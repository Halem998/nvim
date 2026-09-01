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
- `clean_flag` (default: `"false"`) — threaded from the command's `--clean` flag; suppresses
  Stage 3.5 Dispatch Prep's automatic memory retrieval for every dispatch this invocation makes.
- `effort_flag` (default: `""`) — threaded from the command's `--fast` flag; supplies reasoning-
  depth guidance to Stage 3.5 Dispatch Prep and to Stage 1b's agent routing below.
- `model_flag` (default: `""`) — threaded from the command's `--haiku`/`--sonnet`/`--opus`/
  `--fable` flags; selects the model family for every lifecycle dispatch this invocation makes.
  Consumed by Stage 3.5 Dispatch Prep's model-override resolution below. The not-set sentinel is
  the **empty string**, matching `parse-command-args.sh`'s `MODEL_FLAG=""` default — **not** the
  literal token `null`, despite `commands/research.md`'s prose framing.
- `hard_mode` — derived once, here, as `hard_mode="false"; [ "$effort_flag" = "hard" ] &&
  hard_mode="true"`. Consumed by Stage 3.5 Dispatch Prep's hard-mode contract injection below,
  and reserved for later conditional state-machine branches (churn/three-strikes counters, the
  burnout circuit breaker) that read this same boolean rather than re-deriving it.
- `team_mode` (default: `"false"`), `team_size` (default: `2`), `team_size_explicit` (default:
  `"false"`) — threaded from the command's `--team`/`--team-size` flags. Derive `team_size_eff`,
  the effective per-cycle teammate count Stage 3.6 consumes, immediately here, per D2 of this
  stage's originating plan: when `team_size_explicit` is `"true"`, `team_size_eff="$team_size"`;
  otherwise apply the effort-aware default table — `3` baseline, `2` when `effort_flag` is
  `"fast"`, `4` when `effort_flag` is `"hard"` — then clamp the result to the 2-4 range:

  ```bash
  team_mode="${team_mode:-false}"
  team_size="${team_size:-2}"
  team_size_explicit="${team_size_explicit:-false}"
  if [ "$team_size_explicit" = "true" ]; then
    team_size_eff="$team_size"
  else
    team_size_eff=3
    [ "$effort_flag" = "fast" ] && team_size_eff=2
    [ "$effort_flag" = "hard" ] && team_size_eff=4
  fi
  [ "$team_size_eff" -lt 2 ] && team_size_eff=2
  [ "$team_size_eff" -gt 4 ] && team_size_eff=4
  ```
- `force_phases` (default `""`) — threaded from the command's composable `--research`/`--plan`/
  `--implement` flags (A2). Single-task-only. Consumed by Stage 2b below, which splits it into
  the ordered forced-phase queue the state machine loop's Stage 3 sub-step 3c checks first, ahead
  of status-derived dispatch. Never forwarded to any admission-gate script.

**Hard-mode state-machine migration — acceptance checklist.** Each behavior below is reproduced
in this engine behind `$hard_mode`, mapped to the stage that now implements it:

| Behavior | Stage | Notes |
|----------|-------|-------|
| Conditional cycle budget (13 vs. 5) | Stage 2 head | `MAX_CYCLES` branch, before `orchestrate-loop-guard-init.sh` |
| Unified loop-guard JSON schema | Stage 2 | `hard_mode`/`burnout_signals_this_session`/`plan_version` fields, written in both modes |
| `loop-guard-staleness` detector (3-signal) | Stage 2 | `loop-guard-staleness:begin`/`:end`, hard-mode-gated only (D4) |
| Churn-state init (`.orchestrator-churn-state.json`) | Stage 2 | after `mint_dispatch_seq()`, hard-mode-gated only |
| Burnout circuit-breaker gate | Stage 3, sub-step `3b-hard` | between `3b.` and `3c.`, `3c.` left byte-identical (D2) |
| H1 single-blocking-phase-per-cycle implement dispatch | Stage 4, `#### State: planned or implementing` | whole handler forked on `$hard_mode` (D5); base `else` branch unchanged |
| H6 per-target churn counters | Stage 5b | after Stage 5's own `phases_completed` assignment (D7) |
| H5 three-strikes divergence-audit dispatch | Stage 5b | same stage as H6, on `new_target_churn >= 3` |
| Stage 5a / Stage 5b mutual exclusion | Stage 5a (gate), Stage 5b (heading) | exactly one reachable per `hard_mode` value |

**Not migrated**: the `researched`-state adversarial verification gate (H4) — see the residue
note immediately below. Everything else in the source engine's state-machine logic (H1/H5/H6/the
burnout breaker, plus the loop-guard/churn-state plumbing they depend on) is now reproduced here.

**Hard-mode residue not yet migrated**: the `researched`-state adversarial verification gate
(H4) — the `#### State: researched` handler in the `-hard` engine and its `adversarial_verified`
state variable, set at three separate sites and driving a verify-then-re-dispatch loop before
planning — has NOT been ported into this engine's `researched` handler below. This is a
deliberate, recorded scope decision, not an oversight: it is a structurally independent residue
(its own state variable, its own re-dispatch loop, a different handler than the four behaviors
this engine does reproduce) and remains the one still-unmigrated piece of hard-mode
state-machine logic. A future removal of the `-hard` engine must account for this gate
separately; its absence here is not evidence it was folded in elsewhere in this file.

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
# 4th argument is the effort flag ("fast"/"hard"/""). Only "hard" currently changes resolution
# behavior in manifest-routing-lib.sh's routing_agents_hard block, so passing $effort_flag here
# is a no-op for "fast"/"" today — future-proofing the call sites rather than a live behavior
# change for --fast.
source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-agent" "$effort_flag"
RESEARCH_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "plan" "$TASK_TYPE" "planner-agent" "$effort_flag"
PLANNER_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "implement" "$TASK_TYPE" "general-implementation-agent" "$effort_flag"
IMPLEMENT_AGENT="$AGENT_NAME"
echo "[orchestrate] Task type: $TASK_TYPE → research=$RESEARCH_AGENT, plan=$PLANNER_AGENT, implement=$IMPLEMENT_AGENT"
```

### Stage 2: Loop Guard Initialization

Create or read the loop guard file. This tracks cycle count across conversational turns.

**Ephemeral, never committed.** `.orchestrator-loop-guard` is per-cycle runtime state with no
freshness check on read (see the resume branch below: any syntactically valid guard file at this
path is trusted, with no `session_id` or mtime comparison against the current dispatch). A
git-restored copy of a stale guard would silently resume a wrong `cycle_count`/`infra_failures`
pair — exactly the hazard this file's gitignore coverage exists to prevent. The same is true, in
hard mode only, of `.orchestrator-churn-state.json` (H5/H6 per-target churn counters): a second
ephemeral, gitignored, never-committed runtime file with the identical no-freshness-check-on-read
trust model, created and read only inside `$hard_mode` branches below. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

```bash
# Cycle budget is mode-aware: hard mode's per-phase dispatch (H1) needs roughly one cycle per
# phase, so a 7-phase plan needs ~7 cycles minimum — the same rationale
# skill-orchestrate-hard/SKILL.md's Stage 2 carried for its own fixed MAX_CYCLES=13. Base mode's
# whole-plan-per-dispatch handler keeps its original budget.
if [ "$hard_mode" = "true" ]; then
  MAX_CYCLES=13
else
  MAX_CYCLES=5
fi
# Single shared implementation, orchestrate-loop-guard-init.sh — see that script's header for
# the full contract (MAX_INFRA_FAILURES constant, loop_guard_file/handoff_file assignment,
# mkdir -p "$TASK_DIR", and the blocker-escalation counter pair applied further below in this
# same fence). This is the same call skill-orchestrate-hard/SKILL.md's Stage 2 makes for its own
# genuinely-common portion — everything else in this stage (the hard-only loop-guard-staleness
# detector, churn-state init) stays per-engine, either because it differs or because it sits
# inside the locked budget-continuation-override region below, which this script and its call
# site never touch.
loop_guard_init_json=$(bash .claude/scripts/orchestrate-loop-guard-init.sh "$TASK_DIR" "${HANDOFF_PATH_ABS}")
loop_guard_file=$(echo "$loop_guard_init_json" | jq -r '.loop_guard_file')
handoff_file=$(echo "$loop_guard_init_json" | jq -r '.handoff_file')
MAX_INFRA_FAILURES=$(echo "$loop_guard_init_json" | jq -r '.max_infra_failures')
# Hard-mode-only per-target churn-state file (H5/H6). Assigned unconditionally so the variable is
# always in scope, but only ever created/read inside `$hard_mode` branches below (churn-state
# init, further down this stage, and Stage 5b's H6 detector).
if [ "${hard_mode:-false}" = "true" ]; then
  churn_file="${TASK_DIR}/.orchestrator-churn-state.json"
fi

