# Implementation Plan: Task #226

- **Task**: 226 - Implement multi-line artifact linking in TODO.md for 2+ artifacts
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_artifact-linking-audit.md](../reports/01_artifact-linking-audit.md)
- **Artifacts**: plans/02_multiline-linking-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Implement a count-aware artifact linking format that uses inline format for single artifacts but switches to a multi-line indented list format when 2+ artifacts of the same type exist. This resolves the readability problem where tasks with many research iterations produce unreadable single-line comma-separated lists. The implementation follows a standards-first approach: update the canonical documentation, then propagate to core skills, then to extension skills.

### Research Integration

The research report identified 14 files across standards (5), core skills (4), extension skills (4), and README (1). The key insight is that skills append artifacts without awareness of existing count, producing comma accumulation. The fix requires count-aware logic at the point of insertion.

## Goals & Non-Goals

**Goals**:
- Define canonical multi-line format in state-management.md
- Update all core skills (researcher, planner, implementer, status-sync) with count-aware linking
- Update all extension skills that write artifact links
- Update documentation to reflect new format with examples
- Ensure backward compatibility (existing single-artifact entries remain valid)

**Non-Goals**:
- Migrating existing TODO.md entries (tasks can be left as-is)
- Changing the underlying state.json artifact storage (only TODO.md display format changes)
- Adding validation for existing comma-separated format (treat as valid single-line variant)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit tool pattern complexity | Medium | Medium | Provide clear old_string/new_string examples for each case |
| Extension skills diverge | Low | Low | Reference canonical standard rather than inline duplication |
| Regression in postflight | High | Low | Test with both 1-artifact and 2+-artifact scenarios |

## Implementation Phases

### Phase 1: Update Canonical Standards [COMPLETED]

**Goal**: Establish the authoritative definition of the multi-line artifact linking format.

**Tasks**:
- [ ] Add "Artifact Linking Format" subsection to `.claude/rules/state-management.md` (after existing "Artifact Linking" section around line 227)
- [ ] Define the single-artifact inline format (unchanged)
- [ ] Define the multi-artifact multi-line format with 2-space indentation
- [ ] Provide examples for all three artifact types (research, plan, summary)
- [ ] Document the count-detection and format-conversion rules

**Timing**: 30 minutes

**Files to modify**:
- `.claude/rules/state-management.md` - Add format definition subsection

**Edit Pattern**:
```
old_string: (end of existing Artifact Linking section)
new_string: (existing content + new Artifact Linking Format subsection)
```

