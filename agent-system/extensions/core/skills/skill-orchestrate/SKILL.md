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

Map task_type to the correct research and implementation agents using extension manifests.

```bash
# Resolve agents by task_type — consult extension manifests for non-core types
case "$TASK_TYPE" in
  lean4|lean)
    RESEARCH_AGENT="lean-research-agent"
    IMPLEMENT_AGENT="lean-implementation-agent"
    ;;
  neovim)
    RESEARCH_AGENT="neovim-research-agent"
    IMPLEMENT_AGENT="neovim-implementation-agent"
    ;;
  nix)
    RESEARCH_AGENT="nix-research-agent"
    IMPLEMENT_AGENT="nix-implementation-agent"
    ;;
  *)
    RESEARCH_AGENT="general-research-agent"
    IMPLEMENT_AGENT="general-implementation-agent"
    ;;
esac
echo "[orchestrate] Task type: $TASK_TYPE → research=$RESEARCH_AGENT, implement=$IMPLEMENT_AGENT"
```

**Extension resolution**: If a task_type is not in the case table above, check for an extension manifest:
```bash
manifest=".claude/extensions/${TASK_TYPE}/manifest.json"
if [ -f "$manifest" ]; then
  ext_research=$(jq -r ".routing.research[\"$TASK_TYPE\"] // empty" "$manifest")
  ext_implement=$(jq -r ".routing.implement[\"$TASK_TYPE\"] // empty" "$manifest")
  # Map skill names to agent names (skill-X-Y -> X-Y-agent)
  if [ -n "$ext_research" ]; then
    RESEARCH_AGENT=$(echo "$ext_research" | sed 's/^skill-//' | sed 's/$/-agent/')
  fi
  if [ -n "$ext_implement" ]; then
    IMPLEMENT_AGENT=$(echo "$ext_implement" | sed 's/^skill-//' | sed 's/$/-agent/')
  fi
fi
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

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard. No session_id or mtime check — see the ephemerality note above;
  # this is precisely why a git-restorable guard would corrupt the cycle budget.
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker (task 808). A plain
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
      "started": $started,
      "last_updated": $started
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    infra_failures=0
    echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES, MAX_INFRA_FAILURES=$MAX_INFRA_FAILURES"
  else
    # Lost the creation race: another writer won. Resume from their guard, reading BOTH
    # counters — not just cycle_count.
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
  fi
fi

# Blocker escalation counter (reset each /orchestrate invocation)
blocker_escalation_count=0
MAX_BLOCKER_ESCALATIONS=2

# Drift detection constants (reset each /orchestrate invocation)
drift_inspection_count=0
MAX_DRIFT_INSPECTIONS=1
DRIFT_COMPLETION_THRESHOLD=0.70
DRIFT_REVISION_THRESHOLD=0.30
```

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
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"

