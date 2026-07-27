# Implementation Plan: Task #925

- **Task**: 925 - Add a depth-first phase-closure contract and a per-item pre-edit verification gate to core implementers
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: 922, 924 (both shipped this session; their outputs are consumed by name here)
- **Research Inputs**: `specs/925_depth_first_phase_closure_and_pre_edit_gate/reports/01_depth-first-closure-pre-edit-gate.md`
- **Artifacts**: plans/01_depth-first-closure-pre-edit-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task closes two related holes on the core implementer surface. First, neither standard nor
hard mode forbids a single dispatch from opening several phases at once, which strands phases at
`[PARTIAL]` and blocks task completion outright. Second, nothing requires cheap per-item evidence
before an edit from a mechanically-generated list lands, so false positives in such lists reach
the working tree unchallenged.

The approach authors two new sibling contracts in the source store — `phase-closure.md`
(depth-first closure, cheapest-first ordering, stop-at-boundary) and `pre-edit-gate.md`
(proportionate per-item probe before edit) — then wires both into the four core implementer files
via explicit `@`-reference bullets, which research established is the actual load-bearing
mechanism in this codebase. A supplementary `index-entries.json` registration and a durable
architecture note record the placement/injection findings so downstream propagation work inherits
them rather than re-deriving them.

### SOURCE-STORE RULE (binding, applies to every phase)

The source of truth is `agent-system/extensions/core/`. `.claude/` is a **gitignored, disposable
deploy artifact** regenerated from the source store. **Every edit in every phase below MUST
target `agent-system/extensions/**` and MUST NEVER target `.claude/**`.** Note the asymmetry that
makes this easy to get wrong: the *file paths you edit* are `agent-system/extensions/core/...`,
but the *reference strings written inside those files* use the deployed `@.claude/context/...`
form, because that is what the agent sees at runtime. Editing a source file to contain a
`.claude/`-prefixed reference string is correct; editing a file *under* `.claude/` is not.

### No task-number references in deliverables

No file authored or edited outside `specs/**` may cite a task number ("task N", "tasks N-M").
Cite durable anchors instead: filenames, section headings, quoted field names.

### Line-number caveat

All anchors below are symbol names and quoted strings. Do not locate edit sites by line number;
the referenced files are actively edited and line numbers drift.

### Research Integration

Key findings driving this plan:

- **"Verified absent" confirmed exactly**: zero hits for depth-first / breadth-first /
  "one phase at a time" across the entire source store.
- **Two distinct failure shapes must both be addressed.** Standard mode
  (`skills/skill-implementer/SKILL.md`) says only `Execute phases sequentially` and dispatches
  the entire phase loop in a single Agent call; `agents/general-implementation-agent.md` Stage 4
  ("Execute File Operations Loop") iterates `For each phase starting from resume point:` with no
  cost-ordering and no stop condition other than "all phases complete". Hard mode
  (`skills/skill-implementer-hard/SKILL.md` Stage 3b, "Single-Phase Dispatch Context (H1)") uses
  a `grep -E '^### Phase ... \[(NOT STARTED|PARTIAL|IN PROGRESS)\]' | head -1` heading scan that
  treats `PARTIAL` and `NOT STARTED` as **equal-priority, position-ordered** — which is precisely
  what permits opening a new phase while an earlier-opened one sits `PARTIAL`. The contract must
  speak to both shapes; they fail differently.
- **The `@`-reference is the load-bearing mechanism, not directory placement.** Research
  confirmed 12/12 `contracts/*.md` index registrations across core plus all 15 extensions list
  only `*-hard` agent names — zero exceptions. Directory placement therefore carries a
  hard-mode-only *connotation* but no *mechanism*; the explicit `@`-reference bullet in an agent's
  "Context References" section is what actually causes loading.
- **No central injection point exists.** Only core's `agents/general-implementation-agent.md`
  runs the adaptive `context-discovery.md` query; no extension implementation agent and no
  hard-mode agent does. `skill-base.sh`'s `context_injection` lifecycle hook runs the *opposite*
  direction (extensions injecting into core), and no shared dispatch-prompt builder exists.
  Direct precedent: `cslib-implementation-hard-agent.md` hand-copies core's contract references
  bullet-by-bullet. **Consequence: downstream propagation to extension implementers is real,
  per-file work and cannot be closed as free.** Phase 5 records this as a durable artifact.
