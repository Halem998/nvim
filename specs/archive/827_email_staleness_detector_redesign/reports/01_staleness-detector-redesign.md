# Research Report: Task #827

**Task**: 827 - Redesign the /email staleness detector — stop equating maildir files with deduped messages
**Started**: 2026-07-13T15:30:00-07:00
**Completed**: 2026-07-13T16:45:00-07:00
**Effort**: 3 hours (estimated, matches state.json)
**Dependencies**: 826 (completed — Logos maildir reclone + full sync)
**Sources/Inputs**: Codebase (`.claude/extensions/email/`), cross-repo (`~/.dotfiles/modules/home/email/agent-tools/`), live read-only verification commands (`himalaya`, `notmuch`, `find`), one sanctioned `email-reindex` (index-only, run twice), `notmuch(1)` man page
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The freshness gate's core defect is confirmed and reproducible live: `INBOX_ONDISK` (himalaya
  file count) is compared with strict `=` against `INBOX_INDEXED` (`notmuch count folder:X`,
  which dedupes by Message-ID) — an apples-to-oranges comparison. Gmail happens to have zero
  Message-ID duplicates today, so it passes by coincidence; Logos does not, so it is permanently
  `[STALE]`.
- **New finding beyond the task's premise**: of Logos's 23-file gap (341 on-disk vs 318
  notmuch-indexed), only **1** is a genuine "one message, two files" dedup case. The other **22**
  files are files notmuch has **never indexed at all** — confirmed via `id:` lookup returning zero
  hits for their Message-IDs — and **two separate `email-reindex` runs** (one after forcing the
  `Logos/cur` directory mtime forward) did not index them. This is a live, unresolved,
  independent notmuch-indexing anomaly, not explained by "distinct-messages-not-duplicates"
  framing from the task-826 verification. Root cause not identified (ruled out: `new.ignore`
  patterns, hardlinks, directory-mtime skip-scan).
- Recommendation: **combine (a) + (b) + (c)**, not (a) alone. (a) fixes the *comparison logic*
  (file-vs-file, so Gmail and Logos are judged by the same yardstick and the gate becomes
  internally consistent). But (a) alone will **not** make `[ok]` reachable for Logos today,
  because of the confirmed residual 22-file indexing anomaly that reindexing does not close. (b)
  (small bounded tolerance) is therefore load-bearing, not optional, given real-world residuals
  can persist independent of staleness. (c) (reindex-run marker) is a cheap, robust secondary
  signal, especially valuable for autonomous/orchestrator mode where there's no human to
  interpret a numeric divergence.
- A documented `notmuch(1)` quirk makes a naive version of (a) — `notmuch count --output=files
  folder:X` — **actively wrong**, not just imprecise: `--output=files` returns *every known file*
  for every matching message, including duplicate copies that live in **entirely different
  folders** (confirmed live: `notmuch count --output=files folder:Gmail` = 238 despite only 128
  files existing under `Gmail/{cur,new}`; `folder:Logos` similarly returned files physically
  located under `Gmail/cur`). Any implementation of (a) must post-filter the file list to the
  exact on-disk path, not just query `folder:`/`path:` with `--output=files` directly.
- Confirmed the secondary bug: `email-census`'s positional argument (e.g. `email-census logos`)
  is silently discarded — only `--account <gmail|logos>` (or `--account=`) sets `$ACCOUNT`; there
  is no positional handler in `mkPreamble`'s arg-parsing loop
  (`~/.dotfiles/modules/home/email/agent-tools/lib.nix` lines ~79-88). Any positional token is
  swept into the unused `ARGS[]` passthrough array and `$ACCOUNT` silently stays default
  `"gmail"`. Should be fixed in the same census.nix touch, or explicitly deferred with a note.
- Ten doc/code sites reference the current on-disk/notmuch-indexed `[ok|STALE]` semantics and
  must be updated consistently (enumerated below in Finding 4).

## Context & Scope

Researched what the correct maildir-to-notmuch mapping is for both accounts (`gmail`, `logos`),
empirically verified all three redesign options against live data, identified every doc/code site
that encodes the current (defective) semantics, and produced a concrete recommendation and shell
sketch for the planner. Scope is diagnostic/design research only — no files were edited; the two
`email-reindex` invocations and one directory `touch` performed during verification are
index-only/metadata-only, sanctioned per wrapper-contracts.md §13, and mutate no mail.

