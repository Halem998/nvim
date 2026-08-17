# Implementation Summary: Task #5

- **Task**: 5 - implement_roadmap_items_producer (roadmap_items is never derived by any implement path, so /todo's ROADMAP sync is dead in practice)
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T21:31:23Z
- **Completed**: 2026-08-10T23:45:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_roadmap-items-producer.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the producer half of `/todo`'s ROADMAP.md sync, which computed nothing because
implementation agents were never handed `specs/ROADMAP.md` to read. Threaded `roadmap_path`
through all 8 implementation-agent dispatch contexts (2 implementer skills + 6 across both
orchestrate skills), added a read-only "Load Roadmap Context" stage plus a directive Stage 6a to
both implementation agents, added a distinct `roadmap_no_match` silent-zero signal to `/todo`,
proved the whole chain end to end on an isolated fixture suite, and regenerated the deploy tree
with a full gate run.

## What Changed

- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — added `roadmap_path` to
  Stage 4 delegation context
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — same
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added `roadmap_path` to all
  5 implementation-dispatch `context` objects (initial, resume-with-continuation,
  resume-no-continuation, post-revise re-dispatch, multi-task dispatch)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — added `roadmap_path` to
  its `dispatch_context` block
- `agent-system/extensions/core/agents/general-implementation-agent.md` — new "Stage 6-roadmap:
  Load Roadmap Context" read-only stage; Stage 6a rewritten from "optionally... only include if
  clearly maps" to a directive verbatim-copy check
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — new "Stage 5.9:
  Load Roadmap Context" stage; Stage 7's roadmap_items pointer text carries the same directive
- `agent-system/extensions/core/commands/todo.md` — new `roadmap_no_match` boolean derived at
  Step 3.5.5 (eligible tasks non-empty AND eligible matches empty AND open roadmap checkboxes >
  0), defined in both error-handling fallback blocks; the dry-run and final-summary sections both
  grew a fourth branch alongside the existing three, narrowing the omission condition
- `agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh` — new fixture-driven
  suite (4 cases, 11 assertions): end-to-end verbatim propagation + annotation, meta suppression,
  paraphrase non-match, and the `roadmap_no_match` derivation in isolation
- `agent-system/extensions/core/manifest.json` — registered the new test suite in
  `provides.scripts` (required for deploy discovery; see Plan Deviations)
- `specs/state.json` / `specs/TODO.md` — cleared task 5's own stale `dependencies: [1004]` entry
  (see Plan Deviations)
- Regenerated: `.claude/**` (deploy artifact, all 8 dispatch sites + both agent stages + the
  `todo.md` branch + the new test suite confirmed present in the deployed tree)

## Decisions

- Kept `roadmap_items` derivation entirely in the implementation agent's own judgment (no new
  postflight matcher); `roadmap-integration.sh`'s `explicit_roadmap_item` tier already consumes
  exactly this shape of data correctly once populated.
- Stage 6a's directive requires a verbatim copy of the open roadmap item's text — a paraphrase
  silently fails to match downstream rather than risking a false annotation (verified directly by
  Case 3 of the new test suite).
- `roadmap_no_match` reuses data `/todo` already computes at Step 3.5 (no new script call, no new
  matcher tier), gated on all three conditions so it only fires in the genuinely-informative case.

## Plan Deviations

- **Task 5.2** (Phase 5) altered: registering the new test suite in
  `agent-system/extensions/core/manifest.json`'s `provides.scripts` allow-list was required and
  not anticipated by the plan — `scripts/tests/*.sh` deploy is manifest-driven, not
  glob-discovered; the suite was silently absent from `.claude/scripts/tests/` until registered.
- **Task 5.3** (Phase 5) altered: cleared task 5's own stale `dependencies: [1004]` entry in
  `specs/state.json` via `state-write.sh`, surfaced by `verify-deploy.sh`'s
  `validate-state.sh --deep` gate as a dangling-dependency finding. In scope because the plan's
  own metadata line already declares this dependency satisfied ("Dependencies: None ... confirmed
  satisfied/vaulted by the research report") — the state.json entry was simply stale relative to
  the plan's own declaration.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: `test-roadmap-items-producer.sh` — 11/11 assertions pass, exit 0; discovered and passing
  under `run-all.sh` in both source-store and deployed modes
- Files verified: Yes (all edits confirmed via targeted grep/diff review at each phase)
- `verify-deploy.sh`: 21/23 gates pass. 2 pre-existing failures confirmed unrelated to this task
  and out of scope (see Follow-ups)

## Impacts

- Every `/implement` and `/orchestrate` path (standard and hard mode, single- and multi-task) now
  supplies implementation agents with `specs/ROADMAP.md`, closing the actual root cause of "24
  tasks completed, 0 roadmap annotations."
- `/todo` runs now surface an explicit "no roadmap items matched" signal instead of silently
  omitting the Roadmap section when eligible tasks and open items both existed but nothing
  matched.

## Follow-ups

- `test-claude-refresh-matcher.sh` fails consistently in isolation (confirmed via `git diff
  --stat` to be untouched by this plan) — a live-process/pid-matching suite with what looks like a
  genuine environment-sensitivity bug ("still excludes the SAME inhibitor after its target was
  killed -- tautological check"). Pre-existing, unrelated to roadmap_items; worth a dedicated fix
  task but out of scope here.
- `validate-state.sh --deep` still reports one dangling-dependency finding unrelated to this task:
  task 9 (`resolve_deploy_orphan_file_parity`) carries `dependencies: [1015]` pointing at a vaulted
  task, mirroring the same stale-dependency pattern this task's own entry had. Left untouched
  deliberately — task 9's own metadata is out of scope for this implementation.
- No further roadmap_items-producer work outstanding; the verification bar (end-to-end fixture
  demonstration, meta suppression, paraphrase non-match) is fully met.

## References

- `specs/005_implement_roadmap_items_producer/plans/01_roadmap-items-producer.md`
- `specs/005_implement_roadmap_items_producer/reports/01_roadmap-items-producer.md`
- `agent-system/extensions/core/scripts/tests/test-roadmap-items-producer.sh`
