# Research Report: Task #35

**Task**: 35 - Remove or correctly gate a one-time preflight side effect that marks a plan phase [IN PROGRESS] when no agent is dispatched for it
**Started**: 2026-08-12T00:00:00Z
**Completed**: 2026-08-12T00:00:00Z
**Effort**: small-medium (single-file logic deletion + two SKILL.md comment updates + one new regression test)
**Dependencies**: serialized behind the handoff-identity/loop-guard task (both edit `skill-orchestrate-hard/SKILL.md`); this task's root-cause file (`update-task-status.sh`) is disjoint
**Sources/Inputs**: codebase (update-task-status.sh, skill-orchestrate-hard/SKILL.md, skill-orchestrate/SKILL.md, general-implementation-agent.md, general-implementation-hard-agent.md, test-skill-base-lifecycle.sh, test-update-task-status.sh), git history (`git log -p`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and root-caused correctly by the task description: `update_plan_file()`'s
  auto-advance block in `agent-system/extensions/core/scripts/update-task-status.sh` (current
  lines 526-585, nested inside the function that starts at line 469) independently re-derives
  "the first `[NOT STARTED]` phase" via its own `grep -m1` scan, which can select a **different
  phase** than the one the orchestrator is about to dispatch — this is the actual mechanism
  behind the observed phase-19 bug, not mere redundancy.
- **The task description's own "IMPORTANT SCOPE WIDENING" claim does not hold against the
  current code.** `update_plan_file()` has an unconditional early return, `if [[
  "$target_status" != "implement" ]]; then return 0; fi`, at line 471 — *before* the
  `operation == preflight` check the task description cites. This means the phase-advance
  side effect (and the whole PHASE 3 block) is already unreachable for `target_status ==
  research` or `target_status == plan`, regardless of `operation`. Verified against
  `git log -p` (the `target_status != implement` guard has been present since it was
  introduced as a scope-narrowing commit; it is not a new or accidental gate). Acceptance
  criterion 3 ("settle behaviour for all three operation slots") is satisfiable by recording
  this finding: **no code change is needed for the research/plan slots because they cannot
  reach the block today.**
- The "redundant convenience" claim in the code's own comments (lines 574-576) is verified
  true for both engines: `general-implementation-agent.md` (Stage 4A, "for each phase starting
  from resume point") and `general-implementation-hard-agent.md` (Stage 4A, "same contract as
  base agent") both unconditionally call `update-phase-status.sh ... IN_PROGRESS` themselves
  as the very first action for whatever phase they actually work on. No path was found where
  anything downstream depends on the plan file already showing `[IN PROGRESS]` before the
  agent's own Stage 4A runs — the hard engine's own next-phase heading scan matches on
  `PHASE_STATUS_OPEN_ERE` (`NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED`), so a phase left at
  `[NOT STARTED]` is still selectable.
- **Recommended fix: (a) delete**, not gate. Deletion is justified because (1) the dispatched
  agent already owns every per-phase `[IN PROGRESS]` transition unconditionally in both
  engines, confirmed by reading both implementation-agent files, and (2) the independent
  re-scan is not just redundant but actively incorrect whenever the orchestrator's own
  phase-selection criteria diverge from a naive "first NOT STARTED" scan — which is exactly
  what happened at phase 19.
- Root cause of the divergence, concretely: the hard engine's per-phase dispatch (Stage 4,
  `#### State: planned or implementing`) selects `next_phase` via a scan over
  `PHASE_STATUS_OPEN_ERE` (first heading matching NOT STARTED **or** IN PROGRESS **or**
  PARTIAL **or** BLOCKED). `update-task-status.sh`'s auto-advance instead scans for the first
  heading matching **only** `[NOT STARTED]`. When the phase actually being dispatched/resumed
  is itself `[IN PROGRESS]` (e.g. a continuation/resume of an already-started phase) or
  `[PARTIAL]`/`[BLOCKED]`, the orchestrator's scan correctly re-targets that phase, but
  `update-task-status.sh`'s independent scan skips past it (it isn't `[NOT STARTED]`) and
  instead marks whatever the next **strictly-NOT-STARTED** phase is — which can be a
  later, undispatched phase. This is exactly a phase-19-while-dispatching-phase-18 scenario.
  The same divergence is reachable through the `partial` state's "continuation available"
  sub-state in `skill-orchestrate-hard/SKILL.md` (~line 985-990), which also calls
  `skill_preflight_update ... implement ...` and is explicitly commented as "usually a no-op"
  — that comment is about the *state.json* transition only; the *plan-file phase scan* is not
  gated by `state_is_noop` at all and re-runs unconditionally on every preflight call,
  including this continuation-resume site.
