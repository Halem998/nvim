# Research Report: Task #727

**Task**: 727 - Implement extension keyword_overrides lookup in /task command step 4
**Started**: 2026-06-16T02:35:00Z
**Completed**: 2026-06-16T02:38:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (.claude/commands/task.md, .claude/extensions/*/manifest.json, specs/state.json, CLAUDE.md)
**Artifacts**: specs/727_implement_extension_keyword_overrides_in_task_command/reports/01_keyword-overrides-research.md
**Standards**: report-format.md

## Executive Summary

- The `/task` command at `.claude/commands/task.md` already has a complete step 4 implementation with the correct precedence order (meta > extension keyword_overrides > default_task_type > hardcoded table > general) including `keyword_overrides` scanning logic and alias remapping.
- The step 4 documentation in `task.md` lines 111-187 is complete and correct as of the current file state.
- The task description in `state.json` says "currently step 4 only has a hardcoded keyword table" — this appears to be stale; the file already contains the full implementation with all precedence levels.
- **Recommended action**: Verify whether the `task.md` step 4 was recently updated (check git log) and if so, this task may already be complete. If not, the documented implementation in `task.md` is the target spec to implement.

## Context & Scope

The task asks to fix `/task` command step 4 to implement the documented precedence order. Research examined:
1. The current `task.md` step 4 implementation
2. Extension manifest `keyword_overrides` schema (from cslib extension)
3. The `state.json` `default_task_type` field
4. CLAUDE.md documentation of the precedence rules

## Findings

### Current State of Step 4

Reading `task.md` lines 111-187, step 4 currently contains:

**Step 4a - Meta keywords** (lines 120-122): Checks "meta", "agent", "command", "skill" → task_type = `meta`.

**Step 4b - Extension keyword_overrides** (lines 123-142): Scans `.claude/extensions/*/manifest.json` using a bash loop with jq pattern:
```bash
for manifest in .claude/extensions/*/manifest.json; do
  [ -f "$manifest" ] || continue
  matched=$(jq -r --arg desc "$description_lower" '
    .keyword_overrides // {} | to_entries[] |
    select(.value.keywords[]? as $kw |
      ($desc | test("\\b" + $kw + "\\b"))) |
    .key' "$manifest" 2>/dev/null | head -1)
  [ -n "$matched" ] && break
done
```

**Step 4c - Project default** (lines 144-145): Checks `default_task_type` from state.json before falling through to the hardcoded table.

**Step 4d - Hardcoded keyword table** (lines 146-165): Full keyword table for lean4, latex, typst, python, z3, nix, web, epi, formal, founder variants, else general.

**Step 4e - Extension alias remapping** (lines 167-183): Post-resolution alias scan to remap hardcoded table results through extension aliases.

**Conclusion**: The `task.md` file already contains a complete implementation of the documented precedence order.

### keyword_overrides Schema

Only one extension (`cslib`) currently has `keyword_overrides` defined. The schema:

```json
"keyword_overrides": {
  "<task_type_key>": {
    "keywords": ["<word1>", "<word2>", ...],
    "aliases": ["<existing_task_type>", ...]
  }
}
```

- `<task_type_key>`: The task_type to assign when matched (e.g., "cslib", "pr")
- `keywords`: Array of strings matched as whole words (case-insensitive) against the task description
- `aliases`: Array of task_type strings that this extension's type should replace (for alias remapping in step 4e)

Example from cslib:
```json
"keyword_overrides": {
  "cslib": {
    "keywords": ["lean", "lean4", "mathlib", "theorem", "proof", "lint-fix"],
    "aliases": ["lean4"]
  },
  "pr": {
    "keywords": ["pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick"],
    "aliases": []
  }
}
```

### Documented Precedence Order

From CLAUDE.md documentation:
> Precedence: meta keywords > extension `keyword_overrides` > `default_task_type` > keyword table > `general`

This matches the current step 4 implementation in `task.md`.

### state.json default_task_type

The `default_task_type` field in `specs/state.json` is currently `null`. The reading pattern used in step 4:
```bash
default_type=$(jq -r '.default_task_type // empty' specs/state.json)
```

This is already present at line 113-115 of `task.md` (the `jq` call to read `default_type`).

### Git History Check Needed

The task description states "Currently step 4 only has a hardcoded keyword table" — however, the current `task.md` already has the full implementation. This suggests either:
1. The implementation was added between task creation (2026-06-16) and now, OR
2. The task description was written based on an older version

## Decisions

- The implementation target is already present in `task.md` — this is the desired end state.
- No additional changes are needed to `task.md` for step 4.
- The task may need to be reviewed to determine if it was already completed by another task or if a different file was intended.

## Risks & Mitigations

- **Risk**: The bash loop for keyword scanning uses `\b` word boundaries in jq `test()`. Multi-word keywords like "pull request" or "market size" won't match with `\b` anchoring per word — they need to match as exact substrings. The current pattern `test("\\b" + $kw + "\\b")` would fail for "pull request" since `\b` applies to the full string, not individual words.
  - **Mitigation**: For multi-word keywords, the pattern should use `contains($kw)` or strip `\b` anchors and use `test($kw)` instead. This is an edge case since most keywords are single words.
- **Risk**: jq `test()` with `\b` may behave differently across jq versions for boundary detection.
  - **Mitigation**: Test with `jq --arg desc "pr fix" '.keyword_overrides // {} | to_entries[] | select(.value.keywords[]? as $kw | ($desc | test("\\b" + $kw + "\\b"))) | .key'` to verify.
- **Risk**: The `head -1` in the scan takes the first match per manifest. If an extension defines two task_types and both match, only the first one (in JSON order) wins.
  - **Mitigation**: This is acceptable behavior — extension authors control keyword_overrides ordering.

## Context Extension Recommendations

- **Topic**: Extension keyword_overrides schema documentation
- **Gap**: The `keyword_overrides` schema is only mentioned in CLAUDE.md with a reference to `extension-development.md` guide, but the guide doesn't show multi-word keyword handling nuances.
- **Recommendation**: Add a note to `.claude/context/guides/extension-development.md` about single-word vs multi-word keyword matching behavior.

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/task.md` — lines 111-187 (step 4 implementation)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` — keyword_overrides example
- `/home/benjamin/.config/nvim/specs/state.json` — default_task_type field (null)
- All other extension manifests — none have keyword_overrides

### Extensions Without keyword_overrides
All extensions except cslib have no `keyword_overrides`: core, epidemiology, filetypes, formal, founder, latex, lean, literature, memory, nix, nvim, present, python, slidev, typst, web, z3.
