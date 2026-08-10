# Task 464: Alternative Architectures for Source Repo Extension Loading

**Teammate B - Alternative Approaches**
**Focus**: Alternative patterns and prior art beyond minimal-change fixes

---

## Key Findings

### 1. The Self-Loading Guard Is a Symptom, Not the Root Problem

The guard in `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 212-229) prevents loading extensions when `project_dir == global_dir`. The comment explains the reasoning: extension artifacts loaded here would "contaminate the source and cause extension artifacts to leak into core sync."

This framing reveals the actual tension: the source repo is simultaneously:
- The **authoritative source** of core artifacts (what sync copies out)
- A **consumer project** that should be able to run with extensions active

These two roles are architecturally incompatible under the current copy-based model where extensions write files into the same `.claude/` tree that sync reads from.

### 2. The Sync Already Has an Extension Blocklist - It's Just Incomplete

`manifest.aggregate_extension_artifacts()` in `manifest.lua` (lines 233-261) builds a set-based blocklist from all extension manifests. The sync uses this blocklist to filter extension artifacts during "Load Core Agent System." This mechanism already works for **file-based artifacts** (agents, skills, rules, context).

The problem is that extensions also write to **shared files** via merge targets:
- `CLAUDE.md` - extension sections injected with `<!-- SECTION: -->` markers
- `context/index.json` - extension entries appended
- `settings.json` / `settings.local.json` - MCP server configs merged

The sync has partial handling for these (section preservation, re-injection on sync), but the source repo would have these files permanently modified if extensions were loaded there.

### 3. How `extensions.json` Tracks State - A Critical Asset

`state.lua` tracks exactly which files were installed and which sections were merged per extension. This is already the foundation for clean unload. The `installed_files`, `installed_dirs`, and `merged_sections` fields give complete rollback information.

**Key insight**: If extensions are loaded into the source repo with this tracking intact, the sync could use `extensions.json` to know *exactly* what to exclude - not just from manifests (what an extension *can* install) but from state (what is *actually* installed right now).

### 4. The Sync Excludes Dirs from the Source, Not Files in Place

The current sync reads artifacts from `global_dir/.claude/` and copies them to `project_dir/.claude/`. Extension filtering happens at the **scan phase** - the blocklist prevents extension files from being included in what gets copied. This means the source directory's `.claude/` tree is the reference, and its state determines what downstream repos receive.

Extension loading into the source repo would add files to that tree (agents, skills, context dirs), and those files would be included in the next sync unless blocked. The blocklist handles declared files, but merge targets (CLAUDE.md content, index.json entries) flow through file content, not file identity.

---

## Alternative Architecture Approaches

### Approach A: "Core as Extension" - Full Inversion

**Concept**: Redefine the entire current `.claude/` directory (minus extensions/) as a "core" extension. Every project, including the source repo, loads `core` + domain extensions.

**How it would work**:
- Create `.claude/extensions/core/manifest.json` declaring all current core agents, skills, rules, context
- The source repo would have an empty `.claude/` base (or a tiny bootstrap)
- Sync would become "load core extension" which copies from `extensions/core/` to target

**Assessment**:
- **Massive migration cost**: All current core files would need to be restructured
- **Circular dependency risk**: The extension loader itself lives in Neovim Lua, not in `.claude/`
- **Fundamental mismatch**: Extensions are designed to augment core, not BE the core. The extension loader reads from `global_extensions_dir` which points back to the source repo anyway
- **No practical gain**: The sync problem shifts but doesn't disappear - you still need to know what "core" is vs what's domain-specific
- **Verdict**: Architecturally elegant but practically infeasible without massive rework. Low recommendation.

### Approach B: Dual-Tree Architecture - Source Repo Gets a Separate Install Target

**Concept**: Extensions in the source repo load into a **parallel tree** (e.g., `.claude-local/` or `.claude/.local/`) rather than into `.claude/` proper. Sync only ever reads from `.claude/` (the clean tree).

**How it would work**:
- Add a new config preset `config.local_overlay(global_dir)` with `base_dir = ".claude/.local"`
- Claude Code would not see `.claude-local/` since it only reads `.claude/`
- Sync scans `.claude/` and ignores `.claude-local/`

**Problem**: Claude Code and the agent system read from `.claude/` exclusively. A parallel tree is invisible to agents. Extensions loaded into `.claude-local/` would not provide routing, context, skills, or rules to Claude Code sessions.

**Verdict**: Solves the sync leak but makes extensions non-functional in the source repo. Not useful.

### Approach C: Symlink-Based Extension Loading

**Concept**: Instead of copying files into `.claude/`, extensions create symlinks pointing back to their source directories.

**How it would work**:
- `loader.lua` creates symlinks: `.claude/agents/nvim-agent.md -> .claude/extensions/nvim/agents/nvim-agent.md`
- Sync skips symlinks (already has `skip_symlinks` parameter in `scan_directory_for_sync`)
- Source repo extensions are functional (Claude Code follows symlinks) but don't pollute the actual tree

**Evidence**: `scan.lua` already has a `skip_symlinks` parameter (line 53: `@param skip_symlinks boolean|nil Skip symlink files as defense in depth`). This suggests symlink awareness was already considered.

**Assessment**:
- Sync already has the `skip_symlinks` parameter - it just needs to be enabled for the source repo case
- Symlinks work transparently for Claude Code (files appear at expected paths)
- Unload is clean (delete symlinks, not files)
- Merge targets (CLAUDE.md sections, index.json entries) still need to be handled separately - symlinks don't help there
- Cross-filesystem moves won't work but source repo is local, so this is fine
- **The missing piece**: scan.lua's `skip_symlinks` is passed through but the blocklist is still the primary filter. Need to verify if `skip_symlinks=true` would be sufficient.

**Verdict**: Most promising alternative. Symlinks are already partially contemplated. Medium-high recommendation for file-based artifacts.

### Approach D: State-Aware Sync Exclusion (Extend the Blocklist with Live State)

**Concept**: The sync reads `extensions.json` from the source repo and uses its `installed_files` and `merged_sections` to dynamically exclude exactly what's loaded, not just what manifests declare.

**How it would work**:
- `sync.lua`'s `scan_all_artifacts()` already calls `manifest.aggregate_extension_artifacts()` to build the blocklist from manifest declarations
- Extend this to also read the source repo's `.claude/extensions.json` and add `installed_files` to the blocklist
- For merge targets, track which sections are extension-injected and strip them when syncing CLAUDE.md/index.json

**Assessment**:
- `extensions.json` tracks exactly what's installed with full file paths (`installed_files` array in `state.lua`)
- This approach is **additive** - the manifest blocklist stays, state-based exclusion supplements it
- Handles the case where `provides` in manifest doesn't perfectly enumerate installed files (e.g., copied context dirs)
- The harder problem remains: shared file content (CLAUDE.md sections). The sync already has section preservation logic using `<!-- SECTION: -->` markers. If the source repo has loaded extensions, their sections would be in CLAUDE.md. The sync would need to **strip** rather than **preserve** these sections.
- Specifically: `preserve_sections()` in sync.lua currently preserves injected sections. In the source repo case, you'd want to **exclude** them when computing what to sync outward.

**Verdict**: Solid incremental improvement. Works well for file artifacts. The shared-file problem requires inverting the current "preserve extensions" logic for the source repo case. Medium recommendation.

### Approach E: Git-Worktree Isolation

**Concept**: Use a git worktree for the "installed" state. The clean branch has no extension artifacts; a worktree branch has extensions loaded. Sync always reads from the clean branch.

**How it would work**:
- Source repo has two branches: `main` (clean core) and `dev-with-extensions` (extensions loaded)
- User works in the worktree with extensions active
- Sync command reads from `main` branch files, not worktree files

**Assessment**:
- Significant workflow overhead
- The agent system already has worktree support (`.claude/worktrees/`), so infrastructure exists
- But this is overkill for the problem - the user wants to use the source repo normally, not maintain parallel branches
- **Verdict**: Too complex, wrong tool for this problem. Not recommended.

### Approach F: Package-Manager Model (Register-Don't-Copy)

**Concept**: Extensions don't copy files into `.claude/`. Instead, they register themselves in a manifest registry, and Claude Code reads from extension directories directly via configured paths.

**How it would work**:
- Extension "load" writes an entry to `.claude/extensions-registry.json`: `{"nvim": {"path": ".claude/extensions/nvim/", "active": true}}`
- Skills, agents, rules directories become search paths, not copy destinations
- Claude Code would need to support multi-path search (it doesn't currently)

**Assessment**:
- Claude Code's `.claude/` structure is fixed - it reads agents from `.claude/agents/`, skills from `.claude/skills/`, etc.
- This would require fundamental changes to how Claude Code discovers artifacts
- Out of scope for this task
- **Verdict**: Architecturally ideal for the long term, but requires Claude Code changes. Not feasible now.

---

## Recommended Approach

**Primary Recommendation: Hybrid Symlink + State-Aware Sync (Approaches C + D)**

This is the approach most aligned with the existing architecture while enabling extensions in the source repo.

### Phase 1: Symlink-Based Loading in Source Repo

Modify `loader.lua` to detect when `project_dir == global_dir` and use symlinks instead of file copies:

```lua
-- In loader.lua: symlink_or_copy() selector
local function install_file(src, dst, project_dir, config)
  local global_dir = vim.fn.expand("~/.config/nvim")
  if project_dir == global_dir then
    -- Use symlink for source repo (sync skips symlinks)
    vim.fn.system(string.format("ln -sf %s %s", vim.fn.shellescape(src), vim.fn.shellescape(dst)))
  else
    -- Normal copy for consumer repos
    -- existing copy logic...
  end
