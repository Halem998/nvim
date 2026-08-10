# Implementation Summary: Task #826

**Completed**: 2026-07-06 (PARTIAL — safety-blocked)
**Duration**: ~2 hours

## Overview

Executed the 8-phase Logos/ProtonMail-Bridge mail-infrastructure repair plan under strict
safety constraints (live user data, cross-repo, partially destructive). Phases 1, 2, 3, 4, 6
completed (Phase 4 via a documented safety fallback); Phase 5 is blocked by a critical,
plan-invalidating discovery; Phases 7 and 8 were consequently not attempted. The config fix
(the config-side root cause of the bloat and the dotted-folder crash) is fully applied and
verified. The `.Trash`/`.Archive` duplicate-UID reconcile-blocking defect remains unresolved and
requires a dedicated follow-up task — see "Critical Findings" below.

## What Changed

- `~/.dotfiles/modules/home/email/mbsync.nix` — removed `logos-labels` from `Group logos`
  (kept the channel definition for manual inspection), added explanatory comments mirroring the
  existing `gmail-trash`/`gmail-spam` precedent. Committed as `~/.dotfiles` commit `a8f65ad`.
  Applied via `home-manager switch --flake .#benjamin`; live `~/.mbsyncrc` verified to no longer
  list `logos-labels` under `Group logos`.
- `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S` —
  removed (confirmed headerless test-scaffolding message, the sole missing-`Date:`-header file in
  the entire tree). Backed up first.
- `~/Mail/.logos-backup-20260706/` — full backup artifacts: `.mbsyncstate`/`.uidvalidity`
  snapshots (28 files), 7 per-folder tarballs (`.Trash`, `.Archive`, `.Sent`, and all 4 non-empty
  `.Labels.*` folders), Phase 3 verification data, Phase 5 dedup analysis data, Phase 6 backup,
  baseline and final filesystem counts.
- No other files under `~/Mail/Logos` were modified. `.Labels.*` content (38,041 files) and
  `.Trash`/`.Archive` (860+2 duplicate-UID pairs) remain completely untouched.
- `email-freeze` is still in effect (deliberately not lifted).

## Decisions

- Ran an independent Logos-specific backup (state files + per-folder tarballs + baseline counts)
  in Phase 1 because `email-freeze`'s own backup only covers `~/Mail/Gmail`.
- Phase 2's config fix was verified at three levels (Nix build succeeds, home-manager switch
  applies, and the *live* generated `.mbsyncrc` reflects the change) before considering it done.
- Phase 3's verification methodology was rebuilt after an initial colon-split parsing bug (maildir
  filenames contain literal colons in the `U=NNN:2,FLAGS` suffix) produced corrupted output;
  switched to NUL-separated `grep -Z -H` and independently spot-checked both positive and negative
  cases before trusting the result.
- Phase 4 and Phase 5 both hit genuine, evidence-based safety gates (see Critical Findings) and
  were deliberately not forced through, per the explicit orchestrator safety directive to stop and
  mark a phase `[PARTIAL]`/`[BLOCKED]` with a documented blocker rather than force a destructive
  step whose safety could not be established.

## Critical Findings (plan-invalidating discoveries)

1. **Phase 3 — `.Labels.*` is mostly NOT redundant.** Direct Message-Id verification across all
   files in `.Labels.Important`/`.Labels.Letters`/`.Labels.EuroTrip`/`.Labels.CrazyTown` against
   every canonical folder shows 98.4% / 99.8% / 62.5% / 100% of their content (respectively) has
   no copy anywhere else in `~/Mail/Logos` (this account has no "All Mail"-equivalent channel).
   The plan's assumption that these folders were near-total duplicate mirrors safe to bulk-delete
   is false for the two largest folders. Full report:
   `handoffs/phase-3-verification-report.md`.
2. **Phase 5 — the "duplicate UID" pairs are NOT copies of one message.** Verified all 862
   duplicate-UID pairs (860 `.Trash` + 2 `.Archive`) — every single pair has two files with
   **different** Message-Id values (confirmed with `Date:` header spot-checks spanning 2022-2026).
   These are distinct, irreplaceable real messages that collided on the same local UID number due
   to the 2026-02-09 import corruption, not redundant copies. The plan's "choose a copy to keep,
   remove the other" instruction would have destroyed 862 real messages. Full report:
   `handoffs/phase-5-blocker-report.md`.

Both findings independently invalidate a "simple mirror/duplicate cleanup" framing for their
respective folders. No data was lost in either case — both phases stopped before any destructive
action, per the explicit safety mandate for this task.

## Plan Deviations

- **Phase 4** (`.Labels.*` deletion): skipped both the move-label-only-messages and
  delete-mirror-content tasks; applied the plan's own documented Abort-criteria fallback
  (leave inert). Marked `[PARTIAL]`.
- **Phase 5** (`.Trash`/`.Archive` dedup + state reset): skipped keep/remove decisions and the
  state-file clear; no safe automated resolution exists without live IMAP verification (out of
  scope) or an uncertain rename-only workaround. Marked `[PARTIAL]`.
- **Phase 7** (reconcile): not attempted — depends on Phase 5. Marked `[BLOCKED]`.
- **Phase 8** (reindex + lift freeze): not attempted — depends on Phase 7. Marked `[BLOCKED]`.
  Freeze deliberately left in effect.

## Verification

- Phase 2 config fix: Nix build succeeded; `home-manager switch --flake .#benjamin` applied
  cleanly; live `~/.mbsyncrc` confirmed `logos-labels` removed from `Group logos`.
- Phase 6: post-deletion missing-`Date:`-header scan over the full tree returns 0 results.
- Final vs. baseline filesystem count diff: only `.Sent` changed (12 -> 11, the one Phase 6
  deletion); TOTAL 43660 -> 43659. All other folders, including `.Labels.*` and `.Trash`/
  `.Archive`, are byte-count-identical to the Phase 1 baseline.
- `.Trash`/`.Archive` `.mbsyncstate` files confirmed byte-identical (via `diff -q`) to their Phase
  1 backup copies — nothing was touched.
- `mbsync logos` was NOT run (Phase 7 blocked); `/email --logos --sync` was NOT run at any point,
  per the explicit prohibition.

## Notes / Recommended Follow-up

1. **New task recommended**: resolve the `.Trash`/`.Archive` duplicate-UID corruption via a live,
   read-only IMAP UID/Message-Id verification against the Bridge account (862 lookups), or a
   human-reviewed manual pass starting with the 2 tractable `.Archive` pairs. Until this lands,
   `mbsync logos` will continue to fail to reconcile and the 161 staged Trash deletes cannot reach
   the server.
2. **New task recommended** (lower priority): decide, with human input, the disposition of the
   ~37,412 label-only messages in `.Labels.Important`/`.Labels.Letters` (fold into a canonical
   folder, or leave as a permanent local archive — no urgency since they are inert and harmless).
3. `email-freeze` is still active. Do not run `mbsync` manually, press aerc's `$` keybind, or run
   plain `notmuch new` (use `notmuch new --no-hooks` if a reindex is needed in the interim) until
   `email-thaw` is run after the follow-up task above resolves the Phase 5 blocker.
