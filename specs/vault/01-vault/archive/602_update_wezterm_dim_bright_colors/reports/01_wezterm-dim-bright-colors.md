# Research Report: WezTerm Dim/Bright Color Palette Updates

**Task**: #602 - update_wezterm_dim_bright_colors
**Date**: 2026-05-22
**Status**: COMPLETE

## Executive Summary

The WezTerm configuration at `~/.dotfiles/config/wezterm.lua` already has a partial implementation of the dim/bright lifecycle color system, but the color values need improvement and the `update-status` handler incorrectly clears all `CLAUDE_STATUS` values (including lifecycle states) on tab switch rather than only clearing `needs_input`. The TTS announcement format currently says "Tab N STATUS" but the task requires "tab N workflow-type" (lowercase, without "Tab" capitalization). The file is managed by Home Manager via `home.file` symlinking `~/.dotfiles/config/wezterm.lua` to `~/.config/wezterm/wezterm.lua`; rebuilding via `home-manager switch --flake ~/.dotfiles` picks up changes.

---

## Findings

### 1. Current Color Palette (Lines 322–331 of wezterm.lua)

The `format-tab-title` handler already has a `status_colors` table with all eight lifecycle states:

```lua
local status_colors = {
  needs_input  = { bg = "#3a3a3a", fg = "#d0d0d0" },  -- gray
  researching  = { bg = "#1a3a1a", fg = "#607060" },   -- dim green (in progress)
  researched   = { bg = "#2a5a2a", fg = "#d0d0d0" },   -- bright green (done)
  planning     = { bg = "#1a1a3a", fg = "#606070" },   -- dim blue (in progress)
  planned      = { bg = "#2a2a6a", fg = "#d0d0d0" },   -- bright blue (done)
  implementing = { bg = "#3a3a1a", fg = "#707060" },   -- dim gold (in progress)
  completed    = { bg = "#5a5a2a", fg = "#d0d0d0" },   -- bright gold (done)
  blocked      = { bg = "#5a2a2a", fg = "#d0d0d0" },   -- red
}
```

**Problems with current values:**

