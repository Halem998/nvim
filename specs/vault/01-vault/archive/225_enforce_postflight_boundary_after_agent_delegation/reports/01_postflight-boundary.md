# Research Report: Task #225

**Task**: 225 - Enforce postflight boundary after agent delegation in skills
**Started**: 2026-03-17T12:00:00Z
**Completed**: 2026-03-17T12:35:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of 14 skill files, 8 documentation files
**Artifacts**: specs/225_enforce_postflight_boundary_after_agent_delegation/reports/01_postflight-boundary.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Skills currently declare `allowed-tools: Task, Bash, Edit, Read, Write` but thin-wrapper pattern should only need `Task` for delegation with other tools restricted to postflight operations
- Evidence from `/implement 982` shows skill-lean-implementation violated the boundary by running Edit, Bash (lake build), and MCP tools (lean_goal) after agent returned
- Analysis reveals 8 skills that delegate to agents all have the same allowed-tools declaration that enables this violation
- Reference implementation skill-researcher correctly limits postflight to: read metadata, update state.json/TODO.md, link artifacts, git commit
- Recommend creating explicit postflight boundary standard with tool restriction validation

## Context and Scope

### Problem Statement

The task description documents evidence from `/implement 982` where `skill-lean-implementation`:
1. Agent completed at line 68 ("Done - 87 tool uses")
2. Skill then ran:
   - git status
   - lake build
   - lean_goal MCP tool
   - Edit calls to DovetailedBuild.lean (lines 74-133)

This violates the thin-wrapper pattern where skills should only perform postflight operations after agent return - NOT continue implementation work.

### Investigation Scope

1. Identify all skills that delegate to agents
2. Analyze current postflight stage definitions
3. Identify tools that should be blocked during postflight
4. Find existing standards about thin-wrapper pattern and postflight
5. Find reference implementations that correctly implement the boundary
6. Recommend enforcement mechanisms

## Findings

### 1. Skills That Delegate to Agents

Found 8 skills that use `Task` tool for agent delegation:

| Skill | Agent Target | allowed-tools |
|-------|--------------|---------------|
| skill-researcher | general-research-agent | Task, Bash, Edit, Read, Write |
| skill-planner | planner-agent | Task, Bash, Edit, Read, Write |
| skill-implementer | general-implementation-agent | Task, Bash, Edit, Read, Write |
| skill-meta | meta-builder-agent | Task, Bash, Edit, Read, Write |
| skill-team-research | (parallel agents) | Task, Bash, Edit, Read, Write |
| skill-team-plan | (parallel agents) | Task, Bash, Edit, Read, Write |
| skill-team-implement | (parallel agents) | Task, Bash, Edit, Read, Write, Glob |
| skill-orchestrator | (routing) | Read, Glob, Grep, Task |

**Extension skills** (10 additional files not in core .claude/):
- skill-lean-implementation, skill-neovim-implementation, skill-latex-implementation, etc.
- All use same `allowed-tools: Task, Bash, Edit, Read, Write` pattern

### 2. Current Postflight Stage Definition

The skill-lifecycle.md and postflight-control.md define valid postflight operations:

| Operation | Tool | Purpose |
|-----------|------|---------|
| Read metadata file | Read, Bash (jq) | Parse agent return |
| Update state.json | Bash (jq) | Transition task status |
| Update TODO.md | Edit | Update status marker, add artifact links |
| Git commit | Bash (git) | Commit changes |
| Remove marker files | Bash (rm) | Cleanup .postflight-pending |

**NOT in postflight scope**:
- Write to source files (implementation work)
- Edit source files (implementation work)
- MCP tool calls (domain-specific work)
- Lake/build commands (verification work)

### 3. Tools That Should Be Blocked During Postflight

Based on analysis, these tools should be PROHIBITED during postflight:

| Tool | Reason |
|------|--------|
| Edit on non-specs files | Implementation work, not postflight |
| Write on non-specs files | Implementation work, not postflight |
| MCP tools (any) | Domain-specific work, not postflight |
| Bash (lake, nvim, build commands) | Verification work, not postflight |
| WebSearch, WebFetch | Research work, not postflight |

**ALLOWED during postflight**:

| Tool | Allowed Usage |
|------|---------------|
| Read | Read metadata file, verify artifacts exist |
| Bash (jq) | Parse/update state.json |
| Bash (git) | Create commit |
| Bash (rm, mkdir) | Cleanup marker files |
| Edit | ONLY on specs/TODO.md, specs/state.json |

