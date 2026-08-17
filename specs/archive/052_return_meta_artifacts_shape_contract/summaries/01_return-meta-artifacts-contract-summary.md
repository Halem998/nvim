# Implementation Summary: Task #52

- **Task**: 52 - return_meta_artifacts_shape_contract
- **Status**: [COMPLETED]
- **Started**: 2026-08-12T00:00:00Z
- **Completed**: 2026-08-12T00:00:00Z
- **Effort**: ~10 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_return-meta-artifacts-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the `.return-meta.json` `artifacts`-array shape gap across all seven planned phases: a
canonical contract fragment and normative-doc update, a new `validate-return-meta.sh` sibling
validator with `--fix`, a backfilled inline object template across every dispatchable agent that
writes `.return-meta.json` (23 of ~26 agent files touched; 3 recorded exclusions), read-side
normalization at the single consumer chokepoint with a loud notice and recorded defect, closure of
the handoff-present `ARTIFACTS_SHAPE_MISMATCH` detection hole in both orchestrator engines, and a
new deploy-time lint Check F. The explicit strict-contract-plus-normalizing-chokepoint decision the
task description required is recorded and implemented exactly as specified.

## What Changed

- `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` — new
  canonical fragment: copyable object-shaped template, classification rule, path-segment
  type-inference table.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `artifacts (required)`
  section now states the bare-string prohibition and the four-layer posture table.
- `agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh` — new shared anchor:
  `infer_artifact_type`, `normalize_artifacts_array`.
