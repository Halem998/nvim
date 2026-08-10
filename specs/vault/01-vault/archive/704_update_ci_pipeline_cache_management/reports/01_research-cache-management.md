# Research Report: Task #704

**Task**: 704 - Update ci-pipeline.md and lake-commands.md to include Mathlib cache management
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: 0.5h (read-only research, no external sources needed)
**Dependencies**: None
**Sources/Inputs**: Codebase (ci-pipeline.md, lake-commands.md)
**Artifacts**: specs/704_update_ci_pipeline_cache_management/reports/01_research-cache-management.md
**Standards**: report-format.md

## Executive Summary

- ci-pipeline.md has 7 numbered steps (Step 1 through Step 7) plus a Quick Reference table
- lake-commands.md has 5 sections (Build, Test, Lint, Import Management, Import Minimization) plus a Quick Reference table
- The new cache step belongs as Step 0 in ci-pipeline.md (before Step 1: `lake build`), with existing step numbers unchanged
- The new content for lake-commands.md belongs in a new "Cache Management Commands" section inserted before "Build Commands"

## Context & Scope

Task 704 requests additions to two context documentation files in the cslib extension:

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md`

These are markdown documentation files (not Lua code), describing the CI/build workflow for the CSLib Lean 4 library project. The changes add Mathlib `.olean` cache management via `lake exe cache get` to prevent 30+ minute full Mathlib rebuilds when working on a feature branch diverged from upstream.

## Findings

### Codebase Patterns

#### ci-pipeline.md — Current Structure

File: `.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md` (120 lines)

**Sections**:
1. Header with cross-reference note ("Derived from CONTRIBUTING.md and `lakefile.toml`")
2. `## Verification Order` — prose intro
3. Seven numbered steps under `### Step N: <command>` headings:
   - Step 1: `lake build`
   - Step 2: `lake exe checkInitImports`
   - Step 3: `lake lint`
   - Step 4: `lake exe lint-style`
   - Step 5: `lake test`
   - Step 6: `lake exe mk_all --module`
   - Step 7: `lake shake --add-public --keep-implied --keep-prefix`
4. `## Quick Reference` — a 3-column table (Step | Command | When)

**Quick Reference table columns**: `Step`, `Command`, `When`

Each step follows this pattern:
```
### Step N: `<command>`

**Purpose**: <one-line description>.

<prose explaining what it catches, important distinctions>

```bash
<command>
# Optional: variant
<variant command>
```
```

**Step numbering gap**: Currently Steps 1–7 exist. Adding "Step 0" before Step 1 fits naturally — Lean/Lake documentation uses Step 0 conventions for prerequisite/setup steps. No renumbering of existing steps is needed.

#### lake-commands.md — Current Structure

File: `.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md` (133 lines)

**Sections** (in order):
1. Header + cross-reference note
2. `## Build Commands` — `lake build`, `lake build Module.Name`, `lake clean && lake build`
3. `## Test Commands` — `lake test`
4. `## Lint Commands` — `lake lint`, `lake exe lint-style`, `lake exe lint-style --fix`
5. `## Import Management Commands` — `lake exe checkInitImports`, `lake exe mk_all --module`
6. `## Import Minimization Commands` — `lake shake ...`, `lake shake ... --fix`
7. `## Quick Reference` — 3-column table (Command | Purpose | When to use)

**Quick Reference table columns**: `Command`, `Purpose`, `When to use`

Each command entry follows this pattern:
```
### `<command>`

<one-line description of what it does>. <Optional second sentence>.

```bash
<command>
```
```

### Recommendations

#### For ci-pipeline.md

Insert a new **Step 0** section after the `## Verification Order` prose intro and before the existing `### Step 1: \`lake build\`` heading. Content:

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

Then update the Quick Reference table to add a new row:

| Step | Command | When |
|------|---------|------|
| 0 | `lake exe cache get` | Once per branch setup (when based on upstream/main) |
| 1 | `lake build` | Always |
| ... | ... | ... |

#### For lake-commands.md

Insert a new **`## Cache Management Commands`** section before `## Build Commands`. Content:

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

Also add a row to the Quick Reference table:

| `lake exe cache get` | Download Mathlib `.olean` cache | Once per branch setup |

The new row should be inserted before the `lake build` row to reflect dependency order.

## Decisions

- **Step 0, not pre-step or "Step 0.5"**: The existing numbering starts at 1; inserting at 0 is the clearest convention and avoids renumbering any existing step.
- **"Once per branch setup" framing**: The key usage constraint is that cache get is not a per-build operation. Both files should clearly state this.
- **New section before Build Commands in lake-commands.md**: Cache management is a prerequisite to building, so it belongs before `## Build Commands` rather than inside it.
- **No changes to step numbers 1–7**: The existing steps remain unchanged; only Step 0 and Quick Reference rows are added.

## Risks & Mitigations

- **Risk**: Quick Reference table row insertion order could be ambiguous.
  **Mitigation**: Step 0 row goes first in ci-pipeline.md table; `lake exe cache get` row goes before `lake build` row in lake-commands.md table.
- **Risk**: "Once per branch setup" guidance could be misread as "never again."
  **Mitigation**: Include the `lake update` re-run trigger in both files.

## Context Extension Recommendations

None — this task IS the context extension (adding documentation to cslib extension context files).

## Appendix

- Files examined: 2
- External sources: None required (task is documentation-only; `lake exe cache get` is standard Mathlib tooling)
- Grep/Glob: Not needed (exact file paths provided)
