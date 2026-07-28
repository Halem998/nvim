# System Architecture Overview

**Created**: 2026-01-19
**Last Verified**: 2026-05-22
**Purpose**: Consolidated architecture reference for agents generating new components
**Audience**: /meta agent, system developers, architecture reviewers

---

## Three-Layer Architecture

The agent system implements a three-layer delegation pattern separating concerns into distinct execution layers.

```
                         USER INPUT
                              │
                              ▼
                    ┌─────────────────┐
     Layer 1:       │    Commands     │  User-facing entry points
     (Commands)     │  (/research,    │  Shared gate scripts
                    │   /plan, etc.)  │  Route to skills
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
     Layer 2:       │     Skills      │  Thin wrappers via skill-base.sh
     (Skills)       │ (skill-researcher,│  Validate, delegate, postflight
                    │  etc.)          │  Invoke agents via Agent tool
                    └────────┬────────┘
                              │
                              ▼
                    ┌─────────────────┐
     Layer 3:       │     Agents      │  Full execution components
     (Agents)       │ (general-research-│  Load context on-demand
                    │  agent, etc.)   │  Create artifacts
                    └────────┬────────┘
                              │
                              ▼
                        ARTIFACTS
               (reports, plans, summaries)
```

---

## Shared Command Infrastructure

The unified workflow refactor introduced shared scripts that eliminate duplicated gate logic across commands. Commands dropped from ~400-500 lines to ~200 lines each.

### Shared Gate Scripts

| Script | Purpose | Key Exports |
|--------|---------|-------------|
| `parse-command-args.sh` | Parse task numbers, flags (--team, --fast, --hard, --haiku/--sonnet/--opus, --clean, --force) | TASK_NUMBERS, TEAM_MODE, EFFORT_FLAG, MODEL_FLAG |
| `command-gate-in.sh` | CHECKPOINT 1: Session generation, task lookup, terminal status guard | SESSION_ID, TASK_TYPE, PROJECT_NAME, PADDED_NUM |
| `command-gate-out.sh` | CHECKPOINT 2: Artifact validation, defensive status correction | Reads .return-meta.json, runs validate-artifact.sh |
| `command-route-skill.sh` | Route task_type to skill name via extension manifests | SKILL_NAME |
| `update-task-status.sh` | Centralized preflight/postflight status transitions | Updates state.json + TODO.md atomically |

All scripts use **source semantics** — they must be sourced (not called as subprocesses) within a single Bash tool invocation so exported variables are visible to subsequent commands.

### Command Structure (Post-Refactor)

```
STAGE 0:  parse-command-args.sh        Parse task numbers + flags
CHECKPOINT 1: command-gate-in.sh       Session gen, task lookup, preflight
STAGE 2:  Skill tool invocation        Route via command-route-skill.sh
CHECKPOINT 2: command-gate-out.sh      Validate return, defensive correction
CHECKPOINT 3: git commit               Session-tracked commit
```

Commands contain only routing logic. All gate mechanics, session generation, status updates, and artifact validation are handled by the shared scripts.

---

## Shared Skill Base

All skills share lifecycle logic via `.opencode/scripts/skill-base.sh`, which provides 12+ functions:

| Function | Purpose |
|----------|---------|
| `skill_validate_input()` | Validate task number, extract state from state.json |
| `skill_preflight_update()` | Update status to "in progress" + run extension `preflight` hook |
| `skill_create_postflight_marker()` | Create marker file preventing premature termination |
| `skill_read_artifact_number()` | Read/calculate artifact sequence number (supports "prev" mode for plan/implement) |
| `skill_context_injection()` | Run extension `context_injection` hook before agent delegation |
| `skill_read_metadata()` | Parse agent's .return-meta.json after delegation |
| `skill_validate_artifact()` | Validate artifact exists and passes format checks + run extension `verification` hook |
| `skill_postflight_update()` | Update status to completed variant + run extension `postflight` hook |
| `skill_link_artifacts()` | Link artifacts in state.json and TODO.md |
| `skill_cleanup()` | Remove marker and metadata files |
| `skill_write_orchestrator_handoff()` | Write handoff JSON for /orchestrate state machine |

Extension skills are thin wrappers (~83-104 lines) that source skill-base.sh and delegate to their domain agent.

---

## Component Responsibilities Matrix

