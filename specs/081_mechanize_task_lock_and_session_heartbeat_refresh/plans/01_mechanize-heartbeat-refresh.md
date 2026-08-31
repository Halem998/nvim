# Implementation Plan: Task #81

- **Task**: 81 - Mechanize task-lock and session-registry heartbeat refresh: liveness timestamps never advance during a multi-phase /implement run
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None declared. Cross-reference only to project 73 (`correlate_subagent_postflight_hook_to_owning_session`, status `not_started`) for the events.jsonl amendment in Phase 7; no `file_scope` overlap.
- **Research Inputs**: `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/reports/01_heartbeat-non-execution-root-cause.md`
- **Artifacts**: plans/01_mechanize-heartbeat-refresh.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the root cause empirically: the Stage 4D heartbeat calls in
`general-implementation-agent.md` were **never emitted** across all 8 phase transitions of a real
successful run (0/8), while the `update-phase-status.sh` call four lines above them fired 16/16.
The fix is therefore structural, not editorial: move the refresh out of agent prose and into
`update-phase-status.sh` itself — the one script empirically proven to run at every phase
transition — and derive the `session_id` from `holder.json` inside the script rather than
accepting it from the caller, so that **no caller change and no agent prose is required for the
heartbeat to fire**. Alongside that, this plan hardens the reaper against acting on a bad
timestamp (pid liveness on `holder.json`), surfaces the `acquired_at == heartbeat_at`
never-heartbeated fingerprint as a distinct signal, replaces silent `2>/dev/null` discard with a
non-blocking recorded trace, and closes every row of the research call-site survey.

### Research Integration

Load-bearing findings carried directly into this plan (do **not** re-investigate any of these):

- **Root cause is (a) STRUCTURAL, confirmed by the incident's own subagent transcript.** 16
  `update-phase-status.sh` invocations, 8 `git-commit-scoped.sh` invocations, **0**
  `task-lock.sh heartbeat` / `session-heartbeat` invocations. Hypotheses (b) and (c) are ruled
  out. This is settled fact in this plan, not a premise to re-derive.
- **Hypothesis (d) is real but not causal.** `cmd_heartbeat`'s two no-op branches (no lock dir /
  holder.json, and holder-session mismatch) return 0 with only a stderr WARN, which the call
  site's `2>/dev/null` discards. This is a genuine observability defect the plan must fix
  independently (acceptance criterion 4).
- **Placeholder landmine confirmed empirically**: `printf "%03d" "{task_number}"` exits 1, so an
  unsubstituted brace placeholder would make `resolve_task_dir` fail and `cmd_heartbeat` return 2
  — silently, under `2>/dev/null || true`. This is a direct argument against *any* fix that
  re-emits these calls as agent-authored bash.
- **The gap is wider than the observed site.** `general-implementation-hard-agent.md` and
  `skill-orchestrate-hard/SKILL.md` have **zero** heartbeat call sites (absent-caller gap, not a
  failing-caller gap). `skill-orchestrate/SKILL.md`'s three sites (lines ~313, ~318, ~1518) use
  the correct shell-var form but were never empirically observed firing — treat as "same risk
  class, no positive evidence either way", not as confirmed-good.
- **`implement.md`'s "no intra-batch session heartbeat" reasoning has a falsified premise.** Its
  justification defers to a per-phase heartbeat that does not fire. The reasoning becomes true
  again once Phase 1 lands; until then the comment is misleading.
- **Severity is a latent hazard, not a fired incident.** The observed run was ~18 min, under the
  30-min `TASK_LOCK_STALE_MIN`. Research could not establish any historical threshold crossing
  from `events.jsonl` (its `duration_seconds` is per-lifecycle-stage, not per-run). Do not
  overstate severity in any deliverable.
