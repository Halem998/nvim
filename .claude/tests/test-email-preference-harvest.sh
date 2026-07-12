#!/usr/bin/env bash
# test-email-preference-harvest.sh — Assertions for email-preference-harvest.sh and the
# memory-retrieve.sh topic-prefix cross-contamination filter (task 822).
#
# USAGE:
#   bash .claude/tests/test-email-preference-harvest.sh
#
# EXITS:
#   0 — All tests pass
#   1 — One or more tests failed
#
# NOTES:
#   - Tests must be run from the project root (where .claude/ is a direct child)
#   - Pure-bash assertions in the style of test-command-route-skill.sh (no bats/spec framework)
#   - Exercises .claude/scripts/email-preference-harvest.sh subcommands and a synthetic
#     .memory/memory-index.json fixture passed to memory-retrieve.sh — no live vault mutation

set -uo pipefail

PASS=0
FAIL=0
FAILURES=""

HARVEST_SCRIPT=".claude/scripts/email-preference-harvest.sh"
RETRIEVE_SCRIPT=".claude/scripts/memory-retrieve.sh"

# ---------------------------------------------------------------------------
# Helper: assert_eq <test_name> <expected> <actual>
# ---------------------------------------------------------------------------
assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$expected" = "$actual" ]; then
    echo "  PASS [$test_name]: $actual"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL [$test_name]: expected='$expected' actual='$actual'"
  fi
}

# ---------------------------------------------------------------------------
# Helper: assert_contains <test_name> <needle> <haystack>
# ---------------------------------------------------------------------------
assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"

  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS [$test_name]: found '$needle'"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES="$FAILURES\n  FAIL [$test_name]: expected to find '$needle' in: $haystack"
  fi
}

echo "Running email-preference-harvest.sh + memory-retrieve.sh filter tests..."
echo ""

# ---------------------------------------------------------------------------
# Section 1: Normalization edge cases (design §2.3, real-sample-verified)
# ---------------------------------------------------------------------------
echo "=== Normalization edge cases ==="

# Freemail multiplicity: two distinct gmail addresses must yield two distinct keys
# (never rolled up, even though both share the gmail.com domain).
key1=$(bash "$HARVEST_SCRIPT" identity "benbrastmckie@gmail.com" | jq -r '.key')
key2=$(bash "$HARVEST_SCRIPT" identity "99nicky@gmail.com" | jq -r '.key')
if [ "$key1" != "$key2" ]; then
  echo "  PASS [freemail multiplicity]: distinct keys for distinct gmail addresses ($key1 != $key2)"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAILURES="$FAILURES\n  FAIL [freemail multiplicity]: expected distinct keys, both got '$key1'"
fi
freemail_flag=$(bash "$HARVEST_SCRIPT" identity "benbrastmckie@gmail.com" | jq -r '.freemail')
assert_eq "freemail flag true for gmail.com" "true" "$freemail_flag"

# Sender-side plus-addressing strip: invoice+statements@stripe.com -> invoice@stripe.com
local_part=$(bash "$HARVEST_SCRIPT" normalize "invoice+statements@stripe.com" | jq -r '.local_part')
assert_eq "plus-addressing strip" "invoice" "$local_part"
bare=$(bash "$HARVEST_SCRIPT" normalize "invoice+statements+acct_1RszBH2StuRr0lbX@stripe.com" | jq -r '.local_part')
assert_eq "plus-addressing strip (multi-plus)" "invoice" "$bare"

# DMARC "via" relay keying: key resolves to the relay/list address, not the display name.
via_domain=$(bash "$HARVEST_SCRIPT" normalize '"Marta Bienkiewicz" via guaranteed-safe-ai <guaranteed-safe-ai@googlegroups.com>' | jq -r '.domain')
via_local=$(bash "$HARVEST_SCRIPT" normalize '"Marta Bienkiewicz" via guaranteed-safe-ai <guaranteed-safe-ai@googlegroups.com>' | jq -r '.local_part')
assert_eq "DMARC via-relay domain" "googlegroups.com" "$via_domain"
assert_eq "DMARC via-relay local-part" "guaranteed-safe-ai" "$via_local"

# Case-insensitivity: CorrAdmin1@spi-global.com and corradmin1@spi-global.com must normalize
# to the same bare address.
addr_upper=$(bash "$HARVEST_SCRIPT" normalize "CorrAdmin1@spi-global.com" | jq -r '.bare_address')
addr_lower=$(bash "$HARVEST_SCRIPT" normalize "corradmin1@spi-global.com" | jq -r '.bare_address')
assert_eq "case-insensitivity normalizes to same address" "$addr_lower" "$addr_upper"

# Redaction: domain stays plaintext, local-part is a 12-char hex hash (never plaintext).
identity_json=$(bash "$HARVEST_SCRIPT" identity "invoice@stripe.com")
redacted_domain=$(echo "$identity_json" | jq -r '.domain')
redacted_hash=$(echo "$identity_json" | jq -r '.hash')
assert_eq "redaction keeps domain plaintext" "stripe.com" "$redacted_domain"
if echo "$redacted_hash" | grep -qE '^[0-9a-f]{12}$'; then
  echo "  PASS [redaction hash format]: $redacted_hash"
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  FAILURES="$FAILURES\n  FAIL [redaction hash format]: expected 12-char hex, got '$redacted_hash'"
fi

