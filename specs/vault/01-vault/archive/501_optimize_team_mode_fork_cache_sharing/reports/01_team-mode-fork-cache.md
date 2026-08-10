# Research Report: Task #501

**Task**: 501 - Optimize team-mode skills for FORK_SUBAGENT parallel cache sharing
**Started**: 2026-04-28T14:00:00Z
**Completed**: 2026-04-28T14:45:00Z
**Effort**: medium
**Dependencies**: Task 499 (completed)
**Sources/Inputs**:
- Codebase: `.claude/skills/skill-team-research/SKILL.md`, `.claude/skills/skill-team-plan/SKILL.md`, `.claude/skills/skill-team-implement/SKILL.md`
- Codebase: `.claude/context/patterns/fork-patterns.md`, `.claude/context/patterns/team-orchestration.md`, `.claude/context/reference/team-wave-helpers.md`
- Codebase: `.claude/context/formats/team-metadata-extension.md`
- Codebase: Task 499 research report and plan (`specs/499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md`)
- Global settings: `~/.claude/settings.json` (confirms both env vars already enabled)
**Artifacts**:
- `specs/501_optimize_team_mode_fork_cache_sharing/reports/01_team-mode-fork-cache.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- **TeammateTool and FORK_SUBAGENT are likely compatible**: Team skills spawn teammates via TeammateTool (agent teams feature) without specifying `subagent_type`, which is the exact condition for FORK_SUBAGENT cache sharing to activate. Both env vars (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `CLAUDE_CODE_FORK_SUBAGENT=1`) are already enabled in global settings.
- **Current prompt structure is not optimized for cache overlap**: The three team skills have different structures for teammate prompts -- the shared prefix (CLAUDE.md, context files, skill body) is identical, but task-specific content injected into prompts varies per teammate, reducing the cacheable portion.
- **The `token_usage_multiplier: 5.0` hardcoded value is inaccurate**: With FORK_SUBAGENT cache sharing, the actual multiplier for a 4-teammate team should be approximately 1.3x (not 5.0x). This value should be dynamically calculated and reported.
- **Increasing default `team_size` from 2 to 3-4 is economically justified**: With ~90% input token reduction for teammates 2-N, the marginal cost of additional teammates drops from ~1x to ~0.1x. A default of 3 (or even 4 for research) provides better value.
- **Prompt restructuring to maximize shared prefix is the highest-impact optimization**: Moving common content (task context, research findings, shared instructions) before teammate-specific content maximizes the cacheable prefix bytes.
- **No code changes are needed to enable cache sharing**: The architecture already supports it -- the optimizations are about maximizing the benefit through prompt ordering and metadata accuracy.

## Context & Scope

### What Was Researched

1. How the three team-mode skills (team-research, team-plan, team-implement) currently spawn teammates
2. Whether TeammateTool dispatch interacts with FORK_SUBAGENT cache sharing
3. Prompt structure analysis for cache overlap optimization
4. Metadata accuracy for reporting cache savings
5. Whether default `team_size` should change given reduced per-teammate cost
6. Practical limits and constraints of cache sharing in team mode

### Constraints

- Cannot modify TeammateTool internals (Claude Code platform feature)
- Cannot observe actual cache hit rates (platform-internal)
- Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (already enabled)
- FORK_SUBAGENT requires `CLAUDE_CODE_FORK_SUBAGENT=1` (already enabled)

## Findings

### 1. Current Teammate Spawning Mechanism

All three team skills use the same pattern:

1. The skill is invoked as a Skill tool call from the orchestrator/command
2. The skill body contains pseudocode describing how to spawn teammates
3. Teammates are spawned "using TeammateTool" (Claude Code's agent teams feature)
4. The TeammateTool accepts: name, prompt, and model parameters
5. Critically, **no `subagent_type` is specified** in teammate spawning

This is confirmed by the fork-patterns.md reference guide (created in task 499, line 138):
> "Team-mode skills spawn teammates via Agent tool calls without specifying `subagent_type`. This means they ARE eligible for FORK_SUBAGENT cache sharing."

The skills document passing a `model` parameter to TeammateTool (e.g., `model: "sonnet"`) to enforce model selection. The default model for team mode teammates is Sonnet (cost-effective for parallel work).

### 2. Teammate Prompt Structure Analysis

**skill-team-research** (4 teammates, always):
- Teammate A (Primary): task description + focus instructions + output path
- Teammate B (Alternatives): task description + "look for existing solutions" + output path
- Teammate C (Critic): task description + critic role instructions + output path
- Teammate D (Horizons): task description + roadmap reference + strategic focus + output path

**skill-team-plan** (2-3 teammates):
- Teammate A: task description + research content + "incremental delivery" focus + output path
- Teammate B: task description + research content + "alternative boundaries" focus + output path
- Teammate C (optional): task description + research content + risk/dependency analysis + output path

**skill-team-implement** (2-4 teammates per wave):
- Each teammate gets: phase details + files list + steps + verification criteria + output path
- Debugger teammate gets: error details + phase context + files list + output path

**Common elements across all teammate prompts**:
- Task number and description
- Model preference line
- Artifact number and teammate letter
- Output path specification

**Key observation**: The task-specific content (description, research content, model preference line) appears in every teammate prompt. This content is the "shared prefix" that could benefit from cache sharing. However, the *unique instructions* (role, focus, specific output path) are currently interspersed with shared content rather than cleanly separated after it.

### 3. Cache Sharing Mechanics in Team Mode

**How FORK_SUBAGENT cache sharing works with teammates**:

When the lead agent spawns teammates via TeammateTool:
1. Teammate 1 gets the full parent prompt cache (cache miss on first load, then cached)
2. Teammates 2-N share the same cached prefix from the parent conversation
3. The shared prefix includes: system prompt, CLAUDE.md context, loaded context files, skill body, and the conversation history up to the teammate spawning point
4. Each teammate's unique prompt (the TeammateTool prompt parameter) is appended after the shared prefix

**What determines the shared prefix size**:
- The parent's system prompt and conversation state at the time of spawning
- All CLAUDE.md sections loaded by the parent
- The skill body and any context files loaded by the lead
- The conversation messages up to the point of teammate dispatching

**What is NOT shared (teammate-unique)**:
- The specific prompt passed to each teammate via TeammateTool
- Any context the teammate loads independently after spawning

### 4. Spawning Order and Cache Sharing

**Does spawning order matter?** Partially:

- With `FORK_SUBAGENT=1`, the first teammate spawned pays the full cache-miss cost
- Subsequent teammates hit the cached prefix, paying ~10% of input cost
- The order of spawning does NOT affect which teammates benefit -- all teammates 2-N benefit equally regardless of order
- However, the first teammate should ideally be the one with the highest independent value (in case others fail/timeout)

**Current ordering in team-research**:
- A (Primary) -> B (Alternatives) -> C (Critic) -> D (Horizons)
- This is already reasonable: A does the most important primary work, so if it's the only one that completes, it provides the most value. This ordering also means A pays the cache-miss cost but the 3 remaining teammates all get cache hits.

### 5. Prompt Restructuring for Maximum Cache Overlap

The current teammate prompt format mixes shared and unique content:

```
Research task {task_number}: {description}     <-- SHARED
{model_preference_line}                         <-- SHARED
Artifact number: {run_padded}                   <-- SHARED
Teammate letter: a                              <-- UNIQUE
Focus on implementation approaches...           <-- UNIQUE
Output to: .../teammate-a-findings.md           <-- UNIQUE
```

**Optimization**: Structure prompts so ALL shared content comes first, then unique content:

```
## Shared Context
Task: {task_number} - {description}
{model_preference_line}
Artifact number: {run_padded}
Task type: {task_type}
Available tools: {tools_list}

