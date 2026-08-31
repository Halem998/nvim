# Implementation Plan: Task #116

- **Task**: 116 - Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Status**: [NOT STARTED]
- **Effort**: 15 hours
- **Dependencies**: None
- **Research Inputs**: specs/116_core_agent_system_consolidation/reports/01_orchestrate-centric-consolidation-design-inputs.md
- **Artifacts**: plans/01_orchestrate-centric-consolidation.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a meta-task whose implementation deliverables are documents and backlog state, not code.
Phase A produces a written target-state design specification for a single-entry-point core
(`/orchestrate` as the only lifecycle command), answering A1-A7 with a stated decision and
reasoning for each. Phase B assigns exactly one verdict (ON-PATH / RESCOPE / ABSORB / MOOT, plus
an orthogonal BLOCKING flag) to every task in the audit scope, each citing the Phase A decision
that produces it. Phase C applies those verdicts to `specs/TODO.md` and `specs/state.json`.

**Hard scope boundary, load-bearing throughout**: this task creates and modifies files only under
`specs/**`. It does not create, modify, or delete a single file under `agent-system/extensions/**`
or `.claude/**`. The successor tasks that Phase C creates are where files actually get deleted.
VERIFICATION BAR item 5 is checked mechanically in the final phase.

### Research Integration

The research report's seven findings are integrated as follows, and the first is treated as a
first-class design input rather than a footnote:

1. **The dispatch-bypass gap (highest-value finding, independently re-verified during planning).**
   `skill-orchestrate/SKILL.md` dispatches every lifecycle phase via the Agent tool directly
   (`subagent_type: $RESEARCH_AGENT` / `$PLANNER_AGENT` / `$IMPLEMENT_AGENT`, plus the
   `reviser-agent` and multi-task dispatch sites), bypassing `skill-researcher`/`skill-planner`/
   `skill-implementer` entirely. Those three skills are the sole home of Stage 4a memory retrieval
   (`memory-retrieve.sh` gated by `clean_flag`) and of interactive `--lit` resolution
   (`lit-stage4a-flow.md`). Re-verified at planning time: `skill-orchestrate/SKILL.md` contains
   zero occurrences of `memory-retrieve`, `clean_flag`, `lit-stage4a`, or `literature-briefing`,
   while carrying 13 pass-through occurrences of `lit_flag`; and
   `general-research-agent.md`, `planner-agent.md`, `general-implementation-agent.md` each contain
   zero occurrences of either mechanism. **Consequence, confirmed**: every task run through
   `/orchestrate` today receives no memory-augmented context, and `--lit` is threaded end-to-end
   as a boolean that is never resolved into a briefing. This inverts part of A1's premise:
   promoting `/orchestrate` to sole entry point would make a currently-partial capability loss
   total and permanent unless the design closes it first. Phase 2 must therefore produce a named
   post-collapse home for both mechanisms and an explicit sequencing constraint, and Phase 4's A6
   ledger must carry both as line items.
2. `/orchestrate --hard` has no dispatch site anywhere; `skill-orchestrate-hard` (1,784 lines) is
   unreachable from any command, though 10+ test/lint scripts exercise it. This lowers A4's
   migration cost but leaves those test/lint files needing an explicit disposition either way.
   Phase 3 must decide their fate rather than leaving it implicit in the deletion.
3. `next_artifact_number` is incremented only by research's postflight (`orchestrator-postflight.sh`,
   comment "research only"); plan/implement read it back via `skill-base.sh`'s `"prev"` mode
   (`next_artifact_number - 1`) and never increment it. A forced re-plan or re-implement under A2
   therefore collides on the existing MM number unless new increment logic is added. Phase 2's A2
   must decide this with the concrete location named.
4. Sequencing tensions, each to be resolved with a stated direction in Phase 7: the two
   call-site-counting tasks vs. A1's command deletions; the model-flag mirror task vs. A4's
   deletion of its target file; and two BLOCKING candidates research surfaced beyond those the
   task description named -- the `/orchestrate` blocked-verdict discrimination defect (a live
   correctness defect in the very engine A1 makes the sole entry point) and the task-lock /
   session-registry heartbeat defect (liveness is a named A6 preserved asset).

Two data gaps research could not close are handled explicitly in Phase 1 rather than allowed to
produce evidence-free verdicts: three audit-scope tasks carry a null `file_scope` in `state.json`.
Planning confirmed the exact set is three, not two.

### Prior Plan Reference

No prior plan exists for this task.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md consultation was
requested, so no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A written Phase A design specification that states a decision and its reasoning for each of
  A1-A7, specific enough that a successor task implements it without re-deriving any decision.
- A backlog audit assigning exactly one verdict to every task in the audit scope, with every MOOT
  verdict naming the specific deletion-ledger entry that produces it.
- Applied backlog operations: revised descriptions, abandoned tasks with recorded reasons, created
  successor tasks each independently dispatchable with its own `file_scope`, re-topiced survivors,
  and a dependency ordering that regenerates into an acyclic TODO.md.
- A deletion ledger reporting projected before/after totals against the measured baseline, with
  every A6 preserved asset named and given a post-collapse home.

**Non-Goals**:
- Editing, creating, or deleting any file under `agent-system/extensions/**` or `.claude/**`.
- Re-litigating A4 (hard mode collapses to contract injection) or A5 (team mode folds into the
  single engine as a flag). Both are user decisions; this task plans and specifies the HOW.
