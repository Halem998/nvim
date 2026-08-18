# Research Report: Task #70

**Task**: 70 - Fix literature-discover.sh tier starvation and silent Tier 3 failure
**Started**: 2026-08-18T18:38:00Z
**Completed**: 2026-08-18T19:05:00Z
**Effort**: 3-6 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/literature/scripts/literature-discover.sh, commands/literature.md, scripts/zotero-export-status.sh), git history
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect 1 (silent Tier 3 failure)** is confirmed at two layers, not one: `literature-discover.sh:616` discards Tier 3's own stderr (`tier3_search 2>/dev/null || true`), AND `commands/literature.md:372/375/378` discards the *whole script's* stderr (`2>/dev/null`) when invoking `literature-discover.sh`. Fixing only the inner layer is insufficient — the caller-level redirect must change too. The command file itself already flags this as deferred scope at `literature.md:362-365` ("this offer... does NOT modify the existing `2>/dev/null` capture on the main call — that remains a separate, intentionally out-of-scope follow-up"), which is precisely this task.
- **Defect 2 (Tier 1 starves Tiers 2/3)** is confirmed and is actually a truncation bug more than a starvation bug: `tier2_search()` runs unconditionally and caps itself at `DISCOVER_LIMIT` using its *own* local `count`, never checking how many slots Tier 1 already consumed in the shared `RESULTS` array. So with `DISCOVER_LIMIT=10` and Tier 1 alone finding 10+ matches, `RESULTS` can grow to 20 (10 Tier-1 + up to 10 Tier-2), but the final `jq '.[0:$limit]'` (`literature-discover.sh:629`) keeps only the *first* 10 elements in insertion order — all Tier 1. Tier 2's real hits (Jonsson & Tarski) were computed and then silently thrown away by the tail truncation. Tier 3 at least has a *guard* (`current_count >= DISCOVER_LIMIT` early-return) but the guard checks the same unfair, already-exhausted-by-Tier-1 total.
- **Query-construction noise** is confirmed: `SEARCH_TERMS` is built by concatenating the full task `description` + `title` verbatim (`literature-discover.sh:124-127`), then filtered only against a tiny 18-word stop-list (`STOP_WORDS` at line 184) with a 3-character minimum. Domain-generic words survive this filter untouched, and `term_matches()` does a single-term case-insensitive substring OR-match with no relevance ranking — one incidental shared word (e.g. "temporal") is sufficient to surface an unrelated paper as a top hit.
- Recommended fix direction for each defect is below (Findings/Recommendations); this is a research report, not an implementation — concrete diffs belong to the `/plan` phase.

## Context & Scope

Task 70 targets two files: `agent-system/extensions/literature/scripts/literature-discover.sh` (630 lines, three-tier discovery pipeline) and `agent-system/extensions/literature/commands/literature.md` (the `/literature` command driving Mode A "discover"). Per `.claude/rules/source-store-deploy-boundary.md`, all fixes must land in `agent-system/extensions/literature/**` (the source store), never hand-authored into `.claude/**` (the disposable deploy artifact). Sibling tasks 68 (blocked-on-predecessor discrimination), 69 (mojibake quality gate), and 71 (validate directory-path false positives) are unrelated defects in the same extension — no overlap with this task's scope.

## Findings

### Codebase Patterns

**Established "directive + rationale" idiom** (the reference pattern named in the delegation): `zotero-export-status.sh` is a *dedicated classifier script*, separate from the data-producing script it gates. It:
- Prints exactly one token to stdout (e.g. `ZOTERO_EXPORT_STALE`), nothing else on stdout.
- Writes human-readable rationale to stderr on every branch (`zotero-export-status.sh:170,175,180,...`).
- Is invoked by the caller with stderr captured to a file/variable, never `2>/dev/null` (`literature.md:143-144`: `zotero_directive=$("$STATUS_SCRIPT" ... 2>/tmp/zotero-status-rationale.txt); zotero_rationale=$(cat /tmp/zotero-status-rationale.txt)`).
- Never calls `AskUserQuestion` itself — the caller branches on the token and decides whether to prompt interactively or take a logged autonomous default (`orchestrator_mode`).

`literature-discover.sh` does not follow this shape internally for Tier 3: `tier3_search()` treats a non-zero curl exit, empty response, AND an API error body all the same way — `return 0` (silent, indistinguishable from "no results"), at lines 484, 491-493. There is no directive token and the failure reason is lost, compounded by the caller's blanket `2>/dev/null` (`literature.md:372/375/378`) which would discard any stderr notice even if one were added inline.

