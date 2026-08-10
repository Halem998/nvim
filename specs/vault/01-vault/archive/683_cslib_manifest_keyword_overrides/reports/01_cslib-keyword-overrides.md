# Research Report: Task #683

**Task**: 683 - Add keyword_overrides field to the cslib extension manifest.json
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: Low (single JSON object insertion)
**Dependencies**: Task 682 (extension keyword_overrides support in /task command - completed)
**Sources/Inputs**: Codebase (cslib manifest, task command, extension-development.md)
**Artifacts**: specs/683_cslib_manifest_keyword_overrides/reports/01_cslib-keyword-overrides.md
**Standards**: report-format.md

## Executive Summary

- The cslib extension manifest at `.claude/extensions/cslib/manifest.json` currently has no `keyword_overrides` field
- The keyword_overrides schema is fully documented and implemented (task 682 added support in `/task` step 4b/4e)
- Two entries are needed: `cslib` (with `lean4` alias + domain keywords) and `pr` (with PR-workflow keywords)
- The implementation is a single JSON field addition to the existing manifest — no other files need to change

## Context & Scope

Task 682 added `keyword_overrides` support to the `/task` command (step 4b and step 4e). The feature allows extensions to register keywords that influence task-type detection before the hardcoded keyword table is consulted, and to remap existing type results via aliases.

This task (683) adds the actual keyword_overrides entries to the cslib extension manifest so that:
1. Lean-related task descriptions automatically get `cslib` type instead of `lean4` when cslib is loaded
2. PR-workflow task descriptions automatically get `pr` type

## Findings

### Current cslib Manifest Structure

File: `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`

Key observations:
- `task_type: "cslib"` — the extension handles two task types: `cslib` and `pr`
- `routing` covers both: `cslib` routes to `skill-cslib-research`/`skill-cslib-implementation`, `pr` routes to `skill-researcher`/`skill-pr-implementation`
- `routing_hard` also covers both types
- No `keyword_overrides` field exists yet

### keyword_overrides Schema (from extension-development.md)

```json
"keyword_overrides": {
  "<task_type>": {
    "aliases": ["<existing_type>", ...],
    "keywords": ["<word1>", "<word2>", ...]
  }
}
```

- `keywords`: matched as whole-word, case-insensitive against task description (step 4b)
- `aliases`: if hardcoded table or project default resolves to any alias type, remap to this extension type (step 4e)
- Extension keyword matches take precedence over hardcoded table and project default

### Hardcoded keyword table conflict

The existing hardcoded table in `task.md` step 4d maps:
- "lean", "lean4", "mathlib", "theorem", "proof" → `lean4`
- "pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick" → (no entry — these would fall through to `general`)

The `cslib` type needs the `lean4` alias to capture any lean-related task that the hardcoded table would have assigned `lean4`. The `pr` type has no hardcoded table entry (no alias needed, just keywords).

### What Entries Are Required

Per task description:

**cslib entry**:
- keywords: `["lean", "lean4", "mathlib", "theorem", "proof"]`
- aliases: `["lean4"]` — remaps lean4 results from hardcoded table to cslib

**pr entry**:
- keywords: `["pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick"]`
- aliases: `[]` — no alias needed (pr has no hardcoded table entry)

Note: "pull request" contains a space. The `/task` command's whole-word regex uses `\b` boundaries. A two-word phrase like "pull request" will match because `\b` fires at the start of "pull" and end of "request". However, the jq `test("\\b" + $kw + "\\b")` pattern with a space inside should still work in practice for multi-word phrases since `\b` only applies to the first and last word boundary. This is worth noting in the plan for implementation verification.

### Placement in manifest.json

The `keyword_overrides` field should be placed after `routing_hard` and before `merge_targets` to follow the manifest schema ordering convention established in the extension-development.md documentation example.

### Existing Example in Documentation

The extension-development.md guide already provides the exact cslib example:
```json
"keyword_overrides": {
  "cslib": {
    "aliases": ["lean4"],
    "keywords": ["cslib", "bisimulation", "lts"]
  }
}
```

This confirms the schema and naming. The implementation task needs to expand this example with the full keyword lists from the task description.

## Decisions

- Use empty array `[]` for `pr.aliases` rather than omitting the field, for schema consistency
- Place `keyword_overrides` between `routing_hard` and `merge_targets` in the JSON structure
- Include "lean", "lean4", "mathlib", "theorem", "proof" as cslib keywords (these will match via step 4b before the hardcoded table even runs)
- Include the `lean4` alias as belt-and-suspenders for cases where keywords are missing from the description but "lean4" appears via project default or table fallback

## Risks & Mitigations

- **Risk**: "pull request" two-word keyword may not match correctly with `\b` in jq regex
  - **Mitigation**: Implementation can add both "pull" and "request" as separate keywords, or verify the two-word phrase works in jq `test()`. Since "pr" is also in the list as a standalone keyword, the common abbreviation is covered regardless.
- **Risk**: "branch" and "submit" are generic words that could match non-PR tasks
  - **Mitigation**: These are in the keywords list per the task description requirements; accepted tradeoff for deterministic routing
- **Risk**: cslib keywords ("lean", "lean4", etc.) overlap with lean extension keywords
  - **Mitigation**: The lean extension has no `keyword_overrides` field (confirmed), so cslib's step 4b match fires first (determined by filesystem glob order). If lean extension is not loaded, the hardcoded table still falls through to `lean4` — but when cslib IS loaded, the alias remapping in step 4e covers this case.

## Implementation Plan (for planner)

Single-file edit to `.claude/extensions/cslib/manifest.json`:

Add after `"routing_hard": { ... }` block, before `"merge_targets"`:

```json
"keyword_overrides": {
  "cslib": {
    "aliases": ["lean4"],
    "keywords": ["lean", "lean4", "mathlib", "theorem", "proof"]
  },
  "pr": {
    "aliases": [],
    "keywords": ["pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick"]
  }
},
```

No other files require changes. The `/task` command already reads `keyword_overrides` from manifests (task 682).

## Context Extension Recommendations

- The extension-development.md guide already documents keyword_overrides well, including the cslib example. No additional context documentation needed.