## Findings

### Finding 1: The exact maildir↔notmuch mapping (empirically verified)

Both accounts' maildir root **is** their INBOX — there is no separate `<acct>/INBOX/` maildir in
active use. `find ~/Mail -maxdepth 3 -type d` shows, for each account, **both** a root-level
`{cur,new,tmp}` (the account's INBOX) **and** a same-named `INBOX/{cur,new,tmp}` subdirectory that
is empty and unused:

| Path | Files (himalaya / find) | notmuch `folder:` | notmuch `path:` |
|---|---|---|---|
| `Gmail/{cur,new}` (root = INBOX) | 128 | `folder:Gmail` = 128 | `path:Gmail/cur or path:Gmail/new` = 128 |
| `Gmail/INBOX/{cur,new}` (unused decoy) | 0 | `folder:Gmail/INBOX` = 0 | — |
| `Logos/{cur,new}` (root = INBOX) | 341 | `folder:Logos` = 318 | `path:Logos/cur or path:Logos/new` = 318 |
| `Logos/INBOX/{cur,new}` (unused decoy) | 0 | `folder:Logos/INBOX` = 0 | — |

So `himalaya envelope list -f INBOX` and `notmuch count "folder:$ACCOUNT_FOLDER"` (i.e.
`folder:Gmail` / `folder:Logos`) **are already reading the same logical maildir root** — the
"which path does INBOX actually map to" question the task asked to resolve has a clean answer:
`folder:$ACCOUNT_FOLDER` (bare, no `/INBOX` suffix) is correct and already what census.nix uses.
The defect is purely in the **kind of count** on the notmuch side (deduped messages), not in which
folder is queried.

`notmuch count` (no `--output=files`) counts **messages** (unique Message-ID), matching the
`(default)` output mode's semantics for the `search`/`count` commands. This is confirmed by the
Gmail case, where message-count (128) exactly equals file-count (128) — meaning Gmail's INBOX
currently has zero same-message-multiple-files situations, purely coincidentally.

### Finding 2: `--output=files` is not a safe drop-in fix — verified against notmuch(1)

`notmuch(1)`'s own man page documents the exact trap a naive option-(a) implementation would fall
into:

> "For --output=files ... All of them are included in the output (unless limited with the
> --duplicate=N option). This may be particularly confusing for folder: or path: searches in a
> specified directory, as the messages may have duplicates in other directories that are included
> in the output, although these files alone would not match the search."

