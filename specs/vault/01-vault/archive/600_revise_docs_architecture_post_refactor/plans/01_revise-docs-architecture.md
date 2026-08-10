# Implementation Plan: Task #600

- **Task**: 600 - revise_docs_architecture_post_refactor
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Tasks 592-599 (all completed)
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_revise-docs-architecture.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

After tasks 592-599 modernized the runtime system (shared gate scripts, skill-base.sh, /orchestrate, dispatch-agent.sh, extension lifecycle hooks), the documentation was left in a partially stale state. This plan revises 12-14 markdown files across `.claude/docs/`, `.claude/context/architecture/`, and `.claude/extensions/core/docs/` to reflect the current architecture. The highest-impact update is the agent-facing `context/architecture/system-overview.md` (498 lines, dated 2026-01-19), which agents read when generating new components but which lacks core refactor concepts. The strategy is update-in-place with no removals or deprecation notices, updating `docs/` first (working copy) then syncing to `extensions/core/docs/` (distributable copy).

### Research Integration

The team research (3 teammates) identified 9 findings across critical/moderate/low severity:

- **Critical**: context/architecture/system-overview.md stale (lacks skill-base.sh, gate scripts, dispatch-agent, hooks); docs-README.md missing 4 new architecture docs; creating-commands.md and command-template.md use pre-refactor manual gate patterns; 4 new architecture docs missing from extensions/core/docs/ creating sync regression risk; 5 docs/ files diverge from core extension copies
- **Moderate**: user-guide.md missing /orchestrate, /spawn, /merge (NOT /tag -- already present); docs/README.md missing architecture links; creating-skills.md has mixed pre/post content
- **Low**: 4 architecture docs have stale "Target architecture" status framing
- **Corrections applied**: Teammate A incorrectly listed /tag as missing (it is present at line 506); Teammate B incorrectly listed templates/ as missing from docs-README.md tree (it is present at lines 31-34)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. However, it supports the "Agent System Quality" roadmap section by ensuring agents read current architecture documentation when generating new components.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Update the agent-facing `context/architecture/system-overview.md` to reflect the post-refactor architecture including skill-base.sh, gate scripts, dispatch-agent.sh, and lifecycle hooks
- Add 4 new architecture docs (architecture-spec.md, dispatch-agent-spec.md, handoff-schema.md, orchestrate-state-machine.md) to docs-README.md and docs/README.md index files
- Update creating-commands.md and command-template.md to reference shared gate scripts instead of manual patterns
- Add /orchestrate, /spawn, /merge command sections to user-guide.md
- Sync all updated docs/ files to extensions/core/docs/ to prevent "Load Core" regression
- Update stale "Target architecture" framing in 4 architecture docs to "Current architecture"

**Non-Goals**:
- Restructuring the docs/ vs context/ directory layout
- Renaming docs-README.md (Teammate B suggested this but it is out of scope for this task)
- Rewriting docs that are already current (system-overview.md in docs/, creating-extensions.md, agent-frontmatter-standard.md, etc.)
- Creating new documentation for features not yet documented elsewhere
- Modifying context/index.json entries or tier weights

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| context/ system-overview rewrite introduces inaccuracies about the refactor | H | M | Cross-reference with docs/ system-overview.md (known current) and task 592-599 artifacts |
| Sync to extensions/core/docs/ overwrites user customizations | M | L | Check .syncprotect before copying; only sync files that docs/ owns |
| creating-commands.md rewrite breaks existing guide flow | M | L | Preserve overall structure, update only Step 4 and template references |
| Missing edge cases in user-guide.md command sections | L | M | Use existing command sections as pattern; keep descriptions concise |
| docs/examples/ flow files have stale patterns (unassessed by research) | L | M | Quick assessment during Phase 3; flag for follow-up if substantial rewrite needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update Agent-Facing System Overview and Index Files [COMPLETED]

**Goal**: Update the highest-impact stale file (context/architecture/system-overview.md) and fix discoverability gaps in the two docs index files (docs-README.md and docs/README.md).

**Tasks**:
- [ ] Read `docs/architecture/system-overview.md` (336 lines, current) as the authoritative reference for refactored architecture
- [ ] Revise `context/architecture/system-overview.md` (498 lines) to incorporate:
  - Shared command infrastructure: `command-gate-in.sh`, `command-gate-out.sh`, `parse-command-args.sh`, `command-route-skill.sh`
  - Shared skill base: `skill-base.sh` with 12+ lifecycle functions
  - `/orchestrate` command and `dispatch-agent.sh` fork-vs-subagent dispatch
  - Extension lifecycle hooks schema
  - Command size reductions (research.md 393->191L, plan.md 420->202L, implement.md 525->207L)
  - Context budget system with 4-tier progressive disclosure
  - Preserve agent-facing framing (Purpose/Audience metadata, index.json loading context)
