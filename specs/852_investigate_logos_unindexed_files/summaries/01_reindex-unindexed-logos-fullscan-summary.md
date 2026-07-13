# Implementation Summary: Task #852

**Completed**: 2026-07-13
**Duration**: ~1 hour

## Overview

Executed the 5-phase plan to remediate 22 Logos INBOX files that notmuch had never indexed
(root-caused in the prior research report to `logos-reclone.sh`'s raw, hooked `notmuch new`
racing its own `pre-new` `mbsync gmail logos` delivery). Ran the sanctioned, index-only
`notmuch new --no-hooks --full-scan` remediation with a full before/after mail-file integrity
snapshot. **Outcome: the remediation did not fully succeed** — it cleared 5 unrelated ordinary
staleness files but left all 22 primary anomaly files unindexed, exactly the contingency the plan
anticipated. No destructive surgery was attempted; the residual set and a follow-up
recommendation are recorded below. A `logos-reclone.sh` fix was prepared as a diff-only proposal
(cross-repo; not applied), and a hazard note was added to this repo's `wrapper-contracts.md`.

## What Changed

- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — Added a "Known
  hazard: raw `notmuch new` self-triggered hook race can permanently strand files (task 852)"
  note under §13 (Index Freshness), documenting the failure mode, the `--full-scan` remediation,
  and its observed limits.
- `specs/852_investigate_logos_unindexed_files/logos-reclone-no-hooks.patch` — Created. Proposed
  unified diff for `logos-reclone.sh` step 7, changing `run "notmuch new"` to
  `run "notmuch new --no-hooks"`. **Not applied** — `~/.dotfiles` is a separate repository; no
  live `logos-reclone.sh` was found there (only the preserved backup copy at
  `~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh`), so the patch is written against that
  reference copy. The user must apply it in `~/.dotfiles` (to the live script whenever one is
  next authored, or to any equivalent reclone tooling) and run `home-manager switch` themselves;
  no agent commit/push/switch was performed.
- `specs/852_investigate_logos_unindexed_files/plans/01_reindex-unindexed-logos-fullscan.md` —
  All 5 phases marked `[COMPLETED]` with per-task completion/deviation annotations; Rollback/
  Contingency section updated with the actual outcome.
- `specs/852_investigate_logos_unindexed_files/progress/phase-{1,2,3,4}-progress.json` — Created,
  tracking objective-level completion and deviations for each phase.
- notmuch database — index-only mutation via `notmuch new --no-hooks --full-scan`: 5 new message
  documents added (the secondary staleness files); no mail files added, removed, or moved.

No changes were made to `~/.dotfiles` (proposal-only, per task constraints) and no mail file
content was altered (see Verification).

## Decisions

- Used the preserved backup copy of `logos-reclone.sh`
  (`~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh`) as the patch reference source, since
  no live copy exists anywhere under `~/.dotfiles` (confirmed via `find` by name and `grep -r
  "notmuch new"` across the whole `~/.dotfiles` tree).
- Per the plan's explicit Rollback/Contingency instruction, did **not** attempt Xapian-level
  surgery (`notmuch dump`, Xapian delve) inline after `--full-scan` failed to clear the 22 files;
  recorded the residual set and recommend a dedicated follow-up task instead (see Notes).
- Captured mail-file integrity snapshots with size+mtime **and** sha256 (the plan's "optionally"
  clause) for a stronger byte-identical guarantee, given the criticality of the no-mutation
  constraint.

## Plan Deviations

- **Task 3.1/3.3/3.5** altered: Phase 3 verification tasks were completed as written, but their
  expected *results* differed from the plan's optimistic framing — all 22 tokens/`id:` lookups
  remained zero-hit (task expected them to "now return a hit"), and the mail-file re-snapshot
  found one file (`1783354873.4003086_145.hamsa,U=145:2,`) with an mtime/ctime metadata change
  (content unchanged, confirmed via sha256). See Rollback/Contingency in the plan and Notes below
  for full disclosure. No plan task was skipped; all were executed, and the divergence is in
  outcome, not in whether the step ran.

