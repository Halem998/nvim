# Reference Grounding Contract (H3)

This contract implements H3: Prior-Art Transcription Mandate. All hard-mode agents working
from reference materials (papers, documentation, specifications, existing code) must follow
this contract to prevent instinct-driven divergence from authoritative sources.

## Three Tiers of Reference Grounding

### Tier 1: Literature-Backed Domains

Applies when: task involves formalizing, implementing, or verifying claims from research
papers, textbooks, or any source with numbered propositions/theorems.

**Mandatory source-to-implementation mapping table** in any plan or report:

| Source | Proposition/Location | Local Identifier | Status |
|--------|---------------------|-----------------|--------|
| [Author YYYY] | Theorem 3.2 | `MyThm.main_result` | transcribed |
| [Author YYYY] | Lemma 4.1 | `MyLemma.helper` | pending |

**Transcription discipline**: The source wins over instinct. If the source proof uses
technique X and instinct suggests technique Y, implement X first. Instinct-driven deviations
require explicit justification citing a known error in the source or a domain mismatch.

**PDF-level citation**: Load-bearing claims must cite page and proposition number, not just
author and year. "Smith 2019" is insufficient; "Smith 2019, Proposition 3.2, p. 47" is required.

### Tier 2: Documentation-Backed Domains

Applies when: task involves implementing against official API documentation, language
specifications, library changelogs, or RFC-style standards.

**Link-to-implementation mapping**: For each implementation decision that could be questioned,
provide the canonical documentation URL or section reference that justifies it.

**Authoritative resolution**: Official docs over community posts, changelogs over assumed
behavior, current version docs over cached knowledge.

**Version pinning**: If documentation is version-specific, state the version explicitly.
"As of library v2.4.1: ..."

### Tier 3: Implementation-Backed Domains

Applies when: task involves extending, porting, or adapting existing code where the existing
implementation is the specification.

**Test suite as specification**: Existing passing tests define correctness. Modifications
must not break them. New behavior requires new tests before implementation.

**Reference code discipline**: Read the reference implementation before diverging from its
patterns. Pattern divergence without rationale is a defect.

## Source-Coverage Minimums

No single-source conclusions. Each tier has a minimum coverage bar a load-bearing claim
must clear before it may be presented as settled (see H4 `adversarial-verification.md`
Claim Verification Bar for how this feeds into confidence tagging):

- **Tier 1 (Literature-Backed)**: Primary source citation is mandatory. For safety- or
  design-critical claims, a second corroborating source (another passage, a second paper,
  or an independent proof-sketch) is required — no single-passage conclusions for
  load-bearing theorems.
- **Tier 2 (Documentation-Backed)**: Official docs are the minimum. If official docs are
  ambiguous or silent on the point, a second independent source (changelog, source code,
  or a second doc page) is required before concluding — single-page/single-search
  conclusions are forbidden.
- **Tier 3 (Implementation-Backed)**: Reading the reference implementation without
  checking its test suite is insufficient; both are required before a pattern claim ships.
- **Tier-agnostic codebase-pattern rule** (relevant to `meta` research): an "X is the
  convention" claim requires confirmation at 2+ independent call sites/files, not one.

## Tier Selection

The agent selects the applicable tier(s) based on the task description and available materials:

- Research paper mentioned in task → Tier 1 applies
- API/library mentioned in task → Tier 2 applies
- "Port X to Y" or "extend X" → Tier 3 applies
- Multiple tiers may apply simultaneously

When uncertain, apply the highest applicable tier (Tier 1 > Tier 2 > Tier 3).

## Graceful Degradation

When no reference materials are available (purely original work), this contract does not apply.
Document the absence: "No reference materials identified; proceeding from first principles."

## Domain Specialization

This is the domain-agnostic baseline. Extensions may override:

- **lean4**: Tier 1 mandatory with sorry-inventory tracking and paper-section cross-references
- **latex**: Tier 2 applies to LaTeX package documentation and CTAN references
- Extension overrides live in `.claude/extensions/{domain}/context/contracts/reference-grounding.md`
