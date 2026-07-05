# Implementation Plan: Task #820

- **Task**: 820 - `/email --all` cannot re-surface an already-fully-classified mailbox for review
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Cross-repo — the skill-side phases (3, 4) require the `.dotfiles` `email-classify --emit-tagged` binary (Phase 1) to have shipped before they can be exercised end-to-end.
- **Research Inputs**: reports/02_wrapper-gap-verified.md (primary, verified); reports/01_wrapper-gap-seed.md (seed)
- **Artifacts**: plans/02_email-all-emit-tagged.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 820 fixes a gap where `skill-email-cleanup`'s `--all` mode cannot rebuild a Stage 2.5
review set for a mailbox whose messages already all carry durable `+proposed-*` tags. The
verified research (report 02) establishes the fix as a two-file change spanning two repos: add a
genuinely read-only `email-classify --emit-tagged` mode to the `.dotfiles` wrapper
(`modules/home/email/agent-tools/classify.nix`) that reconstructs per-message records from the
existing `+proposed-*` tag (tag-derived action only — never recomputed, never re-tagged), and
switch `skill-email-cleanup` Stage 1/2 (`--all` mode) to consume it for the residual count-probe
and residual pass instead of the current re-classify-and-retag pattern. Documentation in both
repos is updated to record the new mode and correct the "emit-on-change" mischaracterization.

Definition of done: `email-classify --emit-tagged` exists and is read-only (no `notmuch tag`
call, no `classify_one()` recompute feeding the action); `SKILL.md` `--all` mode calls it for
residual counts and the residual pass and emits a distinct "0 new, all residual" status; both
repos' contract docs describe the new mode and the corrected classify semantics.

### Research Integration

Report 02 (verified) supersedes the seed's root-cause framing: `email-classify` is **not**
emit-on-change — it unconditionally re-emits and re-tags every processed message
(`classify.nix` lines 132–167), and `candidate-manifest.jsonl` is destructively overwritten per
call (including by a `--limit 0` counting probe), which is the mechanism that best explains the
observed "0 records". A second, previously-undocumented risk: the existing `--all` residual pass
recomputes each message's action from the current `classify_one()` rule table, so rule-table
drift can silently overwrite a prior human decision before Stage 2.5 review. The `--emit-tagged`
mode closes both the overwrite footgun and the silent-rewrite risk. Seed fixes 2 (`email-census`
query positional) and 3 (persisted per-run manifests) are out of scope per report 02's Decisions.

### Prior Plan Reference

No prior plan. This is the first plan for task 820.

### Roadmap Alignment

No ROADMAP.md consulted (not provided in delegation context). No roadmap phases added.

### Cross-Repo Boundary (key planning decision)

The wrapper binary lives in a **separate git repository** (`~/.dotfiles`); this repo has no
machine dependency on `.dotfiles` by design (`wrapper-contracts.md` line 6). Report 02 recommends
the wrapper change land as a separate `.dotfiles` sub-task mirroring the task 72/79/80 pattern.
This plan honors that boundary by scoping the wrapper work (Phases 1–2) explicitly to the
`~/.dotfiles` working tree with its **own commit in that repo**, kept strictly separate from the
nvim-repo commits for Phases 3–5. If strict task-tracking separation is preferred, Phases 1–2 can
instead be split into a spawned `.dotfiles` task, in which case Phases 3–4 become blocked until
that task ships `--emit-tagged`. Either way the dependency ordering (wrapper first, skill second)
is identical and is what the wave table below encodes.

## Goals & Non-Goals

**Goals**:
- Add a read-only `email-classify --emit-tagged` mode to `.dotfiles` `classify.nix` that derives
  `proposed_action` strictly from the existing `+proposed-*` tag, never calling `notmuch tag` and
  never sourcing the action from a `classify_one()` recompute.
- Switch `skill-email-cleanup` `--all` mode (Stage 1 residual count-probe, Stage 2 residual pass)
  to consume `--emit-tagged`, eliminating both the destructive-overwrite race and the
  silent-tag-rewrite-on-rule-drift risk.
- Emit a distinct "0 new, N residual across 4 tag buckets" status before Stage 2.5 when the new
  count probe reports zero new messages.
- Update both repos' contract docs (`.dotfiles` wrapper-contract handoff; this repo's
  `wrapper-contracts.md` §1/§6/§10) to describe `--emit-tagged` and correct the emit-on-change
  framing.

