# Research Report: Task #96

**Task**: 96 - Add QUESTION: tag support to /learn command
**Started**: 2026-02-25T00:00:00Z
**Completed**: 2026-02-25T00:10:00Z
**Effort**: 3-4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .claude/commands/learn.md, .claude/skills/skill-learn/SKILL.md, .claude/docs/examples/learn-flow-example.md, .claude/docs/reference/standards/multi-task-creation-standard.md
**Artifacts**: This report
**Standards**: report-format.md, CLAUDE.md

## Executive Summary

- The /learn command currently recognizes FIX:, NOTE:, and TODO: tags, each mapping to distinct task types (fix-it-task, learn-it-task, todo-task)
- Adding QUESTION: tag support requires changes to 4 files: the command definition, the skill implementation, the flow example, and the multi-task creation standard compliance table
- QUESTION: tags should map to a new "research-task" type that creates tasks with `language` inferred from source file type and a research-oriented description format
- Topic grouping logic already exists for TODO: tags and can be reused directly for QUESTION: tags with minimal adaptation

## Context and Scope

The task requires expanding the /learn command to recognize `QUESTION:` tags in source code comments. When found, these create research tasks aimed at answering the embedded questions. The implementation must follow established patterns for tag extraction, interactive selection, and topic grouping.

## Findings

### 1. Current Tag Architecture

The /learn command processes tags through a well-defined pipeline:

1. **Extraction** (Step 3 in SKILL.md): grep patterns per file type, categorized into `fix_tags[]`, `note_tags[]`, `todo_tags[]`
2. **Display** (Step 4): Summary sections per tag type
3. **Task Type Selection** (Step 6): AskUserQuestion with multiSelect, options conditional on tag existence
4. **Individual Selection** (Step 7): Per-item selection for TODO: tags
5. **Topic Grouping** (Step 7.5): Clustering by shared terms / file section / action type (for TODO: only when 2+ selected)
6. **Task Creation** (Step 8): Type-specific creation logic with dependency handling
7. **State Updates** (Step 9): state.json + TODO.md atomic updates

Each tag type has a dedicated code path in Steps 6 and 8. Adding QUESTION: requires inserting into each of these stages.

### 2. Tag-to-Task Type Mapping

Current mapping in `learn.md` line 30-35:

| Tag | Task Type | Behavior |
|-----|-----------|----------|
| `FIX:` | fix-it-task | All FIX:/NOTE: grouped into single task |
| `NOTE:` | fix-it-task + learn-it-task | Two task types with optional dependency |
| `TODO:` | todo-task | Individual or topic-grouped tasks |

The new mapping should be:

| Tag | Task Type | Behavior |
|-----|-----------|----------|
| `QUESTION:` | research-task | Individual or topic-grouped research tasks |

### 3. Extraction Pattern for QUESTION: Tags

The existing grep patterns follow a consistent structure per file type. QUESTION: tags use the same comment prefixes:

**Lua files**: `grep -rn --include="*.lua" "-- QUESTION:" $paths 2>/dev/null || true`
**LaTeX files**: `grep -rn --include="*.tex" "% QUESTION:" $paths 2>/dev/null || true`
**Markdown files**: `grep -rn --include="*.md" "<!-- QUESTION:" $paths 2>/dev/null || true`
**Python/Shell/YAML**: `grep -rn --include="*.py" --include="*.sh" --include="*.yaml" --include="*.yml" "# QUESTION:" $paths 2>/dev/null || true`

Results categorized into `question_tags[]` alongside the existing arrays.

### 4. Research-Task Type Design

The research-task type is analogous to todo-task but with research-oriented semantics:

**Key differences from todo-task**:
- **Default language**: Should generally be set based on the *topic* of the question rather than the source file type. However, for consistency with existing /learn behavior, language detection from source file type is the pragmatic choice. The researcher agent will determine the actual research approach based on task content.
- **Description format**: Should frame the content as a question to be answered, not an action to be taken
- **Task title**: Should preserve the question text (possibly prefixed with "Research:" or "Investigate:")
- **Effort scaling**: Same formula as TODO (base 1 hour + 30 min per additional item in a group)

**Proposed task creation format (separate mode)**:
```json
{
  "title": "Research: {question content, truncated to 60 chars}",
  "description": "Answer the following question:\n\n> {full question text}\n\nSource: {file}:{line}",
  "language": "{detected from file type}",
  "effort": "1-2 hours"
}
```

**Proposed task creation format (grouped mode)**:
```json
{
  "title": "{topic_label}: {item_count} research questions",
  "description": "Answer research questions related to {topic_label}:\n\n{question_list}\n\n---\n\nShared context: {shared_terms_description}",
  "language": "{detected from majority file type in group}",
  "effort": "{scaled_effort}"
}
```

Where `{question_list}` uses a blockquote format:
```
- [ ] > {question 1} (`{file}:{line}`)
- [ ] > {question 2} (`{file}:{line}`)
```

### 5. Topic Grouping Reuse

The topic grouping logic in Step 7.5 of SKILL.md is designed generically around:
- **Key terms extraction** (significant words from content)
- **File section proximity** (shared directory path)
- **Action type similarity** (implement, fix, document, test, refactor)

For QUESTION: tags, the action type dimension is less relevant since questions are inherently research-oriented. However, the key terms and file section dimensions apply directly. The clustering algorithm (2+ shared significant terms OR same file_section + action_type) works without modification.

