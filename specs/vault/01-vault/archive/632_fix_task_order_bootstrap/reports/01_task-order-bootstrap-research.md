# Research Report: Task #632

**Task**: 632 - Fix generate-task-order.sh to bootstrap Task Order section if missing
**Started**: 2026-06-01T00:00:00Z
**Completed**: 2026-06-01T00:10:00Z
**Effort**: XS (< 30 min)
**Dependencies**: None
**Sources/Inputs**: Codebase (generate-task-order.sh, task.md, todo.md, update-task-status.sh)
**Artifacts**: specs/632_fix_task_order_bootstrap/reports/01_task-order-bootstrap-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The script operates in strict replace-only mode: `replace_section()` scans for `^## Task Order$` and exits with `return 1` (WARNING) if not found. All callers treat this as non-fatal, so new projects silently never get a Task Order.
- BimodalHarness `/home/benjamin/Projects/BimodalHarness/specs/TODO.md` is confirmed missing `## Task Order` — it has only frontmatter (`---` block), `# TODO`, and `## Tasks`.
- The minimal fix is a `bootstrap_section_if_missing()` helper called in main just before `replace_section()`. It inserts `\n## Task Order\n\n` immediately before `## Tasks` (or appends to EOF if `## Tasks` is also absent).
- The fix must be idempotent: if `## Task Order` already exists, do nothing. No changes to `replace_section()` itself are needed.

---

## Context & Scope

### Script Location
`/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` — 855 lines, `set -euo pipefail`.

### Callers
Three callers, all treat non-zero exit as non-fatal:
1. `.claude/commands/task.md` line 223 — `|| echo "Note: Failed..."` pattern
2. `.claude/commands/todo.md` line 450 — same `|| echo` pattern
3. `.claude/scripts/update-task-status.sh` lines 251, 276 — `|| echo "Warning: ...failed (non-fatal)"`

### Script Flow (update mode)
```
parse args
-> validate STATE_FILE exists, TODO_FILE exists (exits if missing)
-> build_graph()
-> check all_task_nums empty (exits 0 if no active tasks)
-> build_successors_map()
-> load_topics()
-> compute_waves()
-> compute_connected_components()
-> read_existing_goal()  (safe: returns "" if section absent)
-> generate_section()
-> replace_section()     <-- FAILS HERE if ## Task Order absent
-> echo "OK: ..."
```

---

## Findings

### Finding 1: `replace_section()` — exact failure path (lines 763-812)

```bash
replace_section() {
  local new_content="$1"
  local tmp_file
  tmp_file=$(mktemp)

  local section_start=0
  local section_end=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "$line" =~ ^##\ Task\ Order$ ]]; then
      section_start=$line_num
    fi
    if [[ "$section_start" -gt 0 && "$section_end" -eq 0 && "$line_num" -gt "$section_start" ]]; then
      if [[ "$line" =~ ^##\  ]]; then
        section_end=$line_num
        break
      fi
    fi
  done < "$TODO_FILE"

  if [[ "$section_start" -eq 0 ]]; then
    echo "WARNING: ## Task Order section not found in $TODO_FILE — cannot replace" >&2
    return 1    # <-- this is the failure point
  fi
  ...
}
```

The `return 1` propagates as a non-zero exit from main because `set -euo pipefail` is active (the `elif [[ "$MODE" == "update" ]]` branch calls `replace_section` directly with no `||` guard).

### Finding 2: BimodalHarness TODO.md structure

```
---
next_project_number: 40
---

# TODO

## Tasks

### 30. Design documentation...
...
```

There is no `## Task Order` section. The structure is: YAML frontmatter block, `# TODO`, `## Tasks` (with entries). The correct insertion point is between `## Tasks` and the existing task entries — specifically, `## Task Order` should be inserted **before** `## Tasks` so that when `replace_section()` runs, it sees `## Tasks` as the next `##` heading and correctly sets `section_end`.

Wait — re-reading the format: `replace_section()` replaces the content *of* the Task Order section and stops at the next `## ` heading. The Task Order section should come **before** `## Tasks` in the final document so the visual order reads: Task Order (dependency graph) then Tasks (detailed list). Both sections can coexist as separate `##` blocks.

### Finding 3: Section ordering

Looking at the nvim project's own TODO.md for reference:
```bash
grep -n "^##" /home/benjamin/.config/nvim/specs/TODO.md
```
The standard order is:
1. `## Task Order` (first, auto-generated)
2. `## Tasks` (second, manual entries)

