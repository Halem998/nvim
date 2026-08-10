# Research Report: Task #611

**Task**: 611 - add_prompt_to_orchestrate
**Started**: 2026-05-25T00:00:00Z
**Completed**: 2026-05-25T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (commands, skills, scripts)
**Artifacts**: `specs/611_add_prompt_to_orchestrate/reports/01_prompt-parameter-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The `/orchestrate` command currently takes a single `TASK_NUMBER` argument with no optional prompt; both the active command and its extension copy are identical and need the same changes
- The `parse-command-args.sh` script already exports `FOCUS_PROMPT` — orchestrate must source this script (like `/research` does) to get prompt parsing for free
- The `skill-orchestrate` SKILL.md constructs all sub-agent dispatch prompts inline; it needs a `focus_prompt` field extracted from the delegation context and appended to each dispatch string (research, plan, implement, and blocker re-implement steps)
- The delegation context JSON passed from the command to the skill needs one new field: `focus_prompt`
- The CLAUDE.md command reference table needs its usage column updated from `/orchestrate N` to `/orchestrate N [prompt]`

---

## Context & Scope

### What was researched

All files in the `/orchestrate` command chain:

1. `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` — active command
2. `/home/benjamin/.config/nvim/.claude/extensions/core/commands/orchestrate.md` — extension copy (identical to active)
3. `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — state machine skill
4. `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` — superset argument parser
5. `/home/benjamin/.config/nvim/.claude/scripts/dispatch-agent.sh` — dispatch function
6. `/home/benjamin/.config/nvim/.claude/commands/research.md` — reference for focus/prompt pattern
7. `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` — reference for delegation context with `focus_prompt`
8. `/home/benjamin/.config/nvim/.claude/CLAUDE.md` — command reference table

### Constraints

- The command uses `argument-hint` frontmatter (currently `TASK_NUMBER`)
- Skill dispatch in command files must remain as markdown prose — cannot be moved to bash scripts (per memory: "Command files cannot delegate Skill tool invocations to bash scripts")
- The skill's context-flatness constraint (Stage 8) must be preserved — no reading report/plan content inside the state machine loop
- The extension copy at `.claude/extensions/core/commands/orchestrate.md` must receive identical changes as the active command

---

## Findings

### 1. Current Argument Parsing in the Orchestrate Command

The active command at `.claude/commands/orchestrate.md` has:

```yaml
argument-hint: TASK_NUMBER
```

In its execution section, the task number is not parsed via `parse-command-args.sh`. The command's STAGE 2 just passes `task_number={N}` directly in the skill args string — there is no call to `parse-command-args.sh` in the current orchestrate command. The task number is assumed to be extracted directly from `$ARGS` or `$1`.

The `/research` command, by contrast, does:
```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE, EFFORT_FLAG, MODEL_FLAG,
#          CLEAN_FLAG, FORCE_FLAG, FOCUS_PROMPT
```

The FOCUS_PROMPT export comes from Step 5 of `parse-command-args.sh`: it strips all recognized flags from the remaining args after task numbers, leaving the free-text prompt as `FOCUS_PROMPT`.

**Key finding**: Orchestrate needs a new Stage 0 that sources `parse-command-args.sh` to get the task number AND extract the optional prompt text. No changes to `parse-command-args.sh` itself are needed.

### 2. How parse-command-args.sh Extracts FOCUS_PROMPT

From the script (lines 112–124):
```bash
FOCUS_PROMPT=$(echo "$remaining" \
  | sed 's/--team-size[[:space:]]*=*[[:space:]]*[0-9]*//g' \
  | sed 's/--team//g' \
  | sed 's/--fast//g' \
  | sed 's/--hard//g' \
  | sed 's/--haiku//g' \
  | sed 's/--sonnet//g' \
  | sed 's/--opus//g' \
  | sed 's/--clean//g' \
  | sed 's/--force//g' \
  | sed 's/--exploit//g' \
  | sed 's/--explore//g' \
  | xargs)
```

After stripping the task number from `$ARGUMENTS` (Step 1-3), all recognized flags are stripped (Steps 4-5), and whatever text remains becomes `FOCUS_PROMPT`. For `/orchestrate 42 focus on the LSP config`, `FOCUS_PROMPT` would be `"focus on the LSP config"`.

The script already handles this perfectly for orchestrate's use case.

### 3. Delegation Context in skill-orchestrate

The delegation context JSON passed from the command to the skill (STAGE 2 of the command) currently contains:
```json
{
  "session_id": "{SESSION_ID}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "orchestrate", "skill-orchestrate"],
  "task_context": {
    "task_number": N,
    "task_name": "{PROJECT_NAME}",
    "description": "{DESCRIPTION}",
    "task_type": "{TASK_TYPE}"
  },
  "orchestrator_mode": true
}
```

A new `"focus_prompt": "{FOCUS_PROMPT}"` field must be added at the top level (same level as `session_id`, `orchestrator_mode`), matching the pattern used by `skill-researcher`'s delegation context.

### 4. Sub-agent Dispatch in skill-orchestrate (State Handlers)

The skill reads `focus_prompt` from delegation context at Stage 1 (after `session_id`):

```bash
focus_prompt=$(echo "$delegation_context" | jq -r '.focus_prompt // ""')
```

Then the four dispatch sites where `focus_prompt` should be appended to the prompt string:

**State: `not_started` / `not started`** (research dispatch):
```
dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \
  "Research task $task_number: $DESCRIPTION" \
  ...
```
Becomes:
```
dispatch_instructions = dispatch_agent "$RESEARCH_AGENT" \
  "Research task $task_number: $DESCRIPTION${focus_prompt:+. User focus: $focus_prompt}" \
  ...
```

