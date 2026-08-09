# Implementation Summary: Task #962

- **Task**: 962 - Correct the pr_ready skill text and docs to describe the actual resulting state
- **Status**: [COMPLETED]
- **Started**: 2026-08-06T16:00:00Z
- **Completed**: 2026-08-06T16:50:56Z
- **Effort**: ~1.5 hours
- **Dependencies**: 961 (satisfied — sibling edits to the same SKILL.md already landed)
- **Artifacts**: plans/01_pr-ready-resting-state-accuracy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Corrected a prose-accuracy defect across three source-store documentation artifacts: the
skeleton-exhaustion branch of `skill-orchestrate-hard/SKILL.md` described a resting state
(`pr_ready`) that the code path cannot actually produce (the call is a `postflight` operation,
and `update-task-status.sh`'s own `postflight:pr_ready -> completed` mapping always resolves it
to `completed`, regardless of task type). No behavioral or script change was made —
`update-task-status.sh` is byte-identical to before this task. The fix closed a documentation gap
in the declared single source of truth (`status-markers.md`, which had zero mentions of
`pr_ready`/`[PR READY]`) and added a general "target argument vs. resting state" distinction that
both `SKILL.md` and `claudemd.md` now defer to.

## What Changed

- `agent-system/extensions/core/context/standards/status-markers.md` — added a `#### [PR READY]`
  marker definition (TODO.md format, state.json value, meaning, valid transitions) following the
  existing per-marker format, and a new "Target Arguments vs. Resting States" subsection stating
  the general rule and naming `postflight:pr_ready -> completed` as the concrete instance.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — rewrote the
  skeleton-exhaustion branch's inline comment (kept the accurate `--allow-pr-ready` guard
  explanation, added that the call is `postflight` and resolves to `completed` regardless of task
  type) and the EXIT line (now names `completed` as the resting state while retaining the
  `skeleton exhausted` phrase, the follow-up interpolations, and a literal `pr_ready` token for
  grep continuity). The `update-task-status.sh` invocation line itself and the unrelated
  `#### State: pr_ready` handler (lines 845-850) are untouched.
- `agent-system/extensions/core/merge-sources/claudemd.md` — added one clarifying sentence after
  the Status Markers bullet list, stating these are *resting* states and pointing to
  `status-markers.md`'s new subsection for the full rule. The existing eight bullets are
  unmodified.
- `agent-system/extensions/core/index-entries.json` — one-line companion edit (not in the
  original FILE SCOPE; see Plan Deviations) correcting the `standards/status-markers.md` entry's
  `line_count` from 379 to 408 to match the file's new length after the Phase 1 additions.

## Decisions

- No change to `scripts/update-task-status.sh` — confirmed correct as written (guard and mapping
  are independent, both correct). `git diff` against this file is empty.
- The genuine `#### State: pr_ready` handler further down `SKILL.md` was left untouched — it is a
  different, correct code path reachable only via `preflight:pr_ready` for real `task_type ==
  "pr"` tasks.
- Placed the full "Target Arguments vs. Resting States" explanation in `status-markers.md` (the
  designated single source of truth) and made `claudemd.md` a short pointer to it, rather than
  duplicating detail — consistent with `claudemd.md`'s existing pattern of linking to fuller
  references.

## Plan Deviations

- **Task 4.1** (`check-extension-docs.sh` exits zero) altered: the script already fails at
  baseline — before any edit in this task — with 5 issues (deploy-drift on
  `scripts/command-route-skill.sh`, `scripts/lib/phase-heading-patterns.sh`,
  `scripts/update-task-status.sh`, `scripts/verify-deploy.sh`, plus a pre-existing
  `index-entries.json` line_count mismatch for `formats/plan-format.md`). Confirmed via
  `git stash` + rerun that baseline and post-implementation failure sets are identical. None of
  these can be fixed without exceeding this task's FILE SCOPE or touching the explicitly-forbidden
  `update-task-status.sh`. See the plan's Phase 4 `#### Reasoned Exclusions` record.
- **Task 4.5** (change set touches exactly the three FILE SCOPE paths) altered: a fourth file,
  `agent-system/extensions/core/index-entries.json`, required a one-line companion edit. Adding
  the Phase 1 subsections grew `status-markers.md` from 380 to 408 lines, which would otherwise
  have introduced a NEW `check-extension-docs.sh` failure not present at baseline. The companion
  edit is mechanical index bookkeeping (the same correction `generate-context-line-counts.sh
  --write` performs) with zero behavioral or policy surface. See the plan's Phase 4
  `#### Reasoned Exclusions` record for full evidence.

## Verification

- Build: N/A (documentation/prose-only change)
- Tests: N/A
- `bash .claude/scripts/check-task-references.sh`: PASS (exit 0)
- `bash .claude/scripts/check-extension-docs.sh`: exits 1, but with the same 5 pre-existing,
  out-of-scope issues present at baseline (verified via `git stash` comparison) — no new failure
  introduced by this task's substantive edits (the one transient regression this task's own edit
  caused was fixed via the index-entries.json companion edit)
- `git diff -- agent-system/extensions/core/scripts/update-task-status.sh`: empty (confirmed)
- `git status --short` shows no `.claude/**` modifications (confirmed)
- Files verified: Yes — all four modified files read back and confirmed correct

## Impacts

- An operator or future editor reading the skeleton-exhaustion branch's EXIT line now correctly
  concludes the task rests at `[COMPLETED]`, not `[PR READY]`.
- `status-markers.md` is now a genuine single source of truth for the `pr_ready` marker and for
  the general target-argument-vs-resting-state distinction, closing a gap that let the original
  prose drift go unnoticed.
- No downstream script, test, or automation consumes the reworded EXIT string or the edited
  comment block (confirmed via `grep -rn "skeleton exhausted"` during planning), so this change
  has no mechanical blast radius.

## Follow-ups

- The pre-existing `check-extension-docs.sh` failures (deploy-script drift on four core scripts,
  and the `formats/plan-format.md` line_count mismatch) are unrelated infrastructure debt outside
  this task's scope. They existed before this task started and remain after it; a future
  `/meta` or maintenance task should regenerate the deploy tree (`deploy-headless.sh` or the
  picker's `[Reload All]`) and run `generate-context-line-counts.sh --write` to clear them.

## References

- Plan: `specs/962_reconcile_pr_ready_policy_across_docs_and_skill_text/plans/01_pr-ready-resting-state-accuracy.md`
- Research report: `specs/962_reconcile_pr_ready_policy_across_docs_and_skill_text/reports/01_pr-ready-policy-accuracy.md`
