# Implementation Plan: Update Founder Extension Documentation for Phased Workflow

- **Task**: 270 - Update founder extension documentation for phased workflow
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: Tasks 262, 263, 264, 265, 266, 267, 268, 269
- **Research Inputs**: specs/270_founder_extension_documentation/reports/01_meta-research.md
- **Artifacts**: plans/01_extension-documentation.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update all founder extension documentation to reflect the v3.0 architecture where all 5 task types (market, analyze, strategy, legal, project) follow the standard `/research -> /plan -> /implement` phased lifecycle. The /project command documentation needs the largest changes since it previously documented a monolithic workflow. EXTENSION.md and README.md need version bumps and routing table updates. manifest.json needs a version bump to 3.0.0.

### Research Integration

Key findings from research report:
- /project command currently documents monolithic workflow where project-agent does everything in one shot
- market.md and strategy.md serve as templates for the phased workflow documentation pattern
- All 5 commands now share the same lifecycle with differentiation only at the research phase
- Breaking change: project-agent output is now a research report, not a Typst file

## Goals & Non-Goals

**Goals**:
- Document the unified phased workflow for all 5 founder commands
- Update /project command docs to match the market.md/strategy.md phased pattern
- Update EXTENSION.md to v3.0 with complete per-type routing table
- Update README.md to v3.0 with unified workflow description
- Bump manifest.json version to 3.0.0
- Document breaking changes from v2.x

**Non-Goals**:
- Changing any code or agent behavior (documentation only)
- Creating new command files
- Modifying the routing logic itself
- Updating individual market/analyze/strategy/legal command docs (already correct)

## Risks & Mitigations

- Risk: Documentation written before tasks 262-269 are implemented, causing inconsistencies. Mitigation: This task depends on all 8 prior tasks; verify implementation state before executing. Impact: M, Likelihood: L.
- Risk: Missing sections in /project command doc. Mitigation: Use market.md as a concrete template and check all sections systematically. Impact: L, Likelihood: L.

## Implementation Phases

### Phase 1: Update /project Command Documentation [COMPLETED]

**Goal:** Rewrite project.md to document the phased workflow instead of the monolithic one.

**Tasks:**
- [ ] Read current `.claude/extensions/founder/commands/project.md`
- [ ] Read `.claude/extensions/founder/commands/market.md` as template reference
- [ ] Update Overview section: mention standard phased workflow
- [ ] Replace Workflow Summary: autonomous flow -> phased flow (`/project -> /research N -> /plan N -> /implement N`)
- [ ] Update STAGE 2: DELEGATE section for research-only routing to project-agent
- [ ] Update CHECKPOINT 2: GATE OUT for research output only (report, not Typst file)
- [ ] Update Output Artifacts section with new artifact locations (reports/ instead of direct output)
- [ ] Add examples showing the full `/research -> /plan -> /implement` lifecycle
- [ ] Remove references to TRACK and REPORT modes from command stage (these move to /implement)

**Timing:** 25 minutes

**Files to modify:**
- `.claude/extensions/founder/commands/project.md` - full rewrite of workflow sections

**Verification:**
- project.md documents phased workflow matching market.md pattern
- No references to monolithic project-agent behavior remain
- TRACK/REPORT modes referenced only in context of /implement phase

---

### Phase 2: Update EXTENSION.md [COMPLETED]

**Goal:** Update EXTENSION.md to v3.0 with complete routing table and unified workflow diagram.

**Tasks:**
- [ ] Read current `.claude/extensions/founder/EXTENSION.md`
- [ ] Update version references from v2.x to v3.0
- [ ] Update routing table to show all 5 types across all 3 phases (research, plan, implement)
- [ ] Update workflow diagram to show standard lifecycle for all commands
- [ ] Remove references to project-agent's monolithic behavior
- [ ] Add "Breaking Changes from v2.x" section documenting the 4 breaking changes from research
- [ ] Update agent descriptions (project-agent is now research-only)

**Timing:** 15 minutes

**Files to modify:**
- `.claude/extensions/founder/EXTENSION.md` - version bump, routing table, workflow diagram

**Verification:**
- Routing table shows all 15 entries (5 types x 3 phases)
- No v2.x version references remain
- Breaking changes section present

---

### Phase 3: Update README.md and Bump manifest.json [COMPLETED]

**Goal:** Update README.md to v3.0 and bump manifest.json version.

**Tasks:**
- [ ] Read current `.claude/extensions/founder/README.md`
- [ ] Update version references from v2.x to v3.0
- [ ] Update workflow description to show unified phased pattern for all 5 commands
- [ ] Update agent descriptions (project-agent is research-only)
- [ ] Update routing reference summary
- [ ] Update quick start examples to show phased pattern
- [ ] Read current `.claude/extensions/founder/manifest.json`
- [ ] Bump version from current value to `"3.0.0"`

**Timing:** 15 minutes

**Files to modify:**
- `.claude/extensions/founder/README.md` - version bump, workflow description, agent descriptions
- `.claude/extensions/founder/manifest.json` - version field only

**Verification:**
- README.md shows v3.0 with unified workflow
- manifest.json version is "3.0.0"
- Quick start examples demonstrate phased workflow

---

### Phase 4: Cross-File Consistency Review [COMPLETED]

**Goal:** Verify all 4 files are internally consistent and align with each other.

**Tasks:**
- [ ] Verify routing table in EXTENSION.md matches manifest.json routing entries
- [ ] Verify command workflow in project.md matches EXTENSION.md workflow diagram
- [ ] Verify agent descriptions are consistent across all 3 documentation files
- [ ] Verify no stale v2.x references remain in any file
- [ ] Verify breaking changes are documented consistently

**Timing:** 5 minutes

**Verification:**
- All files reference v3.0
- Routing information is consistent across files
- No contradictions between files

## Testing & Validation

- [ ] All 4 files updated and saved
- [ ] No v2.x version references remain in any updated file
- [ ] /project command docs follow same phased pattern as /market
- [ ] Routing table in EXTENSION.md has 15 entries (5 types x 3 phases)
- [ ] manifest.json version is "3.0.0"
- [ ] Breaking changes from v2.x are documented

## Artifacts & Outputs

- plans/01_extension-documentation.md (this plan)
- summaries/01_extension-documentation-summary.md (post-implementation)
- Modified files:
  - `.claude/extensions/founder/commands/project.md`
  - `.claude/extensions/founder/EXTENSION.md`
  - `.claude/extensions/founder/README.md`
  - `.claude/extensions/founder/manifest.json`

## Rollback/Contingency

All changes are documentation-only. Rollback via `git checkout` of the 4 affected files. No code behavior changes, so no risk of breaking functionality.
