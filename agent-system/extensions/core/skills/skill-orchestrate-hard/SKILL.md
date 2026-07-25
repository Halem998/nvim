---
name: skill-orchestrate-hard
description: Full structural hard-mode orchestration state machine with per-phase dispatch (H1), adversarial verification (H4), convergence policing (H6), territory contracts (H7), and churn detection (H5). Invoke for /orchestrate --hard.
allowed-tools: Agent, Bash, Read
---

# Orchestrate Hard Skill

**IMPORTANT**: This is a FULL STRUCTURAL VARIANT, not a thin wrapper over `skill-orchestrate`.
Loop-level changes (per-phase dispatch, churn detection, adversarial verification gate) cannot
be expressed as prompt injection into the base skill. Maintenance: both skills should evolve
together -- changes to escalation ladder and handoff schema in `skill-orchestrate` should be
reflected here.

Hard-mode additions over base `skill-orchestrate`:
- **H1 Per-Phase Dispatch**: Each implement cycle dispatches exactly one phase, not the whole plan
- **H4 Adversarial Verification Gate**: Research output is verified before plan/implement dispatch
- **H5 Divergence Audit**: Three-strikes on any target triggers a dedicated audit research dispatch
- **H6 Convergence Policing**: Churn detection with per-target counters (defect_claims, sorry_relocations)
- **H7 Territory Contracts**: Territory context informs single-phase dispatch prompts (parallel-wave
  dispatch is disabled — see "Tool Constraints (Pure Dispatcher)" below and Stage 4's Per-Phase
  Dispatch handler; exactly one blocking `Agent` call happens per cycle)

## Tool Constraints (Pure Dispatcher)

<!-- BEGIN 772 pure-dispatcher tool constraints (standalone block; 773 must compose around this,
     not overwrite it) -->

The orchestrator is a pure dispatcher: it reads state, dispatches exactly one implementation
agent per cycle, and reads that agent's handoff. It never edits implementation source, never
runs build/test/compiler tooling, and never reads implementation source files itself. This
section is the human/audit-readable statement of intent backing the frontmatter tool scoping
above (`allowed-tools: Agent, Bash, Read` — `Edit` intentionally absent).

**Permitted Bash**: orchestration bookkeeping only — `jq` reads/writes against state.json and
handoff/loop-guard/churn JSON files, file bookkeeping (`mkdir`, `mv`, `rm`, `ls`), text utilities
(`sort`, `tail`, `grep`, `cat`, `date`, `echo`), and `source .claude/scripts/*.sh` helper
scripts. These are the 12 commands the state machine above actually issues: `jq, mkdir, mv, rm,
ls, sort, tail, grep, cat, date, echo, source`.

**Forbidden Bash Operations**: `lake build` (or any `lake` invocation), `lean` / `lean-lsp` /
`mcp__lean-lsp__*`, `nvim --headless`, `npm` / `pytest` / `cargo test` / `go test`, or ANY
language build/test/compiler/linter tool. These belong exclusively to the dispatched
implementation agent (`$IMPLEMENT_AGENT`) — the orchestrator must never invoke them directly,
even to "verify" a phase before or after dispatch.

**Read allowlist (4 categories)**:
1. `specs/state.json` — task status and metadata.
2. `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` and its siblings
   `.orchestrator-loop-guard` / `.orchestrator-churn-state.json`.
3. `specs/{NNN}_{SLUG}/plans/*.md` and `specs/{NNN}_{SLUG}/reports/*.md`. Plan- and
   report-file access covers exactly three bounded, grep-only uses, none of which is a
   full-file comprehension read: (a) the H4 adversarial-verification grep over reports in
   Stage 4; (b) Stage 4's `### Phase N: ... [STATUS]` next-phase selection grep over the plan;
   and (c) Stage 5's count-only phase-marker recovery grep over the plan, which fires only
   inside the missing/stale-handoff branch and is bounded to ≤10 tokens per recovery event
   (two `grep -c` integers). Any other use of these files is outside the allowlist.
4. `.claude/context/contracts/*.md` and `.claude/docs/architecture/*.md` (this skill's own
   contracts and architecture docs, per Context References above).

**Forbidden Reads**: implementation source of any kind — `lua/**`, `after/**`, or any
per-project source root an `$IMPLEMENT_AGENT` would modify. If the orchestrator finds itself
about to Read a source file to "check" an implementation, that is a signal it has drifted from
pure-dispatcher behavior; the correct action is to dispatch (or re-dispatch) the implementation
agent and read its handoff instead.

<!-- END 772 pure-dispatcher tool constraints -->

## Context References

Architecture documentation (load as needed):
- `.claude/context/contracts/convergence.md` - H6 convergence policing rules
- `.claude/context/contracts/territory.md` - H7 territory contract for parallel dispatch
- `.claude/context/contracts/anti-analysis.md` - H2 contract injected into each implement dispatch
- `.claude/context/contracts/wrap-up.md` - H9 contract for handoff discipline
- `.claude/context/contracts/recovery.md` - Fix-forward recovery ladder referenced by the
  Recovery Discipline contract slot (see CONTRACT SLOTS below)
