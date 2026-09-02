# Implementation Plan: Multi-Provider Tier 3 Fallback for literature-discover.sh

- **Task**: 110 - Add multi-provider fallback and S2_API_KEY support to literature-discover.sh Tier 3
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/110_add_discover_multi_provider_fallback/reports/01_multi-provider-tier3-fallback.md
- **Artifacts**: plans/01_multi-provider-tier3-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Tier 3 of `literature-discover.sh` currently has exactly one online provider (Semantic Scholar,
at the `ss_url` assignment inside `tier3_search()`), so a single rate-limited provider silently
disables the entire online tier. This plan makes two additive changes inside that one script:
honor an optional `S2_API_KEY` as an `x-api-key` header, and add an ordered provider fallback
chain (Semantic Scholar -> OpenAlex -> Crossref) that advances only on genuine provider failure.
The mechanism that keeps every provider's output schema-identical is a **behavior-preserving
extraction first**: the per-hit normalization, doc_id derivation, status/pdf_url derivation, and
dedup logic currently inline in the Semantic Scholar `while` loop are lifted into one shared
`tier3_emit_record()` helper that every provider branch calls, so schema identity holds by
construction rather than by three parallel reimplementations. Done means: with Semantic Scholar
forced to 429, a real discovery run still emits a schema-valid Tier 3 record, and that record is
accepted by `literature-ingest-online.sh --dry-run` without a usage error (exit 64).

### Research Integration

Findings from `reports/01_multi-provider-tier3-fallback.md` carried into this plan:

- **No retry/backoff exists in the script today.** The 20+-attempt/75s pattern observed in the
  originating session was external agent-level retrying. Every phase below is therefore scoped to
  work correctly within **one invocation** of the script; adding retry/backoff is a non-goal.
- **Extract, don't duplicate** (Phase 3 before Phase 4). This ordering is load-bearing: adding
  providers before the extraction would create the parallel-reimplementation risk the task's hard
  constraint exists to prevent.
- **Four-branch doc_id contract is closed**: `doi-slug` / `arxiv_<id>` / `ss_<paperId>` /
  `unknown_<slug>`. No fifth prefix. OpenAlex and Crossref pass an empty `paper_id`, so they land
  on `doi-slug` (common case) or `unknown_<slug>`, never `ss_<paperId>`.
- **arXiv hits are `status=="open_access"` with `arxiv_id` set.** There is no literal `"arxiv"`
  status value; the status vocabulary reaching the ingest bridge stays
  `{in_zotero_no_pdf, open_access, paywall}`.
- **`commands/literature.md`'s consumer is substring/token-tolerant**: it runs
  `grep -q 'TIER3_STATUS: FAILED'` and `grep -o 'http_code=[^ ]*'`. An aggregated multi-provider
  failure line is backward compatible as long as the literal `FAILED` text and a space-free
  `http_code=` token both appear on the same line. That consumer file requires no edit.
- **OpenAlex and Crossref were both live-probed anonymously and succeeded** (2026-09-01). OpenAlex
  returns a **prefixed** DOI (`https://doi.org/10.x/...`) that must be stripped to bare before it
  reaches doc_id slugging or the Unpaywall URL; Crossref's `DOI` is already bare. Crossref carries
  no OA/PDF field at all, so its hits reuse the existing Unpaywall-by-DOI path unchanged.
- **Disputed OpenAlex key mandate**: a secondary source claims a mandatory-key cutover; the
  canonical docs and the live probe say otherwise. Resolution adopted here: optional/additive
  `OPENALEX_API_KEY` support plus a `mailto=` politeness param, so a future policy flip needs a
  config change, not a code change.
- **Chain advances only on genuine provider failure** (curl error / non-200 / empty or unparseable
  body / `.error` field) — never on a legitimate zero-result 200. The research explicitly
  considered and rejected "continue on zero results to fill unused quota": it would change
  latency and cost in the healthy case and blur the "ran vs. couldn't run" distinction this task
  is required to preserve.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Read `S2_API_KEY` from the environment and send it as an `x-api-key` header on the Semantic
  Scholar request when set; remain fully anonymous and behavior-identical when unset.
