# Implementation Summary: Task #815

**Completed**: 2026-07-04
**Duration**: ~1 hour

## Overview

Revised `.claude/extensions/email/` to support a second mailbox account (Logos, Protonmail
Bridge) alongside the existing Gmail-only path, following the plan's approach (b)
("additive + gated"): Phases 1-5 (the full landable scope) are implemented and verified; Phase 6
(live end-to-end verification against real wrapper binaries) remains intentionally
`[BLOCKED]` pending `.dotfiles` task 79 landing, exactly as scoped.

## What Changed

- `.claude/extensions/email/commands/email.md` — added a `--account <gmail|logos>` / `--logos`
  selector (default `gmail`, parsed before the `--sync` vs. cleanup route split so it applies
  uniformly to both paths); threaded `account={gmail|logos}` into both the cleanup-path and
  sync-path delegation args; documented per-account `--archive` semantics
  (`folder:Gmail/.All_Mail` vs `folder:Logos/.Archive`); added an unknown-`--account` error entry
  and an actionable precondition gate for `account=logos` (fails loudly, never a silent Gmail
  fallback, pending task 79); generalized Gmail-specific prose in the description and Safety
  Notes to speak in terms of "the account's server/folders".
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — the load-bearing edit. Added
  `account` to the args table; added an "Account Precondition Gate" section gating
  `account=logos` before any binary call; made Stage 0's `BASE_QUERY` derivation account-aware
  via a 2x2 table (`folder:Gmail`/`folder:Gmail/.All_Mail` for gmail,
  `folder:Logos`/`folder:Logos/.Archive` for logos — folder tokens only, zero `tag:<account>`
  usage, zero fallthrough to a Gmail token on a non-gmail path); passed `--account <account>` to
  every wrapper invocation (census, classify — including the `--all` sweep loop, count probes,
  and residual passes — and both execute binaries) using the SAME value resolved once in Stage 0;
  confirmed the cursor rule stays account-agnostic because it builds on the now-disjoint
  `BASE_QUERY` folder subtrees; reworded the Archive Scope section with a per-account
  archive-folder/blast-radius table (Gmail All Mail ~64k messages vs. Logos Archive ~54 messages
  per the live probe, same gates applying regardless of scale); implemented per-account
  pilot-gate scoping (account-keyed `archive-pilot-ack.json` record/files, so a Gmail ack never
  licenses a Logos archive-scope run or vice versa).
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` — accepts the threaded `account`
  arg and defaults the mbsync channel from it (`gmail` -> `gmail`, `logos` -> `logos`), with an
  explicit channel override always taking precedence; preserved the never-`mbsync -a` invariant
  verbatim (explicit new MUST NOT rule); gave the "What sync does" prose a parallel Logos clause
  (real IMAP Archive/Trash folders vs. Gmail's All Mail/Trash labels).
- `.claude/extensions/email/EXTENSION.md` — extended the `/email` command table with the new
  `--account`/`--logos` row and per-account `--archive` semantics; added Safety Invariants
  bullets for account isolation (folder-scoped only, never `tag:<account>`, never `mbsync -a`),
  per-account `--archive` semantics, the documented-but-gated posture of `--logos`, and an
  explicit note on why `hooks/mail-guard.sh` needs no change (name-based allowlist; task 79 adds
  a flag to existing binaries, not new binary names).
- `.claude/extensions/email/manifest.json` — appended `"logos"`, `"protonmail"`, `"proton"` to
  `keyword_overrides.email.keywords` for optional task-routing convenience; JSON validated.
- `.claude/extensions/email/hooks/mail-guard.sh` — confirmed UNCHANGED (verified via `git diff`
  across every phase commit): it allowlists the five wrapper binaries by name only, and task 79
  adds an `--account` flag to those same five binaries rather than new binary names, so the
  allowlist needs no edit.

## Decisions

- Account parsing runs as its own step (Stage/step 1) BEFORE the `--sync`-vs-cleanup route
  determination in `commands/email.md`, so the resolved account applies uniformly to both paths
  rather than being duplicated per route.
- `account` is resolved exactly once per invocation (Stage 0 in skill-email-cleanup) and threaded
  unchanged to every wrapper call, the pilot gate, and both `BASE_QUERY` branches — never
  re-resolved mid-flow, per the plan's "account resolution drifts mid-flow" risk mitigation.
- Per-account pilot-gate scoping was implemented as an account-keyed record/file convention
  (either a top-level `"account"` field or separate per-account ack files) rather than a single
  shared `archive-pilot-ack.json`, so a Gmail pilot-ack can never license a Logos archive-scope
  run.
- The `account=logos` precondition gate is documented as an explicit, actionable, LOUD failure
  (never a silent continuation against Gmail) in three places for defense in depth:
  `commands/email.md` argument parsing, `commands/email.md` Error Handling, and
  `skill-email-cleanup/SKILL.md`'s own "Account Precondition Gate" section.

## Plan Deviations

- **Task 5.5** (verify `EXTENSION.md` additions propagate to `.claude/CLAUDE.md`'s
  `extension_email` section via the sync/merge pipeline) — altered: verified the merge
  MECHANISM and CONFIG are correct (`manifest.json`'s `merge_targets.claudemd` matches the
  pattern used by other loaded extensions; `generate_claudemd` in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` concatenates each loaded extension's
  `EXTENSION.md` by dependency order), but could NOT observe end-to-end propagation because
  `.claude/extensions.json` shows this repo currently has only `core`, `memory`, `nix`, `nvim`
  loaded — the `email` extension itself is not in the loaded set, so `.claude/CLAUDE.md` has no
  "Email Extension" section at all yet, independent of this task's edits (pre-existing
  condition). Triggering the extension picker's load/sync is a user-driven action with
  repo-wide side effects (regenerates the whole `CLAUDE.md`) and is out of scope for this
  implementation.
