---
name: skill-team-implement
description: Orchestrate multi-agent implementation with parallel phase execution. Spawns teammates for independent phases and coordinates dependent phases. Includes debugger teammate for error recovery.
allowed-tools: Agent, Bash, Edit, Read, Write, Glob
# This skill uses Agent tool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during coordination:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/context/reference/team-wave-helpers.md
---

# Team Implement Skill

Multi-agent implementation with wave-based phase parallelization. Analyzes phase dependencies to identify parallelization opportunities, spawns teammates for independent phases, and coordinates sequential execution of dependent phases.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent implementation via skill-implementer.

## Context References

Reference (load as needed during coordination):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/context/reference/team-wave-helpers.md` - Reusable wave patterns

## Trigger Conditions

This skill activates when:
- `/implement N --team` is invoked
- Task exists and has implementation plan
- Team mode is requested via --team flag

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_number` | integer | Yes | Task to implement |
| `plan_path` | string | Yes | Path to implementation plan |
| `resume_phase` | integer | No | Phase to resume from |
| `team_size` | integer | No | Max concurrent teammates (2-4, default 2) |
| `session_id` | string | Yes | Session ID for tracking |
| `model_flag` | string | No | Model override (haiku, sonnet, opus, fable). If set, use instead of default |
| `effort_flag` | string | No | Effort level (fast, hard). Passed as prompt context |

**Model Selection**: Determine teammate model early:
```bash
# Use model_flag if provided, otherwise default to sonnet (cost-effective for team mode)
teammate_model="${model_flag:-sonnet}"
model_preference_line="Model preference: Use Claude ${teammate_model^} for this task."
```

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must exist in state.json
- `plan_path` - Must exist and contain phases
- `team_size` - Clamp to range [2, 4], default 2

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')

# Validate plan exists
if [ ! -f "$plan_path" ]; then
  return error "Plan not found: $plan_path"
fi

# Validate team_size
team_size=${team_size:-2}
[ "$team_size" -lt 2 ] && team_size=2
[ "$team_size" -gt 4 ] && team_size=4
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-team-implement"
operation="implement"
```

**Routing fix**: this call replaces a hand-rolled `state-write.sh` status write with
`update-task-status.sh preflight` (via `skill_preflight_update`), which regenerates TODO.md
internally — TODO.md's Task Order block is therefore no longer stale for the whole duration of a
team run, since it is now refreshed at preflight, not only at postflight.

`operation="implement"` (not `"team-implement"`) is required here: `update-task-status.sh`'s
`target_status` vocabulary has no `team-implement` value, so this skill maps onto the plain
`implement` operation, same as `skill-implementer`.

**Marker unification note**: this skill's marker previously carried "Shape D" — a `team_size`
field and no `created`/`stop_hook_active`. `skill_create_postflight_marker`'s fixture test asserts
an EXACT Shape A key set, so `team_size` is dropped here rather than carried as an extra field;
the marker's `operation` field now reads `"implement"` (matching `$operation` above) rather than
`"team-implement"`.

---

### Stage 4: Check Team Mode Availability

Verify Agent Teams feature is available:

```bash
# Check environment variable
if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  echo "Warning: Team mode unavailable, falling back to single agent"
  # Fall back to skill-implementer (see Stage 4a)
fi
```

---

### Stage 4a: Fallback to Single Agent

If team mode is unavailable:

1. Log warning about degradation.
2. Invoke the underlying single-agent subagent **directly** via the Agent tool
   (`subagent_type: "general-implementation-agent"`, the same subagent `skill-implementer`'s own
   Stage 5 invokes) — passing the same task_context/delegation_context/format-specification this
   skill would otherwise have assembled per-phase-teammate. **Do NOT invoke the whole
   `skill-implementer` skill**: that would re-run its own full preflight/postflight/continuation
   lifecycle on top of this skill's, double-writing status and markers, and is the defect this
   stage previously carried.
3. Add `degraded_to_single: true` to the metadata: record it via
   `specs/${padded_num}_${project_name}/.degraded-fallback-note.json`
   (`{"degraded_to_single": true, "reason": "team mode unavailable"}`) before invoking the
   subagent, and merge that flag into Stage 13's metadata-write content when composing the final
   team execution summary.
4. Follow `@.claude/context/patterns/skill-self-execution-fallback.md`'s write obligation as
   Stage 4c below describes: the directly-invoked subagent already writes `.return-meta.json`
   (satisfying the obligation), so Stage 4c is a no-op in the direct-subagent case.
5. Continue with postflight — the resulting `.return-meta.json` is read exactly like the normal
   team-implementation path.

---

### Stage 4c: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`. As Stage 4a Step 4 notes, this
stage is reached in its "real write" capacity only when this skill performed work inline without
invoking any subagent at all.

