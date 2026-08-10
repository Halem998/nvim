# Plan: Fix Manifest Absolute Paths (Task 537)

**Task**: 537 - fix_manifest_absolute_paths
**Status**: planned
**Date**: 2026-05-07

## Objective

Replace all relative manifest globs with absolute paths derived from `git rev-parse --show-toplevel` across 12 command specification files (24 globs total). Add explicit `[WARN]` logging when no extension manifests are discovered, eliminating silent failures when the agent CWD differs from the project root.

---

## Phase 1: Update `/implement` Commands

**Files**:
- `.opencode/commands/implement.md`
- `.opencode/extensions/core/commands/implement.md`

**Changes**:
1. Add `project_root` derivation early in the single-task flow (CHECKPOINT 1: GATE IN or STAGE 2: DELEGATE):
   ```bash
   project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"
   ```
2. Add project root validation:
   ```bash
   if [ ! -d "$project_root/.opencode" ]; then
       echo "[WARN] .opencode directory not found in project root: $project_root"
   fi
   ```
3. Replace both relative globs (lines ~375 and ~389) with absolute paths:
   - Before: `for manifest in .opencode/extensions/*/manifest.json; do`
   - After: `for manifest in "$project_root/.opencode/extensions/"*/manifest.json; do`
4. Add `manifest_count` accumulator inside each loop body when `[ -f "$manifest" ]` succeeds.
5. After both loops complete, add explicit warning if `manifest_count -eq 0`:
   ```bash
   if [ "$manifest_count" -eq 0 ]; then
     echo "[WARN] No extension manifests found in $project_root/.opencode/extensions/"
   fi
   ```
6. Apply identical changes to `.opencode/extensions/core/commands/implement.md` (core mirror).

---

## Phase 2: Update `/research` Commands

**Files**:
- `.opencode/commands/research.md`
- `.opencode/extensions/core/commands/research.md`

**Changes**:
1. Add `project_root` derivation at the same structural location as in `/implement`.
2. Add `.opencode` directory validation warning.
3. Replace both relative globs (lines ~340 and ~354) with `"$project_root/.opencode/extensions/"*/manifest.json`.
4. Add `manifest_count` accumulator and post-discovery `[WARN]` for zero manifests.
5. Apply identical changes to `.opencode/extensions/core/commands/research.md` (core mirror).

---

## Phase 3: Update `/plan` Commands

**Files**:
- `.opencode/commands/plan.md`
- `.opencode/extensions/core/commands/plan.md`

**Changes**:
1. Add `project_root` derivation at the same structural location as in `/implement`.
2. Add `.opencode` directory validation warning.
3. Replace both relative globs (lines ~344 and ~358) with `"$project_root/.opencode/extensions/"*/manifest.json`.
4. Add `manifest_count` accumulator and post-discovery `[WARN]` for zero manifests.
5. Apply identical changes to `.opencode/extensions/core/commands/plan.md` (core mirror).

---

## Phase 4: Update Core Mirrors (`.opencode/extensions/core/`)

**Files**:
- `.opencode/extensions/core/commands/implement.md` (covered in Phase 1)
- `.opencode/extensions/core/commands/research.md` (covered in Phase 2)
- `.opencode/extensions/core/commands/plan.md` (covered in Phase 3)

**Changes**:
- Mirror all changes from Phases 1-3 exactly.
- Ensure line offsets are validated against the core mirror files (they differ slightly from root copies).

---

## Phase 5: Update `.claude/` Equivalents

**Files**:
- `.claude/commands/implement.md`
- `.claude/commands/research.md`
- `.claude/commands/plan.md`
- `.claude/extensions/core/commands/implement.md`
- `.claude/extensions/core/commands/research.md`
- `.claude/extensions/core/commands/plan.md`

**Changes**:
1. Add identical `project_root` derivation.
2. Add `.claude` directory validation (instead of `.opencode`):
   ```bash
   if [ ! -d "$project_root/.claude" ]; then
       echo "[WARN] .claude directory not found in project root: $project_root"
   fi
   ```
3. Replace both relative globs in each file with `"$project_root/.claude/extensions/"*/manifest.json`.
4. Add `manifest_count` accumulator and post-discovery `[WARN]` for zero manifests.
5. Apply identical changes to all three `.claude/extensions/core/` mirrors.

---

## Phase 6: Add Explicit `[WARN]` When No Manifests Found

This phase is integrated into Phases 1-5 above. The specific warning logic is:

```bash
manifest_count=0
for manifest in "$project_root/.opencode/extensions/"*/manifest.json; do
  if [ -f "$manifest" ]; then
    ((manifest_count++))
    # ... existing routing logic ...
  fi
done

if [ "$manifest_count" -eq 0 ]; then
  echo "[WARN] No extension manifests found in $project_root/.opencode/extensions/"
fi
```

- The `manifest_count` must be incremented inside **both** the primary and fallback loops (for compound task types).
- The warning fires after **both** loops have run and no manifests were discovered.
- This prevents silent fallback to generic skills when the agent is in the wrong directory.

---

## Multi-Task Mode Consideration

In multi-task mode (batch dispatch), add `project_root` derivation once at the start of the batch validation section, before Step 1: Batch Validation. While manifest discovery currently happens inside per-task agents, centralizing the derivation ensures consistency if batch-level manifest operations are added later.

---

## Testing & Verification

1. **Syntax Check**: Run `bash -n` on all modified bash blocks (extract and validate).
2. **Glob Verification**: From a subdirectory of the repo, run:
   ```bash
   project_root="$(git rev-parse --show-toplevel)"
   ls "$project_root/.opencode/extensions/"*/manifest.json
   ```
   Ensure it returns manifests regardless of CWD.
3. **Warning Trigger**: Temporarily rename `.opencode/extensions/` and run a command that triggers manifest discovery; verify `[WARN]` appears.
4. **Count Validation**: Verify `manifest_count` equals the actual number of manifest files present.

---

## Rollback Plan

All changes are additive (new variable + absolute path prefix + warning). To rollback:
1. Revert the 12 files to their pre-change state.
2. No database or external state changes are involved.

---

*End of Plan*
