# Research Report: CSLib Build Cache Optimization

**Task**: 734 — Optimize CSLib build cache strategy
**Date**: 2026-06-16
**Status**: Complete

## Problem Statement

When implementing `pr`-type tasks (and `cslib`-type tasks) in `/home/benjamin/Projects/cslib/`,
the cslib-implementation-agent runs the full 7-step CI pipeline on the feature branch without
first fetching the Mathlib `.olean` cache. This triggers a near-full Mathlib rebuild (30-45
minutes) every time, even when the feature branch shares the same Mathlib pin as upstream/main.

Observable symptom: `lake test` (and `lake build`) running for 1h+ during `/implement` on PR
revision tasks (screenshot evidence: task 221, 1h 10m runtime, 170k tokens, 154 tool calls —
all spent waiting on `lake test` rebuilds).

## Root Cause Analysis

### The Cache Gap

The CSLib extension already documents the correct build-cache strategy in two context files:

- `build-cache-strategy.md` (lines 8-18): Documents `lake exe cache get` as essential, with
  time comparison: cache hit = ~1-2 min fetch + ~2-5 min build vs cache miss = ~25-45 min build
- `ci-pipeline.md` (lines 10-22): Lists `lake exe cache get` as **Step 0** in the verification order

However, the cslib-implementation-agent's CI pipeline instructions (`cslib-implementation-agent.md`
lines 196-241) skip Step 0 entirely and begin at Step 1 (`lake build Module.Name`).

### Files Examined

| File | Path | Relevant Section |
|------|------|-----------------|
| cslib-implementation-agent.md | `.claude/extensions/cslib/agents/` | "CSLib CI Pipeline (Ordered)" — lines 196-241 |
| skill-cslib-implementation/SKILL.md | `.claude/extensions/cslib/skills/` | Stage 3: Prepare Delegation Context |
| skill-pr-implementation/SKILL.md | `.claude/extensions/cslib/skills/` | PR description mode — CI deferred |
| skill-pr-review-implementation/SKILL.md | `.claude/extensions/cslib/skills/` | Dispatch decision, legacy path |
| pr.md | `.claude/extensions/cslib/commands/` | STEP 5b: Fetch Mathlib Cache (correct) |
| build-cache-strategy.md | `.claude/extensions/cslib/context/project/cslib/tools/` | Full cache strategy documentation |
| ci-pipeline.md | `.claude/extensions/cslib/context/project/cslib/standards/` | Step 0: lake exe cache get |
| cslib.md (rules) | `.claude/extensions/cslib/rules/` | CI Verification Order — lines 78-86 |
| manifest.json | `.claude/extensions/cslib/` | Routing: implement.pr -> skill-pr-review-implementation |

### The Three Redundancy Points

1. **Agent CI pipeline missing cache fetch**: `cslib-implementation-agent.md` lists 7 CI steps
   (build, checkInitImports, lint, lint-style, shake, mk_all, test) but omits `lake exe cache get`
   as Step 0.

2. **Skill preflight has no cache warming**: `skill-cslib-implementation/SKILL.md` does not
   run `lake exe cache get` before delegating to the agent. The agent starts work with whatever
   cache state exists locally.

3. **Rules file omits Step 0**: `cslib.md` (rules) lists the CI verification order at lines
   78-86 starting from `lake build`, not `lake exe cache get`.

Meanwhile, the `/pr` command (`pr.md` STEP 5b, lines 1017-1037) correctly includes
`lake exe cache get` — but this only executes during PR submission, not during implementation.

### Double-Build for PR Tasks

For `pr`-type tasks, the CI pipeline runs twice:
1. **During `/implement`**: cslib-implementation-agent runs the full 7-step pipeline
2. **During `/pr`**: The /pr command runs the same 7-step pipeline (STEP 7)

The `/pr` command's pipeline already includes cache fetching (STEP 5b), making the agent's
earlier uncached run purely redundant for PR tasks.

