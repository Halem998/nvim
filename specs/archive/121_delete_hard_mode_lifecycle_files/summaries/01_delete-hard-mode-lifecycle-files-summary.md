# Implementation Summary: Task #121

- **Task**: 121 - Delete hard mode lifecycle files
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T16:20:00Z
- **Completed**: 2026-09-02T19:30:00Z
- **Effort**: ~11 hours (across 8 phases)
- **Dependencies**: 118, 119, 120, 128, 124 (all completed)
- **Artifacts**: plans/01_delete-hard-mode-lifecycle-files.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Deleted the four superseded `-hard` skills (`skill-orchestrate-hard`, `skill-researcher-hard`,
`skill-planner-hard`, `skill-implementer-hard`) and their three matching agent files
(`general-research-hard-agent`, `planner-hard-agent`, `general-implementation-hard-agent`) from
`agent-system/extensions/core/`, retargeted every lint/test/doc reference off them onto
`skill-orchestrate/SKILL.md`'s single-engine hard-mode implementation, and drove the repo-wide
reference count for the seven deleted names to zero (excluding `specs/`). Cslib's and lean's own,
still-live `-hard` skills/agents were explicitly preserved and are unaffected.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — deleted (1,833 lines)
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md` — deleted (275 lines)
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md` — deleted (462 lines)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — deleted (507 lines)
- `agent-system/extensions/core/agents/general-research-hard-agent.md` — deleted (332 lines)
- `agent-system/extensions/core/agents/planner-hard-agent.md` — deleted (334 lines)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — deleted (545 lines)
- `agent-system/extensions/core/manifest.json` — `routing_hard`/`routing_agents_hard` top-level
  keys removed entirely; 7 deleted-asset entries removed from `provides.agents`/`provides.skills`
- `agent-system/extensions/cslib/manifest.json` — 8 dead `routing_hard`/`routing_agents_hard`
  entries removed in matched pairs (`research.pr`, `plan.cslib`, `plan.pr`, `implement.pr`);
  cslib's own live `-hard` entries retained
- `agent-system/extensions/lean/manifest.json` — unmodified by design (verified: empty `git diff`)
- `agent-system/extensions/{core,cslib,lean}/index-entries.json` — 53 dead `load_when.agents[]`
  members pruned; 20 core entries whose entire `load_when` became empty marked `on_demand: true`
  per schema; line_count drift for context files touched in Phases 6-7 mechanically corrected by
  the Phase 8 deploy regeneration
- `agent-system/extensions/core/scripts/lint/{lint-contract-compliance,lint-agent-contracts,
  lint-task-lookup-adoption}.sh` — Checks A/C/E/F retargeted from the deleted files onto the
  surviving engine/contracts; dead in-scope paths and exemption entries pruned
- `agent-system/extensions/core/scripts/tests/{test-routing-resolution,
  test-resume-scan-nonconformance,test-loop-guard-budget-override}.sh`,
  `agent-system/extensions/core/scripts/test-session-runtime-files.sh` — retargeted off the
  deleted hard-mode defaults/paths; a discharged skip-guard removed
- `agent-system/extensions/core/scripts/skill-base.sh` — one dead `[hard-orchestrate]`
  `gate_attributed_path` case arm removed (confirmed genuinely unreachable)
- Roughly 40 documentation/context/comment files across `agent-system/extensions/core/{skills,
  commands,merge-sources,context,docs,scripts}/` and 5 cslib/lean extension-side files —
  de-referenced from the deleted paths, rewritten to describe the current single-engine
  architecture rather than deleted or silently stripped of provenance narrative
- `specs/121_delete_hard_mode_lifecycle_files/.reference-census-after.txt`,
  `.gate-baseline-after.txt` — new, Phase 8 zero-hit confirmation and full gate-run evidence
- `.claude/` deploy tree — regenerated via `deploy-headless.sh`; already carried zero hits for the
  seven names, confirming an earlier in-task deploy refresh, and the fresh regeneration re-confirms
  the clean state plus corrects `index-entries.json` line-count drift

## Decisions

- Narrowed the charter's literal "remove `routing_hard`/`routing_agents_hard` from core, cslib,
  and lean" instruction to entry-level surgery (recorded as the plan's "Scoping Deviation"):
  core's blocks are removed wholesale since every entry names a deleted asset; cslib has 8 dead
  entries removed while its 4 live `-hard` entries are retained; lean is left fully untouched
  since none of its entries name a deleted asset and removing them would break lean's live
  `--hard` routing for no zero-hit benefit.
- `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES` removal was deferred from Phase 2 into Phase
  4's atomic-batch commit: removing the exemption while the four `-hard` SKILL.md files still
  existed un-exempted one genuine hand-rolled violation per file, so the exemption removal and the
  file deletion had to land in the same commit.
- `skill-base.sh`'s `[hard-orchestrate]` case arm was removed rather than retargeted, after
  confirming it was genuinely unreachable (the sole call site always passes `"[orchestrate]"`
  regardless of effort mode).
- Prose de-referencing (Phases 6-7) rewrote passages to describe the current architecture rather
  than deleting historical/provenance narrative outright, preserving the record of what was
  migrated from the standalone hard-mode engine.

## Plan Deviations

