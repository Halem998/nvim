# Implementation Plan: Task #85

- **Task**: 85 - deflake_shell_test_suite_under_concurrency
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: 32
- **Research Inputs**: specs/085_deflake_shell_test_suite_under_concurrency/reports/01_deflake-shell-test-suite.md
- **Artifacts**: plans/01_fix-stale-test-fixtures.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The shell test suite's apparent non-determinism is not a concurrency problem. Research
established that `task-lock.sh` has no defect, that `run-all.sh` never acquires a lock or touches
`specs/.locks`/`specs/state.json`, and that two full `run-all.sh` runs at HEAD — one deliberately
raced against a second simultaneous invocation — produced byte-identical results (50 passed,
2 failed, same two suites, same case-level detail). The entire observed variance is explained by
two deterministic test-fixture-staleness defects that both landed on 2026-08-17 and have failed
on every run since, plus the separately-diagnosed deploy-staleness confounder.

This plan therefore fixes those two fixtures, adds a mechanical guard so the first defect's class
cannot silently recur, writes the implicit isolation rule into the testing standard, and then
executes the task's stated acceptance measurement (10 consecutive runs with a concurrent session
live) with the deploy-staleness confounder explicitly separated rather than assumed absent.
Definition of done: `run-all.sh` reports zero failures, and ten consecutive runs under concurrent
load report identical results.

### Research Integration

Findings driving each phase:

- **Finding 1** (Phase 1): `test-validate-return-meta.sh:57` sets
  `EXISTING_PATH="specs/052_return_meta_artifacts_shape_contract/plans/01_return-meta-artifacts-contract.md"`
  and never overrides `REPO_ROOT`, so `validate-return-meta.sh` resolves that path against the
  **live** `specs/` tree. `/todo` archived that directory (commit `8a104a17c`, 2026-08-17). Three
  cases have failed deterministically ever since (`well-formed`, and two `fix-roundtrip` cases).
  It is the only suite of 41 that reads a live numbered `specs/` path.
- **Finding 2** (Phase 2): `test-skill-base-lifecycle.sh` Group 2 still asserts `skill_cleanup()`
  deletes three files including `.return-meta.json`. Commit `75ec7bfa6` (2026-08-17) deliberately
  narrowed `skill_cleanup()` to a documented two-file contract; the rationale is recorded in the
  function's own header comment in `skill-base.sh`. The test was never updated.
- **Finding 3** (no phase): `task-lock.sh` reviewed, no defect found; all 7 consumer suites
  already isolate correctly via `mktemp -d` scratch trees with `PROJECT_ROOT`/`REPO_ROOT`
  overrides. **No change to `task-lock.sh` or `run-all.sh` is planned or warranted.**
- **Finding 4** (Phase 5): the suite is already perfectly consistent under concurrency at HEAD;
  the deployed `.claude/` tree currently matches the source store, so the deploy confounder is not
  presently active — but that must be re-verified at measurement time, not assumed.
- **Preventive recommendation** (Phases 3-4): a mechanical lint for live-`specs/` path
  dependencies plus a written rule in `context/standards/shell-script-testing.md`, where the
  "never resolve against the live tree" convention is currently implicit only.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation; `specs/ROADMAP.md` was not consulted.

## Goals & Non-Goals

**Goals**:
- Make `test-validate-return-meta.sh` fully self-contained: no dependency on any real numbered
  `specs/` directory, immune to future `/todo` archival and vault renumbering.
- Correct `test-skill-base-lifecycle.sh` Group 2 to `skill_cleanup()`'s documented two-file
  contract, with a positive control asserting `.return-meta.json` survives.
- Add a mechanical guard (lint + its own fixture suite) that fails loudly if any suite regains a
  live-`specs/`-path dependency.
- Write the isolation rule into `context/standards/shell-script-testing.md`.
- Execute and record the task's acceptance measurement, with deploy staleness separated from
  flake rather than conflated with it.

**Non-Goals**:
- Any change to `task-lock.sh` — reviewed, no defect found.
- Any change to `run-all.sh` — it never locks and never touches shared task state.
- Adding retry/re-run logic to any suite. A retried test is not a fixed test; the task
  description states this explicitly and research found nothing that would need one.
- Fixing the deploy-staleness confounder itself (a separate, already-diagnosed concern). This
  plan only separates it from flake during measurement.