---

### Stage 4b: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since summary stays in the same round as research/plan:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Implement uses (current - 1) to stay in the same round as research/plan
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing summary artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/summaries/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
```

**Note**: Team implement does NOT increment `next_artifact_number`. Only research advances the sequence.

---

### Stage 5: Analyze Phase Dependencies

Parse implementation plan to identify parallelization opportunities. Prefer explicit dependency data from the plan; fall back to heuristic inference for older plans.

**Primary: Explicit dependencies** (plans with `**Depends on**:` fields per phase):

```bash
# Parse explicit "**Depends on**:" fields from each phase
dependency_graph = {}
has_explicit_deps = false

for phase in phases:
  depends_on_field = parse_field(phase, "Depends on")
  if depends_on_field is not None:
    has_explicit_deps = true
    if depends_on_field == "none":
      deps = []
    else:
      deps = [int(x.strip()) for x in depends_on_field.split(",")]
    dependency_graph[phase.number] = {
      "status": phase.status,
      "depends_on": deps
    }
```

**Fallback: Heuristic inference** (plans without explicit dependency fields):

```bash
if not has_explicit_deps:
  # Build dependency graph from file overlap analysis
  dependency_graph = {}
  for phase in phases:
    dependency_graph[phase.number] = {
      "status": phase.status,
      "depends_on": infer_from_file_overlap(phase, phases),
      "files": phase.files_modified
    }
```

**Heuristic signals** (fallback only):
- Implicit dependencies from file modifications (phases modifying same files are dependent)
- Cross-phase imports or references

**`infer_from_file_overlap(phase, phases)` definition**: This function applies the shared
directory-prefix overlap algorithm defined once in
`.claude/context/patterns/file-footprint-overlap.md` (referenced by path — the rule is not
restated here). For the given `phase`, compare its declared/inferred file touch-set (parsed from
the plan's "Files to modify" list for that phase) pairwise against every other phase in `phases`
using the same overlap rule (exact match, or bidirectional directory-prefix containment). Return
the list of phase numbers whose file touch-set overlaps with this phase's — those phases must be
treated as dependencies (serialized), since concurrent dispatch would risk two phase-implementer
sub-agents editing the same file at once. This is the phase-level counterpart to the task-level
Component 4a check in `.claude/docs/reference/standards/multi-task-creation-standard.md`; both
consume the same canonical algorithm.

> **CRITICAL: Plan-Text-Only Analysis** -- Stage 5 analyzes dependencies using file paths and phase descriptions extracted from the plan text. The lead agent MUST NOT read, grep, or glob source files to infer dependencies. All signals come from parsing the plan document itself. Actual source file reading is the exclusive responsibility of phase implementer sub-agents.

---

### Stage 6: Calculate Implementation Waves

**Primary: Read wave table from plan** (plans with `**Dependency Analysis**` table):

```
# Parse the Dependency Analysis table from the plan
# Format: | Wave | Phases | Blocked by |
waves = parse_dependency_analysis_table(plan)

if waves is not empty:
  # Use pre-computed wave groupings directly
  # Example parsed result:
  #   Wave 1: [1]        (blocked by: --)
  #   Wave 2: [2, 3]     (blocked by: 1)
  #   Wave 3: [4]        (blocked by: 2, 3)
```

**Fallback: Compute from dependency graph** (plans without wave table):

```
if waves is empty:
  # Topological grouping from dependency_graph (Stage 5 output)
  Wave 1: Phases with no unfinished dependencies
  Wave 2: Phases depending on Wave 1
  Wave 3: Phases depending on Wave 2
  ...

  Example:
    Phase 1, 2, 3: No dependencies -> Wave 1 (parallel)
    Phase 4: Depends on 1, 2 -> Wave 2
    Phase 5: Depends on 3 -> Wave 2
    Phase 6: Depends on 4, 5 -> Wave 3