**State: `researched`** (plan dispatch):
```
dispatch_instructions = dispatch_agent "planner-agent" \
  "Create implementation plan for task $task_number" \
  ...
```
Becomes:
```
dispatch_instructions = dispatch_agent "planner-agent" \
  "Create implementation plan for task $task_number${focus_prompt:+. User focus: $focus_prompt}" \
  ...
```

**State: `planned` / `implementing`** (implement dispatch):
```
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Implement task $task_number following the plan" \
  ...
```
Becomes:
```
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Implement task $task_number following the plan${focus_prompt:+. User focus: $focus_prompt}" \
  ...
```

**State: `partial` with continuation** (resume implement dispatch):
```
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Resume implementation for task $task_number from continuation handoff" \
  ...
```
Becomes:
```
dispatch_instructions = dispatch_agent "$IMPLEMENT_AGENT" \
  "Resume implementation for task $task_number from continuation handoff${focus_prompt:+. User focus: $focus_prompt}" \
  ...
```

Note: Blocker escalation Step 5 (re-dispatch implement after revision) also dispatches implement. The `focus_prompt` should be appended there too.

The bash idiom `${focus_prompt:+. User focus: $focus_prompt}` expands to `. User focus: {text}` when `focus_prompt` is non-empty, and to nothing when it's empty. This is safe and idiomatic for optional suffixes.

### 5. dispatch-agent.sh: How Prompts Flow

`dispatch_agent()` takes a `$prompt` string as its second argument and passes it through to `invoke_named_agent()` or `invoke_agent_fork()`, which include it in the JSON output under the `"prompt"` key. The skill then uses this JSON to build the Agent tool invocation. No changes to `dispatch-agent.sh` are needed — it already passes prompts through transparently.

### 6. Extension Copy Confirmation

The extension copy at `.claude/extensions/core/commands/orchestrate.md` is byte-for-byte identical to the active command (both 127-line files with identical content). Both must receive the same changes.

### 7. CLAUDE.md Command Reference Table

Current entry (line 111):
```
| `/orchestrate` | `/orchestrate N` | Drive task autonomously through full lifecycle (no confirmation gates) |
```

New entry:
```
| `/orchestrate` | `/orchestrate N [prompt]` | Drive task autonomously through full lifecycle (no confirmation gates) |
```

---

## Decisions

- **Prompt propagation method**: Use bash `${focus_prompt:+. User focus: $focus_prompt}` idiom for safe optional suffix appending — no code path changes, just string extension
- **Context key**: Use `focus_prompt` at the top level of delegation context JSON (same as skill-researcher pattern), not nested inside `task_context`
- **Argument parsing**: Source `parse-command-args.sh` in a new Stage 0 in the orchestrate command, extracting `TASK_NUMBERS` (take first element) and `FOCUS_PROMPT`
- **No changes to dispatch-agent.sh**: The dispatch infrastructure already handles arbitrary prompt strings
- **Both command copies need changes**: Active command and extension copy are identical and must receive identical edits

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `parse-command-args.sh` uses `TASK_NUMBERS` (plural), but orchestrate is single-task only | Extract first element: `task_number=$(echo "$TASK_NUMBERS" \| awk '{print $1}')` |
| Empty `FOCUS_PROMPT` causes malformed prompt strings | Use `${focus_prompt:+...}` conditional expansion which safely expands to nothing when empty |
| Extension copy diverges from active command over time | Both files should be edited in the same implementation step |
| `focus_prompt` injection changes behavior for existing invocations without prompt | No behavioral change — when `FOCUS_PROMPT` is empty, the conditional expansion adds nothing |
| Blocker escalation Stage 6 has multiple dispatch calls | Only the re-implement dispatch (Step 5) benefits from focus; blocker research and revision prompts are already blocker-specific and should remain targeted |

---

## Summary of Changes Required

### File 1: `.claude/commands/orchestrate.md`

1. Update `argument-hint` frontmatter from `TASK_NUMBER` to `TASK_NUMBER [PROMPT]`
2. Update `## Arguments` section to add `$2+` - Optional prompt text
3. Add **STAGE 0: PARSE ARGS** before CHECKPOINT 1:
   ```bash
   source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
   task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')
   focus_prompt="${FOCUS_PROMPT:-}"
   ```
4. Add `"focus_prompt": "{FOCUS_PROMPT}"` to the delegation context JSON in STAGE 2

### File 2: `.claude/extensions/core/commands/orchestrate.md`

- Identical changes as File 1 (same content, same edits)

### File 3: `.claude/skills/skill-orchestrate/SKILL.md`

1. Add `focus_prompt` extraction in Stage 1:
   ```bash
   focus_prompt=$(echo "$delegation_context" | jq -r '.focus_prompt // ""')
   ```
2. Append `${focus_prompt:+. User focus: $focus_prompt}` to 4-5 dispatch prompt strings in Stage 4 state handlers

### File 4: `.claude/CLAUDE.md`

- Update command reference table: `/orchestrate N` -> `/orchestrate N [prompt]`

---

## Context Extension Recommendations

- None identified. The `focus_prompt` pattern is already documented via the `/research` command and `skill-researcher` — this task extends the same pattern to orchestrate.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` (127 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/orchestrate.md` (127 lines, identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (495 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` (136 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/dispatch-agent.sh` (129 lines)
- `/home/benjamin/.config/nvim/.claude/commands/research.md` (190 lines, reference pattern)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (reference for delegation context)
- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` (command reference table)

### Memory Context
- Retrieved memory: "Command files cannot delegate Skill tool invocations to bash scripts" — confirms the Stage 0 bash parse + markdown skill dispatch structure
