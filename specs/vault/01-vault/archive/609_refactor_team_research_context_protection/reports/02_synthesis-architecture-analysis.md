# Synthesis Agent Architecture Analysis: Task #609

**Task**: 609 - Refactor skill-team-research for context protection (supplementary)
**Started**: 2026-05-23T10:00:00Z
**Completed**: 2026-05-23T10:30:00Z
**Effort**: Low-Medium (30 minutes — targeted investigation of architectural options)
**Dependencies**: Task 609 report 01 (context-protection-research.md); Task 608 (context-protective-lead.md)
**Sources/Inputs**:
  - `.claude/skills/skill-team-research/SKILL.md` (751 lines) — primary refactor target
  - `.claude/skills/skill-team-plan/SKILL.md` (599 lines) — synthesis comparison
  - `.claude/skills/skill-team-implement/SKILL.md` (first 100 lines) — pattern comparison
  - `.claude/agents/general-research-agent.md` — named agent format reference
  - `.claude/agents/planner-agent.md` — named agent format reference
  - `.claude/agents/reviser-agent.md` — multi-report synthesis pattern reference
  - `.claude/commands/research.md` — command/skill boundary reference
  - `.claude/context/patterns/context-protective-lead.md` — prescriptive pattern
  - `.claude/context/patterns/fork-patterns.md` — fork mechanics and cache sharing
  - `.claude/context/formats/report-format.md` — report structure specification
  - `specs/609_refactor_team_research_context_protection/reports/01_context-protection-research.md` — prior research
**Artifacts**:
  - This report: `specs/609_refactor_team_research_context_protection/reports/02_synthesis-architecture-analysis.md`
**Standards**: report-format.md

---

## Executive Summary

- **Recommended architecture**: A new named agent (`synthesis-agent.md`) is the correct placement for the synthesis logic — not an anonymous fork, not in the skill body, and not in the command. The named agent gives the synthesizer a stable identity, a model declaration, and a persistent format reference, while still operating in a fresh context that keeps the lead thin.
- **The lead's role is reduced to path collection**: After all teammates complete, the lead collects only the file paths from handoff metadata (~100 tokens per teammate) and dispatches the synthesis agent with those paths. The lead's synthesis context growth drops from 7-21k tokens to ~250 tokens (the synthesis summary returned).
- **Anonymous fork is inferior for this use case**: While anonymous forks (no `subagent_type`) benefit from `CLAUDE_CODE_FORK_SUBAGENT=1` cache sharing, they cannot have a stable model declaration or a persistent agent identity. The synthesis task requires reading 4 files + format spec — a named agent handles this more cleanly and is testable in isolation.
- **The command does not need to change**: `research.md` delegates to `skill-team-research` and is unaware of synthesis. The command/skill boundary is correct as-is; the synthesis agent is internal to the skill.
- **`skill-team-plan` already uses a parallel pattern**: `skill-team-plan` spawns plan candidate agents and does inline synthesis of the candidates. This is the same violation that task 609 is fixing in `skill-team-research`. Introducing a synthesis agent sets the precedent for a future fix to `skill-team-plan` as well.
- **Synthesis agent contract is compact**: The agent receives teammate file paths, task description, output path, and an @-reference to `report-format.md`. It reads, analyzes, writes the unified report, and returns a ≤200-word summary. No structured delegation context JSON is needed.

---

## Current State Analysis

### What Synthesis Currently Does (and Why It's Wrong)

The current `skill-team-research` SKILL.md prescribes this flow in Stages 7-9:

**Stage 7: Collect Teammate Results** — The lead iterates over all teammate file paths and is instructed to "parse findings," "extract confidence level," and "check for conflicts." This implies full `Read` of each finding file. For 3-4 teammates with typical 1-3k-token finding files, this adds 4-12k tokens to the lead's context.

**Stage 8: Synthesize Findings** — The lead performs conflict detection, conflict resolution, gap analysis, and Wave 2 Critic integration — all inline in its own context. This analytical work is the second-largest context accumulation, estimated at 2-6k additional tokens.

