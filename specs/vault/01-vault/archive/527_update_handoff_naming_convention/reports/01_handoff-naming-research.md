# Task 527 Research Report: Update Handoff Naming Convention

## Summary

- The handoff artifact system currently uses `phase-{P}-handoff-{TIMESTAMP}.md` naming; this research identifies **13 files** that must be updated to the new `MM_HH_{handoff-slug}.md` convention.
- The new convention replaces volatile timestamps with deterministic, sortable identifiers (`MM` = plan artifact number, `HH` = handoff sequence number) and adds a semantic slug derived from phase name + current objective.
- All changes must be mirrored between `.opencode/context/` / `.opencode/agent/` and their `.opencode/extensions/core/` counterparts.

## Current State

### Existing Naming Pattern

The current handoff filename pattern is used consistently across format specs, agent definitions, and pattern documentation:

```
specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md
```

Where:
- `{P}` = Phase number (unpadded)
- `{TIMESTAMP}` = ISO8601 timestamp (e.g., `20260212T143022Z`)

**Example**: `specs/259_configure_feature/handoffs/phase-3-handoff-20260212T143022Z.md`

### Files Using the Old Pattern

1. **`.opencode/context/formats/handoff-artifact.md`** (8 occurrences)
   - File location spec: `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
   - Example filename: `phase-3-handoff-20260212T143022Z.md`
   - Directory tree examples: `phase-2-handoff-20260212T100000Z.md`, etc.
   - Metadata artifact example path
   - `partial_progress.handoff_path` example path

2. **`.opencode/extensions/core/context/formats/handoff-artifact.md`** (mirror, 8 occurrences)

3. **`.opencode/agent/subagents/general-implementation-agent.md`** (4 occurrences)
   - Stage 4C: Handoff artifact path template
   - Stage 4C: Bash `handoff_file` construction using `$(date -u +%Y%m%dT%H%M%SZ)`
   - Stage 7: Metadata `handoff_path` example
   - Stage 7: Metadata `artifacts[].path` example

4. **`.opencode/extensions/core/agents/general-implementation-agent.md`** (mirror, 4 occurrences)

5. **`.opencode/context/patterns/context-exhaustion-detection.md`** (2 occurrences)
   - JSON example: `handoff_path` value
   - JSON example: `artifacts[].path` value

6. **`.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`** (mirror, 2 occurrences)

7. **`.opencode/context/patterns/subagent-continuation-loop.md`** (1 occurrence)
   - Delegation context example: `continuation_context.handoff_path`

8. **`.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`** (mirror, 1 occurrence)

### Supporting State Variables

The `handoff_count` field in progress files already tracks how many times a phase has been handed off. It is:
- Initialized to `0` in new progress files
- Incremented on each handoff
- Used by successors to resume correctly

This existing field is the foundation for the `HH` (handoff artifact number) component of the new naming convention.

## Proposed Changes

### New Naming Convention

```
specs/{N}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md
```

Where:
- `MM` = `artifact_number` from delegation context, **zero-padded to 2 digits** (e.g., `02`)
- `HH` = `handoff_count + 1`, **zero-padded to 2 digits** (e.g., `01` for first handoff)
- `{handoff-slug}` = Derived from **phase name + current objective**, converted to **kebab-case**

**Example**: `specs/259_configure_feature/handoffs/02_01_implement-validation-framework.md`

### Slug Generation Guidelines

1. Concatenate the phase name and the current objective description
2. Convert to lowercase
3. Replace spaces, underscores, and slashes with hyphens
4. Remove special characters (except hyphens)
5. Collapse multiple consecutive hyphens into one
6. Trim leading/trailing hyphens
7. Limit to ~40 characters for readability

**Example**:
- Phase name: "Implement validation framework"
- Current objective: "Define ValidationResult type"
- Slug: `implement-validation-framework-define-validationresult-type` (or truncated)

### File-by-File Modifications

#### 1. `.opencode/context/formats/handoff-artifact.md`

- **File Location section**: Replace path template and variable definitions
  - Old: `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`
  - New: `specs/{N}_{SLUG}/handoffs/MM_HH_{handoff-slug}.md`
  - Update variable table to document `MM`, `HH`, and slug generation
- **Example**: Update to show new naming example
- **Directory Structure**: Update tree examples to show new filenames
- **Template Header**: Consider whether to keep timestamp in title or switch to a more readable identifier
- **Metadata Examples**: Update `handoff_path` and artifact `path` examples
- **Integration with partial_progress**: Update `handoff_path` example
- **Add Slug Generation Section**: Document the kebab-case derivation rules

#### 2. `.opencode/extensions/core/context/formats/handoff-artifact.md`

- Apply all changes from #1 identically (exact mirror)

#### 3. `.opencode/agent/subagents/general-implementation-agent.md`

- **Stage 4C - Handoff filename construction**:
  - Replace bash `handoff_file` construction using `date` with construction using `artifact_number`, `handoff_count`, and auto-generated slug
  - Old:
    ```bash
    handoff_file="specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-$(date -u +%Y%m%dT%H%M%SZ).md"
    ```
  - New (conceptual):
    ```bash
    handoff_count=$((handoff_count + 1))
    handoff_file="specs/{NNN}_{SLUG}/handoffs/{artifact_number}_${handoff_count}_{handoff-slug}.md"
    ```
    (where `handoff-slug` is generated from phase name + current objective)
- **Stage 7 - Metadata examples**: Update `handoff_path` and artifact `path` values in the partial JSON example

#### 4. `.opencode/extensions/core/agents/general-implementation-agent.md`

- Apply all changes from #3 identically (exact mirror)

#### 5. `.opencode/extensions/lean/agents/lean-implementation-agent.md`

- **Handoff Protocol section**: The current text says "Write handoff document to `specs/{N}_{SLUG}/handoffs/`" without specifying the filename. Add a reference to the handoff artifact format spec and note that filenames follow the `MM_HH_{handoff-slug}.md` convention.
- **Critical Requirements**: No explicit filename construction here, so minimal changes needed.

#### 6. `.opencode/context/patterns/context-exhaustion-detection.md`

- **Handoff Writing Protocol - Step 4**: Update the JSON example
  - Old: `"handoff_path": "specs/259_configure_feature/handoffs/phase-3-handoff-20260504T120000Z.md"`
  - New: `"handoff_path": "specs/259_configure_feature/handoffs/02_01_implement-validation-framework.md"`
- Update the `artifacts[].path` example in the same JSON block

#### 7. `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`

- Apply changes from #6 identically (exact mirror)

#### 8. `.opencode/context/patterns/subagent-continuation-loop.md`

- **Successor Delegation Context**: Update the `handoff_path` example
  - Old: `"handoff_path": "specs/495_.../handoffs/phase-2-handoff-20260504T120000Z.md"`
  - New: `"handoff_path": "specs/495_.../handoffs/02_01_{handoff-slug}.md"`

#### 9. `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`

- Apply changes from #8 identically (exact mirror)

#### 10-13. Additional Mirror/Reference Files (if any)

- `.opencode/context/formats/return-metadata-file.md`: The `handoff_path` field description references `handoff-artifact.md` but does not include an explicit old filename. No change needed unless the description should mention the new convention explicitly.
- `.opencode/extensions/core/context/formats/return-metadata-file.md`: Same as above.
- `.opencode/context/formats/progress-file.md`: No explicit old handoff filename appears. No change needed.
- `.opencode/extensions/core/context/formats/progress-file.md`: Same as above.

## Files Affected

- [ ] `.opencode/context/formats/handoff-artifact.md`
- [ ] `.opencode/extensions/core/context/formats/handoff-artifact.md`
- [ ] `.opencode/agent/subagents/general-implementation-agent.md`
- [ ] `.opencode/extensions/core/agents/general-implementation-agent.md`
- [ ] `.opencode/extensions/lean/agents/lean-implementation-agent.md`
- [ ] `.opencode/context/patterns/context-exhaustion-detection.md`
- [ ] `.opencode/extensions/core/context/patterns/context-exhaustion-detection.md`
- [ ] `.opencode/context/patterns/subagent-continuation-loop.md`
- [ ] `.opencode/extensions/core/context/patterns/subagent-continuation-loop.md`

## Edge Cases

1. **More than 99 handoffs in a single phase**: The `HH` component is zero-padded to 2 digits. If a phase exceeds 99 handoffs, the filename would use 3 digits (`100`). This is extremely unlikely (continuation loop max is 3), but the convention should specify that padding expands as needed rather than wrapping.

2. **Slug collisions**: Two handoffs in the same phase could theoretically generate identical slugs if the objective descriptions are the same. Mitigation: The `HH` component ensures uniqueness even if the slug is identical. If desired, append a short hash or increment suffix to the slug, but the `HH` number already disambiguates.

3. **Empty or very long objective descriptions**: Slug generation should truncate to ~40 characters and handle empty strings gracefully (fallback to phase name only, or `handoff` if both are empty).

4. **Special characters in phase/objective names**: Slug generation must strip or replace characters that are invalid in filenames (e.g., `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`). Kebab-case conversion handles most of these.

5. **Legacy handoff files**: Existing handoff files using the old naming convention will remain in the filesystem. The new convention applies to newly created handoffs. No migration of old files is required.

6. **`artifact_number` availability**: The `artifact_number` (MM) is provided in the delegation context to implementation agents. Research agents do not write handoffs, so this is not a concern. If a non-implementation agent were to write a handoff, it would need an alternative MM source (e.g., `next_artifact_number - 1`).

7. **Lean agent handoff count**: The lean-implementation-agent.md does not currently show progress file initialization with `handoff_count`. It references the handoff protocol but delegates to the general pattern. Ensure the lean agent either inherits the same progress file schema or references the general implementation agent's Stage 3.5 progress initialization.

## Next Steps

1. **Update format spec**: Edit `.opencode/context/formats/handoff-artifact.md` with the new naming convention, variable definitions, and slug generation guidelines. Mirror to `.opencode/extensions/core/context/formats/handoff-artifact.md`.
2. **Update agent definitions**: Edit `.opencode/agent/subagents/general-implementation-agent.md` Stage 4C to construct filenames using `artifact_number`, `handoff_count+1`, and auto-generated slug. Mirror to `.opencode/extensions/core/agents/general-implementation-agent.md`.
3. **Update lean agent**: Edit `.opencode/extensions/lean/agents/lean-implementation-agent.md` to reference the new naming convention in the handoff protocol section.
4. **Update pattern docs**: Edit `.opencode/context/patterns/context-exhaustion-detection.md` and `.opencode/context/patterns/subagent-continuation-loop.md` example paths. Mirror both to `.opencode/extensions/core/context/patterns/`.
5. **Verification**: Grep for any remaining `phase-.*-handoff-` patterns across `.opencode/` to ensure no references were missed.
6. **Task 528**: Proceed to dependent task #528 to update `skill-implementer/SKILL.md` continuation loop examples and any remaining pattern documentation references.
