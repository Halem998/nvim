# Research Report: Task #616

**Task**: 616 - Fix archive-task.sh to remove archived entries from TODO.md
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:30:00Z
**Effort**: 30 minutes (research phase)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/scripts/archive-task.sh` (primary script under review)
- `.claude/extensions/core/scripts/archive-task.sh` (extension copy, identical)
- `specs/TODO.md` (actual format of task entry blocks)
- `.claude/scripts/update-task-status.sh` (reference for TODO.md editing patterns)
- `.claude/commands/todo.md` (how archive-task.sh is called)
**Artifacts**: `specs/616_fix_archive_task_todo_cleanup/reports/01_archive-todo-cleanup.md`
**Standards**: report-format.md

---

## Executive Summary

- The current Step C in `archive-task.sh` (lines 110-138) uses a Python regex that matches `- #N:` patterns — a format that does **not** exist in TODO.md. The actual format is `### N. Title`, causing zero matches and leaving stale task blocks in TODO.md after archival.
- The fix requires replacing the Python regex in Step C with one that matches and removes the full task entry block: from `### N.` through the next `---` separator (inclusive).
- Both `.claude/scripts/archive-task.sh` and `.claude/extensions/core/scripts/archive-task.sh` are **identical copies** and must both be updated.

---

## Context & Scope

The `/todo` command identifies completed/abandoned tasks and calls `archive-task.sh` for each. The script performs four operations (A–D): move task to archive state, remove from active state, update TODO.md, and move the directory. The bug is in Step C (TODO.md update): the regex matches a single-line `- #N:` pattern that was never the actual format. The actual format uses multi-line blocks with `### N.` headings.

---

## Findings

### 1. Current `archive-task.sh` Step C — What It Does (Broken)

**Location**: Lines 110–138 of `.claude/scripts/archive-task.sh`

```python
# Current broken regex:
pattern = re.compile(
    r'^[ \t]*-[ \t]+(?:\*\*)?#' + re.escape(task_num) + r'(?:\*\*)?[:\s].*\n',
    re.MULTILINE
)
```

**What it tries to match**: A single line like `- #616:` or `- **#616**:` or `  - #616 title`.

**What actually exists in TODO.md**:
```
### 616. Fix archive-task.sh to remove archived entries from TODO.md
- **Effort**: 30 minutes
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Dependencies**: None

**Description**: ...long description...

---
```

**Result**: Zero matches. The task block is never removed. After archival, the `### 616.` block remains in the `## Tasks` section of TODO.md indefinitely.

### 2. Actual TODO.md Block Structure

From reading `specs/TODO.md` directly:

```
## Tasks

### {N}. {Title}
- **Effort**: {value}
- **Status**: [{STATUS}]
- **Task Type**: {type}
- **Dependencies**: {value}
[optional additional fields like Research, Plan, Summary]

**Description**: {multi-line description text}

---

### {next N}. ...
```

**Key structural facts**:
- Every task block starts with `### {N}.` at the beginning of a line (exactly: `### ` + number + `.`)
- Every task block ends with `---` on its own line followed by a blank line
- The final task in the file may or may not have a trailing `---`
- The `## Tasks` section ends at end-of-file (no `##` section follows it currently)
- The `## Task Order` section precedes `## Tasks` and must not be touched

### 3. What the Fix Must Do

The Python block must be replaced to:
1. Find the line starting with `### {N}.` (exact prefix, not partial match — avoid matching `### 616` when removing task 16)
2. Capture from that line through the next `---` separator (or end of `## Tasks` section)
3. Remove the entire block including the trailing `---` and any blank lines

**Regex approach** (Python `re.DOTALL` block removal):

```python
import sys, re

todo_path = sys.argv[1]
task_num = sys.argv[2]

with open(todo_path, 'r') as f:
    content = f.read()

# Match the full block: from "### N. " heading to the next "---" separator (inclusive)
# (?m) for multiline, (?s) for dotall within the block
pattern = re.compile(
    r'^### ' + re.escape(task_num) + r'\. .*?\n(?:.*?\n)*?---[ \t]*\n?',
    re.MULTILINE
)
new_content = pattern.sub('', content)

if new_content != content:
    with open(todo_path, 'w') as f:
        f.write(new_content)
    print(f"Removed task {task_num} block from TODO.md")
else:
    print(f"Note: task {task_num} block not found in TODO.md (skipped)", file=sys.stderr)
```

**Important**: Using `re.MULTILINE` with a non-greedy `.*?` across multiple lines requires `re.DOTALL` for `.` to match newlines, OR use `[^#]*?` to stop at the next `###` heading. The safer approach:

```python
pattern = re.compile(
    r'^### ' + re.escape(task_num) + r'\. [^\n]*\n'  # heading line
    r'(?:(?!^### |\Z).)*?'                             # body (stops before next ### or EOF)
    r'^---[ \t]*\n?',                                  # trailing separator
    re.MULTILINE | re.DOTALL
)
```

However the simplest reliable approach is to work line-by-line:

```python
lines = content.split('\n')
start_pattern = re.compile(r'^### ' + re.escape(task_num) + r'\. ')
in_block = False
output_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if not in_block and start_pattern.match(line):
        in_block = True
        i += 1
        continue
    if in_block:
        if line.strip() == '---':
            in_block = False  # consume the separator
            i += 1
            continue
        i += 1
        continue
    output_lines.append(line)
    i += 1
new_content = '\n'.join(output_lines)
```

