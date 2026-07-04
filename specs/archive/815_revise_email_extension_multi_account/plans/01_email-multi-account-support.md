# Implementation Plan: Task #815

- **Task**: 815 - Revise the email/ extension in the .claude/ agent system to support multiple email accounts (Gmail + Logos/Protonmail Bridge)
- **Status**: [COMPLETED] (Phases 1-6 landed; `.dotfiles` task 79 landed and switched in, verified
  by `.dotfiles` task 80 `verify_logos_wrapper_contract_close_phase6` — all 9 wrapper-contract
  rows PASS, zero divergence)
- **Effort**: 5 hours (4.5h for landable Phases 1-5; +0.5h for the deferred, task-79-gated Phase 6)
- **Dependencies**: `.dotfiles` task 79 (email wrapper multi-account `--account` support) — status `researched` only. Soft dependency for authoring Phases 1-5 (additive, gated); HARD dependency for Phase 6 live verification. See Risks.
- **Research Inputs**: specs/815_revise_email_extension_multi_account/reports/01_multi-account-extension-revision.md
- **Artifacts**: plans/01_email-multi-account-support.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Revise the UX/orchestration layer of `.claude/extensions/email/` so `/email` can target either the
existing `gmail` account (default, unchanged) or the new `logos` (Protonmail Bridge) account, by
adding an `--account <gmail|logos>` / `--logos` selector and threading the resolved account through
the cleanup and sync skills' delegation args and notmuch `folder:` query construction. Five files
change (`commands/email.md`, `skills/skill-email-cleanup/SKILL.md`, `skills/skill-email-sync/SKILL.md`,
`EXTENSION.md`, `manifest.json`); `hooks/mail-guard.sh` is confirmed to need **no change**.

**Sequencing strategy — approach (b), additive + gated**: The `.dotfiles` task 79 wrapper binaries
(which must accept `--account logos`) are `researched` only — not implemented, not switched in. Rather
than block all work, Phases 1-5 author the account-parsing and documentation surface in an **additive,
gracefully-degrading** state: a bare `/email` (no flags) is byte-for-byte unchanged and fully
functional against the existing Gmail-only wrappers, while `/email --logos` is parsed, documented, and
routed through an **actionable precondition gate** that fails loudly (never a silent Gmail fallback)
until task 79's wrappers land. Phases 1-5 are therefore safe to land and reach `[COMPLETED]` now.
Phase 6 (live end-to-end verification of `/email --logos` and the post-landing `wrapper-contracts.md`
refresh) is the one segment that **genuinely could not be verified until task 79's binaries landed**;
it was carried as an explicitly blocked phase until task 79 landed and was switched in, at which
point `.dotfiles` task 80 (`verify_logos_wrapper_contract_close_phase6`) verified all 9 contract rows
PASS with zero divergence and nvim task 816 discharged the remaining documentation refresh, bringing
Phase 6 to `[COMPLETED]`.

### Research Integration

Integrates the file-by-file revision plan from `reports/01_multi-account-extension-revision.md`
(§Findings 1-6). Key ground-truth facts consumed:
- Logos is **folder-based, not label-based**: `folder:Logos` (bare root = INBOX),
  `folder:Logos/.Archive`, `.Sent`, `.Drafts`, `.Trash`. There is **no** `.All_Mail` and **no**
  `.Spam` for Logos. Non-dot sibling dirs are empty stray dirs and must never be queried.
- notmuch tag-based account scoping (`tag:logos` / `tag:gmail`) is confirmed **inert** in the live
  database (all counts 0). All account scoping MUST use `folder:` tokens exclusively.
- `hooks/mail-guard.sh` allowlists by binary **name** only; task 79 adds a flag to the five existing
  binaries, not new binaries — so the guard needs no edit (state this explicitly to pre-empt a
  reviewer "fixing" a non-issue).
