# Phase 7 Blocker Report: Reconcile — Scoped `mbsync logos`

**Date**: 2026-07-06
**Status**: BLOCKED — new findings, no destructive action taken
**All actions this session were read-only** (file reads, `ls`/`find`, one `mbsync -y` dry-run,
read-only IMAP `LOGIN`/`EXAMINE`/`UID FETCH`/`UID SEARCH`/`LOGOUT`). Zero writes to any
`.mbsyncstate`/`.uidvalidity` file, zero maildir file changes, zero IMAP `STORE`/`APPEND`/`COPY`/
`EXPUNGE`. Verified via `stat` mtimes before/after (unchanged) and duplicate-UID re-checks.

## 1. Preconditions re-verified (all PASS)

| Precondition | Result |
|---|---|
| `pgrep mbsync` / `pgrep isync` | empty — no process running |
| `ls .Trash/cur \| grep -oE 'U=[0-9]+' \| sort \| uniq -d` | empty |
| `ls .Archive/cur \| grep -oE 'U=[0-9]+' \| sort \| uniq -d` | empty |
| `.Trash` file count | 1945 (matches task 828's post-repair figure) |
| `.Archive` file count | 54 (matches task 828's post-repair figure) |
| Backup dir `~/Mail/.logos-backup-20260706/` | intact — all 7 tarballs `tar -tzf` clean, 28
  `mbsyncstate/` snapshot files present, `task-828/` artifacts present |
| No systemd timer / cron triggers mbsync | confirmed (`systemctl --user list-timers`, no
  crontab installed) |
| Only known trigger paths | notmuch `preNew` hook (`mbsync -a`) and aerc `$` keybind — neither
  was invoked this session |

Task 828's Phase 5 fix holds exactly as reported: every Trash/Archive UID slot maps to one
physical file.

## 2. New finding A: mbsync now hard-errors on BOTH channels (expected, but blocking)

Ran the plan-mandated dry-run first (`mbsync -y -V logos-trash logos-archive`, isync 1.5.1,
`-y`/`--dry-run` = "do not actually modify anything" per `mbsync --help`):

```
Channel logos-trash
...
Maildir error: UID 945 is beyond highest assigned UID 924 in /home/benjamin/Mail/Logos//.Trash.
Channel logos-archive
...
Maildir error: UID 48 is beyond highest assigned UID 39 in /home/benjamin/Mail/Logos//.Archive.
Channels: 2    Boxes: 2    Far: +0 *0 #0 -0    Near: +0 *0 #0 -0
```

Exit 1. `.mbsyncstate`/`.uidvalidity` mtimes for both folders confirmed unchanged after this run.

Root cause (confirmed against `.mbsyncstate` contents + community reports on this exact isync
error string): `.Archive/.mbsyncstate` records `MaxPulledUid 39` / `MaxPushedUid 39`, but the
Maildir now (and, critically, **already before task 828 touched anything**) contains files with
`U=` tokens up to 865. Same pattern in `.Trash`: state records `MaxPulledUid 924`, disk has
tokens up to 5505. mbsync's Maildir driver treats any local UID token above the recorded ceiling
as fatal corruption and refuses to proceed at all — for the *whole* channel, not just the
offending files. This is the standard, plan-anticipated "narrow state reset" trigger (Phase 5's
unexecuted final task). No `.mbsyncstate.journal` file exists for either folder (checked), so
there is no crash-safe journal to auto-replay — a manual bump/reset really is required before
either channel can sync at all.

**However**, a precise breakdown of the untracked UIDs reveals this is not a simple "just bump
the ceiling" fix — see Finding C.

## 3. New finding B: Sent and Archive are drastically out of sync with the server (scope
explosion far beyond "161 staged Trash deletes")

Read-only `EXAMINE` against every mailbox on the Bridge server (127.0.0.1:1143), compared to
local file counts:

| Mailbox | Server `EXISTS` | Local file count | Gap |
|---|---|---|---|
| INBOX | 3,569 | 3,567 | ~synced |
| Drafts | 42 | 41 | ~synced |
| Trash | 1,313 | 1,945 | local ahead (expected: staged deletes) |
| **Sent** | **26,187** | **11** | **~26,176 messages never pulled locally** |
| **Archive** | **36,232** | **54** | **~36,178 messages never pulled locally** |
| All Mail | 68,405 | n/a (virtual) | — |
| Labels/benbrastmckie@gmail.com | 65,373 | n/a (Labels, out of scope per Phase 4) | — |

`logos-sent` and `logos-archive` are both plain `Create Both / Expunge Both` channels with no
`MaxMessages`/expire limiting (the `MaxMessages 50` line in `~/.mbsyncrc` belongs to the Gmail
account block, confirmed by line position — it does not apply to any `logos-*` channel). The
plan's Phase 7 scope ("push the 161 staged Trash deletes," 1-hour budget) never anticipated that
invoking the **group** `mbsync logos` would also attempt to reconcile two channels that are
100-1000x under-synced. A live (or even a full non-dry-run) group reconcile would attempt to pull
roughly 62,000 new messages into `.Sent`/`.Archive` — a multi-hour, large-disk operation with no
connection to this task's stated deliverable, and never verified safe by any prior phase.

This is a pre-existing condition, not something introduced this session or by task 828 (verified
via direct, read-only `EXAMINE` counts, no state was touched).

## 4. New finding C: disposition of the 862 task-828-renamed messages on push is genuinely
ambiguous — cannot be resolved via read-only inspection alone

Built local Message-Id sets for four groups and cross-checked each against the live server via
read-only `UID FETCH`/`UID SEARCH` (scripts and raw JSON preserved at
`~/Mail/.logos-backup-20260706/task-826-phase7/precheck/`):

| Group | Count | Already present in its OWN target mailbox (Trash/Archive) server-side |
|---|---|---|
| 161 "legit" untracked Trash files (UID 945-4645, distinct from task 828's range) | 161 | 5 |
| 860 task-828-renamed `.Trash` files (UID 4646-5505) | 860 | 20 |
| 13 pre-existing untracked `.Archive` files (UID 48-863, predate task 828) | 13 | 0-1 |
| 2 task-828-renamed `.Archive` files (UID 864-865) | 2 | 0 |

Cross-checking the "not found in own mailbox" remainder against INBOX/Sent/Drafts/Spam/Starred
found only a handful more matches (control-verified: a fabricated Message-Id correctly returns
empty from `UID SEARCH`, and the real absent/present results were spot-verified with direct
`UID SEARCH HEADER Message-Id` calls, not just the bulk-fetch parse). Checking against "All Mail"
(68,405 messages) found **100% of every group** present — but this is expected and uninformative:
"All Mail" on this Bridge account behaves as the account's full canonical message store (it
contains virtually every message regardless of current folder), so "found in All Mail" only
confirms these are real, previously-delivered messages (consistent with task 828's own finding),
not that they currently carry Trash/Archive folder membership.

**The unresolved question**: for the ~840 `.Trash`-renamed and ~14 `.Archive` messages that do
NOT currently show Trash/Archive folder membership server-side, would an `mbsync` `APPEND` push
(a) correctly add the folder tag to the message that already exists in the account's canonical
store (safe, desired outcome — Gmail's real IMAP is documented to deduplicate same-content
APPENDs into an existing message this way), or (b) create a genuine second physical copy in
ProtonMail's backend (the duplicate-creation risk task 828 explicitly flagged and handed off)?
This depends entirely on whether ProtonMail Bridge implements Gmail-style APPEND deduplication —
which is NOT something a read-only IMAP probe can determine, and I found no authoritative
documentation confirming Bridge does this. Bridge is a different backend from real Gmail; the
"Labels/benbrastmckie@gmail.com" name on this account is a label artifact, not evidence Bridge
shares Gmail's storage-layer dedup behavior.

## 5. Decision: STOP, do not run the live reconcile

Per the explicit safety protocol for this task: *"If the dry-run reveals anything beyond the
expected 161 staged deletes... STOP and report a blocker with specifics. Do NOT force through a
failed data-integrity or server-push gate."* Finding B alone (a ~62,000-message unplanned pull
scope) and Finding C (irreducible ambiguity on ~850 messages' duplicate-push risk) both clearly
qualify. No `.mbsyncstate`/`.uidvalidity` file was modified, no `mbsync` push/pull was executed,
and the freeze/backup remain fully intact. Phase 7 and Phase 8 remain **BLOCKED**.

## 6. Recommended path forward (for a follow-up task / human decision)

1. **Scope decision needed**: should `logos-sent`/`logos-archive`'s first-ever full pull
   (~62,000 messages) happen at all via this mechanism, and if so, on what timeline/disk budget?
   This is an out-of-band decision this implementation session should not make unilaterally.
2. **Narrow, Trash-only push path**: if the intent is strictly "push the 161 staged Trash
   deletes" as scoped, a follow-up should invoke `mbsync logos-trash` alone (never the `logos`
   group), after resolving Trash's own UID-ceiling block — but only after either (a) quarantining
   the 860 task-828-renamed files out of `.Trash/cur` first (they are fully preserved in the
   Phase 1 tarball and task 828's decision log regardless of maildir location), so a Trash-only
   push cannot touch them, or (b) getting a documented, verified answer on Bridge's APPEND-dedup
   behavior (e.g. a single-message pilot APPEND with before/after "All Mail" UID-count
   verification, done with explicit human sign-off given its potential irreversibility).
3. **Archive's 13+2 untracked/renamed files**: same treatment — quarantine or verify before any
   push.
4. **Do not lift `email-freeze`** (not applicable — no Logos-specific freeze tool exists beyond
   "no process running + trigger-path awareness"; that discipline should continue) until Phase 7
   is actually resolved.

## Artifacts

- `~/Mail/.logos-backup-20260706/task-826-phase7/mbsync-dryrun-trash-archive.log` — the dry-run
  output.
- `~/Mail/.logos-backup-20260706/task-826-phase7/precheck/` — all read-only IMAP probe scripts
  and their JSON output (`local-msgids.json`, `crosscheck-results.json`, `mailbox-counts.json`,
  `final-disposition.json`, `allmail-check.json`, `labelcheck.json`).