- Extract the per-hit normalization/doc_id/status/dedup logic into one shared
  `tier3_emit_record()` helper, with byte-identical output for the existing Semantic Scholar path.
- Add OpenAlex and Crossref as ordered fallback providers that call that same helper.
- Advance the chain only on genuine provider failure; preserve "absence of a `TIER3_STATUS` line
  means Tier 3 ran and found nothing."
- Emit exactly one aggregated `TIER3_STATUS: FAILED` line when (and only when) every attempted
  provider failed, in a shape the existing `commands/literature.md` consumer parses unchanged.
- Prove the integration contract end to end: S2 forced to 429 -> schema-valid record ->
  `literature-ingest-online.sh --dry-run` classifies it without exit 64.

**Non-Goals**:
- **arXiv's Atom-XML API is out of scope** (recorded decision, see Decisions below). It is the one
  parser-cost outlier in a script that is otherwise uniformly `jq`-over-JSON, and Semantic Scholar's
  `externalIds.ArXiv` plus OpenAlex's OA locations already surface most arXiv-hosted content.
- No retry/backoff inside the script. A single invocation tries each provider at most once.
- No change to the per-tier quota/rollover arithmetic, which lives outside `tier3_search()`.
- No change to Tier 1 or Tier 2, to `append_result`/`add_seen`/`is_seen_*` dedup semantics, or to
  the JSON-array stdout contract.
- No change to `commands/literature.md` (its consumer stays compatible by construction).
- No heuristic arXiv-ID extraction from OpenAlex records (`arxiv_id: null` for OpenAlex hits).
- No near-duplicate/fuzzy dedup improvements; existing title+doc_id dedup is the accepted bar.
- No redeploy of the `.claude/` tree. `.claude/` is a disposable deploy artifact regenerated by
  the deploy/reload process; the edit target is the source store only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `tier3_emit_record()` extraction silently regresses the currently-working Semantic Scholar path | H | M | Phase 1 captures a pre-refactor golden output; Phase 3 closes only on a byte-identical diff against it with no stubbing and no new providers wired in |
| A new provider mints a fifth doc_id prefix, breaking downstream dedup and index patching | H | M | Providers never derive doc_ids themselves — `tier3_emit_record()` owns all four branches; Phase 4 asserts the absence of any `oa_`/`cr_` prefix in its verification |
| OpenAlex's prefixed DOI (`https://doi.org/...`) reaches doc_id slugging or the Unpaywall URL unstripped | M | M | Strip in the OpenAlex branch before calling the shared helper; Phase 4 verification asserts a bare-DOI doc_id from an OpenAlex fixture |
| Aggregated FAILED line breaks `commands/literature.md`'s greps | M | L | Phase 6 runs that file's two exact grep expressions against the real emitted line as an explicit check |
| `set -euo pipefail` interacts badly with the new provider loop (e.g. `local x=$(...)` masking exit status, or a non-zero provider return aborting the script) | M | M | Provider functions are called in `if` condition context (errexit-exempt); declare `local` separately from assignment where the exit status is consumed; Phase 5 verification includes a run under all-providers-fail to confirm the script still exits normally |
| Quota accounting drifts once multiple providers can append results | M | M | Recompute `remaining` from the shared `RESULTS` array length against a baseline captured at `tier3_search()` entry, mirroring how the outer rollover math already derives actual counts |
| OpenAlex flips to a mandatory-key policy mid-flight | L | L | `OPENALEX_API_KEY` is read additively now, so the response is a config change; and Crossref remains as a keyless final fallback |
| PATH-shadowing `curl` stub is bypassed because the script calls `curl` via an absolute path or `command curl` | M | L | Verified: the script calls bare `curl`. Phase 1 confirms the stub actually intercepts before any later phase depends on it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6, 7 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Curl-Stub Harness and Pre-Refactor Golden Baseline [COMPLETED]

**Goal**: Establish the PATH-shadowing `curl` stub convention this repo does not yet have, and
capture the pre-refactor Semantic Scholar output that Phase 3's regression check compares against.

