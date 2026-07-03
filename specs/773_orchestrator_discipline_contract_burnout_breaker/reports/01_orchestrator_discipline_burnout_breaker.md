# Research Report: Task #773

**Task**: 773 - Add orchestrator-role discipline contract and burnout circuit-breaker
**Started**: 2026-07-03T16:15:33Z
**Completed**: 2026-07-03T16:45:00Z
**Effort**: 3-6 hours
**Dependencies**: 772 (done), 779 (done) — both directly shape this task's wiring point
**Sources/Inputs**: Codebase (`.claude/skills/skill-orchestrate-hard/SKILL.md`, `.claude/context/contracts/*.md`, `.claude/context/patterns/context-exhaustion-detection.md`, `.claude/context/index.json`), task 779's plan/report (dual-copy precedent)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `skill-orchestrate-hard/SKILL.md` is currently governed only by *content* references
  (Context References list) plus one *enforced* injection point: `build_hard_mode_prompt_context()`
  bakes `anti-analysis.md` (H2), a wrap-up reminder, a settled-design preamble reminder, and (as of
  779) a recovery-ladder reminder into the **implement-dispatch prompt only**. Nothing analogous
  exists for the orchestrator's own conversational turns between dispatches — the gap the task
  description identifies as the burnout root cause.
- 772 restructured the file into a **pure dispatcher** (no `Edit`, forbidden-reads list, forbidden
  Bash list) and explicitly reserved the **Stage 1b → Stage 3b region** (Stage 1b "Resolve
  Hard-Mode Agent Routing" through Stage 3b "Update loop guard", now at lines 115–239) as the
  landing zone for 773's discipline/circuit-breaker wiring. The natural insertion point is a new
  sub-stage placed **after Stage 3b and before Stage 4 (State Handlers)** — i.e. the true top of
  each `while` loop iteration, after `current_status` is known but before any dispatch decision is
  made.
- `contracts/convergence.md` is the exact structural precedent for a contract that governs the
  **orchestrator role itself** (not an implement-dispatch prompt): it has an empty
  `load_when` (`agents: []`, `task_types: []`, `commands: []`) in `index.json` because it is
  referenced directly by `skill-orchestrate-hard`'s own Context References section rather than
  auto-loaded via the agent-context discovery mechanism. `contracts/orchestrator-discipline.md`
  should follow the same empty-`load_when` registration pattern.
- `context-exhaustion-detection.md` (present in both `.claude/context/patterns/` and
  `.claude/extensions/core/context/patterns/`) is written for tool-instrumented agents (Read/Edit
  call counts, progress-file/handoff-artifact protocol consumed by
  `subagent-continuation-loop.md`). The orchestrator is a *pure dispatcher* whose own burnout
  happens in the gaps **between** `Agent` tool calls — extended inline reasoning, re-reads, and
  strategy reversal that never show up as a completed dispatch cycle. The burnout circuit-breaker
  must therefore be a **self-monitored textual checklist** adapted from
  context-exhaustion-detection.md's three signal categories (tool-call volume, re-read detection,
  pre-operation risk), reframed around the orchestrator's own behavior, not a literal port of the
  agent-side mechanism (there is no successor-agent continuation loop for the orchestrator to
  hand off into — see Scoping Decision below).
