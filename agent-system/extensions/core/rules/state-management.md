---
paths: specs/**/*
---

# State Management Rules

## File Synchronization

TODO.md is generated from state.json. Agents update state.json only; `generate-todo.sh` handles TODO.md synchronization. Never edit TODO.md directly for status or artifact changes.

### Canonical Sources
- **state.json**: Machine-readable source of truth and sole authoritative state
  - next_project_number
  - active_projects array with status, task_type
  - Faster to query (12ms vs 100ms for TODO.md parsing)

- **TODO.md**: User-facing rendered view (generated from state.json)
  - Human-readable task list with descriptions
  - Status markers in brackets: [STATUS]
  - Single `## Tasks` section (new tasks prepended at top)

## Artifacts Are Append-Only (With Same-Type Supersession)

`active_projects[].artifacts` is **append-only during the task lifecycle** — the same phrasing
the schema already uses for `memory_candidates`, and the two fields should be read as one
concept. The one sanctioned exception is **same-type 1-for-1 supersession**: every current
writer (`skill_link_artifacts` in `skill-base.sh`, `orchestrator-postflight.sh` Stage 8,
`link_artifact` in `reconcile-task-status.sh`, and `skill-reviser/SKILL.md` Stage 8) removes all
existing entries of the incoming artifact's `type` before adding the one new entry — a "latest
pointer" swap for `report`/`plan`/`summary` links, not a bulk deletion.

**Wholesale `.artifacts = [...]` assignment is prohibited.** An agent updating `specs/state.json`
directly must append via `+=`, or call the sanctioned helper (`skill_link_artifacts` or
equivalent) — never replace the array outright. Replacing the array silently discards every
artifact link not re-included in the replacement, even though the underlying files remain on
disk.

**Enforcement mechanism**: `validate-state.sh --deep` checks, per `project_number` and per
artifact `type`, that the count of paths removed relative to the prior git-committed version does
not exceed the count of paths added — a FAIL-level finding on any pair that violates this. A
genuine, intentional deletion is expressible via the repeatable
`--allow-artifact-removal <project_number>[:<type>]` opt-in flag on the validator; every
suppressed finding is still logged, never silent.

**Known limitation**: enforcement is periodic, not write-time. It runs only when
`validate-state.sh --deep` is invoked (currently via `verify-deploy.sh`'s gate 10), so a lossy
direct-`jq` write can still land between validation passes, and a subsequent legitimate commit
moves the comparison baseline forward, potentially hiding an earlier loss from a later diff. This
trade-off is accepted rather than closed by this rule; closing it fully would require a
synchronous (write-time) enforcement path, which is out of scope here.

## Status Transitions

### Permissive Model

Any command can run from any non-terminal status. Only terminal states block transitions:

```
Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]

Any non-terminal status -> any command (research, plan, implement, revise)
Any status -> [BLOCKED] (with reason)
Any status -> [ABANDONED] (moves to archive)
Any non-terminal -> [EXPANDED] (when divided into subtasks)
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
[IMPLEMENTING] -> [PR READY] (implementation complete, awaiting PR submission)
[PR READY] -> [IMPLEMENTING] (if issues found during PR review)
[PR READY] -> [COMPLETED] (after /merge PR submission)
```

### Restrictions
- Cannot transition from terminal states (completed, abandoned, expanded)
- Cannot mark COMPLETED without all phases done

## State-First Update Pattern

When updating task status:

1. **Write state.json** via `jq` (machine state is the sole source of truth)
2. **Regenerate TODO.md** by calling `bash .claude/scripts/generate-todo.sh`

`update-task-status.sh` performs both steps automatically. Agents must not Edit TODO.md directly for status or artifact changes — `generate-todo.sh` handles all TODO.md rendering from state.json.

```bash
# Full state-first update (preferred)
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"

# Manual regeneration after state.json update
bash .claude/scripts/generate-todo.sh
```

## Error Handling

### On Write Failure
1. Do not update either file partially
2. Log error with context
3. Preserve original state
4. Return error to caller

### On Inconsistency Detection
1. Log the inconsistency
2. Use git blame to determine latest
3. Sync to latest version
4. Use git for recovery of overwritten versions

## File Scope

`file_scope` is an optional task field set at creation time: it is descriptive/anticipated (not
filesystem-validated) and is never mutated by status-sync. See
[State Management Schema](.claude/context/reference/state-management-schema.md#file-scope-field)
for the full field definition and its contrast with `modified_files`/`files_touched`.

## Schema Reference

For complete field schemas, status values mapping, artifact linking formats, and directory creation patterns, see:
- [State Management Schema](.claude/context/reference/state-management-schema.md)
