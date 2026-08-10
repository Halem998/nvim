# Teammate A: Primary Research Findings — Task 600

**Role**: Primary Researcher — Audit current docs vs. refactored system
**Date**: 2026-05-22

---

## Key Findings: Current Documentation Inventory

### Architecture Docs (`.claude/docs/architecture/`)

| File | Lines | Last Updated | Status |
|------|-------|-------------|--------|
| `system-overview.md` | 336 | 2026-05-22 | **Recently updated by task 599** — describes current architecture including skill-base.sh, command gates, computed CLAUDE.md, extension hooks |
| `extension-system.md` | 556 | — | Covers extension loader, merger, state system |
| `architecture-spec.md` | 598 | 2026-05-22 | **NEW from task 592** — Unified workflow architecture spec (design document) |
| `dispatch-agent-spec.md` | 233 | 2026-05-22 | **NEW from task 592** — dispatch_agent() function spec |
| `handoff-schema.md` | 380 | 2026-05-22 | **NEW from task 592** — Orchestrator handoff JSON schema |
| `orchestrate-state-machine.md` | 235 | 2026-05-22 | **NEW from task 592** — /orchestrate state machine spec |

### Guides (`.claude/docs/guides/`)

| File | Lines | Last Updated | Status |
|------|-------|-------------|--------|
| `creating-commands.md` | 190 | — | **OUTDATED** — does not reference shared gate scripts |
| `creating-skills.md` | 680 | — | **Partially updated by task 599** — has skill-base.sh section but rest predates refactor |
| `creating-agents.md` | 690 | — | Mostly current but could reference new architecture |
| `creating-extensions.md` | 853 | — | **Updated by task 599** — has lifecycle hooks section |
| `user-guide.md` | 599 | 2026-01-28 | **OUTDATED** — missing /orchestrate, /spawn, /tag, /merge commands |
| `adding-domains.md` | 454 | — | Adequate |
| `component-selection.md` | 405 | — | Adequate |
| `context-loading-best-practices.md` | 896 | — | Adequate |
| `copy-claude-directory.md` | 268 | — | Adequate |
| `permission-configuration.md` | 776 | — | Adequate |
| `user-installation.md` | 322 | — | Adequate |

### Reference Standards (`.claude/docs/reference/standards/`)

| File | Lines | Status |
|------|-------|--------|
| `agent-frontmatter-standard.md` | 217 | **Current** — updated 2026-04-16, describes tiered model policy |
| `extension-slim-standard.md` | 138 | Current |
| `multi-task-creation-standard.md` | 426 | Current |

### Templates (`.claude/docs/templates/`)

| File | Lines | Status |
|------|-------|--------|
| `README.md` | 352 | **Partially outdated** — architecture section lists only `system-overview.md` and `extension-system.md`; missing 4 new architecture docs |
| `command-template.md` | 84 | **OUTDATED** — uses manual GATE IN steps instead of shared `command-gate-in.sh` / `command-gate-out.sh` |
| `agent-template.md` | 94 | Current — properly references return-metadata-file pattern |

### Index Files

| File | Lines | Status |
|------|-------|--------|
| `README.md` (root) | 259 | **Partially outdated** — architecture diagram section missing 4 new docs from task 592; /orchestrate in command table but docs hub missing architecture spec links |
| `docs-README.md` | 95 | **OUTDATED** — Documentation Map tree listing omits 4 new architecture files; architecture section mentions only "Three-layer architecture" without referencing new unified workflow docs |

---

## Current State of Refactored System (Tasks 592-599)

### What Actually Changed

1. **Shared Command Infrastructure** (task 593): Created `parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh` — commands now ~200 lines instead of ~400-500
2. **Shared Skill Base** (task 594): Created `skill-base.sh` (22K, 363 lines) with 12+ lifecycle functions — extension skills now ~83-104 lines
3. **Command Refactoring** (task 595): `research.md` 393→191L, `plan.md` 420→202L, `implement.md` 525→207L; added `orchestrator_mode` to core skills
4. **/orchestrate Command** (task 596): New autonomous lifecycle command, `skill-orchestrate`, `dispatch-agent.sh`
5. **Secondary Command Refactoring** (task 597): `/revise` 160→125L, `/todo` 1046→630L, `/review` 1039→810L; extracted 8 utility scripts
6. **Context Budget System** (task 598): 4-tier progressive disclosure on all 142 index entries, `validate-context-budgets.sh`
7. **Extension Lifecycle Hooks** (task 599): Hook schema in all 16 manifests, nvim/nix skills thinned, `system-overview.md` updated