- `.claude/context/contracts/orchestrator-discipline.md` - Orchestrator-role discipline
  contract governing this state-machine loop itself (Stage 1c preamble, Stage 3c burnout
  circuit-breaker gate) — not the implement dispatches that anti-analysis.md governs
- `.claude/docs/architecture/orchestrate-state-machine.md` - Base state table (reference)
- `.claude/docs/architecture/handoff-schema.md` - Handoff JSON schema

---

## Execution Flow

### Stage 0: Multi-Task Mode Detection

Same as base `skill-orchestrate`. Parse `multi_task_mode`. If true, use base multi-task
stages (per-phase dispatch applies to each task independently within the wave).

```bash
source .claude/scripts/skill-base.sh
multi_task_mode=$(echo "$delegation_context" | jq -r '.multi_task_mode // false')
session_id=$(echo "$delegation_context" | jq -r '.session_id')
focus_prompt=$(echo "$delegation_context" | jq -r '.focus_prompt // ""')
effort_flag=$(echo "$delegation_context" | jq -r '.effort_flag // "hard"')
```

---

### Stage 1: Input Validation

```bash
task_number=$(echo "$delegation_context" | jq -r '.task_context.task_number')
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DATA=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$TASK_DATA" ]; then
  echo "ERROR: Task $task_number not found in state.json" >&2
  exit 1
fi

PROJECT_NAME=$(echo "$TASK_DATA" | jq -r '.project_name')
TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.task_type // "general"')
DESCRIPTION=$(echo "$TASK_DATA" | jq -r '.description // ""')
TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
# Absolute companion. TASK_DIR stays relative for existing consumers; TASK_DIR_ABS is the
# anchor handed to dispatched agents, which cannot know the ambient working directory their
# Write tool will resolve against. SKILL_REPO_ROOT is exported by skill-base.sh.
TASK_DIR_ABS="${TASK_DIR_ABS:-${SKILL_REPO_ROOT:-$(pwd)}/${TASK_DIR}}"
HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
```

---

### Stage 1b: Resolve Hard-Mode Agent Routing

Map task_type to hard-mode research and implementation agents.

```bash
# Default to hard-mode variants; fall back to base agents if hard variant doesn't exist
case "$TASK_TYPE" in
  lean4|lean)
    RESEARCH_AGENT="lean-research-hard-agent"
    IMPLEMENT_AGENT="lean-implementation-hard-agent"
    PLANNER_AGENT="planner-hard-agent"
    # Verify hard variants exist, fall back if not
    [ ! -f ".claude/agents/${RESEARCH_AGENT}.md" ] && RESEARCH_AGENT="lean-research-agent"
    [ ! -f ".claude/agents/${IMPLEMENT_AGENT}.md" ] && IMPLEMENT_AGENT="lean-implementation-agent"
    ;;
  neovim)
    RESEARCH_AGENT="general-research-hard-agent"
    IMPLEMENT_AGENT="general-implementation-hard-agent"
    PLANNER_AGENT="planner-hard-agent"
    ;;
  nix)
    RESEARCH_AGENT="general-research-hard-agent"
    IMPLEMENT_AGENT="general-implementation-hard-agent"
    PLANNER_AGENT="planner-hard-agent"
    ;;
  *)
    RESEARCH_AGENT="general-research-hard-agent"
    IMPLEMENT_AGENT="general-implementation-hard-agent"
    PLANNER_AGENT="planner-hard-agent"
    ;;
esac

# Check routing_hard extension manifests for overrides
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_hard_research=$(jq -r --arg tt "$TASK_TYPE" '.routing_hard.research[$tt] // empty' "$manifest" 2>/dev/null)
    ext_hard_implement=$(jq -r --arg tt "$TASK_TYPE" '.routing_hard.implement[$tt] // empty' "$manifest" 2>/dev/null)
    if [ -n "$ext_hard_research" ]; then
      RESEARCH_AGENT=$(echo "$ext_hard_research" | sed 's/^skill-//' | sed 's/$/-agent/')
    fi
    if [ -n "$ext_hard_implement" ]; then
      IMPLEMENT_AGENT=$(echo "$ext_hard_implement" | sed 's/^skill-//' | sed 's/$/-agent/')
    fi
  fi
done

echo "[hard-orchestrate] Routing: research=$RESEARCH_AGENT, implement=$IMPLEMENT_AGENT, plan=$PLANNER_AGENT"
```

---

### Stage 1c: Orchestrator Discipline Preamble

Runs ONCE per invocation, immediately after Stage 1b and before the loop begins.

`Read .claude/context/contracts/orchestrator-discipline.md`

