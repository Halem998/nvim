# Research Report: Task #703

**Task**: 703 - Create literature organization guide
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**: literature-retrieve.sh, .claude/context/index.json, .claude/context/guides/extension-development.md
**Artifacts**: specs/703_create_literature_organization_guide/reports/01_lit-org-guide.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The literature system uses two modes: an index-guided keyword-scoring mode (when `specs/literature/index.json` exists) and a fallback recursive scan mode
- The `entries[]` schema for `index.json` has been confirmed from the script source: `id`, `path`, `title`, `token_count`, `score` (computed), and optionally `keywords` and `summary` fields are used by the scoring engine
- The task description specifies additional fields (`bib_key`, `authors`, `year`, `section`, `page_range`) that should be documented as metadata conventions even though the script only reads `keywords`, `summary`, `path`, `title`, and `token_count`
- No `specs/literature/` directory currently exists in this project -- the guide will document the convention from scratch with reference to the authoritative script
- The `load_when` pattern for the new context guide should target `general-research-agent` and the `/research` command

---

## Context & Scope

Task 703 requires creating two files:

1. `.claude/context/guides/literature-organization.md` -- a human-readable reference guide documenting `specs/literature/` directory conventions, index schemas, naming patterns, chunk sizing policy, injection mechanics, and a step-by-step procedure for adding new papers
2. An entry in `.claude/context/index.json` registering the guide for loading by research agents during `--lit` operations

The research goal is to gather the authoritative facts from the codebase before writing either file.

---

## Findings

### 1. Script Location and Constants

**Script**: `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh`

Constants (lines 20-22):
```
TOKEN_BUDGET=4000   # max total tokens to inject
MAX_FILES=10        # max number of files
MIN_SCORE=1         # minimum keyword overlap to include
```

**Path resolution** (lines 29-32): The script resolves `$PROJECT_ROOT` as two directories above `$SCRIPT_DIR` (`.claude/scripts/`). This means `$PROJECT_ROOT` is the repository root (e.g., `/home/benjamin/.config/nvim`). The literature directory is always `$PROJECT_ROOT/specs/literature`.

---

### 2. Two Operating Modes

#### Mode A: Index-Guided (when `specs/literature/index.json` exists AND description is non-empty)

**Step 1 -- Keyword extraction** (lines 42-52):

The script combines the task description and task type, lowercases everything, strips stop words, filters tokens of length > 3, deduplicates, and takes the top 10 keywords.

Stop words list includes: the, a, an, and, or, but, in, on, at, of, to, for, is, are, was, were, be, been, being, have, has, had, do, does, did, will, would, could, should, may, might, can, shall, not, no, with, by, from, as, into, through, during, before, after, above, below, between, out, off, over, under, again, further, then, once, here, there, when, where, why, how, all, both, each, few, more, most, other, some, such, only, own, same, so, than, too, very, just, about, up, its, it, this, that, these, those, what, which, who, whom.

**Step 2 -- Scoring** (lines 60-83):

For each entry in `index.json`, the script:
- Computes `kw_score`: count of task keywords found in `entry.keywords[]` (case-insensitive)
- Computes `summary_bonus`: 1 if any task keyword appears in `entry.summary`, else 0
- `total_score = kw_score + summary_bonus`
- Keeps entries where `total_score >= 1`
- Sorts descending by score

Fields read from each entry: `id`, `keywords`, `summary`, `path`, `title`, `token_count`

**Step 3 -- Greedy selection** (lines 86-96):

Iterates scored entries in score order. Adds an entry to the selection if:
- Current `count < MAX_FILES` (10)
- `total_tokens + entry.token_count <= TOKEN_BUDGET` (4000)

**Step 4 -- Output assembly** (lines 99-126):

Wraps selected files in `<literature-context>...</literature-context>` XML block with headings showing title and relevance score. Resolves `full_path = $LIT_DIR/$entry.path` and reads the file.

#### Mode B: Fallback Scan (no index, no keywords, or no index matches)

Uses `find "$LIT_DIR" -type f \( -name "*.md" -o -name "*.txt" \)` sorted lexicographically.

For each file: estimates tokens as `(word_count * 13 + 5) / 10`. Skips files that would exceed the budget. Outputs with basename as heading.

---

### 3. index.json Schema (Entries Array)

