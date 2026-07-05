# Implementation Plan: Task #818

- **Task**: 818 - Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04)
- **Status**: [COMPLETED]
- **Effort**: 2.2 hours
- **Dependencies**: task 817 (multi-account gating reconciliation — completed)
- **Research Inputs**: specs/818_email_extension_doc_consistency_sweep/reports/01_email-doc-consistency-findings.md
- **Artifacts**: plans/01_email-doc-consistency-sweep.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Documentation-only consistency sweep for the four MEDIUM findings (3-6) deferred from task 817,
all scoped to `.claude/extensions/email/`. Each finding aligns stale, Gmail-only, or ambiguous
documentation with the now-authoritative account-generic (`gmail`/`logos`) language that task 817
landed in the operative gating files. All edits are additive/rewording with no code or wrapper
behavior change; the research report has verified every target line number against on-disk content
post-817. Definition of done: all four findings applied, both finding-6 files kept mutually
consistent, no stale line-number drift, and `check-extension-docs.sh` still PASS.

### Research Integration

The research report (`reports/01_email-doc-consistency-findings.md`) provides current on-disk
(post-817) exact edit sites and precise fix text for each finding, plus the authoritative source
wording to mirror:

- **Finding 3** — `archive-mode-risk.md` untouched by 817; lines 1, 10-17, 61, 68 still exact.
  Mirror the per-account table (`skill-email-cleanup/SKILL.md` lines 379-384) and account-generic
  Gate #1 / Gate #3 wording (lines 393-398, 413-414).
- **Finding 4** — pilot-ack ambiguity shifted to `skill-email-cleanup/SKILL.md` lines 434-442
  (Gate check at 443-448 already assumes a single file). Resolve to the single-file,
  array-of-account-records convention.
- **Finding 5** — `README.md` untouched by 817; lines 16-17 and 106-125 still exact. Add an
  Accounts subsection mirroring `commands/email.md` lines 36-46.
- **Finding 6** — enforcement point is `skill-email-sync/SKILL.md` Stage 3 (lines 92-97);
  `commands/email.md` lines 32-34 and interactive_errors (lines 214-217) get descriptive support
  text. `skill-email-sync/SKILL.md` "explicit override wins" bullet at lines 65-67.