State (to yourself, in your own transcript) that this session is bound by the orchestrator
discipline contract just read: no inline design/proof analysis, no reading implementation
source, no running builds, no mid-cycle strategy reconsideration without a fresh dispatch; when
a phase cannot complete in a bounded dispatch, the only allowed responses are (a) dispatch a
fresh research/audit agent or (b) escalate via the blocker ladder — never absorb the work
inline. This preamble is the pointer; the enforceable checklist is inlined at every loop
iteration in Stage 3c below.

---

### Stage 2: Loop Guard and Churn State Initialization

Create or read the loop guard file with hard-mode churn counters.

```bash
MAX_CYCLES=13
# Infrastructure-failure counter, separate from the work-cycle budget. See
# context/patterns/infra-failure-discrimination.md. Flat (not scaled with MAX_CYCLES):
# transport flakiness is unrelated to plan size. Value is identical to base — hard mode's
# larger MAX_CYCLES does not change infra tolerance.
MAX_INFRA_FAILURES=3
loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"
# Absolute: must name the same file the dispatched agent was told to write.
handoff_file="${HANDOFF_PATH_ABS}"
churn_file="${TASK_DIR}/.orchestrator-churn-state.json"

mkdir -p "$TASK_DIR"

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  echo "[hard-orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker (task 808). A plain
  # `>` redirect has no O_EXCL semantics, so two racing writers could both take
  # this branch and stomp each other's counters; init-marker's mkdir-gate +
  # tmp-mv payload guarantees exactly one winner. On a lost race (exit 1),
  # degrade to the same resume-read the `if`-branch above performs — reading
  # ALL persisted counters (cycle_count, burnout_signals_this_session, infra_failures), not
  # just one.
  if jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --argjson max_infra_failures "$MAX_INFRA_FAILURES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "current_state": "reading",
      "hard_mode": true,
      "burnout_signals_this_session": 0,
      "infra_failures": 0,
      "max_infra_failures": $max_infra_failures,
      "started": $started,
      "last_updated": $started
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    burnout_signals_this_session=0
    infra_failures=0
  else
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    echo "[hard-orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
  fi
fi

# Initialize or read churn state (per-target churn counters)
if [ -f "$churn_file" ] && jq empty "$churn_file" 2>/dev/null; then
  total_churn=$(jq -r '.total_churn // 0' "$churn_file")
else
  # Fresh start: create churn state atomically via init-marker (task 808); on a
  # lost race (exit 1), resume-read total_churn (matching the `if`-branch above).
  if jq -n '{"total_churn": 0, "target_churn": {}, "adversarial_triggers": 0, "audit_dispatches": 0}' \
    | bash .claude/scripts/task-lock.sh init-marker "$churn_file"; then
    total_churn=0
  else
    total_churn=$(jq -r '.total_churn // 0' "$churn_file")
  fi
fi

blocker_escalation_count=0
MAX_BLOCKER_ESCALATIONS=2
adversarial_verified=false
```

Note: MAX_CYCLES is increased from 5 to 13 in hard mode to accommodate per-phase dispatch.
Each phase requires its own cycle; a 7-phase plan needs ~7 cycles minimum.

---

### Stage 3: State Machine Loop

```bash
while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
```

At the top of each iteration:

**3a. Read current task status**
```bash
current_status=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  specs/state.json)
echo "[hard-orchestrate] Cycle $((cycle_count + 1))/$MAX_CYCLES — status: $current_status"
```

**3b. Update loop guard**
```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

---

### Stage 3c: Burnout Circuit-Breaker Gate

**MANDATORY — runs EVERY loop iteration**, after `current_status` is known (3a) and the loop
guard is persisted (3b), strictly before any Stage 4 dispatch decision. This is not an optional
guideline; it is a gate. Per `.claude/context/contracts/orchestrator-discipline.md`, check all
three self-checks before proceeding to Stage 4:

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

No new artifact type is introduced. The forced dispatch reuses the Stage 4b divergence-audit
dispatch shape, triggered by a burnout signal instead of a churn-count threshold; the forced
escalation reuses Stage 6 directly.

**On any signal firing**, increment the scalar counter in the same 3b-style jq write that
already touches `loop_guard_file`:

```bash
burnout_signals_this_session=$((burnout_signals_this_session + 1))
jq --argjson count "$burnout_signals_this_session" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.burnout_signals_this_session = $count | .last_updated = $updated' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
echo "[hard-orchestrate] H-orch: burnout signal detected (session total: $burnout_signals_this_session) — forcing dispatch/escalation, not inline reasoning" >&2
```

---

### Stage 4: State Handlers

#### State: `not_started`

Dispatch research via hard-mode research agent.

```bash
skill_preflight_update "$task_number" "research" "$session_id"
```

```
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false

Agent tool:
  subagent_type: $RESEARCH_AGENT
  prompt: "Research task $task_number: $DESCRIPTION${focus_prompt:+. Focus: $focus_prompt}"
  delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS}
