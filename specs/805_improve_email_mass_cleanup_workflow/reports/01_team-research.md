# Research Report: Task #805

**Task**: 805 - Improve the email/ extension's mass-cleanup workflow (bucket review, `--all`, `--archive`)
**Date**: 2026-07-03
**Mode**: Team Research (4 teammates: Primary, Alternatives, Critic, Horizons)
**Task type**: meta (agent-system / `.claude/extensions/email/`)

## Summary

The three requested capabilities — (1) sender/domain-bucket bulk approval via `AskUserQuestion`,
(2) a `--all` full-inbox batch-drain loop, and (3) a more-cautious `--archive` (Gmail All Mail)
mode — are the correct next step on the email extension's trajectory (ad-hoc single-pass triage →
full mailbox lifecycle management). All three are implementable **entirely on the extension side**
(command + skill + context docs) **without touching the frozen `.dotfiles` wrapper contract**
(MAX_BATCH_SIZE, PLAN_EXPIRY_DAYS, the five binaries) — *provided* the design is built against the
wrapper's real behavior rather than the in-repo summary of it.

The single most important synthesis outcome: **the natural reading of the task ("loop
`email-*-confirmed --execute` in repeated ≤50 batches against one approved manifest") does not
work as-built.** The Critic verified against the live source (`~/.dotfiles/modules/home/email/
agent-tools.nix:235-241`) that `enforce_batch_size()` *hard-refuses* (exit 1, "split required")
any approved manifest containing more than 50 pending IDs for an action — it never auto-processes
a partial batch and leaves the remainder. This directly contradicts the higher-confidence-but-
summary-based claims from the Primary and Alternatives teammates, both of which read the in-repo
`wrapper-contracts.md` (which the Critic proves is stale on exactly this point). **The correct
design is manifest pre-splitting into ≤50-ID sub-manifests, each with its own sha256** — a
materially heavier piece of new orchestration than "loop the execute call," and the crux of the
plan phase.

Recommendation: **extend `skill-email-cleanup`/`email.md` in place** (no fork — unlike `--sync`,
these modes never leave the five wrapper binaries), but treat the plan as **verification-gated**:
re-read the `.dotfiles` source for five specific behaviors before designing against them, and
re-scope two task premises (the confidence-gate framing and the "loop the same call" mechanism)
that do not survive contact with the as-built system.

## Key Findings

### Primary Approach (Teammate A)

- The pipeline already separates unbounded classification from capped execution; bucket review is
  a **presentation layer** added between classify and review (new "Stage 2.5"), not a change to
  the approval-manifest shape or confirm/execute mechanics.
- **Bucket confidence rollup should use `min()`, not `avg()`** — one weak match must not license
  bulk-approving strong ones, preserving the recall-on-keep bias at bucket granularity. The 0.90
  gate is enforced by *which options exist* (a bucket below 0.90 never gets an "approve all as
  delete" option), not by post-hoc filtering of a chosen option.
- The working `AskUserQuestion` bulk-approval idiom in `skill-fix-it/SKILL.md:121-198,221-227`
  (multiSelect, "Select all", grouping-mode pre-question) can be copied almost directly.
- **Extend, don't fork**: `--sync` forked to `skill-email-sync` only because `mbsync` is a
  non-wrapper binary; `--all`/`--archive` never leave the five wrapper binaries, so a fork would
  just duplicate the wrapper-only/mandatory-gate contract across files.
- `--archive` needs: explicit folder-scope separation from INBOX, a second distinctly-worded
  confirmation naming the ~64k blast radius, `--expunge-trash` as opt-in only (never default,
  default to recoverable Trash), and an explicit rule against auto-chaining `/email --sync` after
  a drain.
- **Confidence: High** on the extend-don't-fork call and the AskUserQuestion schema; **Medium** on
  the exact archive folder-scoping flag (could not verify from this repo — flagged for the plan).

### Alternative Approaches (Teammate B)

- Three transplantable in-repo "loop-until-done, resumable, capped" patterns: `skill-orchestrate`
  Stage 3/MT-3 (loop-guard file + circuit breaker), `subagent-continuation-loop.md` (handoff/resume
  mechanics *only* — its subagent-spawning half violates the root-session-gate invariant), and
  `multi-task-operations.md` (Succeeded/Failed/Skipped consolidated reporting).
- **Reuse `<manifest>.state.jsonl` as the loop's own pending-count ledger** — do not invent a
  second idempotency file. The loop's only new state is a per-session batch counter for progress /
  stall detection. (See conflict resolution below — this remains valid but sits *under* a
  splitting layer, not instead of it.)
- `skill-fix-it`'s grouped/separate/combined 3-way confirm with "Select all (N items)" for >20
  items is a ready-made bucket-approval UX; bucket by the existing `match_type: sender|domain`
  taxonomy in `email-preferences.md`.
- The memory extension's `/distill` tombstone → grace-period → hard-delete two-phase design is the
  most relevant distinct prior art for `--archive`'s extra caution (adapt to an in-run
  reversible-then-hard-gated shape, not a literal multi-day wait).
- **Explicitly rejected**: raising MAX_BATCH_SIZE, delegating the review gate to a subagent, and
  regressing to the old 3-tier confidence table (0.80/0.70) that task 803 deliberately tightened.
- **Confidence: High** on prior-art findings; **Medium** on ranking calls — and B explicitly
  caveats that it relied on the harvested `wrapper-contracts.md` summary, *not* the `.dotfiles`
  source, and that any materially different conclusion on the batch-drain loop should be reconciled
  against ground truth first. (The Critic did exactly that.)

### Gaps and Shortcomings (Teammate C — Critic, verified against `.dotfiles` source)

These are direct reads of the as-built frozen wrapper, not inference:

- **F1 (P0, decisive)**: `enforce_batch_size()` hard-refuses (`exit 1`) manifests with >50 pending
  IDs per action — no partial processing. "Loop the same execute call" does not work; the skill
  must **pre-split into ≤50-ID sub-manifests with distinct sha256 each**. Source:
  `agent-tools.nix:235-241`.
- **F2 (P0)**: `PLAN_EXPIRY_DAYS=7` is enforced against raw file **mtime** (`stat -c %Y`), not a
  logical approval timestamp. Splitting a manifest creates fresh mtimes — either silently defeating
  the staleness guard (fresh mtime per split) or forcing the entire drain to finish within 7 days
  of original approval (if mtime preserved via `touch -r`), with no residual-reapproval flow
  designed. Source: `agent-tools.nix:123-140`.
- **F3 (P0)**: `email-classify` is *itself* capped/paginated at `MAX_BATCH_SIZE=50` by default and
  logs "re-run to cover the remainder." The task designs a loop only for the mutation side; the
  **candidate-manifest-building stage needs its own pagination loop** for a 64k scope. Source:
  `agent-tools.nix:334-344,428-439`.
- **F4 (P0)**: Folder scope is a positional notmuch **QUERY** (default `folder:Gmail` = INBOX;
  All Mail requires `folder:Gmail/.All_Mail`). This is undocumented in *every* in-repo email doc —
  `--archive`'s entire feasibility rests on it. Source: `agent-tools.nix:333-344,492-501`.
- **F5 (P1)**: There is **no LLM classification tier** — `classify_one()` is deterministic bash
  with hardcoded confidence constants (0.98/0.60/0.55/0.50). Delete-eligible ≥0.90 only fires for
  ~13 hardcoded personal domains; the "LLM judgment on residual" in `recall-on-keep-bias.md` is
  aspirational, not deployed. **At 64k archive scale the confidence-gate framing barely engages** —
  the real burden is a large `unsure`/low-confidence-archive volume. Source:
  `agent-tools.nix:403-430`.
- **F6-F13 (scope-completeness)**: bucket-approval cardinality/false-positive trade-off unbounded
  (hundreds–thousands of domains vs. AskUserQuestion's small option set); root-session vs.
  multi-day-drain tension (context exhaustion — one long turn vs. bounded-per-invocation resume,
  undecided); `--sync` freeze-during-bulk-ops unreconciled with a multi-day drain; **no field
  validation exists** (the extension has never been loaded/run anywhere — pilot recommended before
  the 64k case); missing circuit-breaker, aggregate audit surface, and a distinct stronger gate for
  `--archive`-sourced `--expunge-trash`; and the in-repo `wrapper-contracts.md` is itself stale on
  F1-F5.
- **Confidence: High** on F1-F5, F13 (direct source reads); Medium-high on F6-F9, F12.

### Strategic Horizons (Teammate D)

- 805 is on-trajectory (803 foundation → `--sync` server loop → whole-mailbox). The risk is scoping
  it as three independent flags rather than one coherent capability.
- **Decouple decision granularity from execution granularity**: the human approves *rules* at
  bucket grain (small bounded decision count); the drain loop applies them mechanically with
  progress-only reporting — **never a per-batch re-prompt** (1,280 batches ÷ 50 makes per-batch
  review impossible, and a second gate would silently reintroduce message-by-message review).
- **Extract a reusable `.claude/context/patterns/batch-drain-loop.md` at the agent-system layer**
  (not email-specific) — "many approved mutations, gated by one human decision, safely resumable"
  is a general primitive with no existing pattern doc.
- **Close the feedback-loop gap** task 803 flagged: bucket approval should *write* (or propose
  writing) durable rules back to the preferences store, not just execute once — otherwise every
  future run re-litigates the same buckets (the exact toil this task exists to reduce).
- **Asymmetric confidence policy by scope** (stricter/corroborated bar for All Mail than inbox),
  expressed in `recall-on-keep-bias.md`/`email-preferences.md` (extension-owned, touches no frozen
  contract).
- **Maintenance-mode reframe**: wire core `loop`/`schedule` skills to run the **read-only Propose
  stage** weekly so a 64k backlog never reaccumulates — with a hard caveat that scheduled/unattended
  runs may run `email-census`/`email-classify` only and **must never call `--execute`** (preserves
  the human-gate invariant). Follow-on, not core scope.
- **Confidence: Medium-high** on 1-5,7; **Medium** on the folder-scope question (which C then
  resolved via direct source read — see F4).

## Synthesis

### Conflicts Resolved

1. **Batch-drain mechanism: "loop the same call" (A, B) vs. "hard-refuse >50, must pre-split" (C).**
   **Resolved in favor of C.** C read the as-built `enforce_batch_size()` at
   `agent-tools.nix:235-241` directly; A and B read the in-repo `wrapper-contracts.md` summary,
   which C independently proves stale on this exact behavior (F13a), and B pre-emptively flagged its
   own reliance on the summary and asked for reconciliation against ground truth. The `--all`/
   `--archive` design must center on **manifest pre-splitting into ≤50-ID sub-manifests, each
   sha256-confirmed**, with the drain loop iterating over sub-manifests. B's "reuse
   `<manifest>.state.jsonl` for idempotency, don't invent a second ledger" survives and composes:
   idempotency still comes from the wrapper's per-manifest state file — there are now simply N
   state files (one per sub-manifest), and the loop's own new state is which sub-manifest index it
   is on plus a batch counter.

2. **Folder-scope flag: "unverified, flag for plan" (A, D) vs. "it's a positional QUERY" (C).**
   **Resolved by C's direct read (F4)**: scope is the notmuch QUERY positional argument
   (`folder:Gmail` default, `folder:Gmail/.All_Mail` for All Mail), not a `--folder` flag. This
   unblocks `--archive` as an extension-side change — but the plan must still confirm the exact
   query string against the live binary, since it is undocumented in-repo.

3. **New skill vs. extend (A: extend; D leaned toward "new skill or clearly separated stages").**
   **Resolved toward extend-in-place with clearly-separated internal stages/branches.** A's
   contract-purity argument is decisive (no non-wrapper binary is introduced, unlike `--sync`).
   D's underlying concern — that new behavior must be *visibly separated*, not silently folded into
   the default path — is satisfied by explicit mode branches (`mode=default|all|archive`) and new
   named stages, not by a fork.

4. **Confidence-gate framing.** A/B took the "delete only ≥0.90 else unsure" premise at face value
   and designed bucket rollups on it; C (F5) showed ≥0.90 only ever fires for ~13 hardcoded
   domains, so at archive scale the gate barely reduces review burden. **Both are compatible**: the
   min()-rollup bucket design (A) is still correct *mechanically*, but the plan must **re-scope the
   expectation** — the dominant archive-scale outcome is a large `unsure`/`archive`-tier volume,
   and either (a) explicitly accept that bucket review is mostly adjudicating archive-tier buckets,
   or (b) add "generalize/extend the classifier" as an explicit prerequisite. This is not a
   contradiction to resolve but a premise to correct.

### Gaps Identified (carry into the plan)

- **Verification-first plan.** Before designing, the planner/implementer must re-read the
  `.dotfiles` source for: F1 (hard-refuse threshold), F2 (mtime-based expiry + `touch -r`
  feasibility), F3 (classify pagination), F4 (exact All Mail query string), F5 (classifier tiers).
  Treat `~/.dotfiles/modules/home/email/agent-tools.nix` as primary; `wrapper-contracts.md` as a
  stale secondary that this task should also **update** to close F13.
- **Two loops, not one**: classify-side pagination (F3) *and* execute-side sub-manifest drain (F1)
  — the task only asked for the latter.
- **Expiry policy decision** (F2): preserve original mtime and design a residual-reapproval flow,
  or reset per split and explicitly own the weakened guard. Must be a conscious, documented choice.
- **Root-session chunking model** (F7): one long-running loop vs. bounded-per-invocation-with-resume.
  Given C's context-exhaustion concern and the direct-execution invariant, bounded-per-invocation
  with a loop-guard file (transplanted from `skill-orchestrate` per B) is the safer default.
- **Pilot before 64k** (F9): the extension has never been loaded/run; a bounded low-stakes `--all`
  pass should validate the mechanics before the `--archive` blast radius.
- **`--archive` extra gates**: distinct stronger confirmation for expunge (A, C-F12), asymmetric
  confidence by scope (D), tombstone/reversible-then-hard two-phase (B), never auto-chain `--sync`
  (A), circuit-breaker + aggregate audit surface (C-F10/F11).
- **Feedback loop** (D): bucket approval should optionally write durable rules back to preferences.
- **Reusable pattern doc** (D): author `batch-drain-loop.md` at the agent-system layer.

### Recommendations (for `/plan 805`)

1. **Extend `skill-email-cleanup` + `email.md` in place**; add `mode=default|all|archive`
   (composable `--all --archive`). No fork, no `manifest.json`/`mail-guard.sh` change.
2. **Design the drain around manifest splitting** (≤50-ID sub-manifests, per-split sha256), with the
   wrapper's `<manifest>.state.jsonl` providing per-sub-manifest idempotency and a loop-guard file
   (orchestrate-style) providing resume + stall detection + a circuit breaker.
3. **Add a classify-side pagination loop** to build candidate manifests over a 64k scope (F3).
4. **Bucket review as a presentation stage** (Stage 2.5): domain grouping, `min()` confidence
   rollup, option-availability gating at 0.90, fix-it's multiSelect/"Select all" idiom; tier the
   bucket list (delete-tier → unsure-tier). Optionally emit durable rule updates (D's feedback loop).
5. **`--archive` = folder-scoped QUERY (`folder:Gmail/.All_Mail`) + extra gates**: second
   blast-radius-naming confirmation, `--expunge-trash` opt-in only (default recoverable Trash),
   asymmetric/corroborated confidence bar, reversible-then-hard two-phase, per-chunk classify, no
   auto-`--sync`.
6. **Verification-first + doc refresh**: re-verify F1-F5 against `.dotfiles`; update the stale
   in-repo `wrapper-contracts.md` (F13) as part of this task's deliverables.
7. **New context docs**: `patterns/bulk-bucket-review.md`, `patterns/batch-drain-loop.md`
   (agent-system layer per D), `domain/archive-mode-risk.md`; update `README.md`/`EXTENSION.md`.
8. **Flag follow-ons** (out of 805 scope): maintenance-mode via `loop`/`schedule` (read-only Propose
   only), persistent domain allow/blocklist, census-diff snapshots, classifier generalization.
9. **Consider a pilot phase** in the plan: bounded `--all` validation run before `--archive`.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary (concrete design) | completed | High (design) / Medium (archive folder flag) |
| B | Alternatives & prior art | completed | High (prior art) / Medium (ranking) |
| C | Critic (verified vs. source) | completed | High (F1-F5, F13) / Medium-high (scope gaps) |
| D | Horizons (strategy/trajectory) | completed | Medium-high (1-5,7) / Medium (scope flag) |

## References

- `~/.dotfiles/modules/home/email/agent-tools.nix:123-140,235-241,333-344,403-439,492-501`
  (as-built frozen wrapper — primary source of truth; verified by Teammate C)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md:9-19,32-76,80-95`
- `.claude/extensions/email/commands/email.md:22-33,41-50,75-80`
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:29-66`
  (in-repo summary — stale on F1-F5 per C-F13; update as part of this task)
- `.claude/extensions/email/context/project/email/standards/recall-on-keep-bias.md:31-42`
- `.claude/extensions/email/context/project/email/patterns/propose-review-confirm-execute.md:31-50`
- `.claude/extensions/email/context/project/email/email-preferences.md:1-40` (§1.2 rule schema)
- `.claude/extensions/email/skills/skill-email-sync/SKILL.md:18-37,70-75` (fork precedent + rationale)
- `.claude/skills/skill-fix-it/SKILL.md:121-198,200-243,344-373` (bulk-approval UX to reuse)
- `.claude/skills/skill-orchestrate/SKILL.md:100-142,597-618` (loop-guard + circuit breaker)
- `.claude/context/patterns/{subagent-continuation-loop,postflight-control,multi-task-operations}.md`
- `.claude/extensions/memory/skills/skill-memory/SKILL.md:954,1057,1184-1390` (two-phase safety)
- `specs/803_email_claude_code_extension/reports/01_email-extension-seed.md`,
  `reports/02_authoring-contract-verification.md`, `summaries/02_author-email-extension-summary.md`
- Commit `51bfda974` (`/email --sync` — mode-flag + separate-skill precedent)
- Teammate findings: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`,
  `01_teammate-c-findings.md`, `01_teammate-d-findings.md`
