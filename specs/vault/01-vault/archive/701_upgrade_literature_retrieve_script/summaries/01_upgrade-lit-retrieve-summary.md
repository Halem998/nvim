# Implementation Summary: Task #701

**Completed**: 2026-06-14
**Duration**: ~30 minutes

## Overview

Upgraded `literature-retrieve.sh` with three targeted improvements: configurable TOKEN_BUDGET from root `index.json` with 8000 default (fixing the previous 4000 hardcode that mismatched CLAUDE.md documentation and ignored declared budgets like BimodalLogic's 40000), recursive subdirectory `index.json` discovery that normalizes `chapters[]` arrays to `entries[]` shape, and a unified merged entry pool with root-wins deduplication before keyword scoring. Both copies of the script are now byte-identical.

## What Changed

- `.claude/extensions/core/scripts/literature-retrieve.sh` — Upgraded primary script: default TOKEN_BUDGET changed from 4000 to 8000, dynamic budget read from index.json, subdirectory discovery loop, chapters[] normalization, merged entry pool with deduplication, scoring now operates on all_entries instead of inline .entries read
- `.claude/scripts/literature-retrieve.sh` — Sync copy; byte-identical to extensions/core version

## Decisions

- Default fallback changed to 8000 (not 4000) based on research finding that 8000 covers 1-2 typical chapter files and is more useful than the original 4000
- Subdirectory discovery uses `find -maxdepth 2` (one level deep) per plan's Non-Goals — no recursive `**/index.json`
- Subdirectory entries get prefixed IDs (`{subdir}_{file}`) to avoid collisions with root entries
- Root entries take precedence in merge: subdirectory entries with the same `path` as any root entry are silently dropped
- Malformed subdirectory index.json files are silently skipped via `2>/dev/null` and empty-array defaults

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (shell script)
- Tests: Passed — 5 manual tests confirmed: (1) exit 1 when directory missing, (2) token_budget read from index.json (40000 case), (3) chapters[] entries discovered and scored from subdirectory, (4) root entries win on path collision, (5) default 8000 budget allows files between 4000-8000 tokens
- Files verified: Both script copies confirmed byte-identical via `diff` (exit 0)

## Notes

- The CLAUDE.md documentation still says `TOKEN_BUDGET=4000` in the Literature Mode section — this is a separate documentation update task; the runtime behavior is now correct
- The `find -maxdepth 2` pattern means it finds `{subdir}/index.json` but NOT `{subdir}/{deeper}/index.json`; this matches the plan's scope
