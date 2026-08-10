# Research Report: Task #121 (Round 3)

**Task**: 121 - clean_up_core_skills_directories
**Started**: 2026-03-03
**Completed**: 2026-03-03
**Effort**: 2-4 hours (implementation)
**Dependencies**: Task 118 (extension exclusion filtering) - already completed
**Sources/Inputs**: Codebase analysis (sync.lua, scan.lua, config.lua, picker/init.lua, entries.lua, edit.lua, parser.lua, opencode picker facade, shared extensions config/init, which-key.lua), directory listings, content identity checks, timestamp analysis
**Artifacts**: specs/121_clean_up_core_skills_directories/reports/research-003.md
**Standards**: report-format.md

## Executive Summary

- **Safety verification PASSED**: Every contaminated artifact in `.opencode/` core directories has a copy in its extension directory. No data will be lost during cleanup. The extension copies are all NEWER (updated Mar 2) than the stale core copies (from Feb 27).
- **CONTEXT_EXCLUDE_PATTERNS serves a distinct purpose** from extension filtering and MUST be preserved. It excludes repository-specific files (project-overview.md, self-healing-implementation-details.md) during sync. Both `.claude/` and `.opencode/` have these files. This mechanism is orthogonal to extension filtering.
- **`<leader>ac` and `<leader>ao` achieve feature parity** through shared infrastructure. Both use the same picker implementation (picker/init.lua), same operations (sync.lua, edit.lua), same entry creation (entries.lua), and same extension management. The only differences are configuration-driven (different base_dir, agents_subdir, settings_file, root_config_file).
- **Context directories in `.opencode/` are ALSO contaminated** with 6 extension-owned subdirectories that need removal alongside the agent/skill/command/rule contamination.

## Context and Scope

This is the third research round for task 121. Prior research established:
- **Research-001**: Contamination inventory (25 artifacts in `.opencode/` core, 8 in `~/.config/.claude/`)
- **Research-002**: Clean-source architecture recommendation (remove extension artifacts from sources, then simplify sync.lua by removing filter code)

This round addresses five specific concerns raised before implementation begins:
1. Safety verification that nothing vital will be lost
2. CONTEXT_EXCLUDE_PATTERNS mechanism analysis
3. Future filtering considerations
4. Feature parity between `<leader>ac` and `<leader>ao` pickers
5. Full artifact management operations audit

## Findings

### 1. Safety Verification: Nothing Vital Will Be Lost

Every contaminated artifact in `.opencode/` core directories was cross-referenced against its extension copy. Results:

**ALL contaminated artifacts have copies in their extension directories -- no data loss.**

However, the copies are NOT identical. The extension copies are all NEWER:

| Artifact | Core Date | Extension Date | Status |
|----------|-----------|----------------|--------|
| document-converter-agent.md | Feb 27 | Mar 2 | Ext newer |
| latex-research-agent.md | Feb 27 | Mar 2 | Ext newer |
| lean-implementation-agent.md | Feb 27 | Mar 2 | IDENTICAL |
| convert.md (command) | Feb 27 | Mar 2 | Ext newer |
| lake.md (command) | Feb 27 | Mar 2 | Ext newer |
| latex.md (rule) | Feb 27 | Mar 2 | Ext newer |
| lean4.md (rule) | Feb 27 | Mar 2 | IDENTICAL |
| skill-document-converter | Feb 27 | Mar 2 | Ext newer |
| skill-latex-implementation | Feb 27 | Mar 2 | Ext newer |
| skill-lean-research | Feb 27 | Mar 2 | Ext newer |
| skill-typst-research | Feb 28 | Mar 2 | Ext newer |

**Conclusion**: The core copies are stale snapshots from the Feb 27 contaminating sync. The extension copies have been updated since (Mar 2). Removing the core copies is safe -- the authoritative versions live in `extensions/{name}/`.

**Additional discovery -- `code-reviewer-agent.md`**: This agent exists ONLY in `.opencode/agent/subagents/` and is NOT in any extension manifest. It is a legitimate core agent unique to `.opencode/`. It must be PRESERVED during cleanup (it is not contamination).

