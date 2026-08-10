# Implementation Plan: Task #756

- **Task**: 756 - Fix orchestrate Stage 5 to link artifacts via .return-meta.json fallback
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/756_fix_orchestrate_artifact_linking/reports/01_artifact-linking-fix.md
- **Artifacts**: plans/01_artifact-linking-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Stage 5 of skill-orchestrate reads `.orchestrator-handoff.json` after each agent dispatch to perform postflight status updates and artifact linking. When agents are dispatched directly (bypassing the skill layer), no handoff file is written, and the current `if [ ! -f "$handoff_file" ]` branch simply logs an error and skips all postflight -- leaving task status stuck and artifacts unlinked. The fix replaces this dead branch with a fallback that reads `.return-meta.json` (which all agents always write), extracts the same status and artifact fields, and calls the existing `skill_postflight_update` and `skill_link_artifacts` functions.

### Research Integration

The research report identified the exact code location (Stage 5, lines 346-441 of SKILL.md), confirmed that `.return-meta.json` status values (`researched`, `planned`, `implemented`) match the existing `case` statement expectations, and provided the complete replacement code. The report also confirmed that drift detection and per-cycle commit logic can be safely skipped in the fallback path since they require handoff-specific fields (`phases_completed`, `phases_total`) that are not available in `.return-meta.json`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. This is a bug fix in the agent orchestration layer.

## Goals & Non-Goals

**Goals**:
- When `.orchestrator-handoff.json` is absent, fall back to reading `.return-meta.json` for status and artifact data
- Call `skill_postflight_update` and `skill_link_artifacts` from the fallback path using the same logic as the existing `else` branch
- Preserve existing behavior when the handoff file does exist (no changes to the `else` branch)

**Non-Goals**:
- Modifying the handoff-writing logic in `skill-base.sh`
- Adding drift detection or per-cycle commit support to the fallback path
- Changing the `.return-meta.json` schema

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `.return-meta.json` has `status: "in_progress"` (agent interrupted) | L | M | The `*)` branch in the case statement logs "no postflight needed" and skips -- same as current behavior for non-terminal statuses |
| Type mismatch between .return-meta.json and state.json field expectations | M | L | Research confirmed both use identical type values ("report", "plan", "summary"); the existing `else` branch already passes these through verbatim |
| Malformed JSON in .return-meta.json | L | L | The `jq empty` validity check guards the entire fallback block; invalid JSON falls through to the error-log path |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add .return-meta.json Fallback to Stage 5 [COMPLETED]

**Goal**: Replace the dead `if [ ! -f "$handoff_file" ]` branch with a fallback that reads `.return-meta.json` and calls the same postflight and artifact-linking functions as the `else` branch.

**Tasks**:
- [x] Open `.claude/skills/skill-orchestrate/SKILL.md` and locate the Stage 5 code block (lines 346-441) *(completed)*
- [x] Replace the 3-line dead branch (lines 346-349: the `if` through the comment before `else`) with the fallback code below *(completed)*
- [x] Verify the replacement preserves the `else` keyword on the correct line so the existing `else` branch is unaffected *(completed)*

**Exact change**: Replace the current `if [ ! -f "$handoff_file" ]` block (everything from the `if` line through the line before `else`) with:

```bash
if [ ! -f "$handoff_file" ]; then
  echo "[orchestrate] WARNING: No orchestrator handoff found. Falling back to .return-meta.json."
  meta_file="${TASK_DIR}/.return-meta.json"
  if [ -f "$meta_file" ] && jq empty "$meta_file" 2>/dev/null; then
    dispatch_status=$(jq -r '.status' "$meta_file")
    meta_artifact_path=$(jq -r '.artifacts[0].path // ""' "$meta_file")
    meta_artifact_type=$(jq -r '.artifacts[0].type // ""' "$meta_file")
    meta_artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$meta_file")
    echo "[orchestrate] Fallback dispatch result from .return-meta.json: $dispatch_status"

    # Postflight status update (same logic as else branch)
    case "$dispatch_status" in
      researched)
        skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
        ;;
      planned)
        skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
        ;;
      implemented)
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
        ;;
      *)
        echo "[orchestrate] Fallback status '$dispatch_status' — no postflight update needed"
        ;;
    esac

    # Artifact linking (same logic as else branch)
    if [ -n "$meta_artifact_path" ] && [ "$meta_artifact_path" != "null" ]; then
      case "$meta_artifact_type" in
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
      skill_link_artifacts "$task_number" "$meta_artifact_path" "$meta_artifact_type" \
        "$meta_artifact_summary" "$field_name" "$next_field"
    fi
  else
    echo "[orchestrate] ERROR: Neither handoff nor .return-meta.json found. State.json may be stale."
    echo "This may mean orchestrator_mode was not propagated correctly."
    # Increment cycle and continue — no postflight possible without metadata
  fi
```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Replace the dead `if [ ! -f "$handoff_file" ]` branch (lines 346-349) with the .return-meta.json fallback logic

**Verification**:
- The `if [ ! -f "$handoff_file" ]` branch now contains the `.return-meta.json` fallback
- The `else` branch (handoff exists) is completely unchanged
- The `# Increment cycle_count` line after the closing `fi` is unchanged
- The replacement includes `jq empty` validation to guard against malformed JSON
- The `case` statement for `dispatch_status` matches the same three values as the `else` branch
- The artifact-linking `case` statement matches the same four branches as the `else` branch

---

## Testing & Validation

- [ ] Read the modified SKILL.md and verify the Stage 5 code block has the correct structure: outer `if/else/fi` with the fallback nested inside the `if` branch
- [ ] Verify no syntax errors in the bash code blocks (balanced `if/fi`, `case/esac`)
- [ ] Verify the `else` branch starting at the original line 350 is completely unchanged
- [ ] Manually test: run `/orchestrate` on a task and observe that artifacts appear in state.json/TODO.md even when the agent is dispatched without `orchestrator_mode`

## Artifacts & Outputs

- `specs/756_fix_orchestrate_artifact_linking/plans/01_artifact-linking-fix.md` (this plan)
- `.claude/skills/skill-orchestrate/SKILL.md` (modified file)

## Rollback/Contingency

Revert the single edit to `.claude/skills/skill-orchestrate/SKILL.md` using `git checkout -- .claude/skills/skill-orchestrate/SKILL.md`. The change is self-contained in one code block within one file.
