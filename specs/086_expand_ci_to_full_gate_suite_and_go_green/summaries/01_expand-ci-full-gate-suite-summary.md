# Implementation Summary: Task #86

- **Task**: 86 - Expand ci to full gate suite and go green
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T05:00:00Z
- **Completed**: 2026-08-25T06:56:00Z
- **Effort**: ~2 hours
- **Dependencies**: 82 (Wire deploy verification into deploy headless) — COMPLETED, verified in code
- **Artifacts**: plans/01_expand-ci-full-gate-suite.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Rewrote the repository's only CI workflow from a single missing-file invocation (exit 127 on
both of its historical runs, since `.claude/` is gitignored) into a deploy-then-verify pipeline
that materializes `.claude/` from the source store and then runs the full `verify-deploy.sh` gate
suite — the same aggregator `deploy-headless.sh` already uses locally. All 19 originally-live
gate failures (16 Rule R line_count mismatches, 3 Rule S missing index entries) are fixed at the
source, `check-runtime-file-tracking.sh` is wired in as gate 14, and a CI-only minimal-init nvim
hatch avoids a `lazy.nvim`/plugin bootstrap. The ACCEPTANCE criterion — a clean-clone rehearsal of
the exact CI step sequence passes, and the same rehearsal with a reintroduced `line_count`
mismatch fails — is demonstrated and recorded as transcripts.

## What Changed

- `.github/workflows/check-extension-docs.yml` — full rewrite: checkout -> install neovim ->
  `deploy-headless.sh --minimal-init` -> `verify-deploy.sh --findings` (full suite, no
  `--skip-slow`). Documents the two deliberately-excluded gate scripts.
- `agent-system/extensions/core/scripts/deploy-headless.sh` — added opt-in
  `--minimal-init DIR` flag (default off, byte-for-byte unchanged when unset); threads the flag
  into its own inline `verify-deploy.sh` call.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added gate 14
  (`check-runtime-file-tracking.sh`, always runs, not deferred by `--skip-slow`); added the same
  `--minimal-init DIR` flag applied to its two nvim call sites (gate5 `verify_all`, gate13
  `find_orphans`).
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`,
  `test-deploy-orphans.sh` — seeded the documented "Consumer Repo Setup" `.gitignore` block into
  each harness's scratch fixture, fixing a genuine regression where gate 14 correctly failed
  these harnesses' bare, never-onboarded throwaway git repos.
- `agent-system/extensions/core/index-entries.json` — 2 new entries (`return-meta-artifacts-template.md`,
  `ci-deploy-tree-bootstrap.md`) plus regenerated `line_count`s for the 14 pre-existing core
  mismatches.
- `agent-system/extensions/literature/index-entries.json` — 2 new entries
  (`corpus-directory-conventions.md`, `shared-module-extraction-for-gate-checks.md`).
- `agent-system/extensions/typst/index-entries.json` — regenerated `line_count`s for 2
  pre-existing mismatches.
- `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` — new: the CI
  recipe reference doc, including a caution about gate additions and scratch-repo test harnesses.

## Decisions

- Pulled the 16 pre-existing Rule R `line_count` fix forward from Phase 7 into Phase 6, since
  Phase 6's own positive-case acceptance requires 0 findings and the plan explicitly authorizes
  "fix the underlying cause at the source and re-run" for any gate found red during rehearsal.
  Phase 7's own regeneration pass then correctly reported 0 changes needed (idempotent), having
  only the new pattern doc's own already-accurate `line_count` to add.
- gate 14 (`check-runtime-file-tracking.sh`) runs unconditionally (not gated on
  `agent-system/extensions` presence like most other gates) since the script itself is deployed
  to every consumer repo by the core extension's manifest, not only the source store.
- `--minimal-init DIR` is a required, explicit, non-derived argument (never inferred from
  `TARGET`) since the nvim config directory and the deploy target differ for a consumer repo,
  even though they coincide in this repo's own CI.

## Plan Deviations

- **Rule R fix pulled forward into Phase 6** (rather than deferred solely to Phase 7): required
  to satisfy Phase 6's own 0-findings positive-case acceptance criterion; explicitly authorized
  by that phase's "fix at the source" instruction. See `progress/phase-6-progress.json`'s
  `deviations` array.
- **gate14 test-fixture regression discovered and fixed during Phase 6**: not anticipated by the
  plan. `test-deploy-propagation.sh` and `test-deploy-orphans.sh` create bare, never-onboarded
  scratch git repos to test the deploy engine; gate 14 correctly failed Check A on them. Fixed by
  seeding the documented onboarding `.gitignore` block into both harnesses' fixtures — gate 14
  and the tests' own assertions are unchanged; only the fixtures became representative of a
  properly-onboarded consumer repo. See `progress/phase-6-progress.json`'s `deviations` array.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: `tests/run-all.sh` — 52 passed, 0 failed (local); clean-clone rehearsal — positive 25
  checks/0 failures/0 findings, negative correctly red naming the edited file, revert back to
  green (all three transcripts recorded)
- Files verified: Yes — `bash -n` clean on both modified scripts; `jq .` parses every modified
  `index-entries.json`; `git diff` on regenerated files is `line_count`-only (plus new entries)

## Impacts

- CI now materializes real signal on every push/PR to master instead of failing with exit 127 on
  a missing file, closing a 0%-coverage gap that had existed since the workflow's introduction.
- Any future gate addition to `verify-deploy.sh` that inspects arbitrary repo/filesystem state
  (not just the deploy tree) should check whether any scratch-repo test harness under
  `scripts/tests/` needs the same onboarding fixture — documented as a caution in
  `ci-deploy-tree-bootstrap.md`.
- Live-Actions confirmation (an actual push watching the workflow go green/red) is a follow-up
  step handed to the user — see `progress/phase7-user-handoff-note.md` for exact commands.

## Follow-ups

- User must push (after `/merge` or directly) to confirm the live GitHub Actions run, per
  `progress/phase7-user-handoff-note.md` — agents may not push or open PRs.
- None outstanding within this task's own scope; all 7 phases closed, all originally-identified
  gate failures fixed, ACCEPTANCE demonstrated locally.

## References

- Plan: `specs/086_expand_ci_to_full_gate_suite_and_go_green/plans/01_expand-ci-full-gate-suite.md`
- Report: `specs/086_expand_ci_to_full_gate_suite_and_go_green/reports/01_expand-ci-full-gate-suite.md`
- Progress files: `specs/086_expand_ci_to_full_gate_suite_and_go_green/progress/phase-{1..7}-progress.json`
- Rehearsal transcripts: `specs/086_expand_ci_to_full_gate_suite_and_go_green/progress/phase6-{positive,negative,revert}-transcript.txt`
- User handoff note: `specs/086_expand_ci_to_full_gate_suite_and_go_green/progress/phase7-user-handoff-note.md`