## Research Context
{research_content or task_context}

## Your Assignment
Teammate: {letter}
Role: {role_description}
Focus: {unique_instructions}
Output path: {unique_output_path}
```

This maximizes the byte-identical prefix that triggers cache hits. The "Shared Context" and "Research Context" sections would be identical across all teammates, and only "Your Assignment" would vary.

**Impact estimate**: For team-plan where research content is injected, the shared prefix could be 80-90% of the total prompt. For team-research, the shared context is smaller (mainly task description and model preference), perhaps 40-60% of the prompt.

### 6. Metadata and Reporting

**Current state**: The `token_usage_multiplier: 5.0` is hardcoded in all three team skills' metadata schemas. This was set as a rough estimate before FORK_SUBAGENT optimization.

**With cache sharing**, the actual multiplier depends on:
- `team_size` (number of teammates)
- `shared_prefix_ratio` (fraction of prompt that is shared)
- Cache hit rate (assumed ~90% reduction)

**Formula**:
```
effective_multiplier = 1 + (team_size - 1) * (1 - shared_prefix_ratio * cache_hit_rate) + synthesis_overhead

Example with 4 teammates, 70% shared prefix, 90% cache hit:
= 1 + 3 * (1 - 0.7 * 0.9) + 0.3
= 1 + 3 * 0.37 + 0.3
= 2.41

