# Research Report: Task #795

**Task**: 795 - pr_ready_guard_type_pr
**Started**: 2026-07-04T16:20:00Z
**Completed**: 2026-07-04T16:38:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/scripts/update-task-status.sh`, `.claude/extensions/core/scripts/update-task-status.sh`
- Codebase: `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`, `.claude/skills/skill-cslib-implementation/SKILL.md` (mirror)
- Codebase: `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
- Codebase: `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md`
- Codebase: `.claude/skills/skill-orchestrate-hard/SKILL.md`, `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (mirror)
- Codebase: `.claude/extensions/core/merge-sources/claudemd.md`, deployed `.claude/CLAUDE.md`
- Codebase: `.claude/extensions/core/rules/pr-prohibition.md`, deployed `.claude/rules/pr-prohibition.md`
- Codebase: `.claude/agents/general-implementation-hard-agent.md`, `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`, `.claude/agents/cslib-implementation-hard-agent.md` (skeleton field)
- Codebase: `specs/state.json` (task 795 entry, lines 866-872)
**Artifacts**:
- This report: `specs/795_pr_ready_guard_type_pr/reports/01_pr_ready_guard_type_pr.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `update-task-status.sh` already accepts `pr_ready` as a `target_status` value (line 66) and
  maps both `preflight:pr_ready` and `postflight:pr_ready` (lines 93-94), but performs **no
  task_type validation whatsoever** — any task, regardless of `task_type`, can be pushed through
  either transition today. This confirms the leak described in the task.
- `skill-cslib-implementation` Stage 6 (the plain, non-hard cslib implementation skill) does
  **not** spell out the `postflight implement` call at all — it says only "Update state.json and
  TODO.md based on result," leaving the actual status-target choice implicit. By contrast, its
  hard-mode sibling `skill-cslib-implementation-hard` Stage 7 **does** show the explicit call
  (`postflight "$task_number" implement "$session_id"`, gated on `status == "implemented"`). This
  asymmetry is very plausibly why cslib implementation tasks have drifted to `pr_ready`: an agent
  executing the vague Stage 6 instruction has no concrete call to copy and may pattern-match on
  the nearby, more prominent `skill-pr-implementation` example instead.
