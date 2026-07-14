# CSLib Build Cache Strategy

Mathlib cloud cache architecture, cache invalidation triggers, and upstream/main base build workflow for CSLib feature branches. Derived from CSLib development practices and Mathlib4 cache documentation.

## Mathlib Cloud Cache Architecture

`lake exe cache get` downloads pre-built `.olean` files for Mathlib dependencies from the Mathlib4 cache server. Once downloaded, only CSLib's own modules need compiling; Mathlib modules load directly from the cache.

The cache is keyed on two values that must both match:
- The Lean toolchain version (from `lean-toolchain`)
- The Mathlib commit hash (from `lake-manifest.json`)

If either value differs from the cached build, `lake exe cache get` will report a cache miss and fall back to a full Mathlib recompile.

Typical time comparison:
- Full Mathlib build (no cache): 20-40 minutes
- `lake exe cache get` fetch: ~1-2 minutes
- `lake build` after cache: ~2-5 minutes (CSLib modules only)

## Cache Invalidation Triggers

Four events invalidate the Mathlib cache and require re-running `lake exe cache get` (or accepting a full rebuild):

1. **Toolchain version change** — `lean-toolchain` updated; cached `.oleans` were built for the old toolchain and are incompatible
2. **Mathlib version bump** — `lake-manifest.json` Mathlib commit hash changes; new `.oleans` not yet on your machine
3. **Branch divergence from upstream/main** — switching to a branch that has a different Mathlib pin than what was last built
4. **Local cache corruption** — `.lake/` directory partially written or corrupted; recover with `lake clean` followed by `lake exe cache get`

## `lake exe cache get` Usage Patterns

### When to Run

Run `lake exe cache get` in these situations:

- After branch creation (especially from upstream/main or after a Mathlib bump)
- After `git pull` that updates `lake-manifest.json`
- After changing `lean-toolchain`
- Before the first `lake build` on a new clone

### Command

```bash
lake exe cache get
```

### Interaction with `lake build`

`lake exe cache get` populates `.lake/packages/mathlib/.lake/build/` with pre-built `.olean` files. `lake build` then only compiles CSLib's own `.lean` files.

Run `lake exe cache get` before `lake build`. If `cache get` fails (cache miss), `lake build` will compile Mathlib from source (slow). This is not an error — it is the expected fallback.

### Expected Time

| Operation | Time |
|-----------|------|
| `lake exe cache get` (hit) | ~1-2 minutes |
| `lake build` after cache hit | ~2-5 minutes |
| `lake build` after cache miss | ~25-45 minutes |

## Upstream/Main Base Build Strategy

### Problem

CSLib's fork main can diverge from upstream/main when Mathlib version bumps or toolchain changes are applied separately. Feature branches created from the fork main may not match a cached Mathlib build, requiring full recompile.

### Strategy: Maintain a Built Upstream/Main Checkout

Keep a separate worktree or clone of upstream/main with a valid built cache:

```bash
# Set up a separate worktree at upstream main
git worktree add ../cslib-upstream upstream/main
cd ../cslib-upstream
lake exe cache get
lake build
```

This built checkout serves as a reference point with a known-good cache state. Feature branches created from this worktree inherit the matching toolchain and Mathlib pin.

### Using as Feature Branch Foundation

When starting a feature branch from upstream/main rather than fork main:

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

**Risky**: Creating branches from fork main (if fork main diverges from upstream):
- Fork main may have a different Mathlib pin or toolchain version than upstream
- `lake exe cache get` may fail with a cache miss for that pin/toolchain combination
- Falls back to full Mathlib recompile (~30-45 minutes)

### Two Mitigation Strategies for Fork-Based Branches

**Strategy 1: Rebase onto upstream/main before building**

```bash
git fetch upstream
git rebase upstream/main
lake exe cache get   # now on upstream's Mathlib pin; cache hit likely
lake build
```

Use this when the fork main divergence is unintentional or when you can safely rebase.

**Strategy 2: Accept the build cost; use fork main as base**

```bash
# No rebase needed — build from fork main directly
lake exe cache get   # will miss; fall through to full build
lake build           # ~30-45 minutes first time
```

If the fork main divergence is intentional (e.g., local patches not yet upstreamed), accept the initial full build cost. The built `.oleans` are then cached locally for subsequent incremental builds on that branch.

## Quick Reference

| Scenario | Action |
|----------|--------|
| New clone | `lake exe cache get` then `lake build` |
| After Mathlib bump | `lake exe cache get` then `lake build` |
| Branch from upstream/main | `lake exe cache get` then `lake build` |
| Branch from diverged fork main | `git rebase upstream/main` or accept full rebuild |
| Cache stale or corrupted | `lake clean && lake exe cache get && lake build` |
| Verify cache was used | Check build output — no "compiling Mathlib" messages |