**Recommended approach**: Reuse the identical clustering algorithm. For QUESTION: tags, the action_type can default to "research" for all items, meaning clustering will rely primarily on shared key terms and file section proximity. This is actually desirable since questions about the same topic should group together regardless of where they appear.

### 6. Interactive Selection Flow

The interactive flow needs these additions:

**Step 6 (Task Type Selection)**: Add a new option:
```json
{
  "label": "Research tasks",
  "description": "Create research tasks for {N} QUESTION: items"
}
```
This option is only shown if QUESTION: tags exist.

**Step 7 equivalent for QUESTION:**: Individual question selection (same pattern as TODO selection):
```json
{
  "question": "Select QUESTION: items to create as research tasks:",
  "header": "Research Question Selection",
  "multiSelect": true,
  "options": [
    {
      "label": "{question content truncated to 50 chars}",
      "description": "{file}:{line}"
    }
  ]
}
```

**Step 7.5 equivalent**: Topic grouping confirmation (identical pattern to TODO grouping). Only triggered when 2+ questions are selected.

### 7. Files Requiring Modification

| File | Changes |
|------|---------|
| `.claude/commands/learn.md` | Add QUESTION: to tag table, add research-task type description, update interactive flow docs, update supported comment styles, update output examples |
| `.claude/skills/skill-learn/SKILL.md` | Add extraction pattern (Step 3.4), add `question_tags[]` array, add display section (Step 4), add task type option (Step 6), add individual selection (new Step 7 variant), add topic grouping (reuse Step 7.5), add creation logic (Step 8.5), update state update patterns (Step 9), update results display (Step 10), update commit message format (Step 11) |
| `.claude/docs/examples/learn-flow-example.md` | Add QUESTION: to tag table, add example scenario with QUESTION: tags, update edge case documentation |
| `.claude/docs/reference/standards/multi-task-creation-standard.md` | Update /learn discovery sources to include QUESTION: |

### 8. Language Detection for Research Tasks

The existing language detection logic for todo-tasks (SKILL.md Step 8.4.3) applies directly:

```
.lua (nvim/) -> "neovim"
.tex  -> "latex"
.md   -> "markdown"
.py/.sh -> "general"
.claude/* -> "meta"
```

This is appropriate because the research will typically need to use the same domain tools as the source file's domain. A QUESTION: in a Lua file about Neovim API behavior should route to the neovim-research-agent.

### 9. Effort Estimate for Research Tasks

Research tasks inherently require more investigation than TODO tasks. However, the /learn command creates tasks at the "not_started" level -- the actual research happens when `/research N` is run. So the effort estimate represents the full lifecycle, not just the research phase.

**Recommended effort**:
- Single question: "1-2 hours" (slightly more than todo-task's "1 hour" to account for research depth)
- Grouped questions: Base 1.5 hours + 30 min per additional item

### 10. No Dependency Relationships for QUESTION: Tags

Unlike NOTE: tags (which create fix-it/learn-it dependency pairs), QUESTION: tags have no inherent dependency relationships with other tag types. Research tasks are independent by nature.

However, there is one consideration: if a FIX: or TODO: tag references the same code area as a QUESTION: tag, the user might want the question answered before acting on the fix/todo. This is a user decision, not something to automate. The existing multi-task creation standard supports external dependencies as a future enhancement (noted in the /learn gaps section).

## Decisions

1. **Task type name**: "research-task" (follows the pattern of fix-it-task, learn-it-task, todo-task)
2. **Language detection**: Same file-type-based detection as todo-task (pragmatic, consistent)
3. **Topic grouping**: Reuse existing algorithm without modification (key terms + file section clustering works for questions)
4. **Effort estimate**: 1-2 hours base for single questions, scaled same as TODO groups
5. **No automatic dependencies**: QUESTION: tags are independent; user can add external dependencies manually
6. **Title prefix**: "Research: {question}" for separate mode, "{topic}: {N} research questions" for grouped mode
7. **Description format**: Use blockquote syntax (`>`) to distinguish questions from action items

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| QUESTION: tags may be rare in practice | Low adoption of feature | The implementation cost is low (follows existing patterns); even rare use has value |
| Topic grouping may produce poor clusters for questions | Confusing grouped tasks | The user always has "Keep as separate tasks" option in the grouping prompt |
| Questions might be very long (multi-line) | Truncation issues in UI | Use same 50-char truncation as TODO, full text in description |
| Overlap with NOTE: semantics | User confusion about when to use QUESTION: vs NOTE: | Document clear distinction: NOTE: = "I learned X, document it"; QUESTION: = "I need to find out X" |

## Appendix

### Search Queries Used
- Codebase grep for tag patterns across .claude/ directory
- File reads of learn.md, SKILL.md, learn-flow-example.md, multi-task-creation-standard.md
- Grep for task type references across .claude/ documentation

### Key File References
- `/home/benjamin/.config/nvim/.claude/commands/learn.md` - Command definition (279 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-learn/SKILL.md` - Skill implementation (688 lines)
- `/home/benjamin/.config/nvim/.claude/docs/examples/learn-flow-example.md` - Flow example (617 lines)
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/multi-task-creation-standard.md` - Multi-task standard (390 lines)

## Next Steps

Run `/plan 96` to create an implementation plan based on this research.
