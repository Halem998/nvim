# Implementation Summary: Task #817

**Completed**: 2026-07-04
**Duration**: ~40 minutes

## Overview

Reconciled stale "documented-but-gated / pending `.dotfiles` task 79" multi-account language
across four `.claude/extensions/email/` files with the now-authoritative `wrapper-contracts.md`
ground truth: `--account <gmail|logos>` is a live, accepted enum on all five wrapper binaries,
verified 9/9 by `.dotfiles` task 80. Converted the `skill-email-cleanup` "Account Precondition
Gate" into a light "Account Liveness Check", fixed the broken `--help` probe, and aligned gate
naming between `skill-email-sync` and `commands/email.md`.

## What Changed

- `.claude/extensions/email/commands/email.md` — Rewrote the Accounts section, `<step_1>` gate
  description, Safety Notes bullet, and Error Handling entry to state `logos` is live/accepted,
  gated only by a step-1 liveness check (not a permanent precondition), while preserving loud
  rejection of unknown `--account` values and the never-silent-fallback invariant.
- `.claude/extensions/email/EXTENSION.md` — Rewrote the Commands table row and Safety Invariants
  bullets to remove "documented-but-gated"/"task 79 pending" framing; removed the literal "task
  79" mention from the `mail-guard.sh` footnote entirely (past-tense alone still tripped the
  grep sweep's `task 79` pattern, so the reference was rephrased without naming the task).
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — Renamed "Account Precondition
  Gate" to "Account Liveness Check"; replaced the broken `email-census --account logos --help`
  probe (which short-circuits before flag validation per wrapper-contracts.md line 41, so it
  never tested account acceptance) with `email-census --account logos` checked via exit
  code/stderr; updated the account param-table row and the Stage 0 step-0 gate reference.
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` — Removed "currently-reserved"/
  "don't yet accept" pending-tense framing from the channel-default section; renamed "`/email`'s
  Phase-1 precondition gate" to "`/email`'s step-1 precondition gate" to match
  `commands/email.md`'s `<step_1>` tag naming.
- `specs/817_reconcile_email_stale_multiaccount_gating/plans/01_reconcile-multiaccount-gating.md`
  — All 5 phases marked `[COMPLETED]`, all task checkboxes checked with completion notes, plan
  Status updated to `[COMPLETED]`.

## Decisions

- Treated the grep sweep (not the plan's cited line numbers) as the authoritative completeness
  gate, per the plan's explicit instruction — line numbers had shifted slightly and the sweep
  caught everything regardless of location.
- The EXTENSION.md footnote required removing the literal string "task 79", not just converting
  it to past tense ("task 79 adds" -> "task 79 added"), because the Phase 5 grep sweep's `task
  79` pattern matches the literal substring regardless of tense. Rephrased to describe the
  `--account` flag addition without naming the task number.
- Preserved the "never a silent fallback to Gmail" and "loud rejection on unknown value"
  invariants verbatim in every rewritten passage, since these remain true under the verified
  contract and were explicitly called out as goals to preserve.

## Plan Deviations

- None (implementation followed plan). The one adjustment — removing "task 79" entirely from the
  EXTENSION.md footnote rather than only reframing its tense — was anticipated by the plan's own
  framing ("update or remove the pending-tense reference") and is consistent with the plan's
  stated authoritative-grep-sweep principle, not a deviation from it.

## Verification

- Build: N/A (documentation-only change)
- Tests: N/A
- `bash .claude/scripts/check-extension-docs.sh` -> `[email] PASS` with the same 2 pre-existing
  unrelated warns (skill-email-implementation not deployed; README.md older than manifest.json);
  no new warnings/errors.
- Grep sweep across all four files for
  `task 79|gmail-reserved|documented[- ]but[- ]gated|documented but gated|currently.reserved|Phase-1 precondition|do not yet accept|don't yet accept|once the wrapper`
  returns zero hits.
- `skill-email-cleanup/SKILL.md` probe reads `email-census --account logos` (no `--help`), with
  exit-code/stderr checking documented.
- `skill-email-sync/SKILL.md` reads "step-1 precondition gate" (not "Phase-1").
- Manual read-through of all four edited regions confirms a single consistent narrative for
  `/email --logos`: live accepted account, light liveness check (not a hard gate), loud
  rejection of unknown values, never a silent fallback to Gmail.

## Notes

No wrapper binaries, `wrapper-contracts.md`, or `.dotfiles` content were touched — this was
scoped entirely to reconciling stale documentation in `.claude/extensions/email/` with the
already-verified contract. The two pre-existing `check-extension-docs.sh` warns are out of scope
per the plan's Non-Goals and were left untouched.
