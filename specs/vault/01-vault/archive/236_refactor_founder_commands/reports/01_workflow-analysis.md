# Research Report: Task #236

**Task**: 236 - refactor_founder_commands
**Date**: 2026-03-18
**Focus**: Workflow analysis of founder extension commands

## Summary

The `/market`, `/analyze`, and `/strategy` commands auto-proceed from task creation through planning and implementation in a single execution, generating the final `strategy/` report without pausing for user review. The correct design is a three-stage workflow where each command produces a research report and stops, leaving plan and implement as explicit user-driven steps.

## Current Workflow (Broken)

```
/market "description"
    → creates task
    → auto-calls /plan  (forcing questions here)
    → auto-calls /implement  (generates strategy/market-sizing-*.md)
    → task COMPLETED

Status: [COMPLETED] in one command execution
```

## Desired Workflow

```
/market "description"
    → creates task
    → asks forcing questions
    → writes research report to specs/{NNN}_{SLUG}/reports/01_*.md
    → task stops at [RESEARCHED]

User reviews report, then:
    /research N        → additional web research (optional)
    /plan N            → creates implementation plan (reads report)
    /implement N       → generates strategy/market-sizing-*.md, task COMPLETED
```

## Root Cause Analysis

### Commands (3 files)
All three commands (`/market`, `/analyze`, `/strategy`) have identical structure:
1. GATE IN: validate input, create task
2. STAGE 2A: auto-delegate to `/plan` (which invokes `skill-founder-plan`)
3. STAGE 2B: auto-delegate to `/implement` (which invokes `skill-founder-implement`)
4. GATE OUT: verify completed task

**Fix needed**: Remove stages 2A and 2B. Replace with a single delegation to `skill-market` / `skill-analyze` / `skill-strategy` that produces a **research report** and stops at `[RESEARCHED]`.

### Skills (3 files: skill-market, skill-analyze, skill-strategy)
Currently these are thin wrappers that invoke market-agent/analyze-agent/strategy-agent.
The agents ask forcing questions AND generate the final report.

**Fix needed**: These skills should follow the `skill-researcher` pattern:
- Preflight: update status to `[RESEARCHING]`
- Delegate: invoke agent to conduct forcing questions and write research report
- Postflight: update status to `[RESEARCHED]`, link artifact, git commit

### Agents (3 files: market-agent, analyze-agent, strategy-agent)
Currently each agent asks forcing questions AND generates the full strategy report output.

**Fix needed**: Agents should conduct forcing questions and write a **research report** to `specs/{NNN}_{SLUG}/reports/01_*.md`. They should NOT generate `strategy/*.md` output. That output belongs to `founder-implement-agent`.

### skill-founder-plan
Currently asks its own forcing questions when `/plan N` is run on a founder task. This is redundant since forcing questions were already asked during research.

**Fix needed**: `skill-founder-plan` / `founder-plan-agent` should **read the research report** for context (the answers from forcing questions are already captured there) and use that to generate a phase-based implementation plan. No interactive questions needed at plan time.

### skill-founder-implement / founder-implement-agent
Currently reads the plan and generates `strategy/*.md`. This part is largely correct.

**Fix needed**: Minor — ensure it reads from both plan AND research report for full context. The `strategy/` output path should support an optional path argument (passed from `/implement N [path]`).

## Scope of Changes

### Files to Modify

| File | Change |
|------|--------|
| `.claude/extensions/founder/commands/market.md` | Remove auto-plan+implement; delegate to skill-market as research; stop at [RESEARCHED] |
| `.claude/extensions/founder/commands/analyze.md` | Same pattern as market.md |
| `.claude/extensions/founder/commands/strategy.md` | Same pattern as market.md |
| `.claude/extensions/founder/skills/skill-market.md` | Rewrite as researcher-pattern skill (preflight→agent→postflight) |
| `.claude/extensions/founder/skills/skill-analyze.md` | Same pattern |
| `.claude/extensions/founder/skills/skill-strategy.md` | Same pattern |
| `.claude/extensions/founder/agents/market-agent.md` | Write research report only; no strategy/ output |
| `.claude/extensions/founder/agents/analyze-agent.md` | Same pattern |
| `.claude/extensions/founder/agents/strategy-agent.md` | Same pattern |
| `.claude/extensions/founder/agents/founder-plan-agent.md` | Read research report instead of asking questions |
| `.claude/extensions/founder/agents/founder-implement-agent.md` | Read both plan + report; support optional output path |

## Consistency Requirement

All three command workflows (market, analyze, strategy) must be **uniformly structured**:

```
/market   → skill-market   → market-agent   → [RESEARCHED]
/analyze  → skill-analyze  → analyze-agent  → [RESEARCHED]
/strategy → skill-strategy → strategy-agent → [RESEARCHED]

/plan N   → skill-founder-plan    → founder-plan-agent    → [PLANNED]
/implement N → skill-founder-implement → founder-implement-agent → [COMPLETED]
```

The `strategy/` output directory is populated ONLY by `founder-implement-agent`.

## Report Format for Agents

Each agent should produce a research report following the standard format:
- Location: `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
- Contents: forcing question answers, data gathered, initial analysis, assumptions
- NOT a final strategy artifact — this is intermediate research with structured Q&A results

## Implementation Notes

1. The existing `skill-researcher` pattern in `.claude/skills/skill-researcher.md` is the reference implementation for the new skill pattern
2. Agents should write to `.return-meta.json` with `status: "researched"` (not "implemented")
3. The plan artifact at `specs/{NNN}_{SLUG}/plans/` should be created by `/plan N` (founder-plan-agent), not by the initial command
4. `/implement N [path]` should optionally accept an output path, defaulting to `strategy/`
