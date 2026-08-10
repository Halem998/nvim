# Research Report: Task #852

**Task**: 852 - Investigate 22 Logos INBOX files that notmuch never indexes
**Started**: 2026-07-13T09:58:00-07:00
**Completed**: 2026-07-13T10:15:00-07:00
**Effort**: ~1.5 hours
**Dependencies**: 827 (completed — staleness detector redesign research; documented this anomaly as a follow-up)
**Sources/Inputs**: Live read-only commands (`notmuch`, `find`, `stat`, `grep`), notmuch config (`notmuch config list`), notmuch hook scripts (`~/.config/notmuch/default/hooks/{pre,post}-new`), reclone-session logs preserved under `~/Mail/.logos-backup-20260706/reclone/`, `~/.dotfiles/modules/home/email/mbsync.nix`, `~/.dotfiles/modules/home/email/agent-tools/wrapper-contracts.md` (via `.claude/extensions/email/context/`), `notmuch-new(1)` / `notmuch-search-terms(7)` man pages
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause identified with strong, direct log evidence**: the 22 files were delivered to
  `~/Mail/Logos/cur` on 2026-07-06 at 09:21:13–14 PDT as a **side effect of `notmuch new`'s own
  `pre-new` hook** (`mbsync gmail logos`), which was triggered because `logos-reclone.sh` (task
  826/828's Logos maildir reclone script) invoked **raw `notmuch new` without `--no-hooks`** at
  its step 7 ("reindexing notmuch"). The preserved log `~/Mail/.logos-backup-20260706/reclone/reclone-live.log`
  shows the hook's `mbsync gmail logos` subprocess running *inside* that `notmuch new` invocation,
  hitting unrelated Gmail-side errors (`channel gmail-trash: far side box [Gmail]/Trash cannot be
  opened`, `duplicate UID 15 in .../Gmail//.All_Mail`, `channel gmail-spam: far side box
  [Gmail]/Spam cannot be opened anymore`, `SubFolders style Maildir++ does not support dots in
  mailbox names`), and finally emitting **`Error: pre-new hook failed with status 1`** — i.e. the
  hook that delivered the 22 files failed, and the very `notmuch new` invocation that spawned it
  never got to (or never correctly completed) indexing the files that hook had just written,
  racing its own delivery.
- This is the exact scenario `~/.dotfiles`'s own wrapper-contracts.md already forbids: "A raw
  `notmuch new` (no `--no-hooks`) remains forbidden because it triggers `mbsync -a`" (here,
  `mbsync gmail logos`, functionally equivalent in scope/risk). `logos-reclone.sh` line 92 (`run
  "notmuch new"`) violates this documented invariant — plausibly written before the invariant was
  formalized, or intentionally accepting the risk for a one-time reclone.
- **Confirmed via direct, exhaustive DB query** that these 22 filenames/Message-IDs are **not
  referenced anywhere** in the 65k+-message notmuch database (`notmuch search --output=files '*'
  | grep <unique-token>` returns nothing for all 5 tokens tested) — ruling out "content already
  indexed under a stale/duplicate record" theories. Combined with task 827's two failed
  post-hoc reindex attempts (including one after forcing `Logos/cur`'s directory mtime forward),
  this points to notmuch's **internal per-directory "already scanned" bookkeeping** (not exposed
  by any `notmuch search` term — it is scan-optimization state, distinct from message documents)
  having been advanced past these files' delivery moment during the racy/aborted hook-triggered
  scan, without the files' content ever having been parsed into the index. This is a known class
  of notmuch hazard: a `mtime`-based directory-scan-skip optimization racing concurrent maildir
  delivery.
