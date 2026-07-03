# Implementation Plan: Orchestrator Discipline Contract and Burnout Circuit-Breaker

- **Task**: 773 - Add orchestrator-role discipline contract and burnout circuit-breaker
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: 772 (done), 779 (done)
- **Research Inputs**: reports/01_orchestrator_discipline_burnout_breaker.md
- **Artifacts**: plans/01_orchestrator-discipline-burnout-breaker.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The H2 anti-analysis contract is injected only into IMPLEMENT dispatch prompts via
`build_hard_mode_prompt_context()`, leaving the ORCHESTRATOR role itself ungoverned — the
root cause of the burnout incident that motivated this task (circular reconsideration ending in
an unsound inline BLOCKED conclusion). This plan creates
`.claude/context/contracts/orchestrator-discipline.md` (a single-copy contract binding the
orchestrator role: no inline design/proof analysis, no reading implementation source, no running
builds, no mid-cycle strategy reconsideration; when a phase cannot complete in a bounded
dispatch, the only allowed responses are (a) dispatch a fresh research/audit agent or (b) escalate
via the blocker ladder — never absorb the work), registers it in `index.json` following
`convergence.md`'s empty-`load_when` precedent, and wires it into `skill-orchestrate-hard`'s
state-machine loop at two sub-stages reserved by task 772: a once-per-invocation Stage 1c preamble
and an every-cycle Stage 3c burnout circuit-breaker gate. Scope is hard-mode only. Definition of
done: contract file exists and is registered; both SKILL.md copies carry Stage 1c + Stage 3c and
remain byte-identical.

### Research Integration

All decisions are taken directly from `reports/01_orchestrator_discipline_burnout_breaker.md`:

- **Wiring mechanism** (report Findings / Decisions): reference-plus-inline-directive at two
  loop-top sub-stages, NOT a `build_hard_mode_prompt_context` contract slot — contract slots
  inject into sub-agent prompts, but this contract governs the orchestrator's own turns, which
  have no prompt string to inject into.
- **Insertion points** (report §Codebase Patterns): Stage 1c immediately after Stage 1b
  (currently ends before Stage 2 at line 166); Stage 3c immediately after Stage 3b and BEFORE
  Stage 4's state handlers (line 243) — the true top-of-loop enforcement point before any dispatch
  decision. Both spots fall inside task 772's reserved Stage 1b→3b region, distinct from 779's
  `build_hard_mode_prompt_context` CONTRACT SLOTS (lines ~385-397).
- **Registration** (report Recommendation 2): `index.json` entry with `load_when` all-empty
  (`task_types: []`, `agents: []`, `commands: []`), `subdomain: "contracts"`, `domain: "core"`,
  mirroring `convergence.md` exactly (orchestrator-loop-referenced, not agent-context-loaded).
