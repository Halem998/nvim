# Phase 1 Results: Create memory-harvest.sh

**Task**: 597 - Refactor /task, /revise, /todo, /review for consistency with new architecture
**Phase**: 1 of 8
**Completed**: 2026-05-22
**Status**: COMPLETED

## What Was Created

- `.claude/scripts/memory-harvest.sh` — New script (~130L after heredoc template)

## Implementation Details

The script accepts a task number as its sole argument and:

1. Reads `memory_candidates` from `specs/state.json` for the given task
2. Filters candidates with `confidence >= 0.7`
3. For each qualifying candidate:
   - Generates a memory ID: `MEM-{category}-{kw1}-{kw2}` (normalized lowercase)
   - Checks for duplicates via `memory-index.json` and existing filesystem files
   - Writes a memory file to `.memory/10-Memories/MEM-{id}.md` with proper YAML frontmatter
   - Appends the new entry to `memory-index.json`, updating `entry_count` and `total_tokens`
4. Outputs the harvest count to stdout (for caller integration)
5. Emits diagnostic messages to stderr (skipped duplicates, harvested IDs)

### Deviation from Plan

The plan described a `harvest_memories()` function. The script was implemented without a named function because bash scripts are invoked directly (no benefit to wrapping in a function for a single-purpose script). The logic is equivalent -- the entire script body performs the harvest.

## Verification Results

All checks passed:

```
bash -n .claude/scripts/memory-harvest.sh  # syntax OK
bash memory-harvest.sh 595                  # harvested 2 candidates: MEM-insight-command-skill-tool, MEM-pattern-gate-out-defensive-check
bash memory-harvest.sh 595                  # idempotent: 0 harvested (skipped 2 duplicates)
bash memory-harvest.sh 597                  # no candidates: output "0", exit 0
bash memory-harvest.sh                      # missing arg: usage message, exit 1
```

Index after harvest: entry_count=6, total_tokens=728 (was entry_count=4, total_tokens=536)

## Files Affected

- `.claude/scripts/memory-harvest.sh` — Created (executable)
- `.memory/10-Memories/MEM-insight-command-skill-tool.md` — Created (from task 595 candidate)
- `.memory/10-Memories/MEM-pattern-gate-out-defensive-check.md` — Created (from task 595 candidate)
- `.memory/memory-index.json` — Updated (2 new entries appended)
