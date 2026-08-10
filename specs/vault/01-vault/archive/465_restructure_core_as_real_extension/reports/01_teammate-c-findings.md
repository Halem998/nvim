# Teammate C Findings: Critical Evaluation of Core-as-Real-Extension Restructure

**Task**: #465 — Restructure core agent system as a real extension in `.claude/extensions/core/`
**Date**: 2026-04-16
**Role**: Critic — gaps, risks, failure modes, unresolved concerns

---

## Key Findings

### Finding 1: "No Bootstrap Problem" Claim Is Correct But Incomplete

The task description correctly identifies that the Round 2 "bootstrap impossibility" in task 464
was a category error: Teammate C from 464 conflated the Lua extension loader (neovim plugin) with
the Claude agent system (.claude/ files). These are independent systems.

**Validated**: The Lua loader does not depend on files in `.claude/` to function. It can
successfully load core by copying files from `.claude/extensions/core/` to `.claude/` even if
`.claude/` is empty at the start.

**The incomplete part**: There IS a pre-condition that matters. `settings.json` references hook
scripts at relative paths (`bash .claude/hooks/*.sh`) and is read by Claude Code at session start.
If core hasn't been loaded yet, `.claude/hooks/` does not exist. The hooks fail silently
(`|| echo '{}'`), so Claude Code still starts — but with no hook functionality. This is an
inconvenience, not a hard failure. The task description should acknowledge this consequence for
the "cold start before core load" scenario.

**Evidence**: `settings.json` contains 12 references to `.claude/hooks/*.sh` matching the
11 hooks listed in core's manifest `provides.hooks`. All use the `|| echo '{}'` silent-fail
pattern. Settings.json is read by Claude Code at session start and is in the "files that stay
in `.claude/`" list — so it is always present, but it references hooks that may not be.

### Finding 2: The Sync System Breaks Completely After Physical Move

This is the most severe technical risk.

`sync.lua:scan_all_artifacts()` builds source paths as:
```
global_dir + "/" + base_dir + "/" + subdir
```
Where `subdir` is a category name like `"agents"`, `"hooks"`, `"skills"`, etc.

After physically moving all core files to `.claude/extensions/core/`, the directories
`.claude/agents/`, `.claude/hooks/`, `.claude/skills/`, `.claude/commands/`, `.claude/rules/`,
`.claude/scripts/`, `.claude/context/`, `.claude/docs/` would all be EMPTY in the source repo
until core is loaded.

The sync system scans those directories and finds nothing. Result: `total_files == 0`, sync
reports "No global artifacts found" or syncs 0 files. The "Load Core Agent System" feature
becomes permanently broken unless the sync source is updated.

**Task description acknowledges this**: "(6) Update sync system to source from
`.claude/extensions/core/` or operate on loaded state." But this is listed as a bullet, not
quantified. The actual work involves changing `scan_all_artifacts()` to detect when core is
real (non-virtual) and source from `extensions/core/{category}/` instead of `.claude/{category}/`.
This affects ~15 category scan calls across lines 766-870 of `sync.lua`.

**Alternative approach**: Source from `.claude/{category}/` but require core to be loaded in
the source repo before sync. This avoids changing sync logic but means "Load Core Agent System"
requires the user to first load core in the source repo (creating a chicken-and-egg UX problem
for first-time setup).

### Finding 3: Existing Repos Have Core Files Present But Core Not in extensions.json

Three repos with the agent system installed were inspected:
- `~/.dotfiles`: has extensions `nvim`, `memory`, `nix` loaded — but NOT `core`
- `~/.config/zed`: has 8 extensions loaded — but NOT `core`
- `~/Philosophy/Papers/PossibleWorlds`: has 5 extensions loaded — but NOT `core`

All three have `.claude/agents/`, `.claude/skills/`, etc. populated from past "Load Core Agent
System" syncs. After the physical move, if a user tries to load core via `<leader>ac`, the
`loader.check_conflicts()` function detects all ~208 files as existing conflicts. The user sees:

> "Note: 208 existing file(s) will be overwritten."

This is technically correct (core would re-copy identical files), but it is alarming and
confusing for users who don't understand the migration context.

