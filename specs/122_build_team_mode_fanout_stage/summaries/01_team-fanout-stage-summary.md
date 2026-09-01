# Implementation Summary: Task #122

- **Task**: 122 - Build the team-mode shared fan-out stage in skill-orchestrate
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T18:35:00Z
- **Completed**: 2026-09-01T00:33:41Z
- **Effort**: ~9.5 hours (single dispatch, all 8 phases)
- **Dependencies**: 117 (dispatch prep stage), 119 (hard-mode state-machine migration)
- **Artifacts**: plans/01_team-fanout-stage.md, summaries/01_team-fanout-stage-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a single, phase-parameterized team-mode fan-out stage to `skill-orchestrate/SKILL.md`: a
shared skeleton (**Stage 3.6**) handling availability checking, effective team-size resolution,
per-teammate spawn/wait/collection, D3 postflight session correlation, and staging/cleanup, plus a
per-phase teammate-plan builder (**Stage 3.6a**) supplying the actual teammate roster for
research/plan (fixed named roles, disjoint artifact files, live `synthesis-agent` dispatch) and
implement (dynamic plan-phase-keyed waves, real source-file territory, ad-hoc debugger role).
`--team`/`--team-size` were added to `orchestrate.md` with an effort-aware default team size
(3 baseline / 2 under `--fast` / 4 under `--hard`), threaded through a strictly additive
`TEAM_SIZE_EXPLICIT` export from `parse-command-args.sh` so the effort-aware default and an
explicit `--team-size` can be told apart without touching any existing consumer.

## What Changed

- `agent-system/extensions/core/scripts/parse-command-args.sh` — added `TEAM_SIZE_EXPLICIT`
  export ("true" only when `--team-size` was actually matched), initialized alongside the
  existing `TEAM_SIZE=2` default; no existing value, clamp, or consumer behavior changed.