The new subsection should include:
```markdown
### Artifact Linking Format

**Rule**: Use inline format when there is exactly 1 artifact of a given type. Use multi-line list format when there are 2 or more artifacts of the same type.

#### Single artifact (inline):
```markdown
- **Research**: [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
```

#### Multiple artifacts (multi-line list):
```markdown
- **Research**:
  - [01_research-findings.md]({NNN}_{SLUG}/reports/01_research-findings.md)
  - [02_supplemental.md]({NNN}_{SLUG}/reports/02_supplemental.md)
```

The label line (`- **Research**:`) ends with a colon and no link when multi-line. Each artifact gets its own `  - [filename](path)` line indented with 2 spaces.

#### Count-Aware Insertion Logic

When adding a new artifact link:

1. **No existing line**: Insert inline format `- **Type**: [file](path)`
2. **Existing inline (1 artifact)**: Convert to multi-line, adding both old and new links
3. **Existing multi-line (2+ artifacts)**: Append new `  - [file](path)` item
```

**Verification**:
- Review state-management.md for complete format definition
- Ensure examples cover single, conversion, and append cases

---

### Phase 2: Update Inline Status Update Patterns [COMPLETED]

**Goal**: Update the reusable inline-status-update pattern document to show both single and multi-line formats.

**Tasks**:
- [ ] Update "Adding Artifact Links" section in `.claude/context/core/patterns/inline-status-update.md` (lines 184-199)
- [ ] Add examples for multi-line format for each artifact type
- [ ] Reference the canonical standard in state-management.md

**Timing**: 20 minutes

**Files to modify**:
- `.claude/context/core/patterns/inline-status-update.md` - Expand artifact linking examples

**Edit Pattern**:
Replace the current three examples with expanded versions showing both single and multi-line:
```
old_string: (current "Adding Artifact Links" section content)
new_string: (expanded content with both formats per type)
```

**Verification**:
- Ensure pattern document shows both formats clearly
- Verify cross-reference to state-management.md

---

### Phase 3: Update Core Skills [COMPLETED]

**Goal**: Implement count-aware artifact linking logic in all four core skills.

**Tasks**:
- [ ] Update `.claude/skills/skill-researcher/SKILL.md` Stage 8 (lines 199-224)
- [ ] Update `.claude/skills/skill-planner/SKILL.md` Stage 8 (lines 206-231)
- [ ] Update `.claude/skills/skill-implementer/SKILL.md` Stage 8 (lines 290-315)
- [ ] Update `.claude/skills/skill-status-sync/SKILL.md` artifact_link operation (lines 203-215)

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-status-sync/SKILL.md`

**Edit Pattern for skill-researcher** (similar for others):

Replace the current Stage 8 TODO.md update instruction:
```markdown
old_string:
**Update TODO.md**: Add research artifact link:
```markdown
- **Research**: [MM_{short-slug}.md]({artifact_path})
```

new_string:
**Update TODO.md**: Add research artifact link using count-aware format.

See `.claude/rules/state-management.md` "Artifact Linking Format" for canonical rules. Use Edit tool:

1. **Read existing task entry** to detect current research links
2. **If no `- **Research**:` line exists**: Insert inline format:
   ```markdown
   - **Research**: [MM_{short-slug}.md]({artifact_path})
   ```
3. **If existing inline (single link)**: Convert to multi-line:
   ```markdown
   old_string: - **Research**: [existing.md](existing/path)
   new_string: - **Research**:
     - [existing.md](existing/path)
     - [MM_{short-slug}.md]({artifact_path})
   ```
4. **If existing multi-line**: Append new item before next field:
   ```markdown
   old_string:   - [last-item.md](last/path)
   - **Plan**:
   new_string:   - [last-item.md](last/path)
     - [MM_{short-slug}.md]({artifact_path})
   - **Plan**:
   ```
```

**skill-status-sync Edit Pattern**:

Replace the artifact_link table with references to the format standard:
```markdown
old_string:
| research | `- **Research**: [MM_{short-slug}.md]({path})` |
| plan | `- **Plan**: [MM_{short-slug}.md]({path})` |
| summary | `- **Summary**: [MM_{short-slug}-summary.md]({path})` |

new_string:
| research | Count-aware format (see Artifact Linking Format in state-management.md) |
| plan | Count-aware format (see Artifact Linking Format in state-management.md) |
| summary | Count-aware format (see Artifact Linking Format in state-management.md) |
```

**Verification**:
- Verify each skill's Stage 8 references the canonical standard
- Check that detection and conversion logic is clearly explained

---

### Phase 4: Update Extension Skills [COMPLETED]

**Goal**: Update extension skills that write artifact links to use count-aware format.

**Tasks**:
- [ ] Update `.claude/extensions/web/skills/skill-web-research/SKILL.md` (line 190)
- [ ] Update `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (line 264)
- [ ] Update `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (line 263)
- [ ] Update `.claude/extensions/present/skills/skill-grant/SKILL.md` (lines 452-455)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/present/skills/skill-grant/SKILL.md`

**Edit Pattern** (for each extension skill):

Replace inline format string with reference to standard:
```markdown
old_string: - **Research**: [MM_{short-slug}.md]({todo_link_path})
new_string: Use count-aware artifact linking format per `.claude/rules/state-management.md` "Artifact Linking Format"
```

Each extension skill should reference the canonical standard rather than duplicating the format rules inline.

**Verification**:
- Verify each extension skill references the canonical standard
- Ensure no hardcoded inline-only format strings remain

---

### Phase 5: Update Process Documentation [COMPLETED]

**Goal**: Update workflow process documentation to reflect the new format.

**Tasks**:
- [ ] Update `.claude/context/project/processes/research-workflow.md` (line 238)
- [ ] Update `.claude/context/project/processes/planning-workflow.md` (line 207)
- [ ] Update `.claude/rules/artifact-formats.md` to mention count-aware linking

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/project/processes/research-workflow.md`
- `.claude/context/project/processes/planning-workflow.md`
- `.claude/rules/artifact-formats.md`

**Edit Pattern**:

For process docs, update any artifact link examples to reference the canonical format:
```markdown
old_string: (inline format example)
new_string: Use count-aware artifact linking format per state-management.md
```

For artifact-formats.md, add a note in the relevant section:
```markdown
**Note**: When linking artifacts in TODO.md, use count-aware format defined in state-management.md (inline for 1 artifact, multi-line list for 2+).
```

**Verification**:
- Verify process documentation references canonical standard
- Ensure artifact-formats.md has cross-reference

---

### Phase 6: Update README Example [COMPLETED]

**Goal**: Update the README example task entry to demonstrate multi-line format.

**Tasks**:
- [ ] Update `.claude/README.md` example task entry (lines 363-366) to show a task with multiple research artifacts using multi-line format

**Timing**: 15 minutes

**Files to modify**:
- `.claude/README.md`

**Edit Pattern**:

The current example likely shows a single-artifact task. Add or modify to show multi-artifact:
```markdown
### Example (single artifact):
- **Research**: [01_findings.md](NNN_slug/reports/01_findings.md)

### Example (multiple artifacts):
- **Research**:
  - [01_findings.md](NNN_slug/reports/01_findings.md)
  - [02_supplemental.md](NNN_slug/reports/02_supplemental.md)
```

**Verification**:
- README example demonstrates multi-line format clearly
- Example is consistent with canonical standard

---

## Testing & Validation

- [ ] Verify state-management.md contains complete format definition with examples
- [ ] Verify inline-status-update.md shows both single and multi-line patterns
- [ ] Verify all 4 core skills reference the canonical standard
- [ ] Verify all 4 extension skills reference the canonical standard
- [ ] Verify process docs and artifact-formats.md have cross-references
- [ ] Verify README example demonstrates multi-line format
- [ ] Manual test: create a task, run /research twice, verify TODO.md shows multi-line format

## Artifacts & Outputs

- `specs/226_multiline_artifact_linking/plans/02_multiline-linking-plan.md` (this file)
- `specs/226_multiline_artifact_linking/summaries/03_multiline-linking-summary.md` (on completion)
- Updated files in .claude/rules/, .claude/skills/, .claude/extensions/, .claude/context/

## Rollback/Contingency

If implementation causes issues:
1. Revert changes to skill files first (most impactful)
2. Keep standard definition in state-management.md (documentation is harmless)
3. Existing comma-separated entries remain valid and readable

The change is additive and backward-compatible. Single-artifact entries continue to use inline format unchanged. Multi-line format is only applied when 2+ artifacts exist.
