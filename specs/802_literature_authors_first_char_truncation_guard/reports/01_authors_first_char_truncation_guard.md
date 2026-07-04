# Research Report: Task #802

**Task**: 802 - Guard skill-literature authors resolver against string-to-first-char truncation
**Started**: 2026-07-04T00:00:00Z
**Completed**: 2026-07-04T00:00:00Z
**Effort**: 30 minutes
**Dependencies**: None (follow-up to task 801, parent_task=801)
**Sources/Inputs**: Codebase (`.claude/skills/skill-literature/SKILL.md`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The buggy line is confirmed exactly as described: `.claude/skills/skill-literature/SKILL.md:1696`.
- The current text is: `(.authors // []) | first // "?"` inside the "List: Show Entries with Resolved Metadata" section's per-entry resolver.
- `jq`'s `first` filter, applied to a JSON string, returns the string's first character rather than erroring — `.authors // []` only substitutes when `.authors` is `null`/`false`, so a string-typed `.authors` silently passes through to `first` and gets truncated to one character.
- Grep across the entire file for `first` confirms line 1696 is the ONLY occurrence of this pattern (`first` applied to `.authors` in a jq pipeline). No other occurrences of the buggy pattern exist elsewhere in the file.
- Fix is a single-line, type-aware jq expression as specified in the task description.

## Context & Scope

Task 802 is a small, self-contained follow-up to task 801 (authors-shape normalization). Task 801 addressed a related but distinct code path in `literature-briefing.sh` (fixed under task 799) and normalized the global corpus to arrays. This task addresses a second, independent occurrence of unsafe `.authors` handling — this time in the "List" operation of the per-repo sub-index resolver inside `SKILL.md` itself (documentation/inline-script form, not a standalone script).

Scope is confirmed as a single line; no other files or occurrences need touching.

## Findings

### Codebase Patterns

**Exact location**: `.claude/skills/skill-literature/SKILL.md`, line 1696, inside the `### List: Show Entries with Resolved Metadata` section (lines 1677-1712), which resolves title/authors/year from the global index for each sub-index entry via a `while` loop over sub-index entries.

**Surrounding context** (lines 1693-1698):
```bash
while IFS=$'\t' read -r doc_id relevance added source; do
  # Resolve from global index
  title=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | .title // "?"' "$global_index" 2>/dev/null | head -1)
  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.authors // []) | first // "?"' "$global_index" 2>/dev/null | head -1)
  year=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.year // "?") | tostring' "$global_index" 2>/dev/null | head -1)
  chunk_count=$(jq --arg id "$doc_id" '[.entries[] | select(.parent_doc == $id)] | length' "$global_index" 2>/dev/null || echo 0)
```

**Exact current text to replace** (the jq filter argument, single-quoted string within line 1696):
```
.entries[] | select(.id == $id) | (.authors // []) | first // "?"
```

**Exact replacement text**:
```
.entries[] | select(.id == $id) | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end
```

Full replacement line 1696 (preserving the surrounding bash variable assignment, `jq -r` invocation, `--arg id "$doc_id"` flag, source file argument, and stderr/`head -1` suffix unchanged):
```bash
  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end' "$global_index" 2>/dev/null | head -1)
```

Note: the type-aware `if/elif/else` expression already returns `"?"` for the null/missing case (the `else` branch), so the `(.authors // [])` guard is subsumed and can be dropped in the replacement — the fix does not need to retain the original `// []` fallback since the `if` covers all three cases (array, string, and everything else including null).

### Other Occurrences Check

Grep of the whole file for `first`:
```
485:  or --dry-run (default) first to preview the change.
563:needed for page-range chunks; for content-aware chunking, extract all text first):
789:# Extract summary: look for Abstract, else use first 2-3 sentences
1523:# In handle_convert Convert Step 3f (metadata prompts), check PREFILL_* first:
1696:  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.authors // []) | first // "?"' "$global_index" 2>/dev/null | head -1)
```
Only line 1696 uses `first` as a jq pipe filter on `.authors`. The other four matches are unrelated prose/comments (lines 485, 563, 789, 1523) with no jq `first` filter involved.

Grep of the whole file for `authors` (36 occurrences) shows the other authors-related jq/bash expressions use different, safe-or-differently-risky patterns:
- Lines 1332, 1338, 1456: `.authors | join(", ")` (or `(.authors // []) | join(", ")`) — `join` on a string argument errors rather than truncating silently, so this is a different failure mode, out of scope per the task description (which targets the `first`-truncation footgun specifically at line ~1696).
- Lines 407, 415, 425-441: task-801 validation logic that explicitly type-checks `.authors` (`(.authors | type) != "array"`) — this is the correct type-aware pattern already used elsewhere in the same file, confirming the fix at line 1696 is consistent with established conventions in this file.

### Recommendations

Apply the single-line edit described above. This is a pure string replacement with no other code path affected. No test suite or build step is required for a Markdown-embedded bash/jq snippet; verification can be done with a manual jq dry run, e.g.:
```bash
echo '{"entries":[{"id":"x","authors":"Yde Venema"}]}' | jq -r '.entries[] | select(.id == "x") | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end'
# -> "Yde Venema" (not "Y")
```

## Decisions

- Fix targets exactly line 1696 as specified in the task description; no other lines require changes.
- The `.authors // []` fallback is dropped in the replacement since the `if/elif/else` construct's `else` branch already covers the null/missing case, avoiding redundant guarding.

## Risks & Mitigations

- **Risk**: None significant — this is a documentation/inline-script correction with no runtime script file to break; the only risk is a typo in the jq expression. **Mitigation**: the exact replacement text above should be copied verbatim, and the dry-run jq check above can validate correctness before/after edit.

## Context Extension Recommendations

None — this is a narrow, self-contained meta task with no context-file gap. omit.

## Appendix

- Search queries used: `grep -n "first" SKILL.md`, `grep -n "authors" SKILL.md`, `Read` lines 1670-1720.
- References: task 801 report `01_authors-schema-normalization.md` (not re-read per Stage 1.6 guidance — referenced only via task description context).