- `agent-system/extensions/core/scripts/validate-return-meta.sh` — new strict validator with
  `--fix` (opt-in, atomic, never implicit).
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` — new, 14 cases.
- 20 agent files backfilled with the object-shaped template (core, cslib, filetypes, lean,
  python, typst, z3, latex, email) — see the plan's Phase 3/4 checklists for the exact set.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_read_metadata` normalizes
  read-side only, emits a loud stderr banner, records `ARTIFACTS_SHAPE_MISMATCH`.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — artifact/status reads
  routed through `skill_read_metadata` instead of duplicated `jq` expressions.
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — inline comment
  documenting the deliberate raw-read (never normalized here, by design).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` — advisory `ARTIFACTS_SHAPE_MISMATCH` probe added to the
  handoff-present Stage 5 branch on both engines; residual-gap note rewritten.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new Check F
  (object-shaped `artifacts` template presence), registered in `main()`.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — 4 new Check F
  assertions (13/13 total).
- `agent-system/extensions/core/merge-sources/claudemd.md` — new `validate-return-meta.sh`
  Utility Scripts entry; `lint-agent-contracts.sh` entry mentions Check F.
- `agent-system/extensions/core/manifest.json` — registered 3 new Phase 2 script files under
  `provides.scripts` (a genuine defect surfaced by `check-extension-docs.sh`, not deploy drift).
- `agent-system/extensions/core/index-entries.json` — corrected `return-metadata-file.md`'s
  `line_count` (596 -> 615) via `generate-context-line-counts.sh --write`.

## Decisions

- The four-layer strict-contract-plus-normalizing-chokepoint posture from the task description
  was implemented exactly as specified; no re-litigation.
- `code-reviewer-agent.md` and `synthesis-agent.md` were found, by reading each file in full, to
  never write `.return-meta.json` at all — recorded as deliberate exclusions (mirroring the
  `literature-agent` precedent the plan itself named), not templated.
- Check F's required-key extraction reads the fragment's fenced JSON block at runtime (never
  hardcoded), matching Check C's own mechanism for the no-task-references bullet.
- Two genuine source-store defects surfaced by `check-extension-docs.sh` (missing
  `provides.scripts` registrations, a stale `index-entries.json` line count) were fixed as part
  of this task, since they are real defects independent of deploy timing — distinct from the
  expected "deployed tree hasn't caught up with source store yet" drift, which was left
  unresolved because this implementer is not the sanctioned automated deploy caller (see
  `context/patterns/regeneration-is-manual-only.md`).

## Plan Deviations

- **Phase 3**: `code-reviewer-agent.md` and `synthesis-agent.md`, both named in the plan's Scope
  Hypothesis as expected template targets, were found on read-through to never write
  `.return-meta.json` and were excluded instead of templated (recorded in the plan's Phase 3
  checklist and in `progress/phase-3-progress.json`'s `deviations` array).
- **Phase 6**: the plan's Scope Hypothesis asserted `skill-orchestrate-hard/SKILL.md` already
  computed `ARTIFACTS_SHAPE_MISMATCH` on its handoff-present branch. A grep-only pass initially
  agreed with that hypothesis; reading the branch in full (exactly what the Scope Hypothesis
  itself instructed) showed the same structural gap as base mode. The same advisory probe was
  applied to hard mode too, and the residual-gap note text was corrected before finalizing
  (recorded in `progress/phase-6-progress.json`'s `deviations` array).

## Verification

- Build: N/A (no build step for this task type)
- Tests: Passed — `run-all.sh`: 42/42; `test-validate-return-meta.sh`: 14/14;
  `test-lint-agent-contracts.sh`: 13/13; `test-skill-base-lifecycle.sh`: 18/18;
  `test-handoff-reader-parity.sh`: 19/19
- Files verified: Yes
- Regression checks (manual, targeted): bare-string fixture through `skill_read_metadata` recovers
  the path, emits the notice, and leaves the on-disk file byte-identical; the same fixture through
  `orchestrate-recover-outcome.sh` still reports `ARTIFACTS_SHAPE_MISMATCH`; the handoff-present
  advisory probe (both engines) fires correctly end-to-end; deliberately reverting one agent's
  template makes Check F fail naming that exact file, and restoring it returns to a clean pass.

## Impacts

- Every future dispatchable agent added to the system that writes `.return-meta.json` is now
  gated by Check F at lint time — a missing or malformed `artifacts` template becomes a
  deploy-time failure rather than a silent production defect discovered after the fact.
- A bare-string `artifacts` array, if it recurs, is now recovered (never silently discarded) at
  the shared consumer chokepoint, with the occurrence made loud and recorded rather than free.
- The handoff-present orchestration path (both base and hard engines) can now surface an
  `ARTIFACTS_SHAPE_MISMATCH` defect it previously could not see at all.

## Follow-ups

- The deployed `.claude/` tree does not yet reflect this task's source-store changes.
  `check-extension-docs.sh`/`verify-deploy.sh` will continue to report the expected
  "deployed script content drift" / "never deployed" findings for the modified and new core
  scripts until the next authorized regeneration (interactive `[Reload All]`/`[Regenerate]`, or
  the sanctioned `skill-orchestrate` inter-cycle checkpoint) runs. This is expected, not a defect
  — see `context/patterns/regeneration-is-manual-only.md`.
- A pre-existing, unrelated `validate-state.sh --deep` finding was observed against this task's
  own `specs/state.json` entry (`blockers`/`priority` fields not in the schema's allowed
  entry-field set). It predates this task's implementation work and is out of this plan's
  Non-Goals-bounded scope; left unaddressed.
- The reserved Check D (required body sections) and Check E (terminal-metadata presence) in
  `lint-agent-contracts.sh` remain deferred, unimplemented follow-up work, unchanged by this task.
- The `.return-meta.json` deletion-ordering defect (`fix_return_meta_lifecycle_ordering`) named as
  independent by the task description remains untouched, as planned.

## References

- Plan: `specs/052_return_meta_artifacts_shape_contract/plans/01_return-meta-artifacts-contract.md`
- Research: `specs/052_return_meta_artifacts_shape_contract/reports/01_return-meta-artifacts-shape.md`
- Progress files: `specs/052_return_meta_artifacts_shape_contract/progress/phase-{1-7}-progress.json`
