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
   and (c) Stage 5's count-only phase-marker recovery grep over the plan, bounded to ≤10 tokens
   per recovery event (two `grep -c` integers) and fired from exactly three bounded uses: the
   missing/stale-handoff branch's own diagnostic-only recovery grep (still the raw inline
   two-`grep -c` idiom directly — it has no recoverable `dispatch_status` to corroborate
   against, so it never calls the shared function below); the recovered=true branch's
   evidence-corroboration call, fired only when return-meta recovery's own
   `evidence_suspect`/`evidence_reason` report `PHASES_ZERO_ON_SUCCESS` for a claimed
   `implemented` status; and the handoff-present branch's corroboration call, which fires only
   when the handoff itself reports `dispatch_status = "implemented"` AND `phases_total -eq 0` —
   never on the normal path of a fresh handoff with populated phase accounting. The latter two
   uses both call the SAME shared `skill_corroborate_phase_counts` (`scripts/skill-base.sh`),
   which performs the same two `grep -c` calls inside itself rather than inline — the single
   anchor both uses (and their base-mode and multi-task mirrors) now share, in the same way
   `scripts/lib/phase-heading-patterns.sh` is the single grammar anchor every phase-heading
   consumer sources rather than re-deriving. Any other use of these files is outside the
   allowlist. (The recovered=true branch's site also carries a sibling `elif` arm on
   `evidence_reason="ARTIFACTS_SHAPE_MISMATCH"` — Deliverable 2(a), a non-fatal
   `system-defect-record.sh` consumer call. It shares the `recovered=true` precondition but
   performs no `grep -c` of any kind and calls no new Read, so it is not a fifth bounded use of
   this allowlist.)
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
# Defect B: explicit, operator-typed budget-continuation override. Parsed here (never inferred
# from session_id, mtime, or any automatic signal) so Stage 2's MAX_CYCLES exhaustion branch can
# read it. See Stage 2 below for the full override mechanism and its rationale.
continue_budget_flag=$(echo "$delegation_context" | jq -r '.continue_budget // false')
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

Map task_type to hard-mode research, plan, and implementation agents via the single canonical
agent resolver, `command-route-agent.sh` — the same script `skill-orchestrate`'s (base) Stage 1b
calls, sourced here with effort `"hard"` and hard-mode defaults. Resolution runs against each
manifest's `routing_agents_hard` declarations; a miss falls through directly to the
caller-supplied hard-mode default below (NOT to the standard, non-hard `routing_agents` block),
preserving today's default-to-general-hard-agent behavior exactly. The two engines now differ
only in the effort argument and these three defaults — no case table, no manifest loop, no sed
derivation.

```bash
source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-hard-agent" "hard"
RESEARCH_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "plan" "$TASK_TYPE" "planner-hard-agent" "hard"
PLANNER_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "implement" "$TASK_TYPE" "general-implementation-hard-agent" "hard"
IMPLEMENT_AGENT="$AGENT_NAME"

echo "[hard-orchestrate] Routing: research=$RESEARCH_AGENT, implement=$IMPLEMENT_AGENT, plan=$PLANNER_AGENT"
```

---

### Dispatch Context Anchor Invariant

Every `delegation_context` in this file states `orchestrator_mode` explicitly, giving two
checkable properties: (I1) no site relies on the reader's `// "false"` default — the key is
always present, `true` or `false`; (I2) `task_dir` / `handoff_path` are present on a context if
and only if it declares `orchestrator_mode: true`. The one indirection: `delegation_context:
$dispatch_context` (Stage 4, per-phase implement dispatch) refers to the JSON literal built
immediately above it — that literal, not the reference line, carries `orchestrator_mode` and the
anchors. `orchestrator_mode` is dual-consumer (handoff-write gate plus the literature Stage 4a
autonomy gate — see the Dual-Consumer Note in `docs/architecture/handoff-schema.md`), so a future
edit here weighs both; the `false` sub-dispatches (H4 verification, H5 divergence audit, Stage 6
blocker research) pass no `lit_flag` at all, leaving the literature path disabled there regardless.

```bash
F=agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
# Anchored at line-start (after leading whitespace) so this check does not self-match its own
# quoted grep patterns below — an unanchored 'delegation_context: {' pattern matches its own
# source line once embedded in this same file.
PAT='^[[:space:]]*delegation_context: \{'
[ "$(grep -cE "$PAT" "$F")" = "$(grep -cE "$PAT.*orchestrator_mode" "$F")" ] && echo "I1 holds"
grep -E "$PAT.*orchestrator_mode: true" "$F" | grep -qv 'task_dir' && echo "I2 VIOLATED (true without task_dir)" || echo "I2 holds (true sites)"
grep -E "$PAT.*orchestrator_mode: false" "$F" | grep -q 'task_dir\|handoff_path' && echo "I2 VIOLATED (false with anchor)" || echo "I2 holds (false sites)"
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

**Both `.orchestrator-loop-guard` and `.orchestrator-churn-state.json` are ephemeral, gitignored,
and never committed.** Neither has a freshness check on read — the resume branch below trusts any
syntactically valid file at these paths unconditionally, with no `session_id` or mtime comparison
against the current dispatch. A git-restored copy of either would silently resume a wrong cycle
count, burnout-signal count, or churn history. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

```bash
MAX_CYCLES=13
# Single shared implementation, orchestrate-loop-guard-init.sh — see that script's header for
# the full contract. Same call skill-orchestrate/SKILL.md's Stage 2 makes for its own
# genuinely-common portion — everything else in this stage (MAX_CYCLES's own value, the
# hard-only loop-guard-staleness detector immediately below, churn-state init) stays per-engine.
loop_guard_init_json=$(bash .claude/scripts/orchestrate-loop-guard-init.sh "$TASK_DIR" "${HANDOFF_PATH_ABS}")
loop_guard_file=$(echo "$loop_guard_init_json" | jq -r '.loop_guard_file')
handoff_file=$(echo "$loop_guard_init_json" | jq -r '.handoff_file')
MAX_INFRA_FAILURES=$(echo "$loop_guard_init_json" | jq -r '.max_infra_failures')
churn_file="${TASK_DIR}/.orchestrator-churn-state.json"