- [ ] Update `docs/docs-README.md` Documentation Map tree to add 4 new architecture docs under `architecture/` and add missing `reference/` section
- [ ] Update `docs/README.md` Documentation Hub "Reference" section to add links to the 4 new architecture docs (architecture-spec.md, dispatch-agent-spec.md, handoff-schema.md, orchestrate-state-machine.md)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/architecture/system-overview.md` - Major revision incorporating refactor concepts
- `.claude/docs/docs-README.md` - Add 4 architecture docs to map, add reference/ section
- `.claude/docs/README.md` - Add 4 architecture doc links to Documentation Hub

**Verification**:
- context/architecture/system-overview.md mentions skill-base.sh, command-gate-in.sh, parse-command-args.sh, dispatch-agent.sh, lifecycle hooks
- docs-README.md tree listing includes all 6 architecture docs and reference/ section
- docs/README.md links to all 6 architecture docs

---

### Phase 2: Update Command and Skill Guides [COMPLETED]

**Goal**: Replace pre-refactor manual gate patterns in command creation docs and add missing commands to user guide.

**Tasks**:
- [ ] Rewrite `docs/guides/creating-commands.md` Step 4 to reference shared gate scripts (`command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh`, `parse-command-args.sh`) instead of inline bash snippets
- [ ] Rewrite `docs/templates/command-template.md` to use shared script calls instead of manual GATE IN with inline skill-status-sync and session ID generation
- [ ] Add /orchestrate section to `docs/guides/user-guide.md` (autonomous lifecycle command)
- [ ] Add /spawn section to `docs/guides/user-guide.md` (spawn tasks to unblock blockers)
- [ ] Add /merge section to `docs/guides/user-guide.md` (create pull/merge request)
- [ ] Harmonize `docs/guides/creating-skills.md` "Skill Template" and "Step-by-Step Guide" sections to reference skill-base.sh lifecycle functions and gate scripts (the skill-base.sh section at line 78+ is already current)
- [ ] Add optional cross-references to new architecture docs in `docs/guides/creating-agents.md` Related Documentation section

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/docs/guides/creating-commands.md` - Replace manual gate pattern with shared scripts
- `.claude/docs/templates/command-template.md` - Replace manual gate pattern with shared scripts
- `.claude/docs/guides/user-guide.md` - Add /orchestrate, /spawn, /merge sections
- `.claude/docs/guides/creating-skills.md` - Harmonize template sections with skill-base.sh
- `.claude/docs/guides/creating-agents.md` - Add cross-references to architecture docs

**Verification**:
- creating-commands.md references command-gate-in.sh, command-gate-out.sh, parse-command-args.sh
- command-template.md uses shared script calls
- user-guide.md includes /orchestrate, /spawn, /merge in table of contents and has sections for each
- creating-skills.md template section references skill-base.sh lifecycle
- creating-agents.md Related Documentation includes dispatch-agent-spec.md, handoff-schema.md

---

### Phase 3: Cosmetic Fixes, Status Framing, and Example Assessment [COMPLETED]

**Goal**: Fix stale "Target architecture" framing in 4 docs, update templates/README.md, and assess docs/examples/ files for stale patterns.

