# Research Report: Task #475

**Task**: Review extension documentation and manifests
**Date**: 2026-04-17
**Mode**: Team Research (4 teammates)
**Session**: sess_1776444885_b6f071

## Summary

Systematic audit of all 16 extensions in `.claude/extensions/`. All extensions have the required triple (README.md, EXTENSION.md, manifest.json). Only 1/16 fails the automated doc-lint script (founder, missing `/consult`). However, deeper analysis reveals stale content, style inconsistencies, undocumented fields, and a critical misunderstanding in the task description about what `routing_exempt` actually does.

## Key Findings

### Critical: Task Description Misunderstands `routing_exempt`

**All 4 teammates independently confirmed**: The task description states `routing_exempt` should "avoid loading any files that should not be loaded by the `<leader>ac` picker." This is incorrect on two counts:

1. **`routing_exempt` is doc-lint only** -- It is consumed exclusively by `check-extension-docs.sh` (lines 113-117) to skip the routing block validation. Zero Lua files reference it. The extension picker (`list_extensions()` in `manifest.lua`) lists all subdirectories unconditionally.

2. **`<leader>ac` is the wrong picker** -- `<leader>ac` maps to `:ClaudeCommands` (commands browser), not `:ClaudeExtensions` (extension management picker). Verified in `which-key.lua:250`.

**Recommendation**: Clarify `routing_exempt` as a validator-exemption flag. If picker filtering is genuinely wanted, that requires a separate feature (e.g., `picker_hidden: true`) -- not overloading this flag.

### P1 -- Fix Script Failure: founder `/consult` (all teammates confirm)

The only `check-extension-docs.sh` failure: `/consult` command in manifest but absent from README. The command and skill exist on disk. Additionally:
- README says "eight commands" but manifest has 10 (missing `/consult` and stale count after `/meeting` was added)
- Architecture tree omits `consult.md`, `meeting.md` from commands listing
- Architecture tree omits 3 agents: `financial-analysis-agent.md`, `meeting-agent.md`, `legal-analysis-agent.md`
- Architecture tree uses stale names: `skill-spreadsheet/` (actual: `skill-founder-spreadsheet/`), `spreadsheet-agent.md` (actual: `founder-spreadsheet-agent.md`)

### P1 -- Document `routing_exempt` in Extension Development Guide

`extension-development.md` manifest field table omits `routing_exempt` entirely. New extension authors won't know it exists. This is the most important documentation gap -- the guide that future authors read has no knowledge of a flag that affects the validator they will encounter.

Additionally, the guide references "See `extensions/template/` for a minimal extension structure" but no `template/` directory exists.

### P2 -- Fix Stale Content: memory README

Memory README (line 25) says: *"Memories are NOT automatically injected... You must pass `--remember` explicitly."* Both EXTENSION.md and CLAUDE.md describe the current model: automatic preflight injection via `memory-retrieve.sh`, suppressed with `--clean`. The script exists at `.claude/scripts/memory-retrieve.sh`. The README documents a superseded manual design.

### P2 -- Fix Stale References: nix README

Two `@`-references point to nonexistent files:
- `patterns/modules.md` -- actual: `patterns/module-patterns.md`
- `tools/nixos-rebuild.md` -- actual: `tools/nixos-rebuild-guide.md`

The doc-lint script does NOT catch this (it only validates `provides.*` entries, not README body content).

### P2 -- Fix Stale Content: extensions/README.md

The root `extensions/README.md` lists only 8 of 16 extensions. Missing: core, epidemiology, filetypes, formal, founder, memory, present, slidev.

### P3 -- Improve Completeness: present README

At 88 lines, `present` README is thin relative to its complexity (6 routing keys, MCP server, slidev dependency). Missing: Architecture, Skill-Agent Mapping, Language Routing, Workflow, Output Artifacts sections. The content exists in EXTENSION.md but is not mirrored in README.md. Comparable extensions (lean 192, nix 186, web 168 lines) all include these sections.

### P3 -- Style Consistency Gaps

Three extensions use non-standard README structures:
- **epidemiology**: Uses "Command" (singular), "Compound Routing", "File Inventory" instead of standard headers
- **memory**: Uses "Navigation"/"Subdirectories" pattern from nvim documentation-policy instead of extension template
- **founder**: Has "What's New in v3.0" changelog section (belongs in CHANGE_LOG, not README)

### P3 -- Add `routing_exempt: true` to slidev

Slidev is a resource-only extension (no task_type, no skills, no routing) -- structurally identical to core's infrastructure-only pattern. It currently passes validation coincidentally (0 skills means no routing block check triggers). Adding the flag documents intent and ensures consistency.

### P4 -- EXTENSION.md Slim Standard Violations

Two extensions exceed the 60-line EXTENSION.md limit from `extension-slim-standard.md`:
- `nix`: 62 lines (+2)
- `present`: 64 lines (+4)

The slim standard is not enforced by `check-extension-docs.sh`. Both violations are minor and fixable with minimal trimming.

## Synthesis

### Conflicts Resolved

No conflicts between teammates. All 4 independently identified the same core issues (routing_exempt misunderstanding, founder /consult failure, extension-development.md gap). Findings are complementary rather than contradictory.

### Gaps Identified

1. **Doc-lint coverage gaps** -- The script does not validate: `context/`, `hooks/`, `data/`, `templates/` entries in manifest `provides`; README body `@`-references; EXTENSION.md size; cross-extension dependency cross-references
2. **No template directory** -- `extension-development.md` references a non-existent `extensions/template/`
3. **Index.json coverage** -- Only 3 extensions (memory, neovim, nix) have entries in the live `index.json`; others use lazy-loaded `index-entries.json` (architecturally correct but limits offline discovery)

### Recommendations

**Must Do (resolves all lint failures and critical doc gaps)**:
1. Fix founder README: add `/consult`, update command count, fix architecture tree
2. Add `routing_exempt` to `extension-development.md` manifest field table
3. Fix memory README: replace `--remember` with auto-retrieval model
4. Fix nix README: correct two broken `@`-references
5. Update extensions/README.md: add all 16 extensions

**Should Do (consistency and completeness)**:
6. Add `routing_exempt: true` to slidev manifest
7. Expand present README with missing sections
8. Consistency sweep of epidemiology/memory README structure vs template
9. Remove stale `extensions/template/` reference from extension-development.md

**Could Do (hardens standards infrastructure)**:
10. Add EXTENSION.md size check to `check-extension-docs.sh`
11. Trim nix/present EXTENSION.md to 60-line limit
12. Add `@`-reference validation to doc-lint script
13. Consider CI integration of doc-lint (roadmap Phase 1 item)

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary audit | completed | high | Per-extension systematic audit, priority classification |
| B | Cross-linking | completed | high | Style analysis, index.json coverage, nix broken refs |
| C | Critic | completed | high | routing_exempt code verification, scope assessment, stale tree names |
| D | Horizons | completed | high | Roadmap alignment, EXTENSION.md slim violations, strategic priorities |

## References

- `.claude/scripts/check-extension-docs.sh` -- Doc-lint validation script
- `.claude/context/guides/extension-development.md` -- Extension authoring guide
- `.claude/extensions/core/templates/extension-readme-template.md` -- README template
- `.claude/docs/reference/standards/extension-slim-standard.md` -- EXTENSION.md size standard
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` -- Lua extension loader (no routing_exempt refs)
