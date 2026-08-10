# Implementation Plan: Task #516

- **Task**: 516 - Remove claudemd_suggestions feature
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/516_remove_claudemd_suggestions_feature/reports/01_claudemd-suggestions-removal.md
- **Artifacts**: plans/01_claudemd-suggestions-removal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the obsolete `claudemd_suggestions` feature from the agent system. CLAUDE.md is now auto-generated from merge-sources, making the pattern of meta tasks proposing CLAUDE.md edits via `claudemd_suggestions` (collected during `/implement` postflight and applied interactively during `/todo`) unnecessary. The removal spans 8 primary files and 19 mirror copies across `.claude/`, `.opencode/`, and `.claude/extensions/core/` directories.

### Research Integration

Research identified all 27 files requiring modification across 8 categories: skill-implementer postflight, /todo command, general-implementation-agent, state-management schema, return-metadata-file format, CLAUDE.md merge-source, agent-template, and team-implement skill. Historical/archive data is explicitly excluded from modification. Decision: meta tasks remain excluded from ROADMAP.md matching but the exclusion note drops the claudemd_suggestions reference.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation required (roadmap_flag is false).

## Goals & Non-Goals

**Goals**:
- Remove all `claudemd_suggestions` field handling from active agent system files
- Update meta task completion workflow to use only `completion_summary`
- Maintain consistent changes across `.claude/`, `.opencode/`, and `.claude/extensions/core/` mirrors
- Preserve `completion_summary` and `roadmap_items` fields in all locations

**Non-Goals**:
- Modifying historical/archive data (`specs/archive/`, `state.json/`)
- Cleaning existing `claudemd_suggestions` values from `specs/state.json` active entries
- Changing meta task routing or task type behavior beyond removing this field

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing a reference causes runtime errors in /todo or skill-implementer | H | L | Research grep was comprehensive; post-implementation grep verification |
| .opencode/ mirrors fall out of sync with .claude/ | M | M | Handle all mirrors in same phase as primary file |
| CLAUDE.md auto-generation breaks if merge-source still references feature | M | L | Update merge-source in Phase 1, regeneration picks up change |
| Removing too much content from /todo leaves gaps in step numbering | M | L | Carefully review surrounding context when removing blocks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove from Implementation Pipeline [COMPLETED]

**Goal**: Remove `claudemd_suggestions` from all files involved in task implementation (agents, skills, templates, formats).

**Tasks**:
- [ ] `.claude/skills/skill-implementer/SKILL.md`: Remove the `claudemd_suggestions` extraction line (~line 293) and the meta task jq block (~lines 343-348). Update Step 3 header to reflect only roadmap_items.
- [ ] `.claude/agents/general-implementation-agent.md`: Remove META-specific Step 3 with claudemd_suggestions generation instructions (~lines 151-176). Remove meta task example JSON blocks. Simplify Stage 7 description (~line 214). Renumber remaining steps.
- [ ] `.claude/skills/skill-team-implement/SKILL.md`: Remove `claudemd_suggestions` line from completion_data JSON example (~line 534).
- [ ] `.claude/docs/templates/agent-template.md`: Remove "For meta tasks, also include claudemd_suggestions" clause (~line 59).
- [ ] `.claude/context/formats/return-metadata-file.md`: Remove table row (~line 152), mandatory note (~lines 155-156), and simplify meta task reference (~line 416).
- [ ] `.claude/context/reference/state-management-schema.md`: Remove field from JSON example (~line 29), completion fields table row (~line 166), and example completed meta task (~line 411).
- [ ] `.claude/extensions/core/merge-sources/claudemd.md`: Update completion workflow bullet (~line 134) to remove claudemd_suggestions reference.
- [ ] Apply same changes to all `.opencode/` mirror files (6 files).
- [ ] Apply same changes to all `.claude/extensions/core/` mirror files (6 files).
- [ ] Apply same changes to all `.opencode/extensions/core/` mirror files (6 files).

**Timing**: 1.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Remove extraction + jq block
- `.claude/agents/general-implementation-agent.md` - Remove meta-specific completion_data
- `.claude/skills/skill-team-implement/SKILL.md` - Remove JSON field
- `.claude/docs/templates/agent-template.md` - Remove clause
- `.claude/context/formats/return-metadata-file.md` - Remove field from table/notes
- `.claude/context/reference/state-management-schema.md` - Remove from schema/table/examples
- `.claude/extensions/core/merge-sources/claudemd.md` - Update bullet
- `.opencode/skills/skill-implementer/SKILL.md` - Mirror
- `.opencode/agent/subagents/general-implementation-agent.md` - Mirror
- `.opencode/skills/skill-team-implement/SKILL.md` - Mirror
- `.opencode/docs/templates/agent-template.md` - Mirror
- `.opencode/context/formats/return-metadata-file.md` - Mirror
- `.opencode/context/reference/state-management-schema.md` - Mirror
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - Mirror
- `.claude/extensions/core/agents/general-implementation-agent.md` - Mirror
- `.claude/extensions/core/skills/skill-team-implement/SKILL.md` - Mirror
- `.claude/extensions/core/docs/templates/agent-template.md` - Mirror
- `.claude/extensions/core/context/formats/return-metadata-file.md` - Mirror
- `.claude/extensions/core/context/reference/state-management-schema.md` - Mirror
- `.opencode/extensions/core/skills/skill-implementer/SKILL.md` - Mirror
- `.opencode/extensions/core/agents/general-implementation-agent.md` - Mirror (if exists)
- `.opencode/extensions/core/skills/skill-team-implement/SKILL.md` - Mirror
- `.opencode/extensions/core/docs/templates/agent-template.md` - Mirror
- `.opencode/extensions/core/context/formats/return-metadata-file.md` - Mirror
- `.opencode/extensions/core/context/reference/state-management-schema.md` - Mirror