**Tasks**:
- [ ] Update `docs/architecture/architecture-spec.md` status framing from "Target architecture" to "Current architecture (implemented by tasks 593-599)"
- [ ] Update `docs/architecture/dispatch-agent-spec.md` status framing from "Target architecture" to "Current architecture"
- [ ] Update `docs/architecture/handoff-schema.md` status framing from "Target architecture" to "Current architecture"
- [ ] Update `docs/architecture/orchestrate-state-machine.md` status framing from "Target architecture" to "Current architecture"
- [ ] Update `docs/templates/README.md` architecture section to list all 6 architecture docs
- [ ] Assess `docs/examples/research-flow-example.md` for stale pre-refactor patterns; update or note for follow-up
- [ ] Assess `docs/examples/fix-it-flow-example.md` for stale pre-refactor patterns; update or note for follow-up

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/docs/architecture/architecture-spec.md` - Status framing update
- `.claude/docs/architecture/dispatch-agent-spec.md` - Status framing update
- `.claude/docs/architecture/handoff-schema.md` - Status framing update
- `.claude/docs/architecture/orchestrate-state-machine.md` - Status framing update
- `.claude/docs/templates/README.md` - Add architecture doc listings
- `.claude/docs/examples/research-flow-example.md` - Assess and update if needed
- `.claude/docs/examples/fix-it-flow-example.md` - Assess and update if needed

**Verification**:
- grep for "Target architecture" in 4 architecture docs returns zero matches
- templates/README.md lists all 6 architecture docs
- Example files either updated or flagged with inline note for follow-up

---

### Phase 4: Extension Core Sync and Cross-Reference Validation [COMPLETED]

**Goal**: Sync all updated docs/ files to extensions/core/docs/ to prevent "Load Core" regression, and validate cross-references across the documentation.

**Tasks**:
- [ ] Copy 4 new architecture docs from `docs/architecture/` to `extensions/core/docs/architecture/`: architecture-spec.md, dispatch-agent-spec.md, handoff-schema.md, orchestrate-state-machine.md
- [ ] Sync updated `docs/architecture/system-overview.md` to `extensions/core/docs/architecture/system-overview.md`
- [ ] Sync updated `docs/guides/creating-commands.md` to `extensions/core/docs/guides/creating-commands.md`
- [ ] Sync updated `docs/guides/creating-skills.md` to `extensions/core/docs/guides/creating-skills.md`
- [ ] Sync updated `docs/guides/creating-agents.md` to `extensions/core/docs/guides/creating-agents.md`
- [ ] Sync updated `docs/guides/user-guide.md` to `extensions/core/docs/guides/user-guide.md`
- [ ] Sync updated `docs/templates/command-template.md` to `extensions/core/docs/templates/command-template.md`
- [ ] Sync updated `docs/templates/README.md` to `extensions/core/docs/templates/README.md`
- [ ] Sync updated `docs/docs-README.md` to `extensions/core/docs/docs-README.md`
- [ ] Sync updated `docs/README.md` to `extensions/core/docs/README.md`
- [ ] Sync updated example files to `extensions/core/docs/examples/` (if modified in Phase 3)
- [ ] Sync `docs/reference/standards/agent-frontmatter-standard.md` and `docs/reference/standards/multi-task-creation-standard.md` to core extension copies (these diverge per research)
- [ ] Validate cross-references: grep for broken relative links (../*, ./*, etc.) across all modified files
- [ ] Verify no .syncprotect entries block the sync targets

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/core/docs/architecture/` - Add 4 new files, update system-overview.md
- `.claude/extensions/core/docs/guides/` - Sync creating-commands.md, creating-skills.md, creating-agents.md, user-guide.md
- `.claude/extensions/core/docs/templates/` - Sync command-template.md, README.md
- `.claude/extensions/core/docs/docs-README.md` - Sync from docs/
- `.claude/extensions/core/docs/README.md` - Sync from docs/
- `.claude/extensions/core/docs/examples/` - Sync if modified
- `.claude/extensions/core/docs/reference/standards/` - Sync diverged files

**Verification**:
- `diff -r .claude/docs/ .claude/extensions/core/docs/` shows no unexpected differences (only files not in scope should differ)
- 4 new architecture docs exist in both docs/ and extensions/core/docs/architecture/
- grep for broken cross-references returns zero results
- "Load Core" sync would no longer regress any updated files

---

## Testing & Validation

- [ ] context/architecture/system-overview.md contains references to skill-base.sh, command-gate-in.sh, parse-command-args.sh, dispatch-agent.sh, lifecycle hooks
- [ ] docs-README.md Documentation Map includes all 6 architecture docs and reference/ section
- [ ] docs/README.md Documentation Hub links all 6 architecture docs
- [ ] creating-commands.md references shared gate scripts (zero matches for manual inline gate pattern)
- [ ] command-template.md uses shared script calls
- [ ] user-guide.md includes /orchestrate, /spawn, /merge (and /tag already present)
- [ ] creating-skills.md template section aligned with skill-base.sh
- [ ] No architecture docs contain "Target architecture" in status framing
- [ ] `diff -r .claude/docs/ .claude/extensions/core/docs/` shows only expected differences
- [ ] No broken cross-references across modified files

## Artifacts & Outputs

- `specs/600_revise_docs_architecture_post_refactor/plans/01_revise-docs-architecture.md` (this plan)
- Updated `.claude/context/architecture/system-overview.md` (agent-facing, major revision)
- Updated `.claude/docs/` files (12-14 files across architecture/, guides/, templates/, examples/)
- Synced `.claude/extensions/core/docs/` (mirror of docs/ updates)

## Rollback/Contingency

All changes are to markdown documentation files tracked by git. If any update introduces inaccuracies or breaks documentation structure:
1. Use `git diff` to review specific file changes
2. Use `git checkout -- <file>` to revert individual files
3. The full changeset can be reverted with a single `git revert` on the implementation commit
4. No runtime code is modified -- documentation errors do not affect system behavior
