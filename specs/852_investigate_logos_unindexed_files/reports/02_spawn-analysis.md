# Blocker Analysis: Task #852

**Parent Task**: #852 - Investigate 22 Logos INBOX files that notmuch never indexes
**Generated**: 2026-07-13
**Blocker**: The sanctioned, index-only remediation `notmuch new --no-hooks --full-scan` ran cleanly but did not index the 22 anomaly Logos INBOX files (it only cleared 5 unrelated staleness files). `--full-scan` disables notmuch's directory-mtime scan-skip optimization, but the 22 files' failure to appear even under an exhaustive whole-database search indicates a deeper bookkeeping inconsistency — most likely in the Xapian "directory document" records notmuch maintains internally — that `--full-scan` alone does not reset.

## Root Cause

Task 852's research (report `01_notmuch-unindexed-files-root-cause.md`) established with direct log
evidence that the 22 files were delivered on 2026-07-06 as a side effect of `logos-reclone.sh`
invoking a raw (non-`--no-hooks`) `notmuch new`, whose own `pre-new` hook (`mbsync gmail logos`)
delivered the files mid-scan and then failed. The implementation pass (plan
`01_reindex-unindexed-logos-fullscan.md`, summary
`01_reindex-unindexed-logos-fullscan-summary.md`) then executed the one remaining untested,
lowest-risk remediation — `notmuch new --no-hooks --full-scan` — exactly as Phase 2/3 specified.
The command exited 0, correctly avoided triggering any hook, and did increase `notmuch count '*'`
by 5 (clearing the unrelated secondary staleness files), proving the command ran and can add
messages. However, Phase 3 verification (all 22 token/`id:` lookups, `comm -23` diff) showed **zero**
of the 22 anomaly files were recovered.

This narrows the root cause: `--full-scan`'s documented behavior is to disable the *directory
mtime*-based scan-skip optimization only (`notmuch-new(1)`). Because it still had no effect, the
blocking state is not "notmuch thinks this directory's mtime is already current" — it is a deeper,
per-file or per-directory "already seen"/"already processed" record that mtime-based (or
mtime-bypassing) heuristics do not touch. The most likely location for this kind of durable,
internal, non-`notmuch search`-exposed bookkeeping is the Xapian **directory document** that
notmuch maintains per-maildir-directory (recording, among other things, the set of filenames/inode
identifiers notmuch believes it has already accounted for in that directory) — plausibly left in
an inconsistent state by the racy/aborted hook-triggered scan on 2026-07-06 (the `pre-new` hook
failed mid-run per the preserved `reclone-live.log`). This is consistent with every finding in
report `01_notmuch-unindexed-files-root-cause.md`, including the ruled-out alternatives
(`new.ignore`, permissions, malformed filenames, non-mail content, global DB corruption) and the
confirmed absence of any message document for these files (Finding 3).

No tool currently installed can inspect this directory-document state directly: notmuch's own CLI
surface (`notmuch new`, `notmuch search`, `notmuch count`, `notmuch dump`/`restore`) only exposes
message-document-level data, not the internal per-directory scan bookkeeping. Verified live this
session: Xapian CLI introspection tools (`xapian-delve`, `xapian-check`, `xapian-inspect`) are not
installed but are available ephemerally via `nix shell nixpkgs#xapian` — the standard next-level
tool for inspecting a glass-backend Xapian database's internal documents/postlists directly,
without installing anything permanently. `notmuch reindex` is confirmed inapplicable, since it only
re-processes messages already present in the index, and these 22 have no message document to
reindex.

## Proposed New Tasks

### New Task 1: Diagnose and repair the Xapian directory-bookkeeping ghost blocking the 22 Logos INBOX files
- **Effort**: 2-4 hours
- **Task Type**: email (topic: extensions)
- **Rationale**: This is the single remaining lever to close task 852's blocker. It is scoped as
  one task rather than split into a separate "diagnose" task and "fix" task because the fix's
  exact shape (which directory document to touch, which record to clear, whether a
  `notmuch new --no-hooks --full-scan` re-run after the reset is sufficient, or whether a lower-
  level surgical edit is required) can only be determined from the diagnostic output itself — an
  implementer must interpret Tier 1/Tier 2 findings in real time to choose the correct
  minimal-risk remediation, which is a single continuous debugging arc rather than two
  independently plannable units of work.
