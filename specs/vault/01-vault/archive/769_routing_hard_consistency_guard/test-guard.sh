#!/usr/bin/env bash
# test-guard.sh — Fixture-based verification harness for check-extension-docs.sh
#
# Builds synthetic EXT_DIR trees in a temp dir and runs check-extension-docs.sh against them
# to verify each new check rule (A, B, C, D) fires on violations and is silent on clean fixtures.
#
# Usage: bash specs/769_routing_hard_consistency_guard/test-guard.sh
# Exit code: 0 = all assertions pass, 1 = one or more assertions failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_REAL="$(cd "$SCRIPT_DIR/../.." && pwd)"
GUARD_SCRIPT="$REPO_ROOT_REAL/.claude/scripts/check-extension-docs.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

# Run the guard against a custom EXT_DIR tree.
# Captures output to $RUN_OUTPUT and exit code to $RUN_EXIT.
RUN_OUTPUT=""
RUN_EXIT=0

run_guard() {
  local repo_root="$1"
  local ext_dir="$2"
  local tmpout
  tmpout=$(mktemp)
  REPO_ROOT="$repo_root" EXT_DIR="$ext_dir" bash "$GUARD_SCRIPT" > "$tmpout" 2>&1
  RUN_EXIT=$?
  RUN_OUTPUT=$(cat "$tmpout")
  rm -f "$tmpout"
}

assert_exit_nonzero() {
  local desc="$1"
  if [[ "$RUN_EXIT" -ne 0 ]]; then
    echo -e "${GREEN}PASS${NC}: $desc (correctly exited non-zero: $RUN_EXIT)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC}: $desc (expected exit non-zero, got 0)"
    echo "  Output: $(echo "$RUN_OUTPUT" | grep -E 'FAIL:|PASS:' | head -5)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_exit_zero() {
  local desc="$1"
  if [[ "$RUN_EXIT" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}: $desc (correctly exited 0)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC}: $desc (expected exit 0, got $RUN_EXIT)"
    echo "  Output: $(echo "$RUN_OUTPUT" | grep -E 'FAIL:|PASS:' | head -5)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_output_contains() {
  local desc="$1"
  local pattern="$2"
  if echo "$RUN_OUTPUT" | grep -q "$pattern"; then
    echo -e "${GREEN}PASS${NC}: $desc (contains: $pattern)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC}: $desc (missing pattern: $pattern)"
    echo "  Output snippet:"
    echo "$RUN_OUTPUT" | head -20 | sed 's/^/    /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_output_not_contains() {
  local desc="$1"
  local pattern="$2"
  if ! echo "$RUN_OUTPUT" | grep -q "$pattern"; then
    echo -e "${GREEN}PASS${NC}: $desc (correctly absent: $pattern)"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "${RED}FAIL${NC}: $desc (unexpected pattern found: $pattern)"
    echo "  Matching lines: $(echo "$RUN_OUTPUT" | grep "$pattern" | head -5)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Create a minimal valid extension manifest (routing_exempt to avoid routing block check)
make_manifest() {
  local ext_path="$1"
  local extra_json="${2:-}"
  mkdir -p "$ext_path"
  cat > "$ext_path/manifest.json" << EOF
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension for fixture harness",
  "routing_exempt": true,
  "provides": {
    "agents": [],
    "skills": [],
    "commands": [],
    "rules": [],
    "scripts": []
  }$extra_json
}
EOF
  echo "# Test Extension" > "$ext_path/EXTENSION.md"
  echo "# Test README" > "$ext_path/README.md"
}

# Create a skill dir with SKILL.md (optionally with subagent_type)
make_skill() {
  local ext_path="$1"
  local skill_name="$2"
  local agent_name="${3:-}"
  mkdir -p "$ext_path/skills/$skill_name"
  if [[ -n "$agent_name" ]]; then
    echo "subagent_type: \"$agent_name\"" > "$ext_path/skills/$skill_name/SKILL.md"
  else
    echo "# Skill" > "$ext_path/skills/$skill_name/SKILL.md"
  fi
}

echo "====================================="
echo "check-extension-docs.sh fixture tests"
echo "====================================="
echo

# -----------------------------------------------------------------------
# RULE A: Undeclared skill dirs
# -----------------------------------------------------------------------
echo "--- Rule A: Undeclared skill dirs ---"

