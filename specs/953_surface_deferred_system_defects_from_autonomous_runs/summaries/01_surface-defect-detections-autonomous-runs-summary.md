# Implementation Summary: Task #953

- **Task**: 953 - Surface deferred system-defect detections from autonomous runs
- **Status**: [COMPLETED]
- **Started**: 2026-08-08T12:08:00Z
- **Completed**: 2026-08-08T13:55:00Z
- **Effort**: ~1.8 hours
- **Dependencies**: prerequisite recorder task (`system-defect-record.sh` + wired detection sites) — already merged
- **Artifacts**: plans/01_surface-defect-detections-autonomous-runs.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a run-scoped, append-only `detected_defects` observation log to both `/orchestrate`
engines, mirroring the existing `defer_ledger` shape. Every system-defect detection that fires
during an autonomous run is now visible twice: immediately, via a uniformly-tagged
`[system-defect:auto]` transcript notice, and at the end, via an enumerated table in the
consolidated summary. All eleven live detection sites are wired, postflight metadata carries the
log on all four output paths, and the rendering exists for both batch and single-task output.
The mechanism is pure bash/jq plus markdown — it creates no task, adds no interactive step, and
never calls `AskUserQuestion`.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 canonical
  `detected_defects` declaration (entry shape, unconditional-append rule, notice format,
  absolute no-prompt constraint, MUST-NOTs, ADDITIVE-never-merged clause); Stage 2 loop-guard
  fresh-init plus both read paths; Stage 5 `append_detected_defect` helper and five wiring points
  (four in-file recorder sites plus a new gate-refuse `else` branch); Stage MT-4
  `append_detected_defect_mt` idiom and three wiring points; Stage 8 clean-exit and partial-exit
  metadata merges; Stage MT-5 steps 1/3/4/5 propagation, never-consulted statement, and
  distinct-category reporting instruction.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 2 loop-guard
  fresh-init plus both read paths with a pointer back to the base file's single canonical
  contract; Stage 5 hard-mode twin helper and five wiring points (the gate discriminant extends
  the file's pre-existing `else` branch rather than adding a second one); a net-new Stage 8
  metadata-merge subsection (the stage previously had none at all) plus a retitle from "Cleanup"
  to "Postflight and Cleanup".
- `agent-system/extensions/core/commands/orchestrate.md` — new `### System Defects Detected`
  section in the batch consolidated-output template, between
  `### Pre-Existing Deploy-Verify Failures (Not Deferred)` and `### Next Steps`; a matching
  single-task defects block in `## Output` that explicitly covers `/orchestrate --hard`.

## Decisions

- **`record_result` records, never gates.** Every recorder call had only the `>/dev/null` half of
  its `>/dev/null 2>&1` redirect dropped, so the recorder's dedup/suppression verdict is captured
  into the ledger entry while stderr stays discarded and the non-fatal `|| echo` tail stays
  intact. The append itself is unconditional: a detection suppressed as a cross-run duplicate
  still fired during this run and is still surfaced.
- **The `skill-base.sh` site is covered from its callers.** All three callers of
  `skill_gate_completion_claim` already hold `$phases_total` and `$plan_markers_verified`, which
  is exactly the Case-3/3 discriminant. Re-deriving the case caller-side keeps
  `scripts/skill-base.sh` unmodified while still reaching all three call sites. Case 1 (ordinary
  incomplete-phase refusal) deliberately does not append.
- **Hard mode's Stage 8 needed a net-new block, not a field.** It had zero metadata-merge
  statements and zero `cycles_used`/`final_state` occurrences. `cycles_used` and `final_state`
  were written alongside `detected_defects` because a block mirroring base mode's would be
  structurally malformed without them; an in-place comment says so, so a later reader does not
  mistake this for a general hard-mode metadata backfill.
- **The log never affects a verdict.** It is never read by any eligibility check, all-terminal
  check, circuit breaker, convergence guard, admission branch, or `exit_status` branch, and both
  the base declaration and MT-5 step 3 state this explicitly so a later pass does not "fix" a
  defect-observing successful batch into `"partial"`.
- **`:tier-c` was not normalized.** Hard mode's existing recorder call uses `:tier-c` where base
  uses `:stage-5-tier-c`; the on-disk string was reused so each ledger entry's `detecting_site`
  matches the durable `specs/events.jsonl` record for the same firing.

## Plan Deviations

- **Task 8.5** altered: the no-interactive check asserted `grep -c AskUserQuestion` equals the
  pre-change baseline on all three files. Phase 1 mandates naming that constraint in the MT-1
  declaration, which is itself one prose occurrence, so the base skill's raw count went 0 → 1.
  Call sites remain 0 (base), 3 (hard, all pre-existing Stage 6), 0 (command doc). The check was
  implemented as call-site-count equality with both numbers recorded, which preserves its intent.
- **Task 8.10** altered: `verify-deploy.sh` gate 5 reported 3 findings, all "Content differs from
  source" naming exactly the three edited files — the expected deploy-pending state, not a defect
  in the change. Resolved by running the sanctioned `deploy-headless.sh`, never by hand-authoring
  `.claude/**`. Post-deploy the full gate set is 19 checks, 0 failures.

## Verification

- Build: N/A (markdown specification files)
- Tests: Passed — `verify-deploy.sh` reports 19 checks, 0 failures (includes doc-lint,
  task-reference lint, manifest content-hash parity, agent-contract lint, routing-wiring lint,
  and the full shell test suite).
- Files verified: Yes

**Phase 8 audit numbers (recorded, not merely asserted)**:

| Check | Base | Hard | Command doc |
|-------|------|------|-------------|
| Helper definitions | 1 | 1 | — |
| Single-task append call sites | 5 | 5 | — |
| Stage 2 fresh-init field | 1 | 1 | — |
| Stage 2 read paths wired | 2 | 2 | — |
| Stage 8 merge key sites | 2 | 2 | — |
| MT idiom definitions | 1 | 0 (intentional) | — |
| MT wiring points | 3 | 0 (intentional) | — |
| Total `detected_defects` occurrences | 24 | 16 | 4 |
| Occurrences inside a gate/branch construct | 0 | 0 | 0 |
| Appends nested in a `record_result`/`SUPPRESSED` conditional | 0 | 0 | — |
| `AskUserQuestion` call sites (baseline → now) | 0 → 0 | 3 → 3 | 0 → 0 |
| Single-task Stage 8 status values | implemented, partial | implemented, partial | — |

Base and hard report identical single-task numbers across every row — the parity audit found no
asymmetry. The six jq programs touched by Phases 1-6 were each extracted and executed with stub
arguments; all parse and behave correctly, including the `null + [entry]` self-heal for a
loop-guard file written before the field existed. `check-task-references.sh` exits 0 with 0
findings, and no tracked path under `.claude/` was modified.

## Impacts

- A defect firing during any `/orchestrate` run — base or hard, single-task or batch — is now
  announced in the transcript at detection time and enumerated at postflight, instead of landing
  only in `specs/events.jsonl` where an operator may never look.
- Hard mode's single-task path now writes `.return-meta.json` at all, closing a structural gap
  where it previously wrote no metadata whatsoever at loop termination.
- `.return-meta.json` and `.return-meta-multi.json` gain a `metadata.detected_defects` key.
  Neither file's top-level `status` vocabulary changed, so no downstream consumer that branches
  on `status` is affected.
- Every change is additive (new field, new appends, new notices, new metadata keys, two new
  rendering sections), so a revert is a clean `git revert` of the phase commits. The `// []`
  forward-compatible reads mean a runtime state file written by either version is read correctly
  by the other.

## Follow-ups

- The interactive lane (turning a surfaced detection into a task) is a separate, parallel
  downstream concern and was explicitly out of scope here; this change overlaps it on no file.
- The pre-existing `AskUserQuestion` in hard mode's Stage 6 blocker escalation remains as-is —
  flagged in the plan as adjacent prior art, explicitly out of scope, and byte-for-byte unchanged.
- Hard mode's broader metadata gap is only partially closed: Stage 8 now writes `status`,
  `cycles_used`, `final_state`, and `detected_defects`, but nothing else about hard-mode metadata
  was backfilled, and the in-place comment says so.

## References

- `specs/953_surface_deferred_system_defects_from_autonomous_runs/plans/01_surface-defect-detections-autonomous-runs.md`
- `specs/953_surface_deferred_system_defects_from_autonomous_runs/reports/01_surface-deferred-system-defects.md`
- `specs/953_surface_deferred_system_defects_from_autonomous_runs/progress/phase-1-progress.json` … `phase-8-progress.json`
- `.claude/context/patterns/system-defect-discrimination.md`
- `.claude/rules/source-store-deploy-boundary.md`
