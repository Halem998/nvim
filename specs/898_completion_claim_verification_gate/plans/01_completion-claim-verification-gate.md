# Implementation Plan: Task #898

- **Task**: 898 - Completion-claim verification gate for the orchestrate skills
- **Status**: [COMPLETED]
- **Effort**: 3.25 hours
- **Dependencies**: None (composes with the already-landed phase-marker-grep recovery carve-out)
- **Research Inputs**: specs/898_completion_claim_verification_gate/reports/01_completion_claim_verification_gate.md
- **Artifacts**: plans/01_completion-claim-verification-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research report establishes that the phases_completed/phases_total arithmetic gate already
exists at all three orchestrator call sites, so this task is NOT about adding that gate. It is
about (a) replacing three hand-copied, already-drifted inline gates with ONE shared bash function
in `skill-base.sh`, (b) adding the missing `plan_markers_verified` fallback so the "phase
accounting absent" case fails closed instead of blindly allowing (base) or blindly refusing
(hard), and (c) fixing three documentation locations that show `phases_completed`/`phases_total`
nested under `continuation_context` when every real writer and every real reader uses top level.

All edits target `agent-system/extensions/core/**` (the source store). No file under `.claude/**`
is touched; deployment to `.claude/` is a separate, user-driven "Load Core" step.

### Research Integration

Findings that directly shape this plan:

- **Do not re-add the arithmetic gate.** It is present in `skill-orchestrate/SKILL.md` Stage 5
  (line ~628) and Stage MT-4 (step 3), and `skill-orchestrate-hard/SKILL.md` Stage 5 (line ~867).
  Phases 2-3 REPLACE these blocks with calls to the shared function; they do not add new logic
  beside them.
- **DECISION POINT resolves to (a): top level is canonical, the docs are wrong.** Exactly one
  active handoff writer exists (`general-implementation-hard-agent.md` H9 Stage 5, mirrored by
  the cslib and lean hard-mode implementation agents) plus one dead zero-caller
  (`skill_write_orchestrator_handoff`), and both already write top level. 177/203 on-disk runtime
  samples are top-level-only; 1 is nested-only (itself a symptom of the doc bug). No reader moves.
- **`plan_markers_verified` is read by nothing today** and is present in only 28/203 (14%) real
  samples, which is exactly why Case 3 must be a corroborated allow/refuse rather than a blind
  allow.
