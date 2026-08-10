# Implementation Plan: Task #117

- **Task**: 117 - Study core .claude artifacts overlap with extensions and address recommendations
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Address residual overlaps and inconsistencies between core .claude/ artifacts and the extension system identified in the research report. The parent `.config/CLAUDE.md` contains stale references to removed extension skills (latex, typst, document-converter). The `adding-domains.md` guide instructs users to place domains directly in core, contradicting the extension system established in tasks 109-110. No dedicated extension system documentation exists. This plan creates 3 phases to clean up stale references, update the domain guide, and create extension documentation.

### Research Integration

Integrated findings from `reports/research-001.md` (2026-03-03). The research identified 5 recommendations; this plan addresses the 3 actionable ones (Recommendations 1, 2, 4). Recommendation 3 (move neovim to extension) is explicitly not implemented -- keeping neovim in core is the correct decision for a Neovim configuration repository. Recommendation 5 (no deduplication needed) requires no action.

## Goals & Non-Goals

**Goals**:
- Remove stale latex/typst/document-converter references from parent `.config/CLAUDE.md`
- Rewrite `adding-domains.md` to recommend extensions as the primary approach for new domains
- Create dedicated extension system documentation (architecture + guide)
- Update `.claude/docs/README.md` to reference new extension docs

**Non-Goals**:
- Moving neovim artifacts to an extension (Recommendation 3 -- explicitly rejected; this IS a neovim repo and the friction is not worth the portability gain)
- Creating an auto-loading mechanism for extensions (runtime limitation of Claude Code)
- Modifying the extension loader Lua code
- Deduplicating content between core and extensions (already clean after task 110)

## Risks & Mitigations

- Risk: Parent CLAUDE.md edits may break routing for users who depend on latex/typst entries. Mitigation: These entries reference skills that no longer exist in core; they only work when extensions are loaded, and the child CLAUDE.md already has the correct "Note" references. Low risk.
- Risk: Rewriting adding-domains.md may break existing bookmarks or cross-references. Mitigation: Keep the same file path, update only content. Check for inbound links.
- Risk: Extension system documentation may become stale as Lua code evolves. Mitigation: Document the architecture at the conceptual level, reference source files for implementation details.

## Implementation Phases

### Phase 1: Clean up parent .config/CLAUDE.md stale references [COMPLETED]

**Goal:** Remove stale latex/typst/document-converter references from the parent CLAUDE.md at `/home/benjamin/.config/.claude/CLAUDE.md`, aligning it with the child `.config/nvim/.claude/CLAUDE.md` which was properly updated in task 110.

**Tasks:**
- [ ] Edit Language-Based Routing table: remove `latex` and `typst` rows, add a "Note" line referencing extensions (matching the child CLAUDE.md pattern)
- [ ] Edit Skill-to-Agent Mapping table: remove `skill-latex-implementation`, `skill-typst-implementation`, `skill-document-converter` rows, add a "Note" line referencing extensions
- [ ] Verify no other stale extension references remain in the file
- [ ] Read the updated file to confirm changes are correct

**Timing:** 30 minutes

**Files to modify:**
- `/home/benjamin/.config/.claude/CLAUDE.md` - Remove stale extension references from routing and mapping tables

**Verification:**
- No references to `latex`, `typst`, or `document-converter` remain in routing/mapping tables
- "Note" lines match the pattern used in the child CLAUDE.md
- File parses correctly as valid markdown

---

### Phase 2: Rewrite adding-domains.md to recommend extensions [COMPLETED]

**Goal:** Update the domain addition guide to recommend the extension approach as the primary method for adding new domains, with the core approach reserved only for the repository's primary domain.

**Tasks:**
- [ ] Add a "Choosing Your Approach" section at the top that distinguishes between core domains (primary project domain) and extension domains (all others)
- [ ] Add a new "Extension Approach (Recommended)" section covering: manifest.json format, EXTENSION.md merge content, directory structure, index-entries.json format, and the load/unload mechanism
- [ ] Rename the existing steps to "Core Approach (Primary Domain Only)" and add a note that this is only for the repository's primary domain
- [ ] Update the architecture diagram to show extensions alongside core routing
- [ ] Update the verification checklist to include extension-specific checks
- [ ] Update navigation links if needed

**Timing:** 1 hour

**Files to modify:**
- `.claude/docs/guides/adding-domains.md` - Major rewrite to recommend extensions as primary approach

**Verification:**
- Guide clearly recommends extensions as the default approach
- Core approach is documented as a special case for the primary domain only
- Extension manifest format is documented with examples
- All internal links are valid

---

### Phase 3: Create extension system documentation [COMPLETED]

**Goal:** Create dedicated documentation for the extension system architecture and a guide for creating extensions, filling the documentation gap identified in the research.

**Tasks:**
- [ ] Create `.claude/docs/architecture/extension-system.md` covering: system overview, directory structure, manifest format, load/unload mechanism, conflict detection, CLAUDE.md section injection, index.json merging, settings merging, state tracking
- [ ] Create `.claude/docs/guides/creating-extensions.md` covering: step-by-step extension creation, manifest.json template, EXTENSION.md template, directory layout, index-entries.json format, testing the extension, loading/unloading via Neovim picker
- [ ] Update `.claude/docs/README.md` to add extension docs to the documentation map and guides sections
- [ ] Cross-reference the new docs from `adding-domains.md` (created in Phase 2)

**Timing:** 1-1.5 hours

**Files to create:**
- `.claude/docs/architecture/extension-system.md` - Architecture documentation
- `.claude/docs/guides/creating-extensions.md` - Extension creation guide

**Files to modify:**
- `.claude/docs/README.md` - Add references to new extension documentation
- `.claude/docs/guides/adding-domains.md` - Add cross-references to new extension docs

**Verification:**
- Architecture doc covers all major components (loader, merger, state, config)
- Guide includes working templates for manifest.json, EXTENSION.md, index-entries.json
- README.md documentation map includes the new files
- All internal links resolve correctly

## Testing & Validation

- [ ] Verify parent CLAUDE.md has no stale extension references in routing/mapping tables
- [ ] Verify adding-domains.md recommends extensions as primary approach
- [ ] Verify extension-system.md exists and covers loader, merger, state, config components
- [ ] Verify creating-extensions.md exists and includes manifest template
- [ ] Verify README.md documentation map includes new extension docs
- [ ] Verify all internal markdown links resolve to existing files

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-20260303.md (upon completion)
- `.claude/docs/architecture/extension-system.md` (new)
- `.claude/docs/guides/creating-extensions.md` (new)

## Rollback/Contingency

All changes are to documentation files only. Rollback is straightforward via `git checkout` of individual files. No code changes, no state migrations, no breaking changes to runtime behavior. The parent CLAUDE.md cleanup is the lowest-risk change since those entries reference skills that no longer exist in core.

## Design Decision: Neovim Extension (Not Implementing)

Research Recommendation 3 proposed moving neovim-specific artifacts (2 agents, 2 skills, 1 rule, 16 context files) to a `neovim` extension for full portability. This is explicitly NOT being implemented because:

1. This IS a Neovim configuration repository -- neovim is the primary domain
2. Neovim context is needed for the majority of tasks
3. The extension loading step would add friction without benefit
4. The child CLAUDE.md already correctly documents neovim as a core domain
5. Task 109 explicitly noted "neovim agents/skills/rules/context remain in core for now" as an intentional decision

This decision should be documented in the implementation summary when the task is completed.
