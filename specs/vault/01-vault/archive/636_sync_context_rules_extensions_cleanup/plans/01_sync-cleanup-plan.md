# Implementation Plan: Task #636

- **Task**: 636 - sync_context_rules_extensions_cleanup
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Tasks 633, 634, 635 (completed)
- **Research Inputs**: specs/636_sync_context_rules_extensions_cleanup/reports/01_sync-audit.md
- **Artifacts**: plans/01_sync-cleanup-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Synchronize remaining stale and missing components from `.claude/` to `.opencode/` in the Neovim config repo. This covers ~96 stale context files, 12 missing files across extensions and patterns, 3 missing hook scripts with manifest updates, deletion of 1 stale file, and a settings.json backport. The approach uses scripted bulk operations with path-prefix substitution (`.claude/` to `.opencode/`) for context files, careful `jq` merge for `index.json`, and targeted edits for manifests and settings.

### Research Integration

Key findings from the sync audit report (01_sync-audit.md):
- 74+ stale context files identified (actual count ~96 when including schema/JSON files)
- 12 missing files: 7 nvim extension context, 2 memory extension context, 2 pattern files, plus `index.json` entries
- Extension hooks missing from nvim and nix manifests in `.opencode/`
- `.opencode/settings.json` has improvements to backport to `.claude/settings.json`
- Rules (`neovim-lua.md`, `nix.md`) correctly live only in extension directories in `.opencode/` -- no action needed
- Scripts sync is out of scope (deferred to separate task per research recommendation)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Overwrite all stale context files in `.opencode/context/` from `.claude/context/` with path-prefix substitution
- Merge `index.json` carefully, preserving `.opencode/`-specific entries while updating shared entries
- Copy 12 missing files to their correct `.opencode/` locations
- Add hook scripts and update nvim/nix extension manifests in `.opencode/`
- Delete stale `.opencode/context/workflows/status-transitions.md`
- Backport settings.json improvements from `.opencode/` to `.claude/`

