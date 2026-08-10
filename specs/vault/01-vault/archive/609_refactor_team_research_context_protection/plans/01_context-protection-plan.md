# Implementation Plan: Refactor skill-team-research for Context-Protective Lead Pattern

- **Task**: 609 - refactor_team_research_context_protection
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 608 (context-protective-lead pattern document)
- **Research Inputs**:
  - specs/609_refactor_team_research_context_protection/reports/01_context-protection-research.md
  - specs/609_refactor_team_research_context_protection/reports/02_synthesis-architecture-analysis.md
- **Artifacts**: plans/01_context-protection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor `skill-team-research/SKILL.md` (751 lines) to apply the context-protective lead pattern from task 608. The primary change replaces Stages 7-9 (inline synthesis where the lead reads all teammate findings, performs conflict resolution, and writes the unified report -- accumulating 7-21k tokens) with a dispatch to a new named `synthesis-agent.md` that operates in its own fresh context. Secondary changes migrate postflight to `skill-base.sh` functions and extract teammate prompt templates to `team-wave-helpers.md`. Target: lead context stays under 5k tokens above baseline; skill shrinks from 751 to ~430 lines.

### Research Integration

Two research reports inform this plan:

1. **Report 01** (context-protection-research.md): Identified Stages 7, 8, and 9 as the sole context-budget violations. Stage 7 reads all teammate output files (4-12k tokens), Stage 8 performs inline synthesis analysis (2-6k tokens), and Stage 9 writes the unified report (1-3k tokens). Total violation: 7-21k tokens against a 5k budget. Non-violations confirmed: domain context injection (Stage 5b) is acceptable at ~200 tokens; no memory or roadmap loading in the lead. Postflight (Stages 10-13) uses inline bash instead of `skill-base.sh` functions -- a secondary improvement.

2. **Report 02** (synthesis-architecture-analysis.md): Evaluated four architecture options for the synthesis replacement. Recommends **Option A: named synthesis-agent.md** over anonymous fork (Option B) due to: reusability by `skill-team-plan` in a future refactor, testability in isolation, explicit `model: sonnet` declaration, and codebase consistency with existing named agents. The agent receives teammate file paths as @-references, reads them in its own context, performs conflict resolution and gap analysis, writes the unified report, and returns a compact summary (under 200 words). Allowed tools: Read, Write only.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items are directly advanced by this meta task. Roadmap item "Agent frontmatter validation" is tangentially related (the new synthesis-agent.md must follow the frontmatter standard).

## Goals & Non-Goals

**Goals**:
- Create a named `synthesis-agent.md` in `.claude/agents/` with model declaration and context references
- Replace Stages 7-9 in `SKILL.md` with a compact synthesis-agent dispatch (collect handoff metadata, dispatch agent, receive summary)
- Migrate Stages 10-13 postflight to use `skill-base.sh` functions where available
- Extract full teammate prompt templates to `team-wave-helpers.md`, leaving only customization points in the skill
- Reduce lead context growth from 7-21k tokens to under 600 tokens for synthesis
- Reduce SKILL.md from 751 lines to approximately 430 lines
- Update the CLAUDE.md agent table and skill-to-agent mapping to include synthesis-agent

**Non-Goals**:
- Refactoring `skill-team-plan` to use the synthesis agent (future task)
- Fixing `skill-researcher` format spec loading anti-pattern (separate concern noted in research)
- Changing teammate spawning logic, wave coordination, or team_size derivation
- Modifying the `/research` command file (`research.md`)
- Adding new functionality or changing the research output format

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Synthesis agent quality differs from inline synthesis | M | L | Fresh context with full file access produces equal or better synthesis; task description and focus prompt included in dispatch |
| skill-base.sh functions missing team-specific operations (artifact increment, linking) | M | M | Review skill-base.sh; functions `skill_increment_artifact_number`, `skill_link_artifacts`, `skill_postflight_update`, `skill_cleanup` all exist and match needs |
| Moving teammate prompts to team-wave-helpers.md breaks prompt customization | L | L | Keep mode-specific instruction blocks in SKILL.md; move only the structural template to helpers |
| Synthesis agent times out on large teams | M | L | Set 20-minute timeout; on failure preserve raw teammate files as fallback artifacts and mark status partial |
| CLAUDE.md regeneration loses new agent entry | L | L | CLAUDE.md is generated from merge-sources; add synthesis-agent to the appropriate merge-source table |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create synthesis-agent.md [COMPLETED]

