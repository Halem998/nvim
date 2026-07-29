# Implementation Plan: Corroborate Phase Counts on the Handoff-Present Path

- **Task**: 968 - corroborate_phase_counts_on_handoff_present_path
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: `specs/968_corroborate_phase_counts_on_handoff_present_path/reports/01_corroborate_phase_counts_handoff_present.md`
- **Artifacts**: plans/01_corroborate-phase-counts-handoff-present.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; source-store-deploy-boundary.md; no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The orchestrator trusts plan-file phase headings as independent completion evidence when **no**
handoff exists, and ignores that same evidence when a handoff exists but omits the optional
`phases_completed` / `phases_total` fields. This plan closes that asymmetry by extracting the
existing corroboration logic into one shared, testable function in `scripts/skill-base.sh` and
invoking it from the handoff-present branch of all three orchestration engines, with the
architectural prose invariants that currently scope corroboration to the missing/stale branch
edited in the same commits. Definition of done: a handoff reporting `implemented` with null phase
counts against a fully-closed plan permits completion (with the `[UNVERIFIED PHASES CORROBORATED]`
banner); a partial plan and a heading-less plan still refuse; and the three engines share one
implementation rather than six hand-copied blocks.

### Research Integration

Every load-bearing finding from the research report is addressed by a named phase:

| Research finding | Addressed by |
|------------------|--------------|
| (1) Both `SKILL.md` files carry prose invariants scoping corroboration to the missing/stale branch; Option A falsifies them | Phases 4 and 5, each declared `Commit Mode: atomic-batch` so code and prose land together |
| (2) `skill_write_orchestrator_handoff` has zero live callers; Option B's helper-vs-jq framing is void | Phase 2 re-scopes Option B to the base-mode agent contract, the population that actually lacks a documented format |
| (3) `scripts/validate-handoff.sh` is correct but unwired | Phase 1 wires it as a bounded, log-only producer-defect diagnostic inside the shared function, firing only on the new trigger |
| (4) `general-implementation-agent.md` documents no `.orchestrator-handoff.json` format at all — plausible root cause | Phase 2 |
| (5) No test coverage for `skill_gate_completion_claim` or the corroboration logic | Phase 3, modeled on `scripts/tests/test-phase-heading-patterns.sh` |
| (6) Verification hazard: both `SKILL.md` files are driving live orchestration right now | Phase 8, an explicit scratch-deploy-tree gate before any redeploy |
| (Open design question) Trigger precondition: both-zero vs. total-only | Decided below (D3) |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task; no roadmap flag was set.

## Decisions

Stated explicitly, per the delegation instruction to decide among A/B/C on the evidence.

**D1 — Adopt A and C as the core fix; adopt a re-scoped subset of B as additive defense.**
Option A is the only option that changes what the gate sees for a handoff that *already exists*
with omitted fields — no producer-side fix retroactively repairs an artifact another write path
already produced, which the research shows is exactly what happened in the observed case. Option
C is not separable from A: A applied once creates a three-way engine divergence with no
precedent, whereas the recovery-path corroboration is already byte-parallel across all three
engines, so mirroring is the status quo, not an extra. Option B is retained but re-scoped per
research finding (2) — see D5.

**D2 — Extract the corroboration logic into `skill_corroborate_phase_counts()` in
`scripts/skill-base.sh` rather than adding three more inline copies.** The block is already
duplicated once across three engines; wiring the handoff-present path inline would make six
hand-maintained copies of logic whose whole purpose is that the engines agree. `skill-base.sh` is
chosen over a new `scripts/*.sh` file for two concrete reasons: (a) both engines already
`source .claude/scripts/skill-base.sh`, so no new sourcing plumbing is needed; (b) a brand-new
`scripts/*.sh` file is subject to the documented deploy-mechanism gap in which the headless
"Load Core" sync does not re-run per-extension script copying for already-loaded extensions, so a
new file can silently never reach an existing deploy — editing an already-deployed file sidesteps
that entirely. It also places the function beside `skill_gate_completion_claim`, which was
unified into that same file for precisely this anti-drift reason.

