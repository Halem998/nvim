# Implementation Plan: Fix Remaining Claude Code Path References in OpenCode Files

- **Task**: 522 - Fix remaining Claude Code path references in OpenCode files
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/522_fix_claude_code_references_opencode/reports/01_claude-refs-audit.md
- **Artifacts**: plans/01_fix-refs-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace all `.claude/` path references, "Claude Code" brand text, and `CLAUDE_CODE_*` environment variable references in `.opencode/` markdown files with their OpenCode equivalents. The research identified 334 matches across 42 distinct files in 8 categories, plus extensive extension mirrors. This plan organizes replacements by category to ensure systematic and safe execution.

### Research Integration

The research report categorized all 334 matches into:
- **Path references**: `.claude/` -> `.opencode/`
- **Brand text**: `Claude Code` -> `OpenCode` (when referring to our system)
- **Environment variables**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- **Historical references**: Keep with rewording (e.g., "Port of CLAUDE.md")

Key findings:
- 42 distinct core files require updates
- Extension mirrors in `.opencode/extensions/core/` duplicate most references
- Some `Claude Code` references are legitimate (historical, product-specific) and must be preserved

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Replace all `.claude/` path references with `.opencode/` where referring to our system
- Replace all `Claude Code` brand text with `OpenCode` where referring to our agent system
- Replace `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` with `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`
- Replace `~/.claude/` with `~/.opencode/` in path references
- Update extension mirrors in parallel with core files
- Verify no broken references remain

**Non-Goals**:
- Change historical references like "Port of CLAUDE.md" (reword instead)
- Modify actual Claude Code product documentation (the user installation guide refers to our system, so it should be updated)
- Change issue numbers (#1132, #17351, #6594) - only change the prefix text
- Touch files outside `.opencode/` directory

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is real env var | High | Medium | Verify OpenCode supports renamed variable; document discrepancy if not |
| GitHub issue references misattributed | Low | Low | Keep issue numbers, only change prefix text to "OpenCode Issue" |
| `.claude/CLAUDE.md` historical path broken | Low | Low | Reword to avoid direct path reference |
| Extension mirrors out of sync | Medium | Medium | Apply all changes to extension files in same commit |
| Legitimate "Claude Code" references overwritten | Medium | Low | Manual review of each replacement; use categorized approach |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Pre-Flight and Safe Batch Replacements [COMPLETED]

**Goal**: Establish baseline and apply safe global replacements.

**Tasks**:
- [ ] Create backup branch: `git checkout -b task-522-fix-claude-refs`
- [ ] Run baseline count: `grep -r "\.claude/\|Claude Code\|CLAUDE_CODE" .opencode/ --include="*.md" | wc -l`
- [ ] **Safe batch 1 - Environment variables**: Replace `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` with `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` across all `.opencode/` `.md` files using sed
- [ ] **Safe batch 2 - Home directories**: Replace `~/.claude/` with `~/.opencode/` across all files
- [ ] **Safe batch 3 - Path references**: Replace `.claude/` with `.opencode/` where it refers to our context system (exclude legitimate external references)
- [ ] Verify batch replacements with grep and review for false positives

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- All `.opencode/` `.md` files with matching patterns

**Verification**:
- `grep -r "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" .opencode/ --include="*.md"` returns 0
- `grep -r "~/.claude/" .opencode/ --include="*.md"` returns 0
- Review `git diff` for batch replacements before proceeding

---

### Phase 2: Update Commands and Skills [COMPLETED]

**Goal**: Apply contextual brand text replacements to commands and skills.

**Tasks**:

**2.1 Commands** (contextual replacements, manual review required):
- [ ] `.opencode/commands/refresh.md` (lines 2, 9, 29, 33, 86, 117, 125, 128, 187)
  - `Manage Claude Code resources` -> `Manage OpenCode resources`
  - `orphaned Claude Code processes` -> `orphaned OpenCode processes`
  - `~/.claude/` -> `~/.opencode/` (already done in batch)
  - `active Claude Code sessions` -> `active OpenCode sessions`
  - `Claude Code Refresh` -> `OpenCode Refresh`
  - `Claude Code Directory Cleanup` -> `OpenCode Directory Cleanup`
- [ ] `.opencode/commands/implement.md` (lines 36, 413)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done in batch)
  - `Claude Code discovers` -> `OpenCode discovers`
- [ ] `.opencode/commands/research.md` (line 42)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)
- [ ] `.opencode/commands/plan.md` (line 38)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)
- [ ] `.opencode/commands/todo.md` (line 987)
  - `Claude Code Issue #1132` -> `OpenCode Issue #1132`

