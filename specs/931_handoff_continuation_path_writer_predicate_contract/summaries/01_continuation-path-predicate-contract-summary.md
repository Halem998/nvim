# Implementation Summary: Task #931

**Completed**: 2026-07-27
**Duration**: ~2 hours

## Overview

Fixed a field-shape schism between the sole active `.orchestrator-handoff.json` writer (H9
hard-mode wrap-up, which emits a flat top-level `continuation_path` string) and the readers
(`orchestrate-triage-classify.sh` and both `skill-orchestrate`/`skill-orchestrate-hard`
`SKILL.md` engines), which previously checked only the nested `continuation_context.handoff_path`
— a key the active writer never produces. A real, actionable continuation therefore classified
as `handoff_state: "empty"` and stranded the task. Implemented Option B: every reader now accepts
either form, normalizing to `{ handoff_path, orchestrator_mode: true }` before it reaches a
successor dispatch, matching the precedent `validate-handoff.sh` already codified.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — new
  regression suite (4 fixtures, both engines), proven RED against the unfixed predicate before
  the fix landed.
- `agent-system/extensions/core/manifest.json` — registered the new suite in `provides.scripts`.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — `continuation_ok` now
  accepts either the nested or flat form; header precedence block, verdict-schema comment, and
  `reason` string updated to match.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 4 partial handler,
  Stage 5 result read, and Stage MT-4 dispatch bullet all resolve either form and normalize
  before the dispatch-context row (closing the secondary gap: the successor implement dispatch
  now actually receives a usable continuation pointer even from a flat-form writer).
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 4 (previously
  flat-only) and Stage 5 (previously nested-only) unified on dual-form resolution.
- `agent-system/extensions/core/scripts/skill-base.sh` — comment-only disposition note on
  `skill_write_orchestrator_handoff` (documented as dead: zero callers, do not delete, do not
  rewire).
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — rewritten to document
  both accepted forms, correct the "sole active writer" contradiction, and show both example
  shapes.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — companion doc
  found stale during the Phase 6 residual sweep; updated for the same dual-form consistency
  (not in the original plan's file list — see Plan Deviations).

## Decisions

- Option B (relax readers) over Option A (force all writers onto the nested form): the nested
  form's only writer has zero callers, so teaching readers to accept the flat form the live
  writer actually emits is the smaller, more honest change.
- `skill_write_orchestrator_handoff` stays defined-but-unreferenced: documented, not deleted or
  rewired, since it's now a valid writer of an already-accepted form.
- Dispatch-context normalization was scoped as its own explicit work (Phase 3), not assumed to
  fall out of the predicate fix automatically.

## Plan Deviations

- **Phase 6** (residual-nested-only sweep) altered beyond its stated file scope: found
  `docs/architecture/orchestrate-state-machine.md` — a companion doc not named in any phase's
  "Files to modify" list — describing the same nested-only rule with stale text (state table
  row, a code snippet, and an example). Updated it for dual-form consistency rather than leaving
  a third silently-diverging copy of the rule this task exists to fix. Doc-only, low-risk, within
  `agent-system/extensions/core/docs/**`. See `progress/phase-6-progress.json`'s `deviations`
  array.

## Verification

- Build: N/A (shell scripts + Markdown docs)
- Tests: `test-orchestrate-triage-classify.sh` — RED pre-fix (exit 1, 4/9 failed, Fixture A and D
  as predicted), GREEN post-fix (exit 0, 9/9 passed). Two sibling suites in `scripts/tests/`
  still pass (8/8, 21/21). `validate-handoff.sh` accepts both fixture forms, unregressed.
- Files verified: Yes — `bash -n` clean on all 3 modified/created shell files, `jq .` clean on
  `manifest.json`, `git status --short -- .claude/` empty, sibling `dispatch_status`/OFF-SCHEMA
  work in both SKILL.md files confirmed untouched by diff, zero task-number citations across the
  full accumulated diff.

## Notes

Named follow-up recorded (not implemented here, per the plan's explicit non-goal): give
`cslib-implementation-hard-agent.md` Stage 5 a `continuation_path` key plus the
populate-on-partial/blocked instruction the core and lean hard-mode agents already carry — its
hardcoded-null `continuation_context` currently populates no continuation pointer of any form,
independent of this task's reader fix.
