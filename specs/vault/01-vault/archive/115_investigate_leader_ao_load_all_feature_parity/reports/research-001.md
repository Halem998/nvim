# Research Report: Task #115

**Task**: 115 - investigate_leader_ao_load_all_feature_parity
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis (sync.lua, scan.lua, config.lua, entries.lua, parser.lua)
**Artifacts**: - /home/benjamin/.config/nvim/specs/115_investigate_leader_ao_load_all_feature_parity/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `<leader>ao` Load All Artifacts operation for OpenCode is missing **11 artifact categories** that are synced for `<leader>ac` Claude Code
- Root cause: The `scan_all_artifacts()` function in `sync.lua` has a `if base_dir == ".claude"` guard (line 184) that excludes most artifact types from OpenCode syncing
- Additionally, the agents subdirectory is hardcoded as `"agents"` but OpenCode uses `"agent/subagents"`, so agents are never found
- The `orchestrator.md` at `agent/orchestrator.md` is also not synced (not in subagents/)
- Several root files are missing from the OpenCode root_file_names list
- Extensions directory is not synced for either system

## Context & Scope

The investigation compares what `<leader>ao` (OpenCode picker Load All) copies vs `<leader>ac` (Claude Code picker Load All) to identify feature parity gaps. Both pickers share the same implementation (`sync.lua`) but the code has system-specific branching that limits OpenCode.

## Findings

### 1. The Critical Guard: `if base_dir == ".claude"` (sync.lua:184-217)

The `scan_all_artifacts()` function has the following structure:

```lua
-- Core artifacts common to both systems (lines 168-181)
artifacts.commands = sync_scan("commands", "*.md")         -- BOTH
artifacts.agents = sync_scan("agents", "*.md")             -- BOTH (but wrong path for opencode)
artifacts.skills = sync_scan("skills", "*.md") + "*.yaml"  -- BOTH

-- .claude/-specific artifacts (lines 183-217)
if base_dir == ".claude" then
  artifacts.hooks      -- CLAUDE ONLY
  artifacts.templates  -- CLAUDE ONLY
  artifacts.lib        -- CLAUDE ONLY
  artifacts.docs       -- CLAUDE ONLY
  artifacts.scripts    -- CLAUDE ONLY
  artifacts.tests      -- CLAUDE ONLY
  artifacts.rules      -- CLAUDE ONLY
  artifacts.context    -- CLAUDE ONLY
  artifacts.systemd    -- CLAUDE ONLY
  artifacts.settings   -- CLAUDE ONLY
end
```

This means when `base_dir == ".opencode"`, **only commands, agents (broken), and skills** are scanned.

### 2. Agents Path Mismatch

The sync code hardcodes:
```lua
artifacts.agents = sync_scan("agents", "*.md")
```

But OpenCode uses `agent/subagents/` not `agents/`:
- `.opencode/agents/` -- **DOES NOT EXIST**
- `.opencode/agent/subagents/` -- **ACTUAL LOCATION** (17 agent files)
- `.opencode/agent/orchestrator.md` -- **ALSO MISSED** (root-level orchestrator)

The `shared/picker/config.lua` correctly defines `agents_subdir = "agent/subagents"` for OpenCode (line 81), but `scan_all_artifacts()` does not use this config value.

### 3. Missing Artifact Categories for OpenCode

| Category | .opencode/ Files | Synced by Load All? | Notes |
|----------|-----------------|---------------------|-------|
| commands | 15 files | YES | Works correctly |
| agents | 17 subagents + 1 orchestrator | NO (wrong path) | Scans `agents/` which does not exist |
| skills | 22 files (md + yaml) | YES | Works correctly |
| hooks | 9 files (.sh) | NO | Behind `.claude` guard |
| templates | 1 file (.yaml) | NO | Behind `.claude` guard |
| docs | 11 files (.md) | NO | Behind `.claude` guard |
| scripts | 15 files (.sh) | NO | Behind `.claude` guard |
| rules | 8 files (.md) | NO | Behind `.claude` guard |
| context | 206 files (197 md, 3 json, 1 yaml) | NO | Behind `.claude` guard |
| systemd | 2 files (.service, .timer) | NO | Behind `.claude` guard |
| extensions | 13 files | NO | Not synced for either system |
| root files | 7 files | PARTIAL | Only OPENCODE.md and settings.json |

