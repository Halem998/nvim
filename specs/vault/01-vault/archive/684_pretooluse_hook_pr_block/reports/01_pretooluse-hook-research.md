# Research Report: Task #684

**Task**: 684 - Add PreToolUse hook to block PR/push operations
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (.claude/settings.json, existing hooks), Official Claude Code docs (code.claude.com/docs/en/hooks, code.claude.com/docs/en/hooks-guide, code.claude.com/docs/en/permissions), GitHub issues (#4669, #13214, #18312)
**Artifacts**: specs/684_pretooluse_hook_pr_block/reports/01_pretooluse-hook-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- PreToolUse hooks CAN reliably block commands even when `Bash(git:*)` is in the allow list, but ONLY via the **exit code 2** mechanism -- not via `permissionDecision: deny` JSON output
- The `permissionDecision: deny` approach has documented bugs when tools are in the allow list (issues #4669, #13214, #18312); the exit code 2 approach is explicitly endorsed in official docs as the recommended pattern for this exact use case
- The hook receives JSON on stdin with `tool_input.command` containing the bash command; no `CLAUDE_TOOL_INPUT` env var is needed
- Command-context awareness (distinguishing /merge from agent calls) is NOT possible via hooks; the recommended mitigation is to have /merge and /pr commands use `allowed-tools` frontmatter and document the workflow
- The recommended implementation uses a standalone script at `.claude/hooks/block-pr-submission.sh` with exit code 2 for denied commands

## Context & Scope

The task requires adding a PreToolUse hook that intercepts Bash tool calls containing `gh pr create`, `glab mr create`, or `git push` commands, and blocks them with an explanation directing users to the `/merge` or `/pr` commands. The hook must work alongside the existing `Bash(git:*)` entry in the project's allow list.

### Current Configuration State

The project's `.claude/settings.json` already has:
- `Bash(git:*)` in the allow list (allowing all git commands without prompts)
- One existing PreToolUse hook (Write matcher for state.json)
- Multiple PostToolUse, SessionStart, Stop, SubagentStop, UserPromptSubmit, and Notification hooks
- Existing hook scripts in `.claude/hooks/` following a consistent pattern

## Findings

### 1. PreToolUse Hook JSON Input Format

Hooks receive JSON on **stdin** (not via environment variable). For Bash tool calls, the format is:

```json
{
  "session_id": "abc123",
  "cwd": "/home/benjamin/.config/nvim",
  "hook_event_name": "PreToolUse",
  "permission_mode": "default",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git push origin main"
  }
}
```

Key fields:
- `tool_name`: Always `"Bash"` for shell commands
- `tool_input.command`: The exact command string Claude is attempting to execute
- `permission_mode`: The current permission mode (default, acceptEdits, bypassPermissions, etc.)

**Note**: The `CLAUDE_TOOL_INPUT` environment variable was mentioned in some older documentation but the canonical mechanism is stdin JSON. The existing inline hook in settings.json uses `$CLAUDE_TOOL_INPUT` via `echo`, which also works but is less reliable according to issue #9567.

### 2. Two Blocking Mechanisms: Exit Code 2 vs. permissionDecision

There are two ways to block a tool call from a PreToolUse hook:

#### Mechanism A: Exit Code 2 (RECOMMENDED)

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE 'git push|gh pr create'; then
  echo "BLOCKED: PR/push operations require the /merge or /pr command." >&2
  exit 2
fi

exit 0
```

**Behavior**: Exit code 2 blocks the tool call. The stderr message is fed back to Claude as feedback. This mechanism works **before** permission rules are evaluated.

**Official documentation** (code.claude.com/docs/en/permissions):
> "A blocking hook also takes precedence over allow rules. A hook that exits with code 2 stops the tool call before permission rules are evaluated, so the block applies even when an allow rule would otherwise let the call proceed."

#### Mechanism B: permissionDecision JSON (NOT RECOMMENDED for this use case)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Use /merge or /pr command instead"
  }
}
```

**Known Issues**:
- Issue #4669 (CLOSED): `permissionDecision: deny` ignored in some versions
- Issue #13214 (CLOSED): PreToolUse hooks bypassed when permission rule matches allow list
- Issue #18312 (CLOSED, duped to #13214): Hook `permissionDecision` ignored when `Bash` is in allow list

The documentation clarifies that `permissionDecision: "allow"` does NOT override deny rules, and `permissionDecision: "deny"` may not override allow rules in all cases. Exit code 2 is the only mechanism that reliably blocks regardless of allow list state.

### 3. Settings.json Configuration Format

The hook entry in settings.json should use:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "if": "Bash(git push *)",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-pr-submission.sh"
    }
  ]
}
```

**Matcher field**: Filters by tool name. `"Bash"` matches all Bash tool calls.

**`if` field** (v2.1.85+): Uses permission rule syntax for fine-grained filtering. The hook process only spawns when the tool call matches the pattern. Important behaviors:
- `Bash(git push *)` matches `git push`, `npm test && git push`, and `echo $(git push)`
- The `if` field checks compound commands (separated by `&&`, `||`, `;`, `|`)
- Commands inside `$()` and backticks are also checked
- The filter **fails open**: if parsing fails, the hook runs anyway

**Limitation**: The `if` field only supports a single pattern per handler. To match multiple patterns (`git push`, `gh pr create`, `glab mr create`), either:
1. Use multiple hook handlers with separate `if` patterns (recommended for performance)
2. Omit `if` and do all pattern matching inside the script (simpler but spawns process for every Bash call)
3. Use `if` for the most common pattern and add script-level checks for others

**Recommended approach**: Omit the `if` field and do all matching in the script, since we need to check three distinct patterns. The process spawn overhead is negligible.

### 4. Command-Context Awareness

**Question**: Can the hook distinguish between user-invoked commands (via `/merge` or `/pr`) and agent-invoked calls?

**Answer**: No. The stdin JSON does not include which command/skill triggered the tool call. The `session_id` and `permission_mode` fields are present but do not indicate the command context.

**Available fields that do NOT solve this**:
- `session_id`: Same for the entire session, not per-command
- `permission_mode`: Global setting, not per-command
- `hook_event_name`: Always "PreToolUse"
- No `command_context`, `skill_name`, or `invoked_by` field exists

**Workaround options**:

1. **Environment variable signal** (recommended): The `/merge` and `/pr` commands could set a temporary signal file or environment variable before executing git push/gh pr create. The hook script checks for this signal and allows the command if present.

2. **Allowed-tools frontmatter**: The `/merge` command already has `allowed-tools: Bash(git:*), Bash(gh:*), Bash(glab:*)` in its frontmatter. However, this affects the Claude Code permission system, not hooks. Hooks fire regardless of `allowed-tools`.

3. **Accept the limitation**: Simply block ALL git push/gh pr create calls from the hook. If the user wants to push or create a PR, they do it manually outside Claude Code, or they temporarily disable the hook. This is the simplest and most secure approach.

4. **Signal file approach**: Before the `/merge` or `/pr` command issues a push, it writes a temp file (e.g., `/tmp/.claude-pr-allowed-$$`). The hook checks for the file's existence and recency (within last 60 seconds). The command cleans up after. This is fragile but functional.

### 5. Existing Hook Patterns in the Project

The project uses two patterns for hooks:

**Pattern A: Inline command** (existing Write PreToolUse hook):
```json
{
  "type": "command",
  "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); ...'"
}
```

**Pattern B: External script** (most other hooks):
```json
{
  "type": "command",
  "command": "bash .claude/hooks/validate-state-sync.sh 2>/dev/null || echo '{}'"
}
```

The task description requests Pattern B (external script) for testability. Existing scripts follow conventions:
- Shebang: `#!/bin/bash`
- Error handling: `set -uo pipefail` in some scripts
- stdin parsing: `INPUT=$(cat)` then `jq` extraction
- Graceful fallback: `echo '{}'` and `exit 0` on non-matching inputs
- Location: `.claude/hooks/` directory

