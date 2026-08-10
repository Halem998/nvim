---
task: 564
type: research
date: 2026-05-13
status: complete
---

# Research Report: Lean Agent Escalation Protocol and Vacuous-Definition Prohibition

## Summary

- The ProofChecker `.opencode/agent/subagents/lean-implementation-agent.md` has a "Proof Stuck" handler that saves progress and returns partial, but **no explicit escalation protocol** — it does not require [BLOCKED] status or documented blocker text.
- The agent's MUST NOT list already prohibits `sorry` and `admit`, but **does not mention vacuous definitions** (`def X := True`, `def X := Unit`) as a prohibited pattern.
- The `.opencode/rules/lean4.md` file has no vacuous-definition rule and no escalation rule.
- The `.opencode/skills/skill-lean-implementation/SKILL.md` GATE IN has no complexity warning for high-effort plans; the commit at Stage 9 is a single batch commit, not phase-granular.
- The `.claude/` reference agent (`extensions/lean/agents/lean-implementation-agent.md`) has the same gaps — it is the upstream template from which the ProofChecker agent was derived, so both need updating.
- The `.claude/agents/general-implementation-agent.md` **does** have a Phase Checkpoint Protocol with per-phase git commits; this pattern should be ported to the lean agent.

---

## Findings

### 1. Current `lean-implementation-agent.md` State (ProofChecker .opencode)

**File**: `/home/benjamin/Projects/ProofChecker/.opencode/agent/subagents/lean-implementation-agent.md`

#### Zero-Debt Completion Gate (lines 117–148)

The gate checks for sorries, new axioms, and build pass before allowing "implemented" status. Crucially it does NOT check for vacuous definitions.

```markdown
## Zero-Debt Completion Gate (MANDATORY)
...
1. Check for sorries in modified files (grep -n "\bsorry\b")
2. Check for new axioms (grep -n "^axiom ")
3. Verify build passes (lake build)

### On Verification Failure
1. Do NOT return "implemented" status
2. Set status: "partial" with requires_user_review: true
3. Include review_reason ...
```

#### MUST NOT Rules (lines 219–232)

```markdown
**MUST NOT**:
5. Create empty or placeholder proofs (sorry, admit) or introduce axioms
12. Defer sorry resolution to a follow-up task
```

**Gap**: No mention of vacuous definitions (`def X := True`, `def X := Unit`, `def X := Trivial`). These are semantically equivalent to introducing a sorry but pass the sorry-grep check.

#### Proof Stuck Handling (lines 177–182)

```markdown
### Proof Stuck
When proof cannot be completed after multiple attempts:
1. Save partial progress (do not delete)
2. Document current proof state via lean_goal
3. Return partial with what was proven and current goal state
```

**Gap**: No requirement to mark phase [BLOCKED] specifically. No requirement to document a structured blocker (what was attempted, why it failed). No prohibition on papering over with a vacuous definition. The text says "return partial" but does not specify the metadata structure or that it must be `status: "partial"` (not `"implemented"`).

#### Phase Status Updates (lines 65–87)

The agent marks phases [IN PROGRESS], [COMPLETED], or [PARTIAL]/[BLOCKED] via Edit tool — the latter two are mentioned as options but no explicit protocol is given for when to use [BLOCKED] vs [PARTIAL].

#### Phase-Granular Commits

**Complete absence**: The ProofChecker lean agent has no Phase Checkpoint Protocol. There is no instruction to commit after each phase. The only git commit happens in the skill's Stage 9 (one batch commit at the end).

#### GATE IN Complexity Warning

**Complete absence**: Neither the skill's Stage 1 (input validation) nor GATE IN checks estimated effort. There is no warning for plans with >20h estimated effort.

---

### 2. Current `lean4.md` Rules State

**File**: `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md`

This is a concise reference (55 lines) covering:
- Blocked MCP tools (lean_diagnostic_messages, lean_file_outline)
- Essential MCP tool table
- Search tools and decision tree
- Workflow pattern (lean_goal constantly, lake build)
- Common tactics
- Build commands

**Complete absence** of:
- Vacuous-definition prohibition
- Escalation protocol requirements
- Any `def X := True` or `def X := Unit` warning

---

### 3. Current `skill-lean-implementation/SKILL.md` State

**File**: `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md`

#### Stage 6: Zero-Debt Verification Gate (lines 146–165)

```bash
# Check for sorries in modified files
sorry_count=$(grep -r "\bsorry\b" Theories/ 2>/dev/null | grep -v "^[[:space:]]*--" | wc -l)

# Verify build passes
if ! lake build 2>/dev/null; then
    build_failed=true
fi
```

**Gap**: No check for vacuous definitions (`grep -rn "^def.*:= True\|^def.*:= Unit\|^def.*:= trivial"` or similar).

