# Research Report: Task #470

**Task**: 470 - Fix loader to handle root-level context files
**Started**: 2026-04-16T12:00:00Z
**Completed**: 2026-04-16T12:15:00Z
**Effort**: Small (single function fix + manifest update)
**Dependencies**: None
**Sources/Inputs**:
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (copy engine)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (caller)
- `.claude/extensions/core/manifest.json` (core provides.context)
- `.claude/extensions/core/context/` (source files)
- `.claude/context/` (deployed files)
**Artifacts**: - This report
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- `copy_context_dirs()` (line 181-222 of loader.lua) only handles directory entries via `vim.fn.isdirectory()` check; files at the context root are silently skipped
- The core manifest's `provides.context` array lists only subdirectory names (15 entries), missing 5 root-level files: `README.md`, `routing.md`, `validation.md`, `core-index-entries.json`, `index.schema.json`
- The `copy_docs()` function (line 343-385) already implements the correct pattern: it checks `isdirectory()` first, then falls back to `filereadable()` for individual files
- The fix requires two changes: (1) add `filereadable` fallback to `copy_context_dirs()`, (2) add root file names to core manifest's `provides.context` array
- Unload is not affected: `remove_installed_files()` tracks individual file paths, not directory entries, so file-level entries will unload correctly

## Context & Scope

Task 469 identified that root-level context files (README.md, routing.md, validation.md) were not being deployed by the extension loader. A manual workaround committed these files directly to `.claude/context/`. However, the underlying loader bug persists: reloading extensions will not regenerate these files since `copy_context_dirs()` only processes directory entries.

This research examines the root cause, evaluates fix options, and recommends an approach.

## Findings

### 1. Root Cause Analysis

The `copy_context_dirs()` function iterates over `manifest.provides.context` entries and treats each as a directory path:

```lua
-- loader.lua lines 198-219
for _, context_path in ipairs(manifest.provides.context) do
  local source_ctx_dir = source_context_dir .. "/" .. context_path
  local target_ctx_dir = target_context_dir .. "/" .. context_path

  if vim.fn.isdirectory(source_ctx_dir) == 1 then  -- <-- ONLY checks directory
    -- ... copies directory recursively
  end
  -- No else/fallback for files
end
```

There are two independent issues:
1. **Loader bug**: `copy_context_dirs()` has no file fallback (unlike `copy_docs()`)
2. **Manifest gap**: `provides.context` does not list the root-level files

### 2. Affected Files

Files in `.claude/extensions/core/context/` that are NOT directories:

| File | Deployed? | Mechanism |
|------|-----------|-----------|
| `README.md` | Yes | Manual workaround (task 469 commit) |
| `routing.md` | Yes | Manual workaround (task 469 commit) |
| `validation.md` | Yes | Manual workaround (task 469 commit) |
| `core-index-entries.json` | No | Read from source dir directly by init.lua (line 489) |
| `index.schema.json` | No | Only used externally (ajv validation) |

Note: `core-index-entries.json` is read from the source directory during loading (not from the deployed location), so its non-deployment has no runtime impact. However, deploying it would be consistent and allow external tools to find it at the expected path. `index.schema.json` is only referenced in documentation for external validation.

### 3. Reference Pattern: copy_docs()

The `copy_docs()` function (lines 343-385) already handles both files and directories:

```lua
for _, doc_name in ipairs(manifest.provides.docs) do
  local source_path = source_docs_dir .. "/" .. doc_name
  local target_path = target_docs_dir .. "/" .. doc_name

  if vim.fn.isdirectory(source_path) == 1 then
    -- Directory: copy recursively
    -- ...
  elseif vim.fn.filereadable(source_path) == 1 then
    -- File: copy directly
    if copy_file(source_path, target_path, false) then
      table.insert(copied_files, target_path)
    end
  end
end
```

This is the exact pattern to replicate in `copy_context_dirs()`.

### 4. Other Extensions

All non-core extensions list single subdirectory entries in `provides.context` (e.g., `"project/neovim"`), so they are unaffected by this bug. Only the core extension has root-level files in its context directory.

### 5. Unload Path Analysis

The `remove_installed_files()` function (lines 587-621 of loader.lua) operates on tracked file paths and directory paths:
- **Files**: Removed individually by path (regardless of whether they came from a directory or file entry)
- **Directories**: Removed only if empty, sorted deepest-first