- **Both composition partners shipped this session and must be wired by name**: `plan-format.md`'s
  `**Scope Hypothesis:**` field explicitly declares its implementation-side consumer
  "out-of-scope for this document" — the pre-edit gate is that consumer. `status-markers.md`'s
  `[COMPLETED WITH EXCLUSIONS]` marker and `plan-format.md`'s `#### Reasoned Exclusions`
  `Item | Reason | Evidence` table are the shipped landing zone for a failed-probe item; the
  `Evidence` column is where the probe result goes.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` consulted for this task (no `roadmap_path` provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Author a depth-first phase-closure contract containing all three required clauses: close one
  phase entirely before opening the next; order remaining phases cheapest-closure-first; and
  **stop at a closed phase boundary** rather than opening a phase that cannot be finished within
  the dispatch.
- State the single-dispatch scoping **explicitly and verbatim** so the contract cannot be read as
  contradicting `plan-format.md`'s "Phases within the same wave can execute in parallel" or
  `context/contracts/territory.md`'s cross-agent parallel dispatch governance.
- Author a per-item pre-edit verification gate requiring cheap, blast-radius-proportionate
  evidence before any item from a mechanical list is applied, routing failed items into the
  existing `#### Reasoned Exclusions` record rather than a new parallel schema.
- Wire both contracts into all four core implementer files via explicit `@`-reference bullets.
- Record the placement and no-central-injection-point findings as durable in-repo content.

**Non-Goals**:
- Touching extension implementation agents. Deliberately out of scope; the reach gap is a
  separate downstream concern.
- Touching the orchestrator skills (`skill-orchestrate`, `skill-orchestrate-hard`).
- Changing hard mode's Stage 3b selector regex or standard mode's Stage 4 loop *code*. The
  contract constrains behavior by reference; rewriting either mechanism is a larger, separate
  change and would risk the phase-count regexes other scripts depend on.
- Inventing a fourth verification-tier-like axis or a competing exclusion record format.
- Redeploying `.claude/` from the source store. Deployment is handled by the existing deploy
  path, not by this task's phases.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Contract written but not wired, silently reproducing the exact defect (invisible to standard-mode dispatches) | H | M | Phase 3 makes each of the four `@`-reference bullets a literal, individually grep-checkable step; Phase 6 re-greps all four files as a gate |
| Depth-first rule read as contradicting the wave table; one rule gets ignored | H | M | Scope-limiting sentence is authored verbatim in Phase 1, named in that phase's verification, and re-checked verbatim in Phase 6 |
| Future contributor assumes `context/contracts/` is hard-mode-only (per the 100% precedent) and skips standard-mode wiring for a later contract | M | M | Both new contracts carry a header note stating they load via explicit reference in BOTH modes; Phase 5 documents the directory convention and its first counter-example |
| An edit lands under `.claude/**` instead of `agent-system/extensions/**` | H | L | Every phase's file list is absolute-prefixed with `agent-system/extensions/core/`; Phase 6 greps `git status` for any `.claude/` path |
| Pre-edit gate written as an unbounded "verify everything" rule that agents deflect into analysis paralysis | M | M | Contract is authored proportionate-to-blast-radius with concrete cheap probes (reference count, build probe, definition lookup) and an explicit cheapness ceiling; it must state it is NOT a license for open-ended investigation |
| Task-number citation leaks into a source-store file | M | M | Phase 6 greps all touched non-`specs/**` files for task-number patterns |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5 | 3 |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

**Note on the wave table and the contract this task authors**: these two are not in tension.
The wave table governs what the *orchestrator* may dispatch to *different agents* concurrently.
The contract authored in Phase 1 governs how a *single agent* sequences its own work within one
dispatch. An agent executing this plan still closes one phase entirely before opening the next,
even where the table shows two phases in the same wave.

---

### Phase 1: Author the depth-first phase-closure contract [COMPLETED]

