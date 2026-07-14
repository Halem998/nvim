# CSLib Proof Structure Patterns

Guidelines for proof style, readability, and automation in CSLib. Derived from CONTRIBUTING.md.

## Core Principle: Readability First

Make proofs easy to follow. A proof that compiles but is inscrutable is harder to review,
maintain, and build on. Prefer explicit intermediate steps over opaque automation.

## Golfing Policy

Golfing and automation are **welcome** when both conditions hold:
1. The proof remains **reasonably readable** after golfing
2. Compilation does not **noticeably slow down**

If golfing sacrifices readability or adds compilation time, prefer the more explicit form.

**When to golf**: Routine goals where the proof structure is clear from the goal state
(e.g., simple arithmetic, obvious equalities, trivial applications of a single lemma).

**When not to golf**: Multi-step arguments where each step has mathematical significance,
or when the proof strategy isn't obvious from the goal alone.

## Named Intermediate Steps

Use `have` to document proof intent and create readable checkpoints:

```lean
theorem foo (h : P ∧ Q) : R := by
  have hP : P := h.1
  have hQ : Q := h.2
  exact bar hP hQ
```

Prefer descriptive names over `h1`, `h2` when the step has semantic content:
- `hpos` over `h1` when proving positivity
- `hbound` over `h2` when establishing a bound
- `hIH` for induction hypotheses when not introduced by `induction`

## Automation Preferences

### Bounded Automation

Prefer bounded automation that is explicit about what it uses:

```lean
-- PREFERRED: explicit simp lemmas
simp only [Nat.add_comm, Nat.mul_comm]

-- USE SPARINGLY: unbounded simp (can be slow and fragile)
simp
```

**Standard automation tactics**:
- `simp only [...]` -- preferred for targeted simplification
- `omega` -- arithmetic over integers/naturals
- `ring` -- ring arithmetic
- `decide` -- decidable propositions
- `aesop` -- general automation (can be slow; use for simple goals)

### Avoiding Slowdowns

When a tactic is slow:
1. Use `simp only` instead of `simp` and add the specific lemmas needed
2. Break the goal into smaller subgoals with `have`
3. Use `conv` for targeted rewriting inside terms
4. Profile with `set_option profiler true` to identify bottlenecks

## Tactic Block Format

Use indented tactic blocks consistently:

```lean
theorem myLemma (h : P) : Q := by
  intro x
  apply someFunc
  · exact left_case h
  · exact right_case h
```

For case splits, use the `·` (focused tactic) syntax to make case structure explicit.

## Term Mode vs Tactic Mode

**Use term mode** when:
- The proof is a straightforward application of a function or constructor
- The structure is clear without intermediate steps
- Example: `theorem foo : P ∧ Q := ⟨hp, hq⟩`

**Use tactic mode** when:
- The proof requires multiple steps or case analysis
- Intermediate hypotheses need to be named for clarity
- The goal state needs to be inspected during development

Mixing modes is fine; use `exact`, `show`, and `refine` to switch between them.

## Literature Fidelity

When a proof follows a published source (paper, textbook):
- Follow the source step-by-step
- Name intermediate steps after the source's lemma labels or theorem numbers
- Cite the source in the module docstring `## References` section

Deviation from the source approach should be documented in `## Implementation notes`.