```

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text describing an error it hit — means
`false`. Then read handoff (Stage 5), which decides whether this cycle is charged.

After Agent tool returns: read handoff (Stage 5). Set `adversarial_verified=false`.
Increment cycle_count.

#### State: `researching`

In-flight. Exit with warning (another session is researching). Same as base skill.

#### State: `researched` — WITH Adversarial Verification Gate (H4)

**HARD MODE DIFFERS FROM BASE**: Before dispatching planning, verify the research report.

```bash
# H4: Adversarial verification gate
if [ "$adversarial_verified" = "false" ]; then
  echo "[hard-orchestrate] H4: Dispatching adversarial verification before planning" >&2
  research_path=$(jq -r --argjson num "$task_number" \
    '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
    specs/state.json)

  if [ -n "$research_path" ] && [ -f "$research_path" ]; then
    # Check if adversarial verification section already exists in report, AND that it contains
    # the required Claim Verification Table header (non-fatal structural strengthening; both
    # checks must pass to skip re-dispatch).
    if grep -q "## Adversarial Self-Verification" "$research_path" && \
       grep -q "| Claim | Source/Counterexample" "$research_path"; then
      echo "[hard-orchestrate] H4: Adversarial verification section with Claim Verification Table found in report. Proceeding to planning." >&2
      adversarial_verified=true
    else
      # Dispatch a focused verification research pass
      # Dispatch window for infra-failure discrimination — see
      # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false

      Agent tool:
        subagent_type: $RESEARCH_AGENT
        prompt: "Adversarial verification pass for task $task_number. Read the research report at $research_path and verify all load-bearing claims. Focus: divergence audit — check for analysis-paralysis signatures, verify source citations, flag uncertain claims."
        delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS}

      # After the Agent tool returns, before Stage 5: judge the tool call's OWN outcome per
      # context/patterns/infra-failure-discrimination.md and set dispatch_was_transport_error=true
      # ONLY if the call itself returned a transport/API-layer error with no subagent-authored
      # text of any kind. Any subagent-authored output means false.
      Increment cycle_count. Loop continues.
    fi
  else
    adversarial_verified=true  # No report to verify; proceed
  fi
fi

# After verification: dispatch planning
if [ "$adversarial_verified" = "true" ]; then
  # Preflight fires ONLY here, strictly inside the adversarial_verified=true branch — never in
  # the H4 verification re-dispatch branch above (which re-dispatches $RESEARCH_AGENT while
  # status is still "researched"; a preflight there would incorrectly regress status to
  # "researching"). This is the single plan-preflight call for the researched handler.
  skill_preflight_update "$task_number" "plan" "$session_id"

  # Dispatch window for infra-failure discrimination — see
  # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
  dispatch_start_ts=$(date -u +%s)
  dispatch_was_transport_error=false

  Agent tool:
    subagent_type: $PLANNER_AGENT
    prompt: "Create hard-mode implementation plan for task $task_number${focus_prompt:+. Focus: $focus_prompt}"
    delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, ...}

  # After the Agent tool returns, before Stage 5: judge the tool call's OWN outcome per
  # context/patterns/infra-failure-discrimination.md and set dispatch_was_transport_error=true
  # ONLY if the call itself returned a transport/API-layer error with no subagent-authored text
  # of any kind. Any subagent-authored output means false. Then read handoff (Stage 5).
fi
```

#### State: `planning`

In-flight. Exit with warning. Same as base skill.

#### State: `planned` or `implementing` — Per-Phase Dispatch (H1)

**HARD MODE DIFFERS FROM BASE**: Dispatch exactly one phase per cycle.

```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)

# Read current handoff to determine phase progress
if [ -f "$handoff_file" ]; then
  phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
  phases_total=$(jq -r '.phases_total // 0' "$handoff_file")
  last_skeleton=$(jq -r '.skeleton // false' "$handoff_file")
else
  phases_completed=0
  phases_total=0
  last_skeleton=false
fi

# === BEGIN 772 Item 5A: heading-scan phase selection + skeleton-exhaustion routing ===
# 772 Item 5A: heading-scan phase selection, replacing the naive
# next_phase=$((phases_completed + 1)) integer increment (could not address N.1/N.2 sub-phase
# headings, sparse numbering, or skeleton-exhaustion). Mirrors
# skill-implementer-hard/SKILL.md Stage 3b's already-landed fix (task 774).
next_phase=""
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" \
    | head -1 \
    | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')
fi

