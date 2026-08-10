# Implementation Summary: Task #828

**Completed**: 2026-07-06
**Duration**: ~20 minutes

## Overview

Resolved all 862 duplicate-`U=NNN` Maildir filename collisions (860 in
`~/Mail/Logos/.Trash/cur`, 2 in `~/Mail/Logos/.Archive/cur`) left unresolved by task 826's
Phase 5. Used live, read-only IMAP verification against the ProtonMail Bridge server to
determine, for each colliding UID slot, which local file matched the server's current
Message-Id at that UID, then renamed the non-matching member to a fresh, non-colliding token.
Zero files deleted; zero server-side writes performed.

## What Changed

- `~/Mail/Logos/.Archive/cur/` — 2 files renamed (`U=1`->`U=864`, `U=2`->`U=865`).
- `~/Mail/Logos/.Trash/cur/` — 860 files renamed (fresh tokens `U=4646` through `U=5505`).
- `~/Mail/.logos-backup-20260706/task-828/` — created with all run artifacts: repair script,
  IMAP probe, decision log, verb logs, verification logs, and handoff note to task 826.
- No files in the neovim config repository were modified (all execution occurred against the
  live mail store at `~/Mail/`; task artifacts live under `specs/828_.../`).

## Decisions

- Corrected the Phase 2 UIDVALIDITY comparison: the plan referenced comparing server
  UIDVALIDITY against "the Phase 1 `.uidvalidity` snapshot," but the maildir-root
  `.uidvalidity` file actually stores `NearUidValidity` (the local side's own identity value),
  not the server-observed value. The correct comparison is against `FarUidValidity` recorded in
  each folder's `.mbsyncstate` — verified this matches server UIDVALIDITY exactly for both
  folders (Trash: 95457113, Archive: 95457115), and confirmed 0 Near/Far UID divergence across
  all 924+39 tracked pairs, validating the premise that local `U=NNN` corresponds directly to
  server UID `NNN`.
- Decision log implemented as append-safe JSONL (rather than TSV) with two extra fields
  (`new_filename`, `executed`) beyond the plan's minimum schema, for clarity when reviewing
  dry-run vs. executed entries.
- The deterministic import-batch tie-break for the `UNVERIFIED` category was implemented but
  never exercised — all 862 pairs resolved as `MATCHED` (0 `UNVERIFIED`), so the anomaly gate
  was never at risk of tripping.

## Plan Deviations

- **Phase 2 task "compare against `.uidvalidity` snapshot"** altered: corrected to compare
  against `.mbsyncstate`'s `FarUidValidity` instead, since the maildir-root `.uidvalidity` file
  holds an unrelated local value. This is a correction of an ambiguous plan reference, not a
  weakening of the safety gate — the gate was evaluated as intended and passed.
- **Decision-log schema** altered: JSONL only, with two additive fields beyond the minimum
  schema specified in the plan.

No task, phase, or safety gate was skipped or deferred.

## Verification

- Both folders' duplicate-UID checks (`ls <cur> | grep -oE 'U=[0-9]+' | sort | uniq -d`): empty.
- Zero deletes: `.Trash/cur` count 1945 -> 1945; `.Archive/cur` count 54 -> 54 (unchanged).
- Zero server writes: 10-sample re-fetch of server Message-Ids post-repair, all unchanged vs.
  the original in-run fetch; IMAP verb audit across every script confirms only
  `LOGIN`/`LIST`/`EXAMINE`/`UID FETCH BODY.PEEK`/`LOGOUT` were ever issued.
- Decision log complete: 1724 lines (dry-run + executed entries for both folders' full pair
  sets — 2 Archive pairs, 860 Trash pairs, each MATCHED).
- Hand-verification (Phase 4 pilot): confirmed both `.Archive` pairs are genuinely distinct
  messages (different Subject/From/Date) and the matched member's Message-Id is an exact string
  match to the server's reported value.

## Notes

Task 826 may now resume its Phase 5 state reset (clear `.Trash`/`.Archive`
`.mbsyncstate`/`.uidvalidity`) and Phase 7 scoped `mbsync logos` reconcile. See
`~/Mail/.logos-backup-20260706/task-828/handoff-to-826.md` for the full handoff note, including
the residual re-push risk noted for task 826's controlled reconcile to address. This task
performed no `mbsync` runs, no state clears, no `email-thaw`, and no notmuch reindexing — all
explicitly out of scope and left untouched.
