#!/usr/bin/env bash
# test-literature-discover-tier3.sh - Regression and scenario tests for
# literature-discover.sh's Tier 3 multi-provider fallback chain (Semantic
# Scholar -> OpenAlex -> Crossref), driven entirely by the PATH-shadowing
# curl-stub.sh in this same directory. No real network access is used or
# required.
#
# Scenarios (pass one or more names as argv; default is "all"):
#   stub-intercept       - the stub actually intercepts curl (no network dependency,
#                           reproducible across two consecutive runs)
#   golden-baseline       - capture (CAPTURE_BASELINE=1) or diff the pre-refactor
#                           Semantic Scholar output against
#                           fixtures/tier3-golden-baseline.json (Phase 3's regression gate)
#   header-check          - S2_API_KEY sent as x-api-key when set, absent when unset
#   schema-openalex        - OpenAlex-sourced record passes the 9-key Tier 3 schema,
#                           with a bare-DOI-derived doc_id (no https_/doi_org_ fragment)
#   schema-crossref        - Crossref-sourced record passes the 9-key Tier 3 schema
#   docid-prefix-grep      - no oa_/cr_ doc_id prefix anywhere in the script
#   healthy                - S2 200 with results -> no TIER3_STATUS line, byte-identical
#                           to golden baseline, no OpenAlex/Crossref request logged
#   zero-result            - S2 200 empty .data -> no TIER3_STATUS line, no fallback request
#   s2-fail-openalex       - S2 429, OpenAlex 200 -> zero TIER3_STATUS lines, record
#                           sourced from the OpenAlex fixture
#   all-fail               - all three providers fail -> exactly one aggregated
#                           `TIER3_STATUS: FAILED` line, script exits normally
#   quota-zero              - DISCOVER_LIMIT small enough that TIER3_QUOTA is 0 -> no
#                           TIER3_STATUS line, no provider request at all
#   e2e-ingest              - S2 429 -> OpenAlex-sourced schema-valid record ->
#                           literature-ingest-online.sh --record ... --dry-run does not
#                           exit 64
#
# Usage:
#   test-literature-discover-tier3.sh [scenario ...]
#   CAPTURE_BASELINE=1 test-literature-discover-tier3.sh golden-baseline   # (re-)capture
#
# All test runs use a scratch mktemp LITERATURE_DIR (no index.json / zotero-library.json)
# so only Tier 3 ever produces a result; they never touch ~/Projects/Literature.
#
# Exit codes: 0 - all run scenarios passed; 1 - a scenario failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
DISCOVER_SH="$SCRIPT_DIR/literature-discover.sh"
INGEST_SH="$SCRIPT_DIR/literature-ingest-online.sh"
CURL_STUB="$TESTS_DIR/curl-stub.sh"
FIXTURES_DIR="$TESTS_DIR/fixtures"
BASELINE_FILE="$FIXTURES_DIR/tier3-golden-baseline.json"

PASS=0
FAIL=0

