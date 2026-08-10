# Research Report: Task #619

**Task**: 619 - syncprotect_aware_extension_verification
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:30:00Z
**Effort**: Small (3 focused changes, ~60 lines total)
**Dependencies**: None
**Sources/Inputs**: verify.lua, loader.lua, init.lua, config.lua, state.lua, .syncprotect files
**Artifacts**: This report
**Standards**: report-format.md, neovim-lua.md

---

## Executive Summary

- **Root cause of false warnings**: `verify_rules()` and `verify_context()` do not receive the
  `protected_paths` set, so they flag protected files as missing.
- **Root cause of false legacy detection**: `detect_legacy_core()` flags ANY `.md` file in
  `.claude/agents/` as legacy core, but files installed by other extensions (nvim, nix, etc.)
  also live there and are not legacy.
- **Shared helper**: `load_syncprotect()` already lives in `loader.lua` as a public function.
  The cleanest fix is to pass `protected_paths` as a new parameter to `verify_extension()`,
  avoiding any new module dependency for `verify.lua`.
- All three changes are minimal, low-risk, and localized to `verify.lua` and `init.lua`.

---

## Context & Scope

The extension system loads files from a global extensions directory into project-local `.claude/`
or `.opencode/` directories. After loading, `verify_extension()` checks that all declared files
exist on disk. `.syncprotect` lists files that the extension system must NOT overwrite during sync
(user-customized files). These protected files are intentionally absent from the synced copy but
still declared in extension manifests. This causes false-positive warnings.

A second bug in `detect_legacy_core()` in `init.lua` is unrelated to syncprotect but tightly
coupled by scope: it misidentifies extension-managed agent files as legacy core artifacts.

---

## Findings

### 1. `verify_rules()` — Current Implementation

**File**: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
**Lines**: 119–144

```lua
local function verify_rules(manifest, target_dir)
  local results = { checked = 0, missing = {} }
  if not manifest.provides or not manifest.provides.rules then return results end
  local rules_dir = target_dir .. "/rules"
  for _, rule_name in ipairs(manifest.provides.rules) do
    results.checked = results.checked + 1
    local rule_path = rules_dir .. "/" .. rule_name
    if not file_exists(rule_path) then
      table.insert(results.missing, rule_name)
    end
  end
  return results
end
```

**Return type**: `{ checked = number, missing = string[] }`

**What needs to change**: Accept `protected_paths` table as third parameter. Before adding to
`missing`, check if `"rules/" .. rule_name` is a key in `protected_paths`. If yes, add to a new
`protected` array instead of `missing`.

**Path format**: The syncprotect entry for `plan-format-enforcement.md` is
`rules/plan-format-enforcement.md`. This matches `"rules/" .. rule_name`, confirmed by comparing
against `copy_simple_files` which uses `rel_path = target_category_name .. "/" .. filename`.

**Updated return type**: `{ checked = number, missing = string[], protected = string[] }`

---

### 2. `verify_context()` — Current Implementation

**File**: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
**Lines**: 150–175

```lua
local function verify_context(extension_dir, target_dir)
  local results = { checked = 0, missing = {} }
  -- reads extension_dir/index-entries.json
  local context_dir = target_dir .. "/context"
  for _, entry in ipairs(index_data.entries) do
    results.checked = results.checked + 1
    local normalized_path = normalize_index_path(entry.path)
    local context_path = context_dir .. "/" .. normalized_path
    if not file_exists(context_path) then
      table.insert(results.missing, entry.path)
    end
  end
  return results
end
```

**Return type**: `{ checked = number, missing = string[] }`

**What needs to change**: Accept `protected_paths` table as third parameter. Before adding to
`missing`, check if `"context/" .. normalized_path` is a key in `protected_paths`. If yes, add to
`protected` instead.

**Path format**: The syncprotect entry for `repo/project-overview.md` is
`context/repo/project-overview.md`. The normalized index path is `repo/project-overview.md`.
So the check must prepend `"context/"` to the normalized path, giving
`"context/" .. normalized_path`. This matches the `rel_path` format used in
`copy_context_dirs()`: `"context/" .. context_path .. "/" .. file_rel_path`.

**Important**: The `entry.path` stored in `missing` uses the original (un-normalized) path. The
syncprotect check uses the normalized path. Both are needed: normalized for lookup, original
for error reporting.

**Updated return type**: `{ checked = number, missing = string[], protected = string[] }`

---

### 3. `verify_extension()` — Caller and Results Consumer

**File**: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
**Lines**: 348–483

