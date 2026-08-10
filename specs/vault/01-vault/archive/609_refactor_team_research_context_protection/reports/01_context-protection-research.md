# Research Report: Task #609

**Task**: 609 - refactor_team_research_context_protection
**Started**: 2026-05-23T00:00:00Z
**Completed**: 2026-05-23T00:45:00Z
**Effort**: Medium (45 minutes)
**Dependencies**: Task 608 (context-protective-lead pattern document)
**Sources/Inputs**:
  - `.claude/skills/skill-team-research/SKILL.md` (751 lines)
  - `.claude/skills/skill-researcher/SKILL.md` (242 lines)
  - `.claude/skills/skill-planner/SKILL.md` (215 lines)
  - `specs/608_context_protective_lead_pattern/reports/01_context-protective-lead.md`
  - `specs/608_context_protective_lead_pattern/plans/01_context-protective-plan.md`
  - `.claude/context/patterns/context-protective-lead.md` (248 lines)
  - `.claude/context/patterns/fork-patterns.md`
  - `.claude/context/patterns/team-orchestration.md`
  - `.claude/context/patterns/thin-wrapper-skill.md`
  - `.claude/context/reference/team-wave-helpers.md` (400 lines)
  - `.claude/scripts/skill-base.sh` (465 lines)
**Artifacts**:
  - This report: `specs/609_refactor_team_research_context_protection/reports/01_context-protection-research.md`
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- `skill-team-research/SKILL.md` (751 lines) has **two major context-bloat violations** of the context-protective lead pattern: (1) Stage 7 instructs the lead to read all teammate output files inline, accumulating 4-12k tokens; (2) Stages 8-9 instruct the lead to perform synthesis analysis (conflict detection, gap analysis, report writing) that should be delegated.
- The skill has **no memory retrieval or format spec loading** (unlike `skill-researcher`), but the domain context injection (Stage 5b) queries `index.json` via jq — which is acceptable (lightweight output) — and injects path references as text into teammate prompts, not the lead's working context.
- The context-protective lead pattern from task 608 is fully documented at `.claude/context/patterns/context-protective-lead.md` and prescribes a **dedicated synthesis agent fork** as the primary fix: the lead passes teammate file paths to a synthesis agent that operates in its own fresh context.
- No existing skill uses a synthesis fork pattern — this is a new capability to implement. The fork mechanics (omitting `subagent_type`) are documented in `.claude/context/patterns/fork-patterns.md` and are compatible with team research teammate spawning.
- The skill can shrink from 751 to roughly 350-450 lines by: (1) moving the synthesis stage documentation to `team-wave-helpers.md`, (2) replacing Stages 7-9 with a compact synthesis agent fork, and (3) using `skill-base.sh` functions for postflight instead of inline bash blocks.
- `skill-researcher` and `skill-planner` are **already thin wrappers** (242 and 215 lines respectively) but both load format specs into lead context via `cat` — a pattern task 609 should not replicate but can note as a companion improvement.

---

## Context & Scope

Task 609 is a refactor of `skill-team-research` to apply the context-protective lead pattern documented in task 608. The scope is:

1. Eliminate lead-inline synthesis (Stages 7-9 → synthesis agent fork)
2. Replace any eager context loading with delegation-first alternatives
3. Shrink the skill file by moving stage documentation to reference files

This research establishes: (a) what specifically needs to change, (b) what the correct replacement patterns are, and (c) what constraints apply to the refactor.

---

## Findings

### 1. Current skill-team-research Structure

The skill is 751 lines divided into 16 stages:

