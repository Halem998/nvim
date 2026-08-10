# Research Report: Task #496 - Prior-Implementation Context Injection for /research

**Task**: 496 - Add prior-implementation context injection to /research
**Started**: 2026-05-04T12:00:00Z
**Completed**: 2026-05-04T13:00:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `.opencode/skills/skill-researcher/SKILL.md` (full preflight/postflight flow)
- `.opencode/agent/subagents/general-research-agent.md` (agent execution flow)
- `.opencode/skills/skill-implementer/SKILL.md` (implementation skill for comparison)
- `.opencode/skills/skill-planner/SKILL.md` (prior plan discovery pattern)
- `.opencode/context/formats/` (report, plan, summary, handoff, progress schemas)
- `specs/state.json` (task status and artifact tracking schema)
- Task directories: `specs/500_*`, `specs/501_*`, `specs/517_*`, `specs/518_*`, `specs/519_*`
- `.opencode/context/patterns/context-discovery.md` (context loading patterns)
**Artifacts**:
- `specs/496_prior_implementation_context_injection/reports/01_prior-context-research.md` (this report)
**Standards**: report-format.md, return-metadata-file.md, state-management.md

## Executive Summary

- **skill-researcher currently has no prior-implementation context awareness**. When `/research` is run on a task in `[IMPLEMENTING]` or `[PARTIAL]` status, the research agent starts from scratch with only the task description and optional focus prompt.
- **The closest existing pattern is skill-planner's "prior plan discovery"** (Stage 4), which finds the latest existing plan file and passes it as `prior_plan_path` in the delegation context. This proves the pattern of pre-delegation artifact discovery is already established.
- **The recommended injection point is a new Stage 4c in skill-researcher**, positioned after memory retrieval (Stage 4a) and format specification preparation (Stage 4b), and before delegation context assembly (Stage 4/Stage 5).
- **Artifacts to collect**: implementation summaries (`summaries/`), handoff documents (`handoffs/`), and progress files (`progress/`). Plans (`plans/`) and prior research (`reports/`) are already discoverable but should also be referenced.
- **Injection format should mirror the existing memory-context and format-specification patterns**: a clearly delimited block (`<prior-implementation-context>`) inserted into the subagent prompt between the format specification and task-specific instructions.
- **Status detection uses the already-queried state.json data** from Stage 1; no additional I/O is needed.

## Context & Scope

This research investigates how to modify the `skill-researcher` preflight to detect when a task has prior implementation work (status `[IMPLEMENTING]` or `[PARTIAL]`) and inject that context into the research subagent's prompt. This enables research operations on partially-completed tasks to build upon existing work rather than starting from scratch.

The scope is limited to:
- The `skill-researcher` skill preflight stages
- The `general-research-agent` agent prompt
- Artifact formats that contain implementation state
- The injection mechanism and format

Out of scope:
- Modifying the postflight flow
- Changing how other skills (planner, implementer) handle context
- Creating new artifact formats (we use existing ones)

## Findings

### Finding 1: Current skill-researcher Preflight Flow

The skill-researcher preflight has 5 main stages (with substages):

| Stage | Name | Purpose |
|-------|------|---------|
| 1 | Input Validation | Read task from state.json, validate exists |
| 2 | Preflight Status Update | Set status to "researching" via `update-task-status.sh` |
| 3 | Postflight Marker | Create `.postflight-pending` marker file |
| 3a | Read Artifact Number | Get `next_artifact_number` from state.json |
| 4a | Memory Retrieval (Auto) | Call `memory-retrieve.sh`, inject into prompt if non-empty |
| 4b | Read Format Specification | Read `report-format.md`, prepare for injection |
| 4 | Prepare Delegation Context | Build JSON context for subagent |
| 5 | Invoke Subagent | Task tool call with prompt containing context + format + memory |

