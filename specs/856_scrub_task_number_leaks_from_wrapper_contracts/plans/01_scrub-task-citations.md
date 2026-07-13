# Implementation Plan: Scrub Task-Number Citations from wrapper-contracts.md

- **Task**: 856 - Retroactive cleanup of pre-existing task-number citations in wrapper-contracts.md
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_task-citation-inventory.md
- **Artifacts**: plans/01_scrub-task-citations.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; no-task-references-in-deliverables.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

Bring the single deliverable file
`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` into compliance with
`.claude/rules/no-task-references-in-deliverables.md` by rewriting or cleanly deleting all 24
pre-existing task-number citations. Each citation is replaced with the durable anchor it actually
stands for (a sibling-doc filename + section, a named function/config source, or an in-file
section reference), or deleted when it adds nothing beyond text already present in the sentence.
The research report provides a line-by-line inventory with verbatim replacement text for every
citation, so this plan applies those verdicts rather than re-deriving them. Definition of done:
the mechanical hook regex returns zero real matches, the one line-wrapped citation (invisible to
that regex) is confirmed gone by manual read, and the advisory hook `validate-no-task-references.sh`
no-ops. Scope is exactly ONE file; no wrapper behavior, technical content, or section numbering
changes.

### Research Integration

The plan is built directly from `reports/01_task-citation-inventory.md`, which classifies all 24
citations into patterns, each with a confirmed durable anchor and verbatim "Recommended"
replacement block:
- **`Task 72`** (lines 1, 4) -> `.dotfiles` handoff doc `wrapper-contract.md` §1-§9 (cite the
  document name, keep the section range).
- **`.dotfiles task 80`** (lines 33, and the line-wrapped 263-264) -> named verification function
  `verify_logos_wrapper_contract_close_phase6`.
- **`task 805, Phase 1`** (lines 10, 58, 168) -> `agent-tools.nix` verification anchor already
  in-sentence.
- **`task 820`** (lines 18, 128, 170, 215, 241) -> in-file §10/§10a, `classify.nix`, and the
  `.dotfiles` addendum §12 already named in-sentence.
- **§13 freshness/reindex** `tasks 823-824 / 823, 827 / 824, 827 / 827` (lines 285, 303, 309, 318,
  332) -> sibling doc `staleness-detection.md` and config source `mbsync.nix`.
- **§13 hook-race narrative** `task 852 / task 854` (lines 337-338, 346, 350, 359, 372, 381, 383)
  -> self-referential phrasing ("that live run", "the earlier ...", "this section"); the concrete
  facts (`logos-reclone.sh`, xapian findings, `search.exclude_tags`) are already stated inline.
- **Line 383-384** additionally embeds a raw `specs/854_.../summaries/...` path pointing into
  another task's directory -> that path is deleted along with the task-number text.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set). This cleanup advances repository
hygiene under `no-task-references-in-deliverables.md` but is a one-off retroactive fix, not a
roadmap item.

## Goals & Non-Goals

**Goals**:
- Rewrite or cleanly delete all 24 task-number citations in `wrapper-contracts.md`, using the
  durable-anchor replacement text specified per-citation in the research report.
