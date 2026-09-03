# Implementation Plan: Task #147

- **Task**: 147 - Build orchestrate-cycle-plan.sh: one script that returns the cycle's whole dispatch plan
- **Status**: [IMPLEMENTING]
- **Effort**: 16 hours
- **Dependencies**: 146 (`orchestrate-build-dispatch.sh`, landed)
- **Research Inputs**: specs/147_build_orchestrate_cycle_plan/reports/01_orchestrate-cycle-plan-script.md
- **Artifacts**: plans/01_orchestrate-cycle-plan-script.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author `scripts/orchestrate-cycle-plan.sh` in the source store
(`agent-system/extensions/core/`), a single per-cycle composer that absorbs Stage MT-3 steps 1-4.5
and Stage MT-4's pre-dispatch half from `skills/skill-orchestrate/SKILL.md` (a measured 35,169 B +
18,688 B region) and returns one compact JSON object describing the whole cycle's dispatch plan.
The script is glue over four already-stable primitives — `orchestrate-batch-admit.sh`,
`orchestrate-triage-classify.sh`, `orchestrate-build-dispatch.sh`, and a sourced
`command-route-agent.sh` — never a reimplementation of any of them. Two genuinely new behaviors
land alongside the relocation: per-task `force_phases` consumption (closing multi-task's
accepted-and-ignored gap) and missing-task-directory creation. A `--dry-run` mode absorbs and
retires `orchestrate-dry-run-report.sh`, so there is exactly one rendering of every admission
verdict. Done means: the script exists and passes fixture tests for the four named acceptance
areas, the old dry-run script and all its call sites are gone, SKILL.md's collapsed region is
replaced by one call plus a short loop with bytes-removed reported, and the full gate set is green.

### Research Integration

The report at `reports/01_orchestrate-cycle-plan-script.md` supplies the following, all treated as
settled inputs rather than re-derived here:

- The exact seven-step MT-3 decomposition and the MT-4 pre-dispatch boundary (everything up to,
  not including, the Agent tool invocations), with measured byte extents.
- Stable CLI/output contracts for `orchestrate-batch-admit.sh` (NDJSON, schema
  `orchestrate-batch-admit-v5`, exit 2 = degrade-and-proceed), `orchestrate-triage-classify.sh`
  (NDJSON, schema `orchestrate-triage-v1`, exit 2 = fall back to the inline Phase-grouping table),
  and `orchestrate-build-dispatch.sh` (`{dispatch_file, model}`; `--seq` and
  `--dispatch-start-ts` are caller-minted).
- The **bare-vs-suffixed `session_id` invariant**: bare `$session_id` for `task-lock.sh acquire`,
  `orchestrate-batch-admit.sh --session-id`, and the implement dispatch's `--session`/agent
  `context.session_id`; `${session_id}_${task_num}` only for `skill_preflight_update` and the
  research/plan dispatches' `--session`/`context.session_id`.
- The full `mt_state_file` field list (~19 fields) that must be preserved byte-identically because
  Stage MT-5 still reads it.
- The decision that agent resolution happens inside the new script by sourcing
  `command-route-agent.sh` (design (a)), cached per task in `mt_state_file` to avoid mid-invocation
  routing drift, rather than depending on Stage MT-2's precomputed maps.
- The decision that `--dry-run` and the live path share one decision-computing code path and fork
  exactly at "would call `orchestrate-build-dispatch.sh` and its lock/mint/preflight/mkdir
  prerequisites".
- The complete retirement inventory for `orchestrate-dry-run-report.sh` (manifest, critical-paths
  registry, command call site, lint allowlist, plus descriptive doc cross-references).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context and no roadmap consultation was performed.
The task's own alignment anchor is `specs/PATH.md` Stage A.3 and its "The four moves per cycle"
section, which names this script as move 1 of 4.

## Goals & Non-Goals

**Goals**:
- One executable, `scripts/orchestrate-cycle-plan.sh`, performing (a) through (l) of the dispatch's
  WORK section in that order and printing exactly one JSON object
  `{cycle, dispatch, deferred, blocked, stop}` on stdout.
- Per-task `force_phases` consumption with canonical research-then-plan-then-implement ordering and
  per-task stop-after-last-named semantics.
- Task-directory creation (`mkdir -p` plus the `state.json` `path` write) whenever `path` is null or
  the directory is absent, ordered strictly before the `orchestrate-build-dispatch.sh` call.
