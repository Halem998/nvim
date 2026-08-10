# Research Report: Task #203

**Task**: Remove OC_ prefix from .claude/ system task directory creation
**Date**: 2026-03-13
**Focus**: Identify all files using OC_ prefix in .claude/ system that need to be changed, compare with .opencode/ patterns, and document the distinction for preventing future confusion

## Summary

Task 194 incorrectly standardized the OC_ prefix across BOTH .claude/ and .opencode/ systems, when the OC_ prefix should only be used by .opencode/. The research identified 44 files in .claude/ that incorrectly reference OC_ prefixed paths and need to be reverted to plain `{NNN}_{SLUG}` format. The .opencode/ system (59 files) correctly uses OC_ and should remain unchanged.

## Root Cause

Task 194 ("standardize_opencode_task_naming_consistency") was intended to fix inconsistencies in the OpenCode task naming system. However, the implementation scope was too broad - it applied the OC_ prefix standardization to .claude/ files as well, creating confusion about system boundaries.

The evidence from state.json shows:
- Task 194 `claudemd_suggestions`: "Updated ... .claude/skills/*, .claude/agents/*, .claude/extensions/*, ... to use OC_ prefix"
- The stated goal was to standardize "OpenCode task naming" but the changes leaked into Claude Code configuration

## Findings

### Files Requiring Changes in .claude/

**Total: 44 files** containing `OC_` references that need to be reverted to plain `{NNN}_{SLUG}` format.

#### Core Agents (4 files)
| File | Change Type |
|------|-------------|
| `.claude/agents/general-implementation-agent.md` | mkdir patterns, metadata paths, example paths |
| `.claude/agents/general-research-agent.md` | mkdir patterns, metadata paths, example paths |
| `.claude/agents/planner-agent.md` | mkdir patterns, metadata paths, example paths |
| `.claude/agents/meta-builder-agent.md` | example task directory paths |

#### Core Skills (4 files)
| File | Change Type |
|------|-------------|
| `.claude/skills/skill-researcher/SKILL.md` | mkdir patterns, metadata file paths, postflight patterns |
| `.claude/skills/skill-planner/SKILL.md` | mkdir patterns, metadata file paths, postflight patterns |
| `.claude/skills/skill-implementer/SKILL.md` | mkdir patterns, metadata file paths, postflight patterns |
| `.claude/skills/skill-todo/SKILL.md` | directory scanning patterns, TODO entry patterns, CHANGE_LOG format |

#### Commands (3 files)
| File | Change Type |
|------|-------------|
| `.claude/commands/research.md` | Header display format |
| `.claude/commands/plan.md` | Header display format |
| `.claude/commands/implement.md` | Header display format |

#### Context/Core (10 files)
| File | Change Type |
|------|-------------|
| `.claude/context/core/formats/return-metadata-file.md` | mkdir patterns, path examples, relationship table |
| `.claude/context/core/formats/subagent-return.md` | path examples |
| `.claude/context/core/patterns/early-metadata-pattern.md` | mkdir patterns, path examples |
| `.claude/context/core/patterns/metadata-file-return.md` | path patterns |
| `.claude/context/core/patterns/file-metadata-exchange.md` | path patterns |
| `.claude/context/core/patterns/postflight-control.md` | directory patterns |
| `.claude/context/core/troubleshooting/workflow-interruptions.md` | path patterns |
| `.claude/context/core/architecture/component-checklist.md` | path patterns |
| `.claude/context/core/architecture/generation-guidelines.md` | path patterns |
| `.claude/context/core/standards/documentation.md` | path patterns |

#### Extension Agents (12 files)
| File | Change Type |
|------|-------------|
| `.claude/extensions/nvim/agents/neovim-implementation-agent.md` | mkdir patterns |
| `.claude/extensions/nvim/agents/neovim-research-agent.md` | mkdir patterns |
| `.claude/extensions/nix/agents/nix-implementation-agent.md` | mkdir patterns |
| `.claude/extensions/nix/agents/nix-research-agent.md` | mkdir patterns |
| `.claude/extensions/web/agents/web-implementation-agent.md` | mkdir patterns |
| `.claude/extensions/web/agents/web-research-agent.md` | mkdir patterns |
| `.claude/extensions/formal/agents/formal-research-agent.md` | mkdir patterns |
| `.claude/extensions/formal/agents/logic-research-agent.md` | mkdir patterns |
| `.claude/extensions/formal/agents/math-research-agent.md` | mkdir patterns |
| `.claude/extensions/formal/agents/physics-research-agent.md` | mkdir patterns |
| `.claude/extensions/filetypes/context/project/filetypes/tools/mcp-integration.md` | path patterns |
| (Additional extension agent files following same pattern) |

