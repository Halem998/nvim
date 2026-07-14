# CSLib Notation Conventions

Overview of notation for common concepts across the CSLib library. Derived from NOTATION.md.

## Equivalences

These are shared across notation options:

| Concept | Notation |
|---------|----------|
| Alpha equivalence | `m =α n` |
| Bisimilarity | `p ~[lts] q` (p is bisimilar to q in the LTS `lts`) |

## Operational Semantics: Three Notation Options

CSLib files may use one of three notation options for operational semantics. **Check existing
notation in a file before adding new notation** to ensure consistency within the file.

### Option A

Uses an extra arrowhead to denote reflexive and transitive closure.

**When there is only one semantics**:

| Concept | Notation |
|---------|----------|
| Reduction | `m → n` |
| Multi-step reduction (possibly zero) | `m ↠ n` |
| Transition | `p [μ]→ q` (μ is a transition label) |
| Multi-step transition (possibly zero) | `p [μs]↠ q` (μs is a list of labels) |
| Saturated transitions | `p [μ]⇒ q` |
| Multi-step saturated transitions | `p [μs]➾ q` |

**When there are alternative semantics**, suffix the arrow with the relation/LTS name:
- `m →[cbv] n` -- reduction from m to n under the `cbv` reduction relation
- `p [μ]→[late] q` -- transition where `late` is an LTS

### Option B

As Option A, but uses `*` to denote reflexive and transitive closure.

| Concept | Notation |
|---------|----------|
| Multi-step reduction (possibly zero) | `m →* n` |
| Multi-step transition (possibly zero) | `p [μs]→* q` (μs is a list of labels) |
| Saturated transitions | `p [μ]⇒ q` |
| Multi-step saturated transitions | `p [μs]⇒* q` |

(Single-step reduction and transition are the same as Option A: `m → n`, `p [μ]→ q`)

### Option C

Like Option A, but uses triangle heads (`⭢`) to distinguish reduction arrows from Lean's
implication arrow (`→`).

**Example**: `(m ⭢ n) → (n ⭢ s) → (m ⯮ s)` -- the outer `→` is Lean implication, `⭢` is
reduction, `⯮` is multi-step reduction.

**When there is only one semantics**:

| Concept | Notation |
|---------|----------|
| Reduction | `m ⭢ n` |
| Multi-step reduction (possibly zero) | `m ⯮ n` |
| Transition | `p μ⭢ q` (μ is a transition label) |
| Multi-step transition (possibly zero) | `p [μs]⯮ q` (μs is a list of labels) |
| Saturated transitions | `p μ⇒ q` |
| Multi-step saturated transitions | `p μs➾ q` |

**When there are alternative semantics**, suffix without brackets:
- `m ⭢cbv n` -- reduction under the `cbv` relation
- `p μ⭢late q` -- transition where `late` is an LTS

## Determining Which Option a File Uses

Before contributing notation to an existing file:

1. Search for existing transition/reduction notation in the file
2. If you see `↠` (extra arrowhead) or `→*` (asterisk) or `⭢` (triangle head), that identifies
   the option
3. If the file already imports a notation scope, check the scope name
4. When in doubt, ask on Zulip or check `Logics/` modules for examples of each option in use

## Notation Reuse Policy

Before defining new notation:
1. Check whether an existing typeclass in `Foundations/` provides what you need
2. For operational semantics: check `Foundations/Semantics/LTS/` for existing LTS notation
3. For syntax concepts: check `Foundations/Syntax/` for `HasAlphaEquiv`, `HasSubstitution`, etc.
4. If new notation is needed and may apply to multiple types, create a typeclass rather than
   direct notation

See `patterns/reuse-first.md` for the typeclass reuse philosophy.
