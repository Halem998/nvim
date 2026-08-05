#!/usr/bin/env bash
# test-lint-agent-contracts.sh - Fixture-driven regression suite for lint-agent-contracts.sh.
#
# Builds an isolated scratch repo tree (mktemp -d) with a minimal agent-system/extensions/
# layout, populates it with positive and negative fixture agent files, and runs the real
# lint-agent-contracts.sh against it via REPO_ROOT=<scratch> (the same source-store invocation
# override the lint script itself documents), asserting on its EXIT CODE and, where relevant,
# on specific [FAIL]/[PASS] lines in its stdout. The lint script is never instrumented or
# modified for testability -- it never learns it is under test.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SRC="$SCRIPT_DIR/../lint/lint-agent-contracts.sh"
FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/no-task-references-bullet.md"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$LINT_SRC" ]; then
  echo "ERROR: expected lint-agent-contracts.sh at $LINT_SRC" >&2
  exit 1
fi
if [ ! -f "$FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $FRAGMENT_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Mirror the real repo layout the lint script expects, relative to the scratch REPO_ROOT.
mkdir -p "$WORKDIR/agent-system/extensions/core/agents"
mkdir -p "$WORKDIR/agent-system/extensions/core/context/contracts"
mkdir -p "$WORKDIR/agent-system/extensions/core/docs/reference/standards"
cp "$FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/contracts/no-task-references-bullet.md"

BULLET_LINE='Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead'

# run_lint: invokes the real lint script against the scratch tree, capturing stdout+exit code.
run_lint() {
  local out code
  out="$(REPO_ROOT="$WORKDIR" bash "$LINT_SRC" --verbose 2>&1)"
  code=$?
  printf '%s\x1e%s' "$code" "$out"
}

# =====================================================================
# Fixture: rogue-key agent (allowed-tools:) -- must fail Check A
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/rogue-key-agent.md" <<EOF
---
name: rogue-key-agent
description: fixture agent with an invalid allowed-tools: key
model: sonnet
allowed-tools: Read, Write
---

# Rogue Key Agent

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: agent missing model: -- must fail Check B
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/no-model-agent.md" <<EOF
---
name: no-model-agent
description: fixture agent with no model field
---

# No Model Agent

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: implementation agent without the bullet -- must fail Check C.
# Named to match the lint's IN_SCOPE_RELATIVE_PATHS allowlist entry
# core/agents/general-implementation-agent.md (the lint checks this exact path).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/general-implementation-agent.md" <<EOF
---
name: general-implementation-agent
description: fixture standing in for the real general-implementation-agent, missing the bullet
model: sonnet
---

# General Implementation Agent

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Negative fixture: frontmatter-less file in an agents/-named directory -- must NOT be treated
# as a dispatchable agent (no Check A/B finding referencing it).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/README.md" <<EOF
# Agents

Not a dispatchable agent -- no frontmatter block at all.
EOF

# =====================================================================
# Negative fixture: fully compliant agent -- must pass all three checks, no findings against it.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/compliant-agent.md" <<EOF
---
name: compliant-agent
description: fixture agent that fully complies with all three checks
model: sonnet
tools: Read, Write
---

# Compliant Agent

## Critical Requirements

**MUST NOT**:
1. $BULLET_LINE
EOF

result="$(run_lint)"
code="${result%%$'\x1e'*}"
out="${result#*$'\x1e'}"

info "lint exit code: $code"

# The scratch fixture set is deliberately non-compliant overall (rogue-key-agent and
# no-model-agent are real violations), so the lint MUST exit 1.
if [ "$code" -eq 1 ]; then
  pass "lint exits 1 against a fixture tree with real violations"
else
  fail "lint expected exit 1, got exit=$code"
fi

# Positive: rogue-key-agent.md fails Check A on the invalid key.
if echo "$out" | grep -qF "rogue-key-agent.md: declares invalid key 'allowed-tools:'"; then
  pass "positive: rogue-key-agent.md fails Check A (invalid allowed-tools: key)"
else
  fail "positive: expected Check A failure for rogue-key-agent.md, not found in output"
fi

# Positive: no-model-agent.md fails Check B on missing model.
if echo "$out" | grep -qF "no-model-agent.md: missing required 'model:' field"; then
  pass "positive: no-model-agent.md fails Check B (missing model:)"
else
  fail "positive: expected Check B failure for no-model-agent.md, not found in output"
fi

# Positive: general-implementation-agent.md (fixture, no bullet) fails Check C.
if echo "$out" | grep -qF "core/agents/general-implementation-agent.md: missing the no-task-references MUST-NOT bullet"; then
  pass "positive: general-implementation-agent.md fixture fails Check C (missing bullet)"
else
  fail "positive: expected Check C failure for general-implementation-agent.md, not found in output"
fi

# Negative: README.md (no frontmatter) produces no Check A/B finding against it.
if echo "$out" | grep -qF "README.md:"; then
  fail "negative: README.md (frontmatter-less) was incorrectly treated as a dispatchable agent"
else
  pass "negative: README.md (frontmatter-less) produces no finding (correctly excluded)"
fi

# Negative: compliant-agent.md produces no FAIL line against it.
if echo "$out" | grep -F "compliant-agent.md" | grep -q "FAIL"; then
  fail "negative: compliant-agent.md unexpectedly failed a check"
else
  pass "negative: compliant-agent.md produces no FAIL against it"
fi

# =====================================================================
# Fragment-missing fixture: Check C must fail loudly, by name, when the fragment file itself
# is absent -- never a silent skip.
# =====================================================================
FRAGDIR="$(mktemp -d)"
mkdir -p "$FRAGDIR/agent-system/extensions/core/agents"
mkdir -p "$FRAGDIR/agent-system/extensions/core/docs/reference/standards"
cat > "$FRAGDIR/agent-system/extensions/core/agents/placeholder-agent.md" <<EOF
---
name: placeholder-agent
description: minimal fixture so the agents root is non-empty
model: sonnet
---

# Placeholder Agent
EOF
frag_out="$(REPO_ROOT="$FRAGDIR" bash "$LINT_SRC" --verbose 2>&1)"
frag_code=$?
rm -rf "$FRAGDIR"

if [ "$frag_code" -eq 1 ] && echo "$frag_out" | grep -qF "canonical fragment not found"; then
  pass "fragment-missing: Check C fails loudly by name when the fragment file is absent"
else
  fail "fragment-missing: expected exit 1 + named fragment-missing failure, got exit=$frag_code"
fi

# =====================================================================
# --help and unknown-argument fixtures
# =====================================================================
help_out="$(bash "$LINT_SRC" --help 2>&1)"
help_code=$?
if [ "$help_code" -eq 0 ] && echo "$help_out" | grep -qF "Usage: lint-agent-contracts.sh"; then
  pass "--help: exits 0 and prints usage"
else
  fail "--help: expected exit 0 + usage text, got exit=$help_code"
fi

bash "$LINT_SRC" --bogus-flag >/dev/null 2>&1
unknown_code=$?
if [ "$unknown_code" -eq 2 ]; then
  pass "unknown argument: exits 2"
else
  fail "unknown argument: expected exit 2, got exit=$unknown_code"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
