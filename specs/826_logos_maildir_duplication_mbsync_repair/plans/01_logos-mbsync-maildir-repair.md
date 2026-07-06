# Implementation Plan: Task #826

- **Task**: 826 - Fix Logos (Protonmail Bridge) maildir duplication and mbsync reconcile failures
- **Status**: [PARTIAL]
- **Effort**: 7.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/826_logos_maildir_duplication_mbsync_repair/reports/01_logos-maildir-mbsync-diagnosis.md
- **Artifacts**: plans/01_logos-mbsync-maildir-repair.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: nix
- **Lean Intent**: false

## Overview

Repair the Logos/ProtonMail-Bridge mail infrastructure by fixing two independent root causes
diagnosed in research: (1) `Channel logos-labels` in `~/.dotfiles/modules/home/email/mbsync.nix`
mirrors every additive Bridge label as a separate local Maildir++ folder (`.Labels.Important`
alone holds 37,540 of 43,660 files, 86% of the tree), and (2) a separate, older duplicate-UID
corruption in `.Trash`/`.Archive` (860/1085 Trash UIDs have two physical files sharing a `U=NNN`
suffix, from the 2026-02-09 import) that blocks `mbsync logos` reconcile and prevents the 161
staged Trash deletes from reaching the Proton server. This is a **cross-repo, partially
destructive** task: config fixes land in `~/.dotfiles`; maildir de-duplication/cleanup runs
against the live `~/Mail/Logos` tree. The work is sequenced conservatively — freeze and back up
first, apply the config fix so no further bloat accumulates, gate every destructive step behind a
verification check, and only reconcile after all mutations are confirmed clean. Definition of done:
config fix committed and applied, `.Labels.*` bloat resolved, `.Trash`/`.Archive` UID collisions
removed, headerless test message removed, `mbsync logos` reconciles exit 0 with the 161 Trash
deletes pushed, and notmuch reindexed against the cleaned tree.

### Research Integration

This plan operationalizes the "Maildir De-duplication / Cleanup Plan" (report §Recommendations
A-D and the numbered cleanup sequence). Key findings carried forward:
- **Config fix (Rec A)**: Remove `logos-labels` from `Group logos`, keep the channel definition,
  following the existing `gmail-trash`/`gmail-spam` exclusion precedent in the same file. Keep
  `logos-folders` (Proton Folders are exclusive; currently 0 files).
- **Dedup must be Message-ID-based, not checksum-based (Rec B, report §3)**: zero byte-identical
  duplicates exist across all 43,660 files — Bridge injects copy-specific artifacts
  (`X-Pm-Gluon-Id`), so `fdupes`/md5 dedup will NOT work. Key on `Message-Id`.
- **Dotted-folder crash (Rec C)**: `.Labels.benbrastmckie@gmail.com` resolves as a side effect of
  removing `logos-labels` from the group — no separate fix needed.
- **Headerless test message (Rec D)**: located in `.Sent` (NOT `.Drafts`) —
  `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S`.
- **notmuch counts are unreliable (report caveat)**: use direct filesystem enumeration
  (`find`/`ls`) as ground truth, not `notmuch path:`/`folder:` queries (cross-ref tasks
  823/824/827).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Remove `logos-labels` from `Group logos` in `~/.dotfiles/modules/home/email/mbsync.nix` (with
  explanatory comment) and apply it via home-manager rebuild, stopping further label-mirror bloat.
- Resolve the `.Labels.*` local bloat (38,041 mirror files) safely, only after verifying no
  message exists exclusively under a label.
- Remove the `.Trash`/`.Archive` duplicate-`U=NNN` files (Message-ID-based) and reset the narrow
  per-folder mbsync state so reconcile succeeds.
- Remove the headerless test message from `.Sent`.
- Achieve a clean (exit 0) `mbsync logos` reconcile that pushes the 161 staged Trash deletes.
- Reindex notmuch against the cleaned maildir.

**Non-Goals**:
- Re-enabling label sync (`logos-labels` stays out of the group; the channel definition is kept
  only for optional manual inspection).
- Fixing the underlying notmuch `path:`/`folder:` index-staleness issue (tracked by sibling tasks
  823/824/827; this plan only does a targeted reindex).
