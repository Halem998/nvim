# Plan: Sync Extension Routing Tables (Task 534)

**Date**: 2026-05-07
**Status**: planned
**Type**: meta
**Source**: Research Report `specs/534_sync_extension_routing_tables/reports/01_routing-tables-research.md`

## Summary

The Extension-Based Routing Tables in the `/implement`, `/research`, and `/plan` command documentation are out of sync with the actual extension manifests. This plan defines the phased work to audit, correct, remove orphaned entries, and validate consistency across all three tables.

---

## Phase 1: Audit Current Tables Across All 3 Command Docs

**Goal**: Produce a validated inventory of every entry in each command's Extension-Based Routing Table, cross-checked against extension manifests.

**Files to inspect**:
- `.opencode/commands/implement.md` (lines 405-413)
- `.opencode/commands/research.md` (lines 370-379)
- `.opencode/commands/plan.md` (lines 374-381)

**Steps**:
1. Read each command doc's Extension-Based Routing Table.
2. For each listed task type, confirm the corresponding skill exists in the relevant extension manifest under `.opencode/extensions/*/manifest.json` (`routing.implement`, `routing.research`, or `routing.plan`).
3. Record any discrepancies (missing manifest entries vs. orphaned table entries).
4. Produce an audit checklist artifact (can be inline in implementation notes).

**Expected outcome**: A verified inventory confirming exactly which entries are valid, missing, or orphaned.

---

## Phase 2: Add Missing Task Types to `/implement` Table

**Goal**: Update the Extension-Based Routing Table in `.opencode/commands/implement.md` to include all task types that have manifest routing entries for `routing.implement`.

**Current table** (lines 407-413):

```markdown
| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-implement` (from founder extension) |
| `founder:deck` | `skill-deck-implement` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-implement` |
| `general`, `meta`, `markdown` | `skill-implementer` (default) |
| `formal`, `logic`, `math`, `physics` | `skill-implementer` (default) |
```

**Changes required**:

1. **Remove orphaned entries**: Remove `formal`, `logic`, `math`, `physics` from the table. These have no manifest routing; they correctly fall through to the default skill, so listing them implies explicit extension routing that does not exist.
2. **Add missing `founder` subtypes**: Add all `founder` subtypes that route to `skill-founder-implement` (or specific sub-skills) so the table matches the manifest exactly:
   - `founder:market` -> `skill-founder-implement`
   - `founder:analyze` -> `skill-founder-implement`
   - `founder:strategy` -> `skill-founder-implement`
   - `founder:legal` -> `skill-founder-implement`
   - `founder:project` -> `skill-founder-implement`
   - `founder:sheet` -> `skill-founder-implement`
   - `founder:finance` -> `skill-founder-implement`
   - `founder:financial-analysis` -> `skill-founder-implement`
   - `founder:meeting` -> `skill-founder-implement`
   - `founder:consult` -> `skill-founder-implement`
3. **Add `present` extension entries**:
   - `present` -> `skill-grant`
   - `present:grant` -> `skill-grant:assemble`
   - `present:budget` -> `skill-budget`
   - `present:timeline` -> `skill-timeline`
   - `present:funds` -> `skill-funds`
   - `present:slides` -> `skill-slides:assemble`
4. **Add `typst` extension entry**:
   - `typst` -> `skill-typst-implementation`
5. **Add `nvim` extension entry**:
   - `neovim` -> `skill-neovim-implementation`
6. **Add `lean` extension entries**:
   - `lean` -> `skill-lean-implementation`
   - `lean4` -> `skill-lean-implementation`
7. **Retain default fallback**: Keep `general`, `meta`, `markdown` routing to `skill-implementer`.

**Implementation approach**: Replace the existing table block (lines 405-413) with an expanded, alphabetically/grouped table that includes all the above entries. Retain the `founder:{sub-type}` compound-key fallback line for readability.

---

## Phase 3: Add Missing Task Types to `/research` Table

**Goal**: Update the Extension-Based Routing Table in `.opencode/commands/research.md` to include all task types that have manifest routing entries for `routing.research`.

**Current table** (lines 372-379):

