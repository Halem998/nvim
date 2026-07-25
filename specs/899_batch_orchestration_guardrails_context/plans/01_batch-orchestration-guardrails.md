# Implementation Plan: Task #899

- **Task**: 899 - Author a batch-orchestration guardrails context pattern from current practice
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/899_batch_orchestration_guardrails_context/reports/01_batch-orchestration-guardrails.md
- **Artifacts**: plans/01_batch-orchestration-guardrails.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task produces exactly ONE new documentation file — a context pattern stating the design
principles that govern admission control for batched `/orchestrate` invocations in this agent
system. The principles already exist implicitly in three shipped mechanisms (creation-time
dependency edges, the runtime wave-split check, and the per-task file lock); what is missing is
the written rationale that downstream admission-machinery work can consult instead of
re-deriving. The deliverable changes no behavior: no skill, command, script, or agent file is
touched, and the file is authored in the source store only.

**Definition of done**: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
exists and is non-empty, contains every required section listed in Phase 1 and Phase 2, contains
zero task-number citations, and `git status --short` shows that file as the only addition or
change anywhere under `agent-system/`.

### Research Integration

The research report is ground truth for this plan and for the deliverable's content. Its five
numbered Decisions map directly onto the deliverable's required sections:

- Decision 1 supplies the blocking-vs-advisory criterion (two conjunctive conditions).
- Decision 2 supplies the batch-scaling rule and the explicitly REJECTED "relax to advisory as
  the batch grows" idea.
- Decision 3 supplies the admission-time vs mid-flight classification as a *knowability* test.
- Decision 4 supplies defer-not-fail as the standing default and its generalization.
- Decision 5 supplies the five non-negotiables.

The report's Risks section supplies the documented divergence between the external
human-in-the-loop literature and this system's actual design (no synchronous confirmation gate
exists in `/orchestrate` at all; escalation is a capped automated fork sequence reviewed by a
human only after the fact). The implementing agent MUST read the report before writing and MUST
NOT re-derive these conclusions independently.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

### Verified Preconditions (from plan-time inspection)

These were checked while planning so the implementing agent does not need to rediscover them:

- `agent-system/extensions/core/manifest.json` registers context by **directory**
  (`provides.context` includes `"patterns"`), so a new file under `context/patterns/` requires
  **no manifest edit**.
- Sibling pattern files (`file-footprint-overlap.md`, `task-lock.md`, `batch-drain-loop.md`) have
  **no entry** in the deployed `context/index.json`, so the new file requires **no index entry**
  either. There is no source-store `index.json` to edit.
- `context/patterns/` has **no README.md**, so there is no sibling listing file to update.

The single-file scope is therefore internally consistent: nothing else needs to change for the
file to be picked up on the next deploy.

## Goals & Non-Goals

**Goals**:

- Write one new context pattern file at
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`.
- State the blocking-vs-advisory criterion and classify this system's existing guardrails under it.
- State how the split changes with batch size (deferral scope, not check existence) and record the
  rejected alternative by name.
- State the admission-time vs mid-flight boundary as a knowability test, with worked examples on
  both sides.
- State defer-not-fail as the standing default for admission conflicts and generalize it.
- State the five non-negotiables verbatim in substance from the research.
- Record the documented divergence between external HITL literature and this system's design.
- Cross-reference mechanism-level documents by path rather than restating their algorithms.

**Non-Goals**:

- Implementing, modifying, or wiring any admission check. No behavior change of any kind.
- Editing `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
  `scripts/task-lock.sh`, `docs/architecture/handoff-schema.md`,
  `docs/reference/standards/multi-task-creation-standard.md`, or any other existing file.
- Editing anything under `.claude/` (gitignored, disposable deploy artifact).
- Resolving the open design fork on out-of-batch dependency edges (exclude the dependent task vs.
  auto-expand the batch). The deliverable flags it as open; it does not decide it.
