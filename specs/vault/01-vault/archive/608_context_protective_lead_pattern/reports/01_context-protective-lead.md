# Research Report: Task #608

**Task**: 608 - context_protective_lead_pattern
**Started**: 2026-05-22T12:00:00Z
**Completed**: 2026-05-22T12:45:00Z
**Effort**: Medium (research)
**Dependencies**: None
**Sources/Inputs**:
  - Codebase analysis of `.claude/skills/` (8 skill files)
  - Codebase analysis of `.claude/agents/` (11 agent definitions)
  - Codebase analysis of `.claude/context/` (142 context index entries)
  - Architecture docs (`handoff-schema.md`, `orchestrate-state-machine.md`, `dispatch-agent-spec.md`)
  - Existing standards (`postflight-tool-restrictions.md`, `thin-wrapper-skill.md`)
**Artifacts**:
  - This report: `specs/608_context_protective_lead_pattern/reports/01_context-protective-lead.md`
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- The system already has a **strong exemplar** of context-protective lead behavior in `skill-orchestrate`, which reads only 400-token handoff JSON between cycles and never reads full artifacts -- but this pattern has NOT been generalized as a standard.
- **Context bloat in team skills is structural**: `skill-team-research` (751 lines) instructs the lead to read ALL teammate output files during synthesis (Stage 7), pulling potentially 10k+ tokens of teammate findings into the lead's context window.
- **Skill preflight stages are a secondary source of bloat**: format specs (88-426 lines each), memory context, roadmap, and prior implementation context are all loaded into the lead's context before delegation. Total preflight injection can reach 500+ lines.
- The core **single-agent skills** (researcher, planner, implementer) are already reasonably thin -- they delegate via Agent tool and do minimal preflight work. The main opportunity is in team orchestration and the orchestrate loop.
- A formal **"Context-Protective Lead Pattern"** document should codify what `skill-orchestrate` already does and extend it to team skills, establishing context budgets, delegation-first investigation, and metadata-only reading as the standard.

---

## Context & Scope

This research examines where lead/orchestrator agents consume excessive context, why it happens, and how to fix it. The scope covers all skill files that operate as "leads" (orchestrating subagents), the context files they load, and the state files they read.

**Key insight from delegation context**: The problem is not that individual files are too large. The problem is that lead agents read too much into their own context instead of delegating investigation to subagents that return compact summaries.

---

## Findings

### 1. WHERE Context Bloat Occurs

#### 1a. Team Research Synthesis (CRITICAL -- Highest Impact)

**File**: `skill-team-research/SKILL.md` (751 lines)

Stage 7 ("Collect All Teammate Results") instructs the lead to **read each teammate's full output file**:

```bash
for teammate in "${teammates[@]}"; do
  file="specs/${padded_num}_${project_name}/reports/${run_padded}_teammate-${teammate}-findings.md"
  if [ -f "$file" ]; then
    # Parse findings
    # Extract confidence level
    # Check for conflicts with other teammates
    teammate_results+=("...")
  fi
done
```

With 3-4 teammates, each producing 1-3k tokens of findings, the lead ingests **4-12k tokens** of teammate output into its own context during synthesis. This is the single largest context bloat point.

Stage 8 then asks the lead to "Extract key findings," "Detect conflicts," "Resolve conflicts," and "Identify gaps" -- all activities that require holding all teammate content in context simultaneously.

**Same pattern in team-plan** (Stage 7, 598 lines) and **team-implement** (677 lines).

#### 1b. Skill Preflight Context Injection (MODERATE)

Each skill loads format specifications and auxiliary context into the lead's context before delegation:

| Skill | Format File | Lines | Also Loads |
|-------|------------|-------|------------|
| skill-researcher | report-format.md | 88 | memory, roadmap (28 lines), prior impl context (up to 500 lines) |
| skill-planner | plan-format.md | 147 | memory |
| skill-implementer | summary-format.md | 60 | memory |

The format files are passed to the subagent as `<artifact-format-specification>` blocks, but they are first **read into the lead's context** via `cat`. The lead itself never uses these format specs -- they are passthrough data.

#### 1c. State File Reading (LOW -- already mitigated in most places)

Most skills use `jq` extraction to read specific fields from `state.json` (102 lines) rather than loading the full file. This is already well-handled. However:

