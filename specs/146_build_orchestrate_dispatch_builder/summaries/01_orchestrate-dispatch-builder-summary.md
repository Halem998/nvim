# Implementation Summary: Task #146

- **Task**: 146 - Build orchestrate-build-dispatch.sh: per-dispatch context files, pointer prompts, and the user-decision contract
- **Status**: [COMPLETED]
- **Started**: 2026-09-02T20:34:57Z
- **Completed**: 2026-09-03T02:15:00Z
- **Effort**: ~9 hours (agent-executed, single continuous session)
- **Dependencies**: 145 (completed)
- **Artifacts**: plans/01_orchestrate-dispatch-builder.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `orchestrate-build-dispatch.sh`, the sole implementation of `/orchestrate`'s Stage 3.5
Dispatch Prep plus every additional per-dispatch input the inline recipes used to interpolate
(task description, artifact round, phase-specific report/plan paths, the normalized continuation
pointer, handoff path, dispatch sequence, territory, and a user-decision contract reference).
Migrated all 11 physical `Run **Stage 3.5**` call sites in `skill-orchestrate/SKILL.md` (8
single-task + 3 MT-4 loops) to a single script call plus a fixed one-sentence pointer prompt,
deleted the Stage 3.5 prose section in favor of a pointer to the script, wrote the user-decision
contract once in `context/standards/`, extracted a shared continuation-pointer helper closing a
previously hand-copied drift risk, registered `.dispatch/` across every runtime-file surface with
cleanup wiring at loop termination, and swept every agent `skill-orchestrate` can dispatch through
a Stage-3.5-backed site (62 agents) with a short "Dispatch File" pointer section.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new script; CLI:
  `<task_number> <phase> --session SID --seq N [--clean] [--lit] [--hard] [--fast] [--model M]
  [--focus "..."] [--territory "..."] [--dispatch-start-ts TS]`; writes
  `specs/{NNN}_{slug}/.dispatch/{seq}.md` and prints `{"dispatch_file": "...", "model": "..."}`.
- `agent-system/extensions/core/scripts/lib/continuation-pointer-lib.sh` — new shared library;
  `resolve_continuation_pointer()` normalizes both accepted continuation-pointer forms (nested
  `continuation_context.handoff_path`, flat `continuation_path`) to one shape or `null`, used by
  both the new script and `orchestrate-triage-classify.sh`'s `continuation_ok` predicate.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — `continuation_ok`
  switched onto the shared helper, collapsing what were two independently hand-copied jq
  implementations into one.
- `agent-system/extensions/core/context/standards/user-decision-contract.md` — new file; the
  single home of the user-decision contract (when to raise one, blocking vs. non-blocking, field
  shape, producer ownership, distinction from `decisions_made`).
