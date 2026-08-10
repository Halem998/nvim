# Implementation Plan: Task #764

- **Task**: 764 - Harden implementation agent plan marker enforcement
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/764_harden_plan_marker_enforcement/reports/01_plan-marker-research.md
- **Artifacts**: plans/01_plan-marker-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan hardens the implementation agent's plan marker update mechanism from soft behavioral instructions to a computationally enforced contract. The root cause of stale markers is that Stage 4A/4D use Edit tool directly (with no verification of success), and there is no post-implementation checkpoint that reads the plan file to confirm all phases are marked [COMPLETED]. The fix adds a mandatory Stage 5a verification-and-repair step, replaces direct Edit calls with `update-phase-status.sh`, extends `validate-artifact.sh` with completion checking, and documents the contract in the handoff schema.

### Research Integration

Key findings from `reports/01_plan-marker-research.md`:
- Phase marker updates (Stage 4A/4D) are behavioral instructions using the Edit tool directly, with no verification that the Edit succeeded or that the agent followed the instruction.
- The `update-phase-status.sh` script exists with idempotency, error reporting, and logging to `phase-transitions.log`, but agents do not use it.
- `validate-artifact.sh` checks plan structure but not marker completeness post-implementation.
- The orchestrator handoff schema has no field for plan marker verification status.
- The top-level `**Status**` field is updated by the skill layer (`update-plan-status.sh`), not the agent. Both layers need enforcement.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances "Agent System Quality" in Phase 1 of ROADMAP.md. Strengthening implementation agent contracts directly improves system reliability, though no specific roadmap item names this task.

## Goals & Non-Goals

**Goals**:
- Add Stage 5a (Verify and Repair Plan Markers) as a hard contract in `general-implementation-agent.md`
- Replace direct Edit tool calls in Stage 4A/4D with `update-phase-status.sh` script calls
- Strengthen the Critical Requirements section with explicit hard-contract language
- Extend `validate-artifact.sh` with a `--verify-completion` flag for plan marker completeness checking
- Add `plan_markers_verified` field to the orchestrator handoff schema documentation

**Non-Goals**:
- Modifying extension-specific implementation agents (neovim, nix, lean4) -- they can adopt the pattern later
- Changing the skill-orchestrate state machine loop or its context flatness constraints
- Auditing the `update-task-status.sh` -> `update-plan-status.sh` postflight chain (separate concern)
- Creating automated tests for the marker verification (manual verification is sufficient for meta tasks)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stage 5a adds context usage for agents near exhaustion | M | L | Verification is a single grep + conditional repair; ~3-5 tool calls max |
| update-phase-status.sh has edge cases not covered by research | L | L | Script already has idempotency checks; test with existing plan files |
| Hard-contract language may cause agents to loop on unfixable marker states | M | L | Stage 5a includes a final-read confirmation with fallback to logging a warning |
| Handoff schema change may not be picked up by existing orchestrator logic | L | M | The field is optional/advisory; orchestrator logs a warning if absent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update general-implementation-agent.md [COMPLETED]

**Goal**: Replace soft marker instructions with hard contracts and add Stage 5a verification.

**Tasks**:
- [x] Replace Stage 4A (Mark Phase In Progress) Edit tool instructions with `update-phase-status.sh` call. Change the text from "Use the Edit tool with:" to a bash call pattern: `bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" IN_PROGRESS` *(completed)*
- [x] Replace Stage 4D (Mark Phase Complete) Edit tool instructions with `update-phase-status.sh` call. Change the text from "Use the Edit tool with:" to a bash call pattern: `bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED` *(completed)*
- [x] Insert Stage 5a: Verify and Repair Plan Markers between Stage 5 (Run Final Verification) and Stage 6 (Create Implementation Summary). The stage must include: (a) fresh Read of plan file, (b) grep-based counting of `[NOT STARTED]` and `[IN PROGRESS]` phase headings, (c) repair loop calling `update-phase-status.sh` for each stale heading, (d) top-level Status verification via `update-plan-status.sh`, (e) final confirmation read *(completed)*
- [x] Update the Critical Requirements section: change MUST NOT item 2 ("Leave plan file with stale status markers") to a HARD CONTRACT block with zero-tolerance language referencing Stage 5a as the mandatory enforcement step *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` -- Replace 4A/4D Edit instructions, insert Stage 5a, update Critical Requirements

**Verification**:
- Stage 4A references `update-phase-status.sh` instead of Edit tool
- Stage 4D references `update-phase-status.sh` instead of Edit tool
- Stage 5a section exists between Stage 5 and Stage 6
- Stage 5a contains grep patterns, repair loop, and final confirmation
- Critical Requirements contains HARD CONTRACT block
- No remaining "Use the Edit tool with:" text in 4A/4D marker-related sections

---

### Phase 2: Extend validate-artifact.sh [COMPLETED]

**Goal**: Add `--verify-completion` flag that checks phase marker completeness for plan artifacts.

**Tasks**:
- [x] Add `--verify-completion` to the argument parsing loop (alongside `--fix` and `--strict`) *(completed)*
- [x] Add plan-specific completion verification block: when `verify_completion=true` and `artifact_type=plan`, count `[NOT STARTED]` and `[IN PROGRESS]` phase headings and call `log_error` if any remain *(completed)*
- [x] Add top-level Status field verification: check that `- **Status**:` contains `[COMPLETED]` when `--verify-completion` is active, and call `log_error` if not *(completed)*
- [x] Update the exit code summary comment at the top of the script to document the new flag *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/validate-artifact.sh` -- Add `--verify-completion` flag with plan completion checks