- Re-auditing all 41 suites by hand — Phase 3's lint mechanizes exactly that audit.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Phase 1's scratch fixture omits a transitive dependency of `validate-return-meta.sh`, turning 3 deterministic failures into a different 3 | M | M | Copy `lib/*.sh` wholesale as `build_fixture_repo()` does, not a hand-picked file list; run the suite standalone and require 14/14 before closing the phase |
| Phase 2's new positive control itself goes stale if `skill_cleanup()`'s contract changes again | M | L | Quote the header comment's two-file contract verbatim in a code comment beside the assertion, so a future contract change surfaces the test in the same diff — this is precisely the omission that caused Finding 2 |
| Phase 3's lint produces false positives on synthetic paths (`specs/000_x`, `specs/001_fixture_task`) that no code ever stats | M | H | Scope the lint to matches that are NOT assigned from a scratch-root variable, and validate it both-polarity in its own fixture suite; if precision cannot be achieved, narrow the lint to a `REPO_ROOT`-unset heuristic rather than shipping a noisy check |
| Deploy staleness recurs during the Phase 5 measurement window and is misread as flake (the exact 2026-08-10 misattribution the task cites) | H | M | Phase 5 diffs each touched file's source-store copy against its deployed copy BEFORE measuring, records the result in the summary, and re-measures after any deploy lands |
| Concurrent sibling sessions land commits mid-measurement, reproducing the original "different suites failed in different runs" artifact | M | M | Record `git rev-parse HEAD` before and after the 10-run block; a changed SHA invalidates the measurement and it is re-run |
| Editing `.claude/**` instead of the source store — the edit appears to work and is wiped by the next deploy | H | L | Every phase's file list names `agent-system/extensions/core/**` paths only; `.claude/` copies are read-only comparison targets in Phase 5 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Isolate test-validate-return-meta.sh from the live specs/ tree [COMPLETED]

**Goal**: `test-validate-return-meta.sh` builds its own scratch fixture repo and invokes the
validator with `REPO_ROOT` pointed at it, so no case resolves a path against the real `specs/`
tree. Suite exits 0.

**Tasks**:
- [x] Add a `build_fixture_repo()`-style helper to the suite that creates *(completed)*
      `$WORKDIR/.claude/scripts/lib/`, copies in `validate-return-meta.sh` and the whole
      `lib/*.sh` set from the same resolved source directory the suite already uses for
      `VALIDATOR_CANDIDATES`, and `chmod +x` the validator copy.
- [x] Create a synthetic fixture artifact in the scratch tree at *(completed)*
      `$WORKDIR/specs/999_fixture_task/plans/01_fixture-plan.md` (any non-empty content).
- [x] Replace `EXISTING_PATH` (currently the archived live path at line 57) with *(completed)*
      `specs/999_fixture_task/plans/01_fixture-plan.md`.
- [x] Invoke the validator with `REPO_ROOT="$WORKDIR"` at every call site: the `assert_exit` *(completed)*
      helper, the Case 3 missing-file call, and all Case 10 / Case 11 direct `bash "$VALIDATOR"`
      calls. Prefer setting it once inside `assert_exit` plus explicitly on each direct call, so
      no call site can be silently missed.
- [x] Point `VALIDATOR` at the scratch copy (`$WORKDIR/.claude/scripts/validate-return-meta.sh`) *(completed)*
      after the existing candidate resolution, keeping the existing exit-2 environment-error
      branch intact for the case where no source copy is found at all.
- [x] Update the suite's header comment to state that it resolves nothing against the live *(completed)*
      `specs/` tree, and why.
- [x] Confirm Case 5 (`specs/does_not_exist_9999/nope.md` -> exit 1) still fails for the right *(completed)*
      reason under the new `REPO_ROOT` — it must be a non-resolving path, not a missing scratch
      tree.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: research measured this suite at 11 passed / 3 failed, and asserts exactly
one live-path dependency (`EXISTING_PATH`, line 57) feeding Cases 1, 2, 4, 6, 9, 10, 11. Confirm
at implementation time by running the suite before the edit (expect 3 named failures:
`well-formed`, `fix-roundtrip: --fix run`, `fix-roundtrip: independent re-validation`) and after
(expect 14 passed, 0 failed). If the before-count differs, re-derive the failing set from the
actual output rather than trusting these numbers.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` - add scratch fixture
  repo builder, replace the archived live `EXISTING_PATH`, thread `REPO_ROOT="$WORKDIR"` through
  every validator invocation, update header comment.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` exits 0 with
  `Failed: 0`.
