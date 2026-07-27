# Implementation Plan: Task #906

- **Task**: 906 - fix_gate_out_validation_arity_and_status_vocabulary
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: 885, 896, 901, 909 (file-overlap serialization edges only — no logical prerequisites)
- **Research Inputs**: specs/906_fix_gate_out_validation_arity_and_status_vocabulary/reports/01_gate-out-arity-and-status-vocabulary.md
- **Artifacts**: plans/01_gate-out-arity-and-status-vocabulary.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent, confirmed defects in the agent-system core are fixed here. **Defect 1**: the
non-blocking artifact link-repair leg of `command-gate-out.sh` calls `validate-artifact.sh` with
the wrong arity, so `--fix` binds to the `type` positional and a directory binds to
`artifact_path` — the repair has therefore never run for any command or task, and it prints a
spurious `[FAIL] File not found` to stdout on every gate-out. The fix extracts ONE shared
per-task-directory validation helper into `skill-base.sh` (reachable from `command-gate-out.sh`
via `source`, precedented by `orchestrator-postflight.sh`) so the per-file-type convention cannot
drift again. **Defect 2**: `skill-orchestrate`'s Stage 8 writes `"completed"` into
`.return-meta.json`, a value the format spec explicitly forbids, which makes gate-out's defensive
status-correction branch permanently unreachable for `operation=orchestrate`. The fix changes the
offending writers to emit `"implemented"`, then documents one normative vocabulary source instead
of three independent restatements.

Definition of done: both defects fixed at the source store, both demonstrated live against a
disposable fixture (spurious `[FAIL]` gone with correct per-type validation; the defensive
correction branch shown reachable for `operation=orchestrate`), and every doc whose prose
described the now-removed bug updated to describe the post-fix reality.

### Research Integration

The research report verified every line-number claim in the task description against the canonical
source store and found several had drifted (none changing the diagnosis). Findings this plan
builds on directly, without re-litigating:

- Defect 1 is at `scripts/command-gate-out.sh:115` (description said 101 — stale). Source and
  deployed copy agree at 115, so they have not drifted relative to each other.
- The required shared-helper approach is **feasible**: `command-gate-out.sh` can
  `source .claude/scripts/skill-base.sh` exactly as `orchestrator-postflight.sh:71` already does.
  `skill-base.sh`'s top-level code is side-effect-free at source time (a `SKILL_CONTEXT_BUDGET`
  default plus `BASH_SOURCE`-anchored `SKILL_REPO_ROOT` resolution) — no writes, no process
  spawning.
- `commands/research.md:424`'s "dead code" prose has this same root cause and is the ONLY such
  occurrence repo-wide. It needs **rewording, not deletion**: the inline "Verify Artifacts" check
  (claim-integrity on the agent's own returned paths) and gate-out's sweep (format compliance
  across every artifact present) are complementary, not redundant.
- Defect 2's offenders are `skill-orchestrate/SKILL.md:934` (Stage 8 clean exit) and the Stage
  MT-5 `exit_status` determination bullet (~1396-1398, prose instructing the agent, not literal
  bash) feeding `specs/.return-meta-multi.json`. The `"partial"` branches are already correct.
- `orchestrate-recover-outcome.sh` needs **no change**. Its freshness gate is mtime-based, not
  vocabulary-based, and Stage 8 always runs strictly last within an invocation, after every Stage
  5 recovery call. The two mechanisms are orthogonal by design.
- Three distinct vocabularies share the words "completed"/"implemented" in different files and
  MUST NOT be conflated: `.return-meta.json` skill status; state.json task status
  (`skill-team-implement/SKILL.md:490` and two `context/patterns/*.md` examples all correctly
  write `"completed"` here); and `orchestrator-postflight.sh:445`'s wezterm-notification status.
  All three were audited and cleared as non-offenders.
- The stop-behavior rationale behind the `"completed"` prohibition was re-verified as **current
  and actively enforced**, not a stale premise. No escalation is warranted.
- `docs/architecture/handoff-schema.md`'s vocabulary is at line 74 (description said 45 — drifted)
  and **agrees** with `return-metadata-file.md`, but the identity is enforced nowhere: the two
  files simply happen to list the same six words independently. Same for handoff-schema.md's
  line-268 prose restating `orchestrate-recover-outcome.sh`'s three-value accept-list.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and `roadmap_flag` was not set, so no
roadmap review/update phases are included. `specs/ROADMAP.md` exists but was not consulted and
MUST NOT be modified by this task.

## Goals & Non-Goals

**Goals**:
- Extract ONE shared "validate every artifact in a task directory with its correct per-file type"
  helper into `scripts/skill-base.sh`, adjacent to `skill_validate_artifact`, and make
  `command-gate-out.sh` consume it — so the convention cannot drift again at a future call site.
- Eliminate the spurious `[FAIL] File not found: specs/NNN_slug` line from every gate-out run,
  and make the link-repair leg actually run for the first time.
- Change `skill-orchestrate`'s two forbidden `"completed"` emissions (Stage 8 clean exit; Stage
  MT-5 `exit_status`) to `"implemented"`, leaving both `"partial"` branches untouched.
