# Research Report: Task #190 (Additional Research)

**Task**: 190 - Investigate UX inconsistencies and improve command outputs
**Started**: 2026-03-12T00:00:00Z
**Completed**: 2026-03-12T01:30:00Z
**Effort**: 2-3 hours
**Dependencies**: Research-001.md (builds on previous findings)
**Sources/Inputs**: Codebase exploration (.claude/commands/, .claude/skills/, .claude/context/core/formats/)
**Artifacts**: specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/reports/research-002.md
**Standards**: report-format.md, command-output.md

## Executive Summary

- **Existing command-output.md standard is well-designed** but inconsistently applied across commands
- **Task number indication varies**: `Task #{N}`, `Task: {N}`, `#{N}:`, `Task #N` (no colon) - need standardization
- **Artifact link formatting is inconsistent**: mix of markdown links, plain paths, and labeled paths
- **Output verbosity varies dramatically**: from 4 lines (/task) to 50+ lines (/review, /todo)
- **Recommended approach**: Define 3 output templates (Simple, Standard, Complex) with concrete examples

## Context & Scope

This research builds on research-001.md which identified 6 distinct "next step" patterns. This follow-up focuses on:
1. General output format standardization beyond "next step" suggestions
2. Task number indication consistency
3. Artifact link formatting
4. Output brevity optimization
5. Concrete, implementable unified output templates

## Findings

### 1. Existing command-output.md Standard Review

The existing standard at `.claude/context/core/formats/command-output.md` defines:

**Header Format** (lines 14-54):
- Task-based commands: `Task: {task_number}`
- Direct commands: `Command: /{command_name}`

**Summary Requirements** (lines 56-86):
- Maximum 100 tokens (~400 characters)
- Target 50-75 tokens
- Three-sentence structure: accomplishment, outcome, next steps

**Artifact Display** (lines 116-130):
```
Artifacts created:
- {type}: {path}
```

**Error Display** (lines 136-155):
```
Status: Failed
{failure_reason}

Errors:
- {error.message}

Recommendation: {recommendation}
```

**Key Gap**: The standard is comprehensive but commands don't follow it consistently.

### 2. Task Number Indication Patterns

Current variations across commands:

| Pattern | Commands Using | Example |
|---------|----------------|---------|
| `Task #{N}` | research, plan, implement, revise | `Research completed for Task #258` |
| `Task: {N}` | command-output.md standard | `Task: 258` |
| `Task #{N}:` | task, errors | `Task #650 created: Fix issues` |
| `#{N}` | meta, fix-it output tables | `Task #650: {title}` |
| `task {N}` | git commits | `task 258: complete research` |

**Recommendation**: Standardize on **`Task #{N}`** (no colon) for user-facing output, as it's:
- Most readable
- Most commonly used
- Clearly indicates task reference

Keep `task {N}` (lowercase, no hash) for git commit messages only.

### 3. Artifact Link Formatting Analysis

Three distinct patterns found:

| Format | Location | Example |
|--------|----------|---------|
| **Labeled Path** | /research, /plan, /errors | `Report: specs/{NNN}_{SLUG}/reports/research-001.md` |
| **Markdown Link** | TODO.md entries | `[research-001.md](specs/{NNN}_{SLUG}/reports/research-001.md)` |
| **List Format** | command-output.md standard | `- report: specs/.../research-001.md` |

**Context-Appropriate Usage**:
- **Console output**: Use labeled path (`Report: {path}`) - readable without terminal link support
- **Markdown files**: Use markdown links (`[name](path)`) - clickable in editors
- **Lists**: Use standard format (`- type: path`) - scannable

**Recommendation**: Console output should use labeled paths since terminals don't universally support clickable links. Markdown files (TODO.md, reports) should use markdown link syntax.

### 4. Output Structure Patterns by Command

Detailed output analysis of all 11 commands:

#### Task-Based Commands (operate on specific task)

| Command | Header | Summary Style | Artifact Format | Next Step |
|---------|--------|---------------|-----------------|-----------|
| /research | `Research completed for Task #{N}` | 1 sentence | `Report: {path}` | `Next: /plan {N}` |
| /plan | `Plan created for Task #{N}` | 2 sentences (phases, effort) | `Plan: {path}` | `Next: /implement {N}` |
| /implement | `Implementation complete for Task #{N}` | 1 sentence + phases count | `Summary: {path}` | (none, completed) |
| /revise | `Plan revised for Task #{N}` | Key changes list | `Previous:` + `New:` | `Next: /implement {N}` |
| /task | `Task #{N} created: {TITLE}` | 4 fields inline | `Artifacts path: specs/...` | (none, just created) |

#### Direct Commands (no task context)

