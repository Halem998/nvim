# Research Report: Task #603

**Task**: 603 - fix_meta_pre_confirmation_pattern
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:10:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/.claude/commands/meta.md` - Command definition and modes
- `/home/benjamin/.config/.claude/skills/skill-meta/SKILL.md` - Skill delegation wrapper
- `/home/benjamin/.config/.claude/agents/meta-builder-agent.md` - Agent interview flow (all 7 stages)
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md` - Multi-task confirmation requirements
- `/home/benjamin/.config/.claude/context/core/patterns/postflight-control.md` - Postflight architecture
- `/home/benjamin/.config/.claude/docs/examples/learn-flow-example.md` - learn-flow foreground AskUserQuestion pattern
- `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` - Reference foreground skill pattern
**Artifacts**:
- `specs/603_fix_meta_pre_confirmation_pattern/reports/01_meta-pre-confirmation.md`
**Standards**: report-format.md, multi-task-creation-standard.md

---

## Executive Summary

- AskUserQuestion called from a background agent (spawned via Task tool) does NOT reliably surface to the user; the confirmation prompt silently disappears and the user never sees it.
- Currently all confirmation happens inside `meta-builder-agent`, which is spawned as a background subagent via Task tool in `skill-meta` -- this is the root cause of the broken pattern.
- The fix requires moving confirmation logic UP into `skill-meta` (foreground), where AskUserQuestion is guaranteed to surface.
- `skill-fix-it` and `skill-learn` are reference implementations: both execute AskUserQuestion in the skill layer (foreground), not in a delegated agent.
- Two modes need different treatment: interactive mode (no args) currently relies entirely on the agent's 7-stage interview; prompt mode (with text arg) proposes a task list that can be confirmed in the skill before spawning.
- `multi-task-creation-standard.md` documents confirmation as Required but does not yet note that confirmation must happen in the foreground layer -- this needs a one-line clarification.

---

## Context & Scope

### Problem Statement

When `/meta "some prompt"` is invoked in prompt mode, the flow is:

```
User -> /meta command -> skill-meta -> Task tool (async) -> meta-builder-agent
                                                                  |
                                                                  v
                                                      AskUserQuestion: "Confirm tasks?"
                                                                  |
                                                            [NEVER SURFACES]
```

The `Task` tool spawns the agent as a background subprocess. `AskUserQuestion` from a background agent does not reliably surface to the foreground conversation. The user never sees the confirmation prompt and either the agent times out waiting or proceeds without user input.

### Scope of Changes Required

Four files need modification:

1. `meta.md` - Document that prompt mode MUST run AskUserQuestion in foreground before delegation
2. `skill-meta/SKILL.md` - Add pre-confirmation stage between context preparation and agent spawn
3. `meta-builder-agent.md` - Add "confirmed" mode; keep existing interactive mode for no-args case
4. `multi-task-creation-standard.md` - Add note that confirmation must happen in foreground layer

---

## Findings

### Finding 1: How AskUserQuestion Works With Background Agents

Claude Code's `Agent` tool (the Task tool in skills) spawns a subagent as a background process. The subagent has its own context window and executes asynchronously. When an agent calls `AskUserQuestion` from within this background context, the interactive prompt appears in the **background agent's thread**, not in the foreground conversation the user is watching.

The result: the user sees the skill invoke the agent, then... silence. The agent blocks waiting for user input that never arrives, eventually timing out or being interrupted.

This is documented implicitly by the pattern used in `skill-fix-it` and `skill-learn`: both skills explicitly execute ALL `AskUserQuestion` calls in the skill body (foreground), before spawning any subagent. The `learn-flow-example.md` explicitly says: "Key difference from old pattern: No subagent delegation. Everything executes directly in skill-learn using AskUserQuestion for interactivity."

### Finding 2: Current Flow in meta.md

