#!/usr/bin/env bash
# test-return-meta-merge.sh — executable verification harness for the Stage 8 `.return-meta.json`
# merge fix (agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, "Stage 8: Postflight")
# and the CHECKPOINT 3 fail-safe warning
# (agent-system/extensions/core/commands/orchestrate.md, "CHECKPOINT 3: COMMIT").
#
# Verification bar (see specs/936_.../reports/01_stage8-clobber-fix.md): a single-task
# /orchestrate run over a task whose implementation agent edits at least one source file outside
# specs/ must produce a CHECKPOINT 3 commit that ACTUALLY CONTAINS that source file — asserted
# via `git show --name-only` on a REAL commit produced by the REAL git-commit-scoped.sh. The
# negative case (zero modified_files) must emit the canonical, un-suffixed fail-safe warning.
#
# The harness EXTRACTS the fenced ```bash blocks from the shipped source-store markdown at
# runtime (extract_block below) and executes them verbatim — it never re-types its own copy of
# the snippets, so it is bound to whatever text is actually shipped, not a hand-maintained
# facsimile that could silently drift from the real file.
#
# Builds a throwaway scratch git repo ($(mktemp -d)/proj) so nothing here ever touches this
# repository's real working tree, index, or specs/. The scratch tree is removed on exit via
# trap, success or failure — mirrors specs/902_.../tests/test-self-modifying-gate.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORE="$REPO_ROOT/agent-system/extensions/core"
SKILL_MD="$CORE/skills/skill-orchestrate/SKILL.md"
ORCH_MD="$CORE/commands/orchestrate.md"
STAGING_MD="$CORE/context/standards/git-staging-scope.md"
SRC_COMMIT="$CORE/scripts/git-commit-scoped.sh"
SRC_GUARD="$CORE/scripts/deploy-root-guard.sh"
SRC_LOCK="$CORE/scripts/task-lock.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# --- scratch git repo(s); MUST NOT write into the repository's real .git, .claude/, or specs/ ---
# Registration uses a manifest FILE, not an in-memory array: every scratch root is created inside
# new_scratch_repo(), which callers invoke via `proj="$(new_scratch_repo)"` — a command
# substitution, which bash runs in a SUBSHELL. An array append inside that subshell would be
# invisible to this top-level script once the subshell exits, silently defeating cleanup. A file
# append survives across the subshell boundary, so it is the only registration mechanism that
# actually works here.
SCRATCH_MANIFEST="$(mktemp)"
cleanup() {
  if [ -f "$SCRATCH_MANIFEST" ]; then
    while IFS= read -r r; do
      [ -n "$r" ] && rm -rf "$r"
    done < "$SCRATCH_MANIFEST"
    rm -f "$SCRATCH_MANIFEST"
  fi
}
trap cleanup EXIT

# --- extract_block <markdown_file> <marker_string> ---
# Prints (to stdout) the content of the FIRST fenced ```bash ... ``` block in <markdown_file>
# that contains the literal substring <marker_string>. Returns 1 (nothing printed) if no such
# block is found. Uses plain bash substring matching (not a regex engine) so markers containing
# shell metacharacters (quotes, `$`, parens) are matched literally, with no escaping required.
extract_block() {
  local file="$1" marker="$2"
  local in_block=0
  local buf=""
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_block" -eq 0 ]; then
      if [ "$line" = '```bash' ]; then
        in_block=1
        buf=""
      fi
    else
      if [ "$line" = '```' ]; then
        if [[ "$buf" == *"$marker"* ]]; then
          printf '%s' "$buf"
          return 0
        fi
        in_block=0
      else
        buf+="$line"$'\n'
      fi
    fi
  done < "$file"
  return 1
}

# --- build a fresh scratch git repo with the CHECKPOINT 3 committer deployed at .claude/scripts/
#     (the path the extracted orchestrate.md block, and git-commit-scoped.sh's own
#     deploy-root-guard.sh, both expect) ---
new_scratch_repo() {
  local root proj
  root="$(mktemp -d)"
  echo "$root" >> "$SCRATCH_MANIFEST"
  proj="$root/proj"
  mkdir -p "$proj/.claude/scripts" "$proj/specs" "$proj/lua"
  cp "$SRC_COMMIT" "$proj/.claude/scripts/git-commit-scoped.sh"
  cp "$SRC_GUARD" "$proj/.claude/scripts/deploy-root-guard.sh"
  cp "$SRC_LOCK" "$proj/.claude/scripts/task-lock.sh"
  chmod +x "$proj/.claude/scripts/"*.sh

  (
    cd "$proj" || exit 1
    git init -q
    git config user.email "harness@example.com"
    git config user.name "Harness"
    echo '# scratch' > README.md
    git add README.md
    git commit -q -m "initial commit"
  )
  echo "$proj"
}

