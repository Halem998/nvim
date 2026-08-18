# Implementation Plan: Fix literature-discover.sh tier starvation and silent Tier 3 failure

- **Task**: 70 - Fix literature-discover.sh tier starvation and silent Tier 3 failure
- **Status**: [NOT STARTED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/reports/01_fix-discover-tier-starvation.md
- **Artifacts**: plans/01_fix-discover-tier-starvation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`literature-discover.sh` has three confirmed discovery-correctness defects: Tier 3 (Semantic
Scholar) failures are indistinguishable from "nothing found online"; Tier 1 consumes the entire
`DISCOVER_LIMIT` budget so Tier 2's real hits are computed and then discarded by the final
`jq '.[0:$limit]'` head-slice and Tier 3 early-returns; and the search query is built by
concatenating an entire multi-paragraph task description, so a single incidental shared word
surfaces unrelated papers. This plan fixes all three inside the source store
(`agent-system/extensions/literature/**`), plus the required companion change at the caller layer
in `commands/literature.md`, whose blanket `2>/dev/null` would otherwise make any inner stderr
fix inert. Done means: a rate-limited Tier 3 run emits a visible notice, every tier gets a
reserved share of `DISCOVER_LIMIT` with rollover of unused slots, and Tiers 1/2 matching is
noise-resistant for long term lists.

### Research Integration

The research report (`reports/01_fix-discover-tier-starvation.md`) confirmed all three defects by
direct code reading and supplied the fix directions this plan adopts:

- Defect 1 is two-layered: `literature-discover.sh`'s `tier3_search 2>/dev/null || true` at the
  tier-dispatch block AND `commands/literature.md` step 1's three `2>/dev/null` invocations. A
  single-file fix is inert. `commands/literature.md` itself already names this gap as deferred
  scope in its step-0 closing paragraph.
- Defect 2 is more a truncation bug than a starvation bug: `tier2_search()` caps on its own local
  `count` against the full `DISCOVER_LIMIT` with no awareness of what Tier 1 already spent, so
  `RESULTS` can hold ~2x the limit and the final head-slice keeps only Tier 1's entries.
  `tier3_search()` already has the right shape (checks the shared total, computes `remaining`) —
  it is just applied against a budget Tier 1 has already exhausted.
- The established directive/rationale idiom to mirror is `zotero-export-status.sh`: one token to
  stdout, human-readable rationale to stderr on every branch, caller captures stderr to a file
  rather than discarding it (`literature.md` already does exactly this for
  `zotero_directive`/`zotero_rationale`).
- Query noise: `SEARCH_TERMS` concatenates `description` then `title` with no cap; `filter_terms()`
  drops only <3-char words and an 18-word stop list; `term_matches()` is an unranked substring OR
  that accepts on the first hit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make Tier 3 non-200 / curl-failure outcomes visible as a machine-parseable stderr notice, without
  disturbing the pure-JSON-array stdout contract.
- Surface that notice to the user at the `/literature` command layer on both the no-results and
  results-found paths.
- Give each tier a reserved share of `DISCOVER_LIMIT`, with unused quota rolling forward, so no
  tier can be starved or truncated away by an earlier tier.
- Reduce query noise from multi-paragraph task descriptions feeding Tiers 1/2's substring matcher.
- Keep every edit in the source store (`agent-system/extensions/literature/**`), never `.claude/**`.

**Non-Goals**:
- Rearchitecting discovery into "run all tiers, merge and rank afterward" — quotas are the minimal
  change consistent with the existing per-tier-function structure.
- Adding relevance scoring or a ranked ordering to the final output array.
- Changing the discovery record schema consumed by `literature-ingest-online.sh`.
- Fixing sibling defects tracked by other tasks in the same extension (blocked-on-predecessor
  discrimination, mojibake gate, validate directory-path false positives).
- Deploying/regenerating `.claude/` — that is a separate user-driven sync step.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Splitting curl status from body changes the existing `.error`-field parse path | M | M | Strip only the trailing status-code line so `ss_results` remains the exact raw JSON body; keep the `.error` check unchanged and add the HTTP-code branch ahead of it |
| Removing the caller's `2>/dev/null` leaks pre-existing Tier 2 stderr hints into user-visible output | M | H | Capture stderr to a file (the `zotero_rationale` pattern), not to the terminal; grep it for the specific `TIER3_STATUS: FAILED` line and surface only that |
| Per-tier quotas regress "best 10 offline matches" for corpora where Tier 1 legitimately dominates | M | M | Rollover: quota unused by an earlier tier is added to the next tier's budget, and a tier that hits its quota while later tiers find nothing still yields a full result set on re-slice |
| Stricter multi-term matching drops legitimate hits for short, deliberate queries | M | M | Apply the multi-term threshold only when the filtered term count is large (> 5); leave short queries at current single-term-match behavior |
| Edits land in `.claude/` (deploy artifact) and are silently wiped | H | L | Every phase's file list names `agent-system/extensions/literature/**` explicitly; Phase 5 greps the diff to confirm no `.claude/**` paths were touched |
| Three phases touch the same file (`literature-discover.sh`) and conflict | M | M | Phases 1 -> 2 -> 3 are strictly sequential on that file; only Phase 4 (a different file) runs parallel |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Tier 3 failure visibility inside literature-discover.sh [NOT STARTED]

**Goal**: A Tier 3 HTTP failure (429, 5xx), curl failure, or API error body emits one
machine-parseable `TIER3_STATUS: FAILED ...` line on the script's own stderr instead of a silent
`return 0`, with the JSON-array stdout contract untouched.

**Tasks**:
- [ ] In `tier3_search()`, change the Semantic Scholar call to capture the HTTP status alongside
      the body (`curl -s -w '\n%{http_code}' --max-time 15 "$ss_url"`), splitting `http_code`
      (last line) from `body` (everything before it) so the body handed to downstream `jq` is
      byte-identical to today's `ss_results`.
- [ ] Replace the three silent `return 0` exits with an emitting helper: curl exit != 0 ->
      `TIER3_STATUS: FAILED reason=curl_exit http_code=n/a (Semantic Scholar unreachable or timed out)`;
      non-200 -> `TIER3_STATUS: FAILED reason=http http_code=429 (Semantic Scholar rate-limited or unreachable)`;
      non-empty `.error` body -> `TIER3_STATUS: FAILED reason=api_error http_code=200 (<error text>)`.
      All go to stderr; each still returns 0 (Tier 3 remains non-fatal).
- [ ] Emit nothing on the success path (a genuine 200 with zero results stays silent — absence of
      the line means "Tier 3 ran and found nothing").
- [ ] Change the tier-dispatch line from `tier3_search 2>/dev/null || true` to
      `tier3_search || true` so the notice actually reaches the script's stderr.
- [ ] Add a short header comment in `tier3_search()` documenting the `TIER3_STATUS:` stderr
      contract and naming `commands/literature.md` as its consumer, mirroring how
      `zotero-export-status.sh` documents its directive/rationale split.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three silent-failure exit points in
`tier3_search()` (curl exit, empty/non-200 response, `.error` body) and one `2>/dev/null` on the
Tier 3 dispatch line. Confirm at implementation time by reading `tier3_search()` in full and
grepping the tier-dispatch block for `2>/dev/null`; if more or fewer exit points exist, cover all
of them and record the actual count in the phase notes rather than matching this estimate.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - `tier3_search()` curl
  status/body split, three stderr notices, tier-dispatch `2>/dev/null` removal, contract comment.

**Verification**:
- `bash -n agent-system/extensions/literature/scripts/literature-discover.sh` passes.
- Force-fail run: point the Semantic Scholar URL at an unroutable host (or run with network
  disabled) and confirm stderr contains exactly one `TIER3_STATUS: FAILED` line while stdout is
  still a valid JSON array (`| jq type` -> `"array"`).
- Normal run: confirm no `TIER3_STATUS:` line appears when Tier 3 returns 200.

---

### Phase 2: Reserved per-tier quotas with rollover [NOT STARTED]

**Goal**: Each tier gets a reserved share of `DISCOVER_LIMIT`; unused quota rolls forward to later
tiers; the final `jq '.[0:$limit]'` becomes a safety net rather than the selection mechanism.

**Tasks**:
- [ ] Before the tier-dispatch block, compute an even-with-remainder three-way split of
      `DISCOVER_LIMIT` into `TIER1_QUOTA`, `TIER2_QUOTA`, `TIER3_QUOTA` (e.g.
      `TIER1_QUOTA=$(( (DISCOVER_LIMIT + 2) / 3 ))`, `TIER2_QUOTA=$(( (DISCOVER_LIMIT + 1) / 3 ))`,
      `TIER3_QUOTA=$(( DISCOVER_LIMIT - TIER1_QUOTA - TIER2_QUOTA ))`), asserting the three sum to
      `DISCOVER_LIMIT`.
- [ ] Change `tier1_search()`'s break condition from `count >= DISCOVER_LIMIT` to
      `count >= TIER1_QUOTA`; keep the local counter.
- [ ] After Tier 1 runs, roll its shortfall forward: `TIER2_QUOTA=$(( TIER2_QUOTA + TIER1_QUOTA - <tier1 actual> ))`,
      deriving `<tier1 actual>` from the shared `RESULTS` length (`jq 'length'`) rather than from a
      function-local variable, so the rollover works regardless of dedup skips.
- [ ] Change `tier2_search()`'s break condition to `count >= TIER2_QUOTA`, and pass
      `--limit="$TIER2_QUOTA"` (not `DISCOVER_LIMIT`) to `zotero-search.sh` so the upstream query
      is not needlessly wide.
- [ ] After Tier 2 runs, roll its shortfall into `TIER3_QUOTA` the same way.
- [ ] In `tier3_search()`, replace the `current_count >= DISCOVER_LIMIT` early-return and the
      `remaining = DISCOVER_LIMIT - current_count` computation with the rolled-forward
      `TIER3_QUOTA`, so Tier 3's budget is its own share plus any unused earlier share — not
      whatever Tier 1 happened to leave. Keep the early-return when `TIER3_QUOTA` is 0 (it is then
      a genuine "no budget" case, and it MUST NOT emit a `TIER3_STATUS: FAILED` line — a skipped
      Tier 3 is not a failed Tier 3).
- [ ] Leave the final `echo "$RESULTS" | jq --argjson limit "$DISCOVER_LIMIT" '.[0:$limit]'` in
      place as a safety net, with a comment noting quotas make it non-binding by construction.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly three break/early-return conditions gate tier
output (`tier1_search`, `tier2_search`, `tier3_search`) and that `RESULTS` length is a faithful
proxy for per-tier actual counts. Confirm at implementation time by grepping the script for
`DISCOVER_LIMIT` and enumerating every occurrence; each must be classified as quota-derived or
deliberately left as the global cap, with the classification recorded in the phase notes.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - quota computation,
  per-tier break conditions, rollover between tiers, Tier 3 budget source, final-slice comment.

**Verification**:
- `bash -n` passes.
- Regression scenario from the research report: `--task N` query at default `DISCOVER_LIMIT=10`
  against a Zotero library containing Jonsson & Tarski 1951/1952 — both titles appear in the
  output without raising `DISCOVER_LIMIT` to 60.
- `jq '[.[].tier] | group_by(.) | map({tier: .[0], n: length})'` over the output shows more than
  one tier represented when more than one tier has matches.
- Degenerate-corpus check: with an empty/missing `LITERATURE_DIR/index.json` (Tier 1 finds 0),
  Tier 2/3 still fill up to `DISCOVER_LIMIT` — rollover wastes no slots.
- Total output length never exceeds `DISCOVER_LIMIT`.

---

### Phase 3: Query-construction noise reduction [NOT STARTED]

**Goal**: Stop feeding an entire multi-paragraph task description into Tiers 1/2's unranked
substring matcher, so one incidental shared word can no longer surface an unrelated paper.

**Tasks**:
- [ ] In the `--task N` resolution block, keep `task_title` and `task_description` as separate
      variables instead of concatenating them into one `task_terms` string.
- [ ] Filter title and description independently through `filter_terms()`; treat title-derived
      terms as primary (always included) and description-derived terms as supplementary.
- [ ] Cap the supplementary set: take description terms from the first sentence (or first N words,
      N configurable via an env var with a documented default) rather than the whole field.
- [ ] Add a match-strength threshold in `tier1_search()` (and the equivalent path in
      `tier2_search()`): count how many distinct filtered terms hit rather than accepting on the
      first, and require >= 2 distinct hits — but ONLY when the filtered term count is large
      (> 5). At or below that count, preserve today's single-term-match behavior exactly.
- [ ] Leave the string handed to Tier 3's `query_string` on the looser/wider side (Semantic Scholar
      does its own relevance ranking and tolerates a longer free-text query), documenting that
      asymmetry in a comment.
