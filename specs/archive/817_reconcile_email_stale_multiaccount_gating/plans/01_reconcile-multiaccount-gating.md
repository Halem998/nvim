# Implementation Plan: Task #817 - Reconcile email extension stale multi-account gating language

- **Task**: 817 - Reconcile the email extension's stale multi-account gating language with the now-verified wrapper contract
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (upstream `.dotfiles` task 79 landed + verified by task 80; wrapper-contracts.md authoritative)
- **Research Inputs**: specs/817_reconcile_email_stale_multiaccount_gating/.orchestrator-handoff.json (research-only, no report markdown)
- **Artifacts**: plans/01_reconcile-multiaccount-gating.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The email extension (`.claude/extensions/email/`) still describes `--account logos` as
"documented-but-gated / pending `.dotfiles` task 79", but that upstream dependency has landed,
switched in, and was live-verified by `.dotfiles` task 80 (9/9 contract rows PASS). The
authoritative ground truth is now `wrapper-contracts.md` §2/§11: `--account <gmail|logos>` is
accepted and unknown values are rejected loudly. This plan strips the obsolete pending-tense
gating language from four files, converts the `skill-email-cleanup` "STOP if gmail-only"
precondition gate into a light read-only liveness check (fixing a broken `--help` probe that
never actually tested account acceptance), and aligns gate naming. Definition of done: an agent
reading `/email --logos` gets one consistent, non-contradictory story; `check-extension-docs.sh`
still PASS; and no "pending task 79" / "gmail-reserved" / "documented but gated" language
survives a grep sweep of the four files.

### Research Integration

Findings originate from `specs/reviews/review-2026-07-04.md` (findings 1 CRITICAL, 2 HIGH, 7 LOW),
ground-truthed against `wrapper-contracts.md` during the research phase and captured in the
orchestrator handoff. The handoff located every stale occurrence with exact line numbers and
noted one occurrence beyond the review's cited ranges (`commands/email.md:178-181`). A planning
grep sweep surfaced two further occurrences not individually cited in the handoff line list:
`skills/skill-email-cleanup/SKILL.md:20` (account param-table row) and `EXTENSION.md:79` (Safety
Invariants footnote). Because line citations can miss duplicates, this plan directs the
implementer to treat the grep sweep — not the cited line numbers — as the authoritative
completeness check.

Key probe fix (finding 2): the current probe `email-census --account logos --help` short-circuits
before flag validation (wrapper-contracts.md line 41: `--help` prints verb/safety-class/flags
unconditionally), so it exits 0 even if `--account logos` were rejected — it never tests account
acceptance. Replace with `email-census --account logos` (a read-only, side-effect-free call per
the Five Binaries safety-class table) and check exit code / stderr.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` provided; `roadmap_flag` not set). Meta task scoped to
extension documentation reconciliation.

## Goals & Non-Goals

**Goals**:
- Remove all obsolete "wrapper reserves `--account gmail` only / hard error / pending `.dotfiles`
  task 79 / documented-but-gated" language from the four target files.
- Convert the `skill-email-cleanup` "Account Precondition Gate" from a STOP-on-gmail-only gate
  into a light read-only liveness check.
- Fix the liveness probe from `email-census --account logos --help` to `email-census --account
  logos` with exit-code/stderr checking.
- Align gate naming: `skill-email-sync/SKILL.md:70` "Phase-1 precondition gate" -> "step-1
  precondition gate" to match `commands/email.md`'s `<step_1>` tag.
- Preserve the "never a silent fallback to Gmail" invariant and the loud-rejection-on-unknown-
  value behavior (both remain true under the verified contract).

**Non-Goals**:
- No changes to wrapper binaries, `wrapper-contracts.md`, or any `.dotfiles` content.
- No behavioral change to `--account gmail` (the existing, unchanged path).
- No refactor of skill logic beyond the gate/probe conversion and stale-language removal.
- No fix for the two pre-existing unrelated `check-extension-docs.sh` warns (skill-email-
  implementation not deployed; README.md older than manifest.json) — out of scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stale occurrence missed (line citations miss a duplicate) | M | M | Phase 5 grep sweep is the authoritative completeness gate; implementer fixes every hit, not just cited lines |
| Rewrite accidentally drops the "never a silent fallback" / "loud rejection on unknown value" invariant | M | L | Preserve these invariants explicitly; they remain true under the verified contract |
| Probe conversion introduces a side-effecting call | H | L | `email-census --account logos` is read-only per the Five Binaries safety-class table; verify against wrapper-contracts.md before writing |
| `check-extension-docs.sh` regresses on cross-reference/link check | M | L | Phase 5 re-runs the linter; baseline is PASS with 2 known unrelated warns |
| Gate-naming change desyncs other `step-1`/`Phase-1` references | L | L | Grep for both spellings; `commands/email.md` already uses `step-1` at lines 120/136 — align to that |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel (each edits a distinct file; no shared
territory). Phase 5 verification runs only after all edits land.

### Phase 1: Rewrite commands/email.md stale gating language [COMPLETED]

**Goal**: Strip obsolete pending-tense gating language from all four locations in the command doc,
replacing it with the verified-contract framing (`--account <gmail|logos>` accepted; unknown
values rejected loudly; never a silent fallback).

**Tasks**:
- [x] Rewrite the Accounts section (lines 41-44): remove "**Documented but gated**" and "fails
      loudly until `.dotfiles` task 79's wrapper binaries land and accept" — state that `logos`
      is a live, accepted account per wrapper-contracts.md §2. *(completed)*
- [x] Rewrite the `<step_1>` argument-parsing gate description (lines 67-72): remove "they
      currently reserve `--account gmail` only, per wrapper-contracts.md §2, pending `.dotfiles`
      task 79" — reframe the gate as a light liveness check, keeping loud-rejection behavior.
      *(completed)*
- [x] Rewrite the Safety Notes bullet (lines 178-181): remove "`--logos` is documented-but-gated
      ... fails loudly until `.dotfiles` task 79's wrapper binaries land". *(completed)*
- [x] Rewrite the Error Handling entry (lines 204-208): remove "wrapper binaries do not yet
      accept `--account logos`, e.g. because `.dotfiles` task 79 has not landed/switched-in" and
      "the wrapper binaries only accept `--account gmail` until `.dotfiles` task 79 lands" —
      reframe as a liveness-probe-failure branch (transient/environmental), not a permanent gate.
      *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/commands/email.md` - Accounts (41-44), `<step_1>` gate (67-72),
  Safety Notes (178-181), Error Handling (204-208). Line numbers are approximate; grep for the
  stale phrases to locate exact spans.

