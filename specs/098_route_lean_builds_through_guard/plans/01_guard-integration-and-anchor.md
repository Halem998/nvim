# Implementation Plan: Task #98

- **Task**: 98 - Route lean extension builds through the guard and rewrite the multi-instance operations anchor
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: 97 (lake-build-guard.sh — complete, shipped)
- **Research Inputs**: specs/098_route_lean_builds_through_guard/reports/01_route-census-through-guard.md
- **Artifacts**: plans/01_guard-integration-and-anchor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The shared Lean build guard is shipped with zero consumers. This plan wires its first consumer —
the `--cross-check` branch of `lean-sorry-census.sh` — records the lifecycle-hook decision with
reasons, and rewrites `multi-instance-optimization.md` from human-advisory prose into mechanism
documentation with figures that match measurement. All edits stay inside the four declared
`file_scope` paths under `agent-system/extensions/lean/**`; no `.claude/**` file and no contract
file owned by the background-builds task is touched. Definition of done is the task's own
ACCEPTANCE clause, checked mechanically in the final phase.

### Research Integration

Findings adopted verbatim from `reports/01_route-census-through-guard.md`:

- **Guard CLI is fixed and must not be re-litigated**: `status` / `preflight` / `build`, with
  `build` passing lake's own exit code through untouched and reserving 75-79 for guard-specific
  failures (75 lock-wait timeout, 76 deferred-on-pressure, 77 usage, 78 no Lean project, 79
  missing capability).
- **Edit site confirmed** at `lean-sorry-census.sh` lines 181-182 inside the `--cross-check`
  branch, whose existing `command -v lake` check (line 178) is the graceful-degradation precedent
  to mirror for guard-absence.
- **Flat deploy topology**: the census script and the guard come from different source-store
  extensions but land as literal siblings in `.claude/scripts/`. A
  `$(dirname "${BASH_SOURCE[0]}")`-relative lookup is therefore correct post-deploy and wrong
  pre-deploy — hence an overridable env-var test seam, mirroring the guard's own
  `LAKE_BUILD_GUARD_LAKE_BIN` precedent, is required rather than merely convenient.
- **Hook decision: no hook.** `skill_get_extension_dir` keys hook resolution strictly on
  `task_type == "lean4"`, so a lean hook would not have fired even for this `meta`-typed task
  editing Lean files; and hooks are non-blocking by design, so a preflight hook cannot enforce a
  refusal. Reasoning is recorded in the anchor doc, not left implicit in a commit message.
- **The 8GB claim is false**: `multi-instance-optimization.md` line 119 asserts "Memory usage
  stays under 8GB (vs 16GB+ spikes)"; the measured figure on record is 16 `lean` processes holding
  29.9 GB RSS on a 30 GB machine. The rewrite corrects this.

Two points of implementation detail that the guard's own source settles and this plan therefore
treats as ground truth rather than re-deriving:

- **`--quiet --collect` is the guard's problem, not the call site's.** `run_lake_foreground`
  already passes `--quiet --collect` to `systemd-run` and its own comment marks them MANDATORY,
  not cosmetic, precisely because systemd's status chatter on stderr would otherwise corrupt a
  `$(... 2>&1)` capture. That is the property that makes the guard safe to drop into this exact
  call site. The census script MUST NOT re-implement, re-pass, or second-guess those flags.
- **Always pass an explicit `-- build`.** The guard forwards `"${lake_args[@]}"` to `cmd_build`;
  an empty forwarded array is a needless `set -u` hazard, and an explicit `-- build` also
  preserves today's exact `lake build` semantics rather than relying on a guard-side default.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- Route `lean-sorry-census.sh --cross-check`'s build through the guard while preserving the
  existing capture of BOTH combined output and exit status in a command substitution.
- Degrade gracefully — never hard-fail — when `lake` is absent, when the guard is absent, or both.
- Cover the new path in `test-lean-sorry-census.sh` with fixtures that demonstrably discriminate
  guarded from unguarded behavior (no vacuous tests).
- Record the lifecycle-hook decision with its reasoning in durable documentation.
- Rewrite `multi-instance-optimization.md` as mechanism documentation with corrected figures, and
  state the detach-without-guard amplification interaction explicitly in writing.

**Non-Goals**:

- Editing any agent, skill, rule, or contract text that instructs an agent to run `lake build`.
  Those eight files are owned by the background-builds task and editing them here is the exact
  twin-file drift this extension treats as a recurring defect class.
- Creating `operations/long-builds.md`. It is owned by a separate concurrent task and does not
  exist on disk yet.
- Editing any `.claude/**` file. That tree is a disposable deploy artifact.
- Re-litigating the guard's mechanism, subcommand shape, or exit-code band.
- Re-proposing `lake -j` / `--jobs` or `LEAN_NUM_THREADS`. Both are recorded dead ends in the
  guard's own header.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dirname-relative guard lookup fails when the census script runs from the source store (its own home and the guard's home are not siblings pre-deploy) | H | H (certain in the test suite) | `LEAN_SORRY_CENSUS_GUARD_BIN` env-var override, `:-`-defaulted to the dirname-relative sibling; this is what makes the tests runnable at all |
| A new hard-failure path is introduced where the guard is not deployed | H | M | Three-way branch with plain `lake build` fallback; Phase 1 writes a guard-absent fixture that must pass identically before and after the change |
| Guard band 75-79 surfaces as an opaque non-zero status in the census warning line | M | M | Extend the existing warning line to name the guard when the guarded path was taken; do not build an exit-code taxonomy |
| Memory-pressure warn path adds one stderr line inside `BUILD_OUTPUT` | L | M | Substring grep for `declaration uses 'sorry'` is unaffected; note it in an inline comment at the call site so a future reader diffing raw output is not surprised |
| Anchor cross-references a `long-builds.md` that does not exist yet | L | H | Reference by filename/path only; describe its subject in general terms; assert no section headings or content from it |
| Fixtures pass against both the old and new script, silently proving nothing | M | M | Phase 1 runs the new fixtures against the UNMODIFIED script first and records the expected pass/fail split, following this suite's own established falsifiability gate |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2), 3 (for 4) |
| 3 | 5 | 2, 4 |

Phases within the same wave can execute in parallel. Phases 1-2 touch only the two script files;
phases 3-4 touch only the anchor doc and the manifest. The two tracks share no file.

---

### Phase 1: Author guard-path fixtures and run the falsifiability gate [COMPLETED]

**Goal**: Extend `test-lean-sorry-census.sh` with `--cross-check` fixtures covering guard-present,
guard-absent, and lake-absent paths, and prove they discriminate by running them against the
still-unmodified census script.

**Tasks**:

- [x] Read `test-lean-sorry-census.sh` in full and reuse its house style exactly: `pass()` /
      `fail()` / `info()` helpers, `PASSED` / `FAILED` integer counters, one `mktemp -d` workdir
      with a `trap ... EXIT` cleanup, synthetic heredoc fixtures only, `exit 0` all-pass /
      `exit 1` any-fail. Do not import the guard suite's `FAKE_LAKE_*` convention — that is a
      different script's convention. *(completed)*
- [x] Add a helper that builds a synthetic Lean project in the workdir (a `lakefile.toml` plus one
      `.lean` file with a known sorry count) so the guard's own project-root resolution succeeds
      when it is exercised. *(completed: make_synthetic_lean_project)*
- [x] Add a helper that fabricates a stub `lake` on a synthetic `PATH`, echoing a controllable
      number of `declaration uses 'sorry'` lines and exiting with a controllable status.
      *(completed: make_stub_lake)*
- [x] Add a helper that fabricates a stub guard script honoring `build [flags] -- <lake args>`,
      echoing a marker line to stdout so the test can prove the guarded path was actually taken,
      and passing through a controllable exit status. *(completed: make_stub_guard)*
- [x] Fixture F — lake absent: `PATH` without `lake`; assert output contains
      `cross_check: unavailable (lake not found in PATH)` regardless of guard presence, proving
      this branch is still checked first and still wins. *(completed: uses
      make_isolated_bin_without_lake, an isolated-PATH helper, since blanket removal of any PATH
      directory containing an executable named lake also removed bash on this machine)*
- [x] Fixture G — lake present, guard absent: point `LEAN_SORRY_CENSUS_GUARD_BIN` at a
      nonexistent path; assert `compiler_sorry_count` / `stripper_sorry_count` /
      `cross_check: MATCH` output shape is byte-identical to pre-integration behavior.
      *(completed)*