# A-violation: extension with skill-undeclared/ not in provides.skills -> FAIL
TMP_A1=$(mktemp -d)
EXT_A1="$TMP_A1/.claude/extensions/test-ext"
make_manifest "$EXT_A1"
make_skill "$EXT_A1" "skill-undeclared"
mkdir -p "$TMP_A1/.claude/skills" "$TMP_A1/.claude/agents"

run_guard "$TMP_A1" "$TMP_A1/.claude/extensions"
assert_exit_nonzero "Rule A violation: exit non-zero"
assert_output_contains "Rule A violation: emits FAIL" "skill dir on disk NOT in provides.skills: skill-undeclared"
rm -rf "$TMP_A1"

# A-clean: extension with skill-declared/ IN provides.skills -> exit 0
TMP_A2=$(mktemp -d)
EXT_A2="$TMP_A2/.claude/extensions/test-ext"
mkdir -p "$EXT_A2"
cat > "$EXT_A2/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": [],
    "skills": ["skill-declared"],
    "commands": [],
    "rules": [],
    "scripts": []
  }
}
EOF
echo "# Test Extension" > "$EXT_A2/EXTENSION.md"
echo "# Test README" > "$EXT_A2/README.md"
make_skill "$EXT_A2" "skill-declared"
mkdir -p "$TMP_A2/.claude/skills" "$TMP_A2/.claude/agents"

run_guard "$TMP_A2" "$TMP_A2/.claude/extensions"
assert_exit_zero "Rule A clean: exit 0 when all dirs declared"
assert_output_not_contains "Rule A clean: no undeclared skill FAIL" "skill dir on disk NOT in provides.skills"
rm -rf "$TMP_A2"

echo

# -----------------------------------------------------------------------
# RULE B: Routing target not resolvable
# -----------------------------------------------------------------------
echo "--- Rule B: Routing target consistency ---"

# B-violation: routing target skill-nonexistent not in any provides.skills and not deployed -> FAIL
TMP_B1=$(mktemp -d)
EXT_B1="$TMP_B1/.claude/extensions/test-ext"
mkdir -p "$EXT_B1"
cat > "$EXT_B1/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "provides": {
    "agents": [],
    "skills": [],
    "commands": [],
    "rules": [],
    "scripts": []
  },
  "routing": {
    "implement": {
      "test": "skill-nonexistent"
    }
  }
}
EOF
echo "# Test Extension" > "$EXT_B1/EXTENSION.md"
echo "# Test README" > "$EXT_B1/README.md"
mkdir -p "$TMP_B1/.claude/skills" "$TMP_B1/.claude/agents"

run_guard "$TMP_B1" "$TMP_B1/.claude/extensions"
assert_exit_nonzero "Rule B violation: exit non-zero on unresolvable routing target"
assert_output_contains "Rule B violation: emits FAIL" "not resolvable"
assert_output_contains "Rule B violation: names the target" "skill-nonexistent"
rm -rf "$TMP_B1"

echo

# -----------------------------------------------------------------------
# RULE C: Routing target not deployed (install-gated severity)
# -----------------------------------------------------------------------
echo "--- Rule C: Deployment check (install-gated) ---"

# C-installed-undeployed: extension IS installed, routing target not deployed -> FAIL
TMP_C1=$(mktemp -d)
EXT_C1="$TMP_C1/.claude/extensions/test-ext"
mkdir -p "$EXT_C1"
cat > "$EXT_C1/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "provides": {
    "agents": [],
    "skills": ["skill-deployed-other", "skill-undeployed-target"],
    "commands": [],
    "rules": [],
    "scripts": []
  },
  "routing": {
    "implement": {
      "test": "skill-undeployed-target"
    }
  }
}
EOF
echo "# Test Extension" > "$EXT_C1/EXTENSION.md"
echo "# Test README" > "$EXT_C1/README.md"
make_skill "$EXT_C1" "skill-deployed-other"
make_skill "$EXT_C1" "skill-undeployed-target"
mkdir -p "$TMP_C1/.claude/agents"
# Deploy skill-deployed-other (makes ext "installed") but NOT skill-undeployed-target
mkdir -p "$TMP_C1/.claude/skills/skill-deployed-other"
echo "# deployed other skill" > "$TMP_C1/.claude/skills/skill-deployed-other/SKILL.md"

run_guard "$TMP_C1" "$TMP_C1/.claude/extensions"
assert_exit_nonzero "Rule C installed+undeployed: exit non-zero"
assert_output_contains "Rule C installed+undeployed: emits FAIL" "routing target not deployed (extension is installed)"
rm -rf "$TMP_C1"

