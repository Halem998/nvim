# Research Report: Task #495

**Task**: 495 - Add multi-subagent continuation loop to skill-implementer
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: 
- `.opencode/skills/skill-implementer/SKILL.md`
- `.opencode/agent/subagents/general-implementation-agent.md`
- `.opencode/context/formats/handoff-artifact.md`
- `.opencode/context/formats/progress-file.md`
- `.opencode/context/formats/return-metadata-file.md`
- `.opencode/context/patterns/postflight-control.md`
- `.opencode/context/patterns/checkpoint-execution.md`
- `.opencode/context/patterns/skill-lifecycle.md`
- `.opencode/context/patterns/team-orchestration.md`
- `.opencode/skills/skill-team-implement/SKILL.md`
- `.opencode/rules/error-handling.md`
**Artifacts**: - `specs/495_multi_subagent_continuation_loop/reports/01_continuation-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The current `skill-implementer` is a thin wrapper that spawns a **single** `general-implementation-agent` subagent. When that subagent returns `partial` status, the skill simply reports the partial result and requires the user to manually re-run `/implement`.
- Two purpose-built formats already exist for context exhaustion recovery -- `handoff-artifact.md` and `progress-file.md` -- but they are **completely unwired** into the general-implementation-agent. No agent instructions reference them, and no skill logic consumes them.
- The `general-implementation-agent` already has a `partial` return path with `partial_progress`, but it lacks instructions to write handoff artifacts or progress files, and it has no context-exhaustion detection heuristics.
- The recommended approach is a **continuation loop** in `skill-implementer`: after postflight reads metadata, detect `partial` status with a `handoff_path`; if present and under the max-continuation limit, spawn a successor subagent with minimal context (handoff + progress file) rather than requiring user intervention. This turns context exhaustion from a user-blocking event into an automatic handoff.

## Context & Scope

This research covers:
1. Current delegation flow in `skill-implementer`
2. Existing format schemas for handoff and progress tracking
3. Current `general-implementation-agent` execution stages
4. How partial/handoff returns are currently handled
5. Existing continuation or loop mechanisms in the system
6. Relevant patterns from `.opencode/context/patterns/`

The goal is to produce a comprehensive gap analysis and recommend a concrete approach for wiring handoff/progress formats into the agent and adding a multi-subagent continuation loop to the skill.

## Findings

### 1. Current Skill Delegation Flow (skill-implementer)

The `skill-implementer` executes as follows:

```
Stage 1: Input Validation
Stage 2: Preflight Status Update (state.json, TODO.md, plan file -> [IMPLEMENTING])
Stage 3: Create Postflight Marker (.postflight-pending)
Stage 3a: Calculate Artifact Number
Stage 4a: Memory Retrieval (Auto)
Stage 4: Prepare Delegation Context JSON
Stage 4b: Read and Inject Format Specification (summary-format.md)
Stage 5: Invoke Subagent (Task tool -> general-implementation-agent)
Stage 5a: Validate Subagent Return Format
Stage 5b: Self-Execution Fallback
--- Postflight ---
Stage 6: Parse Subagent Return (Read .return-meta.json)
Stage 6a: Validate Artifact Content
Stage 7: Update Task Status
  - "implemented" -> "completed"
  - "partial" -> keep "implementing", update resume_phase
  - "failed" -> keep "implementing" for retry
Stage 8: Link Artifacts
Stage 9: Git Commit
Stage 10: Cleanup (remove marker, metadata)
Stage 11: Return Brief Summary
```

**Key observation**: Stage 7 handles `partial` by updating `resume_phase` in state.json, but the skill **never respawns** the subagent. The user must manually run `/implement` again.

The skill explicitly contains this prohibition:

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

This prohibition is the exact behavior that Task 495 intends to replace with an automatic continuation loop.

### 2. Existing Format Schemas

#### 2a. Handoff Artifact (`handoff-artifact.md`)

- **Location**: `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
- **Purpose**: Enable graceful context exhaustion recovery by providing minimal, structured context for successor teammates.
- **Design Principle**: "Plan FOR context exhaustion, not against it. Handoffs are expected events, not failures."
- **Schema**: One-screen max (~40 lines) with progressive disclosure:
  - `Immediate Next Action` - single specific step
  - `Current State` - file, location, work state
  - `Key Decisions Made` - max 3-4 decisions with rationale
  - `What NOT to Try` - failed approaches to avoid
  - `Critical Context` - max 5 essential facts
  - `References` - paths for deeper context (read only if stuck)
