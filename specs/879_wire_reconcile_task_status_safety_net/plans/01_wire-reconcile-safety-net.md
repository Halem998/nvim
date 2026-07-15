# Implementation Plan: Task #879

- **Task**: 879 - Wire reconcile-task-status.sh, which was built for this failure and never called
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours (4.5 hours excluding optional Phase 5)
- **Dependencies**: 876 (preflight wiring, complete), 878 (status-script hardening, complete)
- **Research Inputs**: specs/879_wire_reconcile_task_status_safety_net/reports/01_wire-reconcile-safety-net.md
- **Artifacts**: plans/01_wire-reconcile-safety-net.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`reconcile-task-status.sh` is a deployed, fully-functional self-healing script with zero callers.
This plan gives it three callers, each with a visibility contract calibrated to how much human
attention is present at that trigger point: `/task --sync` (live, user-invoked, primary),
`/orchestrate` entry (live, automatic, once per invocation — never per-cycle), and `skill-todo`
(dry-run-then-confirm only, never silent auto-repair). A preliminary phase closes a promotion
gap in the script itself so that automatic promotion at `/orchestrate` entry cannot mask a
`blocked` outcome as success. Definition of done: every one of the four reconcilable statuses can
be repaired from at least one trigger, and every reconcile pass — including a pass that does
nothing — produces visible output.

### Research Integration

The research report is authoritative on detail; the findings that shape this plan:

- **The script's real interface was verified against its body, not its header.** Signature is
  `<task_number> <session_id> [--dry-run]`; `--dry-run` already exists and is wired through every
  branch — no caller needs to add it. It dispatches purely on `state.json`'s current `status` for
  one task number and does not scan all tasks itself, so any system-wide sweep is the caller's
  loop. Exit 0 covers both success and no-op (including task-not-found, treated as
  possibly-already-archived).
- **A visibility gap in the script drives the caller design**: the `researching`/`planning`/
  `implementing`/`partial` branches print their `[reconcile] ... no-op` lines **only under
  `--dry-run`**. A live no-op is completely silent. Because visibility is this task's whole point,
  every live caller must bracket the call and emit its own notice when the script produced no
  output. This is specified per-phase below rather than left to the implementer.
- **Only the `partial` branch consults `.orchestrator-handoff.json`.** The other three promote on
  artifact existence alone, so a run that wrote a report and then reported `blocked` would be
  force-promoted to `researched`. Phase 1 closes this, using the `blocked` postflight terminus that
  predecessor hardening made available rather than inventing a new mechanism.
- **`/task --sync` Sync Mode already calls the sibling `reconcile-artifacts.sh` at step 2.5.** That
  script is complementary, not overlapping: it is inherently system-wide (no task-number argument),
  append-only, and never touches `status`. Status reconciliation is the natural continuation of
  that same step. Sync Mode has no `session_id` of its own (it deliberately does not source
  `command-gate-in.sh`), so one must be generated inline.
- **`/orchestrate` Stage 3 re-reads status at the top of every cycle**, and predecessor preflight
  wiring already keeps status current between dispatches within one run. The failure this script
  exists for — a *previous* invocation that crashed before postflight — is observable exactly once,
  at entry. Per-cycle reconciliation would be redundant cost on up to 5 (single-task) or 25
  (multi-task) iterations and would fight the orchestrator's own preflight writes.
- **`skill-todo` Stage 2 (`ScanTasks`) matches the literal strings `completed`/`abandoned`.** A task
  stranded in an in-flight status with its artifact already on disk is invisible to that scan and
  can never be archived. A dry-run reconcile pass surfaced through the skill's existing
  `AskUserQuestion` gate makes it visible without compounding a silent promotion with a silent
  directory move.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Give `reconcile-task-status.sh` live callers at `/task --sync` and `/orchestrate` entry, and a
  dry-run caller at `skill-todo`.
- Make `/orchestrate`'s automatic promotion safe by teaching the three artifact-existence branches
  to respect a non-success handoff, the way the `partial` branch already does.
