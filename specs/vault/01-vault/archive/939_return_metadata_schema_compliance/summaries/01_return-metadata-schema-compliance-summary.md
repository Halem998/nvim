# Implementation Summary: Fix Off-Schema .return-meta.json Writes Breaking Orchestrator Recovery

**Task**: 939
**Status**: COMPLETED
**Started**: 2026-07-28
**Completed**: 2026-07-28
**Artifacts**: specs/939_return_metadata_schema_compliance/plans/01_return-metadata-schema-compliance.md, specs/939_return_metadata_schema_compliance/summaries/01_return-metadata-schema-compliance-summary.md
**Standards**: source-store-deploy-boundary, no-task-references-in-deliverables, plan-format.md, status-markers.md, artifact-management.md

## Overview

Two verified writer-side defects caused agents to write `.return-meta.json` files that do not
conform to the schema its readers assume: phase-count fields written at the top level instead of
nested under `.metadata`, and an `artifacts` array of bare strings instead of objects. Both defects
degraded silently — the recovery script (`orchestrate-recover-outcome.sh`) returned 0/0 phases and
an empty artifact path from a present, parseable file, with no signal that anything was wrong. All
seven plan phases are complete: the ambiguous writer instructions that caused each shape are fixed,
an explicit decision against a schema-permissive reader fallback is recorded in the script's own
header, one general "reader got an empty or zero value from a present, parseable file" detection
signal now covers both defects, and that signal is consumed and escalated in the one orchestrator
branch (the recovered=true path) that structurally could not see the pre-existing phase-marker
grep. Every phase's claim was confirmed by running the real recovery script (or an extracted,
`bash -n`-verified copy of the new orchestrator bash blocks) against constructed scratch inputs —
never by reading code alone. Deployment to `.claude/` was deliberately deferred per the delegation
constraint; the orchestrator currently running this task executes from an already-deployed tree
from an earlier session, and no redeploy was performed at any point during this implementation.

## What Changed

Twelve source-store files (all under `agent-system/extensions/core/`) plus this task's own
`specs/` artifacts. This is **three more than the plan's own Phase 7 Scope Hypothesis anticipated**
(it predicted nine); the excess is Phase 4's own declared, in-plan widening from one file to five,
recorded explicitly at the time (see "Item B" below) — not an undeclared drift.

- `agents/general-implementation-agent.md` — Stage 7's ambiguous "Agent-specific metadata fields:
  `phases_completed`, `phases_total`" sentence replaced with an explicit statement that these two
  fields nest **inside `metadata`**, contrasted against `.orchestrator-handoff.json`'s always-top-level
  rule for the same field names; a worked `implemented`-case JSON example added (previously only a
  `partial`-case example existed).
- `agents/general-implementation-hard-agent.md` — Stage 7's clause split so `phases_completed`/
  `phases_total` are explicitly nested under `metadata` while `modified_files` stays top-level, with
  an explicit note that Stage 5's top-level shape (shown a few dozen lines earlier, for
  `.orchestrator-handoff.json`) does not apply here. Also gained the `artifacts` object-array shape
  instruction (Phase 4 widening — see below).
- `skills/skill-implementer-hard/SKILL.md` — Stage 6's two postflight reads corrected from
  `jq -r '.phases_completed // 0'` / `.phases_total` (top-level, broken by the fix above) to
  `.metadata.phases_completed // 0` / `.metadata.phases_total // 0`, matching the already-correct
  sibling `skill-implementer/SKILL.md` (verified read-only, unchanged).
- `skills/skill-team-implement/SKILL.md` — a disambiguating sentence added next to the Stage 13
  example, which was independently confirmed ALREADY correctly nested under `"metadata"` (the task
  description's claim that it showed a top-level shape was refuted by direct inspection and NOT
  "corrected").
- `context/formats/return-metadata-file.md` — a new "`phases_completed`/`phases_total` nesting
  collision (cross-file)" section added, mirroring the style of the existing "Three distinct
  vocabularies" table, contrasting `.return-meta.json`'s nested rule against
  `.orchestrator-handoff.json`'s always-top-level rule.
- `agents/general-research-agent.md` — a local, inline `artifacts` object-array shape instruction
  with a minimal worked example added at Stage 7 (this agent had ZERO prior mention of the shape —
  the exact gap Defect 2 exploited).
