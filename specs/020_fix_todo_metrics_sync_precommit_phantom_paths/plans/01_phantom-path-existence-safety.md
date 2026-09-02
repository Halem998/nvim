# Implementation Plan: Metrics sync measures a stale git index, inflating build_errors with phantom paths

- **Task**: 20 - Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/020_fix_todo_metrics_sync_precommit_phantom_paths/reports/01_metrics-sync-phantom-paths.md
- **Artifacts**: plans/01_phantom-path-existence-safety.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`assess-repo-health.sh` enumerates structural-check candidates from `git ls-files` (the index)
without ever checking that the path exists on disk, so any uncommitted rename/move/delete scores
as a `build_errors` increment. `/todo` then calls that probe at Step 5.6 — after Step 5D's
directory moves and Step 5.7's vault operation but before Step 6's commit — which is precisely
the tree state that triggers the defect, every run. This plan makes the probe existence-safe at
its single enumeration choke point (surfacing skipped paths as a new `phantom_paths` diagnostic
rather than silently dropping them), re-sequences `/todo`'s metrics sync to run after its commit
with its own narrowly-scoped state-only commit, and adds git-fixture regression cases that lock
both directions of the fix. Definition of done: a moved-but-unstaged tracked file contributes
zero to `build_errors`, a genuinely broken tracked file still contributes exactly one, and
`/todo`'s recorded `repository_health` matches an identical probe run immediately after its own
commit.

### Research Integration

Findings from `reports/01_metrics-sync-phantom-paths.md` carried into this plan:

- **Defect A** (probe existence gap) is confirmed at `assess-repo-health.sh`'s
  `enumerate_by_glob` / structural-loop pair; the fix belongs at the two `mapfile` population
  sites, not inside each downstream loop, so `total_candidates` and every future consumer become
  existence-safe from one place.
- `count_marker()`'s `enumerate_by_glob` calls are **already existence-safe** by accident of
  construction (`grep -c` on a missing path fails silently and is coalesced to 0 by the existing
  `c="${c:-0}"`), so TODO/FIXME counting needs no change. Only the two structural arrays do.
- **Decision carried forward**: phantom paths are surfaced as a new integer diagnostic field, not
  silently skipped — index/worktree divergence is a real signal outside `/todo`'s own mid-run
  state, and the script's existing "explicit unknown over guessing" posture (`build_errors: null`)
  is the same pattern one level down.
- `repository_health` in `state-schema.json` carries `additionalProperties: false`, so the new
  field requires an explicit schema property. The research flags probe-edit-without-schema-edit
  as the top risk; this plan makes them one atomic phase.
- **Defect B** (sequencing) fix shape: move the metrics-sync stage after Step 6's commit followed
  by its own `git-commit-scoped.sh` call scoped to `specs/state.json`, rather than folding the
  probe into Step 6 — `git-commit-scoped.sh` is stage+commit-atomic with no "stage only" mode, and
  changing that contract is out of scope.
- **Defect C** (Step 5A `--argjson` MAX_ARG_STRLEN ceiling, described in the task description) is
  **already closed upstream** by the `state-write.sh` transparent-spill fix, verified live by the
  research pass against both associated regression suites. This plan does not re-open it; see
  Non-Goals.
- **Item 3 of the task's WORK list** (other callers with the same pre-commit exposure) is resolved
  by confirmed absence: `commands/todo.md` is the sole production call site under
  `agent-system/extensions/**`. No code change is owed; Phase 4 records the confirmation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; `specs/ROADMAP.md` was not consulted and
is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- Make `assess-repo-health.sh` existence-safe: a candidate present in the git index but absent on
  disk contributes nothing to `build_errors` and nothing to `total_candidates`.
- Surface skipped candidates as a new `phantom_paths` integer field on `repository_health`,
  declared in `state-schema.json` and documented in `state-management-schema.md`.
- Re-sequence `/todo` so the metrics sync measures the tree it actually committed, with its own
  narrowly-scoped follow-up commit.
- Lock both directions with git-fixture regression cases: phantom paths score zero, real defects
  still score exactly their true count.
