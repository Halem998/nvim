# Research Report: Task #190 - Interactive Selector Patterns

**Task**: 190 - investigate_ux_inconsistencies_and_improve_command_outputs
**Started**: 2026-03-12
**Completed**: 2026-03-12
**Effort**: 2-3 hours
**Dependencies**: research-001.md, research-002.md
**Sources/Inputs**: Codebase analysis, existing multi-task-creation-standard.md
**Artifacts**: This report (research-003.md)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Found 22 files using AskUserQuestion patterns across commands, skills, and agents
- Identified 6 distinct interactive selector patterns with varying levels of consistency
- Multi-task creation standard provides partial guidance but lacks explicit interactive selector standardization
- Key gap: No dedicated interactive-selection standard exists in `.claude/context/core/`
- Recommend creating a unified Interactive Selection Standard document

## Context and Scope

This research focuses specifically on interactive selector patterns used when commands give users choices. Building on research-001.md (UX inconsistencies overview) and research-002.md (output standardization), this report catalogs all AskUserQuestion usages, identifies patterns and inconsistencies, and provides concrete recommendations for standardization.

## Findings

### 1. Commands Using AskUserQuestion

#### 1.1 Commands with multiSelect: true (Multi-Selection)

| Command/Skill | File | Usage |
|---------------|------|-------|
| `/fix-it` | commands/fix-it.md, skills/skill-fix-it/SKILL.md | Task type selection, TODO item selection, QUESTION item selection |
| `/review` | commands/review.md | Issue group selection (Tier 1), granularity selection (Tier 2), individual issue selection (Tier 3) |
| `/todo` | commands/todo.md | Orphaned directory handling, CLAUDE.md suggestion selection |
| `/learn` | extensions/memory/commands/learn.md | File selection in directory mode, artifact selection in task mode |

#### 1.2 Commands with multiSelect: false (Single Selection)

| Command/Skill | File | Usage |
|---------------|------|-------|
| `/meta` | commands/meta.md, agents/meta-builder-agent.md | Purpose selection, scope selection, task breakdown, dependencies, effort, confirmation |
| `/refresh` | skills/skill-refresh/SKILL.md | Age threshold selection (8 hours, 2 days, clean slate) |
| `/lean` | extensions/lean/commands/lean.md | Upgrade confirmation, rollback selection |
| `/tag` | extensions/web/skills/skill-tag/SKILL.md | Tag push confirmation |
| `/todo` | commands/todo.md | Orphan handling mode (track all, skip, review list) |

#### 1.3 Commands with Simple Confirmation

| Command/Skill | File | Pattern |
|---------------|------|---------|
| `/meta` | agents/meta-builder-agent.md | "Yes, create tasks" / "Revise" / "Cancel" |
| `/lean` | extensions/lean/commands/lean.md | "Yes, upgrade" / "No, keep current" |
| `/tag` | extensions/web/skills/skill-tag/SKILL.md | "Yes, create and push" / "No, cancel" |

### 2. Current Interactive Selection Patterns

#### 2.1 Selection Result Processing

**Pattern A: Direct Selection Index**
Used by: `/task --review`, simple confirmations
```
Options:
  [1] Complete phase 2 of task 597
  [2] Complete phase 3 of task 597

Your selection: 1,2 or "all" or "none"
```

**Pattern B: AskUserQuestion with Options Array**
Used by: Most commands (standard pattern)
```json
{
  "question": "Which items should be selected?",
  "header": "Selection Header",
  "multiSelect": true|false,
  "options": [
    {"label": "Option text", "description": "Details about option"}
  ]
}
```

**Pattern C: Tiered Selection**
Used by: `/review`
- Tier 1: Group selection (coarse)
- Tier 2: Granularity selection (grouped vs individual)
- Tier 3: Manual individual selection (fine-grained)

#### 2.2 "All/None" Option Conventions

| Command | All Option | None/Cancel Option |
|---------|------------|-------------------|
| `/fix-it` | "Select all ({N} items)" when >20 items | Empty selection = no tasks |
| `/review` | Not explicit (multiSelect covers it) | "Skip" implicit via empty selection |
| `/task --review` | "all" text input | "none" text input |
| `/meta` | Not applicable (guided interview) | "Cancel" explicit option |
| `/todo` | "Track all orphans" | "Skip orphans" |

**Inconsistency Identified**: `/task --review` uses text-based "all"/"none" input while other commands use AskUserQuestion's multiSelect behavior.

