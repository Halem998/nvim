# Research Report: Task #685

**Task**: 685 - Restrict Bash(git:*) permissions to exclude git push
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, Claude Code official documentation, community guides
**Artifacts**: specs/685_restrict_git_push_permissions/reports/01_git-permissions-research.md
**Standards**: report-format.md

## Executive Summary

- The current `Bash(git:*)` permission allows all git commands including `git push`, which can deploy code or push changes without user approval
- Claude Code supports a simple deny-override pattern: keep `Bash(git:*)` in allow, add `Bash(git push *)` to deny -- deny rules take absolute precedence over allow rules
- An alternative approach enumerates every needed git subcommand individually, but the deny-override approach is simpler, less error-prone, and self-maintaining
- `git push` is used in three places: `/merge` (user-invoked PR workflow), `/tag` (user-only deployment), and cslib `/pr` extension -- all three are user-initiated commands where a permission prompt is appropriate
- The change must be applied in TWO files: project-level `.claude/settings.json` and user-level `~/.claude/settings.json`, both of which contain `Bash(git:*)`

## Context & Scope

The task is to prevent autonomous `git push` execution by Claude Code agents. Currently, `Bash(git:*)` in the allow list permits all git operations without a permission prompt. The goal is to ensure `git push` always triggers a permission prompt so the user can review and approve before code leaves the local repository.

## Findings

### 1. Permission Format and Matching Semantics

Claude Code permissions use the format `Tool(specifier)` with the following rules:

| Format | Matches | Notes |
|--------|---------|-------|
| `Bash(git:*)` | `git`, `git add`, `git commit -m "msg"`, etc. | Legacy colon prefix format; word boundary enforced (won't match `gitx`) |
| `Bash(git *)` | `git add`, `git commit -m "msg"`, etc. | Modern space format; trailing `*` makes the wildcard optional, so also matches bare `git` |
| `Bash(git push *)` | `git push`, `git push origin main`, `git push -u origin HEAD` | Matches any command starting with `git push` |

**Key rule**: Deny takes absolute precedence. Evaluation order is: **deny > ask > allow > defaultMode fallback**. First match wins within each tier. A deny rule for `Bash(git push *)` will block `git push` even if `Bash(git:*)` is in allow.

### 2. Complete Inventory of Git Subcommands Used

#### Tier 1: Directly executed in scripts/hooks (must be auto-allowed)

| Subcommand | Usage Location | Purpose |
|------------|---------------|---------|
| `git add` | orchestrator-postflight.sh, skill-base.sh | Stage files for commit |
| `git commit` | orchestrator-postflight.sh | Create commits |
| `git rev-parse` | migrate-directory-padding.sh, verify-lean-mcp.sh, setup-lean-mcp.sh | Find repo root, get commit SHAs |

#### Tier 2: Used in skill/command/agent instructions (must be auto-allowed)

| Subcommand | Usage Location | Purpose |
|------------|---------------|---------|
| `git add` | All skills/commands (commit stages) | Stage files |
| `git commit` | All skills/commands (commit stages) | Create commits |
| `git status` | skill-tag, git-workflow, troubleshooting | Verify working tree state |
| `git diff` | git-workflow rules, troubleshooting | Review changes |
| `git log` | skill-tag, git-workflow | View commit history |
| `git rev-parse` | skill-tag, merge command | Get branch/commit info |
| `git branch` | merge command | Show current branch |
| `git fetch` | skill-tag | Sync remote refs |
| `git remote` | merge command | Get remote URL |
| `git describe` | skill-tag | Get latest tag |
| `git rev-list` | skill-tag | Count commits |
| `git tag` | skill-tag | Create/list tags |
| `git blame` | state-management rules | Resolve sync conflicts |

#### Tier 3: Used in safety/recovery patterns (should be auto-allowed)

| Subcommand | Usage Location | Purpose |
|------------|---------------|---------|
| `git reset` | git-safety.md (rollback pattern) | Revert to safety commit |
| `git clean` | git-safety.md (rollback pattern) | Remove untracked files after rollback |
| `git reflog` | git-safety.md (recovery docs) | Find lost commits |
| `git checkout` | troubleshooting (recovery) | Restore files |

#### Tier 4: Used in merge/rebase workflows (should be auto-allowed)

| Subcommand | Usage Location | Purpose |
|------------|---------------|---------|
| `git merge` | merge command (conflict resolution docs) | Merge branches |
| `git rebase` | merge command (conflict resolution docs) | Rebase branches |
| `git pull` | tag skill (recovery docs) | Pull latest changes |

#### Tier 5: SHOULD REQUIRE PERMISSION PROMPT

| Subcommand | Usage Location | Purpose |
|------------|---------------|---------|
| `git push` | /merge, /tag, cslib /pr | Push commits/tags to remote |

### 3. Analysis of `git push` Usage

**`/merge` command** (`.claude/commands/merge.md` line 154):
- Runs `git push -u origin HEAD` to push branch before creating PR
- User-invoked command (user types `/merge`)
- A permission prompt here is APPROPRIATE -- user should approve pushing

**`/tag` skill** (`.claude/skills/skill-tag/SKILL.md` line 257):
- Runs `git push origin $new_version` to push a version tag
- Already marked as user-only (`skill-tag` cannot be invoked by agents)
- A permission prompt here is APPROPRIATE -- this triggers CI/CD deployment

**cslib `/pr` extension** (`.claude/extensions/cslib/commands/pr.md`):
- Uses `git push -u origin {branch_name}` and `git push origin main`
- Extension command, user-invoked
- A permission prompt here is APPROPRIATE

**`skill-git-workflow`** (`.claude/skills/skill-git-workflow/SKILL.md` line 106):
- Lists `git push --force` under "Never Run" -- this is a prohibition, not a usage
- This skill does NOT execute `git push`; it only runs `git add` and `git commit`

### 4. Recommended Approach: Deny Override

**Option A (RECOMMENDED): Add deny rule for git push**

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)"
    ],
    "deny": [
      "Bash(git push *)",
      "Bash(git push)"
    ]
  }
}
```

Advantages:
- Minimal change (2 lines added to deny list)
- Self-maintaining: new git subcommands auto-allowed without config changes
- Clear intent: explicitly blocks push while allowing everything else
- Matches documented Claude Code pattern from official community guides

Note: Both `Bash(git push *)` and `Bash(git push)` are needed. The `*` wildcard makes the trailing portion optional when it's the only wildcard, but `Bash(git push *)` with the space+wildcard pattern matches `git push` and `git push <anything>`. To be safe against edge cases, including both forms guarantees coverage. However, based on the documentation stating "if the pattern ends with `*` and contains only one wildcard, that trailing wildcard is optional," the single entry `Bash(git push *)` should suffice to match bare `git push` as well. Testing is recommended.

**Option B: Enumerated allow list (NOT recommended)**

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git rev-parse:*)",
      "Bash(git branch:*)",
      "Bash(git fetch:*)",
      "Bash(git remote:*)",
      "Bash(git describe:*)",
      "Bash(git rev-list:*)",
      "Bash(git tag:*)",
      "Bash(git blame:*)",
      "Bash(git reset:*)",
      "Bash(git clean:*)",
      "Bash(git reflog:*)",
      "Bash(git checkout:*)",
      "Bash(git merge:*)",
      "Bash(git rebase:*)",
      "Bash(git pull:*)",
      "Bash(git show:*)",
      "Bash(git stash:*)",
      "Bash(git ls-remote:*)",
      "Bash(git clone:*)",
      "Bash(git init:*)",
      "Bash(git config:*)",
      "Bash(git revert:*)"
    ]
  }
}
```