**Current signature**:
```lua
function M.verify_extension(extension_name, extension_dir, target_dir, config)
```

**Change**: Add `protected_paths` as fifth parameter (optional, defaults to `{}`):
```lua
function M.verify_extension(extension_name, extension_dir, target_dir, config, protected_paths)
  protected_paths = protected_paths or {}
```

Pass `protected_paths` through to `verify_rules()` and `verify_context()`.

**Results consumption** (lines 405–434): Currently, any item in `results.missing` is added to
`verification.errors`. With the change, `results.protected` items should NOT be added to errors
and should NOT affect `verification.status`.

The updated rule verification block (lines 405–415) should become:
```lua
local rule_results = verify_rules(manifest, target_dir, protected_paths)
if #rule_results.missing > 0 then
  verification.rules = { passed = false, checked = rule_results.checked, missing = rule_results.missing }
  for _, rule in ipairs(rule_results.missing) do
    table.insert(verification.errors, "Missing rule: " .. rule)
  end
end
-- Protected rules do not generate errors or warnings
```

Similarly for context verification (lines 417–434).

**Status logic** (lines 472–479): No change needed. Protected items never reach `verification.errors`,
so the status logic remains correct. Rules/context failures remain as "warnings" (non-critical);
agents/skills failures remain as "failed" (critical).

---

### 4. `load_syncprotect()` — Extraction Plan

**File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`
**Lines**: 16–44

**Current signature**:
```lua
function M.load_syncprotect(project_dir, base_dir)
```

**Return type**: `{ [relative_path] = true }` — a set of protected relative paths.

**The function**:
- Tries `{project_dir}/.syncprotect` first (canonical)
- Falls back to `{project_dir}/{base_dir}/.syncprotect` (legacy)
- Skips blank lines and `#` comment lines
- Returns empty table `{}` if no file exists

**Extraction decision**: Do NOT create a new `helpers.lua`. The cleanest approach is:

**Option D (recommended)**: Pass `protected_paths` as a parameter to `verify_extension()`.
- `init.lua` already computes `protected_paths` at line 373 via `loader_mod.load_syncprotect()`
- Pass it when calling `verify_mod.verify_extension()` at line 545
- For `manager.verify()` (line 825), compute protected_paths there too using `loader_mod.load_syncprotect()`
- `verify.lua` remains dependency-free (no new `require` statements)
- No code duplication, no new module

This is simpler than creating a shared `helpers.lua` and avoids making `verify.lua` depend on
`loader.lua` (which depends on picker utils, creating a potentially deep dependency chain).

---