- **Metadata Integration**: `handoff_path` should be included in `partial_progress`:
  ```json
  {
    "status": "partial",
    "partial_progress": {
      "stage": "context_exhaustion_handoff",
      "details": "Approaching context limit. Handoff written with current state.",
      "handoff_path": "specs/.../handoffs/phase-3-handoff-20260212T143022Z.md",
      "phases_completed": 2,
      "phases_total": 4
    }
  }
  ```
- **Artifact Type**: `handoff` is a valid artifact type in metadata.

#### 2b. Progress File (`progress-file.md`)

- **Location**: `specs/{N}_{SLUG}/progress/phase-{P}-progress.json`
- **Purpose**: Incremental tracking of work within implementation phases for resume point identification and handoff context.
- **Schema**:
  ```json
  {
    "phase": 3,
    "phase_name": "Implement validation framework",
    "started_at": "...",
    "last_updated": "...",
    "objectives": [
      {"id": 1, "description": "...", "status": "done"},
      {"id": 2, "description": "...", "status": "in_progress", "note": "..."}
    ],
    "current_objective": 2,
    "approaches_tried": [...],
    "handoff_count": 0
  }
  ```
- **Update Protocol**:
  1. Create at phase start with all objectives as `not_started`
  2. After each objective: set `done`, update `current_objective`
  3. When approach fails: add to `approaches_tried`
  4. Before handoff: ensure progress file reflects current state
  5. On handoff: increment `handoff_count`

#### 2c. Return Metadata (`return-metadata-file.md`)

- **Status values**: `in_progress`, `researched`, `planned`, `implemented`, `partial`, `failed`, `blocked`
- **`partial_progress`** fields: `stage`, `details`, `phases_completed`, `phases_total`
- **`completion_data`** fields: `completion_summary` (all), `roadmap_items` (non-meta)
- **`memory_candidates`**: 0-3 structured candidates
- **`artifacts`**: array with `type`, `path`, `summary` -- `handoff` is a valid type

### 3. Current General-Implementation-Agent Stages

The `general-implementation-agent` executes as follows:

```
Stage 0: Initialize Early Metadata (.return-meta.json with status: "in_progress")
Stage 1: Parse Delegation Context
Stage 2: Load and Parse Implementation Plan
Stage 3: Find Resume Point (scan phases for first incomplete)
Stage 4: Execute File Operations Loop
  A. Mark Phase [IN PROGRESS] in plan file
  B. Execute Steps (read, create/modify, verify)
  C. Verify Phase Completion (build, test, checks)
  D. Mark Phase [COMPLETED] in plan file
Stage 5: Run Final Verification
Stage 6: Create Implementation Summary
Stage 6a: Generate Completion Data
Stage 6b: Emit Memory Candidates
Stage 7: Write Metadata File (status: implemented|partial|failed)
Stage 8: Return Brief Text Summary
```

**Current Error Handling**:
- File operation failure: Return `partial` with error description
- Build/test failure: Attempt fix and retry; if not fixable, return `partial`
- **Timeout**: Mark current phase `[PARTIAL]` in plan, save progress, return `partial` with resume info
- Invalid task/plan: Write `failed` status

**Critical gap**: The agent has NO instructions to:
1. Monitor context usage or detect context exhaustion
2. Write progress files at phase boundaries
3. Write handoff artifacts when approaching limits
4. Include `handoff_path` in `partial_progress`

The timeout handling mentions "save progress" but does not specify writing progress files or handoff artifacts.

### 4. How Context Exhaustion Is Currently Handled

Currently, context exhaustion is handled **reactively** and **manually**:

1. **Agent**: Returns `partial` status with `partial_progress` containing resume info.
2. **Skill**: Reads metadata, sees `partial`, updates `resume_phase` in state.json.
3. **User**: Must manually re-run `/implement` to resume.
4. **Resume**: Next `/implement` invocation reads `resume_phase` from state.json, delegates to a fresh subagent, which re-reads the plan and resumes.

**Problems with current approach**:
- **User-blocking**: Requires human intervention to continue.
- **Context loss**: The fresh subagent must re-read the plan and re-discover context that the previous agent already had.
- **No structured handoff**: The previous agent's state is only captured in `partial_progress.details` (a string), not a structured handoff document.
- **No progress tracking**: There's no per-phase progress file to show exactly which objectives were completed.

### 5. Existing Continuation or Handoff Mechanisms

#### 5a. Postflight Loop Guard (`postflight-control.md`)

The SubagentStop hook has a loop guard:
- Location: `specs/{NNN}_{SLUG}/.postflight-loop-guard`
- Incremented on each blocked stop
- After **3 continuations**, cleanup and allow stop
- Reset when marker is removed normally

**This is NOT a subagent continuation loop** -- it prevents the skill itself from being prematurely terminated by the SubagentStop hook. It does not spawn new subagents.

#### 5b. Team Mode (`skill-team-implement`)

The team implement skill uses `TeammateTool` for parallel phase execution:
- Spawns multiple teammates for independent phases within a wave
- Has debugger teammates for error recovery
- Uses wave-based sequential execution for dependent phases
- Has a fallback to single-agent if team mode is unavailable

**This is NOT a continuation loop for context exhaustion** -- it parallelizes phases, but each teammate is still a single agent that can hit context limits. There is no handoff between teammates for the same phase.

#### 5c. Resume from `resume_phase` (state.json)

The current manual resume mechanism stores `resume_phase` in state.json:
```bash
jq --argjson phase "$phases_completed" \
  '... resume_phase: ($phase + 1)' specs/state.json
```

This is the target for automation -- instead of requiring user re-invocation, the skill should automatically detect partial status and respawn.

### 6. Relevant Patterns from `.opencode/context/patterns/`

| Pattern | Relevance to Continuation Loop |
|---------|-------------------------------|
| `checkpoint-execution.md` | Defines GATE IN -> DELEGATE -> GATE OUT -> COMMIT. The continuation loop adds a "loop back to DELEGATE" path from GATE OUT when partial/handoff is detected. |
| `postflight-control.md` | Marker file protocol and loop guard. The continuation loop should respect the same max-continuation limit (3). |
| `skill-lifecycle.md` | Defines self-contained skill lifecycle. The continuation loop is an extension of the "Delegate" stage, looping within the skill rather than returning to orchestrator. |
| `team-orchestration.md` | Wave-based coordination. Not directly applicable, but the "successor reads handoff, NOT full history" principle applies. |
| `early-metadata-pattern.md` | Agents write early metadata. Each successor subagent should also write early metadata with the same session_id. |
| `anti-stop-patterns.md` | Use continuation-oriented language. The skill should NOT say "returning partial" if it plans to continue; it should say "spawning successor to continue from phase X". |
| `file-metadata-exchange.md` | File I/O patterns for metadata. The continuation loop reads handoff and progress files as inputs for successor spawning. |

## Decisions

1. **Continuation loop belongs in skill-implementer, not the agent**: The agent should remain focused on executing phases and writing handoff/progress artifacts. The skill (lead) should own the loop logic: detect partial -> read handoff -> spawn successor.
2. **Preserve session_id across continuations**: All subagents in the continuation chain share the same session_id for traceability. The delegation_depth increments to prevent infinite recursion.
3. **Max 3 continuations**: Align with the existing loop guard convention from `postflight-control.md`. After 3 handoffs, the skill should report partial and require user intervention.
4. **Progress file is optional, handoff is required for continuation**: The agent should always write a progress file at phase start. For continuation, the skill prioritizes handoff_path if present, falls back to progress file + plan file.
5. **Artifact numbering stays consistent**: All successor subagents use the same `artifact_number` (calculated in Stage 3a) so summaries are written to the same sequence number.
6. **Git commit strategy**: Commit after each subagent completes (phase checkpoint), not just at the very end. This ensures resume points are committed.

