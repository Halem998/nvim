# Research Report: Task #962

**Task**: 962 - Correct the pr_ready skill text and docs to describe the actual resulting state
**Started**: 2026-08-06
**Completed**: 2026-08-06
**Effort**: small (documentation/prose accuracy fix, no script changes)
**Dependencies**: None
**Sources/Inputs**: Codebase (Read/Grep) — no web search needed
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- `scripts/update-task-status.sh`'s `map_status()` already resolves the reported conflict at
  the script level: `postflight:pr_ready` sets `STATE_STATUS="completed"` (line 165), regardless
  of `--allow-pr-ready`. The guard (lines 196-203) separately confirms the flag IS honored (no
  refusal for non-`pr` types when passed). Both facts are simultaneously true — the script needs
  no change, exactly as the task description concludes.
- The one place that misdescribes the resulting state is
  `skills/skill-orchestrate-hard/SKILL.md`'s skeleton-exhaustion branch (lines 698-722): its
  comment says "Transition to `pr_ready`" and its terminal message is
  `EXIT (success, pr_ready — skeleton exhausted, ...)`, but because the call at line 711 is a
  **postflight** call, the task actually comes to rest at `completed` (TODO_STATUS
  `COMPLETED`), never at `pr_ready`.
- The genuine `#### State: pr_ready` handler later in the same file (lines 845-850) is a
  *different, correct* code path: it only fires when `current_status` read fresh from
  `state.json` is literally `"pr_ready"`, which — given the `postflight:pr_ready ->
  completed` mapping — can only happen for real `task_type == "pr"` tasks that went through
  `preflight:pr_ready` (`STATE_STATUS="pr_ready"`). No change needed there.
- `merge-sources/claudemd.md`'s Status Markers list (lines 33-38, deployed verbatim into the
  live `.claude/CLAUDE.md` shown in this session's own project instructions) is accurate about
  *resting* states but never distinguishes a "target status passed as a script argument" from
  "the persisted resting status" — exactly the gap that let the skeleton-exhaustion branch's
  prose drift from what the script actually does. A one-sentence clarification closes this.
- `context/standards/status-markers.md`, which self-describes as "Single source of truth for
  status markers," contains **zero** mentions of `pr_ready` or `[PR READY]` anywhere in its
  ~380 lines (confirmed via grep) — it is missing the marker's definition entirely, unlike the
  sibling reference file `context/reference/state-management-schema.md:300`, which has a bare
  one-line mapping (`| [PR READY] | pr_ready |`) with no further detail. Since this file is in
  the task's FILE SCOPE and is the designated authoritative reference, this is the natural home
  for the definitive TRANSITION-target-vs-RESTING-state statement that the other two artifacts
  can point back to.

## Context & Scope

Investigated whether `update-task-status.sh`'s `pr_ready` guard and
`skill-orchestrate-hard/SKILL.md`'s skeleton-exhaustion routing genuinely conflict, per the
originally reported defect. Confirmed they do not — the script's own `map_status()` function
already reconciles "flag is honored" with "resting state is `completed`" by conditioning the
final `STATE_STATUS` on the `preflight`/`postflight` operation, not on the flag alone.
Investigation was scoped to reading the three FILE SCOPE artifacts plus the one non-scope
script (`scripts/update-task-status.sh`) whose behavior they describe, to identify exactly which
prose is inaccurate and where. No script or behavioral changes were investigated as candidates —
the task description explicitly forecloses that path (item 4), and research confirmed the
script is correct as written.

## Findings

### Codebase Patterns

**`scripts/update-task-status.sh` — the authoritative mapping (verified, lines 150-203):**

```bash
map_status() {
  ...
  case "${op}:${target}" in
    ...
    preflight:pr_ready)  STATE_STATUS="pr_ready";      TODO_STATUS="PR READY" ;;
    postflight:pr_ready) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    ...
  esac
}
```

