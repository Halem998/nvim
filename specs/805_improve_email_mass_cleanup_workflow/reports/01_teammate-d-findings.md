# Research Report: Task #805 — Teammate D (Horizons: Long-Term Alignment & Strategic Direction)

**Task**: 805 - Improve email/ extension mass-cleanup workflow
**Role**: Teammate D — Horizons (strategic scoping, trajectory, adjacency)
**Sources**: specs/ROADMAP.md, specs/TODO.md, `.claude/extensions/email/**`, task 803 artifacts
(reports 01/02, plan 03, summary 02), commit 51bfda974, core `loop`/`schedule` skills.

## Key Findings

1. **The extension's trajectory is "ad-hoc single-pass triage" → "full mailbox lifecycle
   management," and 805 is the correct next step, not a scope surprise.** Task 803 built the
   foundation (wrapper-only execution, propose→review→confirm→execute, recall-on-keep bias);
   commit 51bfda974 (`/email --sync`) closed the loop to the Gmail server. 805's three asks
   (bucket approval, `--all` batch-drain, `--archive`) are the logical continuation: go from "one
   50-message pass" to "the whole mailbox." Nothing here is off-trajectory — the risk is scoping
   it as three independent flags rather than one coherent capability.

2. **The math on `--archive` (~64k messages ÷ MAX_BATCH_SIZE=50 ≈ 1,280 batches) rules out
   monolithic per-batch human review as the interaction model.** No user will meaningfully review
   1,280 batches one at a time. The task description's own shape (bucket-level approval feeding a
   mechanical batch-drain loop) is the right answer, but this report makes explicit a distinction
   the task description leaves implicit: **decouple decision granularity from execution
   granularity.** The human approves *rules* at bucket/sender/domain grain (a small, bounded
   number of decisions); the batch-drain loop then *mechanically* applies those approved
   rules/manifest across many `--execute` batches with progress reporting, never a per-batch
   re-prompt. Progress reporting during drain should be informational + abort-capable only, not a
   second approval gate — a second gate per batch would silently reintroduce the exact
   message-by-message review the bucket-approval design is meant to eliminate.

3. **A genuine reusable primitive is buried inside this task and is worth extracting rather than
   building email-only.** The "approved manifest + idempotent `<manifest>.state.jsonl` +
   capped-batch loop, resumable within a `PLAN_EXPIRY_DAYS` window" shape is not email-specific —
   it is a general answer to "how does an agent system safely apply many approved mutations against
   an untrusted-content domain, gated by one human decision instead of N." Nothing else in this
   repo currently documents this as a named agent-system pattern (checked
   `.claude/context/patterns/` — no `batch-drain` or `bulk-mutation` pattern exists; the closest is
   `subagent-continuation-loop.md`, which is about multi-turn agent orchestration, not bulk-mutate
   safety). Recommend authoring `.claude/context/patterns/batch-drain-loop.md` at the **agent-system
   layer** (`.claude/context/`, not `.claude/extensions/email/context/`) describing the shape
   generically (approved-manifest capping, execution-state idempotency, staleness window, abort
   semantics) with email as the first concrete instance. This is a "where to store new content"
   judgment call per this repo's own CLAUDE.md: "Agent system pattern (orchestration, format,
   workflow)? → `.claude/context/`." A future bulk-mutation need (e.g., a hypothetical bulk
   task-archival cleanup, or a bulk file-tagging extension) could then cite this pattern instead of
   re-deriving it from scratch.

4. **Task 803's own harvest report (report 01) already named the compounding-value gap this task
   should not skip: classification currently has no feedback loop from human review decisions back
   into future classification.** `email-preferences.md` is a static, one-time harvest from the
   retired `~/Mail` harness (14 domain-delete rules, 1 sender-keep rule, keyword-fallback lists).
   Every future `/email` (and future `--all`/`--archive`) run re-asks the human about senders it
   has already ruled on, because there is no mechanism for "user approved delete for
   sender X in bucket review" to become a standing rule. Report 01 explicitly flagged
   "VIP allow-list derived from contacts/sent-folder correspondents" and "reply-history scoring" as
   **absent, not omitted** — gaps for future work, not decisions already made. 805's bucket-approval
   UX is the natural place to close this: when a human approves "all mail from
   newsletters@example.com → delete" at the bucket level, that decision should append (or propose
   appending, pending a lighter-weight confirmation) a new rule to `email-preferences.md`-equivalent
   storage, not just execute once and forget. Without this, `--all`/`--archive` will make the human
   re-litigate the same buckets on every future run — the exact toil this task exists to reduce.
   This is an adjacency opportunity, not scope creep: it reuses the review UI 805 is already
   building; it just needs to also *write*, not only read, the rules.

