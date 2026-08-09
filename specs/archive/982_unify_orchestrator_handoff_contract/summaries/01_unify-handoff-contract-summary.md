# Implementation Summary: Task #982

- **Task**: 982 - One handoff schema, one writer, one validator
- **Status**: [COMPLETED]
- **Started**: 2026-08-05
- **Completed**: 2026-08-05
- **Effort**: ~8 hours
- **Dependencies**: 974 (completed)
- **Artifacts**: plans/01_unify-handoff-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Unified the four previously-disagreeing descriptions of `.orchestrator-handoff.json` (schema
doc, `wrap-up.md` H9 contract, `validate-handoff.sh`, and the two orchestrate engines' readers)
around one machine-checkable JSON Schema file. Rewrote the validator to enforce that schema with
bidirectional tests, deleted the zero-caller `skill_write_orchestrator_handoff` (collapsing the
continuation pointer to one canonical writable form), fixed a live artifact-linking defect in the
hard-mode writer template, rewrote the authoritative prose doc to point at the schema instead of
restating it, added a two-engine reader-parity test, and closed with a redeploy-and-verify pass.
All 7 plan phases are `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json` (new) — the
  single machine-checkable source of truth (draft-07 JSON Schema).
- `agent-system/extensions/core/scripts/validate-handoff.sh` — six-value status enum, required
  `artifacts` (conditional non-empty) and `summary` checks, updated help/header text pointing at
  the schema file.
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` (new) — 3 accept + 4
  reject fixtures, both directions asserted.
- `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` (new) — builds one
  shared fixture, extracts the actual jq filter strings from both `SKILL.md` engines (anchor-based,
  not hand-copied, so it catches real drift), asserts byte-identical filters and values for every
  shared field, and separately validates the four allowlisted hard-only fields
  (`.skeleton`, `.sorry_inventory`, `.blockers[0].target`, `.blockers[0].verbatim_goal`).
- `agent-system/extensions/core/manifest.json` — registered both new test scripts.
- `agent-system/extensions/core/scripts/skill-base.sh` — deleted `skill_write_orchestrator_handoff()`
  and its env-var scaffolding; corrected the orchestrator-mode overview comment to state the
  decided one-channel-per-mode contract.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — reworded two
  comment-only cross-references (deleted-function name, renamed doc section).
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` — reworded a comment-only
  cross-reference to the deleted function.
- `agent-system/extensions/core/context/contracts/wrap-up.md` — added required `summary` and
  `artifacts` fields plus semantics bullets and a schema-file pointer.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — added `summary`
  and `artifacts` to both Stage 5 handoff templates (base and skeleton), fixing the verified
  artifact-linking defect.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — substantially rewritten:
  schema-file pointer replacing the hand-maintained JSON block, folded-in undocumented fields
  (`skeleton`, `sorry_inventory`, `git_checkpoint`, `artifacts[].summary`), retired blocker shape
  replaced with the canonical one, "Two Accepted Forms" renamed to "One Write Form,
  Deprecated-But-Accepted Read Form", Handoff Writers table corrected, deprecated-form example
  recaptioned, all `skill_write_orchestrator_handoff` references reworded to generic phrasing
  (final count: 0), Outcome Channels section restated as the decided one-channel-per-mode
  contract, one stale blocker-shape example fixed, two missing-field examples fixed to pass the
  validator.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — reworded two comment-only
  cross-references to the deleted function/renamed section; made the blocker-escalation Step 3
  handoff read defensive with an explanatory comment (a fork dispatched with
  `orchestrator_mode: false` writes no handoff by contract).
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — reworded one
  comment-only cross-reference to the deleted function.
- `agent-system/extensions/core/agents/planner-hard-agent.md` — added a schema-file pointer to a
  previously-bare `wrap-up.md` cross-reference.
- `agent-system/extensions/core/index-entries.json` — corrected `contracts/wrap-up.md`'s
  `line_count` (147 → 163), a doc-lint drift discovered by `verify-deploy.sh` after Phase 4's
  additive edit.

## Decisions

- Adopted all five research-report decisions verbatim: canonical blocker shape = wrap-up/hard
  shape; canonical continuation form = flat `continuation_path`; `.orchestrator-handoff.json` is
  formally hard-mode-implement-only; `skill_write_orchestrator_handoff` deleted rather than wired
  up; `validate-handoff.sh` gained the full six-value status vocabulary plus an `artifacts` check.
- The reader-side dual-form resolution (nested `continuation_context` + flat `continuation_path`)
  is deliberately RETAINED in both engines as inert backward-compatibility, per the plan's binding
  decision — not narrowed to one form, since a pre-change handoff could still carry the nested
  shape and `test-orchestrate-triage-classify.sh` asserts the dual-form predicate.
- `test-handoff-reader-parity.sh` extracts the actual jq filter strings from both `SKILL.md` files
  via stable text anchors rather than hand-copying them, so the test catches genuine future drift
  between the two engines instead of only agreeing with itself.

## Plan Deviations

- Widened Phase 5's edit set slightly beyond the plan's declared Scope Boundary file list: also
  reworded a second, unrelated "Two Accepted Forms" comment reference in
  `orchestrate-triage-classify.sh` (comment-only, prevents a dangling cross-reference to the
  renamed doc section). Left `docs/architecture/orchestrate-state-machine.md`'s three references
  to the same renamed section untouched — genuinely out of declared scope; recorded as a follow-up
  below.
- Phase 7 surfaced and fixed an unplanned but real defect: `verify-deploy.sh`'s doc-lint gate
  failed on an `index-entries.json` line_count drift for `wrap-up.md` after Phase 4's edit. Fixed
  via the documented `generate-context-line-counts.sh --write` remediation and re-verified.
- Phase 7's deployed test suite run surfaced a pre-existing, out-of-scope defect in
  `test-reconcile-handoff-status.sh` (a `REPO_ROOT` depth-calculation bug that only manifests when
  the test is run from the deploy tree, not the source store). Verified via `git diff` that this
  task touched neither that test file nor `reconcile-task-status.sh`. Not fixed — recorded as a
  follow-up below.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: `test-validate-handoff.sh` (7/7 pass), `test-handoff-reader-parity.sh` (18/18 pass),
  `test-corroborate-phase-counts.sh` (21/21 pass, unchanged), full `core/scripts/tests/` suite
  from the source store: 12/12 pass. From the deployed tree: 12/13 pass (the one failure is the
  pre-existing, unrelated `test-reconcile-handoff-status.sh` defect above).
- `bash .claude/scripts/verify-deploy.sh`: PASS, 16/16 checks (including gate 4's task-reference
  lint over every file written in this task).
- All fenced JSON examples in `wrap-up.md`, `handoff-schema.md`, and
  `general-implementation-hard-agent.md` parse via `jq empty`; every full-handoff example (as
  opposed to explicitly-captioned fragments) passes `validate-handoff.sh`.
- Files verified: Yes — schema file, both new test scripts, and all edited files confirmed present
  and correct both in the source store and in the redeployed `.claude/` tree.

## Impacts

- `validate-handoff.sh` now correctly ACCEPTS `researched`/`planned`-status handoffs (previously a
  false-positive rejection) and correctly REJECTS handoffs missing `artifacts` or `summary`
  (previously silently accepted).
- The hard-mode implement writer template now emits `summary` and `artifacts`, closing the silent
  artifact-linking defect: a real hard-mode `implemented` handoff will now populate
  `handoff_artifact_path`, so `skill_link_artifacts` actually runs.
- `skill-base.sh` is smaller and no longer carries an unreferenced, schema-non-conformant writer
  function as an attractive nuisance for a future caller.
- `docs/architecture/handoff-schema.md` is now a pointer-plus-prose companion to the schema file
  rather than a second, independently-driftable source of truth.

## Follow-ups

- **Deliberate exclusions from this task's scope** (both explicitly named in the plan, not
  silently dropped):
  - All cslib agent files — excluded by the task description; the downstream cslib
    terminal-metadata task propagates this task's decisions to them.
  - `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — its Stage 5
    template is missing `artifacts` entirely and carries a redundant `continuation_context: null`
    now that only the flat form is canonical. Not fixed here; a real, known, unlanded gap for a
    follow-up task.
- `docs/architecture/orchestrate-state-machine.md` still references the old "Two Accepted Forms"
  section name (now "One Write Form, Deprecated-But-Accepted Read Form" in
  `handoff-schema.md`) at three sites. Genuinely out of this task's declared scope; a minor,
  low-risk cross-reference cleanup for whoever next touches that file.
- `test-reconcile-handoff-status.sh` has a pre-existing `REPO_ROOT` depth-calculation bug that
  only manifests when the test is run from the deploy tree (both of its resolution candidates are
  `REPO_ROOT`-relative with no `SCRIPT_DIR`-relative fallback, unlike every other test in the
  suite). Discovered during this task's Phase 7 verification but confirmed unrelated (zero diff
  across this task's commits); left unfixed as out of scope.
- The delegation context for this dispatch (a base-mode `general-implementation-agent` run under
  `orchestrator_mode: true`) explicitly instructed writing `.orchestrator-handoff.json`. Per the
  contract this task establishes, a base-mode (non-hard) implementation dispatch should rely
  exclusively on `.return-meta.json` and never write that file. See this dispatch's final message
  to the team lead for the full explanation and recommendation.

## References

- Plan: `specs/982_unify_orchestrator_handoff_contract/plans/01_unify-handoff-contract.md`
- Research report: `specs/982_unify_orchestrator_handoff_contract/reports/01_unify-handoff-contract.md`
- Progress files: `specs/982_unify_orchestrator_handoff_contract/progress/phase-{1..7}-progress.json`
