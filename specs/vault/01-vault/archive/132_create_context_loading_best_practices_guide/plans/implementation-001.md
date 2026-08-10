# Implementation Plan: Task #132

**Task**: OC_132 - Create context loading best practices guide
**Version**: 001
**Created**: 2026-03-04
**Language**: meta

## Overview

Create a comprehensive guide at `.opencode/docs/guides/context-loading-best-practices.md` that documents the "Push vs Pull" context loading strategy implemented in Task 128. The guide will focus on the Push Context model (critical context injection via `<context_injection>` blocks) while acknowledging the Pull model (on-demand @-references) for optional documentation. The guide will include concrete examples from the 11 migrated skills and provide a decision framework for skill developers.

## Phases

### Phase 1: Create Guide Structure and Core Content [COMPLETED]

**Status**: [COMPLETED]
**Completed**: 2026-03-04

**Objectives**:
1. Create the guide file at `.opencode/docs/guides/context-loading-best-practices.md`
2. Write introduction explaining why context loading matters
3. Document the Push Model with XML structure and examples
4. Document the Pull Model with @-reference patterns
5. Create comparison table showing differences between models

**Files to create**:
- `.opencode/docs/guides/context-loading-best-practices.md` - Main guide file

**Steps**:
1. Create file header with title, version, and purpose
2. Write "Introduction" section explaining context loading importance
3. Write "Push Model" section with:
   - Definition and purpose
   - XML structure template (`<context_injection>` block)
   - Execution flow explanation
   - When to use (strict formats, standards, workflow control)
4. Write "Pull Model" section with:
   - Definition and purpose
   - @-reference syntax examples
   - When to use (optional docs, large files, examples)
5. Create comparison table: Push vs Pull characteristics

**Verification**:
- [ ] File exists at correct path
- [ ] Introduction explains context loading importance
- [ ] Push Model section has XML code examples
- [ ] Pull Model section has @-reference examples
- [ ] Comparison table is complete

---

### Phase 2: Add Real Examples and Decision Framework [COMPLETED]

**Status**: [COMPLETED]
**Completed**: 2026-03-04

**Objectives**:
1. Add concrete examples from existing skills (skill-planner, skill-researcher, skill-implementer, skill-orchestrator)
2. Create decision checklist for choosing Push vs Pull
3. Document migration path from Pull to Push model
4. Cross-reference related standards (skill-structure.md v2.0, context/index.md)
5. Add "Next Steps" section for skill developers

**Files to modify**:
- `.opencode/docs/guides/context-loading-best-practices.md` - Add examples and decision framework

**Steps**:
1. Add "Examples from Core Skills" section with:
   - skill-planner: 3 injected files (plan-format.md, status-markers.md, task-breakdown.md)
   - skill-researcher: 2 injected files (report-format.md, status-markers.md)
   - skill-implementer: 4 injected files (return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md)
   - skill-orchestrator: 2 injected files (orchestration-core.md, state-management.md)
2. Add "Decision Framework" section with checklist:
   - Is this context required for correct operation? (Yes -> Push)
   - Is this context a strict format/standard? (Yes -> Push)
   - Is this context optional reference material? (Yes -> Pull)
   - Is this context >500 lines? (Yes -> Consider Pull)
3. Add "Migration Guide" section explaining how to migrate existing skills from Pull to Push
4. Add "Related Documentation" section linking to:
   - `skill-structure.md` v2.0 (Push Context standard)
   - `context/index.md` (Pull Context catalog)
   - `.claude/docs/guides/context-loading-best-practices.md` (historical Pull model reference)
5. Add "Summary" with key takeaways

**Verification**:
- [ ] Examples section shows actual code from 4 skills
- [ ] Decision checklist has 4 clear criteria
- [ ] Migration guide has clear steps
- [ ] Related documentation links are valid
- [ ] Summary has 3-5 key takeaways

---

## Dependencies

- **Task 128**: Push Context model implementation (completed)
- **skill-structure.md v2.0**: Defines the Push Context standard (exists)
- **context/index.md**: Catalogs Pull Context files (exists)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Duplication with deprecated .claude guide | Focus exclusively on Push model; reference old guide only as historical context |
| Guide becomes outdated | Include version number and last-updated date; link to skill-structure.md for latest standard |
| Developers confused by two guides | Clearly title this guide "Push Context Model"; explain distinction in introduction |
| Examples become stale | Use stable skill files that follow the standard pattern |

## Success Criteria

- [ ] Guide created at `.opencode/docs/guides/context-loading-best-practices.md`
- [ ] Guide explains Push vs Pull distinction clearly
- [ ] Guide includes concrete examples from at least 4 core skills
- [ ] Guide has decision checklist for choosing Push vs Pull
- [ ] Guide references skill-structure.md v2.0 and context/index.md
- [ ] Guide follows documentation standards (no emojis, clear headings)
- [ ] File is approximately 150-250 lines (concise but comprehensive)

## Artifacts & Outputs

- `.opencode/docs/guides/context-loading-best-practices.md` - Context loading best practices guide

## Rollback/Contingency

If the guide needs significant revision:
1. Create new version with incremental improvements
2. Keep existing guide as reference during revision
3. Update links in related documentation
