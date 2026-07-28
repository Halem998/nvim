# Implementation Plan: Task #937

- **Task**: 937 - forward_progress_invariant_for_batch_admission
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 935 (narrow self-modifying defer and override flag) — COMPLETED and deployed
- **Research Inputs**: specs/937_forward_progress_invariant_for_batch_admission/reports/01_forward-progress-invariant-batch-admission.md
- **Artifacts**: plans/01_zero-dispatch-forward-progress-legibility.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A `/orchestrate` batch in which every validated candidate is deferred currently renders as an
ordinary result: three empty tables, `Succeeded: 0 / Failed: 0 / Skipped: 0`, and no visible
statement of why. This plan makes that outcome loud, named, and actionable across all three
surfaces that can produce it (the skill's postflight, the command's consolidated output, and the
`--dry-run` reporter), and records the invariant as a standing requirement in the guardrails
document. **No admission verdict changes.** Definition of done: a zero-dispatch invocation prints
a distinct banner naming every deferred candidate with its `defer_reason` and the exact
dependency-ordered solo re-run command sequence, on both the live and dry-run paths; the
guardrails document names the invariant; every admission decision is byte-for-byte what it was
before.

### Research Integration

Five findings from the research report drive the phase structure:

1. **The defect is a rendering gap, not a logic gap.** `commands/orchestrate.md`'s Consolidated
   Output template has sections for Succeeded / Failed / Skipped / `Deferred (redeploy
   checkpoint)` but **no section for self-modifying deferrals**, despite
   `skill-orchestrate/SKILL.md` Stage MT-5 step 3 explicitly instructing that they be reported.
   Closing that prose/template mismatch is a named deliverable (Phase 4).
2. **The detection primitive already exists, unused.** `mt_state_file.dispatch_start_ts` is
   written only at actual dispatch (three call sites in Stage MT-4). Non-empty validated
   candidates plus an empty `dispatch_start_ts` at loop exit IS the invariant — no new
   dispatch-side bookkeeping.
3. **The status enum is normatively closed.** Add a `forward_progress_violated` field, never a
   seventh `status` value.
4. **The zero-dispatch case is a TRUE POSITIVE of a correctly-working gate.** The predecessor's
   narrowing removed a false-positive trigger; it did not and could not remove the case of
   several independent self-modifying candidates genuinely sharing one cycle. Scope A-F is
   therefore live and unshrunk — and the legibility fix protects a correct decision.
5. **`--dry-run` computes admission in one static whole-batch pass** while the live path
   recomputes per cycle against a shrinking `${#eligible_tasks[@]}`. That divergence is
   deliberate and documented. Scope E targets rendering and vocabulary parity, never
   verdict-set identity (Phase 5).

### Prior Plan Reference

No prior plan for this task. The immediately-preceding dependency task's plan
(`specs/935_narrow_self_modifying_defer_and_override_flag/plans/01_narrow-self-mod-defer-override-flag.md`)
is referenced only for two calibration lessons, not as a template:

- **Late-deploy sequencing works.** That plan confined every `.claude/**` write to a single final
  phase and kept the in-flight run coherent throughout. This plan reuses that shape (Phase 6).
- **The deploy sync defect is real and pre-existing.** Its summary records that
  `deploy-headless.sh`'s picker sync tool silently excludes `skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` from its skills scan, so a plain redeploy leaves those two
  deployed copies stale; it was worked around by copying corrected source directly into
  `.claude/skills/`. This plan's Phase 6 pre-declares the same workaround rather than
  rediscovering it.

### Roadmap Alignment

No ROADMAP.md consultation was requested in the delegation context and no `roadmap_path` was
provided. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Name the forward-progress invariant and its violation outcome once, canonically, and reuse
  those exact strings at every site (Scope A).
- Detect the violation cause-agnostically at Stage MT-5 from `dispatch_start_ts`, and render it
  distinctly at `commands/orchestrate.md` Step 5 — both loci, per Scope A's own phrasing.
- Enumerate every deferred/excluded candidate with its `defer_reason` in the no-dispatch report,
  including the `file_scope_collision` and out-of-batch-predecessor causes that are currently
  logged inline and lost (Scope B).
- Print the exact dependency-ordered solo re-run command sequence (Scope B).
- Confirm and record — never change — the defer-not-fail exit/status contract (Scope C).
- Decide PRINT-ONLY on auto-degradation, with the justification recorded, not asserted (Scope D).
- Give the `--dry-run` reporter the same banner, the same vocabulary, and the same re-run
  sequence format (Scope E).
- Record the invariant in `context/patterns/batch-orchestration-guardrails.md` as a standing
  requirement (Scope F).

**Non-Goals**:

- **Changing any admission decision.** No verdict, no `defer_reason`, no
  `--invocation-count` argument, no eligibility condition, no critical-paths data changes.