- `agent-system/extensions/core/commands/orchestrate.md` — added `--team`/`--team-size` to the
  Options table; narrowed the Constraints bullet from a flat "not supported" to "single-task only,
  accepted-and-ignored with a notice in multi-task mode"; threaded `TEAM_MODE`/`TEAM_SIZE`/
  `TEAM_SIZE_EXPLICIT` through STAGE 0's exports comment and prose, STAGE 2 DELEGATE's args
  string and JSON context, and MULTI-TASK DISPATCH's args string and JSON context (diagnostics
  only, with an explanatory sentence that multi-task mode does not fan out per task).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` —
  - Stage 1: read `team_mode`/`team_size`/`team_size_explicit` and derive `team_size_eff`
    immediately after the existing `hard_mode` derivation, applying the D2 explicit-vs-default
    rule and the 3/2/4 effort table, clamped to 2-4.
  - New **Stage 3.6: Team Fan-Out** (shared skeleton): inputs table, early
    `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` availability check with graceful degradation, spawn
    loop (per-teammate Stage 3.5 sub-call, `dispatch_seq` mint, Agent tool invocation), wave wait
    with 30-minute timeout, collection, the full D3 session-correlation sub-block (marker capture,
    teammate non-obligation, post-wave re-assertion with a loud stderr line, correlation-key
    naming with a path/function-name-only cross-reference to `hooks/subagent-postflight.sh`'s
    `find_marker()`), staging/cleanup statements, and the three-output contract
    (`fanout_degraded`/`teammate_results`/`synthesis_path`).
  - New **Stage 3.6a: Teammate-Plan Builder**: `research` branch (a/b/c/d fixed roles gated by
    `team_size_eff`), `plan` branch (a/b/c fixed roles), a shared D4 synthesis step that dispatches
    `synthesis-agent` live (with an inline-synthesis fallback), and the `implement` branch
    (hard-mode suppression stated first, conformance gate via
    `scripts/lib/phase-heading-patterns.sh`, wave-table-derived teammate set, H7 territory built
    from each phase's own "Files to modify" list, multi-wave execution, and an ad-hoc debugger
    role).
  - Stage 4: added a `team_mode` fork (full statement at `not_started`, pointer references at
    `researching`/`researched`/`planning`/the base branch of `planned`/`implementing`) — each
    fork's `else` branch is the pre-existing single-agent dispatch, left byte-identical.
  - Amended the "Parallel Wave Dispatch: DISABLED" note to scope it to the hard branch's own
    per-phase dispatch, naming team-mode research/plan fan-out as the sanctioned base-mode
    exception and stating implement fan-out stays suppressed under `hard_mode`.
  - Stage MT-1: added `team_mode` read (diagnostics only) and a one-time accepted-and-ignored
    notice; Stage MT-4 received no fan-out fork, by design.

## Decisions

- **D1**: shared skeleton (Stage 3.6) + per-phase builder (Stage 3.6a), mirroring the existing
  Stage 4/Stage 3.5 relationship, rather than one `{phase}`-substituted template.
- **D2**: additive `TEAM_SIZE_EXPLICIT` export rather than changing `TEAM_SIZE`'s pre-flag default
  (which would have broken `commands/implement.md`'s bare `-gt` clamp) or silently overriding an
  explicit `--team-size`.
- **D3**: implemented the orchestrator-side half of the session-correlation fix (marker capture,
  teammate non-obligation, post-wave re-assertion) here; the hook-side read predicate in
  `hooks/subagent-postflight.sh`'s `find_marker()` is out of this task's file scope and is a
  separate, dependent hook-side task's job.
- **D4**: wired `synthesis-agent` live for research/plan synthesis without editing the agent file.
- **D5**: `--hard --team` fully fans out research/plan (hard contracts injected per teammate via
  Stage 3.5 pass-through); implement fan-out is suppressed under `hard_mode` (H1 wins); `--team`
  in multi-task mode is accepted and ignored with a loud notice.

## Plan Deviations

- Phases 3-6 were authored as one contiguous Stage 3.6/Stage 3.6a text region in a single editing
  pass (the four phases share the same file region, making a literal edit-by-edit split
  impractical) and were verified against all four phases' verification criteria together, then
  each phase's checklist and heading marker were still updated individually. Recorded inline in
  the plan at Phase 3's task list.

## Verification

- Build: N/A (documentation/skill-prose change; no compiled artifact)
- Tests: `bash -n` on `parse-command-args.sh` and on the extracted bash fragments of the new
  Stage 3.6/3.6a region — pass. Manual sourcing of `parse-command-args.sh` confirmed
  `TEAM_SIZE`/`TEAM_SIZE_EXPLICIT` for the no-flags, `--team`, and `--team --team-size 4` cases.
- Lint/validate: `check-task-references.sh` (PASS, 0 hits), `lint-postflight-boundary.sh` (0
  violations across 33 files), `lint-routing-wiring.sh` (323 passed, 0 failed). `validate-wiring.sh`
  reports 41 pre-existing failures, all `project/neovim/**`/`project/memory/README.md` missing
  context files, confirmed unrelated via `git diff 029e328dc..HEAD --stat -- agent-system/
  scripts/` (only the three D2-scoped files changed). `validate-state.sh`'s 2 failures
  (`abandon_reason`, `blocks_note` unknown fields on unrelated project numbers) predate this task.
  `check-deploy-freshness.sh` WARNs the deployed `.claude/` tree is stale — the expected advisory
  outcome, since regeneration is a manual operator step (Non-Goal).
- Files verified: `git diff 029e328dc..HEAD --stat -- agent-system/ scripts/` shows exactly the
  three D2-scoped files changed; `git status --short` confirms `agents/synthesis-agent.md`,
  `context/contracts/territory.md`, `hooks/subagent-postflight.sh`, and the three
  `skills/skill-team-*/` directories are untouched; `grep -c "^### Stage 3.6:"` and
  `grep -c "^### Stage 3.6a:"` each return 1.

## Impacts

- `/orchestrate N --team` now fans out research/plan/implement dispatch across parallel teammates
  for the first time; `--team` alone (teams runtime unset) and `--team` in multi-task mode both
  degrade/no-op safely with a loud notice, so no existing non-`--team` behavior changes.
- `synthesis-agent` now has a live dispatch call site (previously zero), reached only when
  `--team` fans out research or plan.
- The "Parallel Wave Dispatch: DISABLED" note's scope is now stated accurately rather than reading
  as a blanket claim.

## Follow-ups

- **Hook-side residue (D3)**: `hooks/subagent-postflight.sh`'s `find_marker()` still does not
  read the marker's own `session_id` field before counting/deleting it — the read-side half of
  the session-correlation fix. This is a separate, dependent hook-side task's declared scope; this
  task implemented only the orchestrator-side mitigation (marker capture, teammate non-obligation,
  post-wave re-assertion).
- **`events.jsonl` misattribution amendment**: also out of this task's scope — it is a property of
  `events-log-lifecycle.sh`'s SubagentStop branch, verified by the hook-side task that owns that
  file.
- Deleting/consolidating `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (now
  that Stage 3.6/3.6a exist) is explicitly a successor task's job, not this one's (plan Non-Goal).
- The deployed `.claude/` tree is now stale relative to the source store; regeneration
  (`deploy-headless.sh` or the picker's Reload All) is the operator's manual next step.

## References

- specs/122_build_team_mode_fanout_stage/plans/01_team-fanout-stage.md
- specs/122_build_team_mode_fanout_stage/reports/01_team-fanout-stage-research.md
- agent-system/extensions/core/context/contracts/territory.md (referenced, not modified)
- agent-system/extensions/core/agents/synthesis-agent.md (referenced, not modified)