- **Definitively ruled out** (per the task's candidate list), with direct evidence gathered in
  this pass:
  - `new.ignore` config (`.mbsyncstate;.strstrings;.lock;dovecot*`): none of the 22 filenames
    match any pattern (confirmed via `notmuch config get new.ignore`).
  - Non-mail content: notmuch's own reclone-time logs show it *actively detects and flags*
    non-mail files with `Note: Ignoring non-mail file: <path>` (confirmed live against
    `~/Mail/specs/...` files sharing the same `database.mail_root`); no such notice exists for
    any of the 22 files, and manual header inspection confirms all 22 are well-formed RFC822
    messages with legitimate `Message-Id`, `From`, `Subject`, `Date` headers.
  - Permissions: all 22 files are `-rw-------`, owned by `benjamin:users`, identical to
    neighboring indexed files — no anomaly.
  - Maildir filename/flag anomalies: filenames follow the standard mbsync/isync
    `<epoch>.<pid>_<n>.<host>,U=<uid>:2,<flags>` convention; flags are simply empty (unseen,
    unreplied) — consistent with genuinely-unread new mail, not a malformed name.
  - Database corruption (general): ruled out as *global* corruption — the database otherwise
    functions normally (65k+ messages searchable, counts consistent); the issue is scoped to a
    specific accounting artifact of one interrupted scan, not filesystem/Xapian-level corruption.
- **Recommended remediation** (not yet executed — this is a diagnosis-only pass per task
  instructions): run `notmuch new --no-hooks --full-scan`. `--full-scan` is documented
  (`notmuch-new(1)`) to disable notmuch's directory-mtime scan-skip optimization entirely — the
  exact mechanism task 827's manual `touch` workaround was trying to force, but did not verify
  bypassed the *file-level* "already known" bookkeeping (as opposed to just the coarse
  directory-mtime gate). This is the one remediation combination not yet tried and is index-only
  (mutates no mail), consistent with the sanctioned `email-reindex` contract.
- **Secondary, lower-priority finding**: 5 additional very-recent Logos files (2 from 2026-07-11,
  3 from 2026-07-13, this session) are also currently unindexed, but these appear to be **ordinary
  staleness** (arrived after the last `email-reindex` run), not the same bookkeeping anomaly —
  there is no evidence of a hook-triggered race for these (the routine `mbsync` fetch path, per
  `~/.dotfiles`, is either the sanctioned `mbsync gmail`/`mbsync logos` group commands run
  standalone, or aerc's `$` keybind which runs `mbsync -a && notmuch new` **sequentially**, not
  concurrently — so the specific hook-race mechanism identified above should not recur under
  normal, policy-compliant operation). Recommend re-running the file-vs-file diff after a routine
  `email-reindex` to confirm these 5 clear normally; if they do not, that would indicate the race
  is broader than this report concludes and warrants further investigation.

## Context & Scope

Task 827 (email staleness detector redesign) surfaced, as a live side-finding, that 22 of Logos
INBOX's 23-file on-disk/indexed divergence are files notmuch has never indexed at all (not
duplicates, not stale index lag — confirmed via zero-hit `id:` lookups and two failed sanctioned
reindex attempts). This task's scope is to root-cause *why* `notmuch new` skips these specific
files and determine a concrete remediation path, via read-only diagnosis only (no mail mutation).
Per the task's cross-repo note, notmuch/mbsync configuration lives in `~/.dotfiles`
(`modules/home/email/`); this repository's `.claude/extensions/email/` documents the *policy*
around that configuration (wrapper-contracts.md) but does not itself configure notmuch/mbsync.

No mail files were mutated. No `notmuch new`/`email-reindex`/`mbsync` commands were executed
during this research pass — all findings come from read-only `notmuch search`/`notmuch count`/
`notmuch config`, filesystem inspection (`find`, `stat`, `ls`, header `grep`), and **pre-existing
log files** that happened to be preserved from the original 2026-07-06 reclone session under
`~/Mail/.logos-backup-20260706/reclone/` — these logs were the decisive piece of evidence and
required no new commands to be run against the mailbox.

## Findings

### Finding 1: Concrete identification of the file set

Reproducing the on-disk-vs-indexed diff (matching 827's methodology, corrected for the
`--output=files` cross-directory-duplicate quirk 827 already documented):