**Stage 9: Create Unified Report** — The lead constructs and writes the complete research report (the `## Key Findings`, `## Synthesis`, `## References` sections). This is a further 1-3k tokens of context.

**Combined violation**: 7-21k tokens above baseline for Stages 7-9, against a target budget of <5k tokens total for all lead overhead. The lead is functioning as both project manager and analyst-writer, which is the precise anti-pattern that context-protective-lead.md prohibits.

### What Must NOT Change

The following are not violations and should not be touched:
- Domain context injection (Stage 5b): The jq query on `index.json` returns path strings (~150 tokens). The `domain_context_section` variable (~200 tokens) is built as @-references injected into teammate prompts, not loaded into the lead's working context.
- Teammate spawning (Stages 5, 6a): Teammate prompts include @-references passed into fresh contexts. The lead doesn't read the content those references point to.
- Status update and postflight (Stages 10-13): These use lightweight `jq` extraction and script calls — correct pattern.

---

## Architecture Options

### Option A: Named Agent (`synthesis-agent.md` in `.claude/agents/`)

A new file `.claude/agents/synthesis-agent.md` defines a synthesis specialist that:
- Has a `model: sonnet` declaration (consistent with other worker agents)
- References `@.claude/context/formats/report-format.md` in its context section
- Is dispatched by the skill via `Agent(subagent_type: "synthesis-agent", prompt: ...)`

**Context budget impact (lead)**:
- Lead reads handoff metadata only: ~400 tokens total for all teammates
- Lead receives synthesis summary: ~200 tokens
- Lead context growth for synthesis: ~600 tokens (vs. 7-21k currently)

**Pros**:
- Stable identity: testable in isolation by invoking the agent directly
- Model declaration: synthesis explicitly uses Sonnet (or can be overridden with `model_flag`)
- Format spec as @-reference: the agent's context section lists `report-format.md` as a reference; the agent loads it in its own context, not the lead's
- Reusable: `skill-team-plan` can dispatch the same agent for plan synthesis in a future refactor
- Consistent with codebase pattern: all significant delegation targets in this project are named agents (`general-research-agent`, `planner-agent`, `reviser-agent`, etc.)
- Metadata exchange: can use `.return-meta.json` pattern for structured handoff if needed

**Cons**:
- Requires creating a new file (`.claude/agents/synthesis-agent.md`) — one additional file in the system
- Must specify `subagent_type` explicitly, which means `CLAUDE_CODE_FORK_SUBAGENT=1` cache sharing does NOT apply; synthesis agent always starts with a fresh context (this is intentional — the synthesis reads files the lead hasn't seen, so cache sharing wouldn't help)

**Complexity**: 1 new file + modification of Stages 7-9 in SKILL.md (~30 lines replacing ~130 lines)

---

### Option B: Anonymous Fork (Agent tool without `subagent_type`)

The synthesis is dispatched as an anonymous fork:
- No `subagent_type` parameter on the Agent tool call
- Prompt includes file paths and instructions inline
- If `CLAUDE_CODE_FORK_SUBAGENT=1` is set, can inherit parent's prompt cache

**Context budget impact (lead)**:
- Same as Option A: lead grows by ~600 tokens for handoff metadata + synthesis summary
- The synthesis fork itself operates in its own context (fresh or shared-cache)

