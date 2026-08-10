# Research Report: Task #716

**Task**: 716 - Create cite-extract.sh script for citation claim extraction
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:30:00Z
**Effort**: ~2h implementation
**Dependencies**: None
**Sources/Inputs**: Codebase (zotero-search.sh), citation pattern analysis
**Artifacts**: specs/716_create_cite_extract_script/reports/01_cite-extract-research.md
**Standards**: report-format.md

## Executive Summary

- Six citation pattern families cover the vast majority of academic writing styles; each maps to a distinct regex with a confidence tier (0.9 / 0.7 / 0.5)
- The script should process input line-by-line with `grep -n` for line numbers, then emit a JSON array via jq, following the same argument-parsing and output conventions as `zotero-search.sh`
- Confidence scoring is based on specificity: named-author+year patterns score highest (0.9), phrase triggers score medium (0.7), and bare number-only patterns score lowest (0.5)

## Context & Scope

The script extracts citation claims from arbitrary text (academic papers, markdown notes, technical documents) and emits structured JSON consumed by `skill-cite`. It must work with bash + grep + sed + awk + jq, read from stdin or a file path argument, and follow the coding style established in `zotero-search.sh`.

## Findings

### Codebase Patterns

From `zotero-search.sh` the extension uses these conventions:

- `#!/usr/bin/env bash` shebang with `set -euo pipefail`
- Header comment block: script name, USAGE, DESCRIPTION, OPTIONS, ENVIRONMENT, EXIT CODES
- `show_usage()` function writing to a file descriptor (`cat >&"$fd" << 'USAGE'`)
- `for arg in "$@"` loop with `case "$arg" in --opt=*)` style option parsing
- Named variables in SCREAMING_SNAKE_CASE for configuration, lowercase for locals
- Multi-line jq programs in single-quoted heredoc-style shell variables (`JQ_PROGRAM='...'`)
- Exit codes: 0 = success, 1 = setup/validation error, 2 = no results
- Output defaults to `json`, with `--format=pretty` for human-readable

### Citation Pattern Catalog

#### Pattern Family 1: Author-Year (in-text)
Matches: `Smith 2020`, `Smith and Jones 2020`, `Smith et al. 2020`

```bash
# Regex (ERE)
'[A-Z][a-z]+( (and|&) [A-Z][a-z]+| et al\.?)?,? (19|20)[0-9]{2}[a-z]?'
```

Confidence: **0.9** — highly specific; false-positive rate very low.

Examples:
- `"As shown by Smith 2020, the method..."` → claim=`"As shown by Smith 2020, the method"`, source=`Smith 2020`
- `"(Jones and Brown 2019)"` → source=`Jones and Brown 2019`
- `"(Lee et al. 2021a)"` → source=`Lee et al. 2021a`

#### Pattern Family 2: Parenthetical Citation
Matches: `(Smith, 2020)`, `(Smith & Jones, 2020)`, `(Smith et al., 2020, p. 45)`

```bash
# Regex (ERE)
'\([A-Z][a-z]+(,? (and|&) [A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}[a-z]?(, p\.? ?[0-9]+)?\)'
```

Confidence: **0.9** — delimiters and comma separation are very diagnostic.

Edge case: `(see also Smith, 2020)` — the leading phrase triggers a secondary claim capture with the surrounding sentence.

#### Pattern Family 3: "According to" / Phrase Attributions
Matches: `according to X`, `as shown by X`, `as argued by X`, `as noted by X`, `as claimed by X`, `as demonstrated by X`, `as stated by X`

```bash
# Regex (ERE, case-insensitive)
'(according to|as (shown|argued|noted|claimed|demonstrated|stated|discussed|reported|suggested|proposed|described) (by|in))[^,\.;]{3,60}'
```

Confidence: **0.7** — phrase is reliable but the captured "source" substring requires further normalization (may be an author name or a title fragment).

#### Pattern Family 4: Theorem / Lemma Attributions
Matches: `Theorem 3 (Smith, 2020)`, `Lemma 2.4 [Jones 2019]`, `by the Smith-Jones theorem`

```bash
# Regex (ERE)
'(Theorem|Lemma|Proposition|Corollary|Definition|Conjecture)[[:space:]]+[0-9]+(\.[0-9]+)*[[:space:]]*[\(\[][A-Z][a-z]+.*?[\)\]]'
# OR
'by (the )?[A-Z][a-z]+(-[A-Z][a-z]+)? (theorem|lemma|conjecture|inequality)'
```

