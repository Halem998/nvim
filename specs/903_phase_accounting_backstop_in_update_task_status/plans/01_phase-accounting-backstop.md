# Implementation Plan: Task #903

- **Task**: 903 - Add an optional phase-accounting backstop to update-task-status.sh implement postflight
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/903_phase_accounting_backstop_in_update_task_status/reports/01_phase-accounting-backstop.md
- **Artifacts**: plans/01_phase-accounting-backstop.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add an optional, additive `--phase-check=warn|refuse` flag to
`agent-system/extensions/core/scripts/update-task-status.sh` that, when present, independently
counts the task plan file's own `### Phase N: {name} [STATUS]` headings and blocks (or warns
about) a `postflight ... implement` transition when conclusive on-disk evidence shows phases are
still incomplete. The flag is absent by default, so every existing call site's behavior is
preserved byte-for-byte until it is separately edited to opt in. After the script change, the
flag is threaded caller-by-caller — `refuse` at the sites with zero phase gate today, `warn`
where a SKILL-layer gate already made an informed decision — with an empirical validation phase
in between that gates the `refuse` rollout on real completed-task plan files.

### Research Integration

Findings carried forward verbatim from the research report:

- **Defect confirmed and re-verified in this planning pass**: `update-task-status.sh` line 154
  (`postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;`) inside
  `map_status()`, and `update_plan_file()` (lines 295-350) which sets `plan_status="COMPLETED"`
  at line 304 and stamps the plan via `update-plan-status.sh` at line 340. Both fire from ONE
  code path (`operation=postflight, target_status=implement`), so a **single early gate placed
  before `acquire_state_mutex` (line 269) blocks both effects at once** — exploited in Phase 2
  rather than gating twice.
- **Call-site inventory: 12 sites.** Only the 3 orchestrate sites (`skill-orchestrate` Stage 5,
  Stage MT-4, `skill-orchestrate-hard`) have any phase gate today, and it depends entirely on the
  dispatched agent's self-reported `.orchestrator-handoff.json`. The other 9 —
  `skill-implementer`, `skill-implementer-hard`, the lean/cslib extension implementers (4),
  both `reconcile-task-status.sh` repair branches, and `command-gate-out.sh` — have ZERO phase
  awareness and together carry the majority of real `/implement` traffic.
- **Evidence source**: the script resolves the plan file from `task_number` alone, reusing the
  existing `project_name` -> `plan_dir` -> version-ordered-`ls` logic already inline in
  `update_plan_file()` (lines 307-322 and 356-375). Parsing target is
  `### Phase N: {name} [STATUS]` — the same regex `update-phase-status.sh` already uses. **Raw
  `- [ ]`/`- [x]` checkbox counting was EVALUATED AND REJECTED as unreliable and is not
  reintroduced anywhere in this plan.**
- **Backward compatibility is binding**: the flag is absent by default; phase accounting is never
  a required argument; no caller ever supplies a phase count (the script gathers evidence
  itself, which is the whole point of a backstop).
- **Composition, not contradiction**: the existing SKILL-layer gate deliberately PASSES THROUGH
  when `phases_total` is 0. The script layer mirrors this exactly — no plan file, or zero
  conforming phase headings, is INCONCLUSIVE and always passes through — so the two layers never
  disagree on the meaning of "no data".

Anchors re-verified by quoted text during planning (all in
`agent-system/extensions/core/`):

| Anchor | Verified quoted text |
|--------|----------------------|
| `scripts/update-task-status.sh:154` | `    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;` |
| `scripts/update-task-status.sh:269` | `acquire_state_mutex` |
| `scripts/update-task-status.sh:304` | `    postflight) plan_status="COMPLETED" ;;` |
| `scripts/reconcile-task-status.sh:344` and `:380` | `      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"` |
| `scripts/command-gate-out.sh:94` | `    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" 2>/dev/null || \` |
| `scripts/skill-base.sh:365` | `      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"` |
| `skills/skill-implementer/SKILL.md:444` | `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"` |
| `skills/skill-implementer-hard/SKILL.md:323` | `  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"` |

**Planning-pass correction to the research report**: the three orchestrate sites do NOT invoke
`update-task-status.sh` directly — they call the shared helper `skill_postflight_update` in
`scripts/skill-base.sh` (line 356), which performs the invocation at line 365. The `warn` opt-in
for those sites is therefore threaded as an **optional 5th argument to
`skill_postflight_update`** (Phase 6), not as a direct flag edit in the orchestrate SKILL files.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `--phase-check=warn|refuse` to `update-task-status.sh` with strict enum validation, new
  exit code 4 for refusal, and `--dry-run` always previewing and exiting 0.
- Gather phase evidence independently in-script from `### Phase N: ... [STATUS]` headings, with
  no new required or positional arguments.
- Place a single early gate that blocks BOTH the state.json flip and the plan-file `[COMPLETED]`
  stamp before any mutex acquisition or write.
- Thread the flag per call site: `refuse` at the zero-gate sites, `warn` where a SKILL-layer gate
  already decided.
- Prove empirically, before the `refuse` rollout, that real completed tasks' plan files do carry
  all-`[COMPLETED]` phase headings.
- Prove that the no-flag default is byte-for-byte unchanged for existing callers.

**Non-Goals**:
- Making phase accounting on by default, or a required argument.
- Checkbox (`- [ ]`/`- [x]`) counting in any form.
- Accepting caller-supplied `--phases-completed`/`--phases-total` values.
- Changing the existing SKILL-layer handoff gate's logic or its `phases_total == 0`
  pass-through.