| Command | Header | Summary Style | Artifact Format | Next Step |
|---------|--------|---------------|-----------------|-----------|
| /todo | (none) | Nested lists by category | (none) | (none) |
| /review | `Review complete for: {scope}` | Multi-section breakdown | `Report: {path}` | Task-specific |
| /errors | `Error Analysis Complete` | Table + summary | `Report: {path}` | `Next: /implement {N}` |
| /meta | `## Tasks Created` | Grouped by priority | `Path: specs/...` | Numbered list |
| /fix-it | `## Tasks Created from Tags` | Table format | (embedded) | Numbered list |
| /refresh | `Claude Code Refresh` | Table + totals | (none) | (none) |

### 5. Output Length Analysis

Commands sorted by typical output length:

| Length Category | Commands | Typical Lines | Status |
|-----------------|----------|---------------|--------|
| **Simple** (4-6 lines) | /task, /research, /plan | 4-6 | OK |
| **Standard** (8-12 lines) | /implement (success), /revise (plan), /errors | 8-12 | OK |
| **Complex** (15-25 lines) | /implement (partial), /meta, /fix-it | 15-25 | OK |
| **Verbose** (30+ lines) | /todo, /review | 30-50+ | NEEDS REDUCTION |

**Verbose Commands Analysis**:

**/todo** (30-40+ lines):
- Lists every archived task
- Lists every directory moved
- Lists orphan operations in detail
- Lists roadmap updates line by line
- Lists CLAUDE.md suggestions

**Reduction opportunities**:
- Group similar items: "Archived 5 completed tasks (650, 651, 652, 653, 654)"
- Summarize operations: "Moved 3 directories to archive/"
- Use counts not lists for routine operations

**/review** (30-50+ lines):
- Full issue breakdowns
- Complete roadmap progress
- Grouped task recommendations
- Issue count tables

**Reduction opportunities**:
- Move detailed breakdowns to report file (already exists)
- Show only top-level summary in console
- Reference report for details

### 6. Unified Output Template Proposal

Based on analysis, propose three templates:

#### Template A: Simple (4-6 lines)

For single-artifact commands with clear next step.

```
{Action verb} for Task #{N}

{Artifact label}: {path}
Summary: {1 sentence summary}

Status: [{STATUS}]
Next: /{next_command} {N}
```

**Example** (/research):
```
Research completed for Task #258

Report: specs/258_modal_logic/reports/research-001.md
Summary: Analyzed 8 Mathlib patterns for modal logic integration.

Status: [RESEARCHED]
Next: /plan 258
```

**Commands**: /research, /plan, /task (create)

#### Template B: Standard (8-12 lines)

For multi-phase commands or commands with metrics.

```
{Action verb} for Task #{N}

{Artifact label}: {path}

Metrics:
- {metric1}: {value}
- {metric2}: {value}

Summary: {1-2 sentence summary}

Status: [{STATUS}]
{Next step if applicable}
```

**Example** (/implement success):
```
Implementation complete for Task #350

Summary: specs/350_feature/summaries/implementation-summary-20260118.md

Metrics:
- Phases completed: 5/5
- Files modified: 8

Summary: Added validation module with error handling.

Status: [COMPLETED]
```

**Example** (/implement partial):
```
Implementation paused for Task #350

Summary: specs/350_feature/summaries/implementation-summary-20260118.md

Progress:
- Completed: Phases 1-3
- Remaining: Phase 4 (validation tests)
- Resume: /implement 350

Status: [IMPLEMENTING]
Next: /implement 350 (will resume from Phase 4)
```

**Commands**: /implement, /revise (plan), /errors

#### Template C: Complex (15-25 lines)

For multi-operation commands with user choices.

```
{Operation} Complete

{Primary section header}:
{Grouped summary, max 5 items}

{Secondary section header (if applicable)}:
{Brief summary}

Artifacts:
- {artifact1}
- {artifact2}

Summary: {1-2 sentences}

Next Steps:
1. {step1}
2. {step2}
```

**Example** (/todo optimized):
```
Archive Complete

Tasks archived: 5
- Completed: 3 (650, 651, 652)
- Abandoned: 2 (653, 654)

Directories moved: 5 -> archive/

Roadmap updated: 3 items marked complete

CLAUDE.md: 2 suggestions applied

Active tasks remaining: 12

Next: Run /todo --dry-run periodically
```

**Commands**: /todo, /review, /meta, /fix-it

### 7. Command Output Sections Standardization

Propose standardized section ordering:

1. **Header** (Task or Command context)
2. **Primary Operation Result** (what was done)
3. **Artifacts** (files created/modified)
4. **Metrics** (counts, phases, effort)
5. **Summary** (1-2 sentences)
6. **Status** (status marker)
7. **Next Step** (if applicable)

