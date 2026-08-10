# Research Report: Task #190

**Task**: 190 - Investigate UX inconsistencies and improve command outputs
**Started**: 2026-03-12T00:00:00Z
**Completed**: 2026-03-12T01:00:00Z
**Effort**: 2-4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (.claude/commands/, .claude/skills/, .claude/agents/)
**Artifacts**: specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **11 commands, 9 skills, and 4 agents** were audited for UX consistency
- **6 distinct patterns** for presenting "next step" suggestions were identified
- **Key inconsistency**: Commands use at least 5 different formats for the same conceptual information
- **Existing standard exists** at `.claude/context/core/formats/command-output.md` but is not consistently applied
- **Recommended approach**: Standardize on 2-3 output patterns with clear guidance on when to use each

## Context & Scope

This research audited all commands, skills, and agents in the `.claude/` system to identify UX inconsistencies, focusing on:
1. How "next step" suggestions are formatted
2. Output section structure variations
3. Interactive prompt patterns
4. Error messaging formats

The goal is to document findings for a subsequent implementation plan to standardize UX patterns where appropriate.

## Findings

### 1. Next Step Suggestion Patterns

Six distinct patterns were identified for presenting the same type of information:

| Pattern | Example | Files Using |
|---------|---------|-------------|
| **Pattern A**: `Next: /cmd {N}` | `Next: /plan {N}` | research.md, plan.md, implement.md (partial), revise.md |
| **Pattern B**: `Next: Run /cmd...` | `Next: Run /implement {N} to fix errors` | errors.md |
| **Pattern C**: `Next Steps:` numbered list | `Next Steps:\n1. Review tasks\n2. Run /research` | meta.md output section |
| **Pattern D**: `Next steps:` lowercase + inline | `Next steps: Run /plan 427...` | research-flow-example.md |
| **Pattern E**: `**Next Steps**:` bold markdown | Used in various skill return formats | skill-meta returns |
| **Pattern F**: `next_steps` JSON field | `"next_steps": "Run /plan {N}"` | agent metadata files |

**Severity**: Medium - Users see inconsistent formatting depending on which command they use.

**File References**:
- `/home/benjamin/.config/nvim/.claude/commands/research.md:110` - `Next: /plan {N}`
- `/home/benjamin/.config/nvim/.claude/commands/plan.md:104` - `Next: /implement {N}`
- `/home/benjamin/.config/nvim/.claude/commands/errors.md:151` - `Next: /implement {N} to fix errors`
- `/home/benjamin/.config/nvim/.claude/commands/meta.md:119-122` - `**Next Steps**:\n1. Review tasks...`

### 2. Output Section Structure Variations

Commands have significant variations in how they structure their output:

| Command | Status Format | Artifact Format | Summary Style |
|---------|---------------|-----------------|---------------|
| `/research` | `Status: [RESEARCHED]` | `Report: {path}` | 5-line block |
| `/plan` | `Status: [PLANNED]` | `Plan: {path}` | 5-line block |
| `/implement` | `Status: [COMPLETED]` or `[IMPLEMENTING]` | `Summary: {path}` | 3-5 lines |
| `/revise` | `Status: [PLANNED]` or `[{current}]` | `Previous:` + `New:` | 10+ lines |
| `/todo` | 4-level hierarchy | Nested lists | Variable (up to 30 lines) |
| `/errors` | Table + summary | `Report: {path}` | Variable |
| `/meta` | `## Tasks Created` or `## Current Structure` | `Path: specs/{NNN}_...` | Mode-dependent |
| `/review` | Multi-section summary | Multiple paths | Very long (50+ lines) |
| `/task` | `Status: [NOT STARTED]` | `Artifacts path:` | 4 lines |
| `/fix-it` | Table format | Multi-section | Interactive sections |
| `/refresh` | Table + totals | None | Variable |

**Severity**: High - No consistent mental model for users to expect.

### 3. Status Marker Presentation

Commands use different formats for status markers:

