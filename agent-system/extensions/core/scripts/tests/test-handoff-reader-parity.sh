#!/usr/bin/env bash
# test-handoff-reader-parity.sh - Two-engine reader parity suite. Builds ONE shared
# .orchestrator-handoff.json fixture, extracts the literal jq filter strings both
# skill-orchestrate/SKILL.md's and skill-orchestrate-hard/SKILL.md's Stage 5 result-read blocks
# actually ship, evaluates each against the shared fixture, and asserts the two engines produce
# byte-identical filter strings AND identical extracted values for every field both read. The
# hard engine additionally reading .skeleton, .sorry_inventory, .blockers[0].target, and
# .blockers[0].verbatim_goal is an expected, allowlisted hard-only difference -- not a parity
# failure -- and is asserted separately (extraction succeeds, values are sane) rather than
# compared against the base engine, which never reads those fields at all.
#
# Structural model: scripts/tests/test-validate-handoff.sh / test-corroborate-phase-counts.sh
# (mktemp -d workdir with an EXIT-trap cleanup, source-store-first candidate resolution for the
# SKILL.md files under active development, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Why extraction, not hand-copied jq: hand-copying the filter strings into this test would not
# catch drift if a future editor changes one engine's Stage 5 read but not the other's -- the
# whole point of "parity" is proving the two SHIPPED files agree, not that this test agrees with
# itself. Extraction is anchored on stable, already-unique surrounding text (verified via
# grep -c == 1 per file at authoring time) rather than raw line numbers, so it survives ordinary
# prose edits elsewhere in either file.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required file was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Source-store-first (see test-validate-handoff.sh's identical rationale): this suite exercises
# the SKILL.md files under active development, which live in the source store before a redeploy
# copies them to the deploy tree. After redeploy the two are identical, so either order then
# yields the same result.
resolve_candidate() {
  local relative="$1" candidate
  for candidate in "$SCRIPT_DIR/../../$relative" "$REPO_ROOT/.claude/$relative"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

BASE_SKILL="$(resolve_candidate "skills/skill-orchestrate/SKILL.md")" || {
  echo "ERROR: skill-orchestrate/SKILL.md not found (source store or deploy tree)" >&2
  exit 2
}
HARD_SKILL="$(resolve_candidate "skills/skill-orchestrate-hard/SKILL.md")" || {
  echo "ERROR: skill-orchestrate-hard/SKILL.md not found (source store or deploy tree)" >&2
  exit 2
}
VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-handoff.sh"
  "$REPO_ROOT/.claude/scripts/validate-handoff.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-handoff.sh not found at any candidate path" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ── Shared fixture: ONE handoff satisfying the validator AND both readers ──────────────────────
# Rich enough to exercise every field either engine reads, including the hard-only extras.
FIXTURE="$WORKDIR/shared-handoff.json"
cat > "$FIXTURE" << 'EOF'
{
  "status": "implemented",
  "summary": "Completed all phases with one tracked strategic sorry and one historical blocker entry.",
  "artifacts": [
    {"type": "summary", "path": "specs/000_x/summaries/01_x-summary.md", "summary": "Partial summary"}
  ],
  "phases_completed": 1,
  "phases_total": 3,
  "blockers": [
    {
      "phase": 2,
      "target": "example-target.sh",
      "verbatim_goal": "example verbatim goal text",
      "what_was_tried": "attempted approach",
      "why_it_failed": "reason it failed"
    }
  ],
  "continuation_path": "specs/000_x/handoffs/phase-1-handoff-20260101T000000Z.md",
  "next_action_hint": "implement",
  "plan_markers_verified": true,
  "skeleton": true,
  "sorry_inventory": [
    {
      "file": "path/to/File.lean",
      "line": 1,
      "statement": "theorem foo : ...",
      "strategic": true,
      "assumption": "assumption text",
      "why_deferred": "deferred reason",
      "follow_up_task": "999"
    }
  ]
}
EOF

if bash "$VALIDATOR" "$FIXTURE" >"$WORKDIR/validator.out" 2>&1; then
  pass "Shared fixture passes validate-handoff.sh -- one schema satisfies validator and both readers"
else
  fail "Shared fixture failed validate-handoff.sh -- see $WORKDIR/validator.out"
  cat "$WORKDIR/validator.out"
fi

# ── extract_jq_filter <file> <anchor_pattern> <var_name> ───────────────────────────────────────
# Locates the unique line assigning var_name from `$handoff` via jq inside the window starting at
# the first line matching anchor_pattern (grep -A80), and prints the filter string between the
# outer single quotes. Fails (empty output) if not found -- callers must check for empty.
extract_jq_filter() {
  local file="$1" anchor="$2" var="$3"
  grep -A80 -F -- "$anchor" "$file" \
    | grep -P "^\s*${var}=\\\$\(echo \"\\\$handoff\" \| jq -[rc] '" \
    | head -1 \
    | grep -oP "jq -[rc] '\K[^']*(?=')"
}

# Anchor: the byte-identical comment immediately preceding both engines' Stage 5 dispatch_status
# read. Verified unique (grep -c == 1) in both files at authoring time.
ANCHOR='not bare `.status`) so a handoff with a missing'

# Shared fields both engines' Stage 5 result-read block extract identically.
SHARED_FIELDS=(dispatch_status dispatch_summary blockers next_hint phases_completed phases_total plan_markers_verified)

for field in "${SHARED_FIELDS[@]}"; do
  base_filter="$(extract_jq_filter "$BASE_SKILL" "$ANCHOR" "$field")"
  hard_filter="$(extract_jq_filter "$HARD_SKILL" "$ANCHOR" "$field")"
  if [[ -z "$base_filter" ]]; then
    fail "$field: could not extract jq filter from skill-orchestrate/SKILL.md"
    continue
  fi
  if [[ -z "$hard_filter" ]]; then
    fail "$field: could not extract jq filter from skill-orchestrate-hard/SKILL.md"
    continue
  fi
  if [[ "$base_filter" != "$hard_filter" ]]; then
    fail "$field: filter strings diverge -- base='$base_filter' hard='$hard_filter'"
    continue
  fi
  base_val="$(jq -r "$base_filter" "$FIXTURE" 2>/dev/null)"
  hard_val="$(jq -r "$hard_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$base_val" == "$hard_val" ]]; then
    pass "$field: identical filter ('$base_filter') and identical value ('$base_val') in both engines"
  else
    fail "$field: identical filter but divergent values -- base='$base_val' hard='$hard_val'"
  fi
done

# ── Continuation dual-form resolution: multi-line jq -c block, compared as a normalized string ──
extract_continuation_block() {
  local file="$1"
  grep -A80 -F -- "$ANCHOR" "$file" \
    | grep -A4 -P '^\s*continuation=\$\(echo "\$handoff" \| jq -c '"'"'$' \
    | sed -n '2,5p' \
    | tr -s ' \t' ' ' \
    | sed 's/^ *//;s/ *$//'
}
base_continuation="$(extract_continuation_block "$BASE_SKILL")"
hard_continuation="$(extract_continuation_block "$HARD_SKILL")"
if [[ -z "$base_continuation" || -z "$hard_continuation" ]]; then
  fail "continuation: could not extract the multi-line jq -c block from one or both engines"
elif [[ "$base_continuation" == "$hard_continuation" ]]; then
  pass "continuation: identical multi-line dual-form-resolution jq block in both engines"
  cont_val="$(jq -c "$base_continuation" "$FIXTURE" 2>/dev/null)"
  if [[ "$cont_val" == *"phase-1-handoff-20260101T000000Z.md"* ]]; then
    pass "continuation: resolved value from shared fixture contains the expected handoff_path"
  else
    fail "continuation: resolved value unexpected: $cont_val"
  fi
else
  fail "continuation: multi-line blocks diverge between engines"
  info "base: $base_continuation"
  info "hard: $hard_continuation"
fi

# ── artifacts[0].{path,type,summary}: both engines read identically ────────────────────────────
ARTIFACT_ANCHOR='handoff_artifact_path=\$(echo "\$handoff" \| jq -r'\''\.artifacts\[0\]\.path'
for sub in path type summary; do
  var="handoff_artifact_${sub}"
  base_filter="$(grep -oP "${var}=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$BASE_SKILL" | head -1)"
  hard_filter="$(grep -oP "${var}=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$HARD_SKILL" | head -1)"
  if [[ -z "$base_filter" || -z "$hard_filter" ]]; then
    fail "artifacts[0].$sub: could not extract from one or both engines"
    continue
  fi
  if [[ "$base_filter" != "$hard_filter" ]]; then
    fail "artifacts[0].$sub: filter strings diverge -- base='$base_filter' hard='$hard_filter'"
    continue
  fi
  base_val="$(jq -r "$base_filter" "$FIXTURE" 2>/dev/null)"
  hard_val="$(jq -r "$hard_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$base_val" == "$hard_val" ]]; then
    pass "artifacts[0].$sub: identical filter and value ('$base_val') in both engines"
  else
    fail "artifacts[0].$sub: identical filter but divergent values -- base='$base_val' hard='$hard_val'"
  fi
done

# ── Hard-only allowlisted fields: extraction succeeds and produces sane values against the ─────
# shared fixture. NOT compared against base -- base never reads these, by design (H5 divergence
# audit routing and blocked-escalation blocker_desc are hard-mode-only concerns).
hard_skeleton_filter="$(grep -oP "skeleton=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$HARD_SKILL" | head -1)"
if [[ -n "$hard_skeleton_filter" ]]; then
  val="$(jq -r "$hard_skeleton_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "true" ]]; then
    pass "hard-only allowlisted: .skeleton extracts 'true' from the shared fixture"
  else
    fail "hard-only allowlisted: .skeleton unexpected value '$val'"
  fi
