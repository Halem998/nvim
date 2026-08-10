# Implementation Plan: Task #192

- **Task**: 192 - bypass_opencode_permission_requests
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/192_bypass_opencode_permission_requests/reports/research-001.md; specs/192_bypass_opencode_permission_requests/reports/research-002.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md; .opencode/context/core/standards/status-markers.md; .opencode/context/core/standards/documentation-standards.md; .opencode/context/core/standards/task-management.md
- **Type**: meta

## Overview

This plan migrates all `/tmp/` references in the `.claude/` system to use `specs/tmp/` instead, eliminating the need to bypass permission requests for external `/tmp/` directory access. The `specs/tmp/` directory already exists and is already used successfully by the `.opencode/` system (completed in task OC_156). This approach is cleaner and more maintainable than adding PreToolUse hooks to auto-allow `/tmp/` access.

The migration affects approximately 161 occurrences across 30+ files including commands, scripts, skills, hooks, and documentation. The work follows the same successful pattern used for the `.opencode/` migration.

### Research Integration

**Research-001.md (Original Approach)**:
Investigated PreToolUse hook mechanism for auto-allowing `/tmp/*` access. Found that hooks can return `{"permissionDecision": "allow"}` to bypass permission prompts. Identified that Write operations are already auto-allowed, but Read and Edit operations would need additional hooks for `/tmp/*` paths.

**Research-002.md (Recommended Approach)**:
Discovered that task OC_156 already migrated `.opencode/` to use `specs/tmp/`. Found 161 remaining `/tmp/` occurrences in `.claude/` files that need migration. The `specs/tmp/` directory exists and is user-owned. Recommended direct path substitution as the cleaner solution.

**Decision**: Adopt the specs/tmp/ migration approach (Research-002) as the primary solution. This avoids permission complexity entirely by using a workspace-local temporary directory.

## Goals & Non-Goals

**Goals**:
- Migrate all `/tmp/` references in `.claude/` commands to `specs/tmp/`
- Migrate all `/tmp/` references in `.claude/` scripts to `specs/tmp/`
- Migrate all `/tmp/` references in `.claude/` skills to `specs/tmp/`
- Migrate all `/tmp/` references in `.claude/` hooks to `specs/tmp/`
- Update documentation to reflect the new pattern
- Verify no permission prompts occur after migration
- Maintain atomic file operations during the migration