# Non-freemail domain rollup (--rollup): key becomes the bare domain, no hash.
rollup_json=$(bash "$HARVEST_SCRIPT" identity "invoice@stripe.com" --rollup)
assert_eq "non-freemail rollup key" "stripe.com" "$(echo "$rollup_json" | jq -r '.key')"
assert_eq "non-freemail rollup hash is null" "null" "$(echo "$rollup_json" | jq -r '.hash')"

# Freemail carve-out: --rollup on a freemail domain must NOT roll up.
freemail_rollup_json=$(bash "$HARVEST_SCRIPT" identity "someone@gmail.com" --rollup)
assert_eq "freemail carve-out ignores --rollup" "false" "$(echo "$freemail_rollup_json" | jq -r '.rolled_up')"

echo ""

# ---------------------------------------------------------------------------
# Section 2: CREATE/EXTEND/UPDATE tally transitions (design §4.3)
# ---------------------------------------------------------------------------
echo "=== Tally CREATE/EXTEND/UPDATE transitions ==="

# CREATE: no existing tally -> first sighting.
create_result=$(bash "$HARVEST_SCRIPT" tally-op "null" "archive" 5 "2026-07-01")
assert_eq "CREATE operation label" "CREATE" "$(echo "$create_result" | jq -r '.operation')"
assert_eq "CREATE archive_count" "5" "$(echo "$create_result" | jq -r '.tally.archive_count')"
assert_eq "CREATE delete_count stays 0" "0" "$(echo "$create_result" | jq -r '.tally.delete_count')"
assert_eq "CREATE keep_count stays 0" "0" "$(echo "$create_result" | jq -r '.tally.keep_count')"

create_tally=$(echo "$create_result" | jq -c '.tally')

# EXTEND: round action matches the stored dominant action -> bump the matching counter.
extend_result=$(bash "$HARVEST_SCRIPT" tally-op "$create_tally" "archive" 3 "2026-07-05")
assert_eq "EXTEND operation label" "EXTEND" "$(echo "$extend_result" | jq -r '.operation')"
assert_eq "EXTEND bumps matching counter" "8" "$(echo "$extend_result" | jq -r '.tally.archive_count')"
assert_eq "EXTEND updates last_seen" "2026-07-05" "$(echo "$extend_result" | jq -r '.tally.archive_last_seen')"

extend_tally=$(echo "$extend_result" | jq -c '.tally')

# UPDATE: round action contradicts the stored dominant action -> increment the OPPOSITE
# counter, never reset the matching (dominant) one.
update_result=$(bash "$HARVEST_SCRIPT" tally-op "$extend_tally" "keep" 4 "2026-07-08")
assert_eq "UPDATE operation label" "UPDATE" "$(echo "$update_result" | jq -r '.operation')"
assert_eq "UPDATE bumps opposite counter" "4" "$(echo "$update_result" | jq -r '.tally.keep_count')"
assert_eq "UPDATE never resets matching counter" "8" "$(echo "$update_result" | jq -r '.tally.archive_count')"
update_dominant=$(bash "$HARVEST_SCRIPT" dominant "$(echo "$update_result" | jq -c '.tally')")
assert_eq "dominant unchanged (8 archive > 4 keep)" "archive" "$update_dominant"

# A further contradicting UPDATE that crosses the count can flip the derived dominant action.
update_tally=$(echo "$update_result" | jq -c '.tally')
flip_result=$(bash "$HARVEST_SCRIPT" tally-op "$update_tally" "keep" 6 "2026-07-10")
assert_eq "flip UPDATE never resets matching counter" "8" "$(echo "$flip_result" | jq -r '.tally.archive_count')"
assert_eq "flip UPDATE bumps opposite counter to exceed" "10" "$(echo "$flip_result" | jq -r '.tally.keep_count')"
flip_dominant=$(bash "$HARVEST_SCRIPT" dominant "$(echo "$flip_result" | jq -c '.tally')")
assert_eq "dominant flips (10 keep > 8 archive)" "keep" "$flip_dominant"

echo ""

# ---------------------------------------------------------------------------
# Section 3: Evidentiary threshold (design §1.4)
# ---------------------------------------------------------------------------
echo "=== Evidentiary threshold ==="

uniform_batch_threshold=$(bash "$HARVEST_SCRIPT" threshold "$create_tally" "true")
assert_eq "uniform-batch always meets threshold" "true" "$uniform_batch_threshold"

rolling_met=$(bash "$HARVEST_SCRIPT" threshold "$extend_tally" "false")
assert_eq "rolling N>=3 at >=80% met (archive=8/8=100%)" "true" "$rolling_met"

rolling_not_met=$(bash "$HARVEST_SCRIPT" threshold "$update_tally" "false")
assert_eq "rolling threshold not met (archive=8/12=67%)" "false" "$rolling_not_met"

echo ""

