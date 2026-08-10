# Implementation Plan: Task #763

- **Task**: 763 - Add --lit integration test script
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Tasks 760, 761, 762 (completed)
- **Research Inputs**: specs/763_add_lit_integration_test_script/reports/01_lit-pipeline-test-research.md
- **Artifacts**: plans/01_lit-test-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a test script at `.claude/scripts/test-lit-pipeline.sh` that validates the full `--lit` pipeline wiring across three layers: the `literature-briefing.sh` runtime script, the 4 CSLib skill SKILL.md Stage 4a blocks, and the 4 CSLib agent `.md` acknowledgment sections. The script uses static grep analysis by default (safe, fast) and offers an opt-in `--runtime` flag for smoke-testing `literature-briefing.sh` with mock fixtures. Output follows the `validate-wiring.sh` colored PASS/FAIL convention.

### Research Integration

The research report identified three test layers with specific grep patterns for each:
- **Layer 1**: `literature-briefing.sh` existence, executability, and `bash -n` syntax
- **Layer 2**: 4 CSLib skills with `lit_context=""` init, `literature-briefing.sh` call, and `lit_flag` gate
- **Layer 3**: 4 CSLib agents with `literature-briefing` or `<literature-briefing>` references
- **Bonus Layer**: General skill interactive detection (`literature-index.json` check + `literature-create-setup-task` reference) in `skill-researcher` and `skill-implementer`
- **Runtime**: Mock-fixture approach using temp dirs for `LITERATURE_DIR` and a temp `specs/literature-index.json` with `trap ... EXIT` cleanup

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No direct ROADMAP.md item. This task supports Phase 1 "Agent System Quality" by adding automated wiring verification for the `--lit` pipeline.

## Goals & Non-Goals

**Goals**:
- Validate that `literature-briefing.sh` and `literature-create-setup-task.sh` exist, are executable, and pass `bash -n` syntax check
- Verify all 4 CSLib skills contain Stage 4a `lit_context` wiring (initialization, briefing call, flag gate)
- Verify all 4 CSLib agents contain `<literature-briefing>` acknowledgment sections
- Verify 2 general skills contain interactive sub-index detection wiring
- Provide opt-in runtime smoke test that exercises `literature-briefing.sh` with mock fixtures
- Use `validate-wiring.sh` output style: colored PASS/FAIL/WARN, counters, summary, exit 1 on failures

**Non-Goals**:
- Testing the full `--lit` flag parsing in `command-gate-in.sh` or `skill-base.sh`
- Testing `literature-retrieve.sh` (the older `specs/literature/` injection mechanism)
- Testing the AskUserQuestion interactive flow end-to-end (requires user interaction)
- Adding the script to CI (separate task if desired)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Runtime test leaves temp `specs/literature-index.json` behind on crash | M | L | Use `trap 'cleanup' EXIT` to always remove temp files |
| Grep patterns match comments/prose instead of code | L | M | Use tighter patterns (e.g., `lit_context=""` not just `lit_context`) |
| Future skill/agent file restructuring breaks static tests | M | L | Test for semantic content, not line numbers; log file paths on failure |
| `literature-briefing.sh` path resolution assumes cwd is project root | M | L | Document usage requirement in script header; add cwd check |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create test-lit-pipeline.sh [COMPLETED]

**Goal**: Write the complete test script with all 6 test sections and colored output infrastructure.