- **Single-copy vs dual-copy** (report Executive Summary): `contracts/*.md` and `index.json` are
  SINGLE-COPY (no `.claude/extensions/core/context/` mirror — `contracts` absent from the core
  manifest's `provides.context`, no core-extension `index.json`). `SKILL.md` is DUAL-COPY and must
  be edited byte-identically in both `.claude/skills/` and `.claude/extensions/core/skills/`.
- **Burnout signal mapping** (report §Burnout Circuit-Breaker): the three task-named signals map
  onto `context-exhaustion-detection.md`'s three categories, reframed for orchestrator
  self-monitoring; the "forced handoff" REUSES existing dispatch/escalation paths (fresh audit
  dispatch shaped like Stage 4b's; jump to Stage 6 escalation) rather than inventing a new
  handoff-artifact type; a single scalar counter piggybacks on the existing `loop_guard_file`.
- **Corollary fix** (report §Context References wiring): `recovery.md` (created by 779) is
  referenced only inside the SKILL.md CONTRACT SLOTS block (line 393), never added to the Context
  References prose list (lines 64-72) — closed in the same edit pass.

### Prior Plan Reference

No prior plan for task 773. Task 779's plan (Phase 6 dual-copy `diff -q` verification pattern) is
the calibration reference the research cites for the SKILL.md dual-copy risk; that verification
discipline is adopted as Phase 6 here.

### Roadmap Alignment

No `roadmap_path` provided and no `roadmap_flag` set for this dispatch. No ROADMAP.md phases added.

## Goals & Non-Goals

**Goals**:
- Create `.claude/context/contracts/orchestrator-discipline.md` using the research's 6-section
  structure (modeled on anti-analysis.md / convergence.md / recovery.md).
- Register the contract in `.claude/context/index.json` with empty `load_when` (convergence.md
  precedent).
- Add the contract (and the missing `recovery.md` entry) to `skill-orchestrate-hard`'s Context
  References list.
- Insert Stage 1c (once-per-invocation orchestrator-discipline preamble) after Stage 1b.
- Insert Stage 3c (every-cycle burnout circuit-breaker gate) after Stage 3b, before Stage 4.
- Extend the `loop_guard_file` JSON shape with a `burnout_signals_this_session` scalar counter.
- Keep both SKILL.md copies byte-identical (`diff -q` clean).

**Non-Goals**:
- Modifying `skill-orchestrate` (base, non-hard) — it has no contract-slot mechanism; out of
  scope per the hard-mode-only instruction.
- Adding or altering any `build_hard_mode_prompt_context` CONTRACT SLOT (779's territory).
- Overwriting or restructuring task 772's `<!-- BEGIN/END 772 ... -->` pure-dispatcher blocks —
  compose around them, never over them.
- Creating a new persisted state sidecar file (`.orchestrator-burnout-state.json`) — the counter
  reuses `loop_guard_file`.
- Instrumenting turn-counting via a script — Stage 3c is a self-monitored behavioral gate (like
  H2), not a jq-computed threshold, except for the single counter field.
- Mirroring the contract or index.json into `.claude/extensions/core/context/` (single-copy).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Forgetting the dual-copy SKILL.md edit reintroduces drift | H | M | Every SKILL.md phase edits BOTH paths as one atomic unit; Phase 6 verifies with `diff -q` (779 Phase 6 pattern) |
| Stage 3c self-check silently skipped the way the original burnout happened | H | M | Phrase Stage 3c as a mandatory gate using anti-analysis.md's imperative violation-and-forced-action sentence pattern, not an optional guideline |
| Edits collide with 772's reserved blocks or 779's CONTRACT SLOTS | M | L | Insert strictly after Stage 1b (line 162) and after Stage 3b (line 239); do not touch lines 24-62 (772 blocks) or ~385-397 (779 slots) |
| Mirroring contract/index.json into core (over-sync) | M | L | Contract + index.json are single-copy; Phase 1/2 write only `.claude/context/`; Phase 6 confirms no core mirror created |
| Over-mechanizing the burnout breaker (script-counting turns) | M | L | Accept behavioral-contract nature; only the scalar `burnout_signals_this_session` counter is mechanized in the existing 3b jq write |
| index.json malformed after edit | M | L | Validate with `python3 -c "import json; json.load(...)"` in Phase 2 and Phase 6 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 5 |

Phases within the same wave can execute in parallel. Phases 3, 4, 5 all edit the same
`SKILL.md` pair and are therefore serialized across waves 2-4; Phase 2 (index.json) is a
different file and runs parallel to Phase 3 in wave 2.

### Phase 1: Author orchestrator-discipline.md contract [COMPLETED]

- **Goal:** Create the single-copy contract file with the research's 6-section structure.
- **Tasks:**
  - [x] Create `.claude/context/contracts/orchestrator-discipline.md` (single-copy; do NOT create
        any `.claude/extensions/core/context/contracts/` mirror).
  - [x] Section 1 — Title + provenance: name it "Orchestrator Discipline Contract"; state it
        exists because H2 (anti-analysis.md) injects only into IMPLEMENT dispatches via
        `build_hard_mode_prompt_context`, leaving the orchestrator ROLE ungoverned; cite the
        task-773 motivating incident (circular reconsideration, "before I concede... ONE more
        time", BLOCKED reached via an unsound inline conclusion later caught by a standard-mode
        audit).
  - [x] Section 2 — Prohibited Actions: the four literal items, each with one sentence of
        rationale tied back to 772's Tool Constraints so the two documents do not drift — (i) no
        inline design/proof analysis, (ii) no reading implementation source (backs 772's Forbidden
        Reads behaviorally), (iii) no running builds (backs 772's Forbidden Bash behaviorally),
        (iv) no mid-cycle strategy reconsideration without a fresh dispatch.
  - [x] Section 3 — The Only Two Allowed Responses when a phase cannot complete in a bounded
        dispatch, phrased as a small lettered ladder like recovery.md's rungs: (a) dispatch a
        fresh research/audit agent (`$RESEARCH_AGENT`, focus_prompt = the exact unresolved
        question); (b) escalate via the blocker ladder (Stage 6). Add the explicit statement that
        absorbing the work inline is NOT a third option and is the anti-pattern this contract
        forbids.
  - [x] Section 4 — Burnout Circuit-Breaker Signals: reframe context-exhaustion-detection.md's
        three categories for orchestrator self-monitoring, using the report's three self-check
        questions verbatim in intent (re-read same path without an intervening Agent dispatch;
        2+ consecutive inline-reasoning turns with no Agent dispatch; about to reverse a
        phase/target/escalation decision without a fresh dispatch having produced a new finding).
  - [x] Section 5 — Forced-Handoff / Forced-Dispatch Mechanism: on any signal, stop the current
        line of reasoning immediately (mid-sentence if needed) and take response (a) or (b);
        reasoning-about-what-a-phase-should-do → (a); deciding-whether-to-keep-escalating → (b);
        no new artifact type.
  - [x] Section 6 — Domain Specialization / Scope note: `--hard`-only; governs
        `skill-orchestrate-hard`'s loop specifically; `skill-orchestrate` (base) out of scope.
  - [x] Keep the file ~90-110 lines, matching the tone/size of anti-analysis.md and convergence.md.
- **Timing:** 1.25 hours
- **Depends on:** none
- **Files to create:**
  - `.claude/context/contracts/orchestrator-discipline.md` — new single-copy contract
- **Verification:**
  - File exists; all six sections present; the four prohibited actions and the two allowed
    responses are stated verbatim to the task description; no core mirror created.

### Phase 2: Register contract in index.json [COMPLETED]

- **Goal:** Add an index.json entry mirroring convergence.md's registration exactly.
- **Tasks:**
  - [x] Add an entry to `.claude/context/index.json` for `contracts/orchestrator-discipline.md`
        with `load_when: { task_types: [], agents: [], commands: [] }`, `subdomain: "contracts"`,
        `domain: "core"`, a `summary`, `keywords` (e.g. orchestrator-discipline, burnout,
        circuit-breaker, hard-mode, H-orch), `topics` (hard-mode, contracts, orchestration), and
        `line_count` matching the created file.
  - [x] Do NOT create any core-extension index.json (none exists; single-copy).
- **Timing:** 0.25 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/context/index.json` — add one contracts entry (single-copy)
- **Verification:**
  - `python3 -c "import json; json.load(open('.claude/context/index.json'))"` parses clean;
    the new entry's `load_when` is all-empty; `line_count` matches the file.

### Phase 3: Wire Context References list in SKILL.md (dual-copy) [COMPLETED]

- **Goal:** Add the new contract and the missing recovery.md entry to the Context References list.
- **Tasks:**
  - [x] In the Context References section (lines 64-72) add a line for
        `.claude/context/contracts/orchestrator-discipline.md` describing it as the
        orchestrator-role discipline contract governing the state-machine loop itself (not
        implement dispatches).
  - [x] Add the currently-missing `.claude/context/contracts/recovery.md` entry to the same list
        (779 created it and registered it in index.json but never added it to this prose list;
        it appears only inside the CONTRACT SLOTS block at line 393).
  - [x] Apply the identical edit to BOTH `.claude/skills/skill-orchestrate-hard/SKILL.md` and
        `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
- **Timing:** 0.25 hours
- **Depends on:** 3 requires the contract path from Phase 1; serialized before Phase 4/5 (same file)
- **Files to modify:**
  - `.claude/skills/skill-orchestrate-hard/SKILL.md` — Context References list
  - `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical edit
- **Verification:**
  - Both files contain the two new reference lines; `diff -q` between the two copies is clean.

### Phase 4: Insert Stage 1c orchestrator-discipline preamble (dual-copy) [COMPLETED]

- **Goal:** Add a once-per-invocation preamble after Stage 1b that binds the run to the contract.
- **Tasks:**
  - [x] Insert a new "Stage 1c: Orchestrator Discipline Preamble" immediately after Stage 1b
        (after current line 162, before Stage 2 at line 166). It runs ONCE per invocation.
  - [x] Content: instruct the orchestrator to state (to itself, in its own transcript) that it is
        bound by `orchestrator-discipline.md` for this session, with a
        `Read .claude/context/contracts/orchestrator-discipline.md` pointer — mirroring
        anti-analysis.md's two-part reference+directive pattern (pointer here, enforceable checklist
        inlined in Stage 3c).
  - [x] Do NOT place this inside or overlapping the 772 `<!-- BEGIN/END 772 ... -->` blocks
        (lines 24-62) or Stage 1b's routing logic.
  - [x] Apply identically to BOTH SKILL.md copies.
- **Timing:** 0.5 hours
- **Depends on:** 3
- **Files to modify:**
  - `.claude/skills/skill-orchestrate-hard/SKILL.md` — new Stage 1c after Stage 1b
  - `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical edit
- **Verification:**
  - Stage 1c heading present after Stage 1b and before Stage 2 in both copies; `diff -q` clean.

### Phase 5: Insert Stage 3c burnout gate + loop_guard counter (dual-copy) [COMPLETED]

- **Goal:** Add the every-cycle burnout circuit-breaker gate at the true top-of-loop enforcement
  point, plus the scalar counter it increments.
- **Tasks:**
  - [x] Insert a new "Stage 3c: Burnout Circuit-Breaker Gate" immediately after Stage 3b (after
        current line 239) and BEFORE Stage 4's state handlers (line 243). It runs EVERY loop
        iteration, after `current_status` is known (3a) and the loop guard is persisted (3b), but
        strictly before any dispatch decision.
  - [x] Phrase the three self-checks from Section 4 of the contract as a mandatory gate using
        anti-analysis.md's imperative violation-and-forced-action sentence pattern (state the
        violation condition and the forced action in the same sentence — not an optional
        guideline).
  - [x] Forced action reuses existing paths: reasoning-about-what-a-phase-should-do → dispatch
        `$RESEARCH_AGENT` with focus_prompt = a literal restatement of the stuck question (the
        Stage 4b divergence-audit dispatch shape, triggered by a burnout signal instead of churn
        count); deciding-whether-to-keep-escalating → jump directly to Stage 6. No new artifact
        type.
  - [x] Extend the `loop_guard_file` JSON shape in Stage 2 (lines 183-195) with a
        `burnout_signals_this_session` field initialized to 0; increment it from Stage 3c in the
        same 3b-style jq write that already touches `loop_guard_file` (no new sidecar file).
  - [x] Apply identically to BOTH SKILL.md copies.
- **Timing:** 1.0 hours
- **Depends on:** 4
- **Files to modify:**
  - `.claude/skills/skill-orchestrate-hard/SKILL.md` — new Stage 3c + loop_guard counter field
  - `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical edit
- **Verification:**
  - Stage 3c heading present after Stage 3b and before Stage 4 in both copies; the three
    self-checks and both forced-action branches are present; `burnout_signals_this_session`
    appears in both the Stage 2 init and the Stage 3c increment; `diff -q` clean.

### Phase 6: Verify byte-identity and validate wiring [COMPLETED]

- **Goal:** Confirm dual-copy integrity, single-copy correctness, and structural soundness.
- **Tasks:**
  - [x] `diff -q .claude/skills/skill-orchestrate-hard/SKILL.md
        .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` → must report identical.
  - [x] Confirm NO `.claude/extensions/core/context/contracts/orchestrator-discipline.md` and NO
        `.claude/extensions/core/context/index.json` were created (single-copy invariant).
  - [x] Validate `.claude/context/index.json` parses and the new entry has all-empty `load_when`.
  - [x] Grep both SKILL.md copies for `Stage 1c`, `Stage 3c`, `orchestrator-discipline.md`,
        `recovery.md`, and `burnout_signals_this_session` — all present in both.
  - [x] Confirm the 772 `<!-- BEGIN/END 772 ... -->` blocks and 779's CONTRACT SLOTS block are
        unmodified (git diff scoped to the intended regions only).
- **Timing:** 0.5 hours
- **Depends on:** 2, 5
- **Files to modify:** none (verification only)
- **Verification:**
  - All `diff -q`/grep/json checks pass; git diff touches only the intended regions.

## Testing & Validation

- [x] `diff -q` between the two SKILL.md copies is clean (byte-identical).
- [x] `python3 -c "import json; json.load(open('.claude/context/index.json'))"` succeeds and the
      new entry has `load_when` all-empty.
- [x] `.claude/context/contracts/orchestrator-discipline.md` exists with all six sections; the
      four prohibited actions and two allowed responses match the task description verbatim.
- [x] Both SKILL.md copies contain Stage 1c (after Stage 1b, before Stage 2) and Stage 3c (after
      Stage 3b, before Stage 4), plus the two new Context References lines and the
      `burnout_signals_this_session` counter.
- [x] No core mirror of the contract or index.json was created; 772/779 blocks untouched.

## Artifacts & Outputs

- `.claude/context/contracts/orchestrator-discipline.md` (new, single-copy)
- `.claude/context/index.json` (modified — one new entry)
- `.claude/skills/skill-orchestrate-hard/SKILL.md` (modified — Context References, Stage 1c,
  Stage 3c, loop_guard counter)
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified — byte-identical)
- `specs/773_orchestrator_discipline_contract_burnout_breaker/plans/01_orchestrator-discipline-burnout-breaker.md` (this file)
- `specs/773_orchestrator_discipline_contract_burnout_breaker/summaries/01_orchestrator-discipline-burnout-breaker-summary.md` (on implementation)

## Rollback/Contingency

All changes are additive and confined to five files. To revert: delete
`.claude/context/contracts/orchestrator-discipline.md`, remove its `index.json` entry, and revert
the Stage 1c / Stage 3c / Context References / loop_guard-counter edits in both SKILL.md copies
(a single `git checkout -- <paths>` on the five files restores the pre-task state). Because the
edits compose around — never overwrite — the 772 and 779 blocks, reverting 773 cannot damage
those siblings' work. Per recovery.md, prefer fix-forward over rollback; snapshot via
`bash .claude/scripts/git-snapshot.sh` before any destructive git operation on uncommitted work.
