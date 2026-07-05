# Implementation Summary: Task #820

**Completed**: 2026-07-05
**Duration**: ~45 minutes

## Overview

Task 820 fixed a gap where `/email --all`'s residual pass could not safely re-surface an
already-fully-classified mailbox for review. The fix spans two repositories: a new read-only
`email-classify --emit-tagged` mode was added to `~/.dotfiles`'s `classify.nix` wrapper binary,
and `skill-email-cleanup`'s `--all` mode (in this repo) was switched to consume it for the
residual count-probe and residual pass. Documentation in both repos was updated to describe the
new mode and correct a prior "emit-on-change" mischaracterization of `email-classify`'s default
mode.

## What Changed

- `~/.dotfiles/modules/home/email/agent-tools/classify.nix` — added `--emit-tagged` flag parsing
  and a new read-only branch (placed after `classify_one()`'s definition) that rebuilds
  `candidate-manifest.jsonl` from each message's existing `+proposed-*` tag; no `notmuch tag`
  call occurs in this branch; `classify_one()` is used only for display `confidence`/`reason`
  (prefixed `tag-derived;`); `--limit`/`MAX_BATCH_SIZE` do not apply. Updated `--help` text.
- `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` —
  §1 binary table updated; new §12 addendum documenting `--emit-tagged`'s safety class,
  tag-derived-action rule, and no-batch-cap behavior.
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `--all` mode Stage 1 count
  probe now uses `--emit-tagged` for the four residual buckets (new-message probe unchanged,
  still `--limit 0`); Stage 2 residual pass switched from `--limit <CHUNK_SIZE>` re-classify to
  `--emit-tagged`; added a distinct "0 new, all residual" status line before Stage 2.5; dropped
  the now-inapplicable per-tag-bucket completeness caveat (residual coverage is now complete by
  construction since `--emit-tagged` has no `--limit`).
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — §1 table row,
  §6 approval-provenance item 4, §10 "NOT emit-on-change" correction paragraph, and new §10a
  documenting `--emit-tagged`'s full contract.
- `specs/820_email_all_resurface_classified_gap/plans/02_email-all-emit-tagged.md` — all 5
  phases marked `[COMPLETED]`, with deviation annotations recorded inline.

## Decisions

- **Branch placement in `classify.nix`** (deviation from the plan's literal line reference): the
  plan suggested placing the new branch "near line 80, alongside `--append-approved`", but
  `--emit-tagged` calls `classify_one()` for display fields, and `classify_one()` is defined
  later in the file (alongside the classification rule tables). Since bash requires a function
  to be defined before it is called, the branch was placed immediately after `classify_one()`'s
  closing `}` instead — same early-exit control flow, no forward-reference bug.
- **Dropped the residual "documented completeness caveat"**: the old caveat existed because the
  prior residual pass used `--limit <CHUNK_SIZE>`, capping coverage per prior-tag bucket.
  `--emit-tagged` has no `--limit` and processes the full per-tag match in one call, so residual
  coverage is now complete by construction. A softer performance note (per-message `notmuch
  show` reads may be slower at very large per-tag bucket sizes) was added in its place, since no
  live mailbox was available in this environment to confirm the caveat could be dropped purely
  on scale grounds — the decision instead rests on the mechanism change itself (unbounded call,
  not chunked pagination).

## Plan Deviations

- **Task 1.1** (live-mailbox overwrite-to-empty probe) skipped: no live notmuch mailbox is
  reachable from this execution environment. Substituted a static-read confirmation of the
  default mode's `: > "$CANDIDATE_FILE.tmp"` truncation (matches report 02's verified analysis).
- **Task 1.2** (branch placement) altered: placed after `classify_one()`'s definition rather than
  near line 80, alongside `--append-approved` — see Decisions above.
- **Task 3.4 / Testing item** (residual completeness caveat) altered: dropped per the mechanism
  change (unbounded `--emit-tagged` call) rather than a scale-based judgment call, since no live
  mailbox was available to measure actual residual bucket sizes.
- **Task 5.3** (live end-to-end `--all` dry pass) skipped: no live mailbox available. Substituted
  a scripted logic test of the tag-parsing/jq-manifest-construction path against a synthetic
  tagged message, confirming correct `tag-derived;`-prefixed output. Recommend the user run one
  real `/email --all` pass to confirm live behavior when convenient.

## Verification

- Build: `.dotfiles` `classify.nix` — `nix-instantiate --parse` passed; an extracted shell-body
  `bash -n` syntax check passed.
- Tests: No live-mailbox test suite exists for this wrapper; a synthetic logic test of the
  `--emit-tagged` tag-case/jq-construction path passed (correct action derivation and
  `tag-derived;` reason prefixing).
- Files verified: Yes — all four modified files read back and grep-verified for the required
  invariants (no `notmuch tag` in the `--emit-tagged` branch; `--emit-tagged` referenced
  consistently in SKILL.md and both contract docs; new-message probe still uses `--limit 0`;
  mutation wrappers and `mode=default` untouched).

## Notes

- Two-repo commit hygiene followed: Phases 1-2 committed in `~/.dotfiles` (commit `ce20df9`,
  "task 72: add email-classify --emit-tagged read-only re-emit mode (nvim task 820)"). Phases
  3-4 content committed in this repo (commit `b0aa8743b`, "task 820 phase 3-4: switch
  skill-email-cleanup --all to --emit-tagged, document mode"), which also carried the plan
  file's phase-checkbox updates for Phases 1-4. This summary and the plan's Phase 5 checkbox
  updates remain for the orchestrator's task-tracking commit.
- Live end-to-end verification (Phase 5, Task 5.3) is the one open item: the next real
  `/email --all` run against a mailbox with existing `+proposed-*` tags should be watched to
  confirm the residual pass reconstructs Stage 2.5 review buckets without any tag-count change.