- **Dual deployed/source copy status** (confirmed empirically, matches 779's finding): `contracts/*.md`
  files and `index.json` are **single-copy** — they exist only under
  `.claude/context/contracts/` and `.claude/context/index.json` respectively, with **no mirror**
  under `.claude/extensions/core/context/` (confirmed: `contracts` is absent from
  `.claude/extensions/core/manifest.json`'s `provides.context` array, and no
  `.claude/extensions/core/context/index.json` exists at all). `SKILL.md`, by contrast, **is**
  dual-copied byte-identically at `.claude/skills/skill-orchestrate-hard/SKILL.md` and
  `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (confirmed via `diff`, currently
  empty) — every SKILL.md edit in this task must be applied to **both** paths atomically.

## Context & Scope

Scope is hard-mode only, per the task description: only `skill-orchestrate-hard` and its
contracts/context need to change. `skill-orchestrate` (base, non-hard) is out of scope — it has no
H-technique contract slots at all today and this task does not add any.

Two sibling tasks landed immediately before this research and directly shape the target file:

- **Task 772** (done, commit `483da526c`): converted `skill-orchestrate-hard` into a pure
  dispatcher. Added the "Tool Constraints (Pure Dispatcher)" section (lines 24–62, wrapped in
  `<!-- BEGIN/END 772 pure-dispatcher tool constraints -->` markers, explicitly marked
  "standalone block; 773 must compose around this, not overwrite it"), disabled parallel-wave
  H7 dispatch, added skeleton-aware phase selection (Item 5A) and a Stage 5 postflight gate
  (Item 5B). Both blocks are wrapped in `<!-- BEGIN/END 772 ... -->` HTML comments.
- **Task 779** (done, commit `c66f5e9cc`): added a 5th "Recovery Discipline" line to the
  `build_hard_mode_prompt_context()` CONTRACT SLOTS block (now 5 slots, lines 386–397) and created
  `contracts/recovery.md`. This confirmed and documented the single-copy-contracts /
  dual-copy-SKILL.md split that this task must also follow.

Both tasks' outputs were re-read fresh in full (not from memory) before writing this report, per
the task's explicit instruction.

## Findings

### Codebase Patterns

**Current file structure of `.claude/skills/skill-orchestrate-hard/SKILL.md`** (696 lines total,
read in full):

| Region | Lines | Purpose |
|---|---|---|
| Frontmatter | 1–5 | `allowed-tools: Agent, Bash, Read` (no `Edit` — 772) |
| Intro + H-technique bullets | 7–22 | Prose description of H1/H4/H5/H6/H7 |
| Tool Constraints (Pure Dispatcher) | 24–62 | 772's reserved standalone block — read/bash allowlists |
| Context References | 64–72 | `.md` doc list: convergence, territory, anti-analysis, wrap-up + 2 architecture docs — **no `recovery.md` entry despite 779 creating it**, and no orchestrator-discipline.md yet |
| Stage 0: Multi-Task Mode Detection | 78–89 | parses `multi_task_mode`, `effort_flag` |
| Stage 1: Input Validation | 93–111 | task lookup in state.json |
| **Stage 1b: Resolve Hard-Mode Agent Routing** | 115–162 | sets `$RESEARCH_AGENT`/`$IMPLEMENT_AGENT`/`$PLANNER_AGENT` — **reserved region start** |
| **Stage 2: Preflight — Loop Guard and Churn State** | 166–209 | creates `loop_guard_file`, `churn_file` |
| **Stage 3: State Machine Loop** (open) | 216–220 | `while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do` |
| **3a. Read current task status** | 224–230 | reads `current_status` from state.json |
| **3b. Update loop guard** | 232–239 | writes `current_state`/`cycle_count` to loop_guard_file — **reserved region end** |
| Stage 4: State Handlers | 243–457 | per-status dispatch logic (`not_started`, `researched` w/ H4 gate, `planned`/`implementing` w/ H1 per-phase dispatch, `partial`, `pr_ready`, `blocked`, `completed`) |
| `build_hard_mode_prompt_context()` | 385–398 | the 5 CONTRACT SLOTS injected into **implement dispatch prompts only** |
| Stage 4b: Churn Detection (H6) | 461–508 | post-dispatch churn signature check, 3-strikes → divergence audit |
| Stage 5: Handoff Reading | 512–612 | reads `.orchestrator-handoff.json`, postflight status update |
| Stage 6: Blocker Escalation | 616–648 | escalation ladder (research retry → AskUserQuestion) |
| Stage 7: Terminal Conditions | 652–661 | MAX_CYCLES exit |
| Stage 8: Cleanup | 666–673 | remove loop_guard/churn files on success |
| Key Differences table | 684–696 | summary vs base skill |

**772's exact reservation language** (from the task prompt, corroborated by the file's own
`<!-- BEGIN 772 pure-dispatcher tool constraints (standalone block; 773 must compose around this,
not overwrite it) -->` comment at line 26): the Stage 1b→3b top-of-loop region is where 773 is
expected to land. Concretely, the best insertion points are:

1. **A new "Stage 1c: Orchestrator Discipline Preamble"** immediately after Stage 1b (after line
   162, before Stage 2 begins at line 166) — a **once-per-invocation** statement, not a per-cycle
   one. This is the orchestrator's own analog of anti-analysis.md's "Settled-Design Preamble
   Protocol": at the start of the run, the orchestrator states (to itself, in its own transcript,
   not to a sub-agent) that it is bound by `orchestrator-discipline.md` for the duration of this
   session.
2. **A new "Stage 3c: Burnout Circuit-Breaker Gate"** placed immediately after Stage 3b (after
   line 239) and before Stage 4's state handlers begin (line 243) — this runs **every loop
   iteration**, after `current_status` is known (3a) and the loop guard is persisted (3b), but
   strictly before any dispatch decision is made in Stage 4. This is the true "top of the
   state-machine loop" enforcement point the task asks for: it gates entry into Stage 4 exactly
   the way `anti-analysis.md`'s read-budget gate is meant to gate entry into further reading for
   an implement dispatch.

This split (once-per-invocation preamble + every-cycle gate) mirrors the existing two-tier
pattern already in the file: `build_hard_mode_prompt_context()`'s slot 4 ("Settled Design
Preamble") is stated once per *dispatch*, while H6 churn detection (Stage 4b) runs once per
*cycle*. Task 772's reservation covers exactly the two spots needed for both tiers.

**`Context References` list wiring** (lines 64–72): add two lines, one for the new contract and
(as a corollary fix, not strictly in scope but trivially co-located) the missing `recovery.md`
entry that 779 created but never added to this list:

```
- `.claude/context/contracts/orchestrator-discipline.md` - Orchestrator-role discipline contract, governs the state-machine loop itself (not implement dispatches)
```

**How `anti-analysis.md` is "injected" today, for comparison**: it is never literally concatenated
into a prompt. `build_hard_mode_prompt_context()` (lines 385–398) emits a short **reference +
directive** line: `"Anti-Analysis Rules: Read .claude/context/contracts/anti-analysis.md. First
file edit within 20% of tool calls."` — i.e. the dispatched agent is told to read the file itself
and given one concrete, checkable rule inline. The analogous mechanism for
`orchestrator-discipline.md` is a directive line embedded directly in the new Stage 1c/3c prose
(the orchestrator reads its own SKILL.md as its "prompt", so the contract's substance can be
either referenced-and-read or stated inline — inlining the enforceable checklist directly in
Stage 3c, with a `Read .claude/context/contracts/orchestrator-discipline.md` pointer in Stage 1c
and the Context References list, mirrors the two-part anti-analysis.md pattern most closely).

### Contract Precedents (structure/tone model)

`anti-analysis.md` (102 lines) structure, used as the model:
1. Title + 1-paragraph provenance/rationale (H2, BimodalLogic task-273 baseline)
2. **Read Budget** — quantified threshold + enforcement sentence
3. **Forbidden Conclusions** — numbered list of unacceptable dispatch outputs
4. **Defect Bar** — ALL-of-N test for when a claim is legitimate vs analysis
5. **Sub-Sorry Policy** / **Strategic sorries** — domain-specific escape valve with a 5-condition
   test
6. **Settled-Design Preamble Protocol** — what must be restated at dispatch start
7. **Domain Specialization** — pointer to extension overrides

`convergence.md` (74 lines) is the closer structural precedent because it *also* governs the
orchestrator directly (not a sub-agent dispatch):
1. Title + provenance (H6, governs "the orchestrator's loop guard")
2. **Progress Criterion Declaration** — what the orchestrator must state before each dispatch
3. **Churn Signatures** — numbered list of patterns indicating non-progress
4. **Three-Strikes Rule** — mechanical escalation trigger
5. **User-Authorization Requirement** — when AskUserQuestion is mandatory
6. **Escalation Ladder** — the ordered list also reproduced in SKILL.md Stage 6

`recovery.md` (83 lines) adds: an explicit "why this file exists" motivating-failure paragraph, a
"`--hard`-only" scope-disambiguation sentence up top, and a **Recovery Ladder** with named rungs
(a/b/c) — useful precedent for phrasing the orchestrator-discipline "when blocked, only two
responses are allowed" ladder as a small numbered ladder rather than prose.

### Proposed `orchestrator-discipline.md` Contract Structure

Modeled on the above three files, sized ~90–110 lines:

1. **Title + provenance**: "Orchestrator Discipline Contract (H-orch / burnout breaker)" — states
   it exists because H2 (anti-analysis.md) is injected only into IMPLEMENT dispatches via
   `build_hard_mode_prompt_context`, leaving the orchestrator ROLE itself ungoverned; cites the
   task-773 motivating incident (circular reconsideration, "before I concede... ONE more time",
   BLOCKED status reached via an unsound inline conclusion later caught by a standard-mode audit).
2. **Prohibited Actions** (the four literal items from the task description, each with one
   sentence of rationale tying back to 772's Tool Constraints section so the two documents don't
   drift):
   - No inline design/proof analysis (no reasoning about *whether* an approach/proof/design is
     correct — that is implementation-agent work)
   - No reading implementation source (already a hard tool-constraint in 772's "Forbidden Reads";
     this contract states the *behavioral* rule that backs that *mechanical* one)
   - No running builds (already a hard tool-constraint in 772's "Forbidden Bash Operations"; same
     relationship)
   - No strategy reconsideration mid-cycle (new: no re-opening a phase/target decision, or an
     escalation-ladder position, without a fresh dispatch producing the reconsideration)
3. **The Only Two Allowed Responses When a Phase Cannot Complete In a Bounded Dispatch**: a short
   ladder, phrased like `recovery.md`'s rungs:
   - (a) Dispatch a fresh research/audit agent (existing `$RESEARCH_AGENT`, `focus_prompt`
     describing exactly what's unresolved) — this is what Stage 4b/H5 divergence audit and Stage
     6 blocker escalation step 2 already do; this contract names the underlying rule they both
     implement.
   - (b) Escalate via the blocker ladder (Stage 6) — AskUserQuestion, then BLOCKED-with-other-
     phases-continuing.
   - Explicitly: "Absorbing the work inline — reasoning through the design/proof yourself,
     editing files yourself even conceptually, or re-running the failed check yourself to
     'verify' before dispatching — is not a third option. It is the anti-pattern this contract
     exists to name and forbid."
4. **Burnout Circuit-Breaker Signals** (see next section) — adapted from
   context-exhaustion-detection.md's three signal categories, reframed for orchestrator self-
   monitoring rather than tool-call-count telemetry.
5. **Forced-Handoff / Forced-Dispatch Mechanism** — what to do the moment a signal fires: stop
   the current line of reasoning immediately (mid-sentence if necessary) and take response (a) or
   (b) above. No third response.
6. **Domain Specialization / Scope note**: "`--hard`-only... this contract governs
   `skill-orchestrate-hard`'s state-machine loop specifically; `skill-orchestrate` (base) has no
   contract-slot mechanism today and is out of scope."

### Burnout Circuit-Breaker: Detection Signals + Forced-Handoff Mechanism

The three signals named in the task description map directly onto
`context-exhaustion-detection.md`'s existing categories, but the *subject* changes from a
tool-instrumented sub-agent to the orchestrator's own conversational behavior:

| Task's signal | context-exhaustion-detection.md precedent | Orchestrator-specific reframing |
|---|---|---|
| Repeated re-reads of the same file | "Re-Read Detection" (§2): "finding yourself re-reading files you already read earlier in the session ... strong signal of context pressure" | Since 772's Read allowlist restricts the orchestrator to 4 categories (state.json, handoff/loop-guard/churn files, plans/reports, contracts/architecture docs), a legitimate orchestrator rarely needs to re-read the *same* plan/report file twice in one cycle. Self-check: "Have I Read the same path twice without an intervening `Agent` dispatch?" |
| Multiple consecutive inline-reasoning turns with no Agent dispatch | "Tool Call Volume" (§1) + "Pre-Operation Risk Assessment" (§3), reframed: the orchestrator's unit of work is an `Agent` dispatch, not a file edit, so the threshold is turns-of-prose-without-a-dispatch, not tool-calls-without-an-edit | Self-check: "Have I produced 2+ conversational turns analyzing what to do next, without an intervening `Agent` tool call?" — this is the literal signature from the task's motivating incident (circular reconsideration of `renameNF_eval_dup`). |
| Mid-analysis strategy reversal | Not directly present in context-exhaustion-detection.md (that document is about context *pressure*, not decision *thrashing*) — closer precedent is `convergence.md`'s "Architecture re-opens" churn signature (§ Churn Signatures item 5): "Agent re-opens a settled architectural decision without presenting a new concrete counterexample" | Self-check, phrased identically to convergence.md's defect bar for symmetry: "Am I about to reverse a phase/target/escalation decision made earlier in this session without a fresh dispatch (research/audit agent) having produced a new concrete finding?" If yes: that reversal itself is the burnout signal — stop and dispatch an audit instead of deciding it inline. |

**Forced-handoff mechanism** (Stage 3c, executes at loop-top, every cycle): unlike the
agent-side pattern (write progress file → write handoff artifact → return `partial` with
`handoff_path`), the orchestrator has **no successor to hand off to via a markdown handoff
artifact** — it does not get re-invoked by reading its own prior handoff the way an implementation
agent's continuation loop does (`subagent-continuation-loop.md` has no orchestrator-side
consumer). So "forced handoff" for the orchestrator role must resolve to one of its two already-
existing dispatch mechanisms rather than a new artifact type:

- If any signal fires and the orchestrator was about to continue reasoning about *what a phase
  should do*: force response (a) — dispatch `$RESEARCH_AGENT` with `focus_prompt` set to a literal
  restatement of the exact question the orchestrator was stuck on (this reuses the existing H5
  divergence-audit dispatch shape from Stage 4b, just triggered by a different signal than churn
  count).
- If any signal fires while the orchestrator is deciding whether to keep escalating vs. accept a
  blocker: force response (b) — jump directly to Stage 6 (skip any further inline deliberation).
- Either branch **increments a burnout-signal counter** so repeated triggers within one task are
  visible in logs/handoff, but — matching 772's pure-dispatcher philosophy and the "no new
  mechanism beyond ordinary work" spirit of `recovery.md`'s rung (a) — this does **not** require a
  new persisted state file. It can piggyback on the existing `loop_guard_file` (add one field,
  e.g. `burnout_signals_this_session`, updated in the same 3b `jq` write that already touches that
  file) rather than introducing a fourth JSON sidecar (loop_guard/handoff/churn already exist;
  minimize surface area).

### External Resources

Not applicable — this is a pure meta/agent-system task with no external library/API surface.
No web research was needed or performed; all findings are from the local codebase.

### Recommendations

1. Create `.claude/context/contracts/orchestrator-discipline.md` (single-copy, no core mirror,
   per the confirmed contracts/-directory pattern) using the 6-section structure above.
2. Register it in `.claude/context/index.json`'s contracts entries with `load_when: {task_types:
   [], agents: [], commands: []}` (empty, matching `convergence.md`'s registration — it is
   orchestrator-loop-referenced, not agent-context-loaded) and `subdomain: "contracts"`,
   `domain: "core"`.
3. Edit `.claude/skills/skill-orchestrate-hard/SKILL.md` **and** its byte-identical mirror
   `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (confirmed identical via
   `diff`, must stay so):
   - Add `orchestrator-discipline.md` to the Context References list (lines 64–72), and while
     there, add the currently-missing `recovery.md` entry (779 created the file and registered it
     in index.json but never added it to this skill's own Context References prose list — a
     latent gap worth closing in the same edit pass since it's the same list).
   - Insert **Stage 1c: Orchestrator Discipline Preamble** after Stage 1b (after line 162), stated
     once per invocation.
   - Insert **Stage 3c: Burnout Circuit-Breaker Gate** after Stage 3b (after line 239), run every
     loop iteration, before Stage 4's state handlers.
   - Optionally extend the `loop_guard_file` JSON shape (Stage 2, lines 183–195) with a
     `burnout_signals_this_session` counter field, initialized to 0, incremented by Stage 3c.
4. Do not touch `skill-orchestrate` (base) or any implement-dispatch contract slot — this task is
   additive to the orchestrator's own loop only, per the "Scope: hard-mode only" instruction.

## Decisions

- **Wiring mechanism**: reference-plus-inline-directive at two loop-top sub-stages (Stage 1c
  once-per-invocation preamble, Stage 3c every-cycle gate), not a `build_hard_mode_prompt_context`-
  style contract slot — because contract slots are, by construction, injected into *sub-agent*
  dispatch prompts, and this contract governs the orchestrator's own turns, which have no prompt
  string to inject into. This directly answers the task's "determine the right mechanism" ask.
- **State persistence**: extend the existing `loop_guard_file` rather than create a new
  `.orchestrator-burnout-state.json` sidecar — minimizes new file surface, consistent with 772's
  pure-dispatcher minimalism and matching how churn state already has its own dedicated file only
  because H6 needs *per-target* counters (a burnout counter needs only one scalar).
- **No new handoff-artifact type**: the agent-side context-exhaustion-detection.md handoff
  protocol (progress file + markdown handoff artifact + `partial`/`handoff_path` return) is not
  reused verbatim, because the orchestrator has no successor-loop consumer for such an artifact.
  Forced response instead reuses the orchestrator's two existing dispatch mechanisms (fresh
  audit dispatch via Stage 4b's shape; Stage 6 escalation).
- **Contract file registration**: single-copy under `.claude/context/contracts/`, `index.json`
  entry with empty `load_when`, following `convergence.md`'s precedent exactly (both are
  orchestrator-loop contracts, not implementation-agent contracts).