- A `--dry-run` mode that runs the identical read-only analysis, mutates nothing, acquires no lock,
  and renders a human table derived from the emitted JSON object and nothing else.
- Retirement of `orchestrate-dry-run-report.sh`: file deleted, every call site and registry entry
  repointed, with the new script taking its slot in the orchestrator critical-path registry.
- Verbatim relay of each admission verdict's own `reason` string; the literals `runs solo only` and
  `re-run it alone` absent from the new script.
- SKILL.md's Stage MT-3 and MT-4-pre-dispatch region collapsed to one call plus a loop of at most
  ten lines, with the displaced prose relocated to `docs/architecture/orchestrate-state-machine.md`.

**Non-Goals**:
- Task 143's `orchestrate-cycle-postflight.sh` (everything from "After all Agent tool calls
  complete" onward) — out of scope, separately dispatched.
- Task 88's four-move engine rewrite. This task collapses the named region to the script call; the
  wholesale restructure of the loop around the four moves is not attempted here.
- Stage MT-1 (`mt_state_file` initialization), Stage MT-2 (routing table), and Stage MT-5
  (postflight/report) remain untouched and continue to run as they do today.
- The `team` field on dispatch rows and the `--team`/`--team-size` inputs: withdrawn by the
  2026-09-02 addendum. Team mode is deleted; no `team` key is emitted.
- Adding any user-facing prompt. The orchestrator never asks the user in this script — deferrals,
  budget exhaustion, and blockers stay autonomous, and the `--allow-*`/`--continue-budget` flags
  remain the pre-answer mechanism.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bare-vs-suffixed `session_id` invariant inverted while porting the per-task loops, desyncing `task-lock.sh heartbeat` from the acquired lock | H | M | Phase 4 carries the invariant as an explicit named contract in the script's doc header AND as a dedicated fixture assertion in Phase 7 (assert the exact string passed to lock acquire vs. preflight for both a research and an implement row) |
