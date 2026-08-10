# Research Report: Task #618

**Task**: 618 - Add reload option to extension picker
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:10:00Z
**Effort**: 30 minutes research
**Dependencies**: None
**Sources/Inputs**: Source files: picker/init.lua, picker/display/entries.lua, shared/extensions/init.lua, shared/picker/ai-tool-picker.lua
**Artifacts**: - specs/618_picker_reload_extensions/reports/01_picker-reload.md

## Executive Summary

- The picker's `<CR>` handler for loaded extensions directly calls `exts.unload()` without any submenu; adding a `vim.ui.select` submenu with Unload/Reload/Cancel is a targeted 10-line change in `picker/init.lua`
- A `reload()` function already exists in the shared extension manager at `shared/extensions/init.lua:690-714` and does unload-then-load without confirmation
- The `[Load All]` / `[Keyboard Shortcuts]` special entry pattern is already established; `[Reload All]` needs a new flag `is_reload_all` added in `entries.create_special_entries()` and a matching handler in `picker/init.lua`
- There is no `reload_all()` function; it must be implemented inline in the `is_reload_all` handler by iterating `list_loaded()` and calling `reload()` for each

## Context & Scope

The `<leader>al` keybinding opens a two-stage picker. Stage 1 (`ai-tool-picker.lua:show_commands_picker`) uses `vim.ui.select` to choose Claude or OpenCode, then runs `:ClaudeCommands`. Stage 2 is the Telescope picker in `picker/init.lua:show_commands_picker()`. This research covers only Stage 2 (the Telescope picker) which handles extension load/unload and all artifact navigation.

## Findings

### 1. Current Architecture (End-to-End Flow)

```
<leader>al
  -> ai-tool-picker.show_commands_picker()       [shared/picker/ai-tool-picker.lua:243]
    -> vim.ui.select (Claude | OpenCode)
    -> vim.cmd("ClaudeCommands")                 [or "OpencodeCommands"]
      -> picker/init.lua:show_commands_picker()
        -> entries.create_picker_entries(structure, config)
        -> pickers.new(...):find()
          -> attach_mappings() registers all key handlers
```

`create_picker_entries()` inserts entries in **reverse order** because `sorting_strategy = "descending"` makes the last-inserted item appear at the top. Special entries (including `[Keyboard Shortcuts]`) are inserted first (so they appear at the bottom of the visible list).

### 2. Extension `<CR>` Handler — Exact Current Code

Location: `picker/init.lua:161-179`

```lua
elseif selection.value.entry_type == "extension" then
  -- Cursor restore: only extension toggle needs this because the entry
  -- list is stable across load/unload. Other reopen cycles (Ctrl-l,
  -- Ctrl-u, Ctrl-s, Load All) change the list, so cursor reset is expected.
  local ext = selection.value
  actions.close(prompt_bufnr)
  local exts = require(extensions_module)
  if ext.status == "active" or ext.status == "update-available" then
    exts.unload(ext.name, { confirm = true })
  else
    exts.load(ext.name, { confirm = true })
  end
  vim.defer_fn(function()
    M.show_commands_picker(
      vim.tbl_extend("force", opts, { _restore_extension_name = ext.name }),
      config
    )
  end, 100)
end
```

**What needs to change**: The `exts.unload(ext.name, { confirm = true })` branch (for active/update-available extensions) must be replaced with a `vim.ui.select` submenu offering Unload/Reload/Cancel. The picker must already be closed before `vim.ui.select` appears (which the current code already does with `actions.close(prompt_bufnr)` before the condition).

### 3. Special Entries Pattern

Location: `picker/display/entries.lua:955-975` (`create_special_entries`) and `entries.create_picker_entries:986-1005`

**Current `create_special_entries()`** produces only one entry: `[Keyboard Shortcuts]` with `is_help = true`.

**`[Load All]` is NOT in `create_special_entries()`**. Reviewing `create_picker_entries()` carefully, `is_load_all` does not appear in `entries.lua` at all. It must be created elsewhere or it was a previous design note in the task description that hasn't been implemented yet. Searching the actual `create_picker_entries()` function (lines 982-1086), the only call to `create_special_entries` is at line 988, and the only special entry returned is `[Keyboard Shortcuts]`.

**Wait** — checking the `picker/init.lua` handler at line 111:

```lua
if selection.value.is_load_all then
  local loaded = sync.load_all_globally(config)
```

