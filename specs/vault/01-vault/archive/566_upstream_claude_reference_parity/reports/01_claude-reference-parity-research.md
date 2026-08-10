# Research Report: Upstream .claude/ Reference System Parity

- **Task**: 566 - upstream_claude_reference_parity
- **Started**: 2026-05-13T00:00:00Z
- **Completed**: 2026-05-13T01:00:00Z
- **Effort**: 1 hour
- **Dependencies**: Task 564 (escalation protocol, vacuous prohibition — already applied to .claude/ agent), Task 565 (plan compliance gate — applied to ProofChecker, template needed here)
- **Sources/Inputs**:
  - `.claude/extensions/lean/rules/lean4.md` — current state (no Vacuous Definitions section)
  - `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` — current state (Stage 5–9, no Stage 6b)
  - `.claude/context/checkpoints/checkpoint-gate-out.md` — current state (no lean4 section 2b)
  - `.claude/extensions/lean/agents/lean-implementation-agent.md` — already updated by task 564
  - `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` — section 2b reference (task 565)
  - `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` — Stage 6b reference (task 565)
  - `specs/564_*/summaries/01_escalation-protocol-summary.md` — task 564 completion record
  - `specs/565_*/summaries/01_compliance-gate-summary.md` — task 565 completion record
- **Artifacts**: `specs/566_upstream_claude_reference_parity/reports/01_claude-reference-parity-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: Task 564 (lean-implementation-agent.md already patched), Task 565 (ProofChecker SKILL.md + checkpoint-gate-out.md patched — this task applies same to .claude/ reference)
- **Downstream Dependents**: All lean4 tasks run via the nvim .claude/ system; the upstream template propagates to new projects
- **Alternative Paths**: None — changes must be made to specific files
- **Potential Extensions**: Extract goal-name parser into shared script once both architectures have Stage 6b

## Executive Summary

- Task 564 already applied escalation protocol, vacuous prohibition, Phase Checkpoint Protocol, and vacuous_count check to `.claude/extensions/lean/agents/lean-implementation-agent.md` — **no changes needed to that file**
- Three files in the `.claude/` reference system need updates: `lean4.md` (rules), `SKILL.md` (implementation skill), and `checkpoint-gate-out.md` (checkpoint)
- The `.claude/` SKILL.md architecture prohibits re-running grep in postflight (postflight-tool-restrictions.md); Stage 6b must read `compliance_check` from agent metadata rather than executing shell checks
- The ProofChecker `.opencode/` versions (updated in task 565) serve as the reference implementation, with architectural adaptation required for the `.claude/` skill
- The `.claude/context/checkpoints/checkpoint-gate-out.md` is the canonical location for the lean4-specific section 2b — the `.claude/extensions/core/context/checkpoints/checkpoint-gate-out.md` copy also exists but is the extension copy; the context/ copy is what commands load

## Context & Scope

### What Needs To Change

**File 1: `.claude/extensions/lean/rules/lean4.md`**

Currently missing: "Vacuous Definitions (PROHIBITED)" section identical to the one added to ProofChecker's lean4.md in task 564. The section must be added before the "What to Do Instead" content is split from the rules file.

Current file has: Essential MCP Tools, Search Decision Tree, Workflow Pattern, Common Tactics, Build Commands, Literature Fidelity. No vacuous definitions section.

**File 2: `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`**

Currently has Stage 5 (Parse Subagent Return) → Stage 6 (Update Task Status) → Stage 7 (Link Artifacts) → Stage 8 (Git Commit) → Stage 9 (Return).

Needs Stage 6b inserted between Stage 5 and Stage 6 (renaming old Stage 6 to Stage 7, etc. is NOT needed — just insert "Stage 6b" as a new labeled stage). 

**Critical architectural difference from ProofChecker**: The `.claude/` skill follows `postflight-tool-restrictions.md` which prohibits grep/bash analysis in postflight. Stage 6b in `.claude/` must NOT re-run the grep check. Instead:

```bash
# Read compliance_check from agent metadata (agent ran the check; skill reads result)
compliance_check=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

