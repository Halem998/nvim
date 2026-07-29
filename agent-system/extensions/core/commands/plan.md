---
description: Create implementation plan for a task
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBERS [--team [--team-size N]] [--fast|--hard] [--haiku|--sonnet|--opus|--fable]
model: opus
---

# /plan Command

Create a phased implementation plan for a task by delegating to the planner skill/subagent.

## Arguments

- `$1` - Task number(s) (required). Supports:
  - Single task: `352`
  - Comma-separated: `7, 22, 59`
  - Ranges: `22-24`
  - Combined: `7, 22-24, 59`
- Remaining args - Optional flags

When multiple task numbers are provided, the command enters multi-task mode (see STAGE 0 below). Single task numbers fall through to the existing single-task flow unchanged.

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--team` | Enable multi-agent parallel planning with multiple teammates | false |
| `--team-size N` | Number of planning teammates to spawn (2-3) | 2 |
| `--fast` | Low-effort mode: lighter reasoning, faster responses | false |
| `--hard` | High-effort mode: deeper reasoning, more thorough analysis | false |
| `--haiku` | Use Haiku model (fastest, lowest cost) | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--fable` | Use Fable model (claude-fable-5) | false |
| `--clean` | Skip automatic memory retrieval | false |
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based planning | false |
| `--roadmap` | Include ROADMAP.md review/update phases in plan | false |

When `--team` is specified, planning is delegated to `skill-team-plan` which spawns multiple planning agents generating alternative plans in parallel. Each teammate produces a plan candidate, and the lead synthesizes findings into a final plan with trade-off analysis.

**Note**: Team mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable. If unavailable, gracefully degrades to single-agent planning.

## Anti-Bypass Constraint

**PROHIBITION**: You MUST NOT write plan artifacts directly using Write or Edit tools. All plan files MUST be created by invoking the appropriate skill (skill-planner or skill-team-plan) via the Skill tool.

**Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.

**Required**: Always delegate to the Skill tool. Never write to `specs/*/plans/*.md` directly from this command.

## Execution

### STAGE 0: PARSE TASK NUMBERS

**Parse task arguments to separate task numbers from remaining args.**

```bash
parse_task_args() {
  local input="$1"
  local task_spec=""
  local remaining=""

  # Match leading task specification: digits, commas, hyphens, spaces
  # Stop at first alphabetic char or -- flag
  if [[ "$input" =~ ^([0-9][0-9,\ \-]*)(\ +.*)?$ ]]; then
    task_spec="${BASH_REMATCH[1]}"
    remaining="${BASH_REMATCH[2]}"
  else
    echo "[FAIL] No task number found in arguments"
    return 1
  fi

  # Trim trailing whitespace/commas from task_spec
  task_spec=$(echo "$task_spec" | sed 's/[, ]*$//')

  # Parse through existing parse_ranges()
  task_numbers=($(parse_ranges "$task_spec"))

  # Trim leading whitespace from remaining
  remaining=$(echo "$remaining" | sed 's/^[[:space:]]*//')

  echo "TASK_NUMBERS=${task_numbers[*]}"
  echo "REMAINING_ARGS=$remaining"
}
```

**Examples**:

| Input | task_numbers | remaining_args | Mode |
|-------|-------------|----------------|------|
| `7` | `[7]` | `` | single |
| `7, 22-24, 59` | `[7, 22, 23, 24, 59]` | `` | multi |
| `7 --team` | `[7]` | `--team` | single |
| `7, 22-24 --team` | `[7, 22, 23, 24]` | `--team` | multi |
| `42 --team --team-size 3` | `[42]` | `--team --team-size 3` | single |

**Dispatch decision**:

```
task_numbers = parse_task_args($ARGUMENTS)

if len(task_numbers) == 1:
    # SINGLE-TASK MODE
    task_number = task_numbers[0]
    # Fall through to CHECKPOINT 1: GATE IN below
    # Existing single-task flow proceeds unchanged

elif len(task_numbers) > 1:
    # MULTI-TASK MODE
    # Continue to MULTI-TASK DISPATCH below
```

### MULTI-TASK DISPATCH

When `parse_task_args()` produces more than one task number, execute the batch flow below instead of the single-task checkpoints.

#### Step 1: Batch Validation

Validate all tasks exist and are not in a terminal state:

```bash
validated_tasks=()
invalid_tasks=()

for task_num in "${task_numbers[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    invalid_tasks+=("$task_num: not found")
    continue
  fi

  status=$(echo "$task_data" | jq -r '.status')

  # /plan accepts any non-terminal status
  if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
    invalid_tasks+=("$task_num: terminal status [$status]")
  else
    validated_tasks+=("$task_num")
  fi
done

# Report invalid tasks but continue with valid ones
if [ ${#invalid_tasks[@]} -gt 0 ]; then
  echo "[WARN] Skipping invalid tasks:"
  for msg in "${invalid_tasks[@]}"; do
    echo "  - $msg"
  done
fi

if [ ${#validated_tasks[@]} -eq 0 ]; then
  echo "[FAIL] No valid tasks to process"
  exit 1
fi
```

#### Step 2: Generate Batch Session ID

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

Register the in-flight session registry entry for this batch. **Use the bare `batch_session_id`
here — never a `_${task_num}`-suffixed derivative.** Step 3 below suffixes the same variable
per-task for its own task-lock acquire/release calls; the registry entry is batch-scoped, not
per-task, so it stays keyed on the unsuffixed value. Best-effort and non-blocking (a registration
failure must never affect any admission or dispatch decision):

```bash
bash .claude/scripts/task-lock.sh session-register "$batch_session_id" "/plan (multi-task)" "$(IFS=,; echo "${validated_tasks[*]}")" 2>/dev/null || true
```

#### Step 2.5: Batch Admission Pre-Check (Gap C)

Before the per-task acquire loop in Step 3, check the whole validated set against
`orchestrate-batch-admit.sh`'s bounded conflict-detection predicate (cross-batch `file_scope`
collisions, the self-modification hazard, and live session-registry contention). This is
DETECTION only — a deferred task is moved out of `validated_tasks` here exactly the same way
Step 3 already moves a lock-refused task to `invalid_tasks`; this step only adds an earlier,
cheaper check for the gap `.claude/context/patterns/batch-orchestration-guardrails.md` already
names for the plain multi-task command paths. Must run AFTER session-register (above), passing
`--session-id "$batch_session_id"` — see D6 in the originating plan for why: without it,
`orchestrate-batch-admit.sh` would see the just-registered batch session as foreign and defer
every candidate against itself.

```bash
admit_output=$(bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#validated_tasks[@]}" --session-id "$batch_session_id" "${validated_tasks[@]}" 2>/dev/null)
while IFS= read -r verdict; do
  [ -z "$verdict" ] && continue
  decision=$(echo "$verdict" | jq -r '.decision // ""')
  [ "$decision" = "defer" ] || continue
  t=$(echo "$verdict" | jq -r '.task_number')
  defer_reason=$(echo "$verdict" | jq -r '.defer_reason // "unknown"')
  reason_text=$(echo "$verdict" | jq -r '.reason // "deferred by batch admission"')
  # EXCLUDE, never auto-expand: remove $t from validated_tasks, never pull anything else in.
  new_validated=()
  for existing in "${validated_tasks[@]}"; do
    [ "$existing" = "$t" ] || new_validated+=("$existing")
  done
  validated_tasks=("${new_validated[@]}")
  invalid_tasks+=("$t: deferred by batch admission [$defer_reason]")
  echo "[WARN] Task #$t deferred by batch admission ($defer_reason): $reason_text" >&2
done <<< "$admit_output"

if [ ${#validated_tasks[@]} -eq 0 ]; then
  echo "[FAIL] No valid tasks remain after batch admission — every candidate was deferred." >&2
  exit 1
fi
```

#### Step 3: Dispatch Skills

This multi-task loop bypasses `command-gate-in.sh`/`command-gate-out.sh` entirely (those are
only sourced by the single-task path below), so each per-task dispatch acquires/releases the
task lock itself, mirroring `implement.md`'s Step 3. See
`.claude/context/patterns/task-lock.md` for the full contract.

For each validated task, invoke the appropriate planner skill using parallel Skill tool calls from the orchestrator's built-in batch loop:

1. Extract task_type per task from state.json
2. Route each task to the appropriate planner skill (extension routing or default `skill-planner`)
3. **Before** invoking the skill for a task: `bash .claude/scripts/task-lock.sh acquire "$task_num" plan "${batch_session_id}_${task_num}" "/plan (multi-task)"`. If this refuses (exit 1 — a fresh lock held by a genuinely different session; same-session re-entry never refuses), move that task from `validated_tasks` to `skipped_tasks`/`invalid_tasks` with reason `"locked by another session"` and do NOT invoke its skill this run.
4. Invoke all skills in a single message (parallel execution, one skill per task)
5. Each skill runs the full single-task planning lifecycle independently (preflight, agent delegation, postflight)
6. Collect text results from all skills; read `.return-meta.json` in each task directory for structured data if needed
7. **After** each task's skill invocation completes (success, partial, or failed): `bash .claude/scripts/task-lock.sh release "$task_num" "${batch_session_id}_${task_num}"` — unconditional, run regardless of outcome.

**Note**: Batch dispatch is handled directly by this command's orchestrator loop via parallel Skill tool calls, not by a separate batch skill.

**No intra-batch session-registry heartbeat**: this step dispatches all validated tasks in a
single parallel batch and waits for every result — there is no per-cycle loop boundary to
heartbeat at, unlike `skill-orchestrate`'s multi-cycle dispatch. This is an intentional omission,
not a gap to "fix" later.

#### Step 4: Batch Git Commit

Release the batch's in-flight session registry entry now, so it is cleaned up regardless of any
individual task's outcome above. Best-effort and non-blocking:

```bash
bash .claude/scripts/task-lock.sh session-release "$batch_session_id" 2>/dev/null || true
```

After all skills return, produce a single git commit. Per-skill postflight may have already committed individual task changes; this batch commit captures any remaining unstaged changes and may be empty (which fails gracefully).

**Full success**:
```
plan tasks {range_summary}: create implementation plan

Tasks: {comma-separated list}
Session: {batch_session_id}
```

**Partial success**:
```
plan tasks {range_summary}: create implementation plan ({succeeded}/{total} succeeded)

Tasks completed: {comma-separated}
Tasks failed: {num} ({reason})[, {num} ({reason})]
Session: {batch_session_id}
```

#### Step 5: Consolidated Output

```markdown
## Batch Plan Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {count}
Failed: {count}
Skipped: {count}

### Succeeded

| Task | Title | Status | Artifact |
|------|-------|--------|----------|
| #7 | task_title | [PLANNED] | specs/007_slug/plans/01_short.md |
| #22 | task_title | [PLANNED] | specs/022_slug/plans/01_short.md |

### Failed

| Task | Error |
|------|-------|
| #23 | Invalid status [IMPLEMENTING] |

### Skipped

| Task | Reason |
|------|--------|
| #99 | Not found in state.json |

### Next Steps
- /implement 7, 22, 24, 59
```

**End of multi-task flow. Do NOT continue to the single-task checkpoints below.**

---