- **The events.jsonl cross-session attribution finding belongs to project 73**, whose task
  already owns the `head -1` marker mis-selection defect. File as a recorded amendment; do not
  fix here (no `file_scope` overlap with `agent-system/extensions/core/hooks/`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- Make the task-lock and session-registry heartbeat fire mechanically at every phase transition
  of a single-task `/implement` run, without depending on any agent executing a documented bash
  snippet (acceptance criteria 1-3).
- Make a heartbeat no-op leave a recorded, findable trace without becoming blocking (criterion 4).
- Close every row of the research call-site survey: fixed, demonstrated, or documented as
  deliberately absent with a reason (criterion 5).
- Give the task lock a pid liveness signal and make both `cmd_reap` and `cmd_acquire`'s
  stale-override refuse to act against a live process (criterion 6).
- Surface `acquired_at == heartbeat_at` as a distinct never-heartbeated diagnostic (criterion 7).
- Resolve the events.jsonl cross-session-attribution finding to a definite home (criterion 8).

**Non-Goals**:

- Rewriting or "clarifying" the prose heartbeat instructions. Research answered design question 1
  in the negative: clearer prose is not the fix, and a 0/8 result is not explained by wording,
  placement, or placeholder form.
- Touching `agent-system/extensions/core/hooks/**`. The `head -1` marker-selection defect and the
  events.jsonl misattribution it causes belong to project 73.
- Changing `TASK_LOCK_STALE_MIN` / `TASK_LOCK_REAP_MIN` defaults, or altering the never-blocks
  contract of `heartbeat` / `session-heartbeat` / `release`.
- Adding a heartbeat to `skill-implementer/SKILL.md`. It is a thin wrapper with no
  phase-transition point of its own; this stays documented-as-deliberately-absent.
- Retrofitting a per-batch intra-dispatch heartbeat into `implement.md` Step 3. Its omission is
  intentional and becomes correct again once Phase 1 lands.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Heartbeat logic inside `update-phase-status.sh` throws under `set -euo pipefail` and breaks every phase transition system-wide | H | M | Wrap the entire block in a guarded function whose every command ends `|| true`; the block must be unable to alter the script's exit code or stdout. Phase 4's functional test asserts the script still exits 0 and prints only the plan path when the lock/session entry are absent, corrupt, and unresolvable. |
| Heartbeat writes to stdout and breaks callers that capture `$(update-phase-status.sh ...)` as a plan path | H | M | Contract: the heartbeat block writes **nothing** to stdout, ever. All output goes to the trace log or stderr. Phase 4 asserts byte-exact stdout equality against the pre-change behavior. |
| Deriving `session_id` from `holder.json` refreshes a lock on behalf of a *foreign* session that happens to be updating phase status | M | L | Accept and document: a phase transition is positive evidence of forward progress on that task, and the derived value is self-consistent by construction. The optional 5th `session_id` argument exists precisely so a caller that knows its identity can assert it and get a traced mismatch instead of a silent refresh. |
| `write_holder` signature change (adding pid) breaks its existing callers | H | M | `write_holder` is called only from `cmd_acquire` and `cmd_heartbeat`. Phase 2 enumerates and updates every call site in the same edit, and treats an absent `pid` field on a legacy `holder.json` as "no liveness information" — identical to today's behavior, never a hard failure. |
| `cmd_check` output-line change breaks a downstream parser | M | L | The fingerprint is an **appended** field on an existing line; the line prefix (`held-fresh` / `held-stale`) and all three exit codes (0/1/2) are unchanged. Phase 3 greps every consumer of `cmd_check` output before editing. |
| Test fixtures that invoke `update-phase-status.sh` in a repo with no lock or session registry now emit unexpected trace files | L | M | The no-lock path is already a clean no-op; additionally provide a `PHASE_HEARTBEAT_DISABLE=1` env opt-out and confirm the existing suites (`test-update-task-status.sh`, `test-postflight-deploy-gate.sh`, `test-skill-base-lifecycle.sh`, `test-phase-heading-patterns.sh`) still pass. |
| The live reproduction (criterion 1) cannot be observed because the deployed `.claude/` tree is regenerated only at postflight, after this run's phase transitions | M | H | Phase 7 does not depend on the deploy timing for its primary evidence: the load-bearing proof is Phase 4's deterministic fixture test (real `holder.json` + real session entry + real `update-phase-status.sh`, asserting `heartbeat_at > acquired_at`). A live observation on this task's own `.lock/holder.json` is attempted as corroboration and recorded honestly as attempted-or-not, never fabricated. |
| Deliverable edits under `agent-system/**` accidentally carry task-number references | M | M | `.claude/rules/no-task-references-in-deliverables.md` applies; a blocking write-time hook exists. Describe changes by durable anchors (script name, section heading), never by task number. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 5, 6 | 1, 2 |
| 3 | 4 | 1, 3 |
| 4 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel. Wave 2's phase 3 is blocked by 2 only;
phases 5 and 6 are blocked by 1 only.

**Territory note**: Phase 1 owns `scripts/update-phase-status.sh`. Phases 2 and 3 both own
`scripts/task-lock.sh` and are therefore serialized (3 depends on 2) even though their concerns
are independent. Phases 5 and 6 own disjoint markdown sets.

---

### Phase 1: Mechanize the heartbeat inside update-phase-status.sh [COMPLETED]

**Goal**: Make both heartbeats fire from the one script empirically proven to run at every phase
transition, with `session_id` derived rather than supplied, so that no caller change and no agent
prose is required. This is the phase that satisfies acceptance criteria 2, 3, and 4.

**Why this mechanism cannot be skipped** (acceptance criterion 3 requires this stated explicitly,
so record it in the script's own header comment as well): `update-phase-status.sh` is the single
command an implementation agent must invoke to move a phase heading — the transition is not
representable any other way, and the transcript shows it invoked 16/16 while the adjacent prose
heartbeat was invoked 0/8. Putting the refresh *inside* that script means the only way to skip
the heartbeat is to skip the phase transition itself. Deriving `session_id` from `holder.json`
rather than accepting it as a required argument is what removes the last prose dependency: a 5th
positional argument would still have to be typed by the same agent prose that was proven not to
be executed, and would additionally re-open the confirmed `printf "%03d" "{task_number}"`
brace-placeholder landmine.

**Tasks**:

- [x] Add a `heartbeat_after_phase_transition()` function to
      `agent-system/extensions/core/scripts/update-phase-status.sh`, invoked **once**,
      immediately after `plan_dir` has been resolved and validated and **before** both the
      "Phase N not found" exit and the idempotency early-exit — so that a no-op status update and
      an unmatched phase number both still refresh liveness (the caller is demonstrably alive and
      working the task in both cases).
- [x] Resolve the task directory as `dirname "$plan_dir"` (already computed with the
      padded/unpadded fallback) and read `session_id` from `${task_dir}/.lock/holder.json` via
      `jq -r '.session_id // empty'`. Absent lock directory, absent/unparseable `holder.json`, or
      empty `session_id` => trace and return, never fail.
- [x] Accept an **optional** 5th positional argument `session_id`. When supplied and non-empty:
      compare against the value read from `holder.json`; on mismatch, write a
      `noop:session-mismatch` trace line naming both values and do **not** heartbeat. When
      absent: use the derived value (which is byte-identical to the holder's by construction, so
      `cmd_heartbeat`'s mismatch branch is unreachable from this call site). Update the usage
      line, the header comment block, and the argument-count validation accordingly — the
      existing 4-argument invocation must remain valid and unchanged in behavior for every
      current caller.
- [x] Resolve `task-lock.sh` using the same deploy-tree-first / source-store-fallback candidate
      list already used in this file for `phase-heading-patterns.sh`
      (`${repo_root}/.claude/scripts/task-lock.sh`, then
      `${repo_root}/agent-system/extensions/core/scripts/task-lock.sh`). Unlike the phase-library
      resolution, a missing `task-lock.sh` here is **not** an environment error: trace
      `error:task-lock-unresolved` and return 0.
- [x] Invoke `bash "$task_lock" heartbeat "$task_number" "$sid"` and
      `bash "$task_lock" session-heartbeat "$sid"`, **capturing stderr and exit status** rather
      than discarding them with `2>/dev/null`. This is the "never block, but never silent" split
      that design question 3 asks for and criterion 4 requires.
- [x] Append one trace line per subcommand to `${repo_root}/.agent-logs/heartbeat-trace.log`
      (the `.agent-logs` directory is already created by this script for
      `phase-transitions.log`), in the shape:
      `[<ISO8601>] task <N> phase <P> <subcommand>: <ok|noop:<reason>|error:<reason>> session=<sid> sid_source=<derived|argument>` —
      with any captured stderr appended as a trailing `msg=<...>` field, newlines collapsed.
      `cmd_heartbeat`'s existing `WARN: heartbeat no-op — ...` stderr text is what makes the
      `noop:` reasons informative; do not suppress it.
- [x] Guard the entire block so it can neither alter the script's exit code nor write to stdout:
      every command inside ends `|| true`; the function is called as
      `heartbeat_after_phase_transition >/dev/null || true`; and it is skipped entirely when
      `PHASE_HEARTBEAT_DISABLE` is set to a non-empty value (an opt-out for fixture harnesses,
      documented in the header comment).
- [x] Extend the script's header comment block: document the new optional argument, the derived-
      `session_id` rationale (including the explicit statement of why this mechanism cannot be
      skipped, above), the trace-log path and line grammar, the `PHASE_HEARTBEAT_DISABLE`
      opt-out, and the invariant that the heartbeat block never affects stdout or exit code.

**Timing**: 1.0 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that `update-phase-status.sh` currently accepts exactly
4 positional arguments with no session reference, and that adding an optional 5th is
backward-compatible for every existing caller. Confirm at implementation time with
`grep -rn "update-phase-status.sh" agent-system/extensions/core/` and check that no caller passes
more than 4 arguments (research enumerated the call sites in
`general-implementation-agent.md` and `general-implementation-hard-agent.md`; treat that
enumeration as a hypothesis, not a fact, and re-run the grep).

**Files to modify**:

- `agent-system/extensions/core/scripts/update-phase-status.sh` - add the guarded heartbeat
  function, the optional 5th argument, the trace log, and the header documentation.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/update-phase-status.sh` parses clean.
- `shellcheck` (if available) reports no new errors relative to the pre-change file.
- Manual smoke: invoke with 4 arguments against a task directory with **no** `.lock/` — the
  script's stdout is byte-identical to the pre-change output (the plan file path alone), exit
  code 0, and a `noop:` line appears in `.agent-logs/heartbeat-trace.log`.
- Manual smoke: invoke against a task directory with a real `holder.json` — `heartbeat_at`
  advances past `acquired_at`, `acquired_at` is unchanged, and an `ok` trace line is written.
- Full gate set for the repository runs before this phase closes.

---

### Phase 2: Add pid liveness to holder.json and make reaping fail safe [COMPLETED]

**Goal**: Give the task lock the liveness signal the session registry already has, and make both
destructive paths (`cmd_reap` and `cmd_acquire`'s stale-override) refuse to act against a live
process. This satisfies acceptance criterion 6 and is worth doing independently of the heartbeat
root cause, because the reaper acting on a bad timestamp is where the real damage occurs.

**Tasks**:

- [x] Extend `write_holder()` in `agent-system/extensions/core/scripts/task-lock.sh` to persist
      `pid` and `pid_source` alongside its existing six fields, mirroring `write_session_entry`'s
      field set. Reuse the existing `resolve_session_pid` bounded-ancestor-walk helper rather
      than writing a second pid resolver.
- [x] Update every `write_holder` call site to thread pid/pid_source. On a *heartbeat* refresh,
      preserve the pid already recorded in `holder.json` (the heartbeat may be invoked from a
      different process than the acquirer — notably from `update-phase-status.sh` after Phase 1 —
      so re-resolving would silently rewrite the lock's identity); resolve a fresh pid only on
      the acquire paths.
- [x] Make `cmd_reap` refuse to reap a lock whose recorded `pid` is alive (`kill -0`), mirroring
      the session side's dead-pid floor. Emit a `SKIP: ... (holder pid <pid> is alive; refusing
      to reap a live process's lock)` line — visible in both `--dry-run` and real modes, never a
      silent skip. A holder with no `pid` field (legacy) or an unresolvable pid falls through to
      today's timestamp-only behavior unchanged.
- [x] Make `cmd_acquire`'s stale-override path refuse to override a stale lock whose recorded
      `pid` is alive: return the same ABORT/exit-1 shape as the fresh-lock-held-by-another-session
      branch, with a distinct message naming the live pid and instructing manual override. A
      legacy holder with no pid keeps today's override-and-warn behavior.
- [x] Update the `holder.json` schema comment at the top of `task-lock.sh` (currently documenting
      six fields) and the corresponding schema description in
      `agent-system/extensions/core/context/patterns/task-lock.md`.

**Timing**: 1.0 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that `write_holder` has a small, enumerable set of call
sites confined to `cmd_acquire` and `cmd_heartbeat`, and that `holder.json` currently persists
exactly six fields. Confirm at implementation time with
`grep -n "write_holder" agent-system/extensions/core/scripts/task-lock.sh` and by reading the
`jq -n` object construction in `write_holder`; if additional call sites exist, update all of them
in this same phase rather than deferring.

**Files to modify**:

- `agent-system/extensions/core/scripts/task-lock.sh` - `write_holder`, its call sites,
  `cmd_reap`, `cmd_acquire`'s stale-override branch, header schema comment.
- `agent-system/extensions/core/context/patterns/task-lock.md` - holder.json schema description.

**Verification**:

- `bash -n` parses clean; `task-lock.sh --help` (or its usage path) still prints.
- A fixture lock written by `acquire` contains `pid` and `pid_source`.
- A fixture lock with a live pid and a deliberately backdated `heartbeat_at` past
  `TASK_LOCK_REAP_MIN` is **not** reaped and produces the new SKIP line.
- The same fixture with a dead pid **is** reaped, exactly as today.
- A legacy fixture `holder.json` with no `pid` field reproduces today's behavior on both paths.
- Full gate set for the repository runs before this phase closes.

---

### Phase 3: Surface the never-heartbeated fingerprint as a distinct diagnostic [COMPLETED]

**Goal**: Make `acquired_at == heartbeat_at` legible as its own signal, distinct from
"heartbeated then went quiet". This satisfies acceptance criterion 7.

**Tasks**:

- [x] Before editing, grep every consumer of `cmd_check`'s stdout and exit codes across
      `agent-system/extensions/core/` (research named `reconcile-task-status.sh` as one) and
      confirm no consumer does an exact whole-line match that an appended field would break.
      Record the consumer list in the phase's progress file.
- [x] Extend `cmd_check`'s `held-fresh` / `held-stale` output lines with an appended
      `never_heartbeated=<true|false>` field, computed as
      `acquired_at == heartbeat_at`. Line prefix and all three exit codes (0 free / 1 held-fresh /
      2 held-stale) are unchanged.
- [x] Extend `cmd_reap`'s `would reap:` / `reaped:` / `SKIP:` lines with the same
      `never_heartbeated=` field, so a dry-run sweep distinguishes "this lock's owner died" from
      "this lock's owner never heartbeated once".
- [x] Document the fingerprint and its two distinct meanings in the exit-code / output-contract
      comment block at the top of `task-lock.sh`, and in
      `agent-system/extensions/core/context/patterns/task-lock.md`.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that `cmd_check`'s output is consumed only by
prefix/exit-code readers and that an appended field is safe. Confirm at implementation time with
`grep -rn "task-lock.sh check\|held-fresh\|held-stale" agent-system/extensions/core/` and read
each hit before editing. If any consumer parses the whole line, adapt that consumer in this same
phase.

**Files to modify**:

- `agent-system/extensions/core/scripts/task-lock.sh` - `cmd_check`, `cmd_reap`, header contract
  comments.
- `agent-system/extensions/core/context/patterns/task-lock.md` - fingerprint documentation.

**Verification**:

- `bash -n` parses clean.
- A freshly acquired, never-heartbeated fixture lock reports `never_heartbeated=true`; the same
  lock after one `heartbeat` reports `never_heartbeated=false`.
- Every enumerated `cmd_check` consumer still behaves identically (build of the changed module
  plus its enumerated direct dependents — i.e. re-run each consumer script's own test where one
  exists).
- Full gate set for the repository runs before this phase closes.

---

### Phase 4: Functional test proving the heartbeat advances [NOT STARTED]

**Goal**: Provide the deterministic, repeatable evidence for acceptance criteria 1 and 2 that
does not depend on catching a live long-running run: a fixture harness that exercises the real
`update-phase-status.sh` against a real `holder.json` and a real session-registry entry and
asserts `heartbeat_at` strictly advances past `acquired_at` across two consecutive phase
transitions.

**Tasks**:

- [ ] Create `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh`, following the
      structural conventions of an existing suite in that directory (read
      `test-phase-heading-patterns.sh` and `test-update-task-status.sh` first and match their
      fixture-repo construction, assertion helpers, and exit-code conventions rather than
      inventing new ones).
- [ ] Fixture: a temporary repo root with `specs/{NNN}_{slug}/plans/01_x.md` containing two
      conforming phase headings, a `.lock/holder.json` whose `acquired_at` and `heartbeat_at` are
      both set to a **fixed past timestamp**, and a `specs/.sessions/{session_id}.json` entry
      with `started_at` and `heartbeat_at` at that same past value. Using a backdated fixture
      makes the assertion deterministic with no `sleep` and no wall-clock race.
- [ ] Assertions, one test case each:
      1. After one 4-argument `update-phase-status.sh ... IN_PROGRESS` call, `holder.json`'s
         `heartbeat_at` is strictly greater than its `acquired_at`, and `acquired_at` is
         unchanged. (Acceptance criterion 2, task-lock half.)
      2. The session entry's `heartbeat_at` is strictly greater than its `started_at`, and
         `started_at` is unchanged. (Acceptance criterion 2, session-registry half.)
      3. After a second call (`... COMPLETED`), both `heartbeat_at` values have advanced again or
         are unchanged only because the ISO second has not ticked — assert
         `heartbeat_at >= previous_heartbeat_at` **and** `> acquired_at`, so the test is not
         flaky at sub-second granularity. (Acceptance criterion 1, "advancing across at least two
         phase transitions".)
      4. **stdout contract**: stdout is byte-identical to the pre-change contract (the plan file
         path alone), and the exit code is 0.
      5. **Never-blocking**: with `.lock/` absent, with a corrupt `holder.json`, and with an
         unresolvable task directory, the script still exits 0 with unchanged stdout, and a
         `noop:`/`error:` line appears in `.agent-logs/heartbeat-trace.log`. (Acceptance
         criterion 4.)
      6. **Mismatch trace**: invoking with an explicit 5th `session_id` that differs from the
         holder's produces a `noop:session-mismatch` trace line and does **not** advance
         `heartbeat_at`.
      7. **Fingerprint**: a never-heartbeated fixture lock reports `never_heartbeated=true` from
         `task-lock.sh check`; after the phase transition it reports `false`. (Acceptance
         criterion 7, wired to Phase 3.)
      8. **Opt-out**: with `PHASE_HEARTBEAT_DISABLE=1`, no heartbeat fires and no trace line is
         written.
- [ ] Register the new test in `agent-system/extensions/core/scripts/tests/run-all.sh` and in the
      `manifest.json` file list, matching how the neighbouring test scripts are registered.
- [ ] Re-run the existing suites that invoke `update-phase-status.sh` in a fixture repo
      (`test-update-task-status.sh`, `test-postflight-deploy-gate.sh`,
      `test-skill-base-lifecycle.sh`, `test-phase-heading-patterns.sh`) and confirm none regressed.

**Timing**: 1.0 hours

**Depends on**: 1, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly four existing test suites invoke
`update-phase-status.sh` in a fixture repo. Confirm at implementation time with
`grep -rln "update-phase-status" agent-system/extensions/core/scripts/tests/` and run every suite
the grep returns, not only the four named here.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` - new file.
- `agent-system/extensions/core/scripts/tests/run-all.sh` - register the new suite.
- `agent-system/extensions/core/manifest.json` - add the new test to the scripts file list.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` passes, all cases.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes with no new failures
  relative to a pre-change baseline captured before this phase begins.
- Full gate set for the repository runs before this phase closes.

---

### Phase 5: Retire the never-executed prose at the implementation-agent sites [COMPLETED]

**Goal**: Close the two agent-file rows of the research call-site survey (acceptance criterion 5)
by removing the confirmed-non-firing prose and the brace-placeholder landmine it carries, and
replacing it with an accurate statement of where the refresh now lives.

**Tasks**:

- [x] In `agent-system/extensions/core/agents/general-implementation-agent.md` Stage 4D, delete
      the two trailing heartbeat paragraphs and their fenced bash blocks (the `task-lock.sh
      heartbeat` and `task-lock.sh session-heartbeat` snippets in brace-placeholder form). These
      are the confirmed-0/8 instructions and the confirmed `printf "%03d" "{task_number}"`
      landmine; leaving them alongside the mechanized path would be a second, competing,
      unreliable call site.
- [x] Replace them with a short non-executable note stating that the task-lock and
      session-registry refresh now happens **inside** `update-phase-status.sh` at this exact
      transition, that the `session_id` is derived from `holder.json` so no argument is needed,
      that a no-op leaves a trace in `.agent-logs/heartbeat-trace.log`, and that the agent must
      not re-add a manual heartbeat call. Reference `context/patterns/task-lock.md` for the
      contract. Do not include a bash block.
- [x] Add the same note to `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
      at its Stage 4D-equivalent `update-phase-status.sh ... COMPLETED` call. This closes the
      absent-caller gap research identified there **without adding prose that must be executed** —
      the hard agent already invokes `update-phase-status.sh`, so it inherits the mechanized
      heartbeat with no behavioral change of its own.
- [x] Verify no task-number references are introduced (`.claude/rules/no-task-references-in-deliverables.md`);
      describe the change by script name and section heading only.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the base agent's Stage 4D heartbeat paragraphs sit at
roughly lines 279-297 and the hard agent's `update-phase-status.sh ... COMPLETED` call at roughly
line 222. Line numbers drift; confirm at implementation time by grepping for `task-lock.sh
heartbeat` and `update-phase-status.sh` in both files rather than editing by line number.

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - remove the two
  heartbeat bash blocks from Stage 4D, add the mechanized-here note.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - add the
  mechanized-here note at its phase-completion call.

**Verification**:

- Diff read-through confirms every changed hunk lies inside prose/markdown regions and that no
  remaining fenced bash block in either file invokes `task-lock.sh heartbeat` or
  `session-heartbeat`.
- `grep -n "task-lock.sh heartbeat\|session-heartbeat"` on both files returns only prose mentions,
  no fenced-block invocations.
- The repository's agent-contract lint (`test-lint-agent-contracts.sh`) still passes.
- Full gate set for the repository runs before this phase closes.

---

### Phase 6: Close the cycle-layer and documentation rows of the survey [NOT STARTED]

**Goal**: Complete acceptance criterion 5 for every remaining surveyed site, and correct the
documentation whose stated premise research falsified.

**Tasks**:

- [ ] `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`: add the task-lock
      and session-registry heartbeat pair at the Stage 3 state-machine loop's per-cycle loop-guard
      write (the `jq ... '.current_state = $state | .last_updated = $updated | .cycle_count =
      $count | .plan_version = $plan_version'` block), mirroring `skill-orchestrate/SKILL.md`'s
      Stage 3 site exactly — **shell-variable** form (`"$task_number"`, `"$session_id"`), never
      brace-placeholder form. This is a genuine absent-caller gap at the cycle layer that the
      phase-layer mechanization does not cover, because a research or plan cycle has no phase
      transitions.
- [ ] `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: leave its three existing
      call sites' code unchanged (correct shell-var form) and add a one-line note at the Stage 3
      site recording that these are the **cycle-layer** heartbeat, complementary to and now
      backstopped by the mechanized phase-layer refresh inside `update-phase-status.sh`, and that
      they remain necessary for research/plan cycles which have no phase transitions.
- [ ] `agent-system/extensions/core/commands/implement.md`: correct the "No intra-batch
      session-registry heartbeat" reasoning. Its justification currently defers to a per-phase
      heartbeat that did not fire; rewrite it to point at the mechanized site inside
      `update-phase-status.sh` and to state that the deferral is sound **because** the refresh is
      now mechanically guaranteed at every phase transition. Keep the omission itself — it is
      intentional and correct.
- [ ] `agent-system/extensions/core/skills/skill-implementer/SKILL.md`: update its note that "the
      refresh lives in the agent's Stage 4D" to name the mechanized site instead, and keep the
      documented-as-deliberately-absent statement that this wrapper has no phase-transition point
      of its own.
- [ ] `agent-system/extensions/core/context/patterns/task-lock.md`: update the "Consumers (Six
      Distinct Wiring Paths)" item 2 wiring description — the phase-transition heartbeat is now
      internal to `update-phase-status.sh`, not a call site in the agent file — and add the
      `skill-orchestrate-hard` cycle-layer site to the consumer list.
- [ ] Record the completed survey table (every site: fixed / mechanized / demonstrated /
      deliberately absent with reason) in this phase's progress file, so Phase 7's summary can
      carry it into the task summary verbatim.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts five files and one new `skill-orchestrate-hard` call
site. Confirm the full site list at implementation time with
`grep -rn "heartbeat" agent-system/extensions/core/{skills,commands,context,agents}/` and reconcile
against the research report's survey table; any site the grep finds that is not in the table is
in scope for this phase, not a deferral.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - add the per-cycle
  heartbeat pair.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - add the complementary-layer
  note.
- `agent-system/extensions/core/commands/implement.md` - correct the falsified deferral reasoning.
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - repoint its heartbeat note.
- `agent-system/extensions/core/context/patterns/task-lock.md` - update consumer wiring item 2.

**Verification**:

- Diff read-through confirms every changed hunk is prose or a fenced block in the correct
  shell-variable form; no brace-placeholder heartbeat invocation exists anywhere in
  `agent-system/extensions/core/`
  (`grep -rn 'task-lock.sh \(session-\)\?heartbeat "{' agent-system/extensions/core/` returns
  nothing).
- Every cross-reference introduced resolves to an existing file and section heading.
- The repository's markdown/contract lints still pass.
- Full gate set for the repository runs before this phase closes.

---

### Phase 7: Reproduction, telemetry-finding placement, and closeout [NOT STARTED]

**Goal**: Satisfy acceptance criteria 1 and 8, and record the complete survey and design-decision
narrative.

**Tasks**:

- [ ] Deploy the source-store changes to the working `.claude/` tree using the repository's own
      deploy path (never by hand-editing `.claude/**`), so the mechanized script is live.
- [ ] **Live corroboration attempt**: sample this task's own
      `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/.lock/holder.json` and the
      corresponding `specs/.sessions/{session_id}.json` before and after this phase's own status
      transitions. Record `acquired_at`, `heartbeat_at`, and the delta. If the deploy landed
      mid-run and the observation is therefore only partial, **record that honestly** — the
      load-bearing evidence for criteria 1-2 is Phase 4's deterministic fixture test, and a
      partial or unavailable live observation must never be written up as a successful
      reproduction.
- [ ] **Criterion 8**: append a recorded amendment to project 73
      (`correlate_subagent_postflight_hook_to_owning_session`) in `specs/state.json`, adding an
      acceptance criterion that the fix must be shown to correct **event attribution** in
      `specs/events.jsonl`, not merely marker selection — citing the observed three
      `subagent_stop` events whose `cc_session_id` belongs to a different Claude session. Do not
      touch `agent-system/extensions/core/hooks/**`. Use the state-management update pattern
      (append/edit the description via a jq-based edit, then regenerate TODO.md); do not
      wholesale-replace any array.
- [ ] Write the task summary to
      `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/summaries/01_mechanize-heartbeat-refresh-summary.md`,
      carrying: the completed call-site survey table from Phase 6, the explicit statement of which
      mechanism guarantees execution and why it cannot be skipped (criterion 3), the pid-liveness
      decision (criterion 6), the fingerprint decision (criterion 7), the trace-mechanism design
      (criterion 4), the reproduction evidence and its honest limits (criteria 1-2), and the
      project 73 amendment (criterion 8).
- [ ] Optional, only if time permits and it does not expand scope: note in the summary the
      research report's context-extension recommendation — a `context/patterns/` or
      `context/standards/` note on when a behavior MUST be mechanized versus when agent prose is
      acceptable — as a follow-up candidate, with this work cited as a worked example. Do not
      author that context file under this task.

**Timing**: 0.75 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that project 73 exists in `specs/state.json` with status
`not_started` and owns the `head -1` marker-selection defect. Confirm at implementation time by
reading that project's entry before amending it; if its status has changed or its description
already covers event attribution, record that instead of appending a duplicate criterion.

**Files to modify**:

- `specs/state.json` - amendment to project 73's description (specs/** only; no deliverable
  task-number rule applies here).
- `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/summaries/01_mechanize-heartbeat-refresh-summary.md` - new file.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes.
- `specs/state.json` validates (`scripts/validate-state.sh` or the repo's state validator).
- The summary explicitly addresses all eight acceptance criteria by number.
- Full gate set for the repository runs before the task completes.

---

## Testing & Validation

- [ ] **Criterion 1**: `test-phase-heartbeat.sh` demonstrates `heartbeat_at` advancing across two
      consecutive phase transitions against a real `holder.json` and a real session-registry
      entry; a live observation on this task's own lock is recorded (or its unavailability is
      recorded honestly).
- [ ] **Criterion 2**: both `holder.json.heartbeat_at > acquired_at` and
      `sessions/{sid}.json.heartbeat_at > started_at` are asserted, with `acquired_at` /
      `started_at` proven unchanged.
- [ ] **Criterion 3**: the summary and `update-phase-status.sh`'s header both state which
      mechanism guarantees execution (the refresh is internal to the one script that must run for
      a phase transition to exist) and why it cannot be skipped.
- [ ] **Criterion 4**: every no-op class (missing lock, corrupt holder, session mismatch,
      unresolvable task dir, unresolvable `task-lock.sh`) writes a distinct, findable trace line
      and never blocks or changes the exit code.
- [ ] **Criterion 5**: the survey table in the summary lists every site as
      fixed / mechanized / demonstrated / deliberately-absent-with-reason.
- [ ] **Criterion 6**: pid-aware refusal is proven for both `cmd_reap` and `cmd_acquire`'s
      stale-override, with legacy pid-less holders shown to keep today's behavior.
- [ ] **Criterion 7**: `never_heartbeated=true|false` is emitted by `check` and by
      `reap --dry-run` and flips correctly across one heartbeat.
- [ ] **Criterion 8**: project 73's entry carries the recorded amendment.
- [ ] **Regression**: `run-all.sh` shows no new failures against a baseline captured before
      Phase 1 begins.
- [ ] **No stdout regression**: `update-phase-status.sh` stdout is byte-identical to the
      pre-change contract in every tested path.
- [ ] **Deliverable rule**: no task-number reference appears in any file outside `specs/**`.
- [ ] **Source-store rule**: no file under `.claude/**` was hand-edited; every change targets
      `agent-system/extensions/core/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/update-phase-status.sh` (mechanized heartbeat, optional
  5th argument, trace log)
- `agent-system/extensions/core/scripts/task-lock.sh` (pid liveness, fail-safe reap and
  stale-override, never-heartbeated fingerprint)
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` (new suite)
- `agent-system/extensions/core/scripts/tests/run-all.sh`, `manifest.json` (registration)
- `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `general-implementation-hard-agent.md` (prose retired / mechanized-here note)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (new cycle-layer site),
  `skill-orchestrate/SKILL.md`, `skill-implementer/SKILL.md` (notes)
- `agent-system/extensions/core/commands/implement.md` (corrected deferral reasoning)
- `agent-system/extensions/core/context/patterns/task-lock.md` (schema, fingerprint, consumer
  wiring)
- `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/summaries/01_mechanize-heartbeat-refresh-summary.md`
- `specs/state.json` (project 73 amendment)
- `.agent-logs/heartbeat-trace.log` (runtime artifact, not committed)

## Rollback/Contingency

- Every phase is committed per green sub-step, so any single phase reverts with
  `git revert` of its own commits without disturbing the others.
- **Highest-risk revert**: Phase 1 touches a script invoked at every phase transition
  system-wide. If a regression appears, the immediate mitigation is `PHASE_HEARTBEAT_DISABLE=1`
  in the environment — it restores the exact pre-change behavior without a revert or a redeploy
  of the whole tree. That opt-out exists specifically as this contingency, and the summary must
  say so.
- **Phase 2 contingency**: if the pid-aware refusal proves too conservative (a lock held by a
  process whose pid is reused, or an ancestor-walk resolving to a long-lived shell), the refusal
  can be narrowed to the reaper only, leaving `cmd_acquire`'s stale-override on today's
  timestamp-only behavior — recorded as a partial satisfaction of criterion 6 with its reason,
  which criterion 6 explicitly permits ("or the decision not to add it is recorded with an
  argument").
- **If the live reproduction cannot be obtained** (deploy timing, run too short), do not
  fabricate it: record the fixture-test evidence as the criterion-1 satisfaction and state
  plainly that a live long-run observation remains outstanding. A fabricated reproduction would
  be a worse outcome than an honest gap.