### 4. Existing Documentation About Thin-Wrapper Pattern

**Key documents**:

1. `.claude/context/core/patterns/thin-wrapper-skill.md`:
   - Defines pattern: Validate -> Prepare context -> Invoke subagent -> Validate return -> Return
   - States skills "do NOT execute business logic"
   - Frontmatter shows `allowed-tools: Task` (not the multi-tool declarations found in practice)

2. `.claude/context/core/patterns/skill-lifecycle.md`:
   - Defines workflow: Preflight -> Delegate -> Postflight -> Return
   - Lists postflight as "Update task status after completion"
   - Does NOT explicitly list prohibited operations

3. `.claude/context/core/workflows/preflight-postflight.md`:
   - Comprehensive v2.0 standard for command-level preflight/postflight
   - Clearly states subagents "DO NOT update status" and "DO NOT create git commits"
   - But does NOT address skill postflight tool restrictions

**Gap**: No document explicitly states what tools are PROHIBITED during skill postflight phase.

### 5. Reference Implementation Analysis

**skill-researcher (correct implementation)**:

Stages after agent return:
- Stage 6: Read metadata file with `jq`
- Stage 7: Update state.json with `jq`, Edit TODO.md
- Stage 8: Link artifacts with `jq`/Edit (only to TODO.md/state.json)
- Stage 9: Git commit with `git add -A && git commit`
- Stage 10: Cleanup with `rm -f`
- Stage 11: Return brief summary

**Observation**: All operations are on specs/ files or git operations. NO source file modifications.

**skill-lean-implementation (violation)**:

Has "Stage 6: Zero-Debt Verification Gate" which runs:
```bash
sorry_count=$(grep -r "\bsorry\b" Theories/ 2>/dev/null | ...)
if ! lake build 2>/dev/null; then
    build_failed=true
fi
```

This verification gate is AFTER the agent returns but is implementation verification work, not postflight. The skill then potentially continues with Edit operations if verification fails.

### 6. Root Cause Analysis

The violation occurs because:

1. **allowed-tools is too permissive**: Skills declare `Task, Bash, Edit, Read, Write` giving them full implementation capability
2. **No phase separation enforcement**: Nothing prevents Edit/Write/MCP use after agent return
3. **Verification gates in wrong place**: skill-lean-implementation has verification in postflight instead of agent
4. **Pattern ambiguity**: Documentation says "thin wrapper" but doesn't specify phase-specific tool restrictions

## Recommendations

### Recommendation 1: Create Postflight Tool Restriction Standard

Create `.claude/context/core/standards/postflight-tool-restrictions.md`:

```markdown
# Postflight Tool Restrictions

## Allowed Tools During Postflight

| Tool | Allowed Targets | Purpose |
|------|-----------------|---------|
| Read | Any file | Verify artifacts, read metadata |
| Bash | jq, git, rm, mkdir | State updates, commits, cleanup |
| Edit | specs/TODO.md, specs/state.json | Status markers, artifact links |

## Prohibited During Postflight

| Tool | Reason |
|------|--------|
| Edit (non-specs files) | Implementation boundary violation |
| Write (non-specs files) | Implementation boundary violation |
| MCP tools (all) | Domain-specific work belongs in agent |
| Bash (lake, nvim, etc.) | Verification belongs in agent |
| WebSearch, WebFetch | Research belongs in agent |
```

### Recommendation 2: Add MUST NOT Section to Skills

Add to all agent-delegating skills:

```markdown
**MUST NOT** (Postflight Boundary):
1. Use Edit or Write on non-specs files after agent returns
2. Call MCP tools after agent returns
3. Run build/verification commands (lake, nvim) after agent returns
4. Continue implementation work after agent returns
5. Use WebSearch/WebFetch after agent returns
```

### Recommendation 3: Move Verification Gates to Agent

For skill-lean-implementation and similar, move "Zero-Debt Verification Gate" from skill postflight to agent execution. The agent should:
1. Run verification as final step
2. Write verification result to metadata file
3. Skill reads verification result from metadata, does NOT re-run verification

### Recommendation 4: Reduce allowed-tools Declarations

Update thin-wrapper skill frontmatter:

**Current** (overly permissive):
```yaml
allowed-tools: Task, Bash, Edit, Read, Write
```

