# Research Report: Task #805 — Teammate B (Alternatives & Prior Art)

**Task**: 805 - Improve email/ mass-cleanup workflow (batch-drain, `--all`, `--archive`)
**Role**: Teammate B — Alternative Approaches & Prior Art (do not duplicate primary recommended-design angle)
**Sources/Inputs**: `.claude/extensions/email/**`, `specs/803_email_claude_code_extension/**`,
`.claude/context/patterns/{subagent-continuation-loop,checkpoint-execution,postflight-control,
team-orchestration,multi-task-operations}.md`, `.claude/skills/{skill-orchestrate,skill-fix-it}/SKILL.md`,
`.claude/extensions/memory/skills/skill-memory/SKILL.md`
**Artifacts**: this report

## Key Findings

1. **The wrapper contract already half-solves idempotent batching at the binary level.**
   `email-archive-confirmed`/`email-delete-confirmed` maintain a companion
   `<manifest>.state.jsonl` execution-state file per approved manifest, skip already-`executed`
   IDs, and enforce `MAX_BATCH_SIZE=50` and `PLAN_EXPIRY_DAYS=7` *inside the binary*
   (`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:38-51`). This
   means task 805's `.state.jsonl`-based idempotency requirement is not a new mechanism to
   invent — it's already the wrapper's own re-run safety net. The orchestration-layer job is
   only to *loop* calls to the existing `--execute` interface and read its existing state file,
   not to build a second competing idempotency ledger.

2. **This repo has three independently-evolved "loop until done, resumable, capped" patterns**
   that are directly transplantable to the `--all` batch-drain flag, with different trade-offs:
   - `subagent-continuation-loop.md` (context-exhaustion handoff loop, max 3 continuations)
   - `skill-orchestrate/SKILL.md` Stage 3 + Stage MT-3 (state-machine loop, `MAX_CYCLES`,
     no-eligible-tasks circuit breaker, per-cycle loop-guard file)
   - `postflight-control.md` (marker file + loop-guard counter, capped at 3, emergency bypass)
   All three converge on the same shape: a small JSON loop-guard file in the task directory,
   a max-iteration cap, and a "stuck detector" that breaks the loop rather than spinning forever.

3. **This repo already has an interactive bulk-approval-by-bucket precedent that predates
   AskUserQuestion sender-buckets**: `skill-fix-it/SKILL.md` Step 7.5 ("Topic Grouping") and
   Step 7.5.4 ("Topic Group Confirmation") cluster N items by shared terms/file-section/action,
   then offer exactly three choices — **grouped / separate / combined** — via a single
   `AskUserQuestion`. This is structurally identical to what "bulk approval by sender/domain
   bucket" needs (cluster candidates into buckets, then approve/reject per-bucket instead of
   per-message), and it already has a "Select all (N items)" affordance for >20 items
   (`skill-fix-it/SKILL.md:175-196`) directly reusable for mailbox-scale (~64k) volumes.

4. **The harvested prior-art email harness (`email-preferences.md`) already defines
   sender/domain-scoped rules with a *tiered* confidence design that was explicitly tightened
   for this extension**: prior art used a 3-tier confidence table (≥0.80 auto / 0.70-0.79
   flagged-borderline / <0.70 manual), which task 803 deliberately replaced with the current
   binary "≥0.90 delete else unsure" gate
   (`.claude/extensions/email/context/project/email/email-preferences.md:1-40`). This is a
   documented alternative that was already considered and rejected — worth citing as "prior art
   we should NOT regress to" rather than a fresh alternative to propose.

5. **Multi-task dispatch (`multi-task-operations.md`) has an already-solved "consolidated
   progress reporting" format** (Succeeded/Failed/Skipped tables + batch commit message) that is
   a ready-made template for "--all" progress reporting across repeated batches, and its
   "failure of one unit must not block others" principle
   (`multi-task-operations.md:415-449`) maps directly onto "one failed batch of 50 must not
   abort the whole drain."