- Re-litigating the predecessor's narrowing, the `deferred_self_modifying` observation-log
  semantics, the `consecutive_no_dispatch_cycles` guard's trigger condition, or the
  `--allow-self-modifying` flag.
- Adding a status enum value to `.return-meta*.json`.
- Auto-executing the solo re-run sequence, or offering to.
- Forcing `--dry-run` and the live path to produce identical verdict sets.
- Editing `skills/skill-orchestrate-hard/SKILL.md`, `scripts/orchestrate-batch-admit.sh`,
  `context/reference/orchestrator-critical-paths.json`, or
  `context/formats/return-metadata-file.md` — all outside the declared file scope.
- Extending the invariant to single-task `/orchestrate` mode, which has no wave/admission
  concept at all.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The loud banner over-triggers on an ordinary partial-success batch (2 of 3 dispatched, 1 deferred), devaluing it | H | M | Gate strictly on the precise invariant — validated candidates non-empty AND zero tasks ever dispatched — never on "any deferral present". Phase 4 and Phase 5 each carry an explicit negative test for the 2-of-3 case. |
| The new observation ledger gets read by an eligibility or admission condition later, silently becoming a fifth gate | H | M | State the MUST NOT in the schema definition itself (Phase 2), and verify by grep in Phase 6 that the ledger field name appears in no eligibility, all-terminal, circuit-breaker, or admission-branch condition. |
| Drifting into re-litigating the gate while "improving legibility" | H | M | Non-Goals above are binding. Phase 6 diffs every touched file for admission-affecting changes and must find none; any such change is reverted, not justified. |
| Self-hosting: editing orchestrator machinery inside a live `/orchestrate` session | H | H | Every phase before Phase 6 writes only under `agent-system/extensions/core/`. The live `.claude/` tree keeps coherent pre-change copies for the whole run. One deliberate redeploy, late, in Phase 6. |
| A plain redeploy leaves `.claude/skills/skill-orchestrate/SKILL.md` stale because of the known picker-sync defect, so verification reads a pre-change file and falsely passes | H | H | Pre-declared in Phase 6: after `deploy-headless.sh`, copy the corrected source directly to `.claude/skills/skill-orchestrate/SKILL.md` as a sanctioned late-phase exception, then verify against the corrected deployed copy. Do not fix the sync tool here — out of scope. |
| The hard-mode skill has no MT `dispatch_start_ts` map, so the command-side fallback mis-fires or silently no-ops under `--hard` | M | M | Three-branch, all-non-silent resolution in Phase 4: structured field if present; `dispatch_start_ts` fallback if present; explicit "not evaluable" notice if neither. Phase 2 records the finding and the deliberate asymmetry. |
| Correcting the MT-5 `exit_status` computation (see Phase 3) is mistaken for a behavior change | M | M | Frame and verify it as status legibility: no admission verdict, no task status, and no `state.json` write changes; only the skill-status string reported for an outcome that already dispatched nothing. Record the reasoning in the guardrails entry. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Name the invariant and record the standing requirement [COMPLETED]

**Goal**: Fix the vocabulary once, in the guardrails document, so every later phase quotes rather
than re-derives it; and satisfy Scope F, Scope C's record-don't-change obligation, and Scope D's
justify-don't-assert obligation in prose before any behavior is touched.

**Tasks**:

- [x] Add a new `### The Forward-Progress Invariant` subsection to
      `context/patterns/batch-orchestration-guardrails.md`, sized and weighted like the existing
      `### The Inter-Cycle Redeploy Checkpoint` subsection, placed after
      `## Defer-Not-Fail: The Standing Default` (the invariant is a consequence of defer-not-fail,
      so it reads in sequence) and before `## Non-Negotiables`. *(completed)*
- [x] **Name the invariant** in that subsection, and use these exact strings everywhere
      afterwards: *(completed)*
      - Invariant name: **forward-progress invariant**.
      - Violation outcome name: **zero-dispatch outcome**.
      - Structured field name: `forward_progress_violated` (boolean).
      - Observation ledger field name: `defer_ledger`.
      - Human-facing banner: `[ZERO DISPATCH - 0 of N validated candidates dispatched;
        forward-progress invariant violated]`.
      - Machine-readable marker:
        `<!-- forward-progress violated=true dispatched=0 validated=N -->`.
- [x] **State the invariant precisely and cause-agnostically**: the validated-candidate set was
      non-empty AND no task was dispatched on any cycle of the invocation. Record that the
      operational test is `mt_state_file.dispatch_start_ts == {}` at loop exit, and that this
      needs no new dispatch-side bookkeeping because that map is already written only at actual
      dispatch. *(completed)*
- [x] **Record the detection/rendering split**: detection is computed in the skill's Stage MT-5
      (single source of truth over `mt_state_file`); rendering is the command's Step 5 (the
      human-facing surface); the `--dry-run` reporter renders the same vocabulary for its own
      static analysis. Name all three loci. *(completed)*
