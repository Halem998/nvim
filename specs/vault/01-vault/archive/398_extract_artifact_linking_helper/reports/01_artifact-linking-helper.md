# Research Report: Task #398

**Task**: 398 - Extract artifact linking helper
**Started**: 2026-04-13T00:00:00Z
**Completed**: 2026-04-13T00:00:00Z
**Effort**: 2-3 hours (implementation)
**Dependencies**: None (task 397 already completed)
**Sources/Inputs**:
- `.claude/skills/skill-researcher/SKILL.md` (Stage 8, lines 263-309)
- `.claude/skills/skill-planner/SKILL.md` (Stage 8, lines 284-330)
- `.claude/skills/skill-implementer/SKILL.md` (Stage 8, lines 335-381)
- `.claude/skills/skill-team-research/SKILL.md` (Stage 10, lines 462-495)
- `.claude/skills/skill-team-plan/SKILL.md` (Stage 10, lines 462-485)
- `.claude/skills/skill-team-implement/SKILL.md` (Stage 12, lines 487-510)
- `.claude/skills/skill-status-sync/SKILL.md` (artifact_link operation, lines 171-218)
- `.claude/scripts/postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`
- `.claude/context/reference/state-management-schema.md` (Artifact Linking Formats, lines 248-289)
- `.claude/context/standards/postflight-tool-restrictions.md`
- `specs/archive/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`
- 26 files across core skills and extensions carrying the count-aware linking pattern
**Artifacts**:
- `specs/398_extract_artifact_linking_helper/reports/01_artifact-linking-helper.md`
**Standards**: report-format.md, artifact-formats.md, state-management.md

## Executive Summary

- Six core skills and approximately 20 extension skills carry near-identical four-case TODO.md artifact-linking logic (no link / insert inline / convert inline to multi-line / append to multi-line). The duplication spans roughly 26 files total.
- Three existing `postflight-*.sh` scripts already handle the state.json side (jq artifact upsert) but do NOT handle TODO.md linking. The TODO.md logic remains inline in every skill as prose instructions for the Edit tool.
- The TODO.md artifact-linking logic cannot be a simple shell script because it requires the Edit tool (semantic text replacement), which is only available inside Claude Code, not via bash. This is the fundamental constraint.
- Recommended approach: a **context-only helper** -- extract the four-case logic into a single canonical context file (`.claude/context/patterns/artifact-linking-todo.md`) that all skills reference via a one-line `@`-import, replacing 20+ lines of duplicated instructions per skill with a single reference.
- This approach respects the postflight tool boundary (Edit tool is still invoked by the skill), eliminates drift risk, and requires no new scripts or skill wiring.

## Context & Scope

Task 397 identified that team skills were missing TODO.md artifact linking entirely and duplicated the logic from single-agent skills into the three team skills. This follow-up addresses the resulting duplication: six core skills plus ~20 extension skills now carry essentially identical four-case artifact-linking instructions.

The question is: what is the right abstraction to eliminate this duplication?

### Constraints

1. **Postflight tool restrictions**: After agent delegation, skills may only use Read, jq/Bash (on state.json), Edit (on specs/TODO.md), git, and rm. No MCP tools, no source file edits.
2. **Edit tool requirement**: The TODO.md artifact linking requires the Edit tool for semantic text replacement (detecting existing links, converting inline to multi-line format). This cannot be done by a shell script.
3. **Skill execution model**: Skills are markdown documents read by Claude Code. They contain instructions (prose + code blocks) that Claude follows. They are not executable scripts.

## Findings

### Current Duplication Inventory

**Core skills** (6 files, each carrying ~25 lines of artifact-linking instructions):

| Skill | Stage | Artifact Type | Field Name | "Next Field" Anchor |
|-------|-------|---------------|------------|---------------------|
| skill-researcher | Stage 8 | research | `**Research**` | `**Plan**` |
| skill-planner | Stage 8 | plan | `**Plan**` | `**Description**` |
| skill-implementer | Stage 8 | summary | `**Summary**` | `**Description**` |
| skill-team-research | Stage 10 | research | `**Research**` | `**Plan**` |
| skill-team-plan | Stage 10 | plan | `**Plan**` | `**Description**` |
| skill-team-implement | Stage 12 | summary | `**Summary**` | `**Description**` |

