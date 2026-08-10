# Implementation Summary: Task #805 — Two-Mode Mass-Cleanup Workflow

- **Task**: 805 - Improve the email/ extension's mass-cleanup workflow (default 50-step, `--all`, `--archive`)
- **Status**: [COMPLETED]
- **Started**: 2026-07-03T00:00:00Z
- **Completed**: 2026-07-03T00:00:00Z
- **Effort**: ~2 hours (single dispatch, 9/9 phases)
- **Dependencies**: None (frozen `.dotfiles` wrapper contract, task 72 — untouched)
- **Artifacts**: plans/02_two-mode-mass-cleanup.md (executed); this summary
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Extended `/email` and `skill-email-cleanup` in place with two decision-granularity modes
(default bounded 50-step vs. `--all` whole-mailbox) and an orthogonal `--archive` All Mail
scope flag, entirely wrapper-only against the frozen `.dotfiles` wrapper contract. Phase 1
ground-truth verification confirmed all five load-bearing wrapper behaviors and resolved the
open ID-capture question, engaging the plan's pre-authorized pagination fallback for the
`--all` sweep. All 9 phases completed; validation is doc-lint + dry-run reasoning (extension
has never been loaded — no live mailbox mutation).

## What Changed

- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — refreshed
  against `agent-tools.nix` ground truth (82 -> 209 lines): verified line references for
  `enforce_batch_size` per-action hard-refuse, mtime expiry semantics, per-path state files
  (incl. the separate `.expunge-state.jsonl` hop-2 companion), classifier constants (14
  domains), new §10 classify pagination contract (`--limit` head-cap/no offset, candidate
  manifest overwritten per call, `--limit 0` count oracle, no complete ID-emit path), §7a
  wrapper-internal `mbsync gmail` reconcile, §11 folder-scope token table.
- `.claude/extensions/email/commands/email.md` — 3-step argument parsing producing composable
  `(mode, scope, focus_hint)`; `--sync` earlier-matched with an explicit conflict rule;
  "Safety posture by invocation form" block.
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (98 -> 421 lines) — Stage 0
  mode/scope dispatch; default mode with the `+proposed-*` tag-exclusion cursor (never needs
  chunking or splitting); `--all` mode: count-oracle pre-sweep estimate, single backgrounded
  read/tag-only chunked sweep with accumulator + progress log, Stage 2.5 consolidated bucket
  approval (min() rollup, 0.90 option-availability gating, fix-it multiSelect idiom,
  [new]/[residual] labels), Stage 3 materialize, Stage 4 ≤50-per-action pairwise-packed splits
  with `touch -r` mtime preservation, Stage 5 transparent drain (per-split sha256, wrapper
  state-file idempotency, expiry stop-and-report, aggregate progress), Stage 6 all-splits
  verify; Archive Scope gates 1-6; Pilot Gate (`archive-pilot-ack.json`); expanded
  Constants/Critical Requirements.
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — NEW (78
  lines): blast-radius table, reversible-vs-hard boundary, asymmetric corroborated confidence
  policy, extra gates, pilot prerequisite, what archive scope does NOT change.
- `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md` — NEW (81
  lines, email layer).
- `.claude/context/patterns/batch-drain-loop.md` — NEW (84 lines, agent-system layer,
  domain-agnostic: one-approval capped-batch drain + chunked-sweep sibling).
- `.claude/extensions/email/index-entries.json` — registered archive-mode-risk.md and
  bulk-bucket-review.md; refreshed wrapper-contracts.md entry.
- `.claude/context/index.json` — registered patterns/batch-drain-loop.md.
- `.claude/extensions/email/README.md`, `EXTENSION.md` — modes/scope documented; Commands
  table extended (incl. previously-missing `--sync` row); Safety Invariants extended (cursor,
  sub-50 drain, mtime-preserve/expiry-stop, archive gates).

## Decisions

- **Phase 1 gate outcome: PROCEED.** All five load-bearing behaviors confirmed. The sixth
  item (ID capture) is an investigation with a pre-authorized fallback in the plan, not a
  load-bearing assumption: the QUERY positional accepts `id:`/`date:`/`tag:` terms, but no
  wrapper emits a complete ID list — so the `--all` sweep paginates by `--limit` +
  tag-exclusion (complete for never-classified mail) plus bounded per-tag residual passes,
  exactly per the plan's Risks/Rollback fallback.
- Discovered and documented the `email-classify --limit 0` **count oracle** (NOTE line
  discloses total matches, nothing processed/tagged) — used for pre-sweep estimates and
  non-silent residual accounting.
- Residual visibility: previously-classified messages are surfaced via aggregate pre-sweep
  counts, bounded residual re-classify passes (records marked `"residual": true`), and
  `[residual]` bucket labels — the tag-pagination exclusion is documented, never silent.
- Pilot gate front-loaded into Phase 6 (Stage-0-coupled); acknowledgement persisted as
  git-tracked `archive-pilot-ack.json` with a `chunk_size_verdict` tying CHUNK_SIZE=1000 to
  post-pilot confirmation.
- Mixed splits pack ≤50 archive + ≤50 delete lines per file (caps are per action, per file),
  halving drain file count; worked example 137a+60d -> 3 files.

