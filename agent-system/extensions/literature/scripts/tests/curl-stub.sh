#!/usr/bin/env bash
# curl-stub.sh — PATH-shadowing curl stub for literature-discover.sh Tier 3 tests.
#
# Dispatches canned HTTP responses by request host, keyed off per-host environment
# variables, so the Tier 3 multi-provider fallback chain can be driven deterministically
# without any real network call. Install by copying or symlinking this file as `curl`
# into a scratch directory prepended to PATH before invoking literature-discover.sh (or
# any other script under test) — literature-discover.sh calls bare `curl`, never an
# absolute path or `command curl`, so a PATH-shadowing stub actually intercepts it.
#
# Host -> env var mapping (all optional; default code is 200, default body is the
# matching fixture under ./fixtures/):
#   api.semanticscholar.org   CURL_STUB_SS_CODE        / CURL_STUB_SS_BODY
#   api.openalex.org          CURL_STUB_OPENALEX_CODE  / CURL_STUB_OPENALEX_BODY
#   api.crossref.org          CURL_STUB_CROSSREF_CODE  / CURL_STUB_CROSSREF_BODY
#   api.unpaywall.org         CURL_STUB_UNPAYWALL_CODE / CURL_STUB_UNPAYWALL_BODY
#
# A *_CODE value of "curl_fail" simulates a curl transport failure: nonzero exit
# (28, curl's own timeout code), no stdout at all — this is how a stubbed scenario
# exercises the `curl_exit` failure branch, distinct from a stubbed non-200 response.
#
# CURL_STUB_LOG, if set, has one line appended per invocation: "URL=<url> ARGS=<argv>"
# — used by tests asserting a header was (or was not) sent, e.g. S2_API_KEY's
# x-api-key header.
#
# Recognizes the two curl invocation shapes literature-discover.sh uses:
#   curl -s -w '\n%{http_code}' --max-time N "$url"   -> body, then a literal
#                                                         newline, then the code
#   curl -s --max-time N "$url"                        -> body only (Unpaywall path)
# Any other flag is accepted and ignored; only -w's format string and the URL
# argument affect this stub's output shape.

set -uo pipefail

FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fixtures"

url=""
want_code_suffix=false
args=("$@")
argc=${#args[@]}

i=0
while [ "$i" -lt "$argc" ]; do
  arg="${args[$i]}"
  case "$arg" in
    -w)
      i=$((i + 1))
      wfmt="${args[$i]:-}"
      if [[ "$wfmt" == *"%{http_code}"* ]]; then
        want_code_suffix=true
      fi
      ;;
    http://*|https://*)
      url="$arg"
      ;;
  esac
  i=$((i + 1))
done

if [ -n "${CURL_STUB_LOG:-}" ]; then
  printf 'URL=%s ARGS=%s\n' "$url" "${args[*]}" >> "$CURL_STUB_LOG"
fi

code=""
body_file=""

case "$url" in
  *api.semanticscholar.org*)
    code="${CURL_STUB_SS_CODE:-200}"
    body_file="${CURL_STUB_SS_BODY:-$FIXTURES_DIR/tier3-semanticscholar-200.json}"
    ;;
  *api.openalex.org*)
    code="${CURL_STUB_OPENALEX_CODE:-200}"
    body_file="${CURL_STUB_OPENALEX_BODY:-$FIXTURES_DIR/tier3-openalex-200.json}"
    ;;
  *api.crossref.org*)
    code="${CURL_STUB_CROSSREF_CODE:-200}"
    body_file="${CURL_STUB_CROSSREF_BODY:-$FIXTURES_DIR/tier3-crossref-200.json}"
    ;;
  *api.unpaywall.org*)
    code="${CURL_STUB_UNPAYWALL_CODE:-200}"
    body_file="${CURL_STUB_UNPAYWALL_BODY:-$FIXTURES_DIR/tier3-unpaywall-200.json}"
    ;;
  *)
    # Unknown/unexpected host: fail loudly as a transport error rather than
    # silently serving the wrong fixture.
    exit 7
    ;;
esac

if [ "$code" = "curl_fail" ]; then
  exit 28
fi

body=""
if [ -f "$body_file" ]; then
  body="$(cat "$body_file")"
fi

if [ "$want_code_suffix" = "true" ]; then
  printf '%s\n%s' "$body" "$code"
else
  printf '%s' "$body"
fi