## Risks & Mitigations

- **Risk**: Stage 3c's self-check is textual/self-monitored (the orchestrator is a Claude session
  interpreting SKILL.md prose, not a script with instrumentation), so it can be silently skipped
  the same way the original burnout happened. **Mitigation**: phrase Stage 3c as a mandatory gate
  with the same enforcement-sentence pattern anti-analysis.md uses ("If you have made 15+ tool
  calls with no Write or Edit, you are in violation. Write something immediately.") — i.e. state
  the violation condition and the forced action in the same imperative sentence, not as an
  optional guideline.
- **Risk**: forgetting the dual-copy SKILL.md edit (deployed + core mirror) reintroduces drift,
  exactly the risk 779's plan flagged explicitly ("Editing only one of a dual deployed/core pair
  reintroduces drift"). **Mitigation**: plan phase should list both paths as one atomic edit unit
  and verify with `diff -q` at the end, matching 779's Phase 6 pattern.
- **Risk**: over-mechanizing the burnout breaker (e.g., trying to literally count "conversational
  turns without a tool call" via a script) is not achievable — the orchestrator has no hook into
  its own turn-taking. **Mitigation**: accept that this is a self-monitored behavioral contract
  like H2, not a hard technical gate; the report above deliberately scopes Stage 3c as an
  imperative self-check, not a jq-computed threshold, except for the one piece that genuinely is
  mechanizable (a `loop_guard_file` counter of how many times the gate has fired).

## Context Extension Recommendations

- **Topic**: orchestrator-role-specific burnout/discipline patterns
- **Gap**: `context-exhaustion-detection.md` documents agent-side (tool-instrumented,
  successor-loop-consuming) context exhaustion only; there is no companion document for
  orchestrator-role self-monitoring where the "successor" is the orchestrator's own next loop
  iteration rather than a freshly-spawned agent.
- **Recommendation**: the new `contracts/orchestrator-discipline.md` created by this task's
  implementation phase effectively fills this gap for the hard-mode orchestrator; a future task
  could consider whether `skill-orchestrate` (base) needs an equivalent, lighter-weight version,
  but that is out of this task's scope.

## Appendix

- Files read in full: `.claude/skills/skill-orchestrate-hard/SKILL.md` (696 lines),
  `.claude/context/contracts/anti-analysis.md` (102 lines), `.claude/context/contracts/
  convergence.md` (74 lines), `.claude/context/contracts/recovery.md` (83 lines),
  `.claude/context/patterns/context-exhaustion-detection.md` (212 lines).
- Commands used: `diff` (SKILL.md dual-copy check, contracts dual-copy check — both confirmed via
  direct diff, not assumption), `find`/`grep` (contracts directory presence in
  `.claude/extensions/core/`), `python3 -c` (manifest.json `provides.context` array inspection,
  index.json entry inspection for `anti-analysis.md`/`convergence.md`/`territory.md`/`wrap-up.md`/
  `recovery.md`), `git log --oneline` (confirming 772/779 commit history).
- Task 779 artifacts consulted for the dual-copy precedent: `specs/779_hardmode_fix_forward_
  recovery_contract/plans/01_recovery-contract-fix-forward.md`,
  `specs/779_hardmode_fix_forward_recovery_contract/reports/01_fix-forward-recovery-contract.md`.
