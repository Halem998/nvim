# Implementation Summary: Task #774

**Completed**: 2026-07-03
**Duration**: ~1 session

## Overview

Implemented the PLANNING leg of the three-leg `--hard` model (research=777, planning=774,
implementation=772). Tightened H8 phase sizing in `planner-hard-agent.md` to a bounded-unit
primary criterion with an explicit phase-count escape valve, added a skeleton+follow-up
decomposition mechanism (placeholder-token allocation, reversed dependency direction) across
`planner-hard-agent.md` and `skill-planner-hard/SKILL.md`, added a plan-time
`## Planned Strategic Sorries` schema to `plan-format.md` reusing task 778's `sorry_inventory`
field names verbatim, fixed two pre-existing `skill-implementer-hard` Stage 3b defects, and
settled the `follow_up_task` convention on plain integers in
`general-implementation-hard-agent.md`. All five in-scope files are dual-copy
(deployed + `.claude/extensions/core/`) and were kept in lockstep throughout.

## What Changed

- `.claude/agents/planner-hard-agent.md` (+ `.claude/extensions/core/agents/planner-hard-agent.md`)
  — Tightened H8: bounded-unit test as PRIMARY sizing criterion, line count demoted to
  secondary/advisory (~100-300 lines), phase-count ceiling (6-8) with skeleton escape valve added
  to Stage 3 table. Added Stage 4a "Skeleton Decomposition" sub-stage: `new_tasks` array reusing
  spawn-agent's exact 0-based schema, `{{FOLLOWUP:i}}` placeholder tokens, `.skeleton-return.json`
  artifact, SETTLED reversed dependency direction (follow-ups depend on skeleton), plain-integer
  `follow_up_task` convention. Added `wrap-up.md`/`anti-analysis.md` to Context References.
  Referenced the new `## Planned Strategic Sorries` section in Stage 5's plan-format additions.
- `.claude/context/formats/plan-format.md` (+ extensions/core copy) — Added
  `plan_metadata.skeleton` (bool) and `plan_metadata.follow_up_tasks` (array of int) to the Plan
  Metadata Schema. Added the `## Planned Strategic Sorries` conditional section (present only
  when `skeleton: true`) with a 5-column table mapping field-for-field to the 778
  `sorry_inventory` schema, plus a deviation-flag note for implementer-placed sorries not on the
  table.
- `.claude/skills/skill-planner-hard/SKILL.md` (+ extensions/core copy) — Added Stage 6b
  (Skeleton Task Allocation): duplicate-with-modification of `skill-spawn` Stages 7-11, consuming
  `.skeleton-return.json`, allocating real task numbers via Kahn-sorted `dependency_order`,
  creating task directories, writing `state.json` entries with the REVERSED dependency direction
  (`dependencies: [skeleton_task_number]`), and recording `plan_metadata.skeleton`/
  `follow_up_tasks` on the skeleton task. Added Stage 6c (Placeholder-Token Substitution Pass):
  single text-substitution pass resolving all `{{FOLLOWUP:i}}` tokens in the plan file (overview
  + Planned Strategic Sorries table) to real task numbers, no-op when no skeleton return exists.
- `.claude/skills/skill-implementer-hard/SKILL.md` (+ extensions/core copy) — Fixed Stage 3b: (a)
  handoff path changed from un-scoped `specs/.orchestrator-handoff.json` to
  `${task_dir}/.orchestrator-handoff.json`, matching `skill-orchestrate-hard`; (b) replaced
  integer-increment phase selection (`next_phase=$((phases_completed + 1))`) with a heading-scan
  of the plan file for the first `[NOT STARTED]`/`[PARTIAL]`/`[IN PROGRESS]` phase heading
  (addresses N.1/N.2 sub-phases and sparse numbering); (c) added skeleton-exhaustion detection
  that emits an explicit notice with pending follow-up task numbers when no incomplete phase
  remains and the prior dispatch was a skeleton.
- `.claude/agents/general-implementation-hard-agent.md` (+ extensions/core copy) — Changed the
  worked example `"follow_up_task": "774.2"` to a plain-integer example `"follow_up_task": "781"`,
  and added a one-line note settling the plain-integer convention (documentation correction, not
  a schema change).

