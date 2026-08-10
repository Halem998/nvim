# Research Report: Task #500

**Task**: 500 - Add context: fork frontmatter to core delegating skills
**Started**: 2026-04-28T14:00:00Z
**Completed**: 2026-04-28T14:30:00Z
**Effort**: small
**Dependencies**: 499 (completed)
**Sources/Inputs**:
- Codebase: all core skill SKILL.md files, extension skill SKILL.md files
- Task 499 research report and implementation artifacts
- `.claude/context/patterns/fork-patterns.md` (created by task 499)
- `.claude/context/architecture/system-overview.md` (updated by task 499)
- `.claude/context/patterns/thin-wrapper-skill.md`
- `.claude/context/templates/thin-wrapper-skill.md`
**Artifacts**:
- `specs/500_add_context_fork_to_core_skills/reports/01_add-context-fork-skills.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- **Task 500 as originally described conflicts with task 499 findings**: Task 499 established that core skills intentionally do NOT use `context: fork` because they need structured context injection (session_id, delegation_depth, memory_context, roadmap_context). Adding `context: fork` would break this architecture.
- **The `context: fork` mechanism prevents context loading at the skill level**: This is a token-saving optimization, NOT a delegation pattern. Core skills already avoid eager context loading via lazy `@`-references and `# Original context (now loaded by subagent)` comments.
- **Extension skills (neovim, nix) do NOT currently use `context: fork`**: They follow the same Pattern A (explicit Task tool with `subagent_type`) as core skills, with identical multi-stage postflight logic.
- **The thin-wrapper template was already clarified by task 499**: The template now explicitly states it documents the "extension skill pattern" (Pattern B), not the core skill pattern.
- **Recommendation: Redefine task 500 scope** to add `context: fork` only to extension skills that lack complex postflight, or abandon if no extension skills qualify.

## Context & Scope

### What Was Researched

1. Whether adding `context: fork` to core skills is still warranted after task 499's documentation corrections
2. Current frontmatter of all core delegating skills (researcher, planner, implementer, reviser, spawn)
3. Current frontmatter of all extension delegating skills (neovim-research, neovim-implementation, nix-research, nix-implementation)
4. What `context: fork` actually does and whether it would break core skill functionality
5. Whether any skills have eager context loading that could be eliminated

### Constraints

- Task 499 already clarified the documentation to state core skills do NOT use `context: fork`
- Core skills inject structured context (session_id, delegation_depth, memory_context, roadmap_context, format_spec) that requires the skill body to execute in the parent conversation
- `context: fork` would isolate the skill body from the parent conversation, preventing structured context injection

## Findings

### 1. Core Skill Frontmatter Audit

All five core delegating skills use identical frontmatter pattern:

| Skill | `context: fork`? | `agent:`? | `allowed-tools` | Delegation Method |
|-------|-------------------|-----------|-----------------|-------------------|
| skill-researcher | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="general-research-agent") |
| skill-planner | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="planner-agent") |
| skill-implementer | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="general-implementation-agent") |
| skill-reviser | No | No | Task, Bash, Edit, Read, Write, Glob, Grep | Task(subagent_type="reviser-agent") |
| skill-spawn | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="spawn-agent") |
| skill-meta | No | **Yes** (`meta-builder-agent`) | Task, Bash, Edit, Read, Write | agent: frontmatter (hybrid) |

Key observation: None of these skills use `context: fork`. All use multiple `allowed-tools` beyond just `Task`, indicating they perform substantive work (preflight, postflight, status updates, artifact linking) in the skill body itself -- not just delegation.

### 2. Extension Skill Frontmatter Audit

All four loaded extension skills also lack `context: fork`:

| Skill | `context: fork`? | `agent:`? | `allowed-tools` | Delegation Method |
|-------|-------------------|-----------|-----------------|-------------------|
| skill-neovim-research | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="neovim-research-agent") |
| skill-neovim-implementation | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="neovim-implementation-agent") |
| skill-nix-research | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="nix-research-agent") |
| skill-nix-implementation | No | No | Task, Bash, Edit, Read, Write | Task(subagent_type="nix-implementation-agent") |

These extension skills use exactly the same Pattern A delegation as core skills. They have multi-stage postflight logic (status update, artifact linking, git commit) identical to the core skills. They are NOT simple Pattern B wrappers.

### 3. What `context: fork` Would Break in Core Skills

Adding `context: fork` to a core skill would cause the following problems:

1. **Skill body runs as subagent prompt in isolation**: The skill body (which contains preflight logic, status updates, memory retrieval, roadmap injection, format spec injection) would be sent as a prompt to the agent, not executed as orchestration code in the parent conversation.

2. **Loss of structured delegation context**: The multi-stage preflight (Stages 1-4c in skill-researcher) reads state.json, calls update-task-status.sh, retrieves memories, reads roadmap, reads format specs -- all before invoking the subagent. With `context: fork`, these stages would be interpreted as instructions for the subagent, not executed by the skill.

