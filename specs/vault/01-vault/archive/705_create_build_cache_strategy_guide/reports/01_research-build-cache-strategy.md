# Research Report: Task #705

**Task**: 705 - Create Build Cache Strategy Context Document
**Started**: 2026-06-14T17:09:00Z
**Completed**: 2026-06-14T17:15:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (index-entries.json, lake-commands.md, linters.md)
**Artifacts**: specs/705_create_build_cache_strategy_guide/reports/01_research-build-cache-strategy.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The cslib extension has 13 existing index entries in a flat JSON array format with `load_when` supporting both `languages` and `agents` arrays
- Existing tool docs (lake-commands.md, linters.md) follow a pattern: H1 title, one-line provenance sentence, H2 sections with H3 subsections for each command, fenced bash blocks, and a Quick Reference table
- The new build-cache-strategy.md should be registered with `load_when` for `cslib-implementation-agent` agent and `pr` language (matching the pattern of ci-pipeline.md and pr-conventions.md which are also relevant to pre-PR and branch workflows)
- lake-commands.md mentions `lake clean && lake build` for stale cache but has no detail on `lake exe cache get` or the Mathlib cloud cache system -- the new document fills this gap

## Context & Scope

Task 705 requires creating a new context document at `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md` and registering it in `.claude/extensions/cslib/index-entries.json`. The document should explain the Mathlib cloud cache system, cache invalidation triggers, the upstream/main base build strategy, `lake exe cache get` usage patterns, and feature branch workflow gotchas.

## Findings

### Codebase Patterns

**Index entry format** (from index-entries.json):

Each entry in the flat `entries` array has these fields:
- `path` - Relative to the extension's `context/` directory (e.g., `project/cslib/tools/lake-commands.md`)
- `description` - Short one-liner (used for display)
- `tags` - Array of lowercase strings
- `load_when` - Object with `languages` array and/or `agents` array
- `domain` - Always `"project"` for cslib tool docs
- `subdomain` - Always `"cslib"` for cslib tool docs
- `summary` - Often identical to `description` (some entries differ slightly)

**load_when patterns observed**:
- Research + implementation agents: `{ "languages": ["cslib"], "agents": ["cslib-research-agent", "cslib-implementation-agent"] }` -- for general domain knowledge
- Implementation only: `{ "languages": ["cslib"], "agents": ["cslib-implementation-agent"] }` -- for implementation-specific patterns
- PR-gated: `{ "languages": ["cslib", "pr"], "agents": ["cslib-implementation-agent"] }` -- for CI, PR conventions, and PR format docs
- Hard mode specific: `{ "languages": ["cslib"], "agents": ["cslib-research-hard-agent"] }` or `["cslib-implementation-hard-agent"]`

**Tool doc style** (from lake-commands.md and linters.md):

Both tool docs share the same structure:
1. H1 title (`# CSLib Lake Commands`, `# CSLib Linters`)
2. One-line provenance sentence (e.g., "All lake commands for CSLib development. Derived from CONTRIBUTING.md and `lakefile.toml`.")
3. H2 thematic sections (e.g., `## Build Commands`, `## Linter Categories`)
4. H3 for individual commands (e.g., `### lake build`, `### 1. Syntax Linters`)
5. Fenced bash code blocks for each command
6. Prose explanation of what it does and when to use it
7. Quick Reference table at end (lake-commands.md has this; linters.md does not)

**Existing cache content in lake-commands.md**:

The only cache-related content in lake-commands.md is the `lake clean && lake build` entry under "Build Commands" with the note "Use when the build cache is stale or after major changes." There is no mention of `lake exe cache get`, Mathlib cloud cache, `.olean` files, or the upstream/main base build strategy. The new document is additive, not duplicative.

**Duplicate entry in index-entries.json**:

The `standards/ci-pipeline.md` path appears twice -- once for the standard `cslib-implementation-agent` and once for `cslib-implementation-hard-agent`. This is intentional: entries can repeat the same path with different agent audiences. New entries follow the same pattern and do not need to deduplicate by path.

### Recommendations

**Content outline for build-cache-strategy.md**:

