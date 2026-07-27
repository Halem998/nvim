# Implementation Plan: Task #932

- **Task**: 932 - Commit per wave and stage source files in the multi-task /orchestrate batch commit
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None (foundational in the 932-935 chain; lands before 933-935)
- **Research Inputs**: `specs/932_commit_per_wave_and_stage_source_files_in_mt_batch/reports/01_stage-source-files-per-task-commits.md`
- **Artifacts**: plans/01_per-task-commit-stage-source-files.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, git-staging-scope.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The multi-task `/orchestrate` batch commit has two independent defects at one site: it stages
nothing outside `specs/` (never reading any task's `modified_files`, never passing
`--honest-index-rows`), and it fires exactly once at end-of-batch, folding every task's diff and
index rows into a single unrevertable commit. This plan fixes both by **relocating** the commit —
not duplicating it — out of `commands/orchestrate.md` Step 5 and into
`skills/skill-orchestrate/SKILL.md` Stage MT-4's already-existing per-task postflight loop, where
`task_dir`, that task's own `.return-meta.json`, and its `dispatch_status` are all simultaneously
in scope. Every commit continues to go through `scripts/git-commit-scoped.sh` unchanged, so
path-scoped staging, the `specs/.commit-lock/` mutex, and the automatic ephemeral-exclusion
injection are preserved by construction. The final phase proves the fix against the stated
verification bar with an executable two-task git harness that inspects actual commit contents.

### Research Integration

The research report's decisive architectural finding drives Component B's design decision (see
Decision Record below): the `waves` array is **inert at runtime**. It is written into
`mt_state_file` by Stage MT-1 and never read again — Stage MT-3's eligibility computation and its
step 4.5 admission re-check both key exclusively off `dependency_graph` predecessor-terminal
state. There is therefore **no existing "wave completed" runtime event** to hook a commit onto;
genuine per-wave commits would require adding a task-to-wave-index map plus a per-cycle
"all members of this wave terminal" check that does not exist today. Per-task completion, by
contrast, is already a first-class event iterated once per task per cycle in Stage MT-4 steps 1-6.

The report also supplies the exact single-task template to mirror (`CHECKPOINT 3`), the already-
specified absent/empty `modified_files` fail-safe in `context/standards/git-staging-scope.md`
(reused verbatim rather than reinvented, per Component A), and confirmation that the existing
Commit-Per-Green-Substep Mandate in `rules/git-workflow.md` independently requires finer
granularity than one end-of-batch commit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consultation performed.

## Decision Record: Per-Task, Not Per-Wave (Component B)

**Decision: per-task-per-phase-transition commit granularity.** The task instruction requires the
choice and its reasoning be recorded here. The research recommendation is evaluated and **adopted**,
on four grounds:

1. **It fully retires hazard 2, which per-wave does not.** Hazard 2 is that a self-modifying task's
   diff cannot be isolated from siblings'. A per-wave commit still mixes every task in that wave.
   Only per-task achieves the actual property being sought: any one task's change is revertable
   without touching a sibling's.
2. **It requires zero new runtime state.** Per-wave requires inventing a wave-membership map and a
   per-cycle wave-completion predicate on a scheduler that deliberately does not work in wave
   barriers. Per-task reuses the loop that already exists.
3. **Per-wave is not even well-defined under the current scheduler.** Because eligibility is
   recomputed continuously off `dependency_graph`, two tasks in the same nominal Kahn's-algorithm
   wave routinely finish different phases on different cycles (see the "MT Example Flow" narrative
   in `docs/architecture/orchestrate-state-machine.md`). "Wave 0 is now done" is not a fact the
   loop tracks or can cheaply derive.
4. **An existing rule already mandates it.** `rules/git-workflow.md`'s Commit-Per-Green-Substep
   Mandate states a verified-green sub-step MUST be committed as it happens and explicitly forbids
   holding commits back until a whole phase or task finishes. The current single end-of-batch
   commit violates this independently of the staging defect.

**Rejected alternative — keep the batch commit alongside new per-task commits.** This would
reintroduce exactly the cross-task entanglement hazard 2 describes, redundantly. The batch commit
is retired, not supplemented.

## Goals & Non-Goals

**Goals**:
- Every source-store file an implementation agent writes during a multi-task `/orchestrate` run is
  staged and committed, via that task's own self-reported `modified_files`.
- Commit granularity becomes one commit per task per phase transition, replacing one commit per
  invocation.