**Migration requirement**: All existing repos must either:
1. Accept the conflict-overwrite to establish core as a tracked extension, OR
2. Have their `extensions.json` programmatically updated to mark core as `active` with
   appropriate `installed_files` list (complex and error-prone).

There is no clean zero-friction migration path for existing repos.

### Finding 4: Precise File Count Is 208, Not ~280

Direct filesystem count of files that would physically move:
- `agents/`: 8 files
- `commands/`: 14 files
- `rules/`: 6 files
- `skills/`: 16 files (directories, each with multiple files — actual file count within
  the 16 skill dirs not broken out here but skills contains 16 tracked entries in manifest)
- `context/`: 101 files
- `scripts/`: 27 files
- `hooks/`: 11 files
- `docs/`: 23 files
- `templates/`: 2 files
- `systemd/`: 2 files

**Total: ~208 files** (excluding `CLAUDE.md`, `README.md`, `settings.json`,
`settings.local.json`, `.gitignore` which stay, and `extensions/` which stays).

The task description says "~280 files" — this overstates by ~35%.

### Finding 5: The utils/ Directory Is an Orphan in the Current System

Three core skills reference `.claude/utils/team-wave-helpers.md` at hardcoded paths:
- `skills/skill-team-plan/SKILL.md`
- `skills/skill-team-research/SKILL.md`
- `skills/skill-team-implement/SKILL.md`

But `utils/` is NOT in core's manifest `provides` and is NOT scanned by the sync system
(no `artifacts.utils` in `scan_all_artifacts()`). This means:
1. `utils/team-wave-helpers.md` is already missing from target repos (pre-existing bug)
2. After physical move, `utils/` would need to be either added to the core manifest
   (as a new category) or the team skills would need to embed the content inline

This is a pre-existing gap that the physical move forces to be resolved. Not introduced by
the task, but surfaced by it.

### Finding 6: context/core-index-entries.json Has Dual-Role Tension

The loader (`init.lua:451-462`) reads `core-index-entries.json` from the TARGET directory
(`target_dir + "/context/core-index-entries.json"`) — NOT from the extension source directory.
This comment explains it: "Load core context entries (always included, not extension-specific)."

After physical move, `core-index-entries.json` would live in `extensions/core/context/`.
When core loads, it copies this file to `.claude/context/`. The loader then reads it from
the target. This works — but ONLY after core is loaded.

For any extension that loads BEFORE core (impossible if all extensions declare
`"dependencies": ["core"]`, but relevant for the source repo before any extension is loaded),
`core-index-entries.json` would not be in the target `.claude/context/` directory, so the
loader skips it silently. This is handled gracefully (`fs_stat` check at line 452).

The task description's "Files that stay in `.claude/`" list includes both `context/index.json`
AND `context/core-index-entries.json`. If `core-index-entries.json` stays, it would be a
permanent resident of `.claude/context/` even when core is "unloaded" — which contradicts
the extension model where unload removes installed files. This inconsistency needs a decision.

### Finding 7: Git History and Cross-Reference Impact

Moving ~208 files in a single commit breaks `git log --follow` for all moved files. Future
`git blame` on agent system files will have a gap at the migration commit. There are ~924 lines
in `.claude/**/*.md` that reference `.claude/` paths — these remain valid because the INSTALLED
paths stay at `.claude/{category}/` (the extensions copy TO there). So cross-references in the
content of moved files do not need updating.

The git impact is manageable (single migration commit with `git mv`) but should be documented
in the commit message for future archaeology.

---

## Bootstrap Analysis

**"No bootstrap problem" claim: VALIDATED (with caveats)**

Code path trace for loading core as a real extension:

1. User presses `<leader>ac` in Neovim
2. Lua picker shows core in available extensions list
3. User selects core, `manager.load("core", {confirm=true})` called (`init.lua:206`)
4. `manifest_mod.get_extension("core", config)` finds `extensions/core/manifest.json` (`init.lua:230`)
5. `state_mod.is_loaded(state, "core")` returns false (`init.lua:239`)
6. No dependencies to resolve (`deps = []` for core, `init.lua:265-293`)
7. `loader_mod.check_conflicts()` checks if `.claude/agents/`, `.claude/skills/`, etc. exist
8. User confirms (or auto-confirms with `force=true`)
9. `helpers.ensure_directory(target_dir)` creates `.claude/` if needed (`init.lua:355`)
10. `loader_mod.copy_simple_files()` copies agents, commands, rules, scripts (`init.lua:385-401`)
11. `loader_mod.copy_skill_dirs()` copies skill directories (`init.lua:403-406`)
12. `loader_mod.copy_context_dirs()` copies context tree (`init.lua:408-411`)
13. `loader_mod.copy_scripts()` copies scripts (`init.lua:413-416`)
14. `process_merge_targets()` runs merge targets (EXTENSION.md injection, settings, index)
15. `state_mod.mark_loaded()` writes to `extensions.json`
16. Verification runs

