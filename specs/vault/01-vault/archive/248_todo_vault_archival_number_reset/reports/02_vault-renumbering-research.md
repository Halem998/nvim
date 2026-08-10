# Research Report: Task #248

**Task**: 248 - Implement vault archival and number reset in /todo when tasks exceed 1000
**Started**: 2026-03-19
**Completed**: 2026-03-19
**Effort**: 3-5 hours
**Dependencies**: None
**Sources/Inputs**: skill-todo/SKILL.md, state.json, TODO.md, state-template.json, state-json-schema.md
**Artifacts**: specs/248_todo_vault_archival_number_reset/reports/02_vault-renumbering-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The vault operation involves moving the entire archive to a vault, renumbering active tasks > 1000, and resetting numbering
- Five components need modification: skill-todo, state.json schema, directory operations, TODO.md updates, and task command
- The state template already includes `project_numbering.policy: "increment_modulo_1000"` suggesting this was anticipated
- Key complexity: Renumbering active tasks requires updating state.json, TODO.md, and renaming task directories

## Context and Scope

**What was researched**:
- Current skill-todo archival workflow (16 stages)
- state.json schema and structure
- TODO.md entry format
- Archive directory structure
- Directory naming conventions (3-digit padding)

**Constraints**:
- Must maintain state.json/TODO.md synchronization
- Must preserve task artifacts during renumbering
- Must handle both padded (NNN) and unpadded directory names
- Must update all artifact references in state.json when renumbering

## Findings

### Current State Schema

The state.json currently tracks:
```json
{
  "next_project_number": 249,
  "active_projects": [...],
  "repository_health": {...}
}
```

The state template (state-template.json) already includes:
```json
{
  "project_numbering": {
    "min": 0,
    "max": 999,
    "policy": "increment_modulo_1000"
  }
}
```

This indicates vault/rollover was anticipated but not implemented.

### Current Archive Structure

```
specs/
  state.json                     # active tasks
  TODO.md                        # user-facing task list
  archive/
    state.json                   # completed_projects array
    {NNN}_{slug}/                # task directories
```

### Proposed Vault Structure

```
specs/
  state.json                     # active tasks (with vault_history)
  TODO.md                        # user-facing task list
  vault/
    01-vault/
      archive/                   # former specs/archive contents
      state.json                 # former specs/archive/state.json
      meta.json                  # vault metadata (task range, created_at)
    02-vault/
      ...
  archive/
    state.json                   # fresh, empty
```

### Vault Operation Flow

When `next_project_number > 1000` is detected after normal /todo archival:

**Phase 1: Pre-Vault Preparation**
1. Archive all completed/abandoned tasks through number 1000 (normal archival)
2. Identify tasks > 1000 that are still active

**Phase 2: User Confirmation**
```
Task numbering has reached {N}.
Active tasks > 1000 will be renumbered:
  - Task 1001 -> Task 1
  - Task 1003 -> Task 3

Vault {M} archived tasks?
Options: Yes (vault and reset), No (skip for now)
```

**Phase 3: Create Vault**
1. Create `specs/vault/{NN-vault}/` directory
2. Move entire `specs/archive/` contents to `specs/vault/{NN-vault}/archive/`
3. Move `specs/archive/state.json` to `specs/vault/{NN-vault}/state.json`
4. Create `specs/vault/{NN-vault}/meta.json` with vault metadata:
   ```json
   {
     "vault_number": 1,
     "created_at": "2026-03-19T...",
     "task_range": "1-999",
     "archived_count": 847,
     "last_task_number": 1000
   }
   ```

**Phase 4: Renumber Active Tasks > 1000**

For each active task with `project_number > 1000`:
1. Calculate new number: `new_number = project_number - 1000`
2. Update state.json entry:
   - `project_number` -> new_number
   - Update all artifact paths: `specs/{old_NNN}_{slug}/` -> `specs/{new_NNN}_{slug}/`
3. Update TODO.md entry:
   - Header: `### 1003. Title` -> `### 3. Title`
   - All artifact links
4. Rename directory: `specs/1003_{slug}/` -> `specs/003_{slug}/`

**Phase 5: Reset Numbering**
1. Set `next_project_number = max(renumbered tasks) + 1`
   - If tasks 1001, 1003, 1004 existed: set to 5 (not 1)
2. Update `vault_count` and `vault_history` in state.json
3. Reinitialize fresh `specs/archive/` with empty state

**Phase 6: Add Vault Header to TODO.md**
```markdown
---
next_project_number: 5
vault_count: 1
---

# TODO

<!-- Vault transition: 2026-03-19 - Tasks 1-999 archived to specs/vault/01-vault/ -->

## Tasks
```

### State Schema Extensions

Add to state.json:
```json
{
  "next_project_number": 5,
  "vault_count": 1,
  "vault_history": [
    {
      "vault_number": 1,
      "vault_dir": "specs/vault/01-vault/",
      "created_at": "2026-03-19T...",
      "task_range": "1-999",
      "archived_count": 847,
      "final_task_number": 1000
    }
  ],
  "active_projects": [...]
}
```

### Files Requiring Modification

| File | Type of Change |
|------|----------------|
| `.claude/skills/skill-todo/SKILL.md` | Add vault detection/execution stages |
| `.claude/commands/todo.md` | Add vault documentation |
| `.claude/rules/state-management.md` | Document vault schema |
| `.claude/context/core/templates/state-template.json` | Add vault_count, vault_history |
| `.claude/context/core/reference/state-json-schema.md` | Document vault fields |

### skill-todo Modifications

