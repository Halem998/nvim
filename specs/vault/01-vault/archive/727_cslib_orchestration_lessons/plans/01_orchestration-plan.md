# Implementation Plan: Task #727

- **Task**: 727 - cslib_orchestration_lessons
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/727_cslib_orchestration_lessons/reports/01_orchestration-lessons.md
- **Artifacts**: plans/01_orchestration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply lessons from CSLib tasks 208-213 lint fix orchestration to improve the cslib extension's agent infrastructure. The research report identified 5 failure modes (context exhaustion, analysis paralysis, file conflicts, stale metadata, inaccurate counts) and proposed 5 concrete fixes. This plan implements those as rules, agent enhancements, and planner context within `.claude/extensions/cslib/`, targeting the specific files that agents and planners read during lint-fix task orchestration.

### Research Integration

Key findings from the research report (01_orchestration-lessons.md):
- **F1**: Context exhaustion on mechanical tasks (>50 edits) -- agents read entire files instead of targeted lines
- **F2**: Analysis paralysis -- agent spent 197 tool calls with zero edits on namespace fix task
- **F3**: File conflicts in parallel multi-task orchestration -- tasks sharing files ran in same wave
- **F4**: Stale `.return-meta.json` -- never updated mid-implementation, left "in_progress" on exhaustion
- **F5**: Inaccurate error counts -- plan used stale counts from task creation, not actual lint output

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation required for this meta task.

## Goals & Non-Goals

**Goals**:
- Create a dedicated lint-fix rules file with anti-analysis and context-management contracts
- Add write-first metadata pattern and lint-count preflight to cslib-implementation-agent
- Add file-overlap wave assignment guidance to planner context
- Register all new files in manifest.json and index-entries.json

