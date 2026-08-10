# Research Report: Fix Manifest Discovery to Use Absolute Paths

**Task**: 537 - fix_manifest_absolute_paths
**Status**: researched
**Date**: 2026-05-07

## Executive Summary

All three core delegating commands (`/implement`, `/research`, `/plan`) discover extension manifests using relative bash globs (`.opencode/extensions/*/manifest.json` or `.claude/extensions/*/manifest.json`). When the agent's shell working directory differs from the project root, these globs silently return no matches, causing routing to fall back to generic skills instead of extension-specific ones. This report identifies all affected files, analyzes the root cause, and proposes exact changes.

---

## 1. Root Cause Analysis

### 1.1 The Working Directory Problem

The commands execute bash code blocks via the `Bash` tool. Bash globs are resolved relative to the **current working directory (CWD)** of the shell process. The agent's CWD is not guaranteed to be the project root.

In the Task 107 trace, the agent's CWD was `/home/benjamin/.config/nvim` while the target project was `/home/benjamin/Projects/ProofChecker`. The glob `.opencode/extensions/*/manifest.json` resolved to `/home/benjamin/.config/nvim/.opencode/extensions/*/manifest.json` (which existed but was the wrong project's extensions) or, if the agent had changed directories, to a path with no matches at all.

### 1.2 Silent Failure Mode

The current code already contains `if [ -f "$manifest" ]` guards inside the loops:

```bash
for manifest in .opencode/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.implement[$tt] // empty' "$manifest")
    ...
  fi
done
```

When the glob matches no files, bash executes the loop body **once** with the literal string `.opencode/extensions/*/manifest.json` as the value of `$manifest`. The `-f` test fails, so no error is emitted. The code then falls back to the hardcoded default skill (`skill-implementer`, `skill-researcher`, or `skill-planner`). This is a **silent failure** that wastes agent reasoning cycles.

---

## 2. Affected Files

### 2.1 Primary OpenCode Commands (6 globs across 3 files)

| File | Lines | Relative Glob | Routing Key |
|------|-------|---------------|-------------|
| `.opencode/commands/implement.md` | 375, 389 | `.opencode/extensions/*/manifest.json` | `.routing.implement[$tt]` |
| `.opencode/commands/research.md` | 340, 354 | `.opencode/extensions/*/manifest.json` | `.routing.research[$tt]` |
| `.opencode/commands/plan.md` | 344, 358 | `.opencode/extensions/*/manifest.json` | `.routing.plan[$tt]` |

Each file has **two identical loops**: one for the full `task_type`, and one fallback for the `base_type` (the part before `:` in compound types like `founder:deck`).

### 2.2 OpenCode Core Extension Mirrors (6 globs across 3 files)

The `core` extension contains copies of the command specs for bundled distribution:

| File | Lines | Relative Glob |
|------|-------|---------------|
| `.opencode/extensions/core/commands/implement.md` | 373, 387 | `.opencode/extensions/*/manifest.json` |
| `.opencode/extensions/core/commands/research.md` | 338, 352 | `.opencode/extensions/*/manifest.json` |
| `.opencode/extensions/core/commands/plan.md` | 342, 356 | `.opencode/extensions/*/manifest.json` |

### 2.3 Claude Code Mirrors (6 globs across 3 files)

The `.claude/` directory is a parallel system with the same structure. It uses `.claude/` as the prefix instead of `.opencode/`:

| File | Lines | Relative Glob |
|------|-------|---------------|
| `.claude/commands/implement.md` | 374, 388 | `.claude/extensions/*/manifest.json` |
| `.claude/commands/research.md` | 339, 353 | `.claude/extensions/*/manifest.json` |
| `.claude/commands/plan.md` | 343, 357 | `.claude/extensions/*/manifest.json` |

### 2.4 Claude Code Core Extension Mirrors (6 globs across 3 files)