Verified live:
- `notmuch count --output=files 'folder:Gmail'` = **238**, even though only 128 files exist under
  `Gmail/{cur,new}`. The extra 110 are files for the *same messages* that also have a duplicate
  copy under `Gmail/.All_Mail/cur/...` (Gmail's All Mail label folder) — those get pulled into the
  file list even though the query was folder-scoped to `Gmail`.
- `notmuch count --output=files 'folder:Logos'` = **403** (matches the number the task-826
  verification also observed). Of those 403 file paths, 84 are **not** under `Logos/{cur,new}` at
  all — several are literally under `Gmail/cur` and `Gmail/.Sent/cur` (i.e., a Logos-folder query
  pulled in files from the *other account's* maildir tree, because those messages happen to share
  a Message-ID with something also delivered to Logos).
- Post-filtering the `--output=files` result down to only paths literally under `Logos/{cur,new}`
  yields **319** — i.e. option (a), if implemented naively as `notmuch count --output=files
  folder:X`, would report a wildly wrong and unstable number (403), not a usable file count (319
  or 341). **Any (a) implementation must post-filter by path prefix**, e.g.:
  ```sh
  notmuch search --output=files "path:${ACCOUNT_FOLDER}/cur or path:${ACCOUNT_FOLDER}/new" \
    | grep -c "/${ACCOUNT_FOLDER}/\(cur\|new\)/"
  ```

### Finding 3: A confirmed, unresolved 22-file indexing anomaly independent of "staleness"

After the post-filter fix in Finding 2, the corrected file-vs-file counts are:

| Account | on-disk (himalaya/find) | notmuch-indexed **files**, post-filtered | Gap |
|---|---|---|---|
| Gmail | 128 | 128 | 0 |
| Logos | 341 | 319 | 22 |

Of that 22-file Logos gap:
- **1** is accounted for by the Finding-1 dedup mechanism (message-count 318 vs post-filtered
  file-count 319 — one message has two on-disk files, both under `Logos/{cur,new}`).
- **22** are files that notmuch has **zero record of, under any query**. Verified per-file: their
  `Message-Id` headers (extracted directly from the maildir files, e.g.
  `<m70823929@xp.philpapers.org>`, `<leanprover/cslib/pull/649/review/4535478124@github.com>`)
  return **zero** hits from `notmuch count 'id:<message-id-with-brackets-stripped>'` — i.e. these
  messages are not indexed anywhere in the 65,253-message database, not merely mis-attributed to
  a different folder.
- This is **not** simple index lag: `email-reindex` (`notmuch new --no-hooks`) was run twice
  during this research (both sanctioned, index-only, no mail mutated) — once as-is, once after
  forcibly bumping `Logos/cur`'s directory mtime forward (to rule out a stored-mtime skip-scan) —
  and both times reported **"No new mail" / 65253 -> 65253 unchanged**. The 22 files remain
  completely unindexed after both attempts.
- Root cause not identified in this research pass. Ruled out: `new.ignore` config (`.mbsyncstate;
  .strstrings;.lock;dovecot*` — filenames don't match), hardlink/inode dedup (each file has a
  unique inode, `find -samefile` found no duplicates), and directory-mtime-based skip-scan
  (forcing the mtime forward did not help). The affected files' mtimes (2026-07-06 09:21) coincide
  with the Logos maildir reclone/UID-collision-repair work from tasks 826/828
  (`~/Mail/.logos-backup-20260706/`, `~/Mail/.logos-backup-20260706/task-828/` contain
  `repair-uid-collisions.py`, `post-repair-verification.txt`) — plausible but unconfirmed that
  these 22 files are residue of that repair that never got a clean `notmuch new` pass pointed at
  them in the right state.
- **Consequence for the redesign**: even a *correctly implemented* option (a) will **not** make
  `[ok]` reliably reachable for Logos today — a residual ~22-file/~6% gap persists independent of
  reindexing. This is the single most important input to the recommendation below: a pure
  equality gate, even on the right units (files vs files), remains fragile against real-world
  indexing anomalies that are out of scope for this task to root-cause. This residual should be
  flagged to the user as a candidate follow-up task (possibly related to 828), not solved here.

### Finding 4: All doc/code sites encoding the current semantics (must update consistently)

| # | File | What it encodes |
|---|---|---|
| 1 | `~/.dotfiles/modules/home/email/agent-tools/census.nix` (lines 40-49) | The freshness line itself: `INBOX_ONDISK` (himalaya), `INBOX_INDEXED` (`notmuch count folder:X`), strict `=` gate. **Primary edit site.** |
| 2 | `~/.dotfiles/modules/home/email/mbsync.nix` (`email-reindex` definition + `email-freeze`/`email-thaw` messages) | Describes `email-reindex` as the remediation; references stay valid regardless of gate redesign, but any renamed variables/output format should be cross-checked here for consistency of operator-facing messaging. |
| 3 | `.claude/extensions/email/context/project/email/domain/staleness-detection.md` | Full design doc: ground-truth table, freshness-line format, end-to-end flow diagram. Needs the `[ok|STALE]` semantics section (and the "on-disk vs notmuch-indexed" ground-truth table) updated to reflect file-vs-file comparison + tolerance. |
| 4 | `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` §13 | "Index Freshness, Reindex, and the Absence of an Auto-Indexer" — restates the on-disk/notmuch-indexed line format and gate semantics; must track staleness-detection.md's update. |
| 5 | `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` | References the Stage 1 staleness gate for `--archive` coverage risk; wording is generic enough it likely needs no semantic change, but re-verify after the redesign lands. |
| 6 | `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (Stage 1 "Census + Staleness Gate", ~lines 304-323; "Staleness Remediation" section, ~lines 608-640) | The `--all` mode's mandatory gate logic and remediation flow — must be updated to match the new comparison semantics and (if (b)/(c) adopted) the new pass/fail condition wording. |
| 7 | `.claude/extensions/email/EXTENSION.md` | Extension-level summary blurb mentioning "on-disk vs notmuch-indexed" and `email-reindex`. |
| 8 | `.claude/extensions/email/README.md` | User-facing README restating the `[ok|STALE]` line format and reconciliation flow. |
| 9 | `.claude/extensions/email/commands/email.md` | `/email` command doc describing the Stage 1 gate behavior in both interactive and autonomous modes. |
| 10 | `.claude/extensions/email/index-entries.json` | Context-index descriptions/summaries referencing "on-disk vs indexed" — cosmetic but should stay accurate for context-discovery relevance matching. |

grep commands used to enumerate this list:
```sh
grep -rln "on-disk\|notmuch-indexed\|INBOX freshness\|\[STALE\]\|email-reindex" \
  .claude/extensions/email/
grep -rln "on-disk\|notmuch-indexed\|INBOX freshness\|email-reindex" \
  ~/.dotfiles/modules/home/email/
```

### Finding 5: The `--account` positional-argument bug (secondary, confirmed)

`~/.dotfiles/modules/home/email/agent-tools/lib.nix`'s shared `mkPreamble` arg-parsing loop
(lines ~79-88):
```sh
while [ "$#" -gt 0 ]; do
  case "$1" in
    --account) ACCOUNT="${2:-}"; shift 2 ;;
    --account=*) ACCOUNT="${1#--account=}"; shift ;;
    --manifest-dir) MANIFEST_DIR="${2:-}"; shift 2 ;;
    --manifest-dir=*) MANIFEST_DIR="${1#--manifest-dir=}"; shift ;;
    --help|-h) print_help; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
