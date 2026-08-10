# Research Report: Task #665

**Task**: 665 - Create cslib skills
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:05:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 664 (cslib agents), lean extension skills
**Sources/Inputs**: Lean extension skills, Nix extension skills, creating-skills.md guide, postflight-tool-restrictions.md, cslib manifest
**Artifacts**: specs/665_create_cslib_skills/reports/01_cslib-skills-research.md
**Standards**: report-format.md, thin-wrapper-skill pattern

---

## Executive Summary

- Both cslib skills follow the thin-wrapper extension pattern (Pattern B from creating-skills.md)
- The modern thin pattern uses `context: fork` + `agent:` frontmatter with prose-only body under ~110 lines
- Nix skills are the best model: they match the cslib use case (domain-specific tools, lake build verification)
- Research skill delegates to `cslib-research-agent`; implementation skill delegates to `cslib-implementation-agent`
- Both agents are declared in the cslib manifest and have stub files ready

---

## Context & Scope

Task 665 creates two SKILL.md files in `.claude/extensions/cslib/skills/`:
- `skill-cslib-research/SKILL.md` - Research skill for CSLib formalization tasks
- `skill-cslib-implementation/SKILL.md` - Implementation skill for CSLib proof work

The cslib extension declares `"dependencies": ["core", "lean"]`, meaning lean-lsp MCP tools are available to cslib agents via inherited context. Both stub files currently contain only a placeholder comment.

---

## Findings

### Codebase Patterns

#### Thin-Wrapper Extension Pattern (Current Standard)

The creating-skills.md guide distinguishes two patterns:
- **Pattern A** (Core skills): Inline `skill-base.sh` calls, 400+ lines - used by skill-lean-research and skill-lean-implementation
- **Pattern B** (Extension skills): `context: fork` + `agent:` frontmatter, prose body under ~110 lines - used by skill-nix-research and skill-nix-implementation

The guide explicitly states extension skills should be ~83-110 lines (Pattern B), not the fat pattern used by lean skills. The lean skills (248+ lines) are Pattern A (core-style) and predate the thin wrapper refactor.

The nix skills (`skill-nix-research/SKILL.md` and `skill-nix-implementation/SKILL.md`) represent the current recommended thin pattern for extension skills. Key characteristics:
- Frontmatter: `allowed-tools: Agent, Bash, Edit, Read, Write` (not `Agent` only - note this deviates from the strict guide)
- Body: Stage 1-4 in prose, postflight in prose, MUST NOT section
- No inline bash code in research skill; minimal context in implementation skill
- Both under 110 lines

#### Lean Skills vs Nix Skills

The lean skills are fat (Pattern A core style): they contain inline bash snippets, jq commands, and 200+ lines. The nix skills are thin (Pattern B extension style): they describe stages in prose without inline code.

For cslib, we should follow the **nix skills pattern** (thin extension), not the lean skills pattern (fat core).

#### Key Differences for cslib

**Research skill** compared to nix-research:
- Agent: `cslib-research-agent` (not `nix-research-agent`)
- Task type: "cslib" (not "nix")
- Tools hint: lean-lsp MCP (inherited via lean dependency), WebSearch, WebFetch, Read, Bash
- Delegation path: `["orchestrator", "research", "skill-cslib-research"]`

**Implementation skill** compared to nix-implementation:
- Agent: `cslib-implementation-agent` (not `nix-implementation-agent`)  
- Task type: "cslib" (not "nix")
- Tools hint: Read, Write, Edit, Bash (lake build, lake test, lake lint, lake exe checkInitImports, lake exe lint-style, lake shake)
- Delegation path: `["orchestrator", "implement", "skill-cslib-implementation"]`
- Must include `plan_path` and `orchestrator_mode` in delegation context
- MUST NOT section: Edit .lean files, run lake build (verification is agent work), use MCP tools, grep for sorries

#### Postflight Restrictions

From `postflight-tool-restrictions.md`:
- Postflight is LIMITED TO: reading metadata, updating state.json, updating TODO.md, linking artifacts, git commit, cleanup
- MUST NOT: edit source files (.lean), run lake build, use MCP tools, grep on source
- The MUST NOT section template is required in all agent-delegating skills

#### Orchestrator Mode

The implementation skill must pass `orchestrator_mode` to the agent so `/orchestrate` can drive the task seamlessly through research -> plan -> implement without user confirmation between phases. This is in the delegation context JSON.

### External Resources

No external documentation needed - all patterns are well-documented in the codebase.

### Recommendations

#### skill-cslib-research/SKILL.md

Model directly on `skill-nix-research/SKILL.md` with these cslib-specific changes:
1. Frontmatter: name=`skill-cslib-research`, description mentions CSLib formalization, agent=`cslib-research-agent`
2. Trigger: task type is "cslib"
3. Stage 3 domain context: mention lean-lsp MCP tools (LeanSearch, Loogle, lean_local_search), CSLib context files, Lean 4 codebase
4. delegation_path: `["orchestrator", "research", "skill-cslib-research"]`
5. No MUST NOT section needed for research skill (research skills typically omit it)

#### skill-cslib-implementation/SKILL.md