**2.2 Skills**:
- [ ] `.opencode/skills/skill-refresh/SKILL.md` (lines 3, 9, 10, 228, 236)
  - `Manage Claude Code resources` -> `Manage OpenCode resources`
  - `orphaned Claude Code processes` -> `orphaned OpenCode processes`
  - `Claude Code Refresh` -> `OpenCode Refresh`
  - `Claude Code Directory Cleanup` -> `OpenCode Directory Cleanup`
- [ ] `.opencode/skills/skill-team-implement/SKILL.md` (lines 5, 16, 139)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)
- [ ] `.opencode/skills/skill-team-research/SKILL.md` (lines 5, 18, 126)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)
- [ ] `.opencode/skills/skill-team-plan/SKILL.md` (lines 5, 16, 133)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.opencode/commands/refresh.md`
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`
- `.opencode/commands/todo.md`
- `.opencode/skills/skill-refresh/SKILL.md`
- `.opencode/skills/skill-team-implement/SKILL.md`
- `.opencode/skills/skill-team-research/SKILL.md`
- `.opencode/skills/skill-team-plan/SKILL.md`

**Verification**:
- `grep -r "Claude Code" .opencode/commands/ .opencode/skills/ --include="*.md"` reviewed for remaining matches

---

### Phase 3: Update Context, Docs, and Rules [COMPLETED]

**Goal**: Apply replacements to context patterns, documentation, and rules.

**Tasks**:

**3.1 Context Patterns and Standards**:
- [ ] `.opencode/context/core/reference/state-management-schema.md` (line 322)
  - Update directory convention statement
- [ ] `.opencode/context/core/patterns/jq-escaping-workarounds.md` (lines 3, 7, 11, 41, 259)
  - `Claude Code's Bash tool` -> `OpenCode's Bash tool`
  - `Claude Code injects` -> `OpenCode injects`
  - `Claude Code Issue #1132` -> `OpenCode Issue #1132`
- [ ] `.opencode/context/core/patterns/postflight-control.md` (line 9)
  - `Claude Code skill returns` -> `OpenCode skill returns`
- [ ] `.opencode/context/core/patterns/early-metadata-pattern.md` (lines 11, 29)
  - `Claude Code abort` -> `OpenCode abort`
  - `Claude Code's shared AbortController` -> `OpenCode's shared AbortController`
- [ ] `.opencode/context/core/patterns/anti-stop-patterns.md` (lines 1, 7)
  - `Claude Code Agent Systems` -> `OpenCode Agent Systems`
  - `Claude Code treats` -> `OpenCode treats`
- [ ] `.opencode/context/core/patterns/checkpoint-execution.md` (line 150)
  - `Claude Code abort` -> `OpenCode abort`
- [ ] `.opencode/context/core/patterns/mcp-tool-recovery.md` (lines 13, 14)
  - `Claude Code and MCP servers` -> `OpenCode and MCP servers`
  - `Claude Code's shared AbortController` -> `OpenCode's shared AbortController`
- [ ] `.opencode/context/core/patterns/inline-status-update.md` (line 5)
  - `Claude Code Issue #1132` -> `OpenCode Issue #1132`
- [ ] `.opencode/context/formats/frontmatter.md` (lines 690, 692, 698, 704)
  - `Claude Code and opencode` -> `OpenCode and other systems`
  - `Claude Code (.claude/agents/)` -> `Other Systems (.other/agents/)`
  - `Porting Checklist (Claude Code to opencode)` -> `Porting Checklist (Other Systems to OpenCode)`
- [ ] `.opencode/context/standards/documentation-standards.md` (line 280)
  - `AI agents (Claude Code)` -> `AI agents (OpenCode)`
- [ ] `.opencode/context/guides/extension-development.md` (lines 3, 11)
  - `Claude Code system` -> `OpenCode system`
  - `Claude Code reads` -> `OpenCode reads`
- [ ] `.opencode/context/architecture/component-checklist.md` (line 301)
  - `Claude Code ignores it` -> `OpenCode ignores it`
- [ ] `.opencode/context/architecture/generation-guidelines.md` (line 351)
  - `Required for Claude Code recognition` -> `Required for OpenCode recognition`
- [ ] `.opencode/context/troubleshooting/workflow-interruptions.md` (lines 9, 249, 259, 278)
  - `Claude Code has known limitations` -> `OpenCode has known limitations`
  - `Restart Claude Code session` -> `Restart OpenCode session`
  - `Stop Claude Code` -> `Stop OpenCode`
- [ ] `.opencode/context/repo/project-overview.md` (line 33)
  - `Claude Code configuration` -> `OpenCode configuration`
- [ ] `.opencode/context/reference/skill-agent-mapping.md` (line 48)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)

**3.2 Docs**:
- [ ] `.opencode/docs/guides/creating-commands.md` (line 3)
  - `Claude Code agent system` -> `OpenCode agent system`
