# Teammate C: Critic Findings - Extension Docs Review

**Task**: 475 - Review extension documentation and manifests
**Role**: Critic - gaps, blind spots, and assumption validation
**Date**: 2026-04-17

---

## Key Findings (Most Critical Gaps)

### 1. CRITICAL: `routing_exempt` Is Only a Doc-Lint Flag, Not a Loader Flag

The task description states that `routing_exempt` should "avoid loading any files that should not be loaded by the `<leader>ac` picker in neovim." This assumption is **incorrect**.

Investigation findings:
- `routing_exempt` is consumed **only** by `.claude/scripts/check-extension-docs.sh` (lines 113-117)
- The Lua extension system (`lua/neotex/plugins/ai/shared/extensions/manifest.lua`, `init.lua`, `loader.lua`) has **zero references** to `routing_exempt`
- The picker (`<leader>ac`) is `:ClaudeCommands` (the commands picker), NOT `:ClaudeExtensions` (the extension management picker)
- `:ClaudeExtensions` is available via command only - no dedicated keymap per `lua/neotex/plugins/ai/shared/README.md`
- The extension loader does not filter any extensions from appearing in the picker based on `routing_exempt`

**What `routing_exempt` actually does**: Skips the `check_routing_block()` validation in the doc-lint script. Extensions with `routing_exempt: true` are not required to have a `routing` block in their manifest even if they declare skills. Only `core` has this flag set.

**Implication**: The task description's framing "to avoid loading any files that should not be loaded by the `<leader>ac` picker" reflects a misunderstanding of what the flag does. The review should clarify what `routing_exempt` actually controls and whether any other extensions should have it set.

### 2. CONFIRMED FAILURE: founder extension `/consult` command not in README

The doc-lint script (`check-extension-docs.sh`) produces exactly **1 failure**:
```
[founder] FAIL: command /consult listed in manifest but not mentioned in README.md
```

The `/consult` command exists on disk (`commands/consult.md`) and has a corresponding `skill-consult` skill (`skills/skill-consult/SKILL.md`), but is completely absent from `founder/README.md`. The README documents 9 commands (market, analyze, strategy, legal, project, deck, finance, sheet, meeting) but omits consult entirely, including from the commands table, the Architecture file tree, and the detailed command reference sections.

### 3. `routing_exempt` Not Documented in Extension Development Guide

The `extension-development.md` guide (`.claude/context/guides/extension-development.md`) does not mention `routing_exempt` at all. The field exists in `core/manifest.json` and is consumed by the doc-lint script, but there is no authoritative documentation explaining:
- What `routing_exempt` does
- When to use it
- Which extensions should use it
- How it interacts with the validator

---

## Assumption Validation

| Assumption | Status | Evidence |
|------------|--------|----------|
| `routing_exempt` controls picker visibility | **FALSE** | No Lua code references `routing_exempt`; it's doc-lint only |
| `<leader>ac` opens the extension picker | **FALSE** | `<leader>ac` maps to `:ClaudeCommands` (commands picker), not `:ClaudeExtensions` |
| All extensions have README.md | **TRUE** | All 16 extension directories have README.md |
| All extensions have EXTENSION.md | **TRUE** | All 16 extension directories have EXTENSION.md |
| All extensions have manifest.json | **TRUE** | All 16 extension directories have manifest.json |
| Manifest agent entries exist on disk | **TRUE for all except** founder has no "consult" agent (skill-consult exists, but no consult agent; routing uses existing agents) |
| Manifest skill entries exist on disk | **TRUE** | All skills have SKILL.md files including `skill-consult` |
| Manifest context entries exist on disk | **TRUE** | All context paths are present |

---

## Stale Content Issues

### founder/README.md - Missing /consult

The `founder/README.md` (v3.0) documents the "What's New in v3.0" section listing 8 commands but the manifest declares 10 commands including `consult.md` and `meeting.md`. The README overview table lists 9 commands but is missing `/consult`. The Architecture file tree (`commands/` section) also omits `consult.md`.

This is a genuine stale content issue: the README was not updated when `/consult` was added.

### founder/README.md - Stale Architecture Tree (Agent/Skill Names)

The architecture tree in `founder/README.md` (lines 252, 269, 340) uses wrong names:
- Lists `skill-spreadsheet/` — actual directory is `skill-founder-spreadsheet/`
- Lists `spreadsheet-agent.md` — actual file is `founder-spreadsheet-agent.md`

Additionally, the architecture tree omits three skill directories that exist on disk and in the manifest: `skill-consult/`, `skill-meeting/`, and `skill-financial-analysis/`. The manifest declares 15 skills but the README architecture only documents 12.

### nix/README.md - Two @-References Point to Nonexistent Files

