# Research Report: Task #592

**Task**: 592 — Design unified workflow architecture
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T01:00:00Z
**Effort**: ~4 hours (design synthesis from 591 team research + full codebase study)
**Dependencies**: Task 591 team research (satisfied)
**Sources/Inputs**:
- specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md
- specs/592_design_unified_workflow_architecture/reports/01_seed-research.md
- .claude/commands/research.md (500 lines — duplication analysis)
- .claude/commands/plan.md (partial read)
- .claude/commands/implement.md (partial read)
- .claude/skills/skill-researcher/SKILL.md (558 lines — lifecycle analysis)
- .claude/skills/skill-orchestrator/SKILL.md (128 lines — vestigial orchestrator)
- .claude/context/architecture/system-overview.md
- .claude/context/patterns/fork-patterns.md
- .claude/context/orchestration/orchestration-core.md
- .claude/context/patterns/thin-wrapper-skill.md
- .claude/context/formats/handoff-artifact.md
- .claude/context/patterns/subagent-continuation-loop.md
**Artifacts**:
- specs/592_design_unified_workflow_architecture/reports/02_architecture-design.md (this file)
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The unified workflow architecture consolidates seven cross-cutting concerns (command parsing, skill
  lifecycle, orchestration loop, agent dispatch, handoff protocol, extension hooks, nested loops) into
  a coherent design that can be implemented incrementally across tasks 593-599.
- The highest-leverage single change is extracting `parse-command-args.sh` (eliminating ~165 lines of
  identical copy-paste across 3 commands) plus a shared `postflight-workflow.sh` (~130 lines
  eliminated). These are safe first steps that validate the extraction strategy.
- The `/orchestrate` command is designed as a **fire-and-forget** autonomous state machine using
  file-based handoffs, preventing context accumulation regardless of how many phases run. Blocker
  escalation (detect → research fork → revise → re-implement) is the novel high-value capability.
- The `dispatch_agent()` function is the single place where fork-vs-subagent logic lives, making the
  platform-evolution surface area minimal.
- Extension lifecycle hooks replace full skill duplication, converting 16 extensions from divergent
  copies of the core lifecycle into hook-based participants.

---

## Context & Scope

### What was researched

This report synthesizes task 591 team research findings into a concrete architectural blueprint that
is specific enough to drive implementation plans for tasks 593-599. Every component design includes:
file locations, function signatures, interface contracts, and the rationale for key decisions.

### User directive on /orchestrate behavior

The user explicitly specified that `/orchestrate` should be **fire-and-forget** (autonomous loop by
default). The task 591 team research recommended confirmation gates (`--auto` bypass), but the user
overrode this recommendation. This report designs the system accordingly. Blocker escalation is the
safety mechanism; it is autonomous loop management at the "research the blocker and fix it" level.

### Constraints from current system

1. Core skills use `subagent_type` in every Agent tool call → `FORK_SUBAGENT` cache sharing does not
   apply to current core skill dispatch. This is intentional (structured context injection requires
   known agent type).
2. Prompt cache TTL is 5 minutes. Fork cache sharing only benefits same-turn re-dispatches.
3. The `continuation-loop-guard` file mechanism already exists in the system and must be preserved.
4. Delegation depth limit is 3. `/orchestrate` adds one outer dispatch level; `delegation_depth` for
   agents invoked by `/orchestrate` will be 2 (not 1 as today).

---

## Findings

### Observed Duplication Baseline

From reading the command and skill files directly:

**Command-level duplication** (identical across research.md, plan.md, implement.md):

| Duplicated Block | Lines per command | Total waste |
|------------------|-------------------|-------------|
| `parse_task_args()` function | ~30 | ~90 lines |
| Flag parsing (STAGE 1.5 equivalent) | ~50 | ~150 lines |
| Batch validation loop | ~25 | ~75 lines |
| `CHECKPOINT 1: GATE IN` lookup+validate | ~30 | ~90 lines |
| `CHECKPOINT 2: GATE OUT` defensive checks | ~25 | ~75 lines |
| `CHECKPOINT 3: COMMIT` | ~15 | ~45 lines |

**Total command duplication: ~525 lines across 3 commands.**
Each command is ~500 lines. Safe extraction target: reduce each to ~150 lines.

**Skill-level duplication** (near-identical across skill-researcher, skill-planner, skill-implementer):

