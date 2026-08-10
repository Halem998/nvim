# Implementation Plan: Task #720

- **Task**: 720 - Integration testing and bug fixes for /cite command
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/720_integration_test_cite_command/reports/01_integration-test-research.md
- **Artifacts**: plans/01_integration-test-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix three bugs discovered during integration testing of the /cite command pipeline. Bug 1 adds the missing Author(Year) citation pattern to cite-extract.sh. Bug 2 fixes the LITERATURE_DIR environment variable being ignored in skill-cite SKILL.md. Bug 3 makes the theorem_attr_ref pattern case-insensitive so sentence-initial "By Lemma 2.1" is detected. After fixes, re-run integration tests to verify all patterns and the full pipeline.

### Research Integration

Key findings from the research report:
- cite-extract.sh detects 7 of 8 documented pattern families correctly; the "Author (Year)" inline format (e.g., `Blackburn (2002)`) is missed entirely
- skill-cite SKILL.md hardcodes `$project_root/specs/literature/index.json` at Step 6, ignoring the `LITERATURE_DIR` env var that skill-literature uses as primary lookup
- theorem_attr_ref pattern uses flags `P` without `i`, so sentence-initial "By Lemma 2.1" fails to match
- Zotero graceful degradation confirmed working; confidence scoring confirmed correct; AskUserQuestion flow and task creation confirmed compliant

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Literature centralization" roadmap item (Phase 2, marked completed for task 710) by ensuring the LITERATURE_DIR two-tier fallback is consistently applied in skill-cite, not just skill-literature.

## Goals & Non-Goals

**Goals**:
- Fix the missing Author(Year) citation pattern in cite-extract.sh
- Fix LITERATURE_DIR env var handling in skill-cite SKILL.md
- Fix case sensitivity in theorem_attr_ref pattern
- Verify all fixes pass integration tests

**Non-Goals**:
- Refactoring other patterns or the overall cite-extract.sh architecture
- Adding new pattern families beyond the Author(Year) fix
- Fixing the cosmetic theorem_attr_bracket truncation (non-functional)
- Modifying Zotero integration behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New Author(Year) pattern causes false positives | M | L | Test with varied inputs; deduplication handles overlaps with existing patterns |
| LITERATURE_DIR fallback breaks when env var unset | M | L | Use `${LITERATURE_DIR:-}` with explicit empty check, matching skill-literature |
| Case-insensitive theorem_attr_ref matches unwanted text | L | L | Pattern is already scoped to known keywords (Theorem/Lemma/etc.) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix cite-extract.sh patterns [COMPLETED]

**Goal**: Add the missing Author(Year) pattern and fix theorem_attr_ref case sensitivity.

**Tasks**:
- [ ] Add `author_paren_year` pattern entry to the PATTERNS array in cite-extract.sh, after the existing `author_year` entry. Pattern: `"author_paren_year|0.9|P|[A-Z][a-z]+(( and | & )[A-Z][a-z]+|,? et al\.?)? \((19|20)[0-9]{2}[a-z]?\)"` with confidence 0.9
- [ ] Change the `theorem_attr_ref` pattern flags from `P` to `Pi` to enable case-insensitive matching
- [ ] Update the script header comment to mention the new `author_paren_year` pattern family (pattern count becomes 9)
- [ ] Test: run `echo 'Blackburn (2002) showed this.' | bash cite-extract.sh` and verify `author_paren_year` is detected
- [ ] Test: run `echo 'By Lemma 2.1, the result holds.' | bash cite-extract.sh` and verify `theorem_attr_ref` matches

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/cite-extract.sh` - Add pattern, fix flags, update header

**Verification**:
- `echo 'Blackburn (2002) showed this.' | bash cite-extract.sh --format=pretty` shows `author_paren_year` detection
- `echo 'By Lemma 2.1, the result holds.' | bash cite-extract.sh --format=pretty` shows `theorem_attr_ref` detection
- `echo 'Smith (2020) and Kripke (1963) agree.' | bash cite-extract.sh --format=pretty` shows two `author_paren_year` matches
- Existing patterns still pass (run full test input from research report)

---

### Phase 2: Fix LITERATURE_DIR handling in skill-cite SKILL.md [COMPLETED]

**Goal**: Make skill-cite use the same two-tier LITERATURE_DIR fallback as skill-literature.

**Tasks**:
- [ ] In SKILL.md Step 6, replace the hardcoded `lit_index="$project_root/specs/literature/index.json"` with a two-tier fallback that checks `LITERATURE_DIR` first
- [ ] The replacement logic should be:
  ```
  if [ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]; then
    lit_index="$LITERATURE_DIR/index.json"
  else
    lit_index="$project_root/specs/literature/index.json"
  fi
  ```
- [ ] Verify the `index_available` check that follows still works with the new path
- [ ] Verify the `score_against_index` function uses `$lit_index` consistently (not a hardcoded path)

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/skills/skill-cite/SKILL.md` - Fix Step 6 index path resolution

