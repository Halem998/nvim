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
#   F - id/FTS namespace unification regression tests (opt-in via --runtime): ingest-then-brief
#       shape, --validate schema-shape/divergence detection, project-filtered-search bridge.
#       A sibling to Section E (not an extension of it) -- needs its own sqlite fixture and a
#       SKILL.md bash-block extraction Section E's infra has no use for. Resolves the scripts
#       and SKILL.md it exercises relative to its OWN SCRIPT_DIR (never the hardcoded deployed
#       .claude/ path Section E uses), so it always tests whichever copy -- source-store or
#       deployed -- it is itself being run from.

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
# Resolves correctly from two independent locations: the deployed copy
# (.claude/scripts/test-lit-pipeline.sh, two levels above .claude/) and the source-store copy
# (agent-system/extensions/literature/scripts/test-lit-pipeline.sh, four levels above the repo
# root). Rather than hardcode either depth, walk upward from SCRIPT_DIR to the nearest ancestor
# that contains a .claude/ directory -- true of the repo root in both cases.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=""
_candidate="$SCRIPT_DIR"
for _ in 1 2 3 4 5 6; do
  if [[ -d "$_candidate/.claude" ]]; then
    PROJECT_ROOT="$_candidate"
    break
  fi
  _parent="$(dirname "$_candidate")"
  [[ "$_parent" == "$_candidate" ]] && break
  _candidate="$_parent"