| Implementer duplicates the admission/classification computation across live and dry-run paths, recreating the "two renderings that drift apart" the addendum exists to remove | H | M | Phase 1 mandates the structural split: one function producing the whole decision set, a second that either renders the table (dry-run) or executes side effects (live). Phase 6 must add no new decision logic — only rendering |
| A forbidden literal (`runs solo only`, `re-run it alone`) or a reconstructed reason string reappears via copy-paste from the retired script | H | M | Phase 2 relays `.reason` verbatim with no string construction; Phase 7 adds a negative `grep` assertion over the whole new script for both literals, run in CI via `tests/run-all.sh` |
| A cross-reference to `orchestrate-dry-run-report.sh` survives deletion, leaving a dangling path in a doc or a lint allowlist | M | H | Phase 8 carries a Scope Hypothesis with the measured reference inventory and closes with a repo-wide `grep -rn orchestrate-dry-run-report` returning zero hits outside historical `specs/**` artifacts |
| An `mt_state_file` field is dropped or renamed during the port, silently breaking Stage MT-5's report | H | M | Phase 1 enumerates the field list in the script doc header from the report's inventory; Phase 10's live 3-task run diffs the post-run `mt_state_file` key set against a pre-change baseline capture |
| The live 3-task parity check diverges because `--invocation-count` is computed differently from the live path's per-cycle `${#eligible_tasks[@]}` | M | M | Phase 2 pins `--invocation-count` to this cycle's eligible-set size explicitly (the retired script's whole-validated-set count was one of the defects being retired); Phase 10 compares dispatch rows against pre-change engine decisions for identical state |
| SKILL.md collapse removes prose that a still-live stage (MT-1/MT-2/MT-5) depends on | M | M | Phase 9 relocates rather than deletes, and bounds the edit to the measured line region; the byte-removed report is computed as a diff of the region, not of the whole file |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7, 8 | 6 |
| 8 | 9 | 8 |
| 9 | 10 | 7, 9 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Script skeleton, CLI surface, and read-only analysis core [COMPLETED]

**Goal**: Create `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` with its doc
header, full flag surface, state loading, and WORK items (a) status refresh + session heartbeat,
(b) all-terminal check, and (c) eligibility — emitting a well-formed (if partly empty) plan JSON.

**Tasks**:
- [x] Create the file with `set -euo pipefail` and a doc header modeled on
      `scripts/orchestrate-stage5-gates.sh`: Purpose / Usage / Output field table / Exit codes.
- [x] Record in the doc header, as this script's durable home: the full `mt_state_file` field list
      it reads and mutates, and the bare-vs-suffixed `session_id` invariant (both currently exist
      only as scattered SKILL.md prose).
- [x] Parse the flag surface: `--session SID` and `--state-file F` (required), plus optional
      `--invocation-count N`, `--force-phases "..."`, `--clean`, `--lit`, `--hard`, `--fast`,
      `--model M`, `--allow-self-modifying`, `--allow-scope-collision`, `--continue-budget`,
      `--dry-run`, and positional task numbers. Reject `--team`/`--team-size` as unknown flags.
- [x] Implement WORK (a): re-read each task's status into `mt_state_file.current_statuses`;
      best-effort `task-lock.sh session-heartbeat "$session_id"` (bare form).
- [x] Implement WORK (b): all-terminal check over `{completed, abandoned, expanded}` plus
      `failed_tasks` and `deferred_deploy_checkpoint`. `deferred_self_modifying` is deliberately
      NOT part of this check — it is an observation log, not an exclusion set.
- [x] Implement WORK (c): eligibility per the dependency-gating model — not terminal/failed, not in
      `deferred_deploy_checkpoint`, all `dependency_graph` predecessors terminal-or-failed. A
      task's own status (including `researching`/`planning`) never removes it from eligibility;
      a failed predecessor yields a `blocked[]` row.
- [x] Implement the no-eligible circuit breaker as a `stop` object, not an exit code.
- [x] Establish the two-function structure the whole script hangs off: one function computing the
      complete decision set, a second consuming it. No side effects in the first.
- [x] Emit `{cycle, dispatch: [], deferred: [], blocked: [...], stop: ...}` via a single
      `jq -n -c` call as the sole stdout channel.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The flag surface is hypothesized to be exactly the eleven optional flags plus
two required ones listed above, with `--dry-run` added by the addendum and `--team`/`--team-size`
withdrawn. Confirm at implementation time by checking each flag is actually consumed by a later
phase's logic; a flag no phase reads is a spec error to report, not to silently retain.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - new file

**Verification**:
- `bash -n` and `shellcheck` clean on the new file.
- Invoked against a fixture `state.json` with all tasks terminal, prints a JSON object whose `stop`
  is non-null and whose `dispatch`/`deferred` are empty arrays.
- Invoked with a task whose predecessor is in `failed_tasks`, that task appears in `blocked[]`.
- `jq -e .` accepts the stdout of every invocation above.

---

### Phase 2: Classification, admission, and verbatim verdict relay [COMPLETED]

**Goal**: Add WORK (d) admission and (e) classification, with the four defer gates, their
consumer-side overrides, defer-not-fail semantics, the idle-overlap advisory, the convergence
guard, and the degradation path — relaying each verdict's own `reason` string verbatim.

**Tasks**:
- [x] Call `orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"`, capture the NDJSON once, and
      reuse the captured value everywhere downstream — never re-invoke.
- [x] On classifier exit 2, fall back to the inline Phase-grouping table applied per task; never
      abort the cycle.
- [x] Build `--phase-map` from the captured classification and call
      `orchestrate-batch-admit.sh --invocation-count <this cycle's eligible-set size>
      --session-id "$session_id" --phase-map ... "${eligible_tasks[@]}"` on every cycle including
      batch size 1. `--session-id` takes the BARE session id.
- [x] Branch on `.decision == "defer"` across `defer_reason` in
      `{self_modifying, file_scope_collision, session_active}`, each with its own override check
      (`--allow-self-modifying`; `--allow-scope-collision`, cross-batch only).
- [x] Every `deferred[]` row's `reason` is the verdict's own `.reason` field, passed through
      unmodified. Construct no reason strings. The designated-candidate tie-breaker is internal to
      the admission script — pass nothing extra for it.
- [x] Append to `defer_ledger`, `deferred_self_modifying`, and `idle_overlap_ledger` exactly as
      today. These observation logs are never read by any eligibility, admission, circuit-breaker,
      or convergence decision.
- [x] Evaluate the idle-overlap advisory on every verdict, independent of the defer filter.
- [x] Implement the convergence guard: increment `consecutive_no_dispatch_cycles`, produce a `stop`
      object after 3.
- [x] On admission exit 2 (state unavailable), log loudly to stderr and proceed WITHOUT the check —
      never abort.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add classification and
  admission stages

**Verification**:
- `bash -n` / `shellcheck` clean.
- Against a fixture with two self-modifying candidates, a `deferred[]` row's `reason` is
  byte-identical to the corresponding `orchestrate-batch-admit.sh` verdict's `.reason`.
- `grep -c 'runs solo only\|re-run it alone'` over the script returns 0.
- A fixture forcing admission exit 2 still prints a valid plan JSON with a loud stderr warning.

---

### Phase 3: Per-task forced phases, task-directory creation, and agent resolution [COMPLETED]

**Goal**: Add WORK (f) per-task `force_phases` consumption and (g) task-directory creation, plus
per-task agent-name resolution for the dispatch rows.

**Tasks**:
- [x] Split `--force-phases` on commas into an ordered queue validated against
      `{research, plan, implement}`; fail loudly on any other token (a corrupted delegation context,
      not a user typo).
- [x] Apply forced phases per task in canonical research-then-plan-then-implement order regardless
      of the typed order, tracking a per-task remaining-forced-phases pointer in `mt_state_file`.
- [x] Implement stop-after-last-named semantics per task: once a task's last named forced phase
      completes, that task stops being force-dispatched and falls through to ordinary
      status-derived classification on the next cycle. Never regress a task's status.
- [x] Implement WORK (g): when `state.json` has `path: null` or the directory is absent,
      `mkdir -p` the task directory and write the `path` field, following
      `skill_validate_input`'s precedent. This MUST happen before any
      `orchestrate-build-dispatch.sh` call for that task, which re-derives its description from
      `state.json` and needs the directory present.
- [x] Resolve the per-task `agent` field by SOURCING
      `.claude/scripts/command-route-agent.sh "$op" "$TASK_TYPE" "$default_agent" "${effort_flag:-}"`
      and reading `$AGENT_NAME`. Never execute it as a subprocess — it exports and never exits.
- [x] Cache each task's resolved agent in `mt_state_file` on first resolution rather than
      re-resolving every cycle, mirroring Stage MT-2's once-per-task intent and avoiding
      mid-invocation routing drift.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add force-phase, directory,
  and agent-resolution stages

**Verification**:
- `bash -n` / `shellcheck` clean.
- With `--force-phases "implement,research"` for one task among three, that task's first forced
  dispatch row carries `phase: research` (canonical order wins over typed order).
- A fixture task with `path: null` gains a created directory and a written `path` before the
  dispatch row is composed.
- Each dispatch row carries a non-empty `agent` value.

---

### Phase 4: Side-effect half — lock, dispatch_seq mint, preflight write, build-dispatch [COMPLETED]

**Goal**: Add WORK (h) lock acquire with stale-reclaim, (i) the atomic `dispatch_seq` +
`dispatch_start_ts` write, (j) the preflight status write, and (l) the per-row
`orchestrate-build-dispatch.sh` call, completing the live path's `dispatch[]` rows.

**Tasks**:
- [x] Call `task-lock.sh acquire "$task_num" "$op" "$session_id" "..."` with the BARE session id,
      including stale-reclaim. On refusal by a fresh foreign lock, remove the task from this
      cycle's batch and add a `deferred[]` row with a lock-contention reason — never add to
      `failed_tasks`, never emit a `blocked[]` row.
- [x] Mint `dispatch_seq` as an atomic read-modify-write incrementing
      `mt_state_file.dispatch_seq_counter`, recording both `dispatch_seq[$t]` and
      `dispatch_start_ts[$t]` in the SAME `jq` write.
- [x] Call `skill_preflight_update "$task_num" "$op" "${session_id}_${task_num}"` — the
      per-task-suffixed form, per the invariant.
- [x] Call `orchestrate-build-dispatch.sh "$task_num" "$phase" --session <per the invariant> --seq
      <minted> --dispatch-start-ts <stamped> [--clean] [--lit] [--hard] [--fast] [--model M]`,
      capturing `{dispatch_file, model}`.
- [x] Apply the session-id invariant at each call site: research and plan dispatches pass
      `${session_id}_${task_num}` as `--session`; implement dispatches pass the bare `$session_id`.
- [x] Populate `dispatch[]` rows as `{task, phase, agent, model, dispatch_file}`. Emit no `team`
      key.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add the side-effect half

**Verification**:
- `bash -n` / `shellcheck` clean.
- Against a two-task fixture with one task pre-locked under a different session id, that task is
  absent from `dispatch[]`, present in `deferred[]`, and absent from `blocked[]` and
  `failed_tasks`.
- `dispatch_seq` and `dispatch_start_ts` for a task appear in the same `mt_state_file` revision
  (assert by writing a marker and confirming a single write).
- A research row's `--session` argument is the suffixed form and an implement row's is the bare
  form (assert via a stubbed `orchestrate-build-dispatch.sh` recording its argv).

---

### Phase 5: Budget accounting, infra-failure counters, and the redeploy checkpoint [COMPLETED]

**Goal**: Add WORK (k): `MAX_CYCLES_MT` and `MAX_INFRA_FAILURES` accounting, `--continue-budget`
honoring, and the inter-cycle redeploy-checkpoint decision, all surfacing through the `stop` field.

**Tasks**:
- [x] Increment `cycle_count`; produce a `stop` object when `cycle_count >= MAX_CYCLES_MT` unless
      `--continue-budget` was passed.
- [x] Track `infra_failures` against `MAX_INFRA_FAILURES` and produce the corresponding `stop`
      object, honoring `--continue-budget` identically.
- [x] Every budget exhaustion produces an honest `stop.message` and never a user prompt.
- [x] Implement the inter-cycle redeploy checkpoint: expand
      `context/reference/orchestrator-critical-paths.json` against `cycle_modified_files`,
      idempotence-guard against `deployed_critical_paths`, run `verify-deploy.sh` before and after
      `deploy-headless.sh`, and record the three-way outcome (success / pre-existing-failure-proceed
      / new-failure-defer) via `deferred_deploy_checkpoint`, `deployed_critical_paths`, and
      `verify_deploy_baseline_notices`.
- [x] Keep loop control as DATA: the script sets `stop` and exits 0. It never decides
      halt-vs-continue on the caller's behalf and never signals loop control through an exit code.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add budget and checkpoint
  accounting

**Verification**:
- `bash -n` / `shellcheck` clean.
- A fixture at `cycle_count == MAX_CYCLES_MT` yields non-null `stop` with a budget reason and
  exit code 0.
- The same fixture with `--continue-budget` yields `stop: null`.
- A fixture whose `cycle_modified_files` touches a declared critical path but is already in
  `deployed_critical_paths` runs no deploy (idempotence guard holds).

---

### Phase 6: `--dry-run` mode and the human table [COMPLETED]

**Goal**: Add the `--dry-run` short-circuit and its compact human table, derived from the emitted
JSON object and nothing else.

**Tasks**:
- [x] Short-circuit immediately after the decision set is computed (admission, classification,
      forced phases, lock PROBE) and strictly before any side effect: no lock acquire, no
      `dispatch_seq` mint, no preflight status write, no directory creation, no
      `orchestrate-build-dispatch.sh` call, no `mt_state_file` mutation.
- [x] Emit the same plan JSON shape, with `dispatch[]` rows carrying `task`/`phase`/`agent` and
      `dispatch_file`/`model` as null.
- [x] Render the human table by reading back that JSON object only. Add no second computation and
      no independent formatting of any decision.
- [x] Choose and document the table's columns in the script doc header (the addendum fixes the
      derivation source, not the layout). Recommended: one section per bucket — dispatch
      (task, phase, agent), deferred (task, reason), blocked (task, reason) — plus the `stop` line.
