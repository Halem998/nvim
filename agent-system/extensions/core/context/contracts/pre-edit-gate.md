# Pre-Edit Verification Gate Contract

This contract requires cheap, proportionate per-item evidence before any item drawn from a
mechanically-generated list — a plan's file list, a grep result set, a candidate count from any
other scan — is actually applied as an edit. It exists because mechanical lists produce false
positives that a naive implementer applies unchallenged, and because a silent skip of a false
positive is just as much a defect as forcing a bad edit through.

## Loaded via explicit reference in BOTH modes

Like `context/contracts/phase-closure.md`, this is a non-hard-exclusive occupant of
`context/contracts/`. Every pre-existing file in this directory is loaded only by `*-hard` agents
and skills, but directory placement is a naming convention, not a load mechanism, in this
codebase — the load-bearing mechanism is an explicit `@`-reference bullet in the consuming
agent's or skill's `## Context References` section. This contract carries that bullet in
`agents/general-implementation-agent.md` (standard mode, and — since core's standalone hard-mode
implementation agent was deleted and merged into `skill-orchestrate`'s H1 per-phase dispatch
branch — the sole surviving core implement-dispatch target for hard mode too), and
`skills/skill-implementer/SKILL.md` (a discoverability reference — the skill delegates loading to
its agent). It is
additionally referenced from every non-core extension implementer agent that runs a plan-phase
loop, and from any extension skill file maintaining its own contract-bullet list, following the
same explicit-bullet mechanism rather than a separate injection path. See
`context/architecture/context-layers.md`'s "Contracts directory: convention vs. load path"
subsection for the full finding.

## A planning-time list is a hypothesis

Any enumerated file list, candidate set, or count that reaches the implementer from a plan, a
grep, or any other mechanical scan is a **hypothesis about the codebase, never a fact about it**.
`context/formats/plan-format.md`'s `**Scope Hypothesis:**` field is the planner-side carrier for
exactly this obligation; that document states its own consuming, implementation-side gate is
"out-of-scope for this document." This contract is that consumer. A phase carrying a
`**Scope Hypothesis:**` line implies its enumerated items require per-item confirmation before any
edit lands — the hypothesis is not self-confirming just because it was written down.

## Probe before edit

Before applying any item from such a list, gather cheap evidence that the item is real. Concrete
probe shapes, chosen by what the edit is doing:

- **Reference count** — does anything still call this? A grep or search over the relevant scope
  for remaining references to a symbol, file, or pattern targeted for removal or rename.
- **Build probe** — does removing or renaming it still compile (or pass the equivalent
  build/typecheck/lint step for the language in play)? A quick local build after a trial edit, or
  a dry-run where the tooling supports one.
- **Definition lookup** — is there a real implementation behind this name, or only the
  declaration the scan matched? A scan that matches a signature, a stub, or a comment can produce
  a false positive that a definition lookup catches immediately.

## Proportionality

Probe cost scales with the edit's blast radius. A single-file comment tweak warrants a glance; a
symbol deletion or a rename applied across a namespace warrants a reference count over the whole
tree before it lands. This contract includes an explicit cheapness ceiling so it cannot be
deflected into open-ended investigation: **the probe is a bounded check with a yes/no answer, not
a research sub-task.** If a probe cannot be made cheap — it would require deep tracing,
speculative execution, or more than a few minutes of investigation to get a yes/no answer — that
difficulty is itself the signal to escalate to the plan (flag it, do not silently skip it, do not
spend the dispatch's budget chasing it inline).

## Failed probe becomes a documented reasoned exclusion

An item whose probe contradicts the hypothesis — the reference count is nonzero when the plan
expected zero, the build breaks, the definition lookup finds a live implementation the scan
missed — is **neither silently skipped nor force-applied**. It is recorded in the phase's
`#### Reasoned Exclusions` table using the existing `Item | Reason | Evidence` columns from
`context/formats/plan-format.md` verbatim: the excluded item goes in `Item`, why it is not
applicable goes in `Reason`, and the probe's own output — the reference count, the build error,
the definition location — goes in `Evidence`. When all five admission-test conditions in
`context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection hold, the phase
closes as `[COMPLETED WITH EXCLUSIONS]` rather than `[PARTIAL]` or a forced, unverified
`[COMPLETED]`. **No parallel or competing record schema may be invented for this purpose** — the
existing table is the landing zone, full stop.

## Orthogonality

This gate is a third, separate axis from two existing per-phase fields in
`context/formats/plan-format.md`, and must not be folded into either of them:

- **Verification Tier** (`prose < local < interface < full`) governs how thoroughly a *phase* is
  checked when it *closes* — a property of the phase's overall verification depth.
- **Commit Mode** (`per-substep` / `atomic-batch`) governs *commit granularity* — when work gets
  committed relative to other work in the same phase.
- **This pre-edit gate** governs per-*item* evidence *before* an individual edit *lands* — it acts
  at the moment of applying one item from a mechanical list, independent of how the surrounding
  phase is tiered or committed.

A phase's Verification Tier does not substitute for a per-item probe, and a per-substep commit
policy does not imply per-item evidence was gathered. Treating any two of these three as the same
knob loses information a future reader needs; say so explicitly rather than letting the
distinction stay implicit.

## Observed failure modes

Concrete shapes a naive mechanical list produces, described here as failure shapes without citing
any specific instance:

- A dead-code scan matches a **declaration** whose real implementation lives elsewhere — deleting
  the matched declaration breaks the actual call site, which the scan never saw.
- A namespace-cleanup list assumes a prefix is unused, but live call sites still depend on it —
  the edit compiles locally in isolation but breaks the build once the full tree is considered.
- A rename list contains a known false positive: an item that matches the rename pattern
  syntactically but is semantically a different concept, so renaming it silently changes behavior
  rather than just relabeling it.

Each of these is caught by exactly one of the three probe shapes above — reference count for the
first two, definition lookup for the third — which is why the probe is chosen proportionate to
what the edit is actually doing, not applied uniformly regardless of shape.
