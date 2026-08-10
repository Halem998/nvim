# Implementation Plan: Task #583

- **Task**: 583 - port_agent_skill_integration
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task #579 (generate-task-order.sh ported), Task #580 (topic schema ported)
- **Research Inputs**: specs/583_port_agent_skill_integration/reports/01_port-agent-skill.md
- **Artifacts**: plans/01_port-agent-skill.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the remaining topic support into three agent/skill files: `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, and `skill-todo/SKILL.md`. Tasks 579 and 580 already ported `generate-task-order.sh` and the state schema documentation; this task ports the runtime behavior -- how tasks get their `topic` field assigned (meta-builder, fix-it) and how the Task Order section is regenerated after archival (skill-todo). All edits are small and surgical, following exact insertion points identified in the research report.

### Research Integration

The research report performed a line-by-line comparison of the three files against their ProofChecker counterparts, identifying exact insertion points and content for each edit. Key findings:
- `meta-builder-agent.md` needs Topic column in Stage 5 table and topic field + auto-inference prose in Stage 6
- `skill-fix-it/SKILL.md` needs topic auto-inference in Step 9.1 and Topic column in Step 10 display table
- `skill-todo/SKILL.md` needs the entire Stage 10.5 RegenerateTaskOrder block and a commit message update in Stage 15
- Generalization rule: no `.lean`-specific heuristics; use `.claude/` or `specs/` -> "agent-system" mapping

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are directly addressed by this task. The work falls under general "Agent System Quality" improvements but does not match any existing line item.

## Goals & Non-Goals

**Goals**:
- Add topic column to confirmation tables in meta-builder and fix-it
- Add topic auto-inference logic (generalized, extension-aware) to meta-builder and fix-it
- Add `"topic"` field to all state.json entry JSON examples in meta-builder and fix-it
- Add Stage 10.5 RegenerateTaskOrder to skill-todo
- Update skill-todo Stage 15 commit message to reflect task order regeneration
- Ensure all topic inference rules are generalized (no `.lean`-specific heuristics)

**Non-Goals**:
- Porting `/task` Step 4.5 keyword heuristic (not in scope; cross-referenced only)
- Modifying `generate-task-order.sh` (already ported in task 579)
- Modifying state schema documentation (already ported in task 580)
- Adding new topic values beyond "agent-system" for `.claude/`/`specs/` paths

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Cross-reference to `/task` Step 4.5 heuristic that may not exist in this repo | L | M | Use phrasing "keyword heuristic (same as `/task` topic inference)" without hard step number reference |
| Line numbers from research report may have shifted since research was done | M | L | Verify insertion points by matching surrounding context before editing |
| `vault_approved` variable referenced in Stage 10.5 may not be set in all flows | L | L | Post-vault re-run is guarded by conditional; no-op if variable is unset or false |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: meta-builder-agent.md Edits [COMPLETED]

**Goal**: Add Topic column to Stage 5 confirmation table and topic field with auto-inference to Stage 6 state.json entry.

**Tasks**:
- [ ] Edit Stage 5 confirmation table (lines 566-569): add `Topic` column header and `{topic}` cell to both example rows (4 columns -> 5 columns, inserting after Language)
- [ ] Add legend bullet after existing "Dependencies Legend" bullets: `- Topics are auto-inferred from task title/description; user can revise by selecting "Revise"`
- [ ] Insert topic auto-inference prose paragraph before the "**state.json Entry**" heading (after line 673): `**Topic Auto-Inference**: Before building the state.json entry, run the keyword heuristic (same as /task topic inference) against each task's title and description. The inferred topic is shown in the Stage 5 confirmation table (Topic column). If the user selects "Revise", they can change topic assignments.`
- [ ] Update Stage 6 state.json JSON example (lines 676-684): add `"topic": "agent-system"` field after `"task_type"` line
- [ ] Add note after the JSON block: `Note: Include "topic" field only if a topic was inferred or assigned; omit if null/skipped.`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/meta-builder-agent.md` - Stage 5 table and Stage 6 state.json entry

**Verification**:
- Stage 5 table has 5 columns: #, Title, Language, Topic, Effort, Dependencies
- Stage 6 JSON example includes `"topic"` field
- Auto-inference prose paragraph is present before the state.json entry block
- Legend includes the topics auto-inference bullet

---

### Phase 2: skill-fix-it/SKILL.md Edits [COMPLETED]

**Goal**: Add topic auto-inference logic in Step 9.1 and Topic column in Step 10 display table.

**Tasks**:
- [ ] Insert topic auto-inference paragraph after the bash comment block in Step 9.1 (after line 449), before the first JSON example: generalized rules (`.claude/` or `specs/` -> "agent-system", extension paths -> keyword heuristic, same as `/task` topic inference)
- [ ] Update the "has_note_dependency is TRUE" JSON example (lines 452-459): add `"topic": "{auto-inferred topic}"` field after `"task_type"` line
- [ ] Update the "all other tasks" JSON example (lines 462 area): add `"topic": "{auto-inferred topic}"` field after `"task_type"` line
- [ ] Add note after the JSON examples: `Note: Omit "topic" field if topic cannot be inferred (empty string from heuristic).`
- [ ] Update Step 10 display table (lines 506-511): add Topic column header and `{topic}` cells to all 4 example rows (4 columns -> 5 columns)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-fix-it/SKILL.md` - Step 9.1 state.json section and Step 10 display table

