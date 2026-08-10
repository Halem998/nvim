# Implementation Plan: Create cite-extract.sh

- **Task**: 716 - Create cite-extract.sh script for citation claim extraction
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/716_create_cite_extract_script/reports/01_cite-extract-research.md
- **Artifacts**: plans/01_cite-extract-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a single bash script at `.claude/extensions/literature/scripts/cite-extract.sh` that detects citation patterns in text and outputs a JSON array of extracted claims. The script follows coding conventions from `zotero-search.sh` (shebang, `set -euo pipefail`, `show_usage()`, option parsing, jq-based JSON output). Six pattern families cover author-year, parenthetical, phrase attribution, theorem attribution, direct quotes, and numeric/alpha-numeric brackets, plus an optional LaTeX `\cite{}` pattern. Confidence is hard-coded per pattern family (0.5-0.9).

### Research Integration

The research report identified six citation pattern families with ERE/PCRE regexes, a grep-per-pattern pipeline architecture, deduplication by `(line_number, source_text)`, and `--min-confidence`/`--format` CLI options. All recommendations are incorporated into this plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `cite-extract.sh` with all seven pattern families (6 core + LaTeX cite)
- Accept input from file path argument or stdin
- Output JSON array of `{claim, source_text, line_number, confidence, pattern_type}`
- Support `--format=json|pretty`, `--min-confidence=N`, `-h/--help`
- Deduplicate results by `(line_number, source_text)`
- Follow `zotero-search.sh` coding conventions exactly