| Stage | Lines (approx) | Operation | Context Impact |
|-------|----------------|-----------|----------------|
| Stage 1: Input Validation | 1-91 | jq extraction of task fields | Low (~100 tokens) |
| Stage 2: Preflight Status Update | 92-101 | bash script call | Negligible |
| Stage 3: Create Postflight Marker | 102-123 | cat heredoc to file | Negligible |
| Stage 4: Check Team Mode | 124-150 | env var check | Negligible |
| Stage 4a: Fallback | 141-151 | skill delegation | Negligible |
| Stage 5a: Artifact Number | 152-175 | jq extraction | Low (~50 tokens) |
| Stage 5b: Task Type Routing + Domain Context | 176-233 | jq index.json query + string building | Low (~200 tokens result) |
| Stage 5: Spawn Wave 1 Teammates | 234-368 | Agent tool calls with large prompts | Lead context: teammate prompts (~500 tokens each) |
| Stage 6: Wait for Wave 1 | 369-388 | Polling | Negligible |
| Stage 6a: Spawn Wave 2 Critic | 389-455 | Agent tool call | Low |
| **Stage 7: Collect Teammate Results** | **456-485** | **Implied Read of all finding files** | **CRITICAL: 4-12k tokens** |
| **Stage 8: Synthesize Findings** | **488-505** | **Lead performs analysis inline** | **CRITICAL: 4-8k tokens of analytical work** |
| **Stage 9: Create Unified Report** | **506-562** | **Lead writes report directly** | **CRITICAL: 2-4k tokens** |
| Stage 10: Update Status | 563-600 | bash script + jq | Low |
| Stage 11: Write Metadata | 601-641 | File write | Low |
| Stage 12: Git Commit | 642-660 | git commands | Low |
| Stage 13: Cleanup | 661-674 | rm commands | Negligible |
| Stage 14: Return Summary | 675-689 | Text return | Low |

**Key finding**: Stages 7, 8, and 9 together constitute the primary context violation. The lead is instructed to iterate over all teammate finding files, read their content, perform analytical work (conflict detection, gap analysis), and then write the unified report. For 3-4 teammates with typical finding files of 1-3k tokens each, the lead accumulates 6-18k tokens of additional context during synthesis.

### 2. Context Budget Violation Analysis

Current approximate lead context growth above baseline:

| Component | Tokens (est.) | Violates Pattern? |
|-----------|---------------|-------------------|
| jq state extraction (Stage 1) | ~200 | No — correct pattern |
| Postflight marker creation (Stage 3) | ~50 | No |
| jq index.json query result (Stage 5b) | ~150 | No — paths only |
| Domain context section text (Stage 5b) | ~200 | Borderline — injected into teammate prompts, not used by lead itself |
| Teammate prompts (Stage 5) | ~1,500 | Acceptable — delegation context |
| Wave 1 teammate returns | ~400 | Acceptable if only reading handoff metadata |
| **Teammate finding files (Stage 7)** | **4,000-12,000** | **VIOLATION** |
| **Inline synthesis work (Stage 8)** | **2,000-6,000** | **VIOLATION** |
| **Report creation in lead (Stage 9)** | **1,000-3,000** | **VIOLATION** |
| **Total violation above budget** | **7,000-21,000** | **vs. 5k budget limit** |

The pattern budget is <5k tokens above baseline. The current implementation exceeds this by 7-21k tokens during synthesis.

### 3. Specific Anti-Patterns to Fix

**Anti-Pattern 1: Lead reads teammate output files (Stage 7)**

Stage 7 contains a for-loop over teammate file paths and the comment "Parse findings / Extract confidence level / Check for conflicts". This instruction implies the lead uses `Read` on each finding file. With 3-4 teammates, each file typically 1-3k tokens, the lead accumulates 4-12k tokens.

The fix per context-protective-lead.md: Fork a synthesis agent that reads these files in its own context.

**Anti-Pattern 2: Lead performs analytical work inline (Stage 8)**

Stage 8 instructs the lead to: extract key findings, detect conflicts, resolve conflicts with evidence-based judgment, identify gaps, incorporate Wave 2 Critic findings. All of this is analytical work that should be delegated to the synthesis agent.

**Anti-Pattern 3: Lead writes the unified report (Stage 9)**

Stage 9 shows a full report template that the lead is supposed to fill in and write. The lead should not write artifact content — it should receive a path to the synthesis agent's completed output.

**Non-violation: Domain context injection (Stage 5b)**

The jq query on index.json returns path strings (~150 tokens of paths). The `domain_context_section` variable is built as a small text block with @-references. This text IS injected into each teammate's prompt — but teammates receive it in their own context, not the lead's working context. The lead constructs the text (~200 tokens) once and includes it in the delegation prompt. This is acceptable.

**Non-violation: No memory or format spec loading**

