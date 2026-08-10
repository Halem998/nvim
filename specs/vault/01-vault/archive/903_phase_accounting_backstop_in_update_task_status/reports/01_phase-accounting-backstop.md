# Research Report: Task #903

**Task**: 903 - Add an optional phase-accounting backstop to update-task-status.sh implement postflight
**Started**: 2026-07-25
**Completed**: 2026-07-25
**Effort**: Medium (script change + several caller opt-ins; script-only portion is small)
**Dependencies**: None (companion to the SKILL-layer gate; independent of the not-yet-researched
verify-before-postflight task on the SKILL side)
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts, skills, context/formats)
**Artifacts**: reports/01_phase-accounting-backstop.md (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `update-task-status.sh` line 154 maps `postflight:implement` to `STATE_STATUS="completed"`
  unconditionally, and `update_plan_file()` (~line 295-350) additionally stamps the plan file's
  own `- **Status**:` line to `[COMPLETED]` unconditionally — both fire with zero phase awareness.
- A comprehensive call-site inventory found **8 distinct runtime call sites** that pass
  `postflight <N> implement` (plus one further false-positive ruled out). Only the three
  `skill-orchestrate`/`skill-orchestrate-hard` code paths have any phase gate today (added by the
  task that preceded this one), and that gate lives entirely in `.orchestrator-handoff.json`
  data, which an agent can (accidentally) omit. The other five call sites — `skill-implementer`,
  `skill-implementer-hard`, the `lean`/`cslib` extension implementation-skill variants, and the
  two repair/defensive-correction scripts `reconcile-task-status.sh` and `command-gate-out.sh` —
  have **no phase gate whatsoever**, at either the SKILL layer or the script layer.
- The script can resolve the task's plan file from `task_number` alone with zero new required
  arguments — it already does this exact `project_name` → `plan_dir` → version-ordered-`ls`
  resolution inline in `update_plan_file()`. That same resolution is reusable for a phase-accounting
  read.
- Per-phase `### Phase N: {name} [STATUS]` headings are a far more robust and already-established
  parsing target than raw `- [ ]`/`- [x]` checkbox counting: two existing scripts
  (`update-phase-status.sh`, called from this same script's preflight path) already treat that
  exact heading regex as authoritative, single-line-per-phase, and idempotency-checkable.
  Checkbox counting is not robust (checkboxes appear in non-phase sections like "Testing &
  Validation" too, and their granularity is per-task-item, not per-phase) and is not recommended.
- **Recommendation**: add an **optional, additive `--phase-check=warn|refuse` flag** (absent by
  default → today's exact behavior, byte-for-byte). When present, the script performs its own,
  independent plan-file phase count (never trusting caller-supplied numbers) and only acts on
  **conclusive on-disk evidence of incompleteness** (phase headings exist, count > 0, and not all
  are `[COMPLETED]`). Absence of phase headings, or absence of a plan file, is always treated as
  inconclusive and passes through unconditionally — mirroring the exact "phases_total == 0 →
  historical pass-through" convention the SKILL-layer gate already established, so the two layers
  never contradict each other.
- **Refuse-vs-warn is not a single global choice** — it should be threaded per call site based on
  each caller's existing failure-handling contract; the report gives a call-by-call
  recommendation, with `refuse` recommended for the two call sites (`skill-implementer`,
  `reconcile-task-status.sh`) that today have zero gate protecting the majority of real-world
  `/implement` runs (general/meta/markdown task types), and `warn` recommended everywhere the
  caller already has its own gate or already treats a non-zero exit as non-fatal.

## Context & Scope

Scope per the task description: verify the defect's line anchors; enumerate every runtime call
site of `postflight ... implement`; determine what evidence the script can gather with zero new
required arguments; read the existing SKILL-layer gate so the two compose rather than contradict;
recommend refuse-vs-warn with justification; recommend the exact flag surface. This is a research
report only — no code changes were made. The SOURCE-STORE RULE was honored: all files read are
under `agent-system/extensions/**`; `.claude/` was not touched (it is a gitignored deploy
artifact and `agent-system/extensions/core/scripts/update-task-status.sh` was confirmed byte-for-
byte identical to `.claude/scripts/update-task-status.sh` at the start of this research).

## Findings

### Defect line anchors (verified)

`agent-system/extensions/core/scripts/update-task-status.sh`:

- **Line 154**: `postflight:implement) STATE_STATUS="completed"; TODO_STATUS="COMPLETED" ;;` —
  inside `map_status()` (lines 144-168). No phase parameter exists anywhere in the script; the
  case statement keys only on the `operation:target_status` pair.
- **Lines 295-350 (`update_plan_file()`)**: for `target_status == "implement"` and
  `operation == "postflight"`, sets `plan_status="COMPLETED"` (line 304) and calls
  `update-plan-status.sh "$task_number" "$project_name" "$plan_status"` (line 340), which stamps
  the plan's single `- **Status**:` metadata line — unconditionally, with no phase check. A
  failure of this call is treated as **fatal** on postflight (`exit 3`, lines 341-346) precisely
  because a silent state.json/plan-file divergence is otherwise externally invisible — the same
  fatal-on-postflight design intent argues for treating phase-incompleteness detection with
  similar seriousness rather than as a soft, ignorable warning by default.
- Both effects are reachable together and only together: there is one code path
  (`operation=postflight, target_status=implement`) that triggers both the state.json flip and
  the plan-file Status stamp. A single early gate (before `PHASE 1: update_state_json`, i.e.
  before line ~269's mutex acquisition) blocks both effects at once — no need for two separate
  checks.

### Call-site inventory (every runtime caller of `postflight ... implement`)

Method: `grep -rn` across all of `agent-system/` for
`update-task-status.sh.*postflight.*implement` (SKILL.md, command `.md`, and `.sh` files),
followed by manual read of each hit's surrounding code to confirm it is a live, unconditional
runtime path (not a doc example or an operation value that can never actually be `implement`).

| # | Call site | Path resolution today | Phase gate today | Phase-accounting evidence available without a new argument? |
|---|-----------|------------------------|-------------------|----|
| 1 | `skill-orchestrate/SKILL.md` Stage 5, `implemented)` arm (single-task) | Reads `phases_completed`/`phases_total` from `.orchestrator-handoff.json`; pass-through when `phases_total == 0` | **Yes** (the task that preceded this one) | Yes — but relies entirely on the dispatched agent's self-reported handoff JSON. Demonstrated fragile: the motivating example had `phases_completed: null, phases_total: null` even though the agent's own `.return-meta.json` correctly said 6/6 |
| 2 | `skill-orchestrate/SKILL.md` Stage MT-4 (multi-task mode) | Same as #1, mirrored per-task, re-read fresh every task in the wave | **Yes** (mirrors #1) | Same caveat as #1 |
| 3 | `skill-orchestrate-hard/SKILL.md` (hard-mode gate) | Same source, but requires `phases_total > 0` strictly (never a 0-pass-through) | **Yes**, stricter | Same caveat as #1, mitigated somewhat by hard mode's per-phase dispatch discipline always populating the fields |
| 4 | `skill-implementer/SKILL.md` Stage 7 (line 444), `/implement N` direct (general/meta/markdown task types — the three core, always-available task types) | Reads `phases_completed`/`phases_total` from the dispatched agent's `.return-meta.json` (`.metadata.phases_completed`/`.metadata.phases_total`, lines 354-355) into local shell vars, **but never checks them before calling postflight** — the only gate is `status == "implemented"` | **No** | Yes — the values are already being read into shell variables one stage earlier for the git-commit message (line 427); they are simply never consulted before the postflight call |
| 5 | `skill-implementer-hard/SKILL.md` line 323 | Reads `phases_completed`/`phases_total` from `.return-meta.json` (lines 298-299) into shell vars, same as #4 — **also never checks them** | **No** | Yes, same as #4 |
| 6 | `lean` extension: `skill-lean-implementation/SKILL.md` line 192 | Domain-specific implementer, same general shape as #4 | **No** | Not directly verified line-by-line in this pass (extension-scoped, lower priority); presumed similar to #4 since it follows the same skill-base.sh/postflight convention |
| 7 | `lean` extension: `skill-lean-implementation-hard/SKILL.md` line 277 | Same shape as #5 | **No** | Same as #6 |
| 8 | `cslib` extension: `skill-cslib-implementation/SKILL.md` line 124 | Same shape as #4 | **No** | Same as #6 |
| 9 | `cslib` extension: `skill-cslib-implementation-hard/SKILL.md` line 298 | Same shape as #5 | **No** | Same as #6 |
| 10 | `reconcile-task-status.sh` lines 317-346 (`implementing` state repair) | Promotes purely on **artifact existence** (a `summaries/*.md` file exists) plus `handoff_permits_promotion("implemented")`, which checks only `.orchestrator-handoff.json`'s `.status` field — **never `phases_completed`/`phases_total`** | **No** | No new argument needed — `TASK_DIR` is already resolved in this script; it would need to read the plan file itself (or delegate to the backstop) exactly like the others |
| 11 | `reconcile-task-status.sh` lines 349-382 (`partial` → `completed` repair) | Same shape as #10, for the `partial` state | **No** | Same as #10 |
| 12 | `command-gate-out.sh` line 94, invoked at the end of **both** `/implement N` (`implement.md:165`) and `/orchestrate N` (`orchestrate.md:402`) with `operation="implement"`/`"orchestrate"` → `status_token="implement"` | Reads only `.return-meta.json`'s top-level `.status` field (`skill_status`); promotes to `expected_status="completed"` whenever `skill_status == "implemented"` and `current_status != expected_status` — **never reads `phases_completed`/`phases_total`** | **No** | No new argument possible in general (a defensive corrector by design has no fresh handoff to trust) — must independently consult the plan file, exactly the case the backstop is built for |

**Excluded from the inventory** (confirmed NOT live `postflight ... implement` callers):

- `orchestrator-postflight.sh` line 310: comment says "research and plan only; implement does
  inline" and this is enforced in code — `do_status_update="false"` is hard-set for
  `operation_type=implement` (lines 164-172), so the guarded call at line 308
  (`if [ "$do_status_update" = "true" ] ...`) never fires for implement. Confirmed by reading, not
  just the comment.
- `reconcile-task-status.sh` line 194 (`record_refused_promotion`): only ever passes
  `blocked`/`partial` as `target_status`, never `implement`.
- `context/workflows/command-lifecycle.md` and `rules/state-management.md`: doc examples with
  literal `implement` shown for illustration, not executable call sites.

**Key inventory-driven finding for the backward-compatibility argument**: call sites #4-#12 (7 of
the 8 real implement-postflight callers with no gate) collectively cover the **majority of real
`/implement` traffic** — every general/meta/markdown task run via `/implement` directly (not via
`/orchestrate`), every lean/cslib extension task, and both repair paths that exist precisely to
recover from crashed/interrupted runs. The SKILL-layer gate added previously protects only the
`/orchestrate` path (call sites #1-#3). This confirms the task description's framing: the
SKILL-layer gate is "one layer deep," and a script-layer backstop is the only mechanism that can
protect all 8 sites uniformly without editing 5+ separate SKILL.md files' internal logic (though
the flag still needs to be *passed* by each caller that wants the on-by-default protection — see
Recommendation below).

### What evidence the script can gather on its own (no new required argument)

1. **Plan file location from `task_number` alone**: already implemented and battle-tested
   in-script. `update_plan_file()` (lines 307-322) resolves `project_name` via a `jq` lookup
   against `state.json` (using the task's own `project_number`), builds
   `specs/{padded_num}_{project_name}/plans` (falling back to the unpadded directory name for
   legacy tasks), and selects the highest-versioned plan file via
   `ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1` with a plain-glob fallback. This
   exact three-step resolution is duplicated verbatim in `update-plan-status.sh` and
   `update-phase-status.sh` (both scripts `update-task-status.sh` already shells out to). A phase-
   accounting backstop can reuse this without any new argument — task_number is already a
   required positional argument to `update-task-status.sh`.

2. **Phase heading format is a reliable, single-source-of-truth signal**:
   `agent-system/extensions/core/context/formats/plan-format.md` (line 71) fixes the heading
   format as `### Phase N: {name} [STATUS]`, one heading per phase, STATUS drawn from
   `{NOT STARTED, IN PROGRESS, COMPLETED, PARTIAL, BLOCKED}` (`status-markers.md`'s "Plan-level vs.
   phase-level markers" section explicitly excludes `ABANDONED` from phase headings — abandonment
   is whole-document only). `update-phase-status.sh` already uses
   `grep -n "^### Phase ${phase_number}:" "$plan_file"` to locate a specific phase's heading line
   and extracts/replaces the bracketed status with `sed`. This is the exact regex and semantics a
   backstop needs, generalized to count across all `N` rather than a single `N`:
   `grep -c '^### Phase [0-9][0-9]*:.*\[COMPLETED\]'` for the completed count and
   `grep -c '^### Phase [0-9][0-9]*:'` for the total. Both are cheap, deterministic, single-pass
   greps over a markdown file the script already knows how to locate.

3. **Checkbox (`- [ ]`/`- [x]`) counting is explicitly NOT recommended** as the primary signal:
   - Checkboxes are *sub-phase* task items (`plan-format.md` line 74: "Tasks: bullet checklist"
     under each phase), not one-per-phase — the count is unrelated to phase count and would need
     per-phase-scoped parsing (finding each phase's heading, then counting only the checkboxes
     between it and the next heading) to mean anything at all.
   - Checkboxes also appear in non-phase sections of the same document (e.g. the "Testing &
     Validation" section, and this task's own live example plan
     `specs/873_.../plans/01_global_default_target_resolution.md` shows checkboxes nested inside
     narrative sub-bullets under phase items, at varying indentation, including some phases that
     use checkboxes for verification-step logging rather than binary completion tracking — see
     that file's Phase 5, which is `[BLOCKED]` at the phase-heading level while still containing a
     mix of `- [x]` and `- [ ]` sub-items). A naive whole-file checkbox ratio would misjudge this
     phase as "mostly done" when the authoritative phase-heading marker says `[BLOCKED]`.
   - The phase-heading marker is also the field two *other* scripts already treat as the single
     mutable, idempotency-checked source of truth (`update-phase-status.sh` line 90's
     `current_status` extraction, `update-plan-status.sh` line 62's equivalent at the plan level).
     Introducing a second, independent, checkbox-based notion of "done" would create exactly the
     kind of dual-source-of-truth drift this whole defense-in-depth effort is trying to eliminate.
   - **Conclusion**: use `### Phase N: ... [STATUS]` heading counting only. Treat `phases_total_from_plan == 0`
     (no `### Phase` headings found at all — e.g. a trivial unphased plan, or no plan file located)
     as **inconclusive**, not as "0 phases needed" — this is the same convention the SKILL-layer
     gate already uses for its own `phases_total == 0` case, so the two layers agree rather than
     disagree on the meaning of "no data."

### Composition with the existing SKILL-layer gate (`skill-orchestrate/SKILL.md` Stage 5)

Read in full (lines 507-536, mirrored at Stage MT-4 lines 969-985, and the stricter hard-mode
variant at `skill-orchestrate-hard/SKILL.md` lines 757-763). Key points for composability:

- The SKILL-layer gate's evidence source is exclusively `.orchestrator-handoff.json`
  (`phases_completed`/`phases_total` fields on the dispatched agent's own self-reported handoff).
  The script-layer backstop's evidence source is exclusively the plan file's own `### Phase`
  headings, read independently of anything the dispatched agent wrote. These are two structurally
  different, non-overlapping evidence sources — exactly the "defense-in-depth" property the task
  asks for, and exactly why the motivating observation (`phases_completed: null` /
  `phases_total: null` in the handoff, while the plan file — assuming the agent updated its own
  phase headings as it worked, a standing convention reinforced by `update-phase-status.sh`'s
  preflight auto-advance call at `update-task-status.sh` lines 352-391 — would have shown all
  phases `[COMPLETED]`) demonstrates the backstop closing a gap the SKILL layer structurally
  cannot: a handoff that omits its own fields gives the SKILL layer nothing to gate on, but the
  plan file is unaffected by what the handoff chose to report.
- Both layers independently converge on the same "no data → pass through" convention
  (`phases_total == 0` at the SKILL layer, `phases_total_from_plan == 0` at the script layer),
  so a caller that has genuinely no phase structure (a trivial one-shot task with no
  `## Implementation Phases` section) is never incorrectly blocked by either layer.
- **They do not contradict, because they gate different things.** The SKILL layer's gate decides
  *whether to call* `update-task-status.sh postflight ... implement` at all (it simply never calls
  the script when its own handoff-based check says "not done yet" — call site #1/#2/#3 in the
  inventory above). The script-layer backstop, when opted in, is a second, independent check *inside*
  the script itself, evaluated every time the script is actually invoked with
  `postflight ... implement` — including the 7 of 8 call sites that have no SKILL-layer
  equivalent at all. When both layers are active on the same call (e.g. if `skill-orchestrate`
  were updated to also pass `--phase-check=warn`), the script-layer check is a **second opinion**,
  not a veto override of the SKILL layer's own decision to proceed — it should default to `warn`,
  not `refuse`, at call sites #1-#3, precisely because the SKILL layer already made an informed
  decision using data the script layer doesn't have (the handoff's other fields, drift-inspection
  results, etc.) and refusing there would be a genuine behavior contradiction, not a backstop.

## Decisions

1. **The backstop is opt-in per call, not on-by-default.** A new flag,
   `--phase-check=warn|refuse` (absent = today's exact behavior), preserves every existing call
   site's behavior byte-for-byte with zero code change required anywhere else. This satisfies the
   task's hard constraint literally: "optional additive flags that default to a no-op."
2. **Evidence is always gathered independently by the script itself**, never accepted as a
   caller-supplied count. This is deliberate: the whole point of the backstop is to be robust
   against a caller (or an upstream handoff) that has wrong or missing phase data. Accepting a
   caller-supplied `--phases-completed N --phases-total M` pair would reproduce the exact fragility
   being fixed (a caller can pass wrong numbers just as easily as a handoff can omit them). The
   only new required-by-caller decision is the *mode* (`warn` vs `refuse`), not the *data*.
3. **The check point is a single early gate**, placed immediately after the existing
   `state_is_noop` computation (line ~214) and before the mutex is acquired (`acquire_state_mutex`
   at line 269) — i.e. before *both* PHASE 1 (`update_state_json`) and PHASE 3
   (`update_plan_file`'s `[COMPLETED]` stamp) can run. This guarantees a `refuse` verdict blocks
   both of the defect's two effects (state.json flip and plan-file Status stamp) with one check,
   and does no wasted work (no mutex acquisition, no jq write) before deciding to refuse.
   The check only runs when `operation == postflight`, `target_status == implement`, and
   `state_is_noop != true` (an already-completed task replaying postflight has nothing left to
   refuse).
4. **`--dry-run` always exits 0**, preserving the script's existing contract that dry-run is
   preview-only and never itself a failure signal (every existing dry-run branch in the script
   returns 0 or falls through to the unconditional `exit 0` at the end). Under
   `--dry-run --phase-check=refuse`, the script prints
   `[dry-run] Phase-check would REFUSE this transition: N/M phases complete in <plan_file>` and
   continues previewing the rest of the (also-dry-run) pipeline, rather than actually exiting
   non-zero. This lets a caller preview a refusal without it looking like a script bug in a
   dry-run harness.
5. **New exit code 4** is recommended for a real (non-dry-run) `refuse` verdict: `Exit codes`
   0-3 are already documented in the script's header comment (lines 21-27); 4 is the next free
   value: "4 - Phase-accounting backstop refused the transition (plan file shows incomplete
   phases); no state.json or plan-file write occurred."

## Refuse vs. Warn: firm recommendation, grounded in the call-site inventory

**No single global default.** The call-site inventory shows two structurally different situations,
and the same choice is wrong for both:

- **Sites with an existing SKILL-layer gate (#1-#3, `skill-orchestrate`/`-hard`)**: recommend
  **`warn`**, if adopted at all. These sites already decided to proceed using richer context (the
  full handoff, drift inspection, hard-mode's per-phase dispatch discipline). A `refuse` here would
  make the script-layer check a silent veto of a decision the orchestrator already made
  deliberately and loggedly — a genuine behavior change, not a backstop. `warn` still surfaces a
  loud, actionable disagreement between the two evidence sources (useful for catching exactly the
  "handoff omitted its fields but the task was actually incomplete" case the SKILL layer cannot
  see) without silently changing what the orchestrator's own state machine decided.

- **Sites with zero gate today (#4-#12: `skill-implementer`, `skill-implementer-hard`, the
  lean/cslib extension implementers, `reconcile-task-status.sh`, `command-gate-out.sh`)**:
  recommend **`refuse`**. These are the sites where the defect described in the task is live and
  unmitigated today, and they represent the majority of `/implement` traffic (every general/meta/
  markdown task run directly, i.e. the three always-available core task types). A `warn`-only
  posture at these sites reproduces the exact failure mode the task calls out — "warning is safe
  but may be ignored" — because none of these call sites currently inspect the script's stderr or
  exit code for anything other than a bare pass/fail (`skill-implementer` doesn't check the exit
  code at all today; `command-gate-out.sh` already treats a non-zero exit as non-fatal-but-logged,
  which is exactly the graceful degradation `refuse` needs and already gets for free at that one
  site — see next paragraph). Only a hard refusal (state.json/plan-file left untouched, non-zero
  exit) reliably prevents the premature `[COMPLETED]` flip these call sites would otherwise apply
  silently.

**Two supporting observations that make `refuse` low-risk at the zero-gate sites specifically:**

1. `command-gate-out.sh` line 94 already wraps its `update-task-status.sh postflight` call with
   `|| echo "WARNING: ... manual correction may be needed" >&2` — a `refuse` exit is *already*
   handled non-fatally by this caller's existing error path, with zero code change needed there
   beyond adding the flag. The command (`/implement` or `/orchestrate`) continues; only the false
   "completed" correction is prevented.
2. `skill-implementer/SKILL.md` Stage 7 is a **single unconditional call with no existing
   error-handling branch** (line 444 is a bare `bash ...` with no `||`). Adding `--phase-check=refuse`
   there requires the SKILL.md to also add an explicit branch for the refusal (treat it like the
   existing "partial" branch a few lines below, at line 483: keep status as `implementing`, log the
   refusal, and let the next `/implement` invocation resume). This is a real SKILL.md edit, not
   free — but it is the correct fix for the primary gap this task identified, and it belongs to
   this task's script-and-adjacent-caller scope rather than to a separate follow-up.

**Caveat / risk to flag explicitly**: a `refuse` posture is only as safe as the assumption that a
genuinely-complete implementation always leaves its plan file's phase headings at `[COMPLETED]`.
This assumption is supported by the codebase (preflight auto-advances the first phase to
`[IN PROGRESS]` via `update-phase-status.sh`, implying phase headings are treated as live,
agent-maintained state throughout implementation) but was not independently verified in this
research pass by tracing every implementation agent's own phase-heading-update discipline
end-to-end. If an implementation agent completes all work but never updates its own plan file's
phase headings (a documentation-lag bug distinct from the phase-count bug this task addresses),
`refuse` mode would produce a false refusal. Recommend the Phase-1 rollout of `refuse` at sites
#4/#10/#11 (the highest-leverage, best-understood sites: `skill-implementer` and both
`reconcile-task-status.sh` branches) be validated against a handful of real recent `[COMPLETED]`
tasks' plan files (confirm their phase headings are indeed all `[COMPLETED]` at the time postflight
ran) before or during implementation, rather than assumed from this research alone.

## Recommended Flag Surface

```
.claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> \
  [--dry-run] [--allow-pr-ready] [--phase-check=warn|refuse]
```

- **Flag name**: `--phase-check=<mode>` (not two separate boolean flags) — a single flag with an
  enum value keeps the "absent = no-op" contract unambiguous (no risk of a caller setting a
  hypothetical `--refuse-on-incomplete` flag without also setting a hypothetical
  `--phase-check-enabled` flag, which would be two knobs for one decision).
- **Default**: absent entirely. **Not** a default of `off` spelled out as a value — literally not
  passing the flag is the only way to get today's exact behavior, so there is no way to
  accidentally opt in.
- **Scope**: only consulted when `operation == postflight` and `target_status == implement`. If
  passed with any other operation/target_status combination, it is silently ignored (no error) —
  phase accounting has no meaning for research/plan/pr_ready postflights, and erroring on an
  inapplicable-but-harmless flag would add a new failure mode for no benefit.
- **Validation**: any value other than `warn` or `refuse` (e.g. a typo) should be a hard validation
  error (`exit 1`, matching the script's existing "Error: ..." + `exit 1` convention at lines
  116-136) rather than silently falling back to a no-op — a typo'd flag should never *silently*
  disable the very protection the caller intended to enable.
- **Interaction with `--dry-run`**: as decided above, `--dry-run` always previews (prints what
  `warn`/`refuse` would do) and always exits 0, regardless of `--phase-check` mode.
- **No new required arguments, no new positional arguments.** `task_number` (already required)
  and `state.json`'s existing `project_name` field (already read) are sufficient to resolve the
  plan file; no caller needs to compute or pass phase counts itself.

**Byte-for-byte backward compatibility confirmed**: every one of the 12 call sites enumerated
above invokes the script today with none of `--dry-run`/`--allow-pr-ready`/a hypothetical
`--phase-check` present (aside from the one existing `--allow-pr-ready` use at
`skill-orchestrate-hard/SKILL.md` line 522, for `pr_ready`, unrelated to this change). Since the
new flag is additive, unparsed-by-default, and only consulted inside the
`target_status == "implement"` branch behind an explicit opt-in, none of the 12 sites' behavior
changes unless and until each is separately edited to pass `--phase-check=...` — which is
recommended as caller-by-caller follow-up work (see Risks & Mitigations), not bundled into the
script change itself.

## Risks & Mitigations

- **Risk**: phase-heading parsing could silently under/over-count if a plan file uses a malformed
  or non-conforming heading (e.g. missing brackets, extra phases inserted by a revision without
  updating numbering). **Mitigation**: treat any heading line that doesn't match the exact
  `^### Phase [0-9]+:.*\[[A-Z ]+\]$` pattern as excluded from both totals (neither counted as total
  nor completed) rather than causing a script error — matches the existing scripts' `|| true` /
  `// 0` graceful-degradation style throughout this codebase.
- **Risk** (flagged above): `refuse` mode assumes agents keep plan-file phase headings in sync
  with real progress. **Mitigation**: validate against real completed-task plan files before
  enabling `refuse` at any site; start with `warn` at less-understood sites (lean/cslib extension
  implementers) and only add `refuse` once confirmed.
- **Risk**: adding `--phase-check=refuse` to `skill-implementer/SKILL.md` requires a new branch
  (no existing `||` error handling on that call), unlike `command-gate-out.sh` which gets refusal
  handling for free. **Mitigation**: model the new branch on the existing `status == "partial"`
  branch a few lines below (line 483 onward) — same "keep status as implementing, log, let the
  next `/implement` resume" shape, just triggered by the script's exit code instead of the agent's
  self-reported status.
- **Risk**: `reconcile-task-status.sh`'s two call sites (#10/#11) are themselves *repair* logic for
  crashed runs; adding `refuse` there means a repair attempt can itself be refused, potentially
  leaving a task stuck in `implementing`/`partial` indefinitely if the plan file's phase headings
  are also out of sync (e.g. the crash happened before the agent updated its own headings).
  **Mitigation**: this is an acceptable failure mode — a stuck-but-honestly-labeled task is
  strictly safer than a silently-wrong `[COMPLETED]` task, and `reconcile-task-status.sh` already
  logs loudly (`echo "[reconcile] ..."`) on every branch, so a refusal here is visible, not silent.

## Context Extension Recommendations

- **Topic**: phase-heading parsing regex and its two existing consumers.
  **Gap**: no single context file currently documents `^### Phase [0-9]+:.*\[STATUS\]` as the
  canonical, reused-in-three-places parsing target for phase completion (it is implicit across
  `plan-format.md`, `update-phase-status.sh`, and (after this task) `update-task-status.sh`).
  **Recommendation**: once implemented, add a short cross-reference note to
  `context/formats/plan-format.md`'s "Implementation Phases (format)" section pointing at
  `update-task-status.sh`'s `--phase-check` flag as a third consumer of the same heading contract,
  so a future format change to phase headings has all three consumers listed in one place.

## Appendix

### Search queries / commands used

```
find / -maxdepth 6 -type d -name "agent-system"
grep -rn "update-task-status\.sh" agent-system --include="*.md" --include="*.sh" -l
grep -rn "update-task-status\.sh[^\"]*postflight[^\"]*implement..." agent-system --include="*.sh" -A1
grep -rn "update-task-status\.sh" agent-system/extensions/*/skills/*/SKILL.md agent-system/extensions/*/commands/*.md -B2 -A2
grep -n "handoff_permits_promotion\|phases_completed\|phases_total" agent-system/extensions/core/scripts/reconcile-task-status.sh
grep -n "do_status_update" agent-system/extensions/core/scripts/orchestrator-postflight.sh
grep -n "^### Phase\|^\*\*Status\*\*\|- \[x\]\|- \[ \]" specs/873_.../plans/01_global_default_target_resolution.md
```

### Files read in full or substantial part

- `agent-system/extensions/core/scripts/update-task-status.sh` (full, 413 lines)
- `agent-system/extensions/core/scripts/update-plan-status.sh` (full, 78 lines)
- `agent-system/extensions/core/scripts/update-phase-status.sh` (full, 127 lines)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (relevant sections, lines
  1-60, 140-220, 260-390)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (lines 1-100)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (lines 1-50, 140-175, 295-315)
- `agent-system/extensions/core/scripts/skill-base.sh` (lines 340-380)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 480-560, 955-998, plus
  targeted grep across the whole file)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (targeted grep,
  lines 440-870)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (lines 340-500)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (lines 280-330)
- `agent-system/extensions/core/context/standards/status-markers.md` (full, 320 lines)
- `agent-system/extensions/core/context/formats/plan-format.md` (lines 55-204)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` (targeted grep)
- `agent-system/extensions/core/commands/orchestrate.md` (lines 370-414)
- `specs/873_global_default_target_resolution_for_meta/plans/01_global_default_target_resolution.md`
  (targeted grep, used as a live example of real plan-file phase-heading/checkbox structure)
