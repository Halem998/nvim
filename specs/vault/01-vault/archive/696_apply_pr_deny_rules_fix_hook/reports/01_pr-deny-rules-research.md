# Research Report: Task #696

**Task**: 696 - Apply PR deny rules to settings.json and fix the block-pr-submission.sh hook
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:05:00Z
**Effort**: ~15 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (settings.json, block-pr-submission.sh, cslib settings.json)
**Artifacts**: specs/696_apply_pr_deny_rules_fix_hook/reports/01_pr-deny-rules-research.md
**Standards**: report-format.md

---

## Executive Summary

- The nvim `.claude/settings.json` is missing two `deny` entries (`Bash(gh pr create*)` and `Bash(gh pr merge*)`) that were already applied to the cslib project during the incident response
- The `block-pr-submission.sh` hook contains a git push block (lines 25-29) that must be removed — user explicitly wants push allowed
- The hook script is not registered in any PreToolUse hook in settings.json — it must be added with matcher `Bash`
- The `.claude/extensions/core/hooks/` directory does NOT exist, so no sync is needed
- All three changes are contained to two files: `settings.json` and `block-pr-submission.sh`

---

## Context & Scope

Tasks 684-685 created `block-pr-submission.sh` and were marked "completed" but the settings.json
changes were never actually applied to the nvim project. The `/orchestrate` command subsequently
submitted a PR to upstream leanprover/cslib without user approval. The user responded by applying
deny rules to the cslib project directly; this task back-fills those same protections into nvim.

The user's explicit policy: **git push is ALLOWED, gh pr create and glab mr create are BLOCKED**.

---

## Findings

### File 1: `.claude/settings.json` (nvim project)

**Path**: `/home/benjamin/.config/nvim/.claude/settings.json`

**Current `permissions.deny` array** (lines 29-35):
```json
"deny": [
  "Bash(rm -rf /)",
  "Bash(rm -rf ~)",
  "Bash(sudo *)",
  "Bash(chmod 777 *)"
]
```

**Missing entries** (present in cslib but not nvim):
- `"Bash(gh pr create*)"`
- `"Bash(gh pr merge*)"`

**Current `hooks.PreToolUse` array** (lines 37-47):
Only one entry, with matcher `Write`. The `block-pr-submission.sh` hook is not registered.

**Missing hook registration**:
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash .claude/hooks/block-pr-submission.sh 2>/dev/null || echo '{}'"
    }
  ]
}
```

### File 2: `.claude/hooks/block-pr-submission.sh`

**Path**: `/home/benjamin/.config/nvim/.claude/hooks/block-pr-submission.sh`

**Current git push block (lines 25-29)**:
```bash
if echo "$COMMAND" | grep -qE '(^|[;&|] *)git push( |$)'; then
  echo "BLOCKED: git push is not allowed directly." >&2
  echo "Use /merge (GitHub/GitLab) or /pr (CSLib) to push and create PRs." >&2
  exit 2
fi
```

This block must be **removed**. The user wants agents to be able to push branches.

The script header comment (line 3) also references "git push" and should be updated.

**Blocks to keep** (lines 30-39):
- `gh pr create` block (lines 30-34)
- `glab mr create` block (lines 35-39)

### File 3: `.claude/extensions/core/hooks/`

**Path**: `/home/benjamin/.config/.claude/extensions/core/hooks/`

This directory does **NOT exist**. No sync step needed.

### Reference: cslib settings.json

**Path**: `/home/benjamin/Projects/cslib/.claude/settings.json`

The cslib project already has the correct deny rules applied:
```json
"deny": [
  "Bash(rm -rf /)",
  "Bash(rm -rf ~)",
  "Bash(sudo *)",
  "Bash(chmod 777 *)",
  "Bash(gh pr create*)",
  "Bash(gh pr merge*)"
]
```

The nvim settings.json deny array should match these exactly (the last two entries are the additions).

The cslib project does NOT have the `block-pr-submission.sh` hook registered either — that is
only needed in nvim (the hook file lives in nvim's `.claude/hooks/`).

---

## Exact Changes Required

### Change 1: Add deny rules to `settings.json`

**File**: `/home/benjamin/.config/nvim/.claude/settings.json`
**JSON path**: `permissions.deny` array
**Action**: Append two entries after `"Bash(chmod 777 *)"` (currently line 34)

Replace:
```json
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ]
```

With:
```json
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)",
      "Bash(gh pr create*)",
      "Bash(gh pr merge*)"
    ]
