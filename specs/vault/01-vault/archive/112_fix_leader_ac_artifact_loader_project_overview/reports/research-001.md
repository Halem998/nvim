# Research Report: Task #112

**Task**: 112 - fix_leader_ac_artifact_loader_project_overview
**Started**: 2026-03-02
**Completed**: 2026-03-02
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Local codebase analysis, Claude Code documentation
**Artifacts**: - specs/112_fix_leader_ac_artifact_loader_project_overview/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The `<leader>ac` "Load All Artifacts" feature has no exclusion mechanism -- it syncs ALL files from the global `.claude/context/` directory including `project-overview.md`, which is a per-project file
- Adding an exclusion list to `scan_directory_for_sync()` in `scan.lua` is the correct fix
- Both `CLAUDE.md` (project root) and `.claude/CLAUDE.md` serve the same purpose in Claude Code; having both causes duplication -- only `.claude/CLAUDE.md` should be included in the sync

## Context & Scope

The user reported that `<leader>ac` "Load All" still loads `project-overview.md` when syncing artifacts from the global directory to a local project. Since `project-overview.md` describes the Neovim configuration project specifically, it should NOT be copied to other projects. Additionally, the task asks to clarify the relationship between `.claude/CLAUDE.md` and root `CLAUDE.md`.

### Architecture of `<leader>ac`

The keybinding chain is:
1. `<leader>ac` (normal mode) -> `<cmd>ClaudeCommands<CR>` (defined in `which-key.lua:242`)
2. `ClaudeCommands` user command -> `commands_picker.show_commands_picker()` (defined in `init.lua:146`)
3. The picker delegates to `picker/init.lua` which displays a Telescope picker
4. The "[Load All Artifacts]" entry triggers `sync.load_all_globally()` (line 88 of `picker/init.lua`)

### Sync Flow

`sync.load_all_globally()` in `sync.lua`:
1. Gets `global_dir` (defaults to `~/.config/nvim`) and `project_dir` (current working directory)
2. Calls `scan_all_artifacts(global_dir, project_dir)` which scans every artifact category
3. For the `context` category (lines 163-171), it scans ALL `.md`, `.json`, and `.yaml` files recursively under `.claude/context/`
4. Presents a confirmation dialog and copies files

## Findings

### Root Cause: No File Exclusion in scan_directory_for_sync

The `scan_directory_for_sync()` function in `scan.lua` (lines 51-103) has NO file exclusion logic. It processes every file matching the extension pattern. The only exclusion in the entire scan module is in `scan_directory()` (line 29-31) which filters out `README.md` for the picker display, but `scan_directory_for_sync()` (used by Load All) does NOT call `scan_directory()` -- it uses `vim.fn.glob()` directly.

**Affected file**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
**Affected function**: `scan_directory_for_sync()` (line 51)

### Files That Should Be Excluded from Sync

The following files in `.claude/context/project/repo/` are repository-specific:

| File | Reason to exclude |
|------|-------------------|
| `project-overview.md` | Describes the specific repository (Neovim config); other projects need their own generated via `update-project.md` |
| `self-healing-implementation-details.md` | Implementation details specific to this repository's self-healing feature |

The `update-project.md` file is actually a **guide/template** for generating `project-overview.md`, so it SHOULD be synced. It tells agents how to create a project-appropriate overview when copied to a new repo.

### CLAUDE.md File Relationship Analysis

The project has three CLAUDE.md files:

| Path | Size | Purpose |
|------|------|---------|
| `/home/benjamin/.config/CLAUDE.md` | 27,845 bytes | Parent directory CLAUDE.md (loaded by directory walk-up; this is for the .config directory as a whole) |
| `/home/benjamin/.config/nvim/CLAUDE.md` | 9,159 bytes | Project root CLAUDE.md -- Neovim configuration guidelines, code standards, testing |
| `/home/benjamin/.config/nvim/.claude/CLAUDE.md` | 9,474 bytes | Agent system CLAUDE.md -- task management, command reference, state sync |

#### How Claude Code Discovers These Files

Per the official Claude Code documentation:

> "CLAUDE.md files can live at `./CLAUDE.md` or `./.claude/CLAUDE.md`" -- these are **alternative locations for the same purpose**: team-shared project instructions.

> "Claude Code reads CLAUDE.md files by walking up the directory tree from your current working directory"

This means when working in `/home/benjamin/.config/nvim/`:
1. `/home/benjamin/.config/nvim/CLAUDE.md` -- loaded (project root)
2. `/home/benjamin/.config/nvim/.claude/CLAUDE.md` -- loaded (.claude variant)
3. `/home/benjamin/.config/CLAUDE.md` -- loaded (parent directory walk-up)

**All three are loaded into every session.** The root `CLAUDE.md` (nvim/CLAUDE.md) focuses on coding standards, while `.claude/CLAUDE.md` focuses on the agent/task system. They serve complementary roles but are technically redundant locations for "project instructions."

#### Which Should Be Synced to Other Projects?

