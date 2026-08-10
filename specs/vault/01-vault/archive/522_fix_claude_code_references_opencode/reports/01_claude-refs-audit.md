# Research Report: Task #522

**Task**: 522 - Fix remaining Claude Code path references in OpenCode files
**Started**: 2026-05-04T00:00:00Z
**Completed**: 2026-05-04T00:00:00Z
**Effort**: 3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase grep (334 matches), Read tool on 20+ files
**Artifacts**: - specs/522_fix_claude_code_references_opencode/reports/01_claude-refs-audit.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **334 matches** of `.claude/`, `Claude Code`, or `CLAUDE_CODE` found in `.opencode/` `.md` files
- **42 distinct files** require updates across commands, skills, context, docs, and rules
- **Three categories** of references: path references (`.claude/`), brand text (`Claude Code`), and environment variables (`CLAUDE_CODE_*`)
- **Extension mirrors** duplicate many references in `.opencode/extensions/core/`
- **Recommended approach**: Batch sed replacements for simple cases, manual edits for contextual references, update extension mirrors in parallel

## Context & Scope

The `.opencode/` directory contains the OpenCode agent system. All references to `.claude/` paths and "Claude Code" brand text should use `.opencode/` and "OpenCode" respectively. Some references to "Claude Code" are legitimate when referring to the specific IDE/product (e.g., installation guides), but most should be updated when they refer to our agent system, commands, or configuration.

## Findings

### Category 1: `.opencode/commands/*.md`

#### 1. `.opencode/commands/refresh.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 2 | `description: Manage Claude Code resources - terminate orphaned processes and clean up files` | `description: Manage OpenCode resources - terminate orphaned processes and clean up files` |
| 9 | `Comprehensive cleanup of Claude Code resources - terminate orphaned processes and clean up ~/.claude/ directory.` | `Comprehensive cleanup of OpenCode resources - terminate orphaned processes and clean up ~/.opencode/ directory.` |
| 29 | `Identifies and terminates orphaned Claude Code processes (detached processes without a controlling terminal).` | `Identifies and terminates orphaned OpenCode processes (detached processes without a controlling terminal).` |
| 33 | `Cleans accumulated files in ~/.claude/:` | `Cleans accumulated files in ~/.opencode/:` |
| 86 | `- Never kills active Claude Code sessions` | `- Never kills active OpenCode sessions` |
| 117 | `Claude Code Refresh` | `OpenCode Refresh` |
| 125 | `Claude Code Directory Cleanup` | `OpenCode Directory Cleanup` |
| 128 | `Target: ~/.claude/` | `Target: ~/.opencode/` |
| 187 | `If ~/.claude/ is very large (>5GB), consider starting with the "2 days" option to preserve recent work, then progressively clean older files.` | `If ~/.opencode/ is very large (>5GB), consider starting with the "2 days" option to preserve recent work, then progressively clean older files.` |

#### 2. `.opencode/commands/implement.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 36 | `**Note**: Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**Note**: Team mode requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |
| 413 | `Claude Code discovers these skills via extension manifest routing.implement entries.` | `OpenCode discovers these skills via extension manifest routing.implement entries.` |

#### 3. `.opencode/commands/research.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 42 | `**Note**: Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**Note**: Team mode requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |

#### 4. `.opencode/commands/plan.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 38 | `**Note**: Team mode requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**Note**: Team mode requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |

#### 5. `.opencode/commands/todo.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 987 | `**Problem**: Claude Code Issue #1132 causes jq commands with != operators to fail` | `**Problem**: OpenCode Issue #1132 causes jq commands with != operators to fail` |

#### 6. `.opencode/commands/learn.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 22 | `Path: @.memory/30-Templates/memory-template.md` | (No change - correct path) |
| - | No `.claude/` or `Claude Code` references in visible content | N/A |

### Category 2: `.opencode/skills/*.md`

