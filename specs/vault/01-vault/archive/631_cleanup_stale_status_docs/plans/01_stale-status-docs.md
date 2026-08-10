# Implementation Plan: Task #631

- **Task**: 631 - Clean up stale status documentation and consolidate
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/631_cleanup_stale_status_docs/reports/01_stale-status-docs.md
- **Artifacts**: plans/01_stale-status-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove the deprecated `status-transitions.md` file and its mirrors/references, replace stale `status-sync-manager` instructions in `status-markers.md` with correct `skill-base.sh` / `update-task-status.sh` documentation, add header notes to `inline-status-update.md`, document orchestrate interaction in `skill-status-sync/SKILL.md` and `rules/state-management.md`, and clean up all tracking references. Every primary file edit must be mirrored to the core extension copy.

### Research Integration

Research report (01_stale-status-docs.md) confirmed:
- 284 occurrences of `status-sync-manager` across 37 files; this task addresses the 6 key files in scope (sub-tasks a-f)
- `status-transitions.md` already has DEPRECATED banner but body still contains harmful instructions
- `status-markers.md` has two stale sections (lines 220-276) instructing delegation to the obsolete subagent
- `inline-status-update.md` is clean (no stale references) and actively referenced by 4 files
- `skill-status-sync/SKILL.md` and `rules/state-management.md` are clean but missing orchestrate flow documentation
- CLAUDE.md files require no changes
- All three status context files have identical mirrors in `.claude/extensions/core/context/`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this documentation cleanup task.

## Goals & Non-Goals

**Goals**:
- Delete the deprecated `status-transitions.md` file and all references to it
- Replace `status-sync-manager` instructions in `status-markers.md` with correct `skill-base.sh` documentation
- Add clarifying header to `inline-status-update.md` identifying `skill-base.sh` as primary path
- Document orchestrate interaction in `skill-status-sync/SKILL.md`
- Add orchestrate flow subsection to `rules/state-management.md`
- Keep all primary files and core extension mirrors in sync

