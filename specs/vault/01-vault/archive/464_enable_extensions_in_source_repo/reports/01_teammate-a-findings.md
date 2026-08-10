# Teammate A Findings: Enable Extensions in Source Repo

## Key Findings

### 1. The Self-Loading Guard (Current Blocker)

The guard is in `init.lua` lines 212-219:
```lua
local global_dir = vim.fn.expand("~/.config/nvim")
if project_dir == global_dir and not opts.force then
  return false, "Cannot load extensions into source directory (~/.config/nvim). ..."
end
```

A `force = true` bypass exists but shows a warning. The guard was added specifically because extension loading writes files into `.claude/` (the sync source), and those files would then be included in subsequent syncs to other repos.

### 2. What Extension Loading Does to Shared Files

Extension loading has three categories of side effects on shared files:

**A. File copies** (agents, rules, skills, context, commands, scripts):
- Copied directly into `.claude/agents/`, `.claude/rules/`, `.claude/skills/`, `.claude/context/`, etc.
- These are explicitly tracked in the extension state and removed on unload.

**B. CLAUDE.md section injection** (via `merge.inject_section`):
- Wraps extension content in `<!-- SECTION: {id} -->...<!-- END_SECTION: {id} -->` markers.
- Example: nvim extension injects into `.claude/CLAUDE.md` with `section_id = "extension_nvim"`.

**C. index.json entry append** (via `merge.append_index_entries`):
- Adds entries with `"path": "project/neovim/..."` etc. to `.claude/context/index.json`.
- Tracked by path for removal on unload.

### 3. The Sync Mechanism and Its Existing Defenses

The sync flow (`sync.lua`) copies from `~/.config/nvim/.claude/` to `{project}/.claude/`. It has **three layers** of protection against extension artifact leakage:

**Layer 1: Manifest-based blocklist** (`aggregate_extension_artifacts`):
- Reads all extension `manifest.json` files and builds a blocklist of every filename in `provides.*`.
- Applied during `scan_directory_for_sync()` using exact and prefix matching.
- This blocks **copied files** (agents, rules, skills, context dirs, scripts, commands).
- Context uses prefix matching: `project/neovim` blocks all `project/neovim/*` entries.

**Layer 2: Section preservation in CLAUDE.md** (`preserve_sections` / `restore_sections`):
- During a full sync (replace), extracts `<!-- SECTION: ... -->` blocks from the LOCAL CLAUDE.md before overwriting.
- Then re-appends them after writing the global content.
- This only protects the TARGET repo's CLAUDE.md - it doesn't affect what's in the SOURCE repo.

**Layer 3: Re-injection after full sync** (`reinject_loaded_extensions`):
- After a full sync, re-runs all merge targets for extensions loaded in the TARGET repo.
- Idempotent (all merge operations deduplicate), so re-injection is safe.

### 4. The Actual Leak Risk: Is It Real?

With extensions loaded in `~/.config/nvim`, three things change in the source repo:

**Risk 1: File copies into `.claude/`** (agents, skills, rules, context files)
- The manifest blocklist in sync IS comprehensive for these.
- `aggregate_extension_artifacts()` reads ALL extension manifests and excludes their `provides.*` entries.
- **Verdict: Blocked by Layer 1.** The blocklist covers every file an extension can declare in `provides`.

**Risk 2: CLAUDE.md section injection**
- If nvim extension is loaded in source repo, `.claude/CLAUDE.md` gets `<!-- SECTION: extension_nvim -->...<!-- END_SECTION: extension_nvim -->` appended.
- The sync copies `.claude/CLAUDE.md` as a root file (line 693-695 in sync.lua: `root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }`).
- The section preservation logic only runs on the TARGET's local CLAUDE.md when it would be overwritten. It does NOT strip sections from the SOURCE before copying.
- **Verdict: REAL LEAK.** Extension-injected sections in the source `.claude/CLAUDE.md` WILL be synced to target repos.

**Risk 3: index.json entry append**
- If extensions are loaded in source repo, their `project/...` entries are in `.claude/context/index.json`.
- The sync scans `context/` with `CONTEXT_EXCLUDE_PATTERNS` which excludes `index.json` and `index.json.backup` explicitly (sync.lua line 26-29).
- **Verdict: Blocked.** `index.json` is in `CONTEXT_EXCLUDE_PATTERNS` and is never synced.

**Risk 4: data directories** (e.g., `.memory/`)
- Copied to project root (e.g., `~/.config/nvim/.memory/`).
- The sync does not copy project-root-level directories at all; it only operates on `.claude/` contents.
- **Verdict: Blocked.** Data directories are never part of sync.

**Risk 5: settings.json** (merged by some extensions via merge_targets.settings)
- The sync copies `settings.json` (line 687: `artifacts.settings = sync_scan("", "settings.json")`).
- If an extension merges keys into `.claude/settings.json`, those keys would be synced.
- **Verdict: POTENTIAL LEAK**, depending on whether any extensions use `merge_targets.settings`.

### 5. Summary: Only Two Real Leak Vectors

