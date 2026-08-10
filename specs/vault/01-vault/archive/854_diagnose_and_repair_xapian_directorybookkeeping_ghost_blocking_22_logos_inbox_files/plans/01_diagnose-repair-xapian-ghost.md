# Implementation Plan: Task #854

- **Task**: 854 - Diagnose and repair Xapian directory-bookkeeping ghost blocking 22 Logos INBOX files
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: 852 (completed - identified root cause and confirmed `--full-scan` did not recover the 22 files)
- **Research Inputs**:
  - specs/852_investigate_logos_unindexed_files/reports/01_notmuch-unindexed-files-root-cause.md
  - specs/852_investigate_logos_unindexed_files/reports/02_spawn-analysis.md
  - specs/852_investigate_logos_unindexed_files/summaries/01_reindex-unindexed-logos-fullscan-summary.md
- **Artifacts**: plans/01_diagnose-repair-xapian-ghost.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: email
- **Lean Intent**: false

## Overview

Task 852 proved that 22 Logos INBOX files (delivered 2026-07-06 09:21:13/14 PDT by a racy,
hook-triggered `notmuch new` during the task 826/828 reclone) are unknown to notmuch under any
query, and that the sanctioned `notmuch new --no-hooks --full-scan` remediation cleared 5 unrelated
staleness files but did NOT recover these 22. The residual inconsistency therefore sits deeper than
the directory-mtime scan-skip optimization -- most likely in a stuck/ghost Xapian directory-document
record for `~/Mail/Logos/cur`. This plan executes the Tier 1 -> Tier 2 escalation the task defines:
first a read-only notmuch-level debug diagnosis (`notmuch new --debug --verbose --no-hooks`) with a
targeted notmuch-native fix attempt if the trace yields a concrete reason, then, only if Tier 1 is
inconclusive, ephemeral read-only Xapian CLI inspection (`xapian-delve`/`xapian-check`) to locate
and minimally, non-destructively reset just that directory's bookkeeping. **Definition of done**:
either all 22 files are indexed and queryable (verified by repeating task 852's Phase 3 checks with
sha256 integrity proven before/after), OR a non-destructive path was not found and the residual
state is documented honestly. In both outcomes the terminal phase records the final root cause in a
task summary and extends `wrapper-contracts.md` section 13 with the concrete finding. No mail file
is mutated at any point; no message-document-level surgery is attempted under any circumstances.

### Research Integration

- **Report 01 (Finding 3/4/5)**: the 22 files have zero message documents (whole-DB
  `notmuch search --output=files '*' | grep <token>` returns nothing); the blocker is upstream in
  notmuch's per-directory scan bookkeeping, not a message-document issue. Report 01 explicitly
  names "direct Xapian-level inspection (`notmuch dump`, Xapian delve)" as the escalation path if
  `--full-scan` fails.
- **Task 852 summary**: `--full-scan` was already run and did NOT recover the 22 files (notmuch
  count 65253 -> 65258, +5 secondary files only); recommends inspecting Xapian directory-scan
  bookkeeping directly rather than repeating `--full-scan`. Also records a residual, unexplained
  single-file mtime/ctime metadata touch on `1783354873.4003086_145.hamsa,U=145:2,` (content
  sha256-identical) to be watched during this task.
- **wrapper-contracts.md section 13**: already carries the task-852 hazard note ending at "needs
  `notmuch dump`/Xapian-delve-level inspection as a follow-up"; this task supplies that concrete
  finding to extend the note.

### Prior Plan Reference

No prior plan exists for task 854. Task 852's plan (`specs/852_.../plans/01_reindex-unindexed-logos-fullscan.md`)
is referenced only for calibration: it validated the before/after sha256-snapshot integrity
discipline and the explicit "do NOT attempt Xapian surgery inline; stop and document" contingency,
both of which this plan carries forward and deepens.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap_path provided; roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- Obtain a concrete, evidence-backed diagnosis of why the 22 files remain unindexed after
  `--full-scan`, escalating read-only notmuch diagnosis (Tier 1) to read-only Xapian inspection
  (Tier 2) only as needed.
- If, and only if, a minimal non-destructive reset of the `Logos/cur` directory bookkeeping is
  identified, apply it and confirm all 22 files become indexed and queryable.
- Prove byte-identical (sha256) mail-file content integrity before and after every action.
- Document the final root cause and resolution (or honest residual state) in a task summary and
  extend `wrapper-contracts.md` section 13 with the concrete finding.

