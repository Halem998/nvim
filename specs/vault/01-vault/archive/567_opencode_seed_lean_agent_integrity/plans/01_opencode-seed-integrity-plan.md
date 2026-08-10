# Implementation Plan: OpenCode Seed Lean Agent Integrity

- **Task**: 567 - opencode_seed_lean_agent_integrity
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 564 (completed), Task 565 (completed)
- **Research Inputs**: specs/567_opencode_seed_lean_agent_integrity/reports/01_opencode-seed-integrity-research.md
- **Artifacts**: plans/01_opencode-seed-integrity-plan.md (this file)
- **Standards**: plan.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Apply all lean agent integrity improvements from tasks 564–565 to the nvim `.opencode/` seed at `~/.config/nvim/.opencode/`. This seed initializes new OpenCode projects via the `<leader>al` picker. Four files need updating: `lean-implementation-agent.md`, `lean4.md`, `SKILL.md`, and `checkpoint-gate-out.md`. All changes mirror the ProofChecker reference with no architectural adaptation needed (OpenCode skills can run grep in postflight).

**Research Integration**: Report `01_opencode-seed-integrity-research.md` provides a complete gap analysis mapping each change to its source file, confirming no adaptation is needed since the `.opencode/` architecture allows grep in skill postflight.

## Goals & Non-Goals

- **Goals**:
  - Add vacuous_count check to Zero-Debt Completion Gate in `lean-implementation-agent.md`
  - Add Escalation Protocol and Phase Checkpoint Protocol sections to `lean-implementation-agent.md`
  - Add item 13 (vacuous prohibition) to MUST NOT in `lean-implementation-agent.md`
  - Add Vacuous Definitions (PROHIBITED) section to `lean4.md`
  - Add Task Complexity Warning to Stage 1 in `SKILL.md`
  - Add vacuous_count check to Stage 6 Zero-Debt Gate in `SKILL.md`
  - Insert Stage 6b (plan compliance spot-check) in `SKILL.md`
  - Replace unconditional Stage 9 commit with conditional (per-phase detection) in `SKILL.md`
  - Add section 2b (lean4 compliance hook) to `checkpoint-gate-out.md`
- **Non-Goals**:
  - Do not modify ProofChecker files (already updated by tasks 564–565)
  - Do not modify `.claude/extensions/lean/` files (handled by task 566)
  - Do not change SKILL.md stage numbering for existing stages

## Risks & Mitigations

- **Risk**: lean-implementation-agent.md Zero-Debt Gate naming differs from ProofChecker ("Zero-Debt Completion Gate" vs "Zero-Debt Verification Gate") → **Mitigation**: Keep existing name, just add vacuous_count step
- **Risk**: SKILL.md Stage 9 conditional commit uses `git log --oneline -10` which may span across sessions → **Mitigation**: Same risk as ProofChecker; acceptable
- **Risk**: Stage 6b grep patterns reference `Theories/` which is specific to Lean project structure → **Mitigation**: This is correct for lean projects; seed is specifically for lean projects
- **Risk**: Inserting Stage 6b may disrupt existing Stage 7+ references → **Mitigation**: Do not renumber; Stage 6b label is additive

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases 1 and 2 (agent and rules) are independent and can execute in parallel. Phase 3 (SKILL) depends on understanding what's in the agent. Phase 4 (checkpoint) is independent but last for logical grouping.

### Phase 1: Update lean-implementation-agent.md [COMPLETED]

- **Goal:** Add all missing items from task 564 to the .opencode/ seed agent: vacuous_count check, escalation protocol, phase checkpoint, item 13
- **Tasks:**
  - [ ] Read `.opencode/extensions/lean/agents/lean-implementation-agent.md` (231 lines) to confirm current state
  - [ ] In Zero-Debt Completion Gate, after sorry check step 1 and before "Check for new axioms", insert step 2:
    ```markdown
    2. **Check for vacuous definitions (PROHIBITED patterns)**:
       ```bash
       vacuous_count=$(grep -rn "^\s*\(noncomputable \)\?\(def\|theorem\|lemma\|instance\).*:= \(True\|Unit\|trivial\|Trivial\)\s*$" Theories/ 2>/dev/null | wc -l)
       ```
       If ANY match: Cannot return "implemented" status. Vacuous definitions are semantically equivalent to sorry.
    ```
  - [ ] Update "On Verification Failure" to mention vacuous definitions alongside sorries
  - [ ] Add `vacuous_count` field to the verification JSON in On Verification Failure documentation
  - [ ] After the Context Management section and before Critical Requirements, insert the Escalation Protocol section (3 steps: mark [BLOCKED], document blocker, return partial)
  - [ ] After Escalation Protocol, insert Phase Checkpoint Protocol section (4 steps: mark [IN PROGRESS], execute, mark [COMPLETED]/[BLOCKED], git commit)
  - [ ] In Critical Requirements MUST NOT list, add item 13 (vacuous prohibition with all patterns and pointer to Escalation Protocol)
- **Timing:** 45 minutes
- **Depends on:** none

### Phase 2: Add Vacuous Definitions Section to lean4.md [COMPLETED]

- **Goal:** Append the "Vacuous Definitions (PROHIBITED)" section to `.opencode/extensions/lean/rules/lean4.md`
- **Tasks:**
  - [ ] Read `.opencode/extensions/lean/rules/lean4.md` to confirm current end of file
  - [ ] Append full Vacuous Definitions section (identical to ProofChecker lean4.md lines 56-98):
    - Section header: `## Vacuous Definitions (PROHIBITED)`
    - Explanation paragraph
    - `### Prohibited Patterns` subsection with Lean code block
    - `### Why These Are Prohibited` subsection (4 bullets)
    - `### What to Do Instead` subsection (4 steps + escalation pointer)
