# Research Report: Task #167 (Supplemental)

**Task**: 167 - Verify and revise agent system loaders for .claude/ and .opencode/
**Started**: 2026-03-10T18:00:00Z
**Completed**: 2026-03-10T19:00:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Sources/Inputs**: Neovim source code, Vision project target directories, extension manifest files
**Artifacts**: - specs/167_verify_revise_agent_system_loaders/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The symlink strategy is fundamentally incomplete: only 2 of 27 extension agents and 28 of 28 extension skills are symlinked, while 25 agents, 5 rules, 7 commands, and ALL extension context directories are missing from core
- The double-question bug in `<leader>ac` extension loading is caused by TWO sequential `vim.fn.confirm()` dialogs in `shared/extensions/init.lua` (conflict check on line 177, then main confirmation on line 192) -- both fire when `confirm=true` and conflicts exist; the root cause is that symlink-based core sync pre-installs skill files, so every extension load encounters conflicts
- Vision has all 11 extensions loaded correctly for both `.claude/` and `.opencode/`, with extension sections injected into CLAUDE.md/OPENCODE.md, settings merged, and context directories populated; one minor issue: the `filetypes` extension has a manifest bug (`context/project/filetypes` should be `project/filetypes`) causing its context files to not be copied

## Area 1: Eliminate Symlinks - Move Extension Contents to Core

### Current Symlink Strategy

The source `.claude/` directory uses symlinks to expose some extension artifacts at the top level so the core sync (`load_all_globally`) picks them up:

**What IS symlinked (exposed via core sync):**
- 2 agents: z3-implementation-agent.md, z3-research-agent.md
- 28 skill directories: All extension skills

**What is NOT symlinked (missing from core sync):**
- 25 agents from 10 extensions (epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web)
- 5 rules (latex.md, lean4.md, nix.md, neovim-lua.md, web-astro.md)
- 7 commands (convert.md, deck.md, slides.md, table.md, lake.md, lean.md, tag.md)
- All extension context directories (11 extensions, ~60 context subdirectories)
- All extension scripts (2 from lean: setup-lean-mcp.sh, verify-lean-mcp.sh)

This means the core sync only partially includes extension artifacts. When a project uses "Load Core Agent System" without individual extension loading, it gets skills but is missing agents, rules, commands, context, and scripts from extensions.

### What Needs to Change

To eliminate symlinks and move extension contents into core, the following changes are required:

#### 1. Move Extension Artifacts to Core Directories

For each of the 11 extensions, copy (not symlink) these files:

| Category | Files to Move | Target Directory |
|----------|--------------|-----------------|
| Agents | 27 files (25 missing + 2 currently symlinked) | `.claude/agents/` |
| Skills | 28 directories (already symlinked, replace with copies) | `.claude/skills/` |
| Rules | 5 files | `.claude/rules/` |
| Commands | 7 files | `.claude/commands/` |
| Context | ~60 directories with files | `.claude/context/project/{topic}/` |
| Scripts | 2 files | `.claude/scripts/` |

**Total: ~130+ files to copy into core directories**

#### 2. Remove Existing Symlinks

```bash
# Remove 2 agent symlinks
rm .claude/agents/z3-implementation-agent.md
rm .claude/agents/z3-research-agent.md

# Remove 28 skill symlinks
for link in .claude/skills/skill-{deck,epidemiology-*,filetypes,formal-*,...}; do
  rm "$link"
done
```

#### 3. Copy Extension Files to Core

```bash
# For each extension, copy agents, skills, rules, commands, context, scripts
for ext in epidemiology filetypes formal latex lean nix nvim python typst web z3; do
  # Agents
  cp .claude/extensions/$ext/agents/*.md .claude/agents/ 2>/dev/null
  # Skills (recursive copy)
  cp -r .claude/extensions/$ext/skills/* .claude/skills/ 2>/dev/null
  # Rules
  cp .claude/extensions/$ext/rules/*.md .claude/rules/ 2>/dev/null
  # Commands
  cp .claude/extensions/$ext/commands/*.md .claude/commands/ 2>/dev/null
  # Context (recursive copy preserving structure)
  cp -r .claude/extensions/$ext/context/* .claude/context/ 2>/dev/null
  # Scripts
  cp .claude/extensions/$ext/scripts/*.sh .claude/scripts/ 2>/dev/null
done
```