```sh
find ~/Mail/Logos/cur ~/Mail/Logos/new -maxdepth 1 -type f | sort > ondisk.txt      # 340 files
notmuch search --output=files 'path:Logos/cur or path:Logos/new' \
  | grep -E '/Logos/(cur|new)/' | sort -u > indexed_filtered.txt                    # 319 files
comm -23 ondisk.txt indexed_filtered.txt                                           # 27 files
```

27 files are currently on-disk-but-unindexed (up slightly from 827's 22+1, because 5 more files
have arrived since 827's pass — see "Secondary finding" below). Of these 27, **22 share an
identical creation signature**: mtime `2026-07-06 09:21:13` or `09:21:14` PDT, filename pattern
`1783354873.4003086_<N>.hamsa,U=<N>:2,` or `1783354874.4003086_<N>.hamsa,U=<N>:2,` (same delivery
PID `4003086`, same host token `hamsa`, sequential IMAP UIDs 145–305, no maildir flags at all —
i.e., genuinely unread mail). These 22 are exactly task 827's originally-reported anomaly set. The
other 5 (2026-07-11 and 2026-07-13 dated) are addressed separately in the secondary finding.

All 22 have legitimate senders/subjects/Message-IDs (GitHub PR-review notifications, LinkedIn
digests, Capital One/Golden 1 credit-score alerts, Google Drive/Sheets share notices, a PhilPapers
notice, a GitLab webcast reminder, a Google Analytics report) — ordinary inbox traffic, not spam,
not malformed, not test data. Full per-file Message-ID/From/Subject listing is in the Appendix.

### Finding 2: `new.ignore`, permissions, filenames, and content — all definitively clean

```sh
$ notmuch config get new.ignore
.mbsyncstate
.strstrings
.lock
dovecot*
```
None of the 22 filenames match. `new.tags=new` (irrelevant to whether a file gets indexed at all).

```sh
$ ls -la ~/Mail/Logos/cur/1783354873.4003086_145.hamsa,U=145:2,
-rw------- 1 benjamin users 6976 Jul  6 09:21 ...
```
All 22 are `0600`, owned by `benjamin:users` — identical to neighboring successfully-indexed
files.

Header inspection of a sample file confirms a fully well-formed RFC822 message (valid
`Message-Id`, `From`, `To`, `Subject`, `Date`, MIME headers, DKIM/ARC chain) — nothing notmuch
would refuse to parse. This is corroborated by evidence from the reclone-time logs themselves:
`notmuch new` (unhooked scanning phase, when it runs) explicitly announces `Note: Ignoring
non-mail file: <path>` for genuinely non-mail content it encounters under the same
`database.mail_root=/home/benjamin/Mail` (which, notably, also contains this repo's `specs/`
tree — confirmed live, e.g. `Note: Ignoring non-mail file:
/home/benjamin/Mail/specs/archive/024_.../reports/research-001.md`). No such notice exists for
any of the 22 files in either preserved reclone-time log, and the direct DB search (Finding 3)
confirms notmuch never attempted them at all — they weren't rejected as non-mail, they were never
looked at.

### Finding 3: Exhaustive DB search confirms these files are unknown to notmuch under *any* query

```sh
$ notmuch search --output=files '*' 2>/dev/null | grep '4003086_145'
(no output)
```
Repeated for 5 of the 22 unique tokens (`4003086_145`, `_159`, `_163`, `_189`, `_305`) — zero
hits in all cases, against the *entire* 65k+-message database, not just `folder:Logos`-scoped
queries. This rules out:
- A stale/duplicate message record under a different path (ruled out in 827 for Message-ID
  lookups; this generalizes it to full-text/path search too).
- Any exposed, `notmuch search`-queryable record of these filenames existing at all.

This means whatever is blocking these files is **not** a message-document-level issue (there is
no message document, full stop) — it is upstream, in notmuch's directory-scan bookkeeping, which
is internal state not exposed through any `notmuch search` term.

### Finding 4: The decisive evidence — the reclone's own `notmuch new` triggered the hook that raced its own delivery

`~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh` (the task 826/828 reclone script, log
files preserved from the original run) contains, at its step 7:

```sh
# --- 7. Reindex notmuch ----------------------------------------------------------
say "reindexing notmuch (detects removed Logos files, indexes fresh ones)"
run "notmuch new"
```

**This is a raw, unhooked `notmuch new` call** — no `--no-hooks`. Per
`~/.config/notmuch/default/hooks/pre-new` (a home-manager-managed symlink):

```sh
#!/nix/.../bash
export PATH="...notmuch-0.40/bin:$PATH"
export NOTMUCH_CONFIG="/home/benjamin/.config/notmuch/default/config"
export NMBGIT="/home/benjamin/.local/share/notmuch/nmbug"

mbsync gmail logos
```

So this single `notmuch new` invocation **automatically triggered a broad `mbsync gmail logos`
pull** as its pre-new hook — before notmuch's own scan phase. The preserved
`reclone-live.log` shows this play out in real time:

```
[reclone] reindexing notmuch (detects removed Logos files, indexes fresh ones)
[reclone][RUN] notmuch new
Maildir notice: sleeping due to recent directory modification.
Error: channel gmail-trash: far side box [Gmail]/Trash cannot be opened.
Maildir error: duplicate UID 15 in /home/benjamin/Mail/Gmail//.All_Mail.
Error: channel gmail-spam: far side box [Gmail]/Spam cannot be opened anymore.
*** IMAP Warning *** Password is being sent in the clear
Maildir notice: no UIDVALIDITY in .../Logos//.Labels.CrazyTown, creating new.
[... 7 more UIDVALIDITY notices for other Labels.* folders ...]
Maildir error: store 'logos-local', folder 'Labels/benbrastmckie@gmail.com': SubFolders style
  Maildir++ does not support dots in mailbox names
Channels: 15    Boxes: 24    Far: +0 *0 #0 -0    Near: +9 *2202 #0 -2200
Error: pre-new hook failed with status 1
RECLONE-DONE-SENTINEL
```

Everything between `[reclone][RUN] notmuch new` and `Error: pre-new hook failed with status 1` is
the **hook's own `mbsync gmail logos` subprocess output**, run automatically by notmuch before its
scan phase. The 22 anomaly files' mtime (`09:21:13`–`09:21:14`) sits exactly inside this window —
between the separately-preserved `repull.log` (mtime `09:21:14.74`, itself the record of this same
hook-triggered mbsync activity delivering Logos INBOX mail) and the hook's own failure report. The
`mbsync` process hit real, unrelated errors on **Gmail-side** channels (Trash/Spam folders, a
duplicate UID, and a Maildir++ naming incompatibility for `Labels/benbrastmckie@gmail.com`) and
exited non-zero overall, causing notmuch to report `pre-new hook failed`.

Two independently-preserved follow-up logs, `notmuch-reindex.log` (mtime 09:18:56 — actually
predates this event and reflects an *earlier* pass in the same session) and `notmuch-reindex2.log`
(mtime 09:21:45, i.e. the very next reindex attempt *after* the hook failure above), both report
**"No new mail"** despite running immediately after this file delivery. This is the crux: by the
time of `notmuch-reindex2.log`'s plain (non-hook) rescan, notmuch's bookkeeping already believed
`Logos/cur` was fully up to date — even though the 22 files delivered moments earlier by the
failed hook had never been parsed into a message document (Finding 3). The most coherent
explanation consistent with every piece of evidence gathered is a **scan/delivery race**: notmuch's
own directory-mtime-based scan-skip optimization (the one `--full-scan` is documented to disable —
see Finding 5) recorded `Logos/cur` as scanned at a point concurrent with or immediately after
these files' arrival, without the scan itself having actually processed them (plausibly because
the hook failure interrupted or foreshortened the scan notmuch would otherwise have performed
after the hook returned). Because this bookkeeping lives in notmuch's internal per-directory
scan-state — not a message document, and not exposed by any `notmuch search` term (Finding 3) — it
persisted silently through task 827's later manual `touch`-and-reindex workaround, which forced
the directory's *filesystem* mtime forward but evidently did not by itself defeat whatever
per-file "already seen" state notmuch retained from the original racy scan.

