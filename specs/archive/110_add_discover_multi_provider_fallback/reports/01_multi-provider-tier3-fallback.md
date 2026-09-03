# Research Report: Task #110

**Task**: 110 - Stop Tier 3 online discovery from being a single point of failure
**Started**: 2026-09-01
**Completed**: 2026-09-01
**Effort**: Medium (one script, ~150-250 new/changed lines; no schema migration)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/literature/scripts/`), live API probes (OpenAlex, Crossref), WebSearch/WebFetch (OpenAlex auth-policy verification)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `literature-discover.sh`'s Tier 3 has exactly one provider (Semantic Scholar, `literature-discover.sh:537`) and no retry/backoff of its own — the 20+-attempt/75s-backoff behavior observed in the originating session was an *external* (agent-level) retry loop around the whole script, not code inside it. A fix must work within a single invocation.
- **Fix 1** (API key) is a small, additive, low-risk change: read `S2_API_KEY`, send it as `x-api-key` only when set.
- **Fix 2** (fallback providers) is best implemented as: extract the existing per-record normalization/dedup/status logic out of the inline Semantic Scholar loop into a shared helper, then add `OpenAlex` and `Crossref` as ordered fallback providers that reuse that helper — this is what makes "same schema" true by construction rather than by three independently-maintained code paths.
- **Hard constraint found and worth flagging explicitly**: the doc_id derivation contract has exactly four branches (doi-slug, `arxiv_<id>`, `ss_<paperId>`, `unknown_<slug>`). A new provider must **never** mint a fifth branch (no `oa_<id>`/`cr_<id>` prefix) — OpenAlex/Crossref records fall through to `doi-slug` (the common case) or straight to `unknown_<slug>` (no paperId analog exists for them), skipping `ss_<paperId>` entirely.
- **TIER3_STATUS semantics generalize cleanly**: track per-provider success/fail; emit the existing `TIER3_STATUS: FAILED` line (unchanged shape, so `commands/literature.md`'s `grep -q 'TIER3_STATUS: FAILED'` + `grep -o 'http_code=[^ ]*'` consumer keeps working with zero changes) only when **every** attempted provider failed. If any provider returns a real (possibly zero-result) response, Tier 3 counts as "ran," exactly like today.
- OpenAlex live-tested successfully with **no key and no `mailto`** during this research pass (2026-09-01), despite a secondary source (a Google Groups thread) claiming a Feb-13 key mandate; the canonical `openalex-docs` repo still documents key-optional access with generous anonymous limits. Recommend treating a key as optional/defensive (same additive pattern as `S2_API_KEY`), not required.

## Context & Scope

Task 110 asks for two independent, additive fixes to `agent-system/extensions/literature/scripts/literature-discover.sh`'s Tier 3 (`tier3_search()`, lines ~516-679):

1. Honor an optional `S2_API_KEY` for higher Semantic Scholar rate limits.
2. Fall through to at least one alternate provider when Semantic Scholar fails (429/non-200/unparseable), preserving the exact downstream record schema consumed by `literature-ingest-online.sh` and the `TIER3_STATUS` stderr contract consumed by `commands/literature.md`.

The source store is `agent-system/extensions/literature/scripts/literature-discover.sh` (732 lines) — the `.claude/` deploy copy is confirmed byte-identical (per task delegation) and is not the edit target.

## Findings

### Codebase Patterns

**Current Tier 3 shape** (`literature-discover.sh:516-679`):
- Single provider: Semantic Scholar graph search (`GET /graph/v1/paper/search`), no auth header, `curl -s -w '\n%{http_code}' --max-time 15`.
- On `curl_exit != 0`, `http_code != 200`, empty body, or a `.error` field in the JSON body: writes one `TIER3_STATUS: FAILED reason=<curl_exit|http|api_error> http_code=<code|n/a> (<text>)` line to *its own* stderr and returns 0 (non-fatal). No line at all is written for a genuine 200-with-zero-matches, and none for `TIER3_QUOTA <= 0` (a skip, not a failure) — this absence-means-success/skip distinction is exactly what a multi-provider version must preserve.
- Per-paper normalization (inline in the `while` loop, lines 573-678): builds `authors_arr` via jq, derives `doc_id` via a strict priority chain — `doi` (present) -> slug it (`tr '/' '_' | tr '.' '_'`); else `arxiv_id` (present) -> `arxiv_<id_with_dots_as_underscores>`; else `paper_id` (Semantic Scholar's own `paperId`) -> `ss_<paperId>`; else a title-derived `unknown_<slug>`. Then derives `status`/`pdf_url`: `openAccessPdf.url` present -> `open_access`; else `arxiv_id` present -> `open_access` with a synthesized `https://arxiv.org/pdf/<id>` URL; else if `doi` present, a **synchronous Unpaywall lookup** (`api.unpaywall.org/v2/<doi>?email=<USER_EMAIL>`) for `best_oa_location.url`; otherwise `status="paywall"`. Finally emits the record via the shared `append_result`/`add_seen` helpers (title+doc_id dedup, shared across all three tiers).
- Per-tier quota with rollover is computed *outside* `tier3_search()` (lines 693-716) using the shared `RESULTS` array length; `tier3_search()` only needs to respect `TIER3_QUOTA`/its local `remaining` counter and is otherwise quota-agnostic. This means adding providers inside `tier3_search()` does not require touching the quota-rollover math at all.
- `literature-term-match.sh` supplies `FILTERED_TERMS`/`urlencode()`-adjacent helpers used to build the query string; `urlencode()` itself is a local function in `literature-discover.sh` (Python one-liner) and is reusable as-is for OpenAlex/Crossref query params.
- No existing retry/backoff logic anywhere in `literature-discover.sh`. No existing curl-mocking test convention in `scripts/tests/*.sh` or `test-lit-pipeline.sh` — a fallback test will need a stub `curl` shell function/script inserted earlier in `PATH`, matched on URL substring, since the script calls bare `curl` (not `command curl`).