```

---

### Stage 7: Spawn Phase Implementers

For each wave, spawn teammates for parallelizable phases (up to team_size):

> **CRITICAL: Template Population from Plan Text Only** -- All template variables (`{phase_details}`, `{files_list}`, `{steps_from_plan}`, `{verification_criteria}`) MUST be populated by extracting text from the plan file. The lead agent MUST NOT read source files, run grep/glob, or use MCP tools to populate these fields. The sub-agent will read source files after it is spawned.

**Phase Implementer Prompt Template**:
```
Implement phase {P} of task {task_number}: {phase_name}

{model_preference_line}

## Plan Context
{phase_details from plan}

## Files to Modify
{files_list}

## Steps
{steps_from_plan}

## Verification
{verification_criteria}

## Instructions
1. Read existing files before modifying
2. Execute steps in order
3. Verify completion with criteria
4. Update phase status in plan file to [COMPLETED]
5. Write results to: specs/{NNN}_{SLUG}/phases/{RR}_phase-{P}-results.md

## On Error
If build/test fails:
1. Write error details to results file
2. Mark phase [PARTIAL] instead of [COMPLETED]
3. Return with error context for debugger
```

---

### Stage 8: Wave Execution Loop

Execute waves sequentially, phases within wave in parallel. Detect Y-shaped
dependency patterns: when a single-phase "trunk" wave precedes a multi-phase
"branching" wave, execute the trunk with a single agent before spawning
parallel teammates for the branching waves.

```
# Y-shaped detection: classify each wave as trunk or branching
# A trunk wave has 1 phase and is followed by a wave with 2+ phases
for i, wave in enumerate(waves):
  next_wave = waves[i+1] if i+1 < len(waves) else None
  wave.is_trunk = (len(wave.phases) == 1 and
                   next_wave is not None and
                   len(next_wave.phases) > 1)

for wave in waves:
  if wave.is_trunk:
    # Trunk wave: execute single phase directly (no team spawning)
    phase = wave.phases[0]
    execute_phase_directly(phase)  # single agent, no teammate overhead
    mark_phase_complete(phase)
  else:
    # Branching or standard wave: spawn parallel teammates
    active_teammates = []
    for phase in wave.phases[:team_size]:
      teammate = spawn_phase_implementer(phase)
      active_teammates.append(teammate)

    # Wait for wave completion
    while not all_complete(active_teammates):
      for teammate in active_teammates:
        if teammate.complete():
          result = teammate.result
          if result.error:
            # Spawn debugger for this phase
            spawn_debugger(phase, result.error)
          else:
            mark_phase_complete(phase)

      # Spawn additional teammates if slots available
      remaining_phases = wave.phases[len(active_teammates):]
      for phase in remaining_phases[:team_size - len(active)]:
        spawn_phase_implementer(phase)

  # Commit wave progress
  git_commit_wave(wave)
```

---

### Stage 9: Handle Phase Errors (Debugger Teammate)

When a phase implementer encounters an error:

**Debugger Teammate Prompt**:
```
Analyze and fix the error in task {task_number} phase {P}:

{model_preference_line}

## Error Details
{error_output}

## Phase Context
{phase_details}

## Files Involved
{files_list}

## Instructions
1. Analyze the error cause
2. Generate hypothesis
3. Attempt fix
4. Verify fix with build/test
5. If fixed: Mark phase [COMPLETED]
6. If not fixable: Document issue and mark [BLOCKED]

Output diagnosis to: specs/{NNN}_{SLUG}/debug/{RR}_phase-{P}-debug.md
```

---

### Stage 10: Per-Wave Commits

After each wave completes, commit progress via `.claude/scripts/git-commit-scoped.sh`, the single
sanctioned implementation of path-scoped, mutex-serialized committing — this also closes this
site's ephemeral-runtime-file staleness gap, since the helper applies the canonical exclusion set
automatically:

```bash
padded_num=$(printf "%03d" "$task_number")
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete wave ${wave_num} (phases ${phase_list})" \
  --session "${session_id}" \
  -- "specs/${padded_num}_${project_name}/" "specs/TODO.md" "$plan_path"
