# Implementation Summary: Task #995

- **Task**: 995 - Convert surviving extension state.json writers to state-write.sh
- **Status**: [COMPLETED]
- **Started**: 2026-08-09
- **Completed**: 2026-08-09
- **Effort**: ~9 hours (across an interrupted first dispatch and this resuming dispatch)
- **Dependencies**: 983 (skill-skeleton collapse, COMPLETED/archived), 984 (state schema/status vocabulary, COMPLETED)
- **Artifacts**: plans/01_convert-extension-state-writers.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Every hand-rolled `jq ... specs/state.json > <staging> && mv <staging> specs/state.json`
sequence surviving in the source store (founder/skills, present/skills, lean/skills,
cslib/skills, founder/present/epidemiology commands/, and two core residuals) now routes through
`.claude/scripts/state-write.sh`. A permanently-wired `lint-state-writer-boundary.sh` lands with
its own fixture test and a new `verify-deploy.sh` gate 12, so the anti-pattern class cannot
silently return. This dispatch resumed a prior run that was interrupted mid-fan-out: phases 1-8
were found already committed and were verified (not re-done) before phases 9-10 were completed.

## What Changed

- `agent-system/extensions/founder/skills/*/SKILL.md` (15 files) — hand-rolled writes converted (Phase 2, prior dispatch)
- `agent-system/extensions/present/skills/*/SKILL.md` (5 files) — hand-rolled writes converted (Phase 3, prior dispatch)
- `agent-system/extensions/lean/skills/*/SKILL.md` (4 files) — hand-rolled writes converted (Phase 4, prior dispatch)
- `agent-system/extensions/cslib/skills/{skill-pr-implementation,skill-pr-review-implementation,skill-pr-review-research,skill-cslib-vet,skill-cslib-research-hard}/SKILL.md` — individually-reviewed conversions, including the `$CSLIB_STATE` hardcoded-absolute-path bug fix (Phase 5, prior dispatch)
- `agent-system/extensions/{founder,present}/commands/*.md`, `agent-system/extensions/epidemiology/commands/epi.md` (16 files) — task-creation sites converted, `next_project_number` bump and `.active_projects` append kept in one `state-write.sh` call (Phase 6, prior dispatch)
- `agent-system/extensions/core/commands/review.md`, `agent-system/extensions/core/context/formats/command-structure.md` — reviews-state-file writes converted via `--state-file`, illustrative doc example corrected (Phase 7, prior dispatch)
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` (new) — regex lint detecting hand-rolled `state.json` writes, with a documented `$CSLIB_STATE`-class blind spot (Phase 8, prior dispatch)
- `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` (new) — 8-case fixture test (Phase 8, prior dispatch)
- `agent-system/extensions/core/manifest.json` — two new `provides.scripts` entries for the lint and its test (Phase 9, this dispatch)
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new gate 12 running the lint against the source store (Phase 9, this dispatch)
- `agent-system/extensions/core/index-entries.json` — `command-structure.md` `line_count` corrected from 982 to 985, re-derived after Phase 7's edit to that file (Phase 9, this dispatch, surfaced by the redeploy's doc-lint gate)
- `specs/995_convert_extension_state_writers_to_state_write/plans/01_convert-extension-state-writers.md` — stale phase-heading markers reconciled against verified committed diffs (this dispatch)

## Decisions

- Reconciled the plan's phase markers against actual git history before doing any new work: read
  each of phases 3-7's commit diffs and re-ran their directory-scoped greps, confirming every
  file matched the plan's declared file-set before marking them `[COMPLETED]`, rather than
  trusting or re-doing them.
- While Phase 9 was in progress, two other previously-dispatched sub-agents (phase6-commands,
  phase8-lint-authoring) finished and committed their own work concurrently; their commits were
  verified (diff, grep, fixture test) before being counted as done, rather than re-executed.
- Phase 9 is closed `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`: gate 12 (the new
  lint) passes cleanly in every run, but `verify-deploy.sh`'s overall exit stays red due to a
  pre-existing, unrelated `REPO_ROOT` path-depth defect in five `tests/run-all.sh` suites (last
  touched by an unrelated task) plus one unrelated `EXTENSION.md`-length assertion — none of
  which any phase of this task touches. Fixing that defect was judged out of scope for a
  state-writer-conversion task and is recorded as a follow-up instead of silently absorbed or
  used to justify weakening gate 12.

## Plan Deviations

- **Phase 9** closed as `[COMPLETED WITH EXCLUSIONS]` instead of `[COMPLETED]`: see the Reasoned
  Exclusions table in the plan's Phase 9 section for the full evidenced accounting of the one
  pre-existing, out-of-scope `verify-deploy.sh` gate-8 residual.

## Verification

- Build: N/A (markdown/shell source store; no compiled artifact)
- Tests: Passed — `test-lint-state-writer-boundary.sh` 8/8; `verify-deploy.sh` 22/23 checks
  (gate 12 passes; see Plan Deviations for the one excluded, pre-existing, unrelated gate-8
  residual)
- Files verified: Yes — every phase's directory-scoped grep, `bash -n` fence check, and (for
  Phase 5) direct file read confirmed clean

### Full-source-store grep result (with exclusion list, per the task's verification bar)

```
grep -rn 'mv .*state\.json\|state\.json > \|> .*state\.tmp\|> .*state\.json\.tmp' \
  agent-system/extensions/ --include="*.md" --include="*.sh"
