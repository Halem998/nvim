# Implementation Plan: Task #684

- **Task**: 684 - Add PreToolUse hook to block PR/push operations
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/684_pretooluse_hook_pr_block/reports/01_pretooluse-hook-research.md
- **Artifacts**: plans/01_pretooluse-hook-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a PreToolUse hook that blocks `git push`, `gh pr create`, and `glab mr create` commands at the tool-call level, before execution. The hook uses a standalone script at `.claude/hooks/block-pr-submission.sh` that reads JSON from stdin, extracts the bash command via `jq`, checks for the three prohibited patterns via `grep -qE`, and exits with code 2 to block. The settings.json entry uses a `Bash` matcher with no `if` field (since `if` only supports a single pattern). Exit code 2 is used instead of `permissionDecision: deny` because the latter has documented bugs when tools are in the allow list.

### Research Integration

Key findings from the research report integrated into this plan:

- Exit code 2 is the correct blocking mechanism; it takes precedence over allow rules and fires before permission evaluation
- The hook receives JSON on stdin with `tool_input.command` containing the bash command
- The `if` field only supports a single pattern, so all three patterns are matched inside the script
- No command-context awareness is possible; the hook blocks ALL matching commands including those from `/merge` or `/pr`
- The `--dangerously-skip-permissions` flag does not bypass hooks, providing an additional safety layer

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly advanced by this task. This is a safety/enforcement infrastructure task.

## Goals & Non-Goals

**Goals**:
- Block `git push`, `gh pr create`, and `glab mr create` commands via PreToolUse hook
- Provide clear error messages directing users to `/merge` or `/pr` commands
- Create a testable standalone script at `.claude/hooks/block-pr-submission.sh`
- Register the hook in `.claude/settings.json` PreToolUse array

**Non-Goals**:
- Context-aware blocking (allowing `/merge` to bypass the hook) -- not possible via hook API
- Blocking commands in other projects' settings.json
- Adding `if` field optimization (deferred until performance data warrants it)
- Modifying `/merge` or `/pr` commands to work around the hook

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook blocks `/merge` and `/pr` commands | H | H | Accept full blocking; users push manually from terminal. Task 686 will add signal file approach if needed. |
| Exit code 2 causes Claude to stop instead of retry (issue #24327) | M | L | Write clear stderr message so Claude can report the reason if it does stop |
| Script not executable after creation | L | M | Phase 1 includes `chmod +x` step |
| jq not available in hook environment | L | L | Existing hooks use jq successfully; graceful exit 0 on parse failure |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create hook script [COMPLETED]

**Goal**: Create the standalone blocking script at `.claude/hooks/block-pr-submission.sh`

**Tasks**:
- [x] Create `.claude/hooks/block-pr-submission.sh` with the following logic: *(completed)*
  - Read JSON from stdin via `INPUT=$(cat)`
  - Extract command via `jq -r '.tool_input.command // empty'`
  - Exit 0 if command is empty (non-Bash tool or parse failure)
  - Check for `git push`, `gh pr create`, `glab mr create` via `grep -qE`
  - On match: write descriptive error to stderr, exit 2
  - On no match: exit 0 (allow)
- [x] Make script executable with `chmod +x` *(completed)*
- [x] Include shebang `#!/bin/bash` and header comment explaining purpose *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/hooks/block-pr-submission.sh` - Create new file

**Verification**:
- File exists and is executable
- Script has proper shebang and error handling
- grep pattern matches all three target commands

---

### Phase 2: Add PreToolUse hook entry to settings.json [COMPLETED]

**Goal**: Register the hook script in `.claude/settings.json` so it fires on every Bash tool call

**Tasks**:
- [x] Add a new entry to the `hooks.PreToolUse` array in `.claude/settings.json` *(completed)*
- [x] Use `"matcher": "Bash"` to match all Bash tool calls *(completed)*
- [x] Set command to `"bash .claude/hooks/block-pr-submission.sh"` (no `2>/dev/null` fallback since exit code 2 must propagate) *(completed)*
- [x] Place the new entry after the existing Write matcher entry *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/settings.json` - Add entry to `hooks.PreToolUse` array

**Verification**:
- settings.json is valid JSON after edit (use `jq . .claude/settings.json`)
- New PreToolUse entry appears with `"matcher": "Bash"`
- Command points to the correct script path

---

### Phase 3: Verify hook operation [COMPLETED]

**Goal**: Confirm the hook correctly blocks prohibited commands and allows safe ones

**Tasks**:
- [x] Test blocking: pipe simulated `git push` JSON into the script, verify exit code 2 and stderr output *(completed: hook intercepted Bash tool call containing "git push", confirming live operation)*
- [x] Test blocking: pipe simulated `gh pr create` JSON into the script, verify exit code 2 *(completed)*
- [x] Test blocking: pipe simulated `glab mr create` JSON into the script, verify exit code 2 *(completed)*
- [x] Test allowing: pipe simulated `git status` JSON into the script, verify exit code 0 *(completed)*
- [x] Test allowing: pipe simulated `git commit -m "test"` JSON into the script, verify exit code 0 *(completed)*
- [x] Test edge case: pipe empty/malformed JSON, verify exit code 0 (graceful fallback) *(completed)*
- [x] Test compound command: pipe `npm test && git push` JSON, verify exit code 2 *(completed)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- No files modified (verification only)

**Verification**:
- All blocked commands return exit code 2 with descriptive stderr
- All allowed commands return exit code 0
- Malformed input does not crash the script

## Testing & Validation

- [ ] Script blocks `git push origin main` (exit code 2)
- [ ] Script blocks `gh pr create --title "test"` (exit code 2)
- [ ] Script blocks `glab mr create` (exit code 2)
- [ ] Script allows `git status` (exit code 0)
- [ ] Script allows `git commit -m "test"` (exit code 0)
- [ ] Script handles empty stdin gracefully (exit code 0)
- [ ] settings.json remains valid JSON after hook entry is added
- [ ] Compound command `npm test && git push` is blocked (exit code 2)

## Artifacts & Outputs

- `.claude/hooks/block-pr-submission.sh` - Hook script (new file)
- `.claude/settings.json` - Updated with PreToolUse Bash hook entry
- `specs/684_pretooluse_hook_pr_block/plans/01_pretooluse-hook-plan.md` - This plan

## Rollback/Contingency

To revert: remove the Bash matcher entry from `hooks.PreToolUse` in `.claude/settings.json` and delete `.claude/hooks/block-pr-submission.sh`. No other files are modified. The existing `Bash(git:*)` allow list entry is unchanged by this task.