- `grep -n 'specs/0[0-9][0-9]_' agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh`
  returns no live-tree path (the synthetic `999_fixture_task` scratch path is the only
  numbered-looking path that may remain).
- Re-run the suite from a different working directory to confirm no implicit cwd dependency was
  introduced.

---

### Phase 2: Correct test-skill-base-lifecycle.sh Group 2 to skill_cleanup()'s two-file contract [COMPLETED]

**Goal**: Group 2 asserts the current, documented contract — `.postflight-pending` and
`.postflight-loop-guard` are removed, `.return-meta.json` is not — and carries a positive control
so a future contract change surfaces here immediately.

**Tasks**:
- [x] Remove `.return-meta.json` from the Group 2 `touch` list only if the positive control does *(completed)*
      not need it present; the positive control DOES need it, so keep the `touch` and instead
      remove `.return-meta.json` from the `[[ ! -f ... ]]` conjunction.
- [x] Add the positive control: assert `.return-meta.json` is **still present** after *(completed)*
      `skill_cleanup` returns, as its own named pass/fail case.
- [x] Reword the passing message from "removes all three lifecycle temp files" to name the actual *(completed)*
      two-file contract.
- [x] Update the Group 2 banner comment (currently "removes the three lifecycle temp files") and *(completed)*
      add a code comment quoting `skill_cleanup()`'s header-comment rationale: `.return-meta.json`
      is not deleted here because the calling command's command-gate-out step still reads it, and
      ownership of its deletion belongs to that consumer. Cite the header comment and commit
      `75ec7bfa6` — **do not cite a task number** (deliverable rule: no task-number references
      outside `specs/**`).

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: research measured this suite at 17 passed / 1 failed, with the single
failure being `skill_cleanup left at least one lifecycle temp file behind`, and locates the defect
in one `if` block (Group 2). Confirm by running the suite before the edit and checking the failure
is exactly that one line; after the edit expect 19 passed / 0 failed (17 + the repaired case + the
new positive control). If the before-run shows additional failures, they are out of this phase's
declared scope and must be reported, not silently absorbed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - Group 2 assertion,
  messages, banner comment, new positive-control case.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0 with
  0 failures, and the run still reports its contamination guard passing (`real specs/ tree status
  is unchanged relative to this suite's pre-run baseline`).
