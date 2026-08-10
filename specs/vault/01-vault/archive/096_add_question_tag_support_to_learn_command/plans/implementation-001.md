# Implementation Plan: Task #96

- **Task**: 96 - Add QUESTION: tag support to /learn command
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Expand the /learn command to recognize `QUESTION:` tags in source code comments alongside the existing `FIX:`, `NOTE:`, and `TODO:` tags. QUESTION: tags create "research-task" type tasks aimed at answering embedded questions. The implementation reuses the existing topic grouping algorithm for clustering related questions and follows the same interactive selection pattern as TODO: tags. A key design decision (per user override) is that task language is inferred from the **content** of the question, not the file type where the tag appears, defaulting to "general" for most research tasks.

### Research Integration

Research report (research-001.md) identified the 4-file modification scope, the tag extraction pipeline stages, topic grouping reuse strategy, and research-task type design. The user overrode the research recommendation for file-type-based language detection, requiring content-based inference instead.

## Goals & Non-Goals

**Goals**:
- Add QUESTION: tag extraction to the scan pipeline (all supported file types)
- Create a "research-task" task type with question-oriented description format
- Implement content-based language detection for research tasks (not file-type-based)
- Reuse existing topic grouping logic for clustering related questions
- Follow the interactive selection pattern established by TODO: tags
- Update all documentation (command, skill, flow example, multi-task standard)

**Non-Goals**:
- Automatic dependency relationships between QUESTION: tags and other tag types
- Multi-line question support (questions must fit on a single comment line)
- Natural language processing for language detection (keyword heuristics are sufficient)
- Changes to existing FIX:/NOTE:/TODO: behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content-based language detection produces incorrect results | Tasks routed to wrong research agent | Medium | Default to "general" for ambiguous cases; keyword matching is conservative |
| Topic grouping produces poor clusters for questions | Confusing grouped research tasks | Low | User always has "Keep as separate tasks" fallback option |
| QUESTION: tags rare in practice, low feature adoption | Wasted implementation effort | Low | Implementation cost is low (follows existing patterns); even rare use has value |
| Long question text causes UI truncation issues | Poor display in selection prompts | Low | Use same 50-char truncation as TODO:, full text in description |

## Implementation Phases

### Phase 1: Add QUESTION: Tag Extraction to Skill [COMPLETED]

**Goal**: Extend the tag extraction pipeline in SKILL.md to scan for QUESTION: tags alongside existing tags.

**Tasks**:
- [ ] Add Step 3.4 (between current 3.3 and 3.4) for QUESTION: tag extraction with grep patterns for all file types (.lua, .tex, .md, .py/.sh/.yaml/.yml)
- [ ] Add `question_tags[]` array to the categorization in Step 3.4 (Parse Results), updating the tag type list to include QUESTION
- [ ] Add QUESTION: Tags display section to Step 4 (Display Tag Summary)
- [ ] Update Step 5 "No Tags Found" message to include QUESTION: in the list of scanned tag types
- [ ] Update Step 5 "Only Certain Tag Types" conditional to include: QUESTION: tags exist -> offer "Research tasks"

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-learn/SKILL.md` - Steps 3, 4, 5

**Verification**:
- SKILL.md contains grep patterns for QUESTION: across all 4 file type groups
- question_tags[] array is documented in Step 3.4
- Display section for QUESTION: tags follows the same format as FIX:/NOTE:/TODO: sections
- Edge case handling includes QUESTION: in the tag type list

---

### Phase 2: Add Interactive Selection for QUESTION: Tags [COMPLETED]

**Goal**: Implement the task type selection option and individual question selection flow, mirroring the TODO: pattern.

**Tasks**:
- [ ] Add "Research tasks" option to Step 6 (Task Type Selection) AskUserQuestion, conditional on QUESTION: tags existing
- [ ] Add Step 7 variant for QUESTION: individual selection (same multiSelect pattern as TODO selection, including >20 "Select all" option)
- [ ] Add Step 7.5 equivalent for QUESTION: topic grouping (reuse identical clustering algorithm; action_type defaults to "research" for all items)
- [ ] Add Step 7.5.4 equivalent for topic group confirmation prompt (same 3 options: accept groups, separate, combined)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-learn/SKILL.md` - Steps 6, 7, 7.5

**Verification**:
- "Research tasks" option appears in Step 6 only when QUESTION: tags exist
- Individual question selection uses same multiSelect pattern as TODO selection
- Topic grouping reuses existing algorithm with action_type defaulting to "research"
- Grouping confirmation prompt matches TODO grouping prompt format

---

### Phase 3: Add Research-Task Creation Logic [COMPLETED]

**Goal**: Implement the task creation logic for research-tasks with content-based language detection.