## Plan Deviations

- **Task 4.1** altered: sweep pagination authored as `--limit` + tag-exclusion chunking (the
  plan's own pre-authorized fallback) because Phase 1 falsified the optimistic ID-capture
  branch.
- **Task 4.3** altered: the "NOT by tags" pagination statement inverted by ground truth; the
  underlying concern (silent exclusion of previously-declined mail) addressed via count-oracle
  residual accounting and `[residual]` labeling instead.
- **Task 5.2** altered (cosmetic): plan's "Stage 3.5 (drain)" authored as "Stage 5" with the
  plan name noted inline; added a Stage 3 materialize step giving the approval mtime a
  concrete origin file.
- **Task 9.1** altered: pilot gate authored in Phase 6, verified in Phase 9.

## Verification

- Build: N/A (documentation/skill meta task)
- Tests: N/A — validation per plan is doc-lint + dry-run reasoning
- Doc-lint: `.claude/scripts/check-extension-docs.sh` — **email extension PASS** after every
  doc-touching phase; the script's only FAIL is the pre-existing, unrelated lean-extension
  `routing_hard` issue (confirmed present before this task via `git stash` A/B check)
- Indexes: both `index-entries.json` and `context/index.json` jq-valid; batch-drain-loop entry
  discoverable via the agent-scoped index query
- Cross-references: all referenced files exist (wrapper-contracts §§ referenced from SKILL.md,
  archive-mode-risk.md, bulk-bucket-review.md, batch-drain-loop.md, skill-fix-it, skill-email-sync)
- Raw-binary scan: grep over changed skill/command/pattern files shows only
  descriptive/prohibitive mentions of `himalaya`/`notmuch` — no invocation instruction outside
  the five wrapper binaries; zero `.dotfiles` edits; MAX_BATCH_SIZE=50 untouched
- Files verified: Yes (all created/modified files exist, line counts recorded)

### End-to-End Dry-Run Walkthrough (Phase 9 record)

1. `/email` -> (default, inbox): census -> `email-classify --limit 50` with tag-exclusion
   cursor -> Stage 3 AskUserQuestion (root session) -> approved manifest + sha256 -> execute ->
   state-file diff. Second bare run classifies a different 50 (cursor advances by
   construction). ≤50/action by construction — can never trip `enforce_batch_size`.
2. `/email --all` -> (all, inbox): `--limit 0` probes (before sweep, never between chunks) ->
   ONE backgrounded read/tag-only sweep job (accumulate-before-overwrite, progress log,
   terminates on 0-chunk; crash-resume via tag exclusion) -> Stage 2.5 bucket approval in root
   session (min() rollup; sub-0.90 buckets never receive a delete option) -> materialize ->
   pairwise-packed ≤50/action splits with `touch -r` -> root-session drain, per-split sha256 +
   state files, expired split STOPS with residual report (never re-timestamps), no re-prompt ->
   all-splits verify.
3. `/email --archive` -> (default, archive): Stage 0 sets `folder:Gmail/.All_Mail` and checks
   the pilot gate (a 50-step pass is within pilot bound); review gate PLUS second
   blast-radius-naming confirmation before execute; deletes stop at Trash; `--expunge-trash`
   opt-in only; no auto-sync.
4. `/email --all --archive` -> full-scale REFUSED until `archive-pilot-ack.json` exists; after
   pilot: full sweep/drain with the corroborated (rule-tier) bulk-delete bar and all archive
   gates layered on the `--all` flow.
5. `/email --sync` -> earlier-matched distinct route to skill-email-sync (own confirmation
   stop); never combined with or auto-chained after cleanup; wrapper-internal per-run
   `mbsync gmail` reconcile documented as frozen contract behavior.

Invariant check across all five: wrapper-only everywhere; a human gate precedes every
mutating path; only the classify sweep is ever backgrounded; MAX_BATCH_SIZE never raised;
mtime preserved / expiry stops; `--archive` full scale blocked pre-pilot. All hold.

## Impacts

- `/email` default becomes strictly safer (bounded, forward-stepping) with no behavior loss.
- `--all`/`--archive` make whole-mailbox and archive cleanup possible without touching the
  frozen wrapper or weakening any safety invariant.
- The batch-drain-loop pattern is now reusable by any capped bulk-mutation workflow.

## Follow-ups

- Run the bounded `--archive` pilot once the extension is actually loaded into a consuming
  repo; record `chunk_size_verdict` and adjust `CHUNK_SIZE` if needed (owner: user, on first
  live use).
- Out-of-scope flagged follow-ons unchanged: classifier generalization, durable-rule
  writeback, maintenance-mode scheduling.

## References

- specs/805_improve_email_mass_cleanup_workflow/plans/02_two-mode-mass-cleanup.md
- specs/805_improve_email_mass_cleanup_workflow/reports/02_two-mode-batching-design.md
- specs/805_improve_email_mass_cleanup_workflow/reports/01_team-research.md
- ~/.dotfiles/modules/home/email/agent-tools.nix (ground truth, read-only)
- .claude/extensions/email/ (all touched files listed in What Changed)