Fields **actively used** by literature-retrieve.sh:

| Field | Type | Required | Used by script |
|-------|------|----------|----------------|
| `id` | string | Yes | Logged in scored output (not displayed to agent) |
| `path` | string | Yes | Resolves to full file path relative to `$LIT_DIR` |
| `title` | string | Recommended | Section heading in output (`entry.title // entry.id` fallback) |
| `token_count` | integer | Yes | Greedy budget enforcement |
| `keywords` | string[] | Yes | Keyword scoring |
| `summary` | string | Recommended | Summary bonus (+1) if any keyword matches |

Fields **specified by task description** as metadata conventions (not read by script but useful for humans and potential future tooling):

| Field | Type | Purpose |
|-------|------|---------|
| `bib_key` | string | BibTeX cite key (e.g., `Smith2023`) |
| `authors` | string[] | Author list |
| `year` | integer | Publication year |
| `section` | string | For chapter entries: section identifier |
| `page_range` | string | Source page range in original document |

---

### 4. Subdirectory Index Formats

The task description mentions a `chapters[]` format for books. This is not present in the current script but is a documented convention the guide should describe. The script treats `path` as relative to `$LIT_DIR`, so a subdirectory entry would use `path: "Author_Year_Title/sec01_introduction.md"`.

The guide should document:
- **Flat files** (`$LIT_DIR/Author_Year_Title.md`) -- for single papers or short specs
- **Subdirectory files** (`$LIT_DIR/Author_Year_Title/sec01_introduction.md`) -- for books or long documents chunked into sections
- **Book-level index** (`$LIT_DIR/Author_Year_Title/index.json`) -- containing `chapters[]` array that parallels the global `entries[]` format but scoped to that book

Since the current script only reads the top-level `$LIT_DIR/index.json`, the `chapters[]` format is a user-maintained organizational convention. The global `index.json` would contain one entry per chapter, each with a `section` field.

---

### 5. Naming Conventions

From task description and deduced from the script behavior:

**Flat papers**: `Author_Year_Title.md`
- Example: `Smith_2023_PropositionalLogic.md`
- Example: `Brastmckie_2024_BimodalLogic.md`

**Chapter files inside a subdirectory**: `secNN_slug.md`
- Example: `sec01_introduction.md`, `sec02_syntax.md`
- `NN` is zero-padded section number for lexicographic ordering

**Index files**: `index.json` at `$LIT_DIR/` root (and optionally at `$LIT_DIR/Author_Year_Title/index.json` for per-book chapter metadata)

---

### 6. Chunk Sizing Policy

**Token budget**: 4000 tokens total across all selected files (TOKEN_BUDGET constant in script).

**Token estimation formula** (fallback mode, lines 148-150):
```bash
word_count=$(wc -w < "$f")
est_tokens=$(( (word_count * 13 + 5) / 10 ))
```
This approximates 1.3 tokens per word.

**Guidance for file authors**: Each chunk file should target ~3000 tokens (roughly 2300 words) to leave headroom within the 4000-token budget for multiple files. A single oversized file that exceeds the budget is silently skipped.

**Index-mode**: `token_count` is a manually-specified integer in the entry. Authors should measure actual token counts (or estimate using the same formula: `word_count * 1.3`).

---

### 7. How --lit Injection Works (End-to-End)

