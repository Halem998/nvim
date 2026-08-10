# Phase 3 Verification Report: Labels-Mirror Redundancy Gate

**Date**: 2026-07-06
**Method**: Direct filesystem enumeration and per-file `Message-Id:` header extraction
(NOT notmuch queries, per report caveat). Raw data under
`~/Mail/.logos-backup-20260706/phase3/`.

## Methodology

For each `.Labels.*` folder and each canonical folder (top-level INBOX `cur`/`new`, `.Archive`,
`.Sent`, `.Drafts`, `.Trash`), extracted the `Message-Id:` header value of every file via
`grep -Z -H -i -m1 "^message-id:"` (NUL-separated to safely handle maildir filenames, which
contain literal colons in the `U=NNN:2,FLAGS` suffix — an initial colon-split approach produced
corrupted output and was discarded before this report was written). Computed
`comm -23 <labels-sorted> <canonical-union-sorted>` to find the label-only set. Every Message-Id
match was file-count-verified against the Phase 1 baseline (`.Labels.Important`: 37540/37540
files matched a Message-Id header, etc. — no headerless files in the Labels folders). Spot-checks
independently confirmed both a positive case (a Message-Id present in both a Labels folder and a
canonical folder) and several negative cases (a Message-Id absent from all canonical folders,
verified via precise header-anchored search, not substring match) before this report was
finalized.

## Results

| Folder | Files | Unique Message-IDs | Overlap w/ canonical | Label-only | % label-only |
|---|---|---|---|---|---|
| `.Labels.Important` | 37540 | 37540 | 615 | **36925** | **98.4%** |
| `.Labels.Letters` | 488 | 488 | 1 | **487** | **99.8%** |
| `.Labels.EuroTrip` | 8 | 8 | 3 | 5 | 62.5% |
| `.Labels.CrazyTown` | 5 | 5 | 0 | 5 | 100.0% |

Canonical union (`.Archive` + `.Sent` + `.Drafts` + `.Trash` + top-level INBOX `cur`/`new`):
5615 unique Message-IDs. `.Folders/` is empty (0 files, confirmed), so it contributes nothing to
the canonical set.

## Finding: The Plan's Core Redundancy Assumption Is Invalidated

The plan's Overview/Goals assumed `.Labels.*` folders are near-total **duplicate mirrors** of
messages that also live in a canonical folder (i.e., that deleting the label mirrors is safe
because Bridge already stores every message primarily under a canonical folder, with the label
folder being an additive, redundant view). **Direct verification shows the opposite for the two
largest folders**: 98.4% of `.Labels.Important` and 99.8% of `.Labels.Letters` content has **no
copy anywhere else** in `~/Mail/Logos` — not in INBOX, `.Archive`, `.Sent`, `.Drafts`, `.Trash`,
`.Folders`, or any other `.Labels.*` folder. These are very likely messages that Protonmail Bridge
presented as "archived + labeled" without exposing an "All Mail"-equivalent canonical location
over this account's IMAP surface (this account has no `logos-all`/"All Mail" channel, unlike the
Gmail account's `gmail-all`), so the `.Labels.*` mirror is, for these ~37,412 messages
(36925 + 487), the **only local copy of that mail**.

This is confirmed by three independent checks, not just the primary set-difference:
1. File-count parity: every file in each Labels folder has exactly one Message-Id header (no
   headerless files skewing the count).
2. A positive spot-check: `<0000000000004248c0058d4d69fc@google.com>` appears in both
   `.Labels.Important/cur` and the top-level INBOX `cur/`, confirming the overlap-detection path
   works correctly.
3. Multiple negative spot-checks (e.g. `<000000000000104a3105afc3f142@google.com>`,
   `<00000143826185db-...@email.amazonses.com>`, `<30087966...@mail1.interfolio.com>`): each
   confirmed absent from every canonical folder via a precise header-anchored re-search (not a
   substring match, which can false-positive on `In-Reply-To`/`References` quoting of the same
   Message-Id in unrelated threads).

## Gate Decision: Phase 4 Bulk-Delete Is UNSAFE As Planned

Per the plan's own Rollback/Contingency §Abort criteria: *"if Phase 3 verification cannot confirm
Labels redundancy, skip Phase 4 deletion (leave files inert) rather than risk data loss — the
config fix alone resolves the reconcile-blocking defects once Phases 5-6 complete."*

This is exactly that case, and more decisively so: redundancy is not merely unconfirmed, it is
**disconfirmed** for 98%+ of `.Labels.Important`/`.Labels.Letters` content. Phase 4's Task 1
("move any label-only Message-ID into a canonical folder before deleting the mirror") is not a
proportionate response at this scale — moving ~37,412 messages into `.Archive` (which currently
holds only 54 files) is a substantial re-categorization decision (which canonical folder each
message belongs in, how to avoid UID/filename collisions in the destination, whether the user
even wants 37k+ historical label-tagged messages folded into `.Archive`) that requires human
judgment beyond this plan's 1-hour Phase 4 budget and beyond a "cleanup of redundant mirrors"
mandate.

**Decision**: invoke the plan's documented fallback — leave ALL `.Labels.*` files in place,
inert (the channel is already out of `Group logos` per Phase 2, so they will never resync or
grow further). Zero data-loss risk. `.Labels.EuroTrip` (5 label-only of 8) and
`.Labels.CrazyTown` (5 label-only of 5) are small enough that they could plausibly be
hand-reviewed and moved in a future task, but are left untouched here for consistency and because
the plan did not budget separate handling per label.

## Recommendation for Follow-up (out of scope for this plan)

A new task should be spawned to decide, with human input, whether/how to fold the ~37,412
label-only messages in `.Labels.Important`/`.Labels.Letters` (and the 10 in `.Labels.EuroTrip`/
`.Labels.CrazyTown`) into a durable canonical location (e.g. a new `.Archive`-adjacent folder, or
left as-is since they are inert and harmless). This plan's mandate (resolve the mbsync
reconcile-blocking defects and stop further bloat) is fully achieved without touching them.
