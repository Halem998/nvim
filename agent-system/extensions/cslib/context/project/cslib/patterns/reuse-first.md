# CSLib Reuse-First Design Pattern

The central design philosophy for contributing to CSLib. Derived from CONTRIBUTING.md and
ORGANISATION.md.

## Core Principle

A central focus of CSLib is providing **reusable abstractions** and their **consistent usage**
across the library. New definitions should instantiate existing abstractions whenever
appropriate.

**Before defining something new, ask**: Does an existing typeclass or abstraction already
capture this concept?

## Typeclass Instantiation Examples

### Labelled Transition Systems

A new LTS implementation should instantiate the `LTS` typeclass from
`Foundations/Semantics/LTS/`, not define its own transition relation from scratch.

```lean
-- WRONG: ad hoc transition relation
def myTransition : State → Label → State → Prop := ...

-- RIGHT: instantiate existing typeclass
instance : LTS MyState MyLabel where
  transition := ...
```

### Abstract Syntax

For a new language with variable binding, use the typeclasses from `Foundations/Syntax/`:
- `HasAlphaEquiv` -- for alpha-equivalence
- `HasWellFormed` -- for well-formedness
- `HasSubstitution` -- for substitution
- `HasFresh` -- for fresh name generation (`Foundations/Data/HasFresh.lean`)

### Logic Frameworks

For a new logic, instantiate from `Foundations/Logic/`:
- `HasBot`, `HasImp`, `HasBox` -- connective typeclasses (`Foundations/Logic/Axioms.lean`)
- Hilbert-style proof system typeclasses (`Foundations/Logic/ProofSystem.lean`)

## Where to Find Abstractions

| Concept | Location |
|---------|----------|
| LTS / operational semantics | `Foundations/Semantics/LTS/` |
| Functional LTS | `Foundations/Semantics/FLTS/` |
| Alpha-equivalence | `Foundations/Syntax/HasAlphaEquiv.lean` |
| Well-formedness | `Foundations/Syntax/HasWellFormed.lean` |
| Substitution | `Foundations/Syntax/HasSubstitution.lean` |
| Fresh name generation | `Foundations/Data/HasFresh.lean` |
| Logic connectives | `Foundations/Logic/Axioms.lean` |
| Abstract proof systems | `Foundations/Logic/ProofSystem.lean` |
| Step-indexed relations | `Foundations/Data/RelatesInSteps.lean` |

## Notation Reuse

The same principle applies to notation. For common concepts like reductions or transitions:
1. Check for an existing typeclass that provides the notation
2. Only define new notation if no existing typeclass fits
3. If defining new notation that could apply to multiple types, create a typeclass

Example: if adding a new language with reduction semantics, find which notation option
(A, B, or C) is used in similar files and instantiate the corresponding typeclass.
See `domain/notation-conventions.md` for the three notation options.

## Typeclass Hierarchy

The Foundations typeclass hierarchy forms the backbone of CSLib's reuse infrastructure:

```
HasBot, HasImp, HasBox, ...    (connective typeclasses)
           │
           ▼
   HasInferenceSystem           (abstract derivability)
           │
           ▼
     HasProofSystem             (Hilbert-style proof systems)

HasAlphaEquiv                  (alpha-equivalence for syntax)
HasWellFormed                  (well-formedness for syntax)
HasSubstitution                (substitution for syntax)
HasFresh                       (fresh name generation)

LTS                            (labelled transition system)
```

When contributing a new formalization:
1. Identify which typeclasses from this hierarchy apply
2. Provide instances before developing specific theory
3. Generic theorems from `Foundations/` become available automatically

## Checking Before Creating

Before adding a new definition:
1. Search `Foundations/` for existing typeclasses
2. Search `Logics/` for similar instantiations
3. Check the mathlib library for overlapping infrastructure
4. When in doubt, ask on CSLib Zulip -- someone may have already formalized it or have a
   preference for how it should fit into the library
