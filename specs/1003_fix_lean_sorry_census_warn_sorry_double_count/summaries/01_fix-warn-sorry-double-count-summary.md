# Implementation Summary: Task #1003

- **Task**: 1003 - Fix lean-sorry-census.sh double-counting warn.sorry suppression annotations
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T07:28:55Z
- **Completed**: 2026-08-10T08:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_fix-warn-sorry-double-count.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`agent-system/extensions/lean/scripts/lean-sorry-census.sh` was double-counting every own-line
`set_option warn.sorry false in` suppression annotation as a phantom sorry, because its matcher
`\bsorry\b` fires at the `.`/`s` word boundary inside `warn.sorry`. The fix swaps the pattern to
the negative-lookbehind form `(?<![.\w])sorry\b`, reconciles two stale docstring lines naming the
old pattern, ships the script's first regression fixture (test-first, proven non-vacuous by
failing against the unfixed script), and validates the fix against the real `~/Projects/cslib`
corpus.

## What Changed

- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` (new) — 8-assertion
  fixture suite covering own-line annotation (A), same-line annotation non-regression (B),
  stripper guard for comments/strings (C), dotted-name generality (D), and an aggregate
  N-annotations/M-real-sorries case (E), plus anti-vacuous naive-vs-tool dual assertions on A/D
  and an inventory-content assertion on A.
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` — line 144 regex changed from
  `re.compile(r'\bsorry\b')` to `re.compile(r'(?<![.\w])sorry\b')`; lines 11 and 96 (docstring
  text naming the matcher) updated to match; line 5 (describing the rejected `grep -rn` chain)
  left verbatim per its correct classification as an alternative-approach description, not this
  script's own behavior.
- `agent-system/extensions/lean/manifest.json` — added `"tests/test-lean-sorry-census.sh"` to
  `provides.scripts`, correcting a wrong assumption in the plan (see Plan Deviations).

## Decisions

- Followed the test-first ordering strictly: the fixture suite was written and run against the
  UNFIXED script first, observed failing exactly as hypothesized (Fixtures A, D, E FAIL; B, C
  PASS; PASSED=2, FAILED=6, exit 1), before any source edit.
- Treated the task description's 45→27 / 41→23 figures as hypotheses per the plan's Scope
  Hypothesis instruction. Observed actual figures: repo-wide 43→25 (delta 18), `Cslib/Logics/Bimodal`
  41→23 (delta 18) — Bimodal matched the hypothesis exactly; the repo-wide absolute pre-fix count
  diverged (43 vs. hypothesized 45), attributed to corpus drift rather than a fix defect, since
  the *identity* (delta == independently-grepped annotation count) held exactly on both scopes.
- The `--cross-check` secondary oracle returned `MISMATCH` (compiler=0, stripper=23) because
  `lake build` found the corpus's 14G `.lake/build` cache fully up to date and elaborated zero
  files, emitting zero compiler sorry warnings regardless of the fix's correctness. This was
  recorded as a Reasoned Exclusion per the plan's explicit fallback instruction rather than
  reported as a passing cross-check; the binding toolchain-free differential (delta identity,
  strict-subset inventory check) is unaffected and passed cleanly.

## Plan Deviations

- **Phase 3, secondary `--cross-check` oracle**: did not resolve to `cross_check: MATCH` as
  hoped; closed as a Reasoned Exclusion (lake build cache was fully warm, so it elaborated
  nothing) — see the plan's Phase 3 `#### Reasoned Exclusions` table. The phase itself closed
  `[COMPLETED WITH EXCLUSIONS]`, not `[PARTIAL]`, since all five admission-test conditions held
  (decided, tightly scoped to one task item, documented, evidenced, no residual work).
- **Phase 4, `provides.scripts` default assumption**: the plan asserted "Core's test files are
  not individually listed in `provides`, so the default answer is no." This was empirically
  false — `check-extension-docs.sh` hard-FAILed until `tests/test-lean-sorry-census.sh` was
  added to `lean/manifest.json`'s `provides.scripts`, matching core's own
  `tests/test-census-count.sh` entry. Corrected at implementation time.

## Verification

- Build: N/A (bash/python3 scripts, no compiled build step)
- Tests: Passed — `test-lean-sorry-census.sh` 8/8 PASS, exit 0, against the fixed script; the
  same suite demonstrably FAILED 6/8 against the unfixed script pre-Phase-2, proving falsifiability
- Files verified: Yes — `git diff --stat` on the source-script edit confirmed exactly 3
  insertions/3 deletions across lines 11, 96, 144 and nothing else; `strip_lean_comments()`'s
  executable body and the counting loop are byte-unchanged

## Impacts

- `lean-implementation-agent.md` and `cslib-implementation-agent.md` (both hard-gate "implemented"
  status on `sorry_count == 0`) now receive an accurate count instead of one inflated by every
  own-line `warn.sorry` suppression annotation in scope — no edit was needed to either file since
  both consume `sorry_count` as an opaque integer.
- The lean extension's real-corpus sorry inventory (`~/Projects/cslib`) drops by exactly 18
  phantom entries repo-wide and in `Cslib/Logics/Bimodal`, with zero real sorries lost (strict
  subset confirmed via inventory diff).

## Follow-ups

- None required by this task. If a fully warm `.lake/build` cache continues to make
  `--cross-check` return a trivial `compiler_sorry_count: 0` in future runs, a future task could
  consider forcing a targeted rebuild of touched files for a genuine compiler cross-check, but
  this is out of scope here (the toolchain-free differential is the documented binding gate).

## References

- `specs/1003_fix_lean_sorry_census_warn_sorry_double_count/plans/01_fix-warn-sorry-double-count.md`
- `specs/1003_fix_lean_sorry_census_warn_sorry_double_count/reports/01_fix-warn-sorry-double-count.md`
- `specs/1003_fix_lean_sorry_census_warn_sorry_double_count/progress/phase-1-progress.json` through `phase-4-progress.json`
- `specs/1003_fix_lean_sorry_census_warn_sorry_double_count/handoffs/` (per-phase handoffs with raw evidence)
