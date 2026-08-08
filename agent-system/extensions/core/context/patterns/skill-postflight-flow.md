# Shared Postflight Flow (Stage 7, 7a, 8, 8a, 9)

**Placed in core context** so the `@`-import below resolves for every skill that reaches
postflight status update, memory-candidate propagation, artifact linking, TTS notification, and
cleanup, regardless of which extension owns the importing skill. This file is the SINGLE
canonical block for these five stages. Before it existed, every lifecycle skill hand-copied its
own status-update call, its own memory-candidate append (or, in most skills, no append at all —
`skill-planner` had never had a Stage 7a, silently discarding every `memory_candidates` a
`planner-agent` emitted), its own two-step artifact-linking jq pair, and one of eleven
near-identical inline TTS blocks. Routing every importer through `skill_postflight_update`,
`skill_propagate_memory_candidates`, `skill_link_artifacts`, `skill_lifecycle_notify`, and
`skill_cleanup` in `skill-base.sh` makes that drift class structurally impossible: there is
exactly one implementation of each stage, and every caller gets whatever that one implementation
currently does. Every instruction below is DIRECT and EXECUTABLE — none of it is commented-out
pseudocode inside a bash fence.

A skill importing this block MUST NOT also keep an inline copy of any of Stage 7, 7a, 8, 8a, or
9. If the importing skill's own body still contains a hand-rolled `state-write.sh` call for
memory candidates, a hand-rolled two-step artifact-linking jq pair, or an inline
`lifecycle-notify.sh` invocation sitting alongside this import, that is drift re-accumulating and
must be deleted, not kept "just in case".

## Placement: the `## Postflight (ALWAYS EXECUTE)` Marker

This block's five stages sit inside the importing skill's existing
`## Postflight (ALWAYS EXECUTE)` section — the heading that marks "these stages run whether the
work was done by a subagent or inline (Stage 5b), and must not be skipped for any reason". This
import does not create that heading; it replaces the hand-written stage bodies underneath a
heading the importing skill already has. The heading itself, and Stage 6/6a (reading and
validating the return-metadata file, which precede this block and are not part of it), stay
skill-specific.

## Preconditions (variables the importing skill already has in scope)

- `task_number`, `padded_num`, `project_name`, `session_id`, `operation` — same meaning as in
  `skill-preflight-flow.md`.
- `status` — the operation's success-variant string read from `.return-meta.json` at Stage 6
  (`researched` | `planned` | `implemented`), or a failure/partial value.
- `artifact_path`, `artifact_type`, `artifact_summary` — read from `.return-meta.json` at Stage 6
  (via `skill_read_metadata` or an equivalent direct `jq` read).
- `memory_candidates` — the `memory_candidates` JSON array read from `.return-meta.json` at Stage
  6 (`jq -c '.memory_candidates // []'`).
- `field_name`, `next_field` — the two label strings `skill_link_artifacts` uses for its
  `field_name`/`next_field` parameters (e.g. `'**Research**'` / `'**Plan**'` for research,
  `'**Plan**'` / `'**Description**'` for plan/implement). These are operation-specific literals
  the importing skill already knows.
- `skill-base.sh` is already sourced by the importing skill; `skill_postflight_update`,
  `skill_propagate_memory_candidates`, `skill_link_artifacts`, `skill_lifecycle_notify`, and
  `skill_cleanup` are already in scope as shell functions.

## Stage 7: Update Task Status (Postflight)

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
```

This only performs the actual `update-task-status.sh postflight` call when `status` is one of the
success values (`researched`/`planned`/`implemented`); any other status is logged and skipped, so
a failed or partial run never advances state. It also runs the extension `postflight` hook and
appends a `lifecycle_stage` milestone event.

**Not covered by this shared call**: `next_artifact_number` incrementing is operation-specific
(only the research operation advances the sequence; plan/implement stay at `current - 1` to share
the same round) and has no dedicated `skill-base.sh` function. An importing skill that needs this
increment keeps that one `state-write.sh` call inline, immediately after this Stage 7 call —
converting it would require a new shared function this plan does not add (see the parent plan's
Non-Goals: "altering `skill-base.sh`'s existing function signatures").

**On partial/failed status**: `skill_postflight_update` already no-ops on a non-success status;
the importing skill still needs its own guard to skip whatever else it would otherwise do next
(e.g. an artifact-number increment) when the run did not succeed.

## Stage 7a: Propagate Memory Candidates

```bash
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
```

Appends (never overwrites) any memory candidates the subagent emitted to the task's `state.json`
entry. A skill that has never had this stage (the report found `skill-planner` in exactly this
state) gains real memory-candidate propagation the first time it imports this block — this is a
deliberate fix carried by this import, not incidental.

## Stage 8: Link Artifacts

```bash
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
```

Performs the two-step jq pattern internally (remove same-type artifacts, then add the new entry —
using the `select(.type == $atype | not)` form to avoid Issue #1132's `!=` escaping bug) and
regenerates TODO.md via `generate-todo.sh` when `artifact_path` is non-empty. Never construct this
two-step pattern by hand at an importing skill's call site.

## Stage 8a: Lifecycle TTS Notification

```bash
skill_lifecycle_notify "$STATE_STATUS"
```

Fires the TTS + WezTerm tab-coloring notification (e.g. "Tab 3 researched") in the background,
guarded on the notify script's presence, never blocking. `$STATE_STATUS` is the same
lifecycle-status string the importing skill already threads through (its own `status` value, or
an operation-specific rendering of it).

## Stage 9: Cleanup

```bash
skill_cleanup "$padded_num" "$project_name"
```

Removes `.postflight-pending`, `.postflight-loop-guard`, and `.return-meta.json` for the task.
Note: `skill-implementer` also removes `.continuation-loop-guard` — that file is
implementer-specific and is removed with a separate `rm -f` immediately after this call, not
folded into `skill_cleanup` (which stays a 2-arg function shared by every importer).

## Ordering

Stages run in the numbered order above: 7, 7a, 8, 8a, 9. Do not run cleanup (Stage 9) before
artifact linking (Stage 8) — the marker and metadata files Stage 9 removes are still needed as
Stage 8's data source (`artifact_path`/`artifact_type`/`artifact_summary` were read from
`.return-meta.json` at Stage 6, but Stage 8's `skill_link_artifacts` call itself has no file
dependency on the marker — the ordering constraint is about not deleting `.return-meta.json`
before every stage that reads it has run, and Stage 8a's `$STATE_STATUS` is derived from the same
already-read `status` value, not a fresh file read).
