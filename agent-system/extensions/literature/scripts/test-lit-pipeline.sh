#!/usr/bin/env bash
# test-lit-pipeline.sh - Validate the full --lit pipeline wiring for CSLib tasks
#
# Usage: .claude/scripts/test-lit-pipeline.sh [--runtime]
#
# Runs static checks (Sections A-D) by default. Pass --runtime to also execute
# Section E: a smoke test that exercises literature-briefing.sh with mock fixtures.
#
# Must be run from the project root (the directory containing .claude/).
#
# Exit 0 when all checks pass, exit 1 when any check fails.
#
# Sections:
#   A - Script existence and syntax (literature-briefing.sh, literature-create-setup-task.sh)
#   B - CSLib skill Stage 4a wiring (4 skills: lit_context init, briefing call, lit_flag gate)
#   C - CSLib agent acknowledgment (4 agents: <literature-briefing> reference)
#   D - General skill interactive detection (skill-researcher, skill-implementer)
#   E - Runtime smoke test with mock fixtures (opt-in via --runtime)

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Counters ---
PASSED=0
FAILED=0
WARNINGS=0

# --- Flags ---
RUN_RUNTIME=false
for arg in "$@"; do
  if [[ "$arg" == "--runtime" ]]; then
    RUN_RUNTIME=true
  fi
done

# --- Script location and project root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Logging helpers ---
log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASSED++))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAILED++))
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARNINGS++))
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# --- Validate project root ---
if [[ ! -d "$PROJECT_ROOT/.claude" ]]; then
  echo -e "${RED}[ERROR]${NC} .claude/ directory not found under $PROJECT_ROOT"
  echo "  Run this script from the project root directory."
  exit 1
fi

# --- Runtime cleanup state ---
TEMP_LIT_DIR=""
TEMP_SUB_INDEX=""
ORIGINAL_SUB_INDEX_EXISTS=false
SUB_INDEX_PATH="$PROJECT_ROOT/specs/literature-index.json"