#### 4. Mirror for .opencode

The same must be done for `.opencode/`. Currently `.opencode/` has NO symlinks and relies entirely on the extension loading system. Under the new approach:

- Copy all extension agents to `.opencode/agent/subagents/`
- Copy all extension skills to `.opencode/skills/`
- Copy all extension commands to `.opencode/commands/`
- Copy all extension rules to `.opencode/rules/`
- Copy all extension context to `.opencode/context/`
- Copy all extension scripts to `.opencode/scripts/`

#### 5. Update References

Files that reference extension paths need updating:

| File | Current Reference | New Reference |
|------|------------------|---------------|
| `.claude/CLAUDE.md` | `@.claude/extensions/nvim/context/...` | `@.claude/context/project/neovim/...` |
| Agent files | `@.claude/extensions/{ext}/context/...` | `@.claude/context/project/{topic}/...` |
| Skill SKILL.md files | `@.claude/extensions/{ext}/context/...` | `@.claude/context/project/{topic}/...` |
| `EXTENSION.md` files | Context imports pointing to extensions/ | Update to core paths |

#### 6. Keep Extensions Directory for Metadata Only

The `extensions/` directory can be retained purely for manifest.json files that the extension picker reads (listing, version info, descriptions). But the actual files would live in core directories.

Alternatively, the extensions/ directory could be removed entirely and the extension picker could scan core directories directly, but this would lose the ability to distinguish extension-provided vs core-provided artifacts.

#### 7. Update Sync Logic

`sync.lua`'s `scan_all_artifacts()` currently follows symlinks via `vim.fn.glob()`. After moving files, this needs no change -- the glob will find real files instead of symlinks.

The extension loader (`shared/extensions/init.lua`) and its `load()` function would still be useful for loading extensions into OTHER projects (not the source nvim config). The loader reads from `global_extensions_dir` and copies to the target project.

### Maintenance Considerations

**With symlinks (current):**
- Edit extension file in `extensions/{ext}/` -> symlink transparently exposes it
- But only works for symlinked categories (agents and skills)
- Rules, commands, context not exposed

**With copies (proposed):**
- Must maintain files in TWO locations: `extensions/{ext}/` (source of truth) AND core directories
- OR: Make core directories the source of truth and update extension manifests to reference core paths
- OR: Eliminate extensions/ directory entirely and have a manifest-only approach

**Recommended approach: Core as Source of Truth**

1. Move all extension files into core directories (agents/, skills/, rules/, commands/, context/)
2. Update extension manifests to list file names without providing physical files
3. The extension loader reads manifests to know WHAT files to copy, but looks for them in core directories instead of extension subdirectories
4. The core sync (`load_all_globally`) continues to glob core directories and sync everything
5. No duplication, no symlinks, single source of truth

This requires modifying `shared/extensions/loader.lua` to support a `source_override_dir` that points to the core directory instead of the extension subdirectory.

## Area 2: Vision Extension Loading Verification

### .claude/ Extensions in Vision

All 11 extensions are loaded and tracked in `extensions.json`:

| Extension | Files | Dirs | Status |
|-----------|-------|------|--------|
| epidemiology | 8 | 1 | Loaded |
| filetypes | 13 | 0 | Loaded |
| formal | 53 | 3 | Loaded |
| latex | 15 | 1 | Loaded |
| lean | 35 | 1 | Loaded |
| nix | 16 | 1 | Loaded |
| nvim | 21 | 3 | Loaded |
| python | 10 | 1 | Loaded |
| typst | 30 | 1 | Loaded |
| web | 29 | 2 | Loaded |
| z3 | 9 | 1 | Loaded |

**Verification results:**
- All agents present (27 extension agents + 4 core = 31 total, all verified)
- All skills present (28 extension skills + 9 core = 37 total, all verified)
- All rules present (5 extension rules + 5 core = 10 total)
- Extension sections injected into CLAUDE.md (10 sections visible via grep)
- settings.local.json merged with MCP servers (lean-lsp, rmcp)
- Context directories present for all extensions

**Issue found: filetypes context NOT loaded**

The filetypes extension manifest has `"context": ["context/project/filetypes"]` instead of `"context": ["project/filetypes"]`. The leading `context/` causes the loader to construct the source path as `{ext_dir}/context/context/project/filetypes` (double "context"), which does not exist. The loader silently skips it. All other extensions use `"project/{topic}"` without the leading `context/`.

