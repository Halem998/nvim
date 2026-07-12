# Convergence Policing Contract (H6)

This contract implements H6: Convergence Policing. It governs the orchestrator's loop
guard to prevent churn — repeated cycles that move work without making progress.

## Progress Criterion Declaration

Before dispatching an implementation agent, the orchestrator MUST state:

1. **Target**: What specific artifact or milestone this dispatch is completing
2. **Success criterion**: How to verify the target is done (e.g., "file exists and has N lines",
   "all tests pass", "phase marker shows [COMPLETED]")
3. **Baseline**: What was the state before this dispatch

This prevents post-hoc rationalization of churn as "progress".

## Churn Signatures

The following patterns in agent output indicate churn, not progress:

1. **Same target moved**: Agent reports "moved" or "refactored" the same target as the
   previous dispatch without net new functionality
2. **Repeated defect verdicts**: Agent claims the same component is defective in consecutive
   dispatches without implementing a fix
3. **Inflating estimates**: Agent's estimate of remaining work increases between dispatches
   (e.g., "5 more dispatches needed" -> "8 more dispatches needed")
4. **Sorry relocation**: In formal verification, sorrys are moved between files/lemmas
   without being resolved
5. **Architecture re-opens**: Agent re-opens a settled architectural decision without
   presenting a new concrete counterexample

The orchestrator tracks `churn_count` (total churn signatures detected) and
`target_churn_count[target]` (churn signatures per specific target).

## Three-Strikes Rule

When `target_churn_count[target]` reaches 3 for any specific target:

1. **Stop**: Do NOT dispatch another implementation agent for this target
2. **Audit**: Dispatch a research agent with `focus_prompt` containing "divergence audit" and
   the target description (activates H5 divergence audit mode in hard research agents)
3. **Reset**: Only after the audit returns with a corrected target definition, dispatch
   implementation again

This rule is strict. Three churn signatures on the same target means the target is
mis-specified, not that the agent needs to try harder.

## User-Authorization Requirement

Architectural pivots — changes that invalidate completed work, require re-implementing
finished phases, or change the fundamental representation — require explicit user authorization:

1. Present the proposed pivot via AskUserQuestion
2. State: current approach, proposed change, what completed work becomes invalid
3. Present at least two options: (a) accept the pivot, (b) proceed with current approach
4. Obtain explicit "yes" before implementing the pivot

Agents MAY NOT implement architectural pivots without this authorization, even if they
determine the current approach is suboptimal.

## Escalation Ladder

When standard dispatch cycles are not converging:

```
1. Standard dispatch (up to 3 attempts per phase)
2. On 3rd failed attempt: Three-Strikes audit (H5 research dispatch)
3. After audit: Revised dispatch with audit findings
4. On continued failure: AskUserQuestion for architectural decision
5. On 2nd user authorization: Mark phase BLOCKED, continue with other phases
```

The escalation ladder is traversed in order. Skipping levels requires explicit justification.
