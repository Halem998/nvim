# Research Report: Port update-task-status.sh Phase 3

- **Task**: 581 - Port update-task-status.sh Phase 3 rewrite from ProofChecker
- **Started**: 2026-05-15T20:00:00Z
- **Completed**: 2026-05-15T20:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 579 (generate-task-order.sh port), Task 580 (topic schema + state-management rules)
- **Sources/Inputs**:
  - Codebase
    - `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (current nvim-config version)
    - `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (ported by task 579)
    - `/home/benjamin/.config/nvim/.claude/rules/state-management.md` (updated by task 580)
  - ProofChecker source
    - `/home/benjamin/Projects/ProofChecker/.claude/scripts/update-task-status.sh` (Phase 3 two-mode source)
    - `/home/benjamin/Projects/ProofChecker/specs/150_task_order_auto_sync/reports/01_task-order-auto-sync.md`
    - `/home/benjamin/Projects/ProofChecker/specs/150_task_order_auto_sync/plans/01_task-order-auto-sync.md`
- **Artifacts**:
  - `specs/581_port_status_script_phase3/reports/01_port-status-phase3.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- The current nvim-config Phase 3 uses the old flat-list pattern that searched for `^- \*\*${N}\*\* \[` entries, which matches the old `## Recommended Order` format, not the new wave+tree format from `generate-task-order.sh`.
- The ProofChecker Phase 3 has a fully implemented two-mode strategy: Mode B (terminal transitions → full regeneration via `generate-task-order.sh --update-todo`) and Mode A (non-terminal transitions → in-place `sed` on tree lines using the `^\s*(└─ )?${N} \[` pattern).
- Mode A's tree pattern correctly matches entries at any indent depth: root-level (`148 [RESEARCHED] — ...`) and indented (`  └─ 147 [RESEARCHED] — ...`).
- Mode A includes a fallback to Mode B when the task is not found in the tree, using a non-fatal `generate-task-order.sh` call with `2>/dev/null`.
- Phase 5 in the nvim-config script is entirely nvim-config-specific (TTS, WezTerm tab colors, OpenCode session renaming) and has no counterpart in ProofChecker; it must be preserved verbatim.
- The implementation task is a targeted replacement of the Phase 3 function body only — no other phases or script structure change.

## Context & Scope

Task 579 ported `generate-task-order.sh` (the script Mode B calls). Task 580 ported the topic schema and updated `state-management.md` to document the Task Order Synchronization section including the two-mode strategy. This task (581) completes the Phase 3 rewrite in `update-task-status.sh` to match the ProofChecker implementation.

The nvim-config `update-task-status.sh` was written before the wave+tree Task Order format was finalized. Its Phase 3 searches for the old flat-list format (`^- **N** [STATUS]`) and has no Mode A/Mode B dispatch. The ProofChecker implementation is the reference for the correct Phase 3 after ProofChecker task 150 completed it.

## Findings

### Current Phase 3 in nvim-config (Before Port)

The current `update_todo_task_order()` function (lines 232–265) uses a single strategy:

1. Searches for `^- \*\*${task_number}\*\* \[` pattern (old flat-list format)
2. If not found: prints warning, returns 0 (no-op, no fallback)
3. If found: extracts current status with `sed 's/.*\[\([^]]*\)\].*/\1/'` and replaces with `sed -i`

This pattern matches the old `## Recommended Order` flat-list format (`- **148** [RESEARCHED] — desc`), not the wave+tree format produced by `generate-task-order.sh`. The tree format entries look like:
- Root: `148 [RESEARCHED] — description` (no leading `- **`)
- Indented: `  └─ 147 [RESEARCHED] — description`

Result: Phase 3 currently silently no-ops on all status changes because the pattern never matches the new tree format. The Task Order section is never updated by `update-task-status.sh` in the current nvim-config.

### ProofChecker Phase 3 (Source for Port)

The ProofChecker `update_todo_task_order()` function implements:

**Mode B dispatch (terminal transitions):**
- Condition: `$TODO_STATUS == "COMPLETED" || $TODO_STATUS == "ABANDONED" || $TODO_STATUS == "EXPANDED"`
- Action: Calls `generate-task-order.sh --update-todo "$TODO_FILE" "$STATE_FILE"` for full regeneration
- Dry-run: Prints `[dry-run] TODO.md Task Order: terminal status $TODO_STATUS -> would run generate-task-order.sh --update-todo`
- Non-fatal: `|| { echo "Warning: generate-task-order.sh failed (non-fatal)" >&2 }`
- Returns 0 after regeneration

**Mode A (non-terminal transitions):**
- Pattern: `grep -n -E "^\s*(└─ )?${task_number} \["` — matches tree lines at any indent depth
- Status extraction: `grep -oE '\[([A-Z ]+)\]' | head -1 | tr -d '[]'` — more robust than the old `sed` extraction, handles multi-word statuses like `NOT STARTED`
- Dry-run: Prints line number and status transition
- Replace: `sed -i "${order_line}s/\[${current_order_status}\]/[${TODO_STATUS}]/"`

**Mode A fallback to Mode B (task not found in tree):**
- Trigger: `order_line` is empty after the grep
- Action: Warning message + non-fatal call to `generate-task-order.sh --update-todo "$TODO_FILE" "$STATE_FILE" 2>/dev/null`
- Dry-run: Prints `[dry-run] TODO.md Task Order: task not in tree, would run generate-task-order.sh --update-todo`
- Returns 0

### Conditions for Mode A vs Mode B Dispatch

| Status | Mode | Rationale |
|--------|------|-----------|
| COMPLETED | Mode B | Task must be pruned from tree; full regen handles this |
| ABANDONED | Mode B | Task must be pruned from tree; full regen handles this |
| EXPANDED | Mode B | Task replaced by subtasks; full regen handles this |
| RESEARCHING, RESEARCHED, PLANNING, PLANNED, IMPLEMENTING, PARTIAL, BLOCKED | Mode A | In-place status update in tree; task remains active |

### Mode A Tree Line Pattern

The grep pattern `^\s*(└─ )?${task_number} \[` correctly matches:
- `148 [RESEARCHED] — ...` (root-level, no indent)
- `  └─ 147 [RESEARCHED] — ...` (depth 1, 2-space indent)
- `    └─ 143 [PARTIAL] — ...` (depth 2, 4-space indent)
- `      └─ 141 [PLANNED] — ...` (depth 3+)

The `\s*` matches any leading spaces (0 or more), and `(└─ )?` optionally matches the tree connector prefix. After the task number comes a space then `[`.

### Mode A Status Extraction Improvement

The ProofChecker version uses `grep -oE '\[([A-Z ]+)\]' | head -1 | tr -d '[]'` instead of `sed 's/.*\[\([^]]*\)\].*/\1/'`. This handles multi-word statuses like `NOT STARTED` (which contains a space) more reliably.

### Mode A Fallback Behavior

When `order_line` is empty (task not found in tree), the ProofChecker script:
1. Prints warning: `Warning: task $task_number not found in TODO.md Task Order tree -- falling back to full regeneration`
2. Calls `generate-task-order.sh --update-todo "$TODO_FILE" "$STATE_FILE" 2>/dev/null || { echo "Warning: ...fallback failed..." >&2 }`
3. Returns 0

The `2>/dev/null` on the fallback call suppresses noise; the primary Mode B call does not suppress stderr (letting genuine failures surface).

### How Mode B Calls generate-task-order.sh

```bash
"$gen_script" --update-todo "$TODO_FILE" "$STATE_FILE"
```

Where:
- `gen_script="$SCRIPT_DIR/generate-task-order.sh"`
- `$TODO_FILE` = `$PROJECT_ROOT/specs/TODO.md` (from script-level config)
- `$STATE_FILE` = `$PROJECT_ROOT/specs/state.json` (from script-level config)

The script finds the `## Task Order` section in TODO.md, regenerates it from state.json (excluding terminal tasks), and replaces the section in-place. The existing Goal line is preserved automatically.

### Phase 5 Lifecycle Notifications (nvim-config-specific, Must Preserve)

Phase 5 exists only in the nvim-config version. ProofChecker has no Phase 5. The nvim-config Phase 5 (lines 330–370) contains three distinct features:

1. **TTS lifecycle signal file** (`postflight` only):
   - Writes `$STATE_STATUS` to `$TMP_DIR/tts-lifecycle-signal`
   - Allows the Stop hook to detect that a lifecycle TTS was already fired and suppress redundant TTS

2. **TTS direct notification** (`postflight` only):
   - Calls `$SCRIPT_DIR/../hooks/tts-notify.sh --lifecycle $STATE_STATUS` in background
   - Speaks "Tab N researched/planned/completed" immediately
   - Non-blocking: runs with `&`

3. **WezTerm tab color update** (`postflight` only):
   - Calls `$SCRIPT_DIR/../hooks/wezterm-notify.sh $STATE_STATUS` in background
   - Sets `CLAUDE_STATUS` user variable to reflect lifecycle state
   - Non-blocking: runs with `&`

4. **OpenCode session rename** (`preflight` only, after Phase 5 block):
   - Reads `project_name` from state.json
   - Builds label: first letter of `target_status` uppercased + rest
   - Calls `$SCRIPT_DIR/rename-session.sh "$label task $N: $project_name"` with `2>/dev/null || true`

These four features are nvim-config-specific infrastructure and must be preserved in their current form. The implementation task must not alter them.

### What Changes and What Stays

| Component | Current (nvim) | After Port | Change Type |
|-----------|----------------|------------|-------------|
| Phase 1 (state.json) | Correct | Unchanged | None |
| Phase 2 (TODO task entry) | Correct | Unchanged | None |
| Phase 3 function body | Old flat-list pattern | Two-mode (Mode A + Mode B) | Replace |
| Phase 4 (plan file) | Correct | Unchanged | None |
| Phase 5 (TTS, WezTerm, OpenCode) | nvim-specific | Unchanged | None |
| Script structure/config | Correct | Unchanged | None |

The implementation scope is strictly the body of `update_todo_task_order()` (lines 232–265 in the current file).

## Decisions

- Port the ProofChecker Phase 3 exactly: Mode B dispatch first, then Mode A with fallback. No deviation.
- The Mode A grep pattern `^\s*(└─ )?${task_number} \[` is correct for the wave+tree format used by `generate-task-order.sh`.
- The status extraction improvement (`grep -oE` vs old `sed`) should be adopted along with the port.
- Phase 5 is not touched; it has no counterpart in ProofChecker and must remain.
- The `gen_script` variable in the Mode B and fallback blocks uses the local path construction `"$SCRIPT_DIR/generate-task-order.sh"` (same as ProofChecker).

## Recommendations

1. Replace the body of `update_todo_task_order()` (lines 232–265) with the ProofChecker two-mode implementation.
2. The replacement adds these key behaviors:
   - Mode B: Terminal transitions call `generate-task-order.sh --update-todo` (auto-prunes)
   - Mode A: Non-terminal transitions use `^\s*(└─ )?${N} \[` pattern
   - Mode A fallback: Missing task falls back to `generate-task-order.sh` regeneration
3. Leave all other phases (1, 2, 4, 5) untouched.
4. Verify with a dry-run: `update-task-status.sh postflight 581 implement <session> --dry-run` should output `[dry-run] TODO.md Task Order: terminal status COMPLETED -> would run generate-task-order.sh --update-todo`.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `generate-task-order.sh` not executable | M | Non-fatal guard: `if [[ -x "$gen_script" ]]` with warning |
| Mode A sed replaces wrong bracket if description contains `[...]` | L | Pattern anchors on task number: `${order_line}s/\[${current_order_status}\]/[${TODO_STATUS}]/` replaces only the first match on that line |
| Phase 5 accidentally modified | M | Edit only the `update_todo_task_order()` function body; verify line ranges before edit |
| Fallback Mode B fires noise on every new task (not yet in tree) | L | `2>/dev/null` on fallback suppresses stderr; warning still goes to stderr |

## Appendix

### File to Modify

- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh`
  - Function: `update_todo_task_order()` (lines 232–265)
  - Replacement: ProofChecker Phase 3 implementation (lines 232–301 of ProofChecker version)

### Line Range Reference (nvim-config current)

```
232: # PHASE 3: Update TODO.md Task Order section
233: # ============================================================
234: update_todo_task_order() {
...
265: }
```

### generate-task-order.sh Integration

The ported Phase 3 calls:
- `"$gen_script" --update-todo "$TODO_FILE" "$STATE_FILE"` (Mode B, primary)
- `"$gen_script" --update-todo "$TODO_FILE" "$STATE_FILE" 2>/dev/null` (Mode A fallback)

Both calls use the script-level `$TODO_FILE` and `$STATE_FILE` variables set at the top of `update-task-status.sh`.

### ProofChecker Task 150 Context

ProofChecker task 150 (task_order_auto_sync) implemented the two-mode Phase 3 strategy as part of a broader auto-sync effort. The research report confirms that Mode A was designed specifically for the wave+tree format produced by `generate-task-order.sh`, and Mode B was designed to auto-prune terminal tasks by delegating to full regeneration.
