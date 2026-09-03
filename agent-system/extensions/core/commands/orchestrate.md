---
description: Execute a task autonomously through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read
argument-hint: TASK_NUMBERS [PROMPT] [--haiku|--sonnet|--opus|--fable] [--research] [--plan] [--implement]
model: opus
---

# /orchestrate Command

Drive a task through its complete lifecycle autonomously without pausing for user confirmation.
Implements fire-and-forget state machine: research -> plan -> implement -> complete.

## Arguments

- `$1` - Task number(s) (required). Supports single task, comma-separated lists, and ranges.
  - Single: `42`
  - Comma-separated: `42, 43, 45`
  - Range: `42-45`
  - Mixed: `42, 44-46, 50`
- `$2+` - Optional prompt/focus text (e.g., `focus on the LSP config`). Applies to all tasks in multi-task mode.

## Constraints

- Multi-task mode uses dependency-aware wave dispatch.
- `--research`/`--plan`/`--implement` (phase-forcing flags) are single-task only: in multi-task
  mode they are accepted and ignored, with a loud notice, rather than partially wiring
  per-task phase forcing into wave dispatch.
- No confirmation gates between lifecycle phases
- Terminates automatically on success, MAX_CYCLES exceeded, MAX_INFRA_FAILURES exceeded (repeated Agent-tool transport/API failures — a distinct connectivity-vs-work-budget diagnosis), or unrecoverable blocker
- In multi-task mode, failure in one task does not block other tasks in the same wave, but DOES block dependent tasks in later waves

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based tasks | false |
| `--dry-run` | Report-only: run the full admission analysis and print the verdict report; dispatch nothing and mutate nothing | false |
| `--allow-self-modifying` | Opt-in bypass of the self-modification admission gate for this invocation only; requires deliberate human intent — never a general-purpose weakening | false |
| `--allow-scope-collision` | Opt-in bypass of the CROSS-BATCH `file_scope_collision` admission gate for this invocation only; never bypasses an `in_batch` collision — requires deliberate human intent — never a general-purpose weakening | false |
| `--continue-budget` | Explicit, operator-typed authorization to continue past an exhausted `MAX_CYCLES` work-cycle budget. Never inferred automatically (not from `session_id`, not from mtime) — a genuinely exhausted budget without this flag refuses immediately with an honest message instead of silently no-op looping. See `context/standards/orchestrator-runtime-files.md`'s "`cycle_count` semantics and the budget-continuation override" section | false |
| `--clean` | Skip automatic memory retrieval | false |
| `--fast` | Low-effort mode: lighter reasoning, faster responses | false |
| `--haiku` | Use Haiku model (fastest, lowest cost). Applies to research/plan/implement dispatches only — diagnostic dispatches (blocker escalation, drift inspection, churn audit, plan revision) retain their frontmatter model | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--fable` | Use Fable model (claude-fable-5) | false |
| `--research` | Force a research round to run even if the task has already progressed past it (e.g. re-research a `[PLANNED]` task). Composable with `--plan`/`--implement`; the composed sequence is ordered by canonical lifecycle order (research, plan, implement) regardless of the order the flags are typed, and STOPS after the last named phase rather than continuing to status-derived dispatch. Opens a new `MM_` artifact round and never regresses the task's status. Single-task only — accepted and ignored (with a loud notice) in multi-task mode | false |
| `--plan` | Force a plan round to run even if the task has already progressed past it. Composable with `--research`/`--implement` on the same terms as `--research` above (canonical ordering, stop-after-last-named-phase, new artifact round, no status regression). Single-task only — accepted and ignored (with a loud notice) in multi-task mode | false |
| `--implement` | Force an implement round to run even if the task has already progressed past it. Composable with `--research`/`--plan` on the same terms as `--research` above (canonical ordering, stop-after-last-named-phase, new artifact round, no status regression). Single-task only — accepted and ignored (with a loud notice) in multi-task mode | false |

## Anti-Bypass Constraint

**PROHIBITION**: All lifecycle phases (research, plan, implement) MUST be executed by delegating
to `skill-orchestrate` via the Skill tool. Never run research/plan/implement directly from this
command.

## Execution

### STAGE 0: PARSE AND DISPATCH

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS (space-separated), FOCUS_PROMPT, REMAINING_ARGS, DRY_RUN_FLAG,
#          ALLOW_SELF_MODIFYING_FLAG, ALLOW_SCOPE_COLLISION_FLAG, CONTINUE_BUDGET_FLAG,
#          CLEAN_FLAG, EFFORT_FLAG, MODEL_FLAG, FORCE_PHASES_FLAG
focus_prompt="${FOCUS_PROMPT:-}"
```

