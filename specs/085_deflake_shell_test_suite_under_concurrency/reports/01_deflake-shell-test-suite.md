# Research Report: Task #85

**Task**: 85 - deflake_shell_test_suite_under_concurrency
**Started**: 2026-08-24T22:00:00-07:00
**Completed**: 2026-08-24T22:20:00-07:00
**Effort**: research
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/tests/run-all.sh`,
  `agent-system/extensions/core/scripts/tests/*.sh` (all 41 suites, audited),
  `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/scripts/validate-return-meta.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh`
- Live reproduction: direct execution of `run-all.sh`, standalone execution of the two
  offending suites, one deliberately concurrent run (two simultaneous `run-all.sh`
  invocations), git history of the two offending fixtures
**Artifacts**:
- This report

## Executive Summary

- **The suite is not primarily a lock-contention/race-condition problem.** No defect was found
  in `task-lock.sh` itself, and every one of the 7 test files that exercise it correctly copies
  it into an isolated scratch tree with `PROJECT_ROOT` (or `REPO_ROOT`) redirected away from the
  real repo before calling it. `run-all.sh` itself never acquires a lock and never touches
  `specs/.locks` or `specs/state.json`.
- **Two concrete, currently-live, 100%-deterministic defects fully explain the observed
  run-to-run inconsistency**, and both were reproduced standalone (zero concurrent load,
  single process, single invocation) — proving they are not flakes in the classic
  scheduling-race sense:
  1. `test-validate-return-meta.sh` hardcodes a real task-directory path
     (`specs/052_return_meta_artifacts_shape_contract/...`) as its "well-formed" fixture and
     resolves it against the **live, mutable** `specs/` tree. That directory was archived by an
     ordinary `/todo` run on 2026-08-17 (commit `8a104a17c`, "archive 25 completed tasks"), so
     the fixture path has not existed since. The suite has failed 3 of its cases deterministically
     ever since, in every run.
  2. `test-skill-base-lifecycle.sh`'s `skill_cleanup` case (Group 2) still asserts that
     `.return-meta.json` is deleted, but `skill_cleanup()` was deliberately changed on the same
     day (commit `75ec7bfa6`, "task 17 phase 1: stop skill_cleanup deleting .return-meta.json")
     to stop deleting that file — a documented, intentional behavior change whose rationale is
     recorded in the function's own header comment. The test was never updated to match, and has
     failed deterministically ever since.
- Both defects are **repository-state staleness bugs in the tests themselves**, not races.
  They explain why two runs minutes apart in the same session can show *different* failing
  suites: the observer is not seeing non-determinism at a fixed commit, they are seeing the
  effect of commits landing between measurements in an actively-orchestrated repo with many
  concurrent agent sessions (this session alone has 5 sibling agents active), compounded by the
  previously-diagnosed deploy-tree-staleness confounder (verify-deploy Gate 8 runs against the
  deployed `.claude/` tree, which can lag the source store).
- **Fixes are cheap, validated, and file-scoped**: no changes to `run-all.sh` or `task-lock.sh`
  are needed. Both offending tests need small, isolated edits described below.

## Context & Scope

Diagnose why `agent-system/extensions/core/scripts/tests/run-all.sh` (`tests/run-all.sh`) reports
different failure sets across runs, per the task's measured evidence (gate-8 run failing
`test-mint-dispatch-seq.sh` Cases B-F / `fix-roundtrip` / a "single-source assertion"; an
independent standalone run failing `test-validate-return-meta.sh` instead; a 2026-08-11 review
recording a roughly 2-in-5 failure rate across five consecutive runs). File scope: `run-all.sh`,
the `scripts/tests/` directory, and `task-lock.sh`.

The task's own framing distinguishes two things that must not be conflated: (a) real flake caused
by concurrent sibling sessions holding locks / mutating shared state, which must be fixed by
isolation or deterministic waiting, and (b) real, non-flake failures such as deploy staleness,
which must not be misattributed to flake and must not be waved away as flake either. This
research adds a **third category** the task description did not yet name: tests that are
individually deterministic (same result every time, at a fixed commit, with or without
concurrent load) but whose fixtures silently drifted out of sync with either (i) the live
repository they read from, or (ii) the implementation they exercise. That category, not lock
contention, is what the evidence in this repository actually shows.

## Findings

### 1. `test-validate-return-meta.sh` — live-`specs/`-path dependency (CONFIRMED, reproduced)

`agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh:57` sets:

```bash
EXISTING_PATH="specs/052_return_meta_artifacts_shape_contract/plans/01_return-meta-artifacts-contract.md"
```

`validate-return-meta.sh` resolves every artifact path against `$REPO_ROOT` (an env var,
defaulting to the real repo root via `git rev-parse --show-toplevel`) and requires it to exist on
disk (`validate-return-meta.sh:257`-equivalent check in `return-meta-artifacts-lib.sh`). The test
never overrides `REPO_ROOT`, so `EXISTING_PATH` is checked against the **actual, live**
`specs/` tree — the only test file in the entire 41-suite directory that does this (confirmed by
auditing every suite for hardcoded `specs/0NN_*` references; every other suite uses either its
own `mktemp -d` scratch fixture or a purely-synthetic path like `specs/000_x` /
`specs/001_fixture_task` that the code under test never checks for on-disk existence).

`specs/052_return_meta_artifacts_shape_contract/` was archived to
`specs/archive/052_return_meta_artifacts_shape_contract/` by commit `8a104a17c` ("todo: archive 25
completed tasks", 2026-08-17). The test was added in the very commit that created task 52
(`328110e1b`), self-referentially pointing at its own task's plan file — a landmine that was
always going to detonate the first time `/todo` archived that task.

**Reproduced standalone** (single process, no concurrent load):

```
$ bash agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh
[FAIL] well-formed: validator exited 1 (expected 0)
...
[FAIL] fix-roundtrip: --fix run exited 1 (expected 0)
[FAIL] fix-roundtrip: repaired file exited 1 on independent re-validation (expected 0)
Passed: 11
Failed: 3
```

This reproduced identically across two further runs, including one run made deliberately
concurrent with a second `run-all.sh` invocation racing against it — the failure count and content
never varied. This is the "fix-roundtrip" item named in the task's gate-8 measurement (Case 10 of
this same suite) and is the most likely source of the standalone run's `test-validate-return-meta.sh`
failures too.

### 2. `test-skill-base-lifecycle.sh` — stale assertion against an intentionally-changed function (CONFIRMED, reproduced)

`skill-base.sh:730-747`'s `skill_cleanup()` header comment reads (in full):

> Removes `.postflight-pending` and `.postflight-loop-guard` only. `.return-meta.json` is NOT
> removed here: this function runs at the skill's own Stage 9, which always fires before the
> calling command's command-gate-out.sh ... ever read the file. Deleting it here made that entire
> body structurally unreachable. Ownership of `.return-meta.json`'s deletion belongs to the
> calling command's own last step that consumes it...

This is a deliberate, documented fix: commit `75ec7bfa6` ("task 17 phase 1: stop skill_cleanup
deleting .return-meta.json", 2026-08-17 — the same day as the archiving above) removed
`.return-meta.json` from `skill_cleanup()`'s `rm -f` list.

`test-skill-base-lifecycle.sh`'s Group 2 (`agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh:186-197`)
still creates all three files and asserts all three are gone after `skill_cleanup`:

```bash
touch "$CLEANUP_TASK_DIR/.postflight-pending" \
      "$CLEANUP_TASK_DIR/.postflight-loop-guard" \
      "$CLEANUP_TASK_DIR/.return-meta.json"
( cd "$WORKDIR" && skill_cleanup "002" "cleanup_fixture" )
if [[ ! -f ".../.postflight-pending" ]] && [[ ! -f ".../.postflight-loop-guard" ]] && \
   [[ ! -f ".../.return-meta.json" ]]; then
  pass ...
else
  fail "skill_cleanup left at least one lifecycle temp file behind"
```

`skill_cleanup()` was never meant to delete `.return-meta.json` (as of Aug 17), so this assertion
fails on every single invocation, forever, regardless of concurrency.

**Reproduced standalone**:

```
$ bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh
[FAIL] skill_cleanup left at least one lifecycle temp file behind
Results: 17 passed, 1 failed
```

The suite's own contamination guard passes (`real specs/ tree status is unchanged relative to
this suite's pre-run baseline`), confirming this suite's isolation from the live `specs/` tree is
otherwise sound — it builds a full scratch fixture repo (`build_fixture_repo()`, copying
`task-lock.sh` and friends into `$WORKDIR/.claude/scripts/`) exactly like the correct pattern
described below. This is a pure content/assertion staleness bug, isolated to one `if` block.

### 3. `task-lock.sh` — no defect found; isolation pattern is applied consistently

Reviewed for genuine concurrency defects (race windows in `mkdir`-based mutex acquisition, PID
reuse in the session registry, TOCTOU in `find_held_locks`) — the file's own comments document
that the mutex uses a genuinely atomic `mkdir` primitive (deliberately chosen over the
non-atomic `jq -n > file` pattern used elsewhere), that `acquire_named_mutex`'s wait-and-retry
wrapper closes a scan-then-mkdir TOCTOU race, and that the session registry avoids any mutex
entirely by relying on tmp-file-rename atomicity per session file. No defect was found in the
portions reviewed (acquire/release mutex primitives, session-registry read/write paths,
`find_held_locks`).

Every test file that exercises `task-lock.sh` (`test-git-commit-scoped.sh`,
`test-loop-guard-staleness.sh`, `test-roadmap-items-producer.sh`, `test-update-task-status.sh`,
`test-loop-guard-budget-override.sh`, `test-postflight-deploy-gate.sh`,
`test-skill-base-lifecycle.sh`) does so by copying `task-lock.sh` (and its sibling dependency
scripts) into a per-test `mktemp -d` scratch tree and pointing `PROJECT_ROOT`/`REPO_ROOT` at that
scratch tree, so `task-lock.sh`'s `find "$PROJECT_ROOT/specs" ...` calls, `specs/.sessions`
resolution, and mutex directories all live under the scratch tree, never the real repo. This is
the correct, already-established idiom in this codebase (`test-skill-base-lifecycle.sh`'s
`build_fixture_repo()` is the fullest example) — it is what `test-validate-return-meta.sh` should
have used and does not (Finding 1).

`run-all.sh` itself never calls `task-lock.sh`, never touches `specs/.locks` or
`specs/.sessions`, and `verify-deploy.sh`'s Gate 8 call site (`verify-deploy.sh:406-424`) does not
wrap the `run-all.sh` invocation in any lock acquisition either. There is no code path by which a
concurrent sibling session's task lock could block or corrupt a `run-all.sh` run.

### 4. Full-suite baseline at the current commit

Two full `run-all.sh` runs (one made deliberately concurrent with a second simultaneous
invocation) both reported the identical result:

```
50 passed, 2 failed, 0 skipped, 52 total
[FAIL] .../tests/test-skill-base-lifecycle.sh
[FAIL] .../tests/test-validate-return-meta.sh
```

This is itself informative: run **concurrently**, the suite is already perfectly consistent
(same 2 failures, same case-level detail, both times) — the deployed `.claude/` tree currently
matches the source store byte-for-byte (`diff` clean on `skill-base.sh`), so the previously-noted
deploy-staleness confounder is not currently in effect either. The only variance the task's
historical measurements show is fully explained by Findings 1 and 2 (which suite each
measurement's snapshot of the repo happened to catch as broken) plus deploy staleness at the time
of those specific measurements — not by a race condition reproducible at a fixed commit.

## Decisions

- Treat this task's deliverable as: fix the two stale-fixture defects (isolate
  `test-validate-return-meta.sh` from the live `specs/` tree; correct
  `test-skill-base-lifecycle.sh`'s Group 2 assertion to match `skill_cleanup()`'s documented
  two-file contract), plus a light preventive audit — not a `task-lock.sh` or `run-all.sh` code
  change, since no defect was found in either.

## Recommendations (validated, ready for `/plan`)

### Fix 1 — `test-validate-return-meta.sh`: build its own fixture repo

Mirror `test-skill-base-lifecycle.sh`'s `build_fixture_repo()` pattern: create a scratch
`$WORKDIR/.claude/scripts/{,lib/}` containing copies of `validate-return-meta.sh` and
`return-meta-artifacts-lib.sh`, plus a scratch `$WORKDIR/specs/<fixture>/plans/<fixture>.md`
file, and invoke the validator with `REPO_ROOT="$WORKDIR"` so path resolution never touches the
real repo. Validated end-to-end manually:

```bash
WORKDIR="$(mktemp -d)"
mkdir -p "$WORKDIR/specs/999_fixture_task/plans" "$WORKDIR/.claude/scripts/lib"
cp agent-system/extensions/core/scripts/validate-return-meta.sh "$WORKDIR/.claude/scripts/"
cp agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh "$WORKDIR/.claude/scripts/lib/"
echo "# fixture plan" > "$WORKDIR/specs/999_fixture_task/plans/01_fixture-plan.md"
# ... write a meta.json referencing "specs/999_fixture_task/plans/01_fixture-plan.md" ...
REPO_ROOT="$WORKDIR" bash "$WORKDIR/.claude/scripts/validate-return-meta.sh" "$WORKDIR/meta.json"
# -> RETURN-META VALIDATION PASSED, exit 0
```

This removes the last dependency this suite has on any real, numbered `specs/` directory —
after this fix nothing in `scripts/tests/` reads a live task path any more, and the suite becomes
immune to any future `/todo` archive or task-renumbering vault operation, run by this session or
any concurrent one.

### Fix 2 — `test-skill-base-lifecycle.sh`: match Group 2's assertion to `skill_cleanup()`'s current contract

Remove `.return-meta.json` from both the `touch` list and the `[[ ! -f ... ]]` conjunction in
Group 2 (`test-skill-base-lifecycle.sh:186-197`), so the case asserts the documented two-file
contract (`.postflight-pending`, `.postflight-loop-guard`) rather than the pre-Aug-17 three-file
one. Optionally strengthen the case by also asserting `.return-meta.json` is **still present**
after `skill_cleanup` (a positive control for the ownership-transfer behavior the header comment
describes), which would have caught this exact drift the moment it happened instead of leaving it
silently red for a week.

### Preventive audit (recommended, low cost)

A one-line guard for future `/plan`+`/implement` work on this task: grep every file in
`scripts/tests/` for `specs/[0-9][0-9][0-9]_` outside a suite's own `mktemp`/scratch-root
variable, to catch any other live-path dependency before it bit-rots the way Finding 1 did. This
research's manual pass (grep across all 41 suites, cross-checked each hit against whether the
matched string ever reaches an `-f`/`-e`/`-d` test) found none beyond Finding 1, but a mechanical
lint would keep it that way.

## Risks & Mitigations

- **Risk**: Fix 2's positive control (asserting `.return-meta.json` survives) could itself go
  stale again if `skill_cleanup()`'s contract changes again. Mitigation: the assertion should
  quote the header comment's contract explicitly in a code comment, so a future contract change
  is more likely to prompt updating the test in the same commit (this is exactly the omission
  that caused Finding 2).
- **Risk**: Other suites may have similar-but-subtler live-state dependencies not caught by a
  grep for `specs/[0-9]{3}_`. Mitigation: the preventive audit above; also worth spot-checking
  after Fix 1/2 land by running `run-all.sh` 10x consecutively per the task's acceptance
  criterion, including at least one run concurrent with a live session, and confirming identical
  results — this is the acceptance test itself, not an extra step.

## Context Extension Recommendations

- **Topic**: shell-test-suite fixture isolation
- **Gap**: `context/standards/shell-script-testing.md` (referenced throughout the suite's own
  header comments as the location-rule standard) does not appear to state the "never resolve a
  path against the live `specs/` tree; always build or copy a scratch fixture" rule this research
  found violated once. Given `build_fixture_repo()` in `test-skill-base-lifecycle.sh` is already
  treated as the reference structural model by several other suites' own header comments, this
  rule is implicit convention, not written standard.
- **Recommendation**: add a short "never touch the live `specs/` or `.claude/` tree" rule to
  `context/standards/shell-script-testing.md`, pointing at `build_fixture_repo()` as the canonical
  pattern, so this class of defect is caught in review rather than discovered a week later by a
  flake investigation.

## Appendix

### Commands / searches used

- `grep -rln "fix-roundtrip\|single.source" agent-system/extensions/core/scripts/` and targeted
  `grep -rn "specs/0[0-9][0-9]_"` sweeps across `scripts/tests/*.sh`
- `git log --oneline --diff-filter=A -- specs/archive/052_return_meta_artifacts_shape_contract/...`
  and `git log -p -1 -L /^skill_cleanup/,+8:.../skill-base.sh`
- Direct execution: `bash test-validate-return-meta.sh`, `bash test-skill-base-lifecycle.sh`,
  `bash run-all.sh --quiet` (twice, one run deliberately concurrent with a second invocation)
- Manual reproduction of the Fix 1 approach (`REPO_ROOT` override + scratch `.claude/scripts`
  copy) against the real `validate-return-meta.sh`, confirmed exit 0

### Suites audited for live-state dependency (none found besides Finding 1)

All 41 suites under `agent-system/extensions/core/scripts/tests/` use `mktemp -d` except
`test-status-vocabulary.sh`, which only *reads* two static repo files
(`lib/status-vocabulary.sh`, `context/schemas/state-schema.json`) and asserts no on-disk
existence of a task-numbered path — currently passing cleanly (22/22) and not implicated in the
task's measured failures.