**Goal**: Create `agent-system/extensions/core/context/contracts/phase-closure.md` containing the
depth-first closure rule with all three required clauses and the explicit single-dispatch scoping
statement.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/contracts/phase-closure.md`.
- [x] Write a header note stating plainly that this contract is loaded via **explicit
      `@`-reference in BOTH standard and hard mode**, not by directory convention — and that
      placement in `context/contracts/` does not imply hard-mode-only applicability. This is the
      first non-hard-exclusive occupant of the directory and must say so.
- [x] Write the **Close-before-open** clause: a dispatch closes one phase entirely — all its
      steps done, its verification run, its heading marker advanced past `[IN PROGRESS]` — before
      opening any other phase. Cite `context/standards/status-markers.md` for the phase-heading
      marker vocabulary.
- [x] Write the **Cheapest-closure-first ordering** clause: among the phases eligible to open
      next, prefer the one that can be *closed* soonest, not the one that is numerically first
      or looks most important. Note that this reorders only within what dependencies allow —
      a phase whose `**Depends on**:` prerequisites are unmet is not eligible regardless of cost.
- [x] Write the **Stop-at-a-closed-phase-boundary** clause: when a dispatch judges it cannot
      finish the next phase within its remaining budget, it STOPS at the current closed boundary
      and hands off, rather than opening the phase and leaving it `[PARTIAL]`. State explicitly
      that this clause is **not redundant with** "work depth-first": depth-first tells an agent
      what order to work in; only this clause tells it to *stop rather than start something it
      cannot finish*. It must not be summarized away or merged into the close-before-open clause.
- [x] Write the **Why `[PARTIAL]` is costly** rationale: a task cannot be marked `COMPLETED`
      while any phase heading is `[PARTIAL]`, so breadth-first work actively prevents completion.
      One closed phase plus a clean handoff strictly dominates four opened phases with one closed.
- [x] Write the **Scope limitation** section containing this sentence verbatim:
      `This contract governs a single dispatch's own phase-opening sequencing only: it forbids ONE AGENT from opening several phases at once; it does NOT forbid the orchestrator from dispatching independent phases to different agents in the same wave.`
      Immediately follow it by naming both potentially-conflicting rules: `plan-format.md`'s
      Dependency Analysis wave table ("Phases within the same wave can execute in parallel") and
      `context/contracts/territory.md` (cross-agent file ownership during simultaneous dispatch).