if [ -n "$next_phase" ]; then
  echo "[hard-orchestrate] H1: Per-phase dispatch — phase $next_phase (heading-scan)" >&2

  # Determine territory for this phase (single-phase dispatch, no parallel territory needed —
  # parallel wave dispatch is disabled, see "Tool Constraints (Pure Dispatcher)" above)
  dispatch_context='{
    "task_number": '$task_number',
    "task_type": "'$TASK_TYPE'",
    "session_id": "'$session_id'",
    "orchestrator_mode": true,
    "effort_flag": "hard",
    "plan_path": "'$plan_path'",
    "phase_number": '$next_phase',
    "task_dir": "'$TASK_DIR_ABS'",
    "handoff_path": "'$HANDOFF_PATH_ABS'"
  }'

  # This preflight sits inside the `if [ -n "$next_phase" ]` branch ONLY — never in the
  # elif skeleton-exhaustion branch or the trailing else (all-complete) branch below, neither
  # of which dispatches an implement agent. Its one-time side effects (workflow-active marker
  # write, first-phase [NOT STARTED]->[IN PROGRESS] auto-advance) do not collide with the
  # heading scan above, which already matches "IN PROGRESS" — so phase-1 auto-advance still
  # resolves next_phase=1, and the call is an idempotent no-op on every later phase.
  skill_preflight_update "$task_number" "implement" "$session_id"

  # Dispatch window for infra-failure discrimination — see
  # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
  dispatch_start_ts=$(date -u +%s)
  dispatch_was_transport_error=false

  Agent tool:
    subagent_type: $IMPLEMENT_AGENT
    prompt: "Implement phase $next_phase of task $task_number. $(build_hard_mode_prompt_context)"
    delegation_context: $dispatch_context

  # After the Agent tool returns, before Stage 5: judge the tool call's OWN outcome per
  # context/patterns/infra-failure-discrimination.md and set dispatch_was_transport_error=true
  # ONLY if the call itself returned a transport/API-layer error with no subagent-authored text
  # of any kind. Any subagent-authored output means false. Increment cycle_count (Stage 5).

elif [ "$last_skeleton" = "true" ]; then
  # Skeleton-exhaustion routing: no incomplete phase heading remains AND the last handoff
  # declared skeleton=true. Derive the follow-up task list from the actually-shipped
  # wrap-up.md field `sorry_inventory[].follow_up_task` — NOT the unpopulated top-level
  # `.follow_up_tasks` that skill-implementer-hard's Stage 3b optimistically reads.
  follow_up_tasks=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | join(", ")' "$handoff_file")
  follow_up_count=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | length' "$handoff_file")
  echo "[hard-orchestrate] Skeleton plan exhausted — follow-up tasks pending: {${follow_up_tasks}}" >&2

  # Transition to pr_ready via the centralized status script (never raw-edit state.json).
  # --allow-pr-ready is required here because update-task-status.sh now restricts pr_ready to
  # task_type == "pr"; this skeleton-exhaustion branch is the sanctioned task-type-agnostic
  # exception (it runs for general/lean4/cslib hard-mode tasks, not just type=pr).
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready
  rm -f "$loop_guard_file"
  EXIT (success, pr_ready — skeleton exhausted, ${follow_up_count} follow-up task(s): ${follow_up_tasks})

else
  # No incomplete phase heading remains and the last handoff was NOT a skeleton: all phases are
  # genuinely complete. Do not blindly dispatch phase 1 and do not loop toward MAX_CYCLES here —
  # fall through without a new Agent dispatch; Stage 5 Part B's
  # phases_completed >= phases_total gate performs the actual status transition.
  echo "[hard-orchestrate] No incomplete phase heading remains and last handoff was not a skeleton — deferring to Stage 5 completion gate." >&2
