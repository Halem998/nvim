# Research Report: Task #37

**Task**: 37 - Close the two residual gaps left by the territory/handoff work
**Started**: 2026-08-12
**Completed**: 2026-08-12
**Effort**: small (two targeted contract edits + one decision record + verification)
**Dependencies**: handoff-identity/loop-guard work (landed), spurious-phase-advance work (landed)
**Sources/Inputs**: codebase (grep/read across `agent-system/extensions/core/**`, `lean/**`, `cslib/**`)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both "already done" claims in the task description are confirmed exactly as stated: the hard
  engine's territory dispatch key and `dispatch-report-not-termination.md` are live and singular.
  No re-derivation needed.
- **Gap 1 (teardown in wrap-up.md) confirmed real.** `context/contracts/wrap-up.md` (194 lines)
  has zero watcher/monitor/background/teardown coverage. The obligation exists only in
  `context/patterns/dispatch-report-not-termination.md`'s "Tear Down Watchers/Monitors Before
  Reporting" section, which wrap-up.md never references and which no hard-mode agent loads at
  wrap-up time.
- **Gap 2 (base-mode decision record) confirmed real.** `skill-orchestrate/SKILL.md` has zero
  `territory` mentions; `skill-orchestrate-hard/SKILL.md` has three (frontmatter, context
  pointer, dispatch key). `territory.md`'s opening scope and Template preamble still describe
  only parallel/multi-agent dispatch, not the single-phase dispatch that is its actual consumer
  today.
- A **precedent pattern already exists** in the codebase for exactly this kind of "explicit,
  mutual, both-engines-visibly-agree" decision record: `skill-orchestrate/SKILL.md` lines 244-260
  carry a `**Decision record**:` / `**Asymmetry decision (recorded...)**:` block pattern used for
  an analogous base-vs-hard asymmetry (whether base mode gains hard mode's
  `loop-guard-staleness` detector). This is the idiom to reuse for Gap 2, not a new format.
- One small, in-scope correction identified during verification (not a rewrite): hard agent
  Stage 3.6 ("Territory Check") is confirmed live (gated correctly on `territory` presence), but
  its four steps cover ownership/blockers only — none of them ties to the STOP-and-report duty
  for foreign commits/modifications/builds that `territory.md`'s `concurrency_note` and Template
  already state. The task description anticipated this exact finding.

## Context & Scope

Task 37 was originally scoped as "wire a sound territory contract into per-phase dispatch." That
work landed as part of a separate handoff-identity/loop-guard effort (its "Defect 5"). This
research verifies the landed state cheaply (per the task's own instructions: verify, do not
redo) and characterizes precisely what remains: two contract-file gaps plus one governance
decision, all confined to `context/contracts/wrap-up.md`, `context/contracts/territory.md`, and
possibly `skills/skill-orchestrate/SKILL.md`.

## Findings

### Verification of "already done" claims (all confirmed)

1. **Territory key wired into hard-mode single-phase dispatch** — confirmed.
   `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` line 814 contains a
   `"territory"` key in the Stage 4 dispatch_context JSON with `owned_files`, `read_only_files`,
   `forbidden_files`, and a `concurrency_note` (line 818) whose text matches the task
   description's summary verbatim: it disclaims exclusive access and instructs STOP-and-report
   on foreign commits/modifications/builds, pointing at both `context/contracts/territory.md` and
   `context/patterns/dispatch-report-not-termination.md`.

2. **No global no-concurrency assertion; STOP-and-report is contractual** — confirmed.
   `context/contracts/territory.md`'s Territory Declaration Template (its final section) states
   explicitly: "This declaration asserts only what is locally checkable... It does NOT assert
   that no other agent is concurrently active," followed by the STOP-and-report instruction, and
   an "Explicit removal note" forbidding reintroduction of "you have exclusive access" language.

