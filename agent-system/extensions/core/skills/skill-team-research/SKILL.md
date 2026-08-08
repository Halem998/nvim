---
name: skill-team-research
description: Orchestrate multi-agent research with wave-based parallel execution. Spawns 2-4 teammates for diverse investigation angles and synthesizes findings.
allowed-tools: Agent, Bash, Edit, Read, Write
# This skill uses Agent tool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
# Context loaded by lead during synthesis:
#   - .claude/context/patterns/team-orchestration.md
#   - .claude/context/formats/team-metadata-extension.md
#   - .claude/context/reference/team-wave-helpers.md
---

# Team Research Skill

Multi-agent research with wave-based parallelization. Spawns 2-4 teammates to investigate complementary angles, then synthesizes findings into a unified report.

**Task-Type-Aware Routing**: Teammates are spawned with task-type-appropriate prompts and tools. Meta tasks focus on .claude/ system patterns; general tasks use web search and codebase exploration.

**IMPORTANT**: This skill requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If team creation fails, gracefully degrades to single-agent research via skill-researcher.

## Context References

Reference (load as needed during synthesis):
- Path: `.claude/context/patterns/team-orchestration.md` - Wave coordination patterns
- Path: `.claude/context/formats/team-metadata-extension.md` - Team result schema
- Path: `.claude/context/formats/return-metadata-file.md` - Base metadata schema
- Path: `.claude/context/reference/team-wave-helpers.md` - Reusable wave patterns

## Trigger Conditions

This skill activates when:
- `/research N --team` is invoked
- Task exists and status allows research
- Team mode is requested via --team flag

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `task_number` | integer | Yes | Task to research |
| `focus_prompt` | string | No | Optional focus for research |
| `team_size` | integer | No | Number of teammates (2-4, default 2) |
| `session_id` | string | Yes | Session ID for tracking |
| `model_flag` | string | No | Model override (haiku, sonnet, opus, fable). If set, use instead of default |
| `effort_flag` | string | No | Effort level (fast, hard). Passed as prompt context |

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must exist in state.json
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
description=$(echo "$task_data" | jq -r '.description // ""')

# Team research always uses 4 teammates (Primary, Alternatives, Critic, Horizons)
team_size=4
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-team-research"
operation="research"
```

**Routing fix**: this call replaces a hand-rolled `state-write.sh` status write with
`update-task-status.sh preflight` (via `skill_preflight_update`), which regenerates TODO.md
internally — TODO.md's Task Order block is therefore no longer stale for the whole duration of a
team run, since it is now refreshed at preflight, not only at postflight.

`operation="research"` (not `"team-research"`) is required here: `update-task-status.sh`'s
`target_status` vocabulary is `research`/`plan`/`implement`/`pr_ready`/`partial`/`blocked` — there
is no `team-research` value, so this skill maps onto the plain `research` operation, same as
`skill-researcher`.

**Marker unification note**: this skill's marker previously carried "Shape D" — a `team_size`
field and no `created`/`stop_hook_active`. `skill_create_postflight_marker`'s fixture test asserts
an EXACT Shape A key set, so `team_size` is dropped here rather than carried as an extra field;
the marker's `operation` field now reads `"research"` (matching `$operation` above) rather than
`"team-research"`.

---

### Stage 4: Check Team Mode Availability

Verify Agent Teams feature is available:

```bash
# Check environment variable
if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  echo "Warning: Team mode unavailable, falling back to single agent"
  # Fall back to skill-researcher
  # ... (see Stage 4a)
