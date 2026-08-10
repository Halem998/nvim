# Implementation Summary: Task #961

- **Task**: 961 - Add staleness detection to the orchestrator loop-guard resume path
- **Status**: [COMPLETED]
- **Started**: 2026-08-06T00:00:00Z
- **Completed**: 2026-08-06T01:40:00Z
- **Effort**: ~2 hours
- **Dependencies**: 960 (established the sentinel-region + fixture-test pattern in the same SKILL.md; already complete)
- **Artifacts**: plans/01_loop-guard-staleness-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added an OR-combined operational-staleness detector to `skill-orchestrate-hard/SKILL.md`'s Stage
2 resume path. A stale `.orchestrator-loop-guard` is now archived aside (never deleted) with a
loud named notice before the pre-existing fresh-init branch reinitializes at cycle 0, closing the
gap where any syntactically valid guard — however old or superseded — was previously trusted
unconditionally. `.orchestrator-churn-state.json` is co-archived under the loop guard's inherited
verdict. Base-mode `skill-orchestrate/SKILL.md` is unchanged and explicitly documented as such.

## What Changed

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — new
  "Operational staleness: a second, orthogonal freshness axis" subsection recording the three
  OR-combined signals, the 7-day mtime default and its rationale, the explicit anti-`session_id`
  defense, and the churn-state inheritance decision; updated the `.orchestrator-loop-guard` and
  `.orchestrator-churn-state.json` Class Table Reader cells; scoped the Rationale section's
  git-restoration paragraph explicitly to base mode and added the hard-mode-now-gates statement;
  added the two new archive filename patterns to the "reviewed and deliberately excluded"
  paragraph alongside `.stray-handoff-{timestamp}.json`.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — added a
  `current_plan_version` computation immediately after `mkdir -p "$TASK_DIR"`; seeded
  `plan_version` into the fresh-init `jq -n` payload; refreshed `plan_version` at the Stage 3b
  per-cycle update; inserted a new `loop-guard-staleness`-sentinel-delimited region implementing
  the three-signal detector, the archive-aside `mv` (with non-fatal `WARNING:` fallback), and the
  churn-state co-archive; added an explanatory prose paragraph pointing at the policy doc. The
  pre-existing `if [ -f "$loop_guard_file" ] ... else ... fi` resume/fresh-init branch and the
  churn-state block immediately below it are byte-identical to before (confirmed via `git diff`)
  — the detector only ever `mv`s a stale file aside and lets both blocks fall through to their
  existing fresh-init branches naturally.
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` (new) — fixture suite
  covering all nine declared cases (current guard, ordinary cross-turn resume, max_cycles drift,
  plan-lineage drift, mtime backstop, old-format guard, no `plans/` directory, churn co-archive,
  churn absent) plus `bash -n`/`bash -u` syntax checks and two structural assertions on the
  fresh-init payload. 28/28 assertions pass, exit 0.
- `agent-system/extensions/core/manifest.json` — added
  `"tests/test-loop-guard-staleness.sh"` to `provides.scripts`, in sorted position.
- `agent-system/extensions/core/index-entries.json` (unplanned fifth file, justified below) —
  corrected the `standards/orchestrator-runtime-files.md` entry's `line_count` from the
  now-stale `184` to the actual `272`, via the sanctioned `generate-context-line-counts.sh`
  maintenance path, since this task's own Phase 1 edit made the declared value stale.

## Decisions

- **mtime default: 7 days.** The guard is rewritten by the per-cycle Stage 3b update, so its
  mtime tracks last *cycle activity*, not creation. Seven days means no orchestration cycle
  touched it across an entire working week — far outside any plausible conversational-resume gap,
  and comfortably below the observed 13-day failure that motivated this task. It is a backstop,
  not the primary gate: the two drift signals (`max_cycles`, `plan_version`) catch a superseded
  guard regardless of age. Env-overridable via `ORCHESTRATOR_LOOP_GUARD_STALE_DAYS`.
  `ORCHESTRATOR_SESSION_REAP_MIN`'s 4-hour default was deliberately rejected as an anchor — it
  protects a much shorter-lived class of file (the in-flight session registry).
- **Placement, not restructuring** (deviation from the research report's Recommendation 2, decided
  during planning): the detector runs *before* the existing `if [ -f "$loop_guard_file" ] ... else
  ... fi` block rather than inside its present-and-valid branch, and archives the stale guard
  aside via `mv` so the pre-existing `[ -f ]` test naturally evaluates false and the unmodified
  fresh-init branch runs at cycle 0. This avoids a third duplicated `jq -n` payload site
  (eliminating the payload-drift risk the report flagged), keeps the region free of any
  `task-lock.sh` dependency (directly executable in a fixture harness), and produces a much
  smaller diff.
- **`.orchestrator-churn-state.json` inherits the loop guard's verdict** rather than deriving an
  independent detector, justified by the Class Table's already-documented 1:1 lifecycle coupling
  (co-created in the same Stage 2 block, co-removed only at full-loop termination). It has no
  `max_cycles`-equivalent schema constant of its own to drift-check.
- **Anti-`session_id` defense**: `session_id` is regenerated on every `/orchestrate` invocation
  regardless of whether any work progressed, so gating on it would flag every legitimate
  conversational resume — a 100% false-positive rate by construction. None of the three chosen
  signals shares that property: `max_cycles` changes only when the skill file is edited, the
  latest-plan basename changes only when a plan artifact is actually written, and mtime advances
  only on a real Stage 3b cycle update. This reasoning is recorded in
  `orchestrator-runtime-files.md` and is the same rationale the churn file's own pre-existing
  observational `session_id` tracking already documents, applied to a new gate rather than
  invented fresh.

## Plan Deviations

- **Phase 5, `check-extension-docs.sh` exit-0 criterion** altered: the command exits 1, not 0.
  Five FAIL lines remain after this task's changes — one `index-entries.json` line_count mismatch
  on `formats/plan-format.md` and four "deployed script content drift" FAILs on
  `command-route-skill.sh`, `phase-heading-patterns.sh`, `update-task-status.sh`, and
  `verify-deploy.sh`. All five are pre-existing and unrelated to this task, verified by diffing
  against commit `c3323d116` ("task 960: complete orchestration", the tip immediately preceding
  this task's first change): `plan-format.md`'s `line_count` mismatch (406 declared vs. 423
  actual) already existed at that commit, and `git diff c3323d116..HEAD --stat` over the four
  drifted scripts produced zero output — this task never touched them. The ONE `Rule R` mismatch
  this task's own Phase 1 edit caused (`orchestrator-runtime-files.md`, 184 declared vs. 272
  actual after the new subsection) was corrected. Recorded as a `#### Reasoned Exclusions` entry
  on Phase 5 in the plan (marker: `[COMPLETED WITH EXCLUSIONS]`).
