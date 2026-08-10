# Implementation Plan: Fix OpenCode Extension Routing in Child Projects

- **Task**: 572 - diagnose_opencode_lean_routing_failure
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/572_diagnose_opencode_lean_routing_failure/reports/01_opencode-routing-diagnosis.md
- **Artifacts**: plans/01_opencode-routing-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

OpenCode's Glob tool silently returns zero results for relative paths into hidden directories (`.opencode/`), causing extension manifest discovery to fail in all child projects. The nvim config already contains the fix (absolute paths via `git rev-parse --show-toplevel`), but no propagation mechanism exists to push core command updates to child projects. This plan fixes the immediate routing bug across all 6 affected child projects, creates a sync script to prevent future drift, and adds validation to catch routing failures explicitly. Definition of done: all child projects route extension-typed tasks correctly, and a reusable sync script exists for future command updates.

### Research Integration

Research report (01_opencode-routing-diagnosis.md) identified 9 findings. Key integrations:
- **Finding 1 (root cause)**: Relative-path Glob failure for `.opencode/` -- drives the fix strategy (absolute paths)
- **Findings 2-3 (scope)**: All 6 child projects affected -- determines Phase 1 scope
- **Finding 4 (no propagation)**: No sync mechanism -- drives Phase 2 (sync script creation)
- **Finding 7 (outdated tables)**: Hardcoded routing tables in child commands -- resolved by full file replacement
- **Finding 8 (missing preamble)**: COMMAND EXECUTION MODE absent from child commands -- resolved by full file replacement

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. The fix addresses OpenCode child project infrastructure, which is orthogonal to current roadmap priorities (documentation infrastructure, agent system quality).

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Fix extension routing in implement.md, research.md, and plan.md across all 6 child projects
- Bring all child project commands to full parity with the nvim canonical versions
- Create a reusable sync script to propagate future core command updates
- Add a routing validation check to surface failures explicitly

**Non-Goals**:
- Fixing the underlying OpenCode Glob tool behavior (upstream issue, out of scope)
- Reviewing or fixing task 129's incorrect implementation results in ProofChecker
- Syncing non-routing commands (errors.md, meta.md, task.md, etc.) -- out of scope for this task
- Modifying the extension loader to manage core commands (Priority 5 in research, deferred)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Child project commands have project-specific customizations that would be lost by wholesale replacement | H | L | Diff each child command against nvim source before replacing; preserve any project-specific sections |
| File permissions or ownership prevent writing to external project directories | M | L | Pre-check write access before starting; skip and report inaccessible projects |
| Some child projects may have extension-specific commands (lake.md, lean.md) that reference the old routing pattern | M | L | These are extension-provided commands, not core routing -- they do not contain manifest discovery code |
| Sync script becomes stale itself with no mechanism to update it | L | M | Document the script location in project-overview and CLAUDE.md; keep script simple and self-contained |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Audit and Replace Core Routing Commands in All Child Projects [COMPLETED]

**Goal**: Bring implement.md, research.md, and plan.md to full nvim parity across all 6 child projects by replacing them with the canonical nvim versions.

**Tasks**:
- [x] Read the nvim canonical versions of implement.md, research.md, and plan.md to establish the baseline *(completed)*
- [x] For each of the 3 child projects with routing code (ProofChecker, dotfiles, zed): diff their implement.md, research.md, and plan.md against nvim versions to identify any project-specific customizations *(completed: no project-specific customizations found, only outdated routing code and hardcoded tables)*
- [x] For each of the 3 child projects without routing code (OpenCode, ModelChecker, protocol): diff their implement.md, research.md, and plan.md against nvim versions to identify any project-specific customizations *(deviation: altered — opencode project has no .opencode/commands dir, skipped; ModelChecker and protocol done)*
- [x] Replace implement.md in all 6 child projects with the nvim canonical version *(completed: 5 projects updated; opencode project skipped — no .opencode/commands dir)*
- [x] Replace research.md in all 6 child projects with the nvim canonical version *(completed: 5 projects updated)*
- [x] Replace plan.md in all 6 child projects with the nvim canonical version *(completed: 5 projects updated)*
- [x] Verify each replaced file contains the `project_root=$(git rev-parse --show-toplevel` fix *(completed: all 5 show count=2)*
- [x] Verify each replaced file contains the `COMMAND EXECUTION MODE` preamble *(completed: all 5 show count=1)*
- [x] Verify each replaced file contains `manifest_count` warning logic *(completed: all 5 show count=3)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/Projects/ProofChecker/.opencode/commands/plan.md` - Replace with nvim canonical
- `/home/benjamin/.dotfiles/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/.dotfiles/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/.dotfiles/.opencode/commands/plan.md` - Replace with nvim canonical
- `/home/benjamin/Projects/OpenCode/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/Projects/OpenCode/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/Projects/OpenCode/.opencode/commands/plan.md` - Replace with nvim canonical
- `/home/benjamin/.config/zed/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/.config/zed/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/.config/zed/.opencode/commands/plan.md` - Replace with nvim canonical
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/plan.md` - Replace with nvim canonical
- `/home/benjamin/Projects/protocol/.opencode/commands/implement.md` - Replace with nvim canonical
- `/home/benjamin/Projects/protocol/.opencode/commands/research.md` - Replace with nvim canonical
- `/home/benjamin/Projects/protocol/.opencode/commands/plan.md` - Replace with nvim canonical