Each parsed flag becomes a delegation-context key, threaded unchanged into both the single-task
STAGE 2 JSON and the multi-task Skill invocation below. All are **consumer-side-only**: none is
ever forwarded to `orchestrate-batch-admit.sh` itself.

- `allow_self_modifying` (`ALLOW_SELF_MODIFYING_FLAG`, default `false`) — opt-in bypass of the
  self-modification admission gate for this invocation only.
- `allow_scope_collision` (`ALLOW_SCOPE_COLLISION_FLAG`, default `false`) — opt-in bypass of the
  CROSS-BATCH `file_scope_collision` gate only (never `in_batch`).
- `continue_budget` (`CONTINUE_BUDGET_FLAG`, default `false`) — explicit, operator-typed
  authorization to continue past an exhausted `MAX_CYCLES` budget; read by `skill-orchestrate`'s
  own Stage 2. **Never inferred automatically** (not from `session_id`, not from mtime) — a
  genuinely exhausted budget without this flag refuses immediately with an honest message. See
  `context/standards/orchestrator-runtime-files.md`'s "`cycle_count` semantics and the
  budget-continuation override" section.
- `clean_flag` (`CLEAN_FLAG`, default `false`) — suppresses `skill-orchestrate`'s own automatic
  memory retrieval (Stage 3.5).
- `effort_flag` (`EFFORT_FLAG`, default `""`) — reasoning-depth guidance for every lifecycle
  dispatch.
- `model_flag` (`MODEL_FLAG`, default `""`, not `null`) — selects the model family for every
  lifecycle dispatch.
- `force_phases` (`FORCE_PHASES_FLAG`, default `""`) — the composable `--research`/`--plan`/
  `--implement` surface (A2). Single-task mode: read only by `skill-orchestrate`'s own Stage 2b.
  Multi-task mode: threaded for diagnostics only — Stage MT-1 emits an accepted-and-ignored
  notice and never fans it into per-task dispatch.

**Dry-run short-circuit** (checked immediately after `parse-command-args.sh` is sourced, and
**before** the `len(TASK_NUMBERS)` branch below): `SESSION_ID` may be unset at this point — the
flag is parsed before CHECKPOINT 1: GATE IN, which is where a session id is normally minted — so
`--session` is passed to the report script only when non-empty.

```bash
if [ "${DRY_RUN_FLAG:-false}" = "true" ]; then
  if [ -n "${SESSION_ID:-}" ]; then
    bash .claude/scripts/orchestrate-dry-run-report.sh --session "$SESSION_ID" $TASK_NUMBERS
  else
    bash .claude/scripts/orchestrate-dry-run-report.sh $TASK_NUMBERS
  fi
  # STOP HERE.
fi
```

The report uses the SAME read-only admission analysis the live path uses — naming
`scripts/orchestrate-batch-admit.sh` (file_scope collisions) and
`scripts/orchestrate-triage-classify.sh` (handoff-triage routing) by path — so the printed wave
numbers are the same ones a live run would actually dispatch. Neither schema is restated here;
see each script's own header comment for its field-by-field contract.