**Tasks**:
- [ ] Add Step 8.5 for research-task creation with three modes (grouped, combined, separate) mirroring Step 8.4
- [ ] Implement content-based language detection function that analyzes question text for domain keywords instead of using source file type
- [ ] Define keyword-to-language mapping: neovim keywords (nvim, neovim, plugin, lazy, telescope, treesitter, lsp, buffer, window, keymap), latex keywords (theorem, proof, lemma, axiom, logic, formula, derivation), meta keywords (.claude, command, agent, skill, workflow, state.json), default to "general" for all other cases
- [ ] Implement title format: "Research: {question content, truncated to 60 chars}" for separate mode; "{topic_label}: {N} research questions" for grouped mode
- [ ] Implement description format using blockquote syntax for questions: "> {question text}" with source file:line reference
- [ ] Implement effort scaling: 1-2 hours base for single questions, base 1.5 hours + 30 min per additional item for grouped

**Timing**: 1 hour

**Files to modify**:
- `.claude/skills/skill-learn/SKILL.md` - New Step 8.5, content-based language detection subsection

**Verification**:
- Separate mode creates tasks with "Research: {question}" title format
- Grouped mode creates tasks with "{topic}: {N} research questions" title format
- Language detection uses question content keywords, NOT source file type
- A math question in a .tex file produces language "general" (not "latex")
- A neovim API question in a .lua file produces language "neovim"
- Effort scaling follows documented formula

---

### Phase 4: Update State Management and Output [COMPLETED]

**Goal**: Integrate research-tasks into state updates, results display, and git commit messaging.

**Tasks**:
- [ ] Update Step 9 (Update State Files) patterns to handle research-task entries in state.json and TODO.md
- [ ] Update Step 10 (Display Results) table to include "research" task type row
- [ ] Update Step 11 (Git Commit) to account for research tasks in commit message
- [ ] Update the Standards Reference compliance table at bottom of SKILL.md to list QUESTION: in Discovery row
- [ ] Update the skill frontmatter description to include QUESTION: in the tag list

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-learn/SKILL.md` - Steps 9, 10, 11, frontmatter, Standards Reference

**Verification**:
- state.json entries for research-tasks follow standard schema
- TODO.md entries include correct format with content-based language
- Results table shows "research" type
- Frontmatter description mentions QUESTION:
- Compliance table updated

---

### Phase 5: Update Command Documentation and Supporting Files [COMPLETED]

**Goal**: Update the learn command definition, flow example, and multi-task creation standard to reflect QUESTION: support.

**Tasks**:
- [ ] Update `.claude/commands/learn.md`: add QUESTION: to description, tag table (research-task type), interactive flow steps, supported comment styles table, task type selection example, output examples, standards compliance table
- [ ] Update `.claude/docs/examples/learn-flow-example.md`: add QUESTION: to tag table, add example scenario with QUESTION: tags showing content-based language detection, update edge case documentation
- [ ] Update `.claude/docs/reference/standards/multi-task-creation-standard.md`: update /learn discovery sources to include QUESTION:, update compliance notes

**Timing**: 45 minutes

**Files to modify**:
- `.claude/commands/learn.md` - Tag table, interactive flow, examples, compliance table
- `.claude/docs/examples/learn-flow-example.md` - Tag table, example scenario, edge cases
- `.claude/docs/reference/standards/multi-task-creation-standard.md` - Discovery sources

**Verification**:
- learn.md tag table has 4 rows (FIX, NOTE, TODO, QUESTION)
- learn.md interactive flow mentions QUESTION: at each relevant step
- learn.md output example includes a research-task row
- Flow example includes a QUESTION: scenario demonstrating content-based language detection
- Multi-task standard references QUESTION: in /learn discovery

---

## Testing & Validation

- [ ] Verify SKILL.md grep patterns for QUESTION: match all 4 file type groups (Lua, LaTeX, Markdown, Python/Shell/YAML)
- [ ] Verify content-based language detection: neovim keyword in question -> "neovim", latex keyword -> "latex", meta keyword -> "meta", ambiguous -> "general"
- [ ] Verify topic grouping reuses existing algorithm without modification (action_type defaults to "research")
- [ ] Verify effort scaling formula: 1 item = "1-2 hours", 2 items = "2 hours", 3 items = "2.5 hours"
- [ ] Verify no changes to existing FIX:/NOTE:/TODO: behavior (regression check by reading unchanged sections)
- [ ] Verify all 4 files are internally consistent in their QUESTION: documentation

## Artifacts & Outputs

- `.claude/skills/skill-learn/SKILL.md` - Updated skill with QUESTION: support
- `.claude/commands/learn.md` - Updated command documentation
- `.claude/docs/examples/learn-flow-example.md` - Updated flow example
- `.claude/docs/reference/standards/multi-task-creation-standard.md` - Updated standard
- `specs/096_add_question_tag_support_to_learn_command/summaries/implementation-summary-20260225.md` - Implementation summary

## Rollback/Contingency

All changes are additive to existing documentation files. Rollback is straightforward: revert the 4 modified files to their pre-implementation state via `git checkout HEAD~N -- <file>` for each file. No runtime code is affected; these are instruction files for the Claude agent system.