- [x] Every deferred row prints the verdict's own `reason` string verbatim, including the
      admission script's ORDERING CONSTRAINT text naming the designated candidate when two or more
      self-modifying candidates are present.
- [x] Verify by inspection that neither `runs solo only` nor `re-run it alone` appears anywhere in
      the file.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add dry-run mode and table
  renderer

**Verification**:
- `bash -n` / `shellcheck` clean.
- A `--dry-run` invocation against a fixture leaves `mt_state_file`, `state.json`, and the `.lock/`
  directory byte-identical (compare checksums before and after).
- The rendered table's deferred reason text is a substring of the plan JSON's corresponding
  `deferred[].reason`.
- `grep -c 'runs solo only\|re-run it alone'` returns 0.

---

### Phase 7: Fixture tests [COMPLETED]

**Goal**: Add `scripts/tests/test-orchestrate-cycle-plan.sh` covering the four acceptance areas plus
the two named invariants, modeled on the two existing sibling test files.

**Tasks**:
- [x] Create the test file following `scripts/tests/test-orchestrate-build-dispatch.sh` and
      `scripts/tests/test-orchestrate-triage-classify.sh` in structure and fixture style.
- [x] Eligibility fixture: assert a task in `researching`/`planning` is still eligible
      (status never gates), and that a failed predecessor produces a `blocked[]` row.