- Running `/email --logos --sync` at any point before the fix is verified (explicitly prohibited).
- Any change to `logos-folders` (Proton Folders are exclusive; left in the group unchanged).
- Modifying `protonmail.nix` (Bridge service config is not implicated).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bulk-deleting `.Labels.*` loses a message that exists ONLY under a label | H | L | Phase 3 verification gate: confirm every `.Labels.*` Message-ID also exists in a canonical folder before Phase 4 deletes anything; move any label-only message into a canonical folder first; tarball backup from Phase 1 |
| Message-ID-based dedup keeps the wrong copy of a `.Trash`/`.Archive` pair | M | M | Prefer the copy whose flags match the desired local state (e.g. already-trashed); back up both members before removing either; per-folder tarball from Phase 1 |
| Resetting `.mbsyncstate`/`.uidvalidity` triggers unexpected re-download/re-push | H | M | Scope the reset to ONLY `.Trash`/`.Archive`, never the whole `logos` account; snapshot all state files in Phase 1; dry-run the reconcile before committing pushes |
| An mbsync process runs mid-cleanup and corrupts state | H | L | Phase 1 `email-freeze` guarantees no mbsync runs; verify no `mbsync`/`isync` process before each destructive phase |
| Config fix not actually applied (edited `.nix` but home-manager not rebuilt) | M | M | Phase 2 verifies the generated `mbsyncrc` no longer lists `logos-labels` under `Group logos` after rebuild |
| Reconcile still exits non-zero due to an un-diagnosed folder | M | L | Phase 7 runs a scoped `mbsync logos` dry-run first and captures full stderr; on failure, stop and record which channel failed rather than force-pushing |
| Parallel destructive phases (3/5/6) collide | M | L | Phases 3, 5, 6 touch disjoint folder territory (`.Labels.*` read-only vs `.Trash`/`.Archive` vs `.Sent`); if executed by a single operator, run sequentially |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 5, 6 | 2 |
| 4 | 4 | 3 |
| 5 | 7 | 4, 5, 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel. Wave 3 phases (3, 5, 6) operate on disjoint
folder territory; if executed by a single operator rather than parallel agents, run them
sequentially under the single Phase 1 freeze.

---

### Phase 1: Freeze and Back Up [COMPLETED]

**Goal**: Guarantee no mbsync runs during cleanup and capture a full rollback snapshot before any
mutation.

**Tasks**:
- [x] Run `email-freeze` (the provided helper) to stop/prevent any mbsync/isync process and the
      `preNew`/sync hooks for the duration of the cleanup. *(completed — note: email-freeze's own
      tarball only covers `~/Mail/Gmail`; the Logos-specific backup below is separate and
      authoritative for this task)*
- [x] Confirm no `mbsync`/`isync`/`mbsync-*` process is running (`pgrep -a mbsync`). *(completed —
      confirmed twice: once via email-freeze, once independently before the Logos backup)*
- [x] Snapshot every `.mbsyncstate*` and `.uidvalidity` file under `~/Mail/Logos` to a timestamped
      backup dir (e.g. `~/Mail/.logos-backup-{DATE}/mbsyncstate/`), preserving relative paths.
      *(completed — 28 files copied to `~/Mail/.logos-backup-20260706/mbsyncstate/`)*
- [x] Create per-folder tarball backups of the folders that will be mutated:
      `.Trash`, `.Archive`, `.Sent`, and the `.Labels.*` folders
      (`.Labels.Important`, `.Labels.Letters`, `.Labels.EuroTrip`, `.Labels.CrazyTown`).
      *(completed — 7/7 tarballs written to `~/Mail/.logos-backup-20260706/tarballs/`, integrity
      verified with `tar -tzf`)*