**Tasks**:
- [ ] Create `.claude/scripts/test-lit-pipeline.sh` with shebang, usage comment, and `--runtime` flag parsing
- [ ] Implement color and logging infrastructure matching `validate-wiring.sh` (GREEN/RED/YELLOW/BLUE, `log_pass`/`log_fail`/`log_warn`/`log_info`, PASSED/FAILED/WARNINGS counters)
- [ ] Add cwd/project-root detection and validation (check `.claude/` exists)
- [ ] Section A: Script existence and syntax checks for `literature-briefing.sh` and `literature-create-setup-task.sh` (exists, executable, `bash -n` passes)
- [ ] Section B: CSLib skill Stage 4a wiring checks for 4 files (`skill-cslib-research`, `skill-cslib-implementation`, `skill-cslib-research-hard`, `skill-cslib-implementation-hard`): `lit_context=""` init, `literature-briefing.sh` call, `lit_flag` gate
- [ ] Section C: CSLib agent acknowledgment checks for 4 files (`cslib-research-agent`, `cslib-implementation-agent`, `cslib-research-hard-agent`, `cslib-implementation-hard-agent`): `literature.briefing` reference present
- [ ] Section D: General skill interactive detection checks for 2 files (`skill-researcher`, `skill-implementer`): `literature-index.json` sub-index check and `literature-create-setup-task` reference
- [ ] Section E (optional, `--runtime` flag): Runtime smoke test with mock fixtures -- create temp `LITERATURE_DIR` with mock `index.json`, write temp `specs/literature-index.json` with matching `doc_id`, run `literature-briefing.sh`, assert non-empty output containing `<literature-briefing>` and the test paper title
- [ ] Section E edge cases: Missing global index (empty stdout), empty sub-index entries (empty stdout), missing sub-index (empty stdout), invalid JSON sub-index (exit 0 graceful)
- [ ] Add cleanup trap (`trap 'cleanup' EXIT`) for runtime test temp files
- [ ] Add summary section: print total PASSED/FAILED/WARNINGS, exit 1 if FAILED > 0
- [ ] Make script executable (`chmod +x`)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/test-lit-pipeline.sh` - Create new test script (entire file)

**Verification**:
- `bash -n .claude/scripts/test-lit-pipeline.sh` passes (syntax valid)
- `.claude/scripts/test-lit-pipeline.sh` runs without `--runtime` and produces PASS/FAIL output
- `.claude/scripts/test-lit-pipeline.sh --runtime` runs and exercises mock fixtures (if global Literature dir not required)

---

### Phase 2: Verify and document [COMPLETED]

**Goal**: Run the script against the current codebase to confirm all static checks pass, fix any false negatives, and add a usage note to the script header.

**Tasks**:
- [ ] Run `bash .claude/scripts/test-lit-pipeline.sh` and verify all static checks (Sections A-D) pass
- [ ] Run `bash .claude/scripts/test-lit-pipeline.sh --runtime` to verify runtime smoke test works with mock fixtures
- [ ] Fix any grep pattern issues that cause false failures (tighten or relax patterns as needed)
- [ ] Ensure script header includes usage documentation: `Usage: .claude/scripts/test-lit-pipeline.sh [--runtime]`
- [ ] Verify exit code is 0 when all tests pass, 1 when any fail

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/test-lit-pipeline.sh` - Fix any pattern issues found during verification

**Verification**:
- All static checks pass (exit 0) against current codebase
- Runtime smoke test passes with `--runtime` flag
- Intentionally breaking a grep target (e.g., removing `literature-briefing` from an agent file) causes the correct FAIL output

## Testing & Validation

- [ ] `bash -n .claude/scripts/test-lit-pipeline.sh` succeeds (valid bash syntax)
- [ ] Script runs from project root and produces colored PASS/FAIL output
- [ ] All static checks (Sections A-D) pass against current codebase
- [ ] Runtime smoke test (Section E) passes with `--runtime` flag
- [ ] Script exits 0 when all checks pass
- [ ] Script exits 1 when any check fails (verified by temporarily removing a target pattern)
- [ ] No temp files left behind after `--runtime` test (check `specs/literature-index.json` does not exist if it did not exist before)

## Artifacts & Outputs

- `.claude/scripts/test-lit-pipeline.sh` - The test/verification script
- `specs/763_add_lit_integration_test_script/plans/01_lit-test-plan.md` - This plan
- `specs/763_add_lit_integration_test_script/summaries/01_lit-test-summary.md` - Implementation summary (created during /implement)

## Rollback/Contingency

The script is a single new file with no impact on existing functionality. Rollback is simply deleting `.claude/scripts/test-lit-pipeline.sh`. No existing files are modified.
