# Research Report: Task #922

**Task**: 922 - risk_stratified_verification_tiers_in_plans
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:30:00Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**: - agent-system/extensions/core source store (rules/, context/formats/, agents/, skills/, scripts/, docs/)
**Artifacts**: - specs/922_risk_stratified_verification_tiers_in_plans/reports/01_verification-tier-source-store-findings.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three source-store findings in the task description (A, B, C) are confirmed verbatim
  against the CURRENT source store — the task description is accurate, not stale.
- Finding B's "at least five" restatement sites undercounts by one: a **sixth** site,
  `docs/guides/user-guide.md`, also restates a phase template with a `**Verification**:` field,
  using yet a *third* field-naming convention (`**Steps**:` instead of `**Tasks**:`). The
  planner should decide whether to update it too (recommended: yes, for consistency) even
  though it is documentation rather than an enforced/parsed template.
- `scripts/validate-artifact.sh`'s existing checks are **whole-document existence checks only**
  (`grep -qF`/`grep -qE` run once per file). There is currently no mechanism anywhere in the
  script that iterates per-phase-block, so a new "every phase must carry a Verification-Tier
  field" requirement cannot be enforced by copying the existing pattern — it needs genuinely new
  loop-over-phase-blocks logic. This directly answers research-focus item 3.
- `index-entries.json`'s recorded `line_count` for `formats/plan-format.md` is **136**; the
  actual file is **222** lines (`wc -l`) / 223 physical lines including the unterminated final
  line — a drift of roughly 86-87 lines, confirming the task description's claim. None of the
  other five (or six) phase-template-restatement files are indexed in `index-entries.json` at
  all — that index only covers the `context/` subtree, not `agents/`, `rules/`, `skills/`, or
  `scripts/`. `context/workflows/task-breakdown.md` is indexed and its recorded count (270) is
  currently accurate (no drift there).
- A close, directly reusable precedent for the required "tie-break-upward" rule already exists
  in `context/contracts/reference-grounding.md`'s H3 tier system: *"When uncertain, apply the
  highest applicable tier (Tier 1 > Tier 2 > Tier 3)."* The new verification-tier vocabulary
  should mirror this phrasing/pattern rather than invent new wording.
- `checkpoint-before-overflow.md`'s green/RED distinction ("green" = "the objective's own
  verification criteria passed") is granularity-agnostic — it already supports defining an
  atomic multi-file batch as one `progress-file.md` objective whose own verification criterion
  is the batch-level build, which is the mechanism Finding D's carve-out should hook into rather
  than inventing a parallel concept.

## Context & Scope

Researched the CURRENT state of the agent-system source store
(`agent-system/extensions/core/`) to verify every claim in the task description before the
`/plan` phase begins, per the task's explicit research focus. No web research was needed; this
is a pure codebase-archaeology task. All findings below are anchored on symbol names, heading
text, and quoted strings (per the task's line-number caveat), not line numbers, except where a
specific current line number is cited as a locator for the next agent's convenience (subject to
drift).

## Findings

### Finding A — Commit-Per-Green-Substep Mandate (rules/git-workflow.md)

Confirmed. `agent-system/extensions/core/rules/git-workflow.md` contains, under
`### Commit-Per-Green-Substep Mandate`:

> "Every verified-green sub-step is committed as it happens — this is a mandate, not an
> optional-when-convenient practice."

Sub-step granularity is defined verbatim as:

> "a 'sub-step' is a `progress-file.md` objective transitioning to `status: "done"` — the same
> unit `files_touched` accumulates against"

and "green" is defined as "verified, not merely attempted" — "the objective's own verification
criteria passed (a check ran and succeeded, files were confirmed to exist and be non-empty, or a
build/test step passed where applicable)" per `checkpoint-before-overflow.md`'s green/RED
distinction.