- [x] **Record the relationship to the existing convergence guard**: the
      `consecutive_no_dispatch_cycles` guard prevents ONE specific non-convergence mode (a
      mutually-colliding self-modifying set spinning to the cycle cap); the forward-progress
      invariant is the GENERAL outcome-legibility requirement covering every cause, including
      `file_scope_collision` (both `in_batch` and `cross_batch`), out-of-batch unmet
      predecessors, and redeploy-checkpoint deferrals. State explicitly that this task does NOT
      widen the guard's trigger — the guard's condition stays exactly as it is, and the invariant
      is detected independently at loop exit. *(completed)*
- [x] **Record the empirical finding** that the predecessor's same-cycle narrowing did not shrink
      this requirement: the remaining zero-dispatch cases are demonstrated true positives of the
      gate working as designed, not artifacts of an over-broad prior rule. Cite the mechanism
      class (several independent self-modifying candidates with no dependency edges to serialize
      them), never a task number. *(completed)*
- [x] **Record the exit/status contract (Scope C), as a CONFIRMED FACT, not a change**: a
      zero-dispatch invocation does not mutate `specs/state.json`, does not add any task to
      `failed_tasks`, and does not mark any task failed or blocked — this is the standing
      defer-not-fail default applied to this outcome, and it is unchanged by this work. Record
      also that a no-dispatch cycle DOES consume a cycle (`cycle_count` increments unconditionally
      at Stage MT-3 step 6, after dispatch), and that this too is unchanged. *(completed)*
- [x] **Record the PRINT-ONLY decision (Scope D)** as a new entry in the existing
      `## Rejected Approaches` section: auto-degrading a zero-dispatch batch into N sequential
      solo invocations is rejected. Justification, all three parts stated: (a) each solo run pays
      its own full research/plan/implement dispatch cost, so silent conversion multiplies cost
      without consent; (b) this system has zero synchronous confirmation gates by design (see the
      existing `## Divergence from External Practice` section), so there is no place to obtain
      that consent mid-run — the absence of a gate is a reason to take the SMALLER action, not
      licence to take the bigger one; (c) it inverts defer-not-fail's proportionality logic, which
      exists to make the system's response to a transient scheduling conflict smaller than the
      conflict, not larger. The report prints the sequence; the human runs it. *(completed)*
- [x] Add the new subsection to the document's `## Related Documents` cross-references only if an
      existing entry becomes inaccurate; do not add a redundant entry. *(completed: no existing
      entry became inaccurate — skipped as directed, no redundant entry added)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  `### The Forward-Progress Invariant` subsection; one new entry under `## Rejected Approaches`.

**Verification**:

- The subsection exists and defines all six canonical strings listed above.
- `grep -c "forward-progress invariant"` in the file is non-zero.
- The document still states principles only: no mechanism is defined here that is also defined in
  a later phase's file (the "stated exactly once each" convention of its `## Related Documents`
  section holds).
- No admission mechanism, threshold, or condition is described as changing anywhere in the new
  text.

---

### Phase 2: Skill-side schema — defer ledger and invariant field [COMPLETED]

**Goal**: Give `mt_state_file` the two fields the report needs, and instrument the existing defer
branches to populate the ledger — additively, with the existing `deferred_self_modifying` and
`deferred_deploy_checkpoint` fields and their semantics untouched.

**Tasks**:

- [x] In `skills/skill-orchestrate/SKILL.md` Stage MT-1's `mt_state_file` initialization list, add
      two fields alongside the existing ones:
      - `defer_ledger: []` — an APPEND-ONLY OBSERVATION LOG of every per-cycle defer/exclusion
        event, entries of the form
        `{"task": <int>, "defer_reason": <string>, "collision_scope": <string|null>, "cycle": <int>, "detail": <string>}`.
      - `forward_progress_violated: false` — initialized false, computed and written once at
        Stage MT-5 (Phase 3). Never read by any loop condition. *(completed)*
- [x] State, in the `defer_ledger` field definition itself, the binding MUST NOT: **the ledger is
      never read by any eligibility check, all-terminal check, circuit breaker, convergence guard,
      or admission branch.** It is written for reporting and read only at Stage MT-5 and by
      `commands/orchestrate.md` Step 5. It is not a fifth admission gate and must never become
      one. *(completed)*
- [x] State that `defer_ledger` is ADDITIVE to `deferred_self_modifying` and
      `deferred_deploy_checkpoint`, not a replacement: a self-modifying defer appends to BOTH the
      existing observation log and the ledger, and the two existing fields keep their current
      semantics, consumers, and Stage MT-5 role byte-for-byte. *(completed)*
