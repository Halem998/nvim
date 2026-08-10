# Research Report: Task #600

**Task**: Revise docs architecture post-refactor
**Date**: 2026-05-22
**Mode**: Team Research (3 teammates, default mode)

## Summary

The tasks 592-599 refactoring successfully modernized the runtime system (shared gate scripts, skill-base.sh, /orchestrate, dispatch-agent.sh, extension lifecycle hooks) but left documentation in a partially stale state. Six docs files are fully current (updated by task 599), but 7-10 files have gaps ranging from critical to cosmetic. The most impactful single finding is that `.claude/context/architecture/system-overview.md` (the agent-facing version) is 4 months stale and lacks core refactor concepts -- agents building new components read this file, not the updated docs/ version. Additionally, 4 new architecture docs created by task 592 exist in docs/ but are unlisted in docs-README.md and missing from extensions/core/docs/, creating both discoverability and sync-regression risks.

## Key Findings

### 1. Critical: context/architecture/system-overview.md Is Stale (Agent-Facing)

**Source**: Teammate B (identified), Critic (verified with nuance)

Two system-overview.md files exist with different freshness:
- `docs/architecture/system-overview.md` -- 336 lines, updated 2026-05-22 by task 599, fully current
- `context/architecture/system-overview.md` -- 498 lines, dated 2026-01-19, missing key refactor concepts

The context/ version IS loaded by agents via index.json (meta-builder-agent, planner-agent). It lacks references to: skill-base.sh, command-gate-in.sh, parse-command-args.sh, dispatch-agent.sh, lifecycle hooks. It does mention /orchestrate (partial update), but core shared-infrastructure concepts are absent. This means agents generating new components produce outdated patterns.

**Impact**: HIGH -- agents read stale architecture, producing pre-refactor components
**Confidence**: HIGH (verified by Critic spot-check)

### 2. Critical: docs-README.md Missing 4 New Architecture Docs

**Source**: Teammates A and B (agreed), Critic (verified)

The documentation map tree listing shows only `system-overview.md` and `extension-system.md` under `architecture/`, but 4 additional docs exist:
- `architecture-spec.md` -- Unified workflow architecture spec
- `dispatch-agent-spec.md` -- dispatch_agent() function spec
- `handoff-schema.md` -- Orchestrator handoff JSON schema
- `orchestrate-state-machine.md` -- /orchestrate state machine spec