1. User runs a command with `--lit` flag (e.g., `/research 703 --lit`)
2. The preflight script (`command-gate-in.sh` or the skill's preflight) calls `literature-retrieve.sh <task_description> <task_type>`
3. `literature-retrieve.sh` checks if `$PROJECT_ROOT/specs/literature/` exists -- exits 1 if not
4. If `index.json` exists and description is non-empty: runs Mode A (keyword scoring, greedy selection)
5. Otherwise: runs Mode B (recursive scan, first-fit within budget)
6. Output is a `<literature-context>` XML block written to stdout
7. The skill injects this block into the agent prompt after `<memory-context>` (if any) and before task-specific instructions
8. If the script exits 1 (empty stdout): `--lit` is silently ignored (no error)

**Key design property**: Relevance is determined by keyword overlap between the task description/type and the entry's `keywords[]` array plus `summary` text. Entries with no keyword overlap are excluded entirely (score = 0 < MIN_SCORE of 1).

---

### 8. index.json Entry Schema (Complete Reference)

```json
{
  "entries": [
    {
      "id": "smith2023-proplogic",
      "bib_key": "Smith2023",
      "title": "Propositional Logic: A Modern Introduction",
      "authors": ["Alice Smith"],
      "year": 2023,
      "section": null,
      "path": "Smith_2023_PropositionalLogic.md",
      "page_range": null,
      "token_count": 1850,
      "keywords": ["propositional", "logic", "syntax", "semantics", "proof"],
      "summary": "Introduces propositional logic with natural deduction and truth tables."
    }
  ]
}
```

For a chapter entry:
```json
{
  "id": "brastmckie2024-bimodal-ch2",
  "bib_key": "Brastmckie2024",
  "title": "BimodalLogic - Chapter 2: Syntax",
  "authors": ["Benjamin Brastmckie"],
  "year": 2024,
  "section": "ch02",
  "path": "Brastmckie_2024_BimodalLogic/sec02_syntax.md",
  "page_range": "15-47",
  "token_count": 2100,
  "keywords": ["bimodal", "syntax", "formula", "operator", "modal"],
  "summary": "Defines the formal syntax of bimodal logic with operator precedence rules."
}
```

---

### 9. context/index.json Registration Format

From reading the existing entries, the new guide entry should follow this pattern:

```json
{
  "summary": "literature-organization guide: specs/literature/ directory layout, index.json schema, naming conventions, chunk sizing, and --lit injection mechanics",
  "domain": "core",
  "keywords": [
    "literature",
    "inject",
    "index",
    "papers",
    "research",
    "specifications"
  ],
  "subdomain": "guides",
  "line_count": <actual>,
  "load_when": {
    "commands": ["/research", "/plan", "/implement"],
    "task_types": [],
    "agents": ["general-research-agent"]
  },
  "topics": [
    "literature",
    "research"
  ],
  "path": "guides/literature-organization.md"
}
```

**Rationale for load_when**:
- `commands: ["/research", "/plan", "/implement"]` -- these are the commands that support `--lit`
- `agents: ["general-research-agent"]` -- research agents are the primary consumers
- No `task_types` filter -- the guide applies to any task type that uses `--lit`

---

### 10. Existing Guide Style

The extension-development.md guide uses:
- Level 2 headers for major sections
- Code blocks for JSON examples
- Tables for field descriptions (Field | Type | Required | Description)
- Inline code for field names and paths
- Concrete examples with plausible values

---

## Decisions

1. The guide will document the `entries[]` schema with both the script-required fields and the recommended metadata fields (bib_key, authors, year, section, page_range) as "metadata conventions"
2. The `chapters[]` format for books will be documented as: store one entry per chapter in the global `index.json` using the `section` field, with `path` pointing to the chapter file inside the subdirectory. A per-book `index.json` is optional and not read by the current script.
3. The index.json entry for context registration uses `load_when.commands` for `/research`, `/plan`, `/implement` and `load_when.agents` for `general-research-agent`
4. Chunk sizing guidance: target ~3000 tokens per chunk (~2300 words) to allow room for multiple files within the 4000-token budget
5. The `token_count` field in index entries should be specified by the author; the estimation formula `word_count * 1.3` can be used to approximate it

---

## Risks & Mitigations

- **Risk**: The `chapters[]` format mentioned in the task description is not implemented in literature-retrieve.sh. The guide must be clear that per-book `index.json` files are organizational metadata only; the global `index.json` is what the script reads.
  - **Mitigation**: Document this explicitly with a "Note" callout in the guide.
- **Risk**: Token counts in index entries going stale when files are edited.
  - **Mitigation**: Document that `token_count` should be re-estimated after significant edits using `echo $(( $(wc -w < file.md) * 13 / 10 ))`.

---

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` (167 lines, authoritative)
- `/home/benjamin/.config/nvim/.claude/context/index.json` (3558 lines, registration format reference)
- `/home/benjamin/.config/nvim/.claude/context/guides/extension-development.md` (style reference)

### Key Numbers
- TOKEN_BUDGET = 4000
- MAX_FILES = 10
- MIN_SCORE = 1
- Token estimation: `(word_count * 13 + 5) / 10` (approximately 1.3 tokens/word)
- Recommended chunk target: ~3000 tokens (~2300 words)
