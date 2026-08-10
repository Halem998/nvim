# Implementation Plan: Task #891

- **Task**: 891 - Gate /orchestrate completed transition on phases_completed >= phases_total
- **Status**: [COMPLETED]
- **Effort**: 1.25 hours
- **Dependencies**: None (wave-1 root). Tasks 895 and 897 also edit both orchestrate SKILL.md files downstream — keep this diff minimal and localized.
- **Research Inputs**: `specs/891_gate_orchestrate_completion_on_phase_progress/reports/01_gate-completion-on-phase-progress.md`
- **Artifacts**: plans/01_gate-completion-on-phase-progress.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/orchestrate` currently flips a task to `completed` on any `dispatch_status = "implemented"`
handoff, with zero awareness of phase accounting — so an implementation agent that prematurely
self-declares "implemented" after phase 4 of 8 permanently marks the task (and its plan file)
complete. This plan adds a phase-completion gate at the two ungated call sites in the base
`skill-orchestrate` skill (single-task Stage 5, multi-task Stage MT-4), and verifies — without
editing — that the equivalent hard-mode site already carries the guard. The gate is
`phases_total > 0 && phases_completed >= phases_total`, with an explicit pass-through when
`phases_total` is 0 or absent so handoffs that carry no phase accounting keep completing exactly
as they do today.

### SOURCE-STORE RULE (binding, read before touching any file)

The agent-system source of truth is **`agent-system/extensions/core/`**. The `.claude/` tree is a
gitignored, untracked, disposable deploy artifact regenerated from the source store by the
`<leader>al` picker/loader. **Every edit in this plan targets `agent-system/extensions/**` and
never `.claude/**`.** An edit written to `.claude/` is silently wiped by the next regeneration and
will read as "the fix vanished". All paths below are relative to the repository root
(`/home/benjamin/.config/nvim`).

At plan time the deploy copy `.claude/skills/skill-orchestrate/SKILL.md` was verified
byte-identical to its source-store original, so line numbers cited here are valid for both — but
only the source-store file is edited.

### Research Integration

Key findings carried into this plan:

- **Two ungated sites, not four.** `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  Stage 5 (`implemented)` case arm, lines 410-412) and Stage MT-4 (step 3's `"implemented"`
  bullet, line 778).
- **Stage MT-4 never reads phase accounting at all.** There is no `jq -r '.phases_completed'`
  anywhere in lines 711-790, so that site needs a *new read* plus the gate — gating without the
  read would reference unset variables.
- **`skill-orchestrate-hard/SKILL.md` Stage 5 (lines 661-683) already has the guard**, added by a
  prior fix. It is a **confirmation-only site**: verify, do not re-edit.
- **Hard mode's Multi-Task Mode delegates to base's MT-1..MT-5**, so fixing base Stage MT-4 fixes
  the multi-task path for both variants. There is no separate hard-mode MT-4.
- **`continuation_context` is not a usable gate signal.** It is `null` on every `"implemented"`
  handoff by design (it is a `partial`-only field), so it cannot distinguish "phase done, task not
  done" from "task fully done". It must not appear in the boolean expression.
- **Downstream is already correct.** Stage MT-4 step 5 re-reads `fresh_status` from `state.json`
  and only adds to `completed_tasks` when it equals `"completed"`; a task left at `implementing`
  falls into its `Otherwise` branch and stays eligible. No downstream changes are required.
- **Out of scope:** an `update-task-status.sh` defense-in-depth backstop (the script takes no
  phase-accounting arguments today and is shared by `reconcile-task-status.sh`,
  `manage-topics.sh`, and `command-gate-out.sh`). Research recommends a separate follow-up task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided for this task; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- Gate the base-mode single-task `implemented` -> `completed` postflight on
  `phases_total > 0 && phases_completed >= phases_total`.
- Gate the base-mode multi-task (Stage MT-4) `implemented` -> `completed` postflight on the same
  condition, adding the per-task `phases_completed`/`phases_total` read it currently lacks.
- Preserve today's behavior exactly when `phases_total` is 0 or absent.
- Make the not-yet-done branch a clean *continue-implementing* branch: no status transition, state
  stays `implementing`, loop bookkeeping unchanged, next cycle re-dispatches.
- Confirm (no edit) that `skill-orchestrate-hard/SKILL.md` Stage 5 already implements the guard.

**Non-Goals**:

- No edit to `skill-orchestrate-hard/SKILL.md` (its Stage 5 guard already exists and is correct
  for hard mode's per-phase dispatch model).
- No changes to `update-task-status.sh` or `skill-base.sh` — the script-layer backstop is a
  separate follow-up task.
- No task-number-citation cleanup sweep. `skill-orchestrate-hard/SKILL.md` contains three
  "772 Item 5B" citations (lines 619, 661, 717) that violate
  `.claude/rules/no-task-references-in-deliverables.md`. **No phase in this plan edits any of
  those lines**, so none of them are touched or expanded; leave them for a dedicated cleanup task.
- No fix to the `handoff-schema.md` documentation drift (schema example nests
  `phases_completed`/`phases_total` under `continuation_context`; the code treats them as
  top-level). Informational only.
- No regeneration of `.claude/` — that is the user's `<leader>al` picker/loader action.

## Desired Behavior (precise restatement)

Given `phases_completed` and `phases_total` read from the dispatched task's own
`.orchestrator-handoff.json` (both optional top-level integer fields, read with a `// 0` default),
on a handoff whose `status` is `"implemented"`:

| Condition | Action |
|-----------|--------|
| `phases_total == 0` (0, absent, or null) | **Preserve today's behavior**: call `skill_postflight_update ... implement` and complete the task exactly as before. Handoffs with no phase accounting must never regress into never completing. |
| `phases_total > 0` and `phases_completed >= phases_total` | Call `skill_postflight_update ... implement` — the task completes. |
| `phases_total > 0` and `phases_completed < phases_total` | **Continue-implementing branch**: skip the postflight call entirely, log the progress line, leave the task at `implementing`, let the loop dispatch the next phase. |

**What the continue-implementing branch must do about loop/cycle bookkeeping** (single-task,
Stage 5):

1. **No status transition.** `skill_postflight_update` is not called, so `state.json` keeps
   `status: "implementing"` and the plan file's own `- **Status**:` field is not stamped
   `[COMPLETED]`.
2. **Artifact linking still runs.** The artifact-linking block that follows the `case` statement
   (lines 418-444) is *outside* the gate and stays unconditional — a summary artifact produced by
   the partial run is still linked, matching hard mode.
3. **`cycle_count` still increments.** The `cycle_count=$((cycle_count + 1))` at the end of Stage 5
   is outside the `case` and must not be moved into a branch. This is what prevents an infinite
   spin: a misreporting implementer burns cycles and the run exits `partial` at `MAX_CYCLES` (5)
   rather than looping forever.
4. **Next cycle re-dispatches.** Stage 3a re-reads `current_status = "implementing"`, and Stage 4's
   combined `planned`/`implementing` handler re-runs `skill_preflight_update ... implement` (an
   idempotent no-op here) and re-invokes the implement agent with the same `plan_path`. The
   implement skill resumes from the first non-`[COMPLETED]` phase, so this is forward progress,
   not a repeat. No stall: the state is a live, dispatchable state, not a terminal or in-flight
   one.

**And in multi-task mode** (Stage MT-4): identical, expressed through the MT loop's own
bookkeeping — step 4 (artifact linking) and step 6 (unconditional per-task lock release) still
run; step 5 reads `fresh_status = "implementing"` and takes its existing `Otherwise:
set current_statuses[task_num] = fresh_status` branch (not `completed_tasks`, not
`failed_tasks`); MT-3 step 6 still increments `cycle_count`; and on the next MT-3 iteration the
task passes the step-3 eligibility filter (not terminal, not in-flight `researching`/`planning`,
not failed) and is re-dispatched, bounded by `MAX_CYCLES_MT`.

## Critical Implementation Note: do NOT copy the hard-mode expression verbatim

Hard mode's guard is:

```bash
if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
```

That form **does not complete** when `phases_total == 0` — it falls to the else branch. That is
acceptable in hard mode, where per-phase dispatch always populates phase accounting, but it would
**violate this task's binding constraint** in base mode, where a handoff with no phase accounting
must still complete as it does today. Base mode therefore uses the pass-through form:

```bash
if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]; then
```

which is `phases_total == 0` (preserve old behavior) **OR** the requested
`phases_total > 0 && phases_completed >= phases_total`. The two forms are deliberately different.
This asymmetry is intentional and is documented in the code comment added in Phase 1; it is not a
bug to "harmonize" and is not in scope to change on the hard-mode side.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer copies the hard-mode `-gt 0 &&` expression into base mode, regressing zero-phase-accounting handoffs into never completing | H | M | The "Critical Implementation Note" section above plus Phase 1's checklist state the exact required expression; Phase 3 greps for the correct form in both sites |
| Gating Stage MT-4 without adding the phase-accounting read leaves the variables unset/stale | H | M | Phase 2 sequences the read as an explicit sub-step *before* the conditional, and requires the read be scoped per-task inside the loop (fresh per handoff, never carried over from a prior task in the same wave) |
| Implementer edits `.claude/skills/...` instead of `agent-system/extensions/core/skills/...` — change silently wiped on next regeneration | H | M | SOURCE-STORE RULE stated in the overview and repeated in every phase's file list; Phase 3 verifies the source-store file contains the gate |
| Edits to hard-mode Stage 5 duplicate or conflict with the existing guard | M | L | Phase 3 is confirmation-only with an explicit "no Edit/Write to this file" instruction and a `git diff --stat` check that the hard-mode file is untouched |
| Merge/edit conflict with tasks 895 and 897, which also touch both orchestrate SKILL.md files | M | M | Keep the diff minimal and localized to the two identified regions; do not reflow, renumber, or reformat surrounding text; do not touch the "772 Item 5B" citation lines |
| Continue-branch causes a stall (task never completes) or a spin (endless re-dispatch) | M | L | Bookkeeping is explicitly unchanged: `cycle_count` increments outside the `case`, `MAX_CYCLES`/`MAX_CYCLES_MT` bound the run, and `implementing` is a dispatchable state in Stage 4; Phase 3 verifies the increment is still outside the `case` |
| Accidentally introducing a task-number citation in a deliverable file | L | M | Phases 1-2 mandate comment text with no task numbers; Phase 3 greps the diff for task-citation patterns |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 are logically independent but
edit the same file (`skill-orchestrate/SKILL.md`), so they are serialized as a territory
constraint to avoid conflicting concurrent edits — not because of a data dependency.

---

### Phase 1: Gate the single-task Stage 5 `implemented)` arm [COMPLETED]

**Goal**: The base-mode single-task postflight only transitions a task to `completed` when phase
accounting confirms every phase is done, or when no phase accounting is present.

**Tasks**:

- [x] Open `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (SOURCE STORE — not
      `.claude/`). Locate the Stage 5 `case "$dispatch_status" in` block; the `implemented)` arm is
      at approximately lines 410-412. *(completed)*
- [x] Confirm before editing that `phases_completed` and `phases_total` are already read above at
      approximately lines 386-387 (`jq -r '.phases_completed // 0'` / `jq -r '.phases_total // 0'`).
      No new read is needed at this site. *(completed)*
- [x] Replace the two-line unconditional arm with the gated form below. Do not modify the
      `researched)`, `planned)`, or `*)` arms, the drift-detection block above, or the
      artifact-linking block below. *(completed)*

Current text to replace:

```bash
    implemented)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
```

Replacement text:

```bash
    implemented)
      # Phase-completion gate: a dispatch reporting "implemented" must not flip the whole task
      # to `completed` while the plan still has phases left. When the handoff carries no phase
      # accounting (`phases_total` 0 or absent) the historical unconditional behavior is
      # preserved — such handoffs must never regress into never completing. Note this differs
      # deliberately from the hard-mode expression, which requires `phases_total > 0`: hard
      # mode's per-phase dispatch always populates phase accounting, base mode's does not.
      if [ "$phases_total" -eq 0 ] || [ "$phases_completed" -ge "$phases_total" ]; then
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      else
        echo "[orchestrate] Phase ${phases_completed}/${phases_total} complete — task not done. Continuing." >&2
        # No status transition: state stays `implementing`. `cycle_count` still increments at the
        # end of this stage, Stage 3a re-reads `implementing` next cycle, and Stage 4's
        # `planned`/`implementing` handler re-dispatches the implement agent against the same
        # plan (which resumes at the first non-completed phase). MAX_CYCLES bounds this, so a
        # misreporting agent exits `partial` rather than looping forever.
      fi
      ;;
```

- [x] Verify the `cycle_count=$((cycle_count + 1))` at the end of Stage 5 is still outside the
      `case` statement and was not moved into a branch. *(completed)*
- [x] Confirm no task numbers appear in the added comment text (per
      `.claude/rules/no-task-references-in-deliverables.md`). *(completed)*

**Timing**: 0.4 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 5 `implemented)` case
  arm (~lines 410-412) replaced with the gated conditional above.

**Verification**:

```bash
# The gate expression is present in the base skill
grep -n 'phases_total" -eq 0 \] || \[ "\$phases_completed" -ge' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
# The continue-branch log line is present
grep -n 'task not done. Continuing' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
# cycle_count increment still exists exactly once at Stage 5 tail
grep -n 'cycle_count=\$((cycle_count + 1))' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
```

- The `implemented)` arm now contains an `if`/`else`; the `researched)` and `planned)` arms are
  byte-identical to before (`git diff` shows changes only inside the `implemented)` arm).
- `continuation_context` does not appear anywhere in the new conditional.
- `git diff --stat` lists only `skill-orchestrate/SKILL.md`.

---

### Phase 2: Gate the multi-task Stage MT-4 per-task postflight [COMPLETED]

**Goal**: The multi-task per-task postflight loop reads each task's phase accounting from its own
handoff and applies the same gate — closing the site that currently has no phase awareness at all.
Because hard mode's Multi-Task Mode delegates to these same stages, this fixes the multi-task path
for both variants.

**Tasks**:

- [x] Open `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (SOURCE STORE).
      Locate `### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight`; the per-task
      postflight list is at approximately lines 772-790, with the `"implemented"` bullet at
      approximately line 778. *(completed)*
- [x] **First** extend step 2 to read phase accounting per task (this must precede the gate —
      gating without the read would reference unset values). *(completed)*
- [x] **Then** replace step 3's `"implemented"` bullet with the gated form. *(completed)*
- [x] Leave steps 1, 4, 5, and 6 unchanged. *(completed)*

Current text of steps 2-3:

```
2. Extract `dispatch_status`, `dispatch_summary`, artifact path/type/summary.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented`
   - Other → no postflight update
```

Replacement text:

```
2. Extract `dispatch_status`, `dispatch_summary`, artifact path/type/summary, and — from *this*
   task's own handoff, freshly per task — `phases_completed` (`jq -r '.phases_completed // 0'`)
   and `phases_total` (`jq -r '.phases_total // 0'`), mirroring the Stage 5 reads. Never carry
   these values over from a previous task in the same wave; re-read them for every task in the
   loop.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → apply the same phase-completion gate as Stage 5. Call
     `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented`
     **only if** `phases_total` is 0 (no phase accounting — preserve the historical behavior) **or**
     `phases_completed >= phases_total`. Otherwise **skip the postflight call**, log
     `[orchestrate] Task {task_num}: phase {phases_completed}/{phases_total} complete — task not done. Continuing.`,
     and leave the task at `implementing`. Steps 4-6 below still run unchanged: the artifact is
     still linked, step 5 reads `fresh_status = "implementing"` and takes its `Otherwise` branch
     (not `completed_tasks`), and the per-task lock is still released. The task stays eligible in
     Stage MT-3's next cycle and is re-dispatched, bounded by `MAX_CYCLES_MT`.
   - Other → no postflight update
```

- [x] Confirm step 5's existing branches (`fresh_status = "completed"` → `completed_tasks`;
      `dispatch_status` failed/blocked → `failed_tasks`; otherwise → `current_statuses`) are
      unchanged — research confirmed they already handle a non-`completed` `fresh_status`
      correctly. *(completed)*
- [x] Confirm no task numbers appear in the added text. *(completed)*

**Timing**: 0.4 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 step 2 (add
  per-task phase-accounting read) and step 3's `"implemented"` bullet (~line 778, add the gate).

**Verification**:

```bash
# Stage MT-4 now reads phase accounting (previously zero hits in this range)
sed -n '/### Stage MT-4/,/### Stage MT-5/p' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | grep -n 'phases_completed'
# The MT-4 gate wording is present
sed -n '/### Stage MT-4/,/### Stage MT-5/p' \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | grep -n 'phases_completed >= phases_total'
```

- The MT-4 range contains at least one `phases_completed` and one `phases_total` reference
  (it contained none before this phase).
- Steps 1, 4, 5, 6 of the per-task postflight list are unchanged in `git diff`.
- The `researched`/`planned` bullets in step 3 are unchanged.
- `continuation_context` does not appear in the new MT-4 text.

---

### Phase 3: Confirm hard-mode site and verify the whole change [COMPLETED]

**Goal**: Positively confirm that `skill-orchestrate-hard/SKILL.md` Stage 5 already implements the
requested guard (so no edit is made and 895/897 do not attempt to re-add it), and verify both base
edits are correct, minimal, and source-store-only.

**Tasks**:

- [x] **Read only** (no Edit, no Write) `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
      lines 655-690. Confirm the `implemented)` arm contains
      `if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then` with an
      `else` branch that logs and performs no status transition. *(completed: confirmed at lines
      669-679 — guard present, no edit made)*
- [x] Record in the implementation summary that this site is **already fixed — confirmed, not
      edited**, and that its `-gt 0 &&` form intentionally differs from base mode's `-eq 0 ||`
      form (see the Critical Implementation Note above). *(completed)*
- [x] Confirm the "772 Item 5B" citation lines (619, 661, 717) in the hard-mode file were **not**
      touched — no edit in this task goes near them, and cleaning them up is a separate task.
      *(completed: zero diff on this file confirms no lines touched)*
- [x] Verify that `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` has zero
      changes in `git diff`. *(completed: `git diff --stat` empty)*
- [x] Verify no file under `.claude/` was modified by this task. *(completed: `git status --short
      --untracked-files=all -- .claude` returned no output)*
- [x] Verify no task-number citations were introduced by the diff. *(completed: grep for
      citation pattern in agent-system/ diff returned none)*
- [x] Confirm `update-task-status.sh` and `skill-base.sh` are unmodified (script-layer backstop is
      a separate follow-up task, deliberately out of scope). *(completed: `git diff --stat` on
      agent-system/extensions/core/scripts/ empty)*

**Timing**: 0.35 hours

**Depends on**: 1, 2

**Files to modify**: none (verification and confirmation only).

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — **read only, confirm no
  change needed**.

**Verification**:

```bash
# Hard-mode guard confirmed present (read-only check)
grep -n 'phases_total" -gt 0 \] && \[ "\$phases_completed" -ge' \
  agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md

# Only the base skill file changed
git status --short

# No .claude/ deploy-tree edits
git status --short --untracked-files=all -- .claude | head

# No task-number citations introduced outside specs/
git diff -- agent-system/ | grep -nE '^\+.*\b[Tt]ask [0-9]{2,4}\b'   # expect no output

# Shared script layer untouched
git diff --stat -- agent-system/extensions/core/scripts/   # expect no output
```

- `git status --short` lists exactly one modified agent-system file:
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`.
- The hard-mode grep returns a hit (guard present) and the hard-mode file shows no diff.
- The task-citation grep returns no output.
- The scripts-directory diff is empty.

---

## Testing & Validation

This is a markdown skill-definition change; there is no executable test harness. Validation is
structural review plus behavioral trace:

- [x] Trace 1 — no phase accounting: a handoff with `status: "implemented"` and no
      `phases_total` field. Read with `// 0` → `phases_total = 0` → first disjunct true →
      `skill_postflight_update ... implement` runs → task completes. **Behavior identical to
      today** (the required non-regression). *(verified against the committed `-eq 0 ||` expression)*
- [x] Trace 2 — all phases done: `phases_completed = 8`, `phases_total = 8` → second disjunct
      true → postflight runs → task completes. *(verified)*
- [x] Trace 3 — premature completion (the observed failure): `phases_completed = 4`,
      `phases_total = 8` → both disjuncts false → no postflight call → `state.json` stays
      `implementing`, plan file Status is not stamped `[COMPLETED]`, artifact still linked,
      `cycle_count` increments, next cycle re-dispatches implement from phase 5. **Bug fixed.**
      *(verified: `else` branch skips `skill_postflight_update`, artifact-linking block and
      `cycle_count` increment remain outside the `case`)*
- [x] Trace 4 — multi-task: same three cases through Stage MT-4, confirming step 5's
      `fresh_status = "implementing"` lands in the `Otherwise` branch and the task remains
      eligible in the next MT-3 cycle. *(verified: MT-4 step 3 gate mirrors Stage 5, steps 4-6
      unchanged)*
- [x] Trace 5 — no infinite spin: an implementer that repeatedly returns `implemented` with
      `4/8` burns `cycle_count` each cycle and exits `partial` at `MAX_CYCLES` (5) / `MAX_CYCLES_MT`.
      *(verified: cycle-count bookkeeping untouched by this change)*
- [x] `continuation_context` appears nowhere in either new gate. *(verified via review of both diffs)*
- [x] All edits are in `agent-system/extensions/core/`; `.claude/` is untouched. *(verified via
      `git status --short --untracked-files=all -- .claude`)*

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (two localized edits).
- Unmodified but confirmed: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
- Implementation summary at
  `specs/891_gate_orchestrate_completion_on_phase_progress/summaries/01_gate-completion-on-phase-progress-summary.md`,
  recording: both edit sites, the confirmation-only hard-mode finding, the deliberate expression
  asymmetry between base and hard mode, and the recommended follow-up task for the
  `update-task-status.sh` backstop.
- **Deploy note (not an implementation step)**: the fix becomes live in `.claude/` only after the
  user regenerates the deploy tree via the `<leader>al` picker/loader. The implementer must not
  write to `.claude/` to shortcut this.

## Rollback/Contingency

- Both edits are contained in a single file and a single commit. Revert with
  `git checkout HEAD -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  (working tree must be clean or snapshotted first, per `.claude/rules/git-workflow.md`), then
  regenerate `.claude/`.
- If the gate proves too aggressive — e.g. a task type whose implement agent legitimately reports
  `implemented` with stale phase counters and now never completes — the narrowest mitigation is to
  widen the pass-through disjunct (treat a missing *or* implausible `phases_total` as no phase
  accounting) rather than removing the gate. Escalate to `/revise 891` rather than reverting
  silently.
- The change is behavior-narrowing only: it can prevent a completion that previously happened, but
  it can never cause a completion that previously did not. The only regression risk is a task
  stuck at `implementing`, which is visible in `state.json`/TODO.md, bounded by `MAX_CYCLES`, and
  recoverable with `/implement 891` or a manual status sync.
