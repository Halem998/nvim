# Implementation Plan: Task #174

- **Task**: 174 - study_opencode_memory_extension
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Add "data" category to extension system and create memory extension from .opencode/memory/
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

This task migrates the .opencode/memory/ system (Obsidian-compatible vault, /learn command, skill-learn, documentation, and MCP integration) into a loadable extension. The extension system requires a new "data" provides category to support read-write data directories that grow over time. The memory extension will be structured to work with both .claude and .opencode systems, with special unload safety to preserve user-created memory files.

### Research Integration

Key findings from research-001:
- The memory system consists of a vault directory, /learn command, skill-learn (currently a tag scanner, needs rewriting), memory docs, and --remember flag in /research
- The extension loader has 7 valid provides categories but none handle read-write data directories
- The loader's copy/unload pattern works well for static files but needs augmentation for user data preservation
- The skill-learn SKILL.md contains tag scanning code (from /fix-it), NOT memory management -- the memory logic is inline in the command
- The --remember flag in /research should be documented in EXTENSION.md rather than requiring hook system changes

## Goals & Non-Goals

**Goals**:
- Add "data" provides category to the extension system (manifest validation + loader + unloader)
- Create a complete memory extension with manifest, command, skill, context, data, and merge targets
- Migrate existing .opencode/memory/ components into the extension
- Implement safe unload that preserves user-created memory files
- Support both .claude and .opencode loading targets

**Non-Goals**:
- Implementing a hook system for modifying existing commands (--remember flag)
- Rewriting the entire /learn command -- only separating concerns where needed
- Adding new memory features beyond what already exists
- Making the MCP server setup automatic (remains manual per memory-setup.md)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Data loss during unload removes user memories | High | Medium | Implement data-preserve flag; unloader tracks skeleton vs user files separately |
| skill-learn rewrite breaks existing tag scanning | Medium | Low | Keep tag scanning in skill-learn for /fix-it; create NEW skill-memory for memory management |
| Extension system changes break existing extensions | High | Low | New "data" category is purely additive; no changes to existing 7 categories |
| Vault directory conflicts on load if user already has .opencode/memory/ | Medium | High | check_conflicts extended for data dirs; load merges skeleton without overwriting existing files |
| --remember flag stops working after migration | Low | Low | Graceful degradation already implemented; flag documented in EXTENSION.md |

## Implementation Phases

### Phase 1: Add "data" Category to Extension System [COMPLETED]

**Goal**: Extend the extension loader to support a new "data" provides category that handles read-write data directories with special unload semantics.

**Estimated effort**: 1.5 hours

**Objectives**:
1. Add "data" to VALID_PROVIDES in manifest.lua
2. Add copy_data_dirs() function to loader.lua
3. Update conflict checking for data directories
4. Implement data-aware unload in init.lua

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Add "data" to VALID_PROVIDES array
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Add copy_data_dirs() function, update check_conflicts()
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Wire up copy_data_dirs in load flow, add data-preserve logic in unload flow

**Steps**:
1. In `manifest.lua`, add `"data"` to the VALID_PROVIDES table
2. In `loader.lua`, create `copy_data_dirs()` that:
   - Reads `provides.data` array from manifest (each entry is a directory name)
   - Copies from `extension/data/{name}/` to `{base_dir}/{name}/`
   - Uses merge-copy semantics: only copies files that do NOT already exist at the target (preserves user data)
   - Returns separate tracking: `skeleton_files` (from extension) vs the target directory path
3. In `loader.lua`, update `check_conflicts()` to check data directories
4. In `init.lua` load flow, add `copy_data_dirs` call after `copy_scripts`
5. In `init.lua` unload flow, add special handling for data directories:
   - Remove only skeleton files that were originally copied (tracked in state)
   - Do NOT remove user-created files in data directories
   - Remove empty subdirectories only
6. In `state.lua`, ensure state tracking distinguishes `installed_files` from `data_skeleton_files`

**Verification**:
- Load an extension with `provides.data` -- skeleton files are copied to base_dir root
- Existing files at target path are NOT overwritten
- Unload removes only skeleton files, preserves user-created content
- Existing extensions without `provides.data` continue to work unchanged
- manifest.lua validates "data" category without errors

---

### Phase 2: Create Memory Extension Structure [COMPLETED]

**Goal**: Build the complete memory extension directory with manifest, EXTENSION.md, and all required configuration files.

**Estimated effort**: 1 hour

**Objectives**:
1. Create extension directory structure under both .claude/extensions/ and .opencode/extensions/
2. Write manifest.json with all provides categories and merge targets
3. Create EXTENSION.md with memory system documentation for injection into CLAUDE.md/OPENCODE.md
4. Create settings-fragment.json for MCP server configuration
5. Create index-entries.json for context discovery