**Extension skills** (~20 files): The same pattern appears in nix, web, founder (11 skills), present (5 skills), and others. Each extension skill carries its own copy.

**Total**: ~26 files, each with ~20-25 lines of nearly identical instructions.

### Variation Analysis

The logic across all skills is structurally identical with three parameterized differences:

1. **Field name**: `**Research**`, `**Plan**`, or `**Summary**`
2. **Artifact type** (for state.json): `"research"`, `"plan"`, or `"summary"`
3. **Next field anchor** (for multi-line append): `**Plan**` or `**Description**`

The four cases themselves are invariant:
- Case 1: No existing line -- insert inline `- **{Type}**: [file](path)`
- Case 2: Existing inline (single link) -- convert to multi-line header + two bullet items
- Case 3: Existing multi-line -- append new bullet before next field
- Case 4 (implicit): Idempotency -- link already present, skip

### Existing Helpers (state.json side only)

Three postflight scripts exist for the state.json jq operations:
- `postflight-research.sh` -- updates status to "researched", replaces research artifacts
- `postflight-plan.sh` -- updates status to "planned", replaces plan artifacts
- `postflight-implement.sh` -- updates status to "completed", replaces summary artifacts

These scripts handle state.json but NOT TODO.md. They could be extended but that would not solve the Edit-tool constraint.

### skill-status-sync's artifact_link Operation

`skill-status-sync` already documents an `artifact_link` operation with count-aware logic (SKILL.md lines 171-218). However:
- It is explicitly "standalone only" -- not wired into workflow postflights
- It uses high-level references ("see state-management.md") rather than concrete Edit tool examples
- Calling it from postflight would require the Task tool (delegation), which violates the postflight restriction on complexity
- It would add a delegation hop (skill -> status-sync) adding latency and token cost

### Trade-off Analysis

#### Option A: Shell Script (`.claude/scripts/link-artifact-todo.sh`)

**Pros**: Single executable, callable from any context.
**Cons**: IMPOSSIBLE. The TODO.md linking requires the Edit tool, which is a Claude Code internal tool. Shell scripts cannot invoke the Edit tool. A `sed`-based approach would be fragile: detecting inline vs multi-line format, handling markdown escaping, and avoiding corruption of other task entries would require complex regex that is error-prone and hard to maintain.

**Verdict**: Not viable.

#### Option B: Reusable Skill

**Pros**: Skills can use the Edit tool natively.
**Cons**: Invoking a skill from postflight requires the Task tool (delegation), which adds a subagent hop. This violates the spirit of postflight restrictions (lightweight, fast operations). It also adds ~30s latency per artifact link and significant token overhead.

**Verdict**: Over-engineered. The linking is a simple Edit operation, not worth a delegation round-trip.

#### Option C: Context Pattern File (Recommended)

Create `.claude/context/patterns/artifact-linking-todo.md` containing the canonical four-case logic with clear parameter documentation. Each skill replaces its 20+ lines of inline instructions with:

```markdown
**Update TODO.md**: Link artifact using count-aware format.

See @.claude/context/patterns/artifact-linking-todo.md with parameters:
- `field_name`: **Research** | **Plan** | **Summary**
- `artifact_filename`: {NN}_{short-slug}.md
- `artifact_path`: full relative path
- `next_field`: **Plan** | **Description**
```

**Pros**:
- Single source of truth (one file to update when format changes)
- Zero runtime overhead (no delegation, no script execution)
- Works within postflight constraints (Edit tool is still invoked by the skill itself)
- Natural fit for the existing `@`-reference context loading system
- Extension skills can reference the same file

**Cons**:
- Still relies on Claude correctly following instructions (same as current approach)
- The skill still "carries" the logic in the sense that Claude must interpret and execute it

**Verdict**: Best balance of maintainability, simplicity, and constraint compliance.

#### Option D: Hybrid -- Context Pattern + Validation Script

Extend Option C with a lint script (`.claude/scripts/lint/validate-artifact-linking.sh`) that checks skills reference the canonical pattern file rather than carrying inline instructions. This catches drift during extension creation.

**Pros**: All benefits of C plus enforcement.
**Cons**: Additional maintenance of the lint script.

**Verdict**: Recommended as a stretch goal after Option C is implemented.

## Decisions

