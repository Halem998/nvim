# Implementation Summary: Task #34

- **Task**: 34 - anchor_git_guard_matching_to_argv
- **Status**: [COMPLETED]
- **Started**: 2026-08-17T18:12:41Z
- **Completed**: 2026-08-17T20:10:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_anchor-guard-matching.md, reports/01_anchor-guard-matching.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`guard-destructive-git.sh` false-positived on ordinary `git commit` calls whose free-text `-m`
message merely mentioned destructive-looking git wording, most severely on multi-line messages.
Landed the verified fix architecture: a single upfront, multi-line-safe quote-strip plus a
comment-strip, applied once to the whole command before any segment extraction, with all seven
detectors repointed at the stripped string. Created the repository's first regression suite for
this hook (43 cases), proved it non-vacuous via a two-stage mutation check, and registered it in
`run-all.sh` discovery via `manifest.json`.

## What Changed

- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — added a single `COMMAND_SCAN`
  construction (upfront quote-strip + comment-strip) immediately after the clean-tree early exit;
  repointed all seven detectors (`ADD_SEGMENTS`, `COMMIT_SEGMENTS`, `git reset --hard`,
  `git checkout --`, `RESTORE_SEGMENTS`, `CLEAN_SEGMENTS`, `git stash drop|clear`,
  `FORCED_SEGMENTS`) at `$COMMAND_SCAN`; deleted the two now-redundant per-segment `seg_scan`
  `sed` strips; updated header/inline comments to describe the actual post-fix matching contract
  and to record the segment-splitting out-of-scope decision.
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — new file, 43
  cases: fixture self-check, clean-tree/empty-command exemption meta-cases, Phase 1 baseline
  (over-staging + destructive-detector true positives, safe-form allow cases), Phase 2 defect
  cases (multi-line hyphenated-prose false positives, per-detector message-text false positives,
  both `--staged` false-exemption forms, no-bypass-opened guards).
- `agent-system/extensions/core/manifest.json` — registered
  `"tests/test-guard-destructive-git.sh"` in `provides.scripts`.

## Decisions

- **Deviation from the plan's literal sed idiom**: the plan's specified `:a;N;$!ba` slurp-mode
  sed construction was implemented verbatim first, then disproved by direct reproduction — GNU
  sed's `N` command, invoked when the current line is already the last line of input (true of
  any genuinely single-line command, the common case), auto-prints the pattern space unmodified
  and terminates the script before the substitution ever runs. This left ordinary single-line
  commands like `git commit -m "fix -a bug"` completely unstripped, regressing a Phase 1 baseline
  case. Replaced with `sed -z` (NUL-delimited records), which treats the whole command — single-
  or multi-line alike — as one record with no last-line special case. Re-verified 43/43 green.
- **Deviation in Phase 2 defect-case construction**: the checklist's literal example message-text
  false positives for the five raw-`$COMMAND` destructive detectors (e.g. `-m "revert the git
  reset --hard fallout"`) do not actually reproduce a defect — these detectors anchor
  segment/match extraction on `(^|[;&|][[:space:]]*)`, start-of-string or a literal `;`/`&`/`|`
  character, not arbitrary preceding prose. Verified by direct reproduction that ordinary-prose
  phrasing was GREEN pre-fix (not evidence). Replaced with message text containing a literal `;`
  immediately before the destructive phrase (e.g. `-m "See the notes below; git reset --hard
  discards local changes"`), which does reproduce RED pre-fix for all five detectors.
