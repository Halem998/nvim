# Implementation Plan: Task #268

- **Task**: 268 - Update manifest.json routing table with per-type keys
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task #264, #265, #266, #267
- **Research Inputs**: specs/268_founder_manifest_routing/reports/01_meta-research.md
- **Artifacts**: plans/01_manifest-routing.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Add per-type routing keys to the `plan` and `implement` sections of the founder extension's manifest.json. Currently only the `research` section has explicit keys for all 5 task types (market, analyze, strategy, legal, project). The plan and implement sections use a single `founder` fallback key, which means the routing system loses type information at those phases. All per-type keys will route to the same shared skills (skill-founder-plan and skill-founder-implement) but enable future per-type specialization without routing table changes.

### Research Integration

The research report confirms:
- The shared planner/implementer approach is intentional -- differentiation happens at the research phase
- The bare `founder` key must be retained as a fallback for legacy tasks without `task_type`
- EXTENSION.md routing table documentation needs updating to reflect per-type plan/implement keys
- README.md routing reference should also be checked

## Goals & Non-Goals

**Goals**:
- Add explicit per-type routing keys for all 5 task types in `plan` and `implement` sections of manifest.json
- Retain bare `founder` key as fallback in all sections
- Update EXTENSION.md routing documentation to reflect the new keys
- Verify JSON validity after editing

**Non-Goals**:
- Creating separate per-type plan or implement skills (all types share the same skill)
- Modifying skill or agent definitions
- Changing research routing (already complete)
- Runtime verification with actual task execution (depends on tasks 264-267 being completed first)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error in manifest.json | H | L | Validate JSON after editing |
| Documentation drift from manifest | M | M | Update docs in same phase as manifest |

## Implementation Phases

### Phase 1: Update manifest.json routing table [COMPLETED]

**Goal**: Add per-type routing keys for plan and implement sections

**Tasks**:
- [ ] Edit `.claude/extensions/founder/manifest.json` routing.plan section to add 5 per-type keys
- [ ] Edit `.claude/extensions/founder/manifest.json` routing.implement section to add 5 per-type keys
- [ ] Validate JSON syntax (parse with jq or similar)

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - add per-type keys to plan and implement routing sections

**Expected routing.plan after edit**:
```json
{
  "founder": "skill-founder-plan",
  "founder:market": "skill-founder-plan",
  "founder:analyze": "skill-founder-plan",
  "founder:strategy": "skill-founder-plan",
  "founder:legal": "skill-founder-plan",
  "founder:project": "skill-founder-plan"
}
```

**Expected routing.implement after edit**:
```json
{
  "founder": "skill-founder-implement",
  "founder:market": "skill-founder-implement",
  "founder:analyze": "skill-founder-implement",
  "founder:strategy": "skill-founder-implement",
  "founder:legal": "skill-founder-implement",
  "founder:project": "skill-founder-implement"
}
```

**Verification**:
- `jq . .claude/extensions/founder/manifest.json` parses without error
- All 5 per-type keys present in plan section
- All 5 per-type keys present in implement section
- Bare `founder` fallback key retained in all 3 sections

---

### Phase 2: Update EXTENSION.md documentation [COMPLETED]

**Goal**: Update the Language-Based Routing table in EXTENSION.md to reflect per-type plan/implement routing

**Tasks**:
- [ ] Update the routing table in EXTENSION.md to show per-type plan and implement entries
- [ ] Change the `/plan` and `/implement` rows from showing only `founder` key to showing all 5 per-type keys
- [ ] Add a note explaining that all types currently route to the same shared skill

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md` - update Language-Based Routing table (lines 139-152)

**Current table rows to update**:
```
| `/plan` | founder | skill-founder-plan | founder-plan-agent |
| `/implement` | founder | skill-founder-implement | founder-implement-agent |
```

**Updated table should show**:
```
| `/plan` (task_type: market) | founder:market | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: analyze) | founder:analyze | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: strategy) | founder:strategy | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: legal) | founder:legal | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: project) | founder:project | skill-founder-plan | founder-plan-agent |
| `/plan` (no task_type) | founder | skill-founder-plan | founder-plan-agent |
| `/implement` (task_type: market) | founder:market | skill-founder-implement | founder-implement-agent |
... (same pattern)
```

**Verification**:
- All 5 task types represented for plan routing
- All 5 task types represented for implement routing
- Fallback rows retained for tasks without task_type
- Table formatting is consistent and renders correctly in markdown

## Testing & Validation

- [ ] manifest.json parses as valid JSON
- [ ] All 18 routing entries present (6 research + 6 plan + 6 implement)
- [ ] EXTENSION.md routing table reflects actual manifest.json contents
- [ ] No existing routing entries removed or changed

## Artifacts & Outputs

- Updated `.claude/extensions/founder/manifest.json` with 12 new routing entries
- Updated `.claude/extensions/founder/EXTENSION.md` with expanded routing documentation

## Rollback/Contingency

Both files are tracked in git. If any issue is discovered:
- `git checkout -- .claude/extensions/founder/manifest.json .claude/extensions/founder/EXTENSION.md`
