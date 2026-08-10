# Research Report: Task #916

**Task**: 916 - fix_orchestrate_completion_summary_propagation
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Medium (one new shared function, six call-site edits, one dead-code removal)
**Dependencies**: None
**Sources/Inputs**: Codebase inspection only (`agent-system/extensions/core/` source store)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Confirmed, mechanically**: every `/orchestrate` path — base single-task, base multi-task
  (Stage MT-4), and hard-mode single-task — reaches a `completed`/`implemented` transition
  through `skill_postflight_update` (status-only) and never reads `completion_data` out of
  `.return-meta.json`. Hard-mode multi-task reuses base Stage MT-4 verbatim, so it has the
  same hole by inheritance, not by a separate implementation.
- **Root cause is a missing read AND a missing write**, not one or the other:
  - Read side: `.return-meta.json`'s `completion_data.completion_summary` /
    `.completion_data.roadmap_items` are never extracted on any orchestrate path.
    `orchestrate-recover-outcome.sh` already reads this exact file for other fields
    (`phases_completed`, artifact info) but does not expose `completion_data`.
  - Write side: no orchestrate call site ever writes `completion_summary`/`roadmap_items`
    into `state.json`. The write logic exists today ONLY inline inside `skill-implementer`
    and `skill-implementer-hard` (each with its own copy), for the plain (non-orchestrated)
    `/implement` path.
- **`commands/orchestrate.md`'s CHECKPOINT 2 "Populate Completion Summary" step is not just
  ineffective, it is actively dangerous to leave in place while fixing this**: it reads
  `$result_summary`, a variable assigned nowhere in the source store
  (`grep -rn 'result_summary=' agent-system/extensions/core/` returns zero hits), so it always
  writes `completion_summary=""`. It runs unconditionally on every single-task `/orchestrate`
  invocation (not gated on the task having reached `completed`), and it runs AFTER
  `skill-orchestrate`'s own postflight returns. If Stage 5's postflight tail is fixed to write a
  correct `completion_summary` and this step is left untouched, this step will immediately
  overwrite the fix with an empty string on every single-task run. It must be removed as part of
  this fix, not left "harmless."
- **A third, currently-orphaned copy of the write logic already exists**:
  `scripts/orchestrate-postflight.sh` Stage 7b implements the exact same guarded
  `completion_summary`/`roadmap_items` write, but is invoked from nowhere — no skill or command
  file calls it (confirmed by grep across all `skills/*/SKILL.md` and `commands/*.md`). It is
  dead code, not a currently-active third divergent path, but it is exactly the "standing
  recommendation to factor this into a shared script" the task description points at — someone
  started it and never wired it in.
- **Recommended design**: one new shared write function in `skill-base.sh`
  (`skill_propagate_completion_summary`), fed by extending the existing shared reader
  (`orchestrate-recover-outcome.sh`) with two new output fields. Six call sites converge on the
  same function: `skill-implementer`, `skill-implementer-hard`, the orphaned
  `orchestrate-postflight.sh` (cheap to fix while touching this exact logic; prevents a future
  fourth copy if it is ever wired up), `skill-orchestrate` single-task Stage 5, `skill-orchestrate`
  Stage MT-4, and `skill-orchestrate-hard` single-task Stage 5 (hard multi-task inherits the
  MT-4 fix for free).

## Context & Scope

Scope was: (1) confirm whether the single-task `/orchestrate` path has the same hole as the
reported multi-task defect, (2) check `skill-orchestrate-hard` for the same gap in both its
single-task and multi-task paths, (3) design and specify a fix that converges the orchestrator
side onto the same reader (`orchestrate-recover-outcome.sh`) and, ideally, the same writer as the
implementer-side producer contract, per the task's explicit design constraint.

All findings below are from direct inspection of
`agent-system/extensions/core/{commands,skills,scripts,agents,context}/` — the gitignored
`.claude/` tree is a disposable deploy artifact and was not edited or treated as a source of
truth, per the SOURCE-STORE RULE.

## Findings

### 1. Single-task base-mode path (`commands/orchestrate.md` + `skills/skill-orchestrate/SKILL.md`)

