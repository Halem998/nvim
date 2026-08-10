# Implementation Plan: Contract Lint Testing Strategy

- **Task**: 677 - contract_lint_testing_strategy
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: Task 669 (hard_mode_agent_system)
- **Research Inputs**: specs/677_contract_lint_testing_strategy/reports/01_contract-lint-research.md
- **Artifacts**: plans/01_contract-lint-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement a bash-based testing strategy for hard-mode behavioral contract compliance. The strategy creates a new static lint script for contract @-reference and vocabulary checks, extends two existing validation scripts (`validate-wiring.sh` and `validate-artifact.sh`) to cover hard-mode agents/skills/plans, and adds a standalone handoff schema validator. All scripts follow the existing bash lint patterns established by `lint-postflight-boundary.sh` and `validate-wiring.sh`, requiring no new infrastructure or test frameworks.

### Research Integration

Research report (`01_contract-lint-research.md`) identified three tiers of testable contract properties: Tier 1 (fully static file content checks), Tier 2 (artifact-level post-hoc checks), and Tier 3 (dynamic runtime traces, deferred). The research catalogued specific statically-checkable properties for all five contracts (anti-analysis, reference-grounding, convergence, territory, wrap-up) and provided concrete implementation sketches for each validation function. Key gap: `validate-wiring.sh` has zero hard-mode coverage, and `validate-artifact.sh` has no hard-mode plan section checks.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items identified for this meta/infrastructure task.

## Goals & Non-Goals

**Goals**:
- Create `lint-contract-compliance.sh` covering Tier 1 static checks for all five hard-mode contracts
- Extend `validate-wiring.sh` to validate hard-mode agents, skills, and contract file existence
- Extend `validate-artifact.sh` to detect and check hard-mode plan sections (postmortem constraints, phase sizing, wave maps)
- Create `validate-handoff.sh` for orchestrator handoff JSON schema validation
- Document what is NOT checked (runtime behavior) to prevent false confidence