**Tier interaction / truncation mechanics** (`literature-discover.sh:340,453,466,629`):
- `tier1_search()` breaks its own loop at `count >= DISCOVER_LIMIT` (local `count`, starts at 0) — can singlehandedly fill all of `DISCOVER_LIMIT`.
- `tier2_search()` breaks its own loop at `count >= DISCOVER_LIMIT` — **also its own local `count`, starting at 0 again**, with no awareness of how many slots Tier 1 already used in the shared `RESULTS`. This is the actual truncation bug: Tier 2 does real work and appends real entries, which then get discarded by the final slice.
- `tier3_search()` is the only tier that checks the shared total (`current_count=$(echo "$RESULTS" | jq 'length')`) before running, and computes `remaining = DISCOVER_LIMIT - current_count` for its own cap — this is the right shape, just applied unfairly (Tier 1 already spent the whole budget by the time Tier 3 checks).
- Final line: `echo "$RESULTS" | jq --argjson limit "$DISCOVER_LIMIT" '.[0:$limit]'` — a plain head-of-array slice with no per-tier fairness, so insertion order (Tier 1, then Tier 2, then Tier 3) determines who survives.

**Query construction** (`literature-discover.sh:106-147, 184-216`):
- `--task N` mode concatenates `description` then `title` into one string (`task_terms="$task_description"; task_terms="$task_terms $task_title"`), with no length cap, no distinction between title (curated, short, high-signal) and description (free-form prose, can be several paragraphs per this task's own description field, which is itself ~230 words).
- `filter_terms()` only drops words shorter than 3 characters and an 18-word stop-list (`a an the in on at of to and or for by with from is are was were`). Nothing removes generic-but-long domain filler ("temporal", "operators", "axiomatization" itself, etc.) that happens to overlap with unrelated corpus entries.
- `term_matches()` (line 173) does a single case-insensitive substring check; `tier1_search()`'s match loop (line 296-302) sets `matched=true` on the *first* term that hits — there is no scoring, so one coincidental shared word ranks a paper the same as ten shared words.

### External Resources

Not applicable — this is a self-contained shell-pipeline defect, not a library/API integration question. (Semantic Scholar's public search API is known to rate-limit unauthenticated traffic around 100 requests / 5 min and returns HTTP 429 on excess, consistent with the reported symptom; no further external research needed.)

### Recommendations

**Defect 1 fix direction** — make Tier 3 failure visible without breaking the pure-JSON-array stdout contract:
1. In `tier3_search()`, split the HTTP status from the body (e.g. `curl -s -w '\n%{http_code}' ...`, then `body`/`http_code` via `sed`/`tail`) so a 429/5xx/timeout is distinguishable from a genuine empty-results 200.
2. On non-200 (or curl exit != 0), write a single machine-parseable line to stderr, e.g. `TIER3_STATUS: FAILED http_code=429 (Semantic Scholar rate-limited or unreachable)`, instead of silently `return 0`. Keep stdout untouched (still only the JSON array) — this preserves every existing consumer of `literature-discover.sh`'s stdout contract.
3. Remove (or narrow) the `2>/dev/null` on the `tier3_search` invocation at `literature-discover.sh:616` so this line actually reaches the script's own stderr.
4. **Required companion change** in `commands/literature.md`'s step 1 (lines 367-381): replace the blanket `2>/dev/null` on the three `"$DISCOVER_SCRIPT" ...` invocations with the same capture-to-file pattern already used for `zotero_directive`/`zotero_rationale` a few lines above in the same file (`... 2>/tmp/discover-rationale.txt`, then `discover_rationale=$(cat /tmp/discover-rationale.txt)`). Grep that rationale for the `TIER3_STATUS: FAILED` line and, when present, surface a visible notice ("Online search (Tier 3) failed: rate-limited or unreachable — results may be incomplete, not exhaustive") both on the no-results path (step 2) and appended to the results-found path (step 3), so a rate-limited run is never confused with "nothing exists online". Without this companion edit, any inner-script stderr fix is inert — the caller already throws it away today, and the file's own comment at line 362-365 flags this exact gap as deferred.

**Defect 2 fix direction** — reserved per-tier quotas instead of first-tier-wins:
1. Before running the tiers, compute a quota per tier that sums to `DISCOVER_LIMIT` (e.g. `TIER1_QUOTA=$(( (DISCOVER_LIMIT + 2) / 3 ))`, `TIER2_QUOTA=$(( (DISCOVER_LIMIT + 1) / 3 ))`, `TIER3_QUOTA=$(( DISCOVER_LIMIT - TIER1_QUOTA - TIER2_QUOTA ))`, or equivalent even-with-remainder split).
2. Change `tier1_search()` and `tier2_search()`'s break conditions from `count >= DISCOVER_LIMIT` to `count >= TIER1_QUOTA` / `count >= TIER2_QUOTA` respectively (each still using its own local counter, just against a smaller cap).
3. Add a rollover mechanism so quota unused by an earlier tier becomes available to later tiers — otherwise a corpus with only 2 Tier-1 matches wastes 8 potential slots instead of letting Tier 2/3 fill them. Concretely: track `remaining_after_tier1 = TIER1_QUOTA - tier1_actual_count` and add it to `TIER2_QUOTA` before Tier 2 runs (and same pattern from Tier 2's shortfall into Tier 3, which already receives a `remaining`-style budget via `current_count`/`DISCOVER_LIMIT` — that part just needs the *quota*, not the raw `DISCOVER_LIMIT`, plugged in).
4. With this change, `RESULTS` should never meaningfully exceed `DISCOVER_LIMIT` by construction, so the final `jq '.[0:$limit]'` slice becomes a safety net rather than the actual (unfair) selection mechanism.
5. Regression check to carry into `/plan`: re-run the reported failing scenario (task-scoped `--task N` query, default `DISCOVER_LIMIT=10`, Zotero library containing Jonsson & Tarski 1951/1952) and confirm both titles now appear without needing `DISCOVER_LIMIT=60`.

**Query-construction fix direction** — reduce noise, prioritize signal:
1. Keep `title` and `description` as separate variables through to `filter_terms()` rather than concatenating first; treat title terms as always-included ("primary") and description terms as supplementary.
2. Cap the number of description-derived terms actually used (e.g. first N words, or first sentence only) rather than passing an entire multi-paragraph description into the matcher — this task's own description field is a concrete worked example of the noise source (~230 words, several unrelated technical terms).
3. Consider widening `STOP_WORDS` or, more robustly, requiring `tier1_search()`'s match to count how many distinct filtered terms hit (not just "≥1") and only accept matches above a small threshold (e.g. ≥2 terms, or require a title/keyword match rather than any substring hit) when the term list is long — this directly prevents a single incidental word like "temporal" from qualifying an unrelated CTL/Büchi paper.
4. Tier 3 (Semantic Scholar) is a genuine full-text search API with its own relevance ranking, so it is more tolerant of a longer free-text query than the naive substring-OR match Tiers 1/2 use locally — the noise-reduction effort should focus on what feeds Tiers 1/2's `term_matches()`, and can be looser for the string handed to Tier 3's `query_string`.

## Decisions

- Confirmed both defects and the query-noise issue as real, via direct code reading (not simulation) — no need for further reproduction steps before planning.
- Confirmed the fix for Defect 1 requires touching *both* files (`literature-discover.sh` for the inner stderr, `commands/literature.md` for the caller-level `2>/dev/null` removal) — a single-file fix is insufficient and was already anticipated as future scope by the code's own comments.
- Scoped Defect 2's fix as "reserved quotas with rollover" rather than a more invasive rearchitecture (e.g. running all three tiers unconditionally and merging/ranking afterward) — quotas are the minimal change consistent with the existing per-tier-function structure and preserve tier1_search's offline-first performance characteristic (still short-circuits when possible).

## Risks & Mitigations

- **Risk**: Splitting curl's status code from body in `tier3_search()` could subtly change existing error-handling paths (e.g. the `.error` field check at line 490-493 assumes `ss_results` is the raw JSON body). **Mitigation**: keep body extraction exact (strip only the trailing status-code line) so downstream `jq` parsing of `ss_results` is unaffected.
- **Risk**: Per-tier quotas could regress cases where a user genuinely wants "the best 10 offline matches" and doesn't care about Tier 2/3 diversity. **Mitigation**: quotas only bind when a tier is at risk of *exceeding* its share — rollover ensures a tier that finds fewer than its quota doesn't waste capacity, and total output is still capped at `DISCOVER_LIMIT`.
- **Risk**: Tightening the term-match threshold for Tiers 1/2 could cause legitimate matches to be dropped for tasks with very few filtered terms (e.g. a 2-word query). **Mitigation**: only apply a stricter multi-term threshold when the filtered term count is large (e.g. > 5), leaving short/deliberate queries at the current single-term-match behavior.

## Context Extension Recommendations

- **Topic**: Multi-tier aggregation fairness in shell pipelines.
- **Gap**: No existing context file documents the "reserved quota + rollover" pattern for aggregating results across independently-capped sources before a final truncation.
- **Recommendation**: If this pattern gets applied more than once in this extension, consider a short pattern note under `context/project/literature/patterns/` documenting it, referencing this fix as the origin case.

## Appendix

- Files read in full: `literature-discover.sh` (630 lines), `zotero-export-status.sh` (213 lines).
- Files read in part: `commands/literature.md` (lines 1-480 of the discover-mode workflow).
- Confirmed via `git log`/`state.json`/`TODO.md` that sibling tasks 68/69/71 (created in the same batch commit `eec2f8503`) target unrelated defects with no scope overlap.
- No web search was needed; this is a self-contained codebase defect.