Disadvantages:
- 26+ entries instead of 1 allow + 1 deny
- Fragile: any new git subcommand used by the system triggers permission prompts until config updated
- Maintenance burden: must keep list synchronized with codebase evolution
- Easy to miss edge cases (e.g., `git -C /path status`)

### 5. Files Requiring Changes

| File | Current | Change Needed |
|------|---------|---------------|
| `.claude/settings.json` (project) | `Bash(git:*)` in allow, no git deny rules | Add `Bash(git push *)` to deny |
| `~/.claude/settings.json` (user) | `Bash(git:*)` in allow, no git deny rules | Add `Bash(git push *)` to deny |

**Important**: The user-level `~/.claude/settings.json` is managed by Home Manager (`~/.dotfiles/config/claude/settings.json`). The implementation should note that the user-level change needs to be applied at the Home Manager source, not directly to `~/.claude/settings.json`.

### 6. Format Consistency

The existing settings files use the colon format (`Bash(git:*)`). The deny rule should use the space format (`Bash(git push *)`) because:
- The colon format `Bash(git push:*)` would match `git push` followed by anything, which is correct
- However, community documentation examples consistently use space format for deny rules: `Bash(git push *)`
- Both formats should work, but the space format is more widely documented

Alternatively, for consistency with the existing `Bash(git:*)` in allow, the deny could use `Bash(git push:*)`. Both `Bash(git push *)` and `Bash(git push:*)` should match the same commands. The implementation should pick one format and verify.

## Decisions

1. **Approach**: Use deny-override (Option A), not enumerated allow list (Option B)
2. **Scope**: Both project-level and user-level settings need the deny rule
3. **Format**: Use `Bash(git push:*)` for consistency with existing colon-format entries, or `Bash(git push *)` following community convention -- implementation should test and confirm
4. **No workflow breakage**: All `git push` invocations are in user-initiated commands where a permission prompt is acceptable and desirable

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Deny format doesn't match all push variants | Low | Medium | Include both `Bash(git push *)` and `Bash(git push)` if testing reveals gaps |
| `/merge` workflow friction | Low | Low | User already initiates `/merge` manually; one extra approval click is acceptable |
| `/tag` workflow friction | Low | Low | Already user-only; explicit push approval adds safety for deployments |
| User-level settings overwritten by Home Manager rebuild | Medium | Medium | Document that the Home Manager source file also needs updating |
| Colon vs space format mismatch | Low | Low | Test the chosen format before committing; both are documented to work |
| `git push` in compound commands (e.g., `git push && echo done`) | Low | Low | The deny pattern matches command prefix; compound commands starting with `git push` will still be caught |

## Appendix

### Search Queries Used
- `grep -rn 'git push'` across `.claude/` directory tree
- `grep -rohn 'git [a-z-]*'` across all scripts, skills, commands, agents, hooks
- WebSearch: Claude Code settings.json permissions format
- WebFetch: Official Claude Code settings docs, community permission guides

### References
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
- [Claude Code Permissions Guide (ClaudeCodeLab)](https://claudecode-lab.com/en/blog/claude-code-permissions-guide/)
- [Claude Code Permissions: Deny Rules, Modes & Wildcards (wmedia.es)](https://wmedia.es/en/tips/claude-code-permissions-3-key-concepts)
- [Claude Code Permissions Blog (Vincent Qiao)](https://blog.vincentqiao.com/en/posts/claude-code-settings-permissions/)

### Implementation Recommendation

The minimal change is:

```json
"deny": [
  "Bash(git push:*)",
  "Bash(rm -rf /)",
  "Bash(rm -rf ~)",
  "Bash(sudo *)",
  "Bash(chmod 777 *)"
]
```

This adds one entry (`Bash(git push:*)`) to the existing deny list in `.claude/settings.json`. The same entry should be added to the user-level settings source at `~/.dotfiles/config/claude/settings.json` (Home Manager managed).