### 4. Missing Root Files for OpenCode

Current `root_file_names` for OpenCode (sync.lua:222):
```lua
root_file_names = { "OPENCODE.md", "settings.json" }
```

Actual root files in `.opencode/`:
| File | Currently Synced? |
|------|-------------------|
| OPENCODE.md | YES |
| settings.json | YES |
| .gitignore | NO |
| README.md | NO |
| QUICK-START.md | NO |
| bun.lock | NO (may not be needed) |
| package.json | NO (may not be needed) |

### 5. Extensions Not Synced (Both Systems)

Neither `.claude` nor `.opencode` sync the `extensions/` directory via Load All. The extensions directory contains language-specific packs:

- `.opencode/extensions/formal/` - 5 files
- `.opencode/extensions/lean/` - 8 files

These are managed through the extension load/unload mechanism in the picker, not via bulk sync. This may be intentional.

### 6. OpenCode-Specific Directories Not in .claude

| Directory | In .opencode? | In .claude? | Notes |
|-----------|---------------|-------------|-------|
| `agent/` | YES (with orchestrator.md) | NO (uses `agents/`) | Different naming |
| `specs/` | YES (TODO.md, state.json) | NO (specs at project root) | Different location |

### 7. File Count Summary

**What .claude Load All syncs (approximately):**
- commands: 11 + hooks: 9 + templates: 1 + lib: ? + docs: 22 + scripts: 12 + tests: ? + skills: 11 + agents: 6 + rules: 6 + context: 102 + systemd: 2 + settings: 1 + root_files: 4 = **many hundreds of files**

**What .opencode Load All currently syncs:**
- commands: 15 + skills: 22 + agents: 0 (broken) + root_files: 2 = **39 files**

**What .opencode Load All SHOULD sync:**
- commands: 15 + agents: 18 + skills: 22 + hooks: 9 + templates: 1 + docs: 11 + scripts: 15 + rules: 8 + context: 206 + systemd: 2 + root_files: 5+ = **312+ files**

## Recommendations

### Fix 1: Remove the `.claude`-only Guard (Critical)

Replace the `if base_dir == ".claude"` conditional with shared scanning that works for both systems. All artifact types that exist in `.opencode/` should be scanned regardless of `base_dir`.

**In `sync.lua`, lines 183-217, change from:**
```lua
if base_dir == ".claude" then
  artifacts.hooks = sync_scan("hooks", "*.sh")
  artifacts.templates = sync_scan("templates", "*.yaml")
  -- ... etc
end
```

**To scanning unconditionally** (all categories that both systems share):
```lua
-- Artifacts common to both .claude and .opencode
artifacts.hooks = sync_scan("hooks", "*.sh")
artifacts.templates = sync_scan("templates", "*.yaml")
artifacts.docs = sync_scan("docs", "*.md")
artifacts.scripts = sync_scan("scripts", "*.sh")
artifacts.rules = sync_scan("rules", "*.md")
artifacts.systemd = {} -- handle per-system below

-- Context (multiple file types: md, json, yaml)
local ctx_md = sync_scan("context", "*.md", true, CONTEXT_EXCLUDE_PATTERNS)
local ctx_json = sync_scan("context", "*.json")
local ctx_yaml = sync_scan("context", "*.yaml")
artifacts.context = {}
for _, files in ipairs({ ctx_md, ctx_json, ctx_yaml }) do
  for _, file in ipairs(files) do
    table.insert(artifacts.context, file)
  end
end

-- System-specific artifacts
if base_dir == ".claude" then
  artifacts.lib = sync_scan("lib", "*.sh")
  artifacts.tests = sync_scan("tests", "test_*.sh")
  artifacts.settings = sync_scan("", "settings.json")

  -- Systemd (.claude naming)
  local systemd_service = sync_scan("systemd", "*.service")
  local systemd_timer = sync_scan("systemd", "*.timer")
  for _, file in ipairs(systemd_service) do
    table.insert(artifacts.systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(artifacts.systemd, file)
  end
elseif base_dir == ".opencode" then
  -- Systemd (.opencode naming)
  local systemd_service = sync_scan("systemd", "*.service")
  local systemd_timer = sync_scan("systemd", "*.timer")
  for _, file in ipairs(systemd_service) do
    table.insert(artifacts.systemd, file)
  end
  for _, file in ipairs(systemd_timer) do
    table.insert(artifacts.systemd, file)
  end
end
```

