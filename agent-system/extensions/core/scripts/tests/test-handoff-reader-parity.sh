#!/usr/bin/env bash
# test-handoff-reader-parity.sh - Single-engine reader presence/correctness suite for
# skill-orchestrate/SKILL.md's Stage 5 result-read block (and the Stage 4 H1 / Stage 5b hard-only
# reads it used to compare against a second file). Builds ONE shared
# .orchestrator-handoff.json fixture, extracts the literal jq filter strings the merged engine
# actually ships for each field, and asserts each filter is present and produces the expected
# value against the shared fixture. This suite used to diff those same filter strings against a
# SECOND file (skill-orchestrate-hard/SKILL.md) for byte-equality -- since the two engines were
# merged into one `hard_mode`-gated file, that comparison premise no longer exists: with one
# engine there is nothing left to diff against, so the checks below were converted from
# extract-twice-and-compare to extract-once-and-verify, preserving every field/value assertion
# the old comparison implied without the vacuous self-comparison.
#
# Structural model: scripts/tests/test-validate-handoff.sh / test-corroborate-phase-counts.sh
# (mktemp -d workdir with an EXIT-trap cleanup, source-store-first candidate resolution for the
# SKILL.md file under active development, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error).
#
# Why extraction, not hand-copied jq: hand-copying the filter strings into this test would not
# catch drift if a future editor changes the engine's Stage 5 read without updating this test to
# match -- the whole point of extraction is proving the SHIPPED file's actual filter still does
# what this test expects, not that this test agrees with itself. Extraction is anchored on
# stable, already-unique surrounding text (verified via grep -c == 1 at authoring time) rather
# than raw line numbers, so it survives ordinary prose edits elsewhere in the file.
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

SKILL_FILE="$(resolve_candidate "skills/skill-orchestrate/SKILL.md")" || {
  echo "ERROR: skill-orchestrate/SKILL.md not found (source store or deploy tree)" >&2
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

# Anchor: the comment immediately preceding the merged engine's Stage 5 dispatch_status read.
# Verified unique (grep -c == 1) in the merged file.
ANCHOR='not bare `.status`) so a handoff with a missing'

# Fields the Stage 5 result-read block extracts. Each field's EXPECTED value is derived from the
# shared fixture above by hand, once, at authoring time (not re-derived from the filter under
# test -- that would make the assertion vacuous).
SHARED_FIELDS=(dispatch_status dispatch_summary blockers next_hint phases_completed phases_total plan_markers_verified)
declare -A SHARED_FIELD_EXPECTED=(
  [dispatch_status]="implemented"
  [dispatch_summary]="Completed all phases with one tracked strategic sorry and one historical blocker entry."
  [blockers]='[{"phase":2,"target":"example-target.sh","verbatim_goal":"example verbatim goal text","what_was_tried":"attempted approach","why_it_failed":"reason it failed"}]'
  [next_hint]="implement"
  [phases_completed]="1"
  [phases_total]="3"
  [plan_markers_verified]="true"
)

for field in "${SHARED_FIELDS[@]}"; do
  filter="$(extract_jq_filter "$SKILL_FILE" "$ANCHOR" "$field")"
  if [[ -z "$filter" ]]; then
    fail "$field: could not extract jq filter from skill-orchestrate/SKILL.md"
    continue
  fi
  val="$(jq -r "$filter" "$FIXTURE" 2>/dev/null)"
  expected="${SHARED_FIELD_EXPECTED[$field]}"
  if [[ "$field" == "blockers" ]]; then
    # blockers is a jq -c array; compare parsed JSON structurally, not as a raw string, so key
    # ordering in the filter's own output can't cause a spurious mismatch.
    val_c="$(jq -c "$filter" "$FIXTURE" 2>/dev/null)"
    if [[ "$(jq -c -e --argjson a "$val_c" --argjson b "$expected" -n '$a == $b' 2>/dev/null)" == "true" ]]; then
      pass "$field: filter ('$filter') present and produces the expected value against the shared fixture"
    else
      fail "$field: filter present but value diverges from expected -- got='$val_c' expected='$expected'"
    fi
  elif [[ "$val" == "$expected" ]]; then
    pass "$field: filter ('$filter') present and produces the expected value ('$val') against the shared fixture"
  else
    fail "$field: filter present but value diverges -- got='$val' expected='$expected'"
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
continuation_block="$(extract_continuation_block "$SKILL_FILE")"
if [[ -z "$continuation_block" ]]; then
  fail "continuation: could not extract the multi-line jq -c block from skill-orchestrate/SKILL.md"
else
  pass "continuation: multi-line dual-form-resolution jq block present"
  cont_val="$(jq -c "$continuation_block" "$FIXTURE" 2>/dev/null)"
  if [[ "$cont_val" == *"phase-1-handoff-20260101T000000Z.md"* ]]; then
    pass "continuation: resolved value from shared fixture contains the expected handoff_path"
  else
    fail "continuation: resolved value unexpected: $cont_val"
  fi
fi

# ── artifacts[0].{path,type,summary}: presence + expected value against the shared fixture ─────
ARTIFACT_ANCHOR='handoff_artifact_path=\$(echo "\$handoff" \| jq -r'\''\.artifacts\[0\]\.path'
declare -A ARTIFACT_SUB_EXPECTED=(
  [path]="specs/000_x/summaries/01_x-summary.md"
  [type]="summary"
  [summary]="Partial summary"
)
for sub in path type summary; do
  var="handoff_artifact_${sub}"
  filter="$(grep -oP "${var}=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$SKILL_FILE" | head -1)"
  if [[ -z "$filter" ]]; then
    fail "artifacts[0].$sub: could not extract from skill-orchestrate/SKILL.md"
    continue
  fi
  val="$(jq -r "$filter" "$FIXTURE" 2>/dev/null)"
  expected="${ARTIFACT_SUB_EXPECTED[$sub]}"
  if [[ "$val" == "$expected" ]]; then
    pass "artifacts[0].$sub: filter present and produces the expected value ('$val') against the shared fixture"
  else
    fail "artifacts[0].$sub: filter present but value diverges -- got='$val' expected='$expected'"
  fi
done

# ── hard_mode-only allowlisted fields: extraction succeeds and produces the expected value ──────
# against the shared fixture. NOT compared against a second engine -- there is only one engine
# now, and these fields are never read on the base-mode path by design (H5 divergence audit
# routing and blocked-escalation blocker_desc are hard_mode-only concerns).
#
# .skeleton is read as `last_skeleton` DIRECTLY FROM THE HANDOFF FILE (`jq -r '...' "$handoff_file"`),
# not via the `echo "$handoff" | jq ...` form the SHARED_FIELDS above use, and it lives in Stage
# 4's `hard_mode`-gated per-phase-dispatch (H1) branch -- NOT Stage 5, where it lived in the old
# hard-only file. extract_jq_filter_from_file() matches that different read shape.
extract_jq_filter_from_file() {
  local file="$1" var="$2"
  grep -oP "${var}=\\\$\\(jq -[rc] '\\K[^']*(?=' \"\\\$handoff_file\"\\))" "$file" | head -1
}

skeleton_filter="$(extract_jq_filter_from_file "$SKILL_FILE" "last_skeleton")"
if [[ -n "$skeleton_filter" ]]; then
  val="$(jq -r "$skeleton_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "true" ]]; then
    pass "hard_mode-only allowlisted: .skeleton (as last_skeleton, Stage 4 H1 branch) extracts 'true' from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .skeleton (last_skeleton) unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract the last_skeleton filter from skill-orchestrate/SKILL.md"
