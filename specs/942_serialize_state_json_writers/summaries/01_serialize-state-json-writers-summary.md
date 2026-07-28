# Implementation Summary: Task #942

- **Task**: 942 - Serialize every specs/state.json writer through one mutex-guarded helper
- **Status**: [PARTIAL]
- **Started**: 2026-07-28T00:00:00Z
- **Completed**: 2026-07-28T06:00:00Z
- **Effort**: ~6 hours
- **Dependencies**: None
- **Artifacts**: plans/01_serialize-state-json-writers.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `agent-system/extensions/core/scripts/state-write.sh`, the single mutex-guarded writer for
`specs/state.json` (fail-closed `specs/.scope-lock` acquisition, private per-process `mktemp`
staging, `jq empty` validation before `mv`, optional in-mutex TODO.md regeneration, `SCOPE_MUTEX_HELD`
guest-mode reentrancy), and converted the plan's full nine-script-plus-two-command-file baseline to
call it. Added `task-lock.sh` `cmd_release` ownership verification, an isolated-temp-root
concurrency suite proving no-lost-update and staging-file isolation, and made the
`workflow-active` marker per-session (keyed by Claude Code's native session UUID) as a single
atomic batch across its one writer and three consumers. Phases 1 through 10 are complete and each
independently verified. Phase 11's own audit gate — a repo-wide grep proving zero hand-rolled
`specs/state.json` tmp-and-mv sequences remain outside `state-write.sh` — did NOT pass: it
surfaced a substantially larger residual surface (thirteen core `SKILL.md` files plus six more
command-file sites) than the plan's originating research report counted. That gap is recorded
honestly below rather than silently converted (uncosted, multi-phase-sized work) or silently
omitted.

## What Changed

- `agent-system/extensions/core/scripts/state-write.sh` — Created. The single mutex-guarded
  `specs/state.json` writer: `<jq-filter> --session-id SID [--arg/--argjson]... [--regen-todo]
  [--dry-run]`. Exit 0 success, 1 usage, 2 mutex ABORT (fail-closed), 3 jq transform failure, 4
  invalid-JSON validation failure.
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` — Created. Isolated-temp-root
  suite proving no-lost-update, staging-file isolation, fail-closed acquire, and guest-mode
  reentrancy (4/4 passing).
- `agent-system/extensions/core/scripts/task-lock.sh` — `cmd_release` now verifies the caller's
  `session_id` against `holder.json` before removing the lock directory (WARN-and-no-op on
  mismatch, unchanged behavior on match/absent).
- `agent-system/extensions/core/scripts/manage-topics.sh` — `add`/`set` converted to
  `state-write.sh`; gained an optional self-generating `--session-id` flag.
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` — Converted to `state-write.sh`;
  gained an optional self-generating `--session-id` flag.
- `agent-system/extensions/core/scripts/archive-task.sh` — The `del()` removal from
  `specs/state.json` (only) converted to `state-write.sh`; `archive/state.json` write left
  untouched (different file, out of scope). Gained an optional self-generating `--session-id`
  flag.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — `link_artifact`'s two write
  sites converted to `state-write.sh` (uses its existing required `session_id` argument).
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — The `--repair` write
  converted to `state-write.sh`; superseded the old "direct-invocation-only, skip the mutex"
  rationale; gained an optional self-generating `--session-id` flag.
- `agent-system/extensions/core/scripts/skill-base.sh` — Deleted the two zero-caller orphaned
  functions `skill_increment_artifact_number` and `skill_propagate_memory_candidates`. Converted
  `skill_propagate_completion_summary` and `skill_link_artifacts` (four write sites total) to
  `state-write.sh`; both gained an optional trailing `session_id` parameter with a self-generating
  fallback.
- `agent-system/extensions/core/scripts/update-task-status.sh` — Deleted `acquire_state_mutex` /
  `release_state_mutex` (the fail-open wrapper). PHASE 1 (state write) and PHASE 2 (TODO.md regen)
  combined into one `state-write.sh --regen-todo` call; a no-op status replay still runs a
  `.`-identity call so TODO.md regen stays mutex-protected on retry.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — Stages 7a, 7c, 7d, and 8 (6
  write sites total) converted to `state-write.sh`. Stage 7b confirmed pure delegation (no inline
  duplicate). The Stage 7-8a `specs/.scope-lock` bracket is kept (preserves all-stages-atomic
  property) but its own acquire now degrades gracefully to per-stage fail-closed acquisition on a
  bracket-timeout, instead of the old fail-open "proceeding unserialized".
- `agent-system/extensions/core/commands/implement.md` — Step 4 (`completion_summary`) converted
  to `state-write.sh`.
- `agent-system/extensions/core/commands/review.md` — The task-creation write (Section 4) and the
  `active_goal` write (Section 6.7.3) converted to `state-write.sh`; the latter folded with
  `--regen-todo`. Added an inline self-generating `session_id` (the file had none before).
- `agent-system/extensions/core/hooks/claude-stop-notify.sh`,
  `agent-system/extensions/core/hooks/wezterm-preflight-status.sh`,
  `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — The `workflow-active` marker
  converted to a per-session form (`workflow-active-<CC_SESSION_ID>`), committed as one
  atomic batch with the writer above. `claude-stop-notify.sh` suppresses on ANY session's marker
  (documented as deliberate); `wezterm-preflight-status.sh` now deletes only its own session's
  marker (the specific defect this batch closes) plus an opportunistic safe cleanup of the
  retired bare-path marker; `events-log-lifecycle.sh` reads its own session's marker via the
  `CC_SESSION_ID` it already captures.
- `agent-system/extensions/core/manifest.json` — Registered `state-write.sh` and
  `test-state-write-concurrency.sh` in `provides.scripts` (sorted).
- `agent-system/extensions/core/docs/architecture/architecture-spec.md`,
  `agent-system/extensions/core/docs/guides/creating-skills.md` — Dropped the two deleted
  `skill-base.sh` functions from their inventories.
- `agent-system/extensions/core/context/patterns/task-lock.md` — Added a "State-Write Convention"
  section; updated the stale `cmd_release`/`Consumers`/reentrancy-example references that had
  gone out of date after Phases 2, 7, and 8.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — Replaced the "Known
  limitation: rapid concurrent writes... could cause races" note with a description of the fixed
  `state-write.sh` convention.
- `.claude/scripts/state-write.sh`, `.claude/scripts/test-state-write-concurrency.sh` — Manually
  deployed (one-off workaround; the headless "Load Core" sync does not re-run `copy_scripts` for
  an already-loaded extension) and verified byte-identical to the source-store files.

## Decisions

- **Self-generating `--session-id` fallback, not caller threading.** Several converted scripts
  (`manage-topics.sh`, `reconcile-artifacts.sh`, `archive-task.sh`,
  `orchestrate-predispatch-review.sh`, `skill-base.sh`'s two functions) previously had no
  `session_id` parameter at all, and some (`manage-topics.sh`) have dozens of pre-existing
  callers across the core, cslib, and literature extensions. Rather than edit every caller, each
  converted script gained an optional `--session-id` (or trailing positional) parameter that
  self-generates one via the same portable pattern `command-gate-in.sh` uses when omitted. Every
  existing caller keeps working unchanged; attribution improves only where a caller opts in
  (`orchestrator-postflight.sh`'s call to `skill_propagate_completion_summary` was updated to
  pass its real `$session_id`, and `commands/task.md`'s `sync_session_id` generation was moved
  earlier so it covers both `reconcile-artifacts.sh` and `reconcile-task-status.sh`).
- **`orchestrator-postflight.sh` keeps its Stage 7-8a bracket, but the bracket's own acquire is
  now fail-closed-with-graceful-degradation, not fail-open.** The plan's task list only asked to
  decide keep-vs-drop the bracket (preferring keep, for the all-stages-atomic property); it did
  not explicitly ask to change the bracket's own acquire posture. This was necessary for
  consistency with the plan's system-wide fail-closed goal and for Phase 11's fail-open-wording
  audit to pass: on a bracket-acquire timeout, `SCOPE_MUTEX_HELD` is left unexported and each
  write stage falls through to `state-write.sh`'s own independent fail-closed acquire, rather
  than the whole postflight run either hard-aborting or proceeding unserialized. Verified against
  a fixture with a pre-claimed outer mutex.
- **`workflow-active` marker keyed by Claude Code's native session UUID
  (`$CLAUDE_CODE_SESSION_ID`), not the agent-system `sess_...` session_id.** The writer
  (`update-task-status.sh`) only has the agent-system session_id in scope, while the three
  consumer hooks primarily have access to Claude Code's native session UUID via hook stdin's
  `.session_id` field — these are two genuinely different id spaces (documented in
  `events-log-lifecycle.sh`'s own header comment). `$CLAUDE_CODE_SESSION_ID` is exported into
  every Bash tool invocation and is the SAME id space as hook stdin's `.session_id`, so it is the
  one identifier both the writer and every consumer can independently resolve without one
  reconstructing it from the other. Falls back to the agent-system `session_id` when the native
  UUID is unavailable (e.g. a manual/test invocation).

## Plan Deviations

- **Phase 4** (`manage-topics.sh`, `reconcile-artifacts.sh`, `archive-task.sh`): added
  self-generating `--session-id` fallback instead of threading through every existing caller
  (dozens for `manage-topics.sh`). `archive-task.sh` was also discovered to have zero callers
  anywhere in the source store.
- **Phase 5** (`orchestrate-predispatch-review.sh`): same self-generating `--session-id` fallback
  pattern.
- **Phase 6** (`skill-base.sh`): same self-generating fallback pattern for
  `skill_propagate_completion_summary` / `skill_link_artifacts`; ~15 existing callers across core
  skills and three extension implementation skills were left unedited.
- **Phase 8** (`orchestrator-postflight.sh`): converted the Stage 7-8a bracket's own acquire from
  fail-open to a graceful per-stage fail-closed degradation (see Decisions above) — broader than
  the plan's literal task-list wording, but necessary for the plan's own system-wide goal and
  Phase 11's audit gate.
- **Phase 9** (`commands/review.md`): added inline `session_id` generation (the file had none
  anywhere before this phase). The task-creation write was NOT folded with `--regen-todo` (unlike
  the `active_goal` write) because a second write (`manage-topics.sh set`) runs between it and the
  actual regen.
- **Phase 10**: `nvim/context/project/neovim/hooks/wezterm-integration.md` documents the marker
  path in prose but was not updated (documentation, not a code consumer — recorded as a follow-up,
  not silently omitted).
- **Phase 11** (major): the audit gate's own Scope Hypothesis — "zero hand-rolled
  `specs/state.json` tmp-and-mv sequences outside `state-write.sh`" — FAILED. See Follow-ups
  below for the full, itemized residual surface. This is recorded honestly rather than silently
  converted (uncosted work well beyond this plan's phases) or silently omitted (would
  misrepresent the plan's own gate as passing).

## Verification

- Build: N/A (bash scripts / markdown)
- Tests: `test-state-write-concurrency.sh` 4/4 passing (no-lost-update, staging-file isolation,
  fail-closed acquire, guest-mode reentrancy). `test-task-lock-reap.sh` 6/6 passing (unaffected
  by the `cmd_release` ownership check). `check-task-references.sh` PASS, 0 unexempted
  occurrences, re-verified after every phase.
- Files verified: Yes — every converted script/hook was smoke-tested against an isolated-temp-root
  fixture (state-write.sh's own suite, plus ad hoc fixtures for `manage-topics.sh`,
  `reconcile-artifacts.sh`, `archive-task.sh`, `reconcile-task-status.sh`,
  `orchestrate-predispatch-review.sh --repair`, `skill-base.sh`'s two functions,
  `update-task-status.sh` (dry-run, real preflight, no-op replay, guest mode),
  `orchestrator-postflight.sh` (full research-operation run, and the degraded-bracket path under
  contention), `commands/review.md`'s two write blocks, and a full two-session
  `workflow-active` fixture).

## Impacts

- Every `specs/state.json` write in the plan's original nine-script-plus-two-command-file scope
  is now mutex-guarded, fail-closed, and free of the shared-temp-path corruption channel.
- The `.claude/scripts/` live deploy has been manually updated for `state-write.sh` and
  `test-state-write-concurrency.sh` ONLY. Every other file this plan edited
  (`task-lock.sh`, `skill-base.sh`, `manage-topics.sh`, `reconcile-artifacts.sh`,
  `archive-task.sh`, `reconcile-task-status.sh`, `orchestrate-predispatch-review.sh`,
  `update-task-status.sh`, `orchestrator-postflight.sh`, `implement.md`, `review.md`,
  `claude-stop-notify.sh`, `wezterm-preflight-status.sh`, `events-log-lifecycle.sh`) is
  confirmed (via `check-extension-docs.sh` drift detection) to be STALE in the live `.claude/`
  deploy until the next full "Load Core" / "Sync all" pass. This is the pre-existing,
  already-documented extension-loader deploy gap (not something this task introduced or is
  scoped to fix), but it means the live runtime is NOT yet protected by any of this task's
  conversions except the two manually-deployed files, until the user runs a full sync.
- The still-unconverted core skills and command-file sites (see Follow-ups) remain exposed to
  the original lost-update and staging-file-collision hazards this task set out to close
  codebase-wide. The hazard is closed for the scripts/hooks layer; it is NOT yet closed for the
  skill-instruction layer.

## Follow-ups

- **Not fixed by this plan (explicit Non-Goal, restated for completeness)**: fifteen extension
  `SKILL.md` files' own inline `specs/state.json` write patterns (web, cslib, memory, present,
  python, typst, lean, latex, nix, nvim, z3, founder, epidemiology, formal, literature).
- **Newly discovered during Phase 11's audit, NOT converted (see plan file's Phase 11 "Audit
  Finding" for full detail)**: thirteen CORE `SKILL.md` files with their own inline hand-rolled
  `specs/state.json` writes — `skill-implementer`, `skill-implementer-hard`, `skill-planner`,
  `skill-planner-hard`, `skill-researcher`, `skill-researcher-hard`, `skill-reviser`,
  `skill-spawn`, `skill-status-sync`, `skill-team-implement`, `skill-team-plan`,
  `skill-team-research`, `skill-todo` — plus additional sites in `commands/task.md` (2 more,
  beyond the reconciliation-related session_id wiring already done) and `commands/todo.md` (4
  sites). Converting these to `state-write.sh` is realistically several more phases at the size
  and rigor of Phases 4-9 of this plan and should be scoped as a follow-up task.
- Several documentation files still show the OLD hand-rolled `jq ... > specs/tmp/state.json &&
  mv ...` pattern as the recommended idiom and should be updated to reference `state-write.sh`:
  `context/patterns/inline-status-update.md`, `context/patterns/jq-escaping-workarounds.md`,
  `context/patterns/file-metadata-exchange.md`, `context/troubleshooting/workflow-interruptions.md`,
  `context/standards/postflight-tool-restrictions.md`, `docs/guides/creating-skills.md`.
- `nvim/context/project/neovim/hooks/wezterm-integration.md` documents the `workflow-active`
  marker's old bare path and should be updated to describe the per-session form.
- The extension-loader deploy gap itself (headless "Load Core" sync does not re-run
  `copy_scripts`/`copy_manifest` for already-loaded extensions, for both new files AND edits to
  existing files) remains open. This plan worked around it for the two new files; it did not fix
  it, and the user should run a full "Load Core"/"Sync all" pass to bring the live `.claude/`
  deploy in sync with every other file this plan edited.

## References

- Plan: `specs/942_serialize_state_json_writers/plans/01_serialize-state-json-writers.md`
- Research report: `specs/942_serialize_state_json_writers/reports/01_serialize-state-json-writers.md`
- Progress files: `specs/942_serialize_state_json_writers/progress/phase-{1..11}-progress.json`
