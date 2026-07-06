# Research Report: Task #826

**Task**: 826 - Root-cause and fix the pre-existing Logos (Protonmail Bridge) mail infrastructure problem exposed by `/email --logos --all`
**Started**: 2026-07-05
**Completed**: 2026-07-06T02:10:53Z
**Effort**: ~1 focused research session (read-only filesystem/config inspection, no mutating commands run)
**Dependencies**: None (research-only; fixes land in `~/.dotfiles` per the cross-repo handoff note)
**Sources/Inputs**: `~/.dotfiles/modules/home/email/{mbsync.nix,notmuch.nix,protonmail.nix}`, live `~/Mail/Logos` maildir tree (read-only `find`/`ls`/`grep`/`md5sum`), `~/Mail/Logos/**/.mbsyncstate` files, `~/.config/notmuch/default/config` + hooks, `git log` on `~/.dotfiles`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause of the ~3x file bloat**: `mbsync.nix`'s `Channel logos-labels` (`Patterns "Labels/*"`, `Create Both`, `Expunge Both`, `Remove Both`, member of `Group logos`) mirrors every ProtonMail Bridge *label* as an independent local Maildir++ folder. Labels are additive/overlapping metadata (Gmail-style), not exclusive folder placement, so any message carrying a label is downloaded a **second time** into `.Labels.<name>` in addition to its canonical folder (INBOX/Archive/Trash/Sent). This is a config defect, not an mbsync bug.
- **The `.Labels.Important` folder alone is responsible for 86% of the bloat**: it physically holds 37,540 of 43,660 total Logos maildir files (confirmed via direct filesystem `find`, independent of notmuch's index). mbsync's own per-channel `.mbsyncstate` confirms this is a faithful pull (`MaxPulledUid 37549`/`MaxPushedUid 37540`), not a sync loop bug — the Bridge-side "Important" label mailbox genuinely contains that many UIDs, almost certainly because this account's mail was populated via a Gmail Easy-Switch/import that carried over Gmail's auto-applied "Important" marker on most historical mail.
- **This bloat happened in a single burst on 2026-07-04** (36,912 of 37,540 `.Labels.Important` files, all of `.Labels.Letters`'s 488 files, and 2,693 of the 2,705 top-level INBOX files share that one mtime) — consistent with `/email --logos --all` being the first real invocation that drove a full `mbsync logos` reconcile against the live Bridge account since the `logos-labels`/`logos-folders` channels were added to `Group logos` (dotfiles commit `45f7936`, 2026-06-24). The 161 files in `.Trash` with the same 2026-07-04 mtime match the task's own "161 local deletes from the recent cleanup" figure.
- **Duplicate-UID errors in `.Trash`/`.Archive` are a separate, older defect**: physically confirmed duplicate `U=NNN` Maildir suffixes (e.g. two files both `U=99` in `.Trash/cur`, two files both `U=1` in `.Archive/cur`), and their timestamps are all **2026-02-09** — the original historical import, not the recent cleanup. 860 of 1,085 distinct UIDs in `.Trash/cur` have 2 physical files apiece. This is separate from the Labels-channel bloat and must be repaired independently (Message-ID/content-based de-duplication, not a config-pattern fix) before `mbsync logos` can reconcile Trash/Archive again.
- **The dotted-folder crash (`.Labels.benbrastmckie@gmail.com`) is a direct consequence of the labels-as-folders design**: no such local directory exists on disk (mbsync never successfully created it), consistent with a Maildir++ hierarchy-separator collision — the label's leaf name itself contains a literal `.` (from the `gmail.com` domain), which Maildir++'s `.`-as-separator convention cannot represent unambiguously as a single path segment. Removing (or excluding) the `Labels/*` pattern from the routine sync group eliminates this crash as a side effect.
- **The "draft with missing Date header" is a single, identifiable test artifact**: `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S` — a 6-line message (`From`/`To`/`Cc`/`Bcc`/`Subject` only, body `TEST`) with **no** `Date:`, `Message-Id:`, `MIME-Version:`, or `Content-Type:` header, CRLF line endings, and a Dovecot-style unique-ID filename pattern distinct from Bridge's `hamsa,` Gluon-origin files. This is almost certainly local test/scaffolding content injected during earlier email-extension development, sitting in the bidirectionally-synced `.Sent` folder, where its missing `Date:` header breaks the IMAP `APPEND` mbsync issues when pushing it to Proton.
- **Caveat on notmuch-derived counts**: notmuch's own `path:`/`folder:` query results were internally inconsistent during this investigation (e.g. `path:Logos/cur` returned files physically under `Gmail/.All_Mail/cur`; `folder:Logos` unqualified returned far fewer messages than `folder:/Logos/` regex). This matches the notmuch index-staleness concerns already raised in sibling tasks 823/824/827. All duplication/count claims in this report are derived from direct filesystem inspection (`find`, `ls`, `md5sum` against `~/Mail/Logos` and its `.mbsyncstate` files), not from notmuch queries, to avoid inheriting that unreliability.

## Context & Scope

Read-only investigation of:
1. `~/.dotfiles/modules/home/email/mbsync.nix` — the `logos` IMAPAccount/Store/Channel/Group block.
2. `~/.dotfiles/modules/home/email/notmuch.nix` — hooks, tagging, ignore/exclude config.
3. `~/.dotfiles/modules/home/email/protonmail.nix` — Bridge systemd service (minimal; no mailbox-shaping config here).
4. Live `~/Mail/Logos` maildir tree and every `.mbsyncstate`/`.uidvalidity` file under it.
5. `git log` on `mbsync.nix` in `~/.dotfiles` for when the Labels/Folders channels were introduced.

No `mbsync`, `notmuch new`, or any mutating command was run. All commands used were `find`, `ls`, `grep`, `md5sum`, `git log`/`git show`, and read-only `notmuch search`/`count` (queries only, no `notmuch tag`/`notmuch new`).

## Findings

### 1. Current `mbsync.nix` Logos configuration (as-is)

```
IMAPAccount logos          Host 127.0.0.1:1143 (Bridge), TLSType None
MaildirStore logos-local   Inbox ~/Mail/Logos/, SubFolders Maildir++

Channel logos-inbox    Far INBOX      Near :logos-local:              Create Both, Expunge Both
Channel logos-sent     Far Sent       Near :logos-local:Sent          Create Both, Expunge Both
Channel logos-drafts   Far Drafts     Near :logos-local:Drafts        Create Both, Expunge Both
Channel logos-trash    Far Trash      Near :logos-local:Trash         Create Both, Expunge Both
Channel logos-archive  Far Archive    Near :logos-local:Archive       Create Both, Expunge Both
Channel logos-labels   Far (root), Patterns "Labels/*"   Create Both, Expunge Both, Remove Both
Channel logos-folders  Far (root), Patterns "Folders/*"  Create Both, Expunge Both, Remove Both

Group logos: logos-inbox, logos-sent, logos-drafts, logos-trash, logos-archive, logos-labels, logos-folders
```

Every channel in `Group logos` runs on a plain `mbsync logos` invocation (used by the `preNew` hook's `mbsync -a`, aerc's `$` keybind, and any manual `mbsync logos`/`mbsync -a`).

### 2. Physical maildir state (ground truth, filesystem-verified)

```
Total Logos maildir files (cur+new, all folders): 43,660

  37,540  .Labels.Important/cur     <- 86% of all files
   2,705  cur (top-level INBOX)
   1,945  .Trash/cur
     862  new (top-level INBOX)
     488  .Labels.Letters/cur
      54  .Archive/cur
      41  .Drafts/cur
      12  .Sent/cur
       8  .Labels.EuroTrip/cur
       5  .Labels.CrazyTown/cur
       0  .Labels.[Gmail]-Spam, .Labels.[Gmail]-Trash,
          .Labels.[Imap]-Spam, .Labels.[Imap]-Trash   <- empty label mailboxes, harmless today
```

No local directory named `.Labels.benbrastmckie@gmail.com` exists anywhere under `~/Mail/Logos` — consistent with mbsync never successfully materializing it (the dotted-folder failure, see §5).

Per-channel `.mbsyncstate` (`MaxPulledUid`/`MaxPushedUid`) for the Labels channels:

```
.Labels.Important   MaxPulledUid 37549  MaxPushedUid 37540   FarUidValidity 105402036
.Labels.Letters     MaxPulledUid   488  MaxPushedUid   488   FarUidValidity 105405389
.Labels.EuroTrip    MaxPulledUid     8  MaxPushedUid     8   FarUidValidity 105405899
.Labels.CrazyTown   MaxPulledUid     5  MaxPushedUid     5   FarUidValidity 105403764
.Labels.[Gmail]-*/[Imap]-*   MaxPulledUid 0  MaxPushedUid 0  FarUidValidity 10559567x
```

The base channels (inbox/sent/drafts/trash/archive) all carry an older `FarUidValidity` in the `95457113`–`95457118` range, while every Labels channel carries a distinctly newer `FarUidValidity` in the `105402036`–`105595676` range — i.e. the Labels mailboxes were provisioned by Bridge/Proton later than the base account, consistent with `logos-labels`/`logos-folders` being added to `mbsync.nix` well after initial account setup (dotfiles commit `45f7936`, 2026-06-24) and then only *actually* synced for the first time when `/email --logos --all` finally drove a real `mbsync logos` reconcile.

**mtime burst analysis** (all `.Labels.Important`, `.Labels.Letters`, and nearly all top-level INBOX files share one date):

```
.Labels.Important/cur : 36,912 files dated 2026-07-04 (628 pre-existing from earlier)
.Labels.Letters/cur    :    488 files dated 2026-07-04 (100% — first sync ever)
cur (top-level INBOX)  :  2,693 files dated 2026-07-04 (12 pre-existing: 5 Feb-09, 7 Mar-24)
new (top-level INBOX)  :    862 files dated 2026-07-04 (100%)
.Trash/cur             :    161 files dated 2026-07-04 (rest: 1,763 Feb-09, 20 Feb/Mar) <- matches
                              the task's own "161 local deletes from the recent cleanup"
.Archive/cur           :      0 files dated 2026-07-04 (untouched that day)
.Sent/cur              :      0 files dated 2026-07-04 (untouched that day)
```

**Conclusion**: 2026-07-04 was a single bulk-reconcile event — plausibly the first real `mbsync logos` pass after `logos-labels` became part of `Group logos` — that pulled the *entire* remote "Important" and "Letters" label mailboxes (and a large slice of INBOX) into local Maildir for the first time, while separately the day's cleanup work moved 161 messages to local Trash. Archive and Sent were unaffected, meaning the current `.Trash`/`.Archive` duplicate-UID corruption (below) is unrelated to this burst — it predates it by nearly five months.

### 3. Duplicate-UID corruption in `.Trash`/`.Archive` (separate, older defect)

Direct inspection of Maildir `U=NNN` filename suffixes:

```
.Trash/cur:    1,085 distinct UIDs, 860 of them (79%) have exactly 2 physical files sharing
               the same U=NNN suffix (e.g. U=99: one file dated 2026-02-09 12:31, another
               dated 2026-02-09 12:32 — 61 seconds apart, same original import session).
.Archive/cur:  only U=1 and U=2 are duplicated (2 files each); the rest of the ~39 distinct
               UIDs are single-copy.
```

Both members of every sampled duplicate pair carry the **same 2026-02-09** date (the original historical import), roughly a minute apart — this looks like a resumed/retried import pass during initial account setup that re-assigned already-used local UIDs rather than continuing the counter, corrupting mbsync's Near-side UID bookkeeping for those two folders specifically. This is what makes `mbsync logos` fail with "duplicate UID" on reconcile: isync cannot determine which of two physical files is authoritative for a given remote UID, and refuses to proceed with Expunge/push once it detects the collision — which is exactly what is blocking the 161 staged Trash deletes from reaching the Proton server.

**Content-duplication check** (md5sum over all 43,660 Logos maildir files): **zero exact byte-identical duplicates** across the entire tree. This rules out a simple `fdupes`-style content dedup as the cleanup mechanism — Bridge appears to inject copy-specific artifacts (e.g. a distinct `X-Pm-Gluon-Id:` per served copy, observed directly in sampled draft files) even when re-serving what is logically the same message through a different virtual mailbox/UID. A separate Message-ID-based scan found only ~650 exact Message-ID repeats out of 43,659 messages with a `Message-Id:` header — i.e. most `.Labels.Important` content is *not* trivially duplicated elsewhere in today's tree by Message-ID either; the operational problem is that `.Labels.Important` mirrors most of the account's history into a folder the user never actually reads via aerc/notmuch (pure bloat + reconcile risk), not that today's disk holds obvious identical-content pairs everywhere.

### 4. The `.Labels.*` folders: Gmail/Proton labels-over-IMAP mechanism

ProtonMail Bridge (like Gmail) exposes **labels** as separate virtual IMAP mailboxes distinct from **folders**: a folder is exclusive (a message lives in exactly one), while a label is additive (a message can carry zero or more simultaneously, and Bridge lists it under every label mailbox it carries, in addition to whatever folder it's filed under). `logos-labels`'s `Patterns "Labels/*"` with `Create Both`/`Expunge Both` mirrors every one of these label-mailboxes as an independent local Maildir++ folder — so any message with, e.g., both "Important" and "Letters" labels while also sitting in Archive ends up with **three** local copies: `.Archive`, `.Labels.Important`, `.Labels.Letters`. `logos-folders` (`Patterns "Folders/*"`) is architecturally safe by contrast — Proton "Folders" (as opposed to "Labels") are exclusive, so mirroring them does not duplicate content; it currently has zero synced files simply because no custom Folders exist in this account yet.

**Answer to the research question "should `.Labels.*` be excluded from the logos mbsync channels?": yes.** The existing `mbsync.nix` file already has established precedent for exactly this kind of exclusion — `gmail-trash`/`gmail-spam` are defined as channels but deliberately kept **out of** `Group gmail` (with an explanatory comment) because including them broke the whole-group reconcile. The same pattern should apply to `logos-labels` (and, out of caution, `logos-folders` should stay in the group only if it is confirmed exclusive/non-duplicating — current evidence supports keeping it, since it holds 0 files and Proton Folders are structurally exclusive).

### 5. The dotted-folder crash on `.Labels.benbrastmckie@gmail.com`

Maildir++ uses `.` as the folder-hierarchy separator when flattening a remote path into a single local directory name (e.g. remote `Labels/Important` -> local `.Labels.Important`). A label whose own leaf name contains a literal `.` — here, `benbrastmckie@gmail.com` (the `.` inside `gmail.com`) — cannot be flattened unambiguously: mbsync/Dovecot-style Maildir++ tooling has no escaping convention for a literal dot inside a single path segment, so the resulting name `.Labels.benbrastmckie@gmail.com` is indistinguishable from a *three*-level hierarchy `Labels` -> `benbrastmckie@gmail` -> `com`. This is a known class of Maildir++ interoperability failure with Gmail-imported label names (Gmail's Easy-Switch/label-import machinery routinely creates labels named after source email addresses, e.g. tagging mail by its original Gmail account). The practical result observed here: **no local directory was ever created** for this label — mbsync aborted that specific mailbox's sync rather than silently mis-nesting it, and (per the task's own report) this contributes to the overall `mbsync logos` reconcile exiting non-zero.

Since this problem is scoped entirely to a `Labels/*` mailbox, removing `logos-labels` from `Group logos` (§4's fix) resolves it as a direct side effect — no separate `Patterns` exclusion is needed once the whole Labels channel is out of the routine group.

### 6. The draft/test message with a missing Date header

No draft under `~/Mail/Logos/.Drafts/{cur,new}` is missing a `Date:` header (all 8 `.Drafts/new` + `.Drafts/cur` files checked directly have well-formed `Date:` lines, including genuine Bridge-imported test drafts from 2025-07-14 with `X-Pm-*` headers). The actual offending message is in **`.Sent`**, not Drafts:

```
~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S

From: Benjamin Brast-McKie <benjamin@logos-labs.ai>
To: benbrastmckie@gmail.com
Cc:
Bcc:
Subject: FROM LOGOS

TEST
```

No `Date:`, `Message-Id:`, `MIME-Version:`, or `Content-Type:` header; CRLF line endings; body is literally `TEST`. The Dovecot-style unique-ID filename (`#1M604459477P4171775V66306I26262783`) is structurally different from every other Bridge-synced file in this account (which use the Gluon-origin `hamsa,` pattern), strongly suggesting this file was deposited directly into the local Maildir by a test/development script rather than downloaded from Bridge. Because `.Sent` is bidirectionally synced (`Create Both`, `Expunge Both`), mbsync will attempt to `APPEND` this local-only file to the Proton server on the next `logos-sent` reconcile — and a message lacking a `Date:` header is liable to fail IMAP `APPEND`/`internaldate` validation on the far side, contributing to the non-zero exit.

## Recommendations

### A. `mbsync.nix` fix (primary, in `~/.dotfiles`)

Remove `Channel logos-labels` from `Group logos`, following the exact precedent already established for `gmail-trash`/`gmail-spam`: keep the channel *definition* (for optional manual/inspection use — e.g. an operator explicitly running `mbsync logos-labels` to inspect what's under a label without polluting the routine group reconcile), but drop it from the `Group logos` channel list, with a comment explaining why (labels are additive Bridge/Proton metadata, not exclusive folders; including them in the group duplicates every labeled message and previously crashed the whole-group reconcile on a dotted label name).

```
    # logos-labels is intentionally NOT a member of Group logos below (see comment there):
    # ProtonMail Bridge exposes Labels as additive, non-exclusive virtual mailboxes (Gmail-style),
    # so mirroring "Labels/*" as local folders duplicates every labeled message into a SECOND
    # local copy on top of its real folder (INBOX/Archive/Trash/Sent), and one such label
    # ("benbrastmckie@gmail.com", imported from a prior Gmail Easy-Switch label) contains a
    # literal "." in its name that collides with Maildir++'s "." hierarchy separator and made
    # the whole `mbsync logos` group reconcile exit 1. Kept for optional manual/inspection use
    # only: `mbsync logos-labels`.
    Channel logos-labels
    ...

    Group logos
    Channel logos-inbox
    Channel logos-sent
    Channel logos-drafts
    Channel logos-trash
    Channel logos-archive
    Channel logos-folders
    # logos-labels intentionally omitted -- see channel definition comment above.
```

`logos-folders` can remain in `Group logos`: Proton "Folders" (distinct from "Labels") are exclusive, currently sync zero files, and no evidence in this investigation suggests they duplicate content. Recommend a follow-up spot-check the first time any custom Folder is actually created in this Proton account, to confirm that assumption holds in practice.

### B. Duplicate-UID repair for `.Trash`/`.Archive` (separate fix, needed before Trash pushes can succeed)

This is a pre-existing state-file corruption from the original 2026-02-09 import, unrelated to the Labels-channel fix above, and must be resolved before the 161 staged Trash deletes can reach the server:

1. **Freeze first** (`email-freeze`, already provided) to guarantee no mbsync process runs during cleanup, and to snapshot `.mbsyncstate*` for rollback.
2. For each duplicate `U=NNN` pair in `.Trash/cur` (860 pairs) and `.Archive/cur` (2 pairs): since content is *not* byte-identical (Bridge injects copy-specific artifacts — see §3), dedup must be done by **Message-ID**, not checksum. For each pair, keep the file whose Message-ID/content is confirmed to still exist server-side (or, for Trash specifically, keep whichever copy carries the flags matching the current desired local state — e.g. the one already flagged deleted/trashed by the recent cleanup) and remove the other.
3. After de-duplicating the physical files so each UID maps to exactly one file, the `.mbsyncstate`/`.uidvalidity` for `.Trash` and `.Archive` almost certainly still needs to be regenerated (the existing state file's UID bookkeeping is the thing that's corrupted, not just the files) — the standard isync recovery is to back up and clear the channel's `.mbsyncstate`/`.uidvalidity` for just those two folders and let mbsync rebuild Near-side state from a fresh `Create Near`/matching pass, rather than resetting the whole `logos` account's state.
4. Only after (1)-(3) succeed should `mbsync logos` (group-scoped, never `-a`) be re-run to push the 161 staged Trash deletes.

This entire sequence is a **mutating operation** and is explicitly out of scope for this research task; it is recorded here as the concrete plan for a follow-up implementation task.

### C. Dotted-folder crash

No separate fix needed beyond (A) — removing `logos-labels` from `Group logos` removes the only code path that touches `Labels/benbrastmckie@gmail.com`. If label sync is ever wanted again for other (non-dotted) labels, add an explicit `Patterns` exclusion for this specific label name (e.g. `Patterns "Labels/*" !"Labels/benbrastmckie@gmail.com"`) rather than re-including the whole pattern unfiltered.

### D. Missing-Date test message

Recommend deleting `~/Mail/Logos/.Sent/cur/1771019138.#1M604459477P4171775V66306I26262783.hamsa,U=12:2,S` outright rather than synthesizing a `Date:` header — its content (`Subject: FROM LOGOS` / body `TEST`) and non-Bridge filename pattern indicate development-test scaffolding with no correspondence value. If there is any doubt about provenance, back it up (e.g. via `email-freeze`-style tarball) before removal. This, too, is a mutating operation left for the follow-up implementation task.

## Maildir De-duplication / Cleanup Plan (for the implementation task)

1. **Freeze** (`email-freeze`) before touching anything.
2. **Config change first** (Recommendation A) so no further Labels-channel bloat accumulates during cleanup — commit this in `~/.dotfiles` before doing any maildir surgery.
3. **Decide the fate of `.Labels.Important`/`.Labels.Letters`/`.Labels.EuroTrip`/`.Labels.CrazyTown` content** (37,540 + 488 + 8 + 5 = 38,041 files): since these are near-total mirrors of content that (mostly) already exists in canonical folders, and the config fix stops further growth, the simplest safe cleanup is to leave the existing label-mirror files in place initially (no data loss risk) and let a follow-up task decide whether to bulk-delete `.Labels.Important`/`.Labels.Letters`/etc. entirely (since Group logos will no longer resync them, they're now static/orphaned local copies) — or leave them as an inert local archive. Recommend bulk deletion once a spot-check confirms every message that matters is reachable via INBOX/Archive/Sent/Drafts/Trash.
4. **Fix `.Trash`/`.Archive` duplicate UIDs** per Recommendation B (Message-ID-based, not checksum-based, since content is not byte-identical).
5. **Remove or archive the headerless test message** in `.Sent` per Recommendation D.
6. **Reconcile**: run `mbsync logos` (group-scoped) once steps 2-5 are complete, to push the 161 staged Trash deletes and confirm a clean (exit 0) reconcile.
7. **Reindex**: `notmuch new --no-hooks` (the sanctioned reindex path per `email-reindex`, task 824) to bring the notmuch index current with the cleaned-up maildir. Given the notmuch path:/folder: query inconsistencies observed during this research (§ caveat above), a full index consistency check is recommended after reconcile, cross-referencing with whatever staleness-detection work lands from tasks 823/824/827.

## Decisions Made (during research)

- Treated `find`/`ls`/`md5sum`-derived filesystem counts as ground truth over notmuch query results, after observing notmuch `path:`/`folder:` queries return results inconsistent with direct filesystem enumeration (see caveat, and sibling tasks 823/824/827).
- Diagnosed the `.Trash`/`.Archive` duplicate-UID problem as a *separate, older* defect (2026-02-09 origin) from the Labels-channel bloat (2026-07-04 origin), based on file mtime evidence, rather than treating all symptoms as one root cause.
- Identified the specific offending draft/test message by full-maildir header scan rather than assuming it was still in `.Drafts` as literally stated in the task description (all current Drafts have valid Date headers); found it in `.Sent` instead.

## Risks & Mitigations

- **Risk**: bulk-deleting `.Labels.Important` content without confirming it's fully redundant could lose data if some messages exist *only* under a label with no canonical-folder copy. **Mitigation**: the cleanup plan (step 3) recommends a spot-check/dry-run reconciliation against INBOX/Archive/Sent/Drafts/Trash before any bulk deletion, and treats leaving the files in place (inert, since the channel is removed from the group) as an acceptable interim state.
- **Risk**: resetting `.mbsyncstate`/`.uidvalidity` for `.Trash`/`.Archive` could cause mbsync to re-download or re-push unexpected state if done incorrectly. **Mitigation**: `email-freeze` backup first; scope the state reset narrowly to only the two affected folders, not the whole `logos` account.
- **Risk**: this report's notmuch-derived caveats overlap with sibling tasks 823/824/827's staleness-detection work; a future implementer should cross-check for redundant effort. **Mitigation**: explicitly cross-referenced above; the cleanup plan's step 7 defers to whatever staleness tooling lands from those tasks.

## Appendix: Key Commands Used

```bash
# Config inspection
cat ~/.dotfiles/modules/home/email/{mbsync.nix,notmuch.nix,protonmail.nix}
cd ~/.dotfiles && git log --oneline --follow -- modules/home/email/mbsync.nix
git show b7e719a -- modules/home/email/mbsync.nix

# Maildir physical state (ground truth)
find ~/Mail/Logos -maxdepth 1 -type d
shopt -s dotglob; for d in ~/Mail/Logos/*/; do find "$d" -maxdepth 2 -type f \( -path "*/cur/*" -o -path "*/new/*" \) | wc -l; done
find ~/Mail/Logos -type f \( -path "*/cur/*" -o -path "*/new/*" \) -printf '%TY-%Tm-%Td\n' | sort | uniq -c

# .mbsyncstate inspection
find ~/Mail/Logos -maxdepth 2 -iname ".mbsyncstate*"
head -5 ~/Mail/Logos/.Labels.Important/.mbsyncstate

# Duplicate-UID detection
ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -c | awk '$1>1'

# Content-duplication check (found zero exact duplicates)
find ~/Mail/Logos -type f \( -path "*/cur/*" -o -path "*/new/*" \) -print0 | xargs -0 md5sum | awk '{print $1}' | sort -u | wc -l

# Missing Date-header scan
find ~/Mail/Logos -type f \( -path "*/cur/*" -o -path "*/new/*" \) -print0 | xargs -0 -P4 -I{} sh -c 'grep -qi "^Date:" "{}" || echo "MISSING: {}"'
```

No `mbsync`, `notmuch new`, or `notmuch tag` command was executed at any point in this investigation.