done
unset _candidate _parent
if [[ -z "$PROJECT_ROOT" ]]; then
  # Fall back to the historical two-levels-up assumption so the original failure mode/message
  # is preserved when no ancestor has a .claude/ directory at all.
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

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
TEMP_LIT_DIR_F=""

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
  # Section F's own scratch corpus (separate from Section E's TEMP_LIT_DIR)
  if [[ -n "$TEMP_LIT_DIR_F" ]] && [[ -d "$TEMP_LIT_DIR_F" ]]; then
    rm -rf "$TEMP_LIT_DIR_F"
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

  # Check if the literature extension is loaded; if not, skip with info -- mirrors Section B/C's
  # existing "extension not loaded" guard for cslib. Without this guard, a repo that simply never
  # loaded the literature extension would hard-fail here instead of gracefully skipping.
  if [[ ! -d "$PROJECT_ROOT/.claude/extensions/literature" ]]; then
    log_info "Literature extension not loaded in this project — skipping Section A"
    return
  fi

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

  # Six skills now delegate Section D's branching to ONE shared, directly-executable block
  # (context/patterns/lit-stage4a-flow.md) rather than each carrying its own inline copy of the
  # literature-index.json / literature-create-setup-task checks -- see CLAUDE.md's "Interactive
  # Sub-Index Setup Detection" section. A skill file satisfies each check below either directly
  # (inline pattern present) or indirectly (it imports the shared flow file, which itself carries
  # the pattern) -- both are valid wiring shapes.
  local shared_flow_file="$PROJECT_ROOT/.claude/context/patterns/lit-stage4a-flow.md"

  for skill in "${skills[@]}"; do
    local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found at $skill_file"
      continue
    fi

    local imports_shared_flow=false
    if grep -q 'lit-stage4a-flow\.md' "$skill_file" 2>/dev/null; then
      imports_shared_flow=true
    fi

    # Check 1: literature-index.json sub-index detection (direct or via shared flow import)
    if grep -q 'literature-index\.json' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-index.json sub-index check found (inline)"
    elif [[ "$imports_shared_flow" == "true" ]] && [[ -f "$shared_flow_file" ]] \
        && grep -q 'literature-index\.json' "$shared_flow_file" 2>/dev/null; then
      log_pass "$skill: literature-index.json sub-index check found (via lit-stage4a-flow.md import)"
    else
      log_fail "$skill: literature-index.json sub-index check NOT found (inline or via shared flow import)"
    fi

    # Check 2: literature-create-setup-task reference (direct or via shared flow import)
    if grep -q 'literature-create-setup-task' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-create-setup-task reference found (inline)"
    elif [[ "$imports_shared_flow" == "true" ]] && [[ -f "$shared_flow_file" ]] \
        && grep -q 'literature-create-setup-task' "$shared_flow_file" 2>/dev/null; then
      log_pass "$skill: literature-create-setup-task reference found (via lit-stage4a-flow.md import)"
    else
      log_fail "$skill: literature-create-setup-task reference NOT found (inline or via shared flow import)"
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
# SECTION F: id/FTS namespace unification regression tests (opt-in via --runtime)
# ============================================================
# The Section E fixture above uses one id (TestPaper2024) for both the global-index .id and
# the sub-index doc_id, always -- it could never catch a regression in the .id-vs-
# chunks_data.doc_id divergence class this section guards. Case 4's fixture below is
# deliberately id-less (doc_id only) so a future .id-only regression fails a test here.
#
# NOTE: a companion coverage-marker regression (asserting a deliberately-unresolvable doc_id
# drives the lit-coverage marker to report the failure rather than falsely reporting
# sparse=false) is a distinct, separately-tracked defect and is intentionally out of scope for
# this section.
section_f() {
  echo ""
  log_info "Section F: id/FTS namespace unification regression tests (--runtime)"
  echo "----------------------------------------"

  local search_script="$SCRIPT_DIR/literature-search.sh"
  local briefing_script_f="$SCRIPT_DIR/literature-briefing.sh"
  local skill_md_f="$SCRIPT_DIR/../skills/skill-literature/SKILL.md"

  if [[ ! -x "$search_script" ]] || [[ ! -x "$briefing_script_f" ]] || [[ ! -f "$skill_md_f" ]]; then
    log_fail "Section F: required script(s) or SKILL.md not found relative to $SCRIPT_DIR"
    return
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    log_warn "Section F: sqlite3 not available -- skipping (cannot build a chunks_data fixture)"
    return
  fi

  # --- Extract the CURRENT Validate Step 1/2/2b bash blocks from SKILL.md into a runnable
  # script, so Cases 2 and 4 exercise the same code that ships, not a second,
  # drift-prone reimplementation of the divergence/schema-shape logic. ---
  local validate_extract
  validate_extract=$(mktemp)
  python3 - "$skill_md_f" "$validate_extract" <<'PYEOF'
import re, sys
skill_path, out_path = sys.argv[1], sys.argv[2]
with open(skill_path) as f:
    text = f.read()
m = re.search(r"### Validate Step 1.*?(?=### Validate Step 3)", text, re.S)
if not m:
    sys.exit(1)
blocks = re.findall(r"```bash\n(.*?)```", m.group(0), re.S)
with open(out_path, "w") as f:
    f.write("#!/usr/bin/env bash\nset -uo pipefail\n\n")
    f.write("\n\n".join(blocks))
    f.write("""
echo "___SCHEMA_SHAPE_DEFECTS_COUNT___${#schema_shape_defects[@]}"
for x in "${schema_shape_defects[@]}"; do echo "___SCHEMA_SHAPE_DEFECT___$x"; done
echo "___STALE_ENTRIES_COUNT___${#stale_entries[@]}"
for x in "${stale_entries[@]}"; do echo "___STALE_ENTRY___$x"; done
echo "___DIVERGENCE_FTS_ONLY_COUNT___${#divergence_fts_only[@]}"
for x in "${divergence_fts_only[@]}"; do echo "___DIVERGENCE_FTS_ONLY___$x"; done
echo "___DIVERGENCE_INDEX_ONLY_COUNT___${#divergence_index_only[@]}"
for x in "${divergence_index_only[@]}"; do echo "___DIVERGENCE_INDEX_ONLY___$x"; done
""")
PYEOF
  if [[ ! -s "$validate_extract" ]]; then
    log_fail "Section F: could not extract Validate Step 1/2/2b logic from SKILL.md"
    rm -f "$validate_extract"
    return
  fi

  TEMP_LIT_DIR_F=$(mktemp -d)
  mkdir -p "$TEMP_LIT_DIR_F/sources/case1_doc" "$TEMP_LIT_DIR_F/sources/case3_fts_id"

  # --- Shared fixture index: Case 1 (realistic post-fix parent+children shape), Case 2
  # (parent with zero FTS coverage under either lookup strategy -- genuine divergence), Case 3
  # (curated .id differs from FTS doc_id, bridged via .path; project_tags set) ---
  cat > "$TEMP_LIT_DIR_F/index.json" <<'CASE_INDEX'
{
  "entries": [
    {
      "doc_id": "case1_doc", "parent_doc": null,
      "path": "sources/case1_doc/", "title": "Case One Regression Document",
      "authors": ["Regression Tester"], "year": 2026, "metadata_status": "resolved",
      "token_count": 0, "chunk_count": 3, "doc_type": "paper", "source_format": "pdf",
      "keywords": ["regression"],
      "summary": "Fixture matching the post-fix literature-ingest.sh output shape, deliberately without a .id key on the parent (doc_id only) so this case is revert-sensitive to the literature-briefing.sh .id-tolerance fix, not merely illustrative."
    },
    {
      "id": "c1chunk1", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0001.md", "title": "Section 1",
      "keywords": ["regression"], "summary": "Chunk 1 summary.", "token_count": 100
    },
    {
      "id": "c1chunk2", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0002.md", "title": "Section 2",
      "keywords": ["regression"], "summary": "Chunk 2 summary.", "token_count": 100
    },
    {
      "id": "c1chunk3", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0003.md", "title": "Section 3",
      "keywords": ["regression"], "summary": "Chunk 3 summary.", "token_count": 100
    },
    {
      "id": "case2_orphan", "doc_id": "case2_orphan", "parent_doc": null,
      "path": "sources/case2_orphan_dir/", "title": "Case Two Orphan Document",
      "authors": [], "year": null, "token_count": 0, "chunk_count": 0,
      "doc_type": "paper", "source_format": "pdf", "keywords": [],
      "summary": "Neither .id nor its path-derived dir key has any FTS chunks -- genuine divergence."
    },
    {
      "id": "case3_curated_id", "doc_id": "case3_curated_id", "parent_doc": null,
      "path": "sources/case3_fts_id/", "title": "Case Three Bridged Document",
      "authors": ["Bridge Tester"], "year": 2026, "token_count": 0, "chunk_count": 1,
      "doc_type": "paper", "source_format": "pdf", "keywords": ["bridging"],
      "summary": "Curated .id differs from the FTS doc_id; resolved only via the .path bridge.",
      "project_tags": ["NamespaceBridgeRegressionProject"],
      "provenance_fidelity": "verified_conversion"
    },
    {
      "id": "case3_decoy_doc", "doc_id": "case3_decoy_doc", "parent_doc": null,
      "path": "sources/case3_decoy_doc/", "title": "Case Three Decoy Document",
      "authors": ["Bridge Tester"], "year": 2026, "token_count": 0, "chunk_count": 1,
      "doc_type": "paper", "source_format": "pdf", "keywords": ["bridging"],
      "summary": "Decoy whose .id matches its own FTS doc_id, so a project-filtered search for the shared query term returns a nonzero result set under BOTH the pre-fix and post-fix allow-list -- this prevents literature-search.sh's zero-result unfiltered-retry fallback from masking the bridge regression (an unfiltered retry would find case3_fts_id too, passing the test even with the bridge reverted).",
      "project_tags": ["NamespaceBridgeRegressionProject"],
      "provenance_fidelity": "verified_conversion"
    }
  ]
}
CASE_INDEX

  # Build the fixture .literature.db from the REAL schema file (never a hand-rolled
  # CREATE TABLE) so this fixture cannot silently drift from the columns
  # literature-search.sh's queries actually select (e.g. `level`, which a prior draft
  # of this fixture omitted and which made --toc fail silently, caught only by
  # literature-search.sh's own `except Exception` and never surfaced under `2>/dev/null`).
  sqlite3 "$TEMP_LIT_DIR_F/.literature.db" < "$SCRIPT_DIR/literature-schema.sql"
  sqlite3 "$TEMP_LIT_DIR_F/.literature.db" <<'CASE_SQL'
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk1', 'case1_doc', 'Section 1', 'Section 1', 'Chunk 1 summary.', 100, 'chunk_0001.md', 'content one for the ingest-then-brief regression case');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk2', 'case1_doc', 'Section 2', 'Section 2', 'Chunk 2 summary.', 100, 'chunk_0002.md', 'content two');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk3', 'case1_doc', 'Section 3', 'Section 3', 'Chunk 3 summary.', 100, 'chunk_0003.md', 'content three');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c3chunk1', 'case3_fts_id', 'Bridged Content', 'Bridged Content', 'Bridged chunk summary.', 50, 'chunk_0001.md', 'nsbridge9x7q unique marker for project-filtered search bridge regression');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c3decoychunk1', 'case3_decoy_doc', 'Decoy Content', 'Decoy Content', 'Decoy chunk summary.', 50, 'chunk_0001.md', 'nsbridge9x7q also present in the decoy so the filtered query is nonzero under both pre-fix and post-fix code');
INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild');
CASE_SQL

  # --- Case 1: ingest-then-brief (actual post-fix output shape) ---
  mkdir -p "$TEMP_LIT_DIR_F/fakerepo/nested/scripts" "$TEMP_LIT_DIR_F/fakerepo/specs"
  ln -sf "$briefing_script_f" "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-briefing.sh"
  ln -sf "$search_script" "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-search.sh"
  cat > "$TEMP_LIT_DIR_F/fakerepo/specs/literature-index.json" <<'CASE1_SUBINDEX'
{"entries": [{"doc_id": "case1_doc", "relevance": "case 1 regression"}]}
CASE1_SUBINDEX

  local case1_stderr case1_briefing case1_toc_count case1_briefing_count
  case1_stderr=$(mktemp)
  case1_briefing=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-briefing.sh" 2>"$case1_stderr")
  if grep -q "not found in global index" "$case1_stderr"; then
    log_fail "Case 1 (ingest-then-brief): skip warning present on stderr (should be zero)"
  elif echo "$case1_briefing" | grep -q "Case One Regression Document" && echo "$case1_briefing" | grep -q "Regression Tester"; then
    log_pass "Case 1 (ingest-then-brief): resolves with real title/authors, zero skip warnings"
  else
    log_fail "Case 1 (ingest-then-brief): expected title/authors not found in briefing output"
  fi
  rm -f "$case1_stderr"

  case1_toc_count=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$search_script" --toc case1_doc 2>/dev/null | jq 'length' 2>/dev/null || echo -1)
  case1_briefing_count=$(echo "$case1_briefing" | grep -oE '[0-9]+ chunk\(s\)' | head -1 | grep -oE '^[0-9]+')
  if [[ "$case1_toc_count" == "3" ]] && [[ "$case1_briefing_count" == "3" ]]; then
    log_pass "Case 1 (ingest-then-brief): --toc chunk count (3) equals briefing's reported chunk count"
  else
    log_fail "Case 1 (ingest-then-brief): chunk count mismatch (--toc=$case1_toc_count, briefing=$case1_briefing_count)"
  fi

  # --- Case 3: project-filtered-search bridge ---
  local case3_search case3_docids
  case3_search=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$search_script" --project NamespaceBridgeRegressionProject "nsbridge9x7q" 2>/dev/null)
  case3_docids=$(echo "$case3_search" | jq -r '[.results[]?.doc_id] | unique | .[]' 2>/dev/null)
  if echo "$case3_docids" | grep -qx "case3_fts_id"; then
    log_pass "Case 3 (project-filtered-search bridge): returns case3_fts_id (curated .id case3_curated_id differs from FTS doc_id)"
  else
    log_fail "Case 3 (project-filtered-search bridge): case3_fts_id NOT returned. Got doc_ids: $case3_docids"
  fi

  # --- Case 2 + Case 4: run the extracted --validate logic once against the shared index,
  # plus a second id-less stub entry (Case 4) added to a COPY of the index so Case 1/2/3's
  # fixtures are untouched by Case 4's deliberately malformed record. ---
  cp "$TEMP_LIT_DIR_F/index.json" "$TEMP_LIT_DIR_F/index_case4.json"
  python3 - "$TEMP_LIT_DIR_F/index_case4.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
