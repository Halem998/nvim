# Research Report: Task #720

**Task**: 720 - Integration testing and verification of /cite command end-to-end
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:30:00Z
**Effort**: ~1 hour
**Dependencies**: cite-extract.sh, zotero-search.sh, skill-cite SKILL.md
**Sources/Inputs**: Codebase (scripts, SKILL.md, command file), live test execution
**Artifacts**: specs/720_integration_test_cite_command/reports/01_integration-test-research.md
**Standards**: report-format.md

---

## Executive Summary

- `cite-extract.sh` is functional and detects 7 of 8 documented pattern families correctly
- **Critical bug**: The "Author (Year)" inline format (e.g., `Blackburn (2002)`) is not detected by any pattern
- `zotero-search.sh` degrades gracefully when library is absent (exit code 1 with clear instructions)
- `specs/literature/index.json` does not exist in this project; skill-cite will fall back to Zotero-only matching (and both will be unavailable)
- The `LITERATURE_DIR` env var points to `~/Projects/Literature` where an `index.json` exists, but `skill-cite` hardcodes `$project_root/specs/literature/index.json` — a mismatch
- `skill-cite` SKILL.md is well-structured with correct error handling and multi-task creation compliance
- The `/cite` command argument parsing and delegation structure is correct

---

## Context & Scope

Tested the full `/cite` command pipeline for task 720 integration testing. Verified:

1. `cite-extract.sh` pattern families via live shell execution
2. `zotero-search.sh` graceful degradation
3. `specs/literature/` availability and index path correctness
4. Real task artifact scanning (task 716 report)
5. `skill-cite` SKILL.md for workflow correctness

Project root: `/home/benjamin/.config/nvim`

---

## Findings

### cite-extract.sh Test Results

**Test input**:
```
Smith (2020) showed that the method works. According to Jones et al. (2019), this is correct.
See Theorem 3.2 (Brown). "The result holds" (White, 2021).
```

**Detected**:
- `direct_quote_bracket`: `"The result holds" (White, 2021)` — confidence 0.85 ✓
- `parenthetical`: `(White, 2021)` — confidence 0.9 ✓
- `phrase_attribution`: `According to Jones et al` — confidence 0.7 ✓
- `theorem_attr_bracket`: `Theorem 3.2 (Br` — confidence 0.9 ✓
- `author_year`: `White, 2021` — confidence 0.9 ✓

**Missing from detection**: `Smith (2020)` (Author Year in parentheses inline format)

---

### Pattern Family Results

| Pattern Family | Test Input | Detected | Status |
|----------------|-----------|----------|--------|
| `author_year` | `Smith 2020`, `Smith et al. 2019`, `Jones and Brown 2019` | Yes | **PASS** |
| `parenthetical` | `(Smith, 2020)`, `(Black & White, 2021)`, `(Smith et al., 2019)` | Yes | **PASS** |
| `phrase_attribution` | `According to Jones et al. (2019)`, `As shown by Smith 2020` | Yes | **PASS** (case-insensitive via -i flag) |
| `theorem_attr_bracket` | `Theorem 3.2 (Brown)` | Yes | **PASS** |
| `theorem_attr_ref` | `by Lemma 2.1`, `from Theorem 3` | Yes (lowercase `by` only) | **PARTIAL** — `By Lemma 2.1` (sentence-initial capital) not detected |
| `direct_quote_bracket` | `"The result holds" (White, 2021)` | Yes | **PASS** |
| `direct_quote_dash` | `"The result holds" — Smith` | Yes | **PASS** |
| `numeric_bracket` | `[42]` | Yes (excludes markdown links) | **PASS** |
| `alpha_num_bracket` | `[Smith20]` | Yes | **PASS** |
| `latex_cite` | `\cite{key}`, `\cite[p.42]{key}` | Yes | **PASS** |

