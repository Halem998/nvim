# Implementation Plan: Task #35

- **Task**: 35 - Stop preflight from auto-advancing an undispatched plan phase to [IN PROGRESS]
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: 16, 33 (both completed; task 33 shares `skill-orchestrate-hard/SKILL.md` edit territory)
- **Research Inputs**: specs/035_stop_preflight_spurious_phase_advance/reports/01_preflight-phase-advance-defect.md
- **Artifacts**: plans/01_delete-preflight-phase-autoadvance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`update_plan_file()` in `agent-system/extensions/core/scripts/update-task-status.sh` performs a
per-phase side effect on every implement preflight: it independently re-derives "the first
`[NOT STARTED]` phase" with its own `grep -m1` scan and marks it `[IN PROGRESS]`, without knowing
which phase (if any) the caller is about to dispatch. This plan **deletes** that convenience
outright, updates the one stale comment block that describes it, and adds regression coverage
asserting a non-dispatching preflight leaves plan phase headings byte-identical.

**Every edit target is under `agent-system/extensions/core/**`.** The `.claude/**` tree is a
gitignored, regenerated deploy artifact: it is *read and executed* (test suites,
`verify-deploy.sh`, `deploy-headless.sh`) but never hand-edited.

**Sequencing constraint that shapes this plan**: both test suites in scope copy their
system-under-test from the **deployed** `.claude/scripts/` tree, not from the source store. A
source-store edit is therefore invisible to the suites until a regeneration runs. Phase 2 exists
solely to close that gap before any new test is written, so every later phase can be verified
green rather than committed red.

### Research Integration

The research report is the primary input and settles four questions this plan does not
re-litigate:

- **Fix strategy is deletion, not gating (Acceptance Criterion 2a).** Verified: both
  `general-implementation-agent.md` (Stage 4A) and `general-implementation-hard-agent.md`
  (Stage 4A) unconditionally call `update-phase-status.sh ... IN_PROGRESS` for whatever phase
  they actually work on, as the first action of processing that phase. No path was found that
  depends on the plan file already showing `[IN PROGRESS]` before that self-mark; the hard
  engine's own next-phase scan matches `NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED`, so leaving a
  phase at `[NOT STARTED]` never makes it unselectable. The convenience is redundant, and worse
  than redundant: its narrower `[NOT STARTED]`-only match criterion cannot agree with the
  orchestrator's wider selection criterion whenever the dispatched phase is a resumed
  `[IN PROGRESS]`/`[PARTIAL]`/`[BLOCKED]` one — the exact divergence that marked an undispatched
  later phase.
- **The task description's "IMPORTANT SCOPE WIDENING" premise is FALSE (Acceptance Criterion 3).**
  `update_plan_file()` opens with an unconditional
  `if [[ "$target_status" != "implement" ]]; then return 0; fi` **before** the
  `operation == "preflight"` check. Research verified via `git log -p` that this guard is
  pre-existing, not accidental. Research and plan preflights therefore cannot reach the phase
  logic today, and **no code change is owed for those two slots**. AC 3 is satisfied by recording
  this finding — investigated and refuted — rather than by planning work for slots that are
  already correct. This plan does not touch the research/plan slots, and Phase 1 records the
  finding durably in a code comment at the retained guard.
- **Co-maintenance scope is one comment block.** `skill-orchestrate-hard/SKILL.md` carries a
  comment (research: lines 822-827) asserting the auto-advance is safe; it becomes false prose
  post-deletion. `skill-orchestrate/SKILL.md` has no equivalent comment (re-confirmed at planning
  time: `grep -n "auto-advance\|first-phase\|first phase"` hits only the hard-mode file, twice,
  both inside that one block). Phase 5 re-verifies this rather than assuming it.
- **Regression coverage belongs primarily in `test-update-task-status.sh`.** That suite exercises
  `update-task-status.sh` directly and already builds isolated fixture repos with conforming plan
  files. `test-skill-base-lifecycle.sh` Group 4 only ever passes `target_status="plan"` — a slot
  that never reaches the plan-file logic at all — so its coverage of this side effect is not thin,
  it is structurally absent.

