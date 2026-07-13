# Implementation Summary: Task #826 (resumed session — Phase 7 reconcile attempt)

**Completed**: 2026-07-06 (PARTIAL — new safety blocker found; task remains BLOCKED)
**Duration**: ~1.5 hours

## Overview

Resumed task 826 after task 828 fully resolved the Phase 5 duplicate-UID blocker (862
collision pairs, live-IMAP-verified rename-only repair, zero deletes, zero server writes).
Re-verified all safety preconditions, then attempted the Phase 7 controlled `mbsync logos`
reconcile per the plan's dry-run-first discipline. The dry-run hard-errored on both `.Trash` and
`.Archive` with mbsync's standard "UID beyond highest assigned UID" error — the plan's own
anticipated Phase-5-leftover state-reset trigger. Before performing that state reset, read-only
IMAP investigation (zero writes) surfaced two new findings serious enough to stop rather than
proceed: (1) `logos-sent`/`logos-archive` are drastically under-synced with the live server (a
~62,000-message pull scope far beyond this task's "161 staged Trash deletes" deliverable), and
(2) the true server-side disposition of the majority of the 862 task-828-renamed messages is
unverifiable via read-only means, so their duplicate-push safety cannot be confirmed. Phases 7
and 8 remain BLOCKED; no destructive action was taken.

## What Changed

- No files under `~/Mail/Logos` were modified. No `.mbsyncstate`/`.uidvalidity` file was written.
  No `mbsync` push/pull was executed (only one `-y`/`--dry-run` invocation, which by definition
  and by verified mtime made zero changes).
- `~/Mail/.logos-backup-20260706/task-826-phase7/` — new artifacts: the dry-run log and a
  `precheck/` directory of read-only IMAP cross-check scripts + JSON results.
- `specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md` —
  Phase 7/8 task checklists annotated with this session's findings and deviations; the Testing &
  Validation duplicate-UID checklist item flipped to satisfied (task 828's fix); the `mbsync
  logos` exit-0 item remains unsatisfied with an updated reason.
- `specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-7-blocker-report.md` (new) —
  full evidence-based analysis.
- `specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-7-handoff-20260706T204500Z.md`
  (new) — condensed phase-end handoff.

## Decisions

- Scoped the exploratory dry-run to the two affected channels (`logos-trash logos-archive`)
  rather than the full `logos` group, as an extra precaution beyond the plan's literal
  instruction, precisely because Sent/Archive's true sync health was unknown at that point.
- Built read-only IMAP cross-check tooling (LOGIN/EXAMINE/UID FETCH/UID SEARCH/LOGOUT only,
  modeled on task 828's `imap-probe.py` pattern) to empirically determine, rather than assume,
  whether the untracked local UID groups already carry Trash/Archive folder membership
  server-side. Control-verified the search mechanism against a fabricated Message-Id (correctly
  returned empty) before trusting its results.
- Discovered and ruled out a false lead: "All Mail" and the giant `Labels/benbrastmckie@gmail.com`
  view both show ~100% presence for every local group checked, but this is uninformative — those
  views function as the account's full canonical message store on this backend, not evidence of
  Trash/Archive-specific folder membership. Confirmed this via a targeted `UID SEARCH` control
  test before relying on the direct per-mailbox (`Trash`, `Archive`) presence checks instead.
- Concluded the responsible action, per the task's own explicit safety protocol ("if the dry-run
  reveals anything beyond the expected 161 staged deletes... STOP"), was to halt before any state
  file modification or live push, given both the scope explosion (Sent/Archive) and the
  irreducible ambiguity (duplicate-push risk for ~840 messages, dependent on undocumented
  ProtonMail Bridge APPEND-dedup behavior).

## Plan Deviations

- **Phase 7 task 2** altered: ran a narrower per-channel dry-run (`logos-trash logos-archive`)
  instead of the literal group-scoped `mbsync logos` command, and stopped after the dry-run
  hard-errored and further read-only investigation revealed new blocking findings, rather than
  proceeding to a live reconcile. See plan file Phase 7 for full annotation.
- **Phase 7 tasks 3-4** and **Phase 8 tasks 1-3**: remain not-reached/deferred; the underlying
  blocker changed in nature (from "duplicate UID corruption" to "unverified push-safety +
  unplanned pull-scope explosion") but the phases remain gated exactly as before.

## Phase 4 Labels-mirror non-goal (unchanged, reaffirmed per delegation instructions)

Per the plan's own Abort-criteria fallback (Phase 3 verification found 98-100% of `.Labels.*`
content has no copy elsewhere in canonical folders — real, unique mail, not redundant mirrors),
Phase 4 deliberately left all `.Labels.*` directories untouched, inert but harmless. This is a
confirmed, already-decided non-goal for this task, not a blocker: `logos-labels` is out of `Group
logos` (Phase 2), so these folders will not resync, grow, or otherwise require attention from
this task. No re-analysis was performed this session per explicit delegation instructions.

## Verification

- Duplicate-UID re-check: `.Trash` and `.Archive` both empty (task 828's fix holds).
- No mbsync/isync process running (before and after this session).
- Backup dir `~/Mail/.logos-backup-20260706/`: all 7 tarballs `tar -tzf`-verified intact, 28
  `.mbsyncstate*`/`.uidvalidity` snapshots present, task 828 artifacts present.
- `.mbsyncstate`/`.uidvalidity` mtimes for `.Trash`/`.Archive` unchanged before/after this
  session's dry-run (confirmed via `stat`).
- `mbsync logos` reconcile: NOT achieved. `notmuch new --no-hooks` reindex: NOT run (depends on
  Phase 7). Freeze/trigger-path discipline: maintained, not lifted.

## Notes

This is not a return to square one — task 828's fix is solid and independently re-verified. The
new blocker is a *different, more nuanced* problem than the original duplicate-UID corruption:
it is a scope/verification question (how much of this account's backlog should this reconcile
touch, and can the 862 renamed messages be pushed without creating server-side duplicates) rather
than a data-corruption question. A follow-up task should either (a) get an explicit scope
decision on the Sent/Archive backlog and a verified-safe push mechanism for the renamed messages
(e.g. a single-message pilot APPEND with human sign-off), or (b) quarantine the 862 renamed files
out of the synced Maildir tree and run a Trash-only (`mbsync logos-trash`, never the group)
reconcile limited strictly to the 161 genuinely-new-and-safe-to-push messages, deferring
Sent/Archive's backlog and the renamed-message disposition to separate, explicitly-scoped work.