```
`ACCOUNT="gmail"` is the hardcoded default (line ~59) and there is no case arm that reads a bare
positional into `$ACCOUNT` — an unrecognized token (e.g. `logos`) falls to the catch-all `*)` and
is pushed into `ARGS[]`, which becomes `"$@"` for the rest of the script but is never consulted by
`census.nix`. So `email-census logos` silently runs as `--account gmail` with `logos` discarded.
This affects **all five wrapper binaries plus `email-census`**, not just census — it is a
shared-preamble bug. Since the redesign already touches `census.nix`/`lib.nix` territory, the
report flags it for the planner to decide whether to bundle a fix (e.g., add a positional-account
convenience arm, or just an explicit "unrecognized argument" hard error instead of silent
discard) into this task or split it into its own task. Given `lib.nix` is the FROZEN wrapper
contract preamble per wrapper-contracts.md's framing ("nothing in this extension may modify it"),
note that `email-census` is *not* one of the five frozen wrapper binaries — it's a separate
sixth/wrapper-adjacent tool per the file's own doc comments — so this specific ARG-parsing
preamble, while shared via `lib.nix`, may or may not fall under the "frozen" prohibition; this is
a decision for the planner/user, not assumed here.

## Recommendation

**Adopt (a) + (b) + (c) together**, not (a) alone:

1. **(a) — Fix the comparison to be file-vs-file**, correcting census.nix's freshness line to
   compare himalaya's on-disk file count against a **post-filtered** notmuch file count for the
   exact same maildir path (not a raw `folder:`/`path:` query with `--output=files`, which Finding
   2 shows is unsafe). Concrete sketch:
   ```sh
   echo "--- Index freshness: INBOX on-disk (himalaya) vs notmuch-indexed FILES (task 827) ---"
   INBOX_ONDISK=$(himalaya envelope list "${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 100000 2>/dev/null \
     | jq 'length' 2>/dev/null)
   INBOX_ONDISK="${INBOX_ONDISK:-?}"
   # notmuch --output=files pulls in cross-folder duplicate files for matching messages (notmuch(1)
   # documents this); post-filter to the exact on-disk path so both sides count the same file set.
   INBOX_INDEXED=$(notmuch search --output=files \
       "path:${ACCOUNT_FOLDER}/cur or path:${ACCOUNT_FOLDER}/new" 2>/dev/null \
     | grep -cE "/${ACCOUNT_FOLDER}/(cur|new)/" || echo '?')
   DIVERGENCE=$(( INBOX_ONDISK - INBOX_INDEXED ))  # guard against non-numeric '?' before arithmetic
   ```
   This alone makes Gmail and Logos judged by the *same units*, fixing the current
   correctness/consistency bug regardless of the residual anomaly.

2. **(b) — Add a bounded tolerance instead of strict equality**, because Finding 3 shows a small,
   currently-irreducible residual can persist even under correct file-vs-file comparison. Suggest
   a small absolute-count threshold (e.g. `abs(D) <= 5` files) OR a ratio threshold (e.g.
   `abs(D)/ONDISK < 1%`) — planner should pick one; absolute is simpler and avoids surprises on
   small mailboxes. `[ok]` when within tolerance, `[STALE]` (or a new third state, e.g.
   `[MINOR-DIVERGENCE]` vs `[STALE]`) otherwise, so a small persistent gap doesn't perpetually
   block `--all` the way the current hard gate does for Logos.

3. **(c) — Add a session-scoped "was `email-reindex` run this session" marker** as a
   complementary, non-numeric signal. Cheap to implement (e.g. a timestamp file written by
   `email-reindex` under `$MANIFEST_DIR` or a well-known state path, checked by `email-census` and
   surfaced as an additional line/flag), valuable because it gives the Stage 1 gate and autonomous
   mode a "did we at least attempt reconciliation" fact independent of whatever residual count
   divergence exists — directly useful given Finding 3's proof that reindexing can legitimately
   fail to close a gap, so "reindex ran and gap persists" is a materially different, more
   actionable status than "reindex was never attempted."

Net effect: `[ok]` becomes reachable for Gmail (unconditionally, matches today) and for Logos
*whenever its residual divergence is within tolerance* (it is currently 22/341 ≈ 6.5%, so the
planner should pick a threshold deliberately, or accept Logos may still read a non-`[ok]` status
until the Finding-3 anomaly is separately investigated — this should be an explicit, documented
tradeoff in the plan, not silently swept under a generous threshold).

### Downstream consistency requirements

- `skill-email-cleanup/SKILL.md` Stage 1 (lines ~304-323) and the Staleness Remediation section
  (~608-640) must be updated to (i) describe the new file-vs-file comparison, (ii) describe the
  tolerance/threshold semantics if (b) is adopted (what counts as `[ok]` is no longer "exactly
  equal"), and (iii) if (c) is adopted, describe how the reindex-marker is surfaced and whether it
  changes the gate's pass/fail decision or is purely informational.
- `staleness-detection.md`'s ground-truth table and end-to-end flow diagram need the same
  updates; it is the authoritative design doc other files point back to.
- `wrapper-contracts.md` §13 restates the same facts more tersely — must not drift from
  staleness-detection.md after the edit.
- `EXTENSION.md`, `README.md`, `commands/email.md`, `index-entries.json` are lower-stakes
  summaries; update for accuracy but they are not gate-logic-bearing.

## Decisions

- Confirmed both accounts' INBOX = maildir root (`{cur,new}` directly under `Gmail/`/`Logos/`),
  not a nested `INBOX/` subfolder — no maildir-mapping ambiguity to resolve; `folder:$ACCOUNT_FOLDER`
  (already used) is correct.
- Confirmed the correct notmuch-side query for option (a) must post-filter `--output=files`
  results by literal path prefix — using `folder:`/`path:` with `--output=files` unfiltered is
  unsafe per notmuch's own documentation and was empirically shown to inflate/pollute counts
  cross-folder and even cross-account.
- Recommend (a)+(b)+(c) combined, explicitly rejecting "(a) alone" as sufficient, based on the
  live-confirmed 22-file residual indexing anomaly that two reindex attempts did not close.
- Flag the Logos 22-file anomaly and the `--account` positional-arg bug as items for the planner
  to explicitly scope in or out of task 827 (both touch the same cross-repo files but are
  logically separable follow-ups).

## Risks & Mitigations

- **Risk**: choosing too generous a tolerance for (b) masks genuine future staleness (e.g. index
  falls badly behind after a long period without `email-reindex`). *Mitigation*: keep the
  threshold small (absolute count, not permissive ratio) and pair with (c) so "reindex never run
  this session" is still surfaced distinctly from "reindex ran, residual is within tolerance."
- **Risk**: the `notmuch search --output=files ... | grep -c ...` post-filter approach adds a
  `notmuch search` (heavier than `notmuch count`) plus a `grep` subprocess to census.nix's
  freshness line; on very large mailboxes this could be slower than the current `notmuch count`
  call. *Mitigation*: this is a read-only, once-per-`email-census`-invocation cost, not a hot
  path; acceptable given `email-census` already does multiple `notmuch count`/`notmuch address`
  calls (sender census, date buckets) of comparable cost.
- **Risk**: bundling the `--account` positional-arg fix into this task expands scope beyond
  "the freshness line" and touches the shared `lib.nix` preamble used by all five frozen wrapper
  binaries. *Mitigation*: plan should treat it as an optional, clearly-separated phase/step, or
  explicitly defer it to a new spawned task — the planner should decide based on task-273-style
  scope discipline, not assume it's in-scope by default.
- **Risk**: the unresolved 22-file indexing anomaly could recur or grow, meaning even a
  well-tuned tolerance eventually fails again. *Mitigation*: explicitly recommend a follow-up
  investigation task (not part of 827) to root-cause why `notmuch new --no-hooks` does not pick
  up these specific files — candidates to investigate: maildir flag/UID artifacts left by the
  task-826/828 reclone and UID-collision repair, a possible notmuch database corruption limited
  to specific document IDs, or file permission/timing race during the repair script's writes.

## Context Extension Recommendations

- **Topic**: notmuch `--output=files` cross-folder/cross-account duplicate-inclusion quirk.
  **Gap**: not documented anywhere in `.claude/extensions/email/context/`; this is a
  notmuch-specific gotcha likely to bite any future census/count logic that reaches for
  `--output=files` naively. **Recommendation**: add a short note to
  `staleness-detection.md`'s "Ground truth vs. index" table (or a new subsection) once the
  redesign lands, citing the `notmuch(1)` man-page quote from Finding 2, so future maintainers
  don't reintroduce the same bug.
- **Topic**: the confirmed-but-unresolved 22-file Logos indexing anomaly. **Gap**: not tracked
  anywhere as a known issue. **Recommendation**: the plan (or a spawned follow-up task) should
  record this as a known, reproducible anomaly with the diagnostic steps taken here (id: lookup
  returning zero, two reindex attempts including a directory-mtime-forced one, both no-op) so a
  future investigator doesn't repeat the same dead-end steps.

## Appendix

### Search queries / commands used (all read-only unless noted)

```sh
# maildir structure
find ~/Mail -maxdepth 3 -type d

# on-disk vs notmuch message-count vs notmuch file-count, both accounts
find ~/Mail/Gmail/cur ~/Mail/Gmail/new -maxdepth 1 -type f | wc -l
find ~/Mail/Logos/cur ~/Mail/Logos/new -maxdepth 1 -type f | wc -l
notmuch count 'folder:Gmail'
notmuch count 'folder:Logos'
notmuch count --output=files 'folder:Gmail'
notmuch count --output=files 'folder:Logos'
notmuch search --output=files 'folder:Gmail' | grep -vc '/Mail/Gmail/\(cur\|new\)/'
notmuch search --output=files 'folder:Logos' | grep -vc '/Mail/Logos/\(cur\|new\)/'
himalaya envelope list -a gmail -f INBOX -o json -s 100000 | jq length
himalaya envelope list -a logos -f INBOX -o json -s 100000 | jq length

# per-file Message-ID lookup for the 22 unindexed files
comm -23 <(find ... | sort) <(notmuch search --output=files ... | sort)
notmuch count 'id:<message-id, brackets stripped>'

# sanctioned, index-only, non-mutating remediation attempts (both no-ops)
email-reindex
touch ~/Mail/Logos/cur && email-reindex

# doc/code site enumeration
grep -rln "on-disk\|notmuch-indexed\|INBOX freshness\|\[STALE\]\|email-reindex" \
  .claude/extensions/email/
grep -rln "on-disk\|notmuch-indexed\|INBOX freshness\|email-reindex" \
  ~/.dotfiles/modules/home/email/

# --account positional-arg bug
sed -n '38,115p' ~/.dotfiles/modules/home/email/agent-tools/lib.nix
```

### Files read

- `.claude/extensions/email/context/project/email/domain/staleness-detection.md`
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (§11, §13)
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (Stage 1, Staleness Remediation,
  Critical Requirements)
- `.claude/extensions/email/EXTENSION.md`, `README.md`, `commands/email.md`, `index-entries.json`
- `~/.dotfiles/modules/home/email/agent-tools/census.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/lib.nix` (`mkPreamble`, arg-parsing loop)
- `~/.dotfiles/modules/home/email/mbsync.nix` (`email-reindex`, `email-freeze`/`email-thaw`
  references, grep-only)
- `notmuch(1)` man page (`--output=files` semantics)

### Cross-repo note

All census.nix / lib.nix / mbsync.nix edits land in `~/.dotfiles` (a separate repository from
this one). This research report and the eventual plan describe the intended `.dotfiles` edits;
per this repo's meta-task conventions, the user applies and rebuilds (`home-manager switch`) the
`.dotfiles` change — it is not committed or built from this repo.
