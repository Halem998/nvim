# Implementation Plan: Add Sheet Command to Present Extension

- **Task**: 552 - add_sheet_command_to_present_extension
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/552_add_sheet_command_to_present_extension/reports/01_add-sheet-command.md
- **Artifacts**: plans/01_add-sheet-command.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The present extension needs access to the generic `/sheet` command for XLSX spreadsheet operations. Research confirmed that `/sheet` already exists in the `filetypes` extension with identical functionality to the Zed source. Rather than duplicating files, the implementation adds `filetypes` as a dependency in the present extension's `manifest.json`, which causes the extension loader to auto-load all filetypes commands (including `/sheet`) when present is loaded. Documentation in EXTENSION.md and README.md is updated to reflect the new dependency. Done when loading the present extension via `<leader>al` also makes `/sheet` available.

### Research Integration

The research report (01_add-sheet-command.md) identified three options:
- **Option A (selected)**: Add `filetypes` as a dependency -- zero duplication, automatic loading
- Option B: Copy 3 files into present -- higher maintenance burden, 800+ lines duplicated
- Option C: Present-specific sheet command -- unnecessary given `/budget` already covers grant-budget use case

Key finding: the Zed `/sheet` command is already fully ported to the filetypes extension. No new command/skill/agent files are needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. The work is an extension configuration change that improves the present extension's capability surface.

## Goals & Non-Goals

**Goals**:
- Make `/sheet` available when the present extension is loaded
- Achieve this through dependency declaration (no file duplication)
- Document the new dependency in EXTENSION.md and README.md

**Non-Goals**:
- Creating a present-specific sheet command with grant-aware semantics
- Modifying the filetypes extension's sheet implementation
- Addressing the `/sheet` command name collision between filetypes and founder (existing issue, out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Loading filetypes adds extra commands (/convert, /table, /scrape, /edit) beyond just /sheet | L | H | Acceptable trade-off: these commands are useful for present workflows (e.g., /convert for document formatting) |
| Command name collision if founder extension also loaded | M | L | Extension picker model means users typically load one domain at a time; existing behavior, not new |
| openpyxl MCP server declared in filetypes may conflict with present's superdoc MCP | L | L | MCP servers use distinct names; no conflict expected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Filetypes Dependency and Update Documentation [NOT STARTED]

**Goal**: Add `filetypes` to the present extension's dependency list and update documentation files to reflect the change.

**Tasks**:
- [ ] Edit `.claude/extensions/present/manifest.json`: change `"dependencies": ["core", "slidev"]` to `"dependencies": ["core", "slidev", "filetypes"]`
- [ ] Edit `.claude/extensions/present/EXTENSION.md`: add a note in the Commands table or below it that `/sheet` is available via the `filetypes` dependency for generic XLSX spreadsheet operations
- [ ] Edit `.claude/extensions/present/README.md`: add `filetypes` to the Dependencies section alongside `slidev`, noting it provides `/sheet` for generic XLSX operations
- [ ] Update the Installation paragraph in README.md to mention that loading `present` also auto-loads `filetypes` (in addition to `slidev`)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/manifest.json` -- add `"filetypes"` to `dependencies` array
- `.claude/extensions/present/EXTENSION.md` -- document `/sheet` availability
- `.claude/extensions/present/README.md` -- update Dependencies section and Installation note

**Verification**:
- `manifest.json` contains `"dependencies": ["core", "slidev", "filetypes"]`
- EXTENSION.md mentions `/sheet` command
- README.md lists `filetypes` as a dependency

---

### Phase 2: Verify Extension Loading [NOT STARTED]

**Goal**: Confirm the dependency chain loads correctly and `/sheet` becomes available.

**Tasks**:
- [ ] Run `jq '.dependencies' .claude/extensions/present/manifest.json` to verify the array contains `filetypes`
- [ ] Verify the filetypes extension exists at `.claude/extensions/filetypes/` with its manifest, commands/sheet.md, skills/skill-sheet/, and agents/sheet-agent.md
- [ ] Verify no circular dependency: check that filetypes does not depend on present (`jq '.dependencies' .claude/extensions/filetypes/manifest.json` should not contain `present`)
- [ ] Run `.claude/scripts/check-extension-docs.sh` to validate extension documentation consistency (if script exists and is executable)

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only)

**Verification**:
- `jq '.dependencies' .claude/extensions/present/manifest.json` outputs `["core", "slidev", "filetypes"]`
- No circular dependency detected
- Doc-lint passes (or reports only pre-existing issues unrelated to this change)

## Testing & Validation

- [ ] `manifest.json` parses as valid JSON with `jq . .claude/extensions/present/manifest.json`
- [ ] Dependencies array is `["core", "slidev", "filetypes"]`
- [ ] No circular dependency between present and filetypes
- [ ] EXTENSION.md mentions `/sheet` command availability
- [ ] README.md lists filetypes as a dependency
- [ ] Doc-lint script passes (if available)

## Artifacts & Outputs

- `.claude/extensions/present/manifest.json` -- updated with filetypes dependency
- `.claude/extensions/present/EXTENSION.md` -- updated with /sheet documentation
- `.claude/extensions/present/README.md` -- updated with filetypes dependency documentation

## Rollback/Contingency

Revert the three file changes via git:
```bash
git checkout -- .claude/extensions/present/manifest.json .claude/extensions/present/EXTENSION.md .claude/extensions/present/README.md
```
The present extension returns to its previous state with `["core", "slidev"]` dependencies and no `/sheet` reference.