The load operation tracks all copied files in `all_files` (line 418), which get stored in extension state as `installed_files`. Adding file entries to `copy_context_dirs()` output will cause those files to appear in `installed_files`, and they will be properly removed on unload. No changes needed to the unload path.

### 6. Conflict Checking

The `check_conflicts()` function (lines 517-585) does NOT check context entries -- it only checks categories like agents, commands, rules, scripts, hooks, docs, templates, systemd, skills, and data. This is acceptable since context entries are extension-namespaced (each extension uses its own subdirectory under `project/`), so conflicts are unlikely. The root-level files (README.md, etc.) could theoretically conflict between extensions, but in practice only core provides them.

## Decisions

1. **Approach**: Use `copy_docs()` pattern (option A from task description) -- add `filereadable` fallback to `copy_context_dirs()`. This is the simplest, most consistent fix.
2. **Do NOT add a separate `context_files` or `root_files` manifest key** (option B) -- this would add unnecessary complexity to the manifest schema when the existing `provides.context` array can already hold both file and directory names.
3. **Do NOT auto-scan the context directory** (option C) -- this would bypass the manifest's explicit enumeration, which exists for a reason (controlled deployment).
4. **Include all 5 root files in manifest** -- even `core-index-entries.json` and `index.schema.json`, for consistency and to support external tooling.

## Recommendations

### Implementation Plan

**Phase 1: Fix `copy_context_dirs()` in loader.lua** (2 lines changed)

Add `elseif vim.fn.filereadable(source_ctx_dir) == 1 then` fallback after the `isdirectory` check, mirroring `copy_docs()`:

```lua
for _, context_path in ipairs(manifest.provides.context) do
  local source_ctx_dir = source_context_dir .. "/" .. context_path
  local target_ctx_dir = target_context_dir .. "/" .. context_path

  if vim.fn.isdirectory(source_ctx_dir) == 1 then
    -- existing directory handling (unchanged)
    -- ...
  elseif vim.fn.filereadable(source_ctx_dir) == 1 then
    -- NEW: handle individual files at context root
    if copy_file(source_ctx_dir, target_ctx_dir, false) then
      table.insert(copied_files, target_ctx_dir)
    end
  end
end
```

Note: The variable names `source_ctx_dir` and `target_ctx_dir` are slightly misleading for file entries but renaming them is out of scope. A comment clarifies the dual usage.

**Phase 2: Update core manifest's `provides.context`**

Add the 5 root-level files to the array:

```json
"context": [
  "README.md",
  "routing.md",
  "validation.md",
  "core-index-entries.json",
  "index.schema.json",
  "architecture",
  "checkpoints",
  ...
]
```

**Phase 3: Remove manually committed files**

After the fix, remove the manually committed copies of README.md, routing.md, and validation.md from `.claude/context/` (they were added by task 469 as a workaround). Then reload extensions to verify the loader deploys them correctly.

**Phase 4: Verification**

1. Reload core extension: trigger extension reload via picker
2. Verify all 5 files exist in `.claude/context/`
3. Verify unload removes the files
4. Verify reload re-creates them

### Testing Approach

```bash
# After fix, reload extensions and verify deployment
ls -la .claude/context/README.md
ls -la .claude/context/routing.md
ls -la .claude/context/validation.md
ls -la .claude/context/core-index-entries.json
ls -la .claude/context/index.schema.json

# Verify headless module load still works
nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.loader')" -c "q"
```

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Variable naming confusion (`source_ctx_dir` for files) | Low | Low | Add inline comment explaining dual file/dir usage |
| Other extensions accidentally listing files in context | Very Low | Low | No action needed; extensions use subdirectory paths |
| Removing manual workaround files before fix is verified | Low | Medium | Test deployment before removing manually committed files |

## Appendix

### Key File Locations

- Loader: `lua/neotex/plugins/ai/shared/extensions/loader.lua` (lines 181-222 for `copy_context_dirs`)
- Reference pattern: same file, lines 343-385 (`copy_docs`)
- Init caller: `lua/neotex/plugins/ai/shared/extensions/init.lua` (line 417)
- Core manifest: `.claude/extensions/core/manifest.json`
- Source context: `.claude/extensions/core/context/`
- Deployed context: `.claude/context/`

### Comparison: copy_context_dirs vs copy_docs

| Feature | copy_context_dirs | copy_docs |
|---------|-------------------|-----------|
| Directory entries | Yes | Yes |
| File entries | **No (bug)** | Yes |
| Recursive scan | Yes | Yes |
| Permission preservation | No | No |