Unlike `skill-researcher` (which loads `memory_context`, `roadmap_context`, and `format_content` via `cat`), `skill-team-research` has none of these preflight loads. This is already correct for team mode — these are delegated to teammates via prompt references.

### 4. Context-Protective Lead Pattern (Task 608 Output)

The pattern document at `.claude/context/patterns/context-protective-lead.md` provides the complete specification. Key elements for task 609:

**Core Principle 5 (most relevant)**:
> Delegate all analysis, including synthesis — When multiple agents produce outputs that need merging (team research, team planning), the lead forks a dedicated synthesis agent that reads all outputs in its own fresh context. The lead receives only the synthesis summary.

**Synthesis Delegation Pattern (from the document)**:

1. Teammates complete and return brief status to lead (~100 tokens each)
2. Lead collects ONLY: status, summary, artifact_path, confidence (handoff metadata)
3. Lead forks a synthesis agent with the collected file paths as @-references
4. Synthesis agent reads files in its own context, performs analysis, writes unified report
5. Lead receives ~200-word summary from synthesis agent
6. Lead context grows by ~250 tokens instead of 4-12k tokens

**Context Budget Reference** (from the document):

| Component | Max Tokens |
|-----------|-----------|
| jq state extraction | 200 |
| Delegation context JSON | 500 |
| Teammate handoff metadata | 400 |
| Routing logic overhead | 200 |
| Return summary | 200 |
| **Total lead overhead** | **1,500** |
| **Budget with safety margin** | **5,000** |

### 5. Fork Agent Pattern for Synthesis

The synthesis agent fork should use the **anonymous fork pattern** (no `subagent_type`). From `fork-patterns.md`:

> When `subagent_type` is omitted, Agent invocations spawn a forked subprocess. This is the mechanism for lightweight anonymous delegation.

The synthesis agent fork:
- Omits `subagent_type` (anonymous fork, no named agent required)
- Receives the list of teammate file paths as @-references in its prompt
- Has `Read` and `Write` in its allowed context
- Reads all finding files in its own fresh context
- Performs: conflict detection, gap analysis, resolution
- Writes the unified report to the specified output path
- Returns a compact summary (~200 words) to the lead

**Important**: From the existing team-orchestration.md documentation, the Critic teammate (Stage 6a) already demonstrates a similar pattern — it reads Wave 1 findings in its own context. The synthesis agent follows the same pattern but aggregates and writes the final unified report.

**No existing skill uses synthesis fork**: The pattern is new. The Critic reads files in its own context (correct), but then returns findings to the lead which re-reads them for synthesis (incorrect). The synthesis fork replaces the lead's re-reading entirely.

### 6. Skill File Reduction Strategy

The skill can shrink significantly by:

**Move to `team-wave-helpers.md`**:
- Full teammate prompt templates (current: ~150 lines in Stages 5, 6a)
- The SKILL.md can reference them: "See `.claude/context/reference/team-wave-helpers.md` for prompt templates"
- Note: team-wave-helpers.md already exists (400 lines) and contains similar wave patterns

**Replace with compact synthesis fork** (new pattern):
- Stages 7-9 collapse to ~30 lines: collect handoff metadata, fork synthesis agent, receive summary
- Saves ~100 lines from the current explicit synthesis loop

**Use `skill-base.sh` functions** for postflight (Stages 10-13):
- `skill-researcher` (242 lines) and `skill-planner` (215 lines) use `skill-base.sh` function calls instead of inline bash blocks
- `skill-team-research` currently has explicit inline bash for: status update, artifact incrementing, artifact linking, git commit
- Migrating to `skill_postflight_update`, `skill_increment_artifact_number`, `skill_link_artifacts` would remove ~50-70 lines

**Estimated target**: 350-450 lines (from 751), a reduction of 40-50%.

### 7. Companion Finding: skill-researcher Format Spec Loading

`skill-researcher` Stage 4b loads the format spec into lead context:
```bash
format_content=$(cat .claude/context/formats/report-format.md)
```

This injects 88 lines of format spec (~700 tokens) into the lead before delegation. The context-protective pattern prescribes passing an @-reference to the subagent instead. Task 609's scope is `skill-team-research` only, but this pattern in `skill-researcher` is a secondary improvement opportunity for a future task.

