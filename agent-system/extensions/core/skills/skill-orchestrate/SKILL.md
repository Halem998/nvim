---
name: skill-orchestrate
description: Autonomous state machine that drives a task through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases. Invoke for /orchestrate command.
allowed-tools: Agent, Bash, Read, Edit
---

# Orchestrate Skill

Fire-and-forget autonomous loop implementing the 10-state task lifecycle state machine.
Drives research, planning, implementation, and blocker escalation without user interaction.

## Context References

Architecture documentation (load as needed):
- `.claude/docs/architecture/orchestrate-state-machine.md` - Complete state table and transition diagram
- `.claude/docs/architecture/handoff-schema.md` - Orchestrator handoff JSON schema

Infrastructure (source as needed):
- `.claude/scripts/skill-base.sh` - Shared skill lifecycle functions

---

## Execution Flow

### Stage 0: Multi-Task Mode Detection

Parse `multi_task_mode` from the delegation context. If true, branch to multi-task stages (MT-1 through MT-5) in the **Multi-Task Mode** section below. If false or absent, fall through to Stage 1 (single-task mode).

Read from delegation context:
- `multi_task_mode` (default: false)
- `session_id`
- `focus_prompt` (default: "")
- `lit_flag` (default: "false")

If `multi_task_mode` is true: skip Stages 1-8 entirely and proceed to Stage MT-1.

---

### Stage 1: Input Validation

Read from delegation context:
- `task_number` (from `task_context.task_number`)
- `session_id`, `focus_prompt`, `lit_flag`
- `continue_budget` (default: `false`) → `continue_budget_flag`. Defect B: explicit,
  operator-typed budget-continuation override for an exhausted work-cycle budget, threaded from
  the command's `--continue-budget` flag. Never inferred from `session_id`, mtime, or any
  automatic signal. See Stage 2 below for the override mechanism.

Resolve from `specs/state.json`:
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DATA=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)
```

If `TASK_DATA` is empty: exit with error "Task $task_number not found in state.json".

Extract: `PROJECT_NAME`, `TASK_TYPE` (default: "general"), `DESCRIPTION`, `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`.

Then resolve the absolute anchor that every dispatched agent will be handed. `TASK_DIR` stays
relative (many consumers below depend on that); `TASK_DIR_ABS` is the anchor that goes into
delegation contexts, because a dispatched agent has no reliable way to know what the ambient
working directory will be when its Write tool runs.

```bash
# SKILL_REPO_ROOT is exported by skill-base.sh, which resolves it from BASH_SOURCE rather than
# from the ambient cwd. $(pwd) is a last-resort fallback for direct invocation.
TASK_DIR_ABS="${TASK_DIR_ABS:-${SKILL_REPO_ROOT:-$(pwd)}/${TASK_DIR}}"
HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
```

### Stage 1b: Resolve Task-Type Routing

Map task_type to the correct research, plan, and implementation agents via the single canonical
agent resolver, `command-route-agent.sh` — sourced from the shared manifest-routing-lib.sh
ladder (the same one `command-route-skill.sh` uses), against each manifest's `routing_agents`
declarations. No case table, no directory probe, no sed derivation: agent names are declared
data, not derived strings (see `context/guides/manifest-routing-schema.md`).

```bash
source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-agent" ""
RESEARCH_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "plan" "$TASK_TYPE" "planner-agent" ""
PLANNER_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "implement" "$TASK_TYPE" "general-implementation-agent" ""
IMPLEMENT_AGENT="$AGENT_NAME"
echo "[orchestrate] Task type: $TASK_TYPE → research=$RESEARCH_AGENT, plan=$PLANNER_AGENT, implement=$IMPLEMENT_AGENT"
```

### Stage 2: Loop Guard Initialization

Create or read the loop guard file. This tracks cycle count across conversational turns.

**Ephemeral, never committed.** `.orchestrator-loop-guard` is per-cycle runtime state with no
freshness check on read (see the resume branch below: any syntactically valid guard file at this
path is trusted, with no `session_id` or mtime comparison against the current dispatch). A
git-restored copy of a stale guard would silently resume a wrong `cycle_count`/`infra_failures`
pair — exactly the hazard this file's gitignore coverage exists to prevent. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

```bash
MAX_CYCLES=5
# Infrastructure-failure counter, separate from the work-cycle budget. See
# context/patterns/infra-failure-discrimination.md. Flat (not scaled with MAX_CYCLES):
# transport flakiness is unrelated to plan size.
MAX_INFRA_FAILURES=3
loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"
# Absolute: this must name the same file the dispatched agent was told to write, and that
# instruction is absolute. Comparing a relative read path against an absolute write path is how
# a misplaced handoff goes unnoticed.
handoff_file="${HANDOFF_PATH_ABS}"

mkdir -p "$TASK_DIR"

# --- budget-continuation-override:begin ---
# Defect B: cycle_count is a per-task, CUMULATIVE budget that survives re-invocation BY DESIGN --
# it is deliberately NOT reset on a new session_id, because that would let an operator silently
# bypass MAX_CYCLES by simply re-invoking /orchestrate. test-session-runtime-files.sh Case 3 is
# the regression protecting this decision; this override must never disturb it. The override
# below is the sanctioned, explicit, loudly-logged escape hatch for a genuinely exhausted budget
# -- never automatic, never session_id-gated, never inferred from mtime. Verbatim-twin mechanism
# to skill-orchestrate-hard/SKILL.md's Stage 2 (base mode has no loop-guard-staleness detector to
# sit after, so this runs immediately before the pre-existing resume-read block below).
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  peek_cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  if [ "$peek_cycle_count" -ge "$MAX_CYCLES" ]; then
    if [ "$continue_budget_flag" = "true" ]; then
      exhaust_ts=$(date -u +%s)
      exhausted_guard_dest="${TASK_DIR}/.exhausted-loop-guard-${exhaust_ts}.json"
      echo "[orchestrate] BUDGET EXHAUSTED (cycle_count=${peek_cycle_count}/${MAX_CYCLES}) — --continue-budget authorized a fresh budget. Archiving exhausted guard to ${exhausted_guard_dest} for auditability, reinitializing at cycle_count=0 with cross-invocation history fields (dispatch_seq_counter, detected_defects) preserved." >&2
      if cp "$loop_guard_file" "$exhausted_guard_dest" 2>/dev/null; then
        # Reinit IN PLACE from the just-archived copy: reset only cycle_count, never wipe
        # dispatch_seq_counter (must never repeat a value within this task) or detected_defects.
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$exhausted_guard_dest" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      else
        echo "[orchestrate] WARNING: could not archive exhausted guard to ${exhausted_guard_dest}; proceeding without archiving (cycle_count reset in place)." >&2
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      fi
    else
      echo "[orchestrate] ERROR: work-cycle budget exhausted (cycle_count=${peek_cycle_count}/${MAX_CYCLES}). This is a budget limit, not an error condition -- the task's plan may still have incomplete phases." >&2
      echo "[orchestrate] To continue this task's work, explicitly authorize a fresh budget: /orchestrate ${task_number} --continue-budget" >&2
      exit 1
    fi
  fi
fi
# --- budget-continuation-override:end ---

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard. No session_id or mtime check — see the ephemerality note above;
  # this is precisely why a git-restorable guard would corrupt the cycle budget.
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  # System-defect observation log for this run (contract: Stage MT-1's `detected_defects`
  # declaration). `// []` is the forward-compatible read for a guard file written before this
  # field existed, matching the `// 0` idiom above.
  detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
  # dispatch_seq_counter: orchestrator-minted per-dispatch identity (Defect A), verbatim-twin
  # field to skill-orchestrate-hard/SKILL.md's Stage 2. `// 0` forward-compatible read, matching
  # cycle_count's own idiom — a guard written before this field existed resumes at 0, never
  # repeating a value already minted this task since the counter only ever increments (see
  # mint_dispatch_seq() below).
  dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
  # Observational-only session_id tracking (NEVER a gate — see Ephemeral note above and
  # context/standards/status-markers.md's rationale: SESSION_ID is regenerated per /orchestrate
  # invocation, while this guard is explicitly designed to survive across conversational turns.
  # The real same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not
  # session_id equality). A mismatch is logged, never branched on.
  guard_session_id=$(jq -r '.session_id // ""' "$loop_guard_file")
  if [ -n "$guard_session_id" ] && [ "$guard_session_id" != "$session_id" ]; then
    echo "[orchestrate] INFO: loop guard was last written by a different session_id ('${guard_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
  fi
  echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker. A plain
  # `>` redirect has no O_EXCL semantics, so two racing writers could both take
  # this branch and stomp each other's counters; init-marker's mkdir-gate +
  # tmp-mv payload guarantees exactly one winner. On a lost race (exit 1),
  # degrade to the same resume-read the `if`-branch above performs.
  if jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --argjson max_infra_failures "$MAX_INFRA_FAILURES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "infra_failures": 0,
      "max_infra_failures": $max_infra_failures,
      "current_state": "reading",
      "detected_defects": [],
      "started": $started,
      "last_updated": $started,
      "dispatch_seq_counter": 0
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    infra_failures=0
    detected_defects='[]'
    dispatch_seq_counter=0
    echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES, MAX_INFRA_FAILURES=$MAX_INFRA_FAILURES"
  else
    # Lost the creation race: another writer won. Resume from their guard, reading BOTH
    # counters — not just cycle_count — and the system-defect observation log alongside them.
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
    dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
    echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
  fi
fi

# mint_dispatch_seq(): increments the dispatch_seq_counter persisted in the loop guard and
# returns the new value on stdout. Verbatim-twin helper to
# skill-orchestrate-hard/SKILL.md's Stage 2 mint_dispatch_seq(). Call immediately before every
# Agent dispatch that writes .orchestrator-handoff.json, adjacent to the dispatch_start_ts
# capture (Defect A). Persisting on every mint (not only at Stage 3b) guarantees the value
# survives a resume and is never repeated within this task, even across separate /orchestrate
# invocations. See context/patterns/dispatch-report-not-termination.md for why an
# orchestrator-minted value is required rather than content the dispatched agent could echo
# unprompted.
mint_dispatch_seq() {
  dispatch_seq_counter=$((dispatch_seq_counter + 1))
  jq --argjson seq "$dispatch_seq_counter" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.dispatch_seq_counter = $seq | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "$dispatch_seq_counter"
}

# Blocker escalation counter (reset each /orchestrate invocation)
blocker_escalation_count=0
MAX_BLOCKER_ESCALATIONS=2

# Drift detection constants (reset each /orchestrate invocation)
drift_inspection_count=0
MAX_DRIFT_INSPECTIONS=1
DRIFT_COMPLETION_THRESHOLD=0.70
DRIFT_REVISION_THRESHOLD=0.30
```

**On the `budget-continuation-override` region above (Defect B)**: this rewrites the SAME
`loop_guard_file` in place (via the archived copy), specifically so `dispatch_seq_counter` and
`detected_defects` are carried forward rather than reset to their fresh-init defaults. This is
the same mechanism `skill-orchestrate-hard/SKILL.md`'s Stage 2 implements — the decision is
identical in both engines — but the mechanism itself is necessarily NET-NEW code here rather than
a byte-for-byte mirror, because base mode has no `loop-guard-staleness` detector region for it to
sit adjacent to.

**Decision record**: `cycle_count` is a per-task, cumulative budget that survives re-invocation by
design — this is the existing, deliberate semantics (protected by
`test-session-runtime-files.sh` Case 3), not a new decision introduced by this override. The same
record appears in `skill-orchestrate-hard/SKILL.md`'s Stage 2 so both engines visibly agree.

**Asymmetry decision (recorded, "recorded not acted on" style, mirroring the hard engine's
record so the two visibly agree)**: whether base mode should ever gain the general 3-signal
`loop-guard-staleness` detector hard mode has is a SEPARATE, undecided question — its absence
here remains deliberate and is not settled by adding the budget-continuation override, which is
orthogonal to it and requires no such detector to function correctly.

### Stage 3: State Machine Loop

**Entry reconcile (once per invocation, never per-cycle)**: before the state machine loop opens,
run `reconcile-task-status.sh` exactly once against this task. The failure this repairs is a
*previous, separate* invocation that crashed before postflight — observable only at the start of
a fresh invocation, not on every cycle iteration (a per-cycle call here would be redundant cost
against up to `MAX_CYCLES` iterations and would fight the preflight writes `skill_preflight_update`
already makes between dispatches within this same run). Live (not `--dry-run`): no human is
reliably present to gate on in `/orchestrate`'s no-confirmation design, and the handoff-aware
promotion guard now bounds what an automatic promotion can do. Bracketed because a live no-op
prints nothing — the empty-output branch must still be visible:

```bash
recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
if [ -n "$recon_out" ]; then
  echo "$recon_out"
else
  echo "[orchestrate] Entry reconcile: no stranded status found for task $task_number"
fi
```

The loop runs until a terminal condition is reached or MAX_CYCLES is hit.

```
while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
```

At the top of each iteration:

**3a. Read current task status**

```bash
current_status=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  specs/state.json)
echo "[orchestrate] Cycle $((cycle_count + 1))/$MAX_CYCLES — status: $current_status"
```

**3b. Update loop guard with current state**

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
   --arg sid "$session_id" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .last_session_id = $sid' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"

# Task-lock heartbeat: refresh at the same per-cycle boundary as the loop guard, so a
# multi-hour single-task /orchestrate run (whose lock was acquired once at orchestrate.md's
# CHECKPOINT 1) never goes stale under its own hand. No-op with a warning if the lock is
# somehow missing or held by another session — heartbeat never blocks this loop. See
# .claude/context/patterns/task-lock.md.
bash .claude/scripts/task-lock.sh heartbeat "$task_number" "$session_id" 2>/dev/null || true

# In-flight session registry heartbeat: same per-cycle boundary, refreshing the entry
# command-gate-in.sh registered at CHECKPOINT 1. Best-effort and non-blocking. See
# .claude/context/patterns/task-lock.md's Session-Registry CLI section.
bash .claude/scripts/task-lock.sh session-heartbeat "$session_id" 2>/dev/null || true
```

**3c. Dispatch by state** (see State Handlers in Stage 4)

---

### Stage 4: State Handlers

#### State: `not_started` or `not started`

```bash
skill_preflight_update "$task_number" "research" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Research task $task_number: $DESCRIPTION" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff (Stage 5). Increment cycle_count.

#### State: `researching`

In-flight state (another session is actively researching). Exit with warning.

```
echo "[orchestrate] WARNING: Task $task_number is currently being researched in another session."
echo "Wait for the research to complete, then run /orchestrate $task_number again."
EXIT (partial)
```

#### State: `researched`

Read research artifact path from state.json:
```bash
research_artifact=$(jq -r --argjson num "$task_number" \
  '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
  specs/state.json)
```

```bash
skill_preflight_update "$task_number" "plan" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$PLANNER_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Create implementation plan for task $task_number" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

#### State: `planning`

In-flight state. Exit with warning (same pattern as `researching`).

#### State: `planned` or `implementing`

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