fi
```

---

### Stage 4a: Fallback to Single Agent

If team mode is unavailable:

1. Log warning about degradation.
2. Invoke the underlying single-agent subagent **directly** via the Agent tool
   (`subagent_type: "general-research-agent"`, the same subagent `skill-researcher`'s own Stage 5
   invokes) — passing the same task_context/delegation_context/format-specification this skill
   would otherwise have assembled per-teammate. **Do NOT invoke the whole `skill-researcher`
   skill** (via Skill tool or otherwise): that would re-run its own full preflight/postflight
   lifecycle on top of this skill's, double-writing status and markers. Invoking the subagent
   directly is the fix for the defect this stage previously carried — a wholesale re-delegation
   to `skill-researcher` produced no return metadata of this skill's own, since `skill-researcher`
   consumed and cleaned up its own copy before this skill's postflight ever ran.
3. Add `degraded_to_single: true` to the metadata the subagent writes is not possible (the
   subagent's `.return-meta.json` schema does not carry this field) — instead, record the
   degradation via a distinct marker this skill controls: append a JSON line to
   `specs/${padded_num}_${project_name}/.degraded-fallback-note.json` before invoking the
   subagent (`{"degraded_to_single": true, "reason": "team mode unavailable"}`), and merge that
   flag into Stage 11's metadata-write content when composing the final team execution summary.
4. Follow `@.claude/context/patterns/skill-self-execution-fallback.md`'s write obligation as
   Stage 4c below describes: the directly-invoked subagent already writes `.return-meta.json`
   (satisfying the obligation), so Stage 4c is a no-op in the direct-subagent case — it exists as
   the actual write path only for the rarer case where this skill performs work inline without
   invoking any subagent at all.
5. Continue with postflight — the resulting `.return-meta.json` is read exactly like the normal
   team-synthesis path (Stage 10 onward).

---

### Stage 4c: Self-Execution Fallback

**Heading-collision note**: this skill's existing Stage 5b is "Task Type Routing Decision", an
unrelated concept — the self-execution fallback is placed here at Stage 4c instead, immediately
after Stage 4a/Stage 4 (degraded-path detection), to avoid reusing that number.

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"researched"`. As Stage 4a Step 4 notes, this
stage is reached in its "real write" capacity only when this skill performed work inline without
invoking any subagent at all — the normal team-wave path (Stage 5 onward) and the degraded direct-
subagent path (Stage 4a) both already produce their own `.return-meta.json`.

---

### Stage 5a: Calculate Artifact Number

Read `next_artifact_number` from state.json (or fall back to directory scanning for legacy tasks):

```bash
# Read next_artifact_number from state.json
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks: count existing artifacts
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

# Reconciliation: scan all task subdirs for max artifact number on disk
# Handles legacy tasks where next_artifact_number may be behind actual files
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(find "specs/${padded_num}_${project_name}" -name "[0-9][0-9]_*.md" 2>/dev/null \
  | sed 's|.*/\([0-9][0-9]\)_.*|\1|' | sort -n | tail -1)
max_on_disk=${max_on_disk:-0}
# Strip leading zeros to avoid octal interpretation
max_on_disk=$((10#$max_on_disk))
if [ "$artifact_number" -le "$max_on_disk" ]; then
  artifact_number=$((max_on_disk + 1))
  # If reconciliation advanced the number, also sync state.json so subsequent operations stay in sync
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number = $new_num' \
    --session-id "$session_id" \
    --argjson num "$task_number" --argjson new_num "$artifact_number"
fi

run_padded=$(printf "%02d" "$artifact_number")

# Collision check: ensure no existing synthesis file uses this prefix in reports/
while ls "specs/${padded_num}_${project_name}/reports/${run_padded}_"*.md 2>/dev/null | grep -q .; do
  artifact_number=$((artifact_number + 1))
  run_padded=$(printf "%02d" "$artifact_number")
done
# run_padded is now the artifact number for this team research run (e.g., "01")
```

**Note**: Team research uses the same artifact number for all teammates and synthesis. The artifact number advances after all teammates and synthesis complete.

---

### Stage 5b: Task Type Routing Decision

Determine task-type-specific configuration for teammate prompts:

```bash
# Route by task type
case "$task_type" in
  "meta")
    # Meta tasks - focus on .claude/ system patterns
    context_refs="@.claude/CLAUDE.md, @.claude/context/index.json"
    available_tools="Read, Grep, Glob"
    ;;
  *)
    # General tasks
    context_refs=""
    available_tools="WebSearch, WebFetch, Read, Grep, Glob"
    ;;
esac

# Determine model for teammates: use model_flag if provided, otherwise default to sonnet (cost-effective for team mode)
teammate_model="${model_flag:-sonnet}"

# Prepare model preference line for prompts (secondary guidance)
model_preference_line="Model preference: Use Claude ${teammate_model^} for this analysis."
```

---

### Stage 5: Spawn Research Wave

Create teammate prompts and spawn wave. Pass `artifact_number` and `teammate_letter` to each teammate.

**Delegation context for teammates**:
```json
{
  "artifact_number": "{run_padded}",
  "teammate_letter": "a",
  "artifact_pattern": "{NN}_teammate-{letter}-findings.md",
  "roadmap_path": "specs/ROADMAP.md"
}
```