`meta.md` (lines 32-65) defines three modes:
- **Interactive** (no args): 7-stage interview, uses AskUserQuestion throughout
- **Prompt** (text arg): Abbreviated flow ending in "Confirm with user" then "Create tasks"
- **Analyze** (--analyze): Read-only, no tasks, no confirmation needed

The command delegates immediately to `skill-meta` in all modes. No AskUserQuestion happens at the command level. The command doc describes confirmation ("Require explicit user confirmation before creating any tasks") but does not specify it must happen in the foreground.

### Finding 3: Current Flow in skill-meta/SKILL.md

`skill-meta` (lines 44-116) does:
1. Input validation and mode detection
2. Context preparation (build delegation JSON)
3. **Immediately invokes meta-builder-agent via Task tool**
4. Return validation
5. Return propagation

There is NO pre-confirmation stage. The skill passes the mode and prompt directly to the agent and waits for return. All interactive work (including confirmation) happens inside the background agent.

The skill's frontmatter shows `allowed-tools: Task, Bash, Edit, Read, Write` -- AskUserQuestion is NOT listed. This is intentional given the current design but must change for prompt mode.

### Finding 4: Current Flow in meta-builder-agent.md (All 7 Stages)

The agent implements three execution paths:

**Stage 3A: Interactive Interview** (for `mode=interactive`)
The entire 7-stage interview with AskUserQuestion runs in the background agent:
- Stage 0: DetectExistingSystem (Bash inventory)
- Stage 1: InitiateInterview (narrative output)
- Stage 2: GatherDomainInfo (AskUserQuestion -- NEVER SURFACES)
- Stage 2.5: DetectDomainType (internal logic)
- Stage 3: IdentifyUseCases (AskUserQuestion -- NEVER SURFACES)
- Stage 4: AssessComplexity (AskUserQuestion -- NEVER SURFACES)
- Stage 5: ReviewAndConfirm (AskUserQuestion -- NEVER SURFACES) <-- confirmation
- Stage 6: CreateTasks (file writes)
- Stage 7: DeliverSummary

**Stage 3B: Prompt Analysis** (for `mode=prompt`)
- Steps 1-2: Internal analysis and related task search
- Step 3: Propose task breakdown
- Step 4: Clarify if needed (AskUserQuestion -- NEVER SURFACES)
- Step 5: Confirm and Create (AskUserQuestion -- NEVER SURFACES) <-- confirmation
- Task creation

**Stage 3C: System Analysis** (for `mode=analyze`)
- Read-only, no confirmation needed, this mode works fine

Critical observation: The critical confirmation AskUserQuestion in Stage 5 (ReviewAndConfirm for interactive, Step 5 for prompt) is what the task description calls out as broken. But for interactive mode, ALL stages are broken -- the user never even sees the opening question "What do you want to accomplish?"

### Finding 5: The Fix Pattern -- Foreground Skill AskUserQuestion

`skill-fix-it` provides the reference pattern. Its frontmatter includes `AskUserQuestion` in `allowed-tools`. It:
1. Does all discovery work inline (grep, bash)
2. Presents findings to user
3. Calls AskUserQuestion for task type selection (foreground -- user sees this)
4. Calls AskUserQuestion for individual item selection (foreground -- user sees this)
5. Calls AskUserQuestion for grouping confirmation (foreground -- user sees this)
6. Creates tasks
7. Git commit

No agent is spawned. Everything is synchronous.

`skill-learn` follows the same pattern explicitly (see learn-flow-example.md).

### Finding 6: What Changes for Each Mode

**Prompt mode** (most urgent fix):
- skill-meta can do lightweight analysis of the prompt in the foreground
- skill-meta proposes task breakdown and calls AskUserQuestion for confirmation
- skill-meta passes confirmed task list to meta-builder-agent with `mode=confirmed`
- meta-builder-agent just creates tasks from the confirmed list (no more interactive)