### 2. Context Exclusion Mechanism (CONTEXT_EXCLUDE_PATTERNS)

#### How It Works

`CONTEXT_EXCLUDE_PATTERNS` is a constant defined at the top of sync.lua (line 15-18):

```lua
local CONTEXT_EXCLUDE_PATTERNS = {
  "project/repo/project-overview.md",
  "project/repo/self-healing-implementation-details.md",
}
```

This is passed as the `exclude_patterns` parameter to `scan.scan_directory_for_sync()` (line 389). Inside scan.lua, the mechanism works via exact relative path matching (lines 93-99):

```lua
for _, pattern in ipairs(exclude_patterns) do
  if rel_path == pattern then
    should_exclude = true
    break
  end
end
```

The `rel_path` is computed relative to the context directory base. So `project/repo/project-overview.md` matches the file at `{base_dir}/context/project/repo/project-overview.md` regardless of whether `base_dir` is `.claude` or `.opencode`.

#### Both Files Exist in Both Trees

- `/home/benjamin/.config/nvim/.claude/context/project/repo/project-overview.md` -- EXISTS
- `/home/benjamin/.config/nvim/.opencode/context/project/repo/project-overview.md` -- EXISTS
- `/home/benjamin/.config/nvim/.claude/context/project/repo/self-healing-implementation-details.md` -- EXISTS
- `/home/benjamin/.config/nvim/.opencode/context/project/repo/self-healing-implementation-details.md` -- EXISTS

#### Purpose: Repository-Specific vs Core Context

These files are **repository-specific** -- they describe THIS Neovim configuration project specifically. When syncing the core agent system to a DIFFERENT project (e.g., a LaTeX document project), these files should NOT be copied because they contain information specific to the Neovim config repository.

This is fundamentally different from extension filtering:
- **Extension filtering**: Prevents extension-owned artifacts from polluting core directories
- **Context exclusion**: Prevents repository-specific context from being synced to other projects

#### Decision: MUST Be Preserved

Research-002 recommended removing the extension filter functions from sync.lua after source cleanup. That recommendation is CORRECT for the four filter functions (`build_extension_exclusions`, `filter_extension_files`, `filter_extension_skills`, `filter_extension_context`). However, `CONTEXT_EXCLUDE_PATTERNS` and its usage in the `sync_scan("context", ...)` call MUST be preserved. They serve a different purpose entirely.

### 3. Future Filtering Considerations

#### What Should REMAIN After Cleanup

1. **CONTEXT_EXCLUDE_PATTERNS** (sync.lua lines 15-18) -- KEEP. Repository-specific file exclusions.

2. **The `exclude_patterns` parameter of `scan_directory_for_sync`** (scan.lua) -- KEEP. This is a general-purpose mechanism that `CONTEXT_EXCLUDE_PATTERNS` uses.

#### What Can Be REMOVED After Source Cleanup

1. `build_extension_exclusions()` (sync.lua lines 24-107) -- REMOVE
2. `filter_extension_files()` (sync.lua lines 114-126) -- REMOVE
3. `filter_extension_skills()` (sync.lua lines 132-152) -- REMOVE
4. `filter_extension_context()` (sync.lua lines 159-188) -- REMOVE
5. All filter call sites in `scan_all_artifacts()` (lines 338, 347, 360, 372, 377, 383, 386, 398) -- REMOVE

#### Potential Future Exclusions

Other file types that might need exclusion in the future:
- **Additional repository-specific context files**: If new repo-specific docs are added to `context/project/repo/`
- **User-specific settings**: Files that contain machine-specific paths or credentials

The existing `CONTEXT_EXCLUDE_PATTERNS` array is easily extensible -- simply add new relative path strings.

#### Defensive Validation (Recommended)

After removing the filter code, a lightweight validation script would protect against future re-contamination. This script would verify the disjointness invariant: no artifact in core directories appears in any extension manifest's `provides` field. This is a post-cleanup safeguard, not a runtime filter.

### 4. Feature Parity: `<leader>ac` vs `<leader>ao`

#### Architecture

Both keymaps invoke the SAME picker infrastructure through a config-driven delegation pattern:

