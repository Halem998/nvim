# Implementation Summary: Task #913

**Completed**: 2026-07-27
**Duration**: ~2.5 hours

## Overview

`/orchestrate` Stage 5 treated a missing `.orchestrator-handoff.json` as a suspected defect on
every dispatch, but base-mode research, plan, and implement dispatches never write one — research
is contractually prohibited from doing so, and base-mode plan/implement simply never gained a
writer. This left successful dispatches stranded at `researching`/`planning`/`implementing` with
no postflight update, requiring manual rescue (observed twice live while orchestrating this very
task). This implementation adds `.return-meta.json` — a file every dispatch already writes per its
own Stage 7 contract — as a second, fail-closed outcome channel, normalized by one new shared
script and consulted at all three affected call sites.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — new shared helper.
  Usage: `orchestrate-recover-outcome.sh <task_dir> <window_start_ts>`. Reads
  `<task_dir>/.return-meta.json`, applies the same mtime-vs-window staleness gate the handoff
  path already uses, and emits a single-line JSON object (`recovered`, `status`, `reason`,
  `artifact_path/type/summary`, `phases_completed`, `phases_total`, `meta_mtime`,
  `window_start`). `recovered=true` only for a present, fresh, parseable file whose `status` is
  `researched`/`planned`/`implemented`; every other case sets `recovered=false` with a reason
  token (`META_MISSING`, `META_STALE`, `META_UNPARSEABLE`, `STATUS_IN_PROGRESS`,
  `STATUS_NOT_SUCCESS`, `USAGE`). Exit 0/1/2 per the header contract; callers treat 2 as 1.
- `agent-system/extensions/core/manifest.json` — registered the new script in
  `provides.scripts`, alphabetically between `orchestrate-dry-run-report.sh` and
  `orchestrate-triage-classify.sh`.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`:
  - Stage 5: the missing/stale-handoff branch now calls the recovery script before emitting any
    error diagnostic. On `recovered=true` it populates `dispatch_status`, phase accounting,
    `plan_markers_verified="absent"`, and artifact fields, then falls into a `have_outcome`-gated
    shared tail (the SAME `case "$dispatch_status"` postflight block and `skill_link_artifacts`
    call the handoff-present branch uses — no duplicated case statement). On `recovered=false`
    the existing error diagnostics, infra-failure discrimination, and phase-marker grep run
    byte-identically to before; the "no plan file available" message is now softened when no
    `plans/` directory exists yet (the normal post-research state) versus loud when one exists
    but yields no plan.
  - Stage MT-4 step 1: the same recovery call now runs before the existing infra-discrimination
    `if`, using the per-task `window_start` already read from `mt_state_file`. A recovered
    outcome sets this task's `dispatch_status`/phase accounting/artifact fields and continues
    into steps 2-6 unchanged — the task is neither added to `failed_tasks` nor infra-deferred.
    A non-recovered outcome falls through to the unchanged infra-vs-`failed_tasks` logic.
  - Context Flatness Constraint section: names `.return-meta.json` as a second, bounded read and
    adds a "Recovery exception (return-meta fallback)" paragraph alongside the existing
    phase-marker-grep exception, calling out that this exception (unlike the grep) DOES drive a
    status transition.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Stage 5 mirrors the
  base-mode restructuring with the `[hard-orchestrate]` log prefix, sets `skeleton=false` and
  `sorry_inventory='[]'` explicitly on the recovered path (return-meta carries no hard-mode
  wrap-up fields), and preserves the hard-mode `implemented`-gate refusal arm for both the
  handoff-present and recovered paths. The H4 (adversarial verification), H5 (divergence audit),
  and Stage 6 (blocker research) sub-dispatches were confirmed untouched — `git diff` for this
  phase falls entirely within the Stage 5 BEGIN/END comment markers.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — added an "Outcome
  Channels" section naming `.orchestrator-handoff.json` as primary and `.return-meta.json` as the
  fallback, and rewrote the Handoff Writers table's "Not implemented" row so it reads as an
  expected, recoverable case rather than an unaddressed gap.
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` — added an
  "Ordering relative to return-meta outcome recovery" section recording that recovery is
  attempted first and the two-signal discrimination applies only when it declines.

## Decisions

- Followed the research report's refutation of the plan/research "symmetry" premise: the fix
  treats base-mode research, plan, and implement identically (all recoverable via return-meta),
  with no special-casing between them.
- Deliberately deviated from the research report's Recommendation 5 (documented in the plan):
  a recovered success charges exactly one work cycle, identical to the handoff-present success
  path, rather than being exempted from `MAX_CYCLES` — real work happened and produced a status
  transition, unlike the infra-exempt case where no work happened at all.
- Left `skill-orchestrate-hard`'s H4/H5/Stage 6 sub-dispatches, the staleness gate, the
  stray-handoff sweep, and `skill_write_orchestrator_handoff` (still zero callers) untouched, per
  the plan's explicit non-goals.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/shell skill sources, no compiled build step)
- Tests: All fixture and trace verifications from the plan passed:
  - `orchestrate-recover-outcome.sh`: six fixture cases (fresh success, stale, missing,
    `in_progress`, non-success `partial`, malformed JSON) all produced the exact
    `recovered`/`reason`/exit-code combination the plan specifies.
  - Hand-traced the base Stage 5, hard-mode Stage 5, and multi-task MT-4 recovery branches
    against a fixture `.return-meta.json` (`status: "researched"`); all three reached
    `skill_postflight_update <n> research <session> researched` (hard mode additionally verified
    `skeleton=false`/`sorry_inventory=[]`; MT-4 additionally verified the task is never added to
    `failed_tasks`).
  - Traced all four negative cases (missing, stale, `in_progress`, `failed`) through the
    embedded branch logic; each reached the unchanged error-diagnostic path rather than a false
    recovery.
  - `bash -n` passed on the new script and on every edited fenced bash block in both orchestrate
    `SKILL.md` files (the MT-4 section's fences are markdown-list-indented; verification
    de-indented them before parsing — the indentation itself is correct Markdown and unchanged
    in kind from the surrounding list).
  - `grep -c` confirmed exactly one `case "$dispatch_status" in` postflight block in Stage 5
    (the shared tail), and confirmed the H4/H5/Stage 6 `orchestrator_mode: false` sub-dispatch
    sites are absent from this task's diff.
  - `git status --porcelain .claude/` is empty and `.claude/` is confirmed gitignored — no
    deploy-tree file was touched by any phase.
- Files verified: Yes — every touched path is under `agent-system/extensions/core/**` or this
  task's own `specs/913_fix_stage5_missing_handoff_after_research_dispatch/` directory.

## Notes

**`.claude/` must be re-synced from the source store for this fix to take effect at runtime.**
This task deliberately edits only `agent-system/extensions/core/**` per the binding SOURCE-STORE
RULE; the deployed `.claude/` tree (gitignored, disposable) still runs the pre-fix Stage 5/MT-4
logic until the next sync (`<leader>al` / "Load Core" / "Sync all"). Until that sync happens,
`/orchestrate` will continue to exhibit the original bug in the live/deployed copy even though the
source is fixed.

`check-extension-docs.sh` could not be run to completion in this session: it refuses to run from
the agent-system source store by design (`deploy-root-guard.sh`'s structural check), and running
it would have required deploying to `.claude/` first, which is explicitly out of scope for this
task. This is expected, pre-existing tooling behavior, not a defect introduced here.