- [x] Forced-phases fixture: `--force-phases "research,plan"` for one task among several; assert
      only that task's named phases are forced, canonical ordering is applied, and the task falls
      through to status-derived classification after its last named phase.
- [x] Verdict-relay fixture: 2+ self-modifying candidates; assert the `--dry-run` table's rendered
      defer reason matches the admission script's own `.reason` field, and that the ORDERING
      CONSTRAINT text naming the designated candidate is present.
- [x] Negative assertion in the same test: `grep` over the script for `runs solo only` and
      `re-run it alone` must return no matches.
- [x] Lock-refusal fixture: two tasks, one pre-locked under a different session id; assert it is
      absent from `dispatch[]`, present in `deferred[]`, and absent from `blocked[]`.
- [x] Session-id invariant fixture: with a stubbed `orchestrate-build-dispatch.sh` recording argv,
      assert research/plan rows use `${session_id}_${task_num}` and implement rows use the bare
      `$session_id`, and that `task-lock.sh acquire` receives the bare form.
- [x] Dry-run no-mutation fixture: checksums of `mt_state_file`, `state.json`, and `.lock/` are
      unchanged across a `--dry-run` invocation.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new file

**Verification**:
- The new test file passes standalone.
- `scripts/tests/run-all.sh` picks it up and remains green.

