# Research Report: Task #895

**Task**: 895 - separate_infra_failure_from_orchestrate_work_cycles
**Started**: 2026-07-25
**Completed**: 2026-07-25
**Effort**: medium (2 file edits + 1 new/extended shared pattern doc)
**Dependencies**: task 891 (file-overlap serializer only, not a logical prerequisite)
**Sources/Inputs**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (source store, re-read in full)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (source store, re-read in full)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/context/patterns/early-metadata-pattern.md`
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md`
- `agent-system/extensions/core/rules/error-handling.md`
- `agent-system/extensions/core/context/contracts/orchestrator-discipline.md`
- `agent-system/extensions/core/docs/fork-patterns.md`
**Artifacts**:
- This report: `specs/895_separate_infra_failure_from_orchestrate_work_cycles/reports/01_infra-failure-vs-work-cycle.md`
**Standards**: report-format.md, subagent-return.md, SOURCE-STORE RULE (all edits target `agent-system/extensions/core/**`, never `.claude/**`)

## Executive Summary

- **All line numbers in the task description are stale.** A phase-completion gate landed in
  `skill-orchestrate/SKILL.md`'s Stage 5 `implemented)` arm and Stage MT-4 before this research
  ran. Re-derived anchors are given below and must be used for planning, not the description's
  numbers.
- **`burnout_signals_this_session` (hard-mode only) is the correct shape to imitate**: a scalar
  counter declared in the loop-guard init block (Stage 2), read on resume, persisted across
  invocations in `.orchestrator-loop-guard` (not reset per-invocation despite the "_this_session"
  name), incremented via the same read-modify-tmp-mv `jq` pattern already used for `cycle_count`,
  with **no explicit cap of its own** — it feeds a *forced dispatch*, not an exit. The new
  infra-failure counter should copy this declaration/persistence/increment shape but, unlike
  `burnout_signals_this_session`, needs an explicit cap (see below), because its failure mode is
  "spin forever," not "reason inline forever."
