# Implementation Plan: Task #119

- **Task**: 119 - Migrate hard-mode state-machine logic (H1 phase-per-cycle, H5/H6 churn/three-strikes, burnout breaker) into skill-orchestrate
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: Task 117 (completed), Task 118 (completed)
- **Research Inputs**: specs/119_migrate_hard_mode_state_machine_logic/reports/01_state-machine-migration-design.md
- **Artifacts**: plans/01_state-machine-migration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the four genuinely stateful hard-mode residues out of
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` and into
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` as `if [ "$hard_mode" = "true" ]`
conditional branches: (1) Stage 2 loop-guard/churn-state initialization plus the conditional
`MAX_CYCLES`, (2) the burnout circuit-breaker gate in Stage 3, (3) per-target churn counters with
the three-strikes divergence-audit dispatch, and (4) the H1 single-blocking-phase-per-cycle
implement limiter. The source (`-hard`) file is READ-ONLY for this task — it is deleted by
separate downstream work, and the 7 tests/lints that assert against it are retargeted by separate
downstream work. Definition of done: `skill-orchestrate/SKILL.md` reproduces all four behaviors
behind `$hard_mode`, the existing test suite still passes unmodified, and every scope decision
below is recorded in-file.

### Research Integration

The research report pins each of the four targets to exact source line ranges and confirms the
prerequisite work (the `hard_mode` boolean at Stage 1/MT-1, unified agent routing at Stage 1b,
and the Stage 3.5 `hard_contracts_block` contract-text injection) is already landed. Findings
carried directly into phases below:

- `hard_mode` already exists and is threaded through both single-task and multi-task entry
  points; no new derivation is needed. Every branch below reads the existing variable.
- Stage 3.5's `implement` contract list is already a strict superset of the contract references
  inside `build_hard_mode_prompt_context()`, and its `territory` input is already declared as
  "optional; no call site sets this today" — the H1 branch becomes its first caller.
- Base Stage 5 already carries a marker/handoff crosscheck; the H1 handler's own crosscheck is
  pre-dispatch (refusing) rather than post-dispatch (repairing), so both are kept.

Two verification findings made during planning extend the report:

- **`phases_completed_before` / `phases_completed_after` are undefined in BOTH files today.**
  `grep` finds exactly one occurrence across the pair — the consumer at hard-file line 1091. The
  hard engine's Stage 4b churn signature therefore reads unset variables. This is repaired as
  part of the migration (Decision D7), which also fixes the stage ordering.
- **Base Stage 5a Drift Inspection is documented base-mode-only but is not gated.** The base
  file's own Stage 2 comment says hard mode "has no Stage 5a Drift Inspection equivalent (its own
  H5 divergence-audit mechanism plays that role instead)", yet the drift constants and the stage
  run unconditionally. Once one engine serves both modes, Stage 5a and the new Stage 5b are
  mutually exclusive and must be gated as such (Phase 6).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Reproduce all four WORK-list behaviors in `skill-orchestrate/SKILL.md` behind `$hard_mode`.
- Keep one loop-guard JSON schema across both modes rather than forking it.
- Repair the `phases_completed_before`/`_after` gap the source engine never closed.
- Record every scope decision — especially the H4 question — in-file, so downstream deletion work
  cannot silently drop an unmigrated residue.
- Leave the existing test/lint suite passing without editing any test.

**Non-Goals**:
- Editing, deleting, or reformatting `skill-orchestrate-hard/SKILL.md` (downstream deletion work).
- Retargeting the 7 tests/lints that assert against the `-hard` file (downstream retarget work).
- Re-doing Stage 3.5's `hard_contracts_block` contract-text injection (already landed).
- Migrating the H4 adversarial-verification gate — see Decision D1.
- Extending the `loop-guard-staleness` detector to base mode — see Decision D4.
- Any change to `.claude/**` by hand: the source store is the only edit target.

## Decisions (resolve the report's two flagged items, plus five carried forward)

**D1 — H4 adversarial verification is OUT OF SCOPE for this task, deliberately and on record.**
Rationale, in order of weight:
1. The task's WORK list enumerates four items; H4 is not among them.
2. H4's contract-TEXT half already landed with the prerequisite work — `adversarial-verification.md`
   is already in Stage 3.5's `research` `core_contracts` list in the base file. What remains
   unmigrated is only its *gate*.
