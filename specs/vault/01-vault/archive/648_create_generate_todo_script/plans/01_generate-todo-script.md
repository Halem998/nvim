# Implementation Plan: Task #648

- **Task**: 648 - Create generate-todo.sh to generate entire TODO.md from state.json
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 647 (completed)
- **Research Inputs**: specs/648_create_generate_todo_script/reports/01_generate-todo-research.md
- **Artifacts**: plans/01_generate-todo-script.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a self-contained bash script `.claude/scripts/generate-todo.sh` that produces the entire `specs/TODO.md` from `specs/state.json` as the sole input. The script generates three sections: YAML frontmatter (from `next_project_number`), Task Order (delegated to `generate-task-order.sh --print`), and Tasks (iterating all `active_projects` entries in descending order). Terminal tasks (completed/abandoned/expanded) appear in the Tasks section but are excluded from Task Order by the existing generate-task-order.sh filter. An append-only log file provides post-validation traceability. Output is written atomically via mktemp + mv.

### Research Integration

Key findings from the research report integrated into this plan:

- **Field completeness**: state.json v1.1.0 (task 647) has all fields needed: title, status, task_type, topic, effort, dependencies, artifacts, description
- **Task Order delegation**: Call `generate-task-order.sh --print` rather than absorbing its 882-line Kahn/DFS logic -- simpler, avoids duplication, already tested
- **Artifact type mapping**: `research`/`report` -> `**Research**`, `plan` -> `**Plan**`, `summary`/`implementation` -> `**Summary**`; count-aware rendering (1 = inline, 2+ = multi-line list)
- **Status mapping**: 11 status values from state.json snake_case to TODO.md `[UPPER CASE]` markers
- **Ordering**: Tasks sorted descending by project_number (newest first)
- **Atomic write**: mktemp in same directory as TODO.md, then mv for atomicity
- **Logging**: `.claude/logs/generate-todo.log` with ISO timestamp format matching existing conventions

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. This is internal agent infrastructure.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Produce a generate-todo.sh script that creates the entire TODO.md from state.json
- Exact format match with the current TODO.md conventions (field order, artifact linking, status markers)
- Atomic write to prevent partial/corrupted output
- Append-only logging for post-validation review
- Idempotent: running twice with the same state.json produces identical output