# Task-lock heartbeat: refresh at the same per-cycle boundary as the loop guard, so a
# multi-hour single-task /orchestrate run (whose lock was acquired once at orchestrate.md's
# CHECKPOINT 1) never goes stale under its own hand. No-op with a warning if the lock is
# somehow missing or held by another session — heartbeat never blocks this loop. See
# .claude/context/patterns/task-lock.md.
bash .claude/scripts/task-lock.sh heartbeat "$task_number" "$session_id" 2>/dev/null || true
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
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Research task $task_number: $DESCRIPTION" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` |

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
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"planner-agent"` |
| `prompt` | "Create implementation plan for task $task_number" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` |

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
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` |

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
# Dual-form resolution + normalization: a continuation pointer may arrive as either the nested
# continuation_context.handoff_path (written today only by the unreferenced
# skill_write_orchestrator_handoff) OR the flat top-level continuation_path (what live H9
# hard-mode wrap-up writers actually emit). Resolve either form and normalize into the single
# shape the dispatch context below and context/patterns/subagent-continuation-loop.md both
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
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Resume implementation for task $task_number from continuation handoff" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, continuation_context: continuation, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` (`continuation_context` here is the **normalized** `continuation` object built above — `{ handoff_path, orchestrator_mode: true }` — never a raw read of the handoff's `continuation_context` or `continuation_path` field. This is the secondary-gap fix: it is what lets the successor implement dispatch actually consume a continuation the standard flat-form writer emitted. Do not "simplify" this back to a raw field read.) |

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
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, resume_context: { status: (resume_probe.status), artifact_path: (resume_probe.artifact_path), phases_completed: (resume_probe.phases_completed), phases_total: (resume_probe.phases_total) } }` (same as the continuation branch's `context` object, minus `continuation_context`, plus `resume_context`) |

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

# ── Staleness gate ────────────────────────────────────────────────────────────
# A handoff sitting at the correct path does NOT prove this dispatch wrote it. If the current
# dispatch wrote nothing (or wrote somewhere else), the PREVIOUS cycle's file is still there,
# and reading it reports the previous cycle's status and phases_completed as if they were this
# one's — a silent wrong answer, worse than a detected absence.
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
  fi
fi

# ── Stray-handoff sweep ───────────────────────────────────────────────────────
# Mechanism-agnostic backstop. The validate-handoff-location.sh PostToolUse hook catches
# Write/Edit-tool misplacements, but it is structurally unable to see a Bash-redirect write
# (skill_write_orchestrator_handoff writes via `jq -n ... > "$handoff_path"`; a Bash tool_input
# carries unexpanded command text, so the resolved destination is never visible to a hook).
# This sweep catches a misplaced handoff no matter how it was written.
#
# Deliberately bounded to two exact paths — the repo root and specs/ — not a recursive find.
# Those are the two places an unanchored write actually lands.
sweep_root="${SKILL_REPO_ROOT:-$(pwd)}"
for stray in "${sweep_root}/.orchestrator-handoff.json" "${sweep_root}/specs/.orchestrator-handoff.json"; do
  if [ -e "$stray" ]; then
    echo "[orchestrate] ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
    echo "[orchestrate] The correct destination is $handoff_file." >&2
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
      # `x=$(grep -c ...) || x=0` — grep exits 1 on zero matches. Never `$(grep -c ... || echo 0)`,
      # which emits two lines in that case.
      recovered_total=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: ' "$recovery_plan_path" 2>/dev/null) || recovered_total=0
      recovered_completed=$(grep -cE '^### Phase [0-9]+(\.[0-9]+)?: .*\[COMPLETED\]' "$recovery_plan_path" 2>/dev/null) || recovered_completed=0
      echo "[orchestrate] RECOVERY: handoff unusable — plan headings show ${recovered_completed}/${recovered_total} phases [COMPLETED] in ${recovery_plan_path}." >&2

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
      # present-and-incomplete always refuses, absent falls back to plan_markers_verified — the
      # recovered path above always sets plan_markers_verified="absent", so an absent phase
      # count on a recovered "implemented" claim is conservatively refused here, not allowed).
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

After Agent tool returns: read `$handoff_file` for research findings.

**Step 3: READ FINDINGS** — From handoff:
```bash
findings_summary=$(jq -r '.summary // "No findings"' "$handoff_file")
findings_artifact=$(jq -r '.artifacts[0].path // ""' "$handoff_file")
```

**Step 4: REVISE PLAN** — Read latest plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"reviser-agent"` |
| `prompt` | "Revise the implementation plan for task $task_number to address this blocker: $blocker_desc. Research findings: $findings_summary" |
| `context` | `{ task_number, session_id, research_findings: findings_summary, plan_path, orchestrator_mode: false }` |

After Agent tool returns: read handoff to confirm revision.

**Step 5: RE-DISPATCH IMPLEMENT** — Read revised plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the revised plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` |

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

If MAX_CYCLES reached (cycle_count >= MAX_CYCLES):

```
echo "[orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
echo "Current state: $current_status. Run /orchestrate $task_number to continue."
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
echo "Status: $current_status | Cycles: $cycle_count/$MAX_CYCLES | Run /orchestrate $task_number to continue."
```

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
  '. * {
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
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
tmp_meta=$(mktemp)
echo "$existing_meta" | jq \
  --arg status "partial" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '. * {
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
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
- `session_id`, `lit_flag`

Compute: `task_count = length(task_numbers)`, `MAX_CYCLES_MT = min(task_count * 5, 25)`,
`MAX_INFRA_FAILURES = 3` (flat **per task**, not scaled by `task_count` — matching single-task
mode; see `context/patterns/infra-failure-discrimination.md`).

Initialize `mt_state_file = "specs/.orchestrator-multi-state.json"` with fields: `session_id`,
`task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, `failed_tasks: []`,
`completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`,
`implement_agents: {}`, `infra_failures: {}` (map task_num -> count, default 0),
`dispatch_start_ts: {}` (map task_num -> unix seconds, written at dispatch time), and
`deferred_self_modifying: []` — an INVOCATION-SCOPED set (persists across every cycle of this
same `mt_state_file`, never reset mid-invocation) of task numbers the self-modification gate has
excluded. This is the mechanism that makes the exclusion converge: without it, a self-modifying
task deferred out of one cycle would simply re-qualify as eligible on the very next cycle (its
predecessors are still terminal, its status is still non-terminal) and the gate would re-fire
every cycle forever, never letting the invocation reach an all-terminal state. See Stage MT-3
step 3 (eligibility exclusion) and step 4.5 (population) below, and Stage MT-5 (postflight
reporting) for the three places this set is read or written.

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