3. That remaining gate is structurally a fifth, independent residue: it lives in a different state
   handler (`#### State: researched`), owns its own `adversarial_verified` state variable set at
   three separate sites, and implements a verify-then-re-dispatch loop with a report-content grep.
   It is not a variant of any of the four items, so folding it in would roughly double this task's
   largest phase without a design pass.
4. Migrating it uncosted would put an unplanned re-dispatch loop into the shared engine's
   `researched` handler, which base mode reaches on every task.

**Consequence that MUST be recorded in-file (Phase 1):** completing this task does NOT by itself
satisfy the "all state-machine residue migrated" precondition for deleting the `-hard` file. H4's
gate is a named, still-unmigrated residue. Phase 1 writes this as an explicit note in
`skill-orchestrate/SKILL.md` next to the Stage 1 `hard_mode` derivation comment, using durable
anchors only (skill/stage/handler names, never task numbers, since the file is a deliverable
outside `specs/**`).

**D2 — Do not renumber Stage 3's lettered sub-steps.** The report flagged renumbering as a
cross-reference risk. Verified by grep: `3a.`/`3b.`/`3c.` occur at exactly three sites in the base
file (the three defining sub-step headings at lines 301, 310, 340), with no forward references
elsewhere. Renumbering would therefore be *safe* — but it is still gratuitous churn, so the
report's low-churn recommendation is adopted: insert the burnout gate as a new labeled sub-step
**`3b-hard.`** between `3b.` and `3c.`, leaving `**3c. Dispatch by state**` byte-identical.

**D3 — One loop-guard JSON schema, not two.** Write `hard_mode`, `burnout_signals_this_session`,
and `plan_version` into the guard in BOTH modes (`$hard_mode` / `0` / `$current_plan_version`),
with `// false`, `// 0`, `// "none"` forward-compatible reads. A guard written before these fields
existed still resumes correctly, and downstream readers face one schema rather than a per-mode
fork. `plan_version` is included in both modes because the staleness detector's Signal 2 reads it
and computing it in base mode is a single cheap `ls | sort -V | tail -1`.

**D4 — The `loop-guard-staleness` 3-signal detector stays strictly `$hard_mode`-gated.** Both
files already carry a matching "Asymmetry decision" note saying whether base mode should gain the
detector unconditionally is a separate, undecided question. This migration does not decide it.
Phase 3 updates the base file's existing note so it says the detector now exists *behind the hard
gate* rather than being absent — the asymmetry question itself stays open and recorded.

**D5 — Fork the whole `#### State: planned or implementing` handler body.** A single top-level
`if [ "$hard_mode" = "true" ]; then <H1 handler> else <existing whole-plan handler> fi`, not
`$hard_mode` checks threaded through H1's internal branches. The two bodies are structurally
different implementations of the same state, not decorated variants of one body.

**D6 — Resolve the `build_hard_mode_prompt_context()` overlap by trimming, not duplicating.**
Verified: Stage 3.5's `implement` `core_contracts` resolve to `anti-analysis.md`, `wrap-up.md`,
`territory.md` (when `territory` is non-empty), `recovery.md`, `phase-closure.md`,
`pre-edit-gate.md` — a strict superset of the three contract files
`build_hard_mode_prompt_context()` names (anti-analysis, wrap-up, recovery). Port only the
non-duplicated residue as a small `phase_mission_block`: the phase-only mission line, the
settled-design preamble instruction (which has no contract file of its own), and the
`PHASES COMPLETED: n of m` line. Set the `territory` variable before invoking Stage 3.5 so
`territory.md` is picked up by the existing mechanism rather than re-listed by hand.

