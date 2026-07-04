# Research Report: Task #815

**Task**: 815 - Revise the email/ extension in the .claude/ agent system to support multiple
email accounts, drawing on the nvim-extension handoff report at
`/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md`,
aligning it with the multi-account changes being made in the .dotfiles/ NixOS config.
**Started**: 2026-07-04T20:14:30Z
**Completed**: 2026-07-04T20:45:00Z
**Effort**: Medium (5 files touched: 1 command, 2 skills, 1 EXTENSION.md doc section, 1 manifest
keyword tweak; ~80-150 changed lines total; no new binaries, no agent/hook changes)
**Dependencies**: `.dotfiles` task 79 (wrapper multi-account support) — status `researched`, NOT
yet planned or implemented. This is a **hard blocking dependency**, not a soft one — see Risks.
**Sources/Inputs**:
- `/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md`
  (the authoritative brief for this task)
- `/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md`
  (companion wrapper-side design — ground-truths the exact folder tokens this task must consume)
- `/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/state.json` entry (task 79
  status = `researched`, not yet implemented)
- `.claude/extensions/email/manifest.json`, `commands/email.md`,
  `skills/skill-email-cleanup/SKILL.md`, `skills/skill-email-sync/SKILL.md`, `EXTENSION.md`,
  `hooks/mail-guard.sh`, `context/project/email/domain/wrapper-contracts.md`,
  `context/project/email/domain/archive-mode-risk.md`,
  `context/project/email/patterns/bulk-bucket-review.md`,
  `context/project/email/email-preferences.md` (all read in full)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The nvim `email/` extension is entirely Gmail-hardcoded today across 3 files:
  `commands/email.md` (arg parsing, `--archive` scope, help text), `skills/skill-email-cleanup/SKILL.md`
  (`BASE_QUERY` derivation, all wrapper invocations), and `skills/skill-email-sync/SKILL.md`
  (mbsync channel default). `EXTENSION.md` and `manifest.json` need smaller doc/keyword touches.
  `hooks/mail-guard.sh` needs **no change** — confirmed by direct inspection: it allowlists by
  binary name only (`ALLOWED_BINARIES` unchanged by task 79) and its deny pattern
  `rm[[:space:]].*Mail` is account-agnostic.
- **Hard sequencing blocker**: `.dotfiles` task 79 (the wrapper binaries) is status `researched`
  only — not planned, not implemented, not switched in via `home-manager switch`. The wrappers at
  `agent-tools.nix:70-72` still hard-reject any `--account` value other than `gmail`. If this
  task's extension edits are implemented and shipped now, every `/email --logos` invocation would
  error at the wrapper's preamble gate. This task's implementation should either (a) wait for
  task 79 to land + switch, or (b) implement the extension changes now but gate them so
  `/email --logos` is not exercised/documented as working until task 79 lands — the research
  itself (this report) can and should proceed regardless, since it only requires reading, not the
  live wrapper.
- Task 79's companion report (`02_wrapper-multi-account.md`) supplies ground-truth values this
  extension must consume: the Logos account is **folder-based, not label-based** — real local
  folders are `INBOX` (bare `folder:Logos`), `Sent`, `Archive`, `Drafts`, `Trash` (dot-prefixed
  maildir++ dirs; confirmed via live `notmuch count` probes). There is **no** `All_Mail` and
  **no** `Spam` for Logos. The wrapper resolves account scope via `folder:` queries exclusively
  (tag-based `+logos`/`+gmail` scoping is confirmed inert in the live database) — the extension
  side must follow the same `folder:`-only convention, never introduce a `tag:logos` query.
- Recommended concrete design for each of the 5 target files, detailed below in Findings and
  ready to hand to `/plan 815`.

## Context & Scope

This task revises the **UX/orchestration layer** of the nvim `.claude/extensions/email/`
extension so it can select between `gmail` (default, existing) and `logos` (new Protonmail/Bridge
account) when invoking the five frozen wrapper binaries
(`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract`). It does **not** touch the wrapper binaries themselves
(`~/.dotfiles/modules/home/email/agent-tools.nix`) — that is `.dotfiles` task 79's exclusive
scope, already researched (two reports, status `researched`). This task's scope is exactly the
handoff report's five numbered sections (§2.1–§2.6), refined here with the ground-truth folder
tokens task 79's second report subsequently confirmed live.

