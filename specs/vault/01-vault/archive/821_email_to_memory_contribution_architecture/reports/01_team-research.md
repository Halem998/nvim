# Research Report: Task #821

**Task**: 821 — Research and design email→memory contribution architecture
**Date**: 2026-07-05
**Mode**: Team Research (4 teammates: Primary, Alternatives, Critic, Horizons)
**Task type**: meta (cross-extension integration: `email` → `memory`)

## Summary

The goal is to route **confirmed** email-cleanup decisions (junk vs keep) from
`skill-email-cleanup` into the memory vault as **sender/domain-aggregated preference memories**
that evolve over time — a granularity the user has already fixed (one evolving memory per
sender/domain, UPDATE/EXTEND, never per-message).

All four teammates independently converged on the same **core architecture**, and July-2026
agent-memory literature (Mem0, MemOS, PersonaTree) corroborates rather than merely permits the
user's aggregation decision. The convergent design is:

- **Capture point**: an opt-in harvest step inside `skill-email-cleanup`, firing **after Stage 6
  (Verify)** on the set of *verified confirmed* actions — never on raw `proposed_action`.
- **Aggregation unit**: the sender/domain bucket that `--all` mode's Stage 2.5 already computes
  (`bulk-bucket-review.md`: domain key, full-address for freemail, `min()` confidence rollup);
  default mode derives the same key post-hoc from the approved manifest's `sender` field.
- **Storage**: vault memories via `skill-memory`'s existing CREATE/UPDATE/EXTEND operations,
  under a **reserved topic namespace** (`email/preferences/{key}`), with a **deterministic
  exact-key dedup** short-circuit *before* the existing fuzzy keyword-overlap path.
- **Gate**: reuse `skill-todo`'s harvest→dedup→tiered-`AskUserQuestion`→batch-index-regen
  *logic* (not its `state.json`/`project_number` substrate, which `/email` lacks), surfacing one
  consolidated opt-in prompt. Never silent; independent of `--clean`.

The disagreements were **not** about this skeleton — they were about **what the design task must
additionally decide before 822 implements it**. The Critic (C) surfaced five load-bearing gaps
the bare skeleton papers over, and the Horizons teammate (D) surfaced two forward-compatibility
decisions (a first-class preference memory *type*, and a named read-back contract) that are cheap
now and expensive to retrofit. **This report's central recommendation is that 821's design
deliverable resolve those gaps explicitly, and that a few of them (revocation UX, success metric,
cross-account scoping) be folded into 822's scope rather than silently dropped.**

## Key Findings

### Primary Approach (Teammate A)

- The **aggregation unit already exists** as a first-class concept: `--all` mode Stage 2.5 bucket
  review groups by sender domain (full address for freemail/shared domains), rolls up confidence
  with `min()` (never `avg()`), labels `[new]`/`[residual]`. This bucket *is* a sender/domain
  human decision — reuse it as the harvest unit; derive the same key in default mode from the
  approved manifest's `sender`.
- **Harvest fires after Stage 6 Verify**, on verified outcomes only (what actually mutated / was
  reviewed-and-kept), one candidate per distinct sender/domain touched — never one per message.
- Because `/email` is **direct-execution (no task directory)**, there is no `state.json` slot for
  a deferred `/todo`-style harvest. Recommend an **immediate inline opt-in** harvest (one extra
  `AskUserQuestion` right after the user already approved the underlying action) over a deferred
  file-queue — matching skill-todo's "gate adjacent to the triggering event" philosophy.
- **Dedup by exact identity, not fuzzy overlap**: look up `topic == "email/preferences/{key}"` in
  `memory-index.json` first (O(1)-style `jq` filter); fall back to fuzzy search only as a
  *suggestion* for near-misses (`mail.foo.com` vs `foo.com`), defaulting to CREATE.
- **Operation mapping**: first sighting → CREATE; same action reconfirmed → EXTEND (append dated
  `## History` line, bump counts); contradicting action → UPDATE (move summary to History, swap
  dominant action). Mirrors Mem0's "contradiction → update, not append."
- **Do not hand-roll decay/EWMA math** in a markdown note; let confirmed-decision **count +
  recency** stand in for confidence, and reuse `/distill`'s existing staleness scoring.
- Distinct from the pre-existing `email-preferences.md` static rule table (compiled into the
  `email-classify` binary) — the vault layer is a **parallel, agent-visible** layer, must not be
  auto-written into the classifier's rule table.

### Alternative Approaches (Teammate B)

