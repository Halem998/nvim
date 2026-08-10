# Research Report: Task #777

**Task**: 777 - Hard-mode research: more effort, higher quality and verification standards
**Started**: 2026-07-03T00:00:00Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: 3-6 hours
**Dependencies**: None (companion to task 772 implementation leg, task 774 planning leg)
**Sources/Inputs**:
- Codebase: `.claude/skills/skill-researcher-hard/SKILL.md`, `.claude/agents/general-research-hard-agent.md`,
  `.claude/agents/cslib-research-hard-agent.md` (+ `.claude/extensions/cslib/agents/`),
  `.claude/extensions/lean/agents/lean-research-hard-agent.md`,
  `.claude/context/contracts/*.md`, `.claude/skills/skill-orchestrate-hard/SKILL.md`,
  `.claude/context/index.json`, `.claude/scripts/validate-artifact.sh`
- Sibling tasks: 772 (implementation leg), 774 (planning leg) — read for precedent/pattern only
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three H4-related behaviors the task wants strengthened (source-coverage bar, contradiction
  resolution, claim verification with confidence levels) currently exist only as **hand-copied
  prose duplicated across three agent files** (`general-research-hard-agent.md`,
  `cslib-research-hard-agent.md`, `lean-research-hard-agent.md`), each with slightly different
  wording. Unlike H2 (anti-analysis), H3 (reference-grounding), H6 (convergence), H7 (territory),
  and H9 (wrap-up), **H4 has no dedicated contract file** in `.claude/context/contracts/`. This is
  the single biggest structural gap and the direct answer to "WHERE to encode enforceable
  contract language."
- The existing H4 prose (Stage 4.5 in each agent) is a checklist of *questions to ask*
  ("Is there a documented counterargument?", "Are citations backed?") but has no enforceable bar
  analogous to H2's 4-element Defect Bar or forced structure — an agent can satisfy it by writing
  a few free-text sentences under `## Adversarial Self-Verification` and move on.
- The only automated verification gate that touches H4 output is in `skill-orchestrate-hard`
  (Stage: `researched`), and it is **purely structural**: `grep -q "## Adversarial
  Self-Verification"` — presence of the heading, not substance of the content. A report with an
  empty or perfunctory section passes.
- There is currently **no source-coverage minimum** anywhere (no "N independent sources" rule),
  **no contradiction-resolution protocol** (H3's "Authoritative resolution" only ranks source
  types, it does not require resolving conflicts before reporting), and **no confidence-level
  taxonomy** (agents are told to "flag uncertain claims" but given no scale or format).
- Recommended approach: create a new dedicated contract file
  `.claude/context/contracts/adversarial-verification.md` (matching the existing 1:1 mapping of
  H-technique → contract file), extend `reference-grounding.md` (H3) with per-tier minimum
  source-coverage requirements, and replace the duplicated Stage 4.5 prose in all three
  research-hard agents with a pointer to the new contract plus a required, machine-checkable
  **Claim Verification Table**. This mirrors exactly how H2's Defect Bar and H9's Handoff JSON
  Schema are encoded — structured tables/schemas, not free prose — and is directly analogous to
  the pattern task 772/774 use for their own H-contracts.

## Context & Scope

Task 777 is the **research leg** of a three-leg `--hard` strengthening effort: task 772 hardens the
implementation leg (orchestrator becomes a pure per-phase dispatcher), task 774 hardens the
planning leg (phase sizing + skeleton/follow-up decomposition), and this task hardens the research
leg (coverage, consistency, verification). Scope is explicitly hard-mode only — standard
`skill-researcher` / `general-research-agent` must not change.

Investigated:
1. `skill-researcher-hard` (dispatch wrapper, postflight logging)
2. `general-research-hard-agent.md` (core agent, Stage 4.5 H4 logic)
3. `cslib-research-hard-agent.md` and `lean-research-hard-agent.md` (domain variants with their
   own copies of the same Stage 4.5 prose)
4. `.claude/context/contracts/` (existing H2/H3/H6/H7/H9 contract files — H4 is absent)
5. How `build_hard_mode_prompt_context` injects contracts (only used for **implementation**
   dispatch in `skill-orchestrate-hard`, not for research dispatch)
