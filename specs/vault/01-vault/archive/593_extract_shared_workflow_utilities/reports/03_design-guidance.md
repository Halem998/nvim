# Design Guidance: Task 593 — Extract Shared Workflow Utilities

**Source**: Task 592 architecture design
**Authoritative Reference**: `.claude/docs/architecture/architecture-spec.md` Component 1
**Depends on**: Task 592 (design, satisfied)
**Blocks**: Tasks 594, 595, 596, 597, 598

---

## Overview

Task 593 extracts ~525 lines of identical command logic into 4 shell scripts in `.claude/scripts/`.
After extraction, each command shrinks from ~500 lines to ~150-200 lines (routing-only controller).

---

## File Locations

### New Files (to create)
```
.claude/scripts/parse-command-args.sh     # Arg parsing: task numbers + flags
.claude/scripts/command-gate-in.sh        # CHECKPOINT 1: session + task lookup
.claude/scripts/command-gate-out.sh       # CHECKPOINT 2: artifact verification
.claude/scripts/postflight-workflow.sh    # Shared postflight operations
```

### Existing Files (unchanged)
```
.claude/scripts/update-task-status.sh    # Keep as-is
.claude/scripts/validate-artifact.sh     # Keep as-is
```

### Command Files (to modify)
```
.claude/commands/research.md             # Source new scripts
.claude/commands/plan.md                 # Source new scripts
.claude/commands/implement.md            # Source new scripts
```

---

## `parse-command-args.sh` Full Specification

**Purpose**: Parse `$ARGUMENTS` string → task number list + remaining flags + focus prompt.

### Exported Variables

| Variable | Type | Description |
|----------|------|-------------|
| `TASK_NUMBERS` | space-separated integers | Parsed task numbers (ranges expanded) |
| `REMAINING_ARGS` | string | Args after task numbers removed |
| `TEAM_MODE` | "true" or "false" | --team flag detected |
| `TEAM_SIZE` | integer 2-4 | --team-size value (default 2) |
| `EFFORT_FLAG` | "fast", "hard", or "" | --fast or --hard detected |
| `MODEL_FLAG` | "haiku", "sonnet", "opus", or "" | Model override flag |
| `CLEAN_FLAG` | "true" or "false" | --clean flag detected |
| `FORCE_FLAG` | "true" or "false" | --force flag (implement only) |
| `FOCUS_PROMPT` | string | Remaining text after all flags stripped |

### Algorithm

```bash
#!/usr/bin/env bash
# parse-command-args.sh
# Usage: source .claude/scripts/parse-command-args.sh "$ARGUMENTS"

parse_command_args() {
  local args="$1"

  # Step 1: Extract task spec (leading numbers, commas, ranges, spaces)
  local task_spec=$(echo "$args" | grep -oE '^[0-9][0-9, -]*')

  # Step 2: Expand ranges "22-24" → "22 23 24"
  TASK_NUMBERS=""
  for token in $(echo "$task_spec" | tr ',' ' '); do
    if echo "$token" | grep -q '-'; then
      start=$(echo "$token" | cut -d'-' -f1)
      end=$(echo "$token" | cut -d'-' -f2)
      for n in $(seq "$start" "$end"); do
        TASK_NUMBERS="$TASK_NUMBERS $n"
      done
    else
      TASK_NUMBERS="$TASK_NUMBERS $token"
    fi
  done
  TASK_NUMBERS=$(echo "$TASK_NUMBERS" | xargs)  # trim whitespace

  # Step 3: Scan for flags
  TEAM_MODE="false"
  TEAM_SIZE=2
  EFFORT_FLAG=""
  MODEL_FLAG=""
  CLEAN_FLAG="false"
  FORCE_FLAG="false"

  local remaining="${args#$task_spec}"  # strip task spec
  [[ "$remaining" =~ --team ]] && TEAM_MODE="true"
  [[ "$remaining" =~ --team-size=([0-9]+) ]] && TEAM_SIZE="${BASH_REMATCH[1]}"
  [[ "$remaining" =~ --fast ]] && EFFORT_FLAG="fast"
  [[ "$remaining" =~ --hard ]] && EFFORT_FLAG="hard"
  [[ "$remaining" =~ --haiku ]] && MODEL_FLAG="haiku"
  [[ "$remaining" =~ --sonnet ]] && MODEL_FLAG="sonnet"
  [[ "$remaining" =~ --opus ]] && MODEL_FLAG="opus"
  [[ "$remaining" =~ --clean ]] && CLEAN_FLAG="true"
  [[ "$remaining" =~ --force ]] && FORCE_FLAG="true"

  # Step 4: Strip flags → FOCUS_PROMPT
  FOCUS_PROMPT=$(echo "$remaining" | sed 's/--team[^ ]*//g; s/--fast//g; s/--hard//g;
    s/--haiku//g; s/--sonnet//g; s/--opus//g; s/--clean//g; s/--force//g' | xargs)

  # Step 5: Validate
  if [ -z "$TASK_NUMBERS" ]; then
    echo "ERROR: No task numbers found in arguments: $args" >&2
    exit 1
  fi

  export TASK_NUMBERS REMAINING_ARGS TEAM_MODE TEAM_SIZE EFFORT_FLAG MODEL_FLAG CLEAN_FLAG FORCE_FLAG FOCUS_PROMPT
}

parse_command_args "$1"
```

---

## `command-gate-in.sh` Full Specification