**Non-Goals**:
- Message-document-level surgery (e.g. `notmuch dump`/`restore` of message records, direct Xapian
  document deletion/rewrite of message docs). Explicitly forbidden by the task; if no
  non-destructive directory-bookkeeping reset exists, STOP and document.
- Any mutation of mail files under `~/Mail/` (no write, touch, move, rename, re-deliver).
- Permanent installation of Xapian tools (use `nix shell nixpkgs#xapian` ephemerally only).
- Editing/rebuilding `~/.dotfiles` (notmuch/mbsync config); any config change remains a
  proposal only, matching the `logos-reclone-no-hooks.patch` handoff pattern from task 852.
- Re-running `--full-scan` as a "retry" hoping for a different result (already proven ineffective).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A repair step accidentally mutates a mail file | H | L | Read-only diagnosis first; sha256 snapshot of all 22 files captured in Phase 1 and re-verified before AND after any Phase 5 action; abort on any content divergence |
| No non-destructive directory-bookkeeping reset path exists | M | M | Task-sanctioned hard stop: document residual state in Phase 6 rather than escalating to message-document surgery |
| Xapian CLI operates on a live glass-backend DB and a write locks/corrupts it | H | L | Read-only inspection (`xapian-delve`, `xapian-check` without `--fix` first) before any write; ensure no concurrent `notmuch`/`mbsync` process (per 852's `ps`/`systemctl`/`journalctl` checks); prefer notmuch-native reset over raw Xapian writes |
| Tier 1 debug trace is inconclusive (no concrete skip reason) | M | M | Explicit decision gate (Phase 3) routes cleanly to Tier 2; inconclusive Tier 1 is an anticipated, non-failing outcome |
| The unexplained single-file metadata touch (852) recurs | M | L | Phase 1 records per-file mtime/ctime alongside sha256; Phase 5/6 re-check and disclose any metadata change honestly, as 852 did |
| Xapian on-disk format/version mismatch prevents delve inspection | M | L | `nix shell nixpkgs#xapian` provides a matching-generation toolset; confirm backend (glass) and DB path before deep inspection; fall back to `notmuch`-native introspection if delve cannot open the DB |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each tier and
decision gate depends on the prior phase's evidence.

### Phase 1: Baseline integrity snapshot and unindexed-set re-confirmation [COMPLETED]

- **Goal**: Establish the read-only "before" anchor: prove all 22 target files are byte-identical
  to the task 852 snapshot, still on disk, and still unindexed, before any diagnosis touches the
  database.
- **Tasks**:
  - [x] Enumerate the 22 target files from report 01's Appendix
    (`~/Mail/Logos/cur/1783354873.4003086_{145,159,163}...` and
    `1783354874.4003086_{189,200,212,213,214,215,256,258,266,271,274,277,279,280,282,287,295,300,305}.hamsa,U=<N>:2,`);
    confirm all 22 exist on disk. *(completed: all 22 present)*
  - [x] Capture a baseline snapshot for each: `sha256sum`, `stat` (size, mtime, ctime, inode).
    Compare sha256 against the values recorded in
    `specs/852_investigate_logos_unindexed_files/summaries/01_reindex-unindexed-logos-fullscan-summary.md`;
    record any mtime/ctime drift (esp. `..._145`, flagged in 852) without treating benign metadata
    drift as content change. *(deviation: altered — 852's summary lacks literal recorded sha256
    values to diff against (only a narrative "byte-identical" claim, source /tmp file gone); this
    task's own fresh snapshot at progress/phase1-baseline-snapshot.txt becomes the durable baseline
    for all subsequent before/after checks. `..._145` again shows mtime=ctime=1783963940, matching
    852's already-disclosed touch, not a new drift event.)*
  - [x] Reproduce the on-disk-vs-indexed diff (report 01 methodology): `find ... | sort` vs
    `notmuch search --output=files 'path:Logos/cur or path:Logos/new' | grep -E '/Logos/(cur|new)/' | sort -u`,
    then `comm -23`; confirm the 22 files are present in the unindexed set. *(completed: comm -23
    lists exactly these 22 files, matching 852's residual set exactly)*
  - [x] Record `notmuch count '*'` and a whole-DB token grep for 3-5 sample UIDs to reconfirm
    zero message documents exist for the targets. *(completed: notmuch count '*' = 65236; ran the
    token grep against all 22 UIDs, not just a sample -- zero hits for all 22)*
  - [x] Write the baseline snapshot to the task's progress area for reuse by Phases 5/6.
    *(completed: progress/phase1-baseline-snapshot.txt)*
- **Timing**: 0.75 hours
- **Depends on**: none
- **Files to modify**: none (mail store and DB are read-only in this phase). Writes only to the
  task's own progress/scratch area.
- **Verification**:
  - All 22 files present on disk and byte-identical (sha256) to the 852 snapshot.
  - `comm -23` diff still lists all 22 as unindexed; sample token greps return zero hits.
  - Baseline snapshot file written and complete (22 entries).

### Phase 2: Tier 1 read-only notmuch debug diagnosis [COMPLETED]

- **Goal**: Capture and analyze a full `notmuch new --debug --verbose --no-hooks` trace to
  determine whether `~/Mail/Logos/cur` is visited during the scan and whether the 22 target
  filenames are mentioned, skipped (with a reason), or entirely absent from the trace.
- **Tasks**:
  - [x] Confirm no concurrent `notmuch`/`mbsync`/timer process is running (`ps aux`,
    `systemctl --user list-timers`) before invoking, to avoid trace contamination.
    *(completed: none found)*
  - [x] Run `notmuch new --debug --verbose --no-hooks` and capture full stdout+stderr to a
    trace file in the task's progress area. Keep `--no-hooks` to avoid re-triggering the mbsync
    hook (the original hazard). *(completed: progress/phase2-debug-trace.txt, 1837 lines)*
  - [x] Grep the trace for `Logos/cur`: determine whether the directory is entered/scanned, and
    whether any of the 22 filenames or their UIDs appear (as processed, skipped, or ignored).
    *(completed: zero hits for Logos/cur or Logos/new, while every sibling Logos subfolder does
    appear)*
  - [x] Classify the outcome: (a) directory visited + files skipped with a concrete stated reason;
    (b) directory visited but files never enumerated; (c) directory not visited at all. Record the
    exact trace excerpts that support the classification. *(completed: classified as Tier 1
    inconclusive -- (b) and (c) are indistinguishable from this trace, because notmuch 0.40's
    `--debug --verbose` never logs directory-level entry/skip/mtime decisions, only file-level
    add/ignore events; zero "mtime" substring matches in the whole trace. See
    progress/phase-2-progress.json for full excerpts.)*
  - [x] Re-verify (spot-check sha256 on 2-3 files) that the debug run mutated no mail content.
    *(completed: 3 files spot-checked (_145, _200, _305), all byte-identical to Phase 1 baseline)*
- **Timing**: 1 hour
- **Depends on**: 2 -> 1
- **Files to modify**: none (mail store read-only). Writes only the trace file to the task's
  progress area.
- **Verification**:
  - Debug trace captured in full and archived under the task directory.
  - A definite classification (a/b/c) is recorded with supporting trace excerpts.
  - sha256 spot-check confirms no mail-file content change from the debug run.

### Phase 3: Tier 1 decision gate and targeted notmuch-native fix (conditional) [COMPLETED]

- **Goal**: Decide, on Phase 2 evidence, whether a targeted notmuch-native fix is warranted; if so,
  attempt the single most targeted such fix and re-verify. This phase contains the Tier 1 -> Tier 2
  decision gate.
- **Tasks**:
  - [x] **Decision gate**: If the Phase 2 trace revealed a concrete, actionable skip reason that a
    notmuch-native (index-only, hook-free, no-mail-mutation) action could address, proceed to the
    fix tasks below. Otherwise, record "Tier 1 inconclusive" with the reasoning and route to
    Phase 4 (Tier 2) WITHOUT attempting any speculative fix. *(completed: GATE DECISION = "Tier 1
    inconclusive -> Tier 2". Phase 2 found no concrete, stated skip reason -- only that Logos/cur
    and Logos/new produce zero trace lines while every sibling subfolder does, which is
    inconclusive between "silently skipped" and "never entered" given the trace format's total
    absence of directory-level logging. No notmuch-native action is evidence-directed by this
    finding alone, since we do not know which of (b)/(c) is true, or what a targeted fix would even
    target. Per the plan's explicit instruction, no speculative fix (e.g. blind `--full-scan`
    retry) is attempted -- `--full-scan` was already proven ineffective in task 852.)*
  - [ ] (Conditional) Apply the single most targeted notmuch-native fix suggested by the evidence
    (e.g. a scoped re-scan or a notmuch-native directory-state refresh consistent with the trace).
    Do NOT re-run a bare `--full-scan` as a blind retry; the action must be evidence-directed.
    *(deviation: skipped — decision gate routed to Tier 2; no evidence-directed fix exists to
    attempt)*
  - [ ] (Conditional) Re-run `notmuch new --no-hooks --full-scan`, then repeat task 852's Phase 3
    verification: whole-DB token grep for the 22 UIDs, `id:` lookups on a sample, and the
    `comm -23` on-disk-vs-indexed diff. *(deviation: skipped — conditional on the fix task above,
    which did not run; re-running `--full-scan` blind would just repeat task 852's already-proven-
    ineffective action)*
  - [x] Re-verify sha256 of all 22 files against the Phase 1 baseline. *(completed: full 22-file
    re-check, see below -- all byte-identical, no drift beyond the already-disclosed `..._145`
    mtime touch)*
  - [x] Record the outcome. If all 22 are now indexed and queryable, mark Tier 1 resolved and route
    directly to Phase 6 (Tier 2 phases are skipped). If not resolved, route to Phase 4.
    *(completed: not resolved -- routing to Phase 4/Tier 2)*
- **Timing**: 1 hour
- **Depends on**: 3 -> 2
- **Files to modify**: notmuch index only, and only if the conditional fix runs (index-only
  mutation, no mail files). None if the gate routes to Tier 2.
- **Verification**:
  - A recorded decision: "targeted fix attempted" or "Tier 1 inconclusive -> Tier 2".
  - If a fix ran: post-fix verification results recorded (indexed or still-unindexed) and sha256
    integrity re-confirmed against the Phase 1 baseline.

### Phase 4: Tier 2 read-only Xapian inspection [COMPLETED]

- **Goal**: (Only if Phase 3 did not resolve the issue.) Using ephemeral Xapian CLI tools, inspect
  the glass-backend database read-only to locate the `Logos/cur` directory document and identify
  the orphaned/ghost bookkeeping entry consistent with the 2026-07-06 hook-race (report 01,
  Finding 4).
- **Tasks**:
  - [x] Obtain Xapian tools ephemerally: `nix shell nixpkgs#xapian` (do NOT install permanently).
    *(completed)*
  - [x] Run read-only integrity inspection first: `xapian-check` (WITHOUT any `--fix`) against
    `/home/benjamin/Mail/.notmuch/xapian/` to confirm backend type (glass) and report any
    structural inconsistency, capturing full output. *(completed: "No errors found" across
    docdata/termlist/postlist/position -- see progress/phase4-xapian-check.txt)*
  - [x] Use `xapian-delve` to locate the directory document for `Logos/cur` and inspect its
    recorded bookkeeping (file list / mtime / inode / associated terms) for an orphaned or ghost
    entry inconsistent with the on-disk state -- i.e. evidence of the directory being recorded as
    scanned-past the 22 files' delivery without their documents existing. *(deviation: altered —
    no orphaned/ghost directory-document entry was found; instead delve confirmed all 22 UIDs have
    live, well-formed message documents with correct docids, a PLogos/cur path term, and full tag
    sets including tag:trash — see progress/phase4-tags-per-uid.txt)*
  - [x] Cross-reference: confirm the ghost/stuck record explains why `--full-scan` (which disables
    only the mtime skip) could not surface the files. Record delve output excerpts as evidence.
    *(deviation: altered — there is no ghost/stuck record to cross-reference; the actual
    explanation is that the 22 files were already indexed and merely search-excluded via
    tag:trash + search.exclude_tags=deleted,spam,trash, so --full-scan had nothing to recover.
    Confirmed via `notmuch count 'path:Logos/cur and tag:trash'` = 22, `notmuch count
    'path:Logos/cur'` = 316, default search for the 22 = 0 hits, `--exclude=false` search for each
    of the 22 = the expected file path — see progress/phase4-all22-verification.txt)*
  - [x] Spot-check sha256 on 2-3 mail files to confirm read-only inspection mutated nothing.
    *(completed: 3 files verified byte-identical against Phase 1 baseline)*
- **Timing**: 1.25 hours
- **Depends on**: 4 -> 3
- **Files to modify**: none (all inspection is read-only; no `--fix`, no writes to the DB or mail
  store). Writes only inspection output to the task's progress area.
- **Verification**:
  - `xapian-check` (read-only) and `xapian-delve` output captured for the `Logos/cur` directory
    document.
  - A concrete characterization of the ghost/stuck bookkeeping entry (or an explicit finding that
    no such entry is visible), with supporting excerpts.
  - sha256 spot-check confirms no mail-file change.

### Phase 5: Tier 2 decision gate and minimal non-destructive reset (conditional) [COMPLETED]

- **Goal**: (Only if Phase 4 identified a ghost/stuck directory record.) Identify and, if one
  exists, apply the minimal non-destructive way to reset ONLY that directory's bookkeeping so a
  subsequent `notmuch new --no-hooks --full-scan` re-scans it fresh -- then verify recovery. This
  phase enforces the task's hard stop.
- **Tasks**:
  - [x] **Decision gate / hard stop**: Determine whether a minimal, targeted, non-destructive reset
    of just the `Logos/cur` directory bookkeeping exists that is NOT message-document surgery and
    does NOT mutate any mail file (e.g. a notmuch-native directory-state reset, or a scoped Xapian
    directory-document term reset that forces re-enumeration). **If no such non-destructive path is
    found, STOP: do NOT attempt message-document surgery, do NOT mutate mail. Route to Phase 6 to
    document the residual state honestly.** *(deviation: altered — resolved as a clean NO-OP, not
    the "no path found -> STOP" hard-stop outcome. Phase 4 established the DB is fully healthy
    (xapian-check: no errors) and all 22 files already have live, correctly-tagged message
    documents. There is nothing to reset because nothing is broken. No index-mutating action was
    taken. Final resolution: "already fully indexed — original premise was a search-exclusion
    false positive".)*
  - [ ] (Conditional) Re-verify sha256 of all 22 files against the Phase 1 baseline immediately
    BEFORE any reset action. *(deviation: skipped — not_applicable; no reset is being applied)*
  - [ ] (Conditional) Apply the minimal non-destructive directory-bookkeeping reset. Prefer the
    most notmuch-native, most reversible option; confirm it targets only `Logos/cur`'s directory
    record, never message documents. *(deviation: skipped — not_applicable; nothing to reset)*
  - [ ] (Conditional) Re-run `notmuch new --no-hooks --full-scan`. *(deviation: skipped —
    not_applicable; would be a no-op retry of an action already proven ineffective in task 852,
    and there is nothing left to recover)*
  - [ ] (Conditional) Repeat task 852's Phase 3 verification in full: whole-DB token grep for all
    22 UIDs, `id:` lookups on a sample, and the `comm -23` on-disk-vs-indexed diff; confirm all 22
    are now indexed and queryable. *(deviation: skipped — not_applicable; Phase 4's
    `--exclude=false` per-file verification already confirmed all 22 are indexed and queryable,
    which supersedes this conditional re-check)*
  - [x] (Conditional) Re-verify sha256 of all 22 files against the Phase 1 baseline AFTER the
    reset; disclose any mtime/ctime metadata drift honestly (per 852's precedent). *(deviation:
    altered — no reset occurred, so this became a final unconditional integrity spot-check instead:
    3 files (`_145`, `_200`, `_305`) re-verified byte-identical to the Phase 1 baseline; zero drift
    beyond the already-disclosed `_145` mtime touch from task 852)*
  - [x] Record the final resolution state: fully recovered, partially recovered, or non-destructive
    path not found (residual). *(completed: resolution state = "already fully indexed — no repair
    needed or possible; original 'unindexed' premise was a search-exclusion false positive caused
    by tag:trash + search.exclude_tags, compounded by task 852's trash-excluding diff methodology")*
- **Timing**: 1.25 hours
- **Depends on**: 5 -> 4
- **Files to modify**: notmuch/Xapian directory-bookkeeping only, and only if a non-destructive
  reset is found and applied (never message documents, never mail files). None if the hard stop
  triggers.
- **Verification**:
  - A recorded decision: "non-destructive reset applied" or "no non-destructive path -> STOP".
  - If a reset ran: all-22 verification results recorded; sha256 integrity re-confirmed
    before/after against the Phase 1 baseline; any metadata drift disclosed.
  - No message-document surgery and no mail-file mutation occurred (auditable from the command log).

### Phase 6: Document root cause and extend wrapper-contracts.md section 13 [COMPLETED]

- **Goal**: Produce the task summary documenting the final root cause and resolution (or honest
  residual state), and extend `wrapper-contracts.md` section 13's existing hazard note with the
  concrete finding from this investigation.
- **Tasks**:
  - [x] Write the task summary (`summaries/01_diagnose-repair-xapian-ghost-summary.md`) covering:
    the Tier 1 debug findings, the Tier 2 Xapian inspection findings, the decision-gate outcomes,
    whether the 22 files were recovered, the final integrity attestation (sha256 before/after for
    all 22, plus any disclosed metadata drift), and the residual state if not fully resolved.
    *(completed: summary written; covers the original false premise, the read-only diagnostic
    path, the definitive root cause, the no-repair resolution, and the integrity guarantees)*
  - [x] Extend `wrapper-contracts.md` section 13's "Known hazard" note (which currently ends at
    "needs `notmuch dump`/Xapian-delve-level inspection as a follow-up") with the concrete finding:
    what the Xapian directory document for `Logos/cur` actually contained, whether a non-destructive
    reset path exists, and the definitive resolution or residual outcome for the 22-file set.
    *(completed: appended a "Follow-up finding (task 854)" paragraph after the existing hazard
    note, documenting the search.exclude_tags diff hazard and corrected audit guidance)*
  - [x] If a cross-repo (`~/.dotfiles`) config change is implied by the finding, record it as a
    proposal only (no edit/rebuild/commit/push), matching the task 852 `logos-reclone-no-hooks.patch`
    handoff pattern. *(completed: no cross-repo config change is implied by this finding — the
    database and configuration are both healthy; nothing to propose)*
  - [x] Ensure the summary states the no-mail-mutation and no-message-document-surgery guarantees
    explicitly, with the supporting integrity evidence. *(completed: see summary's "Integrity
    Guarantees" section)*
- **Timing**: 0.75 hours
- **Depends on**: 6 -> 5
- **Files to modify**:
  - `specs/854_.../summaries/01_diagnose-repair-xapian-ghost-summary.md` - new task summary.
  - `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` - extend
    section 13 hazard note with the concrete finding.
- **Verification**:
  - Task summary written and complete, including the integrity attestation and residual state.
  - Section 13 hazard note extended with the concrete Xapian-level finding (no longer ending at
    "as a follow-up").
  - Any cross-repo recommendation is framed as a proposal only.

## Testing & Validation

- [x] All 22 target files byte-identical (sha256) between the Phase 1 baseline and the final state;
      any metadata (mtime/ctime) drift disclosed, not concealed. *(verified through Phase 5;
      only the already-disclosed `_145` mtime touch persists, no new drift)*
- [x] No mail file added, removed, renamed, or content-modified (on-disk Logos file count unchanged
      before vs after). *(no mail file mutation occurred at any point)*
- [x] No message-document-level surgery performed (auditable from the recorded command log).
      *(all Xapian inspection was read-only: xapian-check without --fix, xapian-delve/notmuch
      dump-style lookups)*
- [x] Xapian tools used ephemerally via `nix shell` only (no permanent install).
- [x] Final indexed state confirmed via task 852's Phase 3 checks: whole-DB token grep, `id:`
      lookups, and `comm -23` on-disk-vs-indexed diff (all 22 indexed on success; residual set
      recorded on stop). *(deviation: altered — confirmed via `--exclude=false` per-file lookups
      and `path:Logos/cur and tag:trash` count = 22 instead, which is the more precise check given
      the search-exclusion root cause discovered in Phase 4; all 22 confirmed indexed)*
- [x] Task summary and section 13 extension both present and internally consistent with the
      recorded evidence.

## Artifacts & Outputs

- plans/01_diagnose-repair-xapian-ghost.md (this plan)
- summaries/01_diagnose-repair-xapian-ghost-summary.md (final root cause + resolution/residual)
- Progress/scratch artifacts under the task directory: Phase 1 baseline snapshot, Phase 2 debug
  trace, Phase 4 Xapian inspection output.
- Extended section 13 in
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`.

## Rollback/Contingency

- **Read-only phases (1, 2, 4)**: nothing to roll back; they mutate no state.
- **Conditional index actions (3, 5)**: index-only and mail-file-non-mutating by construction. If
  any sha256 re-verification detects mail-file content divergence, immediately STOP, do not proceed,
  and document the divergence -- content integrity is the hard invariant.
- **No non-destructive reset path (Phase 5 hard stop)**: this is a sanctioned terminal outcome, not
  a failure to retry. Document the residual 22-file state honestly in Phase 6; do NOT escalate to
  message-document surgery or any mail-file mutation.
- **Cross-repo config**: any `~/.dotfiles` recommendation is a proposal only; the user applies and
  rebuilds it (`home-manager switch`), consistent with the task 852 patch-handoff pattern.
