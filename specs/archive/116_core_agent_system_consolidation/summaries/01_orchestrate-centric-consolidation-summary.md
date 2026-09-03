# Implementation Summary: Task #116

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Status**: [COMPLETED]
- **Started**: 2026-08-31
- **Completed**: 2026-08-31
- **Effort**: ~15 hours (per plan estimate; single dispatch, all 10 phases)
- **Dependencies**: None
- **Artifacts**: plans/01_orchestrate-centric-consolidation.md, reports/02_baseline-and-audit-evidence.md, reports/03_target-state-design.md, reports/04_backlog-audit-verdicts.md, reports/05_backlog-operation-manifest.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

This meta-task designed the target state for an orchestrate-centric core agent system (Phase A,
A1-A7) and rebuilt the backlog around that design (Phase B audit, Phase C operations). All writes
were confined to `specs/**`; no file under `agent-system/extensions/**` or `.claude/**` was
touched, verified at every phase boundary and again at closeout.

## What Changed

- `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md` — Created.
  Re-measured the core extension inventory, re-verified all five research findings (dispatch-bypass
  gap, `skill-orchestrate-hard` unreachability, artifact-numbering asymmetry, manifest routing_hard
  footprint), and built the 33-row audit-scope roster (32 topic-matched + task 100, admitted from
  `topic: null`).
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` — Created. The
  full Phase A design spec: A1 (delete `/research`/`/plan`/`/implement`, keep `/revise`, rehome
  memory/`--lit` first), A2 (phase-forcing flags, append-not-replace, monotonic status), A3
  (routing collapses to `routing_agents`-only), A4 (hard mode becomes contract injection +
  conditional state-machine logic, reusing the *already-existing* `context/contracts/*.md` store),
  A5 (team mode folds to a shared fan-out stage), A6 (preserved-vs-rebuild table for 12
  mechanisms), A7 (deletion ledger with honest before/after accounting), completeness gate PASS.
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` — Created.
  Verdicts for all 33 roster tasks (18 design-coupled + 15 remainder), two confirmed BLOCKING
  tasks (#68, #81), one confirmed NOT-BLOCKING softer candidate (#53), coverage 33/33.
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` — Created.
  Three sequencing tensions resolved with a stated direction each; 11 successor tasks specified,
  created, and numbered (117-127); full operation manifest (CREATE/REVISE/ABANDON/RETOPIC/
  BACKFILL/DEPEND); Phase 10 closeout with VERIFICATION BAR evidence for all 5 items.
- `specs/state.json` — 11 successor tasks created (117-127, `topic: core-agent-system`); #45
  revised + re-topiced to `neovim` + backfilled (topic anomaly: real scope is nvim Lua UI code,
  not the agent system); #46 revised (routing-half moot, `routing_agents`-half survives) +
  backfilled; #51 backfilled; #72/#73 revised (retarget to the new team fan-out stage) + dependency
  added; #64 abandoned (absorbed into #118); #115 abandoned (superseded, cites the A7 ledger);
  #100 re-topiced to `core-agent-system`; #48/#90/#88 gained new dependency edges.
- `specs/TODO.md` — Regenerated via `generate-task-order.sh --update-todo`; 57 non-abandoned
  active tasks placed across 13 acyclic dependency waves; Core Agent System section reflects all
  11 new successor tasks with correct nesting and correctly excludes both abandoned tasks.

## Decisions

- `/orchestrate` becomes the sole lifecycle entry point; `/revise` survives as a distinct command
  (no phase-flag equivalent exists for its plan-revision-with-reason and description-update-fallback
  behaviors).
- The rehome of memory retrieval and `--lit` resolution into a new `skill-orchestrate` dispatch-prep
  stage is a hard precondition that must land before any command or lifecycle-skill deletion —
  encoded as a real dependency edge (task 124 depends on task 117).
- The premise that "no shared contract-text mechanism exists" for hard-mode contracts was found
  false during Phase 3's verification: `context/contracts/*.md` already exists and is already
  referenced by path from every `-hard` consumer. The real migration surface is consumer-count
  reduction (7 reference sites -> 1) plus genuinely stateful residue (~1,590 of 4,232 `-hard`-file
  lines) that becomes conditional engine logic, not new contract-text authoring.
- Several mechanisms the task description assumed were merely "not currently used by `/orchestrate`"
  (`--fast`, `--team`, `--hard`, all four model flags) were verified to be **entirely absent** from
  `/orchestrate`'s own Options table today — corrected in A6 from an implied migration to an
  explicit REBUILD-REQUIRED classification for six of twelve preserved-asset rows.
- Task #115 was refined from Phase 5's "partially moot" into a firm Phase 7 ABANDON: once the
  hard-mode collapse and #114 land, nothing is left to mirror model-flag support into.

## Plan Deviations

- Phase 1: the six audit-scope topics named in the task description had already collapsed to
  `core-agent-system`/`extensions` in live `state.json` (unrelated prior housekeeping); reconciled
  explicitly rather than silently, with the roster arithmetic still landing at 32 (+ task 100).
- Phase 3: corrected the task description's premise about the hard-mode contract-text mechanism
  (see Decisions above) rather than building a duplicate mechanism per the original framing.
- Phase 4: corrected A6's scope — six mechanisms, not two, needed REBUILD-REQUIRED classification.
- Phase 5: task #89 was reassigned from the design-coupled cluster to the remainder cluster (it
  does not touch the orchestrate engine's own multi-task section, only literature/distill skills).
- Phase 7: refined #115 from "partially moot" to a firm ABANDON.
- Phase 10: corrected an inaccurate Phase 5 claim about `--lit`-through-team-skills — task #94
  exists but is out of audit-scope authority (literature topic), not nonexistent.

## Verification

- Build: N/A (documentation + backlog-state task)
- Tests: N/A
- `jq empty specs/state.json`: Success, checked after every write.
- `.active_projects` count: 59 throughout Phase 9-10 (48 pre-existing + 11 created; abandonment
  applied in place, no removal).
- `generate-task-order.sh`: Success, 57/57 non-abandoned tasks placed across 13 acyclic waves.
- `git status --porcelain` / per-commit `git show --name-only` on all 9 phase commits: confirmed
  scoped exclusively to `specs/**`.
- Files verified: Yes (all 5 artifacts + state.json changes read back and confirmed non-truncated).

## Impacts

- Establishes a concrete, citable specification (report 03) that the 11 newly-created successor
  tasks (117-127) implement without re-deriving any A1-A7 decision.
- Reduces near-term backlog churn risk: #48/#90 (call-site-counting) and #88 (mode-gating) now
  carry explicit sequencing dependencies preventing wasted work against soon-to-be-deleted files.
- Surfaces two live correctness defects (#68, #81) as BLOCKING the collapse, ensuring they land
  before `/orchestrate` becomes the sole entry point rather than being silently entrenched.

## Follow-ups

- Task #94 (`--lit` through team skills, literature topic) should be re-evaluated by a
  literature-topic-authorized process once task 122 lands — likely MOOT at that point, per this
  report's analysis, but that determination is outside this task's authority.
- The successor tasks' own descriptions (117-127) reference `reports/03_target-state-design.md`
  for full reasoning; a future `/plan` or `/research` dispatch on any of them should read that
  report rather than re-deriving its decisions.

## References

- `specs/116_core_agent_system_consolidation/plans/01_orchestrate-centric-consolidation.md`
- `specs/116_core_agent_system_consolidation/reports/01_orchestrate-centric-consolidation-design-inputs.md`
- `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md`
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md`
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md`
