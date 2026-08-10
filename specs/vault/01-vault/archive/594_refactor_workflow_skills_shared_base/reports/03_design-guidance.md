# Design Guidance: Task 594 — Refactor Workflow Skills to Shared Base

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` Component 2
**Depends on**: Task 593 (shared utilities), Task 598 (context budgets)
**Blocks**: Tasks 595, 596

---

## Overview

Task 594 extracts ~210 lines of lifecycle duplication across skill-researcher, skill-planner, and
skill-implementer into a shared shell script library `skill-base.sh`. After refactoring, each skill
retains only its unique logic: context collection, delegation context construction, and agent invocation.

**Do NOT add extension hooks in this task.** Extension hooks are task 599 scope.

---

## File Locations

### New Files (to create)
```
.claude/scripts/skill-base.sh           # Shared skill lifecycle library (11 functions)
.claude/scripts/postflight-workflow.sh  # Shared postflight helper (if not created by task 593)
```

### Skill Files (to modify)
```
.claude/skills/skill-researcher/SKILL.md    # 558L → 150L target
.claude/skills/skill-planner/SKILL.md       # ~450L → 130L target
.claude/skills/skill-implementer/SKILL.md   # ~600L → 200L target
.claude/skills/skill-reviser/SKILL.md       # ~490L → ~130L target (if applicable)
```

---

## `skill-base.sh` Function Inventory

All 11 functions with complete signatures:

```bash
#!/usr/bin/env bash
# skill-base.sh — Shared skill lifecycle functions
# Source this file in each skill to use shared lifecycle stages.

# Stage 1: Validate input task number
# Usage: skill_validate_input "$task_number"
# Exports: TASK_DATA, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM, TASK_DIR
# Exit 1 if task not found
skill_validate_input() {
  local task_number="$1"
  PADDED_NUM=$(printf "%03d" "$task_number")
  TASK_DATA=$(jq -c ".active_projects[] | select(.project_number == $task_number)" specs/state.json)
  if [ -z "$TASK_DATA" ]; then
    echo "ERROR: Task $task_number not found" >&2
    exit 1
  fi
  TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.task_type')
  TASK_STATUS=$(echo "$TASK_DATA" | jq -r '.status')
  PROJECT_NAME=$(echo "$TASK_DATA" | jq -r '.project_name')
  TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
  export TASK_DATA TASK_TYPE TASK_STATUS PROJECT_NAME PADDED_NUM TASK_DIR
}

# Stage 2: Update status to in-progress variant
# Usage: skill_preflight_update "$task_number" "$operation" "$session_id"
# operation: "research" | "plan" | "implement" | "revise"
skill_preflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  bash .claude/scripts/update-task-status.sh "$task_number" "${operation}ing" "$session_id"
}

# Stage 3: Create postflight-pending marker
# Usage: skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
skill_create_postflight_marker() {
  local padded_num="$1"
  local project_name="$2"
  local session_id="$3"
  local skill_name="$4"
  local operation="$5"
  local task_dir="specs/${padded_num}_${project_name}"
  mkdir -p "$task_dir"
  cat > "${task_dir}/.postflight-pending" <<EOF
{"session_id": "$session_id", "skill": "$skill_name", "operation": "$operation", "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
}

# Stage 3a: Read artifact number for this task
# Usage: skill_read_artifact_number "$task_number" "$padded_num" "$project_name"
# Exports: ARTIFACT_NUMBER, ARTIFACT_PADDED
skill_read_artifact_number() {
  local task_number="$1"
  local padded_num="$2"
  local project_name="$3"
  ARTIFACT_NUMBER=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .next_artifact_number // 1" specs/state.json)
  if [ "$ARTIFACT_NUMBER" = "null" ] || [ -z "$ARTIFACT_NUMBER" ]; then
    ARTIFACT_NUMBER=1
  fi
  ARTIFACT_PADDED=$(printf "%02d" "$ARTIFACT_NUMBER")
  export ARTIFACT_NUMBER ARTIFACT_PADDED
}

# Stage 6: Read agent metadata file
# Usage: skill_read_metadata "$padded_num" "$project_name"
# Exports: SUBAGENT_STATUS, ARTIFACT_PATH, ARTIFACT_TYPE, ARTIFACT_SUMMARY, MEMORY_CANDIDATES
skill_read_metadata() {
  local padded_num="$1"
  local project_name="$2"
  local task_dir="specs/${padded_num}_${project_name}"
  local meta_file="${task_dir}/.return-meta.json"
  if [ ! -f "$meta_file" ]; then
    SUBAGENT_STATUS="failed"
    ARTIFACT_PATH=""
    ARTIFACT_TYPE=""
    ARTIFACT_SUMMARY="Agent did not write metadata"
    MEMORY_CANDIDATES="[]"
  else
    SUBAGENT_STATUS=$(jq -r '.status' "$meta_file")
    ARTIFACT_PATH=$(jq -r '.artifacts[0].path // ""' "$meta_file")
    ARTIFACT_TYPE=$(jq -r '.artifacts[0].type // ""' "$meta_file")
    ARTIFACT_SUMMARY=$(jq -r '.artifacts[0].summary // ""' "$meta_file")
    MEMORY_CANDIDATES=$(jq -c '.memory_candidates // []' "$meta_file")
  fi
  export SUBAGENT_STATUS ARTIFACT_PATH ARTIFACT_TYPE ARTIFACT_SUMMARY MEMORY_CANDIDATES
}

# Stage 6a: Validate artifact exists (non-blocking)
# Usage: skill_validate_artifact "$status" "$artifact_path"
skill_validate_artifact() {
  local status="$1"
  local artifact_path="$2"
  if [ "$status" != "failed" ] && [ -n "$artifact_path" ]; then
    bash .claude/scripts/validate-artifact.sh "$artifact_path" --fix 2>/dev/null || true
  fi
}

# Stage 7: Update status to completed variant
# Usage: skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
# Only updates on "researched", "planned", or "implemented" status
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  case "$status" in
    researched|planned|implemented)
      local target_status
      case "$operation" in
        research) target_status="researched" ;;
        plan)     target_status="planned" ;;
        implement) target_status="completed" ;;
        revise)   target_status="planned" ;;
      esac
      bash .claude/scripts/update-task-status.sh "$task_number" "$target_status" "$session_id"
      ;;
    *)
      echo "[skill-base] Non-success status '$status' — postflight skipped"
      ;;
  esac
}