**Tasks**:
- [x] Confirm `literature-discover.sh` invokes bare `curl` (not `command curl`, not an absolute
      path) so a `PATH`-shadowing stub actually intercepts it. *(completed)*
- [x] Add a stub script under `agent-system/extensions/literature/scripts/tests/` (following the
      existing `test-literature-*.sh` naming convention there) that dispatches on the requested
      URL host: canned responses for `api.semanticscholar.org`, `api.openalex.org`,
      `api.crossref.org`, and `api.unpaywall.org`, with per-host status/body controlled by
      environment variables so one stub serves every later scenario. *(completed: curl-stub.sh)*
- [x] Store canned JSON fixtures for each provider shaped like the real responses documented in
      the research report (Semantic Scholar `.data[]`; OpenAlex `.results[]` with a **prefixed**
      DOI; Crossref `.message.items[]` with a bare `DOI`). *(completed: fixtures/tier3-*.json)*
- [x] Prove the stub intercepts: run `literature-discover.sh` with the stub first on `PATH` and
      confirm no real network call occurs and the stubbed body drives the output. *(completed: stub-intercept scenario)*
- [x] Capture the golden baseline: with the stub serving a fixed Semantic Scholar 200 fixture and
      a fixed Unpaywall response, run the **current, unmodified** script and save stdout to a
      fixture file for the Phase 3 diff. *(completed: fixtures/tier3-golden-baseline.json)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/` - new stub script and fixture files
  (new files only; no existing script is edited in this phase)

**Verification**:
- Running the discover script with the stub on `PATH` produces output derived entirely from the
  fixtures (no network dependency; reproducible across two consecutive runs).
- The golden baseline file is non-empty and is a valid JSON array containing at least one Tier 3
  record (`jq -e '.[] | select(.tier == 3)'` succeeds).

---

### Phase 2: Fix 1 — Optional S2_API_KEY Header [COMPLETED]

**Goal**: Send `x-api-key: $S2_API_KEY` on the Semantic Scholar request when the variable is set,
with zero behavior change when it is unset.

**Tasks**:
- [x] Add `S2_API_KEY="${S2_API_KEY:-}"` to the existing environment-defaults block alongside
      `LITERATURE_DIR` / `DISCOVER_LIMIT` / `DISCOVER_DESC_WORD_CAP` / `USER_EMAIL`. *(completed)*
- [x] Replace the inline `curl -s -w '\n%{http_code}' --max-time 15 "$ss_url"` call with a
      `curl_args` array built from those same flags, appending
      `-H "x-api-key: $S2_API_KEY"` only when the variable is non-empty. *(completed)*
- [x] Document `S2_API_KEY` in the script header's `ENVIRONMENT` block (optional; unset means
      anonymous access at the lower public rate limit). *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - env default, header
  `ENVIRONMENT` entry, `curl_args` array in the Semantic Scholar request

**Verification**:
- `bash -n` on the script passes.
- With `S2_API_KEY` unset and the Phase 1 stub serving the same fixture, output is byte-identical
  to the Phase 1 golden baseline.
- With `S2_API_KEY` set to a dummy value, the stub records receiving an `x-api-key` header (stub
  logs its argv); with it unset, the stub records no such header.

---

### Phase 3: Extract tier3_emit_record() (Behavior-Preserving Refactor) [COMPLETED]

**Goal**: Lift the per-hit normalization body out of the inline Semantic Scholar loop into one
shared function, with provably identical output for the existing path and no new providers yet.

**Tasks**:
- [x] Define `tier3_emit_record()` taking, in order: `title`, `authors_json`, `year`, `doi`,
      `arxiv_id`, `oa_url_from_provider`, `paper_id`. *(completed)*
- [x] Move into it, unchanged in logic: the empty-title skip, `is_seen_title` check, the
      four-branch doc_id derivation, the `is_seen_doc_id` check, the status/pdf_url derivation
      (provider OA URL -> arXiv synthesized URL -> Unpaywall-by-DOI -> `paywall`), the `jq -n`
      record construction, and the `append_result` / `add_seen` calls. *(completed)*
- [x] Have it return a distinguishable status so the caller can count emitted records (e.g. 0 on
      emit, non-zero on skip), and make the caller's `count`/`remaining` break condition read that
      status rather than assuming every iteration emits. *(completed)*
- [x] Reduce the Semantic Scholar `while` loop body to: field extraction via `jq` from the
      Semantic Scholar shape, then one `tier3_emit_record` call. *(completed)*
- [x] Confirm the four doc_id branches and the three status values remain exactly as they were;
      add no fifth branch and no new status value. *(completed: verified via grep, exactly 4 branches)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The extraction is estimated at roughly 100 lines of existing inline body
moving into the new helper, with the Semantic Scholar loop shrinking to field extraction plus one
call. Confirm at implementation time by reading the actual `tier3_search()` body rather than
trusting this figure; if the block is materially larger or entangled with the loop's `count`/
`remaining` control flow in ways this plan does not anticipate, record the actual shape in the
implementation summary rather than forcing the estimate.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - new `tier3_emit_record()`
  function; `tier3_search()`'s Semantic Scholar loop reduced to a mapping call

**Verification**:
- `bash -n` passes.
- **Regression gate**: with the Phase 1 stub and identical fixtures, output is **byte-identical**
  (`diff` clean) to the Phase 1 golden baseline. This is the phase's blocking criterion.
- A separate un-stubbed run against a known live query (network permitting) produces a valid
  JSON array with Tier 3 records; if Semantic Scholar is rate-limited at the time, that run is
  informational only and the stubbed diff remains the gate.
- `grep` confirms exactly four doc_id assignment branches inside `tier3_emit_record()` and none
  elsewhere in `tier3_search()`.

---

### Phase 4: Add OpenAlex and Crossref Provider Functions [COMPLETED]

**Goal**: Add two provider functions that fetch, validate, and map their own JSON shape onto
`tier3_emit_record()` — introducing no dedup, doc_id, or status logic of their own.

**Tasks**:
- [x] Add `OPENALEX_API_KEY="${OPENALEX_API_KEY:-}"` to the environment-defaults block (optional,
      additive, mirroring `S2_API_KEY`). *(completed)*
- [x] Implement `tier3_try_openalex(query_string, remaining)`: build
      `https://api.openalex.org/works?search=<urlencoded>&per-page=10`, append
      `&mailto=${USER_EMAIL}`, and append `&api_key=...` only when `OPENALEX_API_KEY` is set.
      Map `results[]` -> `.title`, `.publication_year`, `.doi` (**strip any `https://doi.org/`
      prefix to bare DOI before passing it on**), `.authorships[].author.display_name` joined
      into a JSON array, and an OA URL preferring `.primary_location.pdf_url` then
      `.open_access.oa_url`. Pass `arxiv_id=""` and `paper_id=""`. *(completed)*
