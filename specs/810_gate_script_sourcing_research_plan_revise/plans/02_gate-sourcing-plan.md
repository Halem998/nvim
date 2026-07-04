# Implementation Plan: Task #810

- **Task**: 810 - Route /research, /plan, /revise through shared gate scripts for lock + checkpoint coverage
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: 788 (task-lock.sh + gate-in/out baseline), 804, 809 (cross-task file_scope overlap check) — all complete in the working tree
- **Research Inputs**: reports/01_gate-sourcing-analysis.md
- **Artifacts**: plans/02_gate-sourcing-plan.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
- **Type**: meta

## Overview

`command-gate-in.sh`/`command-gate-out.sh` (task 788) are sourced today only by `implement.md` and `orchestrate.md`. `research.md`, `plan.md`, and `revise.md` still carry fully inline, duplicated CHECKPOINT gate logic and never touch `task-lock.sh`, so session-lock protection and the 809 cross-task overlap check do not cover them. This plan refactors those three commands to source the shared gate scripts, first making two prerequisite corrections to the scripts themselves (an operation-aware terminal-status exemption for `revise`, and a `status_token` mapping fix that also repairs a latent `orchestrate` bug), then closing the multi-task-dispatch lock gap in `research.md`/`plan.md`. Definition of done: all three commands share ONE gate path, every edited file's `.claude/extensions/core/` mirror is byte-identical, and a final coherence audit confirms no partial variant remains. Scope is exactly GATE IN/GATE OUT sourcing plus the two named script fixes; `.opencode/` and the `parse-command-args.sh`/`command-route-skill.sh` STAGE 0/2 duplication are out of scope.

### Research Integration

Every finding and recommendation from `reports/01_gate-sourcing-analysis.md` is addressed:
- Recommendation 1 (gate-in `revise` terminal-guard exemption) → Phase 1.
- Recommendation 2 (gate-out `status_token`: `revise→plan`, fix `orchestrate→implement`) → Phase 1.
- Recommendation 3 (per-command CHECKPOINT rewrites, drop redundant TODO.md fallback, keep command-specific supplementary steps, header wording change, Error Handling updates for 809 overlap-refusal, multi-task lock bracketing) → Phases 2, 3, 4.
- Recommendation 4 (no changes to `task-lock.md`, `.postflight-pending` sites, `.opencode/*`, `validate-artifact.sh`) → honored as Non-Goals; dead `validate-artifact.sh --fix` leg in gate-out is left as-is (pre-existing, orthogonal) and commands keep inline artifact checks.
- Dual-copy pairs (§6): every edited file mirrored byte-for-byte to `.claude/extensions/core/`; verified per phase and audited in Phase 5.

### Prior Plan Reference

No prior plan for this task (`plans/` contained only this artifact at planning time). The task directory does contain the round-01 research report, which is the primary input above.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP consultation was requested. This task advances the "one shared gate path / one lock discipline" consolidation begun in task 788; tasks 811-813 will audit the whole system afterward, so this refactor must leave a single clean shared path, not another partial variant.

## Goals & Non-Goals