## Gap Analysis

### Gap 1: Agent lacks handoff/progress file instructions

**Location**: `general-implementation-agent.md`
**Gap**: No mention of `handoff-artifact.md` or `progress-file.md`. The agent does not know to write these files.
**Impact**: Even if the skill adds a continuation loop, there are no handoff artifacts to feed successors.
**Fix**: Add stages to the agent:
- After Stage 3 (Find Resume Point): Create progress file for current phase
- During Stage 4 (Execute File Operations Loop): Update progress file after each objective
- Before returning partial due to context exhaustion: Write handoff artifact
- In Stage 7 (Write Metadata): Include `handoff_path` in `partial_progress` if handoff was written

### Gap 2: Agent lacks context exhaustion detection

**Location**: `general-implementation-agent.md`
**Gap**: No heuristics for detecting context exhaustion. The agent only handles timeout, not context pressure.
**Impact**: Agent may not know when to write a handoff vs. just continuing.
**Fix**: Add context monitoring guidance:
- Track tool call count (each Read/Write/Edit counts)
- If tool calls exceed ~80% of typical context window (e.g., after 50+ tool calls), consider handoff
- If finding yourself re-reading files (signal of context pressure), write handoff before next major operation
- If about to start a new phase and context feels tight, write handoff instead

### Gap 3: Skill lacks continuation loop logic

**Location**: `skill-implementer.md` Stage 7 and Postflight
**Gap**: The skill treats `partial` as terminal for its own execution. It updates resume_phase and exits.
**Impact**: User must manually re-run `/implement`.
**Fix**: Add a continuation loop stage after Stage 7:
- If status == "partial" and `handoff_path` exists and continuation_count < 3:
  - Read handoff artifact
  - Prepare successor delegation context (same session_id, incremented delegation_depth)
  - Spawn successor subagent (goto Stage 5)
  - Increment continuation_count
  - Loop back to Stage 6 (read successor metadata)
- If status == "implemented" or continuation_count >= 3 or status == "failed": proceed to Stage 8

### Gap 4: Skill cleanup removes metadata too early

**Location**: `skill-implementer.md` Stage 10
**Gap**: Cleanup removes `.return-meta.json` immediately after postflight. In a continuation loop, the successor's metadata must be read before cleanup.
**Impact**: If cleanup happens inside the loop body, the next iteration has no metadata to read.
**Fix**: Move cleanup to AFTER the continuation loop exits (i.e., after the final postflight iteration).

### Gap 5: Postflight marker conflicts with continuation

**Location**: `skill-implementer.md` Stage 3 and 10
**Gap**: The `.postflight-pending` marker is created once and removed once. In a continuation loop, the marker should persist across subagent spawns.
**Impact**: If marker is removed mid-loop, the SubagentStop hook may not fire correctly.
**Fix**: Keep the marker for the entire duration of the continuation loop. Only remove it in final cleanup.

### Gap 6: Git commit strategy needs per-subagent commits

**Location**: `skill-implementer.md` Stage 9
**Gap**: Currently commits once at the end. With continuations, each subagent may complete one or more phases.
**Impact**: If a later continuation fails, earlier progress may not be committed.
**Fix**: Add a per-continuation commit step (inside the loop) after each subagent returns, using the phase checkpoint protocol: `task {N} phase {P}: {phase_name}`.

### Gap 7: No `continuation_count` tracking

**Location**: New field needed
**Gap**: There's no place to track how many times a task has been continued.
**Impact**: Could exceed safe limits.
**Fix**: Store `continuation_count` in state.json task entry or in a loop-guard file in the task directory.

## Recommended Approach

### Phase 1: Wire Formats into General-Implementation-Agent

Modify `general-implementation-agent.md` to add:

**New Stage 3.5: Initialize Progress Tracking**
- After finding resume phase, create `specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`
- Populate objectives from plan file steps
- Set `handoff_count` to current value (read existing progress file if resuming)

**New Stage 4.5: Context Exhaustion Detection**
- Add guidance for monitoring context pressure:
  - "After every 10 tool calls, assess whether you have sufficient context remaining"
  - "If you find yourself re-reading files you already read, this is a signal of context pressure"
  - "Before starting any operation that reads 3+ files, check if a handoff would be safer"

