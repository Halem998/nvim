# Implementation Plan: Index 75 Unindexed Context Files

**Task**: 299 - Index 75 unindexed context files
**Date**: 2026-03-26
**Status**: [COMPLETED]

---

## Overview

Add index.json entries for 75 .md files that exist on disk under `/home/benjamin/Projects/Logos/Website/.claude/context/` but have no entry in index.json. Currently 254 entries exist; target is 329.

## Phase 1: Bulk Index Entry Generation [COMPLETED]

**Description**: Generate and append 75 new entries to index.json using bash/jq.

**Approach**:
1. Find all unindexed files via `comm -23` between disk files and index paths
2. For each file, compute `line_count` via `wc -l`
3. Derive `subdomain` from the directory name (or "root" for root-level files)
4. Set `domain: "core"` for all entries
5. Set `summary: null`, `keywords: []`, `topics: []`, `load_when: { "agents": [], "languages": [], "commands": [] }`
6. Append all entries to index.json in a single jq operation

**Validation**:
- Total entries = 329 (254 + 75)
- No duplicate paths
- All entries have valid domain/subdomain
- JSON is valid and properly formatted

## Phase 2: State and TODO Updates [COMPLETED]

**Description**: Update state.json and TODO.md to reflect completion.

---

## Risk Assessment

- **Low risk**: Additive-only change to index.json
- **Rollback**: `git checkout` on index.json
- **Data safety**: Existing entries preserved; only new entries appended