- Existing test coverage gap confirmed: `test-skill-base-lifecycle.sh`'s Group 4 only exercises
  `skill_preflight_update 1 "plan" ...` (a `target_status` that never reaches PHASE 3 at all,
  per the finding above) — it asserts only the `state.json` transition, never touches a plan
  file. `test-update-task-status.sh` covers `--phase-check` (a postflight-only backstop) but
  has no case exercising preflight's phase-marker side effect at all. Both files are on the
  task's file-scope list and are the right places to add regression coverage.

## Context & Scope

Scope was the four files listed in the task's `FILE SCOPE`:
`agent-system/extensions/core/scripts/update-task-status.sh`,
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`,
`agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`,
`agent-system/extensions/core/scripts/tests/test-update-task-status.sh`. The task's own text
requires verifying its "co-maintenance" claim against `skill-orchestrate/SKILL.md` too (that
file is not in the source-store FILE SCOPE list verbatim, but the task explicitly instructs:
"Verify base mode's preflight call sites for the same side effect regardless" and "the
corresponding change MUST be made in `skill-orchestrate/SKILL.md` as well" if Stage-4-call-site
prose changes are needed). This research therefore also read `skill-orchestrate/SKILL.md` and
both implementation-agent files (`general-implementation-agent.md`,
`general-implementation-hard-agent.md`) to establish whether the dispatched agent genuinely
owns the per-phase transition in both engines.

## Findings

### Codebase Patterns

**The exact block to remove** (`agent-system/extensions/core/scripts/update-task-status.sh`,
current line numbers):

- Lines 469-473: `update_plan_file()` function start, with the top-level guard
  `if [[ "$target_status" != "implement" ]]; then return 0; fi` — this line stays; it is the
  reason research/plan preflights already never reach the phase logic.
- Lines 474-524: plan-file top-level `[STATUS]` stamp (`IMPLEMENTING`/`COMPLETED` via
  `update-plan-status.sh`) — unrelated to the phase-marker defect, keep unchanged.
- Lines 498-503 (inside the `DRY_RUN` branch): the dry-run preview echo includes a nested
  `if [[ "$operation" == "preflight" ]]` block (lines 500-502) that previews the phase-advance
  specifically (`"[dry-run] Phase status: first [NOT STARTED] phase -> [IN PROGRESS] ..."`) —
  this preview line must be removed together with the real logic, or the dry-run preview will
  describe a side effect that no longer happens.
- **Lines 526-585: the actual auto-advance block to delete.** This is
  `# Auto-advance the first NOT STARTED phase to IN PROGRESS on implement preflight` through
  its closing `if [[ "$operation" == "preflight" ]]; then ... fi` (585), which itself nests the
  `has_nonconforming_phase_headings` guard (564-567) and the `grep -m1 -E
  "${PHASE_HEADING_ERE}.*\[NOT STARTED\]"` scan + `update-phase-status.sh ... IN_PROGRESS` call
  (568-580). The whole `if` statement at 527 down to its `fi` at 585 is the deletable unit; it
  sits entirely inside `update_plan_file()`, after the (retained) top-level plan-status update.
  The function's own comment already flags it as "Superseded by the base agent owning every
  per-phase transition directly; this call is a redundant convenience" (lines 574-576) —
  research below confirms that comment is accurate for both engines, not aspirational.

**Confirmation the dispatched agent owns every per-phase transition (both engines)**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` Stage 4, "For each
  phase starting from resume point" (line 112) → Stage 4A "Mark Phase In Progress" (lines
  131-136): `bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name"
  "$phase_num" IN_PROGRESS`, called unconditionally as the very first action of processing any
  phase, in the base (whole-plan, sequential) engine.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` line 160-163: "Call
  `update-phase-status.sh` to mark the phase active (same contract as base agent)" — identical
  call, in the hard (per-phase-dispatch) engine.
- No other code path was found (grep across `agent-system/extensions/core/` for `Auto-advance`
  and the "first ... NOT STARTED ... IN PROGRESS" phrase) that duplicates or depends on
  `update-task-status.sh`'s own independent scan. `implementation-workflow.md`'s "find first
  [NOT STARTED] or [IN PROGRESS] phase" language is a *different, legitimate* mechanism — it
  describes the agent's own resume-point detection inside its dispatch, not a duplicate of the
  preflight convenience.

