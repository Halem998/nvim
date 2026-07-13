# Research Report: Task #521

**Task**: 521 - Add model: opus to OpenCode command frontmatter
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: 1.5 hours
**Dependencies**: None
**Sources/Inputs**: Codebase grep, Read tool on command files and standards
**Artifacts**: - specs/521_add_model_opus_opencode_commands/reports/01_command-frontmatter-audit.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Zero commands** in `.opencode/commands/*.md` declare `model: opus` in YAML frontmatter
- **19 command files** are missing the field entirely
- **Agent frontmatter standard** explicitly requires `model: opus` for all agents, but commands lack equivalent enforcement
- **Command template** (`.opencode/context/templates/command-template.md`) does not include `model` in its frontmatter example
- **Creating-commands guide** mentions `model` as optional but does not set a default or recommend `opus`
- **Recommended approach**: Add `model: opus` to all 19 command files and update templates/guides to make it mandatory

## Context & Scope

Per `.opencode/docs/reference/standards/agent-frontmatter-standard.md`, all agents declare `model: opus` in their frontmatter to ensure highest reasoning quality. Commands are the user-facing entry points that route to skills and agents; they should follow the same standard. This audit checks all `.opencode/commands/*.md` files for missing `model: opus` frontmatter.

## Findings

### Commands Missing `model: opus`

All 19 `.opencode/commands/*.md` files are missing the `model` field in their YAML frontmatter:

| # | File | Frontmatter Lines | Has `model`? |
|---|------|------------------|-------------|
| 1 | `.opencode/commands/research.md` | 1-5 | NO |
| 2 | `.opencode/commands/plan.md` | 1-5 | NO |
| 3 | `.opencode/commands/implement.md` | 1-5 | NO |
| 4 | `.opencode/commands/review.md` | 1-5 | NO |
| 5 | `.opencode/commands/errors.md` | 1-5 | NO |
| 6 | `.opencode/commands/refresh.md` | 1-5 | NO |
| 7 | `.opencode/commands/todo.md` | 1-5 | NO |
| 8 | `.opencode/commands/meta.md` | 1-5 | NO |
| 9 | `.opencode/commands/revise.md` | 1-5 | NO |
| 10 | `.opencode/commands/merge.md` | 1-5 | NO |
| 11 | `.opencode/commands/project-overview.md` | 1-4 | NO |
| 12 | `.opencode/commands/spawn.md` | 1-5 | NO |
| 13 | `.opencode/commands/tag.md` | 1-4 | NO |
| 14 | `.opencode/commands/task.md` | 1-5 | NO |
| 15 | `.opencode/commands/learn.md` | 1-3 | NO |
| 16 | `.opencode/commands/distill.md` | 1-3 | NO |
| 17 | `.opencode/commands/fix-it.md` | 1-5 | NO |
| 18 | `.opencode/commands/README.md` | No frontmatter | N/A |

### Detailed Frontmatter Analysis

#### `.opencode/commands/research.md` (Lines 1-5)
```yaml
---
description: Research a task and create reports
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBERS [FOCUS] [--team [--team-size N]] [--fast|--hard] [--haiku|--sonnet|--opus]
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/plan.md` (Lines 1-5)
```yaml
---
description: Create implementation plan for a task
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBERS [--team [--team-size N]] [--fast|--hard] [--haiku|--sonnet|--opus]
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/implement.md` (Lines 1-5)
```yaml
---
description: Execute implementation with resume support
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBERS [--team [--team-size N]] [--force] [--fast|--hard] [--haiku|--sonnet|--opus]
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/review.md` (Lines 1-5)
```yaml
---
description: Review code and create analysis reports
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: "[SCOPE] [--create-tasks]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/errors.md` (Lines 1-5)
```yaml
---
description: Analyze errors and create fix plans
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate, Task
argument-hint: "[--fix TASK_NUMBER]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/refresh.md` (Lines 1-5)
```yaml
---
description: Manage Claude Code resources - terminate orphaned processes and clean up files
allowed-tools: Bash, Read, Glob, AskUserQuestion
argument-hint: "[--dry-run] [--force]"
---
```
**Recommended**: Add `model: opus` after `description` line (and also fix "Claude Code" -> "OpenCode" per Task 522).

#### `.opencode/commands/todo.md` (Lines 1-5)
```yaml
---
description: Archive completed and abandoned tasks
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(mv:*), Bash(mkdir:*), Bash(ls:*), Bash(find:*), Bash(jq:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: "[--dry-run]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/meta.md` (Lines 1-5)
```yaml
---
description: System builder for .opencode/ changes
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), TaskCreate, TaskUpdate
argument-hint: "[COMPONENT] [--preview]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/revise.md` (Lines 1-5)
```yaml
---
description: Revise implementation plan
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER [--expand]
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/merge.md` (Lines 1-5)
```yaml
---
description: Merge pull requests with platform detection
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "[PR_NUMBER] [--dry-run]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/project-overview.md` (Lines 1-4)
```yaml
---
description: Generate project overview and documentation
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/spawn.md` (Lines 1-5)
```yaml
---
description: Spawn child tasks for dependency resolution
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER [--recover]
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/tag.md` (Lines 1-4)
```yaml
---
description: Create and push semantic version tags
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/task.md` (Lines 1-5)
```yaml
---
description: Create and manage tasks
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, AskUserQuestion
argument-hint: "[DESCRIPTION] [--expand] [--recover] [--sync] [--abandon]"
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/learn.md` (Lines 1-3)
```yaml
---
description: Learn from text, files, directories, or task artifacts
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/distill.md` (Lines 1-3)
```yaml
---
description: Distill and maintain memory vault
---
```
**Recommended**: Add `model: opus` after `description` line.