```

---

### Stage 11: Create Implementation Summary

After all waves complete, write summary:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Mode**: Team Implementation ({team_size} max concurrent teammates)
**Duration**: {time}

## Wave Execution

### Wave 1
- Phase 1: {status} ({teammate})
- Phase 2: {status} ({teammate})
- Phase 3: {status} ({teammate})

### Wave 2
- Phase 4: {status} ({teammate})
- Phase 5: {status} ({teammate})

### Wave 3
- Phase 6: {status} ({teammate})

## Changes Made

{Summary of changes from all phases}

## Files Modified

- `path/to/file` - {change description}

## Verification

- Build: {Pass/Fail}
- Tests: {Pass/Fail/N/A}

## Team Metrics

| Metric | Value |
|--------|-------|
| Total phases | {N} |
| Waves executed | {N} |
| Max parallelism | {N} |
| Debugger invocations | {N} |
| Total teammates spawned | {N} |

## Notes

{Any issues, blockers, or follow-up items}
```

Output to: `specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md`

---

### Stage 12: Update Status (Postflight)

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 7 (postflight status update).
This stage's existing behavior always reaches completion once Stage 11's summary is written (there
is no partial/failed branch on this call site, unlike `skill-implementer`'s phase-gated Stage 7),
so the success value `skill_postflight_update` requires is passed literally:

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "implemented"
```

`update-task-status.sh postflight ... implement` maps to state.json status `"completed"`
internally (see `.claude/scripts/update-task-status.sh`'s `postflight:implement ->
STATE_STATUS="completed"` mapping) — this is existing script behavior, not a change made by this
conversion. This also replaces the manual "Update TODO.md" step, since `update-task-status.sh`
regenerates TODO.md internally.

**Link artifact**. Fold `--regen-todo` in — this write is immediately followed by nothing but the TODO.md regen:
```bash
padded_num=$(printf "%03d" "$task_number")
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  --session-id "$session_id" \
  --arg path "specs/${padded_num}_${project_name}/summaries/${run_padded}_implementation-summary.md" \
  --arg type "summary" \
  --arg summary "Team implementation with ${team_size} max concurrent teammates" \
  --regen-todo || echo "WARNING: state-write.sh --regen-todo failed (non-fatal)" >&2
```

If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 12a: Lifecycle TTS Notification

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 8a (TTS notify). This skill
had no lifecycle notification call at all prior to this addition — a distinct defect with the
same user-visible symptom as an unannounced lifecycle transition. Unlike the other lifecycle
skills, this stage does not read `$status` from a Stage-6-style metadata re-read (this skill's
own `status` variable above is the pre-run task status, not a lifecycle-terminal value), so the
literal success value Stage 12 already passes is used directly, matching that call site:

```bash
skill_lifecycle_notify "implemented"
```

Non-blocking: called in background after artifacts are linked. Speaks "Tab N implemented" to
announce the lifecycle transition.

---

### Stage 13: Write Metadata File

Write team execution metadata. Note that `phases_completed`/`phases_total` nest **inside the
`metadata` object** below, as shown — this is the opposite of `.orchestrator-handoff.json`, where
the same two field names are always written at the top level. A writer instruction correct for
one file is wrong for the other; do not move these two fields to the top level of this JSON
object.

**This skill does not write `.orchestrator-handoff.json`** — only `.return-meta.json` (below), so
there is no dispatch_seq field to echo in the normal path. **Defensive case**: should a future
variant of this skill write `.orchestrator-handoff.json`, it MUST echo `dispatch_seq` unchanged
from its own delegation context — copy the value verbatim (never invent, increment, or recompute
one) or omit it when the delegation context omits it. See
`context/patterns/dispatch-report-not-termination.md`.

```json
{
  "status": "implemented",
  "summary": "Team implementation completed with parallel phase execution",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md",
      "summary": "Implementation summary with wave execution details"
    }
  ],
  "team_execution": {
    "enabled": true,
    "wave_count": {N},
    "teammates_spawned": {total_count},
    "max_parallelism": {team_size},
    "debugger_invocations": {N},
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false
  },
  "completion_data": {
    "completion_summary": "Brief description of what was implemented"
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "skill-team-implement",
    "phases_completed": {N},
    "phases_total": {N}
  }
}
```

---

### Stage 14: Final Git Commit

Final commit with summary, via `.claude/scripts/git-commit-scoped.sh`, the single sanctioned
implementation of path-scoped, mutex-serialized committing:

```bash
padded_num=$(printf "%03d" "$task_number")
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete team implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- \
  "specs/${padded_num}_${project_name}/summaries/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json" \
  "$plan_path"