- **Description** (full, implementer-actionable):

  Root cause (from `specs/852_investigate_logos_unindexed_files/reports/01_notmuch-unindexed-files-root-cause.md`
  and `02_spawn-analysis.md`): 22 Logos INBOX files at `~/Mail/Logos/cur/178335487{3,4}.4003086_<N>.hamsa,U=<N>:2,`
  (full list in report 01's Appendix) were delivered by a racy, hook-triggered `notmuch new` during
  the task 826/828 Logos reclone and have never been indexed. `notmuch new --no-hooks --full-scan`
  (task 852's remediation attempt) did not recover them, ruling out a simple directory-mtime
  scan-skip cause. The suspected cause is a stuck/inconsistent Xapian directory-document record for
  `~/Mail/Logos/cur` that predates and survives both mtime-forcing and `--full-scan`.

  **Tier 1 (read-only, notmuch-only, do first)**:
  - Run `notmuch new --debug --verbose` (read-only relative to mail; this does perform a real scan/
    index pass, so confirm ahead of time it will not re-trigger any hook — use `--no-hooks` alongside
    `--debug --verbose` to keep it safe) and capture full output. Look specifically for whether
    `~/Mail/Logos/cur` is visited at all in the debug trace, and whether the 22 target filenames
    are mentioned, skipped, or silently absent from the scan's file enumeration.
  - Cross-check the 22 files' current maildir placement (`cur/` vs `new/`) and flags — confirm none
    have drifted or been touched since the last snapshot in
    `specs/852_investigate_logos_unindexed_files/summaries/01_..._summary.md` (which recorded one
    file's mtime/ctime anomaly; re-verify sha256 content is still byte-identical before any further
    action).
  - If the debug trace reveals a concrete, actionable skip reason (e.g., an explicit "already
    know about this file" log line naming an internal record), attempt the most targeted,
    least-destructive notmuch-native fix suggested by that evidence (e.g., a config-level reset
    scoped to that directory, if notmuch exposes one) before moving to Tier 2.

  **Tier 2 (only if Tier 1 is inconclusive)**:
  - Obtain Xapian CLI tools ephemerally: `nix shell nixpkgs#xapian` (do not install permanently).
  - Use `xapian-delve` and/or `xapian-check` (read-only inspection first) against the glass-backend
    database at `/home/benjamin/Mail/.notmuch/xapian/` to locate the directory document for
    `Logos/cur` and inspect its recorded file list/mtime/inode bookkeeping for an orphaned or
    "ghost" entry consistent with the 2026-07-06 hook-race (per report 01, Finding 4).
  - Identify the minimal, targeted, non-destructive way to reset just that directory's
    bookkeeping so a subsequent `notmuch new --no-hooks --full-scan` will re-scan it fresh. This
    must NOT be message-document surgery and must NOT mutate any mail file — the goal is to make
    notmuch "forget" that it already looked at this one directory, not to hand-construct message
    records or alter maildir content.
  - After the targeted reset, re-run `notmuch new --no-hooks --full-scan` and verify (repeating
    task 852's Phase 3 verification: whole-DB token grep, `id:` lookups, `comm -23` diff) that all
    22 files are now indexed and queryable.

  **Constraints** (carry through the whole task):
  - Read-only diagnosis first; do not mutate any mail file at any point. Re-verify byte-identical
    content (sha256) for all 22 target files both before and after any Tier 2 action.
  - notmuch/mbsync configuration lives in `~/.dotfiles` — do not run `home-manager switch`, do not
    commit or push there. Any config-level recommendation for `~/.dotfiles` is a proposal only
    (matching task 852's existing `logos-reclone-no-hooks.patch` handoff pattern).
  - If Tier 2 also fails to close the gap, or if no non-destructive reset path is found, stop and
    document the residual state honestly (do not attempt message-document-level surgery) —
    escalate to the user with the diagnostic findings rather than taking a destructive action.
  - Document the final root cause (the specific Xapian bookkeeping mechanism, once identified) and
    the resolution steps in a task summary, and update
    `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` §13 with the
    concrete finding (extending task 852's existing hazard note) so this failure mode is fully
    documented for future recurrence.

- **Depends on**: None

## Dependency Reasoning

This blocker resolves with a single new task; there is no multi-task dependency graph to reason
about. The two-tier structure (notmuch-native debug trace first, Xapian CLI inspection second) is
expressed as sequential phases *within* this one task (to be elaborated by `/plan`), not as
separate spawned tasks, because:

- The exact Tier 2 action (which Xapian tool invocation, which record to target) cannot be
  specified in advance — it depends entirely on what Tier 1's debug trace reveals. Splitting this
  into "Task A: run debug trace" and "Task B: fix using Xapian tools" would force a task boundary
  and re-context-load exactly at the point where the most implementation-relevant information
  (the debug trace's specific skip reason) needs to inform the very next action. This is the kind
  of continuous, information-dependent debugging arc the Task Minimization Principle's
  "Sequentiality" criterion favors keeping unified rather than split.
- There is no independent, parallelizable piece of work here: Tier 1 must run before Tier 2 can be
  scoped, and the fix must run after diagnosis. A single implementer session with an internal
  phased plan (produced at `/plan` time) captures this correctly without introducing an artificial
  task dependency edge in `state.json`.

## After Completion

Once the spawned task is complete, resume the parent task #852 with `/implement 852`.

The blocker will be resolved because: the new task's Tier 1/Tier 2 diagnostic sequence targets the
one remaining candidate mechanism (Xapian directory-document bookkeeping) that `--full-scan`
provably did not reach, and its non-destructive reset-and-reverify loop directly produces the
missing outcome task 852 was blocked on — all 22 files indexed and queryable, with mail-file
content integrity preserved throughout.
