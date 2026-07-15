# Context-Protective Lead Pattern

**Created**: 2026-05-22
**Purpose**: Establish how lead/orchestrator agents protect their context window
**Audience**: Skill authors, team orchestration leads, /meta agent

---

## Overview

Lead agents (skill orchestrators, team coordinators, the /orchestrate state machine) must act as **project managers**, not workers. They route tasks, track status via metadata, and delegate all analytical work -- including synthesis -- to subagents with fresh context windows. A lead that reads full artifacts, loads format specs, or performs inline synthesis is violating this pattern.

The reference implementation is `skill-orchestrate`, which grows by only ~450 tokens per cycle regardless of artifact complexity.

---

## Core Principles

1. **Route, not work** -- The lead determines which agents to invoke and in what order. It does not perform analysis, conflict resolution, or synthesis itself.

2. **Pass paths, not content** -- The lead passes file paths and @-references to subagents. It does not `cat` or `Read` files to inject their content into its own context for passthrough.

3. **Read metadata, not artifacts** -- The lead reads status fields (via `jq`), handoff JSON (~100-400 tokens), and brief summaries. It never reads full research reports, plans, implementation summaries, or teammate findings.

4. **Context budget: <5k tokens above baseline** -- All routing, delegation, and coordination work must fit within ~5,000 tokens above the system prompt baseline. See the Context Budget section for per-component limits.

5. **Delegate all analysis, including synthesis** -- When multiple agents produce outputs that need merging (team research, team planning), the lead forks a **dedicated synthesis agent** that reads all outputs in its own fresh context. The lead receives only the synthesis summary.

---

## Anti-Pattern Catalog

| # | Anti-Pattern | Description | Correct Alternative | Impact |
|---|---|---|---|---|
| 1 | **Reading teammate outputs** | Lead reads all teammate finding files during synthesis | Fork a synthesis agent with teammate file paths | High (4-12k tokens) |
| 2 | **Loading format specs** | `cat format-spec.md` in lead preflight for passthrough | Pass `@.claude/context/formats/report-format.md` reference to subagent | Medium (88-426 lines) |
| 3 | **Eagerly reading context files** | Loading context files into lead's context for passthrough to subagent | Use @-references in subagent prompts; delegate investigation to scouts | Medium-High |
| 4 | **Loading memory into lead** | `memory_context=$(bash memory-retrieve.sh ...)` in lead preflight | Pass task keywords to subagent; subagent calls memory-retrieve.sh | Low-Medium |
| 5 | **Reading roadmap in lead** | `roadmap_context=$(cat specs/ROADMAP.md)` for passthrough | Pass `@specs/ROADMAP.md` reference to subagent | Low |
| 6 | **Reading full state.json** | `Read specs/state.json` via Read tool | Use `jq -r '.active_projects[] \| select(.project_number == N) \| .status' specs/state.json` | Low |
| 7 | **Reading full TODO.md** | Loading entire TODO.md for context | `grep -n "task_number" specs/TODO.md` for specific task line | Low |

---

## Before/After Examples

### Example 1: State File Reading

```bash
# BEFORE (bloat -- loads full 100+ line file into lead context):
Read specs/state.json
# Then manually search for the task in the JSON

# AFTER (protective -- extracts only needed fields):
task_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  specs/state.json)
```

**Savings**: ~800 tokens reduced to ~20 tokens.

### Example 2: Format Spec Injection

```bash
# BEFORE (bloat -- lead reads format spec, then injects into subagent prompt):
format_content=$(cat .claude/context/formats/report-format.md)
# Inject $format_content as <artifact-format-specification> block in prompt

# AFTER (protective -- subagent reads it in its own context):
# In subagent delegation prompt:
# "Follow the format in @.claude/context/formats/report-format.md"
```

**Savings**: ~500-2,000 tokens eliminated from lead context.

### Example 3: Team Synthesis