**Confirmed dead code in `commands/orchestrate.md:488-495`**:
```bash
completion_summary="$result_summary"
jq --arg summary "$completion_summary" \
  '(.active_projects[] | select(.project_number == '"$task_number"')).completion_summary = $summary' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
`result_summary` is assigned nowhere in the source store. This step also runs unconditionally at
CHECKPOINT 2 regardless of whether the task actually reached `completed` this cycle — it would
stomp `completion_summary=""` onto a task that only got to `researched` or `planned` too, if the
key existed. This code path is reached only for single-task `/orchestrate` — the multi-task
branch explicitly stops before CHECKPOINT 1 (`commands/orchestrate.md:429`).

**Confirmed the skill itself never populates the field either.** `skills/skill-orchestrate/SKILL.md`
Stage 5's "shared postflight tail" (line ~678-741) is the actual mechanism that flips
`implementing` -> `completed`:
```
implemented)
  if skill_gate_completion_claim ...; then
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
  fi
  ;;
```
`skill_postflight_update` (`scripts/skill-base.sh:371-405`) only calls
`update-task-status.sh postflight` (status/timestamps/TODO.md only — verified no
`completion_summary` reference anywhere in `update-task-status.sh`). Nothing anywhere in
`skill-orchestrate/SKILL.md` references `completion_summary`, `roadmap_items`, or
`completion_data` (confirmed by grep — zero hits). So even before CHECKPOINT 2's broken clobber
runs, the field was already never written.

**Consequence**: fixing only the skill without also removing `commands/orchestrate.md:488-495`
would appear to work in isolation but silently regress the moment both run in sequence — the
CHECKPOINT 2 step runs strictly after the skill returns and unconditionally overwrites whatever
the skill just wrote with `""`. Both edits are required together.

### 2. Multi-task base-mode path (`skills/skill-orchestrate/SKILL.md` Stage MT-4)

Confirmed identical absence. Stage MT-4 step 3 (`SKILL.md:1305-1320`) calls
`skill_gate_completion_claim` + `skill_postflight_update` on `dispatch_status = "implemented"`,
exactly mirroring the single-task tail, and likewise never reads or writes
`completion_summary`/`roadmap_items`. This is the directly-observed live-run defect from the task
description, now traced to its exact site.

### 3. Hard-mode single-task path (`skills/skill-orchestrate-hard/SKILL.md`)

Confirmed the same hole, same site shape. Stage 5's shared postflight tail
(`SKILL.md:950-978`)'s `implemented)` case calls `skill_gate_completion_claim` +
`skill_postflight_update` and nothing else — no `completion_data` read or state.json write.

One structural difference from base mode matters for the fix: **hard-mode's implement dispatch
always writes `.orchestrator-handoff.json`** (`general-implementation-hard-agent.md:378`, "Write
`.orchestrator-handoff.json` at end of every dispatch" — part of the H9 wrap-up contract in
`context/contracts/wrap-up.md`). This means hard mode's `implemented` outcome is read from the
**handoff-present branch** of Stage 5, not the `orchestrate-recover-outcome.sh` recovery branch
(that branch only fires when the handoff is missing or stale). The handoff schema itself
(`skill_write_orchestrator_handoff` in `scripts/skill-base.sh:577-601`, and
`docs/architecture/handoff-schema.md`) has no `completion_summary`/`roadmap_items` field at all —
confirmed by inspecting the full `jq -n` template. So for hard mode, simply extending
`orchestrate-recover-outcome.sh`'s output is not sufficient by itself for the primary path; the
fix must invoke that reader a second time at the `implemented` decision point regardless of which
branch supplied `dispatch_status` (see Recommendation, below).

### 4. Hard-mode multi-task path

`skills/skill-orchestrate-hard/SKILL.md:1101-1104`: "Same as base `skill-orchestrate` multi-task
stages (MT-1 through MT-5)." There is no separate hard-mode MT-4. Fixing base Stage MT-4 fixes
hard-mode multi-task for free; no additional edit site exists here.

### 5. The producer side already works, and already has two independently-maintained copies

`skill-implementer/SKILL.md` Stage 7 Steps 2-3 (lines 475-492) and
`skill-implementer-hard/SKILL.md` Stage 7a (lines 363-375) each inline the identical guarded jq:
write `completion_summary` if non-empty; write `roadmap_items` only when
`task_type != "meta"` and the array is non-empty. Confirmed byte-for-byte equivalent logic in
both files (only variable-naming context differs). Both read
`completion_data.completion_summary` / `completion_data.roadmap_items` from
`.return-meta.json` per the schema in `context/formats/return-metadata-file.md:145-160`. This is
the schema the orchestrator side needs to converge onto.

### 6. `scripts/orchestrator-postflight.sh` is a third copy, currently wired to nothing

This script's header explicitly documents "Stage 7b: Write completion_summary + roadmap_items to
state.json (implement only)" with a `SKIP_COMPLETION_DATA` escape hatch clearly designed so a
caller that already did the write inline can skip this stage as "a safety net." However:
```bash
grep -rn "orchestrator-postflight.sh" agent-system/extensions/core/skills/*/SKILL.md \
  agent-system/extensions/core/commands/*.md agent-system/extensions/core/scripts/*.sh
```
returns zero invocation sites — only cross-reference comments in `skill-git-workflow/SKILL.md`,
`update-task-status.sh`, `git-staging-scope.md`, and `return-metadata-file.md` that describe it
as a "shared postflight pipeline" or "completion seam." Nothing sources or calls it. It is dead
code today, not a currently-active divergent path, but it is precisely the artifact the task
description's "standing recommendation to factor that one into a shared script" refers to — the
recommendation was half-executed (a script was written) and never connected.

### 7. `orchestrate-recover-outcome.sh` is the right extension point, confirmed by its own contract

Its header already states: "This script is the ONE place that reads a task's
`.return-meta.json`... so the three call sites (base Stage 5, hard Stage 5, multi-task Stage MT-4
step 1) cannot drift into three separately-maintained recovery rules." It currently emits
`recovered, status, reason, artifact_path, artifact_type, artifact_summary, phases_completed,
phases_total, meta_mtime, window_start` — no `completion_data` fields. Extending its emitted
schema (rather than adding a second, independently-coded reader) both satisfies the script's own
stated charter and the task's explicit design constraint.

## Decisions

- **Converge on one new write function**, `skill_propagate_completion_summary`, added to
  `scripts/skill-base.sh` alongside the existing `skill_propagate_memory_candidates` (Stage
  7b-adjacent). Signature: `skill_propagate_completion_summary "$task_number"
  "$completion_summary" "$roadmap_items" "$task_type"`. Body is exactly the guarded two-write
  logic already duplicated in `skill-implementer`/`skill-implementer-hard`/
  `orchestrator-postflight.sh` (non-empty-guarded `completion_summary`; `task_type != "meta"`
  AND non-empty/non-`"[]"`-guarded `roadmap_items`).
- **Extend `orchestrate-recover-outcome.sh`'s read side**, not add a second reader. Add
  `completion_summary` (`.completion_data.completion_summary // ""`) and `roadmap_items`
  (`.completion_data.roadmap_items // []`) extraction alongside the existing
  `artifact_path`/`artifact_type`/`artifact_summary` extraction (before the `case "$status"`
  switch), and add both to every `emit()` call (all branches, defaulting to `""`/`"[]"` when the
  file is missing/stale/unparseable) so the script's stdout is always safely parseable regardless
  of which branch fires. Add the two fields to the "Output" doc table in the header comment.
- **Six call sites converge on the new function**:
  1. `skill-implementer/SKILL.md` Stage 7 Steps 2-3 -> replace inline jq with
     `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"`.
  2. `skill-implementer-hard/SKILL.md` Stage 7a Steps 2-3 -> same replacement.
  3. `scripts/orchestrator-postflight.sh` Stage 7b -> replace its inline python block with a call
     to the same shell function (source `skill-base.sh` at the top of the script if not already
     sourced). Optional in the sense that the script is currently unreachable, but cheap and
     removes a fourth copy risk if it is ever wired up later; recommended while touching this
     exact logic rather than deferred.
  4. `skill-orchestrate/SKILL.md` single-task Stage 5, `implemented)` case: immediately after
     `skill_gate_completion_claim` passes and `skill_postflight_update` runs, resolve
     `completion_summary`/`roadmap_items` by reusing `$recover_json` if this outcome came from the
     recovery branch earlier in the same Stage-5 invocation (`[ -n "${recover_json:-}" ]`),
     otherwise issue one more call to `orchestrate-recover-outcome.sh "$TASK_DIR"
     "${dispatch_start_ts:-9999999999}"` (handoff-present branch never populated it). Then call
     `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$TASK_TYPE"`.
  5. `skill-orchestrate/SKILL.md` Stage MT-4 step 3, `dispatch_status = "implemented"` branch:
     identical pattern per task — reuse this task's own `$recover_json` from MT-4 step 1 when
     present, else one additional scoped call using this task's `$task_dir`/`$window_start`
     (already computed per-task in step 1). `task_type` is already resolved per task in the MT-2
     routing table / used directly in the MT-4 dispatch context objects (`SKILL.md:1206`), so no
     new lookup is needed.
  6. `skill-orchestrate-hard/SKILL.md` single-task Stage 5, `implemented)` case: identical to (4).
     No separate multi-task edit needed (Finding 4).
- **Remove `commands/orchestrate.md:488-495`** ("Populate Completion Summary (if implemented)")
  entirely rather than trying to fix `$result_summary` — the skill now does this correctly and
  earlier, and this step is both broken and unconditionally destructive if left in place. This
  removal is a required part of the fix, not a separate cleanup.

## Risks & Mitigations

- **Risk**: reusing `$recover_json` across the two Stage-5 branches (recovery vs. handoff-present)
  could silently read a stale value if a future edit reorders the stage. **Mitigation**: guard
  explicitly on `[ -n "${recover_json:-}" ]` (only true when the recovery branch actually ran this
  cycle) rather than assuming based on control flow position; document the reuse inline as the
  existing code style does elsewhere in this stage.
- **Risk**: adding a second `orchestrate-recover-outcome.sh` invocation per completed task (once
  for outcome recovery when needed, once for completion-data lookup) doubles the read cost on the
  hard-mode/handoff-present path. **Mitigation**: this is a single cheap `jq`-backed file read
  against a small JSON file already read at least once per dispatch elsewhere in the same stage;
  no measurable cost concern, and it preserves the "one script reads this file" invariant the
  script's own header mandates — worth the redundant read.
- **Risk**: removing `commands/orchestrate.md`'s CHECKPOINT 2 step outright (rather than fixing
  `$result_summary`) could look like scope creep. **Mitigation**: leaving it in place after fixing
  the skill actively breaks the fix (see Finding 1's "Consequence"); removal is required, not
  optional, and is the minimal correct action once `$result_summary` is confirmed unfixable in
  place (there is no other variable in scope at that checkpoint carrying the implementer's
  summary — it was never threaded through from the skill's return value to the command layer, and
  the skill already owns and completes this responsibility internally now).
- **Risk**: `roadmap_items`'s meta-task exclusion (`task_type != "meta"`) must be evaluated with
  the CORRECT per-task `task_type` in Stage MT-4 (a multi-task batch can mix task types). Already
  handled: `task_type` is resolved and kept per-task throughout MT-2/MT-4 today (used directly in
  each task's own dispatch context object), so no cross-task leakage risk exists as long as the
  existing per-task variable is threaded into the new call exactly as it already is into the
  dispatch context.

## Context Extension Recommendations

- **Topic**: `docs/architecture/handoff-schema.md` documents the `.orchestrator-handoff.json`
  schema but does not currently note that `completion_summary`/`roadmap_items` deliberately live
  only in `.return-meta.json`'s `completion_data`, never in the handoff. **Gap**: a future reader
  extending the handoff schema could reasonably assume completion metadata belongs there instead,
  recreating this exact defect in a new form. **Recommendation**: add a short note to that doc (or
  to `context/formats/return-metadata-file.md`) stating explicitly that completion metadata is
  read exclusively via `orchestrate-recover-outcome.sh` regardless of handoff presence, once the
  fix above lands.

## Appendix

Key commands used (representative, not exhaustive):
```bash
grep -rn 'result_summary=' agent-system/extensions/core/
grep -n "completion_summary\|roadmap_items\|result_summary" agent-system/extensions/core/commands/orchestrate.md
grep -n "completion_summary\|roadmap_items" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
grep -n "completion_summary\|roadmap_items" agent-system/extensions/core/skills/skill-implementer/SKILL.md agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md
grep -rn "orchestrator-postflight.sh" agent-system/extensions/core/skills/*/SKILL.md agent-system/extensions/core/commands/*.md agent-system/extensions/core/scripts/*.sh
grep -rn "skill_write_orchestrator_handoff" agent-system/extensions/core/
```
Files read in full or in relevant part: `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
`skills/skill-orchestrate-hard/SKILL.md`, `scripts/orchestrate-recover-outcome.sh`,
`scripts/skill-base.sh`, `scripts/orchestrator-postflight.sh`, `skills/skill-implementer/SKILL.md`,
`skills/skill-implementer-hard/SKILL.md`, `context/formats/return-metadata-file.md`,
`agents/general-implementation-hard-agent.md`.