- [x] Write a **Mode applicability** section covering both observed failure shapes: standard mode
      (`agents/general-implementation-agent.md` Stage 4 "Execute File Operations Loop" — a single
      dispatch iterating all phases, no stop condition) and hard mode
      (`skills/skill-implementer-hard/SKILL.md` Stage 3b — a top-to-bottom heading scan that gives
      `PARTIAL` no priority over `NOT STARTED`). For hard mode, state the behavioral override
      plainly: **an already-open `PARTIAL` or `IN PROGRESS` phase is closed before any
      `NOT STARTED` phase is opened, regardless of heading position.** Do not modify the
      selector regex itself.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/phase-closure.md` - new file (contract text)

**Verification**:
- File exists and is non-empty.
- `grep -c "single dispatch's own phase-opening sequencing only"` returns 1 (the verbatim scoping
  sentence is present).
- `grep -i "stop"` finds the stop-at-boundary clause as its own distinct section heading, not
  only as an inline mention.
- All three required clauses (close-before-open, cheapest-closure-first, stop-at-boundary) appear
  as separate, individually-headed sections.
- `grep -nE "task [0-9]+|tasks [0-9]+" ` returns no matches (no task-number citations).
- Path check: the created file is under `agent-system/extensions/core/`, not `.claude/`.

---

### Phase 2: Author the per-item pre-edit verification gate contract [NOT STARTED]

**Goal**: Create `agent-system/extensions/core/context/contracts/pre-edit-gate.md` requiring
cheap, proportionate per-item evidence before any item from a mechanically-generated list is
applied, wired by name to the two shipped composition partners.

**Tasks**:
- [ ] Create `agent-system/extensions/core/context/contracts/pre-edit-gate.md`.
- [ ] Write the same header note as Phase 1: loaded via explicit `@`-reference in BOTH modes; the
      `context/contracts/` directory placement does not imply hard-mode-only.
- [ ] Write the **A planning-time list is a hypothesis** premise: any enumerated file list,
      candidate set, or count that reaches the implementer from a plan, a grep, or any other
      mechanical scan is a hypothesis about the codebase, never a fact about it. Name
      `plan-format.md`'s `**Scope Hypothesis:**` field explicitly and state that this contract is
      the implementation-side consumer that `plan-format.md` declares "out-of-scope for this
      document" — a phase carrying a `**Scope Hypothesis:**` line implies its items require
      per-item confirmation before any edit lands.
- [ ] Write the **Probe before edit** rule: before applying any item from such a list, gather
      cheap evidence that the item is real. Give concrete probe examples with the shape they
      take: a **reference count** (does anything still call this?), a **build probe** (does
      removing/renaming it still compile?), a **definition lookup** (is there a real
      implementation behind this name, or only the declaration the scan matched?).
- [ ] Write the **Proportionality** rule: probe cost scales with the edit's blast radius. A
      single-file comment tweak warrants a glance; deleting a symbol or renaming across a
      namespace warrants a reference count over the whole tree. Include an explicit cheapness
      ceiling so this cannot be deflected into open-ended investigation: the probe is a bounded
      check with a yes/no answer, not a research sub-task. If a probe cannot be made cheap, that
      itself is the signal to escalate to the plan, not to investigate further inline.
- [ ] Write the **Failed probe becomes a documented reasoned exclusion** rule: an item whose
      probe contradicts the hypothesis is neither silently skipped nor force-applied. It is
      recorded in the phase's `#### Reasoned Exclusions` table using the existing
      `Item | Reason | Evidence` columns from `plan-format.md` verbatim — the probe output goes
      in the `Evidence` column. When all five admission-test conditions in
      `context/standards/status-markers.md` hold, the phase closes as
      `[COMPLETED WITH EXCLUSIONS]`. State that no parallel or competing record schema may be
      invented for this purpose.
- [ ] Write the **Orthogonality** section: this gate is a third, separate axis from
      `plan-format.md`'s **Verification Tier** (`prose < local < interface < full`, which governs
      how thoroughly a *phase* is checked when it closes) and **Commit Mode**
      (`per-substep`/`atomic-batch`, which governs commit granularity). The pre-edit gate governs
      per-*item* evidence *before* an edit lands. Say explicitly that these must not be folded
      into one another, so a future reader does not treat them as the same knob.
- [ ] Write a short **Observed failure modes** section giving the concrete shapes a naive
      mechanical list produces: a dead-code scan matching a declaration whose real implementation
      exists elsewhere; a namespace-cleanup list whose edit breaks the build because live call
      sites depend on the prefix; a rename list containing a known false positive. Describe these
      as failure shapes without citing any task number.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/pre-edit-gate.md` - new file (contract text)

**Verification**:
- File exists and is non-empty.
- `grep -c "Scope Hypothesis"` returns >= 1 and `grep -c "Reasoned Exclusions"` returns >= 1
  (both composition partners wired by name).
- `grep "Item | Reason | Evidence"` finds the column set reproduced verbatim.
- `grep "COMPLETED WITH EXCLUSIONS"` finds the marker named.
- `grep -i "verification tier"` and `grep -i "commit mode"` both hit inside the Orthogonality
  section (the three-axis distinction is stated, not implied).
- `grep -nE "task [0-9]+|tasks [0-9]+"` returns no matches.
- Path check: the created file is under `agent-system/extensions/core/`, not `.claude/`.

---

### Phase 3: Wire both contracts into the four core implementer files [NOT STARTED]

**Goal**: Add explicit reference bullets for both new contracts to all four files named in the
task's Scope A, using each file's existing Context References convention.

**Tasks**:
- [ ] In `agent-system/extensions/core/agents/general-implementation-agent.md`, locate the
      `## Context References` section (anchor: the existing bullet
      `` `@.claude/context/patterns/context-discovery.md` ``) and add two bullets in the same
      `@`-prefixed style used by its siblings:
      `` - `@.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (always load) ``
      and
      `` - `@.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (always load) ``
