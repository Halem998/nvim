#!/usr/bin/env bash
# lint-contract-compliance.sh - Static compliance checks for hard-mode behavioral contracts
#
# Validates that hard-mode agents, skills, and contract files structurally comply
# with the H-technique contracts defined in .claude/context/contracts/.
#
# WHAT THIS SCRIPT CHECKS (Tier 1 static file-content checks):
#   A. Hard agents reference their required contracts in Context References sections
#   B. All 5 contract files exist and contain H-technique identifiers
#   C. Each hard skill dispatches to the correct hard agent (SKILL.md wiring)
#   D. skill-orchestrate-hard/SKILL.md contains convergence policing fields
#   E. general-implementation-hard-agent.md contains H2 vocabulary
#   F. index.json has at least one context entry per hard agent
#
# WHAT THIS SCRIPT DOES NOT CHECK (Tier 3 runtime behavior -- deferred):
#   - Whether agents actually honor read budgets at runtime
#   - Whether forbidden conclusions are actually absent from outputs
#   - Whether territory boundaries are enforced during parallel dispatch
#   - Whether handoff JSON is actually written at dispatch end
#   - Whether churn detection actually fires on repeated-target signatures
#
# Usage: lint-contract-compliance.sh [--verbose] [--help]
#
# Exit codes:
#   0 - All checks pass
#   1 - One or more checks failed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: lint-contract-compliance.sh [--verbose] [--help]"
      echo ""
      echo "Runs static compliance checks for hard-mode behavioral contracts."
      echo ""
      echo "Checks:"
      echo "  A. Hard agent contract @-references"
      echo "  B. Contract file existence and H-technique identifiers"
      echo "  C. Hard skill -> hard agent dispatch wiring"
      echo "  D. Convergence policing fields in skill-orchestrate-hard"
      echo "  E. H2 vocabulary in general-implementation-hard-agent"
      echo "  F. index.json contract coverage for hard agents"
      echo ""
      echo "Exit codes: 0 = all pass, 1 = failures found"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1. Use --help for usage."
      exit 2
      ;;
  esac
done

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARNINGS=$((WARNINGS + 1))
}

log_info() {
  $VERBOSE && echo -e "${BLUE}[INFO]${NC} $1" || true
}

