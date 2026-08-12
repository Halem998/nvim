# Implementation Plan: Task #37

- **Task**: 37 - Close the two residual gaps left by the territory/handoff work
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: 33, 35 (both landed)
- **Research Inputs**: specs/037_wire_sound_territory_contract_for_per_phase_dispatch/reports/01_close-two-residual-gaps.md
- **Artifacts**: plans/01_close-residual-territory-gaps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The original "wire a sound territory contract into per-phase dispatch" scope has already landed;
research verified every already-done claim directly against the source store. What remains is
three targeted documentation/contract edits plus one recorded governance decision: watcher/monitor
teardown as an operational obligation in `context/contracts/wrap-up.md`; a rescoping of
`context/contracts/territory.md`'s opening and Template preamble to match its actual
single-phase-dispatch consumer; a recorded base-vs-hard territory asymmetry decision reusing the
existing in-file decision-record idiom; and a small tie-in of the STOP-and-report duty into the
agent files that operationalize the contract. Definition of done: all five acceptance criteria in
the task description are satisfied, no second statement of the "report != termination" model
exists anywhere, and the deployed tree is regenerated so the orchestrator-critical files in scope
are live.

### Research Integration

Findings from `reports/01_close-two-residual-gaps.md` that bind this plan:

- All five "already landed" claims confirmed. They enter this plan as Phase 1 verification steps
  only, never as work to implement.
- `wrap-up.md` (194 lines) genuinely has zero watcher/monitor/background/teardown coverage. The
  correct structural home is a new section parallel to its existing "Ordering: Handoff Write
  Precedes Marker Promotion (Defect 6)" section, using that section's own "precedes" framing.
- `skill-orchestrate/SKILL.md` has zero `territory` mentions; the hard engine has three
  (frontmatter, context pointer at line 90, dispatch key at line 814).
- A directly reusable decision-record idiom exists at `skill-orchestrate/SKILL.md` lines 244-260
  (`**Decision record**:` / `**Asymmetry decision (recorded, ... so the two visibly agree)**:`),
  with its hard-engine counterpart at `skill-orchestrate-hard/SKILL.md` line 479. No ADR
  directory exists in this codebase; decision records live inline in the governing file.
- Base mode's `file_scope` collision deferral (`in_batch`, `cross_batch`, `session_active`
  branches, all ledgered to `defer_ledger`) is **admission-time only** and structurally blind to a
  woken predecessor from an earlier cycle. Any decision that cites it as sufficient is not
  acceptable.
- `general-implementation-hard-agent.md` Stage 3.6's four steps cover ownership and blockers only;
  none ties to the STOP-and-report duty the `concurrency_note` and Template already carry.
- Both `territory.md` (`"line_count": 107`) and `wrap-up.md` (`"line_count": 194`) carry
  `line_count` records in `agent-system/extensions/core/index-entries.json` that will drift.

### Prior Plan Reference

No prior plan. `plans/` is empty for this task.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Add watcher/monitor/background-job teardown to `context/contracts/wrap-up.md` as an operational
  obligation discharged BEFORE the terminal `.orchestrator-handoff.json` write, with a one-line
  pointer for the rationale.
- Rescope `context/contracts/territory.md`'s opening paragraph and Template preamble to describe
  the single-phase dispatch that actually consumes the contract today.
- Record an explicit base-vs-hard territory decision in `skill-orchestrate/SKILL.md`, mirrored in
  `skill-orchestrate-hard/SKILL.md`, that names the woken-predecessor blindness of base mode's
  `file_scope` deferral by name.
- Tie the STOP-and-report duty for observed foreign work into the agent files that operationalize
  the territory contract.
- Re-verify (never re-implement) the five already-landed items.

**Non-Goals**:
- Re-deriving, re-implementing, or churning the hard engine's `territory` dispatch key or its
  `concurrency_note`. It is live and sound.
- Creating any second statement of the "report != termination" model. Every new mention is a
  one-line pointer to `context/patterns/dispatch-report-not-termination.md`.
- Wiring a full `owned_files`/`read_only_files`/`forbidden_files` territory declaration into base
  mode's dispatch context (see the Phase 4 decision below for the reasoned position).