- **Timing:** 15 minutes
- **Depends on:** none

### Phase 3: Update SKILL.md [COMPLETED]

- **Goal:** Add complexity warning, vacuous_count check, Stage 6b, and conditional Stage 9 to `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- **Tasks:**
  - [ ] Read SKILL.md to confirm Stage 1, Stage 6, Stage 9 line positions
  - [ ] In Stage 1 Input Validation, after the plan_file lookup/validation, add Task Complexity Warning subsection:
    ```markdown
    #### Task Complexity Warning (GATE IN)

    After identifying the plan file, extract the estimated effort and warn if total exceeds 20 hours:

    ```bash
    plan_file="specs/${padded_num}_${project_name}/plans/$(ls specs/${padded_num}_${project_name}/plans/ 2>/dev/null | tail -1)"
    if [ -f "$plan_file" ]; then
        effort_line=$(grep -i "Effort\|estimate\|hours\?" "$plan_file" 2>/dev/null | head -5)
        effort_hours=$(echo "$effort_line" | grep -oP '\d+(?=\s*h(our)?s?)' | head -1)
        if [ -n "$effort_hours" ] && [ "$effort_hours" -gt 20 ] 2>/dev/null; then
            echo "WARNING: Task complexity exceeds 20 hours estimated effort (${effort_hours}h)."
            echo "  Consider using /team-implement or breaking into smaller phases."
            echo "  Proceeding with single-agent implementation."
        fi
    fi
    ```

    This warning is non-blocking.
    ```
  - [ ] In Stage 6 Zero-Debt Verification Gate, after sorry_count check and before build check, add vacuous_count check:
    ```bash
    # Check for vacuous definitions (semantically equivalent to sorry)
    vacuous_count=$(grep -rn "^\s*\(noncomputable \)\?\(def\|theorem\|lemma\|instance\).*:= \(True\|Unit\|trivial\|Trivial\)\s*$" Theories/ 2>/dev/null | wc -l)
    ```
    Update the gate failure condition to include `|| [ "$vacuous_count" -gt 0 ]`, and add vacuous_count to the failure message
  - [ ] After Stage 6 (after its `---` separator), insert Stage 6b (Plan Compliance Spot-Check) verbatim from ProofChecker SKILL.md lines 198-268 (Steps 1-4: extract goal names, deliverable existence check, delivery integrity check, record compliance_check)
  - [ ] In Stage 9 Git Commit, replace the unconditional `git add/commit` block with the conditional version:
    ```bash
    # Check if per-phase commits already exist from subagent Phase Checkpoint Protocol
    if git log --oneline -10 | grep -q "phase [0-9]\+:"; then
        echo "Per-phase commits detected — skipping batch commit."
        echo "Phase commits already capture implementation history."
    else
        git add \
          "Theories/" \
          "specs/${padded_num}_${project_name}/summaries/" \
          "specs/${padded_num}_${project_name}/plans/" \
          "specs/TODO.md" \
          "specs/state.json"
        git commit -m "task ${task_number}: complete implementation

    Session: ${session_id}
    "
    fi
    # Always commit state updates
    git add "specs/TODO.md" "specs/state.json" 2>/dev/null || true
    git diff --cached --quiet || git commit -m "task ${task_number}: update task state

    Session: ${session_id}
    "
    ```
- **Timing:** 45 minutes
- **Depends on:** 1, 2

### Phase 4: Add Section 2b to checkpoint-gate-out.md [COMPLETED]

- **Goal:** Add lean4-specific plan compliance verification hook to `.opencode/context/checkpoints/checkpoint-gate-out.md`
- **Tasks:**
  - [ ] Read `.opencode/context/checkpoints/checkpoint-gate-out.md` to confirm section 2 ends and section 3 begins
  - [ ] Insert section 2b between "### 2. Verify Artifacts Exist" and "### 3. Update Status":
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
- **Timing:** 15 minutes
- **Depends on:** 3

## Testing & Validation

- [ ] Verify lean-implementation-agent.md has vacuous_count in Zero-Debt Gate (step 2), Escalation Protocol section, Phase Checkpoint Protocol section, and MUST NOT item 13
- [ ] Verify lean4.md has Vacuous Definitions (PROHIBITED) section at end of file
- [ ] Verify SKILL.md has complexity warning in Stage 1, vacuous_count in Stage 6, Stage 6b after Stage 6, conditional Stage 9
- [ ] Verify checkpoint-gate-out.md has section 2b between sections 2 and 3
- [ ] Confirm all changes are backward compatible (absent `compliance_check` → "skipped", no per-phase commits → batch commit runs normally)

## Artifacts & Outputs

- `plans/01_opencode-seed-integrity-plan.md` (this file)
- `summaries/01_opencode-seed-integrity-summary.md` (created at completion)
- Modified: `.opencode/extensions/lean/agents/lean-implementation-agent.md`
- Modified: `.opencode/extensions/lean/rules/lean4.md`
- Modified: `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- Modified: `.opencode/context/checkpoints/checkpoint-gate-out.md`

## Rollback/Contingency

- All modified files are in git; `git diff HEAD~1` shows exact changes
- If any phase fails, revert via `git checkout HEAD -- <file>`
- No build steps or external services; changes are markdown/text documentation