t_log() { echo "[test-tier3] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -f "$DISCOVER_SH" ]; then
  t_log "literature-discover.sh not found at $DISCOVER_SH"
  exit 1
fi

# ---------------------------------------------------------------------------
# Scratch PATH dir with curl-stub.sh installed as `curl`, prepended to PATH
# ---------------------------------------------------------------------------
STUB_PATH_DIR="$(mktemp -d)"
LIT_SCRATCH_DIR="$(mktemp -d)"
cp "$CURL_STUB" "$STUB_PATH_DIR/curl"
chmod +x "$STUB_PATH_DIR/curl"

cleanup() {
  rm -rf "$STUB_PATH_DIR" "$LIT_SCRATCH_DIR"
}
trap cleanup EXIT

# run_discover QUERY... -- invokes literature-discover.sh with the stub first on
# PATH and an empty scratch LITERATURE_DIR (Tier 1/2 both no-op). Reads
# CURL_STUB_* / DISCOVER_LIMIT / S2_API_KEY / OPENALEX_API_KEY from the caller's
# environment (already exported before calling). Sets globals: OUT, ERR, RC.
run_discover() {
  local out err rc
  out="$(mktemp)"; err="$(mktemp)"
  PATH="$STUB_PATH_DIR:$PATH" LITERATURE_DIR="$LIT_SCRATCH_DIR" \
    "$DISCOVER_SH" "$@" >"$out" 2>"$err"
  rc=$?
  OUT="$(cat "$out")"
  ERR="$(cat "$err")"
  RC=$rc
  rm -f "$out" "$err"
}

# ---------------------------------------------------------------------------
# stub-intercept
# ---------------------------------------------------------------------------
t_stub_intercept() {
  local out1 out2
  CURL_STUB_SS_CODE=200 CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    run_discover "stub intercept probe"
  out1="$OUT"
  if [ "$RC" -ne 0 ] || [ -z "$out1" ]; then
    t_fail "stub-intercept: first run produced no output (rc=$RC)"
    return
  fi
  CURL_STUB_SS_CODE=200 CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    run_discover "stub intercept probe"
  out2="$OUT"
  if [ "$out1" = "$out2" ]; then
    t_pass "stub-intercept: two consecutive stubbed runs are reproducible, no network dependency"
  else
    t_fail "stub-intercept: consecutive stubbed runs diverged"
  fi
  if echo "$out1" | jq -e '.[] | select(.tier == 3)' >/dev/null 2>&1; then
    t_pass "stub-intercept: output is a valid JSON array with a tier==3 record"
  else
    t_fail "stub-intercept: no tier==3 record in stubbed output"
  fi
}

# ---------------------------------------------------------------------------
# golden-baseline
# ---------------------------------------------------------------------------
t_golden_baseline() {
  CURL_STUB_SS_CODE=200 CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    run_discover "golden baseline query"

  if [ "${CAPTURE_BASELINE:-0}" = "1" ]; then
    printf '%s' "$OUT" > "$BASELINE_FILE"
    t_pass "golden-baseline: captured to $BASELINE_FILE"
    return
  fi

  if [ ! -f "$BASELINE_FILE" ]; then
    t_fail "golden-baseline: no baseline file at $BASELINE_FILE (run with CAPTURE_BASELINE=1 first)"
    return
  fi

  local baseline
  baseline="$(cat "$BASELINE_FILE")"
  if [ "$OUT" = "$baseline" ]; then
    t_pass "golden-baseline: current output is byte-identical to the pre-refactor baseline"
  else
    t_fail "golden-baseline: current output DIFFERS from the pre-refactor baseline"
    diff <(printf '%s' "$baseline") <(printf '%s' "$OUT") >&2 || true
  fi
}

# ---------------------------------------------------------------------------
# header-check
# ---------------------------------------------------------------------------
t_header_check() {
  local log_file
  log_file="$(mktemp)"

  CURL_STUB_LOG="$log_file" CURL_STUB_SS_CODE=200 \
    CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    S2_API_KEY="dummy-test-key" \
    run_discover "header check query"

  if grep -qi 'x-api-key: dummy-test-key' "$log_file"; then
    t_pass "header-check: x-api-key header present when S2_API_KEY is set"
  else
    t_fail "header-check: x-api-key header NOT found when S2_API_KEY is set"
  fi
  : > "$log_file"

  CURL_STUB_LOG="$log_file" CURL_STUB_SS_CODE=200 \
    CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    run_discover "header check query unset"

  if grep -qi 'x-api-key' "$log_file"; then
    t_fail "header-check: x-api-key header present when S2_API_KEY is unset"
  else
    t_pass "header-check: no x-api-key header when S2_API_KEY is unset"
  fi
  rm -f "$log_file"
}

# ---------------------------------------------------------------------------
# _run_provider_direct FN QUERY REMAINING -- invokes a single tier3_try_*
# provider function directly (not through tier3_search()'s chain), so Phase 4
# can verify each provider function in isolation before Phase 5 wires them
# into the ordered chain. Extracts the function definitions (urlencode()
# through the end of tier3_try_crossref(), stopping just before
# tier3_search()) into a scratch script and runs it with the stub on PATH.
# Sets globals: PROVIDER_OUT (the resulting $RESULTS JSON array), PROVIDER_RC.
# ---------------------------------------------------------------------------
_run_provider_direct() {
  local fn="$1" query="$2" remaining="$3"
  local script_file
  script_file="$(mktemp)"
  {
    echo 'set -uo pipefail'
    echo 'SEARCH_TERMS="$1"'
    sed -n '/^urlencode() {/,/^tier3_search() {/p' "$DISCOVER_SH" | sed '$d'
    echo "$fn \"\$1\" \"\$2\""
    echo '_direct_rc=$?'
    echo 'echo "$RESULTS"'
    echo 'exit $_direct_rc'
  } > "$script_file"

  PROVIDER_OUT=$(PATH="$STUB_PATH_DIR:$PATH" \
    SCRIPT_DIR="$SCRIPT_DIR" \
    USER_EMAIL="${USER_EMAIL:-benbrastmckie@gmail.com}" \
    OPENALEX_API_KEY="${OPENALEX_API_KEY:-}" S2_API_KEY="${S2_API_KEY:-}" \
    bash "$script_file" "$query" "$remaining" 2>/dev/null)
  PROVIDER_RC=$?
  rm -f "$script_file"
}

# ---------------------------------------------------------------------------
# schema assertion shared helper
# ---------------------------------------------------------------------------
_assert_schema() {
  local json="$1" label="$2"
  local ok
  ok=$(echo "$json" | jq -e '
    (has("title") and has("authors") and has("year") and has("doc_id")
     and has("status") and has("tier") and has("doi") and has("arxiv_id")
     and has("pdf_url"))
    and (.tier == 3)
    and (.status == "open_access" or .status == "paywall")
  ' 2>/dev/null) || ok="false"
  if [ "$ok" = "true" ]; then
    t_pass "$label: record passes 9-key Tier 3 schema"
  else
    t_fail "$label: record FAILS schema assertion: $json"
  fi
}

# ---------------------------------------------------------------------------
# schema-openalex -- drives tier3_try_openalex() directly (Phase 4 verifies
# each provider function in isolation; Phase 5 wires the chain that lets a
# real S2-fails run reach OpenAlex through tier3_search() itself, exercised
# separately by the s2-fail-openalex scenario).
# ---------------------------------------------------------------------------
t_schema_openalex() {
  CURL_STUB_OPENALEX_CODE=200 CURL_STUB_OPENALEX_BODY="$FIXTURES_DIR/tier3-openalex-200.json" \
    _run_provider_direct tier3_try_openalex "openalex schema query" 10
  if [ "$PROVIDER_RC" -ne 0 ]; then
    t_fail "schema-openalex: tier3_try_openalex returned non-zero on a stubbed 200: $PROVIDER_OUT"
    return
  fi

  local rec
  rec=$(echo "$PROVIDER_OUT" | jq -c '.[0]' 2>/dev/null)
  if [ -z "$rec" ] || [ "$rec" = "null" ]; then
    t_fail "schema-openalex: no record produced: $PROVIDER_OUT"
    return
  fi
  _assert_schema "$rec" "schema-openalex"

  local doc_id
  doc_id=$(echo "$rec" | jq -r '.doc_id')
  case "$doc_id" in
    *https_*|*doi_org_*)
      t_fail "schema-openalex: doc_id retains prefixed-DOI fragment: $doc_id"
      ;;
    *)
      t_pass "schema-openalex: doc_id is bare-DOI-derived: $doc_id"
      ;;
  esac

  # 200-with-zero-results returns 0; a stubbed 429 returns non-zero.
  CURL_STUB_OPENALEX_CODE=200 CURL_STUB_OPENALEX_BODY="$FIXTURES_DIR/tier3-semanticscholar-empty-200.json" \
    _run_provider_direct tier3_try_openalex "openalex zero result query" 10
  if [ "$PROVIDER_RC" -eq 0 ]; then
    t_pass "schema-openalex: returns 0 on a stubbed 200-with-zero-results"
  else
    t_fail "schema-openalex: returned non-zero on a stubbed 200-with-zero-results"
  fi

  CURL_STUB_OPENALEX_CODE=429 _run_provider_direct tier3_try_openalex "openalex 429 query" 10
  if [ "$PROVIDER_RC" -ne 0 ]; then
    t_pass "schema-openalex: returns non-zero on a stubbed 429"
  else
    t_fail "schema-openalex: returned 0 on a stubbed 429"
  fi
}