```bash
# BEFORE (bloat -- lead reads ALL teammate outputs inline):
for teammate in a b c; do
  Read "specs/${padded}/reports/${run}_teammate-${teammate}-findings.md"
  # Parse findings, extract confidence, check conflicts...
done
# Lead performs conflict resolution and gap analysis
# Lead writes unified report

# AFTER (protective -- fork a dedicated synthesis agent):
# Lead dispatches synthesis agent with file paths only:
Agent(
  prompt: "Read the following teammate findings and produce a unified report:
    - @specs/NNN/reports/01_teammate-a-findings.md
    - @specs/NNN/reports/01_teammate-b-findings.md
    - @specs/NNN/reports/01_teammate-c-findings.md
    Write unified report to: specs/NNN/reports/01_team-research.md"
)
# Lead receives ~200-word summary from synthesis agent
```

**Savings**: 4,000-12,000 tokens reduced to ~250 tokens.

---

## Synthesis Delegation Pattern

This is the highest-impact application of the context-protective principle. In team workflows, the lead MUST NOT read teammate outputs for synthesis. Instead:

### How It Works

1. **Teammates complete** -- Each teammate writes findings to its assigned output file and returns a brief status handoff to the lead (~100 tokens each).

2. **Lead collects handoff metadata only** -- The lead reads only the handoff objects (status, summary, artifact_path, confidence). It does NOT read the full finding files.

3. **Lead forks a synthesis agent** -- The lead dispatches a dedicated synthesis agent, passing it the paths to all teammate output files:

   ```
   Synthesis agent prompt:
     "You are a synthesis agent. Read the following teammate findings
      and produce a unified report:
        - @{path_to_teammate_a_findings}
        - @{path_to_teammate_b_findings}
        - @{path_to_teammate_c_findings}
      
      Tasks:
        1. Extract key findings from each teammate
        2. Detect and resolve conflicts between findings
        3. Identify coverage gaps
        4. Write a unified report to: {output_path}
      
      Return a <200-word summary of the unified findings."
   ```

4. **Synthesis agent operates in fresh context** -- It reads the full teammate files in its own context window, performs conflict resolution and gap analysis, writes the unified artifact, and returns a compact summary.

5. **Lead receives summary** -- The lead's context grows by ~250 tokens (the synthesis summary), not by 4-12k tokens (all teammate findings).

---

## Handoff Pattern

The orchestrator handoff pattern, proven in `skill-orchestrate`, is the canonical example of context-protective inter-cycle communication.

### The Pattern

After each dispatch cycle, the lead reads only a compact JSON handoff object (~400 tokens total):

```json
{
  "status": "completed",
  "summary": "Research found 3 approaches. Primary: canonical model construction.",
  "artifact_path": "specs/608/reports/01_context-protective-lead.md",
  "next_action": "plan",
  "confidence": "high"
}
```

The lead NEVER reads the artifact at `artifact_path`. It passes the path to the next agent in the lifecycle chain.

The same pattern applies to teammate completion in team workflows -- each teammate returns a ~100-token handoff object with status, summary, and artifact_path. The lead passes the collected `artifact_path` values to the synthesis agent.

### Reference

See `.claude/docs/architecture/handoff-schema.md` for the full handoff JSON schema.
See `.claude/docs/architecture/orchestrate-state-machine.md` for the lifecycle state machine.

---

## Context Budget

Lead agents must stay within ~5,000 tokens above baseline for all routing and delegation work. The baseline is the system prompt (CLAUDE.md chain + skill definition).

### Per-Component Token Limits

| Component | Max Tokens | Notes |
|---|---|---|
| jq state extraction | 200 | Status, project_name, task_type, description |
| Delegation context JSON | 500 | Session, paths, flags |
| Teammate handoff metadata | 400 | ~100 tokens per teammate, 4 max |
| Routing logic overhead | 200 | Conditional dispatch, error handling |
| Return summary | 200 | Brief text return to caller |
| **Total lead overhead** | **1,500** | Above system prompt baseline |
| **Budget with safety margin** | **5,000** | 3.3x margin for edge cases |

### What Counts Against the Budget

- Any file content read via `Read`, `cat`, or `Bash` into the lead's context
- Subagent return text (summaries, error messages)
- jq output and command results
- Inline analytical work (conflict resolution, gap analysis)

### What Does NOT Count

- System prompt baseline (CLAUDE.md chain, skill definition)
- Tool call metadata (function signatures, parameters)
- @-references passed to subagents (loaded in subagent context, not lead)

