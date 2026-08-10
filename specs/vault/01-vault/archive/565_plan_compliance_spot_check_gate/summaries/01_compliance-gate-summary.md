# Implementation Summary: Task #565

## Metadata

- **Task**: 565 - plan_compliance_spot_check_gate
- **Status**: COMPLETED
- **Started**: 2026-05-13
- **Completed**: 2026-05-13
- **Effort**: ~1 hour
- **Artifacts**: plans/01_compliance-gate-plan.md, this file

## Overview

Added a plan-compliance spot-check gate (Stage 6b) to the ProofChecker `.opencode/` lean implementation skill, and a corresponding lean4-specific compliance verification hook to `checkpoint-gate-out.md`. The gate verifies that plan-declared deliverables exist in `Theories/` and detects integrity violations where a replacement function delegates to the function it purports to replace.

## What Changed

### Stage 6b added to SKILL.md (between Stage 6 and Stage 7)

The new stage runs only when the subagent returned `"implemented"` status. It:

1. **Extracts goal names** from the plan file's `**Goals**:` section using `sed`/`grep -oP` to find backtick-wrapped identifiers
2. **Deliverable existence check**: Greps `Theories/` for each name as a `theorem`/`def`/`lemma`/`instance`; marks missing names as failures
3. **Delivery integrity check**: Detects "replacement for"/"replaces"/"bypasses"/"supersedes" patterns in the plan, then checks whether the new definition references the replaced name (delegation detection)
4. **Sets `compliance_check`** to `"passed"`, `"failed"`, or `"skipped"` in all code paths; downgrades status to `"partial"` on failure
5. **Graceful degradation**: If plan file is absent or has no `**Goals**:` section, emits INFO and sets `compliance_check="skipped"` (non-blocking)

### Section 2b added to checkpoint-gate-out.md (between sections 2 and 3)

The new section is lean4/lean task_type-only. It:

- Reads `compliance_check` from `.metadata.compliance_check` in the metadata file
- On `"failed"`: emits `GATE OUT: Plan compliance check FAILED` and sets `decision="PARTIAL"`
- On `"passed"`: proceeds normally
- On `"skipped"` or absent field: emits INFO and proceeds (backward compatible)

## Decisions

- **Graceful degradation over hard failure**: Missing plan file or absent `**Goals**:` section sets `compliance_check="skipped"` rather than blocking — false negatives are safer than false positives for this check
- **Word-boundary matching**: Integrity check uses `\b${replaced}\b` to reduce false positives from comments containing partial identifier matches
- **Skipped git commits**: The ProofChecker repo's `.gitignore` excludes `.opencode/` (line 52), so the phase commits from the plan could not be executed. File changes are saved to disk; committing `.opencode/` config changes is outside the repo's version control scope

## Impacts

- All lean4/lean implementation tasks that return `"implemented"` will now run the compliance spot-check before status update
- GATE OUT will block on `"failed"` compliance results for lean4/lean task types
- Existing metadata files without `compliance_check` field are backward compatible (treated as `"skipped"`)

## Follow-ups

- Task 566: Apply analogous compliance gate to the `.claude/` (nvim) lean skill, which has a different architecture
- Consider extracting the goal-name parser into a shared script once both skill architectures are updated

## References

- Plan: `specs/565_plan_compliance_spot_check_gate/plans/01_compliance-gate-plan.md`
- SKILL.md: `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` (Stage 6b at line 198)
- checkpoint-gate-out.md: `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` (section 2b at line 42)