- Registering the file in any index or manifest (verified unnecessary above).
- Restating the overlap algorithm, the lock protocol, or the handoff schema. Reference by path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer drifts into "fixing" one of the three defects the research names, editing a skill or script | H | M | Phase 3 verification asserts `git status --short` shows exactly one changed path under `agent-system/`; Non-Goals name the forbidden files explicitly |
| Implementer edits or copies into `.claude/**` (deployed tree) | H | M | Source-store rule restated in every phase; `.claude/` is regenerated by a separate manual step, never by this task |
| Task-number citations leak into the deliverable (the research report itself contains one in its Risks section) | M | M | Phase 3 greps the deliverable for task-number patterns; Phase 2 instructs converting any such provenance into a durable anchor (filename + section heading) |
| Deliverable restates mechanism detail already owned by `file-footprint-overlap.md` / `task-lock.md`, creating a second source of truth that can drift | M | M | Phase 2 requires a cross-reference section citing those files by path; Non-Goals forbid restating their algorithms |
| "Relax to advisory as the batch grows" is documented weakly (implied rather than named), and a later pass rediscovers and adopts it | M | L | Phase 2 requires a dedicated, explicitly labelled rejected-approaches section naming it and giving the approval-fatigue reason |
| Over-decomposition or scope creep turns a one-file doc task into a multi-file change | M | L | Three phases only; every phase's verification is file-level and checks the single-file invariant |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase
writes into the same single file, so no two phases may run concurrently.

---

### Phase 1: Author the classification core [COMPLETED]

**Goal**: Create the new file with its framing and its two classification systems — the
blocking-vs-advisory criterion, and the admission-time vs mid-flight knowability test.

**Tasks**:

- [x] Read `specs/899_batch_orchestration_guardrails_context/reports/01_batch-orchestration-guardrails.md`
      in full before writing anything.
- [x] Skim `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` for house
      style (declarative, terse, "defined exactly once, referenced by path" framing).