# ---------------------------------------------------------------------------
# schema-crossref -- drives tier3_try_crossref() directly, same rationale.
# ---------------------------------------------------------------------------
t_schema_crossref() {
  CURL_STUB_CROSSREF_CODE=200 CURL_STUB_CROSSREF_BODY="$FIXTURES_DIR/tier3-crossref-200.json" \
    CURL_STUB_UNPAYWALL_CODE=200 CURL_STUB_UNPAYWALL_BODY="$FIXTURES_DIR/tier3-unpaywall-200.json" \
    _run_provider_direct tier3_try_crossref "crossref schema query" 10
  if [ "$PROVIDER_RC" -ne 0 ]; then
    t_fail "schema-crossref: tier3_try_crossref returned non-zero on a stubbed 200: $PROVIDER_OUT"
    return
  fi

  local rec
  rec=$(echo "$PROVIDER_OUT" | jq -c '.[0]' 2>/dev/null)
  if [ -z "$rec" ] || [ "$rec" = "null" ]; then
    t_fail "schema-crossref: no record produced: $PROVIDER_OUT"
    return
  fi
  _assert_schema "$rec" "schema-crossref"

  CURL_STUB_CROSSREF_CODE=429 _run_provider_direct tier3_try_crossref "crossref 429 query" 10
  if [ "$PROVIDER_RC" -ne 0 ]; then
    t_pass "schema-crossref: returns non-zero on a stubbed 429"
  else
    t_fail "schema-crossref: returned 0 on a stubbed 429"
  fi
}