- `skill-team-research` Stage 1 reads full task data via jq but processes it inline -- acceptable
- `skill-orchestrate` reads `state.json` via jq per-cycle -- correctly minimal
- The orchestrator skill (routing) says "Read specs/state.json" in Step 1 -- could be more specific

#### 1d. Context Index Querying (LOW)

Domain context injection in team skills (Stage 5b) queries `index.json` to find domain-specific context paths. This is a jq query that returns paths (lightweight), but the comment "Read them for domain-specific patterns, tools, and standards" instructs teammates to read these files -- correctly delegating to the subagent.

### 2. WHY Context Bloat Occurs

#### 2a. No Synthesis Delegation Pattern

The system has no concept of a **synthesis agent**. When team skills need to merge multiple teammate outputs, the lead does this work inline. This forces the lead to hold all teammate content in its context simultaneously.

The `skill-orchestrate` state machine avoids this by using the handoff pattern (400-token JSON summaries), but team skills were designed before this pattern was formalized and still use the older "read everything" approach.

#### 2b. Passthrough Data Loaded Into Lead Context

Format specifications (report-format.md, plan-format.md, summary-format.md) are read by the lead skill via `cat` and then injected into the subagent prompt. The lead never uses this data itself -- it is pure passthrough. But the `cat` command loads the content into the lead's context window.

The same applies to memory context, roadmap context, and prior implementation context -- all loaded by the lead and then passed to the subagent.

#### 2c. Missing Context Budget Discipline

There is no documented **context budget** for lead agents. The postflight-tool-restrictions.md standard correctly restricts what tools leads can use AFTER delegation, but there is no equivalent standard for BEFORE delegation (preflight context loading) or DURING synthesis (post-teammate-completion reading).

#### 2d. Leader-as-Worker Anti-Pattern

Team skills conflate the roles of "project manager" (routing, coordination, status tracking) and "worker" (analysis, synthesis, conflict resolution). The lead should be a project manager -- it should delegate ALL analytical work, including synthesis.

### 3. HOW to Fix It (The Context-Protective Lead Pattern)

#### 3a. Core Principle: Lead as Project Manager

The lead agent's role is to:
1. **Route** -- determine which agents to invoke and in what order
2. **Track** -- read metadata (status, summary, path) to verify completion
3. **Delegate** -- pass @-references and file paths to subagents instead of reading files
4. **Report** -- return brief summaries to the caller

The lead MUST NOT:
- Read full artifacts (reports, plans, summaries, teammate findings)
- Load format specifications into its own context
- Perform analytical work (conflict resolution, synthesis, gap analysis)
- Hold more than ~10k tokens above baseline for routing work

#### 3b. Specific Fixes

**Fix 1: Fork a Synthesis Agent for Team Skills**

Instead of the lead reading all teammate outputs in Stage 7-8, fork a synthesis agent:

```
Lead's synthesis dispatch:
  prompt: "Read the following teammate findings and produce a unified report:
    - @specs/{NNN}_{SLUG}/reports/{RR}_teammate-a-findings.md
    - @specs/{NNN}_{SLUG}/reports/{RR}_teammate-b-findings.md
    - @specs/{NNN}_{SLUG}/reports/{RR}_teammate-c-findings.md
    Write the unified report to: specs/{NNN}_{SLUG}/reports/{RR}_team-research.md"
```

The synthesis agent reads the files in its own fresh context, performs conflict resolution and gap analysis, writes the unified report, and returns a 200-token summary to the lead. The lead's context grows by ~250 tokens instead of ~12k.

**Fix 2: Pass Format Specs as @-References**

Instead of `cat report-format.md` in the lead's preflight:

```
# BEFORE (bloat):
format_content=$(cat .claude/context/formats/report-format.md)
# Then inject into prompt as <artifact-format-specification> block

# AFTER (protective):
# In subagent prompt, use @-reference:
# "Follow the format in @.claude/context/formats/report-format.md"
```

The subagent loads the format spec in its own context. The lead never sees it.

**Fix 3: Delegate Memory/Roadmap Loading to Subagents**

Instead of the lead loading memory and roadmap into its context for passthrough:

```
# BEFORE (bloat):
memory_context=$(bash .claude/scripts/memory-retrieve.sh ...)
roadmap_context=$(cat specs/ROADMAP.md)
# Then inject both into subagent prompt

# AFTER (protective):
# In subagent prompt:
# "Load memory context via @.claude/scripts/memory-retrieve.sh for task keywords: {keywords}"
# "Consult @specs/ROADMAP.md for project direction"
```

