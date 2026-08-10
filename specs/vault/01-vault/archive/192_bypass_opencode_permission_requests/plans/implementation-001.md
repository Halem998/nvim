# Implementation Plan: Task #192

- **Task**: 192 - bypass_opencode_permission_requests
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/192_bypass_opencode_permission_requests/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

This plan implements automatic permission bypass for opencode's permission prompts when accessing files in `/tmp/*`. The solution extends the existing PreToolUse hook system in `.opencode/settings.json` to add auto-allow logic for Read and Edit operations on `/tmp/*` paths. The current Write hook already auto-allows all write operations, but we will add explicit `/tmp/*` handling for consistency and clarity.

### Research Integration

The research identified that the PreToolUse hook mechanism is the correct approach for dynamic permission decisions. The `CLAUDE_TOOL_INPUT` environment variable provides tool arguments in JSON format, allowing hooks to inspect the file_path and return `{"permissionDecision": "allow"}` for `/tmp/*` paths. The current Write hook already returns `"allow"` for all operations, so Read and Edit hooks need to be added.

## Goals & Non-Goals

**Goals**:
- Add PreToolUse hook for Read tool to auto-allow `/tmp/*` access
- Add PreToolUse hook for Edit tool to auto-allow `/tmp/*` access
- Update Write hook to include explicit `/tmp/*` handling for consistency
- Ensure proper JSON escaping in all bash commands
- Validate configuration is valid JSON
- Test that permission prompts are bypassed for `/tmp/*` operations

**Non-Goals**:
- Bypassing permission prompts for directories other than `/tmp/*`
- Modifying the permissions.allow array (already allows all tools)
- Changing PostToolUse or other hook types
- Removing existing state.json validation in Write hook

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON escaping errors causing invalid configuration | High - opencode won't start | Medium | Validate JSON after each edit using `jq` tool |
| Overly permissive hooks allowing unintended access | Medium - security risk | Low | Strict pattern matching `[[ "$FILE" == /tmp/* ]]` |
| Hook execution failures falling back to prompts | Low - original behavior preserved | Low | Add `|| echo '{"permissionDecision":"ask"}'` fallback |
| Unintended modification of other PreToolUse hooks | Medium - could break existing functionality | Low | Careful editing, backup before changes |
| Breaking state.json validation in Write hook | Medium - workflow disruption | Low | Preserve existing logic, add `/tmp/*` as additional branch |

## Implementation Phases

### Phase 1: Backup and Prepare [NOT STARTED]

**Goal**: Create a backup of the current settings.json before modifications