**Verification**:
- `grep -niE "task 79|documented[- ]but[- ]gated|currently reserve|do not yet accept" commands/email.md`
  returns nothing.
- The `<step_1>` tag naming is unchanged (only its stale description text is rewritten).

---

### Phase 2: Rewrite EXTENSION.md stale gating language [COMPLETED]

**Goal**: Remove the "gated until `.dotfiles` task 79's wrapper binaries land" framing from the
Commands table and Safety Invariants.

**Tasks**:
- [x] Rewrite the Commands table row (line 29): remove "documented-but-gated — parsed and
      query-constructed now, but routed through an actionable precondition gate that fails loudly
      until `.dotfiles` task 79's wrapper binaries land and accept `--account logos`". Keep
      "Never a silent fallback to Gmail" and state `logos` is an accepted account. *(completed)*
- [x] Rewrite the Safety Invariants bullet(s) (lines 72-77): remove "`/email --logos` is additive
      and gated" / "fails loudly until `.dotfiles` task 79's wrapper binaries land". *(completed)*
- [x] Reconcile the footnote at line 79 ("`.dotfiles` task 79 adds an ...") surfaced by the grep
      sweep — update or remove the pending-tense reference so it reflects the landed/verified
      contract. *(completed: removed the literal "task 79" mention entirely, not just made past
      tense, since the grep sweep's "task 79" pattern requires zero hits for the string itself)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/EXTENSION.md` - Commands table (29), Safety Invariants (72-77), and
  the line-79 footnote.

**Verification**:
- `grep -niE "task 79|documented[- ]but[- ]gated|and gated" EXTENSION.md` returns nothing.

---

### Phase 3: Convert skill-email-cleanup precondition gate to liveness check + fix probe [COMPLETED]

**Goal**: Rewrite the "Account Precondition Gate" section from a STOP-on-gmail-only gate into a
light read-only liveness check, and fix the broken `--help` probe.

**Tasks**:
- [x] Rewrite the "Account Precondition Gate" section (lines 45-60): remove "The five wrapper
      binaries currently reserve `--account gmail`; any other value is a hard error
      (wrapper-contracts.md §2), pending `.dotfiles` task 79 landing + `home-manager switch`" and
      the "STOP ... `--account gmail` until `.dotfiles` task 79 lands" block. Reframe as a light
      liveness check that confirms the wrapper accepts `--account logos` before proceeding.
      *(completed: renamed section to "Account Liveness Check")*
- [x] Fix the probe: replace `email-census --account logos --help` with `email-census --account
      logos` (read-only, side-effect-free per the Five Binaries safety-class table), checking exit
      code and stderr. Document why `--help` is wrong: it short-circuits before flag validation
      (wrapper-contracts.md line 41), so it never actually tests account acceptance. *(completed)*
- [x] Update the account param-table row (line 20) surfaced by the grep sweep: remove
      "`account=logos` is documented-but-gated" and point to the updated liveness-check section.
      *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` - Account Precondition Gate
  section (45-60), probe command, param-table row (20).

**Verification**:
- `grep -niE "task 79|documented[- ]but[- ]gated|hard error|reserve" SKILL.md` returns nothing.
- `grep -n "\-\-help" SKILL.md` shows no `email-census --account logos --help` probe remains.
- The probe reads `email-census --account logos` and checks exit/stderr.

---

### Phase 4: Rewrite skill-email-sync language + align gate naming [COMPLETED]

**Goal**: Remove pending-tense "currently-reserved `--account gmail`" / "once the wrapper binaries
accept `--account logos`" framing, and align gate naming with `commands/email.md`.

**Tasks**:
- [x] Rewrite lines 58-61: remove "currently-reserved `--account gmail`" and "even though the
      wrapper binaries don't yet accept `--account logos`" — state `logos` resolves against the
      `logos` mbsync channel under the verified contract. *(completed)*
- [x] Rewrite lines 70-72: remove "once the wrapper binaries accept `--account logos`" pending
      framing; describe the step-1 liveness check as already-live. *(completed)*
- [x] Gate-naming alignment (finding 7): change "`/email`'s Phase-1 precondition gate" (line 70)
      to "`/email`'s step-1 precondition gate" to match `commands/email.md`'s `<step_1>` tag and
      its existing "step-1 precondition gate" references (lines 120, 136). *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` - lines 58-61, 70-72.

**Verification**:
- `grep -niE "currently.reserved|don't yet accept|once the wrapper|Phase-1 precondition" SKILL.md`
  returns nothing.
- `grep -n "step-1 precondition gate" SKILL.md` shows the aligned naming.

---

### Phase 5: Verify linter PASS and grep sweep clean [COMPLETED]

**Goal**: Confirm the docs are consistent and no stale language survives.

**Tasks**:
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm `[email]` still PASS
      (baseline: PASS with 2 pre-existing unrelated warns — skill-email-implementation not
      deployed; README.md older than manifest.json). No NEW warnings/errors introduced.
      *(completed: confirmed PASS with the same 2 known warns, no new ones)*
- [x] Run a grep sweep across all four files for the retired phrasings and confirm zero hits:
      `grep -rniE "task 79|gmail-reserved|documented[- ]but[- ]gated|documented but gated|currently.reserved|Phase-1 precondition|do not yet accept|don't yet accept|once the wrapper" .claude/extensions/email/commands/email.md .claude/extensions/email/EXTENSION.md .claude/extensions/email/skills/skill-email-cleanup/SKILL.md .claude/extensions/email/skills/skill-email-sync/SKILL.md`
      *(completed: zero hits — required removing the literal "task 79" mention from
      EXTENSION.md's mail-guard.sh footnote entirely, beyond the plan's original past-tense-only
      framing, to satisfy the sweep)*
- [x] Read the four edited regions end-to-end for a consistency pass: an agent reading `/email
      --logos` gets one non-contradictory story (accepted account, loud rejection on unknown
      value, never a silent fallback, step-1 liveness check). *(completed)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3, 4

**Files to modify**: none (verification only).

**Verification**:
- `check-extension-docs.sh` exits with `[email]` PASS and no new warns beyond the 2 known.
- The grep sweep returns zero matches.

## Testing & Validation

- [x] `bash .claude/scripts/check-extension-docs.sh` -> `[email]` PASS (2 known unrelated warns
      only; no new warns/errors).
- [x] Grep sweep across the four files returns zero matches for retired phrasings (see Phase 5).
- [x] `skill-email-cleanup/SKILL.md` probe is `email-census --account logos` (no `--help`), with
      exit/stderr checking.
- [x] `skill-email-sync/SKILL.md:70` reads "step-1 precondition gate" (not "Phase-1").
- [x] Manual read-through confirms a single consistent narrative for `/email --logos`.

## Artifacts & Outputs

- `.claude/extensions/email/commands/email.md` (edited)
- `.claude/extensions/email/EXTENSION.md` (edited)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (edited)
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md` (edited)
- `specs/817_reconcile_email_stale_multiaccount_gating/summaries/01_reconcile-multiaccount-gating-summary.md` (on implementation)

## Rollback/Contingency

All changes are documentation edits confined to `.claude/extensions/email/`. If a rewrite
introduces an inconsistency or the linter regresses, revert the specific file with
`git checkout -- <path>` (changes are uncommitted until the task's commit) and re-apply the
edit. No runtime behavior or wrapper binaries are touched, so there is no operational rollback
concern. If wrapper-contracts.md is later found to be non-authoritative (contradicting the task's
stated ground truth), pause and re-open research rather than reverting piecemeal.