- [x] Implement `tier3_try_crossref(query_string, remaining)`: build
      `https://api.crossref.org/works?query=<urlencoded>&rows=10&mailto=${USER_EMAIL}`. Map
      `message.items[]` -> `.title[0]`, `.issued.date-parts[0][0]`, `.DOI` (already bare),
      authors from `.author[].given`/`.family`. Pass empty OA URL, `arxiv_id`, and `paper_id` —
      Crossref hits therefore reuse the existing Unpaywall-by-DOI path inside
      `tier3_emit_record()` with no new status logic. *(completed)*
- [x] Give both functions the same failure contract as the existing Semantic Scholar branch:
      return non-zero on curl failure, non-200, empty body, or unparseable/error body; return
      zero the moment a real parseable 200 arrives, **even with zero matches**. *(completed)*
- [x] Have each function record its own `reason` and `http_code` into caller-visible variables for
      the Phase 5 aggregated failure line, and write no `TIER3_STATUS` line itself. *(completed: PROVIDER_FAIL_REASON/PROVIDER_FAIL_HTTP_CODE)*
- [x] Refactor the existing Semantic Scholar branch into `tier3_try_semantic_scholar()` with the
      identical signature and failure contract. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: Two new provider functions plus one extraction of the existing branch into
a third, all in the same file — asserted as three functions with a uniform
`(query_string, remaining) -> 0|1` signature. Confirm at implementation time that the shared
signature actually accommodates all three (in particular that the Semantic Scholar branch needs
no extra parameter for its `paper_id` pass-through); if it does not, adjust the signature once
for all three rather than special-casing one.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - `OPENALEX_API_KEY`
  default, `tier3_try_semantic_scholar()`, `tier3_try_openalex()`, `tier3_try_crossref()`