```

---

### Stage 15: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
# Phase results and debug files are intentionally NOT removed by skill_cleanup — it only removes
# .postflight-pending, .postflight-loop-guard, and .return-meta.json.
```

---

### Stage 16: Return Summary

Return brief text summary:

```
Team implementation completed for task {N}:
- Executed {wave_count} waves with up to {team_size} parallel teammates
- Wave 1: Phases 1, 2, 3 (parallel)
- Wave 2: Phases 4, 5 (parallel, after Wave 1)
- Wave 3: Phase 6 (sequential)
- {debugger_count} debugger invocations for error recovery
- All {phase_count} phases completed
- Summary at specs/{NNN}_{SLUG}/summaries/{RR}_implementation-summary.md
- Status updated to [COMPLETED]
```

---

## Error Handling

### Team Creation Failure
- Fall back to skill-implementer
- Mark `degraded_to_single: true`
- Continue with single-agent implementation

### Phase Timeout
- Mark phase [PARTIAL]
- Continue with remaining phases if independent
- Log timeout in summary

### Build/Test Failure
- Spawn debugger teammate
- If debugger succeeds: Continue
- If debugger fails: Mark [BLOCKED], continue with independent phases

### All Phases Blocked
- Return partial status
- Document blocking issues
- User can resolve and re-run

### Git Commit Failure
- Non-blocking: log and continue
- Return success with warning

---

## Return Format

Brief text summary (NOT JSON):

```
Team implementation completed for task {N}:
- Executed 3 waves with up to 2 parallel teammates
- Wave 1: Phases 1, 2 completed in parallel
- Wave 2: Phase 3, 4 completed in parallel
- Wave 3: Phase 5, 6 completed in parallel
- 1 debugger invocation for build error (resolved)
- All 6 phases completed
- Summary at specs/{NNN}_task_name/summaries/01_implementation-summary.md
- Status updated to [COMPLETED]
- Changes committed with session sess_...
```

### Partial Return

```
Team implementation partially completed for task {N}:
- Executed 2 of 3 waves
- Wave 1: Phases 1, 2 completed
- Wave 2: Phase 3 [BLOCKED] (build error unresolved)
- Remaining: Phases 4, 5, 6 blocked by Phase 3
- Debugger attempted fix, see debug report
- Status remains [IMPLEMENTING]
- Run /implement 412 to resume after fixing Phase 3
```

---

## MUST NOT (Postflight Boundary)

After teammates complete phase execution -- whether with status implemented, partial, or failed -- this skill MUST proceed immediately to postflight operations. The skill MUST NOT:

1. **Edit source files** - All implementation work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Use MCP tools** - Domain tools are for teammate use only
4. **Analyze or grep source** - Analysis is teammate work
5. **Write summary/reports** - Artifact creation is done by teammates

> **PROHIBITION**: If a teammate returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the teammate's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## MUST NOT (Pre-Delegation Boundary)

Before spawning phase implementer teammates, this skill MUST NOT:

1. **Read source files** - Source files are read by sub-agents, not the lead
2. **Grep or glob the codebase** - Codebase exploration is sub-agent work
3. **Use MCP tools** - Domain tools (LSP, build, etc.) are for sub-agent use only
4. **Analyze source code** - Code analysis belongs to phase implementers
5. **Run build or test commands** - Verification is done by sub-agents

The pre-delegation phase is LIMITED TO:
- Reading the plan file to extract phases, dependencies, and template variables
- Reading state.json and TODO.md for status updates
- Parsing phase dependency graphs from plan text
- Populating prompt templates with plan-extracted content
- Spawning sub-agents with delegation context