#### 2.3 Confirmation Prompt Conventions

| Pattern | Commands Using | Format |
|---------|----------------|--------|
| Yes/No with descriptions | `/meta`, `/lean`, `/tag`, `/todo` | `{"label": "Yes, action", "description": "consequence"}` |
| Implicit via selection | `/fix-it`, `/review` | Empty selection = cancel |
| Explicit Cancel option | `/meta` | Third option: "Cancel - Exit without creating" |

### 3. Header Format Conventions

| Command | Header Style | Example |
|---------|--------------|---------|
| `/fix-it` | Descriptive noun | "Task Types", "TODO Selection", "TODO Topic Grouping" |
| `/review` | Noun phrase | "Review Task Proposals", "Task Granularity", "Issue Selection" |
| `/meta` | Single word | "Purpose", "Scope", "Confirm" |
| `/refresh` | Noun phrase | "Age Threshold" |
| `/lean` | Descriptive phrase | "Version Upgrade" |
| `/todo` | Single word | "Orphans", "Confirm", "CLAUDE.md Updates" |

**Inconsistency**: Header styles vary from single words to full phrases without clear guidelines.

### 4. Label Format Conventions

| Pattern | Example | Commands Using |
|---------|---------|----------------|
| Action phrase | "Yes, create tasks" | `/meta`, `/tag` |
| Descriptive noun | "fix-it task" | `/fix-it` |
| Descriptive phrase | "Accept suggested topic groups" | `/fix-it` |
| Parameterized | "8 hours (default)" | `/refresh` |
| With context | "[Group] {group_label} ({item_count} issues)" | `/review` |
| With prefix | "[Individual] {issue_title}" | `/review` |

### 5. Description Format Conventions

| Pattern | Example | Usage |
|---------|---------|-------|
| Consequence | "Triggers CI/CD deployment to production" | `/tag` |
| Item count | "Creates {N} grouped tasks: {list}" | `/fix-it` |
| Technical detail | "Critical: 1, High: 2 | Files: file1, file2" | `/review` |
| Path reference | "{file}:{line}" | `/fix-it` TODO selection |
| Action summary | "Remove files older than 8 hours - aggressive cleanup" | `/refresh` |

### 6. Selection Threshold Conventions

| Command | Threshold | Behavior Above Threshold |
|---------|-----------|--------------------------|
| `/fix-it` | 20 items | Add "Select all" option at top |
| `/learn` | 50 files | Warning message displayed |
| `/learn` | 200 files | Hard limit with error |
| `/review` | 10 groups | Merge lowest-priority groups |

### 7. Documentation Gaps

#### 7.1 Missing from `.claude/context/core/`

1. **No dedicated interactive-selection standard** - Patterns are documented inline in each command
2. **No AskUserQuestion schema reference** - Tool behavior assumed but not documented
3. **No header/label style guide** - Each command defines its own conventions
4. **No threshold guidelines** - Item count thresholds vary without explanation

#### 7.2 Existing Related Documentation

| Document | Relevant Content | Gap |
|----------|------------------|-----|
| `multi-task-creation-standard.md` | Section 2 (Interactive Selection), Section 7 (User Confirmation) | Missing: option formatting, header conventions, description guidelines |
| `command-output.md` | Output formatting after selection | Missing: selection prompt formatting |
| `command-structure.md` | Overall command structure | Missing: interactive selection section |

### 8. Proposed Interactive Selection Standard

Based on the analysis, here is a recommended standardization framework:

#### 8.1 AskUserQuestion Schema (Standardized)

```json
{
  "question": "Action-oriented question ending in ?",
  "header": "Short Title (1-3 words)",
  "multiSelect": true|false,
  "options": [
    {
      "label": "Action phrase or descriptive noun (50 char max)",
      "description": "Consequence or context (80 char max)"
    }
  ]
}
```

#### 8.2 Question Format Guidelines

| Question Type | Pattern | Example |
|---------------|---------|---------|
| Action confirmation | "Proceed with {action}?" | "Proceed with creating these tasks?" |
| Selection prompt | "Which {items} should be {action}?" | "Which task types should be created?" |
| Choice prompt | "How should {items} be {processed}?" | "How should TODO items be grouped into tasks?" |
| Filter prompt | "Select {items} to {action}:" | "Select TODO items to create as tasks:" |

#### 8.3 Header Format Guidelines