3. **Postflight would not execute**: Stages 6-10 (parse return, validate artifacts, update status, link artifacts, cleanup) run after the subagent returns. With `context: fork`, the skill body ends when the subagent starts -- there is no "after" phase.

4. **`allowed-tools` would need to be reduced to just `Task`**: Pattern B skills use `allowed-tools: Task` only. Core skills require Bash, Edit, Read, Write for their preflight/postflight operations.

### 4. Could Context Loading Be Optimized Without `context: fork`?

Core skills already minimize context loading:
- Context references are marked "do not load eagerly" with `@`-reference annotations
- Original context and tools are commented out as loaded by subagent
- No `@`-imports or context loading happens at the skill level
- All heavy context loading is delegated to the agent

The only context that loads when a core skill is invoked is the skill's SKILL.md body itself (the orchestration instructions). This is necessary for execution and cannot be deferred.

### 5. Task 499's Documentation Changes

Task 499 already corrected the documentation:
- `system-overview.md` now states: "Core skills (skill-researcher, skill-planner, skill-implementer, etc.): Use Task tool with explicit `subagent_type` for structured delegation. These do NOT use `context: fork` or `agent:` frontmatter because they inject structured context."
- `thin-wrapper-skill.md` template now has a scope notice: "This template shows the extension skill pattern (Pattern B)... Core workflow skills use Pattern A."
- `fork-patterns.md` was created as a comprehensive decision matrix

### 6. Are There Any Skills Where `context: fork` Should Be Added?

Looking at the full skill inventory, the only candidates for `context: fork` would be skills that:
1. Are pure delegation wrappers with no preflight/postflight
2. Use only the Task tool
3. Do not need to inject structured context

Currently, **no loaded skills meet all three criteria**. All delegating skills (core and extension) have substantive preflight/postflight logic. The present extension skills that use Pattern B (mentioned in task 499 as slide-planning, slide-critic) are in unloaded extensions.

## Decisions

1. **Adding `context: fork` to core skills would be harmful**: It would break structured delegation context, preflight/postflight orchestration, and the entire skill-internal postflight pattern.
2. **Adding `context: fork` to loaded extension skills (nvim, nix) would also be harmful**: These skills use the same Pattern A delegation as core skills with identical multi-stage postflight.
3. **Task 500 as originally described is incompatible with the architecture established by task 499**.

## Recommendations

### Option A: Abandon Task 500 (Recommended)

Task 499 has already accomplished the documentation alignment that was the root motivation. The original task description ("align with documentation recommendations") was based on a pre-task-499 understanding where the template appeared to recommend `context: fork` for all skills. Task 499 corrected this misunderstanding. There is nothing left to implement.

### Option B: Redefine as Pattern B Consistency Check

If task 500 should not be abandoned, it could be redefined to verify that:
1. All Pattern A skills (core + loaded extensions) consistently lack `context: fork` -- **VERIFIED: they do**
2. All Pattern B skills (unloaded extensions like slide-*) consistently have `context: fork` -- **not checked, those extensions are not loaded**
3. The `thin-wrapper-skill.md` pattern file correctly documents the Pattern A/B distinction -- **VERIFIED: it does (task 499 fixed this)**

This would make it a verification-only task with no code changes needed.

### Option C: Add `agent:` Frontmatter to Core Skills

A separate (smaller) change that could be beneficial: adding the `agent:` frontmatter field to core skills (similar to how skill-meta already uses it). This would make the skill-to-agent relationship explicit in frontmatter without changing delegation behavior. However, this is cosmetic and may not be worth a task.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Implementing task as-described would break core skills | Critical | Recommend abandoning or redefining task |
| Future developer adds `context: fork` to core skill | Medium | fork-patterns.md decision matrix documents when NOT to use it |
| Confusion between Pattern A and Pattern B persists | Low | Task 499 already addressed documentation; fork-patterns.md provides clear guidance |

## Appendix

### Files Examined

- `.claude/skills/skill-researcher/SKILL.md` - 490 lines, Pattern A, no `context: fork`
- `.claude/skills/skill-planner/SKILL.md` - Pattern A, no `context: fork`
- `.claude/skills/skill-implementer/SKILL.md` - Pattern A, no `context: fork`
- `.claude/skills/skill-reviser/SKILL.md` - Pattern A, no `context: fork`
- `.claude/skills/skill-spawn/SKILL.md` - Pattern A, no `context: fork`
- `.claude/skills/skill-meta/SKILL.md` - Hybrid (agent: yes, context: fork: no)
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` - Pattern A, no `context: fork`
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - Pattern A, no `context: fork`
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - Pattern A, no `context: fork`
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Pattern A, no `context: fork`
- `.claude/context/patterns/fork-patterns.md` - Decision matrix (created by task 499)
- `.claude/context/architecture/system-overview.md` - Lines 103-117 (updated by task 499)
- `.claude/context/patterns/thin-wrapper-skill.md` - Pattern reference
- `.claude/context/templates/thin-wrapper-skill.md` - Template with scope notice
- `specs/499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md` - Task 499 findings
