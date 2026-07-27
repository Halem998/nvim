# Implementation Summary: Task #922

**Completed**: 2026-07-27
**Duration**: ~2.5 hours

## Overview

Introduced a risk-stratified, named-and-ordered verification-tier vocabulary
(`prose < local < interface < full`) into the plan format, alongside an orthogonal
`Commit Mode` axis (`per-substep` default, `atomic-batch` opt-in) that makes a pre-declared
atomic multi-file batch expressible without violating the Commit-Per-Green-Substep Mandate. The
vocabulary was propagated to all six phase-template restatement sites, given real per-phase
enforcement in `validate-artifact.sh` (advisory-first, per D3), and cross-referenced from the
numeric reference-grounding tier system. All six of the plan's phases completed; every phase's
own stated verification criteria were run and passed with the exact counts the plan specified.

## What Changed

- `agent-system/extensions/core/context/formats/plan-format.md` — new `## Verification Tiers`
  section (tier table with per-tier blind spots, tie-break-upward rule, final-gate invariant,
  commit-mode definitions, counts-are-hypotheses obligation, enforcement-level/promotion
  criterion); three new per-phase fields (`Verification Tier`, `Commit Mode`, `Scope Hypothesis`)
  added to `## Implementation Phases (format)` with a field-punctuation-tolerance note; Example
  Skeleton updated to demonstrate both fields.
- `agent-system/extensions/core/rules/git-workflow.md` — new "Atomic-batch objectives" bullet
  inside `### Commit-Per-Green-Substep Mandate`, plus a one-clause pointer added to the
  pre-existing "Do Not Commit" bullet so the two sections read as consistent rather than
  contradictory.
- `agent-system/extensions/core/agents/planner-agent.md` — Stage 4 tier-assignment sub-step
  (with tie-break-upward sentence and counts-are-hypotheses guidance), Stage 5 template fields,
  Stage 6a self-verification checklist entry.
- `agent-system/extensions/core/agents/planner-hard-agent.md` — numbered required-addition item
  for the per-phase tier field (noting hard mode's own "Estimated output" line is itself a scope
  hypothesis), counts-are-hypotheses guidance, and a MUST NOT line against weakening the final
  gate.