**Teammate A - Primary Angle**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: a

Focus on implementation approaches and patterns.
Challenge assumptions and provide specific examples.
Consider {focus_prompt} if provided.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-a-findings.md

Format: Markdown with clear sections for:
- Key Findings
- Recommended Approach
- Evidence/Examples
- Confidence Level (high/medium/low)
```

**Teammate B - Alternative Approaches**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: b

Focus on alternative patterns and prior art.
Look for existing solutions we could adapt.
Do NOT duplicate Teammate A's focus on primary approaches.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-b-findings.md

Format: Same as Teammate A
```

**Teammate C - Critic (always present)**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: c

You are the Critic. Your job is to identify gaps, shortcomings, and blind spots in the research.
Focus on:
- What assumptions haven't been validated?
- What could the other researchers be missing or getting wrong?
- Are there known limitations in the proposed approaches?
- Is the task scope complete, or are there important aspects being overlooked?
- What questions should be asked but aren't being asked?

Do NOT duplicate risk analysis (implementation risks). Focus on research quality and completeness.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-c-findings.md

Format: Same as Teammate A
```

**Teammate D - Horizons (always present)**:
```
Research task {task_number}: {description}

{model_preference_line}

Artifact number: {run_padded}
Teammate letter: d

You are the Horizons researcher. Your job is to think about long-term alignment and strategic direction.

Read the project roadmap at {roadmap_path} (from delegation context) if it exists.
If the roadmap file does not exist, contribute general strategic thinking about project direction.

Focus on:
- Does the proposed approach align with the project's long-term goals and priorities?
- Are there opportunities to advance adjacent roadmap items simultaneously?
- Could the task be scoped differently to better serve the project trajectory?
- What creative or unconventional approaches might better serve the long-term vision?
- What strategic challenges remain that this task could help address?

Think outside the box. Challenge conventional approaches where a better path exists.

Output your findings to:
specs/{NNN}_{SLUG}/reports/{run_padded}_teammate-d-findings.md

Format: Same as Teammate A
```

---

**Spawn teammates using Agent tool**.

**IMPORTANT**: Pass the `model` parameter to enforce model selection:
- Use `model: "${teammate_model}"` (from Stage 5b: model_flag if provided, otherwise "sonnet" as default)

The `model_preference_line` in prompts serves as secondary guidance only. The `model` parameter on Agent tool is the enforced selection.

**Synthesis uses base number without letter**: After all teammates complete, the synthesis report uses `{run_padded}_{slug}.md` (e.g., `01_team-research.md`).

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

Read each teammate's output file using run-scoped paths:

```bash
teammate_results=[]
padded_num=$(printf "%03d" "$task_number")

for teammate in a b c d; do
  # Use run-scoped path
  file="specs/${padded_num}_${project_name}/reports/${run_padded}_teammate-${teammate}-findings.md"
  if [ -f "$file" ]; then
    # Parse findings
    # Extract confidence level
    # Check for conflicts with other teammates
    teammate_results+=("...")
  fi
done
```

---

### Stage 8: Synthesize Findings

Lead synthesizes all teammate results:

1. **Extract key findings** from each teammate
2. **Detect conflicts** between findings
3. **Resolve conflicts** with evidence-based judgment
4. **Identify gaps** in coverage
5. **Decide on Wave 2** if significant gaps exist (not implemented in v1)

**Conflict Resolution**:
- Compare findings across teammates
- Log conflicts found
- Make judgment call based on evidence strength
- Document resolution reasoning

---

### Stage 9: Create Unified Report

Write synthesized report:

```markdown
# Research Report: Task #{N}

**Task**: {title}
**Date**: {ISO_DATE}
**Mode**: Team Research ({team_size} teammates)

## Summary

{Synthesized summary of findings}

## Key Findings

### Primary Approach (from Teammate A)
{Findings}

### Alternative Approaches (from Teammate B)
{Findings}

### Gaps and Shortcomings (from Critic)
{Findings}

### Strategic Horizons (from Horizons)
{Findings}

## Synthesis

### Conflicts Resolved
{List of conflicts and how they were resolved}

### Gaps Identified
{List of any remaining gaps}

### Recommendations
{Synthesized recommendations}

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary | completed | high |
| B | Alternatives | completed | medium |
| C | Critic | completed | high |
| D | Horizons | completed | medium |

## References