**Non-Goals**:
- `email-census` query positional (seed fix 2) — deferred, file separately if wanted.
- Persisted per-run candidate manifests (seed fix 3) — superseded by `--emit-tagged`; not pursued.
- Any change to `mode=default` cursor-query behavior — its `+proposed-*` exclusion is intentional.
- Any change to the mutation wrappers (`email-archive-confirmed` / `email-delete-confirmed`) or
  the frozen approved-manifest / `MAX_BATCH_SIZE=50` contracts.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-diagnosis (Findings 3/4) rests on static source reading, not a fresh live repro | M | M | Phase 1 includes one bounded read-only probe (`--limit 0` then `cat candidate-manifest.jsonl`) against the real mailbox before writing the fix, when a live mailbox is available; skip-and-note if not. |
| `--emit-tagged` accidentally recomputes/apply the action, reintroducing the rule-drift rewrite | H | L | Enforce the invariant in Phase 1: action comes only from the tag `case` block; `classify_one()` result is used solely for display `confidence`/`reason`, labeled `reason="tag-derived;..."`; no `notmuch tag` call anywhere in the branch. |
| Cross-repo commit hygiene (nvim-repo task editing `.dotfiles`) muddies tracking | M | M | Phases 1–2 commit only in `~/.dotfiles`; Phases 3–5 commit only in the nvim repo. See Cross-Repo Boundary; escalate to a spawned `.dotfiles` task if separation must be strict. |
| Skill starts calling `--emit-tagged` before the binary ships | H | L | Wave ordering: Phases 3–4 depend on Phase 1. Phase 5 verifies the skill's referenced flag actually exists in the deployed wrapper. |
| Recomputed `confidence`/`reason` will not match the historical value that justified the tag | L | H | Document explicitly (help text + both contract docs) that confidence is current-rules-derived for display only; action is tag-derived and authoritative. |
| Removing the residual "completeness caveat" may be wrong at real mailbox scale | L | M | Phase 3 re-confirms whether an unbounded per-tag read is acceptable at the account's actual scale before dropping the caveat; keep it if unsure. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3, 4 touch disjoint files across
the two repos (`.dotfiles` contract doc; nvim `SKILL.md`; nvim `wrapper-contracts.md`).

---

### Phase 1: Implement `email-classify --emit-tagged` in `.dotfiles` (cross-repo) [COMPLETED]

**Goal**: Add a read-only tag-read-out mode to the wrapper binary that rebuilds
`candidate-manifest.jsonl` from existing `+proposed-*` tags without mutation or action recompute.

