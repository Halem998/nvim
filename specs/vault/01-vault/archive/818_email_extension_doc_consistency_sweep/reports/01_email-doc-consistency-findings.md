# Research Report: Task #818

**Task**: 818 - Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04)
**Started**: 2026-07-05T00:00:00Z
**Completed**: 2026-07-05T00:00:00Z
**Effort**: small (doc-only sweep, no code/wrapper changes)
**Dependencies**: task 817 (multi-account gating reconciliation — completed, edited `commands/email.md`, `skill-email-cleanup/SKILL.md`, `skill-email-sync/SKILL.md`)
**Sources/Inputs**: - Codebase (`.claude/extensions/email/`), `specs/reviews/review-2026-07-04.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `archive-mode-risk.md` was **not** touched by task 817, so the review's original line numbers
  (1, 12-17, 61, 68) for finding 3 are still exactly correct on disk today.
- `skill-email-cleanup/SKILL.md`'s pilot-ack section (finding 4) shifted down by ~6 lines due to
  817's new "Account Liveness Check" section; the ambiguous "either/or, pick one convention" text
  is now at **lines 434-442** (was 428-442 in the review).
- `README.md` was **not** touched by task 817 — finding 5's line numbers (16-17, 106-125) are
  still exactly correct.
- `commands/email.md`'s `--sync` bullet (finding 6) is, coincidentally, still at **lines 32-34**
  (near the top of the file, above where 817's edits concentrated); `skill-email-sync/SKILL.md`'s
  "explicit override wins" bullet is now at **lines 65-67** (shifted by ~1 from the review's ~64-66),
  and the actual Stage 3 confirm block that needs the new warning text is at **lines 92-97**.
- All four findings are additive/rewording changes with no cross-file conflicts against 817's
  edits; 817 did not touch any of the exact spans finding 3-6 need to change, though 817's new
  language (account-generic tables, "resolved account" phrasing, liveness-check framing) is what
  findings 3-6 should be made to match.

## Context & Scope

Task 816 (parent) landed `.dotfiles` task 79 (multi-account wrapper) reconciliation across
`wrapper-contracts.md`. Task 817 (just completed, prerequisite to this task) reconciled the
**operative gating files** (`commands/email.md`, `skill-email-cleanup/SKILL.md`,
`skill-email-sync/SKILL.md`) with the now-verified wrapper contract — removing "gmail-only,
pending task 79" language and replacing it with a `--account <gmail|logos>` liveness-check model.

This task (818) is a **documentation consistency sweep** for the four MEDIUM findings (3-6) from
`specs/reviews/review-2026-07-04.md` that were explicitly deferred (out of scope) from 817's
critical/high-priority fix. The instruction from the delegator was explicit: re-read all four
target files fresh, since 817 already edited three of them, and locate findings by content, not
stale line numbers.

## Findings

### Finding 3 — `archive-mode-risk.md` incomplete account-generalization

**File**: `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
(83 lines total, unchanged by task 817 — confirmed by content match against the review's own
line citations, which land exactly on the cited text).