- `agent-system/extensions/core/skills/skill-team-plan/SKILL.md` — phase-template field and
  tie-break sentence in the teammate planning instructions (Teammate B inherits via "Format: Same
  as Teammate A").
- `agent-system/extensions/core/context/workflows/task-breakdown.md` — phase-level field in the
  template (distinct from the existing per-item `**Verification:**` lines, left untouched), a
  varying plausible tier for each of the three worked-example phases, and a new closing-checklist
  item.
- `agent-system/extensions/core/docs/guides/user-guide.md` — field added to both the phase
  template block and the bulleted field-explanation list (the site's third naming convention,
  `**Steps**:`, was preserved rather than folded into `**Tasks**:`).
- `agent-system/extensions/core/scripts/validate-artifact.sh` — new per-phase-block iteration
  (locates each `### Phase N` heading's line range and searches only within it), accepting both
  `**Verification Tier**:` and `**Verification Tier:**` punctuation forms, emitting one
  `log_warn` per untiered phase and one for an unrecognized tier value; a source comment at
  `PLAN_METADATA` documents why the field is deliberately excluded from that whole-document
  array. Also fixed a pre-existing `set -euo pipefail` bug (see Decisions).
- `agent-system/extensions/core/rules/plan-format-enforcement.md` — per-phase required-field
  line and a note on the current advisory/warn enforcement level.
- `agent-system/extensions/core/context/contracts/reference-grounding.md` — two-to-three-sentence
  cross-reference note near "Tier Selection" acknowledging the sibling verification-tier system
  and its shared tie-break-upward design, without restating either vocabulary.
- `agent-system/extensions/core/index-entries.json` — corrected `line_count` for
  `formats/plan-format.md` (136 → 299), `workflows/task-breakdown.md` (270 → 281),
  `contracts/reference-grounding.md` (94 → 102).

## Decisions

- Followed the plan's D1-D7 decisions as directed (named ordered tiers to avoid a polarity
  collision with reference-grounding's numeric tiers; commit mode as an orthogonal field, not a
  tier; advisory-first `log_warn` enforcement; the counts-are-hypotheses carrier field; all six
  restatement sites updated; the cross-reference note instead of a new context file; dual
  punctuation-convention tolerance in the validator).
- **Discovered and fixed a pre-existing bug** in `validate-artifact.sh`'s counter functions.
  Live testing (building the required fixtures) showed that `log_error`/`log_warn`/`log_fix`'s
  bare `((var++))` form evaluates to the pre-increment value under `set -euo pipefail`; the very
  first 0-to-1 increment of ANY counter, anywhere in the script's execution, aborts the whole
  script immediately — the summary/`[PASS]`/`[FAIL]` block never runs, and a warnings-only run
  (which the D3 advisory design requires to exit 0) instead exits 1 for the wrong reason. This
  predates this task and affected all three counters, not just the new tier-warning path. Fixed
  by switching all three functions to the safe `var=$((var + 1))` assignment form. Without this
  fix, the new per-phase tier loop's own warnings would have silently truncated validator output
  and broken the D3 advisory-first exit-0 contract that this phase exists to deliver.

## Plan Deviations

- **Task 5.7** (verify `set -euo pipefail` compatibility) altered: no existing safe guard
  pattern was found to "match" as the plan anticipated — the bug was live and unguarded across
  all three counter functions. Fixed all three (not just `log_warn`) rather than a partial fix
  that would leave `log_error`/`log_fix` able to abort the script before the new loop is ever
  reached. See the phase-5 progress file and the inline plan annotation for detail.
- **Task 6.5 / Testing & Validation item** (run `validate-context-index.sh`, confirm no
  line-count mismatch) altered: the script is hardcoded to the DEPLOYED
  `.claude/context/index.json` and is guarded to refuse running from the `agent-system/` source
  tree. The deployed copy is broadly stale (~40 pre-existing mismatched entries unrelated to this
  task), and redeploying `.claude/` is out of scope per the binding source-store rule. Verified
  the three touched entries directly against the source of truth
  (`agent-system/extensions/core/index-entries.json`) via `wc -l` + `jq` instead — all three now
  match exactly.

## Verification

- Build: N/A (markdown + bash; no compiled build step)
- Tests: All phase-level verification criteria run and passed with exact counts as specified in
  the plan:
  - Phase 1: `## Verification Tiers` heading present (1), all four tier names present, tie-break
    string present, final-gate invariant string present, field appears in both the field list and
    Example Skeleton.
  - Phase 2: `atomic-batch` confirmed present **inside** the
    `### Commit-Per-Green-Substep Mandate` section's own line range (not merely in the file);
    "declared in the plan in advance" language present; both pre-existing verbatim quotes still
    present and unmodified.
  - Phase 3: `Verification Tier` and the tie-break string present in both
    `planner-agent.md`/`planner-hard-agent.md`; Stage 6a checklist entry present; both files
    contain a counts-are-hypotheses statement; the pre-existing `**Verification**:` field in
    `planner-agent.md`'s template is unchanged.
  - Phase 4: all three remaining sites carry `Verification Tier`; `task-breakdown.md`'s 11
    pre-existing per-item `**Verification:**` checklist lines are unchanged in count;
    `user-guide.md`'s field-explanation list carries the new entry; combined six-site grep
    returns 6/6.
  - Phase 5 (highest-risk): `bash -n` passes; positive fixture (3 phases, all tiered) → 0 tier
    warnings; **negative fixture (2 phases, only phase 1 tiered) → exactly 1 warning naming phase
    2** (confirmed by direct run, not assumed); both punctuation-convention fixtures → 0 tier
    warnings each; this plan itself and a pre-existing plan under `specs/`
    (`916_fix_orchestrate_completion_summary_propagation`) both exit 0 in default mode; the
    pre-existing plan exits 1 under `--strict` (6 tier warnings reported, one per untiered
    phase).
  - Phase 6: `jq`/`wc -l` cross-check confirms all three touched `index-entries.json` rows are
    now accurate; the seven no-index-coverage files confirmed to genuinely have 0 rows each; the
    combined six-site grep, tie-break-string-in-four-files grep, and final-gate-invariant grep
    all confirmed at Phase 6 sweep time.
- Files verified: Yes — every edited file re-read or grep-confirmed after editing.

## Notes

- `git status --porcelain` was checked after every phase and confirmed changes confined to
  `agent-system/` (and, for the whole-task view, `specs/922_...`) — no path under `.claude/` was
  staged or modified by this task, consistent with the binding source-store rule.
- The implementation-side gate that would consume the `Scope Hypothesis` obligation (Decision D4)
  remains explicitly out of scope, as directed by the plan; this task delivers only the
  planner-side obligation and its carrier field.
- `.claude/` (the deployed tree) was not redeployed as part of this task; a future
  `deploy-headless.sh` run (or the interactive "Load Core" sync) will pick up all of the above
  source-store changes, including the `index-entries.json` line-count corrections.