5. **`--archive`'s higher blast radius is a strong argument for asymmetric classification policy
   between inbox and All Mail scope, expressed at the extension/classification layer — not the
   frozen wrapper contract.** `standards/recall-on-keep-bias.md` currently sets one global bar
   (confidence ≥ 0.90 to auto-propose delete). For All Mail (~64k, "closer to irreversible after
   `--expunge-trash` + sync"), consider requiring a *corroborating* second signal before
   auto-proposing delete at archive scope — e.g., `List-Unsubscribe` header present AND/OR domain
   match against the harvested 14 delete-rule domains AND confidence ≥ 0.90, versus confidence
   alone at inbox scope. This is purely a classification-policy change inside
   `email-preferences.md`/`recall-on-keep-bias.md` (extension-owned), so it does not touch
   MAX_BATCH_SIZE, PLAN_EXPIRY_DAYS, or the five wrapper binaries — fully within 805's stated
   invariants.

6. **An unverified assumption in the task description that another teammate's research should
   confirm empirically: do the five wrapper binaries support folder/scope selection (INBOX vs.
   Gmail All Mail) at all?** The wrapper-contract summary (`context/project/email/domain/
   wrapper-contracts.md §1-§2`) documents `--account gmail` (reserved) and `--manifest-dir`, but no
   `--folder`/`--scope` flag for any of the five binaries. If `email-census`/`email-classify` only
   ever operate over one implicit scope (e.g., INBOX), `--archive` cannot be built as a pure
   extension-side flag — it would require a capability the frozen wrapper contract does not
   currently expose, meaning it is blocked pending a cross-repo ask to `.dotfiles` task 72's owner
   (referenced by name only, never designed here per the task's own constraint). This should be
   verified by the Depth/Coverage teammate (e.g., `email-census --help`, `email-classify --help`)
   before planning assumes `--archive` is purely a same-extension change. Flagging this as the
   single highest-leverage unknown for scoping the plan phase.

7. **A reframing worth considering: separate "one-time backlog drain" from "ongoing maintenance,"
   and use existing core primitives (`loop`, `schedule`) for the latter rather than treating
   `--archive` as a single heroic 64k-message event that, once done, drifts right back to a large
   backlog.** This repo's core skill set already includes a `loop` skill ("Run a prompt or slash
   command on a recurring interval") and a `schedule` skill ("create/update/list/run scheduled
   cloud agents (routines) that execute on a cron schedule"). Neither is currently wired to
   `/email`. A "maintenance mode" — e.g., a weekly scheduled/looped invocation that runs only the
   **read-only Propose stage** (`email-census` + `email-classify`) and lands a fresh candidate
   manifest for review at the user's next interactive session — would keep the mailbox from
   reaccumulating a 64k-message archive backlog in the first place, turning "clean the whole
   mailbox" from a one-time bulk operation into a standing, low-friction practice (a handful of
   bucket approvals per week instead of one 1,280-batch drain every few years).

   **Critical safety caveat, stated explicitly because it is easy to get wrong**: this MUST stop at
   the Propose stage. `/schedule`'s cron/cloud routines and `/loop`'s unattended interval runs have
   no human present, and this task's own invariants say "mandatory human review gate" and
   "interactive gate cannot live in a background subagent." A scheduled/looped job may run
   `email-census`/`email-classify` (both read-only/tag-only, no maildir/IMAP mutation) and persist
   an updated candidate manifest, but must never call `--execute` unattended, no matter how high the
   confidence score. This preserves every invariant in the task description while still delivering
   the "recurring maintenance" outcome — it is additive automation of the *read* side only, never
   automation of approval or mutation.

## Recommended Approach

1. **Keep the three flags as specified** (bucket-approval UX, `--all` batch-drain,
   `--archive`), but implement bucket-approval so it can emit **both** an approved execution
   manifest (as today) **and** a durable rule update (append-style, human-reviewable diff) to the
   preferences store — closing the "no feedback loop" gap from finding 4. This is additive to the
   task's proposed AskUserQuestion flow, not a redesign.
2. **Before planning `--archive`, verify wrapper-binary folder/scope support** (finding 6). If
   scoping isn't supported, scope 805 to build `--archive` up to the point where it is
   provably blocked on a cross-repo capability, and spawn a follow-up cross-repo ask (by name only,
   per the task's own constraint) rather than quietly assuming scope support that may not exist.
3. **Differentiate delete-confidence policy by scope** (inbox vs. archive) inside the existing
   `recall-on-keep-bias.md` standard — a same-extension, low-risk change that meaningfully reduces
   blast radius for the higher-stakes `--archive` path (finding 5).
4. **Extract the batch-drain-loop shape as a named agent-system pattern doc**
   (`.claude/context/patterns/batch-drain-loop.md`) rather than leaving it embedded only in
   email-specific skill prose, so it is discoverable and reusable the next time any extension needs
   "many approved mutations, gated by one human decision, safely resumable" (finding 3).
5. **Treat "ongoing maintenance mode" as a natural, low-cost follow-on** (not part of 805's core
   deliverable, but worth flagging to the planner/user as a roadmap item): a weekly `loop`/`schedule`
   invocation of the Propose stage only, landing a fresh manifest for the next interactive review —
   this is what actually prevents the 64k-message backlog from recurring after `--archive` cleans it
   once (finding 7).

## Evidence/Examples

- Batch math: 64,000 msgs ÷ `MAX_BATCH_SIZE=50` ≈ 1,280 `--execute` batches — cited from
  `context/project/email/domain/wrapper-contracts.md §5` (constants table) combined with the task
  description's "~64k msgs" figure.
- No existing agent-system pattern doc for bulk-mutation-over-approved-manifest:
  `.claude/context/patterns/` contains `subagent-continuation-loop.md`,
  `context-discovery.md`, `jq-escaping-workarounds.md`, `multi-task-operations.md` — none address
  bulk/batch mutation safety.
- Task 803 report 01 (`specs/803_email_claude_code_extension/reports/01_email-extension-seed.md`
  §2, "GAP NOTE — new work, NOT harvestable"): explicitly lists "VIP allow-list derived from
  contacts/sent-folder correspondents — absent" and "Reply-history / thread-participation
  scoring ... absent," confirming these are open gaps rather than deliberate omissions.
- `context/project/email/domain/wrapper-contracts.md §2` documents the full global flag surface
  of the five binaries (`--execute`, `--confirm-manifest`, `--account gmail` reserved,
  `--manifest-dir`) with no folder/scope flag present — the basis for finding 6's blocking question.
- Core skills `loop` and `schedule` (listed in this session's available-skills index) exist
  independent of the email extension and are not currently wired to any `/email` invocation —
  basis for finding 7's maintenance-mode proposal.
- Commit 51bfda974 (`/email --sync`) shows the extension's incremental-capability pattern already
  in practice: each capability addition (sync) was added as a clearly separated skill
  (`skill-email-sync`) with its own confirmation gate, rather than folding new behavior into
  `skill-email-cleanup` — a precedent 805 should likely follow for `--all`/`--archive` (new skill(s)
  or clearly separated stages within `skill-email-cleanup`, not silent behavior changes to the
  default path).

## Confidence Level

**Medium-high** on findings 1-5 and 7 (direct textual evidence from ROADMAP.md, TODO.md, the
email extension's own docs, and task 803 artifacts). **Medium** on finding 6 (the wrapper-binary
scope-flag gap is inferred from the absence of a documented flag in this extension's own summary
of the frozen contract, not from direct inspection of the `.dotfiles`-owned binary source, which is
out of scope for this repo/session) — flagged explicitly as something another teammate or the
planning phase should verify empirically rather than take on my inference alone.
