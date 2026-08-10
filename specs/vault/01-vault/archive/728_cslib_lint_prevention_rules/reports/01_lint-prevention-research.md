# Task 728: CSLib Lint Prevention Rules

## Problem

`lake lint` environment linters are NOT in the PR CI pipeline (`lean_action_ci.yml`). They
only run in a weekly Monday cron (`weekly-lints.yml`) that posts to Zulip but does not block
PRs. This means cslib agents can write code that passes all CI checks while silently
introducing lint errors that accumulate over time.

Tasks 208-213 fixed 850+ lint errors that had accumulated. Preventing recurrence requires
agent-level enforcement since the CI gap is upstream.

## CI Pipeline Gap

**What PR CI runs** (blocks PRs):
- `lake build --wfail --iofail` (syntax linters, warnings-as-errors)
- `lake exe mk_all --check --module` (import verification)
- `lake exe checkInitImports` (init import check)
- `lint-style-action` (text-level style linters)

**What PR CI does NOT run**:
- `lake lint` (environment linters — the 7 categories below)
- `lake shake` (dependency analysis — commented out)

**What the weekly cron runs** (`weekly-lints.yml`, Monday 05:00 UTC):
- Enables `weak.linter.weeklyLintSet = true` in lakefile.toml, then runs `lake build`
- This catches additional build-time linter warnings, posts results to Zulip
- Does NOT block PRs (informational only)

## The 7 Prevention Rules

These should be added to cslib-implementation-agent as hard requirements, and to
cslib-research-agent as awareness items for plan recommendations.

### Rule 1: Mandatory Docstrings (prevents docBlame)

Every new `def`, `theorem`, `lemma`, `instance`, `structure`, and `inductive` declaration
MUST have a `/-- ... -/` docstring. One sentence minimum. Structure fields also need
docstrings.

**Style guide** (from existing codebase):
- Theorems/lemmas: backtick-quoted formal statement + English description
  ```lean
  /-- `G` distributes over `→`. -/
  theorem gDistribution ...
  ```
- Definitions: brief English description of purpose
  ```lean
  /-- The canonical frame for the bimodal logic. -/
  def canonicalFrame ...
  ```
- Structure fields: very short descriptions
  ```lean
  /-- The underlying accessibility relation. -/
  rel : W → W → Prop
  ```

### Rule 2: Correct Declaration Keywords (prevents defLemma)

Prop-valued declarations MUST use `lemma` or `theorem`, never `def`. Convention:
- `theorem` for major named results (completeness, soundness, named lemmas from papers)
- `lemma` for supporting results

`abbrev` is acceptable only for true definitional abbreviations, not for Prop-valued results.

If a declaration has `@[reducible]` and is being changed to `lemma`/`theorem`, remove the
`@[reducible]` attribute (it's meaningless on lemma/theorem).

### Rule 3: CamelCase Names (prevents defsWithUnderscore)

Declaration names MUST use lowerCamelCase (no underscores). Type names use UpperCamelCase.

**Common violation patterns to avoid**:
- `G_distribution` → `gDistribution`
- `lemma_2_4` → `lemma24`
- `temporally_coherent` → `temporallyCoherent`
- `h_impl` (field) → `hImpl`
- `ExistsTask_past` → `ExistsTaskPast`

### Rule 4: Verify @[simp] Before Adding (prevents simpNF)

Before adding `@[simp]` to a lemma, verify:
1. The LHS does not already simplify to something else (check with `lean_multi_attempt`
   using `simp` on the LHS)
2. `simp` cannot already prove the lemma outright

If the LHS involves `abbrev`-defined connectives (like `neg`, `diamond`, `and`), these
unfold transparently. Simp lemmas on the primitive constructors will fire on the LHS before
the derived lemma applies — making the `@[simp]` attribute redundant.

### Rule 5: Minimal Section Variables (prevents unusedSectionVars)

Section variables should only include what's needed by the declarations in that section. If
a variable (especially typeclass instances like `[DecidableEq Atom]`) is only needed by some
declarations:
- Use `omit [InstanceType]` in subsections for declarations that don't need it
- Or split into separate sections

The `omit` pattern is already used in 11+ places across CSLib.

### Rule 6: Namespace Instances (prevents topNamespace)

When writing `instance` declarations inside a `section`, they MUST be wrapped in an explicit
`namespace`. Auto-generated instance names without a namespace create topNamespace errors.

```lean
-- BAD: instance at top level of section
section BimodalInstances
instance : SomeClass (Formula Atom) where ...
end BimodalInstances

-- GOOD: wrapped in namespace
namespace Cslib.Logics.Bimodal.ProofSystem
section BimodalInstances
instance : SomeClass (Formula Atom) where ...
end BimodalInstances
end Cslib.Logics.Bimodal.ProofSystem
```

### Rule 7: No Redundant Qualified Names (prevents dupNamespace)

Inside a namespace, do not use the namespace as a prefix in declaration names.

```lean
-- BAD: creates Temporal.Temporal.Deriv
namespace Cslib.Logic.Temporal
def Temporal.Deriv := ...

-- GOOD: just use the short name
namespace Cslib.Logic.Temporal
def Deriv := ...
```

For `structure` declarations that share the name of their enclosing namespace (e.g.,
`structure Chronicle` in `namespace ...Chronicle`), use
`set_option linter.dupNamespace false in` before the declaration.

## Implementation Plan

### Phase 1: Agent Rules File

Create `.claude/extensions/cslib/context/standards/lint-prevention-rules.md` containing
the 7 rules above. Add to `index.json` with:
```json
{
  "path": ".claude/extensions/cslib/context/standards/lint-prevention-rules.md",
  "line_count": 100,
  "load_when": {
    "agents": ["cslib-implementation-agent", "cslib-implementation-hard-agent"],
    "task_types": ["cslib"]
  }
}
```

### Phase 2: Agent Instruction Update

Add to cslib-implementation-agent's system prompt (after the CI verification section):
```
## Lint Prevention (Mandatory)
Load and follow @.claude/extensions/cslib/context/standards/lint-prevention-rules.md
for every declaration you write. These rules prevent environment lint errors that are
not caught by PR CI but accumulate over time.
```

### Phase 3: Verification Step Enhancement

Update the CI verification pipeline in the agent instructions to include a targeted
lint check after implementation:

```
After lake build passes, run:
  lake lint 2>&1 | grep -E "docBlame|defLemma|defsWithUnderscore|simpNF|unusedSectionVars|topNamespace|dupNamespace"

If any warnings appear in files you modified, fix them before reporting completion.
```

This is faster than full `lake lint` because the agent only needs to check its own files.

### Phase 4: Research Agent Awareness

Add a lighter version of the rules to cslib-research-agent so that research reports
and plan recommendations account for lint requirements from the start.

## Estimated Effort

- Phase 1: 1 file creation (~100 lines)
- Phase 2: 1 agent file edit (~5 lines added)
- Phase 3: 1 agent file edit (~10 lines added)
- Phase 4: 1 agent file edit (~3 lines added)

Total: ~30 minutes of implementation work. Low risk — additive changes only.
