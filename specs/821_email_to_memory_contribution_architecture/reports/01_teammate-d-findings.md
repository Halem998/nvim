# Teammate D Findings: HORIZONS (Long-Term Alignment & Strategic Direction)

**Task**: #821 - Research and design email-to-memory contribution architecture
**Role**: Teammate D — strategic/roadmap-alignment angle
**Scope note**: This report addresses trajectory, generalization, loop-closure, and
unconventional scoping. It deliberately does not re-derive the sender/domain aggregation
mechanics (schema fields, dedup thresholds) — that is the mechanics teammates' territory. Where
mechanics and strategy intersect (e.g. "does this need a new memory *type*"), this report states
the strategic requirement and defers the field-level implementation to the synthesis.

## Key Findings

1. **The memory extension has no roadmap entry for this at all.** `specs/ROADMAP.md` (Phase 1
   and Phase 2, read in full) contains zero mentions of memory, preferences, or email. Its
   current priorities are documentation infrastructure (manifest-driven READMEs, marketplace
   metadata, CI doc-lint) and agent-system quality (extension slim-standard enforcement,
   frontmatter validation). Task 821/822 is not accelerating a named roadmap item — it is
   opening a new capability lane. That is not a problem, but it means this task should *itself*
   propose the roadmap entries it wants to create (see Recommendation 3), since nothing upstream
   is pulling it forward.

2. **Industry taxonomy (July 2026) already treats "preference" as a semantic-memory subtype,
   not an ad-hoc note** — this validates, rather than merely permits, a distinct preference
   memory shape. Current agent-memory literature separates memory by *type* (episodic, semantic,
   procedural, working) independently from memory *architecture* (storage/retrieval mechanics).
   Preference facts specifically live inside semantic memory and are explicitly called out as
   needing update-in-place consolidation rather than duplication when a user's stance changes
   (Mem0's "update the existing memory rather than duplicating it" pattern; MemOS's provenance/
   lifecycle abstraction for heterogeneous memory types). This is the same shape task 821 already
   committed to (sender/domain-aggregated, UPDATE/EXTEND, not per-message) — the industry
   direction corroborates the user's decision rather than just tolerating it.

3. **The vault's current schema has no place to mark a memory as "preference-typed."** I grepped
   `.memory/10-Memories/*.md` for a `category:` or `type:` frontmatter field — none exists. The
   documented frontmatter is `title, created, tags, topic, source, modified` (memory
   README.md lines 151-160). "Preference" would today have to be encoded informally via `tags`
   or `topic` (e.g. `topic: email/senders/example.com`), which works but is invisible to any
   future maintenance tooling (`/distill`) that wants to treat preference memories differently
   from factual/decision memories (different staleness rules, different merge rules, different
   export rules — see Finding 5). **This is the one genuine design fork for 821**: encode
   "preference" as a first-class field now (cheap, forward-compatible) versus defer it and
   retrofit later (cheaper today, technical debt later).

4. **The harvest mechanism 821/822 want already exists in generalized form and has one committed
   client.** `skill-todo`'s harvest flow (SKILL.md ~Stage 181-237) is: scan completed-task
   artifacts -> classify candidates into tiers -> dedup against the vault -> user-gated
   create/update -> tiered reporting ("Memory harvest: N created (T1, T2, T3), N skipped"). This
   is not email-specific machinery; it is a *generic* confirmed-decision-to-memory harvest
   pattern that task 821's design should explicitly reuse rather than reimplement. The email
   extension's manifest.json `hooks` field is empty (`{}`), and the memory extension's
   `manifest.json` has no top-level `hooks` key at all (confirmed via `jq '.hooks'` on both,
   Bash output above) — so today there is exactly zero pre-existing wiring between the two
   extensions. 821 is not extending an established channel; it is building the first one.

