# Research Report: Task #96

**Task**: 96 - surface_literature_coverage_delta_under_lit
**Started**: 2026-08-24
**Completed**: 2026-08-24
**Effort**: medium
**Dependencies**: literature global-index schema-unification (completed — see literature-doc-key.sh
  and the id/path bridge; the sub-index/global-index keying question is settled, see below)
**Sources/Inputs**: codebase (agent-system/extensions/literature/**, agent-system/extensions/core/context/patterns/lit-stage4a-flow.md), specs/TODO.md (companion coverage-marker task, completed)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The existing sparse-coverage guard (`literature-lit-flag-resolve.sh` + the `lit-coverage`
  marker in `literature-briefing.sh`) checks the sub-index's **absolute entry count** against a
  fixed floor (`LITERATURE_SPARSE_THRESHOLD`, default 3). It never looks at the global index at
  all once the sub-index clears that floor. A 37-entry sub-index against a 399-entry global index
  is `SUBINDEX_PRESENT` — reported healthy — with zero comparison ever performed. This is exactly
  the reported blind spot, confirmed by direct code reading, not inference.
- The mechanism to extend is `literature-lit-flag-resolve.sh`'s `SUBINDEX_PRESENT` branch (where
  `entry_count -ge threshold` today short-circuits with no further check) plus the existing
  `SPARSE_PROMPT_NEEDED` directive/marker vocabulary. No new directive token, no new
  `AskUserQuestion` option set, and no new interactive-vs-autonomous branching logic is needed —
  reuse all three.
- **A raw entry-count ratio is not a safe metric on its own.** The global index mixes top-level
  documents and their chunk children in one flat `.entries` array (measured in this environment:
  414 total entries, only 204 are top-level documents with `parent_doc == null`). Comparing a
  doc-level sub-index count (37) against a chunk-inflated global count would overstate the gap by
  roughly 2x. The global side of any delta computation must filter to `parent_doc == null` (or
  `.id // .doc_id` distinct top-level records) to be apples-to-apples with the sub-index, which is
  already doc-level by construction.
- A pure ratio/absolute-gap trigger (e.g. "sub-index is < 20% of global") would fire on almost
  every repo, since a curated sub-index of 10-40 entries will always be dwarfed by a
  200-400-document global corpus — that is normal, not a defect. The actionable signal is
  **topic-scoped**: candidate global documents that match the task's own search terms and are
  absent from the sub-index. `literature-discover.sh`'s Tier 1 matcher (`filter_terms`,
  `term_matches`, stop-word filtering, `MULTI_TERM_MATCH_THRESHOLD`) already implements exactly
  this kind of keyword-vs-global-index matching and is the natural thing to reuse rather than
  writing a second keyword matcher.
- Surfacing must work in `orchestrator_mode == "true"` (autonomous), where `AskUserQuestion` is
  forbidden. The existing precedent — `AUTONOMOUS_GLOBAL` and the autonomous branch of
  `SPARSE_PROMPT_NEEDED` — is "proceed with a deterministic default, but emit a loud,
  non-interactive banner" (the `[SPARSE COVERAGE ...]` banner inside the briefing text itself, not
  just a stderr log). The coverage-delta guard should follow the same shape: advisory-in-prompt
  (a banner inside `lit_context`) always, plus the interactive `AskUserQuestion` re-prompt only
  when not autonomous, reusing the same four options `SPARSE_PROMPT_NEEDED` already offers.
- This task is explicitly scoped to the **briefing-time delta guard** (cheap approximation), not
  the **claim-level check** ("does a draft's 'no counterpart exists' claim hold against the full
  global corpus"), which the task description itself calls out as the expensive alternative and
  tells the plan to decide on rather than silently closing the whole class. Recommend the plan
  implement the cheap guard now and explicitly spin the claim-level check into a named follow-up
  (a `/spawn` candidate), not silently drop it.

## Context & Scope

The task asks for a guard that surfaces the sub-index-vs-global-index coverage delta when `--lit`
is active, so decision-relevant sources sitting in the global corpus (indexed, chunked, readable)
are not silently invisible to research just because they were never added to a repo's curated
`specs/literature-index.json`. Motivating incident (Logos/Theory repo): a 37-entry sub-index
against a 399-entry global index resolved cleanly (37/37, zero skip warnings) while two
research-round conclusions of the form "the framework has no counterpart for X" were reached
without consulting global-corpus sources that define X. The claims happened to survive later
checking, but that was luck, not a pipeline property.

The task is explicitly bounded away from the companion, now-completed coverage-marker task
(`Make the briefing coverage marker report resolution-failure rate` — implemented and merged;
Section G of `test-lit-pipeline.sh` covers its regression). That task closes a different failure
mode: a `doc_id` **is** in the sub-index, resolution against the global index fails, and the
failure was invisible because only successful resolutions were counted into the coverage marker.
This task's failure mode is structurally prior to that one: a source is **never requested at
all** because it was never indexed into the sub-index, so nothing is ever skipped, so the
(correctly implemented) coverage marker reports healthy — and is right to, given what it is
designed to measure. Fixing resolution-failure reporting (companion task) does nothing for a
`doc_id` that was never a candidate in the first place. The two guards are complementary and
belong in the same file-scope declaration (`literature-briefing.sh` / `literature-lit-flag-resolve.sh`)
without being merged into one check.

## Findings

### Codebase Patterns

**`literature-lit-flag-resolve.sh`** (`agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh`)
is the single deterministic decision point upstream of `AskUserQuestion`. Its `SUBINDEX_PRESENT`
branch today is:

```bash
if [ -f "$SUB_INDEX" ]; then
  entry_count=$(jq '.entries | length' "$SUB_INDEX" 2>/dev/null || echo 0)
  if [ "$entry_count" -lt "$LITERATURE_SPARSE_THRESHOLD" ]; then
    echo "SPARSE_PROMPT_NEEDED"; exit 0
  fi
  echo "SUBINDEX_PRESENT"; exit 0
fi
```

It never opens `$GLOBAL_INDEX` in this branch at all — the global index is only read once the
sub-index is *absent* (`PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL`/`GLOBAL_MISSING` branches). This is the
exact code-level confirmation of the reported gap: once a sub-index clears the absolute floor
(default 3), the resolver stops looking at the global corpus for the rest of the run.

**`literature-briefing.sh`**'s `lit-coverage` marker (repo mode) is similarly self-referential:
`coverage_count` is the number of sub-index doc_ids that resolved against the global index, not
a measure of how much of the global index the sub-index represents. `sparse=true` fires only on
`coverage_count < threshold` or a high `skip_rate` (companion task's fix) — both are properties of
the sub-index's own internal resolution, never a comparison to the global index's total size or
topical content.

**`literature-discover.sh`**'s Tier 1 matcher already does global-index keyword matching:
`filter_terms()` strips stop-words and short tokens from a query/description, `term_matches()`
does case-insensitive substring matching against title/keywords, and
`MULTI_TERM_MATCH_THRESHOLD` (5) requires multi-term hits once the filtered-term count is large.
This is the precedent to reuse for computing "candidate global documents matching this task's
terms" rather than inventing a second matcher — consistent with the delegation's instruction to
prefer extending existing machinery.

**Global index shape**: `$LITERATURE_DIR/index.json`'s `.entries` array is flat and mixes
top-level documents (`parent_doc == null`) with their chunk children (`parent_doc == "<id>"`).
Measured in this environment: 414 total entries, 204 top-level documents. A delta computation
that does `jq '.entries | length'` on the global index unfiltered (mirroring the sub-index's own
counting idiom, which is safe there because the sub-index has no chunk children) would silently
compare doc-count to entry-count and overstate the coverage gap by roughly 2x. The global side
must filter to `select(.parent_doc == null)` (the same predicate `literature-briefing.sh`'s repo
mode already uses when hunting for a parent entry, see lines 201-210) to stay doc-level on both
sides of the ratio.

**Existing threshold-and-marker conventions** (`sparse-coverage.md`,
`LITERATURE_SPARSE_THRESHOLD`/`LITERATURE_SKIP_RATE_THRESHOLD`) establish the idiom a coverage-
delta threshold should follow: an env-var-overridable numeric default, a `< threshold` (never
`<=`) comparison, a machine-readable marker line consumers can `grep`, and a loud banner in the
same `[SPARSE COVERAGE ...]`/`[SKIPPED SOURCES ...]`/`[DEGRADED RETRIEVAL ...]` family — never a
silent field nobody reads. The `sparse-coverage.md` file itself explicitly warns against adding "a
separate, unconsumed flag" that "would reproduce the exact silent-degradation failure this
mechanism exists to close" — the same discipline applies here: fold the delta signal into an
existing, already-polled marker/directive rather than adding a field nothing checks.

**Autonomous-mode precedent** (`lit-stage4a-flow.md`, `AUTONOMOUS_GLOBAL` and the autonomous
branch of `SPARSE_PROMPT_NEEDED`): both `MUST NOT call AskUserQuestion`, both take a deterministic
default action, and both emit a visible `[lit:auto] ...` notice on stderr *and* rely on the
in-band `[SPARSE COVERAGE ...]` banner already embedded in `lit_context` for the part of the
signal the consuming research agent actually reads (stderr never reaches the agent's prompt). Any
coverage-delta guard needs the same two-channel signal: an operator-facing stderr notice, and an
in-band banner inside the returned `<literature-briefing>` block, because only the latter reaches
the agent whose "no counterpart exists" claim this exists to guard against.

### External Resources

Not applicable — this is a self-contained internal-pipeline design question; no external
documentation or best-practice research was needed beyond the codebase itself.

### Recommendations

1. **Where the guard fires**: extend `literature-lit-flag-resolve.sh`'s `SUBINDEX_PRESENT` branch.
   After the existing absolute-count check passes (`entry_count -ge LITERATURE_SPARSE_THRESHOLD`),
   add a second check: read the global index, filter to `parent_doc == null`, count topic-scoped
   candidates (global top-level docs whose title/keywords/summary match the query's filtered terms
   via the same matcher `literature-discover.sh` uses) that are **not** already referenced by
   `doc_id` in the sub-index. If that candidate count is non-trivial (e.g. `>= 1`, or a small
   floor — this is a plan-level tuning decision, not a research one), downgrade the directive the
   same way the absolute-count check already downgrades `SUBINDEX_PRESENT` -> `SPARSE_PROMPT_NEEDED`.
   Reusing the existing directive (rather than minting a new one) means `lit-stage4a-flow.md`
   needs no new branch — the `SPARSE_PROMPT_NEEDED` autonomous/interactive split, the four-option
   `AskUserQuestion`, and the two-checkpoint re-prompt logic all already exist and apply unchanged.
   Consider whether the directive text or its wording should distinguish "sub-index too small"
   from "sub-index has topic-scoped misses" for operator clarity, even while keeping the token the
   same — that is a naming/UX call for the plan, not a structural one.

2. **What counts as "materially less"**: reject a bare ratio/absolute-gap trigger (37 vs 399) as
   the firing condition — it is true of nearly every repo with a curated sub-index and would make
   the guard noise, not signal. Use a **compound, topic-scoped** condition instead: global index
   is materially larger (an absolute-gap or ratio pre-filter, cheap to compute, mostly there to
   skip the keyword-matching work entirely when the global index is small or the sub-index is
   already comprehensive) **AND** at least one global top-level document matches the task's own
   filtered search terms and is absent from the sub-index. The second half is what makes the
   signal actionable — it names specific candidate documents, not an abstract percentage.

3. **Matching mechanism**: reuse `literature-discover.sh`'s `filter_terms`/`term_matches`
   machinery (or factor the shared pieces into a small sourceable helper alongside
   `literature-doc-key.sh` if the plan decides two call sites justify extraction) rather than
   writing new term-matching logic. Input is the same `$description`/`$query` the resolver already
   receives via `--query`.

4. **Cost**: this is one extra `jq` pass over a local JSON file (200-400 entries) per `--lit`
   invocation when the sub-index already exists — no network calls, no meaningful latency added.
   No need to gate it behind an additional flag or cache it.

5. **Surfacing shape — both, not either/or**:
   - *Advisory-in-prompt* (mandatory, all contexts including `orchestrator_mode == "true"`): a
     banner inside the `<literature-briefing>` block itself, in the same family as
     `[SPARSE COVERAGE ...]` / `[SKIPPED SOURCES ...]`, naming the topic-scoped candidate count
     and (bounded, e.g. top 5-10) candidate titles/doc_ids so the consuming research agent can act
     on it directly — this is what actually reaches an autonomous run, since stderr does not.
   - *Interactive* (only when not autonomous): reuse the existing `SPARSE_PROMPT_NEEDED` four-option
     `AskUserQuestion` (Use global corpus now / Create curation task / Search online to ingest /
     Skip this run) with prompt wording naming the topic-scoped delta instead of (or in addition
     to) the absolute-count framing. No new option needs inventing.
   - Autonomous runs get the mandatory stderr `[lit:auto] ...` notice per existing convention, plus
     the in-band banner; they must never call `AskUserQuestion` (unchanged rule).

6. **Explicitly out of scope, name it as a follow-up, don't silently drop it**: a claim-level check
   that inspects a draft's specific "no counterpart exists"/"the framework has no X" assertions
   against the global corpus before finalizing is the expensive, more precise mechanism the task
   description itself flags as a live open question ("Decide which is in scope rather than
   silently building the cheap one and calling the class closed"). The research finding here is
   that the briefing-time topic-scoped delta guard (recommendation 1-5) is implementable with
   existing machinery and low cost; a claim-level verifier is a materially different mechanism
   (post-hoc draft scanning, likely a separate pipeline stage or a `/cite`-adjacent check, not a
   Stage 4a briefing-time concern) and should be named explicitly in the plan as a candidate
   follow-up task rather than folded in or silently dropped.

7. **Dependency status confirmed resolved**: the literature global-index schema-unification work
   is complete — `literature-doc-key.sh` and the `.id`/`.path`-bridge/`.doc_id` tolerance pattern
   (`(.id // .doc_id) == $id`) are already in place throughout `literature-briefing.sh` and
   `literature-discover.sh`. A doc_id-keyed delta computation is safe to build on today; it does
   not itself need to solve the `sources/<id>/` (173/399) vs `.path` (399/399) resolution gap the
   dependency retarget called out, since it only needs to detect "is this `doc_id` present in the
   sub-index's list," not resolve a file path — the same tolerant `.id // .doc_id` matching already
   used elsewhere is sufficient.

## Decisions

- Extend `literature-lit-flag-resolve.sh`'s existing `SUBINDEX_PRESENT`/`SPARSE_PROMPT_NEEDED`
  machinery rather than adding a parallel directive or a new AskUserQuestion option set.
- The global side of any delta/ratio computation must count top-level documents
  (`parent_doc == null`), never raw `.entries | length`, to stay doc-level comparable with the
  sub-index.
- The firing condition should be topic-scoped (keyword-matched candidates absent from the
  sub-index), not a bare ratio/absolute-gap, to avoid alarm fatigue on ordinary curated sub-indexes.
- Surfacing must be advisory-in-prompt (banner inside `lit_context`) unconditionally, with the
  interactive `AskUserQuestion` re-prompt as an addition only in non-autonomous contexts.
- The claim-level "no counterpart exists" verifier is out of scope for this task; the plan should
  name it explicitly as a follow-up rather than treat this task as closing that class of risk.

## Risks & Mitigations

- **Alarm fatigue**: an over-eager trigger (e.g. bare ratio) would fire on nearly every repo and
  train operators/agents to ignore the banner. Mitigation: topic-scoped compound condition
  (recommendation 2), matching the discipline already documented in `sparse-coverage.md` around
  the skip-rate threshold's calibration caution.
- **Chunk-count inflation**: computing the global-side count without filtering `parent_doc == null`
  would overstate the gap ~2x (measured: 414 vs 204 in this environment) and could itself become
  a source of false urgency. Mitigation: explicit filter, called out above and should be a review
  checkpoint in the plan/implementation.
- **Prompt bloat**: a banner listing every topic-scoped miss could grow unbounded for a very sparse
  sub-index against a large global corpus. Mitigation: bound the listed candidate titles (e.g.
  top 5-10, matching `literature-briefing.sh`'s existing `--top-n` idiom for global-mode results)
  and state the total count separately from the truncated list.
- **Scope creep into the claim-level check**: without an explicit plan-level note, "close the
  class" language in the task description could tempt an implementer to also attempt claim-level
  verification inside this task, which is a materially larger, different-shaped mechanism.
  Mitigation: call this out explicitly in the plan as future work (recommendation 6).

## Context Extension Recommendations

- **Topic**: coverage-delta / topic-scoped-miss guard design.
- **Gap**: `sparse-coverage.md` documents the absolute-count and skip-rate sparse mechanisms in
  detail but has no section on cross-index (sub-index vs global) delta detection, even though this
  task extends exactly that file's family of mechanisms.
- **Recommendation**: once implemented, add a "Coverage-Delta Detection" section to
  `context/project/literature/domain/sparse-coverage.md` (or a new sibling doc it cross-references)
  documenting the new directive/marker semantics, the `parent_doc == null` filtering requirement,
  and the topic-scoped matching approach, following the existing file's own style and its explicit
  "Authority for the Full Decision Flow" pointer convention.

## Appendix

- Files read: `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`,
  `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh`,
  `agent-system/extensions/literature/scripts/literature-briefing.sh`,
  `agent-system/extensions/literature/scripts/literature-briefing-invoke.sh`,
  `agent-system/extensions/literature/scripts/literature-discover.sh`,
  `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md`,
  `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`,
  `specs/TODO.md` (companion coverage-marker task, entry 78, confirmed completed).
- Measurements taken directly in this environment: sub-index absent in this repo;
  `$LITERATURE_DIR/index.json` — 414 total entries, 204 with `parent_doc == null`.
- No web search was performed; this is a self-contained internal pipeline-design question.