- **There is no clean, single programmatic signal for "the subagent never ran."** The one
  unambiguous signal — the Agent tool invocation itself returning a transport/API-layer error
  rather than any subagent-authored output — is visible only to the orchestrator *as the LLM
  issuing the tool call*, not to bash running after the fact. Stage 5's bash block executes only
  after the Agent tool call has already returned, so it cannot itself distinguish "tool call
  errored" from "tool call succeeded but the subagent produced a bad transcript." The recommended
  design therefore requires an explicit **narrated LLM-judgment step** (in the same style as
  Stage 5a/Stage 6's existing narrated `Agent tool: ...` blocks) that sets a flag immediately
  after each dispatch, corroborated by one **mechanical, bash-checkable fact**: whether
  `.return-meta.json` in the task directory was written/touched during this cycle's dispatch
  window (the early-metadata pattern already write this file at Stage 0 of every agent, "before
  any substantive work" — see `early-metadata-pattern.md`). Both conditions must hold to classify
  a missing-handoff cycle as infra failure; either one alone is not proof and defaults to
  charging a genuine cycle. This directly follows the task's own residual-risk instruction: get
  it wrong in the permissive direction and MAX_CYCLES becomes no cap.
- **Recommended cap: a small, flat `MAX_INFRA_FAILURES=3`, identical in both variants** (not
  scaled with `MAX_CYCLES` the way base/hard differ 5 vs 13). Infra tolerance is about network
  flakiness, which is orthogonal to phase count; a flat, low cap mirrors this codebase's existing
  small-cap precedents (`MAX_BLOCKER_ESCALATIONS=2`, `MAX_DRIFT_INSPECTIONS=1`) and bounds
  worst-case wall-clock retries on a persistent outage without silently defeating the cycle cap.
- **Edit sites**: one shared discrimination-rule doc (new or folded into an existing pattern
  file) plus five to six edit sites in `skill-orchestrate/SKILL.md` (Stage 2 init, every Stage 4
  dispatch site, Stage 5's missing-handoff branch, Stage MT-1's `mt_state_file` schema, Stage
  MT-4 step 1) and a parallel set in `skill-orchestrate-hard/SKILL.md` (Stage 2 init alongside
  `burnout_signals_this_session`, Stage 4's per-phase dispatch, Stage 5's missing-handoff branch,
  and multi-task mode which the hard variant reuses unmodified from base per its own "Multi-Task
  Mode" section).

## Context & Scope

Task 895 asks for a mechanical rule distinguishing an Agent-tool-layer transport/API failure
(subagent never ran, or ran and produced literally nothing) from a genuine dispatch that ran but
left no orchestrator handoff (bad/missing handoff — a real work cycle that must still be
charged). The observed incident: a phase-7 implementation dispatch died on a transient network
error (`ENOTFOUND`); Stage 5's current "missing handoff" branch unconditionally increments
`cycle_count`, so the outage consumed one of `MAX_CYCLES=5` cycles even though (per the task
description) it "did ZERO work and advanced ZERO state." The description also frames the phase-7
death as "mid-edit" — this apparent tension (zero work vs. mid-edit) is addressed directly below,
because it is exactly the ambiguous case a permissive rule would get wrong.

This report covers both `skill-orchestrate/SKILL.md` (base) and `skill-orchestrate-hard/SKILL.md`
(hard). Per the SOURCE-STORE RULE, all cited paths are under `agent-system/extensions/core/`; the
deployed `.claude/` tree is disposable and regenerated from it, and is never a valid edit target.

## Findings

### Re-derived line anchors (current source-store state)

**`skill-orchestrate/SKILL.md`** (870 lines total; changed since the task description was
written — a phase-completion gate was added to Stage 5's `implemented)` case and to Stage MT-4):

| Anchor | Line | Content |
|---|---|---|
| `MAX_CYCLES=5` | 105 | Stage 2, loop guard init |
| Loop-guard fresh-start `jq -n` blob | 121-132 | Stage 2 |
| `MAX_BLOCKER_ESCALATIONS=2` | 144 | Stage 2 |
| `while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do` | 177 | Stage 3, loop condition |
| Dispatch site: `not_started` research | 220-228 | Stage 4 |
| Dispatch site: `researched` → plan | 253-261 | Stage 4 |
| Dispatch site: `planned`/`implementing` → implement | 278-286 | Stage 4 |
| Dispatch site: `partial` continuation → implement | 312-318 | Stage 4 |
| Stage 5 header / missing-handoff check | 369-378 | `if [ ! -f "$handoff_file" ]; then ... # Increment cycle and continue` |
| Stage 5 `implemented)` phase-completion gate (new since description was written) | 410-426 | conditionally skips `skill_postflight_update`, does NOT skip `cycle_count` increment |
| `# Increment cycle_count` / `cycle_count=$((cycle_count + 1))` | 461-462 | End of Stage 5, unconditional |
| Stage 6 header, `MAX_BLOCKER_ESCALATIONS=2` cap check | 504-511 | |
| Stage 6 Step 5 re-dispatch implement | 541-547 | |
| Stage MT-1 `mt_state_file` schema | 650 | field list, no infra-failure field |
| Stage MT-4 step 1, missing-handoff branch | 787-788 | `Read task_dir/.orchestrator-handoff.json. If missing: mark task in failed_tasks, skip.` |

**`skill-orchestrate-hard/SKILL.md`** (800 lines total):

| Anchor | Line | Content |
|---|---|---|
| `MAX_CYCLES=13` | 192 | Stage 2 |
| `burnout_signals_this_session` resume-read | 200-202 | Stage 2 |
| Loop-guard fresh-start `jq -n` blob incl. `"burnout_signals_this_session": 0` | 210-223 | Stage 2 |
| Lost-race resume-read (both counters) | 226-229 | Stage 2 |
| `MAX_BLOCKER_ESCALATIONS=2` | 248 | Stage 2 |
| `while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do` | 260 | Stage 3 |
| Stage 3c burnout circuit-breaker gate, increment site | 284-318 | narrated + `jq` tmp-mv write, no cap — feeds forced dispatch/escalation |
| Dispatch site: `not_started` research | 324-340 | Stage 4 |
| Dispatch site: `researched` (H4 adversarial gate wraps plan dispatch) | 346-391 | Stage 4 |
| Dispatch site: `planned`/`implementing` per-phase (H1) | 397-480 | Stage 4, single dispatch inside `if [ -n "$next_phase" ]` |
| Stage 4b churn detection re-dispatch (audit) | 566-613 | separate H5/H6 mechanism, own counters (`total_churn`, `target_churn`) — out of scope, does not touch `cycle_count` directly except via the normal Stage 5 path after it |
| Stage 5 header / missing-handoff check | 619-630 | same text as base: `if [ ! -f "$handoff_file" ]; then ... # Increment cycle and continue` |
| Stage 5 `implemented)` phase gate | 669-679 | pre-existing in hard mode (772 Item 5B), same shape as base's newer gate |
| `# Increment cycle_count` | 714-715 | unconditional |
| Stage 6 escalation dispatch | 735-753 | |
| Multi-Task Mode section | 782-786 | "Same as base ... Hard-mode applies to each individual task in the wave" — hard mode does **not** duplicate MT-1..MT-5; it reuses base's, so the MT-4 fix in base automatically covers hard-mode multi-task runs |

**Confirmation the description's `SKILL.md:773` anchor is stale/ambiguous**: no line 773 in the
current base file corresponds to "increment cycle and continue" (that text is at line 378); line
773 in the *current* file falls inside Stage MT-4's dispatch-batching narrative (between the
task-lock acquire block and the per-group dispatch loops), not the missing-handoff branch, which
is now at line 788. The description conflated two distinct manifestations of the same defect
class — single-task Stage 5 (increments `cycle_count`, retries) and multi-task Stage MT-4 (marks
`failed_tasks` outright, **no retry at all** — a strictly worse outcome than the single-task
path). Both must be fixed; see "Edit Sites" below.

### The `burnout_signals_this_session` precedent, characterized precisely

Per the task's instruction to read this counter's exact shape before designing the new one:

1. **Declaration**: initialized to `0` inside the Stage 2 fresh-start `jq -n` payload (line 220,
   `"burnout_signals_this_session": 0`), alongside `cycle_count`. Not a separate file.
2. **Persistence**: lives in `.orchestrator-loop-guard` (same file as `cycle_count`), so it
   survives across `/orchestrate --hard` re-invocations of the same task — it is **not** reset
   each conversational turn or each invocation despite its name; only deleted when the loop guard
   itself is deleted (Stage 8, success only). This is a naming quirk worth preserving-by-analogy
   but not literally copying: the new infra counter should use a name that does not overclaim
   per-session scope, e.g. `infra_failures` (see recommendation below).
3. **Read-on-resume**: both the normal resume branch (line 200-202) and the lost-init-race branch
   (line 226-229) read it back from the loop guard — the lost-race branch was itself a past bug
   fix (comment at line 208-209 notes it must read *both* counters, not just `cycle_count`), a
   direct precedent for making sure a second counter is never forgotten in either init path.
4. **Increment site**: Stage 3c (lines 284-318), a **mandatory-every-iteration gate** that runs
   before Stage 4 dispatch decisions. On any of three self-check signals firing, it increments
   the in-memory shell variable, then re-persists via the same read-modify-write-then-`mv`
   pattern used everywhere else in this file for `loop_guard_file`.
5. **No cap of its own.** Unlike `MAX_BLOCKER_ESCALATIONS` or `MAX_DRIFT_INSPECTIONS`, this
   counter has no `MAX_BURNOUT_SIGNALS` — every firing forces a fresh dispatch or escalation
   (Stage 6), which is itself capped by `MAX_BLOCKER_ESCALATIONS`. In other words, burnout
   signals convert into *cycle-consuming* dispatches, so `MAX_CYCLES` is the implicit outer
   bound. **This is not directly transferable to the infra-failure counter**, because the whole
   point of the infra-failure counter is that its increments must *not* be cycle-consuming — so
   it needs its own explicit cap (Stage 3.6/Stage 7-style terminal exit), unlike burnout's
   implicit-via-MAX_CYCLES bound.

### The central question: what signal is actually observable?

**No single, purely-mechanical (bash-only) signal reliably distinguishes "the Agent tool call
failed at the transport/API layer, subagent never ran" from "the subagent ran and left no
handoff."** This is a real, load-bearing finding, not a gap to paper over — argued concretely:

- **The Agent/Task tool call is not a shell command.** It is an LLM tool invocation issued and
  observed directly by the orchestrator (itself an LLM, per this skill's own execution model —
  the SKILL.md interleaves narrated `Agent tool: ...` steps with literal bash blocks throughout,
  e.g. Stage 5a, Stage 6). Its outcome — subagent final message vs. a transport/API-layer error
  surfaced as the tool result — is visible to the orchestrator *at the moment the tool call
  returns*, not to any later bash invocation. Stage 5's bash block runs strictly *after* the tool
  call has already returned control, so a bash-only check (as currently written, `if [ ! -f
  "$handoff_file" ]`) has structurally already lost the one signal that would have distinguished
  the two cases.
- **State.json/task-notification status fields do not help.** `skill_preflight_update` (called
  by the orchestrator's own bash, immediately *before* every dispatch) always lands regardless of
  whether the subsequent Agent call succeeds — it is written by the caller, not the callee, so
  its presence proves nothing about whether the subagent executed.
- **Whether *any* file changed is a real but imperfect signal**, and is exactly where the
  "did ZERO work" vs. "died mid-edit" tension in the task description resolves: if the dying
  agent had reached far enough to touch any file (including its own `.return-meta.json`), that is
  proof of execution and the cycle must be charged as genuine, regardless of what the transport
  layer did afterward. The reverse is not proof of nothing having happened either (a subagent
  could complete a whole turn, decide what to edit, and then die before the edit tool call lands)
  — but the earliest, cheapest, and most reliable proxy already built into this system is the
  **early-metadata write**: every agent following `early-metadata-pattern.md` / the
  `general-research-agent`/`general-implementation-agent` Stage 0 contract writes
  `specs/{NNN}_{SLUG}/.return-meta.json` with `status: "in_progress"` **before any substantive
  work**, specifically so that `delegation_interrupted` (a related, already-defined error
  category — see `rules/error-handling.md` line 27 and `early-metadata-pattern.md` lines 162-203)
  can be detected. If `.return-meta.json` was written or modified *during this cycle's dispatch
  window*, the subagent executed at least one turn — that is unambiguous, mechanical, and
  available to the orchestrator's own bash without any new agent-side plumbing. If it was not
  touched during the window (still at its pre-dispatch mtime, or entirely absent), that is the
  strongest available evidence that the subagent never got as far as its own first tool call.
- **Neither signal alone is sufficient; the task explicitly warns against the permissive
  failure mode.** A tool-call-level error string alone is not proof of "no work" (a subagent can
  emit partial output, touch files, *and* then have the connection die on its final turn — the
  observed "died mid-edit" wording is consistent with this). Conversely, an untouched
  `.return-meta.json` alone (without an accompanying transport-error observation from the tool
  call itself) could also result from an early, ordinary agent bug unrelated to infrastructure
  (e.g., a subagent that silently no-ops). **Requiring both signals together is the deliberately
  conservative design**: default to charging a genuine cycle; only exempt when there is
  corroborated evidence of *both* a transport/API-layer failure *and* zero local footprint.

**Recommended discrimination rule** (to live in Stage 5's missing-handoff branch, both variants,
and to be defined once in a shared doc referenced by both — see Edit Sites):

1. Immediately after each Agent tool dispatch (narrated LLM step, not bash — same pattern as
   existing Stage 5a/Stage 6 narration): judge whether the tool call itself returned a
   transport/API-layer error rather than any subagent-authored output. Concrete positive
   indicators: connection/DNS failures (`ENOTFOUND`, `EAI_AGAIN`, `ECONNREFUSED`, `ECONNRESET`,
   `ETIMEDOUT`), TLS/handshake failures, an explicit harness-level exception for the tool
   invocation itself, or an API-layer error object (`overloaded_error`, `api_error`,
   5xx) with **no subagent-authored text at all**. Negative indicator (NOT infra, must charge):
   any subagent-authored text exists, even if that text itself describes an error the subagent
   encountered (e.g., "I hit a network error while fetching X and am reporting partial
   findings") — that is the subagent narrating its own experience, proof it ran.
   Set `dispatch_was_transport_error=true|false`.
2. Mechanically (bash, Stage 5): record `dispatch_start_ts=$(date -u +%s)` immediately before
   each Agent dispatch (one new line per dispatch site). In Stage 5, when `$handoff_file` is
   missing, check whether `${TASK_DIR}/.return-meta.json` has an mtime `>= dispatch_start_ts` (or
   whether it did not exist before dispatch and now does). Set `meta_touched=true|false`.
3. Classify as infra failure **only if** `dispatch_was_transport_error=true` AND
   `meta_touched=false`. Otherwise, preserve today's behavior exactly (log the existing ERROR
   message, charge `cycle_count`).

### Cap recommendation

**`MAX_INFRA_FAILURES=3`, identical value in both `skill-orchestrate` and
`skill-orchestrate-hard`.** Justification:

- The task explicitly names the risk: "an unbounded no-increment path could spin forever on a
  persistent outage" and prefers a separately-capped counter over a no-increment path for exactly
  this reason. A flat cap satisfies that constraint directly.
- Unlike `MAX_CYCLES` (5 vs. 13, scaled to accommodate hard mode's per-phase dispatch — one cycle
  per phase, documented at hard-mode line 252-253), infra tolerance has no relationship to plan
  size or phase count. It should not scale with `MAX_CYCLES`; a flat, small value avoids
  implicitly licensing more retries just because a task happens to have more phases.
- This codebase's existing small-cap precedents are uniformly low: `MAX_BLOCKER_ESCALATIONS=2`,
  `MAX_DRIFT_INSPECTIONS=1`. Three consecutive genuine transport failures already indicates
  either a real outage (in which case retrying a fourth time within the same invocation wastes
  wall-clock time without benefit — the user should re-run `/orchestrate` later) or a
  misclassification bug (in which case an unbounded counter would mask it). `3` is generous
  enough to absorb a couple of transient DNS/connection blips (the scenario this task is actually
  trying to protect against) while remaining a hard stop against runaway retries.
- **On cap reached**: exit `partial` with a message distinct from the `MAX_CYCLES` message (so a
  human/log reader can immediately tell "infra flakiness" from "ran out of work budget"), e.g.
  `[orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number —
  possible persistent connectivity issue, not charged against MAX_CYCLES. Run /orchestrate
  $task_number again once connectivity is confirmed.` Do not fall through to also incrementing
  `cycle_count` on the failures that hit the cap — the cap's entire purpose is to stay outside the
  work-cycle budget; once capped, the correct recovery is a fresh invocation, not consuming a
  cycle on a failure the orchestrator has already classified as non-work.

### Edit sites (both variants)

**Shared** (new content, single source of truth, referenced from both SKILL.md files — follows
this codebase's established pattern of factoring cross-variant logic into one file rather than
duplicating, e.g. `context/patterns/lit-stage4a-flow.md`):
- A new pattern/contract doc, e.g. `context/patterns/infra-failure-discrimination.md` (or fold
  into `docs/architecture/orchestrate-state-machine.md` / `docs/architecture/handoff-schema.md`
  as a new section — planner's call), stating the discrimination rule above precisely enough to
  be copy-pasted as a Stage 5 sub-block by both skills.

**`skill-orchestrate/SKILL.md`**:
1. Stage 2 (~line 105-151): declare `MAX_INFRA_FAILURES=3`; extend the fresh-start `jq -n` blob
   (~121-132) with `"infra_failures": 0`; extend the resume-read (~113) and the lost-race
   resume-read (~137) to also read `infra_failures`.
2. Stage 4 dispatch sites (~220-228, 253-261, 278-286, 312-318): add
   `dispatch_start_ts=$(date -u +%s)` immediately before each `Invoke the Agent tool` step, and
   a one-line narrated instruction to set `dispatch_was_transport_error` per the shared rule.
3. Stage 5 (~369-378): replace the current unconditional "Increment cycle and continue" comment
   with the discrimination branch (checks `dispatch_was_transport_error` + `.return-meta.json`
   mtime vs. `dispatch_start_ts`; increments `infra_failures` capped at `MAX_INFRA_FAILURES`
   instead of `cycle_count` when both hold).
4. New terminal-condition block analogous to Stage 7's MAX_CYCLES check (~565-571): add a
   MAX_INFRA_FAILURES-reached exit path.
5. Stage MT-1 (~line 650): add `infra_failures: {}` (task_num → count) to the `mt_state_file`
   schema.
6. Stage MT-4 step 1 (~787-788): replace "If missing: mark task in `failed_tasks`, skip" with the
   same discrimination branch, scoped per-task; on non-infra missing handoff, preserve current
   behavior (mark `failed_tasks`) — note this is the **worse** of the two existing manifestations
   (no retry at all today), so this site should be prioritized in planning.

**`skill-orchestrate-hard/SKILL.md`**:
1. Stage 2 (~line 192-250): declare `MAX_INFRA_FAILURES=3` alongside `MAX_CYCLES=13`; extend the
   loop-guard fresh-start blob (~210-223) with `"infra_failures": 0`, matching
   `burnout_signals_this_session`'s exact declaration/persistence shape (same file, same
   read-modify-write pattern); extend both resume-read branches (~200-202, ~226-229).
2. Stage 4 dispatch sites: `not_started` (~324-340), the H4-gated `researched` plan dispatch
   (~346-391, both the verification re-dispatch at ~368-373 and the eventual planner dispatch at
   ~386-390), and the H1 per-phase dispatch (~397-480, single site at ~450-453) — same
   `dispatch_start_ts` + narrated transport-error judgment addition as base.
3. Stage 5 (~619-630): same discrimination branch as base Stage 5.
4. Stage 7 (~757-767): add the MAX_INFRA_FAILURES terminal-condition block alongside the existing
   MAX_CYCLES check.
5. Multi-task mode: **no separate edit needed** — hard mode's "Multi-Task Mode" section (782-786)
   explicitly delegates to base's MT-1..MT-5 unchanged, so fixing base Stage MT-1/MT-4 covers
   `/orchestrate --hard` multi-task runs automatically. Confirm this delegation still holds after
   the base edit (i.e., the hard-mode per-phase dispatch inside multi-task waves must still set
   `dispatch_start_ts` — verify during planning whether MT-4's dispatch loop for `implement_tasks`
   needs the same one-line addition since it is shared code, not duplicated per-variant).

**Out of scope / explicitly not touched by this fix** (flag for planner, do not silently absorb):
- Stage 4b's churn detection (`skill-orchestrate-hard` 566-613) and its own `total_churn` /
  `target_churn` counters — a structurally different, already-working mechanism for a different
  failure class (repeated *content* churn, not transport failure).
- Stage 6's blocker-research fork (`skill-orchestrate` 515-523, `skill-orchestrate-hard` 741-744)
  reads `$handoff_file` without its own missing-handoff branch; this predates and is orthogonal
  to the defect in scope here.

## Decisions

- Treat the discrimination rule as requiring **two corroborating signals** (narrated
  tool-call-level judgment + mechanical `.return-meta.json` freshness check), not one, per the
  task's own "getting this wrong in the permissive direction" warning.
- Recommend a **separate, capped counter** (`infra_failures`, cap `MAX_INFRA_FAILURES=3`) over a
  no-increment path, matching the task description's stated preference and the
  `burnout_signals_this_session` precedent's declaration/persistence shape — but explicitly
  diverging from that precedent by giving the new counter its own cap, since (unlike burnout
  signals) its increments must never consume a cycle.
- Flag the multi-task Stage MT-4 manifestation (line 787-788, marks `failed_tasks` outright on
  any missing handoff, no retry) as the more severe of the two existing defect manifestations and
  recommend the planner prioritize it alongside the single-task Stage 5 fix, not treat it as a
  minor follow-on.

## Risks & Mitigations

- **Risk**: narrated LLM-judgment steps are inherently softer than pure bash and could regress
  toward the exact "unsanctioned judgment call" problem this task exists to eliminate.
  **Mitigation**: the mechanical `.return-meta.json` mtime check is a hard bash gate that must
  independently agree before the infra-failure path is taken — the LLM judgment alone can never
  exempt a cycle from being charged.
- **Risk**: a subagent that writes early metadata but then genuinely dies to a transport failure
  immediately afterward (i.e., real infra failure, but `meta_touched=true`) will still be charged
  as a genuine cycle under this rule. **Mitigation**: this is the deliberately conservative
  choice — the task explicitly prioritizes protecting `MAX_CYCLES` from being defeated over
  perfectly forgiving every possible infra hiccup; accept the residual false-negative (charging a
  cycle for a very-early-but-not-earliest infra death) as the cost of avoiding the far worse
  false-positive (defeating the cap).
- **Risk**: adding `dispatch_start_ts` to every dispatch site is mechanical but touches 7-9
  distinct locations across both files; a planner must not miss one, or that dispatch site will
  silently fall back to always charging (safe direction) or always exempting (unsafe) depending
  on how the missing variable is handled. **Mitigation**: recommend the plan use `${VAR:-0}`-style
  bash defensive defaults so a forgotten site fails toward "always charge" (the safe direction),
  and recommend a grep-based verification step (`grep -c 'Invoke the Agent tool' SKILL.md` vs.
  `grep -c 'dispatch_start_ts=' SKILL.md`) at the end of implementation to catch omissions.

## Context Extension Recommendations

- **Topic**: Agent-tool-call-level failure signals available to a narrating orchestrator.
  **Gap**: `mcp-tool-recovery.md` documents MCP tool failure recovery (AbortError -32001) but
  nothing documents Agent/Task tool transport-layer failure recognition patterns specifically.
  **Recommendation**: the new `infra-failure-discrimination.md` pattern doc (see Edit Sites)
  should double as this documentation, cross-linked from `mcp-tool-recovery.md`'s "Related
  Documentation" section once it exists.

## Appendix

Search/read queries used: full reads of both SKILL.md files; targeted `grep -n` re-derivation of
every anchor cited above (both against stale description numbers and independently); reads of
`handoff-schema.md`, `early-metadata-pattern.md`, `mcp-tool-recovery.md`, `error-handling.md`,
`orchestrator-discipline.md`, `fork-patterns.md`; grep sweep for `ENOTFOUND`/`transient`/`network
error`/`infra_failure` across `agent-system/extensions/core/` (no prior art beyond the patterns
cited above).