- **The gate has teeth only on hard-mode dispatches today.** Base-mode `skill-researcher`,
  `skill-planner`, and `skill-implementer` never write `.orchestrator-handoff.json` at all
  (confirmed by repo-wide grep and by `reconcile-task-status.sh`'s own inline comment). This is a
  pre-existing architectural gap, explicitly out of scope, but the implementer must not read an
  empty base-mode test result as a defect in this work.
- **Do not reuse the phase-marker-grep recovery exception.** It is precondition-scoped to the
  missing/stale-handoff branch; this gate fires only in the opposite branch (handoff present and
  fresh). Merging them would violate that exception's own "nowhere else" contract and this task's
  no-plan-file-reads constraint.
- **`update-task-status.sh --phase-check=refuse` remains the authoritative skill-layer backstop.**
  The orchestrator layer keeps passing `"warn"`, never `"refuse"`, preserving the existing
  division of labor.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and `roadmap_flag` is not set, so no
roadmap phases are included and no roadmap alignment was consulted. `specs/ROADMAP.md` is not
modified by this plan.

## Goals & Non-Goals

**Goals**:

- One shared `skill_gate_completion_claim` function in
  `agent-system/extensions/core/scripts/skill-base.sh`, purely additive (no edit to any existing
  function), implementing the three-case fail-closed semantics exactly once.
- All three call sites (base Stage 5, base Stage MT-4, hard Stage 5) call it identically, so the
  base/hard copy drift that already occurred cannot recur.
- `plan_markers_verified` becomes a read signal for the first time, used only as the Case 3
  corroborating fallback.
- Loud, greppable, task-naming warning text that states which of the three cases fired.
- `handoff-schema.md` and `orchestrate-state-machine.md` reconciled to document top-level
  `phases_completed`/`phases_total` and the new fail-closed Case 3 behavior, superseding the
  current "non-blocking warning only" prescription.
- Explicit, executed verification that the new refusal path terminates against MAX_CYCLES /
  MAX_CYCLES_MT rather than spinning.

**Non-Goals**:

- Moving `phases_completed`/`phases_total` into `continuation_context` in any writer or reader
  (DECISION POINT resolved the other way).
- Wiring a handoff writer into base-mode research/plan/implement skills (separate, larger task).
- Weakening or touching the drift-detection gate (`dispatch_status = "partial"` path), the
  partial/blocker routing, the staleness gate, the infra-failure discrimination, or the
  phase-marker-grep recovery exception.
- Reading plan files, reports, or summaries to verify a completion claim. All gate evidence comes
  from fields already parsed out of `.orchestrator-handoff.json`.
- Editing anything under `.claude/**`, or deploying the source store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing `skill-base.sh`, a load-bearing file sourced by many skills | H | L | New function only; no edit to any existing function. `bash -n` plus a full three-case unit harness in Phase 1 before any call site is wired. |
| Base mode's Case 3 changes from blind-allow to marker-gated, so a legitimate handoff lacking `plan_markers_verified` now costs an extra re-dispatch cycle | M | M | This is the explicit design ask (fail closed on missing evidence). Cost is bounded by MAX_CYCLES, verified in Phase 5. The skill-layer `--phase-check` backstop is unaffected either way. |
| Hard mode's Case 3 changes from blind-refuse to marker-gated allow, slightly loosening hard mode | M | L | Hard mode's per-phase dispatch always populates phase accounting, so Case 3 is near-unreachable there; when it does fire, allowing only on `plan_markers_verified == true` is evidence-backed and strictly better than spinning to MAX_CYCLES. Named as a deliberate change in the function header and in `handoff-schema.md`. |
| Non-integer / malformed `phases_*` values crash the `-ge` comparison under `set -e` | M | L | The function sanitizes both values with a digits-only regex; a non-integer is coerced to 0 and routed to Case 3 (fail closed), never to an arithmetic error. Covered by a unit case in Phase 1. |
| A stale handoff left over from a prior hard-mode run triggers the gate unexpectedly | L | L | The existing mtime-vs-`dispatch_start_ts` staleness gate runs strictly before this branch. Phase 5 asserts the gate call sits inside the `else` (handoff present and fresh) branch. |
| Source-store edits silently not in effect because `.claude/` is not redeployed | M | M | Verification sources the source-store copy directly (`SKILL_REPO_ROOT` override), never `.claude/scripts/skill-base.sh`. The summary states explicitly that a Load Core deploy is required for runtime effect. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint files
(`skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, and the two `docs/architecture/`
files respectively), so parallel execution has no write conflicts.

---

### Phase 1: Shared `skill_gate_completion_claim` in skill-base.sh [COMPLETED]

**Goal**: Add ONE additive bash function implementing the three-case fail-closed gate, and prove
all three cases fire correctly before any call site depends on it.

**Pre-read**: `skill-base.sh` was modified by a sibling task (it now exports `SKILL_REPO_ROOT`
resolved from `BASH_SOURCE`, exports `TASK_DIR_ABS`, and `skill_postflight_update` takes an
optional 5th phase-check argument). Read the current on-disk file before editing; the deployed
`.claude/scripts/skill-base.sh` is BEHIND the source store and must not be consulted as truth.

**Tasks**:

- [x] Read `agent-system/extensions/core/scripts/skill-base.sh` in full around the
      `skill_write_orchestrator_handoff` definition (ends at the file's current tail). *(completed)*
- [x] Append a new function after `skill_write_orchestrator_handoff` (purely additive; do not
      modify that function or any other): *(completed)*

  ```bash
  # ───────────────────────────────────────────────────────────────────────────
  # Completion-claim verification gate
  # Usage: skill_gate_completion_claim "$task_number" "$phases_completed" \
  #          "$phases_total" "$plan_markers_verified" "$log_prefix"
  #
  #   $1 = task_number            : task number, named in every log line
  #   $2 = phases_completed       : integer from the handoff's TOP-LEVEL field (jq '// 0')
  #   $3 = phases_total           : integer from the handoff's TOP-LEVEL field (jq '// 0')
  #   $4 = plan_markers_verified  : "true" | "false" | "absent" (jq '// "absent"')
  #   $5 = log_prefix             : "[orchestrate]" or "[hard-orchestrate]"
  #
  # Returns 0 = ALLOW the completed transition; 1 = REFUSE it. On a refuse the caller MUST skip
  # skill_postflight_update entirely, leave the task at `implementing`, and let the surrounding
  # cycle counter increment as usual, so the next cycle re-dispatches implement and the existing
  # MAX_CYCLES / MAX_CYCLES_MT caps bound the retry.
  #
  # All evidence is read from fields the caller already parsed out of
  # .orchestrator-handoff.json. This function never reads a plan file, report, or summary, and
  # never invokes the Stage 5 phase-marker recovery grep — that exception is scoped to the
  # missing/stale-handoff branch and this gate fires only when a handoff IS present and fresh.
  ```

- [x] Implement the body with these exact semantics: *(completed)*
  - Sanitize `$2` and `$3`: if either does not match `^[0-9]+$`, coerce it to `0` (a malformed
    value is missing evidence, so it falls through to Case 3 — fail closed, never an arithmetic
    error under `set -e`).
  - **Case 2** (checked first, the only unconditional allow): `phases_total > 0` and
    `phases_completed >= phases_total` → log to stderr and `return 0`:
    `${log_prefix} COMPLETION-CLAIM GATE case 2/3 (phase accounting present and complete) task ${task_number}: ${phases_completed}/${phases_total} — allowing completion.`
  - **Case 1**: `phases_total > 0` and `phases_completed < phases_total` → log to stderr and
    `return 1`:
    `${log_prefix} COMPLETION-CLAIM GATE case 1/3 (phase accounting present, incomplete) task ${task_number}: ${phases_completed}/${phases_total} — refusing completion; task stays implementing.`
  - **Case 3** (`phases_total == 0`, i.e. accounting absent or malformed): fall back to
    `plan_markers_verified`.
    - `"true"` → log and `return 0`:
      `${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=true) task ${task_number}: allowing completion on the corroborating marker signal.`
    - anything else (`"false"`, `"absent"`, `"null"`, empty) → log and `return 1`:
      `${log_prefix} COMPLETION-CLAIM GATE case 3/3 (phase accounting absent, plan_markers_verified=${plan_markers_verified}) task ${task_number}: refusing completion — handoff-writer defect suspected; task stays implementing.`
  - Every log line goes to stderr and carries the literal, greppable token
    `COMPLETION-CLAIM GATE case N/3` plus the task number and the case name.
- [x] In the function header comment, record the two deliberate behavior changes this unification
      makes, so a future reader does not "restore" the old asymmetry: base mode loses its
      `phases_total == 0` blind allow, and hard mode loses its `phases_total == 0` blind refuse;
      both are replaced by the corroborated Case 3 fallback. *(completed)*
- [x] Note in the header that this function is the ONLY place the three-case logic may live, and
      that inlining a copy at a call site is the drift this refactor exists to prevent. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/skill-base.sh` — append `skill_gate_completion_claim`;
  no other function touched.

**Verification** (all commands run from `/home/benjamin/.config/nvim`):

```bash
# 1. Syntax
bash -n agent-system/extensions/core/scripts/skill-base.sh && echo "SYNTAX OK"

# 2. Additive-only proof: exactly one added hunk, no deletions in existing functions
git diff --stat agent-system/extensions/core/scripts/skill-base.sh
git diff -U0 agent-system/extensions/core/scripts/skill-base.sh | grep -c '^-[^-]' # must print 0

# 3. Three-case unit harness (sources the SOURCE STORE copy, never .claude/)
cat > /tmp/claude-1000/-home-benjamin--config-nvim/gate-test.sh <<'TESTEOF'
set -u
export SKILL_REPO_ROOT=/home/benjamin/.config/nvim
source /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/skill-base.sh
fail=0
run() { # run <label> <expect:allow|refuse> <expect-token> <args...>
  local label="$1" expect="$2" token="$3"; shift 3
  local out rc
  out=$(skill_gate_completion_claim "$@" 2>&1); rc=$?
  local got=allow; [ "$rc" -ne 0 ] && got=refuse
  if [ "$got" != "$expect" ]; then echo "FAIL $label: expected $expect got $got"; fail=1
  elif ! printf '%s' "$out" | grep -q "$token"; then
    echo "FAIL $label: log missing token '$token' (got: $out)"; fail=1
  elif ! printf '%s' "$out" | grep -q "task 898"; then
    echo "FAIL $label: log does not name the task (got: $out)"; fail=1
  else echo "PASS $label"; fi
}
run case1-short          refuse "case 1/3" 898 2 4 absent "[orchestrate]"
run case2-complete       allow  "case 2/3" 898 4 4 absent "[orchestrate]"
run case2-over           allow  "case 2/3" 898 5 4 true   "[orchestrate]"
run case3-markers-true   allow  "case 3/3" 898 0 0 true   "[orchestrate]"
run case3-markers-false  refuse "case 3/3" 898 0 0 false  "[orchestrate]"
run case3-markers-absent refuse "case 3/3" 898 0 0 absent "[orchestrate]"
run case3-markers-null   refuse "case 3/3" 898 0 0 null   "[orchestrate]"
run case3-malformed      refuse "case 3/3" 898 x y absent "[hard-orchestrate]"
[ "$fail" -eq 0 ] && echo "ALL GATE CASES PASS" || { echo "GATE TESTS FAILED"; exit 1; }
TESTEOF
bash /tmp/claude-1000/-home-benjamin--config-nvim/gate-test.sh

# 4. No .claude/** was touched
git status --short .claude/ | grep -q . && echo "VIOLATION: .claude modified" || echo ".claude clean"
```

Phase is complete only when `ALL GATE CASES PASS` prints and the deletion count in check 2 is 0.

---

### Phase 2: Wire base skill-orchestrate (Stage 5 + Stage MT-4) [COMPLETED]

**Goal**: Replace the two hand-copied inline gates in `skill-orchestrate/SKILL.md` with calls to
the shared function, and read `plan_markers_verified` at both sites.

**Tasks**:

- [x] Stage 5 (`implemented)` case, currently around lines 621-646): add
      `plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')`
      alongside the existing `phases_completed`/`phases_total` reads at the top of the
      handoff-present `else` branch (around lines 597-598). Keep those two reads TOP LEVEL —
      do not move them to `.continuation_context`. *(completed)*
- [x] Replace the inline `if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]`
      block with: *(completed)*

  ```bash
  implemented)
    # Completion-claim verification gate: a dispatch reporting "implemented" must not flip the
    # whole task to `completed` without corroborating evidence in the handoff. The three-case
    # fail-closed logic lives in ONE place — skill_gate_completion_claim in skill-base.sh — so
    # base mode, hard mode, and multi-task mode cannot drift apart again.
    if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
         "$plan_markers_verified" "[orchestrate]"; then
      # `warn`, deliberately NOT `refuse`: the script-side backstop reads the plan file's own
      # phase headings — structurally different evidence — so it is a valuable SECOND OPINION
      # here, not a veto over a decision this state machine made deliberately and loggedly.
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
    fi
    # On refuse: no status transition. State stays `implementing`, the gate already logged which
    # case fired, `cycle_count` still increments at the end of this stage, and Stage 4
    # re-dispatches implement next cycle against the same plan. MAX_CYCLES bounds this, so a
    # misreporting agent exits `partial` rather than looping forever.
    ;;
  ```

- [x] Preserve the surrounding `case` arms (`researched`, `planned`, `*`) byte-for-byte, and leave
      the drift-detection block above the `case` untouched. *(completed)*
- [x] Stage MT-4 step 2: add `plan_markers_verified` (`jq -r '.plan_markers_verified // "absent"'`)
      to the list of per-task fields re-read freshly from *that task's own* handoff every cycle,
      with the same "never carry values over from a previous task in the wave" wording that
      already governs `phases_completed`/`phases_total`. *(completed)*
- [x] Stage MT-4 step 3: rewrite the `dispatch_status = "implemented"` bullet to call
      `skill_gate_completion_claim "$task_num" "$phases_completed" "$phases_total" "$plan_markers_verified" "[orchestrate]"`
      and to call `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented "warn"`
      only when the gate returns 0. On a refuse: skip the postflight call, leave the task at
      `implementing`, and keep steps 4-6 running unchanged (artifact still linked, step 5 takes
      its `Otherwise` branch rather than `completed_tasks`, per-task lock still released). Keep
      the explicit statement that the task stays eligible for Stage MT-3's next cycle, bounded by
      `MAX_CYCLES_MT`. *(completed)*
- [x] Remove the now-obsolete prose in both sites that describes the old
      "`phases_total` 0 → preserve the historical unconditional behavior" pass-through, replacing
      it with a one-line pointer to the shared function's three-case contract. Do NOT delete the
      surrounding `warn`-not-`refuse` rationale. *(completed)*
- [x] Do not modify the "MUST NOT (Context Flatness Constraint)" section or the recovery-exception
      contract; this gate reads only handoff fields and adds no new read. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 `implemented` arm and
  its field reads; Stage MT-4 steps 2 and 3.

**Verification**:

```bash
cd /home/benjamin/.config/nvim
# Exactly two call sites in this file
grep -c "skill_gate_completion_claim" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md   # expect 2

# plan_markers_verified is now read at both sites
grep -c "plan_markers_verified" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md         # expect >= 3

# The old inline arithmetic gate is gone from the implemented path
grep -n 'phases_total" -eq 0 \]\|phases_completed" -ge "\$phases_total"' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md   # expect no output

# The drift gate (partial path) is untouched
git diff -U0 agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
  | grep -E '^[-+].*(DRIFT_COMPLETION_THRESHOLD|invoke_drift_inspection)' # expect no output

# Extracted bash blocks still parse
awk '/^```bash$/{f=1;next} /^```$/{f=0} f' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md > /tmp/claude-1000/-home-benjamin--config-nvim/orch-base.sh
bash -n /tmp/claude-1000/-home-benjamin--config-nvim/orch-base.sh || echo "NOTE: review any parse error — fragments may be intentionally partial"

# No .claude/** edits, no task-number citations in the edited file
git status --short .claude/ | grep -q . && echo "VIOLATION: .claude modified" || echo ".claude clean"
grep -nE '\(task [0-9]+\)|\btasks? [0-9]{2,}\b' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
```

The last grep may surface PRE-EXISTING task-number citations; the binding requirement is that the
diff introduces none. Confirm with
`git diff -U0 <file> | grep -E '^\+' | grep -nE '\(task [0-9]+\)|\btasks? [0-9]{2,}\b'` returning
nothing. If a pre-existing citation sits inside a line this phase rewrites anyway, drop it.

---

### Phase 3: Wire skill-orchestrate-hard Stage 5 [COMPLETED]

**Goal**: Replace the hard-mode inline gate with the identical shared-function call, so the
base/hard asymmetry that already drifted once cannot reappear.

**Tasks**:

- [x] Add `plan_markers_verified=$(echo "$handoff" | jq -r '.plan_markers_verified // "absent"')`
      alongside the existing top-level `phases_completed`/`phases_total`/`skeleton` reads (around
      lines 832-834). *(completed)*
- [x] Replace the inline `if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]`
      block (around lines 864-878) with: *(completed)*

  ```bash
  implemented)
    # A single per-phase "implemented" handoff (skeleton or not) must NOT flip the whole task to
    # completed. Identical call to the base-mode and multi-task sites — the three-case logic
    # lives only in skill_gate_completion_claim.
    if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
         "$plan_markers_verified" "[hard-orchestrate]"; then
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn"
    else
      echo "[hard-orchestrate] skeleton=${skeleton} at refusal." >&2
      # Leave state as `implementing` — Stage 3a re-enters the Per-Phase Dispatch handler
      # (Stage 4, H1) next cycle. No postflight status transition happens here.
    fi
    ;;
  ```

- [x] Preserve the `skeleton` diagnostic: hard mode's existing refusal log names it, and the
      shared function is deliberately mode-agnostic, so the skeleton value is logged by the caller
      on the refusal branch (as above) rather than pushed into the shared function's signature.
      *(completed)*
- [x] Update the surrounding comment to record the deliberate change: hard mode's former
      `phases_total > 0` requirement (a blind refuse when accounting is absent) is now the
      corroborated Case 3 fallback, which allows only on `plan_markers_verified == true`. Note
      that hard mode's per-phase dispatch always populates accounting, so Case 3 should be
      near-unreachable there; when it does fire it means the handoff writer is defective.
      *(completed)*
- [x] Leave the sorry-inventory block, the drift-detection block, the artifact-linking block, and
      the Read allowlist untouched. *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 5 field reads and
  `implemented` arm.

**Verification**:

```bash
cd /home/benjamin/.config/nvim
grep -c "skill_gate_completion_claim" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md  # expect 1
grep -c "plan_markers_verified" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md        # expect >= 2
grep -n 'phases_total" -gt 0 \] && \[ "\$phases_completed" -ge' \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md   # expect no output
git diff -U0 agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md \
  | grep -E '^[-+].*(sorry_inventory|invoke_drift_inspection|DRIFT_COMPLETION_THRESHOLD)'  # expect no output
git status --short .claude/ | grep -q . && echo "VIOLATION: .claude modified" || echo ".claude clean"
git diff -U0 agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md \
  | grep -E '^\+' | grep -nE '\(task [0-9]+\)|\btasks? [0-9]{2,}\b'   # expect no output
```

---

### Phase 4: Reconcile handoff-schema.md and orchestrate-state-machine.md [COMPLETED]

**Goal**: Make the docs describe what the code actually does — top-level phase accounting — and
replace the superseded "non-blocking warning" prescription for `plan_markers_verified` with the
fail-closed three-case contract.

**Tasks**:

- [x] `docs/architecture/handoff-schema.md`, "Complete JSON Schema" block (around lines 108-115):
      move `phases_completed` and `phases_total` OUT of `continuation_context` to the object's top
      level, leaving `continuation_context` holding `handoff_path` (and `orchestrator_mode` where
      shown). Keep `plan_markers_verified` at top level where it already is. *(completed)*
- [x] Same file, `### continuation_context` field definition (around line 169): state explicitly
      that `phases_completed`/`phases_total` are TOP-LEVEL fields, not members of
      `continuation_context`, and that `continuation_context` carries only `handoff_path` and
      `orchestrator_mode`. *(completed)*
- [x] Same file, "`orchestrator_mode` Flag in Continuation Context" example (around lines 265-270)
      and the "Partial with Continuation" example (around lines 393-398): move the two fields to
      top level in both JSON blocks. *(completed)*
- [x] Same file, `### plan_markers_verified` section (lines ~176-190): replace the
      "This warning does not block the next lifecycle phase" prescription with the actual gate
      contract — `plan_markers_verified` is the Case 3 corroborating signal in
      `skill_gate_completion_claim`; when phase accounting is present it is not consulted, and
      when phase accounting is absent an absent/false value REFUSES the completed transition and
      leaves the task continuation-eligible. Reproduce the four log-line shapes so they are
      greppable from the docs. *(completed)*
- [x] Same file, add a short **Handoff Writers** table (research Context Extension recommendation)
      naming the current writers so future work does not have to re-derive it: the hard-mode
      implementation agents' H9 wrap-up (core, plus the cslib and lean counterparts) as the only
      active writers, `skill_write_orchestrator_handoff` in `skill-base.sh` as defined but
      currently unreferenced, and an explicit note that base-mode research/plan/implement
      dispatches do not write this file at all. Reference these by file path only. *(completed)*
- [x] Same file, "Reading Contract" section: add the completion-claim gate to the description of
      what the orchestrator does with the parsed handoff, and state that it introduces NO new file
      read — it consumes only already-parsed fields, so the ~450-tokens-per-cycle flatness
      invariant is unchanged and the three sanctioned grep exceptions table is unaffected.
      *(completed)*
- [x] `docs/architecture/orchestrate-state-machine.md`, "Partial Recovery Flow" example (around
      lines 231-238): move `phases_completed`/`phases_total` to the top level of the handoff
      object in the illustrated flow. *(completed)*
- [x] Same file: document the refusal path — on a Case 1 or Case 3 refusal there is no status
      transition, the task stays `implementing`, `cycle_count` still increments, and the existing
      MAX_CYCLES / MAX_CYCLES_MT caps bound the retry. *(completed)*
- [x] Do NOT change `scripts/validate-handoff.sh`; it already requires top-level
      `phases_completed`/`phases_total`, which is now the documented canon. Record that agreement
      in the schema doc as corroboration. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`

**Verification**:

```bash
cd /home/benjamin/.config/nvim/agent-system/extensions/core/docs/architecture
# No JSON example nests the two fields under continuation_context any more.
# Extract each fenced json block and assert the fields, when present, are at depth 1.
python3 - <<'PY'
import json,re,glob,sys
bad=[]
for f in ["handoff-schema.md","orchestrate-state-machine.md"]:
    txt=open(f).read()
    for m in re.finditer(r"```json\n(.*?)```", txt, re.S):
        blk=m.group(1)
        # comment-free blocks only; schema block uses prose placeholders, so fall back to text check
        if "continuation_context" in blk:
            seg=blk.split("continuation_context",1)[1]
            seg=seg[:seg.find("}")+1] if "}" in seg else seg
            for fld in ("phases_completed","phases_total"):
                if fld in seg: bad.append((f,fld))
print("NESTED OCCURRENCES:",bad if bad else "none")
sys.exit(1 if bad else 0)
PY

# The superseded non-blocking prescription is gone
grep -n "does not block the next lifecycle phase" handoff-schema.md   # expect no output
# The gate is documented and greppable
grep -c "COMPLETION-CLAIM GATE" handoff-schema.md                     # expect >= 2
grep -c "skill_gate_completion_claim" handoff-schema.md orchestrate-state-machine.md
# Handoff Writers table present
grep -n "Handoff Writers" handoff-schema.md
# No task-number citations introduced (these files live outside specs/**)
cd /home/benjamin/.config/nvim
git diff -U0 agent-system/extensions/core/docs/architecture/ | grep -E '^\+' \
  | grep -nE '\(task [0-9]+\)|\btasks? [0-9]{2,}\b'                   # expect no output
git status --short .claude/ | grep -q . && echo "VIOLATION: .claude modified" || echo ".claude clean"
```

---

### Phase 5: Interaction verification (cycle caps, gate disjointness, uniformity) [COMPLETED]

**Goal**: Prove, by execution rather than assertion, that the new refusal path terminates against
the existing cycle caps, that the gate is disjoint from the staleness/recovery and drift paths,
and that all three call sites are byte-identical in shape.

**Tasks**:

- [x] **Cycle-cap bound (base)**: run a harness that simulates a persistently misreporting agent —
      a handoff with `status: "implemented"`, `phases_total: 0`, no `plan_markers_verified` — and
      confirm the loop terminates at `MAX_CYCLES=5` rather than spinning. *(completed: cap-test.sh
      simulate 5 → "base: BOUNDED, no false completion")*
- [x] **Cycle-cap bound (hard, multi-task)**: repeat the count with `MAX_CYCLES=13` and with
      `MAX_CYCLES_MT = min(task_count * 5, 25)` to confirm the same bound arithmetic holds. No
      code change is expected here; the point is to verify, not assume, since the Case 3 refusal
      path is new even though the increment/cap machinery is not. *(completed: hard=13 and
      multi-task=15 (3 tasks × 5) both BOUNDED, no false completion)*
- [x] **Increment unconditionality**: read the cycle-increment block that follows Stage 5 in both
      skills and confirm the only exemption is `infra_exempt_cycle`, i.e. a gate refusal always
      charges a cycle. Same for Stage MT-4's per-wave increment. *(completed: grep confirms
      `infra_exempt_cycle` present in both skills' post-Stage-5 increment blocks)*
- [x] **Staleness precedence**: confirm the gate call sits inside the `else` (handoff present and
      fresh) branch of the missing/stale `if`, so a leftover handoff from a prior run is routed to
      the recovery branch and never reaches this gate. *(completed: awk trace confirms both gate
      call sites in both skills sit inside the handoff-present `else` branch)*
- [x] **Recovery-grep disjointness**: confirm `skill_gate_completion_claim` neither calls nor is
      called from the phase-marker recovery grep, and that the gate adds no plan/report/summary
      read anywhere. *(completed: no `grep -cE '^### Phase'` or `recovered_completed`/
      `recovery_plan_path` reference in skill-base.sh)*
- [x] **Drift gate unweakened and reachable**: confirm the `dispatch_status = "partial"` drift
      block is unchanged, and evaluate its arithmetic against a synthetic partial handoff
      (`phases_completed=1`, `phases_total=6`) to show `invoke_drift_inspection` would fire — the
      research notes this path has likely never been observed firing in practice. *(completed:
      `git diff` shows no `invoke_drift_inspection` line changes; 1/6=0.1667 < threshold → fires)*
- [x] **Uniformity**: confirm the three call sites pass the same five arguments in the same order,
      differing only in task variable and log prefix. *(completed: all three pass
      task-var, phases_completed, phases_total, plan_markers_verified, log_prefix identically)*
- [x] Write the implementation summary recording: the DECISION POINT resolution (a), the two
      deliberate behavior changes (base loses blind-allow, hard loses blind-refuse on absent
      accounting), and the explicit note that a "Load Core" deploy is required before any of this
      takes effect at runtime under `.claude/`. *(completed)*

**Timing**: 45 minutes

**Depends on**: 2, 3, 4

**Files to modify**:

- `specs/898_completion_claim_verification_gate/summaries/01_completion-claim-verification-gate-summary.md`
  (new; the only file written outside `agent-system/extensions/core/**` in this plan)

**Verification**:

```bash
cd /home/benjamin/.config/nvim

# A. Cycle-cap termination harness — persistently misreporting agent, Case 3 refusal every cycle
cat > /tmp/claude-1000/-home-benjamin--config-nvim/cap-test.sh <<'CAPEOF'
set -u
export SKILL_REPO_ROOT=/home/benjamin/.config/nvim
source /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/skill-base.sh
simulate() { # simulate <max_cycles> <label>
  local MAX_CYCLES="$1" label="$2" cycle_count=0 transitions=0
  while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
    if skill_gate_completion_claim 898 0 0 absent "[test]" 2>/dev/null; then
      transitions=$((transitions + 1))
    fi
    cycle_count=$((cycle_count + 1))   # unconditional, mirrors the skills' increment
  done
  echo "$label: cycles=$cycle_count (cap $MAX_CYCLES) transitions=$transitions"
  [ "$cycle_count" -eq "$MAX_CYCLES" ] && [ "$transitions" -eq 0 ] \
    && echo "$label: BOUNDED, no false completion" || { echo "$label: FAILED"; exit 1; }
}
simulate 5  base
simulate 13 hard
task_count=3; mt=$(( task_count * 5 )); [ "$mt" -gt 25 ] && mt=25
simulate "$mt" multi-task
# Counter-case: once evidence appears, the very next cycle completes (no permanent lockout)
skill_gate_completion_claim 898 4 4 absent "[test]" 2>/dev/null \
  && echo "recovery: evidence present -> allows" || { echo "recovery: FAILED"; exit 1; }
CAPEOF
bash /tmp/claude-1000/-home-benjamin--config-nvim/cap-test.sh

# B. Increment unconditionality — the only exemption is the infra branch
grep -n -A4 'Increment cycle_count' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md | grep -c infra_exempt_cycle  # expect 2

# C. Staleness precedence — gate lives in the handoff-present branch
awk '/^else$/{inelse=NR} /skill_gate_completion_claim/{print FILENAME": gate at "NR", enclosing else at "inelse}' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md

# D. Recovery-grep disjointness — no cross-reference, no new artifact read
grep -n "grep -cE '\^### Phase" agent-system/extensions/core/scripts/skill-base.sh   # expect no output
grep -n "recovered_completed\|recovery_plan_path" agent-system/extensions/core/scripts/skill-base.sh # expect no output

# E. Drift gate unchanged and reachable
git diff -U0 agent-system/extensions/core/skills/ | grep -E '^[-+].*invoke_drift_inspection'  # expect no output
awk 'BEGIN{r=1/6; print "ratio", r, (r < 0.5) ? "-> drift inspection FIRES" : "-> no inspection"}'

# F. Uniformity across the three call sites
grep -n -A1 "skill_gate_completion_claim" \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
grep -rc "skill_gate_completion_claim" agent-system/extensions/core/scripts/skill-base.sh  # expect 1 definition site

# G. Source-store rule and deliverable-citation rule
git status --short | grep '^ *M \.claude/' && echo "VIOLATION: .claude modified" || echo ".claude clean"
git diff -U0 agent-system/ | grep -E '^\+' | grep -nE '\(task [0-9]+\)|\btasks? [0-9]{2,}\b'  # expect no output

# H. Re-run Phase 1's full three-case harness against the final state
bash /tmp/claude-1000/-home-benjamin--config-nvim/gate-test.sh
```

Phase is complete only when the cap harness prints `BOUNDED, no false completion` for all three
caps, the recovery counter-case allows, and check H still prints `ALL GATE CASES PASS`.

---

## Testing & Validation

- [ ] `bash -n` passes on the modified `skill-base.sh`.
- [ ] All eight unit cases pass: Case 1 (short) refuses; Case 2 (exact and over-complete) allows;
      Case 3 with `plan_markers_verified=true` allows; Case 3 with `false`, `absent`, and `null`
      refuses; malformed non-integer accounting refuses via Case 3.
- [ ] Every gate log line names the task number and states which of the three cases fired, and
      carries the greppable `COMPLETION-CLAIM GATE case N/3` token.
- [ ] Exactly three call sites exist (base Stage 5, base Stage MT-4, hard Stage 5), all passing
      the same five arguments; the three previously copy-pasted inline gates are gone.
- [ ] Simulated persistent misreporting terminates at MAX_CYCLES=5 / 13 / MAX_CYCLES_MT with zero
      false completions, and a single cycle with real evidence still completes normally.
- [ ] The drift-detection gate, the partial/blocker routing, the staleness gate, the infra-failure
      discrimination, and the phase-marker recovery exception are byte-unchanged.
- [ ] No JSON example in either architecture doc nests `phases_completed`/`phases_total` under
      `continuation_context`; the superseded "non-blocking warning" prescription is gone.
- [ ] `git status --short .claude/` is empty for the whole implementation.
- [ ] No task-number citation is introduced in any added line outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — new `skill_gate_completion_claim`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 and Stage MT-4 wired.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 5 wired.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — top-level canon,
  fail-closed `plan_markers_verified` contract, Handoff Writers table.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — top-level canon
  in the recovery-flow example, refusal path documented.
- `specs/898_completion_claim_verification_gate/summaries/01_completion-claim-verification-gate-summary.md`

## Rollback/Contingency

All changes are confined to five files in the source store, and none of them affect runtime
behavior until a separate "Load Core" deploy copies them into `.claude/`. That deploy is NOT part
of this task, so an unshipped defect here cannot break a live orchestration run.

To revert before deploy, snapshot first (the destructive-git guard blocks path discards on a dirty
tree without one), then restore the five paths:

```bash
bash .claude/scripts/git-snapshot.sh
git restore agent-system/extensions/core/scripts/skill-base.sh \
            agent-system/extensions/core/skills/skill-orchestrate/SKILL.md \
            agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md \
            agent-system/extensions/core/docs/architecture/handoff-schema.md \
            agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md
```

Partial-failure contingency: if Phase 1 lands but a call-site phase does not, the tree is still
consistent — `skill_gate_completion_claim` is additive and simply unreferenced by the un-wired
site, which keeps its existing inline arithmetic gate and behaves exactly as it does today. There
is no intermediate state in which a call site references a function that does not exist, because
Phases 2-4 all depend on Phase 1.