- [x] In Stage MT-3 step 4.5, add one ledger-append instruction to each existing defer branch,
      immediately after (never before, never in place of) that branch's existing removal-and-log
      behavior, which stays byte-for-byte:
      - `self_modifying` branch (no-override path only — a bypassed defer dispatches and must NOT
        be ledgered as a defer): `defer_reason: "self_modifying"`, `collision_scope: null`,
        `detail` naming the matched critical path and label.
      - `file_scope_collision` / `in_batch`: `defer_reason: "file_scope_collision"`,
        `collision_scope: "in_batch"`, `detail` naming the colliding in-batch task.
      - `file_scope_collision` / `cross_batch`: `defer_reason: "file_scope_collision"`,
        `collision_scope: "cross_batch"`, `detail` naming the out-of-batch task and its
        `colliding_task_status`. *(completed)*
- [x] In Stage MT-3 step 7's failure path, add a ledger append for each task added to
      `deferred_deploy_checkpoint` — `defer_reason: "deploy_checkpoint"`, `collision_scope: null`,
      `detail` naming the failed gate and its exit code — again immediately after, and without
      altering, the existing behavior. *(completed)*
- [x] Confirm and record whether `skills/skill-orchestrate-hard/SKILL.md` has a multi-task mode
      that writes `mt_state_file.dispatch_start_ts`. Record the finding as a short note in the
      Stage MT-1 schema text stating that the hard variant is deliberately not modified by this
      change and how the command-side rendering degrades for it (see Phase 4's three-branch
      resolution). Do not edit the hard skill. *(completed: confirmed by grep and reading Stage 0 —
      skill-orchestrate-hard/SKILL.md has no MT-stage implementation of its own; its Stage 0
      delegates multi-task mode to these same base Stage MT-1..MT-5 stages, so it already inherits
      dispatch_start_ts/defer_ledger/forward_progress_violated with no hard-skill edit needed; the
      dispatch_start_ts occurrences local to skill-orchestrate-hard/SKILL.md are unrelated
      single-task shell variables. Finding recorded in Stage MT-1 text; hard skill file untouched)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: exactly THREE defer branches exist in Stage MT-3 step 4.5 needing a ledger
append (`self_modifying`, `file_scope_collision`/`in_batch`, `file_scope_collision`/`cross_batch`),
plus ONE in step 7's failure path — four append sites total. Confirm at implementation time by
enumerating every branch under step 4.5's `defer_reason` dispatch and step 7's failure path before
editing; if a fifth defer path exists, ledger it too and record the correction here rather than
silently leaving it uninstrumented.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 schema additions;
  four ledger-append instructions in Stage MT-3 steps 4.5 and 7.

**Verification**:

- Both new field names appear in the Stage MT-1 initialization list with their definitions.
- The `defer_ledger` MUST NOT sentence is present verbatim in the schema definition.
- The pre-existing text of every defer branch (removal from batch, never-fail, never-status-mutate,
  the exact warning strings) is unchanged — confirm by reading the diff hunk-by-hunk, not by
  reasoning about intent.
- `deferred_self_modifying` and `deferred_deploy_checkpoint` occurrences in eligibility, all-terminal,
  and circuit-breaker conditions are numerically and textually unchanged from before this phase.
- The hard-skill finding is recorded, and `git diff --stat` shows zero changes to
  `skills/skill-orchestrate-hard/SKILL.md`.

---

### Phase 3: Skill-side detection, status contract, and metadata field [COMPLETED]

**Goal**: Compute the invariant once at Stage MT-5, correct the exit-status computation so a
zero-dispatch outcome can never report success, and surface the result structurally in
`.return-meta-multi.json`.

**Tasks**:

- [x] In Stage MT-5 step 1, add `dispatch_start_ts` and `defer_ledger` to the list of fields read
      from `mt_state_file`. *(completed)*
- [x] Add a new step computing the invariant, before the `exit_status` determination: set
      `forward_progress_violated = true` when `task_numbers` is non-empty AND `dispatch_start_ts`
      is an empty object at loop exit; otherwise `false`. Write it back to `mt_state_file` so the
      command's Step 5 can read it. State that this is cause-agnostic by construction — it is true
      regardless of which defer reason produced it. *(completed: new step 2)*
- [x] Amend the `exit_status` determination so that `forward_progress_violated == true` forces
      `"partial"` (and preserves `mt_state_file` for diagnostics), taking precedence over the
      existing `"implemented"` branch. Record, inline, WHY this is needed: the existing conditions
      key on `failed_count`, non-terminal `deferred_self_modifying` residue, and
      `deferred_deploy_checkpoint` emptiness, so a batch that dispatched nothing because every
      candidate hit `file_scope_collision` would otherwise satisfy the `"implemented"` branch with
      an empty `completed_tasks` array. State explicitly that this is a **status-legibility
      correction, not an admission or behavior change**: no verdict, no task status, no
      `state.json` write, and no loop condition is affected — only the skill-status string
      reported for an outcome that already dispatched nothing. *(completed)*
