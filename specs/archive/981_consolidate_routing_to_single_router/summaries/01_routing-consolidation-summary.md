# Implementation Summary: Task #981

- **Task**: 981 - consolidate_routing_to_single_router
- **Status**: [COMPLETED]
- **Started**: 2026-08-05
- **Completed**: 2026-08-06
- **Effort**: ~10.5 hours (estimated), single continuous session
- **Dependencies**: 982 (unify_orchestrator_handoff_contract) — already completed
- **Artifacts**: plans/01_routing-consolidation-plan.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Collapsed six independent routing implementations (the canonical `command-route-skill.sh` plus
five duplicates/divergences: inline copies in `research.md`/`plan.md`, two divergent agent
routers in `skill-orchestrate`/`skill-orchestrate-hard`, and the vestigial `skill-orchestrator`)
onto one shared library, `scripts/lib/manifest-routing-lib.sh`, consumed by two thin resolvers
(`command-route-skill.sh`, refactored; `command-route-agent.sh`, new). Added explicit
`routing_agents`/`routing_agents_hard` manifest declarations (ground-truthed against each
routed skill's own `subagent_type` dispatch line, never derived by string surgery) across all 17
routing-declaring manifests, fixed `implement.md`'s missing `effort_flag` argument (the "6th
defect" discovered during research), switched core-manifest identification from
`routing_exempt: true` to `.name == "core"`, retired `skill-orchestrator`, and added a
wiring-validation lint (`lint-routing-wiring.sh`, wired as `verify-deploy.sh` gate7) plus a
table-driven, mechanically-built parity test (`test-routing-resolution.sh`, 18 assertions). All
8 planned phases completed; zero deviations from Non-Goals; the Phase 1 pre/post baseline diff
(280 rows across 140 `(op, task_type)` pairs × 2 efforts) confirmed byte-for-byte zero behavior
change in `command-route-skill.sh`'s resolution.

## What Changed

- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — new shared library: the
  one five-step first-match-wins ladder (`routing_lookup`), core identification by `.name`
  (`routing_core_manifest`), directory-resolution-via-routing-keys
  (`routing_manifest_for_task_type`), and stderr tracing (`routing_trace`). Exposes a
  `ROUTE_MANIFEST_ROOT` override (default unchanged: `.claude`) so the SAME ladder validates the
  source store pre-deploy (used by the lint and test) without any behavior change for live
  callers.
- `agent-system/extensions/core/scripts/command-route-skill.sh` — refactored onto the library;
  core identification via `.name == "core"`; emits `[route] ...` stderr trace; Step 4e `-hard`
  append fallback preserved verbatim.
- `agent-system/extensions/core/scripts/command-route-agent.sh` — new resolver for
  `/orchestrate`'s agent-level dispatch, same ladder against `routing_agents`/
  `routing_agents_hard`; a hard-mode miss falls through to the caller's own hard default, never
  to the standard block.
- `agent-system/extensions/core/commands/{implement,research,plan}.md` — one call shape: all
  three now `source .claude/scripts/command-route-skill.sh` with the 4th `effort_flag` argument
  (`implement.md`'s was missing it entirely — `/implement N --hard` never reached
  `skill-implementer-hard` before this task); `research.md`/`plan.md`'s inline manifest loops
  deleted, with STAGE 1.5's prose-parsed `effort_flag` materialized as a shell variable
  immediately before the `source` call (empty string, never the literal `null`).
- `agent-system/extensions/*/manifest.json` (17 manifests: core + 16 non-core) — new
  `routing_agents`/`routing_agents_hard` blocks, one entry per existing `routing`/`routing_hard`
  key, ground-truthed against each skill's `subagent_type` line (grepped, not guessed) —
  including the three known-broken derivation cases (`email`→`general-research-agent`,
  `filetypes`→`filetypes-router-agent` not the derived `filetypes-agent`,
  `memory`→`general-*-agent`) and the compound multi-stage `present:slides`/`present:grant`
  skills (representative primary agent per op).
- `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md` — Stage 1b replaced
  with three `command-route-agent.sh` calls (research/plan/implement); deleted the case table,
  directory probe, sed derivation, and (hard engine) the no-`break` last-match-wins loop. The two
  engines now differ only in the effort argument and their three defaults.
- `agent-system/extensions/core/skills/skill-orchestrator/` — deleted (both `SKILL.md` and the
  byte-identical `.archived` twin); dropped from the core manifest's `provides.skills`.
- `agent-system/extensions/epidemiology/commands/epi.md` — dispatch rewritten to resolve via
  `command-route-skill.sh`, mirroring `implement.md`'s shape rather than a third mechanism.
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` — new lint: Check A (every
  `routing.{op}` key has a `routing_agents.{op}` counterpart), Check B (every declared agent
  exists on disk), Check C (same for `routing_hard`/`routing_agents_hard`), Check D (report-only:
  visible list of deliberate `general-*` routings).
- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate7 wired (mirrors gate6's
  structure exactly); header gate-range prose corrected from a stale "gate0-gate5" to the actual
  "gate0-gate7".
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` — new table-driven
  test: matrix built mechanically from all manifests (140 standard + 17 hard pairs), 4 assertions
  (skill resolution, agent existence, engine parity, precedence direction via a synthetic
  core/non-core conflict fixture), 18 total checks, all with confirmed negative controls.
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — new guide
  documenting the full consolidated model.
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — removed the "First-Match
  vs Last-Match Precedence" divergence section (the divergence itself is now eliminated);
  corrected `routing_exempt` references; corrected the now-obsolete "Orchestrate-Hard: Separate
  Reader" section to describe the actual shared-resolver behavior.
- `agent-system/extensions/core/merge-sources/claudemd.md` — "Routing Mechanism" section updated
  (core identification, mentions the shared library); "Utility Scripts" gained
  `lint-routing-wiring.sh`.
- `agent-system/extensions/core/index-entries.json` — registered the new guide; corrected
  `hard-mode-routing.md`'s stale `line_count`.
- `agent-system/extensions/core/docs/guides/{copy-claude-directory,adding-domains}.md` — all five
  `skill-orchestrator` instructions replaced with manifest-declaration instructions and
  cross-references to the new schema guide.
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` — historical audit
  row annotated as referring to a since-retired skill (record preserved, not deleted).

## Decisions

- Applied the SAME 5-step ladder (non-core-then-core) uniformly to the standard `routing` block,
  not just `routing_hard` (which was the only block that had precedence rules before this task).
  Verified behavior-preserving because no manifest carrying `.name == "core"` has ever declared a
  non-empty `.routing` block — confirmed empirically, and by the Phase 1 zero-diff baseline.
- Added a `ROUTE_MANIFEST_ROOT` environment override to the shared library (default unchanged:
  `.claude`) rather than duplicating the ladder for lint/test purposes — this is what "source the
  Phase 1 library rather than re-deriving the ladder" required in practice, since the library as
  first written hardcoded the deployed-tree path and the lint/test must validate the source store
  pre-deploy.
- `present`'s non-standard `critique` op (`routing.critique.present:slides`) was included in
  `routing_agents` for completeness, even though the plan's own block-shape example only lists
  research/plan/implement — the plan's own zero-gaps verification criterion is not scoped to
  those three ops, and Phase 5's lint enforces the same generic completeness.
- `skill-orchestrate`'s single-task plan-dispatch call site and its Skill-to-Agent Mapping summary
  table were also updated to use `$PLANNER_AGENT` (Stage 1b now resolves it) — leaving the actual
  dispatch site hardcoded to the literal `"planner-agent"` would have made the new plan-op
  resolution capability dead code.

## Plan Deviations

- **Phase 3**: included `routing_agents.critique` for `present` (not just research/plan/implement)
  — see Decisions above.
- **Phase 4**: also wired `skill-orchestrate`'s single-task plan-dispatch site (not just Stage 1b)
  to `$PLANNER_AGENT` — see Decisions above. Stage MT-2/MT-3 (multi-task batch mode) were
  confirmed out of scope via the plan's own grep-based Scope Hypothesis and left untouched.
- **Phase 5**: added the `ROUTE_MANIFEST_ROOT` override to `manifest-routing-lib.sh` — see
  Decisions above. Default-unset behavior verified byte-identical via a full baseline replay.
- **Phase 6**: Assert 1's manifest-mutation negative control is a documented no-op by design (the
  expected value is read from the same manifest data the resolver reads); the meaningful negative
  control (corrupting the resolver script itself) was verified manually and documented inline.
- **Phase 7**: the `git-commit-scoped.sh` wrapper cannot stage a pure file deletion (its
  pathspec-existence precondition fails when the path no longer exists on disk, even though git
  itself tracks the staged deletion correctly) — this is an existing limitation of that shared
  script, out of this task's scope to fix. Worked around by committing the already-correctly
  `git rm`-staged deletion directly for that one narrow case only.
- **Phase 8**: also corrected `hard-mode-routing.md`'s now-false "Orchestrate-Hard: Separate
  Reader" section (beyond the named divergence-section removal) — see Decisions above.
  `generate-context-line-counts.sh --check` and `check-extension-docs.sh` both refuse to run
  from the source store by design (they require a deployed tree); verified their targets
  manually instead (`wc -l` cross-check, direct grep), consistent with the plan's own Non-Goal
  against running a deploy as part of phase-level verification.

## Verification

- Build: N/A (shell/markdown/JSON only)
- Tests:
  - `bash -n` clean on all 6 new/modified shell scripts.
  - `lint-agent-contracts.sh --verbose`: 33 passed, 0 warnings, 0 failed (unchanged by this task).
  - `lint-routing-wiring.sh --verbose`: 323 passed, 0 failed, 8 general-* declarations reported
    for visibility (Check D). Negative controls confirmed for Check A and Check B (induced FAIL,
    reverted).
  - `test-routing-resolution.sh`: 18/18 assertions passed. Negative controls confirmed for all
    four assertions (induced failure via resolver/SKILL.md/library mutation, each reverted).
  - `test-deploy-propagation.sh`: 4/4 passed, including "declared-vs-deployed parity (212
    entries checked, 0 missing)" — confirms every newly-registered `provides.scripts` entry
    (the new lib, both new scripts, the new lint, the new test) reaches both a fresh and a
    resync deploy.
  - Full `verify-deploy.sh --findings` run: `FAILURES=2` of 18 checks, both attributable to
    expected pre-deploy drift on gate3/gate5 (the `.claude/` tree here has not been redeployed
    from this task's source-store changes — deploy is the user's action, an explicit plan
    Non-Goal). Gate6 and gate7 both passed.
  - Phase 1 baseline diff: zero differences across 280 rows (140 pairs × 2 efforts).
- Files verified: yes — every created/modified file read back or independently jq/bash-validated.

## Impacts

- `/research N --hard` and `/plan N --hard` now actually resolve `-hard` skills via manifest
  `routing_hard` (previously silently ignored `--hard` entirely).
- `/implement N --hard` now resolves `-hard` skills too (the undocumented 6th defect this task's
  research surfaced).
- `/orchestrate` (both engines) now resolves agents identically, including for task types the old
  code silently mis-routed (`epi` → previously fell through to `general-*-agent`; `email`,
  `memory`, `filetypes` → previously would have derived non-existent agent names via sed).
- Any future extension author adding `routing`/`routing_agents` entries gets a mechanical FAIL
  (lint-routing-wiring.sh, wired into `verify-deploy.sh` gate7) if a declared agent doesn't exist
  or a `routing` key lacks a `routing_agents` counterpart — the defect class this task fixes
  cannot silently recur.

## Follow-ups

- A full end-to-end `verify-deploy.sh` PASS (all 8 gates, zero drift) requires a deploy
  (`<leader>al` / `deploy-headless.sh`), which is the user's action per this task's own
  Non-Goals — not performed as part of this implementation.
- `check-extension-docs.sh` and `generate-context-line-counts.sh --check` likewise require a
  deployed tree to run; their targets were verified manually instead (see Plan Deviations,
  Phase 8) but a post-deploy re-run of both would give the fully mechanical confirmation.
- specs/TODO.md and specs/state.json were left untouched by this dispatch (pre-existing dirty
  state from task creation/planning, outside this implementer's scope); task-status transition to
  `[PR READY]`/`[COMPLETED]` is the team lead's/orchestrator's next step.

## References

- Plan: `specs/981_consolidate_routing_to_single_router/plans/01_routing-consolidation-plan.md`
- Research: `specs/981_consolidate_routing_to_single_router/reports/01_routing-consolidation-research.md`
- New guide: `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