- Mutation check (per `shell-script-testing.md`'s mutation-check rule): temporarily add
  `.return-meta.json` back to `skill_cleanup()`'s `rm -f` list in a scratch copy and confirm the
  new positive control goes red — proving it actually guards the contract. Restore immediately;
  do not commit the mutation.

---

### Phase 3: Add a live-specs-path lint plus its own both-polarity fixture suite [COMPLETED WITH EXCLUSIONS]

**Goal**: A mechanical guard exists that fails if any file in a `scripts/tests/` directory
resolves a path against the live `specs/` tree, so Finding 1's defect class cannot silently
recur.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `lint/lint-live-specs-path.sh` shipped as a repo-wide-clean mechanical guard | Built exactly per the Tasks below (token-prefix heuristic: a bare `specs/[0-9][0-9][0-9]_` literal is a violation unless the containing path token starts with `$`). Run repo-wide it reported 52 violations across 4 files — none a genuine live-path dependency. All 4 are pre-existing suites that embed a synthetic `specs/NNN_` path as pure test-fixture DATA (a JSON `"path"` field value inside `test-validate-handoff.sh`/`test-validate-state.sh` heredocs, or a `file_path` argument string in `test-validate-no-task-references.sh`) fed to a validator/hook that never performs filesystem existence-checking on that field at all — `validate-handoff.sh` has zero `-e`/`-f` checks in its whole file; `validate-no-task-references.sh` matches content, not paths on disk. The one true positive-shaped case, `test-validate-return-meta.sh`'s own `EXISTING_PATH` (Phase 1's fixed fixture), is a false positive too post-fix: it is genuinely confined via a `REPO_ROOT="$FIXTURE_REPO"` override injected at every call site, but the override is decoupled from the literal's own token (no `$`-prefix on the path string itself), so the same heuristic that must flag Finding 1's original bug cannot help flagging it. Distinguishing "reaches a `-e`/`-f`/`-d` check downstream" from "used as inert text/JSON-content" is a data-flow/semantic question a line-level grep heuristic cannot answer without per-validator knowledge, and no tightening attempted (JSON-embedding exclusion, REPO_ROOT-unset-in-file heuristic) eliminated the false positives without also reintroducing false negatives or losing generality across "any suite." This is precisely the risk this phase's own Risks & Mitigations row anticipated, with its own stated fallback: "if precision cannot be achieved... drop the lint script and its suite... only the mechanical enforcement is deferred." | Lint run captured during implementation: `Files checked: 44`, `Files with violations: 4`, `Total violations: 52` (`test-validate-handoff.sh`, `test-validate-no-task-references.sh`, `test-validate-return-meta.sh`, `test-validate-state.sh`), all 52 hand-inspected and confirmed non-live (no `-e`/`-f`/`-d` check reaches any of the flagged literals). The lint script and a would-be both-polarity fixture suite were built, verified against this exact repo-wide run, then reverted (never committed) per the contingency; nothing under `agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` or `.../tests/test-lint-live-specs-path.sh` exists in the final tree, and `manifest.json` carries no registration for either. |

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` following the
      structural model of the existing `lint/lint-*.sh` scripts (same argument handling, same
      exit-code convention, same output shape). *(deviation: altered — built, verified imprecise
      per the next task's finding, then reverted per this phase's Reasoned Exclusions below; not
      present in the final tree)*
- [x] Detection rule: flag a `specs/[0-9][0-9][0-9]_` literal in any `scripts/tests/test-*.sh`
      that is not confined to a scratch-root variable expansion (`$WORKDIR`, `$root`,
      `$LINK_ROOT`, or equivalent). Document the chosen heuristic and its known limits in the
      script's header comment — an approximate check that is honest about its bounds is
      acceptable; a silently over-broad one is not. *(completed: implemented and repo-wide-run;
      see Reasoned Exclusions below for why this heuristic could not reach acceptable precision)*
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-live-specs-path.sh` as a
      both-polarity fixture suite (model: `test-lint-postflight-boundary.sh`): a synthetic test
      file with a bare live path must make the lint exit non-zero; the same file with the path
      under a scratch root must exit 0. Build fixtures inline via heredocs into a `mktemp -d`
      workdir per the fixture convention. *(deviation: skipped — the lint itself was dropped per
      this phase's contingency before a fixture suite would have been meaningful; see Reasoned
      Exclusions)*
- [ ] Register both new scripts in `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` array, subdirectory-qualified (`lint/lint-live-specs-path.sh`,
      `tests/test-lint-live-specs-path.sh`). *(deviation: skipped — nothing to register; the lint
      and its suite were dropped, not shipped)*
- [x] Run the new lint across the whole `scripts/tests/` tree in every extension and resolve or
      explicitly document every hit. *(completed: run repo-wide, all 52 hits across 4 files
      documented as false positives — see Reasoned Exclusions below)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: research's manual pass across all 41 suites found zero live-path