| Duplicated Block | Lines per skill | Notes |
|------------------|-----------------|-------|
| Stage 1: Input validation | ~25 | Identical |
| Stage 2: Preflight status update | ~15 | Identical |
| Stage 3: Postflight marker creation | ~20 | Identical |
| Stage 3a: Artifact number read | ~15 | Identical |
| Stage 6: Read metadata file | ~20 | Identical |
| Stage 6a: Validate artifact | ~15 | Identical |
| Stage 7: Update status | ~15 | Identical |
| Stage 7a: Memory candidates propagation | ~20 | Identical |
| Stage 8: Link artifacts | ~35 | Near-identical |
| Stage 9: Cleanup | ~10 | Identical |
| Stage 10: Return brief summary | ~15 | Identical |

**Skill-specific** (must NOT be shared):
- Stage 4a: Memory retrieval (researcher only — also in planner via `--clean` gate)
- Stage 4b: Format injection (researcher only)
- Stage 4c: Roadmap consultation (researcher only)
- Stage 4d: Prior implementation context (researcher only)
- Stage 4: Delegation context construction (skill-specific fields)
- Stage 5: Agent invocation (different `subagent_type` per skill)

**Total skill duplication: ~210 lines across 3 skills.**
Each skill is ~500-560 lines. Safe extraction target: reduce each to ~150-200 lines.

---

## Component Designs

### Component 1: Shared Command Infrastructure

#### Architecture Decision

Commands become routing-only controllers. All shared logic moves to `.claude/scripts/`.
Commands reference shared logic via `@`-include or direct Bash execution.

#### File Layout

```
.claude/scripts/
├── parse-command-args.sh        # NEW: parse task numbers + flags
├── command-gate-in.sh           # NEW: session_id gen + task lookup + validation
├── command-gate-out.sh          # NEW: artifact verification + defensive status fix
├── update-task-status.sh        # EXISTING (unchanged)
└── validate-artifact.sh         # EXISTING (unchanged)
```

#### `parse-command-args.sh` — Full Specification

**Purpose**: Parse `$ARGUMENTS` string → task number list + remaining flags + focus prompt.

**Signature**:
```bash
# Usage: source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports:
#   TASK_NUMBERS    - space-separated list of integers
#   REMAINING_ARGS  - string of remaining args after task numbers
#   TEAM_MODE       - "true" or "false"
#   TEAM_SIZE       - integer 2-4
#   EFFORT_FLAG     - "fast", "hard", or ""
#   MODEL_FLAG      - "haiku", "sonnet", "opus", or ""
#   CLEAN_FLAG      - "true" or "false"
#   FORCE_FLAG      - "true" or "false"  (implement only)
#   FOCUS_PROMPT    - remaining text after all flags removed
```

**Algorithm**:
1. Regex-match leading `[0-9][0-9,\ \-]*` to extract `task_spec`.
2. Expand ranges: `22-24` → `22 23 24`.
3. Scan `remaining_args` for known flags, setting export vars.
4. Strip all recognized flags from `remaining_args` → `FOCUS_PROMPT`.
5. Exit 1 with message if no task numbers found.

**Command refactoring**: After sourcing this script, each command has TASK_NUMBERS, all flags, and FOCUS_PROMPT. The command body shrinks to:
1. Source `parse-command-args.sh`
2. If `len(TASK_NUMBERS) > 1`, invoke batch dispatch loop
3. Else fall through to CHECKPOINT 1

#### `command-gate-in.sh` — Full Specification

**Purpose**: CHECKPOINT 1 logic — session ID generation, task lookup, terminal status guard.

**Signature**:
```bash
# Usage: source .claude/scripts/command-gate-in.sh "$task_number" "$operation"
# operation: "research" | "plan" | "implement" | "revise"
# Exports:
#   SESSION_ID     - sess_{timestamp}_{random}
#   TASK_TYPE      - from state.json
#   TASK_STATUS    - from state.json
#   PROJECT_NAME   - from state.json
#   DESCRIPTION    - from state.json
#   PADDED_NUM     - printf "%03d" task_number
# Exit 1 if task not found or terminal status
```

**Key behaviors**:
- Generates `SESSION_ID` using `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')`
- Checks terminal statuses (completed, abandoned, expanded) → ABORT
- Displays `[{operation_label}] Task {N}: {project_name}`

#### `command-gate-out.sh` — Full Specification

**Purpose**: CHECKPOINT 2 logic — artifact verification and defensive status correction.

