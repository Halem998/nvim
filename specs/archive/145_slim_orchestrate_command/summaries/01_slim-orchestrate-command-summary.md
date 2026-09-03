# Implementation Summary: Task #145

- **Task**: 145 - Slim `commands/orchestrate.md` to the flag table and the dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-09-02
- **Completed**: 2026-09-02
- **Effort**: ~7 hours
- **Dependencies**: 149 (team-mode deletion — already landed)
- **Artifacts**: plans/01_slim-orchestrate-command.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Slimmed `agent-system/extensions/core/commands/orchestrate.md` from 44,953 B / 790 lines to
18,687 B / 384 lines (58.4% reduction) by relocating two orphaned contract units to
`docs/architecture/orchestrate-state-machine.md`, moving multi-task batch-output ownership to
`skill-orchestrate` Stage MT-5, deleting the `### MULTI-TASK DISPATCH` block (Steps 1-5, 28,059 B
including the Kahn's-algorithm wave-assignment pseudocode), installing a compact STAGE 0 that
retains full dispatch functionality, repointing ~25+ cross-references off the deleted Step
numbers, and adding the missing `--hard` Options row. The measured final byte count (18,687 B)
exceeds the 8,000 B target — reported honestly below with the specific cause, per the task's
explicit instruction not to gut a semantic to hit the number.

## What Changed

- `agent-system/extensions/core/commands/orchestrate.md` — deleted `### MULTI-TASK DISPATCH`
  (Steps 1-5); installed a compact STAGE 0 (parse + per-flag threading + dry-run short-circuit +
  dry-run prohibition block + single/multi-task branch + compact multi-task dispatch: validation
  loop, Pre-Dispatch Review call, intra-batch dependency-graph build, MAX_TASKS guard, `waves`
  diagnostic-echo, Skill invocation with the identical 14-key delegation context); added the
  `--hard` Options row; updated the phase-forcing flags' stale "single-task only" wording; tightened
  prose across Options, Constraints, CHECKPOINT 1, STAGE 2, CHECKPOINT 3, Output, Error Handling,
  and STAGE 0's own narration.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — added
  `### Batch Size Cap (MAX_TASKS)` (verbatim guard + trim wording); extended
  `### Commit Granularity` with the Exit-Path Coverage table (all six outcome rows) and the
  residue-check bash block; reworded the line-424 self-reference to name this document as the
  source of truth for commit granularity.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-5 now READs and
  emits `orchestrate-batch-results-template.md` itself (the one instruction whose absence would
  silently drop all multi-task batch output), owns the re-run-sequence derivation and the residue
  check, and computes `validated_count = length(task_numbers)` for the template. Stage MT-1's
  `waves` field reclassified as a diagnostic echo. ~14 Step-number/MULTI-TASK-DISPATCH references
  repointed to Stage MT-3 step 4.5 / Stage MT-5 / the template file. `force_phases` threading-site
  count corrected (8 → 6, post-deletion).
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`,
  `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/multi-task-operations.md`, `context/patterns/file-footprint-overlap.md`,
  `context/patterns/orchestrate-batch-results-template.md`,
  `context/standards/orchestrator-runtime-files.md`,
  `scripts/orchestrate-dry-run-report.sh`, `scripts/orchestrate-predispatch-review.sh`,
  `scripts/orchestrate-triage-classify.sh` — cross-reference repoints off the deleted Step
  numbers and the `MULTI-TASK DISPATCH` section name (comment-only in the scripts).
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` — Case 2 rewritten: its
  grep assertions previously checked that `commands/orchestrate.md` still contained the
  `file_session_id`/`mt_state_file_valid` comparison logic deleted in Phase 4. Rewritten to verify
  the structural guarantee that makes the retired check unnecessary (`skill-orchestrate` Stage
  MT-1 always initializes `mt_state_file` fresh, unconditionally, every invocation).
- `agent-system/extensions/core/index-entries.json` — corrected two `line_count` drifts this
  task's own edits introduced (`patterns/batch-orchestration-guardrails.md` 926→923,
  `patterns/orchestrate-batch-results-template.md` 163→164).

## Decisions