3. **Agent-side territory check is live, not dead code — but see correction below.**
   `general-implementation-hard-agent.md` Stage 3.6 ("Territory Check", lines 144-150) is gated
   on `If territory parameters were provided in delegation context`. Since Stage 4 of
   `skill-orchestrate-hard/SKILL.md` now always includes `territory` in its dispatch_context, the
   gate fires on that path. However, Stage 3.6's four steps (verify target files are owned; note
   missing-territory files as blockers; use read_only_files for outside reads) cover ownership
   and blockers only — **none of the four steps mentions the STOP-and-report duty for observed
   foreign work** (foreign commits, foreign uncommitted modifications, a build the agent didn't
   start) that `territory.md`'s `concurrency_note` and Template both carry. This is exactly the
   "small in-scope correction" the task description flagged as needing confirmation, and it is
   real: the STOP-and-report duty is stated at the contract/dispatch level but not echoed as an
   explicit Stage 3.6 step in the agent file that operationalizes the rest of the territory
   contract.

4. **Extension hard agents share the pattern** — confirmed. Both
   `lean/agents/lean-implementation-hard-agent.md` (line 277) and
   `cslib/agents/cslib-implementation-hard-agent.md` (line 313) reference
   `context/patterns/dispatch-report-not-termination.md`. No further extension fan-out needed.

5. **Shared root cause stated once, canonically** — confirmed. Only one file states the model:
   `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`. A full
   repo grep for `dispatch-report-not-termination` found 23 referencing files (agents, skills,
   docs, tests, index-entries.json) across core/lean/cslib, all of which point at it with a
   one-line pointer rather than restating it. `territory.md` and `wrap-up.md` are both already in
   this reference list (territory.md in its Template's STOP-and-report sentence; wrap-up.md
   already references it once, in the `dispatch_seq` field-semantics paragraph — but not in
   connection with teardown, confirming Gap 1's precision: the *pointer machinery* exists in
   wrap-up.md already, just not wired to a teardown obligation).

### Gap 1: Watcher/monitor teardown absent from wrap-up.md

