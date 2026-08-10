# Task 465 - Teammate A: Implementation Approaches and Patterns

## Overview

This report investigates the concrete implementation work required to restructure the core agent
system as a real (non-virtual) extension in `.claude/extensions/core/`. Scope: reading all six
extension loader modules, the current core manifest, three non-core extension manifests, the
sync system, and enumerating every file that would move.

---

## Key Findings

### 1. The Virtual Flag Is Checked in Exactly Two Guards

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`

Two fast-path guards bypass copy/remove operations for virtual extensions:

- **Load fast-path** (lines 357-373): `if ext_manifest.virtual then ... return true, nil end`
  Records state with empty file/dir/merged-sections lists; no pcall copy block executes.
- **Unload fast-path** (lines 527-548): `if extension and extension.manifest and
  extension.manifest.virtual then ... return true, nil end` Skips file removal entirely.

Removing `virtual: true` from the manifest and these two guards is sufficient to make core a
real extension, provided the source files exist at the expected paths in `extensions/core/`.

### 2. The Loader Has No `copy_hooks` Function — This Is a Gap

**File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The loader supports these copy operations:
- `copy_simple_files` — agents, commands, rules (`.md` files)
- `copy_skill_dirs` — skills (directories)
- `copy_context_dirs` — context (directories)
- `copy_scripts` — scripts (`.sh` files)
- `copy_data_dirs` — data (merge-copy semantics)

**Hooks are listed in `VALID_PROVIDES` in `manifest.lua` (line 11) and in the manifest blocklist
structure (line 241), but `init.lua` has no `copy_hooks` call and `loader.lua` has no
`copy_hooks` function.**

The core manifest declares 11 hooks. If core becomes a real extension, these hooks will silently
fail to be installed. Adding `copy_hooks` (a simple variant of `copy_scripts` targeting
`hooks/` with `.sh` extension and `preserve_perms=true`) is a required loader change.

### 3. `manifest.get_core_provides()` Guards on `virtual`

**File**: `lua/neotex/plugins/ai/shared/extensions/manifest.lua`, lines 263-274

```lua
function M.get_core_provides(config)
  local core = M.get_extension("core", config)
  if not core or not core.manifest or not core.manifest.virtual then
    return nil
  end
  return core.manifest.provides
end
```

This function is called by `sync.lua` (line 704) to build the allow-list for core sync
operations. If `virtual` is removed from the manifest, `get_core_provides()` returns `nil`,
which causes `sync.lua` to fall back to the blocklist approach instead of the allow-list
approach. This would degrade sync filtering quality.

**Fix required**: Remove or relax the `not core.manifest.virtual` guard. Simplest fix is to
remove it entirely (just check that the extension exists and has `provides`).

### 4. The Picker Already Filters Out Virtual Extensions

**File**: `lua/neotex/plugins/ai/shared/extensions/picker.lua`, lines 147-152

```lua
local details = extensions_module.get_details(ext.name)
if not (details and details.virtual) then
  table.insert(available, ext)
