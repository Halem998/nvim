# Implementation Summary: Task #128

- **Task**: 128 - Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T02:00:00Z
- **Effort**: ~2 hours
- **Dependencies**: 119 (hard-mode state-machine consolidation)
- **Artifacts**: plans/01_fix-h4-adversarial-gate-matcher.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Ported the H4 adversarial-verification gate from the soon-to-be-deleted `skill-orchestrate-hard/SKILL.md`
into the consolidated `skill-orchestrate/SKILL.md`, landing two empirically corrected `grep`
matcher patterns instead of transcribing the source engine's known false-negative originals. The
gate is fully wired into the base engine's `researched` and `planning` handlers behind the
existing `$hard_mode` fork, the base engine's own "Not migrated" / residue documentation was
rewritten to reflect reality, and the deliberate co-maintenance asymmetry (base engine fixed,
`-hard` engine left untouched pending its own deletion) is recorded in both engine files.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Added the `adversarial_verified`
  state variable to the Stage 2 hard-mode init block; added hard-mode-gated resets at the end of
  the `not_started` and `researching` handlers; ported the full H4 verify-or-re-dispatch gate body
  (with the two corrected `grep` patterns) into the `researched` and `planning` handlers,
  immediately before each handler's `skill_preflight_update` call, wrapped so base mode reaches
  that call unchanged; added an H4 row to the hard-mode acceptance-checklist table; rewrote the
  "Not migrated" and "Hard-mode residue not yet migrated" paragraphs (H4 is no longer described as
  unmigrated); added an "Asymmetry decision (recorded, ...)" note.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Added one "Asymmetry
  decision" note adjacent to the `researched` handler's H4 gate heading, pointing readers at the
  base engine's ported (corrected) copy as the live one. No other line in the file was touched;
  the two original false-negative `grep` patterns remain byte-identical to their pre-task form.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — Appended one
  additive paragraph to the "Extending the Signal A vocabulary" section recording that
  `HOOK_REGEX_BOUNDARY_DEFECT` has now been exercised by a concrete non-hook instance (an
  orchestration gate's `grep` matcher with a composed `\b`-anchor boundary defect). No existing
  row, count, or other section was altered.

## Decisions

- Combined the `$hard_mode` and `adversarial_verified` checks into a single `if [ hard_mode ] &&
  [ adversarial_verified = false ]; then` condition rather than nesting two separate `if` blocks —
  functionally equivalent to the source engine's structure and matches this same file's own
  established multi-condition `if`-statement style used elsewhere (e.g. Stage 5b).
- Wrapped the entire remainder of each handler (from `skill_preflight_update` through the
  `team_mode` fork's Agent dispatch) in a second, paired `if [ hard_mode != true ] || [
  adversarial_verified = true ]; then ... fi` block, since falling through to
  `skill_preflight_update` or the planning Agent dispatch after a re-dispatch would incorrectly
  regress status and double-dispatch. The `-hard` source engine achieves the same effect via two
  sequential top-level `if`-blocks with no `hard_mode` wrapper (since that engine is unconditionally
  hard mode); the base engine needed the extra `hard_mode`/`adversarial_verified` OR-condition to
  preserve base mode's prior unconditional behavior.
- Verified all seven fixture-matrix rows (three positive headings, one regression header, two
  negative cases, one false-positive prose probe) twice: once against the plan's verbatim patterns
  before porting (Phase 1), and again against the patterns extracted directly from the landed file
  (Phase 7), under the actually-deployed `ugrep 7.8.4` engine.

## Plan Deviations

- **Task 2 (verification only)** altered: `grep -c 'adversarial_verified'` returned 4 (not the
  plan's stated 3) at the Phase 2 checkpoint, because a pre-existing narrative mention in the
  "Hard-mode residue not yet migrated" paragraph also contained the substring in backticks. The
  three actual code edit sites (Stage 2 init, two handler resets) were confirmed correct and
  isolated; Phase 4's rewrite of that paragraph removed the stray mention, and the final count (13,
  matching 3 set-sites plus reads inside both ported gate bodies) is clean with no residual
  narrative artifact — see Testing & Validation.

## Verification

- Build: N/A (Markdown-only source-store changes)
- Tests: All seven fixture-matrix rows pass in both directions (positive/regression PASS, negative
  FAIL/re-dispatch, false-positive NOMATCH), verified against `ugrep 7.8.4` both from the plan's
  verbatim patterns (Phase 1) and from the patterns extracted from the landed file (Phase 7).
- Files verified: Yes — `git diff --stat` from before Phase 1 to after Phase 6 shows exactly the
  three intended source-store files changed; no `.claude/**` file was modified;
  `lint-contract-compliance.sh` (24/24 passed), `validate-artifact.sh` (plan, PASS), and
  `check-task-references.sh` (0 unexempted occurrences) all pass.

## Impacts

- `/orchestrate --hard` and its manual `--hard` invocation path now runs the H4 adversarial
  verification gate from within the consolidated base engine rather than the deprecated `-hard`
  engine, with a matcher that no longer false-negatives on genuinely conforming research reports
  (previously burning one wasted research re-dispatch on every hard-mode run).
- The base engine's own documentation (`skill-orchestrate/SKILL.md`) now accurately states that all
  five hard-mode behaviors (H1/H4/H5/H6 plus the burnout breaker) are reproduced, unblocking the
  companion word-boundary portability audit's and the `-hard`-engine-deletion task's downstream
  work, both of which were explicitly ordered after this task in the batch coordination notes.

## Follow-ups

- None within this task's scope. The companion word-boundary portability audit, the multi-task-path
  H4 extension question, and the `HOOK_REGEX_BOUNDARY_DEFECT` vocabulary-widening question are all
  explicitly out of scope here and left to their respective owning work, as recorded in the plan's
  Non-Goals and in the added asymmetry/discrimination-doc notes.

## References

- `specs/128_fix_h4_adversarial_gate_matcher/plans/01_fix-h4-adversarial-gate-matcher.md`
- `specs/128_fix_h4_adversarial_gate_matcher/reports/01_fix-h4-adversarial-gate-matcher.md`
- `specs/128_fix_h4_adversarial_gate_matcher/progress/phase-1-progress.json` through `phase-7-progress.json`