**Files to modify**:
- `.opencode/extensions/memory/manifest.json` - Extension manifest (primary location)
- `.opencode/extensions/memory/EXTENSION.md` - Documentation for OPENCODE.md injection
- `.opencode/extensions/memory/settings-fragment.json` - MCP server config for Obsidian
- `.opencode/extensions/memory/index-entries.json` - Context index entries for memory docs
- `.claude/extensions/memory/manifest.json` - Mirror manifest for Claude system
- `.claude/extensions/memory/EXTENSION.md` - Documentation for CLAUDE.md injection
- `.claude/extensions/memory/settings-fragment.json` - MCP server config
- `.claude/extensions/memory/index-entries.json` - Context index entries

**Steps**:
1. Create `.opencode/extensions/memory/` directory structure
2. Write `manifest.json` with:
   - name: "memory", version: "1.0.0"
   - language: null (language-agnostic)
   - provides: { commands: ["learn.md"], skills: ["skill-memory"], context: ["project/memory"], data: ["memory"] }
   - merge_targets with both opencode_md and settings keys
   - mcp_servers with obsidian-memory configuration
3. Write `EXTENSION.md` documenting the memory system, /learn command usage, --remember flag for /research
4. Write `settings-fragment.json` with Obsidian CLI REST MCP server configuration
5. Write `index-entries.json` with entries for memory context files
6. Mirror the extension to `.claude/extensions/memory/` with claude-specific merge_target_key

**Verification**:
- manifest.json passes validation via manifest.lua validate()
- EXTENSION.md contains complete memory system documentation
- settings-fragment.json has valid JSON with MCP server config
- index-entries.json has valid entries array

---

### Phase 3: Migrate Command, Skill, and Context [COMPLETED]

**Goal**: Move the /learn command, create a proper memory-management skill, and migrate documentation into the extension structure.

**Estimated effort**: 1.5 hours

**Objectives**:
1. Copy /learn command into extension commands/
2. Create new skill-memory with proper memory management SKILL.md (separate from tag scanning)
3. Move memory documentation into extension context/
4. Create vault skeleton in extension data/

**Files to modify**:
- `.opencode/extensions/memory/commands/learn.md` - Copy of /learn command
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - New memory management skill
- `.opencode/extensions/memory/skills/skill-memory/README.md` - Skill documentation
- `.opencode/extensions/memory/context/project/memory/learn-usage.md` - Usage guide
- `.opencode/extensions/memory/context/project/memory/memory-setup.md` - MCP setup guide
- `.opencode/extensions/memory/context/project/memory/memory-troubleshooting.md` - Troubleshooting
- `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` - Examples
- `.opencode/extensions/memory/data/memory/00-Inbox/README.md` - Inbox skeleton
- `.opencode/extensions/memory/data/memory/10-Memories/README.md` - Memories skeleton
- `.opencode/extensions/memory/data/memory/20-Indices/README.md` - Indices skeleton
- `.opencode/extensions/memory/data/memory/20-Indices/index.md` - Navigation index
- `.opencode/extensions/memory/data/memory/30-Templates/README.md` - Templates skeleton
- `.opencode/extensions/memory/data/memory/30-Templates/memory-template.md` - Memory template

**Steps**:
1. Copy `.opencode/commands/learn.md` to `extensions/memory/commands/learn.md`
   - Update any hardcoded paths to use relative references
   - Update skill delegation from `skill-learn` to `skill-memory`
2. Create `skill-memory/SKILL.md` with proper memory management functionality:
   - Memory creation (from text input or task artifacts)
   - Memory search (via MCP or file scanning)
   - Memory classification (using taxonomy from existing memories)
   - Index maintenance (updating 20-Indices/index.md)
3. Copy documentation from `.opencode/docs/guides/` to `context/project/memory/`:
   - learn-usage.md
   - memory-setup.md
   - memory-troubleshooting.md
   - knowledge-capture-usage.md (from examples/)
4. Create vault skeleton in `data/memory/`:
   - Copy README.md files from each vault subdirectory
   - Copy memory-template.md
   - Copy initial index.md
   - Do NOT copy existing user memories (MEM-*.md files) -- those stay in place
5. Mirror relevant files to `.claude/extensions/memory/` structure

**Verification**:
- learn.md command file references skill-memory correctly
- skill-memory SKILL.md contains memory management (not tag scanning) logic
- All 4 documentation files present in context/project/memory/
- Vault skeleton contains all 4 subdirectory READMEs and template

---

### Phase 4: Implement Safe Unload and Clean Up Core [COMPLETED]

**Goal**: Ensure unloading the memory extension preserves user memories, and remove migrated components from core .opencode.

**Estimated effort**: 1 hour

**Objectives**:
1. Verify the data-preserve unload logic works for memory vault
2. Clean up core .opencode by removing migrated components
3. Update /research command documentation for --remember flag
4. Test full load/unload cycle