All line numbers above were re-verified against disk during planning (2026-07-04) and remain
accurate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path in delegation; roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- Finish account-generalizing `archive-mode-risk.md` (title, blast-radius table, Gate #1, Gate #3).
- Collapse the pilot-ack file-convention ambiguity in `skill-email-cleanup/SKILL.md` into one
  hardcoded single-file convention consistent with the existing Gate-check text.
- Refresh `README.md` to describe the multi-account (`--account`/`--logos`) feature.
- Add a `--sync` channel/account mismatch warning at the actual enforcement point
  (`skill-email-sync/SKILL.md` Stage 3), with matching descriptive text in `commands/email.md`.
- Keep `check-extension-docs.sh` PASS after all edits.

**Non-Goals**:
- No changes to wrapper scripts, code, or actual sync/cleanup behavior (doc-only sweep).
- No change to the `archive-pilot-ack.json` filename itself (only its documented structure).
- No re-editing of the exact spans task 817 already changed; this task edits different regions.
- No new context files (research confirmed none warranted).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Finding-6 files re-diverge (one documents warning, other omits it) | M | M | Edit `skill-email-sync/SKILL.md` Stage 3 first (enforcement point), then `commands/email.md` descriptive bullets in the same phase; verify both mention the mismatch warning. |
| README numbers go stale again (copy gmail ~64k without logos ~54) | M | M | Pull both figures directly from `skill-email-cleanup/SKILL.md` per-account table (lines 379-384), never re-derive. |
| Pilot-ack edit desyncs `archive-mode-risk.md` line 65 filename mention | L | L | Keep filename `archive-pilot-ack.json` unchanged; only the internal structure description changes. |
| Task-817 edits shifted line numbers again since research pass | L | L | Locate every edit site by content/grep, not by raw line number; report line numbers re-verified during planning. |
| README edit drops the `/email` command mention doc-lint requires | M | L | Preserve all existing `/email` command references; completeness gate runs `check-extension-docs.sh`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel (distinct files, except finding 6's two files
are both owned by Phase 4). Phase 5 is the completeness/verification gate and depends on all.

### Phase 1: Finding 3 — Account-generalize archive-mode-risk.md [COMPLETED]

**Goal**: Remove the last Gmail-only holdouts from
`.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`, mirroring the
authoritative account-generic wording in `skill-email-cleanup/SKILL.md`.

**Tasks**:
- [x] Line 1 title: change `# Archive-Mode Risk (\`--archive\`, All Mail Scope)` to drop "All Mail"
  in favor of account-generic phrasing, e.g. `# Archive-Mode Risk (\`--archive\`, Account Archive Scope)`.
  *(completed)*
- [x] Lines 10-17 "The Blast Radius": add a per-account breakout for "Approximate size" so both
  accounts appear — mirror the `skill-email-cleanup/SKILL.md` table (lines 379-384): gmail All Mail
  `folder:Gmail/.All_Mail` ~64,000 messages; logos Archive `folder:Logos/.Archive` ~54 messages
  (live probe). Prefer adding a short account-labeled table / sub-lines and cross-referencing the
  skill table rather than re-hardcoding a single number.
  *(completed: added a mirrored "Archive of record, per account" table beneath the blast-radius
  table, and changed the table's "Approximate size" row to point to it)*
- [x] Line 61 (Gate #1 confirmation string): change `"Yes, operate on N archived messages in All Mail"`
  to the account-generic pair verbatim from the skill (lines 393-398):
  `"Yes, operate on N archived messages in All Mail" (gmail) / "Yes, operate on N archived messages in Logos Archive" (logos)`.
  *(completed)*
- [x] Line 68 (Gate #3): change `mbsync gmail` to the account-generic `mbsync <account-channel>`,
  matching skill wording (lines 413-414). *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — title, blast-radius
  table row, Gate #1 confirmation string, Gate #3 channel token.

**Verification**:
- No occurrence of "All Mail Scope" in the title line; no bare `~64,000` without a logos counterpart;
  no `mbsync gmail` literal remaining; both gmail and logos appear in the Gate #1 confirmation wording.
- Read the full 83-line file to confirm no other Gmail-only holdouts were introduced.

---

### Phase 2: Finding 4 — Hardcode single-file pilot-ack convention [COMPLETED]

**Goal**: Replace the "either top-level `account` field OR separate per-account files, pick one"
ambiguity in `skill-email-cleanup/SKILL.md` (lines 434-442) with a single, unconditional
convention consistent with the existing Gate-check text (lines 443-448).

**Tasks**:
- [x] Remove the "separate per-account ack files (e.g. `archive-pilot-ack-gmail.json` /
  `archive-pilot-ack-logos.json`) ... pick one convention" alternative (the ambiguous sentence at
  lines 437-439). *(completed)*
- [x] State the hardcoded convention: always the single file `$MANIFEST_DIR/archive-pilot-ack.json`
  holding a JSON array of per-account records, each shaped exactly as already specified
  (`{"account": "gmail|logos", "acknowledged_at": "<ISO8601>", "pilot_scope": "<query>",
  "messages_processed": N, "chunk_size_verdict": "keep 1000 | adjust to <n>"}`). *(completed)*
- [x] Describe the write behavior: if the file is absent, create a one-element array; if present,
  read it and replace-or-append the record whose `"account"` matches the resolved account — never
  create a second file. *(completed)*
- [x] Confirm the immediately-following Gate check text (lines 443-448) already reads the single
  `archive-pilot-ack.json` path and needs no change (it looks for an entry whose `"account"` equals
  the resolved account; absent-or-no-match ⇒ REFUSE). *(completed: verified unchanged, no edit
  needed)*

**Timing**: 0.4 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — pilot-ack acknowledgement-record
  bullet (lines 434-442).

**Verification**:
- No reference to `archive-pilot-ack-gmail.json` / `archive-pilot-ack-logos.json` or "pick one
  convention" remains anywhere in the file.
- The acknowledgement-record text and the Gate-check text (443-448) both reference exactly one file
  path `$MANIFEST_DIR/archive-pilot-ack.json` and the same array-of-records / `"account"`-keyed shape.

---

### Phase 3: Finding 5 — Refresh README.md for multi-account [COMPLETED]

**Goal**: Bring `.claude/extensions/email/README.md` up to date with the multi-account
(`--account`/`--logos`) feature, mirroring terminology already in `commands/email.md` and
`skill-email-cleanup/SKILL.md` post-817.

**Tasks**:
- [x] Lines 16-17 (Purpose): reword the Gmail-only framing to be account-generic, e.g. "...a safe,
  auditable way to triage a mailbox (Gmail by default, or the Logos/Protonmail-Bridge account via
  `--account logos` / `--logos`): read a census of senders/folders...". *(completed)*
- [x] Add a short "Accounts" subsection under "Using `/email`" mirroring `commands/email.md`'s
  Accounts block (lines 36-46): default `account=gmail`; `--account logos` / `--logos` selects the
  Logos account (folder-based: `folder:Logos`, `folder:Logos/.Archive`, no `.All_Mail`/`.Spam`);
  unknown values rejected loudly (never silent gmail fallback); `account=logos` passes a light
  liveness check first. *(completed)*
- [x] Lines 106-112 (`--archive` bullet): reword "operates on All Mail (`folder:Gmail/.All_Mail`,
  ~64k messages)" to name both accounts' archive folders and sizes — gmail All Mail
  `folder:Gmail/.All_Mail` ~64k; logos Archive `folder:Logos/.Archive` ~54 (figures pulled from
  `skill-email-cleanup/SKILL.md` lines 379-384, not re-derived). *(completed)*
- [x] Lines 114-125 (`/email --sync` section): reword heading and body to be account-generic —
  "reconcile the cleanup to the account's server", channel defaults from account (`gmail` or
  `logos`), and the Archived/Deleted bullets should name both accounts' target folders (All Mail /
  Trash for gmail; the real Archive / Trash folders for logos), matching `skill-email-sync/SKILL.md`
  "What sync does" (lines 18-32). *(completed)*