```
# CSLib Build Cache Strategy

One-line: Mathlib cloud cache architecture, cache invalidation triggers, and
upstream/main base build workflow for CSLib feature branches.

## Mathlib Cloud Cache Architecture

- What `lake exe cache get` does: downloads pre-built .olean files for Mathlib
  dependencies from the Mathlib4 cache server
- Effect: only CSLib's own modules need compiling; Mathlib modules load from cache
- When it works: Lean toolchain version + Mathlib commit hash must both match the
  cached build
- Typical time savings: 20-40 minute full Mathlib build vs. ~1-2 minute cache fetch

## Cache Invalidation Triggers

Four events invalidate the Mathlib cache:
1. **Toolchain version change** -- `lean-toolchain` file updated; cached .oleans
   were built for the old toolchain
2. **Mathlib version bump** -- `lake-manifest.json` Mathlib commit hash changes;
   new .oleans not yet on your machine
3. **Branch divergence from upstream/main** -- switching to a branch that has a
   different Mathlib pin than what was last built
4. **Local cache corruption** -- `.lake/` directory partially written or corrupted;
   `lake clean` + `lake exe cache get` to recover

## `lake exe cache get` Usage Patterns

### When to Run

- After branch creation (especially from upstream/main or after a Mathlib bump)
- After `git pull` that updates `lake-manifest.json`
- After changing `lean-toolchain`
- Before the first `lake build` on a new clone

### Command

```bash
lake exe cache get
```

### Interaction with `lake build`

`lake exe cache get` populates the `.lake/packages/mathlib/.lake/build/` cache.
`lake build` then only compiles CSLib's own `.lean` files. Run `cache get` before
`lake build`; if `cache get` fails (cache miss), `lake build` will compile Mathlib
from source (slow).

### Expected Time

- `lake exe cache get`: ~1-2 minutes (downloads pre-built .oleans)
- `lake build` after cache: ~2-5 minutes (CSLib modules only)
- `lake build` without cache: ~25-45 minutes (full Mathlib recompile)

## Upstream/Main Base Build Strategy

### Problem

CSLib's fork main diverges from upstream/main when Mathlib version bumps or
toolchain changes are applied separately. Feature branches created from the fork
main may not match a cached Mathlib build, requiring full recompile.

### Strategy: Maintain a Built Upstream/Main Checkout

Keep a separate worktree or clone of upstream/main with a valid built cache:

```bash
# Example: separate worktree at upstream main
git worktree add ../cslib-upstream upstream/main
cd ../cslib-upstream
lake exe cache get
lake build   # builds CSLib modules against upstream Mathlib pin
```

This built checkout serves as a reference point. Feature branches created from
this worktree inherit the cache.

### Using as Feature Branch Foundation

When starting a feature branch from upstream/main (not fork main):

```bash
git checkout -b feat/my-feature upstream/main
lake exe cache get   # likely a cache hit since toolchain/Mathlib match upstream
lake build           # only CSLib modules to build
```

## Feature Branch Workflow

### Cache-Safe Branch Creation

**Preferred**: Create branches from upstream/main:
```bash
git fetch upstream
git checkout -b feat/my-feature upstream/main
lake exe cache get
lake build
```

**Risky**: Create branches from fork main (if fork main diverges):
- Fork main may have a different Mathlib pin or toolchain than upstream
- `lake exe cache get` may fail (cache miss for that pin/toolchain combo)
- Falls back to full Mathlib recompile

### Two Mitigation Strategies for Fork-Based Branches

**Strategy 1: Rebase onto upstream/main before building**

```bash
git fetch upstream
git rebase upstream/main
lake exe cache get   # now on upstream's Mathlib pin; cache hit likely
lake build
```

**Strategy 2: Accept the build cost; use fork main as base**

If the fork main divergence is intentional (e.g., local patches), accept the
~30-minute initial build cost. The built .oleans are then cached locally for
subsequent incremental builds.

## Quick Reference

| Scenario | Action |
|----------|--------|
| New clone | `lake exe cache get` then `lake build` |
| After Mathlib bump | `lake exe cache get` then `lake build` |
| Branch from upstream/main | `lake exe cache get` then `lake build` |
| Branch from diverged fork main | `git rebase upstream/main` or accept full rebuild |
| Cache stale/corrupted | `lake clean && lake exe cache get && lake build` |
| Verify cache was used | Check build output -- no "compiling Mathlib" messages |
```

**load_when recommendation for index-entries.json**:

Matching the pattern of ci-pipeline.md (which covers CI and pre-PR workflow):
```json
{
  "languages": ["cslib", "pr"],
  "agents": ["cslib-implementation-agent"]
}
```

Rationale: Cache strategy is most relevant (a) during implementation when the agent needs to build, and (b) during PR preparation when a clean build is required. It is less relevant during research. The `pr` language tag matches ci-pipeline.md and pr-conventions.md, signaling this is important pre-PR knowledge.

## Decisions

- Use `load_when` with `languages: ["cslib", "pr"]` and `agents: ["cslib-implementation-agent"]` -- mirrors ci-pipeline.md pattern which is the closest analogue (both are build/CI-adjacent workflow docs)
- Do NOT add `cslib-research-agent` -- cache strategy is not research-phase knowledge
- Do NOT add a second entry for hard-mode agents -- no hard-mode-specific cache considerations
- Keep the document in the `tools/` subdirectory (alongside lake-commands.md and linters.md) as it documents a Lake executable command

## Risks & Mitigations

- **Risk**: Cache server availability varies; `lake exe cache get` can fail silently or partially. **Mitigation**: Document fallback (fall through to full build) explicitly.
- **Risk**: Upstream/main pin vs. fork main pin confusion. **Mitigation**: Make the "two mitigation strategies" section concrete with exact git commands.
- **Risk**: index-entries.json duplicate path entries (ci-pipeline.md already does this). **Mitigation**: This is an established pattern; no risk.

## Context Extension Recommendations

- The new build-cache-strategy.md itself fills the identified gap in cslib tool documentation.
- Consider cross-referencing from lake-commands.md (add a note under `lake clean && lake build` pointing to build-cache-strategy.md for the cloud cache variant).

## Appendix

**Files read**:
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/index-entries.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/tools/lake-commands.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/tools/linters.md`

**Key observations**:
- 13 existing entries; 2 are duplicate paths for different agent audiences
- Tool docs average ~100-130 lines with Quick Reference tables
- No existing entry covers `lake exe cache get` or Mathlib cloud cache