### Routing Path for PR Tasks

```
/implement N (task_type=pr)
  -> manifest routing: implement.pr -> skill-pr-review-implementation
    -> dispatch check: sources present? 
       YES -> pr-review-implementation-agent (composes response files, no CI)
       NO  -> cslib-implementation-agent (legacy path, RUNS FULL CI)
```

For the legacy path (no sources — PR description tasks), the cslib-implementation-agent has
a PR Description Mode detection:

> If `task_type == "pr"` in delegation context, OR if `delegation_path` contains
> `"skill-pr-implementation"`: Skip the CSLib CI Pipeline entirely.

However, for tasks involving actual Lean code changes (like task 221: "Revise PR #648 to
reconcile with merged PR #536"), the agent correctly runs the full CI pipeline — but without
cache warming.

## Proposed Changes

### Change 1: Add `lake exe cache get` to Agent CI Pipeline (HIGH IMPACT)

**File**: `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
**Section**: "CSLib CI Pipeline (Ordered — Run All Steps)" (~line 196)

Insert a new Step 0 before the existing "Scoped build" step:

```markdown
0. **Mathlib cache fetch** (one-time):
   ```bash
   lake exe cache get
   ```
   Downloads pre-built Mathlib `.olean` files. On cache hit (~1-2 min), subsequent
   builds only compile CSLib modules (~2-5 min). On cache miss, this is a no-op and
   `lake build` falls back to full compilation. Always run before Step 1.
```

Renumber existing steps 1-7 to 1-8 (or keep as 0-7 with the new step as 0).

**Impact**: Reduces CI pipeline time from ~30-45 min to ~5-10 min when Mathlib pin matches
upstream. Zero downside on cache miss (falls through to existing behavior).

### Change 2: Add Cache Warming to Skill Preflight (MEDIUM IMPACT)

**File**: `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
**Section**: Stage 3 — Prepare Delegation Context

Add a preflight step before invoking the subagent:

```markdown
### Stage 2b: Preflight Cache Warming

Ensure Mathlib cache is warm before delegating to the agent:

```bash
cd /home/benjamin/Projects/cslib
lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
```

This is non-blocking. Cache fetch failure does not prevent delegation.
```

**Rationale**: Warming the cache at the skill level ensures it happens once, early, before
the agent starts any builds (including per-phase scoped builds during development).

### Change 3: Fix Rules CI Verification Order (LOW IMPACT, CORRECTNESS)

**File**: `.claude/extensions/cslib/rules/cslib.md`
**Section**: "CSLib CI Verification Order" (lines 78-86)

Add Step 0 to match `ci-pipeline.md`:

```markdown
### CSLib CI Verification Order

Run in this order before submitting a PR:

0. `lake exe cache get` -- fetch Mathlib .olean cache (once per branch)
1. `lake build` -- syntax linters (runs during build)
2. `lake exe checkInitImports` -- all files import `Cslib.Init`
...
```

### Change 4: Defer Full CI for PR-Type Implementation (MEDIUM IMPACT)

**File**: `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
**Section**: "PR Description Mode (Skip Verification)" (~line 169)

Expand the detection logic to also cover PR revision tasks routed through the legacy path:

Currently the detection is:
> If `task_type == "pr"` in the delegation context, OR if `delegation_path` contains
> `"skill-pr-implementation"`, you are in PR Description Mode.

Consider adding a lighter verification mode for PR tasks that DO modify Lean files:

```markdown
### PR Implementation Mode (Reduced Verification)

**Detection**: If `task_type == "pr"` AND this is NOT a pure PR description task
(i.e., Lean files were modified), run a reduced pipeline:

1. `lake exe cache get` (Step 0)
2. `lake build Module.Name` (scoped build — affected modules only)
3. `lake exe checkInitImports`

Skip `lake test`, `lake lint`, `lake shake`, `lake exe lint-style` — these are deferred
to the `/pr` command's CI pipeline (STEP 7), which runs them with a warm cache.
```

**Trade-off**: This means the agent may return "implemented" without full verification.
The `/pr` command catches any issues before submission. Risk is low: the scoped build
catches compilation errors, and the full pipeline runs before the PR is actually created.

### Change 5: Add Agent Initialization Cache Step (LOW IMPACT, BELT-AND-SUSPENDERS)

**File**: `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
**Section**: "Stage 0: Initialize Early Metadata" (~line 99)

Add cache warming as part of agent initialization, before any substantive work:

```markdown
## Stage 0b: Ensure Build Cache

Before any lake commands, ensure the Mathlib cache is available:

```bash
cd /home/benjamin/Projects/cslib
lake exe cache get 2>&1 || true
```

This is a one-time operation. If the cache is already warm, this completes in seconds.
```

This complements Change 1 (CI pipeline Step 0) by also covering per-phase scoped builds
(`lake build Module.Name`) that happen BEFORE the final verification pipeline.

### Change 6 (Optional): Main-Branch Pre-Build Strategy

**File**: `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
**Section**: New Stage 2c after cache warming

More aggressive than cache-only warming — also pre-builds CSLib's shared modules:

```bash
cd /home/benjamin/Projects/cslib
current_branch=$(git branch --show-current)

# Save current state
git stash --include-untracked 2>/dev/null || true

# Build on main to warm ALL oleans (Mathlib + CSLib shared modules)
git checkout upstream/main 2>/dev/null
lake exe cache get 2>&1 || true
lake build 2>&1 || true

# Return to feature branch
git checkout "$current_branch" 2>/dev/null
git stash pop 2>/dev/null || true
```

**Trade-off**: Adds ~3-5 min upfront but makes incremental builds on the feature branch even
faster, since shared CSLib modules are already compiled. May be brittle with uncommitted changes.
Not recommended as a default — use only if Changes 1-2 prove insufficient.

## Impact Summary

| Change | File(s) | Estimated Savings | Effort | Priority |
|--------|---------|-------------------|--------|----------|
| 1. Agent CI pipeline cache fetch | cslib-implementation-agent.md | 25-40 min/run | Small (add 8 lines) | P0 |
| 2. Skill preflight cache warming | skill-cslib-implementation/SKILL.md | Same (earlier) | Small (add 6 lines) | P0 |
| 3. Rules CI order fix | cslib.md | Correctness | Trivial (add 1 line) | P1 |
| 4. Defer full CI for PR tasks | cslib-implementation-agent.md | 5-15 min for PR tasks | Medium (new mode) | P1 |
| 5. Agent init cache step | cslib-implementation-agent.md | Covers dev-phase builds | Small (add 5 lines) | P2 |
| 6. Main-branch pre-build | skill-cslib-implementation/SKILL.md | Additional 2-5 min | Medium (fragile) | P3 |

**Changes 1-2 are the critical fix.** They drop the typical CI pipeline time from ~1 hour
(full Mathlib rebuild) to ~5-10 minutes (cache hit + CSLib-only compilation).

Changes 3-5 are correctness and defense-in-depth. Change 6 is optional and only worthwhile
if Changes 1-2 prove insufficient for specific edge cases (diverged fork main, different
Mathlib pin).

## Scope of Implementation

All changes are confined to the cslib extension directory:

```
.claude/extensions/cslib/
├── agents/cslib-implementation-agent.md    # Changes 1, 4, 5
├── skills/skill-cslib-implementation/SKILL.md  # Changes 2, 6
└── rules/cslib.md                          # Change 3
```

No changes needed to:
- The `/pr` command (already has cache fetch in STEP 5b)
- `build-cache-strategy.md` or `ci-pipeline.md` (already document correct behavior)
- `manifest.json` or routing tables
- Any core agent system files

After implementation, reload the extension in target repos via `<leader>al`.