Two facts were independently re-verified against live code at planning time, beyond the report:

1. **The phase-heading library must stay sourced.** `has_nonconforming_phase_headings`,
   `warn_nonconforming`, and the `PHASE_HEADING_TOTAL_ERE` family are still used by the
   `--phase-check` backstop elsewhere in `update-task-status.sh`. Deleting the auto-advance does
   not orphan the `scripts/lib/phase-heading-patterns.sh` sourcing block.
2. **`test-skill-base-lifecycle.sh`'s `build_fixture_repo` copies only five scripts** —
   `update-task-status.sh`, `state-write.sh`, `task-lock.sh`, `generate-todo.sh`,
   `deploy-root-guard.sh` — and **neither `update-plan-status.sh` nor `update-phase-status.sh`**.
   Without adding them, an implement-preflight case there would hit `update_plan_file()`'s
   "update-plan-status.sh not found" early return and pass vacuously **even with the defect
   present**. This is the single largest correctness trap in this plan and Phase 4 addresses it
   explicitly.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

`roadmap_path` was not supplied in the delegation context, so no roadmap was loaded or consulted
(`specs/ROADMAP.md` exists but is out of this dispatch's scope). `roadmap_flag` was absent, so no
roadmap review/update phases are added.

## Goals & Non-Goals

**Goals**:
- Remove every per-phase status write from `update_plan_file()`, so no preflight can mark a phase
  `[IN PROGRESS]` without a dispatch behind it (AC 1, AC 5).
- Record the deletion justification and the refuted scope-widening premise durably, in the plan
  and in a code comment (AC 2, AC 3).
- Add a regression test that would fail against the pre-fix script and cannot pass vacuously
  (AC 4).
- Keep the two orchestrate SKILL.md copies in agreement per their explicit co-maintenance
  contract.

**Non-Goals**:
- Any change to the research or plan `target_status` slots — verified already unreachable.
- Any change to the plan-level `[STATUS]` stamp (`IMPLEMENTING`/`COMPLETED` via
  `update-plan-status.sh`): a separate, correctly-scoped, non-buggy side effect.
- Any change to `skill-base.sh` — `skill_preflight_update` contains no phase logic.
- Any change to the `--phase-check` postflight backstop.
- Adding a dispatch-awareness parameter to `update-phase-status.sh` — deletion makes it moot.
- Authoring a context-file addendum about the divergent-rescan defect class (research's "Context
  Extension Recommendations"); out of scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A regression test passes vacuously because the fixture never reaches `update_plan_file()`'s phase logic | H | H | Every new case carries a **positive control**: assert the plan-level status line DID flip to `[IMPLEMENTING]`, proving the function was entered and the plan file was found. Phase 4 additionally adds the two missing scripts to the lifecycle fixture's copy loop |
| Suites are run against a stale deployed tree and report a false result either way | H | H | Phase 2 redeploys and re-runs baselines before any test is written; Phase 6 redeploys again and re-runs everything after all edits |
| Deleting the convenience regresses an unseen consumer of the pre-dispatch `[IN PROGRESS]` marker | M | L | Research grepped every `update-phase-status.sh` call site and every "first NOT STARTED" phrasing; only the deleted block and the two agents' Stage 4A calls exist. Phase 2's baseline suite run is the empirical check |
| Deleting too much: the retained `target_status != implement` guard or the plan-level stamp gets caught in the excision | H | L | Phase 1 enumerates what stays, verifies by diff read-through, and asserts `grep -c 'update-phase-status.sh'` on the file goes to exactly 0 with the `update-plan-status.sh` call still present |
| Co-maintenance contract violated by editing one SKILL.md and not the other | M | L | Phase 5's first task is a fresh `grep` across both files; the edit is only applied where a match exists, and the absence result is recorded in the summary |
| `skill-orchestrate-hard/SKILL.md` edit collides with the sibling task that also edits it | M | L | That task (dependency 33) is already complete and committed; Phase 5 re-reads the current file content rather than applying a line-anchored patch |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel. Wave 3's three phases touch three disjoint
files (`test-update-task-status.sh`, `test-skill-base-lifecycle.sh`,
`skill-orchestrate-hard/SKILL.md`) and share no edit territory.

---

### Phase 1: Delete the preflight phase auto-advance convenience [COMPLETED]

**Goal**: `update_plan_file()` no longer writes any per-phase status marker, on any path.

**Tasks**:
- [x] Re-read `update_plan_file()` in full in
      `agent-system/extensions/core/scripts/update-task-status.sh`. Locate the deletable unit by
      **content anchor, not line number**: the `if [[ "$operation" == "preflight" ]]; then`
      statement that follows the `update-plan-status.sh` invocation, headed by the comment
      `# Auto-advance the first NOT STARTED phase to IN PROGRESS on implement preflight` and whose
      body opens `local phase_script="$SCRIPT_DIR/update-phase-status.sh"`. *(completed)*
- [x] Delete that entire `if ... fi` statement, including its nested `has_nonconforming_phase_headings`
      guard, the `plan_dir`/`plan_file` resolution, the `grep -m1` scan, and the
      `update-phase-status.sh ... IN_PROGRESS` call. *(completed)*
- [x] Delete the nested dry-run preview inside the `DRY_RUN` branch (the
      `if [[ "$operation" == "preflight" ]]` block echoing
      `[dry-run] Phase status: first [NOT STARTED] phase -> [IN PROGRESS] ...`), so the preview no
      longer advertises a side effect that no longer happens. Keep the surrounding
      `[dry-run] Plan file: status -> ...` echo and the `return 0`. *(completed)*
- [x] Leave untouched, and confirm by diff read-through: the `target_status != implement` early
      return, the `plan_status` case statement, the `project_name` lookup, the `plan_script`
      executability check, and the `update-plan-status.sh` invocation with its
      postflight-fatal/preflight-warn branch. *(completed: git diff confirms only the two deleted
      regions and the one added comment changed)*
- [x] Add a short comment at the retained `target_status != implement` guard recording that (a)
      this guard is the sole bound on plan-file side effects, which is why research and plan
      operations never reach them, and (b) this function no longer touches per-phase markers —
      the dispatched agent owns every per-phase transition directly. Use durable anchors only; no
      task-number references (this file is outside `specs/**`). *(completed)*
- [x] Confirm the `scripts/lib/phase-heading-patterns.sh` sourcing block stays: its
      `has_nonconforming_phase_headings` / `warn_nonconforming` / `PHASE_HEADING_TOTAL_ERE`
      exports are still consumed by the `--phase-check` backstop later in the same script.
      *(completed: sourcing block and --phase-check usage confirmed unchanged)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The deletable unit is hypothesized to be one contiguous `if` statement
(research measured lines 526-585) plus a 3-line dry-run preview (measured lines 500-502), and
`update-task-status.sh` is hypothesized to contain no other `update-phase-status.sh` call.
Confirm at implementation time by running
`grep -n 'update-phase-status.sh' agent-system/extensions/core/scripts/update-task-status.sh`
before and after the edit: the before-count must match what is deleted, and the after-count must
be exactly 0. Do not trust the line numbers — anchor on content.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - delete the auto-advance `if`
  block and its dry-run preview; add the explanatory comment at the retained guard

**Verification**:
- `bash -n agent-system/extensions/core/scripts/update-task-status.sh` exits 0
- `grep -c 'update-phase-status.sh' agent-system/extensions/core/scripts/update-task-status.sh`
  returns 0
- `grep -c 'update-plan-status.sh' ...` is unchanged from before the edit (plan-level stamp intact)
- `grep -n 'has_nonconforming_phase_headings' ...` still shows the `--phase-check` usage
- `git diff` read-through confirms nothing outside the two deleted regions and the one added
  comment changed

---

### Phase 2: Redeploy and establish a green baseline [COMPLETED]

**Goal**: the deployed `.claude/` tree carries the Phase 1 fix, and the existing suites still pass
against it — the empirical check that deletion regressed nothing.

**Tasks**:
- [x] Run `bash .claude/scripts/deploy-headless.sh` from the repo root to regenerate the deployed
      tree from the source store. This is an explicit, deliberate invocation tied to the edit it
      exists to make live, not a silent side effect. *(completed)*
- [x] Run `bash .claude/scripts/verify-deploy.sh`; resolve any drift it reports (e.g.
      `index-entries.json` line-count drift from the Phase 1 edit) and re-run until it passes.
      *(completed: first run surfaced two unrelated-looking failures — gate 8 `run-all.sh` and
      gate 10 `validate-state.sh --deep`. Gate 8 traced to a real, in-scope regression:
      `test-resume-scan-nonconformance.sh`'s Site D structurally asserted the presence of the
      now-deleted `has_nonconforming_phase_headings "$plan_file"` guard inside the deleted
      auto-advance block. Fixed by updating that suite's Site D assertion to check for the
      guard's ABSENCE instead (confirming full deletion, not a partial edit) — see Plan
      Deviations. Gate 10 is pre-existing and unrelated (task 52's `blockers`/`priority` fields
      predate this session; see below). Second run: 22/23 pass, only gate 10 remains, named
      explicitly per the next task below.)*
- [x] Confirm the deployed copy carries the fix:
      `grep -c 'update-phase-status.sh' .claude/scripts/update-task-status.sh` returns 0.
      *(completed: deployed file contains only the two pre-existing, unrelated comment mentions
      at the `--phase-check` backstop section, lines 274/307 — the actual auto-advance call and
      its containing block are gone; `diff .claude/scripts/update-task-status.sh
      agent-system/extensions/core/scripts/update-task-status.sh` reports IDENTICAL)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — all
      existing cases (including the `--phase-check` cases 5-7) must pass. *(completed: 19 passed,
      0 failed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — all
      groups must pass. *(completed: 14 passed, 0 failed)*
- [x] Record both suites' pass/fail counts; a pre-existing failure unrelated to this change must
      be named explicitly rather than silently absorbed. *(completed: test-update-task-status.sh
      19/0, test-skill-base-lifecycle.sh 14/0. Named pre-existing unrelated failure:
      `validate-state.sh --deep` (verify-deploy.sh gate 10) reports two FAIL-level findings —
      "Unknown entry field: blockers" and "Unknown entry field: priority" — against project_number
      52 in the real `specs/state.json`. This predates this dispatch (specs/state.json was
      already `M`odified in `git status` before any Phase 1 edit) and is unrelated to
      `update-task-status.sh`'s per-phase marker logic; left unresolved as out of scope.)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- None (regeneration writes `.claude/**`, which is a generated artifact, not an edit target).
  Drift fixes surfaced by `verify-deploy.sh` are applied in the source store.

**Verification**:
- `verify-deploy.sh` exits 0
- Both named suites exit 0
- Deployed `update-task-status.sh` contains no `update-phase-status.sh` reference

---

### Phase 3: Primary regression case in test-update-task-status.sh [NOT STARTED]

**Goal**: a case proving a non-dispatching implement preflight leaves plan phase headings exactly
as it found them — the coverage AC 4 requires.

**Tasks**:
- [ ] Read the suite's existing case list and the fixture setup used by the `--phase-check` cases
      (which build their own plan file inline; `build_fixture_repo` itself does **not** create
      one). Reuse that shape rather than inventing a new one.
- [ ] Append a new case after the last existing one, following the file's established structure:
      `info` banner, fresh `FIXTURE_ROOT`, `build_fixture_repo`, `UTS`/`task_status` helpers,
      `pass`/`fail` assertions.
- [ ] In the fixture, set the task's `status` to a value from which an implement preflight is
      legitimate (e.g. `planned`), and create
      `specs/001_fixture_task/plans/01_fixture-plan.md` with a plan-level
      `- **Status**: [NOT STARTED]` line and at least **two** conforming phase headings, both
      `[NOT STARTED]`.
- [ ] Snapshot every `^### Phase ` line before the call, run
      `UTS preflight 1 implement sess_test_<n>`, snapshot again, and assert the two snapshots are
      byte-identical.
- [ ] Assert additionally and specifically that no phase heading contains `[IN PROGRESS]` after
      the call.
- [ ] **Positive control (required)**: assert the call exited 0 **and** that the plan-level
      `- **Status**:` line became `[IMPLEMENTING]`. Without this, the case would pass even if the
      fixture plan file were never found, making it worthless as a regression guard.
- [ ] Add a case header comment naming the regression guarded: a preflight that dispatches nothing
      for a phase must never advance that phase's marker, because a false marker feeds fabricated
      territory-conflict signals into hard-mode dispatch reasoning.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The suite is hypothesized to hold 9 cases, with `build_fixture_repo`
creating no plan file and `REQUIRED_SCRIPTS` already including `update-plan-status.sh` and
`update-phase-status.sh`. Confirm at implementation time by reading `REQUIRED_SCRIPTS` and one
existing plan-file-building case before writing the new one; if `REQUIRED_SCRIPTS` lacks either
script, add it, or the case will pass vacuously.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - append the regression
  case

**Verification**:
- Suite exits 0 with the new case reported PASS, and the total case count increased
- Non-vacuity is evidenced by the positive-control assertion passing in the same run
- Sanity check the guard's teeth: temporarily point the case at a plan file whose phase 1 heading
  is pre-set to `[IN PROGRESS]` and confirm the byte-identity assertion still behaves as designed,
  then revert the temporary change

---

### Phase 4: Close the named coverage gap in test-skill-base-lifecycle.sh Group 4 [NOT STARTED]

**Goal**: Group 4 exercises `skill_preflight_update` with `target_status="implement"` against a
fixture that actually contains a plan file — the gap the task description calls out by name.

**Tasks**:
- [ ] Extend that suite's `build_fixture_repo` copy loop to also copy `update-plan-status.sh` and
      `update-phase-status.sh` from the deployed scripts source. **Without this, the new case
      cannot fail even with the defect present**: `update_plan_file()` returns early with
      "update-plan-status.sh not found or not executable".
- [ ] Add a plan file to the fixture (or create it inline in the new case), with a plan-level
      status line and at least two conforming `[NOT STARTED]` phase headings.
- [ ] Add a Group 4 case that calls `skill_preflight_update 1 "implement" "sess_test_<n>"` against
      that fixture, capturing stderr to a log file per the group's existing convention.
- [ ] Assert the phase headings are unchanged and contain no `[IN PROGRESS]`.
- [ ] **Positive control (required)**: assert the state.json status moved to `implementing` **and**
      the plan-level status line became `[IMPLEMENTING]`, proving the wrapper reached
      `update_plan_file()`'s plan-file logic.
- [ ] Leave the existing `"plan"`-target cases untouched — they cover a different transition and
      remain valid.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: `build_fixture_repo` in this suite is hypothesized to copy exactly five
scripts and no plan file. Confirm by reading the function before editing; the count matters only
insofar as the two plan/phase scripts must end up present, so verify by asserting the positive
control passes rather than by trusting the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - extend
  `build_fixture_repo`'s copy loop; add the implement-target case to Group 4

**Verification**:
- Suite exits 0, all pre-existing groups still pass, new case reported PASS
- Positive-control assertions pass in the same run

---

### Phase 5: Retire the stale auto-advance comment and re-verify co-maintenance [NOT STARTED]

**Goal**: no prose in either orchestrate engine describes or relies on the deleted behavior, and
the two SKILL.md copies remain in agreement.

**Tasks**:
- [ ] Run `grep -n "auto-advance\|first-phase\|first phase\|NOT STARTED\]->\[IN PROGRESS"` across
      **both** `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` and
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` at implementation time,
      before editing. Record the result for the summary.
- [ ] In the hard-mode file, rewrite the comment block preceding the implement-dispatch
      `skill_preflight_update "$task_number" "implement" "$session_id"` call. Keep the still-true
      first sentence (this preflight sits inside the `if [ -n "$next_phase" ]` branch only, never
      the skeleton-exhaustion or all-complete branches). Replace the auto-advance reasoning with
      an accurate statement: the call's remaining side effects are the workflow-active marker
      write and the plan-level `[STATUS]` stamp; it writes no per-phase marker, because the
      dispatched agent owns every per-phase transition.
- [ ] Do not weaken or delete the surrounding territory/concurrency prose.
- [ ] If — and only if — the fresh grep finds prose in `skill-orchestrate/SKILL.md` describing the
      deleted behavior, apply the equivalent edit there per the co-maintenance contract. If it
      finds none (the expected outcome, re-confirmed at planning time), record the verification
      result explicitly in the summary and make no edit to that file.
- [ ] Confirm no task-number reference is introduced (both files are outside `specs/**`).

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: Exactly one comment block (research: `skill-orchestrate-hard/SKILL.md` lines
822-827; two of the grep's hits) is hypothesized to describe the deleted behavior, with zero
matching prose in `skill-orchestrate/SKILL.md`. Confirm by the fresh two-file grep above before
editing; a hit in the base-mode file converts this into a two-file edit.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - replace the stale
  auto-advance comment block
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - conditional; edit only if the
  fresh grep finds matching prose

**Verification**:
- Post-edit grep across both files returns no prose asserting a preflight phase auto-advance
- Diff read-through confirms every changed hunk lies inside a comment region
- The `skill_preflight_update` call line itself is unchanged

---

### Phase 6: Final redeploy and full gate [NOT STARTED]

**Goal**: the deployed tree matches the source store across all four edited files, and the full
gate set passes.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to redeploy the edited scripts, tests, and
      SKILL.md files.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and resolve any drift (including
      `index-entries.json` line counts via `generate-context-line-counts.sh --write` if flagged),
      re-running until it passes.
- [ ] Re-run both suites from the source-store path:
      `test-update-task-status.sh` and `test-skill-base-lifecycle.sh`.
- [ ] Re-run any orchestration-adjacent suites that exercise `update-task-status.sh` (discover via
      `grep -rln 'update-task-status' agent-system/extensions/core/scripts/tests/`), so the
      deletion's blast radius is checked, not assumed.
- [ ] Confirm every acceptance criterion is discharged and cite the evidence for each in the
      summary, including the AC 3 record (research/plan slots unreachable; premise refuted, no work
      owed).

**Timing**: 0.5 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None beyond drift fixes surfaced by `verify-deploy.sh`, which are applied in the source store

**Verification**:
- `verify-deploy.sh` exits 0
- Every discovered `update-task-status`-touching suite exits 0
- Deployed `update-task-status.sh` and `skill-orchestrate-hard/SKILL.md` match their source-store
  counterparts

---

## Testing & Validation

- [ ] `bash -n` clean on the edited shell scripts
- [ ] `test-update-task-status.sh` passes, including the new byte-identity case with its positive
      control
- [ ] `test-skill-base-lifecycle.sh` passes, including the new implement-target Group 4 case with
      its positive control
- [ ] Every other test suite referencing `update-task-status` passes
- [ ] `verify-deploy.sh` passes after the final redeploy
- [ ] `grep` across `agent-system/extensions/core/` finds no remaining code or prose that advances
      a phase marker from a preflight

## Artifacts & Outputs

- `specs/035_stop_preflight_spurious_phase_advance/plans/01_delete-preflight-phase-autoadvance.md`
  (this file)
- Modified: `agent-system/extensions/core/scripts/update-task-status.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Conditionally modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `specs/035_stop_preflight_spurious_phase_advance/summaries/01_*-summary.md`

## Rollback/Contingency

All edits are confined to five source-store files and are individually revertible with
`git revert` or a targeted `git checkout <ref> -- <path>` per file, followed by
`bash .claude/scripts/deploy-headless.sh` to restore the deployed tree.

If Phase 2's baseline run reveals that an existing suite depended on the auto-advance, do **not**
reinstate the block as-is: that would restore the divergent-rescan defect. Instead, treat it as
evidence for Acceptance Criterion 2(b), revert Phase 1 only, and re-plan the fix as a
dispatch-awareness gate in which the caller passes the target phase number explicitly rather than
letting the script re-derive it. The plan-level `[STATUS]` stamp and the `--phase-check` backstop
are untouched by every phase here, so no rollback path can disturb them.
