# Research Report: Task #816

**Task**: 816 - Discharge Phase 6 of task 815 (email/ extension multi-account)
**Started**: 2026-07-04T21:31:29Z
**Completed**: 2026-07-04T21:36:00Z
**Effort**: ~0.5h (docs-only, matches original Phase 6 estimate)
**Dependencies**: task 815 (parent), .dotfiles task 79 (landed), .dotfiles task 80 (verification source)
**Sources/Inputs**:
- `/home/benjamin/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/summaries/01_phase6-closure-report.md` (primary, self-contained, authoritative)
- Codebase reads of the three nvim target files
**Artifacts**:
- This report: `specs/816_close_task815_phase6_wrapper_contract_docs/reports/01_phase6-docs-closure.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The blocker is fully resolved: `.dotfiles` task 79 (wrapper binaries) landed and is switched
  in; `.dotfiles` task 80's closure report confirms all 9 wrapper-contract rows PASS with zero
  divergence, and includes a live end-to-end `/email --logos` exercise (census -> classify ->
  dry-run mutation) that succeeded.
- **No discrepancy found**: the closure report's assumed section numbering (`§2`/`§11`) in
  `wrapper-contracts.md` matches the file's actual headings exactly — `## 2. Global Flag
  Contract` and `## 11. Folder-Scope Query Tokens`. The plan/implementation can target these
  anchors directly, verbatim as named in the closure report.
- `wrapper-contracts.md` §2 currently contains stale text (`` **`--account gmail` reserved on
  all five.** Any other value is a hard error. ``) that must be replaced with the confirmed
  `--account <gmail|logos>` enum (default `gmail`, unknown rejected with actionable error).
  §11 currently contains only the Gmail-only 6-row folder-token table and must gain a second,
  per-account table (plus the mbsync-channel mapping, which currently has no dedicated table in
  this file at all — it is new content, not a table replacement).
- `archive-mode-risk.md` has 4 illustrative `folder:Gmail...` occurrences (lines 3, 10 (x2), 74)
  that are candidates for the optional account-neutral generalization; one further mention
  (line 28, "Gmail's Trash retention") is a substantive claim about Gmail-specific server
  behavior, not an illustrative token, and should likely stay Gmail-specific rather than be
  generalized.
- `01_email-multi-account-support.md`'s Phase 6 heading, its overall Status line (line 4), and
  its Testing & Validation Phase-6 checklist item (line 365) all need updating in the same pass;
  the report's checklist under-counts one edit site (the top-of-plan Status line at line 4 also
  says "Phase 6 remains `[BLOCKED]`" and must flip in sync with the heading).

## Context & Scope

This is documentation-only closure work: task 815's Phase 6 was `[BLOCKED]` pending `.dotfiles`
task 79 landing. That landing is now confirmed and independently verified (9/9 contract rows
PASS, live exercise succeeded) in the `.dotfiles` task 80 closure report, which is written to be
fully self-contained for the nvim side — no further live verification or `.dotfiles`-side
lookups are needed. This research's only job was to (a) read the closure report's load-bearing
sections, (b) confirm the three nvim target files' actual structure/anchors so a plan can cite
real headings rather than assumed ones, and (c) flag any discrepancy between assumed and actual
anchors. No files were edited (research phase only, per task instructions).

## Findings

### Codebase Patterns

**`wrapper-contracts.md`** (`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`,
209 lines total, 11 numbered `##` sections):

- `## 2. Global Flag Contract (all five signatures)` — lines 23-39. The account-relevant bullet
  is `` - **`--account gmail` reserved on all five.** Any other value is a hard error. `` (line
  30). This is the single line to replace with the confirmed enum text from the closure report's
  §3 (`--account <gmail|logos>`, default `gmail`, `--account=<value>` form also supported,
  unknown values rejected with actionable stderr error + non-zero exit — never silently coerced
  to Gmail).