**The sections below handle SINGLE-TASK mode only (when `parse_task_args()` produces exactly one task number).**

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "plan"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [PLAN] Task {N}: {project_name}
# Aborts if task not found, in terminal status, or the task lock is refused (same-task
# different-session, or a cross-task file_scope overlap per the cross-task
# file_scope overlap check)
```

Note: the header now reads `[PLAN]` (gate-in's mechanical uppercasing of the operation string),
replacing the prior `[Planning]` present-participle wording — an intentional cosmetic change
from a gate-in refactor, not a defect.

**Load Context** (plan-specific; no gate-script equivalent — must stay inline):
- Task description: `$DESCRIPTION` (from gate-in)
- Research reports from `specs/${PADDED_NUM}_${PROJECT_NAME}/reports/` (if any)
- Discover prior plan (if any):
  ```bash
  prior_plan_path=$(ls -1 "specs/${PADDED_NUM}_${PROJECT_NAME}/plans/"*.md 2>/dev/null | sort -V | tail -1)
  ```

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 1.5 below.

### STAGE 1.5: PARSE FLAGS

**Parse arguments to determine team mode, effort level, and model override.**

1. **Extract Team Options**
   Check args for team flags:
   - `--team` -> `team_mode = true`
   - `--team-size N` -> `team_size = N` (clamp 2-3)

   If no team flag found: `team_mode = false`, `team_size = 2`

2. **Validate Team Size**
   ```bash
   # Clamp team_size to valid range (2-3 for planning)
   team_size=${team_size:-2}
   [ "$team_size" -lt 2 ] && team_size=2
   [ "$team_size" -gt 3 ] && team_size=3
   ```

3. **Extract Effort Flags**
   Check remaining args for effort flags:
   - `--fast` -> `effort_flag = "fast"` (low-effort mode: lighter reasoning)
   - `--hard` -> `effort_flag = "hard"` (high-effort mode: deeper reasoning)

   If multiple are provided, last one wins.
   If none: `effort_flag = null` (normal effort)

4. **Extract Model Flags**
   Check remaining args for model flags:
   - `--haiku` -> `model_flag = "haiku"` (use Haiku model)
   - `--sonnet` -> `model_flag = "sonnet"` (use Sonnet model)
   - `--opus` -> `model_flag = "opus"` (use Opus model)
   - `--fable` -> `model_flag = "fable"` (use Fable model)

   If multiple are provided, last one wins.
   If none: `model_flag = null` (use agent's frontmatter default: opus for planner/meta-builder/reviser; sonnet for general-purpose agents)

5. **Extract Clean Flag**
   Check remaining args for memory retrieval suppression:
   - `--clean` -> `clean_flag = true` (skip automatic memory retrieval)

   If not present: `clean_flag = false`

6. **Extract Lit Flag**
   Check remaining args for literature mode:
   - `--lit` -> `lit_flag = true` (literature-based task: paper-to-code, spec-to-implementation)

   If not present: `lit_flag = false`

7. **Extract Roadmap Flag**
   Check remaining args for roadmap phase injection:
   - `--roadmap` -> `roadmap_flag = true` (add ROADMAP.md review/update phases to plan)

   If not present: `roadmap_flag = false`

**On STAGE 1.5 success**: Flags parsed. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After STAGE 1.5 completes, immediately invoke the Skill tool.

**Team Mode Routing** (when `--team` flag present):

If `team_mode == true`:
- Route to `skill-team-plan`
- Pass `team_size` parameter

**Extension Routing** (when `--team` flag NOT present):

Check extension manifests for task-type-specific plan routing:

```bash
# task_type (may be simple "founder" or compound "founder:deck") comes from gate-in's
# exported TASK_TYPE (CHECKPOINT 1) — no separate task_data lookup needed here.
task_type="$TASK_TYPE"

# Check extension routing for plan (skill_name starts empty)
skill_name=""
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_skill=$(jq -r --arg tt "$task_type" \
      '.routing.plan[$tt] // empty' "$manifest")
    if [ -n "$ext_skill" ]; then
      skill_name="$ext_skill"
      break
    fi
  fi
done

# Fallback: if compound key (contains ":"), try base task_type
if [ -z "$skill_name" ] && echo "$task_type" | grep -q ":"; then
  base_type=$(echo "$task_type" | cut -d: -f1)
  for manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$manifest" ]; then
      ext_skill=$(jq -r --arg tt "$base_type" \
        '.routing.plan[$tt] // empty' "$manifest")
      if [ -n "$ext_skill" ]; then
        skill_name="$ext_skill"
        break
      fi
    fi
  done
fi

# Fallback to default planner if no extension routing found
skill_name=${skill_name:-"skill-planner"}
```

**Extension-Based Routing Table**:

| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-founder-plan` (from founder extension) |
| `founder:deck` | `skill-deck-plan` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-plan` |
| Other | `skill-planner` (default) |

**Skill Selection Logic**:
```
if team_mode:
  skill_name = "skill-team-plan"
else:
  skill_name = {extension routing lookup} OR "skill-planner"
```

**Invoke the Skill tool NOW** with:
```
# For team mode:
skill: "skill-team-plan"
args: "task_number={N} research_path={path to research report if exists} prior_plan_path={path to prior plan if exists} team_size={team_size} session_id={SESSION_ID} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag} lit_flag={lit_flag}"

# For extension-routed skill (e.g., skill-founder-plan):
skill: "{skill_name from extension routing}"
args: "task_number={N} research_path={path to research report if exists} prior_plan_path={path to prior plan if exists} session_id={SESSION_ID} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag} lit_flag={lit_flag}"