- Auditing or re-topicing the literature-topic tasks, or boiling down extension internals.
- Performing any deletion of a lifecycle command, skill, or agent. Successor tasks do that.
- Running this task inside a multi-task `/orchestrate` batch. Its `file_scope` includes
  `specs/TODO.md` and `specs/state.json`, which collide with every other task in the repo.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A1 specifies deleting the three lifecycle commands (and thereby orphaning the three lifecycle skills) without first rehoming memory retrieval and `--lit` resolution, entrenching the confirmed capability loss | H | M | Phase 2 must produce a named post-collapse home for both mechanisms and an explicit ordering constraint ("rehome lands before any command deletion"); Phase 4's A6 carries both as line items; Phase 7 encodes the ordering as a real `dependencies` edge in the successor-task graph |
| A verdict is assigned to a task whose scope is not evidenced (three tasks carry null `file_scope`) | M | H | Phase 1 derives scope from description prose where the prose evidences it, and marks the task EVIDENCE-GAP otherwise; an EVIDENCE-GAP task receives a `file_scope` backfill operation in Phase 9, and its verdict is recorded as provisional-pending-backfill rather than guessed |
| Bulk `state.json` mutation via a single `--argjson` payload exceeds the 128KB per-argument ceiling (MAX_ARG_STRLEN); audit-scope descriptions average ~5KB and run to 5-10KB each | H | M | Every Phase C write goes through `state-write.sh` one task at a time (or in batches whose combined payload is measured to stay under 100KB before the call), never as one bulk array assignment |
| A wholesale `.artifacts = [...]` or `.active_projects = [...]` assignment silently discards existing entries | H | L | Phase C uses targeted per-task jq filters (`map(if .project_number == $n then ... else . end)`) and append (`+=`) semantics only; never a whole-array replacement |
| Line-count savings are double-counted between the collapse itself and the mode-gated-section-loading chain, both of which target the same multi-task section | M | H | Phase 4's A7 ledger nets the two explicitly and states the netting; Phase 7 re-checks the netting when assigning those tasks' verdicts |
| A successor task both deletes a lifecycle skill and rewires its consumers, leaving the system in a state where a dispatch resolves to a missing file | H | M | Phase 8 applies a hard sizing rule: deletion and rewiring are always separate tasks, and the rewiring task is a declared dependency of the deletion task |
| An A-item is answered "to be determined", making Phase A incomplete under VERIFICATION BAR item 1 | H | M | Phase 4 ends with an explicit completeness gate that greps the design report for unresolved-decision language and fails the phase on a hit |
| The implementer drifts into editing the running system while reasoning about deletions | H | M | Phase 10 checks `git status --porcelain` for any path outside `specs/` and fails the task on a hit; the constraint is restated in every phase's Files-to-modify block |

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
| 8 | 8 | 7 |
| 9 | 9 | 8 |
| 10 | 10 | 9 |

Phases within the same wave can execute in parallel. This plan is fully sequential by
construction: Phases 2-4 append successive sections to one design artifact (a shared-file
territory conflict rules out parallelism), Phases 5-6 append to one verdict artifact, and every
Phase C operation depends on the complete verdict set.

---

### Phase 1: Baseline verification and audit-scope evidence roster [NOT STARTED]

**Goal**: Establish the verified factual base that every Phase A decision and every Phase B verdict
rests on, so that no later phase re-derives a measurement or reasons from an unverified claim.

**Tasks**:
- [ ] Re-measure the core extension inventory against the MOTIVATION baseline recorded in the task
      description (commands 18 files/7,707 lines; skills 22 dirs/14,981 SKILL.md lines; agents 12
      files/5,073 lines; rules 10 files; scripts 145 files/48,204 lines; context 137 files/37,959
      lines; docs 28 files). Record each measured value and its delta from the baseline. Where a
      delta exists, the measured value becomes authoritative for A7 and the baseline figure is
      retained alongside it for the description's own reporting requirement.
- [ ] Re-verify the dispatch-bypass finding with reproducible commands and record the exact
      counts: occurrences of `memory-retrieve`, `clean_flag`, `lit-stage4a`, `literature-briefing`
      and `lit_flag` in `skill-orchestrate/SKILL.md`; the same set in the three dispatched agent
      files; and the enumerated `subagent_type` dispatch sites in `skill-orchestrate/SKILL.md`
      (single-task handlers, reviser sites, and multi-task sites).
- [ ] Re-verify that no command file or script invokes `skill-orchestrate-hard`, and enumerate the
      test and lint files that reference it (research reported 10+; confirm the actual set and
      list it by filename).
- [ ] Re-verify the artifact-numbering asymmetry: locate the research-only increment in
      `orchestrator-postflight.sh` and the `"prev"` mode read in `skill-base.sh`, and record both
      by script and function/stage name (never by line number).
- [ ] Re-verify the manifest footprint: count extensions declaring `routing_hard` /
      `routing_agents_hard` versus `routing` / `routing_agents`, and name the declaring extensions.
- [ ] Build the audit-scope roster from `specs/state.json`: every task with `topic != "literature"`
      excluding 116, capturing `project_number`, `project_name`, `topic`, `status`, `task_type`,
      `file_scope`, `dependencies`, and a one-line scope summary derived from the description.
      Note that the human-readable name field is `project_name` (there is no `title` field);
      a query against `.title` returns null for every task and must not be mistaken for missing data.
