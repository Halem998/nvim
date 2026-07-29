# Implementation Summary: Task #944

- **Task**: 944 - Add an in-flight orchestration session registry with liveness and reap
- **Status**: [COMPLETED]
- **Started**: 2026-07-28T23:00:00Z
- **Completed**: 2026-07-29T00:20:00Z
- **Effort**: ~4 hours
- **Dependencies**: 942, 943 (both closed)
- **Artifacts**: plans/01_in-flight-session-registry.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a session registry at `specs/.sessions/{session_id}.json` that records which orchestration
sessions are actually in flight — `session_id`, `pid`, `pid_source`, `command`, `task_numbers`,
the deduplicated UNION of those tasks' declared `file_scope`, `started_at`, `heartbeat_at`. The
registry ships as four additive subcommands (`session-register`/`session-heartbeat`/
`session-release`/`session-reap`) on the existing `scripts/task-lock.sh`, reusing its
`write_holder`-style tmp-file-rename atomic write, `iso_now`/`now_epoch`/`age_minutes`,
`get_file_scope`, and `cmd_reap`'s report-then-delete shape. All 10 plan phases were implemented,
verified, and committed individually. The registry is produced only — no gate, admission script,
or skill consumes it; every wiring call site is best-effort (`2>/dev/null || true`).

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — added `SESSION_REGISTRY_REAP_MIN` (240)
  and `SESSION_REGISTRY_DEAD_PID_MIN` (10) constants; `session_registry_dir()`,
  `resolve_session_pid()`, `write_session_entry()` helpers; `cmd_session_register`,
  `cmd_session_heartbeat`, `cmd_session_release`, `cmd_session_reap` functions; dispatch entries;
  extended header docs. No existing `cmd_*` function body changed.
- `.gitignore` (repo root) — added `**/.sessions/` to the ephemeral-runtime-state block (the ONE
  sanctioned exception to the source-store rule for this task; `root-files/.gitignore` deploys to
  `.claude/.gitignore` and cannot cover a `specs/`-rooted path, so it was deliberately not edited).
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — Class Table row
  for `specs/.sessions/{session_id}.json` (Ephemeral, no reader today); Consumer Repo Setup
  gitignore block updated; root-files exclusion note added.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — new probe
  (`specs/.sessions/sess_0000000000_probe.json`) and pattern (`/\.sessions/[^/]+\.json$`).
- `agent-system/extensions/core/scripts/command-gate-in.sh` /
  `agent-system/extensions/core/scripts/command-gate-out.sh` — single-task session
  register/release, adjacent to the existing task-lock acquire/release calls.
- `agent-system/extensions/core/commands/research.md`, `plan.md`, `implement.md` — multi-task
  batch register (Step 2, bare `batch_session_id`) and release (Step 4/5 boundary).
