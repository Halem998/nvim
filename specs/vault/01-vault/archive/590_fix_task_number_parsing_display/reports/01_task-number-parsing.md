# Research Report: Task #590

**Task**: 590 - fix_task_number_parsing_display
**Started**: 2026-05-21T10:00:00Z
**Completed**: 2026-05-21T10:35:00Z
**Effort**: 1.5 hours
**Dependencies**: None
**Sources/Inputs**:
- `.claude/hooks/wezterm-task-number.sh` (active hook, 65 lines)
- `.claude/hooks/wezterm-clear-task-number.sh` (SessionStart clear, 26 lines)
- `.claude/hooks/wezterm-clear-status.sh` (UserPromptSubmit CLAUDE_STATUS clear)
- `.claude/hooks/wezterm-notify.sh` (Stop hook notification)
- `.claude/settings.json` (hook registration)
- `~/.dotfiles/config/wezterm.lua` (tab title formatting, lines 306-391)
- `.claude/commands/` (all command files for task-number inventory)
- `.claude/extensions/core/hooks/wezterm-task-number.sh` (template copy)
- `.opencode/hooks/wezterm-task-number.sh` (OpenCode copy)
- `.claude/context/project/neovim/hooks/wezterm-integration.md` (docs)
**Artifacts**:
- `specs/590_fix_task_number_parsing_display/reports/01_task-number-parsing.md` (this file)
**Standards**: report-format.md, artifact-formats.md

---

## Executive Summary

- The active hook at `.claude/hooks/wezterm-task-number.sh` has a narrow regex matching only 4 commands (`research|plan|implement|revise`); it misses `/spawn N`, `/task --recover N`, `/task --expand N`, `/task --abandon N`, `/task --review N`, and `/errors --fix N`
- Multi-task syntax (e.g., `/research 7, 22-24, 59`) already captures the first task number correctly but discards the rest; recommendation is to display the compact full spec (spaces stripped)
- The "stale on follow-up" problem: any non-workflow prompt (including follow-up answers like "yes" or "proceed") currently clears `TASK_NUMBER`; fix is a 3-tier logic that preserves on free text
- Only one file needs functional changes: `wezterm-task-number.sh` (with identical updates applied to its 3 mirror copies and 2 documentation files)
- WezTerm display (`wezterm.lua`) and hook registration (`settings.json`) require no changes

---

## Context & Scope

The `wezterm-task-number.sh` hook is called on every `UserPromptSubmit` event. It reads the user's prompt from the JSON input, extracts task numbers from workflow commands, and sets the `TASK_NUMBER` WezTerm user variable via OSC 1337. WezTerm's `format-tab-title` handler reads this variable and appends `#N` to the tab title, producing a format like `2 nvim #590`.

The tab title `max_width` is 25 characters. The display formula is `{tab_idx} {root_dir} #{TASK_NUMBER}`. For a 4-character project name like `nvim`, the task suffix has ~18 characters of budget — sufficient for compact multi-task specs like `#7,22-24,59` (12 chars).

---

## Findings

### Complete Inventory of Commands That Take Task Numbers

| Command Pattern | Current Regex Matches? | Notes |
|---|---|---|
| `/research N` | YES | Single task |
| `/research N, N-N, N` | PARTIAL | Captures first N only |
| `/plan N` | YES | Single task |
| `/plan N, N-N` | PARTIAL | Captures first N only |
| `/implement N` | YES | Single task |
| `/implement N-N` | PARTIAL | Captures first N of range |
| `/implement N, N-N, N` | PARTIAL | Captures first N only |
| `/revise N` | YES | Single task |
| `/spawn N` | NO | Not in regex |
| `/spawn N description` | NO | Not in regex |
| `/task --recover N` | NO | Not in regex |
| `/task --recover N-N` | NO | Range not supported |
| `/task --expand N` | NO | Not in regex |
| `/task --abandon N` | NO | Not in regex |
| `/task --review N` | NO | Not in regex |
| `/errors --fix N` | NO | Not in regex |
| `/todo` | N/A | No task number |
| `/meta` | N/A | No task number |
| `/review` | N/A | No task number |
| `/task --sync` | N/A | No task number |
| `/task "description"` | N/A | Creates new task, no lookup number |