**Verification**:
- `bash -n` passes.
- Driving each provider function directly against its Phase 1 fixture produces records that pass a
  schema assertion: keys `title`, `authors`, `year`, `doc_id`, `status`, `tier`, `doi`,
  `arxiv_id`, `pdf_url` all present (null-valued where absent), `tier == 3`, `status` in
  `{open_access, paywall}`.
- The OpenAlex fixture's prefixed DOI yields a bare-DOI-derived doc_id (no `https_` or `doi_org_`
  fragment in the doc_id).
- A grep for `oa_` / `cr_` doc_id prefixes across the script confirms none was introduced.
- Each function returns 0 on a stubbed 200-with-zero-results and non-zero on a stubbed 429.

---

### Phase 5: Ordered Provider Loop and Aggregated TIER3_STATUS Line [COMPLETED]

**Goal**: Replace the single inline provider call with an ordered chain that advances only on
genuine failure, and emit one backward-compatible aggregated failure line only when all providers
failed.

**Tasks**:
- [x] In `tier3_search()`, after the existing `TIER3_QUOTA <= 0` skip and query-string build,
      capture a baseline `RESULTS` length so per-provider emission can be counted. *(completed)*
- [x] Define the ordered chain `semantic_scholar openalex crossref` (Semantic Scholar first as the
      already-working default now improved by Fix 1; OpenAlex second for breadth plus native OA
      data with no key required; Crossref last as DOI-authoritative but OA-blind). *(completed)*
- [x] Loop over the chain: break when `remaining <= 0`; call the provider in `if` condition
      context (errexit-safe); on success set `any_provider_answered=true` and **break** — the
      chain does not continue past a real answer, including a zero-result one; on failure append
      `provider:reason=<r>:http=<code>` to a `fail_notes` array and record `last_http_code`.
      *(completed)*
- [x] Recompute `remaining` from `TIER3_QUOTA` minus (current `RESULTS` length minus the baseline
      captured at entry), mirroring the outer rollover math's derive-from-RESULTS approach.
      *(completed)*
- [x] When and only when `any_provider_answered` is false, emit exactly one line to stderr in the
      shape `TIER3_STATUS: FAILED reason=all_providers_exhausted http_code=<last|n/a> (tried: ...; <fail_notes>)`
      — literal `TIER3_STATUS: FAILED` substring present, `http_code=` followed by a token with no
      embedded spaces, all on one line. *(completed)*
- [x] Preserve the two existing silences: no line on a `TIER3_QUOTA <= 0` skip, and no line when a
      provider answered with zero matches. *(completed)*
- [x] Keep `tier3_search()` returning 0 in every path (Tier 3 stays non-fatal). *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - `tier3_search()` body
  replaced by the provider loop and aggregated status emission

**Verification**:
- `bash -n` passes.
- Stub scenario "S2 200 with results": output byte-identical to the Phase 1 golden baseline, no
  `TIER3_STATUS` line on stderr, and the stub log shows **no** OpenAlex or Crossref request.
- Stub scenario "S2 200 with zero results": no `TIER3_STATUS` line, and no OpenAlex/Crossref
  request (chain does not advance on a thin answer).
- Stub scenario "S2 429, OpenAlex 200": exactly zero `TIER3_STATUS` lines, records present and
  sourced from the OpenAlex fixture.
- Stub scenario "all three fail": exactly one `TIER3_STATUS: FAILED` line on stderr, script exits
  normally (Tier 3 non-fatal), and the process is not aborted by `set -e`.
- Stub scenario "`DISCOVER_LIMIT` small enough that `TIER3_QUOTA` is 0": no `TIER3_STATUS` line,
  no provider request at all.

---

### Phase 6: End-to-End Integration Verification Against the Stated Bar [COMPLETED]