```markdown
| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-market` (from founder extension) |
| `founder:deck` | `skill-deck-research` (from founder extension) |
| `founder:analyze` | `skill-analyze` (from founder extension) |
| `founder:strategy` | `skill-strategy` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-market` |
| `general`, `meta`, `markdown` | `skill-researcher` (default) |
```

**Changes required**:

1. **Remove orphaned entry**: Remove `markdown` from the default row. No manifest routes `markdown`; it should fall through to `skill-researcher` implicitly without being listed as an explicitly routed type.
2. **Add missing `founder` subtypes**:
   - `founder:market` -> `skill-market`
   - `founder:legal` -> `skill-legal`
   - `founder:project` -> `skill-project`
   - `founder:sheet` -> `skill-founder-spreadsheet`
   - `founder:finance` -> `skill-finance`
   - `founder:financial-analysis` -> `skill-financial-analysis`
   - `founder:meeting` -> `skill-meeting`
   - `founder:consult` -> `skill-consult`
3. **Add `present` extension entries**:
   - `present` -> `skill-grant`
   - `present:grant` -> `skill-grant`
   - `present:budget` -> `skill-budget`
   - `present:timeline` -> `skill-timeline`
   - `present:funds` -> `skill-funds`
   - `present:slides` -> `skill-slides`
4. **Add `typst` extension entry**:
   - `typst` -> `skill-typst-research`
5. **Add `nvim` extension entry**:
   - `neovim` -> `skill-neovim-research`
6. **Add `lean` extension entries**:
   - `lean` -> `skill-lean-research`
   - `lean4` -> `skill-lean-research`
7. **Retain default fallback**: Keep `general`, `meta` routing to `skill-researcher`.

**Implementation approach**: Replace the existing table block (lines 370-379) with an expanded table. Remove `markdown` from the explicit default row.

---

## Phase 4: Add Missing Task Types to `/plan` Table

**Goal**: Update the Extension-Based Routing Table in `.opencode/commands/plan.md` to include all task types that have manifest routing entries for `routing.plan`.

**Current table** (lines 374-381):

```markdown
| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-founder-plan` (from founder extension) |
| `founder:deck` | `skill-deck-plan` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-plan` |
| Other | `skill-planner` (default) |
```

**Changes required**:

1. **Add missing `founder` subtypes**:
   - `founder:market` -> `skill-founder-plan`
   - `founder:analyze` -> `skill-founder-plan`
   - `founder:strategy` -> `skill-founder-plan`
   - `founder:legal` -> `skill-founder-plan`
   - `founder:project` -> `skill-founder-plan`
   - `founder:sheet` -> `skill-founder-plan`
   - `founder:finance` -> `skill-founder-plan`
   - `founder:financial-analysis` -> `skill-founder-plan`
   - `founder:meeting` -> `skill-founder-plan`
   - `founder:consult` -> `skill-founder-plan`
2. **Add `present` extension entries**:
   - `present` -> `skill-planner`
   - `present:grant` -> `skill-planner`
   - `present:budget` -> `skill-planner`
   - `present:timeline` -> `skill-planner`
   - `present:funds` -> `skill-planner`
   - `present:slides` -> `skill-slide-planning`
   - `slides` -> `skill-slide-planning`
3. **Retain default fallback**: Keep `general`, `meta`, `markdown` and any other unrouted types falling through to `skill-planner`.

**Implementation approach**: Replace the existing table block (lines 374-381) with an expanded table. Retain the `founder:{sub-type}` compound-key fallback line and the `Other` default fallback line.

---

## Phase 5: Update Anti-Bypass Constraint to Reference All Applicable Skills

**Goal**: Ensure each command's Anti-Bypass Constraint explicitly names all skills that can legitimately create the artifact for that command.

**Files to update**:
- `.opencode/commands/implement.md` (lines 40-46)
- `.opencode/commands/research.md` (lines 46-52)
- `.opencode/commands/plan.md` (lines 42-48)

**Current text**:
- `/implement`: "skill-implementer or skill-team-implement"
- `/research`: "skill-researcher or skill-team-research"
- `/plan`: "skill-planner or skill-team-plan"

**Changes required**:

1. **`/implement` Anti-Bypass Constraint**:
   - Update the Required line to reference that extension-routed skills are also permitted.
   - New text: `All summary files MUST be created by invoking the appropriate skill (skill-implementer, skill-team-implement, or any extension-specific implementation skill such as skill-founder-implement, skill-neovim-implementation, etc.) via the Skill tool.`
   - Also update the first sentence of the PROHIBITION to mention the broader skill set.

2. **`/research` Anti-Bypass Constraint**:
   - Similarly, expand the named skills to include extension-specific research skills.
   - New text: `All report files MUST be created by invoking the appropriate skill (skill-researcher, skill-team-research, or any extension-specific research skill such as skill-market, skill-neovim-research, etc.) via the Skill tool.`

3. **`/plan` Anti-Bypass Constraint**:
   - Expand the named skills to include extension-specific plan skills.
   - New text: `All plan files MUST be created by invoking the appropriate skill (skill-planner, skill-team-plan, or any extension-specific plan skill such as skill-founder-plan, skill-slide-planning, etc.) via the Skill tool.`

**Implementation approach**: Edit each file's Anti-Bypass Constraint section to replace the narrow skill list with the inclusive pattern. Keep the WHY and Required sections intact; only update the skill enumeration.

---

## Phase 6: Validate Consistency Across All Three Tables

**Goal**: Run a final validation pass to ensure the three updated tables are internally consistent with each other and with the extension manifests.

**Validation checklist**:
1. **Manifest parity**: Every task type listed in any table must exist in the corresponding extension manifest's routing section.
2. **Cross-command parity**: For each extension that provides routing for multiple commands (e.g., `founder`, `present`, `lean`, `nvim`, `typst`), the task types listed in `/implement`, `/research`, and `/plan` must be consistent (same task type names, matching skill naming conventions).
3. **No orphaned entries**: No table row references a task type that does not have a manifest routing entry.
4. **Default fallback consistency**: Each table must clearly indicate the default fallback skill for unrouted task types.
5. **Anti-Bypass consistency**: The Anti-Bypass Constraint in each file must reference skills that are actually listed in that file's routing table.

**Validation script (optional but recommended)**:
Write a small bash script (or manual verification steps) that:
- Parses `.opencode/extensions/*/manifest.json` for `routing.implement`, `routing.research`, `routing.plan`.
- Compares the set of keys against the tables in the three command docs.
- Reports any mismatches.

**Expected outcome**: All discrepancies resolved; validation script passes (or manual checklist passes); a brief validation report is appended to the task notes.

---

## Out-of-Scope (Deferred)

The following items are identified but intentionally deferred to future tasks:

- **Adding routing sections to extensions without them**: The 8 extensions listed in the research report (`z3`, `web`, `python`, `nix`, `latex`, `formal`, `filetypes`, `epidemiology`) have skills but no routing. Adding routing to their manifests is a separate extension-level task.
- **Updating `.claude/context/routing.md`**: The Claude-side routing context also has language-to-skill mappings. That file is separate from the OpenCode command docs and should be synced in a separate task if needed.
- **Adding team-mode extension skills**: If any extension provides team-mode skills (e.g., `skill-team-lean-implement`), those would be added when they exist.

---

## Dependencies

- Research report: `specs/534_sync_extension_routing_tables/reports/01_routing-tables-research.md`
- Extension manifests: `.opencode/extensions/*/manifest.json`
- Command docs: `.opencode/commands/implement.md`, `.opencode/commands/research.md`, `.opencode/commands/plan.md`

## Estimated Effort

- Phase 1: ~15 minutes (audit)
- Phase 2: ~20 minutes (implement table)
- Phase 3: ~20 minutes (research table)
- Phase 4: ~20 minutes (plan table)
- Phase 5: ~15 minutes (anti-bypass updates)
- Phase 6: ~20 minutes (validation + report)

**Total**: ~1.5 hours

## Success Criteria

- [ ] All three command docs have updated Extension-Based Routing Tables with no orphaned entries.
- [ ] All manifest-routed task types appear in the appropriate table(s).
- [ ] Anti-Bypass Constraints reference all applicable skills (core + extension).
- [ ] Validation confirms zero mismatches between tables and manifests.
- [ ] Git commit produced with message: `task 534: sync extension routing tables`