- [ ] `.opencode/docs/reference/standards/agent-frontmatter-standard.md` (line 9)
  - `Claude Code system` -> `OpenCode system`
- [ ] `.opencode/docs/guides/user-installation.md` (lines 5, 12, 22, 24, 55, 61, 70, 86, 107, 115, 119, 142, 146, 178, 226, 239, 276)
  - `installing Claude Code` -> `installing OpenCode`
  - `Claude Code is Anthropic's` -> `OpenCode is a`
  - `Claude Code, authenticate` -> `OpenCode, authenticate`
  - `Start Claude Code` -> `Start OpenCode`
  - `Claude Code sessions` -> `OpenCode sessions`
  - `Restart Claude Code` -> `Restart OpenCode`
  - `In Claude Code` -> `In OpenCode`
  - `Claude Code Issues` -> `OpenCode Issues`
- [ ] `.opencode/docs/guides/copy-claude-directory.md` (lines 11, 33, 40, 209, 246)
  - `agent system for Claude Code` -> `agent system for OpenCode`
  - `Claude Code installed` -> `OpenCode installed`
  - `run Claude Code` -> `run OpenCode`
  - `Restart Claude Code` -> `Restart OpenCode`
- [ ] `.opencode/docs/guides/user-guide.md` (lines 342, 588)
  - `Clean Claude Code resources` -> `Clean OpenCode resources`
  - `Restart Claude Code session` -> `Restart OpenCode session`
- [ ] `.opencode/docs/architecture/extension-system.md` (lines 34, 60, 66, 72, 74, 420, 422)
  - `Claude Code Agnostic` -> `OpenCode Agnostic`
  - `standard Claude Code directory` -> `standard OpenCode directory`
  - `visible to Claude Code` -> `visible to OpenCode`
  - `Integration with Claude Code` -> `Integration with OpenCode`
- [ ] `.opencode/docs/templates/README.md` (line 3)
  - `Claude Code agent system` -> `OpenCode agent system`
- [ ] `.opencode/docs/examples/research-flow-example.md` (line 61)
  - `Claude Code reads` -> `OpenCode reads`
- [ ] `.opencode/docs/examples/fix-it-flow-example.md` (line 68)
  - `Claude Code reads` -> `OpenCode reads`
- [ ] `.opencode/docs/docs-README.md` (line 51)
  - `Install Claude Code` -> `Install OpenCode`

**3.3 Rules**:
- [ ] `.opencode/rules/artifact-formats.md` (lines 119-122)
  - `.claude/context/reference/` -> `.opencode/context/reference/`
  - `.claude/context/formats/` -> `.opencode/context/formats/`
- [ ] `.opencode/rules/error-handling.md` (lines 138, 167)
  - `Claude Code Issue #1132` -> `OpenCode Issue #1132`
  - `Claude Code abort` -> `OpenCode abort`

**3.4 Top-Level Files**:
- [ ] `.opencode/AGENTS.md` (lines 4, 65-67)
  - `ported from .claude/CLAUDE.md` -> `ported from the original system`
  - `.claude/context/project/neovim/` -> `.opencode/context/project/neovim/`
- [ ] `.opencode/EXTENSION.md` (lines 106, 266)
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` -> `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` (already done)
  - `Claude Code Issue #1132` -> `OpenCode Issue #1132`

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- All context, docs, rules, and top-level files listed above

**Verification**:
- `grep -r "Claude Code" .opencode/context/ .opencode/docs/ .opencode/rules/ .opencode/AGENTS.md .opencode/EXTENSION.md --include="*.md" | grep -v "extensions/core" | wc -l` should be near 0 (only legitimate historical references)

---

### Phase 4: Update Extension Mirrors [COMPLETED]

**Goal**: Apply identical changes to all `.opencode/extensions/core/` mirror files.

**Tasks**:
- [ ] `.opencode/extensions/core/commands/*.md` (all 16 command files)
  - Apply same replacements as core commands