**Tasks**:
- [ ] Read current `.opencode/settings.json` to understand exact structure
- [ ] Create backup at `.opencode/settings.json.backup`
- [ ] Verify backup is valid by reading it back
- [ ] Document current PreToolUse hook structure

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/settings.json.backup` - create new backup file

**Verification**:
- Backup file exists and is valid JSON
- Original settings.json unchanged
- Backup contains current Write hook configuration

---

### Phase 2: Add Read Tool Hook for /tmp/* Auto-Allow [NOT STARTED]

**Goal**: Add PreToolUse hook for Read tool that auto-allows `/tmp/*` paths

**Tasks**:
- [ ] Add new hook entry to `hooks.PreToolUse` array (before Write hook)
- [ ] Configure matcher as `"Read"`
- [ ] Add command that extracts file_path from CLAUDE_TOOL_INPUT
- [ ] Implement bash logic: if file starts with `/tmp/`, return `{"permissionDecision": "allow"}`, else return `{"permissionDecision": "ask"}`
- [ ] Include `permissionDecisionReason` for `/tmp/*` matches

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/settings.json` - add Read hook to hooks.PreToolUse array

**Hook Command Structure**:
```bash
bash -c 'FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null); if [[ "$FILE" == /tmp/* ]]; then echo "{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"Auto-allowed /tmp access\"}"; else echo "{\"permissionDecision\": \"ask\"}"; fi'
```

**Verification**:
- JSON is valid (test with `cat .opencode/settings.json | jq .`)
- Read hook is properly nested in PreToolUse array
- Hook command has correct escaping for quotes and special characters

---

### Phase 3: Update Write Tool Hook to Handle /tmp/* [NOT STARTED]

**Goal**: Modify existing Write hook to explicitly handle `/tmp/*` paths while preserving state.json logic

**Tasks**:
- [ ] Read current Write hook command
- [ ] Modify bash logic to add `/tmp/*` check as separate elif branch
- [ ] Preserve existing state.json check logic
- [ ] Update final else branch to remain `"allow"` (current behavior)
- [ ] Ensure proper JSON escaping throughout

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/settings.json` - modify existing Write hook command

**Updated Hook Logic**:
```bash
if [[ "$FILE" == *"specs/state.json"* ]]; then
  echo "{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"State file write\"}";
elif [[ "$FILE" == /tmp/* ]]; then
  echo "{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"Auto-allowed /tmp access\"}";
else
  echo "{\"permissionDecision\": \"allow\"}";
fi
```

**Verification**:
- JSON is valid
- State.json logic preserved
- `/tmp/*` check added as elif branch
- Else branch still returns `"allow"`

---

### Phase 4: Add Edit Tool Hook for /tmp/* Auto-Allow [NOT STARTED]

**Goal**: Add PreToolUse hook for Edit tool that auto-allows `/tmp/*` paths

**Tasks**:
- [ ] Add new hook entry to `hooks.PreToolUse` array (after Write hook)
- [ ] Configure matcher as `"Edit"`
- [ ] Add command that extracts file_path from CLAUDE_TOOL_INPUT
- [ ] Implement bash logic: if file starts with `/tmp/`, return `{"permissionDecision": "allow"}`, else return `{"permissionDecision": "ask"}`
- [ ] Include `permissionDecisionReason` for `/tmp/*` matches

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/settings.json` - add Edit hook to hooks.PreToolUse array

**Hook Command Structure** (same as Read):
```bash
bash -c 'FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null); if [[ "$FILE" == /tmp/* ]]; then echo "{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"Auto-allowed /tmp access\"}"; else echo "{\"permissionDecision\": \"ask\"}"; fi'
```

**Verification**:
- JSON is valid
- Edit hook is properly nested in PreToolUse array
- Hook command has correct escaping for quotes and special characters

---

### Phase 5: Validate JSON Configuration [NOT STARTED]

**Goal**: Ensure final settings.json is valid JSON and properly structured

**Tasks**:
- [ ] Run JSON validation: `cat .opencode/settings.json | jq .`
- [ ] Verify all PreToolUse hooks are valid JSON objects
- [ ] Check that each hook has required fields: `matcher`, `hooks` array with `type` and `command`
- [ ] Verify no syntax errors in bash commands (check escaping)
- [ ] Compare final structure with expected format

**Timing**: 15 minutes

**Files to modify**:
- None (validation only)

**Verification Criteria**:
- [ ] `jq .` returns valid JSON without errors
- [ ] All PreToolUse entries have matcher and hooks
- [ ] All hook commands are properly escaped strings
- [ ] JSON structure matches expected schema

---

### Phase 6: Test Permission Bypass [NOT STARTED]

**Goal**: Verify that Read, Write, and Edit operations on `/tmp/*` no longer prompt for permission

**Tasks**:
- [ ] Create test file: `/tmp/test_permission_bypass.txt`
- [ ] Test Read operation: verify no permission prompt for `/tmp/test_permission_bypass.txt`
- [ ] Test Write operation: verify no permission prompt for `/tmp/test_permission_bypass.txt`
- [ ] Test Edit operation: verify no permission prompt for `/tmp/test_permission_bypass.txt`
- [ ] Verify non-/tmp paths still prompt (if not in allow list)
- [ ] Clean up test file

**Timing**: 30 minutes

**Files to modify**:
- `/tmp/test_permission_bypass.txt` - temporary test file (created and deleted)

**Test Commands**:
1. Read test: Read file at `/tmp/test_permission_bypass.txt`
2. Write test: Write to `/tmp/test_permission_bypass.txt`
3. Edit test: Edit `/tmp/test_permission_bypass.txt`

**Verification Criteria**:
- [ ] Read on `/tmp/*` files shows no permission dialog
- [ ] Write on `/tmp/*` files shows no permission dialog
- [ ] Edit on `/tmp/*` files shows no permission dialog
- [ ] Operations complete successfully without user intervention

---

## Testing & Validation

- [ ] Phase 1: Backup file exists and is valid JSON
- [ ] Phase 2: Read hook added and JSON is valid
- [ ] Phase 3: Write hook updated with `/tmp/*` handling
- [ ] Phase 4: Edit hook added and JSON is valid
- [ ] Phase 5: Full JSON validation passes with `jq`
- [ ] Phase 6: All `/tmp/*` operations bypass permission prompts
- [ ] No regression: state.json validation still works
- [ ] No regression: other hooks (PostToolUse, SessionStart, etc.) unchanged

## Artifacts & Outputs

- `.opencode/settings.json.backup` - Backup of original configuration
- `.opencode/settings.json` - Modified configuration with new hooks
- Test file `/tmp/test_permission_bypass.txt` (temporary, deleted after testing)

## Rollback/Contingency

**If implementation fails**:
1. Restore from backup: `cp .opencode/settings.json.backup .opencode/settings.json`
2. Verify restoration: `cat .opencode/settings.json | jq .`
3. Remove backup file: `rm .opencode/settings.json.backup`

**If hooks cause issues**:
1. Remove specific hook causing problems from PreToolUse array
2. Keep other hooks intact
3. Test incremental changes

**If JSON becomes invalid**:
1. Use backup to restore
2. Manually fix specific escaping issues
3. Validate each change with `jq` before proceeding

## Notes

### Hook Order in PreToolUse Array

The order of hooks in the PreToolUse array doesn't affect functionality since each has a different matcher. However, for consistency and readability, the recommended order is:
1. Read hook
2. Write hook
3. Edit hook

### Current Write Hook Behavior

The existing Write hook already auto-allows all write operations (the else branch returns `"allow"`). Adding explicit `/tmp/*` handling in Phase 3 is for consistency and to provide a specific `permissionDecisionReason` for `/tmp/*` operations.

### JSON Escaping Reference

When escaping JSON in bash commands within JSON:
- `"` becomes `\"` in the JSON string
- `$` variables need to be escaped as `$` (not `\$`)
- Single quotes `'` in bash become `'` in JSON (no escaping needed)

Example:
```json
"command": "bash -c 'echo \"{\\\"key\\\": \\\"value\\\"}\"'"
```

This results in bash receiving: `echo "{"key": "value"}"`

### Permission Decision Values

- `"allow"` - Grant permission without prompting
- `"deny"` - Deny permission without prompting
- `"ask"` - Show permission dialog (default behavior)

For `/tmp/*` paths, we use `"allow"`. For all other paths in Read/Edit hooks, we use `"ask"` to preserve normal behavior.