**Goal**: Demonstrate the actual contract this task exists to restore — a schema-valid record
produced while Semantic Scholar is unavailable, accepted by the ingest bridge.

**Tasks**:
- [x] Run `literature-discover.sh` (the **source-store** copy, not the `.claude/` deploy copy)
      with the stub forcing `api.semanticscholar.org` to HTTP 429 and allowing OpenAlex through
      (fixture or real network), capturing stdout and stderr separately. *(completed)*
- [x] Assert the resulting JSON array contains at least one `tier == 3` record with all nine
      contract keys present and `status` in `{open_access, paywall}`. *(completed)*
- [x] Pipe exactly that record into
      `literature-ingest-online.sh --record '<json>' --dry-run` and confirm it **does not exit
      64** (the usage/malformed-input code) and prints a documented directive token or dry-run
      preview. *(completed: rc=8 ONLINE_INGEST_DEDUP_CHECK_FAILED, not 64)*
- [x] Run the all-providers-fail scenario and apply `commands/literature.md`'s two exact consumer
      expressions to the captured stderr: `grep -q 'TIER3_STATUS: FAILED'` must succeed and
      `grep -o 'http_code=[^ ]*'` must yield exactly one space-free token. *(completed)*
- [x] Confirm `commands/literature.md` required no edit (its greps still fire unmodified).
      *(completed: zero diff against HEAD)*
- [x] Record all scenario commands and their observed output in the implementation summary so the
      verification is reproducible rather than asserted. *(completed: see summaries/01_multi-provider-tier3-fallback-summary.md)*

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- (verification only; no production file edited — any fixture or scenario-runner additions land
  under `agent-system/extensions/literature/scripts/tests/`)

**Verification**:
- The S2-429 run yields a non-empty JSON array with a schema-valid Tier 3 record not sourced from
  Semantic Scholar.
- `literature-ingest-online.sh --record ... --dry-run` on that record exits with a code other
  than 64 and emits a documented directive/preview, not a usage error.
- The all-fail run's stderr satisfies both consumer greps.
- The full existing test set under `agent-system/extensions/literature/scripts/tests/` still
  passes (`test-literature-build-index.sh`, `test-literature-convert.sh`,
  `test-quality-gate-notation.sh`).

---

### Phase 7: Documentation — Env Vars, README Tier 3, and Provider-Chain Context Doc [COMPLETED]

**Goal**: Document the new environment variables, correct the now-stale Tier 3 description, and
record the provider-chain contract so the next reader does not have to re-derive it from source.

**Tasks**:
- [x] Extend the script header's `ENVIRONMENT` block with `OPENALEX_API_KEY` (optional, additive)
      alongside the `S2_API_KEY` entry added in Phase 2. *(completed in Phase 4)*
- [x] Update the script header's Tier 3 one-liner and the `show_usage()` Tier 3 line, both of
      which currently say "Semantic Scholar + Unpaywall/arXiv", to name the provider chain.
      *(completed)*
- [x] Update the Tier 3 bullet in `agent-system/extensions/literature/README.md` (currently
      "Semantic Scholar API, Unpaywall DOI lookup, arXiv direct PDF") to describe the ordered
      chain and both optional API-key variables. *(completed)*
- [x] Create `agent-system/extensions/literature/context/project/literature/domain/tier3-provider-fallback.md`
      documenting: provider order and its rationale, the `tier3_emit_record()` contract and
      parameter list, the closed four-branch doc_id rule with an explicit warning against a fifth
      prefix, the advance-only-on-genuine-failure rule, and the aggregated `TIER3_STATUS` line
      shape with its `commands/literature.md` consumer constraint. Mirror the shape of the
      sibling `sparse-coverage.md` doc in that directory. *(completed)*
- [x] Record the arXiv-out-of-scope decision in that context doc so a future reader sees it was
      decided, not overlooked. *(completed)*
- [x] Reference durable anchors only (filenames, function names, section headings) — no task-number
      citations in any file outside `specs/`. *(completed: check-task-references.sh passes clean)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: prose