The `is_load_all` handler exists in `init.lua` but the entry creation is missing from `entries.lua`. This means either: (a) `[Load All]` was removed from entries but the handler was kept, or (b) it exists in the OpenCode version of entries. Either way, the **[Load All] entry pattern** described in the task description is the right template to follow for `[Reload All]`.

**How `[Keyboard Shortcuts]` is created** (lines 961-974):

```lua
table.insert(entries, {
  is_help = true,
  name = "~~~help",
  display = string.format(
    "%-40s %s",
    "[Keyboard Shortcuts]",
    "Help"
  ),
  command = nil,
  entry_type = "special",
  config = config,  -- Thread config for previewer access
})
```

Key properties:
- `is_help = true` — the sentinel flag checked in `init.lua:127`
- `name = "~~~help"` — tilde prefix sorts it to the bottom/special position
- `entry_type = "special"` — categorizes it
- `config = config` — threads config for previewer

**The `[Reload All]` entry** should follow the same pattern with `is_reload_all = true`.

**Insertion order for `[Reload All]` to appear just above `[Keyboard Shortcuts]`**: Since entries use descending sort, the last-inserted appears at the top. `[Keyboard Shortcuts]` is inserted first in `create_special_entries()`. To appear just above it (i.e., one position higher in the list = inserted one step later), `[Reload All]` must be inserted **after** `[Keyboard Shortcuts]` in the entries array. This means in `create_special_entries()`, `[Keyboard Shortcuts]` is added first, then `[Reload All]` is added second.

### 4. Extension Manager API

Location: `shared/extensions/init.lua` (the `manager` returned by `M.create()`)

Available functions:

| Function | Signature | Behavior |
|----------|-----------|----------|
| `load(name, opts)` | `opts = {confirm, project_dir, force}` | Loads ext, handles deps, optional confirm dialog |
| `unload(name, opts)` | `opts = {confirm, project_dir}` | Removes files, optional confirm dialog |
| `reload(name, opts)` | `opts = {project_dir}` | Unload (no confirm) then load (no confirm), shows "Reloaded" notify |
| `get_status(name, dir)` | string | Returns "active", "inactive", "update-available" |
| `list_available()` | table | All extensions with status |
| `list_loaded(dir)` | table | Array of loaded extension name strings |
| `get_details(name)` | table | Full extension info |
| `verify(name, dir)` | table | Verification report |
| `verify_all(dir)` | table | All loaded extension verification |

**No `reload_all()` function exists.** The reload-all operation must be implemented as a loop in `picker/init.lua`.

**`reload()` signature** (lines 690-714):
```lua
function manager.reload(extension_name, opts)
  opts = opts or {}
  local project_dir = opts.project_dir or vim.fn.getcwd()
  -- checks is_loaded, then calls unload({confirm=false}) then load({confirm=false})
  helpers.notify(string.format("Reloaded extension '%s'", extension_name), "INFO")
  return true, nil
end
```

The `reload()` function does NOT accept a `confirm` parameter — it always runs without confirmation dialogs. This is appropriate for the `[Reload All]` operation which should confirm once at the top level.

### 5. Core System Loading

The "core agent system" is itself an extension named `"core"`. It is loaded/unloaded using the same `manager.load("core", ...)` / `manager.unload("core", ...)` / `manager.reload("core", ...)` API. It is visible in `list_loaded()` when active.

Important constraint from `unload()` (line 580-607): unloading an extension fails if other loaded extensions depend on it. The `"core"` extension is typically a dependency of other extensions. Therefore, **reload-all must unload in dependency-safe order** (dependents before dependencies), or use `reload()` directly on each extension (which internally calls `unload` without dependency check concern since `reload` does a private unload then load of the same extension without needing to worry about inter-extension deps if all are being reloaded).

Actually, reviewing `reload()` more carefully: it calls `manager.unload(extension_name, { confirm = false })` which DOES check dependents (line 580-606). If `core` is a dependency of another loaded extension, `manager.unload("core")` will fail with "required by loaded extension(s)".

**Solution for reload-all**: Must reload in reverse-dependency order. The simplest safe approach is to reload each extension independently using `manager.reload()`, processing non-core extensions first, then core last. Or: collect all loaded names, reload them in order. Since `manager.reload()` calls unload then load sequentially, if we reload in the correct order (leaf extensions before core), each unload call will succeed because the dependent being unloaded first eliminates the dependency block.

**Safe reload-all order**: Use `list_loaded()`, sort so "core" is last, then call `manager.reload()` on each.

### 6. Proposed Changes

#### Feature 1: Submenu for loaded extensions