- [ ] In `agent-system/extensions/core/agents/general-implementation-hard-agent.md`, locate the
      `## Context References` section (anchor: the existing bullets
      `` `@.claude/context/contracts/anti-analysis.md` `` and
      `` `@.claude/context/contracts/territory.md` ``) and add the same two bullets, marked
      `(MANDATORY)` to match the surrounding hard-mode contract bullets' convention.
- [ ] In `agent-system/extensions/core/skills/skill-implementer/SKILL.md`, locate the
      `## Context References` section (anchor: its `Reference (do not load eagerly):` line and
      the trailing note `Context is loaded by the delegated agent.`) and add two bullets in that
      file's `` - Path: `...` - description `` style. These are discoverability, not a load path
      — this skill does not load context itself.
- [ ] In `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`, locate the
      `## Context References` section (anchor: the existing
      `` - Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent) ``
      bullet) and add two bullets in the same `Path:` style, annotated `(loaded by agent)` to
      match.
- [ ] Do not reorganize, reorder, or reword any existing bullet in any of the four files. Add
      only.

**Timing**: 30 minutes

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly four referrer files, each with exactly one
`## Context References` section gaining exactly two new bullets (eight bullets total). Confirm at
implementation time by running `grep -c "^## Context References"` on each of the four files — each
must return exactly 1 before editing. If any file returns 0 or >1, stop and record the discrepancy
rather than guessing an insertion point.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add 2 `@`-reference bullets
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - add 2 `@`-reference bullets (MANDATORY-annotated)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` - add 2 `Path:` bullets
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` - add 2 `Path:` bullets

**Verification**:
- For each of the four files:
  `grep -c "contracts/phase-closure.md" <file>` returns >= 1 **and**
  `grep -c "contracts/pre-edit-gate.md" <file>` returns >= 1.
- Each new bullet sits inside that file's `## Context References` section (confirm by
  `grep -n "## Context References" -A 30 <file>` and reading the output, not by line arithmetic).
- `git diff --stat` shows exactly four modified files, all under `agent-system/extensions/core/`.
- No file under `.claude/` appears in `git status --short`.

---

### Phase 4: Register both contracts in index-entries.json [NOT STARTED]

**Goal**: Add `index-entries.json` entries for both new contracts with `load_when.agents` listing
both the standard and hard implementation agents — the first non-hard-exclusive `contracts/`
registrations in the system — keeping Context Gap Detection accurate.

**Tasks**:
- [ ] Read the existing `contracts/territory.md` entry in
      `agent-system/extensions/core/index-entries.json` as the structural template (fields:
      `path`, `domain`, `subdomain`, `summary`, `line_count`, `keywords`, `topics`,
      `load_when.{agents,commands,task_types}`).
- [ ] Add an entry for `contracts/phase-closure.md` with `domain: "core"`,
      `subdomain: "contracts"`, an accurate `line_count` measured from the file authored in
      Phase 1, keywords covering depth-first / phase-closure / partial / stop-at-boundary, and
      `load_when.agents: ["general-implementation-agent", "general-implementation-hard-agent"]`.
- [ ] Add an entry for `contracts/pre-edit-gate.md` with the same `domain`/`subdomain`, an
      accurate `line_count` measured from the file authored in Phase 2, keywords covering
      pre-edit / verification-gate / scope-hypothesis / reasoned-exclusions, and the same
      two-agent `load_when.agents` list.
- [ ] In each entry's `summary`, note that the contract applies in both standard and hard mode —
      this is what documents the deliberate break from the directory's hard-only precedent.
- [ ] Treat these registrations as **supplementary**: the Phase 3 `@`-reference bullets are the
      load-bearing wiring. Do not remove or weaken any Phase 3 bullet on the grounds that the
      index entry now exists.

