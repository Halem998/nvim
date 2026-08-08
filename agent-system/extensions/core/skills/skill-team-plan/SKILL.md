---
name: skill-team-plan
description: Orchestrate multi-agent planning with parallel plan generation. Spawns 2-3 teammates for diverse planning approaches and synthesizes into final plan with trade-off analysis.
allowed-tools: Agent, Bash, Edit, Read, Write
# This skill uses Agent tool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during synthesis:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/context/reference/team-wave-helpers.md
---

# Team Plan Skill

Multi-agent planning with wave-based parallelization. Spawns 2-3 teammates to generate alternative plans, then synthesizes into a final plan with trade-off analysis.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent planning via skill-planner.

## Context References

Reference (load as needed during synthesis):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/context/reference/team-wave-helpers.md` - Reusable wave patterns

## Trigger Conditions

This skill activates when:
- `/plan N --team` is invoked
- Task exists and status allows planning
- Team mode is requested via --team flag

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_number` | integer | Yes | Task to plan |
| `research_path` | string | No | Path to research report |
| `team_size` | integer | No | Number of teammates (2-3, default 2) |
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
- `team_size` - Clamp to range [2, 3], default 2

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
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate team_size (2-3 for planning)
team_size=${team_size:-2}
[ "$team_size" -lt 2 ] && team_size=2
[ "$team_size" -gt 3 ] && team_size=3
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-team-plan"
operation="plan"
```

**Routing fix**: this call replaces a hand-rolled `state-write.sh` status write with
`update-task-status.sh preflight` (via `skill_preflight_update`), which regenerates TODO.md
internally — TODO.md's Task Order block is therefore no longer stale for the whole duration of a
team run, since it is now refreshed at preflight, not only at postflight.

`operation="plan"` (not `"team-plan"`) is required here: `update-task-status.sh`'s
`target_status` vocabulary has no `team-plan` value, so this skill maps onto the plain `plan`
operation, same as `skill-planner`.

**Marker unification note**: this skill's marker previously carried "Shape D" — a `team_size`
field and no `created`/`stop_hook_active`. `skill_create_postflight_marker`'s fixture test asserts
an EXACT Shape A key set, so `team_size` is dropped here rather than carried as an extra field;
the marker's `operation` field now reads `"plan"` (matching `$operation` above) rather than
`"team-plan"`.

---

### Stage 4: Check Team Mode Availability

Verify Agent Teams feature is available:

```bash
# Check environment variable
if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  echo "Warning: Team mode unavailable, falling back to single agent"
  # Fall back to skill-planner (see Stage 4a)
fi
```

---

### Stage 4a: Fallback to Single Agent

If team mode is unavailable:

1. Log warning about degradation.
2. Invoke the underlying single-agent subagent **directly** via the Agent tool
   (`subagent_type: "planner-agent"`, the same subagent `skill-planner`'s own Stage 5 invokes) —
   passing the same task_context/delegation_context/format-specification this skill would
   otherwise have assembled per-teammate. **Do NOT invoke the whole `skill-planner` skill**: that
   would re-run its own full preflight/postflight lifecycle on top of this skill's, double-writing
   status and markers, and is the defect this stage previously carried.
3. Add `degraded_to_single: true` to the metadata: record it via
   `specs/${padded_num}_${project_name}/.degraded-fallback-note.json`
   (`{"degraded_to_single": true, "reason": "team mode unavailable"}`) before invoking the
   subagent, and merge that flag into Stage 11's metadata-write content when composing the final
   team execution summary.
4. Follow `@.claude/context/patterns/skill-self-execution-fallback.md`'s write obligation as
   Stage 4c below describes: the directly-invoked subagent already writes `.return-meta.json`
   (satisfying the obligation), so Stage 4c is a no-op in the direct-subagent case.
5. Continue with postflight — the resulting `.return-meta.json` is read exactly like the normal
   team-synthesis path.

---

### Stage 4c: Self-Execution Fallback

**Heading-collision note**: this skill's existing Stage 5b is "Load Research Context", an
unrelated concept — the self-execution fallback is placed here at Stage 4c instead, immediately
after Stage 4a/Stage 4 (degraded-path detection), to avoid reusing that number.

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"planned"`. As Stage 4a Step 4 notes, this
stage is reached in its "real write" capacity only when this skill performed work inline without
invoking any subagent at all.

---

### Stage 5a: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since plan stays in the same round as research:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Plan uses (current - 1) to stay in the same round as research
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing plan artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

