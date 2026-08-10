# Research Report: Task #719

**Task**: 719 - Update literature extension manifest and documentation for /cite command
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:05:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 717 (cite implementation, now complete)
**Sources/Inputs**: Codebase exploration
**Artifacts**: `specs/719_update_literature_manifest_cite/reports/01_manifest-update-research.md`
**Standards**: report-format.md

## Executive Summary

- Task 717 already did most of the work: `manifest.json` was updated with `skill-cite` (but not `cite.md` command or `cite-extract.sh` script), `cite.md`, `skill-cite/SKILL.md`, and `cite-extract.sh` all exist.
- `EXTENSION.md` has NOT yet been updated with a `/cite` section — this is a clear gap to fill.
- `core/merge-sources/claudemd.md` does NOT have a `/cite` row in the command reference table — this also needs to be added.
- CLAUDE.md is regenerated via `generate_claudemd()` in `merge.lua`, which reads `EXTENSION.md` from each loaded extension. Manually editing `.claude/CLAUDE.md` is NOT the correct approach — updating `EXTENSION.md` (for the literature extension) and `core/merge-sources/claudemd.md` (for the core command table) is sufficient.

## Context & Scope

Task 719 updates manifest.json, EXTENSION.md, and core/merge-sources/claudemd.md to register the /cite command implemented in task 717. The CLAUDE.md at `.claude/CLAUDE.md` is auto-generated and should not be edited directly.

## Findings

### 1. manifest.json — Current State and Needed Changes

**File**: `/home/benjamin/.config/nvim/.claude/extensions/literature/manifest.json`

**Current state**:
```json
{
  "provides": {
    "agents": ["literature-agent.md"],
    "commands": ["literature.md"],
    "skills": ["skill-literature", "skill-cite"],
    "scripts": ["scripts/zotero-search.sh"]
  }
}
```

**What was already done by task 717**: `skill-cite` added to `provides.skills`.

**What is still missing**:
1. `"cite.md"` not in `provides.commands` (file exists at `commands/cite.md`)
2. `"scripts/cite-extract.sh"` not in `provides.scripts` (file exists at `scripts/cite-extract.sh`)

**Required additions**:
```json
"commands": ["literature.md", "cite.md"],
"scripts": ["scripts/zotero-search.sh", "scripts/cite-extract.sh"]
```

### 2. EXTENSION.md — Current State and /cite Section Placement

**File**: `/home/benjamin/.config/nvim/.claude/extensions/literature/EXTENSION.md`

**Current state**: The file documents the Literature Extension with sections on Centralized Repository, Key Conventions, Zotero integration, Skill-Agent Mapping, and Commands. The Commands section has a table for `/literature` subcommands only.

**What is missing**: A `/cite` command section documenting workflow, arguments, and output format.

**Where to add it**: After the existing Commands table (line 64), add a new `### /cite Command` section (or extend the Commands table). Looking at how other extensions document multi-mode commands, the pattern is to add a dedicated subsection after the main commands table.

**Proposed addition** (to be placed after the existing Commands table):

```markdown
### /cite Command

| Command | Usage | Description |
|---------|-------|-------------|
| `/cite` | `/cite N` | Verify citations for task N |
| `/cite` | `/cite N --gaps` | Focus on finding missing citations for task N |
| `/cite` | `/cite N "focus"` | Verify task N with focus text |
| `/cite` | `/cite "text"` | Verify freeform description text |

**Workflow**: Extracts citation patterns from task artifacts, searches `specs/literature/index.json`
and the Zotero library for matches, scores confidence (confirmed/partial/unconfirmed/gap), presents
findings interactively, and creates research tasks for unverified claims.

**Citation patterns detected**: `author_year`, `parenthetical`, `phrase_attribution`,
`theorem_attr`, `direct_quote`, `numeric_bracket`, `alpha_num_bracket`, `latex_cite`.

**Output format**: Grouped table by confidence status. Confirmed citations require no action.
Unconfirmed/gap citations are presented for interactive selection → task creation.
```

### 3. core/merge-sources/claudemd.md — Command Table Location

**File**: `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`

**Current state**: The Command Reference table ends at line 113 with `/literature --task N`. There is no `/cite` row.

**What needs to be added**: Two rows for `/cite` after the `/literature` block (lines 107-113):

```markdown
| `/cite` | `/cite N [--gaps] ["focus"]` | Verify citations for task N against Literature/ index and Zotero |
| `/cite` | `/cite "text"` | Verify freeform text for citation claims |
```

### 4. CLAUDE.md Regeneration Process

**How CLAUDE.md is generated**: Via `generate_claudemd()` in:
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/merge.lua` (line 549)

**Process**:
1. Reads all loaded extensions from state
2. Orders extensions (core first, then others in stable sort order)
3. For each extension with `merge_targets.claudemd`: reads the source file (either `EXTENSION.md` or `merge-sources/claudemd.md` for core)
4. Concatenates fragments and writes to `.claude/CLAUDE.md`

**Trigger**: Called automatically by the extension loader (load/unload operations). Can also be triggered from Neovim via the extension UI.

**Implication for task 719**: 
- Editing `EXTENSION.md` (literature extension) updates what gets included when the literature extension is loaded.
- Editing `core/merge-sources/claudemd.md` updates the core CLAUDE.md content.
- CLAUDE.md itself should NOT be manually edited — it is overwritten on every load.
- To regenerate: open Neovim, use the extension picker to reload the literature extension, or call `M.generate_claudemd()` from Lua.

### 5. Files Already Created by Task 717

All implementation files exist and are ready:

| File | Status |
|------|--------|
| `.claude/extensions/literature/commands/cite.md` | EXISTS — full command spec |
| `.claude/extensions/literature/skills/skill-cite/SKILL.md` | EXISTS — full skill spec |
| `.claude/extensions/literature/scripts/cite-extract.sh` | EXISTS — citation extractor |
| `.claude/extensions/literature/scripts/zotero-search.sh` | EXISTS — Zotero search |
| `.claude/extensions/literature/manifest.json` | PARTIAL — `skill-cite` added, but `cite.md` and `cite-extract.sh` missing |
| `.claude/extensions/literature/EXTENSION.md` | NEEDS UPDATE — no `/cite` section |
| `.claude/extensions/core/merge-sources/claudemd.md` | NEEDS UPDATE — no `/cite` row |

## Decisions

- Do NOT directly edit `.claude/CLAUDE.md` — it is auto-generated from loaded extensions.
- Add `/cite` to the command table in `core/merge-sources/claudemd.md` (not EXTENSION.md's Commands table for core), since this is where the master command reference lives.
- Also add a `/cite` section to `literature/EXTENSION.md` since extension-specific docs belong there.
- Regeneration of CLAUDE.md is triggered via the Neovim extension loader — the implementation task should note this but not attempt to call the Lua function directly from bash.

## Risks & Mitigations

- **Risk**: If CLAUDE.md is edited directly, it will be overwritten on next extension load.
  **Mitigation**: Only edit source files (`EXTENSION.md` and `core/merge-sources/claudemd.md`).
- **Risk**: `provides.commands` and `provides.scripts` in manifest.json control what the extension loader copies/registers — missing entries means the command won't be registered.
  **Mitigation**: Add both `cite.md` and `scripts/cite-extract.sh` to manifest.json.

## Appendix

- Files inspected: `manifest.json`, `EXTENSION.md`, `core/merge-sources/claudemd.md`, `commands/cite.md`, `skills/skill-cite/SKILL.md`, `scripts/cite-extract.sh`
- CLAUDE.md generation code: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/merge.lua:549`
- Core manifest confirming merge_targets pattern: `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json`