```bash
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

#### State: `partial`

**Cross-reference**: the identical triage rule applied by hand below is also available as an
executable check, `scripts/orchestrate-triage-classify.sh single`. That script is the executable
form of this same rule, including its dual-form continuation-pointer resolution (nested
`continuation_context.handoff_path` OR flat `continuation_path`), and both engines now agree on
every row here except `blocked` (see the justification in the "State: `blocked`" handler below).

Read `.orchestrator-handoff.json` to determine sub-state:

```bash
handoff=$(cat "$handoff_file" 2>/dev/null || echo '{}')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
# Dual-form resolution + normalization: a continuation pointer may arrive as either the
# deprecated, read-only-accepted nested continuation_context.handoff_path (no writer emits this
# today -- its sole writer function has been deleted) OR the flat top-level continuation_path
# (the one canonical form live H9 hard-mode wrap-up writers actually emit). Resolve either form
# and normalize into the single shape the dispatch context below and
# context/patterns/subagent-continuation-loop.md both
# expect: { handoff_path, orchestrator_mode: true }, or null if neither form is present. This
# mirrors scripts/orchestrate-triage-classify.sh's continuation_ok predicate exactly — do not let
# this hand-applied copy drift from that script again.
continuation=$(echo "$handoff" | jq -c '
  ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
  (.continuation_path // null) as $flat |
  ($nested // $flat) as $resolved |
  if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
')
blocker_count=$(echo "$blockers" | jq 'length')
```

**Sub-state: continuation available** (`continuation` — the normalized object above — is non-null;
its `handoff_path` key is guaranteed non-null whenever `continuation` itself is non-null, by
construction of the `jq` resolution above):

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

```bash
# Defense-in-depth: status is typically already "implementing" here, so this is
# usually a no-op (update-task-status.sh preflight is idempotent).
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Resume implementation for task $task_number from continuation handoff" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", continuation_context: continuation, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` (`continuation_context` here is the **normalized** `continuation` object built above — `{ handoff_path, orchestrator_mode: true }` — never a raw read of the handoff's `continuation_context` or `continuation_path` field. This is the secondary-gap fix: it is what lets the successor implement dispatch actually consume a continuation the standard flat-form writer emitted. Do not "simplify" this back to a raw field read.) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

**Sub-state: blockers present** (blocker_count > 0):

Invoke blocker escalation (Stage 6). Increment cycle_count after escalation.

**Sub-state: no handoff, no blockers**:

A base-mode dispatch never writes `.orchestrator-handoff.json` (see docs/architecture/handoff-schema.md's
Handoff Writers table), so this is the normal shape a base-mode `[PARTIAL]` task takes, not a
dead end. Both engines route this sub-state to `implement` — see
`scripts/orchestrate-triage-classify.sh`'s header table. Probe the prior dispatch's outcome for
resume context before opening this cycle's dispatch window:

```bash
# Resume context for a base-mode partial: no handoff exists (base-mode dispatches never
# write one), so read the PRIOR dispatch's .return-meta.json instead. The staleness gate is
# intentionally disabled (window 0) — Stage 4 runs BEFORE this cycle's dispatch, so there is
# no current-cycle window yet, and the leftover prior-cycle state is exactly what we want
# regardless of age. This is deliberately NOT named dispatch_start_ts, which means "the
# current dispatch's window start" everywhere else in this file.
prior_meta_probe_window=0
resume_probe=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "$prior_meta_probe_window" || true)
```

`recovered=false` (exit 1) is the EXPECTED and non-fatal outcome here — the prior dispatch's own
status was `partial`/`in_progress` (that is why the task is in this state at all), and
`orchestrate-recover-outcome.sh` only reports `recovered=true` for `researched`/`planned`/
`implemented`. The probe supplies resume *context* (`.status`, `.artifact_path`,
`.phases_completed`, `.phases_total`), never a success claim, and it must NEVER gate the dispatch
— proceed to dispatch regardless of `recovered`.

```bash
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Resume implementation for task $task_number (no continuation handoff; resume context recovered from the prior dispatch's return metadata)" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq, resume_context: { status: (resume_probe.status), artifact_path: (resume_probe.artifact_path), phases_completed: (resume_probe.phases_completed), phases_total: (resume_probe.phases_total) } }` (same as the continuation branch's `context` object, minus `continuation_context`, plus `resume_context`) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

No missing-plan-file guard is added here (deliberate — see Non-Goals in this task's plan): a
`partial` task with no plan file dispatches implement and likely makes no progress, exactly as
the `mt` engine already does today; `MAX_CYCLES` bounds it.

#### State: `blocked`

Read blockers from state.json (not handoff — task was blocked outside orchestrator context):

```bash
blocker_desc=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"' \
  specs/state.json)
```

Invoke blocker escalation (Stage 6) with blocker_desc.

**Why this handler stays engine-unconditional (Decision 1, intentional divergence from `mt`)**:
this handler always escalates to a human, regardless of engine — a solo invocation has no sibling
task to make progress on, so escalation is the only meaningful action, whereas a batch invocation
(Stage MT-4) skips the blocked task so its siblings can proceed. This is the one row where the
two engines still diverge; it is documented, not an oversight (see
`scripts/orchestrate-triage-classify.sh`'s header table for the full discriminator).

#### State: `completed`

```
echo "[orchestrate] Task $task_number completed successfully."
# Clean up loop guard. This fires only at full-loop termination, never between cycles — so a
# per-cycle commit (e.g. CHECKPOINT 3) runs before this cleanup on every cycle but the last, and
# must exclude the guard itself rather than rely on this rm to keep it out of history. See
# context/standards/orchestrator-runtime-files.md.
rm -f "$loop_guard_file"
EXIT (success)
```

#### States: `abandoned`, `expanded`

```
echo "[orchestrate] Task $task_number is in terminal state [$current_status]. No action taken."
EXIT (no-op)
```

#### Unknown state

```
echo "[orchestrate] WARNING: Unrecognized state '$current_status' for task $task_number."
EXIT (partial)
```

---

### Stage 5: Handoff Reading (after each dispatch)

After every Agent tool invocation, read the orchestrator handoff to learn the outcome.
Never read the full research report, plan, or implementation summary — only the handoff.

```bash
# Reset the per-cycle exemption flag before any branch can set it.
infra_exempt_cycle=false

# ── System-defect observation log ─────────────────────────────────────────────
# One append idiom, reused at every detection site in this stage, matching this file's own
# loop-guard mutation idiom (`jq ... "$loop_guard_file" > "${loop_guard_file}.tmp" && mv ...`).
# The full contract — entry shape, unconditional-append rule, notice format, MUST-NOTs — is
# defined ONCE in Stage MT-1's `detected_defects` declaration and is not restated here.
#
# The helper emits the `[system-defect:auto]` notice itself, so no site can append without
# announcing. The append is UNCONDITIONAL: never gated on the recorder's exit code, nor on a
# `SUPPRESSED:recursion_guard`/`SUPPRESSED:duplicate` value on its stdout. `record_result`
# records that outcome for the operator; it never decides whether the entry exists.
#
# `.detected_defects += [...]` is safe against a guard file written before the field existed:
# jq's `null + [x]` is `[x]`, so the log self-heals rather than erroring.
append_detected_defect() {  # class, attributed_path, site, detail, record_result
  jq --argjson entry "$(jq -c -n \
        --argjson task "$task_number" --arg class "$1" --arg path "$2" \
        --arg site "$3" --argjson cycle "${cycle_count:-0}" --arg detail "$4" \
        --arg rr "${5:-}" \
        '{task:$task, defect_class:$class, attributed_source_path:$path,
          detecting_site:$site, cycle:$cycle, detail:$detail,
          record_result: (if $rr == "" then null else $rr end)}')" \
      '.detected_defects += [$entry]' \
      "$loop_guard_file" > "${loop_guard_file}.tmp" \
    && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=$1 attributed_path=$2 detecting_site=$3" >&2
}

# ── Staleness gate ────────────────────────────────────────────────────────────
# A handoff sitting at the correct path does NOT prove this dispatch wrote it. If the current
# dispatch wrote nothing (or wrote somewhere else), the PREVIOUS cycle's file is still there,
# and reading it reports the previous cycle's status and phases_completed as if they were this
# one's — a silent wrong answer, worse than a detected absence. mtime alone is structurally
# insufficient against a still-live predecessor — see
# context/patterns/dispatch-report-not-termination.md — which is why the dispatch_seq gate
# below exists as a second, content-based check.
#
# Reuse the dispatch window already captured for infra-failure discrimination: dispatch_start_ts
# is set via `date -u +%s` immediately before every Agent tool call above. This is the same
# stat/compare technique the missing-handoff branch below already applies to .return-meta.json,
# pointed at a second file. No new timestamp mechanism.
#
# Fail-closed: an unset dispatch_start_ts yields 9999999999, so a dispatch site that forgot to
# set its window marks the handoff stale rather than trusting it — matching the missing-handoff
# branch's defaults-to-charging posture below.
handoff_stale=false
if [ -f "$handoff_file" ]; then
  stale_window_start="${dispatch_start_ts:-9999999999}"
  handoff_mtime=$(stat -c %Y "$handoff_file" 2>/dev/null || stat -f %m "$handoff_file" 2>/dev/null || echo 0)
  if [ "$handoff_mtime" -lt "$stale_window_start" ]; then
    handoff_stale=true
    echo "[orchestrate] ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($stale_window_start)." >&2
    echo "[orchestrate] This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
    # Deliverable 2(b): record this Class (a) "loud but unactioned" detection. No
    # dispatched-agent-name variable is unambiguously in scope at this shared, stage-agnostic
    # block, so attribution names this detecting site's own SKILL.md.
    # Recorder stdout is captured (only the `>/dev/null` half of the old `>/dev/null 2>&1` is
    # dropped; stderr stays discarded and the non-fatal `|| echo` tail is intact) so its
    # dedup/suppression outcome can be carried into the ledger entry below as `record_result`.
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "skill-orchestrate/SKILL.md:stage-5-stale-handoff" \
      --task "$task_number" --session "$session_id" \
      --message "handoff mtime $handoff_mtime predates this dispatch window ($stale_window_start)" \
      --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    append_detected_defect "HANDOFF_STALE_OR_ABSENT" \
      "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      "skill-orchestrate/SKILL.md:stage-5-stale-handoff" \
      "handoff mtime $handoff_mtime predates this dispatch window ($stale_window_start)" \
      "$record_result"
  fi
fi

# --- dispatch-seq-gate:begin ---
# ── dispatch_seq identity gate (Defect A) ──────────────────────────────────────
# The mtime check above is RETAINED as a second line of defense against the git-restoration
# hazard, but it is structurally insufficient against a still-live predecessor: a woken
# predecessor's late write always carries a NEWER mtime than this dispatch's own window, so it
# passes the mtime check looking exactly like an on-time report. See
# context/patterns/dispatch-report-not-termination.md for why mtime alone cannot discriminate
# the two. dispatch_seq is the actual discriminator: an orchestrator-minted value only this
# dispatch knows (minted via mint_dispatch_seq() in Stage 2, immediately before the Agent call),
# echoed back unchanged by a legitimate writer.
if [ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]; then
  handoff_dispatch_seq=$(jq -r '.dispatch_seq // empty' "$handoff_file" 2>/dev/null)
  if [ -z "$handoff_dispatch_seq" ]; then
    echo "[orchestrate] WARN: handoff has no dispatch_seq field — writer predates or omits the dispatch_seq contract; degrading to mtime-only discrimination (see context/patterns/dispatch-report-not-termination.md)." >&2
  elif [ "$handoff_dispatch_seq" != "${dispatch_seq:-}" ]; then
    handoff_stale=true
    echo "[orchestrate] ERROR: DISPATCH_SEQ MISMATCH — handoff carries dispatch_seq=$handoff_dispatch_seq, this cycle minted dispatch_seq=${dispatch_seq:-<unset>}. This handoff was NOT written by the current dispatch (a still-live predecessor's late write, or a stale copy) — treating as missing." >&2
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "skill-orchestrate/SKILL.md:stage-5-dispatch-seq-mismatch" \
      --task "$task_number" --session "$session_id" \
      --message "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${dispatch_seq:-<unset>}" \
      --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    append_detected_defect "HANDOFF_STALE_OR_ABSENT" \
      "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      "skill-orchestrate/SKILL.md:stage-5-dispatch-seq-mismatch" \
      "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${dispatch_seq:-<unset>}" \
      "$record_result"
  else
    echo "[orchestrate] dispatch_seq match ($handoff_dispatch_seq) — handoff confirmed as this dispatch's own report." >&2
  fi
fi
# --- dispatch-seq-gate:end ---

# ── Stray-handoff sweep ───────────────────────────────────────────────────────
# Mechanism-agnostic backstop. The validate-handoff-location.sh PostToolUse hook catches
# Write/Edit-tool misplacements, but it is structurally unable to see a Bash-redirect write
# (e.g. a shell function writing via `jq -n ... > "$handoff_path"`; a Bash tool_input carries
# unexpanded command text, so the resolved destination is never visible to a hook).
# This sweep catches a misplaced handoff no matter how it was written.
#
# Deliberately bounded to two exact paths — the repo root and specs/ — not a recursive find.
# Those are the two places an unanchored write actually lands.
sweep_root="${SKILL_REPO_ROOT:-$(pwd)}"
for stray in "${sweep_root}/.orchestrator-handoff.json" "${sweep_root}/specs/.orchestrator-handoff.json"; do
  if [ -e "$stray" ]; then
    echo "[orchestrate] ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
    echo "[orchestrate] The correct destination is $handoff_file." >&2
    # Deliverable 2(b): record this Class (a) "loud but unactioned" detection, BEFORE the mv
    # below so the record is written even if the move fails. HANDOFF_MISLOCATED is an existing
    # Signal A instance (no vocabulary extension needed). The stray path is carried in
    # --extra-detail-json for forensics.
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_MISLOCATED \
      --detecting-site "skill-orchestrate/SKILL.md:stage-5-stray-handoff" \
      --task "$task_number" --session "$session_id" \
      --message "stray handoff found at $stray, outside its task directory" \
      --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      --extra-detail-json "$(jq -c -n --arg stray "$stray" '{stray_path: $stray}')" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    # Append BEFORE the mv below, for the same reason the recorder call above sits there: the
    # observation must survive a failed move.
    append_detected_defect "HANDOFF_MISLOCATED" \
      "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
      "skill-orchestrate/SKILL.md:stage-5-stray-handoff" \
      "stray handoff found at $stray, outside its task directory" \
      "$record_result"
    # Move aside rather than delete: preserves the evidence while ensuring no later
    # cwd-relative read can pick it up.
    mv "$stray" "${TASK_DIR}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
      && echo "[orchestrate] Stray moved into ${TASK_DIR}/ for inspection." >&2 \
      || echo "[orchestrate] WARNING: could not move stray aside; remove it manually before the next cycle." >&2
  fi
done

have_outcome=false

if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  # ── Outcome recovery: .return-meta.json fallback (see "MUST NOT (Context Flatness
  # Constraint) — Recovery exception (return-meta fallback)") ─────────────────────
  # Base-mode research, plan, and implement dispatches never write a handoff — by contractual
  # design for research (Stage 3.6 "Scoping Decision"), and simply never implemented for
  # base-mode plan/implement (see docs/architecture/handoff-schema.md's Handoff Writers table).
  # A missing handoff from one of those writers is the EXPECTED outcome, not a defect. Before
  # assuming a defect, consult the one shared recovery script every call site (this stage, hard
  # mode's mirrored Stage 5, and multi-task Stage MT-4 step 1) uses, so the rule cannot drift
  # into three separately-maintained copies.
  recover_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
  recover_exit=$?
  if [ "$recover_exit" -eq 0 ]; then
    recovered=$(echo "$recover_json" | jq -r '.recovered // false' 2>/dev/null) || recovered=false
  else
    recovered=false
  fi

  if [ "$recovered" = "true" ]; then
    dispatch_status=$(echo "$recover_json" | jq -r '.status')
    phases_completed=$(echo "$recover_json" | jq -r '.phases_completed // 0')
    phases_total=$(echo "$recover_json" | jq -r '.phases_total // 0')
    plan_markers_verified="absent"
    handoff_artifact_path=$(echo "$recover_json" | jq -r '.artifact_path // ""')
    handoff_artifact_type=$(echo "$recover_json" | jq -r '.artifact_type // ""')
    handoff_artifact_summary=$(echo "$recover_json" | jq -r '.artifact_summary // ""')
    echo "[orchestrate] RECOVERY: no handoff written for this dispatch — expected outcome for this phase's writer (base-mode research/plan/implement never write one). .return-meta.json (fresh, within this dispatch window) reports status=$dispatch_status; recovering the dispatch outcome from it." >&2
    have_outcome=true
    # Deliberate: charge exactly one work cycle, identical to the handoff-present success path
    # below — real work happened and produced a status transition, so infra_exempt_cycle stays
    # false (its reset default at the top of this stage). This is NOT the infra-exempt case,
    # which exists because no work happened at all; exempting a recovered success would also
    # remove the only bound on a loop that keeps recovering.

    # ── Evidence corroboration (widened detection trigger) ───────────────────────
    # PRECONDITION: reachable ONLY here, on the recovered=true path, when the recovery script's
    # general empty-value detection signal (see orchestrate-recover-outcome.sh's header) fired
    # PHASES_ZERO_ON_SUCCESS. This is the ONE scenario the phase-marker grep further below
    # structurally cannot see, because that grep requires recovered=false — a claimed-complete
    # implementation with a corroborated 0/0 phase count (Defect 1's own scenario) always
    # produces recovered=true and never reaches that branch. This trigger precondition is
    # UNCHANGED by the migration below — only the IMPLEMENTATION moved into the shared
    # skill_corroborate_phase_counts (scripts/skill-base.sh), the single anchor all three engines
    # now call for this logic, mirroring scripts/lib/phase-heading-patterns.sh's own role as the
    # single grammar anchor.
    #
    # Message-consolidation note (deliberate, recorded in the same style the multi-task
    # `blocked`-row divergence in the grouping table below is recorded): the shared function's
    # banner and log lines are scenario-agnostic — task number, plan path, completed/total
    # counts, the `[UNVERIFIED PHASES CORROBORATED]` token itself, and the "Corroborated by an
    # independent source" tail are all preserved verbatim — but it no longer restates "recovery
    # reported status=... with phases 0/0 (evidence_reason=PHASES_ZERO_ON_SUCCESS)" inline; that
    # framing is specific to this call site and is already established by the "RECOVERY:" log
    # line immediately above in the same cycle's output, so no diagnostic information is
    # actually lost, only the restatement.
    #
    # skill_corroborate_phase_counts is defined in scripts/skill-base.sh; source it defensively
    # here (idempotent) since this Stage 5 code fence has no earlier explicit source line of its
    # own to depend on.
    #
    # A sibling ARTIFACTS_SHAPE_MISMATCH arm follows immediately after the PHASES_ZERO_ON_SUCCESS
    # arm below (same if/elif ladder, same recovered=true precondition, same $evidence_suspect/
    # $evidence_reason variables) — it gives the discrimination pipeline's ARTIFACTS_SHAPE_MISMATCH
    # signal (see context/patterns/system-defect-discrimination.md) a consumer via a non-fatal
    # system-defect-record.sh call. It does not call skill_corroborate_phase_counts and does not
    # touch phases_completed/phases_total/plan_markers_verified — those remain exclusively the
    # PHASES_ZERO_ON_SUCCESS arm's concern.
    source .claude/scripts/skill-base.sh
    evidence_suspect=$(echo "$recover_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || evidence_suspect=false
    evidence_reason=$(echo "$recover_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || evidence_reason="NONE"
    if [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "PHASES_ZERO_ON_SUCCESS" ] && [ "$dispatch_status" = "implemented" ]; then
      corroboration_plan_path="${plan_path:-}"
      if [ -z "$corroboration_plan_path" ]; then
        corroboration_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
      fi
      # Empty handoff-path argument (4th arg omitted): there is no handoff to validate on the
      # recovery path — the whole reason this branch exists is that no handoff was written this
      # dispatch — so the log-only validate-handoff.sh diagnostic inside the shared function
      # must never fire here.
      cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "[orchestrate]")
      IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
      phases_completed="${cpc_a#phases_completed=}"
      phases_total="${cpc_b#phases_total=}"
      plan_markers_verified="${cpc_c#plan_markers_verified=}"
    elif [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      # Deliverable 2(a): give ARTIFACTS_SHAPE_MISMATCH a consumer. orchestrate-recover-outcome.sh
      # already computes this signal (a non-empty artifacts array yielding no resolvable path is
      # proof of a shape mismatch, e.g. a bare-string array, not proof of "no artifacts") — this
      # arm only reads it; the computation itself is untouched. No dispatched-agent-name variable
      # is in scope at this shared, stage-agnostic postflight block (Stage 5 runs identically
      # after research, plan, and implement dispatches), so attribution names this detecting
      # site's own SKILL.md per Signal B's "or, for orchestrator-internal sites, from the
      # detecting site itself" allowance.
      echo "[orchestrate] EVIDENCE: recovered .return-meta.json reports status=$dispatch_status with a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — this is proof of a shape mismatch (e.g. a bare-string artifacts array), not proof of \"no artifacts\"." >&2
      record_result=$(bash .claude/scripts/system-defect-record.sh \
        --defect-class ARTIFACTS_SHAPE_MISMATCH \
        --detecting-site "skill-orchestrate/SKILL.md:stage-5-recovered" \
        --task "$task_number" --session "$session_id" \
        --message "recovered return-meta carried a non-empty artifacts array yielding no path" \
        --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      append_detected_defect "ARTIFACTS_SHAPE_MISMATCH" \
        "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        "skill-orchestrate/SKILL.md:stage-5-recovered" \
        "recovered return-meta carried a non-empty artifacts array yielding no path" \
        "$record_result"
    fi
  else
    if [ "$handoff_stale" = "true" ]; then
      echo "[orchestrate] ERROR: Skill did not write a handoff for THIS dispatch (a stale one from an earlier cycle is present)."
    else
      echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
    fi
    echo "This may mean orchestrator_mode was not propagated correctly, or the handoff was written outside the task directory."
    recovered_reported_status=$(echo "${recover_json:-{}}" | jq -r '.status // "unknown"' 2>/dev/null) || recovered_reported_status="unknown"
    if [ "$recovered_reported_status" != "unknown" ]; then
      echo "[orchestrate] .return-meta.json reports status=$recovered_reported_status (not recovered as a successful outcome)." >&2
    fi

    # Infra-failure discrimination — see context/patterns/infra-failure-discrimination.md.
    # TWO corroborating signals are required to exempt this cycle from the work-cycle budget:
    #   (a) dispatch_was_transport_error — narrated judgment about the Agent tool call itself,
    #       set at the dispatch site in Stage 4;
    #   (b) meta_touched — mechanical check of whether the subagent's own Stage 0
    #       early-metadata write landed inside this dispatch window.
    # Either signal alone DEFAULTS TO CHARGING a genuine cycle. The defaults below are chosen
    # so a dispatch site that forgot to set its variables also falls back to charging.
    # Do not weaken the AND below into an OR or a fallthrough.
    meta_file="${TASK_DIR}/.return-meta.json"
    window_start="${dispatch_start_ts:-9999999999}"
    meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
    if [ "$meta_mtime" -ge "$window_start" ]; then
      meta_touched=true
    else
      meta_touched=false
    fi

    if [ "${dispatch_was_transport_error:-false}" = "true" ] && [ "$meta_touched" = "false" ]; then
      # Corroborated infra failure: the Agent tool call failed at the transport/API layer AND
      # the subagent left no footprint at all. Charge infra_failures, never cycle_count.
      infra_failures=$((infra_failures + 1))
      jq --argjson infra "$infra_failures" \
         --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.infra_failures = $infra | .last_updated = $updated' \
        "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      echo "[orchestrate] INFRA FAILURE $infra_failures/$MAX_INFRA_FAILURES — Agent tool transport/API failure with no subagent footprint. Not charged against MAX_CYCLES." >&2
      infra_exempt_cycle=true
    else
      echo "[orchestrate] Missing handoff charged as a genuine work cycle (transport_error=${dispatch_was_transport_error:-false}, meta_touched=$meta_touched)." >&2
    fi

    # ── Phase-marker recovery grep (sanctioned narrow exception) ─────────────────
    # PRECONDITION: reachable ONLY inside this missing/stale-handoff, non-recovered branch.
    # Never runs on the normal path where a fresh handoff was read, and never runs when
    # return-meta recovery already succeeded above — the context-flatness invariant is
    # untouched in both those cases. See "MUST NOT (Context Flatness Constraint) — Recovery
    # exception (phase-marker grep)" for the contract.
    # TOKEN BOUND: two `grep -c` calls returning one integer each — ≤10 tokens per recovery
    # event, no matched line content.
    # These counts are DIAGNOSTIC ONLY: with no usable handoff there is no dispatch_status to
    # trust, so they never drive a status transition. They exist to give the operator and the
    # next cycle visibility into real phase progress that a missing handoff structurally cannot
    # report.
    recovery_plan_path="${plan_path:-}"
    if [ -z "$recovery_plan_path" ]; then
      # $plan_path is set by the planned/implementing dispatch handler; a missing handoff after a
      # research or plan dispatch leaves it unset. Re-derive with the same idiom that handler uses.
      recovery_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    if [ -n "$recovery_plan_path" ] && [ -f "$recovery_plan_path" ]; then
      # Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than
      # re-derived inline. `x=$(grep -c ...) || x=0` — grep exits 1 on zero matches. Never
      # `$(grep -c ... || echo 0)`, which emits two lines in that case.
      . .claude/scripts/lib/phase-heading-patterns.sh
      recovered_total=$(grep -cE "$PHASE_HEADING_ERE" "$recovery_plan_path" 2>/dev/null) || recovered_total=0
      recovered_completed=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$recovery_plan_path" 2>/dev/null) || recovered_completed=0
      if has_nonconforming_phase_headings "$recovery_plan_path"; then
        warn_nonconforming "$recovery_plan_path" "orchestrate-recovery" || true
        echo "[orchestrate] RECOVERY: non-conforming phase heading(s) in ${recovery_plan_path} — recovered phase count is unreliable (treated as unknown, not refused)." >&2
      fi
      echo "[orchestrate] RECOVERY: handoff unusable — plan headings show ${recovered_completed}/${recovered_total} phases closed (COMPLETED or COMPLETED WITH EXCLUSIONS) in ${recovery_plan_path}." >&2

      # Stagnation signal: an identical recovered_completed across consecutive recovery events
      # means dispatches are burning cycles without advancing the plan. Logged, never enforced —
      # MAX_CYCLES remains the only bound on this branch.
      prev_recovered=$(jq -r '.last_recovered_phases_completed // -1' "$loop_guard_file" 2>/dev/null) || prev_recovered=-1
      if [ "$prev_recovered" = "$recovered_completed" ]; then
        echo "[orchestrate] RECOVERY: no phase progress since the previous recovery event (still ${recovered_completed}/${recovered_total}). Dispatches are not advancing the plan." >&2
      fi
      jq --argjson rc "$recovered_completed" --argjson rt "$recovered_total" \
         --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.last_recovered_phases_completed = $rc
         | .last_recovered_phases_total = $rt
         | .last_updated = $updated' \
        "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
    elif [ -d "${TASK_DIR}/plans" ]; then
      echo "[orchestrate] RECOVERY: no plan file available — phase progress cannot be recovered this cycle." >&2
    else
      # Softened: no plans/ directory is the normal case after a research-phase dispatch, not a
      # surprise. Keep the louder message above for the case a plans/ directory exists but yields
      # no readable plan.
      echo "[orchestrate] RECOVERY: no plans/ directory yet (normal after a research-phase dispatch) — phase progress recovery does not apply this cycle." >&2
    fi
  fi
else
  handoff=$(cat "$handoff_file")
  # `// ""` (not bare `.status`) so a handoff with a missing `status` field yields an empty
  # string rather than the literal string "null" — both route to Tier C below.
  dispatch_status=$(echo "$handoff" | jq -r '.status // ""')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  blockers=$(echo "$handoff" | jq -c '.blockers // []')
  # Dual-form resolution + normalization (same rule as the Stage 4 `partial` handler above and
  # scripts/orchestrate-triage-classify.sh's continuation_ok predicate): accept either the nested
  # continuation_context.handoff_path or the flat top-level continuation_path, normalized to
  # { handoff_path, orchestrator_mode: true } or null.
  continuation=$(echo "$handoff" | jq -c '
    ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
    (.continuation_path // null) as $flat |
    ($nested // $flat) as $resolved |
    if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
  ')
  next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')
  echo "[orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"

  # --- marker-handoff-crosscheck:begin ---
  # Defect 6, base-engine equivalent of the hard engine's heading-scan cross-check. Base mode has
  # no discrete per-phase next_phase selection to gate (it always re-dispatches the whole plan),
  # so this cross-check is diagnostic-and-downgrading rather than dispatch-refusing: it compares
  # the plan's own [COMPLETED]/[COMPLETED WITH EXCLUSIONS] marker count against this handoff's
  # phases_completed and, on a mismatch where the plan claims MORE than the handoff confirms,
  # downgrades the specific disputed phase heading to [PARTIAL] -- the same action the hard
  # engine's cross-check takes, and the same manual downgrade the operator performed in the
  # observed incident. See context/contracts/wrap-up.md's "Ordering: Handoff Write Precedes
  # Marker Promotion" for why this state is reachable at all.
  crosscheck_plan_path="${plan_path:-}"
  if [ -z "$crosscheck_plan_path" ]; then
    crosscheck_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
  fi
  if [ -n "$crosscheck_plan_path" ] && [ -f "$crosscheck_plan_path" ]; then
    . .claude/scripts/lib/phase-heading-patterns.sh
    if has_nonconforming_phase_headings "$crosscheck_plan_path"; then
      warn_nonconforming "$crosscheck_plan_path" "orchestrate-marker-handoff-crosscheck" || true
    else
      marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$crosscheck_plan_path" 2>/dev/null) || marker_completed_count=0
      if [ "$marker_completed_count" != "$phases_completed" ]; then
        echo "[orchestrate] MARKER/HANDOFF MISMATCH — plan file shows ${marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but this handoff's own phases_completed=${phases_completed}." >&2
        if [ "$marker_completed_count" -gt "$phases_completed" ]; then
          disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$crosscheck_plan_path" | sed -n "$((phases_completed + 1))p")
          if [ -n "$disputed_line" ]; then
            disputed_linenum="${disputed_line%%:*}"
            disputed_text="${disputed_line#*:}"
            echo "[orchestrate] Downgrading disputed phase heading to [PARTIAL]: ${disputed_text}" >&2
            sed -i -E "${disputed_linenum}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "$crosscheck_plan_path"
          fi
        fi
      fi
    fi
  fi
  # --- marker-handoff-crosscheck:end ---

  # ── Evidence corroboration (handoff-present branch) ──────────────────────────
  # PRECONDITION: reachable ONLY here — a handoff IS present and fresh (this is the `else` of
  # the missing/stale-handoff branch above), dispatch_status is "implemented", AND phases_total
  # is exactly 0 (accounting absent or malformed). This is the THIRD reachable branch of the
  # phase-marker-grep exception — see "MUST NOT (Context Flatness Constraint) — Recovery
  # exception (phase-marker grep)" below for the full three-branch enumeration.
  #
  # D3 (deliberate divergence): the trigger is `phases_total -eq 0` ALONE, not the recovered
  # path's `PHASES_ZERO_ON_SUCCESS` (both-counts-zero) signature above — matching
  # skill_gate_completion_claim's own Case 3 precondition exactly, so trigger and gate cannot
  # drift apart. See skill_corroborate_phase_counts's header comment in scripts/skill-base.sh
  # for the full rationale.
  # D4 (structural, not a promise): Case 1 of skill_gate_completion_claim (phase accounting
  # present and incomplete -> always refuse) is UNREACHABLE from this trigger by construction,
  # since phases_total is already 0 here and Case 1 requires phases_total > 0 — a corroborated
  # correction never overrides a refusal, it only supplies independent evidence (the plan file's
  # own headings, never the handoff's own values) where the handoff supplied none.
  #
  # skill_corroborate_phase_counts is defined in scripts/skill-base.sh; source it defensively
  # here (idempotent — redefines the same functions, no side effects beyond recomputing
  # SKILL_REPO_ROOT) since this Stage 5 code fence has no earlier explicit source line of its
  # own to depend on.
  source .claude/scripts/skill-base.sh
  if [ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]; then
    corroboration_plan_path="${plan_path:-}"
    if [ -z "$corroboration_plan_path" ]; then
      corroboration_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "[orchestrate]" "$handoff_file")
    IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
    phases_completed="${cpc_a#phases_completed=}"
    phases_total="${cpc_b#phases_total=}"
    plan_markers_verified="${cpc_c#plan_markers_verified=}"
  fi

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork)
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    # Use awk for floating-point comparison (bash only does integer math)
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
      invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
    fi
  fi

  # Artifact linking fields, populated here from the handoff — the shared tail below (reached
  # via have_outcome) consumes them identically whether they came from here or from recovery.
  handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
  handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
  handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
  have_outcome=true
fi

# ── Shared postflight tail ────────────────────────────────────────────────────
# Reached from EITHER the handoff-present branch above OR a successful return-meta recovery —
# never duplicated between them. A duplicated `case "$dispatch_status"` is exactly the drift
# this fallback mechanism exists to prevent (see Phase 2 of the plan that introduced it).
if [ "$have_outcome" = "true" ]; then
  # Postflight status update: trigger state.json + TODO.md Task Order regeneration
  #
  # dispatch_status accept-list: the normative enumeration of these six values is
  # context/formats/return-metadata-file.md's status vocabulary, which declares itself normative
  # for .orchestrator-handoff.json's `status` field too (not just .return-meta.json) — keep this
  # list and that table in sync rather than letting them drift independently. That table has a
  # SEVENTH row, `in_progress`, deliberately NOT accepted here: it is early-metadata-only (Stage 0
  # of a writer's own execution) and never a legal terminal dispatch outcome, so a handoff
  # carrying it means the writer never finished — correctly routed to the off-schema arm below,
  # not treated as an unexplained gap in this six-value list.
  offschema_dispatch_status=false
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      # Completion-claim verification gate: a dispatch reporting "implemented" must not flip the
      # whole task to `completed` without corroborating evidence. The three-case fail-closed
      # logic lives in ONE place — skill_gate_completion_claim in skill-base.sh — so base mode,
      # hard mode, and multi-task mode cannot drift apart again. See that function's header for
      # the full case table (phase accounting present-and-complete always allows,
      # present-and-incomplete always refuses, absent falls back to plan_markers_verified — both
      # the recovered path above AND the handoff-present branch's own read set
      # plan_markers_verified="absent" by default, so an absent phase count on either an
      # "implemented" claim recovered from .return-meta.json or one read directly from a fresh
      # handoff is conservatively refused here, not allowed, UNLESS one of the two
      # evidence-corroboration call sites above already flipped it to "true" via
      # skill_corroborate_phase_counts — the recovered-path corroboration block, or the
      # handoff-present branch's own "Evidence corroboration (handoff-present branch)" block —
      # from an independent, corroborating plan-heading read).
      if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
           "$plan_markers_verified" "[orchestrate]"; then
        # `warn`, deliberately NOT `refuse`: the script-side backstop reads the plan file's own
        # phase headings — structurally different evidence — so it is a valuable SECOND OPINION
        # here, not a veto over a decision this state machine made deliberately and loggedly.
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"

        # Populate completion_summary/roadmap_items. The handoff schema has no such field (H9
        # wrap-up writes only status/summary/blockers/artifacts/phase counts — see
        # docs/architecture/handoff-schema.md), so a handoff-present dispatch never populates
        # these here for free; `.return-meta.json`'s `completion_data` is the only source. Reuse
        # this cycle's own `$recover_json` when the recovery branch above already ran (guarded on
        # non-empty, never on control-flow position — see that branch's own comment), otherwise
        # issue one additional read through the same shared script so there is still only ONE
        # reader of `.return-meta.json` in the codebase.
        if [ -n "${recover_json:-}" ]; then
          completion_json="$recover_json"
        else
          completion_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
        fi
        # NOTE: default via `[ -z ] && completion_json='{}'`, never `"${completion_json:-{}}"` —
        # bash parameter-expansion default-word matching stops at the FIRST unescaped `}`, so that
        # inline idiom silently appends a stray trailing `}` to any non-empty value, corrupting the
        # JSON and forcing every jq call below to fail closed to "" via `2>/dev/null`.
        [ -z "${completion_json:-}" ] && completion_json='{}'
        completion_summary=$(echo "$completion_json" | jq -r '.completion_summary // ""' 2>/dev/null) || completion_summary=""
        roadmap_items=$(echo "$completion_json" | jq -c '.roadmap_items // []' 2>/dev/null) || roadmap_items="[]"
        skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$TASK_TYPE"
        if [ -z "$completion_summary" ]; then
          completion_reason=$(echo "$completion_json" | jq -r '.reason // "unknown"' 2>/dev/null) || completion_reason="unknown"
          echo "[orchestrate] WARNING: task completed with empty completion_summary (reason=${completion_reason})" >&2
        fi
      else
        # `skill_gate_completion_claim`'s Case 3/3 (phases_total == 0 AND plan_markers_verified
        # != "true") already called system-defect-record.sh internally. Re-derive that case here
        # from variables this caller already holds, so the observation reaches this run's ledger
        # without reading or editing scripts/skill-base.sh. Case 1 (phases_total > 0, incomplete)
        # is an ordinary refuse and is NOT a defect — it must not append.
        #
        # `record_result` is empty here: the recorder was invoked inside the gate function, not
        # by this caller, so its stdout is not observable from this scope.
        #
        # This branch ONLY observes. It performs no skill_postflight_update and no state
        # transition — the no-transition semantics documented immediately below are unchanged.
        if [ "${phases_total:-0}" -eq 0 ] && [ "${plan_markers_verified:-}" != "true" ]; then
          append_detected_defect "META_MISSING_AFTER_NARRATION" \
            "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
            "scripts/skill-base.sh:skill_gate_completion_claim" \
            "completion claimed with phases_total=0 and unverified plan markers" ""
        fi
      fi
      # On refuse: no status transition. State stays `implementing`, the gate already logged which
      # case fired, `cycle_count` still increments at the end of this stage, and Stage 4
      # re-dispatches implement next cycle against the same plan. MAX_CYCLES bounds this, so a
      # misreporting agent exits `partial` rather than looping forever.
      ;;
    partial|failed|blocked)
      # Tier B — in-enum exception outcome, explicitly recognized (never the silent catch-all).
      # Deliberately NO skill_postflight_update call: skill_postflight_update in
      # scripts/skill-base.sh has its own internal `case "$status" in researched|planned|
      # implemented) ... *) ... skip` accept-list, so a call from here would no-op one layer
      # deeper regardless. That is a known, currently-NON-FUNCTIONAL gap (see this task's plan's
      # "What remains NON-FUNCTIONAL" table and the named follow-up to admit partial/blocked into
      # that accept-list) — not something this branch can silently paper over.
      echo "[orchestrate] Dispatch status '$dispatch_status' — recognized exception outcome. No state.json transition is performed here; the task remains at its current in-flight status. This cycle's loop counter still advances." >&2
      ;;
    *)
      # Tier C — off-schema. dispatch_status is neither a success value nor a recognized
      # exception value: it may be empty (missing `status` field), the literal `in_progress`
      # (early-metadata-only, never a legal terminal value — see the accept-list comment above),
      # or any other unrecognized string. A silent no-op here is exactly the defect this
      # three-tier structure exists to close — a dispatch that in fact succeeded could be
      # stranded and indistinguishable from one that produced nothing.
      offschema_dispatch_status=true
      # Phase identification ONLY — artifacts[0].type (report|plan|summary) reliably names WHICH
      # phase wrote the artifact but is NEVER a success-vs-partial signal: the schema's own
      # examples pair `summary` with both `implemented` and `partial` outcomes. This inference
      # must never be used to synthesize a success verdict for a missing/invalid dispatch_status.
      case "$handoff_artifact_type" in
        report)  inferred_phase="research" ;;
        plan)    inferred_phase="plan" ;;
        summary) inferred_phase="implement" ;;
        *)       inferred_phase="unknown" ;;
      esac
      offschema_display="${dispatch_status:-<empty>}"
      echo "[OFF-SCHEMA DISPATCH STATUS - '${offschema_display}' is not in the handoff status vocabulary (researched|planned|implemented|partial|failed|blocked); the dispatch may have SUCCEEDED but its outcome cannot be trusted or applied]" >&2
      echo "[orchestrate] ERROR: handoff $handoff_file carries an off-schema dispatch_status. Inferred phase (from artifacts[0].type, naming only — not a success signal): $inferred_phase. Remedy: inspect the handoff and the dispatch's own .return-meta.json by hand, then re-run /orchestrate $task_number." >&2
      # Deliverable 2(b): record this Class (a) "loud but unactioned" detection. No
      # dispatched-agent-name variable is unambiguously in scope at this shared, stage-agnostic
      # Tier C arm, so attribution names this detecting site's own SKILL.md per Signal B's
      # "detecting site itself" allowance.
      record_result=$(bash .claude/scripts/system-defect-record.sh \
        --defect-class OFF_SCHEMA_STATUS \
        --detecting-site "skill-orchestrate/SKILL.md:stage-5-tier-c" \
        --task "$task_number" --session "$session_id" \
        --message "handoff dispatch_status '${offschema_display}' is off-schema" \
        --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      append_detected_defect "OFF_SCHEMA_STATUS" \
        "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        "skill-orchestrate/SKILL.md:stage-5-tier-c" \
        "handoff dispatch_status '${offschema_display}' is off-schema" \
        "$record_result"
      ;;
  esac

  # Artifact linking: extract artifact path/type (from the handoff or recovered return-meta) and
  # link in TODO.md + state.json.
  if [ -n "$handoff_artifact_path" ] && [ "$handoff_artifact_path" != "null" ]; then
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
    skill_link_artifacts "$task_number" "$handoff_artifact_path" "$handoff_artifact_type" \
      "$handoff_artifact_summary" "$field_name" "$next_field"
  fi

  # Off-schema halt — consumed HERE, after artifact linking above has already run, not as an
  # inline exit inside the case statement. This preserves the dispatch's evidence (the artifact,
  # if any, is still linked into TODO.md/state.json) rather than discarding it. Mirrors Stage 4's
  # "Unknown state" handler precedent.
  if [ "${offschema_dispatch_status:-false}" = "true" ]; then
    echo "[orchestrate] Halting: task $task_number left at its current status. Any artifact produced by this dispatch was still linked above, preserving the evidence." >&2
    EXIT (partial)
  fi
fi

# Increment cycle_count — skipped ONLY for a corroborated infra failure, which is separately
# bounded by MAX_INFRA_FAILURES (Stage 7). Every iteration charges exactly one of the two
# counters; both are capped, so worst-case iterations per invocation are
# MAX_CYCLES + MAX_INFRA_FAILURES.
if [ "$infra_exempt_cycle" = "true" ]; then
  echo "[orchestrate] Cycle not charged (infra failure). cycle_count remains $cycle_count/$MAX_CYCLES." >&2
else
  cycle_count=$((cycle_count + 1))
fi
```

---

### Stage 5a: Drift Inspection

Called from Stage 5 when phase completion is below DRIFT_COMPLETION_THRESHOLD and dispatch_status is "partial".
Capped at MAX_DRIFT_INSPECTIONS=1 per /orchestrate invocation.

1. If `drift_inspection_count >= MAX_DRIFT_INSPECTIONS`: log warning and return (skip inspection).

2. Increment `drift_inspection_count`. Log: "[orchestrate] Drift inspection attempt N/MAX".

3. Invoke the Agent tool (fork — to inspect the plan file):

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Read the plan file at '$plan_path'. Count: (1) total checklist items matching '- [ ]' or '- [x]', (2) completed items matching '- [x]', (3) deviation annotations matching '*(deviation:'. Calculate drift_pct as: deviation_count / max(total_items, 1). Write compact JSON to '${TASK_DIR}/.drift-inspection.json' with fields: drift_pct (float), deviation_count (int), total_items (int), completed_items (int), summary (string, one sentence). Return a brief summary of findings." |
| `context` | `{ task_number, session_id, plan_path, orchestrator_mode: false }` |

4. After Agent tool returns: read `${TASK_DIR}/.drift-inspection.json`.
   - If file exists: extract `drift_pct` and `drift_summary`.
   - If file missing: log warning, set `drift_pct=0`, `drift_summary="Inspection output missing"`.

5. If `drift_pct > DRIFT_REVISION_THRESHOLD`: trigger plan revision:

   Invoke the Agent tool (reviser):

   | Field | Value |
   |-------|-------|
   | `subagent_type` | `"reviser-agent"` |
   | `prompt` | "Revise the implementation plan for task $task_number to address plan drift (drift_pct=$drift_pct). Summary: $drift_summary" |
   | `context` | `{ task_number, session_id, plan_path, revision_reason: "drift", drift_pct, orchestrator_mode: false }` |

   After Agent tool returns: read handoff to confirm revision.

6. If `drift_pct <= DRIFT_REVISION_THRESHOLD`: log "Drift check passed. Continuing."

---

### Stage 6: Blocker Escalation (5-Step Sequence)

Called when: `partial` state with non-empty blockers, or `blocked` state.
Capped at MAX_BLOCKER_ESCALATIONS=2 per /orchestrate invocation.

**If `blocker_escalation_count >= MAX_BLOCKER_ESCALATIONS`**: log error and return. Manual intervention required. Suggest: (1) `/research $task_number`, (2) `/revise $task_number`, (3) `/implement $task_number`.

Increment `blocker_escalation_count`. Log escalation attempt and blocker description.

**Step 1: DETECT** — blocker_desc is passed in by caller (from handoff or state.json).

**Step 2: RESEARCH FORK** — Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Research this specific blocker for task $task_number: $blocker_desc. Find the root cause and a concrete solution path." |
| `context` | `{ task_number, session_id, blocker: blocker_desc, orchestrator_mode: false }` |

After Agent tool returns: read the fork's own returned text for research findings.

**Step 3: READ FINDINGS** — The fork above is dispatched with `orchestrator_mode: false`, and by
the decided one-channel-per-mode contract (see `docs/architecture/handoff-schema.md`'s "Handoff
Writers" section) a dispatch with `orchestrator_mode: false` writes NO `.orchestrator-handoff.json`
at all — only the hard-mode implementation agent ever writes that file. The fork's returned text
IS the real findings channel here, not `$handoff_file`. The read below is defensive only (in case
a stale handoff from an unrelated prior hard-mode dispatch happens to sit at that path) and is
expected to fall through to the empty defaults on the common path:
```bash
findings_summary=$(jq -r '.summary // "No findings"' "$handoff_file" 2>/dev/null || echo "No findings")
findings_artifact=$(jq -r '.artifacts[0].path // ""' "$handoff_file" 2>/dev/null || echo "")
```

**Step 4: REVISE PLAN** — Read latest plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"reviser-agent"` |
| `prompt` | "Revise the implementation plan for task $task_number to address this blocker: $blocker_desc. Research findings: $findings_summary" |
| `context` | `{ task_number, session_id, research_findings: findings_summary, plan_path, orchestrator_mode: false }` |

After Agent tool returns: read handoff to confirm revision.

**Step 5: RE-DISPATCH IMPLEMENT** — Read revised plan path, then invoke the Agent tool:

```bash
# Dispatch window for infra-failure discrimination and the Stage 5 staleness/dispatch_seq gate
# — see context/patterns/infra-failure-discrimination.md. This dispatch writes
# .orchestrator-handoff.json (orchestrator_mode: true) and therefore needs its own dispatch
# window and dispatch_seq minted here, the same as every other handoff-writing dispatch site.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the revised plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path, roadmap_path: "specs/ROADMAP.md", task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

After Agent tool returns: read handoff.

---

### Stage 7: Loop Guard Update (end of each cycle)

After each cycle (whether dispatch succeeded or failed):

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
   --argjson infra "${infra_failures:-0}" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .infra_failures = $infra' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

If MAX_INFRA_FAILURES reached (infra_failures >= MAX_INFRA_FAILURES):

```
echo "[orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number — repeated Agent tool transport/API failures with no subagent execution."
echo "This is a connectivity problem, not a work-budget problem: cycle_count is still $cycle_count/$MAX_CYCLES."
echo "Run /orchestrate $task_number again once connectivity is confirmed."
EXIT (partial)
```

This is the explicit bound on the exemption path. Because an infra-exempt cycle does not
increment `cycle_count`, the `while` condition alone would not advance; this check — which runs
at the end of every cycle — is what terminates the run. Worst-case iterations per invocation
are therefore `MAX_CYCLES + MAX_INFRA_FAILURES` = 8. Do NOT also increment `cycle_count` here:
the cap's purpose is to stay outside the work-cycle budget.

If MAX_CYCLES reached (cycle_count >= MAX_CYCLES). Note: with the Stage 2
budget-continuation-override in place, this branch is now normally unreachable in practice for an
already-exhausted guard — Stage 2 either exits early (flag absent) or resets cycle_count to 0
(flag present) before the main loop ever opens. It remains correct as a defense-in-depth backstop
for the rare case where MAX_CYCLES is reached DURING this same invocation's own loop:

```
echo "[orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
echo "Current state: $current_status. Run /orchestrate $task_number --continue-budget to authorize a fresh budget and continue."
EXIT (partial)
```

---

### Stage 8: Postflight

On clean exit (task completed or terminal state):

**Both files removed here — `.orchestrator-loop-guard` and `.drift-inspection.json` — are
ephemeral and gitignored, and this is their only cleanup site.** Cleanup fires only at full-loop
termination, never per-cycle, so any commit taken mid-loop (e.g. CHECKPOINT 3, which runs every
cycle) must independently exclude both rather than rely on this `rm` alone. See
`context/standards/orchestrator-runtime-files.md`.

```bash
# Read the run's system-defect observation log BEFORE cleanup below removes the loop guard —
# ordering is load-bearing here (the metadata merge further down consumes this value).
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
# Remove loop guard on success
rm -f "$loop_guard_file"
# Clean up drift inspection artifact if present
rm -f "${TASK_DIR}/.drift-inspection.json"
echo "[orchestrate] Task $task_number: orchestration complete."
echo "Final status: $current_status | Cycles used: $cycle_count/$MAX_CYCLES"
```

On partial exit (MAX_CYCLES, in-flight warning, escalation cap):

```bash
# Preserve loop guard for next /orchestrate invocation
echo "[orchestrate] Task $task_number: orchestration paused."
echo "Status: $current_status | Cycles: $cycle_count/$MAX_CYCLES | Run /orchestrate $task_number --continue-budget to continue once the budget is exhausted, or /orchestrate $task_number for an ordinary cross-turn resume."
```

**Explicitly UNCHANGED by Defect B's budget-continuation override**: this cleanup site still only
fires on full-loop termination (the "On clean exit" block above), never on a partial exit --
including the Stage 2 exhaustion branch's flag-absent `exit 1`, which leaves the exhausted guard
fully in place. This is correct, not an oversight: the guard's entire job is to persist across
exactly this gap so an operator's subsequent `--continue-budget` invocation has something to read
`cycle_count` from. All four sites that touch this guard's lifecycle -- Stage 2's exhaustion
branch, this Stage 7 terminal condition, and this Stage 8 cleanup -- now visibly agree.

Write metadata file. `status` here is the `.return-meta.json` skill-status vocabulary defined
normatively in `context/formats/return-metadata-file.md` — it is NOT the state.json task-status
vocabulary (`current_status` above, where `"completed"` is correct); do not "correct" this value
back to `"completed"`.

On clean exit:

```bash
mkdir -p "${TASK_DIR}/summaries"
# Merge onto the existing file rather than overwrite wholesale: an earlier writer (the
# implementation agent) already populated modified_files/completion_data/etc. on this same
# path, and a later writer MUST NOT clobber fields it does not own.
meta_file="${TASK_DIR}/.return-meta.json"
existing_meta=$(cat "$meta_file" 2>/dev/null || echo '{}')
tmp_meta=$(mktemp)
echo "$existing_meta" | jq \
  --arg status "implemented" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  --argjson detected_defects "$detected_defects" \
  '. * {
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state,
      "detected_defects": $detected_defects
    }
  }' > "$tmp_meta" && mv "$tmp_meta" "$meta_file"