**Pros**:
- No new file to create
- Eligible for `CLAUDE_CODE_FORK_SUBAGENT=1` cache sharing (could reduce synthesis agent's input token cost by ~90%)
- Faster to implement (no new agent definition needed)

**Cons**:
- No stable identity: cannot be invoked independently for testing
- No model declaration: synthesis runs at whatever model the lead is using, not sonnet
- Format spec must be embedded inline in the prompt or referenced; no persistent agent-level reference
- Not reusable: `skill-team-plan` can't share the anonymous fork across skills by name
- Inconsistent with codebase pattern: all other delegation targets that do significant work are named agents
- The Critic teammate already demonstrates that anonymous Agent calls (without `subagent_type`) work correctly for teammate spawning — but the Critic is a one-task contributor, while synthesis is the final integrating step. Synthesis warrants a named agent.
- `fork-patterns.md` explicitly notes that core skills use `subagent_type` explicitly; synthesis is a core operation

**Complexity**: No new files + modification of Stages 7-9 in SKILL.md (~30 lines replacing ~130 lines)

---

### Option C: Logic within the Skill (`SKILL.md` body, existing lead)

Synthesis logic remains in the skill but is rewritten to be context-protective: the lead reads only handoff metadata, synthesizes using only that compact data, and delegates file reading to a helper bash script.

**Context budget impact (lead)**:
- Still accumulates some synthesis work inline
- Cannot truly avoid context growth if synthesis requires reading file content for quality output
- The "helper bash script" approach would require extracting summaries from files at the bash level and injecting only excerpts — lossy and architecturally awkward

**Pros**:
- No new files
- No new delegation layer

**Cons**:
- Cannot achieve the full context savings without a fresh context; the synthesis summary from Stage 7 handoff metadata (status + confidence + one-line summary per teammate) is too thin to produce a high-quality unified report
- Inline bash extraction is fragile and lossy — the quality of conflict detection and gap analysis degrades significantly without reading full content
- Violates the core principle of context-protective-lead.md: "Delegate all analysis, including synthesis"
- The quality argument alone rules this out: the research report is the primary artifact users rely on

**Complexity**: Modification only, but the resulting synthesis quality is inferior

---

### Option D: Logic within the Command (`research.md`)

The command becomes aware of team synthesis: after the skill returns, the command reads the teammate files and performs synthesis before writing the final report.

**Context budget impact (command)**:
- The `/research` command runs at Opus (per `model: opus` in command frontmatter) — synthesis would bloat the Opus context window, which is the most expensive context to bloat
- The command accumulates context across sequential sub-agent calls (it's the orchestrator); adding synthesis would make this worse

**Pros**:
- No new files

**Cons**:
- The command is the orchestrator layer — it must stay thin by the same logic as the skill lead
- Commands run at Opus; synthesis work in the command costs significantly more in tokens and dollars than synthesis in a Sonnet agent
- Moves synthesis to a higher orchestration layer than needed; it should live as close as possible to the work it synthesizes (inside the team skill)
- Breaks the command/skill boundary: commands delegate to skills for domain work; they don't perform domain work themselves
- Anti-bypass constraint in `research.md` already says "MUST NOT write research report artifacts directly" — synthesis is artifact creation
- `research.md` is task-type-agnostic; synthesis logic belongs to the team research skill

**Complexity**: Command modification + context budget violation at the Opus level

---

## Recommended Design

**Use Option A: Named synthesis agent (`synthesis-agent.md`)**.

### Rationale

1. **Codebase consistency**: Every significant delegation target in this project is a named agent. The synthesis step is significant (it reads 3-4 files, performs analytical work, and writes the primary research artifact). It warrants a named agent.

2. **Reusability**: `skill-team-plan` has the same structural violation (lead synthesizes candidate plans inline). A named `synthesis-agent` can be reused for plan synthesis in a future refactor of that skill, with a different prompt but the same agent identity and model declaration.

3. **Testability**: A named agent can be invoked directly for debugging or quality assessment. An anonymous fork cannot.

4. **Model control**: The synthesis agent can declare `model: sonnet` independently of whatever model the lead uses. If the user passes `--opus` to `/research`, that affects the lead; synthesis can still run at Sonnet unless explicitly overridden.

5. **Cache sharing is not a win here**: The synthesis agent needs to read 3-4 files the lead hasn't seen. Even with `CLAUDE_CODE_FORK_SUBAGENT=1`, the shared prefix (CLAUDE.md chain + skill definition) is small relative to the teammate findings. The cache sharing benefit is minimal for this use case compared to teammate spawning where all teammates share the same task context prefix.

6. **Quality matters**: The research report is the primary artifact users read. Full file access in a fresh context produces better synthesis than handoff-metadata-only synthesis or bash-extracted summaries.

---

## Impact on Skill vs Command vs Agent

### `.claude/commands/research.md` — No changes required

The command delegates entirely to `skill-team-research` and is unaware of synthesis. The command/skill boundary is correct: the command routes, the skill orchestrates, the synthesis agent synthesizes. No command changes needed.

### `.claude/skills/skill-team-research/SKILL.md` — Stages 7-9 replaced

**Before**: Stages 7, 8, 9 (130 lines) instruct the lead to read all teammate files, perform synthesis inline, and write the unified report.

**After**: These three stages collapse to approximately 30-40 lines:

**Stage 7 (new): Collect Handoff Metadata**
- Read `.return-meta.json` (or equivalent status file) for each completed teammate
- Extract: `status`, `artifact_path`, `confidence`, `summary` (~100 tokens per teammate)
- Build: list of artifact paths (not file content)
- Lead context growth: ~400 tokens total

**Stage 8 (new): Dispatch Synthesis Agent**
```
Agent(
  subagent_type: "synthesis-agent",
  prompt: "Synthesize research for task {N}: {description}
  
  Teammate findings (read each):
  - @{teammate_a_path}
  - @{teammate_b_path}  
  - @{teammate_c_path}
  
  Task: {task_description}
  Focus: {focus_prompt}
  Output path: specs/{NNN}_{SLUG}/reports/{run_padded}_team-research.md
  
  Return a ≤200-word summary of unified findings."
)
```

**Stage 9 (new): Record Synthesis Result**
- Lead receives ≤200-word synthesis summary from the agent
- Lead stores: `artifact_path`, `summary`, `confidence`
- Lead context growth: ~200 tokens

**Total lead synthesis context growth**: ~600 tokens (vs. 7-21k currently)

### `.claude/agents/synthesis-agent.md` — New file

A new agent definition with:
- `model: sonnet` (worker tier, consistent with other research agents)
- Context references including `@.claude/context/formats/report-format.md`
- Execution flow: parse delegation, read all @-referenced teammate files, extract findings, detect conflicts, resolve with evidence weighting, identify gaps, write unified report, return summary
- No metadata file exchange needed (synthesis is a one-shot operation; the skill handles postflight)

---

## Synthesis Agent Contract

### Inputs

Provided inline in the dispatch prompt (no structured delegation context JSON required):

| Input | Source | Format |
|-------|--------|--------|
| Teammate finding paths | Lead collects from handoff metadata | @-references (one per line) |
| Task description | From task state | Plain text (~100 tokens) |
| Focus prompt | From original invocation | Plain text (optional) |
| Output path | Computed by lead | File path string |
| Format spec | Agent's own context reference | `@.claude/context/formats/report-format.md` |
| Roadmap path | Included as @-reference in prompt | `@specs/ROADMAP.md` (if exists) |

### What the Agent Reads (in its own context)

1. All teammate finding files (3-4 files, 1-3k tokens each = 3-12k tokens)
2. `report-format.md` (via @-reference in its agent definition context section)
3. `specs/ROADMAP.md` (via @-reference in dispatch prompt, if roadmap exists)

### What the Agent Produces

1. **Primary artifact**: Unified research report at the specified output path, following `report-format.md` structure
2. **Return value**: ≤200-word summary including:
   - Top 3 unified findings
   - Conflicts resolved (count and brief description)
   - Coverage gaps identified
   - Overall confidence level (high/medium/low)
   - Path to written report

### What the Agent Does NOT Need

- Session ID or delegation depth (one-shot operation, no metadata file needed)
- Task number (embedded in output path computed by the lead)
- Access to state.json or TODO.md (the skill handles postflight status updates)
- WebSearch or WebFetch (synthesis is local file reading and writing)
- Bash or git (no shell operations needed)

### Allowed Tools

```
allowed-tools: Read, Write
```

Read-only plus Write for the unified report. No shell tools needed.

---

## Reusability: Team-Plan Synthesis

`skill-team-plan` has the same structural violation: Stage 8 instructs the lead to compare candidate plans, evaluate trade-offs, and select elements from each — all inline synthesis. Stage 9 writes the final plan directly.

A future refactor of `skill-team-plan` can reuse `synthesis-agent.md` with a different dispatch prompt:

```
Agent(
  subagent_type: "synthesis-agent",
  prompt: "Synthesize implementation plans for task {N}: {description}
  
  Plan candidates (read each):
  - @{candidate_a_path}
  - @{candidate_b_path}
  
  Risk analysis: @{risk_analysis_path}
  
  Output: specs/{NNN}/plans/{run_padded}_implementation-plan.md
  Format: @.claude/context/formats/plan-format.md"
)
```

The same agent handles both research synthesis and plan synthesis with different @-references and output formats. This is the reusability dividend of Option A over Option B.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Synthesis quality may differ from lead-inline synthesis | Low | Fresh context with full file access produces equal or better synthesis than a context-bloated lead; Critic findings are included as a @-reference |
| Lead loses task context during synthesis | Low | Task description and focus prompt are included in the dispatch prompt; synthesis agent has sufficient context for quality output |
| Synthesis agent fails or times out | Medium | Lead should timeout after 20 minutes; on failure, preserve individual teammate files as fallback artifacts; mark status partial |
| Named agent requires maintaining a new file | Low | The file is simple (model declaration + context references + execution flow); comparable to existing agent files (~100-150 lines) |
| `skill-team-plan` diverges from the new pattern | Low | Not in scope for task 609; document as a follow-on task; the synthesis agent's API is designed for reuse |

---

## Context Extension Recommendations

- **Topic**: Synthesis agent reuse across team skills
- **Gap**: `fork-patterns.md` describes anonymous forks and named agent patterns but does not document the synthesis-agent-as-reusable-named-agent pattern across multiple team skills
- **Recommendation**: Add a section to `fork-patterns.md` or `team-orchestration.md` documenting the synthesis agent pattern: when to use a named agent vs. anonymous fork for synthesis, the minimal allowed-tools declaration, and the reuse contract across `skill-team-research` and `skill-team-plan`

---

## Appendix

### Files Examined

| File | Lines Read | Role |
|------|------------|------|
| `skill-team-research/SKILL.md` | 751 | Primary refactor target (Stages 7-9 analysis) |
| `skill-team-plan/SKILL.md` | 599 | Synthesis pattern comparison |
| `skill-team-implement/SKILL.md` | First 100 | Pattern comparison |
| `agents/general-research-agent.md` | 296 | Named agent format reference |
| `agents/planner-agent.md` | First 40 | Named agent format reference |
| `agents/reviser-agent.md` | 193 | Multi-report synthesis pattern (Stage 4) |
| `commands/research.md` | 192 | Command/skill boundary reference |
| `patterns/context-protective-lead.md` | 249 | Prescriptive pattern specification |
| `patterns/fork-patterns.md` | 160 | Fork mechanics and cache sharing |
| `formats/report-format.md` | 89 | Synthesis output format spec |
| `reports/01_context-protection-research.md` | 369 | Prior research findings |

### Option Comparison Matrix

| Criterion | A: Named Agent | B: Anonymous Fork | C: In-Skill | D: In-Command |
|-----------|:--------------:|:-----------------:|:-----------:|:-------------:|
| Lead context growth | ~600 tokens | ~600 tokens | 2-8k tokens | 7-21k tokens |
| Reusable by team-plan | Yes | No | No | No |
| Testable in isolation | Yes | No | No | No |
| Model control | Yes (sonnet) | No (inherits) | N/A | No (opus) |
| Format spec location | Agent def | Inline/prompt | Inline | Inline |
| Files changed | 2 | 1 | 1 | 2 |
| Cache sharing | No | Yes (conditional) | N/A | N/A |
| Codebase consistency | High | Medium | Low | Low |
| Command awareness needed | No | No | No | Yes |

**Winner**: Option A (Named Agent) — wins on reusability, testability, model control, and consistency; loses only on cache sharing (which is not a win for this use case anyway).

### Context Budget Comparison

| Scenario | Lead Context Growth | Quality |
|----------|--------------------:|---------|
| Current (Stages 7-9 inline) | +7,000-21,000 tokens | Good (but expensive) |
| Option A: Named synthesis agent | +600 tokens | Equal or better |
| Option B: Anonymous fork | +600 tokens | Equal or better |
| Option C: In-skill (metadata only) | +500 tokens | Degraded |
| Pattern budget target | <5,000 tokens | — |