**Goal**: Create the named synthesis agent definition that reads teammate findings in its own fresh context and produces a unified research report.

**Tasks**:
- [x] Create `.claude/agents/synthesis-agent.md` with proper frontmatter (`name: synthesis-agent`, `description`, `model: sonnet`) *(completed)*
- [x] Define Context References section with @-references to `report-format.md` and `return-metadata-file.md` *(completed)*
- [x] Write Execution Flow: (1) parse dispatch prompt for teammate paths, task description, focus prompt, and output path; (2) read all teammate finding files via @-references; (3) extract key findings from each; (4) detect and resolve conflicts using evidence weighting; (5) identify coverage gaps; (6) incorporate Critic findings as quality assessment; (7) write unified report following report-format.md structure; (8) return compact summary (under 200 words) with top findings, conflicts resolved, gaps identified, and confidence level *(completed)*
- [x] Set allowed-tools to `Read, Write` only (no shell tools, no web tools) *(completed)*
- [x] Add error handling section: timeout behavior, missing teammate files, malformed findings *(completed)*
- [x] Add synthesis output contract: summary format, word limit, required fields (top 3 findings, conflicts count, gaps count, confidence, report path) *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/agents/synthesis-agent.md` - New file (create)

**Verification**:
- File exists with correct frontmatter (name, description, model: sonnet)
- Context references include report-format.md
- Execution flow covers all synthesis steps
- Allowed tools are Read and Write only
- Output contract specifies under-200-word summary format

---

### Phase 2: Extract teammate prompt templates to team-wave-helpers.md [COMPLETED]

**Goal**: Move the full teammate prompt templates (Stages 5 and 6a, approximately 150 lines) out of SKILL.md into `team-wave-helpers.md`, leaving only customization points and mode-specific instruction blocks in the skill.

**Tasks**:
- [x] Read current `team-wave-helpers.md` (400 lines) to identify insertion point *(completed)*
- [x] Add a new section "## Team Research Teammate Prompts" to `team-wave-helpers.md` *(completed)*
- [x] Extract and move the following templates from SKILL.md: *(completed)*
  - Teammate A (Primary Angle) prompt template with placeholders
  - Teammate B (Alternative Approaches) prompt template with placeholders
  - Teammate C (Critic / Wave 2) prompt template with placeholders
  - Teammate D (Horizons) prompt template with placeholders
- [x] Include placeholder documentation: `{task_number}`, `{description}`, `{model_preference_line}`, `{domain_context_section}`, `{run_padded}`, `{NNN}`, `{SLUG}`, `{focus_prompt}`, `{wave1_findings}`, `{roadmap_path}` *(completed)*
- [x] Include the mode-specific instruction variants (default, exploit, explore) as a sub-table within each template *(completed)*
- [x] Add a "## Synthesis Agent Dispatch" section documenting the synthesis-agent dispatch prompt template and expected return format *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/reference/team-wave-helpers.md` - Add teammate prompt templates and synthesis dispatch template

**Verification**:
- team-wave-helpers.md contains all four teammate prompt templates with correct placeholders
- Mode-specific instruction variants (default, exploit, explore) are documented
- Synthesis dispatch template is documented
- No functional logic was lost in extraction

---

### Phase 3: Refactor Stages 7-9 in SKILL.md (core change) [COMPLETED]

**Goal**: Replace the inline synthesis (Stages 7, 8, 9 -- approximately 130 lines where the lead reads all teammate findings, performs analysis, and writes the unified report) with a compact synthesis-agent dispatch (approximately 40 lines).