---

## Enforcement Guidelines

Skill authors should review their lead skills against this checklist:

### Skill Review Checklist

- [ ] Lead does NOT use `Read` on `reports/*.md`, `plans/*.md`, or `summaries/*.md`
- [ ] Lead does NOT use `cat` on format spec files (report-format.md, plan-format.md, etc.)
- [ ] Lead does NOT call `memory-retrieve.sh` -- subagent handles memory loading
- [ ] Lead does NOT read `specs/ROADMAP.md` -- passes @-reference to subagent
- [ ] Lead does NOT perform synthesis inline (reading all teammate outputs)
- [ ] Team synthesis is delegated to a dedicated synthesis agent
- [ ] State file access uses `jq` extraction, not full `Read`
- [ ] Subagent prompts use @-references for context files, not inline content
- [ ] Lead context growth stays within ~5k tokens above baseline per cycle

### Violations to Flag in Code Review

1. Any `Read` or `cat` of an artifact file (report, plan, summary, teammate findings)
2. Format spec content assigned to a variable for injection
3. Inline synthesis logic (conflict detection, gap analysis) in a lead skill
4. Memory or roadmap content loaded into lead context for passthrough

---

## Reference Implementation

`skill-orchestrate` is the reference implementation of this pattern.

### What It Does Right

1. **Reads state via jq only** -- One field extraction per cycle (`status`)
2. **Reads only handoff JSON** -- The `.orchestrator-handoff.json` file (~400 tokens)
3. **Never reads full artifacts** -- Research reports, plans, and summaries are never loaded
4. **Passes paths to agents** -- `plan_path` and `continuation_context` are paths/objects, not file content
5. **Explicit constraints** -- Has a documented "MUST NOT" section enforcing these rules
6. **Constant context growth** -- ~450 tokens per cycle regardless of artifact complexity

This is the model all lead agents should follow.

---

## Compliance Status

| Skill | Status | Violations Remaining | Notes |
|-------|--------|---------------------|-------|
| skill-orchestrate | Compliant | 0 | Reference implementation |
| skill-team-research | Compliant | 0 | Refactored in task 609 |
| skill-researcher | Compliant | 0 | Refactored in task 610 |
| skill-planner | Compliant | 0 | Refactored in task 610 |
| skill-implementer | Compliant | 0 | Refactored in task 610 |
| skill-reviser | Compliant | 0 | Refactored in task 610 |
| skill-orchestrator | Compliant | 0 | Refactored in task 610 |
| skill-team-plan | Compliant | 0 | Refactored in task 610 |
| skill-team-implement | Compliant | 0 | Refactored in task 610 |
| skill-neovim-research | Compliant | 0 | Verified clean |
| skill-nix-research | Compliant | 0 | Verified clean |
| skill-neovim-implementation | Compliant | 0 | Verified clean |
| skill-nix-implementation | Compliant | 0 | Verified clean |
| skill-todo | N/A | 0 | Direct execution, no subagent |

---

## Related Patterns

- **Thin Wrapper Skill** (`patterns/thin-wrapper-skill.md`) -- Structural pattern for delegation-first skills. Context-protective lead is the complementary *context discipline* pattern.
- **Team Orchestration** (`patterns/team-orchestration.md`) -- Wave-based coordination model. Context-protective lead governs how the lead handles synthesis within this model.
- **Postflight Control** (`patterns/postflight-control.md`) -- Tool restrictions after subagent return. Context-protective lead extends similar discipline to preflight and synthesis stages.
- **Fork Patterns** (`patterns/fork-patterns.md`) -- Subagent dispatching mechanics. The synthesis agent fork follows these patterns.
- **Context Exhaustion Detection** (`patterns/context-exhaustion-detection.md`) -- Monitoring for context pressure. The budget limits in this pattern aim to prevent exhaustion before it occurs.
- **Handoff Schema** (`.claude/docs/architecture/handoff-schema.md`) -- Full schema for the 400-token handoff JSON.
- **Orchestrate State Machine** (`.claude/docs/architecture/orchestrate-state-machine.md`) -- The lifecycle state machine that demonstrates this pattern.