**Implication for scope item D**: this definition is already unit-agnostic — a "sub-step" is
whatever `progress-file.md` objective the plan/implementer declares it to be. The atomic
multi-file batch carve-out does not need to fight this definition; it needs to make explicit
that ONE `progress-file.md` objective MAY legitimately span multiple files/edits when the plan
has declared that scope as one atomic batch tier, and that the objective's own verification
criterion in that case is the batch-level build, not a per-file green requirement. Landing this
only in `plan-format.md` (the mistake Finding A warns against) would leave
`git-workflow.md`'s mandate reading as if every individual file-level edit inside the batch must
itself reach `status: "done"` before commit — recreating exactly the SYMPTOM 2 defect one layer
up. The carve-out sentence needs to sit inside (or be directly cross-referenced from) the
Commit-Per-Green-Substep Mandate section itself, not merely in the surrounding prose.

### Finding B — Phase-template restatement sites (SIX, not five)

The task description names five sites. All five checked out; a sixth was found.

| # | File | Restates phase template? | Has per-phase `**Verification**:` field? | Field-naming convention |
|---|------|---------------------------|---------------------------------------------|--------------------------|
| 1 | `context/formats/plan-format.md` — "Implementation Phases (format)" section | Yes (prose spec) | **No** | `Goal:` / `Tasks:` / `Timing:` / `Depends on:` / `Owner:` / status-transition timestamps — no Verification field listed at all |
| 2 | `context/formats/plan-format.md` — "Example Skeleton" | Yes (worked example) | **No** | Same fields as above, no Verification |
| 3 | `agents/planner-agent.md` | Yes | **Yes** | `**Goal**:` / `**Tasks**:` / `**Timing**:` / `**Depends on**:` / `**Files to modify**:` / `**Verification**:` |
| 4 | `agents/planner-hard-agent.md` (Stage 5, "Required hard-mode additions to plan format") | Yes, but as a delta list, not a full heading example | **No** — instead requires "Estimated output: ~N lines" and "Done when: {criterion}" per phase | No template heading shown at all; explicitly says "Follow plan-format.md for all other structure" |
| 5 | `skills/skill-team-plan/SKILL.md` | Yes | **Yes** | `**Estimated effort**:` / `**Objectives**:` / `**Files to modify**:` / `**Steps**:` / `**Verification**:` — a THIRD distinct field-naming convention (Objectives+Steps instead of Goal+Tasks) |
| 6 | `context/workflows/task-breakdown.md` | Yes | **Yes, but at a different granularity** — `**Verification:**` appears per checklist *item* inside `**Tasks:**`, not once per phase | `### Phase N: {Phase Name}` / `**Goal:**` / per-task bullets each individually followed by `- **Verification:** {how to verify it's done}` |
| **7 (not in task description)** | `docs/guides/user-guide.md` | Yes | **Yes** | `### Phase 1: ... [NOT STARTED]` / `**Goal**:` / `**Steps**:` (not "Tasks") / `**Verification**:` (single line, not bulleted) |

**Consequence for scope item B**: three different field-naming conventions currently coexist for
the "how do I know this phase is done" concept (`**Verification**:` bullets in
planner-agent.md/skill-team-plan; per-item `**Verification:**` in task-breakdown.md;
`**Verification**:` single-line in user-guide.md). A new per-phase verification-*tier* field
should be named and placed consistently with the existing `**Verification**:` convention (e.g.
`**Verification Tier**:` immediately before or after `**Verification**:`) rather than introducing
a fourth naming style. `plan-format.md` itself — the authoritative format doc that
`validate-artifact.sh` and `plan-format-enforcement.md` both derive from — currently has NO
Verification field of any kind, which is the most consequential gap: it is the document Finding
C's script and Finding A's git-workflow rule both ultimately point back to as "the spec."

**Distinguish restatement sites from mere heading-format consumers.** A broader grep for
`### Phase [0-9N]` also matches files that only *parse* the phase-heading status marker (never
restate the fuller Goal/Tasks/Verification template): `rules/artifact-formats.md`,
`context/standards/status-markers.md`, `docs/architecture/handoff-schema.md`,
`commands/task.md`, `skills/skill-implementer/SKILL.md`,
`skills/skill-implementer-hard/SKILL.md`, `skills/skill-orchestrate/SKILL.md`,
`skills/skill-orchestrate-hard/SKILL.md`, `context/patterns/team-orchestration.md`. These do not
need the new field propagated into them — they consume the `### Phase N: {name} [STATUS]`
heading contract only (the same three-consumer contract `plan-format.md` already documents:
`update-phase-status.sh`, `update-plan-status.sh`, `update-task-status.sh --phase-check`) and are
out of scope for this task's field-propagation work.