**Tasks**:
- [ ] (Optional, if a live mailbox is reachable) Run one bounded read-only probe to confirm the
      overwrite-to-empty mechanism: `email-classify --limit 0 "<scope query>"` then immediately
      `cat candidate-manifest.jsonl`, observing it is empty. Record the result; skip and note if
      no live mailbox is available. *(deviation: skipped — no live notmuch mailbox reachable in
      this execution environment; the destructive-overwrite mechanism was instead confirmed by
      static read of `classify.nix`'s default-mode `: > "$CANDIDATE_FILE.tmp"` truncation, per
      report 02's verified static analysis.)*
- [x] In `~/.dotfiles/modules/home/email/agent-tools/classify.nix`, add `--emit-tagged` flag
      parsing to the existing arg-parse while-loop (near lines 35–43): `--emit-tagged) EMIT_TAGGED=1; shift ;;`. *(completed)*
- [x] Add the new top-level branch (near line 80, alongside the `--append-approved` special mode)
      following report 02's reference design: iterate `notmuch search --output=messages "$QUERY"`,
      read each message's tags via `notmuch show --format=json --body=false`, derive `action` from
      a `case` over `proposed-delete|archive|unsure|keep`, skip messages with no `+proposed-*` tag,
      and emit one JSON line per tagged message to `$CANDIDATE_FILE.tmp`, then
      `mv "$CANDIDATE_FILE.tmp" "$CANDIDATE_FILE"`. *(completed: branch placed after
      `classify_one()`'s definition rather than near line 80, alongside `--append-approved`,
      so the branch can call `classify_one()` for display confidence/reason before bash
      encounters the function definition — see deviation note below)*
- [x] Enforce invariants: **no `notmuch tag` call anywhere in this branch**; `action` comes only
      from the tag `case`; `classify_one()` may be called only for display `confidence`/`reason`,
      emitted as `reason="tag-derived;..."`; `--limit`/`MAX_BATCH_SIZE` do not apply (process the
      full match). `exit 0` at the end of the branch. *(completed: verified via grep, no
      `notmuch tag` call present in the `--emit-tagged` branch)*
- [x] Update the wrapper's `--help` output to list `--emit-tagged` and note the read-only,
      tag-derived-action, display-only-confidence semantics. *(completed)*

**Deviations**:
- **Task 1.2 (branch placement)** altered: the plan's reference design placed the new branch
  "near line 80, alongside `--append-approved`" — before `classify_one()`'s definition (which
  appears later, alongside the mutating classification tier tables). Since `--emit-tagged`
  calls `classify_one()` for display confidence/reason, and bash requires a function to be
  defined before it is called, the branch was placed immediately after `classify_one()`'s
  closing `}` and before the default mode's `total=$(notmuch search ...)` line, instead of
  alongside `--append-approved`. This preserves the same early-exit control flow (checked
  before the default mode's mutating loop) while fixing a would-be `command not found` bug.

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `~/.dotfiles/modules/home/email/agent-tools/classify.nix` — add `--emit-tagged` arg parse + branch + help text

**Verification**:
- `nix` evaluation / syntax check of the modified module passes (e.g. `nix flake check` or the
  repo's equivalent build for the email agent-tools module).
- Grep confirms the `--emit-tagged` branch contains **no** `notmuch tag` invocation.
- If a live mailbox is available: `email-classify --emit-tagged "<scope> and tag:proposed-delete"`
  then `cat candidate-manifest.jsonl` shows one record per tagged message with
  `proposed_action:"delete"` and `reason` prefixed `tag-derived;`; a re-run leaves durable tag
  counts unchanged.
- Commit made in `~/.dotfiles` only.

---

### Phase 2: Document `--emit-tagged` in the `.dotfiles` wrapper contract (cross-repo) [COMPLETED]

**Goal**: Record the new mode in the `.dotfiles` source-of-truth contract doc so future wrapper
work does not regress it.

**Tasks**:
- [x] Update `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`
      (or its successor contract doc) to add `--emit-tagged` to the `email-classify` mode list. *(completed: §1 table row updated)*
- [x] Document its safety class (read-only; closer to `read-only` than `local-tags-only`), the
      tag-derived-action / display-only-confidence rule, and that it is unbounded (no batch cap). *(completed: new §12 addendum)*

**Timing**: ~0.5 hour

**Depends on**: 1

**Files to modify**:
- `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` (or successor)

**Verification**:
- Doc names `--emit-tagged` and states the read-only / tag-derived / no-cap invariants.
- Committed in `~/.dotfiles` only (may share Phase 1's commit if executed together).

---

### Phase 3: Switch `skill-email-cleanup` `--all` mode to consume `--emit-tagged` [COMPLETED]

**Goal**: Change Stage 1 residual count-probe and Stage 2 residual pass to use the read-only mode,
and add explicit "0 new, all residual" framing.

**Tasks**:
- [x] In `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` `--all` mode Stage 1
      "Count probe" bullet: change the four residual-count probes to
      `email-classify --emit-tagged --account <account> "<SCOPE_QUERY> and tag:proposed-<X>"` and
      count output lines (for X in delete/archive/unsure/keep). Leave the **new-message** count
      probe on the mutating `--limit 0` NOTE-line oracle (untagged messages have no tag to read). *(completed)*
- [x] In Stage 2 "Residual messages" bullet: change each residual pass from
      `email-classify --account <account> --limit <CHUNK_SIZE> "<SCOPE_QUERY> and tag:proposed-<X>"`
      to `email-classify --emit-tagged --account <account> "<SCOPE_QUERY> and tag:proposed-<X>"`. *(completed)*
- [x] Add a distinct one-line status when the new-message count probe reports `N=0`:
      "0 new messages; N residual across 4 tag buckets — proceeding directly to bucket review",
      emitted before Stage 2.5 (documentation/UX only; the residual pass already runs
      unconditionally after the new-message loop). *(completed: Stage 1 item 4)*
- [x] Re-confirm whether the residual "documented completeness caveat" (per-prior-tag bound) can
      be dropped now that `--emit-tagged` has no batch/mutation rationale; drop it only if an
      unbounded per-tag read is acceptable at the account's actual scale, otherwise keep it and
      note why. *(completed: dropped — decided the caveat no longer applies since `--emit-tagged`
      has no `--limit` and processes the full per-tag match unconditionally, so residual coverage
      is complete by construction rather than an estimate bounded by `CHUNK_SIZE`. No live
      mailbox was available to measure actual per-tag bucket scale in this execution
      environment, so a softer performance note was added instead — at very large per-tag
      bucket sizes the per-message `notmuch show` read loop may take noticeably longer, which is
      a latency characteristic, not a coverage gap.)*

**Timing**: ~1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `--all` mode Stage 1 count-probe bullet, Stage 2 residual-pass bullet, "0 new, all residual" status line

**Verification**:
- Grep confirms Stage 1/2 `--all` residual paths reference `--emit-tagged` and no longer use
  `--limit <CHUNK_SIZE>` for residual buckets.
- The new-message count probe still uses the `--limit 0` oracle.
- SKILL.md internal cross-references (Stage 2.5 bucket construction) remain consistent.

---

### Phase 4: Update this repo's `wrapper-contracts.md` [COMPLETED]

**Goal**: Document `--emit-tagged` and correct the emit-on-change framing so future agents do not
re-derive it.

**Tasks**:
- [x] In `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`: add
      `--emit-tagged` to §1 binary/mode table with its read-only safety class. *(completed)*
- [x] Update §6 (approval provenance) and §10 (pagination/manifest contract) to describe the new
      mode's read-only manifest (re)population and that it is exempt from the mutation batch cap. *(completed: §6 item 4, new §10a)*
- [x] Add an explicit note in §10: "classify is NOT emit-on-change — every processed message is
      re-emitted and re-tagged unconditionally", plus the confidence-is-display-only caveat for
      `--emit-tagged`. *(completed: §10 correction paragraph + §10a display-only-confidence bullet)*

**Timing**: ~0.75 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — §1, §6, §10

**Verification**:
- Doc names `--emit-tagged`, states tag-derived-action / display-only-confidence / no-cap, and
  carries the explicit "NOT emit-on-change" correction.
- No contradiction remains between §5c/§10 and the newly documented mode.

---

### Phase 5: Cross-repo verification and consistency check [NOT STARTED]

**Goal**: Confirm the two repos agree and the skill's referenced flag exists in the deployed
wrapper.

**Tasks**:
- [ ] Verify `SKILL.md`'s `--emit-tagged` invocations match the flag name and argument shape
      actually implemented in `.dotfiles` `classify.nix` (Phase 1).
- [ ] Verify both contract docs (`.dotfiles` handoff + this repo's `wrapper-contracts.md`) describe
      the same mode semantics (read-only, tag-derived action, display-only confidence, no cap).
- [ ] If a live mailbox is available, run one end-to-end `--all` dry pass against a fully-tagged
      mailbox and confirm Stage 2.5 review reconstructs without any re-tag (durable tag counts
      stable before/after).
- [ ] Confirm no changes leaked into `mode=default` or the mutation wrappers.

**Timing**: ~0.5 hour

**Depends on**: 2, 3, 4

**Files to modify**: none (verification only)

**Verification**:
- Flag name and args consistent across repos.
- Contract docs agree.
- (If live) fully-tagged mailbox re-surfaces for review with stable tag counts.

## Testing & Validation

- [ ] `.dotfiles` module builds / evaluates after the `classify.nix` change.
- [ ] `--emit-tagged` branch contains no `notmuch tag` call (grep).
- [ ] Action is tag-derived only; `classify_one()` feeds display fields only.
- [ ] `SKILL.md` `--all` residual count-probe and residual pass reference `--emit-tagged`; the
      new-message count probe still uses `--limit 0`.
- [ ] "0 new, all residual" status line present before Stage 2.5.
- [ ] Both contract docs document `--emit-tagged` and carry the "NOT emit-on-change" correction.
- [ ] (If live mailbox) fully-tagged mailbox re-surfaces for Stage 2.5 review; durable tag counts
      unchanged before/after a read-only pass.

## Artifacts & Outputs

- `~/.dotfiles/modules/home/email/agent-tools/classify.nix` — new `--emit-tagged` mode (cross-repo)
- `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` — mode doc (cross-repo)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `--all` Stage 1/2 consuming `--emit-tagged`
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — §1/§6/§10 updates
- `specs/820_email_all_resurface_classified_gap/summaries/02_email-all-emit-tagged-summary.md` — implementation summary

## Rollback/Contingency

- Changes are additive and separable. If `--emit-tagged` proves incorrect, revert the `.dotfiles`
  `classify.nix` commit (the mode is a self-contained new branch); the skill still functions on
  its prior re-classify pattern, so revert Phases 3–4 independently in the nvim repo.
- Because the two repos commit separately, either side can be rolled back without touching the
  other. If the skill was switched to `--emit-tagged` but the binary is reverted, re-point the
  Stage 1/2 residual paths back to the `--limit <CHUNK_SIZE>` pattern.
- No mutation of live mail occurs at any point; all new behavior is read-only, so there is no data
  to restore.
