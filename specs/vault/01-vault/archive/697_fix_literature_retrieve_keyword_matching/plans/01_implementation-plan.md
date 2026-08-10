# Implementation Plan: Task #697

**Task**: 697 - Fix literature-retrieve.sh keyword matching and subdirectory search
**Status**: [NOT STARTED]
**Created**: 2026-06-14
**Research Integrated**: specs/697_fix_literature_retrieve_keyword_matching/reports/01_literature-retrieve-research.md

---

## Overview

Fix two issues preventing `--lit` from working in child projects:
1. Add `literature-retrieve.sh` to core extension manifest `provides.scripts` (deployment blocker)
2. Rewrite the script to use `index.json` keyword matching instead of naive file scanning

## Phase 1: Manifest fix + script rewrite [NOT STARTED]

**Effort**: 30-60 minutes
**Files**:
- `.claude/extensions/core/manifest.json` — add 1 line to `provides.scripts`
- `.claude/extensions/core/scripts/literature-retrieve.sh` — full rewrite (~120 lines)
- `.claude/scripts/literature-retrieve.sh` — sync copy from extension core

### Step 1.1: Add literature-retrieve.sh to core manifest

Edit `.claude/extensions/core/manifest.json`, add `"literature-retrieve.sh"` to the `provides.scripts` array in alphabetical position (after `"link-artifact-todo.sh"`, before `"manage-topics.sh"`).

### Step 1.2: Rewrite literature-retrieve.sh

Rewrite `.claude/extensions/core/scripts/literature-retrieve.sh` following the `memory-retrieve.sh` pattern:

**Structure**:
1. Parse args (`$1` = description, `$2` = task_type), set up paths
2. Exit 1 if `specs/literature/` does not exist
3. If `index.json` exists: keyword-matching path
   - Extract keywords from `"$description $task_type"`: lowercase, split on non-alpha, remove stop words, filter length > 3, deduplicate, top 10
   - Score index.json entries via jq: count keyword overlap against entry `keywords` array
   - Filter entries with score >= MIN_SCORE=1
   - Sort by descending score
   - Greedy-select within TOKEN_BUDGET=4000 and MAX_FILES=10 using jq reduce
   - Read selected files, output `<literature-context>` block
4. If `index.json` absent: fallback path
   - Recursive find (no `-maxdepth 1`) for `.md`/`.txt` files
   - Same token budget/max files enforcement as current script
   - Output `<literature-context>` block

**Interface contract** (unchanged):
- Input: `$1` = description, `$2` = task_type
- Output: stdout `<literature-context>` block on success
- Exit 0 on success, exit 1 on no content

### Step 1.3: Sync to live scripts directory

Copy `.claude/extensions/core/scripts/literature-retrieve.sh` to `.claude/scripts/literature-retrieve.sh`. Verify byte-identical with `diff`.

### Step 1.4: Verify

1. Test with cslib's index.json: `bash .claude/scripts/literature-retrieve.sh "modal logic completeness" "lean4"` — should return matching entries
2. Test fallback: `bash .claude/scripts/literature-retrieve.sh "test" "general"` with no index.json present — should scan recursively
3. Test empty directory: should exit 1 with no output
4. Verify manifest: `jq '.provides.scripts | index("literature-retrieve.sh")' .claude/extensions/core/manifest.json` — should return non-null

## Dependencies

None.

## Preserved Assets

- Calling convention in 3 skills (skill-researcher, skill-planner, skill-implementer) — do not modify
- `specs/literature/index.json` schema — read-only, do not modify
