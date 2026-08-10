# Research Report: Task #98

**Task**: 98 - Remove deprecated index.md and consolidate context index to JSON
**Started**: 2026-03-01T00:00:00Z
**Completed**: 2026-03-01T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (Glob, Grep, Read)
**Artifacts**: specs/098_consolidate_context_index_to_json/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- index.md is already marked deprecated (since 2026-02-24) and has a deprecation notice pointing to index.json
- 18 active files in `.claude/` reference index.md (excluding self-references, archives, and .opencode mirror); 17 more in `.opencode/` mirror
- index.schema.json is referenced by only 3 files and provides useful documentation of the index.json structure -- recommend keeping it in place
- index.json is already the primary system used by agents and CLAUDE.md files
- Migration is straightforward: most references are in YAML config snippets (e.g., `index: ".claude/context/index.md"`) that should be updated to `index: ".claude/context/index.json"`

## Context and Scope

Task 98 asks to remove the deprecated `index.md` from `.claude/context/` and consolidate all context discovery onto `index.json`. The scope includes:
1. Identifying all references to `index.md`
2. Evaluating `index.schema.json` for removal or relocation
3. Producing a migration plan

## Findings

### 1. File Analysis

#### index.md (552 lines)
- A human-readable markdown file listing all context files with descriptions, loading strategies, and navigation
- Already contains a **DEPRECATION NOTICE** (line 7) directing agents to use index.json
- Self-referential (references itself 3 times in loading examples)
- Contains historical migration notes (Tasks 240, 246) that are informational only
- Content is fully superseded by index.json entries with richer metadata (topics, keywords, load_when)

#### index.json (~700 lines)
- Machine-readable JSON with structured entries for all context files
- Already referenced by CLAUDE.md, 3 agent files (neovim-research, general-research, planner), and context-discovery.md
- References `"$schema": "./index.schema.json"` on line 2
- Provides automated discovery via jq queries -- strictly more capable than index.md

#### index.schema.json (127 lines)
- JSON Schema (draft 2020-12) defining the structure of index.json
- Referenced by 3 files:
  - `index.json` itself (line 2, `$schema` pointer)
  - `context-index-migration.md` (schema validation example)
  - `context-discovery.md` (schema validation example)
- Provides useful documentation of the entry structure, field types, and constraints
- Not actively used by any runtime code (no bash/lua references)

### 2. References to index.md (Active .claude/ Files)

Categorized by reference type:

#### Category A: Active agent/skill context loading (MUST update)
These files load index.md as context and need to be updated to either remove the reference or point to index.json:

| File | Reference Type |
|------|---------------|
| `.claude/agents/general-implementation-agent.md` (line 53) | `@.claude/context/index.md` in Load for Meta Tasks |
| `.claude/agents/meta-builder-agent.md` (lines 70, 98, 130) | analyze mode context loading |
| `.claude/skills/skill-orchestrator/SKILL.md` (line 17) | Context Loading section |
| `.claude/skills/skill-git-workflow/SKILL.md` (line 16) | Context Loading section |

#### Category B: Documentation/template config snippets (SHOULD update)
These files contain YAML-like config examples or documentation references:

| File | Reference Count | Pattern |
|------|----------------|---------|
| `.claude/docs/guides/context-loading-best-practices.md` | 18 occurrences | `index: ".claude/context/index.md"` in YAML examples |
| `.claude/context/core/schemas/subagent-frontmatter.yaml` | 1 | `index: ".claude/context/index.md"` |
| `.claude/context/core/templates/agent-template.md` | 4 | `index: ".claude/context/index.md"` in templates |
| `.claude/context/core/formats/frontmatter.md` | 5 | `index: ".claude/context/index.md"` in examples |
| `.claude/context/core/standards/xml-structure.md` | 3 | `index: ".claude/context/index.md"` in examples |

#### Category C: Process/workflow documentation (SHOULD update)
These files mention index.md in workflow descriptions:

| File | Reference Count |
|------|----------------|
| `.claude/context/project/processes/planning-workflow.md` | 1 |
| `.claude/context/project/processes/research-workflow.md` | 1 |
| `.claude/context/project/processes/implementation-workflow.md` | 1 |
| `.claude/context/core/orchestration/routing.md` | 1 |
| `.claude/context/project/meta/architecture-principles.md` | 2 |