#### `.opencode/commands/fix-it.md` (Lines 1-5)
```yaml
---
description: Scan for FIX:/NOTE:/TODO:/QUESTION: tags
allowed-tools: Read, Grep, Glob, Bash(git:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: "[PATH...]"
---
```
**Recommended**: Add `model: opus` after `description` line.

### Template and Standard References

#### `.opencode/context/templates/command-template.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 7-12 | Frontmatter example shows only `name` and `description` | Add `model: opus` to the frontmatter example |

**Current**:
```yaml
---
name: {command_name}
description: "{Brief description}"
---
```

**Recommended**:
```yaml
---
name: {command_name}
description: "{Brief description}"
model: opus
---
```

#### `.opencode/docs/guides/creating-commands.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 47-61 | Frontmatter table shows `model` as "No" (optional) | Change to "Yes" (required) and add recommendation |
| 60 | `model | No | Preferred model (opus, sonnet, or omit for default)` | `model | Yes | Preferred model: opus (all commands)` |

**Current table**:
```
| Field | Required | Purpose |
|-------|----------|---------|
| description | Yes | One-line summary |
| allowed-tools | Yes | Scoped tool allowlist |
| argument-hint | Yes | Usage hint |
| model | No | Preferred model (opus, sonnet, or omit for default) |
```

**Recommended table**:
```
| Field | Required | Purpose |
|-------|----------|---------|
| description | Yes | One-line summary |
| allowed-tools | Yes | Scoped tool allowlist |
| argument-hint | Yes | Usage hint |
| model | Yes | Preferred model: opus (all commands use opus) |
```

#### `.opencode/docs/reference/standards/agent-frontmatter-standard.md`
This standard already mandates `model: opus` for agents (lines 44, 59, 175). It does not explicitly mention commands. A cross-reference should be added.

**Recommended addition** (after line 175):
```markdown
### Commands
All command files in `.opencode/commands/` must also declare `model: opus` in their frontmatter to ensure consistent reasoning quality at the entry point level.
```

## Decisions

- **Decision 1**: All 17 command files with YAML frontmatter must have `model: opus` added.
- **Decision 2**: `README.md` has no frontmatter; it is documentation only and does not need `model`.
- **Decision 3**: The command template must be updated to include `model: opus` as a required field.
- **Decision 4**: The creating-commands guide must be updated to mandate `model: opus` rather than making it optional.
- **Decision 5**: Extension command mirrors (`.opencode/extensions/core/commands/*.md`) must also be updated.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Adding `model: opus` to commands conflicts with orchestrator routing | Verify that the orchestrator does not use command frontmatter for model selection (it uses agent frontmatter) |
| Some commands may benefit from lighter models | Document that `model: opus` is the default; runtime flags (`--fast`, `--haiku`) can override at execution time |
| Extension files get out of sync | Update extension mirrors in same commit |

## Context Extension Recommendations

- **Topic**: Command frontmatter standard
- **Gap**: No dedicated standard document for command frontmatter (only agent frontmatter standard exists)
- **Recommendation**: Create `.opencode/docs/reference/standards/command-frontmatter-standard.md` mirroring the agent standard

## Appendix

### Search Queries Used
```bash
grep "^---$" .opencode/commands/*.md
grep "model:" .opencode/commands/*.md
grep "model:" .opencode/context/templates/command-template.md
grep "model" .opencode/docs/guides/creating-commands.md
```

### Extension Mirrors Requiring Updates
- `.opencode/extensions/core/commands/research.md`
- `.opencode/extensions/core/commands/plan.md`
- `.opencode/extensions/core/commands/implement.md`
- `.opencode/extensions/core/commands/refresh.md`
- `.opencode/extensions/core/commands/todo.md`
- `.opencode/extensions/core/commands/errors.md`
- `.opencode/extensions/core/commands/review.md`
- `.opencode/extensions/core/commands/revise.md`
- `.opencode/extensions/core/commands/merge.md`
- `.opencode/extensions/core/commands/project-overview.md`
- `.opencode/extensions/core/commands/spawn.md`
- `.opencode/extensions/core/commands/tag.md`
- `.opencode/extensions/core/commands/task.md`
- `.opencode/extensions/core/commands/learn.md`
- `.opencode/extensions/core/commands/distill.md`
- `.opencode/extensions/core/commands/fix-it.md`
- `.opencode/extensions/core/commands/meta.md`
