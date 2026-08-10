# Implementation Summary: Task #1004

- **Task**: 1004 - Fix /todo repository-metrics sync: build_errors is structurally always 0 and the technical_debt frontmatter target does not exist
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T00:00:00Z
- **Completed**: 2026-08-10T02:10:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_repository-metrics-sync-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md

## Overview

The `/todo` command's "Sync Repository Metrics" stage carried a `build_errors` probe that was
structurally always green (`if cmd_a || cmd_b || true; then ... fi`), an instruction to write
TODO.md frontmatter that no generator emits and no consumer reads, a `status` vocabulary
(`"needs_attention"`) absent from the declared schema enum, and a `jq` filter referencing an
undefined `$build_errors` binding. All four defects are fixed by extracting the probe out of
markdown prose into a real, executable, fixture-tested script
(`scripts/assess-repo-health.sh`), reconciling the schema, rewriting `todo.md` as a thin call
site, and wiring/deploying both new files through the manifest-driven deploy pipeline.

## What Changed

- `agent-system/extensions/core/scripts/assess-repo-health.sh` — new standalone script. Emits the
  whole `repository_health` object as JSON: `bash -n`/`jq empty` structural probe over
  `git ls-files`-or-`find`-enumerated `*.sh`/`*.json`, TODO/FIXME counts over the historical
  `*.lua *.py *.js *.ts *.tex` extension filter, and a `status` derivation restricted to declared
  enum members (`null -> "unknown"`, `0 -> "healthy"`, `>0 -> "critical"`).
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` — new fixture-driven
  suite: a clean-fixture control, Bar 1 (failing fixture), Bar 2 (no-probe fixture), an
  enum-conformance anti-drift check against `state-schema.json`, and Bar 3 (frontmatter
  idempotence regression lock against `generate-todo.sh`, loud-skips when the deployed tree is
  absent).
- `agent-system/extensions/core/context/schemas/state-schema.json` — `repository_health.build_errors`
  changed to `{"type": ["integer", "null"]}`; `status.enum` extended from four to five members by
  adding `"unknown"`.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — mirrored the same
  five-value enum and nullable `build_errors` typing in prose.
- `agent-system/extensions/core/commands/todo.md` — Step 5.6 rewritten as a thin call site over
  `assess-repo-health.sh`; the `state-write.sh` call collapsed to a single
  `--argjson health "$health_json"` binding (eliminating the undefined-`$build_errors` defect
  class entirely); Step 5.7.3 ("Update TODO.md frontmatter") deleted in full with an inline
  rationale note; sub-steps renumbered `5.7.1`-`5.7.4` -> `5.6.1`-`5.6.3`.
- `agent-system/extensions/core/manifest.json` — registered `assess-repo-health.sh` and
  `tests/test-assess-repo-health.sh` in `provides.scripts`.
- `agent-system/extensions/core/merge-sources/claudemd.md` — added a Utility Scripts entry for
  `assess-repo-health.sh`.
- `agent-system/extensions/core/index-entries.json` — corrected `schemas/state-schema.json`'s
  `line_count` (261 -> 262) after the schema edit; caught by `verify-deploy.sh`'s doc-lint gate
  during this task's own Phase 5 verification, not pre-existing.

## Decisions

- Adopted the research's reading of `build_errors` as "the tree is structurally sound"
  (`bash -n`/`jq empty`), not "the project's own build/lint command passes" — this repo has
  neither `Makefile` nor `package.json`, and the agent-system deploys into Lua/Python/Lean/Nix/
  LaTeX/Z3/web trees with no common check command.
- Fixed the index-entries.json line-count drift by hand-editing the single affected entry rather
  than running `generate-context-line-counts.sh --write` across all extensions, to avoid pulling
  unrelated pre-existing drift into this diff.
- Left section 5.7 ("Vault Operation")'s pre-existing `5.8.x` sub-step numbering skew untouched
  (confirmed the numbering skew is NOT local to this stage — it cascades to the following
  section too — and per the plan's own Scope Hypothesis, only Step 5.6's own sub-steps were
  renumbered, with the residual skew explicitly noted rather than silently widening the diff).

## Plan Deviations

- **Phase 2's own local "exits 0" verification bar** initially showed 9/10 assertions passing,
  with the sole failure traced to a stale, pre-existing deployed `.claude/context/schemas/state-schema.json`
  predating this task's Phase 3 edit. Deferred re-confirmation to Phase 5's deploy step (the
  plan's own designated point for syncing `.claude/`); genuine 10/10 (11/11 including Bar 3)
  all-`[PASS]` was confirmed after deploy.
- **Phase 4's `check-task-references.sh` verification** deferred to Phase 5 for the same reason:
  the script refuses to run from the source-store location by design (requires a deployed tree).
  Confirmed passing post-deploy.
- **Phase 5 gained one unplanned file**: `agent-system/extensions/core/index-entries.json`, fixed
  in scope after `verify-deploy.sh`'s doc-lint gate caught a genuine line-count drift caused by
  this task's own Phase 3 schema edit.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: **Passed** — `bash .claude/scripts/tests/test-assess-repo-health.sh` (deployed):
  11 passed, 0 failed, exit 0. Negative-control demonstration executed and reverted: inverting
  the probe's `bash -n`/`jq empty` success sense flipped both Bar 1 and the clean control to
  `[FAIL]` (5 passed, 5 failed), confirming the suite is not vacuous; reverted byte-for-byte and
  re-confirmed the restored baseline.
- Full suite runner: `bash .claude/scripts/tests/run-all.sh` — 35 passed, 0 failed, 35 total, exit
  0 (post-deploy; one transient, unrelated pre-existing flake in
  `test-claude-refresh-matcher.sh` was observed once and confirmed non-reproducing on isolated
  re-run: 12/12).
- `bash .claude/scripts/verify-deploy.sh` — **PASS, 23 check(s), 0 failure(s)** (after fixing the
  index-entries.json drift the first run of this gate caught).
- Files verified: Yes — `.claude/scripts/assess-repo-health.sh` and
  `.claude/scripts/tests/test-assess-repo-health.sh` confirmed present and executable in the
  deployed tree; `.claude/commands/todo.md` confirmed carrying the rewritten Step 5.6.1-5.6.3.
- Real-path exercise: `bash .claude/scripts/assess-repo-health.sh` (no `--root`, this repo)
  emitted valid JSON, `status: "critical"` (found one real, pre-existing, out-of-scope defect:
  `.opencode/scripts/execute-command.sh` fails `bash -n` — outside the source-store rule's scope,
  not touched), confirmed a member of the deployed schema's five-value enum.

## Impacts

- `/todo`'s Sync Repository Metrics stage now calls a real, independently-testable script instead
  of embedding unverifiable bash/jq in markdown prose — the class of defect this task fixes
  (untested embedded logic) cannot recur silently in this stage without a suite failure.
- `repository_health.build_errors` can now express "not measured" distinctly from `0`/`1`, and
  `status` is always drawn from the schema's declared enum.
- `repository_health` has exactly one home (`state.json`); the now-deleted TODO.md-frontmatter
  instruction (which could never have worked, since `generate-todo.sh` always fully overwrites
  TODO.md) is gone, with the rationale recorded inline.

## Follow-ups

- Add a `repository_health.status` enum check to `validate-state.sh`, mirroring its existing
  task-status enum check, so this class of vocabulary drift cannot recur silently (flagged by the
  research as a follow-up, not required by any of the three verification bars).
- Decide separately whether `skill-todo/SKILL.md` should gain a repository-metrics stage at all
  (confirmed not applicable to this task's scope — no existing stage to mirror into).
- `.opencode/scripts/execute-command.sh` fails `bash -n` (found via the real-path exercise above).
  Outside this task's scope (`.opencode/` is a separately tracked deploy target); flagged for a
  future, separately scoped task.

## References

- Plan: `specs/1004_fix_todo_repository_metrics_sync/plans/01_repository-metrics-sync-fix.md`
- Research: `specs/1004_fix_todo_repository_metrics_sync/reports/01_repository-metrics-sync-fix.md`
- Progress files: `specs/1004_fix_todo_repository_metrics_sync/progress/phase-{1..5}-progress.json`