| Format | Example | Commands |
|--------|---------|----------|
| `Status: [MARKER]` | `Status: [RESEARCHED]` | research, plan, implement, revise, task |
| `{marker}` inline | `[COMPLETED]` | implement (partial) |
| `**Status**:` bold | `**Status**: researching` | Some error outputs |
| status in JSON | `"status": "researched"` | Skill returns |

**Recommendation**: Standardize on `Status: [MARKER]` for user-facing output, `status` JSON field for machine use.

### 4. Interactive Selection Patterns

Commands with interactive selection use different formats:

| Command | Selection Format | Options Style |
|---------|------------------|---------------|
| `/meta` | 7-stage interview | AskUserQuestion with options |
| `/review` | Tier-1/Tier-2 selection | AskUserQuestion multiSelect |
| `/fix-it` | 4 selection prompts | AskUserQuestion multiSelect |
| `/todo` | Orphan handling prompt | AskUserQuestion with 3 options |
| `/task --review` | Numbered list + selection | Direct number input |

**Observation**: AskUserQuestion is used consistently, but option presentation varies.

### 5. Error Message Patterns

Three error output patterns were identified:

| Pattern | Structure | Commands |
|---------|-----------|----------|
| **Pattern A**: Inline | `ABORT "message"` | All commands (validation) |
| **Pattern B**: Structured | `Status: Failed\n{reason}\n\nErrors:\n- {list}` | command-output.md standard |
| **Pattern C**: JSON | `{"status": "failed", "error": {...}}` | Skill returns |

**Existing Standard**: `command-output.md` lines 136-155 define the error format but commands don't consistently follow it.

### 6. Artifact Path Reporting

Multiple formats for reporting created artifacts:

| Format | Example | Commands |
|--------|---------|----------|
| `{Type}: {path}` | `Report: specs/.../research-001.md` | research, errors |
| `{Type}: [{name}]({path})` | `Plan: [implementation-001.md](path)` | Some TODO.md updates |
| `- **{Type}**: {path}` | `- **Research**: [research-001.md]` | TODO.md entries |
| `Path: {path}` | `Path: specs/430_...` | meta |
| `Artifacts path:` | `Artifacts path: specs/{NNN}_...` | task |
| `Artifacts created:` list | `- type: path` | command-output.md standard |

**Existing Standard**: `command-output.md` lines 116-130 define the artifact format but it's not universally applied.

### 7. Skill Return Format Inconsistencies

Skills use different return formats for the same type of information:

| Skill | Return Type | Summary Style |
|-------|-------------|---------------|
| skill-researcher | Brief text | 3-6 bullets |
| skill-planner | Brief text | 3-6 bullets |
| skill-implementer | Brief text | 3-6 bullets |
| skill-meta | JSON object | `status`, `summary`, `artifacts` |
| skill-fix-it | Mixed | Interactive + JSON |

**Observation**: Core workflow skills (researcher, planner, implementer) are well-aligned. Meta-related skills diverge.

### 8. Output Length Variations

Significant variation in output verbosity:

| Command | Typical Output Length | Description |
|---------|----------------------|-------------|
| `/task` | 4 lines | Minimal |
| `/research` | 5-6 lines | Concise |
| `/plan` | 5-6 lines | Concise |
| `/implement` (success) | 5-6 lines | Concise |
| `/implement` (partial) | 6-8 lines | Moderate |
| `/revise` | 10-15 lines | Verbose |
| `/meta` | 10-20+ lines | Verbose |
| `/todo` | 15-40+ lines | Very verbose |
| `/review` | 30-50+ lines | Very verbose |
| `/errors` | 15-25 lines | Moderate |
| `/fix-it` | Variable (interactive) | Depends on tags found |

**Issue**: Commands with simple operations have simple output; commands with complex operations have proportionally longer output. This is reasonable, but `/todo` and `/review` may be unnecessarily verbose.

## Recommendations

### High Priority

1. **Standardize Next Step Format**
   - Use `Next: /cmd {N}` pattern for simple single-command suggestions
   - Use `Next Steps:\n1. ...\n2. ...` for multi-step guidance
   - Document decision in command-output.md