fi
# === END 772 Item 5A: heading-scan phase selection + skeleton-exhaustion routing ===
```

**Hard-mode prompt context** (built inline):
```bash
build_hard_mode_prompt_context() {
  echo "
HARD MODE DISPATCH — CONTRACT SLOTS:

1. Mission: Implement phase $next_phase only. Do not continue past this phase.
2. Anti-Analysis Rules: Read .claude/context/contracts/anti-analysis.md. First file edit within 20% of tool calls.
3. Wrap-up Contract: Write .orchestrator-handoff.json before terminating. Incremental commits.
4. Settled Design Preamble: State the decided design before first tool call.
5. Recovery Discipline: If RED, FIX FORWARD to reach green — never revert/reset/checkout to a prior commit. If a sub-goal is genuinely blocked, land a documented strategic-sorry skeleton (anti-analysis.md) instead of discarding structure. Only if rollback is truly required: snapshot first via 'bash .claude/scripts/git-snapshot.sh $task_number' (pass the task number explicitly; the default mode REVERTS the working tree, which is correct immediately before a rollback -- use --no-revert only when you intend to keep working), then use the smallest revert scope. Full ladder: .claude/context/contracts/recovery.md.

PHASES COMPLETED: $phases_completed of $phases_total
"
}
```

After dispatch: read handoff (Stage 5). Check churn state (Stage 4b). Increment cycle_count.

<!-- BEGIN 772: Parallel Wave Dispatch — DISABLED -->
**Parallel Wave Dispatch: DISABLED.** Parallel-wave dispatch (formerly "optional H7") is
disabled. The Per-Phase Dispatch handler above is the sole implement-dispatch path: the
orchestrator dispatches exactly one phase per cycle and blocks on its return — no
simultaneous/background `Agent` calls. Territory contracts (H7) still inform the single-phase
dispatch context (see "Tool Constraints (Pure Dispatcher)" above), but never fan out into
parallel dispatch.
<!-- END 772: Parallel Wave Dispatch — DISABLED -->

#### State: `partial`

Read handoff to determine sub-state:

```bash
handoff=$(cat "$handoff_file" 2>/dev/null || echo '{}')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
continuation=$(echo "$handoff" | jq -r '.continuation_path // null')
blocker_count=$(echo "$blockers" | jq 'length')
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
```

**Sub-state: continuation available** (continuation != null):

```bash
# Defense-in-depth: status is typically already "implementing" here, so this is
# usually a no-op (update-task-status.sh preflight is idempotent).
skill_preflight_update "$task_number" "implement" "$session_id"
```

Dispatch implement with continuation context (per-phase, H1).

**Sub-state: blockers present** (blocker_count > 0):

Check churn counters BEFORE escalating (Stage 4b may have already handled this).
If not at three-strikes threshold, invoke blocker escalation (Stage 6).

**Sub-state: no handoff, no blockers**:
```bash
echo "[hard-orchestrate] Task $task_number: partial state with no continuation. Cycle limit may have been reached."
EXIT (partial)
```

#### State: `pr_ready`

```bash
echo "[hard-orchestrate] Task $task_number is PR READY — use /merge to submit the pull request."
rm -f "$loop_guard_file"
EXIT (success, pr_ready)
```

#### State: `blocked`

Read blockers from state.json. Invoke blocker escalation (Stage 6).

#### State: `completed`

```bash
echo "[hard-orchestrate] Task $task_number completed."
rm -f "$loop_guard_file"
EXIT (success)
```

---

### Stage 4b: Churn Detection (H6) — After Each Implement Dispatch

After every implement dispatch, check the handoff for churn signatures:

```bash
# Read updated churn state
total_churn=$(jq -r '.total_churn // 0' "$churn_file")

# Check for churn signatures in handoff
handoff_status=$(echo "$handoff" | jq -r '.status')
has_blockers=$(echo "$handoff" | jq '.blockers | length > 0')
phases_delta=$((phases_completed_after - phases_completed_before))

if [ "$handoff_status" = "partial" ] && [ "$has_blockers" = "true" ] && [ "$phases_delta" -eq 0 ]; then
  # No progress: churn signature
  blocker_target=$(echo "$handoff" | jq -r '.blockers[0].target // "unknown"')
  current_target_churn=$(jq -r --arg target "$blocker_target" \
    '.target_churn[$target] // 0' "$churn_file")
  new_target_churn=$((current_target_churn + 1))

  # Update churn counters
  jq --arg target "$blocker_target" \
     --argjson count "$new_target_churn" \
     --argjson total "$((total_churn + 1))" \
    '.target_churn[$target] = $count | .total_churn = $total' \
    "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

  echo "[hard-orchestrate] H6: Churn detected on '$blocker_target' (count: $new_target_churn)" >&2

  # Three-strikes: dispatch divergence audit instead of another implement
  if [ "$new_target_churn" -ge 3 ]; then
    echo "[hard-orchestrate] H5: Three-strikes — dispatching divergence audit for '$blocker_target'" >&2
    verbatim_goal=$(echo "$handoff" | jq -r '.blockers[0].verbatim_goal // ""')

    Agent tool:
      subagent_type: $RESEARCH_AGENT
      prompt: "DIVERGENCE AUDIT for task $task_number. Target: '$blocker_target'. Verbatim goal: '$verbatim_goal'. This target has failed 3 times. Identify root cause of repeated failure. Write a divergence table, postmortem, and corrected target definition."
      delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit $blocker_target"}

    # Reset churn counter for this target after audit
    jq --arg target "$blocker_target" \
      '.target_churn[$target] = 0 | .audit_dispatches += 1' \
      "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

    Increment cycle_count. Loop continues (next iteration will re-dispatch implement with audit findings).
  fi