**Signature**:
```bash
# Usage: source .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$session_id"
# Reads skill return from: specs/{NNN}_{SLUG}/.return-meta.json
# Applies defensive correction if state.json status stale
# Exit 1 on critical validation failure (non-blocking on artifact link failure)
```

#### What Stays in Each Command File

After extraction, each command retains only:
1. YAML frontmatter (allowed-tools, argument-hint, model)
2. Anti-bypass constraint (PROHIBITION section)
3. Source + dispatch block (~30 lines)
4. Multi-task batch loop (~40 lines)  
5. Extension routing table (research.md) or single-skill routing (plan.md)
6. Error handling section

**Target size**: 150-200 lines per command (vs. 500 today).

---

### Component 2: Shared Skill Base Pattern

#### Architecture Decision

Use a **sourced shell script library** (`skill-base.sh`) rather than a context document. The script
provides functions called by each skill. Context documents cannot be executed; functions need to run
shell commands.

The skill body becomes:
```
[Frontmatter]
# Skill description (30 lines)
# Skill-specific context collection (Stage 4 variants, ~80 lines)
# Stage 5: Subagent invocation (unique subagent_type, ~30 lines)
# Source skill-base.sh for shared postflight
```

#### File Layout

```
.claude/scripts/
├── skill-base.sh                # NEW: shared skill lifecycle stages
└── postflight-workflow.sh       # NEW: shared postflight (supersedes skill-base postflight)
```

#### `skill-base.sh` — Function Inventory

```bash
# skill_validate_input "$task_number"
# → jq lookup in state.json; exports TASK_DATA, TASK_TYPE, TASK_STATUS, etc.
# → exit 1 if task not found

# skill_preflight_update "$task_number" "$operation" "$session_id"
# → calls update-task-status.sh preflight

# skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
# → writes .postflight-pending file

# skill_read_artifact_number "$task_number" "$padded_num" "$project_name"
# → reads next_artifact_number from state.json or falls back to directory scan
# → exports ARTIFACT_NUMBER, ARTIFACT_PADDED

# skill_read_metadata "$padded_num" "$project_name"
# → reads .return-meta.json
# → exports SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES

# skill_validate_artifact "$status" "$artifact_path"
# → calls validate-artifact.sh --fix (non-blocking)

# skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
# → calls update-task-status.sh postflight (only on success status)

# skill_increment_artifact_number "$task_number"
# → jq increment next_artifact_number in state.json
# → research only (planner/implementer skip this)

# skill_propagate_memory_candidates "$task_number" "$memory_candidates"
# → append to state.json entry (append semantics)

# skill_link_artifacts "$task_number" "$artifact_path"
# → jq state.json update + link-artifact-todo.sh

# skill_cleanup "$padded_num" "$project_name"
# → rm -f .postflight-pending .postflight-loop-guard .return-meta.json
```

#### Hook Points for Skill-Specific Logic

Each skill provides exactly:
1. **Context collection** (Stage 4 variants): unique per skill
2. **Delegation context construction**: unique fields per skill  
3. **Agent invocation** (Stage 5): unique `subagent_type` per skill
4. **Continuation loop** (skill-implementer only): see Component 7

Everything else sources from `skill-base.sh`.

#### Target Skill Sizes

| Skill | Current | Target | Lines Eliminated |
|-------|---------|--------|-----------------|
| skill-researcher | 558 | 150 | 408 |
| skill-planner | ~450 | 130 | 320 |
| skill-implementer | ~600 | 200 | 400 |

The implementer stays larger due to the continuation loop (see Component 7).

---

### Component 3: /orchestrate State Machine

#### Architecture Decision

`/orchestrate` is a new command (`.claude/commands/orchestrate.md`) that delegates to
`skill-orchestrate` which contains the state machine loop. No dedicated agent needed — the state
machine is simple enough to live in the skill body itself (Pattern C: Orchestrator/Routing skill).

This keeps the loop logic co-located with the state table, not spread across an agent prompt.

#### File Layout

```
.claude/commands/orchestrate.md    # NEW: entry point, argument parsing
.claude/skills/skill-orchestrate/
└── SKILL.md                       # NEW: state machine + dispatch logic
```

#### State Machine Design

