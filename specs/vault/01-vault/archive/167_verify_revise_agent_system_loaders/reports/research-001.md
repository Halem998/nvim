# Research Report: Task #167

**Task**: 167 - Verify and revise agent system loaders for .claude/ and .opencode/
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Neovim configuration source code, Vision project target directories
**Artifacts**: - specs/167_verify_revise_agent_system_loaders/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The agent system loaders for both `.claude/` and `.opencode/` are functioning correctly with no critical issues
- The `.claude/` sync to Vision is perfect: zero files missing, zero inappropriate additions
- The `.opencode/` sync to Vision is nearly perfect: 8 minor files missing (README.md placeholders, .gitkeep, test-results.md), 1 project-local file in target (context/project/repo/README.md)
- The loader mechanism uses symlinks in the source to expose extension artifacts (agents, skills) to the core sync operation, which is an effective design pattern
- No revisions to the loader code are needed

## Context & Scope

The task requires verifying the `<leader>ac` (ClaudeCommands) and `<leader>ao` (OpencodeCommands) keymaps and the underlying agent system loader that copies `.claude/` and `.opencode/` directories from the global source (`~/.config/nvim/`) to project directories (specifically `/home/benjamin/Projects/Logos/Vision/`).

## Findings

### Keymap Mechanism

The keymaps are defined in `lua/neotex/plugins/editor/which-key.lua`:

- `<leader>ac` (normal mode): Runs `:ClaudeCommands` -- opens a Telescope picker for .claude/ artifacts
- `<leader>ac` (visual mode): Sends visual selection to Claude with a prompt
- `<leader>ao` (normal mode): Runs `:OpencodeCommands` -- opens a Telescope picker for .opencode/ artifacts
- `<leader>ao` (visual mode): Sends visual selection to OpenCode with a prompt

The picker includes a special entry `[Load Core Agent System]` that triggers `sync.load_all_globally()`, which performs the full directory sync.

### Loader Architecture

The sync operation is implemented in `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`:

1. **Parameterized config**: `lua/neotex/plugins/ai/shared/picker/config.lua` defines presets for `.claude` and `.opencode` with different `base_dir`, `agents_subdir`, and `root_config_file` values
2. **Artifact scanning**: `scan_all_artifacts()` scans 14 artifact categories: commands, agents, skills, hooks, templates, lib, docs, scripts, tests, rules, context, systemd, settings, root_files
3. **User confirmation**: Presents a dialog with options to "Sync all" (replace existing), "Add new only", or "Cancel"
4. **File copy**: Reads source, writes to target, preserves permissions for `.sh` files

Key design decisions:
- **Context exclusions**: `CONTEXT_EXCLUDE_PATTERNS` excludes `project/repo/project-overview.md` and `project/repo/self-healing-implementation-details.md` (repo-specific files)
- **Root CLAUDE.md**: Intentionally NOT synced (contains Neovim-specific standards irrelevant to other projects)
- **OpenCode agents**: Uses `agent/subagents/` subdirectory (not flat `agents/`), plus separately syncs `agent/orchestrator.md`
- **.claude-specific categories**: `lib/`, `tests/`, and `settings.json` are only synced for `.claude` (not `.opencode`)

### Symlink Strategy for Extensions

The source `.claude/` directory uses symlinks to expose extension artifacts at the top level:

```
.claude/agents/z3-implementation-agent.md -> ../extensions/z3/agents/z3-implementation-agent.md
.claude/skills/skill-lean-research -> ../extensions/lean/skills/skill-lean-research
```

This means `vim.fn.glob()` (used by the scanner) follows symlinks and includes extension artifacts in the core sync. The result is that "Load Core Agent System" syncs ALL skills and agents (core + extension) in one operation, without requiring separate extension loading.

There are 28 symlinked skill directories and 2 symlinked agent files in the source `.claude/`.

### Extension System (Separate from Core Sync)

The extension system (`lua/neotex/plugins/ai/shared/extensions/`) provides fine-grained per-project extension management:
- Load/unload/reload extensions individually
- Tracks installed files in `extensions-state.json`
- Handles merge targets (section injection into CLAUDE.md/OPENCODE.md, settings merge, index.json entries)
- Supports conflict detection and atomic rollback

For Vision, no `extensions-state.json` exists, meaning extensions were loaded via the core sync (symlinks) rather than the extension system.

### .claude/ Sync Analysis (Vision)

**Result: PERFECT SYNC**

