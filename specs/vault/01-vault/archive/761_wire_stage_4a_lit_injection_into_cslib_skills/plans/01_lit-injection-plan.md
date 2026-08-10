# Implementation Plan: Task #761

- **Task**: 761 - Wire Stage 4a literature injection into CSLib skills
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/761_wire_stage_4a_lit_injection_into_cslib_skills/reports/01_lit-injection-cslib-skills.md
- **Artifacts**: plans/01_lit-injection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Wire the `--lit` flag's literature briefing injection into the 4 CSLib skill files that currently receive `lit_flag` in their delegation context but never act on it. The hard variants already have Stage 4a with memory retrieval and need only the lit_context block appended. The base variants lack Stage 4a entirely and need both memory retrieval and lit_context added as a new section, plus updates to Stage 4/5 prompt descriptions. The canonical code block is identical across all 4 files; only the memory retrieval third argument (focus_prompt vs empty string) and the Stage 5 prompt parameter list differ.

### Research Integration

Research report `01_lit-injection-cslib-skills.md` provided:
- Exact insertion points for each file (line numbers confirmed by reading the files)
- Canonical code blocks to insert, derived from `skill-researcher/SKILL.md` and `skill-implementer/SKILL.md`
- Confirmation that the lit_context block is identical across all files
- Identification that base variants also lack memory retrieval (bonus scope, but required for feature parity with general skills)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is an infrastructure parity fix for the CSLib extension skills.

## Goals & Non-Goals

**Goals**:
- All 4 CSLib skills inject `lit_context` into subagent prompts when `lit_flag == "true"`
- Base variants gain Stage 4a with both memory retrieval and literature briefing
- Hard variants gain lit_context block appended to their existing Stage 4a
- Stage 5 prompt parameter lists updated to include `lit_context` in all 4 files

**Non-Goals**:
- Modifying CSLib agent definitions (agents already handle `<literature-briefing>` blocks)
- Changing `literature-briefing.sh` or `memory-retrieve.sh` scripts
- Adding tests (skill files are SKILL.md documentation, not executable code)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Insertion at wrong line breaks stage flow | M | L | Verified insertion points by reading all 4 files; use surrounding context for Edit operations |
| Memory retrieval added to base skills may conflict with existing flow | L | L | Pattern is identical to general skills which work correctly; base skills have no conflicting logic |
| Stage numbering inconsistency after insertion | M | L | Follow exact naming convention from reference skills: "Stage 4a: Memory and Literature Retrieval (Auto)" for base, append to existing "Stage 4a" for hard |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire base CSLib skills (research + implementation) [COMPLETED]

**Goal**: Add Stage 4a (memory + literature retrieval) to `skill-cslib-research/SKILL.md` and `skill-cslib-implementation/SKILL.md`, and update their Stage 4/5 prompt descriptions.

**Tasks**:
- [x] Add Stage 4a section to `skill-cslib-research/SKILL.md` after Stage 3 (line 48) and before Stage 4 (line 50), with memory retrieval using `"$focus_prompt"` and lit_context block *(completed)*
- [x] Update `skill-cslib-research/SKILL.md` Stage 4 subagent invocation to include `memory_context` and `lit_context` in prompt description *(completed)*
- [x] Add Stage 4a section to `skill-cslib-implementation/SKILL.md` after Stage 3 (line 60) and before Stage 4 (line 62), with memory retrieval using `""` (no focus_prompt) and lit_context block *(completed)*
- [x] Update `skill-cslib-implementation/SKILL.md` Stage 4 subagent invocation to include `memory_context` and `lit_context` in prompt description *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-cslib-research/SKILL.md` - Add Stage 4a section, update Stage 4 invocation
- `.claude/skills/skill-cslib-implementation/SKILL.md` - Add Stage 4a section, update Stage 4 invocation

**Verification**:
- Each file contains `### Stage 4a: Memory and Literature Retrieval (Auto)` section
- Each file contains `lit_context=""` initialization and `literature-briefing.sh` call
- Each file contains `memory_context=""` initialization and `memory-retrieve.sh` call
- Stage 4 invocation mentions `memory_context` and `lit_context`

---

### Phase 2: Wire hard CSLib skills (research-hard + implementation-hard) [COMPLETED]

**Goal**: Append lit_context block to existing Stage 4a in `skill-cslib-research-hard/SKILL.md` and `skill-cslib-implementation-hard/SKILL.md`, and update their Stage 5 prompt parameter lists.

**Tasks**:
- [x] Append lit_context bash block and note to `skill-cslib-research-hard/SKILL.md` Stage 4a after the memory retrieval `fi` (line 125), before the `---` separator *(completed)*
- [x] Update `skill-cslib-research-hard/SKILL.md` Stage 5 prompt parameter list from `[..., memory_context, focus]` to `[..., memory_context, lit_context, focus]` *(completed)*
- [x] Update `skill-cslib-research-hard/SKILL.md` Stage 5 description note to mention literature briefing injection *(completed)*
- [x] Append lit_context bash block and note to `skill-cslib-implementation-hard/SKILL.md` Stage 4a after the memory retrieval `fi` (line 163), before the `---` separator *(completed)*
- [x] Update `skill-cslib-implementation-hard/SKILL.md` Stage 5 prompt parameter list from `[..., memory_context]` to `[..., memory_context, lit_context]` *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-cslib-research-hard/SKILL.md` - Append lit block to Stage 4a, update Stage 5
- `.claude/skills/skill-cslib-implementation-hard/SKILL.md` - Append lit block to Stage 4a, update Stage 5

**Verification**:
- Each hard skill file contains `lit_context=""` initialization and `literature-briefing.sh` call
- Each hard skill's Stage 5 prompt list includes `lit_context`
- The lit_context block appears AFTER the memory retrieval block, not before
- The note about `lit_flag` independence from `clean_flag` is present

---

### Phase 3: Cross-file verification [COMPLETED]

**Goal**: Verify all 4 files have consistent lit_context wiring matching the reference implementations.

**Tasks**:
- [x] Grep all 4 CSLib skill files for `lit_context` and `literature-briefing.sh` to confirm presence *(completed)*
- [x] Compare the lit_context block in each file against the canonical block from `skill-researcher/SKILL.md` *(completed)*
- [x] Verify Stage 5 prompt parameter lists in all 4 files include `lit_context` *(completed)*
- [x] Verify no other CSLib-related skills were missed (check for any additional `skill-cslib-*` directories) *(completed: skill-cslib-vet is not a research/implementation skill, correctly excluded)*

**Timing**: 10 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- `grep -l "literature-briefing.sh"` returns all 4 CSLib skill files plus the 6 reference files
- No `skill-cslib-*` directory exists that lacks lit_context wiring

## Testing & Validation

- [x] All 4 CSLib skill SKILL.md files contain `lit_context=""` initialization
- [x] All 4 CSLib skill SKILL.md files contain `literature-briefing.sh` call gated on `lit_flag`
- [x] All 4 CSLib skill SKILL.md files include `lit_context` in their Stage 4/5 subagent prompt description
- [x] Base variants include both memory retrieval and lit injection in Stage 4a
- [x] Hard variants have lit injection appended after memory retrieval in existing Stage 4a
- [x] The note about `lit_flag` independence from `clean_flag` is present in all 4 files

## Artifacts & Outputs

- plans/01_lit-injection-plan.md (this file)
- summaries/01_lit-injection-summary.md (implementation summary)

## Rollback/Contingency

All changes are to SKILL.md documentation files under `.claude/skills/`. Revert with `git checkout -- .claude/skills/skill-cslib-*/SKILL.md` if any issues arise. No executable code or configuration is modified.
