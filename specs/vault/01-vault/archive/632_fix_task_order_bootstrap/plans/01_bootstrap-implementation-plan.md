# Implementation Plan: Task #632

- **Task**: 632 - Fix generate-task-order.sh to bootstrap Task Order section if missing
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/632_fix_task_order_bootstrap/reports/01_task-order-bootstrap-research.md
- **Artifacts**: plans/01_bootstrap-implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `generate-task-order.sh` script fails silently when `## Task Order` is missing from TODO.md because `replace_section()` returns 1 on missing section and `set -euo pipefail` propagates the failure. The fix adds a `bootstrap_task_order_section()` function that idempotently inserts a blank `## Task Order` placeholder before `## Tasks` (or at EOF) prior to calling `replace_section()`. This is a single-file change affecting only `.claude/scripts/generate-task-order.sh`.

### Research Integration

Key findings from the research report:
- `replace_section()` (lines 763-812) returns 1 with WARNING when `## Task Order` is absent
- The script uses `set -euo pipefail` (line 27), so the return 1 propagates as a script failure
- Callers (task.md, todo.md, update-task-status.sh) all use `|| echo` non-fatal guards
- `read_existing_goal()` is already safe when the section is absent (returns empty string)
- The standard TODO.md section order is: `## Task Order` then `## Tasks`
- `grep | head | cut` pipeline is safe under pipefail because `cut` always exits 0

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add a `bootstrap_task_order_section()` function that inserts `## Task Order` if missing
- Call the bootstrap function in the update mode block before `replace_section()`
- Ensure idempotency: running on a TODO.md that already has `## Task Order` is a no-op
- Handle edge case where `## Tasks` heading is also absent (append to EOF)

**Non-Goals**:
- Modifying `replace_section()` itself (it is correct; the fix is a pre-pass)
- Changing caller guard patterns in task.md, todo.md, or update-task-status.sh
- Adding tests to the script (no test harness exists for these shell scripts)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `grep -q` returns 1 under pipefail | H | L | Use `if grep -q ...; then return 0; fi` pattern (conditional, not bare) |
| Double blank lines at insertion point | L | M | Cosmetic only; acceptable. `head -n "$((tasks_line - 1))"` preserves original spacing |
| `mktemp` failure | H | L | `set -e` aborts cleanly; no mitigation needed beyond existing error handling |
| Bootstrap runs on non-TODO files | L | L | Function uses `$TODO_FILE` which is validated earlier in the script |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add bootstrap_task_order_section() function [COMPLETED]

**Goal**: Insert the new function into generate-task-order.sh between `replace_section()` and the `# Main` banner.

**Tasks**:
- [x] Add `bootstrap_task_order_section()` function after line 812 (end of `replace_section()`) and before line 814 (`# Main` banner) *(completed: added with || true fix for pipefail safety)*

**Edit specification** -- insert after the closing `}` of `replace_section()` (line 812) and before the `# ============================================================================` / `# Main` block (line 814):

old_string:
```
  # Replace original file
  mv "$tmp_file" "$TODO_FILE"
}

# ============================================================================
# Main
# ============================================================================
```

new_string:
```
  # Replace original file
  mv "$tmp_file" "$TODO_FILE"
}

# ============================================================================
# Bootstrap Task Order Section
# ============================================================================

# bootstrap_task_order_section: if ## Task Order is missing from TODO_FILE,
# insert a blank placeholder before ## Tasks (or at EOF if ## Tasks absent).
# This makes replace_section() work on first run for new projects.
bootstrap_task_order_section() {
  # Idempotent: do nothing if section already present
  if grep -q "^## Task Order$" "$TODO_FILE"; then
    return 0
  fi

  echo "INFO: ## Task Order section missing — bootstrapping in $TODO_FILE" >&2

  local tasks_line
  tasks_line=$(grep -n "^## Tasks$" "$TODO_FILE" | head -1 | cut -d: -f1)

  local tmp_file
  tmp_file=$(mktemp)

  if [[ -n "$tasks_line" ]]; then
    # Insert before ## Tasks
    if [[ "$tasks_line" -gt 1 ]]; then
      head -n "$((tasks_line - 1))" "$TODO_FILE" > "$tmp_file"
    else
      : > "$tmp_file"
    fi
    printf '## Task Order\n\n' >> "$tmp_file"
    tail -n +"${tasks_line}" "$TODO_FILE" >> "$tmp_file"
  else
    # No ## Tasks heading — append to end of file
    cp "$TODO_FILE" "$tmp_file"
    printf '\n## Task Order\n\n' >> "$tmp_file"
  fi

  mv "$tmp_file" "$TODO_FILE"
}

# ============================================================================
# Main
# ============================================================================
```

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Add function between lines 812-814

