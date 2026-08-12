#!/usr/bin/env bash
# test-handoff-dispatch-identity.sh - Regression suite for Defect A: the orchestrator-minted
# `dispatch_seq` identity gate wired into both skill-orchestrate/SKILL.md's and
# skill-orchestrate-hard/SKILL.md's Stage 5, immediately after the pre-existing mtime staleness
# check. Reproduces the observed failure mode -- a woken predecessor's late handoff write whose
# mtime falls INSIDE the successor's dispatch window, defeating an mtime-only gate -- and asserts
# the dispatch_seq comparison rejects it where mtime alone would have accepted it. See
# context/patterns/dispatch-report-not-termination.md for the shared root-cause model this test
# proves closed, and context/standards/orchestrator-runtime-files.md's "Readers MUST check
# freshness" rationale for why mtime alone is insufficient.
#
# Structural model: scripts/tests/test-loop-guard-staleness.sh (sentinel-region extraction via
# awk, mktemp -d workdir with an EXIT trap, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error, bash -n / bash -u structural checks before
# the behavioral cases). Extends that model to TWO engines: every case below runs against BOTH
# skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md's extracted regions, asserting
# identical verdicts -- this is a second, executable layer of the parity guarantee
# test-handoff-reader-parity.sh's byte-equality assertion already provides mechanically.
#
# system-defect-record.sh side-effect avoidance: the extracted region calls
# `bash .claude/scripts/system-defect-record.sh ...` via a RELATIVE path. This suite deliberately
# runs every case with cwd inside its own mktemp WORKDIR (never the repo root), so that relative
# path never resolves to the real script -- the call fails, and the region's own
# `|| echo "Note: system-defect recording failed (non-fatal)"` swallows it harmlessly, exactly as
# it does in production when the recorder is transiently unavailable. This mirrors
# test-validate-handoff-location.sh's documented "deliberately NOT copied into the workdir"
# convention for the same script. No real specs/events.jsonl write ever happens from this suite.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required SKILL.md file or sentinel marker pair not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

BASE_SKILL="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
HARD_SKILL="$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md"

for f in "$BASE_SKILL" "$HARD_SKILL"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required file not found: $f" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BEGIN_MARKER='dispatch-seq-gate:begin'
END_MARKER='dispatch-seq-gate:end'
# Widened to include the pre-existing mtime staleness check immediately above the dispatch_seq
# gate (Case 3 below exercises that check, not the dispatch_seq comparison) -- this is the same
# combined region test-handoff-reader-parity.sh's dispatch_seq-only assertion deliberately does
# NOT need, but this suite does, since it must reproduce the git-restoration hazard case too.
STALENESS_ANCHOR='# ── Staleness gate ─'

extract_combined_region() {
  local file="$1"
  awk -v anchor="$STALENESS_ANCHOR" -v endm="$END_MARKER" '
    $0 ~ anchor { flag=1 }
    flag { print }
    $0 ~ endm { if (flag) exit }
  ' "$file"
}

# Exactly one occurrence of each sentinel in each live file.
for f in "$BASE_SKILL" "$HARD_SKILL"; do
  bcount=$(grep -c "$BEGIN_MARKER" "$f")
  ecount=$(grep -c "$END_MARKER" "$f")
  label="$(basename "$(dirname "$(dirname "$f")")")/$(basename "$f")"
  if [[ "$bcount" -eq 1 ]]; then
    pass "Exactly one '${BEGIN_MARKER}' marker in $label"
  else
    fail "Expected exactly one '${BEGIN_MARKER}' marker in $label, found ${bcount}"
  fi
  if [[ "$ecount" -eq 1 ]]; then
    pass "Exactly one '${END_MARKER}' marker in $label"
  else
    fail "Expected exactly one '${END_MARKER}' marker in $label, found ${ecount}"
  fi
done

base_region="$(extract_combined_region "$BASE_SKILL")"
hard_region="$(extract_combined_region "$HARD_SKILL")"

if [[ -z "$base_region" ]]; then
  echo "ERROR: could not extract combined staleness/dispatch_seq region from $BASE_SKILL" >&2
  exit 2
fi
if [[ -z "$hard_region" ]]; then
  echo "ERROR: could not extract combined staleness/dispatch_seq region from $HARD_SKILL" >&2
  exit 2
fi