New stages to add (after existing Stage 10 ArchiveTasks):

**Stage 10.5: Detect Vault Threshold**
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  vault_needed=true
  # Identify active tasks > 1000
  active_over_1000=$(jq -r '.active_projects[] | select(.project_number > 1000) | .project_number' specs/state.json)
fi
```

**Stage 10.6: Vault User Confirmation**
```json
{
  "question": "Task numbering has reached {N}. Create vault and renumber?",
  "header": "Vault Operation",
  "multiSelect": false,
  "options": [
    {"label": "Yes, create vault", "description": "Archive current archive to vault, renumber tasks > 1000"},
    {"label": "No, skip", "description": "Continue without vault operation"}
  ]
}
```

**Stage 10.7: Execute Vault Operation**
- Create vault directory structure
- Move archive contents
- Create vault metadata

**Stage 10.8: Renumber Active Tasks**
- For each task > 1000:
  - Calculate new_number = project_number - 1000
  - Update state.json entry
  - Update TODO.md entry
  - Rename directory
  - Update all artifact path references

**Stage 10.9: Reset State**
- Set next_project_number to max(renumbered) + 1
- Update vault_count and vault_history
- Reinitialize archive/state.json

### Directory Renaming Details

Critical consideration for directory naming:
- Task 1001 with slug `foo_bar` has directory `specs/1001_foo_bar/` (4-digit)
- After renumbering to 1, directory becomes `specs/001_foo_bar/` (3-digit padded)
- Must handle both padded and unpadded source directories

```bash
old_padded=$(printf "%04d" "$old_number")  # For numbers > 999
new_padded=$(printf "%03d" "$new_number")  # Standard 3-digit

# Find source directory
if [ -d "specs/${old_padded}_${slug}" ]; then
  src="specs/${old_padded}_${slug}"
elif [ -d "specs/${old_number}_${slug}" ]; then
  src="specs/${old_number}_${slug}"
fi

# Rename to standard format
mv "$src" "specs/${new_padded}_${slug}"
```

### Artifact Path Updates

When renumbering task 1003 -> 3, update all artifact paths in state.json:
```json
{
  "artifacts": [
    {
      "path": "specs/1003_slug/reports/01_research.md"  // Old
      "path": "specs/003_slug/reports/01_research.md"   // New
    }
  ]
}
```

Use jq to update:
```bash
jq --arg old "specs/1003_" --arg new "specs/003_" \
  '(.active_projects[] | select(.project_number == 3) | .artifacts[].path) |= gsub($old; $new)' \
  specs/state.json
```

### TODO.md Updates for Renumbering

Update task header:
```markdown
### 1003. Fix some bug           # Old
### 3. Fix some bug              # New
```

Update artifact links:
```markdown
- **Research**: [01_research.md](1003_fix_bug/reports/01_research.md)     # Old
- **Research**: [01_research.md](003_fix_bug/reports/01_research.md)      # New
```

### Edge Cases

1. **No tasks > 1000**: Vault operation proceeds but no renumbering needed
2. **Gaps in numbering**: Tasks 1001, 1003, 1004 become 1, 3, 4 - gaps preserved
3. **Dependencies between tasks > 1000**: Must update dependency arrays too
4. **Tasks with OpenCode prefix**: `OC_1003_slug` becomes `OC_003_slug`

### Dependencies Update

If task 1004 depends on task 1002:
```json
{
  "project_number": 4,          // Was 1004
  "dependencies": [2]           // Was [1002]
}
```

## Recommendations

### Implementation Order

1. **Phase 1**: Add vault schema fields to state-template.json and state-json-schema.md
2. **Phase 2**: Add vault detection stage (10.5) to skill-todo
3. **Phase 3**: Add vault execution stages (10.6-10.7) without renumbering
4. **Phase 4**: Add renumbering stages (10.8-10.9)
5. **Phase 5**: Add TODO.md vault header update
6. **Phase 6**: Update documentation in commands/todo.md and rules/

### Testing Strategy

1. Create test state with next_project_number = 1005
2. Create mock active tasks 1001, 1003, 1004
3. Run vault operation
4. Verify:
   - Vault directory created correctly
   - Archive moved to vault
   - Tasks renumbered to 1, 3, 4
   - next_project_number set to 5
   - Directories renamed
   - Artifact paths updated
   - TODO.md entries updated
   - Dependencies updated

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Directory rename failure | Lost task artifacts | Validate source exists before rename |
| Artifact path mismatch | Broken links | Use atomic jq updates, validate paths |
| Dependencies broken | Invalid references | Update dependencies in same transaction |
| Partial completion | Inconsistent state | Implement as transaction with rollback |
| Race condition | State corruption | Lock state files during vault operation |

## Context Extension Recommendations

- none (meta task)

## Appendix

### Search Queries Used

- Grep for `next_project_number` in .claude/
- Grep for `vault` in .claude/
- Read skill-todo/SKILL.md structure
- Read state-template.json for schema hints

### Key Files Analyzed

- `/home/benjamin/.config/nvim/.claude/skills/skill-todo/SKILL.md` - 556 lines, 16 stages
- `/home/benjamin/.config/nvim/specs/state.json` - 1566 lines, 46 active projects
- `/home/benjamin/.config/nvim/specs/archive/state.json` - ~200 completed projects
- `/home/benjamin/.config/nvim/.claude/context/core/templates/state-template.json` - Schema template

### Existing Infrastructure

The state template already has `project_numbering.policy: "increment_modulo_1000"` which indicates this feature was anticipated during initial design. The vault operation completes this vision.
