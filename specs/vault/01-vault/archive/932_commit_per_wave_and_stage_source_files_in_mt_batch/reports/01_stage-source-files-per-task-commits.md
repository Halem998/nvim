# Research Report: Task #932

**Task**: 932 - Commit per wave and stage source files in the multi-task /orchestrate batch commit
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Medium (2 files change behaviorally, 2 files change documentation-only)
**Dependencies**: None (foundational task in the 932-935 chain; must land before 933-935 per the meta-builder's `next_steps` note)
**Sources/Inputs**: Live source-store reads under `agent-system/extensions/core/` (never the deployed `.claude/` copies)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, git-staging-scope.md

## Executive Summary

- The defect is confirmed exactly as described: `commands/orchestrate.md`'s Step 5 ("Batch Git
  Commit and Consolidated Output") builds `stage_paths` from only `specs/TODO.md`,
  `specs/state.json`, and each validated task's bare `specs/{NNN}_{name}/` directory — it never
  reads any task's `.return-meta.json` and never touches `modified_files`, and it omits
  `--honest-index-rows`. Every source-store file (or any file outside `specs/`) an implementation
  agent writes during a multi-task `/orchestrate` run is left uncommitted.
- The single-task path's `CHECKPOINT 3` in the same file is the exact template to mirror: it reads
  `modified_files` from `${task_dir}/.return-meta.json`, appends each entry to `stage_paths`, and
  passes `--honest-index-rows "{N}"` to `git-commit-scoped.sh`.
- **Key architectural finding for Component B**: the `waves` array computed by `commands/orchestrate.md` Step 3
  (Kahn's algorithm) is passed into the skill and stored verbatim in
  `mt_state_file.waves`, but it is **never read again** anywhere in
  `skills/skill-orchestrate/SKILL.md`'s Stage MT-3/MT-4 dispatch loop. Runtime eligibility is
  driven entirely by `dependency_graph` (a task is eligible the instant all its predecessors are
  terminal), which is a strictly finer-grained, continuously-cycling scheduler than the
  precomputed wave list — a task can become eligible mid-cycle without waiting for the rest of
  its nominal "wave" to finish. This means **there is no existing runtime "wave completed" event
  to hook a commit onto** — implementing genuine per-wave commits requires *adding* wave-membership
  tracking and a "is this wave now fully terminal" check that does not exist today. By contrast, a
  **per-task** commit hooks directly onto an event that already exists and already fires exactly
  once per task per phase transition: Stage MT-4 step 3 (`skill_postflight_update`)/step 5 (fresh
  status re-read, `completed_tasks`/`failed_tasks` bookkeeping).
- **Recommendation: per-task commit granularity**, not per-wave, for three reasons: (1) it directly
  and fully retires hazard 2 (a reverted task's commit contains only that task's own diff and
  index rows — never a sibling's, regardless of which wave either was in); (2) it requires zero
  new tracking state (no wave-membership map, no "wave complete" detection) — it reuses the
  per-task loop and per-task `.return-meta.json` that Stage MT-4 already iterates; (3) it is
  independently required by the **existing** "Commit-Per-Green-Substep Mandate" in
  `.claude/rules/git-workflow.md`, which already states that a verified-green sub-step "MUST be
  committed as it happens" and explicitly forbids holding commits back until a whole phase or task
  finishes — MT mode's current single end-of-batch commit already violates this mandate
  independent of the staging defect, so fixing granularity is not an optional nicety layered on
  top of the staging fix, it is closing a second, independent violation of an existing rule.
- Per the task's own framing, this substantive relocation means: the commit call moves OUT of
  `commands/orchestrate.md` Step 5 (which runs once, after the single `skill-orchestrate`
  invocation returns) and INTO `skills/skill-orchestrate/SKILL.md` Stage MT-4's existing per-task
  postflight loop (after step 3's `skill_postflight_update`/step 4's artifact linking, before step
  6's per-task lock release) — the only place inside the skill where per-task `dispatch_status`,
  `task_dir`, and that task's own `.return-meta.json` are all in scope simultaneously.
- Every existing safety property is preserved by construction if the relocated commit reuses
  `git-commit-scoped.sh` exactly as the single-task `CHECKPOINT 3` does: the commit mutex
  (`specs/.commit-lock/`), the automatic ephemeral-runtime-file exclusion injected for any
  `specs/{NNN}_{slug}/` pathspec, and named (never bare) pathspec commits.

## Context & Scope

Researched the exact staging/commit code at the two named sites in `commands/orchestrate.md`
(single-task `CHECKPOINT 3` vs. multi-task Step 5), the multi-task dispatch/postflight loop in
`skills/skill-orchestrate/SKILL.md` (Stages MT-1 through MT-5), the authoritative staging contract
in `context/standards/git-staging-scope.md`, the `--honest-index-rows` / mutex / exclusion-set
contract implemented in `scripts/git-commit-scoped.sh`, the existing MT-mode narrative in
`docs/architecture/orchestrate-state-machine.md`, and the hazard-2 paragraph plus its adjoining
"Separately, and out of scope for this gate" note in
`context/patterns/batch-orchestration-guardrails.md`. All reads were against the live source store
at `/home/benjamin/.config/nvim/agent-system/extensions/core/` (confirmed present as a sibling
directory inside this same repo, NOT `.claude/`), anchored on symbol names and quoted strings per
the task's line-number caveat.

## Findings

### Codebase Patterns

**Defect A confirmed — `commands/orchestrate.md` Step 5, quoted verbatim**:

```bash
stage_paths=("specs/TODO.md" "specs/state.json")
for tnum in "${validated_tasks[@]}"; do
  tpadded=$(printf "%03d" "$tnum")
  tname=$(jq -r --argjson num "$tnum" \
    '.active_projects[] | select(.project_number == $num) | .project_name' \
    specs/state.json)
  [ -n "$tname" ] && stage_paths+=("specs/${tpadded}_${tname}/")
done
```
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "$commit_message" \
  --session "{batch_session_id}" \
  -- "${stage_paths[@]}"
```

No `--honest-index-rows` flag, no `.return-meta.json` read, no `modified_files` loop. This is the
same defect flagged (but explicitly left unfixed) by
`context/patterns/batch-orchestration-guardrails.md`'s own note: "a multi-task `/orchestrate`
batch commit does not currently stage an implementation agent's self-reported `modified_files` per
task (the batch commit staging gap). This is a distinct defect flagged by the originating research
for a future task; this gate does not fix it." Task 932 is that future task.

**The single-task template to mirror — `CHECKPOINT 3`, quoted verbatim**:

```bash
task_dir="specs/${PADDED_NUM}_${PROJECT_NAME}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
```
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: complete orchestration" \
  --session "{SESSION_ID}" \
  --honest-index-rows "{N}" \
  -- "${stage_paths[@]}"
```

This is the exact per-task shape Component A asks to extend the batch loop with — one
`.return-meta.json` read per task, `modified_files` entries appended, `--honest-index-rows`
passed. `context/standards/git-staging-scope.md`'s "Fail-Safe Direction" section is the
already-specified absent/empty behavior Component A says to reuse rather than reinventing: if
`modified_files` is absent or empty, fall back to the task-directory-only paths and print the
existing loud warning (`[postflight] WARNING: no modified_files reported; source-file changes NOT
committed automatically. Review and commit manually.`) — this applies per-task, not once for the
whole batch.

**Why "waves" cannot be the per-wave commit trigger without new tracking (Component B)**:

`skills/skill-orchestrate/SKILL.md` Stage MT-1 reads `waves` from the delegation context and
stores it in `mt_state_file` ("`task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, ..."), but
a full-file grep of every "wave"-adjacent identifier in that file turns up exactly three hits:
the Stage MT-1 field list above, the field's one-line description ("`waves` — pre-computed
topological wave schedule"), and Stage MT-3 step 6's comment ("`MAX_CYCLES_MT` still increments
once per **wave cycle**" — a naming holdover, not an actual per-wave gate). Stage MT-3's own
eligibility computation (step 3) and the 4.5 admission re-check both key exclusively off
`dependency_graph[task_num]` predecessor-terminal-state — never off `waves`. The docs file
`docs/architecture/orchestrate-state-machine.md`'s "MT Example Flow: 2 Independent Tasks" spells
out the consequence directly: eligibility is recomputed every cycle, and a task's dependents become
eligible "the next cycle when the predecessor reaches terminal state" — this is inherently finer
than wave-synchronous barriers, since two tasks in the same nominal Kahn's-algorithm wave can
finish their research/plan/implement phases in a different number of cycles (a lean4 task's
implement phase might take 3 cycles while a markdown task's takes 1), so "wave 0 is now fully
done" is not a fact the current loop tracks or can cheaply derive without adding a
task-number-to-wave-index map plus a per-wave "all members terminal" check on every cycle.

**Why per-task is the event that already exists**: Stage MT-4's per-task postflight loop ("For
each task in `research_tasks + plan_tasks + implement_tasks`") already, for every single task on
every single cycle, resolves `task_dir`, reads that task's own `.return-meta.json` (via the
return-meta recovery path, step 1), extracts `dispatch_status` (step 2), calls
`skill_postflight_update` (step 3), links artifacts (step 4), and re-reads `fresh_status` to decide
`completed_tasks` vs. `failed_tasks` membership (step 5) — before releasing that task's lock (step
6). Every fact a per-task commit needs (`task_dir`, this task's `modified_files`, this task's
`dispatch_status`/`fresh_status` to pick the commit message) is already resolved in-scope at this
exact point, once per task, per cycle. No new state is required; the commit is simply one more
step inserted into an already-existing per-task iteration.

**Existing rule that independently requires this, not just this task's ask** — `.claude/rules/git-workflow.md`'s "Commit-Per-Green-Substep Mandate":
> "Every verified-green sub-step is committed as it happens — this is a mandate, not an
> optional-when-convenient practice... an intermediate state that is *green*... MUST be committed,
> not held back until the whole phase or task finishes."

MT mode's current single end-of-batch commit (firing only after the WHOLE skill invocation
returns, covering however many internal cycles and phase transitions happened across ALL tasks)
is a standing violation of this mandate independent of the staging gap — every completed research
phase, completed plan phase, etc. for every task in the batch is held uncommitted until the very
end. This reinforces per-task (in fact per-task-per-phase-transition) granularity as the correct
target, not merely "closer to existing structure" per-wave.

### External Resources

Not applicable — this is a closed, self-contained agent-system architecture question; no external
library or API research was relevant. All research was source-store code reading.

### Recommendations

**A. Staging fix** — extend the batch loop (relocated per B below) to, per task, read
`${task_dir}/.return-meta.json`, append `modified_files[]` entries to that task's own
`stage_paths`, and pass `--honest-index-rows "$tnum"`. Reuse the absent/empty warning from
`git-staging-scope.md` verbatim (scoped per-task: "no modified_files reported for task {N};
source-file changes NOT committed automatically"), not a new invented message.

**B. Granularity — per-task, not per-wave.** Relocate the commit call out of
`commands/orchestrate.md` Step 5 into `skills/skill-orchestrate/SKILL.md` Stage MT-4's per-task
postflight loop, one commit per task per phase transition (research complete / plan complete /
implement complete / blocked / failed), reusing `git-commit-scoped.sh` with:
- `stage_paths`: `"${task_dir}/"` + the four ephemeral excludes (or let `git-commit-scoped.sh`
  auto-inject them, since it already detects `specs/{NNN}_{slug}/`-shaped positive pathspecs and
  injects the canonical exclusion set itself) + `specs/TODO.md` + `specs/state.json` + (implement
  only) `plan_path` + that task's own `modified_files[]`.
- `--session "${session_id}_${tnum}"` (the per-task session suffix Stage MT-4 already mints for
  task-lock acquisition).
- `--honest-index-rows "$tnum"` (since `state.json`/`TODO.md` legitimately carry other tasks'
  current rows too, same rationale as the single-task checkpoint).
- Commit message per the existing `git-workflow.md` Standard Actions table, chosen by
  `dispatch_status`: `task {N}: complete research` / `task {N}: create implementation plan` /
  `task {N}: complete implementation` / a blocked/failed-appropriate message mirroring
  `CHECKPOINT 3`'s "on partial" form.

  This directly retires hazard 2: any single task's revert is isolated to its own commit(s),
  never entangled with a sibling's diff or index rows, at the SAME granularity a solo `/research`
  + `/plan` + `/implement` (or solo `/orchestrate`) run would have produced.

  Following this, `commands/orchestrate.md` Step 5's "Batch Git Commit" section either shrinks to
  a defensive `git status --porcelain` check (warn if anything is unexpectedly still
  uncommitted — nothing left to commit at the batch level, since Stage MT-4 already committed
  everything incrementally) or is removed outright in favor of the Consolidated Output section
  alone. Do NOT keep a second combined-batch commit alongside the new per-task commits — that
  would reintroduce exactly the cross-task entanglement hazard 2 describes, just redundantly.

**C. Safety-property preservation** — since the relocated commit reuses `git-commit-scoped.sh`
unchanged (same script, same flags, just called once per task instead of once per invocation),
path-scoped staging, the commit mutex, and the automatic ephemeral exclusion set are preserved by
construction; no second staging implementation is introduced. The one new consideration: Stage
MT-4's per-task postflight loop is a sequential bash `for` loop within the orchestrator's own
turn (only the Agent-tool DISPATCH calls are issued concurrently in one message; postflight
processing, including commits, happens sequentially afterward) — so per-task commits within one
cycle already serialize naturally in program order, and the `specs/.commit-lock/` mutex remains
necessary only for cross-process safety (a concurrently running, separate `/implement` or
`/orchestrate` dispatch touching the same index), exactly as documented.

**D. Documentation updates**:
- `docs/architecture/orchestrate-state-machine.md`'s "MT Mode: Multi-Task Orchestration" section
  (and its "Lifecycle-Cycling Loop (Stage MT-3)" ASCII diagram / "MT Example Flow" narrative)
  should gain a description of the new per-task commit step inside the per-task postflight
  block (step 7 in the diagram), and should note explicitly that MT mode no longer produces one
  combined end-of-batch commit.
- `context/patterns/batch-orchestration-guardrails.md`'s hazard-2 paragraph ("Rollback/
  commit-granularity risk") should be updated to state the hazard is retired — a per-task commit
  means a self-modifying task's change (if it needs reverting) is now isolated in its own
  commit, never mixed with sibling tasks' diffs. The adjoining "Separately, and out of scope for
  this gate" note about the staging gap should also be updated or removed, since this task closes
  that exact gap. If any residual risk remains (e.g., `specs/state.json`/`specs/TODO.md` still
  legitimately carry other tasks' current index rows in each per-task commit, per the
  `--honest-index-rows` addendum mechanism — this is a labeled, honest residual, not a defect),
  state it precisely rather than claiming total elimination.

## Decisions

- **Per-task commit granularity is recommended over per-wave**, based on the finding that `waves`
  is inert at runtime (stored, never consulted for dispatch or completion decisions) while
  per-task completion is already a first-class, already-iterated event in Stage MT-4. This
  decision should be treated as a strong recommendation for the planning stage, not a foreclosed
  final answer — record the reasoning above in the plan file per the task's own instruction.
- The relocated commit should reuse `git-commit-scoped.sh` verbatim (no new script, no new
  staging logic) per Component C's explicit instruction not to hand-roll a second staging
  implementation.

## Risks & Mitigations

- **Risk**: N small commits instead of 1 combined commit is noisier git history for a batch run.
  **Mitigation**: this is the intended, accepted trade — hazard 2 exists precisely because a
  combined commit is NOT reviewable/revertable per-task; the noise is the isolation being bought.
- **Risk**: Removing the batch-level commit from `commands/orchestrate.md` Step 5 without
  verifying Stage MT-4's relocated commit actually covers every exit path (completed, failed,
  blocked, deferred-self-modifying, MAX_CYCLES_MT partial exit) could leave some end states
  uncommitted. **Mitigation**: the verification bar in the task description already requires
  proving actual committed source files for a live two-task run — the plan should include a
  concrete two-task fixture exercising at least one full completion and confirm each task's own
  commit contains that task's own source-store files, not the sibling's.
- **Risk**: `--honest-index-rows` per-task, fired many times per cycle, adds one extra
  staged-vs-HEAD `state.json` diff scan per task per phase transition instead of once per batch.
  **Mitigation**: the flag's own implementation is already documented as "entirely
  failure-tolerant" and cheap (one comparison), so this is a bounded, accepted cost, not a new
  risk class.

## Context Extension Recommendations

- **Topic**: MT-mode commit lifecycle.
- **Gap**: `docs/architecture/orchestrate-state-machine.md`'s MT Mode section currently describes
  Stage MT-4's per-task postflight as "skill_postflight_update + artifact linking + multi-state
  update" only — no commit step is documented there today (the reader has to know to look at
  `commands/orchestrate.md` Step 5 instead, which after this task no longer holds the real
  commit logic).
- **Recommendation**: this task's own Component D scope item already covers this gap; no separate
  follow-up task is needed.

## Appendix

Files read (source store, `agent-system/extensions/core/` root):
- `commands/orchestrate.md` (Step 5 batch commit, CHECKPOINT 3 single-task commit, full
  MULTI-TASK DISPATCH section Steps 1-5)
- `skills/skill-orchestrate/SKILL.md` (Stage MT-1 through MT-5, single-task Stage 0/2/3/8 for
  comparison, full-file grep for "wave"/"MAX_CYCLES" identifiers)
- `context/standards/git-staging-scope.md` (full file — per-operation scope, fail-safe direction,
  exclusion set, `git-commit-scoped.sh` safety gates)
- `scripts/git-commit-scoped.sh` (header comment: usage, `--honest-index-rows` contract, exit
  codes, V2/V3/V4 safety gates)
- `docs/architecture/orchestrate-state-machine.md` (MT Mode section, Lifecycle-Cycling Loop
  diagram, Dependency Gating Model, MT Example Flow)
- `context/patterns/batch-orchestration-guardrails.md` (Inclusion/Exclusion tables, "Deploy-Manual
  Analysis and the Three Surviving Hazards", hazard-2 paragraph, Scope Limitation note)
- `context/formats/return-metadata-file.md` (`modified_files` field schema, confirmed via grep)
- `context/standards/orchestrator-runtime-files.md` (ephemeral/durable class table, confirmed
  `.return-meta.json`/`.orchestrator-handoff.json` are durable-provenance, never in the ephemeral
  exclusion set)

Search commands used: `grep -n` for the exact quoted symbols/strings above (`stage_paths`,
`modified_files`, `honest-index-rows`, `Stage MT-`, `waves\b`), `find` to locate the source-store
root (`agent-system/extensions/core` under this repo, sibling to `.claude/`).