```

### Change 2: Register hook in `settings.json`

**File**: `/home/benjamin/.config/nvim/.claude/settings.json`
**JSON path**: `hooks.PreToolUse` array
**Action**: Add a new entry (with matcher "Bash") as the FIRST entry in PreToolUse, before the existing "Write" matcher entry

The new PreToolUse array should be:
```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/block-pr-submission.sh 2>/dev/null || echo '{}'"
      }
    ]
  },
  {
    "matcher": "Write",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
      }
    ]
  }
]
```

Note: The hook uses `|| echo '{}'` for graceful degradation if the script fails.

### Change 3: Remove git push block from `block-pr-submission.sh`

**File**: `/home/benjamin/.config/nvim/.claude/hooks/block-pr-submission.sh`

**Remove lines 25-29** (the git push block):
```bash
if echo "$COMMAND" | grep -qE '(^|[;&|] *)git push( |$)'; then
  echo "BLOCKED: git push is not allowed directly." >&2
  echo "Use /merge (GitHub/GitLab) or /pr (CSLib) to push and create PRs." >&2
  exit 2
fi
```

**Also update the header comment** (line 3):

Old: `# PreToolUse hook: block git push, gh pr create, and glab mr create operations.`
New: `# PreToolUse hook: block gh pr create and glab mr create operations.`

**Also update the comment block** (lines 5-7):

Old:
```
# These operations require explicit user approval via the /merge command (GitHub PR
# or GitLab MR) or /pr command (CSLib PRs). The /merge and /pr commands include
# proper CI verification and user approval gates.
```

New:
```
# PR/MR creation requires explicit user approval via the /merge command (GitHub PR
# or GitLab MR) or /pr command (CSLib PRs). The /merge and /pr commands include
# proper CI verification and user approval gates.
# git push is allowed — agents may push branches, but not create PRs/MRs.
```

**Final file after changes** (for reference):
```bash
#!/bin/bash
# block-pr-submission.sh
# PreToolUse hook: block gh pr create and glab mr create operations.
#
# PR/MR creation requires explicit user approval via the /merge command (GitHub PR
# or GitLab MR) or /pr command (CSLib PRs). The /merge and /pr commands include
# proper CI verification and user approval gates.
# git push is allowed — agents may push branches, but not create PRs/MRs.
#
# Blocking mechanism: exit code 2 (takes precedence over allow rules, fires before
# permission evaluation). Does NOT use permissionDecision: deny due to documented
# bugs when tools are in the allow list (issues #4669, #13214, #18312).

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Allow through if command is empty (non-Bash tool or parse failure)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block actual PR creation commands.
# Match patterns that start a command or follow && ; | — not strings inside quotes/variables.
if echo "$COMMAND" | grep -qE '(^|[;&|] *)gh pr create'; then
  echo "BLOCKED: gh pr create is not allowed directly." >&2
  echo "Use /merge or /pr to create pull requests with proper approval." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '(^|[;&|] *)glab mr create'; then
  echo "BLOCKED: glab mr create is not allowed directly." >&2
  echo "Use /merge to create merge requests with proper approval." >&2
  exit 2
fi

exit 0
```

---

## Decisions

- **git push NOT added to deny list**: User explicitly wants agents to be able to push branches. Only PR/MR creation is blocked at the harness level.
- **Deny rules are defense-in-depth**: Both `permissions.deny` (harness-level block) AND the hook script (behavioral block) are used together for belt-and-suspenders protection.
- **Hook registered first in PreToolUse**: Placing the Bash matcher before the Write matcher ensures the hook fires for all Bash tool calls without ordering concerns.
- **No extensions/core/hooks sync needed**: The directory `/home/benjamin/.config/.claude/extensions/core/hooks/` does not exist; no sync step required.
- **`|| echo '{}'` is correct**: This makes the hook non-fatal if the script has a parse error or is missing — Claude Code interprets empty/invalid hook output as a pass-through.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Hook script fails silently | `|| echo '{}'` fallback ensures non-fatal failure |
| PreToolUse hook fires on every Bash call (performance) | Script exits 0 quickly for non-PR commands; acceptable overhead |
| `gh pr merge` not blocked by hook script | The deny rule in settings.json covers `gh pr merge*`; hook only blocks `gh pr create` and `glab mr create` (consistent with Tasks 684-685 scope) |
| cslib project still lacks block-pr-submission.sh hook registration | Out of scope for this task; cslib has deny rules which are sufficient |

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/settings.json` — nvim project settings (current state)
- `/home/benjamin/.config/nvim/.claude/hooks/block-pr-submission.sh` — hook script (current state)
- `/home/benjamin/Projects/cslib/.claude/settings.json` — reference: already has deny rules
- `/home/benjamin/.config/.claude/extensions/core/hooks/` — does not exist

### Key Observation: Dual Protection Strategy

The deny rules in `permissions.deny` and the hook script serve different but complementary roles:
- `permissions.deny` with `Bash(gh pr create*)`: harness-level block, cannot be bypassed by model behavior, fires before tool execution
- Hook script exit code 2: also fires before permission evaluation, blocks via behavioral signal
- Together they provide redundant protection with different failure modes