- `agent-system/extensions/core/commands/orchestrate.md` — annotation confirming
  `batch_session_id` passes unchanged into `skill-orchestrate` as `session_id`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 register, Stage
  MT-5 release (orchestrate batch); Stage 3 heartbeat (single-task cycle loop); Stage MT-3 step 1
  heartbeat (batch status refresh).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 4D heartbeat
  (implementer per-phase transition); `skill-implementer/SKILL.md` intentionally untouched.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — new Step 4.6 ("Reap Stale Session
  Registry Entries"), explicit `/refresh` invocation only, `--dry-run` passthrough.
- `agent-system/extensions/core/scripts/test-session-registry.sh` — new isolated-temp-root test
  suite, 10 cases, modeled on `test-task-lock-reap.sh`'s precedent.
- `agent-system/extensions/core/manifest.json` — one `scripts` array entry
  (`test-session-registry.sh`).
- `agent-system/extensions/core/context/patterns/task-lock.md` — new "Session-Registry CLI"
  section (entry schema, per-subcommand contract, threshold rationale, no-`mkdir`-gate rationale);
  "Consumers" section renamed to five paths with the new session-registry wiring path added;
  "Related Documentation" updated with the new test suite and standards cross-reference.

## Decisions

- Confirmed the plan's Scope Hypothesis empirically: `resolve_session_pid()`'s bounded ancestor
  walk resolved `pid_source=ancestor-claude` when run live (found a `claude`-named process two
  hops up from the helper's own `$$`), not the `ppid`/`self` fallback. The
  `SESSION_REGISTRY_DEAD_PID_MIN` floor was verified directly with synthetic fixtures: a dead-pid
  entry younger than the floor survives reap; one older reaps with reason `dead-pid`.
- No `session-list`/query subcommand was added — `session-reap --dry-run` is the only operator
  visibility, matching the plan's explicit Non-Goal.
- No intra-batch heartbeat was added to the three multi-task commands (`research.md`/`plan.md`/
  `implement.md`): each dispatches once per batch and waits for all results, so there is no
  per-cycle loop boundary to heartbeat at.

## Plan Deviations

- Phase 4's "manual end-to-end" verification bullet (a real single-task gate-in/gate-out pair
  observed creating and removing a registry entry) was deferred rather than exercised directly,
  because the deployed `.claude/scripts/task-lock.sh` was stale at that point in the sequence
  (the known `copy_scripts` loader gap — see Phase 10). The equivalent contract was instead
  proven via the isolated-temp-root smoke test in Phase 1 and the full `test-session-registry.sh`
  suite in Phase 9, both run against the deployed copy after Phase 10's redeploy.
- Testing & Validation's "End-to-end smoke: a real single-task command run" checklist item was
  deferred for the same reason: no live `/research`/`/plan`/`/implement` command was invoked
  against this repo during implementation. The isolated manual smoke tests (Phase 1) and the
  deployed test-suite runs (Phase 10) cover the same registration/release contract.
- `check-extension-docs.sh` and `scripts/verify-deploy.sh` both report a pre-existing `literature`
  extension doc-lint FAIL (stale `.pyc` cache entries under `scripts/__pycache__/` and several
  core literature scripts never deployed) that predates this task and is unrelated to any file
  this task touched. Every other extension, including `core`, reports PASS. Not fixed here — out
  of this task's scope.

## Verification

- Build: N/A (shell scripts and markdown only)
- Tests: Passed — `test-task-lock-reap.sh` (6/6, no regression) and `test-session-registry.sh`
  (10/10, new suite), both against source-store and deployed copies
- Files verified: Yes — every phase's edits were syntax-checked (`bash -n`), diff-read-through
  verified, and (where applicable) live-smoke-tested against an isolated temp root before commit

## Impacts

- No admission, refusal, or dispatch decision changed anywhere in the codebase — the registry is
  produced only. `scripts/orchestrate-batch-admit.sh` and every existing `task-lock.sh` `cmd_*`
  function body are byte-unchanged (confirmed by diff inspection in Phase 10's audit).
- A future task can add the first reader of `specs/.sessions/{session_id}.json` (e.g. for
  operator visibility, or an admission check) — this task deliberately shipped zero read surface,
  so that consuming task must add its own freshness/ownership checks together with the reader, as
  `context/patterns/task-lock.md`'s "Non-Goal: No Reader" subsection states.
- Deployed `.claude/` tree was regenerated via `deploy-headless.sh` during Phase 10; the deployed
  copy of `manifest.json` needed a one-off manual `cp` from the source store afterward (the known
  `copy_scripts`/manifest loader gap for already-loaded extensions — the script itself,
  `test-session-registry.sh`, DID reach `.claude/scripts/` correctly this run).

## Follow-ups

- The known `copy_scripts`/manifest loader gap (a new script's manifest entry not always reaching
  an already-deployed repo's deployed `manifest.json` copy on redeploy) remains open, as directed
  by the plan — out of this task's scope to fix.
- The pre-existing `literature` extension doc-lint FAIL (stale `.pyc` cache entries, several
  core scripts never deployed) remains open — unrelated to this task, not investigated further.
- Consuming this registry (an operator `session-list`/query surface, or wiring it into an
  admission decision) is explicitly deferred to a future task, per this task's Non-Goals.

## References

- `specs/944_in_flight_session_registry/plans/01_in-flight-session-registry.md`
- `specs/944_in_flight_session_registry/reports/01_in-flight-session-registry.md`
- `agent-system/extensions/core/context/patterns/task-lock.md`
