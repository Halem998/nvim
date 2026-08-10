# Task 539: Uniform Extension Routing — One Source of Truth

**Status**: `[NOT STARTED]`
**Effort**: 3-4 hours
**Task Type**: meta
**Dependencies**: 538 (automated routing validation exists)

## Problem Statement

The extension routing system has fragmented sources of truth: some extension manifests declare `routing` sections, others have skills but no routing, and command documents duplicate routing information in hardcoded tables. This creates:

1. **Silent fallback failures**: Extensions with skills but no routing (latex, formal, filetypes, epidemiology, z3, web, python) silently fall back to generic agents when `/research`, `/plan`, or `/implement` are invoked.
2. **Manifest-command drift**: Command docs contain hardcoded "Extension-Based Routing Tables" that must be manually kept in sync with manifests. Task 538's validation script found 48 discrepancies.
3. **Overcomplicated fallback chains**: Commands have bash manifest-discovery code PLUS hardcoded tables PLUS fallback comments, when manifest discovery alone should suffice.
4. **Anti-Bypass rot**: Anti-Bypass constraint sections in command docs list specific skill names by hand. When new extensions are added, these lists become incomplete and misleading.

## Guiding Principle

> **One source of truth: `manifest.json`. Zero hardcoding. Consistent behavior.**

## Scope

### In Scope

1. **Audit all manifests** (`.opencode/extensions/*/manifest.json`):
   - Add `routing` section to every extension that provides skills
   - Remove `routing` section from any extension that does not need it
   - Ensure `routing` keys match the extension's `language` field and any compound task types it supports

2. **Simplify command docs** (`.opencode/commands/implement.md`, `research.md`, `plan.md`):
   - Remove hardcoded "Extension-Based Routing Table" markdown tables
   - Keep manifest-discovery bash logic (this is the correct mechanism)
   - Update Anti-Bypass constraints to reference manifest-based discovery instead of listing skills by name
   - Remove fallback comments/warnings that suggest hardcoded behavior

3. **Update validation script** (`.opencode/scripts/validate-routing-tables.sh`):
   - Retarget validation: ensure every skill in `provides.skills` has a corresponding `routing` entry
   - Validate that command docs do NOT contain hardcoded routing tables (grep for old patterns)
   - Ensure no orphaned routing entries exist (routing entries pointing to non-existent skills)

4. **Consider auto-generation**:
   - Document whether command docs should derive their routing knowledge from manifests at load time
   - If feasible, create a `.opencode/scripts/generate-routing-docs.sh` that injects manifest-derived routing summaries into command docs (or decide against it to keep docs static)

### Out of Scope

- Changing the skill implementations themselves
- Adding new skills or agents
- Modifying the extension loader (Task 533 already fixed manifest copying)
- Modifying core extension (`routing_exempt: true` is correct)
- Modifying task state management or the orchestrator core

## Extension Audit

### Manifests Missing Routing (have skills, no routing)

| Extension | Skills | Missing Routing For |
|-----------|--------|---------------------|
| `latex` | skill-latex-research, skill-latex-implementation | research, implement |
| `formal` | skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research | research |
| `filetypes` | skill-filetypes, skill-spreadsheet, skill-presentation, skill-deck | implement (commands: convert, table, slides, deck) |
| `epidemiology` | skill-epidemiology-research, skill-epidemiology-implementation | research, implement |
| `nix` | skill-nix-research, skill-nix-implementation | research, implement |
| `z3` | skill-z3-research, skill-z3-implementation | research, implement |
| `web` | skill-web-research, skill-web-implementation, skill-tag | research, implement |
| `python` | skill-python-research, skill-python-implementation | research, implement |

### Manifests With Routing (correct)

| Extension | Routing Coverage |
|-----------|------------------|
| `lean` | research (lean, lean4), implement (lean, lean4) |
| `nvim` | research (neovim), implement (neovim) |
| `typst` | research (typst), implement (typst) |
| `founder` | research, plan, implement (many compound keys) |
| `present` | research, plan, implement, critique (compound keys) |

### Manifests Without Skills (no routing needed)

| Extension | Note |
|-----------|------|
| `slidev` | Dependency-only extension, provides context only |
| `memory` | Utility extension, skill-memory is invoked by `/learn` command directly |
| `core` | `routing_exempt: true` — base agents and skills |

## Implementation Plan

