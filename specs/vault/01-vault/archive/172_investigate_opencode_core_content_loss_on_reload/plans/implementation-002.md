# Implementation Plan: Fix AGENTS.md Core Content Loss on Reload (Revised)

- **Task**: 172 - Investigate OPENCODE.md core content loss on reload
- **Date**: 2026-03-10 (Revised)
- **Feature**: Fix core content loss when extensions are reloaded via <leader>ao
- **Status**: [COMPLETE]
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Type**: neovim
- **Lean Intent**: false

## Revision Notes

**v002 Changes** (from research-002.md):
- Renamed target file from `OPENCODE.md` to `AGENTS.md` throughout
- AGENTS.md is the standard OpenCode project instructions file (mirrors CLAUDE.md for Claude Code)
- Extension manifests and merge.lua references updated accordingly

## Overview

The root cause is an architectural gap: task OC_127 removed the global agent config file from `~/.config/nvim/.opencode/`, but extension manifests still target the project's agent config file for section injection. When `inject_section` in `merge.lua` encounters a missing target file, it creates an empty file with no core content. When all 11 extensions are reloaded, the result is an agent config containing only extension sections and no core system documentation.

**Key Insight from research-002.md**: OpenCode uses `AGENTS.md` as its standard project instructions file, not `OPENCODE.md`. This mirrors how Claude Code uses `CLAUDE.md`.

The fix creates a global `AGENTS.md` source file, then hardens `inject_section` to use core content as a seed when creating a new file. This two-pronged approach ensures both sync-based restoration and fresh-creation scenarios preserve core content.

## Goals & Non-Goals

**Goals**:
- Create a global `~/.config/nvim/.opencode/AGENTS.md` with core system documentation
- Ensure "Load Core Agent System" sync restores core content via the normal root_files mechanism
- Update sync.lua root_file_names to include `AGENTS.md` if not already present
- Harden `inject_section` so it never creates an empty file when a README.md template exists
- Verify the fix survives full extension unload/reload cycles

**Non-Goals**:
- Removing OPENCODE.md support entirely (may exist in legacy projects)
- Changing extension manifests to target README.md instead of AGENTS.md
- Modifying the extension load/unload sequencing logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content drift between README.md and AGENTS.md | Medium | Medium | Generate AGENTS.md from README.md content; document the relationship |
| Extension manifests still target OPENCODE.md | Medium | High | Audit and update extension manifests to use AGENTS.md |
| inject_section fallback reads wrong README.md | Low | Low | Use the target file's sibling README.md, matching existing directory structure |

## Implementation Phases

### Phase 1: Create Global AGENTS.md and Update Root File Names [COMPLETED]

**Goal**: Establish `~/.config/nvim/.opencode/AGENTS.md` as the canonical core content source, mirroring how `.claude/CLAUDE.md` works.

**Tasks**:
- [ ] Read current `~/.config/nvim/.opencode/README.md` to understand core content structure
- [ ] Create `~/.config/nvim/.opencode/AGENTS.md` with the core system documentation from README.md, adapted for the AGENTS.md role (agent system config file, not general documentation)
- [ ] Check `sync.lua` for the opencode root_file_names list and add `"AGENTS.md"` if not present
- [ ] Update extension manifests: change `section_target_file` from `"OPENCODE.md"` to `"AGENTS.md"` where applicable
- [ ] Test that "Load Core Agent System" sync now copies AGENTS.md to project directories

**Timing**: 1 hour

**Files to modify**:
- `~/.config/nvim/.opencode/AGENTS.md` - Create new file with core system documentation
- `lua/neotex/plugins/ai/shared/sync.lua` - Add "AGENTS.md" to opencode root_file_names if missing
- `~/.config/nvim/.opencode/extensions/*/manifest.json` - Update section_target_file to AGENTS.md

**Verification**:
- File exists at `~/.config/nvim/.opencode/AGENTS.md`
- Content includes core sections (Quick Reference, Project Structure, Task Management, Command Reference, etc.)
- Running sync.lua's `scan_all_artifacts` with opencode config includes AGENTS.md in root_files
- Extension manifests target AGENTS.md

---

### Phase 2: Harden inject_section Against Empty File Creation [COMPLETED]

**Goal**: Modify `merge.lua:inject_section` to seed new files with core content from a sibling README.md when creating the target file for the first time.

**Tasks**:
- [ ] In `merge.lua:inject_section`, replace the empty-file creation (`write_file_string(target_path, "")`) with logic that reads a sibling README.md as seed content
- [ ] If no README.md exists in the same directory, fall back to empty string (preserving current behavior for edge cases)
- [ ] Add a comment explaining the defensive pattern and why it exists

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 139-141 - Replace empty file creation with README.md seed

**Verification**:
- When AGENTS.md does not exist and an extension is loaded, the created file contains README.md content plus the extension section
- When AGENTS.md already exists, behavior is unchanged (idempotent update path)
- When no README.md exists either, falls back to empty file (no crash)

---

### Phase 3: End-to-End Verification [COMPLETED]

**Goal**: Confirm the fix survives the exact scenario that caused the original content loss: full extension unload followed by sequential reload of all 11 extensions.

**Tasks**:
- [ ] Run "Load Core Agent System" sync via `<leader>ao` to sync global AGENTS.md to project
- [ ] Verify project AGENTS.md contains core content
- [ ] Unload all extensions (simulating the reload trigger)
- [ ] Reload all 11 extensions sequentially
- [ ] Verify AGENTS.md still contains core content plus all 11 extension sections
- [ ] Count lines to confirm content is not just extension sections (should be >600 lines)
- [ ] Verify the backup file (AGENTS.md.backup) also contains core content

**Timing**: 30 minutes

**Files to modify**:
- No files modified; verification only

**Verification**:
- AGENTS.md line count after full reload cycle exceeds extension-only count
- Core sections (Quick Reference, Command Reference, etc.) are present after reload
- All 11 extension section markers are present after reload

## Testing & Validation

- [ ] Global AGENTS.md exists and contains core system documentation
- [ ] "Load Core Agent System" sync successfully copies AGENTS.md to project directories
- [ ] Extension manifests all target AGENTS.md (not OPENCODE.md)
- [ ] inject_section creates AGENTS.md with core content when file is missing
- [ ] inject_section preserves existing content when file already exists
- [ ] Full extension reload cycle preserves core content
- [ ] Line count after reload > 600 (vs extension-only baseline)

## Artifacts & Outputs

- `~/.config/nvim/.opencode/AGENTS.md` - Global core content source file
- `lua/neotex/plugins/ai/shared/sync.lua` - Updated root_file_names
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Hardened inject_section
- Extension manifests with updated section_target_file

## Rollback/Contingency

If the fix causes issues:
1. Delete `~/.config/nvim/.opencode/AGENTS.md` to revert to pre-fix state
2. Revert the `merge.lua` change (restore `write_file_string(target_path, "")`)
3. Revert extension manifest changes
4. Manually reconstruct AGENTS.md from README.md content plus extension sections
