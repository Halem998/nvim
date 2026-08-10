# Research Report: Task #646

**Task**: 646 - Harden TODO.md Status Updates
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:30:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of `.claude/scripts/update-task-status.sh`, `specs/TODO.md`, related scripts
**Artifacts**: `specs/646_harden_todo_status_updates/reports/01_harden-todo-status.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- `update-task-status.sh` uses two sed-based patterns (PHASE 2 and PHASE 3) to update TODO.md status text that can fail silently when format deviates from expectations.
- Both phases are already line-number-anchored (they use `grep -n` to find the target line first), so the primary fragility is not location-finding but status-extraction and sed replacement when the extracted `current_todo_status` string is empty or mismatched.
- An awk-based single-pass replacement eliminates all three failure modes: it co-locates the search and replace, handles multi-word statuses, and can emit a non-zero exit code on failure rather than silently succeeding with a no-op.

---

## Context & Scope

`update-task-status.sh` is the centralized atomic status update script called by `skill-base.sh` on every preflight and postflight transition. It updates three locations in sequence:

1. **PHASE 1** (`update_state_json`): JSON update via `jq` — robust, validated, tested.
2. **PHASE 2** (`update_todo_task_entry`): Updates `- **Status**: [STATUS]` inside the `## Tasks` section (lines 187–235).
3. **PHASE 3** (`update_todo_task_order`): Updates `N [STATUS] — ...` tree lines inside the `## Task Order` section (lines 240–309).
4. **PHASE 4** (`update_plan_file`): Delegates to `update-plan-status.sh` — separate scope, not analyzed here.

This report focuses on the sed-based patterns in PHASE 2 and PHASE 3, which is what the task description calls "phase 2" (both are the TODO.md update phases vs. the state.json phase).

---

## Findings

### Current Sed Patterns (Exact Code)

#### PHASE 2 — Task Entry Status Update

**Step 1: Find heading line** (line 195):
```bash
heading_line=$(grep -n "^### ${task_number}\." "$TODO_FILE" | head -1 | cut -d: -f1)
```

**Step 2: Find Status line within next 10 lines** (lines 206–207):
```bash
status_line=$(sed -n "$((heading_line+1)),$((heading_line+10))p" "$TODO_FILE" \
  | grep -n -E '^\s*-?\s*\*\*Status\*\*: \[' | head -1 | cut -d: -f1)
```

**Step 3: Extract current status from that line** (line 219):
```bash
current_todo_status=$(sed -n "${actual_line}p" "$TODO_FILE" | sed 's/.*\[\([^]]*\)\].*/\1/')
```

**Step 4: Replace status** (line 234):
```bash
sed -i "${actual_line}s/\[${current_todo_status}\]/[${TODO_STATUS}]/" "$TODO_FILE"
```

#### PHASE 3 — Task Order Tree Line Update

**Step 1: Find tree line** (line 272):
```bash
order_line=$(grep -n -E "^\s*(└─ )?${task_number} \[" "$TODO_FILE" | head -1 | cut -d: -f1)
```

**Step 2: Extract current status** (line 293):
```bash
current_order_status=$(sed -n "${order_line}p" "$TODO_FILE" | grep -oE '\[([A-Z ]+)\]' | head -1 | tr -d '[]')
```

**Step 3: Replace status** (line 308):
```bash
sed -i "${order_line}s/\[${current_order_status}\]/[${TODO_STATUS}]/" "$TODO_FILE"
```

---

### Failure Modes

#### Failure Mode A: Empty `current_todo_status` (PHASE 2, line 219)

The extraction `sed 's/.*\[\([^]]*\)\].*/\1/'` on the status line text returns the full original line unchanged if no `[...]` pattern is found (e.g., a malformed entry like `- **Status**: NOT STARTED` with no brackets). Because of set `-e` in the outer script, this is suppressed by the grep guard at line 209 that checks `status_line` is non-empty. However, if the Status line exists without brackets (regex `'\[' ` not matched), `status_line` is empty and the function silently returns 0 — the update is skipped with only a warning.

**Actual behavior when format lacks brackets**: The grep at line 206–207 requires `\[` at the end of the pattern. If the status line reads `- **Status**: RESEARCHING` (no brackets), the grep returns nothing, `status_line` is empty, and the function exits with `return 0` (line 210–211). The warning is printed to stderr, but the script exits with code 0. The caller (`update_todo_task_entry`) marks `todo_failed=true` only if the function returns non-zero, so this silent skip causes `exit 0` from the overall script while TODO.md is not updated.

#### Failure Mode B: Status mismatch in sed replacement (PHASE 2, line 234 and PHASE 3, line 308)

Both phases extract `current_status` and then use it as the literal match target in `sed`:
```bash
sed -i "${line}s/\[${current_status}\]/[${NEW_STATUS}]/"
```