### Finding C — validate-artifact.sh is whole-document, not per-phase (answers research-focus item 3)

`scripts/validate-artifact.sh` defines, near the top:

```bash
PLAN_METADATA=("Task" "Status" "Effort" "Dependencies" "Research Inputs" "Artifacts" "Standards" "Type")
PLAN_SECTIONS=("Overview" "Goals & Non-Goals" "Risks & Mitigations" "Implementation Phases" "Testing & Validation" "Artifacts & Outputs" "Rollback/Contingency")
```

Two loops consume these arrays:
- Metadata check: `for field in "${metadata_fields[@]}"; do grep -qF "**${field}**:" "$artifact_path" ...` — checks that the string appears **anywhere at all** in the file, exactly once per field, no positional constraint.
- Section check: `for section in "${required_sections[@]}"; do grep -qE "^##+ ${section}" "$artifact_path" ...` — same whole-document existence semantics.

The only plan-specific check beyond the two generic loops is:

```bash
if ! grep -qE '^### Phase [0-9]+' "$artifact_path"; then
  log_error "Missing Phase headings ..."
fi
if ! grep -qF "Dependency Analysis" "$artifact_path"; then
  log_warn "Missing Dependency Analysis table ..."
fi
```

— i.e. "does at least one phase heading exist anywhere," not "does every phase have field X."

**Concrete implication**: if scope item F simply adds `"Verification Tier"` to a `PLAN_METADATA`-
style array and reuses the existing `grep -qF "**${field}**:"` pattern, the check would pass as
long as the string appears ANYWHERE in the file — e.g. a single phase out of five carrying the
tier field would satisfy it, silently leaving four phases untiered. To actually enforce "every
phase declares a tier" the script needs new logic that (a) locates each `### Phase N` heading's
line range (from that heading to the next `### Phase` heading or EOF), and (b) greps for the
required field pattern within that range only, accumulating a per-phase pass/fail rather than a
single document-wide pass/fail. This is a real script-logic addition, not a one-line array edit;
the planner should size it as its own phase/step rather than folding it silently into "add the
field to the format doc."

`rules/plan-format-enforcement.md` (19 lines, confirmed) is purely a human-readable pointer/
mirror of `plan-format.md`'s required-fields and required-sections lists plus the phase-heading
marker vocabulary; it carries no enforcement logic itself. It will need the new field
name/pattern added to its "Required metadata fields" / phase-heading description text to stay in
sync with whatever `validate-artifact.sh` ends up enforcing (per scope item F).

### Finding — index-entries.json drift (answers research-focus item 5)

```
jq '.entries[] | select(.path|test("plan-format.md"))' index-entries.json
```
reports `"line_count": 136` for `formats/plan-format.md`. The actual file
(`wc -l agent-system/extensions/core/context/formats/plan-format.md`) is **222** lines (223rd
line, the final closing code fence, has no trailing newline, so `wc -l` undercounts by one
relative to the Read-tool's 1-indexed line numbering — the file is 223 physical lines of
content). Either way the drift is roughly **86-87 lines**, confirming the task description's
claim that this entry is "already stale relative to the file... regardless" of this task's
edits.

`index-entries.json` only indexes the `context/` subtree (its `domain`/`subdomain` values are
all `context/`-relative categories: `formats`, `contracts`, `patterns`, `workflows`, etc. — 109
entries total, none under `agents/`, `rules/`, `skills/`, or `scripts/`). Of the six
phase-template-restatement files found in Finding B, only `context/workflows/task-breakdown.md`
is indexed at all, and its recorded count (270) currently matches the real file exactly — no
drift there today. This means scope item G's index-correction work is scoped narrowly: fix
`plan-format.md`'s entry (mandatory regardless of what this task adds), and re-check
`task-breakdown.md`'s count after this task's edits land (since work only in item B touches it).
`git-workflow.md`, `planner-agent.md`, `planner-hard-agent.md`, `skill-team-plan/SKILL.md`,
`plan-format-enforcement.md`, and `validate-artifact.sh` have no index-entries.json rows to
correct — they are simply outside that index's coverage.