- [ ] Update `--task` usage/help text if it describes query construction.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that Tiers 1 and 2 are the only consumers of
`FILTERED_TERMS` needing the threshold and that `term_matches()` has exactly one accept-on-first-hit
call site per tier. Confirm at implementation time by grepping for `FILTERED_TERMS` and
`term_matches` across the script and enumerating every call site before editing.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - task-term resolution,
  title/description separation, description-term cap, match-strength threshold, Tier 3 query
  asymmetry comment.

**Verification**:
- `bash -n` passes.
- Run `--task 70` (whose own description is the worked noise example named in the research report)
  and confirm the result set no longer contains hits justified by a single incidental generic word.
- Short-query regression: a 2-3 word `"query"` invocation returns the same results as before the
  change (threshold must not engage below the term-count trigger).
- Confirm `FILTERED_TERMS` is still non-empty for a title-only task (the existing "no meaningful
  search terms" error path must not start firing on tasks that previously worked).

---

### Phase 4: Caller-level Tier 3 notice in commands/literature.md [NOT STARTED]

**Goal**: `/literature` discover mode captures the discover script's stderr instead of discarding
it, and surfaces a visible incompleteness notice whenever `TIER3_STATUS: FAILED` is present.

**Tasks**:
- [ ] In step 1 of discover mode, replace the `2>/dev/null` on all three `"$DISCOVER_SCRIPT" ...`
      invocations with `2>/tmp/discover-rationale.txt`, then
      `discover_rationale=$(cat /tmp/discover-rationale.txt)` — the same capture pattern the file
      already uses a few sections above for `zotero_directive`/`zotero_rationale`.
- [ ] Add a branch after step 1: if `discover_rationale` contains `TIER3_STATUS: FAILED`, set a
      `tier3_failed` flag and extract the `http_code=` value for the message.
- [ ] Surface the notice on the no-results path (step 2): append
      "Online search (Tier 3) failed: rate-limited or unreachable (http_code={code}) — this run is
      not evidence that nothing exists online. Retry later before concluding the search was
      exhaustive." to the existing "No sources found" block.
- [ ] Surface the notice on the results-found path (step 3): prepend/append the same warning to the
      `AskUserQuestion` presentation so a partial result set is never read as complete.
- [ ] Rewrite the step-0 closing paragraph that declares the main call's `2>/dev/null` an
      "intentionally out-of-scope follow-up" — that follow-up is now done; the paragraph must
      describe the new capture instead of promising a deferred one.
- [ ] Check the error-handling section near the end of the file (the `literature-discover.sh not
      found` / exit-1 / exit-2 entries) and add a Tier 3 partial-failure row so the behavior is
      documented where callers look for it.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three `2>/dev/null` invocation sites in discover
mode step 1 and one deferred-scope paragraph in step 0. Confirm at implementation time with
`grep -n '2>/dev/null' agent-system/extensions/literature/commands/literature.md` and by reading
step 0's closing paragraph; if other `2>/dev/null` occurrences exist elsewhere in the file, leave
them alone unless they are on a `literature-discover.sh` call, and record the enumeration in the
phase notes.

**Files to modify**:
- `agent-system/extensions/literature/commands/literature.md` - step 1 stderr capture, Tier 3
  failure branch, step 2 and step 3 notices, step 0 deferred-scope paragraph rewrite, error-handling
  section entry.

**Verification**:
- Grep confirms no `2>/dev/null` remains on any `"$DISCOVER_SCRIPT"` invocation.
- Grep confirms the "intentionally out-of-scope follow-up" phrasing is gone.
- Walk the documented flow by hand against a forced Tier 3 failure (Phase 1's force-fail setup) and
  confirm the notice text is reachable on both the zero-results and non-zero-results paths.

---

### Phase 5: Cross-file consistency, docs, and regression verification [NOT STARTED]

**Goal**: The new quota and notice behavior is documented where it is described elsewhere, no
sibling caller was left inconsistent, and the full regression scenario passes end to end.

**Tasks**:
- [ ] Grep the extension for other `literature-discover.sh` invocation sites and descriptions
      (`README.md` three-tier pipeline section, `context/project/literature/patterns/literature-command-modes.md`,
      `context/project/literature/patterns/adhoc-navigation-directive.md`'s "Search online to
      ingest" step) and update any that describe the old first-tier-wins budget or claim Tier 3
      failures are silent/non-surfaced.
- [ ] Confirm `literature-ingest-online.sh`'s documented input schema (one element of the discover
      output array) is unaffected — the record shape must be unchanged by this task.
- [ ] Run the full regression scenario end to end: `--task N` at default `DISCOVER_LIMIT`, with a
      populated Zotero export, verifying multi-tier representation, the Jonsson & Tarski titles,
      and stdout still parsing as a JSON array.
- [ ] Run the Tier 3 forced-failure scenario end to end and confirm the notice propagates from
      script stderr through the command layer.
- [ ] Confirm the boundary rule: `git diff --stat` shows changes only under
      `agent-system/extensions/literature/**` and `specs/**` — zero `.claude/**` paths.
- [ ] Run `bash -n` on every modified shell script and the extension's existing
      `scripts/test-lit-pipeline.sh` smoke script if it covers discovery.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts three doc/caller sites needing updates (README three-tier
section, literature-command-modes.md, adhoc-navigation-directive.md). Confirm at implementation
time with `grep -rn 'literature-discover' agent-system/extensions/literature --include=*.md` and
update every site whose description is now false, not just these three.

**Files to modify**:
- `agent-system/extensions/literature/README.md` - three-tier pipeline description (if it states
  budget or failure behavior).
- `agent-system/extensions/literature/context/project/literature/patterns/literature-command-modes.md` -
  discovery-tier description.
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` -
  "Search online to ingest" step, if it assumes silent Tier 3.

**Verification**:
- Regression scenario passes: both Jonsson & Tarski titles present at `DISCOVER_LIMIT=10`, multiple
  tiers represented.
- Forced Tier 3 failure produces a visible user-facing notice.
- `git diff --name-only` contains no `.claude/` path.
- `bash -n` clean on all modified scripts.

## Testing & Validation

- [ ] `bash -n agent-system/extensions/literature/scripts/literature-discover.sh` passes after every phase.
- [ ] Script stdout remains a valid JSON array in all paths (`| jq type` -> `"array"`), including
      the forced-Tier-3-failure path.
- [ ] Discovery record schema (fields consumed by `literature-ingest-online.sh`) is unchanged.
- [ ] `TIER3_STATUS: FAILED` appears on stderr exactly once per failed Tier 3 run, and never on a
      successful or budget-skipped run.
- [ ] Output length never exceeds `DISCOVER_LIMIT`; multiple tiers are represented whenever
      multiple tiers have matches.
- [ ] Rollover check: a tier finding fewer than its quota does not waste slots.
- [ ] Short-query behavior (<= 5 filtered terms) is byte-identical to pre-change behavior.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-discover.sh` (modified: Tier 3 status
  reporting, per-tier quotas with rollover, query-construction noise reduction).
- `agent-system/extensions/literature/commands/literature.md` (modified: stderr capture, Tier 3
  failure notice on both result paths, deferred-scope paragraph rewritten).
- Doc/caller updates under `agent-system/extensions/literature/` (README, literature-command-modes,
  adhoc-navigation-directive) as confirmed by Phase 5's grep.
- `specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/summaries/01_*-summary.md`
  (implementation summary).

## Rollback/Contingency

All changes are confined to two primary files plus documentation, with per-substep commits, so
`git revert` of the task's phase commits restores prior behavior exactly. If the quota change
proves too aggressive for a specific corpus, the split constants are the single point of tuning
(setting `TIER1_QUOTA=DISCOVER_LIMIT` with zero rollover reproduces today's behavior without
reverting the Tier 3 visibility work). The Tier 3 stderr notice is additive and independently
revertable: reinstating `2>/dev/null` on the dispatch line and at the caller restores the old
silent behavior without touching the quota logic.