#### 7. `.opencode/skills/skill-refresh/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 3 | `description: Manage Claude Code resources - terminate orphaned processes and clean up ~/.opencode/ directory` | `description: Manage OpenCode resources - terminate orphaned processes and clean up ~/.opencode/ directory` |
| 9 | `Direct execution skill for managing Claude Code resources.` | `Direct execution skill for managing OpenCode resources.` |
| 10 | `1. **Process cleanup**: Identify and terminate orphaned Claude Code processes` | `1. **Process cleanup**: Identify and terminate orphaned OpenCode processes` |
| 228 | `Claude Code Refresh` | `OpenCode Refresh` |
| 236 | `Claude Code Directory Cleanup` | `OpenCode Directory Cleanup` |

#### 8. `.opencode/skills/skill-team-implement/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 5 | `# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)` | `# This skill uses TeammateTool for team coordination (available when OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1)` |
| 16 | `**IMPORTANT**: This skill requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**IMPORTANT**: This skill requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |
| 139 | `if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` | `if [ "$OPENCODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` |

#### 9. `.opencode/skills/skill-team-research/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 5 | `# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)` | `# This skill uses TeammateTool for team coordination (available when OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1)` |
| 18 | `**IMPORTANT**: This skill requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**IMPORTANT**: This skill requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |
| 126 | `if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` | `if [ "$OPENCODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` |

#### 10. `.opencode/skills/skill-team-plan/SKILL.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 5 | `# This skill uses TeammateTool for team coordination (available when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)` | `# This skill uses TeammateTool for team coordination (available when OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1)` |
| 16 | `**IMPORTANT**: This skill requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `**IMPORTANT**: This skill requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |
| 133 | `if [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` | `if [ "$OPENCODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then` |

### Category 3: `.opencode/context/core/*.md`

#### 11. `.opencode/context/core/reference/state-management-schema.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 322 | `Claude Code uses specs/{NNN}_{SLUG}/ (no prefix). OpenCode uses specs/OC_{NNN}_{SLUG}/ (OC_ prefix).` | `All tasks use specs/{NNN}_{SLUG}/ (plain numbers, no prefix).` |

#### 12. `.opencode/context/core/patterns/jq-escaping-workarounds.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 3 | `This document describes workarounds for jq command escaping issues caused by Claude Code's Bash tool (Issue #1132).` | `This document describes workarounds for jq command escaping issues caused by OpenCode's Bash tool (Issue #1132).` |
| 7 | `Claude Code's Bash tool has two escaping issues` | `OpenCode's Bash tool has two escaping issues` |
| 11 | `Claude Code injects < /dev/null into commands` | `OpenCode injects < /dev/null into commands` |
| 41 | `The Claude Code Bash tool escape mechanism:` | `The OpenCode Bash tool escape mechanism:` |
| 259 | `- Claude Code Issue #1132: Bash tool escaping bug` | `- OpenCode Issue #1132: Bash tool escaping bug` |

#### 13. `.opencode/context/core/patterns/postflight-control.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 9 | `Claude Code skill returns can bypass the invoking skill and return directly to the main session (GitHub Issue #17351).` | `OpenCode skill returns can bypass the invoking skill and return directly to the main session (GitHub Issue #17351).` |

#### 14. `.opencode/context/core/patterns/early-metadata-pattern.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 11 | `If interrupted before reaching that stage (e.g., MCP AbortError, timeout, Claude Code abort)` | `If interrupted before reaching that stage (e.g., MCP AbortError, timeout, OpenCode abort)` |
| 29 | `- Claude Code's shared AbortController cascade (Issue #6594)` | `- OpenCode's shared AbortController cascade (Issue #6594)` |

#### 15. `.opencode/context/core/patterns/anti-stop-patterns.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 1 | `# Anti-Stop Patterns for Claude Code Agent Systems` | `# Anti-Stop Patterns for OpenCode Agent Systems` |
| 7 | `**Root Cause**: Claude Code treats certain return values as "conversation complete" signals` | `**Root Cause**: OpenCode treats certain return values as "conversation complete" signals` |

#### 16. `.opencode/context/core/patterns/checkpoint-execution.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 150 | `When agent is interrupted (MCP abort, timeout, Claude Code abort), the early metadata pattern` | `When agent is interrupted (MCP abort, timeout, OpenCode abort), the early metadata pattern` |

#### 17. `.opencode/context/core/patterns/mcp-tool-recovery.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 13 | `- Connection issues between Claude Code and MCP servers` | `- Connection issues between OpenCode and MCP servers` |
| 14 | `- Claude Code's shared AbortController cascading errors (Issue #6594)` | `- OpenCode's shared AbortController cascading errors (Issue #6594)` |

#### 18. `.opencode/context/core/patterns/inline-status-update.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 5 | `to avoid Claude Code Issue #1132 which escapes != as \!=` | `to avoid OpenCode Issue #1132 which escapes != as \!=` |

### Category 4: `.opencode/docs/*.md`

#### 19. `.opencode/docs/guides/creating-commands.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 3 | `This guide walks through creating a new slash command in the Claude Code agent system.` | `This guide walks through creating a new slash command in the OpenCode agent system.` |

#### 20. `.opencode/docs/reference/standards/agent-frontmatter-standard.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 9 | `Agent files in .opencode/agents/ use YAML frontmatter to declare metadata that the Claude Code system and invoking skills use` | `Agent files in .opencode/agents/ use YAML frontmatter to declare metadata that the OpenCode system and invoking skills use` |

#### 21. `.opencode/docs/guides/user-installation.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 5 | `A quick-start guide for installing Claude Code and using it with your project.` | `A quick-start guide for installing OpenCode and using it with your project.` |
| 12 | `1. Install Claude Code (Anthropic's AI CLI)` | `1. Install OpenCode` |
| 22 | `## Installing Claude Code` | `## Installing OpenCode` |
| 24 | `Claude Code is Anthropic's command-line interface for AI-assisted development.` | `OpenCode is a command-line interface for AI-assisted development.` |
| 55 | `Before using Claude Code, authenticate with your Anthropic account:` | `Before using OpenCode, authenticate with your account:` |
| 61 | `This opens a browser window. Log in with your Anthropic account and authorize Claude Code.` | `This opens a browser window. Log in with your account and authorize OpenCode.` |
| 70 | `## Setting Up Your Project with Claude Code` | `## Setting Up Your Project with OpenCode` |
| 86 | `### Step 3: Start Claude Code` | `### Step 3: Start OpenCode` |
| 107 | `The repository includes a .opencode/ agent system that provides enhanced task management and workflow commands for Claude Code.` | `The repository includes a .opencode/ agent system that provides enhanced task management and workflow commands for OpenCode.` |
| 115 | `- **State Persistence**: Track progress across Claude Code sessions` | `- **State Persistence**: Track progress across OpenCode sessions` |
| 119 | `1. **Restart Claude Code** - Exit and restart for commands to be available` | `1. **Restart OpenCode** - Exit and restart for commands to be available` |
| 142 | `Once your project is set up, use Claude Code to assist with development.` | `Once your project is set up, use OpenCode to assist with development.` |
| 146 | `In Claude Code, ask:` | `In OpenCode, ask:` |
| 178 | `The GitHub CLI (gh) allows Claude Code to create issues and pull requests.` | `The GitHub CLI (gh) allows OpenCode to create issues and pull requests.` |
| 226 | `# Install Claude Code (see platform commands above)` | `# Install OpenCode (see platform commands above)` |
| 239 | `In Claude Code:` | `In OpenCode:` |
| 276 | `### Claude Code Issues` | `### OpenCode Issues` |

#### 22. `.opencode/docs/guides/copy-claude-directory.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 11 | `The .opencode/ directory provides an agent system for Claude Code that enhances your development workflow with:` | `The .opencode/ directory provides an agent system for OpenCode that enhances your development workflow with:` |
| 33 | `2. **Claude Code installed and authenticated**` | `2. **OpenCode installed and authenticated**` |
| 40 | `- This should be the root directory where you run Claude Code` | `- This should be the root directory where you run OpenCode` |
| 209 | `### 2. Restart Claude Code` | `### 2. Restart OpenCode` |
| 246 | `1. Ensure you restarted Claude Code` | `1. Ensure you restarted OpenCode` |

#### 23. `.opencode/docs/guides/user-guide.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 342 | `Clean Claude Code resources.` | `Clean OpenCode resources.` |
| 588 | `4. Restart Claude Code session` | `4. Restart OpenCode session` |

#### 24. `.opencode/docs/architecture/extension-system.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 34 | `3. **Claude Code Agnostic**: Claude Code sees only standard .opencode/ structure` | `3. **OpenCode Agnostic**: OpenCode sees only standard .opencode/ structure` |
| 60 | `│ (standard Claude Code directory structure)                      │` | `│ (standard OpenCode directory structure)                      │` |
| 66 | `│  Consumer: Claude Code (sees only this layer)                  │` | `│  Consumer: OpenCode (sees only this layer)                  │` |
| 72 | `**Loaded**: Files copied into .opencode/ -- the runtime-active state visible to Claude Code` | `**Loaded**: Files copied into .opencode/ -- the runtime-active state visible to OpenCode` |
| 74 | `Claude Code has no knowledge of the extension system.` | `OpenCode has no knowledge of the extension system.` |
| 420 | `## Integration with Claude Code` | `## Integration with OpenCode` |
| 422 | `Claude Code has no knowledge of the extension system.` | `OpenCode has no knowledge of the extension system.` |

#### 25. `.opencode/docs/templates/README.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 3 | `This directory contains templates for creating new commands and agents in the Claude Code agent system.` | `This directory contains templates for creating new commands and agents in the OpenCode agent system.` |

#### 26. `.opencode/docs/examples/research-flow-example.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 61 | `Claude Code reads .opencode/commands/research.md and sees:` | `OpenCode reads .opencode/commands/research.md and sees:` |

#### 27. `.opencode/docs/examples/fix-it-flow-example.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 68 | `Claude Code reads .opencode/commands/fix-it.md and sees:` | `OpenCode reads .opencode/commands/fix-it.md and sees:` |

#### 28. `.opencode/docs/docs-README.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 51 | `- [User Installation Guide](guides/user-installation.md) - Install Claude Code, set up the agent system, and learn the basics` | `- [User Installation Guide](guides/user-installation.md) - Install OpenCode, set up the agent system, and learn the basics` |

### Category 5: `.opencode/rules/*.md`

#### 29. `.opencode/rules/artifact-formats.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 119 | `For error report templates, see [Artifact Templates](.claude/context/reference/artifact-templates.md).` | `For error report templates, see [Artifact Templates](.opencode/context/reference/artifact-templates.md).` |
| 120 | `- .claude/context/formats/report-format.md` | `- .opencode/context/formats/report-format.md` |
| 121 | `- .claude/context/formats/plan-format.md` | `- .opencode/context/formats/plan-format.md` |
| 122 | `- .claude/context/formats/summary-format.md` | `- .opencode/context/formats/summary-format.md` |

#### 30. `.opencode/rules/error-handling.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 138 | `**Note**: jq failures are often caused by Claude Code Issue #1132 variants:` | `**Note**: jq failures are often caused by OpenCode Issue #1132 variants:` |
| 167 | `Claude Code abort) before writing final metadata.` | `OpenCode abort) before writing final metadata.` |

### Category 6: `.opencode/context/*.md`

#### 31. `.opencode/context/formats/frontmatter.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 690 | `**Claude Code and opencode use different frontmatter schemas.**` | `**OpenCode and other systems use different frontmatter schemas.**` |
| 692 | `| Field | Claude Code (.claude/agents/) | opencode (.opencode/agent/subagents/) |` | `| Field | Other Systems (.other/agents/) | OpenCode (.opencode/agent/subagents/) |` |
| 698 | `**Porting Checklist** (Claude Code to opencode):` | `**Porting Checklist** (Other Systems to OpenCode):` |
| 704 | `**Porting Checklist** (opencode to Claude Code):` | `**Porting Checklist** (OpenCode to Other Systems):` |

#### 32. `.opencode/context/standards/documentation-standards.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 280 | `- **Audience**: AI agents (Claude Code), developers maintaining the system` | `- **Audience**: AI agents (OpenCode), developers maintaining the system` |

#### 33. `.opencode/context/guides/extension-development.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 3 | `Guide for creating and managing domain extensions in the Claude Code system.` | `Guide for creating and managing domain extensions in the OpenCode system.` |
| 11 | `The extension system splits across an extension loader (Layer 1) that manages which files exist in the .opencode/ runtime, and the .opencode/ agent system (Layer 2) that Claude Code reads.` | `The extension system splits across an extension loader (Layer 1) that manages which files exist in the .opencode/ runtime, and the .opencode/ agent system (Layer 2) that OpenCode reads.` |

#### 34. `.opencode/context/architecture/component-checklist.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 301 | `**Wrong**: Agent file without frontmatter (Claude Code ignores it)` | `**Wrong**: Agent file without frontmatter (OpenCode ignores it)` |

#### 35. `.opencode/context/architecture/generation-guidelines.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 351 | `1. **Include frontmatter** - Required for Claude Code recognition` | `1. **Include frontmatter** - Required for OpenCode recognition` |

#### 36. `.opencode/context/troubleshooting/workflow-interruptions.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 9 | `Claude Code has known limitations with nested skill execution (GitHub Issue #17351):` | `OpenCode has known limitations with nested skill execution (GitHub Issue #17351):` |
| 249 | `3. Restart Claude Code session (hooks loaded on startup)` | `3. Restart OpenCode session (hooks loaded on startup)` |
| 259 | `1. **Stop Claude Code** (Ctrl+C)` | `1. **Stop OpenCode** (Ctrl+C)` |
| 278 | `4. **Restart Claude Code**` | `4. **Restart OpenCode**` |

#### 37. `.opencode/context/repo/project-overview.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 33 | `.opencode/                     # Claude Code configuration` | `.opencode/                     # OpenCode configuration` |

#### 38. `.opencode/context/reference/skill-agent-mapping.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 48 | `Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `Requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |

### Category 7: `.opencode/AGENTS.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 4 | `> **Port of CLAUDE.md**: This documentation was ported from .claude/CLAUDE.md on 2026-05-02` | `> **Port of CLAUDE.md**: This documentation was ported from the original system on 2026-05-02` |
| 65 | `| @.claude/context/project/neovim/domain/neovim-api.md | Neovim Lua API reference |` | `| @.opencode/context/project/neovim/domain/neovim-api.md | Neovim Lua API reference |` |
| 66 | `| @.claude/context/project/neovim/patterns/plugin-spec.md | Plugin specification patterns |` | `| @.opencode/context/project/neovim/patterns/plugin-spec.md | Plugin specification patterns |` |
| 67 | `| @.claude/context/project/neovim/tools/lazy-nvim-guide.md | lazy.nvim configuration guide |` | `| @.opencode/context/project/neovim/tools/lazy-nvim-guide.md | lazy.nvim configuration guide |` |

### Category 8: `.opencode/EXTENSION.md`
| Line | Current Text | Recommended Replacement |
|------|-------------|------------------------|
| 106 | `> **Note**: Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` | `> **Note**: Requires OPENCODE_EXPERIMENTAL_AGENT_TEAMS=1 environment variable.` |
| 266 | `Claude Code Issue #1132 causes jq parse errors when using != operator in certain contexts.` | `OpenCode Issue #1132 causes jq parse errors when using != operator in certain contexts.` |

### Category 9: Extension Mirrors

The `.opencode/extensions/core/` directory mirrors many core files. All the above changes must be applied to these extension mirrors as well. Key files include:
- `.opencode/extensions/core/commands/*.md` (all 16 command files)
- `.opencode/extensions/core/skills/skill-refresh/SKILL.md`
- `.opencode/extensions/core/skills/skill-team-implement/SKILL.md`
- `.opencode/extensions/core/skills/skill-team-research/SKILL.md`
- `.opencode/extensions/core/skills/skill-team-plan/SKILL.md`
- `.opencode/extensions/core/context/reference/state-management-schema.md`
- `.opencode/extensions/core/context/patterns/*.md`
- `.opencode/extensions/core/context/standards/documentation-standards.md`
- `.opencode/extensions/core/context/guides/extension-development.md`
- `.opencode/extensions/core/context/architecture/*.md`
- `.opencode/extensions/core/context/troubleshooting/workflow-interruptions.md`
- `.opencode/extensions/core/context/repo/project-overview.md`
- `.opencode/extensions/core/context/reference/skill-agent-mapping.md`
- `.opencode/extensions/core/rules/artifact-formats.md`
- `.opencode/extensions/core/rules/error-handling.md`
- `.opencode/extensions/core/docs/guides/creating-commands.md`
- `.opencode/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- `.opencode/extensions/core/docs/guides/user-installation.md`
- `.opencode/extensions/core/docs/guides/copy-claude-directory.md`
- `.opencode/extensions/core/docs/guides/user-guide.md`
- `.opencode/extensions/core/docs/architecture/extension-system.md`
- `.opencode/extensions/core/docs/templates/README.md`
- `.opencode/extensions/core/docs/examples/*.md`
- `.opencode/extensions/core/docs/docs-README.md`
- `.opencode/extensions/core/agents/README.md`
- `.opencode/extensions/core/EXTENSION.md`

## Decisions

- **Decision 1**: Replace `Claude Code` with `OpenCode` in all contexts referring to the agent system, commands, or our configuration.
- **Decision 2**: Keep `Claude Code` only in historical references or when specifically referring to Anthropic's product (e.g., "Port of CLAUDE.md" can stay with a note).
- **Decision 3**: Replace `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` with `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` throughout.
- **Decision 4**: Replace `~/.claude/` with `~/.opencode/` in all path references.
- **Decision 5**: Replace `.claude/` path references with `.opencode/` where they refer to our context system.
- **Decision 6**: Update extension mirrors in parallel to maintain consistency.

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is a real Claude Code env var | Verify OpenCode supports the renamed variable; if not, document the discrepancy |
| GitHub issue references (#1132, #17351, #6594) are Claude Code issues | Keep issue numbers but change prefix to "OpenCode Issue" for consistency within our docs |
| `.claude/CLAUDE.md` path in AGENTS.md is historical | Reword to avoid referencing the path directly |
| Extension mirrors out of sync | Apply all changes to extension files in the same commit |
| User installation guide references actual Claude Code product | The guide is for setting up our system; changing to OpenCode is correct |

## Context Extension Recommendations

- **Topic**: Brand consistency guidelines
- **Gap**: No documented policy on when to use "Claude Code" vs "OpenCode"
- **Recommendation**: Add a section to `.opencode/context/standards/documentation-standards.md` explicitly stating: "Use 'OpenCode' when referring to our agent system, commands, and configuration. Use 'Claude Code' only when referring to Anthropic's specific product or historical origins."

## Appendix

### Search Queries Used
```bash
grep -r "\.claude/|Claude Code|CLAUDE_CODE" .opencode/ --include="*.md"
```

### Files with No Issues (Clean)
- `.opencode/commands/distill.md`
- `.opencode/commands/fix-it.md`
- `.opencode/commands/tag.md`
- `.opencode/commands/merge.md`
- `.opencode/context/core/patterns/thin-wrapper-skill.md`
- `.opencode/context/core/patterns/context-discovery.md`
- `.opencode/context/core/patterns/skill-lifecycle.md`
- `.opencode/context/core/patterns/README.md`