**D7 — Define `phases_completed_before` / `phases_completed_after`, and correct the stage
ordering.** These are referenced by the source engine's churn signature but set by no stage in
either file. Repair: capture `phases_completed_before` from the handoff inside the H1 branch
immediately before the dispatch (the branch already reads `phases_completed` there), and treat
base Stage 5's already-assigned `phases_completed` as `phases_completed_after`. This forces the
churn check to run *after* Stage 5's handoff read, not before it as the source file's own heading
order implies — hence the new stage lands as **Stage 5b**, after Stage 5a, not as a "Stage 4b".

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `test-handoff-reader-parity.sh` compares base and hard Stage 5 blocks and allowlists `.blockers[0].verbatim_goal` as a hard-only difference; the new churn block also reads `verbatim_goal` | H | M | Place Stage 5b strictly OUTSIDE the Stage 5 region the test extracts (after Stage 5a). Run the test in Phase 6; if it flags, fix by moving the block, never by editing the test |
| `test-loop-guard-budget-override.sh` reads BOTH files and makes differential assertions about the base resume-read block | H | M | Phase 2 changes the base resume block; run this test at the end of Phase 2 before proceeding |
| Renumbering / cross-reference drift in Stage 3 | M | L | D2: no renumbering; `3c.` stays byte-identical |
| Sentinel-marker collisions (`loop-guard-staleness:*`, `resume-scan-conformance-gate:*`) once a second copy exists in the base file | M | M | Verified: `test-loop-guard-staleness.sh` scans only the hard file, and `test-resume-scan-nonconformance.sh`'s site list is implementer-hard / orchestrate-hard / lean-implementation-hard / `update-task-status.sh` — base orchestrate is in neither. Confirm with a fresh run in Phase 7 |
| Single-file territory: all seven phases edit one 3,101-line file | M | H | Phases declared strictly sequential (see Dependency Analysis note) so no two dispatches can hold the file at once |
| Editing the deployed `.claude/**` copy instead of the source store | H | L | Every phase names the source-store path explicitly; Phase 7 verifies no `.claude/**` file was hand-edited |
| Task-number references leaking into a deliverable outside `specs/**` | M | M | Phase 7 runs the repo-wide task-reference lint; all in-file notes cite skill/stage/handler names |
| H4 silently lost when the `-hard` file is later deleted | H | M | D1 + Phase 1's in-file residue note |

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
| 7 | 7 | 6 |

Phases within the same wave can execute in parallel. **This plan is deliberately fully
sequential**: every phase edits the same file
(`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`), so the true dependency is
territory exclusivity, not just data flow. Phases 3, 4, and 5 have no data dependency on each
other and could in principle be reordered, but they must never be dispatched concurrently.

---

### Phase 1: Record scope decisions and verify preconditions [COMPLETED]

**Goal**: Close the two items the research report escalated (H4 scope, Stage 3 renumbering) with
recorded decisions, confirm every helper the later phases depend on actually exists, and write the
H4 residue note into the target file so downstream deletion work cannot drop it silently.

**Tasks**:
- [x] Confirm the `-hard` file is untouched in the working tree, and that no other dispatch holds
      `skill-orchestrate/SKILL.md` (`git status --short` on both paths). *(completed)*
- [x] Re-verify D2's grep evidence: `3a.`/`3b.`/`3c.` occur only at their three defining sub-step
      headings in the base file, with no forward references. *(completed)*
- [x] Re-verify that `skill_orchestrate_propagate_completion`, `skill_orchestrate_mint_dispatch_seq`,
      and `skill_gate_completion_claim` exist in `agent-system/extensions/core/scripts/skill-base.sh`
      (Phase 5 calls the first two). *(completed)*
- [x] Re-verify Stage 3.5's `territory` input row still reads "optional; no call site sets this
      today" — Phase 5 changes that statement of fact and must update the row. *(completed)*
- [x] Add a `**Hard-mode residue not yet migrated**` note in `skill-orchestrate/SKILL.md`
      immediately after the Stage 1 `hard_mode` derivation comment, naming the H4
      adversarial-verification gate in the `-hard` engine's `#### State: researched` handler and
      its `adversarial_verified` variable as the one state-machine residue this engine does NOT
      yet reproduce. Use durable anchors only — no task numbers. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts `3a.`/`3b.`/`3c.` appear at exactly 3 sites in the base
file and that 3 named helpers exist in `skill-base.sh`. Both were measured at plan time; confirm
with `grep -n` and `grep -n '^skill_'` before relying on them, and report any drift rather than
proceeding on the plan-time number.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — add the H4 residue note near
  the Stage 1 `hard_mode` derivation.