- [x] Amend Stage MT-5 step 3's reporting instruction to require, when
      `forward_progress_violated` is true, that the consolidated summary lead with the zero-dispatch
      banner and enumerate every `defer_ledger` entry with its `defer_reason`. Keep the existing
      `deferred_self_modifying` observation-log and `deferred_deploy_checkpoint` reporting
      instructions unchanged; the new requirement is additive. *(completed)*
- [x] Restate at this stage, as a confirmed invariant, that a zero-dispatch outcome mutates no
      `specs/state.json` status and adds nothing to `failed_tasks` — referencing the guardrails
      subsection from Phase 1 by name rather than restating its reasoning. *(completed)*
- [x] Add `forward_progress_violated` and `defer_ledger` to the `.return-meta-multi.json`
      `metadata` object in Stage MT-5 step 4's `jq -n` construction, alongside the existing
      `tasks_deferred_self_modifying` / `tasks_deferred_deploy_checkpoint` keys. The top-level
      `status` field keeps its existing closed vocabulary and gains no new value. *(completed:
      jq -e . verified against a synthetic input with all fields populated)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-5 steps 1-4.

**Verification**:

- `jq -e .` passes on the amended Stage MT-5 `jq -n` construction, exercised against a synthetic
  input with all fields populated.
- The `status` values enumerated anywhere in the amended stage remain drawn from the existing
  closed set; grep confirms no new status string was introduced.
- A hand-traced zero-dispatch case (validated candidates present, `dispatch_start_ts` empty,
  `failed_tasks` empty, `deferred_self_modifying` empty, `deferred_deploy_checkpoint` empty) now
  resolves to `"partial"` with `forward_progress_violated: true` — the exact case that previously
  resolved to `"implemented"`.
- A hand-traced ordinary partial-success case (2 of 3 dispatched, 1 deferred) yields
  `forward_progress_violated: false` and an unchanged `exit_status`.
- No text in Stage MT-3's loop was modified by this phase (`git diff` scoped to the stage headings).

---

### Phase 4: Command-side rendering — banner, tables, and re-run sequence [NOT STARTED]

**Goal**: Make the human-facing consolidated output impossible to mistake for an ordinary result,
close the documented `Deferred (self-modifying)` template gap, and print the exact solo re-run
sequence in dependency order.

**Tasks**:

- [ ] In `commands/orchestrate.md` Step 5's `mt_state_file` read block, additionally read
      `forward_progress_violated`, `defer_ledger`, and `dispatch_start_ts`.
- [ ] Implement the three-branch, all-non-silent resolution of the invariant, so rendering works
      regardless of which skill ran:
      1. `forward_progress_violated` present in `mt_state_file` — use it directly.
      2. Field absent but `dispatch_start_ts` present — compute the invariant here from
         `dispatch_start_ts == {}` AND a non-empty validated-candidate set.
      3. Neither present — print an explicit
         `[orchestrate] forward-progress invariant not evaluable (no dispatch_start_ts in multi-state file)`
         notice and render the ordinary output. Never silently skip.
      Also handle the existing missing-multi-state-file branch: it already sets
      `failed_count=${#validated_tasks[@]}`, which is not a zero-dispatch outcome — do not fire the
      banner there.
- [ ] Insert a new `### ZERO DISPATCH` section into the Consolidated Output template, placed
      immediately after the counts block (`Session` / `Tasks requested` / ... / `Cycles used`) and
      **before** `### Succeeded`, rendered only when the invariant is violated. It contains, in
      order:
      - The banner line
        `[ZERO DISPATCH - 0 of {N} validated candidates dispatched; forward-progress invariant violated]`.
      - The machine-readable marker
        `<!-- forward-progress violated=true dispatched=0 validated={N} -->`.
      - One sentence stating this is not a failure: no task was marked failed or blocked and
        `specs/state.json` was not mutated.
      - A `| Task | defer_reason | Detail |` table with one row per `defer_ledger` entry, so every
        excluded candidate is named with its reason.
      - A `Re-run sequence (dependency order; printed, not executed)` block emitting one literal
        `/orchestrate {N}` line per deferred candidate, predecessor-first.
- [ ] Derive the re-run sequence from the `waves` / `dependency_graph` this command already
      computed at Steps 2-3 and still has in scope at Step 5 — reuse that topological order, do
      not recompute or reimplement Kahn's algorithm. Order tasks ascending by number within a wave
      for determinism. State in the template that these commands are printed for the operator to
      run, and are never executed automatically (cross-reference the Phase 1 `## Rejected
      Approaches` entry by name).