# C-uninstalled-undeployed: extension NOT installed, routing target not deployed -> WARN only
TMP_C2=$(mktemp -d)
EXT_C2="$TMP_C2/.claude/extensions/test-ext"
mkdir -p "$EXT_C2"
cat > "$EXT_C2/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "provides": {
    "agents": [],
    "skills": ["skill-uninstalled-undeployed"],
    "commands": [],
    "rules": [],
    "scripts": []
  },
  "routing": {
    "implement": {
      "test": "skill-uninstalled-undeployed"
    }
  }
}
EOF
echo "# Test Extension" > "$EXT_C2/EXTENSION.md"
echo "# Test README" > "$EXT_C2/README.md"
make_skill "$EXT_C2" "skill-uninstalled-undeployed"
mkdir -p "$TMP_C2/.claude/skills" "$TMP_C2/.claude/agents"
# Nothing deployed (extension not installed)

run_guard "$TMP_C2" "$TMP_C2/.claude/extensions"
assert_exit_zero "Rule C uninstalled+undeployed routing: exit 0 (WARN only)"
assert_output_contains "Rule C uninstalled+undeployed: emits WARN" "WARN: routing target not deployed (extension not installed)"
assert_output_not_contains "Rule C uninstalled+undeployed: no FAIL for routing" "FAIL: routing target"
rm -rf "$TMP_C2"

# C-routing_hard lean-case: source skill present, extension uninstalled, target undeployed -> FAIL
TMP_C3=$(mktemp -d)
EXT_C3="$TMP_C3/.claude/extensions/test-ext"
mkdir -p "$EXT_C3"
cat > "$EXT_C3/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": [],
    "skills": ["skill-hard-undeployed"],
    "commands": [],
    "rules": [],
    "scripts": []
  },
  "routing_hard": {
    "implement": {
      "test": "skill-hard-undeployed"
    }
  }
}
EOF
echo "# Test Extension" > "$EXT_C3/EXTENSION.md"
echo "# Test README" > "$EXT_C3/README.md"
make_skill "$EXT_C3" "skill-hard-undeployed"
mkdir -p "$TMP_C3/.claude/skills" "$TMP_C3/.claude/agents"
# Extension not installed (no deployed skills), but routing_hard declared

run_guard "$TMP_C3" "$TMP_C3/.claude/extensions"
assert_exit_nonzero "Rule C routing_hard lean-case: exit non-zero"
assert_output_contains "Rule C routing_hard lean-case: emits FAIL with correct message" \
  "routing_hard target declared but not deployed (and extension not installed)"
rm -rf "$TMP_C3"

echo

# -----------------------------------------------------------------------
# RULE D: Deployed skills must reference agents that exist
# -----------------------------------------------------------------------
echo "--- Rule D: Deployed skill agent existence ---"

# D-violation: deployed skill references ghost-agent (no .md in agents/) -> FAIL
TMP_D1=$(mktemp -d)
EXT_D1="$TMP_D1/.claude/extensions/test-ext"
mkdir -p "$EXT_D1"
cat > "$EXT_D1/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": [],
    "skills": ["skill-with-ghost-agent"],
    "commands": [],
    "rules": [],
    "scripts": []
  }
}
EOF
echo "# Test Extension" > "$EXT_D1/EXTENSION.md"
echo "# Test README" > "$EXT_D1/README.md"
make_skill "$EXT_D1" "skill-with-ghost-agent" "ghost-agent"
mkdir -p "$TMP_D1/.claude/agents"
# Deploy the skill (but ghost-agent.md does NOT exist)
mkdir -p "$TMP_D1/.claude/skills/skill-with-ghost-agent"
echo 'subagent_type: "ghost-agent"' > "$TMP_D1/.claude/skills/skill-with-ghost-agent/SKILL.md"

run_guard "$TMP_D1" "$TMP_D1/.claude/extensions"
assert_exit_nonzero "Rule D missing agent: exit non-zero"
assert_output_contains "Rule D missing agent: emits FAIL" "ghost-agent NOT in .claude/agents"
rm -rf "$TMP_D1"