2. **Enforce command-output.md Standard**
   - Update all commands to follow existing `Artifacts created:` format
   - Update all commands to follow existing error format
   - Add validation or linting to check compliance

3. **Create Output Template Sections**
   - Define 3 output templates: Simple, Standard, Complex
   - Simple: 4-6 lines (task, research, plan single success)
   - Standard: 8-12 lines (implement, revise, errors)
   - Complex: 15-25 lines (todo, review, meta)

### Medium Priority

4. **Reduce /todo Output Verbosity**
   - Group similar items (e.g., "Archived 5 directories" instead of listing each)
   - Move detailed lists to optional `--verbose` flag

5. **Reduce /review Output Verbosity**
   - Summarize issue groups rather than listing all
   - Move detailed breakdown to the report file

6. **Standardize Skill Return Format**
   - All skills should return brief text summaries
   - JSON metadata should be in files, not console output
   - Document in skills-authoring.md

### Low Priority

7. **Add UX Documentation Section to CLAUDE.md**
   - Reference command-output.md standard
   - Provide quick lookup for developers

8. **Create Linting Script**
   - Check command files for output format compliance
   - Integrate with pre-commit hooks

## Decisions

1. **Preserve existing command-output.md as canonical standard** - It defines good patterns, just needs enforcement
2. **Keep interactive patterns as-is** - AskUserQuestion is consistently used, variations are acceptable
3. **Do not change skill return format** - Current brief text + metadata file pattern is working well
4. **Focus implementation on enforcement, not new patterns** - Existing standards are good

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking user expectations | Medium | Low | Document changes, roll out gradually |
| Over-standardization reduces clarity | Medium | Medium | Keep 3 template levels (simple/standard/complex) |
| Implementation scope creep | High | Medium | Focus on highest-impact inconsistencies first |

## Context Extension Recommendations

None required - this is a meta task about the .claude/ system itself.

## Appendix

### Files Audited

**Commands (11)**:
- `/home/benjamin/.config/nvim/.claude/commands/research.md`
- `/home/benjamin/.config/nvim/.claude/commands/plan.md`
- `/home/benjamin/.config/nvim/.claude/commands/implement.md`
- `/home/benjamin/.config/nvim/.claude/commands/revise.md`
- `/home/benjamin/.config/nvim/.claude/commands/task.md`
- `/home/benjamin/.config/nvim/.claude/commands/errors.md`
- `/home/benjamin/.config/nvim/.claude/commands/meta.md`
- `/home/benjamin/.config/nvim/.claude/commands/review.md`
- `/home/benjamin/.config/nvim/.claude/commands/fix-it.md`
- `/home/benjamin/.config/nvim/.claude/commands/todo.md`
- `/home/benjamin/.config/nvim/.claude/commands/refresh.md`

**Skills (9)**:
- skill-researcher
- skill-planner
- skill-implementer
- skill-meta
- skill-fix-it
- skill-status-sync
- skill-git-workflow
- skill-orchestrator
- skill-refresh

**Agents (4)**:
- general-research-agent
- planner-agent
- general-implementation-agent
- meta-builder-agent

### Existing Standards Referenced

- `/home/benjamin/.config/nvim/.claude/context/core/formats/command-output.md` - Primary standard (underutilized)
- `/home/benjamin/.config/nvim/.claude/context/core/formats/report-format.md` - Report structure
- `/home/benjamin/.config/nvim/.claude/context/core/formats/return-metadata-file.md` - Metadata schema

### Pattern Frequency Summary

| Pattern | Occurrences | Recommendation |
|---------|-------------|----------------|
| `Next: /cmd {N}` | 4 commands | KEEP as primary |
| `Next Steps:` list | 2 commands | KEEP for multi-step |
| `Status: [MARKER]` | 5 commands | KEEP as standard |
| `Artifacts created:` | 1 (standard) | ENFORCE everywhere |
| Brief text return | 3 skills | KEEP as standard |
| JSON console return | 1 skill | MIGRATE to file-based |
