# Implementation Summary: Task #965

- **Task**: 965 - Make check_undeclared_scripts skip untracked build artifacts
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T15:00:00Z
- **Completed**: 2026-07-29T15:25:00Z
- **Effort**: ~30 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_git-ls-files-enumeration.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`check_undeclared_scripts()` (Rule Q) in `check-extension-docs.sh` enumerated candidate files with
`find "$ext_path_norm/scripts" -type f`, which walked the working tree and flagged gitignored,
never-tracked build artifacts (two live CPython `__pycache__/*.pyc` files under the `literature`
extension) as permanent, unfixable hard FAILs. All four plan phases replaced the enumeration with
`git ls-files` (mirroring the sibling `_git_deployed_files()` helper's already-proven approach),
re-derived the REPO_ROOT-relative prefix-strip and existence guard, updated the stale header
comment, empirically proved via a positive-detection fixture that a tracked-but-undeclared script
is still caught, and propagated the fix through the sanctioned deploy path.

## What Changed

- `agent-system/extensions/core/scripts/check-extension-docs.sh` — `check_undeclared_scripts()`
  body: replaced `find "$ext_path_norm/scripts" -type f | sort` with
  `git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts" | sort`; added a new local
  `ext_rel="${ext_path_norm#"$REPO_ROOT"/}"` re-deriving the REPO_ROOT-relative prefix (`git
  ls-files` output shape differs from `find`'s absolute-path shape); changed the existence guard
  from `[[ -f "$script_file" ]]` to `[[ -f "$REPO_ROOT/$script_file" ]]`; changed the prefix-strip
  from `${script_file#"$ext_path_norm"/scripts/}` to `${script_file#"$ext_rel"/scripts/}`.
  Rewrote the header comment above the function to state the enumeration method is `git ls-files`
  (not `find`) and to record the gitignore-exclusion rationale, mirroring the existing
  `_git_deployed_files()` comment.
- `.claude/scripts/check-extension-docs.sh` (deployed copy, regenerated via
  `bash .claude/scripts/deploy-headless.sh` — never hand-edited) — now byte-for-byte identical to
  the source-store copy.

## Decisions

- Followed the plan exactly: no shared enumeration helper extracted between
  `check_undeclared_scripts` and `_git_deployed_files`/`check_flat_category_orphans` (the two
  checks enumerate structurally different roots).
- No `__pycache__/*` case exemption added to the existing `case` statement — the git-index
  enumeration change is the systemic fix, not a symptom patch.
- No `*.sh` glob reintroduced; all regular file types remain in scope.

## Phase 3 Assertion Results (HARD gate)

Three properties were empirically verified against the source-store script run with
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`:

**Property 1 — untracked artifacts skipped**: Diffing the pre-change script's output (checked out
from the commit immediately prior to this task's changes) against the post-Phase-1/2 baseline
showed the change removed EXACTLY these two lines and nothing else:
```
-  FAIL: script file on disk NOT in provides.scripts: scripts/__pycache__/literature-decode-font-offset.cpython-313.pyc
-  FAIL: script file on disk NOT in provides.scripts: scripts/tests/__pycache__/generate-test-fixtures.cpython-313.pyc
```
(plus the resulting `literature FAIL -> PASS` and finding-count `3 -> 1` bookkeeping lines that
necessarily follow). No other Rule Q output changed.

**Property 3 — no false-positive regression**: The baseline run against the changed script
reported zero `script file on disk NOT in provides.scripts` findings — the sole remaining FAIL in
the baseline was the (expected, pre-Phase-4) deployed-vs-source-store drift on
`check-extension-docs.sh` itself, unrelated to Rule Q.

**Property 2 — tracked-but-undeclared scripts STILL caught (HARD acceptance criterion)**: Created
`agent-system/extensions/core/scripts/__undeclared-fixture-probe.sh` (shebang + comment only),
made visible to `git ls-files` via `git add -N` (intent-to-add, uncommitted). Re-running the check
produced exactly one new finding:
```
  FAIL: script file on disk NOT in provides.scripts: scripts/__undeclared-fixture-probe.sh
```
Finding count rose from 1 to 2; the diff against the pre-fixture baseline was exactly this one
added line. **PASSED** — the change did not silently convert the check into a no-op. The fixture
was then cleaned up (`git restore --staged` + `rm`); a post-cleanup re-run matched the baseline
byte-for-byte.

## Deploy-Propagation Result

No gap encountered this run. `bash .claude/scripts/deploy-headless.sh` deployed 303 artifacts;
`diff .claude/scripts/check-extension-docs.sh agent-system/extensions/core/scripts/check-extension-docs.sh`
returned exit 0 (bodies identical). `bash .claude/scripts/check-extension-docs.sh` exits 0
("PASS: all extensions OK"). `bash .claude/scripts/verify-deploy.sh` reports
"PASS -- 12 check(s), 0 failure(s)" (the one WARN present — duplicate Stop-hook registration — is
pre-existing and unrelated to this change).

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (shell script; `bash -n` syntax check used instead — exit 0 after every edit)
- Tests: Passed — all three Phase 3 properties confirmed (see above); runtime doc-lint gate
  (`check-extension-docs.sh`) exits 0; `verify-deploy.sh` reports 0 failures
- Files verified: Yes

## Impacts

- The doc-lint gate (`.claude/scripts/check-extension-docs.sh`, invoked by
  `verify-deploy.sh` and elsewhere) no longer reports the two `literature` `__pycache__` FAILs as
  permanent, unfixable findings.
- Any future gitignored build artifact under an extension's `scripts/` tree (virtualenvs, other
  language caches) is now also naturally excluded, since enumeration is git-index-driven rather
  than filesystem-walk-driven — no new case-statement exemption was needed or added.
- No change to any other check in `check-extension-docs.sh`; `deprecated/*` exemption and
  `tests/` non-exemption both preserved verbatim.

## Follow-ups

- None

## References

- `specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/plans/01_git-ls-files-enumeration.md`
- `specs/965_skip_untracked_artifacts_in_undeclared_scripts_check/reports/01_git-ls-files-enumeration.md`
- `agent-system/extensions/core/scripts/check-extension-docs.sh`