**Scope Hypothesis**: Four documentation surfaces are asserted here (script header `ENVIRONMENT`
block, script header + `show_usage()` Tier 3 lines, README Tier 3 bullet, new context doc).
Confirm at implementation time with a grep for `Semantic Scholar` across
`agent-system/extensions/literature/` — if additional prose describes Tier 3 as single-provider in
places this plan did not enumerate, update those too and note the addition rather than treating
the list as closed.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-discover.sh` - header `ENVIRONMENT` and
  Tier 3 description lines, `show_usage()` Tier 3 line
- `agent-system/extensions/literature/README.md` - Tier 3 bullet
- `agent-system/extensions/literature/context/project/literature/domain/tier3-provider-fallback.md` - new

**Verification**:
- A grep for `Semantic Scholar` across the extension returns no remaining prose that describes
  Tier 3 as having a single provider.
- The new context doc exists, is non-empty, and names all four doc_id branches plus the
  no-fifth-prefix rule.
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo-wide lint) reports no
  task-number references introduced outside `specs/`.

---

## Testing & Validation

- [x] `bash -n agent-system/extensions/literature/scripts/literature-discover.sh` passes after
      every code phase.
- [x] Phase 3 regression gate: post-refactor stubbed output is byte-identical to the Phase 1
      pre-refactor golden baseline.
- [x] All five Phase 5 stub scenarios behave as specified (healthy, zero-result, S2-fails-OpenAlex-
      answers, all-fail, quota-zero).
- [x] Phase 6 end-to-end bar: S2 forced to 429 -> schema-valid Tier 3 record ->
      `literature-ingest-online.sh --record ... --dry-run` does not exit 64.
- [x] `commands/literature.md`'s two consumer greps fire unmodified against the aggregated
      FAILED line.
- [x] Existing tests under `agent-system/extensions/literature/scripts/tests/` still pass.
- [x] No fifth doc_id prefix anywhere; status vocabulary unchanged.

## Artifacts & Outputs

- Modified: `agent-system/extensions/literature/scripts/literature-discover.sh`
- Modified: `agent-system/extensions/literature/README.md`
- New: `agent-system/extensions/literature/context/project/literature/domain/tier3-provider-fallback.md`
- New: curl-stub harness and provider fixtures under
  `agent-system/extensions/literature/scripts/tests/`
- New: `specs/110_add_discover_multi_provider_fallback/summaries/01_*-summary.md` with the
  recorded verification-scenario commands and observed output

## Rollback/Contingency

Every change is confined to the literature extension's source store, and each phase is committed
separately, so `git revert` of the phase commits restores the prior single-provider behavior
without touching any other subsystem. Partial-rollback points: reverting Phases 4-7 while keeping
Phases 2-3 leaves a working single-provider Tier 3 with `S2_API_KEY` support and the shared
`tier3_emit_record()` helper in place — the Phase 3 regression gate exists precisely so that this
intermediate state is known-good. If the Phase 3 byte-identical diff cannot be achieved, stop
there and revert to Phase 2's state rather than proceeding with an unproven refactor underneath
new providers.

## Decisions

- **arXiv's Atom-XML API is out of scope for this task.** It is the only non-JSON provider under
  consideration in an otherwise uniformly `jq`-based script, and the marginal coverage gain is
  small because Semantic Scholar's `externalIds.ArXiv` and OpenAlex's OA locations already surface
  arXiv-hosted content. Recorded as a decision, not an oversight; a future task may add it.
- **Two fallback providers, not three** (OpenAlex then Crossref). The task description explicitly
  permits a justified subset.
- **Chain advances only on genuine provider failure**, never on a zero-result 200 — preserving
  today's latency/cost profile in the healthy case and the "ran vs. couldn't run" distinction.
  Continuing on zero results to fill unused quota was considered and rejected; it is a legitimate
  but separate enhancement.
- **No new doc_id prefix.** OpenAlex and Crossref records use only the existing `doi-slug` and
  `unknown_<slug>` branches.
- **Both new providers' auth is optional and additive** (`OPENALEX_API_KEY` mirroring
  `S2_API_KEY`), hedging against the disputed OpenAlex key-mandate report without depending on it.