#### Extension Skills (11 files)
| File | Change Type |
|------|-------------|
| `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | mkdir patterns |
| `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` | mkdir patterns |
| `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` | mkdir patterns |
| `.claude/extensions/web/skills/skill-web-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` | mkdir patterns |
| `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/formal/skills/skill-formal-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/formal/skills/skill-logic-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/formal/skills/skill-math-research/SKILL.md` | mkdir patterns |
| `.claude/extensions/formal/skills/skill-physics-research/SKILL.md` | mkdir patterns |

### Files NOT Requiring Changes

#### .opencode/ System (59 files)
All 59 files in `.opencode/` correctly use OC_ prefix and should remain unchanged. These include:
- `.opencode/skills/*` - All skill definitions
- `.opencode/agent/subagents/*` - All agent definitions
- `.opencode/commands/*` - All command definitions
- `.opencode/extensions/*` - All extension files
- `.opencode/rules/*` - All rule files
- `.opencode/context/*` - All context files
- `.opencode/docs/*` - All documentation

#### Extension Files Using Plain Format
Some extensions (python, typst, z3, latex, lean) already use the correct plain `{N}_{SLUG}` format without OC_ prefix - these serve as correct reference implementations.

### Pattern Analysis

#### OC_ Usage Patterns Found in .claude/

1. **mkdir patterns**:
   ```bash
   mkdir -p "specs/OC_{NNN}_{SLUG}"           # INCORRECT
   mkdir -p "specs/${padded_num}_${task_slug}"  # Should be without OC_
   ```

2. **Path templates**:
   ```
   specs/OC_{NNN}_{SLUG}/.return-meta.json    # INCORRECT
   specs/{NNN}_{SLUG}/.return-meta.json        # CORRECT
   ```

3. **Header display**:
   ```
   [Researching] Task OC_{N}: {name}          # INCORRECT
   [Researching] Task {N}: {name}              # CORRECT
   ```

4. **Scanning patterns (skill-todo)**:
   ```bash
   for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do  # Handles both
   ```
   Note: skill-todo needs to handle BOTH formats during transition.

### Distinction Between Systems

| Aspect | .claude/ System | .opencode/ System |
|--------|-----------------|-------------------|
| Directory format | `specs/{NNN}_{SLUG}/` | `specs/OC_{NNN}_{SLUG}/` |
| Task headers | `Task {N}: {name}` | `Task OC_{N}: {name}` |
| TODO entries | `### {N}. {Title}` | `### OC_{N}. {Title}` |
| Primary tool | Claude Code | OpenCode |
| Configuration dir | `.claude/` | `.opencode/` |

## Recommendations

### 1. Change Categories by Priority

**Priority 1: Core Skills (Critical)**
These generate directories and affect all new task artifacts:
- skill-researcher/SKILL.md
- skill-planner/SKILL.md
- skill-implementer/SKILL.md

**Priority 2: Core Agents (Critical)**
These contain the actual mkdir commands and path construction:
- general-research-agent.md
- general-implementation-agent.md
- planner-agent.md
- meta-builder-agent.md

**Priority 3: Commands (High)**
These display task information to users:
- research.md
- plan.md
- implement.md

**Priority 4: Context/Documentation (Medium)**
These document patterns and examples:
- All files in context/core/

**Priority 5: Extension Files (Medium)**
These follow the same patterns but for specific domains:
- All extension agents and skills

**Priority 6: skill-todo (Special Handling)**
- Must handle BOTH directory formats during transition
- Update CHANGE_LOG format references
- Keep backward compatibility for existing OC_ directories

### 2. Documentation Update Locations

Add clarifying documentation to prevent future confusion:

1. **`.claude/CLAUDE.md` - Artifact Paths section**
   - Explicitly state "Claude Code uses plain `{NNN}_{SLUG}` format"
   - Note that OC_ prefix is reserved for .opencode/ system

2. **`.claude/rules/artifact-formats.md` - Placeholder Conventions section**
   - Add note about system-specific prefixes
   - Document when each format applies

3. **`.claude/rules/state-management.md` - Directory Creation section**
   - Clarify directory naming convention
   - Remove any OC_ references

### 3. Transition Handling

1. **skill-todo must scan both formats**:
   ```bash
   for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do
   ```
   This is already present and should remain for backward compatibility with existing task directories.

2. **Existing directories**: Do NOT rename existing `specs/OC_*` directories. They will be archived naturally through /todo command.

3. **New directories**: All new task directories created by .claude/ will use plain `{NNN}_{SLUG}` format.

## Implementation Scope Summary

| Category | File Count | Complexity |
|----------|-----------|------------|
| Core Skills | 4 | Medium (multiple patterns per file) |
| Core Agents | 4 | Medium (multiple patterns per file) |
| Commands | 3 | Low (single pattern each) |
| Context Core | 10 | Low-Medium (documentation updates) |
| Extension Agents | 12 | Low (consistent pattern) |
| Extension Skills | 11 | Low (consistent pattern) |
| **Total** | **44** | Medium overall |

## Search/Replace Patterns

### Primary Pattern Replacements

1. **mkdir commands**:
   - Find: `mkdir -p "specs/OC_\${padded_num}_\${` or `mkdir -p "specs/OC_{NNN}_`
   - Replace: `mkdir -p "specs/${padded_num}_${` or `mkdir -p "specs/{NNN}_`

2. **Path templates**:
   - Find: `specs/OC_{NNN}_{SLUG}`
   - Replace: `specs/{NNN}_{SLUG}`

3. **Header display**:
   - Find: `Task OC_{N}:` or `Task OC_\${` or `OC_{N}.`
   - Replace: `Task {N}:` or `Task ${` or `{N}.`

4. **Metadata paths**:
   - Find: `specs/OC_${padded_num}_`
   - Replace: `specs/${padded_num}_`

## Next Steps

1. Create implementation plan with phases for each file category
2. Implement changes starting with core skills (highest impact)
3. Test by creating a new task to verify directory format
4. Add documentation clarifying the distinction between systems
5. Consider adding a linter rule to prevent future OC_ usage in .claude/

## References

- Task 194: Original OC_ standardization (root cause of issue)
- `.claude/CLAUDE.md`: Current artifact paths documentation
- `.opencode/AGENTS.md`: OpenCode system documentation
- `specs/state.json`: Task state with completion_summary showing scope of task 194