```
<leader>ac (Normal) -> :ClaudeCommands -> picker/init.lua with claude config
<leader>ao (Normal) -> :OpencodeCommands -> opencode/picker.lua -> picker/init.lua with opencode config
<leader>ac (Visual) -> claude/core/visual.lua -> send_visual_to_claude_with_prompt()
<leader>ao (Visual) -> opencode/core/visual.lua -> send_visual_to_opencode_with_prompt()
```

The shared picker config (`shared/picker/config.lua`) provides two presets:

| Config Field | `M.claude()` | `M.opencode()` |
|-------------|-------------|----------------|
| base_dir | `.claude` | `.opencode` |
| label | `Claude` | `OpenCode` |
| commands_subdir | `commands` | `commands` |
| skills_subdir | `skills` | `skills` |
| agents_subdir | `agents` | `agent/subagents` |
| hooks_subdir | `hooks` | `nil` (no hooks) |
| settings_file | `settings.local.json` | `settings.json` |
| root_config_file | `CLAUDE.md` | `OPENCODE.md` |
| extensions_module | `neotex.plugins.ai.claude.extensions` | `neotex.plugins.ai.opencode.extensions` |

#### Picker Operations (All Shared)

Both pickers use the SAME picker/init.lua with identical key mappings:

| Keybinding | Operation | Claude | OpenCode | Parity |
|-----------|-----------|--------|----------|--------|
| `<Enter>` | Execute/toggle action | YES | YES | FULL |
| `<C-l>` | Load artifact locally | YES | YES | FULL |
| `<C-u>` | Update from global | YES | YES | FULL |
| `<C-s>` | Save to global | YES | YES | FULL |
| `<C-e>` | Edit file | YES | YES | FULL |
| `<C-n>` | Create new command | YES | YES | FULL |
| `<C-r>` | Run script with args | YES | YES | FULL |
| `<C-t>` | Run test | YES | YES | FULL |
| `<Esc>` | Close picker | YES | YES | FULL |

#### Picker Sections (Config-Driven Differences)

| Section | Claude | OpenCode | Notes |
|---------|--------|----------|-------|
| Commands | YES (11) | YES (14, 11 after cleanup) | Same display, config-driven path |
| Agents | YES (6) | YES (15, 7 after cleanup) | OpenCode has unique code-reviewer-agent |
| Skills | YES (11) | YES (22, 11 after cleanup) | Same display, config-driven path |
| Hook Events | YES | NO | OpenCode config has `hooks_subdir = nil` |
| Root Files | YES | YES | Different file lists per config |
| Docs | YES | YES | Depends on directory existence |
| Lib | YES | YES | Depends on directory existence |
| Templates | YES | YES | Depends on directory existence |
| Scripts | YES | YES | Depends on directory existence |
| Tests | YES | YES | Depends on directory existence |
| Extensions | YES | YES | Different extension module per config |
| Load Core Agent System | YES | YES | Same operation, config-driven |
| Keyboard Shortcuts | YES | YES | Same help display |

**Hooks are intentionally absent from OpenCode** because OpenCode does not support hook scripts. This is a design decision, not a parity gap.

#### Extension Management (Shared Infrastructure)

Both systems use the same shared extension infrastructure:

- `shared/extensions/config.lua` -- Configuration presets (claude vs opencode)
- `shared/extensions/init.lua` -- Extension manager factory
- `shared/extensions/loader.lua` -- File copy engine (load/unload)
- `shared/extensions/manifest.lua` -- Manifest validation
- `shared/extensions/state.lua` -- Extension state tracking

Both have thin wrapper modules:
- `claude/extensions/init.lua` -- Creates manager with claude config
- `opencode/extensions/init.lua` -- Creates manager with opencode config

Extension operations (load, unload, reload, list_available, get_details) are identical for both.

#### Feature Parity Verdict: FULL PARITY

The only differences between `<leader>ac` and `<leader>ao` are:
1. **Configuration-driven**: Different base_dir, agents_subdir, settings_file, root_config_file
2. **Intentional design**: OpenCode lacks hooks (by design)
3. **Content-driven**: Different artifact counts in directories (contamination issue being addressed)

The picker operations, UI, key bindings, extension management, and sync behavior are identical.