# --- seed a task dir + TODO.md + state.json + a modified-but-uncommitted source file OUTSIDE
#     specs/ (lua/harness_probe.lua), matching a real /orchestrate single-task run's shape ---
seed_task_fixture() {
  local proj="$1"
  mkdir -p "$proj/specs/936_stage8_return_meta_clobbers_modified_files"
  echo '# TODO' > "$proj/specs/TODO.md"
  echo '{}' > "$proj/specs/state.json"
  echo 'local M = {}' > "$proj/lua/harness_probe.lua"
  (
    cd "$proj" || exit 1
    git add specs/TODO.md specs/state.json README.md >/dev/null 2>&1
    git commit -q -m "seed fixture" || true
    # now dirty README/TODO/state are committed; the probe file and any subsequent
    # .return-meta.json / TODO.md changes stay UNCOMMITTED until CHECKPOINT 3 runs.
  )
}

# ============================================================================
# POSITIVE CASE (clean exit): modified_files survives Stage 8, CHECKPOINT 3
# actually commits the outside-specs/ source file.
# ============================================================================
run_positive_case() {
  local variant="$1" # "clean" or "partial"
  local proj meta_file clean_block cp3_block
  proj="$(new_scratch_repo)"
  seed_task_fixture "$proj"
  meta_file="$proj/specs/936_stage8_return_meta_clobbers_modified_files/.return-meta.json"

  cat > "$meta_file" <<'EOF'
{
  "modified_files": ["lua/harness_probe.lua"],
  "completion_data": {"completion_summary": "harness probe"},
  "memory_candidates": [{"content": "probe candidate", "category": "PATTERN"}],
  "metadata": {
    "agent_type": "general-implementation-agent",
    "session_id": "sess_harness_probe"
  }
}
EOF

  if [ "$variant" = "clean" ]; then
    clean_block=$(extract_block "$SKILL_MD" '--arg status "implemented"')
  else
    clean_block=$(extract_block "$SKILL_MD" '--arg status "partial"')
  fi
  if [ -z "$clean_block" ]; then
    fail "extract_block found no Stage 8 $variant-exit block in SKILL.md"
    return
  fi

  cp3_block=$(extract_block "$ORCH_MD" 'stage_paths=("${task_dir}/"')
  if [ -z "$cp3_block" ]; then
    fail "extract_block found no CHECKPOINT 3 block in orchestrate.md"
    return
  fi

  (
    cd "$proj" || exit 1
    TASK_DIR="specs/936_stage8_return_meta_clobbers_modified_files"
    cycle_count=3
    current_status="completed"
    eval "$clean_block"
  )

  local status_after modified_after completion_after candidates_after agent_type_after
  status_after=$(jq -r '.status' "$meta_file")
  modified_after=$(jq -r '.modified_files[0]' "$meta_file")
  completion_after=$(jq -r '.completion_data.completion_summary' "$meta_file")
  candidates_after=$(jq -r '.memory_candidates[0].content' "$meta_file")
  agent_type_after=$(jq -r '.metadata.agent_type' "$meta_file")

  local expect_status
  if [ "$variant" = "clean" ]; then expect_status="implemented"; else expect_status="partial"; fi

  if [ "$status_after" = "$expect_status" ]; then
    pass "Stage 8 $variant-exit: status merged to '$expect_status'"
  else
    fail "Stage 8 $variant-exit: expected status='$expect_status', got '$status_after'"
  fi
  if [ "$modified_after" = "lua/harness_probe.lua" ]; then
    pass "Stage 8 $variant-exit: modified_files survived the merge"
  else
    fail "Stage 8 $variant-exit: modified_files did NOT survive (got '$modified_after')"
  fi
  if [ "$completion_after" = "harness probe" ]; then
    pass "Stage 8 $variant-exit: completion_data survived the merge"
  else
    fail "Stage 8 $variant-exit: completion_data did NOT survive (got '$completion_after')"
  fi
  if [ "$candidates_after" = "probe candidate" ]; then
    pass "Stage 8 $variant-exit: memory_candidates survived the merge"
  else
    fail "Stage 8 $variant-exit: memory_candidates did NOT survive (got '$candidates_after')"
  fi
  if [ "$agent_type_after" = "general-implementation-agent" ]; then
    pass "Stage 8 $variant-exit: metadata.agent_type survived the merge"
  else
    fail "Stage 8 $variant-exit: metadata.agent_type did NOT survive (got '$agent_type_after')"
  fi

  # --- CHECKPOINT 3: build stage_paths from the (now-merged, not clobbered) metadata file ---
  local cp3_output stage_paths_out
  cp3_output=$(
    cd "$proj" || exit 1
    PADDED_NUM="936"
    PROJECT_NAME="stage8_return_meta_clobbers_modified_files"
    eval "$cp3_block"
    printf '%s\n' "${stage_paths[@]}"
  )
  stage_paths_out="$cp3_output"

  if echo "$stage_paths_out" | grep -qF "lua/harness_probe.lua"; then
    pass "CHECKPOINT 3 ($variant): stage_paths includes lua/harness_probe.lua"
  else
    fail "CHECKPOINT 3 ($variant): stage_paths missing lua/harness_probe.lua (got: $stage_paths_out)"
    return
  fi

  # --- invoke the REAL git-commit-scoped.sh with those stage_paths ---
  local commit_output commit_exit sha
  commit_output=$(
    cd "$proj" || exit 1
    bash .claude/scripts/git-commit-scoped.sh \
      --message "harness: $variant-exit positive case" \
      --session "sess_harness_probe" \
      -- "specs/936_stage8_return_meta_clobbers_modified_files/" "specs/TODO.md" "specs/state.json" "lua/harness_probe.lua" \
      2>&1
  )
  commit_exit=$?
  echo "--- git-commit-scoped.sh output ($variant) ---"
  echo "$commit_output"
  echo "--- end output ---"

  if [ "$commit_exit" -ne 0 ]; then
    fail "git-commit-scoped.sh ($variant) exited non-zero ($commit_exit)"
    return
  fi

  sha=$(cd "$proj" && git rev-parse HEAD)
  echo "Positive case ($variant) commit SHA: $sha"
  local show_output
  show_output=$(cd "$proj" && git show --name-only "$sha")
  echo "--- git show --name-only $sha ---"
  echo "$show_output"
  echo "--- end git show ---"

  if echo "$show_output" | grep -qF "lua/harness_probe.lua"; then
    pass "REAL COMMIT $sha ($variant) contains lua/harness_probe.lua (git show --name-only)"
  else
    fail "REAL COMMIT $sha ($variant) does NOT contain lua/harness_probe.lua"
  fi
}