**Modified Stage 4B: Update Progress File**
- After completing each objective/step, update the progress file:
  - Set objective status to `done` or `in_progress`
  - Update `current_objective`
  - Update `last_updated`
- Before attempting a risky approach, add to `approaches_tried` if it fails

**New Stage 4C: Handoff on Context Pressure**
- When approaching context limits (~80% or before a large operation):
  1. Update progress file to reflect current state
  2. Write handoff artifact to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
  3. Increment `handoff_count` in progress file
  4. Return `partial` status with `handoff_path` in `partial_progress`

**Modified Stage 7: Metadata with Handoff**
- If returning `partial` and handoff was written, include:
  ```json
  "partial_progress": {
    "stage": "context_exhaustion_handoff",
    "details": "Handoff written for successor. See handoff artifact for state.",
    "handoff_path": "specs/.../handoffs/phase-P-handoff-TIMESTAMP.md",
    "phases_completed": N,
    "phases_total": M
  }
  ```

### Phase 2: Add Continuation Loop to Skill-Implementer

Modify `skill-implementer.md` to restructure postflight into a loop:

**New Stage 5c: Continuation Loop Init**
- Initialize `continuation_count=0`
- Max continuations = 3

**Restructured Postflight**:
```
Loop:
  Stage 6: Parse Subagent Return (Read Metadata)
  Stage 6a: Validate Artifact
  Stage 6b: Commit Phase Progress (NEW - inside loop)
    git add -A
    git commit -m "task {N} phase {P}: {phase_name}
    
    Session: {session_id}
    "
  Stage 7: Update Task Status
    - If "implemented": break loop, proceed to final postflight
    - If "partial" and handoff_path exists and continuation_count < 3:
      - continuation_count += 1
      - Read handoff artifact (for logging/display)
      - Prepare successor delegation context:
        - Same session_id
        - delegation_depth += 1
        - Include handoff_path and progress file path in context
        - Add "continuation_context" field indicating this is a successor
      - Spawn successor subagent (goto Stage 5)
      - Continue loop (next iteration reads successor metadata)
    - If "partial" and no handoff_path: break loop, report partial (user must resume)
    - If "partial" and continuation_count >= 3: break loop, report partial (max reached)
    - If "failed": break loop, report failed
End Loop

Stage 8: Link Artifacts (after loop)
Stage 9: Git Commit (final)
Stage 10: Cleanup (remove marker, metadata, loop guard)
Stage 11: Return Brief Summary
```

**Successor Delegation Context**:
The successor subagent needs a modified delegation context that includes:
```json
{
  "session_id": "{same_session_id}",
  "delegation_depth": {parent_depth + 1},
  "delegation_path": ["orchestrator", "implement", "skill-implementer", "successor-{N}"],
  "timeout": 7200,
  "task_context": { ...same... },
  "artifact_number": "{same_artifact_number}",
  "plan_path": "{same_plan_path}",
  "metadata_file_path": "{same_metadata_path}",
  "continuation_context": {
    "is_successor": true,
    "continuation_number": 1,
    "handoff_path": "specs/.../handoffs/phase-3-handoff-...md",
    "progress_path": "specs/.../progress/phase-3-progress.json",
    "previous_phases_completed": 2
  }
}
```

**Agent Behavior on Successor Context**:
- If `continuation_context.is_successor` is true, the agent should:
  1. Read the handoff artifact first (immediate next action)
  2. Read the progress file to understand what was completed
  3. Resume from the indicated phase/objective
  4. Do NOT re-read the full plan unless necessary (handoff has references)

### Phase 3: State and TODO.md Updates