# ---------------------------------------------------------------------------
# docid-prefix-grep
# ---------------------------------------------------------------------------
t_docid_prefix_grep() {
  if grep -nE 'doc_id="(oa|cr)_' "$DISCOVER_SH" >/dev/null 2>&1; then
    t_fail "docid-prefix-grep: found a forbidden oa_/cr_ doc_id prefix in $DISCOVER_SH"
  else
    t_pass "docid-prefix-grep: no oa_/cr_ doc_id prefix in $DISCOVER_SH"
  fi
}

# ---------------------------------------------------------------------------
# healthy
# ---------------------------------------------------------------------------
t_healthy() {
  local log_file
  log_file="$(mktemp)"
  CURL_STUB_LOG="$log_file" CURL_STUB_SS_CODE=200 \
    CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-200.json" \
    run_discover "healthy query"

  if [ -n "$ERR" ] && echo "$ERR" | grep -q 'TIER3_STATUS'; then
    t_fail "healthy: unexpected TIER3_STATUS line on stderr: $ERR"
  else
    t_pass "healthy: no TIER3_STATUS line on stderr"
  fi

  if [ -f "$BASELINE_FILE" ]; then
    local baseline
    baseline="$(cat "$BASELINE_FILE")"
    if [ "$OUT" = "$baseline" ]; then
      t_pass "healthy: output byte-identical to golden baseline"
    else
      t_fail "healthy: output diverged from golden baseline"
    fi
  fi

  if grep -qE 'api\.(openalex|crossref)\.org' "$log_file"; then
    t_fail "healthy: OpenAlex/Crossref request logged despite S2 200 with results"
  else
    t_pass "healthy: no OpenAlex/Crossref request logged"
  fi
  rm -f "$log_file"
}