- `--honest-index-rows` is passed at the relocated site, matching the single-task path.
- Hazard 2 in `context/patterns/batch-orchestration-guardrails.md` is retired, with any residue
  stated precisely rather than papered over.
- Verification demonstrates *committed content*, not merely that code reads `modified_files`.

**Non-Goals**:
- No change to `scripts/git-commit-scoped.sh` itself. No second staging implementation anywhere.
- No change to the eligibility/dependency scheduler, `MAX_CYCLES_MT`, or the wave computation in
  Step 3 of `commands/orchestrate.md` (the `waves` array stays where it is; this plan does not
  remove it, only records that it is inert for commit purposes).
- No change to single-task `CHECKPOINT 3` behavior.
- No extension of the admission gate to plain `/implement N,M` (the documented, accepted scope
  limitation in the guardrails file stays as-is).
- No edits under `.claude/**` — that tree is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing the batch commit leaves some MT exit path uncommitted (blocked, infra-deferred, gate-refused, MAX_CYCLES partial, deferred-self-modifying) | H | M | Phase 2 adds an explicit exit-path coverage table and a defensive residue check; Phase 1 states per-path commit behavior for every branch including the skip-steps-2-5 branches |
| Verification stops at "the code reads modified_files" and never proves committed content | H | M | Phase 5's harness asserts on `git show --name-only` output of real commits; the phase is not green until both isolation assertions pass |
| Harness cannot run `git-commit-scoped.sh` because `deploy-root-guard.sh` refuses any path whose grandparent is not `*/.claude` or `*/.opencode` | M | H | Phase 5 mirrors the deployed layout: harness scripts live at `<scratch>/.claude/scripts/`; this is a known structural requirement, verified from the guard's own `case` statement |
| Edits land in `.claude/**` instead of the source store | H | L | Every phase's file list names only `agent-system/extensions/core/**` paths; Phase 5 verifies `git status` shows no `.claude/` modifications |
| Task-number citations leak into deliverable files outside `specs/**` | M | M | All five target files are outside `specs/**`; each phase's verification includes a task-number-citation grep |
| Per-task `--honest-index-rows` runs N times per cycle instead of once | L | H | Accepted, bounded cost; the flag's implementation is documented as entirely failure-tolerant and cheap |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 1, 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add the per-task commit step to Stage MT-4 [COMPLETED]

**Goal**: `skills/skill-orchestrate/SKILL.md` Stage MT-4's per-task postflight loop gains a commit
step that stages that task's directory, index files, plan path (implement only), and its own
`modified_files`, then commits via `git-commit-scoped.sh` with `--honest-index-rows`.

**Tasks**:
- [x] Insert a new numbered step between the existing step 5 (fresh-status re-read /
      `completed_tasks`/`failed_tasks` bookkeeping) and step 6 (unconditional task-lock release).
      Number it so the existing steps 1-6 keep their identities — use **step 5.5**, matching the
      file's existing precedent of a fractional step (Stage MT-3 already uses "step 4.5").
- [x] Write the staging block, transcribed from `CHECKPOINT 3` in `commands/orchestrate.md` (do not
      invent a variant):
      ```bash
      stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
      [ -n "${plan_path:-}" ] && stage_paths+=("$plan_path")   # implement dispatches only
      metadata_file="${task_dir}/.return-meta.json"
      modified_count=0
      while IFS= read -r f; do
        [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
      done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
      ```
- [x] Add the fail-safe branch reusing the wording already specified in
      `context/standards/git-staging-scope.md`'s "Fail-Safe Direction", scoped per task by
      appending the task number — do NOT author a second, differently-worded convention:
      ```bash
      if [ "$modified_count" -eq 0 ]; then
        echo "[postflight] WARNING: no modified_files reported for task #${task_num}; source-file changes NOT committed automatically. Review and commit manually." >&2
      fi
      ```
- [x] Add the commit call, selecting the message from `dispatch_status` per the Standard Actions
      table in `rules/git-workflow.md`: `researched` -> `task {N}: complete research`; `planned` ->
      `task {N}: create implementation plan`; `implemented` (gate allowed) -> `task {N}: complete
      implementation`; gate-refused / `partial` -> the `CHECKPOINT 3` "on partial" form; `blocked`
      / `failed` -> a blocked/failed-appropriate message. Pass
      `--session "${session_id}_${task_num}"` (the per-task session suffix Stage MT-4 already mints
      for lock acquisition) and `--honest-index-rows "$task_num"`.