else
  fail "hard-only allowlisted: could not extract .skeleton filter from hard engine"
fi

hard_sorry_filter="$(grep -oP "sorry_inventory=\\\$\(echo \"\\\$handoff\" \| jq -c '\K[^']*(?=')" "$HARD_SKILL" | head -1)"
if [[ -n "$hard_sorry_filter" ]]; then
  count="$(jq -c "$hard_sorry_filter" "$FIXTURE" 2>/dev/null | jq 'length')"
  if [[ "$count" == "1" ]]; then
    pass "hard-only allowlisted: .sorry_inventory extracts 1 entry from the shared fixture"
  else
    fail "hard-only allowlisted: .sorry_inventory unexpected count '$count'"
  fi
else
  fail "hard-only allowlisted: could not extract .sorry_inventory filter from hard engine"
fi

hard_blocker_target_filter="$(grep -oP "blocker_target=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$HARD_SKILL" | head -1)"
if [[ -n "$hard_blocker_target_filter" ]]; then
  val="$(jq -r "$hard_blocker_target_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example-target.sh" ]]; then
    pass "hard-only allowlisted: .blockers[0].target extracts 'example-target.sh' from the shared fixture"
  else
    fail "hard-only allowlisted: .blockers[0].target unexpected value '$val'"
  fi