**Verification**:
- The residue note is present, names H4 by mechanism and handler, and contains no task number.
- All four precondition greps produce the expected results, recorded in the phase's commit or
  progress notes.

---

### Phase 2: Stage 2 — conditional `MAX_CYCLES` and unified loop-guard schema [COMPLETED]

**Goal**: Make the cycle budget mode-aware and extend the loop-guard JSON to one schema serving
both modes, so later phases have `burnout_signals_this_session` and `plan_version` in scope.

**Tasks**:
- [x] Replace the bare `MAX_CYCLES=5` at the top of Stage 2 with an `if [ "$hard_mode" = "true" ]`
      branch selecting `13` vs `5`, carrying over the source engine's inline rationale (per-phase
      dispatch needs roughly one cycle per phase). Keep it strictly before the
      `orchestrate-loop-guard-init.sh` call, which takes no `MAX_CYCLES` argument. *(completed)*
- [x] Add the `current_plan_version` computation (`ls -1 "${TASK_DIR}/plans/"*.md | sort -V | tail -1`,
      `basename`, `:-none` fallback) with its "absent plans/ is never evidence of staleness"
      comment, before the guard is read. *(completed)*
- [x] Add `"hard_mode": $hard_mode_json`, `"burnout_signals_this_session": 0`, and
      `"plan_version": $plan_version` to the fresh-init `jq -n` literal (D3). *(completed)*
- [x] Add `burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' ...)` to BOTH
      resume paths — the main `if [ -f "$loop_guard_file" ]` branch and the lost-init-race `else`
      branch — alongside the existing `cycle_count`/`infra_failures`/`detected_defects`/
      `dispatch_seq_counter` reads. *(completed)*
- [x] Extend both resume echo lines to report burnout signals only when `hard_mode` is true, so
      base-mode output is unchanged. *(completed)*
- [x] Set `burnout_signals_this_session=0` in the fresh-init success path alongside the other
      counter resets. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 2 head, fresh-init
  `jq -n` literal, both resume branches.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` passes
  (this test makes differential assertions about the base resume-read block and must be run here,
  not deferred).
- `bash agent-system/extensions/core/scripts/tests/test-session-runtime-files.sh` passes,
  confirming Case 3's cumulative-`cycle_count` semantics are undisturbed.
- Base-mode console output from Stage 2 is unchanged (no burnout text when `hard_mode=false`).

---

### Phase 3: Stage 2 — `loop-guard-staleness` detector and churn-state init [COMPLETED]

**Goal**: Port the 3-signal operational-staleness detector and the churn-state file
initialization into Stage 2 as `$hard_mode`-gated regions, positioned so the existing
`budget-continuation-override` and resume blocks are left completely unmodified.

**Tasks**:
- [x] Add `churn_file="${TASK_DIR}/.orchestrator-churn-state.json"` inside a `$hard_mode` branch
      near the `loop_guard_file`/`handoff_file` assignments. *(completed)*
- [x] Insert the `loop-guard-staleness:begin` / `:end` sentinel region, wrapped in
      `if [ "$hard_mode" = "true" ]`, positioned strictly BEFORE the existing
      `budget-continuation-override:begin` marker and before the `if [ -f "$loop_guard_file" ]`
      resume branch. Port all three signals verbatim in behavior: `max_cycles` drift,
      `plan_version` drift (skipped when either side is empty or `none`), and the
      `ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` mtime backstop (default 7, `mtime == 0` is NOT stale). *(completed)*
- [x] Port the archive-and-fall-through behavior: `mv` the guard to
      `.stale-loop-guard-{ts}.json`, co-archive `$churn_file` to `.stale-churn-state-{ts}.json`
      under the guard's inherited verdict when it exists, and warn (never fail) when either `mv`
      fails. The region must only read, decide, and `mv` — no `task-lock.sh` dependency, so it
      stays directly executable in a fixture harness. *(completed)*
- [x] Change the log prefix from `[hard-orchestrate]` to `[orchestrate]` throughout the ported
      region, matching the host file's convention. *(completed)*
- [x] Add the `$hard_mode`-gated churn-state init/resume block after `mint_dispatch_seq()`:
      `task-lock.sh init-marker` atomic creation with the
      `{session_id, total_churn, target_churn, adversarial_triggers, audit_dispatches}` schema, the
      lost-race `total_churn` resume read, and the non-gating `session_id` mismatch INFO log. *(completed)*
- [x] Update the base file's existing "Asymmetry decision" note at the end of Stage 2 so it states
      the detector now exists behind the hard gate and that whether base mode should gain it
      unconditionally remains a separate, undecided question (D4). *(completed)*
- [x] Update the Stage 2 ephemerality note to cover `.orchestrator-churn-state.json` as a second
      ephemeral, gitignored, never-committed runtime file. *(completed)*
- [x] Confirm `.orchestrator-churn-state.json` and `.stale-*` archives are already covered by
      gitignore; if not, add coverage. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 2 staleness region,
  churn init, asymmetry note, ephemerality note.
- `.gitignore` (only if churn-state / stale-archive coverage is found missing).

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` still passes
  (it scans only the `-hard` file; a pass confirms no accidental edit there).
