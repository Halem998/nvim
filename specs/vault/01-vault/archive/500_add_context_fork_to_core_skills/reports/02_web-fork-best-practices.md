# Research Report: Fork Feature Best Practices (Web Sources)

- **Task**: 500 - Add context: fork to core delegating skills
- **Started**: 2026-04-28T01:00:00Z
- **Completed**: 2026-04-28T01:15:00Z
- **Effort**: supplemental web research
- **Dependencies**: 499 (completed), report 01_add-context-fork-skills.md
- **Sources/Inputs**:
  - [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
  - [Fork Subagents in Claude Code - Build This Now](https://www.buildthisnow.com/blog/guide/mechanics/claude-code-fork-subagent)
  - [GitHub Issue #17283 - Skill tool should honor context: fork and agent: frontmatter](https://github.com/anthropics/claude-code/issues/17283)
- **Artifacts**: `specs/500_add_context_fork_to_core_skills/reports/02_web-fork-best-practices.md`
- **Standards**: report-format.md, artifact-management.md

## Executive Summary

- **`context: fork` makes the SKILL.md body become the subagent's prompt** — it does NOT isolate context loading. The subagent can still use Bash, Edit, Read, Write and execute orchestration logic. What it loses is access to *parent conversation history*.
- **`CLAUDE_CODE_FORK_SUBAGENT=1` only fires when `subagent_type` is omitted** from Agent/Task calls — confirmed by official docs. Core skills always specify `subagent_type` explicitly, so they currently get **zero** cache-sharing benefit from this env var.
- **The two mechanisms are independent**: `context: fork` = execution isolation (no parent history); `CLAUDE_CODE_FORK_SUBAGENT=1` = prompt cache inheritance for anonymous subagents.
- **The first research report (01) was partially wrong** in its reasoning: `context: fork` does not prevent context injection per se, but the subagent loses conversation history which orchestration stages may implicitly rely on.
- **Task 500 should be revised, not abandoned**: the useful implementation is likely omitting `subagent_type` from core skill Task calls (to get FORK_SUBAGENT cache benefits), rather than adding `context: fork`.
- **`context: fork` + `agent:` frontmatter is the right pattern for simple thin-wrapper skills** that don't need parent conversation history and have no multi-stage postflight.

## Context & Scope

The previous research (report 01) was conducted entirely from codebase analysis with no web sources. It concluded that `context: fork` would "break" core skills by preventing context injection. This web research corrects that understanding using official Claude Code documentation.

## Findings

### 1. What `context: fork` Actually Does (Official Docs)

From the official Claude Code skills reference:

> "Add `context: fork` to your frontmatter when you want a skill to run in isolation. The skill content becomes the prompt that drives the subagent. It won't have access to your conversation history."

Key clarifications:
- The SKILL.md body becomes the **task prompt** for a subagent, not a set of orchestration instructions executed inline
- The subagent can still have `allowed-tools: Bash, Edit, Read, Write` and run scripts, update state.json, spawn further subagents
- What is lost: access to **parent conversation history**
- The `agent:` frontmatter field selects which subagent type runs the skill (defaults to `general-purpose`)

### 2. What `CLAUDE_CODE_FORK_SUBAGENT=1` Actually Does

Confirmed from web sources: only fires when **`subagent_type` is omitted** from Agent/Task tool calls. When `subagent_type` is specified explicitly (e.g., `subagent_type: "general-research-agent"`), the fork path is bypassed — a fresh agent is always launched with no cache inheritance.

**Impact on current architecture**: All core skills (skill-researcher, skill-planner, etc.) always specify `subagent_type` explicitly. Therefore they currently receive **zero** prompt cache benefit from `CLAUDE_CODE_FORK_SUBAGENT=1`.

### 3. Where the First Research Report Was Wrong

Report 01 claimed:
> "Adding `context: fork` would cause the skill body (which contains preflight logic, status updates, memory retrieval...) to be sent as a prompt to the agent, not executed as orchestration code in the parent conversation."

This is **correct** as a description of mechanics, but the conclusion ("this breaks things") may be wrong. If the skill body becomes the subagent's prompt, the subagent reads those instructions and executes them — including Bash calls, status updates, etc. The concern is specifically:

1. **Loss of parent conversation history**: Orchestration stages that implicitly depend on conversation context would fail. This needs per-skill analysis.
2. **Deeper nesting**: skill → subagent A → subagent B becomes a 3-layer hierarchy. Cost may increase, not decrease.
3. **Postflight would run inside the subagent**: Status updates, git commits etc. still happen, but inside the isolated subagent context.

### 4. To Actually Benefit from `CLAUDE_CODE_FORK_SUBAGENT=1`

Two paths:

**Path A — Omit `subagent_type` in core skill Task calls**:
Replace `subagent_type: "general-research-agent"` with nothing (let FORK_SUBAGENT select the agent). The forked subagent inherits the parent's prompt cache. Risk: loses explicit agent routing; must rely on `agent:` frontmatter or default `general-purpose`.

**Path B — Use `context: fork` + `agent:` frontmatter for simple skills**:
Convert skills with no postflight or minimal orchestration to Pattern B. These become isolated subagents running the SKILL.md body as a prompt. For skills with complex postflight (skill-researcher, skill-planner, skill-implementer), this requires restructuring — the postflight logic would need to live inside the subagent or be handled differently.

**Path C — Hybrid**: Keep core skills as Pattern A for now. Omit `subagent_type` from the Task tool call within the skill body (using `agent:` frontmatter to route), enabling FORK_SUBAGENT cache sharing for the agent tier while keeping the skill orchestration intact.

### 5. Best Practices from Official Docs

- Use `context: fork` + `agent:` for **simple delegation skills** that only need to pass a task prompt to a specialized agent with no pre/postflight orchestration
- Use explicit `subagent_type` in Task calls (Pattern A) for **orchestrating skills** that need pre/postflight, structured context injection, and status management
- `CLAUDE_CODE_FORK_SUBAGENT=1` benefits are maximized by omitting `subagent_type` — the trade-off is losing explicit agent type control

## Decisions

1. Report 01's **recommendation to abandon task 500 was based on incorrect mechanics** and should be revised
2. The correct scope for task 500 is: investigate and implement the appropriate fork optimization for the current skill architecture, likely Path C (hybrid: keep Pattern A orchestration but enable cache sharing at the agent-dispatch level)
3. `context: fork` + `agent:` is appropriate for any future skills that are pure delegation wrappers

## Recommendations

1. **Revise task 500 plan** — scope it as: for each core skill, evaluate whether dropping `subagent_type` from Task calls (using `agent:` frontmatter instead) enables FORK_SUBAGENT benefits without breaking explicit agent routing
2. **Pilot with one skill** (skill-researcher) before changing all core skills — verify that `CLAUDE_CODE_FORK_SUBAGENT=1` actually triggers cache sharing and that the correct agent is invoked
3. **Update fork-patterns.md** to reflect the corrected mechanics from official docs (the existing description of `context: fork` is partially inaccurate)
4. **Consider Path B for new simple skills** — future skills with no postflight should use `context: fork` + `agent:` from the start

## Appendix

### Mechanics Comparison Table

| Feature | `context: fork` | `CLAUDE_CODE_FORK_SUBAGENT=1` |
|---------|-----------------|-------------------------------|
| Trigger | Skill frontmatter field | Env var + omitting `subagent_type` |
| Effect | SKILL.md body → subagent prompt | Child inherits parent cache |
| Loses | Parent conversation history | Nothing (additive) |
| Gains | Isolation, fresh context | ~90% input token savings |
| Applies to | Skill invocation | Agent/Task tool calls |
| Independent? | Yes | Yes |

### Sources

- Official Claude Code docs: skills reference (context: fork, agent: fields)
- Build This Now: CLAUDE_CODE_FORK_SUBAGENT mechanics guide
- GitHub Issue #17283: Skill tool `context: fork` and `agent:` frontmatter behavior