- The frozen per-account constants (`MAX_BATCH_SIZE=50`, `PLAN_EXPIRY_DAYS=7`, confidence thresholds)
  live in the wrapper and are not parameterized per account — no change here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (meta task; roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Add an `--account <gmail|logos>` flag plus `--logos` shorthand to `/email`, defaulting to `gmail`.
- Make `skill-email-cleanup`'s `BASE_QUERY` derivation and every wrapper invocation account-aware,
  using `folder:` tokens exclusively (never `tag:<account>`).
- Default the mbsync channel in `skill-email-sync` from the resolved account (gmail->gmail,
  logos->logos), preserving the never-`mbsync -a` invariant and explicit-override behavior.
- Give `--archive` per-account meaning: `folder:Gmail/.All_Mail` for gmail vs `folder:Logos/.Archive`
  for logos (no fallthrough to a Gmail token for a non-gmail account).
- Keep the Gmail-only path byte-for-byte unchanged so a bare `/email` is functionally identical.
- Route `/email --logos` through an actionable precondition gate that fails loudly pending task 79
  (documented-but-gated), never silently falling back to Gmail.
- Document the account dimension in `EXTENSION.md` for propagation to `.claude/CLAUDE.md`'s
  `extension_email` merge section; add optional `logos`/`proton`/`protonmail` keyword routing.

**Non-Goals**:
- Editing the wrapper binaries themselves (`agent-tools.nix`) — that is `.dotfiles` task 79's scope.
- Editing `hooks/mail-guard.sh` (confirmed no change needed).
- Logos-tuned classify preferences (`email-preferences.md`) — explicitly out of scope per the handoff.
- Parameterizing the frozen per-account constants — they live in the wrapper.
- Live end-to-end validation of `/email --logos` (deferred to Phase 6, gated on task 79).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Shipping account edits before task 79 lands produces a broken/silent `/email --logos` | H | H | Approach (b): additive edits + actionable precondition gate that fails loudly; Gmail path unchanged. Phase 6 (live verify) was carried as blocked pending task 79; task 79 has since landed and Phase 6 is `[COMPLETED]` (verified by `.dotfiles` task 80, all 9 rows PASS). |
| Silent Gmail-shaped query (`folder:Gmail/.All_Mail`) sent for a Logos `--archive` run yields false-empty, not an error | H | M | No fallthrough case: every non-gmail account MUST resolve its own `folder:` branch; Phase 5 greps for any residual hardcoded `folder:Gmail` on a non-gmail path. |
| Task 79's final `--account` flag spelling could shift during its own impl | M | L | Folder tokens are query-side facts (low risk to encode now); Phase 6 re-confirms exact flag spelling via `email-census --help` once the wrapper lands. |
| Introducing a `tag:<account>` query (inert in live DB) would silently return 0 | M | L | Convention enforced in Phases 2-3 and grep-checked in Phase 5: `folder:` tokens only. |
| Account resolution drifts mid-flow (census under logos, mutate under gmail) | H | L | Resolve `account` once in Stage 0 and thread the SAME value to every wrapper call in one invocation (Phase 2). |
| Cross-account pilot-ack: a Gmail pilot silently licenses a Logos archive-scope run | M | M | Per-account pilot-gate scoping (account field in `archive-pilot-ack.json` or per-account ack files) in Phase 2. |
| EXTENSION.md edit fails to propagate to `.claude/CLAUDE.md` | L | M | Phase 5 runs `check-extension-docs.sh` and verifies the merge pipeline picks up the new content. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 (and external: `.dotfiles` task 79 landing) |

Phases within the same wave can execute in parallel.

### Phase 1: Add the account dimension to `commands/email.md` [COMPLETED]

**Goal**: Introduce the `--account <gmail|logos>` / `--logos` selector, thread the resolved account
into both the cleanup and sync delegation args, and establish the account-arg contract that Phases 2-3
consume. Additive: bare `/email` unchanged.

**Tasks**:
- [x] Add account parsing to the argument-strip step (`<step_2>`, lines ~43-51): recognize
      `--account <gmail|logos>` and the `--logos` shorthand, strip them from `$ARGUMENTS`, default to
      `account=gmail`. Keep the existing `--all`/`--archive` strip intact.
- [x] Thread `account={gmail|logos}` into the cleanup-path delegation args alongside `mode=`, `scope=`,
      `focus_hint=` (the args string `skill-email-cleanup` receives).
- [x] Update `<sync_path>` (lines ~80-92) to pass `args: "account={account}, channel={channel or
      <account-default>}"` so `skill-email-sync` can default the channel from the account (Phase 3).
- [x] Give `--archive` per-account meaning in the flag description (currently line ~24, hardcoded to
      `folder:Gmail/.All_Mail`): document that `account=logos` maps `--archive` to `folder:Logos/.Archive`.
- [x] Add an unknown-account error entry (e.g. `--account work`): surface the wrapper's actionable
      rejection; never a silent Gmail fallback.
- [x] Add an **actionable precondition gate** for `account=logos`: document that `/email --logos` is
      parsed but its wrappers require `.dotfiles` task 79 to have landed + `home-manager switch`; the
      gate checks (or instructs the skill to check) that the wrapper accepts `--account logos` before
      proceeding and fails loudly with a clear message otherwise (mirroring the existing `$PATH` check).
- [x] Generalize the Gmail-specific prose (description + Safety Notes, lines ~2, 9-12, 104-129) to
      "the account's server / real IMAP folders", keeping Gmail as the illustrative default.

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/commands/email.md` - add `--account`/`--logos` parsing, thread account into
  cleanup + sync delegation args, per-account `--archive` doc, unknown-account error, precondition gate,
  prose generalization.

**Verification**:
- Bare `/email` (no flags) parses to `account=gmail, mode=default, scope=inbox` exactly as before.
- `/email --logos --archive` parses to `account=logos, scope=archive`.
- `/email --account work` documents an actionable rejection, not a Gmail fallback.
- The account-arg contract (`account={gmail|logos}`) is defined for Phases 2-3 to consume.

---

### Phase 2: Make `skill-email-cleanup/SKILL.md` account-aware [COMPLETED]

**Goal**: The load-bearing edit — account-aware `BASE_QUERY` derivation, `--account` passthrough to
every wrapper call, and per-account pilot-gate scoping. Gmail stays the default; `folder:` tokens only.

**Tasks**:
- [x] Add `account` to the args table (lines ~15-22): `gmail` (default, no flag) / `logos`
      (`--account logos` or `--logos`).
- [x] Make Stage 0's `BASE_QUERY` account-aware (lines ~56-71):
  - `account=gmail, scope=inbox` -> `folder:Gmail` (unchanged)
  - `account=gmail, scope=archive` -> `folder:Gmail/.All_Mail` (unchanged)
  - `account=logos, scope=inbox` -> `folder:Logos` (bare root = INBOX; NOT `tag:inbox AND tag:logos` —
    that tag scheme is inert in the live DB)
  - `account=logos, scope=archive` -> `folder:Logos/.Archive` (the real Proton folder; there is no
    `.All_Mail`/`.Spam` for Logos). No fallthrough to a Gmail token for any non-gmail account.
- [x] Pass `--account <account>` to **every** wrapper invocation (resolved once in Stage 0, threaded
      unchanged): census (Stage 1 default-mode ~line 84 and `--all`-mode ~line 173), classify calls
      (~line 89 default-mode; `--all` sweep loop ~190-204; count probes ~174-180), and execute calls
      (`email-archive-confirmed`/`email-delete-confirmed` ~127-129 default and ~284-286 `--all`).
- [x] Confirm (do not silently assume) the cursor rule (Stage 2, ~94-113) remains account-agnostic:
      `CURSOR_QUERY` builds on the now-account-aware `BASE_QUERY`, so Gmail and Logos passes scope to
      disjoint folders and never collide on `+proposed-*` tags.
- [x] Reword the Archive Scope section (~320-384): the "All Mail is the archive of record (~64k)"
      framing is Gmail-specific; for Logos the parallel archive-of-record is the real `Archive` folder
      (~54 messages per the live probe — much smaller blast radius). Keep the pilot gate required for
      **both** accounts independently.
- [x] Implement per-account pilot-gate scoping: key `archive-pilot-ack.json` per account (top-level
      `"account"` field, or separate ack files) so a Gmail pilot-ack cannot silently satisfy a Logos
      archive-scope run, or vice versa.
- [x] Honor the precondition gate from Phase 1 for `account=logos` (fail loudly if the wrapper does not
      accept `--account logos`); do not exercise the Logos path as working until task 79 lands.

**Timing**: ~1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` - account arg, account-aware
  `BASE_QUERY`, `--account` passthrough on all wrapper calls, per-account pilot gate, Archive Scope
  rewording.

**Verification**:
- Every branch of `BASE_QUERY` resolves via a `folder:` token; no `tag:<account>` anywhere.
- No fallthrough leaves a non-gmail account on a `folder:Gmail*` token.
- The same resolved `account` is passed to census, classify, and execute within one invocation.
- Pilot ack is per-account; a Gmail ack does not license a Logos archive run.
- `MAX_BATCH_SIZE`/`PLAN_EXPIRY_DAYS`/confidence constants are unchanged (account-agnostic).

---

### Phase 3: Default the mbsync channel from the account in `skill-email-sync/SKILL.md` [COMPLETED]

**Goal**: Accept the threaded `account` arg and default the mbsync channel to the active account's
group, preserving the never-`mbsync -a` invariant and explicit-override behavior.

**Tasks**:
- [x] Accept the `account` arg (threaded from `commands/email.md`'s updated `<sync_path>`) and default
      the channel: `account=gmail -> channel=gmail` (unchanged), `account=logos -> channel=logos` (group
      exists per `mbsync.nix:190`). Preserve `/email --sync <explicit-channel>` override (explicit wins).
- [x] Preserve the never-`mbsync -a` invariant verbatim: `--sync logos` must resolve to `mbsync logos`,
      never `mbsync -a` (already the skill's single-channel design; only the default-resolution logic
      changes).
- [x] Conditionalize the Gmail-specific "What sync does" prose (~18-27): give Logos a parallel clause
      ("...land in Archive/Trash, the account's real IMAP folders") instead of the Gmail label model.

**Timing**: ~0.5 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` - account-to-channel default, preserved
  invariants, prose generalization.

**Verification**:
- `/email --logos --sync` (implicit) resolves to `mbsync logos`.
- `/email --sync work` (explicit) still overrides the account-derived default.
- No path can produce `mbsync -a`.

---

### Phase 4: Documentation + routing surface (`EXTENSION.md`, `manifest.json`) [COMPLETED]

**Goal**: Document the account dimension for propagation to `.claude/CLAUDE.md` and add optional
keyword routing. Depends on the flag/skill surface being settled in Phases 1-3.

**Tasks**:
- [x] `EXTENSION.md`: extend the `/email` command-table row to document `--account <gmail|logos>` /
      `--logos` shorthand and per-account `--archive` semantics.
- [x] `EXTENSION.md`: add a Safety Invariants bullet for account isolation (never `mbsync -a`,
      folder-scoped account resolution, no tag-based account scoping) and a per-account `--archive`
      semantics bullet (Proton has no All-Mail label model; `--archive` -> real `Archive` folder for
      Logos vs `All_Mail` label-folder for Gmail).
- [x] `EXTENSION.md`: note the additive/gated posture (`/email --logos` documented but gated pending
      `.dotfiles` task 79) and that `hooks/mail-guard.sh` intentionally needs no change.
- [x] `manifest.json`: append `"logos"`, `"protonmail"`, `"proton"` to
      `keyword_overrides.email.keywords` (optional routing convenience). Leave `routing`/`merge_targets`
      unchanged.

**Timing**: ~1 hour

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/email/EXTENSION.md` - command-table + safety-invariant additions, gated-posture note.
- `.claude/extensions/email/manifest.json` - keyword_overrides append.

**Verification**:
- `EXTENSION.md` documents `--account`/`--logos` and per-account `--archive` in the command table.
- `manifest.json` remains valid JSON; keyword list includes the three Proton terms.
- The `extension_email` merge target is identified for the Phase 5 propagation check.

---

### Phase 5: Consistency verification + merge propagation [COMPLETED]

**Goal**: Confirm the Gmail path is unchanged, no silent-fallthrough or `tag:<account>` queries were
introduced, `mail-guard.sh` is untouched, and the `EXTENSION.md` content propagates to
`.claude/CLAUDE.md`.

**Tasks**:
- [x] Grep the three edited skill/command files for any residual hardcoded `folder:Gmail` on a
      non-gmail code path and for any `tag:logos`/`tag:gmail` account scoping (must be zero).
      *(completed: zero `tag:gmail`/`tag:logos` matches; every `folder:Gmail` occurrence is
      textually scoped to an `account=gmail` branch — no fallthrough on a non-gmail path)*
- [x] Confirm a bare `/email` invocation path is byte-for-byte semantically unchanged (Gmail default).
      *(completed: step 1 default is `account=gmail` when neither `--account`/`--logos` is
      present, identical to pre-change behavior; mode/scope defaults unchanged)*
- [x] Confirm `hooks/mail-guard.sh` is unmodified and record explicitly in the summary WHY no change is
      needed (allowlists by binary name; task 79 adds no new binaries) to pre-empt a reviewer "fix".
      *(completed: `git diff` across all phase-1-4 commits shows zero changes to
      hooks/mail-guard.sh)*
- [x] Run `.claude/scripts/check-extension-docs.sh` (doc-lint) and confirm it passes for the email
      extension. *(completed: `[email]` section reports OK/PASS; unrelated pre-existing FAILs in
      `core`/`lean` extensions are out of scope for this task)*
- [x] Verify the `EXTENSION.md` additions propagate to `.claude/CLAUDE.md`'s `extension_email` section
      via the sync/merge pipeline (per `manifest.json` `merge_targets.claudemd`). *(deviation:
      altered — verified the merge MECHANISM and config are correct (manifest.json
      `merge_targets.claudemd` matches the pattern used by loaded extensions; `generate_claudemd`
      in merge.lua concatenates each loaded extension's EXTENSION.md by dependency order), but
      could not observe END-TO-END propagation because `.claude/extensions.json` shows this repo
      currently has only `core`, `memory`, `nix`, `nvim` loaded — the `email` extension is not in
      the loaded set, so `.claude/CLAUDE.md` has no Email Extension section at all yet,
      independent of this task's edits. Triggering the extension picker's load/sync is a
      user-driven action with repo-wide side effects (regenerates the whole CLAUDE.md) and is out
      of scope for this implementation; see summary for follow-up note)*

**Timing**: ~0.75 hour

**Depends on**: 4

**Files to modify**:
- None (verification only); may re-touch Phase 1-4 files if a defect is found.

**Verification**:
- Zero `tag:<account>` occurrences; zero non-gmail-path `folder:Gmail*` fallthroughs.
- `check-extension-docs.sh` exits 0.
- `.claude/CLAUDE.md` reflects the new `--account` documentation after merge.
- `mail-guard.sh` diff is empty.

---

### Phase 6: Post-task-79 live verification + `wrapper-contracts.md` refresh [COMPLETED]

**Goal**: Once `.dotfiles` task 79's wrapper binaries land and are switched in, verify `/email --logos`
end-to-end and refresh the read-only wrapper-contract summary. This phase **genuinely cannot be
verified until task 79's wrapper binaries exist** and is the sole segment gated on that external
landing.

**Tasks**:
- [x] Re-confirm the exact wrapper flag spelling via `email-census --help` (guard against a flag-name
      shift during task 79's own implementation) before treating the Logos path as live. *(completed:
      `.dotfiles` task 80 confirmed `--account <gmail|logos>` verbatim across all five wrapper
      binaries' `--help` output)*
- [x] Exercise `/email --logos` end-to-end (census -> classify -> a small archive/delete dry run) against
      the live Logos maildir; confirm `folder:Logos` / `folder:Logos/.Archive` scoping returns non-empty,
      correct counts and the precondition gate now passes. *(completed: `.dotfiles` task 80 §4 ran the
      live census -> classify -> dry-run-mutation exercise end-to-end with correct folder scoping)*
- [x] Refresh `context/project/email/domain/wrapper-contracts.md` §2/§11 with the real `--account` enum
      and the per-account folder-token table, re-verified against the landed `agent-tools.nix`. *(completed:
      nvim task 816 Phase 1, transcribing `.dotfiles` task 80's verified §2/§11 tables verbatim)*
- [x] Optional editorial polish: generalize illustrative `folder:Gmail/.All_Mail` tokens in
      `archive-mode-risk.md` to be account-neutral. *(completed: nvim task 816 Phase 2)*

**Timing**: ~0.5 hour (once unblocked)

**Depends on**: 5, and external: `.dotfiles` task 79 landing + `home-manager switch`

**Resolved**: 2026-07-04 — `.dotfiles` task 79 (`email_wrappers_multi_account`) landed and is
switched in (live-confirmed via `home-manager switch` in `.dotfiles` task 80). Verification source:
`.dotfiles` task 80, `verify_logos_wrapper_contract_close_phase6` — all 9 wrapper-contract rows
PASS, zero divergence, including a live end-to-end `/email --logos` exercise (census -> classify ->
dry-run mutation) with correct account scoping at every step. Documentation refresh (this phase's
remaining deliverable) discharged via nvim task 816.

**Files to modify** (when unblocked):
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
- (optional) `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`

**Verification** (when unblocked):
- `email-census --help` shows the expected `--account` flag surface.
- `/email --logos` returns correct non-empty folder-scoped results.
- `wrapper-contracts.md` reflects the landed `--account` enum and folder-token table.

## Testing & Validation

- [x] Bare `/email` parses and behaves identically to pre-change (Gmail default; regression guard).
      *(completed: confirmed by reading commands/email.md step 1 — defaults to `account=gmail`)*
- [x] `/email --logos` and `/email --account logos` parse to `account=logos`; `--account work` yields an
      actionable rejection (no silent Gmail fallback). *(completed: documented in step 1 and the
      Error Handling unknown-account entry)*
- [x] `/email --logos --archive` resolves `BASE_QUERY=folder:Logos/.Archive` (never `folder:Gmail/.All_Mail`).
      *(completed: Stage 0 account+scope table in skill-email-cleanup/SKILL.md)*
- [x] Grep confirms zero `tag:<account>` queries and zero non-gmail-path `folder:Gmail*` fallthroughs.
      *(completed: see Phase 5 verification)*
- [x] `/email --logos --sync` resolves `mbsync logos`; no path yields `mbsync -a`. *(completed:
      skill-email-sync/SKILL.md channel-default table + explicit never-`mbsync -a` MUST NOT rule)*
- [x] Per-account pilot ack: a Gmail ack does not license a Logos archive-scope run. *(completed:
      Pilot Gate for `--archive` section, account-keyed acknowledgement record)*
- [x] `.claude/scripts/check-extension-docs.sh` exits 0; `EXTENSION.md` propagates to `.claude/CLAUDE.md`.
      *(deviation: altered — `[email]` section passes the doc-lint; propagation to CLAUDE.md is
      unobservable end-to-end because the email extension is not currently loaded in this repo's
      `.claude/extensions.json` — see Phase 5 deviation note)*
- [x] `hooks/mail-guard.sh` diff is empty (documented as intentional). *(completed: confirmed via
      git diff across all phase commits)*
- [x] (Phase 6, gated) `email-census --help` + live `/email --logos` end-to-end once task 79 lands.
      *(completed: `.dotfiles` task 80 `verify_logos_wrapper_contract_close_phase6` ran both —
      `--help` flag-spelling re-confirmation and the live census -> classify -> dry-run-mutation
      `/email --logos` exercise, §4 of its closure report — with all 9 contract rows PASS and zero
      divergence)*

## Artifacts & Outputs

- plans/01_email-multi-account-support.md (this plan)
- summaries/01_email-multi-account-support-summary.md (on implementation)
- Edited: `commands/email.md`, `skills/skill-email-cleanup/SKILL.md`, `skills/skill-email-sync/SKILL.md`,
  `EXTENSION.md`, `manifest.json` (Phases 1-5)
- Deferred/gated: `context/project/email/domain/wrapper-contracts.md` (+ optional `archive-mode-risk.md`)
  in Phase 6, post task-79 landing

## Rollback/Contingency

- All Phase 1-5 edits are additive and gated: reverting is a straight `git revert` of the extension-edit
  commit(s); the Gmail-only path is untouched, so rollback restores exact prior behavior with no data risk.
- If task 79's landed flag surface diverges from the encoded assumption, only the flag-spelling
  passthrough (Phase 2/3) and Phase 6's `wrapper-contracts.md` refresh need adjustment; the folder-token
  branches are query-side facts and remain valid.
- Phase 6 is `[COMPLETED]`: task 79 landed and is switched in, verified by `.dotfiles` task 80
  (`verify_logos_wrapper_contract_close_phase6`, all 9 rows PASS, zero divergence) and discharged
  in nvim task 816. All six phases now constitute a complete, landed deliverable.