- [ ] Add the missing `### Deferred (self-modifying)` table section to the Consolidated Output
      template, alongside the existing `### Deferred (redeploy checkpoint)` section, closing the
      Stage MT-5-prose-versus-template mismatch. Populate from `tasks_deferred_self_modifying`,
      with each task's final status at loop exit, and the observation framing Stage MT-5 already
      mandates ("deferred at least one cycle by the self-modification gate — an OBSERVATION"). This
      section renders on every batch, not only zero-dispatch ones.
- [ ] Add a `### Deferred (other admission exclusions)` table for `defer_ledger` entries whose
      `defer_reason` is neither `self_modifying` nor `deploy_checkpoint`, so
      `file_scope_collision` deferrals are visible on ordinary partial batches too, not only in
      the zero-dispatch banner.
- [ ] Extend the existing `### Next Steps` line so it does not read as the only remedy when the
      banner fired: when the invariant is violated there are no failed tasks to re-run, so point
      at the re-run sequence above instead.
- [ ] Leave the Exit-path coverage table's existing rows unchanged; add no admission-affecting
      text anywhere in this file.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: the Consolidated Output template currently contains exactly FOUR table
sections (`Succeeded`, `Failed`, `Skipped`, `Deferred (redeploy checkpoint)`) and no
self-modifying section. Confirm by enumerating `### ` headings inside the template's fenced block
before editing; if the count differs, reconcile against the actual headings rather than assuming
this hypothesis.

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` — Step 5 read block, three-branch
  resolution, new `### ZERO DISPATCH` section, new `### Deferred (self-modifying)` and
  `### Deferred (other admission exclusions)` sections, amended `### Next Steps`.

**Verification**:

- The template renders the banner and marker only under the precise invariant; a hand-traced
  2-of-3-dispatched batch produces no banner and no marker.
- A hand-traced zero-dispatch batch produces the banner, the marker, one ledger row per deferred
  candidate, and a re-run sequence whose order matches the wave order computed at Step 3
  (predecessor before dependent).
- All three resolution branches, including the not-evaluable one, produce visible output — grep
  confirms no branch falls through to silence.
- The banner section is positioned before `### Succeeded` in the template.
- `### Deferred (self-modifying)` now exists, closing the mismatch with the skill's Stage MT-5
  step 3 instruction.
- No wave-split-check prose in this file was re-touched or duplicated (that text landed with the
  predecessor task and is out of bounds here) — confirm by `git diff` scoped to Steps 2-3.

---

### Phase 5: Dry-run reporter parity [COMPLETED]

**Goal**: Make the report a human uses to preview a batch and the report they get from a live run
agree on how "nothing will dispatch" renders — same banner, same marker, same re-run sequence
format — while explicitly recording that verdict-set identity is NOT claimed.

**Tasks**:

- [x] In `scripts/orchestrate-dry-run-report.sh`, emit the zero-dispatch banner and the
      machine-readable marker immediately after the `=== /orchestrate --dry-run admission report ===`
      title line and before `-- Header --`, conditioned on `${#admitted_tasks[@]} -eq 0` with a
      non-empty `validated_tasks`. Emitting it as an unnumbered banner rather than a new section
      preserves sections 1-7's existing order and numbering byte-for-byte, which several documents
      already name. *(completed)*
- [x] Use the identical banner and marker strings fixed in Phase 1 — differing only in the
      substituted counts. Do not invent a dry-run-specific wording. *(completed)*
- [x] Replace the `-- Recommended split --` section's `no admitted tasks — nothing to split` line
      with the dependency-ordered solo re-run sequence, in the same
      `Re-run sequence (dependency order; printed, not executed)` format Phase 4 uses, derived from
      the wave assignment this script already computes at its Step 3. Keep the existing
      `batch of one — no split applicable` and per-wave branches unchanged. *(completed)*
- [x] Add one `-- Notes --` entry, emitted only in the zero-dispatch case, recording the
      static-versus-cycling divergence: this report computes admission in a single pass with
      `--invocation-count` set to the whole validated set's size, while a live run recomputes per
      cycle against a shrinking eligible set, so the live run may admit tasks this report excludes.
      State that the two surfaces are aligned on rendering and vocabulary, not on verdict sets.
      *(completed)*
- [x] Update the script's header comment block to describe the banner, the marker, and the changed
      `Recommended split` content — the header explicitly enumerates report sections and their
      order, so leaving it stale would itself be a legibility defect. *(completed)*
- [x] Change nothing about the admission call: the `orchestrate-batch-admit.sh` invocation, its
      `--invocation-count` argument, the exclusion composition, and every exit code stay
      byte-for-byte. *(completed: verified by git diff — no hunk touches the
      orchestrate-batch-admit.sh call site or arguments)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the reporter prints exactly SEVEN numbered sections in a fixed order that