| File | Lines | Relative Glob |
|------|-------|---------------|
| `.claude/extensions/core/commands/implement.md` | 374, 388 | `.claude/extensions/*/manifest.json` |
| `.claude/extensions/core/commands/research.md` | 339, 353 | `.claude/extensions/*/manifest.json` |
| `.claude/extensions/core/commands/plan.md` | 343, 357 | `.claude/extensions/*/manifest.json` |

**Total**: 24 manifest globs across 12 files.

### 2.5 Scripts Audit

No scripts in `.opencode/scripts/` or `.claude/scripts/` perform manifest discovery with globs. The routing logic is **exclusively** in the command markdown files.

---

## 3. Deriving Absolute Paths

### 3.1 Existing Conventions

The system already references `PROJECT_ROOT` in several places:

- `skill-todo/SKILL.md` (line 312): `PROJECT_ROOT="${PROJECT_ROOT:-.}"`
- `task.md` (line 181): `source "$PROJECT_ROOT/.opencode/scripts/..."`
- `skill-implementer/SKILL.md` (line 420): `source "$PROJECT_ROOT/.opencode/scripts/..."`

However, `PROJECT_ROOT` is **not set automatically** by the orchestrator. It relies on the environment or falls back to `.`.

### 3.2 Recommended Derivation Strategy

Since every project using this system is a git repository, the most reliable and portable method is:

```bash
# Derive project root from git repository root
project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"
```

**Rationale**:
- `git rev-parse --show-toplevel` returns the absolute path to the repository root, even if the CWD is a subdirectory.
- It works across all platforms where git is installed.
- If git fails (non-repo), the fallback `$(pwd)` preserves backward compatibility.

**Validation**:
After deriving `project_root`, verify the expected directory structure:

```bash
# Verify project root contains expected structure
if [ ! -d "$project_root/.opencode" ] && [ ! -d "$project_root/.claude" ]; then
    echo "[WARN] Neither .opencode nor .claude directory found in project root: $project_root"
fi
```

### 3.3 Where to Derive `project_root`

The derivation should happen **once per command invocation**, early in the single-task flow (e.g., in `CHECKPOINT 1: GATE IN` or at the top of `STAGE 2: DELEGATE`), so it is available for both the initial routing lookup and any subsequent operations.

For multi-task mode, the derivation should happen **once per batch** before the dispatch loop, since all tasks in a batch belong to the same project (same `specs/state.json`).

---

## 4. Proposed Exact Changes

### 4.1 Pattern to Apply (OpenCode files)

**Before** (from `.opencode/commands/implement.md`):

```bash
# Check extension routing for implement (skill_name starts empty)
skill_name=""
for manifest in .opencode/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.implement[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base task_type
if [ -z "$skill_name" ] && echo "$task_type" | grep -q ":"; then
  base_type=$(echo "$task_type" | cut -d: -f1)
  for manifest in .opencode/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg tt "$base_type" \
        '.routing.implement[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi
```

**After**:

```bash
# Derive absolute project root for manifest discovery
project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"

# Verify project root
if [ ! -d "$project_root/.opencode" ]; then
    echo "[WARN] .opencode directory not found in project root: $project_root"
fi

# Check extension routing for implement (skill_name starts empty)
skill_name=""
manifest_count=0
for manifest in "$project_root/.opencode/extensions/"*/manifest.json; do
  if [ -f "$manifest" ]; then
    ((manifest_count++))
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.implement[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base task_type
if [ -z "$skill_name" ] && echo "$task_type" | grep -q ":"; then
  base_type=$(echo "$task_type" | cut -d: -f1)
  for manifest in "$project_root/.opencode/extensions/"*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg tt "$base_type" \
        '.routing.implement[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Explicit warning if no manifests discovered
if [ "$manifest_count" -eq 0 ]; then
  echo "[WARN] No extension manifests found in $project_root/.opencode/extensions/"
fi

# Fallback to default implementer if no extension routing found
skill_name=${skill_name:-"skill-implementer"}
```

