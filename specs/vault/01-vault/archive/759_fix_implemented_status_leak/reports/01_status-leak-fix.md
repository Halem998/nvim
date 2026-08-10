# Research Report: Task #759

**Task**: 759 - Fix "implemented" status leak into state.json
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:15:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (SKILL.md files, shell scripts)
**Artifacts**: specs/759_fix_implemented_status_leak/reports/01_status-leak-fix.md
**Standards**: report-format.md

## Executive Summary

- The value `"implemented"` is an internal agent return status, not a valid task lifecycle status
- It should be normalized to `"completed"` before being written to state.json or displayed in TODO.md
- Four fix sites exist: skill-status-sync (×2 mirrors), skill-orchestrate (×2 mirrors), generate-todo.sh (×1), and orchestrator-postflight.sh (×1 — but this last one is already handled correctly)
- The actual bug is confined: `skill-status-sync/SKILL.md` maps `implemented -> [IMPLEMENTED]` and `generate-todo.sh` has no explicit case for "implemented" (so the wildcard uppercases it to `IMPLEMENTED`)
- `skill-orchestrate/SKILL.md` writes `status: "implemented"` in its partial-exit metadata, which then leaks into state.json when postflight scripts read it

## Context & Scope

The agent return value `"implemented"` is the signal a subagent emits in `.return-meta.json` to indicate it completed implementation work. It is consumed by postflight scripts (skill-base.sh, orchestrator-postflight.sh) which are responsible for translating it to the canonical lifecycle status `"completed"` before updating state.json and TODO.md.

The bug manifests when one of these translation layers is missing or incorrect:
1. `skill-status-sync` documents `implemented -> [IMPLEMENTED]` as valid, which is wrong
2. `generate-todo.sh` has no explicit case for `"implemented"`, so the wildcard `tr '[:lower:]' '[:upper:]'` produces `IMPLEMENTED`
3. `skill-orchestrate` writes `status: "implemented"` in the metadata file it creates, which is read by command-gate-out.sh and may be stored raw in some paths

## Findings

### Fix Site 1: skill-status-sync/SKILL.md (Primary codebase)

**File**: `/home/benjamin/.config/nvim/.claude/skills/skill-status-sync/SKILL.md`
**Lines**: 159-165

**Current code**:
```markdown
**Status Mapping**:
| state.json | TODO.md |
|------------|---------|
| researched | [RESEARCHED] |
| planned | [PLANNED] |
| implemented | [IMPLEMENTED] |
| partial | [PARTIAL] |
```

**Problem**: Maps `implemented -> [IMPLEMENTED]`, documenting an incorrect behavior. The table is reference documentation for what the skill does, so if an agent follows it, it will set the task status to `implemented` in state.json and `[IMPLEMENTED]` in TODO.md, which are not valid lifecycle states.

**Fix**: Remove the `implemented` row entirely, or replace it with `completed -> [COMPLETED]`:
```markdown
**Status Mapping**:
| state.json | TODO.md |
|------------|---------|
| researched | [RESEARCHED] |
| planned | [PLANNED] |
| completed  | [COMPLETED] |
| partial    | [PARTIAL] |
```

**Why correct**: The valid completion state for implementation is `"completed"`, as confirmed by `update-task-status.sh` line 92: `postflight:implement) STATE_STATUS="completed"; TODO_STATUS="COMPLETED"`.

---

### Fix Site 2: generate-todo.sh

**File**: `/home/benjamin/.config/nvim/.claude/scripts/generate-todo.sh`
**Lines**: 115-131

