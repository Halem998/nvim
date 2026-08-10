# Research Report: Task #630

**Task**: 630 - Consolidate orchestrate postflight with skill-base.sh pattern
**Started**: 2026-06-01T00:00:00Z
**Completed**: 2026-06-01T00:30:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-orchestrate/SKILL.md` (1177 lines)
- `.claude/scripts/skill-base.sh` (477 lines)
- Callers: `skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`, `skill-reviser/SKILL.md`, `skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md`
**Artifacts**:
- `specs/630_consolidate_orchestrate_postflight/reports/01_consolidate-postflight.md`
**Standards**: report-format.md

---

## Executive Summary

- The orchestrate skill already calls `skill_postflight_update()` and `skill_link_artifacts()` from `skill-base.sh` — it does NOT inline those functions.
- The actual duplication is a **24-line artifact-type-to-field-name mapping block** that appears identically in Stage 5 (lines ~404-429) and Stage MT-4 (lines ~1041-1066), producing `field_name` and `next_field` values before calling `skill_link_artifacts()`.
- The recommended refactor is to extract this mapping into a **helper function** in `skill-base.sh` (or as a small inline function in SKILL.md), then call it from both Stage 5 and Stage MT-4 to eliminate the 24-line duplicate.
- The task description's framing ("duplicates the pattern in skill-base.sh") is slightly inaccurate: the orchestrate skill already routes through `skill-base.sh` functions. The true duplication is internal to SKILL.md itself.

---

## Context & Scope

This research analyzes whether postflight logic in `skill-orchestrate/SKILL.md` duplicates `skill-base.sh` functions, and what the correct refactoring approach is.

The orchestrate skill is a state machine with two modes:
- **Single-task mode** (Stage 5, ~lines 355-433): reads one handoff file, updates status + links artifact
- **Multi-task mode** (Stage MT-4, ~lines 1003-1090): reads N handoff files per wave, updates status + links artifact for each

---

## Findings

### Codebase Patterns

#### What skill-base.sh provides (postflight-related functions)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `skill_postflight_update` | `"$task_number" "$operation" "$session_id" "$status"` | Calls `update-task-status.sh postflight` when status is success (researched/planned/revised/implemented) |
| `skill_link_artifacts` | `"$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" "$field_name" "$next_field"` | Updates state.json artifacts array + links in TODO.md via `link-artifact-todo.sh` |
| `skill_cleanup` | `"$padded_num" "$project_name"` | Removes `.postflight-pending`, `.postflight-loop-guard`, `.return-meta.json` |
| `skill_validate_artifact` | `"$status" "$artifact_path" "$artifact_kind" ...` | Validates artifact format (non-blocking) |
| `skill_write_orchestrator_handoff` | (9 args) | Writes `.orchestrator-handoff.json` for skill-orchestrate to read |

The `field_name` and `next_field` parameters to `skill_link_artifacts` are caller-specified — the mapping from artifact type to these field names is NOT in `skill-base.sh`.

#### What orchestrate's Stage 5 does (single-task, lines ~355-433)

```
1. Read handoff file (.orchestrator-handoff.json)
2. Extract: dispatch_status, dispatch_summary, blockers, continuation, next_hint,
            phases_completed, phases_total  [ORCHESTRATE-SPECIFIC]
3. Log result + phase progress
4. Drift detection arithmetic gate [ORCHESTRATE-SPECIFIC]
5. Postflight status update via case statement:
   - researched -> skill_postflight_update (research)
   - planned    -> skill_postflight_update (plan)
   - implemented-> skill_postflight_update (implement)
   - *          -> echo (no-op)
6. Artifact linking:
   a. Extract artifact path/type/summary from handoff
   b. Map artifact type to field_name + next_field (case statement)
   c. skill_link_artifacts (if path non-empty)
7. Increment cycle_count
```

#### What orchestrate's Stage MT-4 does (multi-task, lines ~1003-1090)

The per-task postflight block (lines ~1004-1090) for each dispatched task:

```
1. Check if handoff file exists (mark failed if absent) [ORCHESTRATE-SPECIFIC]
2. Read handoff: dispatch_status, dispatch_summary
3. Determine operation from dispatch_status (same case statement as Stage 5)
   -> calls skill_postflight_update per case
4. Artifact linking:
   a. Extract artifact path/type/summary from handoff
   b. Map artifact type to field_name + next_field (IDENTICAL case to Stage 5)
   c. skill_link_artifacts (if path non-empty)
