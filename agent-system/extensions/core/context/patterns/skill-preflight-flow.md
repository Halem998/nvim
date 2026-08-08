# Shared Preflight Flow (Stage 2 + Stage 3)

**Placed in core context** so the `@`-import below resolves for every skill that reaches
preflight status update and marker creation, regardless of which extension owns the importing
skill. This file is the SINGLE canonical Stage 2 + Stage 3 block. Before this block existed, each
lifecycle skill hand-copied its own `update-task-status.sh preflight` call and its own
`.postflight-pending` heredoc — the measured corpus carried SIX mutually incompatible marker
shapes across ~40 writers, purely from copy-and-drift. Routing every importer through
`skill_preflight_update` and `skill_create_postflight_marker` in `skill-base.sh` makes that class
of drift structurally impossible: there is exactly one place the marker schema is defined, and
every caller gets whatever that one place currently emits. Every instruction below is DIRECT and
EXECUTABLE — none of it is commented-out pseudocode inside a bash fence.

A skill importing this block MUST NOT also keep an inline copy of Stage 2 or Stage 3. If the
importing skill's own body still contains a `cat > .../.postflight-pending << EOF` heredoc or a
hand-rolled `update-task-status.sh preflight` call sitting alongside this import, that is drift
re-accumulating and must be deleted, not kept "just in case".

## Preconditions (variables the importing skill already has in scope)

- `task_number` — the task's unpadded integer number (from the delegation context or resolved via
  `state.json`).
- `padded_num` — the task's 3-digit zero-padded directory number, e.g. `printf "%03d" "$task_number"`.
- `project_name` — the task's slug, the `{SLUG}` half of `specs/{NNN}_{SLUG}/`.
- `session_id` — the session identifier generated at GATE IN (`sess_{timestamp}_{random}`).
- `operation` — one of `research` | `plan` | `implement`, matching `update-task-status.sh`'s
  `target_status` vocabulary for this skill's role.
- `skill_name` — the literal name of the importing skill (e.g. `"skill-researcher"`), used as the
  marker's `skill` field.
- `skill-base.sh` is already sourced by the importing skill (once, near the top of its first
  bash-bearing stage) — this block assumes `skill_preflight_update` and
  `skill_create_postflight_marker` are already in scope as shell functions.

## Stage 2: Preflight Status Update

Update task status to the operation's "in-progress" variant BEFORE invoking the subagent (or
before doing the work inline). This is a single call to `skill_preflight_update`, which itself
wraps `update-task-status.sh preflight`, runs the extension `preflight` hook, and appends a
`lifecycle_stage` milestone event — do not re-implement any of that inline.

```bash
skill_preflight_update "$task_number" "$operation" "$session_id"
```

This atomically updates state.json (status, timestamps, session_id), TODO.md's task entry, and
TODO.md's Task Order section. If the underlying `update-task-status.sh` call exits non-zero,
abort and keep the current status — `skill_preflight_update` does not swallow that failure.

## Stage 3: Create Postflight Marker

Create the marker file that prevents premature termination (a Stop-hook-active session
terminating between preflight and postflight would otherwise leave the task silently stuck).

```bash
padded_num=$(printf "%03d" "$task_number")
skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
```

The marker's exact schema (Shape A: `session_id`, `skill`, `task_number`, `operation`, `reason`,
`created`, `stop_hook_active`) is defined in exactly one place —
`skill_create_postflight_marker` in `skill-base.sh` — and is asserted by
`tests/test-postflight-marker-schema.sh`. An importing skill never constructs this JSON itself.

## Ordering

Stage 2 always runs before Stage 3 within a single preflight pass: the status update establishes
the task is "in progress" before the marker asserting that in-progress work exists is written. Do
not reorder these two calls relative to each other.

## Failure Semantics

- **Stage 2 failure** (non-zero exit from the underlying `update-task-status.sh` call): abort the
  skill's preflight entirely. Do not proceed to Stage 3 with an unset/unchanged status.
- **Stage 3 failure** (e.g. `specs/${padded_num}_${project_name}/` cannot be created): this is
  rarer than Stage 2 failure since `skill_create_postflight_marker` itself calls `mkdir -p`, but
  if the marker file still fails to write, treat it the same as a Stage 2 failure — do not
  proceed to subagent invocation without a marker in place, since that marker is the sole
  premature-termination guard.