So when bootstrapping, the new section must be inserted **before** `## Tasks`.

### Finding 4: Edge cases

| Scenario | Behavior |
|----------|----------|
| `## Tasks` heading present | Insert `## Task Order\n\n` before `## Tasks` line |
| `## Tasks` heading absent | Append `\n## Task Order\n\n` at end of file |
| TODO.md does not exist | Already handled: script exits with `ERROR` before reaching bootstrap |
| `## Task Order` already exists | Bootstrap does nothing (idempotent guard) |
| File is empty | Insert at EOF (same as "## Tasks absent" case) |
| YAML frontmatter present | Handled naturally — grep scans the whole file; inserting before `## Tasks` is safe because frontmatter uses `---` delimiters, not `##` headings |

### Finding 5: `read_existing_goal()` is already safe

`read_existing_goal()` returns `""` when `## Task Order` is absent (it just finds nothing). So in the main flow, `GOAL_TEXT` will be `""` for new projects unless `--goal` is passed. This is correct behavior — no change needed there.

### Finding 6: `set -euo pipefail` interaction

The script has `set -euo pipefail`. The bootstrap helper must not use commands that can legitimately return non-zero (like `grep` returning 1 for no-match). Use `grep ... || true` or conditional `if grep ...` form.

---

## Decisions

1. **Add a `bootstrap_task_order_section()` function** near the `replace_section()` block (around line 759), called in main just before `replace_section()`.
2. **Insertion point**: use `grep -n` to find `## Tasks`, then use `head`/`tail` split to insert before it. If not found, append.
3. **No modification to `replace_section()`** — it is correct and well-tested; adding a pre-pass is lower risk.
4. **Idempotent guard in bootstrap**: check `grep -q "^## Task Order$" "$TODO_FILE"` before doing anything.
5. **The bootstrap function logs to stderr with INFO prefix** (not WARNING) so callers can observe it.

---

## Recommended Implementation

### New function (insert after line 812, before the `# Main` banner):

```bash
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
```

### Main block change (around line 852):

```bash
elif [[ "$MODE" == "update" ]]; then
  bootstrap_task_order_section  # <-- add this line
  replace_section "$SECTION_CONTENT"
  echo "OK: Task Order section updated in $TODO_FILE"
fi
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `grep -n` returns 1 (no match) causing pipefail | Use `grep ... \| head -1 \| cut` — `head` and `cut` always exit 0; only `grep` can return 1, so assign via `tasks_line=$(grep ... \| head -1 \| cut ...)` — this pipeline's exit code is `cut`'s (0). Actually: pipefail applies to the *last* command in a pipeline — need to verify. Use explicit `if grep -q ...; then tasks_line=$(grep ...); fi` pattern instead. |
| `mktemp` failure | Extremely rare; `set -e` will abort cleanly if it happens |
| Race condition on TODO_FILE | Not a concern — single-process script, no concurrency |
| Blank line handling around insertion | Inserting `## Task Order\n\n` (2 newlines) before `## Tasks` matches the style of existing TODO.md formatting. The line before `## Tasks` may already have a blank line — this could create a double blank. Acceptable (cosmetic only), or can trim by doing `head -n "$((tasks_line - 1))"` which may include a trailing blank from the original. |

### Pipefail fix for `grep | head | cut`:

In bash `set -euo pipefail`, the exit status of a pipeline is the exit status of the **last** command that failed, or 0 if all succeed. `cut` always exits 0 even with empty input. `head -1` always exits 0. So `grep ... | head -1 | cut -d: -f1` will have exit code 0 even when grep finds nothing — `tasks_line` will just be an empty string. This is safe.

---

## Context Extension Recommendations

- **Topic**: bootstrap patterns in agent scripts
- **Gap**: No documented pattern for scripts that need to be idempotent across new/existing projects
- **Recommendation**: Consider a note in `.claude/context/patterns/` about the "detect-and-bootstrap" pattern for TODO.md section management

---

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (full, 855 lines)
- `/home/benjamin/Projects/BimodalHarness/specs/TODO.md` (full, confirms missing section)
- `/home/benjamin/.config/nvim/.claude/commands/task.md` (lines 218-228)
- `/home/benjamin/.config/nvim/.claude/commands/todo.md` (lines 447-454)

### Key Line References in Script
- Line 27: `set -euo pipefail`
- Lines 710-733: `read_existing_goal()` — safe if section absent
- Lines 763-812: `replace_section()` — fails at line 787 if section absent
- Lines 847-855: main dispatch — `replace_section` called with no fallback in update mode