- Editing anything under `.claude/` (gitignored, untracked, disposable deploy artifact).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `refuse` produces false refusals if agents complete work but never update plan-file phase headings | H | M | Phase 3 is a dedicated empirical validation gate against real recent `[COMPLETED]` tasks using `--dry-run --phase-check=refuse`; the `refuse` rollout (Phases 4-5) does not begin until it passes |
| Malformed/non-conforming phase headings under/over-count | M | M | Count only headings matching the exact conforming shape; exclude non-conforming lines from BOTH totals rather than erroring — matches the `|| true` / `// 0` graceful-degradation style used throughout these scripts |
| `grep -c` exits 1 on zero matches under `set -euo pipefail`, aborting the script | H | M | Use the `VAR=$(grep -c ...) || VAR=0` assignment form (never `$(grep -c ... || echo 0)`, which emits two lines) — see Phase 2 exact text |
| `reconcile-task-status.sh` refusal leaves a task stuck in `implementing`/`partial` | M | M | Accepted: a stuck-but-honestly-labeled task is strictly safer than a silently-wrong `[COMPLETED]`. Both branches already `echo "[reconcile] ..."` loudly, so refusals are visible |
| Conflating exit 4 (refusal) with exits 2/3 (genuine failure) at callers | M | H | Every caller edit captures the exit code into a variable and branches on `-eq 4` distinctly from `-ne 0` |
| Empty-array expansion `"${arr[@]}"` under `set -u` on older bash | M | L | Reuse the exact pattern already proven in this codebase: `reconcile-task-status.sh` line 190-194's `dry_run_flag=()` / `"${dry_run_flag[@]}"` |
| Edits land in `.claude/` instead of the source store | H | M | Every phase's file list names only `agent-system/extensions/**` paths; Phase 7 verification greps `.claude/` for the flag and asserts the source store is authoritative |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 4, 5, and 6 touch disjoint file sets
(scripts / core skills / shared helper + orchestrate + extension skills) and are territory-safe
to run concurrently.

---

### Phase 1: Flag surface — parse, validate, document [COMPLETED]

**Goal**: Add `--phase-check=warn|refuse` argument parsing, strict enum validation, and header
documentation (including new exit code 4) to `update-task-status.sh`. No behavior change yet:
the parsed value is not consumed by anything in this phase.

**Tasks**:
- [x] Update the header usage line and exit-code block *(completed)*
- [x] Add `PHASE_CHECK` parsing to the argument loop *(completed)*
- [x] Add strict enum validation *(completed)*
- [x] Update the usage error message *(completed)*
- [x] `bash -n` syntax check *(completed)*

**Exact replacement text** (all in
`agent-system/extensions/core/scripts/update-task-status.sh`):

1. Header usage line (line 10). Replace:
```
#   .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready]
```
with:
```
#   .claude/scripts/update-task-status.sh <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready] [--phase-check=warn|refuse]
```

2. Exit-code block (lines 21-27). Replace:
```
# Exit codes:
#   0 - Success or no-op (already at target status)
#   1 - Validation error (bad arguments)
#   2 - state.json update failed
#   3 - plan file update failed after state.json was written, on implement postflight only
#       (retry after fixing the plan file; the state.json write is idempotent and will no-op
#       on retry, so the plan/phase updates re-fire and the retry is genuinely effective)
```
with:
```
# Exit codes:
#   0 - Success or no-op (already at target status)
#   1 - Validation error (bad arguments)
#   2 - state.json update failed
#   3 - plan file update failed after state.json was written, on implement postflight only
#       (retry after fixing the plan file; the state.json write is idempotent and will no-op
#       on retry, so the plan/phase updates re-fire and the retry is genuinely effective)
#   4 - Phase-accounting backstop refused the transition (the task's plan file shows incomplete
#       phases); no state.json write and no plan-file status stamp occurred. Only reachable when
#       --phase-check=refuse is explicitly passed on a postflight implement call.
#
# Optional flag: --phase-check=warn|refuse
#   Absent by default. When absent, this script behaves exactly as it did before the flag
#   existed. When present, and only when operation==postflight and target_status==implement,
#   the script independently counts the task plan file's own `### Phase N: ... [STATUS]`
#   headings (never a caller-supplied count) and acts on conclusive on-disk evidence of
#   incompleteness: `warn` logs loudly and proceeds, `refuse` exits 4 without writing anything.
#   Passing the flag with any other operation/target_status pair is silently ignored.
```

3. Argument parsing (lines 98-108). Replace:
```
DRY_RUN=false
ALLOW_PR_READY=false
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --allow-pr-ready) ALLOW_PR_READY=true ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done
```
with:
```
DRY_RUN=false
ALLOW_PR_READY=false
PHASE_CHECK=""
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --allow-pr-ready) ALLOW_PR_READY=true ;;
    --phase-check=*) PHASE_CHECK="${arg#--phase-check=}" ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done
```
(The `--phase-check=*` arm must precede the `*)` catch-all so the flag is never mistaken for a
positional argument. It does in the text above.)

4. Usage error message (line 117). Replace:
```
  echo "Usage: $0 <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready]" >&2
```
with:
```
  echo "Usage: $0 <operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready] [--phase-check=warn|refuse]" >&2
```

5. Enum validation. Insert immediately AFTER the `task_number` regex check block that ends with
`fi` at line 136, and BEFORE the `if [[ ! -f "$STATE_FILE" ]]; then` block at line 138:
```
# A typo'd --phase-check value must never SILENTLY disable the very protection the caller
# intended to enable, so a bad value is a hard validation error rather than a fallback to no-op.
if [[ -n "$PHASE_CHECK" && "$PHASE_CHECK" != "warn" && "$PHASE_CHECK" != "refuse" ]]; then
  echo "Error: --phase-check must be 'warn' or 'refuse', got '$PHASE_CHECK'" >&2
  exit 1
