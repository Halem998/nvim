# Implementation Summary: Task #906

**Completed**: 2026-07-27
**Duration**: ~1.5 hours

## Overview

Fixed two independent, confirmed defects in the agent-system core: a call-arity bug in
`command-gate-out.sh`'s non-blocking artifact-validation leg that made it silently no-op (and
print a spurious `[FAIL] File not found` on every gate-out), and a forbidden `"completed"` value
that `skill-orchestrate` wrote into `.return-meta.json`/`.return-meta-multi.json`, which made
gate-out's defensive status-correction branch permanently unreachable for `operation=orchestrate`.
Both defects were fixed at the source store (`agent-system/extensions/core/`) and demonstrated
live against a disposable fixture; every doc whose prose described the now-removed bugs was
updated to describe post-fix reality.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — new `skill_validate_task_artifacts`
  function inserted immediately after `skill_validate_artifact` (pure insertion; confirmed
  `skill_propagate_completion_summary` and `skill_link_artifacts` remain byte-intact). Iterates
  `reports/->report`, `plans/->plan`, `summaries/->summary`, validating each file with the
  correct type via `validate-artifact.sh "$f" "$type" --fix`, non-blocking, `return 0`
  unconditionally.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — sources `skill-base.sh` (following
  `orchestrator-postflight.sh`'s precedent) and replaces the mis-arity call
  (`validate-artifact.sh "$task_dir" --fix`) with `skill_validate_task_artifacts "$task_dir"`.
  Rewrote the header comment and the "never been exercised" inline comment block to describe the
  `operation=orchestrate` defensive-correction branch as live, and added a cross-reference comment
  above the accept-list pointing at `return-metadata-file.md` as the normative vocabulary source.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 8 clean-exit write and
  the Stage MT-5 `exit_status` determination bullet both changed from `"completed"` to
  `"implemented"`. Both `"partial"` branches left untouched (only a "never X" cross-reference word
  updated to match the sibling branch's new value). Added short clauses at each write site naming
  `return-metadata-file.md` as the vocabulary source.
- `agent-system/extensions/core/commands/research.md` — reworded the "dead code" parenthetical to
  describe the inline "Verify Artifacts" claim-integrity check and gate-out's directory-wide
  format sweep as complementary, not redundant; removed the adjacent task-number citation
  (`Phase 1, task 810`), replaced with a durable anchor naming `command-gate-out.sh`'s
  `status_token` mapping.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added a normative
  declaration above the `status` table (governs `.return-meta.json`, `.return-meta-multi.json`,
  and by reference `.orchestrator-handoff.json`) and a new three-vocabulary disambiguation table
  (skill-status / state.json task-status / wezterm-notification status). Existing table and
  `"Never use completed"` Note left byte-identical.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — added a cross-reference
  sentence at the `status` field definition pointing to `return-metadata-file.md`, plus a second
  cross-reference and an mtime-vs-vocabulary orthogonality note near the
  `orchestrate-recover-outcome.sh` accept-list discussion.

## Decisions

- Followed the plan's required approach exactly: one shared helper in `skill-base.sh` rather than
  an inline loop in `command-gate-out.sh`, reachable via `source .claude/scripts/skill-base.sh`
  (precedented by `orchestrator-postflight.sh:71`).
- Did not touch `command-gate-out.sh`'s accept-list or `orchestrate-recover-outcome.sh` — both
  were already correct per research; `skill-orchestrate` was the sole offender for Defect 2.
- Left `.claude/` entirely unmodified (verified via `git status --short .claude/` and
  `git diff --stat -- .claude/`, both empty) — all fixes live only in the source store.

## Plan Deviations

- None (implementation followed plan).

## Verification

### Verification (a) — gate-out validates each artifact with correct type, no spurious [FAIL]

Built a disposable fixture at `$SCRATCHPAD/task906-fixture` containing the deployed `.claude/`
tree plus the real task directories `specs/913_fix_stage5_missing_handoff_after_research_dispatch`
and `specs/916_fix_orchestrate_completion_summary_propagation` (each already carrying a real
`.return-meta.json` with `status: "implemented"`, left over from sibling in-flight sessions).

**Baseline (stale, deployed scripts, before overwrite)**:
```
=== BASELINE (stale, deployed .claude/) run for task 913 ===
[FAIL] File not found: specs/913_fix_stage5_missing_handoff_after_research_dispatch
EXIT=0

=== BASELINE (stale) run for task 916 ===
[FAIL] File not found: specs/916_fix_orchestrate_completion_summary_propagation
EXIT=0
```

Overwrote `<fixture>/.claude/scripts/{skill-base.sh,command-gate-out.sh}` with the fixed
source-store copies; confirmed the overwrite landed (`grep -c skill_validate_task_artifacts`
returned 2 and 3 respectively against the two fixture scripts).

**Fixed run**:
```
=== FIXED run for task 913 ===
Validating report artifact: specs/913_.../reports/01_stage5-research-handoff-mismatch.md
Validating report: specs/913_.../reports/01_stage5-research-handoff-mismatch.md
[PASS] report artifact is valid (0 warning(s))
Validating plan artifact: specs/913_.../plans/01_stage5-return-meta-fallback.md
Validating plan: specs/913_.../plans/01_stage5-return-meta-fallback.md
[PASS] plan artifact is valid (0 warning(s))
Validating summary artifact: specs/913_.../summaries/01_stage5-return-meta-fallback-summary.md
Validating summary: specs/913_.../summaries/01_stage5-return-meta-fallback-summary.md
  [ERROR] Missing metadata field: **Task**:
WARNING: summary artifact ... has format issues (non-blocking). Review output above.
EXIT=0

=== FIXED run for task 916 ===
Validating report artifact: specs/916_.../reports/01_completion-summary-propagation.md
Validating report: specs/916_.../reports/01_completion-summary-propagation.md
  [ERROR] Missing required section: ## Recommendations
WARNING: report artifact ... has format issues (non-blocking). Review output above.
Validating plan artifact: specs/916_.../plans/01_completion-summary-propagation.md
Validating plan: specs/916_.../plans/01_completion-summary-propagation.md
[PASS] plan artifact is valid (0 warning(s))
Validating summary artifact: specs/916_.../summaries/01_completion-summary-propagation-summary.md
Validating summary: specs/916_.../summaries/01_completion-summary-propagation-summary.md
  [ERROR] Missing metadata field: **Task**:
WARNING: summary artifact ... has format issues (non-blocking). Review output above.
EXIT=0
```

Zero `[FAIL] File not found: specs/` lines in either fixed run; one validation line per artifact
file, each naming the correct type; both runs exit 0. The genuine `[ERROR]` lines are real,
pre-existing format deviations in those artifacts (the repair leg working for the first time),
not failures of the fix.

### Verification (b) — defensive branch reachability for operation=orchestrate

Reused the same fixture (fixed scripts already in place). Wrote `.return-meta.json` for task 913
by running the fixed Stage 8 `jq -n` snippet verbatim (`status: "implemented"`), then desynced
the fixture's `specs/state.json` to `status: "implementing"` for task 913 (`current_status !=
expected_status`).

**Positive run** (`operation=orchestrate`):
```
[gate-out] Defensive correction: status is 'implementing', skill reports 'implemented'. Applying correction to 'completed'.
[phase-check] Task 913: 6/6 phases [COMPLETED] in 01_stage5-return-meta-fallback.md -- proceeding.
OK: task 913 status -> completed
... (artifact validation lines, one genuine non-blocking [ERROR], EXIT=0)
```
Post-run fixture `state.json` status for 913: `"completed"` — outcome (i), the phase-check
backstop allowed the correction because task 913's own plan showed 6/6 phases `[COMPLETED]`.

**Negative control** (re-desynced state.json to `implementing`, `.return-meta.json` status reset
to the OLD forbidden `"completed"` value via the same jq idiom, same `operation=orchestrate`
run): no `[gate-out] Defensive correction:` line appeared, and the fixture's `state.json`
remained uncorrected at `implementing` — confirming `"completed"` still fails the accept-list
exactly as it did before this fix, isolating the vocabulary change as the cause of reachability.

Confirmed the live repo's `specs/state.json` shows no diff attributable to this phase (`git diff
specs/state.json` only shows task 906's own `not_started -> implementing` preflight transition;
tasks 913 and 916 show no diff).

### Reachability answer

The `skill_validate_task_artifacts` helper is reachable from `command-gate-out.sh`'s execution
context via `source .claude/scripts/skill-base.sh` at the top of the script (immediately after
`set -e`), matching `orchestrator-postflight.sh`'s existing precedent exactly. `skill-base.sh`'s
top level was re-verified to contain only variable assignments (`SKILL_CONTEXT_BUDGET`,
`SKILL_REPO_ROOT`, `export`) and function definitions — no executable statement that could abort
sourcing under `set -e`.

### Stop-behavior rationale

Re-verified as current and actively enforced (not a stale premise) — this very agent's own
required output-format instructions include, verbatim, a prohibition on `"completed"` because it
triggers Claude stop behavior. No escalation was warranted.

## Notes

- Pre-existing task-number citations remain, untouched, in `skill-base.sh`'s header note ("task
  598") and `command-gate-out.sh`'s downstream-dependencies note ("Task 594") — both are outside
  the regions this task edited, per the plan's explicit non-goal against sweeping them.
- The verification fixture (`$SCRATCHPAD/task906-fixture`) was removed at the end of Phase 7;
  nothing outside the repo's normal working tree remains.
- `.claude/` was never synced or re-generated during this task; the fixes take effect only after
  a future deliberate sync (Load Core / Sync all).