end
```

Currently core is hidden from the picker because `virtual: true` causes `get_details()` to
return `virtual = true`. Once the virtual flag is removed, core will appear in the picker.

**Decision point**: Should core be visible in the picker?
- If yes: users can (accidentally) unload core, breaking Claude Code in that project.
- If no: add a `"hidden": true` manifest field and filter on that in the picker instead.
- Safeguard option: add a `"protected": true` manifest field and block unload in `manager.unload`.

### 5. File Physical Movement — Complete Enumeration

The following files must be moved from their current `.claude/` locations into
`.claude/extensions/core/`:

**Agents** (8 files → `extensions/core/agents/`):
- `code-reviewer-agent.md`, `general-implementation-agent.md`, `general-research-agent.md`,
  `meta-builder-agent.md`, `planner-agent.md`, `README.md`, `reviser-agent.md`, `spawn-agent.md`

**Commands** (14 files → `extensions/core/commands/`):
- `errors.md`, `fix-it.md`, `implement.md`, `merge.md`, `meta.md`, `plan.md`, `refresh.md`,
  `research.md`, `review.md`, `revise.md`, `spawn.md`, `tag.md`, `task.md`, `todo.md`

**Rules** (6 files → `extensions/core/rules/`):
- `artifact-formats.md`, `error-handling.md`, `git-workflow.md`, `plan-format-enforcement.md`,
  `state-management.md`, `workflows.md`

**Skills** (16 directories → `extensions/core/skills/`):
- `skill-fix-it/`, `skill-git-workflow/`, `skill-implementer/`, `skill-meta/`,
  `skill-orchestrator/`, `skill-planner/`, `skill-refresh/`, `skill-researcher/`,
  `skill-reviser/`, `skill-spawn/`, `skill-status-sync/`, `skill-tag/`,
  `skill-team-implement/`, `skill-team-plan/`, `skill-team-research/`, `skill-todo/`

**Scripts** (27 files → `extensions/core/scripts/`):
- All 26 `.sh` files in `.claude/scripts/` plus `lint/lint-postflight-boundary.sh`
  (subdirectory — verify `copy_scripts` handles recursive subdirectories)

**Hooks** (11 files → `extensions/core/hooks/`):
- `log-session.sh`, `memory-nudge.sh`, `post-command.sh`, `subagent-postflight.sh`,
  `tts-notify.sh`, `validate-plan-write.sh`, `validate-state-sync.sh`,
  `wezterm-clear-status.sh`, `wezterm-clear-task-number.sh`, `wezterm-notify.sh`,
  `wezterm-task-number.sh`

**Context** (15 subdirectories → `extensions/core/context/`):
- `architecture/`, `checkpoints/`, `formats/`, `guides/`, `meta/`, `orchestration/`,
  `patterns/`, `processes/`, `reference/`, `repo/`, `schemas/`, `standards/`,
  `templates/`, `troubleshooting/`, `workflows/`
- ~98 files total inside these directories

**NOT moving** (stay at `.claude/context/`):
- `index.json` — runtime-managed, regenerated on each extension load
- `core-index-entries.json` — special-cased in `init.lua` (line 452); read directly from
  target_dir, not from extension source
- `index.schema.json`, `README.md`, `routing.md`, `validation.md` — metadata/tooling

**Also NOT moving**:
- `.claude/docs/` — synced by `sync.lua`, not managed by extension loader
- `.claude/CLAUDE.md` — base config file; the core EXTENSION.md content would be injected into it
- `.claude/context/index.json`, `.claude/context/core-index-entries.json` — runtime artifacts

### 6. `core-index-entries.json` Has Special Handling That Bypasses Merge Targets

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`, lines 451-462

On every extension load, the loader reads `{target_dir}/context/core-index-entries.json` and
appends its entries to `index.json`. This happens UNCONDITIONALLY and is NOT tracked in the
extension state (not part of `merged_sections`). It runs for every extension load, not just
when core loads.

This means the current `core-index-entries.json` mechanism is separate from the merge_targets
system. If core becomes a real extension with a `merge_targets.index` entry, there would be
TWO mechanisms appending core context entries to `index.json`: the special-case code and the
standard merge_targets path.

**Options**:
1. Keep `core-index-entries.json` at `.claude/context/` as a static fixture (copy it there
   physically as part of the migration, not as a loader-managed file). The special-case code
   in `init.lua` continues to work unchanged.
2. Convert to standard merge_targets and remove the special-case `core-index-entries.json` code.
   This requires the core extension to have `index-entries.json` in its extension directory.

Option 1 is lower-risk and requires no changes to `init.lua`.

### 7. The Sync System's Allow-List Depends on Core's `provides` Map

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, lines 702-760

The sync system calls `manifest.get_core_provides(extension_cfg)` to build an allow-list that
controls which files from the global source repo are synced to target projects. This allow-list
ensures only core-owned files (not extension-owned files) are copied during "Load Core" sync.

Currently this works because:
1. `get_core_provides()` reads core's `virtual: true` manifest
2. Returns the `provides` map (all the core agents, commands, etc.)
3. `build_allow_list()` converts it to a set for O(1) lookup
4. `scan_all_artifacts()` uses the allow-list to filter sync output

If core becomes non-virtual, `get_core_provides()` returns nil (due to the `not virtual` guard),
falling back to the blocklist approach. The sync system degrades but does not break.

**Fix**: Remove the `not core.manifest.virtual` check in `get_core_provides()`.

### 8. Scripts Subdirectory: `copy_scripts` May Not Handle Subdirectories

