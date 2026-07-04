# Implementation Plan: Task #816

- **Task**: 816 - Discharge Phase 6 of task 815 (email/ extension multi-account)
- **Status**: [IN PROGRESS]
- **Effort**: 0.5 hours
- **Dependencies**: task 815 (parent); .dotfiles task 79 (landed, switched in); .dotfiles task 80 (verification source) — all discharged, no live blockers remain
- **Research Inputs**: specs/816_close_task815_phase6_wrapper_contract_docs/reports/01_phase6-docs-closure.md
- **Artifacts**: plans/01_phase6-docs-closure.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Documentation-only closure of task 815's Phase 6, which was `[BLOCKED]` pending `.dotfiles`
task 79 landing. That landing is confirmed and independently verified: `.dotfiles` task 80's
closure report confirms all 9 wrapper-contract rows PASS with zero divergence and includes a live
end-to-end `/email --logos` exercise. This plan transcribes the already-verified contract data
into three nvim files: `wrapper-contracts.md` (§2 enum + §11 tables), `archive-mode-risk.md`
(account-neutral illustrative tokens), and the task-815 plan (flip Phase 6 to `[COMPLETED]` across
five coupled edit sites). No live verification is needed; the source data is copy-verbatim ready.

### Research Integration

The research report (`reports/01_phase6-docs-closure.md`) confirmed there is **no anchor
discrepancy**: the closure report's `§2`/`§11` map 1:1 onto `wrapper-contracts.md`'s actual
`## 2.` and `## 11.` headings. It enumerated exact edit sites: `wrapper-contracts.md` line 30
(stale bullet to replace) and §11 (existing gmail-only table to generalize + new mbsync table as
net-new content); `archive-mode-risk.md` lines 3/10/74 (generalize) with line 28 explicitly
excluded (substantive Gmail-specific Trash-retention fact); and the task-815 plan's five edit
sites (Status line ~4, Phase 6 heading ~308, Depends-on/Blocked block ~328-333, Testing &
Validation checklist ~365-367, Rollback/Contingency mention ~385) which must flip together to
avoid an internally inconsistent plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this closure task (no `roadmap_path` provided). This task advances
the email/ extension multi-account capability by closing the last open phase of task 815.

## Goals & Non-Goals

**Goals**:
- Replace the stale `--account gmail` reserved-only contract in `wrapper-contracts.md` §2 with the
  confirmed `--account <gmail|logos>` enum (default `gmail`, unknown rejected with actionable error).
- Add the per-account folder-token table and the new mbsync-channel mapping table to
  `wrapper-contracts.md` §11, copied verbatim from closure report §3.
- Generalize the three purely-illustrative `folder:Gmail/.All_Mail` tokens in
  `archive-mode-risk.md` (lines 3, 10, 74) to be account-neutral.
- Flip task 815's Phase 6 marker from `[BLOCKED]` to `[COMPLETED]` across all five coupled edit
  sites, citing `.dotfiles` task 79 (landed + switched in) and task 80 (verification, 9/9 PASS).

**Non-Goals**:
- No live verification, `mbsync`, `home-manager switch`, `--execute` mutation, or nix build
  (all done and verified in `.dotfiles` task 80).
- Do NOT alter `archive-mode-risk.md` line 28 (Gmail-specific Trash-retention claim) — it is a
  substantive fact, not an illustrative token.
- No changes to the wrapper binaries or any `.dotfiles` file.
- Do not touch the rest of `wrapper-contracts.md` §2 (dry-run default, `--confirm-manifest`,
  `--manifest-dir`/`--manifest`, `--help`) — none of those facts changed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing only the Phase 6 heading and missing the top Status line (~4) leaves the plan self-contradictory | M | M | Phase 3 enumerates all five edit sites explicitly and requires zero remaining `[BLOCKED]` Phase 6 references as verification. |
