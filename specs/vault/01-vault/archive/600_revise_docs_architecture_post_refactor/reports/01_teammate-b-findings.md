# Teammate B Findings: Alternative Approaches & Cross-Reference Analysis

**Task**: 600 - revise_docs_architecture_post_refactor
**Angle**: Redundancy analysis, reference mapping, documentation strategy alternatives
**Date**: 2026-05-22
**Confidence Level**: High

---

## Key Findings

### 1. Four New Architecture Docs Are Unlisted in docs-README.md

The refactor tasks (592-599) created 4 new architecture documents that exist in `.claude/docs/architecture/` but are NOT listed in `docs-README.md`'s documentation map:

- `architecture-spec.md` — Unified workflow architecture specification (0 external refs besides sibling docs)
- `dispatch-agent-spec.md` — dispatch_agent() function spec (referenced by skill-orchestrate)
- `handoff-schema.md` — Orchestrator handoff JSON schema (referenced by skill-orchestrate)
- `orchestrate-state-machine.md` — /orchestrate state machine (referenced by skill-orchestrate, skill-implementer)

These 4 docs also do NOT exist in `.claude/extensions/core/docs/` — they were added to `.claude/docs/` directly but not synced to the extension source. This creates a sync gap.

### 2. docs/ vs context/ System Overview Is Diverged

Two `system-overview.md` files exist with different purposes and freshness:

| File | Lines | Last Updated | Contains Refactor? |
|------|-------|-------------|-------------------|
| `docs/architecture/system-overview.md` | 336 | 2026-05-22 | YES (updated by task 599) |
| `context/architecture/system-overview.md` | 498 | 2026-01-19 | Minimal (2 mentions) |