Also missing from docs-README.md: the `reference/` section (3 standards files). The `templates/` section IS present (Critic corrected Teammate B's claim).

**Impact**: HIGH -- developers can't discover new architecture documentation
**Confidence**: HIGH

### 3. Critical: creating-commands.md Uses Pre-Refactor Patterns

**Source**: Teammate A (identified), Critic (verified, zero grep matches)

Step 4 describes manual GATE IN/DELEGATE/GATE OUT/COMMIT with inline bash snippets. The refactored system uses shared scripts: `command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh`, `parse-command-args.sh`. Any command created from this guide duplicates infrastructure.

**Impact**: HIGH -- new commands will have pre-refactor structure
**Confidence**: HIGH

### 4. Critical: command-template.md Uses Manual Gate Pattern

**Source**: Teammate A (identified), Critic (verified)

Template shows manual GATE IN with inline skill-status-sync calls and manual session ID generation. Should reference shared gate scripts.

**Impact**: HIGH -- generated commands will be pre-refactor
**Confidence**: HIGH

### 5. Critical: 4 New Architecture Docs Missing from extensions/core/docs/

**Source**: Teammate B (identified), Critic (verified)

The 4 docs created by task 592 exist in `.claude/docs/architecture/` but not in `.claude/extensions/core/docs/architecture/`. Additionally, 5 docs/ files diverge from their core extension copies (system-overview.md, creating-extensions.md, creating-skills.md, multi-task-creation-standard.md, agent-frontmatter-standard.md). Running "Load Core" sync will overwrite updated docs/ versions with stale core copies.

**Impact**: HIGH -- next sync operation will regress updates
**Confidence**: HIGH

### 6. Moderate: user-guide.md Missing 3 Commands

**Source**: Teammate A (identified), Critic (corrected count)

Missing commands: `/orchestrate`, `/spawn`, `/merge`. Note: `/tag` IS present at line 506 (Teammate A incorrectly included it -- Critic caught this error).

**Impact**: MEDIUM -- users won't discover these commands
**Confidence**: HIGH

### 7. Moderate: README.md (Docs Root) Missing Architecture Links

**Source**: Teammate A (identified)

Documentation Hub section under "Reference" links only to system-overview.md and extension-system.md. The 4 new architecture docs should be linked.

**Impact**: MEDIUM -- architecture documentation half-discoverable
**Confidence**: HIGH

### 8. Moderate: creating-skills.md Mixed Pre/Post Content

**Source**: Teammate A (identified)

The skill-base.sh section (added by task 599) is current, but the "Skill Template" and "Step-by-Step Guide" sections still show pre-refactor patterns without referencing gate scripts or lifecycle functions.

**Impact**: MEDIUM -- confusing mixed guidance
**Confidence**: MEDIUM

### 9. Low: 4 Architecture Docs Have Stale Status Framing

**Source**: Teammate A (identified)

architecture-spec.md, dispatch-agent-spec.md, handoff-schema.md, orchestrate-state-machine.md all say "Status: Target architecture" but tasks 593-599 are completed -- these are now implemented, not target.

**Impact**: LOW -- cosmetic, readers may think aspirational
**Confidence**: HIGH

## Synthesis

### Conflicts Resolved

| Conflict | Teammate A | Teammate B | Critic Verdict | Resolution |
|----------|-----------|-----------|----------------|------------|
| /tag in user-guide.md | Missing | Not assessed | Present (line 506) | **Teammate A wrong** -- only /orchestrate, /spawn, /merge missing |
| templates/ in docs-README.md | Not assessed | Missing | Present (lines 31-34) | **Teammate B wrong** -- only reference/ missing |
| context/ system-overview staleness | Not in scope | Completely stale | Partially stale | **Nuanced** -- has /orchestrate mentions but lacks core refactor concepts (skill-base.sh, gate scripts, dispatch-agent, hooks) |
| Scope: include context/ files? | docs/ only | Include context/ | Include as Phase 0 | **Recommend including** -- highest-impact single file |

### Gaps Identified

1. **docs/examples/** -- Neither teammate assessed the two flow example files (research-flow-example.md, fix-it-flow-example.md). These likely describe pre-refactor execution patterns. Need assessment during implementation.

2. **docs/guides/development/** -- context-index-migration.md listed as unlisted but not assessed for content accuracy.

3. **Extension sync direction** -- Teammate B identified the docs/ vs core/ divergence but didn't fully resolve which direction is canonical. Recommendation: update docs/ first (working copy), then sync to extensions/core/docs/ (distributable copy).

4. **Effort estimate** -- Teammate A estimates 2-3 hours. Critic notes this may be optimistic if context/ system-overview is included (498 lines needing significant revision). Adjusted estimate: 2-3 hours for docs/ only, 3-4 hours if context/ included.

### Recommendations

**Recommended execution order** (synthesized from all teammates):

1. **Phase 0: context/architecture/system-overview.md** (highest-impact single file)
   - Update the 498-line agent-facing file with refactor concepts
   - Include skill-base.sh, gate scripts, dispatch-agent.sh, lifecycle hooks
   - Preserve agent-facing framing (Purpose/Audience metadata)

2. **Phase 1: Core docs updates**
   - docs-README.md -- add 4 architecture docs + reference/ section to map
   - command-template.md -- replace manual gates with shared script calls
   - creating-commands.md -- update Step 4 for shared gate scripts
   - user-guide.md -- add /orchestrate, /spawn, /merge sections

3. **Phase 2: Extension sync**
   - Copy 4 new architecture docs to extensions/core/docs/architecture/
   - Sync 5 diverged files from docs/ to extensions/core/docs/
   - This prevents "Load Core" from regressing updates

4. **Phase 3: Secondary updates**
   - README.md (docs root) -- add architecture spec links
   - creating-skills.md -- harmonize template section with skill-base.sh
   - templates/README.md -- update architecture listing
   - Assess docs/examples/ files for stale patterns

5. **Phase 4: Cosmetic fixes**
   - Update "Target architecture" status framing in 4 architecture docs
   - Add optional cross-references in creating-agents.md

**Strategy**: Update-in-place (no removals or deprecation notices). No docs describe patterns that no longer exist -- the refactor evolved patterns, didn't remove them.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary audit | completed | high | Comprehensive gap analysis of all 28 docs files; prioritized change list |
| B | Cross-reference | completed | high | Critical context/ staleness finding; sync gap analysis; alternative strategy evaluation |
| C | Critic | completed | high | Corrected 2 errors (/tag, templates/); verified claims; identified gaps in examples/ and scope |

## References

- Task description: specs/state.json (task 600)
- Teammate A findings: specs/600_revise_docs_architecture_post_refactor/reports/01_teammate-a-findings.md
- Teammate B findings: specs/600_revise_docs_architecture_post_refactor/reports/01_teammate-b-findings.md
- Teammate C findings: specs/600_revise_docs_architecture_post_refactor/reports/01_teammate-c-findings.md
- Refactor tasks: 592 (architecture specs), 593 (shared commands), 594 (skill-base), 595 (command refactor), 596 (/orchestrate), 597 (secondary refactor), 598 (context budget), 599 (extension hooks)