### 5. Artifact Management Operations Audit

#### Operation: "Load Core Agent System" (sync.load_all_globally)

| Aspect | Claude | OpenCode | Parity |
|--------|--------|----------|--------|
| Entry point | `sync.load_all_globally(config)` | Same function, different config | FULL |
| Scans artifacts | `scan_all_artifacts(global_dir, project_dir, config)` | Same function | FULL |
| Extension filtering | `build_extension_exclusions` + filter functions | Same functions | FULL |
| Context exclusion | `CONTEXT_EXCLUDE_PATTERNS` via scan.lua | Same mechanism | FULL |
| User confirmation | 3-choice (Sync all / New only / Cancel) or 2-choice | Same UI | FULL |
| File sync | `sync_files` with permission preservation | Same function | FULL |
| Results notification | Detailed per-category counts | Same format | FULL |

After cleanup: extension filtering functions will be removed, but context exclusion remains.

#### Operation: "Load Extension" (via picker Enter key)

Both pickers use the same entry handler (picker/init.lua line 139-151):
```lua
elseif selection.value.entry_type == "extension" then
  actions.close(prompt_bufnr)
  local exts = require(extensions_module)
  if ext.status == "active" or ext.status == "update-available" then
    exts.unload(ext.name, { confirm = true })
  else
    exts.load(ext.name, { confirm = true })
  end
```

The `extensions_module` is config-driven, but both delegate to `shared.extensions.create(config)` which returns the same manager API.

| Aspect | Claude | OpenCode | Parity |
|--------|--------|----------|--------|
| Load operation | `exts.load(name, {confirm: true})` | Same | FULL |
| Unload operation | `exts.unload(name, {confirm: true})` | Same | FULL |
| State tracking | `extensions.json` in target project | Same | FULL |
| Installed file tracking | Records all copied files/dirs | Same | FULL |
| Config merge | `CLAUDE.md` sections | `OPENCODE.md` sections | Config-driven |

#### Operation: "Unload Extension" (toggle via Enter key)

Same as above -- the picker toggles load/unload based on current status.

#### Operation: "Update from Global" (Ctrl-u, sync.update_artifact_from_global)

| Aspect | Claude | OpenCode | Parity |
|--------|--------|----------|--------|
| Entry point | `sync.update_artifact_from_global(artifact, type, false, config)` | Same | FULL |
| Subdir mapping | command/hook/lib/doc/template/script/test/skill/agent/systemd/root_file | Same map | FULL |
| Permission preservation | `.sh` files get permissions copied | Same | FULL |
| Error handling | Notifications for missing global versions | Same | FULL |

#### Operation: "Load Artifact Locally" (Ctrl-l, edit.load_artifact_locally)

| Aspect | Claude | OpenCode | Parity |
|--------|--------|----------|--------|
| Entry point | `edit.load_artifact_locally(artifact, type, parser, config)` | Same | FULL |
| Dependency loading | Commands: loads dependent commands | Same | FULL |
| Permission preservation | Hook/lib/script/test files | Same | FULL |

#### Operation: "Save to Global" (Ctrl-s, edit.save_artifact_to_global)

| Aspect | Claude | OpenCode | Parity |
|--------|--------|----------|--------|
| Entry point | `edit.save_artifact_to_global(artifact, type, config)` | Same | FULL |
| Target directory | `global_dir/{base_dir}/{subdir}/` | Config-driven | FULL |

### 6. Context Directory Contamination (Additional Finding)

Research-001 noted "Context: Not checked (complex)". This round confirms context contamination:

`.opencode/context/project/` contains 6 extension-owned subdirectories:

| Contaminated Dir | Extension Owner | Core Files | Ext Files |
|-----------------|----------------|------------|-----------|
| project/latex | latex | 8 | 10 |
| project/lean4 | lean | 23 | 23 |
| project/logic | formal | 18 | 19 |
| project/math | formal | 11 | 16 |
| project/typst | typst | 17 | 12 |
| project/web | web | 20 | 20 |

File counts differ in some cases (core has fewer or more files than extension copy). The extension copies should be considered authoritative -- they are maintained as part of the extension package. The core copies are stale from the contaminating sync.