- **Deployed-mode verification used the plan's documented fallback**, not `deploy-headless.sh`:
  that script's own header restricts automated invocation to exactly one sanctioned caller
  (skill-orchestrate's Stage MT-3 redeploy checkpoint) and separately documents a self-overwrite
  hazard when run from within the repo it targets. Used the flat `mktemp -d` tree
  (`hooks/` + `scripts/tests/`) instead, exercising the identical `$SCRIPT_DIR/../../hooks/`
  resolution — 43/43 green.
- **Out of scope, as decided in research and reaffirmed here**: tightening the Cause-2 flag
  regex (`(^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)`) was not attempted — the architecture fix
  already satisfies every acceptance criterion for its symptoms, and correctly narrowing it is a
  separate, riskier regex-design problem with its own false-negative surface.
- **Out of scope, recorded as follow-up**: the `[^;&|]*` segment-splitting regexes used by every
  detector are not quote-aware. This upfront strip confines that risk to genuinely *unquoted*
  occurrences of `;`/`&`/`|`, which is rare and not implicated in any reproduced false positive.
  A correct fix needs a real tokenizer applied consistently across all seven detectors —
  recommended as a separate follow-up task, not attempted here.

## Plan Deviations

- **Phase 3, sed construction**: altered from the plan's literal `:a;N;$!ba` idiom to `sed -z`,
  per the GNU sed single-line-input defect discovered and reproduced during implementation (see
  Decisions above and the Phase 3 checklist annotation in the plan file).
- **Phase 2, message-text defect cases**: altered from the checklist's literal ordinary-prose
  examples to semicolon-punctuated equivalents, per the anchor-pattern analysis discovered during
  implementation (see Decisions above and the Phase 2 checklist annotation).
- No other deviations. All six phases completed as planned, including the deviations' own
  re-verification against the full case set.

## Verification

- Build: N/A (shell scripts; `bash -n` syntax check passed for the hook)
- Tests: `test-guard-destructive-git.sh` 43/43 passed against the fixed hook, in both
  source-store mode and a deployed-directory-shape flat-tree simulation.
- Mutation check (house standard, both stages actually run, output below is what was observed):
  - Full revert: 32 passed / 11 failed. The 11 FAIL labels exactly match the Phase 2 recorded RED
    set (no drift in either direction).
  - Comment-strip-only revert: 42 passed / 1 failed — exactly `defect: #-comment --staged does
    not exempt a real restore`, confirming that clause is independently load-bearing.
  - Restored fix: 43/43 green again, file byte-identical to the committed version.
- Repo-wide sweep: `run-all.sh` (source-store mode) — 42 passed, 1 failed, 0 skipped, 43 total
  (suite-level). The one failing suite, `test-validate-return-meta.sh`, is pre-existing and
  outside this task's file scope; it failed on the pre-Phase-6 baseline run too (with a different
  internal case count), indicating a pre-existing flake rather than a regression from this task.
- Files verified: Yes — `bash -n` clean; `grep -c seg_scan` returns 0; `grep -n '\$COMMAND\b'`
  shows only the empty-command early exit and the `COMMAND_SCAN` construction itself reading raw
  `$COMMAND`; `git ls-files -s` confirms the new suite carries the exec bit (100755).

## Impacts

- Every future Bash tool call in this repository is gated by this hook on a dirty tree. The fix
  removes false-positive blocks on ordinary commit messages (the original bug report's symptom)
  without opening any bypass in the destructive-command detection this hook exists to enforce —
  confirmed by the explicit no-bypass-opened test cases and the mutation check.
- The new suite is the first regression net for this hook; it will catch future regressions to
  either the quote/comment-strip mechanism or the seven detectors themselves, in both
  source-store and deployed deploy shapes.

## Follow-ups

- **Recommended follow-up task**: make the `[^;&|]*` segment-splitting regexes quote-aware
  (real tokenizer, applied consistently across all seven detectors). Explicitly out of scope for
  this task per both the research report and this plan; no known live false positive traces to
  it, but it is a latent gap now that quoted content is otherwise well-protected.
- **Not a follow-up, but worth surfacing**: mid-implementation, a concurrent agent (task 41, in
  the same shared working tree) ran a `git-snapshot.sh`-style stash+hard-reset for its own
  purposes, which silently reverted this task's then-uncommitted Phase 3 edits (the hook fix and
  the plan's Phase 3 checklist annotations) back to the last commit. Fully recoverable — the
  content was still present in the resulting `stash@{0}` — and recovered byte-for-byte, re-verified,
  and committed with no data loss. Recorded here per the house Observation Duty contract as a
  cross-agent interaction in a shared working tree, not a defect in this task's own work; see the
  Phase 3 progressive handoff for the full incident narrative.
- The pre-existing, apparently-flaky failure in `test-validate-return-meta.sh`'s fix-roundtrip
  cases (observed in both the Phase 5 baseline run and the Phase 6 final sweep, with differing
  case counts between runs) was not investigated — outside this task's file scope.

## References

- Plan: `specs/034_anchor_git_guard_matching_to_argv/plans/01_anchor-guard-matching.md`
- Report: `specs/034_anchor_git_guard_matching_to_argv/reports/01_anchor-guard-matching.md`
- Progress files: `specs/034_anchor_git_guard_matching_to_argv/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/034_anchor_git_guard_matching_to_argv/handoffs/phase-{1,3}-handoff-*.md`
  (the Phase 3 handoff documents the shared-worktree revert incident in full)
