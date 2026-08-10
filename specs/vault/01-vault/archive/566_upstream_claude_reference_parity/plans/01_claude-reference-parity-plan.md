# Implementation Plan: Upstream .claude/ Reference System Parity

- **Task**: 566 - upstream_claude_reference_parity
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 564 (completed), Task 565 (completed)
- **Research Inputs**: specs/566_upstream_claude_reference_parity/reports/01_claude-reference-parity-research.md
- **Artifacts**: plans/01_claude-reference-parity-plan.md (this file)
- **Standards**: plan.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Apply lean agent integrity improvements to the `.claude/extensions/lean/` reference system. Task 564 already updated `lean-implementation-agent.md`; this task handles the remaining three files: `lean4.md` (rules), `SKILL.md` (skill), and `checkpoint-gate-out.md` (checkpoint). The key architectural constraint is that the `.claude/` skill postflight cannot run grep (postflight-tool-restrictions.md), so plan compliance must be checked in the agent and read back via metadata — not executed in the skill.

**Research Integration**: Report `01_claude-reference-parity-research.md` identifies all gaps and confirms the architecture decision that the compliance spot-check must run in `lean-implementation-agent.md` Final Verification Stage, with SKILL Stage 6b reading `metadata.compliance_check`.

## Goals & Non-Goals

- **Goals**:
  - Add Vacuous Definitions (PROHIBITED) section to `lean4.md`
  - Add plan compliance spot-check step to `lean-implementation-agent.md` Final Verification Stage
  - Add Stage 6b (metadata-read compliance check) to `SKILL.md`
  - Add section 2b (lean4 compliance hook) to `checkpoint-gate-out.md`
- **Non-Goals**:
  - Do not modify `lean-implementation-agent.md` sections already updated by task 564
  - Do not add grep or shell analysis to SKILL postflight
  - Do not modify ProofChecker files
  - Do not renumber existing SKILL.md stages

## Risks & Mitigations

- **Risk**: Edit to lean-implementation-agent.md could conflict with task 564 changes → **Mitigation**: Read current file state before editing; insert only at Final Verification Stage step 4 (after existing vacuous_count check) — add step 5 plan compliance
- **Risk**: SKILL Stage 6b references `metadata.compliance_check` but agent uses `metadata.compliance_check` as key — need consistent key naming → **Mitigation**: Use `metadata.compliance_check` in agent metadata block; SKILL reads `.metadata.compliance_check`
- **Risk**: checkpoint-gate-out.md is referenced at two paths (.claude/context/ and .claude/extensions/core/context/) → **Mitigation**: Update only `.claude/context/checkpoints/checkpoint-gate-out.md` (the canonical location loaded by commands); the extensions/core copy is a separate file requiring separate check

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases are sequential since each phase builds on the previous (agent change enables SKILL Stage 6b which is referenced by checkpoint).

### Phase 1: Add Vacuous Definitions Section to lean4.md [COMPLETED]

- **Goal:** Add the "Vacuous Definitions (PROHIBITED)" section to the lean4 rules file, identical to the ProofChecker version
- **Tasks:**
  - [ ] Read `.claude/extensions/lean/rules/lean4.md` to confirm current state (no vacuous section)
  - [ ] Append the "Vacuous Definitions (PROHIBITED)" section after the "Literature Fidelity" section:
    ```
    ## Vacuous Definitions (PROHIBITED)

    The following definition patterns are **strictly prohibited** and are semantically equivalent to `sorry`. They create no real proof obligation and will be caught by the Zero-Debt Verification Gate.

    ### Prohibited Patterns

    ```lean
    -- def variants
    def Foo := True
    def Foo := Unit
    def Foo := trivial
    def Foo := Trivial
    noncomputable def Foo := True

    -- theorem variants
    theorem Foo := True
    theorem Foo := trivial
    theorem Foo := Trivial

    -- lemma variants
    lemma Foo := True
    lemma Foo := trivial
    lemma Foo := Trivial

    -- instance variants
    instance Foo := trivial
    instance Foo := True
    ```

    ### Why These Are Prohibited

    - `def X := True` compiles but proves nothing about `X`'s actual semantics
    - `theorem X := trivial` only type-checks when the goal is literally `True`, not the real goal
    - These patterns paper over inability to implement by substituting a semantically empty placeholder
    - They are indistinguishable from `sorry` in terms of proof value: the definition exists but the intent is unfulfilled

    ### What to Do Instead

    If you cannot implement `X`:
    1. Mark the phase **[BLOCKED]** in the plan file
    2. Document the blocker with what was tried, what goal state was reached, and what is needed to unblock
    3. Return `status: "partial"` with `requires_user_review: true`
    4. **Do NOT create `def X := True` or any vacuous placeholder**

    The Escalation Protocol in `lean-implementation-agent.md` specifies the exact procedure.
    ```
- **Timing:** 15 minutes
- **Depends on:** none

### Phase 2: Add Plan Compliance Step to lean-implementation-agent.md [COMPLETED]

