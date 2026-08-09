# Implementation Summary: Task #934

**Completed**: 2026-07-28
**Duration**: ~2.5 hours

## Overview

Implemented the evidence-gated inter-cycle redeploy checkpoint across all seven planned phases,
retiring hazard 3 (the bootstrapping hazard) as partially retired and naming its narrower
replacement exposure. Wired a new Stage MT-3 step 7 into `skill-orchestrate`, hardened
`deploy-headless.sh` for safe automated self-hosting invocation (fail-open mutex plus a
self-overwrite structural fix that was confirmed necessary and then live-verified against this
exact repository), documented `verify-deploy.sh`'s exit-2-is-failure contract, and cross-referenced
the whole contract from `commands/orchestrate.md`. All work landed in the source store
(`agent-system/extensions/core/`); zero hand-edits under `.claude/`.

## What Changed

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — rewrote
  hazard 3 as "PARTIALLY RETIRED" with its three-part (i)/(ii)/(iii) breakdown, reconciled the
  following paragraph's "hazards 1 and 3" phrasing, added the new `### The Inter-Cycle Redeploy
  Checkpoint` subsection (trigger, `modified_files` rationale, rejected alternatives, failure
  contract, sequencing, idempotence guard, concurrency), and added a Related Documents entry for
  `regeneration-is-manual-only.md`.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — added
  `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint` immediately after
  `## When to Prefer Which`, leaving the original "must be invoked explicitly" sentence
  byte-for-byte intact; added a Related Documentation cross-reference to the guardrails doc.
- `agent-system/extensions/core/scripts/deploy-headless.sh` — restructured the entire executable
  body into a single `main()` function invoked as the file's last line (confirmed necessary: the
  sync's `vim.fn.writefile` truncates-in-place, and the pre-edit script was top-level-structured
  and therefore exposed); added a self-contained, fail-open `specs/.deploy-lock/` mutex with
  stale-lock reclaim, implemented inline without sourcing `task-lock.sh`; extended the SAFETY
  header with a pointer to the new carve-out; `--dry-run` now reports mutex state.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — comment-only header additions: a
  `Callers:` note naming the checkpoint as an automated consumer, and an explicit statement that
  exit 2 is treated as failure, never a pass. No executable line changed.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added
  `deferred_deploy_checkpoint: []` and `deployed_critical_paths: []` to the `mt_state_file`
  schema; threaded `deferred_deploy_checkpoint` through Stage MT-3 steps 2/3/4; added new Stage
  MT-3 step 7 (the checkpoint itself); added a one-line `cycle_modified_files` accumulation (plus
  comment) to Stage MT-4 step 5.5, with no other change to that step; updated Stage MT-5 to read,
  report, and gate `exit_status` on `deferred_deploy_checkpoint`, and added
  `tasks_deferred_deploy_checkpoint` to the `.return-meta-multi.json` jq construction.
- `agent-system/extensions/core/commands/orchestrate.md` — added a post-dispatch-counterpart note
  to the self-modification defer-trigger discussion, an ordering clause to the Commit
  Reconciliation section, a new results-table row (Exit-path coverage table) and a new
  `### Deferred (redeploy checkpoint)` section in the Consolidated Output template.
- `specs/934_inter_wave_redeploy_checkpoint/plans/01_inter-cycle-redeploy-checkpoint.md` — all
  seven phase headings marked `[COMPLETED]`, task checklists checked off with completion notes,
  plan-level Status set to `[COMPLETED]`.

## Decisions

- Confirmed the Phase 3 Scope Hypothesis empirically rather than assuming it: `vim.fn.writefile`
  (Neovim's own doc: "An existing file is overwritten, if possible") truncates in place, and the
  pre-edit script's top-level structure was exposed. The restructure was implemented, not skipped.
- The self-overwrite hazard was then observed live: running the OLD deployed
  `.claude/scripts/deploy-headless.sh` from within this repo produced a real bash parse error
  mid-execution when the sync overwrote the file it was executing. Re-running with the newly
  fixed (post-restructure) script completed cleanly with no crash, confirming the fix works
  against the exact self-hosting scenario the hazard describes.
- Deliberately redeployed (`bash .claude/scripts/deploy-headless.sh` then `verify-deploy.sh`)
  during Phase 7 verification rather than leaving the deploy tree stale. This was a conscious,
  logged, one-time invocation matching the plan's own Rollback/Contingency instructions ("After
  implementation, redeploy manually... before relying on the new behavior") and the "deliberate,
  never silent" carve-out this task itself adds — not a routine practice for future implementation
  agents to repeat unprompted.

## Plan Deviations

- None (implementation followed plan). The Phase 3 Scope Hypothesis resolved to "restructure
  needed," which the plan itself flagged as the live branch to expect; this is a hypothesis
  resolution, not a deviation.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: N/A (no test suite for these files)
- `bash -n` on both edited scripts: clean, both in source-store and post-redeploy deployed form.
- `deploy-headless.sh --dry-run`: exit 0, mutex state reported, nothing written, lock absent
  afterward. Held-lock simulation: fail-open warning emitted, exit code unchanged, lock left
  intact (not ours to remove).
- `verify-deploy.sh --quiet`: exit code unchanged from baseline (1, pre-existing, unrelated to
  this task) with identical output.
- `check-extension-docs.sh`: FAILed with exactly 2 issues (expected source/deploy drift on the
  two edited scripts) until a deliberate redeploy; now exits 0 ("PASS: all extensions OK").
- `validate-artifact.sh` against this plan: PASS, 0 warnings.
- Files verified: yes, all six edited files confirmed present and correctly modified.
- Source-store boundary: zero `.claude/` modifications in any git commit for this task.
- No-task-references sweep: 2 pre-existing hits found (predating this task, confirmed via
  `git diff HEAD~4`), not introduced by this work — see Notes.

## Notes

- **Discovered pre-existing issue (out of scope, not fixed)**: `skill-orchestrate/SKILL.md:144`
  ("task 808") and `commands/orchestrate.md:217` ("task 785 and task 787") both violate the
  no-task-references-in-deliverables rule but predate this task's changes entirely. Left
  untouched per the binding instruction to record rather than force unrelated fixes; a follow-up
  cleanup task would need to retitle these as durable anchors instead of task numbers.
- The hard-mode inheritance claim was verified, not assumed: `skill-orchestrate-hard/SKILL.md`
  Stage 0 (lines 90-91) still reads "Same as base `skill-orchestrate`... If true, use base
  multi-task stages" — unchanged, confirming the checkpoint is inherited by `/orchestrate --hard`
  with no edit needed to that file.
- Hazard 3's replacement exposure is now explicitly scoped to six of the nine critical paths
  (the shell scripts); the three skill/command files are unaffected mid-invocation since they are
  read once into context at dispatch time.