- Any further extension fan-out. The lean and cslib hard agents already reference the pattern file.
- Rewriting `general-implementation-hard-agent.md` Stage 3.6. The change is one added step.
- Editing any deployed `.claude/**` file by hand.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new wrap-up.md teardown section restates the pattern file's argument instead of pointing at it, violating acceptance criterion 5 | H | M | Mirror the exact one-line-pointer idiom wrap-up.md already uses in its `dispatch_seq` field-semantics bullet: `See \`context/patterns/dispatch-report-not-termination.md\`.` Phase 6 greps for a second model statement. |
| Editing territory.md's opening while leaving the Template preamble parallel-only (or vice versa) leaves the file internally inconsistent | M | M | Acceptance criterion 3 names both; Phase 3 treats them as one atomic edit (`Commit Mode: atomic-batch`) with a single verification pass over both sites. |
| The Phase 4 decision cites `file_scope` deferral as if it covered the woken-predecessor case | H | M | Phase 4's checklist makes the blindness statement a required, separately-verified sentence; Phase 6 greps for it. |
| Hand-editing a deployed `.claude/**` file, silently wiped on next regeneration | H | L | Every phase's "Files to modify" names only `agent-system/extensions/**` paths. Phase 1 restates the boundary; Phase 6 verifies no `.claude/**` file was touched. |
| Stale `line_count` records in `index-entries.json` after wrap-up.md and territory.md grow | L | H | Phase 6 runs `generate-context-line-counts.sh --write` and commits the result. |
| Orchestrator-critical files edited in the source store but not deployed, so a later verification reads stale deployed content | M | M | Phase 6 runs `deploy-headless.sh` BEFORE any verification that reads the deployed tree, per the task's sequencing note. |
| Churning `skill-orchestrate-hard/SKILL.md` (a large, orchestrator-critical, recently-churned file) beyond the mirrored record | M | L | Phase 4's edit to that file is bounded to a single added paragraph adjacent to the existing line-479 asymmetry record; no other hunk is permitted. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 4 |
| 4 | 6 | 2, 3, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Verify Landed State (No Edits) [COMPLETED]

**Goal**: Cheaply re-confirm all five already-landed items so the rest of the plan proceeds on a
checked foundation, and produce the exact `concurrency_note` text Phase 4 may need to reuse
verbatim. This phase writes no repository files.

