# Research Report: Task #892

**Task**: 892 - Prevent stale/misplaced .orchestrator-handoff.json reads
**Started**: 2026-07-25T15:02:54Z
**Completed**: 2026-07-25T15:08:12Z
**Effort**: medium (multi-file, two mechanisms, source-store only)
**Dependencies**: None (task 896 depends on this one for `scripts/skill-base.sh` edit
serialization only, not a logical prerequisite)
**Sources/Inputs**: Codebase read-through of `agent-system/extensions/core/` and
`agent-system/extensions/lean/` (source store; `.claude/` is the gitignored deploy artifact and
was not edited or treated as authoritative)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

All line numbers below were re-derived directly against the current source-store files during
this research pass (not copied from the task description, which warns anchors have shifted).

## Executive Summary

- **Root cause is a dual-path problem, not one bug.** There are two independent handoff-writing
  mechanisms with two independent location failures:
  1. The shared bash helper `skill_write_orchestrator_handoff` (`skill-base.sh`) constructs the
     handoff path as a **cwd-relative** string (`specs/${padded_num}_${project_name}/...`) — a
     real script-layer weakness, but it is used only by *base-mode* skills, not the hard-mode
     path that produced the observed defect.
  2. The **hard-mode custom-schema writers** (the ones the lean phase-7 agent actually uses)
     never call that helper at all. `wrap-up.md`, `general-implementation-hard-agent.md`,
     `lean-implementation-hard-agent.md`, and `skill-lean-implementation-hard/SKILL.md`'s own
     dispatch prompt all instruct the agent to `Write \`.orchestrator-handoff.json\`` with a
     **bare filename and zero directory path anywhere in the instruction chain**. This is a pure
     agent-instruction bug, and it is the one that produced the repo-root stray.
  3. Compounding both: `skill-orchestrate/SKILL.md`'s four dispatch sites never put a `task_dir`
     (relative or absolute) into the `context` object handed to the subagent — the subagent has
     no authoritative anchor to write against even if it wanted one.
- **The PostToolUse hook IS enforceable, but only for half the problem.** `validate-meta-write.sh`
  and `validate-plan-write.sh` both work today because Write/Edit tool calls always carry a
  resolved, literal `tool_input.file_path` — a location-check hook on `.orchestrator-handoff.json`
  basenames is straightforwardly implementable on that same `Write|Edit` matcher and will catch
  every hard-mode agent write (which uses the Write tool with a literal path). It **cannot** see
  `skill_write_orchestrator_handoff`'s write, because that happens via `Bash` redirection
  (`jq -n ... > "$handoff_path"`) — Bash `tool_input` carries `command` text, not a resolved
  `file_path`, and `$handoff_path` is an unexpanded shell variable in that text, not a string a
  hook can recover. A Bash-matched hook cannot reliably reconstruct the destination either.
- **Recommended fix is three-part**: (a) fix `skill_write_orchestrator_handoff` to write to an
  absolute path, and thread an absolute `task_dir`/`handoff_path` field through every dispatch
  `context` object and every hard-mode agent/skill instruction so no writer ever has to guess a
  bare filename's landing spot; (b) add `hooks/validate-handoff-location.sh` on the `Write|Edit`
  PostToolUse matcher to catch and loudly reject any Write/Edit-tool write of
  `.orchestrator-handoff.json` outside a `specs/{NNN}_{SLUG}/` directory; (c) add an
  orchestrator-side stray-file check in `skill-orchestrate/SKILL.md` (and its `-hard` sibling)
  Stage 5 as the mechanism-agnostic fallback that catches Bash-redirected strays regardless of
  how they were written.
- **Staleness check should reuse `dispatch_start_ts`**, the exact timestamp already captured
  immediately before each of the four dispatch sites for the newly-added infra-failure
  discrimination mechanism (`meta_mtime -ge window_start` at SKILL.md:465). The identical
  `stat -c %Y` vs. `dispatch_start_ts` comparison, applied to `handoff_file` instead of
  `.return-meta.json`, directly catches the reported symptom: a correctly-located but
  *not-touched-this-dispatch* handoff (mtime older than the current dispatch window) is provably
  stale and must not be trusted, exactly as a missing handoff is not trusted today.

## Context & Scope