**Fix 4: Adopt Handoff Pattern Universally**

Extend the orchestrator handoff pattern (400-token JSON) to team synthesis:

```json
{
  "teammate": "a",
  "status": "completed",
  "summary": "Found 3 candidate approaches. Primary: XYZ pattern. Confidence: high.",
  "artifact_path": "specs/NNN/reports/RR_teammate-a-findings.md",
  "key_findings_count": 3,
  "confidence": "high"
}
```

The lead reads only these handoff objects (~100 tokens each, ~400 tokens total for 4 teammates). The synthesis agent reads the full artifacts.

**Fix 5: Implementation Agent Reads Research/Plan via @-Reference**

The lead should direct the implementation agent to read research and plan artifacts, not load them itself:

```
# In implement dispatch prompt:
"Read the research report at @{research_path} and the plan at @{plan_path}
 before starting implementation."
```

The lead only passes paths. This is already mostly correct in skill-implementer (it passes `plan_path` in delegation context), but can be more explicit.

### 4. Anti-Patterns to Document

| Anti-Pattern | Description | Correct Alternative | Impact |
|---|---|---|---|
| **Reading full state.json** | `Read specs/state.json` via Read tool | `jq -r '.active_projects[] \| select(.project_number == N) \| .status' specs/state.json` | Low (state.json is only 102 lines currently, but grows) |
| **Loading format specs** | `cat .claude/context/formats/report-format.md` in lead preflight | Pass `@.claude/context/formats/report-format.md` reference to subagent | Medium (88-426 lines per format spec) |
| **Eagerly reading context files** | Loading context files into lead's context for passthrough | Use @-references in subagent prompts; fork scouts for investigation | Medium-High |
| **Reading teammate outputs during synthesis** | `Read` all teammate finding files in lead's context | Fork a synthesis agent that reads teammate files in fresh context | High (4-12k tokens) |
| **Loading memory into lead** | `memory_context=$(bash memory-retrieve.sh ...)` in lead preflight | Pass task keywords to subagent; subagent calls memory-retrieve.sh | Low-Medium (variable) |
| **Reading roadmap in lead** | `roadmap_context=$(cat specs/ROADMAP.md)` | Pass `@specs/ROADMAP.md` reference to subagent | Low (28 lines currently) |
| **Reading full TODO.md** | Loading entire TODO.md for context | `grep -n "task_number" specs/TODO.md` for specific task line | Low (83 lines currently) |

### 5. Existing Model: skill-orchestrate

`skill-orchestrate` is the reference implementation of the context-protective pattern:

**What it does right**:
1. Reads state.json via `jq` extraction only (one field per cycle: `status`)
2. Reads ONLY `.orchestrator-handoff.json` (400-token budget) after each dispatch
3. NEVER reads research reports, plan files, or implementation summaries
4. Passes `plan_path` and `continuation_context` as paths/objects to dispatched agents
5. Has explicit "MUST NOT" section documenting this constraint
6. Context grows by only ~450 tokens per cycle regardless of artifact complexity

**What the pattern document should codify from this**:
- The 400-token handoff pattern
- The "never read full artifacts" rule
- The "pass paths, not content" principle
- The explicit context budget (~10k tokens above baseline for routing)

### 6. Context Budget Analysis

Current context costs for lead agents (approximate):

| Component | Tokens (estimated) | Necessary? |
|---|---|---|
| System prompt (CLAUDE.md chain) | ~15k | Yes (baseline) |
| Skill definition | ~1.5-3k | Yes (instructions) |
| state.json jq extraction | ~100 | Yes |
| Format spec passthrough | ~500-2k | **No** -- delegate |
| Memory context passthrough | ~200-1k | **No** -- delegate |
| Roadmap passthrough | ~100 | **No** -- delegate |
| Prior impl context passthrough | ~500-2k | **No** -- delegate |
| Teammate outputs (team mode) | ~4-12k | **No** -- delegate |
| **Subtotal unnecessary** | **~1.3-17k** | |

Target: Lead context budget should stay within ~5k tokens above baseline for ALL routing and delegation work. Format specs, memory, roadmap, and teammate outputs should be loaded by subagents in their own context windows.

---

## Decisions