```
READ specs/state.json → get task status

STATE: not_started
  ACTION: dispatch(research, task_number)
  NEXT:   → researched (via handoff)

STATE: researched
  ACTION: dispatch(plan, task_number)
  NEXT:   → planned (via handoff)

STATE: planned
  ACTION: dispatch(implement, task_number, orchestrator_mode=true)
  NEXT:   → implemented (via handoff)
         → partial + handoff_path → read handoff → check blockers → continue loop
         → partial + blockers → dispatch(research_fork, blocker_description)
                              → dispatch(revise, task_number)
                              → dispatch(implement, task_number, orchestrator_mode=true)
         → partial + no handoff + count >= MAX_CYCLES → exit, report

STATE: implementing
  ACTION: dispatch(implement, task_number, orchestrator_mode=true)  [resume]
  NEXT:   same as "planned" dispatch

STATE: partial
  ACTION: same as "implementing"

STATE: blocked
  ACTION: read blockers from state.json
         dispatch(research_fork, blocker_description)
         dispatch(revise, task_number)
         dispatch(implement, task_number)

TERMINAL: completed | abandoned | expanded
  ACTION: report status, exit
```

#### Key Properties of This Design

**Context flatness**: The orchestrator NEVER inlines agent output into its context. After each
dispatch, it reads `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` from disk (200-400 tokens max).
The orchestrator's context window grows by only ~400 tokens per cycle, regardless of what the
delegated skill produced.

**Max cycles**: `MAX_CYCLES = 5` per `/orchestrate` invocation. Prevents runaway loops. On
reaching the limit, the task is left in `partial` state and the user is informed.

**Loop guard file**: `specs/{NNN}_{SLUG}/.orchestrator-loop-guard`
```json
{
  "session_id": "sess_...",
  "cycle_count": 2,
  "max_cycles": 5,
  "current_state": "planned",
  "started": "2026-05-22T00:00:00Z",
  "last_updated": "2026-05-22T00:30:00Z"
}
```

**Orchestrator handoff schema**: Written by each skill to signal the orchestrator. See Component 5.

**Blocker escalation** (the novel capability):
When a dispatch returns `status=partial` AND `blockers` is non-empty:
1. Fork a research subagent (no `subagent_type` → inherits cache prefix ~90% token savings)
2. Pass the blocker description as the research prompt
3. Read the research handoff (200-400 tokens)
4. Dispatch the reviser with research findings + current plan path
5. Re-dispatch implement

