# Implementation Summary: Task #172

**Completed**: 2026-03-10
**Duration**: ~30 minutes

## Changes Made

Fixed AGENTS.md core content loss on extension reload by implementing a two-pronged approach:

1. **Created global AGENTS.md** - Established `~/.config/nvim/.opencode/AGENTS.md` as the canonical core content source, containing all system documentation (Quick Reference, Project Structure, Task Management, Command Reference, Skill-to-Agent Mapping, Rules, State Synchronization, Error Handling, Git Conventions).

2. **Updated sync.lua root_file_names** - Added "AGENTS.md" to the list of root files synced for opencode projects, ensuring the global AGENTS.md is copied to project directories during sync operations.

3. **Updated all extension manifests** - Changed `merge_targets.opencode_md.target` from `.opencode/OPENCODE.md` to `.opencode/AGENTS.md` in all 11 extension manifests.

4. **Hardened inject_section** - Modified `merge.lua:inject_section` to read sibling README.md as seed content when creating a new file, rather than creating an empty file. This defends against core content loss during extension reload cycles.

## Files Modified

- `~/.config/nvim/.opencode/AGENTS.md` - Created with 165 lines of core system documentation
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Added "AGENTS.md" to opencode root_file_names
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Hardened inject_section with README.md seeding
- `~/.config/nvim/.opencode/extensions/nvim/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/lean/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/formal/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/python/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/z3/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/latex/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/typst/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/nix/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/epidemiology/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/filetypes/manifest.json` - Changed target to AGENTS.md
- `~/.config/nvim/.opencode/extensions/web/manifest.json` - Changed target to AGENTS.md

## Verification

- AGENTS.md line count: 165 lines (exceeds extension-only baseline)
- Core sections present: 11 sections (Quick Reference, Project Structure, Task Management, Command Reference, Skill-to-Agent Mapping, Rules and Conventions, State Synchronization, Error Handling, Git Commit Conventions, jq Command Safety, Important Notes)
- Neovim startup: Success (no Lua errors)
- Module loading: Success (merge.lua loads correctly)
- All extension manifests target AGENTS.md: Verified

## Notes

- The fix uses OpenCode's standard `AGENTS.md` file (mirrors CLAUDE.md for Claude Code) rather than the legacy `OPENCODE.md`
- Both AGENTS.md and OPENCODE.md are included in root_file_names for backward compatibility
- The inject_section hardening provides defense-in-depth by seeding from README.md if the target file is missing