**Non-Goals**:
- Creating a separate `lint-fix` task type with its own routing (too heavy -- a rules file activated by lint-fix keywords in the task description is sufficient)
- Modifying orchestrator code or scripts (those live outside the extension)
- Changing files in ~/Projects/cslib/ (the CSLib project itself)
- Implementing conflict matrix generation in the planner agent itself (that would require changes to shared planner-agent.md, outside cslib extension scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Anti-analysis rule too aggressive (15 tool call limit may not suit all lint types) | M | M | Make the threshold configurable in the rule text, note exceptions for complex lint categories |
| Write-first metadata adds complexity to agent that may confuse it | M | L | Keep the additions minimal -- only add the incremental update pattern, not a whole new protocol |
| New rules file not loaded by agent (index-entries misconfigured) | H | L | Verify index-entries.json registration in Phase 4 testing |
| File-overlap guidance ignored by planner (planner reads too much context already) | M | M | Keep the guidance concise (<50 lines) and position it as a checklist, not a lengthy document |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Lint-Fix Rules File [COMPLETED]

**Goal**: Create a new rules file that activates anti-analysis, context-management, and progress-tracking contracts for lint-fix tasks.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/rules/cslib-lint-fix.md` with frontmatter `paths: "**/*.lean"`
- [ ] Include anti-analysis contract: first Edit/Write within 15 tool calls for lint-fix tasks
- [ ] Include lint-driven targeting: run `lake lint` first, parse output, use Read with offset/limit for flagged lines only
- [ ] Include batch-edit pattern: accumulate edits without re-reading files for mechanical changes
- [ ] Include checkpoint handoff: write handoff every 30 edits for tasks with >50 edit sites
- [ ] Include progress tracking: re-run lint count after every 10 edits
- [ ] Include phase-scoped context: complete each phase as self-contained block, do not accumulate cross-phase file contents
- [ ] Add activation clause: rules apply when task description contains "lint", "linter", or plan references lint categories

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/rules/cslib-lint-fix.md` - New file

**Verification**:
- File exists with correct frontmatter
- Rules are clear, actionable, and reference specific tool patterns
- Activation clause scopes the rules to lint-fix work only

---

### Phase 2: Enhance Implementation Agent with Write-First Metadata and Lint Preflight [COMPLETED]

**Goal**: Add incremental metadata updates and lint-count verification to the cslib-implementation-agent.

**Tasks**:
- [ ] Add "Write-First Metadata Pattern" section to cslib-implementation-agent.md after the Stage 0 section
- [ ] Document incremental `.return-meta.json` updates: update `phases_completed` and `lint_count_current` after each phase completion
- [ ] Add "Lint-Count Preflight" section to cslib-implementation-agent.md before the Phase Checkpoint Protocol
- [ ] Document: at implementation start, run the relevant linter, compare count to plan's stated count, log warning if >20% divergence
- [ ] Add `lint_count_start` and `lint_count_current` fields to the metadata schema example in Stage 0

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Add two new sections

**Verification**:
- Agent file contains Write-First Metadata Pattern section
- Agent file contains Lint-Count Preflight section
- Metadata schema example includes lint count fields
- No duplicate or contradictory instructions with existing Stage 0 early metadata

---

### Phase 3: Create File-Overlap Wave Assignment Context [COMPLETED]

**Goal**: Create a planner-facing context document that guides wave assignment for multi-task lint-fix orchestration.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/context/project/cslib/patterns/lint-fix-wave-assignment.md`
- [ ] Document file-overlap analysis: for each task, collect files from plan; build overlap graph; tasks with >30% overlap go in sequential waves
- [ ] Document conflict matrix format: table of task pairs with shared file counts
- [ ] Include practical example from tasks 210/211 (renames vs keyword changes sharing declaration files)
- [ ] Document lint-driven targeting as mitigation: agents using live `lake lint` output are resilient to prior renames
- [ ] Note worktree isolation as an alternative for tasks identified in the conflict matrix

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/context/project/cslib/patterns/lint-fix-wave-assignment.md` - New file

**Verification**:
- File exists with clear guidance
- Conflict matrix example is included
- Guidance is actionable by a planner agent (not just explanatory)

---

### Phase 4: Register New Files and Verify Integration [COMPLETED]

**Goal**: Register the new rules file and context file in manifest.json and index-entries.json, and verify all files load correctly.

**Tasks**:
- [ ] Add `"cslib-lint-fix.md"` to `provides.rules` array in manifest.json
- [ ] Add index entry for `project/cslib/patterns/lint-fix-wave-assignment.md` in index-entries.json with `load_when.agents` including `"planner-agent"` and `"planner-hard-agent"`
- [ ] Add `"lint-fix"` keyword to `keyword_overrides.cslib.keywords` array in manifest.json (so lint tasks get cslib routing)
- [ ] Verify all files pass basic validation: rules file has correct frontmatter, context file exists at registered path, manifest.json is valid JSON
- [ ] Verify index-entries.json is valid JSON with no duplicate paths

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - Add rule, update keywords
- `.claude/extensions/cslib/index-entries.json` - Add context entry

**Verification**:
- `jq '.' manifest.json` succeeds (valid JSON)
- `jq '.' index-entries.json` succeeds (valid JSON)
- New rules file appears in `provides.rules`
- New context file appears in index-entries with correct `load_when`
- `"lint-fix"` appears in keyword_overrides

## Testing & Validation

- [ ] All modified/created files are valid (no syntax errors in JSON files, markdown files have correct frontmatter)
- [ ] `cslib-lint-fix.md` rules are scoped to lint-fix tasks (not applied to all cslib tasks)
- [ ] `cslib-implementation-agent.md` new sections do not conflict with existing Stage 0 or Phase Checkpoint Protocol
- [ ] `lint-fix-wave-assignment.md` is discoverable by planner agents via index-entries.json
- [ ] manifest.json `provides.rules` includes the new rule
- [ ] No files outside `.claude/extensions/cslib/` are modified

## Artifacts & Outputs

- `.claude/extensions/cslib/rules/cslib-lint-fix.md` - New lint-fix behavioral rules
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` - Enhanced with write-first metadata + lint preflight
- `.claude/extensions/cslib/context/project/cslib/patterns/lint-fix-wave-assignment.md` - New planner guidance
- `.claude/extensions/cslib/manifest.json` - Updated provides.rules + keywords
- `.claude/extensions/cslib/index-entries.json` - New context entry
- `specs/727_cslib_orchestration_lessons/plans/01_orchestration-plan.md` - This plan

## Rollback/Contingency

All changes are additive (new files + append-only edits to manifest/index). Rollback:
1. Delete the new files: `cslib-lint-fix.md`, `lint-fix-wave-assignment.md`
2. Revert `cslib-implementation-agent.md` to remove the two added sections
3. Revert `manifest.json` and `index-entries.json` to remove added entries
4. Git revert the implementation commit