- **Step 1.5 Pre-Dispatch Review call**: retained as a one-line advisory invocation inside the
  compact multi-task block (plan's stated default), because it is the only visibility surface
  Non-Negotiable 3 relies on for out-of-batch/nonexistent `dependencies[]` edges. Not dropped.
- **`waves` field**: kept required (Stage MT-1 would otherwise read an absent key) but reclassified
  as a diagnostic echo — a single row of all validated tasks — since eligibility is re-derived
  fresh every cycle at Stage MT-3 step 4.5 and nothing reads the field otherwise.
- **`dependency_graph`**: kept computed and passed from the compact STAGE 0 block, since it is
  hard-required at Stage MT-3 step 3 eligibility and is itself just a narrowed read of
  `specs/state.json`'s `dependencies[]`.
- **MAX_TASKS=8 executable guard**: kept in the compact block (executing behavior, not
  documentation) even though its narrative text moved to `orchestrate-state-machine.md`.
- **Wave-split defense-in-depth note**: NOT relocated — already near-verbatim covered in
  `multi-task-operations.md`'s "File Footprint Overlap as a Serialization Edge".
- **Byte target**: pursued honestly via prose tightening only; did not cut any semantic on
  Decision 2's stop-list to force the number down.

## Plan Deviations

- **Task 1.2** (optionally widen `file_scope`): skipped deliberately — the excursion advisory is
  expected and benign per the plan's own risk table.
- **Task 3.10** (recount `force_phases` threading sites): deferred from Phase 3 to Phase 5 as the
  plan explicitly permits, once the post-deletion tree existed to count against (8 → 6 sites).
- Beyond the plan's explicit task list: tightened STAGE 0's own prose narration in Phase 6 (not
  named in Decision 2's tightening list, which named only CHECKPOINT 3 / Output / Error Handling /
  Options / CHECKPOINT 1 / STAGE 2) — necessary because STAGE 0 is the single largest section
  (~40% of the file) and Decision 2's own list, taken alone, could not approach the target.
- A regression not anticipated by the plan was found and fixed: `test-session-runtime-files.sh`
  Case 2 broke once Phase 4 deleted the `file_session_id` comparison logic it grep-asserted
  against. Fixed in Phase 5 (see What Changed).
- Byte target **not met**: final measured 18,687 B against the 8,000 B target (honest floor
  projected by the plan itself was 8,000-9,200 B). See Verification below for the root-cause
  breakdown; no semantic was cut to approach the number.

## Verification

- Build: N/A (markdown/prose command file plus prose docs)
- Tests: `run-all.sh` — PASS ("all discovered suites passed", 0 failures)
- Full gate run (`verify-deploy.sh`): 3 of 30 checks failed, all three matching the documented
  pre-existing list exactly:
  - gate3 (doc-lint): `patterns/postflight-control.md` (318→405), `schemas/state-schema.json`
    (267→271), `project/literature/patterns/zotero-item-creation.md` (208→234) line_count
    mismatches — pre-existing, untouched.
  - gate10 (`validate-state.sh --deep`): unknown `state.json` entry fields
    (`abandon_reason`/`blocks_note`) — pre-existing.
  - gate12 (state-writer boundary lint): hand-rolled writes in `test-force-phases.sh` —
    pre-existing.
  - gate8 (`run-all.sh` intermittent timing flake): did NOT fire this run.
  - No failure outside this documented set was observed.
- `/orchestrate --dry-run 145` (single task): produced the full admission report.
- `/orchestrate --dry-run 143 142` (two-task batch, both genuinely non-terminal): produced the
  full multi-task admission report (ZERO DISPATCH banner, per-candidate exclusion reasons with
  reasons, re-run sequence `/orchestrate 142` / `/orchestrate 143`).
- All 12 bash fences in the slimmed `orchestrate.md` pass `bash -n`.
- Flag coverage: all 15 `parse-command-args.sh`-consumed flags documented in `## Options`
  (`--lit, --dry-run, --allow-self-modifying, --allow-scope-collision, --continue-budget, --clean,
  --fast, --hard, --haiku, --sonnet, --opus, --fable, --research, --plan, --implement`);
  `--force`/`--local`/`--exploit`/`--explore` correctly absent; no `--team`/`--team-size`.
- Checkpoint order intact: STAGE 0 → CHECKPOINT 1 → STAGE 2 → CHECKPOINT 2 → CHECKPOINT 3.
- Dry-run prohibition block present, semantically unchanged (only its dangling "MULTI-TASK
  DISPATCH" phrase retargeted to "multi-task dispatch below").
- `## Anti-Bypass Constraint` and `## Arguments` verified byte-identical to the pre-task baseline.
- `git status`: no hand-authored file under `.claude/**` (confirmed gitignored via
  `git check-ignore .claude/`); all edits under `agent-system/extensions/core/**`.

### Byte-count root-cause breakdown (target 8,000 B; measured 18,687 B)

| Section | Target (Decision 2) | Measured | Delta |
|---|---|---|---|
| frontmatter + title | 546 | 545 | -1 |
| Arguments | 318 | 318 | 0 |
| Constraints | ~650 | 661 | +11 |
| Options (+`--hard`) | ~1,900 | 2,556 | +656 |
| Anti-Bypass Constraint | 230 | 230 | 0 |
| Execution heading | 14 | 14 | 0 |
| STAGE 0 | ~1,800 | 7,576 | **+5,776** |
| CHECKPOINT 1 | ~600 | 848 | +248 |
| STAGE 2 | ~950 | 1,074 | +124 |
| CHECKPOINT 2 | 262 | 262 | 0 |
| CHECKPOINT 3 | ~1,000 | 2,555 | +1,555 |
| Output | ~550 | 1,498 | +948 |
| Error Handling | ~400 | 550 | +150 |
| **Total** | **~9,200** | **18,687** | **+9,487** |

Nearly two-thirds of the overage (5,776 of 9,487 B) is concentrated in STAGE 0 alone. The plan's
own Decision 2 required the compact multi-task block (validation loop, Pre-Dispatch Review call,
intra-batch `dependency_graph` build, `MAX_TASKS` guard, and the `Skill` invocation with its full
14-key JSON delegation block) to remain in this file — none of that content is a candidate for
removal under the stop-list. The plan's ~1,800 B STAGE 0 estimate assumed this content would net
to near-zero after the `MULTI-TASK DISPATCH` deletion; in practice the retained functional content
alone is roughly 3,668 B of bash/JSON fences that cannot shrink without breaking the key-set or
deleting logic the plan requires kept. The remaining ~3,700 B of overage is spread thinly across
Options (new `--hard` row plus already-tight remaining rows), CHECKPOINT 3 (both full bash fences
required verbatim), and Output (all five outcome lines plus the required example table row) — each
already tightened to what the "keep every listed semantic" stop-list allows.

## Impacts

- `/orchestrate` invocations pay a smaller per-invocation context cost reading this command file
  (58.4% smaller), though not the full reduction PATH.md A.1 targeted.
- Multi-task batch output rendering now lives entirely inside `skill-orchestrate` Stage MT-5,
  making the skill self-sufficient for reporting — a prerequisite for the future
  `orchestrate-cycle-plan.sh` work (PATH row 147) that will absorb the dependency-graph
  construction retained here.
- No change to live `/orchestrate N,M` behavior: admission, eligibility, deferral, locking, and
  dispatch all continue to run exactly as before.

## Follow-ups

- The `waves` key and the STAGE 0 dependency-graph build are earmarked for removal/absorption by
  `orchestrate-cycle-plan.sh` (PATH row 147) — do not remove them piecemeal before that task lands.
- Further byte reduction, if still desired, would require either accepting the plan's ~9,200 B
  honest floor as the real target (revising PATH.md A.1's stated 8,000 B), or a follow-up task to
  extract more of the compact multi-task block's narration into `orchestrate-state-machine.md`
  (though its *executable* bash content would still need to stay here per the Anti-Bypass
  Constraint's "delegate via Skill tool" contract for lifecycle phases, and the state machine doc
  is documentation, not an executed dispatch path).
- `EXPLOIT_FLAG`/`EXPLORE_FLAG` remain orphaned in `parse-command-args.sh` (explicitly out of
  scope for this task).

## References

- `specs/145_slim_orchestrate_command/plans/01_slim-orchestrate-command.md`
- `specs/145_slim_orchestrate_command/reports/01_slim-orchestrate-command.md`
- `specs/PATH.md` (Stage A row A.1)