**File**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`, lines 231-260

`copy_scripts` iterates `manifest.provides.scripts` as a flat list of filenames and constructs
`source_scripts_dir .. "/" .. script_name`. The core manifest lists:
`"lint/lint-postflight-boundary.sh"` — a path with a subdirectory separator.

The current `copy_scripts` implementation constructs:
`source_dir/scripts/lint/lint-postflight-boundary.sh` as source and
`target_dir/scripts/lint/lint-postflight-boundary.sh` as target.

`copy_file()` calls `helpers.ensure_directory(parent_dir)` which would create `scripts/lint/`
as needed. So **this should work** — `copy_file` creates intermediate directories.

Verify that `filereadable(source_path)` still returns 1 for subdirectory paths (it should).

### 9. The Self-Loading Guard Is a WARN, Not a Block

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`, lines 213-226

When loading an extension in the source repo (`project_dir == global_dir`), the guard issues
a `vim.log.levels.WARN` notification but continues. This was relaxed in task 464.

For the source repo, loading core would:
1. Copy files from `extensions/core/agents/` → `.claude/agents/` (already there!)
2. This creates duplicate/overwrite of files that ARE the source

This is benign if the files in `extensions/core/` and `.claude/` are the same content. But
it creates a maintenance burden: the canonical files are in `extensions/core/`, but the source
repo's `.claude/agents/` etc. would be copies installed by the loader.

**Alternative**: After migration, the source repo does NOT self-load core. The files at
`.claude/agents/` etc. are maintained directly (as they are today). The `extensions/core/`
directory IS the source of truth for distribution to other projects. The source repo keeps its
`.claude/` files in sync manually (via git) rather than via the loader.

### 10. CLAUDE.md Restructuring

The current `.claude/CLAUDE.md` (400 lines) contains the entire core agent system documentation.
When core becomes a real extension, it would inject its content via `EXTENSION.md` and
`merge_targets.claudemd`. The flow would be:

- Before loading core: `.claude/CLAUDE.md` is a minimal file (or empty)
- After loading core: `.claude/CLAUDE.md` contains `<!-- SECTION: extension_core -->` block
  with all current CLAUDE.md content

**Problem**: Claude Code reads `.claude/CLAUDE.md` at startup. If core is not loaded, the
CLAUDE.md would be empty/minimal and agents would lose all their routing instructions.

**Mitigations**:
1. Auto-load core on picker open (ensure core is always loaded)
2. Keep CLAUDE.md as-is in source repo (no restructuring), only inject via EXTENSION.md in
   target projects
3. Add a bootstrap mechanism that loads core automatically

For target projects (non-source), the CLAUDE.md would be built by loading core first.

---

## Recommended Approach

Based on the code investigation, here is the recommended implementation sequence:

### Phase 1: Loader Hook Support (prerequisite)
Add `copy_hooks` to `loader.lua` and a corresponding call in `init.lua`. Pattern: identical to
`copy_scripts` with `hooks/` directory and `preserve_perms=true`. Also add hooks to
`check_conflicts` in `loader.lua`.

### Phase 2: Fix `manifest.get_core_provides()`
Remove the `not core.manifest.virtual` guard so the allow-list works whether or not core is
marked virtual. Change condition from:
```lua
if not core or not core.manifest or not core.manifest.virtual then
```
to:
```lua
if not core or not core.manifest or not core.manifest.provides then
```

### Phase 3: Physically Move Core Files
Move all files listed in Finding 5 from `.claude/{category}/` to
`.claude/extensions/core/{category}/`. Update `manifest.json`:
- Remove `"virtual": true`
- Add `merge_targets.claudemd` for EXTENSION.md injection
- Keep `core-index-entries.json` at `.claude/context/` as a static fixture (Option 1)

### Phase 4: Handle Picker Visibility
Add `"protected": true` (or `"hidden": true`) to core's manifest.json to prevent core from
appearing in the picker (or appearing but being unloadable). Update picker.lua to filter on
this field.

### Phase 5: Source Repo Strategy
Decide: does the source repo self-load core?
- **No** (recommended): Keep `.claude/agents/`, `.claude/commands/`, etc. as the working
  copies. The files in `extensions/core/` are the distribution source. The loader copies
  them into `.claude/` only in target projects, not in the source repo. Source repo maintains
  both sets manually (they should be identical).
- **Yes**: Load core in the source repo; `extensions/core/` is the sole source of truth.
  The `.claude/agents/` etc. are loader-managed copies. This is cleaner architecturally but
  means git history is split between `extensions/core/` and `.claude/` after the migration.

