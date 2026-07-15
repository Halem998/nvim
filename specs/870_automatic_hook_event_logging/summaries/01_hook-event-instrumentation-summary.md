# Implementation Summary: Automatic Hook-Based Lifecycle Event Logging

**Completed**: 2026-07-15
**Duration**: ~1.5 hours

## Overview

Wired up `events-append.sh` (previously a complete, callerless append helper) as the first real
consumer of the unified event store. All four `skill-base.sh` lifecycle functions and
`orchestrator-postflight.sh`'s status resolution now emit timed, well-formed events, and two new
Claude-Code-native hooks (`PostToolUse` and combined `Stop`/`SubagentStop`) capture artifact
writes and session lifecycle boundaries. All edits are confined to
`agent-system/extensions/core/`.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — added a start/end timer plus one
  non-blocking `events-append.sh` call to each of `skill_preflight_update`,
  `skill_context_injection`, `skill_validate_artifact`, and `skill_postflight_update`, with the
  correct `checkpoint` value per function and a `deviation`/`milestone` category discriminator
  in `skill_validate_artifact` based on the incoming `status` argument.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — added Stage 6b: exactly
  one `orchestrator_status` event at the point `status` is resolved, mapping
  `success_status`→`success`, `failed`/`blocked`→`blocker`, `partial`→`deviation`; cross-linked
  to the most recent matching `specs/errors.json` entry (by `context.session_id`) as
  `--error-ref` when the file exists and parses.
- `agent-system/extensions/core/hooks/events-log-artifact.sh` (new) — `PostToolUse` hook with a
  cheap path early-exit before any `jq`/lock work; on a matching `.return-meta.json`/
  `specs/errors.json` write, extracts session/task/status (or error id/severity) and emits
  `artifact_write`/`error_logged` events; always echoes `{}`.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (new) — combined `Stop`/
  `SubagentStop` hook branching on stdin's `agent_id` presence; `SubagentStop` correlates via
  the `.postflight-pending` marker (mirroring `subagent-postflight.sh`'s lookup), `Stop`
  correlates via `.claude/tmp/workflow-active` or a `last_assistant_message` task-number regex
  fallback, resolving `session_id` via a `state.json` lookup keyed on the recovered task number;
  always echoes `{}`.
- `agent-system/extensions/core/manifest.json` — `provides.hooks` grew from 16 to 18 entries
  (both new hook filenames added in alphabetical position).
- `agent-system/extensions/core/root-files/settings.json` — `events-log-artifact.sh` appended to
  the existing `PostToolUse` `Write|Edit` matcher; `events-log-lifecycle.sh` appended to both the
  `Stop` and `SubagentStop` matchers, using the existing `|| echo '{}'` non-blocking idiom.
- `agent-system/extensions/core/EXTENSION.md` — hooks count corrected from the pre-existing
  drifted `11` to `18` (matching `manifest.provides.hooks`), plus a new "Hook-Based Event
  Logging" capability bullet referencing `events-format.md` and the hook filenames (no
  task-number citations).

## Decisions

- Used `jq -r '.errors[]? | select(.context.session_id == $sid)] | sort_by(.timestamp) | last'`
  to cross-link the most recent matching `errors.json` entry, since `errors.json`'s schema is
  `{"errors": [...]}` (not a bare array).
- For the `Stop` path's session_id correlation gap (neither `workflow-active` nor
  `last_assistant_message` carry a session_id), added a `state.json` lookup keyed on the
  recovered task number (`active_projects[].session_id`, populated by `update-task-status.sh` on
  every preflight) rather than emitting a sessionless event, which `events-append.sh` requires
  and would otherwise reject.
- Both new hooks follow the stdin-then-`CLAUDE_TOOL_INPUT`-fallback parsing pattern already used
  by `validate-plan-write.sh`/`validate-meta-write.sh`, and the `read -t 0.1` stdin-drain pattern
  already used by `memory-nudge.sh`.

## Plan Deviations

- **Task 4.3** (Stop path session_id correlation) altered: the plan specified marker/message
  correlation for the task number but did not specify how to resolve `session_id` (a mandatory
  `events-append.sh` field) for the Stop path, since neither correlation source carries it
  directly. Added a `state.json` lookup keyed on the recovered task number; if no task is
  recovered or no session_id resolves, the hook exits `{}` cleanly.
- **Task 7 doc-lint** (`check-extension-docs.sh`) altered/deferred: the doc-lint now reports FAIL
  for `scripts/skill-base.sh` and `scripts/orchestrator-postflight.sh` (deployed `.claude/`
  copy vs. `agent-system` extension source content drift). Verified via git history that the two
  copies were byte-identical before this task's edits, so the drift is the direct and
  unavoidable consequence of this task's own Non-Goal ("Do NOT deploy/sync
  `agent-system/extensions/core/` to the live `.claude/` tree"). All other doc-lint checks pass,
  and all other Phase 7 verifications (schema validation, non-blocking guarantee, absent-
  `errors.json` handling, git-status scope confinement) pass cleanly. Deferred to a future,
  separate sync task.

## Verification

- Build: N/A (shell scripts + JSON config, no build step)
- Tests: `bash -n` clean on all 4 modified/new shell files; `jq empty` clean on all 3 touched
  JSON files; a full scratch-directory simulation of preflight → context_injection →
  verification → postflight → `PostToolUse` write → `errors.json` write → `SubagentStop` →
  `Stop` → a second `orchestrator-postflight.sh` failure-with-matching-error-ref pass produced
  10 event lines, all validated schema-clean against `context/schemas/events-schema.json` via
  `jsonschema` (Draft7Validator), including correct `error_ref` cross-linking. Non-blocking
  guarantee confirmed by forcing `events-append.sh` to fail: all four callers/hooks still
  returned exit 0, and both hooks still echoed exactly `{}`. Absent-`errors.json` case confirmed:
  `orchestrator-postflight.sh` still exits 0 with `error_ref: null`.
- Files verified: Yes — `git diff --stat` across all task 870 commits shows every touched file
  confined to `agent-system/extensions/core/` (deliverables) or
  `specs/870_automatic_hook_event_logging/` (task artifacts).
- Doc-lint (`check-extension-docs.sh`, core extension): FAIL — 2 expected/accepted
  deployed-vs-source drift findings on `skill-base.sh`/`orchestrator-postflight.sh` (see Plan
  Deviations above); no other findings.

## Notes

- A follow-up sync task (out of this task's scope) would resolve the doc-lint drift by deploying
  the updated `agent-system/extensions/core/` scripts to the live `.claude/` tree, consistent
  with how task 869 left `events-append.sh`/`events-query.sh` undeployed by design.
- The `SubagentStop` duplicate-event trade-off (a stop firing more than once under
  `subagent-postflight.sh`'s loop-guard continuation) is accepted as documented in the plan;
  downstream consumers can dedupe by `session_id`+`checkpoint` if needed.