# Live plan-lineage reference, written into the guard's `plan_version` field in BOTH modes (D3 —
# one loop-guard JSON schema, not a per-mode fork). Computing it is a single cheap
# `ls | sort -V | tail -1` even in base mode, and the hard-only `loop-guard-staleness` detector
# (below) reads it as its Signal 2. Safe when plans/ does not exist yet (task in
# researching/planning status): the ls glob then matches nothing, `sort -V | tail -1` on empty
# input yields an empty string, and `basename ""` also yields an empty string here, so the
# explicit `:-none` fallback is required — absent plans/ is never itself evidence of staleness.
current_plan_version=$(basename "$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
current_plan_version="${current_plan_version:-none}"

# --- loop-guard-staleness:begin ---
# Hard-mode-only operational-staleness detector: a genuinely-present, never-git-touched guard
# that is simply superseded or old on disk (distinct from the git-restoration hazard the
# ephemeral/gitignored classification protects against). Three OR-combined signals; any one
# tripping is sufficient. See context/standards/orchestrator-runtime-files.md's "Operational
# staleness: a second, orthogonal freshness axis" for the full policy, thresholds, and the
# anti-session_id defense. D4: this detector stays strictly `$hard_mode`-gated — whether base
# mode should gain it unconditionally is a separate, undecided question (see the Asymmetry
# decision note at the end of this stage). No task-lock.sh dependency in this region -- it only
# reads, decides, and archives (mv), so it is directly executable in a fixture harness. The
# pre-existing `budget-continuation-override` region and the resume/churn-state blocks that
# follow are left completely unmodified: once a stale guard/churn file is mv'd aside, `[ -f ]` is
# false and each falls through to its own existing fresh-init branch naturally, at
# cycle_count=0 / total_churn=0.
if [ "${hard_mode:-false}" = "true" ]; then
  loop_guard_stale=false
  if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
    stale_reason=""

    # Signal 1: schema/version drift.
    guard_max_cycles=$(jq -r '.max_cycles // empty' "$loop_guard_file")
    if [ -n "$guard_max_cycles" ] && [ "$guard_max_cycles" != "$MAX_CYCLES" ]; then
      stale_reason="${stale_reason}max_cycles drift (guard=${guard_max_cycles}, live=${MAX_CYCLES}); "
    fi

    # Signal 2: plan-lineage drift. Skipped entirely when either side is empty or "none" -- a
    # missing plan_version (old-format guard) or an absent plans/ directory is never itself
    # evidence of staleness.
    guard_plan_version=$(jq -r '.plan_version // "none"' "$loop_guard_file")
    if [ -n "$guard_plan_version" ] && [ "$guard_plan_version" != "none" ] \
       && [ -n "$current_plan_version" ] && [ "$current_plan_version" != "none" ] \
       && [ "$guard_plan_version" != "$current_plan_version" ]; then
      stale_reason="${stale_reason}plan_version drift (guard=${guard_plan_version}, live=${current_plan_version}); "
    fi

    # Signal 3: mtime-age backstop. An mtime of 0 (stat failed on both GNU and BSD forms) is
    # treated as NOT stale -- an unreadable timestamp is not evidence.
    guard_mtime=$(stat -c %Y "$loop_guard_file" 2>/dev/null || stat -f %m "$loop_guard_file" 2>/dev/null || echo 0)
    stale_days="${ORCHESTRATOR_LOOP_GUARD_STALE_DAYS:-7}"
    if [ "$guard_mtime" -gt 0 ]; then
      now_ts=$(date -u +%s)
      age_seconds=$((now_ts - guard_mtime))
      stale_threshold_seconds=$((stale_days * 86400))
      if [ "$age_seconds" -gt "$stale_threshold_seconds" ]; then
        stale_reason="${stale_reason}mtime age (${age_seconds}s since last update, threshold ${stale_threshold_seconds}s / ${stale_days} days); "
      fi
    fi

    if [ -n "$stale_reason" ]; then
      loop_guard_stale=true
      stale_ts=$(date -u +%s)
      stale_guard_dest="${TASK_DIR}/.stale-loop-guard-${stale_ts}.json"
      echo "[orchestrate] ERROR: STALE LOOP GUARD — ${stale_reason}Archived to ${stale_guard_dest} for inspection; reinitializing fresh guard at cycle 0." >&2
      if mv "$loop_guard_file" "$stale_guard_dest" 2>/dev/null; then
        :
      else
        echo "[orchestrate] WARNING: could not move stale guard aside to ${stale_guard_dest}; ${loop_guard_file} is still in place and must be removed manually before the next cycle." >&2
      fi
      # Co-archive the churn-state file under the loop guard's inherited verdict (not an
      # independently-derived detector) and the same timestamp suffix, so the two archives are
      # correlatable. Only when it exists -- never create an empty churn archive.
      if [ -f "$churn_file" ]; then
        stale_churn_dest="${TASK_DIR}/.stale-churn-state-${stale_ts}.json"
        echo "[orchestrate] Co-archiving churn state to ${stale_churn_dest} (inherits the loop guard's stale verdict)." >&2
        if mv "$churn_file" "$stale_churn_dest" 2>/dev/null; then
          :
        else
          echo "[orchestrate] WARNING: could not move stale churn state aside to ${stale_churn_dest}; ${churn_file} is still in place and must be removed manually before the next cycle." >&2
        fi
      fi
    fi
  fi
fi
# --- loop-guard-staleness:end ---

# --- budget-continuation-override:begin ---
# Defect B: cycle_count is a per-task, CUMULATIVE budget that survives re-invocation BY DESIGN --
# it is deliberately NOT reset on a new session_id, because that would let an operator silently
# bypass MAX_CYCLES by simply re-invoking /orchestrate. test-session-runtime-files.sh Case 3 is
# the regression protecting this decision; this override must never disturb it. The override
# below is the sanctioned, explicit, loudly-logged escape hatch for a genuinely exhausted budget
# -- never automatic, never session_id-gated, never inferred from mtime. Runs immediately after
# the `$hard_mode`-gated `loop-guard-staleness` region above (which only ever archives a stale
# guard aside and falls through) and before the pre-existing resume-read block below.
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
  # burnout_signals_this_session: hard-mode-only counter (D3 — written in BOTH modes via the
  # unified loop-guard schema below, so this read is unconditional and forward-compatible; base
  # mode simply never increments or reports it). `// 0` matches the other counters' idiom.
  burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
  # Observational-only session_id tracking (NEVER a gate — see Ephemeral note above and
  # context/standards/status-markers.md's rationale: SESSION_ID is regenerated per /orchestrate
  # invocation, while this guard is explicitly designed to survive across conversational turns.
  # The real same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not
  # session_id equality). A mismatch is logged, never branched on.
  guard_session_id=$(jq -r '.session_id // ""' "$loop_guard_file")
  if [ -n "$guard_session_id" ] && [ "$guard_session_id" != "$session_id" ]; then
    echo "[orchestrate] INFO: loop guard was last written by a different session_id ('${guard_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
  fi
  # Hard-mode-only burnout reporting, fully self-closed BEFORE the unconditional echo below so
  # the always-present resume-read `if [ -f "$loop_guard_file" ]` above this block stays the
  # ONLY still-open conditional at the point of that echo (test-loop-guard-budget-override.sh
  # extracts from the budget-continuation-override sentinel through that exact echo text and
  # appends one synthetic `fi`; a conditional wrapped around the echo itself would leave two
  # unclosed `if`s there and break the extraction's bash -n check).
  if [ "${hard_mode:-false}" = "true" ]; then
    echo "[orchestrate] Resuming (hard mode) — burnout signals so far: $burnout_signals_this_session"
  fi
  echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker. A plain
  # `>` redirect has no O_EXCL semantics, so two racing writers could both take
  # this branch and stomp each other's counters; init-marker's mkdir-gate +
  # tmp-mv payload guarantees exactly one winner. On a lost race (exit 1),
  # degrade to the same resume-read the `if`-branch above performs.
  # hard_mode_json: JSON-boolean form of the existing $hard_mode string ("true"/"false" is
  # already valid JSON, so this is a direct --argjson pass-through, not a re-derivation).
  hard_mode_json="$hard_mode"
  if jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --argjson max_infra_failures "$MAX_INFRA_FAILURES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson hard_mode_json "$hard_mode_json" \
    --arg plan_version "$current_plan_version" \
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
      "dispatch_seq_counter": 0,
      "hard_mode": $hard_mode_json,
      "burnout_signals_this_session": 0,
      "plan_version": $plan_version
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    infra_failures=0
    detected_defects='[]'
    dispatch_seq_counter=0
    burnout_signals_this_session=0
    echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES, MAX_INFRA_FAILURES=$MAX_INFRA_FAILURES"
  else
    # Lost the creation race: another writer won. Resume from their guard, reading BOTH
    # counters — not just cycle_count — and the system-defect observation log alongside them.
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
    dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
    burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
    if [ "$hard_mode" = "true" ]; then
      echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
    else
      echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
    fi
  fi
fi

# mint_dispatch_seq(): named-shim to the single shared implementation,
# skill_orchestrate_mint_dispatch_seq (scripts/skill-base.sh) — see that function's header for the
# full contract. Kept as a locally-named function (not called directly by name) because Stage 4/5
# call sites below still say `mint_dispatch_seq`, and this file pair is where a one-sided rename
# is a known recurring defect class. Source is defensive/idempotent: this Stage 2 fence has no
# earlier explicit source line of its own to depend on.
source .claude/scripts/skill-base.sh
mint_dispatch_seq() {
  skill_orchestrate_mint_dispatch_seq "$loop_guard_file"
}

# Hard-mode-only churn-state init/resume (H5/H6): per-target churn counters and audit-dispatch
# bookkeeping, read by Stage 5b's churn-detection/three-strikes logic. Gated identically to the
# `churn_file` assignment and the `loop-guard-staleness` region above.
if [ "${hard_mode:-false}" = "true" ]; then
  if [ -f "$churn_file" ] && jq empty "$churn_file" 2>/dev/null; then
    total_churn=$(jq -r '.total_churn // 0' "$churn_file")
    # Observational-only session_id tracking (NEVER a gate — identical rationale to the loop
    # guard's own treatment above: SESSION_ID is regenerated per /orchestrate invocation, while
    # this file is explicitly designed to survive across conversational turns. The real
    # same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not
    # session_id equality).
    churn_session_id=$(jq -r '.session_id // ""' "$churn_file")
    if [ -n "$churn_session_id" ] && [ "$churn_session_id" != "$session_id" ]; then
      echo "[orchestrate] INFO: churn state was last written by a different session_id ('${churn_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
    fi
  else
    # Fresh start: create churn state atomically via init-marker; on a lost race (exit 1),
    # resume-read total_churn (matching the `if`-branch above).
    if jq -n --arg session_id "$session_id" \
      '{"session_id": $session_id, "total_churn": 0, "target_churn": {}, "adversarial_triggers": 0, "audit_dispatches": 0}' \
      | bash .claude/scripts/task-lock.sh init-marker "$churn_file"; then
      total_churn=0
    else
      total_churn=$(jq -r '.total_churn // 0' "$churn_file")
    fi
  fi
fi

# Blocker escalation counter (reset each /orchestrate invocation) — from the same shared
# orchestrate-loop-guard-init.sh call above.
blocker_escalation_count=$(echo "$loop_guard_init_json" | jq -r '.blocker_escalation_count')
MAX_BLOCKER_ESCALATIONS=$(echo "$loop_guard_init_json" | jq -r '.max_blocker_escalations')

# Drift detection constants (reset each /orchestrate invocation) — base-mode-only; hard mode has
# no Stage 5a Drift Inspection equivalent (its own Stage 5b H5 divergence-audit mechanism plays
# that role instead — see the mutual-exclusion decision record at Stage 5a/5b below), so these
# stay out of the shared script AND, now that both modes share this one file, out of scope when
# `hard_mode` is true. Only ever read/incremented from inside Stage 5a's own base-mode-gated
# call site, so leaving them unset in hard mode is safe.
if [ "${hard_mode:-false}" != "true" ]; then
  drift_inspection_count=0
  MAX_DRIFT_INSPECTIONS=1
  DRIFT_COMPLETION_THRESHOLD=0.70
  DRIFT_REVISION_THRESHOLD=0.30
fi
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

**Asymmetry decision (recorded, "recorded not acted on" style)**: the 3-signal
`loop-guard-staleness` detector now exists in this engine, behind the `$hard_mode` gate (D4) —
it is no longer absent from this file the way the note below once described. Whether base mode
(`$hard_mode = false`) should gain the detector UNCONDITIONALLY is a SEPARATE, undecided
question, left open by this migration: the detector's presence here is scoped to hard mode only,
and extending it to base mode would be a distinct, future decision requiring its own rationale —
not something this task settles by porting the hard-only region.

### Stage 2b: Forced-Phase Queue Initialization

Runs once, after Stage 2 (Loop Guard Initialization) and before Stage 3's loop opens. This is the
functional target for what this stage's originating task description called "Stage 1b/2" —
`Stage 1b` (above) is agent routing, not phase selection; this stage is where `force_phases` (A2)
actually resolves into a queue the state machine loop consumes.

**Build the ordered queue.** Split the `force_phases` string (Stage 1, default `""`) on commas
into an ordered bash array, validating each entry against the closed set `{research, plan,
implement}` and failing loudly on anything else — `force_phases` is minted only by
`parse-command-args.sh`'s own canonical-lifecycle-order accumulation (see this stage's
originating plan's Phase 1), so an invalid entry here means a corrupted delegation context, not a
user typo, and deserves a loud failure rather than a silent skip.

```bash
force_queue=()
if [ -n "${force_phases:-}" ]; then
  IFS=',' read -ra _force_phases_split <<< "$force_phases"
  for _fp in "${_force_phases_split[@]}"; do
    case "$_fp" in
      research|plan|implement)
        force_queue+=("$_fp")
        ;;
      *)
        echo "[orchestrate] ERROR: force_phases contains an invalid entry '${_fp}' (expected one of: research, plan, implement). This should be unreachable from parse-command-args.sh's own accumulation — treating as a corrupted delegation context." >&2
        exit 1
        ;;
    esac
  done
fi
```

**Phase-to-handler map (prose, referenced by heading — never inlined).** A popped `force_queue`
entry dispatches the SAME Stage 4 handler body the status-derived path would use for the
equivalent status, by pointer:

| Forced phase | Stage 4 handler (by heading) |
|---|---|
| `research` | State: not_started or not started |
| `plan` | State: researched |
| `implement` | State: planned or implementing |

Referencing one of these handlers is a pointer, not an edit — it does not collide with the
sibling task that owns these handler bodies (see this stage's originating plan's Cross-task
composition table).

**`resolve_cycle_artifact_number()`.** Named function, defined once here, called from Stage 3's
3c on every cycle that dispatches a phase (forced or status-derived). Wraps
`skill_read_artifact_number` — itself entirely UNCHANGED by this stage — choosing `mode` and
`artifact_dir` from the phase about to run: `mode="current"`/`artifact_dir="reports/"` for a
research cycle, `mode="prev"` with the matching directory for a plan or implement cycle (planner
and implementer share the round research opened, per `skill_read_artifact_number`'s own existing
`"prev"` semantics).

```bash
resolve_cycle_artifact_number() {
  local phase="$1"  # "research" | "plan" | "implement"
  local mode artifact_dir
  case "$phase" in
    research)
      mode="current"
      artifact_dir="reports/"
      ;;
    plan)
      mode="prev"
      artifact_dir="plans/"
      ;;
    implement)
      mode="prev"
      artifact_dir="summaries/"
      ;;
  esac
  skill_read_artifact_number "$task_number" "$PADDED_NUM" "$PROJECT_NAME" "$artifact_dir" "$mode"
  # Exports ARTIFACT_NUMBER / ARTIFACT_PADDED — consumed by Stage 4's preamble sentence below,
  # which every handler's `context` object then additionally carries as
  # `artifact_number: $ARTIFACT_NUMBER`.
}
```

**Observability write (never authoritative, never gates admission).** Record the still-pending
forced phases in the loop guard, in the same jq-write style Stage 3's 3b already uses against
`loop_guard_file`:

```bash
force_phases_remaining=$(IFS=,; echo "${force_queue[*]:-}")
jq --arg remaining "$force_phases_remaining" \
  '.force_phases_remaining = $remaining' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

**Empty-queue invariant.** When `force_queue` is empty (the overwhelmingly common case — no
forcing flag was passed), this stage is a no-op: `force_invoked` is `false` on every cycle, and
every downstream path (Stage 3's 3c, Stage 4's dispatch, Stage 5's postflight tail) behaves
byte-for-byte as it did before this stage existed.

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
#
# This is the CYCLE-layer heartbeat, complementary to (and now backstopped by) the mechanized
# PHASE-layer refresh inside update-phase-status.sh itself: it remains necessary here because a
# research or plan cycle has no phase transitions of its own to hook, so this per-cycle site is
# the only refresh those cycles get. It is not redundant with the mechanized site during an
# implement cycle either — this fires once per whole cycle, the mechanized site fires once per
# phase transition within that cycle.
bash .claude/scripts/task-lock.sh heartbeat "$task_number" "$session_id" 2>/dev/null || true

# In-flight session registry heartbeat: same per-cycle boundary, refreshing the entry
# command-gate-in.sh registered at CHECKPOINT 1. Best-effort and non-blocking. See
# .claude/context/patterns/task-lock.md's Session-Registry CLI section.
bash .claude/scripts/task-lock.sh session-heartbeat "$session_id" 2>/dev/null || true
```

**3b-hard. Burnout circuit-breaker gate (hard mode only)**

**MANDATORY when `$hard_mode` is true — runs EVERY loop iteration**, after `current_status` is
known (3a) and the loop guard is persisted (3b), strictly before any Stage 4 dispatch decision.
Skipped entirely when `hard_mode` is false. This is not an optional guideline; it is a gate. Per
`.claude/context/contracts/orchestrator-discipline.md`, check all three self-checks before
proceeding to Stage 4:

1. **If you are about to Read a path you have already read this session without an
   intervening `Agent` dispatch having produced new information, STOP and dispatch
   `$RESEARCH_AGENT` instead** (focus_prompt = a literal restatement of the exact unresolved
   question) — do not complete the re-read.
2. **If this is the second or later consecutive orchestrator turn reasoning about task content
   with no `Agent` tool call in between, STOP reasoning immediately and take response (a) or
   (b) from the contract now** — do not produce a third such turn.
3. **If you are about to reverse a phase, target, or escalation decision without a fresh
   dispatch having just produced the new finding that justifies it, STOP and either dispatch
   `$RESEARCH_AGENT` to obtain that finding (reasoning-about-what-a-phase-should-do) or jump
   directly to Stage 6 (deciding-whether-to-keep-escalating) — never reverse on inline
   reasoning alone.**

No new artifact type is introduced. The forced dispatch reuses Stage 5b's divergence-audit
dispatch shape, triggered by a burnout signal instead of a churn-count threshold; the forced
escalation reuses Stage 6 directly.

**On any signal firing**, increment the scalar counter in the same 3b-style jq write that
already touches `loop_guard_file`:

```bash
if [ "${hard_mode:-false}" = "true" ]; then
  burnout_signals_this_session=$((burnout_signals_this_session + 1))
  jq --argjson count "$burnout_signals_this_session" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.burnout_signals_this_session = $count | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "[orchestrate] H-orch: burnout signal detected (session total: $burnout_signals_this_session) — forcing dispatch/escalation, not inline reasoning" >&2
fi
```

**3c. Dispatch by state.** A three-way, STRICTLY ORDERED decision, replacing the former plain
"dispatch by state" pointer. Order matters and is stated here as a requirement, not left
implicit — a forced phase NEVER overrides a terminal state, and `force_queue` (Stage 2b's
per-cycle parse of `force_phases`) takes priority over status-derived dispatch whenever it is
non-empty. One unified decision (shown as a
single flowing `if`/`elif`/`else` below, not three independently-fenced fragments, so the
control flow stays syntactically whole):

1. **Terminal check, first.** If `current_status` is `completed`, `abandoned`, or `expanded`, run
   the existing terminal-state handler UNCHANGED (see State: `completed` / States: `abandoned`,
   `expanded` in Stage 4) — a forced phase never overrides a terminal state. If `force_queue` is
   non-empty when this branch is taken, emit a loud named refusal FIRST, citing
   `rules/state-management.md`'s "Cannot transition from terminal states".
2. **Else if `force_queue` is non-empty**: pop its head into `forced_phase`, set
   `force_invoked=true` for this cycle, resolve the artifact round via
   `resolve_cycle_artifact_number "$forced_phase"` (Stage 2b), and execute the Stage 4 handler
   Stage 2b's phase-to-handler map names for `forced_phase` — by pointer, exactly as written
   there, never inlined.
3. **Else**: set `force_invoked=false`, derive `cycle_phase` from `current_status` (the same
   research/plan/implement grouping the Stage 4 handler headings already use — `not_started`/
   `not started`/`researching` → `research`; `researched`/`planning` → `plan`; `planned`/
   `implementing`/`partial` → `implement`; every other status, including `blocked` and unknown
   states, dispatches no agent and resolves no artifact number), call
   `resolve_cycle_artifact_number "$cycle_phase"` only when `cycle_phase` is non-empty, and
   dispatch by state exactly as today.

```bash
if [[ "$current_status" == "completed" || "$current_status" == "abandoned" || "$current_status" == "expanded" ]]; then
  if [ "${#force_queue[@]}" -gt 0 ]; then
    echo "[orchestrate] REFUSED: task $task_number is in terminal state [$current_status] — forced phase(s) '${force_queue[*]}' cannot run. Cannot transition from terminal states (rules/state-management.md). Running the existing terminal-state handler below unchanged; no forced dispatch occurs this cycle." >&2
  fi
  force_invoked=false
  # Fall through to the existing terminal-state handler for $current_status, unchanged
  # (see State: `completed` / States: `abandoned`, `expanded` in Stage 4).
elif [ "${#force_queue[@]}" -gt 0 ]; then
  forced_phase="${force_queue[0]}"
  force_queue=("${force_queue[@]:1}")
  force_invoked=true
  resolve_cycle_artifact_number "$forced_phase"
  # Dispatch the Stage 2b-mapped Stage 4 handler for $forced_phase, by pointer.
else
  force_invoked=false
  cycle_phase=""
  case "$current_status" in
    not_started|"not started"|researching) cycle_phase="research" ;;
    researched|planning) cycle_phase="plan" ;;
    planned|implementing|partial) cycle_phase="implement" ;;
  esac
  if [ -n "$cycle_phase" ]; then
    resolve_cycle_artifact_number "$cycle_phase"
  fi
  # Dispatch by state exactly as today (see State Handlers in Stage 4).
fi
```

**Forced-sequence-exhausted terminal condition.** After the cycle whose popped `forced_phase` left
`force_queue` empty completes its Stage 5 postflight, the loop STOPS — it does NOT fall through to
status-derived dispatch. This is checked and applied at Stage 7 (Loop Guard Update), routed
through the same `EXIT (...)` reporting idiom the existing MAX_CYCLES/MAX_INFRA_FAILURES terminal
conditions use, so the run's own summary names it.

---

### Stage 3.5: Dispatch Prep (shared, runs immediately before every Agent dispatch)

This is the SINGLE canonical copy of the memory-retrieval and literature-briefing procedure for
`/orchestrate`. Every dispatch site in Stage 4 (single-task) and Stage MT-4 (multi-task)
references this stage with a short pointer line rather than inlining a second copy — see the
"Shared-snippet convention" mitigation in this task's plan. **Never duplicate this procedure at a
dispatch site.**

**Inputs**:

| Input | Source |
|-------|--------|
| `phase` | `research` \| `plan` \| `implement` — passed by the calling dispatch site |
| `description` | task description (see case-alias below) |
| `task_type` | `TASK_TYPE` (single-task) / per-task `task_type` (multi-task) |
| `focus_prompt` | `focus_prompt` from the delegation context |
| `clean_flag` | Stage 1 / Stage MT-1 (this invocation's `--clean` state) |
| `effort_flag` | Stage 1 / Stage MT-1 (this invocation's `--fast` state) |
| `model_flag` | Stage 1 / Stage MT-1 (this invocation's `--haiku`/`--sonnet`/`--opus`/`--fable` state) |
| `lit_flag` | Stage 1 / Stage MT-1 |
| `orchestrator_mode` | always `true` for every `/orchestrate` dispatch |
| `hard_mode` | Stage 1 / Stage MT-1 (derived from `effort_flag == "hard"`) |
| `territory` | optional; set by the hard-mode `planned`/`implementing` handler's H1 branch (Stage 4) before invoking this stage for `phase=implement`, so `territory.md` is appended by (a) above. No other call site sets it — base mode (`hard_mode = false`) does not gain a `territory` dispatch key (see Stage MT-3's existing "Decision record" for that rationale, which is unaffected by this hard-mode caller) |

**Case alias (do not "simplify" away)**: single-task Stage 1 extracts the task description into
the uppercase `DESCRIPTION` shell variable (from `state.json` via `jq`), while the shared lit flow
(`lit-stage4a-flow.md`) and `memory-retrieve.sh` both expect the lowercase `description`. Multi-
task mode already reads the per-task value into lowercase `description` (Stage MT-4, per Phase 3
of this task's plan). This alias reconciles both call shapes in one line:

```bash
description="${DESCRIPTION:-${description:-}}"
```

**Empty-description warning (loud, non-blocking)**: both `memory-retrieve.sh` and
`lit-stage4a-flow.md` hard-require a non-empty `description` to do anything useful. An empty value
here most often means the multi-task `descriptions` capture (Phase 3) regressed — surface it
immediately rather than silently no-op-ing:

```bash
if [ -z "$description" ]; then
  echo "[orchestrate] WARNING: empty description at dispatch prep (phase=$phase) — memory retrieval and literature briefing will be skipped" >&2
fi
```

**Memory retrieval (Auto), skipped when `clean_flag` is true**: reproduces
`skill-researcher`/`skill-planner`/`skill-implementer`'s own Stage 4a verbatim, except the 3rd
`memory-retrieve.sh` argument is selected by `phase`, preserving the existing per-phase asymmetry:

| `phase` | 3rd `memory-retrieve.sh` argument |
|---------|-----------------------------------|
| `research` | `"$focus_prompt"` |
| `plan` | `""` |
| `implement` | `""` |

```bash
if [ "$clean_flag" != "true" ]; then
  memory_arg3=""
  [ "$phase" = "research" ] && memory_arg3="$focus_prompt"
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$memory_arg3" 2>/dev/null) || memory_context=""
fi
```

`memory-retrieve.sh` emits its own `<memory-context>` wrapper around its output (verified against
the script's own tail) — do NOT re-wrap `memory_context` here. The script exits 1 with empty
stdout when `clean_flag` is true (skipped), `memory-index.json` is missing/empty, no keywords
matched, or it otherwise errored; in every one of those cases `memory_context` is simply empty and
nothing is injected.

**Literature detection and injection (shared block)**: follow `@.claude/context/patterns/lit-stage4a-flow.md`
in full to resolve `--lit` and set `lit_context`: call `literature-lit-flag-resolve.sh`, branch on
all six directives (`LIT_DISABLED`, `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, `PROMPT_NEEDED`,
`AUTONOMOUS_GLOBAL`, `SPARSE_PROMPT_NEEDED`). Because `skill-orchestrate` always sets
`orchestrator_mode: true`, the two interactive directives that would otherwise issue
`AskUserQuestion` are unreachable here — the deterministic `[lit:auto]` autonomous fallback always
applies instead. This stage supplies the shared flow's three preconditions: `lit_flag`,
`description`, and `orchestrator_mode`.

**Independence note**: `lit_flag` is independent of `clean_flag`. `--clean --lit` suppresses
memory retrieval but still injects literature briefing; literature briefing is gated solely on
`lit_flag == "true"`.

**Effort-depth note**: when `effort_flag` is non-empty, set a one-line `effort_note` to be
appended to the dispatch prompt as reasoning-depth guidance, mirroring `commands/research.md`'s
existing "pass it as prompt context to the skill/agent for reasoning depth guidance" instruction.
An empty `effort_flag` produces no note (`effort_note` stays empty).

**Model-override resolution**: when `model_flag` is non-empty, set the `model` output to it
unchanged (`haiku`/`sonnet`/`opus`/`fable` pass through verbatim — this stage does not translate
or validate the value). When `model_flag` is empty, `model` stays empty and no `model` parameter
is emitted at any call site, so the agent's frontmatter default applies. The emptiness test is on
the **empty string**, never on the literal `null`. Only dispatch sites that call this stage
receive the override: the six auxiliary/diagnostic dispatches (Stage 5a Drift Inspection, Stage
5b churn/divergence audit, Stage 6 Blocker Escalation) do not call Stage 3.5 and therefore keep
their frontmatter defaults, by design and with no exemption list to write or maintain.

**Hard-mode contract injection (gated on `hard_mode == "true"`)**: when `hard_mode` is `"false"`
(the default path), `hard_contracts_block` stays empty and this whole subsection is skipped — no
`<hard-mode-contracts>` tag pair is ever emitted. When `hard_mode` is `"true"`:

(a) Start from a fixed, ordered `core_contracts` array selected by `$phase` — the exact three
lists from this task's plan Decision 2, with `territory.md` appended only when the `territory`
input is non-empty (per Decision 3, no call site sets it today, so this branch never fires in
practice):

```bash
case "$phase" in
  research) core_contracts=(anti-analysis.md reference-grounding.md adversarial-verification.md) ;;
  plan)     core_contracts=(reference-grounding.md wrap-up.md anti-analysis.md) ;;
  implement)
    core_contracts=(anti-analysis.md wrap-up.md)
    [ -n "$territory" ] && core_contracts+=(territory.md)
    core_contracts+=(recovery.md phase-closure.md pre-edit-gate.md)
    ;;
esac
```

(b) Resolve extension-declared entries via `routing_lookup_flat` (never `routing_lookup` — see
Decision 5 and `manifest-routing-lib.sh`'s own doc comment for why these are siblings, not a
wrapper). On a hit, apply every `replace:{core-basename}:{override-path}` entry as an in-place
substitution of the matching `core_contracts` element (matched by exact basename), then append
every remaining non-`replace:` entry additively, in the order the manifest lists them. On a miss,
`core_contracts` stands unchanged:

```bash
source .claude/scripts/lib/manifest-routing-lib.sh
routing_lookup_flat "hard_contracts" "$task_type"
if [ -n "$_ROUTE_LAST_VALUE" ]; then
  while IFS= read -r entry; do
    case "$entry" in
      replace:*)
        core_basename="${entry#replace:}"; core_basename="${core_basename%%:*}"
        override_path="${entry#replace:*:}"
        for i in "${!core_contracts[@]}"; do
          [ "${core_contracts[$i]}" = "$core_basename" ] && core_contracts[$i]="$override_path"
        done
        ;;
      *)
        core_contracts+=("$entry")
        ;;
    esac
  done < <(echo "$_ROUTE_LAST_VALUE" | jq -r '.[]')
fi
```

(c) Build `hard_contracts_block` as a `<hard-mode-contracts>` tag wrapping one
`- context/contracts/{file}` line per resolved `core_contracts` entry, in resolved order:

```bash
hard_contracts_block="<hard-mode-contracts>"$'\n'
for c in "${core_contracts[@]}"; do
  hard_contracts_block+="- context/contracts/${c}"$'\n'
done
hard_contracts_block+="</hard-mode-contracts>"
```

**Outputs and injection contract**: this stage produces `memory_context`, `lit_context`,
`effort_note`, and `hard_contracts_block`. The calling dispatch site appends them, in that
order, to the END of its own prompt string — `memory_context` first, then `lit_context`, then
`effort_note`, then `hard_contracts_block` — skipping any of the four that is empty. Never
inject an empty `<memory-context>`, `<literature-briefing>`, or `<hard-mode-contracts>` tag pair.
None of the four outputs is ever added to the dispatch's `context` JSON object.
This stage also produces a fifth output, `model`, of a different kind than the four above: it is
passed as the Agent tool's `model` parameter at each call site, exactly like `subagent_type`, and
is **never** appended to the prompt string and **never** added to the dispatch's `context` JSON
object.
Unlike the three lifecycle skills, `skill-orchestrate` injects no format specification
(`report-format.md`/`plan-format.md`) into its dispatch prompts today (a real, separate,
pre-existing gap — see Non-Goals in this task's plan) — so these blocks are simply the first
content appended after the dispatch site's own base prompt text, with no format block for them
to follow.

---

### Stage 3.6: Team Fan-Out (shared, invoked from every dispatch site when team_mode is true)

This is the SINGLE canonical copy of the team-mode fan-out procedure for `/orchestrate`. Every
dispatch site in Stage 4 that forks on `team_mode` references this stage with a short pointer
line rather than inlining a second copy — the same single-canonical-copy discipline Stage 3.5
states about itself immediately above. **Never duplicate this body at a dispatch site.**

**Inputs**:

| Input | Source |
|-------|--------|
| `phase` | `research` \| `plan` \| `implement` — passed by the calling dispatch site |
| `description` | task description (see Stage 3.5's case-alias) |
| `task_type` | `TASK_TYPE` |
| `focus_prompt` | `focus_prompt` from the delegation context |
| `clean_flag` | Stage 1 (this invocation's `--clean` state) |
| `effort_flag` | Stage 1 (this invocation's `--fast`/`--hard` state) |
| `lit_flag` | Stage 1 |
| `hard_mode` | Stage 1 (derived from `effort_flag == "hard"`) |
| `team_size_eff` | Stage 1's `team_size_eff` derivation |
| `artifact_number` | resolved the same way each per-phase single-dispatch site already resolves it (`next_artifact_number` from `specs/state.json`); unused by the `implement` branch of Stage 3.6a below, which needs no artifact number of its own — recorded here rather than silently dropped |
| `plan_path` | implement only — resolved the same way the base branch's `planned`/`implementing` handler already resolves it |
| `session_id` | Stage 1 |
| `task_dir` | `TASK_DIR_ABS` |
| `handoff_path` | `HANDOFF_PATH_ABS` |

**Early availability check** (first executable step of this stage, before any builder call or
spawn):

```bash
if [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" != "1" ]; then
  echo "[orchestrate] WARNING: --team requested but CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is not set to \"1\" — falling back to single-agent dispatch for phase=$phase" >&2
  fanout_degraded=true
  return  # the calling dispatch site's own pre-existing single-agent `else` branch runs next
fi
fanout_degraded=false
```

`--team` is accepted, never rejected: an unset/non-`"1"` `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
degrades silently to `fanout_degraded=true`, and the calling dispatch site's own pre-existing
single-agent Agent dispatch (already documented at that site, unchanged) runs instead. This stage
MUST NOT re-invoke a whole lifecycle skill on the degraded path — doing so would double
preflight/postflight; the caller's own existing single dispatch is the entire fallback.

**Teammate-plan build**: call **Stage 3.6a: Teammate-Plan Builder** (below) with `phase` and the
inputs above to obtain `teammate_plan` — an ordered array of tuples:

```json
[{"label": "a", "prompt": "...", "subagent_type": "...", "output_path": "...", "delegation_extras": {}, "territory": {}}]
```

If Stage 3.6a itself returns an EMPTY `teammate_plan` (its own degraded-return case — e.g. the
`implement` branch under `hard_mode`, or a non-conforming plan-phase-heading refusal), set
`fanout_degraded=true` here too and return the same way, for the same reason: no teammate to
spawn means no fan-out, so the caller's single-dispatch `else` branch is again the correct path.

**Spawn loop**: for each tuple in `teammate_plan`, in the SAME orchestrator message (BATCHING
RULE — see Stage MT-4's identical rule for the same underlying reason: Claude Code processes all
Agent calls in one message concurrently; multiple messages force sequential execution):

1. Run **Stage 3.5: Dispatch Prep** with `phase` (unchanged) and `hard_mode`/`clean_flag`/
   `lit_flag` passed through exactly as received by this stage — this is what makes
   `--hard --team` inject hard contracts into every teammate's own prompt for free, with no
   separate wiring.
2. Mint a per-teammate `dispatch_seq` via `mint_dispatch_seq()` (the same function every other
   dispatch site in this file already calls).
3. Invoke the Agent tool:
   - `subagent_type`: the tuple's `subagent_type`
   - `model`: THIS teammate's own Stage 3.5 `model` output, passed as the Agent tool's `model`
     parameter when non-empty; omitted when empty
   - `prompt`: the tuple's `prompt`, with `memory_context`, then `lit_context`, then
     `effort_note`, then `hard_contracts_block` from THIS teammate's own Stage 3.5 call appended,
     in that order, skipping any that is empty — identical to every other dispatch site's own
     append contract
   - `context`: `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag,
     task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq,
     postflight_obligation: false }`, merged with the tuple's own `delegation_extras`
     (`teammate_letter`/`artifact_number` for research and plan; `plan_path`/`phase_number`/
     `roadmap_path` for implement — see Stage 3.6a)

**Wave wait**: after a wave's teammates are all launched in that one message, wait for every one
to return or for a 30-minute wave timeout, whichever comes first. On a timeout, record the
missing labels in `teammate_results` (status `"timeout"`) and continue with whatever DID return —
never fail the whole cycle over one slow or unresponsive teammate.

**Collection**: once the wave (or, for `implement`'s multi-wave case — see Stage 3.6a below, all
waves) return, read each RETURNED teammate's declared `output_path` from its own tuple. Record,
per label, one of `present` (file exists and is non-empty) or `missing`. A missing file is
recorded and reported, never treated as a reason to abort the stage.

**Session correlation (D3)** — authored as its own clearly delimited sub-block, because it is the
one piece of this stage that runs regardless of `phase` and regardless of whether the wave
succeeded:

- **Before the spawn loop above**: capture `marker_path="${TASK_DIR}/.postflight-pending"` and
  read its own `session_id` field (`jq -r '.session_id // empty' "$marker_path"`) before any
  teammate is dispatched. This pair — this session's marker path and its own `session_id` — is
  the correlation key referenced below.
- **Teammate non-obligation**: every teammate dispatch context in the spawn loop above carries
  `postflight_obligation: false`. Every teammate's own dispatch prompt MUST additionally state,
  in plain language, that the teammate MUST NOT create a `.postflight-pending` marker of its
  own — so no foreign marker can ever be the file `find_marker()` (in
  `hooks/subagent-postflight.sh`) picks first when it scans for one.
- **Marker re-assertion after the wave** (the actual mitigation): once every teammate in the wave
  has returned (or timed out), re-check `marker_path`:
  ```bash
  current_session=$(jq -r '.session_id // empty' "$marker_path" 2>/dev/null)
  if [ ! -f "$marker_path" ] || [ "$current_session" != "$session_id" ]; then
    echo "[orchestrate] WARNING: teammate stops consumed the continuation budget and removed this session's postflight marker; re-asserted (phase=$phase)" >&2
    skill_create_postflight_marker "$PADDED_NUM" "$PROJECT_NAME" "$session_id" "skill-orchestrate" "$phase"
    echo "0" > "${TASK_DIR}/.postflight-loop-guard"
  fi
  ```
  This converts what was previously a silent, trace-free deletion into an observable,
  self-healed event — the loud stderr line fires on EVERY re-assertion, never silently.
- **Correlation key, named explicitly**: the marker's own `session_id` field, compared against
  this session's `session_id`, is the correlation key. The complementary read-side predicate — the
  actual fix for `find_marker()` ever picking up a foreign marker in the first place — belongs in
  `hooks/subagent-postflight.sh`'s `find_marker()` function, referenced here by path and function
  name only. That file is outside this task's file scope; implementing the read-side predicate is
  a separate, dependent hook-side task's job.

**Staging**: teammate-written artifacts (finding files, candidate plans, phase edits) are staged
under the existing task-directory scope the SAME way every other `/orchestrate` dispatch's output
already is — via `git-commit-scoped.sh`, at the command's own CHECKPOINT 3. This stage performs
no `git commit` of its own, and never uses `git add -A`.

**Cleanup**: remove any per-wave scratch state this stage itself created (there is none by
default; a future addition that creates one must clean it up here). This stage explicitly does
NOT remove `.postflight-pending` or `.postflight-loop-guard` — termination-only cleanup of those
two files belongs solely to Stage 8, and removing them here would race a still-in-flight
orchestrator cycle.

**Outputs contract**: this stage produces exactly three outputs:

| Output | Shape | Consumed by the calling dispatch site as |
|--------|-------|-------------------------------------------|
| `fanout_degraded` | boolean | `true` -> caller runs its own pre-existing single-agent `else` branch unchanged; `false` -> caller uses the two outputs below instead of a single-agent result |
| `teammate_results` | map: label -> `{output_path, status: "present"\|"missing"\|"timeout"}` | caller links each present artifact into `state.json` the same way a single-agent dispatch links its own artifact, and reports each missing/timeout label in its own handoff/summary text |
| `synthesis_path` | string (path) or empty | research/plan: the unified artifact path from Stage 3.6a's synthesis step, used as THE artifact the caller links, in place of any one teammate's raw finding file; implement: always empty — implement's own collection step (Stage 3.6a) aggregates per-phase results directly, with no synthesis step |

---

### Stage 3.6a: Teammate-Plan Builder (per-phase)

```bash
case "$phase" in
  research) ... ;;
  plan)     ... ;;
  implement) ... ;;
esac
```

The three lifecycle phases do not share one teammate shape: `research` and `plan` use a small
FIXED set of named roles producing disjoint artifact files with no source-file territory, while
`implement` derives a DYNAMIC set of teammates from the plan's own phase/wave structure, each
owning real source files, with an ad-hoc debugger role that can be added outside the wave
headcount. This builder exists precisely so Stage 3.6 above can stay phase-agnostic: it calls this
builder once and consumes whatever `teammate_plan` array comes back, without needing to know
which phase produced it.

#### `research` branch

Fixed roles gated by `team_size_eff`:

| Letter | Role | Present from `team_size_eff` |
|--------|------|-------------------------------|
| a | Primary | 2 |
| b | Alternatives | 2 |
| c | Critic | 3 |
| d | Horizons | 4 |

Each tuple:
- `label`: the letter
- `subagent_type`: `$RESEARCH_AGENT` (resolved by task type in Stage 1b — same variable every
  other research dispatch site already uses)
- `prompt`: "Research task $task_number: $description" plus the role's own one-line angle (e.g.
  "Focus: primary investigation" / "Focus: alternative approaches" / "Focus: critique prior
  teammates' findings" / "Focus: roadmap/strategic horizons"), plus ". User focus: $focus_prompt"
  when non-empty
- `delegation_extras`: `{ teammate_letter: "<letter>", artifact_number }` — the research agent
  contract (`agents/general-research-agent.md` and its `-hard` variant) already declares both
  fields and derives `reports/{NN}_teammate-{letter}-findings.md` itself from them; this builder
  never hardcodes that path as a literal it writes to.
- `output_path`: `reports/{NN}_teammate-{letter}-findings.md` (same derivation, computed here only
  so Stage 3.6's collection step knows where to look)
- `territory`: empty (`{}`) — no source files are touched; artifact paths are disjoint by
  construction (each letter owns its own finding file)

#### `plan` branch

Fixed roles gated by `team_size_eff`:

| Letter | Role | Present from `team_size_eff` |
|--------|------|-------------------------------|
| a | Primary/Incremental | 2 |
| b | Alternative-Boundaries | 2 |
| c | Risk-and-Dependency | 3 |

Each tuple:
- `label`: the letter
- `subagent_type`: `$PLANNER_AGENT`
- `prompt`: "Create implementation plan for task $task_number" plus the role's own one-line angle
  ("incremental/primary approach" / "alternative phase boundaries" / "risk and dependency
  analysis"), plus ". User focus: $focus_prompt" when non-empty
- `delegation_extras`: `{ teammate_letter: "<letter>", artifact_number, research_path }` — the
  planner contract (`agents/planner-agent.md` and its `-hard` variant) already declares all three
  and derives `plans/{NN}_candidate-{letter}.md` itself.
- `output_path`: `plans/{NN}_candidate-{letter}.md`
- `territory`: empty (`{}`)

#### Synthesis step (D4) — shared by both branches above

After Stage 3.6's collection step records which teammate files are present, dispatch
`synthesis-agent` via the Agent tool (a plain, direct dispatch — not routed through Stage 3.5,
since `synthesis-agent` is a fresh-context reader/writer with its own fixed input contract, not a
lifecycle-phase agent):

- `prompt`: names the present teammate finding paths (as `@`-references), the task description,
  the focus prompt, and the unified output path
- `context`: `{ task_number, session_id, orchestrator_mode: true }` plus the paths
  `specs/ROADMAP.md` and `specs/TODO.md` — exactly the Stage 1 inputs `agents/synthesis-agent.md`
  already declares it reads (teammate finding paths, task description, focus prompt, output path,
  roadmap path, TODO path)
- unified output path: `reports/{NN}_team-research.md` for `research`, `plans/{NN}_{slug}.md` for
  `plan`

`agents/synthesis-agent.md` is NOT edited by this work — it is dispatched exactly as its own
existing contract already describes itself, for the first time from this call site.

**Synthesis fallback**: if the dispatch returns without producing a file at the unified output
path, fall back to lead-inline synthesis (the orchestrator itself reads the present teammate
files and writes the unified artifact directly) with one loud stderr warning. Never fail the
cycle on synthesis alone — a missing synthesis output degrades to inline synthesis, not to an
aborted dispatch.

Set `synthesis_path` (Stage 3.6's own output, below) to the unified output path once it exists
(whether written by `synthesis-agent` or by the inline fallback) — this is what the calling
dispatch site links into `state.json` in place of any one teammate's raw finding file.

#### `implement` branch

**D5 hard-mode interaction — stated first, before anything else in this branch**: when
`hard_mode` is `"true"`, this branch returns an EMPTY `teammate_plan` immediately, plus one loud
stderr line: `echo "[orchestrate] --team implement fan-out suppressed under --hard: H1's
single-blocking-phase-per-cycle contract takes precedence" >&2`. Stage 3.6 treats an empty
`teammate_plan` exactly like a degraded return (see Stage 3.6 above) and the caller falls through
to the existing H1 single-phase dispatch, unchanged. Nothing below this paragraph runs when
`hard_mode` is `"true"`.

**Conformance gate, before any filtered heading scan**: source
`scripts/lib/phase-heading-patterns.sh` (the shared anchor for this predicate; never re-derive an
inline regex), then call `has_nonconforming_phase_headings "$plan_path"`. On a hit, this branch
refuses to build a teammate plan at all: it returns an empty `teammate_plan` plus one loud stderr
line naming the non-conforming heading, routing the caller to its own degraded single-dispatch
return — exactly like the hard-mode case above. It must NEVER silently select the next conforming
heading and build a partial teammate plan around the gap.

**Teammate-set derivation**: once the conformance gate passes, derive the teammate set from the
plan's own `**Dependency Analysis**` wave table when the plan carries one, falling back to each
phase's own `**Depends on**:` field to reconstruct wave membership when it does not. Only OPEN
phase headings (`[NOT STARTED]`/`[IN PROGRESS]`/`[PARTIAL]`) are eligible; a `[COMPLETED]` or
`[COMPLETED WITH EXCLUSIONS]` phase is never re-dispatched. For the current wave: teammate count =
`min(len(wave.phases), team_size_eff)` — a wave wider than `team_size_eff` dispatches only the
first `team_size_eff` phases of that wave this cycle; the remainder waits for a subsequent cycle.

Each tuple:
- `label`: the phase number (e.g. `"3"`, `"4.1"`)
- `subagent_type`: `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b)
- `prompt`: "Implement task $task_number, phase {phase_number}, following the plan" plus
  ". User focus: $focus_prompt" when non-empty, plus the `<territory>` block described below
- `delegation_extras`: `{ plan_path, phase_number, roadmap_path: "specs/ROADMAP.md" }`
- `output_path`: none in the finding-file sense — implement teammates report through the plan's
  own phase heading and the standard `.return-meta.json`/progress-file mechanism every
  implementation agent already uses, not a separate artifact file
- `territory`: built per the paragraph below

**Territory (H7)**: build the `owned_files`/`read_only_files`/`forbidden_files` object exactly as
defined in `context/contracts/territory.md` — referenced by path here, with no territory prose
re-authored — setting `owned_files` to the phase's own "Files to modify" list (read from the
phase body in the plan). Where a phase's body has no "Files to modify" list, fall back to an
empty `owned_files` and let the agent derive its own from the phase body, exactly as the existing
H1 territory literal already does in this same file's hard branch. Include the contract's
concurrency note in spirit: this declaration asserts ownership, not exclusivity — a dispatched
teammate may still observe a foreign commit or a running build it did not start, and must STOP and
report rather than proceed as if it were the only agent working. Emit this as the stage's own
`<territory>` block, appended to the teammate's prompt, INDEPENDENTLY of `hard_mode` — this is
deliberate: base-mode team-implement teammates need a territory contract exactly as much as
hard-mode ones do, and this emission does not touch or re-gate Stage 3.5's own hard-contract
`<hard-mode-contracts>` block (which stays gated on `hard_mode` exactly as before).

**Multi-wave execution**: waves run strictly in dependency order. A later wave's teammate tuples
are built only AFTER every teammate in the previous wave has returned (or timed out) and Stage
3.6's collection step has recorded the previous wave's results — never built or dispatched ahead
of that point.

**Debugger role**: if any teammate in a wave reports a phase error (a non-`implemented`,
non-`partial` outcome, or a `.return-meta.json` status of `failed`/`blocked` for its phase), spawn
one additional teammate OUTSIDE the wave's own headcount — it does not count against
`team_size_eff` — with `subagent_type: $IMPLEMENT_AGENT`, a prompt carrying the failing phase's
own context plus the reported error text verbatim, and a `territory` scoped to that failing
phase's own files only (the same `owned_files` list the original teammate received).

**Collection (implement has no synthesis step)**: Stage 3.6's collection step aggregates each
returned teammate's own phase-completion status directly — reading the same
`phases_completed`/plan-heading state every single-dispatch implement cycle already reads —
rather than dispatching `synthesis-agent`. `synthesis_path` therefore stays empty for `implement`,
always.

---

### Stage 4: State Handlers

**Every handler's `context` object below additionally carries `artifact_number: $ARTIFACT_NUMBER`**,
resolved this cycle by Stage 2b's `resolve_cycle_artifact_number()` (called from Stage 3's 3c
before the handler below runs). Stated once here, exactly as the `team_mode` fork paragraph below
is stated once and referenced by every later occurrence rather than restated — no individual
handler's `context` table row is edited to add this field.

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

**`team_mode` fork (first occurrence — stated fully here; every later occurrence in this file
references this paragraph rather than restating it)**: at the same granularity the `hard_mode`
fork (D5) uses on the `planned`/`implementing` handler below, this handler forks its whole
dispatch body on `team_mode`:

```bash
if [ "${team_mode:-false}" = "true" ]; then
```

Run **Stage 3.6: Team Fan-Out** (see above) with `phase=research` and the rest of Stage 3.6's
already-derived inputs (`team_size_eff`, `hard_mode`, `clean_flag`, `effort_flag`, `lit_flag`,
`session_id`, `task_dir`, `handoff_path`) — pointer only, never an inlined copy of that stage's
body. A `fanout_degraded=true` return means Stage 3.6 itself found no teammate to spawn (the
teams runtime is unavailable, or Stage 3.6a's own builder degraded) — in that event, fall straight
through to the `else` branch below and run its single-agent dispatch unchanged. The degraded path
costs nothing beyond the one warning Stage 3.6 already emits.

```bash
else
```

Run **Stage 3.5: Dispatch Prep** with `phase=research` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Research task $task_number: $DESCRIPTION" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff (Stage 5). Increment cycle_count.

```bash
fi
```

#### State: `researching`

**Converged (was: exit with warning; see below for why this is now safe)**: dispatch to
research, identically to the `not_started` handler above. `scripts/command-gate-in.sh`'s
`task-lock.sh acquire-retry` already `return 1`s and aborts the entire single-task `/orchestrate`
invocation, before Stage 1 is ever entered, whenever a FRESH foreign lock refuses after its
bounded retry budget. This handler is only reachable once this session already holds the lock —
so the former warning's claim ("another session is actively researching") is provably false in
every reachable case: either no other session holds the lock (this session's own acquire
succeeded outright), or a prior session's lock was stale and reclaimed. A task sitting in
`researching` with a dead prior session's stale lock is exactly the stranded-task case this
convergence exists to unstick; re-dispatching research is the correct, idempotent recovery
action (a fresh research pass adds a new report, it does not corrupt or lose the old one).

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

**`team_mode` fork** (see the `not_started` handler above for the full statement of this fork's
semantics; not restated here):

```bash
if [ "${team_mode:-false}" = "true" ]; then
```

Run **Stage 3.6: Team Fan-Out** with `phase=research` (pointer only). A `fanout_degraded=true`
return falls through to the `else` branch below.

```bash
else
```

Run **Stage 3.5: Dispatch Prep** with `phase=research` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Research task $task_number: $DESCRIPTION" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff (Stage 5). Increment cycle_count.

```bash
fi
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

**`team_mode` fork** (see the `not_started` handler for the full statement of this fork's
semantics; not restated here):

```bash
if [ "${team_mode:-false}" = "true" ]; then
```

Run **Stage 3.6: Team Fan-Out** with `phase=plan` (pointer only). A `fanout_degraded=true` return
falls through to the `else` branch below.

```bash
else
```

Run **Stage 3.5: Dispatch Prep** with `phase=plan` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$PLANNER_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Create implementation plan for task $task_number" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

#### State: `planning`

**Converged (was: exit with warning, same pattern as the former `researching` handler; see that
handler above for the full "this session provably holds the lock" justification, which applies
identically here)**: dispatch to plan, identically to the `researched` handler above.

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

**`team_mode` fork** (see the `not_started` handler for the full statement of this fork's
semantics; not restated here):

```bash
if [ "${team_mode:-false}" = "true" ]; then
```

Run **Stage 3.6: Team Fan-Out** with `phase=plan` (pointer only). A `fanout_degraded=true` return
falls through to the `else` branch below.

```bash
else
```

Run **Stage 3.5: Dispatch Prep** with `phase=plan` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$PLANNER_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Create implementation plan for task $task_number" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

#### State: `planned` or `implementing`

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

**D5 — the whole handler body is forked on `$hard_mode`.** The hard branch (H1) dispatches
exactly one OPEN phase per cycle; the base (`else`) branch below is the pre-existing whole-plan
dispatch, byte-identical to before this fork.

```bash
if [ "${hard_mode:-false}" = "true" ]; then
```

##### Hard branch: Per-Phase Dispatch (H1)

```bash
# Read current handoff to determine phase progress.
if [ -f "$handoff_file" ]; then
  phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
  phases_total=$(jq -r '.phases_total // 0' "$handoff_file")
  last_skeleton=$(jq -r '.skeleton // false' "$handoff_file")
else
  phases_completed=0
  phases_total=0
  last_skeleton=false
fi
# D7: phases_completed_before/phases_completed_after are referenced by the Stage 5b churn
# signature below but were, before this migration, set by NO stage in either engine (verified by
# grep — hard-file line 1091 is the only consumer). Capture it here, immediately after the
# handoff read above, so it is in scope before any dispatch this cycle might make; Stage 5b
# (after Stage 5's own phases_completed assignment) supplies phases_completed_after.
phases_completed_before="$phases_completed"

# Heading-scan phase selection, replacing a naive next_phase=$((phases_completed + 1)) integer
# increment (could not address N.1/N.2 sub-phase headings, sparse numbering, or
# skeleton-exhaustion). Mirrors skill-implementer-hard/SKILL.md Stage 3b's own fix.
next_phase=""
phase_scan_inconclusive=false
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than
  # re-derived inline. Uses the library's OPEN alternation (NOT STARTED|IN PROGRESS|PARTIAL|
  # BLOCKED) and extract_phase_number so a non-conforming heading is never silently
  # mis-selected or truncated.
  . .claude/scripts/lib/phase-heading-patterns.sh
  # --- resume-scan-conformance-gate:begin ---
  # Whole-file conformance check BEFORE the filtered scan below. PHASE_HEADING_ERE admits
  # conforming headings only, so a non-conforming heading is not merely unmatched by that grep
  # -- it is INVISIBLE to it, and the scan would silently select the next conforming OPEN
  # heading instead, dispatching out of order on top of unfinished work.
  # has_nonconforming_phase_headings is the required boolean predicate; the
  # `nonconforming_phase_headings | grep -q .` pipe form is forbidden (unsafe under pipefail).
  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "orchestrate-h1-next-phase" || true
    phase_scan_inconclusive=true
  else
    next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1)
    if [ -n "$next_heading" ]; then
      next_phase=$(extract_phase_number "$next_heading") || next_phase=""
      if [ -z "$next_phase" ]; then
        # Defense-in-depth only, and unreachable by construction: the grep above already
        # guarantees this line matches PHASE_HEADING_ERE. Funnelled into the same sentinel so
        # there is exactly one inconclusive path, never a second silent one.
        phase_scan_inconclusive=true
      fi
    fi
  fi
  # --- resume-scan-conformance-gate:end ---
fi

if [ "$phase_scan_inconclusive" = "true" ]; then
  echo "[orchestrate] H1: non-conforming phase heading(s) in $plan_path — the filtered resume scan cannot see them, so the true next phase is UNKNOWN." >&2
  echo "[orchestrate] Refusing to dispatch, and refusing to claim skeleton-exhaustion or completion. Fix the plan's heading grammar (see plan-format.md's canonical phase-heading shape) and re-run." >&2
  EXIT (partial)

elif [ -n "$next_phase" ]; then
  # --- marker-handoff-crosscheck-predispatch:begin ---
  # Defect 6, PRE-DISPATCH and dispatch-REFUSING. Distinct from base Stage 5's own
  # `marker-handoff-crosscheck` region, which is POST-dispatch and diagnostic-and-downgrading;
  # both are retained (see this task's plan Phase 5). An interrupted dispatch can leave the
  # plan's phase markers ahead of the handoff (marker claims [COMPLETED], handoff's own
  # phases_completed has not confirmed it yet -- see context/contracts/wrap-up.md's "Ordering:
  # Handoff Write Precedes Marker Promotion"). Compare the marker-derived completed count
  # against the handoff's own phases_completed (already read above) before trusting the
  # heading scan's next_phase selection. The has_nonconforming_phase_headings ordering
  # obligation is already satisfied here by construction: this elif branch is reached only
  # after that check already ran (and passed) earlier in this same block.
  marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path" 2>/dev/null || echo 0)
  if [ "$marker_completed_count" != "$phases_completed" ]; then
    echo "[orchestrate] H1: MARKER/HANDOFF MISMATCH — plan file shows ${marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but the handoff's own phases_completed=${phases_completed}. Not dispatching the successor over unconfirmed work." >&2
    if [ "$marker_completed_count" -gt "$phases_completed" ]; then
      # Downgrade the specific disputed phase heading -- the (phases_completed + 1)-th
      # [COMPLETED]/[COMPLETED WITH EXCLUSIONS] heading by order of appearance -- to
      # [PARTIAL], matching the manual downgrade the operator performed in the observed
      # incident.
      disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$plan_path" | sed -n "$((phases_completed + 1))p")
      if [ -n "$disputed_line" ]; then
        disputed_linenum="${disputed_line%%:*}"
        disputed_text="${disputed_line#*:}"
        echo "[orchestrate] H1: downgrading disputed phase heading to [PARTIAL]: ${disputed_text}" >&2
        sed -i -E "${disputed_linenum}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "$plan_path"
      fi
    fi
    EXIT (partial)
  fi
  # --- marker-handoff-crosscheck-predispatch:end ---

  echo "[orchestrate] H1: Per-phase dispatch — phase $next_phase (heading-scan)" >&2

  # Mint this phase's dispatch identity (Defect A) before building dispatch_context, so the
  # per-phase JSON literal below can carry it inline alongside handoff_path.
  dispatch_seq=$(mint_dispatch_seq)

  # Territory (H7, Defect 5): no cross-agent FILE conflict exists within this orchestrator's OWN
  # dispatches (exactly one blocking Agent call per cycle — see "Parallel Wave Dispatch:
  # DISABLED" note below). Defect 5 is a DIFFERENT concern: a woken PREDECESSOR dispatch (see
  # context/patterns/dispatch-report-not-termination.md) resuming outside this orchestrator's
  # own control flow. The orchestrator does not parse the plan's "Files to modify" list itself
  # -- it points the agent at the plan/phase location it already has in this same context, and
  # the agent (unrestricted in what it may read) derives its own owned_files from the phase's
  # own section. Setting `territory` here (non-empty) is what causes Stage 3.5's `implement`
  # `core_contracts` to append `territory.md` — see that stage's `territory` input row.
  territory='{
    "owned_files": "derive from plan_path'\''s Phase '$next_phase' \"Files to modify\" list",
    "read_only_files": [],
    "forbidden_files": [],
    "concurrency_note": "This declaration asserts only which files THIS dispatch owns. It does NOT assert exclusive access -- a still-live predecessor may exist. If you observe foreign commits, foreign uncommitted modifications, or a running build you did not start, STOP and report it rather than proceeding or dismissing it. See context/contracts/territory.md and context/patterns/dispatch-report-not-termination.md."
  }'

  dispatch_context='{
    "task_number": '$task_number',
    "task_type": "'$TASK_TYPE'",
    "session_id": "'$session_id'",
    "orchestrator_mode": true,
    "effort_flag": "hard",
    "plan_path": "'$plan_path'",
    "roadmap_path": "specs/ROADMAP.md",
    "phase_number": '$next_phase',
    "task_dir": "'$TASK_DIR_ABS'",
    "handoff_path": "'$HANDOFF_PATH_ABS'",
    "dispatch_seq": '$dispatch_seq',
    "territory": '$territory'
  }'

  # This preflight sits inside the `[ -n "$next_phase" ]` branch ONLY — never in the elif
  # skeleton-exhaustion branch or the trailing else (all-complete) branch below, neither of
  # which dispatches an implement agent. Its remaining side effects are the workflow-active
  # marker write and the plan-level [STATUS] stamp (via update-plan-status.sh) — it writes NO
  # per-phase marker, on any path: the dispatched implementation agent owns every per-phase
  # [IN PROGRESS]/[COMPLETED] transition directly via its own explicit phase-status calls, as
  # the first action of processing whichever phase it actually works on (see Stage 4A of
  # general-implementation-hard-agent). This is deliberate, not an oversight — re-deriving "the
  # first NOT STARTED phase" here with a narrower scan could advance a phase this dispatch
  # never touched, diverging from the wider `next_phase` selection above whenever the
  # dispatched phase was itself a resumed IN PROGRESS/PARTIAL/BLOCKED one.
  skill_preflight_update "$task_number" "implement" "$session_id"

  # Dispatch window for infra-failure discrimination — see
  # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
  dispatch_start_ts=$(date -u +%s)
  dispatch_was_transport_error=false
```

Run **Stage 3.5: Dispatch Prep** with `phase=implement` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`. `territory` (set
above) is non-empty, so `hard_contracts_block` includes `territory.md`.

```bash
# D6: build_hard_mode_phase_mission() carries ONLY the non-duplicated residue of the hard
# engine's build_hard_mode_prompt_context() — the phase-only mission line, the settled-design
# preamble instruction (which has no contract file of its own), and the "PHASES COMPLETED: n
# of m" line. It deliberately does NOT restate anti-analysis, wrap-up, recovery,
# phase-closure, or pre-edit-gate — Stage 3.5's hard_contracts_block (built above with
# `territory` in scope) already injects all of those as <hard-mode-contracts> entries.
build_hard_mode_phase_mission() {
  echo "
HARD MODE DISPATCH — PHASE MISSION:

1. Mission: Implement phase $next_phase only. Do not continue past this phase.
2. Settled Design Preamble: State the decided design before first tool call.

PHASES COMPLETED: $phases_completed of $phases_total
"
}
phase_mission_block=$(build_hard_mode_phase_mission)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Implement phase $next_phase of task $task_number" then append `phase_mission_block`, then `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `$dispatch_context` (built above) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output means `false`. Then read handoff (Stage 5), check churn
state (Stage 5b), and increment `cycle_count`.

```bash
elif [ "$last_skeleton" = "true" ]; then
  # Skeleton-exhaustion routing: no incomplete phase heading remains AND the last handoff
  # declared skeleton=true. Derive the follow-up task list from the actually-shipped
  # wrap-up.md field `sorry_inventory[].follow_up_task` — NOT the unpopulated top-level
  # `.follow_up_tasks`.
  follow_up_tasks=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | join(", ")' "$handoff_file")
  follow_up_count=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | length' "$handoff_file")
  echo "[orchestrate] Skeleton plan exhausted — follow-up tasks pending: {${follow_up_tasks}}" >&2

  # This postflight call is routed through the pr_ready target argument (never raw-edit
  # state.json). --allow-pr-ready is required here because update-task-status.sh restricts
  # pr_ready to task_type == "pr" unless explicitly overridden; this skeleton-exhaustion
  # branch is the sanctioned task-type-agnostic exception to that guard. Because this call is
  # a postflight operation, update-task-status.sh's own postflight:pr_ready -> completed
  # mapping (see context/standards/status-markers.md's "Target Arguments vs. Resting States"
  # subsection) resolves the resting state to completed regardless of task type.
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready

  # Propagate completion_summary/roadmap_items via the single shared implementation,
  # skill_orchestrate_propagate_completion (scripts/skill-base.sh), through a locally-named
  # shim (Stage 4/5 call sites elsewhere in this file pattern already say the shim name, not
  # the shared function directly). No precomputed JSON is passed — this branch has no cached
  # recovery JSON and needs a fresh read. dispatch_start_ts is still correct here: this branch
  # is only entered on a cycle where no new dispatch occurred, so the variable still holds the
  # last real per-phase implement dispatch's timestamp, preceding that dispatch's
  # .return-meta.json write.
  source .claude/scripts/skill-base.sh
  hard_orchestrate_propagate_completion() {
    skill_orchestrate_propagate_completion "$1" "$2" "$3" "$4" "${5:-}" "[orchestrate]"
  }
  hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}"

  rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note.
  EXIT (success)

else
  # No incomplete phase heading remains and the last handoff was NOT a skeleton: all phases
  # are genuinely complete. Do not blindly dispatch phase 1 and do not loop toward MAX_CYCLES
  # here -- fall through without a new Agent dispatch; Stage 5 Part B's
  # phases_completed >= phases_total gate performs the actual status transition.
  echo "[orchestrate] No incomplete phase heading remains and last handoff was not a skeleton — deferring to Stage 5 completion gate." >&2
fi
```

**Parallel Wave Dispatch: DISABLED (scoped to the hard branch's own per-phase dispatch).** The
Per-Phase Dispatch handler above is the sole implement-dispatch path THIS BRANCH (`hard_mode ==
"true"`) uses: the orchestrator dispatches exactly one phase per cycle and blocks on its return —
no simultaneous/background `Agent` calls. Territory contracts (H7) still inform the single-phase
dispatch context above, but never fan out into parallel dispatch here. This scoping is
deliberate, not incidental: team-mode research/plan fan-out (Stage 3.6, wired into the four
handlers above) is the sanctioned base-mode exception to it, and implement fan-out remains
suppressed under `hard_mode` regardless of `team_mode` — see Stage 3.6a's `implement` branch,
whose D5 hard-mode interaction paragraph returns an empty teammate plan for exactly this reason.
This is a statement about what this orchestrator's own Stage 4 does — it never issues two
concurrent `Agent` calls from THIS branch — not a claim about the state of the world: a
previously-dispatched agent may still be live via a self-armed watcher/monitor or an operator
resume (see `context/patterns/dispatch-report-not-termination.md`), entirely outside this
orchestrator's own control flow.

##### Base branch: whole-plan dispatch (unchanged)

```bash
else
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

**`team_mode` fork** (see the `not_started` handler above for the full statement of this fork's
semantics; not restated here). Since this whole base branch already runs only when `hard_mode` is
`"false"`, this is where implement's own team-mode fan-out actually reaches Stage 3.6 — the hard
branch above never reaches this point:

```bash
if [ "${team_mode:-false}" = "true" ]; then
```

Run **Stage 3.6: Team Fan-Out** with `phase=implement` (pointer only). A `fanout_degraded=true`
return falls through to the `else` branch below.

```bash
else
```

Run **Stage 3.5: Dispatch Prep** with `phase=implement` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Implement task $task_number following the plan" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

```bash
fi
```

#### State: `partial`

**Cross-reference**: the identical triage rule applied by hand below is also available as an
executable check, `scripts/orchestrate-triage-classify.sh single`. That script is the executable
form of this same rule, including its dual-form continuation-pointer resolution (nested
`continuation_context.handoff_path` OR flat `continuation_path`), and both engines now agree on
every row here except the NON-discharged sub-case of `blocked` — a narrower exception than
before this task, since the DISCHARGED sub-case now converges too (see the justification in the
"State: `blocked`" handler below).

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

Run **Stage 3.5: Dispatch Prep** with `phase=implement` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Resume implementation for task $task_number from continuation handoff" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
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

Run **Stage 3.5: Dispatch Prep** with `phase=implement` (see Stage 3.5 above) to produce
`memory_context`, `lit_context`, `effort_note`, and `hard_contracts_block`.

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | Stage 3.5's `model` output — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "Resume implementation for task $task_number (no continuation handoff; resume context recovered from the prior dispatch's return metadata)" (append ". User focus: $focus_prompt" if non-empty), then append `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5, each skipped when empty |
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

**Discriminating read (added by this narrowing)**: before falling through to blocker escalation,
determine whether this block has already DISCHARGED — its `dependencies[]` all reached
`status: "completed"` and its handoff carries no blockers — by invoking the executable classifier
directly, the same script Stage MT-4 already calls for the `mt` engine:

```bash
single_verdict=$(bash .claude/scripts/orchestrate-triage-classify.sh single "$task_number")
verdict_group=$(echo "$single_verdict" | jq -r '.group')
```

If `$verdict_group` is `research`, `plan`, or `implement`: the block is DISCHARGED. Dispatch
identically to the corresponding `#### State:` handler above (`not_started`/`researching` for
`research`, `researched`/`planning` for `plan`, `planned`/`implementing` for `implement`) — same
`skill_preflight_update("$task_number", <target-phase>, "$session_id")` call, same dispatch-window
reset, same Agent tool invocation shape as that handler, keyed off `$task_number`/`$session_id`
exactly as already bound in this cycle; no special-casing beyond selecting the target phase named
by `$verdict_group`.

If `$verdict_group` is anything else (`needs_human`) — a dependency still outstanding, empty
`dependencies[]`, a dependency stuck at a non-completed terminal status (`abandoned`/`expanded`),
handoff blockers present, or a discharged block with no recorded `previous_status` — fall through
to the read-blockers-and-escalate flow below, UNCHANGED:

```bash
blocker_desc=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"' \
  specs/state.json)
```

Invoke blocker escalation (Stage 6) with blocker_desc.

**Why this handler stays engine-unconditional for the NON-discharged case (Decision 1, narrowed
by this task, intentional divergence from `mt`)**: for a block that has NOT resolved, this
handler always escalates to a human, regardless of engine — a solo invocation has no sibling task
to make progress on, so escalation is the only meaningful action, whereas a batch invocation
(Stage MT-4) skips the still-blocked task so its siblings can proceed. This narrower row is where
the two engines still diverge; it is documented, not an oversight. For the DISCHARGED case, both
engines now converge on the SAME `previous_status`-routed dispatch — see
`scripts/orchestrate-triage-classify.sh`'s header table and justification paragraph for the full
six-branch discriminator.

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
# Named-shim to the single shared implementation, skill_orchestrate_append_detected_defect
# (scripts/skill-base.sh) — see that function's header for the full contract (entry shape,
# unconditional-append rule, notice format, MUST-NOTs). Kept as a locally-named function because
# test-handoff-dispatch-identity.sh stubs `append_detected_defect` by this exact name and `eval`s
# a region below that calls it — a renamed call site would silently defeat that stub. Source is
# defensive/idempotent: this Stage 5 fence has no earlier explicit source line of its own to
# depend on.
source .claude/scripts/skill-base.sh
append_detected_defect() {  # class, attributed_path, site, detail, record_result
  skill_orchestrate_append_detected_defect "$loop_guard_file" "[orchestrate]" "$1" "$2" "$3" "$4" "${5:-}"
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

# ── Stray-handoff sweep + outcome-recovery orchestration ─────────────────────────────────────
# Single shared implementation, orchestrate-stage5-gates.sh — see that script's header for the
# full contract (stray-handoff sweep, run unconditionally every cycle exactly like the pre-dedup
# inline code; .return-meta.json outcome recovery, reachable only when the expected handoff is
# missing or stale — see "MUST NOT (Context Flatness Constraint) — Recovery exception
# (return-meta fallback)"; the widened evidence-corroboration narrative for a recovered outcome
# — the PHASES_ZERO_ON_SUCCESS arm calling skill_corroborate_phase_counts, and the sibling
# ARTIFACTS_SHAPE_MISMATCH arm; infra-failure discrimination and the sanctioned phase-marker
# recovery grep for a non-recovered outcome). This is the same call
# skill-orchestrate-hard/SKILL.md's Stage 5 makes, so the two engines cannot drift apart on this
# logic again. The script never sets loop state itself — it only computes and prints a decision
# JSON; every field below is applied inline, in the same branch shape the pre-dedup code used.
stage5_gates_json=$(bash .claude/scripts/orchestrate-stage5-gates.sh \
  "$TASK_DIR" "$task_number" "$session_id" "$handoff_file" "$handoff_stale" \
  "${dispatch_start_ts:-9999999999}" "$loop_guard_file" "[orchestrate]" \
  "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
  "skill-orchestrate/SKILL.md" "${dispatch_was_transport_error:-false}" "${cycle_count:-0}" \
  "${plan_path:-}")
have_outcome=$(echo "$stage5_gates_json" | jq -r '.have_outcome')

if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  recovered=$(echo "$stage5_gates_json" | jq -r '.recovered')
  if [ "$recovered" = "true" ]; then
    # Deliberate: charge exactly one work cycle, identical to the handoff-present success path
    # below — real work happened and produced a status transition, so infra_exempt_cycle stays
    # false (its reset default at the top of this stage). This is NOT the infra-exempt case,
    # which exists because no work happened at all; exempting a recovered success would also
    # remove the only bound on a loop that keeps recovering.
    dispatch_status=$(echo "$stage5_gates_json" | jq -r '.dispatch_status')
    phases_completed=$(echo "$stage5_gates_json" | jq -r '.phases_completed')
    phases_total=$(echo "$stage5_gates_json" | jq -r '.phases_total')
    plan_markers_verified=$(echo "$stage5_gates_json" | jq -r '.plan_markers_verified')
    handoff_artifact_path=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_path')
    handoff_artifact_type=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_type')
    handoff_artifact_summary=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_summary')
  else
    # Infra-failure discrimination already applied inside the script — see
    # context/patterns/infra-failure-discrimination.md. TWO corroborating signals are required
    # to exempt this cycle from the work-cycle budget: (a) dispatch_was_transport_error,
    # narrated judgment about the Agent tool call itself, set at the dispatch site in Stage 4;
    # (b) meta_touched, a mechanical check of whether the subagent's own Stage 0 early-metadata
    # write landed inside this dispatch window. Either signal alone DEFAULTS TO CHARGING a
    # genuine cycle — the script's own defaults preserve that.
    infra_exempt_cycle=$(echo "$stage5_gates_json" | jq -r '.infra_exempt_cycle')
    # infra_failures itself was already incremented and persisted by the script when charged;
    # re-read it here so this cycle's own copy of the variable stays in sync for any later log
    # line in this same fence that references it.
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file" 2>/dev/null) || infra_failures="${infra_failures:-0}"
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

  # ── Advisory evidence probe: ARTIFACTS_SHAPE_MISMATCH on the handoff-present path ─────────
  # Closes the residual gap this branch's own comment used to name as open (see the rewritten
  # note under "MUST NOT (Context Flatness Constraint) — Recovery exception (phase-marker
  # grep)" below): branch (3), the handoff-present path, never called
  # orchestrate-recover-outcome.sh, so ARTIFACTS_SHAPE_MISMATCH was never *computed* here at
  # all — only the recovered-path occurrence (branch 2's arm above) had a consumer.
  #
  # ADVISORY ONLY, by construction: this probe NEVER overrides the handoff-derived outcome,
  # NEVER changes dispatch_status, and NEVER drives a status transition. Its sole effect,
  # mirroring branch 2's own ARTIFACTS_SHAPE_MISMATCH arm for the same defect class, is the
  # loud stderr notice plus the non-fatal system-defect-record.sh call below. The handoff this
  # branch already parsed above (dispatch_status, phases_completed/total,
  # handoff_artifact_path/type/summary) remains the sole source of truth for this cycle's
  # outcome — this probe reads a SEPARATE file (.return-meta.json, if any) purely for its
  # evidence_suspect/evidence_reason fields and ignores every other field it returns.
  #
  # Exit-code handling: exit 0 (recovered=true) is the only code whose evidence fields are
  # consulted. Exit 1 and exit 2 both mean "no signal available" and are NOT escalated — a
  # handoff-present dispatch legitimately may have no recoverable `.return-meta.json` (e.g. a
  # hard-mode dispatch that only ever writes the handoff), so a probe miss here is silent, not
  # a defect.
  artifacts_probe_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
  artifacts_probe_exit=$?
  if [ "$artifacts_probe_exit" -eq 0 ]; then
    artifacts_probe_suspect=$(echo "$artifacts_probe_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || artifacts_probe_suspect=false
    artifacts_probe_reason=$(echo "$artifacts_probe_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || artifacts_probe_reason="NONE"
    if [ "$artifacts_probe_suspect" = "true" ] && [ "$artifacts_probe_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      echo "[orchestrate] EVIDENCE: advisory probe over this dispatch's .return-meta.json (handoff-present path) reports a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — advisory only; the handoff-derived outcome above is unaffected." >&2
      probe_record_result=$(bash .claude/scripts/system-defect-record.sh \
        --defect-class ARTIFACTS_SHAPE_MISMATCH \
        --detecting-site "skill-orchestrate/SKILL.md:stage-5-handoff-present-probe" \
        --task "$task_number" --session "$session_id" \
        --message "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
        --attributed-path "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      append_detected_defect "ARTIFACTS_SHAPE_MISMATCH" \
        "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" \
        "skill-orchestrate/SKILL.md:stage-5-handoff-present-probe" \
        "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
        "$probe_record_result"
    fi
  fi
  # exit 1/exit 2 (recovered=false, or usage/jq error): no signal available, nothing to do here.

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork). Base-mode
  # only (D6/Phase 6 decision record) — Stage 5b's H5 divergence audit plays this role in hard
  # mode instead; see the mutual-exclusion note at Stage 5a/5b below.
  if [ "${hard_mode:-false}" != "true" ] && [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
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
#
# Single shared implementation, orchestrate-stage5-postflight.sh — see that script's header for
# the full contract (the researched/planned/implemented/partial|failed|blocked/Tier C case
# ladder, the completion-claim gate, the completion-propagation call, the artifact-linking
# block). This is the same call skill-orchestrate-hard/SKILL.md's Stage 5 makes, so the two
# engines cannot drift apart on this logic again. The script performs the real state.json/
# TODO.md writes, but the actual loop-halting decision (`EXIT (partial)`) and the cycle_count
# increment below stay HERE, applied inline from the script's decision JSON — this is the
# mitigation for the state-swallowing risk: a script boundary must never silently absorb an
# orchestrator loop-control transition.
if [ "$have_outcome" = "true" ]; then
  stage5_postflight_json=$(bash .claude/scripts/orchestrate-stage5-postflight.sh \
    "$task_number" "$session_id" "$TASK_TYPE" "$TASK_DIR" "$dispatch_status" \
    "$phases_completed" "$phases_total" "$plan_markers_verified" \
    "$handoff_artifact_path" "$handoff_artifact_type" "$handoff_artifact_summary" \
    "[orchestrate]" "skill-orchestrate/SKILL.md:stage-5-tier-c" \
    "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md" "" \
    "${dispatch_start_ts:-9999999999}" "$handoff_file" "$loop_guard_file" "${cycle_count:-0}")
  offschema_dispatch_status=$(echo "$stage5_postflight_json" | jq -r '.offschema_dispatch_status')

  # Off-schema halt — consumed HERE, after the script's own artifact linking has already run,
  # not as an inline exit inside the case statement. This preserves the dispatch's evidence (the
  # artifact, if any, is still linked into TODO.md/state.json) rather than discarding it. Mirrors
  # Stage 4's "Unknown state" handler precedent.
  if [ "$offschema_dispatch_status" = "true" ]; then
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

**Base mode only.** Called from Stage 5 when phase completion is below DRIFT_COMPLETION_THRESHOLD and dispatch_status is "partial".
Capped at MAX_DRIFT_INSPECTIONS=1 per /orchestrate invocation.

**Mutual exclusion with Stage 5b (decision record)**: Stage 5a and Stage 5b (below) are mutually
exclusive by construction — exactly one is reachable for any given `hard_mode` value. Hard mode's
H5 divergence-audit dispatch in Stage 5b plays the drift-inspection role that Stage 5a plays in
base mode; they are two different mechanisms answering the same underlying question ("is this
task's plan/execution drifting, and does it need outside intervention?"), not duplicates of each
other. This makes the existing Stage 2 comment (asserting hard mode "has no Stage 5a Drift
Inspection equivalent — its own H5 divergence-audit mechanism plays that role instead")
executable rather than merely asserted.

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

### Stage 5b: Churn Detection (H6) and Three-Strikes Audit Dispatch (H5) — hard mode only

**Placed AFTER Stage 5a Drift Inspection and before Stage 6.** Placement is load-bearing twice
over: it must run after Stage 5's own `phases_completed` assignment (D7 — this stage supplies
`phases_completed_after` from that already-assigned value) and it must stay strictly outside the
Stage 5 region `test-handoff-reader-parity.sh` extracts. Gated on `hard_mode`; entirely skipped
in base mode, where Stage 5a (above) plays the equivalent role — see that stage's mutual-exclusion
decision record.

```bash
if [ "${hard_mode:-false}" = "true" ]; then
  # D7: phases_completed_before/phases_completed_after were referenced by the source engine's
  # churn signature but set by NO stage in either engine before this migration (verified by
  # grep — exactly one occurrence across the pair, the consumer itself). phases_completed_before
  # was captured in Stage 4's H1 branch, immediately after that branch's own handoff read;
  # phases_completed_after is Stage 5's own already-assigned $phases_completed, taken here.
  # Guard against a cycle where the H1 branch did not run at all (phases_completed_before never
  # set this cycle) by skipping the churn check entirely rather than computing a false delta —
  # an unset-vs-zero distinction matters here, so this is a presence check, not a `// 0` read.
  if [ -n "${phases_completed_before+x}" ] && [ "${have_outcome:-false}" = "true" ] && [ -n "${handoff:-}" ]; then
    phases_completed_after="$phases_completed"
    phases_delta=$((phases_completed_after - phases_completed_before))

    # Churn signature: no progress this cycle despite a partial dispatch with blockers.
    has_blockers=$(echo "${blockers:-[]}" | jq 'length > 0' 2>/dev/null) || has_blockers=false
    if [ "$dispatch_status" = "partial" ] && [ "$has_blockers" = "true" ] && [ "$phases_delta" -eq 0 ]; then
      blocker_target=$(echo "$handoff" | jq -r '.blockers[0].target // "unknown"')
      current_target_churn=$(jq -r --arg target "$blocker_target" \
        '.target_churn[$target] // 0' "$churn_file")
      new_target_churn=$((current_target_churn + 1))

      # Update churn counters (atomic tmp-mv jq write, matching this file's other loop-guard/
      # churn-file writes).
      jq --arg target "$blocker_target" \
         --argjson count "$new_target_churn" \
         --argjson total "$((total_churn + 1))" \
         --arg sid "$session_id" \
        '.target_churn[$target] = $count | .total_churn = $total | .last_session_id = $sid' \
        "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

      echo "[orchestrate] H6: Churn detected on '$blocker_target' (count: $new_target_churn)" >&2

      # Three-strikes: dispatch a divergence audit instead of another implement.
      if [ "$new_target_churn" -ge 3 ]; then
        echo "[orchestrate] H5: Three-strikes — dispatching divergence audit for '$blocker_target'" >&2
        verbatim_goal=$(echo "$handoff" | jq -r '.blockers[0].verbatim_goal // ""')

        # $RESEARCH_AGENT never writes .orchestrator-handoff.json, per the Stage 3.6 "Scoping
        # Decision" in general-research-agent.md / general-research-hard-agent.md and the
        # Handoff Writers table in docs/architecture/handoff-schema.md — so no absolute anchor
        # (handoff_path) is passed here, and orchestrator_mode is explicitly false.
        Agent tool:
          subagent_type: $RESEARCH_AGENT
          prompt: "DIVERGENCE AUDIT for task $task_number. Target: '$blocker_target'. Verbatim goal: '$verbatim_goal'. This target has failed 3 times. Identify root cause of repeated failure. Write a divergence table, postmortem, and corrected target definition."
          delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit $blocker_target", orchestrator_mode: false}

        # Reset the churn counter for this target after the audit dispatch.
        jq --arg target "$blocker_target" --arg sid "$session_id" \
          '.target_churn[$target] = 0 | .audit_dispatches += 1 | .last_session_id = $sid' \
          "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

        # cycle_count is NOT incremented again here: Stage 5b runs strictly after Stage 5's own
        # tail, which already charged this cycle exactly once (D7's ordering fix — the source
        # engine's Stage 4b/Stage 5 ordering left this ambiguous; positioning Stage 5b after
        # Stage 5 resolves it to "exactly one increment per cycle", never two). Loop continues —
        # the next iteration re-dispatches implement with the audit's findings available to it
        # via the plan/handoff the audit informs.
      fi
    fi
  fi
fi
```

---

### Stage 6: Blocker Escalation (5-Step Sequence)

Called when: `partial` state with non-empty blockers, or `blocked` state that has NOT discharged
(a discharged `blocked` task dispatches directly to the phase its `previous_status` names instead
of reaching this stage — see the `#### State: blocked` handler's discriminating read).
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

**Forced-sequence-exhausted (A2 — checked first, ahead of the MAX_INFRA_FAILURES/MAX_CYCLES
checks below).** If this cycle's 3c popped `force_queue` (`force_invoked` is `true`) AND
`force_queue` is now empty, the composed `--research`/`--plan`/`--implement` sequence is
exhausted. STOP here — do not fall through to status-derived dispatch on a subsequent cycle:

```
if [ "${force_invoked:-false}" = "true" ] && [ "${#force_queue[@]}" -eq 0 ]; then
  echo "[orchestrate] Forced-phase sequence complete for task $task_number (last forced phase: $forced_phase). Stopping — the composed --research/--plan/--implement sequence does not fall through to status-derived dispatch."
  EXIT (success)
fi
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
# Single shared implementation, skill_orchestrate_merge_return_meta (scripts/skill-base.sh) — see
# that function's header for the full contract, including WHY it takes a resolved
# detected_defects JSON string rather than the loop-guard path (this clean-exit call reads it
# from the EARLIER fence's `$detected_defects`, captured BEFORE the `rm -f "$loop_guard_file"`
# cleanup above — the loop guard no longer exists by the time this fence runs).
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "implemented" \
  "$cycle_count" "$current_status"
```

On partial exit:

```bash
# Same shared implementation as the clean-exit variant above. The loop guard is PRESERVED on
# partial exit, so this reads it fresh immediately before the call — ordering is not
# load-bearing here, but the read stays structurally identical to the clean-exit variant.
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "partial" \
  "$cycle_count" "$current_status"
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
- `allow_scope_collision` (default: "false") — consumer-side opt-in bypass of the CROSS-BATCH
  `file_scope_collision` admission gate only, never `in_batch` (D1); never passed to
  `orchestrate-batch-admit.sh` itself (see Stage MT-3 step 4.5's `file_scope_collision` ->
  `cross_batch` branch below)
- `clean_flag` (default: `"false"`) — threaded from the command's `--clean` flag; suppresses
  Stage 3.5 Dispatch Prep's automatic memory retrieval for every per-task dispatch this batch
  makes.
- `effort_flag` (default: `""`) — threaded from the command's `--fast` flag; supplies reasoning-
  depth guidance to Stage 3.5 Dispatch Prep for every per-task dispatch this batch makes.
- `model_flag` (default: `""`) — threaded from the command's `--haiku`/`--sonnet`/`--opus`/
  `--fable` flags; selects the model family for every per-task dispatch this batch makes.
  Resolved **once here** and passed unchanged into every Stage 3.5 call — never re-resolved per
  task, and no per-task field is added to `mt_state_file`. The not-set sentinel is the **empty
  string**, matching `parse-command-args.sh`'s `MODEL_FLAG=""` default — not the literal token
  `null`.
- `hard_mode` — derived once, here, as `hard_mode="false"; [ "$effort_flag" = "hard" ] &&
  hard_mode="true"`. Consumed by Stage 3.5 Dispatch Prep's hard-mode contract injection below,
  for every per-task dispatch this batch makes, and reserved for later conditional
  state-machine branches (churn/three-strikes counters, the burnout circuit breaker) that read
  this same boolean rather than re-deriving it.
- `team_mode` (default: `"false"`) — read here for DIAGNOSTICS ONLY. Multi-task mode never fans
  out per task (multiplying per-task concurrency by per-teammate fan-out is unbounded — see
  `context/patterns/multi-task-operations.md`'s cost-warning), so this value never gates a Stage
  MT-4 dispatch fork. When `team_mode` is `"true"`, emit one notice per batch, once, here:
  `echo "[orchestrate] NOTICE: --team is accepted and ignored in multi-task mode — no per-task teammate fan-out will occur" >&2`.
- `force_phases` (default `""`) — read here for DIAGNOSTICS ONLY, on the identical terms
  `team_mode` is above. Multi-task mode has no per-task phase-forcing consumption today (deferred
  — see Phase 7's filed defect in this stage's originating plan); this value never gates a Stage
  MT-4 dispatch fork. When `force_phases` is non-empty, emit one notice per batch, once, here:
  `echo "[orchestrate] NOTICE: --research/--plan/--implement (force_phases=${force_phases}) are accepted and ignored in multi-task mode — no per-task phase forcing will occur" >&2`.

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
`implement_agents: {}`, `descriptions: {}` (map task_num -> task description, written once per
task by Stage MT-2 below; read by Stage MT-4's three dispatch loops for both the existing
`$description` prompt interpolation and the new Stage 3.5 Dispatch Prep's hard-required
`description` precondition), `infra_failures: {}` (map task_num -> count, default 0),
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
it leaves `eligible_tasks` by terminating or failing (a task no longer leaves `eligible_tasks`
merely by transitioning to an in-flight status (`researching`/`planning`), now that eligibility
is no longer status-gated — see Stage MT-3 step 3) — no persistent exclusion is needed for that
to happen, and the loop's existing
per-cycle re-evaluation already guarantees it. **Second, independent, per-cycle exit condition
(the one that actually bounds the self-modifying-specific case, and depends on no status
transition at all)**: the designated-candidate tie-breaker inside `orchestrate-batch-admit.sh`
(see that script's header) admits exactly one self-modifying candidate — the lowest task number —
on EVERY cycle, regardless of how many self-modifying candidates are co-dispatched. N
self-modifying candidates therefore converge to full dispatch in at most N cycles by
construction, independent of whether any sibling ever leaves `eligible_tasks` at all. See Stage
MT-3 step 3 (no longer a status-gated exclusion), step 4.5 (append-only population plus the
tie-breaker's `--phase-map`-threaded admission call), and the new consecutive-no-dispatch guard
below for the bounded case where NEITHER exit condition converges in time (e.g. a tie-breaker
defect), and Stage MT-5 (postflight reporting) for where this log is read.

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
- `idle_overlap_ledger: []` — an APPEND-ONLY OBSERVATION LOG of every admitted verdict this cycle
  carrying a non-empty `idle_overlap_advisory` (NEW in v5 — see Stage MT-3 step 4.5's "Idle
  cross-batch overlap advisory" check above), entries of the form
  `{"task": <int>, "colliding_task_number": <int>, "colliding_task_status": <string>, "overlapping_path": <string>, "cycle": <int>}`.
  Follows `defer_ledger`'s exact shape and MUST NOT: never read by any eligibility check,
  all-terminal check, circuit breaker, convergence guard, or admission branch — the candidates it
  names were ADMITTED, not deferred, so this log excludes nothing. It is written for reporting
  only, read at Stage MT-5 and by `commands/orchestrate.md` Step 5. It is never merged into
  `defer_ledger` — that log's `defer_reason` vocabulary is load-bearing for admission reporting,
  and an advisory has no `defer_reason` at all.

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

For each task in `task_numbers`, read `state.json` to get `task_type`, `project_name`,
`description`. Compute `task_dir = "specs/${padded}_${project_name}"`. Resolve `research_agent` and `implement_agent` using the same routing table as Stage 1b:

| task_type | research_agent | implement_agent |
|-----------|----------------|-----------------|
| `lean4` / `lean` | `lean-research-agent` | `lean-implementation-agent` |
| `neovim` | `neovim-research-agent` | `neovim-implementation-agent` |
| `nix` | `nix-research-agent` | `nix-implementation-agent` |
| *(default)* | `general-research-agent` | `general-implementation-agent` |

Check `.claude/extensions/${task_type}/manifest.json` for override routing. Populate all per-task maps into `mt_state_file`.

**Per-task description capture (must-fix, do not drop as redundant)**: within the same per-task
loop below, read `description=$(echo "$task_data" | jq -r '.description // ""')` and write it
into `mt_state_file`'s `descriptions` map, keyed by task number. Both `memory-retrieve.sh` (hard
`exit 1` on an empty description argument) and `lit-stage4a-flow.md` (`--query "$description"`)
hard-require this value — without this capture, the new Stage 3.5 Dispatch Prep silently no-ops
(no memory retrieval, no literature briefing) for every multi-task dispatch.

**Entry reconcile (once per task, never per-cycle)**: within this same per-task iteration — not
inside Stage MT-3's cycling loop — run `reconcile-task-status.sh` once for each task. This rides
the iteration Stage MT-2 already performs to build the routing table, satisfying the once-per-task
requirement on a path that has no single per-task entry point of its own. Live, bracketed the same
way as the single-task entry reconcile above (a live no-op prints nothing):

```bash
for task_number in "${task_numbers[@]}"; do
  # ... existing routing-table resolution for this task_number (task_type, project_name,
  # task_dir, research_agent, implement_agent) ...
  task_description=$(echo "$task_data" | jq -r '.description // ""')
  jq --arg t "$task_number" --arg d "$task_description" \
    '.descriptions[$t] = $d' \
    "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
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
   - **Eligibility is NOT status-gated on an in-flight string (REMOVED the former `{researching,
     planning}` exclusion here).** A task's own status among `{not_started, researched, planned,
     implementing, partial, researching, planning}` never by itself removes it from
     `eligible_tasks` — eligibility depends only on locks, `dependencies[]`, and file_scope
     overlap, all of which are already enforced downstream: Stage MT-4's per-task
     `task-lock.sh acquire` defers (never excludes) a task whose lock is held FRESH by a genuinely
     different session (exit 1 -> removed from this cycle's batch, never added to `failed_tasks`);
     a stale foreign lock is reclaimed with a warning. `task-lock.sh cmd_acquire` never reads
     `.status` — the lock layer, not the status string, has always been the real concurrency
     arbiter. A task stranded in `researching`/`planning` by a dead prior session's stale lock is
     therefore no longer silently skipped forever: it becomes eligible, the classifier (Stage MT-3
     step 4.5 below) routes it to the phase its status names, and Stage MT-4's lock acquire
     reclaims the stale lock and dispatches it.
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
   is a cross-reference only.

   **Classifier call — relocated here (was formerly invoked a second time, later, at Stage
   MT-4)**: before the admission call below, call the shared handoff-triage classifier ONCE for
   this cycle, over `eligible_tasks`, so the admission call can pass a `--phase-map` built from
   the SAME rule the read-only dry-run report reads, rather than a second,
   independently-maintained copy of it:
   ```bash
   mt_classify_ndjson=$(bash .claude/scripts/orchestrate-triage-classify.sh mt "${eligible_tasks[@]}")
   ```
   Capture `$mt_classify_ndjson` in this cycle's working state and carry it FORWARD into Stage
   MT-4 below — it is safe to reuse without re-invoking: nothing writes `specs/state.json`
   between this site and Stage MT-4's dispatch-bucket filtering within the same cycle, and no
   other step in between reads classifier output that would need a fresher read. Stage MT-4 no
   longer calls the classifier itself; see that stage's note.

   Build `--phase-map` from `$mt_classify_ndjson` — one `task_number:group` pair per candidate,
   comma-joined (the admission script only acts on the `research`/`plan` values; any other group
   value present is harmless, since the admission script ignores an unrecognized group):
   ```bash
   phase_map_arg=$(echo "$mt_classify_ndjson" | jq -r '"\(.task_number):\(.group)"' | paste -sd, -)
   ```

   Before dispatching
   `eligible_tasks` on EVERY cycle — including a cycle where `eligible_tasks` contains only a
   single task, since a cross-batch collision exists at batch size 1 — call the admission
   script, passing `--invocation-count` set to THIS CYCLE'S actual co-dispatch count,
   `${#eligible_tasks[@]}`, `--session-id "$session_id"` (D6, session-registry contention
   input) — the SAME bare `session_id` Stage MT-1 registered via `session-register` above, so
   this call's self-exclusion actually matches the batch's own registry entry rather than seeing
   it as foreign and deferring every candidate against itself — and `--phase-map "$phase_map_arg"`
   (the designated-candidate tie-breaker inside the admission script itself needs no argument; it
   is computed unconditionally from the co-dispatch set every call):
   ```bash
   bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id "$session_id" --phase-map "$phase_map_arg" "${eligible_tasks[@]}"
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

   `jq`-filter stdout for `.decision == "defer"`, then branch on `defer_reason` FIRST (schema v5
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
     status-mutated. **Log the verdict's own `reason` string directly** (do not reconstruct or
     paraphrase it) — as of the designated-candidate tie-breaker, `reason` already names the
     designated candidate this task is deferring in favor of and states plainly that this is a
     one-cycle ORDERING CONSTRAINT resolving in sequence, never an instruction to isolate the
     dispatch:
     ```
     [orchestrate] WARNING: Task #{task_number} has file_scope naming orchestrator-critical
       path {critical_path} ({critical_label}). {verdict.reason}
     ```
     (`{verdict.reason}` already ends with the `--allow-self-modifying` override mention, so no
     separate override line is appended here.)
     Additionally (no-override path only — a bypassed defer dispatches and must NOT be ledgered as
     a defer), append to `mt_state_file.defer_ledger`:
     `{"task": task_number, "defer_reason": "self_modifying", "collision_scope": null, "cycle": cycle_count, "detail": "matched critical path {critical_path} ({critical_label})"}`.
   - **`file_scope_collision`** — retains the exact pre-existing `collision_scope` branching
     below, byte-for-byte. Both branches share the same removal semantics: a deferred task is
     removed from **this cycle's** dispatch batch and is never added to `failed_tasks` (never
     added to `deferred_self_modifying` — that set is exclusively for the `self_modifying` branch
     above). Self-clearing differs by scope, and the two must not be conflated — see each bullet
     below for its own claim.
     - **`in_batch`** (the colliding task is itself in `eligible_tasks`): remove the deferred task
       from this cycle's dispatch batch and log the existing warning. This scope self-clears
       within this invocation: the deferred task becomes eligible again on a later cycle, once the
       colliding in-batch task leaves `eligible_tasks` by terminating or failing (a task no longer
       leaves `eligible_tasks` merely by transitioning to an in-flight status —
       `researching`/`planning` — now that eligibility is no longer status-gated; see Stage MT-3
       step 3). This claim is TRUE and is load-bearing for the convergence argument elsewhere in
       this file:
       ```
       [orchestrate] WARNING: Tasks #{X} and #{Y} have overlapping file_scope with no
         dependency_graph edge between them. Deferring #{Y} to a later cycle to avoid
         concurrent edits to the same files.
       ```
       Additionally, append to `mt_state_file.defer_ledger`:
       `{"task": Y, "defer_reason": "file_scope_collision", "collision_scope": "in_batch", "cycle": cycle_count, "detail": "colliding in-batch task #{X}"}`.
     - **`cross_batch`** (the colliding task is NOT part of `task_numbers` for this invocation):
       **consumer-side override check first** — if `allow_scope_collision == true` for this
       invocation, do NOT act on this defer verdict: dispatch the candidate this cycle anyway,
       exactly as if it had admitted. The verdict itself is unaffected by the flag — it is still
       emitted, still carries `defer_reason: "file_scope_collision"` and
       `collision_scope: "cross_batch"`, and `orchestrate-batch-admit.sh` is NEVER passed the
       flag; the bypass is entirely a decision made here, at the consumer, about whether to act on
       a verdict the script always computes honestly. Per D1, this override is
       **cross-batch-only**: it is checked ONLY in this `cross_batch` sub-branch — the `in_batch`
       branch above is NEVER bypassed by `allow_scope_collision`, regardless of whether it is
       active, and has no override check of its own. Log a loud, distinct bypass notice whether or
       not the gate would otherwise have fired, so a transcript reader can always tell the
       override was active this invocation. On the bypass path, do NOT append to
       `mt_state_file.defer_ledger` — a bypassed defer dispatches and must not be ledgered as a
       defer:
       ```
       [orchestrate] BYPASS: --allow-scope-collision is active. Task #{task_number} has
         overlapping file_scope with out-of-batch task #{colliding_task_number} (status:
         {colliding_task_status}); dispatching this cycle anyway per explicit human-intent
         override (cross-batch only).
       ```
       Otherwise (no override): remove the candidate from this cycle's dispatch batch and log a
       **distinct** warning naming the out-of-batch task and its `colliding_task_status`. This
       scope does NOT self-clear within this invocation: the excluded candidate does NOT
       automatically become eligible again this run — the colliding task is outside
       `task_numbers` and this loop has no mechanism to advance it. A human resolves batch
       composition, or a future invocation re-evaluates once the colliding task's status
       independently changes:
       ```
       [orchestrate] WARNING: Task #{task_number} has overlapping file_scope with task
         #{colliding_task_number} (status: {colliding_task_status}), which is OUTSIDE this
         invocation's task_numbers. Excluding #{task_number} from this cycle — batch
         composition needs human review -- suggest adding #{suggested_predecessor} as a
         dependencies[] entry on #{suggested_dependent} to serialize them. Pass
         --allow-scope-collision for deliberate human-intent bypass (cross-batch only).
       ```
       Ordering rule for `suggested_predecessor`/`suggested_dependent` (the higher task number
       becomes the dependent, the lower becomes the predecessor): identical to, and sourced from,
       `orchestrate-predispatch-review.sh`'s Class D finding (jq computation and rendered string)
       — the two surfaces are one mechanism, printed at two moments (upstream Step 1.5 review, and
       here at the moment of exclusion).
       Additionally (no-override path only), append to `mt_state_file.defer_ledger`:
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

   **Decision record**: base mode does NOT gain a `territory` dispatch key. Its multi-task
   dispatch is genuinely concurrent by construction — the Stage MT-4 BATCHING RULE requires every
   cycle's dispatch batch to be issued as `Agent` tool calls in a single message, so multiple
   agents run concurrently, each with its own `task_dir`, `handoff_path`, and declared
   `file_scope`. A per-dispatch `owned_files` declaration would restate `file_scope` at a second
   grain without adding any detection capability that `file_scope` deferral does not already
   provide for the cross-task file-conflict case it covers.

   **Asymmetry decision (recorded, "recorded not acted on" style, mirroring the hard engine's
   record so the two visibly agree)**: the residual gap is recorded as OPEN, not as covered. The
   `file_scope_collision` and `session_active` branches immediately above operate at ADMISSION
   TIME ONLY — they compare tasks being admitted this cycle against each other and against
   currently-registered live sessions. They are structurally blind to a woken predecessor from an
   EARLIER cycle that already reported but is still live (a self-armed watcher/monitor, or an
   operator resume). That case is not covered by `file_scope` deferral and is not closed by this
   decision. What DOES apply to base mode is the observation half of the contract — the
   STOP-and-report duty on foreign commits, foreign uncommitted modifications, or a running build
   the agent did not start, wired into the base implementation agent independent of any territory
   dispatch key. See `context/patterns/dispatch-report-not-termination.md`.

   **Convergence guard (post-admission empty-dispatch-batch check)**: removing the permanent
   `deferred_self_modifying` exclusion set (this step now only appends to an observation log, per
   Stage MT-1's schema definition) opens a narrow non-convergence mode the old permanent exclusion
   incidentally prevented: `eligible_tasks` can be non-empty every cycle while every member of it
   is deferred by this step's `self_modifying` branch, so the actual dispatch batch is empty and
   nothing runs, cycle after cycle, until `MAX_CYCLES_MT`. **Two independent convergence
   arguments this guard backs up (not replaces)**:
   1. A same-cycle self-mod defer clears on its own once its co-dispatched sibling leaves
      `eligible_tasks` by terminating or failing (a task no longer leaves `eligible_tasks` merely
      by transitioning to an in-flight status — `researching`/`planning` — now that eligibility is
      no longer status-gated; see Stage MT-3 step 3) — which the existing per-cycle loop already
      guarantees for any ordinary case, because the sibling is itself being dispatched and
      processed each cycle.
   2. **Second, independent, per-cycle exit condition that depends on no status transition at
      all**: the designated-candidate tie-breaker inside `orchestrate-batch-admit.sh` admits
      exactly one self-modifying candidate — the lowest task number — on EVERY cycle, regardless
      of how many self-modifying candidates are co-dispatched. This is what actually BOUNDS the
      multiple-self-modifying case: N self-modifying candidates converge to full dispatch in at
      most N cycles by construction, materially stronger than argument 1, which depended on a
      status transition that (pre-tie-breaker) was the only thing standing between this guard and
      `MAX_CYCLES_MT`.

   The guard exists only to BOUND the case where NEITHER natural-clearing mechanism converges in
   time (e.g. a tie-breaker defect, or two self-modifying candidates that keep mutually
   re-qualifying each other as the "colliding sibling" under argument 1 alone). Mechanism:
   maintain `mt_state_file.consecutive_no_dispatch_cycles` (integer, starts at 0). After this
   step's filtering, if the resulting dispatch batch is empty AND `eligible_tasks` (pre-filter) was
   non-empty, increment the counter; on ANY cycle where at least one task actually dispatches,
   reset it to 0. If the counter reaches a small bound (3), break the loop with `partial` status
   and a named diagnostic — rather than silently spinning to `MAX_CYCLES_MT`. **Diagnostic wording
   updated for the designated-candidate tie-breaker (mechanism and 3-cycle bound both unchanged
   above)**: a mutually-colliding self-modifying set is no longer a reachable cause of this guard
   tripping — the tie-breaker always admits exactly one self-modifying candidate per cycle, so N
   self-modifying candidates converge in at most N cycles by construction. The diagnostic instead
   names the causes that remain reachable — e.g. "self-modification gate produced N consecutive
   cycles with zero dispatched tasks; likely a tie-breaker defect (verify
   \$designated_sm_candidate is actually admitting each cycle), a deploy_checkpoint exclusion
   interacting with the batch, or an unexpected file_scope_collision/session_active chain; pass
   --allow-self-modifying only if the tie-breaker itself is confirmed broken" — never an
   instruction to re-run anything solo.

   **Interaction with the task-lock acquire step (Stage MT-4)**: admission runs **before** lock
   acquisition and is a distinct gate — admission compares declared scopes of ALL non-terminal
   tasks in `specs/state.json`, while the lock compares only against currently-held locks.
   Neither replaces the other; both run.

   **Degradation path**: exit 2 from `orchestrate-batch-admit.sh` means state is unavailable
   (missing `jq` or an unreadable `specs/state.json`). In that case, log a loud warning and
   proceed without the check — orchestration cannot function at all under that condition
   regardless of this check, so proceeding is not a silent weakening of the gate.

   **Idle cross-batch overlap advisory** (`idle_overlap_advisory`, NEW in v5): run
   `jq -e '.idle_overlap_advisory'` on **every** verdict this cycle — `admit` verdicts included,
   not only `defer` verdicts. Since v5, a `cross_batch` overlap against an out-of-batch task
   carrying NO execution evidence no longer defers at all; the predicate admits the candidate and
   attaches this field instead of silently dropping the suppressed overlap. This check runs
   OUTSIDE and INDEPENDENTLY of the `.decision == "defer"` filter above — do not nest it inside
   that filter, or every advisory on an `admit` verdict (the common case post-v5) is silently
   skipped. When present, print a distinct ADVISORY line — never folded into an existing WARNING's
   text, because the advisory may name a *different* colliding task than the verdict's own
   subject, so the two lines must stay visually and semantically separate. This fires IN ADDITION
   to any `session_active` or `file_scope_collision` WARNING already logged for the same verdict:
   ```
   [orchestrate] ADVISORY: Task #{task_number} has file_scope overlapping IDLE (status:
     {colliding_task_status}) out-of-batch task #{colliding_task_number} at {overlapping_path};
     not blocking because no execution evidence exists. Add a dependencies[] edge between
     #{task_number} and #{colliding_task_number} if ordering matters.
   ```
   Additionally, append to `mt_state_file.idle_overlap_ledger` (Stage MT-1's schema definition
   above — an admit-side observation log, never an admission gate):
   `{"task": task_number, "colliding_task_number": colliding_task_number, "colliding_task_status": colliding_task_status, "overlapping_path": overlapping_path, "cycle": cycle_count}`.
   This feeds Stage MT-5's `### Admitted (idle overlap advisory)` reporting; it is independent of
   `defer_ledger` and appended regardless of the verdict's own `decision`.

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

**Stage 3.5 is per-task, not per-batch**: each of the three dispatch loops below runs
**Stage 3.5: Dispatch Prep** once INSIDE its own loop body, for each task individually — never
hoisted above the loop and computed once for the whole batch. Different tasks in the same batch
can carry different `task_type`/`description` values, so a single hoisted call would silently
reuse one task's memory/literature context for every sibling in the batch.

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

**Classifier output — REUSED, not re-invoked**: Stage MT-3 step 4.5 already called the shared
handoff-triage classifier once this cycle (to build `--phase-map` for the admission call) and
captured its output as `$mt_classify_ndjson`. This stage reuses that SAME captured NDJSON for
grouping rather than calling `orchestrate-triage-classify.sh` a second time — nothing writes
`specs/state.json` between the two sites within one cycle, so a second read would return
identical output at the cost of a second subprocess invocation. Do not re-invoke the classifier
here.

`jq`-filter `$mt_classify_ndjson` by `.group` into this stage's dispatch buckets: `.group ==
"research"` -> `research_tasks`, `.group == "plan"` -> `plan_tasks`, `.group == "implement"` ->
`implement_tasks`, `.group == "needs_human"` -> `failed_tasks` (mark blocked), and `.group ==
"skip"` or `.group == "terminal"` -> skip (no dispatch). This same captured NDJSON supplies the
pre-dispatch `blockers`/`continuation_context` read for `partial` tasks that the table below
previously only asserted without a spelled-out mechanism — its precedence is **continuation >
blockers > neither** (a task with a valid continuation always dispatches to implement even if
stale blockers are also present; only absence of continuation falls through to the blockers
check).

**Degradation path**: exit 2 from `orchestrate-triage-classify.sh` at Stage MT-3 step 4.5's call
site (this stage no longer calls it) means state is unavailable (missing `jq`, or an unreadable
`specs/state.json`). `$mt_classify_ndjson` is empty in that case. When empty, log a loud warning
here and fall back to the Phase grouping table below, applied inline per task, rather than
silently skipping dispatch for the whole cycle — orchestration must still make forward progress
when the classifier itself cannot run.

**Phase grouping** (documentation of the rule the classifier script transcribes, retained here as
a byte-identical reference table — `scripts/orchestrate-triage-classify.sh` is the executable
source of truth, and THREE artifacts — this table, the classifier script's own header verdict
table, and single-task Stage 4's `partial` sub-state prose above — MUST be changed together,
never independently, and must always agree) — classify each eligible task by its current status:

| Task status | Group | Agent |
|-------------|-------|-------|
| `not_started`, `researching` | research_tasks | `research_agents[task_num]` |
| `researched`, `planning` | plan_tasks | `planner-agent` |
| `planned`, `implementing` | implement_tasks | `implement_agents[task_num]` |
| `partial` with continuation | implement_tasks | `implement_agents[task_num]` |
| `partial` with blockers | failed_tasks (mark blocked) | — |
| `partial` with no handoff | implement_tasks | `implement_agents[task_num]` |
| `blocked`, discharged (all `dependencies[]` completed, no handoff blockers) | the group `previous_status` names (research_tasks/plan_tasks/implement_tasks) | the corresponding agent |
| `blocked`, dependency outstanding or empty `dependencies[]` | skip | — |
| `blocked`, dependency abandoned/expanded, handoff blockers present, or `previous_status` missing | failed_tasks (mark blocked) | — |
| `unknown` | skip | — |

`researching` folds into the SAME group as `not_started`, and `planning` folds into the SAME
group as `researched` — this is the eligibility-not-status-gated convergence: a task stranded in
`researching`/`planning` by a dead prior session's stale lock is no longer routed to `skip`
merely for carrying an in-flight status string; it re-dispatches to the phase its status names.
`unknown` (any status string that is none of the classifier's recognized rows) keeps the old
`skip` behavior unchanged.

`blocked` is NARROWED, not unconditionally folded into `skip`: a `blocked` task that is
DISCHARGED — its `dependencies[]` all reached `status: "completed"` and its handoff carries no
blockers — now converges with single-task Stage 4 on the SAME `previous_status`-routed group for
BOTH engines, rather than diverging. The row that still diverges from single-task Stage 4 (which
always escalates a `blocked` task to `needs_human`/escalation) is narrower than before: only the
NON-discharged case (a dependency still outstanding, or empty `dependencies[]`) still folds into
`skip` here — and that narrower divergence remains intentional, documented, not an oversight
(Decision 1, narrowed by this task): a batch invocation skips a still-blocked task so its
siblings can proceed, whereas the single-task engine has no siblings and so escalates to a human
instead. A dependency stuck at a non-completed terminal status (`abandoned`/`expanded`) or a
handoff carrying unresolved blockers routes to `failed_tasks` (mark blocked) instead, consistent
with this stage's existing `needs_human` -> `failed_tasks` filter above, since both engines agree
`needs_human` for those sub-cases. See the `#### State: blocked` handler above and
`scripts/orchestrate-triage-classify.sh`'s header table and justification paragraph for the full
six-branch discriminator between the discharged case (converged), the narrowed non-discharged
divergence (still documented), and the now-removed `partial` divergence (converged previously).

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
- Read `description=$(jq -r --arg t "$task_num" '.descriptions[$t] // ""' "$mt_state_file")` — the
  per-task description Stage MT-2 captured, consumed both by this loop's existing `$description`
  prompt interpolation and by Stage 3.5 Dispatch Prep below.
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- `skill_preflight_update "$task_num" "research" "${session_id}_${task_num}"`
- Run **Stage 3.5: Dispatch Prep** with `phase=research` for this task (the same single canonical
  procedure defined in Stage 3.5 — do not inline a second copy) to produce `memory_context`,
  `lit_context`, `effort_note`, and `hard_contracts_block`.
- Invoke Agent tool: `subagent_type = research_agents[task_num]` (pass Stage 3.5's `model` (if non-empty) as the Agent tool's `model` parameter), prompt = "Research task $task_num: $description" with `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5 appended, each skipped when empty, context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }`

For each task in `plan_tasks`:
- Read `description=$(jq -r --arg t "$task_num" '.descriptions[$t] // ""' "$mt_state_file")` — the
  per-task description Stage MT-2 captured, consumed by Stage 3.5 Dispatch Prep below.
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- Read `research_artifact` path from `state.json` artifacts (type=report)
- `skill_preflight_update "$task_num" "plan" "${session_id}_${task_num}"`
- Run **Stage 3.5: Dispatch Prep** with `phase=plan` for this task (the same single canonical
  procedure defined in Stage 3.5 — do not inline a second copy) to produce `memory_context`,
  `lit_context`, `effort_note`, and `hard_contracts_block`.
- Invoke Agent tool: `subagent_type = "planner-agent"` (pass Stage 3.5's `model` (if non-empty) as the Agent tool's `model` parameter), prompt = "Create implementation plan for task $task_num" with `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5 appended, each skipped when empty, context = `{ task_number: task_num, task_type, session_id: "${session_id}_${task_num}", research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }`

For each task in `implement_tasks`:
- Read `description=$(jq -r --arg t "$task_num" '.descriptions[$t] // ""' "$mt_state_file")` — the
  per-task description Stage MT-2 captured, consumed by Stage 3.5 Dispatch Prep below.
- Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
- Record the dispatch window AND mint dispatch_seq (see the shared snippet above), and reset this task's `task_transport_error` to `false`
- Read `plan_path` from `task_dir/plans/` (latest .md)
- Read `continuation` from `task_dir/.orchestrator-handoff.json`, resolving **either** accepted
  form — nested `continuation_context.handoff_path` or flat top-level `continuation_path` (same
  dual-form rule as `scripts/orchestrate-triage-classify.sh`'s `continuation_ok` predicate and the
  single-task Stage 4/Stage 5 handlers above) — and **normalizing** the result to
  `{ handoff_path, orchestrator_mode: true }`, or `null` if neither form is present
- `skill_preflight_update "$task_num" "implement" "${session_id}_${task_num}"`
- Run **Stage 3.5: Dispatch Prep** with `phase=implement` for this task (the same single canonical
  procedure defined in Stage 3.5 — do not inline a second copy) to produce `memory_context`,
  `lit_context`, `effort_note`, and `hard_contracts_block`.
- Invoke Agent tool: `subagent_type = implement_agents[task_num]` (pass Stage 3.5's `model` (if non-empty) as the Agent tool's `model` parameter), prompt = "Implement task $task_num following the plan" with `memory_context`, then `lit_context`, then `effort_note`, then `hard_contracts_block` from Stage 3.5 appended, each skipped when empty, context = `{ task_number: task_num, task_type, session_id: "$session_id", orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", continuation_context: continuation, lit_flag, task_dir: task_dir_abs, handoff_path: handoff_path_abs, dispatch_seq: task_dispatch_seq }` (`continuation_context` here is the **normalized** `continuation` value resolved above, never a raw field read; `session_id` here is the bare value deliberately — see the Task-lock acquire invariant above — because `general-implementation-agent`'s per-phase `task-lock.sh heartbeat` call presents this exact field's value against `holder.json`, and a suffixed value would desync the heartbeat from the lock acquired for this task)

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
   `deferred_deploy_checkpoint`, `dispatch_start_ts`, `defer_ledger`, `idle_overlap_ledger`,
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

   Whenever `idle_overlap_ledger` is non-empty, it MUST likewise be reported as its own
   **distinct** category — never folded into any Deferred section (its entries are ADMITS, not
   exclusions), never omitted merely because the batch otherwise succeeded (see
   `commands/orchestrate.md`'s consolidated-output template, `### Admitted (idle overlap
   advisory)` section, for the actual rendering — this stage only supplies the data). It has no
   bearing on `exit_status` — an admitted-with-advisory task is a normal admit and is never
   consulted by branch selection above, exactly like `detected_defects` and
   `verify_deploy_baseline_notices`.
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
  --argjson idle_overlap_ledger "$idle_overlap_ledger" \
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
      "idle_overlap_ledger": $idle_overlap_ledger,
      "detected_defects": $detected_defects,
      "verify_deploy_baseline_notices": $verify_deploy_baseline_notices,
      "cycles_used": $cycles_used,
      "multi_task_mode": true
    }
  }' > "specs/.return-meta-multi-${session_id}.json"
```
The top-level `status` field keeps its existing closed vocabulary (`"implemented"` / `"partial"`
/ `"failed"`) and gains no new value; `forward_progress_violated`, `detected_defects`, and
`idle_overlap_ledger` are carried only inside `metadata`, never as `status` values themselves.

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
  **Residual gap closed**: branch (3), the handoff-present path (Stage 5's `else`), now also
  calls `orchestrate-recover-outcome.sh` — as an ADVISORY EVIDENCE PROBE ONLY, immediately after
  this branch's own PHASES_ZERO_ON_SUCCESS-style corroboration block. The probe reads only
  `evidence_suspect`/`evidence_reason` from a separate `.return-meta.json` read (if any exists
  for this dispatch) and ignores every other field the script returns; it never overrides the
  handoff-derived outcome above, never changes `dispatch_status`, and never drives a status
  transition. On a fired `ARTIFACTS_SHAPE_MISMATCH` signal its sole effect mirrors branch (2)'s
  own arm for the same class: a loud `[orchestrate] EVIDENCE:` stderr notice plus the same
  non-fatal `system-defect-record.sh` call and `append_detected_defect` log entry. Exit 1 and
  exit 2 from the probe (no recoverable `.return-meta.json`, or a usage/jq error) are both
  treated as "no signal available" and are not escalated — a handoff-present dispatch
  legitimately may have nothing left to probe. `skill-orchestrate-hard/SKILL.md` was checked for
  the same structural hole on its own handoff-present branch (its "Evidence corroboration
  (handoff-present branch)" block, structurally identical to this one) and found to have the
  IDENTICAL gap — its existing `orchestrate-recover-outcome.sh` call sites are all on the
  recovered-path branch (this file's branch (2) mirror), not the handoff-present branch. The
  same advisory probe was applied there too, at the corresponding location, so both engines
  visibly agree.
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