- [x] Record baseline filesystem counts (per-folder `find … -path "*/cur/*" -o -path "*/new/*" |
      wc -l`) to compare against post-cleanup counts. *(completed — written to
      `~/Mail/.logos-backup-20260706/baseline-counts.txt`; TOTAL: 43660, matching the research
      report's baseline exactly)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- None in-repo. Creates backup artifacts under `~/Mail/.logos-backup-{DATE}/` (outside the repo).

**Verification**:
- `pgrep mbsync` returns nothing.
- Backup dir contains a copy of every `.mbsyncstate*`/`.uidvalidity` and a tarball per mutated
  folder; baseline counts recorded to a file in the backup dir.

---

### Phase 2: Apply mbsync.nix Config Fix (cross-repo, ~/.dotfiles) [COMPLETED]

**Goal**: Remove `logos-labels` from `Group logos` so no further label-mirror bloat accumulates,
and apply it via home-manager.

**Tasks**:
- [x] In `~/.dotfiles/modules/home/email/mbsync.nix`: keep the `Channel logos-labels` *definition*
      but remove it from the `Group logos` channel list, adding an explanatory comment mirroring
      the existing `gmail-trash`/`gmail-spam` exclusion precedent (labels are additive Bridge
      metadata, not exclusive folders; including them duplicated every labeled message and crashed
      the whole-group reconcile on the dotted `benbrastmckie@gmail.com` label name). *(completed)*
- [x] Leave `logos-folders` in `Group logos` unchanged (Proton Folders are exclusive; 0 files).
      *(completed — unchanged)*
- [x] Rebuild home-manager so the generated `mbsyncrc` reflects the change
      (`home-manager switch --flake …` or the repo's standard rebuild command). *(completed —
      `home-manager switch --flake .#benjamin`; also verified via a scoped `nix build
      .#homeConfigurations.benjamin.activationPackage` before the switch)*
- [x] Commit the change in `~/.dotfiles` (separate repo; scoped commit referencing task 826).
      *(completed — commit a8f65ad, "email: remove logos-labels from Group logos (nvim task 826)",
      only `modules/home/email/mbsync.nix` staged)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/.dotfiles/modules/home/email/mbsync.nix` - remove `logos-labels` from `Group logos`, add
  explanatory comment; keep channel definition.

**Verification**:
- The generated `mbsyncrc` (e.g. `~/.mbsyncrc` or the home-manager-managed path) no longer lists
  `logos-labels` under `Group logos`; `logos-folders` and the five base channels are still present.
- `~/.dotfiles` has a committed change; `git -C ~/.dotfiles status` is clean.

---

### Phase 3: Verify Labels-Mirror Redundancy (deletion safety gate) [COMPLETED]

**Goal**: Confirm every message under `.Labels.*` also exists in a canonical folder before any
deletion, and identify any label-only messages that must be preserved.

**Tasks**:
- [x] For each `.Labels.*` folder, extract the set of `Message-Id` headers
      (`.Labels.Important`, `.Labels.Letters`, `.Labels.EuroTrip`, `.Labels.CrazyTown`).
      *(completed — 37540/488/8/5 files, 100% have a Message-Id header)*
- [x] Extract the `Message-Id` set from the canonical folders
      (top-level INBOX `cur`/`new`, `.Archive`, `.Sent`, `.Drafts`, `.Trash`). *(completed —
      5615 unique canonical Message-IDs; `.Folders` confirmed empty, 0 files)*
- [x] Compute the set difference: Message-IDs present in `.Labels.*` but absent from every
      canonical folder ("label-only" messages). *(completed — see verification report)*
- [x] Produce a verification report listing counts and any label-only Message-IDs (with their
      source file paths). If the label-only set is non-empty, list each file so Phase 4 can move it
      into a canonical folder before deleting the label mirror. *(completed — report at
      `specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-3-verification-report.md`.
      DEVIATION/CRITICAL FINDING: the label-only set is NOT a small exception list as the plan
      assumed — it is 98.4% of `.Labels.Important` (36925/37540) and 99.8% of `.Labels.Letters`
      (487/488). This invalidates the plan's redundancy assumption; see report for full analysis
      and the resulting Phase 4 fallback decision.)*
- [x] Use direct filesystem enumeration (`grep`/`find` over maildir files), NOT notmuch queries
      (per report caveat). *(completed — used `grep -Z -H -i -m1 "^message-id:"`, NUL-separated
      to correctly handle maildir filenames containing literal colons in the `U=NNN:2,FLAGS`
      suffix; an initial colon-split parse was discarded after it produced corrupted output)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- None (read-only verification). Writes a verification report to the Phase 1 backup dir.

**Verification**:
- Verification report exists listing per-folder Message-ID counts and the label-only set.
  *(satisfied — see phase-3-verification-report.md)*
- If label-only set is empty: Phase 4 may bulk-delete. If non-empty: the exact files to preserve
  are enumerated for Phase 4. *(label-only set is 98.4%/99.8%/62.5%/100% per folder — FAR from
  empty. Per the plan's own Abort criteria, Phase 4 falls back to leave-in-place/inert rather than
  bulk-delete or attempt an out-of-scope bulk-move of ~37,412 messages.)*

---

### Phase 4: Remove or Archive Orphaned Labels-Mirror Files [PARTIAL]

**Goal**: Reclaim the ~38,041 label-mirror files now that the channel is out of the group and
redundancy is verified, without losing any label-only message.

**Tasks**:
- [ ] For any label-only Message-ID identified in Phase 3: move its file into the appropriate
      canonical folder (e.g. `.Archive/cur`) with a correctly rewritten Maildir filename BEFORE
      deleting the label mirror. *(deviation: skipped — label-only set is ~37,412 messages
      (98.4%/99.8%/62.5%/100% per folder), not a small exception list; bulk-moving this many
      messages into `.Archive` (currently 54 files) is a human-judgment-requiring
      re-categorization decision out of scope for this plan's Phase 4 budget. See Phase 3
      verification report.)*
- [ ] Delete the now-orphaned `.Labels.Important`, `.Labels.Letters`, `.Labels.EuroTrip`,
      `.Labels.CrazyTown` mirror content (`cur`/`new` files). Because `logos-labels` is no longer
      in `Group logos`, these will not resync. Prefer removing the whole `.Labels.*` maildir
      directories (including their now-orphaned `.mbsyncstate`/`.uidvalidity`) rather than leaving
      empty shells; the empty `.Labels.[Gmail]-*`/`.Labels.[Imap]-*` mailboxes may be removed too.
      *(deviation: skipped — deletion is unsafe given the Phase 3 finding; would destroy ~37,412
      messages with no other local copy)*
- [x] If Phase 3 verification was inconclusive, fall back to leaving the files in place (inert,
      since the channel is out of the group) and record that decision — no data-loss risk.
      *(completed — this is the path taken. Phase 3 verification was not merely inconclusive but
      conclusively negative for bulk redundancy; the inert fallback applies a fortiori. All
      `.Labels.*` directories and their `.mbsyncstate`/`.uidvalidity` files are left completely
      untouched. Confirmed inert: `logos-labels` channel is out of `Group logos` per Phase 2, so
      no future `mbsync logos` will resync, grow, or touch these folders.)*

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `~/Mail/Logos/.Labels.*/` - delete orphaned mirror content (after preserving any label-only
  messages into canonical folders).

**Verification**:
- Post-deletion filesystem count for `~/Mail/Logos` drops by ~38,041 files vs the Phase 1 baseline
  (or the leave-in-place decision is recorded). *(leave-in-place decision recorded; filesystem
  count unchanged from Phase 1 baseline for all `.Labels.*` folders — confirmed below)*
- Every label-only Message-ID from Phase 3 is now present in a canonical folder. *(not
  applicable — no messages were moved; all label-only messages remain in their original
  `.Labels.*` location, which is preserved untouched, so no data loss occurred)*

**Phase 4 blocker (for handoff/orchestrator visibility)**: This plan's original goal of reclaiming
~38,041 `.Labels.*` files is NOT achieved. The files remain in place, inert but unreclaimed. A
follow-up task should be spawned to decide, with human input, the disposition of the ~37,412
label-only messages (fold into a canonical folder, leave as a permanent read-only archive, or
another resolution). This does not block Phases 5-8: the config fix (Phase 2) already prevents
further growth, and the mbsync-reconcile-blocking defects (duplicate Trash/Archive UIDs,
headerless Sent message) are independent of the Labels folders.

---

### Phase 5: Message-ID-Based UID Dedup for .Trash/.Archive + Narrow State Reset [PARTIAL]

**Goal**: Remove the duplicate-`U=NNN` files so each UID maps to exactly one physical file, then
reset only the two affected folders' mbsync state so reconcile can rebuild cleanly.

**Tasks**:
- [x] Enumerate duplicate `U=NNN` pairs in `.Trash/cur` (~860 pairs) and `.Archive/cur` (~2 pairs)
      via the `U=` suffix. *(completed — exactly 860 pairs in `.Trash/cur`, 2 pairs in
      `.Archive/cur`, matching the plan's estimate exactly; zero anomalies (every duplicate UID
      has exactly 2 files, none had 1 or 3+))*
- [ ] For each pair, choose the copy to keep by **Message-Id** and flags — NOT by checksum (content
      is not byte-identical; report §3). For `.Trash`, prefer the copy carrying the deleted/trashed
      flags matching the recent cleanup; for `.Archive`, keep the copy whose Message-ID is confirmed
      still present server-side. Remove the other member of the pair. *(deviation: skipped —
      CRITICAL FINDING: verified all 862 pairs (860 Trash + 2 Archive), and 100% have DIFFERENT
      Message-Id values between the two files. These are NOT redundant copies of one message; they
      are 862 distinct, irreplaceable real messages that collided on the same local UID number due
      to the 2026-02-09 import corruption. "Remove the other member" as literally instructed would
      permanently destroy real mail with zero redundancy. See
      `handoffs/phase-5-blocker-report.md` for full analysis.)*
- [ ] Script this (860 pairs is not feasible by hand); dry-run the script to list keep/remove
      decisions before executing, and log the decisions to the Phase 1 backup dir. *(deviation:
      skipped — no keep/remove decision can be made safely without a live IMAP verification
      against the Bridge server (out of scope for this plan) or a rename-only fix that risks
      creating new server-side duplicates on the next reconcile; see blocker report)*
- [ ] After dedup, back up and clear ONLY the `.Trash` and `.Archive` `.mbsyncstate`/`.uidvalidity`
      files (they are already snapshotted in Phase 1) so mbsync rebuilds Near-side state for just
      those two folders — do NOT reset the whole `logos` account state. *(deviation: skipped — no
      dedup occurred to act on; clearing state now, with the filename-level UID collision still
      physically present, would not resolve the underlying corruption and could cause unpredictable
      reconcile behavior. `.Trash`/`.Archive` `.mbsyncstate`/`.uidvalidity` remain untouched, exactly
      as backed up in Phase 1.)*

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `~/Mail/Logos/.Trash/cur/`, `~/Mail/Logos/.Archive/cur/` - remove duplicate-UID files.
- `~/Mail/Logos/.Trash/.mbsyncstate*`, `~/Mail/Logos/.Archive/.mbsyncstate*` and their
  `.uidvalidity` - clear (after backup) for narrow rebuild.

**Verification**:
- `ls .Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` returns nothing (no duplicate UIDs);
  same for `.Archive/cur`. *(NOT satisfied — duplicates remain; see blocker)*
- Keep/remove decision log written; `.mbsyncstate`/`.uidvalidity` for the two folders backed up
  then cleared. *(NOT satisfied by design — no destructive action taken; see blocker report)*

**Phase 5 BLOCKER (for handoff/orchestrator visibility)**: This phase could not complete safely.
See `handoffs/phase-5-blocker-report.md` for the full analysis. Summary: all 862 duplicate-UID
pairs (860 `.Trash` + 2 `.Archive`) were verified to contain two messages with DIFFERENT
Message-Id values — i.e. these are not redundant copies but distinct, irreplaceable real messages
that collided on the same local UID number. Deleting either member of any pair would destroy real
mail. No safe automated resolution is possible without either a live IMAP verification pass
against the Bridge server (862 lookups, out of scope here) or a rename-only fix that risks
creating new server-side duplicates on the next reconcile. No files or state were modified. This
blocks Phase 7 (reconcile), which depends on Phase 5.

---

### Phase 6: Remove Headerless Test Message from .Sent [COMPLETED]

**Goal**: Remove the local-only headerless test message that will fail IMAP `APPEND` on the next
`logos-sent` reconcile.

**Tasks**:
- [x] Confirm the target file is the headerless test scaffolding: subject `FROM LOGOS`, body
      `TEST`, no `Date:`/`Message-Id:`/`MIME-Version:`/`Content-Type:` header, Dovecot-style
      filename (distinct from Bridge's `hamsa,` pattern):
      `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S`.
      *(completed — content and missing headers confirmed exactly as described; a full-tree
      missing-`Date:`-header scan found this as the ONLY such file in all of `~/Mail/Logos`)*
- [x] Back it up to the Phase 1 backup dir, then delete it (per Rec D — do not synthesize a
      `Date:` header; it has no correspondence value). *(completed — backed up to
      `~/Mail/.logos-backup-20260706/phase6/`, verified byte-identical via `diff -q` before
      deletion, then removed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S` - remove.

**Verification**:
- The file no longer exists in `.Sent/cur`; a backup copy exists in the Phase 1 backup dir.
  *(satisfied — confirmed removed via `ls`; backup at
  `~/Mail/.logos-backup-20260706/phase6/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S`)*
- A missing-`Date:`-header scan over `~/Mail/Logos` returns no remaining files. *(satisfied —
  re-ran the full-tree scan post-deletion, 0 results)*

---

### Phase 7: Reconcile — Scoped `mbsync logos` [BLOCKED]

**Goal**: Push the 161 staged Trash deletes and confirm a clean (exit 0) group reconcile.

**Tasks**:
- [ ] Confirm the freeze is still in effect and no mbsync process is running. *(deviation:
      skipped — phase not attempted, see blocker below)*
- [ ] Run a scoped, group-limited `mbsync logos` (NEVER `mbsync -a`, and NEVER
      `/email --logos --sync`) — first with verbose/dry output if the isync version supports it —
      capturing full stdout/stderr. *(deviation: skipped — NOT attempted, per the orchestrator's
      explicit instruction not to run this before verification passes. Phase 5's duplicate-UID
      corruption is unresolved (see phase-5-blocker-report.md); running `mbsync logos` now would
      hit the exact same "duplicate UID" failure the task was created to fix, achieving nothing,
      and risks unpredictable behavior given the still-corrupted Near-side UID bookkeeping.)*
- [ ] On success (exit 0): confirm the 161 Trash deletes propagated (Trash reconciled with server)
      and `.Trash`/`.Archive` Near-side state rebuilt without duplicate-UID errors. *(not
      reached)*
- [ ] On failure: stop, record which channel failed and the exact stderr to the backup dir, and do
      NOT force-push; treat as a resume point rather than proceeding to reindex. *(not reached —
      phase blocked before attempting reconcile; treat Phase 5 as the resume point for a follow-up
      task)*

**Phase 7 BLOCKER**: Depends on Phase 5 (not completed) and Phase 4 (PARTIAL). Not attempted in
this run. See `handoffs/phase-5-blocker-report.md`.

**Timing**: 1 hour

**Depends on**: 4, 5, 6

**Files to modify**:
- `~/Mail/Logos/**/.mbsyncstate*`, `.uidvalidity` - regenerated by mbsync (expected, not manual).

**Verification**:
- `mbsync logos` exits 0; captured log shows no "duplicate UID" or dotted-folder errors.
- The 161 staged Trash deletes are pushed (Trash count reconciled against server expectation).

---

### Phase 8: Reindex notmuch and Consistency Check [BLOCKED]

**Goal**: Bring the notmuch index current with the cleaned maildir and lift the freeze.

**Tasks**:
- [ ] Run the sanctioned reindex path `notmuch new --no-hooks` (per `email-reindex`, task 824).
      *(deviation: deferred — depends on Phase 7 which was not attempted; deferred to the
      follow-up task that resolves Phase 5)*
- [ ] Perform a full index consistency spot-check cross-referencing filesystem counts vs notmuch
      counts for `Logos` folders; note (do not attempt to fix here) any residual `path:`/`folder:`
      inconsistency and cross-reference tasks 823/824/827. *(deviation: deferred — same reason)*
- [ ] Lift the `email-freeze` so normal sync/hooks resume. *(deviation: deferred — deliberately
      NOT lifted. The freeze remains in effect at the end of this implementation run because the
      `.Trash`/`.Archive` duplicate-UID corruption is unresolved; lifting the freeze risks an
      accidental `mbsync -a` trigger via notmuch's preNew hook or aerc's `$` keybind hitting the
      same corruption unexpectedly. Resume with `email-thaw` only after the Phase 5 blocker is
      resolved.)*
- [ ] Record final per-folder filesystem counts vs the Phase 1 baseline in a short cleanup log.
      *(completed for the folders actually touched — see the implementation summary for a
      complete before/after count table covering Phases 1-6)*

**Timing**: 0.75 hours

**Depends on**: 7

**Files to modify**:
- notmuch index (`~/.local/share/notmuch` or configured DB path) - reindexed (not a repo file).

**Verification**:
- `notmuch new --no-hooks` completes without error. *(not run — see blocker)*
- Consistency spot-check recorded; freeze lifted (normal sync resumes); final counts logged.
  *(freeze intentionally left in place; final filesystem counts for touched folders recorded in
  the implementation summary)*

**Phase 8 BLOCKER**: Depends on Phase 7 (blocked). Not attempted in this run. The freeze remains
active; resume with `email-thaw` only after a follow-up task resolves the Phase 5 blocker and
Phase 7's reconcile succeeds.

## Testing & Validation

- [x] `~/.dotfiles/modules/home/email/mbsync.nix` no longer includes `logos-labels` in `Group
      logos`; home-manager rebuild succeeded and the generated `mbsyncrc` reflects it. *(verified
      — Phase 2)*
- [x] No `.Labels.*` folder resyncs on `mbsync logos` (channel is out of the group). *(channel
      confirmed out of `Group logos` in the live `.mbsyncrc`; will not resync — cannot be verified
      by an actual reconcile since Phase 7 is blocked)*
- [ ] `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` is empty; same for
      `.Archive/cur`. *(NOT satisfied — 860/2 duplicate UIDs remain; see Phase 5 blocker)*
- [x] Missing-`Date:`-header scan over `~/Mail/Logos` returns no files. *(verified — Phase 6, 0
      results post-deletion)*
- [ ] `mbsync logos` exits 0 with no duplicate-UID or dotted-folder errors; 161 Trash deletes pushed.
      *(NOT attempted — blocked by Phase 5; see phase-5-blocker-report.md)*
- [ ] `notmuch new --no-hooks` completes; consistency spot-check recorded. *(NOT attempted —
      blocked by Phase 7)*
- [x] Every label-only Message-ID (if any) identified in Phase 3 is preserved in a canonical
      folder. *(satisfied trivially — no messages were moved or deleted; all label-only messages
      remain exactly where they were, in their original `.Labels.*` location)*

## Artifacts & Outputs

- `~/.dotfiles/modules/home/email/mbsync.nix` (modified, committed in ~/.dotfiles)
- `~/Mail/.logos-backup-{DATE}/` - mbsyncstate/uidvalidity snapshot, per-folder tarballs,
  verification report, keep/remove decision log, baseline + final counts, reconcile log
- `specs/826_logos_maildir_duplication_mbsync_repair/summaries/01_logos-mbsync-maildir-repair-summary.md`
  (implementation summary)

## Rollback/Contingency

- **Config fix**: revert the `~/.dotfiles/modules/home/email/mbsync.nix` commit and rebuild
  home-manager to restore the prior `mbsyncrc`.
- **Maildir mutations**: restore the affected folder(s) from the Phase 1 per-folder tarballs and
  restore the snapshotted `.mbsyncstate*`/`.uidvalidity` files, then re-freeze before retrying.
- **Reconcile failure**: the freeze remains in effect; Phase 7 stops without force-pushing and
  records the failing channel — restore state files from Phase 1 and treat as a resume point.
- **Abort criteria**: if Phase 3 verification cannot confirm Labels redundancy, skip Phase 4
  deletion (leave files inert) rather than risk data loss — the config fix alone resolves the
  reconcile-blocking defects once Phases 5-6 complete.