fi
```

---

### Stage 5: Handoff Reading (after each dispatch)

<!-- BEGIN 772 Item 5B: hard-mode-specific Stage 5 (explicit, not "same as base + sorry log") -->
**HARD MODE DIFFERS FROM BASE**: After every Agent tool invocation, read the orchestrator
handoff to learn the outcome — same drift-detection and artifact-linking behavior as base
`skill-orchestrate` Stage 5, but the `implemented` postflight transition is gated so a single
per-phase handoff (skeleton or not) never flips the whole task to `completed` early.

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
    echo "[hard-orchestrate] ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($stale_window_start)." >&2
    echo "[hard-orchestrate] This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
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
    echo "[hard-orchestrate] ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
    echo "[hard-orchestrate] The correct destination is $handoff_file." >&2
    # Move aside rather than delete: preserves the evidence while ensuring no later
    # cwd-relative read can pick it up.
    mv "$stray" "${TASK_DIR}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
      && echo "[hard-orchestrate] Stray moved into ${TASK_DIR}/ for inspection." >&2 \
      || echo "[hard-orchestrate] WARNING: could not move stray aside; remove it manually before the next cycle." >&2
  fi
done

if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  if [ "$handoff_stale" = "true" ]; then
    echo "[hard-orchestrate] ERROR: Skill did not write a handoff for THIS dispatch (a stale one from an earlier cycle is present)."
  else
    echo "[hard-orchestrate] ERROR: Skill did not write orchestrator handoff."
  fi
  echo "This may mean orchestrator_mode was not propagated correctly, or the handoff was written outside the task directory."

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
    echo "[hard-orchestrate] INFRA FAILURE $infra_failures/$MAX_INFRA_FAILURES — Agent tool transport/API failure with no subagent footprint. Not charged against MAX_CYCLES." >&2
    infra_exempt_cycle=true
  else
    echo "[hard-orchestrate] Missing handoff charged as a genuine work cycle (transport_error=${dispatch_was_transport_error:-false}, meta_touched=$meta_touched)." >&2
  fi

  # ── phase-marker recovery grep (sanctioned narrow exception) ─────────────────
  # PRECONDITION: reachable ONLY inside this missing/stale-handoff branch. Never runs on the
  # normal path where a fresh handoff was read — the context-flatness invariant is untouched
  # there. See "MUST NOT (Context Flatness Constraint) — Recovery exception" for the contract.
  # Same access class as the next-phase selection grep in the planned/implementing handler above
  # — heading lines only, over the same $plan_path — but conditioned on a bad handoff rather
  # than run every cycle.
  # TOKEN BOUND: two `grep -c` calls returning one integer each — ≤10 tokens per recovery event,
  # no matched line content.
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
    echo "[hard-orchestrate] RECOVERY: handoff unusable — plan headings show ${recovered_completed}/${recovered_total} phases [COMPLETED] in ${recovery_plan_path}." >&2

    # Stagnation signal: an identical recovered_completed across consecutive recovery events
    # means dispatches are burning cycles without advancing the plan. Logged, never enforced —
    # MAX_CYCLES remains the only bound on this branch.
    prev_recovered=$(jq -r '.last_recovered_phases_completed // -1' "$loop_guard_file" 2>/dev/null) || prev_recovered=-1
    if [ "$prev_recovered" = "$recovered_completed" ]; then
      echo "[hard-orchestrate] RECOVERY: no phase progress since the previous recovery event (still ${recovered_completed}/${recovered_total}). Dispatches are not advancing the plan." >&2
    fi
    jq --argjson rc "$recovered_completed" --argjson rt "$recovered_total" \
       --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '.last_recovered_phases_completed = $rc
       | .last_recovered_phases_total = $rt
       | .last_updated = $updated' \
      "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  else
    echo "[hard-orchestrate] RECOVERY: no plan file available — phase progress cannot be recovered this cycle." >&2
  fi
else
  handoff=$(cat "$handoff_file")
  dispatch_status=$(echo "$handoff" | jq -r '.status')
  dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
  blockers=$(echo "$handoff" | jq -c '.blockers // []')
  continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
  next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  skeleton=$(echo "$handoff" | jq -r '.skeleton // false')

  # Additional hard-mode handoff fields: sorry inventory, extended with skeleton + follow_up_task
  sorry_inventory=$(echo "$handoff" | jq -c '.sorry_inventory // []')
  if [ "$(echo "$sorry_inventory" | jq 'length')" -gt 0 ]; then
    follow_ups=$(echo "$sorry_inventory" | jq -r '[.[] | .follow_up_task | select(. != null)] | unique | join(", ")')
    echo "[hard-orchestrate] Sorry inventory: $(echo "$sorry_inventory" | jq 'length') sorrys (skeleton=${skeleton}, follow_up_task: {${follow_ups}})" >&2
  fi

  echo "[hard-orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[hard-orchestrate] Phase progress: $phases_completed/$phases_total (skeleton=${skeleton})"

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork) — same as base
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[hard-orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
      invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
    fi
  fi

  # Postflight status update — hard-mode-specific gate on `implemented` (772 Item 5B)
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      # A single per-phase "implemented" handoff (skeleton or not) must NOT flip the whole task
      # to completed. Only transition when every phase is actually done.
      if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
        # `warn`, not `refuse` -- same rationale as the base-mode gate: hard mode's per-phase
        # dispatch discipline already populates phase accounting and this gate is strictly
        # stricter (it requires phases_total > 0, never a 0-pass-through), so the script-side
        # check is a second opinion on independent evidence rather than a veto.
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
      else
        echo "[hard-orchestrate] Phase ${phases_completed}/${phases_total} complete (skeleton=${skeleton}). Continuing." >&2
        # Leave state as `implementing` — Stage 3a re-enters the Per-Phase Dispatch handler
        # (Stage 4, H1) on the next cycle. No postflight status transition happens here.
      fi
      ;;
    *)
      echo "[hard-orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac

  # Artifact linking — same as base: extract artifact path/type from handoff and link in
  # TODO.md + state.json
  handoff_artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
  handoff_artifact_type=$(echo "$handoff" | jq -r '.artifacts[0].type // ""')
  handoff_artifact_summary=$(echo "$handoff" | jq -r '.artifacts[0].summary // ""')
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
fi

# Increment cycle_count — skipped ONLY for a corroborated infra failure, which is separately
# bounded by MAX_INFRA_FAILURES (Stage 7). Every iteration charges exactly one of the two
# counters; both are capped, so worst-case iterations per invocation are
# MAX_CYCLES + MAX_INFRA_FAILURES.
if [ "$infra_exempt_cycle" = "true" ]; then
  echo "[hard-orchestrate] Cycle not charged (infra failure). cycle_count remains $cycle_count/$MAX_CYCLES." >&2
else
  cycle_count=$((cycle_count + 1))
fi
```
<!-- END 772 Item 5B: hard-mode-specific Stage 5 -->