5. Re-read fresh status from state.json
6. Update multi-state tracking file [ORCHESTRATE-SPECIFIC]
```

#### The exact duplication: artifact type -> field name mapping

This block appears identically in Stage 5 (lines ~409-426) and Stage MT-4 (lines ~1046-1063):

```bash
case "$handoff_artifact_type" in
  report)
    field_name='**Research**'
    next_field='**Plan**'
    ;;
  plan)
    field_name='**Plan**'
    next_field='**Description**'
    ;;
  summary)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
  *)
    field_name='**Summary**'
    next_field='**Description**'
    ;;
esac
```

This is **24 lines of identical logic** that maps an artifact type string to the TODO.md field label pair. The comment in Stage MT-4 even acknowledges this: `# Artifact linking (same logic as single-task Stage 5)`.

#### Calling conventions for skill_postflight_update

All 8 callers across the skill ecosystem use the same 4-parameter signature:
```bash
skill_postflight_update "$task_number" "$operation" "$session_id" "$SUBAGENT_STATUS"
```

Orchestrate's Stage 5 uses `$dispatch_status` instead of `$SUBAGENT_STATUS` — same role, different variable name (status value comes from handoff JSON rather than `.return-meta.json`). The parameters match perfectly.

#### Calling conventions for skill_link_artifacts

Standard callers (researcher, planner, implementer) hard-code their field names:
```bash
skill_link_artifacts "$task_number" "$ARTIFACT_PATH" "$ARTIFACT_TYPE" "$ARTIFACT_SUMMARY" '**Research**' '**Plan**'
```

Orchestrate must determine field names dynamically based on `handoff_artifact_type`, which is why it has the case statement first.

### Duplication Map

| Element | Stage 5 lines | Stage MT-4 lines | Duplicated? |
|---------|--------------|------------------|-------------|
| `skill_postflight_update` calls | 389-401 | 1022-1039 | Both use skill-base.sh — calls are parallel, not duplicated code |
| Read handoff fields (path/type/summary) | 405-407 | 1042-1044 | Yes — 3 lines identical |
| Guard: non-empty artifact path | 408 | 1045 | Yes — 1 line identical |
| Artifact type -> field name case | 409-426 | 1046-1063 | Yes — 18 lines identical |
| `skill_link_artifacts` call | 427-428 | 1064-1065 | Yes — 2 lines identical |
| Handoff read (status/summary) | 366-374 | 1016-1019 | Yes — ~5 lines similar |
| Drift detection | 377-386 | absent | Orchestrate-specific (single only) |
| Loop guard update | 432-433 | 1092-1097 | Orchestrate-specific (different mechanics) |
| Multi-state tracking update | absent | 1068-1089 | Orchestrate-specific (multi-task only) |

**True duplication**: ~29 lines shared between Stage 5 and Stage MT-4 in SKILL.md (not duplication vs skill-base.sh).

### Behavioral Differences

The two blocks are functionally identical in their postflight logic. The only differences are:

1. **Variable name**: Stage 5 uses `$task_number`, Stage MT-4 uses `$task_num` (the loop variable)
2. **Session ID**: Stage 5 uses `$session_id`, Stage MT-4 uses `"${session_id}_${task_num}"` (per-task session)
3. **Missing handoff handling**: Stage MT-4 checks for handoff absence and marks the task as failed in multi-state (orchestrate-specific). Stage 5 logs a message but continues.
4. **Drift detection**: Only in Stage 5.
5. **Multi-state update**: Only in Stage MT-4.

No behavioral bugs detected — both code paths call the same skill-base.sh functions with the same arguments (accounting for variable name differences).

### Recommendations

#### Option A: Extract helper function in skill-base.sh (Recommended)

Add a `skill_link_artifact_from_handoff()` helper to `skill-base.sh` that encapsulates:
1. Read artifact path/type/summary from a handoff JSON string
2. Map type to field_name + next_field
3. Call `skill_link_artifacts()`

```bash
# Proposed new function in skill-base.sh
# Usage: skill_link_artifact_from_handoff "$task_number" "$handoff_json"
skill_link_artifact_from_handoff() {
  local task_number="$1"
  local handoff_json="$2"
  local artifact_path artifact_type artifact_summary field_name next_field

  artifact_path=$(echo "$handoff_json" | jq -r '.artifacts[0].path // ""')
  artifact_type=$(echo "$handoff_json" | jq -r '.artifacts[0].type // ""')
  artifact_summary=$(echo "$handoff_json" | jq -r '.artifacts[0].summary // ""')

  if [ -z "$artifact_path" ] || [ "$artifact_path" = "null" ]; then
    return 0
  fi

  case "$artifact_type" in
    report)  field_name='**Research**'; next_field='**Plan**' ;;
    plan)    field_name='**Plan**';     next_field='**Description**' ;;
    *)       field_name='**Summary**';  next_field='**Description**' ;;
  esac

  skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" \
    "$artifact_summary" "$field_name" "$next_field"
}
```

