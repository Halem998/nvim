---
description: Execute a task autonomously through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read
argument-hint: TASK_NUMBERS [PROMPT]
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

- Multi-task mode uses dependency-aware wave dispatch. `--team` flag not supported.
- No confirmation gates between lifecycle phases
- Terminates automatically on success, MAX_CYCLES exceeded, MAX_INFRA_FAILURES exceeded (repeated Agent-tool transport/API failures — a distinct connectivity-vs-work-budget diagnosis), or unrecoverable blocker
- In multi-task mode, failure in one task does not block other tasks in the same wave, but DOES block dependent tasks in later waves

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based tasks | false |
| `--dry-run` | Report-only: run the full admission analysis and print the verdict report; dispatch nothing and mutate nothing | false |
| `--allow-self-modifying` | Opt-in bypass of the self-modification admission gate for this invocation only; requires deliberate human intent — never a general-purpose weakening | false |

## Anti-Bypass Constraint

**PROHIBITION**: All lifecycle phases (research, plan, implement) MUST be executed by delegating
to `skill-orchestrate` via the Skill tool. Never run research/plan/implement directly from this
command.

## Execution

### STAGE 0: PARSE AND DISPATCH

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS (space-separated), FOCUS_PROMPT, REMAINING_ARGS, DRY_RUN_FLAG,
#          ALLOW_SELF_MODIFYING_FLAG
focus_prompt="${FOCUS_PROMPT:-}"
```

`ALLOW_SELF_MODIFYING_FLAG` (default `"false"`) is read here from the sourced parser and passed
into the Skill delegation context below as `allow_self_modifying`, alongside `lit_flag` — a
consumer-side-only signal that is never forwarded to `orchestrate-batch-admit.sh` itself.

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

**Dry-run prohibition block**: in dry-run mode, this command MUST NOT continue to MULTI-TASK
DISPATCH, MUST NOT reach CHECKPOINT 1 (GATE IN), MUST NOT invoke the Skill or Agent tools, MUST
NOT acquire a task lock, and MUST NOT run CHECKPOINT 3 (COMMIT). This mirrors the Anti-Bypass
Constraint above: just as that constraint prohibits running lifecycle phases without delegating
through `skill-orchestrate`, this constraint prohibits a `--dry-run` invocation from reaching ANY
lifecycle phase at all — the STOP HERE above is absolute, not advisory.

If `len(TASK_NUMBERS) == 1`: extract `task_number=$(echo "$TASK_NUMBERS" | awk '{print $1}')` and fall through to CHECKPOINT 1: GATE IN.

If `len(TASK_NUMBERS) > 1`: continue to MULTI-TASK DISPATCH below.

---

### MULTI-TASK DISPATCH

#### Step 1: Batch Validation

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

#### Step 1.5: Pre-Dispatch Review

Call the shared review script against `validated_tasks` in its default report-only mode, and
print its findings as loud, non-blocking warnings:

```bash
bash .claude/scripts/orchestrate-predispatch-review.sh "${validated_tasks[@]}"
```

This call is **advisory-loud, never blocking**: it is a REVIEW stage, not a fifth admission gate.
`--dry-run` already exists as the abort-before-dispatch surface for a human who wants to see the
full picture before anything runs; exclusion/deferral authority for the self-modification and
cross-batch file_scope-collision findings this call surfaces (Classes C and D) stays exactly
where it already was — the runtime wave-split check below, immediately before each wave's
dispatch. See `context/patterns/batch-orchestration-guardrails.md`'s Blocking vs. Advisory
criterion for the general rule this call follows: Step 1.5 never aborts the invocation on its
own account, regardless of how many findings it prints.

The findings run BEFORE Step 2 below on purpose — Step 2 is the last point at which
`validated_tasks`' RAW, unfiltered `dependencies[]` is still visible, before it is narrowed to
an intra-batch-only view for wave assignment.

#### Step 2: Dependency Graph Construction

For each task in `validated_tasks`, read its `dependencies` field from state.json. Restrict to
**intra-batch dependencies only** (ignore dependencies on tasks not in `validated_tasks`). This
intra-batch restriction is a wave-assignment concern, not a silent discard: Step 1.5 above has
already classified and reported every raw edge this step is about to narrow, including the
out-of-batch and nonexistent cases Non-Negotiable 3 requires visibility into.

```bash
# Build adjacency map: task -> list of validated predecessors it depends on
declare -A predecessors   # predecessors[$task] = space-separated list of intra-batch deps
declare -A in_degree      # in_degree[$task] = count of intra-batch predecessors

