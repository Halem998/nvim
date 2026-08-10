# Implementation Plan: Task #717

- **Task**: 717 - Create skill-cite direct execution skill
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 716
- **Research Inputs**: specs/717_create_skill_cite_verification/reports/01_skill-cite-research.md
- **Artifacts**: plans/01_skill-cite-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a direct execution skill at `.claude/extensions/literature/skills/skill-cite/SKILL.md` that verifies citation claims in task artifacts against the Literature/ index and Zotero library. The skill follows the `/fix-it` pattern: extract citations, search for matches, score confidence, present findings interactively, and create tasks for unverified claims. Also update the literature extension manifest to register the new skill.

### Research Integration

The research report (01_skill-cite-research.md) provides:
- Complete cite-extract.sh JSON output schema (claim, source_text, line_number, confidence, pattern_type)
- Complete zotero-search.sh JSON output schema (citation_key, title, authors, year, score, pdf_paths, abstract_snippet)
- Literature/ index.json entry schema with keyword matching approach
- Confidence scoring methodology (confirmed/partial/unconfirmed/gap)
- SKILL.md frontmatter requirements and structure
- AskUserQuestion multiSelect pattern from skill-fix-it

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create SKILL.md with complete execution flow for citation verification
- Integrate cite-extract.sh for citation extraction from task artifacts
- Integrate Literature/ index and zotero-search.sh for source matching
- Implement confidence scoring (confirmed/partial/unconfirmed/gap)
- Follow multi-task creation standard for interactive selection and task creation
- Register skill-cite in the literature extension manifest.json

**Non-Goals**:
- Creating a separate agent (this is direct execution)
- Modifying cite-extract.sh or zotero-search.sh
- Creating the /cite command entry in CLAUDE.md (handled by extension loader)
- Building a citation database or bibliography manager

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| SKILL.md structure diverges from skill-fix-it pattern | M | L | Follow skill-fix-it step-by-step as template |
| manifest.json update breaks extension loading | H | L | Minimal change: add one entry to provides.skills array |
| Confidence scoring logic too complex for SKILL.md | M | L | Keep scoring as simple threshold checks, not algorithm |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Create SKILL.md and Register in Manifest [COMPLETED]

**Goal**: Create the complete skill-cite SKILL.md file and register it in the literature extension manifest.

**Tasks**:
- [x] Create directory `.claude/extensions/literature/skills/skill-cite/` *(completed)*
- [x] Create SKILL.md with frontmatter (name: skill-cite, description, allowed-tools: Bash, Read, Write, Edit, AskUserQuestion) *(completed)*
- [x] Write Step 1: Parse Arguments -- accept task number N or file path as argument *(completed)*
- [x] Write Step 2: Generate Session ID -- standard `sess_$(date +%s)_$(od ...)` pattern *(completed)*
- [x] Write Step 3: Locate Task Artifacts -- read state.json to find task slug, then glob `specs/{NNN}_{SLUG}/reports/*.md`, `plans/*.md`, `summaries/*.md`; also support direct file path argument *(completed)*
- [x] Write Step 4: Extract Citations -- for each artifact file, run `cite-extract.sh --format=json` and aggregate results into a combined array; include file path in each result object *(completed)*
- [x] Write Step 5: Handle No Citations -- if no citations found across all artifacts, report and exit gracefully (same as fix-it Step 5) *(completed)*
- [x] Write Step 6: Search Literature/ Index -- for each unique citation claim, extract query terms from `source_text`, search `specs/literature/index.json` entries by keyword overlap (title + keywords fields); record match scores *(completed)*
- [x] Write Step 7: Search Zotero -- for each unique citation claim, run `zotero-search.sh --format=json --limit=5` with query terms from `source_text`; gracefully degrade if Zotero not configured (exit 1) *(completed)*
- [x] Write Step 8: Score Confidence -- apply scoring methodology: confirmed (zotero score >= 3 OR index keyword overlap >= 2), partial (zotero score 1-2 OR index overlap 1), unconfirmed (no match), gap (pattern found but source unavailable); compute composite confidence *(completed)*
- [x] Write Step 9: Display Results -- show all citations grouped by confidence status (confirmed first as display-only, then partial, then unconfirmed/gap as actionable); include source_text, file:line, pattern_type, match details *(completed)*
- [x] Write Step 10: Interactive Selection -- AskUserQuestion with multiSelect for unconfirmed/gap claims; include "Select all" option when >20 items; partial claims offered with lower priority in separate prompt *(completed)*
- [x] Write Step 11: Task Creation -- for each selected claim, create task in state.json (task_type from parent task or "general"); use two-step jq pattern; topic auto-infer from source file paths *(completed)*
- [x] Write Step 12: State Update and Commit -- update state.json with new tasks, call generate-todo.sh, git commit with session ID *(completed)*
- [x] Write Error Handling section -- cite-extract.sh failures, zotero-search.sh failures, state.json write failures, git commit failures (non-blocking) *(completed)*
- [x] Add `"skill-cite"` to `provides.skills` array in `.claude/extensions/literature/manifest.json` *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/skills/skill-cite/SKILL.md` - Create new skill file
- `.claude/extensions/literature/manifest.json` - Add skill-cite to provides.skills

**Verification**:
- SKILL.md exists with correct frontmatter (name, description, allowed-tools)
- SKILL.md follows the 12-step execution flow covering extraction, search, scoring, display, selection, and task creation
- manifest.json includes "skill-cite" in provides.skills array
- All steps reference correct script paths and JSON schemas from research report

## Testing & Validation

- [ ] SKILL.md has valid YAML frontmatter with name, description, and allowed-tools fields
- [ ] Step 4 uses `cite-extract.sh --format=json` with correct invocation pattern
- [ ] Step 7 uses `zotero-search.sh --format=json --limit=5` with graceful degradation
- [ ] Step 8 scoring matches the methodology from the research report (confirmed/partial/unconfirmed/gap thresholds)
- [ ] Step 10 follows AskUserQuestion multiSelect pattern from skill-fix-it
- [ ] Step 11 follows state.json update pattern (two-step jq, generate-todo.sh)
- [ ] manifest.json is valid JSON after adding skill-cite entry
- [ ] No references to nonexistent scripts or tools

## Artifacts & Outputs

- `.claude/extensions/literature/skills/skill-cite/SKILL.md` - The skill definition file
- `.claude/extensions/literature/manifest.json` - Updated with skill-cite registration
- `specs/717_create_skill_cite_verification/plans/01_skill-cite-plan.md` - This plan

## Rollback/Contingency

Remove the created directory and revert the manifest.json change:
```bash
rm -rf .claude/extensions/literature/skills/skill-cite/
git checkout -- .claude/extensions/literature/manifest.json
```