| Placing the new mbsync table under a wrong/standalone heading reads as scope creep | L | M | Add it as an `### 11a.` subsection under the existing `## 11.` heading, keeping it inside "§11" as the closure report specifies while giving it a distinct anchor. |
| Over-generalizing `archive-mode-risk.md` could assert a false claim about Logos/Protonmail Trash retention | M | L | Exclude line 28 from the generalization pass (explicit non-goal); only touch the three illustrative token sites (3, 10, 74). |
| Stale `reserved-only` / gmail-only wording left behind in edited sections | M | L | Verification greps the edited sections for `reserved-only` and gmail-only phrasing; must return zero in the edited spans. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

Phases within the same wave can execute in parallel. All three phases edit distinct,
non-overlapping files, so they have no inter-phase dependencies.

### Phase 1: Refresh wrapper-contracts.md §2 enum + §11 tables [COMPLETED]

**Goal**: Replace the stale account bullet in §2 and add the per-account folder-token table plus a
new mbsync-channel mapping table to §11, verbatim from closure report §3.

**Tasks**:
- [x] In `## 2. Global Flag Contract`, replace the single stale bullet at line ~30
      (`**\`--account gmail\` reserved on all five.** Any other value is a hard error.`) with the
      confirmed enum: `--account <gmail|logos>` (also `--account=<value>` form), default `gmail`
      when omitted, unknown values rejected with an actionable stderr error and non-zero exit —
      never silently coerced to Gmail (closure report §2 rows 1-3, §3 enum paragraph). *(completed)*
- [x] Leave the rest of §2 untouched (dry-run default, `--confirm-manifest`, `--manifest-dir`/
      `--manifest`, `--help`). *(completed: verified unchanged)*
- [x] In `## 11. Folder-Scope Query Tokens`, generalize the section's framing (currently "for the
      gmail maildir") to cover both accounts, and insert the per-account folder-token table
      verbatim from closure report §3 (columns: Account, Inbox query, Archive query, Real folders;
      rows: `gmail` and `logos`). *(completed)*
- [x] Add the mbsync-channel mapping table as new content under a new `### 11a.` subsection (it has
      no existing home in this file). Copy verbatim from closure report §3 (columns: Account,
      mbsync invocation, mbsync.nix Group, Location) plus the "Never `mbsync -a`" note. *(completed)*

**Timing**: 0.2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — §2 bullet
  replacement (~line 30); §11 intro generalization + per-account folder-token table; new `### 11a.`
  mbsync-channel table (~lines 194-209 region, end of file).

**Verification**:
- No `reserved` / `reserved-only` wording remains in §2's account contract.
- §11 contains both a per-account (gmail + logos) folder-token table and an mbsync-channel table.
- The two tables match closure report §3 cell-for-cell (Logos archive is `folder:Logos/.Archive`,
  no `.All_Mail`/`.Spam`; gmail `mbsync gmail` -> `Group gmail`, logos `mbsync logos` -> `Group logos`).

---

### Phase 2: Generalize archive-mode-risk.md illustrative tokens [COMPLETED]

**Goal**: Make the three purely-illustrative `folder:Gmail/.All_Mail` token mentions
account-neutral without asserting any Logos-specific server behavior.

**Tasks**:
- [x] Line ~3 (top-of-file framing sentence): generalize the `folder:Gmail/.All_Mail`
      archive-scope example so it reads correctly for either account (reference the per-account
      table in `wrapper-contracts.md` §11 rather than hardcoding Gmail tokens). *(completed)*
- [x] Line ~10 (Blast Radius table column headers `INBOX (folder:Gmail)` /
      `All Mail (folder:Gmail/.All_Mail)`): generalize the header phrasing to be account-neutral.
      *(completed)*
- [x] Line ~74 ("What Archive Scope Does NOT Change" — `folder:Gmail/.All_Mail` classify query
      base token): generalize to account-neutral phrasing. *(completed)*