# Live plan-lineage reference for the loop-guard-staleness detector (Stage 2, below) and the
# guard's own `plan_version` schema field. Safe when plans/ does not exist yet (task in
# researching/planning status): the ls glob then matches nothing, `sort -V | tail -1` on empty
# input yields an empty string, and `basename ""` also yields an empty string here, so the
# explicit `:-none` fallback is required -- never treat an absent plans/ directory as evidence of
# staleness.
current_plan_version=$(basename "$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
current_plan_version="${current_plan_version:-none}"

# --- loop-guard-staleness:begin ---
# Operational-staleness detector: a genuinely-present, never-git-touched guard that is simply
# superseded or old on disk (distinct from the git-restoration hazard the ephemeral/gitignored
# classification protects against). Three OR-combined signals; any one tripping is sufficient.
# See context/standards/orchestrator-runtime-files.md's "Operational staleness: a second,
# orthogonal freshness axis" for the full policy, thresholds, and the anti-session_id defense.
# No task-lock.sh dependency in this region -- it only reads, decides, and archives (mv), so it
# is directly executable in a fixture harness. The pre-existing `if [ -f "$loop_guard_file" ]`
# block immediately below this region, and the churn-state block below that, are left completely
# unmodified: once a stale guard/churn file is mv'd aside, `[ -f ]` is false and each falls
# through to its own existing fresh-init branch naturally, at cycle_count=0 / total_churn=0.
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
    echo "[hard-orchestrate] ERROR: STALE LOOP GUARD — ${stale_reason}Archived to ${stale_guard_dest} for inspection; reinitializing fresh guard at cycle 0." >&2
    if mv "$loop_guard_file" "$stale_guard_dest" 2>/dev/null; then
      :
    else
      echo "[hard-orchestrate] WARNING: could not move stale guard aside to ${stale_guard_dest}; ${loop_guard_file} is still in place and must be removed manually before the next cycle." >&2
    fi
    # Co-archive the churn-state file under the loop guard's inherited verdict (not an
    # independently-derived detector) and the same timestamp suffix, so the two archives are
    # correlatable. Only when it exists -- never create an empty churn archive.
    if [ -f "$churn_file" ]; then
      stale_churn_dest="${TASK_DIR}/.stale-churn-state-${stale_ts}.json"
      echo "[hard-orchestrate] Co-archiving churn state to ${stale_churn_dest} (inherits the loop guard's stale verdict)." >&2
      if mv "$churn_file" "$stale_churn_dest" 2>/dev/null; then
        :
      else
        echo "[hard-orchestrate] WARNING: could not move stale churn state aside to ${stale_churn_dest}; ${churn_file} is still in place and must be removed manually before the next cycle." >&2
      fi
    fi
  fi
fi
# --- loop-guard-staleness:end ---

# --- budget-continuation-override:begin ---
# Defect B: cycle_count is a per-task, CUMULATIVE budget that survives re-invocation BY DESIGN --
# it is deliberately NOT reset on a new session_id, because that would let an operator silently
# bypass MAX_CYCLES by simply re-invoking /orchestrate --hard. test-session-runtime-files.sh
# Case 3 is the regression protecting this decision; this override must never disturb it. The
# override below is the sanctioned, explicit, loudly-logged escape hatch for a genuinely
# exhausted budget -- never automatic, never session_id-gated, never inferred from mtime.
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  peek_cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  if [ "$peek_cycle_count" -ge "$MAX_CYCLES" ]; then
    if [ "$continue_budget_flag" = "true" ]; then
      exhaust_ts=$(date -u +%s)
      exhausted_guard_dest="${TASK_DIR}/.exhausted-loop-guard-${exhaust_ts}.json"
      echo "[hard-orchestrate] BUDGET EXHAUSTED (cycle_count=${peek_cycle_count}/${MAX_CYCLES}) — --continue-budget authorized a fresh budget. Archiving exhausted guard to ${exhausted_guard_dest} for auditability, reinitializing at cycle_count=0 with cross-invocation history fields (dispatch_seq_counter, detected_defects, plan_version) preserved." >&2
      if cp "$loop_guard_file" "$exhausted_guard_dest" 2>/dev/null; then
        # Reinit IN PLACE from the just-archived copy: reset only cycle_count, never wipe
        # dispatch_seq_counter (must never repeat a value within this task -- see
        # context/patterns/dispatch-report-not-termination.md) or the detected_defects
        # observation log.
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$exhausted_guard_dest" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      else
        echo "[hard-orchestrate] WARNING: could not archive exhausted guard to ${exhausted_guard_dest}; proceeding without archiving (cycle_count reset in place)." >&2
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      fi
    else
      echo "[hard-orchestrate] ERROR: work-cycle budget exhausted (cycle_count=${peek_cycle_count}/${MAX_CYCLES}). This is a budget limit, not an error condition -- the task's plan may still have incomplete phases." >&2
      echo "[hard-orchestrate] To continue this task's work, explicitly authorize a fresh budget: /orchestrate ${task_number} --hard --continue-budget" >&2
      exit 1
    fi
  fi
fi
# --- budget-continuation-override:end ---

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  # System-defect observation log for this run. Its entry shape, unconditional-append rule,
  # notice format, and MUST-NOTs are defined ONCE in `skill-orchestrate/SKILL.md`'s Stage MT-1
  # `detected_defects` declaration and are deliberately not restated here, so the base and
  # hard engines cannot drift apart. `// []` is the forward-compatible read for a guard file
  # written before the field existed, matching the `// 0` idiom above.
  detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
  # dispatch_seq_counter: orchestrator-minted per-dispatch identity (Defect A). `// 0`
  # forward-compatible read, matching cycle_count's own idiom — a guard written before this
  # field existed resumes at 0, never repeating a value already minted this task since the
  # counter only ever increments (see mint_dispatch_seq() below).
  dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
  echo "[hard-orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker. A plain
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
    --arg plan_version "$current_plan_version" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "current_state": "reading",
      "hard_mode": true,
      "burnout_signals_this_session": 0,
      "infra_failures": 0,
      "max_infra_failures": $max_infra_failures,
      "detected_defects": [],
      "started": $started,
      "last_updated": $started,
      "plan_version": $plan_version,
      "dispatch_seq_counter": 0
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    burnout_signals_this_session=0
    infra_failures=0
    detected_defects='[]'
    dispatch_seq_counter=0
  else
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
    dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
    echo "[hard-orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
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

# Initialize or read churn state (per-target churn counters)
if [ -f "$churn_file" ] && jq empty "$churn_file" 2>/dev/null; then
  total_churn=$(jq -r '.total_churn // 0' "$churn_file")
  # Observational-only session_id tracking (NEVER a gate — identical rationale to the loop
  # guard's Stage 2 treatment above: SESSION_ID is regenerated per /orchestrate invocation, while
  # this file is explicitly designed to survive across conversational turns. The real same-task
  # concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not session_id equality).
  churn_session_id=$(jq -r '.session_id // ""' "$churn_file")
  if [ -n "$churn_session_id" ] && [ "$churn_session_id" != "$session_id" ]; then
    echo "[hard-orchestrate] INFO: churn state was last written by a different session_id ('${churn_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
  fi
else
  # Fresh start: create churn state atomically via init-marker; on a
  # lost race (exit 1), resume-read total_churn (matching the `if`-branch above).
  if jq -n --arg session_id "$session_id" \
    '{"session_id": $session_id, "total_churn": 0, "target_churn": {}, "adversarial_triggers": 0, "audit_dispatches": 0}' \
    | bash .claude/scripts/task-lock.sh init-marker "$churn_file"; then
    total_churn=0
  else
    total_churn=$(jq -r '.total_churn // 0' "$churn_file")
  fi
fi

# Blocker escalation counter (reset each /orchestrate invocation) — from the same shared
# orchestrate-loop-guard-init.sh call above.
blocker_escalation_count=$(echo "$loop_guard_init_json" | jq -r '.blocker_escalation_count')
MAX_BLOCKER_ESCALATIONS=$(echo "$loop_guard_init_json" | jq -r '.max_blocker_escalations')
adversarial_verified=false
```

Note: MAX_CYCLES is increased from 5 to 13 in hard mode to accommodate per-phase dispatch.
Each phase requires its own cycle; a 7-phase plan needs ~7 cycles minimum.

**On the `loop-guard-staleness` region above**: it runs before the pre-existing
`if [ -f "$loop_guard_file" ] ...` resume branch and only ever archives a stale guard aside — it
never edits that branch or the churn-state block that follows it. When a stale guard is `mv`'d
away, `[ -f "$loop_guard_file" ]` becomes false and the untouched fresh-init `else` branch runs
naturally, seeding a new guard at `cycle_count: 0`; the same fall-through applies to the
churn-state block if its file was co-archived. See
`context/standards/orchestrator-runtime-files.md`'s "Operational staleness: a second, orthogonal
freshness axis" for the full policy this region implements.

**On the `budget-continuation-override` region above (Defect B)**: unlike the staleness region,
this one does NOT fall through to the pre-existing fresh-init branch — it rewrites the SAME
`loop_guard_file` in place (via the archived copy), specifically so `dispatch_seq_counter` and
`detected_defects` are carried forward rather than reset to their fresh-init defaults. Falling
through to fresh-init here would let `dispatch_seq` repeat a value already minted earlier in this
task, violating the "never repeats a value within a task" invariant Defect A's fix depends on.

**Asymmetry decision (recorded, not merely implied)**: budget exhaustion is deliberately NOT
folded into the 3-signal `loop-guard-staleness` detector above as a fourth signal. That
detector's premise is "this guard's CONTENT has gone stale/superseded" (a schema/lineage/age
mismatch); an exhausted guard is neither stale nor superseded — its `cycle_count` is completely
accurate, it has simply reached the budget ceiling. Conflating the two would make an accurate,
current guard look like a data-integrity problem rather than what it actually is: a budget limit
requiring an explicit human decision to lift. Whether base mode should ever gain the general
3-signal staleness detector at all is a SEPARATE, undecided question, out of scope for this
override and not settled by adding it here.

**Territory asymmetry acknowledgment (mirroring the base engine's record so the two visibly
agree)**: this engine carries the `territory` dispatch key documented at Stage 4's dispatch
context (`owned_files`/`read_only_files`/`forbidden_files`/`concurrency_note`) because its
per-phase dispatch is single-agent-at-a-time; the base engine's multi-task dispatch is instead
genuinely concurrent by construction and deliberately does NOT gain a `territory` key. See
`skill-orchestrate/SKILL.md`'s own Decision record / Asymmetry decision pair, adjacent to its
Stage MT-3 `file_scope_collision`/`session_active` deferral branches, for the full reasoning and
the named open gap (admission-time-only `file_scope` deferral is blind to a woken predecessor
from an earlier cycle).

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
# Recompute the latest-plan basename at every cycle (not just at fresh-init) so a plan revision
# landing mid-run is absorbed into the guard rather than left stale until the next resume — see
# the loop-guard-staleness detector in Stage 2, which compares against exactly this field.
current_plan_version=$(basename "$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
current_plan_version="${current_plan_version:-none}"
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
   --arg plan_version "$current_plan_version" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .plan_version = $plan_version' \
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
dispatch_seq=$(mint_dispatch_seq)

Agent tool:
  subagent_type: $RESEARCH_AGENT
  prompt: "Research task $task_number: $DESCRIPTION${focus_prompt:+. Focus: $focus_prompt}"
  delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq}
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
    # a claim-verification table matched by SHAPE, not by a fixed header string (non-fatal
    # structural strengthening; both checks must pass to skip re-dispatch). Shape: a table-cell
    # containing the word "claim" immediately followed by a cell containing both "source" and
    # "counterexample" (case- and spacing-insensitive, tolerant of extra columns). Both known
    # passing formats match: the canonical `| Claim | Source/Counterexample | ... |` header and
    # the observed `| # | Claim under attack | Source / counterexample | Outcome |` header. An
    # unrelated table does not match.
    if grep -q "## Adversarial Self-Verification" "$research_path" && \
       grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"; then
      echo "[hard-orchestrate] H4: Adversarial verification section with Claim Verification Table found in report. Proceeding to planning." >&2
      adversarial_verified=true
    else
      # Dispatch a focused verification research pass
      # Dispatch window for infra-failure discrimination — see
      # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false
      # Minted for consistency (every dispatch_start_ts site mints adjacent to it) even though
      # this dispatch never writes .orchestrator-handoff.json and so has nothing to inject
      # dispatch_seq into below -- see the no-handoff-path rationale in the comment immediately
      # following.
      dispatch_seq=$(mint_dispatch_seq)

      # $RESEARCH_AGENT never writes .orchestrator-handoff.json, per the Stage 3.6 "Scoping
      # Decision" in general-research-agent.md / general-research-hard-agent.md and the Handoff
      # Writers table in docs/architecture/handoff-schema.md, so the anchor here was unread —
      # removed rather than kept. Note: `handoff_path` in a research agent's own returned
      # `partial_progress` names its research-shaped `handoffs/research-handoff-*.md`, not this
      # orchestrator anchor; passing the orchestrator anchor here invited exactly that
      # conflation.
      Agent tool:
        subagent_type: $RESEARCH_AGENT
        prompt: "Adversarial verification pass for task $task_number. Read the research report at $research_path and verify all load-bearing claims. Focus: divergence audit — check for analysis-paralysis signatures, verify source citations, flag uncertain claims."
        delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", orchestrator_mode: false}

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
  dispatch_seq=$(mint_dispatch_seq)

  Agent tool:
    subagent_type: $PLANNER_AGENT
    prompt: "Create hard-mode implementation plan for task $task_number${focus_prompt:+. Focus: $focus_prompt}"
    delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq, ...}

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
# skill-implementer-hard/SKILL.md Stage 3b's already-landed fix.
#
# Orchestration-loop posture: unlike a leaf worker's precondition check, this skill IS the
# long-running orchestration loop, with its own established terminal-condition vocabulary
# (`EXIT (partial, ...)` / `EXIT (success, ...)`, used at multiple other points in this file). A
# raw `exit 1` here would be a nonlocal jump out of the whole `/orchestrate --hard` run with no
# bookkeeping and no message shaped like this file's other terminal paths -- worse than the bug it
# would replace. The inconclusive case below therefore routes to this file's own
# `EXIT (partial, ...)` convention as a distinct FIRST branch, so it can never be mistaken for
# skeleton-exhaustion or genuine full completion (both of which are false claims when the real
# cause is a malformed plan).
next_phase=""
phase_scan_inconclusive=false
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than re-derived
  # inline. Uses the library's OPEN alternation (NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED) and
  # extract_phase_number so a non-conforming heading is never silently mis-selected or truncated.
  . .claude/scripts/lib/phase-heading-patterns.sh
  # --- resume-scan-conformance-gate:begin ---
  # Whole-file conformance check BEFORE the filtered scan below. PHASE_HEADING_ERE admits
  # conforming headings only, so a non-conforming heading is not merely unmatched by that grep --
  # it is INVISIBLE to it, and the scan would silently select the next conforming OPEN heading
  # instead, dispatching out of order on top of unfinished work. has_nonconforming_phase_headings
  # is the required boolean predicate; the `nonconforming_phase_headings | grep -q .` pipe form is
  # forbidden (unsafe under pipefail).
  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "orchestrate-hard-next-phase" || true
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
  echo "[hard-orchestrate] H1: non-conforming phase heading(s) in $plan_path — the filtered resume scan cannot see them, so the true next phase is UNKNOWN." >&2
  echo "[hard-orchestrate] Refusing to dispatch, and refusing to claim skeleton-exhaustion or completion. Fix the plan's heading grammar (see plan-format.md's canonical phase-heading shape) and re-run." >&2
  EXIT (partial, non-conforming phase heading — next phase unknown)

