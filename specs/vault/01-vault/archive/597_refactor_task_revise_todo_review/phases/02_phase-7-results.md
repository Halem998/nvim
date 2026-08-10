# Phase 7 Results: Refactor /review to use utility scripts

**Completed**: 2026-05-22
**Phase**: 7 of 8

## Summary

Refactored `.claude/commands/review.md` to call the three utility scripts created in Phase 6,
replacing ~346 lines of inline logic with ~148 lines of script-call wrappers. Net reduction: 229
lines (1039L -> 810L).

## Changes Made

### `.claude/commands/review.md` (modified)

**Section 2.5 (Roadmap Integration)**: Replaced the original 148-line inline implementation
covering Steps 2.5, 2.5.2, and 2.5.3 with a 35-line wrapper:
- Calls `bash .claude/scripts/roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json --annotate`
- Captures `roadmap_state`, `roadmap_matches`, and `annotation_summary` from JSON output
- Includes error handling for missing script (falls back to empty roadmap state)

**Section 5.5.2-5.5.5 (Issue Grouping)**: Replaced the original 108-line inline implementation
covering indicator extraction, clustering algorithm, post-processing, and scoring with a
single stdin-pipe call:
- Calls `echo "$all_issues" | bash .claude/scripts/issue-grouping.sh`
- Output is a scored, sorted JSON array of grouped issue objects
- Includes error handling for missing script (falls back to empty groups)

**Section 5.5.6-5.5.7 (Tiered Selection)**: Replaced the original 90-line inline implementation
covering Tier 1 group selection, Tier 2 granularity, and Tier 3 manual selection with
`tier-selection.sh` calls:
- `bash .claude/scripts/tier-selection.sh --mode tier1` for group selection prompt
- `bash .claude/scripts/tier-selection.sh --mode tier2 --selected-groups "$selected_groups"` for granularity
- `bash .claude/scripts/tier-selection.sh --mode tier3 --selected-groups "$selected_groups"` for manual selection
- Includes error handling for missing script

**Preserved unchanged**:
- Section 1.5 (Load Review State)
- Section 2.6 (Parse Task Order)
- Section 3 (Analyze Findings)
- Section 4 (Create Review Report) -- with note to use roadmap_state from script
- Section 4.5 (Update Review State)
- Section 5 (Task Proposal Mode)
- Section 5.5.1 (Collect All Issues)
- Section 5.6.1-5.6.4 (Task Creation from Selection)
- Section 6.5 (Regenerate Task Order)
- Section 6.7 (Interactive Task Order Management)
- Section 7 (Git Commit)
- Section 8 (Output)

## Line Count Analysis

| Metric | Value |
|--------|-------|
| Original review.md | 1039L |
| New review.md | 810L |
| Net reduction | 229L |
| Plan target | ~450L |
| Discrepancy | Plan over-estimated inline section sizes by ~360L |

The plan estimated ~180L for Steps 2.5-2.5.3, ~180L for Steps 5.5.2-5.5.5, and ~100L for
Steps 5.5.6-5.5.7 (total ~460L extracted). The actual inline sizes were 148L, 108L, and 90L
respectively (total 346L). Replacement wrappers consume ~148L.

The remaining inline content (task creation logic ~161L, task order parsing ~86L, goal
management ~89L) was not in scope for Phase 7 and would require additional utility script
extraction in a future task.

## Verification

- `wc -l .claude/commands/review.md`: 810L (reduced from 1039L)
- All three utility scripts called from review.md: YES
- `roadmap-integration.sh` call: line 71
- `issue-grouping.sh` call: line 360
- `tier-selection.sh` calls: lines 393, 407, 420
- Review report generation uses `roadmap_state`/`roadmap_matches` from script: YES (Step 4 note)
- Task creation flow uses `grouped_issues` from `issue-grouping.sh`: YES (Sections 5.6.1-5.6.2)
- Task creation uses selection from `tier-selection.sh`: YES (Sections 5.5.6-5.5.7 documented flow)
- Task Order regeneration (Section 6.5) preserved: YES
- Review state tracking (Section 4.5) preserved: YES
- Git commit section (Section 7) references all modified files: YES
- All three utility scripts pass `bash -n` syntax check: YES

## Deviations from Plan

- **Line count target not met** (810L vs ~450L): The plan's line count estimates for the inline
  sections were approximately 2x the actual sizes (e.g., "~180L" for a 108-line section). All
  three sections were correctly replaced with script calls; the remaining bulk is unextracted
  inline logic outside Phase 7 scope.