**Fix**: Change filetypes manifest.json `provides.context` from `["context/project/filetypes"]` to `["project/filetypes"]`.

### .opencode/ Extensions in Vision

All 11 extensions are loaded and tracked in `.opencode/extensions.json`:

| Extension | Files | Dirs | Status |
|-----------|-------|------|--------|
| epidemiology | 12 | 3 | Loaded |
| filetypes | 13 | 3 | Loaded |
| formal | 67 | 7 | Loaded |
| latex | 21 | 3 | Loaded |
| lean | 47 | 5 | Loaded |
| nix | 22 | 3 | Loaded |
| nvim | 29 | 3 | Loaded |
| python | 15 | 3 | Loaded |
| typst | 36 | 3 | Loaded |
| web | 34 | 3 | Loaded |
| z3 | 13 | 3 | Loaded |

**Verification results:**
- All agents present in `agent/subagents/` (27 extension agents + 5 core = 32 total)
- All skills present (28 extension skills + 12 core = 40 total)
- All rules present (5 extension rules + 5 core + 1 README = 11 total)
- Extension sections injected into OPENCODE.md (11 sections)
- settings.local.json merged
- Context directories matching .claude/ set

Note: `.opencode/` has slightly higher file counts per extension because it tracks created directories separately and has different path structures.

### Additional Changes Required (Beyond Symlink Elimination)

1. **Fix filetypes manifest.json** in BOTH `.claude/extensions/filetypes/manifest.json` AND `.opencode/extensions/filetypes/manifest.json` -- change context path from `"context/project/filetypes"` to `"project/filetypes"`
2. **Reload filetypes extension in Vision** after fixing the manifest to install the missing context files
3. **After moving to core**: Re-sync Vision with `Load Core Agent System` to pick up all extension files that were previously missing from core sync

## Area 3: Double-Question Bug in <leader>ac Extension Loader

### Root Cause

The double-question occurs in `lua/neotex/plugins/ai/shared/extensions/init.lua` within the `manager.load()` function (lines 154-279).

Two sequential `vim.fn.confirm()` dialogs execute when `confirm=true`:

**Dialog 1 (Conflict Check, lines 176-189):**
```lua
if #conflicts > 0 and confirm then
  local conflict_msg = "The following files would be overwritten:\n"
  -- ...
  conflict_msg = conflict_msg .. "\nProceed anyway?"
  local choice = vim.fn.confirm(conflict_msg, "&Yes\n&No", 2)
  if choice ~= 1 then
    return false, "Cancelled by user"
  end
end
```

**Dialog 2 (Main Confirmation, lines 192-215):**
```lua
if confirm then
  local message = string.format(
    "Load extension '%s' v%s?\n\n%s\n%s",
    extension_name, ext_manifest.version,
    ext_manifest.description, provides_summary
  )
  local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
  if choice ~= 1 then
    return false, "Cancelled by user"
  end
end
```

### Why .claude Shows Double-Question but .opencode Does Not

The `.claude/` core sync (`load_all_globally`) copies ALL files from core directories, which includes symlinked skill files from extensions. So when a user later tries to load an extension via the extension picker, the skill files ALREADY EXIST in the target project (they were copied during core sync). This triggers the conflict check (Dialog 1), followed by the main confirmation (Dialog 2) -- resulting in two questions.

The `.opencode/` core sync does NOT have symlinks, so extension skill files are NOT included in the core sync. When a user loads an extension via the picker, no files exist yet -- zero conflicts. Dialog 1 is skipped (the `if #conflicts > 0` check is false), and only Dialog 2 shows -- resulting in one question.

### What the User Observes

| Step | .claude (leader-ac) | .opencode (leader-ao) |
|------|---------------------|----------------------|
| 1. User selects extension | Picker closes | Picker closes |
| 2. Conflict check | "The following files would be overwritten... Proceed?" (YES/NO) | Skipped (no conflicts) |
| 3. Main confirm | "Load extension 'X' v1.0.0?... Load/Cancel" | "Load extension 'X' v1.0.0?... Load/Cancel" |
| Result | TWO dialogs | ONE dialog |

### Fix Options