The **docs/** version was updated during the refactor and is current. The **context/** version is 4 months stale — it's the version loaded by agents via index.json but describes the pre-refactor architecture. This is the most critical finding: agents building new components will read the stale context/ version.

### 3. Three Direct File-Name Overlaps Between docs/ and context/

| File | docs/ version | context/ version | Status |
|------|---------------|-------------------|--------|
| `system-overview.md` | 336 lines, post-refactor | 498 lines, pre-refactor | **DIVERGED** — context/ is stale |
| `agent-template.md` | User tutorial template | Agent-facing reference with header | **DIFFERENT PURPOSE** — intentional split |
| `command-template.md` | User tutorial template | Agent-facing reference with header | **DIFFERENT PURPOSE** — intentional split |

The template overlap is intentional: context/ templates add header metadata and model defaults for agent consumption, while docs/ templates are user-facing tutorials. These should remain separate but cross-reference each other.

### 4. Five docs/ Files Are Out of Sync with extensions/core/docs/

Files that DIFFER between `.claude/docs/` and `.claude/extensions/core/docs/`:

1. `docs/architecture/system-overview.md` — Updated by task 599, core extension copy is stale
2. `docs/guides/creating-extensions.md` — Updated by task 599 (lifecycle hooks), core copy stale
3. `docs/guides/creating-skills.md` — Updated with skill-base.sh content, core copy stale
4. `docs/reference/standards/multi-task-creation-standard.md` — Differs from core copy
5. `docs/reference/standards/agent-frontmatter-standard.md` — Differs from core copy

This means running "Load Core" sync will OVERWRITE the updated docs/ versions with stale core copies unless the core extension is updated first.

### 5. docs-README.md Also Missing reference/ and templates/ from Map

The documentation map in `docs-README.md` omits several file categories:

**Unlisted files**:
- `reference/standards/agent-frontmatter-standard.md` (7 refs — heavily referenced)
- `reference/standards/extension-slim-standard.md` (1 ref)
- `reference/standards/multi-task-creation-standard.md` (11 refs — most referenced doc)
- `templates/agent-template.md` (4 refs)
- `templates/command-template.md` (2 refs)
- `guides/development/context-index-migration.md` (1 ref)

### 6. Two README Files Create Confusion

- `.claude/docs/README.md` — Full navigation hub for .claude/ system (259 lines)
- `.claude/docs/docs-README.md` — Documentation-specific map (95 lines)

The README.md actually serves as the `.claude/README.md` system hub (it references root-level CLAUDE.md, context/, extensions/). The docs-README.md is the actual docs/ index. This naming is confusing — `docs-README.md` should probably be `README.md` and the current `README.md` should live at `.claude/README.md`.

### 7. context/templates/ Has 5 Files Not in docs/templates/

context/ has `delegation-context.md`, `orchestrator-template.md`, `state-template.json`, `subagent-template.md`, `thin-wrapper-skill.md` — none in docs/templates/. These are agent-facing templates not needed by users, so this gap is intentional. But the docs/templates/README.md should acknowledge this split.

---

## Recommended Approach

### Strategy: Update-in-Place with Sync-First

Rather than removing or deprecating docs, **update them in place** and then sync to `extensions/core/docs/`. Rationale:

1. **All docs/ files have at least 1 reference** — none are truly orphaned
2. **The extension sync model requires core/ to be authoritative** — if docs/ is updated but core/ isn't synced, the next "Load Core" will regress
3. **The docs/ → context/ divergence is the real problem** — not redundancy

### Recommended Execution Order

**Phase 1: Sync the source of truth**
1. Copy updated `.claude/docs/` files back to `.claude/extensions/core/docs/` (5 differing files)
2. Copy the 4 new architecture docs to `extensions/core/docs/architecture/`

**Phase 2: Update docs-README.md**
1. Add the 4 new architecture docs to the documentation map
2. Add the reference/ and templates/ sections to the map
3. Consider renaming: `docs-README.md` → keep as `README.md` within docs/ (it IS the docs index)

**Phase 3: Update context/architecture/system-overview.md**
1. This is the CRITICAL update — replace the 2026-01-19 content with post-refactor architecture
2. Keep the agent-facing framing (Purpose/Audience metadata) but update the substance
3. Consider whether context/ should reference docs/ instead of duplicating

**Phase 4: Update guides/**
1. `creating-commands.md` — Add gate scripts pattern, parse-command-args.sh reference
2. `creating-skills.md` — Already updated with skill-base.sh (just needs core sync)
3. `creating-agents.md` — Minimal changes needed (agent interface hasn't changed much)

**Phase 5: Update .claude/README.md**
1. Update the Documentation Hub section to reference new architecture docs
2. Update the architecture diagram if needed (already shows 3-layer)

### Alternative: Consolidate docs/ into context/

**NOT recommended** because:
- docs/ serves user-facing documentation (guides, examples, tutorials)
- context/ serves agent-facing reference (loaded via index.json for agent context injection)
- These have different audiences and different loading mechanisms
- Merging would bloat agent context budgets with tutorial content

### Alternative: Deprecation Notices

**NOT recommended** because:
- No docs describe patterns that "no longer exist" — the refactor evolved patterns, didn't remove them
- Deprecation notices add noise and create maintenance burden
- Better to update in-place since all docs are still relevant

---

## Evidence/Examples

### Critical Stale File: context/architecture/system-overview.md

```
Created: 2026-01-19
Last Verified: 2026-01-19
```

This file is loaded by meta-builder-agent and planner-agent when generating new components. It describes the pre-refactor architecture without skill-base.sh, dispatch-agent.sh, or /orchestrate. Any agent reading this will generate outdated components.

### Sync Gap Example

```
# Files in .claude/docs/architecture/ but NOT in extensions/core/docs/architecture/
architecture-spec.md        # Created by task 592
dispatch-agent-spec.md      # Created by task 596
handoff-schema.md           # Created by task 595
orchestrate-state-machine.md # Created by task 596
```

These files exist in the installed location but not in the extension source, making the core extension an incomplete backup.

### Reference Count Distribution

Most-referenced docs (excluding self-references and core extension copies):
- `multi-task-creation-standard.md` — 11 references
- `agent-frontmatter-standard.md` — 7 references
- `creating-agents.md` — 7 references
- `creating-skills.md` — 6 references
- `creating-commands.md` — 5 references
- `extension-system.md` — 5 references
- `component-selection.md` — 5 references

Zero-reference docs:
- `architecture-spec.md` — 0 external refs (only referenced by its sibling architecture docs)

---

## Confidence Level: High

This analysis is based on concrete file comparisons, grep-based reference counting, and diff analysis. The findings about sync gaps and stale context/ files are verifiable facts, not estimates. The main uncertainty is around the recommended execution order — Phase 3 (context/ update) could arguably come first since it's the most impactful for agent quality.
