# Research Report: Task #687

**Task**: 687 - Create agent-level PR prohibition rule
**Started**: 2026-06-12T17:30:00Z
**Completed**: 2026-06-12T17:45:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of `.claude/rules/`, `.claude/agents/`, `.claude/skills/`, `.claude/CLAUDE.md`
**Artifacts**: specs/687_agent_pr_prohibition_rule/reports/01_pr-prohibition-research.md
**Standards**: report-format.md

## Executive Summary

- Rule files in `.claude/rules/` use YAML frontmatter with `paths:` for auto-application; no registration in `index.json` is needed
- For universal application, a `paths:` value of `["**/*"]` should be used, matching the broadest existing patterns
- The existing `git-workflow.md` rule prohibits `git push --force` but does NOT prohibit `git push` or PR creation, leaving a gap that this new rule fills
- A precedent for agent prohibitions exists in `skill-tag` (`user-only: true`) and meta-builder-agent (`FORBIDDEN` + `MUST NOT` sections)
- Full draft rule provided below

## Context & Scope

The task is to create a rule file that explicitly forbids all agents from creating PRs, pushing to remote, or invoking `/merge` autonomously. Currently, no rule comprehensively prevents these actions. The existing `git-workflow.md` only prohibits `git push --force` to main/master and destructive operations, but does not block regular `git push` or PR creation commands.

## Findings

### Rule File Format and Conventions

All rule files in `.claude/rules/` follow this structure:

1. **YAML Frontmatter**: Required. Contains a `paths:` field that determines when the rule is auto-applied by Claude Code.
2. **Heading**: `# Rule Name` immediately after frontmatter.
3. **Sections**: Organized by topic with `##` and `###` headings.
4. **Prohibition style**: Uses "Do Not" / "Never Run" / "MUST NOT" / "FORBIDDEN" language. The meta-builder-agent sets the strongest precedent with `**FORBIDDEN** - This agent MUST NOT:` followed by a bulleted list.

**Frontmatter format**:
```yaml
---
paths: ["specs/**/*", ".claude/**/*"]
---
```

The `paths:` value can be:
- A single string: `paths: specs/**/*`
- An array of globs: `paths: ["specs/**/*", ".claude/**/*"]`

### Path Pattern Analysis

Existing path patterns across all rule files:

| Rule | Path Pattern | Scope |
|------|-------------|-------|
| `artifact-formats.md` | `specs/**/*` | Specs directory only |
| `error-handling.md` | `.claude/**/*` | Agent system only |
| `git-workflow.md` | `["specs/**/*", ".claude/**/*"]` | Specs + agent system |
| `neovim-lua.md` | (no frontmatter) | Lua files only |
| `nix.md` | `["**/*.nix"]` | Nix files only |
| `plan-format-enforcement.md` | `specs/**/plans/**` | Plan files only |
| `project-overview-detection.md` | `.claude/context/repo/project-overview.md` | Single file |
| `state-management.md` | `specs/**/*` | Specs directory only |
| `workflows.md` | `.claude/**/*` | Agent system only |

For the PR prohibition rule, the path pattern `**/*` achieves universal application. Claude Code auto-applies rules whose `paths:` glob matches the files being worked on. Since agents work across all file types, `**/*` ensures the rule is always active regardless of which files the agent touches.

An alternative is `["specs/**/*", ".claude/**/*", "lua/**/*", "**/*.nix"]` to match all commonly-edited path patterns, but `**/*` is simpler and more reliable since it catches edge cases.

### Rule Discovery Mechanism

Rules in `.claude/rules/` are auto-discovered by Claude Code:

1. **No registration needed**: Rules are NOT registered in `.claude/context/index.json`. The index only covers context files, not rules.
2. **Path-based auto-application**: Claude Code reads the `paths:` YAML frontmatter and applies the rule when editing/working with files matching those globs.
3. **Extension rules**: Extensions can add rules via `provides.rules` in their `manifest.json`, which copies rule files into `.claude/rules/` during extension loading.

### Existing Prohibition Patterns

**In `git-workflow.md`** (lines 77-81):
```markdown
### Never Run
- `git push --force` to main/master
- `git reset --hard` without explicit user request
- `git rebase -i` (interactive mode not supported)
- Any destructive operations without user confirmation
```

This prohibits `git push --force` but NOT regular `git push` or PR creation.

**In `skill-tag` SKILL.md** (frontmatter):
```yaml
user-only: true
```
With text: "This command is **user-only** - agents MUST NOT invoke it."

**In `meta-builder-agent.md`**:
```markdown
**FORBIDDEN** - This agent MUST NOT:
- Write to `.claude/` paths using Write or Edit tools
```

**In `CLAUDE.md`** (the generated file):
```markdown
**User-Only Skills**: Skills marked as "user-only" cannot be invoked by agents.
These are for human-controlled operations like deployment (`skill-tag`).
```

### Gap Analysis

The current rule set has no rule that:
1. Prohibits `gh pr create` or `glab mr create` by agents
2. Prohibits `git push` (non-force) by agents
3. Prohibits autonomous `/merge` invocation by agents