1. **Option C (context pattern file)** is the recommended approach. The Edit tool constraint makes shell scripts non-viable, and skill delegation is too heavyweight for postflight.
2. The context pattern file should be parameterized with `field_name`, `artifact_filename`, `artifact_path`, and `next_field`.
3. The file should include concrete Edit tool examples for all four cases, not just references to state-management.md.
4. All 6 core skills and ~20 extension skills should be updated to reference the pattern file.
5. The three existing `postflight-*.sh` scripts should remain as-is -- they correctly handle the state.json side and do not need changes.

## Recommendations

1. **Create** `.claude/context/patterns/artifact-linking-todo.md` with the canonical four-case logic, parameterized by field name, artifact filename, path, and next-field anchor.
2. **Update all 6 core skills** to replace inline Stage 8 artifact-linking instructions with a 4-line reference to the pattern file.
3. **Update ~20 extension skills** with the same replacement.
4. **Add an entry** to `.claude/context/index.json` for the new pattern file with `load_when` targeting all skills that perform artifact linking.
5. **Update** `.claude/context/reference/state-management-schema.md` "Count-Aware Linking" section to cross-reference the new pattern file.
6. **(Stretch)** Add a lint check that flags skills with inline artifact-linking instructions that should reference the pattern file.

### Implementation Phases

- **Phase 1**: Create the pattern file and update 6 core skills (~45 min)
- **Phase 2**: Update ~20 extension skills (~30 min, mechanical find-and-replace)
- **Phase 3**: Update index.json and state-management-schema.md references (~15 min)
- **Phase 4 (optional)**: Lint script for enforcement (~30 min)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Claude misinterprets parameterized instructions | Low | Medium | Include concrete examples for each artifact type in the pattern file |
| Extension skills have subtle variations | Low | Low | Audit all 26 files during implementation; the variation analysis shows they are structurally identical |
| Pattern file not loaded in context | Medium | Medium | Add to index.json with appropriate load_when targeting; skills also use direct `@`-reference |
| Breaking existing working skills during refactor | Low | High | Test one skill first (skill-researcher) end-to-end before batch updating others |

## Appendix

### Files Carrying the Duplicated Pattern (26 total)

**Core skills** (6):
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-team-research/SKILL.md`
- `.claude/skills/skill-team-plan/SKILL.md`
- `.claude/skills/skill-team-implement/SKILL.md`

**Extension skills** (~20):
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- `.claude/extensions/present/skills/skill-timeline/SKILL.md`
- `.claude/extensions/present/skills/skill-grant/SKILL.md`
- `.claude/extensions/present/skills/skill-funds/SKILL.md`
- `.claude/extensions/present/skills/skill-budget/SKILL.md`
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md`
- `.claude/extensions/founder/skills/skill-spreadsheet/SKILL.md`
- `.claude/extensions/founder/skills/skill-project/SKILL.md`
- `.claude/extensions/founder/skills/skill-meeting/SKILL.md`
- `.claude/extensions/founder/skills/skill-market/SKILL.md`
- `.claude/extensions/founder/skills/skill-legal/SKILL.md`
- `.claude/extensions/founder/skills/skill-finance/SKILL.md`
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md`
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md`
- `.claude/skills/skill-reviser/SKILL.md`

**Context/process files** (reference, not duplication):
- `.claude/context/processes/research-workflow.md`
- `.claude/context/processes/planning-workflow.md`

### Parameterization Map

| Artifact Type | Field Name | Next Field Anchor | Used By |
|---------------|------------|-------------------|---------|
| research | `**Research**` | `**Plan**` | skill-researcher, skill-team-research, extension research skills |
| plan | `**Plan**` | `**Description**` | skill-planner, skill-team-plan, extension plan skills |
| summary | `**Summary**` | `**Description**` | skill-implementer, skill-team-implement, extension implement skills |

### Proposed Pattern File Structure

```markdown
# Artifact Linking in TODO.md

## Parameters
- `{field_name}`: The bold field name (**Research**, **Plan**, or **Summary**)
- `{artifact_filename}`: Display name (e.g., `01_research-findings.md`)
- `{artifact_path}`: Relative path from project root
- `{next_field}`: The field that follows (for multi-line append anchor)

## Cases

### Case 1: No existing field line
[Insert inline format]

### Case 2: Existing inline (single link)
[Convert to multi-line]

### Case 3: Existing multi-line
[Append before next field]

### Case 4: Link already present
[Skip - idempotent]
```