**No step in this path requires files to already be in `.claude/` to function**. The Lua
loader operates purely on source files in `extensions/core/` and target paths in `.claude/`.
The bootstrap concern from task 464 was specific to a scenario where core FILES bootstrap the
LOADER — that is not the case here.

**Remaining caveat**: Claude Code reads `settings.json` (always present) which references hooks
that only exist AFTER step 10. The `|| echo '{}'` safety net ensures Claude Code starts
regardless, but hooks are non-functional until core is loaded. This is documented as "expected
behavior: load core first, then start Claude Code session."

---

## Edge Cases and Failure Modes

### 1. Partial Load (Crash Mid-Copy)

The load is wrapped in `pcall` (`init.lua:383`). On failure, `loader_mod.remove_installed_files()`
removes all partially-copied files. Since core is the BASE of `.claude/`, a partial core load
means some categories are populated and others are empty.

**Risk**: Claude Code is running concurrently and reading `.claude/` while the loader is
copying. Reading a partially-populated `.claude/` gives inconsistent context. Mitigation:
advise users to load core before starting Claude Code sessions, not during.

### 2. Unloading Core While Other Extensions Are Loaded

`manager.unload()` checks for dependents (`init.lua:551-563`) and shows a WARNING but does
not BLOCK unload. All 15 non-core extensions declare `"dependencies": ["core"]`. If user
unloads core while nvim/lean/memory are loaded:
- Warning shown: "WARNING: Extension 'core' is required by: nvim, lean, memory, ..."
- User can proceed anyway
- Result: ~208 files deleted from `.claude/`, all dependent extensions broken
- Claude Code: reads minimal CLAUDE.md shell, no agents/commands/skills visible

**Risk level**: HIGH for accidental unload. The warning exists but is overridable.
**Recommendation**: Consider blocking (not just warning) unload when dependents are active.

### 3. extensions.json State After Unload

When core is unloaded, `state_mod.mark_unloaded()` removes core from `extensions.json`.
All dependent extensions (nvim, lean, etc.) remain listed as "active" in `extensions.json`
even though their actual files are intact. Core's files are gone but dependents' files remain
(extension files are tracked and removed separately per extension).

Result: `extensions.json` reports nvim as "active" but core as absent. Next load of any
extension correctly checks `state_mod.is_loaded(state, "core")` which returns false, so
core would be auto-loaded. This is correct behavior.

### 4. Race Between Claude Code Reading .claude/ and Loader Writing

Claude Code does not hold file locks on `.claude/` files. The loader writes files one at a
time using `io.open(filepath, "w")`. If Claude Code reads a file being written mid-operation,
it gets partial content. This is inherent to the architecture and not specific to this change.
The `|| echo '{}'` patterns mitigate catastrophic failures.

### 5. User Uses Claude Code Before Loading Any Extensions (First Setup)

New repo scenario: user clones a repo, sync installs core files in `.claude/`, but
`extensions.json` doesn't exist yet (or records no extensions). User opens Claude Code:
- `settings.json` is present (synced), hooks fail silently
- `CLAUDE.md` shell is present (synced from `.claude/CLAUDE.md` in source repo)
- No task management docs visible (not in shell CLAUDE.md)
- User is confused: commands like `/research` and `/plan` are "not found"

This is a WORSE user experience than today where all files are unconditionally present after
sync. The task must define what "first time setup" looks like for new repos.

---

## Files That Must Remain in .claude/

Based on code analysis:

| File | Reason Must Stay | What Happens If Absent |
|------|-----------------|------------------------|
| `CLAUDE.md` | Claude Code protocol requirement; reads it as project instructions | Claude Code has no project context |
| `settings.json` | Claude Code reads for permissions and hooks | All tool permissions and hooks disabled |
| `extensions.json` | Extension loader state tracking (`state.lua:71`) | Loader treats all extensions as inactive |
| `extensions/` directory | Contains all extension source manifests and files | No extensions available to load |
| `context/index.json` | Agents query this for context discovery | Context discovery fails |

Additional files that should stay for first-session functionality (not strictly required by
protocol, but expected by users):

| File | Status | Notes |
|------|--------|-------|
| `context/core-index-entries.json` | AMBIGUOUS per task | If it stays, it's a permanent resident outside extension model |
| `README.md` | Low risk to stay | Not protocol-required |
| `settings.local.json` | May contain extension-merged keys | Should stay, generated |

The task description includes `context/core-index-entries.json` in the "files that stay" list.
This is correct functionally but creates a conceptual inconsistency: it's core content that
doesn't follow the extension lifecycle. Accepting this inconsistency is fine as a pragmatic
compromise.

---

## Unresolved Risks

### Risk 1: Sync System Requires Non-Trivial Update (HIGH)

The sync system must be updated to source core files from `extensions/core/` not `.claude/`.
This is acknowledged in the task but the scope is underspecified. It affects `scan_all_artifacts()`
which has ~15 category scan calls. The clean implementation requires either:
- Changing the `global_dir` parameter to `extensions/core/` when building source paths, OR
- Adding a conditional branch to check manifest virtual flag and switch source directory

Without this change, "Load Core Agent System" is broken after the physical move.

### Risk 2: Migration Strategy for Existing Repos Is Undefined (HIGH)

Three repos (dotfiles, zed config, Philosophy/Papers) have core files present but core not
tracked in `extensions.json`. After the physical move:
- These repos continue working normally (files are still present)
- If they run "Load Core Agent System", they get updated files (sync from `extensions/core/`)
- If they try to load core via picker, they get 208 conflict warnings

A migration guide or automated migration script is needed. Alternatively, the loader's
conflict-detection could be made smarter: if all conflicts are identical to extension source
files, silently adopt them rather than prompting.

### Risk 3: Hooks Work Only After Core Load (MEDIUM)

Settings.json always references `.claude/hooks/*.sh`. In any repo, if core hasn't been loaded,
all hook commands fail silently. This affects the source repo itself during development
(e.g., if user unloads core to test, hooks break). Users may not understand why hooks stopped
working after unloading core.

### Risk 4: utils/ Category Not Defined in Extension Model (MEDIUM)

Three team skills reference `.claude/utils/team-wave-helpers.md` at hardcoded paths. This path
is not provided by any extension and not synced. The physical move forces a decision: add
`utils` as a new category in the extension model, or change the skill files to reference a
different location. Either requires updates beyond the core manifest.

### Risk 5: Large Migration Is Hard to Test Comprehensively (MEDIUM)

~208 files moving changes the source structure. Testing requires:
- Verifying all 208 files copy correctly during `manager.load("core")`
- Verifying rollback works if copy fails mid-way
- Verifying sync finds and syncs from new source path
- Verifying all 3 existing repos work after migration
- Verifying all 15 dependent extensions load after core
- Verifying unload correctly removes all 208 files

The existing test suite (`tests/` dir) has 0 test files, making automated regression testing
impossible. This is a pre-existing gap but it makes the migration riskier.

---

## Confidence Level

**Confidence: HIGH**

All findings are grounded in specific code paths, file system observations, and precise
file counts:

- Bootstrap analysis: traced via `init.lua:206-498` (complete load path)
- Sync breakage: `sync.lua:694` (`scan_all_artifacts`), line 793 (`artifacts.hooks = sync_scan("hooks", ...)`)
- Extensions.json path: `state.lua:71` (`project_dir + "/" + config.base_dir + "/" + config.state_file`)
- Existing repos inspection: direct reading of `~/.dotfiles`, `~/.config/zed`, `~/Philosophy/Papers/PossibleWorlds` extensions.json
- File counts: direct `find` commands on filesystem
- settings.json hooks: direct grep on settings.json content
- Dependent extensions: inspected all 16 manifests in `extensions/*/manifest.json`
- utils/ gap: grep of skills/ against actual utils/ contents
