# Implementation Plan: Plan Compliance Spot-Check Gate

- **Task**: 565 - plan_compliance_spot_check_gate
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_compliance-gate-research.md
- **Artifacts**: plans/01_compliance-gate-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a plan-compliance spot-check gate (Stage 6b) to the `.opencode/` lean implementation skill that verifies plan-declared deliverables exist in the codebase with non-vacuous definitions, and detects integrity violations where a "replacement" function delegates to the function it purports to replace. Also add a lean4-specific verification hook to the `.opencode/` checkpoint-gate-out.md that reads the compliance result from metadata.

### Research Integration

Research confirmed: (1) Stage 6b should sit between the existing Zero-Debt Gate (Stage 6) and Status Update (Stage 7); (2) the `**Goals**:` section in plan files is the most machine-readable source for deliverable names; (3) replacement relationships can be detected via patterns like "replacement for", "replaces", "bypasses", "supersedes"; (4) `orchestration-validation.md` does not need changes; (5) the `.claude/` lean skill has a different architecture and is out of scope (task 566).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" items in Phase 1 of the roadmap, specifically improving implementation verification integrity for lean tasks. No direct roadmap item references this exact feature, but it strengthens the overall agent system quality.

## Goals & Non-Goals

**Goals**:
- Add Stage 6b (Plan Compliance Spot-Check) to `.opencode/skills/skill-lean-implementation/SKILL.md`
- Implement deliverable existence check: extract backtick-wrapped identifiers from plan `**Goals**:` section and verify each exists in `Theories/` as a `theorem`/`def`/`lemma`/`instance`
- Implement delivery integrity check: detect when a plan-declared replacement function calls the function it replaces
- Set `compliance_check` field in metadata (`"passed"` or `"failed"`) for downstream consumption
- Add section 2b to `.opencode/context/checkpoints/checkpoint-gate-out.md`: lean4-specific compliance verification that reads `compliance_check` from metadata
- Graceful degradation: if plan has no `**Goals**:` section, emit WARNING and continue (non-blocking)

**Non-Goals**:
- Modifying `orchestration-validation.md` (domain checks belong in skill layer)
- Modifying the `.claude/` (nvim) lean skill (different architecture; task 566 scope)
- Adding a full re-build or re-running `lake build` in Stage 6b (already done in Stage 6)
- Guaranteeing zero false positives on the integrity check (graceful degradation is acceptable)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Goals section uses backtick names that are types/modules, not theorems | M | M | Only WARN on missing names; only FAIL when the pattern `theorem/def/lemma/instance` search is conclusive |
| sed boundary parsing stops at wrong `**` delimiter | M | L | Use `## ` heading boundary as fallback; test with actual plan files |
| Replacement-pattern grep misses variant phrasings | L | M | Include multiple patterns; false negatives are safer than false positives |
| File defining X references Y in comments (false positive on integrity check) | M | L | Use word-boundary matching (`\b`); document known limitation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add Stage 6b to skill-lean-implementation/SKILL.md [COMPLETED]

**Goal**: Insert the plan compliance spot-check stage between the existing Stage 6 (Zero-Debt Gate) and Stage 7 (Status Update).

**Tasks**:
- [ ] Read current SKILL.md to confirm exact insertion point (after Stage 6 closing `---`, before Stage 7 heading)
- [ ] Insert new `### Stage 6b: Plan Compliance Spot-Check (MANDATORY)` section with:
  - Step 1: Extract plan goal theorems — `sed` to isolate `**Goals**:` section, `grep -oP` for backtick-wrapped identifiers, `sort -u`
  - Step 2: Deliverable existence check — loop over extracted names, `grep -rq` for `^(noncomputable )?(theorem|def|lemma|instance) $name\b` in `Theories/`
  - Step 3: Delivery integrity check — scan plan for replacement patterns, find file defining the new name, check if replaced name appears in that file
  - Step 4: Set metadata — if any check fails, set `compliance_failed=true` and `status="partial"`; write `compliance_check` field to metadata
