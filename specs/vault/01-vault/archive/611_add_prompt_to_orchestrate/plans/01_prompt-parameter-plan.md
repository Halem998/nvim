# Implementation Plan: Add Optional Prompt Parameter to /orchestrate

- **Task**: 611 - add_prompt_to_orchestrate
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/611_add_prompt_to_orchestrate/reports/01_prompt-parameter-research.md
- **Artifacts**: plans/01_prompt-parameter-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add an optional free-text prompt parameter to the `/orchestrate` command so users can provide focus guidance (e.g., `/orchestrate 42 focus on the LSP config`) that flows through the entire delegation chain to each sub-agent dispatch. The command already has access to `parse-command-args.sh` which exports `FOCUS_PROMPT`; the skill already dispatches sub-agents with prompt strings that can be suffixed. No new infrastructure is needed -- this threads an existing pattern (used by `/research`) through the orchestrate pipeline.

### Research Integration

The research report (01_prompt-parameter-research.md) confirmed:
- `parse-command-args.sh` already exports `FOCUS_PROMPT` after stripping task numbers and flags
- The orchestrate command does not currently source this script; a new Stage 0 is needed
- The skill has 4-5 dispatch sites where prompt strings are constructed inline
- The `dispatch-agent.sh` infrastructure passes prompts through transparently
- The bash idiom `${focus_prompt:+. User focus: $focus_prompt}` is the safe approach for optional suffixes

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Enable `/orchestrate N [prompt]` syntax with optional free-text prompt
- Thread the prompt through delegation context JSON from command to skill
- Append the prompt to every sub-agent dispatch (research, plan, implement, blocker re-implement)
- Update CLAUDE.md command reference to document the new syntax
- Keep the extension copy at `.claude/extensions/core/commands/orchestrate.md` in sync

**Non-Goals**:
- Adding `--team` or multi-task support to `/orchestrate`
- Modifying `parse-command-args.sh` (it already handles prompt extraction)
- Modifying `dispatch-agent.sh` (it already passes prompts transparently)
- Changing the blocker research or plan revision prompts (those are blocker-specific and should remain targeted)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `parse-command-args.sh` exports `TASK_NUMBERS` (plural) but orchestrate is single-task | L | M | Extract first element: `task_number=$(echo "$TASK_NUMBERS" \| awk '{print $1}')` |
| Empty `FOCUS_PROMPT` causes malformed prompt strings | H | L | Use `${focus_prompt:+. User focus: $focus_prompt}` conditional expansion (expands to nothing when empty) |
| Extension copy diverges from active command | M | M | Edit both files in the same phase with identical changes |
| Blocker escalation Step 5 dispatch missed | M | L | Explicitly list all dispatch sites in the phase checklist |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Command Argument Parsing and Delegation Context [COMPLETED]

**Goal**: Update both command files (active + extension copy) to parse the optional prompt from arguments and include it in the delegation context JSON.

**Tasks**:
- [x] Update `argument-hint` frontmatter from `TASK_NUMBER` to `TASK_NUMBER [PROMPT]` in `.claude/commands/orchestrate.md` *(completed)*
- [x] Update the `## Arguments` section to document the optional prompt parameter (`$2+` - Optional prompt/focus text) *(completed)*
- [x] Add a new STAGE 0 (before CHECKPOINT 1) that sources `parse-command-args.sh` and extracts `task_number` and `focus_prompt`:
  ```bash
  source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
  task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')
  focus_prompt="${FOCUS_PROMPT:-}"
  ```
  *(completed)*