For the "Load All" sync operation:
- `.claude/CLAUDE.md` -- YES, should be synced. Contains the agent system reference that other projects need.
- Root `CLAUDE.md` (project root) -- SHOULD NOT be synced. Contains Neovim-specific coding standards (Lua style, plugin patterns, etc.) that are irrelevant to non-Neovim projects.

Currently, `sync.lua` lines 199-227 sync BOTH:
- Line 199: `root_file_names` includes `"CLAUDE.md"` (this is `.claude/CLAUDE.md`)
- Lines 216-227: Also syncs `project_dir .. "/CLAUDE.md"` (root-level CLAUDE.md)

### Recommendations

#### Fix 1: Add exclusion list to scan_directory_for_sync

Add a file exclusion mechanism to `scan_directory_for_sync()` or `scan_all_artifacts()`. Two approaches:

**Option A: Exclusion list parameter**
Add an optional `exclude_patterns` parameter to `scan_directory_for_sync()` that filters files by relative path pattern.

**Option B: Per-category exclusion in scan_all_artifacts**
Add exclusion logic in the `scan_all_artifacts()` function specifically for the `context` category, filtering out `project/repo/project-overview.md` and `project/repo/self-healing-implementation-details.md`.

**Recommended: Option A** -- more general-purpose, can be reused for other exclusion needs.

#### Fix 2: Exclude root CLAUDE.md from sync

In `scan_all_artifacts()` (lines 216-227), the root-level `CLAUDE.md` should be excluded from sync or made optional. The project root `CLAUDE.md` in this repo contains Neovim-specific guidelines that should not be copied to other projects.

Options:
- Remove lines 216-227 entirely (stop syncing root CLAUDE.md)
- Add a confirmation/skip prompt for root CLAUDE.md

**Recommended**: Remove root CLAUDE.md from automatic sync. Each project should maintain its own root CLAUDE.md with project-specific guidelines.

#### Fix 3: Consider merging or deduplicating CLAUDE.md files

The content overlap between `CLAUDE.md` and `.claude/CLAUDE.md` is minimal -- they serve different purposes (coding standards vs. agent system). However, both are loaded into every session consuming context tokens. Options:
- Keep both (current): Clear separation of concerns, but 18+ KB of instructions loaded per session
- Merge into `.claude/CLAUDE.md` only: Simpler, single source of truth, but mixing concerns
- Keep both but trim: Reduce each to essential content only

**Recommended**: Keep both files but clarify their distinct roles. Root `CLAUDE.md` for project coding standards that apply regardless of the agent system. `.claude/CLAUDE.md` for the agent/task management system that gets synced across projects.

### Implementation Location Summary

| File | Line(s) | Change |
|------|---------|--------|
| `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` | 51-103 | Add `exclude_patterns` parameter to `scan_directory_for_sync()` |
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | 149-229 | Pass exclusion patterns when scanning context artifacts |
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | 216-227 | Remove or guard root CLAUDE.md sync |
| `lua/neotex/plugins/ai/claude/commands/picker/utils/scan_spec.lua` | New tests | Add test cases for exclusion patterns |

## Decisions

- `project-overview.md` should be excluded because it is explicitly designed to be regenerated per-project (as documented in `update-project.md`)
- `self-healing-implementation-details.md` should also be excluded as it describes implementation details specific to this repository
- `update-project.md` should NOT be excluded -- it is the template/guide for generating project-specific overviews
- Root `CLAUDE.md` should not be included in the "Load All" sync because it contains Neovim-specific coding standards

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Exclusion list becomes stale as new repo-specific files are added | Low -- new files added rarely | Document the exclusion convention; consider using a `.syncignore` pattern |
| Users may expect root CLAUDE.md to sync | Medium -- users accustomed to current behavior | Show notification when root CLAUDE.md is skipped |
| Breaking change for projects already using synced project-overview.md | Low -- project-overview.md should be regenerated anyway | No migration needed; existing copies remain unchanged |

## Context Extension Recommendations

- **Topic**: Context sync exclusion patterns
- **Gap**: No documentation exists about which context files are project-specific vs. portable
- **Recommendation**: Add a section to `.claude/context/README.md` documenting which files under `project/repo/` are project-specific and should not be synced

## Appendix

### Search Queries Used
- Local: Grep for `leader.*ac`, `ClaudeCommands`, `project-overview`, `EXCLUDE|exclude|skip`
- Local: Glob for picker module files
- Web: "Claude Code CLAUDE.md file discovery hierarchy"
- Web: Claude Code official documentation at code.claude.com/docs/en/memory

### Key File Paths
- Keybinding: `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` (line 242)
- Picker init: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua`
- Sync module: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Scan module: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- Registry: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/artifacts/registry.lua`
- Entries: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
- Project overview: `/home/benjamin/.config/nvim/.claude/context/project/repo/project-overview.md`
- Update project guide: `/home/benjamin/.config/nvim/.claude/context/project/repo/update-project.md`

### References
- [Claude Code Memory Documentation](https://code.claude.com/docs/en/memory)
- [Using CLAUDE.MD files blog post](https://claude.com/blog/using-claude-md-files)