### 5. `detect_legacy_core()` — Current Implementation

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`
**Lines**: 164–206

```lua
local function detect_legacy_core(project_dir, config)
  local target_dir = project_dir .. "/" .. config.base_dir
  local state = state_mod.read(project_dir, config)
  if state_mod.is_loaded(state, "core") then
    return false, nil
  end
  local agents_dir = target_dir .. "/agents"
  if vim.fn.isdirectory(agents_dir) == 1 then
    local handle = vim.loop.fs_scandir(agents_dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if type == "file" and name:match("%.md$") and name ~= ".gitkeep" then
          return true, string.format("Legacy core detected: '%s/%s' ...", agents_dir, name)
        end
      end
    end
  end
  return false, nil
end
```

**The bug**: It flags `port-agent.md`, `neovim-research-agent.md`, etc. because they are `.md`
files in `.claude/agents/` but were installed by other extensions (nvim, nix, etc.), not by a
legacy (pre-migration) core installation.

**Call site** (`init.lua` line 245–257): `detect_legacy_core()` is called only when
`extension_name == "core"`. At this point, `ext_manifest` (core's manifest) is already in scope
(loaded at line 232: `local ext_manifest = extension.manifest`).

**The fix**: Add `ext_manifest` as a parameter. Build a set from `ext_manifest.provides.agents`.
Only flag files that ARE in that set:

```lua
local function detect_legacy_core(project_dir, config, core_manifest)
  -- ... (unchanged preamble) ...
  -- Build set of filenames declared by core extension
  local core_agents = {}
  if core_manifest and core_manifest.provides and core_manifest.provides.agents then
    for _, agent_file in ipairs(core_manifest.provides.agents) do
      core_agents[agent_file] = true
    end
  end

  local agents_dir = target_dir .. "/agents"
  if vim.fn.isdirectory(agents_dir) == 1 then
    local handle = vim.loop.fs_scandir(agents_dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        -- Only flag files declared in core's manifest (not extension-managed agents)
        if type == "file" and name:match("%.md$") and name ~= ".gitkeep"
            and core_agents[name] then
          return true, string.format("Legacy core detected: '%s/%s' ...", agents_dir, name)
        end
      end
    end
  end
  return false, nil
end
```

**Updated call site** (line 246):
```lua
local is_legacy, legacy_detail = detect_legacy_core(project_dir, config, ext_manifest)
```

**Core agents list** (from manifest at `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json`):
- `code-reviewer-agent.md`
- `general-implementation-agent.md`
- `general-research-agent.md`
- `meta-builder-agent.md`
- `planner-agent.md`
- `reviser-agent.md`
- `spawn-agent.md`

Files like `neovim-research-agent.md`, `nix-research-agent.md`, `port-agent.md`, `synthesis-agent.md`
are NOT in this list and will no longer trigger false positives.

**Edge case**: If `core_agents` is empty (empty manifest or nil), the function returns `false, nil`.
This is safe: if core has no declared agents, there can be no legacy core artifacts.

---

### 6. Call Sites Summary

**`manager.load()` in `init.lua`**:
- Line 373: `protected_paths` already computed via `loader_mod.load_syncprotect(project_dir, config.base_dir)`
- Line 545: `verify_mod.verify_extension(extension_name, source_dir, target_dir, config)` → add `protected_paths` as 5th arg
- Line 246: `detect_legacy_core(project_dir, config)` → add `ext_manifest` as 3rd arg

**`manager.verify()` in `init.lua`** (lines 811–826):
- Need to compute `protected_paths` before calling `verify_extension`
- Add: `local protected_paths = loader_mod.load_syncprotect(project_dir, config.base_dir)`
- Line 825: `verify_mod.verify_extension(extension_name, extension.path, target_dir, config)` → add `protected_paths`

---

## Decisions

- **No new `helpers.lua`**: Passing `protected_paths` as a parameter is cleaner than creating a
  new shared module. `verify.lua` stays dependency-free.
- **No syncprotect for agents/skills**: These are critical failures when missing. Protected files
  in these categories would indicate a configuration error, not a user customization. The task
  description only mentions rules and context as producing false warnings.
- **Silent protection**: Protected files produce no output (no "Protected: X" line in the report).
  The `verify.lua` format_report and notify_results functions need no changes.
- **Backward compatible**: `protected_paths` is optional in `verify_extension()` (defaults to `{}`),
  so external callers (if any) need no changes. Currently there are no external callers.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `entry.path` vs normalized path mismatch in `verify_context` | Use normalized path for syncprotect lookup, keep original for `missing` array |
| `core_agents` set is empty if manifest format changes | Guard with `if core_manifest and ...` check; returns `false` (no legacy) which is safe |
| `manager.verify()` called without project_dir | It defaults to `vim.fn.getcwd()` — `load_syncprotect()` will use that, consistent with load behavior |
| `.syncprotect` file not found | `load_syncprotect()` already returns `{}` (empty table) gracefully |
| Rules with subdirectory paths | Core rules are flat filenames. If a rule were `subdir/name.md`, `"rules/" .. rule_name` would still match the syncprotect entry format from `copy_simple_files` |

---

## Specific Change Locations

| File | Function | Lines | Change |
|------|----------|-------|--------|
| `verify.lua` | `verify_rules()` | 123–144 | Add `protected_paths` param; split into `missing`/`protected` |
| `verify.lua` | `verify_context()` | 150–175 | Add `protected_paths` param; split into `missing`/`protected` |
| `verify.lua` | `M.verify_extension()` | 348, 405–415, 417–434 | Add optional `protected_paths` param; pass to sub-functions |
| `init.lua` | `detect_legacy_core()` | 173–206 | Add `core_manifest` param; filter to core agents only |
| `init.lua` | `manager.load()` | 246 | Pass `ext_manifest` to `detect_legacy_core()` |
| `init.lua` | `manager.load()` | 545 | Pass `protected_paths` to `verify_mod.verify_extension()` |
| `init.lua` | `manager.verify()` | 811–826 | Compute `protected_paths`; pass to `verify_extension()` |

---

## Context Extension Recommendations

- **Topic**: syncprotect interaction with verification
- **Gap**: No existing context documents the `.syncprotect` file format or its interaction with
  the verification pipeline. The behavior difference between "missing" and "protected" is implicit.
- **Recommendation**: Could add a brief section to `extension-development.md` or a new
  `syncprotect-guide.md` once the implementation is stable.