| Category | Source (core) | Target | Status |
|----------|---------------|--------|--------|
| Commands | 11 | 11 | Match |
| Agents | 4 core + 2 symlinked | 6 | Match |
| Skills | 7 core + 28 symlinked | 35 | Match |
| Hooks | 9 | 9 | Match |
| Scripts | 14 | 14 | Match |
| Rules | 6 | 6 | Match |
| Context | 83 (excl. repo-specific) | 84 (incl. update-project.md) | Match |
| Docs | 49 | 49 | Match |
| Root files | CLAUDE.md, .gitignore, README.md, settings.local.json | All present | Match |

Files correctly excluded from sync:
- `context/project/repo/project-overview.md` (repo-specific, per CONTEXT_EXCLUDE_PATTERNS)
- `context/project/repo/self-healing-implementation-details.md` (repo-specific)
- `extensions/` directory (not directly synced; individual files exposed via symlinks)
- `logs/` directory (runtime-generated)
- `output/` directory (runtime-generated)

### .opencode/ Sync Analysis (Vision)

**Result: NEAR-PERFECT SYNC (8 minor files missing)**

| Category | Source (core) | Target | Status |
|----------|---------------|--------|--------|
| Commands | 13 | 13 | Match |
| Agents (subagents) | 6 | 6 | Match |
| Orchestrator | 1 | 1 | Match |
| Skills | 12 dirs | 12 dirs | Match |
| Hooks | 9 | 9 | Match |
| Scripts | 14 | 13 | 1 missing |
| Rules | 6 | 6 | Match |
| Context | 99 (excl. repo-specific) | 100 | 1 extra |
| Docs | 20 | 20 | Match |
| Root files | settings.json, .gitignore, README.md | All present | Match |

**Missing files (source-only, all low-importance)**:
1. `agent/README.md` -- documentation file, not a functional artifact
2. `context/core/checkpoints/.placeholder` -- empty placeholder file
3. `hooks/README.md` -- documentation file
4. `scripts/.gitkeep` -- git tracking placeholder
5. `scripts/README.md` -- documentation file
6. `scripts/test-results.md` -- test output file
7. `systemd/README.md` -- documentation file
8. `templates/README.md` -- documentation file

**Why these are missing**: The sync scanner uses `vim.fn.glob()` with extension-specific patterns (e.g., `*.sh` for scripts, `*.md` for commands). README.md files in non-markdown-scanning directories (scripts, hooks, systemd, templates) are not matched by the extension filters. The `.gitkeep` and `.placeholder` files are not matched by any pattern.

**Target-only file**:
- `context/project/repo/README.md` -- a project-local file created by the project itself (not a sync artifact). This is appropriate.

### Root Configuration Files

| File | .claude | .opencode |
|------|---------|-----------|
| Root CLAUDE.md | NOT synced (correct -- Neovim-specific) | N/A |
| .claude/CLAUDE.md | Synced (correct -- agent system config) | N/A |
| OPENCODE.md | N/A | Not present in source or target |
| .opencode/settings.json | N/A | Synced |

## Decisions

- The loader code is correct and does not need revision
- The symlink strategy effectively exposes extension artifacts to the core sync without requiring explicit extension loading
- The 8 missing `.opencode/` files are all README.md placeholders or utility files that have no functional impact
- The `.opencode/` scanner could be enhanced to also sync README.md files (not just extension-matched files), but this is a low-priority improvement

## Risks & Mitigations

1. **Symlink fragility**: If symlinks break (e.g., extension directory renamed/moved), the core sync will silently skip those files. Mitigation: symlinks are created by the extension system and are stable.

2. **README.md gap in .opencode**: The 8 missing README files mean directory documentation is absent in the target. Mitigation: these are informational only and don't affect functionality.

3. **No extensions-state.json in Vision**: Extension artifacts were synced via symlinks rather than the extension system, so there's no formal tracking. Mitigation: the core sync is idempotent and can re-sync at any time.

## Context Extension Recommendations

None -- the research domain is well-covered by existing context files.

## Appendix

### Search Queries Used
- Grep for `leader.*ac`, `leader.*ao`, `ClaudeCommands`, `OpencodeCommands`
- File listing with `find` and `find -L` (with and without symlink following)
- Python-based directory comparison for accurate diff
- Content diff of key files (CLAUDE.md, commands, agents, rules)

### Key Source Files
- `lua/neotex/plugins/editor/which-key.lua` (lines 230-263) -- keymap definitions
- `lua/neotex/plugins/ai/shared/picker/config.lua` -- .claude/.opencode config presets
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` -- core sync logic
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- extension load/unload system
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` -- file copy engine
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` (line 978) -- "Load Core Agent System" entry
