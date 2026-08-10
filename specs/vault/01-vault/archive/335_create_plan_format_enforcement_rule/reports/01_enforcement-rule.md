# Research Report: Plan-Format Enforcement Rule

- **Task**: 335 - Create plan-format enforcement rule
- **Date**: 2026-03-30
- **Language**: meta

## Findings

### Existing Rule Patterns

Rules in `.claude/rules/` use YAML frontmatter with a `paths:` field to auto-apply when editing matching files. Two relevant examples:

1. **artifact-formats.md** - Uses `paths: specs/**/*` to match all spec artifacts
2. **state-management.md** - Uses `paths: specs/**/*` to match all spec artifacts

Both demonstrate the pattern: YAML frontmatter with glob path, then concise checklist content.

### Plan Format Specification

The canonical plan format is defined in `.claude/context/formats/plan-format.md`. Key requirements:

**Required Metadata Fields** (Markdown block, not YAML frontmatter):
- Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type

**Required Sections**:
1. Overview (2-4 sentences)
2. Goals & Non-Goals (bullets)
3. Risks & Mitigations (bullets)
4. Implementation Phases (## heading with ### Phase N: {name} [STATUS] sub-headings)
5. Testing & Validation
6. Artifacts & Outputs
7. Rollback/Contingency

**Per-Phase Required Fields**:
- Goal, Tasks (bullet checklist), Timing
- Optional: Owner, Started/Completed timestamps

### Design Decision

The new rule should:
- Use `paths: specs/**/plans/**` to match only plan files (more specific than `specs/**/*`)
- Be a concise checklist/reminder, not a full specification
- Reference `plan-format.md` for complete details
- Focus on the most commonly missed requirements

## Recommendation

Create a single rule file with:
- YAML frontmatter targeting plan files specifically
- Quick-reference checklists for metadata fields, sections, and phase format
- A pointer to the full specification for edge cases
