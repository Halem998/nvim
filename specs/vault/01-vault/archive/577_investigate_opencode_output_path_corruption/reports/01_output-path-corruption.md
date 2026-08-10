# Research Report: OpenCode Output Path Corruption

- **Task**: 577 - investigate_opencode_output_path_corruption
- **Started**: 2026-05-14T23:25:00Z
- **Completed**: 2026-05-14T23:55:00Z
- **Effort**: ~30 minutes
- **Dependencies**: Task 572 (OpenCode routing failure diagnosis), Task 574 (temp file fix)
- **Sources/Inputs**:
  - `/home/benjamin/.config/nvim/.opencode/output/implement.md` — Corrupted output file
  - `/home/benjamin/.config/nvim/.opencode/commands/plan.md` — Active plan command (has COMMAND EXECUTION MODE preamble)
  - `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/plan.md` — Core extension source (MISSING preamble)
  - `/home/benjamin/.dotfiles/.opencode/commands/plan.md` — Dotfiles installed plan command
  - `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/loader.lua` — Extension file copy engine
  - `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua` — Extension manager (reload flow)
  - `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode.lua` — OpenCode plugin config (snacks.terminal usage)
  - `/home/benjamin/.local/share/nvim/lazy/opencode.nvim/lua/opencode/server/init.lua` — opencode.nvim cwd matching
  - `specs/572_diagnose_opencode_lean_routing_failure/reports/01_opencode-routing-diagnosis.md` — Prior diagnosis
  - `/home/benjamin/.config/nvim/.syncprotect` — Sync protection file
- **Artifacts**:
  - `specs/577_investigate_opencode_output_path_corruption/reports/01_output-path-corruption.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

---

## Executive Summary

- **Root cause**: The core extension source files (`~/.config/nvim/.opencode/extensions/core/commands/`) are MISSING the `COMMAND EXECUTION MODE` preamble and the routing fix (`git rev-parse --show-toplevel`) that were added to the active command files in `~/.config/nvim/.opencode/commands/`. When the user reloads the core extension via `<leader>al`, the extension loader OVERWRITES the improved active commands with the outdated extension source files, stripping these critical improvements.
- **Secondary mechanism**: The `output/implement.md` file is OpenCode's session export (written when `<leader>x` is pressed in the TUI). The file being at `~/.config/nvim/.opencode/output/` confirms OpenCode was running with `cwd=~/.config/nvim/` rather than `~/.dotfiles/`, which itself is a CWD mismatch problem when OpenCode is launched via the Neovim snacks.terminal plugin.
- **Scope**: ALL 15 core commands lack the COMMAND EXECUTION MODE preamble in the extension source. Three commands (`implement.md`, `plan.md`, `research.md`) also lack the absolute-path routing fix.
- **Effect**: After extension reload, commands revert to describe-instead-of-execute behavior (LLM describes command content rather than executing it), and extension-typed tasks silently fall back to general agents.
- **Protection gap**: The `.syncprotect` file is honored by the sync operation but NOT by the extension loader, so no protection mechanism prevents the reload from overwriting improved command files.

---

## Context & Scope

### What Was Investigated

The user reports that after reloading the `.opencode/` agent system in `~/.dotfiles/` via the Neovim `<leader>al` extension loader, running `/plan 57` produces output at `~/.config/nvim/.opencode/output/implement.md` rather than the expected `specs/` artifact path. Task 572 previously diagnosed a similar routing failure in the ProofChecker project. Task 574 fixed `/tmp/` usage in temp file patterns.

This investigation examined:
1. The content and origin of `output/implement.md`
2. The extension reload mechanism (`<leader>al` -> `OpencodeExtensions`)
3. The difference between active command files and extension source files
4. The `output/` directory purpose and write mechanism
5. The CWD relationship between Neovim and the OpenCode TUI

### Constraints

- Diagnostic only — no code changes made during this research
- The failing session output is already captured at `~/.config/nvim/.opencode/output/implement.md`
- Task 57 in `~/.dotfiles/specs/` already has a plan (status: `planned`)

---

## Findings

### Finding 1: The Core Extension Source Files Are Missing Critical Improvements

The active command files in `~/.config/nvim/.opencode/commands/` have been improved over time, but the core extension SOURCE files in `~/.config/nvim/.opencode/extensions/core/commands/` were never updated to match. The following improvements exist only in the active files, NOT the extension source:

**COMMAND EXECUTION MODE preamble** (ALL 15 commands affected):
```
> **COMMAND EXECUTION MODE** — You have been invoked as this command with arguments: `$ARGUMENTS`. Execute the workflow below immediately. Do not summarize this file, ask what to do with it, or describe its contents. Start execution now.
```

**Absolute path routing fix** (`implement.md`, `plan.md`, `research.md`):
```bash
# MISSING from extension source (uses relative path, broken in OpenCode):
for manifest in .opencode/extensions/*/manifest.json; do

# In active command files (works correctly):
project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
manifest_dir="$project_root/.opencode/extensions"
for manifest in "$manifest_dir"/*/manifest.json; do
```

Confirmed by diff: ALL 15 commands differ between active and extension source.

### Finding 2: Extension Reload Overwrites Active Commands with Outdated Source

When the user runs `<leader>al` -> selects OpenCode -> reloads the core extension:

1. Extension loader calls `loader_mod.copy_simple_files()` for the "commands" category
2. Source: `~/.config/nvim/.opencode/extensions/core/commands/plan.md` (OLD, missing preamble)
3. Target: `~/.config/nvim/.opencode/commands/plan.md` (NEW, has preamble)
4. The loader unconditionally copies and **overwrites** the target

The `copy_file()` function in `loader.lua` has no version checking, no conflict detection for locally-modified files, and no protection for files improved outside the extension system. It simply reads the source and writes the target.

Key code (in `loader.lua`, line 14-37):
```lua
local function copy_file(source_path, target_path, preserve_perms)
  local content = helpers.read_file(source_path)
  if not content then return false end
  local success = helpers.write_file(target_path, content)  -- unconditional overwrite
  ...
