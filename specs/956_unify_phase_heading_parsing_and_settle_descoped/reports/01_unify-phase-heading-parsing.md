# Research Report: Task #956

**Task**: 956 - Unify phase-heading parsing across all sites and settle the [DESCOPED] outcome
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: research only
**Dependencies**: None (builds directly on the prior reasoned-exclusions phase-outcome work)
**Sources/Inputs**: Codebase (agent-system/extensions/**, specs/**), git history of the prior reasoned-exclusions task's report/plan/summary
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The task's own framing conflicts with a very recent, deliberate, evidenced decision.** The
  prior "documented reasoned exclusions" work explicitly researched letter-suffixed sub-phases
  and **rejected** adding them: `plan-format.md`'s "Canonical phase-heading shape" section states
  in bold, "Letter-suffixed sub-phases (`3a`) are deliberately not supported by any consumer and
  must not be used. This is a decision, not an unimplemented feature." Task 956's WORK item (1)
  asks to reverse that decision. This is the central decision the plan must make explicitly, not
  silently override.
- **Recommended resolution for letters**: do NOT widen the grammar. Instead, make the two
  observed silent failures loud — a phase heading whose number token doesn't parse as the
  canonical `N` or `N.M` shape (e.g. `3a`) should surface as a visible, actionable
  non-conforming-heading warning/error at the same sites that already have an
  inconclusive-and-pass-through branch for "no conforming headings," rather than being silently
  dropped from a count or silently collapsed into a neighboring phase number. This satisfies WORK
  item (3) for phase *numbers*, generalized from the task's WORK item (3) for phase *statuses*,
  without reopening or duplicating the ~11-file blast radius the prior task closed. If the
  planner instead chooses to reverse the decision, the full site inventory and character-class
  constraints below are what an editor needs.
- **Recommended resolution for `[DESCOPED]`**: reject it, not admit it. `[COMPLETED WITH
  EXCLUSIONS]` already covers "every remaining item was decided, justified, and will not be
  revisited" — including the degenerate case where *all* remaining items in a phase are excluded
  (i.e., the whole phase is descoped). Admitting a fourth, semantically-overlapping marker would
  require re-touching every one of the same sites `[COMPLETED WITH EXCLUSIONS]` already wired,
  recreating the exact duplication problem the prior task exists to prevent. `DESCOPED` also
  satisfies the `[A-Z][A-Z ]*` character-class constraint, so it isn't technically forced either
  way — the choice is architectural, not mechanical.
- **The given FILE SCOPE is materially incomplete.** Three more files carry phase-heading regex
  sites that the prior task's own audit already named as consumers of this exact shape:
  `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md` (both
  Stage 5a), and `commands/task.md` (`/task --review`'s Step 3). None accept letter suffixes
  either, and any unify-the-sites effort that misses them recreates the drift this task exists to
  close.
- **A reusable shared-library precedent already exists in this codebase** for exactly this
  problem shape: `scripts/lib/task-reference-patterns.sh` is sourced by both its script and hook
  consumers so a pattern is defined once. The same approach (a new
  `scripts/lib/phase-heading-patterns.sh`) is the natural "single named anchor" for the three
  `.sh` files; the four `SKILL.md` files already establish a `source .claude/scripts/*.sh` /
  `bash .claude/scripts/*.sh` convention for their embedded bash and can source the same library.

## Context & Scope

The task asks to (1) unify ~19 phase-heading regex sites across 6+ files onto one canonical
pattern (deciding whether to admit `Phase Na` and `Phase Na.M`), (2) decide `[DESCOPED]`'s fate,
and (3) make any unrecognized phase marker a loud, inconclusive result rather than a silent zero.
Research scope: read every named file in FILE SCOPE plus every phase-heading regex site
transitively reachable from `plan-format.md`'s own "Consumer sites of this shape" documentation
(written by the immediately-prior task), and read that prior task's report/plan/summary in full
to understand what was already decided and why, since task 956 sits directly on top of that work.

## Findings

### 1. The prior decision this task must explicitly confront

`specs/924_documented_reasoned_exclusions_phase_outcome/` (the "documented reasoned exclusions"
task referenced in task 956's own description) researched this exact letter-suffix question and
rejected it, with this rationale (its report, "Findings" section 4):

> `skill-implementer-hard/SKILL.md`'s own comment explicitly documents that its
> decimal-admitting form was a deliberate fix for "N.1/N.2 sub-phase headings or sparse
> numbering" — i.e. decimal sub-phasing is an established, intentional pattern already in
> production use; letter suffixing has no such precedent anywhere and would be a genuinely new
> addition, not a gap-fill of an already-partially-supported case.

That task's plan then codified the rejection directly into `plan-format.md`:

```
**Letter-suffixed sub-phases (`3a`) are deliberately not supported by any consumer and must not
be used.** This is a decision, not an unimplemented feature: no script or agent in this codebase
recognizes a letter suffix on a phase number, and none is planned to. Decimal sub-phasing (`3.1`)
is the only supported sub-phase form.
```
(`agent-system/extensions/core/context/formats/plan-format.md`, "Canonical phase-heading shape"
subsection.)

Task 956's evidence (a real plan authored with `3a`/`3b`/`3c`/`4a`/`4b`) shows the decision was
violated in practice, not that it was wrong in principle — the plan that triggered this task
should not have used letters at all per the standing rule. The two live choices are:

- **(A) Hold the line, close the silent-failure gap instead** (recommended): keep letters
  unsupported, but make a non-conforming phase-number token (anything after `### Phase ` that
  isn't `[0-9]+` optionally followed by `.[0-9]+`) trigger the *same* loud,
  inconclusive-and-pass-through behavior `update-task-status.sh` already has for "zero conforming
  headings," rather than silently under-matching (the TOTAL/DONE undercount observed) or silently
  truncating (the `validate-artifact.sh` "Phase 3" x3 collapse observed). The offending plan gets
  fixed by renumbering `3a→3.1, 3b→3.2, 3c→3.3` etc., which is a small, mechanical, one-time edit
  to that plan file — not a system change.
- **(B) Reverse the decision**: admit `Phase Na` (and decide `Na.M`) as task 956 literally asks.
  This is a real, evidenced request (letters ARE observed in practice) but it means editing
  `plan-format.md`'s canonical-shape section from a "must not be used" prohibition to a positive
  grammar, and propagating that grammar to every site in Findings #3 below — a strictly larger
  edit than (A), and a second reversal of a decision made and shipped in the same work session
  chain.

This is presented as a decision for the plan, not resolved unilaterally here, because task 956's
own WORK item (1) explicitly requests (B) — but a plan that adopts (B) without acknowledging it
is overturning `plan-format.md`'s explicit, dated, evidenced prohibition would be making an
undocumented reversal of a very recent architectural decision, which is itself a process defect
independent of which technical answer is chosen.

### 2. Confirmed mechanics of both observed defects

**Undercount (`update-task-status.sh`)** — `count_plan_phases()`
(`agent-system/extensions/core/scripts/update-task-status.sh`, function of that name):
```
PHASE_CHECK_TOTAL=$(grep -c '^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[[A-Z][A-Z ]*\][[:space:]]*$' ...)
PHASE_CHECK_DONE=$(grep -c '^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:.*\[\(COMPLETED\|COMPLETED WITH EXCLUSIONS\)\][[:space:]]*$' ...)
```
A heading like `### Phase 3a: ... [COMPLETED]` fails to match **either** regex at all: after the
digit run, the pattern requires `:` (optionally via the decimal group) immediately, and `a` isn't
`:`. The heading is invisible to both TOTAL and DONE — it silently vanishes from the count on
both sides, which is why the real-world case under-reported `4/4` instead of `9/9` yet still
"passed."

**Collapse (`validate-artifact.sh`)** — the presence check (`grep -qE '^### Phase [0-9]+(\.[0-9]+)?'`)
and phase-line enumeration (`grep -n '^### Phase [0-9]\+\(\.[0-9]\+\)\?'`) are **not** end-anchored
to `:`, so `### Phase 3a: ...` DOES match as a prefix — the loop still iterates over all 9 lines
correctly (this file does not undercount phases). The number-extraction step, though,
```
phase_num=$(echo "$phase_heading" | grep -oE '^### Phase [0-9]+(\.[0-9]+)?' | grep -oE '[0-9]+(\.[0-9]+)?' || true)
```
extracts only the digit run — `3a` extracts as `3` — so three distinct headings (`3a`, `3b`,
`3c`) all report as "Phase 3" in the `log_warn "Phase ${phase_num} missing **Verification
Tier** field"` message. This is a *reporting* defect (each heading is still individually checked
for its own Verification Tier field), not an undercount, and is a materially smaller fix than
`update-task-status.sh`'s.

**Why `[DESCOPED]` silently zeroes out**: `count_plan_phases()`'s TOTAL bracket class is
`[A-Z][A-Z ]*` (uppercase letters and spaces only) — this is documented in
`status-markers.md`'s "Character-class constraint" note as the reason `COMPLETED WITH EXCLUSIONS`
was spelled without a hyphen. `DESCOPED` satisfies that class, so a `### Phase N: ... [DESCOPED]`
heading **is** counted in TOTAL, but DONE's alternation is the literal
`\(COMPLETED\|COMPLETED WITH EXCLUSIONS\)` — `DESCOPED` is not in it, so the phase counts in the
denominator and never the numerator. This is exactly the observed "5/9 instead of 5/5" refusal:
every `[DESCOPED]` phase inflates TOTAL without ever satisfying DONE. This is a **structural**
consequence of the TOTAL/DONE asymmetry, not a one-off oversight, and it will recur for *any*
future all-caps marker that isn't added to the DONE alternation — which is exactly why WORK item
(3)'s "loud inconclusive result for an unrecognized marker" is the right general fix, independent
of which way `[DESCOPED]` itself is resolved.

### 3. Full consumer-site inventory (expands the given FILE SCOPE)

`plan-format.md`'s own "Consumer sites of this shape" paragraph (written during the prior task)
already names sites beyond task 956's given FILE SCOPE. Verified present and still matching the
digits-only/decimal-only shape today:

| File | In task 956's FILE SCOPE? | Site(s) | Current shape |
|------|---------------------------|---------|----------------|
| `scripts/update-task-status.sh` | Yes | `count_plan_phases()` TOTAL + DONE; `first_phase` auto-advance grep+sed | decimal-admitting, no letters |
| `scripts/update-phase-status.sh` | Yes | `grep -n "^### Phase ${phase_number}:"` | parameterized on caller-supplied `phase_number` — already letter-agnostic in isolation; the defect is entirely in *callers* that extract `phase_number` via a digits-only regex before invoking this script |
| `scripts/validate-artifact.sh` | Yes | presence check; phase-line enumeration; phase-number extraction (2 chained `grep -oE`) | decimal-admitting, no letters |
| `skills/skill-orchestrate/SKILL.md` | Yes | 3 recovered-total/recovered-completed pairs (Stage 5, corroboration + recovery branches, 2 call sites) | decimal-admitting, no letters; **also** only recognizes literal `[COMPLETED]`, not `[COMPLETED WITH EXCLUSIONS]`, in `recovered_completed` — a second, independent drift from the DONE alternation used elsewhere |
| `skills/skill-orchestrate-hard/SKILL.md` | Yes | `next_phase` grep+sed pair; 2 recovered-total/recovered-completed pairs | same two issues as above |
| `skills/skill-implementer-hard/SKILL.md` | Yes | `next_phase` grep+sed pair | decimal-admitting, no letters |
| `skills/skill-lean-implementation-hard/SKILL.md` | Yes | `next_phase` grep (digits-only, **no decimal support at all**); `phase_number` extraction (`grep -oP "Phase \K[0-9]+"`) | least-capable site in the codebase — doesn't even have the decimal fix yet |
| `rules/plan-format-enforcement.md` | Yes | prose spec only, no regex | valid-marker list needs updating if either decision changes |
| `agents/general-implementation-agent.md` | **No — missing from FILE SCOPE** | Stage 5a: `stale_total` count, iteration grep, phase-number extraction (2 chained greps), `awk` next-heading-boundary pattern | decimal-admitting, no letters (4 regex fragments) |
| `agents/general-implementation-hard-agent.md` | **No — missing from FILE SCOPE** | Same Stage 5a block, hard-mode copy | same 4 fragments |
| `commands/task.md` | **No — missing from FILE SCOPE** | `/task --review` Step 3: `grep -E "^### Phase [0-9]+(\.[0-9]+)?:"` | decimal-admitting, no letters |

`scripts/update-plan-status.sh` was checked and confirmed to have **zero** phase-heading
references — it operates only on the plan-level `- **Status**:` field, a structurally different
mechanism, and is correctly out of scope (consistent with the prior task's own finding).
`scripts/orchestrate-recover-outcome.sh` was also checked — it reads `phases_completed`/
`phases_total` from JSON (`.return-meta.json` / `.orchestrator-handoff.json`) via `jq`, never
touching the plan file, and is not a phase-heading-regex site.

**Recommendation**: expand FILE SCOPE to include the three missing files before implementation
starts. Missing them would repeat exactly the failure mode task 956 exists to fix — a partial fix
across some but not all sites recreates drift.

### 4. `[COMPLETED WITH EXCLUSIONS]`'s admission test already covers the whole-phase case

`status-markers.md`'s five-condition admission test for `[COMPLETED WITH EXCLUSIONS]` (decision
not abandonment; tightly scoped to enumerated items; documented reason; evidenced; no residual
work) does not require that *some but not all* items remain — a phase whose *entire* remaining
scope is decided-and-will-not-be-revisited satisfies all five conditions identically to a
partial-exclusion phase. The mechanism (`#### Reasoned Exclusions` table: `Item | Reason |
Evidence`) already accepts an enumerated list covering 100% of a phase's remaining items. There is
no gap in the existing outcome that `[DESCOPED]` would fill — only a missing instruction to
authors that whole-phase descoping is exactly what `[COMPLETED WITH EXCLUSIONS]` is for.

**If `[DESCOPED]` is rejected** (recommended), the cheapest complete fix is:
- `plan-format-enforcement.md` / `status-markers.md`: one sentence stating `[DESCOPED]` is not a
  recognized phase-heading marker and that whole-phase descoping uses `[COMPLETED WITH
  EXCLUSIONS]` with a `#### Reasoned Exclusions` record covering all remaining items.
- `validate-artifact.sh`: a new check (there is currently **no** validation of phase-status
  *marker text* against the valid-marker enum at all — only the Verification Tier field is
  checked per-phase) that flags any bracket content not in `{NOT STARTED, IN PROGRESS, COMPLETED,
  COMPLETED WITH EXCLUSIONS, PARTIAL, BLOCKED}` as a loud error, naming `[DESCOPED]` explicitly in
  the message as "use [COMPLETED WITH EXCLUSIONS] instead" if that exact string is seen. This is
  the natural implementation of WORK item (3)'s "loud inconclusive result."
- Zero changes needed to `update-task-status.sh`'s DONE alternation, `update-phase-status.sh`'s
  accepted-status case branch, the handoff-schema accounting rule, or any Stage 5a skip-on-resume
  list — all of that machinery was already built generically enough by the prior task to need no
  further widening for this outcome.

**If `[DESCOPED]` is admitted instead** (not recommended, but priced here for comparison), it
requires touching every site `[COMPLETED WITH EXCLUSIONS]` touched: `status-markers.md` (new
subsection + admission test justification separate from `COMPLETED WITH EXCLUSIONS`, or a
statement of why it needs its OWN test), `plan-format.md` valid-status list,
`plan-format-enforcement.md`, `update-task-status.sh` DONE alternation, `update-phase-status.sh`
case branch, `general-implementation-agent.md`/`-hard-agent.md` Stage 3 skip-on-resume list and
Stage 5a repair-awareness, `handoff-schema.md`'s `phases_completed` accounting rule, and
`commands/task.md`'s phase-categorization list — an ~9-site ripple to add a marker that is
semantically redundant with one already fully wired.

### 5. Existing shared-library precedent for the "single named anchor"

`agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` already solves the
identical problem shape for a different pattern family: it is `source`d by both
`scripts/check-task-references.sh` (lint gate) and `hooks/validate-no-task-references.sh`
(write-time guard) so the pattern is defined exactly once and both consumers are "guaranteed to
agree byte-for-byte." Both consumers resolve the library via a deploy-tree-first,
source-store-fallback candidate list and fail loudly (not silently) if neither location has it.
This is the model to follow for a new `scripts/lib/phase-heading-patterns.sh`:

- Export the canonical ERE/BRE forms already documented (but only as prose, not as sourceable
  code) in `plan-format.md`'s "Canonical phase-heading shape" table, plus the DONE-status
  alternation and the (currently code-duplicated) `[A-Z][A-Z ]*` TOTAL bracket class.
- The three `.sh` files (`update-task-status.sh`, `update-phase-status.sh`,
  `validate-artifact.sh`) `source` it directly, exactly like `check-task-references.sh` does.
- The `SKILL.md` files (`skill-orchestrate`, `skill-orchestrate-hard`, `skill-implementer-hard`,
  `skill-lean-implementation-hard`) already establish a `source .claude/scripts/*.sh` /
  `bash .claude/scripts/*.sh` convention for their embedded bash blocks (e.g.
  `source .claude/scripts/skill-base.sh`, `bash .claude/scripts/orchestrate-recover-outcome.sh`)
  — their phase-heading snippets can `source .claude/scripts/lib/phase-heading-patterns.sh` and
  reference exported variables (e.g. `$PHASE_HEADING_ERE`) instead of re-typing the literal
  regex, closing the copy-paste-drift root cause task 956 identifies directly, not just
  patching each occurrence in place.
- `agents/general-implementation-agent.md` / `-hard-agent.md` and `commands/task.md` (Finding #3)
  should be brought onto the same library once FILE SCOPE is corrected.

**Known operational gap to flag, not fixed by this task**: `rules/source-store-deploy-boundary.md`
records that the headless deploy/sync path does not automatically copy a *brand-new*
`scripts/lib/*.sh` file into an already-loaded extension's deployed `.claude/scripts/lib/` tree —
this was hit and manually worked around when `task-reference-patterns.sh` was first added. A new
`phase-heading-patterns.sh` will need the same one-off manual propagation (or a full "Load Core"
resync) on this repo's existing deployment; this is a known, named, pre-existing gap in the
extension-loader subsystem, not something task 956 should attempt to fix as a side effect.

### 6. Related but out-of-scope drift found during this audit

- `.claude/rules/artifact-formats.md`'s "Phase Status Markers" section still lists only `[NOT
  STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]` — it was not updated when
  `[COMPLETED WITH EXCLUSIONS]` was introduced. Its source-store counterpart (under
  `agent-system/extensions/core/rules/`) should be checked and reconciled; this is pre-existing
  drift the prior task missed, not something task 956 introduced, but the planner for 956 may
  want to absorb this one-line fix while already touching the same vocabulary.
- `skill-orchestrate/SKILL.md`'s and `skill-orchestrate-hard/SKILL.md`'s `recovered_completed`
  variable (Finding #3) only matches literal `[COMPLETED]`, never `[COMPLETED WITH EXCLUSIONS]` —
  an exclusion-closed phase in a plan being recovered through this specific corroboration path
  would under-count exactly as `update-task-status.sh` did before the prior task fixed it. This is
  in the direct blast radius of "reconcile all sites onto one canonical pattern" and should be
  fixed alongside the letter/DESCOPED work, not left as a fourth divergent shape.
- **No test coverage exists anywhere for phase-heading-regex parsing.** `find agent-system -path
  "*tests*"` shows exactly two test files repo-wide (`test-literature-convert.sh`,
  `test-validate-no-task-references.sh`); the latter is the model to follow —
  `task-reference-patterns.sh`'s shared library has fixtures precisely because two independent
  consumers needed to be proven to agree. A `phase-heading-patterns.sh` library should ship with
  an analogous `scripts/tests/test-phase-heading-patterns.sh` covering: `Phase 3`, `Phase 3.1`,
  `Phase 3.1.2` (must reject per the "at most one decimal sub-level" rule), and — once the
  letter/DESCOPED decisions are made — `Phase 3a` and `[DESCOPED]` fixtures encoding whichever
  resolution is chosen (accept-and-count, or reject-and-warn-loudly).

## Decisions

These are presented as findings/recommendations for the plan to ratify, not as unilaterally
made implementation decisions:

- Recommend **not** widening the canonical grammar to accept letter-suffixed sub-phases; instead
  make a non-conforming phase-number token a loud, visible warning at every accounting site,
  mirroring the existing "no conforming headings" inconclusive-and-pass-through branch. If the
  planner instead chooses to admit letters (as task 956's WORK item (1) literally requests), that
  choice must explicitly record that it reverses `plan-format.md`'s dated, evidenced prohibition,
  and must decide `Na.M` legality; the recommended constraint if adopted is "at most one
  optional sub-phase suffix total, either a decimal (`.M`) or a single lowercase letter (`a`-`z`),
  never both stacked" — the same single-sub-level spirit as the existing decimal rule.
- Recommend **rejecting** `[DESCOPED]` and requiring `[COMPLETED WITH EXCLUSIONS]` with a
  `#### Reasoned Exclusions` record covering 100% of the phase's remaining items for the
  whole-phase-descope case. This reuses fully-wired machinery and adds zero new accounting sites.
- Recommend expanding FILE SCOPE to include `agents/general-implementation-agent.md`,
  `agents/general-implementation-hard-agent.md`, and `commands/task.md` before implementation, per
  Finding #3.
- Recommend a new shared library `scripts/lib/phase-heading-patterns.sh`, modeled directly on
  `scripts/lib/task-reference-patterns.sh`, as the "single named anchor" the task asks for, with
  the deploy-tree-first/source-store-fallback resolution pattern and loud failure if not found.

## Risks & Mitigations

- **Risk**: implementing only the given FILE SCOPE (8 files) silently misses the 3 additional
  known consumer sites, recreating the exact drift this task exists to close.
  **Mitigation**: expand scope per Finding #3 before implementation; cite `plan-format.md`'s own
  consumer-site paragraph as the source of truth for the list, not line numbers.
- **Risk**: a new shared-library file may not propagate to this repo's already-deployed
  `.claude/scripts/lib/` on the next headless sync, per the documented extension-loader gap.
  **Mitigation**: verify the file lands in `.claude/scripts/lib/` after deploy (a `Read`/`ls`
  check), and manually invoke the loader's copy primitives (or a full "Load Core" resync) if not,
  exactly as was done for `task-reference-patterns.sh`.
- **Risk**: reversing `plan-format.md`'s explicit no-letter-suffix decision without recording that
  it is a reversal would silently erase the rationale the prior task recorded, inviting a future
  reader to re-litigate the same question a third time.
  **Mitigation**: whichever way the plan resolves this, it must edit the existing prohibition text
  in place (not merely add new text beside it) and state explicitly that this supersedes the
  prior decision, with a one-line pointer to what changed and why.
- **Risk**: `[COMPLETED WITH EXCLUSIONS]`'s five-condition admission test was written with a
  single excluded item or a partial subset in mind stylistically; if rejecting `[DESCOPED]`,
  author-facing guidance should say explicitly that "all remaining items" is a valid, not a
  degenerate/unintended, case — otherwise authors may reach for an ad hoc marker like `[DESCOPED]`
  again out of uncertainty that whole-phase exclusion is really covered.
  **Mitigation**: add one explicit sentence to that effect in `status-markers.md`.

## Context Extension Recommendations

- **Topic**: Phase-heading regex consumer-site list.
  **Gap**: `plan-format.md`'s "Consumer sites of this shape" paragraph is prose-only and already
  incomplete relative to the true site count found here (a `SKILL.md` recovered-completed
  `[COMPLETED WITH EXCLUSIONS]` gap, and no mention that `update-phase-status.sh` itself is
  parameter-driven rather than pattern-driven).
  **Recommendation**: once a shared library exists (Finding #5), replace the prose consumer list
  with "grep for `phase-heading-patterns.sh` sourcers" as the live, self-verifying inventory
  mechanism, the same way `task-reference-patterns.sh`'s two consumers are found by grepping for
  its filename rather than trusting a hand-maintained prose list to stay current.
- **Topic**: Phase-heading-regex test coverage.
  **Gap**: zero test coverage exists for any phase-heading parsing anywhere in the codebase.
  **Recommendation**: `scripts/tests/test-phase-heading-patterns.sh`, modeled on
  `test-validate-no-task-references.sh`, covering the fixture set in Finding #6.

## Appendix

### Search queries / commands used

- `grep -rn 'DESCOPED' agent-system/ .claude/ specs/` — confirmed zero hits outside `specs/`
  (task metadata only).
- `grep -n 'Phase \[0-9\]\|\^### Phase\|grep.*Phase' <each FILE SCOPE file>` — located all
  regex sites in the given scope.
- `grep -n 'Phase heading\|### Phase\|Implementation Phases' plan-format.md` — found the existing
  "Canonical phase-heading shape" section and its consumer-site list.
- `grep -rn 'letter-suffix\|Letter-suffix\|letter suffix\|Phase 3a\|Phase Na' specs/ agent-system/`
  — surfaced the prior task (`specs/924_documented_reasoned_exclusions_phase_outcome/`) and its
  explicit rejection of letter suffixes.
- Read in full: `specs/924_.../reports/01_documented-reasoned-exclusions.md`,
  `specs/924_.../plans/01_reasoned-exclusions-phase-outcome.md`,
  `specs/924_.../summaries/01_reasoned-exclusions-phase-outcome-summary.md`.
- `find agent-system -path "*tests*"` — confirmed the total absence of phase-heading test
  coverage.

### Files read in full or in relevant part

- `agent-system/extensions/core/scripts/update-task-status.sh` (lines ~220-340, ~460-470)
- `agent-system/extensions/core/scripts/update-phase-status.sh` (full)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (lines ~140-220)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (phase-marker/recovery
  sections)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (same)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (resume-scan section)
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` (resume-scan
  section)
- `agent-system/extensions/core/rules/plan-format-enforcement.md` (full)
- `agent-system/extensions/core/context/standards/status-markers.md` (lines ~120-230)
- `agent-system/extensions/core/context/formats/plan-format.md` (lines ~64-210)
- `agent-system/extensions/core/context/contracts/phase-closure.md` (partial)
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` (full)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 5a)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 5a)
- `agent-system/extensions/core/commands/task.md` (Step 3, phase parsing)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (phases_completed
  accounting rule)
- `.claude/rules/artifact-formats.md` (Phase Status Markers section)