- **Testing & Validation item** "(Phase 6, gated) `email-census --help` + live `/email --logos`
  end-to-end once task 79 lands" — deferred to Phase 6 per the explicit scoping instruction for
  this dispatch: Phase 6 genuinely cannot be verified until `.dotfiles` task 79's wrapper
  binaries land and `home-manager switch` activates them. Phase 6 remains `[BLOCKED]` in the
  plan, exactly as designed.

## Verification

- Build: N/A (markdown/JSON configuration, no build step)
- Tests: N/A (no automated test suite for agent-interpreted markdown specs; verified via
  targeted greps and textual consistency checks — see Phase 5)
- Files verified: Yes
  - Zero `tag:gmail`/`tag:logos` occurrences across the three edited skill/command files.
  - Every `folder:Gmail` occurrence is textually scoped to an `account=gmail` branch; zero
    fallthrough on a non-gmail path.
  - Bare `/email` (no flags) parses to `account=gmail, mode=default, scope=inbox` — identical to
    pre-change behavior.
  - `hooks/mail-guard.sh` diff is empty across all phase commits.
  - `.claude/scripts/check-extension-docs.sh`: the `[email]` extension section reports
    OK/PASS (unrelated pre-existing FAILs in the `core`/`lean` extensions are out of scope).
  - `.claude/extensions/email/manifest.json` validated as well-formed JSON after the
    keyword-list edit.

## Notes

- **Phase 6 is intentionally `[BLOCKED]`, not a failure.** It requires `.dotfiles` task 79's
  wrapper binaries (which must accept `--account logos`) to land and be activated via
  `home-manager switch` before `email-census --help` re-confirmation and live `/email --logos`
  end-to-end verification can run. Task 79 is currently `researched` only.
- **Recommended follow-up**: once `.dotfiles` task 79 lands, either resume Phase 6 of this
  plan directly, or spawn a small follow-up task (e.g. via `/spawn 815` or a new `/task`) scoped
  to: (1) re-confirming the wrapper's exact `--account` flag spelling via `email-census --help`,
  (2) exercising `/email --logos` end-to-end (census -> classify -> a small archive/delete dry
  run) against the live Logos maildir, and (3) refreshing
  `context/project/email/domain/wrapper-contracts.md` §2/§11 with the landed `--account` enum
  and folder-token table.
- Phases 1-5 constitute the complete, landable deliverable per the plan's own Rollback/
  Contingency section: a bare `/email` (Gmail) is fully functional and unchanged; `/email --logos`
  is parsed, documented, and safely gated rather than silently broken.