---

### Phase 8: Retire orchestrate-dry-run-report.sh and repoint every call site [COMPLETED]

**Goal**: Delete the retired script and update every reference so there is exactly one rendering of
every admission verdict.

**Tasks**:
- [x] Delete `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh`.
- [x] `manifest.json`: remove the `orchestrate-dry-run-report.sh` entry from `scripts`; add
      `orchestrate-cycle-plan.sh` in its alphabetical slot (between `orchestrate-build-dispatch.sh`
      and `orchestrate-loop-guard-init.sh`); add `tests/test-orchestrate-cycle-plan.sh` to the
      `tests` list alongside its two siblings.
- [x] `context/reference/orchestrator-critical-paths.json`: remove the
      `scripts/orchestrate-dry-run-report.sh` entry (label "admission report surface") and add
      `scripts/orchestrate-cycle-plan.sh` labeled for its widened role (cycle dispatch-plan composer:
      admission, classification, lock acquire, status writes, dispatch-seq mint).
- [x] `commands/orchestrate.md`: repoint the dry-run short-circuit's two `bash` lines to
      `orchestrate-cycle-plan.sh --dry-run [--session "$SESSION_ID"] --state-file specs/state.json
      $TASK_NUMBERS`. Leave the surrounding dry-run prohibition block's prose unchanged apart from
      the script name.
- [x] `scripts/lint/lint-task-lookup-adoption.sh`: remove `core/scripts/orchestrate-dry-run-report.sh`
      from the offender allowlist; add `core/scripts/orchestrate-cycle-plan.sh` only if the lint
      actually flags it, and prefer fixing the lookup shape over allowlisting.
- [x] Update the descriptive cross-references to name `orchestrate-cycle-plan.sh --dry-run`:
      `scripts/lib/common.sh`, `scripts/orchestrate-batch-admit.sh`,
      `scripts/orchestrate-triage-classify.sh`, `docs/architecture/batch-admit-schema.md`,
      `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/task-lock.md`.
      Historical narrative passages describing what the retired script once did may keep its name;
      forward-looking references to a live surface must be repointed.
- [x] Confirm no remaining live reference: `grep -rn orchestrate-dry-run-report` over the source
      store returns only historical narrative (or nothing).

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: interface

