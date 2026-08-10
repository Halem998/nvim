# Task 396 Phase 1 Decisions

**Date**: 2026-04-10
**Session**: sess_1775849000_d6e8f4

## User Decisions

### (a) Lean extension scripts
**Decision**: Remove orphaned entries from `lean/manifest.json`. The manifest references script files that were never created on disk. Documentation-only fix; no script creation.

### (b) Formal extension research-only pattern
**Decision**: Treat as bug — add implement routing to the formal extension. Note: this expands scope beyond pure documentation audit; implementer agent must wire up appropriate implement skill/agent, not just document the current state.

### (c) Duplicate documentation standards files
**Decision**: **Combine both** files into a single canonical file named `documentation-standards.md` (keeping the more descriptive name). Merge structure:
- Base: `documentation-standards.md` (cleaner, current, no stale `.opencode` refs)
- Fold in from `documentation.md`: Formatting Standards section (line length, headings, code blocks, file trees, lists), README structure template, validation scripts, quality checklist
- Drop from `documentation.md`: all `.opencode` references, LEAN 4 formal symbol section (move to `.claude/extensions/lean/` context if preserved at all), duplicate emoji/version-history sections
- After merge: delete `documentation.md`, grep `.claude/` for `@.claude/context/standards/documentation.md` references and repoint to `documentation-standards.md`

### (d) Stale templates (agent-template.md, command-template.md, subagent-template.md, creating-commands.md)
**Decision**: Rewrite to current format. Preserves the template pattern for future authors. Templates must match current agent frontmatter standard, skill-internal postflight pattern, and checkpoint-based command structure.

### (e) Co-Authored-By convention update
**Decision**: Remove `Co-Authored-By` trailer from the commit convention example block in `.claude/CLAUDE.md`. Honors user memory preference (see `~/.claude/projects/-home-benjamin--config-nvim/memory/feedback_no_coauthored_by.md`).

### (f) Scope tier endorsement
**Decision**: **Full Tier 1 + 2 + 3** (~11 hours). Execute all 10 phases of the plan:
- Tier 1 (Phases 1-5): filetypes/README.md, core-doc drift fixes, code-reviewer frontmatter, stale template resolution
- Tier 2 (Phases 6-7): READMEs for 5 complex extensions (lean, formal, nvim, nix, web)
- Tier 3 (Phases 8-10): Simple-extension READMEs, doc-lint script, ROADMAP.md population

## Baseline Inventory

### Extension README status (14 extensions)

**Has README.md (3)**: founder, memory, present

**Missing README.md (11)**: epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3

### Blast-radius grep results

**`documentation.md` references** (references to `context/standards/documentation.md` that will repoint to `documentation-standards.md`):
- `.claude/commands/review.md:840` — `.claude/docs/registries/documentation.md` (different file; skip)
- `.claude/context/processes/research-workflow.md:190,509` — "per documentation.md standards"
- `.claude/context/meta/context-revision-guide.md:90` — example list
- `.claude/context/core-index-entries.json:1004` — index entry
- `.claude/context/index.json:1716` — index entry
- `.claude/context/standards/documentation.md:66,310` — self-references

**`documentation-standards.md` references** (to preserve/update):
- `.claude/context/standards/documentation-standards.md:12,239` — self-references
- `.claude/context/core-index-entries.json:1018` — index entry
- `.claude/context/index.json:1740` — index entry

**`subagent-return-format.md` references** (rename to `subagent-return.md`):
- `.claude/docs/templates/command-template.md:47`
- `.claude/context/schemas/subagent-frontmatter.yaml:183`
- `.claude/context/templates/agent-template.md` (5 occurrences: lines 46, 114, 179, 222, 266, 307)
- `.claude/context/workflows/review-process.md:28`
- `.claude/docs/templates/agent-template.md:168, 206, 360`
- `.claude/context/workflows/command-lifecycle.md:31`
- `.claude/context/processes/{planning,research,implementation}-workflow.md:249,280,285`
- `.claude/context/formats/frontmatter.md:370, 424, 523, 571`
- `.claude/context/orchestration/delegation.md:808`
- `.claude/context/orchestration/routing.md:383`
- `.claude/context/orchestration/architecture.md:182`
- `.claude/context/formats/subagent-return.md:260` (self-reference inside actual file)
- `.claude/context/orchestration/orchestrator.md:683, 783`
- `.claude/context/meta/standards-checklist.md:86, 301`
- `.claude/context/standards/xml-structure.md:234, 659`
- `.claude/docs/templates/README.md:111, 203, 313, 323`

**`creating-commands.md` references** (guide to be rewritten):
- `.claude/README.md:192`
- `.claude/skills/skill-meta/SKILL.md:7`
- `.claude/context/architecture/system-overview.md:87`
- `.claude/context/architecture/component-checklist.md:360`
- `.claude/docs/examples/fix-it-flow-example.md:642`
- `.claude/docs/architecture/system-overview.md:275`
- `.claude/docs/guides/creating-skills.md:529`
- `.claude/docs/guides/creating-agents.md:685`
- `.claude/docs/guides/component-selection.md:400`
- `.claude/docs/README.md:21, 59`
- `.claude/agents/meta-builder-agent.md:75, 94, 231`

**`agent-template.md` / `command-template.md` / `subagent-template.md` references** (stale templates to be rewritten):
- See grep output above — ~15 references across architecture/context/docs files. Since decision (d) is to **rewrite** (not delete), no reference changes needed — references remain valid but point to updated content.

### Blast-radius conclusions

- The `documentation.md` -> `documentation-standards.md` consolidation affects ~6 files (including index entries).
- The `subagent-return-format.md` -> `subagent-return.md` rename is already reflected in the actual file (it exists as `subagent-return.md`) but many references still use the old path. These must be repointed in Phase 2 & 5.
- The `creating-commands.md` guide has ~12 referrers. Rewriting (not deleting) preserves all links.
- Stale templates have ~15 referrers. Rewriting preserves all links.