### 4.2 Pattern to Apply (Claude Code files)

For `.claude/` files, replace `.opencode/extensions/` with `.claude/extensions/`:

```bash
project_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"

if [ ! -d "$project_root/.claude" ]; then
    echo "[WARN] .claude directory not found in project root: $project_root"
fi

for manifest in "$project_root/.claude/extensions/"*/manifest.json; do
  ...
done
```

### 4.3 Multi-Task Mode Consideration

In multi-task mode, the batch validation loop runs before dispatch. The `project_root` derivation should be added at the start of the multi-task dispatch section (before Step 1: Batch Validation), so it is available if any batch-level manifest operations are added later. Currently, manifest discovery only happens inside per-task agents, but centralizing the derivation keeps the code consistent.

---

## 5. Impact Assessment

### 5.1 ProofChecker Project vs Nvim Config Project

The nvim config project (`/home/benjamin/.config/nvim`) is the **source** repository for the OpenCode/Claude Code system. It contains:
- `.opencode/extensions/` with 16 extension manifests
- `.claude/extensions/` with 16 extension manifests
- `specs/state.json` with task metadata

When a user works on a **different project** (e.g., ProofChecker at `/home/benjamin/Projects/ProofChecker`), the extension loader (fixed in Task 533) copies the relevant extension files into that project's `.opencode/extensions/` directory. The commands should discover manifests in the **target project**, not the source repository.

Using `git rev-parse --show-toplevel` ensures that:
- If the agent is working in ProofChecker's directory, manifests are found in `ProofChecker/.opencode/extensions/`.
- If the agent is working in the nvim config directory, manifests are found in `nvim/.opencode/extensions/`.
- The routing always uses the correct project's extensions.

### 5.2 Backward Compatibility

The proposed changes are fully backward compatible:
- If CWD is already the project root, `git rev-parse --show-toplevel` returns the same path.
- The `$(pwd)` fallback ensures non-git environments still work.
- The explicit `[WARN]` messages only add observability; they do not change control flow.

---

## 6. Acceptance Criteria Verification

| Criterion | How Proposed Changes Satisfy It |
|-----------|--------------------------------|
| All commands use absolute paths for manifest discovery | Replace relative globs with `"$project_root/..."` in all 12 files |
| Working directory is verified before globbing | `git rev-parse --show-toplevel` derives the true project root independent of CWD; validation checks `.opencode/` or `.claude/` exists |
| If no manifests are found, explicit warning is emitted | `manifest_count` accumulator + `[WARN]` message at end of discovery |
| Task 107-style trace shows manifests discovered correctly | Absolute paths ensure glob resolves to correct directory regardless of agent CWD |

---

## 7. Implementation Checklist

- [ ] `.opencode/commands/implement.md` - Add `project_root` derivation + absolute paths + warning
- [ ] `.opencode/commands/research.md` - Add `project_root` derivation + absolute paths + warning
- [ ] `.opencode/commands/plan.md` - Add `project_root` derivation + absolute paths + warning
- [ ] `.opencode/extensions/core/commands/implement.md` - Mirror changes
- [ ] `.opencode/extensions/core/commands/research.md` - Mirror changes
- [ ] `.opencode/extensions/core/commands/plan.md` - Mirror changes
- [ ] `.claude/commands/implement.md` - Apply with `.claude/` prefix
- [ ] `.claude/commands/research.md` - Apply with `.claude/` prefix
- [ ] `.claude/commands/plan.md` - Apply with `.claude/` prefix
- [ ] `.claude/extensions/core/commands/implement.md` - Mirror changes with `.claude/` prefix
- [ ] `.claude/extensions/core/commands/research.md` - Mirror changes with `.claude/` prefix
- [ ] `.claude/extensions/core/commands/plan.md` - Mirror changes with `.claude/` prefix

---

## 8. Open Questions

None. The scope is well-defined and the fix is mechanical.

---

*End of Research Report*
