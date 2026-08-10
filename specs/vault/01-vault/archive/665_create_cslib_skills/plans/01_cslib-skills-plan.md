# Implementation Plan: Task #665

- **Task**: 665 - Create cslib skills
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 664 (cslib agents)
- **Research Inputs**: specs/665_create_cslib_skills/reports/01_cslib-skills-research.md
- **Artifacts**: plans/01_cslib-skills-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Create two thin-wrapper extension skills (Pattern B, ~83-110 lines each) for the cslib extension. Both follow the nix skills pattern: frontmatter with allowed-tools, prose-only stage descriptions, and delegation to cslib-specific agents. The research skill delegates to cslib-research-agent for Mathlib/Lean 4 pattern research; the implementation skill delegates to cslib-implementation-agent for proof work and includes a MUST NOT postflight boundary section.

### Research Integration

Key findings from research report:
- Pattern B (thin extension) is the correct standard for extension skills
- Nix skills are the reference model (not lean skills which are fat Pattern A)
- allowed-tools should be `Agent, Bash, Edit, Read, Write` (matching nix skills)
- Implementation skill must include `plan_path` and `orchestrator_mode` in delegation context
- MUST NOT section required in implementation skill for postflight boundary enforcement

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create skill-cslib-research/SKILL.md with complete thin-wrapper content
- Create skill-cslib-implementation/SKILL.md with complete thin-wrapper content including MUST NOT section
- Both skills match nix skills pattern (83-110 lines)
- Both skills correctly reference cslib-specific agents and context

**Non-Goals**:
- Creating or modifying the cslib agents themselves (task 664)
- Modifying the cslib manifest (already correct)
- Creating context files for the cslib extension

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| cslib agents still stubs | L | H | Skills are independent of agent content; they name agents only |
| lean-lsp MCP tool names change | L | L | Tools inherited via lean dependency; names stable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create skill-cslib-research/SKILL.md [COMPLETED]

**Goal**: Replace the stub with the full thin-wrapper research skill content

**Tasks**:
- [ ] Write complete SKILL.md to `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Replace stub with full content

**Exact file content**:

```markdown
---
name: skill-cslib-research
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions. Invoke for cslib research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Research Skill

Thin wrapper that delegates CSLib research to `cslib-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "cslib"
- Research is needed for CSLib formalization, Lean 4 proof patterns, or Mathlib API
- CSLib contribution standards or module patterns need to be gathered

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task_type is "cslib".

### Stage 2: Preflight Status Update
Update status to "researching" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the cslib-research-agent:
- lean-lsp MCP tools for Mathlib search (lean_leansearch, lean_loogle, lean_local_search)
- CSLib context files from `.claude/extensions/cslib/context/`
- Local CSLib Lean files for pattern analysis

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-cslib-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "cslib"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-research-agent".

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add research artifact to state.json. Update TODO.md per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
```

**Verification**:
- File has frontmatter with name, description, allowed-tools
- File is under 110 lines
- References cslib-research-agent
- Has delegation_path including "skill-cslib-research"

---

### Phase 2: Create skill-cslib-implementation/SKILL.md [COMPLETED]

**Goal**: Replace the stub with the full thin-wrapper implementation skill content including MUST NOT section

**Tasks**:
- [ ] Write complete SKILL.md to `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Replace stub with full content

**Exact file content**:

```markdown
---
name: skill-cslib-implementation
description: Implement CSLib proofs following Lean 4 and CSLib contribution standards. Invoke for cslib implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Implementation Skill

Thin wrapper that delegates CSLib proof implementation to `cslib-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "cslib"
- /implement command targets a CSLib task
- Lean 4 proofs or CSLib definitions need to be created or modified

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists, task_type is "cslib", and an implementation plan is present.

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the cslib-implementation-agent:
- CSLib coding standards from `.claude/extensions/cslib/context/`
- Verification: `lake build`, `lake test`, `lake lint`, `lake exe checkInitImports`, `lake exe lint-style`, `lake shake`
- lean-lsp MCP tools for proof state inspection (inherited via lean dependency)

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-cslib-implementation"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "cslib"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "orchestrator_mode": true,
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-implementation-agent".

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight)
Update state.json and TODO.md based on result.

### Stage 7: Link Artifacts
Add artifact to state.json with summary. Update TODO.md per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`, `next_field=**Description**`.

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .lean files** - All CSLib proof work is done by agent
2. **Run lake build/test/lint** - Verification is done by agent
3. **Use lean-lsp MCP tools** - Domain tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Return Format

Brief text summary (NOT JSON).
```

**Verification**:
- File has frontmatter with name, description, allowed-tools
- File is under 110 lines
- References cslib-implementation-agent
- Has delegation_path including "skill-cslib-implementation"
- Includes plan_path and orchestrator_mode in delegation context
- Has complete MUST NOT section with 5 prohibitions

---

### Phase 3: Verification [COMPLETED]

**Goal**: Validate both skills meet thin-wrapper Pattern B requirements

**Tasks**:
- [ ] Verify skill-cslib-research/SKILL.md has valid frontmatter (name, description, allowed-tools)
- [ ] Verify skill-cslib-research/SKILL.md is under 110 lines
- [ ] Verify skill-cslib-implementation/SKILL.md has valid frontmatter (name, description, allowed-tools)
- [ ] Verify skill-cslib-implementation/SKILL.md is under 110 lines
- [ ] Verify skill-cslib-implementation/SKILL.md has MUST NOT section with all 5 items
- [ ] Verify both skills reference correct agents (cslib-research-agent, cslib-implementation-agent)
- [ ] Verify implementation skill includes plan_path and orchestrator_mode in delegation JSON

**Timing**: 10 minutes

**Depends on**: 1, 2

**Files to modify**: None (read-only verification)

**Verification**:
- `grep -c "^" .claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` returns <= 110
- `grep -c "^" .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` returns <= 110
- `grep -q "name: skill-cslib-research" .claude/extensions/cslib/skills/skill-cslib-research/SKILL.md`
- `grep -q "name: skill-cslib-implementation" .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `grep -q "MUST NOT" .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `grep -q "orchestrator_mode" .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `grep -q "plan_path" .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`

---

## Testing & Validation

- [ ] Both SKILL.md files have valid YAML frontmatter (name, description, allowed-tools fields)
- [ ] Both files are under 110 lines (Pattern B thin wrapper requirement)
- [ ] Research skill references cslib-research-agent
- [ ] Implementation skill references cslib-implementation-agent
- [ ] Implementation skill has MUST NOT section with 5 prohibitions
- [ ] Implementation skill includes plan_path and orchestrator_mode in delegation context JSON
- [ ] Both delegation contexts have correct delegation_path arrays

## Artifacts & Outputs

- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Complete research skill
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Complete implementation skill

## Rollback/Contingency

Both files currently contain only stub content. If implementation fails, restore the stubs:
```
echo "# skill-cslib-research\n\nStub -- full content created by task #665." > .claude/extensions/cslib/skills/skill-cslib-research/SKILL.md
echo "# skill-cslib-implementation\n\nStub -- full content created by task #665." > .claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md
```
