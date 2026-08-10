# Research Report: Add Sheet Command to Present Extension

- **Task**: 552 - add_sheet_command_to_present_extension
- **Started**: 2026-05-11T12:00:00Z
- **Completed**: 2026-05-11T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Zed source: `/home/benjamin/.config/zed/.claude/commands/sheet.md`
  - Existing filetypes extension: `.claude/extensions/filetypes/`
  - Existing present extension: `.claude/extensions/present/`
  - Existing founder extension: `.claude/extensions/founder/`
  - Extension development guide: `.claude/context/guides/extension-development.md`
- **Artifacts**: `specs/552_add_sheet_command_to_present_extension/reports/01_add-sheet-command.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- The Zed `/sheet` command (generic XLSX create/edit/analyze) is **already fully ported** to this repo in the `filetypes` extension with identical command, skill (`skill-sheet`), and agent (`sheet-agent`).
- The `present` extension currently has no `/sheet` command and does not depend on `filetypes`. Adding the sheet capability requires either adding `filetypes` as a dependency or copying the three files into `present/`.
- The `founder` extension has a **different** `/sheet` command (cost breakdown spreadsheets with forcing questions), which is unrelated to this task.
- The recommended approach is to **add `filetypes` as a dependency** to the present extension's manifest, rather than duplicating the command/skill/agent files, since the filetypes extension already provides all the XLSX tooling infrastructure (tool detection, dependency guide, openpyxl MCP server).
- Alternatively, if the goal is a present-specific sheet command (e.g., grant-budget-aware), consider whether the existing `/budget` command already covers the use case.

## Context & Scope

The task asks to port `/sheet` from the Zed IDE's `.claude/commands/sheet.md` into the `present/` extension. Research needed to determine:

1. What the Zed `/sheet` command does
2. Whether it already exists in this repo
3. What structure changes the present extension needs
4. How the extension loader (`<leader>al`) handles dependencies

## Findings

### Zed Source Command

The Zed `/sheet` command at `/home/benjamin/.config/zed/.claude/commands/sheet.md` is a generic XLSX spreadsheet manipulation command with three modes:
- **create**: Build new workbooks from scratch with formulas, formatting, and multi-sheet layouts
- **edit**: Modify existing workbooks preserving formulas and styles
- **analyze**: Read and summarize spreadsheet data

It delegates to `skill-sheet` which invokes `sheet-agent`. The agent uses `openpyxl` for workbook operations and `pandas` for analysis.

### Existing Filetypes Extension (Already Ported)

The Zed `/sheet` command, skill, and agent are **already present** in the `filetypes` extension:

| Component | Path |
|-----------|------|
| Command | `.claude/extensions/filetypes/commands/sheet.md` |
| Skill | `.claude/extensions/filetypes/skills/skill-sheet/SKILL.md` |
| Agent | `.claude/extensions/filetypes/agents/sheet-agent.md` |
| Context (tool detection) | `.claude/extensions/filetypes/context/project/filetypes/tools/tool-detection.md` |
| Context (dependencies) | `.claude/extensions/filetypes/context/project/filetypes/tools/dependency-guide.md` |
| MCP server | `openpyxl` MCP server declared in filetypes `manifest.json` |

Diff between the Zed version and filetypes version shows only trivial delegation_path naming differences (`"sheet"` vs `"xlsx"` in one path element).

### Present Extension Current State

The present extension provides five commands: `/grant`, `/budget`, `/timeline`, `/funds`, `/slides`. Its dependencies are `["core", "slidev"]`. It has no dependency on `filetypes` and no `/sheet` command.

The present extension already handles XLSX generation via its `/budget` command (grant-specific budgets with openpyxl), but this is a domain-specific budget tool, not a general-purpose XLSX command.

### Founder Extension /sheet (Different Purpose)

The founder extension has its own `/sheet` command at `.claude/extensions/founder/commands/sheet.md`. This is a **completely different command** -- a cost breakdown spreadsheet generator with forcing questions, task system integration, and modes (ESTIMATE, BUDGET, FORECAST, ACTUALS). It uses `skill-founder-spreadsheet` and `founder-spreadsheet-agent`, not the generic XLSX chain.

### Extension Loader Mechanism

Extensions are loaded via `<leader>al` which invokes the picker at `lua/neotex/plugins/ai/claude/extensions/picker.lua`. The loader:
1. Reads `manifest.json` for each selected extension
2. Auto-loads dependencies (with circular detection, depth limit of 5)
3. Copies agents, skills, commands, rules into `.claude/` runtime
4. Merges context index entries into `.claude/context/index.json`
5. Regenerates `.claude/CLAUDE.md` from merge sources

Dependencies declared in `manifest.json` are auto-loaded silently.

### Command Name Collision Risk

If both `filetypes` and `founder` are loaded simultaneously, they would both provide a `/sheet` command. The filetypes version is generic XLSX; the founder version is cost breakdown. This collision already exists and is managed by load-time context (typically only one domain extension is loaded per session).

Adding `/sheet` to `present` would create a **three-way collision** if all three extensions are loaded. This is a concern but is mitigated by the extension picker's selective loading model.

## Decisions

- The Zed `/sheet` command does not need to be ported -- it already exists in the `filetypes` extension with identical functionality.
- The task should be reframed: either (a) add `filetypes` as a dependency to `present`, or (b) create a present-specific `/sheet` command with grant-aware semantics.

## Recommendations

### Option A: Add filetypes as a dependency (Recommended)

Add `"filetypes"` to the present extension's `dependencies` array in `manifest.json`:

```json
"dependencies": ["core", "slidev", "filetypes"]
```

**Pros**:
- No code duplication
- Inherits all filetypes capabilities (convert, table, scrape, edit, sheet)
- Automatic tool detection context and dependency guide
- openpyxl MCP server configuration comes for free

**Cons**:
- Loads the entire filetypes extension (all commands, agents, skills)
- May be more than needed if only `/sheet` is desired
- Adds `/convert`, `/table`, `/scrape`, `/edit` commands which may clutter the command space

**Files to modify**: 1 file
- `.claude/extensions/present/manifest.json` -- add `"filetypes"` to `dependencies`

### Option B: Copy sheet files into present extension

Copy the three files from filetypes to present and update manifest/index:

**Files to create**:
- `.claude/extensions/present/commands/sheet.md`
- `.claude/extensions/present/skills/skill-sheet/SKILL.md`
- `.claude/extensions/present/agents/sheet-agent.md`

**Files to modify**:
- `.claude/extensions/present/manifest.json` -- add to `provides.agents`, `provides.skills`, `provides.commands`, `routing`
- `.claude/extensions/present/EXTENSION.md` -- add `/sheet` to commands table
- `.claude/extensions/present/README.md` -- add `/sheet` to architecture and command docs
- `.claude/extensions/present/opencode-agents.json` -- add sheet agent entry
- `.claude/extensions/present/index-entries.json` -- add context entries (optional, could reference filetypes context)

**Pros**:
- Self-contained present extension
- No extra commands loaded
- Can customize for present-specific needs

**Cons**:
- Duplicates 3 files (~800+ lines total)
- Must maintain two copies when filetypes updates
- Still needs openpyxl/pandas tool detection context (would need to either duplicate or reference filetypes context)

### Option C: Present-specific sheet command

If the goal is a grant-budget-aware spreadsheet command (not generic XLSX), consider whether `/budget` already covers the use case. If it does, no new command is needed.

## Risks & Mitigations

- **Command name collision**: If present and filetypes are both loaded, two `/sheet` commands would exist. Mitigation: the extension loader typically handles this via last-loaded-wins, and users generally load one domain extension at a time.
- **Context dependency**: The `sheet-agent` references filetypes-specific context paths (`context/project/filetypes/tools/tool-detection.md`). If Option B is chosen, these paths must be updated or the filetypes context must be available. Mitigation: add filetypes as a dependency even with Option B.
- **Maintenance burden**: Duplicated files diverge over time. Mitigation: prefer Option A (dependency) over Option B (copy).

## Appendix

### Search Queries
- File system searches in `.claude/extensions/` for sheet-related content
- Diff comparison between Zed source and filetypes extension versions
- Manifest.json analysis for all relevant extensions
- Extension loader code at `lua/neotex/plugins/ai/claude/extensions/picker.lua`

### Key File References
- Zed source: `/home/benjamin/.config/zed/.claude/commands/sheet.md`
- Filetypes command: `.claude/extensions/filetypes/commands/sheet.md`
- Filetypes skill: `.claude/extensions/filetypes/skills/skill-sheet/SKILL.md`
- Filetypes agent: `.claude/extensions/filetypes/agents/sheet-agent.md`
- Present manifest: `.claude/extensions/present/manifest.json`
- Present EXTENSION.md: `.claude/extensions/present/EXTENSION.md`
- Founder /sheet (different): `.claude/extensions/founder/commands/sheet.md`