**Confirmation of the divergence mechanism** (why phase 19 got marked with no dispatch):
- `skill-orchestrate-hard/SKILL.md`'s per-phase dispatch handler (`#### State: planned or
  implementing`, current lines ~688-843) computes `next_phase` via a heading scan matching
  `PHASE_STATUS_OPEN_ERE` = `NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED` (line 739), i.e. the
  *first phase not yet closed*, which may itself already be `[IN PROGRESS]` (a resumed phase).
- Immediately before dispatching the agent for that `$next_phase`, it calls
  `skill_preflight_update "$task_number" "implement" "$session_id"` (line 828), which reaches
  `update-task-status.sh`'s independent `grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT
  STARTED\]"` (line 568) — a **narrower** match (`[NOT STARTED]` only, no `IN
  PROGRESS|PARTIAL|BLOCKED`) that is not told what `$next_phase` is and cannot agree with it
  by construction whenever the two criteria disagree (i.e. whenever `$next_phase` itself is
  not `[NOT STARTED]`).
- The existing comment at lines 822-827 in `skill-orchestrate-hard/SKILL.md` asserts this is
  safe — "phase-1 auto-advance still resolves next_phase=1, and the call is an idempotent
  no-op on every later phase" — but that reasoning is only correct under the assumption that
  phases are always dispatched in strict NOT-STARTED order with no resumption of an
  already-IN-PROGRESS phase. The `partial` state's "continuation available" sub-state (lines
  ~977-990) is exactly a counterexample: it resumes a phase that is *already* `[IN PROGRESS]`
  (not `[NOT STARTED]`), calls the same `skill_preflight_update ... implement ...`, and that
  call's phase-marker sub-logic is **not** gated by the "usually a no-op" comment there — that
  comment is about the `state.json` status field (already `implementing`), not about the
  independent plan-file phase re-scan, which fires unconditionally regardless of
  `state_is_noop`. This is the live path that plausibly produced the phase-19 bug: the true
  in-flight/resumed phase is not the strictly-first-NOT-STARTED one, so the auto-advance marks
  a later, undispatched phase instead.
- This comment block (lines 822-827) will become stale prose once the auto-advance is deleted
  and must be updated or removed as part of the fix (see Decisions below).

**Scope verification (acceptance criterion 3, all three operation slots)**:
- `research` and `plan` target_status: `update_plan_file()` returns at line 471 before ever
  reaching `operation == preflight` — verified no path to PHASE 3 exists for these two slots
  today. **No fix needed for these two slots**; they were already correctly out of scope. This
  directly contradicts the task description's "IMPORTANT SCOPE WIDENING" hypothesis, which
  should be recorded as investigated-and-refuted rather than acted on.
- `implement` target_status, `operation == preflight`: this is the only slot where the defect
  is reachable, confirmed at three call sites in `skill-orchestrate-hard/SKILL.md` (fresh
  per-phase dispatch at line 828, and the `partial`/"continuation available" sub-state at
  ~line 990) and at the analogous call sites in `skill-orchestrate/SKILL.md` (lines 423, 495,
  553 — base mode always re-dispatches the whole plan, so `update-task-status.sh`'s own scan
  and the base agent's own resume-point scan are more likely, but not provably guaranteed, to
  agree; deletion removes the risk in both engines uniformly rather than relying on that
  likelihood).

### Existing Test Coverage (confirmed insufficient, per task description)

- `test-skill-base-lifecycle.sh` Group 4 (lines 250-297): calls `skill_preflight_update 1
  "plan" "sess_test_preflight"` and `skill_postflight_update 1 "plan" ...` — `target_status`
  is `"plan"` throughout, which (per the finding above) never reaches PHASE 3's plan-file
  logic at all. The group asserts only `state.json` status transitions
  (`planning`/`planned`/unchanged-on-failure). No plan file or phase heading is created or
  asserted anywhere in this group.
- `test-update-task-status.sh` (391 lines): covers `--phase-check=warn|refuse` (Cases 5-7,
  lines 176-277), which is a **postflight**-only backstop (`operation == postflight &&
  target_status == implement`, guarded separately at line 348 in the source script) — a
  completely different code path from the preflight auto-advance. No case in this file invokes
  `update-task-status.sh preflight <task> implement <session>` against a fixture plan file with
  a `[NOT STARTED]` phase and asserts the phase heading is left untouched.
- Both files already have their own `build_fixture_repo`-style scaffolding
  (`test-update-task-status.sh` builds a private `specs/state.json` + task dir with a plan file
  carrying conforming phase headings, per its own header comment at lines 18-25;
  `test-skill-base-lifecycle.sh` has an equivalent `build_fixture_repo()` at line 110) that a
  new regression case can reuse directly.

### Recommendations

1. **Delete**, not gate, the block at `update-task-status.sh` lines 526-585 (the
   `# Auto-advance the first NOT STARTED phase to IN PROGRESS on implement preflight` `if`
   statement) plus its dry-run preview counterpart at lines 500-502. This is justified as
   deletion-of-a-genuinely-redundant-convenience per Acceptance Criterion 2(a): both
   implementation agents (base and hard) unconditionally self-mark their own dispatched phase
   `[IN PROGRESS]` at the start of Stage 4A, and no other code path depends on the plan file
   already showing `[IN PROGRESS]` before that self-mark happens (the hard engine's own
   next-phase selection scan already treats `[NOT STARTED]` as an eligible/selectable open
   state, so nothing is lost by leaving a not-yet-dispatched phase at `[NOT STARTED]` until the
   agent itself starts it).