```bash
# --- Guard: pr_ready is reserved for task_type == "pr" unless explicitly overridden ---
if [[ "$target_status" == "pr_ready" && "$task_type" == "pr" ]]; then
  : # allowed: pr-type task transitioning to pr_ready
elif [[ "$target_status" == "pr_ready" && "$ALLOW_PR_READY" == "true" ]]; then
  : # allowed: explicit override flag passed (e.g. skeleton-exhaustion routing in skill-orchestrate-hard)
elif [[ "$target_status" == "pr_ready" ]]; then
  echo "Error: 'pr_ready' is reserved for task_type == 'pr' ..." >&2
  exit 1
fi
```

Two independent axes, both correct: the **guard** decides whether the call is *permitted at
all* (permitted for `task_type == "pr"` always, or any type with `--allow-pr-ready`); the
**mapping** decides what status is *actually written*, keyed by `operation` (`preflight` vs
`postflight`), completely independent of the guard. A `postflight` call with target `pr_ready`
is always permitted-but-resolves-to-`completed`, whether or not `--allow-pr-ready` was needed to
get past the guard. This is why the task description's framing — "decide which side is
authoritative" — dissolves: both are authoritative for different questions (permission vs.
resulting value).

**`skills/skill-orchestrate-hard/SKILL.md` — the inaccurate branch (lines 698-722):**

```bash
elif [ "$last_skeleton" = "true" ]; then
  ...
  # Transition to pr_ready via the centralized status script (never raw-edit state.json).
  # --allow-pr-ready is required here because update-task-status.sh now restricts pr_ready to
  # task_type == "pr"; this skeleton-exhaustion branch is the sanctioned task-type-agnostic
  # exception (it runs for general/lean4/cslib hard-mode tasks, not just type=pr).
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready

  hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}"

  rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note below
  EXIT (success, pr_ready — skeleton exhausted, ${follow_up_count} follow-up task(s): ${follow_up_tasks})
```

Two concrete inaccuracies, both traceable to the same mistaken assumption (that passing
`pr_ready` as a target to a `postflight` call parks the task at `pr_ready`):

1. **Comment** ("Transition to `pr_ready` ... this skeleton-exhaustion branch is the sanctioned
   task-type-agnostic exception"): not false — the flag genuinely is the sanctioned exception to
   the *guard* — but misleading in isolation because it never states that the call is a
   `postflight` call and that `postflight:pr_ready` always resolves to `completed` regardless of
   task type. A reader who knows only this comment would reasonably (but wrongly) conclude the
   task rests at `pr_ready`.
2. **EXIT line**: `EXIT (success, pr_ready — skeleton exhausted, ...)` directly names the wrong
   resting state. Given the mapping above and the fact that `hard_orchestrate_propagate_completion`
   is invoked immediately before it (populating `completion_summary`/`roadmap_items`, which is
   exactly the shared helper the genuine `completed` EXIT paths at lines 862 and 719 itself use)
   — the actual, verifiable resting state at this EXIT is `completed`, not `pr_ready`.

**The correctly-worded, unrelated `pr_ready` state handler (lines 845-850) — for contrast, no
change needed:**

```bash
#### State: `pr_ready`

echo "[hard-orchestrate] Task $task_number is PR READY — use /merge to submit the pull request."
rm -f "$loop_guard_file"
EXIT (success, pr_ready)
```

This handler is reached only when Stage 3a's `current_status` (read fresh from `state.json`,
not passed as a script argument) is the literal string `"pr_ready"`. Since
`postflight:pr_ready -> completed` (above), the only way `state.json` can genuinely hold
`"pr_ready"` at Stage 3a is via a `preflight:pr_ready` call (`STATE_STATUS="pr_ready"`), which
per the guard is unconditionally permitted only for `task_type == "pr"` (or with
`--allow-pr-ready`, though no live call site passes that flag on a `preflight` operation — grep
of the file shows exactly one `--allow-pr-ready` call site, and it is the `postflight` call at
line 711). This handler's own prose ("is PR READY — use /merge") is therefore accurate for the
population that can actually reach it.

**`merge-sources/claudemd.md` — the Status Markers section (lines 33-38):**