**Consumer contract** (`literature-ingest-online.sh:20-95`, the authoritative schema):
```
title: string (required)
authors: string[] (required, may be empty)
year: integer|null (required key)
doc_id: string (required) — Tier 2: Zotero citation_key; Tier 3: doi-slug | arxiv_<id> | ss_<paperId> | unknown_<slug>
status: "in_zotero_no_pdf" | "open_access" | "paywall"   (only these three reach this bridge)
tier: 2 | 3
doi: string|null        (tier 3 only)
arxiv_id: string|null   (tier 3 only)
pdf_url: string|null    (tier 3 only)
```
Note the explicit warning already in that header: `arxiv_id` set + `status=="open_access"` is how an arXiv hit is represented — there is no literal `"arxiv"` status. This is unaffected by adding providers as long as every provider funnels through the same status-derivation logic.

**`commands/literature.md`'s TIER3_STATUS consumer** (`commands/literature.md:368-395`): captures `literature-discover.sh`'s stderr (no longer discarded), and does exactly two things with it: `grep -q 'TIER3_STATUS: FAILED'` to set a boolean, and `grep -o 'http_code=[^ ]*'` to extract one display value. Both operations are tolerant of extra trailing text on the line (the `[^ ]*` capture stops at the first space after `http_code=`), so a richer, multi-provider FAILED line is safe as long as (a) the literal substring `TIER3_STATUS: FAILED` appears, and (b) `http_code=<token-with-no-spaces>` appears somewhere on that same line.

### External Resources