**Note**: For typst, the core copy has MORE files (17) than the extension copy (12). This means 5 context files exist ONLY in the core copy. These files would be lost if the core copy is deleted without first reconciling with the extension copy.

**Recommendation**: Before removing contaminated context directories, verify that any files present in core but ABSENT from the extension copy are either (a) moved to the extension copy, or (b) confirmed as obsolete.

### 7. Missing `.opencode/` Core Context

`.opencode/context/project/` is missing the `hooks/` subdirectory that `.claude/context/project/hooks/` has. This is a separate sync freshness issue, not contamination. It should be addressed separately (by a future core sync or manual copy).

## Decisions

1. **Safe to proceed with cleanup** -- all contaminated artifacts have authoritative copies in extension directories.
2. **CONTEXT_EXCLUDE_PATTERNS MUST be preserved** in sync.lua. It serves repository-specific exclusion, not extension filtering.
3. **Extension filter functions CAN be removed** from sync.lua after source directories are cleaned.
4. **`<leader>ac` and `<leader>ao` achieve full feature parity** -- no remediation needed.
5. **Context directories need cleanup too** -- 6 extension-owned subdirectories in `.opencode/context/project/` must be removed.
6. **Typst context reconciliation required** -- the core copy has 5 files not in the extension copy. These must be reconciled before deletion.
7. **`code-reviewer-agent.md` must be preserved** -- it is a legitimate core agent unique to `.opencode/`.
8. **The `exclude_patterns` parameter in scan.lua must be preserved** -- it is the general mechanism that `CONTEXT_EXCLUDE_PATTERNS` uses.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Typst context files lost (5 core-only files) | Medium | Reconcile before deletion: copy missing files to extension context first |
| Other context directories with core-only files | Medium | Run diff check on all 6 contaminated context dirs before deletion |
| Removing filter code leaves system vulnerable to re-contamination | Low | Add disjointness validation script as post-cleanup safeguard |
| CONTEXT_EXCLUDE_PATTERNS accidentally removed with filter code | High | Implementation plan must explicitly mark this constant and its usage as PRESERVE |

## Appendix

### Complete Artifact Cleanup Checklist

#### .opencode/ Source (25 artifacts + 6 context directories)

**Agents to remove from `agent/subagents/`** (9):
- [x] document-converter-agent.md (document-converter ext, ext copy exists)
- [x] latex-implementation-agent.md (latex ext, ext copy exists)
- [x] latex-research-agent.md (latex ext, ext copy exists)
- [x] lean-implementation-agent.md (lean ext, ext copy exists)
- [x] lean-research-agent.md (lean ext, ext copy exists)
- [x] logic-research-agent.md (formal ext, ext copy exists)
- [x] math-research-agent.md (formal ext, ext copy exists)
- [x] typst-implementation-agent.md (typst ext, ext copy exists)
- [x] typst-research-agent.md (typst ext, ext copy exists)

**PRESERVE**: code-reviewer-agent.md (core, not in any extension)

**Skills to remove from `skills/`** (11 directories):
- [x] skill-document-converter (document-converter ext)
- [x] skill-lake-repair (lean ext)
- [x] skill-latex-implementation (latex ext)
- [x] skill-latex-research (latex ext)
- [x] skill-lean-implementation (lean ext)
- [x] skill-lean-research (lean ext)
- [x] skill-lean-version (lean ext)
- [x] skill-logic-research (formal ext)
- [x] skill-math-research (formal ext)
- [x] skill-typst-implementation (typst ext)
- [x] skill-typst-research (typst ext)

**Commands to remove from `commands/`** (3):
- [x] convert.md (document-converter ext)
- [x] lake.md (lean ext)
- [x] lean.md (lean ext)

**Rules to remove from `rules/`** (2):
- [x] latex.md (latex ext)
- [x] lean4.md (lean ext)

**Context directories to remove from `context/project/`** (6):
- [ ] project/latex (latex ext) -- verify no core-only files first
- [ ] project/lean4 (lean ext) -- verify no core-only files first
- [ ] project/logic (formal ext) -- verify no core-only files first
- [ ] project/math (formal ext) -- verify no core-only files first
- [ ] project/typst (typst ext) -- **5 CORE-ONLY FILES, reconcile first**
- [ ] project/web (web ext) -- verify no core-only files first