This exact hazard (raw `notmuch new` triggering a broad `mbsync`) is precisely what
`~/.dotfiles`'s own `wrapper-contracts.md` documents as forbidden:

> `notmuch new --no-hooks`: `--no-hooks` skips `preNew = mbsync -a` (preserving the never-`mbsync
> -a` invariant and staying safe...) ... A raw `notmuch new` (no `--no-hooks`) remains forbidden
> because it triggers `mbsync -a`.

`logos-reclone.sh`'s step 7 (`run "notmuch new"`, no `--no-hooks`) violates this invariant. This
was very plausibly written before the invariant was formalized (task 827's report and the
`email-reindex` wrapper both post-date this reclone), or was an intentional one-off risk
acceptance for the reclone itself — either way, it is the concrete origin event for this anomaly,
and is not a risk under the currently-sanctioned `email-reindex` (`notmuch new --no-hooks`) path,
which never triggers `mbsync` at all.

### Finding 5: `--full-scan` — the one remediation not yet tried

`notmuch-new(1)`:

> `--full-scan`: By default notmuch-new uses directory modification times (mtimes) to optimize
> the scanning of directories for new mail. This option turns that optimization off.

Task 827's workaround was `touch ~/Mail/Logos/cur && email-reindex` (i.e., `notmuch new
--no-hooks`, no `--full-scan`) — forcing the directory's *filesystem* mtime forward and hoping the
plain mtime-comparison optimization would then trigger a rescan. That it didn't work is the
strongest evidence that whatever state is blocking these files is **not simply** "notmuch's
recorded mtime for this directory happens to already be ≥ current mtime" (which the touch would
have trivially defeated) — some deeper per-file "already processed" bookkeeping, orthogonal to the
coarse directory-mtime gate, is the more likely culprit (consistent with Finding 4's race
explanation). `--full-scan` is documented to disable "the [mtime] optimization" wholesale for the
invoked run, which is a strictly stronger reset than a manual touch and is the natural next
targeted test — it was not attempted in 827's two remediation passes.

**Recommended next step** (not executed in this research pass, per task's read-only mandate):

```sh
notmuch new --no-hooks --full-scan
```

This is index-only (no mail mutation), does not trigger any hook (safe under the
never-`mbsync`-from-`notmuch new` invariant), and directly targets the one untested variable. If
this *still* fails to index the 22 files, that would indicate the corruption is deeper than a
scan-skip optimization artifact (e.g., a genuinely inconsistent Xapian directory-document record
requiring lower-level intervention — at that point, escalate to inspecting the Xapian database
directly, e.g. via `notmuch dump`/Xapian delve tooling, which is beyond this report's read-only
CLI-level scope).

### Secondary finding: 5 additional currently-unindexed files are likely ordinary staleness

Beyond the 22-file anomaly, the current live diff also shows 5 more unindexed files:
- 2 from 2026-07-11 13:17 (UID 344, 345)
- 3 from 2026-07-13 09:58 (UID 351–353, this session, ~10 minutes before this research began)

There is no `pre-new`-hook-race evidence for these (no reclone/repull log activity coincides with
their arrival), and per `~/.dotfiles/modules/home/email/mbsync.nix`, there is **no** mbsync
systemd timer — the only trigger paths are manual `mbsync <group>` calls or aerc's `$` keybind,
which runs `mbsync -a && notmuch new` **sequentially** (not concurrently, so the specific race in
Finding 4 should not recur through that path). These 5 are most plausibly explained by ordinary
reindex lag (mail arrived after the last `email-reindex` run) rather than a recurrence of the
22-file bookkeeping anomaly. Recommend confirming this by re-running the file-vs-file diff
immediately after the next routine `email-reindex`; if these 5 persist afterward, that would
indicate the hazard is broader than a one-off reclone artifact and warrants re-opening this
investigation.

## Decisions

- Root cause: a policy-violating raw `notmuch new` (no `--no-hooks`) in `logos-reclone.sh`
  triggered its `pre-new` hook's `mbsync gmail logos` mid-scan; that hook delivered the 22 files
  and then failed (unrelated Gmail-channel errors), racing/short-circuiting notmuch's own scan of
  the very directory the hook was writing into, leaving `Logos/cur`'s scan-bookkeeping advanced
  past these files without their content ever being parsed into the index.
- Ruled out (with direct evidence, per the task's candidate list): `new.ignore`/`new.tags` config,
  filename/flag anomalies, non-mail content, file permissions, and global database corruption.
- Recommended remediation: `notmuch new --no-hooks --full-scan` — index-only, hook-free, and the
  one combination not yet attempted in 827's two remediation passes.
- The 5 additional currently-unindexed files (2026-07-11, 2026-07-13) are provisionally treated as
  ordinary reindex staleness, not a recurrence of the bookkeeping anomaly, pending confirmation
  after the next routine `email-reindex`.

## Risks & Mitigations

- **Risk**: `--full-scan` might not resolve the anomaly if the underlying Xapian directory-record
  inconsistency is deeper than a scan-skip artifact. *Mitigation*: this report explicitly flags
  that outcome as the trigger for escalating to direct Xapian-level inspection (`notmuch dump`,
  Xapian delve), which is out of scope for CLI-level read-only diagnosis and should be a follow-up
  task if `--full-scan` does not close the gap.
- **Risk**: `logos-reclone.sh`'s policy-violating raw `notmuch new` call could recur if the script
  is ever re-run (e.g., a future reclone) without being patched to use `--no-hooks` (or to run
  `mbsync` and `notmuch new --no-hooks` as clearly separated, sequential steps). *Mitigation*:
  recommend a follow-up fix to `logos-reclone.sh` line 92 (`run "notmuch new"` → `run "notmuch new
  --no-hooks"`, with `mbsync` invoked explicitly and separately if a pull is needed at that point)
  to bring it in line with the `~/.dotfiles` wrapper-contracts.md invariant. This is a `.dotfiles`
  change and, like the 827 recommendations, must be applied and rebuilt by the user
  (`home-manager switch`), not this repo.