### Current Regex Analysis

```bash
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research|plan|implement|revise)[[:space:]]+([0-9]+) ]]; then
    TASK_NUMBER="${BASH_REMATCH[2]}"
fi
```

**What it matches**: A prompt optionally starting with whitespace, then an optional `/`, then one of 4 command words, then whitespace, then one or more digits. Captures only the first digit sequence.

**What it misses**:
1. `/spawn N` — `spawn` not in alternation
2. `/task --recover N`, `/task --expand N`, `/task --abandon N`, `/task --review N` — multi-word patterns with `--` flags
3. `/errors --fix N` — `errors` not in alternation, requires `--fix` flag
4. Multi-task ranges: `22-24` — regex stops at first digit group, misses `-24`
5. Multi-task lists: `7, 22-24, 59` — regex stops at `7`, ignores `, 22-24, 59`

**The else branch** currently clears `TASK_NUMBER` for ANY non-matching prompt, including free-text follow-up answers to agent questions (e.g., "yes proceed", "focus on LSP"). This causes the tab title to lose the task context whenever the user responds to an in-progress agent.

### Timing Analysis

The `UserPromptSubmit` event fires when the user submits a message, before Claude begins processing. The hook execution order in `settings.json` is:
1. `wezterm-task-number.sh` — runs first (can read `CLAUDE_STATUS` before it's cleared)
2. `wezterm-clear-status.sh` — clears `CLAUDE_STATUS` after

The `Stop` event fires when Claude finishes responding. It does NOT modify `TASK_NUMBER`. This means `TASK_NUMBER` persists correctly through an entire agent run, but is cleared by the next non-workflow `UserPromptSubmit`.

**The stale scenario**: User types `/research 7` → `TASK_NUMBER=7`. Agent runs and asks a follow-up question. User answers "yes proceed" → `UserPromptSubmit` fires → else branch clears `TASK_NUMBER` → tab loses `#7` context mid-workflow.

**The correct behavior**: `TASK_NUMBER` should persist during follow-up exchanges within a workflow. It should only change/clear when the user explicitly starts a different command.

### Multi-Task Display Strategy

**Recommendation: Compact full spec** (strip internal spaces, preserve structure).

| Input | TASK_NUMBER Value | Tab Shows |
|---|---|---|
| `/research 7` | `7` | `2 nvim #7` |
| `/research 22-24` | `22-24` | `2 nvim #22-24` |
| `/research 7, 22-24, 59` | `7,22-24,59` | `2 nvim #7,22-24,59` |
| `/task --recover 343-345` | `343-345` | `2 nvim #343-345` |

This approach is informative (shows exactly which tasks), stays within the 25-char tab width for typical project names, and is consistent with how task ranges appear in TODO.md.

**Discarded alternatives**:
- First number only (`"7"` for `/research 7, 22-24`): loses multi-task context
- Truncated with `+` (`"7+"`): indicates multi-task but hides task numbers
- Count (`"3"`): ambiguous — looks like task 3

### Proposed Regex Implementation

Three-tier logic replaces the current two-branch (set/else-clear) pattern:

**Tier 1 — SET**: Workflow command with task number(s)

```bash
# Tier 1a: research, plan, implement, revise, spawn + task spec
if [[ "$PROMPT" =~ ^[[:space:]]*/?(research|plan|implement|revise|spawn)[[:space:]]+([0-9][0-9,\ -]*) ]]; then
    TASK_SPEC="${BASH_REMATCH[2]}"
    TASK_SPEC="${TASK_SPEC%%--*}"       # strip from first "--" (flags)
    while [[ "$TASK_SPEC" =~ [[:space:],]$ ]]; do
        TASK_SPEC="${TASK_SPEC%[[:space:],]}"   # strip trailing space/comma
    done
    TASK_DISPLAY="${TASK_SPEC// /}"     # compact: remove spaces
    SHOULD_SET=1

# Tier 1b: /task --recover/expand/abandon/review + task spec
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(task)[[:space:]]+(--(recover|expand|abandon|review))[[:space:]]+([0-9][0-9,\ -]*) ]]; then
    TASK_SPEC="${BASH_REMATCH[4]}"
    TASK_SPEC="${TASK_SPEC%%--*}"
    while [[ "$TASK_SPEC" =~ [[:space:],]$ ]]; do
        TASK_SPEC="${TASK_SPEC%[[:space:],]}"
    done
    TASK_DISPLAY="${TASK_SPEC// /}"
    SHOULD_SET=1

# Tier 1c: /errors --fix N
elif [[ "$PROMPT" =~ ^[[:space:]]*/?(errors)[[:space:]]+--fix[[:space:]]+([0-9]+) ]]; then
    TASK_DISPLAY="${BASH_REMATCH[2]}"
    SHOULD_SET=1

# Tier 2 — CLEAR: Any other slash command (new session context, no task)
elif [[ "$PROMPT" =~ ^[[:space:]]*/[a-zA-Z] ]]; then
    SHOULD_CLEAR=1

# Tier 3 — PRESERVE: Free text / follow-up (no change to TASK_NUMBER)
fi
```

**Test cases confirming correctness**:

| Prompt | Action | TASK_NUMBER |
|---|---|---|
| `/research 7` | SET | `7` |
| `/research 7, 22-24, 59` | SET | `7,22-24,59` |
| `/implement 7, 22-24 --team` | SET | `7,22-24` |
| `/spawn 15 missing state` | SET | `15` |
| `/task --recover 343-345` | SET | `343-345` |
| `/task --recover 337, 343` | SET | `337,343` |
| `/task --expand 5` | SET | `5` |
| `/task --abandon 5` | SET | `5` |
| `/task --review 597` | SET | `597` |
| `/errors --fix 12` | SET | `12` |
| `/todo` | CLEAR | `""` |
| `/meta` | CLEAR | `""` |
| `/review` | CLEAR | `""` |
| `/task --sync` | CLEAR | `""` |
| `/task "new task desc"` | CLEAR | `""` |
| `yes proceed` | PRESERVE | (unchanged) |
| `focus on LSP errors` | PRESERVE | (unchanged) |
| `""` (empty) | PRESERVE | (unchanged) |

### Edge Cases

- **`/task "description"`**: Matches Tier 2 (slash command, no task number after `--flag`) → correctly clears. Creating a new task has no associated lookup number.
- **No-slash command** (`research 7` without `/`): The current regex has `/?` making slash optional. The proposed Tier 2 only clears on `^/[a-zA-Z]`. So bare `research 7` would be treated as free text (Tier 3, preserve). This is the correct behavior — only explicit slash commands are commands.
- **Leading zeros** (`/research 007`): Captured as `007`, stored and displayed as-is. No normalization needed.
- **Empty prompt**: Falls to Tier 3 (preserve). Correct.
- **Very long spec** (`/implement 1,2,3,4,5,6,7,8,9,10`): Displays as `#1,2,3,4,5,6,7,8,9,10` (23 chars). With project name and tab index this may truncate — acceptable since WezTerm handles it gracefully.

---

## Decisions

1. **3-tier logic over 2-tier**: Tier 3 (preserve on free text) solves the "follow-up clears task" problem without requiring conversation-context awareness.
2. **Compact full spec for multi-task**: `7,22-24,59` rather than first-only or abbreviated. Most informative within display budget.
3. **Slash detection for Tier 2**: Using `^[[:space:]]*/[a-zA-Z]` to identify slash commands is simple and correct. A user typing free text starting with `/` is extremely unlikely.
4. **Post-process `--` stripping**: Rather than making the regex exclude `--` characters, capture broadly then strip from first `--` occurrence. This keeps the regex readable.
5. **Apply to all 4 copies**: Both `.claude/` and `.opencode/` active hooks and their `extensions/core/` templates must be updated identically.

---

## Recommendations

### Priority 1: Update wezterm-task-number.sh (all copies)

Apply the 3-tier logic to all 4 copies of the hook:

| File | Role |
|---|---|
| `.claude/hooks/wezterm-task-number.sh` | Claude Code active hook |
| `.claude/extensions/core/hooks/wezterm-task-number.sh` | Claude Code source template |
| `.opencode/hooks/wezterm-task-number.sh` | OpenCode active hook |
| `.opencode/extensions/core/hooks/wezterm-task-number.sh` | OpenCode source template |

### Priority 2: Update documentation files

Update the documented command patterns in:
- `.claude/context/project/neovim/hooks/wezterm-integration.md` (lines ~64-75)
- `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` (same section)

Add new commands to the pattern list, update behavior table to describe 3-tier logic, update `TASK_NUMBER` value description to `"Numeric string or compact multi-task spec (e.g., \"7,22-24,59\")"`.

### No Changes Needed

- `.claude/hooks/wezterm-clear-task-number.sh` — SessionStart clear is correct behavior
- `.claude/settings.json` — Hook registration and order is correct
- `~/.dotfiles/config/wezterm.lua` — Already handles any string value for `TASK_NUMBER`

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Regex over-matches (e.g., `spawn` matching a different command named `spawn`) | All commands are short known words; no namespace conflicts |
| Trailing-hyphen edge case in spec (`22-`) | `%%--*` strips from `--`; single trailing `-` removed by `while` trim loop |
| Long multi-task spec exceeds tab width | WezTerm `truncate_right` handles overflow gracefully |
| `.opencode/` hooks diverge from `.claude/` hooks | Both are updated in the same implementation phase |
| Free text starting with `/` treated as command | Extremely unlikely in practice; acceptable edge case |

---

## File Change Table

| File | Change Type | Lines Affected |
|---|---|---|
| `.claude/hooks/wezterm-task-number.sh` | Modify | Lines 34-62 (regex + conditional logic) |
| `.claude/extensions/core/hooks/wezterm-task-number.sh` | Modify | Same lines |
| `.opencode/hooks/wezterm-task-number.sh` | Modify | Same lines |
| `.opencode/extensions/core/hooks/wezterm-task-number.sh` | Modify | Same lines |
| `.claude/context/project/neovim/hooks/wezterm-integration.md` | Modify | Lines ~64-75 (command list and behavior table) |
| `.claude/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` | Modify | Same section |

---

## Appendix

### Search Queries Used

- `find /home/benjamin/.config/nvim -name "wezterm-task-number.sh"` — located all 4 copies
- `grep -n "spawn\|revise\|recover\|expand" .claude/commands/spawn.md` — verified command patterns
- `grep -rn "wezterm-task-number\|TASK_NUMBER" .claude/` — found all references
- Bash regex testing for all proposed patterns against comprehensive test cases

### Key Constraints

- Claude Code hooks receive only `{ "prompt": "...", "cwd": "..." }` as JSON input — no conversation history
- WezTerm user variables are write-only from shell; cannot be read back via `wezterm cli list`
- The hook runs before `wezterm-clear-status.sh`, so `CLAUDE_STATUS` is still set when the hook runs (if needed for future logic)
- All 4 hook copies must stay in sync; they share identical content

### Related Context

- `task 795`: Introduced the original 2-tier logic (set/clear on workflow vs. other commands)
- `task 802`: Fixed WezTerm tab task number clearing on SessionStart
- This task (590): Adds missing commands, multi-task spec display, and 3-tier preservation logic
