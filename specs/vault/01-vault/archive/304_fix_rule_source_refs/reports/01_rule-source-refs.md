# Research Report: Malformed @-references in Extension Rule Source Files

**Task**: 304 -- Fix malformed @-references in extension rule source files
**Date**: 2026-03-26
**Status**: Complete

## Summary

Three extension rule source files contain @-references that use incorrect path prefixes. When the extension loader copies these rules to a target project, the @-references must resolve against the target project's `.claude/context/` directory (where context files are installed), not against the source extension directory structure.

**Correct pattern**: `@.claude/context/project/{domain}/...`
**Incorrect patterns**: `@.claude/extensions/{ext}/context/project/{domain}/...`

## File Analysis

### 1. neovim-lua.md

**Source**: `.claude/extensions/nvim/rules/neovim-lua.md`
**References found**: 3 (lines 145-147)

| Line | Current Reference | Correct Reference | Status |
|------|-------------------|-------------------|--------|
| 145 | `@.claude/context/project/neovim/standards/lua-style-guide.md` | `@.claude/context/project/neovim/standards/lua-style-guide.md` | CORRECT |
| 146 | `@.claude/context/project/neovim/patterns/plugin-spec.md` | `@.claude/context/project/neovim/patterns/plugin-spec.md` | CORRECT |
| 147 | `@.claude/context/project/neovim/patterns/keymap-patterns.md` | `@.claude/context/project/neovim/patterns/keymap-patterns.md` | CORRECT |

**Finding**: All 3 references already use the correct installed path pattern. No changes needed.

**Verification**: All 3 target files exist in the extension source:
- `.claude/extensions/nvim/context/project/neovim/standards/lua-style-guide.md` -- EXISTS
- `.claude/extensions/nvim/context/project/neovim/patterns/plugin-spec.md` -- EXISTS
- `.claude/extensions/nvim/context/project/neovim/patterns/keymap-patterns.md` -- EXISTS

### 2. nix.md

**Source**: `.claude/extensions/nix/rules/nix.md`
**References found**: 8 (lines 222-229)

| Line | Current Reference | Correct Reference | Target Exists |
|------|-------------------|-------------------|---------------|
| 222 | `@.claude/extensions/nix/context/project/nix/domain/nix-language.md` | `@.claude/context/project/nix/domain/nix-language.md` | YES |
| 223 | `@.claude/extensions/nix/context/project/nix/domain/flakes.md` | `@.claude/context/project/nix/domain/flakes.md` | YES |
| 224 | `@.claude/extensions/nix/context/project/nix/domain/nixos-modules.md` | `@.claude/context/project/nix/domain/nixos-modules.md` | YES |
| 225 | `@.claude/extensions/nix/context/project/nix/domain/home-manager.md` | `@.claude/context/project/nix/domain/home-manager.md` | YES |
| 226 | `@.claude/extensions/nix/context/project/nix/patterns/module-patterns.md` | `@.claude/context/project/nix/patterns/module-patterns.md` | YES |
| 227 | `@.claude/extensions/nix/context/project/nix/patterns/overlay-patterns.md` | `@.claude/context/project/nix/patterns/overlay-patterns.md` | YES |
| 228 | `@.claude/extensions/nix/context/project/nix/patterns/derivation-patterns.md` | `@.claude/context/project/nix/patterns/derivation-patterns.md` | YES |
| 229 | `@.claude/extensions/nix/context/project/nix/standards/nix-style-guide.md` | `@.claude/context/project/nix/standards/nix-style-guide.md` | YES |

**Finding**: All 8 references use `@.claude/extensions/nix/context/project/nix/...` but should use `@.claude/context/project/nix/...`. The `extensions/nix/context/` prefix is wrong -- it references the source location rather than the installed location.

### 3. web-astro.md

**Source**: `.claude/extensions/web/rules/web-astro.md`
**References found**: 5 (lines 218-222)

| Line | Current Reference | Correct Reference | Target Exists |
|------|-------------------|-------------------|---------------|
| 218 | `@.claude/extensions/web/context/project/web/domain/astro-framework.md` | `@.claude/context/project/web/domain/astro-framework.md` | YES |
| 219 | `@.claude/extensions/web/context/project/web/domain/tailwind-v4.md` | `@.claude/context/project/web/domain/tailwind-v4.md` | YES |
| 220 | `@.claude/extensions/web/context/project/web/patterns/astro-component.md` | `@.claude/context/project/web/patterns/astro-component.md` | YES |
| 221 | `@.claude/extensions/web/context/project/web/patterns/accessibility-patterns.md` | `@.claude/context/project/web/patterns/accessibility-patterns.md` | YES |
| 222 | `@.claude/extensions/web/context/project/web/standards/performance-standards.md` | `@.claude/context/project/web/standards/performance-standards.md` | YES |

**Finding**: All 5 references use `@.claude/extensions/web/context/project/web/...` but should use `@.claude/context/project/web/...`. Same issue as nix.md.

## Summary of Findings

| File | Total Refs | Broken | Already Correct |
|------|-----------|--------|-----------------|
| neovim-lua.md | 3 | 0 | 3 |
| nix.md | 8 | 8 | 0 |
| web-astro.md | 5 | 5 | 0 |
| **Total** | **16** | **13** | **3** |

**Note**: The original task description stated 16 broken references across 3 files (3 + 8 + 5). Investigation shows that the 3 neovim-lua.md references already use the correct `@.claude/context/project/neovim/...` pattern. Only **13 references** in 2 files (nix.md and web-astro.md) are actually malformed.

## Recommendation

Fix all 13 malformed references in 2 source files by removing the `extensions/{ext}/context/` prefix segment:
- `@.claude/extensions/nix/context/project/nix/...` -> `@.claude/context/project/nix/...`
- `@.claude/extensions/web/context/project/web/...` -> `@.claude/context/project/web/...`

The neovim-lua.md file requires no changes.

## Effort Estimate

~30 minutes (simple find-and-replace in 2 files, 13 line edits total).
