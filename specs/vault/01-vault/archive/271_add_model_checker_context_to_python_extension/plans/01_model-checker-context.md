# Implementation Plan: Task 271

- **Task**: 271 - Add ModelChecker domain context files to Python extension
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_model-checker-context.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Replace generic placeholder files in the Python extension's domain directory with project-specific ModelChecker context files. The source files (`model-checker-api.md` and `theory-lib-patterns.md`) exist in the ModelChecker repository and need to be copied to the extension, replacing the current generic `application-api-patterns.md` and `library-patterns.md`. The index-entries.json and README.md must be updated to reference the new filenames.

## Goals & Non-Goals

**Goals**:
- Copy ModelChecker domain context files to Python extension
- Remove generic placeholder files
- Update index-entries.json with new file references
- Update README.md to reference new domain files

**Non-Goals**:
- Modifying the source files in ModelChecker repo
- Adding new context categories beyond domain replacement
- Changing other extension files (patterns/, standards/)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Source files missing | M | L | Verify files exist before copy |
| Index entry syntax error | M | L | Validate JSON after edit |
| Broken cross-references | L | L | Grep for old filenames after removal |

## Implementation Phases

### Phase 1: Copy Source Files [COMPLETED]

**Goal**: Copy ModelChecker domain files to Python extension

**Tasks**:
- [ ] Verify source files exist in ModelChecker repo
- [ ] Copy `model-checker-api.md` to extension domain directory
- [ ] Copy `theory-lib-patterns.md` to extension domain directory

**Timing**: 10 minutes

**Files to modify**:
- `~/.config/nvim/.claude/extensions/python/context/project/python/domain/model-checker-api.md` - Create (copy from source)
- `~/.config/nvim/.claude/extensions/python/context/project/python/domain/theory-lib-patterns.md` - Create (copy from source)

**Verification**:
- Both new files exist in target directory
- File contents match source

---

### Phase 2: Remove Old Files [COMPLETED]

**Goal**: Remove generic placeholder files that are being replaced

**Tasks**:
- [ ] Delete `application-api-patterns.md`
- [ ] Delete `library-patterns.md`

**Timing**: 5 minutes

**Files to modify**:
- `~/.config/nvim/.claude/extensions/python/context/project/python/domain/application-api-patterns.md` - Delete
- `~/.config/nvim/.claude/extensions/python/context/project/python/domain/library-patterns.md` - Delete

**Verification**:
- Old files no longer exist
- No dangling references in other files

---

### Phase 3: Update index-entries.json [COMPLETED]

**Goal**: Update extension index to reference new domain files

**Tasks**:
- [ ] Replace `application-api-patterns.md` entry with `model-checker-api.md`
- [ ] Replace `library-patterns.md` entry with `theory-lib-patterns.md`
- [ ] Update descriptions and tags for new files
- [ ] Validate JSON syntax

**Timing**: 15 minutes

**Files to modify**:
- `~/.config/nvim/.claude/extensions/python/index-entries.json` - Update two entries

**Verification**:
- JSON parses without error
- New file paths are correct relative paths
- Tags and descriptions match file content

---

### Phase 4: Update README.md [COMPLETED]

**Goal**: Update extension README to document new domain files

**Tasks**:
- [ ] Update Key Files section with new filenames
- [ ] Update loading recommendations for research/implementation
- [ ] Ensure structure section accurately reflects domain contents

**Timing**: 10 minutes

**Files to modify**:
- `~/.config/nvim/.claude/extensions/python/context/project/python/README.md` - Update references

**Verification**:
- All referenced files exist
- Loading recommendations are accurate
- No references to old filenames remain

---

### Phase 5: Final Verification [COMPLETED]

**Goal**: Validate complete replacement with no broken references

**Tasks**:
- [ ] Grep for old filenames across entire extension directory
- [ ] Verify all 4 domain files in directory are intentional
- [ ] Test extension loading (if applicable)

**Timing**: 5 minutes

**Verification**:
- No references to `application-api-patterns.md` or `library-patterns.md`
- Domain directory contains exactly: `model-checker-api.md`, `theory-lib-patterns.md`
- Extension structure is coherent

## Testing & Validation

- [ ] Both new domain files exist and contain expected content
- [ ] Old placeholder files are removed
- [ ] index-entries.json validates as proper JSON
- [ ] README.md references correct filenames
- [ ] No orphan references to old filenames in extension

## Artifacts & Outputs

- plans/01_model-checker-context.md (this file)
- summaries/01_model-checker-context-summary.md (post-implementation)

## Rollback/Contingency

If implementation fails:
1. Restore deleted files from git (`git checkout -- <files>`)
2. Remove newly added files
3. Revert index-entries.json and README.md changes
4. Task returns to [PLANNED] status for retry