If `current_status` is empty (extraction yielded empty string), the sed command becomes:
```bash
sed -i "37s/\[\]/[RESEARCHING]/"
```
This pattern `\[\]` matches the literal string `[]` — which never appears in valid TODO.md status lines. The sed command succeeds (exit 0) but makes no change. **This is the core silent failure mode.**

Testing confirmed: `echo "- **Status**: [NOT STARTED]" | sed 's/\[\]/[RESEARCHING]/'` produces `- **Status**: [NOT STARTED]` unchanged.

#### Failure Mode C: Lowercase / mixed-case status in Task Order (PHASE 3)

The `grep -oE '\[([A-Z ]+)\]'` pattern on line 293 only matches uppercase letters and spaces inside brackets. If a manually-set entry uses lowercase like `[researching]`, extraction returns empty string, falling into Failure Mode B.

#### Failure Mode D: `current_todo_status` contains regex metacharacters

The sed pattern `s/\[${current_todo_status}\]/...` substitutes the variable into a regex. All standard TODO status values (`NOT STARTED`, `RESEARCHING`, `RESEARCHED`, `PLANNING`, `PLANNED`, `IMPLEMENTING`, `COMPLETED`, `ABANDONED`, `EXPANDED`, `REVISED`, `PARTIAL`, `BLOCKED`) contain only uppercase letters, spaces, and no regex metacharacters — so this is low risk in practice, but still a latent hazard if new statuses containing `(`, `.`, `*`, etc. are added.

#### Failure Mode E: The 10-line search window

PHASE 2 searches only the 10 lines after the heading for `**Status**:`. Modern task entries have 4–6 metadata fields. Old entries (tasks 78, 87) with `Research Started:`, `Research Completed:` fields could push Status to line +8 or beyond. The 10-line window is currently sufficient but fragile if new fields are added.

---

### Format Variations in Current TODO.md

Inspecting `specs/TODO.md`:
- All active task entries use `- **Status**: [STATUS]` (dash + space, no indentation).
- Status values observed: `[RESEARCHING]`, `[NOT STARTED]`, `[COMPLETED]`, `[PLANNED]`.
- Task order tree uses both unindented (`642 [RESEARCHING]`) and indented (`  └─ 643 [NOT STARTED]`).
- No bracket-free status lines or lowercase statuses found in current file.

The current file is well-formed, but the scripts lack defensive handling for format drift.

---

### Other Scripts That Use These Patterns

- **`update-plan-status.sh`** (lines 51, 58, 60): Uses the same sed extraction pattern for plan file status lines. The same fragility exists but is out of scope for this task.
- **`vault-operation.sh`** (lines 163–166): Uses sed for task number renaming in TODO.md, not status updating — different operation, not affected.
- No other `.claude/scripts/` file uses the specific status extraction patterns.

---

### Proposed Replacement: awk Single-Pass Approach

Rather than a two-step "find line number then sed-replace-by-line-number" pattern, awk can do both operations in a single pass. This eliminates all failure modes:

#### PHASE 2 Replacement (update_todo_task_entry)

Replace lines 205–234 with:

```bash
update_todo_task_entry() {
  # ...existing guards for TODO_FILE existence and heading_line...

  # Awk single-pass: find heading, find Status within 10 lines, replace status
  local updated
  updated=$(awk -v task="$task_number" -v new_status="$TODO_STATUS" '
    BEGIN { found = 0; window = 0; count = 0 }
    $0 ~ ("^### " task "\\.") {
      found = 1; window = 10
      print; next
    }
    found && window > 0 {
      window--
      if ($0 ~ /^[[:space:]]*-?[[:space:]]*\*\*Status\*\*:[[:space:]]*\[/) {
        sub(/\[[A-Z ]+\]/, "[" new_status "]")
        found = 0; window = 0; count++
      }
    }
    { print }
    END { exit (count == 0) }
  ' "$TODO_FILE")

  local awk_exit=$?
  if [[ $awk_exit -ne 0 ]]; then
    echo "Warning: no Status line updated for task $task_number in TODO.md" >&2
    return 1
  fi
  echo "$updated" > "$TMP_DIR/todo.md.tmp" && mv "$TMP_DIR/todo.md.tmp" "$TODO_FILE"
}
```

Key differences from current implementation:
1. No separate extraction of `current_todo_status` — awk replaces directly without needing to know the current value.
2. `exit (count == 0)` makes awk return exit code 1 if no replacement was made, enabling the caller to detect failure rather than silent skip.
3. Single read of TODO.md instead of two reads (one for extraction, one for replacement).
4. The `sub(/\[[A-Z ]+\]/, ...)` pattern replaces any well-formed `[STATUS]` regardless of what the status text is — no case-sensitivity failure.

#### PHASE 3 Replacement (update_todo_task_order — Mode A only)

