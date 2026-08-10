# Implementation Summary: Task #122

**Completed**: 2026-03-03
**Duration**: Approximately 2 hours

## Changes Made

Renamed the `document-converter` extension to `filetypes` and expanded it with specialized sub-agents for spreadsheet operations (Excel/CSV/ODS to LaTeX/Typst tables), presentation operations (PowerPoint to Beamer/Polylux/Touying), and general document operations. Implemented router agent architecture with format detection and delegation to specialized agents. Created new `/table` and `/slides` commands for targeted conversion workflows. Maintained full parity between `.claude/` and `.opencode/` extension systems.

## Files Created

### .claude/extensions/filetypes/

| File | Description |
|------|-------------|
| `manifest.json` | Extension manifest with updated provides section |
| `EXTENSION.md` | Extension documentation with skill-agent mapping |
| `index-entries.json` | Context index entries for lazy loading |
| `agents/filetypes-router-agent.md` | Router agent for format detection and delegation |
| `agents/document-agent.md` | Document conversion agent (renamed from document-converter-agent) |
| `agents/spreadsheet-agent.md` | Spreadsheet to table conversion agent |
| `agents/presentation-agent.md` | Presentation extraction and slide generation agent |
| `skills/skill-filetypes/SKILL.md` | Primary routing skill |
| `skills/skill-spreadsheet/SKILL.md` | Spreadsheet conversion skill |
| `skills/skill-presentation/SKILL.md` | Presentation conversion skill |
| `commands/convert.md` | /convert command (updated to use skill-filetypes) |
| `commands/table.md` | /table command for spreadsheet to table conversion |
| `commands/slides.md` | /slides command for presentation conversion |
| `context/project/filetypes/README.md` | Context documentation overview |
| `context/project/filetypes/tools/tool-detection.md` | Shared tool detection patterns |
| `context/project/filetypes/tools/dependency-guide.md` | Platform-specific installation (NixOS, apt, brew) |
| `context/project/filetypes/tools/mcp-integration.md` | MCP server integration documentation |
| `context/project/filetypes/patterns/spreadsheet-tables.md` | Spreadsheet to LaTeX/Typst patterns |
| `context/project/filetypes/patterns/presentation-slides.md` | Presentation extraction patterns |

### .opencode/extensions/filetypes/

Mirror of all `.claude/` files with OpenCode-compatible paths and merge targets.

## Files Removed

- `.claude/extensions/document-converter/` (entire directory)
- `.opencode/extensions/document-converter/` (entire directory)

## Files Modified

| File | Change |
|------|--------|
| `.claude/CLAUDE.md` | Updated skill reference from document-converter to filetypes |
| `.claude/README.md` | Updated skill reference from document-converter to filetypes |
| `.claude/docs/guides/component-selection.md` | Updated skill/agent references |
| `.claude/docs/guides/creating-agents.md` | Updated agent references |
| `.claude/docs/architecture/system-overview.md` | Updated skill references |
| `.opencode/OPENCODE.md` | Updated skill-agent mapping |
| `.opencode/docs/guides/component-selection.md` | Updated skill/agent references |
| `.opencode/docs/parity-summary.md` | Updated agent/skill names |
| `.opencode/context/core/patterns/skill-lifecycle.md` | Updated skill references |
| `.opencode/agent/subagents/README.md` | Updated agent references |

## Verification

- [x] Manifest schema validation: All provides entries correspond to existing files
- [x] Agent reference validation: All agent names in skills and commands match agent file names
- [x] Context link validation: All internal links in context files resolve correctly
- [x] Old name cleanup: Zero references to `document-converter` in both codebases
- [x] OpenCode parity: `.opencode/extensions/filetypes/` mirrors `.claude/extensions/filetypes/`
- [x] All 19 files created in .claude extension
- [x] All 19 files created in .opencode extension

## Architecture Summary

```
/convert -> skill-filetypes -> filetypes-router-agent -> document-agent
                                                      -> spreadsheet-agent (for XLSX)
                                                      -> presentation-agent (for PPTX)

/table -> skill-spreadsheet -> spreadsheet-agent

/slides -> skill-presentation -> presentation-agent
```

## Notes

- Task 121 (remove extension-specific skills from core) was completed before this task
- Tool detection patterns are shared via `tool-detection.md` to avoid retroactive updates
- NixOS installation instructions are provided as the primary method per research findings
- Future work items (Typst/LaTeX slide context files, round-trip conversions) are documented in the plan
