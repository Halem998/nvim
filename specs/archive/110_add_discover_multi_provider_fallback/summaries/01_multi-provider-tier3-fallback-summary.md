# Implementation Summary: Task #110

- **Task**: 110 - Add multi-provider fallback and S2_API_KEY support to literature-discover.sh Tier 3
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_multi-provider-tier3-fallback.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`literature-discover.sh`'s Tier 3 previously depended on a single online provider (Semantic
Scholar), so a rate-limited Semantic Scholar silently disabled the entire online tier. This
implementation added optional `S2_API_KEY` support, extracted the per-hit normalization/doc_id/
status/dedup logic into a shared `tier3_emit_record()` helper (behavior-preserving, verified
byte-identical against a pre-refactor golden baseline), and added an ordered provider fallback
chain (Semantic Scholar -> OpenAlex -> Crossref) that advances only on genuine provider failure.
All seven plan phases completed; all work stayed inside the literature extension's source store
(`agent-system/extensions/literature/`), with no `.claude/` redeploy per the plan's recorded
decision.

## What Changed

- `agent-system/extensions/literature/scripts/literature-discover.sh` — added `S2_API_KEY` /
  `OPENALEX_API_KEY` env defaults and header documentation; extracted `tier3_emit_record()`
  (the shared per-hit normalization/doc_id/status/dedup helper); added `tier3_try_semantic_scholar()`,
  `tier3_try_openalex()`, `tier3_try_crossref()` provider functions sharing one
  `(query_string, remaining) -> 0|1` contract; replaced `tier3_search()`'s single-provider call
  with an ordered chain and an aggregated `TIER3_STATUS: FAILED` stderr line emitted only when
  every attempted provider fails; updated header/`show_usage()` Tier 3 descriptions.
- `agent-system/extensions/literature/scripts/tests/curl-stub.sh` — new PATH-shadowing curl stub
  dispatching canned per-host HTTP responses (Semantic Scholar / OpenAlex / Crossref / Unpaywall),
  controlled by `CURL_STUB_*` env vars, with a `curl_fail` code value simulating a transport
  failure and `CURL_STUB_LOG` for header-presence assertions.
- `agent-system/extensions/literature/scripts/tests/test-literature-discover-tier3.sh` — new
  regression/scenario suite: stub-intercept, golden-baseline (byte-identical regression gate),
  header-check, per-provider schema/doc_id assertions, docid-prefix-grep, and the five Phase 5
  chain-behavior scenarios (healthy, zero-result, s2-fail-openalex, all-fail, quota-zero), plus
  an end-to-end `literature-ingest-online.sh --dry-run` integration check.
- `agent-system/extensions/literature/scripts/tests/fixtures/` — new canned JSON fixtures for
  Semantic Scholar (200 and empty-200), OpenAlex (prefixed DOI), Crossref (bare DOI), Unpaywall,
  and the captured pre-refactor golden baseline (`tier3-golden-baseline.json`).
- `agent-system/extensions/literature/README.md` — Tier 3 bullet updated to describe the ordered
  fallback chain and both optional API-key variables.
