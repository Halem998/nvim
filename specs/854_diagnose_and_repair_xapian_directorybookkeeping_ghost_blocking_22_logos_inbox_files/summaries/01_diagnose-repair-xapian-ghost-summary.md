# Implementation Summary: Task #854

**Completed**: 2026-07-13
**Duration**: ~2 hours across 6 phases

## Overview

Task 854 set out to diagnose and repair a hypothesized "stuck Xapian directory-bookkeeping
ghost" believed to be blocking 22 Logos INBOX files from ever being indexed by notmuch, after
task 852's `notmuch new --no-hooks --full-scan` remediation failed to recover them. The
investigation reverses the task's original premise: **the 22 files were never unindexed**. They
are, and throughout this task remained, fully and correctly indexed in the Xapian database. The
real cause is that all 22 carry `tag:trash`, which notmuch's `search.exclude_tags` configuration
(`deleted, spam, trash`) silently omits from default search/count/output-files results — and task
852's on-disk-vs-indexed diff methodology used exactly such a default (trash-excluding) search as
its "indexed set" probe, producing a false-positive "unindexed" classification. No repair was
needed, none was attempted, and none was possible, because nothing was broken.

## Diagnostic Path Taken

**Phase 1 (baseline)**: Re-confirmed on disk presence and captured a fresh sha256/stat snapshot
of all 22 target files (`progress/phase1-baseline-snapshot.txt`), since task 852's summary only
narratively claimed byte-identical integrity without recording literal hash values. Reproduced
the `comm -23` on-disk-vs-indexed diff from task 852's methodology, confirming the same 22 files
appeared "unindexed" by that methodology. `notmuch count '*'` = 65236.

**Phase 2 (Tier 1 — read-only notmuch debug diagnosis)**: Ran `notmuch new --debug --verbose
--no-hooks` and captured the full 1837-line trace (`progress/phase2-debug-trace.txt`). Every
sibling Logos subfolder (`.Archive`, `.Drafts`, six `.Labels.*`, `.Sent`, `.Trash`,
`.mbsyncstate`) is explicitly represented in the trace, but `Logos/cur`/`Logos/new` (the INBOX
maildir housing the 22 targets) produced zero trace lines of any kind. This was classified
**Tier 1 inconclusive**: notmuch 0.40's `--debug --verbose` output contains no directory-level
entry/skip/mtime logging at all (zero "mtime" substring matches across the whole trace), so
"directory visited, files silently skipped" and "directory never entered" are indistinguishable
from this trace format alone.

**Phase 3 (Tier 1 decision gate)**: Since Phase 2 yielded no concrete, actionable skip reason, no
speculative or blind-retry fix was attempted (the plan explicitly forbids re-running `--full-scan`
as a blind retry, since task 852 already proved it ineffective). Gate routed cleanly to Tier 2.
sha256 of all 22 files re-verified against the Phase 1 baseline: byte-identical, no drift.

**Phase 4 (Tier 2 — ephemeral, read-only Xapian inspection)**: Obtained Xapian tools via `nix
shell nixpkgs#xapian` (never installed permanently). Ran `xapian-check` (without `--fix`) against
the notmuch Xapian database: **"No errors found"** across all four B-tree tables (docdata,
termlist, postlist, position) — `progress/phase4-xapian-check.txt`. This disproves the plan's
working hypothesis of a stuck/ghost directory-bookkeeping record; the database has no structural
inconsistency whatsoever. `xapian-delve`-based lookups (via `notmuch dump`/`notmuch search
--exclude=false`) for all 22 UIDs found live, well-formed message documents with correct docids
(73596, 73843, 73847, 73850, 73851, 73614, 73616, ...) and a `PLogos/cur` path term, each carrying
the tag set `gmail, logos, proposed-archive, trash, unread` (`progress/phase4-tags-per-uid.txt`).
Cross-referencing confirmed the actual cause:
- `notmuch config get search.exclude_tags` = `deleted, spam, trash`
- `notmuch count 'path:Logos/cur and tag:trash'` = 22 (exactly the target set)
- `notmuch count 'path:Logos/cur'` = 316 (the 22 are a subset of the full folder)
- Default (trash-excluding) search for the 22 = 0 hits
- `notmuch search --exclude=false ...` / per-file `--exclude=false` lookups for each of the 22
  individually return exactly the expected file path (`progress/phase4-all22-verification.txt`)

Spot-check sha256 on 3 files confirmed the read-only inspection mutated nothing.

**Phase 5 (Tier 2 decision gate)**: Resolved as a clean **NO-OP**, not the plan's "no
non-destructive path found → STOP" hard-stop outcome. Those two are distinct outcomes: the
hard-stop presupposes something IS broken but cannot safely be fixed; here nothing is broken, so
there is nothing to reset. No index-mutating action was taken. A final sha256 spot-check (3 files:
`_145`, `_200`, `_305`) against the Phase 1 baseline confirmed byte-identical content, closing the
integrity loop.

