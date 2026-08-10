# Implementation Plan: Task #308

- **Task**: 308 - adaptive_context_loading_by_extension_and_language
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/308_adaptive_context_loading_by_extension_and_language/reports/01_context-loading-research.md
- **Artifacts**: plans/01_adaptive-context-loading.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement adaptive context loading to resolve orphaned core index entries. Research discovered the problem is inverted from the task description: empty load_when arrays cause files to NEVER load (not always load), making 95 core entries (~29,373 lines) inaccessible via standard jq queries. The fix requires classifying all core entries with proper load_when conditions, adding validation to prevent future orphaning, and optionally implementing budget-aware loading for prioritization.

### Research Integration

Key findings from research report:
- 95 core entries in core-index-entries.json have completely empty load_when arrays
- Current jq queries use `select(.load_when.agents[]? == "X")` which never matches empty arrays
- Extensions (typst, neovim, founder, present) are well-configured with proper load_when
- Schema already supports `always: true` for universal files
- Combined query pattern needed: `always OR agent-match OR language-match OR command-match`

## Goals & Non-Goals

**Goals**:
- Classify all 95 core index entries with appropriate load_when conditions
- Ensure every context file is discoverable via at least one dimension
- Add validation script to detect entries with all-empty load_when
- Update agent context discovery queries to use combined OR pattern
- Document the load_when classification guidelines

**Non-Goals**:
- Changing jq semantics (empty arrays already correctly mean "never match")
- Implementing real-time budget enforcement (optional enhancement for later)
- Modifying extension index entries (already well-configured)
- Changing the index.json schema structure

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-classification (too broad) | Medium | Medium | Start with narrow matches, expand based on usage |
| Under-classification (too narrow) | High | Medium | Include fallback `always: true` for critical patterns |
| Breaking existing workflows | High | Low | Test queries before regenerating index |
| Large PR from many file changes | Medium | High | Single commit with clear classification rationale |

## Implementation Phases

### Phase 1: Audit and Classify Core Entries [COMPLETED]

**Goal**: Categorize all 95 core index entries into classification buckets

**Tasks**:
- [ ] Extract list of all 95 entries from core-index-entries.json
- [ ] Create classification spreadsheet with columns: path, category, load_when
- [ ] Classify each entry into one of: universal (always:true), agent-specific, language-specific, command-specific
- [ ] Document classification rationale for each category

**Timing**: 1.5 hours

**Files to analyze**:
- `.claude/context/core-index-entries.json` - Source of 95 entries
- `.claude/context/` subdirectories - Context to understand file purposes
- `.claude/agents/` - Reference for agent names
- `.claude/commands/` - Reference for command names

**Verification**:
- Every entry has at least one non-empty load_when dimension OR always:true
- Classification rationale is documented

**Classification Guidelines**:

| Category | Criteria | Example load_when |
|----------|----------|-------------------|
| Universal | Critical patterns, core schemas, README | `{"always": true}` |
| Agent-specific | Agent instruction files, agent-related patterns | `{"agents": ["planner-agent"]}` |
| Language-specific | Language standards, tool references | `{"languages": ["neovim", "lua"]}` |
| Command-specific | Command-related guides, workflows | `{"commands": ["/research", "/plan"]}` |
| Multi-dimension | Applies to multiple categories | `{"agents": [...], "languages": [...]}` |

---

### Phase 2: Update Core Index Entries [COMPLETED]

**Goal**: Apply classifications to core-index-entries.json

**Tasks**:
- [ ] Backup current core-index-entries.json
- [ ] Update each entry with classified load_when
- [ ] Validate JSON syntax after each batch of updates
- [ ] Run jq query tests to verify entries are now discoverable

**Timing**: 1 hour

**Files to modify**:
- `.claude/context/core-index-entries.json` - Add load_when to all 95 entries

**Verification**:
- `jq '[.entries[] | select((.load_when.agents | length) == 0 and (.load_when.languages | length) == 0 and (.load_when.commands | length) == 0 and (.load_when.always == true | not))] | length'` returns 0
- Sample queries return expected entries

---

### Phase 3: Create Validation Script [COMPLETED]

**Goal**: Add tooling to prevent future orphaned entries

**Tasks**:
- [ ] Create `.claude/scripts/validate-index.sh` with checks:
  - Warn on entries with all-empty load_when (and no always:true)
  - Verify all paths exist
  - Check for duplicate paths
  - Report budget estimates per agent/language
- [ ] Add script to extension installation workflow
- [ ] Document validation in context discovery patterns

**Timing**: 45 minutes

**Files to create**:
- `.claude/scripts/validate-index.sh` - New validation script

**Files to modify**:
- `.claude/scripts/install-extension.sh` - Add validation call
- `.claude/context/patterns/context-discovery.md` - Document validation

**Verification**:
- Running script on current index reports no orphaned entries
- Running script on index with orphaned entry produces warning

---

### Phase 4: Update Agent Query Patterns [COMPLETED]

**Goal**: Ensure agents use combined OR query pattern

**Tasks**:
- [ ] Audit agent files for context discovery queries
- [ ] Update queries to use combined pattern:
  ```bash
  jq -r '.entries[] |
    select(
      (.load_when.always == true) or
      (.load_when.agents[]? == $agent) or
      (.load_when.languages[]? == $lang) or
      (.load_when.commands[]? == $cmd)
    ) | .path'
  ```
- [ ] Update context-discovery.md with new recommended patterns
- [ ] Update CLAUDE.md quick reference if needed

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/*.md` - Update context discovery sections
- `.claude/context/patterns/context-discovery.md` - Document combined pattern
- `.claude/CLAUDE.md` - Update context discovery quick reference

**Verification**:
- Sample combined query returns always + agent + language + command matches
- No hardcoded single-dimension queries remain in agents

---

### Phase 5: Regenerate and Test Index [COMPLETED]

**Goal**: Rebuild index.json and verify full system operation

**Tasks**:
- [ ] Run extension installer to regenerate merged index.json
- [ ] Run validation script to confirm no orphaned entries
- [ ] Test context loading for sample task languages (meta, neovim, typst)
- [ ] Verify line counts are reasonable per category

**Timing**: 30 minutes

**Files to verify**:
- `.claude/context/index.json` - Regenerated merged index
- Extension index entries - Preserved during merge

**Verification**:
- Validation script passes with no warnings
- Query for `language=meta` returns expected entries
- Query for `always=true` returns universal entries
- Total line count per agent/language is documented

## Testing & Validation

- [ ] All 95 core entries have non-empty load_when OR always:true
- [ ] Validation script detects orphaned entries in test case
- [ ] Combined query pattern returns entries from all dimensions
- [ ] Sample task (meta, neovim, typst) loads appropriate context
- [ ] No regression in existing extension context loading

## Artifacts & Outputs

- `plans/01_adaptive-context-loading.md` - This implementation plan
- `.claude/context/core-index-entries.json` - Updated with load_when
- `.claude/scripts/validate-index.sh` - New validation script
- `.claude/context/patterns/context-discovery.md` - Updated documentation
- `summaries/02_adaptive-context-loading-summary.md` - Implementation summary (after completion)

## Rollback/Contingency

If implementation causes issues:
1. Restore core-index-entries.json from git backup
2. Re-run extension installer to regenerate index.json
3. Revert agent file changes
4. Remove validation script

All changes are additive to load_when (no existing conditions removed), so rollback is low-risk.