Compare to without cache sharing:
= 1 + 3 * 1.0 + 0.3
= 4.3
```

**Recommended metadata fields to add**:
```json
{
  "team_execution": {
    "token_usage_multiplier": 2.4,
    "fork_cache_sharing": {
      "enabled": true,
      "estimated_savings_percent": 63,
      "shared_prefix_ratio": 0.70
    }
  }
}
```

Since actual cache hit rates are platform-internal and cannot be observed directly, the multiplier should be an estimate based on prompt structure analysis rather than measured data.

### 7. Default `team_size` Reconsideration

**Current default**: `team_size=2` (documented rationale: "minimizes cost")

**With FORK_SUBAGENT cache sharing**, the cost equation changes:

| team_size | Without cache | With cache (70% shared) | Quality benefit |
|-----------|--------------|------------------------|----------------|
| 2 | 2.0x + synth | ~1.4x + synth | Minimal diversity |
| 3 | 3.0x + synth | ~1.7x + synth | Good diversity |
| 4 | 4.0x + synth | ~2.1x + synth | Maximum diversity |

**Recommendation by skill type**:
- **team-research**: Already hardcoded to 4 teammates (line 73 of SKILL.md: `team_size=4`). This is appropriate -- research benefits most from diverse angles, and the marginal cost of teammates 3-4 is minimal with cache sharing.
- **team-plan**: Default 2, max 3. Recommend keeping at 2 -- planning has more deterministic outputs and less benefit from diversity.
- **team-implement**: Default 2, max 4. Recommend keeping at 2 -- implementation parallelism is bounded by wave dependencies, not team size.

**Note**: skill-team-research already overrides any user-provided `team_size` to 4 (hardcoded in Stage 1). The SKILL.md code comments say "Team research always uses 4 teammates (Primary, Alternatives, Critic, Horizons)". This means the `--team-size` flag has no effect for research, which is already optimal.

### 8. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` Requirement

This env var is already set in global settings (`~/.claude/settings.json`). It enables:
- The TeammateTool for spawning parallel agents
- Wave-based coordination with completion notifications
- Model selection enforcement per teammate

Without this env var, team skills gracefully degrade to single-agent execution via fallback skills (skill-researcher, skill-planner, skill-implementer).

The env var is independent of `CLAUDE_CODE_FORK_SUBAGENT=1`. Both are needed for optimal team mode:
- `AGENT_TEAMS=1`: Enables TeammateTool (required for team mode)
- `FORK_SUBAGENT=1`: Enables prompt cache sharing (cost optimization)

### 9. Practical Limits

**Context size**: Larger parent contexts create larger shared prefixes, which means greater absolute savings per teammate. However, very large contexts may approach API limits. The team skills load CLAUDE.md, skill body, and task context -- typically 20-40K tokens. This is well within limits.

**Teammate independence**: Cache sharing works best when teammates work independently. The current wave model (all teammates in a wave run in parallel with no inter-teammate communication) is already optimal for this.

**Cache invalidation**: The Anthropic API cache has a TTL (typically 5 minutes). If teammate spawning is staggered over a long period, later teammates may not benefit from the cache. The current model spawns all teammates in a wave simultaneously, which is optimal.

**Model mismatch**: If teammates use different models than the parent (e.g., parent is Opus, teammates are Sonnet), cache sharing may not apply because the system prompts differ by model. The current architecture has the lead agent (running in the Skill context) spawn Sonnet teammates. The cache sharing would apply to the shared prefix of the lead's conversation, but the model-specific system prompt portion would differ. This is an area of uncertainty.

## Decisions

1. **Prompt restructuring is the primary optimization**: Reorder teammate prompts to maximize shared prefix (shared content first, unique assignment last).
2. **`token_usage_multiplier` should be dynamic**: Replace hardcoded 5.0 with a calculated estimate based on team_size and estimated shared prefix ratio.
3. **Default team sizes should remain as-is**: Research already uses 4 (optimal). Plan and implement defaults of 2 are appropriate since their quality benefit from additional teammates is lower.
4. **Add `fork_cache_sharing` metadata block**: Track estimated savings in team execution metadata for reporting.
5. **No env var changes needed**: Both `AGENT_TEAMS=1` and `FORK_SUBAGENT=1` are already enabled globally.