**Undocumented gap** (not in the 8 pattern families):
- `author_paren_year`: `Blackburn (2002)`, `Smith (2020)` — inline author-year with parenthesized year
  - This is one of the most common academic citation styles
  - The current regex requires a comma or space directly before the year digits
  - `Blackburn (2002)` fails because `(` is not in the optional preceding characters
  - **Fix**: add `\([0-9]{4}\)` variant or extend `author_year` regex to allow `\((19|20)[0-9]{2}\)`

---

### Zotero Library Availability

- **Library file**: `~/Projects/Literature/zotero-library.json` — **NOT FOUND**
- **ZOTERO_LIBRARY env**: not set
- **LITERATURE_DIR env**: set to `/home/benjamin/Projects/Literature`
- `zotero-search.sh` exits with code 1 and prints clear setup instructions (graceful degradation confirmed)
- In `skill-cite` Step 7, `zotero_available` will be set to `false`; verification will proceed with index-only matching

**Status**: Zotero unavailable — graceful degradation works correctly.

---

### Literature Index Availability

- **`specs/literature/index.json`** (path used by `skill-cite`): **NOT FOUND** — `specs/literature/` directory does not exist in this project
- **`~/Projects/Literature/index.json`** (LITERATURE_DIR path): **EXISTS** with 2+ entries (modal logic books)
- **Architecture mismatch**: `skill-cite` hardcodes `$project_root/specs/literature/index.json` (line 171 of SKILL.md), while `skill-literature` uses a two-tier fallback (checks `LITERATURE_DIR` first, then `specs/literature/`)

**Bug**: `skill-cite` does not respect `LITERATURE_DIR`. It will always report `index_available=false` in environments where `LITERATURE_DIR` is set and `specs/literature/` doesn't exist locally. The actual literature index at `~/Projects/Literature/index.json` is never searched.

**Fix**: Update `skill-cite` Step 6 to use the same two-tier fallback as `skill-literature`:
```bash
if [ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]; then
  lit_index="$LITERATURE_DIR/index.json"
else
  lit_index="$project_root/specs/literature/index.json"
fi
```

---

### Real Artifact Scan Test

Ran `cite-extract.sh` on `specs/716_create_cite_extract_script/reports/01_cite-extract-research.md`:

- Found 26 citation patterns across the file
- Correctly detected: `author_year`, `parenthetical`, `phrase_attribution`, `theorem_attr_bracket`, `direct_quote_bracket`, `numeric_bracket`, `alpha_num_bracket`, `latex_cite`
- All detected patterns are from example code blocks in the research document itself
- Exit code 0 (success)

---

### Confidence Scoring

- `--min-confidence=N` flag works correctly
- At 0.7: filters out `numeric_bracket` (0.5) and leaves `author_year` (0.9)
- Hard-coded confidence values per pattern are correct and reasonable
- `direct_quote_dash` at 0.6 is below default threshold of 0.5 — all patterns pass default

---

### Identified Bugs and Issues

#### Bug 1: "Author (Year)" Pattern Not Detected (High Severity)

**Description**: The very common `Author (Year)` academic citation format is not matched by any pattern.

**Examples that fail**:
- `Blackburn (2002) showed...`
- `Smith (2020) argued...`
- `Kripke (1963) proposed...`

**Root cause**: `author_year` regex `[A-Z][a-z]+(( and | & )[A-Z][a-z]+|,? et al\.?)?,? (19|20)[0-9]{2}` requires a comma or bare space before the year. A parenthesized year `(2002)` does not match.

**Fix**: Add a new pattern `author_paren_year` or extend the existing regex to also accept `\((19|20)[0-9]{2}[a-z]?\)`:
```
"author_paren_year|0.9|P|[A-Z][a-z]+(( and | & )[A-Z][a-z]+|,? et al\.?)? \((19|20)[0-9]{2}[a-z]?\)"
```

#### Bug 2: LITERATURE_DIR Not Respected in skill-cite (Medium Severity)

