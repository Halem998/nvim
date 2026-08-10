# Implementation Summary: Task #993

- **Task**: 993 - Promote SCHEMA_CONFORMANCE_GATE_MODE from advisory to hard
- **Status**: [COMPLETED]
- **Started**: 2026-08-09T00:00:00Z
- **Completed**: 2026-08-09T00:30:00Z
- **Effort**: 0.5 hours
- **Dependencies**: 987, 990, 992 (all landed; empirically re-confirmed by research and by this implementation)
- **Artifacts**: plans/01_promote-schema-gate-hard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Flipped `SCHEMA_CONFORMANCE_GATE_MODE`'s default from `advisory` to `hard` in
`agent-system/extensions/core/scripts/check-extension-docs.sh`, rewrote its preceding comment
block to past tense recording completed remediation (mirroring `INDEX_TRUTH_GATE_MODE`'s
post-promotion style), and dropped the now-stale `, defaults advisory` qualifier from the two
top-of-file header rule-list bullets describing Rules T and U. Exactly one fragment was
behavior-changing; everything else was comment/header prose, matching the plan's scope
hypothesis precisely (verified: `SCHEMA_CONFORMANCE_GATE_MODE` had exactly one default-assignment
occurrence and one `== "hard"` test; `defaults advisory` had exactly two occurrences).

## What Changed

- `agent-system/extensions/core/scripts/check-extension-docs.sh` — `SCHEMA_CONFORMANCE_GATE_MODE`
  default flipped from `${SCHEMA_CONFORMANCE_GATE_MODE:-advisory}` to
  `${SCHEMA_CONFORMANCE_GATE_MODE:-hard}`; its preceding comment block rewritten to past tense
  recording that both follow-on remediation efforts (the index-entries.json schema migration and
  the EXTENSION.md slim-down) have landed and a hard-mode dry run confirmed zero Rule T and zero
  Rule U findings across all 19 extensions, with guidance that the advisory override remains
  available for temporary local debugging only; the two top-of-file header bullets describing
  Rules T and U had their `, defaults advisory` clause dropped, matching the sibling
  `INDEX_TRUTH_GATE_MODE` bullets' style (no `defaults X` qualifier at all).

## Decisions

- Kept `schema_conformance_report()` and every Rule T/U call site untouched, per the plan's
  non-goal — the `hard -> fail; else -> info ADVISORY` branch was already generic and needed no
  changes.
- Followed the plan's explicit instruction not to reword the header bullets to "defaults hard";
  removed the qualifier entirely to match the `INDEX_TRUTH_GATE_MODE` sibling bullets' precedent.

## Plan Deviations

- **Phase 2, "re-run the verification bar" task** altered: `REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/check-extension-docs.sh` exits 1 rather than the plan's
  expected 0, but the single FAIL present ("deployed script content drift (deployed != extension
  source): scripts/check-extension-docs.sh") is Rule F (`check_deployed_script_drift`) firing on
  this script's own self-reference — the deployed `.claude/scripts/check-extension-docs.sh` has
  not yet been regenerated to match the source-store edits made in this task, which is a
  pre-documented structural gotcha whenever `check-extension-docs.sh` itself is edited (see
  `.memory/10-Memories/MEM-workflow-check-extension-docs-rules.md`'s "Self-reference hazard"
  section). Regenerating `.claude/` via `deploy-headless.sh` is restricted to
  `skill-orchestrate`'s own Stage MT-3 redeploy checkpoint per that script's own header comment,
  not a general implementation agent, so this was left for the orchestrator's own redeploy step
  rather than run here. Confirmed instead via targeted checks: zero `Rule T:`/`Rule U:` findings
  in the run log, all 19 extensions PASS in the per-extension summary table (only `core` shows
  FAIL, solely due to Rule F), and the `SCHEMA_CONFORMANCE_GATE_MODE=advisory` override run
  produces the identical single Rule F FAIL with zero schema findings either way — proving the
  plan's substantive claim (all extensions pass Rule T/U under hard mode) holds, and that the
  override escape hatch still functions correctly.
- **Phase 2, "run check-task-references.sh" task** altered: the source-store copy of
  `check-task-references.sh` refuses to run outside a deployed `scripts/` tree by design (it
  computes repo root via `../..` from its own location, which is bogus from
  `agent-system/extensions/core/scripts/`). Ran the deployed `.claude/scripts/check-task-references.sh`
  instead — identical script content, the sanctioned invocation path per its own error message.
  Result: PASS, 0 unexempted task-reference occurrences across all 4 scanned trees.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: `bash -n` parses clean on the edited file; `check-task-references.sh` (deployed copy)
  PASS with 0 occurrences; `SCHEMA_CONFORMANCE_GATE_MODE=advisory` override run confirmed
  functional (same Rule F FAIL, zero schema findings, identical to the hard-mode default run)
- Files verified: Yes — `grep -n 'SCHEMA_CONFORMANCE_GATE_MODE:-'` shows `:-hard` and no remaining
  `:-advisory`; `grep -c 'defaults advisory'` returns 0

## Impacts

- `SCHEMA_CONFORMANCE_GATE_MODE` now defaults to `hard` with no environment override needed,
  meaning Rules T and U (index-entries.json schema conformance and the EXTENSION.md 60-line
  limit) now block `verify-deploy.sh` repo-wide on any future regression, matching the
  `ORPHAN_GATE_MODE` / `INDEX_TRUTH_GATE_MODE` precedent already accepted for the sibling gates.
- The gate's comment prose and header bullets now accurately describe the gate's current
  (post-remediation) state rather than a stale pre-remediation description.

## Follow-ups

- `extension-slim-standard.md` (line ~9-12) still reads "defaulting `advisory`" and is now stale
  prose; it was outside this task's `file_scope` and is a candidate one-line follow-up.
- The pre-existing `test-index-entries-schema.sh` failure ("Rule U did not fire on a 61-line
  EXTENSION.md") is unchanged by this task and remains an unrelated open item — it was outside
  `file_scope` per the plan's non-goals.
- The deployed `.claude/scripts/check-extension-docs.sh` copy has not yet been regenerated to
  match this task's source-store edit, producing a single Rule F self-reference drift FAIL when
  the gate is run against the current deploy tree. This resolves automatically at the next
  deploy-tree regeneration (the orchestrator's own redeploy checkpoint, or a manual
  `<leader>al` "Reload All"/"Regenerate", or `bash scripts/deploy-headless.sh`); no action is
  needed from this implementation task.

## References

- Plan: `specs/993_promote_schema_gates_to_hard/plans/01_promote-schema-gate-hard.md`
- Research: `specs/993_promote_schema_gates_to_hard/reports/01_promote-schema-gate-hard.md`
- Modified: `agent-system/extensions/core/scripts/check-extension-docs.sh`