| Artifact | Sync Behavior | Extension Loaded in Source | Safe? |
|---|---|---|---|
| Agents, rules, skills | Blocklisted by manifest | Extension copies into `.claude/` | YES - blocked |
| Context files | Blocklisted by prefix | Extension copies into `.claude/context/project/` | YES - blocked |
| Scripts, commands | Blocklisted by manifest | Extension copies into `.claude/` | YES - blocked |
| `.claude/CLAUDE.md` (sections) | Copied as root_file | Extension INJECTS into source CLAUDE.md | **NO - LEAKS** |
| `.claude/context/index.json` | Excluded explicitly | Extension appends project/ entries | YES - excluded |
| settings.json | Copied | Extension may merge keys | **POTENTIAL LEAK** |
| data dirs (.memory/) | Not synced | Extension copies to project root | YES - not synced |

### 6. Minimal Fix: Strip Extension Sections from Source CLAUDE.md During Sync

The leak is in `sync_files()` when processing `root_files` for `CLAUDE.md`. The source content (from global dir) is read and written as-is, including any `<!-- SECTION: ... -->` blocks. The fix needs to strip those blocks from the content when reading from the source (global) repo.

The mechanism to do this already exists: `preserve_sections()` extracts the blocks, and the inverse (stripping them from source content) just requires not re-appending them. Essentially, when reading from the global source, strip any `<!-- SECTION: ... -->` blocks before writing to target.

## Recommended Approach

**Minimal Change (Targeted Fix):**

1. **Modify `sync_files()` in `sync.lua`**: When processing a CONFIG_MARKDOWN_FILES entry (CLAUDE.md, OPENCODE.md) with action == "copy" or "replace", strip `<!-- SECTION: ... -->` blocks from the GLOBAL (source) content before writing to target. This ensures extension-injected content in the source repo never reaches targets.

2. **Remove the self-loading guard** in `init.lua` (or relax it to allow loading without `force`): With the CLAUDE.md stripping in place, there is no leak risk for CLAUDE.md. The blocklist already handles file copies.

3. **Verify settings.json**: Audit whether any extension uses `merge_targets.settings` to merge into `.claude/settings.json`. If yes, add settings.json to the strip list or add a separate stripping mechanism for it. Looking at the manifests: the nvim and memory manifests do NOT use `merge_targets.settings`, but this should be confirmed across all extensions.

4. **Optional defense-in-depth for source CLAUDE.md**: After confirming the sync fix works, could also add logic in the `manager.load()` function that, when running in source repo (force=true), uses a different target path for CLAUDE.md injection (e.g., a separate `CLAUDE.local.md` that is never synced).

**The key insight**: The existing blocklist + index.json exclusion already handle 5 of 7 artifact types. Only CLAUDE.md sections (and possibly settings.json) need additional handling. This is a targeted 10-15 line fix in sync.lua rather than a deep restructuring.

## Evidence and Examples

### Blocklist Coverage (from aggregate_extension_artifacts)

For nvim extension with `provides = {agents: ["neovim-research-agent.md", "neovim-implementation-agent.md"], skills: ["skill-neovim-research", ...], rules: ["neovim-lua.md"], context: ["project/neovim"]}`:

- `blocklist.agents["neovim-research-agent.md"] = true` -- blocks exact filename
- `blocklist.context["project/neovim"] = true` -- blocks entire directory tree via prefix match in scan.lua:121

### CLAUDE.md Sync Path (confirmed leak)

In `scan_all_artifacts()` (sync.lua lines 693-712):
```lua
root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }
-- ...
global_path = global_dir .. "/" .. base_dir .. "/" .. filename  -- source: ~/.config/nvim/.claude/CLAUDE.md
local_path = project_dir .. "/" .. base_dir .. "/" .. filename   -- target: {project}/.claude/CLAUDE.md
```

Then in `sync_files()` (lines 258-269):
```lua
local content = helpers.read_file(file.global_path)  -- reads source CLAUDE.md WITH sections
if CONFIG_MARKDOWN_FILES[file.name] and file.action == "replace" then
  -- Reads LOCAL content to preserve, but writes GLOBAL content (with sections) to target
  local local_content = helpers.read_file(file.local_path)
  local sections = preserve_sections(local_content)  -- extracts LOCAL sections
  content = restore_sections(content, sections)       -- appends LOCAL sections to GLOBAL (which already has them)
end
helpers.write_file(file.local_path, content)  -- writes GLOBAL content WITH source sections
```

The stripping fix is a one-liner: before writing, strip `<!-- SECTION: ... -->` blocks from `content` (the global/source content).

### Current State of Source Repo (confirmed no leakage currently)

- `~/.config/nvim/.claude/CLAUDE.md`: 0 `<!-- SECTION: -->` markers (no extensions loaded in source repo)
- `~/.config/nvim/.claude/context/index.json`: 0 `project/` entries (no extension context injected)

This confirms the self-loading guard is currently working correctly.

## Confidence Level: **High**

The code paths are fully traced. The blocklist mechanism is comprehensive for file copies. The only real leak vector is CLAUDE.md section injection, and the fix is straightforward. The `preserve_sections()` / `restore_sections()` functions provide the exact building blocks needed - just apply stripping to the source content rather than (only) preserving from the local content.