- `agent-system/extensions/literature/context/project/literature/patterns/literature-command-modes.md` —
  Tier 3 bullet updated (same stale "Semantic Scholar API, Unpaywall DOI lookup, arXiv" prose
  found via the Phase 7 scope-hypothesis grep sweep; not enumerated in the original plan file
  list, updated per that phase's confirm-at-implementation-time instruction).
- `agent-system/extensions/literature/context/project/literature/patterns/zotero-item-creation.md` —
  minor accuracy addition: its cookie-wall-risk note's provider list now also names OpenAlex/
  Crossref alongside Semantic Scholar/Unpaywall/arXiv.
- `agent-system/extensions/literature/context/project/literature/domain/tier3-provider-fallback.md` —
  new context doc (mirrors sibling `sparse-coverage.md`'s shape) documenting provider order and
  rationale, the `tier3_emit_record()` contract, the closed four-branch doc_id rule, the
  OpenAlex-prefixed-DOI stripping requirement, the advance-only-on-genuine-failure rule, the
  aggregated `TIER3_STATUS` line shape and its `commands/literature.md` consumer constraint, and
  the arXiv-out-of-scope decision.

## Decisions

- Extraction-before-addition ordering was followed exactly as planned: Phase 3 (extract
  `tier3_emit_record()`) closed on a byte-identical diff against the Phase 1 golden baseline
  before Phase 4 added any new provider.
- `tier3_search()`'s single-provider call site was refactored to call
  `tier3_try_semantic_scholar()` directly in Phase 4 (ahead of Phase 5's full chain), keeping the
  script always in a runnable, behavior-identical state between phases rather than leaving a
  half-wired intermediate.
- The Phase 4/5 provider-function verification used a direct-invocation test harness
  (`_run_provider_direct` in the test suite, extracting function definitions into a scratch
  script under the curl stub) rather than requiring Phase 5's chain to exist first — this matches
  the plan's Phase 4 verification intent ("driving each provider function directly") without
  waiting on later-phase wiring.
- Phase 7's scope-hypothesis grep sweep (`grep -rn "Semantic Scholar"`) found one additional
  stale-prose surface beyond the plan's enumerated four
  (`context/project/literature/patterns/literature-command-modes.md`, byte-identical duplicate
  bullet to README.md's); updated it too and recorded the addition here per that phase's own
  instruction not to treat the list as closed.

## Plan Deviations

- None (implementation followed plan). The one addition beyond the plan's enumerated Phase 7
  file list (`literature-command-modes.md`) was explicitly anticipated by that phase's own
  Scope Hypothesis instruction ("if additional prose describes Tier 3 as single-provider in
  places this plan did not enumerate, update those too"), so it is recorded as a plan-anticipated
  addition rather than a deviation.

## Verification

- Build: N/A (bash script; `bash -n` passes after every code phase)
- Tests: Passed — full custom suite (27/27 scenarios) plus all three pre-existing suites under
  `scripts/tests/` (`test-literature-build-index.sh` 9/9,  `test-literature-convert.sh` 13/13,
  `test-quality-gate-notation.sh` all fixtures)
- Files verified: Yes

### Reproducible verification commands and observed output (Phase 6)

**Full custom suite** (`bash agent-system/extensions/literature/scripts/tests/test-literature-discover-tier3.sh all`): 27 passed, 0 failed — covers stub-intercept, golden-baseline (byte-identical regression gate), header-check, schema-openalex, schema-crossref, docid-prefix-grep, healthy, zero-result, s2-fail-openalex, all-fail, quota-zero, e2e-ingest.

**Phase 6 end-to-end bar, run directly against the source-store script** (not through the test harness, to demonstrate the literal contract):

```
PATH="$STUB_DIR:$PATH" LITERATURE_DIR="$LIT_SCRATCH" \
  CURL_STUB_SS_CODE=429 CURL_STUB_OPENALEX_CODE=200 \
  CURL_STUB_OPENALEX_BODY=".../tier3-openalex-200.json" \
  agent-system/extensions/literature/scripts/literature-discover.sh \
  "S2 429 OpenAlex 200 integration probe"
```
Result: exit 0, stdout is a JSON array containing one `tier==3` record sourced from the OpenAlex
fixture (`doc_id=10_5678_openalex-stub`, `status=open_access`), all nine schema keys present, no
`TIER3_STATUS` line on stderr (only the tier2-skip notice).

```
literature-ingest-online.sh --record '<that record>' --dry-run
```
Result: exit 8 (`ONLINE_INGEST_DEDUP_CHECK_FAILED`), **not 64**. Stdout carries the documented
directive token `ONLINE_INGEST_DEDUP_CHECK_FAILED`; stderr shows the record was classified
`resolvable` (create-item path) and the exit came from a downstream Zotero-search-unavailable
condition in this sandboxed environment, not a usage/malformed-input error — exactly the "not
exit 64" bar the plan sets.

```
PATH="$STUB_DIR:$PATH" LITERATURE_DIR="$LIT_SCRATCH" \
  CURL_STUB_SS_CODE=curl_fail CURL_STUB_OPENALEX_CODE=curl_fail CURL_STUB_CROSSREF_CODE=curl_fail \
  agent-system/extensions/literature/scripts/literature-discover.sh \
  "all providers fail integration probe"
```
Result: exit 1 (no sources found), stderr contains exactly one line:
`TIER3_STATUS: FAILED reason=all_providers_exhausted http_code=n/a (tried: semantic_scholar,openalex,crossref; semantic_scholar:reason=curl_exit:http=n/a;openalex:reason=curl_exit:http=n/a;crossref:reason=curl_exit:http=n/a)`.
`commands/literature.md`'s two exact consumer expressions both succeed against it:
`grep -q 'TIER3_STATUS: FAILED'` matches; `grep -o 'http_code=[^ ]*'` yields exactly one token,
`http_code=n/a`.

`commands/literature.md` required no edit: `git diff --stat HEAD -- .../commands/literature.md`
is empty.

## Impacts

- Tier 3 online discovery no longer has a single point of failure: a rate-limited or unreachable
  Semantic Scholar now falls through to OpenAlex, then Crossref, before Tier 3 is reported as
  failed.
- `S2_API_KEY` / `OPENALEX_API_KEY` let a user raise both providers' rate limits without any
  script change; both remain fully anonymous and behavior-identical when unset.
- No downstream consumer (`commands/literature.md`, `literature-ingest-online.sh`, the doc_id/
  dedup contract) required any change — the extraction-first design and the closed four-branch
  doc_id contract kept the integration surface stable by construction.

## Follow-ups

- None required for this task's stated bar. The arXiv Atom-XML API remains explicitly
  out-of-scope (recorded decision); a future task could add native arXiv search if Semantic
  Scholar's `externalIds.ArXiv` and OpenAlex's OA locations prove insufficient in practice.

## References

- Plan: `specs/110_add_discover_multi_provider_fallback/plans/01_multi-provider-tier3-fallback.md`
- Research: `specs/110_add_discover_multi_provider_fallback/reports/01_multi-provider-tier3-fallback.md`
- New context doc: `agent-system/extensions/literature/context/project/literature/domain/tier3-provider-fallback.md`
- Test suite: `agent-system/extensions/literature/scripts/tests/test-literature-discover-tier3.sh`