```markdown
### Status Markers
- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` -> `[RESEARCHED]` - Research phase
- `[PLANNING]` -> `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` -> `[COMPLETED]` - Standard implementation terminus (general, meta, markdown, cslib, and all other non-pr task types)
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - type=pr only: implementation + PR submission phase
- `[PR READY]` -> `[IMPLEMENTING]` - type=pr only: if PR review finds issues (re-dispatch)
- `[ABANDONED]`, `[EXPANDED]` - Terminal states (no further transitions)
- `[BLOCKED]`, `[PARTIAL]` - Exception states (non-terminal; any command can resume from these)
```

This text is deployed verbatim into the repo's live `.claude/CLAUDE.md` (confirmed identical in
this session's own project-instructions preamble). It is true of *resting* states — exactly as
the task description establishes — but says nothing about the fact that an internal mechanism
(a skill invoking `update-task-status.sh` with `pr_ready` as a *target argument*) can pass
through that name without ever producing a `[PR READY]` resting state for a non-`pr` task. That
silence is exactly what let the skeleton-exhaustion branch's author (or a subsequent editor)
drift into believing "pass `pr_ready` + `--allow-pr-ready`" implies "the task now rests at
`[PR READY]`."

**`context/standards/status-markers.md` — the "single source of truth" gap:**

Grepped the entire file for `pr_ready` and `PR READY` (case variants included): zero matches.
The file enumerates `[NOT STARTED]`, `[RESEARCHING]`, `[RESEARCHED]`, `[PLANNING]`, `[PLANNED]`,
`[REVISING]`, `[REVISED]`, `[IMPLEMENTING]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`,
`[ABANDONED]`, `[EXPANDED]`, and the phase-heading-only `[COMPLETED WITH EXCLUSIONS]` — but never
`[PR READY]`, despite its own header claiming to be the authoritative reference for "All valid
status markers and their meanings" and "Which status changes are allowed." The one other place
in the codebase that even mentions the mapping is
`context/reference/state-management-schema.md:300`, a bare table row (`| [PR READY] |
pr_ready |`) with no further explanation and outside this task's FILE SCOPE (not to be edited
here, only noted as existing prior art for table shape).

### External Resources

Not applicable — this is a pure documentation/prose-accuracy task confined to a single repo's
internal artifacts; no external research was needed or performed.

### Recommendations

1. **`skill-orchestrate-hard/SKILL.md` skeleton-exhaustion branch (lines 707-722)**: Rewrite the
   comment and EXIT line to name the actual resting state (`completed`), while still explaining
   *why* `pr_ready` is the status-script argument used to get there. Suggested shape (not
   prescriptive of exact wording, which is an implementation decision):
   - Comment: state that the call is a `postflight` operation, and that
     `update-task-status.sh`'s own `postflight:pr_ready -> completed` mapping (name it
     explicitly) resolves this to a `completed` resting state regardless of task type; keep the
     existing explanation of why `--allow-pr-ready` is needed to pass the *guard*, since that
     part is accurate.
   - EXIT line: replace `pr_ready — skeleton exhausted` wording with a message naming
     `completed` as the actual resting state (optionally still referencing that the transition
     was routed through the `pr_ready` target argument, for anyone grepping for `pr_ready` who
     lands here).
2. **`merge-sources/claudemd.md` Status Markers list (lines 33-38)**: Add one clarifying
   sentence after the existing bullet list distinguishing a *status-script target argument*
   (what gets passed to `update-task-status.sh` as `$target_status`) from the *persisted resting
   status* it produces, noting that they are not always the same value (citing the
   `postflight:pr_ready -> completed` mapping as the concrete, named example) — mirroring the
   requested clarification in the task description's item 3.
3. **`context/standards/status-markers.md`**: Since this file is explicitly in FILE SCOPE and is
   the designated single source of truth, it is the more natural permanent home for the full
   TRANSITION-vs-RESTING distinction (the claudemd.md sentence can then be a short pointer back
   to it, consistent with claudemd.md's existing pattern of linking out to fuller references
   rather than duplicating detail). Consider adding a `[PR READY]` definition entry (following
   the existing per-marker subsection format used for `[COMPLETED]`, `[BLOCKED]`, etc.) that
   states: TODO.md format, state.json value `pr_ready`, meaning (type=pr only, awaiting
   `/merge`), and a note that other task types can pass `pr_ready` as a script argument via
   `--allow-pr-ready` without ever resting there — pointing to the `postflight:pr_ready ->
   completed` mapping by name. This closes the "single source of truth" gap discovered above and
   gives the other two artifacts one place to defer to.

## Decisions

- **No change to `scripts/update-task-status.sh`**: confirmed correct as written; both the
  guard and the mapping are independently correct and jointly consistent. This matches the task
  description's binding constraint (item 4) and this research found no evidence to challenge it.
- **The defect is isolated to prose in one branch of one skill file**, plus a documentation gap
  in the two other FILE SCOPE artifacts that made that prose drift possible/unnoticed.
- **status-markers.md's missing `[PR READY]` entry is judged in-scope for fix**, not merely
  incidental, because the file is both in FILE SCOPE and self-declared as the authoritative
  reference; leaving it silent on `pr_ready` after this task lands would still leave one FILE
  SCOPE artifact under-specified relative to the other two.

## Risks & Mitigations

- **Risk**: An editor might be tempted to "fix" the guard or mapping in
  `update-task-status.sh` while touching adjacent prose, since the two pieces of code sit right
  next to the misleading comment. **Mitigation**: the task description's item 4 explicitly
  forbids this and instructs escalation instead of proceeding; this report reconfirms the
  script is correct, giving the implementer independent grounds to leave it untouched.
- **Risk**: Rewording the EXIT line could accidentally break a caller or test that greps for the
  literal string `pr_ready` in that EXIT message (e.g., a fixture harness asserting
  skeleton-exhaustion behavior). **Mitigation**: search for consumers of this EXIT string before
  editing (`grep -rn "skeleton exhausted"` across `agent-system/extensions/core/` and any test
  harnesses) as part of implementation; the recommendation above only asks for renaming the
  *resting-state* word, not removing all mention of `pr_ready` from the message, which keeps a
  grep for `pr_ready` on this line still findable if any consumer relies on it.
- **Risk**: `bash .claude/scripts/check-extension-docs.sh` (the stated verification bar) lints
  READMEs, manifests, and cross-references — a status-markers.md addition needs to keep any
  existing internal doc cross-reference format the linter checks. **Mitigation**: confirmed the
  script exists at `.claude/scripts/check-extension-docs.sh`; implementer should run it after
  edits and before declaring the task done, per the verification bar.

## Context Extension Recommendations

- **Topic**: TRANSITION-target vs. RESTING-state distinction for status-script arguments
- **Gap**: No existing context file states this distinction generally (only the `pr_ready`
  instance was investigated here). If a similar target-vs-resting mismatch reappears for a
  different status pair, it would currently require the same kind of ad hoc pattern-matching
  through `map_status()` that produced the original defect report.
- **Recommendation**: `context/standards/status-markers.md`'s planned `[PR READY]` entry (see
  Recommendation 3 above) can generalize this into a short "Target Arguments vs. Resting
  States" subsection near the "Command → Status Mapping" table, giving future status-pair
  additions to `map_status()` a template to follow. Not required for this task's verification
  bar, but noted as a natural byproduct of the fix.

## Appendix

- Searches performed: `grep -n "pr_ready\|PR READY" skills/skill-orchestrate-hard/SKILL.md`;
  `grep -n "allow-pr-ready\|ALLOW_PR_READY\|pr_ready" scripts/update-task-status.sh`;
  `grep -n "PR READY\|pr_ready\|COMPLETED\|IMPLEMENTING\|terminus" merge-sources/claudemd.md`;
  full read of `context/standards/status-markers.md`; `grep -rn "PR READY\|pr_ready"
  context/ docs/` (found only `state-management-schema.md:300`, out of scope).
- Files read in full: `skills/skill-orchestrate-hard/SKILL.md` (partial — Stages 0 through
  Stage 5 tail, sufficient to cover both `pr_ready`-touching branches and confirm no third site
  exists via grep), `context/standards/status-markers.md` (full, 380 lines).
- Confirmed via grep that exactly one `--allow-pr-ready` call site exists in
  `skill-orchestrate-hard/SKILL.md` (line 711, the `postflight` skeleton-exhaustion call) — no
  `preflight` call passes the flag, corroborating that the genuine `pr_ready` resting-state
  handler (lines 845-850) is reachable only via the type=`pr` unconditional-allow branch of the
  guard.