### Tier-vocabulary design recommendation (answers research-focus item 4 — proposal only, not a decision)

The task explicitly reserves the exact tier set as a planning-time design decision. This is a
starting proposal for the plan phase to evaluate/revise, built from the task description's own
illustrative examples plus the blind-spot requirement:

| Tier | Trigger (what kind of edit) | In-phase verification | Explicitly does NOT cover (blind spot) |
|------|------------------------------|------------------------|------------------------------------------|
| 0 — Prose/comment-only | Edits confined to comments, docstrings, markdown prose, non-code text with zero elaboration/compile surface | None required beyond a diff read-through (no build) | Any accidental edit that crosses out of a comment/string boundary; cannot catch that by construction — a stray edit outside the comment token is invisible to this tier |
| 1 — Single-module | Edits confined to one compilation unit/file with no exported-signature change | Targeted single-file/single-module build or lint only | Cross-module breakage from a signature or behavior change that looks internal but is actually observed elsewhere (e.g. via reflection, dynamic dispatch, or an untyped call site) |
| 2 — Cross-module signature | Renames/retypes/reorders a symbol whose call sites span multiple files | Batch build restricted to the affected module + its direct dependents/call sites (not full repo) | Transitive breakage more than one hop away from the declared call-site set, and any semantic (not just type-level) behavior change downstream |
| 3 — Atomic multi-file batch (Finding D) | A single logically-atomic refactor whose intermediate per-file states are necessarily red (task's rename example: 24 files / 231 call sites) | ONE full build/test run at the end of the whole batch; no intermediate per-file gate | Nothing structurally new vs. Tier 2's blind spot — but explicitly must NOT be read as weakening final-gate strictness; it only changes *when* the gate runs, not what it covers |
| 4 — Whole-repo semantic | Edits that can change runtime/proof behavior anywhere (shared tactic, core type, global config, elaboration-affecting change) | Full gate set (all four gates in the motivating example) — this is the existing default/only tier today | N/A — this is the ceiling; nothing is deferred past it |

Design notes for the planner:
- The **tie-break-upward rule** (scope item C) means: when a phase's edit class is ambiguous
  between adjacent tiers, the planner MUST select the numerically higher (stricter) tier — direct
  structural mirror of `reference-grounding.md`'s "When uncertain, apply the highest applicable
  tier."
- The **non-negotiable constraint** (final gate unchanged) means Tier 4 must remain textually
  identical in strictness to today's existing full-gate requirement — the new vocabulary adds
  tiers 0-3 *below* the existing behavior, it does not redefine tier 4's contents.
- Every tier below the top (0-3) needs its "does NOT cover" column populated per the task's
  additional requirement, exactly as drafted above — a tier with no stated blind spot is
  indistinguishable from a silent weakening, which the task explicitly forbids.

## Decisions

- None made in this research pass — the task explicitly frames the tier vocabulary, exact field
  names, and script-enforcement mechanism as planning-time decisions. This report supplies
  verified facts and one starting proposal for the plan phase to adopt, adjust, or replace.

## Risks & Mitigations

- **Risk**: A plan that adds the Verification-Tier field only to `plan-format.md` and
  `planner-agent.md` (the two most visible sites) reproduces Finding B's exact failure mode
  (field present in some generated plans, absent in others depending on which
  skill/agent produced them). **Mitigation**: plan must enumerate all six sites found above (five
  named in the task + `docs/guides/user-guide.md`) as explicit touch points, even if the decision
  for the sixth is "skip, documentation-only, low priority" — that should be a stated decision,
  not a silent omission.
- **Risk**: Implementing per-phase field enforcement in `validate-artifact.sh` by copy-pasting
  the existing whole-document `grep -qF` pattern silently under-enforces (passes with only one
  tiered phase out of N). **Mitigation**: plan must size the script change as genuinely new
  per-phase-block-iteration logic (see Finding C), not a one-line array addition.
- **Risk**: Landing the atomic-batch carve-out only in `plan-format.md` recreates the
  expressiveness bug one layer up in `git-workflow.md`. **Mitigation**: plan must edit
  `rules/git-workflow.md`'s Commit-Per-Green-Substep Mandate section directly (Finding A), with
  plan-format.md cross-referencing it rather than restating conflicting language.
- **Risk**: A carelessly worded "counts are hypotheses" rule could read as excusing sloppy
  research rather than obliging implementation-time confirmation. **Mitigation**: scope item E is
  explicit that this task delivers only the planner-side obligation and plan-format field; the
  implementation-side consuming gate is an intentionally separate sibling task — the plan should
  not attempt to also design that consumer.

## Context Extension Recommendations

- **Topic**: Verification-tier / risk-stratified verification concept.
  **Gap**: No existing context file documents a risk/blast-radius-based verification-tiering
  concept anywhere in `context/contracts/` or `context/patterns/`, even though the directly
  analogous H3 reference-grounding tier system (`context/contracts/reference-grounding.md`)
  already establishes the "select tier by risk, tie-break upward when uncertain" pattern this
  task needs. **Recommendation**: the plan phase should decide whether the new tier vocabulary
  belongs solely inside `plan-format.md` (task description's stated location) or whether it
  additionally warrants a short cross-reference note in `reference-grounding.md` acknowledging
  the sibling pattern, to prevent future readers from treating the two tier systems as unrelated
  when they share the same tie-break-upward design.

## Appendix

### Search queries / commands used

```bash
grep -n "Commit-Per-Green-Substep\|sub-step" agent-system/extensions/core/rules/git-workflow.md
grep -n "^#\|Verification" agent-system/extensions/core/context/formats/plan-format.md
grep -n "Verification\|### Phase\|Goal:\|Tasks:\|Timing:\|Depends on" agent-system/extensions/core/agents/planner-agent.md
grep -n "Verification\|### Phase\|H8" agent-system/extensions/core/agents/planner-hard-agent.md
grep -rn "Verification\|### Phase" agent-system/extensions/core/skills/skill-team-plan/SKILL.md
grep -n "Verification\|### Phase" agent-system/extensions/core/context/workflows/task-breakdown.md
grep -n "PLAN_SECTIONS\|Verification" agent-system/extensions/core/scripts/validate-artifact.sh
jq '.entries[] | select(.path|test("plan-format.md"))' agent-system/extensions/core/index-entries.json
grep -rln '\*\*Verification\*\*:' agent-system/extensions/core --include="*.md"
grep -rl '### Phase [0-9N]' agent-system/extensions/core --include="*.md"
grep -n "Tier 1\|Tier 2\|Tier 3\|tier" agent-system/extensions/core/context/contracts/reference-grounding.md
```

### File locations referenced (current, subject to the line-number caveat)

- `agent-system/extensions/core/rules/git-workflow.md` — Commit-Per-Green-Substep Mandate
- `agent-system/extensions/core/context/formats/plan-format.md` — phase template + example skeleton (no Verification field)
- `agent-system/extensions/core/agents/planner-agent.md` — phase template with Verification field
- `agent-system/extensions/core/agents/planner-hard-agent.md` — H8 sizing + Stage 5 required-additions list
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md` — phase template with Verification field
- `agent-system/extensions/core/context/workflows/task-breakdown.md` — per-task-item Verification (different granularity)
- `agent-system/extensions/core/docs/guides/user-guide.md` — sixth restatement site (not in task description)
- `agent-system/extensions/core/scripts/validate-artifact.sh` — PLAN_SECTIONS/PLAN_METADATA whole-document checks
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — 19-line pointer checklist
- `agent-system/extensions/core/index-entries.json` — plan-format.md entry drift (136 vs 222/223)
- `agent-system/extensions/core/context/contracts/reference-grounding.md` — tie-break-upward precedent (H3)
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` — green/RED definition consumed by Finding A