Replace lines 292–308 (the non-terminal in-place update path) with:

```bash
# Replace [current_status] on the specific tree line
local updated
updated=$(awk -v task="$task_number" -v new_status="$TODO_STATUS" '
  BEGIN { count = 0 }
  match($0, "^[[:space:]]*(└─ )?" task " \\[[A-Z ]+\\]") {
    sub(/\[[A-Z ]+\]/, "[" new_status "]")
    count++
  }
  { print }
  END { exit (count == 0) }
' "$TODO_FILE")

local awk_exit=$?
if [[ $awk_exit -ne 0 ]]; then
  echo "Warning: task $task_number not found in TODO.md Task Order tree -- falling back to full regeneration" >&2
  # ...existing fallback to generate-task-order.sh...
  return 0
fi
echo "$updated" > "$TMP_DIR/todo.md.tmp" && mv "$TMP_DIR/todo.md.tmp" "$TODO_FILE"
```

Key differences:
1. Uses `match()` with a properly anchored pattern: `^[[:space:]]*(└─ )?TASK \[` — same semantics as the existing `grep -E "^\s*(└─ )?${task_number} \["` but inside awk.
2. No separate extraction of `current_order_status` variable.
3. Exit code from awk detects no-op, triggers existing fallback path gracefully.

---

### Edge Cases to Handle

1. **`NOT STARTED` multi-word status**: The pattern `/\[[A-Z ]+\]/` (uppercase letters and spaces) correctly matches `[NOT STARTED]`. Confirmed by testing.

2. **Task number boundary matching**: `^### 2\.` correctly does NOT match `### 20.` because `\.` is a literal dot, and `"^### 20."` requires "20." after "### ". Verified by testing.

3. **Awk pattern with task numbers containing special chars**: Task numbers are positive integers (`[0-9]+`), so no regex metacharacter risk in `"^### " task "\\."`.

4. **Concurrent writes**: Both awk replacements write via temp file (`TMP_DIR/todo.md.tmp`). This inherits the same shared temp file issue as the current implementation — a separate concern addressed in task 645.

5. **Idempotency**: The awk `sub()` always overwrites with the target status. If already at target, sub() is a no-op but `count++` still fires, and awk exits 0. This preserves idempotent behavior (caller's existing `current_todo_status == TODO_STATUS` check at line 221–226 can be removed or retained).

6. **`update-plan-status.sh` not changed**: This script uses sed for plan files using the same extraction pattern. It is in scope for a follow-up task but is separate from `update-task-status.sh`.

---

## Decisions

- Focus replacement on `update_todo_task_entry` (PHASE 2) and the Mode A in-place path of `update_todo_task_order` (PHASE 3).
- PHASE 3 Mode B (terminal status full regeneration via `generate-task-order.sh`) should remain unchanged — it already delegates to a full regeneration script rather than using sed.
- The `update-plan-status.sh` sed patterns are out of scope for this task (separate file, separate concern).
- Use awk single-pass approach rather than line-number-based Python/perl one-liner for portability.
- Preserve the existing temp-file-plus-atomic-move pattern (`TMP_DIR/todo.md.tmp` -> `TODO_FILE`).

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Awk pattern regression on existing format | Medium | Test with current TODO.md before and after |
| `└─` Unicode character in awk pattern | Low | Awk handles UTF-8 bytes in string literals; same chars already in grep pattern |
| Shared `$TMP_DIR/todo.md.tmp` file collision | Medium | Already exists; task 645 addresses this separately |
| PHASE 2 awk writes full file on each update | Low | File is small (~200 lines); single-pass awk faster than read-grep-sed pipeline |
| Removing idempotency pre-check changes semantics | Low | Awk `sub()` on already-correct value is a no-op; behavior identical |

---

## Context Extension Recommendations

- **Topic**: Bash script testing patterns for `.claude/scripts/`
- **Gap**: No test harness exists for `update-task-status.sh` — format regressions are caught only in production.
- **Recommendation**: Consider adding a `tests/` directory under `.claude/scripts/` with a `test-update-task-status.sh` script that exercises known-good and edge-case inputs.

---

## Appendix

### Search queries used
- Codebase: `grep -rn "sed" .claude/scripts/` — identified all sed usages
- Codebase: `grep -rn "update-task-status"` — mapped all callers
- Codebase: `grep -n "\*\*Status\*\*" specs/TODO.md` — verified current format

### References
- `update-task-status.sh` lines 187–309 (PHASE 2 and PHASE 3 logic)
- `update-plan-status.sh` lines 51–60 (related sed patterns, out of scope)
- `specs/TODO.md` — current task entry format (dash-prefixed, bracket-enclosed status)
- `specs/archive/543_convert_opencode_json_to_computed_artifact/TODO.md` — older format sample (consistent)