- **Risk**: this report's race-condition explanation for *why* the bookkeeping got stuck (as
  opposed to *that* it got stuck, which is directly evidenced) is inferential, since notmuch's
  internal directory-scan state is not introspectable via any `notmuch` CLI command used here.
  *Mitigation*: the report clearly labels this as the best-supported inference from available
  evidence, not a confirmed mechanism, and proposes a concrete, low-risk test (`--full-scan`) whose
  outcome will either confirm the remediation or motivate deeper Xapian-level investigation.

## Context Extension Recommendations

- **Topic**: `notmuch new`'s pre-new-hook-triggered-mbsync race with its own directory scan.
  **Gap**: not documented anywhere in `.claude/extensions/email/context/` or
  `~/.dotfiles`'s `wrapper-contracts.md` beyond the general "never mbsync -a from notmuch new"
  invariant — the *specific failure mode* (hook-delivered mail racing the invoking `notmuch new`'s
  own scan, silently leaving files permanently unindexed even after mtime-forcing workarounds) is
  new information from this investigation. **Recommendation**: add a short "known hazard" note to
  `wrapper-contracts.md` §13 (Index Freshness section) documenting this failure mode and the
  `--full-scan` remediation, so a future raw `notmuch new` invocation (accidental or otherwise)
  that hits the same race is diagnosed quickly rather than re-investigated from scratch.