# ---------------------------------------------------------------------------
# Section 4: Exact-key dedup lookup (design §4.1)
# ---------------------------------------------------------------------------
echo "=== Exact-key dedup lookup ==="

FIXTURE_DIR=$(mktemp -d)
trap 'rm -rf "$FIXTURE_DIR"' EXIT

cat > "$FIXTURE_DIR/memory-index.json" << 'EOF'
{
  "version": "1.0.0",
  "entry_count": 1,
  "entries": [
    {"id": "MEM-email-pref-stripe", "topic": "email/preferences/gmail/stripe.com", "summary": "test fixture"}
  ]
}
EOF

dedup_hit=$(bash "$HARVEST_SCRIPT" dedup "$FIXTURE_DIR/memory-index.json" "email/preferences/gmail/stripe.com")
assert_eq "dedup hit returns matched entry id" "MEM-email-pref-stripe" "$(echo "$dedup_hit" | jq -r '.id')"

dedup_miss=$(bash "$HARVEST_SCRIPT" dedup "$FIXTURE_DIR/memory-index.json" "email/preferences/gmail/never-seen.com")
assert_eq "dedup miss returns null (falls through to CREATE)" "null" "$dedup_miss"

dedup_missing_index=$(bash "$HARVEST_SCRIPT" dedup "$FIXTURE_DIR/no-such-file.json" "email/preferences/gmail/stripe.com")
assert_eq "dedup against missing index file returns null" "null" "$dedup_missing_index"

echo ""

# ---------------------------------------------------------------------------
# Section 5: memory-retrieve.sh topic-prefix cross-contamination exclusion (design §5.2)
# ---------------------------------------------------------------------------
echo "=== memory-retrieve.sh topic-prefix exclusion ==="

RETRIEVE_FIXTURE=$(mktemp -d)
mkdir -p "$RETRIEVE_FIXTURE/.memory/10-Memories" "$RETRIEVE_FIXTURE/.claude/scripts"
cp "$RETRIEVE_SCRIPT" "$RETRIEVE_FIXTURE/.claude/scripts/memory-retrieve.sh"

cat > "$RETRIEVE_FIXTURE/.memory/memory-index.json" << 'EOF'
{
  "version": "1.0.0",
  "entry_count": 2,
  "entries": [
    {"id": "MEM-general-fixture", "path": ".memory/10-Memories/MEM-general-fixture.md", "title": "General fixture", "summary": "general", "topic": "general/patterns", "keywords": ["harvestkeyword", "fixture"], "token_count": 50, "retrieval_count": 0},
    {"id": "MEM-emailpref-fixture", "path": ".memory/10-Memories/MEM-emailpref-fixture.md", "title": "Email preference fixture", "summary": "pref", "topic": "email/preferences/gmail/fixture.com", "keywords": ["harvestkeyword", "fixture"], "token_count": 50, "retrieval_count": 0}
  ]
}
EOF
echo "general fixture content" > "$RETRIEVE_FIXTURE/.memory/10-Memories/MEM-general-fixture.md"
echo "email preference fixture content" > "$RETRIEVE_FIXTURE/.memory/10-Memories/MEM-emailpref-fixture.md"

general_output=$(cd "$RETRIEVE_FIXTURE" && bash .claude/scripts/memory-retrieve.sh "harvestkeyword fixture task" "general" 2>/dev/null || true)
if echo "$general_output" | grep -qF "Email preference fixture"; then
  FAIL=$((FAIL + 1))
  FAILURES="$FAILURES\n  FAIL [task_type=general excludes email/preferences/*]: leaked into output"
else
  echo "  PASS [task_type=general excludes email/preferences/*]: not present in output"
  PASS=$((PASS + 1))
fi
assert_contains "task_type=general still includes general memory" "General fixture" "$general_output"

# Reset retrieval_count mutated by the general-mode call above before the email-mode call.
cat > "$RETRIEVE_FIXTURE/.memory/memory-index.json" << 'EOF'
{
  "version": "1.0.0",
  "entry_count": 2,
  "entries": [
    {"id": "MEM-general-fixture", "path": ".memory/10-Memories/MEM-general-fixture.md", "title": "General fixture", "summary": "general", "topic": "general/patterns", "keywords": ["harvestkeyword", "fixture"], "token_count": 50, "retrieval_count": 0},
    {"id": "MEM-emailpref-fixture", "path": ".memory/10-Memories/MEM-emailpref-fixture.md", "title": "Email preference fixture", "summary": "pref", "topic": "email/preferences/gmail/fixture.com", "keywords": ["harvestkeyword", "fixture"], "token_count": 50, "retrieval_count": 0}
  ]
}
EOF

email_output=$(cd "$RETRIEVE_FIXTURE" && bash .claude/scripts/memory-retrieve.sh "harvestkeyword fixture task" "email" 2>/dev/null || true)
assert_contains "task_type=email includes email/preferences/* (future carve-out)" "Email preference fixture" "$email_output"

rm -rf "$RETRIEVE_FIXTURE"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  printf "%b\n" "$FAILURES"
  exit 1
fi

echo ""
echo "All tests passed."
exit 0
