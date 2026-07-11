# Implementation Plan: Task #828

- **Task**: 828 - Resolve Logos Trash/Archive UID collisions via live IMAP verification
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None (parent task 826 resumes after this completes)
- **Research Inputs**:
  - specs/828_logos_trash_archive_uid_collision_repair/reports/01_spawn-analysis-from-826.md
  - specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md (resolution path 1)
  - specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md (Phase 5)
- **Artifacts**: plans/01_logos-uid-collision-repair.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Resolve the 862 duplicate-`U=NNN` Maildir collisions (860 in `~/Mail/Logos/.Trash/cur`, 2 in
`~/Mail/Logos/.Archive/cur`) left unresolved by task 826's Phase 5. Task 826 established, over all
862 pairs, that the two colliding files always carry DIFFERENT `Message-Id` values — they are
distinct, irreplaceable real messages that happened to collide on the same local `U=NNN` slot due
to a corrupted, non-monotonic Near-side UID counter from the 2026-02-09 import. Because no member
is a redundant copy, no `Message-Id`-based delete is safe. The only safe technique (blocker report
resolution path 1) is a **live, read-only IMAP verification** against the ProtonMail Bridge server:
for each colliding UID slot, fetch the Message-Id the Bridge currently maps to that server UID,
compare it to both local candidates, and where one member matches, **rename the OTHER member off
the colliding token** to a fresh, non-colliding `U=NNN` — never deleting either file and never
writing anything to the server. The work is sequenced conservatively: verify the existing Phase 1
backup and freeze, establish a strictly read-only IMAP channel, build a dry-run-first rename-only
script, validate it end-to-end on the 2 tractable `.Archive` pairs, then apply the same script to
the 860 `.Trash` pairs, logging every decision to the Phase 1 backup directory. Definition of done:
`ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the `.Archive/cur`
equivalent both return nothing, zero files deleted, zero server-side writes performed by this
task's script, and a decision log documenting every rename.

### Research Integration

Key findings carried forward from the spawn analysis and the task 826 blocker report/plan:
- **All 862 pairs have DIFFERENT Message-Ids (100%, not a sample)** — deletion is off the table;
  rename-only is the only non-destructive resolution (blocker report Task 2, resolution path 1).
- **Root cause is a corrupted, non-monotonic Near-side UID counter** from a resumed 2026-02-09
  import, not a content-duplication event. This is exactly why the local `U=NNN` token may not
  correspond to the server's current UID for that message, and why live server truth is required.
- **Structural pair pattern**: one member of nearly every `.Trash` pair comes from the
  `1770669071/1770669072.1006834_*` import batch (2026-02-09 20:31-20:32 UTC), the other from a
  wider range of later local mtimes — used only as a deterministic tie-break for the (expected
  rare) ambiguous case, never as the primary decision.
- **Maildir filename parsing hazard (Phase 3 lesson)**: maildir filenames contain literal colons
  in the `,U=NNN:2,FLAGS` info suffix; naive colon-splitting corrupts output. Extract Message-Ids
  by reading file contents (not by parsing filenames), and preserve the full `:2,FLAGS` suffix on
  rename.
- **Bridge connection (verified from `~/.mbsyncrc`)**: `Host 127.0.0.1`, `Port 1143`,
  `User benjamin@logos-labs.ai`, `TLSType None`, `AuthMechs LOGIN`,
  `PassCmd "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"`. Far
  mailbox names are `Trash` and `Archive`. The repair script reuses this exact credential path —
  no secret is ever hardcoded.
- **Phase 1 backup is intact and authoritative**: `~/Mail/.logos-backup-20260706/` holds
  per-folder tarballs (verified with `tar -tzf`), a 28-file `.mbsyncstate`/`.uidvalidity`
  snapshot, `baseline-counts.txt`, and `phase5/` enumeration data (`trash-dup-pairs.tsv`).

### Prior Plan Reference

Task 826's plan (`plans/01_logos-mbsync-maildir-repair.md`) is the parent context, not a template.
Its Phase 5 stopped at a verification gate rather than force a destructive step — this task
implements the safe follow-on that Phase 5's blocker report identified. Effort calibration: task
826 budgeted 1.5h for a naive delete-based Phase 5 that proved unsafe; the live-IMAP + script +
pilot approach here is correctly scoped at ~4h. Validated approach carried forward: back up first,
gate every mutation behind a verification check, operate on disjoint folder territory, and STOP at
a gate rather than force through uncertainty.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided in the delegation context; roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- For each of the 862 colliding `U=NNN` slots, determine via live read-only IMAP which local file
  (if either) matches the Bridge server's current Message-Id for that server UID.
- Rename the non-matching member of each pair to a fresh, non-colliding `U=NNN` token so each UID
  maps to exactly one physical file in `.Trash/cur` and `.Archive/cur`.
- Preserve both messages of every pair on disk (rename only; zero deletes).
- Perform zero server-side writes: connect read-only (IMAP `EXAMINE`), fetch with `BODY.PEEK`,
  never `STORE`/`APPEND`/`COPY`/`EXPUNGE`.
- Provide a dry-run mode that lists every planned rename before any execution.
- Validate the technique on the 2 `.Archive` pairs before applying it to the 860 `.Trash` pairs.
- Write a complete decision log (every rename: which file matched, which was renamed, old/new
  token, decision category) to the Phase 1 backup directory.

**Non-Goals** (explicitly out of scope — left for task 826 to resume afterward):
- Running `mbsync logos` (any scoped or full reconcile).
- Clearing/resetting `.Trash`/`.Archive` `.mbsyncstate` or `.uidvalidity`.
- Lifting `email-freeze` / running `email-thaw`.
- notmuch reindexing.
- Re-verifying Message-Id distinctness of the 862 pairs (already conclusively established).
- Re-running Phase 3's `.Labels.*` mirror-redundancy analysis (separate, already-decided concern).
- Any modification to the server side, any credential change, any change to `~/.dotfiles`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script performs a server-side write (STORE/APPEND/COPY/EXPUNGE), violating "zero server writes" | H | L | Use IMAP `EXAMINE` (read-only SELECT) and `BODY.PEEK` only; the client issues no other mutating verbs; Phase 2 probe asserts read-only; Phase 6 confirms server Message-Ids unchanged for a sample |
| UIDVALIDITY mismatch between server and the snapshotted `.uidvalidity` invalidates the local `U=NNN` <-> server-UID correspondence | H | M | Phase 2 reads server `UIDVALIDITY` from the `EXAMINE` response and compares against the Phase 1 `.uidvalidity` snapshot per folder; on mismatch, STOP and escalate — the whole UID-comparison premise breaks and needs human review |
| A rename accidentally deletes or corrupts a message | H | L | Rename-only within the same `cur/` dir via `mv`; preserve the full `,U=NNN:2,FLAGS` suffix, changing only the numeric token; verify post-run file counts equal pre-run counts (0 deletes) |
| Neither pair member matches the server's Message-Id at that UID (server holds a third message, or UID absent) | M | M | Still break the collision (rename-only is non-destructive) using the deterministic import-batch tie-break, but log the slot as `UNVERIFIED`; if the `UNVERIFIED` count exceeds a small threshold, STOP before bulk execution and escalate |
| Fresh `U=NNN` token collides with an existing token or an intra-run allocation | M | L | Compute max `U=` across the whole folder (`cur`+`new`) once, allocate strictly above it, and track allocations within the run |
| Renamed file is re-pushed to the server as a new duplicate by task 826's later reconcile (blocker report path 2 concern) | M | M | This task performs zero server writes and zero state changes; the renamed file is real mail already present server-side under its own UID; re-association is task 826's controlled step (it clears `.Trash`/`.Archive` state and rebuilds Near-side pairing). Residual risk is explicitly handed off, not resolved here |
| An mbsync/isync process runs mid-repair and mutates state | H | L | Phase 1 confirms `email-freeze` is active and `pgrep mbsync`/`isync` is empty before any mutation; re-check before Phase 5 bulk execution |
| Message-Id extraction mangled by maildir filenames containing literal colons | M | L | Read Message-Ids from file contents (not filename parsing); operate on absolute paths |
| Bridge IMAP unreachable or credential lookup fails | M | L | Phase 2 probe fails fast with a clear error before any mutation; no partial renames occur because the script fetches all needed server Message-Ids before executing any rename |

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

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase is
a safety gate for the next, so every wave contains one phase.

---

### Phase 1: Preflight — Backup and Freeze Verification [COMPLETED]

**Goal**: Confirm the environment is frozen and the Phase 1 backup is intact before touching any
file, and record an authoritative pre-repair snapshot.

**Tasks**:
- [x] Confirm no mbsync/isync process is running: `pgrep -a mbsync`, `pgrep -a isync` return
      nothing; confirm `email-freeze` is still in effect (per task 826, the freeze was never
      lifted).
- [x] Verify the Phase 1 backup at `~/Mail/.logos-backup-20260706/` is intact: `tarballs/`
      contains the `.Trash` and `.Archive` tarballs and `tar -tzf` succeeds on each;
      `mbsyncstate/` snapshot exists; `baseline-counts.txt` exists;
      `phase5/trash-dup-pairs.tsv` exists.
- [x] Record a pre-repair snapshot to the task working dir: current file counts for
      `~/Mail/Logos/.Trash/cur` and `~/Mail/Logos/.Archive/cur`, and regenerate the duplicate-UID
      lists (`ls <folder> | grep -oE 'U=[0-9]+' | sort | uniq -d`) to confirm 860 / 2 collisions
      still hold before any change.
- [x] Create the task working directory for this run's artifacts under the backup dir:
      `~/Mail/.logos-backup-20260706/task-828/` (holds the repair script, dry-run outputs, and the
      decision log).

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- None (read-only verification). Creates `~/Mail/.logos-backup-20260706/task-828/` for artifacts.

**Verification**:
- `pgrep mbsync`/`pgrep isync` empty; backup tarballs pass `tar -tzf`; pre-repair counts and the
  860 / 2 duplicate-UID lists recorded to `task-828/pre-repair-snapshot.txt`.

---

### Phase 2: Establish Strictly Read-Only IMAP Connectivity to ProtonMail Bridge [COMPLETED]

**Goal**: Prove a read-only IMAP channel to the Bridge that can retrieve per-server-UID
Message-Ids for the `Trash` and `Archive` mailboxes, and confirm UIDVALIDITY matches the local
snapshot.

**Tasks**:
- [x] Build a minimal Python `imaplib` probe (stdlib, no extra deps; run via system `python3` or
      `nix shell nixpkgs#python3`). Connection params come from `~/.mbsyncrc`: `127.0.0.1:1143`,
      user `benjamin@logos-labs.ai`, plaintext (`TLSType None`), credential fetched at runtime via
      `secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai` — never
      hardcode the password.
