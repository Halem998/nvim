# Implementation Plan: Fix Lean Extension Manifest Routing

- **Task**: 524 - Fix lean extension manifest routing
- **Status**: [COMPLETED]
- **Effort**: 15 minutes
- **Dependencies**: None
- **Research Inputs**: `specs/524_fix_lean_extension_manifest_routing/reports/01_manifest-routing-research.md`
- **Artifacts**: `specs/524_fix_lean_extension_manifest_routing/plans/01_manifest-routing-plan.md` (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: json
- **Lean Intent**: false

## Overview

Add a `routing` section to `.opencode/extensions/lean/manifest.json` that maps `lean` and `lean4` task types to the extension's specialized skills (`skill-lean-research` for research phase, `skill-lean-implementation` for implement phase). Currently the manifest lacks routing entirely, causing all lean tasks to fall through to generic agents. No plan-phase routing is needed because no lean-specific planner skill exists.

### Research Integration

The research report identified:
- The lean manifest is missing a `routing` key entirely
- The command files query `.routing.{phase}[$task_type]` via jq; missing routing causes fallback to defaults
- The `founder` extension provides the canonical working example
- Only `research` and `implement` phases need routing; `plan` falls back to `skill-planner` appropriately
- Both `"lean"` and `"lean4"` task type keys must be mapped for compatibility

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No specific ROADMAP.md item covers this fix, but it supports the "Agent System Quality" theme (Phase 1) by ensuring extensions correctly route to their specialized skills.

## Goals & Non-Goals

**Goals**:
- Add `routing` section to `.opencode/extensions/lean/manifest.json`
- Map both `lean` and `lean4` task types to `skill-lean-research` (research phase)
- Map both `lean` and `lean4` task types to `skill-lean-implementation` (implement phase)
- Validate the modified manifest parses as valid JSON
- Verify jq queries against the routing section return expected skill names

**Non-Goals**:
- Add routing to other extensions (nvim, typst, nix) — out of scope
- Create a new lean-specific planner skill
- Modify command routing logic
- Create new documentation files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Invalid JSON after manual edit | High | Low | Validate with `jq empty` immediately after editing |
| Wrong skill names in routing | Medium | Low | Skill names verified against directory names in research report |
| Trailing comma causing parse error | Medium | Low | Carefully match JSON comma placement; validate with jq |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add Routing Section and Verify [COMPLETED]

**Goal**: Insert the `routing` JSON section into the lean manifest and verify it works.

**Tasks**:
- [ ] Read current `.opencode/extensions/lean/manifest.json` to confirm state matches research
- [ ] Insert `routing` section between `provides` and `merge_targets` (after line 35, before line 36)
- [ ] Run `jq empty .opencode/extensions/lean/manifest.json` to validate JSON syntax
- [ ] Run jq query to verify `.routing.research.lean` returns `"skill-lean-research"`
- [ ] Run jq query to verify `.routing.research.lean4` returns `"skill-lean-research"`
- [ ] Run jq query to verify `.routing.implement.lean` returns `"skill-lean-implementation"`
- [ ] Run jq query to verify `.routing.implement.lean4` returns `"skill-lean-implementation"`
- [ ] Run jq query to confirm `.routing.plan` returns `null` (no plan routing, as intended)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/lean/manifest.json` — add `routing` section

**Exact JSON to insert** (including leading indentation):

```json
  "routing": {
    "research": {
      "lean": "skill-lean-research",
      "lean4": "skill-lean-research"
    },
    "implement": {
      "lean": "skill-lean-implementation",
      "lean4": "skill-lean-implementation"
    }
  },
```

**Verification commands**:
```bash
# Validate JSON syntax
jq empty .opencode/extensions/lean/manifest.json

# Verify research routing
jq -r '.routing.research.lean' .opencode/extensions/lean/manifest.json
# Expected output: skill-lean-research

jq -r '.routing.research.lean4' .opencode/extensions/lean/manifest.json
# Expected output: skill-lean-research

# Verify implement routing
jq -r '.routing.implement.lean' .opencode/extensions/lean/manifest.json
# Expected output: skill-lean-implementation

jq -r '.routing.implement.lean4' .opencode/extensions/lean/manifest.json
# Expected output: skill-lean-implementation

# Confirm no plan routing (returns "null")
jq -r '.routing.plan.lean // "null"' .opencode/extensions/lean/manifest.json
# Expected output: null
```

---

## Testing & Validation

- [ ] `jq empty` exits 0 (valid JSON)
- [ ] `jq '.routing.research.lean'` outputs `skill-lean-research`
- [ ] `jq '.routing.research.lean4'` outputs `skill-lean-research`
- [ ] `jq '.routing.implement.lean'` outputs `skill-lean-implementation`
- [ ] `jq '.routing.implement.lean4'` outputs `skill-lean-implementation`
- [ ] `jq '.routing.plan'` outputs `null`
- [ ] Full manifest structure matches the reference in the research report

## Artifacts & Outputs

- Modified file: `.opencode/extensions/lean/manifest.json` (single-line insertion of `routing` section)

## Rollback/Contingency

- Revert the single insertion using git: `git checkout -- .opencode/extensions/lean/manifest.json`
- Or manually delete the `routing` block (lines 36-45 after insertion) and remove the trailing comma after `provides` closing brace.
