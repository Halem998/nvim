# CSLib Project Organization

Directory structure and namespace conventions for CSLib. Derived from ORGANISATION.md.

**Note**: This organization is under active discussion and may change.

## Top-Level Structure

```
Cslib/                     -- Root namespace of the Computer Science library
├── Foundations/           -- General-purpose definitions shared across all logics
├── Logics/               -- Specific logic formalizations
├── Languages/            -- Modelling and programming languages
├── Computability/        -- Automata theory, Turing machines, register machines
├── Algorithms/           -- Algorithm formalizations
├── Crypto/               -- Cryptography formalizations
├── MachineLearning/      -- Machine learning formalizations
├── Probability/          -- Probability theory formalizations
└── Init.lean             -- Root initialization file (all files must import this)

CslibTests/               -- Library tests
Cslib.lean                -- Barrel import of all library files
references.bib            -- BibTeX bibliography for citation keys
```

## Foundations/ (Shared Infrastructure)

The `Foundations/` directory provides infrastructure shared across all specific logics. It defines
abstract proof systems, connective typeclasses, and generic theorems that are instantiated by
each logic.

```
Foundations/
├── Logic/                     -- Abstract proof system infrastructure
│   ├── Axioms.lean            -- Connective typeclasses (HasBot, HasImp, HasBox, etc.)
│   ├── Connectives.lean       -- Derived connective abbreviations
│   ├── InferenceSystem.lean   -- Abstract inference system and derivability
│   ├── ProofSystem.lean       -- Hilbert-style proof system typeclasses
│   ├── LogicalEquivalence.lean-- Abstract logical equivalence
│   ├── Theorems.lean          -- Barrel import for all theorem modules
│   ├── Theorems/
│   │   ├── Combinators.lean   -- S, K, B combinators and imp_trans
│   │   ├── BigConj.lean       -- Big conjunction theorems
│   │   ├── Propositional/     -- Propositional logic theorems
│   │   │   ├── Core.lean      -- LEM, DNE, EFQ, conjunction elimination
│   │   │   └── Connectives.lean-- Contraposition, De Morgan, etc.
│   │   ├── Modal/             -- Modal logic theorems
│   │   │   ├── Basic.lean     -- Box monotonicity, box distribution
│   │   │   └── S5.lean        -- S5-specific derived theorems
│   │   └── Temporal/          -- Temporal logic theorems
│   │       └── TemporalDerived.lean -- G/H distribution, transitivity
│   └── Metalogic/
│       ├── Consistency.lean       -- Consistency and maximal consistency
│       └── DeductionHelpers.lean  -- Deduction theorem helpers
├── Data/                      -- General-purpose data structures
│   ├── HasFresh.lean          -- Fresh name generation
│   ├── Relation.lean          -- Relation utilities
│   ├── ListHelpers.lean       -- List helper lemmas
│   ├── RelatesInSteps.lean    -- Step-indexed relations
│   ├── DecidableEqZero.lean   -- Decidable equality to zero
│   ├── StackTape.lean         -- Stack/tape data structures
│   └── BiTape.lean            -- Bidirectional tape
├── Combinatorics/             -- Combinatorial results
│   └── InfiniteGraphRamsey.lean
├── Control/                   -- Control flow abstractions
│   └── Monad/
│       └── Free/              -- Free monads
├── Semantics/                 -- Operational semantics
│   ├── LTS/                   -- Labelled transition systems
│   │   └── LTSCat/           -- LTS category theory
│   └── FLTS/                  -- Functional LTS
├── Syntax/                    -- Abstract syntax infrastructure
│   ├── HasAlphaEquiv.lean     -- Alpha equivalence typeclass
│   ├── HasWellFormed.lean     -- Well-formedness typeclass
│   ├── HasSubstitution.lean   -- Substitution typeclass
│   ├── Context.lean           -- Contexts
│   └── Congruence.lean        -- Congruence relations
└── Lint/                      -- Custom linting rules
    └── Basic.lean
```

## Logics/ Dependency Hierarchy

The `Logics/` directory contains specific logic formalizations. Each logic instantiates the
abstract infrastructure from `Foundations/Logic/`.

```
Foundations/Logic  (abstract infrastructure)
       │
       ▼
  Propositional    (propositional logic: formulas, proof system, metalogic)
       │
       ├──────────────────┐
       ▼                  ▼
     Modal            Temporal     (extend propositional with □ or U/S)
       │                  │
       └──────┬───────────┘
              ▼
           Bimodal               (combines modal + temporal, BX axiom system)
```

Other logics:
- `Logics/HML/` -- Hennessy-Milner Logic (for process equivalence)
- `Logics/LinearLogic/CLL/` -- Classical Linear Logic (sequent calculus, cut elimination, phase semantics)

## Namespace Convention

The `Cslib.Logic` namespace spans both `Foundations/Logic/` and `Logics/`:

| Namespace | Source Directory |
|-----------|-----------------|
| `Cslib.Logic.Axioms` | `Foundations/Logic/Axioms.lean` |
| `Cslib.Logic.Propositional` | `Logics/Propositional/` |
| `Cslib.Logic.Modal` | `Logics/Modal/` |
| `Cslib.Logic.Temporal` | `Logics/Temporal/` |
| `Cslib.Logic.Bimodal` | `Logics/Bimodal/` |

Infrastructure lives in `Foundations/`, specific logics live in `Logics/`, and both share the
`Cslib.Logic` namespace prefix.

## Module Placement Guide

When adding a new module, place it according to its role:

| What you're adding | Where it goes |
|--------------------|---------------|
| Abstract typeclass or proof system | `Foundations/Logic/` |
| General data structure or utility | `Foundations/Data/` |
| Operational semantics / LTS | `Foundations/Semantics/LTS/` |
| Abstract syntax (alpha-equiv, substitution) | `Foundations/Syntax/` |
| Specific logic formalization | `Logics/{LogicName}/` |
| Programming language / process calculus | `Languages/{LanguageName}/` |
| Algorithm formalization | `Algorithms/` |
| Tests | `CslibTests/` |

For new top-level directories or major structural additions, coordinate on Zulip first.
See `domain/contributing-standards.md` for the full coordination policy.