- [x] `LIST` mailboxes and confirm the Far names `Trash` and `Archive` exist (map: local
      `.Trash` -> IMAP `Trash`, local `.Archive` -> IMAP `Archive`).
- [x] Open each mailbox with `EXAMINE` (read-only SELECT) and capture the server `UIDVALIDITY`.
      Compare it against the Phase 1 `.uidvalidity` snapshot for that folder
      (`~/Mail/.logos-backup-20260706/mbsyncstate/...`). If they differ for either folder, STOP and
      escalate — the `U=NNN` <-> server-UID correspondence is invalid and the technique cannot be
      applied safely without human review. *(deviation: altered — the correct comparison value is
      `FarUidValidity` from mbsync's own `.mbsyncstate` per folder, not the maildir-root
      `.uidvalidity` file, which stores `NearUidValidity` — the local side's own identity value,
      unrelated to the server. Verified: Trash FarUidValidity=95457113 == server
      UIDVALIDITY=95457113; Archive FarUidValidity=95457115 == server UIDVALIDITY=95457115. Both
      match. Additionally verified 0 Near/Far UID divergence across all 924 (.Trash) / 39
      (.Archive) tracked pairs in `.mbsyncstate`, confirming local `U=NNN` filename tokens
      correspond directly to server UID `NNN`.)*
