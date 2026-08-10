# Implementation Plan: Convert TODO.md Artifact References to Markdown Links

- **Task**: 741 - Convert TODO.md artifact references to markdown links
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/741_todo_artifact_markdown_links/reports/01_markdown-links-research.md
- **Artifacts**: plans/01_markdown-links-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update `generate-todo.sh` to emit artifact references as proper markdown links `[path](specs/path)` instead of bare bracket `[path]` format, making them clickable when viewed on GitHub or in markdown renderers. Also update all documentation files that describe or enforce the bracket-only format to reflect the new markdown link convention.

### Research Integration

Research report identified the exact lines in `generate-todo.sh` (284, 290) that need printf format changes. The report covered 2 of 4 files -- it missed the prohibition rule in `artifact-formats.md` (line 115) and the format examples in `state-management-schema.md` (line 265+), both of which also enforce the bracket-only convention and need updating.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly relevant to this meta task.

## Goals & Non-Goals

**Goals**:
- Make artifact links in TODO.md render as clickable markdown links
- Update `generate-todo.sh` printf statements to emit `[path](specs/path)` format
- Update all documentation that describes or enforces the bracket-only format

**Non-Goals**:
- Retroactively converting existing TODO.md entries (they regenerate automatically via `generate-todo.sh`)
- Changing how `state.json` stores artifact paths (state.json stores full `specs/` paths; TODO rendering is generate-todo.sh's concern)
- Modifying the short-path stripping logic (`${apath#specs/}`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing TODO.md entries not updated until next regeneration | L | H | Acceptable -- run `generate-todo.sh` once after implementation to regenerate all entries |
| Links broken when viewed from subdirectory | L | L | Standard GitHub behavior; `specs/` prefix is relative to repo root |
| Printf format mismatch (wrong number of arguments) | H | L | Each printf passes the same variable twice -- straightforward and testable |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Script and Documentation [COMPLETED]

**Goal**: Change the link format in `generate-todo.sh` and update all documentation files that reference the bracket-only convention.

**Tasks**:
- [x] Edit `.claude/scripts/generate-todo.sh` line 284: change `printf -- '- **%s**: [%s]\n'` to `printf -- '- **%s**: [%s](specs/%s)\n'` and add second `"$paths_str"` argument *(completed)*
- [x] Edit `.claude/scripts/generate-todo.sh` line 290: change `printf '  - [%s]\n'` to `printf '  - [%s](specs/%s)\n'` and add second `"$p"` argument *(completed)*
- [x] Edit `.claude/context/patterns/artifact-linking-todo.md` line 29: replace bracket-only format declaration with markdown link format declaration *(completed)*
- [x] Edit `.claude/context/patterns/artifact-linking-todo.md` examples in Cases 1-3 (lines 55-106): update all `[path]` references in examples to `[path](specs/path)` format *(completed)*
- [x] Edit `.claude/context/patterns/artifact-linking-todo.md` compact reference (line 122 area): update template example *(deviation: skipped — compact reference is an instruction template with no link format examples to update)*
- [x] Edit `.claude/rules/artifact-formats.md` line 115: replace PROHIBITION of markdown links with statement that links now USE markdown format; update inline examples on lines 112-113 *(completed)*
- [x] Edit `.claude/context/reference/state-management-schema.md` line 265: replace bracket-only declaration with markdown link declaration *(completed)*
- [x] Edit `.claude/context/reference/state-management-schema.md` example blocks (lines 270, 276, 283, 292, 298-299): update all `[path]` examples to `[path](specs/path)` format *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-todo.sh` - lines 284, 290: printf format strings
- `.claude/context/patterns/artifact-linking-todo.md` - line 29 format declaration + all examples
- `.claude/rules/artifact-formats.md` - line 115 prohibition + inline examples
- `.claude/context/reference/state-management-schema.md` - line 265 declaration + example blocks

**Verification**:
- Run `bash .claude/scripts/generate-todo.sh` and inspect `specs/TODO.md` for markdown link format
- Grep TODO.md for `](specs/` to confirm links use the new format
- Grep the four documentation files for "bracket-only" to confirm no stale references remain

---

### Phase 2: Verify and Regenerate [COMPLETED]

**Goal**: Run generate-todo.sh to regenerate TODO.md with the new link format and verify correctness.

**Tasks**:
- [x] Run `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md *(completed)*
- [x] Verify output contains `[path](specs/path)` format links (not bare `[path]`) *(completed: 33 markdown links confirmed)*
- [x] Verify no broken links (check a sample link resolves to an existing file) *(completed: spot-checked task 740 links)*
- [x] Verify multi-artifact entries also use the new format (check a task with 2+ artifacts of same type) *(completed: task 734 multi-report entry confirmed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `specs/TODO.md` - regenerated output (not manually edited)

**Verification**:
- `grep -c '](specs/' specs/TODO.md` returns a count matching the number of artifact links
- `grep '\[.*\]$' specs/TODO.md | grep -v '^\- \*\*Status' | grep -v '^\- \*\*Completed'` returns no bare-bracket artifact links (status markers like `[PLANNED]` are expected)

## Testing & Validation

- [ ] `bash .claude/scripts/generate-todo.sh` completes without error
- [ ] `grep '](specs/' specs/TODO.md` shows markdown links in the output
- [ ] No remaining "bracket-only" references in updated documentation files
- [ ] The PROHIBITION line in artifact-formats.md now describes markdown link format, not bracket-only

## Artifacts & Outputs

- `specs/741_todo_artifact_markdown_links/plans/01_markdown-links-plan.md` (this file)
- `specs/741_todo_artifact_markdown_links/summaries/01_markdown-links-summary.md` (after implementation)

## Rollback/Contingency

Revert the two-character printf changes in `generate-todo.sh` (lines 284, 290) and restore documentation to bracket-only format. Run `generate-todo.sh` to regenerate TODO.md with original format.
