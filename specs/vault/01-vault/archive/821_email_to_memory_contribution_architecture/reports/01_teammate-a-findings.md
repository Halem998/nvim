# Research Report: Task #821 (Teammate A — Primary)

**Task**: 821 - Research and design email-to-memory contribution architecture
**Focus**: Concrete implementation approach for wiring skill-email-cleanup into skill-memory
**Sources/Inputs**: Codebase (skill-email-cleanup, skill-memory, skill-todo, memory manifest.json,
wrapper-contracts.md, bulk-bucket-review.md, email-preferences.md), WebSearch (agent-memory
architecture, sender-reputation aggregation)

## Key Findings

1. **The aggregation unit the user wants already exists as a first-class concept in
   skill-email-cleanup**: the `--all` mode's Stage 2.5 bucket review groups candidates by
   sender domain (full address for freemail/shared domains), rolls up confidence with `min()`
   (never `avg()`), and labels buckets `[new]`/`[residual]`
   (`.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md`). This bucket
   *is* a sender/domain-scoped human decision — it is the natural harvest unit, not the
   individual message.

2. **skill-memory already has the exact three-operation vocabulary needed**
   (CREATE/UPDATE/EXTEND) and a working dedup mechanism (keyword-overlap classification: `>60%`
   -> UPDATE, `30-60%` -> EXTEND, `<30%` -> CREATE) plus MCP-or-grep search
   (`.claude/extensions/memory/skills/skill-memory/SKILL.md` lines 159-238). This is generic
   fuzzy-topic dedup tuned for organic prose notes, not for structured per-entity records — see
   Recommendation 3 below on why a stronger key is needed for this specific use case.

3. **skill-todo's harvest pipeline (Stage 7-14) is the correct reusable template for the
   opt-in/gate mechanics**, not skill-memory's raw content-mapping+search pipeline: it defines
   `memory_candidates` (content/category/source_artifact/confidence/suggested_keywords) emitted
   by upstream agents into a task's metadata, a dedup pass against `memory-index.json`
   classified into `NOOP` (>90% overlap, silently excluded) / `UPDATE` (>60%, flagged) / `CREATE`
   (<=60%), a three-tier AskUserQuestion multiSelect gate (Tier1 pre-selected high-confidence
   PATTERN/CONFIG, Tier2 shown WORKFLOW/TECHNIQUE, Tier3 hidden INSIGHT/low-confidence), and only
   then file creation + batch index regeneration. **This exact `memory_candidates` contract is
   already the mechanism this research-agent itself uses** (see this agent's own Stage 5/7
   instructions) — it is a proven, existing cross-skill interface, not something to invent.

4. **The memory extension's `hooks: {}` in manifest.json is empty** — there is no existing
   lifecycle-hook consumer wired for email, and no evidence any extension currently populates
   `hooks` for a cross-extension contribution flow. Building on the `memory_candidates` +
   harvest-at-archival-time convention (Finding 3) is lower-risk than inventing a new hook
   mechanism, because (a) it reuses tested code paths, (b) it does not require a new hook-schema
   dispatch mechanism in `skill-base.sh`, and (c) `/email` is direct-execution (no task-file
   lifecycle) so there is no natural "postflight" moment for a manifest-driven hook to fire
   *unless* email cleanup runs are tied to a task (see Recommendation 1).

5. **The email extension already has a static, pre-existing sender/domain preference artifact**:
   `email-preferences.md` (harvested prior-art rule table: pattern/match_type/condition/action/
   confidence/reason, keyed on sender or domain). This is a *different* mechanism from the
   requested memory-vault route — it is the seed/rule-table consumed by the `email-classify`
   wrapper binary itself (compiled into the nix-packaged tool), not something agents rewrite at
   runtime. The new memory-vault preference records are a *parallel, agent-visible* layer: they
   inform future `/email` invocations' framing/context (via `<memory-context>` auto-retrieval in
   `/research`/`/plan`/`/implement`) and, longer-term, could seed updates to
   `email-preferences.md`, but they must not be confused with, or auto-written into, the
   classifier's compiled rule table.

6. **External research confirms the aggregation model is well-trodden**: agent long-term memory
   frameworks (Mem0, 2026) formalize exactly this ADD/UPDATE/DELETE/NOOP decision per fact
   instead of per-conversation-turn, explicitly to avoid store bloat and duplicate near-identical
   facts — "when a user corrects a preference, Mem0 updates the existing record rather than
   creating a duplicate" (see Evidence below). Sender-reputation literature converges on
   **recency-weighted aggregation (EWMA-style) with decay toward neutral**, not permanent
   confidence, and **event-driven updates** (a reputation figure is revised on each new signal,
   not recomputed from scratch) — both patterns map cleanly onto the EXTEND operation.