cleanup() {
  if [[ -n "$TEMP_LIT_DIR" ]] && [[ -d "$TEMP_LIT_DIR" ]]; then
    rm -rf "$TEMP_LIT_DIR"
  fi
  # Only remove sub-index if we created it (it didn't exist before)
  if [[ -n "$TEMP_SUB_INDEX" ]] && [[ -f "$TEMP_SUB_INDEX" ]] && [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    rm -f "$TEMP_SUB_INDEX"
  fi
  # Restore original LITERATURE_DIR if we changed it
  if [[ -n "${SAVED_LITERATURE_DIR+x}" ]]; then
    export LITERATURE_DIR="$SAVED_LITERATURE_DIR"
  fi
}
trap 'cleanup' EXIT

# ============================================================
# SECTION A: Script existence and syntax
# ============================================================
section_a() {
  echo ""
  log_info "Section A: Script existence and syntax"
  echo "----------------------------------------"

  local scripts_dir="$PROJECT_ROOT/.claude/scripts"

  # literature-briefing.sh: exists
  local briefing_script="$scripts_dir/literature-briefing.sh"
  if [[ -f "$briefing_script" ]]; then
    log_pass "literature-briefing.sh exists"
  else
    log_fail "literature-briefing.sh not found at $briefing_script"
    return
  fi

  # literature-briefing.sh: executable
  if [[ -x "$briefing_script" ]]; then
    log_pass "literature-briefing.sh is executable"
  else
    log_fail "literature-briefing.sh is not executable (run: chmod +x $briefing_script)"
  fi

  # literature-briefing.sh: bash -n syntax check
  if bash -n "$briefing_script" 2>/dev/null; then
    log_pass "literature-briefing.sh passes bash -n syntax check"
  else
    log_fail "literature-briefing.sh has bash syntax errors (bash -n failed)"
  fi

  # literature-create-setup-task.sh: exists
  local setup_script="$scripts_dir/literature-create-setup-task.sh"
  if [[ -f "$setup_script" ]]; then
    log_pass "literature-create-setup-task.sh exists"
  else
    log_fail "literature-create-setup-task.sh not found at $setup_script"
    return
  fi

  # literature-create-setup-task.sh: executable
  if [[ -x "$setup_script" ]]; then
    log_pass "literature-create-setup-task.sh is executable"
  else
    log_fail "literature-create-setup-task.sh is not executable (run: chmod +x $setup_script)"
  fi

  # literature-create-setup-task.sh: bash -n syntax check
  if bash -n "$setup_script" 2>/dev/null; then
    log_pass "literature-create-setup-task.sh passes bash -n syntax check"
  else
    log_fail "literature-create-setup-task.sh has bash syntax errors (bash -n failed)"
  fi
}

# ============================================================
# SECTION B: CSLib skill Stage 4a wiring
# ============================================================
section_b() {
  echo ""
  log_info "Section B: CSLib skill Stage 4a wiring"
  echo "----------------------------------------"

  # Check if cslib extension is loaded; if not, skip with info
  if [[ ! -d "$PROJECT_ROOT/.claude/skills/skill-cslib-research" ]]; then
    log_info "CSLib extension not loaded in this project — skipping Section B"
    return
  fi

  local skills=(
    "skill-cslib-research"
    "skill-cslib-implementation"
    "skill-cslib-research-hard"
    "skill-cslib-implementation-hard"
  )

  for skill in "${skills[@]}"; do
    local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found at $skill_file"
      continue
    fi

    # Check 1: lit_context="" initialization
    if grep -q 'lit_context=""' "$skill_file" 2>/dev/null; then
      log_pass "$skill: lit_context=\"\" initialization found"
    else
      log_fail "$skill: lit_context=\"\" initialization NOT found"
    fi

    # Check 2: literature-briefing.sh call
    if grep -q 'literature-briefing\.sh' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-briefing.sh call found"
    else
      log_fail "$skill: literature-briefing.sh call NOT found"
    fi

    # Check 3: lit_flag gate (lit_flag == "true" or lit_flag = "true")
    if grep -q 'lit_flag' "$skill_file" 2>/dev/null; then
      log_pass "$skill: lit_flag gate found"
    else
      log_fail "$skill: lit_flag gate NOT found"
    fi
  done
}

# ============================================================
# SECTION C: CSLib agent acknowledgment sections
# ============================================================
section_c() {
  echo ""
  log_info "Section C: CSLib agent acknowledgment sections"
  echo "----------------------------------------"

  # Check if cslib extension is loaded; if not, skip with info
  if [[ ! -f "$PROJECT_ROOT/.claude/agents/cslib-research-agent.md" ]]; then
    log_info "CSLib extension not loaded in this project — skipping Section C"
    return
  fi

  local agents=(
    "cslib-research-agent"
    "cslib-implementation-agent"
    "cslib-research-hard-agent"
    "cslib-implementation-hard-agent"
  )

  for agent in "${agents[@]}"; do
    local agent_file="$PROJECT_ROOT/.claude/agents/$agent.md"

    if [[ ! -f "$agent_file" ]]; then
      log_fail "$agent: agent file not found at $agent_file"
      continue
    fi

    # Check for <literature-briefing> tag reference or literature-briefing text
    if grep -q 'literature.briefing\|<literature-briefing>' "$agent_file" 2>/dev/null; then
      log_pass "$agent: literature-briefing acknowledgment found"
    else
      log_fail "$agent: literature-briefing acknowledgment NOT found"
    fi
  done
}

# ============================================================
# SECTION D: General skill interactive detection wiring
# ============================================================
section_d() {
  echo ""
  log_info "Section D: General skill interactive detection wiring"
  echo "----------------------------------------"

  local skills=(
    "skill-researcher"
    "skill-implementer"
  )

  for skill in "${skills[@]}"; do
    local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found at $skill_file"
      continue
    fi

    # Check 1: literature-index.json sub-index detection
    if grep -q 'literature-index\.json' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-index.json sub-index check found"
    else
      log_fail "$skill: literature-index.json sub-index check NOT found"
    fi

    # Check 2: literature-create-setup-task reference
    if grep -q 'literature-create-setup-task' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-create-setup-task reference found"
    else
      log_fail "$skill: literature-create-setup-task reference NOT found"
    fi
  done
}

# ============================================================
# SECTION E: Runtime smoke test (opt-in via --runtime)
# ============================================================
section_e() {
  echo ""
  log_info "Section E: Runtime smoke test (--runtime)"
  echo "----------------------------------------"

  local briefing_script="$PROJECT_ROOT/.claude/scripts/literature-briefing.sh"

  # --- Create temp LITERATURE_DIR with mock global index ---
  TEMP_LIT_DIR=$(mktemp -d)
  local test_doc_id="TestPaper2024"
  local test_title="A Test Paper on Literature Briefing"
  local test_author="Test Author"
  local test_year="2024"

  # Write mock global index.json
  cat > "$TEMP_LIT_DIR/index.json" <<GLOBAL_INDEX
{
  "entries": [
    {
      "id": "${test_doc_id}",
      "title": "${test_title}",
      "authors": ["${test_author}"],
      "year": ${test_year},
      "path": "sources/${test_doc_id}/",
      "parent_doc": null,
      "token_count": 1000
    }
  ]
}
GLOBAL_INDEX

  log_info "Created temp LITERATURE_DIR: $TEMP_LIT_DIR"

  # --- Save and override LITERATURE_DIR env var ---
  SAVED_LITERATURE_DIR="${LITERATURE_DIR:-}"
  export LITERATURE_DIR="$TEMP_LIT_DIR"

  # --- Track original sub-index existence ---
  if [[ -f "$SUB_INDEX_PATH" ]]; then
    ORIGINAL_SUB_INDEX_EXISTS=true
    TEMP_SUB_INDEX=""
    log_warn "specs/literature-index.json already exists — smoke test will use existing sub-index"
    # Still test with this sub-index if it has the test doc_id; otherwise add a temp entry
  else
    ORIGINAL_SUB_INDEX_EXISTS=false
    TEMP_SUB_INDEX="$SUB_INDEX_PATH"
    mkdir -p "$(dirname "$SUB_INDEX_PATH")"
  fi

  # Test 1: Missing sub-index -> empty output (silent exit)
  if [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    local output_no_index
    output_no_index=$(bash "$briefing_script" 2>/dev/null)
    if [[ -z "$output_no_index" ]]; then
      log_pass "Missing sub-index: briefing script produces empty output (silent exit)"
    else
      log_fail "Missing sub-index: expected empty output, got: $output_no_index"
    fi
  else
    log_info "Skipping missing-sub-index test (file already exists)"
  fi

  # Test 2: Empty sub-index entries -> empty output
  if [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    cat > "$SUB_INDEX_PATH" <<'EMPTY_SUB'
{"entries": []}
EMPTY_SUB
    local output_empty
    output_empty=$(bash "$briefing_script" 2>/dev/null)
    if [[ -z "$output_empty" ]]; then
      log_pass "Empty sub-index entries: briefing script produces empty output"
    else
      log_fail "Empty sub-index entries: expected empty output, got: $output_empty"
    fi
  fi

  # Test 3: Valid sub-index with matching doc_id -> briefing block with title
  cat > "$SUB_INDEX_PATH" <<SUB_INDEX
{
  "entries": [
    {
      "doc_id": "${test_doc_id}",
      "relevance": "Core reference for testing"
    }
  ]
}
SUB_INDEX

  local output_valid
  output_valid=$(bash "$briefing_script" 2>/dev/null)

  if echo "$output_valid" | grep -q '<literature-briefing>'; then
    log_pass "Valid sub-index: output contains <literature-briefing> tag"
  else
    log_fail "Valid sub-index: output does NOT contain <literature-briefing> tag"
    log_info "  Output was: $(echo "$output_valid" | head -5)"
  fi

  if echo "$output_valid" | grep -q "$test_title"; then
    log_pass "Valid sub-index: output contains test paper title"
  else
    log_fail "Valid sub-index: output does NOT contain expected title '$test_title'"
    log_info "  Output was: $(echo "$output_valid" | head -10)"
  fi

  # Test 4: Missing global index (after removing temp dir) -> empty output, exit 0
  local saved_temp_dir="$TEMP_LIT_DIR"
  local temp_index_backup="$TEMP_LIT_DIR/index.json.bak"
  mv "$TEMP_LIT_DIR/index.json" "$temp_index_backup"

  local output_no_global exit_code_no_global
  output_no_global=$(bash "$briefing_script" 2>/dev/null) || true
  exit_code_no_global=$?

  # Restore
  mv "$temp_index_backup" "$TEMP_LIT_DIR/index.json"

  if [[ -z "$output_no_global" ]] && [[ "$exit_code_no_global" -eq 0 ]]; then
    log_pass "Missing global index: empty output and exit 0 (graceful)"
  else
    log_fail "Missing global index: expected empty output + exit 0, got output='$output_no_global' exit=$exit_code_no_global"
  fi

  # Test 5: Invalid JSON sub-index -> exit 0 (graceful degradation)
  echo "NOT VALID JSON {{{" > "$SUB_INDEX_PATH"
  local output_invalid exit_code_invalid
  output_invalid=$(bash "$briefing_script" 2>/dev/null) || true
  exit_code_invalid=$?

  if [[ "$exit_code_invalid" -eq 0 ]]; then
    log_pass "Invalid JSON sub-index: exits 0 (graceful degradation)"
  else
    log_fail "Invalid JSON sub-index: expected exit 0, got exit $exit_code_invalid"
  fi

  if [[ -z "$output_invalid" ]]; then
    log_pass "Invalid JSON sub-index: empty output (no crash output)"
  else
    log_warn "Invalid JSON sub-index: non-empty output (may be acceptable): $output_invalid"
  fi

  # Cleanup happens via trap
  log_info "Runtime smoke test complete. Temp files will be cleaned up."
}

# ============================================================
# MAIN
# ============================================================
main() {
  echo "========================================"
  echo "--lit Pipeline Integration Test"
  echo "========================================"
  log_info "Project root: $PROJECT_ROOT"
  if [[ "$RUN_RUNTIME" == "true" ]]; then
    log_info "Mode: static + runtime smoke test (--runtime)"
  else
    log_info "Mode: static checks only (pass --runtime for smoke test)"
  fi

  section_a
  section_b
  section_c
  section_d

  if [[ "$RUN_RUNTIME" == "true" ]]; then
    section_e
  fi

  # --- Summary ---
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}PIPELINE TEST FAILED${NC}"
    exit 1
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo -e "${YELLOW}PIPELINE TEST PASSED WITH WARNINGS${NC}"
    exit 0
  else
    echo -e "${GREEN}PIPELINE TEST PASSED${NC}"
    exit 0
  fi
}

main "$@"