6. **The memory extension's `/distill --gc` / `--purge` two-phase tombstone-then-hard-delete
   design** (`skill-memory/SKILL.md:954,1057,1355-1366`) is a distinct alternative idempotency
   *and* safety mechanism worth naming for `--archive`'s extra-caution requirement: soft-mark
   (tombstone / provisional tag) now, hard-delete only after a grace period and a second
   confirmation — structurally different from `<manifest>.state.jsonl`'s "did we already move
   this message" tracking, and better suited to the near-irreversible All Mail case than to
   ordinary inbox cleanup.

## Recommended Approach (Alternatives Ranked)

### Focus Area 1 — Bulk approval by sender/domain bucket

| Rank | Alternative | Trade-off vs. plain per-message AskUserQuestion | Verdict |
|------|-------------|--------------------------------------------------|---------|
| 1 | **Adopt fix-it's grouped/separate/combined 3-way pattern**, but bucket by `sender`/`domain` (using the existing rule `match_type` taxonomy already in `email-preferences.md` §1.2) instead of fix-it's shared-term clustering. One `AskUserQuestion` per bucket-group tier, "Select all" affordance reused verbatim for >20 buckets. | Reuses a proven, already-shipped algorithm and confirmation UX; avoids inventing a fourth bulk-approval UI in the codebase. Con: fix-it's clustering is keyword-based, not sender/domain-based — needs a substitution of the clustering key, not the confirmation flow. | **Adopt** |
| 2 | **Tiered auto/unsure/keep queues** (three separate AskUserQuestion passes: show `delete`-tier buckets first, then `unsure`-tier, `keep` tier auto-skipped/silent) rather than one mixed bucket list. | Matches the recall-on-keep-bias standard's own tiering language (`recall-on-keep-bias.md`) and reduces cognitive load per pass (user reviews ~10 delete-candidate sender-buckets, then separately ~10 unsure sender-buckets). Con: more total AskUserQuestion round-trips for the same mailbox vs. a single combined bucket list. | **Adopt as a refinement of #1**, not a replacement — tier the bucket list, don't add a 4th confirmation mechanism. |
| 3 | **Domain allowlist/blocklist file** (a persistent, git-tracked `context/project/email/domain-policy.md` or similar the user curates over time, consulted by `email-classify` deterministic-first tier) instead of re-asking every run. | Matches `recall-on-keep-bias.md`'s own "deterministic rules first, LLM only on residual" tiering (§Deterministic-First, LLM-on-Residual) and reduces repeat-approval fatigue for senders already triaged in a prior run. Con: is a data/policy change (new persistent file + write path), not purely a UX change to the review stage — heavier lift, touches `email-classify`'s rule-loading, not just the skill's review stage. | **Worth adopting as a fast-follow**, not in task 805's scope (which is skill/command-level, not wrapper/classifier-level) — flag as a follow-up rather than build now. |
| 4 | **Summary-preview-then-confirm** (show only aggregate counts per bucket — "127 messages from noreply@X, propose delete" — with an expand-for-detail secondary option) instead of showing every message. | Lower cognitive load at ~64k mailbox scale. Con: duplicates what fix-it's grouped mode + fix-it's "Select all (N items)" already deliver (label already carries the count); a separate expand-detail affordance adds a second interaction mode with no clearly distinct benefit over drilling into "Keep as separate tasks"-equivalent. | **Reject as a distinct alternative** — subsumed by #1's group labels, which already carry `{item_count}` in the description field per `skill-fix-it/SKILL.md:344-350`. |
| 5 | **unsubscribe-first pass** (run `email-unsubscribe-extract` and resolve List-Unsubscribe candidates in one dedicated approval pass *before* the delete/archive bucket pass, rather than interleaving it "for senders the user flagged" as the current cleanup skill does — `skill-email-cleanup/SKILL.md:69-71`). | Front-loading unsubscribe reduces the volume of *future* mass-cleanup runs (fewer recurring senders to re-triage every pass) and is a natural first step for an entire-mailbox operation, unlike ad-hoc `/email`. Con: adds one more mandatory human gate before any deletion happens, lengthening the interactive setup phase for `--all`/`--archive`. | **Adopt for `--all`/`--archive` specifically** (whole-mailbox context justifies the extra front-loaded pass); not needed for the existing ad-hoc `/email` (no changes there). |

