# Implementation Plan: Task #209

- **Task**: 209 - create_extension_metadata
- **Status**: [COMPLETED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None (Task 204-208 context files should exist first for full verification)
- **Research Inputs**: [01_extension-metadata-research.md](../reports/01_extension-metadata-research.md)
- **Artifacts**: plans/02_extension-metadata-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The grant extension metadata files (EXTENSION.md and index-entries.json) already exist and follow established conventions from other extensions. This implementation plan focuses on verification, line count accuracy updates, and ensuring all referenced context files exist. The index-entries.json references 16 context files that need to be verified.

### Research Integration

Key findings from the research report:
- EXTENSION.md contains all required sections (language routing, skill-agent mapping, workflow, components, context imports)
- index-entries.json uses canonical `project/grant/` paths correctly
- manifest.json merge_targets are properly configured for `<leader>ac` loader integration
- Verification should ensure line_count values in index-entries.json match actual file sizes

## Goals & Non-Goals

**Goals**:
- Verify EXTENSION.md contains all required sections per extension conventions
- Verify index-entries.json entries use canonical paths and proper load_when conditions
- Update line_count values in index-entries.json to match actual file sizes (if context files exist)
- Identify any missing context files referenced in index-entries.json
- Ensure manifest.json merge_targets are correctly configured

**Non-Goals**:
- Creating the actual context files (that is Task 204-208 scope)
- Modifying the grant-agent or skill-grant definitions
- Testing the full extension loading workflow

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context files don't exist yet | Medium | Medium | Document missing files, defer line_count updates until files exist |
| EXTENSION.md missing sections | Low | Low | Add any missing sections following nvim extension pattern |
| Path format inconsistencies | Low | Low | Normalize paths to canonical format |

## Implementation Phases

### Phase 1: Verify EXTENSION.md Structure [COMPLETED]

**Goal**: Confirm EXTENSION.md contains all required sections per extension conventions

**Tasks**:
- [ ] Read current EXTENSION.md content
- [ ] Verify presence of required sections:
  - [ ] Extension title and description
  - [ ] Language Routing table
  - [ ] Skill-Agent Mapping table
  - [ ] Context Imports section with @-references
- [ ] Compare structure against nvim/nix/latex extensions for consistency
- [ ] Document any missing or non-standard sections

**Timing**: 15 minutes

**Files to examine**:
- `.claude/extensions/grant/EXTENSION.md` - Current file
- `.claude/extensions/nvim/EXTENSION.md` - Reference pattern

**Verification**:
- All required sections present
- Markdown formatting is correct
- @-references use correct paths

---

### Phase 2: Verify index-entries.json Schema [COMPLETED]

**Goal**: Confirm all 16 entries follow the correct schema with canonical paths

**Tasks**:
- [ ] Read current index-entries.json content
- [ ] Verify each entry has required fields:
  - [ ] path (canonical format: `project/grant/...`)
  - [ ] domain, subdomain
  - [ ] topics, keywords (arrays)
  - [ ] summary (string)
  - [ ] line_count (number)
  - [ ] load_when with languages/agents/commands
- [ ] Check for path format consistency (no `.claude/context/` prefix)
- [ ] Verify load_when conditions reference `grant` language and `grant-agent`

**Timing**: 15 minutes

**Files to examine**:
- `.claude/extensions/grant/index-entries.json` - Current file
- `.claude/extensions/nvim/index-entries.json` - Reference pattern

**Verification**:
- All entries pass schema validation
- Paths use canonical format
- No duplicate entries

---

### Phase 3: Cross-Reference Context Files [COMPLETED]

**Goal**: Verify context files exist and update line_count values

**Tasks**:
- [ ] List all paths from index-entries.json
- [ ] Check existence of each referenced file in `.claude/context/project/grant/`
- [ ] For existing files: count actual lines and compare to line_count
- [ ] Document any missing files (expected if Tasks 204-208 not complete)
- [ ] Update line_count values for any files that exist

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/grant/index-entries.json` - Update line_count if needed

**Verification**:
- File existence documented
- Line counts match actual files (for existing files)
- Missing files noted in summary

---

### Phase 4: Verify manifest.json Integration [COMPLETED]

**Goal**: Confirm merge_targets are correctly configured

**Tasks**:
- [ ] Read current manifest.json
- [ ] Verify claudemd merge_target points to EXTENSION.md
- [ ] Verify index merge_target points to index-entries.json
- [ ] Verify section_id is unique (`extension_grant`)
- [ ] Check target paths are correct

**Timing**: 10 minutes

**Files to examine**:
- `.claude/extensions/grant/manifest.json` - Current file

**Verification**:
- Both merge_targets configured
- section_id is unique
- Source files exist

## Testing & Validation

- [ ] All required sections present in EXTENSION.md
- [ ] All index-entries.json entries have correct schema
- [ ] Canonical paths used consistently (no `.claude/context/` prefix)
- [ ] manifest.json merge_targets correctly configured
- [ ] Line counts match actual file sizes (where files exist)

## Artifacts & Outputs

- `specs/209_create_extension_metadata/plans/02_extension-metadata-plan.md` (this file)
- `specs/209_create_extension_metadata/summaries/03_extension-metadata-summary.md` (after implementation)
- Updated `.claude/extensions/grant/index-entries.json` (if line_count corrections needed)

## Rollback/Contingency

If modifications cause issues:
- Revert index-entries.json to original state via git
- EXTENSION.md and manifest.json should remain unchanged
- No destructive operations in this task