Note: `.opencode/` does not have `lib/` or `tests/` directories, so those can remain `.claude`-only. But `scan_directory_for_sync` already returns empty if the directory does not exist, so it is safe to scan unconditionally.

### Fix 2: Use Config for Agents Path (Critical)

Change the hardcoded `"agents"` to use the config's `agents_subdir`:

**In `scan_all_artifacts()`, line 170, change from:**
```lua
artifacts.agents = sync_scan("agents", "*.md")
```

**To:**
```lua
local agents_subdir = (config and config.agents_subdir) or "agents"
artifacts.agents = sync_scan(agents_subdir, "*.md")
```

### Fix 3: Sync Orchestrator.md for OpenCode (Important)

The `agent/orchestrator.md` file sits outside `agent/subagents/` and would not be picked up by scanning `agent/subagents`. Add explicit handling:

```lua
if base_dir == ".opencode" then
  -- Also sync orchestrator.md from agent/ root
  local orchestrator_files = sync_scan("agent", "orchestrator.md", false)
  for _, file in ipairs(orchestrator_files) do
    table.insert(artifacts.agents, file)
  end
end
```

### Fix 4: Expand OpenCode Root Files (Minor)

**In `scan_all_artifacts()`, line 222, change from:**
```lua
root_file_names = { "OPENCODE.md", "settings.json" }
```

**To:**
```lua
root_file_names = { "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }
```

The `bun.lock` and `package.json` are likely build artifacts and may not need syncing.

### Fix 5: Extensions Sync (Optional, Lower Priority)

Extensions are currently not synced for either system. If desired, add:
```lua
artifacts.extensions = sync_scan("extensions", "*.*", true)
```

However, extensions have their own load/unload lifecycle, so bulk syncing may not be appropriate. This should be a deliberate design decision.

## Decisions

1. **Unconditional scanning is safe**: `scan_directory_for_sync` returns an empty array when a directory does not exist, so scanning directories that only exist in one system will not cause errors.
2. **The `.claude` guard was likely a conservative initial implementation** rather than an intentional feature restriction.
3. **Extensions should NOT be bulk-synced** -- they have their own activation mechanism through the picker UI.
4. **`lib/` and `tests/` are .claude-only** -- OpenCode does not have these directories and does not need them.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Syncing OpenCode context (206 files) could be slow | Low | Same recursive scan used for .claude context already works |
| Wrong agents path could create `agents/` dir in OpenCode projects | Medium | Use config's `agents_subdir` to ensure correct path |
| Root file conflicts (settings.json synced via both root_files and settings category) | Low | For OpenCode, settings.json is already in root_file_names; remove duplicate if adding general settings scan |
| Existing projects may have stale .opencode/ artifacts | Low | The merge_only option already handles this via user prompt |

## Appendix

### Files Analyzed
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Main sync logic with the `.claude`-only guard
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning utilities
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/picker/config.lua` - Picker configuration (shows agents_subdir difference)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/opencode/commands/picker.lua` - OpenCode picker facade
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Main picker orchestration
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Entry display logic

### Directory Comparison
- `.opencode/` has 14 top-level directories: agent, commands, context, docs, extensions, hooks, rules, scripts, skills, specs, systemd, templates + root files
- `.claude/` has 15 top-level directories: agents, commands, context, docs, extensions, hooks, logs, output, rules, scripts, skills, systemd, templates + root files
- Key structural difference: `.opencode/agent/` vs `.claude/agents/`