**Non-Goals**:
- Refactoring update-task-status.sh or postflight-workflow.sh (that is task 649)
- Modifying state.json schema or format
- Replacing generate-task-order.sh (reused as-is via --print)
- Adding interactive features or user prompts to the script
- Implementing log rotation (deferred to task 652)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Output format diverges from current TODO.md conventions | H | M | Phase 3 diff validation against current TODO.md; fix discrepancies before declaring done |
| generate-task-order.sh --print fails or produces unexpected output | M | L | Check exit code; if non-zero, log error and abort; if zero with empty stdout, write empty Task Order section with warning |
| jq != escaping issue (Claude Code #1132) | M | M | Use `select(.status == "X" \| not)` pattern consistently; avoid `!=` operator |
| Description contains printf format specifiers (%s, %d) | M | L | Always use `printf '%s\n' "$var"` -- never pass user data as format string |
| Concurrent callers overwrite each other | L | L | Atomic mv means last writer wins, which is acceptable since same input produces same output |
| Missing optional fields on legacy tasks | L | L | Defensive fallbacks: title from project_name, omit missing effort/topic, empty deps = None |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core script skeleton and task entry generation [COMPLETED]

**Goal**: Create the complete generate-todo.sh script with all sections: argument parsing, YAML frontmatter, Task Order delegation, and Tasks section with full entry formatting.

**Tasks**:
- [x] Create `.claude/scripts/generate-todo.sh` with shebang, `set -euo pipefail`, and SCRIPT_DIR/PROJECT_ROOT variables *(completed)*
- [x] Implement argument parsing: `--todo FILE` (default: specs/TODO.md), `--state FILE` (default: specs/state.json), `--dry-run` (stdout), `--log FILE` (default: .claude/logs/generate-todo.log), `--no-log` *(completed)*
- [x] Implement `format_status()` function: maps state.json snake_case status values to TODO.md `[UPPER CASE]` markers (all 11 values: not_started, researching, researched, planning, planned, implementing, completed, blocked, abandoned, partial, expanded) *(completed)*
- [x] Implement YAML frontmatter generation: read `next_project_number` from state.json, write `---\nnext_project_number: {N}\n---` *(completed)*
- [x] Implement `# TODO` heading and `## Task Order` section: call `"$SCRIPT_DIR/generate-task-order.sh" --print` and capture stdout; check exit code *(completed)*
- [x] Implement `## Tasks` section header *(completed)*
- [x] Implement `generate_task_entry()` function that takes a task number and outputs a complete task entry:
  - Heading: `### {N}. {title}`
  - Field order: Effort, Status, Task Type, Topic (if present), Dependencies
  - Artifact links grouped by type (research/report -> Research, plan -> Plan, summary/implementation -> Summary)
  - Count-aware artifact rendering: single = inline `- **Type**: [path]`, multiple = multi-line list
  - Strip `specs/` prefix from artifact paths
  - Description block: `**Description**: {text}` *(completed)*
- [x] Implement main loop: extract all project_numbers sorted descending via jq, iterate and call `generate_task_entry()` for each, with `---` separator between entries *(completed)*
- [x] Implement atomic write: redirect all output to `mktemp -p "$(dirname "$TODO_FILE")"`, then `mv` temp file to TODO_FILE; use trap to clean up temp file on EXIT *(completed)*
- [x] Make script executable: `chmod +x` *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - New file (the entire script)

**Verification**:
- Script runs without errors: `bash .claude/scripts/generate-todo.sh --dry-run | head -50`
- Output contains YAML frontmatter, Task Order section, and Tasks section
- Task entries have correct field order and formatting
- Artifact links use bracket-only format with specs/ prefix stripped

---

### Phase 2: Logging infrastructure [COMPLETED]

**Goal**: Add append-only logging to the script for post-validation traceability.

**Tasks**:
- [x] Implement `log()` function: appends `[ISO8601_TIMESTAMP] generate-todo: {LEVEL} {MESSAGE}` to log file; respects `--no-log` flag *(completed)*
- [x] Add START log entry at script beginning: `START state={path} todo={path}` *(completed)*
- [x] Add section completion log entries: after frontmatter, after Task Order, after Tasks section *(completed)*
- [x] Add task count summary in OK log entry: `OK tasks={total} (active={count}, terminal={count}) elapsed={seconds}s` *(completed)*
- [x] Add ERROR log entries for failure conditions: state.json not found, generate-task-order.sh failure, jq parse errors *(completed)*
- [x] Add WROTE log entry after successful atomic mv: `WROTE {path}` *(completed)*
- [x] Ensure log directory exists: `mkdir -p "$(dirname "$LOG_FILE")"` *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - Add logging functions and log calls throughout

**Verification**:
- After running, `.claude/logs/generate-todo.log` contains timestamped entries
- Log shows START, section completions, and OK/WROTE on success
- On simulated failure (e.g., missing state.json), log shows ERROR entry

---

### Phase 3: Integration validation and idempotency [COMPLETED]

**Goal**: Validate that the generated TODO.md matches the current format and that the script is idempotent.

**Tasks**:
- [x] Run `bash .claude/scripts/generate-todo.sh --dry-run > /tmp/generated-todo.md` and diff against current `specs/TODO.md` *(completed: remaining diffs are expected data differences from state.json enrichment)*
- [x] Analyze diff output and identify formatting discrepancies (field order, whitespace, separator placement, artifact link format, description rendering) *(completed: fixed blank line before ## Tasks section)*
- [x] Fix any discrepancies found in the script (adjust printf formatting, field ordering, whitespace, trailing newlines) *(completed: added blank line after Task Order section output)*
- [x] Re-run dry-run and verify diff is minimal (only expected differences: Task Order timestamp, possibly status changes from concurrent operations) *(completed: only data differences from state.json enrichment remain)*
- [x] Test idempotency: run generate-todo.sh to write TODO.md, then run again and verify `diff` shows no changes *(completed: two consecutive runs produce identical output)*
- [x] Verify terminal tasks (completed/abandoned/expanded) appear in Tasks section but not in Task Order output *(completed: 11 terminal tasks in Tasks section, 0 in Task Order)*
- [x] Verify the `---` separator appears between task entries but not after the last entry *(completed: last entry has no trailing separator)*

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - Fix any formatting discrepancies found during validation

**Verification**:
- `diff <(bash .claude/scripts/generate-todo.sh --dry-run) specs/TODO.md` shows only expected differences
- Running the script twice produces identical output
- Terminal tasks verified in correct sections

---

### Phase 4: Edge case handling and robustness [COMPLETED]

**Goal**: Handle all edge cases gracefully: missing optional fields, empty artifacts, title fallback, and special characters in descriptions.

**Tasks**:
- [x] Add title fallback: if `title` is null/empty, derive from `project_name` by replacing underscores with spaces and capitalizing first word *(completed)*
- [x] Handle missing optional fields: omit `- **Effort**:` line when effort is null/empty, omit `- **Topic**:` line when topic is null/empty *(completed)*
- [x] Handle empty/missing dependencies: render `None` when dependencies array is empty or absent *(completed)*
- [x] Handle tasks with no artifacts: skip all artifact link lines when artifacts array is empty or absent *(completed)*
- [x] Handle tasks with multiple artifacts of the same type: use multi-line list format per count-aware linking rules *(completed: both research and report types merge under Research group)*
- [x] Handle empty description: omit the `**Description**:` block entirely when description is null/empty *(completed)*
- [x] Handle description with embedded newlines: emit as-is since TODO.md is markdown *(completed)*
- [x] Test with a synthetic state.json entry that has all fields missing/empty to verify graceful handling *(completed: null values handled gracefully)*
- [x] Verify unknown artifact types render as `**{Capitalized_type}**:` with path *(completed: Dataset, Notes etc render correctly)*

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - Add defensive checks and fallback handling

**Verification**:
- Script does not error when optional fields are missing
- Missing fields produce clean output (no empty lines, no "null" text)
- Multi-artifact rendering produces correct multi-line list format
- Title fallback works when title field is absent

---

## Testing & Validation

- [ ] `bash .claude/scripts/generate-todo.sh --dry-run` runs without errors and produces valid markdown
- [ ] Diff of dry-run output vs current TODO.md shows only expected timestamp differences
- [ ] Running the script twice with `--todo specs/TODO.md` produces identical output (idempotency)
- [ ] `--no-log` flag suppresses log output
- [ ] `--dry-run` flag prints to stdout without modifying TODO.md
- [ ] Log file `.claude/logs/generate-todo.log` contains structured entries after a run
- [ ] Terminal tasks (status=completed/abandoned/expanded) appear in Tasks section but not in Task Order
- [ ] Artifact links use bracket-only format `[path]` with `specs/` prefix stripped
- [ ] Status markers map correctly: `not_started` -> `[NOT STARTED]`, `implementing` -> `[IMPLEMENTING]`, etc.
- [ ] Tasks are sorted in descending order by project_number (newest first)

## Artifacts & Outputs

- `.claude/scripts/generate-todo.sh` - The main script (new file)
- `.claude/logs/generate-todo.log` - Log file created on first run (auto-created)
- `specs/648_create_generate_todo_script/plans/01_generate-todo-script.md` - This plan

## Rollback/Contingency

The script is a new file (`generate-todo.sh`) that does not modify any existing scripts. Rollback is simply deleting the new file. The script does not become the authoritative TODO.md writer until task 649 integrates it into the pipeline. Until then, the existing update-task-status.sh and link-artifact-todo.sh scripts continue to function unchanged. If the generated output is incorrect, the current TODO.md can be restored from git history (`git checkout specs/TODO.md`).