- [x] (Optional polish) line 39 file-inventory entry for `archive-mode-risk.md`: generalize
  "All Mail blast radius" to "account archive blast radius". *(completed)*
- [x] Preserve every existing `/email` command mention in the README (doc-lint requires commands
  listed in the manifest to be mentioned in README.md). *(completed: verified via grep, all
  `/email` mentions intact)*

**Timing**: 0.6 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/README.md` — Purpose (16-17), new Accounts subsection, `--archive`
  bullet (106-112), `/email --sync` section (114-125), optional line 39.

**Verification**:
- `--account` and `--logos` now appear in the README (previously absent by full-file grep).
- Both `~64` (logos) and `~64k`/`~64,000` (gmail) archive sizes appear; no unconditional "operates
  on All Mail" framing remains.
- `/email` command references intact.

---

### Phase 4: Finding 6 — Add --sync channel/account mismatch warning [COMPLETED]

**Goal**: Add an explicit `--sync` channel/account mismatch warning at the actual enforcement point
(`skill-email-sync/SKILL.md` Stage 3), then align the descriptive text in `commands/email.md` and
the "explicit override wins" bullet so the two files do not re-diverge.

**Tasks**:
- [x] `skill-email-sync/SKILL.md` Stage 3 (lines 92-97): add a mismatch check/warning — if an
  explicit channel override was given and it does not match the resolved `account`'s default channel
  (e.g. `account=gmail` but `--sync logos`, or vice versa), surface it as an explicit warning inside
  the same confirmation prompt (e.g. "Warning: the channel to sync (`logos`) does not match the
  account this cleanup ran against (`gmail`) — proceed anyway?"); never silently sync a mismatched
  channel. Edit this file first (it is the enforcement point). *(completed)*
- [x] `skill-email-sync/SKILL.md` "explicit override wins" bullet (lines 65-67): add a trailing
  clause noting the override is still checked for mismatch at Stage 3 ("...always takes precedence —
  but see Stage 3, which surfaces a warning if this override disagrees with the resolved account").
  *(completed)*
- [x] `commands/email.md` `--sync [channel]` Input bullet (lines 32-34): add a clause that if the
  explicit channel disagrees with the resolved account's default channel, `skill-email-sync`'s
  Stage 3 confirm surfaces a mismatch warning before proceeding — the override still wins if the
  user confirms. *(completed)*
- [x] `commands/email.md` `<interactive_errors>` (lines 214-217): add a bullet documenting the
  mismatch-warning path, consistent with the other documented interactive/confirmation behaviors
  (e.g. "Explicit `--sync <channel>` disagrees with the resolved `account` -> Stage 3 surfaces an
  explicit mismatch warning; proceeding is still possible on explicit user confirmation.").
  *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` — Stage 3 confirm block (92-97),
  "explicit override wins" bullet (65-67).