| Aspect | Command | Skill | Agent |
|--------|---------|-------|-------|
| **Location** | `.opencode/commands/` | `.opencode/skills/skill-*/SKILL.md` | `.opencode/agents/*.md` |
| **User-facing** | Yes | No | No |
| **Invocation** | `/command` syntax | Via Command routing | Via Agent tool from Skill |
| **Context loading** | None | Minimal | Full (lazy loading) |
| **Input validation** | Basic parsing | Delegation validation | Execution validation |
| **Execution** | Route only | Validate + delegate | Full workflow |
| **Artifact creation** | No | No | Yes |
| **Return format** | N/A | Pass-through | Standardized JSON |

---

## Layer Details

### Layer 1: Commands

**Purpose**: User-facing entry points that parse arguments and route to skills.

**Key characteristics**:
- Use `parse-command-args.sh` for argument parsing (task numbers, flags)
- Use `command-gate-in.sh` for session generation and task validation
- Route to skills via `command-route-skill.sh`
- Use `command-gate-out.sh` for postflight validation
- Minimal logic (~200 lines after refactor, down from ~400-500)

**Available commands**:
| Command | Purpose |
|---------|---------|
| `/task` | Create, manage, sync tasks |
| `/research` | Conduct task research |
| `/plan` | Create implementation plans |
| `/implement` | Execute implementation |
| `/revise` | Revise plans |
| `/review` | Code review |
| `/errors` | Analyze errors |
| `/todo` | Archive completed tasks |
| `/meta` | System builder |
| `/fix-it` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/refresh` | Clean orphaned processes and old files |
| `/tag` | Create semantic version tag (user-only) |
| `/spawn` | Spawn new tasks to unblock blocked task |
| `/merge` | Create pull/merge request |
| `/orchestrate` | Autonomous lifecycle (research -> plan -> implement) |

**Reference**: @.opencode/docs/guides/creating-commands.md

---

### Layer 2: Skills

**Purpose**: Thin wrappers that validate inputs, delegate to agents, and handle lifecycle operations.

**Key characteristics**:
- Source `skill-base.sh` for lifecycle functions
- Validate inputs before delegation
- Prepare delegation context (session_id, depth, path)
- Invoke agent via **Agent tool** (not Skill tool)
- Handle preflight/postflight status updates internally
- Perform git commit after agent completion
- Return brief text summary (agent writes JSON to metadata file)

**Thin Wrapper Pattern**:
```yaml
---
name: skill-{name}
description: {description}
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

**Note on delegation patterns**: Skills use one of two delegation approaches:
- **Core skills** (skill-researcher, skill-planner, skill-implementer, etc.): Use Agent tool with explicit `subagent_type` for structured delegation. These inject structured context (session_id, delegation_depth, memory_context) directly.
- **Extension skills** (skill-{ext}-research, skill-{ext}-implementation, etc.): May optionally use `context: fork` + `agent:` frontmatter for simpler delegation when structured context injection is not needed.

In all cases, delegation happens via the **Agent tool** (not the Skill tool). See @.opencode/context/patterns/fork-patterns.md for the full decision matrix.

**Key skills**:
| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-researcher | general-research-agent | General web/codebase research |
| skill-planner | planner-agent | Create implementation plans |
| skill-implementer | general-implementation-agent | General file implementation |
| skill-meta | meta-builder-agent | System building and task creation |
| skill-status-sync | (direct execution) | Atomic status updates |
| skill-orchestrate | (direct execution) | Autonomous lifecycle state machine |
| skill-git-workflow | (direct execution) | Create scoped git commits |
| skill-spawn | spawn-agent | Analyze blockers and spawn new tasks |

**Note**: Additional skills are available via extensions in `.opencode/extensions/`. Extension skills are thin wrappers (under ~110 lines) that source skill-base.sh and delegate to their domain agent.

**Reference**: @.opencode/context/patterns/thin-wrapper-skill.md

---

### Layer 3: Agents

**Purpose**: Full execution components that do the actual work.

**Key characteristics**:
- Load context on-demand via @-references
- Execute multi-step workflows
- Create artifacts in proper locations
- Write structured `.return-meta.json` metadata (read by skills in postflight)
- Handle errors with recovery information

**Return format** (written to `.return-meta.json`):
```json
{
  "status": "researched|planned|implemented|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [{...}],
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "agent_type": "{name}",
    "delegation_depth": N,
    "delegation_path": [...]
  },
  "errors": [...],
  "next_steps": "..."
}
```

**Critical**: Never use "completed" as status value — triggers Claude stop behavior.

**Reference**: @.opencode/context/formats/subagent-return.md

---

## Skill Architecture Patterns

Skills implement three distinct architecture patterns based on their execution needs.

### Pattern A: Delegating Skills with Internal Postflight

**Used by**: skill-researcher, skill-planner, skill-implementer, skill-meta (core skills; extensions add more)