### Phase 6: CLAUDE.md Bootstrap
Create a minimal `.claude/CLAUDE.md` stub for the source repo that works without any
extension loaded, plus a full `EXTENSION.md` in `extensions/core/` for injection into
target projects.

---

## Files Affected

### Loader Changes Required

| File | Change | Lines |
|------|--------|-------|
| `lua/neotex/plugins/ai/shared/extensions/loader.lua` | Add `copy_hooks()` function | ~230-260 (after `copy_scripts`) |
| `lua/neotex/plugins/ai/shared/extensions/loader.lua` | Add hooks to `check_conflicts()` | ~335-390 |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Add `copy_hooks` call in load pcall | ~393-414 |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Remove virtual fast-path (load) | ~357-373 |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Remove virtual fast-path (unload) | ~527-548 |
| `lua/neotex/plugins/ai/shared/extensions/manifest.lua` | Fix `get_core_provides()` guard | ~268-273 |
| `lua/neotex/plugins/ai/shared/extensions/picker.lua` | Handle `hidden`/`protected` flag | ~147-152 |

### Core Extension Files to Create

| File | Notes |
|------|-------|
| `.claude/extensions/core/EXTENSION.md` | Core agent system documentation for injection |
| `.claude/extensions/core/agents/*.md` | Moved from `.claude/agents/` |
| `.claude/extensions/core/commands/*.md` | Moved from `.claude/commands/` |
| `.claude/extensions/core/rules/*.md` | Moved from `.claude/rules/` |
| `.claude/extensions/core/skills/*/SKILL.md` | Moved from `.claude/skills/` |
| `.claude/extensions/core/scripts/*.sh` | Moved from `.claude/scripts/` |
| `.claude/extensions/core/hooks/*.sh` | Moved from `.claude/hooks/` |
| `.claude/extensions/core/context/*/` | Moved from `.claude/context/` subdirs |

### Manifest Changes

| File | Change |
|------|--------|
| `.claude/extensions/core/manifest.json` | Remove `"virtual": true` |
| `.claude/extensions/core/manifest.json` | Add `merge_targets.claudemd` (EXTENSION.md) |
| `.claude/extensions/core/manifest.json` | Optionally add `"protected": true` or `"hidden": true` |

### Files That Stay Put

| File | Reason |
|------|--------|
| `.claude/context/index.json` | Runtime-managed, regenerated on each load |
| `.claude/context/core-index-entries.json` | Special-cased in `init.lua`; handled separately |
| `.claude/context/index.schema.json` | Tooling metadata, not extension-managed |
| `.claude/CLAUDE.md` | Base config file; becomes merge target for extensions |
| `.claude/docs/` | Handled by sync system, not extension loader |

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Hooks not copied (missing `copy_hooks`) | High | Add `copy_hooks` before any file movement |
| `get_core_provides()` returns nil after removing virtual flag | Medium | Fix guard before changing manifest |
| Source repo self-loads core → overwrites identical files | Low | Don't self-load in source repo; keep `.claude/` files manual |
| Core appears in picker → user accidentally unloads core | Medium | Add `protected` flag to manifest + enforcement |
| `core-index-entries.json` duplication via two code paths | Medium | Keep as static fixture (Option 1) — no loader change needed |
| 98+ context files to move → git history disruption | Low | Single atomic commit with `git mv` preserves history |
| CLAUDE.md becomes empty without core loaded | High | Keep base CLAUDE.md in source; EXTENSION.md is additive for targets |
| Sync allow-list degrades | Low | Fix `get_core_provides()` guard first |

---

## Confidence Level

**High** for:
- Complete file enumeration (all files identified from manifest + filesystem listing)
- Location of all code changes needed (exact line numbers provided)
- Missing `copy_hooks` gap — confirmed by grep that neither `init.lua` nor `loader.lua` mention hooks
- `get_core_provides()` breaking if virtual flag removed — confirmed by reading the exact guard

**Medium** for:
- CLAUDE.md restructuring strategy — multiple valid approaches, tradeoffs depend on priorities
- Source repo self-loading strategy — both options are viable; "no self-load" is safer

**Low** for:
- Exact content of `EXTENSION.md` — needs careful curation from current CLAUDE.md
- Whether `protected` vs `hidden` is the right UX for core in the picker