1. **Status refresh**: For each task in `task_numbers`, read current status from `state.json` and update `mt_state_file.current_statuses`.

2. **All-terminal check**: If every task is in `{completed, abandoned, expanded}`, in
   `failed_tasks`, OR in `deferred_self_modifying` — break loop (exit success or partial). A task
   in `deferred_self_modifying` is deliberately excluded, not stuck, so this check treats it the
   same as a terminal/failed task for the purpose of deciding whether the loop has anything left
   to do — see step 3's exclusion and step 4.5's population of this set below.

3. **Build eligible_tasks**: For each task, include it if ALL of the following are true:
   - Status is NOT `{completed, abandoned, expanded}` and NOT in `failed_tasks`
   - Task number is NOT in `deferred_self_modifying` (populated by step 4.5 below; this is the
     mechanism that makes the exclusion converge — without it, a self-modifying task deferred out
     of one cycle would simply re-qualify as eligible again on the very next cycle, since its own
     status and predecessors have not changed, and the gate would re-fire every cycle forever)
   - Status is NOT `{researching, planning}` (in-flight from prior cycle)
   - All predecessors from `dependency_graph[task_num]` are in terminal state or `failed_tasks`
   
   If a predecessor is in `failed_tasks`: mark this task in `failed_tasks` with status `blocked` and skip it.
   If a predecessor is still in-progress: skip this task (wait for next cycle).

4. **No-eligible circuit breaker**: If `eligible_tasks` is empty AND at least one task remains
   that is NOT terminal, NOT in `failed_tasks`, and NOT in `deferred_self_modifying` — log warning
   with list of stuck tasks and break loop (exit partial). (If every remaining non-eligible task
   is accounted for by step 2's All-terminal check instead — i.e. every task is terminal, failed,
   or deferred-self-modifying — step 2 has already broken the loop before this step runs, so this
   circuit breaker's "stuck tasks" framing is reserved for genuinely stuck tasks, never for a
   deliberately deferred self-modifying one.)