| Context | Format | Examples |
|---------|--------|----------|
| Confirmation | Verb + Noun | "Confirm Creation", "Version Upgrade" |
| Selection | Noun (+ Qualifier) | "Task Types", "TODO Selection", "Issue Groups" |
| Configuration | Noun | "Age Threshold", "Granularity" |

#### 8.4 Label Format Guidelines

| Option Type | Pattern | Example |
|-------------|---------|---------|
| Confirmation positive | "Yes, {action}" | "Yes, create tasks" |
| Confirmation negative | "No, {alternative}" | "No, cancel" |
| Selection item | "{Description}" or "[Type] {Description}" | "fix-it task" or "[Group] API fixes" |
| All option | "Select all ({N} items)" | "Select all (25 items)" |
| Skip option | "Skip {what}" or "None" | "Skip orphans" |

#### 8.5 Description Format Guidelines

| Content Type | Pattern | Example |
|--------------|---------|---------|
| Consequence | "{What happens}" | "Triggers CI/CD deployment" |
| Item details | "{Metadata} | {Files/Paths}" | "Critical: 1, High: 2 | Files: a.lua, b.lua" |
| Count summary | "Creates {N} {type}(s)" | "Creates 3 grouped tasks" |
| Source reference | "{file}:{line}" or "Source: {path}" | "nvim/lua/plugins/lsp.lua:67" |

#### 8.6 Threshold Guidelines

| Item Count | Behavior |
|------------|----------|
| 1-10 | Show all options directly |
| 11-20 | Show all, consider grouping |
| 21-50 | Add "Select all" option, show warning |
| 51-100 | Require narrowing or explicit "all" confirmation |
| >100 | Hard limit with error, suggest filtering |

### 9. Command-Specific Recommendations

#### `/task --review`
- **Current**: Text-based "all"/"none" input
- **Recommendation**: Migrate to AskUserQuestion with multiSelect for consistency

#### `/fix-it`
- **Current**: Well-implemented tiered selection
- **Recommendation**: Document as reference implementation

#### `/review`
- **Current**: Three-tier selection (groups -> granularity -> items)
- **Recommendation**: Simplify to two tiers (groups with inline granularity choice)

#### `/meta`
- **Current**: 7-stage interview with multiple AskUserQuestion calls
- **Recommendation**: Document interview pattern as separate standard for multi-step interactions

#### `/todo`
- **Current**: Mixed patterns (orphan handling vs CLAUDE.md suggestions)
- **Recommendation**: Unify confirmation patterns

## Decisions

1. **Primary Pattern**: AskUserQuestion with options array is the standard; text-based selection is deprecated
2. **Confirmation Style**: Explicit "Yes/No/Cancel" for destructive or creation actions; implicit via empty selection for filtering
3. **Threshold**: 20 items is the standard threshold for "Select all" option
4. **Header Style**: 1-3 word noun phrases, Title Case

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing user habits | Medium | Document changes, gradual migration |
| Increased complexity from standardization | Low | Keep standard concise, provide templates |
| Tool compatibility (AskUserQuestion) | Low | Already standardized across all commands |

## Appendix

### A. Files Analyzed

1. `.claude/commands/fix-it.md`
2. `.claude/commands/review.md`
3. `.claude/commands/meta.md`
4. `.claude/commands/todo.md`
5. `.claude/commands/task.md`
6. `.claude/commands/errors.md`
7. `.claude/skills/skill-fix-it/SKILL.md`
8. `.claude/skills/skill-refresh/SKILL.md`
9. `.claude/skills/skill-meta/SKILL.md`
10. `.claude/agents/meta-builder-agent.md`
11. `.claude/docs/reference/standards/multi-task-creation-standard.md`
12. `.claude/context/core/formats/command-output.md`
13. `.claude/extensions/lean/commands/lean.md`
14. `.claude/extensions/memory/commands/learn.md`
15. `.claude/extensions/web/skills/skill-tag/SKILL.md`

### B. Search Queries Used

- `AskUserQuestion` (19 files found)
- `multiSelect` (14 files found)
- `options.*label` (22 files found)

### C. Context Extension Recommendations

**Topic**: Interactive Selection Patterns
**Gap**: No dedicated standard document exists for interactive selection UI patterns
**Recommendation**: Create `.claude/context/core/standards/interactive-selection.md` containing:
- AskUserQuestion schema and usage guidelines
- Question/header/label/description format conventions
- Threshold guidelines for large item lists
- Confirmation vs selection pattern decision tree
- Reference implementations from `/fix-it` and `/meta`

This would consolidate the patterns identified in this research and provide a single reference for command authors.
