# Implementation Summary: Fix lifecycle TTS notify variable (`$STATE_STATUS` -> `$status`)

- **Task**: 101 - fix_tts_only_announces_tab_1
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T20:17:00Z
- **Completed**: 2026-08-25T20:52:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-lifecycle-tts-notify-variable.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Every lifecycle skill's Stage 8a invoked the TTS/tab-color notifier as
`skill_lifecycle_notify "$STATE_STATUS"`, but no skill ever assigned `STATE_STATUS` -- the shared
postflight contract's real variable is `status`. Bash silently expanded the unset name to `""`,
`lifecycle-notify.sh` hit its documented empty-status no-op guard, and every lifecycle
announcement ("Tab N researched" / "planned" / "implemented") vanished before tab resolution or
TTS was ever reached. All 7 planned phases are complete: the rename landed at the shared origin
and all 12 propagated call sites, a loud-failure guard now makes an empty-status call observable
instead of silent, two adjacent defects found during scope confirmation were fixed, a narrow
regression lint now runs as `verify-deploy.sh` gate 15, and the fix was deployed and verified
end-to-end against real log evidence.

## What Changed

- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` -- Stage 8a code block
  and its two prose references renamed `$STATE_STATUS` -> `$status` (the canonical origin).
- 5 core `SKILL.md` files (`skill-planner`, `skill-planner-hard`, `skill-implementer`,
  `skill-implementer-hard`, `skill-reviser`) -- Stage 8a/8b call sites renamed to `$status`.
- 6 extension `SKILL.md` files (`skill-web-research`, `skill-web-implementation`,
  `skill-epi-research`, `skill-epi-implement`, `skill-cslib-research-hard`,
  `skill-cslib-implementation-hard`) -- same rename.
- `agent-system/extensions/core/scripts/skill-base.sh` -- `skill_lifecycle_notify` gained an
  empty-argument guard: warns to stderr naming the function, returns success, never invokes the
  notifier (never-blocking contract preserved).
- `agent-system/extensions/core/scripts/lifecycle-notify.sh` -- the existing empty-status no-op
  branch now appends a log line to `specs/tmp/claude-tts-notify.log` instead of exiting silently;
  usage comment updated to document this.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` -- new Group 2a:
  empty-status guard case and non-empty-path regression case for `skill_lifecycle_notify`.