4.5. **Runtime wave-split check (cross-batch defense-in-depth)**: Before dispatching
   `eligible_tasks` on EVERY cycle — including a cycle where `eligible_tasks` contains only a
   single task, since a cross-batch collision exists at batch size 1 — call the admission
   script, passing `--invocation-count` set to this invocation's FULL `task_numbers` count (NOT
   `${#eligible_tasks[@]}`), so the self-modification defer trigger below is evaluated against
   the whole invocation, never just this cycle's eligible subset:
   ```bash
   bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#task_numbers[@]}" "${eligible_tasks[@]}"
   ```
   This compares each eligible task's `file_scope` against every non-terminal task in a single
   `specs/state.json` read — the comparison set is every non-terminal task in state, not merely
   this invocation's own `task_numbers` set. This is still not a repo-wide filesystem scan: no
   globbing, no second read, just one read of
   `specs/state.json` per cycle. The predicate itself is the shared directory-prefix overlap
   algorithm in `.claude/context/patterns/file-footprint-overlap.md` (referenced by path — not
   restated here); the verdict schema is published in
   `.claude/docs/architecture/batch-admit-schema.md` (also referenced by path, never restated).

   `jq`-filter stdout for `.decision == "defer"`, then branch on `defer_reason` FIRST (v2 schema
   — every defer verdict carries this REQUIRED discriminator; checking `collision_scope` without
   checking `defer_reason` first would misread a self-modifying defer as an ordinary in-batch
   collision, since both verdicts carry a `reason` string):

   - **`self_modifying`** (the candidate's own `file_scope` names an orchestrator-critical path):
     remove the candidate from this cycle's dispatch batch AND add it to the INVOCATION-SCOPED
     `mt_state_file.deferred_self_modifying` set (persists for the remainder of this
     invocation — this is the critical difference from the two `file_scope_collision` branches
     below, which only affect the current cycle). **This is the mechanism that makes the
     exclusion converge**: without recording it in `deferred_self_modifying`, the task would
     simply re-qualify as eligible again on the very next cycle (see step 3's exclusion above)
     and this check would re-fire every cycle forever, and the invocation would never reach an
     all-terminal state. The task is never added to `failed_tasks` and never status-mutated. Log
     a **distinct** warning naming the matched critical path and label:
     ```
     [orchestrate] WARNING: Task #{task_number} has file_scope naming orchestrator-critical
       path {critical_path} ({critical_label}). Orchestrator-critical work runs solo only —
       excluding #{task_number} from this invocation. Re-run it alone: /orchestrate {task_number}
     ```
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
     - **`cross_batch`** (the colliding task is NOT part of `task_numbers` for this invocation):
       remove the candidate from this cycle's dispatch batch and log a **distinct** warning naming
       the out-of-batch task and its `colliding_task_status`:
       ```
       [orchestrate] WARNING: Task #{task_number} has overlapping file_scope with task
         #{colliding_task_number} (status: {colliding_task_status}), which is OUTSIDE this
         invocation's task_numbers. Excluding #{task_number} from this cycle — batch
         composition needs human review.
       ```

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

### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight

> **BATCHING RULE**: ALL Agent tool calls for the current cycle's dispatch batch MUST be issued in a SINGLE orchestrator message with multiple tool-use content blocks. Do NOT issue calls across multiple messages — Claude Code processes all calls in a single message concurrently; multiple messages force sequential execution.

> **COMPLETION SEQUENCING**: After ALL Agent tool calls complete (Claude Code returns control after all calls in the single message finish), read handoffs for every dispatched task. Do NOT read handoffs interleaved with dispatches. Per-task postflight (below) now includes a scoped git commit (step 5.5); these commits serialize naturally in program order because postflight is a sequential loop within this same orchestrator turn, so the `specs/.commit-lock/` mutex is needed only against a concurrently-running separate dispatch, never against this loop's own iterations.

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
bash .claude/scripts/task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" "/orchestrate (multi-task)"
```

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

For each task in `research_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window: `jq --arg t "$task_num" --argjson ts "$(date -u +%s)" '.dispatch_start_ts[$t] = $ts' "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"`, and reset this task's `task_transport_error` to `false`
- `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = research_agents[task_num]`, prompt = "Research task $task_num: $description", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs }`

For each task in `plan_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window: `jq --arg t "$task_num" --argjson ts "$(date -u +%s)" '.dispatch_start_ts[$t] = $ts' "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"`, and reset this task's `task_transport_error` to `false`
- Read `research_artifact` path from `state.json` artifacts (type=report)
- `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = "planner-agent"`, prompt = "Create implementation plan for task $task_num", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs }`

For each task in `implement_tasks`:
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window: `jq --arg t "$task_num" --argjson ts "$(date -u +%s)" '.dispatch_start_ts[$t] = $ts' "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"`, and reset this task's `task_transport_error` to `false`
- Read `plan_path` from `task_dir/plans/` (latest .md)
- Read `continuation` from `task_dir/.orchestrator-handoff.json`, resolving **either** accepted
  form — nested `continuation_context.handoff_path` or flat top-level `continuation_path` (same
  dual-form rule as `scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate and the
  single-task Stage 4/Stage 5 handlers above) — and **normalizing** the result to
  `{ handoff_path, orchestrator_mode: true }`, or `null` if neither form is present