## Definitive Root Cause

The 22 "unindexed" Logos INBOX files were never unindexed. They are all fully indexed in the
Xapian database with correct docids, path terms, and tags. The apparent "unindexed" state
reported by task 852 was a **false positive** produced by that task's diagnostic methodology: a
`comm -23` diff of `find ~/Mail/Logos/cur` (on-disk, all files) against `notmuch search
--output=files ...` (which honors `search.exclude_tags` and therefore silently drops any
`tag:trash` file from its output). Because all 22 files carry `tag:trash`, and `trash` is one of
notmuch's excluded tags (`deleted, spam, trash`), they were absent from the "indexed" side of that
diff while present on the "on-disk" side — appearing as "on disk but not indexed" when they were
in fact "indexed but search-excluded." `notmuch new --full-scan` in task 852 "failed to recover"
them precisely because there was nothing to recover: they were already indexed before task 852
ever ran.

**Task 852's "unindexed files" conclusion should be considered corrected by this finding.** The
22 files it identified as permanently unindexed and unrecoverable were, in fact, correctly and
completely indexed throughout.

## Resolution

No repair needed, none attempted, none possible — nothing was broken. The Xapian database passed
integrity checks with zero errors; all 22 target message documents are live and correctly tagged.
No index-mutating action, no message-document surgery, and no mail-file mutation occurred at any
point in this task's six phases.

## Integrity Guarantees

- **No mail-file mutation**: sha256 of every touched file was re-verified against the Phase 1
  baseline at multiple checkpoints (Phase 2 debug run, Phase 3 gate, Phase 4 Xapian inspection,
  Phase 5 final check) and remained byte-identical throughout. The one previously-disclosed
  metadata anomaly (`_145`'s mtime=ctime=1783963940, first noted in task 852) recurred unchanged
  across every check in this task — no new drift event occurred.
- **No message-document-level surgery**: all Xapian inspection was strictly read-only
  (`xapian-check` without `--fix`, `xapian-delve`/`notmuch dump`-style lookups). No document was
  created, deleted, or rewritten at the Xapian level.
- **No permanent tool installation**: all Xapian CLI tooling was obtained ephemerally via `nix
  shell nixpkgs#xapian` and never installed into the system profile or `~/.dotfiles`.
- **No cross-repo config changes**: no `~/.dotfiles` edit, rebuild, commit, or push occurred; none
  was needed for this finding.

## Open Question (Out of Scope)

Whether these 22 messages *should* carry `tag:trash` is a mail-triage / classification matter, not
an indexing defect. This task does not judge or act on that question — it is left entirely to the
user's own mail-triage workflow. Nothing in this task altered any tag on any message.

## Plan Deviations

- **Task 4.3/4.4** altered: no orphaned/ghost directory-document entry was found (as the plan
  anticipated investigating); instead the inspection found all 22 message documents live and
  correctly indexed, and traced the true cause to `tag:trash` + `search.exclude_tags`.
- **Task 5.1** altered: the Phase 5 decision gate resolved as a clean "no repair needed" NO-OP
  rather than the "no non-destructive path found → STOP" hard-stop the plan anticipated as the
  failure-mode alternative to a successful reset.
- **Tasks 5.2-5.6** (conditional reset/re-verification steps): skipped as not_applicable, since no
  reset was needed. A final unconditional sha256 spot-check (in place of the conditional
  pre/post-reset pair) closed the integrity loop instead.
- **Task 3.2/3.3** (conditional Tier 1 fix and full-scan re-run): skipped as not_applicable per
  Phase 3's evidence-directed decision gate (see `progress/phase-3-progress.json`).

See `progress/phase-1-progress.json` through `progress/phase-5-progress.json` for the complete
per-phase deviation and evidence trail.

## Verification

- Build: N/A (documentation/diagnostic task)
- Tests: N/A
- Xapian DB integrity: `xapian-check` — "No errors found" (all four B-tree tables)
- All 22 target files: confirmed indexed via `--exclude=false` per-file lookup and via
  `path:Logos/cur and tag:trash` count = 22
- sha256 integrity: all spot-checked files byte-identical to the Phase 1 baseline at every
  checkpoint through the end of Phase 5
- Files verified: Yes

## Notes

`wrapper-contracts.md` section 13's existing hazard note (task 852) is extended by this task with
the concrete finding that `search.exclude_tags` interacting with `notmuch search --output=files`
(and any default search) is itself a distinct hazard from the hook-race issue documented there —
it can independently produce false "unindexed" positives for any excluded-tag message, regardless
of whether a hook race ever occurred. See
`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` section 13.