### 8. Next Step Pattern Standardization

From research-001.md, consolidate to two patterns:

**Pattern 1: Single Command** (most commands):
```
Next: /command {N}
```

**Pattern 2: Multiple Steps** (/meta, complex operations):
```
Next Steps:
1. Review {artifact} in {location}
2. Run /research {N} to begin
3. Progress through /research -> /plan -> /implement
```

**Never use**: `Next steps:` (lowercase), `**Next Steps**:` (bold), `Next: Run /command` (verbose)

## Recommendations

### High Priority (Implement First)

1. **Standardize Task Number Format**
   - All commands: `Task #{N}` (no colon after)
   - Git commits only: `task {N}` (lowercase, no hash)
   - Update: All 11 command files, command-output.md standard

2. **Enforce Artifact Format**
   - Console: `{Type}: {path}` (labeled path)
   - Markdown: `[{name}]({path})` (clickable link)
   - Update: All command Output sections

3. **Create 3 Output Templates**
   - Add to command-output.md: Simple, Standard, Complex templates
   - Assign each command to appropriate template
   - Include concrete examples

### Medium Priority

4. **Reduce /todo Output Verbosity**
   - Group task lists: "Archived 5 tasks (650-654)"
   - Summarize operations: "Moved 3 directories"
   - Target: 15-20 lines max

5. **Reduce /review Output Verbosity**
   - Move issue details to report file
   - Show only summary in console
   - Target: 20-25 lines max

6. **Standardize Next Step Format**
   - Single: `Next: /command {N}`
   - Multiple: `Next Steps:\n1. ...\n2. ...`
   - Update: research-001.md identified 6 variations, consolidate to 2

### Low Priority

7. **Add Output Validation**
   - Lint script to check command output sections
   - Verify artifact format matches template
   - Check next step format

8. **Document Template Selection**
   - Add guidance to command-authoring.md
   - Include template selection criteria

## Decisions

1. **Keep command-output.md as canonical** - Don't create new standard, update existing
2. **Use `Task #{N}` consistently** - Most readable, most common
3. **Three template levels are sufficient** - Simple/Standard/Complex covers all cases
4. **Verbosity reduction is worth the effort** - /todo and /review can be significantly shorter
5. **Artifact format is context-dependent** - Console vs markdown have different needs

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking user expectations | Low | Low | Changes are refinements, not redesigns |
| Template doesn't fit edge case | Medium | Low | Templates are guidelines, not strict requirements |
| Verbose output has hidden value | Low | Low | Move details to artifacts, keep summaries |
| Implementation effort is high | Medium | Medium | Prioritize high-impact changes first |

## Context Extension Recommendations

None required - this is a meta task about the .claude/ system itself.

## Appendix

### Concrete Implementation Changes Summary

| Command | Current Issue | Change |
|---------|---------------|--------|
| /research | Uses `Task #258:` (with colon) | Change to `Task #258` |
| /plan | Uses `Task #258:` (with colon) | Change to `Task #258` |
| /implement | Uses `Task #{N}` (correct) | No change |
| /revise | Uses `Task #{N}:` (with colon) | Change to `Task #258` |
| /task | Uses `Task #{N} created:` | Keep (title follows) |
| /todo | No header, verbose lists | Add header, group items |
| /review | Verbose sections | Summarize, move details to report |
| /errors | Uses `Next: /implement {N} to fix` | Change to `Next: /implement {N}` |
| /meta | Uses `**Next Steps**:` | Change to `Next Steps:` |
| /fix-it | Uses `**Next Steps**:` | Change to `Next Steps:` |
| /refresh | Good format | No change |

### Files to Modify

1. `.claude/context/core/formats/command-output.md` - Add templates, update header format
2. `.claude/commands/research.md` - Update Output section
3. `.claude/commands/plan.md` - Update Output section
4. `.claude/commands/implement.md` - Verify/update Output section
5. `.claude/commands/revise.md` - Update Output section
6. `.claude/commands/task.md` - Verify Output section
7. `.claude/commands/todo.md` - Major reduction, add grouping
8. `.claude/commands/review.md` - Major reduction
9. `.claude/commands/errors.md` - Update Next step format
10. `.claude/commands/meta.md` - Update Next Steps format
11. `.claude/commands/fix-it.md` - Update Next Steps format

### Search Queries Used

- Glob: `.claude/commands/*.md`
- Glob: `.claude/skills/*/SKILL.md`
- Read: command-output.md, all command files, skill files
- Pattern analysis: Task number formats, artifact formats, next step formats

### References

- `.claude/context/core/formats/command-output.md` - Existing standard
- `.claude/docs/reference/standards/command-authoring.md` - Command development patterns
- Research-001.md findings on 6 next step patterns
