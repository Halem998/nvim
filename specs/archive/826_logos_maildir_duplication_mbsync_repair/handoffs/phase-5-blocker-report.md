# Phase 5 Blocker Report: Duplicate-UID Pairs Are Distinct Messages, Not Redundant Copies

**Date**: 2026-07-06
**Method**: Direct filesystem enumeration + per-file `Message-Id:`/`Date:` header extraction over
all 862 duplicate-UID pairs (860 in `.Trash/cur`, 2 in `.Archive/cur`). Raw data under
`~/Mail/.logos-backup-20260706/phase5/`.

## Task 1 (enumeration) — completed

- `.Trash/cur`: 860 UIDs with exactly 2 physical files apiece (verified: zero anomalies, i.e. no
  UID has 1 or 3+ files — every "duplicate" is a clean pair). List:
  `~/Mail/.logos-backup-20260706/phase5/trash-dup-pairs.tsv`.
- `.Archive/cur`: 2 UIDs (`U=1`, `U=2`), each with exactly 2 files, matching the plan's estimate.

## Task 2 (choose which copy to keep) — BLOCKED, critical finding

The plan instructed choosing a copy to keep "by Message-Id and flags" and removing "the other
member of the pair," implicitly assuming each pair is two copies **of the same message**. Direct
verification of **all 862 pairs** (not a sample) shows this assumption is false:

- **All 860 `.Trash/cur` pairs have DIFFERENT `Message-Id` values between the two files.**
- **Both `.Archive/cur` pairs also have DIFFERENT `Message-Id` values.**

Spot-checked `Date:` headers confirm these are genuinely distinct, unrelated real messages, not
near-duplicates in a thread:
- `.Archive` `U=1`: one file dated `Mon, 09 Feb 2026`, the other dated `Tue, 18 Jan 2022` — nearly
  four years apart.
- `.Archive` `U=2`: `Mon, 09 Feb 2026` vs. `Sun, 09 Jan 2022`.
- `.Trash` `U=99` sample: `Fri, 15 Mar 2024` vs. `Wed, 22 Oct 2025`.

Filename analysis shows a consistent structural pattern for `.Trash`: one member of nearly every
pair (kept-file candidate "A") comes from the `1770669071.1006834_*`/`1770669072.1006834_*`
timestamp batch (2026-02-09 20:31-20:32 UTC, the original import), while the other member ("B")
spans a wide range of later local mtimes (2026-02 through 2026-03), i.e. these are real messages
that were independently moved into Trash at different times and happened to collide with an
already-used local UID number — consistent with the research report's diagnosis of a corrupted,
non-monotonic Near-side UID counter from a resumed 2026-02-09 import, **not** a content-duplication
event.

## Why This Blocks Phase 5 As Planned

The plan's Task 2 ("choose the copy to keep... remove the other") would, if executed literally,
**permanently destroy 862 distinct, irreplaceable real email messages** (860 from Trash + 2 from
Archive) that happen to have no other local copy. There is no redundant copy to discard in any of
these 862 pairs — both members are unique content. This is a data-loss risk far more severe than
Phase 3's finding, because Phase 3 at least had files that were mirrors of something (redundancy
existed for ~1.6% of the set); here, redundancy exists for **0% of the 862 pairs** (0/862 identical
Message-IDs).

Correctly resolving the underlying UID-collision (so mbsync's Near-side bookkeeping is
self-consistent and reconcile can proceed) without destroying either message requires one of:
1. **Live IMAP verification against the Bridge/Proton server** to determine, for each of the 862
   colliding UID slots, which local file (if either) matches the Far side's *current* UID
   assignment, then non-destructively rename (not delete) the non-matching file to a fresh,
   non-colliding UID marker so mbsync can re-associate it as a distinct message on the next
   reconcile. This is the only fully-safe path but requires 862 IMAP UID FETCH-and-compare
   round-trips — out of scope for this plan's Phase 5 budget (1.5 hours) and requires either a new
   script + human review, or explicit authorization to interact live with the Bridge/IMAP account
   beyond `mbsync`'s own group-scoped invocation.
2. **A blind rename-only fix** (strip/renumber the `U=NNN` token on one arbitrary member of each
   pair to break the filename collision, without server verification): this preserves both
   messages' content locally, but risks mbsync treating the renamed file as new local-only content
   on the next reconcile and pushing/re-uploading it to the server — which could create a **new**
   server-side duplicate, directly conflicting with this task's own Non-Goal ("no new bloat") and
   with the orchestrator's explicit prohibition on forcing through an uncertain destructive/
   state-changing step.

Neither option can be executed safely within this plan's current scope and verification
machinery. Per the orchestrator's explicit safety directive ("If a verification gate fails, STOP
and mark the phase [PARTIAL] with a blocker... rather than forcing through a destructive step"),
**no files under `.Trash/cur` or `.Archive/cur` were deleted, renamed, or otherwise modified**, and
**no `.mbsyncstate`/`.uidvalidity` files were cleared**. All 862 pairs (1724 files) remain exactly
as backed up in Phase 1.

## Recommendation for Follow-up (out of scope for this plan)

Spawn a new task to resolve the `.Trash`/`.Archive` duplicate-UID corruption via one of:
- A live, read-only IMAP UID/Message-Id reconciliation script against the Bridge account (safe,
  authoritative, but needs its own careful implementation and testing — 862 lookups).
- A human-reviewed manual pass over the (much smaller) `.Archive` case (2 pairs) first, since it
  is tractable by hand, before deciding whether to invest in automation for the 860 `.Trash` pairs.
- Accepting that `mbsync logos` group reconcile will continue to fail on Trash/Archive until this
  is resolved, while the config fix (Phase 2, already applied) and Sent-folder cleanup (Phase 6)
  still provide real value independent of this blocker.

This plan's Phase 7 (scoped `mbsync logos` reconcile) and Phase 8 (reindex + lift freeze) both
depend on Phase 5 and are therefore also not attempted in this implementation run — see the
top-level implementation summary for the overall phase status.