**Goals**:
- `research.md`, `plan.md`, `revise.md` source `command-gate-in.sh` at GATE IN and call `command-gate-out.sh` at GATE OUT, replacing inline CHECKPOINT logic.
- `command-gate-in.sh` grants an operation-aware exemption so `revise` is never rejected on terminal-status tasks (preserves `skill-reviser`'s "works regardless of task status" contract).
- `command-gate-out.sh` maps operation → `status_token` correctly (`revise→plan`, `orchestrate→implement` fixed) and stops passing `$operation` verbatim as `update-task-status.sh`'s `target_status`.
- `research.md`/`plan.md` multi-task dispatch loops acquire/release the task lock per task, mirroring `implement.md` Step 3.
- Each command's Error Handling section documents 809's new cross-task overlap-refusal failure mode.
- Every edited file is byte-identical to its `.claude/extensions/core/` mirror.

**Non-Goals**:
- No changes to `.opencode/*` (pre-existing, already-diverged system; out of scope per §6).
- No changes to `.claude/context/patterns/task-lock.md` (already documents the target end state, §1).
- No changes to any `.postflight-pending` write site (coverage inherited transitively, §5).
- No fix to `validate-artifact.sh`'s dead `--fix` leg (pre-existing, orthogonal; candidate for a separate task).
- No refactor of the `parse-command-args.sh`/`command-route-skill.sh` STAGE 0/2 duplication (§7; note as a follow-up candidate only).
- No git commit, no state.json/TODO.md mutation (planning-only deliverable is this file; implementation is a later dispatch).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Forgetting the `revise` terminal-guard exemption breaks `/revise` on abandoned/completed tasks | H | M | Phase 1 verification: source gate-in in a subshell with a fabricated `abandoned` task + `operation=revise`, assert exit 0/no ABORT; assert `operation=research` still aborts. Re-checked in Phase 5 acceptance test. |
| Bundling the `orchestrate` `target_status` fix widens the apparent diff footprint | M | H | Called out explicitly as a deliberate, minimal, same-6-line-block fix in Phase 1 tasks and the eventual commit message; no call-site change to `orchestrate.md`/`implement.md`. |
| Dual-copy drift between `.claude/` and `.claude/extensions/core/` mirrors | H | M | Every phase edits both copies together and ends with a `diff` gate (zero output required); Phase 5 audits all 10 files (6 command + 4 script). |
| New cross-task overlap ABORT surprises users of previously lock-free commands | M | M | Each command refactor phase updates the "GATE IN Failure" Error Handling section to name the lock-refusal and cross-task-overlap-refusal modes (§4). |
| Header wording change (`[Researching]`→`[RESEARCH]`) mistaken for a defect later | L | M | Documented as an intentional cosmetic change in Phases 3/4 and the implementation summary. |
| Redundant inline steps (manual TODO.md Edit fallback) left behind, producing a "partial variant" | M | M | Phase 5 greps each refactored command for leftover inline session-gen/jq-lookup/TODO.md-Edit blocks; must find none beyond the command-specific supplementary steps. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2, 3, and 4 touch disjoint command-file pairs and share only the already-corrected scripts from Phase 1, so they carry no ordering constraint among themselves.

---

### Phase 1: Correct the shared gate scripts [NOT STARTED]

**Goal**: Land the two prerequisite script corrections so the three commands can source them unmodified afterward: the operation-aware terminal-status exemption in `command-gate-in.sh`, and the `status_token` mapping fix in `command-gate-out.sh` (adding the `revise` arm and repairing the latent `orchestrate` bug in the same block).

**Tasks**:
- [ ] In `.claude/scripts/command-gate-in.sh`, wrap the `completed|abandoned|expanded` terminal-status guard so it is skipped when `operation == "revise"` (per report Recommendation 1); leave the guard behavior identical for all other operations.
- [ ] In `.claude/scripts/command-gate-out.sh`, refactor the `case "$operation"` block to set both `expected_status` and a new `status_token` variable: `research→researched/research`, `plan→planned/plan`, `implement→completed/implement`, `orchestrate→completed/implement` (fixes latent bug), `revise→planned/plan` (new), `*→""` (no-op).
- [ ] In the same file, change the postflight call to pass `"$status_token"` (not `"$operation"`) as `update-task-status.sh`'s `target_status` positional arg.
- [ ] Do NOT touch the dead `validate-artifact.sh "$task_dir" --fix` leg (out of scope; left as-is per Recommendation 4).
- [ ] Mirror both edits byte-for-byte into `.claude/extensions/core/scripts/command-gate-in.sh` and `.claude/extensions/core/scripts/command-gate-out.sh`.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/command-gate-in.sh` - operation-aware terminal-status exemption for `revise`
- `.claude/scripts/command-gate-out.sh` - `status_token` variable, `revise` arm, `orchestrate→implement` fix
- `.claude/extensions/core/scripts/command-gate-in.sh` - identical mirror
- `.claude/extensions/core/scripts/command-gate-out.sh` - identical mirror

**Verification**:
- [ ] `bash -n` clean on both `.claude/scripts/command-gate-in.sh` and `command-gate-out.sh`.
- [ ] `diff .claude/scripts/command-gate-in.sh .claude/extensions/core/scripts/command-gate-in.sh` → zero output; same for `command-gate-out.sh`.
- [ ] Subshell test: source `command-gate-in.sh` against a fabricated `abandoned`/`completed` task with `operation=revise` → returns 0, prints no `ABORT`; with `operation=research` → still aborts (return 1). (Use a throwaway state entry or a stubbed `TASK_STATUS`.)
- [ ] Inspect the gate-out `case` block: `orchestrate` now yields `status_token=implement`, `revise` yields `status_token=plan`; no branch passes a value outside `research|plan|implement|pr_ready` to `target_status`.

---

### Phase 2: Refactor revise.md onto the shared gate [NOT STARTED]

**Goal**: Replace `revise.md`'s inline CHECKPOINT 1 (GATE IN) and CHECKPOINT 3 (GATE OUT) logic with `command-gate-in.sh`/`command-gate-out.sh`, preserving revise's status-agnostic behavior and its Plan-Revision vs Description-Update routing.

**Tasks**:
- [ ] CHECKPOINT 1: replace inline session-ID generation, `jq` task lookup, and the explicit "no terminal-status guard" prose with `source .claude/scripts/command-gate-in.sh "$task_number" "revise"`. The Phase-1 exemption preserves the "works regardless of task status" contract.
- [ ] Keep the revise-specific plan-existence check (drives Plan-Revision vs Description-Update routing) immediately after the gate-in source; it has no gate-script equivalent and must stay inline.
- [ ] CHECKPOINT 3: replace the inline state.json/TODO.md defensive-correction block (scoped to "Plan Revision only") with `bash .claude/scripts/command-gate-out.sh "$task_number" "revise" "$SESSION_ID"`.
- [ ] Drop the now-redundant manual TODO.md Edit-tool fallback (achieved as a side effect of `update-task-status.sh`'s internal `generate-todo.sh` call).
- [ ] Confirm the description-update path still skips defensive correction: `skill-reviser` reports `status="description_updated"`, outside gate-out's `implemented|researched|planned` gate, so no correction fires — desired behavior; keep the description-update path routed around the gate-out call as today.
- [ ] Update the "GATE IN Failure" Error Handling section to name the new lock-refusal and cross-task `file_scope` overlap-refusal modes (§4) in addition to the existing "task not found"/"invalid status" cases.
- [ ] Note the header now displays `[REVISE]` (gate-in's mechanical uppercasing) as an intentional change.
- [ ] Mirror every edit byte-for-byte into `.claude/extensions/core/commands/revise.md`.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/revise.md` - CHECKPOINT 1/3 gate sourcing, keep plan-existence check, Error Handling update
- `.claude/extensions/core/commands/revise.md` - identical mirror

**Verification**:
- [ ] `diff .claude/commands/revise.md .claude/extensions/core/commands/revise.md` → zero output.
- [ ] `grep` confirms `source .claude/scripts/command-gate-in.sh "$task_number" "revise"` and `command-gate-out.sh ... "revise"` present; no inline `sess_$(date +%s)` session-gen or manual TODO.md Edit fallback remains.
- [ ] Plan-existence check and description-update conditioning still present.
- [ ] Error Handling section mentions cross-task overlap-refusal.

---

### Phase 3: Refactor research.md onto the shared gate + multi-task lock [NOT STARTED]

**Goal**: Replace `research.md`'s inline CHECKPOINT 1/CHECKPOINT 2 logic with the shared gate scripts, keep the inline artifact-existence check, and add per-task lock bracketing to the MULTI-TASK DISPATCH loop (mirroring `implement.md` Step 3).

**Tasks**:
- [ ] CHECKPOINT 1 (single-task path): replace inline session-ID gen, `jq` lookup, and terminal-status handling with `source .claude/scripts/command-gate-in.sh "$task_number" "research"`.
- [ ] CHECKPOINT 2: replace the inline state.json defensive-correction block and the manual TODO.md Edit-tool fallback with `bash .claude/scripts/command-gate-out.sh "$task_number" "research" "$SESSION_ID"`.
- [ ] KEEP the inline artifact-existence check (step 2) as a command-specific supplementary step — `command-gate-out.sh`'s `validate-artifact.sh --fix` leg is dead code and cannot substitute for it.
- [ ] Update the header expectation from `[Researching]` to `[RESEARCH]` (gate-in's uppercasing; call out as intentional cosmetic change).
- [ ] Add per-task lock bracketing to the MULTI-TASK DISPATCH loop (Step 3), copying `implement.md`'s pattern verbatim: `task-lock.sh acquire "$task_num" research "${batch_session_id}_${task_num}" "/research (multi-task)"` before each skill invocation (skip-with-reason `"locked by another session"` on exit 1), unconditional `task-lock.sh release "$task_num" "${batch_session_id}_${task_num}"` after each invocation regardless of outcome.
- [ ] Update the "GATE IN Failure" Error Handling section to name the new lock-refusal and cross-task overlap-refusal modes (§4).
- [ ] Mirror every edit byte-for-byte into `.claude/extensions/core/commands/research.md`.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/research.md` - CHECKPOINT 1/2 gate sourcing, keep artifact-existence check, multi-task lock bracketing, header + Error Handling updates
- `.claude/extensions/core/commands/research.md` - identical mirror

**Verification**:
- [ ] `diff .claude/commands/research.md .claude/extensions/core/commands/research.md` → zero output.
- [ ] `grep` confirms `source .claude/scripts/command-gate-in.sh "$task_number" "research"`, `command-gate-out.sh ... "research"`, and both `task-lock.sh acquire ... research` / `task-lock.sh release` in the multi-task loop.
- [ ] Inline artifact-existence check retained; no leftover manual TODO.md Edit fallback or inline session-gen block.
- [ ] Error Handling section mentions cross-task overlap-refusal.

---

### Phase 4: Refactor plan.md onto the shared gate + multi-task lock [NOT STARTED]

**Goal**: Replace `plan.md`'s inline CHECKPOINT 1/CHECKPOINT 2 logic with the shared gate scripts, keep the plan-specific supplementary steps (Load Context, plan-file-status verification), and add per-task lock bracketing to the MULTI-TASK DISPATCH loop.

**Tasks**:
- [ ] CHECKPOINT 1 (single-task path): replace inline session-ID gen, `jq` lookup, and terminal-status handling with `source .claude/scripts/command-gate-in.sh "$task_number" "plan"`.
- [ ] KEEP the plan-specific "Load Context" step (research reports + prior-plan discovery) immediately after gate-in; it has no gate-script equivalent.
- [ ] CHECKPOINT 2: replace the inline state.json defensive-correction block and the manual TODO.md Edit-tool fallback with `bash .claude/scripts/command-gate-out.sh "$task_number" "plan" "$SESSION_ID"`.
- [ ] KEEP the plan-specific step 6 (plan-file-status verification) as a command-specific supplementary step after the gate-out call, mirroring how `implement.md` keeps its plan-status/TODO.md steps.
- [ ] Update the header expectation from `[Planning]` to `[PLAN]` (intentional cosmetic change).
- [ ] Add per-task lock bracketing to the MULTI-TASK DISPATCH loop, copying `implement.md`'s Step 3 verbatim: `task-lock.sh acquire "$task_num" plan "${batch_session_id}_${task_num}" "/plan (multi-task)"` before each skill invocation (skip-with-reason on exit 1), unconditional release after.
- [ ] Update the "GATE IN Failure" Error Handling section to name the new lock-refusal and cross-task overlap-refusal modes (§4).
- [ ] Mirror every edit byte-for-byte into `.claude/extensions/core/commands/plan.md`.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/commands/plan.md` - CHECKPOINT 1/2 gate sourcing, keep Load Context + plan-file-status steps, multi-task lock bracketing, header + Error Handling updates
- `.claude/extensions/core/commands/plan.md` - identical mirror

**Verification**:
- [ ] `diff .claude/commands/plan.md .claude/extensions/core/commands/plan.md` → zero output.
- [ ] `grep` confirms `source .claude/scripts/command-gate-in.sh "$task_number" "plan"`, `command-gate-out.sh ... "plan"`, and `task-lock.sh acquire ... plan` / `task-lock.sh release` in the multi-task loop.
- [ ] Load Context step and plan-file-status verification retained; no leftover manual TODO.md Edit fallback or inline session-gen block.
- [ ] Error Handling section mentions cross-task overlap-refusal.

---

### Phase 5: Coherence verification and dual-copy audit [NOT STARTED]

**Goal**: Confirm the refactor leaves ONE clean shared gate path (no partial variant), all dual-copy pairs are byte-identical, and the load-bearing behaviors survive — a system-level check ahead of the 811-813 audits.

**Tasks**:
- [ ] Diff-audit all 10 affected files as 5 pairs (`.claude/` ↔ `.claude/extensions/core/`): `research.md`, `plan.md`, `revise.md`, `command-gate-in.sh`, `command-gate-out.sh` — each `diff` must produce zero output.
- [ ] Grep all three refactored commands for residual inline gate logic (`sess_$(date +%s)` session-gen, inline `jq` terminal-status guards, manual TODO.md Edit-tool fallback) — must find none beyond the documented command-specific supplementary steps (research artifact check; plan Load Context + plan-file-status; revise plan-existence + description-update routing).
- [ ] Confirm all three commands source `command-gate-in.sh` with the correct operation string and call `command-gate-out.sh` with the matching operation, consistent with `implement.md`/`orchestrate.md`.
- [ ] Acceptance test A (revise on terminal status): source `command-gate-in.sh` with a task whose status is `abandoned`/`completed` and `operation=revise` → succeeds (exit 0, no ABORT); same task with `operation=research`/`plan` → aborts. Confirms the Phase-1 exemption is exercised end-to-end.
- [ ] Acceptance test B (gate-out token mapping): confirm `command-gate-out.sh` with `operation=revise` would pass `plan` as `target_status`, and `operation=orchestrate` would pass `implement` — neither hits `update-task-status.sh`'s validation error.
- [ ] Acceptance test C (multi-task lock): confirm `research.md` and `plan.md` multi-task loops acquire before and release after each per-task skill invocation, with skip-on-refusal semantics matching `implement.md` Step 3.
- [ ] Confirm no changes were made to `.opencode/*`, `.claude/context/patterns/task-lock.md`, `.postflight-pending` write sites, or `validate-artifact.sh` (Non-Goals held).
- [ ] Record the intentional header wording change (`[RESEARCH]`/`[PLAN]`/`[REVISE]`) and the bundled `orchestrate→implement` fix in the implementation summary so they are not later flagged as defects/scope creep.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- None (verification-only; produces findings for the implementation summary)

**Verification**:
- [ ] All 5 `diff` pairs zero-output.
- [ ] Residual-inline-logic grep returns nothing unexpected across all three commands.
- [ ] Acceptance tests A, B, C pass.
- [ ] Non-Goals confirmed untouched via `git status`/`diff` scoped to the out-of-scope paths.

## Testing & Validation

- [ ] `bash -n` clean on `command-gate-in.sh` and `command-gate-out.sh` (both trees).
- [ ] All 5 dual-copy `diff` pairs produce zero output.
- [ ] Gate-in `revise` exemption: `abandoned`/`completed` task + `operation=revise` → success; `operation=research`/`plan` → abort.
- [ ] Gate-out token mapping: `revise→plan`, `orchestrate→implement`, `research→research`, `plan→plan`, `implement→implement`; no value outside `research|plan|implement|pr_ready` reaches `target_status`.
- [ ] `research.md`/`plan.md` multi-task loops acquire/release the lock per task with skip-on-refusal, matching `implement.md` Step 3.
- [ ] Each command's Error Handling section documents the cross-task overlap-refusal mode.
- [ ] No residual inline session-gen / terminal-guard / manual TODO.md Edit logic in the three commands beyond their documented command-specific supplementary steps.
- [ ] `.opencode/*`, `task-lock.md`, `.postflight-pending` sites, and `validate-artifact.sh` unchanged.

## Artifacts & Outputs

- `plans/02_gate-sourcing-plan.md` (this file)
- `summaries/02_gate-sourcing-summary.md` (produced at implementation time)
- Edited (at implementation time): `.claude/scripts/command-gate-in.sh`, `.claude/scripts/command-gate-out.sh`, `.claude/commands/{research,plan,revise}.md`, and their `.claude/extensions/core/` mirrors (10 files total).

## Rollback/Contingency

- All changes are localized to two scripts (both trees) and three command files (both trees); revert with `git checkout -- <path>` on the affected files, which restores the fully-inline pre-refactor behavior with no schema or state migration required.
- If the gate-in exemption or gate-out token fix misbehaves, Phase 1 can be reverted independently — the command refactors (Phases 2-4) will then fail their `source` verification, surfacing the coupling immediately rather than silently.
- If a dual-copy pair drifts, re-copy the `.claude/` version over its `.claude/extensions/core/` mirror (or vice versa) and re-run the Phase 5 `diff` audit; no other artifact depends on the mirror content.
- Because implementation is a separate dispatch and touches no state.json/TODO.md/git in the planning stage, this plan itself carries no rollback obligation.