must be preserved. Confirm by enumerating the `echo "-- ... --"` lines before editing; if the count
or order differs from the header comment, reconcile to the actual code and note the header drift.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — header comment block,
  banner/marker emission, `-- Recommended split --` empty-admitted branch, one conditional note.

**Verification**:

- `bash -n` clean on the source-store copy.
- Executable smoke test against a scratch deploy-shaped tree (the same technique the predecessor
  task used to avoid touching the live deploy tree), covering three cases: (a) zero admitted →
  banner, marker, and a dependency-ordered re-run sequence all present; (b) all admitted → no
  banner, no marker, `0 excluded` line intact; (c) partial admission → no banner, existing wave
  split intact.
- Exit codes unchanged: 0 for any printed report regardless of exclusion count, 2 for usage errors
  and the all-not-found/terminal case.
- The banner string is byte-identical to the live path's, modulo substituted counts — confirm by
  diffing the two literal templates.
- `git diff` shows zero changes to the `orchestrate-batch-admit.sh` call site or its arguments.

---

### Phase 6: Consistency sweep, deliberate redeploy, final gates [NOT STARTED]

**Goal**: Confirm the four files are mutually consistent and admission-neutral, then perform the
single deliberate redeploy — accounting explicitly for the known picker-sync defect — and run the
full gate set against the live system. This is the only phase permitted to write under `.claude/`.

**Tasks**:

- [ ] Consistency sweep across all four files: the invariant name, the outcome name,
      `forward_progress_violated`, `defer_ledger`, the banner string, and the marker string must
      each be spelled identically at every occurrence.
- [ ] **Admission-neutrality audit** (the binding constraint of this task): for each of the four
      files, read the full diff and confirm no hunk changes an admission verdict, a
      `defer_reason`, an `--invocation-count` argument, an eligibility condition, an all-terminal
      condition, a circuit-breaker condition, the convergence guard's trigger, or the
      critical-paths data. Any such hunk is reverted, not justified.
- [ ] **Defer-not-fail confirmation** (Scope C, confirm-and-record): grep the diffs for any new
      write to `specs/state.json`, any new `failed_tasks` append, and any new status mutation on a
      deferred task. Expected result: zero. Record the confirmation in the implementation summary.
- [ ] Verify the `defer_ledger` MUST NOT held: grep `skills/skill-orchestrate/SKILL.md` for every
      `defer_ledger` occurrence and confirm each is a write, a schema definition, or a Stage MT-5
      read — never a term in an eligibility, all-terminal, circuit-breaker, or admission condition.
- [ ] Confirm the source-store boundary held: `git diff --stat` over every commit for this task
      shows zero `.claude/` paths BEFORE the redeploy step below.
- [ ] Run the no-task-references sweep over every file touched outside `specs/`. Distinguish
      pre-existing hits from newly introduced ones via `git diff`; fix only what this change
      introduced, and record any pre-existing hits without fixing them.
- [ ] `bash -n` on `scripts/orchestrate-dry-run-report.sh` (source-store copy).
- [ ] Perform ONE deliberate redeploy: `bash .claude/scripts/deploy-headless.sh`, then
      `bash .claude/scripts/verify-deploy.sh`. Log it explicitly as a conscious, one-time
      invocation matching this plan's Rollback/Contingency — not a routine practice.
- [ ] **Pre-declared sync-defect workaround**: `deploy-headless.sh`'s picker sync tool has a
      pre-existing defect excluding `skill-orchestrate/SKILL.md` from its skills scan, so the
      redeploy above leaves the deployed copy stale. Immediately after the redeploy, copy the
      corrected source directly to `.claude/skills/skill-orchestrate/SKILL.md` and verify the copy
      by diffing it against the source. This is a sanctioned late-phase exception to the
      source-store rule, matching the precedent set by the predecessor task. **Do not fix the sync
      tool here** — it is out of this task's declared file scope; recommend a follow-up task
      instead. `skill-orchestrate-hard/SKILL.md` is untouched by this task and needs no copy.
- [ ] After redeploy: `bash .claude/scripts/check-extension-docs.sh` must exit 0 (it is EXPECTED to
      FAIL on source/deploy drift for every prior phase; only here is a PASS required).
- [ ] After redeploy: `bash -n` on the deployed copy of the dry-run reporter, and confirm the
      deployed `commands/orchestrate.md` and `context/patterns/batch-orchestration-guardrails.md`
      contain the new sections.
- [ ] `bash .claude/scripts/validate-artifact.sh` against this plan file: PASS.

