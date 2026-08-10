# Implementation Summary: Task #967

- **Task**: 967 - fix_git_commit_scoped_lock_exclude_abort
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T17:30:00Z
- **Completed**: 2026-07-29T18:55:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_lock-exclude-abort-fix.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, git-staging-scope.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`git-commit-scoped.sh` unconditionally injected four `:(exclude)<task_dir>/<ephemeral>` pathspec
entries for any task-directory pathspec. Naming an already-gitignored path in an explicit
`:(exclude)` entry made `git add` refuse the whole add whenever that path currently existed on
disk — most visibly a held task lock's `.lock/` directory, but empirically all four candidates
reproduced the identical abort. Fixed by gating injection on `git check-ignore -q`: a candidate
`.gitignore` already covers is never named in an exclude pathspec (git already skips it silently
when swept up implicitly by the directory pathspec); a candidate not covered is still injected
exactly as before. Shipped test-first, with the regression suite proven RED against the unmodified
script before the fix landed, then deployed and confirmed live against this very task's own
in-flight `.lock/`.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — replaced the unconditional
  exclude-injection block with a `git check-ignore -q`-gated loop; updated the file-header comment
  and the block's leading comment to describe the conditional behavior and the abort mechanism.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — new regression suite
  (T1-T7) exercising the real script against real git in scratch repos: commit-lands-with-`.lock/`
  present (T1), `.lock` not staged (T2), all-four-present in a fully-covered repo (T3), no-`.lock`-
  but-other-three-present (T4), under-configured repo where the injected excludes are what keep
  the four out (T5), V3 exclude-only-refusal intact (T6), V2 unmatched-pathspec-drop intact (T7).
- `agent-system/extensions/core/manifest.json` — registered
  `tests/test-git-commit-scoped.sh` in `provides.scripts`.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — reframed both
  `ephemeral_excludes` array copies as a candidate set with conditional-injection prose, added the
  cross-reference to `orchestrator-runtime-files.md`'s "gitignore coverage is the primary,
  sufficient control" position, and marked the "Reference Template" copy as illustrative only
  (the sanctioned implementation is `git-commit-scoped.sh`).
- `specs/state.json` — corrected an unharvested `memory_candidates` entry (project 965) whose
  diagnosis was accurate but whose "stage individual subpaths" workaround is now superseded by
  the shipped fix; rewrote in place to state the trigger plainly and point at the fix.
- Deployed `.claude/scripts/git-commit-scoped.sh` and
  `.claude/scripts/tests/test-git-commit-scoped.sh` — regenerated from the source store via
  `deploy-headless.sh`, plus a one-off `loader_mod.copy_scripts`/`copy_manifest` invocation to
  work around the known already-loaded-extension `copy_scripts` gap for the brand-new test file.

## Decisions

- **Chose Option C (conditional injection via `git check-ignore`) over Option A (drop `.lock/`
  only)** — the task's literal VERIFICATION BAR wording assumed the other three ephemeral excludes
  were not gitignored; research disproved that empirically (all four reproduce the identical
  abort), so Option A would have shipped a fix that provably left three instances of the same
  defect live. See the plan's "Conflict Reconciliation" section for the full resolution.
- **Fully-covered repos (including this one) now inject zero exclude entries** for a task-dir
  pathspec — exclusion is delivered by `.gitignore` alone in that configuration. This is a
  deliberate, documented behavior change (see the plan's "Stated deviation" subsection), not an
  oversight; the fallback direction (any non-zero `check-ignore` exit still injects) keeps
  under-configured repos byte-for-byte on the pre-fix behavior.
- **Used the loader's own copy primitives** (not hand-authored `.claude/**` edits) to work around
  the deploy-mechanism gap where `deploy-headless.sh` skipped copying the brand-new test file for
  an already-loaded extension — consistent with `source-store-deploy-boundary.md`.

## Plan Deviations

- None (implementation followed plan). Phase 5's Scope Hypothesis anticipated the `copy_scripts`
  gap explicitly and named the workaround in advance; hitting it and applying the documented
  workaround is execution of the plan, not a deviation from it.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `bash .claude/scripts/tests/test-git-commit-scoped.sh` exits 0, 7 passed / 0
  failed against the deployed copy. Pre-fix mutation check confirmed T1 and T3 RED (rc=2, "paths
  are ignored") against the unmodified script.
- Files verified: Yes — `bash -n` clean on both the script and the test suite; `git diff --stat`
  confirms the Phase 2 fix is confined to `git-commit-scoped.sh` alone, within the file-header
  comment and the injection block only (V2/V3 gates and the commit mutex untouched).

## Impacts

- Every scoped commit through `git-commit-scoped.sh` against a task directory with a currently-held
  `.lock/` (or any other present, gitignored ephemeral runtime file) now lands instead of silently
  failing with a non-blocking exit 2 — closing a defect that was actively dropping commits in
  in-flight multi-task `/orchestrate` batches (per Stage MT-4's commit-before-lock-release
  ordering, the `.lock/` directory is present by construction at every multi-task per-task commit).
- `git-staging-scope.md` readers now learn the exclusion set is conditional and gitignore-primary,
  matching the already-settled `orchestrator-runtime-files.md` position, closing a doc/script drift
  gap.
- The one unharvested memory candidate recommending a superseded workaround is corrected so future
  agents are pointed at the shipped fix instead.

## Follow-ups

- None. The task's own live defect (two prior failed commits for this task in the same batch) was
  directly closed by this task's own final commit, which landed successfully with `.lock/` present.

## References

- `specs/967_fix_git_commit_scoped_lock_exclude_abort/plans/01_lock-exclude-abort-fix.md` — full
  plan, including the "Conflict Reconciliation" and "Stated deviation" sections
- `specs/967_fix_git_commit_scoped_lock_exclude_abort/reports/01_lock-exclude-abort.md` — research
  report with the empirical findings this plan implements
- `specs/967_fix_git_commit_scoped_lock_exclude_abort/progress/phase-{1..5}-progress.json` —
  per-phase progress records with mutation-check output and deploy-workaround notes