elif [ -n "$next_phase" ]; then
  # --- marker-handoff-crosscheck:begin ---
  # Defect 6: an interrupted dispatch can leave the plan's phase markers ahead of the handoff
  # (marker claims [COMPLETED], handoff's own phases_completed has not confirmed it yet -- see
  # context/contracts/wrap-up.md's "Ordering: Handoff Write Precedes Marker Promotion"). Compare
  # the marker-derived completed count against the handoff's own phases_completed (already read
  # above) before trusting the heading scan's next_phase selection. The `has_nonconforming_phase_headings`
  # ordering obligation is already satisfied here by construction: this elif branch is reached
  # only after that check already ran (and passed) earlier in this same block.
  marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path" 2>/dev/null || echo 0)
  if [ "$marker_completed_count" != "$phases_completed" ]; then
    echo "[hard-orchestrate] H1: MARKER/HANDOFF MISMATCH — plan file shows ${marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but the handoff's own phases_completed=${phases_completed}. Not dispatching the successor over unconfirmed work." >&2
    if [ "$marker_completed_count" -gt "$phases_completed" ]; then
      # Downgrade the specific disputed phase heading -- the (phases_completed + 1)-th
      # [COMPLETED]/[COMPLETED WITH EXCLUSIONS] heading by order of appearance -- to [PARTIAL],
      # matching the manual downgrade the operator performed in the observed incident.
      disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$plan_path" | sed -n "$((phases_completed + 1))p")
      if [ -n "$disputed_line" ]; then
        disputed_linenum="${disputed_line%%:*}"
        disputed_text="${disputed_line#*:}"
        echo "[hard-orchestrate] H1: downgrading disputed phase heading to [PARTIAL]: ${disputed_text}" >&2
        sed -i -E "${disputed_linenum}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "$plan_path"
      fi
    fi
    EXIT (partial, marker/handoff phases_completed mismatch — plan=${marker_completed_count} handoff=${phases_completed})
  fi
  # --- marker-handoff-crosscheck:end ---

  echo "[hard-orchestrate] H1: Per-phase dispatch — phase $next_phase (heading-scan)" >&2

  # Mint this phase's dispatch identity (Defect A) before building dispatch_context, so the
  # per-phase JSON literal below can carry it inline alongside handoff_path, matching this
  # file's other three dispatch sites.
  dispatch_seq=$(mint_dispatch_seq)

  # Territory (H7, Defect 5): no cross-agent FILE conflict exists within this orchestrator's OWN
  # dispatches (parallel wave dispatch is disabled — see "Tool Constraints (Pure Dispatcher)"
  # above, exactly one blocking Agent call per cycle). Defect 5 is a DIFFERENT concern: a woken
  # PREDECESSOR dispatch (see context/patterns/dispatch-report-not-termination.md) resuming
  # outside this orchestrator's own control flow. The orchestrator does not parse the plan's
  # "Files to modify" list itself (that would expand the Read allowlist in "Tool Constraints"
  # above beyond its enumerated bounded uses) — it points the agent at the plan/phase location it
  # already has in this same context, and the agent (unrestricted in what it may read) derives
  # its own owned_files from the phase's own section.
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
    "territory": {
      "owned_files": "derive from plan_path'\''s Phase '$next_phase' \"Files to modify\" list",
      "read_only_files": [],
      "forbidden_files": [],
      "concurrency_note": "This declaration asserts only which files THIS dispatch owns. It does NOT assert exclusive access -- a still-live predecessor may exist. If you observe foreign commits, foreign uncommitted modifications, or a running build you did not start, STOP and report it rather than proceeding or dismissing it. See context/contracts/territory.md and context/patterns/dispatch-report-not-termination.md."
    }
  }'

  # This preflight sits inside the `if [ -n "$next_phase" ]` branch ONLY — never in the
  # elif skeleton-exhaustion branch or the trailing else (all-complete) branch below, neither
  # of which dispatches an implement agent. Its remaining side effects are the workflow-active
  # marker write and the plan-level [STATUS] stamp (via update-plan-status.sh) — it writes NO
  # per-phase marker, on any path: the dispatched implementation agent owns every per-phase
  # [IN PROGRESS]/[COMPLETED] transition directly via its own explicit phase-status calls, as
  # the first action of processing whichever phase it actually works on (see Stage 4A of
  # general-implementation-hard-agent). This is deliberate, not an oversight — a prior
  # convenience here independently re-derived "the first NOT STARTED phase" with its own
  # narrower scan and could advance a phase this dispatch never touched, diverging from the
  # wider `next_phase` selection above whenever the dispatched phase was itself a resumed
  # IN PROGRESS/PARTIAL/BLOCKED one; the convenience was deleted rather than gated.
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

  # This postflight call is routed through the pr_ready target argument (never raw-edit
  # state.json). --allow-pr-ready is required here because update-task-status.sh now restricts
  # pr_ready to task_type == "pr" unless explicitly overridden; this skeleton-exhaustion branch is
  # the sanctioned task-type-agnostic exception to that guard (it runs for general/lean4/cslib
  # hard-mode tasks, not just type=pr). Because this call is a postflight operation,
  # update-task-status.sh's own postflight:pr_ready -> completed mapping (see
  # context/standards/status-markers.md's "Target Arguments vs. Resting States" subsection)
  # resolves the resting state to completed regardless of task type — the task never rests at
  # pr_ready here; that resting state is reserved for the separate `#### State: pr_ready` handler
  # below, reached only via a preflight:pr_ready call for real task_type == "pr" tasks.
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready

  # Propagate completion_summary/roadmap_items (Defect B fix). No precomputed JSON is passed —
  # this branch has no cached $recover_json and needs a fresh read. dispatch_start_ts is still
  # correct here: this branch is only entered on a cycle where no new dispatch occurred, so the
  # variable still holds the last real per-phase implement dispatch's timestamp, which precedes
  # that dispatch's .return-meta.json write — exactly the freshness window the recovery script's
  # staleness gate expects.
  hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}"

  rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note below
  EXIT (success, completed — skeleton exhausted via pr_ready target argument, ${follow_up_count} follow-up task(s): ${follow_up_tasks})

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