**Purpose**: CHECKPOINT 1 — session ID generation, task lookup, terminal status guard.

### Usage

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "$operation"
# operation: "research" | "plan" | "implement" | "revise"
```

### Exported Variables

| Variable | Type | Description |
|----------|------|-------------|
| `SESSION_ID` | string | `sess_{timestamp}_{random}` |
| `TASK_TYPE` | string | From state.json |
| `TASK_STATUS` | string | From state.json |
| `PROJECT_NAME` | string | From state.json |
| `DESCRIPTION` | string | From state.json |
| `PADDED_NUM` | string | `printf "%03d" $task_number` |

### Key Behaviors

```bash
#!/usr/bin/env bash
# command-gate-in.sh

gate_in() {
  local task_number="$1"
  local operation="$2"

  # Generate session ID
  SESSION_ID="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"

  # Pad task number
  PADDED_NUM=$(printf "%03d" "$task_number")

  # Look up task in state.json
  local task_data=$(jq -c ".active_projects[] | select(.project_number == $task_number)" specs/state.json)

  if [ -z "$task_data" ]; then
    echo "ERROR: Task $task_number not found in state.json" >&2
    exit 1
  fi

  TASK_TYPE=$(echo "$task_data" | jq -r '.task_type')
  TASK_STATUS=$(echo "$task_data" | jq -r '.status')
  PROJECT_NAME=$(echo "$task_data" | jq -r '.project_name')
  DESCRIPTION=$(echo "$task_data" | jq -r '.description')

  # Guard: terminal status check
  case "$TASK_STATUS" in
    completed|abandoned|expanded)
      echo "ABORT: Task $task_number is in terminal status: $TASK_STATUS" >&2
      exit 1
      ;;
  esac

  # Display operation header
  local op_label=$(echo "$operation" | tr '[:lower:]' '[:upper:]')
  echo "[$op_label] Task $task_number: $PROJECT_NAME"

  export SESSION_ID TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM
}

gate_in "$1" "$2"
```

---

## `command-gate-out.sh` Full Specification

**Purpose**: CHECKPOINT 2 — read skill return metadata, apply defensive status correction.

### Usage

```bash
source .claude/scripts/command-gate-out.sh "$task_number" "$operation" "$session_id"
```

### Key Behaviors

```bash
#!/usr/bin/env bash
# command-gate-out.sh

gate_out() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local padded_num=$(printf "%03d" "$task_number")

  # Get project name
  local project_name=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .project_name" specs/state.json)
  local task_dir="specs/${padded_num}_${project_name}"

  # Read skill return metadata
  local meta_file="${task_dir}/.return-meta.json"
  if [ ! -f "$meta_file" ]; then
    echo "WARNING: .return-meta.json not found — skill may have failed silently" >&2
    # Non-blocking: continue with defensive correction
  else
    local skill_status=$(jq -r '.status' "$meta_file")

    # Defensive status correction: if status stale in state.json, fix it
    local current_status=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .status" specs/state.json)
    if [ "$skill_status" = "implemented" ] && [ "$current_status" != "completed" ]; then
      echo "[gate-out] Defensive correction: setting status to completed"
      bash .claude/scripts/update-task-status.sh "$task_number" "completed" "$session_id"
    fi
  fi

  # Non-blocking: artifact link failure does not fail the gate
  bash .claude/scripts/validate-artifact.sh "$task_dir" --fix 2>/dev/null || true
}

gate_out "$1" "$2" "$3"
```

---

## Command Refactoring Target

After extraction, each command file retains:

| Section | Approx Lines |
|---------|-------------|
| YAML frontmatter | 5 |
| PROHIBITION section | 10 |
| Source parse-command-args.sh | 5 |
| Multi-task batch loop | 40 |
| Extension routing table (research.md only) | 30 |
| Source command-gate-in.sh | 5 |
| Skill delegation call | 20 |
| Source command-gate-out.sh | 5 |
| Git commit block | 15 |
| Error handling | 15 |
| **Total target** | **~150-200** |

**Currently**: ~500 lines per command (525 lines of duplication across 3 commands).

---

## Baseline Measurement Methodology

Before starting extraction, measure:

```bash
# Count lines per command file
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md

# Identify which blocks are identical (not just similar)
diff <(sed -n '/parse_task_args/,/^}/p' .claude/commands/research.md) \
     <(sed -n '/parse_task_args/,/^}/p' .claude/commands/plan.md)

# After extraction, re-measure to validate savings
```

Record measurements in the task summary artifact.

---

## Implementation Order

1. `parse-command-args.sh` — lowest risk, highest line savings (~165 lines)
2. `command-gate-in.sh` — prerequisite for further command simplification
3. `command-gate-out.sh` — eliminates defensive check duplication
4. Update research.md, plan.md, implement.md to source these scripts
5. `postflight-workflow.sh` — shared postflight (~130 lines)
6. Validate: run a research task end-to-end, confirm status transitions work

**Do NOT tackle skill-base.sh in task 593.** Save for task 594 (after task 598 context budgets).

---

## Verification

```bash
# Verify new script files exist and are non-empty
ls -la .claude/scripts/parse-command-args.sh \
       .claude/scripts/command-gate-in.sh \
       .claude/scripts/command-gate-out.sh \
       .claude/scripts/postflight-workflow.sh

# Verify command file line counts reduced
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md
# Each should be 150-200 lines

# Functional test: run research on a test task
# /research 593 (should produce research report with proper status transitions)
```