**Proposed** (explicit phase separation):
```yaml
allowed-tools: Task, Bash, Edit, Read
# Bash: restricted to jq, git, rm, mkdir
# Edit: restricted to specs/TODO.md, specs/state.json
```

Note: `Write` is generally not needed - Edit handles TODO.md/state.json updates.

### Recommendation 5: Add Validation Script

Create `.claude/scripts/lint/lint-postflight-boundary.sh`:

```bash
#!/bin/bash
# Detect potential postflight boundary violations in skill files

violations=0

for skill in .claude/skills/*/SKILL.md .claude/extensions/*/skills/*/SKILL.md; do
    # Check for Edit patterns after "Stage [5-9]" or "postflight"
    if grep -A 50 "Stage [5-9]\|postflight" "$skill" | grep -q "Edit.*\.lean\|Edit.*\.lua\|Edit.*\.py"; then
        echo "VIOLATION: $skill has Edit on source files in postflight"
        ((violations++))
    fi
done

exit $violations
```

### Recommendation 6: Update Extension Skills

Apply the same restrictions to extension skills:
- skill-lean-implementation
- skill-neovim-implementation
- skill-latex-implementation
- skill-typst-implementation
- etc.

## Decisions

1. **Postflight should be state-only operations**: Read metadata, update state.json/TODO.md, git commit, cleanup
2. **Verification gates belong in agents**: Agents own all domain-specific work including final verification
3. **Edit/Write should be path-restricted in postflight**: Only specs/ directory allowed
4. **MCP tools should be blocked in postflight**: All domain-specific tools belong in agent phase

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Existing skills break when restricted | Gradual migration with agent updates first |
| Verification gates removed but agents don't add them | Update agent templates to include verification |
| False positives in linter | Careful regex patterns, manual review for edge cases |
| Extension skills not updated | Include in migration plan, batch update |

## Implementation Approach

**Phase 1: Documentation** (1 phase)
- Create postflight-tool-restrictions.md standard
- Add references to thin-wrapper-skill.md, skill-lifecycle.md

**Phase 2: Agent Updates** (1 phase per domain)
- Move verification gates from skill-lean-implementation to lean-implementation-agent
- Same for other extension agents with verification

**Phase 3: Skill Updates** (1 phase)
- Add MUST NOT sections to all agent-delegating skills
- Update allowed-tools declarations where practical

**Phase 4: Validation** (1 phase)
- Create lint-postflight-boundary.sh
- Add to validate-all-standards.sh
- Optional: Add to pre-commit hooks

## Appendix

### Search Queries Used

```bash
# Find skills with Task delegation
grep -r "Task tool\|subagent\|agent:" .claude/skills/

# Find postflight patterns
grep -r "postflight\|POSTFLIGHT\|Stage.*post\|GATE OUT" .claude/skills/

# Find allowed-tools declarations
grep -r "allowed-tools" .claude/skills/*/SKILL.md

# Find existing tool restrictions
grep -r "MUST NOT\|DO NOT\|prohibited\|boundary" .claude/context/core/
```

### Files Analyzed

**Core Skills** (8 files):
- .claude/skills/skill-researcher/SKILL.md
- .claude/skills/skill-planner/SKILL.md
- .claude/skills/skill-implementer/SKILL.md
- .claude/skills/skill-meta/SKILL.md
- .claude/skills/skill-team-research/SKILL.md
- .claude/skills/skill-team-plan/SKILL.md
- .claude/skills/skill-team-implement/SKILL.md
- .claude/skills/skill-status-sync/SKILL.md

**Extension Skills** (6 files examined):
- .claude/extensions/lean/skills/skill-lean-implementation/SKILL.md
- .claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md
- .claude/extensions/lean/skills/skill-lean-research/SKILL.md
- .claude/extensions/nvim/skills/skill-neovim-research/SKILL.md
- .claude/extensions/latex/skills/skill-latex-implementation/SKILL.md
- .claude/extensions/typst/skills/skill-typst-implementation/SKILL.md

**Documentation** (8 files):
- .claude/context/core/patterns/thin-wrapper-skill.md
- .claude/context/core/patterns/skill-lifecycle.md
- .claude/context/core/patterns/postflight-control.md
- .claude/context/core/workflows/preflight-postflight.md
- .claude/context/core/patterns/anti-stop-patterns.md
- .claude/context/core/orchestration/postflight-pattern.md
- .claude/context/core/checkpoints/checkpoint-gate-out.md
- .claude/context/core/templates/thin-wrapper-skill.md