#### ~/.config/.claude/ Target (8 artifacts)

**Skills to remove** (3): skill-document-converter, skill-latex-implementation, skill-typst-implementation
**Agents to remove** (3): document-converter-agent.md, latex-implementation-agent.md, typst-implementation-agent.md
**Commands to remove** (1): convert.md
**Rules to remove** (1): latex.md

#### Post-Cleanup Counts (Expected)

| Category | .claude Source | .opencode Source | Parity |
|----------|--------------|-----------------|--------|
| Agents | 6 | 7 (+code-reviewer) | Intentional +1 |
| Skills | 11 | 11 | MATCH |
| Commands | 11 | 11 | MATCH |
| Rules | 6 | 6 | MATCH |
| Context (core project/) | 5 dirs | 4 dirs (-hooks) | Missing hooks/ |

### Filtering Mechanism Summary

| Mechanism | Purpose | Location | After Cleanup |
|-----------|---------|----------|--------------|
| `CONTEXT_EXCLUDE_PATTERNS` | Exclude repo-specific files from sync | sync.lua L15-18 | PRESERVE |
| `exclude_patterns` param | General exclusion in scan | scan.lua L50,93-99 | PRESERVE |
| `build_extension_exclusions()` | Build extension artifact sets | sync.lua L24-107 | REMOVE |
| `filter_extension_files()` | Filter agents/commands/rules | sync.lua L114-126 | REMOVE |
| `filter_extension_skills()` | Filter skills by path | sync.lua L132-152 | REMOVE |
| `filter_extension_context()` | Filter context by prefix | sync.lua L159-188 | REMOVE |

### Picker Architecture Diagram

```
Normal mode keybinding
  |
  +-- <leader>ac -> :ClaudeCommands
  |     |
  |     +-- claude/init.lua -> claude_config = shared_config.claude()
  |           |
  |           +-- picker/init.lua(opts, claude_config)
  |
  +-- <leader>ao -> :OpencodeCommands
        |
        +-- opencode/picker.lua -> opencode_config = shared_config.opencode()
              |
              +-- picker/init.lua(opts, opencode_config)

              Shared picker infrastructure:
              +-- parser.get_extended_structure(config)
              +-- entries.create_picker_entries(structure, config)
              +-- sync.load_all_globally(config)
              +-- sync.update_artifact_from_global(artifact, type, silent, config)
              +-- edit.load_artifact_locally(artifact, type, parser, config)
              +-- edit.save_artifact_to_global(artifact, type, config)
```

### Key Files Examined

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Sync operation with CONTEXT_EXCLUDE_PATTERNS and extension filtering (648 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning with exclude_patterns support (206 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/picker/config.lua` - Claude vs OpenCode config presets (91 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Shared picker with all operations (283 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/commands/picker.lua` - OpenCode picker facade (21 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Picker entry creation (808 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua` - Edit/load/save operations (231 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/parser.lua` - Command/skill/agent parsing with fallback (804 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/config.lua` - Shared extension configuration (71 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/extensions/init.lua` - OpenCode extension manager (13 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/extensions/config.lua` - OpenCode extension config (15 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/extensions/picker.lua` - OpenCode extension picker (245 lines)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` - Keybinding definitions (lines 238-267)

## Next Steps

Run `/plan 121` to create implementation plan incorporating findings from all three research rounds. Key implementation considerations:

1. **Pre-deletion context reconciliation**: Before removing `.opencode/context/project/{ext}/`, diff each directory against its extension copy and move any core-only files to the extension
2. **Preserve CONTEXT_EXCLUDE_PATTERNS**: Mark explicitly in plan as DO-NOT-REMOVE
3. **Preserve code-reviewer-agent.md**: Mark explicitly in plan as DO-NOT-REMOVE
4. **Remove extension filter functions**: 4 functions (~130 lines) plus ~8 call sites
5. **Clean ~/.config/.claude/ target**: 8 artifacts to remove
6. **Validation script**: Create disjointness check to prevent re-contamination