- `bash agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` still
  passes — the `budget-continuation-override` region must be byte-identical to before this phase.
- Exactly one `loop-guard-staleness:begin`/`:end` pair exists in the base file.
- A base-mode dry read of Stage 2 shows the detector and churn init entirely skipped.

---

### Phase 4: Stage 3 — burnout circuit-breaker gate as sub-step `3b-hard` [COMPLETED]

**Goal**: Add the mandatory per-iteration burnout gate between `3b. Update loop guard` and
`3c. Dispatch by state` without renumbering either.

**Tasks**:
- [x] Insert a new sub-step heading `**3b-hard. Burnout circuit-breaker gate (hard mode only)**`
      immediately after the `3b.` code fence and immediately before `**3c. Dispatch by state**`,
      leaving the `3c.` line byte-identical (D2). *(completed)*
- [x] Port the three MANDATORY self-checks verbatim in substance, sourced from
      `context/contracts/orchestrator-discipline.md`: re-read-without-new-information,
      second-consecutive-reasoning-turn, and reverse-a-decision-without-a-fresh-dispatch. State
      explicitly that the gate runs every loop iteration when `hard_mode` is true and is skipped
      entirely otherwise. *(completed)*
- [x] Port the counter increment: bump `burnout_signals_this_session` and write it back with
      `last_updated` in a `3b`-style atomic tmp-mv `jq` write against `$loop_guard_file`, with the
      `[orchestrate]` log line. *(completed)*
- [x] Preserve the "no new artifact type" note: the forced dispatch reuses the divergence-audit
      dispatch shape (added in Phase 6) and the forced escalation reuses Stage 6 directly. Point at
      Stage 5b and Stage 6 by name. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 3, between `3b.` and
  `3c.`.

**Verification**:
- `grep -n '3c\. Dispatch by state'` returns the same single line, textually unchanged.
- The gate reads `burnout_signals_this_session`, which Phase 2 put in scope.
- Base mode reaches `3c.` with no added behavior.

---

### Phase 5: Stage 4 — H1 single-blocking-phase-per-cycle dispatch fork [COMPLETED]

**Goal**: Fork `#### State: planned or implementing` on `$hard_mode`, with the hard branch
dispatching exactly one OPEN phase per cycle and the base branch preserved unchanged.

**Tasks**:
- [x] Wrap the entire existing handler body in `if [ "$hard_mode" = "true" ]; then <H1> else
      <existing whole-plan body> fi` (D5), leaving the base body's text untouched inside the
      `else`. *(completed)*
- [x] In the hard branch, read `phases_completed` / `phases_total` / `skeleton` from the handoff
      (defaulting to `0`/`0`/`false` when absent), and set
      `phases_completed_before="$phases_completed"` for Stage 5b (D7). *(completed)*