Confidence: **0.9** for bracketed attributions, **0.7** for eponymous references (no explicit year).

#### Pattern Family 5: Direct Quotes with Attribution
Matches: `"quoted text" (Smith 2020)`, `"quoted text" [Smith 2020]`, `"quoted text" -- Author`

```bash
# Regex (ERE)
'"[^"]{10,200}"[[:space:]]*[\(\[][^)\]]{3,50}[\)\]]'
# OR em-dash attribution
'"[^"]{10,200}"[[:space:]]*--[[:space:]]*[A-Z][a-z]+'
```

Confidence: **0.85** — quoted text with trailing citation is very specific; em-dash attribution without a year is lower confidence (0.6).

#### Pattern Family 6: Bracketed Numeric / Alpha-Numeric
Matches: `[1]`, `[42]`, `[Smith20]`, `[SJ19]`

```bash
# Numeric
'\[[0-9]{1,3}\]'
# Alpha-numeric key
'\[[A-Z][a-zA-Z]{2,8}[0-9]{2,4}\]'
```

Confidence: **0.5** for bare numerics (context-dependent; many false positives from markdown syntax), **0.7** for alpha-numeric keys.

Note: Bare `[1]` should be suppressed when the surrounding context is a markdown link pattern `[text](url)` or `[text][ref]`. A negative lookahead is needed:

```bash
# Exclude markdown links: [N] not followed by ( or ]
'\[[0-9]{1,3}\](?!\(|[A-Za-z])'
# Use grep -P for Perl-compatible regex, or post-filter with awk
```

### Confidence Scoring Methodology

| Score | Criterion |
|-------|-----------|
| 0.9 | Named author + explicit 4-digit year, unambiguous delimiter |
| 0.85 | Quoted text with bracketed citation |
| 0.7 | Phrase attribution (no year), eponymous theorem, alpha-numeric key |
| 0.5 | Bare numeric bracket, ambiguous context |

Scores are hard-coded per pattern family. No runtime scoring computation is needed; the pattern match itself determines the confidence tier.

### JSON Output Schema

```json
[
  {
    "claim": "The full sentence or clause containing the citation",
    "source_text": "Smith 2020",
    "line_number": 42,
    "confidence": 0.9,
    "pattern_type": "author_year"
  }
]
```

Field definitions:
- `claim`: The surrounding sentence extracted by capturing up to the nearest sentence boundary (`.`, `\n`, or 200 chars max) around the match. Trimmed of leading/trailing whitespace.
- `source_text`: The matched citation string itself (not the full sentence).
- `line_number`: 1-indexed line number in the input where the match was found.
- `confidence`: Float in [0.5, 0.9] per pattern family table above.
- `pattern_type`: One of `author_year`, `parenthetical`, `phrase_attribution`, `theorem_attribution`, `direct_quote`, `numeric_bracket`.

### Implementation Approach

**Recommended: grep-per-pattern pipeline**

Run `grep -nEP` (Perl regex for lookahead) once per pattern family, capture the line number and matched text, then use awk to extract the surrounding sentence context, then build the JSON array with jq.

```bash
# Per-pattern loop structure
declare -A PATTERNS
declare -A PATTERN_TYPES
declare -A PATTERN_CONFIDENCE

PATTERNS[author_year]='[A-Z][a-z]+(( and | & )[A-Z][a-z]+| et al\.?)?,? (19|20)[0-9]{2}[a-z]?'
PATTERN_TYPES[author_year]="author_year"
PATTERN_CONFIDENCE[author_year]="0.9"
# ... more patterns

RESULTS='[]'
for key in "${!PATTERNS[@]}"; do
  while IFS=: read -r linenum match_line; do
    # Extract source_text via sed match
    # Extract claim (surrounding context)
    # Build JSON object
    RESULTS="$(echo "$RESULTS" | jq --arg claim "$claim" --arg src "$source_text" \
      --argjson ln "$linenum" --argjson conf "${PATTERN_CONFIDENCE[$key]}" \
      --arg ptype "${PATTERN_TYPES[$key]}" \
      '. + [{"claim": $claim, "source_text": $src, "line_number": $ln, "confidence": $conf, "pattern_type": $ptype}]')"
  done < <(grep -nEP "${PATTERNS[$key]}" "$INPUT_FILE" 2>/dev/null || true)
done
```

**Stdin handling:**