**Current code**:
```bash
format_status() {
  local raw="$1"
  case "$raw" in
    not_started)  printf '%s' "NOT STARTED" ;;
    researching)  printf '%s' "RESEARCHING" ;;
    researched)   printf '%s' "RESEARCHED" ;;
    planning)     printf '%s' "PLANNING" ;;
    planned)      printf '%s' "PLANNED" ;;
    implementing) printf '%s' "IMPLEMENTING" ;;
    completed)    printf '%s' "COMPLETED" ;;
    blocked)      printf '%s' "BLOCKED" ;;
    abandoned)    printf '%s' "ABANDONED" ;;
    partial)      printf '%s' "PARTIAL" ;;
    expanded)     printf '%s' "EXPANDED" ;;
    pr_ready)     printf '%s' "PR READY" ;;
    *)            printf '%s' "$(echo "$raw" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}
```

**Problem**: There is no explicit case for `"implemented"`. When state.json contains `"implemented"` (due to any of the other bugs), the wildcard branch uppercases it to `IMPLEMENTED` instead of showing `COMPLETED`. This propagates the wrong marker into TODO.md.

**Fix**: Add an explicit case that maps `implemented -> COMPLETED`:
```bash
    implemented) printf '%s' "COMPLETED" ;;
```

Insert this before or after the `completing` case (line 124). This is a safety net: if `"implemented"` ever lands in state.json, generate-todo.sh will produce the correct TODO marker. The right long-term fix is to prevent `"implemented"` from reaching state.json at all, but this defensive case is still needed.

---

### Fix Site 3: skill-orchestrate/SKILL.md — Stage 8 Postflight (Primary codebase)

**File**: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
**Lines**: 700-712

**Current code**:
```bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "implemented" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
```

**Problem**: On both clean exit AND partial exit, `skill-orchestrate` writes `status: "implemented"` to `.return-meta.json`. This metadata file is then read by `command-gate-out.sh`, which checks `skill_status` and triggers `update-task-status.sh`. When `command-gate-out.sh` sees `skill_status = "implemented"` for operation `orchestrate`, it correctly maps to `expected_status = "completed"` (line 60). However, `skill-status-sync` reading this file directly would see `"implemented"` and write it raw to state.json.

More critically: the `/orchestrate` command writes `"implemented"` in the metadata, but the signal value for the orchestrate lifecycle is semantically equivalent to "completed" — it is not a partial/failed state. Using a non-standard string `"implemented"` is the root confusion.

**Fix**: Change `--arg status "implemented"` to `--arg status "completed"` for clean exit. For partial exit, use `"partial"`:

```bash
# Clean exit variant:
jq -n \
  --arg status "completed" \
  ...

# Partial exit variant:
jq -n \
  --arg status "partial" \
  ...
```

Note: The current skill writes the same metadata block for both paths (partial and clean). The fix should differentiate: use `"completed"` on clean exit and `"partial"` on partial exit (MAX_CYCLES reached).

---

### Fix Site 4: extensions/core/skills/skill-status-sync/SKILL.md (Extension mirror)

**File**: `/home/benjamin/.config/nvim/.claude/extensions/core/skills/skill-status-sync/SKILL.md`
**Lines**: 159-165 (same as Fix Site 1)

**Current code**: Identical to Fix Site 1 — `implemented | [IMPLEMENTED]` in the status mapping table.

**Fix**: Same as Fix Site 1 — replace `implemented | [IMPLEMENTED]` with `completed | [COMPLETED]`.

---

### Fix Site 5: extensions/core/skills/skill-orchestrate/SKILL.md (Extension mirror)

**File**: `/home/benjamin/.config/nvim/.claude/extensions/core/skills/skill-orchestrate/SKILL.md`
**Lines**: 621-634 (same pattern as Fix Site 3)

**Current code**:
```bash
jq -n \
  --arg status "implemented" \
  ...
```

**Fix**: Same as Fix Site 3 — change `"implemented"` to `"completed"` for clean exit, `"partial"` for partial exit.

---

### Additional Investigation: orchestrator-postflight.sh

**File**: `/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh`
**Line 113**: `success_status="implemented"`
**Lines 308-313**: TTS notification normalizes `"implemented"` to `"completed"` for wezterm