- [x] Port the heading-scan phase selection: source
      `.claude/scripts/lib/phase-heading-patterns.sh`, run `has_nonconforming_phase_headings` over
      the WHOLE plan file FIRST (the ordering obligation), `warn_nonconforming` + set
      `phase_scan_inconclusive` on a hit, otherwise grep the first OPEN heading and extract its
      number via `extract_phase_number`. Include the `resume-scan-conformance-gate:begin`/`:end`
      sentinels and the "the `| grep -q .` pipe form is forbidden under pipefail" note. *(completed)*
- [x] Port the four-way branch in order: (a) `phase_scan_inconclusive` -> `EXIT (partial, ...)`
      using this file's existing terminal-condition convention, never a raw `exit 1`;
      (b) `-n "$next_phase"` -> pre-dispatch marker/handoff crosscheck then dispatch;
      (c) `last_skeleton = true` -> skeleton-exhaustion routing; (d) trailing `else` -> no
      dispatch, defer to the Stage 5 completion gate. *(completed)*
- [x] In branch (b), port the pre-dispatch marker/handoff crosscheck (compare
      `PHASE_HEADING_DONE_ERE` count against the handoff's `phases_completed`; on a mismatch where
      the plan claims more, downgrade the disputed heading to `[PARTIAL]` and `EXIT (partial, ...)`).
      Add a comment distinguishing it from base Stage 5's existing crosscheck: this one is
      pre-dispatch and dispatch-REFUSING; Stage 5's is post-dispatch and diagnostic-and-downgrading.
      Both are retained. *(completed)*
- [x] In branch (b), mint `dispatch_seq`, then build the hard `dispatch_context` adding
      `phase_number` and the `territory` object (`owned_files` pointing at the phase's own "Files
      to modify" list, empty `read_only_files`/`forbidden_files`, and the predecessor-wake
      `concurrency_note`). Carry the source engine's rationale that this documents intra-task
      predecessor hazards, not exclusive access. *(completed)*
- [x] Set the `territory` variable before running Stage 3.5 so `territory.md` is added to
      `core_contracts` by the existing mechanism (D6), and update Stage 3.5's `territory` input-table
      row, which currently says no call site sets it. *(completed)*
- [x] Add `build_hard_mode_phase_mission()` producing only the non-duplicated residue (D6): the
      "implement phase N only, do not continue past this phase" mission line, the settled-design
      preamble instruction, and `PHASES COMPLETED: n of m`. Do NOT restate anti-analysis, wrap-up,
      recovery, phase-closure, or pre-edit-gate — Stage 3.5's `hard_contracts_block` already
      injects them. Append it to the dispatch prompt before the Stage 3.5 blocks. *(completed)*
- [x] Keep `skill_preflight_update` inside branch (b) ONLY, never in (c) or (d), with the source
      engine's comment explaining why no per-phase marker is written here. *(completed)*
- [x] Port the skeleton-exhaustion branch: derive follow-ups from
      `sorry_inventory[].follow_up_task`, call
      `update-task-status.sh postflight ... pr_ready ... --allow-pr-ready` with the
      postflight-mapping rationale, call `skill_orchestrate_propagate_completion` via a local
      named shim, `rm -f "$loop_guard_file"`, and `EXIT (success, ...)`. *(completed)*
- [x] Set `dispatch_start_ts` / `dispatch_was_transport_error` in the dispatch branch exactly as
      the base body does, and change all `[hard-orchestrate]` log prefixes to `[orchestrate]`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: The H1 handler is estimated at roughly 220 source lines plus a ~13-line
prompt helper, and the migration is expected to add roughly that much to the base file minus the
contract-reference text trimmed under D6. Confirm the actual source extent with
`grep -n 'Per-Phase Dispatch (H1)'` and a `wc -l` over the extracted range before porting; report
the real figure rather than assuming the plan-time estimate.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `#### State: planned or
  implementing` handler; Stage 3.5 `territory` input-table row.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` passes
  (its site list does not include base orchestrate; a pass confirms no collateral damage).
- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh` and
  `test-handoff-dispatch-identity.sh` pass.
- Base-mode path through the handler is textually identical to the pre-phase version (verify with
  a diff of the `else` body against the original).
- The dispatch prompt contains no duplicated contract reference: each of anti-analysis, wrap-up,
  recovery, phase-closure, pre-edit-gate, territory appears exactly once, via
  `hard_contracts_block`.

