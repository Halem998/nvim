# Phase 6 Results: Create /review Utility Scripts

**Completed**: 2026-05-22
**Phase**: 6 of 8

## Overview

Created three utility scripts by extracting reusable components from the monolithic `/review` command. These scripts are standalone executables that will be consumed by Phase 7 to reduce `review.md` from ~1039L to ~450L.

## Files Created

- `/home/benjamin/.config/nvim/.claude/scripts/issue-grouping.sh` — 214 lines. Implements Steps 5.5.2-5.5.5 from review.md: indicator extraction, clustering algorithm, post-processing (group cap, small-group merging), and scoring.
- `/home/benjamin/.config/nvim/.claude/scripts/roadmap-integration.sh` — 183 lines. Implements Steps 2.5-2.5.3 from review.md: ROADMAP.md parsing, cross-reference with state.json, and annotation of completed items.
- `/home/benjamin/.config/nvim/.claude/scripts/tier-selection.sh` — 178 lines. Implements Steps 5.5.6-5.5.7 from review.md: generates AskUserQuestion JSON for Tier 1 group selection, Tier 2 granularity selection, and Tier 3 manual selection.

## Script Interfaces

### issue-grouping.sh
- **Input**: JSON array of issue objects (stdin or `--file PATH`)
- **Output**: Sorted JSON array of grouped issues with scores to stdout
- **Algorithm preserved**: Primary match (file_section + issue_type), secondary match (2+ shared key_terms + same priority), new group fallback; group cap at 10; small-group (<2 items) merging

### roadmap-integration.sh
- **Input**: `--roadmap PATH --state PATH`
- **Options**: `--annotate` to apply edits; `--dry-run` to preview
- **Output**: JSON with `roadmap_state`, `roadmap_matches`, and `annotation_summary` to stdout
- **Safety**: Skips already-annotated items; one edit per item; only high-confidence matches auto-annotate
- **Auto-creates default ROADMAP.md** if none exists

### tier-selection.sh
- **Input**: JSON array of grouped issues (stdin or `--file PATH`)
- **Modes**: `--mode tier1` (group selection), `--mode tier2 --selected-groups "0,1"` (granularity), `--mode tier3 --selected-groups "0,1"` (manual selection), `--summarize` (plain-text summary)
- **Output**: AskUserQuestion JSON prompt to stdout for caller to execute

## Verification

- All three scripts exist and are executable (`chmod +x` applied)
- `bash -n` passes for all three (syntax check clean)
- `issue-grouping.sh`: correctly groups 4 test issues into 3 groups with correct labels (e.g., "plugins fixes", "Roadmap: Phase 1") and scores
- `roadmap-integration.sh`: parses ROADMAP.md phases/checkboxes correctly; matches completed tasks by title and roadmap_items; applies `- [x]` annotations with `*(Completed: Task N)*` suffix; empty skipped_reasons when no items skipped
- `tier-selection.sh`: generates well-formed AskUserQuestion JSON for all three tiers; handles empty input gracefully with fallback prompt

## Deviations from Plan

- **issue-grouping.sh**: Uses Python 3 for the stateful clustering algorithm (not pure bash/jq) since jq lacks variable mutation. The algorithm logic is preserved verbatim from review.md. Python is available in the execution environment.
- **tier-selection.sh**: Script generates AskUserQuestion prompt JSON rather than executing the interaction directly (as noted in the plan: "This script primarily generates the AskUserQuestion JSON prompts and parses responses"). Caller is responsible for executing the prompt and passing selections back via `--selected-groups`.