### 6. Compound Command and Evasion Considerations

Claude Code's `if` field parser handles compound commands by checking each subcommand independently. However, when matching in the script itself, care must be taken:

**Commands to detect**:
- `git push` (with or without arguments: `git push`, `git push origin main`, `git push -u origin HEAD`)
- `gh pr create` (with various flags)
- `glab mr create` (with various flags)

**Evasion patterns to consider**:
- Compound commands: `npm test && git push` -- grep will catch `git push` in the full string
- Subshells: `$(git push)` -- the `if` field catches this; grep on the full command string also catches it
- Variable expansion: `CMD=push && git $CMD` -- harder to catch, but Claude Code is unlikely to generate this
- Quoting: `git "push"` -- unlikely but possible; grep on `git.*push` handles this
- Process wrappers: `timeout 30 git push` -- Claude Code strips recognized wrappers before `if` evaluation

**Recommended detection**: Use `grep -qE` with patterns that match the command words:
- `\bgit\s+push\b` or simpler `git push` (since git push is distinctive enough)
- `\bgh\s+pr\s+create\b` or `gh pr create`
- `\bglab\s+mr\s+create\b` or `glab mr create`

For simplicity and reliability, basic substring matching (`grep -q`) is sufficient since these command sequences are highly distinctive and unlikely to appear in non-PR contexts.