6. The H4 gate in `skill-orchestrate-hard` (structural heading-presence check only)
7. `.claude/context/index.json` (per-contract `load_when.agents` entries — needed for any new file)

## Findings

### Codebase Patterns

**Contract file convention** (`.claude/context/contracts/*.md`): each file implements exactly one
H-technique, is referenced by name in agent `## Context References` as "MANDATORY", and encodes
concrete, checkable bars rather than general advice:
- `anti-analysis.md` (H2): Read Budget (numeric %), Forbidden Conclusions (6 enumerated
  unacceptable outputs), Defect Bar (4 required elements), Settled-Design Preamble Protocol.
- `reference-grounding.md` (H3): three tiers, each with a **required table format**
  (source-to-implementation mapping), explicit tier-selection rule, "Authoritative resolution"
  precedence for Tier 2 (official > community, current version > cached knowledge) but this is a
  *source ranking*, not a *conflict resolution requirement* — it never says a report must resolve
  a detected contradiction before shipping.
- `convergence.md` (H6), `territory.md` (H7), `wrap-up.md` (H9): each defines a JSON schema or
  numeric threshold (three-strikes count, owned/read-only file lists, 400-token handoff schema)
  that a script or orchestrator can grep/parse — this is what makes them "enforceable" rather than
  advisory.

**H4 is the outlier**: it is named in `skill-researcher-hard`'s description and in
`skill-orchestrate-hard`'s description ("H4 Adversarial Verification Gate"), and referenced as
"Adversarial self-verification (H4)" in three separate agent files, but **no
`.claude/context/contracts/adversarial-verification.md` exists**. Each agent (general/cslib/lean)
independently hand-writes its own Stage 4.5 section:

```
### Stage 4.5: Adversarial Self-Verification (H4)
1. Challenge each recommendation: ...
2. Verify citations: ...
3. Check for analysis-only conclusions: ...
4. Identify uncertain claims: ...
```

The three copies differ only in domain-specific item 4/5 (cslib adds "reuse completeness" and
"zero-debt compliance"; lean adds "type signature confirmed via lean_hover_info"). The
*general-purpose rigor logic task 777 wants strengthened* (source coverage, contradiction
resolution, confidence levels) is exactly the part that is currently shared prose and would need
to be edited in three places if left as-is — a direct violation of the "maintenance note: changes
should be mirrored" pattern already flagged as fragile in `skill-researcher-hard`'s own docstring
("Maintenance note: changes to skill-researcher postflight should be mirrored here").

**H4 gate enforcement is structural-only**: in `skill-orchestrate-hard/SKILL.md`, State
`researched`:
```bash
if grep -q "## Adversarial Self-Verification" "$research_path"; then
  adversarial_verified=true
else
  # dispatch a focused verification pass
fi
```
This only checks the heading exists. A report with `## Adversarial Self-Verification\n\nLooks
good.` passes the gate. There is no check for a populated claim table, confidence markers, or
resolved contradictions. `.claude/scripts/validate-artifact.sh` (generic report/plan validator)
has no hard-mode-specific checks at all — confirmed by grep, zero matches for
"Adversarial|defect|H2|H3|H4|anti-analysis".

**`build_hard_mode_prompt_context`** (in `skill-orchestrate-hard/SKILL.md`) is **only used for
implementation dispatch** (`Implement phase $next_phase...`), never for research dispatch. Research
dispatch prompts are a single plain sentence (`"Research task $task_number: $DESCRIPTION"`) with no
injected contract-slot text; all H4/H3/H2 enforcement for research currently comes entirely from
the dispatched agent's own file (`general-research-hard-agent.md` etc.) reading its
`## Context References` — there is no orchestrator-side injection mechanism for research the way
there is for implementation. This means the contract-file approach (agent reads
`@.claude/context/contracts/adversarial-verification.md`) is the *only* viable enforcement surface
for research-hard; there is no parallel `build_hard_research_prompt_context` to extend.