- `.claude/extensions/email/commands/email.md` — `--sync` Input bullet (32-34), `<interactive_errors>`
  (214-217).

**Verification**:
- Both `skill-email-sync/SKILL.md` and `commands/email.md` mention the channel/account mismatch
  warning (grep for "mismatch"/"does not match"); neither is silent on it.
- Stage 3 still instructs including the channel name and now also the mismatch check.

---

### Phase 5: Completeness and doc-lint verification gate [COMPLETED]

**Goal**: Confirm all four findings are fully applied, both finding-6 files are mutually consistent,
and the extension doc-lint still passes.

**Tasks**:
- [x] Re-grep each target file to confirm no stale Gmail-only holdouts remain for the four findings
  (title "All Mail Scope"; `mbsync gmail`; `archive-pilot-ack-gmail.json`; README missing
  `--account`; mismatch warning present in both finding-6 files). *(completed: title holdout gone,
  archive-mode-risk.md's only remaining `mbsync` reference is the account-generic
  `mbsync <account-channel>`; `archive-pilot-ack-gmail/logos.json` appear only in the
  never-used-filename exclusion text; README has 4 `--account` occurrences; both
  skill-email-sync/SKILL.md and commands/email.md contain "mismatch" text)*
- [x] Confirm no edit accidentally touched a span task 817 owned (diff review scoped to the four
  findings' regions only). *(completed: `git diff --stat` shows only the five plan-scoped files
  plus a pre-existing uncommitted EXTENSION.md diff from task 817 that this task did not touch)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the email extension reports no
  FAIL (overall exit 0, or email-specific PASS if other extensions are unaffected). *(completed:
  `[email]` section reports PASS with only a pre-existing, unrelated WARN about the
  skill-email-implementation routing target not being deployed; `core` and `lean` FAILs in the
  overall summary are pre-existing and out of scope for this task)*

**Timing**: 0.2 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification only).

**Verification**:
- `check-extension-docs.sh` PASS for the email extension (no new FAIL introduced).
- All four findings' completeness greps return the expected post-edit state.

---

## Testing & Validation

- [x] `bash .claude/scripts/check-extension-docs.sh` PASS (email extension has no FAIL after edits).
- [x] `archive-mode-risk.md`: title has no "All Mail Scope"; blast-radius table shows both gmail and
  logos sizes; Gate #1 has both confirmation strings; no `mbsync gmail` literal.
- [x] `skill-email-cleanup/SKILL.md`: single `archive-pilot-ack.json` convention only; no per-account
  filenames or "pick one convention" text.
- [x] `README.md`: `--account`/`--logos` documented; both archive sizes present; `--sync` section
  account-generic; `/email` command references intact.
- [x] `skill-email-sync/SKILL.md` + `commands/email.md`: mismatch warning documented in both.

## Artifacts & Outputs

- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (edited)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (edited)
- `.claude/extensions/email/README.md` (edited)
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` (edited)
- `.claude/extensions/email/commands/email.md` (edited)
- `specs/818_email_extension_doc_consistency_sweep/summaries/01_email-doc-consistency-sweep-summary.md`
  (implementation summary, produced by /implement)

## Rollback/Contingency

All changes are doc-only and confined to `.claude/extensions/email/`. If a change causes a doc-lint
FAIL or an unwanted wording regression, revert the affected file(s) via `git checkout --
<file>` (edits are additive/rewording, so per-file revert is safe and independent). No behavioral
rollback is needed since no code or wrapper logic changes.