- `state.json` should track `continuation_count` and `last_handoff_path` for visibility
- `TODO.md` status stays `[IMPLEMENTING]` throughout the continuation loop
- Only update to `[COMPLETED]` when the loop breaks with `implemented` status

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Infinite continuation loop | High | Hard limit of 3 continuations (same as postflight loop guard). Store count in task directory. |
| Token cost explosion | High | Each continuation spawns a fresh agent with full context. Limit 3. Consider adding a `--max-continuations` flag. |
| Handoff artifact missing or malformed | Medium | Skill falls back to progress file + plan file. If both missing, report partial and require user resume. |
| Successor subagent re-does completed work | Medium | Progress file clearly marks objectives as `done`. Agent instructions say "skip done objectives". |
| Git history bloat from per-phase commits | Low | This is already the intended phase checkpoint protocol. Each phase should be committed. |
| Postflight marker removed too early | Medium | Move cleanup to after the loop. Ensure marker persists across continuations. |
| Race condition: user runs `/implement` while continuation is in progress | Low | Session ID check in state.json. If session_id changes mid-loop, abort continuation. |
| Context exhaustion during handoff writing | Low | Handoff is short (~40 lines). Write it before attempting any large file operations. |

## Context Extension Recommendations

- **Topic**: Continuation Loop Pattern
- **Gap**: No documented pattern for multi-subagent sequential continuation within a single skill invocation
- **Recommendation**: Create `.opencode/context/patterns/subagent-continuation-loop.md` documenting the loop structure, max-continuation limits, successor delegation context, and handoff consumption. This pattern could be reused by other skills (e.g., skill-researcher for long research tasks).

- **Topic**: Context Exhaustion Detection
- **Gap**: No documented heuristics for agents to self-monitor context pressure
- **Recommendation**: Create `.opencode/context/patterns/context-exhaustion-detection.md` with tool-call counting guidelines, re-read detection signals, and handoff trigger thresholds.

## Appendix

### Search Queries Used
- Read `skill-implementer/SKILL.md` (both `.opencode/` and `.opencode/extensions/core/`)
- Read `general-implementation-agent.md` (both `.opencode/agent/subagents/` and `.claude/agents/`)
- Read `handoff-artifact.md`
- Read `progress-file.md`
- Read `return-metadata-file.md`
- Read `postflight-control.md`
- Read `checkpoint-execution.md`
- Read `skill-lifecycle.md`
- Read `team-orchestration.md`
- Read `skill-team-implement/SKILL.md`
- Grep for `handoff|continuation|context.?exhaust|partial.?progress|resume` in `.opencode/rules/` and `.opencode/context/patterns/`

### References
- `.opencode/skills/skill-implementer/SKILL.md` - Current skill flow with prohibition on continuation
- `.opencode/agent/subagents/general-implementation-agent.md` - Current agent stages (254 lines)
- `.opencode/context/formats/handoff-artifact.md` - Handoff schema (188 lines), currently unwired
- `.opencode/context/formats/progress-file.md` - Progress tracking schema (250 lines), currently unwired
- `.opencode/context/formats/return-metadata-file.md` - Metadata schema with `partial_progress` and `handoff_path`
- `.opencode/context/patterns/postflight-control.md` - Loop guard (max 3 continuations)
- `.opencode/skills/skill-team-implement/SKILL.md` - Team mode (parallel, not sequential continuation)
- `.opencode/rules/error-handling.md` - Partial progress and resume patterns

### Key Code References

**Current prohibition on continuation** (skill-implementer.md line 503):
```markdown
> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.
```

**Current partial handling** (skill-implementer.md lines 370-390):
```bash
**If status is "partial"**:
Keep status as "implementing" but update resume point.
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson phase "$phases_completed" \
  '... resume_phase: ($phase + 1)' specs/state.json
```

**Agent timeout handling** (general-implementation-agent.md line 233):
```markdown
- **Timeout**: Mark current phase `[PARTIAL]` in plan, save progress, return partial with resume info
```

**Handoff metadata integration** (handoff-artifact.md lines 121-135):
```json
{
  "status": "partial",
  "partial_progress": {
    "stage": "context_exhaustion_handoff",
    "handoff_path": "specs/.../handoffs/phase-3-handoff-...md",
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

**Loop guard** (postflight-control.md lines 128-134):
```markdown
- Location: `specs/{NNN}_{SLUG}/.postflight-loop-guard`
- Incremented on each blocked stop
- After 3 continuations, cleanup and allow stop
```