Live-probed both proposed fallback providers during this research pass (2026-09-01, from this repo's network):

- **OpenAlex** (`https://api.openalex.org/works?search=<query>`) — succeeded anonymously, no key, no `mailto`. Response shape confirmed: `results[].title`, `results[].publication_year`, `results[].doi` (note: **prefixed** `https://doi.org/10.xxxx/...`, must be stripped to a bare DOI before reuse in doc_id-slugging or the Unpaywall URL, both of which assume a bare DOI as Semantic Scholar's `externalIds.DOI` already provides), `results[].authorships[].author.display_name`, `results[].open_access.is_oa` / `.oa_url`, `results[].primary_location.pdf_url` (often a more directly-fetchable PDF link than `open_access.oa_url`, which can be a landing page). No native "arxiv_id" field; arXiv-hosted works are identifiable only heuristically (e.g. `primary_location.source.display_name == "arXiv"` + parsing the landing-page URL) — not required for this fix; treat OpenAlex records as DOI-based (`arxiv_id: null`) unless a follow-up wants that enhancement.
  - Rate-limit/auth policy: found conflicting secondary sources. A Google Groups thread claims a Feb-13 mandatory-API-key cutover (409 errors past 100 free credits/day). The canonical `ourresearch/openalex-docs` rate-limits doc (and this session's own successful anonymous call) says a key is *not* required, with generous free limits (100 req/s, 100k credits/day) and `mailto=`/User-Agent as an optional politeness signal only. Given the live test succeeded with zero auth just now, treat the key as optional and defensive: read `OPENALEX_API_KEY` and append `&api_key=` only if set (mirrors `S2_API_KEY`'s additive pattern), and still send `mailto=${USER_EMAIL}` (the same env var `literature-discover.sh` already uses for Unpaywall) for the politeness/consistency benefit documented for both eras of the policy.
- **Crossref** (`https://api.crossref.org/works?query=<query>`) — succeeded anonymously. Response shape confirmed: `message.items[].DOI` (bare, unlike OpenAlex — no prefix stripping needed), `message.items[].title[0]`, `message.items[].author[].given`/`.family`, `message.items[].issued.date-parts[0][0]` for year. No OA/PDF field at all in the base response — a Crossref hit always needs the *same* Unpaywall-by-DOI fallback the existing Semantic Scholar branch already performs for a DOI-only, non-arXiv hit. This makes Crossref strictly the "DOI is authoritative but I still don't know if it's open" tier, i.e. exactly parallel to Semantic Scholar's own DOI branch — good schema fit, no new status logic needed.
  - Crossref's own politeness convention: `mailto=` query param or in `User-Agent`, no key ever required; also confirmed live.
- **arXiv API** (`http://export.arxiv.org/api/query`) — not probed live (task explicitly says choosing a subset is fine). It returns Atom XML rather than JSON, which is a real parser-cost outlier relative to the rest of this script (everything else is `jq` over JSON) — recommend treating it as optional/deferred rather than folding it into this task, since Semantic Scholar and OpenAlex both already surface arXiv-hosted OA content through their existing/near-existing fields.

### Recommendations

**Fix 1 — S2_API_KEY (small, do first):**
```bash
S2_API_KEY="${S2_API_KEY:-}"   # add near existing USER_EMAIL/env-var block, line ~46

# inside the Semantic Scholar branch's curl call:
local curl_args=(-s -w '\n%{http_code}' --max-time 15)
[ -n "$S2_API_KEY" ] && curl_args+=(-H "x-api-key: $S2_API_KEY")
ss_raw=$(curl "${curl_args[@]}" "$ss_url" 2>/dev/null) || curl_exit=$?
```
Document `S2_API_KEY` in the script's header `ENVIRONMENT` block (alongside `LITERATURE_DIR`/`DISCOVER_LIMIT`/`DISCOVER_DESC_WORD_CAP`) and in `README.md`'s Tier 3 description. Unset stays fully anonymous — zero behavior change for existing callers.

**Fix 2 — ordered provider fallback (the substantial change):**

1. **Extract, don't duplicate.** Pull the per-hit normalization body currently inline in the Semantic Scholar `while` loop (doc_id derivation, status/pdf_url derivation including the Unpaywall-by-DOI sub-call, `append_result`/`add_seen`) into one shared function, e.g. `tier3_emit_record(title, authors_json, year, doi, arxiv_id, oa_url_from_provider, paper_id)`, called identically by every provider branch. This is the mechanism that makes "same schema, same doc_id rules" true by construction — a provider branch's only job is to map its own JSON shape onto this function's parameter list; it never re-implements dedup, doc_id, or status logic. This directly satisfies the task's hard constraint and its warning that "a provider that mints doc_ids differently will break dedup and index patching downstream."
   - `paper_id` is passed through only for the Semantic-Scholar branch (feeds the `ss_<paperId>` doc_id case); OpenAlex/Crossref branches pass an empty `paper_id`, so their records fall through the *existing* fourth branch (`unknown_<slug>`) whenever no DOI/arXiv id is present — no fifth doc_id prefix is introduced.
   - Before calling the shared function, an OpenAlex branch must strip any `https://doi.org/` prefix from its `doi` field (Crossref's `DOI` field needs no stripping).
2. **Ordered provider loop**, replacing the single inline Semantic Scholar call:
   ```
   providers=(semantic_scholar openalex crossref)   # S2 first (already-working default,
                                                     # improved by Fix 1); OpenAlex second
                                                     # (broadest coverage + native OA data,
                                                     # no key required); Crossref last (DOI-only,
                                                     # needs the Unpaywall sub-call for OA data,
                                                     # same shape as S2's own DOI branch)
   any_provider_answered=false
   fail_notes=()
   for provider in "${providers[@]}"; do
     [ "$remaining" -le 0 ] && break
     if tier3_try_$provider "$query_string" "$remaining"; then   # emits via tier3_emit_record()
       any_provider_answered=true
       remaining=$(( TIER3_QUOTA - <current tier3 record count> ))
     else
       fail_notes+=("$provider:<reason>=<http_code>")
     fi
   done
   if [ "$any_provider_answered" = false ]; then
     echo "TIER3_STATUS: FAILED reason=all_providers_exhausted http_code=${last_http_code:-n/a} (tried: ${providers[*]}; ${fail_notes[*]})" >&2
   fi
   ```
   Each `tier3_try_<provider>` function returns 0 the moment it gets a real (parseable, non-error) HTTP response — **even if that response has zero matches** — and returns 1 only on curl failure / non-200 / unparseable body / API error field, exactly mirroring today's single-provider FAILED conditions. This is the design choice that generalizes "absence of the line means Tier 3 ran and found nothing" correctly: if Semantic Scholar answers with zero hits, the loop stops there (no wasted calls to OpenAlex/Crossref) and no FAILED line is written — identical to today's behavior when S2 is healthy. The chain only advances on genuine provider failure, not on a thin result — this keeps quota usage and latency close to today's baseline in the common case and reserves the fallback cost for the actual outage scenario the task is about.
   - **Considered and rejected**: continuing to the next provider on a *successful-but-zero-result* answer, to fill unused Tier 3 quota with better recall. Rejected for this task because it would change latency/cost even in the non-degraded case and blur the exact distinction ("ran and found nothing" vs "could not run") the task explicitly asks to keep meaningful — worth a note for whoever plans this, since it's a legitimate but separate enhancement.
3. **Backward-compatible FAILED line.** The aggregate line keeps the literal substring `TIER3_STATUS: FAILED` and an `http_code=<token>` field with no embedded spaces immediately after it, so `commands/literature.md`'s existing `grep -q`/`grep -o 'http_code=[^ ]*'` consumer requires **no changes** — verified by construction against its exact regex.

**Verification plan (matches the task's stated bar):**
- Force the Semantic Scholar branch to see a 429: the cleanest no-network-flakiness way is a `PATH`-shadowing stub `curl` script (no existing convention in this repo's tests, so this establishes one) that inspects its arguments for the target host and returns `429`/canned bodies for `api.semanticscholar.org`, and passes through to real `curl` (or a small canned 200 fixture) for `api.openalex.org`/`api.crossref.org`.
- Confirm the resulting stdout JSON array contains a schema-valid Tier 3 record (`title`, `authors[]`, `year`, `doc_id`, `status` in `{open_access, paywall}`, `tier: 3`, `doi`/`arxiv_id`/`pdf_url` present as keys even when null) sourced from OpenAlex (or Crossall, if OpenAlex is also stubbed to fail) instead of Semantic Scholar.
- Pipe that single record into `literature-ingest-online.sh --record '<json>' --dry-run` and confirm it prints one of the documented directive tokens (most likely `ONLINE_INGEST_NO_PDF` for a `paywall` record, or the dry-run preview path for `open_access`) rather than exiting 64 (usage/malformed-input error) — exit 64 would mean the schema mismatch the task is explicitly guarding against.
- Separately confirm the *all-providers-fail* path: stub all three providers to fail, confirm exactly one `TIER3_STATUS: FAILED reason=all_providers_exhausted ...` line reaches stderr and `commands/literature.md`'s existing grep still fires on it unmodified.

## Decisions

- Recommend two fallback providers (OpenAlex, then Crossref), not three — the task explicitly allows a justified subset, and arXiv's Atom/XML format is a real parsing-cost outlier not offset by much marginal coverage (Semantic Scholar's `externalIds.ArXiv` and OpenAlex's arXiv-hosted OA locations already cover most of that ground).
- Chain to the next provider only on genuine failure (curl error / non-200 / unparseable / API error), never merely on a zero-result 200 — preserves today's latency/cost profile in the non-degraded case and keeps the "ran vs. couldn't run" distinction crisp.
- Both new providers' auth is optional/additive (`OPENALEX_API_KEY` mirroring `S2_API_KEY`), given the live-verified current reality of anonymous access working, while hedging against the (disputed but possible) stricter policy reported in a secondary source.
- No new doc_id prefix branches — OpenAlex/Crossref records use only the existing doi-slug and unknown_<slug> branches of the four-branch contract.

## Risks & Mitigations

- **Risk**: OpenAlex's documented/disputed key requirement changes again mid-flight. **Mitigation**: additive `OPENALEX_API_KEY` env var support now means no code change is needed later if it becomes mandatory — only a config change for callers.
- **Risk**: A shared `tier3_emit_record()` refactor accidentally changes Semantic Scholar's own existing behavior (regression on the currently-working path). **Mitigation**: the verification plan's first bullet should also be run once with *no* stubbing (pure pass-through) to confirm byte-identical output to the pre-refactor script for a known query, before wiring in the new providers.
- **Risk**: Crossref/OpenAlex responses occasionally have multiple works with the same normalized title as an existing Tier 1/2 hit but a different DOI (near-duplicate). **Mitigation**: out of scope for this task — the existing `is_seen_title`/`is_seen_doc_id` dedup is unchanged and already the accepted dedup bar for all three tiers.

## Context Extension Recommendations

- **Topic**: Tier 3 multi-provider fallback design (once implemented).
- **Gap**: No existing context doc under `context/project/literature/domain/` covers Tier 3's internal provider chain the way `sparse-coverage.md` covers coverage-detection or `zotero-integration.md` covers Zotero; a fallback chain with a shared record-normalization contract is exactly the kind of shape that benefits from being documented once rather than re-derived from source on the next touch.
- **Recommendation**: after implementation, add a short `context/project/literature/domain/tier3-provider-fallback.md` documenting the provider order/rationale, the shared `tier3_emit_record()` contract, and the four-branch doc_id rule (explicitly warning against a fifth prefix) — mirroring how `sparse-coverage.md` documents its own env-var/threshold contract today.

## Appendix

- Files read: `agent-system/extensions/literature/scripts/literature-discover.sh` (full, 732 lines), `agent-system/extensions/literature/scripts/literature-ingest-online.sh` (header/contract, lines 1-120), `agent-system/extensions/literature/scripts/literature-term-match.sh` (full), `agent-system/extensions/literature/README.md` (Tier 3 section), `agent-system/extensions/literature/commands/literature.md` (TIER3_STATUS consumer, lines ~355-400), `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` (for the sibling-pattern reference in Context Extension Recommendations).
- Live probes: `curl https://api.openalex.org/works?search=...` and `curl https://api.crossref.org/works?query=...` (both anonymous, both succeeded, 2026-09-01).
- Web sources consulted for OpenAlex auth-policy verification:
  - [openalex-docs rate-limits-and-authentication.md](https://github.com/ourresearch/openalex-docs/blob/main/how-to-use-the-api/rate-limits-and-authentication.md)
  - [OpenAlex users group: API keys required starting Feb 13](https://groups.google.com/g/openalex-users/c/rI1GIAySpVQ)
- Search queries used: "OpenAlex API rate limit mailto polite pool 2026"; grep sweeps for `S2_API_KEY|x-api-key`, `semanticscholar|openalex|crossref|export.arxiv.org`, `TIER3_STATUS`, `backoff|retry`, `curl() |mock_curl|MOCK|httpbin` across `agent-system/extensions/literature/`.