#### Category D: Guide/template documentation (SHOULD update)
| File | Reference Count |
|------|----------------|
| `.claude/docs/guides/adding-domains.md` | 1 |
| `.claude/docs/guides/development/context-index-migration.md` | 8 (migration guide -- keep but update) |
| `.claude/docs/templates/agent-template.md` | 2 |
| `.claude/docs/templates/README.md` | 2 |

### 3. References to index.schema.json (Active Files)

Only 3 external references:
1. `index.json` line 2: `"$schema": "./index.schema.json"` -- standard JSON Schema pointer
2. `context-index-migration.md` line 240: validation example command
3. `context-discovery.md` line 210: validation example command

### 4. .opencode Mirror Impact

The `.opencode/` directory contains a parallel mirror with 17 files referencing index.md. This mirror should also be updated for consistency, but may be considered a separate concern depending on its maintenance model.

### 5. Archive References

Multiple files in `specs/archive/` reference index.md. These are historical records and should NOT be modified.

### Recommendations

#### index.md: REMOVE
- Delete `.claude/context/index.md`
- The deprecation period (since 2026-02-24) has been observed
- All content is superseded by index.json
- Update all 18 active files in `.claude/` to remove or redirect references

#### index.schema.json: KEEP IN PLACE
- Provides valuable structural documentation of the index.json format
- Standard JSON Schema practice to co-locate schema with data file
- The `$schema` pointer in index.json is idiomatic and useful for IDE validation
- Only 3 external references, all appropriate (validation examples)
- Moving it would break the relative `$schema` reference in index.json
- No runtime overhead -- purely declarative

#### context-index-migration.md: UPDATE (do not remove)
- This migration guide documents the transition and remains useful reference
- Update to reflect that migration is now complete (index.md removed)
- Change language from "being deprecated" to "has been removed"

#### Reference Migration Strategy

For most references, the update is one of:
1. **Agent/skill context loading**: Remove `@.claude/context/index.md` line entirely (agents already use index.json via jq queries documented in their Dynamic Context Discovery sections)
2. **YAML config `index:` field**: Change `".claude/context/index.md"` to `".claude/context/index.json"`
3. **Documentation text references**: Update to mention index.json
4. **meta-builder-agent analyze mode**: Replace index.md reference with index.json

## Decisions

- index.schema.json is NOT an active runtime component but IS a useful documentation artifact -- keep in place
- .opencode/ mirror updates should be included in scope for completeness
- Archive files should never be modified
- The migration guide should be preserved and updated to reflect completion

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Missed reference causes agent to fail | Low | Comprehensive grep search performed; no runtime (bash/lua) references found |
| .opencode mirror inconsistency | Medium | Include .opencode updates in implementation plan |
| Future contributors reference old index.md | Low | Migration guide documents the change; index.json is well-established |

## Implementation Complexity

- **File to delete**: 1 (index.md)
- **Files to update in .claude/**: 18
- **Files to update in .opencode/**: 17
- **Files NOT to touch**: archives, index.schema.json
- **Estimated effort**: 1-2 hours (mostly find-and-replace with targeted edits)

## Appendix

### Search Queries Used

```bash
# Find all references to index.md
grep -rl "index\.md" .claude/ --include="*.md" --include="*.yaml" --include="*.json"

# Find all references to index.schema.json
grep -rl "index\.schema\.json" .claude/ --include="*.md" --include="*.yaml" --include="*.json" --include="*.sh"

# Find references in scripts (runtime code)
grep -rl "index\.md" .claude/ --include="*.sh"

# Count references in context-loading-best-practices
grep -c "index\.md" .claude/docs/guides/context-loading-best-practices.md
```

### Files with index.md References (Complete Active List)

```
.claude/agents/general-implementation-agent.md
.claude/agents/meta-builder-agent.md
.claude/context/core/formats/frontmatter.md
.claude/context/core/orchestration/routing.md
.claude/context/core/schemas/subagent-frontmatter.yaml
.claude/context/core/standards/xml-structure.md
.claude/context/core/templates/agent-template.md
.claude/context/project/meta/architecture-principles.md
.claude/context/project/processes/implementation-workflow.md
.claude/context/project/processes/planning-workflow.md
.claude/context/project/processes/research-workflow.md
.claude/docs/guides/adding-domains.md
.claude/docs/guides/context-loading-best-practices.md
.claude/docs/guides/development/context-index-migration.md
.claude/docs/templates/agent-template.md
.claude/docs/templates/README.md
.claude/skills/skill-git-workflow/SKILL.md
.claude/skills/skill-orchestrator/SKILL.md
```