- [x] State that commit failure is **non-blocking** (log and continue to step 6) — a failed commit
      must never prevent the per-task lock release, which would strand the task.
- [x] Spell out branch coverage explicitly in the step's prose, so no exit path is ambiguous:
      - Steps 2-5 skipped (infra-deferral, MAX_INFRA_FAILURES, genuine-missing-handoff): step 5.5
        is also skipped. Nothing this dispatch produced is committable and `dispatch_status` is
        unresolved. Note this deliberately, so a later reader does not read it as an oversight.
      - Completion-claim gate refused: step 5.5 DOES run (steps 4-6 already run unchanged on a
        refuse) and commits at the partial-form message with the task still at `implementing`.
      - `dispatch_status` = `failed` or `blocked`: step 5.5 runs; artifacts and status changes
        produced by the dispatch are still real and belong in a commit.
- [x] Update Stage MT-4's opening COMPLETION SEQUENCING note (or add one sentence to it) recording
      that per-task postflight now includes a commit and that these commits serialize naturally in
      program order because postflight is a sequential loop within the orchestrator's own turn —
      the `specs/.commit-lock/` mutex remains required only for cross-process safety against a
      concurrently-running separate dispatch sharing the index.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly one file changes
(`skills/skill-orchestrate/SKILL.md`) and that one new step is inserted at one site inside Stage
MT-4's per-task loop. Confirm at implementation time by grepping for every occurrence of
`git-commit-scoped.sh` in that file after the edit — the expected count is exactly one; more than
one means a second commit site was introduced, which this plan forbids.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - insert step 5.5 in Stage MT-4's
  per-task postflight loop; amend the COMPLETION SEQUENCING note.

**Verification**:
- `grep -c "git-commit-scoped.sh" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns exactly `1`.
- The new block's staging list is byte-comparable to `CHECKPOINT 3`'s in
  `commands/orchestrate.md` apart from the per-task variable names and the `plan_path` addition
  (diff the two blocks by eye and record the intended differences).
- `grep -n "honest-index-rows" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  shows the flag present in the new call.
- The fail-safe warning string matches the wording in `context/standards/git-staging-scope.md`
  modulo the appended task number.
- Step numbering is still monotonic and the existing step 6 lock release remains last and
  unconditional.

---

### Phase 2: Retire the batch commit in commands/orchestrate.md Step 5 [COMPLETED]

**Goal**: Step 5 no longer performs a combined batch commit. Consolidated output is preserved; a
defensive residue check replaces the commit.

**Tasks**:
- [x] Delete the `stage_paths` construction loop and the `git-commit-scoped.sh` invocation from the
      "Batch Git Commit" sub-section, along with the `commit_message` branch that built the
      combined message.
- [x] Replace the sub-section with a "Commit Reconciliation (no batch commit)" sub-section that:
      (a) states plainly that MT mode no longer produces one combined end-of-batch commit and that
      per-task commits are issued inside the skill's per-task postflight loop; (b) explains WHY —
      the combined commit entangles N tasks' diffs and index rows, defeating per-task revert; and
      (c) runs a defensive, non-blocking residue check:
      ```bash
      residue=$(git status --porcelain -- specs/ 2>/dev/null)
      if [ -n "$residue" ]; then
        echo "[orchestrate] WARNING: uncommitted residue under specs/ after batch completion:" >&2
        echo "$residue" >&2
        echo "[orchestrate] Per-task commits are issued inside the skill's per-task postflight; review and commit manually." >&2
      fi
      ```
      The check WARNS ONLY — it must never commit, because a blanket commit here would recreate
      exactly the entanglement being removed.
- [x] Retitle the Step 5 heading from "Batch Git Commit and Consolidated Output" to reflect the new
      content (e.g. "Commit Reconciliation and Consolidated Output"). Update any in-file
      cross-reference to the old heading text.
- [x] Preserve verbatim: the `mt_state_file` result-reading block that precedes it, the entire
      **Consolidated Output** block, and the closing "After consolidated output, STOP" instruction.
- [x] Add a short exit-path coverage note listing every MT terminal outcome and where its commit is
      issued (completed / failed / blocked / partial-from-MAX_CYCLES / deferred-self-modifying).
      Deferred-self-modifying tasks are never dispatched and never status-mutated, so they
      correctly produce no commit — say so, rather than leaving it inferred.