- [x] Sample-fetch: `UID FETCH <uid> (BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])` for a few known
      colliding UIDs; confirm a Message-Id is returned per server UID and that `BODY.PEEK` leaves
      the `\Seen` flag unchanged.
- [x] Assert in code and in a short probe log that the client will only ever issue `EXAMINE` +
      `UID FETCH BODY.PEEK` — no `STORE`, `APPEND`, `COPY`, `EXPUNGE`, or writable `SELECT`.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- Creates the probe script and `task-828/imap-probe.log` under the backup working dir. No maildir
  or server mutation.

**Verification**:
- Probe connects, lists `Trash`/`Archive`, `EXAMINE` succeeds read-only, UIDVALIDITY matches the
  snapshot for both folders, and sample Message-Ids are retrieved. Probe log records the read-only
  verb assertion.

---

### Phase 3: Build the Dry-Run-Capable, Rename-Only Repair Script [COMPLETED]

**Goal**: Implement the core repair algorithm with a default dry-run mode and an explicit,
separately-gated execute mode.

**Tasks**:
- [x] Enumerate local duplicate-`U=` pairs in a target folder's `cur/` by parsing the `U=NNN`
      token from filenames (cross-check against `phase5/trash-dup-pairs.tsv`).
- [x] For each local file in a pair, extract its `Message-Id` by reading file contents (not
      filename parsing), operating on absolute paths.