- Produce explicit measured before/after evidence rather than an unqualified green.

**Non-Goals**:
- Re-opening the Step 5A `--argjson` argument-length defect (closed upstream; verified by research).
- Changing `git-commit-scoped.sh`'s stage+commit-atomic contract or adding a stage-only mode.
- Adding project-specific build/lint/test checks to the probe (its structural-soundness reading is
  a deliberate, documented scope decision).
- Adding the general "existence-check requirement for `git ls-files` enumerators" subsection to
  `context/standards/census-methodology.md` — the research recommends it as a follow-up task, and
  `census-count.sh` is not an affected caller today.
- Any edit under `.claude/**`. That tree is a gitignored deploy artifact; all edits target
  `agent-system/extensions/core/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Probe emits `phantom_paths` before `state-schema.json` declares it; `additionalProperties: false` then fails every `validate-state.sh --deep` run | H | H | Phase 1 is a declared `atomic-batch`: probe + schema + schema doc land as one commit, never separately |
| New test asserts schema membership against the **deployed** `.claude/context/schemas/state-schema.json`, which is stale until the next deploy, producing a spurious failure | M | M | New test cases assert probe *behavior* only (`build_errors`, `phantom_paths`, `status`). Schema conformance is verified separately in Phase 4 via `validate-state.sh --deep`, resolved against the source store |
| Existence filter over-filters — a probe that can only ever report zero | H | L | Phase 2's dual-assertion fixture requires `build_errors == 1` exactly (not 0, not 2) with a real syntax error present alongside a phantom path; mirrors the suite's existing "Bar 1 vs. clean control" pairing |
| Renumbering `/todo`'s Step 5.6 silently breaks the cross-references that point at it | M | H | Phase 3 owns all cross-reference sites and re-greps for `Step 5.6` afterward; the sites are enumerated in that phase's Scope Hypothesis |
| A `/todo` run that fails between the archive commit and the new metrics commit leaves metrics one run stale | L | L | Strictly better than today (today's single commit bakes in a *wrong* value permanently); the next `/todo` recomputes. Documented in the re-sequenced step's prose |
| Every existing test fixture is a non-git `mktemp -d`, so no case exercises the `git ls-files` path at all today | M | H | Phase 2's new fixtures are git work trees (`git init`/`add`/`commit`), a third fixture kind alongside the existing ones — the existing suite's structure and `pass()`/`fail()`/`info()` helpers are reused, not rewritten |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Existence-safe enumeration and phantom_paths field [NOT STARTED]

**Goal**: `assess-repo-health.sh` filters non-existent candidates at the single population site,
excludes them from `total_candidates`, and emits a new `phantom_paths` integer alongside
`build_errors` — with the schema and schema documentation updated in the same commit.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/assess-repo-health.sh`, filter the two structural
      candidate arrays for on-disk existence at their `mapfile` population sites (`SH_FILES`,
      `JSON_FILES`), retaining a count of dropped paths in a `phantom_paths` counter. Do not add
      per-loop existence guards downstream — the filter is the choke point.
- [ ] Confirm `total_candidates` is computed from the filtered arrays, so the degenerate
      zero-candidate branch (`build_errors: null` / `status: "unknown"`) reflects real candidates
      only.
- [ ] Leave `count_marker()` unchanged; add a short comment recording *why* it needs no filter
      (`grep -c` on a missing path already coalesces to 0 via the existing `c="${c:-0}"`), so a
      future reader does not "fix" it redundantly.
- [ ] Emit `phantom_paths` as a fifth key in the script's final `jq -n` object, always an integer
      (0 when none) — never null, since "how many index entries were missing from disk" is always
      measurable, unlike `build_errors`.
- [ ] Update the script's header block: the `Output (stdout)` key list, the `Enumeration`
      paragraph (state the index-vs-worktree divergence and the existence filter), and the
      `Degenerate case` paragraph (state that phantom paths are excluded from the candidate total).
- [ ] Add the `phantom_paths` property to `repository_health.properties` in
      `agent-system/extensions/core/context/schemas/state-schema.json` (`"type": "integer"`, with a
      description naming it a count of git-index entries absent from the worktree at assessment
      time). `additionalProperties: false` stays as-is.
