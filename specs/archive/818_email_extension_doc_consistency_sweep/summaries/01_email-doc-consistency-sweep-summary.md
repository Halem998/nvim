# Implementation Summary: Task #818

**Completed**: 2026-07-04
**Duration**: ~25 minutes

## Overview

Applied all four MEDIUM findings (3-6) deferred from the review-2026-07-04 email extension
review, closing out the remaining Gmail-only and ambiguous documentation across
`.claude/extensions/email/`. All edits are doc-only rewording/additions with no wrapper or code
behavior change, and all edit sites were located by content/grep rather than the review's
original line numbers, since task 817 had already shifted three of the five target files.

## What Changed

- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — retitled line 1
  off "All Mail Scope" to "Account Archive Scope"; added a mirrored "Archive of record, per
  account" table (gmail ~64,000 / logos ~54 messages) beneath the Blast Radius table; made Gate #1
  a two-account confirmation-string pair; made Gate #3 use `mbsync <account-channel>` instead of
  the gmail-only literal.
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — collapsed the pilot-ack
  "either a top-level `account` field, or separate per-account files — pick one" ambiguity into a
  single hardcoded convention: always `$MANIFEST_DIR/archive-pilot-ack.json`, a JSON array of
  per-account records, with explicit create-if-absent / replace-or-append-by-account write
  semantics, matching the existing Gate-check text unchanged.
- `.claude/extensions/email/README.md` — reworded the Purpose section off Gmail-only framing;
  added a new "Accounts" subsection mirroring `commands/email.md`'s Accounts block; made the
  `--archive` bullet and the `/email --sync` section account-generic (both accounts' archive
  folders/sizes and target folders named); generalized the `archive-mode-risk.md` file-inventory
  entry.
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` — added a Stage 3 channel/account
  mismatch check that surfaces an explicit warning inside the confirmation prompt when an
  explicit `--sync` channel disagrees with the resolved account's default channel; added a
  trailing cross-reference to this check on the "explicit override wins" bullet.
- `.claude/extensions/email/commands/email.md` — added a descriptive clause to the `--sync
  [channel]` Input bullet and a new `<interactive_errors>` bullet documenting the mismatch-warning
  path, kept consistent with `skill-email-sync/SKILL.md`'s wording.

## Decisions

- For Finding 4, chose the single-file array-of-records convention (not per-account filenames)
  because the pre-existing Gate-check text already assumed one file path — the fix conforms the
  ambiguous upstream text to the already-fixed downstream text, rather than the reverse.
- For Finding 3's blast-radius table, added a short mirrored per-account table beneath the
  existing INBOX/Archive comparison table rather than splitting the comparison table's cells,
  to keep the mirrored figures easy to diff against `skill-email-cleanup/SKILL.md`'s
  authoritative table.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation-only task)
- Tests: N/A
- `bash .claude/scripts/check-extension-docs.sh`: `[email]` section PASS (only pre-existing,
  unrelated WARN about `skill-email-implementation` routing target not being deployed in this
  repo). Overall summary shows `core` and `lean` FAIL, both pre-existing and out of scope.
- Files verified: Yes — re-grepped all five edited files for stale Gmail-only holdouts and
  confirmed the mismatch warning appears in both Finding-6 files.

## Notes

`git diff --stat` for `.claude/extensions/email/` also shows `EXTENSION.md` as modified; this is
a pre-existing uncommitted change from task 817 (not committed to git before this task started)
and was not touched by this task.