run_padded=$(printf "%02d" "$artifact_number")
# run_padded is now the artifact number for this team planning run (e.g., "01")
```

**Note**: Team plan does NOT increment `next_artifact_number`. Only research advances the sequence.

---

### Stage 5b: Load Research Context

Load research report if available:

```bash
padded_num=$(printf "%03d" "$task_number")
research_content=""
if [ -n "$research_path" ] && [ -f "$research_path" ]; then
  research_content=$(cat "$research_path")
fi
```

---

### Stage 5: Spawn Planning Wave

Create teammate prompts and spawn wave. Pass `artifact_number` and `teammate_letter` to each teammate.

**Delegation context for teammates**:
```json
{
  "artifact_number": "{run_padded}",
  "teammate_letter": "a",
  "artifact_pattern": "{NN}_candidate-{letter}.md"
}
```

**Teammate A - Plan Version A (Incremental Delivery)**:
```
Create an implementation plan for task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: a

Focus on incremental delivery with verification at each phase.
Each phase should deliver working, tested functionality.
Consider dependencies between phases.

Research findings:
{research_content}

Output your plan to:
specs/{NNN}_{SLUG}/plans/{run_padded}_candidate-a.md

Format: Standard implementation plan format with:
- Overview
- Phases with status markers [NOT STARTED]
- Tasks with file modifications
- A **Verification Tier** per phase (one of `prose`, `local`, `interface`, `full` -- see
  plan-format.md's `## Verification Tiers` section). When uncertain, apply the strictest
  applicable tier (full > interface > local > prose).
- Verification steps per phase
- Estimated effort
```

**Teammate B - Plan Version B (Alternative Boundaries)**:
```
Create an alternative implementation plan for task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: b

Consider different phase boundaries or ordering.
Look for opportunities to parallelize phases.
Focus on risk mitigation through early verification.

Research findings:
{research_content}

Do NOT duplicate Teammate A's exact phase structure.
Provide a meaningfully different approach.

Output your plan to:
specs/{NNN}_{SLUG}/plans/{run_padded}_candidate-b.md

Format: Same as Teammate A
```

**Teammate C - Risk/Dependency Analysis (if team_size >= 3)**:
```
Analyze dependencies and risks for implementing task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: c

Identify:
- Which phases can be parallelized vs must be sequential
- Critical path through the implementation
- High-risk phases requiring extra verification
- External dependencies that could block progress

Research findings:
{research_content}

Output your analysis to:
specs/{NNN}_{SLUG}/plans/{run_padded}_risk-analysis.md

Format: Risk analysis with dependency graph and critical path
```

---

**Spawn teammates using Agent tool**.

**IMPORTANT**: Pass the `model` parameter to enforce model selection:
- Use `model: "sonnet"` for all tasks

**Synthesis uses base number without letter**: After all teammates complete, the synthesis plan uses `{run_padded}_{slug}.md` (e.g., `01_implementation-plan.md`).

---

### Stage 6: Wait for Wave Completion

Wait for all teammates to complete or timeout:

```
Timeout: 30 minutes for Wave 1

While not all complete and not timed out:
  - Check teammate completion status
  - Collect completed results
  - Wait 30 seconds between checks

On timeout:
  - Mark remaining as "timeout"
  - Continue with available results
```

---

### Stage 7: Collect Teammate Results

Read each teammate's output file:

```bash
teammate_results=[]
padded_num=$(printf "%03d" "$task_number")

for candidate in a b; do
  file="specs/${padded_num}_${project_name}/plans/${run_padded}_candidate-${candidate}.md"
  if [ -f "$file" ]; then
    teammate_results+=("...")
  fi
done

# Also check for risk analysis if team_size >= 3
if [ "$team_size" -ge 3 ]; then
  file="specs/${padded_num}_${project_name}/plans/${run_padded}_risk-analysis.md"
  if [ -f "$file" ]; then
    teammate_results+=("...")
  fi
fi
```

---

### Stage 8: Synthesize Plans

Lead synthesizes plan candidates:

1. **Compare phase structures** from candidates A and B
2. **Evaluate trade-offs** between approaches
3. **Incorporate risk analysis** (if available)
4. **Select best elements** from each candidate
5. **Identify parallelization opportunities**

**Trade-off Comparison**:
- Phase count and estimated effort
- Risk profile
- Dependency complexity
- Parallelization potential

---

### Stage 9: Create Final Plan

Write synthesized plan:

```markdown
# Implementation Plan: Task #{N}

**Task**: {title}
**Version**: {run_padded}
**Created**: {ISO_DATE}
**Task Type**: {task_type}
**Mode**: Team Planning ({team_size} teammates)

## Overview

{Synthesized approach based on candidate evaluation}

## Trade-off Analysis

### Candidate A (Incremental Delivery)
- Phases: {N}
- Estimated effort: {hours}
- Strengths: {list}
- Weaknesses: {list}

### Candidate B (Alternative)
- Phases: {N}
- Estimated effort: {hours}
- Strengths: {list}
- Weaknesses: {list}

### Selected Approach
{Explanation of why chosen elements were selected}

## Phases

### Phase 1: {Name} [NOT STARTED]

**Estimated effort**: {hours}

**Objectives**:
1. {Objective}

**Files to modify**:
- `path/to/file` - {changes}

**Steps**:
1. {Step}

**Verification Tier**: {one of `prose`, `local`, `interface`, `full` -- see plan-format.md's
`## Verification Tiers` section}

**Verification**:
- {How to verify}

---

{Additional phases...}

## Dependencies

- {Dependency}

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|

## Success Criteria

- [ ] {Criterion}

## Team Planning Metadata

| Teammate | Role | Status |
|----------|------|--------|
| A | Incremental plan | completed |
| B | Alternative plan | completed |
```

Output to: `specs/{NNN}_{SLUG}/plans/{RR}_implementation-plan.md`

---

### Stage 10: Update Status (Postflight)

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 7 (postflight status update):

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
```

This replaces the hand-rolled status write with `update-task-status.sh postflight` (via
`skill_postflight_update`), which also regenerates TODO.md internally — the manual "Update TODO.md"
step no longer applies.

**Link artifact**. Fold `--regen-todo` in — this write is immediately followed by nothing but the TODO.md regen:
```bash
padded_num=$(printf "%03d" "$task_number")
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  --session-id "$session_id" \
  --arg path "specs/${padded_num}_${project_name}/plans/${run_padded}_implementation-plan.md" \
  --arg type "plan" \
  --arg summary "Team planning with ${team_size} teammates and trade-off analysis" \
  --regen-todo || echo "WARNING: state-write.sh --regen-todo failed (non-fatal)" >&2
```

If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 11: Write Metadata File

Write team execution metadata:

```json
{
  "status": "planned",
  "summary": "Team planning completed with {N} teammates",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/{NNN}_{SLUG}/plans/{RR}_implementation-plan.md",
      "summary": "Implementation plan with trade-off analysis"
    }
  ],
  "team_execution": {
    "enabled": true,
    "wave_count": 1,
    "teammates_spawned": {team_size},
    "teammates_completed": {completed_count},
    "teammates_failed": {failed_count},
    "token_usage_multiplier": 5.0,
    "degraded_to_single": false
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "skill-team-plan",
    "phase_count": {N},
    "estimated_hours": "{X-Y}"
  }
}
```

---

### Stage 12: Git Commit

Commit using targeted staging:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/plans/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete team planning (${team_size} teammates)

Session: ${session_id}
```

---

### Stage 13: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
# Candidate plans are intentionally NOT removed by skill_cleanup — it only removes
# .postflight-pending, .postflight-loop-guard, and .return-meta.json.
```

---

### Stage 14: Return Summary

Return brief text summary:

```
Team planning completed for task {N}:
- Spawned {team_size} teammates for parallel plan generation
- Teammate A: Incremental delivery plan ({N} phases)
- Teammate B: Alternative approach ({N} phases)
- Trade-off analysis completed
- Final plan at specs/{NNN}_{SLUG}/plans/{RR}_implementation-plan.md
- Status updated to [PLANNED]
```

---

## Error Handling

### Team Creation Failure
- Fall back to skill-planner
- Mark `degraded_to_single: true`
- Continue with single-agent planning

### Teammate Timeout
- Continue with available results
- Note timeout in synthesis
- Mark result as partial if critical candidate missing

### Git Commit Failure
- Non-blocking: log and continue
- Return success with warning

---

## Return Format

Brief text summary (NOT JSON):

```
Team planning completed for task {N}:
- Spawned 2 teammates for parallel plan generation
- Teammate A: Incremental plan (4 phases, 8-12 hours)
- Teammate B: Alternative plan (3 phases, 6-10 hours)
- Selected: Hybrid approach favoring Candidate A structure with B's parallelization
- Final plan at specs/412_task_name/plans/01_implementation-plan.md
- Status updated to [PLANNED]
- Changes committed with session sess_...
```

---

## MUST NOT (Postflight Boundary)

After teammates complete and plans are synthesized, this skill MUST NOT:

1. **Edit source files** - All planning work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Analyze task requirements** - Analysis is teammate work
4. **Write plan files** - Artifact creation is done during synthesis, not postflight
5. **Use research tools** - Research is for teammate use only

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