2. Leave the top-level `target_status != implement` guard (line 471) and the plan-level
   `[STATUS]` stamp (lines 474-524, `IMPLEMENTING`/`COMPLETED` via `update-plan-status.sh`)
   untouched — that is a separate, correctly-scoped, non-buggy side effect unrelated to
   per-phase markers.
3. Update the stale comment block at `skill-orchestrate-hard/SKILL.md` lines 822-827, which
   currently describes and relies on the now-deleted "first-phase auto-advance" behavior
   ("Its one-time side effects (workflow-active marker write, first-phase [NOT STARTED]->[IN
   PROGRESS] auto-advance) do not collide with the heading scan above ... so phase-1
   auto-advance still resolves next_phase=1, and the call is an idempotent no-op on every
   later phase"). Post-fix, `skill_preflight_update ... implement ...` only performs the
   workflow-active-marker write and the plan-level `[STATUS]` stamp — the comment should say
   so, dropping the now-false auto-advance claim.
4. Per the co-maintenance contract (`skill-orchestrate-hard/SKILL.md` lines 956-961/1686-1688),
   check whether an equivalent comment exists in `skill-orchestrate/SKILL.md`'s implement-dispatch
   call sites (lines ~423, ~495, ~553) — this research found **no** equivalent
   auto-advance-describing comment there (base mode's nearby comments describe
   `state.json`-idempotency only, e.g. "usually a no-op (update-task-status.sh preflight is
   idempotent)" near the continuation-available sub-state, which remains accurate post-fix
   since it was never about the phase marker). If the implementer confirms this on a fresh read
   at fix time, no `skill-orchestrate/SKILL.md` prose edit is required beyond that
   verification; if any other comment there is found to describe the deleted behavior, it must
   be updated in lockstep per the stated contract.