5. **The loop is currently one-directional and the strategic payoff is entirely in the read
   path, not the write path.** Task 820 (email-classify's `proposed_action`) and task 822
   (write preferences to the vault) are both artifacts of the *same* underlying capability idea
   — "the system should get better at triage over time" — but as scoped, 822 only implements the
   write side. Nothing in 821's or 822's description commits to memory-informed classification.
   Without a read-back path, the vault becomes a preference *log*, not a preference *engine*: it
   accumulates sender reputations that a human could read manually (mildly useful, akin to a
   personal CRM) but that never make `/email` faster, safer, or less repetitive to run. The
   entire "evolves over time" framing in the task title implies feedback, and feedback requires
   a consumer.

## Recommended Approach

1. **Design 821 as a two-artifact deliverable: (a) the sender/domain-aggregated write-path spec
   822 will implement, and (b) an explicit, named read-back contract that 822 does NOT have to
   implement but that a follow-on task can pick up without re-litigating design.** Concretely:
   821's output should include a section titled something like "Future: classifier read-back
   (not in 822's scope)" specifying: what memory-retrieve.sh-style query `email-classify` would
   run (e.g. sender/domain exact-match lookup against `.memory/10-Memories/` filtered by a
   preference marker), what it would return (a prior disposition + confidence + last-seen date),
   and how it would modify `proposed_action`/`confidence` (e.g. a prior "always delete this
   sender" memory raises confidence on a repeat `delete` proposal; it should never *silently*
   override to auto-execute — the existing propose/review/confirm/execute gate stays intact).
   File this as a new roadmap item and/or a follow-on task (823?) rather than letting it evaporate
   as an unwritten aspiration. This is cheap now (a paragraph of spec) and expensive to
   reconstruct later once 822 has shipped a schema that wasn't designed with lookup in mind.

2. **Introduce a first-class `category: preference` (or `memory_type: preference`) frontmatter
   field in this task, scoped narrowly.** Given Finding 3 and Finding 2 (industry convention
   treats preference as a semantic-memory subtype requiring different lifecycle handling than
   factual/decision memories), retrofitting this after 822 ships means either a migration pass
   over existing preference memories or permanently living with tag-based inference. The
   scope should be minimal: extend the frontmatter schema and `index.md` generation to recognize
   the field where present; do not require it (existing memories keep working with no field).
   This is a schema-additive, non-breaking change appropriate for 821's design doc even though
   822 will be the one to write it into skill-memory.

3. **Recommend 821 explicitly propose two ROADMAP.md entries** (Phase 2, "Medium-Term
   Improvements," where task 710's literature centralization already lives as a precedent for
   cross-cutting infra work): (a) "Preference memory read-back for email-classify" (the loop
   closure from Recommendation 1), and (b) "Generalize confirmed-decision harvest beyond email"
   (see below). Since /todo's roadmap-annotation only fires from `completion_summary` +
   `roadmap_items` on non-meta tasks, and 821/822 are `task_type: meta`, this task's synthesis
   should note that these roadmap items need to be added by hand to ROADMAP.md (or via a small
   follow-up meta task) rather than assuming the standard completion flow will do it.

4. **On generalization (fix-it triage, task abandonment, PR review decisions): recommend YES,
   but as a *named, deferred* design note in 821 rather than as in-scope work for 822.** The
   underlying shape — "a human confirms a disposition on a recurring, keyed entity; aggregate
   that disposition into an evolving preference memory keyed by the entity, not by the individual
   event" — is genuinely domain-agnostic. `skill-fix-it`'s tag triage (recurring tag types/
   locations), task abandonment reasons (recurring blocker categories), and PR review decisions
   (recurring reviewer preferences/style nits) all fit the same shape. However, 822's estimated
   effort is already 3 hours for the email-only path with full test/doc obligations across two
   extensions; folding a generalized harvest abstraction into the same task risks scope creep
   into a third design surface. The pragmatic move: 821 documents the *shape* of the general
   pattern (one paragraph, "N: confirmed-decision-keyed-by-entity -> aggregate preference
   memory, with skill-todo's tiered classify/dedup/gate as the reference implementation") and
   flags it as a candidate for its own future meta task once email (822) proves the pattern
   works in practice. Building the general abstraction before it has a second real client risks
   guessing wrong about the abstraction boundary — email should stay "the first client," and a
   second client (fix-it, most likely, given it already produces structured task-creation output)
   should be what justifies extracting the general mechanism, not speculation now.

5. **Unconventional scoping worth flagging even if not adopted**: two angles from the
   personalization-layer literature that reframe what the vault entry *is*, beyond "a markdown
   note a human might read":
   - **Preference memories as an exportable notmuch tag ruleset.** Since the email extension
     already operates entirely through notmuch tags (`+proposed-*` cursor tags, per the email
     README), a sender/domain preference memory could double as the source-of-truth for a
     generated notmuch tag/filter rule (e.g. "senders with a `delete` preference memory and
     confidence > 0.9 auto-get a `+low-priority` tag on arrival"), making the vault entry
     directly executable rather than only advisory. This is a stronger loop-closure than
     Recommendation 1's classifier-hint approach, but also a bigger commitment (it starts
     *acting* on stored preference rather than just *informing* a proposal) — flag it, don't
     adopt it as the default design, since it changes the safety posture of a system whose whole
     design (per the email README's two-layer enforcement and propose/confirm/execute gate) is
     built around human-gated mutation.
   - **Preference memories as future local-model training/fine-tuning data.** 2026 agent-memory
     literature (MemOS, PersonaTree) treats structured preference stores as reusable substrate
     for both retrieval-time context injection *and* offline model adaptation. If sender/domain
     preference memories accumulate with consistent schema and enough volume, they become a
     natural candidate corpus for training a lightweight local classifier (a genuinely
     `skill-email-cleanup`-external artifact) that could eventually replace or supplement
     `email-classify`'s heuristic proposed_action logic. Worth a one-line mention in 821's
     "future direction" notes; not actionable now, no vendor/model chosen, and would need its
     own task once/if the vault accumulates meaningfully.

## Evidence/Examples

- `specs/ROADMAP.md` (full read): no mention of memory/email/preference in either Phase 1 or
  Phase 2; task 710 (literature centralization) is the closest analog for "cross-extension infra
  work landing in Phase 2."
- `.claude/extensions/email/README.md` lines 63-73 (Workflow: Propose -> Review -> Confirm ->
  Execute) and lines 74-84 (Two-Layer Enforcement): establishes that any read-back path
  (Recommendation 1) must stay inside the existing human-gated confirm/execute boundary — a
  preference memory can raise/lower `confidence` on a `proposed_action`, but must not itself
  trigger `--execute`.
  `.claude/extensions/memory/README.md` lines 151-160 (Frontmatter Fields table): confirms no
  `category`/`type` field exists today, only `title, created, tags, topic, source, modified`.
- `grep -n "harvest" .claude/skills/skill-todo/SKILL.md`: confirms a generalized, already-shipped
  tiered harvest -> dedup -> user-gated-create/update -> reporting flow (Stages ~181-237, 690,
  742-757) that 821 should point to as the reusable mechanism rather than re-derive.
- `jq '.hooks' .claude/extensions/email/manifest.json` -> `null`; `jq '.hooks'
  .claude/extensions/memory/manifest.json` -> `{}`: confirms zero existing cross-extension wiring
  — 821 is originating this integration, not extending one.
- Web research (July 2026 sources) on preference-as-semantic-memory-subtype and
  update-in-place consolidation, corroborating the task's already-decided aggregation approach:
  - [What Is AI Agent Memory and Why It Powers Intelligent AI Agents in 2026](https://gleecus.com/blogs/ai-agent-memory-intelligent-ai-agents-2026/)
  - [Best AI Agent Memory Frameworks in 2026: Compared and Ranked](https://atlan.com/know/best-ai-agent-memory-frameworks-2026/)
  - [Agent Memory Architectures: Patterns and Trade-offs (2026)](https://atlan.com/know/agent-memory-architectures/)
  - [Types of AI Agent Memory: Episodic, Semantic, Procedural and More](https://atlan.com/know/types-of-ai-agent-memory/)
  - [AI Agent Memory 2026: Progress Benchmark Report Evaluations (Mem0)](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
  - [MemRerank: Preference Memory for Personalized Product Reranking (arXiv)](https://arxiv.org/pdf/2603.29247)
  - [PersonaTree: Structured Lifecycle Memory for Person Understanding in LLM Agents (arXiv)](https://arxiv.org/pdf/2606.04780)

## Confidence Level

- **High confidence**: Findings 1, 3, 4, 5 (directly verified via file reads/greps in this repo,
  not inference).
- **Medium-high confidence**: Finding 2 and Recommendation 2 (industry taxonomy is consistent
  across multiple independent 2026 sources, but the specific frontmatter field name/shape is a
  design choice for the synthesis to finalize, not a fact to verify).
- **Medium confidence**: Recommendations 1 and 4 (the strategic argument for loop-closure and
  generalization-as-future-work is sound and grounded in the repo's own roadmap precedent, but
  reasonable people could scope 822 to include a minimal read-back stub rather than deferring it
  entirely — flagging this as the main point the synthesis should explicitly decide rather than
  silently drop).
- **Lower confidence / speculative**: Recommendation 5's two "unconventional" angles (notmuch
  ruleset export, local-model training data) — included as strategic seeds per the prompt's
  request for creative scoping, not as things 821 should commit to now.