---

### Stage 6: Blocker Escalation

Extended escalation ladder (same as base + audit step):

```
1. Standard dispatch (handled in Stage 4)
2. On 3 churn strikes: Divergence audit (Stage 4b, H5)
3. After audit: Revised dispatch with audit findings
4. If still blocked: AskUserQuestion for architectural decision
5. If 2nd authorization fails: Mark phase BLOCKED, continue with other phases
```

When escalation is invoked:

```bash
if [ "$blocker_escalation_count" -lt "$MAX_BLOCKER_ESCALATIONS" ]; then
  blocker_escalation_count=$((blocker_escalation_count + 1))

  # Escalate to blocker research
  blocker_desc=$(echo "$handoff" | jq -r '.blockers[0].verbatim_goal // "Unspecified blocker"')
  Agent tool:
    subagent_type: $RESEARCH_AGENT
    prompt: "Research blocker for task $task_number: $blocker_desc. Find a concrete resolution path."
    delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "blocker research"}

  Increment cycle_count.
else
  # Cap reached: AskUserQuestion for architectural decision
  AskUserQuestion:
    question: "Task $task_number is repeatedly blocked on: $blocker_desc. Choose: (a) Accept proposed pivot, (b) Proceed with current approach, (c) Abandon this path"
    options: ["(a) Accept pivot", "(b) Proceed current", "(c) Abandon"]
fi
```

---

### Stage 7: Terminal Conditions

```bash
# MAX_INFRA_FAILURES reached — repeated transport/API failures, distinct from work-budget
# exhaustion. This is the explicit bound on the exemption path: an infra-exempt cycle does not
# increment cycle_count, so worst-case iterations per invocation are
# MAX_CYCLES + MAX_INFRA_FAILURES = 16.
if [ "${infra_failures:-0}" -ge "$MAX_INFRA_FAILURES" ]; then
  echo "[hard-orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number — repeated Agent tool transport/API failures with no subagent execution."
  echo "This is a connectivity problem, not a work-budget problem: cycle_count is still $cycle_count/$MAX_CYCLES."
  echo "Run /orchestrate $task_number --hard again once connectivity is confirmed."
  EXIT (partial, cycle_count=$cycle_count)
fi

# MAX_CYCLES reached
if [ "$cycle_count" -ge "$MAX_CYCLES" ]; then
  echo "[hard-orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
  echo "Phases completed: $phases_completed of $phases_total"
  echo "Run /orchestrate $task_number --hard to resume, or /implement $task_number --hard for manual phase dispatch."
  EXIT (partial, cycle_count=$MAX_CYCLES)
fi
```

---

### Stage 8: Cleanup

```bash
rm -f "$loop_guard_file"
rm -f "$churn_file"
```

(Only on successful completion. Leave loop guard and churn state on partial for resume.)

---

## Multi-Task Mode

Same as base `skill-orchestrate` multi-task stages (MT-1 through MT-5). Hard-mode applies
to each individual task in the wave — they each use the per-phase dispatch H1 loop above.

---

## Key Differences from skill-orchestrate

| Feature | skill-orchestrate | skill-orchestrate-hard |
|---------|------------------|----------------------|
| MAX_CYCLES | 5 | 13 |
| Implement dispatch | Whole plan per cycle | One phase per cycle (H1) |
| Adversarial gate | None | Research verified before plan (H4) |
| Churn detection | None | Per-target counters (H6) |
| Three-strikes | None | Audit dispatch at 3 (H5) |
| Parallel dispatch | None | Disabled — single blocking phase per cycle (772) |
| Agents used | Base agents | Hard-mode agents |
| Prompt construction | Simple | Contract-slot injection |