fi
```

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - header docs, flag parsing, enum
  validation, usage string

**Verification**:
- `bash -n agent-system/extensions/core/scripts/update-task-status.sh` exits 0
- `bash agent-system/extensions/core/scripts/update-task-status.sh postflight 903 implement s --phase-check=bogus` exits 1 with the new error message
- `bash agent-system/extensions/core/scripts/update-task-status.sh` with no args prints the
  updated usage string including `[--phase-check=warn|refuse]`
- A `--dry-run` run WITHOUT the flag produces output identical to the pre-change script (spot
  check; the rigorous byte-for-byte diff is Phase 7)

---

### Phase 2: Evidence gathering and the single early gate [NOT STARTED]

**Goal**: Add independent plan-file phase counting and the single early gate that blocks both the
state.json flip and the plan-file `[COMPLETED]` stamp, placed before `acquire_state_mutex`.

**Tasks**:
- [ ] Add `resolve_plan_file_for_phase_check()` and `count_plan_phases()`
- [ ] Add the gate block with its four verdict branches
- [ ] Confirm placement is before `mkdir -p "$TMP_DIR"` and therefore before `acquire_state_mutex`
- [ ] `bash -n` syntax check

**Exact insertion text**. Insert the entire block below into
`agent-system/extensions/core/scripts/update-task-status.sh` immediately AFTER the
`state_is_noop` block that ends at line 214 with:
```
state_is_noop=false
if [[ "$current_state_status" == "$STATE_STATUS" ]]; then
  state_is_noop=true
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Task $task_number already at status '$STATE_STATUS' -- state.json no-op"
  fi
fi
```
and BEFORE:
```
# --- Ensure tmp directory exists ---
mkdir -p "$TMP_DIR"
```

Text to insert:
```bash
# ============================================================
# PHASE 0: Phase-accounting backstop (opt-in via --phase-check)
# ============================================================
# Independent, script-side evidence gathering: this NEVER trusts a caller-supplied phase count.
# Accepting one would reproduce the exact fragility being fixed (a caller can pass wrong numbers
# just as easily as a handoff can omit them), so the only caller-supplied decision is the MODE.
#
# Evidence source is the plan file's own `### Phase N: {name} [STATUS]` headings -- the same
# single-line-per-phase contract plan-format.md fixes and update-phase-status.sh already treats
# as authoritative. Deliberately NOT `- [ ]`/`- [x]` checkbox counting: checkboxes are sub-phase
# task items whose granularity is unrelated to phase count, and they also appear in non-phase
# sections (e.g. "Testing & Validation"), so a whole-file checkbox ratio is not a phase signal.
#
# Plan-file resolution reuses update_plan_file()'s existing project_name -> plan_dir ->
# version-ordered-ls chain, so NO new argument is required: task_number (already a required
# positional) is sufficient.
#
# Conclusiveness convention: only "conforming phase headings exist AND at least one is not
# [COMPLETED]" is conclusive evidence of incompleteness. No plan file, no plan dir, or zero
# conforming phase headings is INCONCLUSIVE and always passes through -- deliberately mirroring
# the SKILL-layer gate's own `phases_total == 0` pass-through so the two layers never disagree
# on the meaning of "no data".
PHASE_CHECK_PLAN_FILE=""
PHASE_CHECK_TOTAL=0
PHASE_CHECK_DONE=0