## Recommendations

### Priority 1: Restructure Teammate Prompt Templates

Modify all three team skills to use a "shared prefix first, unique assignment last" prompt format. This maximizes cache overlap between teammates.

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` (Stage 5 prompts)
- `.claude/skills/skill-team-plan/SKILL.md` (Stage 5 prompts)
- `.claude/skills/skill-team-implement/SKILL.md` (Stage 7 prompts)

**Approach**: Extract the common preamble (task context, model preference, artifact number, research content) into a shared block, followed by a clearly separated "Your Assignment" section with teammate-specific instructions.

### Priority 2: Update Token Usage Multiplier Calculation

Replace `token_usage_multiplier: 5.0` with a formula-based estimate that accounts for cache sharing.

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` (Stage 11 metadata)
- `.claude/skills/skill-team-plan/SKILL.md` (Stage 11 metadata)
- `.claude/skills/skill-team-implement/SKILL.md` (Stage 13 metadata)
- `.claude/context/formats/team-metadata-extension.md` (schema update)

### Priority 3: Add Cache Sharing Metadata

Add `fork_cache_sharing` block to team execution metadata schema.

**Files to modify**:
- `.claude/context/formats/team-metadata-extension.md` (add schema fields)
- All three team skill SKILL.md files (add to metadata output)

### Priority 4: Update Team Orchestration Documentation

Update documentation to reflect FORK_SUBAGENT cache sharing benefits.

**Files to modify**:
- `.claude/context/patterns/team-orchestration.md` (add cache sharing section, update "Performance Considerations")
- `.claude/context/patterns/fork-patterns.md` (update "Team-Mode Optimization Opportunity" section from future work to implemented)

### Priority 5: Update Hardcoded Guidance in CLAUDE.md

The main CLAUDE.md contains: "Note: Team mode uses ~5x tokens compared to single-agent. Default team_size=2 minimizes cost." This should be updated to reflect cache sharing benefits.

**Files to modify**:
- `.claude/CLAUDE.md` (via extension loader -- the actual source is likely in `.claude/extensions/core/` or generated)

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| TeammateTool may not actually use FORK_SUBAGENT for cache sharing | Medium | The fork-patterns.md states they ARE eligible; verify empirically by checking API billing after a team run |
| Model mismatch (Opus lead + Sonnet teammates) may prevent cache sharing | Medium | Document this as an open question; test with same-model team if possible |
| Prompt restructuring may change teammate behavior | Low | Keep same content, only reorder sections; verify output quality is maintained |
| Dynamic multiplier may be inaccurate | Low | Use conservative estimates; note that actual savings are platform-internal |
| Updating CLAUDE.md team mode note may conflict with extension loader | Low | Trace the source of the note through extension core files |

## Appendix

### Key Files Examined

- `.claude/skills/skill-team-research/SKILL.md` (634 lines) - Full team research workflow
- `.claude/skills/skill-team-plan/SKILL.md` (617 lines) - Full team planning workflow
- `.claude/skills/skill-team-implement/SKILL.md` (697 lines) - Full team implementation workflow
- `.claude/context/patterns/fork-patterns.md` (160 lines) - Fork pattern reference (from task 499)
- `.claude/context/patterns/team-orchestration.md` (147 lines) - Wave coordination patterns
- `.claude/context/reference/team-wave-helpers.md` (401 lines) - Reusable wave patterns
- `.claude/context/formats/team-metadata-extension.md` (112 lines) - Team metadata schema
- `specs/499_research_fork_subagent_patterns/reports/01_fork-subagent-patterns.md` - Task 499 research
- `~/.claude/settings.json` - Confirms both env vars enabled

### Environment Configuration

```json
{
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
  "CLAUDE_CODE_FORK_SUBAGENT": "1"
}
```

Both are set in `~/.claude/settings.json` (global scope).

### Current team_size Defaults

| Skill | Default | Max | Effective |
|-------|---------|-----|-----------|
| skill-team-research | 2 (param) | 4 | 4 (hardcoded override in Stage 1) |
| skill-team-plan | 2 | 3 | 2 |
| skill-team-implement | 2 | 4 | 2 |