- `## 11. Folder-Scope Query Tokens (verified)` — lines 194-209 (end of file). Currently one
  6-row table scoped only to "the gmail maildir" (line 196: "Notmuch folder tokens for the gmail
  maildir, as hardcoded in `email-census` (lines 297-303)"), followed by a one-paragraph note on
  the All Mail token (lines 205-209). This whole section needs a second per-account table (the
  closure report's §3 "Per-account folder-token table": gmail vs logos, inbox/archive query,
  real folders) inserted alongside or replacing the existing table, generalized so the section
  heading/intro text isn't gmail-only anymore. The mbsync-channel mapping table (closure report
  §3, second table: account -> `mbsync <group>` invocation -> `Group` name -> `mbsync.nix` line
  numbers) has **no existing home** in this file — §11 is titled "Folder-Scope Query Tokens", so
  the mbsync table is new content that will need either a new subsection (e.g. `### 11a.` or a
  fresh `## 12.`) or insertion at the end of §11 with a clear sub-heading, since it doesn't fit
  the "folder-scope query tokens" framing verbatim.
- **No discrepancy**: `§2` and `§11` in the closure report map 1:1 onto the actual `## 2.` and
  `## 11.` headings in the file. A plan can cite these anchors directly with confidence.

**`archive-mode-risk.md`** (`.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`,
79 lines, no numbered sections — plain `#`/`##` headings):

- Illustrative/generalization candidates (per closure report's optional item):
  - Line 3: `` Why archive-scope (`folder:Gmail/.All_Mail`) email operations get extra-caution
    gates `` — top-of-file framing sentence.
  - Line 10: table header row, `` | Property | INBOX (`folder:Gmail`) | All Mail
    (`folder:Gmail/.All_Mail`) | `` — the "Blast Radius" table's column headers.
  - Line 74: `` All Mail scoping is purely the classify QUERY base token
    `folder:Gmail/.All_Mail` `` — "What Archive Scope Does NOT Change" section.
- Non-candidate (leave as-is): line 28, "Recoverable until Trash is expunged (locally) and,
  server-side, per Gmail's Trash retention" — this is a substantive claim specifically about
  Gmail's server-side retention policy (Logos/Protonmail Bridge may have different or no
  equivalent retention behavior), not a generic illustrative token, so generalizing it risks
  asserting something untrue for the Logos account rather than simply being clearer wording.