**Option A: Merge into single dialog (recommended)**
Combine the conflict information into the main confirmation dialog. If conflicts exist, append them to the message:
```lua
if confirm then
  local message = string.format(
    "Load extension '%s' v%s?\n\n%s\n%s",
    extension_name, ext_manifest.version,
    ext_manifest.description, provides_summary
  )
  if #conflicts > 0 then
    message = message .. "\n\nNote: " .. #conflicts .. " existing files will be overwritten."
  end
  local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
  -- ...
end
```
Remove the separate conflict dialog entirely.

**Option B: Skip conflict check when confirm=true**
The conflict check is redundant when followed by a general confirmation. Remove the conflict dialog and keep only the main confirmation:
```lua
-- Remove lines 176-189 entirely
-- The main confirmation at line 192 is sufficient
```

**Option C: Make conflicts informational only**
Move conflict listing into the main dialog without a separate yes/no:
```lua
if confirm then
  local conflict_info = ""
  if #conflicts > 0 then
    conflict_info = "\n\nWill overwrite " .. #conflicts .. " existing file(s)."
  end
  local message = string.format(
    "Load extension '%s' v%s?\n\n%s\n%s%s",
    extension_name, ext_manifest.version,
    ext_manifest.description, provides_summary,
    conflict_info
  )
  local choice = vim.fn.confirm(message, "&Load\n&Cancel", 2)
end
```

### Note on Root Cause After Symlink Elimination

Once symlinks are eliminated and extension files are moved to core (Area 1), the double-question issue becomes moot for the CURRENT scenario because:
- Core sync will copy ALL extension files (they're now in core directories)
- Individual extension loading via the picker becomes redundant for the source nvim config
- However, the double-question could still occur when loading extensions into other projects where some files already exist

Therefore, the fix should be applied regardless of whether symlinks are eliminated.

## Decisions

1. The symlink strategy should be replaced with direct file copies in core directories
2. The filetypes extension manifest has a bug that prevents context file loading
3. The double-question is caused by two sequential confirm dialogs, fixable by merging into one
4. Vision has all extensions loaded correctly except for the filetypes context bug

## Risks & Mitigations

1. **Dual-maintenance risk**: Moving files to core creates potential for extension source and core copy to diverge. Mitigated by making core the single source of truth and updating the extension loader to reference core paths.

2. **Core directory bloat**: Adding ~130 files to core directories makes them larger. Mitigated by clear naming conventions (extension-provided files are prefixed with language name).

3. **Breaking extension picker**: After moving files, the extension picker must still be able to list available extensions. Mitigated by keeping manifest.json files in extensions/ for metadata purposes.

## Context Extension Recommendations

None -- this is a meta/infrastructure task.

## Appendix

### File Counts by Extension

| Extension | Agents | Skills | Rules | Commands | Context Dirs | Scripts |
|-----------|--------|--------|-------|----------|-------------|---------|
| epidemiology | 2 | 2 | 0 | 0 | 3 | 0 |
| filetypes | 5 | 4 | 0 | 4 | 3 | 0 |
| formal | 4 | 4 | 0 | 0 | 9 | 0 |
| latex | 2 | 2 | 1 | 0 | 5 | 0 |
| lean | 2 | 4 | 1 | 2 | 9 | 2 |
| nix | 2 | 2 | 1 | 0 | 4 | 0 |
| nvim | 2 | 2 | 1 | 0 | 5 | 0 |
| python | 2 | 2 | 0 | 0 | 3 | 0 |
| typst | 2 | 2 | 0 | 0 | 5 | 0 |
| web | 2 | 3 | 1 | 1 | 5 | 0 |
| z3 | 2 | 2 | 0 | 0 | 3 | 0 |
| **Total** | **27** | **29** | **5** | **7** | **54** | **2** |

### Key Source Files

- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- Extension load/unload logic (double-question bug)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` -- File copy engine
- `lua/neotex/plugins/ai/shared/extensions/config.lua` -- Claude vs OpenCode configuration
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` -- Main picker (line 139-147: extension entry handling)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` -- Core sync logic
- `.claude/extensions/filetypes/manifest.json` -- Bug: context path has leading "context/"

### Search Queries Used

- Symlink listing via `find -type l -ls`
- Extension manifest analysis via python3 JSON parsing
- Directory comparison between source and Vision via `ls` and `diff`
- Grep for extension-related code patterns in picker and loader modules