# ---------------------------------------------------------------------------
# zero-result
# ---------------------------------------------------------------------------
t_zero_result() {
  local log_file
  log_file="$(mktemp)"
  CURL_STUB_LOG="$log_file" CURL_STUB_SS_CODE=200 \
    CURL_STUB_SS_BODY="$FIXTURES_DIR/tier3-semanticscholar-empty-200.json" \
    run_discover "zero result query"

  if echo "$ERR" | grep -q 'TIER3_STATUS'; then
    t_fail "zero-result: unexpected TIER3_STATUS line on a legitimate zero-result 200"
  else
    t_pass "zero-result: no TIER3_STATUS line on a legitimate zero-result 200"
  fi

  if grep -qE 'api\.(openalex|crossref)\.org' "$log_file"; then
    t_fail "zero-result: chain advanced past a zero-result 200"
  else
    t_pass "zero-result: chain did not advance past a zero-result 200"
  fi
  rm -f "$log_file"
}

# ---------------------------------------------------------------------------
# s2-fail-openalex
# ---------------------------------------------------------------------------
t_s2_fail_openalex() {
  CURL_STUB_SS_CODE=429 CURL_STUB_OPENALEX_CODE=200 \
    CURL_STUB_OPENALEX_BODY="$FIXTURES_DIR/tier3-openalex-200.json" \
    run_discover "s2 fail openalex answers query"

  if echo "$ERR" | grep -q 'TIER3_STATUS'; then
    t_fail "s2-fail-openalex: unexpected TIER3_STATUS line despite OpenAlex answering"
  else
    t_pass "s2-fail-openalex: zero TIER3_STATUS lines"
  fi

  if echo "$OUT" | jq -e '.[] | select(.tier == 3 and (.title | contains("OpenAlex")))' >/dev/null 2>&1; then
    t_pass "s2-fail-openalex: record sourced from the OpenAlex fixture"
  else
    t_fail "s2-fail-openalex: no OpenAlex-sourced record found: $OUT"
  fi
}

# ---------------------------------------------------------------------------
# all-fail
# ---------------------------------------------------------------------------
t_all_fail() {
  CURL_STUB_SS_CODE=curl_fail CURL_STUB_OPENALEX_CODE=curl_fail \
    CURL_STUB_CROSSREF_CODE=curl_fail \
    run_discover "all fail query"

  local n
  n=$(echo "$ERR" | grep -c 'TIER3_STATUS: FAILED' || true)
  if [ "$n" -eq 1 ]; then
    t_pass "all-fail: exactly one aggregated TIER3_STATUS: FAILED line"
  else
    t_fail "all-fail: expected exactly one TIER3_STATUS: FAILED line, got $n: $ERR"
  fi

  # commands/literature.md's two exact consumer expressions
  if echo "$ERR" | grep -q 'TIER3_STATUS: FAILED'; then
    t_pass "all-fail: consumer grep 'TIER3_STATUS: FAILED' succeeds"
  else
    t_fail "all-fail: consumer grep 'TIER3_STATUS: FAILED' FAILED"
  fi
  local tok
  tok=$(echo "$ERR" | grep -o 'http_code=[^ ]*')
  local tok_count
  tok_count=$(echo "$tok" | grep -c . || true)
  if [ "$tok_count" -eq 1 ] && [ -n "$tok" ]; then
    t_pass "all-fail: consumer grep 'http_code=[^ ]*' yields exactly one space-free token: $tok"
  else
    t_fail "all-fail: consumer grep for http_code= token did not yield exactly one token: '$tok'"
  fi

  # RC comes from `|| true`-wrapped tier3_search in the discover script, so
  # the overall script must still exit normally (0 sources found -> exit 1,
  # NOT aborted by set -e). Any exit code other than 0/1 indicates abort.
  if [ "$RC" -eq 0 ] || [ "$RC" -eq 1 ]; then
    t_pass "all-fail: script exited normally (rc=$RC), not aborted by set -e"
  else
    t_fail "all-fail: script exited abnormally (rc=$RC)"
  fi
}