- [x] For each colliding slot `U=NNN`, fetch the server's current Message-Id at server UID `NNN`
      via read-only `UID FETCH ... BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)]`.
- [x] Decision rule per pair:
      - Exactly one member's Message-Id equals the server's Message-Id at `U=NNN` -> that member
        keeps the token; rename the OTHER member to a fresh token. Category: `MATCHED`.
      - Neither matches (server UID holds a third message or is absent) -> still break the
        collision by renaming the non-import-batch member (deterministic tie-break) to a fresh
        token; keep the import-batch member on `U=NNN`. Category: `UNVERIFIED` (flagged for human
        review).
      - Both match -> impossible given the established Message-Id distinctness; assert/guard and
        abort with a clear error if ever seen.
- [x] Fresh-token generation: compute `max(U=)` across the whole folder (`cur`+`new`) once,
      allocate fresh tokens strictly above it, monotonically, tracking allocations within the run
      to prevent intra-run collisions.
- [x] Rename mechanics: change only the `U=NNN` numeric substring to `U=MMM`, preserving the rest
      of the filename including the `:2,FLAGS` info suffix; `mv` within the same `cur/` directory;
      never delete.
- [x] Dry-run mode (DEFAULT): compute all decisions and write the full planned-rename list to the
      decision log WITHOUT executing any `mv`. Execute mode requires an explicit flag (e.g.
      `--execute`) and re-uses the identical decision computation.
- [x] Decision-log schema (append-safe TSV or JSONL under `task-828/`): `timestamp`, `folder`,
      `colliding_uid`, `server_msgid`, `fileA`, `fileA_msgid`, `fileB`, `fileB_msgid`,
      `matched_member`, `renamed_file`, `old_token`, `new_token`, `category` (`MATCHED`/
      `UNVERIFIED`). *(deviation: altered — implemented as JSONL, one object per line, with
      additional `new_filename` and `executed` fields for clarity; all required fields present.)*
- [x] Fetch-then-act ordering: fetch ALL needed server Message-Ids and compute ALL decisions
      before performing ANY rename, so a mid-run connection failure cannot leave a folder
      half-repaired.

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- Creates `~/Mail/.logos-backup-20260706/task-828/repair-uid-collisions.py` (or equivalent). No
  maildir mutation in this phase (script authored, not yet executed against real folders beyond
  dry-run wiring tested in Phase 4).

**Verification**:
- Script runs in dry-run without error against a small input, emits a well-formed decision log,
  and performs no `mv` and no server write. Read-only IMAP verbs only.

---