# ============================================================================
# NEGATIVE CASE: zero modified_files -> canonical un-suffixed warning on stderr,
# and the commit contains only task-directory / specs/ paths.
# ============================================================================
run_negative_case() {
  local proj meta_file cp3_block
  proj="$(new_scratch_repo)"
  seed_task_fixture "$proj"
  meta_file="$proj/specs/936_stage8_return_meta_clobbers_modified_files/.return-meta.json"

  cat > "$meta_file" <<'EOF'
{
  "status": "implemented",
  "metadata": {"cycles_used": 1, "final_state": "completed"}
}
EOF

  cp3_block=$(extract_block "$ORCH_MD" 'stage_paths=("${task_dir}/"')
  if [ -z "$cp3_block" ]; then
    fail "extract_block found no CHECKPOINT 3 block in orchestrate.md (negative case)"
    return
  fi

  # NOTE: the stderr redirect MUST be attached to the subshell's own compound command (the
  # `{ ...; }` block below), not to the closing `)` of the `$(...)` substitution — a redirect
  # trailing the substitution itself only affects the (nonexistent) outer simple command and
  # never touches the subshell's own fd 2, so the warning would otherwise leak straight to the
  # harness's own terminal instead of being captured here.
  local stderr_file stdout_out
  stderr_file=$(mktemp)
  stdout_out=$(
    {
      cd "$proj" || exit 1
      PADDED_NUM="936"
      PROJECT_NAME="stage8_return_meta_clobbers_modified_files"
      eval "$cp3_block"
      printf '%s\n' "${stage_paths[@]}"
    } 2>"$stderr_file"
  )
  local captured_stderr
  captured_stderr=$(cat "$stderr_file")
  rm -f "$stderr_file"

  echo "--- negative case captured stderr ---"
  echo "$captured_stderr"
  echo "--- end captured stderr ---"

  local canonical_warning
  canonical_warning=$(extract_block "$STAGING_MD" 'no modified_files reported' 2>/dev/null)
  # Fail-Safe Direction's warning line is inside a plain (non-bash) fenced block; fall back to a
  # direct grep of the standard for the exact line if extract_block (which only scans ```bash
  # blocks) finds nothing, since the canonical wording lives in a plain ``` block there.
  local canonical_line
  canonical_line=$(grep -F '[postflight] WARNING: no modified_files reported' "$STAGING_MD" | head -1)

  if [ -z "$canonical_line" ]; then
    fail "could not extract the canonical warning line from git-staging-scope.md"
  elif echo "$captured_stderr" | grep -qF "$canonical_line"; then
    pass "negative case: canonical un-suffixed warning present on stderr"
  else
    fail "negative case: canonical warning NOT found on stderr (expected: $canonical_line)"
  fi

  if echo "$captured_stderr" | grep -qF "for task #"; then
    fail "negative case: suffixed 'for task #' variant leaked into the single-task site"
  else
    pass "negative case: no task-number-suffixed variant present (single-task site is correct)"
  fi

  if echo "$stdout_out" | grep -qF "lua/harness_probe.lua"; then
    fail "negative case: stage_paths unexpectedly includes lua/harness_probe.lua"
  else
    pass "negative case: stage_paths does NOT include the untracked source file"
  fi

  # Commit with only the fixed task-scope paths (matching what CHECKPOINT 3 would actually stage)
  local commit_output commit_exit sha show_output
  commit_output=$(
    cd "$proj" || exit 1
    bash .claude/scripts/git-commit-scoped.sh \
      --message "harness: negative case" \
      --session "sess_harness_probe" \
      -- "specs/936_stage8_return_meta_clobbers_modified_files/" "specs/TODO.md" "specs/state.json" \
      2>&1
  )
  commit_exit=$?
  echo "--- git-commit-scoped.sh output (negative) ---"
  echo "$commit_output"
  echo "--- end output ---"

  if [ "$commit_exit" -ne 0 ]; then
    fail "git-commit-scoped.sh (negative case) exited non-zero ($commit_exit)"
    return
  fi

  sha=$(cd "$proj" && git rev-parse HEAD)
  show_output=$(cd "$proj" && git show --name-only "$sha")
  echo "--- git show --name-only $sha (negative case) ---"
  echo "$show_output"
  echo "--- end git show ---"

  if echo "$show_output" | grep -qF "lua/harness_probe.lua"; then
    fail "negative case commit $sha unexpectedly contains lua/harness_probe.lua"
  else
    pass "negative case commit $sha contains only task-directory/specs paths"
  fi
}

# ============================================================================
# REGRESSION GUARD: no truncating `jq -n` write remains in Stage 8 for
# .return-meta.json, so a future revert to the old wholesale-overwrite form is
# caught even if the behavioral cases above were somehow skipped.
# ============================================================================
run_regression_guard() {
  local stage8_region truncating_count
  stage8_region=$(sed -n '/^Write metadata file\./,/^## Multi-Task Mode/p' "$SKILL_MD")
  truncating_count=$(echo "$stage8_region" | grep -c 'jq -n')
  if [ "$truncating_count" -eq 0 ]; then
    pass "regression guard: no truncating 'jq -n' .return-meta.json write remains in Stage 8"
  else
    fail "regression guard: found $truncating_count 'jq -n' occurrence(s) in the Stage 8 region — the clobber may have returned"
  fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
  echo "== Positive case: clean exit =="
  run_positive_case clean
  echo
  echo "== Positive case: partial exit =="
  run_positive_case partial
  echo
  echo "== Negative case =="
  run_negative_case
  echo
  echo "== Regression guard =="
  run_regression_guard
  echo
  echo "===================="
  echo "PASS=$PASS FAIL=$FAIL"
  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"