for task_num in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' \
    specs/state.json)
  intra_deps=()
  for dep in $deps; do
    # Only include deps that are also in validated_tasks
    if [[ " ${validated_tasks[*]} " == *" $dep "* ]]; then
      intra_deps+=("$dep")
    fi
  done
  predecessors[$task_num]="${intra_deps[*]}"
  in_degree[$task_num]=${#intra_deps[@]}
done
```

#### Step 3: Topological Wave Assignment (Kahn's Algorithm)

```bash
# Initialize: collect tasks with no intra-batch predecessors into Wave 0
declare -A wave_assignment
waves=()
remaining=("${validated_tasks[@]}")

wave_num=0
while [ ${#remaining[@]} -gt 0 ]; do
  ready=()
  next_remaining=()

  for task in "${remaining[@]}"; do
    if [ "${in_degree[$task]}" -eq 0 ]; then
      ready+=("$task")
      wave_assignment[$task]=$wave_num
    else
      next_remaining+=("$task")
    fi
  done

  # Circular dependency detection: if no tasks are ready but remaining is non-empty
  if [ ${#ready[@]} -eq 0 ]; then
    echo "[ERROR] Circular dependency detected among tasks: ${remaining[*]}"
    echo "Aborting multi-task orchestration."
    return 1
  fi

  waves+=("${ready[*]}")
  remaining=("${next_remaining[@]}")

  # Decrement in-degree for tasks whose predecessor just completed this wave
  for completed in "${ready[@]}"; do
    for task in "${remaining[@]}"; do
      if [[ " ${predecessors[$task]} " == *" $completed "* ]]; then
        in_degree[$task]=$(( ${in_degree[$task]} - 1 ))
      fi
    done
  done

  wave_num=$(( wave_num + 1 ))
done
```

Wave assignment summary: tasks in Wave 0 have no intra-batch predecessors and run first. Tasks in Wave 1 depend only on Wave 0 tasks, and so on. All tasks within a wave are independent and can run in parallel.

**File-safety is a property of `dependencies[]` accuracy**: Wave assignment above places two
tasks in the same wave whenever no `dependencies[]` edge connects them. Since task creation
(Multi-Task Creation Standard Component 4a) now auto-adds a serializing `dependencies[]` edge
whenever two tasks' `file_scope` overlaps, tasks created together in the same batch are
file-safe "for free" — no change to the Kahn's-algorithm ordering itself was required. The
residual gap is **cross-batch**: two tasks created in *separate* batches (each created
independently, in unrelated `/task` or `/orchestrate` invocations) have no creation-time
overlap comparison between them, so `dependencies[]` may not encode a real file conflict. The
runtime wave-split check below closes that gap.

**Runtime wave-split check (cross-batch defense-in-depth)**: this subsection is illustrative of
the CONTRACT `skill-orchestrate` fulfills, not code this file itself runs. Step 4 below builds
`waves_json` wholesale from the pre-computed wave schedule and hands the ENTIRE schedule to a
SINGLE `skill-orchestrate` Skill call — this file never loops waves and never itself invokes
`orchestrate-batch-admit.sh`. The sole EXECUTING admission gate is
`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5, which re-evaluates `eligible_tasks` every CYCLE
(re-derived fresh each time from current task statuses and the dependency graph), not once per
entry of the pre-computed `waves[]` array. Do not add a real per-wave dispatch loop to this file
to make the illustration literal — Step 4's `for wave_tasks in "${waves[@]}"` loop only
serializes JSON and must stay that way.

The bash block below is retained as an illustration of that contract, with the argument corrected
to match what the skill actually passes:

```bash
bash .claude/scripts/orchestrate-batch-admit.sh --invocation-count "${#wave_tasks[@]}" "${wave_tasks[@]}"
```

`--invocation-count` carries the actual co-dispatch count for the cycle/wave being evaluated
(`${#wave_tasks[@]}` here, `${#eligible_tasks[@]}` at the skill's own per-cycle call site) — never
the whole invocation's full validated-candidate count. A `dependencies[]`-edge-connected pair can
never share that count in the first place (the skill's own eligibility rule guarantees a successor
is never eligible until its predecessor terminates), so a whole-invocation count would fire
against pairs that never actually co-occur.

This compares each wave task's `file_scope` against every non-terminal task in a single
`specs/state.json` read — not just the tasks already collected into `validated_tasks` for this
invocation. This is still not a repo-wide filesystem scan: no globbing, no second read, just one
read of `specs/state.json` per invocation. The predicate itself is the shared directory-prefix
overlap algorithm in `.claude/context/patterns/file-footprint-overlap.md` (referenced by path —
the rule is not restated here); the verdict schema is published in
`.claude/docs/architecture/batch-admit-schema.md` (also referenced by path, never restated).

`jq`-filter stdout for `.decision == "defer"`, then branch on `defer_reason` FIRST (schema v3 —
every defer verdict carries this REQUIRED discriminator; do not fall through to a
`collision_scope`-only branch without checking it first, or a self-modifying defer is
misread as an ordinary in-batch collision):

- **`self_modifying`** (the candidate's own `file_scope` names an orchestrator-critical path —
  see `context/patterns/batch-orchestration-guardrails.md`'s "Self-Modification Hazard" section):
  defer the candidate out of the current wave/cycle — it becomes eligible again on a later one,
  once its co-dispatched sibling leaves eligibility — and log a **distinct** warning naming the
  matched critical path and label. `--allow-self-modifying` (see `## Options` above) is the
  deliberate, human-intent escape hatch for the residual co-dispatch case: when active, the
  actual consumer (`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5) dispatches the candidate
  anyway rather than acting on this defer verdict; the flag is never passed to
  `orchestrate-batch-admit.sh` itself. The deferred task is neither marked failed nor blocked — it
  simply is not dispatched this wave/cycle:
  ```
  [orchestrate] WARNING: Task #{task_number} has file_scope naming orchestrator-critical
    path {critical_path} ({critical_label}), co-dispatched this wave/cycle alongside another
    candidate. Deferring #{task_number} to a later cycle — it becomes eligible again once its
    co-dispatched sibling leaves eligibility. Pass --allow-self-modifying to override.
  ```

  **Post-dispatch counterpart**: this check reads a task's *declared* `file_scope`,
  pre-dispatch. A task whose *actual* `modified_files` touch a critical path — as distinct from
  what it declared — is invisible here and is instead caught after dispatch by the inter-cycle
  redeploy checkpoint in `skill-orchestrate` Stage MT-3 step 7. See
  `context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
  subsection for that contract; it is not restated here.
- **`file_scope_collision`** — retains the exact pre-existing `collision_scope` branching below,
  byte-for-byte:
  - **`in_batch`** (the colliding task is itself in this wave): defer the named task to the next
    wave — existing behavior, existing warning format preserved:
    ```
    [orchestrate] WARNING: Wave {N} tasks #{X} and #{Y} have overlapping file_scope
      ({path}) with no dependencies[] edge between them. Deferring #{Y} to wave {N+1}
      to avoid concurrent edits to the same files.
    ```
  - **`cross_batch`** (the colliding task is NOT part of this invocation): exclude the candidate
    from this invocation's admitted set and log a **distinct** warning naming the out-of-batch
    task and its `colliding_task_status`, so the transcript distinguishes "resolves by waiting one
    wave" from "this batch's composition is contested":
    ```
    [orchestrate] WARNING: Task #{task_number} has overlapping file_scope ({path}) with
      task #{colliding_task_number} (status: {colliding_task_status}), which is OUTSIDE
      this invocation's batch. Excluding #{task_number} from this run — batch composition
      needs human review.
    ```

**Defer-not-fail invariant**: this check never marks a task failed and never mutates
`specs/state.json` — a `defer` verdict only changes which wave (or whether this invocation at
all) a task is dispatched in. This applies identically to the `self_modifying` defer_reason: the
excluded task is neither failed nor marked blocked, and this script never writes to
`specs/state.json`.

**Degradation path**: exit 2 from `orchestrate-batch-admit.sh` means state is unavailable
(missing `jq` or an unreadable `specs/state.json`). In that case, log a loud warning and proceed
without the check — orchestration cannot function at all under that condition regardless of this
check, so proceeding is not a silent weakening of the gate.

This check is cheap (one `specs/state.json` read per invocation) and never silent. If it proves
too aggressive in practice (over-splitting waves), it can be relaxed to warn-only by editing this
section and the mirrored section in `.claude/skills/skill-orchestrate/SKILL.md` — see
Rollback/Contingency in the originating plan
(`specs/787_file_footprint_aware_dependencies/plans/01_file-footprint-aware-dependencies.md`).

#### Step 4: Wave Execution

Generate the batch session ID:

```bash
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**MAX_TASKS Guard**: Before entering multi-task dispatch, check task count:

```bash
task_count=${#validated_tasks[@]}
MAX_TASKS=8
if [ "$task_count" -gt "$MAX_TASKS" ]; then
  echo "[orchestrate] WARNING: $task_count tasks exceeds MAX_TASKS=$MAX_TASKS."
  echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
  # Recalculate waves for the trimmed task list
fi
```

**Single-Dispatch Multi-Task Mode**: Build the dependency graph JSON and waves JSON for passing to the skill, then invoke a single `skill-orchestrate` instance that manages all tasks internally:

```bash
# Build dependency_graph JSON: {"task_num": [dep1, dep2], ...}
dep_graph_json=$(jq -n '{}')
for task_num in "${validated_tasks[@]}"; do
  deps_array=$(jq -n --argjson deps "$(printf '%s\n' "${predecessors[$task_num]}" | jq -R . | jq -s .)" '$deps')
  dep_graph_json=$(echo "$dep_graph_json" | jq --arg key "$task_num" --argjson deps "$deps_array" \
    '. + {($key): $deps}')
done

# Build waves JSON: [[task_a, task_b], [task_c], ...]
waves_json=$(jq -n '[]')
for wave_tasks in "${waves[@]}"; do
  wave_array=$(printf '%s\n' $wave_tasks | jq -R 'tonumber' | jq -s '.')
  waves_json=$(echo "$waves_json" | jq --argjson wave "$wave_array" '. + [$wave]')
done

# Build task_numbers JSON array
task_numbers_json=$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')
```

Invoke a single `skill-orchestrate` instance with all task context:

```
Tool: Skill
Parameters:
  skill: "skill-orchestrate"
  args: "multi_task_mode=true task_numbers={task_numbers_json} waves={waves_json} dependency_graph={dep_graph_json} session_id={batch_session_id} focus_prompt={focus_prompt} lit_flag={LIT_FLAG} allow_self_modifying={ALLOW_SELF_MODIFYING_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{batch_session_id}",
  "multi_task_mode": true,
  "task_numbers": [42, 43, 44],
  "waves": [[42], [43, 44]],
  "dependency_graph": {"42": [], "43": [42], "44": [42]},
  "focus_prompt": "{focus_prompt}",
  "lit_flag": "{LIT_FLAG}",
  "allow_self_modifying": "{ALLOW_SELF_MODIFYING_FLAG}"
}
```

The skill manages wave-by-wave dispatch, per-task postflight (status sync + artifact linking), and writes results to `specs/.orchestrator-multi-state-${batch_session_id}.json`.

#### Step 5: Commit Reconciliation and Consolidated Output

After the single `skill-orchestrate` invocation completes, read results from `specs/.orchestrator-multi-state-${batch_session_id}.json` and produce a residue check (non-blocking) and consolidated output.

```bash
mt_state_file="specs/.orchestrator-multi-state-${batch_session_id}.json"
mt_state_file_valid="false"
if [ -f "$mt_state_file" ]; then
  file_session_id=$(jq -r '.session_id // ""' "$mt_state_file")
  if [ "$file_session_id" = "$batch_session_id" ]; then
    mt_state_file_valid="true"
  else
    echo "[orchestrate] ERROR: Multi-state file session_id mismatch — ${mt_state_file} carries session_id '${file_session_id}', this invocation is '${batch_session_id}'. Refusing to consume a foreign session's batch state; treating the file as missing. Stage MT-1 always initializes fresh (no resume-on-exists branch), so a mismatch here can only mean a real bug (stale variable reuse or a wrongly resolved path), never an expected condition."
  fi
fi
if [ "$mt_state_file_valid" = "true" ]; then
  completed_tasks=$(jq -r '.completed_tasks[]' "$mt_state_file" 2>/dev/null | tr '\n' ' ')
  failed_tasks_json=$(jq -c '.failed_tasks // []' "$mt_state_file")
  cycles_used=$(jq -r '.cycle_count // 0' "$mt_state_file")
  max_cycles=$(jq -r '.max_cycles // 25' "$mt_state_file")
  succeeded_count=$(jq '.completed_tasks | length' "$mt_state_file")
  failed_count=$(jq '.failed_tasks | length' "$mt_state_file")
  # Forward-progress invariant fields (additive; see
  # context/patterns/batch-orchestration-guardrails.md's "### The Forward-Progress Invariant").
  fpv_field_present=$(jq 'has("forward_progress_violated")' "$mt_state_file")
  dispatch_start_ts_present=$(jq 'has("dispatch_start_ts")' "$mt_state_file")
  forward_progress_violated=$(jq -r '.forward_progress_violated // false' "$mt_state_file")
  defer_ledger_json=$(jq -c '.defer_ledger // []' "$mt_state_file")
  tasks_deferred_self_modifying_json=$(jq -c '.deferred_self_modifying // []' "$mt_state_file")
else
  if [ ! -f "$mt_state_file" ]; then
    echo "[orchestrate] WARNING: Multi-state file missing (looked for specs/.orchestrator-multi-state-${batch_session_id}.json) — skill may have been interrupted"
  fi
  completed_tasks=""
  failed_tasks_json="[]"
  cycles_used=0
  succeeded_count=0
  failed_count=${#validated_tasks[@]}
  # Missing-multi-state-file branch: this is NOT a zero-dispatch outcome (it is a distinct
  # missing-state failure mode, already handled by the failed_count line above) — never fire the
  # banner here.
  fpv_field_present="false"
  dispatch_start_ts_present="false"
  forward_progress_violated="false"
  defer_ledger_json="[]"
  tasks_deferred_self_modifying_json="[]"
fi
skipped_count=${#skipped_tasks[@]}
```

**Three-branch, all-non-silent invariant resolution** (works regardless of which skill ran —
`skill-orchestrate` writes `forward_progress_violated` directly per Phase 3 above;
`skill-orchestrate-hard`'s multi-task mode delegates to the SAME base MT stages per its own Stage
0, so it already inherits the field too — see that file's Stage 0 statement. This three-branch
shape exists as a forward-compatible safety net for any future MT variant that might omit the
field, not because one exists today):

1. **`forward_progress_violated` present in `mt_state_file`** (`fpv_field_present == "true"`) —
   use it directly: `forward_progress_violated` from above.
2. **Field absent but `dispatch_start_ts` present** (`fpv_field_present == "false"` AND
   `dispatch_start_ts_present == "true"`) — compute the invariant here:
   ```bash
   if [ "$fpv_field_present" = "false" ] && [ "$dispatch_start_ts_present" = "true" ]; then
     dispatch_start_ts_empty=$(jq '.dispatch_start_ts == {}' "$mt_state_file")
     if [ "$dispatch_start_ts_empty" = "true" ] && [ "${#validated_tasks[@]}" -gt 0 ]; then
       forward_progress_violated="true"
     else
       forward_progress_violated="false"
     fi
   fi
   ```
3. **Neither present** (`fpv_field_present == "false"` AND `dispatch_start_ts_present == "false"`,
   and `$mt_state_file` itself is present — the missing-file branch above already set all three
   to a fixed "false"/"[]" and is excluded from this branch) — print an explicit notice and
   render the ordinary output, never silently skip:
   ```bash
   if [ -f "$mt_state_file" ] && [ "$fpv_field_present" = "false" ] && [ "$dispatch_start_ts_present" = "false" ]; then
     echo "[orchestrate] forward-progress invariant not evaluable (no dispatch_start_ts in multi-state file)"
     forward_progress_violated="false"
   fi
   ```

`validated_count=${#validated_tasks[@]}` — computed once here for use in the ZERO DISPATCH
section's banner/marker below (`{validated_count}` in the Consolidated Output template).

**Commit Reconciliation (no batch commit)**:

MT mode no longer produces one combined end-of-batch commit here. Per-task commits are issued
inside `skill-orchestrate`'s own per-task postflight loop (Stage MT-4 step 5.5), one commit per
task per phase transition, using that task's own `task_dir` and self-reported `modified_files` —
see `.claude/context/standards/git-staging-scope.md`'s "Multi-Task Application" subsection for the
authoritative per-task scope contract. The combined commit that used to run here was retired
because it entangled every task in the requested range into a single unrevertable commit,
mixing N tasks' diffs and index rows and defeating per-task revert (see
`.claude/context/patterns/batch-orchestration-guardrails.md`'s hazard 2 for the retired hazard this
closes).

This step now runs only a defensive, non-blocking residue check — it WARNS ONLY and never
commits, because a blanket commit here would recreate exactly the entanglement being removed:

**Ordering relative to the inter-cycle redeploy checkpoint**: per-task commits at Stage MT-4
step 5.5 always precede the inter-cycle redeploy checkpoint (`skill-orchestrate` Stage MT-3 step
7) — a wave's work is committed before the tree it produced is redeployed over. See
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection ("Sequencing") for the full statement of this guarantee; it is not restated here.

```bash
residue=$(git status --porcelain -- specs/ 2>/dev/null)
if [ -n "$residue" ]; then
  echo "[orchestrate] WARNING: uncommitted residue under specs/ after batch completion:" >&2
  echo "$residue" >&2
  echo "[orchestrate] Per-task commits are issued inside the skill's per-task postflight; review and commit manually." >&2
fi
```

**Exit-path coverage** — every MT terminal outcome and where its commit is issued:

| Outcome | Commit issued where |
|---------|---------------------|
| `completed` | Stage MT-4 step 5.5, at the task's own postflight iteration (message: complete research/plan/implementation, per that task's `dispatch_status`) |
| `failed` | Stage MT-4 step 5.5 still runs for a failed dispatch; artifacts and status changes it produced are real and committed |
| `blocked` | Stage MT-4 step 5.5 still runs; same reasoning as `failed` |
| Partial (gate-refused, or `MAX_CYCLES_MT` reached mid-loop) | Stage MT-4 step 5.5 runs at the partial-form message on every cycle that reaches it, including the cycle where `MAX_CYCLES_MT` is hit |
| Deferred self-modifying (a task whose own dispatch is deferred rather than run this cycle) | Never dispatched and never status-mutated this cycle, so it correctly produces no commit this cycle — it becomes eligible, and committable, on a later cycle |
| Deferred-by-redeploy-checkpoint (a task excluded for the remainder of the invocation because the inter-cycle redeploy checkpoint's deploy/verify gate failed) | Never dispatched and never status-mutated for the rest of this invocation; distinct operator remedy from deferred-self-modifying — see `### The Inter-Cycle Redeploy Checkpoint` in `context/patterns/batch-orchestration-guardrails.md` |

**Re-run sequence derivation (for the ZERO DISPATCH section below)**: reuse the `waves` array
already computed at Step 3 above — do not recompute or reimplement Kahn's algorithm. For each
wave in order, list its deferred/excluded task numbers ascending by number, one `/orchestrate {N}`
line per task, predecessor-first. This is printed for the operator to run, and is never executed
automatically — see the Phase 1 `## Rejected Approaches` entry in
`context/patterns/batch-orchestration-guardrails.md` ("Auto-degrading a zero-dispatch batch...").

**Consolidated Output**:

```markdown
## Batch Orchestrate Results

Session: {batch_session_id}
Tasks requested: {count}
Succeeded: {succeeded_count}
Failed: {failed_count}
Skipped: {skipped_count}
Cycles used: {cycles_used}/{max_cycles}

### ZERO DISPATCH

(Rendered only when `forward_progress_violated` resolved true above. Placed immediately after the
counts block and BEFORE `### Succeeded` — never omitted, never demoted below the ordinary tables.)

[ZERO DISPATCH - 0 of {validated_count} validated candidates dispatched; forward-progress invariant violated]
<!-- forward-progress violated=true dispatched=0 validated={validated_count} -->

This is not a failure: no task was marked failed or blocked and `specs/state.json` was not
mutated (see `context/patterns/batch-orchestration-guardrails.md`'s
`### The Forward-Progress Invariant` subsection).

| Task | defer_reason | Detail |
|------|--------------|--------|
| #10 | self_modifying | matched critical path .claude/scripts/task-lock.sh (concurrency lock) |
| #11 | file_scope_collision | colliding out-of-batch task #{N} (status: implementing) |

Re-run sequence (dependency order; printed, not executed):
```
/orchestrate 10
/orchestrate 11
```

### Succeeded

| Task | Title | Final Status |
|------|-------|--------------|
| #42 | task_title | [COMPLETED] |

### Failed

| Task | Error |
|------|-------|
| #43 | Partial: blockers present (no continuation) |

### Skipped

| Task | Reason |
|------|--------|
| #44 | predecessor #43 failed |
| #99 | terminal status [ABANDONED] |

### Deferred (self-modifying)

(Renders on every batch, not only zero-dispatch ones — populated from
`tasks_deferred_self_modifying_json`, each task's FINAL status at loop exit, per Stage MT-5 step
4's reporting instruction in `skill-orchestrate/SKILL.md`.)

| Task | Final Status | Note |
|------|--------------|------|
| #21 | [COMPLETED] | deferred at least one cycle by the self-modification gate — an OBSERVATION; went on to complete before loop exit |
| #22 | still pending | deferred, not yet redispatched this invocation — remains eligible for a future `/orchestrate` run (solo or batched) or `--allow-self-modifying` |

### Deferred (other admission exclusions)

(Populated from `defer_ledger` entries whose `defer_reason` is neither `self_modifying` nor
`deploy_checkpoint` — i.e. `file_scope_collision` deferrals — so they are visible on ordinary
partial batches too, not only inside the ZERO DISPATCH section above.)

| Task | defer_reason | collision_scope | Detail |
|------|--------------|------------------|--------|
| #23 | file_scope_collision | cross_batch | colliding out-of-batch task #{N} (status: implementing) |

### Deferred (redeploy checkpoint)

| Task | Reason |
|------|--------|
| #55 | inter-cycle redeploy checkpoint gate failed ({gate}, exit {code}); not dispatched for the remainder of this invocation |

Operator remedy (distinct from a deferred-self-modifying task): resolve the deploy/verify
failure, redeploy manually, then re-run `/orchestrate` on the remaining task numbers. See
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection for the full contract; not restated here.

### Next Steps
- Re-run failed tasks: /orchestrate {failed_task_numbers}
- **When ZERO DISPATCH fired**: there are no failed tasks to re-run — point at the re-run
  sequence in the ZERO DISPATCH section above instead of this line.
```

**After consolidated output, STOP. Do not continue to CHECKPOINT 1.**

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
args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true lit_flag={LIT_FLAG}"
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
  "lit_flag": "{LIT_FLAG}"
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
```

**On partial:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: orchestration paused (cycles {M}/{MAX})" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
```

Commit failure is non-blocking (log and continue).

## Output

**Completion**: `Orchestration complete for Task #{N}` | Final status: `[COMPLETED]` | Cycles: M/5

**Partial**: `Orchestration paused for Task #{N}` | Status: `[{STATUS}]` | Cycles: M/5 | `Next: /orchestrate {N}`

**Blocked**: `Task #{N} requires manual intervention` | Blocker description | Suggested actions

**`--dry-run`**: the printed admission report only — no status transition, no cycle consumed, no commit. The invocation ends after the report; nothing else in this Output section applies to a `--dry-run` run.

## Error Handling

- **GATE IN Failure**: Task not found or in terminal state — return error with guidance
- **DELEGATE Failure**: Keep current status, log error; loop guard preserved for resume
- **GATE OUT Failure**: Missing artifacts — log warning, continue with available
- **MAX_CYCLES Reached**: Report status, provide `/orchestrate {N}` resume instruction
- **MAX_INFRA_FAILURES Reached**: Report a connectivity problem distinct from work-budget exhaustion (`cycle_count` unaffected), provide `/orchestrate {N}` resume instruction once connectivity is confirmed
