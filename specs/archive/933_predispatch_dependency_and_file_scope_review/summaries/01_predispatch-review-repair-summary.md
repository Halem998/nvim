# Implementation Summary: Task #933

**Completed**: 2026-07-27
**Duration**: single dispatch, all 6 phases

## Overview

Extracted a new shared script, `orchestrate-predispatch-review.sh`, that reads
`specs/state.json` directly and reports four classes of pre-dispatch defect (dropped dependency
edges, null metadata fields, self-modification declaration coarseness, and missing cross-batch
serializing edges) before `commands/orchestrate.md` narrows the raw dependency graph to an
intra-batch-only view. The script is wired identically into both the live `/orchestrate` path
(Step 1.5, advisory-loud, non-blocking) and the `--dry-run` report (new section 7), so the two
surfaces cannot drift. An opt-in `--repair` flag, reachable only by direct invocation, normalizes
literal-null `dependencies`/`file_scope` fields.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — new script:
  Class A (raw dependency edge classification: `intra_batch`/`out_of_batch_live`/
  `out_of_batch_terminal`/`nonexistent`), Class B (literal-null metadata defects on
  `dependencies`/`file_scope`/`title`/`topic`), Class C (self-modification with
  declaration-coarseness diagnosis, consuming `orchestrate-batch-admit.sh` verdicts), Class D
  (missing cross-batch serializing edges, suggested never written), and an opt-in `--repair`
  flag scoped to `dependencies`/`file_scope` null-to-`[]` normalization only.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — added Step 8 (calls the
  new script) and report section 7 ("Pre-dispatch review"), plus a "Checks run" line and header
  Composition/Report-sections updates. Sections 1-6 unchanged in order and numbering.
- `agent-system/extensions/core/commands/orchestrate.md` — inserted Step 1.5 (Pre-Dispatch
  Review) between Step 1 (Batch Validation) and Step 2 (Dependency Graph Construction); updated
  Step 2's prose to note the intra-batch restriction is a wave-assignment concern, not a silent
  discard, since Step 1.5 already reported the raw edges.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — added a Stage MT-1
  cross-reference noting raw dependency review already happened upstream at Step 1.5; no code
  change (confirmed `dependency_graph` is received pre-built, never rebuilt by this stage).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — updated
  Non-Negotiable 3 to record that its warn-loudly and distinguish-subcases clauses are now
  satisfied (with an explicit, honest note that the exclude-by-default clause is NOT newly
  implemented on the live dispatch path by this review-only stage); resolved the Open Design
  Fork ("exclude the dependent task by default; never auto-expand the batch").
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — added
  `orchestrate-predispatch-review.sh` as a fourth entry on the "Read by" list.
- `agent-system/extensions/core/manifest.json` — registered the new script in
  `provides.scripts` (alphabetically ordered).

## Decisions

- Class B's checked field set (`dependencies`, `file_scope`, `title`, `topic`) was confirmed by
  surveying live `specs/state.json`: zero literal nulls currently exist on any field across all
  48 `active_projects[]` entries, confirming the plan's Defect 2 is a real but currently dormant
  class. `artifacts` (also array-typed) was surveyed but excluded — it is not consumed by any
  admission-relevant code path.
- `--repair`'s state write reuses `update-task-status.sh`'s exact atomicity convention
  (write-to-temp-then-`mv`, validated with `jq empty`) but deliberately does NOT acquire the
  `specs/.scope-lock` mutex, since `--repair` is direct-invocation-only and never called from a
  live or automated path.
- The Open Design Fork was resolved as a recorded design decision ("exclude by default, never
  auto-expand"), not as a claim that live-path exclusion for out-of-batch dependency edges is
  newly implemented — that residual gap is explicitly documented as still open, since the plan's
  own Non-Goals bar this review stage from becoming a fifth admission gate.
- `index-entries.json` was left unmodified with a recorded reasoned exclusion (Phase 6): no new
  file was introduced under `context/` by this task.

## Plan Deviations

- None (implementation followed plan). One bug was found and fixed during fixture testing
  (Phase 3): the initial `--repair` diff/write jq filters used
  `select(($cands | index(.project_number)) != null)`, which re-pipes `.` into `$cands` inside
  `index()`'s argument and raises "Cannot index array with string". Fixed by binding
  `.project_number as $pn` first, matching the pattern already used elsewhere in the script. This
  was corrected within Phase 3 before it closed, not deferred.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: `bash -n` passed on both scripts; functional testing performed against a seeded fixture
  (isolated `.claude/scripts/` + `specs/state.json` fixture under a scratch directory) covering
  all four defect classes, the degraded-admit-predicate path, and `--repair`'s normalize/warn
  split. End-to-end verified against live tasks 887/933/934/935 via both the deployed
  `orchestrate-dry-run-report.sh` (all 7 sections, section 7 present with live findings) and a
  direct `orchestrate-predispatch-review.sh` invocation.
- `check-extension-docs.sh`: exits 0 ("PASS: all extensions OK") after a headless redeploy
  (`deploy-headless.sh`, `verify-deploy.sh` PASS with 0 failures). This redeploy also
  incidentally resolved two pre-existing, task-933-unrelated drift failures
  (`orchestrate-triage-classify.sh`, `skill-base.sh`) left over from a prior task's
  un-redeployed source-store changes.
- `specs/state.json`: confirmed byte-identical across every non-`--repair` invocation via
  `git diff --stat` (only the pre-existing preflight status transition, not-started ->
  implementing, appears in the diff).
- `--repair` unreachable from any `/orchestrate` invocation: confirmed by grep across
  `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, and
  `scripts/parse-command-args.sh` — no matches.
- Files verified: Yes (all six changed/created files confirmed present and syntactically valid;
  `manifest.json` and `index-entries.json` both parse via `jq .`).

## Notes

- The residual live-path gap for excluding an out-of-batch, non-terminal dependency (Class A's
  `out_of_batch_live`/`nonexistent` subcases) from actual dispatch remains open — the guardrails
  doc now names this honestly rather than overclaiming full Non-Negotiable 3 satisfaction. Closing
  it would require either extending `dependency_graph` construction to represent out-of-batch
  edges or adding a dedicated exclusion check, both explicitly out of this task's scope (Non-Goal:
  "Making the review stage a fifth admission gate").
- Follow-up candidates recorded in the plan (unchanged, not actioned by this task): a test harness
  at `scripts/tests/test-orchestrate-predispatch-review.sh`, and the pre-existing
  `index-entries.json` coverage gap for several `context/patterns/` and `context/reference/`
  files.
