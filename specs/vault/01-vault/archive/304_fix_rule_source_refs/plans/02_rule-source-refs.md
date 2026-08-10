# Implementation Plan: Fix Malformed @-references in Extension Rule Source Files

**Task**: 304
**Date**: 2026-03-26
**Status**: [COMPLETED]

## Overview

Fix 13 malformed @-references in 2 extension rule source files (nix.md and web-astro.md) that use wrong path prefixes pointing to extension source directories instead of installed context paths.

## Phase 1: Fix References [COMPLETED]

### Step 1: Fix nix.md (8 refs)
- **File**: `.claude/extensions/nix/rules/nix.md`
- **Action**: Replace `@.claude/extensions/nix/context/project/nix/` with `@.claude/context/project/nix/` across all 8 occurrences (lines 222-229)

### Step 2: Fix web-astro.md (5 refs)
- **File**: `.claude/extensions/web/rules/web-astro.md`
- **Action**: Replace `@.claude/extensions/web/context/project/web/` with `@.claude/context/project/web/` across all 5 occurrences (lines 218-222)

## Phase 2: Verify [COMPLETED]

- Grep for remaining `extensions/nix/context` and `extensions/web/context` patterns in rule files
- Confirm zero matches (all fixed)

## Notes

- neovim-lua.md already uses correct paths (3 refs verified OK, no changes needed)
- The pattern is consistent: remove the `extensions/{ext}/` segment from the path