---

### Phase 6: Stage 5b — churn detection (H6), three-strikes audit (H5), and Stage 5a gating [COMPLETED]

**Goal**: Add per-target churn counters and the three-strikes divergence-audit dispatch as a new
hard-only stage positioned after Stage 5's handoff read, and make it mutually exclusive with base
mode's Stage 5a drift inspection.

**Tasks**:
- [x] Add `### Stage 5b: Churn Detection (H6) and Three-Strikes Audit Dispatch (H5) — hard mode
      only`, placed AFTER Stage 5a Drift Inspection and before Stage 6, wrapped in
      `if [ "$hard_mode" = "true" ]`. Placement is load-bearing twice over: it must be after
      Stage 5's `phases_completed` assignment (D7) and strictly outside the Stage 5 region
      `test-handoff-reader-parity.sh` extracts. *(completed)*
- [x] Set `phases_completed_after="$phases_completed"` from Stage 5's already-assigned value and
      compute `phases_delta` against `phases_completed_before` from Phase 5 (D7). Add a comment
      recording that these two variables were referenced-but-never-set in the source engine and
      that this migration defines them. *(completed)*
- [x] Port the churn signature: `handoff_status == "partial"` AND `blockers | length > 0` AND
      `phases_delta -eq 0`. Guard against an unset `phases_completed_before` (a cycle where the H1
      branch did not run) by skipping the check rather than computing a false delta. *(completed)*
- [x] On a signature: increment `target_churn[blocker_target]` and `total_churn` in `$churn_file`
      via atomic tmp-mv `jq`, and log the H6 detection line with `[orchestrate]`. *(completed)*
- [x] On `new_target_churn >= 3`: log the H5 three-strikes line, read
      `blockers[0].verbatim_goal`, and dispatch `$RESEARCH_AGENT` with the DIVERGENCE AUDIT prompt
      (target, verbatim goal, explicit "failed 3 times" framing, request for a divergence table,
      postmortem, and corrected target definition) and `delegation_context` carrying
      `orchestrator_mode: false` with NO `handoff_path` — preserving the source engine's comment
      citing the research agents' Stage 3.6 Scoping Decision for why research agents never write
      the handoff. *(completed)*
- [x] After the audit dispatch: reset `target_churn[blocker_target]` to 0, increment
      `audit_dispatches`, increment `cycle_count`, and let the loop continue.
      *(deviation: altered — `cycle_count` is NOT incremented a second time inside this branch.
      Stage 5b is positioned strictly after Stage 5's own tail, which already charges the cycle
      exactly once per D7's ordering fix; the source engine's ambiguous Stage 4b/Stage 5 ordering
      is exactly what made a literal second increment look correct there. A second increment here
      would double-charge the cycle budget. `audit_dispatches`/`target_churn` reset and the
      "loop continues" framing are otherwise ported verbatim.)*