**Current locations** (verified against on-disk content, identical to review's citations):

1. **Line 1** — title still says:
   ```
   # Archive-Mode Risk (`--archive`, All Mail Scope)
   ```
   The rest of the file's intro (lines 3-8) is already account-generic ("the account's archive
   query token, e.g. `folder:Gmail/.All_Mail` for `gmail` or `folder:Logos/.Archive` for
   `logos`"), so the title is the one holdout.

2. **Lines 10-17** — "The Blast Radius" section/table:
   ```
   ## The Blast Radius

   | Property | INBOX (account inbox query, e.g. `folder:Gmail`) | Archive (account archive query, e.g. `folder:Gmail/.All_Mail`; see `wrapper-contracts.md` §11 for the per-account table) |
   |----------|------------------------|--------------------------------------|
   | Approximate size | hundreds | ~64,000 messages |
   | Content age | recent, familiar | years of archive-of-record history |
   | Classifier validation | rules hand-tuned against inbox traffic | never validated against archive-era senders |
   | Cost of a wrong delete | annoying | potentially irreplaceable history |
   ```
   The column headers were already account-generalized (mentioning both gmail/logos folder
   tokens), but the **body row** "Approximate size" still hardcodes a single gmail-only number
   (`~64,000 messages`) with no Logos figure at all.

3. **Line 61** — Gate #1 ("Second blast-radius-naming confirmation"):
   ```
   the folder verbatim: "Yes, operate on N archived messages in All Mail". Distinct wording is
   ```
   Hardcodes the gmail-only confirmation string with no logos variant.

4. **Line 68** — Gate #3 ("Never auto-chain `/email --sync`"):
   ```
   run their own group-scoped `mbsync gmail` reconcile per executed run (frozen contract,
   ```
   Hardcodes `mbsync gmail` instead of the account-generic channel.

**What to match it against** — the now-authoritative account-generic material already in
`skill-email-cleanup/SKILL.md` (post-817, verified current):

- **Per-account archive table** (lines 379-384 today):
  ```
  | Account | Archive folder | Approximate size | Blast-radius note |
  |---------|----------------|-------------------|---------------------|
  | `gmail` | All Mail (`folder:Gmail/.All_Mail`) | ~64,000 messages | orders of magnitude more destructive than INBOX; much of the content is old mail the classifier's inbox-tuned rules were never validated against |
  | `logos` | Archive (`folder:Logos/.Archive`) | ~54 messages (live probe) | much smaller blast radius than the Gmail archive, but the SAME proportionate gates apply in full — smaller scale is not a reason to relax any gate |
  ```
- **Gate #1 wording** (lines 393-398 today, in "Archive Scope" section):
  ```
  2. **Second, distinctly-worded blast-radius confirmation**: ... ask a separate AskUserQuestion
     that names the blast radius explicitly: "Yes, operate on N archived messages in All Mail"
     (gmail) / "Yes, operate on N archived messages in Logos Archive" (logos) / "No, stop here".
     Generic "proceed?" wording is not acceptable; the option label must state N and the
     account's archive-folder name.
  ```
- **Gate #3 wording** (lines 413-414 today):
  ```
  6. **Never auto-chain `/email --sync`** after an archive drain. The wrapper's internal
     per-run `mbsync <account-channel>` reconcile is frozen contract behavior; ...
  ```

**Precise edit plan for `archive-mode-risk.md`**:

| Location | Current | Change to |
|----------|---------|-----------|
| Line 1 | `# Archive-Mode Risk (`--archive`, All Mail Scope)` | `# Archive-Mode Risk (`--archive`, Account Archive Scope)` (or equivalent generic phrasing — drop "All Mail" from the title itself) |
| Lines 10-17 | Single-column "Approximate size: ~64,000 messages" with no per-account breakout | Either (a) split the "Approximate size" row into two account-labeled sub-lines, or (b) add a short account-generic table beneath (mirroring the skill's `Account \| Archive folder \| Approximate size \| Blast-radius note` table verbatim, with the gmail ~64,000 and logos ~54 rows), and note in the INBOX/Archive comparison table that the Archive column's size varies per account (cross-reference the skill table rather than re-hardcoding a single number) |
| Line 61 | `"Yes, operate on N archived messages in All Mail"` | `"Yes, operate on N archived messages in All Mail" (gmail) / "Yes, operate on N archived messages in Logos Archive" (logos)` — matching skill wording verbatim |
| Line 68 | `mbsync gmail` | `mbsync <account-channel>` — matching skill wording verbatim |

No other lines in this file need changes; the rest is already correctly account-generic (verified
by reading the full 83-line file).

---

### Finding 4 — Pilot-ack file convention ambiguity in `skill-email-cleanup/SKILL.md`

**File**: `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (490 lines total,
edited by task 817, but 817's edits were concentrated earlier in the file — the "Account
Liveness Check" section, lines 45-65 — which pushed everything below it down by roughly 6 lines
relative to the review's original citation).

**Current location** (re-located by content, confirmed via direct read): lines 434-442, inside
the "## Pilot Gate for `--archive`" section (header at line 417):

```
434	- **Acknowledgement record, keyed by account**: after a pilot completes and Stage 6
435	  verification is clean, ask the user to acknowledge the pilot outcome (AskUserQuestion, root
436	  session). On acknowledgement write (or update) `$MANIFEST_DIR/archive-pilot-ack.json` as an
437	  account-keyed structure — either a top-level `"account"` field per ack record, or separate
438	  per-account ack files (e.g. `archive-pilot-ack-gmail.json` / `archive-pilot-ack-logos.json`);
439	  pick one convention and apply it consistently. Record shape:
440	  `{"account": "gmail|logos", "acknowledged_at": "<ISO8601>", "pilot_scope": "<query>",
441	  "messages_processed": N, "chunk_size_verdict": "keep 1000 | adjust to <n>"}`. This file is
442	  git-tracked and is the gate's persistent evidence, per account.
```

The immediately-following "Gate check (Stage 0)" bullet (lines 443-448) already assumes a
**single file** path: `$MANIFEST_DIR/archive-pilot-ack.json` is referenced singularly in the
REFUSE message ("run a bounded pilot first ... verify, and acknowledge"), which is inconsistent
with the "separate per-account ack files (e.g. `archive-pilot-ack-gmail.json` /
`archive-pilot-ack-logos.json`)" branch offered two lines above it. This internal inconsistency
is exactly what the review's finding 4 flags: a fresh agent (no memory of a prior invocation's
choice) could pick the "separate files" branch and silently diverge from the "Gate check" text's
assumption of one shared file.

**Recommended fix** — hardcode the single-file, `"account"`-keyed convention (removing the
"separate per-account ack files" alternative entirely, since the "Gate check" text already
depends on there being one path):

- File: always `$MANIFEST_DIR/archive-pilot-ack.json` (one file, never per-account filenames).
- Structure: a JSON array of per-account records, each shaped exactly as already specified:
  `{"account": "gmail|logos", "acknowledged_at": "<ISO8601>", "pilot_scope": "<query>",
  "messages_processed": N, "chunk_size_verdict": "keep 1000 | adjust to <n>"}`.
- On acknowledgement: if the file doesn't exist, create it with a one-element array containing
  the new record; if it exists, read it, replace (or append) the record whose `"account"` field
  matches the resolved account, and write the array back — never create a second file.
- Gate check (Stage 0): always read `$MANIFEST_DIR/archive-pilot-ack.json`, parse the array, and
  look for an entry whose `"account"` field equals the resolved `account`. Absent-or-no-match
  means REFUSE (per the existing message at lines 445-448, unchanged).

This removes the ambiguous "either/or... pick one convention" sentence (lines 437-439) and
replaces it with a single, explicit, unconditional convention description — eliminating the
cross-invocation judgment call the review flagged. No other file (`archive-mode-risk.md` line 65
references `archive-pilot-ack.json` by name only, no convention detail) needs changes for this
finding.

---

### Finding 5 — `README.md` stale relative to multi-account feature

**File**: `.claude/extensions/email/README.md` (136 lines total, **not** touched by task 817 —
confirmed: no account-selector language anywhere in the file's "Using `/email`" section).

**Current locations** (verified, review's original line citations are still exactly correct):

1. **Lines 16-17** (Purpose section):
   ```
   16  This extension gives an agent a safe, auditable way to triage a Gmail inbox: read a census of
   17  senders/folders, classify messages into propose-archive/propose-delete/keep/unsure buckets,
   ```
   Frames the whole extension as Gmail-only.

2. **Lines 106-125** ("Two modes and a scope flag" + `/email --sync` sections):
   ```
   106  - **`/email --archive` (scope flag, composable with either mode)**: operates on All Mail
   107    (`folder:Gmail/.All_Mail`, ~64k messages) instead of INBOX, with extra-caution gates: ...
   ...
   114  ### `/email --sync [channel]` — reconcile the cleanup to Gmail
   115
   116  The cleanup wrappers mutate the **local** maildir only; nothing reaches Gmail-in-the-browser until
   ...
   120  Once a cleanup is complete and looks right, run `/email --sync` (routes to `skill-email-sync`) to
   121  run `mbsync <channel>` (default channel `gmail`, overridable: `/email --sync work`). This pushes
   122  the local archives/deletes up to Gmail, so the browser inbox reflects the cleanup:
   123
   124  - Archived messages -> Gmail **All Mail** (still searchable/recoverable).
   125  - Deleted messages -> Gmail **Trash** (recoverable ~30 days).
   ```
   All Gmail-only framing, `--archive` described as "operates on All Mail" unconditionally, no
   `--account`/`--logos` mention anywhere, `--sync`'s default channel/account described as Gmail
   only.

**No `--account`/`--logos` mention anywhere in the file** (confirmed by full read) — the "Using
`/email`" section (lines 85-131) needs a new subsection analogous to `commands/email.md`'s
"Accounts" block (lines 36-46) to describe the selector.

**Recommended fix** (matching terminology already used in `commands/email.md` and
`skill-email-cleanup/SKILL.md` post-817):

- Lines 16-17: reword Purpose to be account-generic, e.g. "...a safe, auditable way to triage a
  mailbox (Gmail by default, or the Logos/Protonmail-Bridge account via `--account logos` /
  `--logos`): read a census of senders/folders...".
- Add a short "Accounts" subsection under "Using `/email`" (after the existing "Two modes and a
  scope flag" list, or before it) mirroring `commands/email.md`'s Accounts block: default
  `account=gmail`; `--account logos` / `--logos` selects the Logos account (folder-based:
  `folder:Logos`, `folder:Logos/.Archive`, no `.All_Mail`/`.Spam`); unknown values rejected
  loudly, never silent gmail fallback; `account=logos` passes a light liveness check first.
- Lines 106-112 (`--archive` bullet): reword "operates on All Mail (`folder:Gmail/.All_Mail`,
  ~64k messages)" to "operates on the account's archive folder (All Mail, `folder:Gmail/.All_Mail`,
  ~64k messages for gmail; the real Archive folder, `folder:Logos/.Archive`, ~54 messages for
  logos)".
- Lines 114-125 (`/email --sync` section): reword the heading and body to be account-generic —
  "reconcile the cleanup to the account's server", channel defaults from account (`gmail` or
  `logos`), and the Archived/Deleted bullets should mention both accounts' target folders
  (All Mail/Trash for gmail; the real Archive/Trash folders for logos), matching
  `skill-email-sync/SKILL.md`'s "What sync does" section (lines 18-32).
- (Minor, not explicitly cited by the review but same theme) line 39's file-inventory table
  entry for `archive-mode-risk.md` still says "All Mail blast radius" — worth a one-word
  generalization to "account archive blast radius" while in the file for consistency, though this
  is optional polish beyond the review's explicit citation.

---

### Finding 6 — No `--sync` channel/account mismatch warning

**Files**: `.claude/extensions/email/commands/email.md` and
`.claude/extensions/email/skills/skill-email-sync/SKILL.md` (both edited by task 817).

**Current locations** (re-verified by content):

1. `commands/email.md` **lines 32-34** — coincidentally unchanged position from the review
   (this bullet sits near the top of the file, above where 817 concentrated its edits):
   ```
   32  - `--sync [channel]`: reconcile local mutations to the server; optional mbsync channel name
   33    (default: the resolved account's channel — `gmail` or `logos`; an explicit channel always
   34    overrides the account default).
   ```
   States that an explicit channel always overrides — with no mention that an override
   disagreeing with the resolved account is even possible/flagged.

2. `commands/email.md`'s `<sync_path>` `expected_return` block (**lines 129-137** today) has the
   fuller description and is also a candidate edit point:
   ```
   134  the account's server, with the sync result reported. Run this only after a cleanup is
   135  complete and reviewed - never interleaved with an active cleanup batch (freeze sync during
   ...
   ```
   (full text already reproduced above in the codebase read) — currently silent on mismatch.

3. `commands/email.md`'s `error_handling` section — `<interactive_errors>` (**lines 214-217**)
   lists "User declines all proposed actions" and "User declines the sync confirmation" but has
   no entry for a channel/account mismatch warning.

4. `skill-email-sync/SKILL.md` — the "explicit override wins" bullet, now at **lines 65-67**
   (shifted by ~1 from the review's ~64-66 due to 817's edits earlier in the file):
   ```
   65  - **Explicit override wins**: the user may override the resolved default with an explicit
   66    channel token as the argument to `--sync` (e.g. `/email --sync work`) — an explicit channel
   67    always takes precedence over the account-derived default, for either account.
   ```
   States the override always wins with zero mention of surfacing a mismatch.

5. `skill-email-sync/SKILL.md`'s **Stage 3: Confirm** block — the actual mandatory-stop gate
   where the new warning belongs — is at **lines 92-97**:
   ```
   92  ### Stage 3: Confirm (mandatory stop)
   93
   94  Call AskUserQuestion to confirm the reconcile before running it. Make the prompt explicit that
   95  sync propagates local archives/deletes to the account's server and that any locally expunged
   96  messages become permanently removed on the server. Include the channel name to be synced
   97  (`gmail` or `logos`, or the explicit override). Do not proceed without an explicit approval.
   ```
   This block already says to "include the channel name to be synced" but never checks/mentions
   whether that channel actually matches the resolved account.

**Recommended fix**:

- `skill-email-sync/SKILL.md` Stage 3 (lines 92-97): add an explicit mismatch check/warning,
  e.g. append a sentence: "If an explicit channel override was given and it does not match the
  resolved `account`'s default channel (e.g. `account=gmail` but `--sync logos`, or vice versa),
  surface this as an explicit warning inside the same confirmation prompt — e.g. 'Warning: the
  channel to sync (`logos`) does not match the account this cleanup ran against (`gmail`) —
  proceed anyway?' — never silently sync a mismatched channel without flagging it."
- `skill-email-sync/SKILL.md` "explicit override wins" bullet (lines 65-67): add a trailing
  clause noting the override is still checked for mismatch at Stage 3 ("...always takes
  precedence — but see Stage 3, which surfaces a warning if this override disagrees with the
  resolved account").
- `commands/email.md` lines 32-34 (Input `--sync` bullet): add a clause: "if the explicit channel
  disagrees with the resolved account's default channel, `skill-email-sync`'s Stage 3 confirm
  surfaces a mismatch warning before proceeding — the override still wins if the user confirms."
- `commands/email.md` `<interactive_errors>` (lines 214-217) or `<execution_errors>`
  (197-211): add a new bullet documenting the mismatch-warning path for consistency with the
  other documented interactive/confirmation behaviors, e.g. "Explicit `--sync <channel>`
  disagrees with the resolved `account` -> `skill-email-sync` Stage 3 surfaces an explicit
  mismatch warning in the confirmation prompt; proceeding is still possible on explicit user
  confirmation."

## Decisions

- Treat `archive-mode-risk.md` and `README.md` as **untouched by task 817** — their content was
  read fresh and matches the review's original line citations exactly; no re-verification gap.
- Treat `skill-email-cleanup/SKILL.md` and both `commands/email.md`/`skill-email-sync/SKILL.md`
  citations as **shifted** by 817's edits; the report above gives the current, re-located line
  numbers (verified by direct read, not review inheritance).
- For finding 4, resolve the ambiguity in favor of the **single-file, array-of-account-records**
  convention, since the existing "Gate check" text (lines 443-448) already assumes a single
  `archive-pilot-ack.json` path — picking the other branch ("separate per-account files") would
  require also rewriting the Gate check text, which is out of proportion to a MEDIUM finding.
- For finding 6, the warning belongs primarily in `skill-email-sync/SKILL.md` Stage 3 (the actual
  mandatory-stop confirmation gate); `commands/email.md`'s edits are secondary/descriptive
  (documenting that the behavior exists) rather than the enforcement point itself.

## Risks & Mitigations

- **Risk**: editing `skill-email-cleanup/SKILL.md`'s pilot-ack section could desync from
  `archive-mode-risk.md`'s single mention of `archive-pilot-ack.json` (line 65) if the filename
  itself changes. **Mitigation**: the recommended fix keeps the filename
  (`archive-pilot-ack.json`) unchanged — only the internal structure/convention description
  changes — so `archive-mode-risk.md` needs no edit for this finding.
- **Risk**: `README.md`'s "Two modes and a scope flag" list interleaves mode/scope explanation
  with account examples; a careless edit could make the numbers stale again (e.g. copy gmail's
  ~64k without logos' ~54). **Mitigation**: pull both numbers directly from
  `skill-email-cleanup/SKILL.md`'s account-generic table (lines 379-384) rather than re-deriving.
- **Risk**: finding 6's fix touches both `commands/email.md` and `skill-email-sync/SKILL.md`;
  if only one file is edited, the two could re-diverge (one documents the warning, the other
  doesn't implement it). **Mitigation**: implement the actual warning logic in
  `skill-email-sync/SKILL.md` Stage 3 first, then update `commands/email.md`'s descriptive
  bullets to match, in the same edit pass.

## Context Extension Recommendations

None — this is a meta task correcting existing doc consistency within an already-documented
extension; no new context file is warranted.

## Appendix

- Files read in full: `specs/reviews/review-2026-07-04.md`,
  `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (83 lines),
  `.claude/extensions/email/README.md` (136 lines), `.claude/extensions/email/commands/email.md`
  (218 lines), `.claude/extensions/email/skills/skill-email-sync/SKILL.md` (133 lines).
- Files read in relevant part: `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`
  (490 lines; grepped for account/Gmail/Logos/blast/64,000 references, then read lines 367-455
  in full for the Archive Scope + Pilot Gate sections).
- Line numbers throughout this report are current on-disk line numbers as of this research pass
  (post-task-817), verified by direct `Read` tool output, not carried over from the review.