### 8. Comparison: Single-Agent vs Team-Research Lead Behavior

| Behavior | skill-researcher (single) | skill-team-research (team) | Target |
|----------|---------------------------|---------------------------|--------|
| Format spec loading | Yes (88 lines via cat) | No | Passthrough via @-ref |
| Memory retrieval | Yes (variable) | No | Passthrough via @-ref |
| Roadmap loading | Yes (28 lines via cat) | No | Passthrough via @-ref |
| Teammate output reading | N/A | Yes (4-12k tokens) | No — fork synthesis |
| Inline synthesis | N/A | Yes | No — fork synthesis |
| skill-base.sh postflight | Yes | No | Yes |

---

## Decisions

1. The primary fix is replacing Stages 7-9 with a synthesis agent fork. This addresses the largest context violation (7-21k tokens above budget).
2. The synthesis agent should be an anonymous fork (no `subagent_type`) for simplicity, following the fork-patterns.md guidance.
3. The skill should be restructured to use `skill-base.sh` postflight functions, bringing it in line with `skill-researcher` and `skill-planner`.
4. Teammate prompt templates should be moved to or cross-referenced from `team-wave-helpers.md` to reduce the skill file size.
5. Domain context injection (Stage 5b) is NOT a violation — the jq query and path-reference construction are acceptable.
6. Memory and roadmap loading are not present in `skill-team-research` (unlike `skill-researcher`), so no changes needed there.

---

## Recommendations

### Primary Change: Synthesis Agent Fork (Stages 7-9 Replacement)

Replace the current Stages 7-9 with:

**Stage 7 (new): Collect Teammate Handoff Metadata**
- After each teammate completes, read only their `.return-meta.json` or equivalent metadata (status, summary, artifact_path, confidence)
- This is ~100 tokens per teammate, not the full finding file

**Stage 8 (new): Fork Synthesis Agent**
- Dispatch an anonymous Agent fork with:
  - The collected teammate file paths as @-references
  - The task description and context
  - The expected output path for the unified report
  - The format specification as an @-reference (not inline content)
- The synthesis agent reads all finding files in its own fresh context
- The synthesis agent writes the unified report and returns a compact summary

**Stage 9 (new): Receive and Record Synthesis Summary**
- Lead receives the ~200-word synthesis summary from the fork
- Lead records the artifact path and summary for postflight
- Lead's context grows by ~250 tokens (not 7-21k)

**Synthesis agent prompt template** (to be included in the refactored skill):
```
You are a synthesis agent for team research. Your task is to read all teammate findings 
and produce a unified research report.

## Teammate Findings

Read each of the following files:
{for each teammate_path: - @{teammate_path}}

## Your Tasks

1. Extract key findings from each teammate
2. Identify agreements and conflicts between teammates
3. Resolve conflicts using evidence strength as the criterion  
4. Identify coverage gaps (important angles no teammate addressed)
5. Incorporate Critic teammate's quality assessment

## Output

Write a unified research report to: {output_path}

Follow the format in @.claude/context/formats/report-format.md

After writing the report, return a summary (≤200 words) with:
- Top 3 findings
- Key conflicts resolved (if any)
- Gaps identified (if any)
- Confidence level (high/medium/low)
```

### Secondary Change: Migrate Postflight to skill-base.sh

Replace inline bash blocks in Stages 10-13 with `skill-base.sh` function calls:
- `skill_postflight_update "$task_number" "research" "$session_id" "researched"`
- `skill_increment_artifact_number "$task_number"`
- `skill_link_artifacts "$task_number" "$ARTIFACT_PATH" ...`
- `skill_cleanup "$PADDED_NUM" "$PROJECT_NAME"`

This removes ~50-70 lines and aligns postflight with other core skills.

### Tertiary Change: Move Teammate Prompt Templates to Reference File

The current SKILL.md contains ~150 lines of full teammate prompt templates (Stages 5, 6a). These can be condensed to brief references, with full templates living in `team-wave-helpers.md`. The skill would reference them:

> "See `.claude/context/reference/team-wave-helpers.md` for the canonical teammate prompt templates. Customize the `{task_description}`, `{artifact_number}`, and `{output_path}` placeholders."

