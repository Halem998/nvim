# Implementation Plan: Sync Missing Scripts to Core Extension

- **Task**: 612 - sync_missing_scripts_to_core_extension
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/612_sync_missing_scripts_to_core_extension/reports/01_script-sync-research.md
- **Artifacts**: plans/01_script-sync-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

18 scripts present in `.claude/scripts/` are missing from the core extension source directory (`.claude/extensions/core/scripts/`) and the `provides.scripts` array in `manifest.json`. This causes the `<leader>al` loader and `copy_scripts()` to never deploy these scripts to other projects, breaking all commands and skills in synced repositories. The fix is mechanical: copy the 18 files and update the manifest JSON array.

### Research Integration

Research report confirmed all 18 scripts are non-deprecated, general-purpose infrastructure. Critical finding: `postflight-workflow.sh` is the actual implementation that the three already-deployed postflight wrappers delegate to -- its absence means those wrappers are broken in synced projects. No script requires modification before copying; all are ready for direct inclusion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any named ROADMAP.md item, but it unblocks the agent system quality goals by ensuring all core scripts are deployable.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- All 18 missing scripts copied to `.claude/extensions/core/scripts/`
- All 18 scripts added to `provides.scripts` in `manifest.json`
- Loader can deploy the full script set to any synced project

**Non-Goals**:
- Running `<leader>al` to sync to downstream projects (user action post-fix)
- Modifying script content (they work as-is)
- Adding automated drift detection (separate task scope)
- Verifying downstream projects like ProofChecker (user confirms after sync)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| manifest.json becomes invalid JSON after edit | H | L | Validate with `jq empty manifest.json` after edit |
| A script is already in the extension directory (missed by research) | L | L | Use `cp -n` (no-clobber) or verify with `ls` before copy |
| File permissions lost during copy | M | L | Use `cp -p` to preserve permissions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Copy Scripts to Extension Directory [COMPLETED]

**Goal**: Place all 18 missing scripts in `.claude/extensions/core/scripts/`

**Tasks**:
- [x] Verify all 18 scripts exist in `.claude/scripts/` (sanity check) *(completed)*
- [x] Copy all 18 scripts with permission preservation: *(completed)*
  - `archive-task.sh`
  - `command-gate-in.sh`
  - `command-gate-out.sh`
  - `command-route-skill.sh`
  - `dispatch-agent.sh`
  - `generate-task-order.sh`
  - `issue-grouping.sh`
  - `memory-harvest.sh`
  - `orphan-detection.sh`
  - `parse-command-args.sh`
  - `postflight-workflow.sh`
  - `rename-session.sh`
  - `roadmap-integration.sh`
  - `roadmap-sync.sh`
  - `skill-base.sh`
  - `tier-selection.sh`
  - `validate-context-budgets.sh`
  - `vault-operation.sh`
- [x] Confirm all 18 files exist in `.claude/extensions/core/scripts/` after copy *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/` - 18 new files added

**Verification**:
- `ls .claude/extensions/core/scripts/ | wc -l` shows 44 (26 existing + 18 new)
- `diff <(ls .claude/scripts/*.sh | xargs -n1 basename | sort) <(ls .claude/extensions/core/scripts/*.sh | xargs -n1 basename | sort)` returns empty (top-level scripts match)

---

### Phase 2: Update manifest.json [COMPLETED]

**Goal**: Add all 18 script names to the `provides.scripts` array in alphabetical order

**Tasks**:
- [x] Add the following 18 entries to `provides.scripts` array in `manifest.json` (inserted alphabetically among existing entries): *(completed)*
  - `"archive-task.sh"`
  - `"command-gate-in.sh"`
  - `"command-gate-out.sh"`
  - `"command-route-skill.sh"`
  - `"dispatch-agent.sh"`
  - `"generate-task-order.sh"`
  - `"issue-grouping.sh"`
  - `"memory-harvest.sh"`
  - `"orphan-detection.sh"`
  - `"parse-command-args.sh"`
  - `"postflight-workflow.sh"`
  - `"rename-session.sh"`
  - `"roadmap-integration.sh"`
  - `"roadmap-sync.sh"`
  - `"skill-base.sh"`
  - `"tier-selection.sh"`
  - `"validate-context-budgets.sh"`
  - `"vault-operation.sh"`
- [x] Validate JSON is syntactically correct with `jq empty .claude/extensions/core/manifest.json` *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/manifest.json` - `provides.scripts` array expanded from 26 to 44 entries

**Verification**:
- `jq '.provides.scripts | length' .claude/extensions/core/manifest.json` returns 44
- `jq empty .claude/extensions/core/manifest.json` exits 0 (valid JSON)

---

### Phase 3: Cross-Verification [COMPLETED]

**Goal**: Confirm complete parity between `.claude/scripts/` and extension source

**Tasks**:
- [x] Compare filesystem: `comm -23 <(ls .claude/scripts/*.sh | xargs -n1 basename | sort) <(ls .claude/extensions/core/scripts/*.sh | xargs -n1 basename | sort)` should return empty *(completed)*
- [x] Compare manifest to filesystem: verify every file in `.claude/extensions/core/scripts/` is listed in `provides.scripts` (and vice versa) *(completed: 44 manifest entries, 44 filesystem files)*
- [x] Spot-check one critical script (`postflight-workflow.sh`) to confirm content matches source *(completed: files match exactly)*

**Timing**: 5 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- Zero differences between `.claude/scripts/` and `.claude/extensions/core/scripts/` for top-level `.sh` files
- Manifest `provides.scripts` count matches filesystem file count (44 entries, 44 files including `lint/lint-postflight-boundary.sh`)

## Testing & Validation

- [ ] `jq empty .claude/extensions/core/manifest.json` exits 0
- [ ] `jq '.provides.scripts | length' .claude/extensions/core/manifest.json` returns 44
- [ ] No diff between `.claude/scripts/` top-level `.sh` files and `.claude/extensions/core/scripts/` top-level `.sh` files
- [ ] `lint/lint-postflight-boundary.sh` remains in both locations (pre-existing nested entry unaffected)

## Artifacts & Outputs

- `.claude/extensions/core/scripts/` - 18 new script files
- `.claude/extensions/core/manifest.json` - Updated `provides.scripts` array (26 -> 44 entries)

## Rollback/Contingency

If implementation introduces issues:
1. Remove the 18 new files from `.claude/extensions/core/scripts/` (they are copies, not moves)
2. Revert `manifest.json` to previous state via `git checkout -- .claude/extensions/core/manifest.json`
3. Source files in `.claude/scripts/` are never modified, so no data loss risk
