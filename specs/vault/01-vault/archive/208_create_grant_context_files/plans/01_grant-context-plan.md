# Implementation Plan: Task #208

- **Task**: 208 - Create grant context files for domain knowledge
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: Task 204 (grant extension scaffold)
- **Research Inputs**: [01_grant-context-patterns.md](../reports/01_grant-context-patterns.md)
- **Artifacts**: plans/01_grant-context-plan.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Create 14 context files for grant writing domain knowledge, organized into domain/, patterns/, standards/, templates/, and tools/ subdirectories. Files will be progressively loaded by the grant-agent based on task needs. The structure follows established extension context patterns from lean, latex, and filetypes extensions.

### Research Integration

Key findings from research report 01_grant-context-patterns.md:
- Directory structure follows `context/project/{domain}/` convention with domain/, patterns/, standards/, templates/, tools/ subdirectories
- Line count targets: domain files 50-100 lines, pattern files 80-150 lines, template files 100-200 lines
- Three-stage progressive loading for context budget management (~1,460 lines total)
- Index entries must specify `grant-agent` in `load_when.agents` for automatic discovery

## Goals & Non-Goals

**Goals**:
- Create all 14 context files with appropriate content
- Update README.md with navigation links to all files
- Update index-entries.json with entries for all files
- Follow established context file format standards

**Non-Goals**:
- Creating actual grant proposals (files provide templates only)
- Implementing grant-agent logic (covered by separate task)
- Creating funder-specific detailed guides (files provide patterns)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context files too large for agent window | High | Low | Target 60-150 lines per file; split if needed |
| Funder requirements outdated | Medium | Medium | Focus on patterns over specifics; link to official guides |
| Missing key grant writing concepts | Medium | Low | Research report provides comprehensive coverage |
| Template examples not applicable | Low | Medium | Use generic examples; note specifics vary by funder |

## Implementation Phases

### Phase 1: Create Domain Files [COMPLETED]

**Goal**: Establish foundational grant domain knowledge files

**Tasks**:
- [ ] Create `domain/funder-types.md` (~80 lines) - AI Safety, SBIR, Foundation, Academic funders
- [ ] Create `domain/proposal-components.md` (~100 lines) - Standard sections and purposes
- [ ] Create `domain/grant-terminology.md` (~60 lines) - Key terms and definitions

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/domain/funder-types.md`
- `.claude/extensions/grant/context/project/grant/domain/proposal-components.md`
- `.claude/extensions/grant/context/project/grant/domain/grant-terminology.md`

**Verification**:
- All 3 files exist with appropriate content
- Files follow context file format (H1 title, structure section, examples, best practices)

---

### Phase 2: Create Pattern Files [COMPLETED]

**Goal**: Create reusable structure patterns for grant writing

**Tasks**:
- [ ] Create `patterns/proposal-structure.md` (~120 lines) - Section organization patterns
- [ ] Create `patterns/budget-patterns.md` (~150 lines) - Budget formats by funder type
- [ ] Create `patterns/evaluation-patterns.md` (~100 lines) - Logic models and evaluation plans
- [ ] Create `patterns/narrative-patterns.md` (~80 lines) - Writing patterns for impact statements

**Timing**: 40 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/patterns/proposal-structure.md`
- `.claude/extensions/grant/context/project/grant/patterns/budget-patterns.md`
- `.claude/extensions/grant/context/project/grant/patterns/evaluation-patterns.md`
- `.claude/extensions/grant/context/project/grant/patterns/narrative-patterns.md`

**Verification**:
- All 4 files exist with appropriate content
- Budget patterns cover NSF, NIH, Foundation, and SBIR formats
- Evaluation patterns include logic model template

---

### Phase 3: Create Standards Files [COMPLETED]

**Goal**: Establish grant writing style guides and reference material

**Tasks**:
- [ ] Create `standards/writing-standards.md` (~100 lines) - Grant writing style guide
- [ ] Create `standards/character-limits.md` (~60 lines) - Funder-specific limits reference

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/standards/writing-standards.md`
- `.claude/extensions/grant/context/project/grant/standards/character-limits.md`

**Verification**:
- Both files exist with appropriate content
- Writing standards cover active voice, specificity, measurable objectives
- Character limits include NSF, NIH, and common foundation limits

---

### Phase 4: Create Template Files [COMPLETED]

**Goal**: Provide ready-to-use templates for common grant sections

**Tasks**:
- [ ] Create `templates/executive-summary.md` (~120 lines) - Executive summary template
- [ ] Create `templates/budget-justification.md` (~150 lines) - Budget justification templates
- [ ] Create `templates/evaluation-plan.md` (~100 lines) - Evaluation plan template
- [ ] Create `templates/submission-checklist.md` (~80 lines) - Pre-submission checklist

**Timing**: 40 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/templates/executive-summary.md`
- `.claude/extensions/grant/context/project/grant/templates/budget-justification.md`
- `.claude/extensions/grant/context/project/grant/templates/evaluation-plan.md`
- `.claude/extensions/grant/context/project/grant/templates/submission-checklist.md`

**Verification**:
- All 4 files exist with appropriate content
- Templates include fill-in sections and example text
- Budget justification covers personnel, equipment, travel, other direct costs

---

### Phase 5: Create Tools Files [COMPLETED]

**Goal**: Provide tool integration guides for grant writing

**Tasks**:
- [ ] Create `tools/funder-research.md` (~100 lines) - How to research funders
- [ ] Create `tools/web-resources.md` (~60 lines) - Useful grant writing resources

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/tools/funder-research.md`
- `.claude/extensions/grant/context/project/grant/tools/web-resources.md`

**Verification**:
- Both files exist with appropriate content
- Funder research covers identifying funders, analyzing priorities, reading past grants
- Web resources include grant databases, funder websites, writing resources

---

### Phase 6: Update README and Index [COMPLETED]

**Goal**: Update navigation and context discovery files

**Tasks**:
- [ ] Update `README.md` with links to all new files
- [ ] Update `index-entries.json` with entries for all 14 files

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/grant/context/project/grant/README.md`
- `.claude/extensions/grant/index-entries.json`

**Verification**:
- README.md contains navigation links to all subdirectories and files
- index-entries.json contains entries for all 14 files plus README
- Each index entry has path, description, tags, and load_when with grant language and grant-agent

## Testing & Validation

- [ ] Verify all 14 context files exist in correct locations
- [ ] Verify README.md contains links to all files
- [ ] Verify index-entries.json contains all entries with correct schema
- [ ] Verify total line count is approximately 1,460 lines (within context budget)
- [ ] Verify files follow established format (H1 title, sections, examples)

## Artifacts & Outputs

- plans/01_grant-context-plan.md (this file)
- summaries/02_grant-context-summary.md (on completion)
- 14 context files in `.claude/extensions/grant/context/project/grant/`
- Updated README.md
- Updated index-entries.json

## Rollback/Contingency

If implementation fails:
1. Delete any partially created context files
2. Restore README.md and index-entries.json from git
3. Task can be resumed from the incomplete phase

All changes are additive and do not modify existing grant extension functionality.