**Verification**:
- `grep -c "project_root" $project/.opencode/commands/implement.md` returns >= 1 for all 6 projects
- `grep -c "manifest_count" $project/.opencode/commands/implement.md` returns >= 1 for all 6 projects
- `grep -c "COMMAND EXECUTION MODE" $project/.opencode/commands/implement.md` returns 1 for all 6 projects
- Same checks for research.md and plan.md

---

### Phase 2: Create Core Command Sync Script [COMPLETED]

**Goal**: Create a reusable script that propagates canonical core command files from the nvim source to all registered child projects, preventing future drift.

**Tasks**:
- [x] Create `.opencode/scripts/sync-core-commands.sh` in the nvim config *(completed)*
- [x] Define the list of core routing commands to sync: implement.md, research.md, plan.md *(completed)*
- [x] Define the registry of child project paths (hardcoded list with existence checks) *(completed)*
- [x] Implement dry-run mode (`--dry-run`) that shows what would be copied without modifying files *(completed)*
- [x] Implement actual sync mode that copies canonical files to each child project *(completed)*
- [x] Add diff-based reporting: show which files changed vs which were already current *(completed)*
- [x] Add a `--check` mode that only reports drift without fixing (exit code 1 if drift detected) *(completed)*
- [x] Make the script idempotent (re-running produces the same result) *(completed)*
- [x] Add `--commands` flag to optionally specify which commands to sync (default: all three routing commands) *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/scripts/sync-core-commands.sh` - New file: sync script

**Verification**:
- Script runs without errors in `--dry-run` mode
- Script correctly identifies that all child projects are now up to date (no drift after Phase 1)
- Script in `--check` mode exits 0 when all files match

---

### Phase 3: Add Routing Validation Warning [COMPLETED]

**Goal**: Add explicit warning logic to implement.md, research.md, and plan.md in the nvim canonical source when a non-default task type is detected but no extension routing was found, making silent fallback visible.

**Tasks**:
- [x] Add a warning block after the manifest discovery loop in the nvim implement.md that warns when `task_type` is not `general`/`meta`/`markdown` AND `skill_name` is empty AND `manifest_count > 0` *(completed)*
- [x] Add the same warning block to the nvim research.md *(completed)*
- [x] Add the same warning block to the nvim plan.md *(completed)*
- [x] Re-run the sync script from Phase 2 to propagate the validation warning to all child projects *(completed: 15 files updated across 5 child projects)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/commands/implement.md` - Add routing fallback warning
- `/home/benjamin/.config/nvim/.opencode/commands/research.md` - Add routing fallback warning
- `/home/benjamin/.config/nvim/.opencode/commands/plan.md` - Add routing fallback warning
- All 18 child project command files (via sync script re-run)

**Verification**:
- Grep for the warning text in nvim source files confirms presence
- After sync, grep for the warning text in all child project files confirms propagation
- Manual review of warning logic confirms it only fires for non-default task types with failed routing

---

### Phase 4: End-to-End Validation [COMPLETED]

**Goal**: Verify the routing fix works correctly across all child projects by running manifest discovery logic and confirming the fix in ProofChecker specifically.

**Tasks**:
- [x] In ProofChecker, run the absolute-path manifest discovery logic via Bash to confirm manifests are found: `project_root=$(git rev-parse --show-toplevel); ls "$project_root/.opencode/extensions/"*/manifest.json` *(completed: found 7 manifests including lean/manifest.json)*
- [x] In each child project that has extensions installed, verify the manifest discovery returns results *(completed: ProofChecker confirmed; other projects don't have extensions dir)*
- [x] Verify the nvim source commands have no regressions by checking for all required sections (routing, preamble, delegation chain notes) *(completed: all sections verified present)*
- [x] Run the sync script in `--check` mode to confirm zero drift across all child projects *(completed: exit code 0, 15 files all current)*
- [x] Document the fix and sync script location in the implementation summary *(completed: see summaries/01_opencode-routing-fix-summary.md)*

**Timing**: 15 minutes

**Depends on**: 3

**Files to modify**:
- None (validation only)

**Verification**:
- ProofChecker manifest discovery returns lean extension manifest
- Sync script `--check` exits 0
- All 6 child projects have identical routing commands to nvim source

---

## Testing & Validation

- [ ] ProofChecker: `git rev-parse --show-toplevel` returns correct project root, and `ls "$(git rev-parse --show-toplevel)/.opencode/extensions/"*/manifest.json` finds the lean manifest
- [ ] All 6 child projects: `grep "project_root" .opencode/commands/implement.md` succeeds
- [ ] All 6 child projects: `grep "COMMAND EXECUTION MODE" .opencode/commands/implement.md` succeeds
- [ ] Sync script `--check` mode exits 0 (no drift detected)
- [ ] Sync script `--dry-run` mode shows no changes needed

## Artifacts & Outputs

- 18 updated command files across 6 child projects (implement.md, research.md, plan.md)
- `/home/benjamin/.config/nvim/.opencode/scripts/sync-core-commands.sh` - New sync script
- 3 updated nvim canonical command files (with routing validation warning)
- `specs/572_diagnose_opencode_lean_routing_failure/summaries/01_opencode-routing-fix-summary.md` - Implementation summary

## Rollback/Contingency

To revert, restore the previous versions of implement.md, research.md, and plan.md in each child project from git history:

```bash
# In each affected child project:
cd /path/to/project
git checkout HEAD~1 -- .opencode/commands/implement.md .opencode/commands/research.md .opencode/commands/plan.md
```

For the sync script: simply delete `.opencode/scripts/sync-core-commands.sh`.

For the routing validation warning in nvim source: revert the specific warning block from the three nvim command files.