# ---------------------------------------------------------------------------
# quota-zero
# ---------------------------------------------------------------------------
t_quota_zero() {
  local log_file
  log_file="$(mktemp)"
  CURL_STUB_LOG="$log_file" DISCOVER_LIMIT=0 \
    run_discover "quota zero query"

  if echo "$ERR" | grep -q 'TIER3_STATUS'; then
    t_fail "quota-zero: unexpected TIER3_STATUS line on a quota-zero skip"
  else
    t_pass "quota-zero: no TIER3_STATUS line on a quota-zero skip"
  fi
  if [ -s "$log_file" ]; then
    t_fail "quota-zero: a provider request was made despite zero quota"
  else
    t_pass "quota-zero: no provider request made"
  fi
  rm -f "$log_file"
}

# ---------------------------------------------------------------------------
# e2e-ingest
# ---------------------------------------------------------------------------
t_e2e_ingest() {
  if [ ! -f "$INGEST_SH" ]; then
    t_fail "e2e-ingest: literature-ingest-online.sh not found at $INGEST_SH"
    return
  fi

  CURL_STUB_SS_CODE=429 CURL_STUB_OPENALEX_CODE=200 \
    CURL_STUB_OPENALEX_BODY="$FIXTURES_DIR/tier3-openalex-200.json" \
    run_discover "e2e ingest query"

  local rec
  rec=$(echo "$OUT" | jq -c '.[] | select(.tier == 3)' 2>/dev/null | head -n1)
  if [ -z "$rec" ]; then
    t_fail "e2e-ingest: no tier==3 record produced under S2-429/OpenAlex-200"
    return
  fi
  _assert_schema "$rec" "e2e-ingest"

  local ingest_rc
  "$INGEST_SH" --record "$rec" --dry-run >/tmp/e2e-ingest-out.$$  2>/tmp/e2e-ingest-err.$$
  ingest_rc=$?
  if [ "$ingest_rc" -eq 64 ]; then
    t_fail "e2e-ingest: literature-ingest-online.sh --dry-run exited 64 (usage/malformed-input error)"
    cat /tmp/e2e-ingest-err.$$ >&2
  else
    t_pass "e2e-ingest: literature-ingest-online.sh --dry-run did not exit 64 (rc=$ingest_rc)"
  fi
  rm -f /tmp/e2e-ingest-out.$$ /tmp/e2e-ingest-err.$$
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
declare -A SCENARIOS=(
  [stub-intercept]=t_stub_intercept
  [golden-baseline]=t_golden_baseline
  [header-check]=t_header_check
  [schema-openalex]=t_schema_openalex
  [schema-crossref]=t_schema_crossref
  [docid-prefix-grep]=t_docid_prefix_grep
  [healthy]=t_healthy
  [zero-result]=t_zero_result
  [s2-fail-openalex]=t_s2_fail_openalex
  [all-fail]=t_all_fail
  [quota-zero]=t_quota_zero
  [e2e-ingest]=t_e2e_ingest
)

ORDER=(stub-intercept golden-baseline header-check schema-openalex schema-crossref \
  docid-prefix-grep healthy zero-result s2-fail-openalex all-fail quota-zero e2e-ingest)

if [ "$#" -eq 0 ] || [ "$1" = "all" ]; then
  TO_RUN=("${ORDER[@]}")
else
  TO_RUN=("$@")
fi

for name in "${TO_RUN[@]}"; do
  fn="${SCENARIOS[$name]:-}"
  if [ -z "$fn" ]; then
    t_log "unknown scenario: $name"
    FAIL=$((FAIL + 1))
    continue
  fi
  "$fn"
done

t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