`context/contracts/wrap-up.md` (194 lines) is organized into: Orchestrator Handoff JSON Schema,
Continuation Handoff Markdown, Incremental Commit Discipline, "Ordering: Handoff Write Precedes
Marker Promotion (Defect 6)", Build-Green Invariant, Domain Specialization. None of these
sections mentions watchers, monitors, background jobs, or teardown — confirmed by direct read
(not just the task description's grep claim).

The rationale and MUST already exist, canonically, in
`dispatch-report-not-termination.md`'s "Tear Down Watchers/Monitors Before Reporting" section
(lines 52-59): "every agent that arms a watcher/monitor process during its own dispatch MUST
tear it down before reporting a terminal result." wrap-up.md is the file an agent actually
consults at wrap-up time (per its own header: "STANDARD mode never loads this file... loaded
exclusively by hard-mode dispatch paths") and is the file that already enumerates ordered
obligations before terminating (see the existing "Ordering: Handoff Write Precedes Marker
Promotion" section, which is precisely this kind of sequencing rule). An agent that follows
wrap-up.md to the letter today can report cleanly with a monitor still armed, having violated
nothing stated in the file it was told to follow.

**Where it fits structurally**: the natural location is a new section parallel to "Ordering:
Handoff Write Precedes Marker Promotion (Defect 6)" — e.g. "Teardown Precedes Terminal Handoff"
— stated as an obligation discharged BEFORE the terminal `.orchestrator-handoff.json` write
(mirroring that section's own "precedes" framing), with a one-line pointer to
`context/patterns/dispatch-report-not-termination.md` for the why, not a restatement of its
argument. This keeps Gap 1's fix inside wrap-up.md's existing idiom rather than inventing a new
one.

### Gap 2: Base-mode territory decision record

Confirmed by direct grep: `skill-orchestrate/SKILL.md` (base engine) has **zero** occurrences of
`territory`; `skill-orchestrate-hard/SKILL.md` has three (frontmatter description, a context
pointer at line 90, and the dispatch key at line 814). `territory.md` itself still opens: "This
contract implements H7: Territory Contracts for Parallel Dispatch... when multiple agents are
dispatched simultaneously to work on different phases of the same plan," and its Template
section says "The orchestrator includes this in each parallel dispatch context" — both
descriptions predate/don't reflect that the contract's actual, landed consumer today is
single-phase (not parallel-phase) hard-mode dispatch.

**Base mode's actual concurrency shape** (verified directly): Stage MT-3's BATCHING RULE (line
2061) requires "ALL Agent tool calls for the current cycle's dispatch batch... issued in a SINGLE
orchestrator message," explicitly because Claude Code "processes all calls in a single message
concurrently." This is genuine concurrent multi-agent dispatch — one call per *task number* in
the batch (research_tasks / plan_tasks / implement_tasks loops, lines ~2190-2216), each given its
own `task_dir_abs` / `handoff_path_abs` derived from its own task number.

**Existing mitigation and its scope**: base mode already defers tasks with overlapping
`file_scope` and no `dependency_graph` edge, both in-batch (`collision_scope: "in_batch"`) and
cross-batch (`collision_scope: "cross_batch"`, checked against live registered sessions' unioned
`file_scope`), logging to `defer_ledger` (lines ~1880-1919). This is a real, working mitigation —
but it operates only at *admission time*, comparing `file_scope` values the orchestrator itself
declared for tasks it is *about to* dispatch. It has no mechanism at all for a task whose agent
already reported in an earlier cycle but is still live (self-armed watcher, or an
operator-initiated resume) — exactly the woken-predecessor case task 37 is about. A woken
predecessor from cycle N-1 is invisible to Stage MT-3's file_scope-collision check at cycle N: it
already passed, or was never subject to, that check for the *current* cycle's dispatch, because
the check only compares tasks being admitted this cycle against each other and against
currently-registered live sessions — not against every task that has ever reported in this
`/orchestrate` invocation.

**Base mode already carries the companion half of the shared root cause.** `skill-orchestrate/
SKILL.md` already references `dispatch-report-not-termination.md` three times (lines 221, 677,
723, 730) — but only for the Defect A discrimination problem (mtime-based staleness gate cannot
tell a woken predecessor's late handoff write from a fresh one; `dispatch_seq` is the fix). It
has never been extended to Defect 5 (territory), which is the specific asymmetry task 37 names.

**Precedent for how to record this decision**: `skill-orchestrate/SKILL.md` lines 244-260 already
contain the established idiom for exactly this shape of question — a base-vs-hard asymmetry that
is deliberately left open pending a separate decision, recorded so "both engines visibly agree":

> **Asymmetry decision (recorded, "recorded not acted on" style, mirroring the hard engine's
> record so the two visibly agree)**: whether base mode should ever gain the general 3-signal
> `loop-guard-staleness` detector hard mode has is a SEPARATE, undecided question...

This is a directly reusable template for Gap 2's deliverable: a `**Decision record**:` /
`**Asymmetry decision (recorded...)**:` block, placed in `skill-orchestrate/SKILL.md` near the
BATCHING RULE (Stage MT-3, ~line 2061) or the existing dispatch-report-not-termination pointers
(~line 677), stating explicitly whether base mode gains a territory contract and, either way,
addressing the file_scope-deferral blindness identified above by name. If the decision is "wire
it," a mirrored acknowledgment belongs in `skill-orchestrate-hard/SKILL.md` (as the existing
loop-guard-staleness asymmetry record does in reverse), satisfying the "explicit mutual
co-maintenance contract" the task description invokes. If the decision is "do not wire it (yet)",
the same block records the reason and must still name the file_scope blindness rather than
citing file_scope deferral as if it already covered the woken-predecessor case.

No prior art for a separate "decision record" document/directory exists in this codebase (no
`docs/decisions/`, no ADR convention found) — decision records live inline, in the file whose
behavior they govern, which further supports placing this in `skill-orchestrate/SKILL.md` itself
(and, if applicable, mirrored in `skill-orchestrate-hard/SKILL.md`) rather than a new file.

### Gap 3 (rescoping, item 3 of acceptance criteria): territory.md's opening and Template preamble

Independently of whether base mode gets wired, `territory.md`'s current framing is already
inaccurate to today's reality regardless of the base-mode decision's outcome: its opening
("H7: Territory Contracts for Parallel Dispatch... when multiple agents are dispatched
simultaneously") and Template preamble ("The orchestrator includes this in each parallel dispatch
context") describe only the parallel-dispatch case, but the contract's actual shipped consumer
(`skill-orchestrate-hard/SKILL.md` Stage 4) is single-phase dispatch. This is a factual-accuracy
fix independent of the Gap 2 decision and should be made regardless of what that decision
concludes — the two are related but not gated on each other.

### index-entries.json note (secondary, implementation-stage concern)

Both `territory.md` (currently `"line_count": 107`) and `wrap-up.md` (currently
`"line_count": 194`) have index-entries.json records that carry `line_count` fields. Any edit
that changes either file's line count should be followed by
`.claude/scripts/generate-context-line-counts.sh --write` (per its documented role in CLAUDE.md)
to keep those counts accurate — noted here for the implementation phase, not actioned in
research.

## Decisions

- Treat Gap 1 and Gap 2 as independent, disjoint edits (per the task's own SEQUENCING section):
  Gap 1 touches only `wrap-up.md`; Gap 2 touches `territory.md` (opening/Template — needed
  regardless of the decision's outcome) and possibly `skill-orchestrate/SKILL.md` (only if the
  decision is "wire it," or in either case for the decision-record block itself).
- The Stage 3.6 STOP-and-report correction (verification item 4) is small and disjoint from both
  gaps — it touches only `general-implementation-hard-agent.md`'s existing four-step list (add a
  fifth step or fold the duty into an existing one), not a rewrite.
- Recommend reusing the exact `**Decision record**:`/`**Asymmetry decision (recorded...)**:`
  prose idiom already established at `skill-orchestrate/SKILL.md` lines 244-260, rather than
  inventing a new decision-record format.

## Risks & Mitigations

- **Risk**: editing `territory.md`'s opening scope while leaving the Template's parallel-dispatch
  framing untouched (or vice versa) would leave the file internally inconsistent. Mitigation:
  both the opening paragraph and the Template preamble are named explicitly in acceptance
  criterion 3; treat them as one edit, not two.
- **Risk**: a Gap 2 "wire base mode" decision that only adds a territory dispatch key to base mode
  without addressing the woken-predecessor blindness would repeat the exact mistake task 37 is
  closing (an assertion of exclusivity that isn't sound). Mitigation: if wiring base mode, reuse
  the hard engine's `concurrency_note` wording (STOP-and-report, no exclusivity claim) verbatim
  rather than re-deriving new territory language.
- **Risk**: restating `dispatch-report-not-termination.md`'s argument inside wrap-up.md's new
  teardown section instead of pointing at it, violating acceptance criterion 5. Mitigation: the
  existing wrap-up.md `dispatch_seq` paragraph already demonstrates the correct one-line-pointer
  style ("See `context/patterns/dispatch-report-not-termination.md`") — mirror that exact idiom
  for the new teardown section.

## Context Extension Recommendations

None — this is a meta task and both contract files already exist with appropriate index-entries.json
coverage; only their content needs updating, not new context-file creation.

## Appendix

### Search queries / greps used

```
grep -n territory agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
grep -c territory agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
grep -n "3.6\|territory" agent-system/extensions/core/agents/general-implementation-hard-agent.md
grep -n "dispatch-report-not-termination" agent-system/extensions/lean/agents/lean-implementation-hard-agent.md agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md
grep -rln "dispatch-report-not-termination" agent-system/
grep -n "file_scope\|defer_ledger\|BATCHING RULE\|MT-3\|Deferring #" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
grep -rn "co-maintenance" agent-system/extensions/core/
grep -n "wrap-up.md\|territory.md" agent-system/extensions/core/index-entries.json
```

### Files read in full or substantial part

- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/context/contracts/territory.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 3.6 region)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines ~221-260, ~1750-2220)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (territory grep hits)