**Non-Goals**:
- Modifying files outside `.claude/` directory
- Changing any logic or functionality (only path changes)
- Adding PreToolUse hooks (alternative approach, not needed)
- Migrating system-level temporary files
- Creating new temporary file conventions (follow existing pattern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed occurrences of `/tmp/` | Medium - incomplete migration | Medium | Comprehensive grep search before and after; use find with multiple file extensions |
| Wrong path references in nested commands | Medium - broken functionality | Low | Test each command after migration; verify paths are absolute or correctly relative |
| Breaking concurrent file access | Low - atomicity issues | Low | `specs/tmp/` maintains same atomic semantics as `/tmp/` |
| Documentation inconsistencies | Low - confusing examples | Medium | Update all example code in docs; grep for remaining `/tmp/state.json` references |
| Accidentally modifying wrong files | Medium - system damage | Low | Use version control; review all changes before committing; backup first |
| Path resolution in hooks/scripts | Medium - runtime errors | Low | Test hooks and scripts individually after migration |

## Implementation Phases

### Phase 1: Backup and Inventory [NOT STARTED]

**Goal**: Create backup of affected files and complete inventory of all `/tmp/` references

**Tasks**:
- [ ] Run comprehensive grep to find all `/tmp/` occurrences in `.claude/`
- [ ] Create list of files to modify, grouped by priority
- [ ] Backup all files that will be modified
- [ ] Verify `specs/tmp/` directory exists and is writable
- [ ] Document current state for rollback purposes

**Timing**: 45 minutes

**Files to modify**:
- Create backup archive of `.claude/` directory

**Verification**:
- Backup archive exists and is restorable
- File inventory is complete (161 occurrences found)
- `specs/tmp/` exists and has correct permissions (drwxr-xr-x)

---

### Phase 2: Migrate Core Commands [NOT STARTED]

**Goal**: Update the most frequently used command files

**Tasks**:
- [ ] Update `.claude/commands/task.md` (9 occurrences of `/tmp/`)
  - Replace `/tmp/state.json` with `specs/tmp/state.json`
  - Replace jq temp file patterns
- [ ] Update `.claude/commands/todo.md` (3 occurrences)
  - Replace temp jq script patterns like `/tmp/todo_nonmeta_$$.jq`
- [ ] Update `.claude/commands/implement.md` (1 occurrence)
- [ ] Update `.claude/commands/revise.md` (2 occurrences)
- [ ] Validate each file still follows command documentation standards

**Timing**: 1.5 hours

**Files to modify**:
- `.claude/commands/task.md`
- `.claude/commands/todo.md`
- `.claude/commands/implement.md`
- `.claude/commands/revise.md`

**Verification**:
- All 15 occurrences in command files updated
- Commands can be parsed without errors
- No remaining `/tmp/` references in command files

---

### Phase 3: Migrate Scripts [NOT STARTED]

**Goal**: Update postflight scripts and other shell scripts

**Tasks**:
- [ ] Update `.claude/scripts/postflight-research.sh` (3 occurrences)
- [ ] Update `.claude/scripts/postflight-plan.sh` (3 occurrences)
- [ ] Update `.claude/scripts/postflight-implement.sh` (3 occurrences)
- [ ] Check `.claude/scripts/install-extension.sh` for `/tmp/` usage
- [ ] Check `.claude/scripts/uninstall-extension.sh` for `/tmp/` usage
- [ ] Ensure all `mv` operations maintain atomic file semantics

**Timing**: 1 hour

**Files to modify**:
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/postflight-plan.sh`
- `.claude/scripts/postflight-implement.sh`
- `.claude/scripts/install-extension.sh` (if needed)
- `.claude/scripts/uninstall-extension.sh` (if needed)

**Verification**:
- Scripts are executable after modifications
- All `/tmp/` references replaced with `specs/tmp/`
- Test each script with `--help` or dry-run if available

---

### Phase 4: Migrate Skills [NOT STARTED]

**Goal**: Update skill definitions in SKILL.md files

**Tasks**:
- [ ] Update `.claude/skills/skill-researcher/SKILL.md` (5 occurrences)
- [ ] Update `.claude/skills/skill-implementer/SKILL.md` (4 occurrences)
- [ ] Update `.claude/skills/skill-planner/SKILL.md` (3 occurrences)
- [ ] Update `.claude/skills/skill-status-sync/SKILL.md` (3 occurrences)
- [ ] Verify skill examples still demonstrate correct patterns

**Timing**: 1 hour

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-status-sync/SKILL.md`

**Verification**:
- All 15 occurrences in skills updated
- Skill documentation is coherent
- Examples use correct paths

---

### Phase 5: Migrate Hooks [NOT STARTED]

**Goal**: Update runtime hook files

**Tasks**:
- [ ] Update `.claude/hooks/tts-notify.sh` (3 occurrences)
  - Replace `/tmp/claude-tts-last-notify`
  - Replace `/tmp/claude-tts-notify.log`
  - Replace `/tmp/claude-tts-$$.wav`
- [ ] Verify hook still functions correctly after path changes

**Timing**: 30 minutes

**Files to modify**:
- `.claude/hooks/tts-notify.sh`

**Verification**:
- Hook file is executable
- All 3 `/tmp/` references updated
- Hook can be sourced without errors

---

### Phase 6: Migrate Extensions [NOT STARTED]

**Goal**: Update extension-specific skill files

**Tasks**:
- [ ] Update `.claude/extensions/web/skills/skill-web-research/SKILL.md`
- [ ] Update `.claude/extensions/web/skills/skill-web-implementation/SKILL.md`
- [ ] Update `.claude/extensions/nix/skills/skill-nix-research/SKILL.md`
- [ ] Update `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- [ ] Update `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- [ ] Update `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- [ ] Update `.claude/extensions/lean/skills/skill-lean-research/SKILL.md`
- [ ] Update `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md`

**Timing**: 1 hour

**Files to modify**:
- All 8 extension skill files listed above

**Verification**:
- All occurrences in extension files updated
- Extension skill examples are correct

---

### Phase 7: Update Context Documentation [NOT STARTED]

**Goal**: Update pattern and workflow documentation to reflect new paths

**Tasks**:
- [ ] Update `.claude/context/core/patterns/inline-status-update.md`
- [ ] Update `.claude/context/core/patterns/jq-escaping-workarounds.md`
- [ ] Update `.claude/context/core/patterns/file-metadata-exchange.md`
- [ ] Update `.claude/context/core/patterns/postflight-control.md`
- [ ] Update `.claude/context/core/orchestration/preflight-pattern.md`
- [ ] Update `.claude/context/core/orchestration/postflight-pattern.md`
- [ ] Update `.claude/context/core/workflows/preflight-postflight.md`
- [ ] Update `.claude/context/project/processes/research-workflow.md`
- [ ] Update `.claude/context/project/processes/planning-workflow.md`
- [ ] Update `.claude/context/project/processes/implementation-workflow.md`

**Timing**: 1.5 hours

**Files to modify**:
- 10 documentation files listed above

**Verification**:
- All example code uses `specs/tmp/` instead of `/tmp/`
- Documentation is internally consistent
- No `/tmp/state.json` references remain in docs

---

### Phase 8: Verification and Testing [NOT STARTED]

**Goal**: Verify complete migration and test that no permission prompts occur

**Tasks**:
- [ ] Run comprehensive grep to confirm zero remaining `/tmp/` references in `.claude/`
- [ ] Test command: `/task --sync` (uses state.json operations)
- [ ] Test command: `/research 1 test` (if task 1 exists)
- [ ] Test command: `/plan 1` (if task 1 exists)
- [ ] Verify no permission prompts appear during operations
- [ ] Verify temporary files are created in `specs/tmp/`
- [ ] Check that `specs/tmp/` files are properly cleaned up after operations
- [ ] Validate all modified files are syntactically correct

**Timing**: 1 hour

**Files to modify**:
- None (verification only)

**Verification**:
- Zero `/tmp/` references remain in `.claude/` (excluding documentation about external systems)
- No permission prompts during test operations
- Files are created in correct location (`specs/tmp/`)
- System functions normally after migration

---

## Testing & Validation

- [ ] Phase 1: Complete inventory with 161 occurrences documented
- [ ] Phase 2: All 15 command file occurrences migrated
- [ ] Phase 3: All 9+ script occurrences migrated
- [ ] Phase 4: All 15 skill occurrences migrated
- [ ] Phase 5: All 3 hook occurrences migrated
- [ ] Phase 6: All ~60 extension occurrences migrated
- [ ] Phase 7: All ~40 documentation occurrences updated
- [ ] Phase 8: Zero remaining `/tmp/` references in `.claude/`
- [ ] No permission prompts during normal operations
- [ ] Commands work correctly: `/task`, `/research`, `/plan`, `/implement`
- [ ] Scripts execute without errors: postflight scripts, hooks
- [ ] Atomic file operations preserved (temp file + mv pattern)
- [ ] Rollback plan tested and functional

## Artifacts & Outputs

- `.claude/` directory with all `/tmp/` references migrated to `specs/tmp/`
- Backup archive of original `.claude/` state
- Migration log documenting all files modified
- Verification report showing zero remaining `/tmp/` references
- Updated documentation reflecting new temporary file conventions

## Rollback/Contingency

**If migration causes issues**:
1. Stop all operations and assess the issue
2. Restore from backup: Extract backup archive to restore original `.claude/` state
3. Verify restoration: Run commands to ensure they work as before
4. Remove backup after confirming stability

**If specific files cause problems**:
1. Restore only the problematic files from backup
2. Investigate the specific issue with those files
3. Fix and retry migration for those specific files
4. Keep other migrated files intact

**If permission prompts still appear**:
1. Check that `specs/tmp/` has correct permissions (755, user-owned)
2. Verify files are actually being created in `specs/tmp/`
3. Check for any remaining `/tmp/` references that were missed
4. Consider the PreToolUse hook approach as fallback (from Research-001)

**If atomic file operations break**:
1. Verify `specs/tmp/` is on the same filesystem as the target files
2. Check that `mv` operations use correct paths
3. Ensure temp files are created in correct location before move

## Alternative Approach (Fallback)

If the specs/tmp/ migration proves problematic, the alternative approach from Research-001 remains viable:

**PreToolUse Hook Approach**:
Add hooks to `.opencode/settings.json` to auto-allow `/tmp/*` access:
- Add Read hook with matcher checking for `/tmp/*` paths
- Add Edit hook with matcher checking for `/tmp/*` paths
- Write hook already auto-allows all operations

This approach requires modifying `.opencode/settings.json` instead of 30+ files in `.claude/`, but adds ongoing complexity with hook maintenance.

## Notes

### Migration Pattern

The standard pattern being migrated:
```bash
# Before:
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# After:
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Historical Context

This migration follows the successful pattern established in task OC_156, which migrated the `.opencode/` system from `/tmp/` to `specs/tmp/`. The `.opencode/` migration handled 85+ occurrences and has been running without issues.

### Why Not TMPDIR?

Setting `TMPDIR=specs/tmp` was considered but rejected because:
- Not all tools respect TMPDIR
- Requires setting environment variable before every command
- Inconsistent behavior across different tools
- More complex to implement reliably than path substitution

### Post-Migration

After this migration is complete, all agent systems (both `.opencode/` and `.claude/`) will use `specs/tmp/` for temporary files. Future development should follow this convention and never use `/tmp/` for agent-related temporary files.