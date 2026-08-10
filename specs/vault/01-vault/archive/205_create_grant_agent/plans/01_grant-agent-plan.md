# Implementation Plan: Task #205

- **Task**: 205 - Create grant-agent with research and writing capabilities
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #204 (grant extension scaffold)
- **Research Inputs**: [01_grant-agent-patterns.md](../reports/01_grant-agent-patterns.md)
- **Artifacts**: plans/01_grant-agent-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Create grant-agent.md with capabilities for grant proposal research and writing. The agent will support four primary workflows: funder research, proposal drafting, budget development, and progress tracking. Implementation follows the established subagent pattern with frontmatter, staged execution flow, workflow routing, progressive context loading, and metadata file exchange.

### Research Integration

Key findings from research report:
- Agent should use `model: opus` for deep reasoning requirements
- Tools: WebSearch, WebFetch, Read, Write, Edit (full research + writing capability)
- 8-stage execution flow (Stage 0-7) matching general-research-agent pattern
- Progressive context loading via index.json queries with `load_when.agents == "grant-agent"`
- Return format: brief text summary to console, structured JSON to `.return-meta.json`

## Goals & Non-Goals

**Goals**:
- Create complete grant-agent.md following agent authoring standards
- Implement all four workflow types (funder research, proposal draft, budget develop, progress track)
- Enable progressive context loading from grant extension context files
- Ensure compatibility with skill-grant (task 206) via matching frontmatter
- Include comprehensive error handling with fallback chains

**Non-Goals**:
- Creating actual grant templates (handled by separate context creation)
- Implementing skill-grant (task 206) or /grant command (task 207)
- Creating context files beyond what exists in extension scaffold

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Workflow routing complexity | Medium | Medium | Use clear decision tree matching research report diagram |
| Context file dependencies | Low | Low | Document optional context loading, graceful degradation |
| Integration mismatch with skill-grant | Medium | Low | Follow exact frontmatter pattern from research |
| Large agent file | Low | Medium | Use clear section organization, match general-research-agent structure |

## Implementation Phases

### Phase 1: Agent Structure and Frontmatter [COMPLETED]

**Goal**: Create grant-agent.md file with proper frontmatter and basic structure

**Tasks**:
- [ ] Create `.claude/extensions/grant/agents/grant-agent.md`
- [ ] Add frontmatter: name, description, model: opus
- [ ] Create Overview section with agent metadata table
- [ ] Add IMPORTANT note about metadata file exchange pattern

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/grant/agents/grant-agent.md` - Create new file

**Verification**:
- File exists with valid YAML frontmatter
- Overview section includes Name, Purpose, Invoked By, Return Format

---

### Phase 2: Allowed Tools and Context References [COMPLETED]

**Goal**: Define tool access and context loading patterns

**Tasks**:
- [ ] Create Allowed Tools section with categorized listing
- [ ] Define File Operations tools (Read, Write, Edit, Glob, Grep)
- [ ] Define Web Tools (WebSearch, WebFetch)
- [ ] Create Context References section with on-demand loading
- [ ] Add Dynamic Context Discovery section with index.json queries

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/agents/grant-agent.md` - Add sections

**Verification**:
- All required tools documented
- Context queries use correct jq syntax with `load_when.agents[]? == "grant-agent"`

---

### Phase 3: Execution Flow Stages 0-3 [COMPLETED]

**Goal**: Implement initialization and workflow routing stages

**Tasks**:
- [ ] Stage 0: Initialize Early Metadata (in_progress status)
- [ ] Stage 1: Parse Delegation Context (extract task_context, workflow_type)
- [ ] Stage 2: Determine Grant Workflow (decision tree for 4 workflow types)
- [ ] Stage 3: Load Context (progressive loading via index.json)
- [ ] Add workflow routing table matching research diagram

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/grant/agents/grant-agent.md` - Add execution stages

**Verification**:
- Stage 0 includes early metadata JSON template
- Stage 2 workflow routing covers all 4 types
- Context loading queries are syntactically correct

---

### Phase 4: Execution Flow Stages 4-7 [COMPLETED]

**Goal**: Implement workflow execution, artifact creation, and return format

**Tasks**:
- [ ] Stage 4: Execute Workflow (per-workflow tool usage patterns)
- [ ] Stage 5: Create Artifacts (workflow-specific output paths)
- [ ] Stage 6: Write Metadata File (final status JSON)
- [ ] Stage 7: Return Brief Summary (3-6 bullet text format)
- [ ] Add artifact path patterns table from research

**Timing**: 40 minutes

**Files to modify**:
- `.claude/extensions/grant/agents/grant-agent.md` - Add remaining stages

**Verification**:
- Each workflow has defined artifact output path
- Metadata file JSON template matches return-metadata-file.md schema
- Stage 7 explicitly states NOT to return JSON to console

---

### Phase 5: Error Handling and Critical Requirements [COMPLETED]

**Goal**: Implement comprehensive error handling and requirements lists

**Tasks**:
- [ ] Create Error Handling section with categories (network, timeout, invalid task)
- [ ] Add WebSearch/WebFetch fallback chain
- [ ] Create search fallback chain diagram
- [ ] Add Return Format Examples (success, partial, failed)
- [ ] Create Critical Requirements section (MUST DO / MUST NOT lists)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/grant/agents/grant-agent.md` - Add error handling sections

**Verification**:
- All error categories from research covered
- Fallback chain matches general-research-agent pattern
- MUST DO includes early metadata, metadata file write, brief summary return
- MUST NOT includes JSON console return, skip Stage 0

---

### Phase 6: Verification and Integration Testing [COMPLETED]

**Goal**: Verify agent file is complete and ready for skill-grant integration

**Tasks**:
- [ ] Verify all sections present compared to general-research-agent
- [ ] Check frontmatter matches skill-grant expectations
- [ ] Validate all jq queries are syntactically correct
- [ ] Verify JSON templates are valid
- [ ] Check agent file line count (should be 350-450 lines similar to reference)

**Timing**: 20 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- Agent file has all 8 sections (Overview, Metadata, Tools, Context, Discovery, Execution, Errors, Requirements)
- Frontmatter `name: grant-agent` matches skill-grant `agent: grant-agent`
- All JSON templates pass validation

## Testing & Validation

- [ ] Verify file exists at `.claude/extensions/grant/agents/grant-agent.md`
- [ ] Verify YAML frontmatter parses correctly
- [ ] Verify all jq queries return valid results against sample index.json
- [ ] Verify JSON metadata templates are valid JSON
- [ ] Compare structure against general-research-agent.md (8 major sections)
- [ ] Verify workflow routing table covers all 4 workflow types
- [ ] Verify artifact paths follow `{NNN}_{SLUG}/` directory pattern

## Artifacts & Outputs

- `.claude/extensions/grant/agents/grant-agent.md` - Primary agent definition file
- `specs/205_create_grant_agent/summaries/01_grant-agent-summary.md` - Implementation summary (created on completion)

## Rollback/Contingency

If implementation fails:
1. Delete `.claude/extensions/grant/agents/grant-agent.md` if partially created
2. Keep grant extension scaffold intact (task 204)
3. Re-run `/plan 205` to create revised plan if needed
4. Consider simplifying to 2-3 workflow types if 4 proves too complex