### 7. Interaction with --dangerously-skip-permissions

The official documentation confirms:
> "The bypass flag skips only interactive confirmations, not hooks."

This means the hook will fire even in bypass permissions mode, providing an additional safety layer.

## Recommendations

### Recommended Hook Script Implementation

```bash
#!/bin/bash
# block-pr-submission.sh
# PreToolUse hook: block PR/push operations
# These operations should use /merge or /pr commands with explicit user approval.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check for PR creation and push commands
if echo "$COMMAND" | grep -qE 'git push|gh pr create|glab mr create'; then
  echo "BLOCKED: PR submission and git push operations are not allowed directly." >&2
  echo "Use the /merge command (GitHub PR or GitLab MR) or /pr command (CSLib PRs) instead." >&2
  echo "These commands include proper CI verification and user approval gates." >&2
  exit 2
fi

exit 0
```

### Recommended Settings.json Entry

Add to the existing `PreToolUse` array in `.claude/settings.json`:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash .claude/hooks/block-pr-submission.sh"
    }
  ]
}
```

**Why no `if` field**: The `if` field only accepts a single pattern. We need to match three patterns (`git push`, `gh pr create`, `glab mr create`). Using multiple hook handlers with separate `if` fields would work but adds complexity. Since the script itself is lightweight (just jq + grep), the overhead of spawning it for every Bash call is negligible.

### Alternative: With `if` field (more selective spawning)

If process spawn overhead is a concern, use the `if` field to filter. However, since `if` only accepts one pattern, you need separate hook entries:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "if": "Bash(git push *)",
      "command": "bash .claude/hooks/block-pr-submission.sh"
    },
    {
      "type": "command",
      "if": "Bash(gh pr *)",
      "command": "bash .claude/hooks/block-pr-submission.sh"
    },
    {
      "type": "command",
      "if": "Bash(glab mr *)",
      "command": "bash .claude/hooks/block-pr-submission.sh"
    }
  ]
}
```

This approach spawns the script only when one of the three patterns matches, reducing unnecessary process creation. The script still does its own verification as a safety net (defense in depth), since the `if` filter fails open.

### Regarding /merge and /pr Command Compatibility

The `/merge` command uses `allowed-tools: Bash(git:*), Bash(gh:*), Bash(glab:*)` and the `/pr` command uses `allowed-tools: Bash, Read, Edit, Write, AskUserQuestion`. These frontmatter declarations affect Claude Code's permission system but do NOT bypass PreToolUse hooks.

**Impact**: When `/merge` or `/pr` is invoked, the hook WILL block git push and gh pr create calls made by those commands. This is a fundamental limitation.

**Mitigation options** (in order of recommendation):