case "$compliance_check" in
    "failed")
        echo "Stage 6b: Plan compliance check FAILED (agent reported)"
        echo "  See agent output for missing deliverables or integrity violations"
        status="partial"
        ;;
    "passed")
        echo "Stage 6b: Plan compliance check PASSED"
        ;;
    "skipped"|*)
        echo "Stage 6b: INFO — compliance_check absent or skipped; proceeding"
        ;;
esac
```

This is architecturally different from the ProofChecker SKILL.md which re-runs grep in postflight. The `.claude/` postflight reads the agent's self-reported result.

**Where does the agent run the compliance check?** The lean-implementation-agent.md (already updated by task 564) runs the Zero-Debt gate and reports results in metadata. The compliance check can be integrated into the agent's Final Verification Stage — adding a "Plan Compliance Spot-Check" step that mirrors what ProofChecker's SKILL.md Stage 6b does, but runs in the AGENT (not postflight). Alternatively, Stage 6b in the SKILL can be a lightweight read that trusts the agent's `compliance_check` field.

Given task 564's scope: the lean-implementation-agent.md was updated but the compliance spot-check is a task 565 feature, not task 564. So the agent does NOT yet have the compliance spot-check. The cleanest approach:

**Option A**: Add compliance spot-check to the agent (lean-implementation-agent.md) in the Final Verification Stage, and have the SKILL Stage 6b read the result.
**Option B**: Add compliance spot-check to the SKILL Stage 6b using only `jq` reads (no grep), treating it as a metadata-pass-through with the check location being TBD.

The task description says: "the check must read compliance_check from agent metadata (verification.compliance_check)". This implies the agent already does the check and writes to metadata. Given that task 565 added Stage 6b to ProofChecker SKILL.md (not to the agent), we have a design choice.

**Recommended approach**: Add the compliance spot-check to the **agent's Final Verification Stage** (since the `.claude/` postflight cannot run grep), and have SKILL Stage 6b read `metadata.compliance_check`. This requires a small addition to `lean-implementation-agent.md` for the compliance check section. This is consistent with the "agent does verification work" principle.

**File 3: `.claude/context/checkpoints/checkpoint-gate-out.md`**

Currently missing section 2b (lean4-specific plan compliance verification). The ProofChecker checkpoint has this section. The same content applies verbatim since it reads from metadata.

## Findings

### File Analysis

| File | Current State | Gap | Action |
|------|--------------|-----|--------|
| `lean-implementation-agent.md` | Already updated (task 564) | No compliance check in Final Verification Stage | Add compliance spot-check to Final Verification Stage |
| `lean4.md` | No vacuous section | Missing "Vacuous Definitions (PROHIBITED)" section | Copy from ProofChecker lean4.md |
| `SKILL.md` | Stage 5→6→7→8→9 | Missing Stage 6b (metadata-read compliance check) | Add Stage 6b after Stage 5, reading `metadata.compliance_check` |
| `checkpoint-gate-out.md` | No section 2b | Missing lean4 compliance hook | Add section 2b verbatim from ProofChecker |

### Architecture Constraint Confirmed

`postflight-tool-restrictions.md` is explicit:
- `grep` on source files: PROHIBITED ("Analysis is agent work")
- MCP tools: PROHIBITED
- Verification commands: PROHIBITED

Therefore Stage 6b in `.claude/` SKILL must be a metadata reader only. The grep check (deliverable existence, integrity) must live in the agent.

### Agent Final Verification Stage — Current State

The `lean-implementation-agent.md` Final Verification Stage (lines 118–193) currently checks:
1. `sorry_count` (grep)
2. `vacuous_count` (added by task 564 — grep)
3. `axiom_count` (grep)
4. `lake build`

Missing: plan compliance spot-check (deliverable existence + replacement integrity). This needs to be added as step 5 in the Final Verification Stage.

### Plan Compliance Check in Agent

The agent can run the compliance check as part of Final Verification Stage, step 5:

```bash
# Step 5: Plan compliance spot-check
plan_file=$(ls specs/${padded_num}_${project_name}/plans/*.md 2>/dev/null | sort -V | tail -1)
if [ -z "$plan_file" ]; then
    compliance_check="skipped"
else
    goal_names=$(sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" \
      | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`' | sort -u)
    if [ -z "$goal_names" ]; then
        compliance_check="skipped"
    else
        compliance_failed=false
        for name in $goal_names; do
            if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) $name\b" Theories/ 2>/dev/null; then
                echo "  [OK] $name found"
            else
                echo "  [MISSING] $name not found"
                compliance_failed=true
            fi
        done
        # Integrity check (replacement delegation detection)
        replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses|supersedes)\s+`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan_file" 2>/dev/null \
            | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`')
        for replaced in $replacement_targets; do
            for new_name in $goal_names; do
                new_file=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) $new_name\b" Theories/ 2>/dev/null | head -1)
                if [ -n "$new_file" ] && grep -q "\b${replaced}\b" "$new_file"; then
                    echo "  [INTEGRITY FAIL] $new_name delegates to $replaced"
                    compliance_failed=true
                fi
            done
        done
        [ "$compliance_failed" = true ] && compliance_check="failed" || compliance_check="passed"
    fi
fi
```

Record in metadata: `"metadata": { ..., "compliance_check": "$compliance_check" }`

## Decisions

1. **Add compliance spot-check to agent, not SKILL postflight** — consistent with postflight-tool-restrictions.md; agent does analysis, skill reads result
2. **SKILL Stage 6b reads `metadata.compliance_check`** — lightweight, backward compatible (absent field treated as "skipped")
3. **Lean4.md vacuous section**: copy verbatim from ProofChecker version (identical prohibited patterns apply)
4. **Checkpoint section 2b**: copy verbatim from ProofChecker version (same logic, reads from metadata)
5. **Do not renumber existing stages** — insert "Stage 6b" as labeled addition, existing Stage 6/7/8/9 labels stay

## Recommendations

### Priority Order

1. **`.claude/extensions/lean/rules/lean4.md`** — add Vacuous Definitions section (simple append)
2. **`.claude/extensions/lean/agents/lean-implementation-agent.md`** — add plan compliance spot-check to Final Verification Stage (step 5)
3. **`.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`** — add Stage 6b (metadata read only)
4. **`.claude/context/checkpoints/checkpoint-gate-out.md`** — add section 2b

### Implementation Notes

- Files 1 and 4 are pure insertions with no structural changes
- File 2 (agent) adds a step to an existing section — minimal diff
- File 3 (SKILL) inserts Stage 6b between Stage 5 and Stage 6 — minimal diff
- No renaming of existing stages required
- All changes are backward compatible (absent `compliance_check` in metadata → "skipped")

## Risks & Mitigations

- **Risk**: Adding compliance check to agent could cause false negatives if `**Goals**:` section is absent from plan → **Mitigated**: graceful degradation to "skipped"
- **Risk**: Grep pattern may miss complex identifiers → **Mitigated**: same caveat applies to ProofChecker; document as known limitation
- **Risk**: Stage 6b adds latency to every lean implementation → **Mitigated**: bash grep is fast; only runs when status is "implemented"

## Appendix

### Key File Paths

| File | Path |
|------|------|
| lean4.md (rules) | `.claude/extensions/lean/rules/lean4.md` |
| lean-implementation-agent.md | `.claude/extensions/lean/agents/lean-implementation-agent.md` |
| SKILL.md | `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` |
| checkpoint-gate-out.md | `.claude/context/checkpoints/checkpoint-gate-out.md` |
| ProofChecker reference SKILL.md | `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` |
| ProofChecker reference checkpoint | `/home/benjamin/Projects/ProofChecker/.opencode/context/checkpoints/checkpoint-gate-out.md` |