**Tasks**:
- [x] Confirm the hard engine's `territory` dispatch key and `concurrency_note`:
      `grep -n territory agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
      Expect hits at the frontmatter description, the H7 bullet, the context pointer, the Stage 4
      dispatch-context comment, the `"territory"` key, its `concurrency_note`, and the
      Parallel-Wave-Disabled section. Copy the `concurrency_note` string verbatim into scratch for
      Phase 4's possible reuse. Do NOT edit it. *(completed: verified, all expected hits present, concurrency_note copied to progress/phase-1-progress.json)*
- [x] Confirm `context/contracts/territory.md`'s Template still carries the "asserts only what is
      locally checkable" sentence, the STOP-and-report instruction, and the "Explicit removal note"
      anti-regression clause. Do NOT edit them in this phase. *(completed: confirmed at lines 93, 99, 103)*
- [x] Confirm the "report != termination" model is stated in exactly one place:
      `grep -rln "dispatch-report-not-termination" agent-system/ | wc -l` returns a nonzero
      referencing-file count, and `ls agent-system/extensions/*/context/patterns/dispatch-report-not-termination.md`
      returns exactly one file. Record both numbers as the Phase 6 baseline. *(completed: 23 referencing files, exactly 1 canonical pattern file)*
- [x] Confirm the lean and cslib hard agents still reference the pattern file:
      `grep -n "dispatch-report-not-termination" agent-system/extensions/lean/agents/lean-implementation-hard-agent.md agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
      Expect one hit in each. No extension fan-out is required; do not add any. *(completed: one hit in each)*
- [x] Confirm `general-implementation-hard-agent.md` Stage 3.6 exists, is gated on
      `If territory parameters were provided in delegation context`, and has exactly four numbered
      steps none of which mentions foreign commits/modifications/builds. This is the precondition
      for Phase 5's correction. *(completed: confirmed at line 144, four steps, gate intact)*
- [x] Restate the source-store boundary before any editing phase begins: every edit in Phases 2-6
      targets `agent-system/extensions/**`. No `.claude/**` file is hand-edited at any point. *(completed)*
- [x] If ANY of the above verifications fails (the landed state is not as research reported),
      STOP and report rather than proceeding — the remaining phases assume this foundation. *(completed: none failed, proceeding)*

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts (a) exactly one file states the "report != termination"
model, and (b) Stage 3.6 has exactly four steps. Both are research-reported hypotheses, not facts.
Confirm (a) with the `ls` glob above and (b) by reading the Stage 3.6 block directly. If either
count differs from the hypothesis, record the actual value and carry it forward as the Phase 6
baseline rather than asserting the planned number.

**Files to modify**:
- None. This phase is read-only by design.

**Verification**:
- All six confirmation greps/reads executed and their outputs recorded in the phase progress notes.
- `git status --short` shows no modification attributable to this phase.

---

### Phase 2: Teardown Obligation in wrap-up.md (Gap 1) [COMPLETED]

**Goal**: Add watcher/monitor/background-job teardown to `context/contracts/wrap-up.md` as an
operational obligation discharged before the terminal handoff write, satisfying acceptance
criterion 1.

**Tasks**:
- [x] Add a new `##`-level section to `agent-system/extensions/core/context/contracts/wrap-up.md`,
      placed immediately after the existing "Ordering: Handoff Write Precedes Marker Promotion
      (Defect 6)" section and before "Build-Green Invariant", titled in that section's own
      "precedes" idiom (e.g. `## Teardown Precedes the Terminal Handoff Write`). *(completed)*
- [x] State the obligation operationally and in the imperative: every agent that arms a
      watcher, monitor, or background job during its own dispatch MUST tear it down BEFORE writing
      the terminal `.orchestrator-handoff.json`. Name the concrete artifacts an agent actually
      arms in this system (backgrounded `Bash` invocations, file/process watchers, monitor loops)
      so the obligation is checkable rather than abstract. *(completed)*
- [x] Give the rationale as a ONE-LINE POINTER only, mirroring the existing idiom already used in
      wrap-up.md's `dispatch_seq` field-semantics bullet:
      `See \`context/patterns/dispatch-report-not-termination.md\`.` Do NOT restate, summarize, or
      re-argue that file's model — acceptance criterion 5 forbids a second statement of it. *(completed)*
- [x] Record the standing limitation in one sentence: teardown cannot prevent a resume-driven wake,
      so it complements — never replaces — the sound territory contract. *(completed)*
- [x] Do NOT modify any other section of wrap-up.md. This is an addition, not a restructure. *(completed: verified via git diff --stat, single hunk)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/contracts/wrap-up.md` - add one new `##` section between
  the Defect-6 ordering section and the Build-Green Invariant section.

**Verification**:
- `grep -inE 'watch|monitor|background|teardown' agent-system/extensions/core/context/contracts/wrap-up.md`
  now returns hits (it returned nothing before this phase).
- The new section contains exactly one occurrence of `dispatch-report-not-termination`, and that
  occurrence is a pointer sentence, not a paraphrase of the model.
- `git diff` for this file shows exactly one added hunk; no pre-existing section is altered.

---

### Phase 3: Rescope territory.md to Its Actual Consumer [COMPLETED]

**Goal**: Make `context/contracts/territory.md`'s opening scope and Template preamble accurately
describe how the contract is consumed today — single-phase hard-mode dispatch — satisfying
acceptance criterion 3.

**Tasks**:
- [x] Edit the opening paragraph of
      `agent-system/extensions/core/context/contracts/territory.md` (currently "This contract
      implements H7: Territory Contracts for Parallel Dispatch. It governs file ownership and
      commit coordination when multiple agents are dispatched simultaneously to work on different
      phases of the same plan.") so it states that the contract's shipped consumer today is
      `skill-orchestrate-hard`'s single-phase dispatch, while remaining applicable to parallel
      dispatch should it be re-enabled. Retain the `H7` identifier — it is asserted by
      `lint-contract-compliance.sh`. *(completed)*
- [x] Edit the Template preamble (currently "The orchestrator includes this in each parallel
      dispatch context:") so it reads as each dispatch context, not each *parallel* dispatch
      context. *(completed)*
- [x] Treat both edits as ONE change: the file must not be left describing single-phase dispatch in
      one place and parallel-only dispatch in the other. *(completed: verified by top-to-bottom read)*
- [x] Leave the "File Territory", "Plan-Section Territory", "Commit Protocol", "Handoff Merge
      Rule", the Template body, and the "Explicit removal note" untouched. In particular, do not
      weaken or reword the Template's "does NOT assert that no other agent is concurrently active"
      sentence or the STOP-and-report instruction. *(completed: only the two named sites touched)*
- [x] Update the `contracts/territory.md` `summary` field in
      `agent-system/extensions/core/index-entries.json` if its "for parallel dispatch" wording now
      contradicts the rescoped opening. Do not touch its `line_count` here — Phase 6 regenerates
      all line counts mechanically. *(completed: summary updated, line_count untouched)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Files to modify**:
- `agent-system/extensions/core/context/contracts/territory.md` - opening paragraph and Template
  preamble.
- `agent-system/extensions/core/index-entries.json` - `contracts/territory.md` entry's `summary`
  field only (conditional on the wording contradiction above).

**Verification**:
- Reading territory.md top-to-bottom, the opening and the Template preamble agree with each other
  and with the shipped consumer.
- `grep -n "H7" agent-system/extensions/core/context/contracts/territory.md` still returns the
  identifier (contract-compliance lint depends on it).
- `grep -n "exclusive access\|no other agent is active" agent-system/extensions/core/context/contracts/territory.md`
  returns only the anti-regression note's own quoted examples, never a live assertion.
- `jq empty agent-system/extensions/core/index-entries.json` passes if that file was touched.

---

### Phase 4: Record the Base-Mode Territory Decision (Gap 2) [COMPLETED]

**Goal**: Record an explicit, mutual base-vs-hard decision on whether base mode gains a territory
contract, satisfying acceptance criterion 2, using the codebase's established in-file
decision-record idiom rather than a new format or a new file.

**The decision to record** (determined at plan time; the implementer records it, does not
re-litigate it):

> Base mode does NOT gain a `territory` dispatch key. Its concurrency is genuinely concurrent but
> INTER-TASK: the Stage MT-4 batching rule dispatches one agent per task number, each with its own
> `task_dir`, `handoff_path`, and declared `file_scope`. A per-dispatch `owned_files` declaration
> would restate `file_scope` at a second grain without adding any detection capability that
> `file_scope` deferral does not already provide for the cross-task file-conflict case it covers.
>
> The residual gap is recorded as OPEN, not as covered. Base mode's `file_scope` collision
> deferral (`in_batch`, `cross_batch`, and `session_active` branches, all ledgered to
> `defer_ledger`) operates at ADMISSION TIME only: it compares tasks being admitted this cycle
> against each other and against currently-registered live sessions. It is structurally blind to a
> woken predecessor from an EARLIER cycle that already reported but is still live (a self-armed
> watcher/monitor, or an operator resume). That case is not covered by `file_scope` deferral and
> is not closed by this decision.
>
> What DOES apply to base mode is the observation half of the contract — the STOP-and-report duty
> on foreign commits, foreign uncommitted modifications, or a running build the agent did not
> start. That duty is orthogonal to the file-ownership declaration and is wired into the base
> implementation agent in Phase 5, not via a territory dispatch key.

**Tasks**:
- [x] Add a `**Decision record**:` / `**Asymmetry decision (recorded, ... so the two visibly
      agree)**:` block to `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, reusing
      the exact prose idiom already established in that file at the loop-guard-staleness asymmetry
      record (the `**Decision record**:` / `**Asymmetry decision (recorded, "recorded not acted on"
      style, mirroring the hard engine's record so the two visibly agree)**:` pair). Do not invent
      a new decision-record format and do not create a new file or directory for it. *(completed)*
- [x] Place the block where a future reader of the base engine will actually find it: adjacent to
      the Stage MT-3 `file_scope_collision` / `session_active` deferral branches whose limitation
      it names, or immediately after the Stage MT-4 BATCHING RULE. Choose one site; do not
      duplicate the record at both. *(completed: placed adjacent to the session_active branch)*
- [x] The block MUST state, in its own words: (a) the decision (base mode does not gain a
      `territory` dispatch key); (b) that base mode's multi-task dispatch is genuinely concurrent
      by construction (the BATCHING RULE's single-message requirement); (c) that `file_scope`
      deferral is ADMISSION-TIME ONLY and structurally blind to a woken predecessor from an earlier
      cycle — named explicitly as an OPEN residual gap, never as something `file_scope` covers;
      and (d) a one-line pointer to `context/patterns/dispatch-report-not-termination.md` for the
      underlying model. No restatement of that model. *(completed: all four elements present)*
- [x] Add the mirrored acknowledgment to
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, bounded to a single
      added paragraph adjacent to its existing `**Asymmetry decision (recorded, not merely
      implied)**` record, so the two engines visibly agree. State that the hard engine carries a
      `territory` dispatch key and the base engine deliberately does not, and cite the base
      engine's record. Do not modify the hard engine's `territory` key, its `concurrency_note`, or
      any other hunk of that file. *(completed: single hunk, concurrency_note byte-identical)*
- [x] Do NOT add a `territory` key, `owned_files`, `read_only_files`, or `forbidden_files` to any
      base-mode dispatch context. *(completed: none added)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - one added decision-record
  block.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - one added mirrored
  acknowledgment paragraph.

**Verification**:
- `grep -c territory agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` is now
  nonzero (it was 0), and every occurrence is inside the decision-record block — none is a dispatch
  key or a dispatch-context field.
- The base-engine block contains a sentence naming admission-time-only scope and woken-predecessor
  blindness. Confirm by reading, e.g. via
  `grep -n -A2 "admission" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`.
- `git diff --stat` shows exactly one added hunk in each of the two SKILL.md files.
- `grep -c "dispatch-report-not-termination" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  increased by exactly 1 relative to the pre-phase count, and the new occurrence is a pointer.

---

### Phase 5: Tie STOP-and-Report Into the Agent Files [NOT STARTED]

**Goal**: Make the STOP-and-report duty for observed foreign work an explicit step in the agent
files that operationalize the territory contract — the targeted correction research confirmed, plus
the base-agent half the Phase 4 decision commits to.

**Tasks**:
- [ ] In `agent-system/extensions/core/agents/general-implementation-hard-agent.md`, extend Stage
      3.6 ("Territory Check") with a fifth numbered step covering the STOP-and-report duty: if you
      observe work you did not do — a foreign commit, a foreign uncommitted modification, or a
      running build you did not start — STOP and report it in the handoff rather than proceeding or
      dismissing it as noise. Point at `context/contracts/territory.md` (already referenced by step
      1) and add a one-line pointer to `context/patterns/dispatch-report-not-termination.md`.
- [ ] Leave Stage 3.6's existing four steps and its `If territory parameters were provided in
      delegation context` gate unchanged. This is an added step, not a rewrite.
- [ ] In `agent-system/extensions/core/agents/general-implementation-agent.md`, add the same
      observation duty as a short, self-contained obligation, worded so it does NOT depend on a
      `territory` delegation-context parameter (base mode sends none, per the Phase 4 decision).
      Keep it to one short paragraph with a one-line pointer to
      `context/patterns/dispatch-report-not-termination.md`. Do not import the territory contract's
      ownership machinery into the base agent.
- [ ] Verify neither addition restates the "report != termination" model. Each is an operational
      duty plus a pointer.

**Timing**: 30 minutes

**Depends on**: 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - Stage 3.6 gains one
  numbered step.
- `agent-system/extensions/core/agents/general-implementation-agent.md` - one added short
  obligation paragraph.

**Verification**:
- Stage 3.6 now has five numbered steps; the gate line is byte-identical to before.
- `grep -n "STOP and report" agent-system/extensions/core/agents/general-implementation-hard-agent.md agent-system/extensions/core/agents/general-implementation-agent.md`
  returns a hit in each file.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` passes (frontmatter and no-task-reference
  bullet coverage unaffected).
- No task-number reference was introduced into either agent file (both live outside `specs/**`).

---

### Phase 6: Index Counts, Deploy, and Acceptance Gates [NOT STARTED]

**Goal**: Reconcile the mechanical side effects of the content edits, regenerate the deployed tree
so the orchestrator-critical files in scope are live, and verify all five acceptance criteria.

**Tasks**:
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --write` to correct the now-stale
      `line_count` fields for `contracts/wrap-up.md` and `contracts/territory.md` in
      `agent-system/extensions/core/index-entries.json`. Confirm with `--check` that it reports
      clean afterwards.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and resolve any failure it reports against
      the files this task touched.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's standard
      deploy entry point) BEFORE any verification below that reads the deployed `.claude/**` tree.
      Several files in scope are orchestrator-critical and are copied into the deployed tree.
- [ ] Run `bash .claude/scripts/lint/lint-contract-compliance.sh` and confirm it still passes —
      `territory.md`'s `H7` identifier and the hard agents' contract references must survive the
      Phase 3 rescope.
- [ ] **Acceptance criterion 1**: confirm wrap-up.md carries the teardown obligation before the
      terminal handoff write, as a pointer rather than a re-derivation.
- [ ] **Acceptance criterion 2**: confirm the base-mode decision record exists, is findable from
      both engines, and names the woken-predecessor blindness of `file_scope` deferral.
- [ ] **Acceptance criterion 3**: confirm territory.md's opening and Template preamble both
      describe today's consumption.
- [ ] **Acceptance criterion 4**: re-run Phase 1's verification greps and confirm nothing landed
      previously was churned. Specifically confirm the hard engine's `concurrency_note` string is
      byte-identical to the Phase 1 scratch copy.
- [ ] **Acceptance criterion 5**: confirm exactly one file still states the "report != termination"
      model — `ls agent-system/extensions/*/context/patterns/dispatch-report-not-termination.md`
      returns one path — and that every mention added by Phases 2, 4, and 5 is a one-line pointer.
- [ ] Confirm the source-store boundary held: `git status --short` shows no modified path under any
      `.claude/` tree attributable to hand-editing (deploy-written files excepted, and `.claude/` is
      gitignored here).
- [ ] Write the implementation summary to
      `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/summaries/01_close-residual-territory-gaps-summary.md`.

**Timing**: 40 minutes

**Depends on**: 2, 3, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly two `index-entries.json` `line_count` fields
drift (`contracts/wrap-up.md` and `contracts/territory.md`). Confirm with
`generate-context-line-counts.sh --check` before `--write`; if it reports a different set, record
the actual set rather than the planned one.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` fields.
- `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/summaries/01_close-residual-territory-gaps-summary.md` - new.