**Analysis**: This script uses `"implemented"` as the internal trigger value (`success_status`) to detect a successful implement operation. It then calls `update-task-status.sh postflight implement` (line 186) which correctly writes `"completed"` to state.json (via the `postflight:implement -> completed` mapping in update-task-status.sh line 92). The `do_status_update="false"` for implement (line 117) means this path runs inline in skill-implementer, not here.

The line 313 `[ "$notify_status" = "implemented" ] && notify_status="completed"` is a defensive alias showing the developers know `"implemented"` should display as `"completed"` for notifications.

**Conclusion**: `orchestrator-postflight.sh` is NOT a bug site. It uses `"implemented"` as an internal discriminator and correctly translates to `"completed"` when updating state. However, the comment on line 308 is evidence of the broader confusion this naming causes.

---

### Additional Investigation: skill-base.sh (both primary and extension)

**Files**: 
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` (lines 280-283)
- `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/skill-base.sh` (lines 280-283)

**Current code**:
```bash
case "$status" in
  researched|planned|implemented)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
    ;;
```

**Analysis**: `skill_postflight_update` accepts `"implemented"` as a trigger to call `update-task-status.sh`, which correctly maps `postflight:implement -> completed`. This is correct behavior — `"implemented"` from `.return-meta.json` triggers a call to the centralized update script, which writes `"completed"` to state.json. This is NOT a bug site.

---

### Additional Investigation: command-gate-out.sh

**File**: `/home/benjamin/.config/nvim/.claude/scripts/command-gate-out.sh`
**Lines**: 57-76

**Analysis**: Correctly handles `skill_status = "implemented"` by calling `update-task-status.sh postflight` for operation `implement`, which maps to `"completed"`. NOT a bug site.

---

### Additional Investigation: skill-implementer/SKILL.md and skill-team-implement/SKILL.md

Both skills correctly call `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"` when `status = "implemented"`, which writes `"completed"` to state.json. NOT bug sites.

`skill-team-implement/SKILL.md` Stage 13 writes `"status": "implemented"` to the metadata file (line 514), which is then consumed by `skill-implementer` postflight correctly. The metadata file value `"implemented"` is correctly consumed and translated.

---

### Root Cause Summary

The confusion stems from two layers of "status":
1. **Agent return status** in `.return-meta.json`: `"implemented"` is a signal value meaning "implementation work completed"
2. **Lifecycle status** in `state.json` / `TODO.md`: `"completed"` / `[COMPLETED]` is the canonical end state

The correct translation pipeline is: `.return-meta.json: "implemented"` → `update-task-status.sh postflight implement` → `state.json: "completed"` / `TODO.md: [COMPLETED]`.

The bugs occur when:
- **skill-status-sync** documents the table incorrectly (says `implemented -> [IMPLEMENTED]`) so agents following the docs write the wrong status
- **generate-todo.sh** has no explicit case for `"implemented"`, so if `state.json` ever contains it, `TODO.md` gets `[IMPLEMENTED]`
- **skill-orchestrate** writes `status: "implemented"` in its own metadata, which is ambiguous — for a completed orchestration run, this should be `"completed"` to be unambiguous

## Decisions

1. Fix skill-status-sync documentation to remove `implemented -> [IMPLEMENTED]` and replace with `completed -> [COMPLETED]`
2. Add defensive `implemented) printf '%s' "COMPLETED"` case to generate-todo.sh
3. Fix skill-orchestrate Stage 8 metadata: use `"completed"` on clean exit, `"partial"` on partial exit
4. Apply fixes to extension mirrors in `.claude/extensions/core/`

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Changing `--arg status "implemented"` in skill-orchestrate may break code-gate-out.sh's pattern match | Confirmed: command-gate-out.sh checks `skill_status = "implemented"` OR `"researched"` OR `"planned"` — changing to `"completed"` means this specific pattern would not match. Must also update command-gate-out.sh line 64 to include `"completed"` in the trigger condition |
| generate-todo.sh defensive case may mask underlying bugs | Intentional: it is defense-in-depth, not a primary fix |
| Extension mirrors may drift from primary if not updated atomically | Fix both primary and extension mirrors in the same commit |