- [ ] Add the matching row to the `### Repository Health Fields` table in
      `agent-system/extensions/core/context/reference/state-management-schema.md`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts exactly **two** array population sites need filtering
(`SH_FILES`, `JSON_FILES`) and that `count_marker()` needs none. Confirm at implementation time by
grepping `enumerate_by_glob` call sites in the script and checking each consumer's failure mode on
a nonexistent path before editing; if a third structural consumer exists, filter it at the same
choke point and record the correction.

**Files to modify**:
- `agent-system/extensions/core/scripts/assess-repo-health.sh` - existence filter, `phantom_paths`
  counter and emission, header contract update
- `agent-system/extensions/core/context/schemas/state-schema.json` - new `phantom_paths` property
  under `repository_health`
- `agent-system/extensions/core/context/reference/state-management-schema.md` - new row in the
  Repository Health Fields table

**Verification**:
- `bash -n agent-system/extensions/core/scripts/assess-repo-health.sh` passes.
- `jq empty agent-system/extensions/core/context/schemas/state-schema.json` passes.
- The source-store script run with `--root` against a clean scratch directory emits all five keys,
  with `phantom_paths` an integer.
- The existing suite (`bash agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh`)
  still passes at its pre-change count — the new field must not disturb the existing cases.

---

### Phase 2: Git-fixture regression cases [NOT STARTED]

**Goal**: The regression suite proves, on an actual git work tree, that a moved-but-unstaged
tracked file contributes zero errors while a genuinely broken tracked file still contributes
exactly one.

**Tasks**:
- [ ] Add a git-fixture helper to
      `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` that builds a
      throwaway work tree under the suite's existing `WORKDIR` (`git init`, `git add`,
      `git commit` with `-c user.email=` / `-c user.name=` or equivalent local config so the
      fixture never depends on the caller's global git identity).
- [ ] Case: **phantom-only**. Commit one syntactically valid tracked `*.sh`, then `mv` it to a new
      path without staging. Assert `build_errors == 0`, `status == "healthy"`, and
      `phantom_paths == 1`.
- [ ] Case: **phantom plus real defect**. Same fixture with a second tracked `*.sh` carrying a
      deliberate syntax error, left in place and unmoved. Assert `build_errors == 1` exactly
      (explicitly asserted to be neither 0 nor 2), `status == "critical"`, and `phantom_paths == 1`.
- [ ] Case: **all-phantom degenerate**. A fixture whose only tracked structural candidates have
      all been moved away unstaged. Assert `build_errors` is JSON `null` (explicitly neither 0 nor
      1) and `status == "unknown"` — proving phantom paths are excluded from `total_candidates`,
      not merely from the error count.
- [ ] Reuse the suite's existing `pass()` / `fail()` / `info()` helpers and PASSED/FAILED counters;
      do not restructure existing cases.
- [ ] Add an `info()` line at the new cases' start noting that these fixtures — unlike every
      pre-existing one — are real git work trees and therefore exercise the `git ls-files`
      enumeration path rather than the `find` fallback.
- [ ] Update the suite's header `Cases:` block to describe the new cases and the third fixture
      kind.
- [ ] Skip the git cases with a named `[INFO]` line (not a FAILED) if `git` is unavailable on
      PATH, matching the suite's existing skip convention for the `generate-todo.sh` case.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts **three** new cases suffice to cover the fix in both
directions plus the degenerate branch. Confirm at implementation time by checking each assertion
actually fails against the pre-Phase-1 script: temporarily `git stash` the Phase 1 change (or run
the cases against a copy of the prior script) and record that the phantom-only and all-phantom
cases go `[FAIL]`, per the suite's existing negative-control convention. A case that passes both
before and after the fix is not a regression lock and must be replaced.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` - git-fixture helper,
  three new cases, header `Cases:` block update

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` exits 0 with the
  new cases reported PASS and no pre-existing case regressed.
- The negative-control transcript (cases failing against the pre-fix script) is captured for the
  implementation summary.