**Scope Hypothesis**: The reference inventory is hypothesized to be exactly these files, measured at
plan time: `manifest.json` (1 hit), `commands/orchestrate.md` (2 hits),
`scripts/lib/common.sh` (1), `scripts/orchestrate-batch-admit.sh` (1),
`scripts/orchestrate-triage-classify.sh` (2), `scripts/lint/lint-task-lookup-adoption.sh` (1),
`context/reference/orchestrator-critical-paths.json` (1),
`docs/architecture/batch-admit-schema.md` (9), `context/patterns/batch-orchestration-guardrails.md`
(4), `context/patterns/task-lock.md` (1). Confirm at implementation time by re-running
`grep -rn "orchestrate-dry-run-report" agent-system/extensions/core` before editing; treat any file
not on this list as a finding to report, and any listed file with a changed hit count as a signal
that the region moved.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - deleted
- `agent-system/extensions/core/manifest.json` - script and test registry entries
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` - registry swap
- `agent-system/extensions/core/commands/orchestrate.md` - dry-run short-circuit repoint
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - allowlist
- `agent-system/extensions/core/scripts/lib/common.sh` - comment cross-reference
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - header cross-reference
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - header cross-references
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - cross-references
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - cross-references
- `agent-system/extensions/core/context/patterns/task-lock.md` - cross-reference

**Verification**:
- `jq -e .` accepts both edited JSON files.
- `grep -rn "orchestrate-dry-run-report" agent-system/extensions/core` returns only historical
  narrative.
- `scripts/lint/lint-task-lookup-adoption.sh` exits 0.
- `/orchestrate --dry-run` short-circuit in `commands/orchestrate.md` names only the new script.

---

### Phase 9: Collapse SKILL.md and relocate the displaced prose [NOT STARTED]

**Goal**: Replace Stage MT-3 and MT-4's pre-dispatch half with one `orchestrate-cycle-plan.sh` call
plus a loop of at most ten lines, relocating the displaced prose to
`docs/architecture/orchestrate-state-machine.md`.

**Tasks**:
- [ ] Capture the byte size of the target region before editing (`sed -n` over the measured line
      range piped to `wc -c`) so the removal figure is a real diff, not an estimate.
- [ ] Replace Stage MT-3 steps 1-4.5 with a single call to `orchestrate-cycle-plan.sh` passing the
      session, state file, flags, and task numbers, and reading `stop`/`dispatch`/`deferred`/
      `blocked` from the returned JSON.
- [ ] Replace MT-4's pre-dispatch half with a loop of at most ten lines that composes the batched
      Agent-tool message from `dispatch[]` rows. Everything from "After all Agent tool calls
      complete" onward stays untouched (it belongs to the separate postflight script task).
- [ ] Relocate the displaced explanatory prose to
      `docs/architecture/orchestrate-state-machine.md`, which the lead never loads. Create the file
      if absent; otherwise append a clearly headed section.
- [ ] Leave Stage MT-1, MT-2, and MT-5 untouched; confirm every `mt_state_file` field they read is
      still written by the new script.
- [ ] Report bytes removed from SKILL.md (before-size minus after-size for the region, plus the
      whole-file delta).
- [ ] Reference durable anchors only (script names, stage names, section headings) in every edited
      deliverable — no task-number citations outside `specs/**`.

**Timing**: 1.5 hours

**Depends on**: 8

**Verification Tier**: interface

**Scope Hypothesis**: The collapsible region is hypothesized to be SKILL.md lines 2685-3132 (Stage
MT-3, 35,169 B) plus 3133-3358 (MT-4 pre-dispatch half, 18,688 B), 53,857 B total, against a
271,733 B file. Confirm at implementation time by re-locating the stage headings with
`grep -n '^### Stage MT-'` before editing — line numbers drift, headings do not — and by
re-measuring both regions; report the actual removed byte count, not this estimate.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - collapse MT-3 and MT-4's
  pre-dispatch half
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - relocated prose

**Verification**:
- `grep -n '^### Stage MT-'` still lists MT-1 through MT-5 in order.
- The MT-4 dispatch loop is at most ten lines.
- `scripts/lint/lint-postflight-boundary.sh` and `scripts/lint/lint-contract-compliance.sh` exit 0.
- Byte-removal figure recorded in the implementation summary.

---

### Phase 10: Live 3-task parity run and full gate set [NOT STARTED]

**Goal**: Demonstrate that the new script's dispatch rows match the decisions the pre-change engine
makes for the same state, and that the full gate set is green.

**Tasks**:
- [ ] Capture a pre-change baseline: for a real 3-task candidate set, record the decisions the
      pre-change engine would make (from the git-stashed or previous-commit SKILL.md path, or from
      the retired dry-run script's output captured before Phase 8 deletes it — capture this early
      if needed).
- [ ] Run `orchestrate-cycle-plan.sh --dry-run` over the same 3-task set and the same `state.json`.
- [ ] Compare dispatch rows task-by-task: same tasks, same phases, same agents; deferrals carry the
      same verdict reasons.
- [ ] Diff the post-run `mt_state_file` key set against the pre-change baseline key set; every
      field Stage MT-5 reads must still be present.
- [ ] Run the full gate set: `bash -n` and `shellcheck` on all changed shell files,
      `scripts/tests/run-all.sh`, every `scripts/lint/*.sh`, and `verify-deploy.sh`.
- [ ] Deploy the source store and re-run `verify-deploy.sh` to confirm the new script lands in
      `.claude/scripts/` and the retired one is gone.
- [ ] Record in the implementation summary: parity result, bytes removed from SKILL.md, and gate
      outcomes.

**Timing**: 1.5 hours

**Depends on**: 7, 9

**Verification Tier**: full

**Files to modify**:
- none (validation phase; findings recorded in the summary artifact)

**Verification**:
- Dispatch rows match the pre-change baseline for the same state, with any divergence explained.
- `scripts/tests/run-all.sh` green.
- Every `scripts/lint/*.sh` exits 0.
- `verify-deploy.sh` exits 0 both before and after `deploy-headless.sh`.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean on `orchestrate-cycle-plan.sh` and every edited shell file.
- [ ] `scripts/tests/test-orchestrate-cycle-plan.sh` passes standalone and under
      `scripts/tests/run-all.sh`.
- [ ] Eligibility fixture: status never gates; a failed predecessor blocks.
- [ ] Forced-phases fixture: canonical ordering, per-task stop-after-last-named, fall-through.
- [ ] Verdict-relay fixture: reason strings byte-identical to the admission script's own; ORDERING
      CONSTRAINT text present for 2+ self-modifying candidates.
- [ ] Forbidden-literal negative assertion: `runs solo only` and `re-run it alone` absent.
- [ ] Lock-refusal fixture: refused task in `deferred[]`, not `dispatch[]`, not `blocked[]`, not
      `failed_tasks`.
- [ ] Session-id invariant fixture: bare form for lock acquire, admission, and implement dispatch;
      suffixed form for preflight and research/plan dispatch.
- [ ] Dry-run no-mutation fixture: state, mt-state, and lock directory unchanged.
- [ ] Live 3-task parity run against the pre-change engine's decisions for identical state.
- [ ] `jq -e .` accepts every JSON emission and every edited JSON file.
- [ ] Every `scripts/lint/*.sh` exits 0.
- [ ] `verify-deploy.sh` exits 0 before and after deploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (new)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (new or extended)
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` (deleted)
- Edits to `manifest.json`, `context/reference/orchestrator-critical-paths.json`,
  `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
  `scripts/lint/lint-task-lookup-adoption.sh`, `scripts/lib/common.sh`,
  `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-triage-classify.sh`,
  `docs/architecture/batch-admit-schema.md`,
  `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/task-lock.md`
- `specs/147_build_orchestrate_cycle_plan/summaries/01_orchestrate-cycle-plan-script-summary.md`

## Rollback/Contingency

All edits are confined to the source store (`agent-system/extensions/core/`), which is under
version control; `.claude/` is a regenerable deploy artifact and is never hand-edited. Rollback is
a git revert of the task's commits followed by `deploy-headless.sh` to regenerate `.claude/`.

Partial-failure contingency, in order of preference:
1. If the SKILL.md collapse (Phase 9) fails verification, revert only that phase's commit. The new
   script and its tests stand alone and are already registered; the engine simply continues using
   its inline path until the collapse is retried.
2. If the dry-run retirement (Phase 8) must be undone, restore
   `orchestrate-dry-run-report.sh` from git and revert the registry/call-site edits. The new
   script's `--dry-run` mode is additive and can coexist temporarily, at the cost of the
   two-renderings drift the addendum exists to remove — acceptable only as a transient state.
3. If the live parity run (Phase 10) shows divergence, do not revert: record the divergence, treat
   it as a defect in the phase that introduced it, and fix forward, since the baseline capture makes
   the delta diagnosable.