- `agents/general-research-hard-agent.md`, `agents/planner-agent.md`, `agents/planner-hard-agent.md`
  — the same minimal `artifacts` shape instruction added (Phase 4 widening — see "Item B" below).
- `scripts/orchestrate-recover-outcome.sh` — header gained an Item C decision record (no permissive
  top-level-phases fallback) and expanded output-field docs; `emit()` gained two new positional
  parameters (`${12}`=`evidence_suspect`, `${13}`=`evidence_reason`) and two new emitted JSON
  fields; a general detection signal (`PHASES_ZERO_ON_SUCCESS`, `ARTIFACTS_SHAPE_MISMATCH`) is now
  computed on the recovered=true path, folding a captured jq-failure exit code into the artifacts
  signature as corroboration rather than discarding it.
- `skills/skill-orchestrate/SKILL.md` — Stage 5's recovered=true branch and its Stage MT-4
  multi-task mirror both gained an evidence-corroboration block: when the recovery script reports
  `PHASES_ZERO_ON_SUCCESS` for a claimed `implemented` status, the block reuses the pre-existing
  phase-marker grep idiom verbatim; on corroboration it sets `plan_markers_verified="true"` and
  corrects the phase counts (with a loud `[UNVERIFIED PHASES CORROBORATED]` banner); on
  non-corroboration it leaves everything untouched (the false-positive guard). The Context Flatness
  Constraint's "Recovery exception (phase-marker grep)" bullet was rewritten to name both now-reachable
  branches, and a stale comment claiming the recovered path "always" sets `plan_markers_verified="absent"`
  was corrected.
- `skills/skill-orchestrate-hard/SKILL.md` — the identical corroboration block applied to its
  mirrored Stage 5 recovery branch, preserving the `[hard-orchestrate]` log prefix; the analogous
  stale comment corrected.

## Decisions

- **Item B (artifacts-shape instruction location)**: a local, inline instruction was added at each
  writer's own Stage 7 rather than only making the `@`-reference to the format doc more prominent,
  because Defect 2 already falsified "the reference alone is sufficient" — the research agent wrote
  a bare-string array despite the reference existing.