- [x] Gate Stage 5a Drift Inspection (and its Stage 2 drift constants
      `drift_inspection_count` / `MAX_DRIFT_INSPECTIONS` / the two thresholds) to base mode only,
      with a decision record stating Stage 5a and Stage 5b are mutually exclusive: H5's divergence
      audit plays the drift-inspection role in hard mode. The Stage 2 comment already asserts this
      asymmetry; this makes it executable. *(completed)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — new Stage 5b; Stage 5a hard
  gate; Stage 2 drift constants gate.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` passes. If it
  flags a new base/hard divergence, fix by relocating Stage 5b further outside the extracted
  region — never by editing the test (retargeting is downstream work).
- `bash agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` and
  `test-validate-handoff.sh` pass.
- Exactly one of Stage 5a / Stage 5b is reachable for any given `hard_mode` value.
- `phases_completed_before` and `phases_completed_after` each have exactly one assignment site and
  at least one reader.

---

### Phase 7: Full verification, deploy sync, and residue documentation [NOT STARTED]

**Goal**: Prove the migration is complete and non-regressive against the whole suite, confirm the
source-store/deploy boundary was respected, and leave the acceptance checklist recorded.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and record the result.
      Every failure must be triaged as caused-by-this-migration (fix here) or pre-existing
      (record, do not fix).
- [ ] Explicitly re-run the 7 tests/lints named as downstream-retarget scope
      (`test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`,
      `test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`,
      `test-handoff-dispatch-identity.sh`, `test-resume-scan-nonconformance.sh`,
      `lint/lint-contract-compliance.sh`) and confirm all pass WITHOUT any test file having been
      edited by this task (`git status --short` over the test directories must be clean).
- [ ] Confirm `git diff --stat` shows `skill-orchestrate-hard/SKILL.md` completely unmodified.
- [ ] Confirm no file under `.claude/**` was hand-edited; if the repo's flow requires a deploy to
      refresh `.claude/`, run the sanctioned deploy/reload rather than editing in place.
- [ ] Run the repo-wide task-reference lint (`scripts/check-task-references.sh` or equivalent) and
      confirm zero task-number references were introduced outside `specs/**`.
- [ ] Add a short acceptance-checklist note near the top of `skill-orchestrate/SKILL.md`'s
      hard-mode discussion mapping each migrated behavior (cycle budget, per-phase implement
      dispatch, churn counters, three-strikes audit, burnout breaker) to the stage that now
      implements it, plus the one behavior that is NOT migrated (H4, per Phase 1's note).
- [ ] Verify a base-mode read-through of the full file is behaviorally unchanged: every added
      region is inside a `$hard_mode` branch, and no unconditional statement was altered except
      the loop-guard JSON schema additions (D3) and the Stage 5a gate (Phase 6).

**Timing**: 0.75 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly 7 downstream-scope tests/lints exist at the paths
listed. Confirm each path resolves under `agent-system/extensions/core/scripts/` before running,
and report any that are missing or renamed rather than silently skipping them.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — acceptance-checklist note.

**Verification**:
- `run-all.sh` green, or every red triaged and recorded as pre-existing.
- Test directories clean in `git status --short`.
- `skill-orchestrate-hard/SKILL.md` shows zero diff.
- Task-reference lint clean.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/scripts/tests/run-all.sh` passes (or every failure is
      triaged as pre-existing with evidence).
- [ ] The 7 downstream-scope tests/lints pass with no test file edited by this task.
- [ ] `skill-orchestrate-hard/SKILL.md` is byte-identical to its pre-task state.
- [ ] Base-mode behavior is unchanged: every added region is `$hard_mode`-gated, apart from the
      deliberate loop-guard schema unification and the Stage 5a mode gate.
- [ ] Each of the four WORK-list behaviors is present and traceable to a named stage in
      `skill-orchestrate/SKILL.md`.
- [ ] `phases_completed_before` / `phases_completed_after` each have exactly one assignment site.
- [ ] No contract reference is injected twice into the hard-mode implement prompt.
- [ ] No task-number references introduced outside `specs/**`.
- [ ] No hand-authored file under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the sole substantive
  deliverable: conditional `MAX_CYCLES`, unified loop-guard schema, `$hard_mode`-gated
  `loop-guard-staleness` detector, churn-state init, burnout gate at `3b-hard`, forked H1
  per-phase implement handler, new Stage 5b churn/three-strikes stage, Stage 5a base-mode gate,
  and two recorded-decision notes (H4 residue, acceptance checklist).
- `.gitignore` — only if churn-state / stale-archive coverage is found missing.
- `specs/119_migrate_hard_mode_state_machine_logic/summaries/01_*-summary.md` — implementation
  summary, including the confirmed-vs-hypothesized figures from the three Scope Hypothesis lines.

## Rollback/Contingency

Every change is confined to one markdown file in the source store, and each phase is an
independently committed unit. To revert a single phase, revert that phase's commit; to revert the
whole migration, revert the task's commit range. No script, schema, or state file is mutated
destructively: the loop-guard schema additions are forward-compatible reads (`// false`, `// 0`,
`// "none"`), so a guard written by the migrated engine is still readable by the pre-migration
engine and vice versa. `.orchestrator-churn-state.json` is ephemeral and gitignored; deleting it
is always safe. If the migration must be abandoned mid-way, the `-hard` engine is untouched and
remains fully functional, so `/orchestrate --hard` continues to route there via the existing
manifest ladder.