This removes ~100-120 lines from the skill.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Synthesis agent quality may differ from lead-inline synthesis | Medium | The synthesis agent has MORE context capacity than the lead (fresh context window), so quality should be equivalent or better |
| Losing the lead's nuanced conflict resolution (it "knows" the task context) | Low | The lead passes the task description and focus_prompt to the synthesis agent in the delegation prompt |
| Anonymous fork doesn't have access to CLAUDE.md system context | Low | The synthesis agent only needs Read/Write tools and the teammate file paths; no system context required |
| Moving teammate prompt templates breaks forward compatibility | Low | Keep templates in team-wave-helpers.md and reference from SKILL.md; no functional change |
| skill-base.sh postflight functions may not cover team-specific operations | Medium | Review skill-base.sh; for team-specific increments and linking, keep custom bash but use function wrappers where available |
| Domain context injection query (jq on index.json) runs at lead level | Low | This is a small jq query returning paths (~150 tokens) — acceptable and not a violation per the pattern |

---

## Context Extension Recommendations

- **Topic**: Synthesis agent fork pattern (anonymous agent for multi-output aggregation)
- **Gap**: The `fork-patterns.md` document covers the mechanics of anonymous forks but does not document the synthesis use case (reading multiple files, aggregating, writing unified output)
- **Recommendation**: Add a "Synthesis Fork" section to `fork-patterns.md` with the canonical synthesis agent prompt template and expected return format

---

## Appendix

### Files Examined

| File | Lines | Role |
|------|-------|------|
| `skill-team-research/SKILL.md` | 751 | Primary refactor target |
| `skill-researcher/SKILL.md` | 242 | Comparison: single-agent research |
| `skill-planner/SKILL.md` | 215 | Comparison: single-agent planning |
| `context-protective-lead.md` | 248 | Pattern specification from task 608 |
| `fork-patterns.md` | 160 | Anonymous fork mechanics |
| `team-orchestration.md` | 210 | Wave coordination patterns |
| `thin-wrapper-skill.md` | 258 | Delegation-first pattern |
| `team-wave-helpers.md` | 400 | Reusable wave patterns (target for off-loaded content) |
| `skill-base.sh` | 465 | Shared postflight function library |
| `context-protective-plan.md` | 171 | Task 608 implementation plan |
| `context-protective-lead-report.md` | 346 | Task 608 research findings |

### Context Budget Comparison

| Scenario | Lead Context Growth | Notes |
|----------|--------------------|-|
| Current implementation | +7,000-21,000 tokens | Stages 7-9 violation |
| After synthesis fork | +250 tokens | Synthesis summary only |
| Budget target | <5,000 tokens | Per context-protective-lead.md |
| Reference (skill-orchestrate) | +450 tokens/cycle | Proven exemplar |

### Synthesis Agent: Why Anonymous Fork

The synthesis agent does not need a named subagent type because:
1. It performs a single, bounded operation (read files, synthesize, write report)
2. It doesn't need the structured delegation context (session_id, delegation_depth, etc.)
3. It inherits the parent's prompt cache if `CLAUDE_CODE_FORK_SUBAGENT=1` is set
4. Named subagents require agent definition files; anonymous forks are simpler for one-time operations

The Critic teammate already demonstrates this pattern successfully — it reads Wave 1 findings in its own context without being a named agent.

### Estimated Line Count After Refactor

| Section | Current Lines | Target Lines | Change |
|---------|---------------|--------------|--------|
| Header + Context refs | 10 | 10 | 0 |
| Stages 1-4a (validation, preflight, fallback) | 150 | 100 | -50 (trim comments) |
| Stage 5a (artifact number) | 24 | 15 | -9 |
| Stage 5b (domain context) | 57 | 40 | -17 |
| Stage 5 + 6a (teammate spawning) | 215 | 80 | -135 (reference team-wave-helpers) |
| Stage 6 (wait) | 20 | 20 | 0 |
| Stages 7-9 (synthesis → fork) | 130 | 45 | -85 |
| Stages 10-14 (postflight) | 125 | 60 | -65 (use skill-base.sh) |
| Error handling | 40 | 40 | 0 |
| MUST NOT section | 20 | 20 | 0 |
| **Total** | **751** | **~430** | **-321** |
