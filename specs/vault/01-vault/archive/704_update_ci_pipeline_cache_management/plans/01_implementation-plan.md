# Implementation Plan: Task #704

- **Task**: 704 - Update ci-pipeline.md and lake-commands.md to include Mathlib cache management
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/704_update_ci_pipeline_cache_management/reports/01_research-cache-management.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add Mathlib cache management documentation to two cslib extension context files. Insert a new Step 0 (`lake exe cache get`) in ci-pipeline.md before the existing Step 1, and add a new "Cache Management Commands" section in lake-commands.md before "Build Commands". Both additions emphasize the "once per branch setup" usage pattern and the 30+ minute rebuild avoidance context.

### Research Integration

Research confirmed the exact insertion points, file structures, and content templates. ci-pipeline.md has 7 numbered steps (1-7) with a Quick Reference table; lake-commands.md has 5 command sections plus a Quick Reference table. The new content slots cleanly into both files without disturbing existing content.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Document `lake exe cache get` as Step 0 in the CI pipeline verification order
- Add a Cache Management Commands section to lake-commands.md
- Update both Quick Reference tables with the new cache command entry
- Emphasize the "once per branch setup, not every build" usage pattern

**Non-Goals**:
- Modifying any other CI pipeline steps
- Adding cache invalidation or troubleshooting documentation
- Changing the existing step numbering (Steps 1-7 remain unchanged)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Quick Reference row insertion order ambiguous | L | L | Step 0 row goes first in ci-pipeline.md; cache row goes before `lake build` in lake-commands.md |
| "Once per branch setup" misread as "never again" | M | L | Include `lake update` re-run trigger in both files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add Step 0 to ci-pipeline.md [NOT STARTED]

**Goal**: Insert Step 0 (Cache Setup) and update the Quick Reference table in ci-pipeline.md.

**Tasks**:
- [ ] Insert the following Step 0 section after the "Run these steps in order..." prose paragraph and before `### Step 1: \`lake build\``:

```markdown
### Step 0: `lake exe cache get`

**Purpose**: Download pre-built Mathlib `.olean` files from the Mathlib cache.

Run this once when setting up a new branch that is based on upstream/main. This is
especially critical when the local fork's main has diverged from upstream — without
cache fetching, `lake build` triggers a near-full rebuild of Mathlib (30+ minutes).

```bash
lake exe cache get
```

**When to run**: Once per branch setup, not on every build. Re-run only if switching
to a different Mathlib revision (e.g., after a `lake update`).
```

- [ ] Add a new row to the Quick Reference table as the first data row (before Step 1):

```markdown
| 0 | `lake exe cache get` | Once per branch setup (when based on upstream/main) |
```

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md` - Insert Step 0 section and Quick Reference row

**Verification**:
- Step 0 appears between the intro prose and Step 1
- Quick Reference table has Step 0 as first row
- No existing content is altered

---

### Phase 2: Add Cache Management Commands to lake-commands.md [NOT STARTED]

**Goal**: Insert a new Cache Management Commands section and update the Quick Reference table in lake-commands.md.

**Tasks**:
- [ ] Insert the following section after the header/cross-reference note and before `## Build Commands`:

```markdown
## Cache Management Commands

### `lake exe cache get`

Downloads pre-built Mathlib `.olean` files from the Mathlib S3 cache. Avoids a
near-full Mathlib rebuild (30+ minutes) when working on a branch based on upstream/main
whose local fork's main has diverged.

```bash
lake exe cache get
```

**Usage**: Run once per branch setup. Re-run after `lake update` if the Mathlib revision
changes. Not needed on every build.

**Expected behavior**: Downloads compiled `.olean` artifacts for the pinned Mathlib commit
in `lake-manifest.json`. On success, subsequent `lake build` runs only compile CSLib
itself (seconds to minutes, not 30+ minutes).
```

- [ ] Add a new row to the Quick Reference table as the first data row (before `lake build`):

```markdown
| `lake exe cache get` | Download Mathlib `.olean` cache | Once per branch setup |
```

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md` - Insert Cache Management section and Quick Reference row

**Verification**:
- Cache Management Commands section appears before Build Commands
- Quick Reference table has `lake exe cache get` as first row
- No existing content is altered

---

### Phase 3: Verification [NOT STARTED]

**Goal**: Confirm both files are well-formed and internally consistent.

**Tasks**:
- [ ] Read ci-pipeline.md and verify Step 0 is present, Step 1-7 unchanged, Quick Reference table has 8 rows
- [ ] Read lake-commands.md and verify Cache Management Commands section exists before Build Commands, Quick Reference table has 12 rows
- [ ] Verify cross-references between files still hold (ci-pipeline.md references `tools/lake-commands.md`, lake-commands.md references `standards/ci-pipeline.md`)

**Timing**: 5 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- Both files parse as valid markdown
- All step numbers are consistent
- Cross-references are intact

## Testing & Validation

- [ ] ci-pipeline.md has Step 0 before Step 1 with correct content
- [ ] ci-pipeline.md Quick Reference table includes Step 0 row
- [ ] lake-commands.md has Cache Management Commands section before Build Commands
- [ ] lake-commands.md Quick Reference table includes `lake exe cache get` row
- [ ] No existing content in either file is modified or removed
- [ ] "Once per branch setup" and `lake update` re-run trigger appear in both files

## Artifacts & Outputs

- plans/01_implementation-plan.md (this file)
- Modified: `.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md`
- Modified: `.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md`

## Rollback/Contingency

Both files are git-tracked. Revert with `git checkout -- .claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md .claude/extensions/cslib/context/project/cslib/tools/lake-commands.md` if changes are incorrect.