```

Returns **19 raw hits**, all evidenced against the plan's six enumerated exclusion classes (the
Scope Boundary Resolution table's classes 1-6), with two classes gaining new, in-scope instances
introduced by this task's own Phase 8 artifacts:

1. **`state-write.sh` itself** (1 hit: `scripts/state-write.sh:6`) — it IS the sanctioned writer; the hit is header-comment prose describing the anti-pattern it replaces.
2. **Bare `mv` vault-rename, not a jq-staged write** (3 hits: `commands/todo.md:871`, `skills/skill-todo/SKILL.md:680`, `scripts/deprecated/vault-operation.sh:129`) — a file relocation with no temp path or transform.
3. **`jq -e ... > /dev/null` read-only existence checks** (4 hits: `commands/task.md:442`, `context/orchestration/validation.md:281,286,339`) — read state, write nothing.
4. **Test fixtures deliberately constructing corrupt/dirty state** (2 original hits in `scripts/tests/test-update-task-status.sh:329-330`, **plus 4 new hits in this task's own `scripts/tests/test-lint-state-writer-boundary.sh:5,67,121,141`**) — the new lint's own fixture file intentionally contains a hand-rolled write pattern as its "must-fail" test case; converting it would defeat the test, exactly the same reasoning as the pre-existing exclusion.
5. **Illustrative/prose anti-pattern description, not a live writer** (1 original hit in `context/patterns/jq-escaping-workarounds.md:255`, **plus 4 new hits in this task's own `scripts/lint/lint-state-writer-boundary.sh:6,41,173,181`**) — the lint's header comment documents the anti-pattern it detects, in prose, matching the same class as the pre-existing doc-pattern exclusion. (`context/patterns/task-lock.md` contributes 0 matching lines, as recorded in the Phase 1 baseline.)
6. **`base_branch`/`forcing_data` schema non-conformance** — not a grep-matching class; a semantic non-goal (changing *what* is written is out of scope), carried forward as a deferred follow-up below.

11 hits belong to the original five grep-matching classes (1-5) recorded in Phase 1's baseline;
8 new hits belong to the same two classes (4 and 5) but are contributed by this task's own
Phase 8 lint and fixture-test files. Zero hits are unclassified.

### Dry-run smoke test

`state-write.sh --dry-run` validated the converted filter/binding shape for both:
- Founder (`skill-market`'s status-update filter): `[dry-run] filter applies cleanly; no write performed, no mutex acquired.`
- Present (`skill-budget`'s status-update filter): `[dry-run] filter applies cleanly; no write performed, no mutex acquired.`

### `$CSLIB_STATE` confirmation (by reading, not grep, per the lint's documented limitation)

Read `agent-system/extensions/cslib/skills/skill-pr-implementation/SKILL.md` directly: Stage 7
now writes `specs/state.json` (project-relative, default target) via `state-write.sh` with no
`--state-file` argument and no `CSLIB_DIR`/`CSLIB_STATE` reference anywhere in the file
(confirmed by both direct read and a targeted grep returning zero).

## Impacts

- Every extension task-creation and status-update write site (founder, present, lean, cslib,
  epidemiology, plus two core residuals) is now serialized through `state-write.sh`'s mutex,
  closing the `next_project_number` race window that existed under the old unserialized
  hand-rolled sequences.
- `lint-state-writer-boundary.sh`, wired as `verify-deploy.sh` gate 12, prevents the anti-pattern
  class from silently returning in future extension work.

## Follow-ups

- **`base_branch`/`forcing_data` schema non-conformance** (deferred per this plan's Non-Goals): changing *what* any site writes was explicitly out of scope for this conversion task.
- **Variable-indirected write blind spot**: `lint-state-writer-boundary.sh` is a regex lint and cannot catch a variable-indirected write (the `$CSLIB_STATE` class this task fixed) if a similar pattern is reintroduced elsewhere; the lint's header documents this, and the dry-run smoke test plus direct-read verification are the compensating control, not a proof of absence.
- **Newly discovered, out-of-scope**: `verify-deploy.sh` gate 8 (`tests/run-all.sh`) carries a pre-existing `REPO_ROOT` path-depth defect (`$SCRIPT_DIR/../../../../..` resolves 5 levels up from `.claude/scripts/tests`, landing at `/home/benjamin` instead of this repo's actual root `/home/benjamin/.config/nvim`, which is only 3 levels up) affecting `test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`, `test-resume-scan-nonconformance.sh`, `test-skill-base-lifecycle.sh`, and `test-update-task-status.sh`, plus an unrelated `test-index-entries-schema.sh` "Rule U" (`EXTENSION.md` length) assertion failure. None of these files are touched by any phase of this task; `git log` confirms they predate this task (e.g. `test-loop-guard-staleness.sh` was last touched by an unrelated prior task). Recorded here as a candidate for a dedicated follow-up task rather than fixed in-scope.

## References

- `specs/995_convert_extension_state_writers_to_state_write/plans/01_convert-extension-state-writers.md`
- `specs/995_convert_extension_state_writers_to_state_write/baseline/01_grep-baseline-and-recipe.md`
- `specs/995_convert_extension_state_writers_to_state_write/reports/01_convert-extension-state-writers.md`