- [x] Add `"focus_prompt": "{FOCUS_PROMPT}"` field to the delegation context JSON in STAGE 2 (at the same level as `session_id` and `orchestrator_mode`) *(completed)*
- [x] Apply identical changes to `.claude/extensions/core/commands/orchestrate.md` *(completed)*
- [x] Verify both files remain byte-for-byte identical after edits *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/orchestrate.md` - Add Stage 0 arg parsing, update frontmatter, update delegation JSON
- `.claude/extensions/core/commands/orchestrate.md` - Identical changes (extension copy)

**Verification**:
- Both files have `argument-hint: TASK_NUMBER [PROMPT]`
- Both files contain Stage 0 with `parse-command-args.sh` sourcing
- Both files include `focus_prompt` in delegation context JSON
- `diff` between both files returns empty (files remain identical)

---

### Phase 2: Skill Dispatch Prompt Threading [COMPLETED]

**Goal**: Update the skill state machine to extract `focus_prompt` from delegation context and append it to all sub-agent dispatch prompt strings.

**Tasks**:
- [x] Add `focus_prompt` extraction in Stage 1 (Input Validation), after `session_id` extraction:
  ```bash
  focus_prompt=$(echo "$delegation_context" | jq -r '.focus_prompt // ""')
  ```
  *(completed)*
- [x] Append `${focus_prompt:+. User focus: $focus_prompt}` to the research dispatch prompt in State `not_started`:
  - From: `"Research task $task_number: $DESCRIPTION"`
  - To: `"Research task $task_number: $DESCRIPTION${focus_prompt:+. User focus: $focus_prompt}"`
  *(completed)*
- [x] Append the same suffix to the plan dispatch prompt in State `researched`:
  - From: `"Create implementation plan for task $task_number"`
  - To: `"Create implementation plan for task $task_number${focus_prompt:+. User focus: $focus_prompt}"`
  *(completed)*
- [x] Append the same suffix to the implement dispatch prompt in State `planned`/`implementing`:
  - From: `"Implement task $task_number following the plan"`
  - To: `"Implement task $task_number following the plan${focus_prompt:+. User focus: $focus_prompt}"`
  *(completed)*
- [x] Append the same suffix to the continuation dispatch prompt in State `partial` (sub-state: continuation available):
  - From: `"Resume implementation for task $task_number from continuation handoff"`
  - To: `"Resume implementation for task $task_number from continuation handoff${focus_prompt:+. User focus: $focus_prompt}"`
  *(completed)*
- [x] Append the same suffix to the blocker escalation Step 5 re-implement dispatch prompt:
  - From: `"Implement task $task_number following the revised plan"`
  - To: `"Implement task $task_number following the revised plan${focus_prompt:+. User focus: $focus_prompt}"`
  *(completed)*
- [x] Do NOT modify the blocker research prompt (Step 2) or plan revision prompt (Step 4) -- those are blocker-specific and should remain targeted *(completed: verified unchanged)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add focus_prompt extraction in Stage 1, append to 5 dispatch prompts in Stages 4 and 6

**Verification**:
- Stage 1 includes `focus_prompt` extraction via jq
- All 5 dispatch prompt strings include the conditional suffix
- Blocker research (Step 2) and plan revision (Step 4) prompts are unchanged
- No syntax errors in the bash conditional expansion idiom

---

### Phase 3: Documentation Update [COMPLETED]

**Goal**: Update the CLAUDE.md command reference table to reflect the new syntax.

**Tasks**:
- [x] Update the `/orchestrate` row in the Command Reference table in `.claude/CLAUDE.md`:
  - From: `| /orchestrate | /orchestrate N | Drive task autonomously...`
  - To: `| /orchestrate | /orchestrate N [prompt] | Drive task autonomously...`
  *(completed)*

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/CLAUDE.md` - Update command reference table row for `/orchestrate`

**Verification**:
- The command reference table shows `/orchestrate N [prompt]` in the Usage column
- No other rows in the table were modified

## Testing & Validation

- [ ] Verify `diff .claude/commands/orchestrate.md .claude/extensions/core/commands/orchestrate.md` returns empty (files remain identical)
- [ ] Verify `argument-hint: TASK_NUMBER [PROMPT]` appears in both command files
- [ ] Verify `focus_prompt` field exists in delegation context JSON in both command files
- [ ] Verify `focus_prompt` extraction (jq line) exists in SKILL.md Stage 1
- [ ] Verify 5 dispatch prompts in SKILL.md contain `${focus_prompt:+. User focus: $focus_prompt}`
- [ ] Verify CLAUDE.md command reference shows `/orchestrate N [prompt]`
- [ ] Grep for `FOCUS_PROMPT` in command files to confirm sourcing of parse-command-args.sh
- [ ] Confirm no changes to `parse-command-args.sh` or `dispatch-agent.sh`

## Artifacts & Outputs

- `specs/611_add_prompt_to_orchestrate/plans/01_prompt-parameter-plan.md` (this plan)
- Modified: `.claude/commands/orchestrate.md`
- Modified: `.claude/extensions/core/commands/orchestrate.md`
- Modified: `.claude/skills/skill-orchestrate/SKILL.md`
- Modified: `.claude/CLAUDE.md`

## Rollback/Contingency

All changes are to markdown/prose files in `.claude/`. Rollback is straightforward:
- `git checkout -- .claude/commands/orchestrate.md .claude/extensions/core/commands/orchestrate.md .claude/skills/skill-orchestrate/SKILL.md .claude/CLAUDE.md`
- No database migrations, no binary artifacts, no external service dependencies