**Description**: `skill-cite` SKILL.md Step 6 hardcodes `$project_root/specs/literature/index.json` but `skill-literature` uses `LITERATURE_DIR` as primary lookup. When LITERATURE_DIR is set (as it is in this environment), the real literature index is bypassed.

**Fix**: Update `skill-cite` Step 6 to use two-tier fallback identical to `skill-literature` Step 2.

#### Bug 3: theorem_attr_ref Case Sensitivity (Low Severity)

**Description**: `theorem_attr_ref` pattern requires lowercase `by|from|using|applying|via`. Sentence-initial `By Lemma 2.1` is not detected.

**Root cause**: Pattern flags are `P` (PCRE) without `i` (case-insensitive).

**Fix**: Change pattern flags from `P` to `Pi` for `theorem_attr_ref`.

#### Non-bug: source_text truncation in theorem_attr_bracket

`theorem_attr_bracket` source_text shows `Theorem 3.2 (Br` — truncated mid-word. This is because `grep -oP` extracts only the matched portion, and the regex `(Theorem|...) [0-9]+(\.[0-9]+)* \([A-Z][a-z]` only matches through the first two characters of the author name (the regex anchors the match with `\([A-Z][a-z]` as a lookahead check). This truncated source_text is used for keyword searching and is slightly misleading. Not a functional bug but cosmetically poor.

---

### AskUserQuestion multiSelect Assessment

Reviewed `skill-cite` SKILL.md Steps 10.1 and 10.2:
- Standard case (<=20 items): correct multiSelect format
- Large case (>20 items): adds "Select all" option — correct
- Partial matches presented as separate prompt (Step 10.2) — correct
- Empty selection gracefully exits — correct

**Assessment**: AskUserQuestion flow is correctly structured per multi-task creation standard.

---

### Task Creation Assessment

Reviewed `skill-cite` SKILL.md Steps 11–13:
- Uses `next_project_number` from `state.json` — correct
- Two-step jq pattern (avoids Issue #1132) — correct
- `generate-todo.sh` called non-blocking — correct
- Git commit scoped to `specs/TODO.md specs/state.json` — correct

**Compliance with multi-task creation standard**: Partial (documented as intended):
- Item Discovery: ✓ (cite-extract.sh)
- Interactive Selection: ✓ (AskUserQuestion multiSelect)
- User Confirmation: ✓ (implicit via selection)
- State Updates: ✓ (atomic state.json + generate-todo.sh)

---

## Decisions

- The "Author (Year)" pattern gap is a functional bug, not a design omission — should be fixed
- LITERATURE_DIR mismatch in skill-cite is a real integration bug — should be fixed
- theorem_attr_ref case sensitivity is low-priority cosmetic fix
- No issues with the `/cite` command argument parsing or delegation to skill-cite

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Author (Year) citations missed in academic writing | High | Add `author_paren_year` pattern |
| Literature index never searched when LITERATURE_DIR set | Medium | Two-tier fallback in skill-cite |
| False positives from numeric_bracket in markdown docs | Low | Already excluded with `(?!\()` lookahead |
| Double-counting: parenthetical + author_year both fire | Low | Deduplication by (line_number, source_text) handles correctly |

---

## Appendix

### Search Queries Used
- Codebase grep: `cite-extract.sh`, `zotero-search.sh`, `SKILL.md`, `cite.md`
- Live test commands: 8 distinct test inputs with `cite-extract.sh`
- File scan: `specs/716_create_cite_extract_script/reports/01_cite-extract-research.md`

### Key File Paths
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/cite-extract.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/scripts/zotero-search.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/skills/skill-cite/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/literature/commands/cite.md`
- `/home/benjamin/Projects/Literature/index.json` (exists, LITERATURE_DIR-based)
- `specs/literature/index.json` (does NOT exist)
- `~/Projects/Literature/zotero-library.json` (does NOT exist)