- **Phase 2, `lint-task-lookup-adoption.sh` `EXCLUDED_FILES` entries**: deferred to Phase 4's
  atomic-batch commit rather than removed in Phase 2 as originally chartered — removing the
  allowlist entry while the file still existed un-exempted a genuine violation per file. Verified
  reverting restored the exact Phase 1 baseline result.
- No other deviations. All 8 phases completed per plan; no scope was descoped or excluded.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `scripts/tests/run-all.sh` 62/62; `test-routing-resolution.sh` 13/13;
  `test-index-entries-schema.sh` 9/9; `test-lint-agent-contracts.sh` and
  `test-lint-task-lookup-adoption.sh` both green; `test-skill-base-lifecycle.sh` green
- Files verified: Yes — all seven deletion targets absent from disk; all three manifests parse as
  valid JSON; `git diff` on `lean/manifest.json` is empty; all 8 cslib/lean `-hard` assets present
  and still routed
- Zero-hit confirmation: `grep -rn -E` over the seven deleted names returns 0 hits in
  `agent-system/` and 0 hits repo-wide excluding `specs/` (before: 449 raw name occurrences /
  359 grep-line occurrences across 60 files)
- Full gate set: `lint-contract-compliance.sh`, `lint-agent-contracts.sh`,
  `lint-task-lookup-adoption.sh`, `lint-routing-wiring.sh`, `lint-branch-gated-sections.sh`,
  `lint-lifecycle-status-var.sh`, `lint-postflight-boundary.sh`, `lint-scoped-commit-boundary.sh`
  all exit 0; `check-extension-docs.sh` reproduces only the pre-existing literature-extension
  failure recorded in the Phase 1 baseline; `verify-deploy.sh` reports 3/30 checks failed, all
  three independently confirmed pre-existing and unrelated to this task (see Follow-ups)

## Impacts

- `/orchestrate --hard` for `general`/`meta`/`markdown` task types now resolves entirely through
  `skill-orchestrate`'s single hard-mode-gated engine (no separate `-hard` skill/agent dispatch);
  `cslib` and `lean4` continue routing to their own domain-specific `-hard` skills/agents,
  unaffected.
- Core's general/meta/markdown task types under `--hard` now share the same
  `general-implementation-agent` as standard mode for the implement phase, which never writes
  `.orchestrator-handoff.json` — a pre-existing architectural consequence surfaced (not created)
  during Phase 6, and already correctly documented in `handoff-schema.md` before this task closed.
- Reduces the core extension's file count by 7 files (~4,288 lines) and its manifest surface by
  2 top-level routing keys.

## Follow-ups

- `verify-deploy.sh` gate 16 (the `routing_hard`/`routing_agents_hard` migration warning) reports
  PASS in this repository's own deploy because `.claude-extensions.json` does not load the cslib
  or lean extensions here. In a deploy where cslib and/or lean ARE loaded, gate 16 is expected to
  warn since both extensions still legitimately declare `routing_hard`/`routing_agents_hard` for
  their own live `-hard` assets — that residue is out of this task's scope and belongs to a
  separate task chartered to retire the four-block routing model entirely (tracked upstream of
  this task as a dependency in `specs/state.json`, e.g. task 127's routing-ladder collapse work).
- Three pre-existing, independently-confirmed-unrelated gate failures remain open, none caused by
  or in scope for this task: (1) `check-extension-docs.sh`/`verify-deploy.sh` — a literature
  extension `index-entries.json` line_count mismatch on
  `project/literature/patterns/zotero-item-creation.md`; (2) `validate-state.sh --deep` — unknown
  `abandon_reason`/`blocks_note` fields on unrelated project numbers
  (94, 46, 31, 64, 73, 115, 132, 106, 107, 109), confirmed present in `specs/state.json` before
  this task's first commit; (3) `lint-state-writer-boundary.sh` — 4 hand-rolled `state.json`
  writes in `test-force-phases.sh`, last touched by an unrelated task and never part of this
  task's file scope.
- Observed but not addressed (per this task's file scope): a set of uncommitted working-tree
  modifications not made by this task were present at Phase 8 start
  (`.claude-extensions.json`, `.memory/memory-index.json`, `after/ftplugin/{markdown,tex,typst}.lua`,
  `agent-system/extensions/latex/README.md`, `docs/MAPPINGS.md`, `docs/TYPST.md`,
  `lua/neotex/plugins/editor/README.md`, `lua/neotex/plugins/editor/which-key.lua`,
  `lua/neotex/util/README.md`, `lua/neotex/util/process.lua`, `specs/events.jsonl`, and an
  untracked `agent-system/extensions/literature/scripts/literature-pyenv/` directory), most likely
  belonging to other concurrently-dispatched agents in this session. Excluded from this task's
  commit staging.

## References

- `specs/121_delete_hard_mode_lifecycle_files/plans/01_delete-hard-mode-lifecycle-files.md`
- `specs/121_delete_hard_mode_lifecycle_files/reports/01_precondition-verification.md`
- `specs/121_delete_hard_mode_lifecycle_files/.reference-census-before.txt`,
  `.reference-census-after.txt`
- `specs/121_delete_hard_mode_lifecycle_files/.gate-baseline-before.txt`, `.gate-baseline-after.txt`
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A7 deletion ledger)