**Interactive mode** (harder fix):
- The entire 7-stage interview requires multiple back-and-forth AskUserQuestion calls
- Option A: Move the whole interview into skill-meta (no agent delegation for interactive mode)
- Option B: Keep the agent for interactive mode but document this as known-broken until a foreground-agent API is available
- Option C: Run interactive mode in the foreground skill itself (like skill-fix-it does) and only spawn agent for task creation step

The task description says: "keep interactive mode for no-args /meta where agent runs foreground." This suggests Option B or the existing interactive mode works because it's invoked without args and the user sees it differently. However, the same background-agent limitation applies to interactive mode -- all AskUserQuestion calls from Stage 2 onwards are invisible.

Actually, re-reading the task description: "add confirmed mode that accepts pre-validated task list and creates without re-asking; keep interactive mode for no-args /meta where agent runs foreground." The phrase "where agent runs foreground" may mean interactive mode should be restructured so skill-meta itself does the interview (not delegating to an agent), OR it may mean a future state. The task description focuses the fix on prompt mode.

### Finding 7: multi-task-creation-standard.md Current State

Section 7 ("User Confirmation", lines 267-291) states:
> "Always show task summary and require explicit confirmation before creating tasks."
> "Mandatory: User MUST explicitly select 'Yes, create tasks' before any tasks are created."

It does NOT say WHERE this confirmation must happen (foreground vs. background). The compliance table at the bottom (lines 382-392) shows `/meta` as "Full (Reference)" with "All 8 components."

This needs a note: confirmation must execute in the foreground skill layer, not in a delegated background agent, because AskUserQuestion from background agents does not reliably surface to users.

### Finding 8: What Data skill-meta Needs to Propose Tasks

For prompt mode, skill-meta needs to:
1. Parse the prompt for keywords, intent, change type, scope (currently done in agent Step 1)
2. Check state.json for related active tasks (currently done in agent Step 2, requires Bash jq)
3. Propose task breakdown based on analysis
4. Present to user via AskUserQuestion

This requires skill-meta to have `Bash` and `AskUserQuestion` in its allowed-tools (Bash is already present).

For interactive mode, the full interview requires extensive back-and-forth that mirrors what the agent currently does. The skill would need all the same tooling: `Read, Glob, Bash, AskUserQuestion`.

---

## Decisions

1. **Root cause confirmed**: AskUserQuestion from background agents (Task tool spawns) does not surface to users. This is inherent to the architecture, not a configuration issue.

2. **Fix scope**: Prompt mode is the primary fix. Interactive mode is more complex and may require a larger refactor (moving the entire interview into skill-meta or restructuring it differently).

3. **Confirmed mode**: meta-builder-agent needs a new `mode=confirmed` that accepts a pre-validated task list and creates tasks without re-asking. This is a clean addition that doesn't break existing behavior.

4. **skill-fix-it is the right reference**: The foreground-skill pattern with inline AskUserQuestion is the established pattern for commands that need user interaction before task creation.

5. **multi-task-creation-standard.md update**: Add a sentence to Section 7 noting that confirmation must execute in the foreground layer.

---

## Recommendations

### Priority 1: Fix skill-meta for prompt mode

Add a new Stage 2.5 to skill-meta between "Context Preparation" and "Invoke Subagent":

**Stage 2.5: Pre-Confirmation (prompt mode only)**

```
IF mode == "prompt":
  1. Parse prompt for keywords, intent, scope
  2. Run: jq '.active_projects[] | select(.project_name | contains("{keyword}"))' specs/state.json
  3. Propose task breakdown (1-3 tasks for most prompts)
  4. AskUserQuestion: Show task summary, get "Yes/Revise/Cancel"
  5. If Cancel: return cancelled status immediately (no agent spawn)
  6. If Yes: add confirmed_tasks list to delegation context
  7. Set mode="confirmed" in delegation context
```

Add `AskUserQuestion` to skill-meta's allowed-tools frontmatter.

### Priority 2: Add confirmed mode to meta-builder-agent

Add Stage 3D to meta-builder-agent:

**Stage 3D: Confirmed Task Creation** (for `mode=confirmed`)

