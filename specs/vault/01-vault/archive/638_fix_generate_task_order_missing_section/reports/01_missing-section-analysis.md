# Research Report: Task #638

**Task**: 638 - Fix generate-task-order.sh to create Task Order section when missing
**Started**: 2026-06-08T18:00:00Z
**Completed**: 2026-06-08T18:30:00Z
**Effort**: 30 minutes (research only)
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (nvim version, current)
- `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh` (cslib version, outdated)
- `/home/benjamin/Projects/cslib/specs/TODO.md` (reproduces the bug)
- `/home/benjamin/Projects/BimodalLogic/specs/TODO.md` (reference format)
- `git log` history to identify when fix was introduced
**Artifacts**: `specs/638_fix_generate_task_order_missing_section/reports/01_missing-section-analysis.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The bug exists in the **cslib project's copy** of `generate-task-order.sh`, not the nvim config's copy.
- The nvim config version already contains the fix (`bootstrap_task_order_section` function), added in commit `d926494cd` ("tasks 628, 629, 632: complete orchestration").
- The cslib version is an **older out-of-sync copy** that lacks the bootstrap function. Running it on cslib's `TODO.md` (which has no `## Task Order` section) prints a WARNING and exits with code 1, leaving the file unchanged.
- The fix is straightforward: sync the cslib script by adding the `bootstrap_task_order_section` function and its call at the update path.

---

## Context & Scope

The `generate-task-order.sh` script is used across multiple projects to regenerate the `## Task Order` section in `TODO.md`. Each project has its own copy under `.claude/scripts/`. When a new project initializes its `TODO.md` without a `## Task Order` section, running `generate-task-order.sh --update-todo` should create the section. The bug manifests in the cslib project where this initialization scenario occurs.

---

## Findings

### Codebase Patterns

**Two distinct versions of generate-task-order.sh exist:**

| File | Has `bootstrap_task_order_section`? | Version |
|------|-------------------------------------|---------|
| `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` | YES (line 821) | Current/fixed |
| `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh` | NO | Outdated |

**The diff between the two versions shows exactly two differences:**
1. **Missing un-slugify line** (line 148 in nvim version): `desc="${desc//_/ }"` — cosmetic, makes project_name fallbacks display with spaces instead of underscores.
2. **Missing `bootstrap_task_order_section` function** (lines 815-853 in nvim version) — the core fix.

### Current Behavior (cslib version)

When `--update-todo` is invoked and `## Task Order` is absent from `TODO.md`:

```
replace_section() {
  ...
  if [[ "$section_start" -eq 0 ]]; then
    echo "WARNING: ## Task Order section not found in $TODO_FILE — cannot replace" >&2
    return 1   # <-- exits function with failure
  fi
  ...
}
```

With `set -euo pipefail` active, `return 1` causes the calling script to abort. The result:
- Warning printed to stderr
- Exit code 1 returned
- `TODO.md` left unchanged
- `## Task Order` section never created

**Verified reproduction:**
```bash
$ bash /home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh \
    --update-todo /home/benjamin/Projects/cslib/specs/TODO.md \
    /home/benjamin/Projects/cslib/specs/state.json
WARNING: ## Task Order section not found in .../TODO.md — cannot replace
$ echo $?
1
```

### Expected Behavior

When `## Task Order` is absent, the script should:
1. Detect the missing section
2. Insert a blank `## Task Order` placeholder before the `## Tasks` section (or at EOF if `## Tasks` is also absent)
3. Then run `replace_section` which finds the newly-inserted placeholder and replaces it with generated content

This is exactly what `bootstrap_task_order_section()` does in the nvim version:

```bash
bootstrap_task_order_section() {
  # Idempotent: do nothing if section already present
  if grep -q "^## Task Order$" "$TODO_FILE"; then
    return 0
  fi

  echo "INFO: ## Task Order section missing — bootstrapping in $TODO_FILE" >&2

  local tasks_line
  tasks_line=$(grep -n "^## Tasks$" "$TODO_FILE" | head -1 | cut -d: -f1) || true

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

**Verified working (nvim version on cslib's TODO.md):**
```bash
$ bash /home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh \
    --update-todo /tmp/test_cslib_todo.md \
    /home/benjamin/Projects/cslib/specs/state.json