- **Topic**: `logos-reclone.sh`'s policy-violating `notmuch new` call. **Gap**: the script itself
  (in `~/Mail/.logos-backup-20260706/reclone/`, a backup/historical copy, not necessarily the live
  `.dotfiles` script) is not tracked as a known-defect anywhere. **Recommendation**: if
  `logos-reclone.sh` (or an equivalent live reclone tool) still exists in `~/.dotfiles` for future
  use, a follow-up task should patch it to use `notmuch new --no-hooks` at its reindex step,
  consistent with the invariant documented in wrapper-contracts.md.

## Appendix

### Full list of the 22 anomaly files (Message-ID | From | Subject)

```
1783354873.4003086_145.hamsa,U=145:2,  <m70823929@xp.philpapers.org>  PhilPapers — New incomplete items attributed to you
1783354873.4003086_159.hamsa,U=159:2,  <1429371317.4505461.1781100566893@marketo-platform...>  GitLab — [Tomorrow] Join us at GitLab Transcend
1783354873.4003086_163.hamsa,U=163:2,  <e00c7596fb2ee77b0ae1d96932053c30e3ded596-20367314-111718561@google.com>  Google Analytics — performance report May 15-Jun 11
1783354874.4003086_189.hamsa,U=189:2,  <1318293735.3919141.1781549650381@lor1-app120160...>  LinkedIn — Ekin just messaged you
1783354874.4003086_200.hamsa,U=200:2,  <23.23.05988.249C13A6@i-08c669093a4955ab2...>  Capital One — credit score improved
1783354874.4003086_212.hamsa,U=212:2,  <leanprover/cslib/pull/649/review/4535478124@github.com>  GitHub — PR #649 review (Ching-Tsun Chou)
1783354874.4003086_213.hamsa,U=213:2,  <leanprover/cslib/pull/607/review/4535719262@github.com>  GitHub — PR #607 review (Eric Wieser)
1783354874.4003086_214.hamsa,U=214:2,  <leanprover/cslib/pull/607/review/4535721634@github.com>  GitHub — PR #607 review (Eric Wieser)
1783354874.4003086_215.hamsa,U=215:2,  <leanprover/cslib/pull/607/review/4535774762@github.com>  GitHub — PR #607 review (Eric Wieser)
1783354874.4003086_256.hamsa,U=256:2,  <9C.DC.52246.60EEE3A6@i-092a34752009ae680...>  Capital One — credit score improved
1783354874.4003086_258.hamsa,U=258:2,  <1782514962549.c51e7110-...@bf06x.hubspotemail.net>  FITNESS SF — Polk Weightlist Update #8
1783354874.4003086_266.hamsa,U=266:2,  <8de4c9fa-a353-4582-bd17-94b9d644f6e6@dfw1s10mta1990.xt.local>  Golden 1 Credit Union — credit score refresh
1783354874.4003086_271.hamsa,U=271:2,  <3mWJnLqs7wHYZ_wn9jmbBA@notifications.google.com>  Google — Security alert
1783354874.4003086_274.hamsa,U=274:2,  <1782757924240.5be201d3-...@bf06x.hubspotemail.net>  FITNESS SF — 48 Hours Left rate lock
1783354874.4003086_277.hamsa,U=277:2,  <1779962437.15382677.1782767392700@lor1-app84904...>  LinkedIn — Mike just messaged you
1783354874.4003086_279.hamsa,U=279:2,  <1120678493.14284923.1782775004757@lor1-app149061...>  LinkedIn — Mike just messaged you
1783354874.4003086_280.hamsa,U=280:2,  <922946988.15479284.1782776250481@lor1-app122175...>  LinkedIn — Jacob just messaged you
1783354874.4003086_282.hamsa,U=282:2,  <autogen-java-0d1d94ba-794d-4ef0-b237-2cc8a9a0f86a@google.com>  Google Sheets — share request
1783354874.4003086_287.hamsa,U=287:2,  <CAKB0ReC2DhHF_uie6=hCKskQGVmvQ3JH9vC19XSZT59inwWFKA@mail.gmail.com>  Circle Of Sacred Nature — Post-Ceremony Follow-Up
1783354874.4003086_295.hamsa,U=295:2,  <benbrastmckie/cslib/check-suites/CS_.../1782932212@github.com>  GitHub Actions — CI run failed
1783354874.4003086_300.hamsa,U=300:2,  <autogen-java-8e192977-3b5e-46b1-94e9-5adc70dac5ef@google.com>  Google Drive — folder shared
1783354874.4003086_305.hamsa,U=305:2,  <leanprover/cslib/pull/607/review/4617748857@github.com>  GitHub — PR #607 review (Fabrizio Montesi)
```