# ── append_detected_defect stub ─────────────────────────────────────────────────────────────────
# Faithful to the real function's call signature (class, attributed_path, site, detail,
# record_result) and its one observable side effect the extracted region depends on --
# `.detected_defects += [...]` on `$loop_guard_file` -- but this suite's assertions never inspect
# detected_defects content, only handoff_stale and stderr text, so a minimal append is sufficient.
append_detected_defect_def='
append_detected_defect() {
  jq --argjson entry "$(jq -c -n --arg class "$1" --arg path "$2" --arg site "$3" --arg detail "$4" \
        "{defect_class:\$class, attributed_source_path:\$path, detecting_site:\$site, detail:\$detail}")" \
      "'"'"'.detected_defects += [\$entry]'"'"'" \
      "$loop_guard_file" > "${loop_guard_file}.tmp" 2>/dev/null \
    && mv "${loop_guard_file}.tmp" "$loop_guard_file" 2>/dev/null
  echo "[test-stub] [system-defect:auto] queued -- defect_class=$1 attributed_path=$2 detecting_site=$3" >&2
}
'

# =====================================================================
# bash -n: each extracted region must be independently syntax-clean once the stub function and
# fixture inputs are prepended.
# =====================================================================
for pair in "base:$BASE_SKILL:$base_region" "hard:$HARD_SKILL:$hard_region"; do
  label="${pair%%:*}"; rest="${pair#*:}"; file="${rest%%:*}"; region="${rest#*:}"
  syntax_file="$WORKDIR/syntax-${label}.sh"
  {
    echo '#!/usr/bin/env bash'
    echo 'handoff_file="/tmp/fixture/.orchestrator-handoff.json"'
    echo 'dispatch_start_ts=0'
    echo 'dispatch_seq=1'
    echo 'task_number=1'
    echo 'session_id="sess_fixture"'
    echo 'loop_guard_file="/tmp/fixture/.orchestrator-loop-guard"'
    printf '%s\n' "$append_detected_defect_def"
    printf '%s\n' "$region"
  } > "$syntax_file"
  if bash -n "$syntax_file" 2>"$WORKDIR/syntax-${label}.err"; then
    pass "Extracted region ($label engine) is bash -n clean"
  else
    fail "Extracted region ($label engine) failed bash -n: $(cat "$WORKDIR/syntax-${label}.err")"
  fi
done

# ── Region execution harness ────────────────────────────────────────────────────────────────────
# Runs an extracted region (base or hard) in a subshell against a fixture handoff file, with cwd
# inside WORKDIR (never the repo root -- see header note on system-defect-record.sh avoidance).
run_region() {
  local region="$1" handoff_file="$2" dispatch_start_ts="$3" dispatch_seq="$4" \
        loop_guard_file="$5" out_file="$6" err_file="$7"
  (
    cd "$WORKDIR" || exit 1
    handoff_file="$handoff_file"
    dispatch_start_ts="$dispatch_start_ts"
    dispatch_seq="$dispatch_seq"
    task_number=1
    session_id="sess_fixture_current_dispatch"
    loop_guard_file="$loop_guard_file"
    eval "$append_detected_defect_def"
    eval "$region"
    echo "__HANDOFF_STALE__=${handoff_stale:-}"
  ) > "$out_file" 2> "$err_file"
}

result_stale() { grep '^__HANDOFF_STALE__=' "$1" | tail -1 | sed 's/^__HANDOFF_STALE__=//'; }

make_handoff() {
  local path="$1" dispatch_seq_value="$2"
  if [[ -n "$dispatch_seq_value" ]]; then
    jq -n --argjson seq "$dispatch_seq_value" \
      '{"status":"implemented","summary":"fixture","artifacts":[{"type":"summary","path":"specs/000_x/summaries/01_x-summary.md"}],"phases_completed":1,"phases_total":1,"blockers":[],"continuation_path":null,"dispatch_seq":$seq}' \
      > "$path"
  else
    jq -n \
      '{"status":"implemented","summary":"fixture","artifacts":[{"type":"summary","path":"specs/000_x/summaries/01_x-summary.md"}],"phases_completed":1,"phases_total":1,"blockers":[],"continuation_path":null}' \
      > "$path"
  fi
}

make_loop_guard() {
  local path="$1"
  echo '{"detected_defects":[]}' > "$path"
}