**Timing**: 1 hour

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: exactly FOUR source-store files are modified by this task
(`commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
`scripts/orchestrate-dry-run-report.sh`, `context/patterns/batch-orchestration-guardrails.md`), and
exactly ONE of them (`skill-orchestrate/SKILL.md`) needs the direct-copy workaround. Confirm both
counts against `git diff --name-only` and against the sync tool's actual behavior on this run
before asserting the workaround was necessary; if the sync defect has since been fixed, record that
and skip the copy rather than performing it blindly.

**Files to modify**:

- None in the source store. The redeploy writes `.claude/**` as a deploy artifact by design, which
  is the sanctioned exception to the source-store rule; the direct copy above is the second,
  pre-declared exception.

**Verification**:

- All four declared source-store files confirmed present and modified; no fifth file touched.
- Zero `.claude/` paths in any pre-redeploy commit for this task.
- Admission-neutrality audit produced zero findings.
- Defer-not-fail confirmation produced zero findings.
- `verify-deploy.sh` exit code recorded and compared against the pre-change baseline (a pre-existing
  non-zero baseline is not a regression; a NEW non-zero is).
- `check-extension-docs.sh` exits 0.
- The deployed `skill-orchestrate/SKILL.md` diffs clean against its source-store copy.

---

## Testing & Validation

- [ ] Zero-dispatch trace (live path): validated candidates non-empty, `dispatch_start_ts` empty →
      banner, marker, one ledger row per deferred candidate, dependency-ordered re-run sequence,
      `exit_status == "partial"`, `forward_progress_violated: true`.
- [ ] Negative trace (live path): 2 of 3 dispatched, 1 deferred → no banner, no marker,
      `forward_progress_violated: false`, unchanged `exit_status`, and the deferred task visible in
      the appropriate `Deferred (...)` table.
- [ ] Collision-only zero-dispatch trace: `deferred_self_modifying` and
      `deferred_deploy_checkpoint` both empty, every candidate deferred by `file_scope_collision` →
      `"partial"`, not `"implemented"` (the status-legibility correction of Phase 3).
- [ ] Not-evaluable trace: `mt_state_file` present without `dispatch_start_ts` → explicit notice
      printed, ordinary output rendered, no banner.
- [ ] Dry-run smoke test, three cases (zero admitted / all admitted / partial admission), run
      against a scratch deploy-shaped tree, never the live deploy tree.
- [ ] Banner and marker strings byte-identical between the live template and the dry-run reporter,
      modulo substituted counts.
- [ ] `jq -e .` passes on the amended `.return-meta-multi.json` construction.
- [ ] `bash -n` clean on `orchestrate-dry-run-report.sh` in both source-store and post-redeploy
      deployed form.
- [ ] Admission neutrality: zero diff hunks affecting any admission verdict, condition, or
      argument across all four files.
- [ ] Defer-not-fail: zero new `state.json` writes, `failed_tasks` appends, or status mutations.
- [ ] `defer_ledger` appears in no eligibility, all-terminal, circuit-breaker, or admission
      condition.
- [ ] No task-number citations introduced in any file outside `specs/`.
- [ ] `validate-artifact.sh` PASSes against this plan.

## Artifacts & Outputs

- `specs/937_forward_progress_invariant_for_batch_admission/plans/01_zero-dispatch-forward-progress-legibility.md`
  (this file)
- `specs/937_forward_progress_invariant_for_batch_admission/summaries/01_zero-dispatch-forward-progress-legibility-summary.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  `### The Forward-Progress Invariant` subsection and one `## Rejected Approaches` entry
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 schema additions,
  four Stage MT-3 ledger appends, Stage MT-5 detection / status correction / metadata field
- `agent-system/extensions/core/commands/orchestrate.md` — Step 5 zero-dispatch banner section,
  two new deferral tables, re-run sequence, three-branch resolution
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — banner, marker, re-run
  sequence, divergence note, updated header
- A recommended follow-up task (not created by this plan) for the `deploy-headless.sh` picker-sync
  defect that excludes the two orchestrate SKILL.md files from its skills scan

## Rollback/Contingency

Every phase before Phase 6 writes only under `agent-system/extensions/core/`, so the live `.claude/`
tree keeps coherent pre-change copies for the entire run and an abort at any point leaves the
running orchestrator unaffected. To revert: `git revert` the per-phase commits in reverse order,
then perform one deliberate redeploy plus the direct-copy workaround to restore the deployed tree.

Per-file fallbacks, if a phase proves problematic:

- The four files are independently revertible. Reverting the dry-run reporter (Phase 5) alone
  leaves the live path's legibility fix intact and merely reopens the parity gap.
- Reverting Phase 3's `exit_status` correction alone restores the prior (incorrect but harmless)
  `"implemented"`-on-zero-dispatch behavior without affecting the banner, since the command's Step 5
  can compute the invariant from `dispatch_start_ts` on its own.
- If the `defer_ledger` proves too invasive, the banner can still render from
  `deferred_self_modifying` + `deferred_deploy_checkpoint` alone, at the cost of Scope B's
  "every excluded candidate" completeness for `file_scope_collision` causes — a documented
  degradation, not a silent one.

No rollback path involves changing an admission decision, in either direction.