# Stage 7a: Increment artifact number (research only)
# Usage: skill_increment_artifact_number "$task_number"
skill_increment_artifact_number() {
  local task_number="$1"
  python3 -c "
import json
with open('specs/state.json', 'r') as f:
    state = json.load(f)
for p in state['active_projects']:
    if p['project_number'] == $task_number:
        p['next_artifact_number'] = p.get('next_artifact_number', 1) + 1
        break
with open('specs/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
}

# Stage 7b: Propagate memory candidates to state.json
# Usage: skill_propagate_memory_candidates "$task_number" "$memory_candidates"
skill_propagate_memory_candidates() {
  local task_number="$1"
  local memory_candidates="$2"
  if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    python3 -c "
import json
with open('specs/state.json', 'r') as f:
    state = json.load(f)
new_candidates = json.loads('$memory_candidates')
for p in state['active_projects']:
    if p['project_number'] == $task_number:
        existing = p.get('memory_candidates', [])
        p['memory_candidates'] = existing + new_candidates
        break
with open('specs/state.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
  fi
}

# Stage 8: Link artifacts to task record
# Usage: skill_link_artifacts "$task_number" "$artifact_path"
skill_link_artifacts() {
  local task_number="$1"
  local artifact_path="$2"
  if [ -n "$artifact_path" ]; then
    bash .claude/scripts/link-artifact-todo.sh "$task_number" "$artifact_path" 2>/dev/null || true
  fi
}

# Stage 9: Cleanup temporary files
# Usage: skill_cleanup "$padded_num" "$project_name"
skill_cleanup() {
  local padded_num="$1"
  local project_name="$2"
  local task_dir="specs/${padded_num}_${project_name}"
  rm -f "${task_dir}/.postflight-pending" \
        "${task_dir}/.postflight-loop-guard" \
        "${task_dir}/.return-meta.json" 2>/dev/null || true
}
```

---

## Hook Points for Skill-Specific Logic

Each skill provides exactly these unique sections:

### Stage 4: Context Collection (unique per skill)

```
skill-researcher Stage 4 variants:
  - 4a: Memory retrieval (not in planner/implementer)
  - 4b: Format injection (research reports)
  - 4c: Roadmap consultation
  - 4d: Prior implementation context

skill-planner Stage 4:
  - Load research report context
  - Load prior plan if exists

skill-implementer Stage 4:
  - Load plan file
  - Load continuation context (if successor)
  - Check orchestrator_mode flag
```

### Stage 5: Agent Invocation (unique subagent_type)

```
skill-researcher:  subagent_type = "general-research-agent"
skill-planner:     subagent_type = "planner-agent"
skill-implementer: subagent_type = "general-implementation-agent"
skill-reviser:     subagent_type = "reviser-agent"
```

---

## Target Skill Sizes

| Skill | Current Lines | Target Lines | Lines Eliminated |
|-------|--------------|--------------|-----------------|
| skill-researcher | 558 | 150 | 408 |
| skill-planner | ~450 | 130 | 320 |
| skill-implementer | ~600 | 200 | 400 |
| skill-reviser | ~490 | 130 | 360 |
| **Total** | **~2100** | **~610** | **~1490** |

Implementer stays larger due to orchestrator_mode flag and `max_continuations` logic.

---

## What Remains Skill-Specific (Do NOT Extract)

| Section | Why Skill-Specific |
|---------|-------------------|
| Stage 4 context collection | Different memory retrieval, format injection, roadmap steps |
| Delegation context construction | Different fields per skill (research focus, plan path, etc.) |
| Stage 5 agent invocation | Different `subagent_type`, different prompt construction |
| Implementer: orchestrator_mode check | Unique to implementer + orchestrate integration |
| Implementer: continuation loop | Unique to implementer (max_continuations logic) |

---

## Context Budget Constraints (from Task 598)

Skill files must NOT embed Tier 3 context (agent-level context). After task 594:
- Skill files: ≤ 200 lines (unique logic only)
- Agent context is loaded by the agent at spawn time (not by the skill)
- Budget caps: sonnet workers ≤ 8K tokens, opus planners ≤ 15K tokens

---

## Implementation Order

1. Build `skill-base.sh` with all 11 functions
2. Refactor `skill-researcher` first (most stages, best test case)
3. Validate: run a research task end-to-end
4. Refactor `skill-planner`
5. Refactor `skill-implementer` (preserve orchestrator_mode logic)
6. Refactor `skill-reviser` (if applicable to shared base)

---

## Verification

```bash
# Verify skill-base.sh exists
ls -la .claude/scripts/skill-base.sh

# Verify skill line counts reduced
wc -l .claude/skills/skill-researcher/SKILL.md \
       .claude/skills/skill-planner/SKILL.md \
       .claude/skills/skill-implementer/SKILL.md
# Each should be 130-200 lines

# Functional test: research task end-to-end
# Verify all status transitions work correctly
```