**No source-coverage minimum exists anywhere.** Neither H3 nor H4 prose states a required number
of independent sources before a claim may be treated as settled. The base (non-hard)
`general-research-agent.md` Search Priority list (local codebase > context files > web search >
web fetch) is an *ordering*, not a *coverage* requirement, and hard mode does not add one.

**No confidence-level taxonomy exists.** Agents are told to "flag uncertain claims" and "list
uncertain claims with confidence levels" but no contract defines what confidence levels are
available or what evidence justifies each (mirrors the gap H2 avoided by defining an explicit
4-element Defect Bar rather than saying "flag bad designs").

### External Resources

Not applicable — this is a meta task modifying the `.claude/` agent system itself; no external
library/API research was needed. (Consistent with H3 Tier 3 / graceful degradation: "when no
reference materials are available... proceeding from first principles" — here the codebase itself
is the specification, per the sibling-task 772/774 precedent for encoding H-contracts.)

### Recommendations

**1. New contract file: `.claude/context/contracts/adversarial-verification.md` (H4)**

Mirrors the anti-analysis.md structure. Concrete sections to include:

- **Claim Verification Bar** (4-element, directly modeled on H2's Defect Bar): a load-bearing
  claim may ship as VERIFIED only when ALL of: (a) claim stated verbatim, (b) concrete source
  quoted/cited OR a tested counterexample, (c) verification method named (e.g. "grep confirmed 3
  call sites", "WebFetch of official docs v2.4"), (d) confidence level assigned. Missing any
  element downgrades the claim to UNVERIFIED and it must be explicitly caveated, not presented as
  settled.
- **Confidence Level Taxonomy**: High (2+ independent sources agree, or a directly-read
  authoritative source with no conflicting evidence found), Medium (single authoritative source,
  not cross-checked, or code pattern confirmed in only one location), Low (inferred from
  instinct/convention, not directly verified) — every load-bearing claim in the report must carry
  one of these three tags.
- **Contradiction Resolution Protocol**: when independent sources disagree, the agent MUST attempt
  resolution using precedence rules before writing the finding (official docs > community posts;
  current code > stale comments/docs; test suite behavior > assumed behavior — reusing H3's
  existing "Authoritative resolution" ranking as the resolution mechanism, not just a source
  ranking). Only if resolution genuinely fails may the report state
  `UNRESOLVED CONTRADICTION: <A> vs <B>` — but even then it must state the downstream risk and
  which further check would resolve it. "Reporting a contradiction flatly" (juxtaposing two facts
  with no resolution attempt) is a forbidden output.
- **Forbidden Verification Outputs** (modeled on H2's Forbidden Conclusions list): e.g. "sources
  agree" without naming which sources; "well documented" / "commonly known" without a citation;
  "no conflicting information found" without stating what was searched and how many independent
  sources were checked; a contradiction noted with no resolution attempt.
- **Domain Specialization** section (matching the pattern in anti-analysis.md /
  reference-grounding.md) noting where cslib's BibKey verification and lean's
  `lean_hover_info`-confirmed type signatures plug in as domain-specific verification methods
  under the shared Claim Verification Bar.

**2. Extend `.claude/context/contracts/reference-grounding.md` (H3) with source-coverage minimums**

Add a subsection per tier (this is the natural home for coverage requirements since tiers already
define what counts as a source):
- Tier 1: primary source citation is mandatory; when the claim is safety/design-critical, a second
  corroborating source (another paper, or a second passage in the same source) is required — no
  single-passage conclusions for load-bearing theorems.
- Tier 2: official docs is Tier 2's minimum; add "if official docs are ambiguous or silent, a
  second independent source (changelog, source code, or a second doc page) is required before
  concluding" — i.e. explicitly forbid single-page/single-search conclusions.
- Tier 3: existing implementation + test suite both required (already implied by "test suite as
  specification" but not stated as a *minimum count* — make it explicit: reading the
  implementation alone, without checking its test suite, is insufficient).
- Add a tier-agnostic rule for codebase-pattern claims (common in `meta` task type research, which
  this very task is an instance of): a pattern claim ("X is the convention") requires confirmation
  at 2+ independent call sites/files, not one.

**3. Update `.claude/skills/skill-researcher-hard/SKILL.md`**
- Add `.claude/context/contracts/adversarial-verification.md` to `## Context References` as
  MANDATORY (alongside the existing anti-analysis.md and reference-grounding.md references).
- Stage 6a (`validate-artifact.sh` call): optionally extend with a lightweight grep-based check for
  the Claim Verification Table header (`| Claim | Source/Counterexample | Verification Method |
  Confidence |`) analogous to the existing report-format validation, non-blocking (`|| true`) to
  match current error-handling conventions. This is a secondary/optional hardening — primary
  enforcement lives in the agent's own contract-reading discipline, matching how H2/H3 work today
  (no script currently enforces the Defect Bar either; enforcement is agent self-compliance plus
  the orchestrator's structural gate).

**4. Update the three research-hard agent files**
(`.claude/agents/general-research-hard-agent.md`, `.claude/agents/cslib-research-hard-agent.md` /
`.claude/extensions/cslib/agents/cslib-research-hard-agent.md`,
`.claude/extensions/lean/agents/lean-research-hard-agent.md` — note `general-research-hard-agent.md`
also has a duplicate under `.claude/extensions/core/agents/`, keep both in sync as today):
- Add `@.claude/context/contracts/adversarial-verification.md` to `## Context References` as
  MANDATORY, replacing the ad hoc Stage 4.5 checklist prose with: "Before Stage 4.5, read
  `adversarial-verification.md` and internalize the Claim Verification Bar, Confidence Level
  Taxonomy, and Contradiction Resolution Protocol."
- Stage 3 (`Execute Primary Searches`): add an explicit **no-single-source-conclusion** rule
  cross-referencing the new H3 coverage minimums — "Do not proceed to Stage 4 synthesis with a
  load-bearing claim backed by only one search result or one source; run at least one
  cross-checking search/read before concluding."
- Stage 4.5: replace the free-text checklist with a required **Claim Verification Table** as the
  primary artifact of this stage (structured, matching H3's mapping-table pattern):

  | Claim | Source/Counterexample | Verification Method | Confidence |
  |-------|-----------------------|----------------------|------------|

  plus a **Contradiction Log** subsection (only present when contradictions were found) recording
  each conflict and its resolution (or, rarely, `UNRESOLVED` with stated risk).
- Domain agents keep their existing specializations (cslib's BibKey protocol, lean's
  `lean_hover_info` confirmation) as the "Verification Method" column content for their domain,
  rather than as separate duplicated Stage 4.5 logic — this removes the 3-way prose duplication
  while preserving domain-specific verification mechanics.

**5. `.claude/context/index.json`**: add an entry for the new `contracts/adversarial-verification.md`
file (mirroring the existing `anti-analysis.md` entry structure) with
`load_when.agents: ["general-research-hard-agent", "cslib-research-hard-agent",
"lean-research-hard-agent"]`, `subdomain: "contracts"`.

**6. Secondary/optional — `skill-orchestrate-hard` H4 gate**: currently `grep -q "##
Adversarial Self-Verification"`. Could be strengthened to also require the Claim Verification
Table header be present (`grep -q "| Claim | Source/Counterexample"`), but this file is the
*consumer* of research-hard output, not itself a "research" skill/agent, so it is outside the
literal scope stated in the task ("Scope: hard-mode only; do NOT change standard research" — this
file is hard-mode but not research). Flagged here for completeness/consistency but treated as
optional, lower-priority in the implementation plan; the primary deliverable (contract file +
agent Stage 4.5 rewrite) achieves the task's goals without touching the orchestrator.

## Decisions

- **New file over extending an existing one for H4**: `adversarial-verification.md` follows the
  established 1-technique-1-file convention (H2→anti-analysis.md, H3→reference-grounding.md,
  H6→convergence.md, H7→territory.md, H9→wrap-up.md); H4 is the only H-technique referenced by
  name in three agent files and one skill description without a backing contract file. Extending
  `reference-grounding.md` instead was considered and rejected because H4's concerns (claim
  verification bar, confidence levels, contradiction resolution across *all* claims) are broader
  than H3's concern (source-to-implementation traceability for reference materials specifically);
  keeping them separate also matches the task's own framing ("extend the existing H4... and H3...").
- **Source-coverage minimums live in H3, not H4**: coverage is tier-dependent (what counts as an
  "independent source" differs for literature vs. docs vs. code), so it belongs with the tier
  definitions in `reference-grounding.md`; the H4 file cross-references it rather than duplicating.
- **Table-based enforcement, not prose**: matching every existing enforceable contract (Defect Bar,
  mapping tables, handoff JSON schema, territory JSON), the new Claim Verification Table and
  Contradiction Log are structured formats that a future script (or the existing orchestrate-hard
  grep gate) can check mechanically, not free paragraphs.
- **No new orchestrator injection mechanism needed**: unlike implementation dispatch
  (`build_hard_mode_prompt_context`), research dispatch has no equivalent function and does not
  need one — the contract-file + agent-file approach is sufficient and consistent with how H2/H3
  already work for research today.

## Risks & Mitigations

- **Risk**: Editing three agent files (general/cslib/lean) plus two extension-directory mirrors
  (`.claude/extensions/core/agents/general-research-hard-agent.md`,
  `.claude/extensions/cslib/agents/`) risks drift if only some copies are updated. **Mitigation**:
  implementation plan should explicitly enumerate all file pairs found in this research (confirmed
  via grep: `.claude/agents/general-research-hard-agent.md` +
  `.claude/extensions/core/agents/general-research-hard-agent.md` are duplicates; similarly for
  cslib) and update both in the same phase.
- **Risk**: Raising the rigor bar increases token cost per hard-mode research dispatch (more
  searches, structured tables). **Mitigation**: this is consistent with the already-documented
  ~3-5x cost multiplier for `--hard`; no new cost-model documentation change needed beyond noting
  research-hard now front-loads more searches (already implied by "raise the effort/coverage bar"
  in the task description).
- **Risk**: A stricter contradiction-resolution requirement could cause agents to stall (mini
  analysis-paralysis) trying to resolve genuinely unresolvable conflicts. **Mitigation**: the
  contract explicitly permits `UNRESOLVED CONTRADICTION` as a valid terminal state (not a forbidden
  output) provided the risk and next-check are stated — this keeps H2's anti-analysis spirit intact
  for the new H4 contract.

## Context Extension Recommendations

- **Topic**: H4 contract centralization
- **Gap**: `.claude/context/contracts/` has no file for H4 despite H4 being referenced by name in
  three agent files and `skill-orchestrate-hard`'s description; this is the direct cause of the
  prose-duplication and weak-enforceability problems this task is meant to fix.
- **Recommendation**: create `.claude/context/contracts/adversarial-verification.md` per the
  Recommendations section above, and register it in `.claude/context/index.json`.

## Appendix

Search queries / greps used:
- `grep -rn "build_hard_mode_prompt_context"` — confirmed injection mechanism is
  implementation-only, not used for research dispatch.
- `grep -rln "Adversarial Self-Verification"` — found 6 files (3 agent files ×2 copies each for
  general/cslib, plus lean, plus 2 copies of skill-orchestrate-hard), confirming duplication.
  Note: `general-research-hard-agent.md` appears in both `.claude/agents/` and
  `.claude/extensions/core/agents/`; `cslib-research-hard-agent.md` similarly in
  `.claude/agents/` and `.claude/extensions/cslib/agents/`. `lean-research-hard-agent.md` only
  under `.claude/extensions/lean/agents/`.
- `grep -n "Adversarial\|defect\|H2\|H3\|H4\|anti-analysis" .claude/scripts/validate-artifact.sh`
  — zero matches, confirming no script-level enforcement of hard-mode research contracts exists.
- `jq -r '.entries[] | select(.path | test("contracts/")) | .path' .claude/context/index.json` —
  listed the 5 existing contract files (anti-analysis, reference-grounding, convergence,
  territory, wrap-up); confirmed adversarial-verification.md is absent.
- Read sibling task descriptions (772, 774) from `specs/state.json` for precedent/consistency only
  (not as authoritative sources for this task's own findings — both are still `not_started` at time
  of this research, so no completed-artifact precedent to cite yet).