**Timing**: 25 minutes

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts these will be the first two `contracts/*` entries in the
whole source store whose `load_when.agents` includes a non-`-hard` agent name. Confirm at
implementation time with a probe over every `index-entries.json` in `agent-system/`, filtering
`contracts/` entries and printing their `load_when.agents`; before the edit the result must show
zero non-`-hard` names. If the probe contradicts this, record the discrepancy in a
`#### Reasoned Exclusions` row and adjust the summary wording rather than asserting a false first.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - add 2 entries

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` exits 0 (valid JSON).
- `jq -r '.entries[] | select(.path=="contracts/phase-closure.md") | .load_when.agents[]'` lists
  both `general-implementation-agent` and `general-implementation-hard-agent`; same for
  `contracts/pre-edit-gate.md`.
- Each entry's `line_count` matches `wc -l` on the corresponding contract file.
- No pre-existing entry was modified: `git diff` on the file shows additions only.

---

### Phase 5: Record the placement and no-central-injection findings durably [NOT STARTED]

**Goal**: Write the two research findings that downstream propagation work depends on into a
durable in-repo location, so that work inherits them rather than re-deriving them — and so it
cannot be mistakenly closed as free.

**Tasks**:
- [ ] Add a short subsection to
      `agent-system/extensions/core/context/architecture/context-layers.md` (anchor: its existing
      "Where to store new content" decision tree) titled along the lines of
      "Contracts directory: convention vs. load path".
- [ ] Record finding (i) — **where a contract must live to be loaded by both modes**: directory
      placement is not a load mechanism in this codebase. `context/contracts/` is a naming and
      genre convention whose occupants have historically been hard-mode-only. What actually causes
      a contract to load is an explicit `@`-reference bullet in the consuming agent's
      `## Context References` section. A contract intended for both standard and hard mode may
      live in `context/contracts/` provided it is explicitly referenced from both agents, and
      should say so in its own header.
- [ ] Record finding (ii) — **no central injection point exists**, stated unambiguously and with
      its evidence: only core's standard implementation agent runs the adaptive
      `context-discovery.md` index query; no extension implementation agent and no hard-mode
      implementation agent does. `skill-base.sh`'s `context_injection` lifecycle stage runs the
      opposite direction — it lets extensions inject their domain content into a core skill's
      dispatch prompt, not core broadcast outward. No shared dispatch-prompt builder exists; each
      `SKILL.md` constructs its own dispatch prompt inline.
- [ ] Record the **consequence**: propagating any core contract to extension implementation
      agents is manual, per-file work with no shortcut. Cite the durable in-repo precedent by
      filename — `extensions/cslib/agents/cslib-implementation-hard-agent.md` hand-lists core's
      `anti-analysis.md`, `wrap-up.md`, and `territory.md` as individually copied bullets — and
      name it as the template such propagation follows.