- **Phase 5, "modified-file set is exactly the four declared" criterion** altered: a fifth file,
  `agent-system/extensions/core/index-entries.json`, was touched — the one-line `line_count`
  correction described above. This is a direct, mechanical consequence of this task's own Phase 1
  edit (not an independent scope choice) and was made via the sanctioned
  `generate-context-line-counts.sh` maintenance script's documented purpose, touching only the
  single entry this task's own edit made stale.

## Verification

- Build: N/A (markdown/shell configuration, no compiled artifact)
- Tests: Passed — `test-loop-guard-staleness.sh` 28/28 assertions, exit 0;
  `test-resume-scan-nonconformance.sh` (standing regression suite over the same SKILL.md) 39/39
  assertions, exit 0 (no collateral damage to the neighbouring `resume-scan-conformance-gate`
  region)
- Files verified: Yes
- `bash -n` on the extracted `loop-guard-staleness` region and on the full Stage 2 fenced block:
  clean
- `bash -u` on the extracted region with only the five declared inputs bound (`TASK_DIR`,
  `loop_guard_file`, `churn_file`, `MAX_CYCLES`, `current_plan_version`): clean, confirming no
  undeclared input
- `check-task-references.sh`: exit 0 (zero unexempted occurrences across all four scanned trees)
- `check-extension-docs.sh`: exit 1 — see Plan Deviations above; the sole task-caused failure was
  fixed, five pre-existing unrelated failures remain and are excluded with evidence
- `git status --short`: confirmed zero modified paths under `.claude/**`

## Impacts

- A hard-mode `/orchestrate --hard` resume on a task directory carrying a genuinely stale loop
  guard (superseded skill version, superseded plan lineage, or simply untouched for over a week)
  now gets a fresh guard at cycle 0 with a loud, signal-naming notice, instead of silently
  resuming a wrong cycle/burnout/infra-failure count from an unrelated line of work.
- The stale guard and its co-archived churn state are preserved on disk
  (`.stale-loop-guard-{ts}.json`, `.stale-churn-state-{ts}.json`) for operator inspection, never
  deleted.
- Base-mode `/orchestrate` (non-`--hard`) retains the byte-for-byte identical unconditional-trust
  shape in its own Stage 2 and was **not** changed by this task — stated explicitly in both
  `orchestrator-runtime-files.md` and here so no reader assumes base mode was silently fixed too.

## Follow-ups

- None required by this task's verification bar. A future task could extend the same detector to
  base-mode `skill-orchestrate/SKILL.md` if the same staleness hazard is judged worth guarding
  there too — this task deliberately leaves that decision unmade (Non-Goal).
- The five pre-existing `check-extension-docs.sh` FAIL lines identified but not fixed by this task
  (one `index-entries.json` line_count drift on `plan-format.md`, four deployed-script
  content-drift FAILs) remain open for whichever task next touches those files or runs a full
  deploy-tree regeneration (`bash .claude/scripts/deploy-headless.sh`).

## References

- `specs/961_add_freshness_detection_to_orchestrator_loop_guard/plans/01_loop-guard-staleness-detection.md`
- `specs/961_add_freshness_detection_to_orchestrator_loop_guard/reports/01_loop-guard-staleness-detection.md`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` (structural
  model for the new fixture suite)