- [x] Create `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      with a title and a 3-5 sentence purpose statement: this file documents the *principles*
      governing batch admission control; the *mechanisms* live in the files it cross-references;
      it defines no new behavior.
- [x] Write a section describing the three existing admission layers as they actually are today
      (creation-time overlap-derived dependency edges; runtime wave/cycle-split check scoped to
      the current invocation's task set; lock-acquisition-time comparison against currently-held
      locks), naming each layer's scan scope explicitly, and noting that these layers combine a
      cheap optimistic pre-check with a pessimistic enforcement lock.
- [x] Write the **blocking-vs-advisory criterion** section: a guardrail is BLOCKING (refuse to
      dispatch — i.e. defer) if and only if BOTH (a) it is computable purely from on-disk
      structural state without invoking any agent, AND (b) the harm of proceeding anyway is
      silent and hard to detect after the fact. A guardrail is ADVISORY (warn and continue) when
      its signal is inherently a heuristic or estimate, or when the flagged condition is not this
      invocation's to fix. State plainly that ADVISORY never means unlogged or silent.
- [x] Add a classification table applying the criterion to this system's guardrails: file-scope
      overlap, held lock, unmet predecessor (all BLOCKING, both conditions met); heuristic drift
      percentage and absent completion-marker verification signal (ADVISORY, with the reason each
      fails a condition).
- [x] Write the **admission-time vs mid-flight** section, framed as a KNOWABILITY test, not a cost
      test: a problem belongs to admission control if and only if the fact needed to detect it
      already exists on disk before any agent is invoked; it belongs to mid-flight detection if
      and only if that fact does not exist until an agent has acted. Give both lists — file-scope
      collision, stale handoff, held lock, unmet predecessor on the admission side; premature
      completion claims, churn, drift on the mid-flight side — with one clause each saying which
      on-disk fact (or absent fact) puts it there.

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — created in
  this phase (new file; the only file this task writes).

**Verification**:

- The file exists and is non-empty.
- Section headings for the three-layer description, the blocking-vs-advisory criterion, and the
  admission-time-vs-mid-flight knowability test are all present.
- The criterion is stated as a conjunction of two conditions, not a single cost condition.
- `git status --short` shows the new file as the only added or modified path under
  `agent-system/`, and nothing at all under `.claude/`.

---

### Phase 2: Author the scaling rule, defaults, non-negotiables, and divergence [COMPLETED]

**Goal**: Complete the file with the batch-scaling rule and its rejected alternative, defer-not-fail
as the standing default, the five non-negotiables, the documented external-literature divergence,
the open design fork, and the cross-reference section.

**Tasks**:

- [x] Write the **batch-size scaling** section: batch size changes the SCOPE of deferral (defer
      the one colliding task, as the wave-split and lock-refusal paths already do), never the
      EXISTENCE of a check. State the consequence explicitly: a batch of eight never pays more
      than one deferred task for any single conflict, so check existence is orthogonal to the
      batch-size cap.
- [x] Write a clearly labelled **rejected approaches** section whose first entry is
      "relax a blocking check to advisory as the batch grows" (equivalently, indexing check
      strictness to batch size). Give the reason: it imports the approval-fatigue /
      rubber-stamping failure mode — documented for human reviewers under volume — into machine
      admission control, where it does not apply, since a machine overlap check does not get
      harder to run or less necessary as concurrency rises. Name it as rejected, not merely
      discouraged, so a later pass cannot rediscover and adopt it as a tunable.
- [x] Write the **defer-not-fail** section: deferral is the standing default response to every
      admission-time conflict. Ground it in the two existing precedents (the wave/cycle-split
      deferral of the lower-priority task, and the lock-acquisition refusal) and generalize it to
      the two gaps the research identified: a collision with a non-terminal, currently-unlocked
      task outside the batch, and a declared dependency whose target lies outside the batch.
      State the rationale: admission conflicts are transient by construction (they clear when the
      colliding or blocking task terminates), whereas this system's failed/blocked states require
      human intervention to clear — disproportionate for a scheduling conflict.
- [x] Write the **non-negotiables** section as five explicitly enumerated items, never relaxed for
      throughput at any batch size:
      1. Never promote to completed on a bare self-reported implementation status; an outcome
         check on actual plan/artifact marker state must gate it. Self-report is supplementary
         evidence only.
      2. Never narrow file-footprint or lock overlap scanning to the current invocation's task set
         as the only scope; the scan must also reach non-terminal, currently-unlocked tasks
         outside the batch.
      3. Never silently drop a dependency edge because its target is out of batch; at minimum warn
         loudly and exclude the dependent task by default.
      4. Never let human-facing batch approval substitute for or gate machine admission decisions.
         Which tasks may run concurrently is a deterministic, per-pair, machine-checked question.
      5. Never treat the batch-size cap as a correctness control. It bounds human cognitive load
         over the consolidated output, not the soundness of per-pair admission checks; raising it
         is safe only if the human-facing review strategy scales with it.
- [x] Write the **divergence from external practice** section, stated plainly rather than smoothed
      over: the external human-in-the-loop literature assumes a human is available to escalate to
      synchronously during a run. This system assumes the opposite by design — autonomous
      orchestration has zero synchronous confirmation gates between lifecycle phases; escalation
      is a capped automated fork sequence, and human review happens only after the fact via the
      consolidated output and the commit trail. No synchronous batch-approval gate exists here at
      all, and the deliverable must not imply one does.
- [x] Write a short **open design fork** note: for an out-of-batch dependency, whether the right
      response is to exclude the dependent task or to auto-expand the batch to include the
      predecessor is unresolved. Both are defer-not-fail-compatible; they differ in blast radius,
      and an auto-expanded batch would itself need admission checks. Flag as open, do not decide.
      Add the accompanying bounded-scope design note: any widening of the overlap scan should
      follow the existing bounded-scan precedent (compare against a bounded set such as
      non-terminal tasks, never an unbounded scan of every task directory), or it reintroduces the
      very cost problem this pattern exists to prevent.
- [x] Write a **related documents** cross-reference section citing, by path only and without
      restating their content: the overlap-algorithm pattern, the task-lock pattern, the
      orchestrate command and orchestration skill (naming the relevant step/stage headings), the
      handoff schema (for the completion-marker verification field and the token budget any
      mid-flight signal must fit inside), and the multi-task creation standard (for the
      creation-time overlap component).
- [x] Reread the whole file for provenance language: every "why does this exist" reference must
      cite a durable anchor (filename, section heading, mechanism name). Convert any task-number
      provenance carried over from the research report into such an anchor.

**Timing**: ~1 hour

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — extended
  with the sections above. No other file.

**Verification**:

- Section headings for batch-size scaling, rejected approaches, defer-not-fail, non-negotiables,
  divergence from external practice, open design fork, and related documents are all present.
- The non-negotiables section enumerates exactly five items.
- The rejected-approaches section names the batch-size-indexed-advisory idea explicitly.
- No mechanism algorithm (overlap comparison steps, lock protocol steps, handoff field list) is
  restated; those appear only as path references.
- `git status --short` still shows the new file as the only changed path under `agent-system/`.

---

### Phase 3: Verification gate [COMPLETED]

**Goal**: Prove the three invariants that define success — file present and complete, no
task-number citations, no collateral edits.

**Tasks**:

- [x] Confirm the file exists and is non-empty:
      `test -s agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`.
- [x] Confirm every required section heading is present by grepping the file's headings and
      checking them against the Phase 1 and Phase 2 lists. Any missing section is a defect to fix
      in place, not to report as an acceptable gap.
- [x] Grep the deliverable for task-number citation patterns and confirm zero matches:
      `grep -nEi '\b[Tt]asks?[ -]+[0-9]+' agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      (expected: no output). Also check for parenthesized forms such as `(task 809)`.