resolve_plan_file_for_phase_check() {
  local project_name padded_num plan_dir plan_file
  project_name=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_name' \
    "$STATE_FILE")
  if [[ -z "$project_name" || "$project_name" == "null" ]]; then
    return 0
  fi
  padded_num=$(printf "%03d" "$task_number")
  plan_dir="$PROJECT_ROOT/specs/${padded_num}_${project_name}/plans"
  if [[ ! -d "$plan_dir" ]]; then
    plan_dir="$PROJECT_ROOT/specs/${task_number}_${project_name}/plans"
  fi
  [[ -d "$plan_dir" ]] || return 0
  # Version-ordered selection (not mtime-ordered), the same two-tier rule used by
  # update_plan_file()'s preflight branch, update-plan-status.sh, and update-phase-status.sh.
  plan_file=$(ls "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort | tail -1 || echo "")
  if [[ -z "$plan_file" ]]; then
    plan_file=$(ls "$plan_dir"/*.md 2>/dev/null | sort | tail -1 || echo "")
  fi
  [[ -n "$plan_file" && -f "$plan_file" ]] || return 0
  PHASE_CHECK_PLAN_FILE="$plan_file"
  return 0
}

count_plan_phases() {
  # A heading is counted only when it matches the exact conforming shape
  # `### Phase <N>: ... [<UPPERCASE STATUS>]` (trailing whitespace tolerated). Malformed headings
  # -- missing brackets, lowercase status, non-numeric N -- are excluded from BOTH totals rather
  # than raising an error, matching the graceful-degradation style used throughout these scripts.
  #
  # The `VAR=$(grep -c ...) || VAR=0` form is required, not cosmetic: `grep -c` exits 1 when it
  # matches nothing (which `set -e` would otherwise treat as fatal), and the tempting
  # `$(grep -c ... || echo 0)` form emits TWO lines ("0" from grep plus "0" from echo).
  PHASE_CHECK_TOTAL=$(grep -c '^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$' \
    "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_TOTAL=0
  PHASE_CHECK_DONE=$(grep -c '^### Phase [0-9][0-9]*:.*\[COMPLETED\][[:space:]]*$' \
    "$PHASE_CHECK_PLAN_FILE" 2>/dev/null) || PHASE_CHECK_DONE=0
}

# The gate runs BEFORE acquire_state_mutex below, so a refusal costs no mutex acquisition and no
# jq write. Because PHASE 1 (state.json flip) and PHASE 3 (update_plan_file's [COMPLETED] stamp)
# are both downstream of this point and both reachable only via this one
# operation=postflight/target_status=implement code path, this single gate blocks both of the
# defect's two effects at once.
#
# `state_is_noop == true` is excluded: a task already at 'completed' replaying postflight has
# nothing left to refuse.
if [[ -n "$PHASE_CHECK" && "$operation" == "postflight" && "$target_status" == "implement" \
      && "$state_is_noop" != "true" ]]; then
  resolve_plan_file_for_phase_check
  if [[ -n "$PHASE_CHECK_PLAN_FILE" ]]; then
    count_plan_phases
  fi

  if [[ -z "$PHASE_CHECK_PLAN_FILE" ]]; then
    echo "[phase-check] Task $task_number: no plan file resolved -- inconclusive, passing through." >&2
  elif [[ "$PHASE_CHECK_TOTAL" -eq 0 ]]; then
    echo "[phase-check] Task $task_number: no conforming '### Phase N: ... [STATUS]' headings in $(basename "$PHASE_CHECK_PLAN_FILE") -- inconclusive, passing through." >&2
  elif [[ "$PHASE_CHECK_DONE" -ge "$PHASE_CHECK_TOTAL" ]]; then
    echo "[phase-check] Task $task_number: ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases [COMPLETED] in $(basename "$PHASE_CHECK_PLAN_FILE") -- proceeding." >&2
  else
    # Conclusive on-disk evidence of incompleteness.
    if [[ "$DRY_RUN" == "true" ]]; then
      # --dry-run is preview-only and never itself a failure signal, so it always exits 0 and
      # continues previewing the rest of the pipeline even under --phase-check=refuse. This lets
      # a caller preview a refusal without it looking like a script bug in a dry-run harness.
      echo "[dry-run] Phase-check (mode=${PHASE_CHECK}) would block this transition: ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases complete in ${PHASE_CHECK_PLAN_FILE}"
    elif [[ "$PHASE_CHECK" == "refuse" ]]; then
      echo "Error: [phase-check] refusing postflight implement for task $task_number: only ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases are [COMPLETED] in ${PHASE_CHECK_PLAN_FILE}." >&2
      echo "       No state.json write and no plan-file status stamp occurred." >&2
      echo "       Finish the remaining phases, or correct the plan file's phase headings, and re-run." >&2
      exit 4
    else
      echo "WARNING: [phase-check] task $task_number is being marked completed with only ${PHASE_CHECK_DONE}/${PHASE_CHECK_TOTAL} phases [COMPLETED] in ${PHASE_CHECK_PLAN_FILE}." >&2
    fi
  fi
fi
```

Note on the `exit 4` path: it fires the existing `trap cleanup EXIT`, whose
`release_state_mutex` is a guarded no-op because `STATE_MUTEX_OWNED_HERE` is still `false` at
this point. No cleanup change is needed.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - insert PHASE 0 block between the
  `state_is_noop` computation and `mkdir -p "$TMP_DIR"`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/update-task-status.sh` exits 0
- On a task whose plan has all phases `[COMPLETED]`:
  `... postflight <N> implement s --dry-run --phase-check=refuse` prints the
  `-- proceeding.` line and exits 0
- On a task whose plan has at least one non-`[COMPLETED]` phase:
  `... postflight <N> implement s --dry-run --phase-check=refuse` prints the
  `[dry-run] Phase-check (mode=refuse) would block` line and **exits 0**
- Same task, non-dry-run with `--phase-check=refuse` exits **4**, and `git diff specs/state.json`
  plus the plan file's `- **Status**:` line are both unchanged
- Same task with `--phase-check=warn` exits 0, prints the `WARNING: [phase-check]` line, and
  performs the transition
- `... postflight <N> plan s --phase-check=refuse` on an incomplete-phase task is silently
  unaffected (flag ignored outside implement)
- No occurrence of `- [ ]` or `- [x]` counting anywhere in the diff

---

### Phase 3: Empirical validation gate for the `refuse` rollout [NOT STARTED]

**Goal**: Prove, before any `refuse` opt-in ships, that genuinely-complete implementations do
leave their plan files' phase headings at `[COMPLETED]`. This is the research report's explicit
mitigation for the one flagged, unverified assumption underlying `refuse` mode. **If this phase
fails, Phases 4 and 5 must be re-scoped to `warn` and the failure recorded, rather than
proceeding.**

**Tasks**:
- [ ] Select a sample of at least 8 recent tasks whose `state.json` status is `completed` and
      which have a plan file under `specs/{NNN}_{SLUG}/plans/`
- [ ] For each, run the new machinery in preview mode:
      `bash agent-system/extensions/core/scripts/update-task-status.sh postflight <N> implement validation-probe --dry-run --phase-check=refuse`
      (`--dry-run` guarantees zero writes; for an already-`completed` task the `state_is_noop`
      exclusion additionally means the gate does not even evaluate — so for the probe, note that
      the gate is skipped and instead directly count headings on the same resolved plan file)
- [ ] Because `state_is_noop` short-circuits the gate for already-`completed` tasks, perform the
      substantive count directly with the identical regexes:
      ```bash
      total=$(grep -c '^### Phase [0-9][0-9]*:.*\[[A-Z][A-Z ]*\][[:space:]]*$' "$plan" 2>/dev/null) || total=0
      done=$(grep -c '^### Phase [0-9][0-9]*:.*\[COMPLETED\][[:space:]]*$' "$plan" 2>/dev/null) || done=0
      ```
      and record `done/total` per sampled task
- [ ] Classify each sampled task: all-complete (supports `refuse`), partially-marked (false-refusal
      risk), or zero conforming headings (inconclusive pass-through, harmless)
- [ ] Record the tally and the verdict in the phase's verification notes

**Pass criterion**: at least 80% of sampled tasks that have conforming phase headings show
`done == total`, AND no sampled task shows a plan file with headings stuck at `[NOT STARTED]`
despite a `completed` state. Tasks with zero conforming headings do not count against the
criterion (they are the inconclusive pass-through case by design).

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- None (read-only validation phase). Findings are recorded in this plan's phase verification
  notes and in the task summary.

**Verification**:
- A per-task table of `done/total` for at least 8 sampled `completed` tasks is recorded
- The pass criterion is explicitly evaluated and a PASS/FAIL verdict stated
- `git status --porcelain` shows no modifications introduced by this phase

---

### Phase 4: `refuse` opt-in at the zero-gate scripts [NOT STARTED]

**Goal**: Thread `--phase-check=refuse` into the three zero-gate script call sites — both
`reconcile-task-status.sh` repair branches and `command-gate-out.sh`'s defensive correction —
each distinguishing exit 4 (refusal) from a genuine failure.

**Tasks**:
- [ ] Edit `reconcile-task-status.sh` `implementing` branch (line 344)
- [ ] Edit `reconcile-task-status.sh` `partial` branch (line 380)
- [ ] Edit `command-gate-out.sh` defensive correction (line 94)
- [ ] `bash -n` all three

**Exact replacement text** (all in `agent-system/extensions/core/scripts/`):

1. `reconcile-task-status.sh`, `implementing` branch. Replace:
```bash
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted implementing -> completed"
```
with:
```bash
      reconcile_rc=0
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id" --phase-check=refuse || reconcile_rc=$?
      if [[ "$reconcile_rc" -eq 4 ]]; then
        # A repair attempt can itself be refused. That is the intended, accepted failure mode: a
        # stuck-but-honestly-labeled task is strictly safer than a silently-wrong [COMPLETED]
        # one, and this branch already logs loudly on every path so the refusal is never silent.
        echo "[reconcile] Task $task_number: phase-accounting backstop refused the implementing -> completed promotion (plan file shows incomplete phases) — leaving status=implementing"
        exit 0
      elif [[ "$reconcile_rc" -ne 0 ]]; then
        echo "[reconcile] Task $task_number: update-task-status.sh failed (exit $reconcile_rc)" >&2
        exit "$reconcile_rc"
      fi
      echo "[reconcile] Task $task_number: promoted implementing -> completed"
```

2. `reconcile-task-status.sh`, `partial` branch. Replace:
```bash
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id"
      echo "[reconcile] Task $task_number: promoted partial -> completed"
```
with:
```bash
      reconcile_rc=0
      "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "implement" "$session_id" --phase-check=refuse || reconcile_rc=$?
      if [[ "$reconcile_rc" -eq 4 ]]; then
        echo "[reconcile] Task $task_number: phase-accounting backstop refused the partial -> completed promotion (plan file shows incomplete phases) — leaving status=partial"
        exit 0
      elif [[ "$reconcile_rc" -ne 0 ]]; then
        echo "[reconcile] Task $task_number: update-task-status.sh failed (exit $reconcile_rc)" >&2
        exit "$reconcile_rc"
      fi
      echo "[reconcile] Task $task_number: promoted partial -> completed"
```

Do NOT route these refusals through `record_refused_promotion`. That helper performs its own
`update-task-status.sh postflight ... "$handoff_status"` state write for `blocked`/`partial`
values; a phase-check refusal must leave state untouched, and the plain `echo` above is the
whole intended report.

3. `command-gate-out.sh`. Replace:
```bash
    echo "[gate-out] Defensive correction: status is '$current_status', skill reports '$skill_status'. Applying correction to '$expected_status'."
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" 2>/dev/null || \
      echo "WARNING: update-task-status.sh failed — manual correction may be needed" >&2
```
with:
```bash
    echo "[gate-out] Defensive correction: status is '$current_status', skill reports '$skill_status'. Applying correction to '$expected_status'."
    # A defensive corrector has no fresh handoff to trust, so it is exactly the case the
    # script-side backstop is built for: only the implement token gets --phase-check=refuse (the
    # flag is silently ignored elsewhere, but passing it only where it applies keeps intent
    # legible). stderr is deliberately no longer discarded for this call -- swallowing it would
    # hide the refusal's reason, which is the only actionable part of the message.
    gate_out_phase_check=""
    if [ "$status_token" = "implement" ]; then
      gate_out_phase_check="--phase-check=refuse"
    fi
    gate_out_rc=0
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$status_token" "$session_id" ${gate_out_phase_check} || gate_out_rc=$?
    if [ "$gate_out_rc" -eq 4 ]; then
      echo "[gate-out] Phase-accounting backstop refused the defensive correction for task $task_number (plan file shows incomplete phases). Leaving status as '$current_status'." >&2
    elif [ "$gate_out_rc" -ne 0 ]; then
      echo "WARNING: update-task-status.sh failed — manual correction may be needed" >&2
    fi
```
(`${gate_out_phase_check}` is intentionally unquoted so an empty value expands to no argument at
all; the value is a fixed literal set two lines above, never user input.)

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - both implement-postflight
  repair branches
- `agent-system/extensions/core/scripts/command-gate-out.sh` - defensive correction call

**Verification**:
- `bash -n` exits 0 for both scripts
- `grep -n 'phase-check' agent-system/extensions/core/scripts/reconcile-task-status.sh` shows
  exactly 2 hits; `command-gate-out.sh` shows exactly the intended hits
- `reconcile-task-status.sh --dry-run` on an `implementing` task still behaves as before (the
  dry-run branches were not touched)
- A live reconcile against a task with incomplete phase headings logs the refusal line and leaves
  `specs/state.json` unchanged (`git diff specs/state.json` empty)

---

### Phase 5: `refuse` opt-in at the core implementer skills [NOT STARTED]

**Goal**: Thread `--phase-check=refuse` into `skill-implementer` and `skill-implementer-hard`,
each of which needs a NEW refusal-handling branch (neither has any error handling on its
postflight call today).

**Tasks**:
- [ ] Edit `skill-implementer/SKILL.md` Stage 7 Step 1 and add Step 1a
- [ ] Edit `skill-implementer-hard/SKILL.md` Stage 7
- [ ] Confirm no task-number citations were introduced (these files live outside `specs/**`)

**Exact replacement text**:

1. `agent-system/extensions/core/skills/skill-implementer/SKILL.md`, Stage 7. Replace:

~~~markdown
**Step 1**: Run the centralized status update script to update state.json (status -> "completed", timestamps), TODO.md (`[IMPLEMENTING]` -> `[COMPLETED]` in task entry + Task Order), and plan file (status -> `[COMPLETED]`):
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```
~~~

with:

~~~markdown
**Step 1**: Run the centralized status update script to update state.json (status -> "completed", timestamps), TODO.md (`[IMPLEMENTING]` -> `[COMPLETED]` in task entry + Task Order), and plan file (status -> `[COMPLETED]`).

`--phase-check=refuse` engages the script-side phase-accounting backstop. This skill previously
had no phase gate at all: `phases_completed`/`phases_total` are read from the agent's
`.return-meta.json` one stage earlier for the commit message, but were never consulted before
this call. The backstop is deliberately independent of those values — the script resolves the
task's own plan file and counts its `### Phase N: ... [STATUS]` headings itself, exiting 4
without writing anything if any phase is not `[COMPLETED]`:
```bash
postflight_rc=0
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=refuse || postflight_rc=$?
```

**Step 1a (refusal branch)**: If `postflight_rc` is 4 the backstop refused — no state.json write
and no plan-file stamp occurred. Treat this exactly like the `status == "partial"` branch below:
keep the task at `implementing`, record a resume point, and let the next `/implement` invocation
resume from the first incomplete phase. Do NOT retry without the flag, and do NOT hand-edit
state.json to `completed`. Skip Steps 2-3 (completion_summary and roadmap_items are completion
metadata and the task is not complete); Step 4's memory-candidate propagation may still run.
```bash
if [ "$postflight_rc" -eq 4 ]; then
    echo "[implementer] Phase-accounting backstop refused completion for task $task_number: the plan file shows incomplete phases. Task stays [IMPLEMENTING]; re-run /implement to resume." >&2
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson phase "$phases_completed" \
      '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
        last_updated: $ts,
        resume_phase: ($phase + 1)
      }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
elif [ "$postflight_rc" -ne 0 ]; then
    echo "WARNING: update-task-status.sh exited $postflight_rc — manual correction may be needed" >&2
fi
```
~~~

2. `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`, Stage 7. Replace:
```bash
if [ "$status" = "implemented" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
fi
```
with:
```bash
if [ "$status" = "implemented" ]; then
  postflight_rc=0
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=refuse || postflight_rc=$?
  if [ "$postflight_rc" -eq 4 ]; then
    # The backstop read the plan file's own `### Phase N: ... [STATUS]` headings and found
    # incomplete phases. Nothing was written. Degrade to the partial path -- keep status
    # "implementing" for resume -- rather than retrying without the flag.
    echo "[hard-mode] Phase-accounting backstop refused completion for task $task_number; keeping status=implementing for resume." >&2
    status="partial"
  elif [ "$postflight_rc" -ne 0 ]; then
    echo "WARNING: update-task-status.sh exited $postflight_rc — manual correction may be needed" >&2
  fi
fi
```
The surrounding comment lines (`# On partial: keep status as "implementing" for resume` and the
skeleton-dispatch NOTE) are unchanged and remain immediately below this block.

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - Stage 7 Step 1 + new Step 1a
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - Stage 7

**Verification**:
- `grep -n 'phase-check=refuse' agent-system/extensions/core/skills/skill-implementer/SKILL.md`
  returns exactly 1 hit; same for `skill-implementer-hard/SKILL.md`
- The refusal branch in each file references exit code 4 explicitly and distinguishes it from
  `-ne 0`
- `grep -nEi 'task [0-9]{2,}|tasks [0-9]{2,}' ` over the two edited files returns no new
  task-number citations (the literal `$task_number` variable is not a citation)
- The `status == "partial"` branch further down `skill-implementer/SKILL.md` is unmodified

---

### Phase 6: `warn` opt-in where a SKILL-layer gate already decided [NOT STARTED]

**Goal**: Add an optional 5th `phase_check_mode` argument to the shared
`skill_postflight_update` helper (absent by default), pass `warn` from the three orchestrate
implement arms, and add `warn` at the four lean/cslib extension implementers. `warn` never
changes an exit code, so no caller needs a new error branch.

**Tasks**:
- [ ] Add the optional 5th argument to `skill_postflight_update` in `skill-base.sh`
- [ ] Pass `warn` from `skill-orchestrate` Stage 5's `implemented)` arm
- [ ] Update `skill-orchestrate` Stage MT-4's prose instruction to pass `warn`
- [ ] Pass `warn` from `skill-orchestrate-hard`'s `implemented)` arm
- [ ] Append `--phase-check=warn` at the four extension implementer call sites
- [ ] `bash -n skill-base.sh`

**Exact replacement text**:

1. `agent-system/extensions/core/scripts/skill-base.sh`. Replace:
```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  local _t0
  _t0=$(date +%s.%N)
  case "$status" in
    researched|planned|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id"
      ;;
```
with:
```bash
skill_postflight_update() {
  local task_number="$1"
  local operation="$2"
  local session_id="$3"
  local status="$4"
  # Optional 5th argument: phase-check mode ("warn" or "refuse"), forwarded to
  # update-task-status.sh's opt-in phase-accounting backstop. ABSENT is the default for every
  # existing caller and means the flag is not passed at all, preserving today's exact behavior
  # byte-for-byte. The empty-array expansion pattern below is the same one already used by
  # reconcile-task-status.sh's dry_run_flag=() handling.
  local phase_check_mode="${5:-}"
  local phase_check_args=()
  if [[ -n "$phase_check_mode" ]]; then
    phase_check_args=(--phase-check="$phase_check_mode")
  fi
  local _t0
  _t0=$(date +%s.%N)
  case "$status" in
    researched|planned|implemented)
      bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id" "${phase_check_args[@]}"
      ;;
```

2. `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, Stage 5. Replace:
```bash
      if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]; then
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
```
with:
```bash
      if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]; then
        # `warn`, deliberately NOT `refuse`. This gate already decided to proceed using richer
        # context than the script has (the full handoff, drift inspection). The script-side
        # backstop reads a structurally different evidence source -- the plan file's own phase
        # headings, unaffected by what the handoff chose to report -- so it is a valuable SECOND
        # OPINION here, not a veto: a `refuse` at this site would silently override a decision
        # this state machine made deliberately and loggedly. The loud warning is exactly what
        # catches the "handoff omitted its phase fields but the task was actually incomplete"
        # case, which the handoff-based gate above structurally cannot see.
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
```

3. `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, Stage MT-4 step 3. Replace:
```
   - `dispatch_status = "implemented"` → apply the same phase-completion gate as Stage 5. Call
     `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented`
```
with:
```
   - `dispatch_status = "implemented"` → apply the same phase-completion gate as Stage 5. Call
     `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented "warn"`
     (the trailing `"warn"` mirrors Stage 5's script-side second-opinion backstop; never `refuse`
     here, for the same reason)
```

4. `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. Replace:
```bash
      if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
```
with:
```bash
      if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
        # `warn`, not `refuse` -- same rationale as the base-mode gate: hard mode's per-phase
        # dispatch discipline already populates phase accounting and this gate is strictly
        # stricter (it requires phases_total > 0, never a 0-pass-through), so the script-side
        # check is a second opinion on independent evidence rather than a veto.
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
```

5. The four extension implementers. At each of the following exact lines, append
` --phase-check=warn` to the existing invocation. `warn` (not `refuse`) is chosen for these
because their phase-heading-update discipline was not verified end-to-end; escalating them to
`refuse` is deliberate follow-up work, not part of this change.
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md:192`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md:277`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation/SKILL.md:124`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md:298`

In each case the line reads (modulo leading indentation):
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```
and becomes:
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=warn
```
Re-verify each anchor by this quoted text before editing; do not trust the line numbers alone.

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - optional 5th arg on
  `skill_postflight_update`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 + Stage MT-4
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - implemented arm
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `agent-system/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` exits 0
- Calling `skill_postflight_update` with 4 arguments passes NO `--phase-check` argument
  (confirm by `bash -x` trace or by a stub `update-task-status.sh` that echoes `"$@"`)
- Calling it with a 5th argument `warn` passes exactly `--phase-check=warn`
- `grep -rn 'phase-check=warn' agent-system/extensions/` returns exactly 4 hits (the extension
  implementers); `grep -rn '"warn"' ` in the two orchestrate SKILL files returns the 3 expected
  `skill_postflight_update` hits
- No `refuse` appears in any orchestrate or extension file

---

### Phase 7: Backward-compatibility proof, source-store audit, and doc cross-reference [NOT STARTED]

**Goal**: Prove the no-flag default is byte-for-byte unchanged for existing callers, prove no
edit landed in `.claude/`, and add the plan-format cross-reference the research recommended.

**Tasks**:
- [ ] Capture the pre-change script and diff its no-flag behavior against the new one
- [ ] Audit the full 12-site inventory for correct flag assignment
- [ ] Confirm no `.claude/` file was edited
- [ ] Add the `plan-format.md` cross-reference note
- [ ] Confirm no task-number citations outside `specs/**`

**Backward-compatibility proof procedure**:
```bash
cd /home/benjamin/.config/nvim
git show HEAD:agent-system/extensions/core/scripts/update-task-status.sh > /tmp/uts-baseline.sh
# Pure-text guard: everything the new script does WITHOUT the flag must be reachable in the
# baseline. Confirm the diff touches only additive regions.
diff /tmp/uts-baseline.sh agent-system/extensions/core/scripts/update-task-status.sh
```
Then, for at least 4 tasks spanning distinct states (`implementing`, `planned`, `completed`, and
one with no plan directory), and for each of `preflight`/`postflight` x
`research`/`plan`/`implement`, compare dry-run output with no flag:
```bash
for t in <T1> <T2> <T3> <T4>; do
  for op in preflight postflight; do
    for ts in research plan implement; do
      a=$(bash /tmp/uts-baseline.sh "$op" "$t" "$ts" bc-probe --dry-run 2>&1 || echo "rc=$?")
      b=$(bash agent-system/extensions/core/scripts/update-task-status.sh "$op" "$t" "$ts" bc-probe --dry-run 2>&1 || echo "rc=$?")
      [ "$a" = "$b" ] || echo "MISMATCH task=$t op=$op ts=$ts"
    done
  done
done
```
The loop must print no `MISMATCH` line. Exit codes are captured into the compared strings via the
`rc=$?` fallback, so an exit-code divergence is caught too.

**Full call-site audit** — assert exactly this assignment across all 12 sites:

| Site | File | Expected |
|------|------|----------|
| 1 | `skill-orchestrate/SKILL.md` Stage 5 | `warn` (via `skill_postflight_update` 5th arg) |
| 2 | `skill-orchestrate/SKILL.md` Stage MT-4 | `warn` (prose instruction) |
| 3 | `skill-orchestrate-hard/SKILL.md` | `warn` (via 5th arg) |
| 4 | `skill-implementer/SKILL.md` | `refuse` + exit-4 branch |
| 5 | `skill-implementer-hard/SKILL.md` | `refuse` + exit-4 branch |
| 6 | `skill-lean-implementation/SKILL.md` | `warn` |
| 7 | `skill-lean-implementation-hard/SKILL.md` | `warn` |
| 8 | `skill-cslib-implementation/SKILL.md` | `warn` |
| 9 | `skill-cslib-implementation-hard/SKILL.md` | `warn` |
| 10 | `reconcile-task-status.sh` implementing branch | `refuse` + exit-4 branch |
| 11 | `reconcile-task-status.sh` partial branch | `refuse` + exit-4 branch |
| 12 | `command-gate-out.sh` | `refuse` (implement token only) + exit-4 branch |

Audit command:
```bash
grep -rn 'update-task-status\.sh.*implement\|phase-check\|skill_postflight_update' \
  agent-system/extensions/ --include=*.sh --include=*.md
```

**Doc cross-reference**. In
`agent-system/extensions/core/context/formats/plan-format.md`, in the section that fixes the
`### Phase N: {name} [STATUS]` heading format, add a short note that this heading contract now
has three consumers — `update-phase-status.sh` (per-phase status mutation),
`update-plan-status.sh` (plan-level equivalent), and `update-task-status.sh`'s `--phase-check`
backstop (whole-plan completion counting) — so a future change to the heading format has all
three listed in one place. Do not cite any task number in this note.

**Timing**: 1 hour

**Depends on**: 4, 5, 6

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - phase-heading consumer
  cross-reference note

**Verification**:
- The backward-compatibility loop prints no `MISMATCH`
- `git status --porcelain .claude/` is empty (the deploy artifact is untracked and gitignored;
  additionally confirm by timestamp that no `.claude/**` file was written during implementation)
- The 12-site audit table is confirmed row by row
- `grep -rnEi '\btasks? [0-9]{2,}\b' agent-system/ --include=*.sh --include=*.md` shows no new
  hits introduced by this change
- `bash -n` passes for all four modified `.sh` files

---

## Testing & Validation

- [ ] `bash -n` passes for `update-task-status.sh`, `reconcile-task-status.sh`,
      `command-gate-out.sh`, `skill-base.sh`
- [ ] No-flag invocation is byte-for-byte identical to the pre-change script across the
      operation x target_status x task-state matrix (Phase 7 loop, zero `MISMATCH`)
- [ ] `--phase-check=bogus` exits 1 with a clear error (never a silent fallback to no-op)
- [ ] `--phase-check=refuse` on an incomplete-phase task exits 4 with zero writes to
      `specs/state.json` and zero change to the plan's `- **Status**:` line
- [ ] `--phase-check=warn` on the same task exits 0, logs the warning, and completes the
      transition
- [ ] `--dry-run --phase-check=refuse` always exits 0 and previews the refusal
- [ ] `--phase-check=refuse` on a `postflight plan` or `postflight research` call is silently
      ignored
- [ ] A task with no plan file, and a task whose plan has zero conforming `### Phase` headings,
      both pass through with an `-- inconclusive` log line
- [ ] The `state_is_noop` path (already-`completed` task replaying postflight) is unaffected
- [ ] No checkbox (`- [ ]` / `- [x]`) counting appears anywhere in the diff
- [ ] All edits are under `agent-system/extensions/**`; nothing under `.claude/**`

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/update-task-status.sh` (flag surface, PHASE 0
  gate, exit code 4)
- Modified `agent-system/extensions/core/scripts/reconcile-task-status.sh` (2 `refuse` opt-ins)
- Modified `agent-system/extensions/core/scripts/command-gate-out.sh` (1 `refuse` opt-in)
- Modified `agent-system/extensions/core/scripts/skill-base.sh` (optional 5th arg)
- Modified `agent-system/extensions/core/skills/skill-implementer/SKILL.md` and
  `skill-implementer-hard/SKILL.md` (`refuse` + exit-4 branches)
- Modified `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` (`warn`)
- Modified 4 lean/cslib extension implementer SKILL.md files (`warn`)
- Modified `agent-system/extensions/core/context/formats/plan-format.md` (consumer
  cross-reference)
- Phase 3 empirical validation table (recorded in the task summary)

## Rollback/Contingency

- **Phase 1-2 only**: revert the single script; the flag is additive and no caller passes it yet,
  so reverting is a clean `git checkout` of one file with zero caller coordination.
- **Phase 3 fails the pass criterion**: do NOT proceed with Phases 4-5 as written. Re-scope every
  `refuse` in this plan to `warn`, and record the plan-file phase-heading discipline gap as a
  separate blocker to address before `refuse` can be trusted anywhere.
- **A `refuse` site produces false refusals in practice**: downgrade that one site to `warn` by
  changing its flag value; no other code needs to change because `warn` never alters an exit code
  and the exit-4 branches simply become unreachable.
- **Full revert**: `git checkout HEAD -- agent-system/extensions/` restores every file; `.claude/`
  is a disposable deploy artifact regenerated by the loader and needs no rollback.