**D3 — The new trigger precondition is `phases_total -eq 0` alone, deliberately diverging from
the recovery path's `PHASES_ZERO_ON_SUCCESS` (both-counts-zero) signature.** The research flagged
this as a genuine open choice. Resolved in favor of total-only because the corroboration block's
sole consumer is `skill_gate_completion_claim`'s Case 3, whose own precondition is `phases_total
== 0` and which ignores `phases_completed` entirely once that holds. Matching the consumer's
precondition exactly means trigger and gate cannot drift apart; matching the recovery-path
signature instead would leave a real gap — a handoff with `phases_completed: 7, phases_total:
null` would take Case 3, be refused, and never be corroborated. This divergence MUST be recorded
in-file as deliberate, in the same style the `blocked`-row divergence in the multi-task grouping
table is recorded.

**D4 — The gate is not weakened, and this is structural rather than a promise.** The new call
site writes only `phases_completed` / `phases_total` / `plan_markers_verified`, and only from the
plan file. Case 1 (accounting present and incomplete → always refuse) is *unreachable* from the
new trigger by construction, because the trigger requires `phases_total == 0` and Case 1 requires
`phases_total > 0`. A corroborated correction therefore never overrides a refusal; it only
supplies independent evidence where the handoff supplied none. Case 2's unconditional allow is
untouched.

**D5 — Option B re-scoped to two items that match the live reality.** (B1) Wire the existing,
correct, unwired `validate-handoff.sh` as a **log-only, non-gating** producer-defect diagnostic,
fired only on the new corroboration trigger — never per-cycle, so the ~450-tokens-per-cycle
context-flatness budget is untouched on the normal path. (B2) Give
`general-implementation-agent.md` an explicit `.orchestrator-handoff.json` section: base-mode
implement is documented as a non-writer by design, so the contract states that prohibition
outright and, for the defensive case, requires that any counts written come from the Stage 5a
plan-heading pass the agent already runs — never `null`. The "helper vs raw `jq -n`" framing from
the task description is dropped as counterfactual per research finding (2).

## Goals & Non-Goals

**Goals**:
- Make plan-heading corroboration reachable from the handoff-present branch in all three engines.
- Keep one implementation of the corroboration logic, shared and directly testable.
- Keep the completion gate fail-closed: partial plans and heading-less plans still refuse.
- Update the two prose invariants that currently assert corroboration is missing/stale-only, in
  the same commits as the code that falsifies them.
- Give the verification bar's three fixtures a real production artifact to test against.
- Close the producer-side gap for base-mode implement dispatches.

**Non-Goals**:
- Changing `skill_gate_completion_claim`'s three-case logic. It needs zero changes.
- Making `validate-handoff.sh` a hard stop anywhere. A REFUSE-worthy defect must still route
  through the corroboration/gate machinery, not a unilateral abort.
- Reviving or wiring `skill_write_orchestrator_handoff` (zero live callers; out of scope).
- Redeploying `.claude/` as part of this task's implementation phases (see Phase 8).
- Any edit under `.claude/**`. All edits target `agent-system/extensions/core/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A syntax or logic error in an orchestrator-critical `SKILL.md` is picked up by a live redeploy mid-cycle, affecting every task currently being orchestrated | H | M | Phase 8's scratch-deploy-tree gate; `bash -n` on every extracted embedded-bash block before any phase closes; no redeploy inside phases 1-7 |
| Code lands without the paired prose-invariant edit, leaving a stated MUST-NOT contradicted by shipped behavior | H | M | Phases 4 and 5 declare `Commit Mode: atomic-batch` so the code and prose edits are one objective with one commit; verified by grep for the old wording |
| Corroboration accidentally admits a partial plan, weakening the gate | H | L | D4's structural argument plus Phase 3's explicit partial-plan and heading-less fixtures, which must REFUSE |
| Phase 7's refactor of three working recovery-path blocks introduces a behavior change | M | M | Phase 7 is behavior-preserving by contract: the extracted function is a faithful lift; Phase 3's suite runs before and after and must produce identical verdicts |
| The three engines drift again after this change | M | L | D2's single shared function makes agreement structural; Phase 8 audits it by grep rather than by eye |
| `validate-handoff.sh` runs under `set -euo pipefail` and exits non-zero, aborting the orchestrator's bash block | M | M | Invoke as `... || true` inside the shared function; Phase 1 verification includes an exit-1 fixture |
| A new `scripts/*.sh` file never reaches an existing deploy (documented loader gap) | M | M | D2 avoids new script files for the production logic; only the new *test* file is new, and tests are run from the source store |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 1, 3 |
| 4 | 6 | 4 |
| 5 | 7 | 4, 5, 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Shared corroboration function in skill-base.sh [COMPLETED]

**Goal**: Create `skill_corroborate_phase_counts()` in `agent-system/extensions/core/scripts/skill-base.sh`
as the single implementation of plan-heading corroboration, callable from every engine and
directly testable.

**Tasks**:
- [x] Add `skill_corroborate_phase_counts()` immediately after `skill_gate_completion_claim()` in
      `scripts/skill-base.sh`, with a header comment in the same style as its neighbor.
- [x] Signature: `skill_corroborate_phase_counts <task_number> <plan_path> <log_prefix> [handoff_path]`.
      It prints a single line of shell-assignable output on stdout of the form
      `phases_completed=<int> phases_total=<int> plan_markers_verified=<true|absent>` and returns
      0 when corroborated, 1 when not corroborated (including the non-conforming and no-plan
      cases). Callers `eval`-free-parse it with `read`, never `eval`.
- [x] Source `.claude/scripts/lib/phase-heading-patterns.sh` inside the function body using the
      deploy-tree-first / source-store-fallback candidate list already used by
      `scripts/tests/test-phase-heading-patterns.sh`, so the function works both post-deploy and
      in a source-store-only checkout.
- [x] Implement the three-way branch as a faithful lift of the existing block: (a)
      `has_nonconforming_phase_headings` true -> call `warn_nonconforming`, emit the
      "counts unreliable" note, return `plan_markers_verified=absent` with counts untouched;
      (b) `total > 0 && completed -eq total` -> return corrected counts and
      `plan_markers_verified=true`, emitting the `[UNVERIFIED PHASES CORROBORATED]` banner;
      (c) otherwise -> emit the non-corroborating note, leave `plan_markers_verified=absent`.
- [x] Handle the empty/missing `plan_path` case: emit the "no plan file found to corroborate
      against" note and return the absent verdict. Never treat a missing plan as corroboration.
- [x] Use the `x=$(grep -c ...) || x=0` idiom, never `$(grep -c ... || echo 0)` — the latter
      emits two lines on zero matches.
- [x] When the optional `handoff_path` argument is non-empty and the file exists, run
      `bash .claude/scripts/validate-handoff.sh "$handoff_path" >&2 || true` as a **log-only,
      non-gating** producer-defect diagnostic (D5/B1). Its exit status MUST NOT influence the
      function's own return value. Guard with `|| true` because that script runs under
      `set -euo pipefail` and exits 1 on any failed check.
- [x] Add a comment block recording D3 (total-only trigger vs. the recovery path's both-zero
      signature) and D4 (Case 1 unreachable by construction) as deliberate design, in the same
      "this is a DESIGN, not an undocumented assertion" style the multi-task `blocked`-row
      divergence uses.
- [x] Use durable anchors only in all added comments — reference function names, section
      headings, and file paths; never cite a task number (deliverable rule).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the function has exactly one new home
(`scripts/skill-base.sh`) and that both engines already source it. Confirm at implementation time
with `grep -n "skill-base.sh" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`; if either engine turns out
not to source it in the Stage 5 scope, add the source line in that engine's phase (4 or 5) rather
than relocating the function.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - add `skill_corroborate_phase_counts()`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` is clean.
- Smoke test: source the file in a scratch shell, call the function against a hand-written
  all-closed plan fixture and confirm the corroborated verdict and banner; call it against a
  partial fixture and confirm the absent verdict.
- Confirm the function never writes to any file and never reads a report or summary.

---

### Phase 2: Producer-side contract and handoff-schema note [COMPLETED]

**Goal**: Close the base-mode producer gap identified as the plausible root cause of the observed
null-field handoff, and record `validate-handoff.sh`'s wiring status so a future reader does not
re-discover by grep that it was dead code.

**Tasks**:
- [x] Add an explicit `.orchestrator-handoff.json` section to
      `agent-system/extensions/core/agents/general-implementation-agent.md`, stating that
      base-mode implement does not write this file by design (matching `handoff-schema.md`'s
      "Handoff Writers" table), and that a `handoff_path` field appearing in the delegation
      context is an anchor for the orchestrator's own read, not an instruction to write one.
- [x] In the same section, cover the defensive case: if a handoff is written anyway,
      `phases_completed` / `phases_total` MUST be the real integers already computed by the
      agent's Stage 5a plan-heading marker-repair pass, written at the **top level** (contrasting
      with `.return-meta.json`'s nested placement, which that agent file already documents), and
      MUST NEVER be `null`.
- [x] Update `agent-system/extensions/core/docs/architecture/handoff-schema.md`'s "Handoff
      Writers" section with a short note that `validate-handoff.sh` is now invoked as a log-only
      diagnostic from the shared corroboration function, naming that function.
- [x] No task-number citations in any of these files (deliverable rule); reference the schema
      section and function name instead.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - new handoff section
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Handoff Writers note

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no embedded bash altered.
- `grep -n "orchestrator-handoff" agent-system/extensions/core/agents/general-implementation-agent.md`
  now returns a dedicated section, not only the incidental nesting-contrast mention.
- `bash .claude/scripts/check-task-references.sh` (or the source-store fallback path) reports no
  new findings.

---

### Phase 3: Fixture-driven test suite for corroboration and the completion gate [COMPLETED]

**Goal**: Give the verification bar's three scenarios a real harness that exercises production
code, not a hand-copied reimplementation of markdown-embedded bash.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh`,
      structurally modeled on `scripts/tests/test-phase-heading-patterns.sh`: `mktemp -d` workdir
      with an EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate resolution,
      sourced (not subprocessed) libraries, `pass()` / `fail()` / `info()` helpers with integer
      counters, exit 0 all-pass / 1 any-fail / 2 environment error.
- [x] Source both `scripts/skill-base.sh` and `scripts/lib/phase-heading-patterns.sh`.
- [x] Fixture A (verification bar item 1): plan with all phases `[COMPLETED]`, simulated handoff
      with null phase counts. Assert `skill_corroborate_phase_counts` corroborates, emits the
      `[UNVERIFIED PHASES CORROBORATED]` banner, and that feeding its output into
      `skill_gate_completion_claim` returns 0 (ALLOW).
- [x] Fixture B (verification bar item 2): plan with a partial close (some `[COMPLETED]`, some
      `[NOT STARTED]`). Assert non-corroborated, `plan_markers_verified` stays `absent`, and the
      gate returns 1 (REFUSE).
- [x] Fixture C (verification bar item 3): plan with zero conforming phase headings. Assert
      non-corroborated, the non-conforming warning is emitted where applicable, and the gate
      returns 1 (REFUSE).
- [x] Fixture D: mixed `[COMPLETED]` and `[COMPLETED WITH EXCLUSIONS]`, all closed. Assert
      corroborated — `COMPLETED WITH EXCLUSIONS` counts as closed per the shared library's DONE
      alternation.
- [x] Fixture E: a non-conforming heading (e.g. a letter-suffixed phase number) mixed with
      otherwise-closed phases. Assert the unreliable/absent branch, never a corroboration.
- [x] Fixture F (D4 guard): `phases_total > 0` and incomplete. Assert the gate refuses regardless
      of any corroboration output — proving Case 1 is untouched.
- [x] Fixture G: empty/missing plan path. Assert the absent verdict, not a crash.
- [x] Fixture H: `validate-handoff.sh` invoked against a handoff with null counts. Assert the
      function still returns its own verdict and does not abort — the diagnostic is non-gating.
- [x] `chmod +x` the new test file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Eight fixtures (A-H) are asserted as sufficient coverage — three from the
stated verification bar plus five guarding the enum, the D4 invariant, and the non-gating
diagnostic. Confirm at implementation time by checking that every branch of
`skill_corroborate_phase_counts` is reached by at least one fixture; add fixtures rather than
leaving a branch uncovered.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` - new file

**Verification**:
- `bash -n` clean on the new test file.
- `bash agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` exits 0 with
  all fixtures passing.
- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` still exits 0
  (no regression in the shared library).

---

### Phase 4: Base single-task Stage 5 wiring and MUST NOT prose edit [COMPLETED]

**Goal**: Make corroboration reachable from `skill-orchestrate/SKILL.md` Stage 5's
handoff-present branch, and update the `## MUST NOT (Context Flatness Constraint)` contract in
the same commit so no stated invariant is left contradicted.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md` Stage 5, inside the `else` (handoff-present) branch,
      after `plan_markers_verified` is read from the handoff and before `have_outcome=true`, add
      the new trigger: when `dispatch_status = "implemented"` AND `phases_total -eq 0`, resolve
      the plan path with the same `${plan_path:-}` / `ls -1 "${TASK_DIR}/plans/"*.md | sort -V |
      tail -1` idiom the recovery block uses, then call `skill_corroborate_phase_counts` and
      re-assign `phases_completed` / `phases_total` / `plan_markers_verified` from its output.
- [x] Pass `"$handoff_file"` as the optional fourth argument so the log-only
      `validate-handoff.sh` diagnostic fires exactly here and nowhere else.
- [x] Add the in-place comment recording D3's total-only precondition as a deliberate divergence
      from the recovery path's `PHASES_ZERO_ON_SUCCESS` signature, and D4's structural argument
      that Case 1 is unreachable from this trigger.
- [x] Edit `## MUST NOT (Context Flatness Constraint)`'s "Recovery exception (phase-marker grep)"
      to enumerate a THIRD reachable branch (handoff-present + `phases_total == 0` +
      `status == "implemented"`), preserving the same four bounds already stated for the other
      two branches (count-only, heading-lines-only, narrow precondition, evidence-based
      escalation).
- [x] Rewrite the closing sentence "they do not relax item 2 anywhere else" so it remains true —
      it must now name the three bounded branches rather than assert a single-branch scope, and
      must keep asserting that the normal path (fresh handoff with populated accounting) runs no
      plan read at all.
- [x] Update the `implemented)` case comment in the shared postflight tail, which currently says
      corroboration comes only from "the recovered path above".
- [x] Durable anchors only in all comment text; no task-number citations.

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly one code insertion point (Stage 5's `else`
branch) and three prose edit sites (the phase-marker-grep exception's branch enumeration, its
closing sentence, and the `implemented)` case comment). Confirm at implementation time by
grepping the file for every occurrence of "missing/stale-handoff branch" and "recovered path
above"; each hit is either edited or explicitly confirmed still-accurate before the phase closes.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 handoff-present
  branch, `## MUST NOT (Context Flatness Constraint)`, `implemented)` case comment

**Verification**:
- Extract every fenced bash block in the edited Stage 5 region to a scratch file and confirm
  `bash -n` is clean.
- Re-run the Phase 3 suite: still exits 0.
- `grep -n "they do not relax item 2 anywhere else"` returns nothing (the falsified sentence is
  gone), and the replacement text names three branches.
- Read-through confirms the corroborated correction is sourced only from the plan file, never
  from the handoff's own values.

---

### Phase 5: Hard-mode Stage 5 wiring and Read allowlist prose edit [COMPLETED]

**Goal**: Apply the identical change to `skill-orchestrate-hard/SKILL.md`, including its own
`## Tool Constraints (Pure Dispatcher)` Read allowlist invariant.

**Tasks**:
- [x] In `skills/skill-orchestrate-hard/SKILL.md` Stage 5 (inside the marked hard-mode Stage 5
      block), add the same trigger and `skill_corroborate_phase_counts` call to the
      handoff-present `else` branch, with the `[hard-orchestrate]` log prefix.
- [x] Pass the handoff path as the optional fourth argument, matching Phase 4.
- [x] Edit "Read allowlist" item 3(c) in `## Tool Constraints (Pure Dispatcher)`: it currently
      says the count-only phase-marker grep "fires only inside the missing/stale-handoff branch".
      Widen it to name the handoff-present corroboration trigger as a second bounded use, keeping
      the ≤10-tokens-per-event ceiling and the grep-only (never full-file-comprehension)
      framing.
- [x] Update the hard-mode `implemented)` case comment that currently attributes
      `plan_markers_verified="true"` solely to "the evidence-corroboration block above".
- [x] Add the same D3/D4 comment as Phase 4, worded for this engine, so a reader of either file
      sees the same rationale.
- [x] Durable anchors only; no task-number citations.

**Timing**: 1.25 hours

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5 handoff-present
  branch, `## Tool Constraints (Pure Dispatcher)` Read allowlist, `implemented)` case comment

**Verification**:
- `bash -n` clean on every extracted fenced bash block in the edited region.
- Re-run the Phase 3 suite: still exits 0.
- `grep -n "fires only inside the missing/stale-handoff branch"` returns nothing.
- Diff the new hard-mode block against Phase 4's base-mode block: the only differences are the
  log prefix and variable names already known to differ between the engines.

---

### Phase 6: Multi-task Stage MT-4 wiring [NOT STARTED]

**Goal**: Mirror the change into the multi-task engine so all three agree, matching the existing
"identical mirror" precedent already used for the recovery-path corroboration.

**Tasks**:
- [ ] In `skills/skill-orchestrate/SKILL.md` Stage MT-4, in step 2 (the handoff-present field
      extraction), add the same trigger after `plan_markers_verified` is read: when this task's
      own `dispatch_status = "implemented"` AND its `phases_total -eq 0`, call
      `skill_corroborate_phase_counts` scoped to **this task's own** `plan_path` / `task_dir` and
      handoff, never another task's in the same wave.
- [ ] Re-resolve the plan path per task inside the loop, using the same
      `ls -1 "${task_dir}/plans/"*.md | sort -V | tail -1` fallback the MT recovery block uses.
      Never carry a value over between loop iterations.
- [ ] Update step 2's existing sentence "this step's own read applies only when a handoff was
      actually present" so it also describes the new corroboration, and update step 3's
      `implemented` bullet, which currently describes the gate call as consuming raw handoff
      fields only.
- [ ] Add a short note that this is the intentional mirror of single-task Stage 5, referencing
      that stage by heading name.
- [ ] Durable anchors only; no task-number citations.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the multi-task engine has exactly one handoff-present
extraction site (Stage MT-4 step 2). Confirm at implementation time with a grep for
`plan_markers_verified` within the `## Multi-Task Mode` region; every hit is either the recovery
block (untouched here), the new site, or the gate call in step 3.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 steps 2 and 3

**Verification**:
- `bash -n` clean on every extracted fenced bash block in the edited MT-4 region.
- Re-run the Phase 3 suite: still exits 0.
- Read-through confirms per-task scoping: no variable set in one iteration is readable as a
  default in the next.

---

### Phase 7: Migrate the existing recovery-path blocks to the shared function [NOT STARTED]

**Goal**: Eliminate the remaining hand-copied corroboration blocks so exactly one implementation
exists, making "the three engines agree" mechanically checkable rather than eyeballed.

**Tasks**:
- [ ] Replace the inline corroboration block in `skill-orchestrate/SKILL.md` Stage 5's
      `recovered = true` branch with a call to `skill_corroborate_phase_counts`, preserving the
      existing `evidence_suspect` / `evidence_reason` / `dispatch_status` precondition exactly as
      the recovery path's trigger (this phase changes the implementation, never the trigger).
- [ ] Do the same for `skill-orchestrate-hard/SKILL.md` Stage 5's recovered branch.
- [ ] Do the same for `skill-orchestrate/SKILL.md` Stage MT-4 step 1's recovered branch.
- [ ] Pass an EMPTY handoff-path argument on all three recovery-path call sites — there is no
      handoff to validate on that path, and the diagnostic must not fire there.
- [ ] Preserve every existing log-message wording that an operator may be grepping for, including
      the `[UNVERIFIED PHASES CORROBORATED]` banner and the per-engine log prefixes.
- [ ] Update the `## MUST NOT` and Read-allowlist prose to describe the shared function as the
      single anchor, in the same way `phase-heading-patterns.sh` is described as the single
      grammar anchor.

**Timing**: 1.25 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Three existing inline corroboration blocks are asserted (base single-task
Stage 5, hard single-task Stage 5, base multi-task Stage MT-4 step 1). Confirm at implementation
time with `grep -rn "UNVERIFIED PHASES CORROBORATED" agent-system/extensions/core/skills/`; if the
count differs from three plus the new call sites, reconcile before editing. If any site proves to
carry a genuine behavioral difference that the shared function cannot express, do NOT force the
migration — record the divergence in-file as deliberate, in the style of the multi-task
`blocked`-row divergence, and close the phase as `[COMPLETED WITH EXCLUSIONS]` with a
`#### Reasoned Exclusions` record.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 and Stage MT-4
  recovery blocks
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5 recovery block

**Verification**:
- `bash -n` clean on every extracted fenced bash block in all edited regions.
- Re-run the Phase 3 suite: still exits 0, with identical per-fixture verdicts to the pre-phase
  run (behavior-preserving).
- `grep -c` for the corroboration three-way branch's distinctive strings shows one implementation
  in `skill-base.sh` and zero duplicated implementations in either `SKILL.md`.

---

### Phase 8: Scratch-deploy-tree verification and engine-agreement audit [NOT STARTED]

**Goal**: Clear the verification hazard before anything reaches the live deploy, and confirm the
full verification bar is met.

**Tasks**:
- [ ] Create a disposable scratch copy of the deploy tree (a throwaway clone or git worktree with
      its own regenerated `.claude/`) and verify there. The live `.claude/` this session and its
      siblings are being orchestrated through MUST NOT be redeployed as part of this task.
- [ ] In the scratch tree, extract every fenced bash block from both `SKILL.md` files and run
      `bash -n` over each. Record the block count checked.
- [ ] In the scratch tree, run the full test set: the new corroboration suite,
      `test-phase-heading-patterns.sh`, and `test-orchestrate-triage-classify.sh`.
- [ ] Run `bash scripts/verify-deploy.sh` in the scratch tree and confirm all gates pass,
      including the task-reference lint gate over the newly edited deliverables.
- [ ] Engine-agreement audit: grep all three engines for the corroboration call and confirm each
      calls the shared function with the same precondition shape. Record any remaining divergence
      in-file as deliberate, in the style of the multi-task `blocked`-row divergence — an
      undocumented divergence is a phase failure.
- [ ] Walk the stated verification bar item by item and record the evidence for each of the three
      required fixtures in the implementation summary.
- [ ] Confirm no file under `.claude/**` was written by any phase
      (`git status --short` shows only `agent-system/extensions/core/**` and `specs/**`).

**Timing**: 1.25 hours

**Depends on**: 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: "Three engines" is asserted as the complete set of corroboration consumers.
Confirm at implementation time with
`grep -rln "skill_corroborate_phase_counts" agent-system/extensions/core/`; any consumer outside
the three engines and the test suite is either brought into the audit or explained.

**Files to modify**:
- None (verification only). Any defect found is fixed in the owning phase's file and re-verified.

**Verification**:
- Every `bash -n` invocation exits 0.
- All three test suites exit 0 in the scratch tree.
- `verify-deploy.sh` exits 0 in the scratch tree.
- The three verification-bar fixtures each have recorded evidence.
- The live `.claude/` tree is unmodified.

---

## Testing & Validation

- [ ] Handoff reports `implemented` with null phase counts + plan fully closed -> completion
      ALLOWED, `[UNVERIFIED PHASES CORROBORATED]` banner emitted.
- [ ] Handoff reports `implemented` with null phase counts + plan partially closed -> completion
      REFUSED.
- [ ] Plan has zero conforming phase headings -> completion REFUSED, non-conforming warning
      emitted.
- [ ] `phases_total > 0` and incomplete -> completion REFUSED (Case 1 untouched).
- [ ] `[COMPLETED WITH EXCLUSIONS]` counts as closed, matching the shared library's DONE
      alternation.
- [ ] `bash -n` clean on every edited file's embedded bash.
- [ ] `test-corroborate-phase-counts.sh`, `test-phase-heading-patterns.sh`, and
      `test-orchestrate-triage-classify.sh` all exit 0.
- [ ] `verify-deploy.sh` passes in the scratch tree, including the task-reference lint gate.
- [ ] The three engines agree, or any remaining divergence is documented in-file as deliberate.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` (modified) - `skill_corroborate_phase_counts()`
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` (new)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified) - Stage 5, Stage
  MT-4, `## MUST NOT (Context Flatness Constraint)`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified) - Stage 5,
  `## Tool Constraints (Pure Dispatcher)`
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified) - handoff section
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified) - Handoff Writers note
- `specs/968_corroborate_phase_counts_on_handoff_present_path/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase commits independently to the source store, and `.claude/` is never written, so no
live orchestration behavior changes until a deliberate redeploy after Phase 8. Rollback is a
`git revert` of the phase commits in reverse order; because `skill_gate_completion_claim` is
untouched, reverting only the `SKILL.md` wiring restores the prior fail-closed behavior exactly,
leaving the shared function as harmless dead code. If Phase 7's refactor proves risky, it can be
reverted alone without affecting the core fix delivered by Phases 1 and 4-6. If a `SKILL.md` edit
is found broken after redeploy, revert that single file to its pre-task state and re-run the
deploy sync — the engines are independent files and one may be rolled back without the others.