- `agent-system/extensions/core/skills/skill-team-implement/SKILL.md` -- new Stage 12a added: this
  skill had NO lifecycle notification call at all (a distinct, adjacent defect), now calls
  `skill_lifecycle_notify "implemented"`.
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` -- rewrote
  the stale "fired directly by `update-task-status.sh` PHASE 5, using `$STATE_STATUS`" description
  (that mechanism no longer exists) across four sections to describe the real path: a skill's
  Stage 8a -> `skill_lifecycle_notify` -> `lifecycle-notify.sh` -> `tts-notify.sh --lifecycle`.
- `agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh` -- new narrow regression
  lint: fails when any `SKILL.md` under `agent-system/extensions/*/skills/` or any file under
  `agent-system/extensions/*/context/patterns/` passes `$STATE_STATUS` to `skill_lifecycle_notify`
  or `lifecycle-notify.sh` on the same line.
- `agent-system/extensions/core/scripts/verify-deploy.sh` -- new gate 15 wiring the lint above into
  the deploy-verification pipeline (source-store invocation, `REPO_ROOT="$TARGET"` override,
  SKIP-if-not-source-store, matching gates 6/7/11/12's convention).
- `agent-system/extensions/core/manifest.json` -- registered both new files in `provides.scripts`
  so `deploy-headless.sh` ships them.
- `agent-system/extensions/core/scripts/tests/test-lint-lifecycle-status-var.sh` -- new test suite,
  9 cases (3 negative-polarity call shapes, 1 positive-polarity, 1 false-positive control, 3
  real-tree legitimate-file guards).
- `agent-system/extensions/nvim/index-entries.json` -- corrected the `tts-stt-integration.md`
  entry's declared `line_count` (372 -> 382) after the nvim guide's own edit grew it; caught by
  Phase 7's pre-deploy baseline capture (see Plan Deviations).

## Decisions

- Rename direction: call sites renamed to `$status` (already the contract's documented
  Preconditions variable), not the inverse. Paired with a loud-failure guard rather than relying
  on the rename alone, since the rename-only approach is exactly what let the original defect
  survive six-plus weeks and a full unification refactor undetected.
- Regression guard scoped narrowly (line co-occurrence of `$STATE_STATUS` with
  `skill_lifecycle_notify`/`lifecycle-notify.sh`/`lifecycle_script`) rather than building a general
  undefined-variable linter, per the plan's Decision 2 -- the general class is deferred as a
  follow-up and separately covered at runtime by the loud-failure guard.
- The new lint lives in a new sibling script (`lint-lifecycle-status-var.sh`), not folded into
  `lint-postflight-boundary.sh`: that existing lint only scans deployed `SKILL.md` files and has no
  `context/patterns/*.md` scan surface, which this check requires.

## Plan Deviations

- **Phase 4** (`test-skill-base-lifecycle.sh` passes): deferred the full-suite pass to Phase 7.
  The suite's own `resolve_candidate()` prefers the deployed `skill-base.sh` (matching real
  runtime), which was still stale at Phase 4 (deploy is explicitly Phase 7's job). Logic was
  manually verified correct at Phase 4 by sourcing the source-store file directly; the full suite
  now passes 22/22 post-deploy (confirmed in Phase 7).
- **Phase 7** (pre-deploy baseline): the baseline capture surfaced one genuinely new finding beyond
  Decision 5's expected two -- `agent-system/extensions/nvim/index-entries.json` still declared
  `tts-stt-integration.md`'s `line_count` as 372 after Phase 5's edit grew the file to 382 lines.
  Fixed immediately, before deploying, by updating the declared count.

## Impacts

- Every lifecycle skill (research/plan/implement, standard and hard-mode, across core, web, epi,
  and cslib extensions) now correctly announces "Tab N researched/planned/implemented" via TTS and
  updates the WezTerm tab color on every postflight completion.
- `skill-team-implement` gains lifecycle announcement for the first time.
- Any future re-drift of this exact variable-name defect now produces two independent, immediate
  signals: a stderr warning at the call site, and a logged (not silent) no-op in
  `specs/tmp/claude-tts-notify.log` -- plus a hard CI-style gate failure via `verify-deploy.sh`
  gate 15 before it can even reach a deploy.
- `verify-deploy.sh` now runs 26 checks (was 25); its header documentation and findings-mode gate
  range were updated from "gate0 through gate14" to "gate0 through gate15".

## Follow-ups

- The general undefined-variable-vs-Preconditions-section linter recorded in Decision 2 remains a
  deliberately deferred follow-up; a separate task should carry it if desired.
- `get_tab_prefix()`'s multi-window `tab_id` sort-scoping (Decision 4) and the two pre-existing,
  unrelated `verify-deploy.sh --findings` items acknowledged in Decision 5 (lean4 doc line-count;
  the lake-build-guard.sh finding, which happened to resolve as a byproduct of this task's full
  resync) were intentionally left out of scope.
- Two files under `agent-system/extensions/core/scripts/` (`roadmap-integration.sh`,
  `state-write.sh`) plus a new untracked `test-state-write-large-payload.sh` were observed
  modified/added in the working tree during this session but were not touched by this task's work
  (confirmed via `git log` showing zero prior commits by this task against those paths). They were
  deliberately left uncommitted and unstaged -- flagging here per the observation-duty contract
  rather than silently working around them.

## References

- `specs/101_fix_tts_only_announces_tab_1/plans/01_fix-lifecycle-tts-notify-variable.md`
- `specs/101_fix_tts_only_announces_tab_1/reports/01_tts-tab-announcements-not-firing.md`
- `specs/101_fix_tts_only_announces_tab_1/progress/phase-{1..7}-progress.json`