{Sources cited by teammates}
```

Output to: `specs/{NNN}_{SLUG}/reports/{RR}_team-research.md`

---

### Stage 10: Update Status (Postflight)

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 7 (postflight status update):

```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
```

This replaces the hand-rolled status write with `update-task-status.sh postflight` (via
`skill_postflight_update`), which also regenerates TODO.md internally — the manual "Update TODO.md
via Edit tool" step below no longer applies, since `update-task-status.sh` is the sole authorized
TODO.md-status writer per `state-management.md`.

**Research-specific addition, NOT covered by the shared block**: increment `next_artifact_number`
immediately after the shared block's Stage 7 call, guarded the same way as `skill-researcher` and
`skill-researcher-hard`:

```bash
if [ "$status" = "researched" ]; then
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
      (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
    --session-id "$session_id"
fi
```

**Note**: Team research (like single-agent research) is the only operation that increments `next_artifact_number`. Team plan and team implement use `(current - 1)` to stay in the same "round".

**Link artifact in state.json**:
Fold `--regen-todo` in — this write is immediately followed by nothing but the TODO.md regen:
```bash
padded_num=$(printf "%03d" "$task_number")
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  --session-id "$session_id" \
  --arg path "specs/${padded_num}_${project_name}/reports/${run_padded}_team-research.md" \
  --arg type "research" \
  --arg summary "Team research with ${team_size} teammates" \
  --regen-todo || echo "WARNING: state-write.sh --regen-todo failed (non-fatal)" >&2
```

This regenerates TODO.md from state.json, automatically reflecting the newly linked artifact. If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 11: Write Metadata File

Write team execution metadata:

```json
{
  "status": "researched",
  "summary": "Team research completed with {N} teammates",
  "artifacts": [
    {
      "type": "research",
      "path": "specs/{NNN}_{SLUG}/reports/{RR}_team-research.md",
      "summary": "Synthesized research from {team_size} teammates"
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
  "teammate_results": [...],
  "synthesis": {
    "conflicts_found": {N},
    "conflicts_resolved": {N},
    "gaps_identified": {N},
    "wave_2_triggered": false
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "skill-team-research"
  }
}
```

---

### Stage 12: Git Commit

Commit using targeted staging (prevents race conditions with concurrent agents):

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete team research (${team_size} teammates)

Session: ${session_id}
```

**Note**: Use targeted staging, NOT `git add -A`. See `.claude/context/standards/git-staging-scope.md`.

---

### Stage 13: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
# Teammate findings files are intentionally NOT removed by skill_cleanup — it only removes
# .postflight-pending, .postflight-loop-guard, and .return-meta.json; findings stay for reference.
```

---

### Stage 14: Return Summary

Return brief text summary:

```
Team research completed for task {N}:
- Spawned {team_size} teammates for parallel investigation
- Teammate A: Primary approach findings (high confidence)
- Teammate B: Alternative patterns identified (medium confidence)
- {N} conflicts found and resolved
- Synthesized report at specs/{NNN}_{SLUG}/reports/{RR}_team-research.md
- Status updated to [RESEARCHED]
```

---

## Error Handling

### Team Creation Failure
- Fall back to skill-researcher
- Mark `degraded_to_single: true`
- Continue with single-agent research

### Teammate Timeout
- Continue with available results
- Note timeout in synthesis
- Mark result as partial if critical teammate missing

### Synthesis Failure
- Preserve raw teammate findings
- Mark status as partial
- Provide raw findings to user

### Git Commit Failure
- Non-blocking: log and continue
- Return success with warning

---

## Return Format

Brief text summary (NOT JSON):

```
Team research completed for task {N}:
- Spawned 3 teammates for parallel investigation
- Teammate A: Implementation patterns (high confidence)
- Teammate B: Prior art analysis (medium confidence)
- Teammate C: Risk analysis (high confidence)
- 1 conflict resolved (approach preference)
- Synthesized report at specs/412_task_name/reports/01_team-research.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_...
```

---

## MUST NOT (Postflight Boundary)

After teammates complete and findings are synthesized, this skill MUST NOT:

1. **Edit source files** - All research work is done by teammates
2. **Run build/test commands** - Verification is done by teammates
3. **Use WebSearch/WebFetch** - Research tools are for teammate use only
4. **Analyze or grep source** - Analysis is teammate work
5. **Write reports** - Artifact creation is done during synthesis, not postflight

The postflight phase is LIMITED TO:
- Reading teammate metadata files
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
