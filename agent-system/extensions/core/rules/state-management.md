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

See `context/reference/state-management-schema.md`'s "Enforcement and Update-Pattern Narrative"
section (Artifacts Are Append-Only subsection) for the enforcement mechanism and its known
periodic-not-write-time limitation.

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

```bash
# Full state-first update (preferred)
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"

# Manual regeneration after state.json update
bash .claude/scripts/generate-todo.sh
```

See `context/reference/state-management-schema.md`'s "Enforcement and Update-Pattern Narrative"
section for the two-step explanation and the On Write Failure / On Inconsistency Detection error
handling.

## File Scope

`file_scope` is an optional task field set at creation time: it is descriptive/anticipated (not
filesystem-validated) and is never mutated by status-sync. See
[State Management Schema](.claude/context/reference/state-management-schema.md#file-scope-field)
for the full field definition and its contrast with `modified_files`/`files_touched`.

## Schema Reference

For complete field schemas, status values mapping, artifact linking formats, and directory creation patterns, see:
- [State Management Schema](.claude/context/reference/state-management-schema.md)
