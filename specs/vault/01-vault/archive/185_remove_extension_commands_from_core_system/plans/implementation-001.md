# Implementation Plan: Task #185

- **Task**: 185 - Remove extension commands from core system
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-11
- **Feature**: Move extension-specific commands/skills from core to extensions, simplify routing tables
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/.claude/CLAUDE.md

## Overview

This task moves 7 extension-specific commands and 1 duplicate skill from the core `.claude/` directory to their respective extension directories, simplifies the language routing tables in `research.md` and `implement.md` to only list core languages, and updates the extension installer script to handle command symlinks. The goal is a clean core/extension boundary where extensions are self-contained.

### Research Integration

Research identified 7 commands to move (convert, deck, slides, table to filetypes; lake, lean to lean; tag to web), 1 skill to remove from core (skill-tag, duplicate of web extension's copy), and routing tables with 10-14 extension rows to simplify. The extension loader (`install-extension.sh`) currently handles skills, agents, and index entries but NOT commands -- this needs to be added.

## Goals and Non-Goals

**Goals**:
- Move all extension-specific commands from core `commands/` to extension `commands/` directories
- Remove duplicate `skill-tag` from core (already exists in web extension)
- Simplify routing tables in `research.md` and `implement.md` to core-only entries
- Update `install-extension.sh` to create command symlinks during extension installation
- Update `uninstall-extension.sh` to remove command symlinks during extension uninstallation
- Update `CLAUDE.md` to reflect core-only command list

**Non-Goals**:
- Changing how extensions are loaded at runtime (keybinding, config merge)
- Modifying extension manifests (they already declare their commands correctly)
- Adding dynamic routing lookup (commands already note extension skill discovery)
- Restructuring the extension loader beyond command symlink support

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Commands unavailable after move if extensions not loaded | H | M | Extension loader creates symlinks; verify symlinks work for commands |
| Breaking existing extension installations | M | L | Test install/uninstall cycle after changes |
| Routing table simplification breaks non-core language tasks | H | L | Keep the "Extension skills" note directing to extension discovery |

## Implementation Phases

### Phase 1: Create Extension Command Directories and Move Commands [COMPLETED]

**Goal**: Move 7 commands from core to their respective extension directories

**Tasks**:
- [ ] Create `commands/` directory in filetypes extension
- [ ] Create `commands/` directory in lean extension
- [ ] Create `commands/` directory in web extension
- [ ] Move `convert.md`, `deck.md`, `slides.md`, `table.md` from `.claude/commands/` to `.claude/extensions/filetypes/commands/`
- [ ] Move `lake.md`, `lean.md` from `.claude/commands/` to `.claude/extensions/lean/commands/`
- [ ] Move `tag.md` from `.claude/commands/` to `.claude/extensions/web/commands/`
- [ ] Verify all 7 files exist in their new locations
- [ ] Verify core `commands/` directory now has only 11 commands

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/commands/convert.md` - Move to `.claude/extensions/filetypes/commands/`
- `.claude/commands/deck.md` - Move to `.claude/extensions/filetypes/commands/`
- `.claude/commands/slides.md` - Move to `.claude/extensions/filetypes/commands/`
- `.claude/commands/table.md` - Move to `.claude/extensions/filetypes/commands/`
- `.claude/commands/lake.md` - Move to `.claude/extensions/lean/commands/`
- `.claude/commands/lean.md` - Move to `.claude/extensions/lean/commands/`
- `.claude/commands/tag.md` - Move to `.claude/extensions/web/commands/`

**Verification**:
- `ls .claude/commands/` shows exactly 11 files (errors, fix-it, implement, meta, plan, refresh, research, review, revise, task, todo)
- `ls .claude/extensions/filetypes/commands/` shows 4 files
- `ls .claude/extensions/lean/commands/` shows 2 files
- `ls .claude/extensions/web/commands/` shows 1 file

---

### Phase 2: Remove Duplicate Core Skill [COMPLETED]

**Goal**: Remove skill-tag from core since it already exists in the web extension

**Tasks**:
- [ ] Verify `skill-tag` exists in `.claude/extensions/web/skills/skill-tag/`
- [ ] Compare core `skill-tag/SKILL.md` with web extension copy to confirm they are identical or web version is authoritative
- [ ] Remove `.claude/skills/skill-tag/` directory from core
- [ ] Verify core `skills/` directory has 9 remaining skills

**Timing**: 0.25 hours

**Files to modify**:
- `.claude/skills/skill-tag/` - Delete directory (duplicate of web extension's copy)

**Verification**:
- `ls .claude/skills/` shows 9 directories (no skill-tag)
- `.claude/extensions/web/skills/skill-tag/` still exists

---

### Phase 3: Update Extension Installer and Uninstaller [COMPLETED]

**Goal**: Add command symlink support to `install-extension.sh` and `uninstall-extension.sh`

**Tasks**:
- [ ] Add `install_commands()` function to `install-extension.sh` that creates symlinks from `extensions/{name}/commands/*.md` to `.claude/commands/`
- [ ] Follow the same pattern as `install_skills()` (relative symlinks, duplicate detection, logging)
- [ ] Add `install_commands` call to main installation flow
- [ ] Update `uninstall-extension.sh` to remove command symlinks (if it handles skill/agent symlink removal)
- [ ] Test by running install script on one extension and verifying command symlinks are created

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/scripts/install-extension.sh` - Add `install_commands()` function and call it
- `.claude/scripts/uninstall-extension.sh` - Add command symlink removal

**Verification**:
- Run `bash .claude/scripts/install-extension.sh .claude/extensions/web` and verify `.claude/commands/tag.md` is created as a symlink
- Run `ls -la .claude/commands/tag.md` to confirm it points to `../extensions/web/commands/tag.md`

---

### Phase 4: Simplify Routing Tables [COMPLETED]

**Goal**: Reduce routing tables in research.md and implement.md to core-only entries

**Tasks**:
- [ ] In `research.md`: Replace the 11-row routing table (lines 50-62) with a single core entry: `general`, `meta`, `markdown` -> `skill-researcher`
- [ ] In `research.md`: Add a note below the table explaining that extension languages are handled by extension-provided skills (discovered automatically when extensions are loaded)
- [ ] In `implement.md`: Replace the 11-row routing table (lines 65-77) with two core entries: `general`, `meta`, `markdown` -> `skill-implementer` and `formal`, `logic`, `math`, `physics` -> `skill-implementer`
- [ ] In `implement.md`: Add a similar extension discovery note
- [ ] Keep the existing "Note: Extension skills are located in..." line in both files

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/commands/research.md` - Simplify routing table to core-only
- `.claude/commands/implement.md` - Simplify routing table to core-only

**Verification**:
- `grep -c "skill-" .claude/commands/research.md` shows reduced count
- `grep -c "skill-" .claude/commands/implement.md` shows reduced count
- Core entries (skill-researcher, skill-implementer) still present

---

### Phase 5: Update CLAUDE.md and Documentation [COMPLETED]

**Goal**: Update system documentation to reflect the new core-only command and skill lists

**Tasks**:
- [ ] In `.claude/CLAUDE.md`: Remove any extension commands from the Command Reference table (verify `/convert` is not listed -- it should not be based on current file)
- [ ] In `.claude/CLAUDE.md`: Verify the Skill-to-Agent Mapping table only lists core skills (remove skill-tag entry if present)
- [ ] In `.claude/CLAUDE.md`: Ensure "Extension Skills" note is present
- [ ] In `.claude/CLAUDE.md`: Add `markdown` to core language routing table if missing
- [ ] Verify the root `CLAUDE.md` (`.config/CLAUDE.md`) is consistent

**Timing**: 0.25 hours

**Files to modify**:
- `.claude/CLAUDE.md` - Update skill mapping table, verify command list
- `.config/CLAUDE.md` - Verify consistency with inner CLAUDE.md

**Verification**:
- `grep "skill-tag" .claude/CLAUDE.md` returns no matches in core skill table
- `grep "/convert" .claude/CLAUDE.md` returns no matches in command table
- `markdown` appears in core language routing

---

### Phase 6: Verification and Testing [COMPLETED]

**Goal**: Validate the complete migration works end-to-end

**Tasks**:
- [ ] Run `ls .claude/commands/` and verify exactly 11 core commands remain
- [ ] Run `ls .claude/skills/` and verify exactly 9 core skills remain
- [ ] Run `bash .claude/scripts/install-extension.sh .claude/extensions/filetypes` and verify 4 command symlinks are created in `.claude/commands/`
- [ ] Run `bash .claude/scripts/install-extension.sh .claude/extensions/lean` and verify 2 command symlinks are created
- [ ] Run `bash .claude/scripts/install-extension.sh .claude/extensions/web` and verify 1 command symlink is created (plus skill-tag symlink)
- [ ] Verify symlinks point to correct relative paths
- [ ] Run `bash .claude/scripts/uninstall-extension.sh .claude/extensions/web` and verify command symlinks are removed
- [ ] Re-install extensions to restore working state

**Timing**: 0.5 hours

**Files to modify**: None (verification only)

**Verification**:
- All extension commands accessible via symlinks after installation
- Core commands directory is clean (no extension commands without symlinks)
- Install/uninstall cycle is idempotent

## Testing and Validation

- [ ] Core commands directory contains exactly 11 files after Phase 1
- [ ] Core skills directory contains exactly 9 directories after Phase 2
- [ ] Extension installer creates command symlinks for all declared commands
- [ ] Extension uninstaller removes command symlinks
- [ ] Routing tables in research.md and implement.md contain only core language entries
- [ ] CLAUDE.md references only core commands and skills
- [ ] A full install-all-extensions cycle leaves the system in a working state

## Artifacts and Outputs

- Modified `install-extension.sh` with command symlink support
- Modified `uninstall-extension.sh` with command symlink removal
- Simplified `research.md` and `implement.md` routing tables
- Updated `CLAUDE.md` documentation
- 7 commands moved to extension directories
- 1 duplicate skill removed from core

## Rollback/Contingency

If the migration causes issues:
1. Use `git checkout` to restore moved command files to core `commands/`
2. Re-add `skill-tag` to core `skills/` if needed
3. Revert routing table changes in `research.md` and `implement.md`
4. Revert installer script changes

All changes are tracked in git, making full rollback straightforward.