**Verification**:
- `bash .claude/scripts/validate-artifact.sh /dev/null plan --verify-completion` parses without error (file-not-found is expected; flag parsing should succeed)
- The `--verify-completion` flag is documented in the usage comment
- Completion checks only run when both `--verify-completion` is true AND type is `plan`

---

### Phase 3: Update orchestrator handoff schema documentation [COMPLETED]

**Goal**: Document the `plan_markers_verified` field in the handoff schema so skills can include it and the orchestrator can log warnings when absent.

**Tasks**:
- [x] Add `plan_markers_verified` field (type: boolean, optional) to the Complete JSON Schema section in `handoff-schema.md` *(completed)*
- [x] Add a Field Definition entry for `plan_markers_verified` explaining: set to `true` when Stage 5a verification passes, optional field, orchestrator logs warning if absent or false after implement dispatch *(completed)*
- [x] Add `plan_markers_verified` to the Successful Implementation example object *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/docs/architecture/handoff-schema.md` -- Add field definition, schema entry, and example

**Verification**:
- `plan_markers_verified` appears in the JSON schema block
- Field Definitions section includes a `plan_markers_verified` entry
- Successful Implementation example includes `"plan_markers_verified": true`

---

### Phase 4: Integration verification and hard-mode agent sync [COMPLETED]

**Goal**: Verify the changes work together and propagate the Stage 5a contract to the hard-mode implementation agent.

**Tasks**:
- [x] Read `general-implementation-hard-agent.md` and check whether it inherits from or duplicates the standard agent's stage definitions. If it duplicates Stage 4A/4D/5, apply the same `update-phase-status.sh` and Stage 5a changes *(completed: agent duplicates 4A/4D with brief text — updated both to use script; added Stage 5a with single-phase dispatch caveat)*
- [x] Run `validate-artifact.sh` against an existing completed plan file (e.g., `specs/762_add_literature_briefing_injection_to_cslib_agents/plans/01_lit-injection-agents-plan.md`) with `--verify-completion` to confirm the flag works correctly on a real artifact *(completed: [PASS] All phase headings verified [COMPLETED])*
- [x] Verify `update-phase-status.sh` can be called with the argument pattern specified in the updated agent spec by running it against a test plan (dry inspection of the script's argument handling) *(completed: idempotent call to task 764 phase 1 returned exit 0)*
- [x] Review the complete set of changes for internal consistency: Stage 4A/4D reference the script, Stage 5a calls the script for repair, validate-artifact.sh checks the same markers, handoff schema documents the new field *(completed: all grep counts verified)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/agents/general-implementation-hard-agent.md` -- Sync Stage 5a and 4A/4D changes if needed

**Verification**:
- `validate-artifact.sh --verify-completion` runs without errors on a real plan file
- Hard-mode agent has Stage 5a or inherits it consistently
- No contradictions between agent spec, script arguments, and schema documentation

## Testing & Validation

- [ ] Grep `general-implementation-agent.md` for "Use the Edit tool" in Stage 4A/4D context -- should return zero matches
- [ ] Grep `general-implementation-agent.md` for "update-phase-status.sh" -- should match in 4A, 4D, and 5a
- [ ] Grep `general-implementation-agent.md` for "HARD CONTRACT" -- should match in Critical Requirements
- [ ] Run `bash .claude/scripts/validate-artifact.sh specs/762_add_literature_briefing_injection_to_cslib_agents/plans/01_lit-injection-agents-plan.md plan --verify-completion` and verify it produces output (pass or error, not a crash)
- [ ] Grep `handoff-schema.md` for "plan_markers_verified" -- should match in schema, definitions, and example

## Artifacts & Outputs

- `.claude/agents/general-implementation-agent.md` -- Updated with Stage 5a, 4A/4D script calls, hard contract language
- `.claude/agents/general-implementation-hard-agent.md` -- Synced with Stage 5a if applicable
- `.claude/scripts/validate-artifact.sh` -- Extended with `--verify-completion` flag
- `.claude/docs/architecture/handoff-schema.md` -- Updated with `plan_markers_verified` field
- `specs/764_harden_plan_marker_enforcement/plans/01_plan-marker-plan.md` -- This plan
- `specs/764_harden_plan_marker_enforcement/summaries/01_plan-marker-summary.md` -- Implementation summary

## Rollback/Contingency

All changes are to documentation and shell scripts within `.claude/`. Rollback via `git checkout` of the affected files:
```bash
git checkout HEAD -- .claude/agents/general-implementation-agent.md .claude/agents/general-implementation-hard-agent.md .claude/scripts/validate-artifact.sh .claude/docs/architecture/handoff-schema.md
```
No runtime dependencies or build artifacts are affected. The changes are purely behavioral contracts and validation logic.