Researched: (1) whether `skill_write_orchestrator_handoff` in `scripts/skill-base.sh` resolves
the task directory cwd-relatively (script-layer bug) or whether the misplacement is an
agent-instruction problem; (2) whether a PostToolUse hook can actually enforce a handoff-location
check given it only sees `file_path`; (3) whether a handoff staleness check can reuse the
just-added infra-failure-discrimination dispatch-window timestamp; (4) every edit site, across
both `core` and `lean` extensions, with re-derived line anchors.

Scope is confined to the SOURCE STORE (`agent-system/extensions/core/`,
`agent-system/extensions/lean/`) per the binding source-store rule. `.claude/` was read only
incidentally (to inspect the currently-deployed `settings.json` hook registrations, since
`merge-sources/settings-hooks.json` in the source store does not yet contain the full deployed
hook set — see Findings below) and must never be treated as an edit target.

## Findings

### Codebase Patterns

#### 1. `skill_write_orchestrator_handoff` IS cwd-relative (confirmed script-layer weakness)

`agent-system/extensions/core/scripts/skill-base.sh`:

```
497  skill_write_orchestrator_handoff() {
...
513    local handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
...
560    jq -n ... > "$handoff_path" && \
561      echo "[skill-base] Orchestrator handoff written: $handoff_path" || \
562      echo "[skill-base] WARNING: Failed to write orchestrator handoff to $handoff_path" >&2
563  }
```

`handoff_path` is built from a bare `specs/...` string with no repo-root anchor, and the write
at line 560 is a plain Bash redirect against whatever the shell's current working directory is
at call time. If cwd is not the repo root when this function runs, the write silently lands
somewhere else — not necessarily the repo root, but wherever cwd happens to be, which is exactly
the class of bug the task asks about. This mirrors the identically-shaped, already-tracked
cwd-relativity bug in the sibling `skill_link_artifacts` function in the same file (lines
434-456; `specs/state.json`, `specs/tmp/state.json`, and `.claude/scripts/generate-todo.sh` are
all bare-relative there too) — confirming this is a recurring pattern in `skill-base.sh`, not a
one-off. That sibling bug is the dedicated scope of a separate task, which is why it is
serialized after this one purely for file-edit ordering on `scripts/skill-base.sh`.

`skill_validate_input` (same file, line 172) also derives `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`
as a bare relative string, so every consumer of `TASK_DIR` throughout `skill-base.sh` inherits
the same cwd assumption.

**Important scoping note**: `skill_write_orchestrator_handoff` is called only by base-mode core
skills using the *standard* handoff schema (`status/summary/artifacts/phases_completed/...`).
Hard-mode skills that need the extended schema (`skeleton`, `sorry_inventory`, `blockers` with
verbatim goal text) never call it — they instruct the dispatched agent to write the file
directly. **The lean phase-7 agent that produced the observed repo-root stray is a hard-mode
agent, so this script-layer bug is not what caused the observed defect** — but it is real, it
should still be fixed, and a future base-mode misplacement is entirely plausible under the same
conditions (cwd not being the repo root when a Bash tool call runs).

#### 2. The observed defect's true cause: hard-mode write instructions never specify a directory

None of the four instruction sites that tell a hard-mode agent to write
`.orchestrator-handoff.json` include a directory path — not a relative one, not an absolute one:

- `agent-system/extensions/core/context/contracts/wrap-up.md` (the canonical H9 schema
  definition, loaded by both `general-implementation-hard-agent` and
  `lean-implementation-hard-agent`), line 14: `Every hard-mode implementation dispatch MUST
  write \`.orchestrator-handoff.json\` before terminating.` — bare filename, no path, in the
  contract that *defines* the schema for every hard-mode writer.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`, line 253:
  `**Step 1: Write \`.orchestrator-handoff.json\`**` followed immediately by a JSON schema
  block — again no directory.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`, line 259:
  `**Step 1: Write \`.orchestrator-handoff.json\`** (always, even on success):` followed by a
  JSON schema block — same gap. This is the agent that actually misplaced the file in the
  observed run.
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`, line 178,
  inside the bulleted list of what the dispatched subagent will do: `- Write
  \`.orchestrator-handoff.json\` with sorry_inventory` — this is the literal text injected into
  the Agent-tool `prompt` field for the dispatch (Stage 5a, lines ~160-179), so the dispatched
  agent's *actual received instructions* never contain a directory either.

