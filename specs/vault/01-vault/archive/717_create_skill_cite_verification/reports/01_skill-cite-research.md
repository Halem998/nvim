# Research Report: Task #717

**Task**: 717 - Create skill-cite direct execution skill for citation verification
**Started**: 2026-06-15T22:10:00Z
**Completed**: 2026-06-15T22:25:00Z
**Effort**: 1.5 hours
**Dependencies**: Task #716
**Sources/Inputs**: Codebase exploration (skill-fix-it, skill-literature, cite-extract.sh, zotero-search.sh, multi-task-creation-standard.md, manifest.json)
**Artifacts**: specs/717_create_skill_cite_verification/reports/01_skill-cite-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-cite should follow the `/fix-it` direct execution pattern: scan, display, interactive multiSelect, create tasks
- cite-extract.sh outputs a JSON array with fields: `claim`, `source_text`, `line_number`, `confidence`, `pattern_type`
- zotero-search.sh outputs a JSON array with: `citation_key`, `title`, `authors`, `year`, `score`, `pdf_paths`, `abstract_snippet`
- The confidence scoring system maps claim matches to confirmed/partial/unconfirmed/gap using Literature/ index keyword overlap and Zotero score
- SKILL.md frontmatter requires `name`, `description`, and `allowed-tools` fields; place at `.claude/extensions/literature/skills/skill-cite/SKILL.md`

## Context & Scope

The task is to create `skill-cite`, a direct execution skill (no separate agent) that verifies citation claims extracted from task artifacts. It integrates `cite-extract.sh` and `zotero-search.sh` and creates tasks for corrections/additions/gap-fills using the multi-task creation standard.

## Findings

### 1. `/fix-it` Skill Pattern Analysis

The reference implementation at `.claude/skills/skill-fix-it/SKILL.md` shows the canonical direct execution pattern:

**SKILL.md frontmatter**:
```yaml
---
name: skill-fix-it
description: Scan codebase for FIX:/NOTE:/TODO:/QUESTION: tags...
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---
```

**11-step execution flow**:
1. Parse arguments
2. Generate session ID (`sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')`)
3. Execute scanning
4. Display results to user BEFORE any selection
5. Handle edge cases (no results, partial results)
6. Task type selection via `AskUserQuestion` with `multiSelect: true`
7. Individual item selection (with "Select all" for >20 items)
8. Topic grouping algorithm (key terms + file section clustering)
9. Topic grouping confirmation (3-way: grouped/separate/combined)
10. Create selected tasks in dependency-aware order
11. Update state.json, assign topics, regenerate TODO.md, git commit

**Key AskUserQuestion pattern** (multiSelect):
```json
{
  "question": "Which task types should be created?",
  "header": "Task Types",
  "multiSelect": true,
  "options": [
    {"label": "fix-it task", "description": "Combine {N} FIX:/NOTE: tags into single task"},
    ...
  ]
}
```

**Task creation details**: Reads `next_project_number` from `specs/state.json`, writes new entries, calls `manage-topics.sh set`, then `generate-todo.sh`.

### 2. cite-extract.sh Output Format

Located at `.claude/extensions/literature/scripts/cite-extract.sh`.

**JSON output schema** (array of objects):
```json
[
  {
    "claim": "full line content (truncated to 200 chars)",
    "source_text": "matched citation text (the actual citation marker)",
    "line_number": 42,
    "confidence": 0.9,
    "pattern_type": "author_year|parenthetical|phrase_attribution|theorem_attr_bracket|theorem_attr_ref|direct_quote_bracket|direct_quote_dash|numeric_bracket|alpha_num_bracket|latex_cite"
  }
]
```

**Confidence levels per pattern**:
- `0.9` — author_year, parenthetical, theorem_attr_bracket, direct_quote_bracket, latex_cite (high-confidence structural markers)
- `0.85` — direct_quote_bracket
- `0.7` — phrase_attribution, theorem_attr_ref, alpha_num_bracket
- `0.6` — direct_quote_dash
- `0.5` — numeric_bracket (lowest: [42] is ambiguous)

**Invocation**:
```bash
cite-extract.sh [--format=json|pretty] [--min-confidence=N] [FILE]
# or:
cat file.md | cite-extract.sh [OPTIONS]
```

**Exit codes**: 0 = found results, 1 = setup error, 2 = no results

