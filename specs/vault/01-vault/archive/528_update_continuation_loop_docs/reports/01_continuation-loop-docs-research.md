# Task 528 Research Report: Update Continuation Loop Documentation

## Summary

- The current handoff artifact naming convention uses `phase-{P}-handoff-{TIMESTAMP}.md` (e.g., `phase-3-handoff-20260212T143022Z.md`) across 4 primary files and their `.opencode/extensions/core/` mirrors.
- Task 527 introduces a new convention: `MM_HH_{handoff-slug}.md` where MM = plan artifact number, HH = handoff count+1 (zero-padded), and slug = kebab-case derived from phase name + current objective.
- A total of **8 files** require updates (4 primary + 4 core mirrors). The `skill-implementer/SKILL.md` file itself does not contain literal old-style example paths; the updates are needed in the pattern documents it references and the agent it delegates to.
- Task 527 has not yet produced a research report (reports directory is empty), but the new naming convention is clearly specified in Task 527's description.

## Current State

### Primary Files with Old Naming Convention

1. **`.opencode/context/formats/handoff-artifact.md`** (7 occurrences)
   - Line 12: `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
   - Line 21: Example: `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md`
   - Lines 32-34: Directory structure examples:
     - `phase-2-handoff-20260212T100000Z.md`
     - `phase-2-handoff-20260212T120000Z.md`
     - `phase-3-handoff-20260212T140000Z.md`
   - Line 115: Artifact path: `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md`
   - Line 132: handoff_path: `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md`

2. **`.opencode/context/patterns/subagent-continuation-loop.md`** (1 occurrence)
   - Line 95: `"handoff_path": "specs/495_.../handoffs/phase-2-handoff-20260504T120000Z.md"`

3. **`.opencode/context/patterns/context-exhaustion-detection.md`** (2 occurrences)
   - Line 137: `"handoff_path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"`
   - Line 144: `"path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"`

4. **`.opencode/agent/subagents/general-implementation-agent.md`** (4 occurrences)
   - Line 196: `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
   - Line 199: `handoff_file="specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-$(date -u +%Y%m%dT%H%M%SZ).md"`
   - Line 322: `"handoff_path": "specs/.../handoffs/phase-P-handoff-TIMESTAMP.md"`
   - Line 329: `"path": "specs/.../handoffs/phase-P-handoff-TIMESTAMP.md"`

### Extension Core Mirrors

All 4 primary files have identical mirrors in `.opencode/extensions/core/`:
- `.opencode/extensions/core/context/formats/handoff-artifact.md` (note: missing lines 51-52 and 167-168 compared to primary)
- `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`
- `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- `.opencode/extensions/core/agents/general-implementation-agent.md`

### Files Examined but NOT Affected

- `.opencode/skills/skill-implementer/SKILL.md` - Uses `handoff_path` as a jq variable (`'.partial_progress.handoff_path // ""'`), not literal example paths. The continuation loop documentation references the pattern documents but contains no hardcoded naming examples.
- `.opencode/skills/skill-researcher/SKILL.md` - References `"$task_dir/handoffs/"*.md` generically; no specific naming convention examples.
- `.opencode/context/formats/return-metadata-file.md` - No old-style handoff paths.
- `.opencode/context/formats/progress-file.md` - No old-style handoff paths (uses `phase-{P}-progress.json` for progress files, which is unchanged by this task).

## Proposed Changes

### New Naming Convention

Per Task 527 description, the new handoff artifact naming convention is:

```
specs/{NNN}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md
```

Where:
- `{NNN}` = 3-digit padded task number
- `{SLUG}` = Task slug in snake_case
- `MM` = Plan artifact number (same as `artifact_number` in delegation context, e.g., `02`)
- `HH` = Handoff count + 1, zero-padded to 2 digits (e.g., `01`, `02`)
- `{handoff-slug}` = Derived from phase name + current objective, kebab-case

Example: `specs/259_configure_feature/handoffs/02_01_implement-validation-framework.md`

### File-by-File Changes

#### 1. `.opencode/context/formats/handoff-artifact.md`

| Line | Current | Proposed |
|------|---------|----------|
| 12 | `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md` | `specs/{NNN}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md` |
| 21 | `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md` | `specs/259_configure_feature/handoffs/02_01_implement-date-validator.md` |
| 32 | `phase-2-handoff-20260212T100000Z.md` | `02_01_define-validation-types.md` |
| 33 | `phase-2-handoff-20260212T120000Z.md` | `02_02_implement-field-validators.md` |
| 34 | `phase-3-handoff-20260212T140000Z.md` | `03_01_integrate-with-handler.md` |
| 115 | `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md` | `specs/259_configure_feature/handoffs/02_01_implement-date-validator.md` |
| 132 | `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md` | `specs/259_configure_feature/handoffs/02_01_implement-date-validator.md` |

**Also update** the `Where:` bullet list (lines 15-19) to document MM, HH, and slug components.

#### 2. `.opencode/context/patterns/subagent-continuation-loop.md`

| Line | Current | Proposed |
|------|---------|----------|
| 95 | `"handoff_path": "specs/495_.../handoffs/phase-2-handoff-20260504T120000Z.md"` | `"handoff_path": "specs/495_.../handoffs/02_01_implement-core-module.md"` |

#### 3. `.opencode/context/patterns/context-exhaustion-detection.md`

| Line | Current | Proposed |
|------|---------|----------|
| 137 | `"handoff_path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"` | `"handoff_path": "specs/259_configure_feature/handoffs/02_01_implement-date-validator.md"` |
| 144 | `"path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"` | `"path": "specs/259_configure_feature/handoffs/02_01_implement-date-validator.md"` |

#### 4. `.opencode/agent/subagents/general-implementation-agent.md`

| Line | Current | Proposed |
|------|---------|----------|
| 196 | `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md` | `specs/{NNN}_{SLUG}/handoffs/{MM}_{HH}_{handoff-slug}.md` |
| 199 | `handoff_file="specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-$(date -u +%Y%m%dT%H%M%SZ).md"` | `handoff_file="specs/{NNN}_{SLUG}/handoffs/{MM}_${handoff_count_padded}_${handoff_slug}.md"` |
| 322 | `"handoff_path": "specs/.../handoffs/phase-P-handoff-TIMESTAMP.md"` | `"handoff_path": "specs/.../handoffs/MM_HH_handoff-slug.md"` |
| 329 | `"path": "specs/.../handoffs/phase-P-handoff-TIMESTAMP.md"` | `"path": "specs/.../handoffs/MM_HH_handoff-slug.md"` |

**Note**: The bash variable construction in line 199 should reference `artifact_number` (MM), `handoff_count+1` (HH), and an auto-generated slug variable.

#### 5-8. Extension Core Mirrors

Apply the exact same changes to:
- `.opencode/extensions/core/context/formats/handoff-artifact.md`
- `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`
- `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- `.opencode/extensions/core/agents/general-implementation-agent.md`

