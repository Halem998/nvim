# Implementation Summary: Task #960

- **Task**: 960 - Wire non-conformance detection into the hard-mode resume-scan sites
- **Status**: [COMPLETED]
- **Started**: 2026-08-06T15:11:24Z
- **Completed**: 2026-08-06T16:05:00Z
- **Effort**: ~5 hours (matches plan estimate)
- **Dependencies**: None outstanding (tasks 959 and 957 landed prior to this task)
- **Artifacts**: plans/01_nonconformance-resume-scan-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Both hard-mode resume-scan sites selected the next phase to dispatch via a
`PHASE_HEADING_ERE`-filtered grep, which admits conforming headings only — so a non-conforming
heading (e.g. `4C`) was not merely unmatched, it was **invisible** to the scan, and the existing
`warn_nonconforming` guard branches sat in provably unreachable code. This implementation inserts
a whole-file conformance gate (`has_nonconforming_phase_headings`) before every filtered scan at
four sites, funnels every inconclusive outcome into one named sentinel
(`phase_scan_inconclusive`), gives each site a first-class inconclusive branch matched to its own
posture, and adds the first executable regression harness for these markdown-embedded scan
blocks. All six plan phases completed; no deviations from the plan's substantive scope.

## What Changed

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` — header prose only: added
  an "Ordering contract for filtered scans" note naming `has_nonconforming_phase_headings` as the
  required predicate and forbidding the racy `nonconforming_phase_headings | grep -q .` pipe form.
  No behavioral change; confirmed by `test-phase-heading-patterns.sh` still passing unchanged
  (35/35).
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — Stage 3b: replaced the
  scan region with the whole-file-check-first gate; the existing `exit 1` posture is now
  reachable and sits above the entire `if/elif/else` cascade (including the `else next_phase=1`
  fallback), not merely above the previously-dead inner branch.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — H1 per-phase dispatch:
  replaced the scan region with the same gate; restructured the cascade so an inconclusive scan
  is a distinct **first** branch routing to this file's own `EXIT (partial, ...)` terminal
  convention, rather than falling through into the skeleton-exhaustion or full-completion
  branches (both of which assert a false claim when the real cause is a malformed plan).
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — Stage 3
  (audit-discovered Site C, a structural clone of the implementer-hard site): same gate, adopting
  this file's own `return error` convention for the leaf-worker posture.
- `agent-system/extensions/core/scripts/update-task-status.sh` — plan-initialization
  `first_phase_heading` convenience path (audit-discovered Site D): minimal guard added — on a
  non-conforming heading, warns and skips the auto-advance convenience entirely rather than
  silently marking a different phase `IN_PROGRESS`. Non-fatal character preserved exactly.
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` — new. Extracts
  the sentinel-delimited (`resume-scan-conformance-gate:begin`/`:end`) executable regions from
  the three SKILL.md sites and runs them against three fixtures (the `4C`/`5` verification bar,
  a happy-path no-behavior-change case, and a decimal-sub-phase case), plus `bash -n` and
  structural assertions on the posture branches and a repo-wide check for the forbidden pipe
  form. 39 assertions, all passing.
- `agent-system/extensions/core/manifest.json` — one `provides.scripts` entry added in
  alphabetical order.
- `agent-system/extensions/core/context/formats/plan-format.md` — "Canonical phase-heading shape"
  subsection: added an "Ordering obligation for filtered scans" paragraph recording the fix and
  the posture-asymmetry rationale. Purely additive; the letter-suffix prohibition paragraph,
  canonical regex table, and consumer-list sentence structure are byte-identical to before.

## Decisions

- Kept the two declared sites' postures deliberately different (leaf-worker hard stop at Sites B
  and C vs. orchestration-loop `EXIT (partial, ...)` at Site A), per the plan's Decision 3 — the
  asymmetry reflects a real structural difference (no subagent dispatched yet vs. a long-running
  loop with established terminal-condition bookkeeping), not an oversight.
- Brought Site C (`skill-lean-implementation-hard`, a structural clone outside the declared
  `file_scope`) into scope, since `plan-format.md`'s consumer list already named it as bound by
  the same "closed contract" claim this task makes true.