- [x] Confirm `CHECKPOINT 3` (the single-task commit) is untouched.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that after the edit, `commands/orchestrate.md` contains
exactly two `git-commit-scoped.sh` invocations, both inside `CHECKPOINT 3` (the completion form
and the partial form), and zero in the MULTI-TASK DISPATCH section. Confirm by
`grep -n "git-commit-scoped.sh"` and checking every hit's line falls after the `### CHECKPOINT 3`
heading.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - Step 5: remove batch commit, add
  reconciliation/residue check, retitle heading, add exit-path coverage note.

**Verification**:
- `grep -n "git-commit-scoped.sh" agent-system/extensions/core/commands/orchestrate.md` returns
  exactly two hits, both below the `### CHECKPOINT 3` heading line. *(deviation: altered — the file has a pre-existing THIRD hit, a prose mention inside CHECKPOINT 3's own explanatory paragraph (unrelated to this phase's edit, not a second commit call site). All three hits fall below the `### CHECKPOINT 3` heading and zero fall in the MULTI-TASK DISPATCH section, satisfying the substantive intent — no MT batch commit, single-task CHECKPOINT 3 untouched — of this bullet.)*
- No `stage_paths` array remains in the MULTI-TASK DISPATCH section:
  `awk '/MULTI-TASK/,/### CHECKPOINT 1/' commands/orchestrate.md | grep -c stage_paths` is `0`.
- The Consolidated Output markdown block and the "After consolidated output, STOP" line are
  unchanged (diff against the pre-edit copy).
- No task-number citations introduced: `grep -nE 'task[s]? [0-9]{2,}' ` over the changed region
  shows only format placeholders (`{N}`, `{range_summary}`), never a literal task number.

---

### Phase 3: Document the MT per-task commit scope in git-staging-scope.md [NOT STARTED]

**Goal**: The authoritative staging-scope contract records that MT mode applies the per-operation
scopes **per task**, and that the existing Fail-Safe Direction warning is the single convention for
absent/empty `modified_files` in both modes.

**Tasks**:
- [ ] Add a subsection (e.g. "Multi-Task Application") after the `## Per-Operation Scope` block,
      stating that in multi-task `/orchestrate` the `research`/`plan`/`implement` scopes above apply
      once per task, keyed to that task's own directory and its own `.return-meta.json` — never
      unioned across tasks into a single commit.
- [ ] Record the reason in one sentence: a union commit cannot be reverted per task.
- [ ] Amend the `## Fail-Safe Direction` section with a single sentence stating that in multi-task
      application the same warning is emitted per task with the task number appended, and that this
      is the only sanctioned wording — a second convention MUST NOT be introduced.
- [ ] Note that `--honest-index-rows` is required at every site staging `specs/state.json` or
      `specs/TODO.md`, because those files legitimately carry other tasks' current rows.
- [ ] Check the `## Related Documentation` section and add cross-references if the new subsection
      warrants them.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - add Multi-Task
  Application subsection; amend Fail-Safe Direction.

**Verification**:
- The warning string appears in the file exactly once as a canonical form; the new prose refers to
  it rather than restating a variant.
- The new subsection names no task numbers (no-task-references rule).
- The file's existing "Forbidden Operations" and "Reference Template" sections are unchanged.

---

### Phase 4: Update the architecture doc and retire hazard 2 [NOT STARTED]

**Goal**: `docs/architecture/orchestrate-state-machine.md`'s MT Mode section describes the new
commit granularity, and `context/patterns/batch-orchestration-guardrails.md`'s hazard-2 paragraph
plus its adjoining staging-gap note reflect reality.