### Critical Dependency: command-gate-out.sh

**File**: `/home/benjamin/.config/nvim/.claude/scripts/command-gate-out.sh`
**Lines**: 64-65

**Current code**:
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

If skill-orchestrate is changed to write `"completed"` instead of `"implemented"`, this guard will no longer match for completed orchestrations. The gate-out defensive correction is meant to catch stale status in state.json — for a completed orchestration, it would check if state.json is already `"completed"` and no-op. The fix here should be to add `"completed"` to the match condition:

```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "completed" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```

This adds `"completed"` as a valid trigger for the defensive correction in command-gate-out.sh.

## Recommendations

### Phase 1: Documentation Fixes (Zero Risk)

1. **skill-status-sync/SKILL.md** (both primary and extension mirror): Replace `implemented | [IMPLEMENTED]` with `completed | [COMPLETED]` in the Status Mapping table.

2. **skill-orchestrate/SKILL.md** (both primary and extension mirror): Change Stage 8 metadata `--arg status "implemented"` to `--arg status "completed"` for clean exit and `--arg status "partial"` for partial exit.

### Phase 2: Script Fixes (Low Risk)

3. **generate-todo.sh**: Add `implemented) printf '%s' "COMPLETED" ;;` before the wildcard case. This is a defensive net that normalizes the wrong value to the correct display string.

4. **command-gate-out.sh**: Add `"completed"` to the trigger condition (line 64) so defensive correction fires even when skill-orchestrate writes `"completed"` directly.

### Summary Table

| File | Line(s) | Current | Fix |
|------|---------|---------|-----|
| `.claude/skills/skill-status-sync/SKILL.md` | 164 | `implemented \| [IMPLEMENTED]` | `completed \| [COMPLETED]` |
| `.claude/extensions/core/skills/skill-status-sync/SKILL.md` | 164 | `implemented \| [IMPLEMENTED]` | `completed \| [COMPLETED]` |
| `.claude/skills/skill-orchestrate/SKILL.md` | 703 | `--arg status "implemented"` | `--arg status "completed"` (clean) / `"partial"` (partial) |
| `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` | 625 | `--arg status "implemented"` | `--arg status "completed"` (clean) / `"partial"` (partial) |
| `.claude/scripts/generate-todo.sh` | ~128 | (no case for `implemented`) | Add `implemented) printf '%s' "COMPLETED" ;;` |
| `.claude/scripts/command-gate-out.sh` | 64 | matches `"implemented"` only | Also match `"completed"` |

## Appendix

### Files Examined
- `.claude/skills/skill-status-sync/SKILL.md` — lines 159-165
- `.claude/extensions/core/skills/skill-status-sync/SKILL.md` — lines 159-165
- `.claude/scripts/generate-todo.sh` — lines 115-132
- `.claude/skills/skill-orchestrate/SKILL.md` — lines 668-714
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` — lines 599-634
- `.claude/scripts/skill-base.sh` — lines 270-290
- `.claude/extensions/core/scripts/skill-base.sh` — lines 270-290
- `.claude/scripts/update-task-status.sh` — lines 85-99
- `.claude/scripts/orchestrator-postflight.sh` — lines 80-315
- `.claude/scripts/command-gate-out.sh` — lines 52-77
- `.claude/skills/skill-implementer/SKILL.md` — lines 280-480
- `.claude/skills/skill-implementer-hard/SKILL.md` — grep results
- `.claude/skills/skill-team-implement/SKILL.md` — lines 465-542
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — lines 480-541 (no Stage 8 metadata write — hard mode has no clean metadata write for partial exit, only EXIT directives)