5. Add a regression test to close the gap identified in acceptance criterion 4. Two
   placements were assessed:
   - `test-update-task-status.sh` (preferred primary location): add a case exercising `UTS
     preflight 1 implement sess_test_N` against a fixture plan file containing a `### Phase 1:
     ... [NOT STARTED]` heading and asserting the heading is **unchanged** afterward (still
     `[NOT STARTED]`, not flipped to `[IN PROGRESS]`), reusing this file's existing
     fixture-building pattern (its own header already documents building "a private
     specs/state.json and task directory with a plan file carrying conforming phase
     headings").
   - `test-skill-base-lifecycle.sh` Group 4 (optional, secondary): could add a case that calls
     `skill_preflight_update 1 "implement" ...` (not just `"plan"`) against a fixture that
     includes a plan file, to close the gap the task description calls out by name ("exercise
     only the state.json transition, never the plan-file phase side effect"). Since
     `skill_preflight_update` is a thin wrapper that shells out to the same
     `update-task-status.sh` exercised more directly in `test-update-task-status.sh`, the
     `test-update-task-status.sh` case is the higher-value/lower-duplication location; adding
     a `target_status == "implement"` case to Group 4 as well is optional but would directly
     match the task description's own phrasing of the coverage gap.

## Decisions

- **Fix strategy: deletion**, not a dispatch-awareness gate. Rationale recorded above and
  required explicitly by Acceptance Criterion 2 — verified the dispatched agent owns every
  per-phase transition in both engines before choosing this option.
- **No behavior change needed for `research`/`plan` target_status slots** — verified
  unreachable today via the `target_status != implement` guard; Acceptance Criterion 3 is
  satisfied by recording this as the settled behavior for those two slots (already correct,
  not "widened" as the task description hypothesized).
- **Comment maintenance is scoped to `skill-orchestrate-hard/SKILL.md` lines 822-827**, with a
  verification-only check against `skill-orchestrate/SKILL.md` (no comment found there
  describing the deleted behavior at research time; implementer should re-verify at fix time
  per the co-maintenance contract, since prose may have shifted).
- **Regression test primary location: `test-update-task-status.sh`**, asserting a preflight
  `implement` call against a `[NOT STARTED]` phase heading leaves that heading untouched.

## Risks & Mitigations

- **Risk**: deleting the auto-advance could regress a path that silently relies on the plan
  file showing `[IN PROGRESS]` before the agent starts (e.g. a human-observability dashboard,
  or another automated reader gating on the phase marker mid-dispatch-window).
  **Mitigation**: grepped the codebase for all `update-phase-status.sh` call sites and all
  "first NOT STARTED" phrasing; found none besides the deleted block and the two
  implementation-agent Stage 4A calls (which remain). The hard engine's own phase-selection
  scan already accepts `[NOT STARTED]` as an eligible state, so removing the preflight
  pre-mark does not narrow what can be selected for dispatch.
- **Risk**: the "co-maintenance" contract between the two SKILL.md files could be violated if
  the implementer edits comment prose in one file's Stage 4 dispatch sites without checking the
  other. **Mitigation**: this report explicitly calls out that no matching comment currently
  exists in `skill-orchestrate/SKILL.md` (verified by grep for "auto-advance"/"first-phase" —
  zero hits there, three hits in the hard-mode file, all in the one comment block), so the
  update is genuinely scoped to one file's prose plus the shared script; the implementer should
  still re-grep at fix time in case of intervening edits.
- **Risk**: a new regression test could be written against the wrong `target_status`/`operation`
  combination (as the existing Group 4 test was, using `"plan"` instead of `"implement"`),
  reproducing the same coverage gap under a different guise. **Mitigation**: this report states
  explicitly that the case must use `operation=preflight`, `target_status=implement`, and a
  fixture plan file with a real `### Phase N: ... [NOT STARTED]` heading, then assert the
  heading string is byte-identical before and after the call.

## Context Extension Recommendations

- **Topic**: divergent phase-selection criteria between the orchestrator's own next-phase scan
  (`PHASE_STATUS_OPEN_ERE`) and any independent phase-scanning convenience in shared scripts.
  **Gap**: no existing context file documents this specific class of bug (two independent scans
  over the same plan file, using different match criteria, that can silently disagree). **
  Recommendation**: consider a short addendum to
  `agent-system/extensions/core/context/formats/plan-format.md` or
  `agent-system/extensions/core/context/patterns/` noting that any future convenience touching
  phase headings should take the target phase number as an explicit parameter rather than
  independently re-deriving it, to prevent recurrence of this class of defect.

## Appendix

### Search queries / commands used

- `git log --oneline -- agent-system/extensions/core/scripts/update-task-status.sh`
- `git log -p --follow -- agent-system/extensions/core/scripts/update-task-status.sh | grep -n
  "target_status.*!= .implement"` (confirmed the `target_status != implement` early-return guard
  is pre-existing, not newly introduced)
- `grep -rn "update-phase-status.sh" agent-system/extensions/core/` (enumerated every call site;
  confirmed only the deleted block and the two implementation-agent Stage 4A calls invoke it)
- `grep -n "skill_preflight_update|next_phase|PHASE_STATUS_OPEN_ERE|..." skill-orchestrate/SKILL.md`
  and the equivalent for `skill-orchestrate-hard/SKILL.md`
- `grep -rln "first.*NOT STARTED.*IN PROGRESS\|Auto-advance" agent-system/extensions/core/`
  (found three files; the third, `implementation-workflow.md`, describes a different, unrelated
  agent-side resume-point mechanism, not a duplicate defect site)
- Read: `update-task-status.sh` (lines 1-220, 380-600), `skill-orchestrate-hard/SKILL.md`
  (lines 460-1000), `skill-orchestrate/SKILL.md` (lines 390-1040), `general-implementation-agent.md`
  (lines 95-240), `general-implementation-hard-agent.md` (grep for Stage 4A call),
  `test-skill-base-lifecycle.sh` (lines 225-305), `test-update-task-status.sh` (header + grep)

### References

- `agent-system/extensions/core/scripts/update-task-status.sh` (root-cause file; lines 469-586
  is the full `update_plan_file()` function, lines 526-585 is the deletable block)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 4 call sites:
  lines 569, 664, 828, ~990; stale comment: lines 822-827)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 4 call sites: lines
  423, 495, 553; verified no matching stale comment at research time)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 4A, lines
  112-136)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 4A, lines
  ~160-163)
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` (Group 4, lines
  250-297)
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` (391 lines; existing
  `--phase-check` coverage, no preflight phase-marker coverage)