dependencies beyond Finding 1, and identified `test-status-vocabulary.sh` as the only non-`mktemp`
suite (it reads two static repo files and asserts no on-disk task path). The lint is expected to
report zero violations once Phase 1 lands. Confirm by running the lint repo-wide; any hit is
either a genuine second instance (fix it, and report that research undercounted) or a false
positive (tighten the heuristic). Do not suppress a hit to make the count match.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` - new lint script.
- `agent-system/extensions/core/scripts/tests/test-lint-live-specs-path.sh` - new both-polarity
  fixture suite.
- `agent-system/extensions/core/manifest.json` - register both under `provides.scripts`.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-live-specs-path.sh` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` exits 0 repo-wide.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers the new suite (total
  suite count increases by exactly one) and reports zero failures.
- `jq -e '.provides.scripts | index("lint/lint-live-specs-path.sh")' agent-system/extensions/core/manifest.json`
  and the equivalent for the test suite both succeed.

---

### Phase 4: Write the fixture-isolation rule into shell-script-testing.md [COMPLETED]

**Goal**: The "never resolve a path against the live `specs/` or `.claude/` tree" rule is written
down rather than implicit convention, and points at the canonical pattern and the new lint.

**Tasks**:
- [x] Add a short subsection to *(completed)*
      `agent-system/extensions/core/context/standards/shell-script-testing.md`'s "Fixture
      convention" section stating the rule: a suite must never resolve an artifact path against
      the live `specs/` tree or the deployed `.claude/` tree; it builds or copies a scratch
      fixture and redirects `REPO_ROOT`/`PROJECT_ROOT` at it.
- [x] Name `build_fixture_repo()` in `test-skill-base-lifecycle.sh` as the canonical structural *(completed)*
      model (it is already treated as such by several suites' header comments).
- [x] State the failure mode concretely: a suite that reads a live numbered task directory breaks *(completed)*
      the moment `/todo` archives it or a vault operation renumbers it — a failure that presents
      as flake and is not one.
- [x] Cross-reference `scripts/lint/lint-live-specs-path.sh` as the mechanical enforcement. *(deviation: altered — the lint was dropped per Phase 3's Reasoned Exclusions, so the written rule instead states enforcement is currently manual, not mechanical, rather than pointing at a script that does not exist)*
- [x] Keep the wording free of task-number references (deliverable rule). *(completed)*

**Timing**: 15 minutes

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new rule subsection
  under "Fixture convention".

**Verification**:
- Diff read-through confirms every changed hunk is prose inside that file (no executable content).
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo-wide task-
  reference lint) reports no new violations.
- The referenced `build_fixture_repo()` symbol exists; no lint path is referenced (see Phase 3's
  Reasoned Exclusions — the lint was dropped, and the written rule says so rather than pointing at
  a nonexistent script).

---

### Phase 5: Acceptance measurement — 10 consecutive runs under concurrent load [COMPLETED]

**Goal**: The task's stated acceptance criterion is executed and recorded: 10 consecutive
`run-all.sh` runs, with at least one other session active, all reporting the same result — with
deploy staleness explicitly separated from flake.

**Tasks**:
- [x] Record `git rev-parse HEAD` and `git status --porcelain` before the measurement block. *(completed: HEAD `cfedc778e`, working tree carried only pre-existing unrelated churn)*
- [x] Confounder separation, BEFORE measuring: for each file touched by Phases 1-4, `diff` the
      source-store copy against its deployed `.claude/` counterpart. Record the result. If any
      differ, state that the deployed tree is stale, and note that Gate 8's verdict is not
      comparable until a deploy lands. *(completed: all three touched files plus run-all.sh itself
      are byte-identical source-vs-deployed; see summary for the separately-tracked literature
      extension staleness, which does not touch anything measured here)*
- [x] Run `run-all.sh --quiet` ten consecutive times against the source store, capturing each
      run's summary line and the full set of `^\[FAIL\] ` lines. *(completed: 10/10 byte-identical
      outputs, `52 passed, 0 failed, 0 skipped, 52 total`, zero FAIL lines in any run)*
- [x] Ensure at least one concurrent session is active during the block (sibling agents in this
      session satisfy this); note in the record which runs overlapped concurrent activity.
      *(completed as literally specified: a distinct session for this task was confirmed active
      inside the 11:07:34Z-11:28:53Z window via timestamped session_stop events, satisfying the
      stated criterion "while at least one other session is active". Recorded limitation: no
      lock/shared-state CONTENTION was demonstrated, and none can be — run-all.sh acquires no
      locks and touches no shared state per this plan's own Finding 3, a property strengthened by
      Phases 1-2 isolating the affected tests into scratch fixture repos. The stricter contention
      reading is unattainable because the isolation fix succeeded, not because measurement fell
      short. Accepted on the literal criterion by explicit maintainer decision. See summary for
      full evidence.)*
- [x] Re-record `git rev-parse HEAD` after the block. If the SHA changed, the measurement is
      invalid — discard and re-run. *(completed: HEAD unchanged at `cfedc778e`, measurement valid)*
- [x] Compare the ten results: identical summary counts AND identical failure sets is the pass
      condition. Any divergence is a real finding to investigate, not noise to average out.
      *(completed: md5sum of all 10 run outputs is a single unique hash — byte-identical, not
      just count-identical; corroborated by a same-filesystem-state verbose 11th run enumerating
      all 52 suite names)*
- [x] If a deploy lands during or after this work, re-measure and record the post-deploy result
      separately, so a genuine staleness failure is never labelled flake and flake is never
      excused as staleness. *(completed: no deploy was run during this work, so no re-measurement
      was required)*
- [x] Record the full measurement (both SHAs, the diff result, all ten summary lines) in the
      task's implementation summary. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: research measured 52 total suites (50 passed, 2 failed) at HEAD; after
Phase 3 adds one suite the expected steady state is 53 passed, 0 failed, 0 skipped, 53 total.
Confirm from the actual summary lines rather than asserting these numbers — a differing total
means suites were added or lost by concurrent work and must be reconciled before the measurement
counts.

**Files to modify**:
- None (measurement only). Output is recorded in the implementation summary.

**Verification**:
- Ten captured summary lines are byte-identical to one another.
- The failure set is empty in all ten runs.
- Pre- and post-block `git rev-parse HEAD` match.
- The source-vs-deployed diff result for every touched file is recorded, whatever it says.

---

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` exits 0. *(verified at closure: exit 0)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0,
      contamination guard still passing. *(verified at closure: exit 0)*