# For default single-agent mode:
skill: "skill-planner"
args: "task_number={N} research_path={path to research report if exists} prior_plan_path={path to prior plan if exists} session_id={SESSION_ID} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag} lit_flag={lit_flag}"
```

If `model_flag` is set, pass the `model` parameter to override the agent's default model:
- `model_flag="haiku"` -> pass `model: haiku`
- `model_flag="sonnet"` -> pass `model: sonnet`
- `model_flag="opus"` -> pass `model: opus`
- `model_flag="fable"` -> pass `model: fable`
- `model_flag=null` -> omit `model` parameter (use agent's frontmatter default: opus for planner/meta-builder/reviser; sonnet for general-purpose agents)

If `effort_flag` is set, pass it as prompt context to the skill/agent for reasoning depth guidance.

The skill spawns agent(s) which analyze task requirements and research findings, decompose into logical phases, identify risks and mitigations, and create a plan in `specs/{NNN}_{SLUG}/plans/`.

**On DELEGATE success**: Plan created. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   Required fields: status, summary, artifacts, metadata (phase_count, estimated_hours)

2. **Verify Artifacts**
   Check plan file exists on disk

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "plan" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
# status_token mapping (Phase 1 of the gate-in refactor): operation "plan" -> target_status "plan"
# Runs validate-artifact.sh --fix (non-blocking)
# Defensive correction (state.json + TODO.md) handled by this script
```

3. **Verify Plan File Status (Defensive; plan-specific — no gate-script equivalent)**

   **Only when skill reports success:**

   Check that the plan file status marker shows `[NOT STARTED]` (expected state for a newly created plan). If it shows something unexpected like `[PLANNING]`, log a warning:

   ```bash
   # Find latest plan file
   plan_file=$(ls -1 "specs/${PADDED_NUM}_${PROJECT_NAME}/plans/"*.md 2>/dev/null | sort -V | tail -1)

   if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
       # Check if plan file has a valid status (NOT STARTED or IMPLEMENTING)
       if grep -qE '^\*\*Status\*\*: \[PLANNING\]|^\- \*\*Status\*\*: \[PLANNING\]' "$plan_file"; then
           echo "WARNING: Plan file status still shows [PLANNING]. Expected [NOT STARTED] for newly created plan."
       fi
   fi
   ```

**RETRY** skill if validation fails.

**On GATE OUT success**: Plan verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

### CHECKPOINT 3: COMMIT

Apply the `plan` scope from `.claude/context/standards/git-staging-scope.md` — targeted staging,
never a repo-wide add:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
git add \
  "specs/${padded_num}_${project_name}/" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "$(cat <<'EOF'
task {N}: create implementation plan

Session: {session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

## Output

```
Plan created for Task #{N}

Plan: specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md

Phases: {phase_count}
Estimated effort: {estimated_hours}

Status: [PLANNED]
Next: /implement {N}
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Terminal status (completed/abandoned): Return error with current status
- Locked by another session: `command-gate-in.sh` propagates `task-lock.sh acquire`'s refusal
  (a fresh lock held by a genuinely different session) — ABORT with the lock's held-by/reason
  message; re-run once the other session's operation completes or its lock goes stale
- Cross-task `file_scope` overlap (the cross-task file_scope overlap check): if another currently-locked task's `file_scope`
  overlaps this task's and that lock is fresh, `/plan` ABORTs before DELEGATE, naming the
  conflicting task number — this is a new failure mode `/plan` did not have before this
  gate-in refactor; re-run once the other task's lock releases or goes stale
- Multi-task mode: the per-task lock-acquire refusal above moves that task from
  `validated_tasks` to `invalid_tasks` with reason `"locked by another session"` (skip, not a
  batch-abort)
- Multi-task mode, batch admission (Step 2.5, Gap C): `orchestrate-batch-admit.sh` deferring a
  candidate (`file_scope_collision`, `self_modifying`, or `session_active`) moves that task from
  `validated_tasks` to `invalid_tasks` with reason `"deferred by batch admission [{defer_reason}]"`
  (skip, not a batch-abort — same shape as the lock-acquire refusal bullet above, just earlier and
  cheaper)

### DELEGATE Failure
- Skill fails: Keep [PLANNING], log error
- Timeout: Partial plan preserved, user can re-run

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Link failure: Non-blocking warning