**Verification**:
- Step 9.1 has topic auto-inference paragraph with generalized rules (no `.lean` heuristic)
- Both JSON examples include `"topic"` field
- Step 10 display table has 5 columns: #, Type, Title, Language, Topic
- learn-it row shows `agent-system` as topic value

---

### Phase 3: skill-todo/SKILL.md Edits [COMPLETED]

**Goal**: Add Stage 10.5 RegenerateTaskOrder block and update Stage 15 commit message.

**Tasks**:
- [ ] Insert new `<stage id="10.5" name="RegenerateTaskOrder">` block after the Stage 10 closing `</stage>` tag (line 642), before the `<stage id="11"` opening tag (line 644)
- [ ] Stage 10.5 content: action description, process with generate-task-order.sh --update-todo call (non-fatal), post-vault re-run conditional, task_order_regenerated tracking variable, non-fatal note
- [ ] Update Stage 15 step 3 (line 721): add sub-bullet about appending ", regenerate task order" to commit message when task_order_regenerated=true, with example

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - New Stage 10.5 and Stage 15 commit message

**Verification**:
- Stage 10.5 exists between Stage 10 and Stage 11
- generate-task-order.sh call uses correct flags: `--update-todo specs/TODO.md specs/state.json`
- Post-vault re-run is guarded by `vault_approved=true` conditional
- Stage 10.5 is explicitly marked as non-fatal
- Stage 15 step 3 references `task_order_regenerated` and includes example commit message

## Testing & Validation

- [ ] All three files are valid markdown (no broken tables or XML structure)
- [ ] Stage 5 table in meta-builder-agent.md has consistent column count across header, separator, and data rows
- [ ] Step 10 table in skill-fix-it/SKILL.md has consistent column count across all rows
- [ ] Stage 10.5 XML in skill-todo/SKILL.md has matching opening and closing tags
- [ ] No `.lean`-specific heuristics appear in any of the three files' new content
- [ ] All JSON examples are syntactically valid
- [ ] Cross-references use generalized phrasing (not hard-coded step numbers from ProofChecker)

## Artifacts & Outputs

- `specs/583_port_agent_skill_integration/plans/01_port-agent-skill.md` (this plan)
- `.claude/agents/meta-builder-agent.md` (modified)
- `.claude/skills/skill-fix-it/SKILL.md` (modified)
- `.claude/skills/skill-todo/SKILL.md` (modified)

## Rollback/Contingency

All three files are version-controlled. If edits cause issues, revert with `git checkout -- .claude/agents/meta-builder-agent.md .claude/skills/skill-fix-it/SKILL.md .claude/skills/skill-todo/SKILL.md`. Each file edit is independent, so individual files can be reverted without affecting the others.