### Phase 4: .Archive Pilot — Dry-Run, Hand-Verify, Then Execute (2 pairs) [COMPLETED]

**Goal**: Validate the whole technique end-to-end on the 2 tractable `.Archive` pairs before
scaling.

**Tasks**:
- [x] Run the script in dry-run against `~/Mail/Logos/.Archive/cur` (2 pairs); review the planned
      renames and decision log.
- [x] Hand-verify both pairs (tractable by hand): confirm the `MATCHED` member's Message-Id truly
      equals the server's Message-Id at that UID, and that the renamed member is the genuinely
      distinct message. Confirm both categories/decisions are sensible.
- [x] Execute the renames on the 2 `.Archive` pairs (`--execute`).
- [x] Verify: `ls ~/Mail/Logos/.Archive/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` returns
      nothing; `.Archive/cur` file count is unchanged vs the Phase 1 pre-repair snapshot (2
      renames, 0 deletes); both original Message-Ids are still present on disk (`grep`); the
      decision log records both renames.

**Timing**: 0.5 hours

**Depends on**: 3

**Files to modify**:
- `~/Mail/Logos/.Archive/cur/` — 2 files renamed (token only). Appends to the decision log.

**Verification**:
- `.Archive/cur` duplicate-UID check empty; count unchanged (0 deletes); both Message-Ids
  preserved; decision log updated. If any check fails, STOP — do not proceed to Phase 5.

---

### Phase 5: .Trash Bulk — Dry-Run Review, Anomaly Gate, Then Execute (860 pairs) [COMPLETED]

**Goal**: Apply the validated technique to the 860 `.Trash` pairs, with an anomaly gate before
bulk execution.

**Tasks**:
- [x] Re-confirm the freeze and no mbsync/isync process before touching `.Trash`.
- [x] Run the script in dry-run against `~/Mail/Logos/.Trash/cur` (860 pairs); review the decision
      log: count `MATCHED` vs `UNVERIFIED`, and flag any pair where the server UID was absent or
      both members matched.
- [x] Anomaly gate: if the `UNVERIFIED`/anomaly count exceeds a small threshold (e.g. >5% of
      pairs, or any `both-match` assertion failure), STOP and write a blocker/handoff for human
      review rather than mass-executing. Result: 860/860 MATCHED, 0 UNVERIFIED (0%), no
      both-match aborts — gate passed cleanly, well under threshold.
- [x] On a clean dry-run, execute the renames on the 860 `.Trash` pairs (`--execute`).
- [x] Verify: `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` returns
      nothing; `.Trash/cur` file count is unchanged vs the pre-repair snapshot (0 deletes);
      spot-check a sample of renamed pairs to confirm both Message-Ids are preserved on disk.

**Timing**: 0.75 hours

**Depends on**: 4

**Files to modify**:
- `~/Mail/Logos/.Trash/cur/` — up to 860 files renamed (token only). Appends to the decision log.

**Verification**:
- `.Trash/cur` duplicate-UID check empty; count unchanged (0 deletes); sampled Message-Ids
  preserved; decision log complete for all executed renames.

---

### Phase 6: Final Verification, Decision-Log Finalization, and Handoff to Task 826 [COMPLETED]

**Goal**: Confirm the full definition of done, finalize the decision log, and hand off cleanly to
task 826.