**Dry-run prohibition block**: in dry-run mode, this command MUST NOT continue to multi-task
dispatch below, MUST NOT reach CHECKPOINT 1 (GATE IN), MUST NOT invoke the Skill or Agent tools,
MUST NOT acquire a task lock, and MUST NOT run CHECKPOINT 3 (COMMIT). This mirrors the Anti-Bypass
Constraint above: just as that constraint prohibits running lifecycle phases without delegating
through `skill-orchestrate`, this constraint prohibits a `--dry-run` invocation from reaching ANY
lifecycle phase at all — the STOP HERE above is absolute, not advisory.

If `len(TASK_NUMBERS) == 1`: extract `task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')` and fall through to CHECKPOINT 1: GATE IN.

If `len(TASK_NUMBERS) > 1`: continue to the multi-task dispatch block below.

**Multi-task dispatch** (`len(TASK_NUMBERS) > 1`):

```bash
validated_tasks=(); skipped_tasks=()
for task_num in "${TASK_NUMBERS[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' specs/state.json)
  if [ -z "$task_data" ]; then
    skipped_tasks+=("$task_num: not found")
    continue
  fi
  status=$(echo "$task_data" | jq -r '.status')
  case "$status" in
    completed|abandoned|expanded)
      skipped_tasks+=("$task_num: terminal status [$status]")
      continue
      ;;
  esac
  validated_tasks+=("$task_num")
done
```

Report skipped tasks as warnings. If no validated tasks remain, ABORT with error.

**Pre-Dispatch Review** (advisory-loud, never blocking — retained as a one-line call; it is the
only visibility surface for out-of-batch/nonexistent `dependencies[]` edges before they are
narrowed away below): `--dry-run` remains the abort-before-dispatch surface for a human who wants
the full picture; this call never aborts on its own account.

```bash
bash .claude/scripts/orchestrate-predispatch-review.sh "${validated_tasks[@]}"
```

Build the intra-batch dependency graph — restricted to dependencies on tasks also in
`validated_tasks` (the raw, unfiltered edges were already reviewed above):

```bash
declare -A predecessors
for task_num in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' \
    specs/state.json)
  intra_deps=()
  for dep in $deps; do
    [[ " ${validated_tasks[*]} " == *" $dep "* ]] && intra_deps+=("$dep")
  done
  predecessors[$task_num]="${intra_deps[*]}"
done

dep_graph_json=$(jq -n '{}')
for task_num in "${validated_tasks[@]}"; do
  deps_array=$(jq -n --argjson deps "$(printf '%s\n' "${predecessors[$task_num]}" | jq -R . | jq -s .)" '$deps')
  dep_graph_json=$(echo "$dep_graph_json" | jq --arg key "$task_num" --argjson deps "$deps_array" \
    '. + {($key): $deps}')
done
```

**MAX_TASKS Guard** (see `docs/architecture/orchestrate-state-machine.md`'s
`### Batch Size Cap (MAX_TASKS)` for the documented contract this executes):

```bash
task_count=${#validated_tasks[@]}
MAX_TASKS=8
if [ "$task_count" -gt "$MAX_TASKS" ]; then
  echo "[orchestrate] WARNING: $task_count tasks exceeds MAX_TASKS=$MAX_TASKS."
  echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
fi
```

`waves` is a **diagnostic echo, not a schedule the engine consumes** — `skill-orchestrate`
re-derives eligibility fresh every cycle from `dependency_graph` and current task statuses (Stage
MT-3 step 4.5), never from a pre-computed wave. It is passed as one row of all validated tasks:

```bash
waves_json=$(jq -n --argjson t "$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')" '[$t]')
task_numbers_json=$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')

source .claude/scripts/lib/common.sh
batch_session_id="$(common_session_id)"
```

Invoke a single `skill-orchestrate` instance with all task context — it manages wave-by-wave
dispatch, per-task postflight, in-flight session registry annotation (register at Stage MT-1,
release at Stage MT-5), and writes results to
`specs/.orchestrator-multi-state-${batch_session_id}.json`:

```
Tool: Skill
Parameters:
  skill: "skill-orchestrate"
  args: "multi_task_mode=true task_numbers={task_numbers_json} waves={waves_json} dependency_graph={dep_graph_json} session_id={batch_session_id} focus_prompt={focus_prompt} lit_flag={LIT_FLAG} allow_self_modifying={ALLOW_SELF_MODIFYING_FLAG} allow_scope_collision={ALLOW_SCOPE_COLLISION_FLAG} continue_budget={CONTINUE_BUDGET_FLAG} clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} force_phases={FORCE_PHASES_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{batch_session_id}",
  "multi_task_mode": true,
  "task_numbers": [42, 43, 44],
  "waves": [[42, 43, 44]],
  "dependency_graph": {"42": [], "43": [42], "44": [42]},
  "focus_prompt": "{focus_prompt}",
  "lit_flag": "{LIT_FLAG}",
  "allow_self_modifying": "{ALLOW_SELF_MODIFYING_FLAG}",
  "allow_scope_collision": "{ALLOW_SCOPE_COLLISION_FLAG}",
  "continue_budget": "{CONTINUE_BUDGET_FLAG}",
  "clean_flag": "{CLEAN_FLAG}",
  "effort_flag": "{EFFORT_FLAG}",
  "model_flag": "{MODEL_FLAG}",
  "force_phases": "{FORCE_PHASES_FLAG}"
}
```

The skill emits the consolidated batch output itself (Stage MT-5) once its lifecycle-cycling loop
exits — see `context/patterns/orchestrate-batch-results-template.md`.

**After the Skill invocation returns, STOP. Do not continue to CHECKPOINT 1** — multi-task mode
is fully handled inside this single `skill-orchestrate` call, including its own consolidated
output.

---

### CHECKPOINT 1: GATE IN

```bash
source .claude/scripts/command-gate-in.sh "$task_number" "orchestrate"
# Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
# Displays: [ORCHESTRATE] Task {N}: {project_name}
```

**Permissive gate**: Unlike `/implement`, this command does NOT require a plan file.
The state machine handles all lifecycle phases starting from wherever the task currently is.

**Only blocks on terminal states**: `completed`, `abandoned`, `expanded`.
All non-terminal states (not_started, researched, planned, implementing, partial, blocked) are
valid entry points for the orchestrator — without exception, this includes a `partial` task with
no handoff and no blockers (the normal shape left by a base-mode dispatch), which the state
machine dispatches implement for rather than treating as a dead end.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 completes, immediately invoke the Skill tool.

Invoke `skill-orchestrate` via the Skill tool:

```
skill: "skill-orchestrate"
args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true lit_flag={LIT_FLAG} continue_budget={CONTINUE_BUDGET_FLAG} clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} force_phases={FORCE_PHASES_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{SESSION_ID}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "orchestrate", "skill-orchestrate"],
  "task_context": {
    "task_number": N,
    "task_name": "{PROJECT_NAME}",
    "description": "{DESCRIPTION}",
    "task_type": "{TASK_TYPE}"
  },
  "orchestrator_mode": true,
  "focus_prompt": "{FOCUS_PROMPT}",
  "lit_flag": "{LIT_FLAG}",
  "continue_budget": "{CONTINUE_BUDGET_FLAG}",
  "clean_flag": "{CLEAN_FLAG}",
  "effort_flag": "{EFFORT_FLAG}",
  "model_flag": "{MODEL_FLAG}",
  "force_phases": "{FORCE_PHASES_FLAG}"
}
```

**On DELEGATE success**: Orchestration complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2.

### CHECKPOINT 2: GATE OUT

```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "orchestrate" "$SESSION_ID"
# Reads .return-meta.json; applies defensive status correction if needed
```

**On GATE OUT success**: IMMEDIATELY CONTINUE to CHECKPOINT 3.

### CHECKPOINT 3: COMMIT

