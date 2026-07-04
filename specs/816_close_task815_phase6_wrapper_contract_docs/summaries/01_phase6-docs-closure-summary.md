# Implementation Summary: Task #816

**Completed**: 2026-07-04
**Duration**: ~0.5 hours

## Overview

Documentation-only closure of task 815's Phase 6, which had been `[BLOCKED]` pending `.dotfiles`
task 79's wrapper binaries landing. `.dotfiles` task 80's closure report independently verified
all 9 wrapper-contract rows PASS with zero divergence, including a live end-to-end `/email --logos`
exercise. This task transcribed that already-verified contract data into three nvim files and
flipped task 815's Phase 6 from `[BLOCKED]` to `[COMPLETED]`. No live verification was performed
(none was needed — the source data was copy-verbatim ready).

## What Changed

- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — Replaced the
  stale "`--account gmail` reserved on all five" bullet in §2 with the confirmed
  `--account <gmail|logos>` enum (default `gmail`, unknown values rejected with a non-zero-exit
  actionable error, never silently coerced). Generalized §11's intro and added the per-account
  folder-token table (gmail + logos rows) plus a new `### 11a.` mbsync-channel mapping table,
  both copied verbatim from the `.dotfiles` task 80 closure report §3.
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — Generalized the
  three illustrative `folder:Gmail/.All_Mail` token mentions (top-of-file framing sentence, Blast
  Radius table column headers, "What Archive Scope Does NOT Change" section) to be account-neutral,
  cross-referencing `wrapper-contracts.md` §11 for the full per-account table. Left the substantive
  Gmail-specific Trash-retention fact unchanged.
- `specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md` —
  Flipped Phase 6 from `[BLOCKED]` to `[COMPLETED]` across all five originally coupled edit sites
  (top Status line, Phase 6 heading, Depends-on/Blocked block, Testing & Validation checklist item,
  Rollback/Contingency mention), citing `.dotfiles` task 79 (landed, switched in) and task 80
  (verification source, 9/9 PASS). Also resolved two additional historical `[BLOCKED]` mentions
  discovered during verification (Overview narrative and Risks & Mitigations table) that were not
  in the original five-site enumeration but were still Phase-6-associated and caught by the
  whole-file grep check.
- `specs/816_close_task815_phase6_wrapper_contract_docs/plans/01_phase6-docs-closure.md` — Marked
  all three phases `[COMPLETED]`, checked off all task items, and updated the Testing & Validation
  section with final results.

## Decisions

- Copied the per-account folder-token and mbsync-channel tables verbatim from the `.dotfiles`
  task 80 closure report §3, as instructed, rather than re-deriving them.
- Placed the mbsync-channel table under a new `### 11a.` subsection (rather than a standalone
  top-level heading) to keep it inside "§11" as the closure report's cross-repo mapping specifies.
- Expanded Phase 3's scope beyond the five originally enumerated edit sites to two additional
  historical `[BLOCKED]` mentions (Overview line ~33, Risks & Mitigations table line ~86) once the
  whole-file grep verification caught them — this was necessary to satisfy the stated verification
  criterion of "zero remaining `[BLOCKED]` references... anywhere in the task-815 plan."

## Plan Deviations

- **Task 3.6** (not originally enumerated): Two additional historical `[BLOCKED]` mentions in the
  task-815 plan's Overview narrative and Risks & Mitigations table were resolved beyond the five
  originally listed edit sites, because the plan's own verification criterion required zero
  `[BLOCKED]` hits anywhere in the file, not just at the five sites. See progress file
  `phase-3-progress.json` for the full deviation record.

## Verification

- Build: N/A (documentation-only, no build).
- Tests: N/A (no test suite for these artifacts).
- `bash .claude/scripts/check-extension-docs.sh`: `[email]` extension section reports `PASS`.
  Overall script exit code is 1 due to pre-existing, unrelated `[core]` and `[lean]` extension
  FAILs (script-reference drift in core, undeployed hard-mode skill targets in lean) — confirmed
  via `git stash`/`git stash pop` to predate this task's edits and to be present both before and
  after task 816's changes were applied.
- `grep -rn 'reserved-only' .claude/extensions/email/context/project/email/domain/wrapper-contracts.md`:
  zero hits.
- `grep -n 'BLOCKED' specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md`:
  zero hits.
- Files verified: Yes — all three edited files exist, are non-empty, and were spot-checked with
  grep for the required content/absence of stale wording.

## Notes

No `.dotfiles` files were touched (out of scope, per the plan's non-goals). No live mail commands,
`mbsync`, `home-manager switch`, or `--execute` mutation was run (all verification was already
performed and documented in `.dotfiles` task 80). Task 815 is now fully closed across all six
phases.