- `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new `user_decision
  (optional)` subsections, referencing (not restating) the contract file.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`,
  `.gitignore`, `agent-system/extensions/core/context/standards/git-staging-scope.md` (2 array
  literals), `agent-system/extensions/core/scripts/git-commit-scoped.sh` (1 array literal),
  `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — `.dispatch/` registered
  as an ephemeral, directory-class runtime file across every surface.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — all 11 physical `Run
  **Stage 3.5**` sites replaced with a script call + fixed pointer prompt; the Stage 3.5 prose
  section deleted in favor of a pointer; `.dispatch/` cleanup added at all 3 single-task
  loop-termination sites plus a new per-task Stage MT-5 cleanup step; byte size 277,015 →
  270,380 (-6,635 bytes) despite the added bash blocks, because the deleted Stage 3.5 prose was
  larger than what replaced it.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new 49-case
  parity/negative/anti-drift/headless test suite.
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`,
  `test-deploy-propagation.sh`, `test-orchestrate-triage-classify.sh` — fixed hand-copied fixture
  lists/dependency copies that this task's own new files (`.dispatch/`,
  `continuation-pointer-lib.sh`) would otherwise have silently gone stale against.
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` — Check A repointed
  from `SKILL.md` (which no longer contains the `core_contracts` case statement) to
  `orchestrate-build-dispatch.sh`, with a precise anchor distinguishing it from the script's other
  two `case "$phase" in` statements.
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  — new scripts/tests/lib registered for deployment; new/changed context-doc line counts synced.
- 62 agent contract files across `core`, `cslib`, `email`, `epidemiology`, `filetypes`, `formal`,
  `founder`, `latex`, `lean`, `nix`, `nvim`, `present`, `python`, `typst`, `web`, `z3` — each
  gained a short **Dispatch File** section pointing at the per-dispatch context file and the
  user-decision contract.

## Decisions

- Phases 3 and 4 (Stage 3.5 replication and the per-dispatch gatherers/file writer) were
  implemented as one script-authoring pass since both target the same new file, then verified
  separately against each phase's own criteria.
- Used `skill-base.sh`'s existing `skill_validate_input` instead of a fresh jq query for
  description/task_type/task_dir resolution — same effect, avoids a second implementation.
- The hard-mode per-phase (H1) dispatch site's `phase_mission_block` (the "Implement phase N
  only" / "PHASES COMPLETED: n of m" mission text) was kept authored inline at that one site and
  appended to the fixed pointer prompt, rather than folded into the script's gatherers — it is
  genuinely per-cycle content (next_phase, phases_completed, phases_total) the script was never
  scoped to gather, and dropping it silently would have violated the plan's own MUST NOT
  ("a generated dispatch file must carry every input the current inline recipe would have
  interpolated").
- The agent-contract sweep resolved dispatchable agents via `manifest-routing-lib.sh`'s own
  functions with `ROUTE_MANIFEST_ROOT=agent-system` (the documented validation-only mode),
  walking the SOURCE STORE's manifests rather than this repo's own narrower deployed extension
  set (core/email/literature/memory/nix/nvim) — the correct mode for a sweep whose target is
  source-store agent files, not this one repo's live routing.
- `.dispatch/` cleanup mirrors the singleton runtime files' lifecycle: swept only at genuine
  full-loop-termination / per-task completion, never on a `[PARTIAL]`/failed exit, matching
  `orchestrator-runtime-files.md`'s existing disposition for the loop guard and churn state.

## Plan Deviations

- **Task 4.1** altered: used `skill_validate_input` instead of a fresh jq query for
  description/task_type (equivalent effect, DRYer — see Decisions).
- **Task 6.3 (Phase 6, hard branch prompt)** altered: kept `phase_mission_block` appended to the
  fixed pointer prompt at the one hard-mode per-phase dispatch site, rather than stripping all
  non-pointer content from every site without exception — see Decisions for the MUST NOT
  rationale.
- **Task 9.1 (Phase 9, MT-5 per-task cleanup)** altered: the plan's Scope Hypothesis assumed an
  existing MT-5 per-task cleanup equivalent to co-locate with; live inspection found none exists
  (Stage MT-5 only ever cleaned up the shared `mt_state_file`/session registry). Added a new
  per-task cleanup step (Stage MT-5 step 7), gated on `completed_tasks` only.
- **Not a plan deviation, but a discovered-and-fixed adjacent defect**: `lint-contract-compliance.sh`'s
  Check A hard-coded an assumption that `SKILL.md` still contains the `core_contracts` case
  statement Phase 3 moved into the new script; fixed as part of this task's own full-gate-run
  obligation (Phase 9) rather than left for a future task, since it was a direct, mechanical
  consequence of this task's own migration.

## Verification

- Build: N/A (shell scripts + markdown; no compiled build step)
- Tests: `test-orchestrate-build-dispatch.sh` 49/49 passing (bite-check confirmed); full
  `bash .claude/scripts/tests/run-all.sh` 62/62 on the deployed tree across every phase-boundary
  re-run in this session; one FAIL (a pre-existing timing-flaky test, `test-four-tier-conflict.sh`
  case 6) observed on a single later full-repo re-run under this session's own heavy background
  load — see Follow-ups.
- Files verified: Yes — every phase's verification tier (`full`/`interface`) ran the commands its
  plan section specified before the phase was marked `[COMPLETED]`.
- Acceptance numbers (full detail in `progress/phase-9-progress.json`):
  - Prompt-byte reduction: 95.5% on a real 3-task hard-mode-composite measurement (16,122 B →
    719 B); 94.9% on a plain base-mode measurement of the same 3 tasks. Both comfortably above
    the ≥90% target.
  - Dispatch-file parity: PASS, 49 assertions, all Stage 3.5 + per-dispatch inputs enumerated
    explicitly (not spot-checked).
  - Agent-contract sweep: 62 agents edited; explicit negatives named (literature/slidev's absent
    `routing_agents` blocks, memory's already-core-covered routing, the four auxiliary-only
    agents, four sub-agents never a routing target, and two non-agent context-doc files a naive
    glob would have miscounted).
  - `user_decision` end-to-end: simulated (no live Agent-tool dispatch available to this
    implementer) — a sample `.return-meta.json` with `user_decision` set survives a simulated
    later-writer read-modify-write byte-identical, and both states pass `validate-return-meta.sh`.

## Impacts

- Every future `/orchestrate` dispatch (single-task and multi-task alike) now authors a ~240-byte
  pointer prompt instead of an inline description/memory/literature/hard-contracts blob, directly
  addressing the context-exhaustion defect the task description measured (a 5-task wave
  previously costing the lead 25-60 KB of self-authored, context-retained prompt text per cycle).
- The `user_decision` contract gives agents a narrow, structured channel to request the user's
  judgment without the orchestrator ever guessing or asking on its own — wired into both schema
  docs and referenced from the dispatch file and all 62 swept agent contracts.
- `.dispatch/` is now a fully registered, cleaned-up ephemeral runtime-file class; no risk of it
  leaking into git history via any of the four registration surfaces this task updated.
- Closes a real, previously-flagged drift risk: the continuation-pointer dual-form resolution now
  has exactly one implementation, not two independently hand-copied ones.

## Follow-ups

- `orchestrate-cycle-plan.sh` (Stage A.3 of `specs/PATH.md`'s thin-lead path) is a separate,
  later task that will call this task's script from a batch planner; out of scope here by design.
- Four pre-existing, unrelated `verify-deploy.sh` gate failures were found and left as-is (not
  this task's file scope): (1) 3 stale `index-entries.json` line-count declarations
  (`patterns/postflight-control.md`, `schemas/state-schema.json`,
  `project/literature/patterns/zotero-item-creation.md`), predating this task by several
  unrelated commits; (2) a timing-flaky `test-four-tier-conflict.sh` budget-bound case, explicitly
  documented in prior git history as a known flake, untouched by this task's diff; (3)
  `validate-state.sh --deep` schema drift (`abandon_reason`, `blocks_note` unknown fields) on
  unrelated task entries dating to commits before this task; (4) 4 hand-rolled `state.json`
  writes in `test-force-phases.sh`, a file this task never touched. None of the four is a
  regression introduced by this task (confirmed via `git diff` against each file); a future
  `/errors` or dedicated cleanup pass should address them.
- The `user_decision` end-to-end demonstration was simulated rather than run through a live
  `/orchestrate` cycle with a real dispatched agent, since this implementer has no Agent-tool
  access of its own. A future live `/orchestrate --lit` or plain research dispatch that
  deliberately exercises a genuine ambiguous choice would be a stronger real-world confirmation,
  though the mechanical round-trip (write → validate → merge → validate → byte-compare) already
  proves the schema and producer-ownership contract hold.

## References

- Plan: `specs/146_build_orchestrate_dispatch_builder/plans/01_orchestrate-dispatch-builder.md`
- Report: `specs/146_build_orchestrate_dispatch_builder/reports/01_orchestrate-build-dispatch.md`
- Progress files: `specs/146_build_orchestrate_dispatch_builder/progress/phase-{1..9}-progress.json`
- Handoff checkpoint: `specs/146_build_orchestrate_dispatch_builder/handoffs/phase-5-handoff-20260902T230500Z.md`
- `specs/PATH.md`, "Target design: the thin lead" (governing sequencing document; this task is
  Stage A.2)
