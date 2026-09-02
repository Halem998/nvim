# Adversarial Verification Contract (H4) — CSLib Mirror Copy

This is the cslib-extension mirror copy of the core H4 contract. It exists to restore reach
for `cslib-research-hard-agent` in a cslib-loaded deploy, after core's index entry for this
path was correctly narrowed to list only agents that ship with core (see the source
mirror-entry precedent this file follows: `@.claude/extensions/lean/context/contracts/adversarial-verification.md`).

Unlike the lean4 parity copy, this file does **not** specialize into a single domain. The
deployed path `.claude/context/contracts/adversarial-verification.md` is shared: under the
extension loader's upsert-by-path merge (last extension processed for a given load/sync run
wins the whole entry, content included), any agent still auto-loading this path — today,
`cslib-research-hard-agent`; core's own standalone hard-mode research agent that originally
motivated this mirror is deleted, and core's own index entry for this path is now on-demand
only, so this collision concern no longer applies to a core agent — may transparently end
up reading *this* file instead of core's whenever `cslib` is loaded alongside (or in place
of) `core`. Content below the title is therefore kept identical to the canonical core file —
`@.claude/context/contracts/adversarial-verification.md` — rather than rewritten into a
cslib-only variant, so that collision does not silently narrow the contract for agents that
never asked for cslib-specific instructions. If cslib ever needs genuinely cslib-only H4
behavior, that content belongs in a new, additively-composed section rather than replacing
the shared baseline here.

## Claim Verification Bar

A load-bearing claim ships as **VERIFIED** only when ALL of the following hold:

1. **Claim stated verbatim**: The claim is written out as a specific, checkable statement
   (not paraphrased or gestured at).
2. **Concrete source quoted/cited OR a tested counterexample**: Either a direct quotation
   with citation (page/section/URL/file:line), or a counterexample that was actually
   executed/searched, not merely imagined.
3. **Verification method named**: The specific tool, search, or read that produced the
   evidence is named (e.g., `lean_hover_info` at `Foo.bar:12`, `WebFetch` on the official
   docs page, `Grep` across N call sites, BibKey lookup in `references.bib`).
4. **Confidence level assigned**: One of the three tags from the Confidence Level
   Taxonomy below.

Missing any of the four elements downgrades the claim to **UNVERIFIED**. An UNVERIFIED
claim must be explicitly caveated in the report — it may not be presented as settled.

This bar composes with the H3 Source-Coverage Minimums (see
`@.claude/context/contracts/reference-grounding.md#source-coverage-minimums`): element 2
of this bar is satisfied only when the coverage minimum for the claim's tier has already
been met (e.g., a Tier 2 claim resting on a single ambiguous doc page has not cleared H3
coverage, and therefore cannot be tagged High confidence here regardless of citation
formatting).

## Confidence Level Taxonomy

Every load-bearing claim in a research report carries exactly one confidence tag:

- **High**: 2+ independent sources agree, OR a directly-read authoritative source was
  checked with no conflicting evidence found (and the search for conflicts is itself
  documented — see Forbidden Verification Outputs).
- **Medium**: A single authoritative source, not cross-checked against a second source;
  or a pattern confirmed in only one location/call site.
- **Low**: Inferred from convention or instinct, not directly verified against a source
  or counterexample.

Confidence tags are not optional decoration — they are read downstream by planning and
implementation agents to decide which claims need re-verification before being acted on.

## Contradiction Resolution Protocol

When independent sources disagree on a load-bearing claim, attempt resolution via
precedence BEFORE writing the finding into the report. Reuse the H3 Authoritative
resolution ranking:

1. Official docs > community posts / forum answers
2. Current code > stale docs / stale comments
3. Test-suite behavior > assumed behavior
4. Directly-read primary source > secondary summary or instinct

Only if resolution genuinely fails after applying this ranking may the report state:

```
UNRESOLVED CONTRADICTION: <A> vs <B>
Downstream risk: <what breaks if the wrong side is trusted>
Resolving check: <the specific search/read that would resolve it, not yet performed>
```

`UNRESOLVED CONTRADICTION` is a valid terminal state — it is not a failure of the
research dispatch — provided the risk and the resolving check are both stated. Silently
picking one side of a contradiction without applying the precedence ranking, or omitting
the contradiction entirely, is a contract violation.

## Forbidden Verification Outputs

The following are NOT acceptable in a `## Adversarial Self-Verification` section:

1. **"Sources agree"** — without naming which sources.
2. **"Well documented" / "commonly known"** — without a citation.
3. **"No conflicting information found"** — without stating what was searched and how
   many independent sources were checked.
4. **A contradiction noted with no resolution attempt** — every contradiction must show
   the precedence ranking was applied before it may be marked `UNRESOLVED CONTRADICTION`.

These are verification-paralysis-adjacent signatures: they read as due diligence but
carry no checkable content. An agent that produces them has failed Stage 4.5.

## Domain Specialization

This is the domain-agnostic baseline. Domain-specific "Verification Method" values plug
into element 3 of the Claim Verification Bar without altering the bar itself:

- **cslib**: BibKey verification against `references.bib` (see
  `@.claude/extensions/cslib/context/project/cslib/standards/citation-conventions.md`)
  is a valid "Verification Method" value for literature claims; reuse-completeness
  (all 5 Reuse Check Protocol steps exhausted) and zero-debt compliance checks are
  additional cslib-specific verification passes layered on top of this bar.
- **lean4**: A `lean_hover_info`-confirmed type signature is a valid "Verification
  Method" value for Mathlib/CSLib API claims; `lean_local_search` confirmation is the
  minimum bar for "does X exist" claims (see
  `@.claude/extensions/lean/context/contracts/adversarial-verification.md` for the
  parity copy used by lean-only deployments).
- Extension overrides live in
  `.claude/extensions/{domain}/context/contracts/adversarial-verification.md`.

This file is the cslib-extension mirror copy; the canonical core file lives at
`@.claude/context/contracts/adversarial-verification.md`.
