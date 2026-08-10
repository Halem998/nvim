# Implementation Summary: Task #185

**Completed**: 2026-03-11
**Duration**: ~1.5 hours

## Changes Made

Moved 7 extension-specific commands from core `.claude/commands/` to their respective extension directories, removed duplicate `skill-tag` from core (kept web extension copy), added command symlink support to extension installer/uninstaller scripts, and simplified routing tables in research.md and implement.md to core-only entries.

## Files Modified

### Commands Moved
- `.claude/commands/convert.md` -> `.claude/extensions/filetypes/commands/`
- `.claude/commands/deck.md` -> `.claude/extensions/filetypes/commands/`
- `.claude/commands/slides.md` -> `.claude/extensions/filetypes/commands/`
- `.claude/commands/table.md` -> `.claude/extensions/filetypes/commands/`
- `.claude/commands/lake.md` -> `.claude/extensions/lean/commands/`
- `.claude/commands/lean.md` -> `.claude/extensions/lean/commands/`
- `.claude/commands/tag.md` -> `.claude/extensions/web/commands/`

### Skills Removed
- `.claude/skills/skill-tag/` - Removed (duplicate of web extension copy)

### Scripts Updated
- `.claude/scripts/install-extension.sh` - Added `install_commands()` function for command symlinks
- `.claude/scripts/uninstall-extension.sh` - Added `remove_commands()` function for cleanup

### Documentation Updated
- `.claude/commands/research.md` - Simplified routing table to core-only (1 entry)
- `.claude/commands/implement.md` - Simplified routing table to core-only (2 entries)
- `.claude/CLAUDE.md` - Added `markdown` to core language routing table

## Verification

- Core commands directory: 11 files (errors, fix-it, implement, meta, plan, refresh, research, review, revise, task, todo)
- Core skills directory: 9 directories (skill-fix-it, skill-git-workflow, skill-implementer, skill-meta, skill-orchestrator, skill-planner, skill-refresh, skill-researcher, skill-status-sync)
- Extension installer creates command symlinks: Verified with filetypes (4), lean (2), web (1)
- Extension uninstaller removes command symlinks: Verified with web extension cycle
- Symlinks point to correct relative paths: `../extensions/{ext}/commands/{cmd}.md`
- Install/uninstall cycle is idempotent: Verified

## Notes

The extension system now has clean core/extension separation:
- Core contains only universal commands and skills
- Extensions provide language-specific capabilities including commands
- Extension installer/uninstaller handles all artifacts (commands, skills, agents, index entries)
- Routing tables direct to core skills, with notes about extension discovery

When extensions are loaded via `<leader>ac`, their commands become available via symlinks. This maintains the user experience while keeping the core system minimal.