# run_case NAME REGION_LABEL REGION HANDOFF_DISPATCH_SEQ MINTED_DISPATCH_SEQ MTIME_OFFSET_SECONDS EXPECT_STALE EXPECT_STDERR_GREP
run_case() {
  local name="$1" engine_label="$2" region="$3" handoff_seq="$4" minted_seq="$5" \
        mtime_offset="$6" expect_stale="$7" expect_grep="${8:-}"
  local fx="$WORKDIR/${name}-${engine_label}"
  mkdir -p "$fx"
  local handoff_file="$fx/.orchestrator-handoff.json"
  local loop_guard_file="$fx/.orchestrator-loop-guard"
  make_handoff "$handoff_file" "$handoff_seq"
  make_loop_guard "$loop_guard_file"

  # dispatch_start_ts: "now" is the successor's dispatch-window open time. mtime_offset is applied
  # to the handoff file's actual mtime relative to now (0 = written right now, i.e. inside the
  # window; a large positive value backdates the file to BEFORE the window opened).
  local now_ts dispatch_start_ts
  now_ts=$(date -u +%s)
  dispatch_start_ts="$now_ts"
  if [[ "$mtime_offset" -gt 0 ]]; then
    local epoch=$((now_ts - mtime_offset))
    touch -d "@${epoch}" "$handoff_file" 2>/dev/null \
      || touch -t "$(date -u -d "@${epoch}" +%Y%m%d%H%M.%S)" "$handoff_file"
  fi

  local out="$fx.out" err="$fx.err"
  run_region "$region" "$handoff_file" "$dispatch_start_ts" "$minted_seq" "$loop_guard_file" "$out" "$err"

  local got_stale
  got_stale="$(result_stale "$out")"
  if [[ "$got_stale" == "$expect_stale" ]]; then
    pass "${name} (${engine_label}): handoff_stale=${expect_stale}"
  else
    fail "${name} (${engine_label}): expected handoff_stale=${expect_stale}, got '${got_stale}' -- stderr: $(cat "$err")"
  fi
  if [[ -n "$expect_grep" ]]; then
    if grep -qE "$expect_grep" "$err"; then
      pass "${name} (${engine_label}): stderr matches expected pattern"
    else
      fail "${name} (${engine_label}): stderr does not match expected pattern '${expect_grep}': $(cat "$err")"
    fi
  fi
}

for pair in "base:$base_region" "hard:$hard_region"; do
  engine_label="${pair%%:*}"; region="${pair#*:}"

  # =====================================================================
  # Case 1: dispatch_seq matches the current cycle's minted value, mtime inside the window.
  # Expected: ACCEPTED (handoff_stale=false).
  # =====================================================================
  run_case "case1-match" "$engine_label" "$region" 5 5 0 "false" 'dispatch_seq match'

  # =====================================================================
  # Case 2 (THE LOAD-BEARING CASE): dispatch_seq is a PREDECESSOR's value (a still-live
  # predecessor's late write), mtime inside the successor's dispatch window -- reproducing the
  # observed 6-second-overlap failure shape. mtime alone would ACCEPT this (mtime_offset=0, i.e.
  # written "just now", well inside the window); only the dispatch_seq comparison rejects it.
  # Expected: REJECTED (handoff_stale=true), stderr names DISPATCH_SEQ MISMATCH.
  # =====================================================================
  run_case "case2-mismatch-inside-window" "$engine_label" "$region" 4 5 0 "true" 'DISPATCH_SEQ MISMATCH'

  # =====================================================================
  # Case 3: old mtime (git-restoration hazard) -- handoff predates the dispatch window by a wide
  # margin, regardless of dispatch_seq. Expected: REJECTED by the RETAINED mtime check, before
  # the dispatch_seq comparison is even reached (handoff_stale is already true).
  # =====================================================================
  run_case "case3-old-mtime" "$engine_label" "$region" 5 5 3600 "true" 'STALE HANDOFF'

  # =====================================================================
  # Case 4: handoff has no dispatch_seq field at all (writer predates the contract). mtime is
  # inside the window. Expected: WARN, NOT rejected -- handoff_stale stays false.
  # =====================================================================
  run_case "case4-absent" "$engine_label" "$region" "" 5 0 "false" 'WARN: handoff has no dispatch_seq field'
done

# =====================================================================
# Negative-control note (not automated): temporarily reverting the dispatch_seq gate (commenting
# out the `elif [ "$handoff_dispatch_seq" != ... ]` branch in both SKILL.md files) makes Case 2
# fail, since only that branch's mismatch check distinguishes it from Case 1. This was verified
# manually during authoring per the plan's Phase 7 verification bullet and is not re-verified on
# every run (would require mutating the source files mid-suite).
# =====================================================================

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