### Key New Scripts

| Script | Purpose | Lines |
|--------|---------|-------|
| `skill-base.sh` | Shared skill lifecycle functions | 22,147 |
| `parse-command-args.sh` | Parse task numbers + flags | 4,418 |
| `command-gate-in.sh` | Session gen + task lookup + validation | 2,512 |
| `command-gate-out.sh` | Artifact validation + status correction | 3,214 |
| `command-route-skill.sh` | Task type → skill name routing | 2,432 |
| `dispatch-agent.sh` | Fork-vs-subagent dispatch | 5,455 |

### Key New Architecture Docs (from task 592)

| Document | Purpose |
|----------|---------|
| `architecture-spec.md` | Unified workflow design spec, 7-task dependency ordering |
| `dispatch-agent-spec.md` | dispatch_agent() function specification |
| `handoff-schema.md` | Orchestrator handoff JSON schema |
| `orchestrate-state-machine.md` | /orchestrate 10-state machine specification |

---

## Gap Analysis

### CRITICAL Gaps (Docs describe pre-refactor architecture)

#### 1. `docs-README.md` — Documentation Map Missing New Architecture Files
- **Gap**: Tree listing shows only `system-overview.md` and `extension-system.md` under `architecture/`
- **Reality**: 4 additional architecture docs exist: `architecture-spec.md`, `dispatch-agent-spec.md`, `handoff-schema.md`, `orchestrate-state-machine.md`
- **Impact**: Developers can't discover the new architecture documentation
- **Confidence**: HIGH

#### 2. `creating-commands.md` — No Reference to Shared Gate Scripts
- **Gap**: Step 4 describes manual GATE IN/DELEGATE/GATE OUT/COMMIT with inline bash snippets
- **Reality**: Commands now use `command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh`, `parse-command-args.sh`
- **Impact**: New commands created from this guide will duplicate infrastructure instead of using shared scripts
- **Confidence**: HIGH

#### 3. `command-template.md` — Uses Manual Gate Pattern
- **Gap**: Template shows manual GATE IN with inline `skill-status-sync` calls and manual session ID generation
- **Reality**: Commands now call `bash .claude/scripts/command-gate-in.sh "$task_number" "operation"` which handles session gen, task lookup, and validation; postflight uses `bash .claude/scripts/command-gate-out.sh`
- **Impact**: Any command generated from this template will have pre-refactor structure
- **Confidence**: HIGH

#### 4. `user-guide.md` — Missing /orchestrate, /spawn, /tag, /merge
- **Gap**: Table of contents lists /task, /research, /plan, /revise, /implement, /todo, /review, /refresh, /errors, /meta, /fix-it, /convert — missing 4 commands
- **Reality**: /orchestrate (task 596), /spawn, /tag, /merge are all available
- **Impact**: Users won't discover these commands from the guide
- **Confidence**: HIGH

### MODERATE Gaps (Partially outdated)

#### 5. `README.md` (root docs) — Documentation Hub Missing Architecture Spec Links
- **Gap**: "Documentation Hub" section under "Reference" links only to `system-overview.md` and `extension-system.md`
- **Reality**: 4 new architecture docs should also be linked
- **Impact**: Architecture documentation is half-discoverable
- **Confidence**: HIGH

#### 6. `creating-skills.md` — Mixed Pre/Post Refactor Content
- **Gap**: The skill-base.sh section was added by task 599 and is current, but the main "Skill Template" section (line 222+) and "Step-by-Step Guide" section still show the pre-refactor pattern without referencing the gate scripts or lifecycle functions
- **Reality**: Extension skills use skill-base.sh; core skills still have inline lifecycle stages but are shorter
- **Impact**: Confusing mixed guidance for developers
- **Confidence**: MEDIUM