---

### Phase 3: Re-sequence /todo's metrics sync after its commit [NOT STARTED]

**Goal**: `/todo` computes and records repository metrics against the tree it has already
committed, and records that update in its own narrowly-scoped commit.

**Tasks**:
- [ ] In `agent-system/extensions/core/commands/todo.md`, relocate the `### 5.6. Sync Repository
      Metrics` section to sit between `### 6. Git Commit` and `### 7. Output`, renumbering it to
      `### 6.5. Sync Repository Metrics` and its substeps accordingly. Placement before Step 7
      preserves Step 7's ability to report the `metrics_*` values it already reads.
- [ ] Add a rationale paragraph to the relocated section stating why it runs post-commit: Step 5D's
      directory moves and Step 5.7's vault operation leave the git index behind the worktree, so a
      pre-commit probe measures paths that no longer exist. Note that the probe is independently
      existence-safe as of Phase 1, and that both fixes are required — re-sequencing does not
      protect against a concurrent session's uncommitted rename elsewhere in the tree.
- [ ] Add a new final substep issuing a metrics-only commit via `git-commit-scoped.sh` scoped to
      `specs/state.json` (message: `todo: sync repository metrics`, same `--session`). Note that
      `--honest-index-rows` is inapplicable here for the opposite reason it is inapplicable to Step
      6: this commit touches nothing task-scoped at all.
- [ ] Record in that substep's prose that a failure between Step 6's commit and this one leaves
      metrics one run stale but loses no state — the next `/todo` recomputes — consistent with the
      non-blocking treatment of git failures in `rules/error-handling.md`.
- [ ] Add `metrics_phantom_paths` to the tracked output values in the relocated reporting substep,
      so a nonzero phantom count is visible to the operator rather than buried in state.json.
- [ ] Update every cross-reference to the old step number: the "See Step 5.6.2 for the identical
      rationale" pointer in the Step 5.7 vault section, the `commands/todo.md Step 5.6` pointer in
      `assess-repo-health.sh`'s header, and the `(Step 5.6.1)` pointer in
      `docs/reference/utility-scripts-inventory.md`.
- [ ] Re-grep `Step 5\.6` across `agent-system/` and confirm the only remaining hits are unrelated
      (`commands/review.md`'s own `5.6.x` subsections and
      `docs/examples/fix-it-flow-example.md`'s skill-step reference, neither of which concerns
      `/todo`).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly **three** cross-reference sites point at the old
step number outside the moved section itself (`todo.md`'s vault-section pointer,
`assess-repo-health.sh`'s header, `utility-scripts-inventory.md`). Confirm at implementation time
with a repo-wide `grep -rn "Step 5\.6"` over `agent-system/` **before and after** the edit; any
additional hit that concerns `/todo` must be updated and the correction recorded.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - relocate and renumber the metrics-sync step,
  add the post-commit rationale, add the metrics-only commit substep, add
  `metrics_phantom_paths` to reported values, fix the vault-section cross-reference
- `agent-system/extensions/core/scripts/assess-repo-health.sh` - header cross-reference to the new
  step number (single line; Phase 1 owns the rest of this file and runs in an earlier wave)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - cross-reference to
  the new step number

**Verification**:
- Step ordering in `todo.md` reads 5.5 -> 5.7 -> 6 -> 6.5 -> 7 with no orphaned or duplicated
  numbers.
- The post-edit `grep -rn "Step 5\.6" agent-system/` returns only the unrelated hits enumerated
  above.
- Every bash block in the relocated section is syntactically valid when extracted and run through
  `bash -n`.

---

### Phase 4: Acceptance evidence and full-gate verification [NOT STARTED]

**Goal**: Produce the explicit measured before/after evidence the task's acceptance criteria
demand, and run the complete gate set.

**Tasks**:
- [ ] Build a scratch git fixture reproducing the reported failure shape at reduced scale: commit a
      set of tracked `*.sh`/`*.json` files under a directory, then `mv` that directory without
      staging. Run the **pre-fix** probe (from `git show` of the parent commit, or a saved copy)
      and the **post-fix** probe against the identical tree; record both `build_errors` and
      `status` from each. Expected: pre-fix reports a large inflated count with
      `status: "critical"`; post-fix reports the true count with `phantom_paths` equal to the
      number of moved candidates.
- [ ] In the same fixture, stage and commit the move, then re-run the post-fix probe. Assert the
      two post-fix readings agree — this is the task's stated acceptance condition (a `/todo` run
      reports the same `build_errors` and `status` as an identical probe run immediately after its
      commit).