Apply the `implement`-equivalent scope from `.claude/context/standards/git-staging-scope.md`
(task dir + self-reported `modified_files`) and commit via `.claude/scripts/git-commit-scoped.sh`,
the single sanctioned implementation of path-scoped, mutex-serialized committing — under-stage,
never a repo-wide add. The helper injects the canonical ephemeral-runtime-file exclusion set from
that same standard automatically for the task-directory pathspec below. This is the single most
exposed staging site to the mid-lifecycle-sweep hazard `.claude/context/standards/
orchestrator-runtime-files.md` documents: this checkpoint runs every cycle of a still-running
`/orchestrate` loop, well before the loop guard's own termination-only cleanup fires. Serializing
through the commit mutex also matters here because this per-cycle checkpoint can run concurrently
with another in-flight task's own commit sharing the same index.

The zero-`modified_files` warning below is the canonical, un-suffixed wording from
`.claude/context/standards/git-staging-scope.md`'s "Fail-Safe Direction" section — this is the
single-task site, so it never carries the task-number suffix reserved for the multi-task per-task
site. Do not invent a second wording here.

```bash
task_dir="specs/${PADDED_NUM}_${PROJECT_NAME}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
modified_count=0
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
if [ "$modified_count" -eq 0 ]; then
  echo "[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually." >&2
fi
```

**On completion:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: complete orchestration" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
# Deletion is scoped to the completion branch ONLY. .return-meta.json was staged and committed
# above (its modified_files were already read into stage_paths above), and this is the completion
# outcome's own last consumer of the file. Do NOT add this deletion to the partial branch below:
# a still-running /orchestrate loop's next cycle recovers its outcome via
# orchestrate-stage5-gates.sh, which reads .return-meta.json as a freshness-windowed fallback
# (gated on mtime against dispatch_start_ts, so a stale leftover is never mistaken for a fresh
# outcome) -- deleting it on the paused/partial branch would discard that recovery path.
rm -f "${metadata_file}"
```

**On partial:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: orchestration paused (cycles {M}/{MAX})" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
# NOTE: deliberately no .return-meta.json deletion here -- see the completion branch's comment
# above. The paused/partial outcome keeps the file for the next cycle's outcome recovery.
```

Commit failure is non-blocking (log and continue).

## Output

**Completion**: `Orchestration complete for Task #{N}` | Final status: `[COMPLETED]` | Cycles: M/5

**Partial**: `Orchestration paused for Task #{N}` | Status: `[{STATUS}]` | Cycles: M/5 | `Next: /orchestrate {N}`

**Blocked**: `Task #{N} requires manual intervention` | Blocker description | Suggested actions

**System Defects Detected**: rendered only when `metadata.detected_defects` in the task's
`.return-meta.json` is non-empty. It renders on a **Completion** outcome as readily as on a
**Partial** one — a detection is an observation about the agent system, never a verdict on the
task. This applies to `/orchestrate --hard` runs identically: hard mode writes the same
`metadata.detected_defects` key from its own Stage 8 metadata merge. Same table shape as the
batch section above, so the two renderings stay visually consistent:

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #{N} | HANDOFF_STALE_OR_ABSENT | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:stage-5-stale-handoff | handoff mtime predates this dispatch window |

Operator remedy: fix the named source-store path under `agent-system/extensions/**`; the durable
record is already in `specs/events.jsonl`. No task status was mutated because of these rows.

**`--dry-run`**: the printed admission report only — no status transition, no cycle consumed, no commit. The invocation ends after the report; nothing else in this Output section applies to a `--dry-run` run.

## Error Handling

- **GATE IN Failure**: Task not found or in terminal state — return error with guidance
- **DELEGATE Failure**: Keep current status, log error; loop guard preserved for resume
- **GATE OUT Failure**: Missing artifacts — log warning, continue with available
- **MAX_CYCLES Reached**: Report status, provide `/orchestrate {N}` resume instruction
- **MAX_INFRA_FAILURES Reached**: Report a connectivity problem distinct from work-budget exhaustion (`cycle_count` unaffected), provide `/orchestrate {N}` resume instruction once connectivity is confirmed