#### Stage 9: Git Commit (lines 209–222)

Single batch commit at task completion:
```bash
git add Theories/ specs/.../summaries/ specs/.../plans/ specs/TODO.md specs/state.json
git commit -m "task ${task_number}: complete implementation"
```

**Gap**: No per-phase commits. All phases committed as a single unit.

#### GATE IN / Stage 1 (Input Validation)

Validates task exists, status allows implementation, task type is lean/lean4. No check for plan complexity or estimated effort.

---

### 4. Reference `.claude/` Lean Agent

**File**: `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`

This is the upstream template from which the ProofChecker agent was derived. It is nearly identical to the ProofChecker version, with one difference: it uses a more detailed "Final Verification Stage" section with structured `verification` JSON in metadata. It also has the same gaps:
- No escalation protocol for phase blocking
- No vacuous-definition prohibition
- No phase-granular commits
- No complexity warning at GATE IN

Since the ProofChecker agent should stay in sync with this reference, **both files need the same updates**.

---

### 5. Phase-Granular Commit Pattern (from general-implementation-agent.md)

**File**: `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`

The general agent has a clear Phase Checkpoint Protocol (lines 341–357):

```markdown
## Phase Checkpoint Protocol

For each phase in the implementation plan:
1. Read plan file, identify current phase
2. Update phase status to [IN PROGRESS] in plan file
3. Execute phase steps as documented
4. Update phase status to [COMPLETED] or [BLOCKED] or [PARTIAL]
5. Git commit with message: task {N} phase {P}: {phase_name}
   git add -A && git commit -m "task {N} phase {P}: {phase_name}
   Session: {session_id}"
6. Proceed to next phase or return if blocked
```

This pattern should be ported directly to the lean implementation agent. For the lean skill, the batch commit in Stage 9 should be made conditional (only commit if the agent did not already commit per-phase).

---

### 6. Complexity Warning Patterns

No existing GATE IN in any agent or skill checks estimated effort from the plan. The implement command's CHECKPOINT 1 validates: task existence, status, plan existence, and resume point. It does not read the plan's estimated total effort.

A complexity warning would require:
1. Reading the plan file during GATE IN
2. Extracting estimated total effort (e.g., `grep -i "estimated.*effort\|total.*hours\|effort.*total"`)
3. Comparing to a threshold (>20h)
4. Displaying a warning and optionally prompting for confirmation

This is a new pattern with no existing precedent in the `.claude/` or `.opencode/` systems.

---

## Recommendations

### File 1: `lean-implementation-agent.md` (ProofChecker .opencode)

**Add four changes**:

**A. Vacuous-Definition Prohibition** — Add to MUST NOT section:
```markdown
13. **Create vacuous definitions to paper over inability** — Never write:
    - `def X := True` (definition returns trivially true)
    - `def X := Unit` (definition returns unit type as placeholder)
    - `def X := trivial` / `def X := Trivial`
    - Any definition whose body is a placeholder value rather than the actual implementation

    A vacuous definition passes sorry-grep but is semantically equivalent to sorry.
    If you cannot implement X correctly, mark the phase [BLOCKED], not X := True.
```

**B. Vacuous-Definition Check** — Add to Zero-Debt Completion Gate:
```bash
# Check for vacuous definitions
vacuous_count=$(grep -rn "^def.*:= True\|^def.*:= Unit\|^def.*:= trivial\|^noncomputable def.*:= True" Theories/ | wc -l)
# If vacuous_count > 0: Cannot return "implemented" status
```

**C. Formal Escalation Protocol** — Add a new section:
```markdown
## Escalation Protocol (MANDATORY)

When a phase CANNOT be completed properly, you MUST:

1. **Mark the phase [BLOCKED]** in the plan file:
   Edit: "### Phase {P}: {Name} [IN PROGRESS]" -> "### Phase {P}: {Name} [BLOCKED]"

2. **Document the blocker** in a structured way:
   - What you attempted (list of tactics/approaches tried)
   - What the current proof state is (paste lean_goal output)
   - Why the phase cannot be completed (specific technical reason)
   - What would be needed to unblock (missing lemma, different proof strategy, human insight)

3. **Return status: "partial"** (never "implemented") with:
   ```json
   {
     "status": "partial",
     "requires_user_review": true,
     "review_reason": "Phase {P} blocked: {one-line reason}",
     "partial_progress": {
       "stage": "phase_{P}_blocked",
       "details": "{description}",
       "phases_completed": N,
       "phases_total": M,
       "blocked_phase": P,
       "blocker": "{same one-line reason}"
     }
   }
   ```

**NEVER** create a vacuous definition to make a phase appear complete.
**NEVER** return "implemented" if any phase is [BLOCKED].
```