- Demonstrate live, on a fixture, that (a) gate-out validates each artifact with its correct type
  and emits no spurious `[FAIL]`, and (b) the defensive status-correction branch is reachable for
  `operation=orchestrate`.
- Establish `context/formats/return-metadata-file.md` as the single normative status-vocabulary
  source, with `handoff-schema.md` and `command-gate-out.sh`'s accept-list cross-referencing it
  rather than independently restating it.
- Update every piece of prose that described the now-removed bug (`research.md:424`'s "dead code"
  parenthetical; `command-gate-out.sh`'s "had this branch ever been exercised" comment block).

**Non-Goals**:
- Do NOT add `"completed"` to `command-gate-out.sh`'s accept-list. The accept-list is correct;
  `skill-orchestrate` is the offender. This direction is settled and MUST NOT be inverted.
- Do NOT modify `scripts/orchestrate-recover-outcome.sh`. Its accept-list is already correct and
  is provably safe against the Stage 8 fix via the mtime-freshness argument.
- Do NOT modify `skill-orchestrate-hard/SKILL.md` (reader only), `skill-team-implement/SKILL.md`,
  `context/patterns/jq-escaping-workarounds.md`, `context/patterns/inline-status-update.md`, or
  `orchestrator-postflight.sh:445` — all audited and cleared as correct writers of *different*
  vocabularies.
- Do NOT touch the `"partial"` branches in either Stage 8 or Stage MT-5.
- Do NOT re-sync, regenerate, or edit anything under `.claude/`. See the self-modification note
  in Risks.
- Do NOT change `validate-artifact.sh` itself — its usage contract and `[FAIL]`-to-stdout behavior
  are correct; only the caller was wrong.
- Do NOT sweep pre-existing task-number citations out of unrelated regions of the touched files
  (`skill-base.sh`'s "task 598" header note, `command-gate-out.sh`'s "Task 594" downstream note).
  Only citations inside lines this task is already rewording are removed. The rest is noted as a
  follow-up rather than expanded into here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Self-modification**: this task edits `command-gate-out.sh`, `skill-base.sh`, and `skill-orchestrate/SKILL.md` — machinery executing this very run | H | H | `.claude/` is a stale deploy artifact NOT being re-synced during this run, so source-store edits cannot alter the in-flight orchestration. Phases are ordered so the source store is never left half-edited: Phase 1 adds an unused-but-valid function (safe intermediate), Phase 2 switches the call site. Never run a `.claude/` sync as part of this task. |
| Sourcing `skill-base.sh` under `command-gate-out.sh`'s `set -e` aborts gate-out if any top-level statement returns non-zero | H | L | Research verified skill-base.sh's top-level is assignments + function definitions only. Phase 2 adds an explicit re-verification task (grep the file for top-level executable statements) before wiring, and a live smoke run confirms gate-out still exits 0. |
| Clobbering `skill_propagate_completion_summary` (landed in `skill-base.sh` ~line 472 earlier this session) or task 896's `skill_link_artifacts` edits | H | M | Phase 1's first task is a fresh full re-read of `skill-base.sh`. Insert the new function immediately after `skill_validate_artifact` ends, never by rewriting a line range spanning other functions. Verify both `skill_propagate_completion_summary` and `skill_link_artifacts` are still intact after the edit. |
| Verification against the real repo would mutate real `specs/state.json`, release real task locks, and corrupt in-flight orchestration state | H | H | All verification runs inside a **disposable fixture root** built in Phase 3 (copied `.claude/` + copied `specs/`), never the live repo. The fixture is removed in Phase 7. No verification step ever runs `command-gate-out.sh` from the repo root. |
| Deployed `.claude/scripts/` is stale, so a fixture that copies it verbatim would exercise the OLD code and produce a false pass | H | M | The fixture build explicitly overwrites `<fixture>/.claude/scripts/skill-base.sh` and `command-gate-out.sh` with the FIXED source-store copies after the bulk copy. Phase 3 includes a task to confirm the overwrite landed (grep for the new function name in the fixture copy) before drawing any conclusion. |
| The new helper silently no-ops when `reports/`, `plans/`, or `summaries/` is absent (e.g. a `[RESEARCHED]`-only task has no `summaries/`) | M | H | Per-file `[ -e ]` existence guard inside the loop so an unmatched glob is skipped without error, preserving the current non-blocking posture. |
| Using `shopt -s nullglob` inside a *sourced* function mutates the caller's shell options | M | M | Do not use `nullglob`. Use the per-file `[ -e ]` guard instead, so the library never mutates global shell state. |
| Line numbers drift as edits land within a phase | L | H | Every edit in this plan is anchored to quoted anchor text, with the planning-time line number given only as a locator. Re-grep for the anchor before each edit. |
| Prose updated to claim the branch is "live" before it is actually demonstrated | M | M | Phase 6 (documentation coherence) depends on Phase 5 (reachability demonstration), so no doc asserts reachability that has not been exercised. |
| Introducing a task-number citation into a file outside `specs/**` | M | M | The no-task-references rule is binding. Phase 7 re-greps every touched non-`specs/**` file for `task [0-9]` / `Task [0-9]` patterns in newly added lines. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Phases 1 and 4 touch disjoint files
(`scripts/skill-base.sh` vs `skills/skill-orchestrate/SKILL.md`) and are safe to run
concurrently. Phases 2 and 6 both touch `command-gate-out.sh` but sit in different waves.

---

### Phase 1: Add the shared per-task-directory validation helper [COMPLETED]

**Goal**: A new `skill_validate_task_artifacts` function exists in `skill-base.sh`, correct and
unit-verified, with no existing function clobbered. The source store remains in a valid state
(the function is simply not called yet).

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/skill-base.sh` in full before editing.
      Confirm `skill_validate_artifact` (~324-360), `skill_propagate_completion_summary` (~472),
      and `skill_link_artifacts` (~500) are all present, and note the exact line where
      `skill_validate_artifact`'s closing brace sits. *(completed: closing brace at line 364)*
- [x] Insert `skill_validate_task_artifacts` immediately after `skill_validate_artifact`'s
      closing brace, as a new block — never by rewriting a range that spans another function.
      *(completed)*
- [x] Function contract *(completed)*:
      - Usage comment: `skill_validate_task_artifacts "$task_dir"` — validates every artifact in
        a task directory against its correct per-type format. Non-blocking.
      - Single positional: `task_dir` (used as given; do NOT prefix `SKILL_REPO_ROOT`, because
        `command-gate-out.sh` passes a repo-root-relative path and runs from the repo root).
      - Iterate three `(subdir, type)` pairs: `reports`->`report`, `plans`->`plan`,
        `summaries`->`summary`.
      - For each `"$task_dir"/<subdir>/*.md`, guard with `[ -e "$f" ] || continue` so an
        unmatched glob is skipped. Do NOT use `shopt -s nullglob` (would mutate the sourcing
        caller's shell options).
      - Per file, echo one concise line naming the type and path (mirroring
        `skill_validate_artifact`'s `Validating ${artifact_kind} artifact...` precedent), then
        call `bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null`; on
        non-zero, emit a non-blocking WARNING to stderr naming the file, and continue the loop.
      - `return 0` unconditionally at the end — the function is sourced into callers running
        under `set -e`, so it must never propagate a failure.
- [x] Add a short comment above the function stating why it exists: `validate-artifact.sh` takes
      exactly one file and one type per invocation, so a whole-directory sweep needs its own
      abstraction, and centralizing it here is what keeps the per-file-type convention from
      drifting at future call sites. No task-number citations. *(completed)*
- [x] Unit-verify in isolation, without touching the live repo state: in one bash block,
      `source agent-system/extensions/core/scripts/skill-base.sh` and call
      `skill_validate_task_artifacts specs/913_fix_stage5_missing_handoff_after_research_dispatch`.
      Confirm one line per artifact with the correct type, zero
      `[FAIL] File not found: specs/...` lines naming a directory, and a `0` return.
      (This sources the source-store copy directly; it still invokes the deployed
      `.claude/scripts/validate-artifact.sh`, which is unchanged by this task and therefore
      safe to use.) *(completed: 3 lines printed for report/plan/summary, zero FAIL lines,
      return 0; also confirmed a missing plans/summaries subdir prints nothing and returns 0)*
- [x] Confirm `skill_propagate_completion_summary` and `skill_link_artifacts` are still byte-
      intact via `git diff` on the file — the diff must show ONLY an insertion.
      *(completed: git diff --stat shows 25 insertions, 0 deletions)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` — insert `skill_validate_task_artifacts`
  after `skill_validate_artifact`; pure insertion, no other hunks.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes.
- `git diff --stat` on the file shows insertions only, zero deletions.
- The isolated call above prints exactly one validation line per `.md` file under
  `reports/`, `plans/`, `summaries/` of the fixture task, each with the matching type.
- A call against a task directory missing `summaries/` returns 0 and prints nothing for that
  subdirectory (no error, no `[FAIL]`).

---

### Phase 2: Rewire command-gate-out.sh to the shared helper [COMPLETED]

**Goal**: `command-gate-out.sh`'s artifact-validation leg calls the shared helper with correct
arity, and gate-out still exits 0 with `set -e` in force after sourcing `skill-base.sh`.

**Tasks**:
- [x] Re-verify sourcing safety before wiring: inspect `skill-base.sh`'s top level (outside any
      function body) and confirm it contains only variable assignments and function definitions —
      nothing that can return non-zero under `set -e`. Record the result; if any executable
      top-level statement is found, guard the source (`source ... || true` is NOT acceptable for
      a library whose functions must then exist — instead relocate the helper to a sourceable
      location and record why, per the task's required approach). *(completed: confirmed
      top-level is only `SKILL_CONTEXT_BUDGET`/`SKILL_REPO_ROOT` assignments plus `export` and
      function definitions — no executable statement that can fail under `set -e`)*
- [x] Replace the buggy call (anchor: `bash .claude/scripts/validate-artifact.sh "$task_dir"
      --fix 2>/dev/null || true`, at line 115 as of planning) with a source + helper call:
      `source .claude/scripts/skill-base.sh` then
      `skill_validate_task_artifacts "$task_dir"`, keeping the existing `if [ -d "$task_dir" ]`
      guard and the non-blocking posture. *(completed)*
- [x] Place the `source` following `orchestrator-postflight.sh`'s precedent. Prefer sourcing once
      near the top of the script with a short comment naming the function it is sourced for,
      matching `orchestrator-postflight.sh:70-71`'s in-file comment style; keep the call itself
      at the existing call site. *(completed)*
- [x] Update the script's header comment block (anchor: `This script can be called as a
      subprocess (not sourced) since it only produces side effects`) with one clarifying clause:
      the script may itself source `skill-base.sh` internally — that statement is about how
      callers invoke *this* script, not a restriction on what it may source. No task-number
      citations. *(completed)*
- [x] Do NOT touch the accept-list at the `[ "$skill_status" = "implemented" ]` conditional in
      this phase — its cross-reference comment lands in Phase 6. *(confirmed untouched)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` — add the `source` line, replace the
  mis-arity call, amend the header comment.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/command-gate-out.sh` passes.
- `grep -n 'validate-artifact.sh "\$task_dir"' agent-system/extensions/core/scripts/command-gate-out.sh`
  returns nothing (the mis-arity form is gone).
- `grep -rn 'validate-artifact.sh' agent-system/extensions/core/` shows every remaining call site
  in the correct 3-token `"$path" "$kind" --fix` form.
- Live smoke run of the fixed script under `set -e` is deferred to Phase 3 (needs the fixture).

---

### Phase 3: Build the verification fixture and demonstrate verification (a) [COMPLETED]

**Goal**: A disposable fixture repo root exists containing the FIXED scripts, and a real
`command-gate-out.sh` run inside it validates each artifact with its correct type and emits zero
spurious `[FAIL]`.

**Tasks**:
- [x] Create a disposable fixture root (`mktemp -d`, or a directory under the agent's scratchpad).
      Record the path; it is removed in Phase 7. Nothing in this phase writes outside it.
      *(completed: `$SCRATCHPAD/task906-fixture`)*
- [x] Populate the fixture: `cp -r .claude <fixture>/.claude` (the deployed tree — provides
      `validate-artifact.sh`, `task-lock.sh`, `update-task-status.sh`, `generate-todo.sh`, and
      whatever else those transitively need), then `mkdir -p <fixture>/specs` and copy
      `specs/state.json`, `specs/TODO.md`, and the two real task directories
      `specs/913_fix_stage5_missing_handoff_after_research_dispatch/` and
      `specs/916_fix_orchestrate_completion_summary_propagation/`. *(completed)*
- [x] **Overwrite with the fixed copies** (this is what makes the test meaningful — the deployed
      tree is stale and is NOT being re-synced): copy
      `agent-system/extensions/core/scripts/skill-base.sh` and
      `agent-system/extensions/core/scripts/command-gate-out.sh` over their fixture counterparts.
      *(completed)*
- [x] Confirm the overwrite landed:
      `grep -c skill_validate_task_artifacts <fixture>/.claude/scripts/skill-base.sh` is non-zero
      AND the same grep against `<fixture>/.claude/scripts/command-gate-out.sh` is non-zero.
      Do NOT proceed on a failed check — a false pass is worse than no test. *(completed: counts
      2 and 3 respectively)*
- [x] Baseline (optional but recommended): before overwriting, run the STALE gate-out in a
      throwaway copy of the fixture and capture the spurious
      `[FAIL] File not found: specs/913_...` line as the before-state. This is the reproduction
      the research verified live twice; capturing it makes the after-state meaningful.
      *(completed: baseline run against the deployed .claude/ before overwrite reproduced
      `[FAIL] File not found: specs/913_fix_stage5_missing_handoff_after_research_dispatch` and
      `[FAIL] File not found: specs/916_fix_orchestrate_completion_summary_propagation`, both
      exit 0)*
- [x] From `<fixture>` as cwd, run
      `bash .claude/scripts/command-gate-out.sh 913 implement <fake_session_id>` and capture full
      stdout+stderr. Repeat for task 916. *(completed, see captured evidence in the execution
      summary)*
- [x] Assess against the pass criteria below. Note that genuine `[ERROR]`/`[FIXED]` lines from
      `validate-artifact.sh` about real format deviations in those artifacts are EXPECTED and are
      not failures — that is the repair leg working for the first time. Only a
      `[FAIL] File not found` naming a *directory* is the defect. *(completed: 913's summary had
      one genuine [ERROR] Missing metadata field: **Task**:; 916's report had one genuine [ERROR]
      Missing required section: ## Recommendations, and its summary the same missing-Task-field
      error — all expected, non-blocking, zero directory-level [FAIL] lines)*

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- None in the repo. All writes are confined to the fixture root.

**Verification**:
- Zero occurrences of `[FAIL] File not found: specs/` in either captured run. **This is
  verification (a)'s primary criterion.**
- One validation line per `.md` file under each of `reports/`, `plans/`, `summaries/` in each task
  directory, each naming the correct type (`report` for `reports/*.md`, etc.).
- Both runs exit 0.
- The before/after contrast is recorded (stale run shows the spurious `[FAIL]`; fixed run does
  not).

---

### Phase 4: Fix the forbidden status vocabulary in skill-orchestrate [COMPLETED]

**Goal**: `skill-orchestrate` no longer emits `"completed"` into `.return-meta.json` or
`.return-meta-multi.json`; both `"partial"` branches are untouched.

**Tasks**:
- [x] Stage 8 clean exit (anchor: the `jq -n \` block containing `--arg status "completed"`
      writing `> "${TASK_DIR}/.return-meta.json"`, at line 934 as of planning): change
      `"completed"` to `"implemented"`. *(completed)*
- [x] Confirm the immediately following partial-exit block (`--arg status "partial"`, ~line 951)
      is left EXACTLY as-is. `"partial"` is in the valid vocabulary. *(confirmed unchanged via
      git diff)*
- [x] Stage MT-5 `exit_status` determination (anchor: the bullet reading ``AND
      `deferred_self_modifying` is empty → `"completed"` (remove `mt_state_file`)``, ~line 1396):
      change the arrow target from `"completed"` to `"implemented"`. This is prose instructing the
      agent what logic to implement, not literal bash — it is a text edit to the bullet.
      *(completed)*
- [x] Confirm the `"partial"` bullet immediately below (including its "incomplete by design"
      rationale prose) is left EXACTLY as-is. *(confirmed unchanged apart from updating the
      "never X" cross-reference word from "completed" to "implemented", required by this same
      task since it names the sibling branch's new value)*
- [x] Add one short clause at the Stage 8 write and at the MT-5 bullet noting that the status
      value comes from the vocabulary defined in `context/formats/return-metadata-file.md`, so a
      future reader does not "correct" it back. Keep it to a sentence; the fuller normative
      statement lands in Phase 6. No task-number citations. *(completed)*
- [x] Re-grep the whole file for `--arg status "completed"` and for `→ "completed"` to confirm no
      further `.return-meta*.json` writer remains. Any hit that writes **state.json** task status
      is correct and MUST be left alone — check what each hit writes to before changing anything.
      *(completed: zero `--arg status "completed"` hits remain; remaining `"completed"` hits are
      all state.json/`fresh_status` task-status references or this task's own clarifying prose)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — two value changes plus two
  short clarifying clauses.

**Verification**:
- `grep -n '"completed"' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — every
  remaining hit is a state.json task status or a `[COMPLETED]` TODO.md marker, never a
  `.return-meta.json` / `.return-meta-multi.json` write.
- Both `"partial"` branches are unchanged in `git diff`.
- `git diff` on the file shows only the intended hunks.

---

### Phase 5: Demonstrate verification (b) — defensive branch reachability [COMPLETED]

**Goal**: The `operation=orchestrate` defensive status-correction branch in
`command-gate-out.sh` is demonstrated **reachable** against a deliberately desynced state.json —
the behavior that has never once fired in production.

**Tasks**:
- [x] Reuse the Phase 3 fixture (rebuild it if it was already torn down). Confirm the fixed
      `command-gate-out.sh` is in place. *(completed: reused `$SCRATCHPAD/task906-fixture`,
      already overwritten with the fixed scripts in Phase 3)*
- [x] In the fixture ONLY, write a `.return-meta.json` into the chosen task directory whose
      `status` is `"implemented"`, produced by running the **fixed** Stage 8 `jq -n` snippet from
      `skill-orchestrate/SKILL.md` verbatim (not hand-authored) — this proves the end-to-end
      chain: Stage 8's emitted value now passes gate-out's accept-list. *(completed, on task
      913's fixture directory)*
- [x] In the fixture's `specs/state.json` ONLY, deliberately desync the task's `status` to a
      value other than `completed` (e.g. `implementing`), so
      `current_status != expected_status` holds. *(completed)*
- [x] From `<fixture>` as cwd, run
      `bash .claude/scripts/command-gate-out.sh <task_number> orchestrate <fake_session_id>` and
      capture full stdout+stderr. *(completed)*
- [x] Confirm the branch fired: the line
      `[gate-out] Defensive correction: status is '...', skill reports 'implemented'. Applying
      correction to 'completed'.` appears. **This echo is the reachability proof**, and it is
      emitted before `update-task-status.sh` is invoked. *(completed: line appeared verbatim —
      `[gate-out] Defensive correction: status is 'implementing', skill reports 'implemented'.
      Applying correction to 'completed'.`)*
- [x] Record what happens downstream, accepting either outcome as valid: (i)
      `update-task-status.sh` succeeds and the fixture's state.json is repaired to `completed`;
      or (ii) the `--phase-check=refuse` backstop returns 4 and gate-out prints the
      `Phase-accounting backstop refused the defensive correction` message. Outcome (ii) still
      proves reachability and is the correct, designed behavior when the plan file shows
      incomplete phases — do NOT weaken the phase-check to force outcome (i). *(completed:
      outcome (i) — the phase-check backstop found 6/6 phases [COMPLETED] in task 913's own plan
      and allowed the correction; `update-task-status.sh` succeeded and the fixture's state.json
      was repaired from `implementing` to `completed`)*
- [x] Run the negative control: repeat with a `.return-meta.json` containing the OLD
      `"completed"` value and confirm the correction line does **not** appear — this isolates the
      vocabulary fix as the cause and confirms the pre-fix branch really was unreachable.
      *(completed: re-desynced state.json to `implementing`, wrote the old forbidden
      `"completed"` value via the same jq idiom, re-ran gate-out — no `[gate-out] Defensive
      correction:` line appeared, and the fixture's state.json remained uncorrected at
      `implementing`, confirming `"completed"` still fails the accept-list exactly as before)*
- [x] Confirm the live repo's `specs/state.json` is untouched (`git diff specs/state.json` shows
      no status change attributable to this phase). *(completed: the only diff in the live
      specs/state.json is task 906's own `not_started` -> `implementing` preflight transition;
      tasks 913 and 916 show no diff)*

**Timing**: 1 hour

**Depends on**: 3, 4

**Files to modify**:
- None in the repo. All writes are confined to the fixture root.

**Verification**:
- The `[gate-out] Defensive correction:` line is present in the positive run. **This is
  verification (b)'s primary criterion.**
- The negative control produces no such line.
- The live `specs/state.json` and the live task locks are unmodified.

---

### Phase 6: Documentation coherence and the single normative vocabulary [NOT STARTED]

**Goal**: Every doc that described the now-removed bug describes post-fix reality, and
`return-metadata-file.md` is the explicit single normative source for the status vocabulary,
referenced rather than restated elsewhere.

**Tasks**:
- [ ] `commands/research.md` (anchor: ``**Verify Artifacts** (research-specific; kept inline —
      `command-gate-out.sh`'s `validate-artifact.sh --fix` leg is dead code and cannot substitute
      for this check)``, line 424 as of planning): reword to describe the two checks as
      complementary, not dead/redundant — the inline step is a **claim-integrity** check on the
      paths the agent itself returned; gate-out's sweep is a **directory-wide format** check over
      every artifact present, regardless of what was claimed. Both are wanted.
- [ ] While rewording that block, remove the task-number citation in the adjacent comment line
      (anchor: `status_token mapping (Phase 1, task 810)`), replacing it with a durable anchor
      (e.g. naming `command-gate-out.sh`'s `status_token` mapping). This is inside the region
      already being edited; do not expand beyond it.
- [ ] `scripts/command-gate-out.sh` comment block (anchor: `would have failed
      update-task-status.sh's validation had this branch ever been exercised`, ~69-73): rewrite
      to describe the branch as **live**, and keep the still-valuable distinction it draws
      between `operation`, `status_token`, and `expected_status`. Remove the now-false
      never-exercised framing.
- [ ] `scripts/command-gate-out.sh` accept-list (anchor: the `[ "$skill_status" = "implemented" ]`
      conditional): add a comment above it cross-referencing
      `.claude/context/formats/return-metadata-file.md` as the normative source of these values,
      so the list and the spec cannot drift silently. Do NOT change the list's contents.
- [ ] `context/formats/return-metadata-file.md` (anchor: the `### status (required)` value table
      and the ``**Note**: Never use `"completed"``` line): add a short statement declaring this
      table the **normative** status vocabulary for `.return-meta.json`,
      `specs/.return-meta-multi.json`, and — by reference — `.orchestrator-handoff.json`. Leave
      the existing table and Note intact.
- [ ] `context/formats/return-metadata-file.md`: add a compact disambiguation table naming the
      three distinct vocabularies that share the words "completed"/"implemented", and which
      file/field each governs: (1) this skill-status vocabulary
      (`.return-meta.json` / `.return-meta-multi.json`); (2) state.json task status, where
      `"completed"` is CORRECT; (3) the lifecycle/wezterm notification status in
      `orchestrator-postflight.sh`, unrelated to either. Explicitly warn against cross-wiring
      them. No task-number citations.
- [ ] `docs/architecture/handoff-schema.md` (anchor: `"status": "researched | planned |
      implemented | partial | failed | blocked"`, line 74 as of planning): add one sentence
      pointing to `context/formats/return-metadata-file.md` as the shared normative enumeration
      that this field's values are drawn from, noting the identity is intentional even though the
      two files govern different artifacts.
- [ ] `docs/architecture/handoff-schema.md` (anchor: the prose restating `orchestrate-recover-
      outcome.sh`'s accept-list, ``whose `status` is `researched`, `planned`, or `implemented``,
      ~line 268): add the same cross-reference so this second restatement also points at the
      normative source instead of standing alone.
- [ ] Add a short note (in `handoff-schema.md` near the recover-outcome passage, or in the
      recover-outcome discussion already there) recording that its accept-list needs no change
      under this vocabulary and that its freshness gate is mtime-based, not vocabulary-based — so
      a future reviewer does not reintroduce coupling between the two mechanisms. Express it as a
      design fact, not as task history; no task-number citations.

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` — reword the "dead code" parenthetical;
  drop the adjacent task-number citation.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — rewrite the never-exercised
  comment block; add the accept-list cross-reference comment.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — normative declaration
  plus the three-vocabulary disambiguation table.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — two cross-reference
  sentences plus the mtime-vs-vocabulary orthogonality note.

**Verification**:
- `grep -rn 'dead code' agent-system/extensions/core/commands/ agent-system/extensions/core/docs/`
  returns no hit referring to the `validate-artifact.sh --fix` leg.
- `grep -rn 'had this branch ever been exercised' agent-system/extensions/core/` returns nothing.
- `return-metadata-file.md` contains the word "normative" in the status section, and both
  `handoff-schema.md` locations reference `return-metadata-file.md` by path.
- The status value table in `return-metadata-file.md` and the ``Never use `"completed"``` Note are
  unchanged.
- `bash -n agent-system/extensions/core/scripts/command-gate-out.sh` still passes.

---

### Phase 7: Final sweep, rule compliance, and cleanup [NOT STARTED]

**Goal**: No residual offenders, no rule violations, no stray fixture, and a complete diff
confined to the declared file scope.

**Tasks**:
- [ ] Confirm **zero** edits under `.claude/`: `git status --short` and `git diff --stat` show no
      path beginning `.claude/`. (`.claude/` is gitignored, so additionally spot-check that no
      Write/Edit targeted it during this task.) Do NOT run a `.claude/` sync.
- [ ] Confirm every changed path is inside the declared `file_scope`
      (`agent-system/extensions/core/{scripts/command-gate-out.sh, scripts/skill-base.sh,
      skills/skill-orchestrate/SKILL.md, docs/architecture/handoff-schema.md,
      context/formats/return-metadata-file.md, commands/research.md}`) plus this task's own
      `specs/906_.../` artifacts. `validate-artifact.sh` was in scope but is expected UNCHANGED —
      flag it if it shows in the diff.
- [ ] Re-grep for residual arity offenders across the whole source store:
      `grep -rn 'validate-artifact.sh' agent-system/extensions/core/` — every call must be
      `"$path" "$kind" --fix` form or the new helper.
- [ ] Re-grep for residual vocabulary offenders: any `--arg status "completed"` or
      `"status": "completed"` writing a `.return-meta*.json`. Confirm the known non-offenders
      (`skill-team-implement/SKILL.md`, the two `context/patterns/*.md` examples,
      `orchestrator-postflight.sh`'s notification mapping) are all still untouched.
- [ ] Confirm `scripts/orchestrate-recover-outcome.sh` and `skills/skill-orchestrate-hard/SKILL.md`
      are unmodified.
- [ ] Rule check — no task-number citations outside `specs/**`: for each touched file, run
      `git diff -U0 <file> | grep '^+' | grep -iE 'task[s]? +[0-9]'` and confirm no ADDED line
      cites a task number. Pre-existing citations in untouched regions are out of scope (noted
      as a follow-up, not fixed here).
- [ ] Remove the verification fixture root and confirm nothing outside the repo's normal
      working tree remains.
- [ ] Write the execution summary to
      `specs/906_fix_gate_out_validation_arity_and_status_vocabulary/summaries/01_gate-out-arity-and-status-vocabulary-summary.md`,
      including: the captured before/after output for verification (a); the captured
      correction-line output plus negative control for verification (b); the recorded answer to
      "is the helper reachable from `command-gate-out.sh`'s execution context" and where it was
      placed; and an explicit statement that the stop-behavior rationale was re-verified as
      current (no escalation needed).
- [ ] Note in the summary's follow-ups: pre-existing task-number citations remain in
      `skill-base.sh`'s header note and `command-gate-out.sh`'s downstream-dependencies note,
      outside the regions this task edited.

**Timing**: 0.5 hours

**Depends on**: 6

**Files to modify**:
- `specs/906_fix_gate_out_validation_arity_and_status_vocabulary/summaries/01_gate-out-arity-and-status-vocabulary-summary.md`
  (new).

**Verification**:
- All greps above return the expected empty/clean results.
- `git diff --stat` lists only in-scope paths.
- The fixture directory no longer exists.
- The summary contains verbatim captured evidence for both (a) and (b), not a restatement that
  they passed.

---

## Testing & Validation

- [ ] `bash -n` passes on both modified shell scripts.
- [ ] `git diff` on `skill-base.sh` is insertion-only; `skill_propagate_completion_summary` and
      `skill_link_artifacts` are byte-intact.
- [ ] **Verification (a)**: a `command-gate-out.sh` run in the fixture against a real task
      directory emits zero `[FAIL] File not found: specs/` lines and one correctly-typed
      validation line per artifact file. Before/after outputs captured.
- [ ] **Verification (b)**: the `[gate-out] Defensive correction:` line appears for
      `operation=orchestrate` against a desynced fixture state.json with an `"implemented"`
      return-meta; the negative control with `"completed"` produces no such line.
- [ ] Zero `validate-artifact.sh` call sites remain in the 2-token form anywhere in the source
      store.
- [ ] Zero `.return-meta*.json` writers emit `"completed"` anywhere in the source store.
- [ ] Both `"partial"` branches in `skill-orchestrate/SKILL.md` are unchanged.
- [ ] No file under `.claude/` was modified; no `.claude/` sync was run.
- [ ] No added line outside `specs/**` cites a task number.
- [ ] The live `specs/state.json` shows no status mutation caused by verification work.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — new `skill_validate_task_artifacts`
  function (insertion only).
- `agent-system/extensions/core/scripts/command-gate-out.sh` — `source` of `skill-base.sh`,
  corrected validation call, rewritten never-exercised comment block, accept-list cross-reference.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 8 clean exit and Stage
  MT-5 `exit_status` emit `"implemented"`.
- `agent-system/extensions/core/commands/research.md` — reworded artifact-verification
  parenthetical; task-number citation removed from the edited region.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — normative-source
  declaration plus three-vocabulary disambiguation table.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — two cross-references to the
  normative source plus the mtime-vs-vocabulary orthogonality note.
- `specs/906_fix_gate_out_validation_arity_and_status_vocabulary/summaries/01_gate-out-arity-and-status-vocabulary-summary.md`
  — execution summary with captured verification evidence.
- Transient (removed in Phase 7): the verification fixture root.

## Rollback/Contingency

- Every change is a small, reviewable edit to six tracked files under
  `agent-system/extensions/core/`. Rollback is `git checkout -- <file>` per file, or `git revert`
  of the phase commits. Because `.claude/` is not re-synced by this task, nothing in the running
  agent system changes until a deliberate future sync — so a bad landing cannot break the harness
  mid-flight.
- **If Phase 2's sourcing-safety re-verification fails** (a top-level statement in `skill-base.sh`
  can return non-zero under `set -e`): do not force the source. Relocate the helper to a
  sourceable location, record why in the summary, and rewire the call site accordingly. The task
  description explicitly sanctions this fallback.
- **If Phase 3's fixture cannot be made to run gate-out end to end** (e.g. `update-task-status.sh`
  needs more of the tree than was copied): expand the fixture copy rather than running against
  the live repo, or narrow to invoking `skill_validate_task_artifacts` directly for (a) while
  still building a full fixture for (b) — the correction-branch echo in (b) requires the real
  script. Never run gate-out from the live repo root as a test.
- **If verification (b)'s downstream `update-task-status.sh` refuses via the phase-check
  backstop**: that is an acceptable pass. Record it and do not weaken the backstop to force a
  state mutation.
- Commit per phase per the repository's commit-per-green-substep convention, so any single phase
  can be reverted independently.