else
  fail "hard-only allowlisted: could not extract .blockers[0].target filter from hard engine"
fi

hard_verbatim_goal_filter="$(grep -oP "verbatim_goal=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$HARD_SKILL" | head -1)"
if [[ -n "$hard_verbatim_goal_filter" ]]; then
  val="$(jq -r "$hard_verbatim_goal_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example verbatim goal text" ]]; then
    pass "hard-only allowlisted: .blockers[0].verbatim_goal extracts the expected text from the shared fixture"
  else
    fail "hard-only allowlisted: .blockers[0].verbatim_goal unexpected value '$val'"
  fi
else
  fail "hard-only allowlisted: could not extract .blockers[0].verbatim_goal filter from hard engine"
fi

# ── Every extracted field name must appear in the schema's properties (grep-audit lock-in) ─────
SCHEMA_CANDIDATES=(
  "$SCRIPT_DIR/../../context/schemas/orchestrator-handoff-schema.json"
  "$REPO_ROOT/.claude/context/schemas/orchestrator-handoff-schema.json"
)
SCHEMA=""
for candidate in "${SCHEMA_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCHEMA="$candidate"
    break
  fi
done
if [[ -z "$SCHEMA" ]]; then
  fail "schema file not found at any candidate path -- cannot lock in field-name audit"