- [ ] Reconcile the roster size against the audit scope's stated count of 32 and record the
      reconciliation arithmetic explicitly. In particular, record a disposition for the single task
      carrying `topic: null` (its `file_scope` names core orchestrate-batch-admission and
      multi-task-creation-standard paths): either admit it to the audit scope with a stated reason
      and re-topic it in Phase 9, or exclude it with a stated reason. Do not leave it unaddressed.
- [ ] For each roster entry with a null or empty `file_scope`, attempt to evidence scope from the
      description prose. Where the prose names concrete files, record the derived scope and mark it
      DERIVED-FROM-DESCRIPTION. Where it does not, mark the entry EVIDENCE-GAP and record what
      evidence is missing. Do not infer a scope that the description does not state.
- [ ] Write the results to `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md`
      with a Measurement section, a Verified Findings section (one subsection per re-verified
      claim, each with the command used and the observed result), and the roster table.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts (a) that the audit scope contains 32 tasks and (b) that
exactly three audit-scope tasks carry a null `file_scope`. Both are hypotheses from research and
planning-time queries, to be confirmed at implementation time by re-running the roster query
against the live `specs/state.json` and reporting the observed counts; if either differs, the
observed value is authoritative and the discrepancy is recorded in the report rather than silently
reconciled.

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md` - created
- No file under `agent-system/extensions/**` or `.claude/**` is read-modified; reads only.

**Verification**:
- The report exists and contains a Measurement table with a measured value and a delta for all
  seven baseline rows.
- Each of the five re-verified claims has a recorded command and an observed result; a claim that
  did not reproduce is recorded as NOT REPRODUCED with the observed evidence, not silently dropped.
- The roster table has one row per audit-scope task, and the reconciliation arithmetic against 32
  is stated, including the disposition of the `topic: null` task.
- Every roster row has a non-empty scope cell, labelled either from `file_scope`,
  DERIVED-FROM-DESCRIPTION, or EVIDENCE-GAP.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 2: Phase A design -- entry point, phase forcing, and dispatch defaults (A1-A3) [NOT STARTED]

**Goal**: Decide and record A1, A2, and A3 with reasoning, resolving the dispatch-bypass gap before
any deletion decision is stated.

**Tasks**:
- [ ] Create `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` with a
      header, a Scope and Constraints section restating the specs-only write boundary, and section
      stubs for A1-A7.
- [ ] **A1 -- single entry point.** State precisely what happens to `/research`, `/plan`,
      `/implement`, and `/revise`: deleted outright, or retained as thin aliases forwarding to
      `/orchestrate` with a phase flag. State the decision and its reasoning. If aliases are
      retained, specify that they carry no argument parsing and no gate sequencing of their own,
      and say what mechanism enforces that. Address `/revise` specifically: its two behaviors
      (reasoned revision with a user-supplied free-text reason, and the description-update fallback
      when no plan exists) have no `/orchestrate` equivalent today and need an explicit home.
- [ ] **A1 precondition -- the dispatch-bypass gap.** Record as a named design constraint that
      memory retrieval (`memory-retrieve.sh`, gated by `clean_flag`) and interactive `--lit`
      resolution (`lit-stage4a-flow.md`) live only in the three lifecycle skills that
      `skill-orchestrate` bypasses, using Phase 1's verified counts as evidence. Name the
      post-collapse home for each (the expected shape is a dispatch-prep stage inside the single
      engine, mirroring the base skills' Stage 4a and invoked once per dispatch rather than once
      per command). State the ordering constraint explicitly: the rehome lands before any command
      or lifecycle-skill deletion, so the system is never in a state where the capability has no
      home. This constraint is carried forward into A6 and into Phase 7's sequencing.
- [ ] **A2 -- phase-forcing flags.** Specify the flag surface for re-running a phase that has
      already produced an artifact, covering at minimum `--research`, `--plan`, `--implement`, and
      whatever replaces `/revise`. Record a decision for each of the four sub-questions: (i) does a
      forced phase replace the prior artifact or append a new numbered one, naming the concrete
      change required -- the research-only increment site in `orchestrator-postflight.sh` and the
      `"prev"` mode read in `skill-base.sh` -- if appending is chosen for plan/implement, since no
      increment mechanism exists for them today; (ii) what a forced phase does to task status,
      including an explicit non-regression rule so that forcing research on a planned task cannot
      strand its plan; (iii) whether phase flags compose and, if so, whether composition means
      "force both" or "stop after the named phase"; (iv) the no-flag default. Also name the two
      consumption points a forcing flag must reach: the command's own argument parsing and the
      engine's state-driven handler selection, which today has no flag-driven override.
- [ ] **A3 -- defaults from task type and loaded extensions.** Specify how the single engine derives
      its dispatch defaults (agent, model, contracts) from `task_type` plus loaded extensions,
      without the user naming a skill. Start from the existing shared routing ladder and its two
      consumers. State what survives, what changes, and exactly what each extension manifest must
      declare after the collapse, given that A4 removes two of the current four routing blocks.
      Name the compound-key (`ext:subtype`) resolution behavior explicitly, since one open backlog
      task documents a live resolver defect there.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` - created; A1-A3
  sections written, A4-A7 stubs present

**Verification**:
- Sections A1, A2, and A3 each contain a stated decision and a reasoning paragraph; none contains
  "to be determined", "TBD", or an equivalent deferral.
- A1 names the fate of all four lifecycle commands individually.
- The dispatch-bypass constraint is recorded with Phase 1's evidence cited, names a post-collapse
  home for both memory retrieval and `--lit` resolution, and states the ordering constraint.
- A2 answers all four sub-questions and names the concrete increment/read sites by script and
  function name.
- A3 states what each extension manifest declares post-collapse.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 3: Phase A design -- hard-mode contract injection and team-mode fold (A4-A5) [NOT STARTED]

**Goal**: Specify HOW the two already-decided collapses are carried out, without re-litigating
whether they happen.

**Tasks**:
- [ ] **A4 -- hard mode as contract injection.** The decision is settled: the H2-H9 contracts are
      injected into the dispatch prompt rather than routed to a duplicate skill/agent tree,
      collapsing the three `-hard` lifecycle skills, the three `-hard` agent files, and
      `skill-orchestrate-hard`, and removing `routing_hard` / `routing_agents_hard` from every
      manifest. Specify: (i) where contract texts live so one edit updates every consumer, noting
      that no shared contract-text mechanism exists to adopt today -- the H2-H9 text is scattered
      inline stage-by-stage across each `-hard` file, and the routing lib governs only which file
      to dispatch to, never what text it contains, so this must be built; name the existing
      single-shared-block pattern used for the `--lit` Stage 4a flow as the precedent to copy;
      (ii) how an extension adds or overrides a contract for its own task types; (iii) the
      migration path for the extensions that still declare a `routing_hard` block -- silent ignore,
      deploy-time warning, or hard error -- and state the reasoning, noting that no
      unrecognized-manifest-key path exists today; (iv) the disposition of the test and lint files
      Phase 1 enumerated as referencing `skill-orchestrate-hard` (updated, retargeted, or deleted),
      since they need handling regardless of the collapse.
- [ ] **A4 -- measure before assuming cheap.** Using Phase 1's measurements and a stage-header
      comparison, record how much of `skill-orchestrate-hard` is genuinely hard-specific versus
      shared skeleton, and how much of each `-hard` lifecycle skill and agent is boilerplate
      duplicated from its base counterpart. Report the hard-specific residue as the real migration
      surface. Record explicitly that the engine's multi-task stages live solely in the base
      engine, so none of that half migrates.
- [ ] **A5 -- team mode folds into the engine.** The decision is settled: parallel-teammate
      capability is preserved as a flag inside the single engine. Specify: (i) what happens to the
      three team skills and the synthesis agent -- deleted, or reduced to a fan-out helper the
      engine calls -- and state which, with reasoning; (ii) whether `--team` survives as a user
      flag or becomes an automatic decision from task shape; (iii) whether `--team-size` survives;
      (iv) how the teammate contract layer (per-teammate finding files, territory contracts, and
      the subagent-postflight correlation to the owning session) is expressed once instead of three
      times; (v) the graceful-degradation path when the experimental agent-teams environment
      variable is unset, which must be preserved explicitly, not dropped as incidental.
- [ ] Record in A5 that two open backlog tasks describe real defects in exactly the teammate
      contract layer being folded, so the fold must state where each defect is re-expressed if
      teammates are preserved at all. Do not assign their verdicts here; that is Phase 5's work.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts a hard-specific residue figure for `skill-orchestrate-hard`
and for each `-hard` skill/agent pair. These are measurements to be taken at implementation time by
stage-header comparison and line counting, not values carried over from research; the report states
the method alongside each figure so a reader can reproduce it.

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` - A4 and A5 sections
  appended

**Verification**:
- A4 answers all four sub-questions with a stated decision and reasoning, and reports the
  hard-specific residue measurement with its method.
- A5 answers all five sub-questions with a stated decision and reasoning, and the
  graceful-degradation path is named explicitly.
- Neither section re-opens the whether-question for A4 or A5.
- Neither section contains "to be determined", "TBD", or an equivalent deferral.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 4: Phase A design -- preserved assets, deletion ledger, and completeness gate (A6-A7) [NOT STARTED]

**Goal**: Enumerate every mechanism that must survive the collapse with its post-collapse home,
produce the deletion ledger with honest cost accounting, and gate Phase A as complete.

**Tasks**:
- [ ] **A6 -- preserved assets.** Produce a table with one row per mechanism, columns: mechanism,
      where it lives today (file, and function or stage name), where it lives after the collapse,
      and how its survival is verified. Cover at minimum every mechanism the task description
      names: GATE IN / GATE OUT checkpoint sequencing; scoped git commits per phase; artifact format
      validators; task-lock and session-registry concurrency control; the batch admission gates
      (self-modification, file_scope collision, cycle budget); `--lit` literature briefing
      injection; memory retrieval and `--clean` suppression; the four model flags; `--fast`; and
      the return-metadata handoff contract with the recovery path built on it.
- [ ] Mark the two mechanisms that are confirmed absent from the `/orchestrate` path today
      (`--lit` interactive resolution, and memory retrieval with `--clean` suppression) as
      REBUILD-REQUIRED rather than PRESERVE, cross-referencing Phase 2's A1 precondition. Their
      post-collapse home is a new build, not a migration, and the ledger must say so.
- [ ] **A7 -- deletion ledger.** Produce a table with one row per file proposed for deletion,
      columns: path, line count, what replaces it, and what capability is lost (or "none"). Include
      the lifecycle commands, the three `-hard` lifecycle skills, the three `-hard` agent files,
      `skill-orchestrate-hard`, the three team skills and the synthesis agent, and any lifecycle
      skill or agent orphaned by A1's decision.
- [ ] Report projected before/after totals against the measured baseline from Phase 1, with the
      description's recorded baseline shown alongside where they differ. Do not report an
      unqualified reduction figure: every reduction figure is accompanied by the capability-cost
      column and by the added surface the collapse introduces (the contract-text mechanism, the
      fan-out helper, the rehomed Stage 4a dispatch prep, and any new increment logic A2 requires).
- [ ] Net the ledger's savings against the mode-gated-section-loading chain explicitly, stating
      which savings belong to the collapse and which to mode-gating, so Phase 7 can assign those
      tasks' verdicts without double-counting.
- [ ] **Completeness gate.** Re-read the design report end to end. Confirm every one of A1-A7 has a
      stated decision with reasoning. Grep the report for deferral language ("to be determined",
      "TBD", "to be decided", "left open", "future work will decide") and resolve every hit or
      justify it as out-of-scope-by-design with a named owner. Record the gate result in a
      Completeness Gate section at the end of the report.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: prose

**Scope Hypothesis**: The ledger asserts a per-file line count and a projected before/after total.
Every line count is measured at implementation time from the live source store (never carried over
from the description's baseline without a stated delta), and the report records the measurement
command so the figures are reproducible.

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` - A6, A7, and
  Completeness Gate sections appended

**Verification**:
- A6's table has a row for every mechanism the task description enumerates, each with a named
  post-collapse home, and the two confirmed-absent mechanisms are marked REBUILD-REQUIRED.
- A7's ledger has a row per proposed deletion with all four columns populated; no row has an empty
  capability-cost cell.
- The projected reduction is reported against the measured baseline and is accompanied by the added
  surface, not stated as a bare number.
- The double-count netting against mode-gating is stated.
- The Completeness Gate section records a pass for all of A1-A7, and a repository grep of the report
  for deferral language returns no unresolved hit. This satisfies VERIFICATION BAR items 1 and 3.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 5: Backlog audit -- design-coupled cluster [NOT STARTED]

**Goal**: Assign exactly one verdict, with its citation, to every audit-scope task whose fate
depends on a Phase A decision.

**Tasks**:
- [ ] Create `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` with a
      Verdict Vocabulary section (ON-PATH, RESCOPE, ABSORB, MOOT, plus the orthogonal BLOCKING
      flag), a Method section, and a verdict table.
- [ ] Partition the Phase 1 roster into a design-coupled cluster and a remainder. The design-coupled
      cluster is every task whose `file_scope` or description-derived scope touches: the
      orchestrate engine (either variant), a lifecycle command, a lifecycle skill or agent (either
      variant), a team skill or the synthesis agent, the routing ladder or its consumers or a
      manifest routing block, the model-flag threading path, or the context-loading convention
      chain that targets the engine's multi-task section. Record the partition and its rule in the
      Method section so the remainder is defined by exclusion rather than by omission.
- [ ] For each task in the design-coupled cluster, read its full description and assign exactly one
      verdict, citing the specific Phase A decision (by A-item and by the sentence it turns on)
      that produces it. A MOOT verdict MUST name the specific row in Phase 4's deletion ledger that
      makes it moot; "probably obsolete" is not a verdict and must be rejected in review.
- [ ] Flag BLOCKING separately from the verdict where applicable. Evaluate at minimum the two
      candidates research surfaced: the blocked-verdict discrimination defect in the engine that A1
      makes the sole entry point, and the task-lock / session-registry heartbeat defect touching an
      A6 preserved asset. Also evaluate the handoff-absence-signal task as a softer candidate,
      since it governs whether the collapse's own rollout telemetry can be trusted. For each, state
      BLOCKING or NOT BLOCKING with reasoning; do not leave a candidate unevaluated.
- [ ] Verify, do not re-derive, the findings the task description already established for this
      cluster: the two model-flag threading tasks and the second's partial mootness under A4; the
      `--lit` threading task through the team skills; the two team-mode-lifecycle defect tasks; the
      hard-contract-delivery task the description states A4 subsumes; and the mode-gated-section
      chain. Record confirmation or contradiction with evidence in each case.
- [ ] For any task marked EVIDENCE-GAP in Phase 1, record its verdict as provisional and state the
      backfill required before the verdict is final. Do not assign a confident verdict on absent
      evidence.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: The design-coupled cluster is estimated at roughly 17 of the roster's tasks.
This is a hypothesis; the actual membership is produced at implementation time by applying the
stated partition rule to the Phase 1 roster, and the observed count is recorded. The count is not a
target -- a task is in the cluster if and only if the rule admits it.

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` - created;
  design-coupled cluster verdicts written

**Verification**:
- The Method section states the partition rule, and the cluster membership follows from it.
- Every task in the cluster has exactly one verdict cell, populated.
- Every verdict cites a specific A-item decision; every MOOT verdict additionally names a Phase 4
  ledger row.
- All three BLOCKING candidates are evaluated with a stated result and reasoning.
- Each of the description's pre-established findings for this cluster is marked confirmed or
  contradicted, with evidence.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 6: Backlog audit -- remainder cluster [NOT STARTED]

**Goal**: Assign exactly one verdict, with its citation, to every remaining audit-scope task, closing
the roster.

**Tasks**:
- [ ] For each task in the remainder cluster, read its full description and assign exactly one
      verdict under the same rules as Phase 5. A task genuinely unaffected by A1-A5 receives
      ON-PATH with a stated reason for its independence, plus a sequencing note relative to the
      refactor -- ON-PATH is a positive finding of independence, not a default for tasks not
      examined closely.
- [ ] Handle the three latex build-guard tasks explicitly. The task description states the expected
      verdict is to return them to the `extensions` topic untouched; confirm or contradict that
      expectation per task, noting that one of the three touches a core agent file and therefore
      may not be purely extension-internal.
- [ ] Handle the task carrying `topic: null` per Phase 1's recorded disposition: if admitted to the
      audit scope, assign it a verdict; if excluded, restate the exclusion reason here so the
      roster closes with an explicit accounting for every non-literature task.
- [ ] Handle the tasks Phase 1 marked EVIDENCE-GAP or DERIVED-FROM-DESCRIPTION: record which
      evidence tier the verdict rests on, and for EVIDENCE-GAP entries record the backfill
      operation Phase 9 must perform.
- [ ] Note without resolving any topic anomaly observed (a task whose `file_scope` is entirely
      extension-owned while carrying the core topic, or the reverse). These are re-topic inputs for
      Phase 9, not verdicts.
- [ ] Close the verdict table with a coverage line: total roster size, verdicts assigned, and the
      arithmetic showing every roster row has exactly one verdict.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: prose

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` - remainder
  cluster verdicts and coverage line appended

**Verification**:
- Every roster row from Phase 1 now appears exactly once in the verdict table with exactly one
  verdict; the coverage arithmetic is stated and balances. This satisfies VERIFICATION BAR item 2's
  coverage half.
- Every MOOT verdict in the whole table names a Phase 4 ledger row; a grep of the table for MOOT
  rows shows a ledger citation in each. This satisfies VERIFICATION BAR item 2's citation half.
- The three latex tasks each carry a confirmed-or-contradicted note against the expected verdict.
- The `topic: null` task's accounting is explicit.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 7: Verdict reconciliation, sequencing decisions, and Phase C operation manifest [NOT STARTED]

**Goal**: Turn the verdict table into an unambiguous, ordered list of backlog operations, so that
Phase C is mechanical application rather than further judgment.

**Tasks**:
- [ ] Resolve every sequencing tension with a stated direction and reasoning: the two
      call-site-counting tasks (the shared task-lookup-helper adoption lint and the scoped-commit
      propagation task) relative to A1's command deletions, whose call-site counts change depending
      on order; the model-flag mirror task relative to A4's deletion of its target file; and the
      double-count question between the collapse and the mode-gated-section chain, using Phase 4's
      netting. State a single direction per tension, not a pair of options.
- [ ] Finalize the BLOCKING set from Phases 5-6 and state, for each member, what specifically the
      collapse would inherit or entrench if it did not land first.
- [ ] Enumerate the successor implementation tasks the design requires. For each: a working title,
      a one-paragraph scope, its `file_scope` (source-store paths under
      `agent-system/extensions/**`, never `.claude/**`), and its dependencies. Apply the sizing
      rule from the task description: no single successor task both deletes a lifecycle skill and
      rewires its consumers; the rewiring task is a declared dependency of the deletion task. The
      rehome of memory retrieval and `--lit` resolution from Phase 2's A1 precondition is one such
      rewiring task and must precede every command or lifecycle-skill deletion.
- [ ] Produce the operation manifest as a table: one row per backlog operation, columns: operation
      (CREATE / REVISE / ABANDON / RETOPIC / DEPEND / BACKFILL), target task (or NEW-n for a task
      not yet numbered), the exact change, and the verdict or design decision authorizing it.
      Include a `file_scope` backfill row for every EVIDENCE-GAP task.
- [ ] Order the manifest so that CREATE operations precede the DEPEND operations that reference the
      new task numbers, and record that new task numbers are allocated at apply time from
      `next_project_number`, not pre-assigned in this manifest.
- [ ] Write the manifest to
      `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md`.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: prose

**Files to modify**:
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` - created

**Verification**:
- Each of the three named sequencing tensions has exactly one stated direction with reasoning.
- The BLOCKING set is final and each member states what would be entrenched.
- Every successor task has a title, scope, `file_scope` naming only source-store paths, and
  dependencies; a grep of the successor `file_scope` entries returns no `.claude/` path.
- No successor task's scope contains both a lifecycle-skill deletion and its consumer rewiring.
- Every non-ON-PATH verdict in the Phase 5-6 table maps to at least one manifest row, and every
  manifest row cites its authorizing verdict or design decision.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 8: Phase C -- create successor tasks [NOT STARTED]

**Goal**: Create every successor implementation task the manifest specifies, in `specs/state.json`,
each independently dispatchable with its own `file_scope`.

**Tasks**:
- [ ] Re-read the operation manifest's CREATE rows. For each, assemble the task record:
      `project_number` (allocated from `next_project_number`), `project_name` (snake_case slug),
      `status: "not_started"`, `task_type` (`meta` for source-store system changes),
      `topic: "core-agent-system"`, `description`, `created`, `dependencies`, `file_scope`,
      `last_updated`.
- [ ] Write each task through `state-write.sh` as the single mutex-guarded writer. Apply one CREATE
      per invocation, appending with `+=` against `.active_projects`; never assign
      `.active_projects = [...]` wholesale, which would discard existing entries.
- [ ] Guard against the MAX_ARG_STRLEN hazard: successor descriptions are expected to run several
      kilobytes each and audit-scope descriptions average roughly 5KB. Before each invocation,
      measure the assembled payload; if a single `--argjson` argument would approach the 128KB
      per-argument ceiling, split the description across a staged file read rather than passing it
      inline, or split the operation. Never batch multiple task payloads into one argument.
- [ ] After each write, re-read the affected record back from `state.json` and confirm it round-trips
      (the description is intact and not truncated, `file_scope` is present and non-empty,
      `dependencies` is present).
- [ ] Increment `next_project_number` correctly for each allocation, and record the allocated
      numbers back into the manifest so Phase 9's DEPEND rows can reference them.
- [ ] Commit after each successful green write, per the commit-per-green-substep mandate, staging
      only `specs/state.json` and the manifest.

**Timing**: 1.5 hours

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: The number of successor tasks is whatever Phase 7's manifest enumerates; this
plan asserts no count. At implementation time, confirm that the number of records added to
`.active_projects` equals the number of CREATE rows in the manifest, and report both.

**Files to modify**:
- `specs/state.json` - successor task records appended via `state-write.sh`
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` - allocated
  task numbers recorded against CREATE rows

**Verification**:
- `jq empty specs/state.json` succeeds (the file remains valid JSON).
- The count of `.active_projects` entries increased by exactly the number of manifest CREATE rows,
  and no pre-existing entry was removed (compare the pre-phase and post-phase sets of
  `project_number` values; the pre-phase set is a subset of the post-phase set).
- Every created task has a non-empty `file_scope` containing only `agent-system/extensions/**`
  paths, a non-null `description`, and `topic: "core-agent-system"`.
- No description round-trips truncated.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 9: Phase C -- revise, abandon, re-topic, and backfill [NOT STARTED]

**Goal**: Apply every REVISE, ABANDON, RETOPIC, and BACKFILL operation the manifest specifies to the
existing backlog.

**Tasks**:
- [ ] Apply REVISE operations: replace the description of each RESCOPE task with the revised text
      the manifest specifies, stating what changed and why within the description itself so a future
      reader of the task alone understands the rescope. One task per `state-write.sh` invocation,
      with the same payload-size guard as Phase 8.
- [ ] Apply ABANDON operations: transition each MOOT task to `abandoned` with a recorded reason that
      cites the specific deletion-ledger entry making it moot. Use the sanctioned status-update path
      rather than a hand-rolled status assignment, so TODO.md regeneration and any archival hooks
      stay consistent.
- [ ] Apply RETOPIC operations: set `topic` to `core-agent-system` for survivors the manifest
      designates, and return the latex build-guard tasks to `extensions` per Phase 6's confirmed
      verdicts. Confirm each target topic value already exists in `active_topics`; add none that the
      manifest does not authorize.
- [ ] Apply BACKFILL operations: populate `file_scope` for each EVIDENCE-GAP task from the evidence
      recorded in Phase 1 and Phase 6, and finalize that task's provisional verdict in the verdict
      report, converting it from provisional to final or recording that it remains blocked on
      evidence.
- [ ] After each write, read the affected record back and confirm the intended field changed and no
      sibling field was lost. Confirm `.artifacts` arrays on touched tasks are unchanged (this phase
      touches no artifact links).
- [ ] Commit after each successful green write, staging only `specs/state.json` and the affected
      report.

**Timing**: 1.5 hours

**Depends on**: 8

**Verification Tier**: full

**Files to modify**:
- `specs/state.json` - descriptions, statuses, topics, and `file_scope` fields updated via
  `state-write.sh`
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` - provisional
  verdicts finalized

**Verification**:
- `jq empty specs/state.json` succeeds.
- Every manifest REVISE row's target has the revised description; every ABANDON row's target has
  status `abandoned` and a recorded reason citing a ledger entry; every RETOPIC row's target carries
  the specified topic; every BACKFILL row's target has a non-empty `file_scope`.
- No task record lost a field: the set of keys per touched record matches its pre-phase key set.
- The count of `.active_projects` entries is unchanged from the end of Phase 8 (abandonment is a
  status transition here, not a removal; any archival move is a separate `/todo` operation).
- No provisional verdict remains unresolved in the verdict report.
- `git status --porcelain` shows changes only under `specs/`.

---

### Phase 10: Phase C -- dependency ordering, TODO regeneration, and verification-bar closeout [NOT STARTED]

**Goal**: Write the dependency ordering into `state.json`, regenerate `specs/TODO.md`, and close
every item of the task's VERIFICATION BAR with evidence.

**Tasks**:
- [ ] Apply the manifest's DEPEND operations: write each `dependencies` array so the wave generator
      produces the intended sequence. Encode at minimum the BLOCKING set as dependencies of the
      collapse tasks that would otherwise inherit their defects, the rehome-before-deletion ordering
      from Phase 2's A1 precondition, and the sequencing directions Phase 7 fixed for the
      call-site-counting tasks and the model-flag mirror task.
- [ ] Confirm every dependency edge references an existing `project_number`, including the numbers
      allocated in Phase 8.
- [ ] Regenerate the ordering and TODO.md via `generate-task-order.sh` (and `generate-todo.sh` where
      the regeneration path requires it, or `state-write.sh --regen-todo` on the final write). Never
      hand-edit `specs/TODO.md`.
- [ ] Confirm the generated dependency waves are acyclic: the generator's Kahn's-algorithm wave
      computation must place every task in a wave, with no task left unplaced. A cycle manifests as
      unplaced tasks; treat any such report as a phase failure and repair the offending edge.
- [ ] Confirm the Core Agent System section of the regenerated TODO.md reflects the new ordering,
      including the created successor tasks and excluding the abandoned ones per the generator's
      own rendering rules.
- [ ] Write a closeout section into
      `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` recording
      evidence for each of the five VERIFICATION BAR items: (1) every A1-A7 answered with a
      decision, citing the Phase 4 completeness gate; (2) every audit-scope task carries exactly one
      verdict and every MOOT names its ledger entry, citing the Phase 6 coverage arithmetic; (3) the
      projected reduction is reported against the measured baseline with A6 accounted item by item,
      citing Phase 4's ledger; (4) the regenerated TODO.md has acyclic waves and an updated Core
      Agent System section, citing this phase's generator output; (5) no file under
      `agent-system/extensions/**` or `.claude/**` was created, modified, or deleted, citing the
      working-tree check below.
- [ ] Run the boundary check: `git status --porcelain` plus a diff of committed paths for this task's
      commits must show no path outside `specs/`. Record the command and its output in the closeout.
- [ ] Write the execution summary to
      `specs/116_core_agent_system_consolidation/summaries/01_orchestrate-centric-consolidation-summary.md`.

**Timing**: 1 hour

**Depends on**: 9

**Verification Tier**: full

**Files to modify**:
- `specs/state.json` - `dependencies` arrays written via `state-write.sh`
- `specs/TODO.md` - regenerated, never hand-edited
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` - closeout
  section appended
- `specs/116_core_agent_system_consolidation/summaries/01_orchestrate-centric-consolidation-summary.md` - created

**Verification**:
- `jq empty specs/state.json` succeeds and every dependency edge resolves to an existing
  `project_number`.
- `generate-task-order.sh` completes successfully and places every task in a wave, with no unplaced
  task (acyclicity). This satisfies VERIFICATION BAR item 4.
- `specs/TODO.md` is regenerated by the script, and its Core Agent System section lists the created
  successor tasks in the intended order.
- The closeout section records evidence for all five VERIFICATION BAR items.
- `git status --porcelain` and the per-commit path diff show no path outside `specs/`. This satisfies
  VERIFICATION BAR item 5.

---

## Testing & Validation

- [ ] `jq empty specs/state.json` succeeds after every Phase C write.
- [ ] The pre-task set of `project_number` values is a subset of the post-task set (no task record
      silently disappeared).
- [ ] No task record lost `.artifacts`, `.description`, `.file_scope`, or `.dependencies` fields
      across the Phase C writes.
- [ ] `generate-task-order.sh` produces acyclic waves with every task placed.
- [ ] `specs/TODO.md` was produced by the generator, not hand-edited (its generated timestamp line
      is present and current).
- [ ] The design report contains no unresolved deferral language for any of A1-A7.
- [ ] Every audit-scope task appears exactly once in the verdict table with exactly one verdict.
- [ ] Every MOOT verdict names a deletion-ledger row that exists in the design report.
- [ ] Every created successor task has a non-empty `file_scope` containing only
      `agent-system/extensions/**` paths.
- [ ] `git status --porcelain` shows no modified, added, or deleted path outside `specs/`.
- [ ] `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no
      new task-number reference outside `specs/**`, since all artifacts of this task live under
      `specs/` and successor descriptions must cite durable anchors rather than task numbers in the
      deliverable text they specify.

## Artifacts & Outputs

- `specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md` - measured
  baseline, re-verified findings, and the audit-scope roster with evidence tiers.
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` - the Phase A target
  state design specification covering A1-A7 plus the completeness gate.
- `specs/116_core_agent_system_consolidation/reports/04_backlog-audit-verdicts.md` - one verdict per
  audit-scope task with citations, the BLOCKING set, and the coverage arithmetic.
- `specs/116_core_agent_system_consolidation/reports/05_backlog-operation-manifest.md` - the ordered
  backlog operation manifest, allocated successor task numbers, and the VERIFICATION BAR closeout.
- `specs/116_core_agent_system_consolidation/summaries/01_orchestrate-centric-consolidation-summary.md` -
  execution summary.
- `specs/state.json` - successor tasks created; RESCOPE descriptions revised; MOOT tasks abandoned
  with reasons; survivors re-topiced; `file_scope` backfilled; dependency ordering written.
- `specs/TODO.md` - regenerated from `state.json`.

## Rollback/Contingency

Every write in this task is confined to `specs/`, and every `state.json` mutation goes through
`state-write.sh`, which stages atomically under the `specs/.scope-lock` mutex and validates before
the move. Rollback options, in increasing order of scope:

- **Single bad write**: the offending commit is scoped to `specs/state.json` plus one report, so
  `git revert` of that commit restores the prior state; follow with a TODO.md regeneration.
- **A whole Phase C phase**: revert that phase's commits in reverse order, then regenerate TODO.md.
  Because Phase 8 (creates) precedes Phase 9 (revises/abandons) and Phase 10 (dependencies), the
  reverts unwind cleanly in that order.
- **Full task rollback**: revert every commit carrying this task's number, then regenerate TODO.md.
  The four report artifacts and the summary are additive files under the task directory; deleting
  them has no effect on the rest of the system.

If Phase A cannot reach a decision on an A-item because the underlying system state contradicts the
research premise (for example, if the dispatch-bypass finding does not reproduce), record the
contradiction in the design report, mark the task `[BLOCKED]` with that reason rather than
proceeding to Phase B on a false premise, and do not begin Phase C. Phase C is the only phase that
mutates shared backlog state; leaving it unstarted keeps the repository in its pre-task condition.