**Verification**:
- `generate-context-line-counts.sh --check` reports clean.
- `check-extension-docs.sh`, `lint-contract-compliance.sh`, and `lint-agent-contracts.sh` all exit 0.
- `jq empty agent-system/extensions/core/index-entries.json` passes.
- All five acceptance criteria explicitly confirmed with the evidence recorded in the summary.

---

## Testing & Validation

- [ ] `jq empty agent-system/extensions/core/index-entries.json` passes.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] `bash .claude/scripts/lint/lint-contract-compliance.sh` exits 0 (H7 identifier and hard-agent
      contract references intact after the territory.md rescope).
- [ ] `bash .claude/scripts/lint/lint-agent-contracts.sh` exits 0 after both agent-file edits.
- [ ] `grep -inE 'watch|monitor|background|teardown' agent-system/extensions/core/context/contracts/wrap-up.md`
      returns hits (it returned nothing before this task).
- [ ] `grep -c territory agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` is nonzero
      and every hit is inside the decision record.
- [ ] `ls agent-system/extensions/*/context/patterns/dispatch-report-not-termination.md` returns
      exactly one path — no second statement of the model was created.
- [ ] The hard engine's `concurrency_note` string is byte-identical to its pre-task value.
- [ ] No task-number reference introduced outside `specs/**`
      (`bash .claude/scripts/check-task-references.sh` if available).

