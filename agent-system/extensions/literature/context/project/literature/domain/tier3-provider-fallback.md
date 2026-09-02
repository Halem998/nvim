# Tier 3 Provider Fallback

`literature-discover.sh`'s Tier 3 (online search) tries an ordered chain of providers —
Semantic Scholar, then OpenAlex, then Crossref — rather than depending on a single provider
that can silently disable the entire online tier when rate-limited.

## Provider Order and Rationale

`tier3_search()` defines the chain as `semantic_scholar openalex crossref`:

1. **Semantic Scholar** — the already-working default, now additionally accepting an optional
   `S2_API_KEY` (sent as an `x-api-key` header) to raise its rate limit. Tried first because it
   is the richest single source: title, authors, year, DOI, arXiv ID, and a native OA PDF URL
   in one response.
2. **OpenAlex** — tried second for breadth plus native OA data, and requires no key: an
   optional `OPENALEX_API_KEY` plus a `mailto=` politeness param are additive only.
3. **Crossref** — tried last. It is DOI-authoritative (Crossref is a DOI registration agency)
   but carries no OA/PDF field at all, so a Crossref hit always falls through to the existing
   Unpaywall-by-DOI lookup for its `pdf_url`.

## The `tier3_emit_record()` Contract

Every provider branch maps its own response shape onto one shared function,
`tier3_emit_record()`, rather than deriving a doc_id, status, or pdf_url itself. This is what
makes the three providers' output schema-identical by construction instead of by three parallel
reimplementations that could drift.

**Parameters, in order**: `title`, `authors_json` (a JSON array string, e.g. `["A. Author"]` or
`[]`), `year`, `doi`, `arxiv_id`, `oa_url_from_provider`, `paper_id`.

**Return value**: 0 and a record is appended on emit; 1 (no record, no seen-set mutation) on an
empty title, a duplicate title, or a duplicate doc_id. A caller's `count`/`remaining` loop reads
this return status directly rather than assuming every call emits.

**What it owns internally**:
- The empty-title skip and `is_seen_title` check.
- The four-branch doc_id derivation (see below).
- The `is_seen_doc_id` check.
- Status/pdf_url derivation, in this fixed preference order: provider-native OA URL ->
  arXiv-synthesized URL (`https://arxiv.org/pdf/<id>`) -> Unpaywall-by-DOI lookup -> `paywall`.
- The `jq -n` record construction and the `append_result` / `add_seen` calls.

## The Closed Four-Branch doc_id Contract

`tier3_emit_record()` derives `doc_id` via exactly four branches, checked in this order:

1. `doi-slug` — DOI with `/` and `.` replaced by `_` (e.g. `10.1234/foo` -> `10_1234_foo`).
   Common case for OpenAlex and Crossref hits, since both usually carry a DOI.
2. `arxiv_<id>` — used only when no DOI is present but an arXiv ID is.
3. `ss_<paperId>` — Semantic Scholar's own paper ID, used only when neither a DOI nor an arXiv
   ID is present. OpenAlex and Crossref always pass an empty `paper_id`, so they can never land
   on this branch.
4. `unknown_<slug>` — a title-derived fallback when none of the above apply.

**No fifth prefix may ever be added.** OpenAlex and Crossref do not mint their own `oa_`/`cr_`
doc_id prefixes; they only ever land on the `doi-slug` or `unknown_<slug>` branch. A fifth prefix
would break downstream dedup (`is_seen_doc_id`) and any index-patching logic keyed on the
existing four-branch vocabulary. `docid-prefix-grep` in
`scripts/tests/test-literature-discover-tier3.sh` asserts this by grepping the script for
`doc_id="(oa|cr)_` and failing if either is ever introduced.

## OpenAlex's Prefixed DOI

OpenAlex returns DOIs prefixed with `https://doi.org/` (e.g. `https://doi.org/10.1234/foo`),
unlike Semantic Scholar and Crossref, which are already bare. `tier3_try_openalex()` strips this
prefix (`doi="${doi_raw#https://doi.org/}"`) before the value ever reaches
`tier3_emit_record()`'s doc_id slugging or the Unpaywall-by-DOI URL. An unstripped prefix would
both corrupt the doc_id (an extra `https_doi_org_` fragment) and produce an invalid Unpaywall
request URL.

## Advance-Only-on-Genuine-Failure

The chain advances to the next provider **only on genuine provider failure**: a curl transport
error, a non-200 HTTP response, an empty body, or an unparseable/`.error` body. It never advances
on a legitimate zero-result 200 — a provider that answers with zero matches is treated as having
run successfully, and the chain stops there.

This preserves the pre-existing "ran vs. couldn't run" distinction Tier 3 depends on: absence of
a `TIER3_STATUS` stderr line means Tier 3 ran and found nothing, never that Tier 3 could not run.
Continuing past a zero-result 200 to fill unused quota from a later provider was considered and
rejected — it would change latency and cost in the healthy case and blur that distinction.

Each `tier3_try_*` provider function shares one contract: `provider_fn query_string remaining ->
0|1`. Return 0 the moment a real, parseable 200 arrives — even with zero matches. Return 1 on
failure, and set the caller-visible `PROVIDER_FAIL_REASON` / `PROVIDER_FAIL_HTTP_CODE` variables
so `tier3_search()` can build its per-provider fail note and the aggregated failure line.

## The Aggregated `TIER3_STATUS` Line

When, and only when, every attempted provider fails, `tier3_search()` writes exactly one line to
its own stderr:

```
TIER3_STATUS: FAILED reason=all_providers_exhausted http_code=<last|n/a> (tried: <providers>; <fail_notes>)
```

`<fail_notes>` is a semicolon-joined list of `provider:reason=<r>:http=<code>` entries, one per
attempted provider. `<last|n/a>` is the last-attempted provider's HTTP code, or `n/a` if it
failed at the curl-transport level.

**`commands/literature.md` consumer constraint (this is why the line has this exact shape)**:
that file's discover step 1 runs two greps against this script's captured stderr —
`grep -q 'TIER3_STATUS: FAILED'` and `grep -o 'http_code=[^ ]*'` — and requires no edit for this
task. The aggregated line therefore keeps the literal `TIER3_STATUS: FAILED` substring and a
space-free `http_code=` token, both on the same line, exactly as the pre-existing single-provider
line did. `commands/literature.md` is substring/token-tolerant by design and does not care how
many providers were tried or what the parenthesized detail text says.

## Decision: arXiv's Atom-XML API Is Out of Scope

Native arXiv search (its own Atom-XML API) was considered and explicitly excluded from this
provider chain — recorded as a decision, not an oversight. It is the one parser-cost outlier in
a script that is otherwise uniformly `jq`-over-JSON across all four Tier 3 providers (Semantic
Scholar, OpenAlex, Crossref, Unpaywall), and the marginal coverage gain is small: Semantic
Scholar's `externalIds.ArXiv` field and OpenAlex's OA locations already surface most
arXiv-hosted content that would otherwise require a dedicated arXiv API integration. A future
task may add it if this gap proves material in practice.

## Testing

`scripts/tests/test-literature-discover-tier3.sh` exercises this whole contract against a
PATH-shadowing curl stub (`scripts/tests/curl-stub.sh`), with no real network access: the
byte-identical regression gate against the pre-refactor golden baseline, the `S2_API_KEY`
header check, per-provider schema and doc_id assertions, the five chain-behavior scenarios
(healthy / zero-result / S2-fails-OpenAlex-answers / all-fail / quota-zero), and the end-to-end
`literature-ingest-online.sh --dry-run` integration check.
