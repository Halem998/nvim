# Implementation Plan: Task #261

- **Task**: 261 - project_manifest_update
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task #260 (COMPLETED)
- **Research Inputs**: specs/261_project_manifest_update/reports/01_manifest-update-research.md
- **Artifacts**: plans/01_manifest-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update the founder extension manifest.json to register project-agent, skill-project, and project.md command created by Task #260. Also add the project-timeline.typ template entry to index-entries.json for context discovery.

### Research Integration

Research identified 4 exact changes to manifest.json and 1 addition to index-entries.json. No changes needed to routing.plan or routing.implement sections since generic "founder" routing handles project tasks.

## Goals & Non-Goals

**Goals**:
- Register project-agent.md in provides.agents array
- Register skill-project in provides.skills array
- Register project.md in provides.commands array
- Add founder:project routing entry to routing.research section
- Add project-timeline.typ template to index-entries.json

**Non-Goals**:
- Modifying routing.plan or routing.implement (generic routing sufficient)
- Creating new files (all artifacts exist from Task #260)
- Changing EXTENSION.md (already updated by Task #260)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error | Extension fails to load | Low | Validate with jq after editing |
| Incorrect array position | Visual inconsistency | Low | Follow existing alphabetical ordering |

## Implementation Phases

### Phase 1: Update manifest.json [COMPLETED]

**Goal**: Add all four entries to manifest.json

**Tasks**:
- [ ] Add "project-agent.md" to provides.agents array (after legal-council-agent.md)
- [ ] Add "skill-project" to provides.skills array (after skill-legal)
- [ ] Add "project.md" to provides.commands array (after legal.md)
- [ ] Add "founder:project": "skill-project" to routing.research section (after founder:legal)
- [ ] Validate JSON syntax with jq

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Add 4 entries

**Verification**:
- `jq '.' manifest.json` succeeds without error
- grep confirms all entries present

---

### Phase 2: Update index-entries.json [COMPLETED]

**Goal**: Add project-timeline.typ template entry for context discovery

**Tasks**:
- [ ] Add project-timeline.typ entry to entries array
- [ ] Include proper load_when metadata for agents, languages, commands
- [ ] Validate JSON syntax with jq

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/founder/index-entries.json` - Add 1 entry

**Verification**:
- `jq '.' index-entries.json` succeeds without error
- grep confirms project-timeline.typ entry present

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm extension loads correctly with new entries

**Tasks**:
- [ ] Run jq to validate both JSON files
- [ ] Verify all 5 additions are present
- [ ] Confirm no duplicate entries

**Timing**: 5 minutes

**Verification**:
- All JSON files valid
- Extension registration complete

## Testing & Validation

- [ ] `jq '.' .claude/extensions/founder/manifest.json` - Valid JSON
- [ ] `jq '.' .claude/extensions/founder/index-entries.json` - Valid JSON
- [ ] grep -q "project-agent.md" manifest.json
- [ ] grep -q "skill-project" manifest.json
- [ ] grep -q "project.md" manifest.json
- [ ] grep -q "founder:project" manifest.json
- [ ] grep -q "project-timeline.typ" index-entries.json

## Artifacts & Outputs

- specs/261_project_manifest_update/plans/01_manifest-update-plan.md (this file)
- specs/261_project_manifest_update/summaries/01_manifest-update-summary.md (after implementation)

## Rollback/Contingency

If JSON becomes invalid:
1. Use git to restore original manifest.json and index-entries.json
2. Re-apply changes one at a time with validation between each