**Tasks**:
- [x] Run the DoD commands for BOTH folders and confirm empty output:
      `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the `.Archive/cur`
      equivalent.
- [x] Confirm zero deletes: post-repair total file counts for `.Trash/cur` and `.Archive/cur`
      equal the Phase 1 pre-repair snapshot counts.
- [x] Confirm zero server-side writes: re-read (`BODY.PEEK`) a small sample of server UIDs and
      confirm their Message-Ids are unchanged; confirm the script's IMAP verb log shows only
      `EXAMINE` + `UID FETCH BODY.PEEK`.
- [x] Finalize and archive the decision log under `~/Mail/.logos-backup-20260706/task-828/`
      documenting every rename across both folders (both `MATCHED` and any `UNVERIFIED`).
- [x] Write a short handoff note (for task 826): the UID collisions are resolved; task 826 may
      resume its Phase 5 state reset (back up then clear ONLY `.Trash`/`.Archive`
      `.mbsyncstate`/`.uidvalidity`) and Phase 7 scoped `mbsync logos` reconcile. Restate what
      remains out of scope here (mbsync, state clear, thaw, reindex) and note the residual
      re-push risk that task 826's controlled reconcile addresses.

**Timing**: 0.5 hours

**Depends on**: 5

**Files to modify**:
- None (verification + log finalization). Writes the final decision log and handoff note under the
  backup working dir.

**Verification**:
- Both folders' duplicate-UID checks empty; both file counts equal pre-repair snapshot (0
  deletes); server Message-Id sample unchanged (0 server writes); decision log and handoff note
  written.

## Testing & Validation

- [x] `pgrep mbsync` / `pgrep isync` empty before every mutation (Phases 1, 5).
- [x] Phase 1 backup tarballs pass `tar -tzf`; pre-repair snapshot records 860 `.Trash` + 2
      `.Archive` collisions.
- [x] IMAP probe connects read-only (`EXAMINE`), UIDVALIDITY matches the `.uidvalidity` snapshot
      for both folders, and sample Message-Ids are retrieved with `BODY.PEEK`. *(deviation:
      altered — correct comparison target is `.mbsyncstate`'s `FarUidValidity`, not the
      maildir-root `.uidvalidity` file; both folders matched after correction.)*
- [x] Dry-run produces a well-formed decision log and performs no `mv` and no server write.
- [x] `.Archive` pilot: `uniq -d` empty; count unchanged (0 deletes); both Message-Ids preserved.
- [x] `.Trash` bulk: `uniq -d` empty; count unchanged (0 deletes); sampled Message-Ids preserved;
      anomaly gate passed (860/860 MATCHED, 0 UNVERIFIED, 0 anomalies).
- [x] Final: `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the
      `.Archive/cur` equivalent both empty; zero deletes; zero server writes; decision log written.

## Artifacts & Outputs

- `~/Mail/.logos-backup-20260706/task-828/repair-uid-collisions.py` — the dry-run-capable,
  rename-only repair script.
- `~/Mail/.logos-backup-20260706/task-828/pre-repair-snapshot.txt` — pre-repair counts and
  duplicate-UID lists.
- `~/Mail/.logos-backup-20260706/task-828/imap-probe.log` — read-only connectivity/UIDVALIDITY
  verification.
- `~/Mail/.logos-backup-20260706/task-828/decision-log.tsv` (or `.jsonl`) — every rename decision
  (folder, colliding UID, server Message-Id, both candidates' Message-Ids, matched member, renamed
  file, old/new token, category).
- `~/Mail/.logos-backup-20260706/task-828/handoff-to-826.md` — resume note for task 826.
- `specs/828_logos_trash_archive_uid_collision_repair/summaries/01_logos-uid-collision-repair-summary.md`
  — implementation summary.

## Rollback/Contingency

- **Renames are non-destructive and reversible**: the decision log records every `old_token` ->
  `new_token` mapping, so any rename can be reverted by mapping back. No file is ever deleted.
- **Folder-level rollback**: restore `~/Mail/Logos/.Trash` and/or `.Archive` from the Phase 1
  tarballs (`~/Mail/.logos-backup-20260706/tarballs/`) and the `.mbsyncstate`/`.uidvalidity`
  snapshot; the freeze remains in effect throughout, so no reconcile can intervene.
- **UIDVALIDITY mismatch**: STOP at Phase 2, change nothing, and escalate for human review — the
  comparison premise is invalid.
- **Anomaly gate tripped**: STOP at Phase 5 before bulk execution, write a blocker/handoff, and
  leave `.Trash` untouched (the `.Archive` pilot renames, if already executed, are individually
  reversible via the decision log).
- **Abort criterion**: if server-side writes cannot be guaranteed zero (e.g. the IMAP library
  forces a writable SELECT), do not proceed — the "zero server writes" invariant is
  non-negotiable.