- [x] Run `git status --short` and confirm the ONLY path listed under `agent-system/` is the new
      file (shown as untracked or added). Pre-existing modifications elsewhere in the repository
      that this task did not create are acceptable and must be left untouched.
- [x] Confirm nothing under `.claude/` was written by this task. The deployed tree is regenerated
      by a separate manual step and is never edited or hand-synced here.
- [x] Record the verification command outputs in the implementation summary rather than asserting
      success narratively.

**Timing**: ~0.5 hours

**Depends on**: 2

**Files to modify**: none (verification only; in-place fixes to the deliverable are permitted if a
check fails).

**Verification**:

- `test -s` on the deliverable passes.
- Heading check lists every required section.
- Task-number grep returns no matches.
- `git status --short` shows exactly one path under `agent-system/` and zero under `.claude/`.

---

## Testing & Validation

- [x] `test -s agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      succeeds (file exists, non-empty).
- [x] All required section headings from Phases 1 and 2 are present in the deliverable.
- [x] `grep -nEi '\b[Tt]asks?[ -]+[0-9]+' <deliverable>` returns no matches.
- [x] `git status --short` lists exactly one path under `agent-system/` (the new file).
- [x] `git status --short` lists nothing under `.claude/`.
- [x] No file among `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`,
      `scripts/task-lock.sh`, `docs/architecture/handoff-schema.md`, and
      `docs/reference/standards/multi-task-creation-standard.md` appears as modified.
- [x] The deliverable references mechanism documents by path without restating their algorithms.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — the single
  new deliverable file.
- `specs/899_batch_orchestration_guardrails_context/summaries/01_batch-orchestration-guardrails-summary.md`
  — implementation summary including the verification command outputs from Phase 3.

## Rollback/Contingency

The deliverable is a single new, previously nonexistent file. Rollback is deleting it:
`rm agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`. Nothing
else is touched, so there is no state, behavior, or dependent artifact to unwind. If Phase 3
finds a collateral edit to an existing file under `agent-system/`, revert that file specifically
(never a whole-tree discard, and never a destructive git operation on a dirty tree without a
snapshot first) and re-run Phase 3.