- Brought Site D (`update-task-status.sh`'s `first_phase_heading`) into scope as a minimal,
  strictly subtractive guard (warn-and-skip only) rather than a full restructure, preserving its
  documented non-fatal character exactly.
- Test harness: since the library-sourcing line sits immediately before the sentinel
  `:begin` marker at all three sites (per the Phase 1 canonical snippet), it is not textually
  present inside the extracted region. The harness sources the library directly in its execution
  wrapper before `eval`-ing each region instead of rewriting an in-region line — behaviorally
  identical, since the region's own logic never re-sources the library.
- The repo-wide "zero forbidden pipe form" assertion excludes backtick-quoted comment references
  to the form (the canonical gate snippet's own header comment intentionally quotes it as
  documentation of what is forbidden); real invocation syntax is never backtick-wrapped, so this
  cannot hide a genuine violation.

## Plan Deviations

- Phase 3's optional, explicitly non-blocking cleanup item (renaming the `=== BEGIN/END 772 Item
  5A ===` fence comments to a durable anchor) was left unchanged — the plan itself marked this
  step as take-only-if-the-diff-stays-clean, and it was skipped to keep the structural edit's
  diff minimal.
- Phase 5's region-extraction task described "rewrite the sourcing line to the resolved `$LIB`
  path" as part of the extracted region; in the landed sites the sourcing line sits just before
  the sentinel `:begin` marker (matching the plan's own Phase 1 canonical snippet), so it is not
  textually inside the extracted region. The harness instead sources `$LIB` directly in its
  execution wrapper, which is behaviorally equivalent. See "Decisions" above.

Both deviations are non-substantive (test-harness plumbing and an explicitly optional cosmetic
cleanup); no scope, posture, or behavioral commitment from the plan was altered.

## Verification

- Build: N/A (bash/markdown, no build step)
- Tests: Passed — `test-resume-scan-nonconformance.sh` 39/39, `test-phase-heading-patterns.sh`
  35/35 (unchanged)
- Files verified: Yes — `bash -n` clean on `phase-heading-patterns.sh`, `update-task-status.sh`,
  and every sentinel-delimited extracted region; `jq` parses `manifest.json`
- Adversarial check: reverted Site B's gate to the pre-fix filtered-grep-first ordering in a
  scratch copy; the suite failed with exit 1, "34 passed, 5 failed", reproducing the exact
  silent-mis-selection bug ("phase 5 was silently selected despite the non-conforming 4C
  heading"). Scratch copy discarded after the check.
- Zero edits under `.claude/**` — confirmed via `git diff --name-only` across all six phase
  commits.
- Zero unexempted task-number citations outside `specs/**` — confirmed via
  `check-task-references.sh`.

## Impacts

- Both hard-mode per-phase dispatch sites (and the lean extension's clone) now genuinely refuse
  to guess a resume point when a plan contains a non-conforming phase heading, instead of
  silently selecting the next conforming OPEN heading and dispatching out of order on top of
  unfinished work.
- `skill-implementer-hard`'s `else next_phase=1` fallback can no longer re-dispatch phase 1 when
  the only open phase in a whole plan is non-conforming — the gate gates the entire cascade, not
  just the previously-dead inner branch.
- `skill-orchestrate-hard` can no longer mistake a malformed plan for skeleton-exhaustion (falsely
  transitioning to `pr_ready`) or full completion — an inconclusive scan is now a distinct,
  loud, first-class terminal state.
- `plan-format.md`'s "closed contract, not an aspiration" claim about non-conforming-heading
  detection is now verifiably true end-to-end at every site its own consumer list names.

## Follow-ups

- None. The Phase 4 Scope Hypothesis re-run of the consumer-discovery command
  (`grep -rl 'phase-heading-patterns.sh' agent-system/extensions`) confirmed no new consumer has
  appeared beyond the four sites fixed here and the sites research already verified as
  correctly wired.

## References

- Plan: `specs/960_wire_nonconformance_detection_into_resume_scan_sites/plans/01_nonconformance-resume-scan-gate.md`
- Research: `specs/960_wire_nonconformance_detection_into_resume_scan_sites/reports/01_wire-nonconformance-detection.md`
- Library: `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh`
- New test: `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh`
