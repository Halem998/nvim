# Implementation Summary: Task #964

- **Task**: 964 - Repair /refresh orphan detection so live system and session processes are never selected
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_refresh-orphan-matcher-repair.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`/refresh`'s orphaned-process matcher previously selected live system daemons, live-session
sleep inhibitors, a live memory-tracker service, and the refresh script's own transient
subshells as "orphans" -- on the verification machine it reported 10 orphans, all false
positives, meaning `--force` would have terminated the machine's OOM-protection daemon and the
inhibitor of the very session issuing the command. This implementation replaces the two-stage
`ps aux`-regex-then-ancestor-walk matcher in `claude-refresh.sh` with a single atomic `ps -eo`
snapshot plus four independently-testable exclusion predicates, ships a regression suite proven
RED against the pre-fix matcher, makes the systemd timer non-destructive by default, fixes the
pre-exclusion reclaim figure, adds a genuine `--dry-run` preview path, and reconciles every doc
site that previously claimed a safety property the code did not implement.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` -- full matcher rewrite: single
  `ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args --no-headers` snapshot; four named
  predicates (`is_claude_executable_comm`, `is_system_slice_cgroup`, `is_owned_by_current_uid`,
  `is_live_inhibitor_target`); zero-query self-exclusion on pid/ppid == `$$`; deleted
  `is_in_current_tree()` and its stale-snapshot ancestor-walk race; `main()` +
  `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` dual-mode guard; `--dry-run` flag; post-exclusion
  reclaim-memory accumulation; rewritten header safety block documenting the real mechanism and
  the deliberate recall-for-safety trade-off; a `validate_cgroup_support()` fail-loud guard
  against a future platform lacking the `cgroup` `ps` column.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` -- new regression
  suite covering all four named acceptance-bar assertions: (a) `/system.slice/` cgroup exclusion,
  (b) argv-mention rejection (comm-identity gate), (c) inhibitor-target liveness driven by a real
  backgrounded process, (d) self-subshell exclusion via both a synthetic-comm case and a direct
  end-to-end fake-`ps` harness. Includes a mutation check proving the suite is RED against the
  pre-fix script.
- `agent-system/extensions/core/manifest.json` -- registered
  `tests/test-claude-refresh-matcher.sh` in `provides.scripts`.
- `agent-system/extensions/core/systemd/claude-refresh.service` -- `ExecStart` (live and
  commented system-wide alternative) changed from `--force` to `--dry-run`, with a policy comment.