**D. Phase Checkpoint Protocol** — Add the phase-granular commit pattern (porting from general-implementation-agent.md):
```markdown
## Phase Checkpoint Protocol

For each phase in the implementation plan:
1. Mark phase [IN PROGRESS]
2. Execute proof steps
3. Mark phase [COMPLETED], [BLOCKED], or [PARTIAL]
4. Git commit:
   git add -A && git commit -m "task {N} phase {P}: {phase_name}
   Session: {session_id}"
5. Proceed to next phase or return if [BLOCKED]
```

### File 2: `lean4.md` (ProofChecker .opencode rules)

**Add a Vacuous Definitions section**:
```markdown
## Vacuous Definitions (PROHIBITED)

Never write:
- `def X := True` — trivially-true placeholder
- `def X := Unit` — unit-type placeholder
- `def X := trivial` / `Trivial`

These pass sorry-grep but are semantically incorrect.
If you cannot implement X: mark the phase [BLOCKED], not X := True.
```

### File 3: `skill-lean-implementation/SKILL.md` (ProofChecker .opencode)

**Two changes**:

**A. Stage 6: Add Vacuous-Definition Check**:
```bash
# Check for vacuous definitions
vacuous_count=$(grep -rn "^def.*:= True\|^def.*:= Unit\|^def.*:= trivial" Theories/ 2>/dev/null | wc -l)

if [ "$vacuous_count" -gt 0 ] || [ "$sorry_count" -gt 0 ] || [ "$build_failed" = true ]; then
    echo "Zero-debt gate FAILED"
    status="partial"
fi
```

**B. GATE IN: Add Complexity Warning**:
Add after "Load Implementation Plan" step, before dispatching the subagent:
```bash
# Extract estimated total effort from plan
effort_hours=$(grep -i "estimated.*effort\|total.*effort\|effort.*total\|total.*hours" "$plan_path" | grep -o '[0-9]\+' | awk '{sum+=$1} END {print sum}')

if [ "${effort_hours:-0}" -gt 20 ]; then
    echo "[WARN] This plan has an estimated effort of ~${effort_hours}h (>20h threshold)."
    echo "       Consider breaking into smaller sub-tasks or using --team mode."
    echo "       Proceeding with implementation..."
fi
```

Note: This is a warning, not a blocker. The task should proceed regardless.

**C. Stage 9: Make Per-Phase Commits the Norm**

Since the agent will now commit per-phase, the Stage 9 commit should be conditional:
```bash
# Only commit if agent did not already create per-phase commits
if ! git log --oneline -1 | grep -q "phase.*:"; then
    git add -A && git commit -m "task ${task_number}: complete implementation"
fi
```

### File 4: `.claude/extensions/lean/agents/lean-implementation-agent.md`

Apply the same four changes as File 1 (escalation protocol, vacuous prohibition, vacuous check in Zero-Debt Gate, Phase Checkpoint Protocol) to keep the upstream template in sync with the ProofChecker instance.

---

## Risks and Considerations

1. **Vacuous-definition grep precision**: The pattern `^def.*:= True` may miss edge cases (multiline defs, noncomputable defs, `theorem X := True`). The pattern should cover `theorem` and `lemma` keywords too, and be multiline-aware for complex cases. A simpler heuristic: flag any `:= True` or `:= Unit` or `:= trivial` at the end of a definition line.

2. **Phase-granular commits and skill batch commit**: If the agent commits per-phase and the skill also commits at the end, there will be duplicate commits. The Stage 9 commit in the skill should be made conditional or removed if the agent already committed all phases.

3. **Complexity warning threshold**: The 20h threshold requires that plans actually record estimated effort in a parseable format. If plans use varied formats (e.g., "~3h per phase" vs "Total: 25 hours"), extraction will be unreliable. The warning should degrade gracefully if effort cannot be parsed.

4. **[BLOCKED] vs [PARTIAL] semantics**: The current phase status markers include both [BLOCKED] and [PARTIAL] as "exception states" in the task management system. [BLOCKED] should be used for "cannot proceed due to technical inability"; [PARTIAL] for "ran out of time/context but could resume." This distinction should be explicit in the escalation protocol.

5. **Two-file sync burden**: The lean agent exists in both `.opencode/agent/subagents/` and `.claude/extensions/lean/agents/`. These need to be kept in sync. The implementation plan should update both.

---

## References

- `/home/benjamin/Projects/ProofChecker/.opencode/agent/subagents/lean-implementation-agent.md` — Primary target file (232 lines)
- `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md` — Rules file (55 lines)
- `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` — Skill file (264 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md` — Reference upstream template (269 lines)
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` — Source of Phase Checkpoint Protocol pattern (lines 341-357)
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/implement.md` — Implement command GATE IN (no complexity warning)