- Delete the raw `specs/854_.../` cross-task path leak at line 383-384 along with its task number.
- Achieve zero real matches for the hook regex `\btasks?[:,]?[[:space:]]+[0-9]` and confirm the
  line-wrapped citation (report finding #12) is gone via manual read.
- Confirm `validate-no-task-references.sh` no-ops (or only flags intentional illustrative example
  lines, phrased so they do not read as real citations).

**Non-Goals**:
- Fixing the pre-existing §12 numbering gap (`### 11a.` -> `## 13.`). Out of scope; preserve
  section numbering exactly.
- Changing any documented wrapper behavior, technical content, or `##`/`###` heading numbers.
- Editing any file other than `wrapper-contracts.md` (no sibling docs, no deployed copy exists).
- Changing the in-file forward reference `§10` to `§10a` (report finding #7 flags this as an
  out-of-scope technical edit).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Mechanically deleting `(task N)` parentheticals leaves doubled punctuation or dangling parens | M | M | Copy each "Recommended" block from the report verbatim as full replacement text rather than deleting substrings in place |
| Hook's single-line regex reports false PASS while the line-wrapped citation (lines 263-264) or a newly-introduced wrap is missed | H | M | Verification includes a manual read of §11/§11a and §13 plus `grep -niw task`, not just the exact hook regex re-run |
| Line numbers in the report have drifted (file is now 386 lines vs report's 387) | M | H | Implementer re-greps for each citation and matches on the quoted text, not the line number, before editing |
| Over-eager renumbering to "fix" the missing `## 12.` gap | M | L | Explicitly listed as a Non-Goal; preserve all section numbering |
| An illustrative "bad example" line (if any is introduced) reads as a real citation and re-triggers the hook | L | L | Any example phrasing must be constructed so it does not match `\btasks?[:,]?[[:space:]]+[0-9]` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Apply durable-anchor rewrites to all 24 citations [COMPLETED]

**Goal**: Rewrite or cleanly delete every task-number citation in `wrapper-contracts.md` using the
per-citation verdicts and verbatim replacement text from the research report.

**Tasks**:
- [x] Read `reports/01_task-citation-inventory.md` in full and read the current
      `wrapper-contracts.md` to re-verify line numbers (match on quoted text, not line number, since
      the file is now 386 lines). *(completed)*
- [x] Apply findings #1-#2 (`Task 72`, lines ~1, ~4): replace with `.dotfiles` handoff doc
      `wrapper-contract.md` §1-§9 anchor per the report's Recommended blocks. *(completed)*
- [x] Apply findings #3, #6, #8 (`task 805, Phase 1`, lines ~10, ~58, ~168): drop the
      task/phase reference, keep/tighten the `agent-tools.nix` anchor. *(completed)*
- [x] Apply finding #5 and #12 (`.dotfiles task 80`, lines ~33 and the line-wrapped ~263-264):
      drop `task 80`, keep `verify_logos_wrapper_contract_close_phase6`. Treat #12 carefully — it
      wraps across a line break. *(completed)*
- [x] Apply findings #4, #7, #9, #10, #11 (`task 820`, lines ~18, ~128, ~170, ~215, ~241): drop
      the task number, keep the in-sentence anchor (§10, `classify.nix`, `.dotfiles` addendum §12,
      feature name). Do NOT change `§10` to `§10a`. *(completed; finding #9 also required moving
      the bold-close marker from line 171 to line 170's parenthetical to keep markdown bold spans
      matched after the task-number text was dropped — no technical content changed)*
- [x] Apply findings #13-#17 (§13 freshness/reindex, lines ~285, ~303, ~309, ~318, ~332): drop
      task numbers, cite `staleness-detection.md` / `mbsync.nix` as specified. *(completed)*
- [x] Apply findings #18-#24 (§13 hook-race narrative, lines ~337-338, ~346, ~350, ~359, ~372,
      ~381, ~383-384): delete cleanly with self-referential phrasing. For #24, delete BOTH the
      `task 854` text AND the raw `specs/854_.../summaries/...` path. *(completed)*
- [x] Copy each replacement from the report's "Recommended" block verbatim to avoid doubled
      punctuation or dangling parentheses. *(completed)*

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` - rewrite/delete all
  24 task-number citations; no other content or section-number changes.

**Verification**:
- All 24 citations from the report inventory have been addressed (checklist above complete).
- No `##`/`###` heading numbers changed; §12 gap left as-is.
- No file other than `wrapper-contracts.md` was touched.

### Phase 2: Verify compliance (mechanical + manual + hook) [COMPLETED]

**Goal**: Confirm zero real task-number citations remain, including the line-wrapped one the
single-line regex cannot catch, and confirm the advisory hook no-ops.

**Tasks**:
- [x] Run `grep -niE '\btasks?[:,]?[[:space:]]+[0-9]' <file>` and confirm 0 real matches (only
      intentional illustrative example lines, if any, may remain and must be phrased not to match).
      *(completed: 0 matches, exit code 1)*
- [x] Run a supplementary `grep -niw 'task' <file>` and manually read every hit to catch
      line-wrapped or reworded residue. *(completed: 0 matches)*
- [x] Manually read §11/§11a (around former lines 263-264) and §13 (around former lines 337-386)
      to confirm the line-wrapped `task 80` citation and the self-referential rewrites read cleanly.
      *(completed: both sections read in full, prose flows correctly)*
- [x] Confirm the raw `specs/854_.../` path is gone: `grep -n 'specs/854' <file>` returns nothing.
      *(completed: no output)*
- [x] Run / simulate the advisory hook `.claude/hooks/validate-no-task-references.sh` against the
      file and confirm it no-ops (or only surfaces intentional example lines). *(completed: hook
      returned `{}`)*
- [x] Confirm section numbering is unchanged (`grep -nE '^#{1,3} '` shows the same heading numbers,
      §12 gap preserved). *(completed: §1-§11a then §13, gap preserved, no heading text/numbers
      changed except the two headings that themselves contained citations: §1 H1 title and §10/§10a
      titles, whose numbering and non-citation content are unchanged)*

**Timing**: ~0.5 hour

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- Hook regex returns 0 real matches.
- `grep -n 'specs/854' <file>` returns nothing.
- Manual read of §11/§11a and §13 confirms no residual task citations.
- Advisory hook no-ops.

## Testing & Validation

- [ ] `grep -niE '\btasks?[:,]?[[:space:]]+[0-9]' wrapper-contracts.md` -> 0 real matches.
- [ ] `grep -niw 'task' wrapper-contracts.md` -> every remaining hit is prose (e.g. "the task
      description"), not a numbered citation.
- [ ] `grep -n 'specs/854' wrapper-contracts.md` -> no output.
- [ ] Manual read of §11/§11a and §13 confirms the line-wrapped citation (report finding #12) is
      gone and self-referential rewrites read cleanly.
- [ ] `.claude/hooks/validate-no-task-references.sh` no-ops on the file.
- [ ] Heading numbers unchanged; §12 gap preserved (no renumbering).

## Artifacts & Outputs

- Edited file: `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
- `specs/856_scrub_task_number_leaks_from_wrapper_contracts/summaries/01_scrub-task-citations-summary.md`
  (implementation summary)

## Rollback/Contingency

Single-file, edit-only change with no behavioral impact. To revert:
`git checkout -- .claude/extensions/email/context/project/email/domain/wrapper-contracts.md`.
If verification (Phase 2) finds residual or newly-introduced task citations, re-enter Phase 1 for
the specific offending lines using the report's verbatim replacement text; do not renumber
sections or alter technical content as part of any fix.