- **Goal:** Add step 5 (plan compliance spot-check) to the Final Verification Stage of the agent, so the agent runs the check and records `compliance_check` in metadata
- **Tasks:**
  - [ ] Read `.claude/extensions/lean/agents/lean-implementation-agent.md` Final Verification Stage (lines ~118-193)
  - [ ] After step 4 (`lake build`) and before "Recording Verification Results", add step 5:
    ```markdown
    5. **Plan compliance spot-check**:
       ```bash
       # Extract plan file path
       plan_file=$(ls "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
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
                   if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b" Theories/ 2>/dev/null; then
                       echo "  [OK] $name — found in Theories/"
                   else
                       echo "  [MISSING] $name — not found in Theories/"
                       compliance_failed=true
                   fi
               done
               replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses|supersedes)\s+`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan_file" 2>/dev/null \
                   | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`')
               for replaced in $replacement_targets; do
                   for new_name in $goal_names; do
                       new_file=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${new_name}\b" Theories/ 2>/dev/null | head -1)
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
       Record: `compliance_check` ("passed", "failed", or "skipped")
    ```
  - [ ] In "Recording Verification Results", add `"compliance_check": "$compliance_check"` to the metadata `metadata` block
  - [ ] In "On Verification Failure", add: if `compliance_check == "failed"`, set `status: "partial"`, `review_reason: "Plan compliance check failed"`
- **Timing:** 30 minutes
- **Depends on:** 1

### Phase 3: Add Stage 6b to SKILL.md [COMPLETED]

- **Goal:** Insert Stage 6b (metadata-read compliance check) between Stage 5 and Stage 6 of `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- **Tasks:**
  - [ ] Read SKILL.md to find Stage 5 parse block ending (verify line ~168)
  - [ ] Insert immediately after Stage 5 (the `---` separator after the verification_passed line):
    ```markdown
    ---

    ### Stage 6b: Plan Compliance Check (Read from Metadata)

    **This stage only runs if status from metadata is "implemented".**

    Read the agent-reported compliance result from metadata (agent ran the grep check in Final Verification Stage; SKILL reads the result — MUST NOT re-run grep per postflight-tool-restrictions.md):

    ```bash
    if [ "$status" = "implemented" ]; then
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
    fi
    ```

    **Architecture note**: The `.claude/` skill MUST NOT run grep or shell analysis in postflight (see postflight-tool-restrictions.md). The lean-implementation-agent runs the check during Final Verification Stage and records results in metadata. This stage reads that result only.
    ```
- **Timing:** 20 minutes
- **Depends on:** 2

### Phase 4: Add Section 2b to checkpoint-gate-out.md [COMPLETED]

- **Goal:** Add lean4-specific plan compliance verification hook (section 2b) to `.claude/context/checkpoints/checkpoint-gate-out.md`
- **Tasks:**
  - [ ] Read `.claude/context/checkpoints/checkpoint-gate-out.md` to find section 2 end / section 3 start
  - [ ] Insert section 2b after the existing "### 2. Verify Artifacts Exist" section (before "### 3. Update Status"):
    ```markdown
    ### 2b. Lean4-Specific: Plan Compliance Verification (lean4 / lean task_type only)

    If `task_type` is "lean4" or "lean", verify that the skill's Stage 6b plan compliance check ran and passed:

    ```bash
    # Read compliance result from metadata (backward compatible: absent field = "skipped")
    compliance_status=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

    case "$compliance_status" in
        "failed")
            echo "GATE OUT: Plan compliance check FAILED — plan deliverables not all present or integrity violation detected"
            echo "  Check skill Stage 6b output for missing theorem names or replacement-delegation issues"
            decision="PARTIAL"
            ;;
        "passed")
            echo "GATE OUT: Plan compliance check PASSED"
            ;;
        "skipped"|*)
            echo "INFO: Plan compliance check skipped or not present in metadata — proceeding"
            ;;
    esac
    ```

    If `metadata_file` does not contain the `compliance_check` field (older skill version or non-lean4 task), emit INFO and proceed normally. This section is backward compatible.
    ```
  - [ ] Also check `.claude/extensions/core/context/checkpoints/checkpoint-gate-out.md` and apply the same section 2b if it exists as a separate file
- **Timing:** 20 minutes
- **Depends on:** 3

## Testing & Validation

- [ ] Verify lean4.md has the Vacuous Definitions section by reading the file
- [ ] Verify lean-implementation-agent.md Final Verification Stage has step 5 with compliance_check logic
- [ ] Verify SKILL.md has Stage 6b between Stage 5 and Stage 6
- [ ] Verify checkpoint-gate-out.md has section 2b between sections 2 and 3
- [ ] Confirm all four changes are backward compatible (absent `compliance_check` → "skipped")

## Artifacts & Outputs

- `plans/01_claude-reference-parity-plan.md` (this file)
- `summaries/01_claude-reference-parity-summary.md` (created at completion)
- Modified: `.claude/extensions/lean/rules/lean4.md`
- Modified: `.claude/extensions/lean/agents/lean-implementation-agent.md`
- Modified: `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- Modified: `.claude/context/checkpoints/checkpoint-gate-out.md`

## Rollback/Contingency

- All modified files are in git; `git diff HEAD~1` shows exact changes
- If any phase fails validation, revert via `git checkout HEAD -- <file>`
- No build steps or external services involved; changes are documentation-only