Model directly on `skill-nix-implementation/SKILL.md` with these cslib-specific changes:
1. Frontmatter: name=`skill-cslib-implementation`, description mentions CSLib proofs, agent=`cslib-implementation-agent`
2. Trigger: task type is "cslib", /implement command
3. Stage 3 domain context: Lake build commands (lake build, lake test, lake lint, lake exe checkInitImports, lake exe lint-style, lake shake), CSLib contribution standards
4. Delegation context: include `plan_path` and `orchestrator_mode`
5. delegation_path: `["orchestrator", "implement", "skill-cslib-implementation"]`
6. MUST NOT section: Edit .lean files, run lake commands, use lean-lsp MCP tools, grep for sorries

---

## Decisions

- **Pattern B (thin extension)**: Use nix skill pattern, not lean skill pattern - cslib is an extension skill and should follow current thin wrapper standards
- **allowed-tools**: Use `Agent, Bash, Edit, Read, Write` (matching nix skills, which is the current standard for extension skills despite the guide saying `Agent` only)
- **MUST NOT in research skill**: Omit (research skills don't have build/verification restrictions; nix-research omits it too)
- **orchestrator_mode field**: Include in implementation delegation context for /orchestrate compatibility

---

## Risks & Mitigations

- **Risk**: cslib agents (task 664) may still be stubs - the skills reference agents that aren't fully implemented yet
  - **Mitigation**: Skills are independent of agent content; they just name the agent type. Skills can be created now.
- **Risk**: lean-lsp MCP tool inheritance via `"dependencies": ["lean"]` - this is a manifest-level dependency, not verified in skill content
  - **Mitigation**: Skills mention lean-lsp tools in delegation context description; agents load the actual tools

---

## Implementation Template

### skill-cslib-research/SKILL.md

```
---
name: skill-cslib-research
description: Research CSLib formalization patterns and Mathlib API for CSLib contributions. Invoke for cslib research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Research Skill

Thin wrapper that delegates CSLib research to `cslib-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "cslib"
- Research is needed for CSLib formalization, Lean 4 proof patterns, or Mathlib API
- CSLib contribution standards or module patterns need to be gathered

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task_type is "cslib".

### Stage 2: Preflight Status Update
Update status to "researching" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the cslib-research-agent:
- lean-lsp MCP tools for Mathlib search (lean_leansearch, lean_loogle, lean_local_search)
- CSLib context files from `.claude/extensions/cslib/context/`
- Local CSLib Lean files for pattern analysis

{delegation context JSON}

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-research-agent".

### Stage 4b: Self-Execution Fallback
[standard fallback text]

## Postflight (ALWAYS EXECUTE)

### Stage 5: Parse Subagent Return
### Stage 6: Update Task Status (Postflight)
### Stage 7: Link Artifacts (field_name=**Research**, next_field=**Plan**)
### Stage 8: Git Commit
### Stage 9: Return Brief Summary

## Return Format

Brief text summary (NOT JSON).
```

### skill-cslib-implementation/SKILL.md

```
---
name: skill-cslib-implementation
description: Implement CSLib proofs following Lean 4 and CSLib contribution standards. Invoke for cslib implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Implementation Skill

Thin wrapper that delegates CSLib proof implementation to `cslib-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "cslib"
- /implement command targets a CSLib task
- Lean 4 proofs or CSLib definitions need to be created or modified

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists, task_type is "cslib", and an implementation plan is present.

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context

Domain-specific context for the cslib-implementation-agent:
- CSLib coding standards from `.claude/extensions/cslib/context/`
- Verification: `lake build`, `lake test`, `lake lint`, `lake exe checkInitImports`, `lake exe lint-style`, `lake shake`
- lean-lsp MCP tools for proof state inspection (inherited via lean dependency)

{delegation context JSON including plan_path and orchestrator_mode}

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-implementation-agent".

### Stage 4b: Self-Execution Fallback
[standard fallback text]

## Postflight (ALWAYS EXECUTE)

### Stage 5: Parse Subagent Return
### Stage 6: Update Task Status (Postflight)
### Stage 7: Link Artifacts (field_name=**Summary**, next_field=**Description**)
### Stage 8: Git Commit
### Stage 9: Return Brief Summary

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:
1. Edit .lean files - All CSLib proof work is done by agent
2. Run lake build/test/lint - Verification is done by agent
3. Use lean-lsp MCP tools - Domain tools are for agent use only
4. Grep for sorries - Debt analysis is agent work
5. Write summary/reports - Artifact creation is agent work

[standard PROHIBITION text]

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Return Format

Brief text summary (NOT JSON).
```

---

## Context Extension Recommendations

None - the cslib extension already has its own context directory. No new core context files needed.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-research/SKILL.md` - Fat Pattern A (248 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Fat Pattern A (318 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - Thin Pattern B (83 lines) - PRIMARY MODEL
- `/home/benjamin/.config/nvim/.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Thin Pattern B (104 lines) - PRIMARY MODEL
- `/home/benjamin/.config/nvim/.claude/docs/guides/creating-skills.md` - Skill creation guide
- `/home/benjamin/.config/nvim/.claude/context/standards/postflight-tool-restrictions.md` - MUST NOT standard
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` - cslib extension definition
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` - Stub to replace
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - Stub to replace