```bash
if [[ -n "${1:-}" && "$1" != -* ]]; then
  INPUT_FILE="$1"
else
  INPUT_FILE=$(mktemp)
  cat > "$INPUT_FILE"
  CLEANUP_TMPFILE=true
fi
```

**Deduplication:** After all patterns run, sort the results array by line_number and remove exact-duplicate `{line_number, source_text}` pairs with jq `unique_by(.line_number, .source_text)`.

**Output sort:** Sort by `line_number` ascending.

### Edge Cases and Limitations

| Edge Case | Behavior |
|-----------|----------|
| Multi-author `(A, B, C, 2020)` | Matched by parenthetical pattern; full author list included in `source_text` |
| `et al.` without year | Phrase-attribution confidence (0.7); no year means no parenthetical match |
| `ibid.` / `op. cit.` | Not matched by any pattern; would require a separate low-confidence (0.4) pattern — recommended to exclude in v1 |
| Year ranges `2019-2021` | Not matched by single-year patterns; exclude in v1 |
| Footnote numbers `^1` | Not matched (superscript notation, not bracketed) |
| Markdown `[text](url)` | Excluded by negative lookahead in numeric-bracket pattern |
| LaTeX `\cite{key}` | Not matched by text patterns; a dedicated pattern `\\cite\{[^}]+\}` would add it; confidence 0.9 |
| HTML `<ref>` tags | Not matched; out of scope for v1 |
| Lines > 500 chars | `grep` handles gracefully; `claim` field truncated to 200 chars |

**LaTeX cite pattern** (recommended addition for v1, since the script may process .tex files):

```bash
PATTERNS[latex_cite]='\\cite(\[[^\]]*\])?\{[^}]+\}'
PATTERN_CONFIDENCE[latex_cite]="0.9"
```

### Script Architecture

```
cite-extract.sh
  |
  +-- Argument parsing (--format, --confidence, -h)
  |     --format=json|pretty  (default: json)
  |     --min-confidence=N    (default: 0.5, filter by confidence tier)
  |
  +-- Input resolution (file path or stdin -> tmpfile)
  |
  +-- Pattern loop (6-7 patterns, grep -nEP per pattern)
  |     -> collect raw matches with line numbers
  |
  +-- Context extraction (awk, extract surrounding sentence)
  |
  +-- JSON assembly (jq, build array)
  |
  +-- Deduplication (jq unique_by)
  |
  +-- Confidence filter (jq select)
  |
  +-- Output (json or pretty)
  |
  +-- Cleanup (tmpfile if stdin)
```

## Decisions

1. Use `grep -nEP` (Perl-compatible) for lookahead support in the numeric-bracket pattern. GNU grep on Linux supports `-P`; document the dependency.
2. Hard-code confidence per pattern family (no runtime scoring) — keeps the script simple and deterministic.
3. Include LaTeX `\cite{}` as a pattern family in v1 — the script processes .tex and .md files and LaTeX citations are unambiguous.
4. Exclude `ibid.`/`op. cit.` from v1 — marginal utility, high false-positive risk.
5. Exclude year-range citations from v1 — uncommon enough to not warrant the regex complexity.
6. `--min-confidence` filter applied at output time via jq, not during pattern matching — simpler logic.
7. Deduplication by `(line_number, source_text)` only — same citation style on same line is a duplicate, but different citations on the same line are kept.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `grep -P` unavailable (macOS default grep) | Document that GNU grep is required; add guard `grep --version | grep -q GNU` with error message |
| Very large files (>10MB) slow grep loop | Add optional `--max-lines=N` flag in v1 or document limitation |
| False positives from numeric brackets in markdown | Negative lookahead pattern; additionally, detect markdown context by checking for `[text](` patterns on the same line |
| jq not installed | Guard at startup: `command -v jq >/dev/null 2>&1 \|\| { echo "Error: jq required" >&2; exit 1; }` |
| Overlapping pattern matches inflate output | Deduplication step removes exact duplicates; overlapping with different source_text is intentional (multiple citations on one line) |

## Appendix

### Search Queries Used
- Codebase: `zotero-search.sh` — coding conventions, argument parsing, jq style
- Citation pattern analysis: academic writing conventions (APA, MLA, Chicago, IEEE, LaTeX)

### References
- APA author-year: `(Author, Year)` and `Author (Year)`
- IEEE numeric: `[N]`
- Chicago/Turabian: footnote + bibliography (footnote markers not matched)
- LaTeX: `\cite{key}`, `\cite[p. 45]{key}`
- Math: `Theorem 3.2 (Author Year)`, eponymous theorems