**Integration approach**: For each task artifact (reports/*.md, plans/*.md), run cite-extract.sh and aggregate results. Use `--format=json` for programmatic processing.

### 3. zotero-search.sh Integration Approach

Located at `.claude/extensions/literature/scripts/zotero-search.sh`.

**JSON output schema** (array of objects):
```json
[
  {
    "citation_key": "Smith2020_modal_logic",
    "title": "Modal Logic for Open Minds",
    "authors": "Smith, John; Jones, Alice",
    "year": 2020,
    "score": 7,
    "pdf_paths": ["/path/to/file.pdf"],
    "abstract_snippet": "First 200 chars of abstract..."
  }
]
```

**Scoring** (additive, per matching term):
- title: +3
- keyword: +2
- abstract: +1
- author: +1

**Invocation**:
```bash
zotero-search.sh [--limit=N] [--format=json|pretty] QUERY [QUERY...]
```

**Exit codes**: 0 = results found, 1 = library not found (print setup instructions), 2 = no results

**Library resolution** (3-tier fallback):
1. `$ZOTERO_LIBRARY` env var
2. `$LITERATURE_DIR/zotero-library.json`
3. `~/Projects/Literature/zotero-library.json`

**Integration approach**: Extract the `source_text` from each cite-extract claim as query terms, run zotero-search.sh, then cross-reference with Literature/ index.

### 4. Literature/ Index Search Strategy

The Literature/ index is at `specs/literature/index.json`. Entry schema:
```json
{
  "id": "entry_id",
  "path": "relative/path.md",
  "token_count": 3500,
  "keywords": ["modal", "logic", "kripke"],
  "summary": "One-sentence summary",
  "authors": ["Smith, John"],
  "title": "Modal Logic...",
  "year": 2020,
  "doc_type": "paper|book|chapter|section",
  "source_format": "pdf|djvu|manual",
  "bib_key": "Smith2020",
  "zotero_key": "ABCD1234"
}
```

**Keyword matching approach** (same as skill-literature search mode):
```bash
# For each claim's source_text, split into terms and score index entries
while IFS=$'\t' read -r entry_id entry_path entry_keywords entry_title; do
  score=0
  combined="${entry_keywords} ${entry_title}"
  for term in "${query_terms[@]}"; do
    if echo "$combined" | grep -qi "$term"; then
      score=$(( score + 1 ))
    fi
  done
  # score > 0 = match
done < <(jq -r '.entries[] | [.id, .path, (.keywords // [] | join(" ")), (.title // "")] | @tsv' "$index_file")
```

**Cross-reference with Zotero**: Match on `bib_key`, `zotero_key`, or `id` fields.

### 5. Confidence Scoring Methodology

For each extracted citation claim, skill-cite searches both Zotero and Literature/ index and scores the match:

| Status | Condition |
|--------|-----------|
| **confirmed** | Zotero score >= 3 AND/OR Literature/ index keyword overlap >= 2; document found and accessible |
| **partial** | Zotero score 1-2 OR Literature/ index keyword overlap 1; potential match but uncertain |
| **unconfirmed** | No Zotero or index match; claim cannot be verified against known sources |
| **gap** | Citation pattern found but no source available (PDF not downloaded, not in Zotero) |

**Composite confidence**: `match_status_score * cite_extract_confidence`
- confirmed (1.0) * claim_confidence = final_confidence
- partial (0.5) * claim_confidence
- unconfirmed (0.0) * claim_confidence

**Display grouping** for AskUserQuestion:
1. Unconfirmed/Gap claims (need tasks) → offered for task creation
2. Confirmed claims → display-only, no task needed
3. Partial claims → offered with lower priority

### 6. SKILL.md Structure and Frontmatter Requirements

Based on both skill-fix-it and skill-literature:

**Required frontmatter**:
```yaml
---
name: skill-cite
description: Verify citation claims in task artifacts against Literature/ index and Zotero library. Invoke for /cite command.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---
```

**Target path**: `.claude/extensions/literature/skills/skill-cite/SKILL.md`

**manifest.json update required**: Add `"skill-cite"` to the `provides.skills` array in `.claude/extensions/literature/manifest.json`.

**Context References pattern** (from skill-literature):
```yaml
# Reference (do not load eagerly):
- Path: `@specs/literature/index.json`
- Path: `@specs/state.json`
```

## Decisions

1. **No separate agent** — skill-cite runs as direct execution like /fix-it and /literature
2. **Input scope** — scan task artifacts (reports, plans, summaries) within `specs/{NNN}_{SLUG}/`, not arbitrary files; optionally support direct file path argument
3. **Task creation scope** — create tasks only for unconfirmed/gap claims, not confirmed ones; partial claims are user-selectable
4. **Search order** — Literature/ index first (local, fast), then Zotero (external); combine results
5. **manifest.json** — must add skill-cite to `provides.skills` for extension routing to work
6. **Graceful degradation** — if Zotero not configured (exit 1), continue with index-only search

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Zotero not configured | Graceful degradation: exit 1 from zotero-search.sh triggers index-only mode |
| No Literature/ index | Check for index existence; report "no index found" if missing |
| cite-extract.sh returns no results | Report "no citations found" and exit gracefully without prompts |
| Source text query produces too many Zotero results | Use `--limit=5` per claim (not global limit) and filter by score > 2 |
| Large number of claims (>20) | Add "Select all unconfirmed" option like /fix-it's "Select all" |
| state.json update race conditions | Use two-step jq pattern (write to tmp, then mv) |

## Context Extension Recommendations

- **Topic**: skill-cite pattern in literature extension
- **Gap**: No documented pattern for citation verification workflows in `.claude/context/`
- **Recommendation**: After implementation, add a note to `.claude/extensions/literature/README.md` describing the cite verification workflow

## Appendix

### Key File Paths
- `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` — primary reference
- `/home/benjamin/.config/nvim/.claude/extensions/literature/skills/skill-literature/SKILL.md` — extension skill reference
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/cite-extract.sh` — citation extractor
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh` — Zotero searcher
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md` — task creation standard
- `/home/benjamin/.config/nvim/.claude/extensions/literature/manifest.json` — needs skill-cite added to provides.skills

### Search Queries Used
- Read: skill-fix-it/SKILL.md, skill-literature/SKILL.md, cite-extract.sh, zotero-search.sh, multi-task-creation-standard.md, manifest.json
- Bash: ls on scripts/, extension directory, specs/717 directory, state.json jq query