**Verification**:
- Grep for `claudemd_suggestions` in all modified files returns no matches
- `completion_summary` and `roadmap_items` references remain intact in all files

---

### Phase 2: Remove from /todo Command [COMPLETED]

**Goal**: Remove all `claudemd_suggestions` handling from the /todo command and its mirrors.

**Tasks**:
- [ ] `.claude/commands/todo.md`: Update meta task exclusion note (~line 151) to drop claudemd_suggestions reference, keeping exclusion reason.
- [ ] `.claude/commands/todo.md`: Remove Step 3.6 "Scan Meta Tasks for CLAUDE.md Suggestions" (~lines 261-341) entirely.
- [ ] `.claude/commands/todo.md`: Remove dry-run "CLAUDE.md suggestions" output section (~lines 390-431).
- [ ] `.claude/commands/todo.md`: Remove Step 5.6 "Interactive CLAUDE.md Suggestion Selection" (~lines 719-854) entirely.
- [ ] `.claude/commands/todo.md`: Remove CLAUDE.md output lines (~lines 1096-1098).
- [ ] `.claude/commands/todo.md`: Remove CLAUDE.md row from section inclusion rules table (~line 1114).
- [ ] `.claude/commands/todo.md`: Remove conditional output rules for CLAUDE.md suggestions (~lines 1116-1127).
- [ ] `.claude/commands/todo.md`: Remove appendix subsection "Interactive CLAUDE.md Application" (~lines 1247-1267).
- [ ] Apply same changes to `.opencode/commands/todo.md` (uses "AGENTS.md" instead of "CLAUDE.md").
- [ ] Apply same changes to `.claude/extensions/core/commands/todo.md`.
- [ ] Apply same changes to `.opencode/extensions/core/commands/todo.md`.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/todo.md` - Remove Steps 3.6, 5.6, dry-run section, output sections, appendix
- `.opencode/commands/todo.md` - Mirror (AGENTS.md variant)
- `.claude/extensions/core/commands/todo.md` - Mirror
- `.opencode/extensions/core/commands/todo.md` - Mirror

**Verification**:
- Grep for `claudemd_suggestions` in all todo.md files returns no matches
- Step numbering remains consistent (no gaps or dangling references)
- Remaining /todo functionality (archival, ROADMAP.md, CHANGE_LOG) is intact

---

### Phase 3: Verification and Cleanup [COMPLETED]

**Goal**: Verify complete removal across the entire codebase and ensure no broken references remain.

**Tasks**:
- [ ] Run comprehensive grep for `claudemd_suggestions` across entire codebase (excluding `specs/archive/`, `state.json/`, and `specs/OC_504_*`)
- [ ] Verify zero matches in active files (any remaining matches should be in archive/historical data only)
- [ ] Verify `completion_summary` references are intact in all modified files
- [ ] Verify `roadmap_items` references are intact in all modified files
- [ ] Check that step/section numbering is consistent in `/todo` command files
- [ ] Spot-check that `.opencode/` mirrors match `.claude/` changes

**Timing**: 0.25 hours (15 minutes)

**Depends on**: 1, 2

**Files to modify**:
- None (verification only; fixes applied inline if issues found)

**Verification**:
- `grep -rn "claudemd_suggestions" --exclude-dir=archive --exclude-dir=state.json` returns only historical/archive matches
- No broken cross-references in modified files

## Testing & Validation

- [ ] Grep confirms zero `claudemd_suggestions` references in active system files
- [ ] `completion_summary` field remains documented in schema and used in implementation agent
- [ ] `roadmap_items` field remains documented and functional
- [ ] Meta task exclusion note in /todo updated to not reference obsolete feature
- [ ] Mirror consistency: `.claude/` primary files match `.opencode/` and `.claude/extensions/core/` counterparts

## Artifacts & Outputs

- 27 modified files (8 primary + 19 mirrors) with `claudemd_suggestions` references removed
- Updated merge-source triggers auto-regeneration of `.claude/CLAUDE.md`

## Rollback/Contingency

All changes are text deletions and minor edits in markdown/documentation files. Rollback via `git revert` of the implementation commit(s). No code execution, no schema migrations, no data loss risk.