- **Item B footprint widening (Phase 4)**: the phase's own Scope Hypothesis explicitly instructed
  widening if the grep found other `.return-meta.json` writers equally silent on the `artifacts`
  shape. It did: `general-implementation-hard-agent.md`, `general-research-hard-agent.md`,
  `planner-agent.md`, and `planner-hard-agent.md` all write the file with zero local shape mention.
  Each received the identical minimal treatment, per the plan's own contingency instruction — this
  widened Phase 4's edit set from the one declared file to five, recorded explicitly at the time
  (see `progress/phase-4-progress.json`'s `deviations` entry) rather than silently.
- **Item C (no schema-permissive reader fallback)**: `orchestrate-recover-outcome.sh` deliberately
  does NOT accept a top-level `phases_completed`/`phases_total` shape as a fallback. The two
  documented read locations (`.metadata.*`, `.partial_progress.*`) remain exhaustive by design. A
  permissive fallback would silently bless an off-schema write instead of keeping writer drift
  visible; the `evidence_suspect`/`evidence_reason` fields are the evidence-based alternative —
  they surface the contradiction without correcting the underlying emitted value. This is recorded
  in the script's own header comment, not only in this summary.
- **`skill-implementer-hard/SKILL.md` ownership** (recorded in the plan, executed in Phase 2): this
  file is outside task 939's declared `file_scope` but inside the next task's. Task 939 took the
  two-line reader fix anyway because the coupling is a correctness invariant of Phase 2's own writer
  edit — deferring it would ship a change that breaks the non-orchestrator `/implement --hard` phase
  gate and depend on a different, later task to restore it.
- **Non-goal held**: no change was made to `.orchestrator-handoff.json`'s own top-level phase-field
  rule (correct as-is), and no existing read location in `orchestrate-recover-outcome.sh` was
  redefined — only two new fields were added.
- **Deployment deliberately deferred**: per the delegation constraint, no `deploy-headless.sh` run,
  no picker "Load Core", no `load_all_globally` invocation occurred. All verification in Phases 5-7
  ran directly against the source-store script and scratch extractions of the source-store skill
  files' bash blocks — never against the deployed `.claude/` tree.

## Before/After Table (verification by construction)

All three fixtures below were run against the REAL `orchestrate-recover-outcome.sh` at
`agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`, both before any Phase 2-6
edit (Phase 1 baseline) and after all edits landed (Phase 7 final). Fixtures live under the session
scratchpad (`939-verify/{control_correct,defect1_topmeta,defect2_barestrings}/`), never inside the
repository.

| Fixture | Field | Before (Phase 1) | After (Phase 7) |
|---|---|---|---|
| control (correct shape) | `phases_completed`/`phases_total` | 6 / 6 | 6 / 6 (unchanged) |
| control | `evidence_suspect` / `evidence_reason` | field did not exist | `false` / `"NONE"` |
| control | exit code | 0 | 0 (unchanged) |
| defect1 (top-level phases) | `phases_completed`/`phases_total` | 0 / 0 | 0 / 0 (**unchanged by design** — Item C holds: the off-schema value is never silently corrected by the script itself) |
| defect1 | `evidence_suspect` / `evidence_reason` | field did not exist | `true` / `"PHASES_ZERO_ON_SUCCESS"` |
| defect1 | exit code | 0 | 0 (unchanged) |
| defect2 (bare-string artifacts) | `artifact_path` | `""` | `""` (**unchanged by design**) |
| defect2 | stderr | 3× `jq: error ... Cannot index string with string` | identical 3 lines still present (not suppressed) — but the underlying jq failure now also feeds `evidence_suspect` |
| defect2 | `evidence_suspect` / `evidence_reason` | field did not exist | `true` / `"ARTIFACTS_SHAPE_MISMATCH"` |
| defect2 | exit code | 0 | 0 (unchanged) |

**Orchestrator corroboration harness** (Phase 6/7, extracted Stage 5 block run against the
`defect1_topmeta` fixture's real recovery output plus three constructed scratch plan files):

| Plan fixture | `recovered_completed`/`recovered_total` | Result |
|---|---|---|
| All 3 phase headings `[COMPLETED]` | 3/3 | **Corroborated**: `plan_markers_verified` flips `absent` → `true`; `phases_completed`/`phases_total` corrected to 3/3; `[UNVERIFIED PHASES CORROBORATED]` banner emitted |
| Zero `### Phase N:` headings | 0/0 | Non-corroborating: `plan_markers_verified` stays `absent`; counts stay 0/0 |
| Genuine partial plan (1/3 `[COMPLETED]`) | 1/3 | Non-corroborating (false-positive guard holds): `plan_markers_verified` stays `absent`; counts stay 0/0 |

## Impacts

- A completed implementation task whose dispatch skips writing `.orchestrator-handoff.json` (the
  documented base-mode behavior) and whose `.return-meta.json` happens to carry the old off-schema
  top-level phase shape will no longer be silently stranded at 0/0 phases when its plan file's
  phase headings corroborate genuine completion — the orchestrator now escalates on evidence.
  Recovery scripts and skills still refuse completion when there is no corroborating evidence,
  preserving the fail-closed default.
- `/implement --hard` (non-orchestrator) phase gating in `skill-implementer-hard/SKILL.md` is fixed
  concurrently with the writer change that would otherwise have broken it — no regression window.
- Four additional agent definitions (`general-implementation-hard-agent.md`,
  `general-research-hard-agent.md`, `planner-agent.md`, `planner-hard-agent.md`) now carry an
  explicit `artifacts` shape reminder, closing the same latent gap Defect 2 exploited before it can
  recur in those writers.
- `general-implementation-hard-agent.md` is a file the next task (940) will also edit, for an
  unrelated concern (summary metadata headers) — no overlap with this task's edits, flagged
  explicitly per the delegation's "note on what comes next."

## Follow-ups

- None required to close this task. The plan's non-goals explicitly exclude retroactively repairing
  any existing on-disk `.return-meta.json` file (ephemeral, deleted after postflight) and redefining
  the format doc's schema itself.
- Deployment to `.claude/` remains pending (deliberately deferred per delegation constraint) — a
  future deploy step, outside this task's scope, will pick up these source-store changes.

## References

- Plan: `specs/939_return_metadata_schema_compliance/plans/01_return-metadata-schema-compliance.md`
- Research report: `specs/939_return_metadata_schema_compliance/reports/01_return-metadata-schema-compliance-research.md`
- Progress files: `specs/939_return_metadata_schema_compliance/progress/phase-{1..6}-progress.json`
- Modified source-store files (12): see "What Changed" above; full list also in
  `git diff --stat efb398458..HEAD --name-only` for this task's six phase commits
  (`5f8e9bcee`..`11ea785e0`).