**Non-Goals**:
- Cleaning up `status-sync-manager` references in the remaining ~30 out-of-scope files (noted for future task)
- Rewriting `inline-status-update.md` jq patterns (they remain valid)
- Modifying CLAUDE.md files (already correct per research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Primary edits not mirrored to core extension copies | M | M | Each phase explicitly includes mirror step; verification checks both paths |
| Removing index.json entry breaks context loading | L | L | Entry only loaded for `/task` + `meta`; safe to remove |
| extensions.json edit introduces parse error | H | L | Validate JSON with jq after edit |
| Cross-references missed during cleanup | M | L | Research report provides complete cross-reference map |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Delete status-transitions.md and clean references [COMPLETED]

**Goal**: Remove the deprecated file, its core extension mirror, its index.json entry, its extensions.json tracking, and cross-references in other files.

**Tasks**:
- [ ] Delete `.claude/context/workflows/status-transitions.md`
- [ ] Delete `.claude/extensions/core/context/workflows/status-transitions.md`
- [ ] Remove the `status-transitions.md` entry from `.claude/context/index.json` (the entry with `path: "workflows/status-transitions.md"`)
- [ ] Remove `.claude/context/workflows/status-transitions.md` from the `installed_files` array in `.claude/extensions.json` (line ~268)
- [ ] Remove `workflows/status-transitions.md` from the core extension `context_files` array in `.claude/extensions.json` (line ~440)
- [ ] Remove the `status-transitions.md` reference from `.claude/context/orchestration/architecture.md` (line 540: `- workflows/status-transitions.md - Status transition rules`)
- [ ] Validate `.claude/extensions.json` parses correctly with `jq . .claude/extensions.json > /dev/null`
- [ ] Validate `.claude/context/index.json` parses correctly with `jq . .claude/context/index.json > /dev/null`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/workflows/status-transitions.md` - DELETE
- `.claude/extensions/core/context/workflows/status-transitions.md` - DELETE
- `.claude/context/index.json` - Remove entry
- `.claude/extensions.json` - Remove two references
- `.claude/context/orchestration/architecture.md` - Remove cross-reference line

**Verification**:
- Both `status-transitions.md` files no longer exist
- `jq . .claude/context/index.json` succeeds with no `status-transitions` entries
- `jq . .claude/extensions.json` succeeds with no `status-transitions` references
- `grep -rn "status-transitions" .claude/context/ .claude/extensions/` returns no results

---

### Phase 2: Update status-markers.md to remove stale status-sync-manager content [COMPLETED]

**Goal**: Replace the "Status Update Protocol" section (lines 220-264) and "Atomic Synchronization" section (lines 268-276) with correct documentation describing `skill-base.sh` functions and `update-task-status.sh`. Also clean up the References section (lines 310-315) to remove references to deleted files.

**Tasks**:
- [ ] Replace "Status Update Protocol" section (lines 220-264) with new content describing:
  - `skill_preflight_update()` from `skill-base.sh` sets in-progress status before work begins
  - `skill_postflight_update()` from `skill-base.sh` sets final status and links artifacts after work finishes
  - Both call `update-task-status.sh` which atomically updates `state.json` and `TODO.md`
  - For manual/recovery use: `skill-status-sync` skill provides standalone operations
- [ ] Replace "Atomic Synchronization" section (lines 268-276) with description of `update-task-status.sh` atomic update behavior (state.json first, then TODO.md, then plan file)
- [ ] Remove `status-transitions.md` reference from References section (line 313)
- [ ] Remove `status-sync-manager.md` reference from References section (line 314)
- [ ] Add references to `skill-base.sh` and `update-task-status.sh` in References section
- [ ] Apply identical edits to `.claude/extensions/core/context/standards/status-markers.md`

**Timing**: 30 minutes

**Depends on**: 1 (status-transitions.md reference removal depends on file being deleted first)

**Files to modify**:
- `.claude/context/standards/status-markers.md` - Replace stale sections
- `.claude/extensions/core/context/standards/status-markers.md` - Mirror same edits

**Verification**:
- `grep -n "status-sync-manager" .claude/context/standards/status-markers.md` returns no results
- `grep -n "status-transitions" .claude/context/standards/status-markers.md` returns no results
- Both files contain references to `skill-base.sh` and `update-task-status.sh`
- `diff .claude/context/standards/status-markers.md .claude/extensions/core/context/standards/status-markers.md` returns no differences

---

### Phase 3: Add header note to inline-status-update.md [COMPLETED]

**Goal**: Add a clarifying note at the top of `inline-status-update.md` identifying `skill-base.sh` as the primary status update path, with these jq patterns serving as reference/fallback documentation.

**Tasks**:
- [ ] Add a note block after the title (line 1) and before the existing content (line 3), e.g.:
  ```
  > **Note**: The primary status update path is `skill_preflight_update()` / `skill_postflight_update()` from `skill-base.sh`, which call `update-task-status.sh`. The jq patterns below document the underlying operations and serve as reference for debugging and recovery scenarios.
  ```
- [ ] Apply identical edit to `.claude/extensions/core/context/patterns/inline-status-update.md`

**Timing**: 15 minutes

**Depends on**: 1 (logically independent but grouped in Wave 2 for clean ordering)

**Files to modify**:
- `.claude/context/patterns/inline-status-update.md` - Add header note
- `.claude/extensions/core/context/patterns/inline-status-update.md` - Mirror same edit

**Verification**:
- Both files contain the new note about `skill-base.sh`
- `diff .claude/context/patterns/inline-status-update.md .claude/extensions/core/context/patterns/inline-status-update.md` returns no differences

---

### Phase 4: Update skill-status-sync/SKILL.md and rules/state-management.md [COMPLETED]

**Goal**: Document orchestrate interaction in the skill file and add an orchestrate flow subsection to the state management rule.

**Tasks**:
- [ ] In `.claude/skills/skill-status-sync/SKILL.md`, add a paragraph to the "Standalone Use Only" section (after line 28) explaining: "The `/orchestrate` command calls `skill_postflight_update()` from `skill-base.sh` after each lifecycle dispatch cycle. Orchestrate reads `state.json` for current task status, dispatches the next lifecycle phase (research, plan, implement), and uses `skill_postflight_update()` for status transitions. It does not invoke this skill."
- [ ] In `.claude/rules/state-management.md`, add a new "Orchestrate Flow" subsection after the "Restrictions" subsection (after line 41), documenting: `/orchestrate` drives tasks through successive lifecycle phases by reading `state.json` status, dispatching to the appropriate skill, and calling `skill_postflight_update()` from `skill-base.sh` after each dispatch. The cycle repeats (`research -> plan -> implement`) until the task reaches a terminal state.

**Timing**: 20 minutes

**Depends on**: 2 (conceptually independent, but benefits from status-markers.md being updated first for consistent terminology)

**Files to modify**:
- `.claude/skills/skill-status-sync/SKILL.md` - Add orchestrate interaction note
- `.claude/rules/state-management.md` - Add orchestrate flow subsection

**Verification**:
- `grep -n "orchestrate" .claude/skills/skill-status-sync/SKILL.md` shows the new content
- `grep -n "orchestrate\|Orchestrate" .claude/rules/state-management.md` shows the new subsection
- Both additions reference `skill_postflight_update()` and `skill-base.sh`

---

### Phase 5: Verify and validate all changes [COMPLETED]

**Goal**: Run comprehensive verification to ensure all changes are consistent, no stale references remain in the modified files, and mirrors are in sync.

**Tasks**:
- [ ] Verify `status-transitions.md` is fully removed: `find .claude/ -name "status-transitions.md"` returns nothing
- [ ] Verify no `status-sync-manager` references in the 5 modified files: `grep -l "status-sync-manager" .claude/context/standards/status-markers.md .claude/context/patterns/inline-status-update.md .claude/skills/skill-status-sync/SKILL.md .claude/rules/state-management.md` returns nothing
- [ ] Verify mirror sync for status-markers.md: `diff .claude/context/standards/status-markers.md .claude/extensions/core/context/standards/status-markers.md`
- [ ] Verify mirror sync for inline-status-update.md: `diff .claude/context/patterns/inline-status-update.md .claude/extensions/core/context/patterns/inline-status-update.md`
- [ ] Verify JSON validity: `jq . .claude/context/index.json > /dev/null && jq . .claude/extensions.json > /dev/null`
- [ ] Verify no dangling cross-references to deleted files in architecture.md: `grep "status-transitions" .claude/context/orchestration/architecture.md` returns nothing

**Timing**: 15 minutes

**Depends on**: none (runs after all phases, but has no explicit phase dependency since it is a final check)

**Files to modify**:
- None (read-only verification)

**Verification**:
- All checks pass with no errors

## Testing & Validation

- [ ] Both `status-transitions.md` files are deleted (primary and core extension mirror)
- [ ] `status-markers.md` contains no `status-sync-manager` references and references `skill-base.sh` / `update-task-status.sh`
- [ ] `inline-status-update.md` has a header note about `skill-base.sh` being the primary path
- [ ] `skill-status-sync/SKILL.md` documents orchestrate interaction
- [ ] `rules/state-management.md` has orchestrate flow subsection
- [ ] All primary files match their core extension mirrors (where mirrors exist)
- [ ] `index.json` and `extensions.json` parse without errors and contain no `status-transitions` references
- [ ] CLAUDE.md files unchanged (confirmed correct in research)

## Artifacts & Outputs

- `specs/631_cleanup_stale_status_docs/plans/01_stale-status-docs.md` (this file)
- Modified: `.claude/context/standards/status-markers.md` + mirror
- Modified: `.claude/context/patterns/inline-status-update.md` + mirror
- Modified: `.claude/skills/skill-status-sync/SKILL.md`
- Modified: `.claude/rules/state-management.md`
- Modified: `.claude/context/index.json`
- Modified: `.claude/extensions.json`
- Modified: `.claude/context/orchestration/architecture.md`
- Deleted: `.claude/context/workflows/status-transitions.md` + mirror

## Rollback/Contingency

All files are tracked in git. If changes cause issues:
1. `git checkout -- .claude/context/workflows/status-transitions.md .claude/extensions/core/context/workflows/status-transitions.md` to restore deleted files
2. `git checkout -- .claude/context/standards/status-markers.md .claude/extensions/core/context/standards/status-markers.md` to restore original content
3. `git checkout -- .claude/context/index.json .claude/extensions.json` to restore tracking entries