- `agent-system/extensions/core/scripts/install-systemd-timer.sh` -- heredoc-generated
  `ExecStart` changed the same way.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` -- "Process Safety" section
  rewritten to describe the four real predicates; Step 2 now forwards `--dry-run` through to
  `claude-refresh.sh` (it previously dropped the flag entirely); "Dry-Run Flow" example updated
  to show the process-cleanup DRY RUN banner.
- `agent-system/extensions/core/commands/refresh.md` -- "Process Protection" section rewritten;
  `--dry-run` Options row made accurate; non-destructive timer posture recorded in both the
  "Stale Task Locks" and "Stale Session-Scoped Orchestration Files" sections.

## Decisions

- Replaced the two-stage design with a single-snapshot design rather than patching the ancestor
  walk, because the two-stage design has an inherent race (a second, later live re-query against
  possibly-already-exited transient PIDs) that a direction-only fix would not close.
- `is_claude_executable_comm`'s allow-list is exact-match on `comm` (`claude`, plus `node` gated
  by an argv entrypoint check), not a prefix/substring match -- this is what correctly excludes
  `claude-memory-tracker` (kernel-truncated `comm` "claude-memory-t") without a bespoke exception,
  since it never equals the allow-listed executable names.
- Predicate 4 (`is_live_inhibitor_target`) is kept and unit-tested even though today's
  `systemd-inhibit` candidates are already excluded by predicate 1 -- it is required by
  acceptance criterion 1(c), is the only predicate that protects other live sessions' inhibitors
  (not just the invoker's own), and is documented as intentional defense-in-depth rather than
  dead code.
- The regression suite's mutation check is pinned to a specific commit (`7e79b2695`, the last
  commit before the Phase 1 rewrite) rather than `HEAD`, since by the time the test file itself
  is authored `HEAD` already is the fixed script -- `git show HEAD:...` would have made the check
  vacuously pass.

## Plan Deviations

- None (implementation followed plan). Two implementation-time discoveries were folded into
  Phase 2/3 without changing plan scope: (1) a naive `$PPID`-based self-pid guess in the
  self-exclusion test harness was wrong because `snapshot=$(take_snapshot)` forks an intermediate
  subshell, fixed by walking real ancestry with the system `ps` instead; (2) a plain blocking
  `wait` on a backgrounded helper process intermittently stalled under this machine's concurrent
  load, replaced with a bounded, non-blocking `kill -0` poll loop.

## Verification

- Build: N/A (shell scripts / markdown docs)
- Tests: Passed -- `test-claude-refresh-matcher.sh` 12/12 assertions GREEN against the fixed
  script (4 stable re-runs), confirmed RED against the pre-fix script (commit `7e79b2695`)
- Files verified: Yes

### Acceptance-bar sweep (all seven criteria, read-only, `--force` never invoked)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Regression tests exist and pass | PASS -- 12/12 assertions, RED-against-pre-fix confirmed |
| 2 | Zero orphans on this live machine | PASS -- 0 orphans, 6 active sessions; all 10 previously-reported false positives individually cross-checked and classified by predicate |
| 3 | Reclaim figure is post-exclusion | PASS -- live machine shows no figure (0 survivors); non-empty-sum path verified via a targeted fake-`ps` harness (huge earlyoom row correctly excluded from a 1.9 MB total of two real survivors) |
| 4 | Real `--dry-run` preview path, true doc | PASS -- accepted, no mutation; banner verified present via a harness run with a synthetic orphan; doc matches |
| 5 | Non-destructive timer/installer | PASS -- neither `ExecStart` carries `--force`; both accept `--dry-run` |
| 6 | No doc site claims an unimplemented safety property | PASS -- residual grep across the whole source store returns only accurate mechanism descriptions |
| 7 | `bash -n` clean on every edited script | PASS -- `claude-refresh.sh`, `install-systemd-timer.sh`, `test-claude-refresh-matcher.sh` all clean |

Additional checks: `check-task-references.sh` clean (0 unexempted occurrences across 4 scanned
trees); `jq empty manifest.json` valid with both entries present; `git status --short` confirms
this task's commits touched only `agent-system/extensions/core/**` and
`specs/964_repair_refresh_orphan_detection/**` -- no file was written under `.claude/**`.

## Impacts

- `/refresh` (no flags or `--dry-run`) on this machine now correctly reports zero orphaned
  processes instead of 10 false positives, eliminating the risk that `--force` would terminate
  the OOM-protection daemon, live sleep inhibitors (including the invoking session's own), or a
  live memory-tracker service.
- The hourly, unattended `claude-refresh.timer` cadence is no longer destructible by a future
  matcher regression -- it reports/logs rather than terminates by default.
- `/refresh --dry-run` now genuinely previews process cleanup rather than silently dropping the
  flag.

## Follow-ups

- None required by this task's scope. Recorded but explicitly out of scope (per the plan's
  Non-Goals): the separately-tracked deploy-propagation gap for brand-new `scripts/tests/*.sh`
  files reaching an existing `.claude/` deploy; broadening orphan-detection recall (a deliberate
  trade-off in favor of safety); moving the `specs/` sweeps onto the systemd cadence.

## References

- `specs/964_repair_refresh_orphan_detection/plans/01_refresh-orphan-matcher-repair.md`
- `specs/964_repair_refresh_orphan_detection/reports/01_refresh-orphan-matcher-repair.md`