# Named-shim to the single shared implementation, skill_orchestrate_propagate_completion
# (scripts/skill-base.sh) — see that function's header for the full contract (single propagation
# path for every terminal "implemented" exit in both orchestrate engines; a new terminal exit
# path added to either SKILL.md MUST call a helper here rather than re-inlining a
# completion-propagation block). Kept as a locally-named function because both call sites in this
# file still say `hard_orchestrate_propagate_completion`. Source is defensive/idempotent: this
# fence has no earlier explicit source line of its own to depend on.
#
# Usage: hard_orchestrate_propagate_completion <task_number> <task_type> <task_dir> \
#          <dispatch_start_ts> [precomputed_json]
source .claude/scripts/skill-base.sh
hard_orchestrate_propagate_completion() {
  skill_orchestrate_propagate_completion "$1" "$2" "$3" "$4" "${5:-}" "[hard-orchestrate]"
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

**Scope of this claim (Defect 5 correction)**: this is a statement about what THIS orchestrator's
own Stage 4 does — it never issues two concurrent `Agent` calls — not a claim about the state of
the world. It does NOT mean no other agent can be concurrently active: a previously-dispatched
agent may still be live via a self-armed watcher/monitor or an operator resume (see
`context/patterns/dispatch-report-not-termination.md`), entirely outside this orchestrator's own
control flow. "No parallel dispatch" and "no concurrency" are different claims; only the former
is asserted here.
<!-- END 772: Parallel Wave Dispatch — DISABLED -->

#### State: `partial`

Read handoff to determine sub-state:

```bash
handoff=$(cat "$handoff_file" 2>/dev/null || echo '{}')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
# Dual-form resolution: the flat top-level continuation_path is what live H9 hard-mode wrap-up
# writers actually emit; the nested continuation_context.handoff_path is a mirror-image
# possibility -- today no writer needs it, but a revived nested-form writer would otherwise be
# invisible to this engine, which is the exact mirror of the defect being fixed here. Same rule
# as scripts/orchestrate-triage-classify.sh's continuation_ok predicate and the base engine's
# Stage 4/Stage 5 handlers.
continuation=$(echo "$handoff" | jq -r '.continuation_context.handoff_path // .continuation_path // "null"')
blocker_count=$(echo "$blockers" | jq 'length')
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
```

**Sub-state: continuation available** (`continuation` — resolved from either accepted form above
— is not the literal string `"null"`):

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
rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note below
EXIT (success, pr_ready)
```

#### State: `blocked`

Read blockers from state.json. Invoke blocker escalation (Stage 6).

#### State: `completed`

```bash
echo "[hard-orchestrate] Task $task_number completed."
rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note below
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
     --arg sid "$session_id" \
    '.target_churn[$target] = $count | .total_churn = $total | .last_session_id = $sid' \
    "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

  echo "[hard-orchestrate] H6: Churn detected on '$blocker_target' (count: $new_target_churn)" >&2

  # Three-strikes: dispatch divergence audit instead of another implement
  if [ "$new_target_churn" -ge 3 ]; then
    echo "[hard-orchestrate] H5: Three-strikes — dispatching divergence audit for '$blocker_target'" >&2
    verbatim_goal=$(echo "$handoff" | jq -r '.blockers[0].verbatim_goal // ""')

    # $RESEARCH_AGENT never writes .orchestrator-handoff.json, per the Stage 3.6 "Scoping
    # Decision" in general-research-agent.md / general-research-hard-agent.md and the Handoff
    # Writers table in docs/architecture/handoff-schema.md — so no absolute anchor is passed
    # here. Revisit if that exclusion is ever lifted.
    Agent tool:
      subagent_type: $RESEARCH_AGENT
      prompt: "DIVERGENCE AUDIT for task $task_number. Target: '$blocker_target'. Verbatim goal: '$verbatim_goal'. This target has failed 3 times. Identify root cause of repeated failure. Write a divergence table, postmortem, and corrected target definition."
      delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit $blocker_target", orchestrator_mode: false}

    # Reset churn counter for this target after audit
    jq --arg target "$blocker_target" --arg sid "$session_id" \
      '.target_churn[$target] = 0 | .audit_dispatches += 1 | .last_session_id = $sid' \
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

# ── System-defect observation log ─────────────────────────────────────────────
# Named-shim to the single shared implementation, skill_orchestrate_append_detected_defect
# (scripts/skill-base.sh) — see that function's header for the full contract (entry shape,
# unconditional-append rule, notice format, MUST-NOTs). Kept as a locally-named function because
# test-handoff-dispatch-identity.sh stubs `append_detected_defect` by this exact name and `eval`s
# a region below that calls it — a renamed call site would silently defeat that stub. The only
# per-engine difference is the notice prefix (`[hard-orchestrate]` here, `[orchestrate]` in
# `skill-orchestrate/SKILL.md`), passed as an explicit argument below. Source is
# defensive/idempotent: this Stage 5 fence has no earlier explicit source line of its own to
# depend on.
source .claude/scripts/skill-base.sh
append_detected_defect() {  # class, attributed_path, site, detail, record_result
  skill_orchestrate_append_detected_defect "$loop_guard_file" "[hard-orchestrate]" "$1" "$2" "$3" "$4" "${5:-}"
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
    echo "[hard-orchestrate] ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($stale_window_start)." >&2
    echo "[hard-orchestrate] This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
    # Deliverable 2(b): record this Class (a) "loud but unactioned" detection. No
    # dispatched-agent-name variable is unambiguously in scope at this shared, stage-agnostic
    # block, so attribution names this detecting site's own SKILL.md.
    # Recorder stdout is captured (only the `>/dev/null` half of the old `>/dev/null 2>&1` is
    # dropped; stderr stays discarded and the non-fatal `|| echo` tail is intact) so its
    # dedup/suppression outcome can be carried into the ledger entry below as `record_result`.
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "skill-orchestrate-hard/SKILL.md:stage-5-stale-handoff" \
      --task "$task_number" --session "$session_id" \
      --message "handoff mtime $handoff_mtime predates this dispatch window ($stale_window_start)" \
      --attributed-path "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    append_detected_defect "HANDOFF_STALE_OR_ABSENT" \
      "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
      "skill-orchestrate-hard/SKILL.md:stage-5-stale-handoff" \
      "handoff mtime $handoff_mtime predates this dispatch window ($stale_window_start)" \
      "$record_result"
  fi
fi

# --- dispatch-seq-gate:begin ---
# HARD-MODE-TWIN-CROSS-REFERENCE: byte-identical to skill-orchestrate/SKILL.md's Stage 5 block apart from the notice prefix and self-attribution strings; see test-handoff-reader-parity.sh's mechanical assertion.
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
    echo "[hard-orchestrate] WARN: handoff has no dispatch_seq field — writer predates or omits the dispatch_seq contract; degrading to mtime-only discrimination (see context/patterns/dispatch-report-not-termination.md)." >&2
  elif [ "$handoff_dispatch_seq" != "${dispatch_seq:-}" ]; then
    handoff_stale=true
    echo "[hard-orchestrate] ERROR: DISPATCH_SEQ MISMATCH — handoff carries dispatch_seq=$handoff_dispatch_seq, this cycle minted dispatch_seq=${dispatch_seq:-<unset>}. This handoff was NOT written by the current dispatch (a still-live predecessor's late write, or a stale copy) — treating as missing." >&2
    record_result=$(bash .claude/scripts/system-defect-record.sh \
      --defect-class HANDOFF_STALE_OR_ABSENT \
      --detecting-site "skill-orchestrate-hard/SKILL.md:stage-5-dispatch-seq-mismatch" \
      --task "$task_number" --session "$session_id" \
      --message "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${dispatch_seq:-<unset>}" \
      --attributed-path "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
      2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
    append_detected_defect "HANDOFF_STALE_OR_ABSENT" \
      "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
      "skill-orchestrate-hard/SKILL.md:stage-5-dispatch-seq-mismatch" \
      "handoff dispatch_seq=$handoff_dispatch_seq does not match this cycle's minted dispatch_seq=${dispatch_seq:-<unset>}" \
      "$record_result"
  else
    echo "[hard-orchestrate] dispatch_seq match ($handoff_dispatch_seq) — handoff confirmed as this dispatch's own report." >&2
  fi
fi
# --- dispatch-seq-gate:end ---

# ── Stray-handoff sweep + outcome-recovery orchestration ─────────────────────────────────────
# Single shared implementation, orchestrate-stage5-gates.sh — see that script's header for the
# full contract. Same call skill-orchestrate/SKILL.md's Stage 5 makes, so the two engines cannot
# drift apart on this logic again. Differs only by the notice prefix and the --detecting-site
# string. The script never sets loop state itself — it only computes and prints a decision JSON;
# every field below is applied inline, in the same branch shape the pre-dedup code used.
stage5_gates_json=$(bash .claude/scripts/orchestrate-stage5-gates.sh \
  "$TASK_DIR" "$task_number" "$session_id" "$handoff_file" "$handoff_stale" \
  "${dispatch_start_ts:-9999999999}" "$loop_guard_file" "[hard-orchestrate]" \
  "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
  "skill-orchestrate-hard/SKILL.md" "${dispatch_was_transport_error:-false}" "${cycle_count:-0}" \
  "${plan_path:-}")
have_outcome=$(echo "$stage5_gates_json" | jq -r '.have_outcome')

if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  recovered=$(echo "$stage5_gates_json" | jq -r '.recovered')
  if [ "$recovered" = "true" ]; then
    dispatch_status=$(echo "$stage5_gates_json" | jq -r '.dispatch_status')
    phases_completed=$(echo "$stage5_gates_json" | jq -r '.phases_completed')
    phases_total=$(echo "$stage5_gates_json" | jq -r '.phases_total')
    plan_markers_verified=$(echo "$stage5_gates_json" | jq -r '.plan_markers_verified')
    handoff_artifact_path=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_path')
    handoff_artifact_type=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_type')
    handoff_artifact_summary=$(echo "$stage5_gates_json" | jq -r '.handoff_artifact_summary')
    # .return-meta.json carries no hard-mode wrap-up fields — set these explicitly so hard-mode
    # logging degrades visibly rather than reading uninitialized values left over from a
    # previous cycle. Hard-only; the shared script never touches these.
    skeleton=false
    sorry_inventory='[]'
    # Deliberate: charge exactly one work cycle, identical to the handoff-present success path
    # below — real work happened and produced a status transition, so infra_exempt_cycle stays
    # false (its reset default at the top of this stage).
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
  # Dual-form resolution (same rule as Stage 4's partial handler above and
  # scripts/orchestrate-triage-classify.sh's continuation_ok predicate): this occurrence was
  # nested-only and inconsistent with Stage 4's flat-only read -- both are now unified on
  # accepting either form, normalized to { handoff_path, orchestrator_mode: true } or null.
  continuation=$(echo "$handoff" | jq -c '
    ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
    (.continuation_path // null) as $flat |
    ($nested // $flat) as $resolved |
    if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
  ')
  next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  skeleton=$(echo "$handoff" | jq -r '.skeleton // false')
  plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')

  # Additional hard-mode handoff fields: sorry inventory, extended with skeleton + follow_up_task
  sorry_inventory=$(echo "$handoff" | jq -c '.sorry_inventory // []')
  if [ "$(echo "$sorry_inventory" | jq 'length')" -gt 0 ]; then
    follow_ups=$(echo "$sorry_inventory" | jq -r '[.[] | .follow_up_task | select(. != null)] | unique | join(", ")')
    echo "[hard-orchestrate] Sorry inventory: $(echo "$sorry_inventory" | jq 'length') sorrys (skeleton=${skeleton}, follow_up_task: {${follow_ups}})" >&2
  fi

  echo "[hard-orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[hard-orchestrate] Phase progress: $phases_completed/$phases_total (skeleton=${skeleton})"

  # ── Evidence corroboration (handoff-present branch) ──────────────────────────
  # PRECONDITION: reachable ONLY here — a handoff IS present and fresh (this is the `else` of
  # the missing/stale-handoff branch above), dispatch_status is "implemented", AND phases_total
  # is exactly 0 (accounting absent or malformed). Mirrors base mode's identical Stage 5 block
  # byte-for-byte apart from the `[hard-orchestrate]` log prefix and this file's own variable
  # names — see "Tool Constraints (Pure Dispatcher)" — "Read allowlist" item 3(c) below for the
  # widened bounded-use enumeration this call site is now a member of.
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
  # here (idempotent) since this Stage 5 code fence has no earlier explicit source line of its
  # own to depend on.
  source .claude/scripts/skill-base.sh
  if [ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]; then
    corroboration_plan_path="${plan_path:-}"
    if [ -z "$corroboration_plan_path" ]; then
      corroboration_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
    fi
    cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "[hard-orchestrate]" "$handoff_file")
    IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
    phases_completed="${cpc_a#phases_completed=}"
    phases_total="${cpc_b#phases_total=}"
    plan_markers_verified="${cpc_c#plan_markers_verified=}"
  fi

  # ── Advisory evidence probe: ARTIFACTS_SHAPE_MISMATCH on the handoff-present path ─────────
  # Mirrors base-mode `skill-orchestrate/SKILL.md`'s identical Stage 5 addition byte-for-byte
  # apart from the `[hard-orchestrate]` log prefix and this file's own attributed-path/
  # detecting-site strings — closes the same residual gap named in base mode's "MUST NOT
  # (Context Flatness Constraint) — Recovery exception (phase-marker grep)" note: this branch,
  # the handoff-present path, never called `orchestrate-recover-outcome.sh`, so
  # `ARTIFACTS_SHAPE_MISMATCH` was never *computed* here at all — only the recovered-path
  # occurrence (this file's own branch-2 arm above) had a consumer.
  #
  # ADVISORY ONLY, by construction: this probe NEVER overrides the handoff-derived outcome,
  # NEVER changes dispatch_status, and NEVER drives a status transition. Its sole effect,
  # mirroring the recovered-path arm above for the same defect class, is the loud stderr notice
  # plus the non-fatal system-defect-record.sh call below. The handoff this branch already
  # parsed above (dispatch_status, phases_completed/total, handoff_artifact_path/type/summary)
  # remains the sole source of truth for this cycle's outcome — this probe reads a SEPARATE file
  # (.return-meta.json, if any) purely for its evidence_suspect/evidence_reason fields and
  # ignores every other field it returns.
  #
  # Exit-code handling: exit 0 (recovered=true) is the only code whose evidence fields are
  # consulted. Exit 1 and exit 2 both mean "no signal available" and are NOT escalated — a
  # handoff-present dispatch legitimately may have no recoverable `.return-meta.json`.
  artifacts_probe_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
  artifacts_probe_exit=$?
  if [ "$artifacts_probe_exit" -eq 0 ]; then
    artifacts_probe_suspect=$(echo "$artifacts_probe_json" | jq -r '.evidence_suspect // false' 2>/dev/null) || artifacts_probe_suspect=false
    artifacts_probe_reason=$(echo "$artifacts_probe_json" | jq -r '.evidence_reason // "NONE"' 2>/dev/null) || artifacts_probe_reason="NONE"
    if [ "$artifacts_probe_suspect" = "true" ] && [ "$artifacts_probe_reason" = "ARTIFACTS_SHAPE_MISMATCH" ]; then
      echo "[hard-orchestrate] EVIDENCE: advisory probe over this dispatch's .return-meta.json (handoff-present path) reports a non-empty artifacts array yielding no resolvable path (evidence_reason=ARTIFACTS_SHAPE_MISMATCH) — advisory only; the handoff-derived outcome above is unaffected." >&2
      probe_record_result=$(bash .claude/scripts/system-defect-record.sh \
        --defect-class ARTIFACTS_SHAPE_MISMATCH \
        --detecting-site "skill-orchestrate-hard/SKILL.md:stage-5-handoff-present-probe" \
        --task "$task_number" --session "$session_id" \
        --message "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
        --attributed-path "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
        2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
      append_detected_defect "ARTIFACTS_SHAPE_MISMATCH" \
        "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" \
        "skill-orchestrate-hard/SKILL.md:stage-5-handoff-present-probe" \
        "advisory probe over .return-meta.json on the handoff-present path found a non-empty artifacts array yielding no path" \
        "$probe_record_result"
    fi
  fi
  # exit 1/exit 2 (recovered=false, or usage/jq error): no signal available, nothing to do here.

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork) — same as base
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[hard-orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
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

# ── Shared postflight tail — hard-mode-specific gate on `implemented` (772 Item 5B) ──────────
# Reached from EITHER the handoff-present branch above OR a successful return-meta recovery —
# never duplicated between them.
#
# Single shared implementation, orchestrate-stage5-postflight.sh — see that script's header for
# the full contract. Same call skill-orchestrate/SKILL.md's Stage 5 makes, so the two engines
# cannot drift apart on this logic again. The script performs the real state.json/TODO.md
# writes, but the actual loop-halting decision (`EXIT (partial)`) and the cycle_count increment
# below stay HERE, applied inline from the script's decision JSON.
if [ "$have_outcome" = "true" ]; then
  stage5_postflight_json=$(bash .claude/scripts/orchestrate-stage5-postflight.sh \
    "$task_number" "$session_id" "$TASK_TYPE" "$TASK_DIR" "$dispatch_status" \
    "$phases_completed" "$phases_total" "$plan_markers_verified" \
    "$handoff_artifact_path" "$handoff_artifact_type" "$handoff_artifact_summary" \
    "[hard-orchestrate]" "skill-orchestrate-hard/SKILL.md:tier-c" \
    "agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md" " --hard" \
    "${dispatch_start_ts:-9999999999}" "$handoff_file" "$loop_guard_file" "${cycle_count:-0}")
  offschema_dispatch_status=$(echo "$stage5_postflight_json" | jq -r '.offschema_dispatch_status')

  # Hard-only diagnostic: the script's `implemented_gate_passed` field is `null` unless
  # dispatch_status was "implemented" this cycle, so this only ever fires on that arm's refusal
  # branch — same precondition the pre-dedup inline `else` clause had.
  implemented_gate_passed=$(echo "$stage5_postflight_json" | jq -r '.implemented_gate_passed')
  if [ "$dispatch_status" = "implemented" ] && [ "$implemented_gate_passed" = "false" ]; then
    echo "[hard-orchestrate] skeleton=${skeleton} at refusal." >&2
  fi

  # Off-schema halt — consumed HERE, after the script's own artifact linking has already run,
  # not as an inline exit inside the case statement. This preserves the dispatch's evidence (the
  # artifact, if any, is still linked into TODO.md/state.json) rather than discarding it. Mirrors
  # Stage 4's "Unknown state" handler precedent.
  if [ "$offschema_dispatch_status" = "true" ]; then
    echo "[hard-orchestrate] Halting: task $task_number left at its current status. Any artifact produced by this dispatch was still linked above, preserving the evidence." >&2
    EXIT (partial)
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
  # $RESEARCH_AGENT never writes .orchestrator-handoff.json, per the Stage 3.6 "Scoping
  # Decision" in general-research-agent.md / general-research-hard-agent.md and the Handoff
  # Writers table in docs/architecture/handoff-schema.md — so no absolute anchor is passed
  # here. Revisit if that exclusion is ever lifted.
  Agent tool:
    subagent_type: $RESEARCH_AGENT
    prompt: "Research blocker for task $task_number: $blocker_desc. Find a concrete resolution path."
    delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "blocker research", orchestrator_mode: false}

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

# MAX_CYCLES reached. Note: with the Stage 2 budget-continuation-override in place, this branch
# is now normally unreachable in practice for an already-exhausted guard -- Stage 2 either exits
# early (flag absent) or resets cycle_count to 0 (flag present) before the main loop ever opens.
# It remains correct as a defense-in-depth backstop for the rare case where MAX_CYCLES is reached
# DURING this same invocation's own loop (not from a resumed, pre-exhausted guard).
if [ "$cycle_count" -ge "$MAX_CYCLES" ]; then
  echo "[hard-orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
  echo "Phases completed: $phases_completed of $phases_total"
  echo "Run /orchestrate $task_number --hard --continue-budget to authorize a fresh budget and continue."
  EXIT (partial, cycle_count=$MAX_CYCLES)
fi
```

---

### Stage 8: Postflight and Cleanup

**Write metadata file.** `status` here is the `.return-meta.json` skill-status vocabulary defined
normatively in `context/formats/return-metadata-file.md` — it is NOT the state.json task-status
vocabulary (`current_status` below, where `"completed"` is correct); do not "correct" this value
back to `"completed"`. **No new top-level status value is introduced by the `detected_defects`
mechanism**: a run that observed a defect but otherwise completed is still `"implemented"`.

This subsection MUST run BEFORE the `rm -f` block below — `detected_defects` is read out of the
loop guard, so the guard must still exist when the read happens.

`cycles_used` and `final_state` are written here because a merge block mirroring base mode's
Stage 8 would be structurally incomplete without them; closing the broader hard-mode metadata
gap is not this change's purpose, and nothing else about hard-mode metadata is being backfilled.

On clean exit:

```bash
# Single shared implementation, skill_orchestrate_merge_return_meta (scripts/skill-base.sh) — see
# that function's header for the full contract. Read the run's system-defect observation log
# while the loop guard still exists (this fence runs BEFORE the `rm -f` cleanup below, unlike
# the base engine's own clean-exit ordering — see that function's header for the asymmetry).
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "implemented" \
  "$cycle_count" "$current_status"
```

On partial exit:

```bash
# Same shared implementation and merge-onto-existing discipline as the clean-exit variant above.
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "partial" \
  "$cycle_count" "$current_status"
```

**Cleanup.**

**Both `.orchestrator-loop-guard` and `.orchestrator-churn-state.json` are ephemeral, gitignored,
and removed only at full-loop termination — never between cycles.** Every `stage_paths`/`git add`
in this loop (and in `commands/orchestrate.md`'s CHECKPOINT 3, which runs every cycle) must
independently exclude both rather than rely on this cleanup, because a per-cycle commit happens
before this stage ever runs on any cycle but the last. See
`context/standards/orchestrator-runtime-files.md` for the full policy.

```bash
rm -f "$loop_guard_file"
rm -f "$churn_file"
```

(Only on successful completion. Leave loop guard and churn state on partial for resume.)

**Explicitly UNCHANGED by Defect B's budget-continuation override**: this cleanup site still only
fires on full-loop termination, never on a partial exit -- including the Stage 2 exhaustion
branch's flag-absent `exit 1`, which leaves the exhausted guard fully in place. This is correct,
not an oversight: the guard's entire job is to persist across exactly this gap, so an operator's
subsequent `--continue-budget` invocation has something to read `cycle_count` from. All four
sites that touch this guard's lifecycle -- Stage 2's exhaustion branch, Stage 7's terminal
condition, and this Stage 8 cleanup -- now visibly agree on this.

---

## Multi-Task Mode

Same as base `skill-orchestrate` multi-task stages (MT-1 through MT-5). Hard-mode applies
to each individual task in the wave — they each use the per-phase dispatch H1 loop above.

**Why this section transcribes rather than merely points**: the two-sentence pointer above
already nominally covered the self-modification admission gate and the inter-cycle redeploy
checkpoint, and a repo-wide grep for `batch-admit` against this file found ZERO references —
direct evidence that a bare "same as base" pointer does not reliably carry a mechanism forward
into a full structural variant. Strengthening the pointer's wording would repeat exactly the
failure class this task found, so the two mechanisms below are transcribed explicitly instead,
matching this file's own stated design philosophy of being a full structural variant of
`skill-orchestrate`, not a thin wrapper around it.

**Transcribed: self-modification / cross-batch admission gate** (mirrors
`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 — **CO-MAINTENANCE**: an edit to either copy
REQUIRES the same edit to the other; the two MUST always agree). Before dispatching
`eligible_tasks` on every cycle, call the admission script with the NARROWED co-dispatch count
and `--session-id "$session_id"` (D6, session-registry contention input — the SAME bare
`session_id` Stage MT-1 registered via `session-register`, so this call's self-exclusion matches
the batch's own registry entry rather than seeing it as foreign and deferring every candidate
against itself):

```bash
bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id "$session_id" "${eligible_tasks[@]}"
```

`jq`-filter stdout for `.decision == "defer"`, then branch on `defer_reason` FIRST (schema v5 —
every defer verdict carries this REQUIRED discriminator):

- **`self_modifying`**: consumer-side override check first — if `allow_self_modifying == true`
  for this invocation, do NOT act on the defer verdict; dispatch the candidate this cycle anyway
  and log a loud, distinct bypass notice naming the matched `critical_path` and `critical_label`,
  whether or not the gate would otherwise have fired. `orchestrate-batch-admit.sh` is NEVER
  passed the flag — the bypass is a consumer-side decision only. Otherwise, remove the candidate
  from this cycle's dispatch batch and append it to the `deferred_self_modifying` OBSERVATION LOG
  (no longer an eligibility-exclusion set — the defer clears on its own once the co-dispatched
  sibling leaves `eligible_tasks`); log a distinct warning naming the matched critical path,
  label, and the co-dispatched sibling situation.
- **`file_scope_collision`** — matches `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's
  `collision_scope` branching exactly; both branches remove the deferred task from this cycle's
  dispatch batch and never add it to `failed_tasks` (never added to `deferred_self_modifying` —
  that set is exclusive to the `self_modifying` branch above). Self-clearing differs by scope, and
  the two must not be conflated:
  - **`in_batch`** (the colliding task is itself in `eligible_tasks`): self-clears within this
    invocation — the deferred task becomes eligible again on a later cycle, once the colliding
    in-batch task leaves `eligible_tasks` (entering `researching`/`planning`, terminating, or
    failing). This cycling defer IS Tier 1 (auto-sequence) of the four-tier conflict-response
    ladder — see `.claude/context/patterns/task-lock.md`'s "Four-Tier Conflict Response" section
    for the full ladder and how this multi-cycle re-sequencing compares to plain multi-task
    `/research`'s, `/plan`'s, and `/implement`'s bounded one-extra-pass equivalent.
  - **`cross_batch`** (the colliding task is NOT part of `task_numbers` for this invocation): does
    NOT self-clear within this invocation — the excluded candidate does NOT automatically become
    eligible again this run, since the colliding task is outside `task_numbers` and this loop has
    no mechanism to advance it. A human resolves batch composition, or a future invocation
    re-evaluates once the colliding task's status independently changes. The warning names the
    out-of-batch task, its `colliding_task_status`, and appends the suggestion clause "suggest
    adding #{suggested_predecessor} as a dependencies[] entry on #{suggested_dependent} to
    serialize them" (higher task number is the dependent, lower is the predecessor) — identical to
    `orchestrate-predispatch-review.sh`'s Class D finding, the same mechanism printed both
    upstream (Step 1.5 review) and here at the moment of exclusion.
  No behavioral change from the base skill here; this bullet is a full transcription, not a
  cross-reference.
- **`session_active`** (NEW in v4, reached only when the collision scan above found no hit): a
  live registered session's own unioned `file_scope` overlaps the candidate's. Same defer-not-fail
  cycle semantics as the two branches above — remove the candidate from this cycle's dispatch
  batch, never add to `failed_tasks`, never add to `deferred_self_modifying`, eligible again once
  the contending session releases or goes stale. Log a distinct warning naming the contending
  session, the task it covers, and its liveness reason.
- **Degradation path**: exit 2 from `orchestrate-batch-admit.sh` means state is unavailable; log
  a loud warning and proceed without the check.

**Idle cross-batch overlap advisory** (`idle_overlap_advisory`, NEW in v5): mirrors
`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5's advisory check exactly — **CO-MAINTENANCE**:
an edit to either copy REQUIRES the same edit to the other. Run `jq -e '.idle_overlap_advisory'`
on **every** verdict this cycle, `admit` included, OUTSIDE and INDEPENDENTLY of the
`defer_reason` branching above — a v5 `cross_batch` overlap against an idle out-of-batch task no
longer defers at all, it admits with this field attached, so nesting the check inside the defer
branching would silently skip the common case. When present, print a distinct ADVISORY line —
never folded into an existing WARNING's text, since the advisory may name a *different* colliding
task than the verdict's own subject. This fires IN ADDITION to any `session_active` or
`file_scope_collision` WARNING already logged for the same verdict:
```
[orchestrate] ADVISORY: Task #{task_number} has file_scope overlapping IDLE (status:
  {colliding_task_status}) out-of-batch task #{colliding_task_number} at {overlapping_path};
  not blocking because no execution evidence exists. Add a dependencies[] edge between
  #{task_number} and #{colliding_task_number} if ordering matters.
```

The verdict schema itself is not restated here — see `docs/architecture/batch-admit-schema.md`.
The overlap predicate is not restated here — see `context/patterns/file-footprint-overlap.md`.

**Transcribed: inter-cycle redeploy checkpoint** (mirrors `skill-orchestrate/SKILL.md` Stage MT-3
step 7 — **CO-MAINTENANCE**: an edit to either copy REQUIRES the same edit to the other; the two
MUST always agree). After every dispatch cycle, once `cycle_count` increments: expand
`context/reference/orchestrator-critical-paths.json` using the same `scope_roots x
critical_paths` expression `orchestrate-batch-admit.sh` performs, intersect against this cycle's
accumulated `cycle_modified_files` using the directory-prefix overlap predicate in
`context/patterns/file-footprint-overlap.md`, and subtract already-deployed critical paths
(`deployed_critical_paths`, the idempotence guard). If the remainder is non-empty: immediately
before redeploying, capture a pre-redeploy baseline (`verify-deploy.sh`'s own exit code captured
FIRST, as the sole command in its command substitution, THEN its `--findings --quiet` output
filtered to `^FINDING ` lines and `sort -u`'d as a separate step — see
`skill-orchestrate/SKILL.md`'s Stage MT-3 step 7 Fire bullet for why the exit code must not be
read off a piped substitution), then run, in order:

```bash
bash .claude/scripts/deploy-headless.sh
```

and, only on its success:

```bash
bash .claude/scripts/verify-deploy.sh
```

capturing the identical post-redeploy baseline at this same call site. Branch three ways:

- **`deploy-headless.sh` failure** (exit 1/2) → defer unconditionally, with NO baseline
  consultation whatsoever: add every non-terminal, non-failed task in `task_numbers` to
  `deferred_deploy_checkpoint`; never add to `failed_tasks`, never status-mutate, never abort.
- **`verify-deploy.sh` failure with at least one newly-introduced finding** relative to the
  pre-redeploy baseline (the set difference over the two captures) → defer, unchanged in shape
  from the branch above: same `deferred_deploy_checkpoint` addition, same never-fail/never-mutate/
  never-abort guarantees.
- **`verify-deploy.sh` failure whose findings are ALL already present in the pre-redeploy
  baseline** → the third operator-visible state: proceed, reported just as loudly as an outright
  failure (banner + machine marker + a `verify_deploy_baseline_notices` ledger entry), and record
  the matched critical paths into `deployed_critical_paths` exactly as the success path does. Never
  add to `deferred_deploy_checkpoint` or `defer_ledger` for this branch.

On outright success (`verify-deploy.sh` exit 0), record the matched paths into
`deployed_critical_paths` and continue. Full contract (baseline mechanism, exit-2 resolution,
rejected alternatives, sequencing guarantee, concurrency) is recorded once, authoritatively, in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection — referenced here, not restated in full.

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

---

## MUST NOT (Postflight Boundary)

This section names, in the same vocabulary `skill-orchestrate`'s equivalent section and every
delegating core skill's postflight-boundary section use, the same restrictions the "Tool
Constraints (Pure Dispatcher)" section above already enforces structurally (via the
`allowed-tools: Agent, Bash, Read` frontmatter scoping — `Edit` intentionally absent). After each
stage dispatch (research/plan/implement) returns, this skill MUST NOT:

1. **Edit source files** - This skill never holds the `Edit` tool at all; all research, planning,
   and implementation work is done by the dispatched agent
2. **Run build/test/compiler/linter commands** - Forbidden Bash Operations above names the
   specific denylist (`lake build`, `lean`/`lean-lsp`, `nvim --headless`, `npm`/`pytest`/
   `cargo test`/`go test`, or any equivalent tool); these belong exclusively to the dispatched
   `$IMPLEMENT_AGENT`
3. **Use MCP/WebSearch/domain tools** - Domain tools are for the dispatched agent's use only
4. **Analyze or grep implementation source** - the Read allowlist above explicitly forbids
   reading `lua/**`, `after/**`, or any per-project source root; grep is bounded to the three
   named plan/report uses only
5. **Write reports/plans/summaries** - Artifact creation is dispatched-agent work

The per-dispatch postflight phase is LIMITED TO the same bounded set the Context-Flatness-style
read allowlist above already defines: reading `.orchestrator-handoff.json` (or its bounded
return-meta/phase-marker recovery exceptions), driving the state-machine transition to the next
cycle, and cleanup of temp/marker/churn-state files.

Reference: @.claude/context/standards/postflight-tool-restrictions.md