Meanwhile, the SKILL.md files that later *read* the file back correctly use the scoped relative
path (`specs/${padded_num}_${project_name}/.orchestrator-handoff.json` — see
`skill-lean-implementation-hard/SKILL.md` lines 113, 257, 328, and
`skill-implementer-hard/SKILL.md` lines 129-133, which has an explanatory comment recording a
*prior* fix from an even worse un-scoped `specs/.orchestrator-handoff.json` collision path).
**The scoped path exists in the reader's own bash, but is never communicated to the writer
(the dispatched agent).** That gap — reader knows the correct path, writer is never told it —
is the direct, sufficient explanation for the observed repo-root stray: with no path given, a
Write-tool call for a bare `.orchestrator-handoff.json` resolves against the ambient working
directory at Write-tool-call time, which is the repo root in the normal dispatch flow.

`agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` itself does not inline a
"Write `.orchestrator-handoff.json`" bullet in its Agent-tool dispatch prompt (line 242-243);
it relies entirely on `general-implementation-hard-agent.md` (which loads `wrap-up.md`) to
supply that instruction — so the same path-less gap applies transitively.

Two files in the task's "verified" component list are **not** writers and require no location
fix, only confirmation:
- `agent-system/extensions/core/agents/general-research-agent.md`, line 187, and
- `agent-system/extensions/core/agents/general-research-hard-agent.md`, line 202,

both explicitly instruct: *"Do NOT use `wrap-up.md`'s H9 schema or `.orchestrator-handoff.json`
for research — that schema and its consumer allowlist are implementation-agent-only."* Research
dispatches are handled by a different mechanism entirely (`skill_write_orchestrator_handoff`
called from `skill-researcher`'s own postflight, or an orchestrator-supplied absolute path passed
directly in the delegation prompt — see this very research dispatch's own delegation context,
which specified an absolute handoff path explicitly). No change needed to these two files beyond
leaving the prohibition intact.

`agent-system/extensions/lean/context/contracts/anti-analysis.md`, line 104, only *references*
the `sorry_inventory` field's existence inside `.orchestrator-handoff.json`; it contains no write
instruction and needs no location fix, only a possible cross-reference note if the schema
contract (`wrap-up.md`) gains an explicit path field.

#### 3. The orchestrator never gives dispatched agents an absolute anchor to begin with

`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`:

- Line 55: `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"` (relative).
- Line 111: `handoff_file="${TASK_DIR}/.orchestrator-handoff.json"` (relative; this is the
  read-side path the task description's `:107` anchor has shifted to).
- Four dispatch sites, each constructing the Agent-tool `context` object with no `task_dir`
  field at all:
  - not-started -> research, line ~239: `context: { task_number, task_type, session_id,
    orchestrator_mode: true, lit_flag }`
  - researched -> plan, line ~288: `context: { task_number, task_type, session_id,
    research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag }`
  - planned/implementing -> implement, line ~328: `context: { task_number, task_type,
    session_id, orchestrator_mode: true, plan_path, lit_flag }`
  - partial (continuation) -> implement resume, line ~380: `context: { task_number, task_type,
    session_id, orchestrator_mode: true, plan_path, continuation_context, lit_flag }`

  None of these four sites include `task_dir` (relative or absolute). A dispatched agent must
  independently re-derive `TASK_DIR="specs/${padded_num}_${project_name}"` from `task_number` by
  re-reading `specs/state.json`, and even then only recovers a *relative* path — there is no
  absolute anchor anywhere in the delegation chain. Contrast this with how **this very research
  dispatch** was set up: the calling orchestrator layer supplied an explicit *absolute* handoff
  path (`/home/benjamin/.config/nvim/specs/892_.../.orchestrator-handoff.json`) directly in the
  task prompt outside the standard `context` object — proving the orchestrator is capable of
  producing an absolute anchor when instructed to, but does not do so uniformly for the four
  `skill-orchestrate` dispatch sites above.

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` has the identical shape:
  `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"` (line 115), `handoff_file="${TASK_DIR}/.orchestrator-handoff.json"`
  (line 199), and its own set of `dispatch_start_ts` capture sites (lines 347, 393, 422, 496)
  feeding an infra-failure-discrimination block with `window_start="${dispatch_start_ts:-9999999999}"`
  (line 697) that mirrors the base skill almost exactly. This file is **not** in the task's
  originally-verified component list but is affected by the identical missing-`task_dir` and
  missing-staleness-check gaps and should be updated in lockstep with `skill-orchestrate/SKILL.md`
  if the fix is to be complete — flagging this for the planner as an in-scope addition.

- `agent-system/extensions/core/docs/architecture/handoff-schema.md`, line 5, documents the
  canonical location as `specs/{NNN}_{SLUG}/.orchestrator-handoff.json (runtime; not checked
  in)` with no mention of the repo-root-misplacement failure mode or an absolute-path
  requirement. This doc should be updated alongside the code fix so it stops silently endorsing
  a relative-only convention.

#### 4. The PostToolUse hook mechanism: honestly enforceable for one write path, blind to the other

Studied `validate-meta-write.sh` and `validate-plan-write.sh`
(`agent-system/extensions/core/hooks/`) as instructed. Both hooks:
1. Read PostToolUse hook stdin JSON, extract `tool_input.file_path`.
2. Pattern-match that string against known-good/known-bad path shapes.
3. Return `{}` (no-op) or `{"additionalContext": "..."}` (advisory nudge) — neither hook blocks.

This works reliably **only because Write/Edit tool calls always carry a resolved, literal
`file_path` string in `tool_input`** — there is no shell-variable indirection to resolve. A new
`hooks/validate-handoff-location.sh` on the same `PostToolUse` `Write|Edit` matcher, checking
`basename(file_path) == ".orchestrator-handoff.json"` and requiring the path to match
`(^|/)specs/[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$`, is **directly enforceable** by the
exact same mechanism as the two hooks studied — and it will catch the observed defect class
outright, because the hard-mode agent's `.orchestrator-handoff.json` write (Section 2 above) is
naturally a single-JSON-blob Write-tool call with a literal path argument, not a Bash pipeline.

However, `skill_write_orchestrator_handoff` (`skill-base.sh:560`) writes via
`jq -n ... > "$handoff_path"` inside a `Bash` tool call. A `PostToolUse` hook on that call's
`tool_input` sees `command` (the literal, **unexpanded** shell source text — `"$handoff_path"`
appears verbatim, not the string it evaluates to) and has no `file_path` field at all. Compare
`guard-destructive-git.sh` (`PreToolUse`, matcher `Bash`), which *does* reliably pattern-match
Bash commands — but only because it matches **fixed subcommand text** (`git reset --hard`,
`git clean -fd`, ...), never a *computed* destination built from a variable. There is no
general, reliable way for a hook to recover `$handoff_path`'s resolved value from the command
string alone; doing so would require either (a) full shell evaluation inside the hook
(fragile, and the variable's value isn't even visible to the hook process), or (b) forbidding
variable-indirected redirects entirely as a policy, which is a much bigger and separate change.

**Conclusion, stated plainly as the task requested**: a `Write|Edit`-matched PostToolUse hook
IS enforceable and should be added — but it only covers the hard-mode agent-direct-write path
(which happens to be the one that actually broke). It cannot and must not be relied on as the
sole defense for the `skill_write_orchestrator_handoff` Bash-redirect path; that path needs the
script-layer absolute-path fix (Section 1) plus the orchestrator-side stray-file check
(mechanism-agnostic, catches any write regardless of how it happened) as the complementary
defense-in-depth layer the task description already suggested.

**Hook registration mechanics**: The source-store hook-merge file
`agent-system/extensions/core/merge-sources/settings-hooks.json` currently only registers
`validate-no-task-references.sh` on `PostToolUse`/`Write|Edit`. The three other
`PostToolUse` hooks studied (`validate-state-sync.sh`, `validate-plan-write.sh`, and — by
extension — the new `validate-handoff-location.sh`) are registered directly in the deployed
`.claude/settings.json` (`Write`/`Write|Edit` matchers, lines 101-128 of the current deploy) but
that file is the disposable deploy artifact. The new hook's registration entry must be added to
`agent-system/extensions/core/merge-sources/settings-hooks.json` (not `.claude/settings.json`
directly) so it survives regeneration, on a `PostToolUse` block with matcher `Write|Edit`
alongside the existing `validate-no-task-references.sh` entry (they can share one matcher block
with two `hooks` array entries, following the existing `validate-plan-write.sh` pattern visible
in the deployed settings).

#### 5. Staleness check: `dispatch_start_ts` is directly reusable, no parallel timestamp needed

`skill-orchestrate/SKILL.md` Stage 5 (handoff-reading), current shape:

```
445  # Reset the per-cycle exemption flag before any branch can set it.
446  infra_exempt_cycle=false
447
448  if [ ! -f "$handoff_file" ]; then
449    echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
...
462    meta_file="${TASK_DIR}/.return-meta.json"
463    window_start="${dispatch_start_ts:-9999999999}"
464    meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
465    if [ "$meta_mtime" -ge "$window_start" ]; then
466      meta_touched=true
...
484  else
485    handoff=$(cat "$handoff_file")
486    dispatch_status=$(echo "$handoff" | jq -r '.status')
...
```

`dispatch_start_ts` is captured via `date -u +%s` immediately before each of the four Agent-tool
dispatch sites (`skill-orchestrate/SKILL.md` lines 235, 283, 323, 372) specifically to give the
missing-handoff branch (448-483) a window boundary. The identical technique — `stat -c %Y
"$handoff_file"` compared against `${dispatch_start_ts:-...}` — can be inserted at the top of
the existing `else` branch (line 484, right before line 485's `cat`) to catch the case this task
is actually about: a handoff that **exists at the correct path** but was **not touched during
the current dispatch window** (i.e., it is the previous cycle's leftover, exactly the phase-6
handoff read after phase 7 completed in the observed run). No new timestamp source is needed;
this is the same `dispatch_start_ts` variable, applied to a second file. Recommended behavior on
staleness detection: treat it the same severity class as the missing-handoff branch (loud
`[orchestrate] ERROR: stale handoff detected — mtime older than dispatch window` rather than
silently trusting `dispatch_status`/`phases_completed` from a file that predates this dispatch),
and feed it into the same infra-failure-discrimination decision so a genuinely stale-but-present
handoff is not silently treated as a successful, in-window read.

The same insertion point exists in `skill-orchestrate-hard/SKILL.md` at its analogous handoff-read
block (around line 683's `if [ ! -f "$handoff_file" ]`, using the `window_start` variable already
defined at line 697), and should receive the identical patch for consistency across both
orchestrator variants.

### External Resources

None consulted; this is a fully self-contained agent-system codebase question with no external
dependency.

### Recommendations

1. **Fix `skill_write_orchestrator_handoff` (`skill-base.sh` line ~513)** to build an absolute
   path rather than a bare `specs/...` string — e.g. resolve a repo-root anchor once (mirroring
   the `PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)` pattern already used correctly elsewhere
   in this codebase, per the sibling task's research into `generate-todo.sh`/`update-task-status.sh`)
   and join it with the existing relative `TASK_DIR` construction.
2. **Add an absolute `task_dir` (and/or a precomputed absolute `handoff_path`) field to the
   `context` object at all four `skill-orchestrate/SKILL.md` dispatch sites** (research, plan,
   implement, implement-resume) and the equivalent sites in `skill-orchestrate-hard/SKILL.md`, so
   every dispatched agent receives an unambiguous, pre-resolved anchor instead of having to
   re-derive a relative path from `task_number`.
3. **Update every hard-mode write instruction to state the absolute path explicitly**:
   `wrap-up.md` (the canonical schema contract), `general-implementation-hard-agent.md` Step 1,
   `lean-implementation-hard-agent.md` Step 1, and the dispatch-prompt bullet in
   `skill-lean-implementation-hard/SKILL.md` — all four should read something like "Write to the
   ABSOLUTE path given as `task_dir`/`handoff_path` in your delegation context —
   `{task_dir}/.orchestrator-handoff.json` — NEVER a bare relative filename," removing the
   silent reliance on ambient cwd at Write-tool-call time.
4. **Add `hooks/validate-handoff-location.sh`** on `PostToolUse` matcher `Write|Edit`, modeled
   directly on `validate-meta-write.sh`'s parsing (stdin JSON -> `tool_input.file_path`), checking
   `basename == ".orchestrator-handoff.json"` and rejecting anything not matching
   `specs/[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$`. Given the severity (this is worse than a
   missing handoff, per the task description), consider a **blocking** response (exit 2, mirroring
   `guard-destructive-git.sh`'s block pattern) rather than the advisory-only
   `additionalContext` pattern the meta/plan hooks use — a location violation has no legitimate
   caller-context exception the way `.claude/` writes sometimes do inside `/implement`. Register
   it in `agent-system/extensions/core/merge-sources/settings-hooks.json`, not directly in
   `.claude/settings.json`.
5. **Add an orchestrator-side stray-file check** in `skill-orchestrate/SKILL.md` (and `-hard`)
   Stage 5, immediately after the handoff read/no-read branch: glob for
   `.orchestrator-handoff.json` at the repo root and other non-task-dir locations a stray could
   plausibly land, and fail loudly if found — this is the mechanism-agnostic fallback that also
   catches `skill_write_orchestrator_handoff`'s Bash-redirect writes, which the PostToolUse hook
   cannot see.
6. **Add the mtime-vs-`dispatch_start_ts` staleness check** at the top of Stage 5's existing
   `else` branch (handoff-found path) in both `skill-orchestrate/SKILL.md` (~line 484) and
   `skill-orchestrate-hard/SKILL.md` (~its equivalent branch near line 719), reusing the exact
   `dispatch_start_ts` variable already captured at each dispatch site — no new timestamp
   mechanism needed.
7. **Update `docs/architecture/handoff-schema.md` line 5** to document the absolute-path
   requirement and cross-reference the new validation hook and stray-file check, so the doc no
   longer silently endorses a relative-only convention.

## Decisions

- Treated `skill-orchestrate-hard/SKILL.md` as in-scope-for-planning even though it is not in the
  task's originally-verified component list, because it shares the identical `TASK_DIR`/
  `handoff_file`/`dispatch_start_ts` shape and would otherwise regress independently of any fix
  applied only to the base `skill-orchestrate/SKILL.md`. Recommend the planner decide explicitly
  whether to include it in this task's `file_scope` or split it into a follow-up, rather than
  silently leaving it unpatched.
- Confirmed the PostToolUse hook question with a concrete, load-bearing answer (enforceable for
  Write/Edit-tool writes only) rather than a hedge, per the task's explicit instruction not to
  recommend a hook that cannot work.
- Did not attempt to design the exact stray-file-check glob patterns or the hook's blocking vs.
  advisory posture in full — flagged as an open decision for the planner (recommendation 4 above
  leans toward blocking, given the severity language in the task description, but this trades off
  against the hook family's existing advisory-only convention and should be an explicit planning
  decision, not an unstated research assumption).

## Risks & Mitigations

- **Risk**: Making `validate-handoff-location.sh` blocking (exit 2) could break a legitimate
  edge case not yet identified (e.g., a future skill intentionally writing a scratch copy of the
  handoff schema outside a task dir for testing). **Mitigation**: scope the hook's match strictly
  to the exact basename `.orchestrator-handoff.json`, never a substring/glob, and let the planner
  weigh blocking vs. advisory explicitly rather than defaulting to advisory out of hook-family
  convention alone.
- **Risk**: An absolute-path fix in `skill_write_orchestrator_handoff` that resolves the repo
  root via `git rev-parse --show-toplevel` could behave unexpectedly inside a git worktree or a
  nested-repo scenario. **Mitigation**: prefer resolving from the script's own location
  (`$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`-style, matching the already-correct pattern
  used by `generate-todo.sh`/`update-task-status.sh`) over `git rev-parse`, since `skill-base.sh`
  lives at a fixed, known offset from the repo root regardless of git state.
- **Risk**: Adding a stray-file check that scans the entire repo root on every dispatch could be
  slow or noisy if other legitimate dotfiles share a similar name pattern. **Mitigation**: scope
  the glob to the exact filename `.orchestrator-handoff.json` at the repo root only (plus,
  optionally, one level of `specs/*` that isn't the current task's dir), not a recursive search.

## Context Extension Recommendations

- **Topic**: Handoff-writing path resolution convention.
- **Gap**: There is no existing context/pattern file documenting "how a dispatched agent should
  resolve its own task directory as an absolute path" — every writer either re-derives a relative
  path from `task_number` independently or receives nothing at all. This is the same class of gap
  that produced both this task and the sibling `skill_link_artifacts` cwd-relativity task.
- **Recommendation**: after this task and its sibling land, consider adding a short pattern file
  (e.g. `context/patterns/absolute-task-dir-resolution.md`) documenting the canonical way a
  dispatched agent or skill script should obtain and pass along an absolute task-directory anchor,
  referenced from both `wrap-up.md` and `skill-base.sh`'s header comment, to prevent a third
  recurrence of the same relative-path assumption elsewhere in the system.

## Appendix

Files read in full or in relevant part during this research pass:
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/general-research-hard-agent.md`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/context/contracts/territory.md`
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md`
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/hooks/validate-meta-write.sh`
- `agent-system/extensions/core/hooks/validate-plan-write.sh`
- `agent-system/extensions/core/hooks/guard-destructive-git.sh`
- `agent-system/extensions/core/merge-sources/settings-hooks.json`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- `agent-system/extensions/lean/context/contracts/anti-analysis.md`
- `.claude/settings.json` (deployed artifact, read-only, for currently-live hook registrations)
- `specs/state.json` (task 892 and task 896 entries, for scope/dependency confirmation)

No web search was performed; this is a self-contained internal-codebase investigation.