INFO: ## Task Order section missing — bootstrapping in /tmp/test_cslib_todo.md
OK: Task Order section updated in /tmp/test_cslib_todo.md
$ echo $?
0
```

The output correctly generates waves table + topic tree format matching BimodalLogic's format (verified against `/home/benjamin/Projects/BimodalLogic/specs/TODO.md`).

### Root Cause Analysis

The cslib project's `generate-task-order.sh` was copied from the nvim config at an earlier point (before commit `d926494cd` on 2026-06-01 which added `bootstrap_task_order_section`). The cslib copy was never updated when the fix was applied to the nvim version.

The relevant code path before the fix:

```
--update-todo mode:
  1. build_graph()
  2. build_successors_map()
  3. load_topics()
  4. compute_waves()
  5. compute_connected_components()
  6. read_existing_goal()           <-- reads from TODO_FILE
  7. generate_section()             <-- generates new section content
  # MISSING STEP: bootstrap_task_order_section()
  8. replace_section()              <-- FAILS if section absent, exits with code 1
```

After the fix:

```
--update-todo mode:
  ...
  7. generate_section()
  8. bootstrap_task_order_section() <-- NEW: inserts placeholder if missing
  9. replace_section()              <-- now always finds the section
```

### Format Verification

The nvim version generates output matching the expected format:
- Waves table with `| Wave | Tasks | Blocked by | Topics |` columns
- `**Grouped by Topic**` section with `### TopicName` subsections
- Dependency tree with `└─` indentation for dependents
- No artifact links in task order entries (script only accesses `project_number`, `status`, `description`, `topic`, and `dependencies` from `state.json`)

---

## Decisions

- **Root is in cslib copy**: The bug is not in the nvim config's copy; it was already fixed there. The implementation task needs to update the cslib copy.
- **Approach is copy+patch**: The cleanest fix is to copy the two missing pieces from the nvim version into the cslib version (the un-slugify line and the bootstrap function).
- **No behavioral change in happy path**: When `## Task Order` already exists, `bootstrap_task_order_section` returns immediately (idempotent), so existing behavior is fully preserved.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Other projects also have outdated copies | Check BimodalLogic, ModelChecker, dotfiles, etc. for the same missing bootstrap function |
| cslib TODO.md may have unusual structure | Pre-test on a copy before modifying live file |
| sync approach diverges again over time | Consider a canonical symlink or shared script source |

**Note on scope**: A grep across all known project `.claude/scripts/` directories for `bootstrap_task_order_section` would reveal if other projects are affected and need the same update.

---

## Context Extension Recommendations

- **Topic**: Script synchronization pattern across multi-project setups
- **Gap**: No documentation on how shared scripts propagate to child projects, or how to detect out-of-sync copies
- **Recommendation**: Consider adding a note to `.claude/context/repo/project-overview.md` or a new context file describing the script propagation model (sync-on-extension-install vs. manual copy)

---

## Appendix

### Search Queries Used
- `grep -rn "generate-task-order"` across `.claude/` to find all callers
- `diff` between nvim and cslib versions to isolate differences
- `bash` dry-run of both versions against cslib's actual `TODO.md`
- `git log -S "bootstrap_task_order_section"` to find when fix was introduced

### Key File Paths
- Nvim (fixed): `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`
- cslib (buggy): `/home/benjamin/Projects/cslib/.claude/scripts/generate-task-order.sh`
- cslib TODO.md (reproduces bug): `/home/benjamin/Projects/cslib/specs/TODO.md`

### Commit Reference
- Fix introduced in nvim at: `d926494cd` ("tasks 628, 629, 632: complete orchestration", 2026-06-01)
- Task 638 created after: `42b84f3b6` ("task 638: create task for fixing generate-task-order.sh missing section", 2026-06-08)