- [x] Fixture H — lake present, guard present: point `LEAN_SORRY_CENSUS_GUARD_BIN` at the stub
      guard; assert the guard marker line appears in captured output AND that `compiler_sorry_count`
      is still parsed correctly from the combined capture. *(completed)*
- [x] Fixture I — guarded non-zero exit: stub guard exits non-zero; assert the existing
      `exited non-zero` warning still fires on stderr and reports the guard's status.
      *(completed)*
- [x] Anti-vacuous check: assert Fixture H's captured output DIFFERS from Fixture G's (the marker
      line is present in exactly one), so a fixture both implementations would agree on cannot
      masquerade as coverage. *(completed)*
- [x] Run the suite against the unmodified `lean-sorry-census.sh`. Expected split: F and G PASS
      (behavior-preserving branches), H and I FAIL (the guard path does not exist yet). Record the
      observed split in the phase's commit message. If H or I PASSES here, the fixture is vacuous
      — fix the fixture before proceeding. *(completed: observed split matched exactly — F and G
      PASS in full, H and I FAIL in full; Passed: 11, Failed: 4; see
      progress/phase-1-progress.json's falsifiability_gate_result)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts four new fixtures (F-I) plus three helpers is sufficient
coverage for the new path. Confirm at implementation time by re-reading the ACCEPTANCE clause in
the task description and checking each of its three degradation conditions (lake absent, guard
absent, both present) maps to at least one fixture; add fixtures if a condition is uncovered
rather than declaring the count met.

**Files to modify**:

- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` - append fixtures F-I and
  their helpers; extend the header comment to describe the second regression concern (guard
  routing) alongside the existing `warn.sorry` double-count concern.

**Verification**:

- `bash -n agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` parses.
- Suite runs to completion (non-zero exit is EXPECTED at this phase) and prints the F/G PASS,
  H/I FAIL split.
- Existing Fixtures A-E still PASS, unchanged.

---

### Phase 2: Route the census cross-check build through the guard [NOT STARTED]

**Goal**: Replace the unguarded `lake build` command substitution with a three-way branch that
routes through the guard when available and falls back to today's exact behavior otherwise,
turning Phase 1's failing fixtures green.

**Tasks**:

- [ ] Locate the call site by content, not line number: `BUILD_OUTPUT="$(lake build 2>&1)"`
      followed by `BUILD_STATUS=$?` inside the `if [[ $CROSS_CHECK -eq 1 ]]` block.
- [ ] Resolve the guard path once, above the branch:
      `GUARD_BIN="${LEAN_SORRY_CENSUS_GUARD_BIN:-$(dirname "${BASH_SOURCE[0]:-$0}")/lake-build-guard.sh}"`.
      Use the `${BASH_SOURCE[0]:-$0}` form so the script still resolves when sourced or invoked
      via `bash <path>`.
- [ ] Implement the three-way branch, preserving branch order so the existing `lake`-absent check
      is still evaluated FIRST:
      (a) `lake` absent -> unchanged `cross_check: unavailable (lake not found in PATH)`;
      (b) `lake` present, guard not executable -> unchanged `BUILD_OUTPUT="$(lake build 2>&1)"`;
      (c) both present -> `BUILD_OUTPUT="$("$GUARD_BIN" build -- build 2>&1)"`.
      In all three branches `BUILD_STATUS=$?` is captured on the immediately following line and
      the `COMPILER_COUNT` / `MATCH` / `MISMATCH` reporting is untouched.
- [ ] Pass `-- build` explicitly. Do not pass `--dir` (defaults to `$PWD`, matching today's
      undirected invocation exactly), do not pass `--memory-bound`, `--defer-on-pressure`, or
      `--no-share`. Recorded decision: memory bounding stays opt-in and off here, because the
      census is a verification read-out whose value is a correct count, and an aborted or deferred
      build would silently under-count rather than fail loudly.
- [ ] Track whether the guarded branch was taken in a small flag variable and use it to extend the
      existing non-zero warning so the guard is named when it was used — e.g. distinguishing
      "guarded lake build exited non-zero (N)" from today's "lake build exited non-zero (N)". Do
      not build an exit-code taxonomy; a caller needing to disambiguate the guard's reserved 75-79
      band from lake's own codes calls `status`/`preflight` separately, per the guard's header.
- [ ] Add an inline comment at the call site noting that on the memory-pressure warn-and-proceed
      path the guard emits one extra stderr line which lands inside the combined `2>&1` capture;
      this is harmless because the `declaration uses 'sorry'` grep is substring-based, but a future
      reader diffing raw census output should not be surprised by it.
- [ ] Update the script's header `Usage`/`Output (with --cross-check, ...)` block to describe the
      guard routing and the new env var, and document `LEAN_SORRY_CENSUS_GUARD_BIN` as a test seam.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the edit is confined to the ~20-line `--cross-check`
block plus the header comment of one file. Confirm with `git diff --stat` showing exactly one
file changed and the diff hunks falling only in the header and the `CROSS_CHECK` block; if the
diff reaches outside those regions, stop and re-scope.

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` - guard path resolution, three-way
  cross-check branch, extended non-zero warning, inline pressure-line comment, header docs.

**Verification**:

- `bash -n agent-system/extensions/lean/scripts/lean-sorry-census.sh` parses.
- `shellcheck` on the changed script reports no new findings versus its pre-change baseline
  (capture the baseline before editing so "new" is decidable).
- `bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` exits 0 with all
  fixtures A-I passing — the exact fixtures that failed in Phase 1 are now green.
- Fixture G still passes, proving the guard-absent fallback did not regress.

---

### Phase 3: Rewrite the operations anchor as mechanism documentation [NOT STARTED]

**Goal**: Replace the anchor's human-advisory remedies with guard mechanism documentation, correct
the falsified memory figures, and state the detach-without-guard amplification interaction in
writing.

**Tasks**:

- [ ] Preserve, essentially as-is: the `## Overview` framing, the `### Root Cause` section
      (concurrent `lake build` memory pressure, `.olean` file-locking contention, CPU saturation,
      diagnostic delays), and the `## Monitoring` section's `ps aux --sort=-%mem` and `htop`
      commands. The task description names the diagnosis as sound and the remedies as the stale
      part.
- [ ] Preserve the `LEAN_LOG_LEVEL` / `LEAN_PROJECT_PATH` MCP environment configuration — it is
      MCP-transport tuning, not a build-concurrency remedy, and the guard does not supersede it.
- [ ] Delete the human-advisory remedies: "pause work in 3-4 other sessions", "run `lake build`
      before starting Claude sessions", "allow 1-2 minutes for LSP to stabilize", and the
      per-phase before/during/after session choreography under `## Workflow Recommendations`.
- [ ] Write a `## The Build Guard` mechanism section covering: flock-based serialization of
      concurrent builds; result sharing (a waiter replays a fresh prior result instead of running a
      redundant build) and the staleness policy that decides freshness; the PSI + swap preflight;
      opt-in `systemd-run --user --scope` memory bounding and its audible degradation when
      user-scope cgroup delegation is unavailable; and the silent-when-no-conflict invariant that
      makes the guard safe inside a `$(... 2>&1)` capture.
- [ ] Write a `## Invoking the guard` section naming the three subcommands and when a caller
      reaches for each: `status` (read-only view of lock/pressure state), `preflight` (should I
      start a build now), `build` (run one, serialized and optionally bounded). Note that `build`
      passes lake's own exit code through and reserves 75-79 for guard-specific outcomes, and that
      a caller needing to disambiguate calls `status`/`preflight` separately.
- [ ] Write the interaction section, plainly and without hedging: detaching builds so they escape
      the 10-minute foreground cap is a correct fix for a real livelock (a cap-killed build caches
      no `.olean`, so retries restart at the identical module), but that cap is currently the only
      thing bounding how long a redundant concurrent build survives. Removing it without
      serialization means ten duplicate builds run to completion instead of ten dying at ten
      minutes, each holding multi-gigabyte `lean` processes for the full duration. Detached
      invocation and serialization must land together; adopting either half alone makes the
      measured memory situation strictly worse.
- [ ] Correct the figures. Delete "Memory usage stays under 8GB (vs 16GB+ spikes)" and the
      "60-80% reduction in timeout frequency" / "within 30s (vs 60s+)" predictions. State the
      measured observation instead — 16 concurrent `lean` processes holding 29.9 GB RSS on a 30 GB
      machine with 29 GB of swap in use and 3.1 GB available — and label it explicitly as one
      illustrative measurement on one machine, not a predictive ceiling to be hardcoded as an
      assumption.
- [ ] Add a forward reference to the sibling anchor by filename only —
      `operations/long-builds.md`, covering the foreground-cap livelock and passive progress
      checks — with no assertion about its section headings or current content, since it may land
      before or after this file depending on dispatch order.
- [ ] Keep the single-anchor convention: prose lives here once and is referenced by path from call
      sites, never restated at them. Do not duplicate the guard's own header rationale verbatim;
      summarize its mechanism and point to the script.
- [ ] Retain a short "what an operator can still do by hand" subsection (the `ps`/`htop` checks,
      and reducing concurrent Lean sessions when contention is observed) so manual diagnosis
      survives, demoted from primary remedy to fallback.
- [ ] Cite no task numbers anywhere in the file.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly the `## Prevention Strategies`,
`## Workflow Recommendations`, and `## Expected Results` sections need replacing while
`### Root Cause` and `## Monitoring` are preserved. Confirm at implementation time by re-reading
the current file end to end and checking each remaining section against the test "does this
instruct a person to do something the guard now does automatically"; adjust the preserve/replace
split on what the file actually says rather than on this list.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md` -
  full rewrite of remedies; diagnosis and monitoring preserved; figures corrected.

**Verification**:

- The strings `8GB`, `16GB+`, `60-80%`, and `pause work in 3-4 other sessions` no longer appear.
- The measured 29.9 GB figure appears and is explicitly labeled illustrative rather than
  predictive.
- The detach-without-guard amplification statement is present as prose, not implied.
- `grep -n 'long-builds.md'` finds the forward reference; no claim about its contents accompanies
  it.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no task-number
  reference in this file.

---

### Phase 4: Record the lifecycle-hook decision and confirm the manifest needs no change [NOT STARTED]

**Goal**: Record "no lean lifecycle hook" as an explicit, reasoned decision in the anchor doc, and
confirm by inspection that `manifest.json` correctly requires no edit.

**Tasks**:

- [ ] Re-verify the manifest premise before recording anything:
      `jq 'has("hooks")' agent-system/extensions/lean/manifest.json` returns `false`, and
      `provides.hooks` is `[]`. If either has changed since research, stop and re-decide rather
      than recording a stale premise.
- [ ] Read both live reference implementations before concluding — `nix` (top-level `hooks` with
      `preflight` + `context_injection`) and `nvim` (`context_injection` only) — so the decision is
      made against the real contract and not a summary of it. This is a lightly-trodden path.
- [ ] Add a `## Why there is no lean lifecycle hook` section to the anchor doc recording the
      decision and its four reasons: (1) hook resolution keys strictly on `task_type == "lean4"`
      via `skill_get_extension_dir`, so a `general`- or `meta`-typed task working in a Lean
      repository — including the task that wrote this very section — would get nothing;
      (2) hooks are non-blocking by design, a non-zero exit is caught and downgraded to a
      `[skill-base] WARNING`, so a preflight hook cannot enforce a refusal and would imply
      protection it cannot deliver; (3) the enforceable mechanism already exists and is directly
      invocable — the guard's own PSI/swap preflight and `--defer-on-pressure`, needing no hook
      machinery; (4) any actual refusal obligation belongs in contract text, which this scope does
      not own.
- [ ] State the disposition of the operation-filtering question explicitly: since no hook is added,
      the "should the hook self-filter on `operation`" question is moot and is recorded as such
      rather than left silently unanswered — and note that a future hook, if one is ever added,
      would fire for all operations including research, because `operation` is passed as an
      argument rather than filtered on.
- [ ] Confirm and record that `manifest.json` therefore requires no edit: no top-level `hooks`
      object is added, and `provides.scripts` already lists both the census script and its test.
      Leaving a `file_scope` file unmodified is the recorded outcome, not an oversight.
- [ ] Cite no task numbers in the section.

**Timing**: 20 minutes

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `manifest.json` needs zero edits. Confirm with the `jq`
check above plus `git diff --name-only` showing `manifest.json` absent from the changed set; if
the premise fails, the phase converts to adding a hook per the nix five-positional-arg contract
(`task_number`, `task_type`, `task_dir`, `session_id`, `operation`; `set -euo pipefail`; warnings
to stderr; unconditional `exit 0`) registered in BOTH the top-level `hooks` object and
`provides.scripts`.

**Files to modify**:

- `agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md` -
  add the hook-decision record section.
- `agent-system/extensions/lean/manifest.json` - expected: no change (verified, not assumed).

**Verification**:

- The anchor doc contains a section recording the no-hook decision with all four reasons.
- `git diff --name-only` does not list `agent-system/extensions/lean/manifest.json`.
- `jq empty agent-system/extensions/lean/manifest.json` still parses (trivially true if unchanged;
  run it anyway so an accidental edit is caught).

---

### Phase 5: Acceptance sweep and boundary enforcement [NOT STARTED]

**Goal**: Run the full gate set and check every clause of the task's ACCEPTANCE statement plus the
two binding scope rules.

**Tasks**:

- [ ] Run `bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh`; require
      exit 0 with every fixture A-I green.
- [ ] `bash -n` and `shellcheck` both changed shell scripts; no new findings versus baseline.
- [ ] Confirm `git diff --name-only` lists ONLY paths from the declared `file_scope`. Any path
      outside it is a scope violation, not a bonus.
- [ ] Confirm no `.claude/**` path appears in the diff (source-store rule: such an edit silently
      vanishes on the next reload).
- [ ] Confirm none of the eight contract files owned by the background-builds task appear in the
      diff: both implementation agent twins, both implementation skills, both research agents,
      `skill-lake-repair`, and `rules/lean4.md`.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` over the changed
      files; zero task-number references outside `specs/`.
- [ ] Walk the ACCEPTANCE clause literally, one condition at a time: guarded routing with both
      output and status captured; graceful degradation for absent `lake`; graceful degradation for
      absent guard; test covers the new path; hook decision recorded with reasons; anchor no longer
      instructs a human to pause sessions as its primary remedy; anchor documents the guard's
      actual mechanism; no figure contradicted by measurement; sibling anchors cross-reference
      without duplicating; detach amplification stated explicitly; no contract file modified; no
      `.claude/**` file modified.
- [ ] Confirm `operations/long-builds.md` was NOT created by this task.

**Timing**: 25 minutes

**Depends on**: 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- None — verification only.

**Verification**:

- Test suite exit 0; lints clean; changed-file set is a subset of `file_scope`; task-reference lint
  clean; every ACCEPTANCE clause individually checked off.

---

## Testing & Validation

- [ ] `test-lean-sorry-census.sh` exits 0 with fixtures A-E (pre-existing) and F-I (new) all
      passing.
- [ ] The Phase 1 falsifiability record shows H and I failing against the unmodified script,
      proving the new fixtures discriminate.
- [ ] Guard-absent fixture produces output byte-identical in shape to pre-integration behavior.
- [ ] Guard-present fixture proves the guarded path was actually taken via the stub's marker line.
- [ ] `lake`-absent short-circuit still wins regardless of guard presence.
- [ ] `bash -n` and `shellcheck` clean on both changed scripts.
- [ ] `check-task-references.sh` clean on all changed files.
- [ ] Changed-file set is a subset of the declared `file_scope`.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` — cross-check build routed through
  the guard with three-way graceful degradation and a documented test-seam env var.
- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` — fixtures F-I covering
  guard-present, guard-absent, lake-absent, and guarded-non-zero paths.
- `agent-system/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md` —
  rewritten as mechanism documentation with corrected figures, the detach amplification statement,
  a forward reference to the sibling anchor, and the recorded hook decision.
- `agent-system/extensions/lean/manifest.json` — expected unchanged; verified, not assumed.
- `specs/098_route_lean_builds_through_guard/summaries/01_*-summary.md` — implementation summary.

## Rollback/Contingency

Every phase is a single-file, self-contained edit committed separately, so `git revert` of an
individual phase commit restores prior behavior with no cross-phase entanglement. The script
change is additionally self-rolling-back by design: with `LEAN_SORRY_CENSUS_GUARD_BIN` pointed at
a nonexistent path, the census script takes the plain `lake build` branch and behaves exactly as
it does today, so the integration can be disabled at runtime without a code change. If the guard
proves to misbehave at this call site under real load, set that variable to `/nonexistent` as an
immediate mitigation and revert the Phase 2 commit at leisure. The documentation phases are
independently revertible and block nothing.