**Recommended approach**: The line-by-line approach is most robust because it handles:
- Multi-line descriptions
- Descriptions that contain `---` as markdown content (unlikely but possible)
- The last task in the file where there may be no trailing `---`

### 4. Edge Cases to Handle

| Edge Case | Handling |
|-----------|----------|
| Task is the last entry (no trailing `---`) | Line-by-line approach: exit block on `### next_N` or EOF |
| Task number partial match (e.g., task 6 matching `### 61.`) | Use `^### 6\. ` anchored with literal dot and space |
| Task block contains `---` in description | Line-by-line: stop only when `line.strip() == '---'` (exact) |
| TODO.md not found | Already guarded by `if [ -f "$TODO_FILE" ]` |
| Python not available | `|| true` already in place; non-fatal |
| Dry-run mode | The Step C block is skipped in dry-run (exits early at line 83) |

### 5. Where to Insert the Fix

**File**: `.claude/scripts/archive-task.sh` — lines 110–138 (Step C block).

The entire Step C heredoc block from `python3 - "$TODO_FILE" "$task_number" <<'PYEOF'` through `PYEOF` must be replaced with an updated Python heredoc using the corrected pattern.

**Also update**: `.claude/extensions/core/scripts/archive-task.sh` — lines 110–138 (identical content).

Confirmed by diff: both files are byte-for-byte identical copies. Both need the exact same fix applied.

### 6. `update-task-status.sh` — Reuse Potential

`update-task-status.sh` does update the TODO.md task entry status in-place (lines 185–233) and updates the Task Order section (lines 238–307). However, it does **not** remove blocks — it only updates the `[STATUS]` field within existing blocks. It cannot be called here to do the removal.

The Task Order section cleanup is handled by `generate-task-order.sh` (called from `update-task-status.sh` Phase 3 for terminal statuses). This only affects the `## Task Order` section, not the `## Tasks` section entries.

### 7. `generate-task-order.sh` — Does Not Clean the `## Tasks` Section

`generate-task-order.sh` regenerates only the `## Task Order` section by replacing everything between `## Task Order` and `## Tasks` headers. The `## Tasks` section with its individual `### N.` blocks is never touched by this script. This confirms the bug: there is no mechanism that removes task blocks from `## Tasks` — only the broken Python pattern in `archive-task.sh` was supposed to do it.

### 8. The `/todo` Command Flow

The `/todo` command (in `.claude/commands/todo.md`) calls `archive-task.sh` in a loop for each archivable task (Step 5, line ~266-268). The comment in `todo.md` explicitly states: *"update TODO.md, move directory — all handled by archive-task.sh"*. The bug is that Step C of `archive-task.sh` silently fails (exits with `|| true`), so the TODO.md cleanup never happens.

---

## Decisions

- **Fix location**: Step C heredoc in `archive-task.sh` (both copies)
- **Approach**: Line-by-line Python block removal (most robust)
- **Error semantics**: Keep as best-effort (`|| true`) — the script should not abort if TODO.md cleanup fails
- **Dry-run**: No changes needed; dry-run already exits before Step C

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Task number partial match (e.g., removing task 6 when task 16/61 exists) | Anchor with `^### {N}\. ` (literal dot + space after number) |
| Last task has no `---` separator | Line-by-line: stop block at EOF if `---` not found |
| Stale Task Order entry after block removal | `generate-task-order.sh` is called later in `/todo` (Step 5.8), which regenerates the Task Order from state.json — already cleaned by Step B |
| Extension copy diverges | Apply identical fix to both files; note them as dual-maintenance copies |

---

## Implementation Plan Summary

**Phase 1**: Replace Step C in `.claude/scripts/archive-task.sh`
- Remove lines 115–137 (the Python heredoc with broken regex)
- Replace with corrected Python heredoc using line-by-line block removal
- Use `^### {N}\. ` as the block start anchor
- Stop block at first `---` line (exact) or next `### ` heading

**Phase 2**: Apply identical change to `.claude/extensions/core/scripts/archive-task.sh`

**Phase 3**: Verify by manual test
- Create a test TODO.md snippet with a task block
- Run the Python snippet against it
- Confirm the block is removed and surrounding blocks are intact

---

## Appendix

### Exact Line Numbers in `archive-task.sh`

Both copies (`.claude/scripts/` and `.claude/extensions/core/scripts/`):

```
Line 110:  # --- C. Update TODO.md (remove completed/abandoned entry) ---
Line 111:  # This is a best-effort step -- warn on failure but don't abort
Line 112:  if [ -f "$TODO_FILE" ]; then
Line 113:    # Find the task entry lines (pattern: "- #N:" or "- **#N**:")
Line 114:    # Use a Python one-liner for reliable multi-line removal
Line 115:    python3 - "$TODO_FILE" "$task_number" <<'PYEOF' 2>/dev/null || true
... [broken Python] ...
Line 137:  PYEOF
Line 138:  fi
```

The fix replaces lines 113–138 (the comment about the wrong pattern plus the entire heredoc block).

### Verified: Both Copies Are Identical

```bash
diff .claude/scripts/archive-task.sh .claude/extensions/core/scripts/archive-task.sh
# (no output — files are identical)
```