**Characteristics**:
- Frontmatter: `allowed-tools: Agent, Bash, Edit, Read, Write`
- 11-stage execution flow with preflight/postflight inline
- Source skill-base.sh for all lifecycle functions
- Invoke subagent via Agent tool with explicit subagent_type
- Create postflight marker file to prevent premature termination
- Return brief text summary (agent writes JSON to metadata file)

**Execution Flow**:
```
Stage 1:  Input Validation           (skill_validate_input)
Stage 2:  Preflight Status Update    (skill_preflight_update)    [RESEARCHING]
Stage 3:  Create Postflight Marker   (skill_create_postflight_marker)
Stage 4:  Prepare Delegation Context
Stage 5:  Invoke Subagent            (Agent tool)
Stage 6:  Parse Subagent Return      (skill_read_metadata)
Stage 7:  Update Task Status         (skill_postflight_update)   [RESEARCHED]
Stage 8:  Link Artifacts             (skill_link_artifacts)
Stage 9:  Git Commit
Stage 10: Cleanup                    (skill_cleanup)
Stage 11: Return Brief Summary
```

---

### Pattern B: Direct Execution Skills

**Used by**: skill-status-sync, skill-refresh, skill-git-workflow (3 skills)

**Characteristics**:
- Frontmatter: `allowed-tools: Bash, Edit, Read` (no Agent tool)
- Execute work inline without spawning subagent
- No postflight marker needed (work is atomic)
- Return JSON or text directly

---

### Pattern C: Orchestrator/Routing Skills

**Used by**: skill-orchestrate (1 skill)

**Characteristics**:
- Frontmatter: `allowed-tools: Read, Glob, Grep, Agent`
- Autonomous state machine driving research -> plan -> implement without user confirmation
- Uses `dispatch-agent.sh` for fork-vs-subagent dispatch decisions
- Dispatches to other skills/agents based on task type

---

### Pattern Selection Decision Tree

```
Does the skill need to spawn a subagent?
├── NO → Pattern B (Direct Execution)
│   └── Use for: atomic operations, status updates, cleanup
│
└── YES → Does it need to route to multiple skills/agents?
    ├── YES → Pattern C (Orchestrator/Routing)
    │   └── Use for: /orchestrate autonomous lifecycle
    │
    └── NO → Pattern A (Delegating with Internal Postflight)
        └── Use for: research, planning, implementation workflows
```

**Default Choice**: Pattern A is the standard for new skills unless there's a specific reason to use B or C.

---

## /orchestrate and dispatch-agent.sh

The `/orchestrate` command provides autonomous lifecycle execution — driving a task through research, planning, and implementation without user confirmation between phases.

**State machine**: 10 states from INIT through RESEARCH, PLAN, IMPLEMENT to DONE/FAILED.

**dispatch-agent.sh**: Fork-vs-subagent dispatch function used by skill-orchestrate. It produces JSON dispatch instructions (does not invoke Agent tool directly). Functions:
- `dispatch_agent()` — primary dispatch with fork/subagent decision
- `invoke_named_agent()` — generates named subagent dispatch JSON
- `invoke_agent_fork()` — generates fork dispatch JSON (blocker research only)

**Reference**: @.opencode/docs/architecture/orchestrate-state-machine.md, @.opencode/docs/architecture/dispatch-agent-spec.md

---

## Computed CLAUDE.md

CLAUDE.md at `.opencode/CLAUDE.md` is a **computed artifact** generated by `merge.lua:generate_claudemd()`. It is assembled from:
- Core merge-source: `.opencode/extensions/core/merge-sources/claudemd.md`
- Loaded extension EXTENSION.md files (each extension contributes a section)

Do not edit `.opencode/CLAUDE.md` directly — it will be overwritten on the next generation. To modify core content, edit the merge-sources. To modify extension content, edit the extension's `EXTENSION.md`.

---

## Extension Lifecycle Hooks

Extensions can declare lifecycle hooks in their `manifest.json` under a top-level `"hooks"` object:

```json
{
  "hooks": {
    "preflight": "scripts/my-preflight.sh",
    "context_injection": "scripts/my-context.sh",
    "verification": "scripts/my-verify.sh",
    "postflight": "scripts/my-postflight.sh"
  }
}
```

**Distinction from `provides.hooks`**: The `provides.hooks` array lists scripts for file-copy deployment to `.opencode/hooks/`. The top-level `hooks` object lists scripts called during skill lifecycle stages.

Hook scripts receive 5 positional arguments: `task_number task_type task_dir session_id operation`.

All hooks are:
- Optional (missing key = skip silently)
- Non-blocking (non-zero exit = warning, not failure)
- Invoked by skill-base.sh at the corresponding lifecycle stage