- [~] `bash agent-system/extensions/core/scripts/tests/test-lint-live-specs-path.sh` exits 0
      (both polarities exercised). *(N/A — script never shipped; the lint it would cover was
      dropped under Phase 3's Reasoned Exclusions. Criterion obsoleted by that decision, not
      unmet by omission.)*
- [~] `bash agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` exits 0 repo-wide.
      *(N/A — lint dropped under Phase 3's Reasoned Exclusions: 52 repo-wide hits, all false
      positives, heuristic could not reach acceptable precision.)*
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports zero failures and zero
      skips. *(verified: 52 passed, 0 failed, 0 skipped, on each of 10 runs)*
- [x] Phase 2's mutation check demonstrated the new positive control goes red against a
      re-introduced three-file `skill_cleanup()`. *(recorded complete in phase-2-progress.json)*
- [x] Ten consecutive `run-all.sh` runs under concurrent load report identical results
      (acceptance criterion). *(verified: 10/10 byte-identical by md5sum, 11:07:34Z-11:28:53Z,
      HEAD stable at cfedc778e; concurrent session confirmed active in-window. Accepted on the
      criterion's literal wording -- see Phase 5 for the recorded contention limitation.)*
- [x] No new task-number references outside `specs/**`. *(verified: check-task-references.sh exit 0)*
- [x] No file under `.claude/**` was written by this work. *(verified: no .claude/ path in any of this task's commits)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh` (modified — scratch
  fixture repo, `REPO_ROOT` override, no live-tree dependency)
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` (modified — two-file
  `skill_cleanup` contract plus positive control)
- `agent-system/extensions/core/scripts/lint/lint-live-specs-path.sh` (built, verified, then
  dropped per Phase 3's Reasoned Exclusions — not present in the final tree)
- `agent-system/extensions/core/scripts/tests/test-lint-live-specs-path.sh` (not created — the
  lint it would cover was dropped)
- `agent-system/extensions/core/manifest.json` (not modified — no registrations, nothing shipped)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (modified — fixture
  isolation rule, cross-referencing the mechanical enforcement as deferred rather than the
  dropped lint script)
- `specs/085_deflake_shell_test_suite_under_concurrency/summaries/01_*-summary.md` (new — includes
  the full acceptance measurement record)

## Rollback/Contingency

Every phase is a small, independently revertable edit to one or two files, with per-substep
commits. Reverting any single phase's commit restores the prior state without affecting the
others; Phases 1 and 2 are fully independent of each other.

Contingencies:
- If Phase 3's lint cannot reach acceptable precision, ship Phases 1, 2, 4 and 5 and drop the lint
  script and its suite (revert their commits, remove the two manifest entries, and reword Phase 4's
  cross-reference). The rule is still documented; only the mechanical enforcement is deferred.
- If Phase 5's ten runs are NOT identical, do not retry-until-green and do not close the task.
  Capture the divergent runs' full output, and report the divergence — a genuinely non-identical
  result at a fixed SHA with a fresh deploy would overturn the research finding and warrants a new
  round of investigation, not a workaround.