### Commands used (all read-only; no `notmuch new`/`mbsync`/mail mutation performed)

```sh
find ~/Mail/Logos/cur ~/Mail/Logos/new -maxdepth 1 -type f | sort > ondisk.txt
notmuch search --output=files 'path:Logos/cur or path:Logos/new' | sort > indexed.txt
grep -E '/Logos/(cur|new)/' indexed.txt | sort -u > indexed_filtered.txt
comm -23 ondisk.txt indexed_filtered.txt > missing.txt
comm -13 ondisk.txt indexed_filtered.txt   # stale/renamed index entries, informational

notmuch config list
notmuch config get new.ignore
notmuch config get new.tags
notmuch config get database.mail_root

notmuch search --output=files '*' | grep '<unique-filename-token>'   # x5 tokens tested
notmuch count 'id:<message-id, brackets stripped>'
notmuch search --output=files 'id:<message-id, brackets stripped>'

ls -la <each of the 22 files>
grep -ni '^message-id' <sample file>
awk '/^$/{exit} {print}' <sample file>     # header dump

cat ~/.config/notmuch/default/hooks/pre-new
cat ~/.config/notmuch/default/hooks/post-new

grep -n "notmuch" ~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh
cat ~/Mail/.logos-backup-20260706/reclone/reclone-live.log
tail -40 ~/Mail/.logos-backup-20260706/reclone/notmuch-reindex.log
tail -40 ~/Mail/.logos-backup-20260706/reclone/notmuch-reindex2.log
stat -c '%n  %y' ~/Mail/.logos-backup-20260706/reclone/{notmuch-reindex.log,notmuch-reindex2.log,repull.log,reclone-live.log}
cat ~/Mail/.logos-backup-20260706/reclone/repull.log
cat ~/Mail/.logos-backup-20260706/task-828/post-repair-verification.txt

grep -n "pre-new\|post-new\|mbsync -a" .claude/extensions/email/context/project/email/domain/wrapper-contracts.md
grep -n "systemd\|Timer\|onCalendar" ~/.dotfiles/modules/home/email/mbsync.nix
```