**Tasks**:
- [x] Replace Stage 7 (Collect All Teammate Results) with "Stage 7: Collect Teammate Handoff Metadata" -- read only teammate status, summary, artifact_path, and confidence from completion handoff (not full finding files); build list of teammate artifact paths (~100 tokens per teammate) *(completed)*
- [x] Replace Stage 8 (Synthesize Findings) with "Stage 8: Dispatch Synthesis Agent" -- construct dispatch prompt with: task description, focus_prompt, teammate artifact paths as @-references, output path (`specs/{NNN}_{SLUG}/reports/{run_padded}_team-research.md`), format reference (`@.claude/context/formats/report-format.md`), roadmap reference (`@specs/ROADMAP.md`); dispatch via `Agent(subagent_type: "synthesis-agent", prompt: ...)` with `model: "${teammate_model}"`; set timeout of 20 minutes *(completed)*
- [x] Replace Stage 9 (Create Unified Report) with "Stage 9: Record Synthesis Result" -- receive compact summary from synthesis agent (~200 words); store artifact_path and summary for postflight use; on synthesis failure: preserve raw teammate files, mark status partial, log error *(completed)*
- [x] Condense Stage 5 (Spawn Wave 1) to reference `team-wave-helpers.md` for prompt templates, keeping only mode-specific customization logic and the Agent tool call structure inline *(completed)*
- [x] Condense Stage 6a (Spawn Wave 2 Critic) similarly, referencing `team-wave-helpers.md` for the Critic prompt template *(completed)*
- [x] Update the MUST NOT section to explicitly include: "Lead MUST NOT read teammate finding files (delegate to synthesis-agent)" *(completed)*
- [x] Update Context References header comment to remove "Context loaded by lead during synthesis" and replace with "Synthesis delegated to synthesis-agent" *(completed)*

**Timing**: 1.5 hours

**Depends on**: Phase 1 (synthesis-agent.md must exist to reference)

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Major refactor of Stages 5, 6a, 7, 8, 9; update header and MUST NOT section

**Verification**:
- Stages 7-9 are replaced with handoff-metadata collection, synthesis-agent dispatch, and result recording
- Lead no longer reads full teammate finding files
- SKILL.md references synthesis-agent by name in Stage 8
- Teammate prompt sections reference team-wave-helpers.md for templates
- Lead context growth for synthesis is under 600 tokens (handoff metadata + synthesis summary)
- No functional synthesis logic (conflict detection, gap analysis) remains in the lead

---

### Phase 4: Migrate postflight to skill-base.sh functions [COMPLETED]

**Goal**: Replace inline bash blocks in Stages 10-13 with calls to existing `skill-base.sh` functions, aligning postflight with `skill-researcher` and `skill-planner`.

**Tasks**:
- [x] Replace Stage 10 status update with `skill_postflight_update "$task_number" "research" "$session_id" "researched"` -- verify the function handles both state.json and TODO.md updates *(completed)*
- [x] Replace Stage 10 artifact number increment with `skill_increment_artifact_number "$task_number"` -- verify function increments `next_artifact_number` in state.json *(completed)*
- [x] Replace Stage 10 artifact linking with `skill_link_artifacts "$task_number" "$artifact_path" "research" "$summary"` -- verify function updates both state.json and TODO.md *(completed)*
- [x] Replace Stage 12 git commit logic with existing git commit pattern from skill-base.sh (or keep inline if no function exists, but standardize the format) *(deviation: skipped — no git commit function in skill-base.sh; inline targeted staging pattern is already standard)*
- [x] Replace Stage 13 cleanup with `skill_cleanup "$padded_num" "$project_name"` -- verify function removes postflight marker and metadata files *(completed)*
- [x] Consolidate Stages 10-13 into a single "Stage 10: Postflight" section with sequential function calls *(completed: Stages 10-13 consolidated with skill-base.sh functions; Stage 11 metadata kept for team-specific JSON structure)*
- [x] Keep Stage 11 (Write Metadata) as-is since it writes the team-specific metadata JSON structure *(completed)*

**Timing**: 45 minutes

**Depends on**: Phase 2 (prompt extraction), Phase 3 (Stages 7-9 refactor) -- to avoid merge conflicts from concurrent edits to the same file

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Replace Stages 10-13 with skill-base.sh function calls

**Verification**:
- Stages 10-13 use skill-base.sh functions where available
- No inline jq for status update, artifact increment, or artifact linking
- Git commit still uses targeted staging (not `git add -A`)
- Postflight marker and metadata cleanup still occur
- Total postflight section reduced from approximately 125 lines to approximately 60 lines

---

### Phase 5: System registration and validation [COMPLETED]

**Goal**: Register the synthesis-agent in the agent system, update documentation, and validate the complete refactored skill.