**Non-Goals**:
- Matching `ibid.`/`op. cit.` or year-range citations
- Matching footnote superscripts or HTML `<ref>` tags
- Runtime confidence scoring (hard-coded per pattern is sufficient)
- Integration with `skill-cite` (separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `grep -P` unavailable on some systems | H | L | Guard with `grep --version` check; document GNU grep dependency |
| False positives from numeric brackets in markdown | M | M | Negative lookahead via `-P`; post-filter markdown link patterns |
| jq not installed | H | L | Guard at startup with `command -v jq` check |
| Large files slow the per-pattern grep loop | L | L | Document limitation; script is for analysis not bulk processing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create cite-extract.sh [COMPLETED]

**Goal**: Write the complete script with all pattern families, argument parsing, JSON output, and deduplication.

**Tasks**:
- [ ] Create file at `.claude/extensions/literature/scripts/cite-extract.sh`
- [ ] Add shebang (`#!/usr/bin/env bash`), `set -euo pipefail`, and header comment block matching zotero-search.sh style (USAGE, DESCRIPTION, OPTIONS, EXIT CODES)
- [ ] Implement `show_usage()` function using `cat >&"$fd"` pattern
- [ ] Implement argument parsing loop (`for arg in "$@"`) with:
  - `--format=json|pretty` (default: json)
  - `--min-confidence=N` (default: 0.5, float in [0.0, 1.0])
  - `-h`/`--help`
  - Positional argument = file path
- [ ] Implement dependency guards: check `jq` and `grep -P` availability at startup
- [ ] Implement input resolution: file path argument or stdin piped to tmpfile, with cleanup trap
- [ ] Define pattern arrays using associative arrays:
  - `author_year` (confidence 0.9): `[A-Z][a-z]+(( and | & )[A-Z][a-z]+| et al\.?)?,? (19|20)[0-9]{2}[a-z]?`
  - `parenthetical` (confidence 0.9): `\([A-Z][a-z]+(,? (and|&) [A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}[a-z]?(, p\.? ?[0-9]+)?\)`
  - `phrase_attribution` (confidence 0.7): `(according to|as (shown|argued|noted|claimed|demonstrated|stated|discussed|reported|suggested|proposed|described) (by|in))[^,\.;]{3,60}` (case-insensitive)
  - `theorem_attribution` (confidence 0.9 for bracketed, 0.7 for eponymous): split into two sub-patterns
  - `direct_quote` (confidence 0.85 for bracketed, 0.6 for em-dash): split into two sub-patterns
  - `numeric_bracket` (confidence 0.5): `\[[0-9]{1,3}\]` with negative lookahead `(?!\()` to exclude markdown links
  - `alpha_numeric_bracket` (confidence 0.7): `\[[A-Z][a-zA-Z]{2,8}[0-9]{2,4}\]`
  - `latex_cite` (confidence 0.9): `\\cite(\[[^\]]*\])?\{[^}]+\}`
- [ ] Implement grep-per-pattern loop:
  - For each pattern, run `grep -nEP` (or `grep -niEP` for case-insensitive patterns)
  - Parse output as `linenum:matched_line`
  - Extract `source_text` by re-matching the pattern on the matched line
  - Extract `claim` as the full line content, truncated to 200 chars
- [ ] Implement JSON assembly using jq:
  - Build result objects with `claim`, `source_text`, `line_number`, `confidence`, `pattern_type`
  - Accumulate into a JSON array
- [ ] Implement deduplication: sort by `line_number`, then `unique_by(.line_number, .source_text)` via jq
- [ ] Implement confidence filter: `jq select(.confidence >= $min_conf)`
- [ ] Implement output formatting:
  - `json`: pipe through `jq '.'`
  - `pretty`: tabular output with LINE, CONFIDENCE, TYPE, SOURCE, CLAIM columns
- [ ] Implement exit codes: 0 = results found, 1 = setup/validation error, 2 = no results
- [ ] Make script executable: `chmod +x`

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/cite-extract.sh` - Create new file

**Verification**:
- Script passes `bash -n cite-extract.sh` syntax check
- `--help` prints usage and exits 0
- Missing `jq` or `grep -P` detected at startup

---

### Phase 2: Test with Sample Inputs [COMPLETED]

**Goal**: Verify all pattern families detect citations correctly and output is valid JSON.

**Tasks**:
- [ ] Create a test input file with at least one example per pattern family:
  - Author-year: `Smith 2020 showed that...`
  - Parenthetical: `...as shown (Smith, 2020)`
  - Phrase attribution: `According to Jones, the method...`
  - Theorem attribution: `Theorem 3.2 (Smith, 2020) states...`
  - Direct quote: `"The result is clear" (Smith 2020)`
  - Numeric bracket: `The method [42] improves...`
  - Alpha-numeric bracket: `As shown in [Smith20]...`
  - LaTeX cite: `As shown in \cite{Smith2020}...`
- [ ] Run script against test file and verify JSON output parses with `jq`
- [ ] Verify each pattern type appears in output with correct confidence tier
- [ ] Test `--min-confidence=0.8` filters out low-confidence results
- [ ] Test `--format=pretty` produces tabular output
- [ ] Test stdin input: `echo "Smith 2020" | bash cite-extract.sh`
- [ ] Test empty input returns exit code 2 and empty array
- [ ] Test markdown false-positive suppression: `[link](url)` should not match numeric bracket
- [ ] Clean up test file after verification

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- (temporary test file only, cleaned up after verification)

**Verification**:
- All seven pattern families produce at least one match
- JSON output is valid (parses with `jq .`)
- Confidence filtering works correctly
- No false positives from markdown link syntax

## Testing & Validation

- [ ] `bash -n cite-extract.sh` passes (syntax check)
- [ ] Script detects all seven citation pattern families
- [ ] JSON output validates with `jq .`
- [ ] `--min-confidence` filtering works
- [ ] `--format=pretty` produces readable table
- [ ] stdin and file path input both work
- [ ] Exit code 2 on no results
- [ ] Markdown `[text](url)` patterns do not trigger false positives

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/cite-extract.sh` - The citation extraction script
- `specs/716_create_cite_extract_script/plans/01_cite-extract-plan.md` - This plan

## Rollback/Contingency

Delete `.claude/extensions/literature/scripts/cite-extract.sh` to fully revert. No existing files are modified.