- [x] Leave line ~28 ("Gmail's Trash retention") UNCHANGED — substantive Gmail-specific server
      fact, not an illustrative token. *(completed: verified unchanged, now at line 30 due to
      earlier line-count shift)*
- [x] Confirm the line-6 cross-reference to `wrapper-contracts.md` §10/§11 still resolves (section
      numbers are unchanged; §11 only grew content). *(completed)*

**Timing**: 0.15 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — lines ~3, ~10,
  ~74 generalized; line ~28 untouched.

**Verification**:
- Lines 3, 10, 74 no longer hardcode Gmail-only tokens as the sole illustration.
- Line 28's Gmail Trash-retention claim is byte-for-byte unchanged.
- No newly-introduced claim about Logos/Protonmail server-side retention.

---

### Phase 3: Flip task 815 Phase 6 marker to [COMPLETED] [NOT STARTED]

**Goal**: Update all five coupled edit sites in the task-815 plan so Phase 6 reads `[COMPLETED]`
consistently, citing the landing and verification sources.

**Tasks**:
- [ ] Top **Status** line (~4): update the parenthetical from "Phase 6 remains `[BLOCKED]` pending
      `.dotfiles` task 79" to reflect Phase 6 now `[COMPLETED]` (task 79 landed + switched in,
      task 80 verified 9/9 PASS).
- [ ] Phase 6 heading (~308): flip the trailing marker from `[BLOCKED]` to `[COMPLETED]`.
- [ ] **Depends on** / **Blocked** block (~328-333): note task 79's external dependency is
      discharged (landed); replace the stale `**Blocked**:` paragraph with a resolution note
      citing `.dotfiles` task 80 (`verify_logos_wrapper_contract_close_phase6`) as the verification
      source (all 9 rows PASS, zero divergence).
- [ ] Testing & Validation checklist item (~365-367): flip `- [ ]` to `- [x]` and reference the
      closure report's live-exercise results (closure report §4) as completion evidence.
- [ ] Rollback/Contingency mention (~385): update the stale "Phase 6 stays `[BLOCKED]` until task
      79 lands" line to reflect the resolved state.

**Timing**: 0.15 hours

**Depends on**: none

**Files to modify**:
- `specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md` — five
  edit sites (~4, ~308, ~328-333, ~365-367, ~385).

**Verification**:
- Zero remaining `[BLOCKED]` references tied to Phase 6 anywhere in the task-815 plan.
- Phase 6 heading and top Status line agree (both reflect `[COMPLETED]`).
- Task 79 (landed) and task 80 (verification, 9/9 PASS) are both cited.

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` passes (exit 0) after all edits.
- [ ] `grep -rn 'reserved-only' .claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
      returns no hit in the §2 account contract.
- [ ] `wrapper-contracts.md` §11 contains a per-account folder-token table (gmail + logos rows) and
      an mbsync-channel table; both match closure report §3.
- [ ] `archive-mode-risk.md` line ~28 (Gmail Trash retention) is unchanged; lines 3/10/74 are
      account-neutral.
- [ ] `grep -n 'BLOCKED' specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md`
      shows zero remaining Phase-6-associated `[BLOCKED]` references.
- [ ] Task-815 plan's top Status line and Phase 6 heading are internally consistent.

## Artifacts & Outputs

- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (edited: §2, §11 + new §11a)
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (edited: lines 3, 10, 74)
- `specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md` (edited: five Phase-6 sites)
- `specs/816_close_task815_phase6_wrapper_contract_docs/summaries/01_phase6-docs-closure-summary.md` (implementation summary)

## Rollback/Contingency

All changes are documentation-only and confined to three markdown files. To revert, `git checkout`
the three edited files. No code, build, or live-system state is touched, so rollback carries no
runtime risk. If the closure report's §3 data is ever found to disagree with live wrapper behavior,
re-open task 815 Phase 6 rather than patching in place.