**Tasks**:
- [ ] In `orchestrate-state-machine.md`, extend the Lifecycle-Cycling Loop ASCII box 7 ("Per-task
      postflight") to name the commit — e.g. `skill_postflight_update + artifact linking +
      per-task scoped commit + multi-state update`. Keep the box borders aligned (this is a
      box-drawing diagram; column width must be preserved exactly).
- [ ] Add a short prose subsection under MT Mode ("Commit Granularity") stating: one commit per task
      per phase transition, issued inside Stage MT-4's per-task postflight; MT mode produces no
      combined end-of-batch commit; all commits route through the shared scoped-commit helper,
      preserving path-scoped staging, the commit mutex, and automatic ephemeral-file exclusion.
- [ ] Update the "MT Example Flow: 2 Independent Tasks" narrative so each cycle's `Postflight:` line
      shows the per-task commits (e.g. `Postflight: A -> researched (commit), B -> researched
      (commit)`), and adjust the EXIT line if it implies a trailing batch commit.
- [ ] In `batch-orchestration-guardrails.md`, rewrite hazard 2 ("Rollback/commit-granularity risk")
      to record that it is **retired**: a per-task commit means a self-modifying task's change is
      isolated in its own commit, never mixed with sibling tasks' diffs, at the same granularity a
      solo run produces. Do not silently delete the hazard — the section is explicitly framed as
      "the three surviving hazards" and a later maintainer must be able to see what changed and
      why. Adjust the section's framing sentence and any count language ("three hazards") so the
      prose stays internally consistent with a retired entry.
- [ ] State the residual precisely rather than claiming total elimination: each per-task commit
      still stages `specs/state.json` and `specs/TODO.md`, which legitimately carry other tasks'
      current index rows; `--honest-index-rows` labels this in the commit message. This is a
      labeled, honest residual, not a defect. Verification-gap risk (hazard 1) and bootstrapping
      risk (hazard 3) are untouched and remain live — say so explicitly so the gate's rationale is
      not read as weakened.
- [ ] Update or remove the "Separately, and out of scope for this gate" paragraph about the batch
      commit staging gap, since that gap is now closed.

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly two files change and that the guardrails file's
"three hazards" framing needs count/wording adjustment. Confirm at implementation time by grepping
that file for `three hazards` and for any other numeric reference to the hazard count before
editing — if additional occurrences exist beyond the two known sites (the framing sentence and the
closing "A later maintainer must not read..." sentence), all must be updated together.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - MT Mode diagram
  box 7, new Commit Granularity subsection, MT Example Flow.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - hazard 2
  retirement with stated residual; staging-gap note update/removal.

**Verification**:
- The ASCII diagram still renders with aligned borders (visual check plus a column-width check on
  the edited lines against their neighbors).
- `grep -n "batch commit" agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  shows no remaining claim that the staging gap is unfixed.
- The guardrails file's hazard enumeration is internally consistent: no sentence still asserts a
  count that contradicts the retired entry.
- Neither file contains a literal task-number citation.

---

### Phase 5: Executable two-task commit-content verification [NOT STARTED]

**Goal**: Prove, by inspecting real commit contents, that two tasks that both modify source-store
files produce commits that actually contain those files, and that neither commit contains the
other's. This is the task's stated verification bar; reading the code is explicitly insufficient.

**Tasks**:
- [ ] Create a scratch harness repo under the session scratchpad (never inside the user's repo):
      `git init`, an initial commit, and the **deployed layout** required by
      `scripts/deploy-root-guard.sh` — the guard's `case "${__guard_dir%/*}"` accepts only
      `*/.claude` or `*/.opencode`, so copy `git-commit-scoped.sh`, `deploy-root-guard.sh`, and
      `task-lock.sh` (plus any helper they source) to `<scratch>/.claude/scripts/`.
- [ ] Build the two-task fixture inside the harness repo:
      - `specs/state.json` and `specs/TODO.md` with rows for two tasks (use fixture numbers that
        do not collide with real tasks).
      - `specs/901_alpha/.return-meta.json` with
        `modified_files: ["agent-system/extensions/core/fixture_alpha.md"]`, plus a plan file and a
        summary file so the task directory is non-empty.
      - `specs/902_beta/.return-meta.json` with
        `modified_files: ["agent-system/extensions/core/fixture_beta.md"]`, likewise.
      - Both fixture source files created with distinct content under
        `agent-system/extensions/core/`, mirroring the real source-store path shape.
      - An ephemeral file in each task dir (`.orchestrator-loop-guard`) to confirm the automatic
        exclusion still fires.
- [ ] Transcribe the step 5.5 block authored in Phase 1 into a runnable harness script **verbatim**
      (substituting only the fixture task numbers/paths). If transcription requires changing the
      logic to make it run, that is a defect in Phase 1's block — fix Phase 1, not the harness.
- [ ] Run the harness: two sequential invocations, one per task, exactly as the sequential
      per-task postflight loop would.
- [ ] Assert on actual commit contents, not on script exit codes alone:
      - `git show --name-only --format= HEAD~1` contains `agent-system/extensions/core/fixture_alpha.md`
        and does NOT contain `fixture_beta.md`.
      - `git show --name-only --format= HEAD` contains `fixture_beta.md` and does NOT contain
        `fixture_alpha.md`.
      - Neither commit contains any `.orchestrator-loop-guard` path (exclusion set preserved).
      - Both commits contain `specs/state.json` and `specs/TODO.md`, and the second commit's
        message carries the `--honest-index-rows` addendum when the staged `state.json` legitimately
        carries the other task's row.
      - Exactly two commits were created beyond the initial commit (no combined third commit).
- [ ] Run the fail-safe path as a second harness case: a task whose `.return-meta.json` has an
      absent/empty `modified_files`. Assert the warning is emitted on stderr with the canonical
      wording and that the commit still succeeds containing only the task-directory paths.
- [ ] Record the harness script path and the assertion output in the phase completion notes so the
      run is reproducible. Do not leave harness artifacts inside the user's repository.
- [ ] Confirm no `.claude/**` file in the user's repo was modified by any phase of this task:
      `git status --porcelain -- .claude/` is empty (it is gitignored, but check the working tree
      too), and every changed file is under `agent-system/extensions/core/` or `specs/`.
- [ ] Record explicitly that a live end-to-end `/orchestrate N,M` run additionally requires a human
      redeploy (`<leader>al` / "Load Core"), which an agent must not perform. The harness is the
      executable bar this plan meets; the live run is a follow-up human confirmation, not a blocker
      on this task's completion.

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the harness needs exactly three copied scripts
(`git-commit-scoped.sh`, `deploy-root-guard.sh`, `task-lock.sh`). Confirm by grepping
`git-commit-scoped.sh` for every `. "${SCRIPT_DIR}/` and every `bash .../scripts/` reference before
building the harness, and copy whatever that grep actually reports rather than assuming three.

**Files to modify**:
- None in the repository. Harness files are created under the session scratchpad only.

**Verification**:
- All assertions above pass, with the actual `git show --name-only` output captured in the phase
  notes.
- The isolation assertions (alpha's commit excludes beta's file and vice versa) are the specific
  evidence that hazard 2 is retired; a phase where only the "contains its own file" half passes is
  NOT green.

---

## Testing & Validation

- [ ] `skills/skill-orchestrate/SKILL.md` contains exactly one `git-commit-scoped.sh` call site.
- [ ] `commands/orchestrate.md` contains exactly two, both inside `CHECKPOINT 3`.
- [ ] The relocated call passes `--honest-index-rows` and a per-task `--session`.
- [ ] The absent/empty `modified_files` warning uses the wording already in
      `context/standards/git-staging-scope.md`, task-scoped — no second convention.
- [ ] Harness run: two tasks, two commits, each containing its own source-store fixture file and
      not the sibling's.
- [ ] Harness run: ephemeral runtime files excluded from both commits.
- [ ] Harness run: fail-safe case warns loudly and still commits task-directory paths.
- [ ] No file under `.claude/**` modified; all edits under `agent-system/extensions/core/**`.
- [ ] No literal task-number citations in any of the five changed deliverable files.
- [ ] The guardrails file's hazard enumeration reads consistently after hazard 2's retirement, with
      hazards 1 and 3 explicitly still live.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- Modified: `agent-system/extensions/core/commands/orchestrate.md`
- Modified: `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Modified: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- Modified: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- Scratch (not committed): the two-task verification harness and its captured assertion output.

## Rollback/Contingency

Each phase is a single-file (Phase 4: two-file) prose edit committed separately, so any phase can
be reverted independently with `git revert` of its own commit.

**Ordering contingency**: Phase 2 removes the only existing MT commit. If Phase 1 lands and Phase 2
does not, MT mode temporarily produces both per-task commits and a redundant batch commit — noisy
but not lossy. If Phase 2 landed without Phase 1 the batch would commit nothing at all, which is why
the wave map forces 1 before 2; do not reorder them.

**Verification contingency**: if Phase 5's harness cannot execute `git-commit-scoped.sh` for a
structural reason beyond the known `deploy-root-guard.sh` layout requirement, do NOT downgrade the
bar to code inspection. Instead, build the harness against a full scratch deploy tree (copy the
whole `scripts/` directory to `<scratch>/.claude/scripts/`) and re-run. Only if that also fails
should the task be marked blocked with the specific structural obstacle recorded.
