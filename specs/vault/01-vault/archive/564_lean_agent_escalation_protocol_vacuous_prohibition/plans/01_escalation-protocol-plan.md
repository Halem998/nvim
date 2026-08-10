# Implementation Plan: Lean Agent Escalation Protocol and Vacuous-Definition Prohibition

- **Task**: 564 - lean_agent_escalation_protocol_vacuous_prohibition
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_escalation-protocol-research.md
- **Artifacts**: plans/01_escalation-protocol-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a formal escalation protocol, vacuous-definition prohibition, phase-granular commits, and a complexity warning to the lean-implementation-agent and its associated skill and rules files. Changes target four files across two repositories (ProofChecker `.opencode/` and nvim `.claude/extensions/lean/`), ensuring the upstream template stays synchronized with the downstream instance.

### Research Integration

Research report `01_escalation-protocol-research.md` identified all four target files, documented their current gaps (no escalation protocol, no vacuous-def prohibition, no phase-granular commits, no complexity warning), and provided specific content recommendations including grep patterns, JSON metadata structures, and the Phase Checkpoint Protocol to port from `general-implementation-agent.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add vacuous-definition prohibition to MUST NOT sections and Zero-Debt gates in both lean agent files
- Add formal Escalation Protocol section requiring [BLOCKED] status with structured blocker documentation
- Port Phase Checkpoint Protocol from general-implementation-agent to the lean agent
- Add vacuous-definition rule to `lean4.md` rules file
- Add vacuous-definition check to skill Stage 6 verification
- Add task complexity warning to skill GATE IN for plans >20h estimated effort
- Make skill Stage 9 batch commit conditional on whether per-phase commits already exist

**Non-Goals**:
- Modifying the general-implementation-agent (source of the pattern, not a target)
- Adding automated enforcement tooling beyond grep checks
- Changing task management or state.json schemas
- Updating any skill other than skill-lean-implementation

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Grep pattern misses edge cases (multiline defs, `noncomputable` prefix) | M | M | Cover `noncomputable`, `theorem`, `lemma` keywords; note in comments that multiline is a known gap |
| Two-file sync burden (ProofChecker + upstream template) | L | L | Update both in the same phase, verify identical content |
| Effort parsing fails on varied plan formats | L | M | Degrade gracefully; warning is non-blocking, absence of parseable hours = no warning |
| Stage 9 conditional commit logic conflicts with edge cases | M | L | Check git log for "phase" in recent commits; if none found, batch commit proceeds normally |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Lean Agent Core Updates (Both Files) [COMPLETED]

**Goal**: Add escalation protocol, vacuous-definition prohibition, vacuous-def check in Zero-Debt Gate, and Phase Checkpoint Protocol to both lean-implementation-agent files.

**Tasks**:
- [ ] Add vacuous-definition prohibition to MUST NOT section in ProofChecker agent (`lean-implementation-agent.md` lines ~219-232), covering `def X := True`, `def X := Unit`, `def X := trivial`, `theorem`/`lemma` variants
- [ ] Add vacuous-definition grep check to Zero-Debt Completion Gate (after sorry check, before build verification) in ProofChecker agent
- [ ] Add formal Escalation Protocol section with structured [BLOCKED] requirements, metadata JSON structure, and clear prohibition on papering over with vacuous definitions
- [ ] Add Phase Checkpoint Protocol section (ported from general-implementation-agent.md lines 341-357) with per-phase git commit instructions
- [ ] Apply identical four changes to upstream template at `.claude/extensions/lean/agents/lean-implementation-agent.md`
- [ ] Verify both files have consistent content for the added sections

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/agent/subagents/lean-implementation-agent.md` - Add 4 sections/modifications
- `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md` - Mirror same 4 changes

**Verification**:
- Both files contain "Escalation Protocol" section
- Both files contain "Vacuous" in MUST NOT section
- Both files contain "Phase Checkpoint Protocol" section
- Both Zero-Debt Gates include vacuous_count grep check

---

### Phase 2: Rules File Update [COMPLETED]

**Goal**: Add vacuous-definition prohibition section to the lean4 rules file.

**Tasks**:
- [ ] Add "Vacuous Definitions (PROHIBITED)" section to `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md` with examples of prohibited patterns and the escalation directive
- [ ] Include `theorem` and `lemma` keywords in addition to `def`
- [ ] Note the semantic equivalence to `sorry` for context

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md` - Add Vacuous Definitions section

**Verification**:
- File contains "Vacuous Definitions (PROHIBITED)" section
- Section lists all prohibited patterns (`def`, `theorem`, `lemma` with `:= True`, `:= Unit`, `:= trivial`)

---

### Phase 3: Skill File Updates (Stage 6, GATE IN, Stage 9) [COMPLETED]

**Goal**: Add vacuous-definition check to Stage 6, complexity warning to GATE IN, and make Stage 9 batch commit conditional.

**Tasks**:
- [ ] Add vacuous-definition grep check to Stage 6 Zero-Debt Verification Gate in SKILL.md, including `noncomputable` prefix handling and `theorem`/`lemma` keywords
- [ ] Add complexity warning after plan loading in GATE IN (Stage 1), extracting effort hours with graceful degradation if unparseable
- [ ] Make Stage 9 batch commit conditional: check if recent git log contains phase-scoped commits, skip batch if per-phase commits already exist
- [ ] Ensure complexity warning is non-blocking (warning only, does not halt execution)

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` - Modify Stage 6, Stage 1 (GATE IN), Stage 9

**Verification**:
- Stage 6 includes `vacuous_count` grep pattern
- GATE IN has effort extraction and >20h threshold warning
- Stage 9 commit is guarded by `git log --oneline` check for existing phase commits

---

## Testing & Validation

- [ ] Grep both lean-implementation-agent files for "Escalation Protocol" section presence
- [ ] Grep both lean-implementation-agent files for "vacuous" in MUST NOT section
- [ ] Grep lean4.md for "Vacuous Definitions" section
- [ ] Grep SKILL.md Stage 6 for "vacuous_count" variable
- [ ] Grep SKILL.md for effort threshold warning (">20" or "20h")
- [ ] Verify Stage 9 conditional logic references "phase" in git log check
- [ ] Confirm no syntax errors by visual review of markdown structure in all modified files

## Artifacts & Outputs

- `specs/564_lean_agent_escalation_protocol_vacuous_prohibition/plans/01_escalation-protocol-plan.md` (this file)
- Modified: `/home/benjamin/Projects/ProofChecker/.opencode/agent/subagents/lean-implementation-agent.md`
- Modified: `/home/benjamin/.config/nvim/.claude/extensions/lean/agents/lean-implementation-agent.md`
- Modified: `/home/benjamin/Projects/ProofChecker/.opencode/rules/lean4.md`
- Modified: `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md`

## Rollback/Contingency

All changes are additive markdown content. Rollback via `git checkout -- <file>` on each modified file. No schema changes, no binary artifacts, no build dependencies. If the vacuous-definition grep pattern proves too aggressive, it can be narrowed without affecting other additions.