fi

# .sorry_inventory: the merged engine no longer assigns a bare `sorry_inventory=` variable -- it
# inlines the `.sorry_inventory[]?.follow_up_task` filter directly into the `follow_up_tasks`/
# `follow_up_count` derivation (same Stage 4 H1 branch, immediately after the `last_skeleton`
# check above), and that code path runs unconditionally within the branch rather than behind a
# second, inner hard_mode check. This is a presence-and-correctness check on that inlined filter
# (via follow_up_tasks, which surfaces the fixture's one strategic sorry's follow_up_task="999"),
# not a re-creation of the old bare-variable count check -- the field is still exercised, just
# through its actual call site rather than a no-longer-existing intermediate variable.
follow_up_tasks_filter="$(extract_jq_filter_from_file "$SKILL_FILE" "follow_up_tasks")"
if [[ -n "$follow_up_tasks_filter" ]]; then
  val="$(jq -r "$follow_up_tasks_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "999" ]]; then
    pass "hard_mode-only allowlisted: .sorry_inventory (inlined into follow_up_tasks, Stage 4 H1 branch) extracts follow_up_task='999' from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .sorry_inventory (follow_up_tasks) unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract the follow_up_tasks filter (inlined .sorry_inventory read) from skill-orchestrate/SKILL.md"
fi

# .blockers[0].target / .blockers[0].verbatim_goal: SURVIVED UNCHANGED -- same variable names,
# same `echo "$handoff" | jq -r '...'` read form as before, just retargeted to the merged file.
# Both live in Stage 5b's `hard_mode`-gated H5/H6 churn-detection block (churn signature: no
# progress this cycle despite a partial dispatch with blockers), not Stage 5 proper.
blocker_target_filter="$(grep -oP "blocker_target=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$SKILL_FILE" | head -1)"
if [[ -n "$blocker_target_filter" ]]; then
  val="$(jq -r "$blocker_target_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example-target.sh" ]]; then
    pass "hard_mode-only allowlisted: .blockers[0].target (Stage 5b H5/H6 churn detection) extracts 'example-target.sh' from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .blockers[0].target unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract .blockers[0].target filter from skill-orchestrate/SKILL.md"
fi

verbatim_goal_filter="$(grep -oP "verbatim_goal=\\\$\(echo \"\\\$handoff\" \| jq -r '\K[^']*(?=')" "$SKILL_FILE" | head -1)"
if [[ -n "$verbatim_goal_filter" ]]; then
  val="$(jq -r "$verbatim_goal_filter" "$FIXTURE" 2>/dev/null)"
  if [[ "$val" == "example verbatim goal text" ]]; then
    pass "hard_mode-only allowlisted: .blockers[0].verbatim_goal (Stage 5b H5/H6 churn detection) extracts the expected text from the shared fixture"
  else
    fail "hard_mode-only allowlisted: .blockers[0].verbatim_goal unexpected value '$val'"
  fi
else
  fail "hard_mode-only allowlisted: could not extract .blockers[0].verbatim_goal filter from skill-orchestrate/SKILL.md"
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

# dispatch_seq Stage 5 gate parity (Defect A) -- REMOVED. This block used to extract the
# `dispatch-seq-gate:begin`/`:end` sentinel region from both engines and diff them for
# byte-equality. With one merged engine, that comparison would extract the SAME region from the
# SAME file twice and diff it against itself -- a vacuous, always-green no-op, not a real parity
# check. The real coverage for this gate (including its dispatch_seq-mismatch behavioral cases,
# not just a structural diff) already lives in test-handoff-dispatch-identity.sh, which exercises
# the extracted region directly against fixtures. Removed deliberately here rather than left as a
# silently-passing no-op.

# ── Summary ──────────────────────────────────────────────────────────────────────────────────
info "Engine resolved to:    $SKILL_FILE"
info "Validator resolved to: $VALIDATOR"
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