`nix/README.md` lines 177–178 reference files that do not exist at those paths:

| README reference | Actual file on disk |
|---|---|
| `.../patterns/modules.md` | `patterns/module-patterns.md` |
| `.../tools/nixos-rebuild.md` | `tools/nixos-rebuild-guide.md` |

Files were renamed (with descriptive suffixes) but the README was not updated. The doc-lint
script does NOT detect this because `check_manifest_entries()` only validates `provides.*`
entries — it does not parse README body content for `@`-references.

**Impact**: These are agent-context @-refs. If agents load the README as context and attempt
to dereference these paths, they'll fail silently (file not found). The correct paths are
`patterns/module-patterns.md` and `tools/nixos-rebuild-guide.md`.

### extensions/README.md - Incomplete Extension Table

The root `extensions/README.md` lists only 8 extensions in its "Available Extensions" table (nvim, lean, latex, typst, python, nix, web, z3) but there are 16 extension directories. Missing from the table: core, epidemiology, filetypes, formal, founder, memory, present, slidev, z3. This file appears significantly out of date.

### extension-development.md - Missing `routing_exempt` Documentation

The extension development guide's "Manifest Fields" table has 8 documented fields but omits `routing_exempt`. If the flag is meaningful, it needs documentation here.

---

## Scope Assessment

### What the doc-lint script checks (current scope)
- Required files: `manifest.json`, `EXTENSION.md`, `README.md` per extension
- Manifest entry validation: agents, skills, commands, rules, scripts must exist on disk
- Routing block requirement: extensions with skills must have `routing` (unless `routing_exempt`)
- README-manifest cross-reference: commands in manifest must be mentioned in README

### What the doc-lint script does NOT check
- Whether `context` entries in `provides` exist on disk (only agents, skills, commands, rules, scripts are checked)
- Whether `data` entries in `provides` exist on disk
- Whether `hooks` entries in `provides` exist on disk
- Whether `docs` entries in `provides` exist on disk
- Whether `templates` entries in `provides` exist on disk
- Cross-linking between extensions (e.g., dependency README cross-references)
- Internal consistency within README (e.g., does the architecture section match the commands section)
- Whether EXTENSION.md content is consistent with README.md
- Whether `index-entries.json` files reference paths that exist
- Whether `@`-references in README body content resolve to real files (the nix stale refs above passed the check script)

### Should the review scope include rules/, agents/, skills/ within extensions?

The doc-lint script validates that the *manifest entries* for these exist on disk, but it does not check:
- Content quality of agent files
- SKILL.md content completeness
- Whether agent names in README match actual agent filenames
- Whether skill descriptions match implementations

For task 475's stated goal ("complete, accurate, and consistent" documentation), reviewing the content of individual agent/skill files is arguably in scope but would be a much larger effort.

---

## Unanswered Questions

1. **Should `routing_exempt` be added to other extensions?** The only use case is "extension provides skills but handles routing through hardcoded orchestrator logic." Is there any extension besides `core` that fits this pattern? If not, `routing_exempt` is a single-use field.

2. **What does `routing_exempt` actually mean for the `<leader>ac` picker?** The task description's intent may have been about something different - perhaps preventing certain extensions from appearing in `:ClaudeExtensions` picker. Currently, no filtering by `routing_exempt` exists at the Lua level. Should it be added?

3. **Who owns the root `extensions/README.md`?** It's significantly out of date (8 of 16 extensions listed). Should it be auto-generated or manually maintained?

4. **Is the `founder` `/consult` command a new addition or an omission from the v3.0 rewrite?** The README's "What's New in v3.0" section mentions "Unified Phased Workflow: All 8 commands" - but there are actually 10 commands (consult and meeting added later?). This needs author clarification.

5. **Should extensions without `task_type` (like `slidev`) need a routing block check?** Currently they pass because `skill_count` would be 0. But should they declare `routing_exempt: true` explicitly for clarity?

6. **Is there a template extension?** The `extension-development.md` references "See `extensions/template/` for a minimal extension structure" but there is no `template` directory in `.claude/extensions/`.

---

## Confidence Level

**High** for:
- `routing_exempt` is doc-lint only (verified by exhaustive grep of all Lua files)
- `<leader>ac` maps to ClaudeCommands not ClaudeExtensions (verified in which-key.lua:250)
- founder `/consult` doc failure (confirmed by running check-extension-docs.sh)
- All 16 extensions have README.md, EXTENSION.md, manifest.json (verified)
- extensions/README.md is out of date (verified: 8/16 extensions listed)

**Medium** for:
- `extension-development.md` template reference to non-existent `extensions/template/` (may have been removed)
- Whether `consult` is a recent addition or long-standing omission