# ---------------------------------------------------------------------------
# Check A: Hard agent contract @-references
# Each hard agent must reference its required contracts in its Context References section
# ---------------------------------------------------------------------------
check_a_hard_agent_contract_references() {
  echo ""
  echo "--- Check A: Hard agent contract @-references ---"

  # research agent requires: anti-analysis, reference-grounding
  local research_agent="$CLAUDE_DIR/agents/general-research-hard-agent.md"
  if [[ ! -f "$research_agent" ]]; then
    log_fail "general-research-hard-agent.md not found"
  else
    log_info "Checking $research_agent"
    if grep -qF "@.claude/context/contracts/anti-analysis.md" "$research_agent"; then
      log_pass "general-research-hard-agent: references anti-analysis contract"
    else
      log_fail "general-research-hard-agent: missing @-reference to anti-analysis.md"
    fi
    if grep -qF "@.claude/context/contracts/reference-grounding.md" "$research_agent"; then
      log_pass "general-research-hard-agent: references reference-grounding contract"
    else
      log_fail "general-research-hard-agent: missing @-reference to reference-grounding.md"
    fi
  fi

  # planner agent requires: reference-grounding
  local planner_agent="$CLAUDE_DIR/agents/planner-hard-agent.md"
  if [[ ! -f "$planner_agent" ]]; then
    log_fail "planner-hard-agent.md not found"
  else
    log_info "Checking $planner_agent"
    if grep -qF "@.claude/context/contracts/reference-grounding.md" "$planner_agent"; then
      log_pass "planner-hard-agent: references reference-grounding contract"
    else
      log_fail "planner-hard-agent: missing @-reference to reference-grounding.md"
    fi
  fi

  # implementation agent requires: anti-analysis, wrap-up, territory
  local impl_agent="$CLAUDE_DIR/agents/general-implementation-hard-agent.md"
  if [[ ! -f "$impl_agent" ]]; then
    log_fail "general-implementation-hard-agent.md not found"
  else
    log_info "Checking $impl_agent"
    if grep -qF "@.claude/context/contracts/anti-analysis.md" "$impl_agent"; then
      log_pass "general-implementation-hard-agent: references anti-analysis contract"
    else
      log_fail "general-implementation-hard-agent: missing @-reference to anti-analysis.md"
    fi
    if grep -qF "@.claude/context/contracts/wrap-up.md" "$impl_agent"; then
      log_pass "general-implementation-hard-agent: references wrap-up contract"
    else
      log_fail "general-implementation-hard-agent: missing @-reference to wrap-up.md"
    fi
    if grep -qF "@.claude/context/contracts/territory.md" "$impl_agent"; then
      log_pass "general-implementation-hard-agent: references territory contract"
    else
      log_fail "general-implementation-hard-agent: missing @-reference to territory.md"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Check B: Contract file existence and H-technique identifiers
# All 5 contract files must exist and contain their respective H-technique identifier
# ---------------------------------------------------------------------------
check_b_contract_files() {
  echo ""
  echo "--- Check B: Contract file existence and H-technique identifiers ---"

  local contracts_dir="$CLAUDE_DIR/context/contracts"

  declare -A CONTRACT_FILES=(
    ["anti-analysis.md"]="H2"
    ["reference-grounding.md"]="H3"
    ["convergence.md"]="H6"
    ["territory.md"]="H7"
    ["wrap-up.md"]="H9"
  )

  for contract_file in "${!CONTRACT_FILES[@]}"; do
    local technique="${CONTRACT_FILES[$contract_file]}"
    local full_path="$contracts_dir/$contract_file"

    if [[ ! -f "$full_path" ]]; then
      log_fail "Contract file missing: contracts/$contract_file"
    else
      log_info "Checking $full_path for $technique identifier"
      if grep -qE "^# .*\($technique\)|$technique:" "$full_path" 2>/dev/null; then
        log_pass "contracts/$contract_file: contains $technique identifier"
      elif grep -qF "$technique" "$full_path" 2>/dev/null; then
        log_pass "contracts/$contract_file: contains $technique reference"
      else
        log_fail "contracts/$contract_file: missing $technique identifier"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Check C: Hard skill -> hard agent dispatch wiring
# Each hard skill SKILL.md must dispatch to the correct hard agent
# ---------------------------------------------------------------------------
check_c_hard_skill_dispatch() {
  echo ""
  echo "--- Check C: Hard skill -> hard agent dispatch wiring ---"

  declare -A SKILL_AGENTS=(
    ["skill-researcher-hard"]="general-research-hard-agent"
    ["skill-planner-hard"]="planner-hard-agent"
    ["skill-implementer-hard"]="general-implementation-hard-agent"
  )

  for skill in "${!SKILL_AGENTS[@]}"; do
    local expected_agent="${SKILL_AGENTS[$skill]}"
    local skill_file="$CLAUDE_DIR/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found"
    else
      log_info "Checking $skill_file for reference to $expected_agent"
      if grep -q "$expected_agent" "$skill_file" 2>/dev/null; then
        log_pass "$skill -> $expected_agent (wired)"
      else
        log_fail "$skill: does not reference $expected_agent"
      fi
    fi
  done

  # skill-orchestrate-hard is a special case -- it dispatches to all hard agents
  local orchestrate_skill="$CLAUDE_DIR/skills/skill-orchestrate-hard/SKILL.md"
  if [[ ! -f "$orchestrate_skill" ]]; then
    log_fail "skill-orchestrate-hard: SKILL.md not found"
  else
    log_pass "skill-orchestrate-hard: SKILL.md exists"
  fi
}

# ---------------------------------------------------------------------------
# Check D: Convergence policing fields in skill-orchestrate-hard/SKILL.md
# Churn state file must declare total_churn, target_churn, adversarial_triggers fields
# ---------------------------------------------------------------------------
check_d_convergence_policing() {
  echo ""
  echo "--- Check D: Convergence policing fields in skill-orchestrate-hard ---"

  local skill_file="$CLAUDE_DIR/skills/skill-orchestrate-hard/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    log_fail "skill-orchestrate-hard/SKILL.md not found -- skipping convergence checks"
    return
  fi

  log_info "Checking for convergence policing fields in $skill_file"

  for field in "total_churn" "target_churn" "adversarial_triggers"; do
    if grep -qF "$field" "$skill_file" 2>/dev/null; then
      log_pass "skill-orchestrate-hard: contains '$field' churn field"
    else
      log_fail "skill-orchestrate-hard: missing '$field' convergence policing field"
    fi
  done
}

# ---------------------------------------------------------------------------
# Check E: H2 vocabulary in general-implementation-hard-agent.md
# The implementation hard agent must mention key H2 contract terms
# ---------------------------------------------------------------------------
check_e_h2_vocabulary() {
  echo ""
  echo "--- Check E: H2 vocabulary in general-implementation-hard-agent ---"

  local impl_agent="$CLAUDE_DIR/agents/general-implementation-hard-agent.md"

  if [[ ! -f "$impl_agent" ]]; then
    log_fail "general-implementation-hard-agent.md not found -- skipping H2 vocabulary checks"
    return
  fi

  log_info "Checking H2 vocabulary in $impl_agent"

  # forbidden conclusions (exact phrase or close variant)
  if grep -qiE "Forbidden [Cc]onclusions|forbidden-conclusions|forbidden conclusions" "$impl_agent" 2>/dev/null; then
    log_pass "general-implementation-hard-agent: contains 'Forbidden Conclusions' H2 term"
  else
    log_fail "general-implementation-hard-agent: missing 'Forbidden Conclusions' H2 vocabulary"
  fi

  # defect bar (exact phrase or variant)
  if grep -qiE "[Dd]efect [Bb]ar|defect-bar" "$impl_agent" 2>/dev/null; then
    log_pass "general-implementation-hard-agent: contains 'Defect Bar' H2 term"
  else
    log_fail "general-implementation-hard-agent: missing 'Defect Bar' H2 vocabulary"
  fi

  # settled-design (H2 concept: re-opening settled decisions requires counterexample)
  if grep -qiE "settled[- ][Dd]esign|settled design" "$impl_agent" 2>/dev/null; then
    log_pass "general-implementation-hard-agent: contains 'settled-design' H2 term"
  else
    log_warn "general-implementation-hard-agent: 'settled-design' term not found (optional H2 vocabulary)"
  fi
}

# ---------------------------------------------------------------------------
# Check F: index.json contract coverage for hard agents
# Each hard agent must appear in at least one context entry's load_when.agents array
# ---------------------------------------------------------------------------
check_f_index_coverage() {
  echo ""
  echo "--- Check F: index.json contract coverage for hard agents ---"

  local index_file="$CLAUDE_DIR/context/index.json"

  if [[ ! -f "$index_file" ]]; then
    log_fail "index.json not found at $index_file"
    return
  fi

  if ! jq empty "$index_file" 2>/dev/null; then
    log_fail "index.json is not valid JSON"
    return
  fi

  local hard_agents=(
    "general-research-hard-agent"
    "planner-hard-agent"
    "general-implementation-hard-agent"
  )

  for agent in "${hard_agents[@]}"; do
    local count
    count=$(jq -r "[.entries[] | select(.load_when.agents[]? == \"$agent\")] | length" "$index_file" 2>/dev/null || echo "0")
    if [[ "$count" -gt 0 ]]; then
      log_pass "index.json: $agent has $count context entries"
    else
      log_warn "index.json: $agent has 0 context entries (contracts not indexed?)"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "========================================"
  echo "Contract Compliance Lint"
  echo "========================================"
  echo "Project root: $PROJECT_ROOT"

  check_a_hard_agent_contract_references
  check_b_contract_files
  check_c_hard_skill_dispatch
  check_d_convergence_policing
  check_e_h2_vocabulary
  check_f_index_coverage

  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}CONTRACT COMPLIANCE LINT FAILED ($FAILED failures)${NC}"
    echo ""
    echo "Reference: .claude/context/contracts/ for contract definitions"
    exit 1
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo -e "${YELLOW}CONTRACT COMPLIANCE LINT PASSED WITH WARNINGS${NC}"
    exit 0
  else
    echo -e "${GREEN}CONTRACT COMPLIANCE LINT PASSED${NC}"
    exit 0
  fi
}

main "$@"
