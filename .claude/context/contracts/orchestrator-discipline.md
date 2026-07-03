# Orchestrator Discipline Contract

This contract binds the ORCHESTRATOR ROLE itself — not the agents it dispatches. H2
(`anti-analysis.md`) is injected only into IMPLEMENT dispatch prompts via
`build_hard_mode_prompt_context()`; the orchestrator's own turns have no prompt string to
inject into, so its behavior was previously ungoverned. This is the root cause of the
burnout incident that motivated this task: an orchestrator entered circular reconsideration
of a settled phase target ("before I concede... ONE more time"), absorbed implementation-grade
reasoning into its own turns instead of dispatching, and reached an unsound inline `BLOCKED`
conclusion — later caught only by a standard-mode audit dispatched from outside the loop. This
contract exists to make that failure mode structurally unreachable: the orchestrator is bound
by the same discipline expected of the agents it dispatches, expressed as a role contract
rather than a prompt-injection slot.

## Prohibited Actions

The orchestrator MUST NOT, at any point in the state-machine loop:

1. **No inline design/proof analysis.** Reasoning about whether a design, proof strategy, or
   implementation approach is correct is implementation-grade work. It belongs in a dispatched
   agent's turn, not the orchestrator's own reasoning.
2. **No reading implementation source.** Backs 772's Tool Constraints "Forbidden Reads"
   behaviorally: `lua/**`, `after/**`, or any per-project source root an `$IMPLEMENT_AGENT`
   would modify is off-limits to the orchestrator itself, even to "just check" a claim.
3. **No running builds.** Backs 772's Tool Constraints "Forbidden Bash Operations"
   behaviorally: `lake build`, `lean`/`lean-lsp`, `nvim --headless`, test runners, or any
   build/test/compiler/linter tool belong exclusively to the dispatched agent.
4. **No mid-cycle strategy reconsideration without a fresh dispatch.** The orchestrator may not
   revisit a phase target, escalation decision, or architectural judgment call using only its
   own prior reasoning. Reconsideration requires a new finding from a freshly dispatched agent.

## The Only Two Allowed Responses

When a phase cannot complete in a bounded dispatch, the orchestrator has exactly two allowed
responses — a closed ladder, not a menu to improvise from:

(a) **Dispatch a fresh research/audit agent.** Use `$RESEARCH_AGENT` with `focus_prompt` set to
    a literal restatement of the exact unresolved question. This is the correct response when
    the orchestrator finds itself reasoning about what a phase or target *should* be.

(b) **Escalate via the blocker ladder** (Stage 6). This is the correct response when the
    question is not "what should this phase do" but "should we keep escalating this blocker".

**Absorbing the work inline is NOT a third option.** Working through the design question,
proof strategy, or root cause inside the orchestrator's own turn — even partially, even as
"just thinking out loud before dispatching" — is exactly the anti-pattern this contract
forbids. If neither (a) nor (b) has been invoked, the orchestrator has not yet responded.

## Burnout Circuit-Breaker Signals

These three signals reframe `context-exhaustion-detection.md`'s three categories for
orchestrator self-monitoring. Any one of them firing is a violation requiring the Forced
Action below, not a judgment call:

1. **Repeated same-file re-reads.** The orchestrator re-reads a path it has already read in
   this session without an intervening `Agent` dispatch having produced new information.
2. **Consecutive inline-reasoning turns with no dispatch.** Two or more consecutive
   orchestrator turns reason about task content (phase status, design, blockers) without an
   `Agent` tool call landing in between.
3. **Mid-analysis strategy reversal.** The orchestrator is about to reverse a phase, target, or
   escalation decision, and the reversal is not grounded in a new finding a fresh dispatch just
   produced.

## Forced-Handoff / Forced-Dispatch Mechanism

On any signal firing, the orchestrator MUST stop the current line of reasoning immediately —
mid-sentence if needed — and take response (a) or (b) from "The Only Two Allowed Responses"
above. No new artifact type or state file is introduced:

- If the orchestrator was reasoning about what a phase/target *should* be → response (a):
  dispatch `$RESEARCH_AGENT`, shaped like Stage 4b's divergence-audit dispatch, but triggered
  by a burnout signal instead of a churn-count threshold.
- If the orchestrator was deciding whether to keep escalating a blocker → response (b): jump
  directly to Stage 6.

The forced dispatch/escalation reuses the state machine's existing paths verbatim. The only
mechanized trace of a signal firing is the scalar counter `burnout_signals_this_session`,
which increments on `loop_guard_file` in the same jq write Stage 3b already performs — no
sidecar file, no separate artifact type.

## Domain Specialization / Scope

**`--hard`-only.** This contract governs `skill-orchestrate-hard`'s state-machine loop
specifically — the once-per-invocation Stage 1c preamble and the every-cycle Stage 3c gate.
Base `skill-orchestrate` has no contract-slot mechanism and no per-phase dispatch loop tight
enough for burnout to accumulate the way it did here; it is out of scope for this contract.