- Compared **three capture points**: (A) in-skill harvest, (B) memory-extension lifecycle hook,
  (C) `/todo`-style deferred harvest. Verdict: **in-skill harvest** is the right fit. The
  lifecycle-hook slot (`hooks: {}`) is **schema-ready but unused/unproven anywhere in the repo**
  — its non-fatal-failure-isolation contract is unverified. The `/todo` pattern's *logic*
  transfers but its **storage substrate does not** (`memory-harvest.sh` keys off `project_number`
  in `state.json`, which ad-hoc `/email` sessions don't have).
- Compared **three storage options**: (1) vault memories, (2) dedicated JSONL/sqlite store, (3)
  notmuch tags as source-of-truth + memory cache. Verdict: **option 1** is structurally correct
  and needs the least new machinery, but is **not risk-free** (two required fixes below). Option 3
  is best framed as a *complementary reconciliation source* ("notmuch tags never lie about what
  was decided"), not a replacement. Option 2 is a future escalation path only.
- Two **compatibility risks** against the vault-memory choice, both required fixes regardless of
  capture point: **(i)** deterministic-key dedup deviation from skill-memory's fuzzy contract;
  **(ii)** `/distill`'s **zero-retrieval purge** signal (`retrieval_count==0 AND age>30d`) will
  wrongly flag email-preference memories as stale, because they're read by `skill-email-cleanup`,
  not by the `memory-retrieve.sh` path that increments `retrieval_count`. Must exempt by
  topic-prefix or make the email-side read increment retrieval.
- Prior art converges on three transferable mechanics: **confidence-as-count-not-preference**,
  **temporal decay/hybrid weighting**, and **conflict-resolution-over-deletion** (Mem0's mark-
  superseded → maps to the vault's `## History`).

### Gaps and Shortcomings (Teammate C — Critic)

Five load-bearing gaps the skeleton design does not address (each is a **design-task
deliverable**, not an implementation detail):

1. **Transactional vs. preference conflation** — nothing distinguishes "archive this one
   receipt" from "always junk this sender." Every confirm currently feeds the same pipe.
   → Require an **evidentiary threshold** (e.g. uniform action across the batch for that sender,
   or rolling N≥3 confirms at ≥80% consistency) before writing/strengthening a preference; store
   a running per-action tally, not a single scalar.
2. **Mixed senders** (e.g. GitHub: security alerts=keep, marketing=junk) must be a **first-class
   outcome** — record the split (by subject/category token) or decline to aggregate, never
   average into a false scalar. The review key and the *memory* key are **not obligated to be the
   same partition** (directly qualifies A's "reuse the bucket key").
3. **Identity/normalization** — the manifest `sender` is a **bare unnormalized string**
   (`wrapper-contracts.md:46`), no contract for case, display-name, plus-addressing,
   DMARC-rewritten forwarders, or List-Id vs From. Pick **one documented key + normalization
   rule**, and **verify it against a real `email-census`/`email-classify` sample** before
   committing.
4. **Privacy/scope cross-contamination** — `memory-retrieve.sh` scores **corpus-wide by keyword
   overlap with no task-type namespace filter**, and its >4-char/stopword filter does *not* drop
   proper nouns (`github`, `google`, `notifications` all pass). An email-triage preference can
   leak into an unrelated coding task's `<memory-context>`. → **segregated namespace** + consider
   **redaction/hashing** (domain + stable sender-hash) rather than plaintext-PII addresses.
5. **No success metric / feedback-loop audit** anywhere in the 2-task chain. → define what
   "working" means (per-sender agreement rate, churn reduction, contradiction audit).

Plus a **feedback-loop hazard**: if a stored preference later biases `proposed_action`/confidence
and the human rubber-stamps the pre-biased proposal (automation bias), early mistakes entrench —
and skill-memory's **UPDATE/EXTEND/CREATE have no "weaken/contradict" primitive**. And four
**scope-completeness omissions**: no revocation/edit UX, no cross-account (gmail vs logos)
scoping, no archive-scope isolation (stale archive mail biasing current inbox), no 822 test plan.

### Strategic Horizons (Teammate D)

- **No roadmap entry exists** — `specs/ROADMAP.md` has zero mentions of memory/email/preference.
  821 opens a new capability lane; it must **propose its own ROADMAP.md entries** (and since
  821/822 are `meta`, the standard `completion_summary`+`roadmap_items` flow won't add them — do
  it by hand / a small follow-up).
- **Industry taxonomy treats "preference" as a semantic-memory subtype** needing update-in-place
  consolidation — corroborates the user's decision. But the vault frontmatter (`title, created,
  tags, topic, source, modified`) has **no `category`/`type` field**. **The one genuine schema
  fork**: add a first-class `category: preference` field now (cheap, forward-compatible,
  non-breaking) vs. retrofit later.
- **The loop is one-directional as scoped** — 822 only writes. Without a read-back path the vault
  is a preference *log*, not a preference *engine*: it never makes `/email` faster/safer. The
  "evolves over time" framing implies feedback, and feedback needs a consumer. → 821 should
  **spec a named read-back contract** (a "Future: classifier read-back, not in 822's scope"
  section) so 822's write schema is designed with lookup in mind; file as roadmap item / task 823.
- **Generalize the harvest pattern** (fix-it triage, task-abandonment reasons, PR-review nits)
  → **YES but as a deferred design note**, not 822 scope. Email stays "the first client"; a
  second real client should justify extraction, not speculation.
- Speculative seeds (flag, don't adopt): preference memories as an **exportable notmuch tag
  ruleset** (stronger loop-closure but changes the human-gated safety posture), and as
  **local-model training data**.

## Synthesis

### Conflicts Resolved

1. **"Reuse the review bucket key" (A) vs. "the memory key need not equal the review key" (C).**
   Resolution: adopt C's nuance. Use the Stage 2.5 bucket grouping as the *starting* key and the
   harvest *trigger*, but the **stored** preference key is a normalized identity (Finding C3) and
   must support a **per-sender split** for heterogeneous senders (C2). The review partition
   optimizes human ergonomics; the memory partition optimizes durable identity — related but not
   identical.

2. **"No decay math; count + recency is enough" (A/B) vs. "need an explicit weaken/contradict
   primitive" (C).** Resolution: these reconcile cleanly through the **running per-action tally**
   both sides implicitly point at. Store `{delete_count, archive_count, keep_count, last_seen}` in
   the memory body. A contradicting confirm **increments the opposite counter**, which shifts the
   dominant-action ratio — i.e. contradiction handling falls out of the tally arithmetic **without
   a bespoke decay engine** (A satisfied) **and without needing a new skill-memory API verb**
   (C's gap addressed at the *convention* level, not the API level). The "dominant action" is a
   derived function of the tally, not a stored scalar that must be forcibly overwritten. This is
   the report's key mechanical synthesis.

3. **Inline opt-in harvest (A) vs. deferred `/todo`-style harvest (B's option C).** Resolution:
   inline, because B independently proved the deferred path's substrate (`project_number`) doesn't
   exist for `/email`. Reuse skill-todo's harvest *logic* (tiered classify / dedup / gate /
   batch-regen), not its storage.

4. **Capture-point (B): in-skill vs. lifecycle-hook.** Resolution: in-skill. The hook mechanism is
   unproven in-repo and its failure-isolation contract is unverified — not a starting-design
   dependency. (Revisit only if a second client makes a shared hook worthwhile — see below.)

5. **Storage (B): which store.** Resolution: vault memories (option 1), with notmuch tags (option
   3) as an optional *reconciliation/audit* source, and JSONL/sqlite (option 2) explicitly a
   future escalation only.

### Gaps Identified (must be resolved by 821's design deliverable)

Convergent, high-confidence requirements the design doc must specify:

- **G1 — Evidentiary threshold** before promoting a confirm to a stored/strengthened preference
  (C1); **mixed-sender split** as a first-class branch (C2).
- **G2 — One normalized identity key** (lowercase, plus-tag-strip local-part@domain, domain
  rollup fallback, List-Id preference, DMARC caveat), **verified against a real census/classify
  sample** (C3).
- **G3 — Deterministic exact-key dedup** short-circuit before fuzzy overlap (A + B + C).
- **G4 — Segregated `email/preferences/*` namespace** + `/distill` **zero-retrieval exemption**
  (or retrieval-increment on email-side reads) + cross-contamination fix in `memory-retrieve.sh`
  (or namespace de-weighting) (B5, C4).
- **G5 — Redaction decision**: plaintext address vs domain+hash (C4) — determines the schema.
- **G6 — Feedback-loop guardrails**: cap the confidence a stored preference may contribute to
  `proposed_action`; surface evidence ("junked N, kept M") rather than pre-selecting; the tally
  from Conflict-2 *is* the reversal mechanism (C feedback-loop).
- **G7 — `category: preference` first-class frontmatter field** (D2) — schema-additive,
  non-breaking; recognized by `index.md`/`/distill` where present, not required.
- **G8 — Named read-back contract** as a "future, not in 822" spec section (D1/D5) so the write
  schema is lookup-ready; propose ROADMAP entries + a follow-on task 823.

Convergent recommendations to **fold into 822's scope** (currently missing from the 2-task
chain — flagged by C's scope-completeness section):

- **Revocation/edit UX** for a wrong preference (distinct from `/distill --purge`).
- **Cross-account scoping** decision (gmail vs logos: account-scoped or global key).
- **Archive-scope isolation** (don't let stale archive-era confirms bias current inbox).
- **A minimal success signal / test phase** for 822 (agreement-rate logging or contradiction
  audit) so correctness regressions are visible.

Deferred design notes (document in 821, do **not** implement in 822):

- Generalize the confirmed-decision→preference harvest beyond email (D4).
- Notmuch-ruleset export and local-model training-data angles (D5, speculative).

### Recommendations

1. **Adopt the convergent skeleton**: post-Stage-6 inline opt-in harvest in `skill-email-cleanup`
   → normalized-key aggregated vault memory under `email/preferences/{key}` → deterministic-key
   dedup → skill-todo-style tiered gate → batch index regen.
2. **The 821 design deliverable must resolve G1–G8** — these are the substance of the design task,
   not optional polish. In particular, do the **real census/classify sample check (G2)** during
   design, not in 822.
3. **Model confidence as a per-action tally** (`delete/archive/keep counts + last_seen`); dominant
   action is derived; contradiction handling is arithmetic, not a new API verb.
4. **Recommend expanding 822's scope** to include revocation UX, cross-account scoping,
   archive-scope isolation, and a minimal success-signal phase — or, if the user prefers to keep
   822 lean, spawn a **task 823** for the read-back "preference engine" loop closure and a
   **task 824** for measurement/audit. (Decision for /plan or the user.)
5. **Make the two forward-compat moves now** (cheap, retrofit-expensive): the `category:
   preference` field (G7) and the named read-back contract spec (G8).
6. **Add ROADMAP.md entries by hand** (meta tasks don't auto-annotate): "Preference memory
   read-back for email-classify" and "Generalize confirmed-decision harvest beyond email."

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary (implementation approach) | completed | High (codebase) / Medium (external framing) |
| B | Alternatives & prior art | completed | Medium-High (codebase) / Medium (prior art) |
| C | Critic (gaps & blind spots) | completed | High (findings 1,3,4) / Medium-High (feedback loop) |
| D | Horizons (strategy & roadmap) | completed | High (findings 1,3,4,5) / Medium (scoping calls) |

## References

Codebase (grounded, file/line-cited by teammates):
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (Stage 2.5/3/5/6, five-binary constraint)
- `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md` (bucket grouping, `min()` rollup)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md:43-47` (manifest schema, bare `sender`); `:215-241` (`--emit-tagged`, task 820)
- `.claude/extensions/email/context/project/email/email-preferences.md` (static classifier rule table — distinct layer)
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (CREATE/UPDATE/EXTEND, 60%/30% dedup thresholds)
- `.claude/extensions/memory/README.md:151-160` (frontmatter fields — no `category`/`type`)
- `.claude/scripts/memory-retrieve.sh` (corpus-wide keyword scoring, no namespace filter); `.claude/scripts/memory-harvest.sh` (`project_number`-keyed)
- `.claude/skills/skill-todo/SKILL.md` Stages ~181-253, 694-732 (harvest→dedup→tiered gate→batch regen)
- `.claude/extensions/{email,memory}/manifest.json` (`hooks` empty/absent — zero existing wiring)
- `specs/ROADMAP.md` (no memory/email/preference entries)

Prior art (WebSearch, July 2026 — directionally solid, treat specifics as illustrative):
- Mem0 ADD/UPDATE/DELETE/NOOP + Update Resolver (mark superseded, not delete): arxiv.org/abs/2504.19413; mem0.ai/blog/state-of-ai-agent-memory-2026
- Preference-as-semantic-memory-subtype / update-in-place: atlan.com/know/types-of-ai-agent-memory; MemOS, PersonaTree (arxiv 2606.04780), MemRerank (arxiv 2603.29247)
- Sender-reputation / spam feedback-loop aggregation: sciencedirect.com/science/article/pii/S2405844018353404; arxiv.org/pdf/1205.1357
- Implicit-feedback = confidence-not-preference + temporal decay: dl.acm.org/doi/10.1145/2512208; link.springer.com/article/10.1007/s11227-022-04484-6
- Feedback-loop bias / automation bias: arxiv.org/html/2509.00109v1; DMARC forwarding sender-identity instability: arxiv.org/pdf/2302.07287
