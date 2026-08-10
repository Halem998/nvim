# Research Report: Task #221

**Task**: 221 - fix_phase_status_markers_implementation_agents
**Started**: 2026-03-17T12:00:00Z
**Completed**: 2026-03-17T12:15:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of implementation agents and skills
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Three implementation agents have inconsistent phase status marker handling: grant-agent, latex-implementation-agent, and typst-implementation-agent
- The reference implementation (general-implementation-agent.md) has a complete "Phase Checkpoint Protocol" section with detailed Stage 4A/4D instructions and per-phase git commits
- skill-grant lacks calls to update-plan-status.sh unlike skill-implementer which calls it at preflight (IMPLEMENTING) and postflight (COMPLETED/PARTIAL)
- Recommended: Add Phase Checkpoint Protocol to grant-agent, add update-plan-status.sh calls to skill-grant, expand latex/typst agents with detailed Edit tool patterns

## Context and Scope

This research examines the phase status marker handling across implementation agents to identify gaps and recommend fixes for consistency. The scope includes:

1. general-implementation-agent.md - Reference implementation (complete)
2. grant-agent.md - Missing Phase Checkpoint Protocol
3. skill-implementer SKILL.md - Reference skill with update-plan-status.sh calls
4. skill-grant SKILL.md - Missing update-plan-status.sh calls
5. latex-implementation-agent.md - Incomplete phase marker instructions
6. typst-implementation-agent.md - Incomplete phase marker instructions
7. update-plan-status.sh - Utility script for plan-level status updates

## Findings

### 1. Reference Implementation: general-implementation-agent.md

The general-implementation-agent provides a complete reference for phase status marker handling:

**Stage 4A: Mark Phase In Progress**
```markdown
**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
```

**Stage 4D: Mark Phase Complete**
```markdown
**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
```

