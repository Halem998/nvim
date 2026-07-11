# Blocker Analysis: Task #826

**Parent Task**: #826 - Fix Logos (ProtonMail Bridge) maildir duplication and mbsync reconcile failures
**Generated**: 2026-07-05
**Blocker**: Phase 5 (Trash/Archive UID dedup) cannot proceed because all 862 duplicate-UID pairs contain two messages with *different* Message-Ids — i.e. distinct, irreplaceable real mail, not redundant copies. No automated Message-ID-based "keep one, delete the other" resolution is safe. This blocks Phase 7 (`mbsync logos` reconcile) and Phase 8 (reindex + lift `email-freeze`).

## Root Cause

**Category**: Technical unknowns / missing prerequisite (live external verification required before a destructive local operation can proceed safely).

The plan (`specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md`,
Phase 5) assumed the 862 duplicate-`U=NNN` pairs in `~/Mail/Logos/.Trash/cur` (860) and
`~/Mail/Logos/.Archive/cur` (2) were two copies of the *same* message, colliding on a stale local
UID slot from the 2026-02-09 import corruption — in which case "choose the copy to keep by
Message-Id and flags, remove the other" would be safe (the discarded copy is fully redundant).

Phase 3 verification (`handoffs/phase-3-verification-report.md`) already demonstrated the
project's Labels-mirror redundancy assumption was wrong for a similar reason (98.4%/99.8% of
`.Labels.Important`/`.Labels.Letters` content has no copy elsewhere), so the implementer applied
the same rigor to Phase 5 rather than trusting the plan's assumption at face value.

The Phase 5 blocker report (`handoffs/phase-5-blocker-report.md`) did the same direct verification
for Phase 5's dedup assumption and found it categorically false: **all 862 pairs (100%, not a
sample) have DIFFERENT `Message-Id` values between the two colliding files.** Spot-checked `Date:`
headers confirm these are unrelated real messages sometimes years apart (e.g. `.Archive` `U=1`:
`Mon, 09 Feb 2026` vs. `Tue, 18 Jan 2022`). Filename-timestamp analysis shows a structural pattern
consistent with the diagnosed root cause: one member of each pair is from the original
2026-02-09 20:31-20:32 UTC import batch; the other was independently moved into Trash later and
happened to collide with an already-used local UID number, because the Near-side UID counter is
non-monotonic/corrupted.

Consequently, "remove the other member of the pair" as the plan literally instructs would
permanently destroy 862 distinct, irreplaceable real messages. The implementer correctly stopped
per the orchestrator's explicit safety directive rather than force through a destructive step, and
left all 1,724 files and both folders' `.mbsyncstate`/`.uidvalidity` completely untouched (see
Phase 1 backup, still fully valid: `~/Mail/.logos-backup-20260706/`).

The blocker report identifies exactly two theoretically viable resolution paths, of which only one
is safe:
1. **Live IMAP verification against the ProtonMail Bridge server** (862 UID FETCH-and-compare
   round-trips) to determine, per colliding UID slot, which local file (if either) matches the
   Far side's *current* UID assignment, then a **rename-only** (never delete) operation to move
   the non-matching file to a fresh, non-colliding `U=NNN` token so mbsync can re-associate it as
   a distinct message on the next reconcile. This is the only fully safe path, but was out of the
   original plan's Phase 5 scope/budget (1.5 hours) and requires its own script and testing.
2. **A blind rename-only fix** with no server verification: preserves both messages locally but
   risks mbsync treating the renamed file as new local-only content and pushing it to the server
   as a duplicate on the next reconcile — directly violating the task's own "no new bloat"
   non-goal. Rejected as unsafe by the blocker report.

Task 826's own scope, timing, and delegation context deliberately excluded live IMAP interaction
beyond `mbsync`'s own group-scoped invocation, which is why this became a genuine blocker rather
than something the implementer could resolve in-place.

## Proposed New Tasks

### New Task 1: Resolve Logos Trash/Archive UID collisions via live IMAP verification
- **Effort**: 3-4 hours
- **Task Type**: nix
- **Rationale**: This is the single missing prerequisite for task 826 to resume Phases 7-8. It
  supplies the live-IMAP-verified, rename-only repair that path 1 of the blocker report identifies
  as the only safe resolution, scoped narrowly to just the UID-collision repair (not the
  reconcile/reindex/thaw steps, which remain task 826's responsibility to resume afterward).
- **Depends on**: None

## Dependency Reasoning

Only one task is proposed, so there is no internal dependency graph to reason about. This
reflects the Task Minimization Principle: the blocker has exactly one root cause (an unverified
UID collision requiring live server truth), and the two candidate resolution paths in the blocker
report collapse to a single safe technique (live IMAP verify + rename-only repair) applied first
to the 2 tractable `.Archive` pairs (as an inline validation of the technique before scaling) and
then to the 860 `.Trash` pairs using the same script and rollback machinery. Splitting "build the
verification script" from "run it against all 862 pairs" would not satisfy the Sequentiality
criterion for a *separate* task, because the implementation choices in building the script
(dry-run format, rename-token scheme, decision log format) are exactly what an implementer needs
to decide *while* running it against the small Archive set first — there is no clean handoff point
where a second implementer would need to make different, independent choices. Both belong in one
task.

## After Completion

Once the spawned task is complete, resume the parent task #826 with `/implement 826`.

The blocker will be resolved because: with every colliding local UID either confirmed to already
match the Bridge server's authoritative assignment, or renamed (never deleted) to a fresh
non-colliding UID slot, `~/Mail/Logos/.Trash/cur` and `~/Mail/Logos/.Archive/cur` will each map one
physical file per UID — satisfying the plan's own Phase 5 verification criterion (`ls .Trash/cur |
grep -oE 'U=[0-9]+' | sort | uniq -d` returns nothing). Task 826 can then proceed to Phase 7
(`mbsync logos` scoped reconcile) without hitting the "duplicate UID" failure, and Phase 8
(reindex + lift `email-freeze`) becomes reachable.
