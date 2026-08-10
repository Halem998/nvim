# Implementation Plan: Fix /meta Pre-Confirmation Pattern

- **Task**: 603 - fix_meta_pre_confirmation_pattern
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_meta-pre-confirmation.md
- **Artifacts**: plans/01_meta-pre-confirmation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

AskUserQuestion called from background agents (spawned via the Task tool) does not reliably surface to the user. Currently, `/meta` in prompt mode delegates immediately to meta-builder-agent, which calls AskUserQuestion for confirmation from the background -- the user never sees it. The fix moves confirmation into the foreground skill layer (skill-meta) before spawning the agent, following the established pattern used by skill-fix-it and skill-learn. The agent receives a new `mode=confirmed` path that accepts a pre-validated task list and creates tasks without re-prompting.

### Research Integration

Key findings from `reports/01_meta-pre-confirmation.md`:
- AskUserQuestion from background agents routes to the background thread, not the user's active conversation (platform limitation, not a configuration issue)
- skill-fix-it and skill-learn are reference implementations: both call AskUserQuestion in the foreground skill before any agent spawn
- skill-meta's frontmatter is missing `AskUserQuestion` from `allowed-tools` -- must be added
- meta-builder-agent needs a `mode=confirmed` path (Stage 3D) that skips all interactive prompts
- Interactive mode (no args) has the same limitation but is out of scope; the full 7-stage interview refactor is a separate task

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific roadmap items are directly addressed by this task. However, this fix improves overall Agent System Quality by correcting a broken confirmation pattern in a core command.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Move user confirmation for prompt mode into the foreground skill layer where AskUserQuestion works
- Add `mode=confirmed` to meta-builder-agent that accepts a pre-validated task list
- Add `AskUserQuestion` to skill-meta's allowed-tools
- Document the foreground confirmation requirement in multi-task-creation-standard.md
- Update meta.md to describe the new prompt mode confirmation flow

**Non-Goals**:
- Refactoring interactive mode (no args) -- the full 7-stage interview restructuring is a separate, larger task
- Changing the Agent/Task tool platform behavior
- Modifying analyze mode (it has no confirmation step and works correctly)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| skill-meta prompt analysis diverges from agent analysis quality | M | M | Keep skill-side analysis minimal (parse, propose, confirm only); agent handles nuanced task creation in confirmed mode |
| Confirmed mode task list schema mismatch between skill and agent | H | L | Define schema precisely in both files; include schema example in both SKILL.md and agent doc |
| Interactive mode remains broken after this fix | M | H | Document clearly in meta.md; recommend prompt mode; plan full refactor as separate task |
| skill-meta grows too complex with inline analysis | L | L | Limit pre-confirmation to keyword parsing, state.json check, and summary presentation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update skill-meta SKILL.md [COMPLETED]

**Goal**: Add pre-confirmation stage for prompt mode so AskUserQuestion runs in the foreground before spawning meta-builder-agent

**Tasks**:
- [x] Add `AskUserQuestion` to the `allowed-tools` frontmatter line (change from `Task, Bash, Edit, Read, Write` to `Task, Bash, Edit, Read, Write, AskUserQuestion`) *(completed)*
- [x] Add a new **Stage 2.5: Pre-Confirmation (prompt mode only)** section between "Context Preparation" and "Invoke Subagent" with these steps: *(completed)*
  - Parse prompt for keywords, intent, and scope
  - Run `jq` query against `specs/state.json` to check for related active tasks
  - Propose task breakdown (1-3 tasks for typical prompts) with title, description, task_type, effort, dependencies
  - Call AskUserQuestion with "Yes, create tasks" / "Revise" / "Cancel" options
  - On Cancel: return cancelled status immediately (no agent spawn)
  - On Revise: re-prompt with adjusted breakdown
  - On Yes: set `mode=confirmed` and add `confirmed_tasks` list to delegation context
- [x] Update Section 3 (Invoke Subagent) to pass `mode=confirmed` and `confirmed_tasks` in the delegation context when pre-confirmation succeeds *(completed)*
- [x] Add a `cancelled` return format example for when user cancels at the skill layer (no agent spawned) *(completed)*
- [x] Define the `confirmed_tasks` schema inline with an example matching the research report's proposed schema: *(completed)*
  ```json
  {
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

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/.claude/skills/skill-meta/SKILL.md` - Add AskUserQuestion to frontmatter, add Stage 2.5 pre-confirmation section, update delegation context

**Verification**:
- `allowed-tools` line includes `AskUserQuestion`
- Stage 2.5 section exists with complete pre-confirmation flow
- Delegation context includes `mode=confirmed` and `confirmed_tasks` fields
- Cancelled return format documented for skill-level cancellation

---

### Phase 2: Update meta-builder-agent.md [COMPLETED]

**Goal**: Add `mode=confirmed` execution path that accepts a pre-validated task list and creates tasks without any AskUserQuestion calls

