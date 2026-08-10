# Implementation Plan: Task #705

- **Task**: 705 - Create Build Cache Strategy Context Document
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/705_create_build_cache_strategy_guide/reports/01_research-build-cache-strategy.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create a new context document `build-cache-strategy.md` in the cslib extension tools directory documenting Mathlib cloud cache architecture, cache invalidation triggers, `lake exe cache get` usage patterns, upstream/main base build strategy, and feature branch workflow. Register the document in `index-entries.json` with appropriate `load_when` targeting the `cslib-implementation-agent` and `pr` language tag. The research report provides a complete content outline ready for transcription.

### Research Integration

The research report (01_research-build-cache-strategy.md) provides:
- Full content outline with all 5 sections and subsections pre-drafted
- Exact `load_when` configuration: `{ "languages": ["cslib", "pr"], "agents": ["cslib-implementation-agent"] }`
- Confirmation that the tool doc style follows H1 title, provenance sentence, H2/H3 sections, fenced bash blocks, Quick Reference table pattern
- Placement decision: `project/cslib/tools/build-cache-strategy.md` alongside lake-commands.md and linters.md

## Goals & Non-Goals

**Goals**:
- Create build-cache-strategy.md with all 5 content sections from research outline
- Register in index-entries.json matching existing entry patterns
- Fill the documented gap in cslib tool documentation for `lake exe cache get` and Mathlib cloud cache

**Non-Goals**:
- Modifying lake-commands.md to cross-reference the new document (out of scope for this task)
- Adding hard-mode agent entries (research determined this is unnecessary)
- Adding cslib-research-agent to load_when (cache strategy is implementation-phase knowledge)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error in index-entries.json | M | L | Validate with jq after editing |
| Content diverges from established tool doc style | L | L | Follow lake-commands.md structure exactly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create build-cache-strategy.md [COMPLETED]

**Goal**: Write the complete context document with all 5 content sections following the cslib tool doc style.

**Tasks**:
- [ ] Create file at `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md`
- [ ] Write H1 title and provenance sentence
- [ ] Write section: `## Mathlib Cloud Cache Architecture` (what `lake exe cache get` does, effect on build, when it works, time savings)
- [ ] Write section: `## Cache Invalidation Triggers` (4 triggers: toolchain change, Mathlib bump, branch divergence, local corruption)
- [ ] Write section: `## lake exe cache get Usage Patterns` with H3 subsections (When to Run, Command, Interaction with lake build, Expected Time)
- [ ] Write section: `## Upstream/Main Base Build Strategy` with H3 subsections (Problem, Strategy: Maintain a Built Upstream/Main Checkout, Using as Feature Branch Foundation)
- [ ] Write section: `## Feature Branch Workflow` with H3 subsections (Cache-Safe Branch Creation, Two Mitigation Strategies for Fork-Based Branches)
- [ ] Write `## Quick Reference` table (Scenario | Action format)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md` - NEW file, ~100-130 lines

**Verification**:
- File exists at the expected path
- Contains all 5 H2 sections plus Quick Reference table
- Fenced bash blocks for all commands
- Follows same style as lake-commands.md (H1, provenance, H2/H3 hierarchy)

---

### Phase 2: Register in index-entries.json [COMPLETED]

**Goal**: Add the new document entry to the cslib extension index with correct metadata and load_when configuration.

**Tasks**:
- [ ] Add new entry to the `entries` array in `.claude/extensions/cslib/index-entries.json`
- [ ] Set path: `project/cslib/tools/build-cache-strategy.md`
- [ ] Set description: `CSLib build cache strategy: Mathlib cloud cache, lake exe cache get, feature branch workflow`
- [ ] Set tags: `["cslib", "cache", "lake", "build", "mathlib"]`
- [ ] Set load_when: `{ "languages": ["cslib", "pr"], "agents": ["cslib-implementation-agent"] }`
- [ ] Set domain: `"project"`, subdomain: `"cslib"`
- [ ] Set summary matching description
- [ ] Validate JSON with `jq . index-entries.json`

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/index-entries.json` - Add one entry to the entries array

**Verification**:
- `jq . .claude/extensions/cslib/index-entries.json` parses without error
- New entry is present with correct load_when, path, and tags
- Entry count is now 14 (was 13)

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm the new document integrates correctly with the context discovery system.

**Tasks**:
- [ ] Verify the file is discoverable via context index query for `cslib-implementation-agent`
- [ ] Verify the file is discoverable via `pr` language query
- [ ] Confirm no duplicate paths or conflicting entries
- [ ] Verify document content covers all 5 topics from the research report

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- `jq` query for cslib-implementation-agent returns the new path
- `jq` query for pr language returns the new path
- Document has correct section structure matching research outline

## Testing & Validation

- [ ] `jq . .claude/extensions/cslib/index-entries.json` succeeds (valid JSON)
- [ ] `jq '.entries | length' .claude/extensions/cslib/index-entries.json` returns 14
- [ ] Context query for agent `cslib-implementation-agent` includes `build-cache-strategy.md`
- [ ] Context query for language `pr` includes `build-cache-strategy.md`
- [ ] build-cache-strategy.md contains all 5 content sections from research outline

## Artifacts & Outputs

- `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md` - New context document
- `.claude/extensions/cslib/index-entries.json` - Updated with new entry

## Rollback/Contingency

- Delete `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md`
- Revert the added entry in `index-entries.json` (remove the last entry from the array)
- Both changes are additive-only, so rollback is straightforward with `git checkout`