end
```

### Finding 3: The `output/` Directory Is OpenCode's Session Export Location

The `~/.config/nvim/.opencode/output/` directory was created on May 7 and contains `implement.md`. The content of this file is:

1. The `plan.md` command body with `$1` substituted as `57` (argument rendered by OpenCode)
2. Followed by the model's confused response ("What would you like me to do with this specification?")

This is NOT a corrupted artifact path. This is OpenCode's **session export** feature (`<leader>x` in the TUI = `session_export` keybinding). The session export writes the conversation to `.opencode/output/{command-name}.md`. The file being named `implement.md` suggests the export was triggered during a previous `/implement` session (or the export uses the last command name from the session).

The file path confirms that **OpenCode was running with `cwd=~/.config/nvim/`** at the time, not `~/.dotfiles/`.

### Finding 4: OpenCode Inherits Neovim's CWD via snacks.terminal

The OpenCode Neovim plugin (`opencode.lua`) launches OpenCode via:
```lua
local attach_cmd = "opencode --port 3000"
require("snacks.terminal").open(attach_cmd, opencode_win_opts)
```

The `snacks.terminal` API uses `vim.fn.getcwd(0)` as the default cwd for the terminal. From snacks.nvim source (`terminal.lua`, line 180):
```lua
cwd = opts.cwd or vim.fn.getcwd(0),
```

No `cwd` override is passed in `opencode_win_opts`. Therefore, OpenCode starts with whatever Neovim's current working directory is at the moment the terminal is opened/toggled.

Additionally, `opencode.nvim` uses CWD to match running OpenCode servers to the current Neovim session (`server/init.lua`, line 374-378): it filters servers by whether `server.cwd` overlaps with `vim.fn.getcwd()`.

**The CWD mismatch scenario**:
1. User has Neovim open editing files in `~/.config/nvim/` (cwd = nvim config)
2. User presses `<leader>al` -> selects "Load Core Agent System" (sync from nvim to dotfiles)
3. Extension loader uses `vim.fn.getcwd()` = nvim cwd — but it's explicitly set to the target project
4. User then tries to work in OpenCode TUI
5. OpenCode TUI was already open (or gets opened) with cwd = `~/.config/nvim/`
6. Commands look for `specs/state.json` in `~/.config/nvim/specs/` — task 57 not found there
7. The model, without the COMMAND EXECUTION MODE preamble, describes the command instead of erroring
8. The response gets written as session export to `~/.config/nvim/.opencode/output/implement.md`

### Finding 5: The `.syncprotect` Mechanism Does Not Apply to Extension Reload

The `.syncprotect` file at `~/.config/nvim/.syncprotect` protects files during the "Load Core Agent System" sync operation (`sync.lua`). However:

- The sync operation reads `.syncprotect` and skips protected files
- The extension loader (`loader.lua` + `init.lua`) has NO `.syncprotect` integration
- Therefore, reloading the core extension via the extension picker bypasses all file protection

There is also no mechanism to detect that the target file has been locally modified relative to the extension source.

### Finding 6: This Is a Recurring Pattern

Task 572 documented the same root cause: the extension routing code (using relative Glob paths) was fixed in the active command files but never propagated back to the extension source. When child projects reload extensions, they get the unfixed version.

The same maintenance debt affects the COMMAND EXECUTION MODE preamble: it was added to active commands but the extension source was not updated. Every extension reload strips this critical preamble from the installed commands.

### Finding 7: The `output/` Directory Was Pre-Created by an Earlier Session

The `output/` directory was created on May 7 (as shown by `stat`). The `implement.md` file was written (or updated) on May 14 (today). This directory appears to have been created by an earlier failed OpenCode session operating in the nvim config context, establishing the pattern where session exports land there.

---

## Decisions

- The primary root cause is **extension source files not tracking active command improvements** — not a path corruption bug in the traditional sense
- The `output/implement.md` file is a session export, not a corrupted artifact path (terminology clarification)
- The CWD mismatch (OpenCode running in nvim config instead of dotfiles) is a contributing factor but secondary to the missing preamble
- All 15 core commands need to be updated in the extension source to match the active versions

---

## Recommendations

### Priority 1 (Immediate): Update Core Extension Source Commands

Copy all improved active command files back to the core extension source:

```bash
cp ~/.config/nvim/.opencode/commands/*.md \
   ~/.config/nvim/.opencode/extensions/core/commands/
```

Verify the manifest lists all commands, and verify the diff is clean after copying.

**Files to update** (all 15):
- `errors.md`, `fix-it.md`, `implement.md`, `merge.md`, `meta.md`, `plan.md`
- `project-overview.md`, `refresh.md`, `research.md`, `review.md`, `revise.md`
- `spawn.md`, `tag.md`, `task.md`, `todo.md`

After updating, any extension reload will copy the CURRENT (improved) versions rather than the outdated source versions.

### Priority 2 (Immediate): Prevent Future Drift with a Sync Script or CI Check

Create a validation script (`.opencode/scripts/validate-wiring.sh` or a new check) that compares active commands to extension source and warns when they diverge. This prevents the same maintenance debt from accumulating.

Possible approach:
```bash
#!/bin/bash
# check-command-sync.sh: ensure extension source matches active commands
for cmd in .opencode/commands/*.md; do
  name=$(basename "$cmd")
  src=".opencode/extensions/core/commands/$name"
  if [ -f "$src" ] && ! diff -q "$cmd" "$src" > /dev/null 2>&1; then
    echo "DRIFT: $name differs from core extension source"
  fi
done
```

### Priority 3 (Short-term): Add CWD Awareness to OpenCode Plugin Launch

Pass an explicit `cwd` to the snacks.terminal when launching OpenCode. The cwd should be derived from the project context, not inherited from Neovim's arbitrary current buffer:

```lua
local opencode_win_opts = {
  win = {
    position = "right",
    width = 0.40,
    enter = true,
    cwd = vim.fn.getcwd(),  -- explicit, or derive from project root
    on_win = function(win)
      require("opencode.terminal").setup(win.win)
    end,
  },
}
```

A more robust solution would be to detect the git project root from the current buffer file path and use that as the cwd, ensuring OpenCode always starts in the correct project context.

### Priority 4 (Medium-term): Add `.syncprotect`-Style Protection to Extension Loader

Extend the extension loader to respect `.syncprotect` when overwriting existing files. Files listed in `.syncprotect` should be skipped during extension reload just as they are during sync operations. This prevents accidental overwrite of locally-customized files.

### Priority 5 (Medium-term): Propagate Fixed Commands to All Child Projects

The same drift issue affects child project command files. After fixing the core extension source, reload the core extension in each child project to propagate the fixes:
- `~/.dotfiles/.opencode/` — current project
- Other child projects (ProofChecker, OpenCode, Zed, ModelChecker, protocol) — if applicable

---

## Risks & Mitigations

- **Immediate re-occurrence**: If the user reloads the core extension before Priority 1 is implemented, the commands will be overwritten again. Mitigation: Implement Priority 1 as the first action.
- **Extension manifest needs updating**: The core extension manifest must include any new command files (e.g., `distill.md`, `learn.md` if they exist). Check for commands in active directory not in manifest.
- **CWD mismatch is masked**: Without the COMMAND EXECUTION MODE preamble, failures are silent (model describes instead of errors). With the preamble restored, failures become explicit errors when task 57 is not found in the wrong `state.json`. This is actually better behavior.

---

## Context Extension Recommendations

- **Topic**: Extension source vs. active file drift
- **Gap**: No documentation exists explaining the relationship between `~/.opencode/commands/` (active files) and `~/.opencode/extensions/core/commands/` (source files), or the risk of drift when active files are modified directly.
- **Recommendation**: Add a note to `.opencode/context/patterns/extension-lifecycle.md` (or create it) documenting: (1) active files are installed FROM extension source, (2) improvements to active files must be backported to extension source, (3) the `check-command-sync.sh` script validates alignment.

---

## Appendix

### Failure Chain Summary

```
User: reloads core extension via <leader>al
  -> extension loader copies from extensions/core/commands/ to .opencode/commands/
  -> COMMAND EXECUTION MODE preamble STRIPPED from plan.md, implement.md, research.md, etc.
  -> routing fix (absolute paths) STRIPPED from plan.md, implement.md, research.md

User: runs /plan 57 in OpenCode TUI (running with cwd=~/.config/nvim/)
  -> plan.md loaded (now without COMMAND EXECUTION MODE preamble)
  -> $1 substituted with "57" -> plan.md content rendered
  -> model sees command documentation, NOT an execution instruction
  -> model describes the command instead of executing it
  -> response saved to ~/.config/nvim/.opencode/output/implement.md (session export)
  
  [Secondary path: if model does try to execute]:
  -> searches specs/state.json in cwd=~/.config/nvim/
  -> task 57 not found (nvim project uses task numbers 500+)
  -> no extension manifests found (hidden dir relative path bug, Finding 1 in task 572)
  -> falls back to skill-planner with incorrect context
```

### Key File Paths

| File | Status | Notes |
|------|--------|-------|
| `~/.config/nvim/.opencode/commands/plan.md` | Improved | Has COMMAND EXECUTION MODE + routing fix |
| `~/.config/nvim/.opencode/extensions/core/commands/plan.md` | Outdated | Missing preamble and routing fix |
| `~/.dotfiles/.opencode/commands/plan.md` | Outdated | Installed from core extension (also outdated) |
| `~/.config/nvim/.opencode/output/implement.md` | Session export | Written May 14, confirms nvim cwd context |

### Command Drift Summary

- 15 of 15 commands differ between active (`~/.opencode/commands/`) and extension source (`~/.opencode/extensions/core/commands/`)
- 15 of 15 are missing COMMAND EXECUTION MODE preamble in extension source
- 3 of 15 are missing the absolute-path routing fix in extension source (`implement.md`, `plan.md`, `research.md`)
- The active commands in `~/.config/nvim/.opencode/commands/` have additional commands not in the extension source (`distill.md`, `learn.md`, `sheet.md` — 18 active vs 15 in extension source)