**Tasks**:
- [x] Add `confirmed` to the valid modes list in Stage 1 (Parse Delegation Context) -- update from `interactive|prompt|analyze` to `interactive|prompt|analyze|confirmed` *(completed)*
- [x] Add a new **Stage 3D: Confirmed Task Creation** section after Stage 3C with these steps: *(completed)*
  - Extract `confirmed_tasks` array from delegation context
  - Validate each task has required fields (title, description, task_type, effort)
  - Skip all AskUserQuestion calls (user already confirmed in skill layer)
  - Execute Stage 6 (CreateTasks) logic directly for each confirmed task
  - Execute Stage 7 (DeliverSummary) to produce output
- [x] Add routing entry in Stage 3 header: `confirmed` -> Stage 3D: Confirmed Task Creation *(completed)*
- [x] Add a `confirmed` mode return format example in Stage 5 (Return Structured JSON) showing `mode: "confirmed"` in metadata *(completed)*
- [x] Update the Mode-Context Matrix table to add a `confirmed` column (same as `prompt` column but with no on-demand loading needed since tasks are pre-validated) *(completed)*
- [x] Add a note in Stage 3B (Prompt Analysis) that this path is now only used when skill-meta cannot handle pre-confirmation (fallback/legacy) *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/.claude/agents/meta-builder-agent.md` - Add confirmed mode routing, Stage 3D section, return format, context matrix update

**Verification**:
- Stage 3 routes `confirmed` mode to Stage 3D
- Stage 3D accepts `confirmed_tasks` and creates tasks without AskUserQuestion
- Mode-Context Matrix includes `confirmed` column
- Return format example includes `mode: "confirmed"`

---

### Phase 3: Update Documentation [COMPLETED]

**Goal**: Update meta.md command documentation and multi-task-creation-standard.md to reflect the foreground confirmation pattern

**Tasks**:
- [x] In `meta.md`, update the Prompt Mode section (lines 82-91) to document that confirmation happens in the foreground skill layer before agent spawn: *(completed)*
  - Add note: "For prompt mode, skill-meta performs task proposal and user confirmation BEFORE spawning meta-builder-agent. The agent receives a pre-confirmed task list and creates tasks without re-prompting."
  - Update step 4 ("Confirm with user") to note this runs in the foreground skill
- [x] In `meta.md`, add a note in the Interactive Mode section (lines 69-79) that interactive mode currently runs all AskUserQuestion calls in the background agent and may not surface prompts reliably; recommend using prompt mode for reliable confirmation *(completed)*
- [x] In `multi-task-creation-standard.md`, add a "Foreground Requirement" note after the "Mandatory" line in Section 7 (User Confirmation, around line 291): *(completed)*
  - "**Foreground Requirement**: Confirmation MUST execute in the foreground skill layer (not inside a delegated background agent). AskUserQuestion called from background agents (spawned via Task tool) does not reliably surface to users. Skills that delegate to agents for task creation must complete all confirmation steps before spawning the agent."

**Timing**: 0.25 hours

**Depends on**: 2

**Files to modify**:
- `/home/benjamin/.config/.claude/commands/meta.md` - Update prompt mode and interactive mode documentation
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md` - Add foreground requirement note to Section 7

**Verification**:
- meta.md prompt mode section documents foreground confirmation
- meta.md interactive mode section includes reliability caveat
- multi-task-creation-standard.md Section 7 includes Foreground Requirement note
- No formatting or structural issues in either file

## Testing & Validation

- [ ] Verify skill-meta SKILL.md frontmatter includes `AskUserQuestion` in allowed-tools
- [ ] Verify meta-builder-agent.md accepts `confirmed` as a valid mode
- [ ] Verify meta-builder-agent.md Stage 3D exists and routes confirmed tasks to creation without AskUserQuestion
- [ ] Verify meta.md documents the foreground confirmation pattern for prompt mode
- [ ] Verify multi-task-creation-standard.md includes the foreground requirement note
- [ ] Verify confirmed_tasks schema is consistent between skill-meta and meta-builder-agent docs
- [ ] Manual test: run `/meta "test prompt"` and confirm that AskUserQuestion surfaces in the foreground

## Artifacts & Outputs

- `specs/603_fix_meta_pre_confirmation_pattern/plans/01_meta-pre-confirmation.md` (this plan)
- Modified: `/home/benjamin/.config/.claude/skills/skill-meta/SKILL.md`
- Modified: `/home/benjamin/.config/.claude/agents/meta-builder-agent.md`
- Modified: `/home/benjamin/.config/.claude/commands/meta.md`
- Modified: `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md`

## Rollback/Contingency

All changes are documentation-only modifications to markdown files in the agent system. If the changes cause issues:
1. Revert the specific file(s) using `git checkout HEAD -- <file>`
2. The existing prompt and interactive modes continue to work as before (with the known AskUserQuestion limitation)
3. No code, build, or runtime dependencies are affected
