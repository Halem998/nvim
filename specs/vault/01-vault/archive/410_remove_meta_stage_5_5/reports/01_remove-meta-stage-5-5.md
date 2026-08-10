# Research Report: Task #410

**Task**: 410 - Remove meta Stage 5.5 auto-research artifact generation
**Started**: 2026-04-13T18:00:00Z
**Completed**: 2026-04-13T18:15:00Z
**Effort**: ~1 hour implementation
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, `/home/benjamin/.config/zed/CHANGE.md` Theme 2
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- Stage 5.5 (GenerateResearchArtifacts) spans lines 594-691 in `meta-builder-agent.md` and auto-generates shallow research boilerplate, setting tasks to RESEARCHED status
- Three files need changes: `meta-builder-agent.md` (primary), `skill-meta/SKILL.md` (return format), `multi-task-creation-standard.md` (compliance table)
- The change simplifies the `/meta` workflow: tasks start as NOT STARTED and follow normal `/research -> /plan -> /implement` lifecycle
- Key constraint: task descriptions must still include full file paths so `/research` has clear starting points

## Context & Scope

The `/meta` command creates tasks for `.claude/` system changes. Currently, Stage 5.5 auto-generates research reports from interview context and sets tasks to RESEARCHED status. This produces shallow boilerplate that real `/research` must redo anyway. Removing it simplifies the workflow without losing value, since task descriptions already capture enough context for `/research` to work effectively.

## Findings

### File 1: `.claude/agents/meta-builder-agent.md`

**Changes required (6 locations)**:

1. **Remove Stage 5.5 section** (lines 594-691, ~98 lines)
   - The entire `### Interview Stage 5.5: GenerateResearchArtifacts` section
   - Includes subsections 5.5.1 through 5.5.4
   - Contains the research report template, artifact tracking, and transition logic

2. **Update Stage 5 -> 6 transition** (line 592)
   - Current: `**If user selects "Yes"**: Proceed to Stage 5.5 (Research Artifact Generation).`
   - Change to: `**If user selects "Yes"**: Proceed to Stage 6 (CreateTasks).`

3. **Update state.json template** (lines 774-789)
   - Change `"status": "researched"` to `"status": "not_started"`
   - Remove the `"artifacts"` array with the research report object
   - Remove the note at line 792 about RESEARCHED status

4. **Update TODO.md template** (lines 794-806)
   - Change `[RESEARCHED]` to `[NOT STARTED]`
   - Remove the `- **Research**: [01_meta-research.md](...)` line

5. **Update batch insertion code** (lines 827-836)
   - Change `[RESEARCHED]` to `[NOT STARTED]` in the entry template
   - Remove `research_path` variable and `**Research**` line from the template
   - Remove the comment about "RESEARCHED status and research link" (line 827)

6. **Update DeliverSummary next_steps** (lines 1113-1118)
   - Current template says: `Run /research {first_task_num} to begin research on foundational task`
   - This is already correct (it says `/research`, not `/plan`), so no change needed here
   - The examples at lines 1166-1168, 1210-1213, 1250-1252 also already reference `/research` -- no change needed

### File 2: `.claude/skills/skill-meta/SKILL.md`

**Changes required (4 locations)**:

1. **Update summary in expected return** (line 131)
   - Change: `"Created 2 tasks for command creation workflow. Tasks start in RESEARCHED status."`
   - To: `"Created 2 tasks for command creation workflow. Tasks start in NOT STARTED status."`

2. **Remove research artifact objects from artifacts array** (lines 138-151)
   - Remove the two `"type": "research"` objects from the artifacts array
   - Keep the `"type": "task"` objects (task directory references)

3. **Update metadata fields** (lines 160-161)
   - Change `"tasks_status": "researched"` to `"tasks_status": "not_started"`

4. **Update next_steps** (line 162)
   - Change: `"Run /plan 430 to create implementation plan (research already complete)"`
   - To: `"Run /research 430 to begin research on first task"`

5. **Update the note after the return example** (lines 166-167)
   - Remove or rewrite: `**Note**: Tasks created via /meta start in RESEARCHED status because...`
   - Replace with: `**Note**: Tasks created via /meta start in NOT STARTED status. Run /research N to begin the standard research -> plan -> implement lifecycle.`

### File 3: `.claude/docs/reference/standards/multi-task-creation-standard.md`

**Changes required (4 locations)**:

1. **Remove Research Generation row from reference implementation table** (line 373)
   - Remove: `| **Research Generation** | **Interview Stage 5.5 (GenerateResearchArtifacts)** |`

2. **Remove Stage 5.5 from Enhanced Stages list** (line 378)
   - Remove: `- **Stage 5.5 (GenerateResearchArtifacts)**: Creates 01_meta-research.md from interview context for each task`

3. **Update compliance table** (lines 384-390)
   - Remove the `Research Gen` column entirely (header, separator, and all data rows)
   - Or change the `/meta` entry from `**Yes**` to `No`

4. **Remove Stage 5.5 references from Enhanced Features section** (lines 394-397)
   - Remove: `- **Research Artifact Generation** (Stage 5.5): Creates lightweight research reports from interview context`
   - Remove: `- **RESEARCHED Status**: Tasks start in researched status, enabling immediate /plan N without separate /research N`
   - Update State Updates row (line 374): change "RESEARCHED status" to "NOT STARTED status"

## Decisions

- **Remove rather than simplify**: Stage 5.5 should be fully removed, not simplified. The value proposition (skip research) was undermined by shallow output quality.
- **Keep file paths in descriptions**: Task descriptions created by meta-builder-agent must continue to include full file paths to affected files, giving `/research` clear starting points. This is already the pattern (see task 410's own description as an example).
- **No directory pre-creation needed**: Without Stage 5.5, `/meta` no longer needs to create `specs/{NNN}_{slug}/reports/` directories. The `/research` command creates these when it runs.

## Risks & Mitigations

1. **Risk**: Existing tasks created by `/meta` may have RESEARCHED status with no real research content
   - **Mitigation**: Tasks 409-413 were just created and already have the auto-generated status. The recent batch (409-413) was created from the Zed CHANGE.md and has detailed descriptions with file paths, so `/research` can work from those descriptions. No retroactive fixup needed.

2. **Risk**: Users accustomed to running `/plan N` immediately after `/meta` will need to run `/research N` first
   - **Mitigation**: The DeliverSummary template already says "Run /research {N}" as the next step. The change is self-documenting.

3. **Risk**: The prompt-mode path (Stage 3B) at line 1305 references "same as Interview Stage 6" -- need to verify it doesn't reference Stage 5.5
   - **Mitigation**: Line 1305 says "Create tasks (same as Interview Stage 6)" with no reference to Stage 5.5. No change needed.

## Appendix

### Lines affected per file

| File | Lines to modify | Lines to remove | Net change |
|------|----------------|-----------------|------------|
| `meta-builder-agent.md` | ~10 | ~98 (Stage 5.5) + ~8 (templates) | -96 lines |
| `skill-meta/SKILL.md` | ~5 | ~12 (research artifacts) | -7 lines |
| `multi-task-creation-standard.md` | ~3 | ~5 (Stage 5.5 refs) | -2 lines |
| **Total** | ~18 | ~118 | ~-105 lines |

### Key grep results for cross-references

All instances of "Stage 5.5", "5.5", "RESEARCHED", "researched", "meta-research", and "GenerateResearch" in the three target files were identified and accounted for in this report. The DeliverSummary examples (lines 1130-1253) already use `/research` as the recommended next step and need no changes.