## Recommended Approach

### WHERE the harvest fires

Do **not** invent a new hook-dispatch mechanism in `manifest.json`'s `hooks: {}` for this. Instead
extend the **existing** `memory_candidates` convention (Finding 3/4) at the email-cleanup
boundary:

- **Capture point = the human review gate itself** (Stage 3 in default mode, Stage 2.5 bucket
  approval in `--all` mode) — this is where a `proposed_action` becomes a *confirmed* decision,
  which is the correct trust boundary (never harvest from `proposed_action` alone; only from
  what the user actually approved at Stage 3/2.5, i.e. what ends up in the approved manifest and
  survives Stage 5/6 execution verification).
- **Emission point = immediately after Stage 6 (Verify)**, once the wrapper's own execution-state
  diff confirms which Message-IDs actually mutated (or, for `keep` decisions, which IDs were
  reviewed and left in place). At this point `skill-email-cleanup` groups the *verified* outcomes
  by sender/domain (reusing the *exact* bucket-construction logic from Stage 2.5 / Finding 1 —
  even in default mode, where Stage 3 is per-message, derive the same sender/domain grouping key
  post-hoc from the approved manifest's `sender` field) and constructs a small in-memory list of
  aggregated `memory_candidates`-shaped objects, one per distinct sender/domain touched this run
  (not one per message).
- **Persistence of the trigger**: since `/email` is direct-execution and has no task directory,
  there is no `state.json` task entry to stash `memory_candidates` on for a later `/todo` harvest.
  Two options, in order of recommended preference:
  1. **Immediate, opt-in inline harvest**: after Stage 6, if 1+ sender/domain buckets were
     touched, present ONE additional AskUserQuestion ("Update memory preferences for N
     sender/domain(s) touched this run? [Yes / No / Show details]") and, on yes, invoke the
     memory CREATE/UPDATE/EXTEND path directly (in-process, not a subagent) using the aggregation
     schema below. This keeps `/email` self-contained and gives the user a single extra opt-in
     gate at the natural moment (right after they already approved the underlying action) —
     consistent with the "MANDATORY INTERACTIVE REQUIREMENT" style already used by both
     `skill-email-cleanup` and `skill-memory`.
  2. **Deferred, file-based harvest** (fallback if the inline path is judged too heavy for a
     direct-execution skill): append the aggregated candidates to a durable, git-tracked file
     scoped to the email extension, e.g. `.claude/extensions/email/.pending-memory-harvest.jsonl`
     (one line per sender/domain candidate, append-only), and let `/learn` (skill-memory) or a
     new `/learn --email-harvest` mode ingest+dedup+clear it interactively later. This defers the
     interactive gate but avoids adding memory-vault code paths to a direct-execution email skill.
  Recommend **Option 1** — it matches skill-todo's own "gate immediately adjacent to the
  triggering event" philosophy and avoids introducing a second half-finished pending-queue file
  format alongside the JSONL manifests that already exist.

### WHAT the aggregated sender/domain preference memory looks like

One memory per sender-or-domain identity (never per message), using the CREATE template fields
(`.claude/extensions/memory/skills/skill-memory/SKILL.md` lines 360-384) with email-specific
conventions:

```yaml
---
title: "Email preference: {sender_or_domain}"
created: {first-seen date}
tags: ["EMAIL-PREFERENCE"]
topic: "email/preferences/{domain-or-address}"
source: "skill-email-cleanup ({account})"
modified: {today}
keywords: ["email", "{domain}", "{account}", "{dominant_action}"]  # exact domain/address token
                                                                    # is MANDATORY (see dedup below)
summary: "{dominant_action} ({N} confirmed decisions, last {date})"
retrieval_count: 0
last_retrieved: null
---

# Email preference: {sender_or_domain}

**Bucket key**: {domain or full address if freemail/shared domain — same rule as bulk-bucket-review.md}
**Account(s) seen**: gmail, logos
**Confirmed decisions**: {delete: N, archive: N, keep: N, unsure->reviewed: N}
**Dominant action**: {delete|archive|keep} ({confidence range or min-conf rollup})
**Last confirmed**: {ISO date} ({N} message(s) this run)
**Rule-tier basis** (if available): {custom-domain-delete:foo.com | keyword-fallback:newsletter | header-based:list-unsubscribe | user-override}

## History

### {date} — {account} — {N} messages
{action} confirmed at Stage {3|2.5}, min-conf {c}, basis: {reason}

## Connections
<!-- e.g. [[MEM-email-preference-related-domain]] -->
```

**UPDATE vs EXTEND semantics for this schema** (mapping the generic memory-skill operations onto
the sender/domain aggregation the user has already decided on):

- **First sighting of a sender/domain** -> CREATE (as above).
- **Same action confirmed again** (e.g. `foo.com` deleted again) -> **EXTEND**: append a dated
  `### {date}` line under `## History`, bump the `Confirmed decisions` counts and `Last
  confirmed` date in the body (frontmatter `modified` updated). This is the common case and
  matches skill-memory's EXTEND template almost verbatim.
- **Contradicting action confirmed** (e.g. previously archived, now the user confirms `keep`, or
  vice versa) -> **UPDATE**: this is a genuine preference change, not a routine reinforcement.
  Follow skill-memory's UPDATE template: move the current summary to `## History` with a date
  marker, replace `Dominant action` with the new one. This mirrors Mem0's "new fact contradicts
  old fact -> update, not append" rule (see Evidence).
- Do **not** implement numeric confidence decay/EWMA math inside the memory file itself — that
  overengineers a markdown note. Instead, let the **count of confirmed decisions and recency of
  `Last confirmed`/`modified`** stand in for confidence: a sender/domain confirmed 8 times as
  `delete` is a stronger, later-retrieved signal than one confirmed once 200 days ago, and the
  existing distillation staleness scoring in skill-memory (Stage on `/distill`) already surfaces
  stale/never-retrieved memories for review — reuse that machinery rather than adding a second
  decay engine.

### HOW dedup + UPDATE works against memory-index.json

The generic skill-memory dedup (fuzzy keyword-overlap search, thresholds 60%/30%) is the wrong
primary key for this use case: a domain/address is an **exact identity**, and fuzzy overlap could
either miss a match (short domain name, few shared keywords) or false-positive across unrelated
senders that share a generic keyword like "newsletter". Recommended dedup path, layered on top
of (not replacing) the existing mechanism:

1. **Exact-match lookup first**: before falling back to the generic MCP/grep keyword search,
   look up `memory-index.json` entries whose `topic` equals
   `"email/preferences/{domain-or-address}"` (or, equivalently, whose `keywords` array contains
   the exact lowercased domain/address token). This is a deterministic O(1)-style filter over the
   already-loaded index (`jq -r --arg t "email/preferences/foo.com" '.entries[] | select(.topic==$t)'`),
   analogous to skill-todo's `dedup_action` classification but keyed on identity rather than
   Jaccard overlap.
   - Exact hit -> **UPDATE or EXTEND** per the semantics above (never CREATE a duplicate for the
     same domain).
   - No exact hit -> fall back to the standard fuzzy search only to catch legitimate near-miss
     cases (e.g. `mail.foo.com` vs `foo.com` subdomain consolidation) as a **suggestion**, not an
     auto-merge; default to CREATE if no exact match exists.
2. **Topic-namespace convention**: reserving `email/preferences/*` as a topic prefix keeps these
   machine-generated aggregation memories visually and structurally distinct from organic
   user-authored `/learn` memories, and lets `/distill`'s topic-cluster grouping
   (`cluster_key = topic.split("/")[0]` -> `"email"`) naturally group them for health reporting
   without special-casing.
3. **Batch index regeneration**: identical to skill-todo Stage 14 — after all buckets touched in
   one `/email` run are processed, regenerate `memory-index.json`, `index.md`, and
   `10-Memories/README.md` ONCE (not per-bucket), following the existing "JSON Index Maintenance"
   procedure verbatim.
4. **Keyword superset discipline**: when UPDATE/EXTEND-ing, follow the same invariant used in
   `/distill --merge` (keyword superset guarantee) — the updated memory's `keywords` array must
   remain a superset of what it had before, so retrieval never regresses.

### Opt-in / gate behavior

- **Never silent**: exactly like `--lit`'s "no silent no-op" discipline and skill-memory's
  "MANDATORY INTERACTIVE REQUIREMENT", the harvest step must surface an explicit
  AskUserQuestion before any memory file is written or updated. Recommended single consolidated
  prompt (multiSelect, one option per touched sender/domain bucket), reusing the bulk-bucket-review
  presentation idiom:
  ```json
  {
    "question": "Save/update email preference memory for these sender(s)/domain(s)?",
    "header": "Memory harvest ({N} bucket(s) touched this run)",
    "multiSelect": true,
    "options": [
      {"label": "Select all (N buckets)", "description": "..."},
      {"label": "foo.com -> delete (8th confirmation, min-conf 0.98)", "description": "CREATE|UPDATE|EXTEND: ..."}
    ]
  }
  ```
- **Selecting nothing** exits gracefully with no file writes (same contract as every other
  AskUserQuestion gate in this system).
- **Scope gating**: only sender/domains with a **verified** (post Stage-6) confirmed action are
  eligible — never harvest from `proposed_action`/`unsure` candidates that were declined or left
  untouched at the bucket-approval stage. This preserves the "review gate is never skipped"
  invariant: the memory harvest is downstream of, never a substitute for, the mandatory human
  review.
- **Composability with `--clean`**: this harvest step is a *write* path, not the *retrieval* path
  `--clean` suppresses, so it should NOT be gated by `--clean` (which only affects
  `<memory-context>` auto-retrieval in `/research`/`/plan`/`/implement`). Gate it only by the
  new email-specific AskUserQuestion above, and document that distinction clearly to avoid the
  natural (but wrong) assumption that `--clean` also disables this write.
- **Archive-scope caution**: because `scope=archive` runs can touch very large buckets (up to
  ~64,000 messages/All-Mail), cap the harvest prompt at a reasonable number of buckets per
  question (reuse the existing >20-buckets "Select all" idiom) and consider deferring
  archive-scope harvest to a follow-up `/learn` pass rather than blocking the drain's progress
  reporting with an oversized AskUserQuestion.

## Evidence/Examples

- Bucket construction, `min()` confidence rollup, `[new]`/`[residual]` labeling:
  `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md` (whole file).
- Stage 2.5 (`--all` mode) bucket approval as the mandatory human review gate; Stage 3 (default
  mode) per-message review; Stage 6 verify-against-wrapper-state-files:
  `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` lines 158-179, 283-315, 379-384.
- Manifest schema (JSONL keyed on Message-ID, `proposed_action`/`confidence`/`reason`):
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` lines 43-47;
  `--emit-tagged` read-only re-emit (task 820) lines 215-241.
- skill-memory CREATE/UPDATE/EXTEND templates, dedup thresholds (60%/30%), MCP-or-grep search:
  `.claude/extensions/memory/skills/skill-memory/SKILL.md` lines 159-384.
- Memory extension's empty `hooks: {}` (no existing lifecycle-hook consumer):
  `.claude/extensions/memory/manifest.json` line 59.
- skill-todo harvest pipeline (`memory_candidates`, NOOP/UPDATE/CREATE dedup at 90%/60%, 3-tier
  AskUserQuestion gate, batch index regen): `.claude/skills/skill-todo/SKILL.md` Stages 7, 9, 14
  (lines 180-253, 694-732).
- Pre-existing static sender/domain rule table (different mechanism, classifier-consumed):
  `.claude/extensions/email/context/project/email/email-preferences.md` (harvested prior-art:
  pattern/match_type/condition/action/confidence/reason, 14 custom-domain-delete rules at
  confidence 0.98).
- Mem0 (2026) ADD/UPDATE/DELETE/NOOP four-operation model, "when a user corrects a preference,
  Mem0 updates the existing record rather than creating a duplicate" — validates the
  UPDATE-on-contradiction / EXTEND-on-reinforcement split recommended above. See
  [The Mem0 architecture: How agent memory works](https://aikickstart.com.au/news/mem0-architecture-how-agent-memory-works),
  [Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory (arXiv)](https://arxiv.org/pdf/2504.19413).
- Sender-reputation aggregation literature: EWMA-style recency-weighted scoring, decay toward
  neutral absent new signals, event-driven (not batch-recomputed) updates — validates using
  recency/count rather than a hand-rolled decay formula. See
  [Reputation Score — an overview (ScienceDirect)](https://www.sciencedirect.com/topics/computer-science/reputation-score),
  [8 Factors Affecting Sender Reputation](https://www.mailforge.ai/blog/8-factors-affecting-sender-reputation).

## Confidence Level

**High** for the codebase-integration recommendations (capture point, bucket reuse, dedup-by-topic-
namespace, opt-in gate mechanics) — these are grounded in exact file/line references to existing,
tested patterns already in this repo.

**Medium** for the external best-practices framing (EWMA/decay, Mem0 four-operation model) — the
general shape (aggregate-and-update rather than append-per-event, contradiction triggers
update/merge rather than duplication) is well-corroborated across sources, but the search results
are mostly high-level vendor/blog content rather than primary academic papers with hard numbers,
so treat specific claims (e.g. "1-2 week stabilization") as illustrative, not load-bearing for
design decisions.
