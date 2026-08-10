# Research: Orphaned Index Entries in Website index.json

**Task**: 302
**Date**: 2026-03-26
**Status**: Complete

## Current State

The Website project's `.claude/context/index.json` contains **83 total entries**. Of these, **26 entries** reference files that do not exist on disk.

### Loaded Extensions

From `/home/benjamin/Projects/Logos/Website/.claude/extensions.json`, three extensions are currently active:

| Extension | Status | Version |
|-----------|--------|---------|
| filetypes | active | 2.1.0 |
| web | active | 1.0.0 |
| memory | active | 1.0.0 |

**Notable absence**: The `lean4` extension is **not loaded**, yet 24 lean4 context entries remain in the index.

### Orphaned Entries (26 total)

#### Pitch-Deck Entries (2) -- filetypes subdomain

These reference non-existent files under `project/filetypes/patterns/`:

1. `project/filetypes/patterns/pitch-deck-structure.md`
2. `project/filetypes/patterns/touying-pitch-deck-template.md`

**Note**: Task 297 already identified and was supposed to remove these duplicates. They appear to still be present in the index.

#### Lean4 Entries (24) -- lean4 subdomain

All reference non-existent files under `project/lean4/`:

| # | Path |
|---|------|
| 1 | `project/lean4/README.md` |
| 2 | `project/lean4/domain/mathlib-overview.md` |
| 3 | `project/lean4/domain/dependent-types.md` |
| 4 | `project/lean4/domain/key-mathematical-concepts.md` |
| 5 | `project/lean4/domain/lean4-syntax.md` |
| 6 | `project/lean4/patterns/tactic-patterns.md` |
| 7 | `project/lean4/standards/lean4-style-guide.md` |
| 8 | `project/lean4/standards/proof-conventions-lean.md` |
| 9 | `project/lean4/standards/proof-debt-policy.md` |
| 10 | `project/lean4/standards/proof-readability-criteria.md` |
| 11 | `project/lean4/standards/proof-conventions.md` |
| 12 | `project/lean4/tools/mcp-tools-guide.md` |
| 13 | `project/lean4/tools/aesop-integration.md` |
| 14 | `project/lean4/tools/leansearch-api.md` |
| 15 | `project/lean4/tools/loogle-api.md` |
| 16 | `project/lean4/tools/lsp-integration.md` |
| 17 | `project/lean4/agents/lean-implementation-flow.md` |
| 18 | `project/lean4/agents/lean-research-flow.md` |
| 19 | `project/lean4/operations/multi-instance-optimization.md` |
| 20 | `project/lean4/processes/end-to-end-proof-workflow.md` |
| 21 | `project/lean4/processes/project-structure-best-practices.md` |
| 22 | `project/lean4/templates/definition-template.md` |
| 23 | `project/lean4/templates/new-file-template.md` |
| 24 | `project/lean4/templates/proof-structure-templates.md` |

### Other Entries

All remaining 57 entries (83 - 26) reference files that **do exist on disk**. No other broken references were found.

## Relationship to Task 301

- **Task 301** addresses the root cause: the extension loader does not clean up index entries when extensions are unloaded
- **This task (302)** is an immediate fix for the current state
- If task 301 is completed first, the loader will handle cleanup automatically on future unloads
- This task can be done independently as a quick fix, with the understanding that if extensions are loaded/unloaded again before 301 is complete, orphans may recur

## Proposed Implementation

### Approach A: Filter by file existence (precise)

```bash
cd /home/benjamin/Projects/Logos/Website/.claude/context
jq '[.entries[] | select(. as $e | $e.path | . as $p | input_line_number > 0)]' index.json
```

More practically, use a script that checks each path:

```bash
cd /home/benjamin/Projects/Logos/Website/.claude/context
jq --argjson orphans "$(jq -r '.entries[].path' index.json | while read -r p; do [ ! -f "$p" ] && echo "\"$p\""; done | jq -s '.')" \
  '[.entries[] | select(.path as $p | ($orphans | index($p)) == null)]' index.json > index.json.tmp
mv index.json.tmp index.json
```

### Approach B: Filter by domain path prefix (simpler)

Remove all entries whose path starts with `project/lean4/` or matches the two known pitch-deck orphans:

```bash
cd /home/benjamin/Projects/Logos/Website/.claude/context
jq '[.entries[] | select((.path | startswith("project/lean4/")) | not) | select(.path == "project/filetypes/patterns/pitch-deck-structure.md" | not) | select(.path == "project/filetypes/patterns/touying-pitch-deck-template.md" | not)]' index.json
```

### Recommendation

Use **Approach A** (file existence check) as it catches any orphans regardless of domain prefix, making it future-proof.

### Expected Result

- Before: 83 entries
- After: 57 entries (83 - 26)
- All remaining entries verified to reference existing files