- **Green** (`researching`/`researched`): The dim green (`#1a3a1a` bg, `#607060` fg) is nearly invisible — very dark background with muted green-gray foreground. The bright green (`#2a5a2a`) is still quite dark; it lacks the "bright/bold" visual pop needed for a finished state.
- **Blue** (`planning`/`planned`): The dim blue (`#1a1a3a` bg, `#606070` fg) has a blue-gray fg but the background is barely distinguishable from black. The bright blue (`#2a2a6a`) is similarly too dark.
- **Gold** (`implementing`/`completed`): The dim gold (`#3a3a1a` bg, `#707060` fg) foreground is a muddy gray-green, losing the gold hue. The bright gold (`#5a5a2a` bg) looks khaki/olive rather than gold.
- **Contrast ratio issue**: All in-progress states use very dark backgrounds (#1a..) with slightly-lighter mid-tone foregrounds — the visual difference between "no status" (#202020 bg, #808080 fg) and "in progress" states is small and inconsistent.

**Recommended improvements (see Section 5 for specific values).**

### 2. The `update-status` Handler Bug (Lines 401–425)

The current `update-status` event handler clears ALL `CLAUDE_STATUS` values whenever the user switches to a tab:

```lua
wezterm.on("update-status", function(window, pane)
  -- ...
  if last_active ~= tab_id then
    -- Tab changed! Check if new tab has CLAUDE_STATUS and clear it
    for _, tab_pane in ipairs(active_tab:panes()) do
      local user_vars = tab_pane:get_user_vars()
      if user_vars.CLAUDE_STATUS and user_vars.CLAUDE_STATUS ~= "" then
        -- Clear the user variable via OSC escape sequence
        tab_pane:inject_output("\027]1337;SetUserVar=CLAUDE_STATUS=\007")
      end
    end
    -- ...
  end
end)
```

**The bug**: This clears lifecycle states (`researched`, `planned`, `completed`, etc.) that should persist until the next command. The correct behavior per the task description is:
- **Only clear `needs_input`** on tab switch (this is the "attention needed" signal)
- **Preserve lifecycle states** (`researching`, `researched`, `planning`, `planned`, `implementing`, `completed`, `blocked`) until the next command overwrites them

**Fix**: Add a conditional check — only inject the clear sequence when `CLAUDE_STATUS == "needs_input"`.

### 3. TTS Announcement Format

**Current behavior** (`tts-notify.sh`, lines 112–116):
```bash
MESSAGE="$TAB_PREFIX $LIFECYCLE_STATUS"
speak "$MESSAGE"
```

This produces: `"Tab 4 researched"` (capital "Tab").

**Requested format**: `"tab 4 researched"` (lowercase, with tab-number before workflow-type).

The task description says: `"tab-number workflow-type (e.g. tab 4 researched)"` — so the fix is simply to use lowercase `"tab"` in the message construction.

**Location**: `tts-notify.sh` line 51 (`tab_prefix="Tab"` should be `"tab"`), and line 68 (`tab_prefix="Tab $tab_num"` should be `"tab $tab_num"`).

**Note**: The TTS script lives at `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh` (NOT in `~/.dotfiles`), so it is not Nix-managed and can be edited directly.

### 4. How WezTerm Config is Nix-Managed

From `home.nix` line 1124:
```nix
".config/wezterm/wezterm.lua".source = ./config/wezterm.lua;
```

This creates a symlink: `~/.config/wezterm/wezterm.lua` -> `~/.dotfiles/config/wezterm.lua`.

There is also a read-only copy at line 1186:
```nix
".config/config-files/wezterm.lua".text = builtins.readFile ./config/wezterm.lua;
```

The old `programs.wezterm` Home Manager module is commented out (lines 926–929).

**Rebuild command**:
```bash
home-manager switch --flake ~/.dotfiles
```

Since the active config is a `source` symlink (not a generated file), changes to `~/.dotfiles/config/wezterm.lua` are immediately live in WezTerm without a rebuild — WezTerm watches the config file. However, rebuilding is still needed to keep the Nix store in sync and generate the config-files copy.

### 5. Recommended Color Values

The task specifies: research=green, plan=blue, implement=gold. DIM for in-progress, BRIGHT/BOLD for finished.

The existing terminal color palette (from `config.colors`) provides reference anchors:
- Green: `#7e8d50` (ansi), `#7e8d50` (bright — same value; could use brighter variant)
- Yellow/Gold: `#e5b566` (ansi/bright)
- Blue: `#6c99ba` (ansi/bright)

**Proposed improved values** that maintain the dim→bright progression while staying readable:

| State | bg | fg | Notes |
|-------|----|----|-------|
| `needs_input` | `#3a3a3a` | `#d0d0d0` | Keep existing gray |
| `researching` | `#1e2e1e` | `#5a7a5a` | Dim green: dark bg, muted green fg |
| `researched` | `#1a4a1a` | `#a0d080` | Bright green: medium-dark bg, vivid green fg |
| `planning` | `#1a1e30` | `#5a6a8a` | Dim blue: dark bg, muted blue fg |
| `planned` | `#1a2a5a` | `#80a8d8` | Bright blue: medium-dark bg, vivid blue fg |
| `implementing` | `#2e2a18` | `#8a7a40` | Dim gold: dark bg, muted gold fg |
| `completed` | `#4a3e18` | `#e5c060` | Bright gold: medium-dark bg, vivid gold fg |
| `blocked` | `#5a2a2a` | `#d0d0d0` | Keep existing red |

**Key improvements over current**:
- All `fg` colors for in-progress states now have distinct hue (green/blue/gold) rather than gray-ish
- All finished-state `fg` values are bright/vivid rather than flat `#d0d0d0`
- Contrast between in-progress and finished states within the same hue family is more pronounced

### 6. Tab Title Format Consideration

The format-tab-title currently builds: `"<tab_number> <project_name>"` with optional `" #<task_num>"`. The TTS format `"tab 4 researched"` uses the same global position numbering that `get_global_tab_position()` produces for tab labels. These are already aligned — no changes needed to tab title display logic.

---

## Recommendations

### Change 1: Fix `update-status` handler to preserve lifecycle states

In `wezterm.lua`, change the tab-switch clearing logic to only clear `needs_input`:

```lua
wezterm.on("update-status", function(window, pane)
  local window_id = window:window_id()
  local active_tab = window:active_tab()
  local tab_id = active_tab:tab_id()
  local tracking = wezterm.GLOBAL.tab_tracking or {}
  local last_active = tracking[window_id]

  if last_active ~= tab_id then
    -- Tab changed! Only clear needs_input, preserve lifecycle states
    for _, tab_pane in ipairs(active_tab:panes()) do
      local user_vars = tab_pane:get_user_vars()
      if user_vars.CLAUDE_STATUS == "needs_input" then
        tab_pane:inject_output("\027]1337;SetUserVar=CLAUDE_STATUS=\007")
      end
    end
    tracking[window_id] = tab_id
    wezterm.GLOBAL.tab_tracking = tracking
  end
end)
```

### Change 2: Update color palette in `status_colors` table

Replace the existing `status_colors` table values with the improved values from Section 5. The table is at lines 322–331 of `~/.dotfiles/config/wezterm.lua`.

### Change 3: Fix TTS lowercase "tab" prefix

In `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh`, change lines 51 and 68:
- Line 51: `local tab_prefix="Tab"` → `local tab_prefix="tab"`
- Line 68: `tab_prefix="Tab $tab_num"` → `tab_prefix="tab $tab_num"`

This makes TTS speak `"tab 4 researched"` instead of `"Tab 4 researched"`.

### Change 4: Rebuild Home Manager after wezterm.lua changes

```bash
home-manager switch --flake ~/.dotfiles
```

WezTerm will auto-reload via its file watcher immediately after `wezterm.lua` is saved, so the visual changes are instant; the Home Manager rebuild is only needed to keep the Nix-managed copy in sync.

---

## Key Files

- **WezTerm config**: `/home/benjamin/.dotfiles/config/wezterm.lua`
- **Home Manager config**: `/home/benjamin/.dotfiles/home.nix` (line 1124 — source symlink)
- **WezTerm notify hook**: `/home/benjamin/.config/nvim/.claude/hooks/wezterm-notify.sh`
- **TTS notify hook**: `/home/benjamin/.config/nvim/.claude/hooks/tts-notify.sh`
- **Preflight status hook**: `/home/benjamin/.config/nvim/.claude/hooks/wezterm-preflight-status.sh`
- **Update-task-status script**: `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`

---

## References

- WezTerm `format-tab-title` event: https://wezfurlong.org/wezterm/config/lua/window-events/format-tab-title.html
- WezTerm `update-status` event: https://wezfurlong.org/wezterm/config/lua/window-events/update-status.html
- WezTerm OSC 1337 SetUserVar: https://wezfurlong.org/wezterm/config/lua/pane/get_user_vars.html
- Existing wezterm.lua color palette analysis (ansi/brights at lines 106–126)
- Task 601 commit context (simplify notification pipeline, merged vocabulary)