end
```

The `skip_symlinks` parameter in `scan_directory_for_sync` would then naturally exclude these from sync.

### Phase 2: Section-Stripping for Shared Files in Sync

Extend `sync.lua`'s handling of CLAUDE.md in the source repo case. When `project_dir == global_dir` (i.e., sync is reading FROM the source), strip extension sections rather than preserve them:

The current `preserve_sections()` / `restore_sections()` logic runs at the **destination**. For source repo, the question is different: the SOURCE has extension sections that should not flow to destinations.

Add a `strip_extension_sections()` function that removes `<!-- SECTION: extension_* -->` blocks from content before it's used as the sync source.

### Phase 3: Update the Self-Loading Guard

Remove (or weaken) the guard in `init.lua` once symlink-based loading is in place:

```lua
-- Instead of blocking, use symlink mode automatically
if project_dir == global_dir then
  opts.symlink_mode = true  -- Signal to loader to use symlinks
end
```

### Why This Works

1. **Sync safety**: `scan_directory_for_sync` has `skip_symlinks` parameter already - enabling it for symlinks means extension agent/skill/rule files in the source repo are naturally excluded from sync
2. **Extension functionality**: Symlinks appear as real files to Claude Code, so routing, context, rules all work normally
3. **Clean unload**: Deleting symlinks is cleaner than managing copied files; `installed_files` tracking still works
4. **Minimal migration**: No restructuring of core vs extension concepts needed
5. **Merge target challenge**: Still requires handling CLAUDE.md sections and index.json - but these are bounded problems with existing marker infrastructure

---

## Evidence / Examples

### Existing Symlink Awareness
```
-- scan.lua line 53:
--- @param skip_symlinks boolean|nil Skip symlink files as defense in depth (default: false)
```
The parameter exists but `skip_symlinks=false` by default. This suggests the architecture already contemplated symlink-aware scanning.

### Section Markers Are Already Structured for Removal
```
<!-- SECTION: extension_nvim -->
[Extension content]
<!-- END_SECTION: extension_nvim -->
```
The `preserve_sections()` function in sync.lua can find these exactly. A `strip_extension_sections()` function would be the inverse.

### The Blocklist Pattern Works for Files
`aggregate_extension_artifacts()` in manifest.lua already demonstrates the pattern: read all manifests, build a blocklist. Extending this to read `extensions.json` for live state is a natural extension of the same pattern.

### State Tracks Exact Install Path
From `state.lua` `mark_loaded()`:
```lua
state.extensions[extension_name] = {
  installed_files = installed_files or {},  -- exact paths
  merged_sections = merged_sections or {},  -- what was merged
  ...
}
```
The state already carries enough information to reverse the installation precisely.

---

## What NOT to Do

1. **Don't make core a "core extension"**: Too much migration cost, circular architecture, no practical benefit over the hybrid approach
2. **Don't use a parallel tree (`.claude-local/`)**: Extensions would be invisible to Claude Code
3. **Don't use git worktrees**: Wrong abstraction level, high overhead
4. **Don't fight the copy model for consumer repos**: Extensions in consumer repos should keep copying (not symlinks) because consumer repos don't have the extension source directories locally

---

## Confidence Level

**Overall: Medium-High**

- Symlink-based loading (Phase 1): **High confidence** - `skip_symlinks` parameter already exists, symlinks are transparent to Claude Code, clean to implement
- Section stripping for sync (Phase 2): **Medium confidence** - the infrastructure (section markers, `preserve_sections`) exists; the inverse logic is new but straightforward
- Guard removal/weakening (Phase 3): **High confidence** - the guard is deliberately bypassable with `force=true`; making it automatic for symlink mode is minimal change

**Risk**: Merge targets (CLAUDE.md, index.json) for extensions in the source repo are the most complex part. Even with symlinks for file artifacts, these shared-file modifications still happen via in-place edits. A full solution needs to handle both.

**Unknown**: Whether Claude Code actually follows symlinks for `.claude/agents/`, `.claude/skills/`, etc. - this assumption should be verified before committing to the symlink approach.