# D-clean: deployed skill references real-agent (agent .md exists) -> exit 0
TMP_D2=$(mktemp -d)
EXT_D2="$TMP_D2/.claude/extensions/test-ext"
mkdir -p "$EXT_D2"
cat > "$EXT_D2/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": ["real-agent.md"],
    "skills": ["skill-with-real-agent"],
    "commands": [],
    "rules": [],
    "scripts": []
  }
}
EOF
echo "# Test Extension" > "$EXT_D2/EXTENSION.md"
echo "# Test README" > "$EXT_D2/README.md"
make_skill "$EXT_D2" "skill-with-real-agent" "real-agent"
mkdir -p "$EXT_D2/agents"
echo "# Real agent" > "$EXT_D2/agents/real-agent.md"
# Deploy the skill AND the agent
mkdir -p "$TMP_D2/.claude/skills/skill-with-real-agent"
echo 'subagent_type: "real-agent"' > "$TMP_D2/.claude/skills/skill-with-real-agent/SKILL.md"
mkdir -p "$TMP_D2/.claude/agents"
echo "# Real agent" > "$TMP_D2/.claude/agents/real-agent.md"

run_guard "$TMP_D2" "$TMP_D2/.claude/extensions"
assert_exit_zero "Rule D real agent: exit 0"
assert_output_not_contains "Rule D real agent: no FAIL for existing agent" "NOT in .claude/agents"
rm -rf "$TMP_D2"

# D-skip-direct-execution: skill with no subagent_type (direct-execution) -> no FAIL
TMP_D3=$(mktemp -d)
EXT_D3="$TMP_D3/.claude/extensions/test-ext"
mkdir -p "$EXT_D3"
cat > "$EXT_D3/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": [],
    "skills": ["skill-direct-execution"],
    "commands": [],
    "rules": [],
    "scripts": []
  }
}
EOF
echo "# Test Extension" > "$EXT_D3/EXTENSION.md"
echo "# Test README" > "$EXT_D3/README.md"
make_skill "$EXT_D3" "skill-direct-execution"  # no agent_name arg
# Deploy the skill (no subagent_type in SKILL.md)
mkdir -p "$TMP_D3/.claude/skills/skill-direct-execution"
echo "# Direct execution skill (no subagent_type)" > "$TMP_D3/.claude/skills/skill-direct-execution/SKILL.md"
mkdir -p "$TMP_D3/.claude/agents"

run_guard "$TMP_D3" "$TMP_D3/.claude/extensions"
assert_exit_zero "Rule D direct-execution: exit 0 (no agent to check)"
assert_output_not_contains "Rule D direct-execution: no FAIL" "NOT in .claude/agents"
rm -rf "$TMP_D3"

echo

# -----------------------------------------------------------------------
# Full clean fixture: all rules pass -> exit 0
# -----------------------------------------------------------------------
echo "--- Full clean fixture ---"
TMP_CLEAN=$(mktemp -d)
EXT_CLEAN="$TMP_CLEAN/.claude/extensions/test-ext"
mkdir -p "$EXT_CLEAN"
cat > "$EXT_CLEAN/manifest.json" << 'EOF'
{
  "name": "test-ext",
  "version": "1.0.0",
  "description": "Test extension",
  "routing_exempt": true,
  "provides": {
    "agents": ["real-agent.md"],
    "skills": ["skill-clean"],
    "commands": [],
    "rules": [],
    "scripts": []
  }
}
EOF
echo "# Test Extension" > "$EXT_CLEAN/EXTENSION.md"
echo "# Test README" > "$EXT_CLEAN/README.md"
make_skill "$EXT_CLEAN" "skill-clean" "real-agent"
mkdir -p "$EXT_CLEAN/agents"
echo "# Real agent" > "$EXT_CLEAN/agents/real-agent.md"
mkdir -p "$TMP_CLEAN/.claude/skills/skill-clean"
echo 'subagent_type: "real-agent"' > "$TMP_CLEAN/.claude/skills/skill-clean/SKILL.md"
mkdir -p "$TMP_CLEAN/.claude/agents"
echo "# Real agent" > "$TMP_CLEAN/.claude/agents/real-agent.md"

run_guard "$TMP_CLEAN" "$TMP_CLEAN/.claude/extensions"
assert_exit_zero "Full clean fixture: exit 0"
assert_output_not_contains "Full clean fixture: no FAILs" "  FAIL:"
rm -rf "$TMP_CLEAN"

echo

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "====================================="
echo "Harness Results"
echo "====================================="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "FAIL: $FAIL_COUNT assertion(s) failed"
  exit 1
else
  echo "PASS: all assertions passed"
  exit 0
fi