- [ ] Confirm the reverse direction in the same evidence run: a genuinely broken file in the
      fixture is still counted. Never report an unqualified green.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` (full suite,
      including Phase 2's cases).
- [ ] Run `validate-state.sh --deep` against a `state.json` whose `repository_health` carries the
      new `phantom_paths` field, confirming the schema addition is accepted and
      `additionalProperties: false` is satisfied.
- [ ] Record in the implementation summary that `commands/todo.md` is the sole production caller of
      `assess-repo-health.sh` under `agent-system/extensions/**` (item 3 of the task's WORK list,
      resolved by confirmed absence — re-verify with `grep -rln "assess-repo-health" agent-system/`
      rather than restating the research's finding on trust).
- [ ] Record explicitly that the Step 5A argument-length defect described in the task description
      was verified closed upstream by the research pass and is deliberately untouched here.

**Timing**: 45 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the reduced-scale fixture reproduces the same *shape* as
the reported 184-phantom production run, not the same magnitude. Confirm by checking that the
pre-fix reading's `build_errors` equals the number of moved candidates (total inflation, zero
residue) — if it does not, the fixture is not reproducing the reported defect and must be adjusted
before the evidence is trusted.

**Files to modify**:
- None (verification only). Findings are recorded in the implementation summary artifact.

**Verification**:
- Both probe readings (post-fix pre-commit, post-fix post-commit) agree on `build_errors` and
  `status`.
- Full regression suite exits 0.
- `validate-state.sh --deep` accepts the new field.

---

## Testing & Validation

- [ ] `bash -n` clean on `assess-repo-health.sh` and on every bash block extracted from the
      relocated `todo.md` section.
- [ ] `jq empty` clean on `state-schema.json`.
- [ ] `test-assess-repo-health.sh` exits 0 with the three new git-fixture cases passing and no
      pre-existing case regressed.
- [ ] Negative control: the new cases demonstrably `[FAIL]` against the pre-fix probe.
- [ ] `validate-state.sh --deep` accepts a `repository_health` object carrying `phantom_paths`.
- [ ] Measured before/after `build_errors` and `status` pairs recorded explicitly in the summary,
      in both directions (phantom contributes zero; real defect still counted).
- [ ] No file under `.claude/**` modified (`git status --short` shows edits only under
      `agent-system/extensions/core/**` and `specs/**`).

## Artifacts & Outputs

- `specs/020_fix_todo_metrics_sync_precommit_phantom_paths/plans/01_phantom-path-existence-safety.md` (this file)
- `specs/020_fix_todo_metrics_sync_precommit_phantom_paths/summaries/01_phantom-path-existence-safety-summary.md` (implementation phase)
- Modified: `agent-system/extensions/core/scripts/assess-repo-health.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh`
- Modified: `agent-system/extensions/core/commands/todo.md`
- Modified: `agent-system/extensions/core/context/schemas/state-schema.json`
- Modified: `agent-system/extensions/core/context/reference/state-management-schema.md`
- Modified: `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`

## Rollback/Contingency

Each phase commits independently (Phase 1 as one atomic batch), so `git revert` of a single phase
commit restores the prior behavior without disturbing the others. Phase 1 must be reverted as a
unit — reverting only the probe change while leaving the schema property in place is harmless, but
reverting only the schema while leaving the probe emitting `phantom_paths` breaks
`validate-state.sh --deep` on every subsequent run. If Phase 3's re-sequencing proves problematic
in a live `/todo` run, reverting it alone leaves Phase 1's existence-safety in force, which already
removes the false inflation; the residual exposure is only that metrics describe a tree about to
change.