```
- Receive confirmed_tasks list from delegation context
- Skip all AskUserQuestion (user already confirmed)
- Execute Stage 6 (CreateTasks) directly
- Execute Stage 7 (DeliverSummary)
- Return tasks_created status
```

This mode accepts the pre-validated list and just does the mechanical work of updating TODO.md, state.json, creating task directories, and git committing.

### Priority 3: Address interactive mode

Options in order of complexity:
- **Option A (Simple)**: Document that interactive mode is known-broken for the same reason; add a warning in meta.md that interactive mode requires `--prompt` arg for reliable confirmation. Users should always pass a prompt.
- **Option B (Medium)**: Move the 7-stage interview into skill-meta itself (like skill-fix-it), only spawning agent for the task creation step. Requires adding all the interview logic to the skill.
- **Option C (Full)**: Make skill-meta the primary interview handler for all modes, reducing meta-builder-agent to a pure task-creation agent with no interactive steps.

The task description says "keep interactive mode for no-args /meta where agent runs foreground" -- this suggests Option A (accept the limitation) rather than full refactor.

### Priority 4: Update multi-task-creation-standard.md

Add to Section 7 (User Confirmation), after the "Mandatory" note:

> **Foreground Requirement**: Confirmation MUST execute in the foreground skill layer (not inside a delegated background agent). AskUserQuestion called from background agents (spawned via Task tool) does not reliably surface to users. Skills that delegate to agents for task creation must complete all confirmation steps before spawning the agent.

### Priority 5: Update meta.md

Add to the Prompt Mode section:

> **Confirmation in foreground**: For prompt mode, skill-meta performs task proposal and user confirmation BEFORE spawning meta-builder-agent. The agent receives a pre-confirmed task list and creates tasks without re-prompting.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| skill-meta prompt analysis differs from agent analysis | Medium | Low | Keep analysis logic simple in skill; agent still handles nuanced cases in confirmed mode |
| Interactive mode still broken after fix | High | Medium | Document clearly; recommend prompt mode; plan full refactor as separate task |
| Confirmed mode list format mismatch | Low | Medium | Define schema precisely in both skill and agent docs |
| skill-meta grows too complex | Low | Low | Keep pre-confirmation stage minimal (parse, propose, confirm only) |

---

## Appendix

### Key File Paths

- `/home/benjamin/.config/.claude/commands/meta.md` - Command (lines 1-190)
- `/home/benjamin/.config/.claude/skills/skill-meta/SKILL.md` - Skill (lines 1-210)
- `/home/benjamin/.config/.claude/agents/meta-builder-agent.md` - Agent (lines 1-614)
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md` - Standard (lines 267-291 for confirmation)

### Confirmed Mode Schema (Proposed)

```json
{
  "session_id": "sess_...",
  "mode": "confirmed",
  "confirmed_tasks": [
    {
      "title": "Task title",
      "description": "Task description",
      "task_type": "meta",
      "effort": "2 hours",
      "dependencies": []
    }
  ]
}
```

### Reference: skill-fix-it Frontmatter (Correct Pattern)

```yaml
---
name: skill-fix-it
description: ...
allowed-tools: Bash, Grep, Read, Write, Edit, AskUserQuestion
---
```

Note `AskUserQuestion` in allowed-tools -- this enables foreground interactive prompts.

### Reference: skill-meta Current Frontmatter (Needs Update)

```yaml
---
name: skill-meta
description: ...
allowed-tools: Task, Bash, Edit, Read, Write
---
```

`AskUserQuestion` is missing and must be added for prompt mode pre-confirmation.

### The Background Agent Limitation

Claude Code's Task tool spawns agents asynchronously. `AskUserQuestion` from these agents routes to the background agent's UI thread, not the user's active conversation. This is a platform limitation, not a configuration issue. The established workaround (used by skill-fix-it, skill-learn) is to call AskUserQuestion in the foreground skill before spawning any agent.