1. **Signal file approach**: Have `/merge` and `/pr` set a signal before push operations. The hook checks for it. Implementation:
   - Before push: `touch /tmp/.claude-pr-allowed`
   - Hook: check if `/tmp/.claude-pr-allowed` exists and was modified within the last 60 seconds
   - After push: `rm -f /tmp/.claude-pr-allowed`
   - This requires modifying the /merge and /pr command definitions

2. **Permission deny rule instead of hook**: Use `"deny": ["Bash(git push *)"]` in settings.json permissions. This is simpler but less flexible (no custom error message, no `gh pr create` blocking via deny rules since `gh` is not in the allow list pattern).

3. **Accept full blocking**: Block ALL push/PR operations via the hook. Users must push/create PRs manually from the terminal. This is the most secure but least convenient option.

4. **Exclude from hook via comment convention**: The /merge and /pr commands could add a distinctive comment to their push commands (e.g., `git push origin HEAD # APPROVED_BY_MERGE_COMMAND`). The hook checks for this comment suffix. This is fragile but self-contained.

## Decisions

- Use **exit code 2** mechanism exclusively; avoid `permissionDecision` JSON due to documented bugs with allow lists
- Use **external script** at `.claude/hooks/block-pr-submission.sh` per the task description
- Use **substring matching** via `grep -qE` for command detection (sufficient for the distinctive patterns)
- **Omit `if` field** in the initial implementation for simplicity; the script handles all three patterns internally
- The question of /merge and /pr compatibility should be deferred to the implementation plan, where the tradeoffs can be evaluated with the user

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Hook blocks /merge and /pr commands | High | Signal file approach or accept manual push workflow |
| Exit code 2 causes Claude to stop instead of retry (issue #24327) | Medium | Write clear stderr message directing to /merge; this is intermittent and model-dependent |
| Evasion via variable expansion (`CMD=push; git $CMD`) | Low | Unlikely pattern from Claude; add CLAUDE.md guidance as defense in depth |
| Hook not firing in headless mode (-p) (issue #36071) | Low | Not relevant for interactive use; headless deployments need separate safeguards |
| Performance overhead of spawning script for every Bash call | Low | Script is <10ms; can add `if` field optimization later if needed |

## Appendix

### Search Queries Used
- "Claude Code PreToolUse hook permissionDecision deny bash command block"
- "Claude Code hooks PreToolUse CLAUDE_TOOL_INPUT environment variable JSON format"
- "Claude Code PreToolUse hook hookSpecificOutput deny bash allow list fix resolved 2026"
- "Claude Code hooks PreToolUse exit 2 stderr block command latest version"
- "Claude Code Bash(git:*) allow list PreToolUse hook git push blocked bypass"

### References
- [Official Hooks Guide](https://code.claude.com/docs/en/hooks-guide) - Canonical documentation for hook configuration and patterns
- [Official Hooks Reference](https://code.claude.com/docs/en/hooks) - Full event schemas, JSON formats, exit code semantics
- [Official Permissions Reference](https://code.claude.com/docs/en/permissions) - Permission rule syntax, allow/deny interaction with hooks
- [GitHub Issue #4669](https://github.com/anthropics/claude-code/issues/4669) - permissionDecision deny ignored (CLOSED)
- [GitHub Issue #13214](https://github.com/anthropics/claude-code/issues/13214) - PreToolUse hooks bypassed when permission rule matches (CLOSED)
- [GitHub Issue #18312](https://github.com/anthropics/claude-code/issues/18312) - Hook permissionDecision ignored with allow list (CLOSED, dup of #13214)
- [GitHub Issue #24327](https://github.com/anthropics/claude-code/issues/24327) - Exit code 2 causes Claude to stop instead of retry
- [git-safe hook example](https://www.aihero.dev/this-hook-stops-claude-code-running-dangerous-git-commands) - Production-tested git command blocking pattern
- [Claude Code permissions guide](https://pasqualepillitteri.it/en/news/1832/claude-code-dangerously-skip-permissions-pretooluse-hooks-2026) - PreToolUse hooks with --dangerously-skip-permissions