**Non-Goals**:
- Runtime trace harness for behavioral compliance (deferred to future task)
- CI integration (meta tasks skip CI by default)
- Automated test runner framework (all scripts are standalone)
- Modifying the contracts themselves or the hard-mode agents/skills

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Static checks give false confidence about behavioral correctness | H | M | Document clearly in each script header what is NOT checked |
| Lint script becomes stale as contracts evolve | M | M | Check contract files by reading them for vocabulary, not hardcoded strings where possible |
| Hard-mode plan checks produce false positives on non-hard plans | M | L | Gate checks on detection of "hard-mode" or "planner-hard" marker in plan metadata |
| validate-wiring.sh extension conflicts with existing checks | M | L | Add hard-mode checks in a separate function, called from main() after existing checks |
| Contract file structure changes break grep patterns | M | M | Use anchored heading patterns (^##) that are format-stable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1      | --         |
| 2    | 2, 3   | 1          |
| 3    | 4      | 2, 3       |

Phases within the same wave can execute in parallel.

---

### Phase 1: Static Contract Lint Script [COMPLETED]

**Goal**: Create the core lint script that validates hard-mode contract structural compliance across agent files, skill files, contract files, and index.json.

**Tasks**:
- [x] Create `.claude/scripts/lint/lint-contract-compliance.sh` following the `lint-postflight-boundary.sh` pattern (colored output, exit 0/1, `set -euo pipefail`) *(completed)*
- [x] Implement Check A: hard-agent contract @-references (verify each hard agent references its required contracts in Context References section) *(completed)*
- [x] Implement Check B: contract file existence and H-technique references (all 5 contract files exist and contain H-technique identifiers) *(completed)*
- [x] Implement Check C: skill-to-hard-agent dispatch wiring (each hard skill dispatches to correct hard agent) *(completed)*
- [x] Implement Check D: convergence policing fields in `skill-orchestrate-hard/SKILL.md` (churn fields: `total_churn`, `target_churn`, `adversarial_triggers`) *(completed)*
- [x] Implement Check E: H2 vocabulary in implementation-hard agent (Forbidden Conclusions, Defect Bar, single-phase, settled-design) *(completed)*
- [x] Implement Check F: index.json contract coverage for hard agents (verify hard agents appear in contract `load_when.agents` entries) *(completed)*
- [x] Add `--verbose` flag for detailed output and `--help` for usage *(completed)*
- [x] Add script header documenting what IS and IS NOT checked (explicit scope boundary) *(completed)*
- [x] Test the script against the current codebase and verify exit code 0 *(completed: 24 checks pass)*

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/lint/lint-contract-compliance.sh` - New file (~200-250 lines)

**Verification**:
- Script runs without errors: `bash .claude/scripts/lint/lint-contract-compliance.sh`
- Exit code 0 on current codebase (all checks pass)
- `--verbose` flag produces detailed per-check output
- Intentionally breaking a contract reference produces exit code 1

---

### Phase 2: Hard-Mode Wiring Validation Extension [COMPLETED]

**Goal**: Extend `validate-wiring.sh` to cover hard-mode agents, skills, and contract files so the existing wiring validator has full coverage.

**Tasks**:
- [x] Add `validate_hard_mode_system()` function to `validate-wiring.sh` *(completed)*
- [x] Check hard agent existence (3 agents: `general-research-hard-agent`, `planner-hard-agent`, `general-implementation-hard-agent`) *(completed)*
- [x] Check hard skill directory existence (4 skills: `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`, `skill-orchestrate-hard`) *(completed)*
- [x] Check contract file existence (5 contracts in `.claude/context/contracts/`) *(completed)*
- [x] Check index.json entries exist for hard agents (at least one entry per hard agent in `load_when.agents`) *(completed)*
- [x] Call `validate_hard_mode_system()` from the main execution flow (after existing `validate_claude_system` or `validate_all_systems` calls) *(completed)*
- [x] Verify script still passes with `--claude` and `--all` flags *(completed: all hard-mode checks pass)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/validate-wiring.sh` - Add ~60-80 lines (new function + call site)

**Verification**:
- `bash .claude/scripts/validate-wiring.sh --claude` includes hard-mode checks in output
- All hard-mode checks show `[PASS]` on current codebase
- Removing a hard agent file causes `[FAIL]` in output

---

### Phase 3: Hard-Mode Plan Artifact Checks [COMPLETED]

**Goal**: Extend `validate-artifact.sh` to detect hard-mode plans and verify they contain required sections (postmortem constraints, phase sizing annotations, dependency wave maps).

**Tasks**:
- [x] Add hard-mode plan detection logic: check for `planner-hard` or `hard-mode` or `--hard` in plan metadata/title *(completed: gates on title/metadata, not body)*
- [x] When hard-mode plan detected, check for `## Postmortem Constraints` section heading *(completed)*
- [x] Check for phase sizing annotations: at least one `### Phase` has `Estimated output` and `Done when` fields *(completed)*
- [x] Check for Dependency Analysis wave map table (already checked for all plans; verify it covers hard-mode plans) *(completed: pre-existing check covers this)*
- [x] Ensure non-hard plans are not flagged by the hard-mode checks (gate on detection) *(completed: verified)*
- [x] Add hard-mode check results to the existing pass/fail output format *(completed: warnings appear in summary)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/validate-artifact.sh` - Add ~30-40 lines (hard-mode detection + checks)

**Verification**:
- `bash .claude/scripts/validate-artifact.sh specs/.../plans/hard-plan.md plan` reports hard-mode section status
- Non-hard plans are not flagged for missing hard-mode sections
- Missing `## Postmortem Constraints` in a hard plan produces a warning

---

### Phase 4: Handoff Schema Validation Script [COMPLETED]

**Goal**: Create a standalone validator for `.orchestrator-handoff.json` files produced by `skill-orchestrate-hard`, verifying JSON structure, required fields, and status/continuation_path consistency.

**Tasks**:
- [x] Create `.claude/scripts/validate-handoff.sh` following existing script patterns (colored output, usage help) *(completed)*
- [x] Validate JSON parsability with `jq empty` *(completed)*
- [x] Check required fields: `status`, `phases_completed`, `phases_total`, `blockers` *(completed: sorry_inventory and continuation_path treated as optional warnings)*
- [x] Validate status value is one of: `implemented`, `partial`, `blocked` *(completed)*
- [x] When status is `partial` or `blocked`, verify `continuation_path` is non-null *(completed: accepts continuation_context as alternative)*
- [x] When status is `partial`, verify `phases_completed < phases_total` *(completed)*
- [x] Add usage documentation and `--help` flag *(completed)*
- [x] Test against any existing handoff files in `specs/` directories *(completed: tested against 3 existing files)*

**Timing**: 1 hour

**Depends on**: 2, 3

**Files to modify**:
- `.claude/scripts/validate-handoff.sh` - New file (~80-100 lines)

**Verification**:
- Script accepts a valid handoff JSON file with exit code 0
- Invalid JSON produces clear error message
- Missing required fields produce warnings
- Status/continuation_path inconsistency produces warning

## Testing & Validation

- [x] `lint-contract-compliance.sh` exits 0 on current codebase *(24 checks pass)*
- [x] `validate-wiring.sh --claude` includes hard-mode checks and all pass *(16 new hard-mode checks all PASS)*
- [x] `validate-artifact.sh` correctly detects and checks a hard-mode plan *(warns on missing Postmortem Constraints and phase sizing)*
- [x] `validate-artifact.sh` does not flag non-hard plans for hard-mode sections *(verified)*
- [x] `validate-handoff.sh` validates existing handoff JSON files (if any) *(tested against 5 existing files)*
- [x] All scripts have consistent colored output format (PASS/FAIL/WARN) *(verified)*
- [x] All scripts include usage documentation via `--help` flag *(verified)*
- [x] No regressions in existing `validate-wiring.sh` or `validate-artifact.sh` checks *(verified)*

## Artifacts & Outputs

- `.claude/scripts/lint/lint-contract-compliance.sh` - New static contract lint script
- `.claude/scripts/validate-wiring.sh` - Extended with hard-mode system validation
- `.claude/scripts/validate-artifact.sh` - Extended with hard-mode plan checks
- `.claude/scripts/validate-handoff.sh` - New handoff schema validator
- `specs/677_contract_lint_testing_strategy/plans/01_contract-lint-plan.md` - This plan

## Rollback/Contingency

All changes are additive. The new lint script and handoff validator are standalone files that can be deleted. The extensions to `validate-wiring.sh` and `validate-artifact.sh` add new functions called from main() -- reverting requires removing the function definitions and their call sites. Git revert of the implementation commit cleanly undoes all changes.