**Verification**:
- With `LITERATURE_DIR=~/Projects/Literature` set, skill-cite Step 6 would resolve to `~/Projects/Literature/index.json`
- With `LITERATURE_DIR` unset, skill-cite falls back to `$project_root/specs/literature/index.json`
- The `index_available` flag correctly reflects whether the resolved path exists

---

### Phase 3: Integration test verification [COMPLETED]

**Goal**: Run end-to-end integration tests to confirm all three bugs are fixed and no regressions introduced.

**Tasks**:
- [ ] Run cite-extract.sh with the full test input from the research report (all 8+ pattern families) and verify all patterns detected
- [ ] Run cite-extract.sh with Author(Year) variants: `Smith (2020)`, `Kripke (1963)`, `Jones et al. (2019)`
- [ ] Run cite-extract.sh with case variants for theorem_attr_ref: `by Lemma 2.1`, `By Lemma 2.1`, `FROM Theorem 3`
- [ ] Verify `--min-confidence` filtering still works correctly
- [ ] Verify deduplication still works (parenthetical and author_year patterns on same input should deduplicate)
- [ ] Spot-check skill-cite SKILL.md for internal consistency (Step 6 path used in later steps)
- [ ] Run cite-extract.sh on a real task artifact (e.g., task 716 report) and compare result count to research baseline (26 citations)

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (test-only phase)

**Verification**:
- All test commands exit 0 with expected output
- No regressions in existing pattern detection
- Real artifact scan produces >= 26 citations (may increase due to new Author(Year) pattern)

## Testing & Validation

- [ ] cite-extract.sh detects `Blackburn (2002)` as `author_paren_year` with confidence 0.9
- [ ] cite-extract.sh detects `By Lemma 2.1` as `theorem_attr_ref` with confidence 0.7
- [ ] All 8 original pattern families still pass their test cases from the research report
- [ ] `--min-confidence` filtering excludes low-confidence patterns correctly
- [ ] Deduplication by (line_number, source_text) still works
- [ ] skill-cite SKILL.md Step 6 resolves LITERATURE_DIR when set
- [ ] skill-cite SKILL.md Step 6 falls back to specs/literature/ when LITERATURE_DIR unset

## Artifacts & Outputs

- `specs/720_integration_test_cite_command/plans/01_integration-test-plan.md` (this file)
- Modified: `.claude/extensions/literature/scripts/cite-extract.sh`
- Modified: `.claude/extensions/literature/skills/skill-cite/SKILL.md`

## Rollback/Contingency

All changes are to two files. Revert with `git checkout -- .claude/extensions/literature/scripts/cite-extract.sh .claude/extensions/literature/skills/skill-cite/SKILL.md` if issues arise. The new `author_paren_year` pattern is additive and can be removed from the PATTERNS array independently.