- This file cross-references `wrapper-contracts.md` §10 and §11 by name (line 6), which still
  match after the §11 edit (the section number doesn't change, only its content grows).

**`01_email-multi-account-support.md`** (`specs/815_revise_email_extension_multi_account/plans/01_email-multi-account-support.md`,
387 lines):

- Top-of-plan **Status** metadata line (line 4): `` **Status**: [COMPLETED] (Phases 1-5 landed;
  Phase 6 remains `[BLOCKED]` pending `.dotfiles` task 79) `` — this parenthetical needs updating
  in the same pass as the heading flip (change to reflect Phase 6 now `[COMPLETED]`, citing task
  79 landed + task 80 verification), otherwise the plan will have an internally inconsistent
  top-of-file summary vs. its own Phase 6 heading.
- **Phase 6 heading** (line 308): `` ### Phase 6: Post-task-79 live verification +
  `wrapper-contracts.md` refresh [BLOCKED] `` — the bracket marker to flip to `[COMPLETED]`.
- **Depends on** line (line 328): `` **Depends on**: 5, and external: `.dotfiles` task 79 landing
  + `home-manager switch` `` — should be updated to note task 79 has landed (dependency
  discharged), consistent with the closure report's confirmation.
- **Blocked** line (lines 330-333): the whole `**Blocked**: 2026-07-04 — ...` paragraph
  documenting the blocker is now stale and should be replaced with a resolution note citing
  `.dotfiles` task 80 (`verify_logos_wrapper_contract_close_phase6`) as the verification source,
  per the task 816 description's explicit instruction.
- **Testing & Validation** Phase-6 checklist item (line 365): `` - [ ] (Phase 6, gated)
  `email-census --help` + live `/email --logos` end-to-end once task 79 lands. `` — its
  `(deviation: deferred to Phase 6 ...)` note (lines 366-367) should be updated to `[x]` and
  reference the closure report's live-exercise results (closure report §4) as the completion
  evidence, since that exercise already ran the equivalent command sequence.
- The **Files to modify (when unblocked)** list (lines 335-337) and **Verification (when
  unblocked)** list (lines 339-342) remain accurate as-is — same two files, same verification
  criteria — no anchor drift here.
- **Rollback/Contingency** section (lines 378-386) mentions "Phase 6 stays `[BLOCKED]` until
  task 79 lands" (line 385) — also stale, same update as the Blocked paragraph above.

### External Resources

Not applicable — this is a pure cross-repo documentation-transcription task with a
self-contained source report; no external web research was needed or performed.

### Recommendations

1. Treat the closure report's §2 verdict table and §3 contract-data block as ground truth to
   copy verbatim — they are already formatted for direct insertion (closure report's own words,
   §3 header: "Ready to Apply to `wrapper-contracts.md` §2/§11").
2. In `wrapper-contracts.md` §2, replace only the single stale bullet (line 30) — leave the rest
   of §2 (dry-run default, `--confirm-manifest`, `--manifest-dir`/`--manifest`, `--help`)
   untouched, since none of those facts changed with task 79.
3. In `wrapper-contracts.md` §11, generalize the section's framing (currently "for the gmail
   maildir") to cover both accounts, insert the per-account folder-token table from the closure
   report's §3, and add the mbsync-channel mapping as new content (decide during planning whether
   as an `### 11a.` subsection or appended paragraph — the closure report doesn't mandate a
   specific sub-anchor, only that the content lands "in" §11's vicinity).
4. For `archive-mode-risk.md`, generalize lines 3, 10, and 74 (the three purely-illustrative
   token mentions) but leave line 28's Gmail-retention claim untouched, since it is factually
   scoped to Gmail rather than illustrative.
5. In the plan file, flip four sites in the same edit pass to avoid an internally inconsistent
   plan: the top Status line (4), the Phase 6 heading (308), the Depends-on/Blocked block
   (328-333), and the Testing & Validation checklist item (365-367) plus the
   Rollback/Contingency mention (385) — all six line ranges belong to the same logical edit and
   should be updated together, citing `.dotfiles` task 79 (landed) and task 80
   (`verify_logos_wrapper_contract_close_phase6`, the verification source) as the citations the
   task 816 description requires.

## Decisions

- No discrepancy exists between the closure report's assumed anchors and the actual file
  structure — the plan should target `wrapper-contracts.md` §2 and §11 exactly as named.
- The mbsync-channel table is new content for `wrapper-contracts.md` (no prior table existed);
  this is not a "refresh" of existing content but an addition, and the planner should decide the
  exact sub-anchor/heading for it.
- `archive-mode-risk.md`'s line 28 (Gmail Trash retention) is excluded from the "generalize
  illustrative tokens" scope — it is a substantive Gmail-specific fact, not an illustrative
  token.
- The plan-file edit touches five distinct line ranges (4, 308, 328-333, 365-367, 385), all part
  of one coherent "flip Phase 6 to COMPLETED" edit; a plan should treat these as one edit unit
  rather than only the heading line.

## Risks & Mitigations

- **Risk**: Editing only the Phase 6 heading and missing the top-of-plan Status line (line 4)
  would leave the plan self-contradictory (top says Phase 6 `[BLOCKED]`, Phase 6 section says
  `[COMPLETED]`). **Mitigation**: explicitly listed as a required edit site above.
- **Risk**: Placing the new mbsync-channel table under the wrong heading (e.g., creating a
  standalone `## 12.` when the closure report says "§2/§11") could look like scope creep.
  **Mitigation**: recommend a `### 11a.` subsection under the existing `## 11.` heading, keeping
  it inside "§11" as the closure report specifies, while still giving it a distinct anchor.
- **Risk**: Over-generalizing `archive-mode-risk.md` could inadvertently assert a false claim
  about Logos/Protonmail Bridge server-side Trash retention behavior (which may differ from or
  not exist for Gmail). **Mitigation**: exclude line 28 from the generalization pass, as
  recommended above.

## Context Extension Recommendations

None — this is a self-contained, one-off documentation closure with no new reusable pattern
that existing context files fail to cover.

## Appendix

- Closure report read in full: `/home/benjamin/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/summaries/01_phase6-closure-report.md`.
- `grep -n '^#'` against `wrapper-contracts.md` to enumerate actual section headings and confirm
  §2/§11 anchor match.
- `grep -n 'Gmail\|All_Mail\|account'` against `archive-mode-risk.md` to enumerate illustrative
  token occurrences.
- `grep -n '^### Phase 6\|BLOCKED\|Status:\|Dependencies:'` against
  `01_email-multi-account-support.md`, followed by a full read of lines 300-387, to locate all
  Phase-6-related edit sites (heading, Status line, Depends-on/Blocked block, Testing &
  Validation item, Rollback/Contingency mention).