else
  schema_props="$(jq -r '.properties | keys[]' "$SCHEMA" 2>/dev/null)"
  # Top-level field names read by either engine (sub-field paths like artifacts[0].path and
  # blockers[0].target collapse to their top-level property names: artifacts, blockers).
  AUDITED_FIELDS=(status summary artifacts blockers phases_completed phases_total plan_markers_verified skeleton sorry_inventory next_action_hint continuation_path continuation_context)
  audit_ok=true
  for f in "${AUDITED_FIELDS[@]}"; do
    if ! grep -qx -- "$f" <<< "$schema_props"; then
      fail "grep-audit: field '$f' is read by a reader but absent from schema properties"
      audit_ok=false
    fi
  done
  if [[ "$audit_ok" == "true" ]]; then
    pass "grep-audit: all ${#AUDITED_FIELDS[@]} reader-referenced field names appear in schema properties"
  fi
fi

# ── dispatch_seq Stage 5 gate parity (Defect A) ─────────────────────────────────────────────────
# Extracts the `dispatch-seq-gate:begin`/`:end` sentinel region from both engines and asserts
# byte-equality after normalizing the two known-allowed differences: the notice prefix
# (`[orchestrate]` vs `[hard-orchestrate]`) and each engine's own self-attribution strings
# (`skill-orchestrate/SKILL.md` vs `skill-orchestrate-hard/SKILL.md`). This is the mechanical
# backstop for the "one-sided fix of the Stage 5 verbatim twin" recurring defect class named in
# this file pair's own Risks & Mitigations: a future edit landing in only one engine fails this
# assertion instead of silently diverging.
extract_sentinel_region() {
  local file="$1"
  awk '/dispatch-seq-gate:begin/{flag=1} flag{print} /dispatch-seq-gate:end/{if(flag){exit}}' "$file"
}

base_gate="$(extract_sentinel_region "$BASE_SKILL")"
hard_gate="$(extract_sentinel_region "$HARD_SKILL")"

if [[ -z "$base_gate" ]]; then
  fail "dispatch_seq gate: could not extract dispatch-seq-gate:begin/:end region from $BASE_SKILL"
elif [[ -z "$hard_gate" ]]; then
  fail "dispatch_seq gate: could not extract dispatch-seq-gate:begin/:end region from $HARD_SKILL"
else
  # Normalize hard-mode-only strings down to the base-mode spelling before comparing.
  normalized_hard="$(sed -e 's/hard-orchestrate/orchestrate/g' -e 's/skill-orchestrate-hard/skill-orchestrate/g' <<< "$hard_gate")"
  # The hard engine also carries exactly one extra cross-reference comment line, tagged with the
  # HARD-MODE-TWIN-CROSS-REFERENCE marker, with no counterpart line in the base file (matching the
  # pre-existing append_detected_defect cross-reference convention, which also lives only in the
  # hard file) -- strip that single tagged line before comparing so this expected, allowlisted
  # asymmetry does not register as drift.
  normalized_hard_no_twin="$(grep -v 'HARD-MODE-TWIN-CROSS-REFERENCE' <<< "$normalized_hard")"
  if [[ "$base_gate" == "$normalized_hard_no_twin" ]]; then
    pass "dispatch_seq gate: base and hard Stage 5 gate blocks are byte-identical apart from the notice prefix, self-attribution strings, and the hard-only cross-reference comment"
  else
    fail "dispatch_seq gate: base and hard Stage 5 gate blocks diverge beyond the allowed prefix/attribution/cross-reference differences"
    diff <(echo "$base_gate") <(echo "$normalized_hard_no_twin") || true
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────────────────────
info "Base engine resolved to:  $BASE_SKILL"
info "Hard engine resolved to:  $HARD_SKILL"
info "Validator resolved to:    $VALIDATOR"
echo ""
echo "========================================"
echo "test-handoff-reader-parity.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