The `/merge` command itself does not have `user-only: true` in its frontmatter (unlike `/tag`), so there is no skill-level guard. The prohibition must come from a rule.

The `skill-orchestrate-hard` SKILL.md does reference the `/merge` flow correctly, printing: `"Task $task_number is PR READY -- use /merge to submit the pull request."` This confirms agents are expected to STOP at `[PR READY]` status and let the user invoke `/merge`.

### Recommendations

**File path**: `.claude/rules/pr-prohibition.md`

**Path pattern**: `**/*` (universal application)

**Content structure**:
1. YAML frontmatter with `paths: "**/*"`
2. Title heading
3. Scope statement
4. Three prohibition sections (PR creation, pushing, /merge invocation)
5. What agents SHOULD do instead (mark task as `[PR READY]`)
6. Rationale section

**Relationship to existing rules**: This rule complements `git-workflow.md` which covers commit conventions and destructive operation guards. The PR prohibition rule is a separate concern (agent autonomy boundaries) and warrants its own file rather than being appended to `git-workflow.md`.

## Draft Rule Content

```markdown
---
paths: "**/*"
---

# PR and Push Prohibition

## Scope

This rule applies to ALL agents, skills, and automated operations. Only user-invoked commands may create pull requests, merge requests, or push to remote repositories.

## Prohibited Operations

### 1. Pull Request / Merge Request Creation

Agents MUST NOT create pull requests or merge requests via any method:

- `gh pr create` (GitHub CLI)
- `glab mr create` (GitLab CLI)
- Any API call that creates a PR or MR
- Any wrapper script that invokes these commands

### 2. Pushing to Remote Repositories

Agents MUST NOT push commits or branches to remote repositories:

- `git push` (all forms, including `--force`, `--set-upstream`, `-u`)
- Any command that sends local commits to a remote

### 3. Autonomous /merge Invocation

Agents MUST NOT invoke the `/merge` command. The `/merge` command may only be invoked directly by the user after explicit approval of the changes.

## Required Behavior

When implementation is complete, agents MUST:

1. Mark the task status as `[PR READY]`
2. Report to the user that changes are ready for review
3. Wait for the user to invoke `/merge` or manually create the PR

## Rationale

Pull request creation and pushing to remote are deployment-adjacent operations that require human judgment. Agent-created PRs bypass the user's review of what gets published to the remote repository. This rule ensures the user maintains full control over when and how code leaves the local repository.
```

## Decisions

- **Separate file**: Create a new rule file rather than appending to `git-workflow.md`, because the PR prohibition is about agent autonomy boundaries (a different concern from commit conventions).
- **Universal path pattern**: Use `**/*` rather than a list of specific path patterns, ensuring the rule applies regardless of what files agents are editing.
- **String format**: Use `paths: "**/*"` (single string) rather than array, consistent with simpler rules like `state-management.md`.
- **No index registration**: Rules are auto-discovered from `.claude/rules/` via `paths:` frontmatter; no `index.json` entry is needed.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Rule not applied if no files match `**/*` | Low | Claude Code applies rules when any file in the repo is being worked on; `**/*` matches everything |
| Agents ignore the rule text | Medium | Rules in `.claude/rules/` are injected into agent context automatically; strong MUST NOT language follows established precedent |
| `/merge` command lacks `user-only: true` guard | Medium | Consider adding `user-only: true` to the `/merge` command frontmatter as a belt-and-suspenders approach (separate task) |
| Overly broad `**/*` pattern causes performance issues | Very Low | Rule file is small (~40 lines); no performance impact from broad matching |

## Context Extension Recommendations

- **Topic**: Agent autonomy boundaries
- **Gap**: No centralized documentation of which operations are user-only vs. agent-permitted
- **Recommendation**: Consider a context file at `.claude/context/reference/agent-permission-boundaries.md` documenting all user-only operations in one place

## Appendix

### Files Examined
- `.claude/rules/artifact-formats.md` - Frontmatter format reference
- `.claude/rules/error-handling.md` - Frontmatter format reference
- `.claude/rules/git-workflow.md` - Closest existing rule (git operations)
- `.claude/rules/neovim-lua.md` - Alternative format (no frontmatter)
- `.claude/rules/nix.md` - Array paths format reference
- `.claude/rules/plan-format-enforcement.md` - Specific path pattern reference
- `.claude/rules/project-overview-detection.md` - Single-file path reference
- `.claude/rules/state-management.md` - Single string path reference
- `.claude/rules/workflows.md` - Command lifecycle reference
- `.claude/agents/general-implementation-agent.md` - Agent structure/prohibition patterns
- `.claude/agents/general-research-agent.md` - Agent structure reference
- `.claude/agents/meta-builder-agent.md` - FORBIDDEN pattern precedent
- `.claude/skills/skill-tag/SKILL.md` - user-only pattern reference
- `.claude/skills/skill-orchestrate-hard/SKILL.md` - PR READY flow reference
- `.claude/commands/merge.md` - /merge command definition
- `.claude/context/index.json` - Verified rules are not registered here