- [ ] Cite durable anchors only. No task numbers anywhere in this file.

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/architecture/context-layers.md` - add one subsection

**Verification**:
- `grep -c "context/contracts/" agent-system/extensions/core/context/architecture/context-layers.md`
  returns >= 1 (previously 0 — the file had no contracts mention).
- The subsection names all three negative-hook findings: the adaptive query,
  `skill-base.sh`'s `context_injection` direction, and the absence of a shared dispatch-prompt
  builder.
- `grep "cslib-implementation-hard-agent"` finds the precedent cited by filename.
- `grep -nE "task [0-9]+|tasks [0-9]+"` returns no matches.
- Existing content in the file is unmodified: `git diff` shows additions only.

---

### Phase 6: Cross-cutting verification gate [NOT STARTED]

**Goal**: Run the checks that no single earlier phase can run on its own — the four-referrer
wiring sweep, the verbatim scoping-sentence check, and the source-store / task-reference hygiene
sweep across everything this task touched.

**Tasks**:
- [ ] **Referrer sweep**: for each of the four files in Phase 3, confirm both
      `contracts/phase-closure.md` and `contracts/pre-edit-gate.md` appear. All eight checks must
      pass; any miss is a Phase 3 defect to fix, not a finding to report.
- [ ] **Verbatim scoping check**: confirm the wave-table scoping sentence appears in
      `phase-closure.md` exactly as specified in Phase 1, with no paraphrase or truncation. This
      is the highest-risk single item in the task — a contract that contradicts an existing rule
      without explicit scoping will cause one of the two rules to be ignored.
- [ ] **Non-contradiction read-through**: read `phase-closure.md`'s scope section alongside
      `context/formats/plan-format.md`'s "Phases within the same wave can execute in parallel"
      and `context/contracts/territory.md`'s opening scope statement. Confirm a reader
      encountering all three would not conclude any pair conflicts.
- [ ] **Three-clause presence check**: confirm `phase-closure.md` still contains all three
      required clauses as distinct sections, with the stop-at-boundary clause intact and not
      collapsed into the close-before-open clause.
- [ ] **Source-store hygiene**: confirm `git status --short` lists no path under `.claude/`. All
      changes must be under `agent-system/extensions/core/`.
- [ ] **Task-reference hygiene**: grep every file this task created or modified for task-number
      citation patterns; all are outside `specs/**` so all must be clean.
- [ ] **JSON validity**: re-confirm `index-entries.json` parses.
- [ ] Record any item that fails a check and is deliberately not fixed in a
      `#### Reasoned Exclusions` table with its probe output in the `Evidence` column — applying
      this task's own pre-edit gate to itself.

**Timing**: 25 minutes

**Depends on**: 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts a total touched-file set of seven: two new contract
files, four referrer files, `index-entries.json`, and `context-layers.md` — which is eight, so
confirm the actual count rather than trusting this sentence. Probe with `git status --short` and
reconcile against the per-phase file lists above; an unexpected extra path (especially any under
`.claude/`) is a stop-and-report condition, not something to fold in silently.

**Files to modify**:
- None (verification only; any fix lands in the phase that owns the file)

**Verification**:
- All eight referrer greps (4 files x 2 contracts) return >= 1.
- `grep -c "single dispatch's own phase-opening sequencing only" agent-system/extensions/core/context/contracts/phase-closure.md`
  returns exactly 1.
- `git status --short | grep -c "^.*\.claude/"` returns 0.
- `grep -rnE "task [0-9]+|tasks [0-9]+" ` over the touched non-`specs/**` files returns no
  matches.
- `jq empty agent-system/extensions/core/index-entries.json` exits 0.
- Touched-file set reconciles with the per-phase file lists, with any deviation documented.

---

## Testing & Validation

- [ ] Both new contract files exist under `agent-system/extensions/core/context/contracts/` and
      are non-empty.
- [ ] `phase-closure.md` contains all three required clauses as distinct sections, including the
      stop-at-boundary clause stated as non-redundant.
- [ ] The wave-table scoping sentence is present verbatim in `phase-closure.md`.
- [ ] `pre-edit-gate.md` names `**Scope Hypothesis:**`, `#### Reasoned Exclusions`, the
      `Item | Reason | Evidence` columns, and `[COMPLETED WITH EXCLUSIONS]`.
- [ ] All four referrer files reference both contracts.
- [ ] `index-entries.json` is valid JSON with two new entries listing both implementation agents.
- [ ] `context-layers.md` records both the placement finding and the no-central-injection finding
      with the `cslib-implementation-hard-agent.md` precedent named.
- [ ] No changes under `.claude/`; no task-number citations outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/contracts/phase-closure.md` (new)
- `agent-system/extensions/core/context/contracts/pre-edit-gate.md` (new)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (modified)
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (modified)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (modified)
- `agent-system/extensions/core/index-entries.json` (modified)
- `agent-system/extensions/core/context/architecture/context-layers.md` (modified)
- `specs/925_depth_first_phase_closure_and_pre_edit_gate/summaries/01_*-summary.md` (on completion)

## Rollback/Contingency

All changes are additive text edits to a git-tracked source tree with no runtime code paths.

- **Per-phase rollback**: `git checkout <file>` on the specific file, or delete the two new
  contract files. Phases 1 and 2 create files with no dependents until Phase 3 wires them, so
  either can be discarded independently.
- **Partial-completion state**: if Phases 1-2 land but Phase 3 does not, the contracts exist but
  are unreferenced — inert, not harmful. This is a safe stopping point.
- **If the scoping sentence proves insufficient** and the depth-first rule still reads as
  contradicting the wave table, the contingency is to strengthen `phase-closure.md`'s scope
  section with a worked example rather than to weaken the depth-first rule — the rule is what
  produced the observed recovery.
- **If `index-entries.json` registration causes any downstream validator failure**, remove the two
  entries. They are supplementary; the Phase 3 `@`-reference bullets carry the actual behavior.
