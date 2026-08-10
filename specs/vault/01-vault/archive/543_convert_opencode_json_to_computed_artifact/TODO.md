# Task 543: Convert opencode.json to Fully Computed Artifact

- **Task**: 543 - convert_opencode_json_to_computed_artifact
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Task Type**: meta
- **Dependencies**: Task #542

## Description

Replace the merge-target approach for `opencode.json` with a computed-artifact pattern, analogous to how `generate_claudemd()` in `merge.lua` rebuilds `CLAUDE.md` from scratch after every load/unload cycle. Research the `generate_claudemd()` pattern, design a `generate_opencode_json()` function that aggregates agent entries from all loaded extensions, and implement the regeneration pipeline. Document the computed-artifact pattern in `.opencode/context/patterns/computed-artifacts.md` for future use with other merge-target files.

## Key Files

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - merge/unmerge logic and `generate_claudemd()` reference implementation
- `opencode.json` - target file to convert to computed artifact
- `.opencode/context/patterns/computed-artifacts.md` - documentation of the pattern

## Acceptance Criteria

1. `generate_opencode_json()` function exists in merge.lua, modeled on `generate_claudemd()`
2. opencode.json is regenerated in full after every load/unload cycle (never hand-edited)
3. Computed artifact pattern documented in `.opencode/context/patterns/computed-artifacts.md`
4. Load/unload tests pass with the new regeneration approach