**File**: `lua/neotex/plugins/ai/claude/commands/picker/init.lua`
**Location**: Lines 161-179 (the `entry_type == "extension"` branch)

Replace the direct `exts.unload()` call with a `vim.ui.select` submenu. The key insight is that `actions.close(prompt_bufnr)` must happen before `vim.ui.select` is called (Telescope and vim.ui don't compose well simultaneously). The current code already closes before the condition check.

```lua
elseif selection.value.entry_type == "extension" then
  local ext = selection.value
  actions.close(prompt_bufnr)
  local exts = require(extensions_module)
  if ext.status == "active" or ext.status == "update-available" then
    -- Show submenu for already-loaded extensions
    vim.schedule(function()
      vim.ui.select(
        { "Unload", "Reload", "Cancel" },
        { prompt = "Extension: " .. ext.name },
        function(choice)
          if choice == "Unload" then
            exts.unload(ext.name, { confirm = true })
          elseif choice == "Reload" then
            exts.reload(ext.name, {})
          end
          -- Always reopen picker (even on Cancel, to restore state)
          vim.defer_fn(function()
            M.show_commands_picker(
              vim.tbl_extend("force", opts, { _restore_extension_name = ext.name }),
              config
            )
          end, 100)
        end
      )
    end)
  else
    exts.load(ext.name, { confirm = true })
    vim.defer_fn(function()
      M.show_commands_picker(
        vim.tbl_extend("force", opts, { _restore_extension_name = ext.name }),
        config
      )
    end, 100)
  end
end
```

**Note**: `vim.schedule()` wraps the `vim.ui.select` call because Telescope's `actions.close` schedules a window close asynchronously — without `vim.schedule`, `vim.ui.select` may appear before the picker window actually closes. The reopen `vim.defer_fn` is moved inside the `vim.ui.select` callback so it runs after the user makes a choice regardless of which option.

#### Feature 2: `[Reload All]` special entry

**File**: `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
**Location**: `create_special_entries()` starting at line 958

Add the `[Reload All]` entry after `[Keyboard Shortcuts]`:

```lua
function M.create_special_entries(config)
  local entries = {}

  -- [Keyboard Shortcuts] — appears at very bottom (inserted first with descending sort)
  table.insert(entries, {
    is_help = true,
    name = "~~~help",
    display = string.format("%-40s %s", "[Keyboard Shortcuts]", "Help"),
    command = nil,
    entry_type = "special",
    config = config,
  })

  -- [Reload All] — appears just above [Keyboard Shortcuts] (inserted second)
  table.insert(entries, {
    is_reload_all = true,
    name = "~~~reload_all",
    display = string.format("%-40s %s", "[Reload All]", "Wipe and reload all loaded extensions"),
    command = nil,
    entry_type = "special",
    config = config,
  })

  return entries
end
```

**File**: `lua/neotex/plugins/ai/claude/commands/picker/init.lua`
**Location**: After the `is_load_all` handler (around line 124), add before `is_help` check

```lua
-- Reload All special entry
if selection.value.is_reload_all then
  local exts = require(extensions_module)
  local loaded = exts.list_loaded()
  if #loaded == 0 then
    -- Nothing to reload
    return
  end
  actions.close(prompt_bufnr)
  vim.schedule(function()
    -- Sort: core last (so dependents are reloaded first)
    table.sort(loaded, function(a, b)
      if a == "core" then return false end
      if b == "core" then return true end
      return a < b
    end)
    local success_count = 0
    for _, ext_name in ipairs(loaded) do
      local ok, err = exts.reload(ext_name, {})
      if ok then
        success_count = success_count + 1
      else
        vim.notify("Failed to reload '" .. ext_name .. "': " .. (err or "unknown"), vim.log.levels.WARN)
      end
    end
    vim.notify(string.format("Reloaded %d extension(s)", success_count), vim.log.levels.INFO)
    vim.defer_fn(function()
      M.show_commands_picker(opts, config)
    end, 100)
  end)
  return
end
```

Also add a guard in `Ctrl-l`, `Ctrl-u`, `Ctrl-s`, `Ctrl-e` handlers (which already check `is_load_all`) to also skip `is_reload_all` entries:

```lua
-- Current guard pattern (lines 185, 209, 234, 258):
if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_heading then
-- Becomes:
if not selection or selection.value.is_help or selection.value.is_load_all or selection.value.is_reload_all or selection.value.is_heading then
```

### 7. Ordinal/Sort Ordering

The existing special entry `[Keyboard Shortcuts]` uses `name = "~~~help"`. The tilde characters (`~`) sort after all alphanumeric characters in ASCII, placing them last in any ascending sort (or first in the `sorting_strategy = "descending"` picker). The new `[Reload All]` entry uses `name = "~~~reload_all"` which sorts after `"~~~help"` lexicographically (`r` > `h`), so with descending sort, `"~~~reload_all"` appears **above** `"~~~help"` in the visual list — which is exactly what we want.

Note: The entries don't use the `ordinal` field for the sort key directly; they use the `ordinal` field computed in `entry_maker` as `name .. " " .. description`. Since `~~~reload_all` > `~~~help`, reload_all appears higher (closer to top). Confirmed correct.

## Decisions

- Use `vim.ui.select` for the submenu (consistent with Stage 1 picker; minimal new dependencies)
- Use `vim.schedule()` to delay `vim.ui.select` until after Telescope window teardown completes
- Always reopen the picker after a submenu action (including Cancel) to maintain good UX
- No separate confirmation dialog for `reload()` — the submenu choice "Reload" IS the confirmation
- For `[Reload All]`: no top-level `vim.fn.confirm()` dialog needed; the entry name is self-documenting and the operation is quick. If a per-extension failure occurs, show a warning per extension but continue
- Reload-all does not perform a single top-level confirm dialog (unlike `unload` which shows file counts). This is intentional: reload is non-destructive (files are preserved, just re-copied from source)
- Sort order: non-core extensions first, core last — prevents dependency-check failures during sequential reload

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| `vim.ui.select` appears before Telescope window closes | Medium | Wrap in `vim.schedule()` |
| Reload ordering fails (core reloaded while dependents loaded) | Low | Sort core last in reload-all loop |
| `manager.reload()` fails mid-loop for reload-all | Low | Continue loop, collect errors, show summary notify |
| `is_reload_all` entry not skipped by Ctrl-l/Ctrl-u/Ctrl-s/Ctrl-e | Medium | Add `is_reload_all` to all four guard conditions |
| Picker reopens too fast after reload-all (race condition) | Low | The 100ms `vim.defer_fn` already handles this; reload operations are synchronous |
| Extension with dependents fails unload during `reload()` | Low | `reload()` calls private `unload` which checks dependents; sorting ensures non-core reloaded before core; within extension-to-extension deps the user is responsible for ordering or we just let it fail gracefully with a warning |

## Context Extension Recommendations

- **Topic**: vim.ui.select composition with Telescope
- **Gap**: `neovim-api.md` does not document the `vim.schedule()` requirement when using `vim.ui.select` after closing a Telescope picker
- **Recommendation**: Add a note to `domain/neovim-api.md` about async window teardown requiring `vim.schedule()` before `vim.ui.select`

## Appendix

### Files to Modify

1. `lua/neotex/plugins/ai/claude/commands/picker/init.lua`
   - Lines 161-179: Replace direct unload with vim.ui.select submenu
   - Around line 124: Add `is_reload_all` handler
   - Lines 185, 209, 234, 258: Add `is_reload_all` to guard conditions

2. `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
   - Lines 958-975 (`create_special_entries`): Add `[Reload All]` entry after `[Keyboard Shortcuts]`

### Key API Reference

- Extension manager API: `neotex.plugins.ai.claude.extensions` (delegates to `shared.extensions`)
- `manager.reload(name, opts)`: unload without confirm + load without confirm, returns `(bool, err)`
- `manager.list_loaded()`: returns array of loaded extension name strings
- `manager.unload(name, opts)`: opts.confirm defaults to true; blocks on dependents
- `manager.load(name, opts)`: opts.confirm defaults to true; handles deps recursively

### Descending Sort Reference

`sorting_strategy = "descending"` + `default_selection_index = 2` means:
- Last entry inserted = appears at TOP of picker
- Ordinal strings are sorted descending: `z` > `a` means `z` appears first
- `~~~` prefix ensures special entries sort last in ascending = first (top) in descending... **wait**

Actually re-examining: the `[Commands]` section entries appear at the top because they are inserted **last** in `create_picker_entries()` (line 1082). The `create_special_entries()` entries are inserted **first** (line 988-991), so they appear at the **bottom**. This is consistent with `[Keyboard Shortcuts]` being at the very bottom of the picker list.

For `[Reload All]` to appear just **above** `[Keyboard Shortcuts]`, it needs to be inserted **after** `[Keyboard Shortcuts]` in the entries array (since later-inserted = higher in visual list with descending sort). The proposed code inserts `[Keyboard Shortcuts]` first, then `[Reload All]` second in `create_special_entries()`, which is correct.