**Phase Checkpoint Protocol Section (Lines 315-337)**
```markdown
## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
   ```
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning
```

### 2. Gap Analysis: grant-agent.md

**Current State**: The grant-agent has a detailed Execution Flow with Stage 4: Execute Workflow, but it lacks:

- No Phase Checkpoint Protocol section
- No mention of per-phase git commits
- No Edit tool patterns for phase marker updates
- Stage 4 (Execute Workflow) is workflow-specific (funder_research, proposal_draft, etc.) but doesn't reference plan-based phase execution for the `assemble` workflow

**The assemble workflow** (lines 295-328) does file assembly but lacks phase-level status tracking that would be needed if assemble followed a multi-phase plan.

**Missing Components**:
1. No Stage 4A/4D equivalents for phase status updates
2. No explicit Edit tool patterns for `[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`
3. No per-phase git commit instructions
4. No Phase Checkpoint Protocol section

### 3. Reference Skill: skill-implementer SKILL.md

skill-implementer correctly calls update-plan-status.sh at two points:

**Preflight (Stage 2, line 93-94)**:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$padded_num" "$project_name" "IMPLEMENTING"
```

**Postflight - Success (Stage 7, lines 262-265)**:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$padded_num" "$project_name" "COMPLETED"
```

**Postflight - Partial (Stage 7, lines 281-284)**:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$padded_num" "$project_name" "PARTIAL"
```

### 4. Gap Analysis: skill-grant SKILL.md

**Current State**: skill-grant has detailed status mapping tables for workflow types but **does not call update-plan-status.sh**:

- Stage 2 (Preflight Status Update) updates state.json and TODO.md but NOT the plan file's Status metadata
- Stage 7 (Postflight) updates state.json and TODO.md but NOT the plan file's Status metadata
- The workflow-to-status mapping (lines 41-52) shows this is designed but the plan file update is missing

**Missing Components**:
1. No update-plan-status.sh call in Stage 2 (Preflight)
2. No update-plan-status.sh call in Stage 7 (Postflight)
3. The `assemble` workflow should update plan status to IMPLEMENTING->COMPLETED

### 5. Gap Analysis: latex-implementation-agent.md

**Current State**: The latex-implementation-agent is a condensed version (123 lines vs 501 lines for general-implementation-agent) with minimal phase handling:

**Existing reference (lines 75-84)**:
```markdown
### Stage 4: Execute LaTeX Development Loop

For each phase:
1. Mark phase `[IN PROGRESS]`
2. Create/modify .tex files
3. Run `latexmk -pdf`
4. Check compilation result
5. Mark phase `[COMPLETED]` or `[PARTIAL]`
```

**Missing Components**:
1. No detailed Edit tool patterns showing old_string/new_string
2. No explicit instruction about "Phase status lives ONLY in the heading"
3. No Phase Checkpoint Protocol section
4. No per-phase git commit instructions
5. No Stage 6a (Generate Completion Data) for completion_summary

### 6. Gap Analysis: typst-implementation-agent.md

**Current State**: Nearly identical to latex-implementation-agent (104 lines) with same gaps:

**Existing reference (lines 58-65)**:
```markdown
### Stage 4: Execute Typst Development Loop
For each phase:
1. Mark phase `[IN PROGRESS]`
2. Create/modify .typ files
3. Run `typst compile`
4. Check compilation result
5. Mark phase `[COMPLETED]` or `[PARTIAL]`
```

**Missing Components** (same as latex):
1. No detailed Edit tool patterns showing old_string/new_string
2. No explicit instruction about "Phase status lives ONLY in the heading"
3. No Phase Checkpoint Protocol section
4. No per-phase git commit instructions
5. No Stage 6a (Generate Completion Data) for completion_summary

### 7. update-plan-status.sh Analysis

The script handles **plan-level** (metadata) status, not phase-level status:

- Updates the `- **Status**: [...]` line in plan metadata
- Accepts values: IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED
- Is idempotent (no-op if already at target status)
- Finds plan file automatically from task number and project name

**Important Distinction**:
- `update-plan-status.sh` = Plan metadata status (overall task state)
- Edit tool patterns in agents = Phase-level status (per-phase progress)

Both are needed for complete tracking.

## Recommendations

### Issue 1: grant-agent lacks Phase Checkpoint Protocol

**Action**: Add a new section "## Phase Checkpoint Protocol" to grant-agent.md, positioned after Stage 5 (Assemble Workflow) or at the end before Critical Requirements.

**Content to add** (adapted for grant workflows):
```markdown
## Phase Checkpoint Protocol

For grant tasks with implementation plans (typically `assemble` workflow):

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - Phase status lives ONLY in the heading
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

**Note**: This protocol applies primarily to the `assemble` workflow when following a multi-phase plan. Single-stage workflows (funder_research, proposal_draft, budget_develop, progress_track) may not require phase-level tracking.
```

### Issue 2: skill-grant lacks update-plan-status.sh calls

**Action 1**: Add to Stage 2 (Preflight Status Update) after TODO.md update:

```bash
# Update plan file status (if plan exists and workflow is assemble)
if [ "$workflow_type" = "assemble" ]; then
    .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "IMPLEMENTING" 2>/dev/null || true
fi
```

**Action 2**: Add to Stage 7 (Postflight) after state.json update:

For assemble success:
```bash
if [ "$workflow_type" = "assemble" ] && [ "$meta_status" = "assembled" ]; then
    .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "COMPLETED" 2>/dev/null || true
fi
```

For assemble partial:
```bash
if [ "$workflow_type" = "assemble" ] && [ "$meta_status" = "partial" ]; then
    .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "PARTIAL" 2>/dev/null || true
fi
```

### Issue 3: latex/typst agents have incomplete phase marker instructions

**Action**: Expand Stage 4 in both agents to include detailed Edit tool patterns.

**For latex-implementation-agent.md**, replace the existing Stage 4 with:

```markdown
### Stage 4: Execute LaTeX Development Loop

For each phase starting from resume point:

**A. Mark Phase In Progress**
Edit plan file heading to show the phase is active.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**B. Execute Steps**
1. Create/modify .tex files per plan instructions
2. Run `latexmk -pdf document.tex` to compile
3. Check for compilation errors
4. Fix errors iteratively

**C. Verify Phase Completion**
- Compilation must succeed
- All specified files must exist
- Cross-references must resolve

**D. Mark Phase Complete**
Edit plan file heading to show the phase is finished.
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**E. Git Commit Phase**
```bash
git add -A && git commit -m "task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```
```

Also add a "## Phase Checkpoint Protocol" section summarizing the overall protocol.

**For typst-implementation-agent.md**, apply the same expansion with `typst compile` instead of `latexmk -pdf`.

### Summary of Changes

| File | Change Type | Priority |
|------|-------------|----------|
| grant-agent.md | Add Phase Checkpoint Protocol section | High |
| skill-grant SKILL.md | Add update-plan-status.sh calls (Stage 2, Stage 7) | High |
| latex-implementation-agent.md | Expand Stage 4 with Edit patterns, add Phase Checkpoint Protocol | Medium |
| typst-implementation-agent.md | Expand Stage 4 with Edit patterns, add Phase Checkpoint Protocol | Medium |

## Decisions

1. The Phase Checkpoint Protocol should be consistent across all implementation agents
2. update-plan-status.sh should be called by skills, not agents (agents do phase-level, skills do plan-level)
3. The latex/typst agents can remain more condensed than general-implementation-agent but need the critical Edit tool patterns

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Grant workflow complexity (5 different types) | Only apply Phase Checkpoint Protocol to `assemble` workflow which uses plans |
| Over-verbosity in latex/typst agents | Keep expansion focused on Edit patterns and Phase Checkpoint; don't duplicate all detail from general-implementation-agent |
| Backward compatibility | All changes are additive; existing workflows will work |

## Appendix

### Files Analyzed

1. `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (501 lines) - Reference implementation
2. `/home/benjamin/.config/nvim/.claude/extensions/present/agents/grant-agent.md` (590 lines) - Missing Phase Checkpoint Protocol
3. `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (403 lines) - Reference skill with update-plan-status.sh
4. `/home/benjamin/.config/nvim/.claude/extensions/present/skills/skill-grant/SKILL.md` (1009 lines) - Missing update-plan-status.sh calls
5. `/home/benjamin/.config/nvim/.claude/extensions/latex/agents/latex-implementation-agent.md` (123 lines) - Incomplete phase markers
6. `/home/benjamin/.config/nvim/.claude/extensions/typst/agents/typst-implementation-agent.md` (104 lines) - Incomplete phase markers
7. `/home/benjamin/.config/nvim/.claude/scripts/update-plan-status.sh` (68 lines) - Plan status utility

### Key Line References

**general-implementation-agent.md**:
- Stage 4A (Mark Phase In Progress): Lines 135-141
- Stage 4D (Mark Phase Complete): Lines 168-175
- Phase Checkpoint Protocol: Lines 315-337

**skill-implementer SKILL.md**:
- Preflight update-plan-status.sh call: Lines 93-94
- Postflight update-plan-status.sh call (COMPLETED): Lines 262-265
- Postflight update-plan-status.sh call (PARTIAL): Lines 281-284

**skill-grant SKILL.md**:
- Stage 2 (Preflight): Lines 119-171 - missing plan update
- Stage 7 (Postflight): Lines 317-384 - missing plan update