**Non-Goals**:
- Script synchronization (13 differing scripts -- requires individual review, separate task)
- Epidemiology/filetypes/formal/lean extension context gaps (intentional redesigns)
- Modifying `.claude/` context files (`.claude/` is source of truth)
- Top-level rules duplication in `.opencode/rules/` (extension directories are correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `index.json` merge loses `.opencode/`-specific entries | H | M | Use `jq` merge that preserves entries by path key; verify entry count before and after |
| Hook scripts contain `.claude/` path references | M | H | Run `grep -r '.claude' ` on copied scripts and substitute to `.opencode/` |
| Path-prefix substitution is too aggressive (catches comments, URLs) | M | L | Use `sed` with word-boundary awareness: `s|\.claude/|.opencode/|g` only in file references |
| Stale file count changes between research and implementation | L | M | Use dynamic `find` + `stat` comparison instead of hard-coded file list |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Delete Stale File and Pre-Sync Verification [COMPLETED]

**Goal**: Remove the confirmed stale file and establish baseline metrics for verification.

**Tasks**:
- [ ] Verify `.opencode/context/workflows/status-transitions.md` is not referenced elsewhere: `grep -r 'status-transitions' .opencode/` (exclude the file itself)
- [ ] Delete `.opencode/context/workflows/status-transitions.md`
- [ ] Record baseline file counts for verification:
  - Count of files in `.opencode/context/` (total)
  - Count of files in `.opencode/extensions/nvim/context/`
  - Count of files in `.opencode/extensions/memory/context/`
  - Count of files in `.opencode/extensions/nix/scripts/`
- [ ] Verify `.opencode/extensions/nvim/scripts/` directory exists (create if needed)
- [ ] Verify `.opencode/extensions/nix/scripts/` directory exists (create if needed)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/context/workflows/status-transitions.md` - DELETE

**Verification**:
- `status-transitions.md` no longer exists at `.opencode/context/workflows/`
- Baseline counts recorded for post-sync comparison
- Script directories exist for both nvim and nix extensions

---

### Phase 2: Bulk Sync Stale Context Files [COMPLETED]

**Goal**: Overwrite all stale context files in `.opencode/context/` from `.claude/context/` with path-prefix substitution, excluding `index.json` (handled in Phase 3).

**Tasks**:
- [ ] Write a sync script that:
  1. Iterates all files in `.claude/context/` (md and json, excluding `index.json`)
  2. For each file that also exists in `.opencode/context/` AND `.claude/` version is newer
  3. Copies `.claude/context/{path}` to `.opencode/context/{path}`
  4. Runs `sed -i 's|\.claude/|.opencode/|g'` on the copied file
  5. Logs each file synced
- [ ] Execute the sync script
- [ ] Spot-check 5 synced files to confirm:
  - Content matches `.claude/` version (modulo path substitution)
  - No remaining `.claude/` path references in synced files
  - File is syntactically valid (no broken markdown)

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- ~96 files under `.opencode/context/` - OVERWRITE with path-substituted content from `.claude/context/`

**Verification**:
- `grep -r '\.claude/' .opencode/context/ --include='*.md'` returns zero matches (excluding any intentional cross-references)
- File count in `.opencode/context/` is unchanged (overwrites, not additions)

---

### Phase 3: Copy Missing Files [COMPLETED]

**Goal**: Add the 12 missing files to their correct locations in `.opencode/`.

**Tasks**:
- [ ] Copy 7 missing nvim extension context files from `.claude/extensions/nvim/context/` to `.opencode/extensions/nvim/context/`:
  - `project/neovim/guides/neovim-integration.md`
  - `project/neovim/guides/tts-stt-integration.md`
  - `project/neovim/hooks/wezterm-integration.md`
  - `project/neovim/standards/box-drawing-guide.md`
  - `project/neovim/standards/documentation-policy.md`
  - `project/neovim/standards/emoji-policy.md`
  - `project/neovim/standards/lua-assertion-patterns.md`
- [ ] Create necessary subdirectories under `.opencode/extensions/nvim/context/` (`guides/`, `hooks/`, `standards/`)
- [ ] Run path-prefix substitution on copied nvim files: `sed -i 's|\.claude/|.opencode/|g'`
- [ ] Copy 2 missing memory extension context files from `.claude/extensions/memory/context/` to `.opencode/extensions/memory/context/`:
  - `project/memory/distill-usage.md`
  - `project/memory/domain/memory-reference.md`
- [ ] Create necessary subdirectories under `.opencode/extensions/memory/context/`
- [ ] Run path-prefix substitution on copied memory files
- [ ] Copy 2 missing pattern files from `.claude/context/patterns/` to `.opencode/context/patterns/`:
  - `context-protective-lead.md`
  - `fork-patterns.md`
- [ ] Run path-prefix substitution on copied pattern files
- [ ] Verify all 12 files exist in their target locations: `ls -la` each path

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/standards/documentation-policy.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/standards/emoji-policy.md` - CREATE
- `.opencode/extensions/nvim/context/project/neovim/standards/lua-assertion-patterns.md` - CREATE
- `.opencode/extensions/memory/context/project/memory/distill-usage.md` - CREATE
- `.opencode/extensions/memory/context/project/memory/domain/memory-reference.md` - CREATE
- `.opencode/context/patterns/context-protective-lead.md` - CREATE
- `.opencode/context/patterns/fork-patterns.md` - CREATE

**Verification**:
- All 12 files exist at target paths
- `grep -r '\.claude/' ` on each file returns zero matches

---

### Phase 4: Extension Hooks -- Scripts and Manifests [COMPLETED]

**Goal**: Copy missing hook scripts to `.opencode/` extensions and update manifests to reference them.

**Tasks**:
- [ ] Copy `.claude/extensions/nvim/scripts/nvim-context.sh` to `.opencode/extensions/nvim/scripts/nvim-context.sh`
- [ ] Run path-prefix substitution on copied nvim script: `sed -i 's|\.claude/|.opencode/|g'`
- [ ] Make script executable: `chmod +x .opencode/extensions/nvim/scripts/nvim-context.sh`
- [ ] Copy `.claude/extensions/nix/scripts/nix-context.sh` to `.opencode/extensions/nix/scripts/nix-context.sh`
- [ ] Copy `.claude/extensions/nix/scripts/nix-preflight.sh` to `.opencode/extensions/nix/scripts/nix-preflight.sh`
- [ ] Run path-prefix substitution on copied nix scripts
- [ ] Make nix scripts executable: `chmod +x .opencode/extensions/nix/scripts/nix-*.sh`
- [ ] Verify no remaining `.claude/` references in copied scripts: `grep -r '\.claude/' .opencode/extensions/nvim/scripts/ .opencode/extensions/nix/scripts/`
- [ ] Update `.opencode/extensions/nvim/manifest.json`: add `"hooks": {"context_injection": "scripts/nvim-context.sh"}` (currently missing or empty)
- [ ] Update `.opencode/extensions/nix/manifest.json`: add `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}` (currently missing or empty)
- [ ] Also add `"plan"` routing entry to `.opencode/extensions/nvim/manifest.json` (missing in `.opencode/`, present in `.claude/`): `"plan": {"neovim": "skill-planner"}`
- [ ] Also add `"plan"` routing entry to `.opencode/extensions/nix/manifest.json` (missing in `.opencode/`, present in `.claude/`): `"plan": {"nix": "skill-planner"}`

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/extensions/nvim/scripts/nvim-context.sh` - CREATE
- `.opencode/extensions/nix/scripts/nix-context.sh` - CREATE
- `.opencode/extensions/nix/scripts/nix-preflight.sh` - CREATE
- `.opencode/extensions/nvim/manifest.json` - EDIT (add hooks, add plan routing)
- `.opencode/extensions/nix/manifest.json` - EDIT (add hooks, add plan routing)

**Verification**:
- All 3 scripts exist and are executable
- `jq '.hooks' .opencode/extensions/nvim/manifest.json` returns `{"context_injection": "scripts/nvim-context.sh"}`
- `jq '.hooks' .opencode/extensions/nix/manifest.json` returns `{"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`
- `jq '.routing.plan' .opencode/extensions/nvim/manifest.json` returns `{"neovim": "skill-planner"}`
- `jq '.routing.plan' .opencode/extensions/nix/manifest.json` returns `{"nix": "skill-planner"}`
- No `.claude/` path references in any copied script

---

### Phase 5: Merge index.json [COMPLETED]

**Goal**: Carefully merge `.claude/context/index.json` into `.opencode/context/index.json`, preserving `.opencode/`-specific entries while updating shared entries with newer content from `.claude/`.

**Tasks**:
- [ ] Record pre-merge metrics:
  - `.opencode/context/index.json` entry count
  - `.claude/context/index.json` entry count
  - Count of `.opencode/`-specific entries (paths starting with `core/` or `README.md`)
- [ ] Create a backup: `cp .opencode/context/index.json .opencode/context/index.json.bak`
- [ ] Write a `jq` merge script that:
  1. Reads `.claude/context/index.json` as source
  2. Reads `.opencode/context/index.json` as target
  3. For each entry in source: apply `.claude/` to `.opencode/` path substitution on all string values
  4. For entries whose `.path` exists in both: replace with the updated source entry
  5. For entries in source but not in target: add them (new entries from `.claude/`)
  6. For entries only in target (`.opencode/`-specific): preserve them unchanged
  7. Also add index entries for the 12 newly-copied files from Phase 3 (if not already present in either source)
- [ ] Execute the merge
- [ ] Verify post-merge metrics:
  - Entry count >= original `.opencode/` count (should be equal or greater, never less)
  - All `.opencode/`-specific entries still present
  - No `.claude/` path references remain in any entry
- [ ] Remove backup file after verification: `rm .opencode/context/index.json.bak`

**Timing**: 45 minutes

**Depends on**: 2, 3, 4

**Files to modify**:
- `.opencode/context/index.json` - MERGE (complex update)

**Verification**:
- `jq '.entries | length' .opencode/context/index.json` >= pre-merge count
- `jq '[.entries[] | select(.path | startswith("core/"))] | length' .opencode/context/index.json` equals pre-merge `.opencode/`-specific count
- `jq -r '.entries[].path' .opencode/context/index.json | grep '\.claude/'` returns zero matches
- JSON is valid: `jq . .opencode/context/index.json > /dev/null`

---

### Phase 6: Settings.json Backport and Final Verification [COMPLETED]

**Goal**: Backport improvements from `.opencode/settings.json` to `.claude/settings.json` and run final cross-system verification.

**Tasks**:
- [ ] Add missing permissions to `.claude/settings.json` allow list:
  - `"Bash(nvim *)"` (for headless Neovim operations)
  - `"Bash(luac *)"` (Lua compiler)
  - `"Bash(pnpm *)"` (Node package manager)
  - `"Bash(npx *)"` (Node package runner)
- [ ] Add timeout values to hook entries in `.claude/settings.json`:
  - `SessionStart` wezterm hook: add `"timeout": 5000`
  - `SessionStart` claude-ready-signal hook: add `"timeout": 5000`
  - `Stop` claude-stop-notify hook: add `"timeout": 5000`
  - `UserPromptSubmit` hooks: add `"timeout": 5000` to each
  - `Notification` tts-notify hook: add `"timeout": 10000`
- [ ] Fix state.json path check precision in `.claude/settings.json`:
  - Change `*"state.json"*` to `*"specs/state.json"*` in PreToolUse Write hook
- [ ] Update `.claude/settings.json` claude-ready-signal path to use absolute path: `bash ~/.config/nvim/scripts/claude-ready-signal.sh`
- [ ] Validate both settings files are valid JSON: `jq . .claude/settings.json && jq . .opencode/settings.json`
- [ ] Run final verification across both systems:
  - No stale context files remain (`.claude/` newer than `.opencode/` by more than research report date)
  - All 12 missing files now exist
  - Hook scripts exist and are executable
  - Manifests have hooks and plan routing entries
  - `status-transitions.md` is deleted from `.opencode/context/workflows/`
  - `index.json` entry count is valid

**Timing**: 30 minutes

**Depends on**: 5

**Files to modify**:
- `.claude/settings.json` - EDIT (add permissions, timeouts, path fixes)

**Verification**:
- `.claude/settings.json` is valid JSON
- `jq '.permissions.allow' .claude/settings.json` includes `Bash(nvim *)`, `Bash(luac *)`, `Bash(pnpm *)`, `Bash(npx *)`
- Hook entries in `.claude/settings.json` have timeout values
- PreToolUse hook uses `*"specs/state.json"*` check
- Full cross-system diff shows only expected differences (system-specific paths, `task_type` vs `language`, etc.)

## Testing & Validation

- [ ] `grep -r '\.claude/' .opencode/context/ --include='*.md' | grep -v 'cross-reference'` returns zero matches (no stale `.claude/` refs in synced context)
- [ ] `ls .opencode/context/workflows/status-transitions.md` returns "No such file"
- [ ] All 12 newly-added files exist and have correct content
- [ ] `jq . .opencode/context/index.json > /dev/null` succeeds (valid JSON)
- [ ] `jq . .claude/settings.json > /dev/null` succeeds (valid JSON)
- [ ] Hook scripts are executable: `test -x .opencode/extensions/nvim/scripts/nvim-context.sh`
- [ ] Manifests have correct hook and routing entries (verified via `jq`)

## Artifacts & Outputs

- `specs/636_sync_context_rules_extensions_cleanup/plans/01_sync-cleanup-plan.md` (this file)
- `specs/636_sync_context_rules_extensions_cleanup/summaries/01_sync-cleanup-summary.md` (after implementation)

## Rollback/Contingency

- **Context files**: `git checkout .opencode/context/` to restore pre-sync state
- **index.json**: Backup created in Phase 5 (`index.json.bak`); also recoverable via `git checkout .opencode/context/index.json`
- **Manifest changes**: `git checkout .opencode/extensions/nvim/manifest.json .opencode/extensions/nix/manifest.json`
- **Settings.json**: `git checkout .claude/settings.json`
- **New files**: `git clean -fd .opencode/extensions/nvim/context/ .opencode/extensions/memory/context/ .opencode/extensions/nvim/scripts/ .opencode/extensions/nix/scripts/` to remove added files
- All changes are reversible via git since they modify tracked directories