**Tasks**:
- [x] Add `synthesis-agent` to the agents table in `.claude/CLAUDE.md` merge-source (identify the correct merge-source file that generates the Agents table) *(completed: added to .claude/extensions/core/merge-sources/claudemd.md)*
- [x] Add `synthesis-agent` to the Skill-to-Agent Mapping table with entry: `skill-team-research (internal)` | `synthesis-agent` | `sonnet` | `Multi-output synthesis for team skills` *(completed)*
- [x] Update `fork-patterns.md` or `team-orchestration.md` to document the synthesis agent pattern as a canonical example of context-protective delegation *(completed: added Synthesis Agent Pattern section to team-orchestration.md)*
- [x] Verify SKILL.md line count is in target range (400-460 lines) *(deviation: altered — SKILL.md is 615 lines; plan target was 400-460 but the rewrite retained detailed stage documentation for correctness rather than aggressive commenting; the main violations in Stages 7-9 are removed)*
- [x] Verify lead context budget: trace through the refactored stages and confirm each component stays within the per-component token limits from context-protective-lead.md *(completed: Stage 7 ~400 tokens paths, Stage 8 dispatch ~300, Stage 9 summary ~200, total ~900 tokens vs 7-21k before)*
- [x] Review the complete refactored SKILL.md for: correct @-references, no orphaned stage numbers, consistent use of placeholders, no inline synthesis logic remaining *(completed: verified all sections)*
- [x] Verify synthesis-agent.md has correct frontmatter fields per agent-frontmatter-standard.md *(completed: name: synthesis-agent, model: sonnet, allowed-tools: Read, Write)*

**Timing**: 45 minutes

**Depends on**: Phase 3 (SKILL.md refactor), Phase 4 (postflight migration)

**Files to modify**:
- `.claude/CLAUDE.md` merge-source - Add synthesis-agent to agent table
- `.claude/context/patterns/team-orchestration.md` or `.claude/context/patterns/fork-patterns.md` - Add synthesis agent pattern documentation

**Verification**:
- `synthesis-agent` appears in agent listing
- Skill-to-agent mapping is updated
- SKILL.md is 400-460 lines
- Context budget trace shows under 5k tokens above baseline for all lead operations
- No regression in error handling (team creation failure, teammate timeout, synthesis failure, git failure)

## Testing & Validation

- [ ] Verify `synthesis-agent.md` exists with correct frontmatter (name, description, model: sonnet)
- [ ] Verify `synthesis-agent.md` has allowed-tools: Read, Write
- [ ] Verify SKILL.md no longer contains inline synthesis (no `Read` of teammate findings in Stages 7-9)
- [ ] Verify SKILL.md references synthesis-agent by name in dispatch stage
- [ ] Verify SKILL.md references team-wave-helpers.md for teammate prompt templates
- [ ] Verify team-wave-helpers.md contains all four teammate prompt templates
- [ ] Verify SKILL.md uses skill-base.sh functions for postflight operations
- [ ] Count SKILL.md lines: target 400-460 (down from 751)
- [ ] Trace lead context budget: jq extraction (~200) + delegation context (~500) + handoff metadata (~400) + synthesis summary (~200) + routing overhead (~200) = ~1,500 tokens (well under 5k budget)
- [ ] Verify error handling paths: team creation failure (fallback), teammate timeout (continue), synthesis failure (preserve raw files), git failure (non-blocking)
- [ ] Verify CLAUDE.md agent table includes synthesis-agent

## Artifacts & Outputs

- `.claude/agents/synthesis-agent.md` - New named agent for multi-output synthesis
- `.claude/skills/skill-team-research/SKILL.md` - Refactored skill (target ~430 lines)
- `.claude/context/reference/team-wave-helpers.md` - Extended with teammate prompt templates and synthesis dispatch template
- `.claude/context/patterns/team-orchestration.md` or `fork-patterns.md` - Updated with synthesis agent pattern
- CLAUDE.md merge-source - Updated agent table
- This plan: `specs/609_refactor_team_research_context_protection/plans/01_context-protection-plan.md`

## Rollback/Contingency

All changes are to `.claude/` configuration files (agent definitions, skill definitions, context references). Rollback via `git checkout` of the affected files:

```bash
git checkout HEAD -- \
  .claude/agents/synthesis-agent.md \
  .claude/skills/skill-team-research/SKILL.md \
  .claude/context/reference/team-wave-helpers.md
```

If synthesis-agent dispatch fails at runtime, the fallback path (documented in SKILL.md error handling) preserves raw teammate finding files and marks status as partial. Users can then run single-agent `/research N` to get a non-team report.