---

## Context Budget System

Context files use a 4-tier progressive disclosure system to control agent context loading:

| Tier | When Loaded | Typical Size |
|------|-------------|-------------|
| 1 | Always (every agent invocation) | < 200 lines |
| 2 | Command/task-type match | < 400 lines |
| 3 | Agent-specific match | < 700 lines |
| 4 | On-demand (@-reference only) | Any size |

All 142 index entries in `.opencode/context/index.json` have assigned tiers. The `validate-context-budgets.sh` script enforces tier assignments and line count limits.

---

## Delegation Flow

### Standard Execution Flow

```
User: "/research 259"
         │
         ▼
┌───────────────────┐
│ 1. parse-command-  │  Extract task_number=259
│    args.sh         │  Parse flags (--team, etc.)
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 2. command-gate-   │  Generate session_id
│    in.sh           │  Lookup task_type=general
└─────────┬─────────┘  Validate status, export vars
          │
          ▼
┌───────────────────┐
│ 3. command-route-  │  task_type=general → skill-researcher
│    skill.sh        │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 4. Skill: skill-   │  skill_validate_input()
│    researcher       │  skill_preflight_update()
│                     │  Invoke general-research-agent
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 5. Agent creates   │  specs/259_{slug}/reports/01_{short-slug}.md
│    artifacts       │  Writes .return-meta.json
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 6. Skill postflight│  skill_read_metadata()
│                     │  skill_postflight_update()
│                     │  skill_link_artifacts()
│                     │  git commit + skill_cleanup()
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 7. command-gate-   │  Validate return, defensive correction
│    out.sh          │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ 8. Git commit      │  Session-tracked commit
└───────────────────┘
```

---

## Checkpoint-Based Execution

All workflow commands follow a three-checkpoint pattern:

```
┌──────────────────────────────────────────────────────────────┐
│  CHECKPOINT 1    ─→    STAGE 2    ─→    CHECKPOINT 2    ─→   │
│   GATE IN              DELEGATE          GATE OUT            │
│  (Preflight)         (Skill/Agent)     (Postflight)          │
│                                                   │          │
│                                                   ▼          │
│                                            CHECKPOINT 3      │
│                                              COMMIT          │
└──────────────────────────────────────────────────────────────┘
```

| Checkpoint | Script | Purpose |
|------------|--------|---------|
| GATE IN | `command-gate-in.sh` | Generate session_id, validate task exists, update status to "in_progress" variant |
| DELEGATE | Skill tool invocation | Route to skill, skill invokes agent, agent creates artifacts |
| GATE OUT | `command-gate-out.sh` | Validate return, link artifacts, update status to success variant |
| COMMIT | git commit | Session-tracked commit with `task {N}: {action}` format |

**Reference**: @.opencode/context/checkpoints/

---

## Session Tracking

Every delegation has a unique session ID for traceability:

**Format**: `sess_{unix_timestamp}_{6_char_random}`
**Example**: `sess_1736700000_abc123`