```

On partial exit:

```bash
mkdir -p "${TASK_DIR}/summaries"
# Merge onto the existing file rather than overwrite wholesale: an earlier writer (the
# implementation agent) already populated modified_files/completion_data/etc. on this same
# path, and a later writer MUST NOT clobber fields it does not own.
meta_file="${TASK_DIR}/.return-meta.json"
existing_meta=$(cat "$meta_file" 2>/dev/null || echo '{}')
# The loop guard is PRESERVED on partial exit, so ordering is not load-bearing here — but the
# two blocks are kept structurally identical to the clean-exit variant on purpose.
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
tmp_meta=$(mktemp)
echo "$existing_meta" | jq \
  --arg status "partial" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  --argjson detected_defects "$detected_defects" \
  '. * {
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state,
      "detected_defects": $detected_defects
    }
  }' > "$tmp_meta" && mv "$tmp_meta" "$meta_file"
```

---

## Multi-Task Mode

Entered when `multi_task_mode=true` in the delegation context (detected in Stage 0).
All single-task stages (1-8) are skipped. The skill receives a pre-computed wave schedule
from `orchestrate.md` and manages all tasks in a single orchestrator instance.

### Stage MT-1: Parse Multi-Task Context

Read from delegation context:
- `task_numbers` — array of task numbers to manage
- `dependency_graph` — map of task_number -> [predecessor_task_numbers]
- `waves` — pre-computed topological wave schedule
- `session_id`, `lit_flag`, `allow_self_modifying` (default: "false") — consumer-side opt-in
  bypass of the self-modification admission gate; never passed to `orchestrate-batch-admit.sh`
  itself (see Stage MT-3 step 4.5's `self_modifying` branch below)

**Upstream review cross-reference**: raw dependency review already happened upstream, at
`commands/orchestrate.md` Step 1.5 (Pre-Dispatch Review), before `dependency_graph` above was
even built — Step 1.5 runs `scripts/orchestrate-predispatch-review.sh` against the FULL raw
`dependencies[]` on every candidate, warning loudly on every out-of-batch or nonexistent edge
Step 2/3 is about to narrow away. The `dependency_graph` this stage receives has therefore
already been reviewed within that review stage's own stated limits: it is advisory-loud, never
blocking, and it does not itself exclude an out-of-batch predecessor from this stage's
eligibility check below (Stage MT-3 step 3) — see
`context/patterns/batch-orchestration-guardrails.md`'s Non-Negotiable 3 and Open Design Fork for
the current status of that residual gap. No code change was needed here: this stage receives an
already-built `dependency_graph` from the command's Step 2/3 output rather than rebuilding any
part of it itself.

Compute: `task_count = length(task_numbers)`, `MAX_CYCLES_MT = min(task_count * 5, 25)`,
`MAX_INFRA_FAILURES = 3` (flat **per task**, not scaled by `task_count` — matching single-task
mode; see `context/patterns/infra-failure-discrimination.md`).

Initialize `mt_state_file = "specs/.orchestrator-multi-state-${session_id}.json"` with fields: `session_id`,
`task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, `failed_tasks: []`,
`completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`,
`implement_agents: {}`, `infra_failures: {}` (map task_num -> count, default 0),
`dispatch_start_ts: {}` (map task_num -> unix seconds, written at dispatch time),
`dispatch_seq_counter: 0` (batch-scoped monotonic counter, Defect A — never repeats a value
across the whole batch, mirroring the single-task engine's loop-guard `dispatch_seq_counter`),
`dispatch_seq: {}` (map task_num -> the `dispatch_seq` minted for that task's most recent
dispatch, written at dispatch time alongside `dispatch_start_ts[$t]`), and
`deferred_self_modifying: []` — an APPEND-ONLY OBSERVATION LOG (persists across every cycle of
this same `mt_state_file`, never reset mid-invocation) of task numbers the self-modification gate
has deferred AT LEAST ONCE this invocation. As of the narrowed same-cycle scope, this is NO LONGER
an eligibility-exclusion set — a task appearing in this log is not thereby excluded from a later
cycle's `eligible_tasks`. The convergence mechanism is now the SAME one `file_scope_collision`
already uses: the defer is re-evaluated fresh every cycle from `${#eligible_tasks[@]}` and the
candidate's own `file_scope`, and it clears on its own once the co-dispatched sibling that caused
it leaves `eligible_tasks` (enters `researching`/`planning`, terminates, or fails) — no persistent
exclusion is needed for that to happen, and the loop's existing per-cycle re-evaluation already
guarantees it. See Stage MT-3 step 3 (no longer an exclusion), step 4.5 (append-only population),
and the new consecutive-no-dispatch guard below for the bounded case where the natural clearing
condition does not hold, and Stage MT-5 (postflight reporting) for where this log is read.

**In-flight session registry** (adjacent to, not part of, `mt_state_file`): register the batch
under the bare `session_id` this stage received, with the full `task_numbers` set as the CSV.
Best-effort and non-blocking — a registration failure must never affect any admission, dispatch,
or eligibility decision:

```bash
bash .claude/scripts/task-lock.sh session-register "$session_id" "/orchestrate (multi-task)" "$(IFS=,; echo "${task_numbers[*]}")" 2>/dev/null || true
```

Single-task `/orchestrate` needs no separate registry wiring: its CHECKPOINT 1/2 already routes
through `command-gate-in.sh`/`command-gate-out.sh`, which register/release the session registry
entry for every single-task dispatch (see that pair's own wiring). This registration is
multi-task-only, mirroring why `mt_state_file` itself is initialized only in this MT branch.

`deferred_deploy_checkpoint`'s semantics are UNCHANGED by this narrowing and remain a genuine,
permanent-for-the-invocation eligibility exclusion — the two fields are not conflated by this
change; see the field definition immediately below.

Alongside it, two more INVOCATION-SCOPED fields with the same never-reset-mid-invocation
semantics, backing the inter-cycle redeploy checkpoint (Stage MT-3 step 7 below; full contract in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection):

- `deferred_deploy_checkpoint: []` — task numbers excluded for the remainder of the invocation
  because a checkpoint gate (`deploy-headless.sh` or `verify-deploy.sh`) failed. A DISTINCT set
  from `deferred_self_modifying`: the two causes have different operator remedies, so they are
  never merged.
- `deployed_critical_paths: []` — critical paths already redeployed this invocation; the
  idempotence guard's backing store, so the checkpoint does not re-fire on the same path every
  cycle.
- `consecutive_no_dispatch_cycles: 0` — integer counter backing Stage MT-3 step 4.5's convergence
  guard: increments on any cycle where `eligible_tasks` was non-empty but the self-modification
  gate deferred every member of it (empty actual dispatch batch); resets to 0 on any cycle where
  at least one task dispatches. Bounds the narrow non-convergence mode a removed permanent
  exclusion set no longer prevents by construction.
- `verify_deploy_baseline_notices: []` — an APPEND-ONLY OBSERVATION LOG of every checkpoint firing
  that proceeded past a pre-existing `verify-deploy.sh` failure (the third operator-visible state;
  see the **Failure contract** branch (c) in `context/patterns/batch-orchestration-guardrails.md`'s
  `### The Inter-Cycle Redeploy Checkpoint` subsection), entries of the form
  `{"cycle": <int>, "gate": "verify-deploy.sh", "pre_findings": <int>, "post_findings": <int>, "new_findings": 0, "post_exit": <int>}`.
  It carries the same MUST NOT as `defer_ledger` immediately below: never read by any eligibility
  check, all-terminal check, circuit breaker, convergence guard, or admission branch. It is
  written for reporting only, read at Stage MT-5 and by `commands/orchestrate.md` Step 5. It is
  NOT a defer/exclusion set — the third state excludes nothing — and is never merged into
  `defer_ledger`, whose own contract scopes it to defer/exclusion events.

Two more fields, backing the **forward-progress invariant** (full contract in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
subsection):

- `defer_ledger: []` — an APPEND-ONLY OBSERVATION LOG of every per-cycle defer/exclusion event,
  entries of the form
  `{"task": <int>, "defer_reason": <string>, "collision_scope": <string|null>, "cycle": <int>, "detail": <string>}`.
  **MUST NOT**: the ledger is never read by any eligibility check, all-terminal check, circuit
  breaker, convergence guard, or admission branch. It is written for reporting and read only at
  Stage MT-5 and by `commands/orchestrate.md` Step 5. It is not a fifth admission gate and must
  never become one. `defer_ledger` is ADDITIVE to `deferred_self_modifying` and
  `deferred_deploy_checkpoint`, not a replacement: a self-modifying defer appends to BOTH the
  existing observation log and the ledger, and the two existing fields keep their current
  semantics, consumers, and Stage MT-5 role byte-for-byte.
- `detected_defects: []` — an APPEND-ONLY OBSERVATION LOG of every system-defect detection that
  fired during this run. This declaration is the SINGLE canonical definition of the field's
  contract; `skill-orchestrate-hard/SKILL.md` points back here rather than restating it, so the
  two engines cannot drift.

  **Entry shape**:
  `{"task": <int>, "defect_class": <string>, "attributed_source_path": <string>, "detecting_site": <string>, "cycle": <int>, "detail": <string>, "record_result": <string|null>}`.
  Unlike `defer_ledger`'s MT-only `task`, `task` here is ALWAYS populated: a task number
  (`$task_number` in single-task stages, `$task_num` in MT stages) is in scope at every detection
  site in both engines.

  **Unconditional-append rule**: the append fires whenever the caller's own detection fires, and
  is NEVER gated on `system-defect-record.sh`'s exit code, nor on a `SUPPRESSED:recursion_guard`
  or `SUPPRESSED:duplicate` value on its stdout. `record_result` records that outcome for the
  operator; it never decides whether the entry exists. Rationale: the recorder's dedup key is
  cross-run, while this log answers "what fired during THIS run" — a detection suppressed as a
  cross-run duplicate still fired here and must still be surfaced. This mirrors `defer_ledger`'s
  existing unconditional-append discipline.

  **Notice format** (modelled on the literature `AUTONOMOUS_GLOBAL` directive's `[lit:auto]`
  notice): immediately after each append, at every site, emit
  `[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=<CLASS> attributed_path=<PATH> detecting_site=<SITE>`
  (`[hard-orchestrate]` prefix in the hard-mode file; MT sites additionally name the task). Its
  purpose is the same "never a silent no-op" principle that directive states: a detection that
  only lands in a file the operator never opens is indistinguishable from no detection at all.

  **Absolute constraint**: no site in this mechanism may call `AskUserQuestion`. When
  `orchestrator_mode` is true there is no human to prompt, so accumulate-then-render is the
  deterministic default — exactly as `AUTONOMOUS_GLOBAL` prescribes for the same situation. This
  mechanism surfaces detections; it creates no task and adds no interactive step.

  **MUST NOT**: the log is never read by any eligibility check, all-terminal check, circuit
  breaker, convergence guard, or admission branch. It is written for reporting and read only at
  Stage MT-5 and by `commands/orchestrate.md`. It is not an admission gate and must never become
  one. It is likewise never consulted by `exit_status` branch selection: a batch that succeeded
  and also observed a defect is still a successful batch.

  **ADDITIVE, never merged**: `detected_defects` is ADDITIVE to `defer_ledger` and is never
  merged into it — `defer_ledger`'s `defer_reason` vocabulary is load-bearing for admission
  reporting, and a system-defect detection excludes nothing and has no `defer_reason`. It is
  likewise never merged into `verify_deploy_baseline_notices`, which is a different observation
  log for a different concern (pre-existing deploy-verify failures). Three separate logs, three
  separate operator remedies.
- `forward_progress_violated: false` — initialized false, computed and written once at Stage MT-5
  from `dispatch_start_ts`. Never read by any loop condition.

**Hard-mode finding, recorded, not acted on**: `skills/skill-orchestrate-hard/SKILL.md` has no
MT-stage implementation of its own — its Stage 0 states explicitly that when `multi_task_mode` is
true it "use[s] base multi-task stages", i.e. these SAME Stage MT-1 through MT-5 stages in
`skill-orchestrate/SKILL.md`. Multi-task `/orchestrate --hard` therefore already writes
`mt_state_file.dispatch_start_ts`, `defer_ledger`, and `forward_progress_violated` via this same
file with no separate hard-mode edit needed. The `dispatch_start_ts` occurrences that DO appear as
hard-mode-local shell variables elsewhere in `skill-orchestrate-hard/SKILL.md` belong to its
single-task (non-MT) infra-failure-discrimination logic — a same-named but unrelated local
variable, not the `mt_state_file` field. `commands/orchestrate.md` Step 5's three-branch
resolution still degrades explicitly (an explicit "not evaluable" notice, never a silent skip) for
any future MT path variant that might lack the field, but no such variant exists today.

### Stage MT-2: Build Per-Task Routing Table

For each task in `task_numbers`, read `state.json` to get `task_type`, `project_name`. Compute `task_dir = "specs/${padded}_${project_name}"`. Resolve `research_agent` and `implement_agent` using the same routing table as Stage 1b:

| task_type | research_agent | implement_agent |
|-----------|----------------|-----------------|
| `lean4` / `lean` | `lean-research-agent` | `lean-implementation-agent` |
| `neovim` | `neovim-research-agent` | `neovim-implementation-agent` |
| `nix` | `nix-research-agent` | `nix-implementation-agent` |
| *(default)* | `general-research-agent` | `general-implementation-agent` |

Check `.claude/extensions/${task_type}/manifest.json` for override routing. Populate all per-task maps into `mt_state_file`.

**Entry reconcile (once per task, never per-cycle)**: within this same per-task iteration — not
inside Stage MT-3's cycling loop — run `reconcile-task-status.sh` once for each task. This rides
the iteration Stage MT-2 already performs to build the routing table, satisfying the once-per-task
requirement on a path that has no single per-task entry point of its own. Live, bracketed the same
way as the single-task entry reconcile above (a live no-op prints nothing):

```bash
for task_number in "${task_numbers[@]}"; do
  # ... existing routing-table resolution for this task_number (task_type, project_name,
  # task_dir, research_agent, implement_agent) ...
  recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
  if [ -n "$recon_out" ]; then
    echo "$recon_out"
  else
    echo "[orchestrate] Entry reconcile: no stranded status found for task $task_number"
  fi
done
```

### Stage MT-3: Lifecycle-Cycling Loop

Initialize `cycle_count = 0`. Loop while `cycle_count < MAX_CYCLES_MT`:

1. **Status refresh**: For each task in `task_numbers`, read current status from `state.json` and update `mt_state_file.current_statuses`. Alongside this refresh, heartbeat the batch's in-flight
   session registry entry (keyed on the bare `session_id` Stage MT-1 registered) — a new USE of
   this existing per-cycle checkpoint, not an invented one; Stage MT-4's per-task lock
   acquire/release brackets a single dispatch and has no equivalent per-cycle lock heartbeat to
   sit beside, so this loop-top status refresh is the correct per-cycle site for the batch-level
   heartbeat instead. Best-effort and non-blocking:
   ```bash
   bash .claude/scripts/task-lock.sh session-heartbeat "$session_id" 2>/dev/null || true
   ```

2. **All-terminal check**: If every task is in `{completed, abandoned, expanded}`, in
   `failed_tasks`, OR in `deferred_deploy_checkpoint` — break loop (exit success or partial). A
   task in `deferred_deploy_checkpoint` is deliberately, permanently excluded for the remainder of
   the invocation, so this check treats it the same as a terminal/failed task for the purpose of
   deciding whether the loop has anything left to do — see Stage MT-3 step 7's population of
   `deferred_deploy_checkpoint` below. `deferred_self_modifying` is DELIBERATELY ABSENT from this
   check as of the narrowed same-cycle scope: a task recorded there still has real work pending
   (it is only deferred for cycles where it is actually co-dispatched with a colliding sibling),
   so it must not be treated as "nothing left to do" merely because the observation log carries
   its number.

3. **Build eligible_tasks**: For each task, include it if ALL of the following are true:
   - Status is NOT `{completed, abandoned, expanded}` and NOT in `failed_tasks`
   - Task number is NOT in `deferred_deploy_checkpoint` (populated by Stage MT-3 step 7 below;
     this remains a genuine, invocation-scoped eligibility EXCLUSION — unlike
     `deferred_self_modifying`, which as of the narrowing is no longer an exclusion here at all
     — and is what makes the redeploy-checkpoint deferral converge rather than re-qualifying the
     task next cycle)
   - Status is NOT `{researching, planning}` (in-flight from prior cycle)
   - All predecessors from `dependency_graph[task_num]` are in terminal state or `failed_tasks`
   
   If a predecessor is in `failed_tasks`: mark this task in `failed_tasks` with status `blocked` and skip it.
   If a predecessor is still in-progress: skip this task (wait for next cycle).

4. **No-eligible circuit breaker**: If `eligible_tasks` is empty AND at least one task remains
   that is NOT terminal, NOT in `failed_tasks`, and NOT in `deferred_deploy_checkpoint` — log
   warning with list of stuck tasks and break loop (exit partial). (If every remaining
   non-eligible task is accounted for by step 2's All-terminal check instead — i.e. every task is
   terminal, failed, or deferred-by-redeploy-checkpoint — step 2 has already broken the loop
   before this step runs, so this circuit breaker's "stuck tasks" framing is reserved for
   genuinely stuck tasks, never for a redeploy-checkpoint-deferred one.) As of the narrowed
   same-cycle scope, this PRE-admission check no longer reserves any special case for
   self-modifying candidates: they are ordinary members of `eligible_tasks` at this point (step 3
   above no longer excludes them), and are only removed from the dispatch batch by step 4.5's
   POST-admission filtering below — the scenario where step 4.5 empties an otherwise non-empty
   `eligible_tasks` is a distinct, later concern handled by the new convergence guard at the end
   of step 4.5, not by this circuit breaker.

4.5. **Runtime wave-split check (cross-batch defense-in-depth)**: this step IS Tier 1
   (auto-sequence) of the four-tier conflict-response ladder for `/orchestrate` — see
   `.claude/context/patterns/task-lock.md`'s "Four-Tier Conflict Response" section for the full
   ladder and how this multi-cycle re-sequencing compares to plain multi-task `/research`'s,
   `/plan`'s, and `/implement`'s bounded one-extra-pass equivalent. No behavioral change here; this
   is a cross-reference only. Before dispatching
   `eligible_tasks` on EVERY cycle — including a cycle where `eligible_tasks` contains only a
   single task, since a cross-batch collision exists at batch size 1 — call the admission
   script, passing `--invocation-count` set to THIS CYCLE'S actual co-dispatch count,
   `${#eligible_tasks[@]}`, and `--session-id "$session_id"` (D6, session-registry contention
   input) — the SAME bare `session_id` Stage MT-1 registered via `session-register` above, so
   this call's self-exclusion actually matches the batch's own registry entry rather than seeing
   it as foreign and deferring every candidate against itself:
   ```bash
   bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id "$session_id" "${eligible_tasks[@]}"
   ```
   This is the corrected contract (narrowed from an earlier version of this step that passed this
   invocation's full validated-candidate count): the self-modification defer trigger fires
   against candidates actually co-dispatched THIS wave/cycle, not against the invocation's full
   candidate set. Step 3's eligibility rule already guarantees a `dependencies[]`-edge-connected
   pair can never share an `eligible_tasks` batch — a successor is never eligible until its
   predecessor leaves the non-terminal set — so a whole-invocation count fired against pairs that
   could never actually co-occur; that was a pure false positive, not a safety margin. The
   remaining strictness is real, not vestigial: a self-modifying candidate genuinely sharing a
   cycle with an un-edge-connected sibling still defers, and that residual strictness is grounded
   in the standing verification-gap hazard (hazard 1 in
   `context/patterns/batch-orchestration-guardrails.md` — a fix to orchestrator machinery is
   verified only against a scratch deploy-tree copy, never the live system) — not in the two
   hazards this dependency chain already retired.
   This compares each eligible task's `file_scope` against every non-terminal task in a single
   `specs/state.json` read — the comparison set is every non-terminal task in state, not merely
   this invocation's own `task_numbers` set. This is still not a repo-wide filesystem scan: no
   globbing, no second read, just one read of
   `specs/state.json` per cycle. The predicate itself is the shared directory-prefix overlap
   algorithm in `.claude/context/patterns/file-footprint-overlap.md` (referenced by path — not
   restated here); the verdict schema is published in
   `.claude/docs/architecture/batch-admit-schema.md` (also referenced by path, never restated).

   `jq`-filter stdout for `.decision == "defer"`, then branch on `defer_reason` FIRST (schema v3
   — every defer verdict carries this REQUIRED discriminator; checking `collision_scope` without
   checking `defer_reason` first would misread a self-modifying defer as an ordinary in-batch
   collision, since both verdicts carry a `reason` string):

   - **`self_modifying`** (the candidate's own `file_scope` names an orchestrator-critical path):
     **consumer-side override check first** — if `allow_self_modifying == true` for this
     invocation, do NOT act on this defer verdict: dispatch the candidate this cycle anyway,
     exactly as if it had admitted. The verdict itself is unaffected by the flag — it is still
     emitted, still carries `self_modifying: true` and `defer_reason: "self_modifying"`, and
     `orchestrate-batch-admit.sh` is NEVER passed the flag; the bypass is entirely a decision made
     here, at the consumer, about whether to act on a verdict the script always computes
     honestly. Log a loud, distinct bypass notice whether or not the gate would otherwise have
     fired, so a transcript reader can always tell the override was active this invocation:
     ```
     [orchestrate] BYPASS: --allow-self-modifying is active. Task #{task_number} has file_scope
       naming orchestrator-critical path {critical_path} ({critical_label}); dispatching this
       cycle anyway per explicit human-intent override.
     ```
     Otherwise (no override): remove the candidate from this cycle's dispatch batch and append it
     to the `mt_state_file.deferred_self_modifying` OBSERVATION LOG (task numbers the gate has
     deferred at least once this invocation — see Stage MT-1's schema definition above; this log
     is no longer an eligibility-exclusion set, so recording an append here does NOT by itself
     keep the task out of a later cycle's `eligible_tasks` — see step 3's convergence rationale
     for what actually clears the defer). The task is never added to `failed_tasks` and never
     status-mutated. Log a **distinct** warning naming the matched critical path, label, and the
     co-dispatched sibling situation that caused the defer:
     ```
     [orchestrate] WARNING: Task #{task_number} has file_scope naming orchestrator-critical
       path {critical_path} ({critical_label}), co-dispatched this cycle alongside another
       eligible candidate. Deferring #{task_number} to a later cycle — it becomes eligible again
       once its co-dispatched sibling leaves eligible_tasks (dependencies[]-edge-connected
       candidates never share a cycle, so this never fires for an edge-connected pair). Pass
       --allow-self-modifying for deliberate human-intent bypass.
     ```
     Additionally (no-override path only — a bypassed defer dispatches and must NOT be ledgered as
     a defer), append to `mt_state_file.defer_ledger`:
     `{"task": task_number, "defer_reason": "self_modifying", "collision_scope": null, "cycle": cycle_count, "detail": "matched critical path {critical_path} ({critical_label})"}`.
   - **`file_scope_collision`** — retains the exact pre-existing `collision_scope` branching
     below, byte-for-byte. Both branches preserve the surrounding cycle semantics verbatim: a
     deferred task is removed from **this cycle's** dispatch batch, is never added to
     `failed_tasks`, and becomes eligible again on a later cycle (never added to
     `deferred_self_modifying` — that set is exclusively for the `self_modifying` branch above).
     - **`in_batch`** (the colliding task is itself in `eligible_tasks`): remove the deferred task
       from this cycle's dispatch batch and log the existing warning:
       ```
       [orchestrate] WARNING: Tasks #{X} and #{Y} have overlapping file_scope with no
         dependency_graph edge between them. Deferring #{Y} to a later cycle to avoid
         concurrent edits to the same files.
       ```
       Additionally, append to `mt_state_file.defer_ledger`:
       `{"task": Y, "defer_reason": "file_scope_collision", "collision_scope": "in_batch", "cycle": cycle_count, "detail": "colliding in-batch task #{X}"}`.
     - **`cross_batch`** (the colliding task is NOT part of `task_numbers` for this invocation):
       remove the candidate from this cycle's dispatch batch and log a **distinct** warning naming
       the out-of-batch task and its `colliding_task_status`:
       ```
       [orchestrate] WARNING: Task #{task_number} has overlapping file_scope with task
         #{colliding_task_number} (status: {colliding_task_status}), which is OUTSIDE this
         invocation's task_numbers. Excluding #{task_number} from this cycle — batch
         composition needs human review.
       ```
       Additionally, append to `mt_state_file.defer_ledger`:
       `{"task": task_number, "defer_reason": "file_scope_collision", "collision_scope": "cross_batch", "cycle": cycle_count, "detail": "colliding out-of-batch task #{colliding_task_number} (status: {colliding_task_status})"}`.
   - **`session_active`** (NEW in v4, reached only when the state.json collision scan above found
     no hit): a live registered session's own unioned `file_scope` overlaps the candidate's.
     Same "defer, not fail" cycle semantics as the two branches above — remove the candidate from
     this cycle's dispatch batch, never add it to `failed_tasks`, never add it to
     `deferred_self_modifying` (that set is exclusive to the `self_modifying` branch), eligible
     again on a later cycle once the contending session releases or goes stale. Log a distinct
     warning naming the contending session, the task it covers, and its liveness reason:
     ```
     [orchestrate] WARNING: Task #{task_number} has file_scope overlapping live registered
       session {session_id}'s (liveness: {session_liveness_reason}) covered task
       #{colliding_task_number} at {overlapping_path}. Deferring #{task_number} to a later
       cycle — it becomes eligible again once that session releases or its registry entry
       goes stale.
     ```
     Additionally, append to `mt_state_file.defer_ledger`:
     `{"task": task_number, "defer_reason": "session_active", "collision_scope": null, "cycle": cycle_count, "detail": "contending session {session_id} (liveness: {session_liveness_reason}) covers task #{colliding_task_number} at {overlapping_path}"}`.

   **Convergence guard (post-admission empty-dispatch-batch check)**: removing the permanent
   `deferred_self_modifying` exclusion set (this step now only appends to an observation log, per
   Stage MT-1's schema definition) opens a narrow non-convergence mode the old permanent exclusion
   incidentally prevented: `eligible_tasks` can be non-empty every cycle while every member of it
   is deferred by this step's `self_modifying` branch, so the actual dispatch batch is empty and
   nothing runs, cycle after cycle, until `MAX_CYCLES_MT`. The convergence ARGUMENT this guard
   backs up (not replaces): a same-cycle self-mod defer clears on its own once its co-dispatched
   sibling leaves `eligible_tasks` — entering `researching`/`planning`, terminating, or
   failing — which the existing per-cycle loop already guarantees for any ordinary case, because
   the sibling is itself being dispatched and processed each cycle. The guard exists only to BOUND
   the case where that natural clearing does not happen (e.g. two self-modifying candidates that
   keep mutually re-qualifying each other as the "colliding sibling" every cycle). Mechanism:
   maintain `mt_state_file.consecutive_no_dispatch_cycles` (integer, starts at 0). After this
   step's filtering, if the resulting dispatch batch is empty AND `eligible_tasks` (pre-filter) was
   non-empty, increment the counter; on ANY cycle where at least one task actually dispatches,
   reset it to 0. If the counter reaches a small bound (3), break the loop with `partial` status
   and a named diagnostic — e.g. "self-modification gate produced N consecutive cycles with zero
   dispatched tasks; likely a mutually-colliding self-modifying set; re-run affected tasks solo or
   pass --allow-self-modifying" — rather than silently spinning to `MAX_CYCLES_MT`.

   **Interaction with the task-lock acquire step (Stage MT-4)**: admission runs **before** lock
   acquisition and is a distinct gate — admission compares declared scopes of ALL non-terminal
   tasks in `specs/state.json`, while the lock compares only against currently-held locks.
   Neither replaces the other; both run.

   **Degradation path**: exit 2 from `orchestrate-batch-admit.sh` means state is unavailable
   (missing `jq` or an unreadable `specs/state.json`). In that case, log a loud warning and
   proceed without the check — orchestration cannot function at all under that condition
   regardless of this check, so proceeding is not a silent weakening of the gate.

   This mirrors the same check documented in `orchestrate.md` Step 3 for the pre-computed wave
   schedule — both now describe a script call, not an inline loop; here it applies per-cycle to
   `eligible_tasks` since Multi-Task Mode dispatches cycle-by-cycle rather than strictly
   wave-by-wave. If this proves too aggressive in practice, it can be relaxed to warn-only by
   editing this step (see Rollback/Contingency in
   `specs/787_file_footprint_aware_dependencies/plans/01_file-footprint-aware-dependencies.md`).

5. **Dispatch** (Stage MT-4) — see below.

6. **Increment cycle_count**, update `mt_state_file.cycle_count`. If `cycle_count >= MAX_CYCLES_MT`: log partial status and break.

7. **Inter-cycle redeploy checkpoint.** Full contract (trigger, `modified_files` rationale,
   rejected alternatives, failure contract, sequencing, idempotence guard, concurrency) is
   recorded once, authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s
   `### The Inter-Cycle Redeploy Checkpoint` subsection — referenced here, not restated.

   **Sequencing guarantee, stated up front**: every task dispatched this cycle already had its
   own scoped commit attempted at Stage MT-4 step 5.5, unconditionally, before this step runs.
   Committed-then-redeployed, in that order, is guaranteed by existing step ordering, not by new
   synchronization.

   - **Overlap computation**: expand `context/reference/orchestrator-critical-paths.json` using
     the same `scope_roots x critical_paths` jq expression `orchestrate-batch-admit.sh` already
     performs (reuse it; do not re-derive it here), and intersect against this cycle's
     `cycle_modified_files` (accumulated at Stage MT-4 step 5.5 below) using the directory-prefix
     overlap predicate in `context/patterns/file-footprint-overlap.md` (referenced by path, never
     restated).
   - **Idempotence guard**: subtract `mt_state_file.deployed_critical_paths` from the overlap set.
     If the remainder is empty, skip the checkpoint this cycle at zero further cost and continue
     to the next cycle. Without this guard, a task sitting in `implementing` across several cycles
     would re-report the same `modified_files` and re-fire the checkpoint every cycle. This
     idempotence mechanism is unaffected by the self-modification narrowing elsewhere in this
     document — `deployed_critical_paths` is its own accumulating set, distinct from both
     `deferred_self_modifying` and `deferred_deploy_checkpoint`.
   - **Fire**: if the remainder is non-empty, log a loud notice naming every matched critical path
     and its label. Immediately before running `deploy-headless.sh`, capture the pre-redeploy
     baseline:
     ```bash
     PRE_RAW=$(bash .claude/scripts/verify-deploy.sh --findings --quiet)
     PRE_EXIT=$?
     PRE_FINDINGS=$(printf '%s\n' "$PRE_RAW" | grep '^FINDING ' | sort -u)
     ```
     (capturing `verify-deploy.sh`'s own exit code requires it to be the LAST command in its
     command substitution — `$?` after a piped substitution like
     `x=$(cmd | grep ... | sort -u)` reports `sort -u`'s exit status, not `cmd`'s, since the
     pipeline runs inside the substitution's own subshell and does not update the parent shell's
     `PIPESTATUS`. The filtering is therefore a separate second step over the already-captured
     text.)
     Then run, in order, from the repo root:
     ```bash
     bash .claude/scripts/deploy-headless.sh
     ```
   - **`deploy-headless.sh` failure branch — stated BEFORE any baseline logic.** Non-zero exit
     (1 or 2) → defer unconditionally, exactly as today, with NO baseline consultation
     whatsoever — the pre-redeploy capture taken above is simply discarded, unread, in this
     branch. Log a loud warning naming
     the exit code, then add every task in `task_numbers` that is not terminal and not in
     `failed_tasks` to `mt_state_file.deferred_deploy_checkpoint`. As of the narrowing, membership
     in the `deferred_self_modifying` OBSERVATION LOG is no longer a reason to skip a task here —
     that log does not confer any exclusion of its own, so a task recorded in it that is otherwise
     eligible and non-terminal is exactly the kind of task this permanent exclusion is meant to
     catch. Never add to `failed_tasks`. Never status-mutate. Never abort the invocation. Include
     the operator remedy in the warning: fix the deploy failure, redeploy manually, then re-run
     `/orchestrate` on the remaining task numbers. Append to `mt_state_file.defer_ledger`:
     `{"task": task_number, "defer_reason": "deploy_checkpoint", "collision_scope": null, "cycle": cycle_count, "detail": "deploy-headless.sh exit {exit_code}"}`.
   - **On `deploy-headless.sh` success**, capture the post-redeploy baseline at the same call site
     the plain `verify-deploy.sh` call occupied before this baseline mechanism existed:
     ```bash
     POST_RAW=$(bash .claude/scripts/verify-deploy.sh --findings --quiet)
     POST_EXIT=$?
     POST_FINDINGS=$(printf '%s\n' "$POST_RAW" | grep '^FINDING ' | sort -u)
     ```
   - **Success path (`POST_EXIT == 0`)**: unchanged — record the matched paths into
     `mt_state_file.deployed_critical_paths`, log the deployed artifact count and a `verify-deploy`
     pass, and continue to the next cycle. `PRE_FINDINGS` is unused in this branch.
   - **`POST_EXIT` non-zero**: compute the set difference
     `NEW_FINDINGS=$(comm -13 <(printf '%s\n' "$PRE_FINDINGS") <(printf '%s\n' "$POST_FINDINGS"))`,
     then branch on whether it is empty:
     - **`NEW_FINDINGS` empty → the third state.** Every finding `verify-deploy.sh` reports
       post-redeploy already existed in the pre-redeploy baseline — a pre-existing failure, not one
       this redeploy introduced. Log the banner
       `[PRE-EXISTING VERIFY-DEPLOY FAILURE - N finding(s) predate this redeploy, 0 newly introduced; batch continuing]`
       and the machine marker
       `<!-- verify-deploy-baseline pre={pre_count} post={post_count} new=0 proceeded=true -->`
       (symmetric exit-2 case: if `POST_EXIT == 2`, the banner instead reads "could not run,
       before or after this redeploy — pre-existing condition"). Record the matched paths into
       `mt_state_file.deployed_critical_paths`, exactly as the success path does — the redeploy
       mechanically succeeded; only the standing lint state is unhealthy, and without this the
       idempotence guard would re-fire the checkpoint every cycle on the same paths purely because
       a pre-existing failure is still present. Do NOT add any task to
       `deferred_deploy_checkpoint`. Do NOT append to `defer_ledger` — its contract scopes it to
       defer/exclusion events, and the third state excludes nothing. Append one entry to
       `mt_state_file.verify_deploy_baseline_notices`:
       `{"cycle": cycle_count, "gate": "verify-deploy.sh", "pre_findings": pre_count, "post_findings": post_count, "new_findings": 0, "post_exit": POST_EXIT}`.
       Continue to the next cycle.
     - **`NEW_FINDINGS` non-empty → the existing failure path, unchanged in shape.** Log a loud
       warning naming the gate and its exit code, then add every task in `task_numbers` that is not
       terminal and not in `failed_tasks` to `mt_state_file.deferred_deploy_checkpoint`. Never add
       to `failed_tasks`. Never status-mutate. Never abort the invocation. Include the operator
       remedy in the warning: fix the deploy/verify failure, redeploy manually, then re-run
       `/orchestrate` on the remaining task numbers. Append to `mt_state_file.defer_ledger`, its
       `detail` field enriched to name the new findings — count first, then finding text as token
       budget allows:
       `{"task": task_number, "defer_reason": "deploy_checkpoint", "collision_scope": null, "cycle": cycle_count, "detail": "verify-deploy.sh exit {POST_EXIT} ({n} new finding(s) vs. pre-redeploy baseline: {finding}; {finding})"}`.
   - Already-dispatched-and-committed tasks from prior cycles are unaffected by any path — their
     commits landed at step 5.5 before this step ran.

### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight

> **BATCHING RULE**: ALL Agent tool calls for the current cycle's dispatch batch MUST be issued in a SINGLE orchestrator message with multiple tool-use content blocks. Do NOT issue calls across multiple messages — Claude Code processes all calls in a single message concurrently; multiple messages force sequential execution.

> **COMPLETION SEQUENCING**: After ALL Agent tool calls complete (Claude Code returns control after all calls in the single message finish), read handoffs for every dispatched task. Do NOT read handoffs interleaved with dispatches. Per-task postflight (below) now includes a scoped git commit (step 5.5); these commits serialize naturally in program order because postflight is a sequential loop within this same orchestrator turn, so the `specs/.commit-lock/` mutex is needed only against a concurrently-running separate dispatch, never against this loop's own iterations.

**System-defect observation log (MT append idiom)** — the multi-task counterpart of single-task
Stage 5's `append_detected_defect` helper, targeting `$mt_state_file` instead of the loop guard
(an MT run has no loop guard) and scoped to each task's own `$task_num` /
`${session_id}_${task_num}`. It matches the same `jq ... > "${mt_state_file}.tmp" && mv ...`
idiom the existing `defer_ledger` appends in Stages MT-3/MT-4 use, so the two read as the same
kind of write. The full contract — entry shape, unconditional-append rule, notice format,
MUST-NOTs — is defined ONCE in Stage MT-1's `detected_defects` declaration and is not restated
here.

**These MT sites serve `/orchestrate --hard` batches too.** Exactly as Stage MT-1 already records
for `defer_ledger`, `skill-orchestrate-hard/SKILL.md` has no MT-stage implementation of its own
and delegates to these same stages, so the wiring below needs no hard-file mirror. The absence of
a hard-mode MT counterpart is intentional; do not "fix" it.

```bash
append_detected_defect_mt() {  # task_num, class, attributed_path, site, detail, record_result
  jq --argjson entry "$(jq -c -n \
        --argjson task "$1" --arg class "$2" --arg path "$3" \
        --arg site "$4" --argjson cycle "${cycle_count:-0}" --arg detail "$5" \
        --arg rr "${6:-}" \
        '{task:$task, defect_class:$class, attributed_source_path:$path,
          detecting_site:$site, cycle:$cycle, detail:$detail,
          record_result: (if $rr == "" then null else $rr end)}')" \
      '.detected_defects += [$entry]' \
      "$mt_state_file" > "${mt_state_file}.tmp" \
    && mv "${mt_state_file}.tmp" "$mt_state_file"
  echo "[orchestrate] Task #${1}: [system-defect:auto] queued for postflight summary — defect_class=$2 attributed_path=$3 detecting_site=$4" >&2
}
```

**Classifier call** — before grouping, call the shared handoff-triage classifier so this stage's
routing reads the SAME rule the read-only dry-run report reads, rather than a second,
independently-maintained copy of it:

```bash
bash .claude/scripts/orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"
```

`jq`-filter the emitted NDJSON by `.group` into this stage's dispatch buckets: `.group ==
"research"` -> `research_tasks`, `.group == "plan"` -> `plan_tasks`, `.group == "implement"` ->
`implement_tasks`, `.group == "needs_human"` -> `failed_tasks` (mark blocked), and `.group ==
"skip"` or `.group == "terminal"` -> skip (no dispatch). This single call supplies the
pre-dispatch `blockers`/`continuation_context` read for `partial` tasks that the table below
previously only asserted without a spelled-out mechanism — its precedence is **continuation >
blockers > neither** (a task with a valid continuation always dispatches to implement even if
stale blockers are also present; only absence of continuation falls through to the blockers
check).

**Degradation path**: exit 2 from `orchestrate-triage-classify.sh` means state is unavailable
(missing `jq`, or an unreadable `specs/state.json`). In that case, log a loud warning and fall
back to the Phase grouping table below, applied inline per task, rather than silently skipping
dispatch for the whole cycle — orchestration must still make forward progress when the classifier
itself cannot run.

**Phase grouping** (documentation of the rule the classifier script transcribes, retained here as
a byte-identical reference table — `scripts/orchestrate-triage-classify.sh` is the executable
source of truth, and THREE artifacts — this table, the classifier script's own header verdict
table, and single-task Stage 4's `partial` sub-state prose above — MUST be changed together,
never independently, and must always agree) — classify each eligible task by its current status:

| Task status | Group | Agent |
|-------------|-------|-------|
| `not_started` | research_tasks | `research_agents[task_num]` |
| `researched` | plan_tasks | `planner-agent` |
| `planned`, `implementing` | implement_tasks | `implement_agents[task_num]` |
| `partial` with continuation | implement_tasks | `implement_agents[task_num]` |
| `partial` with blockers | failed_tasks (mark blocked) | — |
| `partial` with no handoff | implement_tasks | `implement_agents[task_num]` |
| `blocked`, `researching`, `planning`, unknown | skip | — |

`blocked` folding into `skip` here is the one row that still diverges from single-task Stage 4
(which routes `blocked` to `needs_human`/escalation) — and it is intentional, documented, not an
oversight (Decision 1): a batch invocation skips the blocked task so its siblings can proceed,
whereas the single-task engine has no siblings and so escalates to a human instead. See the
`#### State: blocked` handler above and `scripts/orchestrate-triage-classify.sh`'s header table
for the full discriminator between this documented divergence and the now-removed `partial`
divergence.

**Task-lock acquire (per-task, before dispatch)**: Multi-task dispatch bypasses the single-task
gate scripts entirely (`command-gate-in.sh`/`command-gate-out.sh` are never sourced here), so
this stage acquires/releases the lock itself. See `.claude/context/patterns/task-lock.md` for the
full contract. For each task across `research_tasks + plan_tasks + implement_tasks` (before
building the single dispatch message):

```bash
bash .claude/scripts/task-lock.sh acquire "$task_num" "$op" "$session_id" "/orchestrate (multi-task)"
```

**Invariant**: the bare `$session_id` is used here deliberately — it MUST equal the value Stage
MT-1 passed to `session-register` and Stage MT-3 passes to `orchestrate-batch-admit.sh
--session-id`, because `session_contention()`'s self-exclusion is an exact string match on
`session_id`. A per-task-suffixed value (`${session_id}_${task_num}`) would make the batch's own
union-`file_scope` registration read as a foreign live session, refusing every lock acquire in
the batch against its own registration.

where `$op` is `research`/`plan`/`implement` matching the task's group. If `acquire` refuses
(exit 1 — a fresh lock held by a genuinely different session; same-session re-entry, including a
prior cycle of this SAME multi-task run, never refuses), remove that task from this cycle's
dispatch batch (do NOT add it to `failed_tasks` — it becomes eligible again next cycle, mirroring
the wave-split check's defer-not-fail behavior in Stage MT-3 step 4.5) and log:

```
[orchestrate] WARNING: Task #{task_num} is locked by another session; deferring to a later cycle.
```

**Dispatch all groups in ONE message**: the preflight calls below run per task, immediately
before that task's Agent dispatch is composed into the single batched message — they are not a
separate round-trip and do not violate the BATCHING RULE above. `update-task-status.sh` is
idempotent, so calling it once per task per cycle is always safe, including repeated
continuation-resume cycles.

Minting `dispatch_seq` for a batch dispatch (Defect A, applies to all three loops below):
increment the SAME batch-scoped `dispatch_seq_counter` and record the minted value into
`dispatch_seq[$t]`, in the same jq write that records `dispatch_start_ts[$t]` — one atomic
read-modify-write per task, so two tasks dispatched in the same batched message never collide on
the counter:
```bash
task_dispatch_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$mt_state_file")
jq --arg t "$task_num" --argjson ts "$(date -u +%s)" --argjson seq "$task_dispatch_seq" \
  '.dispatch_start_ts[$t] = $ts | .dispatch_seq[$t] = $seq | .dispatch_seq_counter = $seq' \
  "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
```

For each task in `research_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = research_agents[task_num]`, prompt = "Research task $task_num: $description", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }`

For each task in `plan_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- Read `research_artifact` path from `state.json` artifacts (type=report)
- `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = "planner-agent"`, prompt = "Create implementation plan for task $task_num", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }`

For each task in `implement_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- Read `plan_path` from `task_dir/plans/` (latest .md)
- Read `continuation` from `task_dir/.orchestrator-handoff.json`, resolving **either** accepted
  form — nested `continuation_context.handoff_path` or flat top-level `continuation_path` (same
  dual-form rule as `scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate and the
  single-task Stage 4/Stage 5 handlers above) — and **normalizing** the result to
  `{ handoff_path, orchestrator_mode: true }`, or `null` if neither form is present
- `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = implement_agents[task_num]`, prompt = "Implement task $task_num following the plan", context = `{ task_number: task_num, task_type, session_id: "$session_id", orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", continuation_context: continuation, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }` (`continuation_context` here is the **normalized** `continuation` value resolved above, never a raw field read; `session_id` here is the bare value deliberately — see the Task-lock acquire invariant above — because `general-implementation-agent`'s per-phase `task-lock.sh heartbeat` call presents this exact field's value against `holder.json`, and a suffixed value would desync the heartbeat from the lock acquired for this task)

**After all Agent tool calls complete**, read handoffs and run per-task postflight for each dispatched task:

**Per-task transport judgment (narrated, before the handoff loop)**: for each dispatched task,
judge that task's OWN Agent tool call outcome per
`context/patterns/infra-failure-discrimination.md` and set `task_transport_error` for that task
to `true` only if the call itself returned a transport/API-layer error with no
subagent-authored text of any kind. Judge each task independently — never carry one task's
verdict over to another in the same batch.

For each task in `research_tasks + plan_tasks + implement_tasks`:
1. Read `task_dir/.orchestrator-handoff.json`. If present, continue to step 2, which extracts
   fields directly from it as today. **If missing**, first attempt outcome recovery via
   `.return-meta.json` using the SAME shared script single-task Stage 5 (and hard-mode Stage 5)
   consult — `.return-meta.json` is written by every research, plan, and base-mode implement
   dispatch even when that writer is never expected to produce a handoff, so a missing handoff
   here is very often the expected, successful outcome, not a defect. Only if recovery ALSO
   declines does this fall through to the infra-failure discrimination rule
   (`context/patterns/infra-failure-discrimination.md`) scoped to THIS task, exactly as before.

   ```bash
   window_start=$(jq -r --arg t "$task_num" '.dispatch_start_ts[$t] // 9999999999' "$mt_state_file")
   recover_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$task_dir" "$window_start" 2>/dev/null)
   recover_exit=$?
   if [ "$recover_exit" -eq 0 ]; then
     recovered=$(echo "$recover_json" | jq -r '.recovered // false' 2>/dev/null) || recovered=false
   else
     recovered=false
   fi
   ```

   **If `recovered = true`**: log a neutral per-task note and populate this task's
   `dispatch_status`, `phases_completed`, `phases_total`, `plan_markers_verified="absent"`, and
   artifact path/type/summary directly from `$recover_json` — the same fields step 2 would
   otherwise extract from a handoff:

   ```bash
   dispatch_status=$(echo "$recover_json" | jq -r '.status')
   dispatch_summary=""
   phases_completed=$(echo "$recover_json" | jq -r '.phases_completed // 0')
   phases_total=$(echo "$recover_json" | jq -r '.phases_total // 0')
   plan_markers_verified="absent"
   artifact_path=$(echo "$recover_json" | jq -r '.artifact_path // ""')
   artifact_type=$(echo "$recover_json" | jq -r '.artifact_type // ""')
   artifact_summary=$(echo "$recover_json" | jq -r '.artifact_summary // ""')
   echo "[orchestrate] Task #${task_num}: RECOVERY — no handoff written for this dispatch (expected outcome for this phase's writer); .return-meta.json reports status=$dispatch_status; recovering the outcome from it." >&2
   ```

   **Evidence corroboration (identical mirror of the single-task Stage 5 block above)**: same
   precondition (`evidence_suspect=true`, `evidence_reason="PHASES_ZERO_ON_SUCCESS"`,
   `dispatch_status="implemented"` — UNCHANGED by this migration), now calling the same shared
   `skill_corroborate_phase_counts` (scripts/skill-base.sh) single-task Stage 5's recovered
   branch above migrated to, scoped to this task's own `plan_path`/`task_dir`/handoff — never
   another task's in the same wave. Empty handoff-path argument (4th arg omitted): there is no
   handoff to validate on the recovery path.

   A sibling `elif` arm on `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` mirrors the single-task
   Stage 5 arm of the same name: a non-fatal `system-defect-record.sh` call, scoped to this
   task's own `task_num`/`session_id`, attributed to this SKILL.md's own path (no
   dispatched-agent-name variable is unambiguously in scope for this shared per-task loop, which
   spans `research_tasks`, `plan_tasks`, and `implement_tasks` uniformly). It does not call
   `skill_corroborate_phase_counts` and does not touch phase accounting.

   Deliberate convergence (recorded, not silent): the pre-migration banner here read
   `[UNVERIFIED PHASES CORROBORATED] Task #${task_num}: recovery reported status=...` — a
   capitalized `Task #` form distinct from both single-task engines' lowercase `task
   ${task_number}` form. The shared function emits ONE banner shape for every call site; this
   migration adopts that shape here too, removing the third undocumented per-engine
   banner-shape divergence. Grepping the bare `UNVERIFIED PHASES CORROBORATED` token still
   matches identically; only the trailing task-number rendering converges.

   ```bash
   evidence_suspect=$(echo "$recover_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || evidence_suspect=false
   evidence_reason=$(echo "$recover_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || evidence_reason="NONE"
   if [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "PHASES_ZERO_ON_SUCCESS" ] && [ "$dispatch_status" = "implemented" ]; then
     corroboration_plan_path="${plan_path:-}"
     if [ -z "$corroboration_plan_path" ]; then
       corroboration_plan_path=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)
     fi
     cpc_line=$(skill_corroborate_phase_counts "$task_num" "$corroboration_plan_path" "[orchestrate]")
     IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
     phases_completed="${cpc_a#phases_completed=}"
     phases_total="${cpc_b#phases_total=}"
     plan_markers_verified="${cpc_c#plan_markers_verified=}"
   elif [ "$evidence_suspect" = "true" ] && [ "$evidence_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
     # Deliverable 2(a) mirror of the single-task Stage 5 arm above. The dispatched agent for
     # this task_num varies by which group it belongs to (research_agents[task_num],
     # the literal "planner-agent", or implement_agents[task_num]) and this shared per-task
     # postflight loop runs after all three groups without tracking which group each task_num
     # came from here, so (identically to the single-task arm) attribution names this detecting
     # site's own SKILL.md rather than guessing the wrong array.
     echo "[orchestrate] Task #${task_num}: EVIDENCE — recovered .return-meta.json reports status=$dispatch_status with a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — this is proof of a shape mismatch (e.g. a bare-string artifacts array), not proof of \"no artifacts\"." >&2
     record_result=$(bash .claude/scripts/system-defect-record.sh \
       --defect-class ARTIFACTS_SHAPE_MISMATCH \
       --detecting-site "skill-orchestrate/SKILL.md:stage-mt4-recovered" \
       --task "$task_num" --session "${session_id}_${task_num}" \
       --message "recovered return-meta carried a non-empty artifacts array yielding no path" \
       --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
       2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
     append_detected_defect_mt "$task_num" "ARTIFACTS_SHAPE_MISMATCH" \
       "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
       "skill-orchestrate/SKILL.md:stage-mt4-recovered" \
       "recovered return-meta carried a non-empty artifacts array yielding no path" \
       "$record_result"
   fi
   ```

   This task is NOT added to `failed_tasks` and is NOT infra-deferred; **continue into steps 3-6
   below unchanged** — step 2's own handoff read is skipped for this task (there is no handoff to
   read), but the same fields it would have populated are already set here, freshly per task, and
   never carried over from a previous task in the same wave.

   **If `recovered = false`** (including a `recover_exit` of 2): apply the infra-failure
   discrimination rule exactly as before — unchanged from today's behavior. Return-meta recovery
   above is a strictly additive first check; when it declines, a missing handoff still falls
   through to this rule, which remains the sole determinant of `failed_tasks` vs. infra-deferral
   for a genuinely inconclusive dispatch.

   ```bash
   meta_file="${task_dir}/.return-meta.json"
   meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
   task_infra=$(jq -r --arg t "$task_num" '.infra_failures[$t] // 0' "$mt_state_file")

   if [ "${task_transport_error:-false}" = "true" ] && [ "$meta_mtime" -lt "$window_start" ]; then
     task_infra=$((task_infra + 1))
     jq --arg t "$task_num" --argjson n "$task_infra" \
       '.infra_failures[$t] = $n' "$mt_state_file" > "${mt_state_file}.tmp" \
       && mv "${mt_state_file}.tmp" "$mt_state_file"
     if [ "$task_infra" -ge "$MAX_INFRA_FAILURES" ]; then
       echo "[orchestrate] Task #${task_num}: MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached — repeated transport/API failures. Marking failed_tasks." >&2
       # Cap reached: fall back to the historical behavior — add to failed_tasks,
       # release the per-task lock (step 6), skip steps 2-5.
     else
       echo "[orchestrate] Task #${task_num}: INFRA FAILURE ${task_infra}/${MAX_INFRA_FAILURES} — NOT marked failed; stays eligible for the next cycle." >&2
       # Do NOT add to failed_tasks. Release the per-task lock (step 6), skip steps 2-5.
     fi
   else
     # Genuine missing handoff (the subagent ran, or there is no corroborating transport
     # error), and return-meta recovery above also declined: preserve the historical behavior
     # exactly.
     echo "[orchestrate] Task #${task_num}: missing handoff charged as genuine (transport_error=${task_transport_error:-false}). Marking failed_tasks." >&2
     # Add to failed_tasks, release the per-task lock (step 6), skip steps 2-5.
   fi
   ```

   **Bound**: the shared `MAX_CYCLES_MT` still increments once per wave cycle regardless of any
   task's infra verdict, so the outer loop is unchanged and already bounded. Independently, a
   task can be infra-deferred at most `MAX_INFRA_FAILURES` times before it lands in
   `failed_tasks` anyway — so no task can keep the wave alive indefinitely.
2. Extract `dispatch_status`, `dispatch_summary`, artifact path/type/summary, and — from *this*
   task's own handoff, freshly per task — `phases_completed` (`jq -r '.phases_completed // 0'`),
   `phases_total` (`jq -r '.phases_total // 0'`), and `plan_markers_verified`
   (`jq -r '.plan_markers_verified // "absent"'`), mirroring the Stage 5 reads. **When step 1
   recovered the outcome from `.return-meta.json` instead of a handoff, these fields are already
   populated from that recovery — this step's own read applies only when a handoff was actually
   present, and it is this step's own read that the new evidence-corroboration call below
   consumes.** Never carry these values over from a previous task in the same wave; re-read (or,
   on the recovered path, re-recover) them for every task in the loop.

   **Evidence corroboration (handoff-present, per-task)** — the intentional mirror of single-task
   Stage 5's own "Evidence corroboration (handoff-present branch)" block, scoped to exactly this
   task in the loop. PRECONDITION: reachable only when *this task's own* freshly-read
   `dispatch_status = "implemented"` AND its `phases_total -eq 0`. When it fires, re-resolve the
   plan path per task inside the loop — `plan_path` if already set for this task, else
   `ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1` (the same fallback the MT
   recovery block above uses) — then call `skill_corroborate_phase_counts`, scoped to **this
   task's own** `task_dir`, plan path, and handoff, never another task's in the same wave, and
   re-assign `phases_completed` / `phases_total` / `plan_markers_verified` from its output:
   ```bash
   if [ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]; then
     mt_corroboration_plan_path="${plan_path:-}"
     if [ -z "$mt_corroboration_plan_path" ]; then
       mt_corroboration_plan_path=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)
     fi
     cpc_line=$(skill_corroborate_phase_counts "$task_num" "$mt_corroboration_plan_path" "[orchestrate]" "${task_dir}/.orchestrator-handoff.json")
     IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
     phases_completed="${cpc_a#phases_completed=}"
     phases_total="${cpc_b#phases_total=}"
     plan_markers_verified="${cpc_c#plan_markers_verified=}"
   fi
   ```
   D3/D4 apply identically to this call site as to single-task Stage 5's own: the trigger is
   `phases_total -eq 0` alone (not the recovered path's both-zero `PHASES_ZERO_ON_SUCCESS`
   signature), and `skill_gate_completion_claim`'s Case 1 stays structurally unreachable from
   this trigger, since Case 1 requires `phases_total > 0`. See `skill_corroborate_phase_counts`'s
   own header comment in `scripts/skill-base.sh` for the full rationale.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → apply the same completion-claim verification gate as
     Stage 5: call
     `skill_gate_completion_claim "$task_num" "$phases_completed" "$phases_total" "$plan_markers_verified" "[orchestrate]"`.
     `$phases_completed` / `$phases_total` / `$plan_markers_verified` here are NOT necessarily
     the raw handoff fields step 2 first extracted — when step 2's own evidence-corroboration
     block fired and corroborated (this task's `phases_total` was 0 and its plan headings show a
     fully-closed plan), these three variables already carry the corrected, plan-sourced values
     by the time this gate call runs; when it did not fire or did not corroborate, they are
     unchanged from step 2's raw read. Only if the gate returns 0 (allow), call
     `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented "warn"`
     (the trailing `"warn"` mirrors Stage 5's script-side second-opinion backstop; never `refuse`
     here, for the same reason). On a refuse, **skip the postflight call** — the gate has already
     logged which of the three cases fired — and leave the task at `implementing`. Steps 4-6
     below still run unchanged: the artifact is still linked, step 5 reads
     `fresh_status = "implementing"` and takes its `Otherwise` branch (not `completed_tasks`), and
     the per-task lock is still released. The task stays eligible in Stage MT-3's next cycle and
     is re-dispatched, bounded by `MAX_CYCLES_MT`.

     **Additionally, on a refuse, evaluate the caller-side defect discriminant** — the multi-task
     counterpart of single-task Stage 5's own. `skill_gate_completion_claim`'s Case 3/3
     (`phases_total` is 0 AND `plan_markers_verified` is not `"true"`) already called
     `system-defect-record.sh` internally; re-derive that case here from the variables this
     caller already holds, so the observation reaches this run's ledger without reading or
     editing `scripts/skill-base.sh`. Case 1 (`phases_total > 0`, incomplete) is an ordinary
     refuse and is NOT a defect — it must not append. When the discriminant holds, call
     `append_detected_defect_mt "$task_num" "META_MISSING_AFTER_NARRATION"
     "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
     "scripts/skill-base.sh:skill_gate_completion_claim" "completion claimed with phases_total=0
     and unverified plan markers" ""` (empty `record_result`: the recorder ran inside the gate
     function, so its stdout is not observable from this scope). **This changes nothing about the
     refuse path's existing behavior**: steps 4-6 still run unchanged, the task still stays at
     `implementing`, and it still stays eligible for re-dispatch bounded by `MAX_CYCLES_MT`. The
     append only observes.

     **On allow**, immediately after that `skill_postflight_update` call, resolve and propagate
     THIS task's completion data — re-resolved per task on every iteration, never carried over
     from a previous task in the same wave (the same caution already given above for
     `phases_completed`/`phases_total`/`plan_markers_verified`). Reuse this task's own
     `$recover_json` from step 1 when `[ -n "${recover_json:-}" ]` (that task went through the
     return-meta recovery branch this cycle), otherwise issue one additional scoped read using
     this task's own `$task_dir` and the `$window_start` already computed for it in step 1 — the
     handoff schema has no `completion_summary`/`roadmap_items` field, so a handoff-present task
     never populates these for free:
     ```bash
     if [ -n "${recover_json:-}" ]; then
       completion_json="$recover_json"
     else
       completion_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$task_dir" "$window_start" 2>/dev/null)
     fi
     # NOTE: default via `[ -z ] && completion_json='{}'`, never `"${completion_json:-{}}"` — bash
     # parameter-expansion default-word matching stops at the FIRST unescaped `}`, so that inline
     # idiom silently appends a stray trailing `}` to any non-empty value, corrupting the JSON.
     [ -z "${completion_json:-}" ] && completion_json='{}'
     completion_summary=$(echo "$completion_json" | jq -r '.completion_summary // ""' 2>/dev/null) || completion_summary=""
     roadmap_items=$(echo "$completion_json" | jq -c '.roadmap_items // []' 2>/dev/null) || roadmap_items="[]"
     skill_propagate_completion_summary "$task_num" "$completion_summary" "$roadmap_items" "$task_type"
     if [ -z "$completion_summary" ]; then
       completion_reason=$(echo "$completion_json" | jq -r '.reason // "unknown"' 2>/dev/null) || completion_reason="unknown"
       echo "[orchestrate] Task #${task_num}: WARNING: task completed with empty completion_summary (reason=${completion_reason})" >&2
     fi
     ```
     `$task_type` here is the SAME per-task value already threaded into this task's own dispatch
     context object above (Stage MT-2's routing table) — no new lookup is introduced, so a batch
     mixing meta and non-meta tasks cannot leak one task's exclusion onto another's.
   - `dispatch_status` accept-list note (prose form of Stage 5's comment): the normative
     enumeration of the six values used throughout this step is
     `context/formats/return-metadata-file.md`'s status vocabulary, which declares itself
     normative for `.orchestrator-handoff.json`'s `status` field too — keep this list and that
     table in sync rather than letting them drift independently. That table's SEVENTH row,
     `in_progress`, is deliberately excluded below: it is early-metadata-only and never a legal
     terminal dispatch outcome.
   - `dispatch_status = "partial"`, `"failed"`, or `"blocked"` → in-enum exception outcome, no
     postflight update. `skill_postflight_update` in `scripts/skill-base.sh` has its own internal
     `case "$status" in researched|planned|implemented) ... *) ... skip` accept-list, so a call
     from here would no-op one layer deeper regardless (identical to Stage 5's Tier B comment;
     see that comment for the same known, currently-NON-FUNCTIONAL gap and its named follow-up).
     Log an explicit recognition line naming the status: `echo "[orchestrate] Task #${task_num}:
     dispatch status '${dispatch_status}' — recognized exception outcome, no state.json
     transition performed." >&2`. Steps 4-6 still run unchanged.
   - Any other value, **including `null`, empty, and `in_progress`** → OFF-SCHEMA. Emit the same
     `[OFF-SCHEMA DISPATCH STATUS - ...]` banner Stage 5 emits (character-identical, modulo the
     interpolated value) to stderr, with the same `artifacts[0].type`-derived phase inference
     scoped to phase identification only (never a success-vs-partial signal — see Stage 5's own
     MUST-NOT comment on this same inference). Perform no postflight update. This task is charged
     to `failed_tasks` in step 5 below rather than halting the whole wave. **Deliverable 2(b),
     recording**: identically to Stage 5's Tier C arm, also call the recorder non-fatally —
     `bash .claude/scripts/system-defect-record.sh --defect-class OFF_SCHEMA_STATUS
     --detecting-site "skill-orchestrate/SKILL.md:stage-mt4-tier-c" --task "$task_num" --session
     "${session_id}_${task_num}" --message "handoff dispatch_status off-schema" --attributed-path
     "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" >/dev/null 2>&1 || echo
     "Note: system-defect recording failed (non-fatal)" >&2` — scoped to this task's own
     `task_num`/`session_id`, attributed to this SKILL.md's own path since no dispatched-agent-name
     variable is unambiguously in scope for this shared per-task loop. Capture the recorder's
     stdout into `record_result` by dropping only the `>/dev/null` half of that redirect (keep
     stderr discarded and the non-fatal `|| echo` tail intact), then append to this run's
     observation log via the MT append idiom defined at the top of this stage —
     `append_detected_defect_mt "$task_num" "OFF_SCHEMA_STATUS"
     "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
     "skill-orchestrate/SKILL.md:stage-mt4-tier-c" "handoff dispatch_status
     '${offschema_display}' is off-schema" "$record_result"` — which also emits the
     `[system-defect:auto]` notice. The append is UNCONDITIONAL: it never depends on the
     recorder's exit code or on a `SUPPRESSED:` value in `record_result`.
4. Call `skill_link_artifacts` if artifact path is present (same field mapping as Stage 5).
5. Re-read fresh status from `state.json` (postflight may have updated it). Update `mt_state_file.current_statuses[task_num]`:
   - If `fresh_status = "completed"`: also add to `completed_tasks`.
   - If `dispatch_status` is `"failed"` or `"blocked"`: add to `failed_tasks`.
   - If `dispatch_status` is OFF-SCHEMA (step 3's third bullet): add to `failed_tasks` — the
     multi-task analogue of Stage 5's halt. Loud and per-task; deliberately does NOT kill sibling
     tasks in the wave.
   - Otherwise: set `current_statuses[task_num] = fresh_status`.
5.5. **Per-task scoped commit.** MT mode issues one commit per task per phase transition here,
     inside this same per-task loop iteration — never a single combined end-of-batch commit (see
     `commands/orchestrate.md` Step 5's "Commit Reconciliation" note for why the batch commit was
     retired). This step reuses the exact single-task `CHECKPOINT 3` staging template — `task_dir`,
     that task's own `.return-meta.json`, and `dispatch_status` are all already in scope from steps
     1-2 above, so no new state is introduced:

     ```bash
     stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
     [ -n "${plan_path:-}" ] && stage_paths+=("$plan_path")   # implement dispatches only
     metadata_file="${task_dir}/.return-meta.json"
     modified_count=0
     while IFS= read -r f; do
       [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
       # Also accumulate into a cycle-scoped array feeding Stage MT-3 step 7's overlap
       # computation. Accumulated HERE, not re-read at step 7, because postflight cleanup may
       # remove this task's .return-meta.json before step 7 runs later in the same cycle.
       [ -n "$f" ] && cycle_modified_files+=("$f")
     done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
     ```

     **Fail-safe** — the SAME canonical warning `context/standards/git-staging-scope.md`'s
     "Fail-Safe Direction" section specifies, task-scoped by appending the task number (this is
     the only sanctioned wording; do not introduce a second convention):

     ```bash
     if [ "$modified_count" -eq 0 ]; then
       echo "[postflight] WARNING: no modified_files reported for task #${task_num}; source-file changes NOT committed automatically. Review and commit manually." >&2
     fi
     ```

     **Commit message selection**, keyed off this task's own `dispatch_status` (and, for
     `implemented`, whether the completion-claim gate in step 3 allowed or refused the transition —
     read back via `fresh_status` re-read in step 5 above, since a refuse leaves `fresh_status`
     at `implementing` rather than `completed`), per the Standard Actions table in
     `rules/git-workflow.md`:
     - `dispatch_status = "researched"` → `"task ${task_num}: complete research"`
     - `dispatch_status = "planned"` → `"task ${task_num}: create implementation plan"`
     - `dispatch_status = "implemented"` AND `fresh_status = "completed"` (gate allowed) →
       `"task ${task_num}: complete implementation"`
     - `dispatch_status = "implemented"` AND `fresh_status != "completed"` (gate refused), OR
       `dispatch_status = "partial"` → the `CHECKPOINT 3` "on partial" form:
       `"task ${task_num}: orchestration paused (cycles ${cycle_count}/${MAX_CYCLES_MT})"`
     - `dispatch_status = "failed"` or `"blocked"` → `"task ${task_num}: orchestration dispatch
       ${dispatch_status}"`
     - `dispatch_status` OFF-SCHEMA → `"task ${task_num}: orchestration dispatch off-schema"`
       (follows the same `failed`/`blocked` form above, so an off-schema outcome never falls
       through step 5.5 with no `commit_message` assigned)

     ```bash
     bash .claude/scripts/git-commit-scoped.sh \
       --message "$commit_message" \
       --session "${session_id}_${task_num}" \
       --honest-index-rows "$task_num" \
       -- "${stage_paths[@]}"
     ```

     **Non-blocking**: commit failure is logged and execution continues to step 6 — a failed
     commit must never withhold the per-task lock release, which would strand the task.

     **Branch coverage** (every `dispatch_status` / recovery path this loop can reach):
     - **Steps 2-5 skipped** (infra-deferral, `MAX_INFRA_FAILURES` cap reached, genuine-missing-
       handoff charged to `failed_tasks`): step 5.5 is ALSO skipped. Nothing this dispatch produced
       is committable — `dispatch_status` was never resolved for this task this cycle. This is
       deliberate, not an oversight: a later reader should not read the absence of a commit here as
       a bug.
     - **Completion-claim gate refused** (step 3's `implemented` branch, `skill_gate_completion_claim`
       returns non-allow): steps 4-6 already run unchanged on a refuse (per step 3's own prose), so
       step 5.5 DOES run and commits at the partial-form message above, with the task still at
       `implementing`.
     - `dispatch_status = "failed"` or `"blocked"`: step 5.5 runs. Artifacts and status changes the
       dispatch actually produced (e.g. a partial report or a handoff recording the blocker) are
       still real and belong in a commit.
     - `dispatch_status` OFF-SCHEMA: step 5.5 DOES run — artifacts the dispatch actually produced
       are still real and belong in a commit, per the artifact-linking rationale Stage 5's halt
       already relies on. The task is charged to `failed_tasks` (step 5 above).

     **Serialization note**: these per-task commits serialize naturally in program order, because
     per-task postflight is a sequential loop within the orchestrator's own turn — no two
     iterations of this loop ever run concurrently with each other. The `specs/.commit-lock/`
     mutex the scoped-commit helper above acquires internally remains required only for
     cross-process safety against a concurrently-running SEPARATE `/orchestrate` or `/implement`
     dispatch sharing the same index, not against this loop's own iterations.
6. **Task-lock release (per-task, unconditional)**: regardless of the outcome above (success,
   failed, or blocked):
   ```bash
   bash .claude/scripts/task-lock.sh release "$task_num" "$session_id"
   ```
   The release argument must match the acquire argument above — bare `$session_id` — per the
   Task-lock acquire invariant.

### Stage MT-5: Multi-Task Postflight

After the lifecycle-cycling loop exits (all terminal, no eligible tasks, or MAX_CYCLES_MT reached):

1. Read from `mt_state_file`: `completed_tasks`, `failed_tasks`, `deferred_self_modifying`,
   `deferred_deploy_checkpoint`, `dispatch_start_ts`, `defer_ledger`,
   `verify_deploy_baseline_notices`, `detected_defects`, `current_statuses`, `cycles_used`,
   counts. `current_statuses`
   (refreshed every cycle by Stage MT-3 step 1) is what step 3 below consults to determine, per
   task in `deferred_self_modifying`, whether it reached a terminal state by loop exit.
2. **Compute the forward-progress invariant** (full contract in
   `context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
   subsection — referenced here, not restated): set `forward_progress_violated = true` when
   `task_numbers` is non-empty AND `dispatch_start_ts` is an empty object at loop exit; otherwise
   `false`. Write it back to `mt_state_file` so `commands/orchestrate.md` Step 5 can read it. This
   is cause-agnostic by construction — it is true regardless of which `defer_reason` produced the
   zero-dispatch outcome (`self_modifying`, `file_scope_collision`, or `deploy_checkpoint`).
3. Determine `exit_status` — this is the `.return-meta-multi.json` skill-status vocabulary
   (normatively defined in `context/formats/return-metadata-file.md`), distinct from the
   `tasks_completed` array below (which records state.json task status, where `"completed"` is
   correct):
   - `forward_progress_violated == true` → `"partial"` (preserve `mt_state_file` for
     diagnostics), taking precedence over the `"implemented"` branch below. **Why this precedence
     is needed**: the existing conditions key on `failed_count`, non-terminal
     `deferred_self_modifying` residue, and `deferred_deploy_checkpoint` emptiness, so a batch
     that dispatched nothing because every candidate hit `file_scope_collision` would otherwise
     satisfy the `"implemented"` branch with an empty `completed_tasks` array — a batch that did
     nothing reporting success. **This is a status-legibility correction, not an admission or
     behavior change**: no verdict, no task status, no `state.json` write, and no loop condition
     is affected by this branch — only the skill-status string reported for an outcome that
     already dispatched nothing.
   - `failed_count == 0` AND every task in `deferred_self_modifying` reached a terminal state
     (`completed`, `abandoned`, or `expanded`) by loop exit AND `deferred_deploy_checkpoint` is
     empty → `"implemented"` (remove `mt_state_file`). A task that appears in
     `deferred_self_modifying` — meaning the gate deferred it at least once cycle during this
     invocation — but went on to dispatch and complete before the loop exited is a SUCCESS, not a
     partial: the observation log records history, not an outstanding obligation.
   - `failed_count > 0` OR any task in `deferred_self_modifying` is STILL non-terminal at loop
     exit OR `deferred_deploy_checkpoint` is non-empty → `"partial"` (preserve `mt_state_file` for
     diagnostics). The gate here is deliberately narrower than "the log is merely non-empty" — it
     is "the log names a task with unfinished work remaining" — because the log itself no longer
     implies an outstanding exclusion the way it did before the narrowing. A non-empty
     `deferred_deploy_checkpoint` alone (zero `failed_tasks`, and no non-terminal
     `deferred_self_modifying` residue) still yields `"partial"`, never `"implemented"` — that set
     retains its original, unchanged permanent-exclusion semantics: at least one task remains
     undispatched pending a manual deploy/verify fix. This is distinct from a failure: the task is
     not in `failed_tasks` and was never status-mutated, so `"partial"` here means "incomplete by
     design", not "broken".

   **Confirmed invariant, restated not re-derived**: a zero-dispatch outcome mutates no
   `specs/state.json` status and adds nothing to `failed_tasks` — see
   `context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
   subsection for the full reasoning; this stage only reuses it by name.

   **`verify_deploy_baseline_notices` is NEVER consulted by this branch selection.** A batch that
   ran to completion past a pre-existing `verify-deploy.sh` failure (the third operator-visible
   state) is `"implemented"`, exactly as if the checkpoint had never fired at all — this is a
   deliberate decision, stated here so a later pass does not "fix" it into a `"partial"`. Only
   `deferred_deploy_checkpoint` (a genuine, non-empty exclusion set) affects this resolution;
   `verify_deploy_baseline_notices` is a pure observation log with no bearing on `exit_status`.

   **`detected_defects` is likewise NEVER consulted by this branch selection.** A batch that
   completed its work successfully and also observed one or more system-defect detections is
   `"implemented"`. A detection names a defect in the agent system itself, not unfinished work in
   the batch: it excludes no task and mutates no task status, so it cannot make an otherwise
   successful batch partial. This too is a deliberate decision, stated here so a later pass does
   not "fix" it into a `"partial"`.
4. Report `deferred_self_modifying` tasks in the consolidated summary as **deferred at least one
   cycle by the self-modification gate** — an OBSERVATION, not an outstanding-work category. For
   each task in the log, report its FINAL status at loop exit alongside the note: a task that
   reached a terminal state is reported as completed (with the observation as a footnote); a task
   still non-terminal at loop exit is reported as **still pending — deferred, not yet redispatched
   this invocation** and remains eligible for a future `/orchestrate` run (solo or batched) or an
   `--allow-self-modifying` override. Never add a self-modifying-deferred task to `failed_tasks`,
   and never mutate its `specs/state.json` status because of the deferral itself.

   Report `deferred_deploy_checkpoint` tasks as a **distinct** category —
   **deferred-by-redeploy-checkpoint** — separate from both the self-modification-gate
   observation above and `failed_tasks`, because the operator remedy differs: resolve the
   deploy/verify failure, redeploy manually, then re-run `/orchestrate` on the remaining task
   numbers. Never add these tasks to `failed_tasks`, and never mutate their `specs/state.json`
   status.

   Whenever `verify_deploy_baseline_notices` is non-empty, it MUST be reported as its own
   **distinct** category — never folded into the `deferred_deploy_checkpoint` reporting above, and
   never omitted merely because the batch otherwise succeeded (see
   `commands/orchestrate.md`'s `### Pre-Existing Deploy-Verify Failures (Not Deferred)` section for
   the actual rendering — this stage only supplies the data). This is the third
   operator-visible state and must be announced just as loudly as an outright failure, on a
   `"partial"` batch or an `"implemented"` one alike.

   Whenever `detected_defects` is non-empty, it MUST likewise be reported as its own **distinct**
   category — never folded into any defer category, never merged with
   `verify_deploy_baseline_notices`, and never omitted merely because the batch otherwise
   succeeded (see `commands/orchestrate.md`'s `### System Defects Detected` section for the
   actual rendering — this stage only supplies the data). Its operator remedy is different again
   from every category above: the fix belongs in the named source-store path under
   `agent-system/extensions/**`, not in any task's own work.

   **Additive requirement**: when `forward_progress_violated` is true, the consolidated summary
   MUST additionally lead with the zero-dispatch banner and enumerate every `defer_ledger` entry
   with its `defer_reason` (see `commands/orchestrate.md` Step 5 for the actual rendering — this
   stage only supplies the data). This is additive to, and does not replace, the
   `deferred_self_modifying` and `deferred_deploy_checkpoint` reporting instructions above.
5. Write `specs/.return-meta-multi-${session_id}.json`:
```bash
jq -n \
  --arg status "$exit_status" \
  --arg session_id "$session_id" \
  --argjson tasks_completed "$completed_tasks" \
  --argjson tasks_failed "$failed_tasks" \
  --argjson tasks_deferred_self_modifying "$deferred_self_modifying" \
  --argjson tasks_deferred_deploy_checkpoint "$deferred_deploy_checkpoint" \
  --argjson forward_progress_violated "$forward_progress_violated" \
  --argjson defer_ledger "$defer_ledger" \
  --argjson detected_defects "$detected_defects" \
  --argjson verify_deploy_baseline_notices "$verify_deploy_baseline_notices" \
  --argjson cycles_used "$cycles_used" \
  '{
    "status": $status,
    "session_id": $session_id,
    "metadata": {
      "tasks_completed": $tasks_completed,
      "tasks_failed": $tasks_failed,
      "tasks_deferred_self_modifying": $tasks_deferred_self_modifying,
      "tasks_deferred_deploy_checkpoint": $tasks_deferred_deploy_checkpoint,
      "forward_progress_violated": $forward_progress_violated,
      "defer_ledger": $defer_ledger,
      "detected_defects": $detected_defects,
      "verify_deploy_baseline_notices": $verify_deploy_baseline_notices,
      "cycles_used": $cycles_used,
      "multi_task_mode": true
    }
  }' > "specs/.return-meta-multi-${session_id}.json"
```
The top-level `status` field keeps its existing closed vocabulary (`"implemented"` / `"partial"`
/ `"failed"`) and gains no new value; `forward_progress_violated` and `detected_defects` are
carried only inside `metadata`, never as `status` values themselves.

6. **In-flight session registry release**: alongside the `mt_state_file` remove/preserve handling
   above (step 3), release the batch's session registry entry — unconditionally, regardless of
   which `exit_status` branch was taken, so the registry is cleaned up at the same postflight
   boundary as the batch's other session-scoped runtime state. Best-effort and non-blocking; must
   not alter `exit_status`, `forward_progress_violated`, or any other computation above:
   ```bash
   bash .claude/scripts/task-lock.sh session-release "$session_id" 2>/dev/null || true
   ```

---

## MUST NOT (Context Flatness Constraint)

This skill MUST NOT:

1. **Read research reports** (`reports/*.md`) during the state machine loop
2. **Read plan files** (`plans/*.md`) during the state machine loop
3. **Read implementation summaries** (`summaries/*.md`) during the state machine loop
4. **Read continuation handoff files** (`handoffs/*.md`) — pass the path, not the content

The two files read after each dispatch are `.orchestrator-handoff.json` (≤400 tokens) and,
inside the missing/stale-handoff branch only, `.return-meta.json` (see the return-meta fallback
exception below — bounded to a handful of scalar fields, no report prose).
This ensures context grows by only ~450 tokens per cycle regardless of artifact complexity.

**Recovery exception (return-meta fallback)**: When — and only when — Stage 5 has already
determined that this dispatch's `.orchestrator-handoff.json` is missing or stale, the
orchestrator consults `scripts/orchestrate-recover-outcome.sh`, which reads
`<task_dir>/.return-meta.json` and returns a single-line JSON object of scalar fields. The same
four bounds this section already holds recovery exceptions to apply here too:

- **Fields-only**: the script extracts `status`, `artifacts[0].path/type/summary`,
  `phases_completed`, and `phases_total` — never a report, plan, summary, or handoff file's
  content. No free-text prose ever enters context.
- **Missing/stale-handoff-branch-only precondition**: it fires only where the handoff read has
  already failed, and nowhere else. It is never a routine per-cycle read, and never a substitute
  for reading a handoff that is present and fresh.
- **Token ceiling**: one JSON object of ~10 scalar fields, a hard ceiling well under 100 tokens
  per recovery event.
- **Authoritative, unlike the phase-marker grep below**: a `recovered=true` outcome DOES
  synthesize a `dispatch_status` and DOES drive the normal postflight status transition —
  `.return-meta.json` is the file every research/plan/base-implement dispatch already writes as
  its own contractual success signal, so a fresh, parseable `researched`/`planned`/`implemented`
  status is exactly as trustworthy here as it is when `command-gate-out.sh` reads the same file
  for the non-orchestrator path. This is the one place the two recovery exceptions in this
  section diverge: the phase-marker grep below is diagnostic-only and never moves `state.json`,
  while this exception is the ONLY thing standing between "no handoff" and "task stranded."

**Recovery exception (phase-marker grep)**: When — and only when — Stage 5 has already
determined that this dispatch's `.orchestrator-handoff.json` is missing or stale AND return-meta
recovery above also declined, the orchestrator MAY run at most two count-only `grep -c` calls
against the plan file's `### Phase N: {name} [STATUS]` heading lines to recover
`phases_completed` / `phases_total`. All four bounds below are binding:

- **Count-only**: `grep -c`, never `grep`. No matched line content ever enters context — the
  two calls return one integer each, a hard ceiling of **≤10 tokens per recovery event**.
- **Heading lines only**: the patterns anchor on `^### Phase N: `. Checklist items, prose,
  deviation annotations, and every other part of the plan file remain out of scope.
- **Recovery-only precondition, THREE reachable branches**: fires from exactly three places,
  never elsewhere. (1) The missing/stale-handoff branch of Stage 5, after return-meta recovery
  above has already declined — the original branch documented here, still the raw inline
  two-`grep -c` idiom directly (diagnostic-only; it never sets `plan_markers_verified` and never
  calls the shared function, since it has no recoverable `dispatch_status` to corroborate
  against). (2) The recovered=true branch above, but ONLY when return-meta recovery's own
  `evidence_suspect`/`evidence_reason` fields report `PHASES_ZERO_ON_SUCCESS` for a claimed
  `implemented` status — the evidence-corroboration block that widens this exception's trigger
  to the one scenario branch (1) structurally cannot see, since branch (1) requires
  `recovered=false`. (3) The handoff-present branch (Stage 5's `else`, and its Stage MT-4 step 2
  mirror), but ONLY when the handoff itself reports `dispatch_status = "implemented"` AND
  `phases_total -eq 0` — the scenario branches (1) and (2) structurally cannot see, since both
  require the handoff to be missing, stale, or recovered from `.return-meta.json` rather than
  read directly. Branches (2) and (3) both call the SAME shared `skill_corroborate_phase_counts`
  (`scripts/skill-base.sh`), which performs the same two `grep -c` calls inside itself rather
  than inline — the single anchor both branches (and their hard-mode and multi-task mirrors)
  now share, in the same way `scripts/lib/phase-heading-patterns.sh` is the single grammar
  anchor every phase-heading consumer sources rather than re-deriving. None of the three
  branches is a routine per-cycle read, and none is a substitute for reading a handoff that is
  present and fresh with populated accounting — the normal path (fresh handoff,
  `phases_total > 0` or `plan_markers_verified` already set) never reaches any of them.
  **Still exactly three, not four**: branch (2)'s recovered=true site also carries a sibling
  `elif` arm on `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` (Deliverable 2(a), a
  `system-defect-record.sh` consumer call) — it shares branch (2)'s `recovered=true`
  precondition but never calls `skill_corroborate_phase_counts` and performs no `grep -c` of any
  kind, so it does not add a fourth reachable branch to this phase-marker-recovery enumeration.
  **Known residual gap (recorded, not fixed here)**: branch (3), the handoff-present path
  (Stage 5's `else`), never calls `orchestrate-recover-outcome.sh`, so `ARTIFACTS_SHAPE_MISMATCH`
  is never *computed* there at all — the new consumer arm above covers only the recovered-path
  occurrence of this signal. Closing that detection hole is out of scope for this work; it is
  named here so a future reader does not assume full coverage.
- **Diagnostic in branch (1), evidence-based escalation in branches (2) and (3)**: in branch (1)
  the recovered counts are logged and recorded in the loop guard only — they never synthesize a
  `dispatch_status` and never drive a status transition, since there is no recoverable outcome
  to trust. In branches (2) and (3) a *corroborating* grep result (heading count matches the
  claimed phase count exactly, or the plan is fully closed) DOES set
  `plan_markers_verified="true"` and corrects `phases_completed`/`phases_total` for the
  completion-claim gate to act on — in branch (2) the recovery script's own emitted 0/0 values
  are left untouched, only this orchestrator-side variable is corrected; in branch (3) the
  handoff's own null/zero fields are likewise left unwritten, since this branch reads them but
  never rewrites the file. In both branches the correction is sourced from an independent
  artifact (the plan file), never from the off-schema value itself. A non-corroborating result
  in branch (2) or (3) is treated identically to branch (1): diagnostic-only,
  `plan_markers_verified` stays `absent`.

These three named branches — (1) missing/stale-handoff recovery, (2) recovered=true
PHASES_ZERO_ON_SUCCESS corroboration, (3) handoff-present implemented/phases_total=0
corroboration — are the ONLY places item 2 is narrowed; items 1, 3, and 4 stay unrelaxed
everywhere, and item 2 stays fully in force outside these three branches. The normal path — a
fresh handoff with `phases_total > 0` or an already-populated `plan_markers_verified` — reads no
plan file at all, so the ~450-tokens-per-cycle flatness invariant is unaffected there.

---

## MUST NOT (Postflight Boundary)

This section is distinct from, and additive to, the Context Flatness Constraint above: that
section bounds what this skill reads between dispatches; this section bounds what this skill
does. After each stage dispatch (research/plan/implement) returns, this skill MUST NOT:

1. **Edit source files** - All research, planning, and implementation work is done by the
   dispatched skill/agent, never by the orchestrator's own state-machine loop
2. **Run build/test commands** - Verification is done by the dispatched skill/agent
3. **Use MCP/WebSearch/domain tools** - Domain tools are for the dispatched skill/agent's use only
4. **Analyze or grep source** - Analysis is dispatched-skill work
5. **Write reports/plans/summaries** - Artifact creation is dispatched-skill work

The per-dispatch postflight phase is LIMITED TO:
- Reading the dispatch's `.orchestrator-handoff.json` (or the bounded return-meta/phase-marker
  recovery exceptions documented above)
- Driving the state-machine transition to the next stage
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research dispatch | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Plan dispatch | `$PLANNER_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Implement dispatch | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes .drift-inspection.json |
| Plan revision (drift) | `"reviser-agent"` | Triggered when drift_pct > DRIFT_REVISION_THRESHOLD |

Default agents: `general-research-agent`, `planner-agent`, `general-implementation-agent`. Extension agents resolved in Stage 1b via `command-route-agent.sh`.