- **Critical finding not enumerated in the task's three edits**: `skill-orchestrate-hard` (both
  `.claude/skills/skill-orchestrate-hard/SKILL.md` and its mirror
  `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, byte-identical) contains a
  **third caller** of `postflight ... pr_ready` at its "skeleton-exhaustion routing" branch
  (~line 431), and this call is **task_type-agnostic by design**. It fires whenever a hard-mode
  implementation handoff has `skeleton: true` (the documented "strategic-sorry skeleton" outcome)
  and no incomplete phase heading remains, regardless of whether the task is `cslib`, `lean4`,
  `general`, or anything else — the `skeleton` field is defined identically in
  `general-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`, and
  `cslib-implementation-hard-agent.md`. **A naive guard of "reject pr_ready unless
  task_type==pr" will break this legitimate, currently-working completion path** for every
  hard-mode task type other than `pr`. This must be resolved in the plan before the guard ships.
- Recommended approach: keep the guard in core `update-task-status.sh` (do not push pr_ready
  fully into the cslib extension — the script is already the single centralized, task-type-blind
  status authority and hard-coding cslib-specific bypass logic into an extension skill would
  re-introduce exactly the kind of unguarded direct state.json edit the script exists to prevent).
  But the guard predicate must be `task_type == "pr" OR <skeleton-exhaustion is the caller>`, not
  a bare `task_type == "pr"` check. The cleanest implementation is a new explicit CLI signal
  (a 5th positional arg or flag, e.g. `--allow-skeleton`) that `skill-orchestrate-hard` passes
  when it calls `postflight pr_ready` from the skeleton-exhaustion branch, so the guard only
  needs to check "task_type==pr OR explicit allow-skeleton override passed" — no fragile caller
  sniffing.
- Additionally found (adjacent, likely out of the named 3-file scope but worth flagging): the
  deployed `.claude/rules/pr-prohibition.md` "Required Behavior" section still states "When
  implementation is complete, agents MUST: 1. Mark the task status as `[PR READY]` ... 3. Wait
  for the user to invoke `/merge`" as if this were universal for all task types. This is stale
  relative to actual behavior (`skill-implementer`, `skill-cslib-implementation`, and the general
  hard-mode agents all transition straight to `[COMPLETED]` via `postflight implement`). This
  doc drift is a second instance of the same "PR READY described as universal terminus" problem
  the task asks to fix in `claudemd.md:36-37`, just in a different file.

## Context & Scope

Task 795 asks for three coordinated source-tree edits (in `/home/benjamin/.config/nvim/.claude/`)
to reserve `[PR READY]`/`pr_ready` for `task_type == "pr"` tasks only, plus a design decision on
where the guard lives. Out of scope: repairing the 5 already-mislabeled deployed cslib tasks
(447/404/407/438/453) — separate manual data repair.

This research verified current behavior of all three named files, traced every caller of
`pr_ready` in the skill layer to determine the full blast radius of a guard, and confirmed the
extension-source vs. deployed-mirror duplication pattern that governs where edits must land.

## Findings

### Codebase Patterns

**1. `update-task-status.sh` current behavior (confirms the leak)**

- Line 66: `target_status` validation accepts `research|plan|implement|pr_ready` — no task_type
  parameter is accepted or read anywhere in the script.
- Lines 93-94 (`map_status` case block):
  ```
  preflight:pr_ready)  STATE_STATUS="pr_ready";      TODO_STATUS="PR READY" ;;
  postflight:pr_ready) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
  ```
- The script never reads `.task_type` from `state.json` today. It does, however, already read
  other per-task fields via `jq` keyed on `project_number` (see `task_exists` at line 105-107,
  `current_state_status` at line 115-117, and `project_name` at line 212-214 inside
  `update_plan_file`). Adding a `task_type` lookup is a straightforward extension of an existing,
  proven pattern — no new plumbing needed:
  ```bash
  task_type=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .task_type // "general"' \
    "$STATE_FILE")
  ```
  This lookup should happen after the existing "task exists" check (~line 112) and before
  `map_status` is called, since the guard needs `task_type` before deciding whether
  `pr_ready` is permitted.
- **Mirror**: `.claude/extensions/core/scripts/update-task-status.sh` is byte-identical to the
  deployed `.claude/scripts/update-task-status.sh` (`diff` exit 0). Both copies exist; the
  extension copy is presumably the source of truth synced to the deployed path by a redeploy
  step (see task 796's mention of "redeployed via `<leader>al>`"). **Both files must end up
  consistent** — either edit the extension source and redeploy, or edit both directly in the
  same commit.

**2. `skill-cslib-implementation` Stage 6 (the actual bug)**

Current text (lines 120-121 of `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`):
```
### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.
```
No status-target value is named. Compare to `skill-pr-implementation` Stage 6 (line 89, "PR
READY" heading) which is explicit and prominent, including a "CRITICAL DIFFERENCE" callout, a
concrete `bash` command, and an explicit "Do NOT call `postflight implement`" warning. An agent
executing `skill-cslib-implementation` with only the vague instruction has nothing analogous to
copy from within its own skill file, and the nearest fully-worked example of a `pr_ready` call in
the neighboring `skill-pr-implementation` file is a very plausible source of copy-paste drift —
this is consistent with the observed leak (cslib implementation tasks landing on `[PR READY]`).

The task's own instruction to "mirror `skill-pr-implementation:95`" should instead mirror the
**correct sibling**, `skill-cslib-implementation-hard` Stage 7 (lines 294-301 of
`.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`), which already gets
this right:
```bash
### Stage 7: Update Task Status (Postflight)
if [ "$status" = "implemented" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
fi
# On partial: keep status as "implementing" for resume
```
Recommendation: rewrite the plain skill's Stage 6 to this exact pattern (`postflight ... implement`,
gated on `status == "implemented"`, with the partial-resume comment), NOT a `pr_ready` call. This
makes the plain and hard cslib-implementation skills structurally symmetric, closing the gap that
most likely caused the leak.

Both the extension source
(`.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`) and its byte-identical
mirror (`.claude/skills/skill-cslib-implementation/SKILL.md`, confirmed via `diff`) need this
change reconciled the same way as item 1's script mirror.

**3. `claudemd.md:36-37` doc reconciliation**

Current text (confirmed at both the merge-source and the deployed `.claude/CLAUDE.md`, which is
line-for-line identical in this section — deployed lines 45-46):
```
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - Implementation + PR phase
- `[PR READY]` -> `[IMPLEMENTING]` - If PR review finds issues (re-dispatch)
```
This presents `[PR READY]` as a universal step of the implementation lifecycle for every task
type, which is inconsistent with actual behavior: `skill-implementer` (general/meta/markdown) and
`skill-cslib-implementation` (once fixed per item 2) both go `[IMPLEMENTING]` -> `[COMPLETED]`
directly. Only `task_type == "pr"` tasks (`skill-pr-implementation`,
`skill-pr-review-implementation`) route through `[PR READY]`.

Recommended replacement text:
```
- `[IMPLEMENTING]` -> `[COMPLETED]` - Standard implementation terminus (general, meta, markdown, cslib, and all other non-pr task types)
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - type=pr only: implementation + PR submission phase
- `[PR READY]` -> `[IMPLEMENTING]` - type=pr only: if PR review finds issues (re-dispatch)
```
This is a merge-source edit; it flows into `.claude/CLAUDE.md` via the existing merge/deploy
mechanism (no separate script was found under `.claude/scripts/` explicitly named for this merge
— the plan should confirm the actual regeneration path, likely part of the extension
install/deploy tooling, e.g. `.claude/scripts/install-extension.sh` or a `/meta`-driven rebuild,
before assuming a manual copy is sufficient).

### External Resources

Not applicable — this is a pure internal agent-system consistency fix with no external API or
library surface.

### The Design Fork (central finding)

The task frames the design decision as binary: "guard in core `update-task-status.sh` (keyed on
`task_type==pr`) vs. pushing `pr_ready`/`PR READY` fully into the cslib extension." Research
shows neither pure option works cleanly, because of the third caller:

**`skill-orchestrate-hard` skeleton-exhaustion routing** (`.claude/skills/skill-orchestrate-hard/SKILL.md`
and mirror, ~lines 389-442, "772 Item 5A"):
```bash
elif [ "$last_skeleton" = "true" ]; then
  ...
  # Transition to pr_ready via the centralized status script (never raw-edit state.json).
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"
  rm -f "$loop_guard_file"
  EXIT (success, pr_ready — skeleton exhausted, ${follow_up_count} follow-up task(s): ${follow_up_tasks})
```
This fires whenever a hard-mode implementation agent's handoff declares `skeleton: true` (a
documented, legitimate "implemented with strategic-sorry placeholder" outcome — see
`anti-analysis.md`) and no incomplete plan-phase heading remains. The `skeleton` field is defined
identically across `general-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
and `cslib-implementation-hard-agent.md` — it is **not cslib-specific**. In practice this means
`/orchestrate --hard` on a `general`, `meta`, `lean4`, or `cslib` task that lands a skeleton will
call `postflight pr_ready` with a `task_type` that is essentially never `"pr"` (pr-type tasks
compose PR descriptions, not proofs, and don't produce skeleton handoffs).

Implications for each pure option:
- **Option A — bare `task_type == "pr"` guard in core script**: breaks this orchestrate-hard path
  outright for every non-pr hard-mode task with a skeleton outcome. This is a regression, not
  just an edge case — skeleton-exhaustion is an intentional, documented terminal state for
  hard-mode orchestration.
- **Option B — move `pr_ready` handling fully into the cslib extension** (e.g., a cslib-specific
  wrapper script instead of the shared `update-task-status.sh`): does not address the
  orchestrate-hard caller at all, since that caller lives in core (`skill-orchestrate-hard` is a
  core skill, not a cslib extension skill) and is task-type-agnostic. Pushing the logic into the
  cslib extension does not give core orchestration a legal way to reach `pr_ready` for its
  skeleton-exhaustion case.

**Recommended resolution**: keep the guard in core `update-task-status.sh` (Option A's location)
but make the predicate `task_type == "pr" OR an explicit orchestrator override flag is passed`,
not a bare `task_type == "pr"` check. Concretely:
- Add a 5th (optional) positional argument or flag to `update-task-status.sh`, e.g.
  `--allow-skeleton` or `--override-guard=skeleton_exhaustion`, that `skill-orchestrate-hard`
  passes explicitly at its skeleton-exhaustion call site (~line 431).
- The guard logic becomes: reject `preflight:pr_ready` / `postflight:pr_ready` unless
  (`task_type == "pr"`) OR (the override flag was passed). This keeps the script as the single
  centralized authority (consistent with the script's existing "never raw-edit state.json"
  design principle, called out in the orchestrate-hard comment itself), avoids task_type sniffing
  fragility, and gives the one legitimate non-pr caller an explicit, auditable escape hatch
  instead of a silent type-based bypass.
- This keeps `pr_ready` semantically anchored to "type=pr OR an explicitly-declared
  skeleton-exhaustion completion," both of which are legible, intentional states — not an
  accidental default reachable by any task type through vague skill instructions (the actual bug
  being fixed).

An alternative worth surfacing to the plan phase (not preferred, but simpler if the plan wants to
avoid script signature changes): reroute `skill-orchestrate-hard`'s skeleton-exhaustion branch
away from `pr_ready` entirely, to the existing `[PARTIAL]` terminal/exception status (already
defined in `.claude/CLAUDE.md`'s Status Markers list) with the follow-up task list recorded in
its summary — arguably a better semantic fit for "skeleton exhausted, follow-ups pending" than
"ready to submit a pull request" was in the first place. This is a larger blast-radius change
(status-sync script, TODO.md rendering, downstream consumers of the `pr_ready` exit message in
orchestrate-hard) and was not requested by the task, so it is flagged as an option rather than a
recommendation; the plan should decide based on how much churn is acceptable given task 795's
tightly scoped 3-edit framing.

### Recommendations

1. **`update-task-status.sh`** (both `.claude/scripts/` and `.claude/extensions/core/scripts/`
   copies): add a `task_type` lookup via `jq` (mirroring the existing `project_name` lookup
   pattern at lines 212-214) immediately after the task-exists check (~line 112). Add a guard
   before `map_status` is invoked (or inside it) that rejects `preflight:pr_ready` and
   `postflight:pr_ready` combinations unless `task_type == "pr"` OR an explicit override
   flag/argument is present. Add the override flag/argument to the script's argument parsing
   (alongside the existing `--dry-run` flag pattern at lines 38-46).
2. **`skill-orchestrate-hard`** (not one of the task's 3 named edits, but a necessary companion
   change to avoid a regression): update the skeleton-exhaustion call site (~line 431 in both
   `.claude/skills/skill-orchestrate-hard/SKILL.md` and its mirror) to pass the new override
   flag/argument. Flag this explicitly to the plan phase as a 4th coordinated edit, or confirm
   with the user/orchestrator whether it should be spawned as a separate follow-up task — but
   shipping items 1 and 3 (the guard) without this change will silently break existing hard-mode
   orchestration runs that land skeletons on non-pr task types.
3. **`skill-cslib-implementation` Stage 6** (both `.claude/extensions/cslib/skills/` source and
   `.claude/skills/` mirror): replace the vague "Update state.json and TODO.md based on result"
   with the explicit `postflight ... implement` call pattern already used correctly in
   `skill-cslib-implementation-hard` Stage 7 (status-gated, with the partial-resume comment).
4. **`claudemd.md:36-37`**: replace the two status-marker lines with the three-line version above
   that explicitly scopes `[PR READY]` to `type=pr`.
5. Flag (do not fix in this task, per its stated scope) the stale "Required Behavior" section of
   `.claude/extensions/core/rules/pr-prohibition.md` (deployed at `.claude/rules/pr-prohibition.md`)
   which still describes `[PR READY]` as a universal completion step for "when implementation is
   complete" — recommend a follow-up task to reconcile this rule doc with the type=pr-only
   scoping once 795 lands, since it is the same category of staleness as the claudemd.md fix but
   in a file outside 795's declared scope.

## Decisions

- The guard belongs in core `update-task-status.sh`, not pushed into the cslib extension —
  the script is already the sole centralized status-mutation authority and the one non-pr
  caller of `pr_ready` (orchestrate-hard's skeleton-exhaustion path) is itself a core-layer
  concern, not a cslib one. Moving the logic into the extension would not give that caller a
  legal path and would fragment the "single centralized status authority" design already in
  place.
- The guard predicate must not be a bare `task_type == "pr"` check; it must accommodate the
  orchestrate-hard skeleton-exhaustion caller via an explicit, auditable override rather than
  silently allowing all task types (which would defeat the fix) or breaking that caller
  (which would be a regression).
- Item 3 (skill-cslib-implementation Stage 6) should copy the pattern from
  `skill-cslib-implementation-hard` Stage 7 (`postflight ... implement`), not restate
  `skill-pr-implementation`'s `pr_ready` pattern — mirroring the latter would be
  self-defeating given the task's own goal.

## Risks & Mitigations

- **Risk**: Shipping the guard without updating `skill-orchestrate-hard`'s skeleton-exhaustion
  call site breaks existing `/orchestrate --hard` completion for any non-pr task type that lands
  a skeleton. **Mitigation**: treat the orchestrate-hard update as a required companion edit (see
  Recommendation 2), not optional polish — the plan phase should size this as part of the same
  task or explicitly spawn a tightly-coupled follow-up that lands atomically with the guard.
- **Risk**: The two mirrored copies of each edited file (`.claude/...` deployed vs.
  `.claude/extensions/{core,cslib}/...` source) could be edited inconsistently, reintroducing
  drift. **Mitigation**: edit both copies in the same commit, or edit the extension source and
  run whatever redeploy step keeps them in sync (referenced as `<leader>al` in task 796's
  description) before considering the task done; verify with `diff` before finalizing.
- **Risk**: The claudemd.md fix, once merged into `.claude/CLAUDE.md`, could still be
  contradicted by the stale `pr-prohibition.md` "Required Behavior" text, confusing future
  readers of the doc set. **Mitigation**: not fixed in this task per its stated scope, but
  explicitly recommended as a fast follow-up (see Recommendation 5) so the inconsistency doesn't
  linger silently.
- **Risk**: `jq` lookups for `task_type` should follow the repo's documented jq safety pattern
  (`select(.type == "X" | not)` instead of `!=`, per `.claude/context/patterns/jq-escaping-workarounds.md`)
  if any `!=`-style comparison is needed in the guard implementation. **Mitigation**: the plan
  should use `==`-based equality checks (`task_type == "pr"`) rather than `!=` comparisons,
  consistent with existing safe patterns already used elsewhere in the script.

## Context Extension Recommendations

- **Topic**: PR-lifecycle status documentation consistency
- **Gap**: `.claude/extensions/core/rules/pr-prohibition.md` "Required Behavior" section
  describes `[PR READY]` as the universal post-implementation status for "when implementation is
  complete," which is stale relative to current per-task-type behavior. Not fixed here (outside
  795's 3-file scope) but should be tracked.
- **Recommendation**: after 795 lands, create a small follow-up task to reconcile
  `pr-prohibition.md`'s "Required Behavior" section with the type=pr-only scoping established by
  this task, so all three docs (`claudemd.md`, `pr-prohibition.md`, and the runtime guard) agree.

## Appendix

- Searches performed: direct file reads of all four named artifacts plus their
  extension-source/deployed-mirror pairs; `grep -rn "pr_ready"` across
  `.claude/skills/*/SKILL.md` and `.claude/extensions/*/skills/*/SKILL.md` to enumerate every
  caller of the `pr_ready` status target; `grep -rn "\"skeleton\""` across
  `.claude/agents/*.md` and `.claude/extensions/*/agents/*.md` to determine whether the
  `skeleton` handoff field is cslib-specific or task-type-agnostic; `diff` checks confirming
  byte-identical mirrors between extension-source and deployed copies of
  `update-task-status.sh`, `skill-orchestrate-hard/SKILL.md`.
- Key file:line references:
  - `.claude/scripts/update-task-status.sh:66` (target_status validation)
  - `.claude/scripts/update-task-status.sh:93-94` (pr_ready map_status entries)
  - `.claude/scripts/update-task-status.sh:212-214` (existing jq-lookup-by-project_number pattern to mirror for task_type)
  - `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md:120-121` (vague Stage 6)
  - `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md:294-301` (correct pattern to mirror)
  - `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md:89-99` (the pr_ready pattern task 795 pointed at, correct for type=pr but wrong model for item 2)
  - `.claude/extensions/core/merge-sources/claudemd.md:36-37` / deployed `.claude/CLAUDE.md:45-46`
  - `.claude/skills/skill-orchestrate-hard/SKILL.md:389-442` (skeleton-exhaustion routing, the un-named third caller)
  - `.claude/extensions/core/rules/pr-prohibition.md:33-39` (adjacent stale doc, flagged not fixed)