1. The pattern document MUST use `skill-orchestrate` as the reference implementation and extend its principles to all lead roles.
2. The pattern applies to TWO distinct lead roles: (a) team skill leads (synthesis coordination), (b) orchestrate state machine (lifecycle coordination). Both should follow the same principles.
3. Format spec injection should transition from `cat`-and-inject to `@-reference` delegation over time (not a breaking change -- both work).
4. The synthesis agent fork is the highest-impact change and should be the primary recommendation.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Synthesis agent produces lower quality than lead-inline synthesis | Medium | Start with team-research only; compare quality before rolling out to team-plan/team-implement |
| @-reference approach may not work for all context injection | Low | Keep `cat`-and-inject as fallback; @-references are additive, not replacement |
| Pattern adds a new standard that needs enforcement | Low | Lint script extension (check for Read/cat on artifact files in lead skills) |
| Forking synthesis agent adds latency | Low | Synthesis is already the bottleneck; agent startup overhead is <5 seconds |
| Current roadmap/memory are small enough that passthrough is cheap | Low | True today (28 lines / ~200 tokens), but the pattern prevents future bloat as these grow |

---

## Recommendations

### What the Pattern Document Should Contain

1. **Title**: "Context-Protective Lead Pattern"
2. **Audience**: Skill authors, team orchestration leads, /meta agent
3. **Core Principles**:
   - Lead as project manager, not worker
   - Pass paths, not content
   - Read metadata, not artifacts
   - Context budget: <10k tokens above baseline
   - Delegate analysis (including synthesis) to subagents

4. **Sections**:
   - Anti-pattern catalog (table with before/after)
   - Context budget guidelines (per-component token limits)
   - Handoff pattern reference (link to orchestrator-handoff-schema.md)
   - Synthesis delegation pattern (fork instructions)
   - Enforcement guidelines (lint checks, skill review checklist)
   - Reference implementation (skill-orchestrate excerpts)

5. **Companion Standard**: A concise "lead-context-budget.md" that sets numeric limits

### Implementation Priority (for tasks 609 and 610)

1. **Task 609** (Pattern Document): Create `.claude/context/patterns/context-protective-lead.md` with the full pattern, anti-pattern catalog, and guidelines
2. **Task 610** (Standard): Create `.claude/context/standards/lead-context-budget.md` with enforceable numeric limits and lint script updates

### Future Work

- Refactor `skill-team-research` synthesis to use a forked synthesis agent
- Update `skill-researcher`, `skill-planner`, `skill-implementer` preflight to pass format specs via @-references
- Add lint check: "Lead skill MUST NOT use Read tool on `reports/*.md`, `plans/*.md`, or `summaries/*.md`"

---

## Appendix

### Files Examined

| File | Lines | Role |
|---|---|---|
| `skill-team-research/SKILL.md` | 751 | Team research orchestration (highest bloat) |
| `skill-researcher/SKILL.md` | 242 | Single-agent research wrapper |
| `skill-orchestrator/SKILL.md` | 128 | Command routing |
| `skill-orchestrate/SKILL.md` | 449 | Autonomous lifecycle (reference implementation) |
| `skill-implementer/SKILL.md` | 363 | Implementation wrapper |
| `skill-planner/SKILL.md` | 215 | Planning wrapper |
| `skill-team-plan/SKILL.md` | 598 | Team planning orchestration |
| `skill-team-implement/SKILL.md` | 677 | Team implementation orchestration |
| `postflight-tool-restrictions.md` | 207 | Existing postflight standard |
| `thin-wrapper-skill.md` | 254 | Existing delegation pattern |
| `team-orchestration.md` | 205 | Team coordination patterns |
| `handoff-schema.md` | 380 | Orchestrator handoff JSON schema |
| `orchestrate-state-machine.md` | 80+ | State machine specification |
| `dispatch-agent-spec.md` | 60+ | Fork vs named subagent dispatch |
| `context/index.json` | 142 entries, ~35k total lines | Context discovery index |

### Context Budget Breakdown (Proposed)

| Component | Max Tokens | Notes |
|---|---|---|
| jq state extraction | 200 | Status, project_name, task_type, description |
| Delegation context JSON | 500 | Session, paths, flags |
| Teammate handoff metadata | 400 | 100 tokens per teammate, 4 max |
| Routing logic | 200 | Conditional dispatch, error handling |
| Return summary | 200 | Brief text return |
| **Total lead overhead** | **1,500** | Above system prompt baseline |
| **Budget with margin** | **5,000** | 3.3x safety margin |