- [ ] `.opencode/extensions/core/skills/skill-refresh/SKILL.md`
- [ ] `.opencode/extensions/core/skills/skill-team-implement/SKILL.md`
- [ ] `.opencode/extensions/core/skills/skill-team-research/SKILL.md`
- [ ] `.opencode/extensions/core/skills/skill-team-plan/SKILL.md`
- [ ] `.opencode/extensions/core/context/reference/state-management-schema.md`
- [ ] `.opencode/extensions/core/context/patterns/*.md` (all mirrored patterns)
- [ ] `.opencode/extensions/core/context/standards/documentation-standards.md`
- [ ] `.opencode/extensions/core/context/guides/extension-development.md`
- [ ] `.opencode/extensions/core/context/architecture/*.md`
- [ ] `.opencode/extensions/core/context/troubleshooting/workflow-interruptions.md`
- [ ] `.opencode/extensions/core/context/repo/project-overview.md`
- [ ] `.opencode/extensions/core/context/reference/skill-agent-mapping.md`
- [ ] `.opencode/extensions/core/rules/artifact-formats.md`
- [ ] `.opencode/extensions/core/rules/error-handling.md`
- [ ] `.opencode/extensions/core/docs/guides/creating-commands.md`
- [ ] `.opencode/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- [ ] `.opencode/extensions/core/docs/guides/user-installation.md`
- [ ] `.opencode/extensions/core/docs/guides/copy-claude-directory.md`
- [ ] `.opencode/extensions/core/docs/guides/user-guide.md`
- [ ] `.opencode/extensions/core/docs/architecture/extension-system.md`
- [ ] `.opencode/extensions/core/docs/templates/README.md`
- [ ] `.opencode/extensions/core/docs/examples/*.md`
- [ ] `.opencode/extensions/core/docs/docs-README.md`
- [ ] `.opencode/extensions/core/agents/README.md`
- [ ] `.opencode/extensions/core/EXTENSION.md`

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- All extension mirror files listed above

**Verification**:
- `grep -r "Claude Code" .opencode/extensions/ --include="*.md" | wc -l` should be near 0
- `grep -r "\.claude/" .opencode/extensions/ --include="*.md" | wc -l` should be 0

---

### Phase 5: Final Verification and Commit [COMPLETED]

**Goal**: Ensure minimal remaining references and commit changes.

**Tasks**:
- [ ] Run comprehensive grep: `grep -r "\.claude/\|Claude Code\|CLAUDE_CODE" .opencode/ --include="*.md" | wc -l`
- [ ] Review all remaining matches manually; legitimate ones should only be:
  - Historical port notes (e.g., "Port of CLAUDE.md")
  - Any true references to Anthropic's Claude Code product
- [ ] Run `git diff --stat` to review change scope
- [ ] Verify no `.claude/` path references remain
- [ ] Commit with message: `task 522: fix Claude Code references in OpenCode files`

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- None (verification and commit only)

**Verification**:
- Near-zero inappropriate `Claude Code` references
- Zero `.claude/` path references
- Zero `CLAUDE_CODE_` environment variable references
- Commit successful

## Testing & Validation

- [ ] Zero `.claude/` path references in `.opencode/` markdown files
- [ ] Zero `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` references
- [ ] Zero `~/.claude/` references
- [ ] All "Claude Code" -> "OpenCode" replacements are contextually correct
- [ ] Extension mirrors are consistent with core files
- [ ] Git diff reviewed for accidental changes
- [ ] Historical references preserved with appropriate rewording

## Artifacts & Outputs

- `specs/522_fix_claude_code_references_opencode/plans/01_fix-refs-plan.md` (this file)
- Git commit with all Claude Code reference fixes
- Minimal remaining legitimate references only

## Rollback/Contingency

If issues are discovered post-deployment:
1. Revert the commit: `git revert HEAD`
2. Restore from backup branch: `git checkout task-522-fix-claude-refs-backup`
3. If specific replacements caused issues, manually restore those files

## Replacement Rules Summary

| Category | Pattern | Replacement | Scope |
|----------|---------|-------------|-------|
| Environment variable | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` | All files |
| Home directory | `~/.claude/` | `~/.opencode/` | All files |
| Path reference | `.claude/context/` | `.opencode/context/` | All files |
| Path reference | `.claude/agents/` | `.opencode/agents/` | All files |
| Brand text | `Claude Code` | `OpenCode` | When referring to our system |
| Issue prefix | `Claude Code Issue #N` | `OpenCode Issue #N` | All files |
| Product description | `Claude Code is Anthropic's` | `OpenCode is a` | User installation guide |
| Historical | `ported from .claude/CLAUDE.md` | `ported from the original system` | AGENTS.md only |
| Bash tool | `Claude Code's Bash tool` | `OpenCode's Bash tool` | jq workarounds |
| Session | `Restart Claude Code` | `Restart OpenCode` | All guides |
| Process | `orphaned Claude Code processes` | `orphaned OpenCode processes` | refresh command/skill |
| Resources | `Claude Code resources` | `OpenCode resources` | refresh command |
| Limitations | `Claude Code has known limitations` | `OpenCode has known limitations` | troubleshooting |

## Files to Skip

The following files had no issues and require no changes:
- `.opencode/commands/distill.md`
- `.opencode/commands/fix-it.md`
- `.opencode/commands/tag.md`
- `.opencode/commands/merge.md`
- `.opencode/context/core/patterns/thin-wrapper-skill.md`
- `.opencode/context/core/patterns/context-discovery.md`
- `.opencode/context/core/patterns/skill-lifecycle.md`
- `.opencode/context/core/patterns/README.md`
