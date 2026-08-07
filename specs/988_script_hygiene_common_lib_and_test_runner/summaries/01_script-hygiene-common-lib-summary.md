# Implementation Summary: Task #988

- **Task**: 988 - Script hygiene: lib/common.sh, strict-mode convention, test runner wired into deploy
- **Status**: [COMPLETED]
- **Started**: 2026-08-06
- **Completed**: 2026-08-07
- **Effort**: ~16 hours across multiple dispatches
- **Dependencies**: None (Task 960, Task 964 already completed)
- **Artifacts**: plans/01_script-hygiene-common-lib.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed all four coupled shell-hygiene deliverables in the mandated order across 10 plan phases:
a `scripts/tests/run-all.sh` test runner wired into `verify-deploy.sh` as Gate 8; a
`scripts/lib/common.sh` shared library extracting repo-root resolution, session-ID generation,
UTC timestamps, a logging trio, and a test pass/fail/info trio; mechanical migration of the
duplicated session-ID and root-resolution boilerplate onto that library; a per-file-audited
`set -euo pipefail` strict-mode convention (27 files migrated across Phases 6-7, individually
audited and live-fixture-verified, zero reclassified to Class B); shebang normalization (24
files); and new test coverage for `skill-base.sh`'s lifecycle functions and
`update-task-status.sh`. Every phase is `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/scripts/tests/run-all.sh` — new test runner, discovers and runs
  every suite in both documented locations, loud-skip on zero-discovered, `[SKIP]` against a
  non-source-store target.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new Gate 8 wired to `run-all.sh`.
- `agent-system/extensions/core/scripts/lib/common.sh` — new shared library (`common_repo_root`,
  `common_session_id`, `common_timestamp_iso`/`epoch`/`date`, `common_log_error`/`warn`/`info`,
  `common_test_pass`/`fail`/`info`), sets no shell options, 23-assertion unit suite.
  `tests/test-common-lib.sh` — new unit suite for the library above.
- Session-ID generation consolidated to exactly one place across 8 sites in 7 files, closing
  `command-gate-in.sh`'s `tr -d ' \n'` divergence from the other sites' `tr -d ' '`.
  Root-resolution boilerplate migrated at 40+ sites to `common_repo_root`.
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` — new convention doc:
  three strict-mode classes (A migrate, B counter-idiom stays `-uo pipefail`, C sourced-only
  stays unset), full live classification of every non-`-e` file.
- 27 files migrated `set -uo pipefail` → `set -euo pipefail` across Phases 6-7 (5 highest-risk
  state mutators in Phase 6; 22 remaining Class A files — 11 ordinary scripts, 5 notification
  hooks, 6 EXTRA CARE PreToolUse/PostToolUse gates — across 5 batches in Phase 7), each
  individually audited for `-e`-hostile constructs and live-fixture-verified. See the per-phase
  commits for the full per-file finding detail; recurring hazard classes found and fixed: bare
  `VAR=$(cmd); status=$?` (converted to `if VAR=$(cmd); then st=0; else st=$?; fi`), bare
  `[ cond ] && action` (guarded with `|| true`), bare grep/jq captures whose common case is the
  no-match/failure path (guarded with `|| true`), and a standalone `((VAR++))` post-increment
  hazard (converted to `VAR=$((VAR + 1))`).
- 24 files' shebangs normalized `#!/bin/bash` → `#!/usr/bin/env bash` (19 hooks, 5 core scripts,
  1 email hook); confirmed inert for every registered hook call site (all invoked via explicit
  `bash .claude/hooks/<name>.sh`).
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new suite covering
  `skill_preflight_update`, `skill_postflight_update`, `skill_gate_completion_claim`,
  `skill_link_artifacts`, `skill_cleanup` (14/14 assertions).
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — new suite covering
  preflight/postflight transitions, TODO.md regeneration, `--phase-check=warn`/`refuse`, and the
  non-conforming-heading interaction (16/16 assertions).
- `agent-system/extensions/core/manifest.json` — registers all 5 new script files under
  `provides.scripts`.

## Decisions

- Guarding a bare command-substitution assignment or `[ cond ] && action` statement with
  `|| true` always preserves pre-migration behavior exactly: the assignment/action still happens
  with whatever output was actually produced; only the exit-status propagation to `-e` is
  suppressed. This is distinct from cases where letting `-e` abort is a deliberate improvement
  (e.g. a failed `mktemp -d` whose failure was never gracefully tolerated to begin with) — those
  were left unguarded.
- The classic `VAR=$(cmd); status=$?` anti-pattern is the highest-severity hazard class: under
  `-e`, a failing first-line assignment aborts before the status-capture line ever runs, silently
  destroying whatever graceful-degradation logic depended on that status. Fixed uniformly via
  `if VAR=$(cmd); then status=0; else status=$?; fi`.