## Artifacts & Outputs

- `agent-system/extensions/core/context/contracts/wrap-up.md` (modified — one new teardown section)
- `agent-system/extensions/core/context/contracts/territory.md` (modified — opening + Template
  preamble rescoped)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified — decision record)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified — mirrored
  acknowledgment)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (modified — Stage 3.6
  fifth step)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified — observation
  duty)
- `agent-system/extensions/core/index-entries.json` (modified — regenerated `line_count`, possibly
  one `summary`)
- `specs/037_wire_sound_territory_contract_for_per_phase_dispatch/summaries/01_close-residual-territory-gaps-summary.md`
  (new)

## Rollback/Contingency

Every phase is an additive, per-file documentation edit committed separately, so reverting is a
per-phase `git revert` of that phase's commit; no phase leaves another in an inconsistent state
except Phase 3, whose two territory.md sites are committed atomically together, and Phase 4, whose
two SKILL.md sites are committed atomically together.

If Phase 1 finds the landed state is NOT as research reported, STOP and report rather than
proceeding — the plan's premise is broken and the remaining phases must be re-planned.

If Phase 6's deploy step fails, the source-store edits still stand and are committed; report the
deploy failure and leave redeployment to an operator rather than hand-editing `.claude/**` to
compensate.

If the Phase 4 decision proves unrecordable at the chosen site without disturbing surrounding
prose, relocate the block to the alternative site named in that phase's checklist rather than
splitting it across both.