### Phase 1: Add Missing Routing to Manifests

For each extension in the "Missing Routing" table above:

1. Add `routing` object with `research`, `plan` (if applicable), and `implement` keys
2. Map the extension's `language` field to the appropriate skill
3. For compound task types (e.g., `founder:deck`), follow the existing pattern in `founder` and `present` manifests

Example for `latex`:
```json
"routing": {
  "research": {
    "latex": "skill-latex-research"
  },
  "implement": {
    "latex": "skill-latex-implementation"
  }
}
```

### Phase 2: Remove Hardcoded Tables from Command Docs

In `.opencode/commands/implement.md`, `.opencode/commands/research.md`, `.opencode/commands/plan.md`:

1. **Remove** the "Extension-Based Routing Table" markdown table sections entirely
2. **Keep** the manifest-discovery bash scripts (these are correct)
3. **Update** Anti-Bypass constraints to say:
   > "All summary/report/plan files MUST be created by invoking the appropriate skill via the Skill tool. The correct skill is determined by manifest discovery in `.opencode/extensions/*/manifest.json`."
   Instead of listing skill names.
4. **Remove** fallback comments like `Using fallback routing` and `Fallback to default...` — these imply hardcoded fallbacks exist. Instead, keep the default skill assignment (`skill_name=${skill_name:-"skill-implementer"}`) as the clean default when no manifest matches.

### Phase 3: Update Validation Script

In `.opencode/scripts/validate-routing-tables.sh`:

1. **New check**: Every skill in `provides.skills` across all manifests must have at least one routing entry (unless the extension has `routing_exempt: true` or is a utility extension like `memory`)
2. **New check**: Every routing entry must point to a skill that exists in the same manifest's `provides.skills`
3. **New check**: Command docs must not contain hardcoded routing tables (grep for "`|`" table patterns in routing sections)
4. **Remove** the old "manifest vs command doc" comparison logic

### Phase 4: Test and Verify

1. Run the updated validation script
2. Verify each modified manifest is valid JSON
3. Verify command docs still route correctly (manifest discovery logic is unchanged)
4. Update any tests or documentation that reference the old hardcoded tables

## Key Files to Modify

### Manifests (8 files)
- `.opencode/extensions/latex/manifest.json`
- `.opencode/extensions/formal/manifest.json`
- `.opencode/extensions/filetypes/manifest.json`
- `.opencode/extensions/epidemiology/manifest.json`
- `.opencode/extensions/nix/manifest.json`
- `.opencode/extensions/z3/manifest.json`
- `.opencode/extensions/web/manifest.json`
- `.opencode/extensions/python/manifest.json`

### Command Docs (3 files)
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

### Scripts (1 file)
- `.opencode/scripts/validate-routing-tables.sh`

## Success Criteria

- [ ] All extensions with skills have complete `routing` sections
- [ ] No hardcoded routing tables exist in command docs
- [ ] Anti-Bypass constraints reference manifest discovery, not hardcoded skill lists
- [ ] Validation script passes with zero errors
- [ ] Manifest discovery alone determines routing — no silent fallback to generic agents

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Adding routing to manifests that intentionally lacked it | Review each extension: if it has skills, it needs routing. `slidev` and `memory` correctly have no routing. |
| Breaking command docs by removing tables | The bash manifest-discovery code is the actual routing mechanism; markdown tables are documentation-only. Verify docs still reference manifest discovery. |
| Validation script false positives | Update the script's skip patterns for `routing_exempt`, utility extensions, and command-only extensions. |

## Related Tasks

- **Task 534**: Sync extension routing tables across command docs (COMPLETED — superseded by this task)
- **Task 537**: Fix manifest discovery to use absolute paths (COMPLETED)
- **Task 538**: Add automated routing table validation (COMPLETED — script will be updated)
- **Task 533**: Fix extension loader to copy manifest.json (COMPLETED)

## Decision: Auto-Generation of Routing Docs

**Question**: Should command docs contain routing information at all, or should they be generated from manifests?

**Recommendation**: Remove hardcoded tables. The bash manifest-discovery code in each command doc is the authoritative runtime mechanism. Adding a script to auto-generate a `.opencode/context/routing-index.md` reference file (updated by CI) is optional and can be a follow-up task. The priority is removing the duplicate/hardcoded source of truth.

---

*Created: 2026-05-07*
*Author: meta-builder-agent*