## Decisions

- Followed the plan's settled design decisions verbatim: reversed dependency direction
  (follow-ups depend on skeleton), `{{FOLLOWUP:i}}` placeholder + single postflight substitution
  pass, duplicate-with-modification (no shared `spawn-tasks-from-return.sh` helper), plain-integer
  `follow_up_task` format, plan-time schema homed in `plan-format.md`/`planner-hard-agent.md` only.
- Left `wrap-up.md` and `anti-analysis.md` completely untouched (778's territory, single-copy,
  implement-time schema is final) — confirmed via `git status`/`git diff --stat` across all
  task-774 commits.
- Did not touch `skill-orchestrate-hard`, `skill-spawn`, `spawn-agent`, or standard-mode
  planner/implementer files, per the plan's territory constraints.
- Mirrored (did not fix) the pre-existing literature-script-name drift
  (`literature-briefing-invoke.sh` deployed vs `literature-briefing.sh 2>/dev/null` in
  extensions/core) in both SKILL.md pairs.

## Plan Deviations

- **Phase 7 doc-lint check**: `bash .claude/scripts/check-extension-docs.sh` exits 1 overall, not
  0 as the plan's verification criterion literally states. Root cause: a pre-existing, unrelated
  FAIL in the `[lean]` extension (`routing_hard` targets `skill-lean-research-hard`/
  `skill-lean-implementation-hard` declared in `.claude/extensions/lean/manifest.json` but not
  deployed because the lean extension is not installed on this machine). Confirmed pre-existing
  via `git log --follow -- .claude/extensions/lean/manifest.json`, which shows the
  `routing_hard` block was introduced 10+ commits before this task and the lean extension is
  entirely outside task 774's territory. The `[core]` extension entry — which covers all five
  in-scope files — reports `OK`. Treated as an accepted deviation rather than a blocker since
  fixing the lean extension's routing_hard declarations is out of scope for a planning-leg task
  scoped to five specific dual-copy files.

## Verification

- Build: N/A (documentation/skill-doc edits only)
- Tests: N/A (no automated test suite for `.claude/` skill docs)
- Files verified: Yes — `diff` confirms byte-identical lockstep for
  `planner-hard-agent.md`, `general-implementation-hard-agent.md`, and `plan-format.md` (deployed
  vs `.claude/extensions/core/`); both SKILL.md pairs (`skill-planner-hard`,
  `skill-implementer-hard`) differ from their extensions/core copies ONLY by the 4 pre-existing
  literature-script-name drift lines each.
- `git status`/`git diff --stat` confirm no out-of-scope files were touched across any task-774
  commit (no `wrap-up.md`, `anti-analysis.md`, `skill-orchestrate-hard`, `skill-spawn`,
  `spawn-agent`, or standard-mode planner/implementer files).
- Grep-verified: bounded-unit + escape-valve language present in H8; `.skeleton-return.json`,
  `{{FOLLOWUP`, `new_tasks` schema, and both contract files present in planner-hard-agent Context
  References; `## Planned Strategic Sorries` defined in plan-format.md and referenced from
  planner-hard-agent.md; no literal `"follow_up_task": "774.2"` value remains anywhere (only
  negative-example mentions inside "never dotted" documentation notes).

## Notes

- This is a documentation/skill-doc-only change; no runtime behavior is exercised until a real
  `--hard` plan later triggers the skeleton path (Phase 4a of `planner-hard-agent.md`) or a task
  hits the Stage 3b heading-scan / skeleton-exhaustion paths in `skill-implementer-hard`.
- Task 779 also edits `skill-implementer-hard/SKILL.md` and
  `general-implementation-hard-agent.md`; the plan's postmortem constraints called for
  serialization on these two files. No concurrent edit was observed during this dispatch.
- Follow-on note for a future task: the pre-existing `[lean]` doc-lint FAIL (routing_hard targets
  not deployed) is unrelated to this task but remains an open item if strict `check-extension-docs.sh`
  exit-0 is ever required as a CI gate.