**Verification**:
- Function exists in the script: `grep -q "bootstrap_task_order_section" .claude/scripts/generate-task-order.sh`
- Script passes syntax check: `bash -n .claude/scripts/generate-task-order.sh`

---

### Phase 2: Call bootstrap in update mode block [COMPLETED]

**Goal**: Wire the bootstrap function into the main execution path so it runs before `replace_section()` in update mode.

**Tasks**:
- [x] Add `bootstrap_task_order_section` call on the line before `replace_section "$SECTION_CONTENT"` in the update mode branch *(completed)*

**Edit specification** -- modify the `elif` block (currently around line 852-854):

old_string:
```
elif [[ "$MODE" == "update" ]]; then
  replace_section "$SECTION_CONTENT"
  echo "OK: Task Order section updated in $TODO_FILE"
```

new_string:
```
elif [[ "$MODE" == "update" ]]; then
  bootstrap_task_order_section
  replace_section "$SECTION_CONTENT"
  echo "OK: Task Order section updated in $TODO_FILE"
```

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Add one line in the update mode branch

**Verification**:
- The call appears in the update block: `grep -A2 'MODE.*update' .claude/scripts/generate-task-order.sh | grep -q 'bootstrap_task_order_section'`

---

### Phase 3: Verification and edge-case testing [COMPLETED]

**Goal**: Confirm the fix works for both the normal case (missing section) and the idempotent case (section already exists).

**Tasks**:
- [x] Run `bash -n .claude/scripts/generate-task-order.sh` to verify no syntax errors *(completed)*
- [x] Create a temporary TODO.md without `## Task Order` and verify bootstrap inserts it before `## Tasks` *(completed)*
- [x] Run the script again on the same file to confirm idempotency (no duplicate section) *(completed)*
- [x] Run the script on the nvim project's own TODO.md to confirm no regression (section already exists, should be a no-op) *(completed)*
- [x] Verify the BimodalHarness case: a TODO.md with YAML frontmatter, `# TODO`, and `## Tasks` but no `## Task Order` *(completed: tested with YAML frontmatter + Tasks section)*

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (verification only)

**Verification**:
- `bash -n` exits 0 (no syntax errors)
- Temporary file gains `## Task Order` section on first run
- Second run on same file produces identical output (idempotent)
- nvim TODO.md is unchanged after script run (existing section preserved)

---

## Testing & Validation

- [x] Script syntax check passes: `bash -n .claude/scripts/generate-task-order.sh` *(completed)*
- [x] Bootstrap inserts `## Task Order` before `## Tasks` in a file missing it *(completed)*
- [x] Bootstrap is a no-op when `## Task Order` already exists *(completed)*
- [x] Edge case: file with no `## Tasks` heading appends section at EOF *(completed)*
- [x] No regression on existing nvim TODO.md *(completed)*

## Artifacts & Outputs

- `.claude/scripts/generate-task-order.sh` - Modified with bootstrap function and call site
- `specs/632_fix_task_order_bootstrap/plans/01_bootstrap-implementation-plan.md` - This plan
- `specs/632_fix_task_order_bootstrap/summaries/01_bootstrap-implementation-summary.md` - Post-implementation summary

## Rollback/Contingency

Revert the single file to its previous state:
```bash
git checkout HEAD -- .claude/scripts/generate-task-order.sh
```
The change is isolated to one file with no external dependencies, making rollback trivial.
