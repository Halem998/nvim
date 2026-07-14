# CSLib Lint Prevention Rules

Environment linters (`lake lint`) are **NOT** in the PR CI pipeline -- they only run in a
weekly Monday cron (`weekly-lints.yml`). This means code can pass all PR CI checks while
silently introducing lint errors that accumulate over time (tasks 208-213 fixed 850+ such
errors). Follow these 7 rules for every declaration you write.

## Rule 1: Mandatory Docstrings (prevents docBlame)

Every `def`, `theorem`, `lemma`, `instance`, `structure`, and `inductive` MUST have a
`/-- ... -/` docstring. Structure fields also need docstrings.

```lean
-- GOOD
/-- The canonical frame for the bimodal logic. -/
def canonicalFrame : Frame := ...

-- BAD (no docstring)
def canonicalFrame : Frame := ...
```

## Rule 2: Correct Declaration Keywords (prevents defLemma)

Prop-valued declarations MUST use `lemma` or `theorem`, never `def`.
- `theorem` for major named results
- `lemma` for supporting results
- Remove `@[reducible]` when changing `def` to `lemma`/`theorem`

```lean
-- GOOD
/-- `G` distributes over `→`. -/
theorem gDistribution : ... := ...

-- BAD
def gDistribution : ... := ...
```

## Rule 3: CamelCase Names (prevents defsWithUnderscore)

Declaration names MUST use lowerCamelCase (no underscores). Type names use UpperCamelCase.

```lean
-- GOOD: gDistribution, lemma24, temporallyCoherent, hImpl
-- BAD:  G_distribution, lemma_2_4, temporally_coherent, h_impl
```

## Rule 4: Verify @[simp] Before Adding (prevents simpNF)

Before adding `@[simp]`, verify the LHS does not already simplify to something else.
Use `lean_multi_attempt` with `simp` on the LHS. If the LHS involves `abbrev`-defined
connectives (like `neg`, `diamond`, `and`), these unfold transparently and simp lemmas on
primitive constructors may fire first, making the `@[simp]` redundant.

## Rule 5: Minimal Section Variables (prevents unusedSectionVars)

Section variables should only include what all declarations in that section need. Use `omit`
for declarations that don't need a particular variable:

```lean
variable [DecidableEq Atom]
omit [DecidableEq Atom] in
theorem myTheorem : ...  -- does not need DecidableEq
```

## Rule 6: Namespace Instances (prevents topNamespace)

`instance` declarations inside a `section` MUST be wrapped in an explicit `namespace`:

```lean
-- GOOD
namespace Cslib.Logics.Bimodal
section BimodalInstances
instance : SomeClass (Formula Atom) where ...
end BimodalInstances
end Cslib.Logics.Bimodal

-- BAD (instance at top level of section without namespace)
section BimodalInstances
instance : SomeClass (Formula Atom) where ...
end BimodalInstances
```

## Rule 7: No Redundant Qualified Names (prevents dupNamespace)

Inside a namespace, do not use the namespace as a prefix in declaration names:

```lean
-- GOOD
namespace Cslib.Logic.Temporal
def Deriv := ...

-- BAD (creates Temporal.Temporal.Deriv)
namespace Cslib.Logic.Temporal
def Temporal.Deriv := ...
```

For `structure` declarations sharing the name of their enclosing namespace, use:
`set_option linter.dupNamespace false in`