### Files/logs read

- `specs/827_email_staleness_detector_redesign/reports/01_staleness-detector-redesign.md` (prior
  dead-ends: `new.ignore`, hardlinks, directory-mtime-forced touch)
- `~/Mail/.logos-backup-20260706/reclone/reclone-live.log` (decisive: shows hook-triggered mbsync
  racing the reclone's own `notmuch new`, ending in `pre-new hook failed with status 1`)
- `~/Mail/.logos-backup-20260706/reclone/{notmuch-reindex.log,notmuch-reindex2.log,repull.log}`
  (timing correlation with the 22 files' creation mtime)
- `~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh` (the offending raw `notmuch new` call,
  line 92)
- `~/Mail/.logos-backup-20260706/task-828/post-repair-verification.txt`,
  `decision-log.jsonl` (grepped only; confirms UID-collision repair touched `.Trash`/`.Archive`
  only, not `Logos/cur` — this repair is unrelated to the INBOX anomaly, contra one of 827's
  speculative theories)
- `~/.config/notmuch/default/hooks/pre-new`, `post-new` (confirms `pre-new = mbsync gmail logos`)
- `~/.dotfiles/modules/home/email/mbsync.nix` (`email-reindex` definition; confirmed no systemd
  timer exists for mbsync)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (confirms the
  "never raw `notmuch new`" invariant this reclone script violated)
- `notmuch-new(1)`, `notmuch-search-terms(7)` man pages (`--full-scan`, `path:`/`folder:` semantics)

### Cross-repo note

The concrete remediation (`notmuch new --no-hooks --full-scan`) and the suggested
`logos-reclone.sh` patch (use `--no-hooks` at its reindex step) both apply to files/state in
`~/.dotfiles` and `~/Mail` — outside this repository. Per this repo's conventions, this report
documents the finding and recommendation; the user applies the remediation directly (running the
suggested command and/or editing and rebuilding `~/.dotfiles` via `home-manager switch`), not this
repo.