**Key observation**: Stage 1 already reads the full task entry from state.json, including `status`, `artifacts`, `description`, etc. The status is available at `status=$(echo "$task_data" | jq -r '.status')` but is currently only used for validation (ensuring the task exists).

**Source**: `.opencode/skills/skill-researcher/SKILL.md`, lines 40-62 (Stage 1), lines 124-148 (Stage 4a), lines 147-170 (Stage 4), lines 178-188 (Stage 4b), lines 190-236 (Stage 5).

### Finding 2: Existing Context Injection Patterns

The system already uses two context injection mechanisms that serve as templates for the new feature:

**Pattern A: Memory Context Injection (Stage 4a)**
```bash
# Retrieve
memory_context=$(bash .opencode/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null)

# Inject (in Stage 5 prompt)
{memory_context from Stage 4a -- already wrapped in <memory-context> tags}
```

**Pattern B: Format Specification Injection (Stage 4b)**
```bash
# Read
format_content=$(cat .opencode/context/formats/report-format.md)

# Inject (in Stage 5 prompt)
<artifact-format-specification>
## CRITICAL: Report Format Requirements
{format_content from Stage 4b}
</artifact-format-specification>
```

Both patterns:
1. Read content during preflight
2. Include it as a clearly-delimited block in the subagent prompt
3. Place the block AFTER the delegation context JSON and BEFORE task-specific instructions
4. Are conditional (memory only injects if non-empty; format always injects)

**Source**: `.opencode/skills/skill-researcher/SKILL.md`, lines 124-148, 178-188, 204-226.

### Finding 3: Prior Plan Discovery in skill-planner (Closest Analog)

The planner skill already implements a form of prior-artifact discovery:

```bash
# Discover prior plan (if any)
prior_plan_path=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

This path is then passed in the delegation context as `"prior_plan_path": "..."`. The subagent is expected to read and reference it.

**Key difference**: The planner passes a **path reference**, not the **content**. The subagent must read the file itself. For research on partially-implemented tasks, we want the **content injected directly** so the research agent has immediate context without needing to discover and read files.

**Source**: `.opencode/skills/skill-planner/SKILL.md`, lines 165-174.

### Finding 4: State.json Schema and Status Values

The state.json `active_projects` entries contain:

```json
{
  "project_number": 496,
  "project_name": "prior_implementation_context_injection",
  "status": "not_started",
  "task_type": "meta",
  "description": "Add prior-implementation context injection to /research for tasks in IMPLEMENTING state",
  "artifacts": [
    {"path": "...", "type": "research|plan|summary|handoff", "summary": "..."}
  ],
  "next_artifact_number": 2,
  "memory_candidates": [...],
  "plan_metadata": {...},
  "completion_summary": "..."
}
```

**Relevant status values**:
- `implementing` - Task is currently being implemented
- `partial` - Implementation was interrupted or partially completed
- `researched` - Has research reports
- `planned` - Has implementation plans

The `artifacts` array tracks all artifacts with their `type` field. For prior-implementation context, the relevant types are:
- `summary` - Implementation summaries (in `summaries/`)
- `handoff` - Handoff documents (in `handoffs/`)
- `plan` - Implementation plans (in `plans/`)
- `research` - Prior research reports (in `reports/`)

**Source**: `specs/state.json` (live data, tasks 500, 501, 517, 518, 519).

### Finding 5: Artifact Formats and Directory Structure

**Task directory structure** (observed in tasks 500, 501, 517, 518, 519):
```
specs/{NNN}_{SLUG}/
├── reports/          # Research reports (*.md)
├── plans/            # Implementation plans (*.md)
├── summaries/        # Implementation summaries (*.md)
├── progress/         # Progress tracking files (not observed in current tasks)
└── handoffs/         # Handoff artifacts (not observed in current tasks)
```

**Implementation Summary** (`summary-format.md`):
- Contains: Overview, What Changed, Decisions, Impacts, Follow-ups, References
- Written by implementation agent after `/implement`
- Status markers: `[COMPLETED]`, `[PARTIAL]`, etc.

**Handoff Artifact** (`handoff-artifact.md`):
- Contains: Immediate Next Action, Current State, Key Decisions, What NOT to Try, Critical Context, References
- Written when context exhaustion occurs during implementation
- File naming: `phase-{P}-handoff-{TIMESTAMP}.md`

**Progress File** (`progress-file.md`):
- JSON format tracking phase objectives
- Contains: objectives array with status (not_started, in_progress, done, blocked), approaches_tried, handoff_count
- File naming: `phase-{P}-progress.json`

**Note**: No current tasks have `handoffs/` or `progress/` directories, but the formats are defined and ready for use.

**Sources**:
- `.opencode/context/formats/summary-format.md`
- `.opencode/context/formats/handoff-artifact.md`
- `.opencode/context/formats/progress-file.md`
- Live task directories (500, 501, 517, 518, 519)

### Finding 6: Example Implementation Summary Content

Task 518's implementation summary (`specs/518_unified_ai_tool_picker_session_management/summaries/01_unified-ai-picker-summary.md`) shows the rich context available:

- Phase-by-phase breakdown of completed work
- Key architectural decisions (e.g., `vim.ui.select` for Stage 1, atomic writes)
- Files created/modified
- Verification steps

Task 517's summary shows:
- What changed (MCP server config, tool enablement, agent prompts)
- Decisions (global vs per-project config, leaving Claude Code files unchanged)
- Impacts (OpenCode can now access lean-lsp tools)
- Follow-ups (future enhancements)

These summaries provide exactly the kind of context a research agent needs when investigating a follow-up issue or re-researching a partially-completed task.

**Source**: Live artifact files in task directories 517 and 518.

### Finding 7: general-research-agent Already Supports Context Loading

The research agent's Stage 1.5 loads roadmap context when `roadmap_path` is provided. This proves the agent is architecturally prepared to receive additional context files:

```markdown
### Stage 1.5: Load Roadmap Context
If `roadmap_path` is provided in the delegation context and the file exists:
1. Use `Read` to load the roadmap file
2. Extract priorities and incomplete items
3. Store as `roadmap_context` for use in Stage 2
```

Similarly, the agent could receive `prior_implementation_context` in the delegation context and use it during Stage 2 (Analyze Task and Determine Search Strategy) to avoid redundant research.

**Source**: `.opencode/agent/subagents/general-research-agent.md`, lines 60-69.

## Decisions

1. **Injection Point**: Add a new Stage 4c to skill-researcher, between Stage 4b (format spec) and Stage 4 (delegation context preparation), or merge it into Stage 4.

2. **Detection Logic**: Check `status` from Stage 1. If `status == "implementing"` or `status == "partial"`, trigger artifact collection.

3. **Artifacts to Collect** (in priority order):
   1. **Implementation summaries** (`summaries/*.md`) - Highest value, human-readable overview
   2. **Handoff documents** (`handoffs/*.md`) - Critical if present (context exhaustion state)
   3. **Progress files** (`progress/*.json`) - Machine-readable objective status
   4. **Plans** (`plans/*.md`) - Already discoverable by planner, but useful for research context

4. **Content vs Path**: Inject **content** directly into the prompt (like memory context), not just a path reference. The research agent should not need to read additional files during its initialization.

5. **Tag Format**: Use `<prior-implementation-context>` tags, consistent with `<memory-context>` and `<artifact-format-specification>`.

6. **Length Budget**: Cap total injected content at ~500 lines to avoid overwhelming the subagent prompt. If content exceeds the budget, prioritize summaries over progress files, and handoffs over plans.

## Recommendations

### Recommendation 1: Add Stage 4c to skill-researcher

Insert a new stage in skill-researcher preflight:

```markdown
### Stage 4c: Collect Prior Implementation Context

If task status is "implementing" or "partial", collect existing implementation artifacts from the task directory and prepare them for injection.

```bash
# Check status (from Stage 1)
if [ "$status" = "implementing" ] || [ "$status" = "partial" ]; then
    padded_num=$(printf "%03d" "$task_number")
    task_dir="specs/${padded_num}_${project_name}"
    
    # Collect artifact contents
    prior_context=""
    
    # 1. Implementation summaries (highest priority)
    if [ -d "$task_dir/summaries" ]; then
        for f in $(ls -1 "$task_dir/summaries/"*.md 2>/dev/null | sort -V); do
            prior_context+="\n## Summary: $(basename $f)\n\n$(cat "$f")\n"
        done
    fi
    
    # 2. Handoff documents
    if [ -d "$task_dir/handoffs" ]; then
        for f in $(ls -1 "$task_dir/handoffs/"*.md 2>/dev/null | sort -V | tail -3); do
            prior_context+="\n## Handoff: $(basename $f)\n\n$(cat "$f")\n"
        done
    fi
    
    # 3. Progress files
    if [ -d "$task_dir/progress" ]; then
        for f in $(ls -1 "$task_dir/progress/"*.json 2>/dev/null | sort -V | tail -1); do
            prior_context+="\n## Progress: $(basename $f)\n\n$(cat "$f")\n"
        done
    fi
    
    # 4. Latest plan
    if [ -d "$task_dir/plans" ]; then
        latest_plan=$(ls -1 "$task_dir/plans/"*.md 2>/dev/null | sort -V | tail -1)
        if [ -n "$latest_plan" ]; then
            prior_context+="\n## Plan: $(basename $latest_plan)\n\n$(cat "$latest_plan")\n"
        fi
    fi
fi
```

**Length limiting**:
```bash
# Count lines and warn/truncate if too long
line_count=$(echo -e "$prior_context" | wc -l)
if [ "$line_count" -gt 500 ]; then
    # Truncate with notice
    prior_context=$(echo -e "$prior_context" | head -n 500)
    prior_context+="\n\n[NOTE: Prior implementation context truncated from $line_count lines to 500 lines budget]"
fi
```
```

### Recommendation 2: Update Stage 5 Prompt Injection

Add the prior context block to the subagent prompt in Stage 5, following the same placement rules as memory context:

```
<artifact-format-specification>
## CRITICAL: Report Format Requirements
{format_content from Stage 4b}
</artifact-format-specification>

{prior_context from Stage 4c -- wrapped in <prior-implementation-context> tags}

{memory_context from Stage 4a -- already wrapped in <memory-context> tags}
```

**Placement priority**:
1. Delegation context JSON (first)
2. Format specification (second)
3. Prior implementation context (third) -- NEW
4. Memory context (fourth)
5. Task-specific instructions (last)

This ordering ensures the agent sees implementation state before general memories, which is correct when researching a partially-completed task.

### Recommendation 3: Update general-research-agent.md

Add a new Stage 1.6 to the research agent:

```markdown
### Stage 1.6: Load Prior Implementation Context

If `prior_implementation_context` is provided in the delegation context:

1. Parse the tagged sections (summaries, handoffs, progress, plan)
2. Extract key decisions, current state, and completed work
3. Use this information in Stage 2 to avoid redundant research
4. Reference existing artifacts in the new report rather than rediscovering them
```

Also update Stage 2's "Identify Research Questions" to include:
```
6. What prior implementation work exists and what gaps remain?
```

### Recommendation 4: Add Delegation Context Field

Add `prior_implementation_context` to the delegation context JSON prepared in Stage 4:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher"],
  "timeout": 3600,
  "task_context": { ... },
  "artifact_number": "{artifact_number}",
  "focus_prompt": "{optional focus}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "prior_implementation_context": "{prior_context from Stage 4c, or empty string}"
}
```

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Prior context exceeds prompt budget, crowding out research instructions | Medium | Cap at 500 lines; prioritize summaries over other artifacts; truncate with notice |
| Stale context from old summaries misleads research | Low | Always include the file date in the injected context; agent should verify timestamps |
| Handoff/progress files not present in most tasks (no adoption yet) | Low | Graceful degradation: if no artifacts found, inject nothing (no error) |
| Double-loading: research agent reads the same files skill already injected | Low | Inject content directly (not paths); add explicit instruction to NOT re-read injected files |
| Research on not-yet-implemented tasks (status "planned") gets unnecessary injection | Low | Only trigger on "implementing" and "partial", not "planned" or "researched" |

## Context Extension Recommendations

- **Topic**: Skill preflight context collection patterns
- **Gap**: No documented pattern for how skills should discover and inject prior artifacts into subagent prompts
- **Recommendation**: Create `.opencode/context/patterns/skill-prior-context-injection.md` documenting the Stage 4c pattern for use by skill-researcher, skill-planner, and skill-implementer. Include templates for artifact discovery, length budgeting, and prompt placement.

## Appendix

### Search Queries and Files Examined

**Codebase files read**:
- `.opencode/skills/skill-researcher/SKILL.md` (449 lines)
- `.opencode/agent/subagents/general-research-agent.md` (262 lines)
- `.opencode/skills/skill-implementer/SKILL.md` (513 lines)
- `.opencode/skills/skill-planner/SKILL.md` (490 lines)
- `.opencode/context/formats/report-format.md` (88 lines)
- `.opencode/context/formats/plan-format.md` (147 lines)
- `.opencode/context/formats/summary-format.md` (55 lines)
- `.opencode/context/formats/handoff-artifact.md` (188 lines)
- `.opencode/context/formats/progress-file.md` (250 lines)
- `.opencode/context/formats/return-metadata-file.md` (425 lines)
- `.opencode/context/patterns/context-discovery.md` (297 lines)

**Live task directories examined**:
- `specs/500_add_context_fork_to_core_skills/` (reports/, plans/)
- `specs/501_optimize_team_mode_fork_cache_sharing/` (reports/, plans/)
- `specs/517_fix_opencode_mcp_tools_unavailable_lean/` (reports/, plans/, summaries/)
- `specs/518_unified_ai_tool_picker_session_management/` (reports/, plans/, summaries/)
- `specs/519_add_leader_al_ai_commands_loader_picker/` (reports/, plans/, summaries/)

**State.json analysis**:
- Queried all active project statuses
- Examined artifact array structure
- Verified `next_artifact_number`, `plan_metadata`, `memory_candidates` fields

### Injection Point Diagram

```
Stage 1: Input Validation
    │
    ▼
Stage 2: Preflight Status Update
    │
    ▼
Stage 3: Postflight Marker
    │
    ▼
Stage 3a: Read Artifact Number
    │
    ▼
Stage 4a: Memory Retrieval ──────┐
    │                            │
    ▼                            │
Stage 4b: Format Specification ──┤
    │                            │
    ▼                            │
Stage 4c: Prior Context Collection (NEW)
    │                            │
    ▼                            │
Stage 4: Prepare Delegation Context
    │                            │
    ▼                            │
Stage 5: Invoke Subagent ◄───────┘
    │
    ▼
[Subagent prompt contains:]
1. Delegation context JSON
2. <artifact-format-specification>
3. <prior-implementation-context> (NEW)
4. <memory-context>
5. Task instructions
```

### Skill-Planner Prior Plan Discovery (Reference Pattern)

```bash
# From skill-planner/SKILL.md Stage 4
padded_num=$(printf "%03d" "$task_number")
prior_plan_path=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

This pattern should be extended for skill-researcher to:
1. Check multiple directories (summaries, handoffs, progress)
2. Read file contents (not just paths)
3. Inject contents directly into the prompt