- Guarantee that every reconcile pass is visible, including passes that find nothing to do.
- Land every edit in the canonical `agent-system/extensions/core/` tree and mirror it to the
  gitignored `.claude/` deploy tree.

**Non-Goals**:

- **No new scripts.** Every phase either edits `reconcile-task-status.sh` itself or adds inline
  caller logic to an existing command/skill document.
- **The archived-while-still-held-lock problem is explicitly deferred to a follow-up task.**
  Research corroborated it (a lock holder file was found git-tracked inside a task directory that
  the archive stage moves wholesale, with no lock check anywhere in that path), but
  `reconcile-task-status.sh` carries no lock awareness and cannot fix it under any wiring choice.
  The fix is a separate wiring of `task-lock.sh check`/`release` into `skill-todo`'s `ArchiveTasks`
  stage immediately before the directory move. Do not implement it here.
- **No auto-repair of plan-vs-state divergence.** If Phase 5 is executed at all, it is report-only:
  there is no unambiguous correct side to a plan-vs-state mismatch, unlike "artifact exists,
  therefore promote."
- **No per-cycle reconciliation** on any `/orchestrate` path.
- **No update to the lock pattern document's Consumers section** — that belongs with the deferred
  lock fix, not here.
- No change to `reconcile-artifacts.sh`, `generate-todo.sh`, or `update-task-status.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Automatic promotion at `/orchestrate` entry masks a genuine `blocked` outcome as success | H | M | Phase 1 gates all four branches on handoff status before promoting; Phase 3 depends on Phase 1 so the guard is in place before any automatic caller exists |
| A live reconcile pass that finds nothing is completely silent (script only prints no-op lines under `--dry-run`), so the user cannot distinguish "ran, found nothing" from "never ran" | M | H | Every live caller captures the script's output and emits an explicit no-op notice when it is empty — specified per-phase, not left to implementer discretion |
| Editing the orchestrator's own SKILL.md while an orchestrator is executing it | M | H | All verification uses direct script invocation against an isolated `mktemp -d` fixture and dry-run output inspection; no phase requires a live `/orchestrate` run to verify |
| An edit lands only in the gitignored `.claude/` deploy mirror and is lost | H | M | Every phase edits the canonical `agent-system/extensions/core/` path first and mirrors to `.claude/` as an explicit task step; each phase's verification diffs the two copies |
| Looping the script per task adds N invocations to `/task --sync` and multi-task `/orchestrate` entry | L | M | Bounded by non-terminal active task count (small); the script early-exits for any task not in one of the four reconcilable statuses |
| A task-number citation leaks into a deliverable comment outside `specs/**` | L | M | Explicit MUST NOT in every phase that adds a comment; verification greps the touched files |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |

Phases within the same wave can execute in parallel. Phases 2, 3, 4, and 5 touch four disjoint
files and share no state; each depends on Phase 1 only because Phase 1 settles the promotion
semantics they wire up. Phase 5 is optional/stretch and is the first to drop if effort runs long.

---

### Phase 1: Handoff-aware promotion guard in reconcile-task-status.sh [COMPLETED]

**Goal**: Make the `researching`/`planning`/`implementing` branches respect a non-success handoff
before promoting, so that automatic reconciliation (Phase 3) cannot convert a reported `blocked`
or otherwise-unsuccessful outcome into a false success. This is the enabling precondition for
every automatic caller.

**Tasks**:

- [x] Read `agent-system/extensions/core/scripts/reconcile-task-status.sh` in full; note the
      `partial` branch's existing handoff check (it reads `.orchestrator-handoff.json`, compares
      `.status` to `"implemented"`, and no-ops otherwise) — this is the pattern to generalize.
      *(completed)*
- [x] Add a helper (e.g. `handoff_permits_promotion <expected_status>`) implementing the same
      contract the `partial` branch already uses: if the handoff file is absent, permit promotion
      (preserves today's behavior for tasks with no handoff); if present and `.status` matches the
      success value for the phase, permit; otherwise refuse and report. *(completed)*
- [x] Define the per-branch success values: `researching` -> `researched`, `planning` -> `planned`,
      `implementing` -> `implemented`. Confirm each against the handoff `status` values actually
      written by the corresponding agents before hardcoding them; if a phase's success value cannot
      be confirmed, permit promotion for that branch and record the reason in the summary rather
      than guessing. *(completed: confirmed against handoff-schema.md's status enum and
      skill-orchestrate's Stage 5 dispatch_status case statement — researched/planned/implemented
      are the exact values written)*
- [x] Wire the guard into the `researching`, `planning`, and `implementing` branches, between the
      artifact-found check and the promotion. Leave the `partial` branch's existing check alone —
      it already implements this contract correctly. *(completed)*
- [x] On refusal, print a visible line in BOTH dry-run and live mode (this branch must not inherit
      the script's live-no-op silence, because a refusal is exactly the case a human needs to see):
      `[reconcile] Task N: status=X, artifact exists but handoff status=Y — refusing promotion`.
      Exit 0 (a refusal is a correct no-op, not an error). *(completed)*
- [x] Record the refused-promotion case using the sanctioned `blocked`/`partial` postflight termini
      that predecessor hardening added, if and only if the handoff status maps unambiguously to one
      of them. If the mapping is ambiguous, report and no-op — do not invent a status. *(completed:
      handoff status "blocked"/"partial" map 1:1 to the same-named target_status; any other value
      including "failed" or an empty/missing status field is left as a plain no-op)*
- [x] Mirror the edited script to `.claude/scripts/reconcile-task-status.sh`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — add handoff guard helper; call
  it from the three artifact-existence branches (canonical source).
- `.claude/scripts/reconcile-task-status.sh` — deploy mirror (copy, not a second hand-edit).

**Verification**:

- `bash -n` parses cleanly on both the canonical and mirrored copies.
- `diff agent-system/extensions/core/scripts/reconcile-task-status.sh .claude/scripts/reconcile-task-status.sh`
  is empty.
- Fixture test (see Testing & Validation for the full template): with `status=researching` and a
  report artifact present but **no** handoff file, `--dry-run` still reports the promotion — the
  no-handoff path is unchanged from today.
- Fixture test: with `status=researching`, a report artifact, and a handoff whose `status` is
  `blocked`, both `--dry-run` and live mode print the refusal line and do not promote.
- Fixture test: with `status=researching`, a report artifact, and a handoff whose `status` is
  `researched`, live mode promotes as before.
- `grep -nEi 'task [0-9]|\(task [0-9]' agent-system/extensions/core/scripts/reconcile-task-status.sh`
  returns no new hits.

---

### Phase 2: Wire /task --sync as the primary live trigger [COMPLETED]

**Goal**: Add a status-reconciliation step to Sync Mode alongside the existing artifact-
reconciliation step, so the command the system already tells users to run for "state looks wrong"
actually repairs status. This is the primary trigger: user-invoked, never on a hot path.

**Tasks**:

- [x] Read the Sync Mode section of `agent-system/extensions/core/commands/task.md`, in particular
      step 2.5 (`reconcile-artifacts.sh`) — the new step goes immediately after it as step 2.6, so
      artifact registration is backfilled before status is reconciled against it. *(completed)*
- [x] Generate a session ID inline (Sync Mode deliberately does not source the gate-in script, so
      it has none): use the standard portable pattern
      `sync_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"`. *(completed)*
- [x] Add the sweep loop over non-terminal active tasks. Select `researching`/`planning`/
      `implementing`/`partial` from `state.json` using the `| not` inequality pattern required by
      this codebase's jq escaping workaround — never the `!=` operator. *(deviation: altered — used
      a direct `select(.status == "researching" or ... or .status == "partial")` positive-match
      selector instead of a negation-of-terminal-statuses `| not` selector. Both avoid `!=`
      entirely; positive-match against the four reconcilable statuses is simpler and was verified
      to return the identical result set against real `specs/state.json` as a `| not`-based
      cross-check)*
- [x] Call `bash .claude/scripts/reconcile-task-status.sh "$task_num" "$sync_session_id"` per task,
      live (not dry-run): the user explicitly invoked a repair command. *(completed)*
- [x] **Visibility**: capture each call's combined output. Print it verbatim when non-empty. After
      the loop, always print a summary line — `Status reconciliation: N task(s) promoted` — and,
      when N is zero, `Status reconciliation: no tasks required status repair`. The zero case must
      print; a silent sweep is the failure mode this task exists to eliminate. *(completed)*
- [x] Keep the step non-fatal: a per-task failure warns and continues to the next task, matching
      how step 3's `generate-todo.sh` call already degrades. *(completed)*
- [x] Do not renumber the existing steps; insert as 2.6. *(completed)*
- [x] Mirror to `.claude/commands/task.md`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/commands/task.md` — new Sync Mode step 2.6 (canonical source; this
  file was not in the task's declared file scope — research identified it as required by the
  chosen primary trigger).
- `.claude/commands/task.md` — deploy mirror.

**Verification**:

- Extract the step 2.6 shell block and run `bash -n` on it.
- Run the sweep loop's jq selector against the real `specs/state.json` and confirm it returns only
  tasks in the four reconcilable statuses (compare against a manual read of state.json).
- Fixture test: a fixture state.json with one stranded task and one `completed` task; run the
  loop's logic against the fixture and confirm the stranded task is promoted and the completed
  task is untouched.
- Fixture test: a fixture with zero stranded tasks; confirm the `no tasks required status repair`
  summary line prints.
- `diff` the canonical and mirrored copies; confirm empty.
- Confirm no task-number citations were added to `task.md`.

---

### Phase 3: Wire /orchestrate entry as the secondary automatic trigger [COMPLETED]

**Goal**: Reconcile a task stranded by a previous crashed run exactly once per invocation, before
any lifecycle decision is made — on both the single-task and multi-task paths, and never inside a
cycle loop.

**Tasks**:

- [x] Read `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` Stage 2 (loop guard
      init) and Stage 3 (state machine loop), and Stage MT-2 (routing table build) / MT-3 (cycling
      loop), to place the calls precisely. *(completed)*
- [x] **Single-task**: add the call at the Stage 2 / Stage 3 boundary — after loop-guard
      initialization, before the `while` loop opens. It must be outside the loop body. `session_id`
      and `task_number` are both already in scope there. *(completed: verified by inspection —
      lines 155-172 precede `while` at line 177)*
- [x] **Multi-task**: add the call inside Stage MT-2's existing per-task iteration (the loop that
      already visits every task once to build the routing table), not in Stage MT-3's cycling loop.
      This is what satisfies the once-per-task requirement on a path that has no single per-task
      entry point — the reconcile rides the existing iteration rather than needing new entry
      detection. *(completed: verified by inspection — lines 650-667 sit inside Stage MT-2, before
      Stage MT-3 begins at line 669)*
- [x] Call live (not dry-run), consistent with the orchestrator's explicit no-confirmation design:
      no human is reliably present to gate on, and Phase 1's guard now bounds what promotion can do.
      *(completed)*
- [x] **Visibility**: because a live no-op prints nothing, bracket each call —
      `recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)`.
      If `recon_out` is non-empty, echo it. If empty, echo
      `[orchestrate] Entry reconcile: no stranded status found for task $task_number`. Both paths
      print; neither is silent. Use the same `[orchestrate]` prefix the surrounding stages use.
      *(completed)*
- [x] Keep it non-fatal (`|| true`): a reconcile failure must never prevent the orchestrator from
      starting. *(completed)*
- [x] Add a brief comment at each call site stating the once-per-invocation constraint and why
      (the failure mode is a *previous* run's crash, observable only at entry; per-cycle calls
      would be redundant and would fight the orchestrator's own preflight writes). **MUST NOT**
      cite a task number in that comment. *(completed)*
- [x] Mirror to `.claude/skills/skill-orchestrate/SKILL.md`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 2/3 boundary call;
  Stage MT-2 per-task call (canonical source).
- `.claude/skills/skill-orchestrate/SKILL.md` — deploy mirror.

**Verification**:

- Confirm by reading the diff that the single-task call sits before the `while` line and the
  multi-task call sits inside MT-2's iteration and not in MT-3's loop body — this is a structural
  claim about placement, so verify it by inspection of the surrounding lines, not by running the
  orchestrator.
- `bash -n` on the extracted bracketing snippet from each of the two call sites.
- Fixture test: run the bracketing snippet against a fixture task with nothing to reconcile and
  confirm the `no stranded status found` line prints (this is the branch that would otherwise be
  invisible).
- Fixture test: run it against a stranded fixture task and confirm the script's `[reconcile]` lines
  are echoed through.
- `diff` the canonical and mirrored copies; confirm empty.
- `grep -nEi 'task [0-9]' ` the added lines; confirm no new task-number citations (note the file
  has pre-existing citations elsewhere — do not add more, and do not remediate existing ones here).

---

### Phase 4: Wire skill-todo as a dry-run-then-confirm reporter [COMPLETED]

**Goal**: Make status-stranded tasks visible to `/todo` — they are currently invisible to its scan
and therefore unarchivable forever — without ever silently promoting status immediately before
silently moving a directory.

**Tasks**:

- [x] Read `agent-system/extensions/core/skills/skill-todo/SKILL.md` stages 1, 2 (`ScanTasks`), 8
      (`DryRunOutput`), and 9 (`InteractivePrompts`) to match the file's XML-ish stage structure and
      its established conventions. *(completed)*
- [x] Add a new `<stage id="1.5" name="ReconcileScan">` between `ParseArguments` and `ScanTasks`, so
      any promotion the user approves is reflected before Stage 2's scan reads status. *(completed)*
- [x] In that stage: select non-terminal active tasks from `state.json` (same `| not` selector as
      Phase 2), call `bash .claude/scripts/reconcile-task-status.sh "$n" "$session_id" --dry-run`
      per task, and collect any task whose dry-run output reports a would-promote into
      `reconcile_candidates`. Dry-run mode is what makes this stage side-effect-free. *(deviation:
      altered — used the same positive-match selector as Phase 2's step 2.6 rather than a `| not`
      negation selector, for the same reason recorded there: both avoid `!=` entirely, and
      positive-match is simpler. Fixture-verified byte-identical state.json before/after)*
- [x] **Visibility (dry-run output)**: extend Stage 8's preview with a line mirroring the existing
      memory-candidate line's style — `Status reconciliation: {N} task(s) stranded with artifacts
      on disk`, or `Status reconciliation: none`. Stage 8 exits after display, so this is the whole
      visibility contract for `/todo --dry-run`. *(completed)*
- [x] **Visibility (interactive)**: add a sub-step to Stage 9 presenting `reconcile_candidates`
      through the skill's existing `AskUserQuestion` multiSelect pattern, showing each candidate's
      task number, current status, the artifact found, and the promotion that would result. Skip
      the sub-step entirely when `reconcile_candidates` is empty, matching how the memory-harvest
      sub-step already handles its empty case. *(completed)*
- [x] Only for user-selected candidates, re-run the script **without** `--dry-run` to apply the
      promotion, echoing its `[reconcile]` output. Unselected candidates are left stranded and
      simply are not archived this run — that is the correct conservative outcome. *(completed:
      verified by grep — the only non-dry-run invocation in the file sits in this Stage 9 branch)*
- [x] State explicitly in the stage description that this stage never auto-repairs: `/todo` performs
      the system's most irreversible operations, and a silent promotion followed by a silent archive
      compounds two mutations with no visibility. *(completed)*
- [x] Mirror to `.claude/skills/skill-todo/SKILL.md`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — new stage 1.5; Stage 8 preview line;
  Stage 9 confirmation sub-step (canonical source).
- `.claude/skills/skill-todo/SKILL.md` — deploy mirror.

**Verification**:

- Confirm the new stage id and structure match the file's existing `<stage id=... name=...>`
  convention by inspection.
- `bash -n` on the extracted stage 1.5 shell block.
- Fixture test: run the stage 1.5 selector + dry-run call against a fixture with one stranded task;
  confirm the script prints its `Would promote` line and that `state.json` in the fixture is
  **byte-identical before and after** — proving the scan stage is genuinely side-effect-free.
- Confirm by reading the diff that no live (non-dry-run) invocation exists anywhere in the file
  outside the user-selected branch in Stage 9.
- `diff` the canonical and mirrored copies; confirm empty.
- Confirm no task-number citations were added.

---

### Phase 5: Report-only plan-vs-state divergence check (optional/stretch) [COMPLETED]

**Goal**: Surface plan-file-vs-state.json status divergence, which currently has no detector
anywhere in the system. **This phase is optional.** It is new comparison logic rather than pure
wiring, and the task's hard requirement is "give the script a caller" — which Phases 1-4 satisfy
completely. Drop this phase if effort runs long; the tree stays green without it.

**Tasks**:

- [x] Confirm the gap still holds before building anything: the TODO renderer reads only
      `state.json` and never opens a plan file, so nothing compares the two today. If a detector has
      appeared since research, stop and report rather than duplicating it. *(completed: re-grepped
      generate-todo.sh and all scripts for a plan-vs-state comparator; confirmed still absent)*
- [x] Add a report-only check to `reconcile-task-status.sh`: read the version-ordered latest plan
      file's `- **Status**:` field and compare it against `state.json`'s status for the same task.
      *(completed: reuses the existing version-ordered `find_latest_artifact "plans"` helper)*
- [x] Use the settled plan-level marker vocabulary — `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED,
      ABANDONED, COMPLETED}` — and note that this is a deliberately narrower set than the phase-
      heading vocabulary. Do not compare against phase-heading markers; they are a different grain.
      *(completed: `plan_level_equivalent()` maps only these six state.json values; statuses with
      no plan-level equivalent, e.g. researching/planning, are silently skipped)*
- [x] On mismatch, print `[reconcile] WARNING: task N plan status=X, state.json status=Y` and
      **nothing else**. **MUST NOT** repair either direction: unlike "artifact exists, therefore
      promote," a plan-vs-state mismatch has no unambiguous correct side. Exit code is unaffected.
      *(completed; fixture-verified both files byte-identical before/after a mismatch)*
- [x] Run the check for every reconcilable status, including the branches that no-op, so divergence
      is reported even when there is nothing to promote. *(completed: `check_plan_state_divergence`
      is called as the first statement in all four branches, before their own no-artifact early
      exits)*
- [x] Mirror to `.claude/scripts/reconcile-task-status.sh`. *(completed)*
- [x] *(unplanned, discovered during fixture testing)* Hardened `find_latest_artifact()` against a
      pre-existing latent bug: under `set -euo pipefail`, an artifact subdirectory that exists but
      is empty made the unexpanded `*.md` glob fail `ls`, and pipefail aborted the entire script
      with exit 2 instead of a normal no-artifact no-op. This directly undermines the
      non-fatal/visible guarantees Phases 2-4 build on top of this function, so it was fixed in the
      same file already being edited (`|| true` on the pipeline) rather than deferred. Fixture
      re-verified: an existing-but-empty artifact directory now no-ops cleanly (exit 0) instead of
      crashing.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — report-only divergence check
  (canonical source; same file as Phase 1, sequenced after it).
- `.claude/scripts/reconcile-task-status.sh` — deploy mirror.

**Verification**:

- `bash -n` on both copies.
- Fixture test: a fixture whose plan file says `[COMPLETED]` while state.json says `implementing`;
  confirm the WARNING line prints and that the fixture's `state.json` and plan file are both
  byte-identical before and after — proving report-only.
- Fixture test: matching plan and state; confirm no WARNING prints.
- Fixture test: task with no plan file at all; confirm no WARNING and no error (exit 0).
- `diff` the canonical and mirrored copies; confirm empty.

---

## Testing & Validation

All verification runs against an isolated fixture or by static inspection. **No phase may be
verified by running `/orchestrate`, `/task --sync`, or `/todo` live** — Phases 3 and 4 edit the very
documents a running orchestrator or archival run would be executing, and this plan is itself being
executed under an orchestrator.

**Fixture template.** The script resolves `PROJECT_ROOT` as `SCRIPT_DIR/../..`, so placing the
scripts at `$FIXTURE/.claude/scripts/` makes `$FIXTURE` the project root and fully isolates the
run from the real `specs/state.json`:

```bash
FIXTURE=$(mktemp -d)
mkdir -p "$FIXTURE/.claude/scripts" "$FIXTURE/specs/900_fixture_task/reports"
cp .claude/scripts/reconcile-task-status.sh \
   .claude/scripts/update-task-status.sh \
   .claude/scripts/update-plan-status.sh \
   .claude/scripts/update-phase-status.sh \
   .claude/scripts/generate-todo.sh \
   "$FIXTURE/.claude/scripts/"
cat > "$FIXTURE/specs/state.json" <<'JSON'
{
  "next_project_number": 901,
  "active_projects": [
    {"project_number": 900, "project_name": "fixture_task", "status": "researching",
     "task_type": "meta", "artifacts": []}
  ]
}
JSON
touch "$FIXTURE/specs/900_fixture_task/reports/01_fixture-report.md"

bash "$FIXTURE/.claude/scripts/reconcile-task-status.sh" 900 sess_fixture_test --dry-run
```

Adapt per phase by varying `status`, adding `.orchestrator-handoff.json`, adding `plans/`, or
adding a second non-reconcilable task. Remove the fixture when done. Note the directory name must
be `{padded_number}_{project_name}` — the script derives it from state.json, so a mismatch produces
a silent no-op that looks like a passing test.

**Checklist**:

- [ ] `bash -n` passes on both copies of every edited shell block or script.
- [ ] Every edited file is byte-identical between `agent-system/extensions/core/...` and its
      `.claude/...` mirror (`diff` returns empty for each).
- [ ] Phase 1: promotion is refused when the handoff reports a non-success status; unchanged when
      no handoff exists.
- [ ] Phase 2: the sweep selector matches exactly the four reconcilable statuses; the zero-candidate
      summary line prints.
- [ ] Phase 3: both call sites are outside their respective cycle loops (verified by inspection);
      the empty-output branch prints its no-op notice.
- [ ] Phase 4: the scan stage leaves fixture `state.json` byte-identical; no live invocation exists
      outside the user-confirmed branch.
- [ ] Phase 5 (if executed): divergence is reported and nothing is mutated.
- [ ] No file outside `specs/**` gained a task-number citation:
      `grep -rnEi '\(task [0-9]+\)|task [0-9]+' ` over the diff of each touched file.
- [ ] No new script files were created anywhere.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (+ `.claude/` mirror) — handoff
  guard (Phase 1); optional report-only divergence check (Phase 5).
- `agent-system/extensions/core/commands/task.md` (+ mirror) — Sync Mode step 2.6 (Phase 2).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (+ mirror) — entry reconcile at
  the Stage 2/3 boundary and in Stage MT-2 (Phase 3).
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (+ mirror) — stage 1.5, Stage 8 line,
  Stage 9 sub-step (Phase 4).
- `specs/879_wire_reconcile_task_status_safety_net/summaries/01_wire-reconcile-safety-net-summary.md`
  — implementation summary, recording which trigger points landed, whether Phase 5 was executed,
  and the deferred lock-release follow-up.

## Rollback/Contingency

Each phase touches one canonical file plus its mirror and is independently revertible with
`git checkout` of the canonical path followed by re-mirroring to `.claude/` (the mirror is
gitignored, so reverting the canonical file alone leaves a stale deploy copy — always re-mirror).
No phase migrates data or mutates real task state: all four callers invoke an existing script whose
own mutations already go through the established tmp-file-rename and postflight-replay paths.

Contingency by phase:

- Phase 1 refuses too aggressively (promotions that should happen do not): the guard permits
  promotion when no handoff file exists, so the blast radius is limited to tasks that have a
  handoff reporting a non-success status — arguably the correct outcome. If a phase's success value
  proves wrong, widen that branch's accepted set rather than removing the guard.
- Phase 3 proves too noisy at `/orchestrate` entry: reduce to printing only non-empty script output
  (dropping the explicit no-op notice) before considering removing the call entirely — the call is
  the point, the notice is tunable.
- Phase 5 is the designated drop candidate under effort pressure and has no dependents.