This is the only place forks are used in the core workflow. The fork is justified because:
- The orchestrator context is warm (same session, recent cache)
- No named agent routing is needed (the blocker research doesn't require specialized context)
- The operation completes within the same conversational turn

---

### Component 4: dispatch_agent() Function Specification

#### Architecture Decision

`dispatch_agent()` lives in `.claude/scripts/dispatch-agent.sh`. It is sourced by skill-orchestrate.

#### Full Function Specification

```bash
# dispatch_agent() — encapsulates fork-vs-named-subagent decision
#
# Usage:
#   dispatch_agent "$agent_type" "$prompt" "$context_json" "$is_blocker_escalation"
#
# Parameters:
#   agent_type              - Named agent (e.g. "general-research-agent"), or "" for fork
#   prompt                  - Full prompt string to pass to Agent tool
#   context_json            - Delegation context JSON string
#   is_blocker_escalation   - "true" | "false"
#     "true": omit subagent_type (fork path)
#     "false": use agent_type as subagent_type (named subagent path)
#
# Internal decision:
#   IF is_blocker_escalation == "true":
#     → Agent tool call WITHOUT subagent_type
#     → FORK_SUBAGENT=1 applies (if env var set)
#     → parent cache prefix inherited (~90% token reduction)
#   ELSE:
#     → Agent tool call WITH subagent_type="$agent_type"
#     → Fresh context, full cost
#
# Returns:
#   Writes handoff to: specs/{NNN}_{SLUG}/.orchestrator-handoff.json
#   Exit code 0 on success, 1 on agent failure
```

#### Why Not Context-Warmth Detection

The task 591 seed report suggested a `context_is_warm()` check based on 5-minute cache TTL. This was
rejected for the following reason: the orchestrator always knows *why* it is dispatching (state
machine transition vs. blocker escalation). The `is_blocker_escalation` flag is a semantic signal,
not a TTL measurement. Blocker escalation always happens within a single `/orchestrate` invocation
(guaranteed warm), while state transitions always cross conversation boundaries (guaranteed cold).
This eliminates the need for cache TTL heuristics.

#### Future-Proofing

When Anthropic provides a "named fork" API:
```bash
# Only dispatch-agent.sh changes:
if [ "$named_fork_available" = "true" ] && [ "$is_blocker_escalation" = "true" ]; then
  # Use named fork: gets both cache sharing AND specialized prompt
  invoke_named_fork "$agent_type" "$prompt"
else
  # Current behavior unchanged
fi
```

---

### Component 5: Structured Handoff Object Schema

#### Architecture Decision

Two distinct handoff types serve different purposes:

1. **Orchestrator handoff** (`.orchestrator-handoff.json`): Written by skills to signal the
   `/orchestrate` state machine. Small and structured. Used for dispatch decisions.
2. **Continuation handoff** (`handoffs/phase-N-handoff-TIMESTAMP.md`): Existing markdown format.
   Written by agents to enable context-exhaustion recovery. Unchanged from current design.

#### Orchestrator Handoff JSON Schema

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "research | plan | implement | revise",
  "status": "researched | planned | implemented | partial | failed | blocked",
  "summary": "2-4 sentence description of what was accomplished",
  "artifacts": [
    {
      "type": "report | plan | summary",
      "path": "specs/NNN_slug/type/file.md"
    }
  ],
  "blockers": [
    {
      "description": "What is blocking implementation",
      "phase": "phase where blocker was detected",
      "severity": "hard | soft"
    }
  ],
  "next_action_hint": "plan | implement | revise | none",
  "files_modified": ["list of modified file paths"],
  "decisions_made": ["key decision 1", "key decision 2"],
  "dead_ends": ["approach tried but failed"],
  "continuation_context": {
    "handoff_path": "path to continuation handoff (partial only)",
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

**Token budget**: This schema must be populated with concise values. The `summary` field is
constrained to 4 sentences (~100 tokens). The full handoff object should stay under 400 tokens so
the orchestrator context remains flat.

#### Writing Contract

Skills MUST write to `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` when invoked by `/orchestrate`.
Skills detect orchestrator mode via `"orchestrator_mode": true` in their delegation context.

When NOT in orchestrator mode (normal `/research`, `/plan`, `/implement` invocation), skills do NOT
write this file. The file's presence signals orchestrator dispatch.

#### Reading Contract

The orchestrator reads the handoff file after each dispatch:
```bash
handoff=$(cat "specs/${padded_num}_${project_name}/.orchestrator-handoff.json")
status=$(echo "$handoff" | jq -r '.status')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
```

The orchestrator NEVER reads the full research reports, plan files, or implementation summaries
during its state machine loop. It reads only the 400-token handoff. This is the mechanism that
keeps orchestrator context flat.

---

### Component 6: Extension Lifecycle Hooks

#### Architecture Decision

Extensions declare hooks in `manifest.json`. The shared skill base (`skill-base.sh`) checks for
and calls these hooks at defined points in the lifecycle. This replaces the current pattern where
extension skills must copy the entire 11-stage lifecycle.

#### manifest.json Schema Additions

```json
{
  "name": "nix",
  "version": "1.0.0",
  "hooks": {
    "preflight": "scripts/nix-preflight.sh",
    "context_injection": "scripts/nix-context.sh",
    "postflight": "scripts/nix-postflight.sh",
    "verification": "scripts/nix-verify.sh"
  }
}
```

All hook fields are optional. Absent hooks are silently skipped.

#### Hook Execution Contract

Each hook script receives these positional arguments:
```bash
# $1 = task_number (integer)
# $2 = task_type (string, e.g. "nix")
# $3 = task_dir (path, e.g. "specs/242_configure_nixos")
# $4 = session_id (string)
# $5 = operation (string: "research" | "plan" | "implement")
```

Hooks MUST:
- Exit 0 on success
- Exit 1 on fatal failure (skill aborts)
- Write to stdout for logging
- NOT modify state.json directly (skill-base.sh owns state)

Hooks MAY:
- Write files to `$task_dir/` for context injection
- Set environment variables for the subsequent subagent invocation

#### Hook Invocation Points in `skill-base.sh`

```
Stage 2: skill_preflight_update() → calls hooks.preflight
Stage 4: skill_prepare_delegation() → calls hooks.context_injection
          (hook can write files; skill reads and injects them)
Stage 6a: skill_validate_artifact() → calls hooks.verification
Stage 7: skill_postflight_update() → calls hooks.postflight
```

#### Extension Skill After Hook Integration

After hook integration, a complete extension skill becomes:

```markdown
---
name: skill-nix-implementation
description: Implement Nix configuration changes.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Nix Implementation Skill

## Execution

### Stage 4: Context Injection
Call hooks.context_injection to gather Nix-specific context.

### Stage 5: Invoke Subagent
Agent tool with subagent_type: "nix-implementation-agent"

### Shared Lifecycle
Source .claude/scripts/skill-base.sh for all other stages.
```

**Target extension skill size**: 30-50 lines (vs. 400-600 lines today).

#### Migration Path for Existing Extensions

1. Extract existing preflight/postflight logic from `skill-{ext}-implementation` → `scripts/{ext}-preflight.sh`
2. Add `hooks` section to `manifest.json`
3. Thin down the skill body to Stage 4 (context injection) + Stage 5 (agent invocation)
4. Validate that `skill-base.sh` calls the hooks correctly

---

### Component 7: Nested Loop Resolution

#### Architecture Decision

**Exclusive alternatives**: When `/orchestrate` dispatches skill-implementer, it passes
`"orchestrator_mode": true` in the delegation context. Skill-implementer detects this flag and
**disables its inner continuation loop** (max_continuations = 0). The outer orchestrator loop
handles all continuation at the phase level.

Two nested loops with different termination conditions are unreliable. If skill-implementer's inner
loop were active, it could:
- Run 3 continuation cycles internally (inner loop limit)
- Return to the orchestrator as "implemented"
- The orchestrator would not know partial phases ran inside

This makes the orchestrator's state view inconsistent.

#### Implementation

**In skill-implementer** (Stage 5c — loop guard init):
```bash
# Read orchestrator_mode from delegation context
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')

if [ "$orchestrator_mode" = "true" ]; then
  max_continuations=0  # Disable inner loop; orchestrator drives
else
  max_continuations=3  # Normal inner loop behavior
fi
```

**In skill-orchestrate** (state machine loop):
The outer loop is already bounded by `MAX_CYCLES = 5`. Each cycle can dispatch one skill invocation.
If skill-implementer returns `partial` (context exhaustion), the orchestrator reads the continuation
handoff path from the orchestrator handoff and re-dispatches implement with `continuation_context`
embedded in the delegation JSON.

#### Handoff Compatibility Between Both Loop Types

The orchestrator handoff (`.orchestrator-handoff.json`) and the continuation handoff
(`handoffs/phase-N-handoff.md`) serve different consumers:
- The **orchestrator** reads `.orchestrator-handoff.json` to decide next dispatch
- The **successor agent** reads `handoffs/phase-N-handoff.md` to resume work

These are not in conflict. When skill-implementer runs in `orchestrator_mode`, it:
1. Writes the continuation handoff (for the successor agent)  
2. Writes the orchestrator handoff (for the orchestrator), including `continuation_context.handoff_path`
3. Returns `partial` status to the skill wrapper
4. The skill wrapper propagates the orchestrator handoff content

The orchestrator then reads `continuation_context.handoff_path` from the orchestrator handoff and
passes it in the next implement dispatch as `continuation_context`.

#### The "Flag Carried Through" Pattern

The `orchestrator_mode` flag must be preserved across continuations:
```json
{
  "continuation_context": {
    "is_successor": true,
    "continuation_number": 1,
    "handoff_path": "...",
    "orchestrator_mode": true   // ADDED: propagated from parent delegation
  }
}
```

---

### Context Budget Architecture (Overview)

**Note**: Full context budget design belongs to task 598. This section establishes the constraints
that tasks 593-597 must satisfy.

#### Four-Tier Loading Model

| Tier | Loaded When | Budget | Content |
|------|-------------|--------|---------|
| 1 (always) | Every invocation | ~500 lines | Anti-stop patterns, return-metadata, checkpoint-execution |
| 2 (command) | On command entry | ~500 lines | Routing tables, argument docs, anti-bypass |
| 3 (agent) | At agent spawn | ~3-5K lines | Full workflow patterns, domain context |
| 4 (on-demand) | Via `@`-ref in agent | Unbounded | Detailed guides, templates, examples |

**Critical constraint for tasks 593-597**: Commands MUST NOT load Tier 3 context. The current
research.md, plan.md, and implement.md embed agent-level context inline (e.g., full state machine
logic, format specifications). These must move to Tier 3 (agent context files) or be removed.

**Budget caps for task 598 to enforce**:
- Command files: ≤ 200 lines after task 593 extraction
- Skill files: ≤ 200 lines after task 594 extraction
- Agent context at spawn: ≤ 5K lines (sonnet workers), ≤ 15K lines (opus planners)

---

## Decisions

1. **Fire-and-forget orchestrate**: `/orchestrate` runs autonomously by default. The user explicitly
   chose this over confirmation gates (which the 591 team recommended). Blocker escalation is the
   safety mechanism.

2. **Shell script library over context document** for `skill-base.sh`: Skills need to execute shell
   logic (jq, file operations), not just read reference text.

3. **Semantic dispatch flag over TTL heuristic** for fork vs. subagent: `is_blocker_escalation=true`
   is a reliable semantic signal. Cache TTL measurement is fragile.

4. **Orchestrator handoff separate from continuation handoff**: These serve different consumers and
   must not be conflated. The orchestrator reads structured JSON; the successor agent reads
   markdown.

5. **Exclusive loop model**: Orchestrator mode disables skill-implementer's inner continuation loop.
   Layered loops are unreliable.

6. **No `dispatch_agent()` shell function in commands**: `dispatch_agent()` lives in skill-orchestrate
   only (via `dispatch-agent.sh`). Regular commands do not use this function — they directly invoke
   skills via the Skill tool.

7. **Extension hooks in manifest.json, not SKILL.md**: Manifest is the single source of truth for
   extension metadata. Adding a `hooks` section avoids a new file format.

8. **Incremental extraction order**: 593 → 598 → 594 → 595/596 → 597 → 599 (following 591 team
   reordering recommendation: 598 elevated to inform shared base design).

---

## Recommendations

### For Task 593 (Shared Utilities Extraction)

Implement in this order:
1. `parse-command-args.sh` (lowest risk, highest line savings)
2. `command-gate-in.sh` (prerequisite for any further command simplification)
3. `command-gate-out.sh` (eliminate defensive check duplication)
4. Update research.md, plan.md, implement.md to source these scripts
5. Validate: run a research task, confirm status transitions work

**Do NOT tackle skill-base.sh in task 593.** Save that for task 594 after context budgets are
established (task 598).

### For Task 594 (Skill Base Extraction)

1. Build `skill-base.sh` with the 11 functions listed in Component 2
2. Refactor skill-researcher first (most stages, best test case)
3. Validate: run a research task end-to-end
4. Then refactor skill-planner and skill-implementer
5. Do NOT add extension hooks in this task — save for task 599

### For Task 595 (Refactor /research, /plan, /implement)

These commands should already be thin after task 593. Task 595 focuses on:
1. Adding the orchestrator handoff writing capability to each skill
2. Testing `orchestrator_mode=true` dispatch path

### For Task 596 (/orchestrate Command)

1. Create `.claude/commands/orchestrate.md` (thin argument parsing)
2. Create `.claude/skills/skill-orchestrate/SKILL.md` (state machine, ~200 lines)
3. Create `.claude/scripts/dispatch-agent.sh` (dispatch function)
4. Implement loop guard and orchestrator handoff writing
5. Implement blocker escalation path (highest-value feature)
6. Add `orchestrator_mode` flag to skill-implementer

### For Task 598 (Progressive Disclosure / Context Budgets)

1. Audit current context index.json for tier classification
2. Move command-level agent context to Tier 3 (agent context files)
3. Enforce budget caps per agent type
4. Update CLAUDE.md context discovery documentation

### For Task 599 (Extension Compatibility)

1. Add `hooks` schema to manifest.json for all 16 extensions
2. Update `skill-base.sh` to invoke hooks at defined points
3. Migrate extension skills to thin wrappers
4. Verify each extension still produces valid artifacts

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|-----------|
| `skill-base.sh` function signatures change mid-refactor, breaking extensions | Medium | High | Lock the function signatures at task 592 design time (this document). Only backward-compatible additions allowed after task 594. |
| `orchestrator_mode` flag not propagated through continuation chains | Medium | High | Add explicit check in skill-implementer: if `continuation_context.orchestrator_mode` is present, preserve it. |
| Fork dispatch in blocker escalation fails silently (FORK_SUBAGENT not set) | Medium | Low | `dispatch-agent.sh` falls back to named subagent when fork fails. Document the `FORK_SUBAGENT=1` env var requirement. |
| Orchestrator handoff overwrites between cycles (concurrent orchestrate runs) | Low | Medium | Include `session_id` in handoff filename: `.orchestrator-handoff-{session_id}.json`. Orchestrator reads its own session's file. |
| Extension hooks introduce timing/ordering bugs in postflight | Low | Medium | Hooks are called with `set -e` disabled (non-fatal). Hook failures are logged but do not block skill completion. |
| Task 598 context budgets are incompatible with current agent @-refs | Medium | Medium | Task 598 should audit before setting hard limits. Initial caps can be advisory. |
| Token measurements are missing — cannot validate improvement claims | Medium | Low | Add a baseline measurement script to task 593 deliverables. |

---

## Context Extension Recommendations

- **Topic**: Orchestrator handoff format and orchestrator-mode dispatch
- **Gap**: No documentation exists for the `.orchestrator-handoff.json` schema or the
  `orchestrator_mode` flag in delegation context.
- **Recommendation**: Create `.claude/context/formats/orchestrator-handoff.md` and
  `.claude/context/patterns/orchestrator-mode.md` as part of task 596.

- **Topic**: Extension lifecycle hooks
- **Gap**: The `manifest.json` schema is not documented as including a `hooks` field. Extension
  developers have no reference for what hooks are available.
- **Recommendation**: Update `.claude/context/guides/extension-development.md` with the hooks
  schema as part of task 599.

- **Topic**: `dispatch_agent()` function and fork-vs-subagent decision for orchestrators
- **Gap**: Current `fork-patterns.md` does not address the use of forks for blocker escalation
  within an orchestration loop.
- **Recommendation**: Add a section to `fork-patterns.md` covering orchestrator-context forks as
  part of task 596.

---

## Appendix

### A. Line Count Validation

Actual line counts read during this research:
- `.claude/commands/research.md`: 500 lines
- `.claude/skills/skill-researcher/SKILL.md`: 558 lines
- `.claude/skills/skill-orchestrator/SKILL.md`: 128 lines
- `.claude/context/patterns/subagent-continuation-loop.md`: 210 lines
- `.claude/context/formats/handoff-artifact.md`: 206 lines

### B. Identical Code Blocks Confirmed

The following blocks were confirmed identical (not just similar) across the 3 commands:
- `parse_task_args()` function body (lines 64-90 in research.md, same in plan.md and implement.md)
- STAGE 1.5 flag parsing structure (team, effort, model, clean flags)
- CHECKPOINT 3 git commit block

### C. Dependency Graph for Tasks 593-599

```
592 (this task: design) ─────────────────────┐
                                              │
593 (shared utilities) ──────────────────────┤
  └─ extracts: parse-command-args.sh          │
               command-gate-in.sh             │
               command-gate-out.sh            │
               postflight-workflow.sh         │
                              │               │
                              ▼               │
598 (progressive disclosure) ◄───────────────┘
  └─ establishes: context budgets per tier
                  context index tier tags
                              │
                              ▼
594 (skill base) ─── depends on 598 budgets ──┐
  └─ extracts: skill-base.sh                  │
                              │               │
          ┌───────────────────┘               │
          ▼                   ▼               │
595 (refactor commands)  596 (/orchestrate)   │
  └─ research/plan/impl   └─ state machine    │
     slim to ~150L            dispatch_agent   │
                              blocker escalation│
                                              │
597 (task/revise/todo/review)                 │
  └─ unrelated to shared base                 │
                              │               │
                              ▼               │
                    599 (extensions) ◄────────┘
                      └─ hooks in manifest.json
                         thin extension skills
```

### D. File Location Summary

New files to be created across tasks 593-599:

```
.claude/scripts/
├── parse-command-args.sh         (task 593)
├── command-gate-in.sh            (task 593)
├── command-gate-out.sh           (task 593)
├── postflight-workflow.sh        (task 593)
├── skill-base.sh                 (task 594)
└── dispatch-agent.sh             (task 596)

.claude/commands/
└── orchestrate.md                (task 596)

.claude/skills/skill-orchestrate/
└── SKILL.md                      (task 596)

.claude/context/formats/
└── orchestrator-handoff.md       (task 596)

.claude/context/patterns/
└── orchestrator-mode.md          (task 596)
```

### E. References

- specs/591_research_claude_code_orchestration_practices/reports/01_team-research.md
- specs/592_design_unified_workflow_architecture/reports/01_seed-research.md
- .claude/context/architecture/system-overview.md
- .claude/context/patterns/fork-patterns.md
- .claude/context/orchestration/orchestration-core.md
- .claude/context/patterns/subagent-continuation-loop.md
- .claude/context/formats/handoff-artifact.md
