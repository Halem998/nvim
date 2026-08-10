# Design Guidance: Task 597 — Refactor /task, /revise, /todo, /review

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` Components 1-2
**Depends on**: Task 593 (shared utilities)
**Blocks**: Task 599

---

## Overview

Task 597 applies the shared command infrastructure from task 593 to 4 additional commands that
were not covered by task 595. These commands are less critical path than /research, /plan, /implement
but benefit from the same shared gate-in/gate-out patterns.

---

## File Targets

| Command | Current Lines | Target | Notes |
|---------|--------------|--------|-------|
| /task | 710L | ~300L | 5 modes; complex but reducible |
| /revise | 161L | ~120L | Already compact; add orchestrator handoff |
| /todo | 1047L | ~400L | Decompose into utility modules |
| /review | 1040L | ~400L | Decompose into reusable components |

---

## /task: Applicable Shared Utilities

Apply these gate scripts to /task's state operations:
```bash
source .claude/scripts/command-gate-in.sh "$task_number" "$operation"
# Exports SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, PADDED_NUM
```

/task has 5 modes:
1. Create: `task "Description"` — no gate-in (no task number yet)
2. Recover: `task --recover N` — gate-in with operation="recover"
3. Expand: `task --expand N` — gate-in with operation="expand"
4. Sync: `task --sync` — no gate-in (bulk operation)
5. Abandon: `task --abandon N` — gate-in with operation="abandon"

Apply `parse-command-args.sh` only to modes 2, 3, 5. Mode 1 has free-form text input.
Mode 4 is bulk and does not need per-task gate-in.

---

## /revise: Orchestrator Handoff Integration

/revise is already compact (161L). Primary change: add `orchestrator_mode` support.

When `orchestrator_mode=true` is detected in /revise's delegation context:
```bash
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')

if [ "$orchestrator_mode" = "true" ]; then
  # Write orchestrator handoff after revise completes
  cat > "specs/${padded_num}_${project_name}/.orchestrator-handoff.json" <<EOF
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "revise",
  "status": "planned",
  "summary": "Plan revised. New version at $new_plan_path.",
  "artifacts": [{"type": "plan", "path": "$new_plan_path"}],
  "blockers": [],
  "next_action_hint": "implement"
}
EOF
fi
```

---

## /todo: Decomposition Targets

/todo (1047L) should be decomposed into these utility modules:

### Module 1: `archive-task.sh`
```bash
# Extract: task archival logic (~200L)
# Inputs: task_number, archive_dir
# Outputs: moves task directory to specs/archive/
# Calls: update-task-status.sh (mark archived)
```

### Module 2: `orphan-detection.sh`
```bash
# Extract: detect tasks in state.json missing from TODO.md (~100L)
# Inputs: state.json, TODO.md
# Outputs: list of orphaned task numbers
```

### Module 3: `roadmap-sync.sh`
```bash
# Extract: ROADMAP.md annotation from completion_summary + roadmap_items (~120L)
# Inputs: task_number, completion_summary, roadmap_items
# Outputs: annotates ROADMAP.md
```

### Module 4: `vault-operation.sh`
```bash
# Extract: vault archival when next_project_number > 1000 (~150L)
# Inputs: current state.json
# Outputs: creates vault, renumbers, resets state
```

### Module 5: `memory-harvest.sh` (NEW — critical gap)
```bash
# NEW: harvest memory_candidates from tasks being archived
# This closes a critical information loss gap:
# - 571 archived tasks have memory_candidates in state.json
# - Only 3 memories exist in .memory/ vault
#
# Algorithm:
# 1. For each task being archived:
#    a. Read task.memory_candidates from state.json
#    b. For each candidate with confidence >= 0.7:
#       - Write to .memory/{keyword}.md
#       - Update .memory/index.json
#    c. Clear memory_candidates from task record
#
# Signature:
# harvest_memories "$task_number" "$memory_candidates_json"
```

---

## /review: Decomposition Targets

/review (1040L) should be decomposed into:

### Module 1: `issue-grouping.sh`
```bash
# Extract: issue discovery and grouping algorithm (~180L)
# Inputs: codebase scan results
# Outputs: grouped issues by topic/severity
```

### Module 2: `roadmap-integration.sh`
```bash
# Extract: roadmap analysis and annotation (~120L)
# Inputs: review findings, ROADMAP.md
# Outputs: annotated roadmap with review suggestions
```

### Module 3: `tier-selection.sh`
```bash
# Extract: 3-tier severity selection flow (~100L)
# Inputs: issue list
# Outputs: critical/medium/low tier classification
```

---

## Memory Harvest Automation (Critical Priority)

This is the highest-value deliverable in task 597:

### Current State
```bash
# Count archived tasks with memory candidates
jq '.active_projects[] | select(.status == "completed") | 
    select(.memory_candidates | length > 0) | .project_number' specs/state.json | wc -l
# Expected: ~571 tasks
```

### Target Behavior

When /todo archives a task that has `memory_candidates`:
1. Invoke `memory-harvest.sh` before removing from `active_projects`
2. For each candidate with `confidence >= 0.7`: write to memory vault
3. Log how many memories were harvested

### Integration Point

In /todo's archival loop:
```bash
for task_number in "${tasks_to_archive[@]}"; do
  # ... archival logic ...

  # Harvest memory candidates before archiving
  memory_candidates=$(jq -r ".active_projects[] | 
    select(.project_number == $task_number) | 
    .memory_candidates // []" specs/state.json)
  
  if [ "$(echo "$memory_candidates" | jq 'length')" -gt 0 ]; then
    bash .claude/scripts/memory-harvest.sh "$task_number" "$memory_candidates"
  fi
done
```

---

## Verification

```bash
# Verify line counts
wc -l .claude/commands/task.md .claude/commands/revise.md \
       .claude/commands/todo.md .claude/commands/review.md

# Verify new utility modules exist
ls .claude/scripts/archive-task.sh \
   .claude/scripts/orphan-detection.sh \
   .claude/scripts/roadmap-sync.sh \
   .claude/scripts/vault-operation.sh \
   .claude/scripts/memory-harvest.sh

# Test memory harvest
# 1. Find a completed task with memory_candidates
# 2. Run /todo to archive it
# 3. Verify memories appear in .memory/ vault

# Test /revise orchestrator_mode
# 1. Invoke /revise with orchestrator_mode=true in delegation context
# 2. Verify .orchestrator-handoff.json written with correct schema
```