- [ ] Add graceful degradation: if plan file not found or has no `**Goals**:` section, emit `WARNING: No goals found — skipping compliance check` and set `compliance_check="skipped"`
- [ ] Update the metadata write logic (between Stage 6b and Stage 7) to include `compliance_check` in the metadata object passed to state updates

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` - Insert Stage 6b section (~60 lines of markdown)

**Verification**:
- Stage 6b section exists between Stage 6 and Stage 7
- The section references `plan_file` variable (already available from GATE IN)
- Graceful degradation path documented and non-blocking
- `compliance_check` field is set in all code paths (passed/failed/skipped)

---

### Phase 2: Add Section 2b to checkpoint-gate-out.md [COMPLETED]

**Goal**: Add a lean4-specific compliance verification hook that reads the `compliance_check` field from metadata and blocks progression if it reports failure.

**Tasks**:
- [ ] Read current checkpoint-gate-out.md to confirm insertion point (after section 2 "Verify Artifacts Exist", before section 3 "Update Status")
- [ ] Insert new `### 2b. Lean4-Specific: Plan Compliance Verification (lean4 task_type only)` section with:
  - Condition: only runs if `task_type` is "lean4" or "lean"
  - Read `compliance_check` from metadata file: `jq -r '.metadata.compliance_check // "skipped"' "$metadata_file"`
  - If `"failed"`: emit `GATE OUT BLOCKED: Plan compliance check failed` and set `decision="PARTIAL"`
  - If `"skipped"` or field absent: emit INFO and proceed (backward compatible)
  - If `"passed"`: proceed normally
- [ ] Ensure section uses consistent variable names (`$metadata_file`, `$task_type`) matching existing sections

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` - Insert section 2b (~25 lines of markdown)

**Verification**:
- Section 2b appears between sections 2 and 3
- Variable names match existing file conventions
- Backward compatibility: absent field does not block

---

### Phase 3: End-to-End Verification [COMPLETED]

**Goal**: Validate that the two modified files are internally consistent and the data flow from Stage 6b to GATE OUT section 2b is correct.

**Tasks**:
- [ ] Re-read both modified files to confirm no syntax errors in code blocks
- [ ] Verify the metadata field name is consistent: `compliance_check` used in both SKILL.md (writer) and checkpoint-gate-out.md (reader)
- [ ] Verify the field path is consistent: Stage 6b writes to `.metadata.compliance_check`; section 2b reads from `.metadata.compliance_check`
- [ ] Confirm plan_file variable is available in Stage 6b (trace from GATE IN complexity warning where it is first assigned)
- [ ] Confirm Stage 6b is gated on `status == "implemented"` (same condition as Stage 6) so it does not run on already-failed implementations

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- No new files; read-only verification of both modified files

**Verification**:
- Both files use `compliance_check` as the field name
- Both files use `.metadata.compliance_check` as the JSON path
- Stage 6b only runs when status from metadata is "implemented"
- No orphan variable references

## Testing & Validation

- [ ] Verify Stage 6b section inserted at correct position in SKILL.md (between Stage 6 and Stage 7)
- [ ] Verify section 2b inserted at correct position in checkpoint-gate-out.md (between sections 2 and 3)
- [ ] Verify `compliance_check` field name is consistent across both files
- [ ] Verify graceful degradation path (no `**Goals**:` section) documented as non-blocking
- [ ] Verify backward compatibility (missing field in metadata does not cause errors)
- [ ] Verify word-boundary matching used in integrity check (`\b$replaced\b`)

## Artifacts & Outputs

- `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` (modified)
- `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` (modified)
- `specs/565_plan_compliance_spot_check_gate/plans/01_compliance-gate-plan.md` (this plan)

## Rollback/Contingency

Both target files are under version control in the ProofChecker repository. If changes introduce regressions:

1. `git checkout HEAD -- .opencode/skills/skill-lean-implementation/SKILL.md .opencode/context/checkpoints/checkpoint-gate-out.md`
2. The compliance check is additive and gated on `status == "implemented"` — removing it has no effect on existing workflows
3. If the compliance check produces excessive false positives, change `compliance_failed=true` to a WARNING-only mode by commenting out the `status="partial"` line