This would reduce Stage 5's artifact linking block from ~24 lines to 2:
```bash
skill_link_artifact_from_handoff "$task_number" "$handoff"
```

And Stage MT-4's block from ~24 lines to 2:
```bash
skill_link_artifact_from_handoff "$task_num" "$handoff"
```

**Net reduction**: ~40 lines removed from SKILL.md (24 in Stage 5 + 24 in Stage MT-4 = 48, minus 2 call sites = 46 lines, offset by ~15 lines added to skill-base.sh = net -31 lines).

#### Option B: Inline helper function in SKILL.md

Add a local function at the top of SKILL.md's execution flow:

```bash
link_artifact_from_handoff() {
  local task_num="$1"
  local handoff_json="$2"
  # ... same body as Option A ...
}
```

**Pros**: No change to skill-base.sh (simpler PR scope).
**Cons**: Helper lives in SKILL.md rather than the shared library, so other skills can't reuse it. Less aligned with the consolidation goal.

#### Recommended: Option A

Add the helper to `skill-base.sh`. The artifact-type-to-field-name mapping is generic enough to be useful to any skill that reads from orchestrator handoffs. The convention (report->'**Research**', plan->'**Plan**', summary->'**Summary**') is a system-wide standard that belongs in the shared library.

### Callers to Update

Only two callers need to change: Stage 5 and Stage MT-4 in `skill-orchestrate/SKILL.md`. No other skill currently reads from a handoff JSON to extract artifact info — they use `.return-meta.json` via `skill_read_metadata()` instead. So the new helper is orchestrate-specific in its usage, but generically useful.

---

## Decisions

- **Confirmed**: The orchestrate skill already routes through `skill_postflight_update()` and `skill_link_artifacts()` — it is not maintaining a parallel postflight code path for these operations.
- **Identified**: The actual duplication is the artifact-type-to-field-name case statement (24 lines), duplicated identically between Stage 5 and Stage MT-4.
- **Recommended approach**: Add `skill_link_artifact_from_handoff()` to `skill-base.sh` and replace both identical blocks with calls to this helper.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| New helper not sourced at call site | Low | Both Stage 5 and MT-4 are within code that already sources `skill-base.sh` at Stage 1 (line 54) |
| Handoff JSON passed as string may have quoting issues | Medium | Use `echo "$handoff"` pattern (same as existing code); test with jq parse guard |
| Missing `null` check for artifact_path | Low | Helper explicitly handles empty/null (same as existing guard at lines 408, 1045) |
| `summary` type not in case statement | Low | Existing code has explicit `summary` case — helper should preserve this |

---

## Edge Cases

1. **Empty artifact_path**: Existing Stage 5 guards with `[ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]`. Helper should use `jq -r '.artifacts[0].path // ""'` and return early if empty. Already handled in Option A design above.

2. **Handoff has no artifacts array**: `jq -r '.artifacts[0].path // ""'` already returns empty string for missing arrays.

3. **Unknown artifact type**: Both existing blocks fall through to `field_name='**Summary**'; next_field='**Description**'`. Helper preserves this default.

4. **Multi-task session ID derivation**: Stage MT-4 uses `"${session_id}_${task_num}"` for per-task sessions. This is passed to `skill_postflight_update`, not to the artifact-linking path — no impact on the helper.

5. **spec/tmp directory**: `skill_link_artifacts` uses `specs/tmp/state.json` as a temp file. This directory must exist. Already present in the repo (checked).

---

## Context Extension Recommendations

None. This is a meta task and the duplication is internal to the skill file. No new context documentation is needed.

---

## Appendix

### Search strategy used
1. Read `skill-base.sh` in full (477 lines)
2. Read `skill-orchestrate/SKILL.md` in sections (1177 lines total)
3. `grep -n "skill_postflight_update|skill_link_artifacts"` across all 8 skill files to map callers
4. `grep -n "field_name|next_field|handoff_artifact"` in SKILL.md to isolate duplicate blocks

### Key line references
- `skill-base.sh`: `skill_postflight_update` at lines 275-290; `skill_link_artifacts` at lines 344-367
- Stage 5 postflight block: SKILL.md lines ~388-430
- Stage MT-4 postflight block: SKILL.md lines ~1003-1090
- Identical artifact-type case: Stage 5 lines ~409-426; Stage MT-4 lines ~1046-1063
- Comment acknowledging duplication: SKILL.md line 1041 `# Artifact linking (same logic as single-task Stage 5)`
