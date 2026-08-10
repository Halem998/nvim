# Implementation Plan: Task #802

- **Task**: 802 - Guard skill-literature authors resolver against string-to-first-char truncation
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None (follow-up to task 801, parent_task=801)
- **Research Inputs**: specs/802_literature_authors_first_char_truncation_guard/reports/01_authors_first_char_truncation_guard.md
- **Artifacts**: plans/01_authors-truncation-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Apply a single-line, type-aware jq fix to `.claude/skills/skill-literature/SKILL.md:1696`. The current `(.authors // []) | first // "?"` filter silently truncates a string-typed `.authors` value to its first character, because jq's `first` on a JSON string returns the first char rather than erroring, and `// []` only guards `null`/`false`. Research confirmed line 1696 is the only occurrence of this pattern. The fix is a verbatim string replacement plus a jq sanity check.

### Research Integration

The research report supplies the exact current text, the exact replacement text, and grep evidence that no other occurrence of the `first`-on-`.authors` footgun exists in the file. The type-aware `if/elif/else` replacement subsumes the old `// []` null guard (the `else` branch returns `"?"` for null/missing), so no fallback is lost. The replacement was pre-validated during planning: a string value yields the full name, an array value yields its first element.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided; roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- Replace the buggy jq filter at SKILL.md:1696 with the type-aware expression.
- Verify string-typed and array-typed `.authors` both resolve correctly.

**Non-Goals**:
- Touching the `join(", ")` authors resolvers (lines 1332, 1338, 1456) — different failure mode, out of scope.
- Modifying the task-801 validation logic (lines 407-441), which is already type-aware and correct.
- Any refactor, test-harness addition, or changes to other files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typo when transcribing the jq expression | L | L | Copy the replacement text verbatim from the report; run the jq dry-run check in the Verification step |
| Editing the wrong `authors=` line | L | L | The `old_string` includes the full unique `(.authors // []) | first // "?"` fragment, which appears only once in the file |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Single phase; no parallelism.

### Phase 1: Apply type-aware authors resolver [COMPLETED]

**Goal**: Replace the truncating jq filter with the type-aware expression and confirm both input shapes resolve correctly.

**Tasks**:
- [x] In `.claude/skills/skill-literature/SKILL.md` at line 1696, replace the jq filter argument `.entries[] | select(.id == $id) | (.authors // []) | first // "?"` with `.entries[] | select(.id == $id) | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end`, leaving the surrounding `authors=$(jq -r --arg id "$doc_id" '...' "$global_index" 2>/dev/null | head -1)` wrapper unchanged. *(completed: also applied to the hardlinked `.claude/extensions/literature/skills/skill-literature/SKILL.md` copy — same inode, edit was automatically reflected in both)*
- [x] Run the jq sanity check for both a string-typed and an array-typed `.authors` value. *(completed: string case -> "Yde Venema", array case -> "A. Author")*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-literature/SKILL.md` (line 1696) - swap the single jq filter string; no surrounding bash changes.

**Verification**:
- String case yields the full name:
  ```bash
  echo '{"entries":[{"id":"x","authors":"Yde Venema"}]}' | jq -r '.entries[] | select(.id == "x") | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end'
  # expected: Yde Venema
  ```
- Array case yields the first element:
  ```bash
  echo '{"entries":[{"id":"x","authors":["A. Author","B. Coauthor"]}]}' | jq -r '.entries[] | select(.id == "x") | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end'
  # expected: A. Author
  ```
- Confirm the SKILL.md file no longer contains the substring `(.authors // []) | first`.

---

## Testing & Validation

- [ ] String-typed `.authors` returns the full author name (not a single character).
- [ ] Array-typed `.authors` returns the first element.
- [ ] `grep -c '(.authors // \[\]) | first' .claude/skills/skill-literature/SKILL.md` returns 0.

## Artifacts & Outputs

- Modified `.claude/skills/skill-literature/SKILL.md` (one line changed).
- Execution summary (produced at /implement time).

## Rollback/Contingency

Single-line change: revert via `git checkout -- .claude/skills/skill-literature/SKILL.md` or by restoring the original filter `(.authors // []) | first // "?"`. No dependent state or downstream artifacts to unwind.