#### 7. `templates/README.md` — Missing Skill Template Reference
- **Gap**: Lists command-template.md and agent-template.md but the skill template entry points to `.claude/context/templates/thin-wrapper-skill.md` (not in docs/templates/)
- **Reality**: Skill template should reflect the thin wrapper pattern with skill-base.sh
- **Impact**: Developers may look in the wrong place for the skill template
- **Confidence**: MEDIUM

### LOW Gaps (Minor or cosmetic)

#### 8. `architecture-spec.md` — Status Framing
- **Gap**: Header says "Target architecture for the unified workflow refactor" with "Status: Target architecture"
- **Reality**: Tasks 593-599 are all completed; this is now current architecture, not target
- **Impact**: Cosmetic — readers might think it's aspirational rather than implemented
- **Confidence**: HIGH

#### 9. `dispatch-agent-spec.md`, `handoff-schema.md`, `orchestrate-state-machine.md` — Status Framing
- **Gap**: All say "Status: Target architecture — designed by Task 592, implemented by Task 596"
- **Reality**: All are implemented and current
- **Impact**: Same cosmetic issue as #8
- **Confidence**: HIGH

#### 10. `creating-agents.md` — No Cross-Reference to Architecture Specs
- **Gap**: Related Documentation section doesn't reference the new architecture docs
- **Reality**: Agents interact with dispatch-agent.sh and the handoff schema
- **Impact**: Minor — agents don't typically need to know about dispatch-agent.sh (skills handle this)
- **Confidence**: LOW

---

## Recommended Approach (Priority Order)

### Phase 1: Critical Updates (High Impact, Required)

1. **`docs-README.md`** — Add 4 new architecture files to Documentation Map tree and Architecture section
2. **`command-template.md`** — Replace manual GATE IN/OUT with shared script calls (`command-gate-in.sh`, `command-gate-out.sh`, `parse-command-args.sh`)
3. **`creating-commands.md`** — Update Step 4 to reference shared gate scripts; add new examples; reference `command-route-skill.sh`
4. **`user-guide.md`** — Add /orchestrate, /spawn, /tag, /merge command sections

### Phase 2: Moderate Updates (Improve Consistency)

5. **`README.md`** (root docs) — Add architecture spec links to Documentation Hub
6. **`creating-skills.md`** — Harmonize the template section with skill-base.sh patterns; ensure core skill vs extension skill distinction is clear
7. **`templates/README.md`** — Update architecture section, add cross-reference for skill template location

### Phase 3: Cosmetic/Status Updates

8. **`architecture-spec.md`** — Change "Target architecture" to "Current architecture" or "Implemented architecture"
9. **`dispatch-agent-spec.md`**, **`handoff-schema.md`**, **`orchestrate-state-machine.md`** — Same status framing update
10. **`creating-agents.md`** — Add optional cross-references to new architecture docs

### Phase 4: Assessment (No Changes Expected)

11. **`agent-frontmatter-standard.md`** — Already current (2026-04-16)
12. **`multi-task-creation-standard.md`** — Already current
13. **`extension-slim-standard.md`** — Already current
14. **`creating-extensions.md`** — Already updated by task 599

---

## Files That Are Fully Current (No Changes Needed)

- `system-overview.md` — Updated by task 599 (2026-05-22)
- `creating-extensions.md` — Updated by task 599 with lifecycle hooks
- `agent-frontmatter-standard.md` — Current (2026-04-16)
- `multi-task-creation-standard.md` — Current
- `extension-slim-standard.md` — Current
- `agent-template.md` — Current pattern

## Files That May Need Deprecation Assessment

No files in `.claude/docs/` describe exclusively pre-refactor architecture. The `architecture-spec.md` originally described the "target" architecture but is now the implemented reality. No docs need to be removed — only updated.

---

## Summary

The refactor (tasks 592-599) successfully modernized the runtime system but left documentation gaps in 4 critical areas:
1. **Discovery** — New architecture docs not indexed in README files
2. **Command creation guide** — Still describes manual gate patterns instead of shared scripts
3. **Command template** — Same manual pattern issue
4. **User guide** — Missing 4 commands (/orchestrate, /spawn, /tag, /merge)

The `system-overview.md` and `creating-extensions.md` were properly updated by task 599, but the remaining guides and index files were not touched.

**Estimated effort**: 2-3 hours (matching task description)
**Confidence**: HIGH across all critical findings