- `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"`
- Invoke Agent tool: `subagent_type = implement_agents[task_num]`, prompt = "Implement task $task_num following the plan", context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, plan_path, continuation_context: continuation, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs }` (`continuation_context` here is the **normalized** `continuation` value resolved above, never a raw field read)

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
   present.** Never carry these values over from a previous task in the same wave; re-read (or,
   on the recovered path, re-recover) them for every task in the loop.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → apply the same completion-claim verification gate as
     Stage 5: call
     `skill_gate_completion_claim "$task_num" "$phases_completed" "$phases_total" "$plan_markers_verified" "[orchestrate]"`
     and, only if it returns 0 (allow), call
     `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented "warn"`
     (the trailing `"warn"` mirrors Stage 5's script-side second-opinion backstop; never `refuse`
     here, for the same reason). On a refuse, **skip the postflight call** — the gate has already
     logged which of the three cases fired — and leave the task at `implementing`. Steps 4-6
     below still run unchanged: the artifact is still linked, step 5 reads
     `fresh_status = "implementing"` and takes its `Otherwise` branch (not `completed_tasks`), and
     the per-task lock is still released. The task stays eligible in Stage MT-3's next cycle and
     is re-dispatched, bounded by `MAX_CYCLES_MT`.

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
     to `failed_tasks` in step 5 below rather than halting the whole wave.
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
   bash .claude/scripts/task-lock.sh release "$task_num" "${session_id}_${task_num}"
   ```

### Stage MT-5: Multi-Task Postflight

After the lifecycle-cycling loop exits (all terminal, no eligible tasks, or MAX_CYCLES_MT reached):

1. Read from `mt_state_file`: `completed_tasks`, `failed_tasks`, `deferred_self_modifying`,
   `cycles_used`, counts.
2. Determine `exit_status` — this is the `.return-meta-multi.json` skill-status vocabulary
   (normatively defined in `context/formats/return-metadata-file.md`), distinct from the
   `tasks_completed` array below (which records state.json task status, where `"completed"` is
   correct):
   - `failed_count == 0` AND `deferred_self_modifying` is empty → `"implemented"` (remove
     `mt_state_file`)
   - `failed_count > 0` OR `deferred_self_modifying` is non-empty → `"partial"` (preserve
     `mt_state_file` for diagnostics). A non-empty `deferred_self_modifying` alone (zero
     `failed_tasks`) still yields `"partial"`, never `"implemented"` — the invocation did not
     actually finish everything it was asked to; one task remains undispatched pending a solo
     re-run. This is distinct from a failure: the task is not in `failed_tasks` and was never
     status-mutated, so `"partial"` here means "incomplete by design", not "broken".
3. Report `deferred_self_modifying` tasks in the consolidated summary as **deferred-for-solo-run**
   — a category distinct from both `completed_tasks` and `failed_tasks`. Never add a
   deferred-self-modifying task to `failed_tasks`, and never mutate its `specs/state.json` status
   — it simply was not dispatched by this invocation and remains eligible for a future solo
   `/orchestrate {task_number}` run.
4. Write `specs/.return-meta-multi.json`:
```bash
jq -n \
  --arg status "$exit_status" \
  --argjson tasks_completed "$completed_tasks" \
  --argjson tasks_failed "$failed_tasks" \
  --argjson tasks_deferred_self_modifying "$deferred_self_modifying" \
  --argjson cycles_used "$cycles_used" \
  '{
    "status": $status,
    "metadata": {
      "tasks_completed": $tasks_completed,
      "tasks_failed": $tasks_failed,
      "tasks_deferred_self_modifying": $tasks_deferred_self_modifying,
      "cycles_used": $cycles_used,
      "multi_task_mode": true
    }
  }' > "specs/.return-meta-multi.json"
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
- **Recovery-only precondition**: it fires inside the missing/stale-handoff branch of Stage 5,
  after return-meta recovery has already declined, and nowhere else. It is never a routine
  per-cycle read, and never a substitute for reading a handoff that is present and fresh.
- **Diagnostic, not authoritative**: the recovered counts are logged and recorded in the loop
  guard. They never synthesize a `dispatch_status` and never drive a status transition — with
  no handoff AND no recoverable return-meta status there is no dispatch outcome to trust.

These two exceptions narrow item 2 inside one branch; they do not relax items 1, 3, or 4, and
they do not relax item 2 anywhere else. The ~450-tokens-per-cycle flatness invariant is
unaffected on the normal path, where neither recovery mechanism runs at all.

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research dispatch | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Plan dispatch | `"planner-agent"` | Fresh context; `orchestrator_mode: true` |
| Implement dispatch | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes .drift-inspection.json |
| Plan revision (drift) | `"reviser-agent"` | Triggered when drift_pct > DRIFT_REVISION_THRESHOLD |

Default agents: `general-research-agent`, `general-implementation-agent`. Extension agents resolved in Stage 1b.
