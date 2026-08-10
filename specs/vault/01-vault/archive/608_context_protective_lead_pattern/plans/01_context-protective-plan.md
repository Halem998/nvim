# Implementation Plan: Task #608

- **Task**: 608 - context_protective_lead_pattern
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/608_context_protective_lead_pattern/reports/01_context-protective-lead.md
- **Artifacts**: plans/01_context-protective-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a formal pattern document that codifies how lead/orchestrator agents should protect their context window. The document establishes that leads act as project managers -- routing, tracking, and delegating -- never reading full artifacts or performing analytical work themselves. The primary deliverable is `.claude/context/patterns/context-protective-lead.md`, registered in the context index and cross-referenced from existing related patterns. The key architectural insight, emphasized by the user, is that synthesis in team workflows must be handled by a dedicated synthesis agent that receives teammate reports in its own fresh context, never by the lead reading all outputs.

### Research Integration

The research report (01_context-protective-lead.md) provides comprehensive findings:
- Identified `skill-orchestrate` as the existing reference implementation (400-token handoff pattern)
- Quantified team synthesis bloat at 4-12k tokens when the lead reads all teammate outputs
- Cataloged 7 anti-patterns with before/after fixes
- Proposed a context budget of <5k tokens above baseline for lead agents
- Recommended synthesis agent delegation as the highest-impact change

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" items in ROADMAP.md Phase 1, establishing a new quality standard for lead agent behavior.

## Goals & Non-Goals

**Goals**:
- Create a pattern document that establishes the context-protective lead principle
- Document the "lead as project manager" role with concrete rules
- Provide an anti-pattern catalog with before/after code examples
- Define a context budget (<5k tokens above baseline)
- Codify the synthesis delegation pattern (dedicated synthesis agent, not lead-inline)
- Reference `skill-orchestrate` as the existing exemplar
- Register the pattern in `context/index.json` for discovery

**Non-Goals**:
- Refactoring existing skills to comply (tasks 609 and 610 handle that)
- Creating enforcement lint scripts (future work)
- Modifying `skill-orchestrate` itself (already compliant)
- Creating a separate "lead-context-budget.md" standard (budget is embedded in the pattern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pattern document too long to be useful | M | L | Target 150-250 lines with clear sections; anti-patterns use compact table format |
| Overlap with thin-wrapper-skill.md | L | M | Cross-reference rather than duplicate; this pattern is complementary (thin-wrapper = structure, context-protective = context discipline) |
| Budget numbers become stale as system evolves | L | M | Express budgets as ratios/principles, not just absolute numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Draft the Pattern Document [COMPLETED]

**Goal**: Create the full pattern document at `.claude/context/patterns/context-protective-lead.md`.

**Tasks**:
- [x] Create file with header metadata (Created date, Purpose, Audience) *(completed)*
- [x] Write "Core Principles" section establishing the lead-as-project-manager role with 5 numbered rules *(completed)*
- [x] Write "Anti-Pattern Catalog" section as a table with 7 entries from the research report *(completed)*
- [x] Write "Before/After Examples" section with 3 concrete code examples *(completed)*
- [x] Write "Synthesis Delegation Pattern" section detailing dedicated synthesis agent fork *(completed)*
- [x] Write "Handoff Pattern" section referencing orchestrate-state-machine.md and 400-token budget *(completed)*
- [x] Write "Context Budget" section with per-component token limits table *(completed)*
- [x] Write "Enforcement Guidelines" section with skill author review checklist *(completed)*
- [x] Write "Reference Implementation" section pointing to skill-orchestrate *(completed)*
- [x] Write "Related Patterns" section with cross-references *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/context-protective-lead.md` - New file (target: 150-250 lines)

**Verification**:
- File exists and is well-structured markdown
- All 7 anti-patterns from the research report are represented
- Synthesis delegation pattern explicitly states a dedicated agent handles synthesis, not the lead
- Context budget section includes numeric limits
- Cross-references use correct file paths

---

### Phase 2: Register in Context Index [COMPLETED]

**Goal**: Add the new pattern to `.claude/context/index.json` so it is discoverable by agents and commands.

**Tasks**:
- [x] Read current index.json to identify the correct insertion point (patterns section) *(completed)*
- [x] Add an entry for `context-protective-lead.md` with appropriate `load_when` conditions *(completed: commands=[/meta], task_types=[meta], agents=[] -- team leads are skills not agents)*
- [x] Verify the entry's `line_count` matches the actual file *(completed: 248 lines)*
- [x] Verify index.json remains valid JSON after editing *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/index.json` - Add new entry for the pattern

**Verification**:
- `jq '.' .claude/context/index.json` parses without error
- `jq '.entries[] | select(.path == "context/patterns/context-protective-lead.md")' .claude/context/index.json` returns the new entry
- `load_when` conditions are appropriate (not always-load, but available to team skills and orchestrate)

---

### Phase 3: Cross-Reference and Validate [COMPLETED]

**Goal**: Ensure the new pattern is properly cross-referenced from related patterns and passes basic validation.

**Tasks**:
- [x] Add a brief cross-reference line in `team-orchestration.md` pointing to context-protective-lead.md *(completed)*
- [x] Add a brief cross-reference line in `thin-wrapper-skill.md` pointing to context-protective-lead.md *(completed)*
- [x] Verify all file paths referenced in the pattern document are valid *(completed: all 8 paths verified)*
- [x] Verify the pattern document line count is within 150-250 lines *(completed: 248 lines)*
- [x] Read the completed pattern document end-to-end to confirm coherence and completeness *(completed)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/context/patterns/team-orchestration.md` - Add cross-reference
- `.claude/context/patterns/thin-wrapper-skill.md` - Add cross-reference

**Verification**:
- All referenced file paths exist on disk
- Pattern document is 150-250 lines
- Cross-references in related patterns point to the correct path
- Document stands alone as a complete reference for tasks 609 and 610

## Testing & Validation

- [ ] Pattern document parses as valid markdown with no broken formatting
- [ ] `jq '.' .claude/context/index.json` validates cleanly
- [ ] All file paths referenced in the document exist
- [ ] Anti-pattern catalog has 7 entries matching the research findings
- [ ] Synthesis delegation section explicitly describes a dedicated synthesis agent (not lead-inline)
- [ ] Context budget section specifies <5k tokens above baseline
- [ ] Cross-references added to team-orchestration.md and thin-wrapper-skill.md

## Artifacts & Outputs

- `.claude/context/patterns/context-protective-lead.md` - The pattern document (primary deliverable)
- `.claude/context/index.json` - Updated with new entry
- `.claude/context/patterns/team-orchestration.md` - Cross-reference added
- `.claude/context/patterns/thin-wrapper-skill.md` - Cross-reference added

## Rollback/Contingency

Revert by removing the new pattern file, reverting the index.json entry, and removing cross-reference lines from team-orchestration.md and thin-wrapper-skill.md. All changes are additive -- no existing behavior is modified.