with open(p) as f:
    idx = json.load(f)
# Case 4: a stub entry with NEITHER .id NOR .path -- the exact shape that used to be
# misreported as the literal string "null (missing)".
idx["entries"].append({"doc_id": "case4_stub", "title": "Case Four Schema-Shape Stub"})
with open(p, "w") as f:
    json.dump(idx, f, indent=2)
PYEOF

  local validate_out
  validate_out=$(SCRIPT_DIR="$SCRIPT_DIR" lit_dir="$TEMP_LIT_DIR_F" index_file="$TEMP_LIT_DIR_F/index_case4.json" bash "$validate_extract" 2>&1)
  rm -f "$validate_extract"

  if echo "$validate_out" | grep -q "^___DIVERGENCE_INDEX_ONLY___case2_orphan"; then
    log_pass "Case 2 (--validate divergence): case2_orphan reported in the index-only-no-FTS-chunks bucket"
  else
    log_fail "Case 2 (--validate divergence): case2_orphan NOT reported. Output: $(echo "$validate_out" | grep '___DIVERGENCE')"
  fi

  if echo "$validate_out" | grep -q "^___SCHEMA_SHAPE_DEFECT___case4_stub"; then
    log_pass "Case 4 (schema-shape): case4_stub reported in the schema-shape-defects bucket"
  else
    log_fail "Case 4 (schema-shape): case4_stub NOT reported in schema-shape-defects"
  fi

  if echo "$validate_out" | grep -qi "null (missing)"; then
    log_fail "Case 4 (schema-shape): the literal string 'null (missing)' appeared in --validate output -- the misreport this task fixes"
  else
    log_pass "Case 4 (schema-shape): the literal string 'null (missing)' never appears in --validate output"
  fi

  log_info "Section F complete. Temp corpus will be cleaned up."
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
    section_f
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