**Canonical authoring home**: `~/.config/nvim/.claude/extensions/email/` is the source of truth.
The consumer copy at `~/Mail/.claude/...` is downstream (synced via the extension loader) and
must never be edited directly — this applies to whichever agent later implements this task's plan.

## Findings

### File-by-file changes required

#### 1. `commands/email.md` — add the account dimension

Current state (verified by reading the file in full, lines 1-149):
- Frontmatter `description` and body are Gmail-worded throughout ("reconcile ... to Gmail", "All
  Mail (~64k messages)" at lines 2, 9-12, 24, 28, 109-128).
- Argument Parsing `<step_2>` (lines 43-51) strips `--all`/`--archive` from `$ARGUMENTS` and
  hardcodes `scope=archive -> folder:Gmail/.All_Mail` (line 47).
- `<sync_path>` (lines 80-92) passes `args: "channel={channel or gmail}"` with no account
  dimension at all.
- Error Handling section (lines 133-148) has no unknown-account case.

Required changes:
1. Add an `--account <gmail|logos>` flag (default `gmail`) plus a `--logos` shorthand, parsed in
   a new step alongside the existing `--all`/`--archive` flag strip (step_2). Thread the resolved
   `account` value into the cleanup-path delegation args: `args: "account={gmail|logos},
   mode=..., scope=..., focus_hint=..."`.
2. Update `<sync_path>` to pass `args: "account={account}, channel={channel or <account-default>}"`
   so `skill-email-sync` can default the mbsync channel from the resolved account (see file 3
   below) rather than always defaulting to `gmail`.
3. Give `--archive` per-account meaning at the command layer: document that for `account=logos`,
   `--archive` maps to the real `folder:Logos/.Archive` (not `.All_Mail`, which does not exist for
   Logos) — update the flag description (currently line 24, hardcoded to
   `folder:Gmail/.All_Mail`).
4. Add an `<interactive_errors>` or `<execution_errors>` entry for "Unknown account value (e.g.
   `--account work`)" -> surface the wrapper's actionable rejection, never a silent Gmail
   fallback (per the handoff's Verification §3 item 5).
5. Conditionalize the Gmail-specific prose in the description and Safety Notes section (lines 2,
   9-12, 104-129) — e.g. "reconcile the cleanup to the account's server" instead of "to Gmail",
   with Gmail as the illustrative default example.

#### 2. `skills/skill-email-cleanup/SKILL.md` — the load-bearing edit

Current state (verified, lines 1-422):
- The args table (lines 15-22) has only `mode` and `scope`, no `account`.
- Stage 0 (lines 56-70) hardcodes `BASE_QUERY`: `scope=inbox -> "folder:Gmail"`,
  `scope=archive -> "folder:Gmail/.All_Mail"` (line 60-61).
- Every wrapper invocation across Stages 1-6 (both `mode=default` at lines 82-136 and `mode=all`
  at lines 139-317) invokes `email-census`/`email-classify`/`email-archive-confirmed`/
  `email-delete-confirmed`/`email-unsubscribe-extract` with **no `--account` flag anywhere**.
- The Archive Scope section (lines 320-384) is written exclusively in Gmail terms
  ("All Mail is the archive of record (~64k messages)").

Required changes:
1. Add `account` to the args table (line 16-22): `account` = `gmail` (default, no flag) /
   `logos` (`--account logos` or `--logos`).
2. Make Stage 0's `BASE_QUERY` derivation account-aware:
   - `account=gmail, scope=inbox` -> `folder:Gmail` (unchanged)
   - `account=gmail, scope=archive` -> `folder:Gmail/.All_Mail` (unchanged)
   - `account=logos, scope=inbox` -> `folder:Logos` (bare root = INBOX, confirmed live by
     `.dotfiles` task 79's report 02, folder-scoped — do NOT use `tag:inbox AND tag:logos`; that
     tag scheme is confirmed **inert** in the live notmuch database, all counts 0)
   - `account=logos, scope=archive` -> `folder:Logos/.Archive` (the real Proton folder; there is
     no `.All_Mail` or `.Spam` for Logos — confirmed via live `notmuch count` probes in task 79's
     report 02: only `.Sent`, `.Archive`, `.Drafts`, `.Trash` exist as real dot-prefixed folders;
     non-dot `INBOX`/`Sent`/`Trash`/`Drafts`/`Archive` subdirectories are empty stray dirs and
     must never be queried)
3. Pass `--account <account>` to **every** wrapper invocation once task 79 lands: the census
   (Stage 1, line 84 default-mode / Stage 1 `--all` mode line 173), the classify calls (line 89
   default-mode `email-classify --limit 50 "<CURSOR_QUERY>"`; the `--all`-mode sweep loop lines
   190-204; the count-probe lines 174-180), and the execute calls (`email-archive-confirmed`/
   `email-delete-confirmed` at lines 127-129 default-mode and 284-286 `--all`-mode). Gmail stays
   the default so a bare `/email` (no flags) is byte-for-byte unchanged.
4. The cursor rule (Stage 2, lines 94-113) is account-agnostic as designed and needs **no
   change**: because `CURSOR_QUERY` is built on top of the now-account-aware `BASE_QUERY`, a
   Gmail pass and a Logos pass naturally scope to disjoint folders and never collide on the same
   `+proposed-*` tags. Confirm (do not silently assume) that this still holds once `--account` is
   threaded through — the current text already notes this at lines 96-98 and remains correct.
5. Archive Scope section (lines 320-384): reword the account-specific framing. The "All Mail is
   the archive of record (~64k messages)" framing (line 329) is Gmail-specific; for Logos the
   parallel archive-of-record is the real `Archive` folder (54 messages per the live probe — much
   smaller blast radius than Gmail's ~64k). The **pilot gate** (lines 360-384) should remain
   required for both accounts independently — do not let a Gmail pilot-ack satisfy a Logos
   archive-scope run, and vice versa (recommend keying `archive-pilot-ack.json` per account, e.g.
   a top-level `"account"` field in the ack JSON, or separate ack files, so the gate is not
   silently satisfied cross-account by an unrelated pilot).
6. `MAX_BATCH_SIZE=50`/`PLAN_EXPIRY_DAYS=7`/confidence constants (lines 385-394) remain
   account-agnostic per task 79's own design decision (these constants live in the frozen wrapper
   and are not parameterized per account) — no change needed here.

#### 3. `skills/skill-email-sync/SKILL.md` — account-to-channel default

Current state (verified, lines 1-107):
- Line 50: "The default channel is `gmail`... The user may override it as the argument to
  `--sync`".
- Lines 22-27 describe Gmail-specific semantics ("land in All Mail", "Trash ... ~30 days in
  Gmail").

Required changes:
1. Accept the `account` arg (threaded from `commands/email.md`'s updated `<sync_path>` — see file
   1 above) and default the mbsync channel to the active account's group: `account=gmail ->
   channel=gmail` (unchanged), `account=logos -> channel=logos` (the group already exists per
   `mbsync.nix:190`, confirmed by the handoff report). Preserve the existing override behavior
   (`/email --sync <explicit-channel>` still wins over the account-derived default).
2. Preserve the **never `mbsync -a`** invariant verbatim (line 36 of `wrapper-contracts.md` §7a
   and this skill's own framing) — `--sync logos` must resolve to `mbsync logos`, never
   `mbsync -a`. This is already the skill's design (single-channel invocation, Stage 4, lines
   77-87) and needs no structural change, only the default-channel resolution logic in item 1.
3. Conditionalize the Gmail-specific "What sync does" prose (lines 18-27): Proton's Archive/Trash
   are real, non-overlapping maildir folders (not Gmail's label model where every message is
   implicitly a member of All Mail) — the "moved by `email-archive-confirmed` leave the inbox and
   land in All Mail" line is Gmail-specific and should be generalized or given a parallel Logos
   clause ("...land in Archive/Trash, the account's real IMAP folders").

#### 4. `hooks/mail-guard.sh` — NO CHANGE (confirmed)

Read in full (98 lines). `ALLOWED_BINARIES` allowlists by binary **name** only
(`email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`,
`email-unsubscribe-extract`) — task 79 adds an `--account` flag to these five existing binaries,
it does not add or rename any binary. `DENY_PATTERNS`' `rm[[:space:]].*Mail` pattern still covers
both `~/Mail/Gmail/` and `~/Mail/Logos/` paths generically (it matches any `rm ... Mail`
substring, not a Gmail-specific path). **No edit needed.** State this explicitly in the
implementation summary/PR so a reviewer doesn't attempt to "fix" a non-issue (per the handoff's
explicit instruction).

#### 5. `manifest.json` — optional keyword auto-detection

Current `keyword_overrides.email.keywords` (verified,
`["inbox", "email", "gmail", "himalaya", "notmuch", "unsubscribe", "junk mail", "draft reply",
"mbsync", "aerc", "mail triage"]`) has no Logos/Proton terms. Low-priority addition: append
`"logos"`, `"protonmail"`, `"proton"` so account-flavored task descriptions route to `email` task
type automatically. Not required for `/email --logos` to function — purely a routing
convenience. `routing`/`merge_targets` blocks need no change.

#### 6. `EXTENSION.md` — document multi-account (merge-source propagation)

`EXTENSION.md` is the merge source for the `extension_email` section of `.claude/CLAUDE.md`
(confirmed via `manifest.json`'s `merge_targets.claudemd`). Required additions:
- Command table: extend the `/email` row (or add a row) documenting `--account <gmail|logos>` /
  `--logos` shorthand and per-account `--archive` semantics.
- Safety Invariants list: add an "account isolation" bullet (never `mbsync -a`, folder-scoped
  account resolution, no tag-based account scoping) and a per-account `--archive` semantics
  bullet (Proton has no All-Mail label model; `--archive` maps to a real `Archive` folder for
  Logos vs. the `All_Mail` label-folder for Gmail).
- This propagates to `.claude/CLAUDE.md`'s `extension_email` section on the next sync/merge —
  verify the merge pipeline (`check-extension-docs.sh` or the sync command) picks up the new
  content once edited.

### Context files that do NOT need changes for this task's scope

- `context/project/email/domain/wrapper-contracts.md` — this is a **read-only summary of the
  frozen `.dotfiles` contract**; it should be updated only after task 79's wrapper changes
  actually land (to reflect the new `--account` enum, the `ACCOUNT_FOLDER`/`ACCOUNT_MBSYNC_GROUP`
  resolver, etc.). Updating it now, before task 79 lands, would describe wrapper behavior that
  does not yet exist. Recommend a follow-up task (or a phase in this task's plan explicitly
  marked "post-task-79-landing") to refresh this file once the wrapper ships.
- `context/project/email/domain/archive-mode-risk.md`, `patterns/bulk-bucket-review.md`,
  `standards/recall-on-keep-bias.md` — read in full; these describe risk/pattern/standard
  reasoning that is largely account-agnostic (confidence rollup, bucket construction, recall
  bias). `archive-mode-risk.md` does reference `folder:Gmail/.All_Mail` illustratively (lines 3,
  10, 74) but its *reasoning* (asymmetric blast radius, recoverability) applies unchanged to
  Logos's `Archive`/`Trash` — a light editorial pass to generalize the illustrative folder tokens
  is optional polish, not required for functional correctness.
- `context/project/email/email-preferences.md` — read in full (142 lines); already contains a
  Proton-aware classify note (lines 70-75, documenting that certain Proton-marketing sender rules
  must not over-generalize to a blanket Protonmail-account block). Per the handoff report,
  "Logos-tuned classify preferences" are explicitly **out of scope** for this extension task —
  they are a separate, later refinement handled by the user directly.

## Decisions

- **Sequencing**: this task's *implementation* (a future `/plan 815` + `/implement 815`) should
  be sequenced after `.dotfiles` task 79 lands and is switched in via `home-manager switch`, per
  the handoff report's explicit "Hard sequencing constraint" (§0). This research report itself
  has no such dependency (it only requires reading files, not exercising the live wrapper), so
  producing it now is correct and unblocks planning — but the plan produced from this report
  should either (a) note the task-79 landing as an explicit implementation precondition/blocker,
  or (b) scope the implementation to land the extension-side edits in a state where `--account
  logos`/`--logos` are parsed and documented but explicitly marked non-functional pending task 79
  (e.g., a precondition check similar to the existing `$PATH` check, but checking whether the
  wrapper accepts `--account logos` before proceeding, failing actionably otherwise).
- **Folder-scoping convention**: consistently use `folder:` query tokens for account scoping,
  never `tag:<account>`, matching the wrapper design's own finding that the notmuch `postNew`
  tag-application hooks are currently inert in the live database. This applies to `BASE_QUERY`,
  `CURSOR_QUERY`, and any future extension-side query construction.
- **Pilot gate scoping**: recommend per-account pilot acknowledgement (not a single shared
  `archive-pilot-ack.json`) so a Gmail archive-scope pilot does not silently license a full-scale
  Logos archive-scope run against an unvalidated classifier/folder set, or vice versa. This is a
  new decision not explicitly present in the handoff report and should be flagged to the planner
  as a design choice requiring confirmation (see Risks).

## Risks & Mitigations

- **Risk (hard blocker)**: implementing and shipping this task's extension edits before
  `.dotfiles` task 79 lands + `home-manager switch` produces a broken `/email --logos` (errors at
  the wrapper's preamble gate, `agent-tools.nix:70-72`). **Mitigation**: treat task 79's landing
  as an explicit precondition in the implementation plan; do not interleave. Track task 79's
  status (`researched` as of this report) before scheduling `/implement 815`.
- **Risk**: task 79 is itself only `researched`, not `planned`/`implemented` — its exact final
  design (variable names, exact code shape) could still shift during its own planning/
  implementation phases, even though its two research reports are detailed and specific. The
  folder tokens (`folder:Logos`, `folder:Logos/.Archive`, etc.) are read-only/query-side facts
  independent of the wrapper's internal implementation, so they are low-risk to hardcode into
  this extension now; but the exact CLI flag surface (e.g. whether the wrapper ultimately spells
  it `--account logos` vs. something else) should be re-verified against the landed wrapper's
  `--help` output before this task's implementation finalizes wrapper-facing flag names.
  **Mitigation**: `/implement 815` (whenever scheduled) should run `email-census --help` (once
  the wrapper lands) to reconfirm the exact flag spelling before finalizing the command/skill
  edits.
- **Risk**: cross-account manifest confusion — task 79's report 02 flags that a manifest built
  under `--account logos` fed to a mutation binary invoked with the default `gmail` account would
  resolve folders incorrectly (no manifest-embedded `account` field decided yet on the wrapper
  side). **Mitigation**: this extension's skill-email-cleanup edits must always pass the SAME
  resolved `account` value to every wrapper call within one invocation (census, classify, and
  execute all in the same `/email --logos` run) — never let account resolution drift mid-flow.
  This is naturally satisfied if `account` is resolved once in Stage 0 and threaded through
  unchanged, as recommended above.
- **Risk**: silently sending a Gmail-shaped query (`folder:Gmail/.All_Mail`) for a Logos
  `--archive` run would produce a false-empty result (no error, just zero matches) rather than a
  loud failure, because the query is syntactically valid notmuch even if scoped to the wrong
  account. **Mitigation**: the handoff report and this research both explicitly call out
  `account=logos, scope=archive -> folder:Logos/.Archive` as a required branch — the plan and
  implementation must not leave a fallthrough case that defaults to the Gmail token for any
  non-gmail account.

## Context Extension Recommendations

- **Topic**: Post-landing wrapper-contract refresh.
  **Gap**: `context/project/email/domain/wrapper-contracts.md` will become stale (still describes
  `--account gmail` as the sole reserved value) the moment task 79's wrapper lands.
  **Recommendation**: file a follow-up task (or a final phase of this task's plan, sequenced
  after task 79 lands) to refresh `wrapper-contracts.md` §2 and §11 with the real `--account`
  enum and the per-account folder-token table, re-verified against the landed
  `agent-tools.nix`.

## Appendix

### Search queries / commands used

- Direct file reads (no web search needed — this is a meta/codebase-only task):
  `/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/reports/01_nvim-extension-handoff.md`
  `/home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account/reports/02_wrapper-multi-account.md`
  `.claude/extensions/email/manifest.json`
  `.claude/extensions/email/commands/email.md`
  `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`
  `.claude/extensions/email/skills/skill-email-sync/SKILL.md`
  `.claude/extensions/email/EXTENSION.md`
  `.claude/extensions/email/hooks/mail-guard.sh`
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
  `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
  `.claude/extensions/email/context/project/email/email-preferences.md`
- `jq '.active_projects[] | select(.project_number==79)' /home/benjamin/.dotfiles/specs/state.json`
  — confirmed task 79 status = `researched` (not yet planned/implemented).
- `find /home/benjamin/.dotfiles/specs/079_email_wrappers_multi_account -type f` — confirmed both
  reports plus `.orchestrator-handoff.json` exist; no plan/summary artifacts yet.

### References

- `.dotfiles` task 79 (`specs/079_email_wrappers_multi_account/`) — parent/prerequisite task,
  status `researched`.
- `.dotfiles` task 72 (parent of task 79) — frozen wrapper contract origin (referenced throughout
  `wrapper-contracts.md`).