- Several Phase 7 hazards sat directly on a SUCCESS path rather than a failure path (e.g.
  `events-log-lifecycle.sh`'s `[ -z "$session_id" ] && exit_success` aborted precisely when a
  marker WAS found with a valid session_id — the normal case; `orchestrate-dry-run-report.sh`'s
  `task-lock.sh check` anti-pattern aborted whenever a lock was legitimately held — an everyday
  occurrence). An audit that only reasons about "what happens on failure" misses this class.
- `validate-no-task-references.sh`'s documented "fails OPEN if its own shared pattern library
  cannot be sourced" contract was extended to cover a present-but-syntax-broken library, not just
  a missing one — under the prior code, only the missing-file case honored that contract; a
  broken-but-present library would have aborted under `-e` instead of falling through. Live
  -verified with a deliberately syntax-broken library file.

## Plan Deviations

- **Task 10.3** (cover "the refusal path on terminal statuses" for `update-task-status.sh`)
  skipped: live inspection of the full 564-line script found no terminal-status
  (completed/abandoned/expanded) refusal logic anywhere in it — it has no awareness of terminal
  statuses at all. This is a stale planning assumption; no fabricated test case was written for
  nonexistent behavior. Every other named coverage item for this suite was completed.

## Verification

- Build: N/A (shell scripts)
- Tests: `bash agent-system/extensions/core/scripts/tests/run-all.sh` — 29/29 passed in the final
  full-suite run (one transient, non-reproducing flake in the already-documented
  `test-claude-refresh-matcher.sh` was observed once mid-implementation and confirmed to clear on
  immediate re-run — pre-existing, unrelated to this task).
- Files verified: Yes — every new file registered in `core/manifest.json`'s `provides.scripts`.
- `check-task-references.sh --quiet`: 0 unexempted occurrences across all scanned trees.
- `lint-agent-contracts.sh --verbose`: 33 passed, 0 warnings, 0 failed.
- `grep -rl '^#!/bin/bash' --include="*.sh" agent-system/extensions/`: 0 matches.
- `grep -rn 'sess_\$(date' --include="*.sh" agent-system/extensions/`: matches only
  `lib/common.sh`.
- Real `specs/` tree confirmed untouched by the two new test suites via a delta-based
  contamination guard in each.

## Impacts

- Every state-mutating and PreToolUse/PostToolUse-gate script in the source store now aborts
  loudly on a genuine internal error instead of silently continuing past it — the core intent of
  the `-e` migration — while every previously-tolerated graceful-degradation path (empty/no-match
  results, documented fail-open contracts) was individually verified to still behave identically.
- `run-all.sh` + Gate 8 give every future change to these scripts a real regression net that did
  not exist before this task.
- `scripts/lib/common.sh` eliminates the session-ID trailing-newline divergence and gives future
  scripts one place to source root-resolution, timestamp, logging, and test-helper conventions
  from, rather than re-deriving them inline.

## Follow-ups

- `.claude/` has not been redeployed during this dispatch (this agent is not a sanctioned
  automated caller of `deploy-headless.sh`); `verify-deploy.sh` Gates 3/5 and
  `check-extension-docs.sh` currently report the expected "deployed script content drift" for
  every file this task touched. Resolves at the next human/orchestrator-driven
  `[Reload All]`/`[Regenerate]` deploy.
- Root-resolution migration (Phase 4) was explicitly bounded — roughly 24 residual variant sites
  across deeper-nested hooks/lint scripts remain unmigrated, recorded as a deliberate residual in
  that phase's own scope hypothesis, not a defect.
- `skill-base.sh` has 11 functions beyond the 5 covered in Phase 9 that remain untested (listed
  in `test-skill-base-lifecycle.sh`'s own header); covering them was explicitly out of this
  phase's bounded scope ("5 named functions, not all 17").
- One pre-existing, out-of-scope bug was found and recorded (not fixed) during the Phase 7 audit:
  `validate-plan-write.sh`'s `output=$(bash "$VALIDATOR" ...) || true` followed by
  `exit_code=$?` means `exit_code` is always 0, making the case statement's 1/2/* branches dead
  code — predates this migration and is a correctness bug unrelated to `-e` safety (the existing
  `|| true` already makes the line `-e`-safe by construction).

## References

- Plan: `specs/988_script_hygiene_common_lib_and_test_runner/plans/01_script-hygiene-common-lib.md`
- Report: `specs/988_script_hygiene_common_lib_and_test_runner/reports/01_shell-hygiene-common-lib.md`
- Classification doc: `agent-system/extensions/core/context/standards/shell-strict-mode.md`
- Handoffs: `specs/988_script_hygiene_common_lib_and_test_runner/handoffs/` (phase-6, phase-7)
- Progress files: `specs/988_script_hygiene_common_lib_and_test_runner/progress/` (phases 1-10)
