---
paths: "**/*.lean"
---

# Plan Compliance Rules

## Path Pattern

Applies to: **/*.lean

## Core Principle

When an implementation plan exists for a `.lean` file, the plan is the contract. The agent's
job is to execute the plan's task sequence, not to re-derive its own decomposition. A plan
already reflects deliberate choices about lemma structure, proof order, and scope; discarding
that work mid-implementation to substitute a different approach destroys the planning investment
and produces divergent, hard-to-review proofs.

Motivation: repeated observed failures in formal-proof implementation, where an agent produced
many successive plan revisions because each implementation dispatch re-derived its own
decomposition instead of executing the existing plan's task sequence — discarding prior planning
effort every cycle.

## Forbidden Patterns

The following rationalizations are explicitly banned when a plan exists for the file being
edited:

- **Assessing what's "truly minimal"** — the plan already made this judgment; re-assessing it
  mid-implementation is scope renegotiation, not execution
- **Inventing an alternative approach** — do not substitute your own proof strategy for the
  plan's specified one, even if you believe yours is better
- **Skipping intermediate theorems** the plan specifies, to jump directly to a final result
- **Inlining proofs** instead of following the plan's decomposition into named lemmas
- **Routing through different helper lemmas** than the plan specifies
- **"Cleaner approach" rationalizations** — a cleaner-seeming shortcut discovered mid-proof is
  not license to abandon the plan's decomposition

## Required Behavior

- Follow the plan's exact task sequence, step-by-step, in the order given
- Implement each specified lemma/theorem as its own step, even if a later step could subsume it
- If a step genuinely cannot be completed as written, stop and escalate (see below) rather than
  silently substituting a different step

## Relationship to Plan Deviations

`general-implementation-agent.md` and `cslib-implementation-agent.md` document a sanctioned
"Plan Deviations" mechanism: an implementation agent may skip, alter, or defer a plan step with
only a post-hoc inline annotation, no pre-approval gate. **For files matching this rule's glob,
that mechanism is not a substitute for compliance.** A would-be deviation on a `.lean` file must
first be raised as a blocker to the user — mark the phase `[BLOCKED]` and explain what was tried
and why the plan step cannot be executed as written. Do not silently annotate and proceed past
it. This narrows the general policy for formal-proof files only; the general policy remains
unchanged for all other file types.

## Related Context

- **Literature Fidelity** (`lean4.md`): governs following a *literature source* (paper,
  textbook). This rule governs following the *plan*. Both matter and neither substitutes for
  the other — a task can have a literature source, a plan, both, or neither.
- **H2 anti-analysis** (`anti-analysis.md`): governs pace and analysis-output ratio, gated
  behind `--hard`. This rule applies unconditionally, in every mode, whenever a plan exists.