**Files to modify**:
- `.opencode/commands/learn.md` - Remove from core (now in extension)
- `.opencode/docs/guides/learn-usage.md` - Remove from core
- `.opencode/docs/guides/memory-setup.md` - Remove from core
- `.opencode/docs/guides/memory-troubleshooting.md` - Remove from core
- `.opencode/docs/examples/knowledge-capture-usage.md` - Remove from core
- `.opencode/skills/skill-learn/SKILL.md` - Evaluate: if only used by /learn, remove; if used by /fix-it equivalent, keep

**Steps**:
1. Verify unload behavior with a test scenario:
   - Load memory extension (creates vault skeleton)
   - Create a test memory file in 10-Memories/
   - Unload extension
   - Confirm test memory file is preserved
   - Confirm skeleton files (READMEs, template) are removed
   - Confirm empty directories are cleaned up but non-empty ones are preserved
2. Remove migrated components from core .opencode:
   - Delete .opencode/commands/learn.md
   - Delete .opencode/docs/guides/learn-usage.md, memory-setup.md, memory-troubleshooting.md
   - Delete .opencode/docs/examples/knowledge-capture-usage.md
   - Evaluate skill-learn: if it's the /fix-it backend, keep it; if redundant, note for separate cleanup
3. Do NOT delete .opencode/memory/ directory -- it contains user data
   - After extension is loaded, the extension manages this directory
   - The directory persists independently of extension state
4. Document in EXTENSION.md that --remember flag requires the extension to be loaded
5. Add a note to /research command that --remember is an extension-provided feature

**Verification**:
- Full load/unload cycle preserves user memory files
- Core .opencode no longer contains learn command or memory docs
- skill-learn status is resolved (kept for tag scanning or removed if redundant)
- /research command documentation updated for --remember dependency

---

### Phase 5: Testing and Documentation [COMPLETED]

**Goal**: Validate the complete memory extension lifecycle and update project documentation.

**Estimated effort**: 0.5 hours

**Objectives**:
1. Test extension load in both .claude and .opencode contexts
2. Verify manifest validation, file copying, merge targets, and MCP settings
3. Update project documentation to reflect memory as an extension

**Files to modify**:
- `.opencode/OPENCODE.md` - Verify extension injection point works
- `.claude/CLAUDE.md` - Verify extension injection point works (if applicable)

**Steps**:
1. Test .opencode load:
   - Run extension load for "memory" via Neovim picker
   - Verify learn.md appears in .opencode/commands/
   - Verify skill-memory appears in .opencode/skills/
   - Verify context files appear in .opencode/context/project/memory/
   - Verify vault skeleton appears in .opencode/memory/ (or merges with existing)
   - Verify EXTENSION.md section injected into OPENCODE.md
   - Verify settings-fragment.json merged into settings
   - Verify index entries merged into index.json
2. Test .claude load:
   - Run extension load for "memory" via Neovim picker
   - Verify same components appear in .claude/ directories
3. Test unload preserves data:
   - Unload extension
   - Verify user memories preserved
   - Verify extension files removed
   - Verify OPENCODE.md section removed
   - Verify settings unmerged
4. Test reload:
   - Reload extension
   - Verify clean state after reload
5. Verify no regression in existing extensions (load/unload nvim, lean, etc.)

**Verification**:
- Extension loads and unloads cleanly in both systems
- No regression in existing extension functionality
- User data survives unload/reload cycles
- MCP server configuration applied correctly

## Testing & Validation

- [ ] manifest.lua validates "data" category in provides
- [ ] copy_data_dirs() copies skeleton files to base_dir root
- [ ] copy_data_dirs() does NOT overwrite existing files
- [ ] Unload removes skeleton files but preserves user-created files
- [ ] Existing extensions load/unload without regression
- [ ] Memory extension loads in .opencode with all components
- [ ] Memory extension loads in .claude with all components
- [ ] /learn command works after extension load
- [ ] Vault skeleton created correctly on first load
- [ ] EXTENSION.md section injected into config file
- [ ] MCP settings merged correctly
- [ ] Index entries merged correctly
- [ ] Full load/unload/reload cycle works

## Artifacts & Outputs

- Modified extension system files (manifest.lua, loader.lua, init.lua, state.lua)
- New extension directory: .opencode/extensions/memory/ (and .claude/extensions/memory/)
- Migrated /learn command and new skill-memory skill
- Migrated documentation to extension context
- Vault skeleton in extension data directory
- Cleaned up core .opencode (removed migrated components)

## Rollback/Contingency

If the "data" category changes cause issues:
1. Revert manifest.lua (remove "data" from VALID_PROVIDES)
2. Revert loader.lua (remove copy_data_dirs)
3. Revert init.lua (remove data loading/unloading)
4. The memory extension can still work without "data" category by using a manual setup step (user creates .opencode/memory/ manually)

If the memory extension itself has issues:
1. Simply unload the extension -- user data is preserved
2. Restore /learn command to core .opencode from git history
3. Restore documentation files from git history