### Focus Area 2 — `--all` batch-drain loop

| Rank | Alternative | Trade-off vs. a bespoke new drain loop | Verdict |
|------|-------------|------------------------------------------|---------|
| 1 | **Transplant `skill-orchestrate`'s Stage 3 state-machine loop shape**: a `.email-drain-loop-guard` JSON file (session_id, batch_count, max_batches, last_updated) in the task/session scratch dir, a `while` loop with a per-iteration status re-check, and a "no-eligible-work" circuit breaker (mirrors Stage MT-3 step 4, `skill-orchestrate/SKILL.md:613`) that exits cleanly when a batch classify pass returns zero pending-approved IDs. | This is the closest existing analogue to "repeated ≤50 batches until done": same iterate-check-dispatch-recheck shape, same idea of a loop guard surviving interruption. Con: `skill-orchestrate` is an *agent-lifecycle* loop (research→plan→implement), so its state vocabulary (researching/planned/etc.) doesn't map 1:1 — only the loop-guard/circuit-breaker *mechanics* transplant, not the state table. | **Adopt the mechanics, not the vocabulary.** |
| 2 | **Reuse `<manifest>.state.jsonl` directly as the loop's own progress ledger** (read `pending = approved_count - executed_count` from the wrapper's own state file each iteration; stop when `pending == 0`), instead of a separate `.email-drain-loop-guard` idempotency file. | Zero new idempotency surface — the wrapper already tracks this, per contract §4 (`wrapper-contracts.md:38-41`). The loop's ONLY new state is "how many batches have I run this session" (a simple counter for progress reporting / stall detection), which does not need to duplicate execution status. Con: none identified — this is strictly less machinery than inventing a second state file. | **Adopt — this directly satisfies the task's own idempotency requirement without new design.** |
| 3 | **Per-continuation git commit after each batch** (mirrors `subagent-continuation-loop.md`'s "Per-Continuation Git Commits" — commit after every drain iteration, not only at the end). | Preserves partial progress if the drain is interrupted mid-mailbox (analogous rationale: "if a later continuation fails, earlier progress is preserved"). Con: for email cleanup the "progress" that matters is mailbox state (server + maildir), not a git-tracked file — the git commit only captures the approved-manifest/state-file bookkeeping, not the actual mutation. Still valuable for audit trail continuity. | **Adopt for the manifest/state-file bookkeeping commit only** — not a substitute for the manifest's own state tracking. |
| 4 | **Multi-task-operations.md's "Succeeded/Failed/Skipped" consolidated table** adapted to "batches attempted / IDs archived / IDs deleted / IDs failed / IDs remaining" for the `--all` progress report, rather than a bespoke report format. | Reuses an established, already-documented reporting convention instead of inventing a new one; keeps the progress report consistent with how other batch operations in this repo report partial success (`multi-task-operations.md:369-410`). Con: multi-task-operations.md's table is per-*task*, not per-*batch*-of-messages — column semantics need renaming, not restructuring. | **Adopt with renamed columns.** |
| 5 | **A dedicated "drain supervisor" subagent looping via the `Agent` tool** (spawn a fresh subagent per batch, like `subagent-continuation-loop.md`'s successor-spawning) instead of the root/skill session looping in place. | This is explicitly **incompatible with task 805's stated invariant**: "direct-execution in root session (no background subagent for the gate)". The continuation-loop pattern's whole point is delegating long-running work to fresh-context subagents — but the mandatory human-review gate must stay in the root/direct-execution session per the task's invariant and per `skill-email-cleanup/SKILL.md`'s existing "Direct Execution" framing. | **Reject** — flagged explicitly since it is the most tempting transplant (it's the closest pattern by loop *mechanics*) but violates a hard invariant in the task description. |
| 6 | **Raise or dynamically tune batch size instead of looping** (e.g. detect large mailboxes and request a higher `MAX_BATCH_SIZE` via a wrapper flag). | Directly prohibited by the task ("do NOT raise MAX_BATCH_SIZE=50 — loop instead") and undermines the wrapper's own safety cap, which exists precisely to bound blast radius per invocation (`wrapper-contracts.md:48`). | **Reject — explicitly out of scope by task invariant.** |

### Focus Area 3 — `--archive` (Gmail All Mail, ~64k msgs, near-irreversible)

| Rank | Alternative | Trade-off vs. running the same `--all` drain loop unmodified against All Mail | Verdict |
|------|-------------|-------------------------------------------------------------------------------|---------|
| 1 | **Tombstone-then-grace-period-then-hard-action, borrowed from `/distill --purge`/`--gc`** (`skill-memory/SKILL.md:954,1057,1355-1366`): for `--archive`'s scope, first apply a soft/reversible action (archive, which is already reversible per `recall-on-keep-bias.md:41-42`) across a batch, and only permit `--expunge-trash`-class hard operations after a second, separate confirmation once the archive batch is verified — mirroring the memory vault's "tombstone now, hard-delete only after grace period + explicit `--gc`" two-phase design. | This is the single most relevant *distinct* prior-art mechanism for "extra caution / near-irreversible blast radius" because it is the only pattern in this repo that already separates a reversible soft-action from a later, separately-gated hard-action for exactly the reason task 805 calls out (large, near-irreversible risk). Con: the memory vault's grace period is measured in days across separate `/distill` invocations, not within one `--archive` run — needs adaptation to an in-run two-stage confirm (batch approved → archived → optional follow-up "now expunge" pass) rather than a literal multi-day wait. | **Adopt the two-phase reversible-then-hard-gated shape**; do not literally import a 7-day wait into a single-session flag. |
| 2 | **Sampling-based pre-flight estimate before committing to a ~64k-message drain** (run `email-census`/`email-classify` in a scoped "estimate first N buckets, extrapolate volume" mode, show the user "~64k messages, ~1,280 batches of 50, est. review buckets: ~40" before starting the loop) rather than launching the batch-drain loop directly. | Gives the human reviewer a scale-appropriate expectation before an operation that will run many more batches than ordinary inbox cleanup; cheap to add given `email-census` is already read-only. Con: `email-census` already reports senders/folders/date ranges (`skill-email-cleanup/SKILL.md:44-47`) — this is arguably not a new UX so much as *always showing* the batch-count arithmetic that Focus Area 2's progress reporting (ranked #4 above) already computes per-iteration; as a one-time preflight display it is a light, additive convenience rather than a competing design. | **Adopt as a lightweight addition** to Focus Area 2's progress-reporting mechanism (display the estimate once before the loop starts), not a separate mechanism. |
| 3 | **A stricter/second confidence gate specifically for All Mail** (e.g. require ≥0.95, not ≥0.90, before auto-proposing delete when operating in `--archive` scope) as the primary "extra caution" lever. | Directly extends the existing, already-documented confidence-gate mechanism (`recall-on-keep-bias.md:31-42`) with a scope-conditional threshold, which is a minimal, well-understood change (one number, one condition) rather than a new mechanism. Con: `--archive` per the task description is about *archiving* All Mail (already the more-reversible action per `recall-on-keep-bias.md`), so a delete-specific stricter gate may be solving the wrong verb — needs to be paired with #1's archive/hard-action split rather than substituted for it. | **Adopt as a secondary reinforcement**, paired with #1, not standalone. |
| 4 | **Read-only "diff preview" against a prior All Mail census snapshot** (persist the previous `email-census` output for the All Mail folder; before `--archive` runs, diff against the new census and highlight only what changed since last run) instead of a fresh full classify pass every time. | Reduces redundant review of buckets already triaged in a previous `--archive` run — similar rationale to Focus 1's domain-allowlist alternative. Con: requires persisting and diffing census snapshots, a new stateful artifact with its own staleness/invalidation questions; heavier than the task's scope and overlaps with the domain-allowlist follow-up already flagged in Focus Area 1 (#3). | **Reject for task 805's scope** — same rationale as Focus Area 1 alternative #3: flag as a possible future follow-up, not part of this task. |

## Evidence/Examples (file:line)

- Wrapper-baked idempotency and batch cap (the ground truth to loop against, not duplicate):
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:38-51`
- Agent-level restatement of the same constants and "do not batch around the cap" instruction:
  `.claude/extensions/email/agents/email-implementation-agent.md:80-87`
- Manifest lifecycle stages (propose/review/confirm/execute/verify) and freeze-sync-during-bulk-ops note:
  `.claude/extensions/email/context/project/email/patterns/propose-review-confirm-execute.md:1-51`
- Recall-on-keep bias, deterministic-first tiering, and the ≥0.90 delete confidence gate:
  `.claude/extensions/email/context/project/email/standards/recall-on-keep-bias.md:1-42`
- Prior-art confidence table that was deliberately tightened for this extension (cite as rejected precedent):
  `.claude/extensions/email/context/project/email/email-preferences.md:1-40`
- Existing sender/domain rule schema (`match_type: sender|domain|subject|from_addr`) reusable as the bucket key:
  `.claude/extensions/email/context/project/email/email-preferences.md` §1.2 (rule schema section)
- Direct-execution / mandatory-stop-for-review invariant already encoded for `/email` (do not delegate the gate to a subagent):
  `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md:9-19`
- Topic-grouping cluster algorithm + grouped/separate/combined 3-way confirm (bucket-approval precedent):
  `.claude/skills/skill-fix-it/SKILL.md:200-243`
- "Select all (N items)" affordance for >20-item interactive selection (directly reusable at mailbox scale):
  `.claude/skills/skill-fix-it/SKILL.md:175-196`
- Effort/description-count scaling in group labels (subsumes "summary preview" as a distinct alternative):
  `.claude/skills/skill-fix-it/SKILL.md:344-373`
- Orchestrate state-machine loop guard file + circuit breaker (mechanics to transplant for `--all`):
  `.claude/skills/skill-orchestrate/SKILL.md:100-142` (Stage 2, single-task loop guard)
  `.claude/skills/skill-orchestrate/SKILL.md:597-618` (Stage MT-3, multi-task no-eligible-work circuit breaker)
- Subagent continuation loop (max 3 continuations, handoff-based resume) — cited as the pattern whose
  *subagent-spawning* half must NOT be transplanted (violates task 805's root-session-gate invariant):
  `.claude/context/patterns/subagent-continuation-loop.md:1-50, 186-199`
- Postflight marker/loop-guard file protocol (max 3 continuations, emergency bypass) — general loop-guard precedent:
  `.claude/context/patterns/postflight-control.md:37-134`
- Multi-task batch dispatch: per-unit isolation, "failure of one must not block others," consolidated
  Succeeded/Failed/Skipped report format (adapt for `--all` batch progress reporting):
  `.claude/context/patterns/multi-task-operations.md:369-449`
- Memory vault tombstone-then-grace-period-then-hard-delete two-phase design (the distinct alternative
  idempotency/safety mechanism for `--archive`'s extra-caution requirement):
  `.claude/extensions/memory/skills/skill-memory/SKILL.md:954, 1057, 1184-1390`
- `/email --sync` freeze-during-bulk-ops note (interacts with any drain loop — do not run `--sync` mid-drain):
  `.claude/extensions/email/commands/email.md:75-80`

## Confidence Level

**High** for Findings 1, 2, 3, 6 and the file:line citations above — all drawn directly from
on-disk, task-803-verified artifacts and already-shipped skill patterns in this repo; no
speculation involved.

**Medium** for the specific ranking/adoption calls in the Recommended Approach tables — these are
my synthesis of trade-offs based on reading the cited patterns, not independently verified against
a live mailbox or the actual wrapper binary source (which lives outside this repo, in
`~/.dotfiles`, and was not re-read here; I relied on the harvested summaries in
`wrapper-contracts.md` and `email-preferences.md`, which report themselves as verified against
`email_execute.py` at harvest time). If the primary/root researcher's report reaches materially
different conclusions on Focus Area 2 (the batch-drain loop), reconcile against Finding 2 above
first — reusing `<manifest>.state.jsonl` as the loop's own pending-count source is the
highest-confidence, lowest-risk recommendation in this report and should not be superseded by a
new bespoke idempotency file without strong justification.