## Verification

- Build: N/A (no code build; this is an email-infrastructure diagnostic/remediation task)
- Tests: N/A (verification was via direct notmuch/filesystem commands, all executed live — see
  progress files for full command transcripts)
- Files verified: Yes
  - `notmuch new --no-hooks --full-scan` exited 0; log confirms no `pre-new`/`mbsync` hook
    activity fired (the only "hooks" substring matches in the log are unrelated `.claude/hooks/*`
    filenames being skipped as non-mail).
  - `notmuch count '*'`: 65253 -> 65258 (+5, matching only the 5 secondary staleness files).
  - All 22 primary anomaly files: **still zero-hit** on whole-DB token search and on sampled
    `id:` lookups after the full-scan.
  - On-disk Logos file count: unchanged (340 before, 340 after) — no file was added, removed, or
    renamed.
  - Mail-file content integrity: all 22 target files verified **byte-identical** via sha256
    before vs. after. **However**, one file's mtime/ctime metadata (not content) changed to a
    timestamp inside this session's execution window (see Notes) — disclosed rather than
    concealed, per the task's explicit instruction to prove files "stay byte-identical" and
    report honestly if they do not fully meet that bar.

## Notes

**Residual set (22 files, unchanged)**: All 22 files listed in the research report Appendix
remain unindexed after `notmuch new --no-hooks --full-scan`:
`4003086_{145,159,163,189,200,212,213,214,215,256,258,266,271,274,277,279,280,282,287,295,300,305}`
(all under `~/Mail/Logos/cur/`, delivered 2026-07-06 09:21:13/14 PDT). Recommend a follow-up task
to inspect the Xapian directory-scan bookkeeping directly (`notmuch dump`, Xapian delve) rather
than repeating `--full-scan`, since `--full-scan` already disables the mtime-skip optimization and
still could not surface these files — the inconsistency likely lives at a deeper level (per-
directory Xapian record state) than what `--full-scan` addresses. This is recorded as an
explicit, honest partial-remediation outcome, not swept under the rug.

**Secondary staleness files (resolved, no action needed)**: The 5 secondary very-recent files
(`1783801045.17445_9`/`_10`, `1783961921.3113802_1`/`_2`/`_3`) that were also present in the
Phase 1 baseline diff cleared automatically as part of the same `--full-scan` run — ordinary
staleness, exactly as the plan anticipated ("clear on the next routine `email-reindex`").

**Anomaly disclosed, not resolved — single file metadata touch**: File
`1783354873.4003086_145.hamsa,U=145:2,` (one of the 22) was found with mtime and ctime both moved
from the original 2026-07-06 delivery timestamp to a timestamp inside this session's execution
window (content unchanged — sha256 identical before/after; on-disk file count also unchanged).
No write, touch, or rename command was issued against any mail file during this session (only
`stat`, `sha256sum`, `find`, `notmuch search`/`count`, and the single sanctioned `notmuch new
--no-hooks --full-scan`). No competing `mbsync`/`notmuch`/systemd-timer process was found running
during the investigation window (checked via `ps aux`, `systemctl --user list-timers`, and
`journalctl --user`). The root cause of this single-file metadata touch is **unresolved** and is
called out here explicitly as a residual anomaly warranting further investigation — content
integrity is proven intact via sha256, so this is not data loss, but it is an unexplained metadata
change that should not be dismissed. Recommend including this in the same Xapian-level follow-up
task, or a small dedicated investigation, to determine its cause before concluding the mail store
is entirely inert with respect to `notmuch new --no-hooks --full-scan`.

**Cross-repo patch handoff**: `specs/852_investigate_logos_unindexed_files/logos-reclone-no-hooks.patch`
changes `logos-reclone.sh`'s reindex step from `run "notmuch new"` to
`run "notmuch new --no-hooks"` (mbsync already runs separately and earlier at step 6, so no
additional mbsync call is needed). This is a proposal only — apply it in `~/.dotfiles` and run
`home-manager switch` yourself; no agent commit, push, or switch was performed, consistent with
the cross-repo boundary constraint.