**Generation** (handled by `command-gate-in.sh`):
```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Usage**:
- Generated at GATE IN checkpoint
- Passed through delegation context to agent
- Returned in agent metadata
- Included in git commit message
- Logged in errors.json for traceability

---

## Task-Type-Based Routing

Tasks route to specialized skills/agents based on their `task_type` field. Routing is resolved by `command-route-skill.sh`, which checks extension manifests before falling back to defaults.

| Task Type | Research | Planning | Implementation |
|----------|----------|----------|----------------|
| `general` | skill-researcher → general-research-agent | skill-planner → planner-agent | skill-implementer → general-implementation-agent |
| `meta` | skill-researcher → general-research-agent | skill-planner → planner-agent | skill-implementer → general-implementation-agent |
| _{extension}_ | _Extension-provided skill → extension agent_ | skill-planner → planner-agent | _Extension-provided skill → extension agent_ |

**Note**: Extensions (e.g., nix, neovim, lean4, latex, typst) add task type routing entries. See `.opencode/extensions/*/manifest.json`.

---

## Command-Skill-Agent Mapping

Complete mapping of all commands to their skill and agent paths:

| Command | Routing Type | Skill(s) | Agent(s) | Pattern |
|---------|--------------|----------|----------|---------|
| `/research` | Task-type-based | Extension or skill-researcher | Extension or general-research-agent | A |
| `/plan` | Single | skill-planner | planner-agent | A |
| `/implement` | Task-type-based | Extension or skill-implementer | Extension or general-implementation-agent | A |
| `/revise` | Single | skill-planner (new version) | planner-agent | A |
| `/meta` | Single | skill-meta | meta-builder-agent | A |
| `/review` | Direct | (direct execution) | (inline execution) | B |
| `/errors` | Direct | (direct execution) | (inline execution) | B |
| `/todo` | Direct | skill-todo | (no agent) | B |
| `/task` | Direct | skill-meta | meta-builder-agent | A |
| `/orchestrate` | Autonomous | skill-orchestrate | (dispatches multiple) | C |
| `/refresh` | Direct | skill-refresh | (no agent) | B |
| `/spawn` | Single | skill-spawn | spawn-agent | A |
| `/tag` | Direct | (user-only) | (no agent) | B |
| `/merge` | Direct | (direct execution) | (inline execution) | B |

**Pattern Legend**:
- **A**: Delegating skill with internal postflight (spawns subagent)
- **B**: Direct execution skill (no subagent)
- **C**: Orchestrator/routing skill (central dispatch)

---

## Error Handling

Errors propagate upward through the layers with structured information:

```
Agent Error
    │
    ▼
Agent returns: {"status": "failed", "errors": [{...}]}
    │
    ▼
Skill validates return, passes through error
    │
    ▼
Orchestrator receives error, handles based on severity:
  ├─ Critical: Log to errors.json, return to user
  ├─ Recoverable: Suggest retry/resume
  └─ Partial: Save progress, enable resume
```

---

## Delegation Depth Limits

Prevent infinite delegation loops with depth tracking:

| Depth | Layer | Example |
|-------|-------|---------|
| 0 | Orchestrator | User -> Orchestrator |
| 1 | Command/Skill | Orchestrator -> Command -> Skill |
| 2 | Agent | Skill -> Agent |
| 3 | Sub-agent (rare) | Agent -> Utility Agent |

**Maximum depth**: 3 levels (hard limit)

---

## File Structure

```
.opencode/
├── commands/           # Layer 1: User commands (~200 lines each)
│   ├── research.md
│   ├── plan.md
│   └── ...
├── skills/             # Layer 2: Skills (thin wrappers via skill-base.sh)
│   ├── skill-researcher/
│   │   └── SKILL.md
│   └── ...
├── agents/             # Layer 3: Agents
│   ├── general-research-agent.md
│   └── ...
├── scripts/            # Shared infrastructure
│   ├── skill-base.sh           # 12+ lifecycle functions
│   ├── parse-command-args.sh   # Argument parsing
│   ├── command-gate-in.sh      # CHECKPOINT 1
│   ├── command-gate-out.sh     # CHECKPOINT 2
│   ├── command-route-skill.sh  # Task-type routing
│   ├── dispatch-agent.sh       # Fork-vs-subagent dispatch
│   ├── update-task-status.sh   # Status transitions
│   └── ...
├── rules/              # Automatic behavior rules
├── context/            # Domain knowledge (4-tier budget system)
│   ├── architecture/   # Architecture docs (for agents)
│   ├── patterns/       # Reusable patterns
│   ├── formats/        # Artifact formats
│   └── ...
├── extensions/         # Domain extensions
│   ├── core/           # Foundation extension
│   └── ...
└── docs/               # User documentation
    ├── guides/         # How-to guides
    ├── architecture/   # Architecture docs (for users)
    └── ...
```

---

## Related Documentation

### User-Facing Documentation
- @.opencode/docs/architecture/system-overview.md - Simplified architecture overview for users

### Architecture Specifications
- @.opencode/docs/architecture/architecture-spec.md - Unified workflow architecture design spec
- @.opencode/docs/architecture/dispatch-agent-spec.md - dispatch_agent() function specification
- @.opencode/docs/architecture/handoff-schema.md - Orchestrator handoff JSON schema
- @.opencode/docs/architecture/orchestrate-state-machine.md - /orchestrate state machine specification

### Detailed Patterns
- @.opencode/context/orchestration/orchestration-core.md - Delegation, routing, session tracking
- @.opencode/context/orchestration/orchestration-validation.md - Return validation patterns
- @.opencode/context/orchestration/architecture.md - Three-layer detailed explanation

### Templates
- @.opencode/context/patterns/thin-wrapper-skill.md - Skill delegation pattern
- @.opencode/context/templates/subagent-template.md - Agent template
- @.opencode/context/templates/command-template.md - Command template

### Return Formats
- @.opencode/context/formats/subagent-return.md - Agent return schema
- @.opencode/context/formats/return-metadata-file.md - File-based return pattern

### Anti-Patterns
- @.opencode/context/patterns/anti-stop-patterns.md - Patterns that cause workflow early stop