**Note**: The core mirror of `handoff-artifact.md` is missing lines 51-52 and 167-168 (Plan/Progress references in the example). The sync should preserve this difference or optionally add those missing lines for consistency.

## Files Affected

- [ ] `.opencode/context/formats/handoff-artifact.md`
- [ ] `.opencode/context/patterns/subagent-continuation-loop.md`
- [ ] `.opencode/context/patterns/context-exhaustion-detection.md`
- [ ] `.opencode/agent/subagents/general-implementation-agent.md`
- [ ] `.opencode/extensions/core/context/formats/handoff-artifact.md`
- [ ] `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`
- [ ] `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- [ ] `.opencode/extensions/core/agents/general-implementation-agent.md`

## Dependencies

- **Task 527** (`update_handoff_naming_convention`): This task depends on Task 527, which defines the new `MM_HH_{handoff-slug}.md` naming convention. Task 527 updates `handoff-artifact.md` format spec with the new naming convention and slug generation guidelines, and updates `general-implementation-agent.md` Stage 4C to construct filenames using `artifact_number`, `handoff_count+1`, and auto-generated slug.
- **Relationship**: Task 528 is a documentation follow-up to Task 527. Task 527 updates the primary format spec and agent definition; Task 528 updates the pattern documents (subagent-continuation-loop.md, context-exhaustion-detection.md) and ensures all example `handoff_path` values are consistent with the new convention. Task 528 also syncs all changes to the `.opencode/extensions/core/` mirrors.
- **Task 527 Status**: `[NOT STARTED]` - reports directory exists but is empty. The new naming convention parameters are defined in Task 527's description in `specs/TODO.md`.

## Next Steps

1. **Wait for Task 527 completion** (or execute in parallel if dependency is soft): Task 527 establishes the exact slug generation algorithm and updates the primary `handoff-artifact.md` File Location section.
2. **Update primary files**: Apply the proposed changes to the 4 primary files in `.opencode/context/` and `.opencode/agent/`.
3. **Sync to core mirrors**: Copy updated files to `.opencode/extensions/core/` counterparts, preserving any intentional differences (e.g., the handoff-artifact.md missing lines).
4. **Verify consistency**: Run `grep` to ensure no `phase-{P}-handoff-{TIMESTAMP}` references remain in `.opencode/skills/`, `.opencode/agent/`, `.opencode/context/patterns/`, or their core mirrors.
5. **Update task status**: Move Task 528 from `[RESEARCHED]` to `[PLANNED]` and create implementation plan if needed.
