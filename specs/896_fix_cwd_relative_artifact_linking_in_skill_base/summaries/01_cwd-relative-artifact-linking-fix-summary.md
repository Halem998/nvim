# Implementation Summary: Task #896

**Completed**: 2026-07-25
**Duration**: ~1 hour

## Overview

Fixed `skill_link_artifacts` in `agent-system/extensions/core/scripts/skill-base.sh` so its three
internal paths (`specs/state.json`, `specs/tmp/state.json`, `.claude/scripts/generate-todo.sh`)
resolve against the already-exported `SKILL_REPO_ROOT` anchor instead of the caller's ambient
working directory, and added an opt-in `--task N` filter to
`agent-system/extensions/core/scripts/reconcile-artifacts.sh` so operators no longer need to run
an unscoped repo-wide sweep to backfill one task's artifacts. Both fixes were proven with
executable verification from a non-root working directory against a throwaway deployed-shaped
harness under the session scratch directory.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — inside `skill_link_artifacts` only:
  added `mkdir -p "${SKILL_REPO_ROOT}/specs/tmp"` before the first jq round-trip, and anchored the
  Step 1/Step 2 jq redirect operands (`specs/state.json`, `specs/tmp/state.json`, the `mv`
  source/destination) and the `generate-todo.sh` invocation on `SKILL_REPO_ROOT`. No other
  function in the file was touched; the jq filter expressions, `--arg` bindings, function
  signature, and doc comment block are byte-identical to before.
- `agent-system/extensions/core/scripts/reconcile-artifacts.sh` — converted the argument loop from
  `for arg in "$@"` to a `while [[ $# -gt 0 ]]`/`shift` loop that accepts `--dry-run`, `--task N`,
  and `--task=N`; added numeric validation (`^[0-9]+$`) rejecting a non-numeric or missing
  `--task` value with `exit 1`; added an `if`/`then` filter guard in the main per-task loop
  (`if [[ -n "$TASK_FILTER" ]] && [[ "$task_num" -ne "$TASK_FILTER" ]]; then continue; fi`); and
  extended the final summary echoes with an optional ` (task $TASK_FILTER)` suffix that is empty
  (byte-identical to the prior message) when no filter is set. The unfiltered, no-argument
  invocation at `agent-system/extensions/core/commands/task.md:438` is unchanged.
- `specs/896_fix_cwd_relative_artifact_linking_in_skill_base/plans/01_cwd-relative-artifact-linking-fix.md`
  — all five phases checked off with completion notes; Testing & Validation checklist checked off.
- `specs/896_fix_cwd_relative_artifact_linking_in_skill_base/progress/phase-{1..5}-progress.json`
  — objective-level progress records for each phase.

## Decisions

- Verification ran against a throwaway harness under the session scratch directory
  (`<scratch>/h/repo`), never against the source store or the live repo, because
  `deploy-root-guard.sh` (sourced by `reconcile-artifacts.sh`) hard-fails when executed from
  `agent-system/extensions/` — this is a pre-existing, out-of-scope constraint on how verification
  must be performed, not a defect being fixed.
- All harness invocations of `skill_link_artifacts` used `env -u SKILL_REPO_ROOT` so a stale
  exported anchor from an earlier shell could never mask a still-broken `BASH_SOURCE`-relative
  computation.
- The `--task` filter guard uses the `if`/`then` form rather than a trailing `&& continue`
  compound, per the plan's `set -uo pipefail` interaction concern.

## Plan Deviations

- Phase 5's verification bullet "`git diff --stat -- agent-system/` lists exactly two changed
  files" does not hold literally: a concurrently running implementation agent (per this task's
  explicit concurrency constraint) modified
  `agent-system/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md` and two docs files in
  the same working tree during this run, so the raw count is four. Verification was re-scoped to
  confirm this implementation's own two files
  (`agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/reconcile-artifacts.sh`) are the only `agent-system/`
  files it modified, which holds — see `progress/phase-5-progress.json` for the recorded
  deviation.

## Verification

- Build: N/A (bash scripts)
- Tests: `bash -n` passed on both modified scripts; full executable verification suite (Phases 1
  and 4) passed against the scratch harness — non-root-cwd artifact registration, missing-`tmp`-dir
  resilience, duplicate-type remove-then-add dedup, real (non-`--dry-run`) `--task N` scoping with
  a `jq` diff proving other tasks' `artifacts` arrays untouched, and a real no-argument sweep
  matching the Phase 1 baseline exactly.
- Files verified: Yes — `git diff` reviewed in full for both files; both hunks confined to
  `skill_link_artifacts` (skill-base.sh) and the argument-parsing/filter/summary code
  (reconcile-artifacts.sh); no task-number citations introduced (two pre-existing citations at
  `skill-base.sh:19` and `:159` are outside this diff's hunk).

## Notes

- The deployed `.claude/scripts/` copy is stale by design and will pick up this fix on the next
  sync; no hand-edit was made to the deploy tree (`.claude/` is gitignored and disposable, per the
  source-store rule).
- `agent-system/extensions/core/manifest.json` already lists both scripts (`skill-base.sh` and
  `reconcile-artifacts.sh` at line 142); no manifest change was needed.
- The four documentation references to `skill_link_artifacts` (`docs/guides/creating-skills.md`,
  `docs/architecture/system-overview.md`, `docs/architecture/architecture-spec.md`,
  `docs/examples/research-flow-example.md`) all cite the function's name/signature only, which is
  unchanged, so no doc edit was needed.
