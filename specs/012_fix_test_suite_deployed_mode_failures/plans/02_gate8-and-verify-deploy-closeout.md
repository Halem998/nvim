# Implementation Plan: Close the gate-8 flake and the standing verify-deploy failures

- **Task**: 12 - Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
- **Status**: [IMPLEMENTING]
- **Effort**: 8.75 hours total (4.75 completed in Phases 1-5, 4.0 remaining in Phases 6-11)
- **Dependencies**: None (one advisory overlap: the opencode session-id duplication task owns `test-common-lib.sh`)
- **Research Inputs**:
  - specs/012_fix_test_suite_deployed_mode_failures/reports/01_run-all-deployed-mode-triage.md
  - The gate-8 diagnosis recorded in this task's `specs/state.json` `description` field under the
    heading `=== SCOPE EXTENSION (folded in after gate-8 diagnosis; user-approved) ===` (measured
    failure rates, captured assertion text, ruled-out hypotheses, corrected assumptions, and
    file/line anchors). Treated as authoritative measured input, not as a hypothesis to re-derive.
- **Artifacts**: plans/02_gate8-and-verify-deploy-closeout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Phases 1-5 are closed and verified: the `REPO_ROOT` depth defect is eliminated across 17 test
suites, the `test-index-entries-schema.sh` fixture gap is fixed, the `task-lock.sh`
`write_holder()` race is fixed, and both modes measure clean — source-store `run-all.sh` 37/37 and
deployed `run-all.sh` 34/34, with all 18 files this task modified byte-identical between the
source store and the deployed tree. This revision does not reopen, re-verify, or re-plan any of
that work.

What remains is the residual the previous plan's Phase 6 described only vaguely. It is now
diagnosed with captured evidence and splits into two fully independent problems:

1. **The gate-8 flake** in `test-claude-refresh-matcher.sh` assertion (c) — root cause CONFIRMED
   (`kill -0` reports a killed-but-unreaped child as alive), fix route CONFIRMED (injectable
   liveness predicate), and two alternative repair routes DISPROVEN under test.
2. **Standing `verify-deploy.sh` failures** that are entirely independent of gate 8 —
   `verify-deploy.sh` exited non-zero on 20/20 runs regardless of whether gate 8 passed. Fixing
   gate 8 alone cannot turn it green.

This plan replaces the old Phase 6 with six concrete, evidenced, single-agent-run phases (6-11)
and raises the acceptance bar from a single green run to a repeated sample, because a 20% flake is
not disproven by one lucky invocation.

Definition of done: `verify-deploy.sh` reports 0 findings across a repeated sample of 20
consecutive runs with the observed pass/fail fraction stated verbatim, **or** every residual
failure carries a written, evidenced justification. An unqualified "green" claim is never
acceptable.

### Research Integration

Newly integrated: the gate-8 diagnosis recorded in this task's `state.json` `description` under
the `=== SCOPE EXTENSION ===` heading. Its load-bearing findings, restated here so the
implementer does not need to re-derive them:

- **Failure rates measured**: 4/20 (20%) inside `verify-deploy.sh` gate 8; 13/30 (43%) standalone
  on an idle machine; 25/30 (83%) in a mirror copy.
- **Captured signature**, byte-identical across all four gate-8 failures apart from PID:
  `[FAIL] is_live_inhibitor_target: still excludes the SAME inhibitor after its target (pid NNNNNNN) was killed -- tautological check`
- **Mechanism proven directly**: `kill -0` returns success for a killed-but-unreaped child; `wait`
  reaps in 2ms. Failing runs averaged 141.5s vs 131.0s passing — a 10.5s delta against the 8.0s
  poll budget, i.e. every failure burns the full 40 x 0.2s loop.
- **Ruled out**: `task-lock.sh` / `holder.json` TOCTOU. Zero occurrences across all 20 runs.
- **Corrected assumption 1**: the flake is NOT load-sensitive (43% on an idle machine; CPU burners
  did not reproduce it).
- **Corrected assumption 2**: widening the poll budget is DISPROVEN as a fix. No finite budget
  helps a 43-83% failure rate, and the helper sometimes genuinely survives the kill, so widening
  only makes each failure slower.
- **Two real-process repairs failed under test and must not be re-attempted**: a naive `wait` hung
  ~300s (the suite leaks a `sleep 300` helper inheriting stdout/stderr, so any reader using
  command substitution blocks for the full 300s — one run measured 300022ms); `kill -9` + `wait` +
  detached streams killed the test script itself (RC=137, 20/20).
- **Required fix**: the injectable-predicate route (Phases 6-7 below).
- **Standing verify-deploy failures**, independent of gate 8: deploy drift on
  `system-defect-record.sh` (354 source / 352 deployed) and `system-defect-discrimination.md`
  (397 source / 382 deployed) with source AHEAD; an `index-entries.json` `line_count` of 382
  declared for a 397-line file; and a dangling `1015` entry in `specs/state.json` task 9's
  `dependencies` array left over from vault renumbering.

Superseded by this revision: the previous plan's Phase 6, whose "leading suspect / recommended next
step" framing is now replaced by a confirmed root cause and a confirmed fix route. Its
`[PARTIAL]` record is preserved below for history.

### Prior Plan Reference

`plans/01_run-all-deployed-mode-fixes.md`. Phases 1-5 of that plan are carried forward verbatim
and unchanged. Its Phase 6 is superseded by Phases 6-11 here.

### Note on stale path prefixes

The previous plan's Artifacts section and the `state.json` artifact entries record paths under
`specs/1012_...`, a pre-renumbering prefix. The real directory is
`specs/012_fix_test_suite_deployed_mode_failures/`. Use the real path everywhere; do not create or
reference the `1012_` form.

## Goals & Non-Goals

**Goals**:
- Eliminate the gate-8 flake at its confirmed root cause by extracting the liveness syscall in
  `is_live_inhibitor_target` into an overridable seam and driving assertion (c) through a scripted
  probe — preserving the argv-parsing coverage the assertion exists to protect.
- Record, in the replacement code itself, that this weakens the suite's documented "driven by a
  REAL process" intent — as a stated trade-off, never a silent one.
- Clear all three standing `verify-deploy.sh` findings: the two-file deploy drift, the
  `index-entries.json` `line_count` mismatch, and the dangling dependency entry.
- Sequence the `line_count` correction and the redeploy so the final verification observes a
  consistent source/deploy tree.
- Prove the result against a repeated sample and report the observed fraction verbatim.

**Non-Goals**:
- Re-opening, re-verifying, or re-planning Phases 1-5. They are closed.
- Widening the poll budget in `test-claude-refresh-matcher.sh`. Disproven — do not attempt.
- Re-attempting either failed real-process repair (naive `wait`; `kill -9` + `wait` + detached
  streams). Both are measured failures, not untried options.
- Changing `is_live_inhibitor_target`'s production semantics or its documented live-check
  trade-off. The seam extraction must be behavior-equivalent in production.
- Inventing a replacement dependency target for the dead `1015` entry.
- Hand-editing anything under `.claude/**`. That tree is a disposable deploy artifact; every edit
  lands in `agent-system/extensions/**`.
- Fixing `test-common-lib.sh` or `.opencode/scripts/command-gate-in.sh` — owned by the concurrent
  sibling task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The seam extraction accidentally changes production liveness behavior | H | L | The seam body is the exact `kill -0 "$1" 2>/dev/null` expression moved verbatim; Phase 6's verification requires the unmodified suite (pre-Phase-7) to still pass against the seamed script, proving equivalence before the test is touched |
| Replacing the real-process fixture removes genuine coverage | M | M | Only the liveness syscall is substituted. The `--pid=([0-9]+)` extraction, the no-`--pid` rejection path, and both assertion directions run unchanged against the real `is_live_inhibitor_target`. Phase 7 requires an explicit in-file record of what was and was not weakened |
| A test-local `_pid_is_alive` override leaks into later assertions in the same shell | M | M | Phase 7 requires restoring the production seam definition immediately after the assertion (c) block, and verifying the subsequent no-`--pid` assertion still passes in the same run |
| `deploy-headless.sh` is manual-by-default with exactly one sanctioned automated caller | H | H | Phase 10 encodes the same sanctioned-path ladder the closed Phase 4 used: the orchestrator's inter-cycle redeploy checkpoint first, an explicit operator action second, and an evidenced `[BLOCKED]` close third — never a self-invoked deploy on the implementer's own authority, and never a hand-copy into `.claude/**` |
| Correcting `index-entries.json` after the redeploy would leave the deployed tree stale again | M | H | Encoded as a hard ordering constraint: Phase 8 precedes Phase 10, and Phase 10 is the single step that redeploys. Phase 11 re-checks drift after the redeploy rather than assuming it |
| 20 consecutive `verify-deploy.sh` runs is a long wall-clock commitment (~140s each, ~47 min) | L | H | Run the sample as one backgrounded driver loop appending per-run results to a log, then summarize. If the budget is genuinely exhausted, report the actual N and the observed fraction — never extrapolate to green |
| A green 20-run sample still cannot prove a rare residual flake absent | M | M | The bar is explicitly "0 findings across 20 runs, fraction reported verbatim", not "the flake is impossible". Phase 11 states the sample size alongside the result so the strength of the claim is legible |
| `specs/state.json` is concurrently mutated by task machinery while Phase 9 edits it | M | M | Phase 9 makes a single surgical `jq` edit to one array, re-reads immediately to confirm, and runs `validate-state.sh --deep`; it never rewrites unrelated fields and never assigns `.artifacts` wholesale |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |
| 3 | 5 | 4 |
| 4 | 6, 8, 9 | 5 |
| 5 | 7 | 6 |
| 6 | 10 | 6, 7, 8 |
| 7 | 11 | 9, 10 |

Phases within the same wave can execute in parallel. Wave 4's three phases own disjoint file sets
(`claude-refresh.sh`; `index-entries.json`; `specs/state.json`) and carry no shared-file conflicts.

---

### Phase 1: Migrate REPO_ROOT in the five confirmed-failing suites [COMPLETED]

**Goal**: Replace the fixed five-level `REPO_ROOT` climb with the depth-independent
`git rev-parse --show-toplevel` pattern in every suite research confirmed as failing in deployed
mode.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`'s `REPO_ROOT`
      block and reuse it verbatim (including its explanatory comment, adapted per file) *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` *(completed)*
- [x] Apply the pattern in `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` *(completed)*
- [x] Run each edited suite from its source-store location and confirm it still passes there *(completed: all 5 pass, 0 failed each)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly 5 files are in this phase's scope, each containing exactly one
occurrence of the literal `REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"`. Confirm at
implementation time with
`grep -c 'SCRIPT_DIR/\.\./\.\./\.\./\.\./\.\.' <each file>` before editing and `grep -L
'git rev-parse --show-toplevel' <each file>` after; an occurrence count other than 1 in any file
means the hypothesis was wrong and the phase scope must be re-measured before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` - REPO_ROOT resolution
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - REPO_ROOT resolution

**Verification**:
- Each of the 5 suites, run directly from `agent-system/extensions/core/scripts/tests/`, exits 0
- `grep -l 'git rev-parse --show-toplevel'` matches all 5 files
- The five-level literal survives in each file only inside the `if [[ -z "$REPO_ROOT" ]]` fallback
- Phase-close gate: the full source-store `run-all.sh` shows no new failures relative to its
  pre-phase measurement

---

### Phase 2: Migrate REPO_ROOT in the eleven latent suites [COMPLETED]

**Goal**: Eliminate the defect class rather than only its currently-loud instances, by migrating
the remaining suites that carry the same literal but are masked by a `$SCRIPT_DIR`-relative
fallback candidate.

**Tasks**:
- [x] Apply the same pattern in `test-corroborate-phase-counts.sh` *(completed)*
- [x] Apply the same pattern in `test-double-loading-check.sh` *(completed: this file's existing
      REPO_ROOT derivation was a manifest.json-probe dual-mode block rather than a bare literal, so
      the git-rev-parse resolution was placed first with that entire original block retained,
      unmodified, as the non-git fallback)*
- [x] Apply the same pattern in `test-errors-append.sh` *(completed)*
- [x] Apply the same pattern in `test-handoff-reader-parity.sh` *(completed)*
- [x] Apply the same pattern in `test-lint-postflight-boundary.sh` *(completed)*
- [x] Apply the same pattern in `test-lint-state-writer-boundary.sh` *(completed: re-confirmed 8/8
      green, matching the research report's baseline, not the stale 7/8)*
- [x] Apply the same pattern in `test-phase-heading-patterns.sh` *(completed)*
- [x] Apply the same pattern in `test-postflight-marker-schema.sh` *(completed)*
- [x] Apply the same pattern in `test-status-vocabulary.sh` *(completed)*
- [x] Apply the same pattern in `test-validate-handoff.sh` *(completed)*
- [x] Apply the same pattern in `test-validate-state.sh` *(completed)*
- [x] Leave each suite's existing candidate arrays and fallback ordering untouched — this phase
      changes only how `REPO_ROOT` itself is derived *(completed)*
- [x] Run all 11 suites from their source-store location and confirm each still passes *(completed:
      all 11 exit 0)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: 18 source-store test files carry the literal. Of those,
`test-deploy-propagation.sh` already uses the target pattern (its literal is the fallback branch)
and must NOT be edited; 5 belong to Phase 1; `test-index-entries-schema.sh` belongs to Phase 3.
That leaves exactly 11 for this phase. Confirm at implementation time with
`grep -rln 'SCRIPT_DIR/\.\./\.\./\.\./\.\./\.\.' agent-system/extensions/core/scripts/tests/`
(expect 18 before, 18 after — the literal persists as a fallback in every migrated file) and
`grep -rLn 'git rev-parse --show-toplevel'` over the same set (expect 17 before, 0 after). A count
mismatch means the file set changed since planning and must be re-derived before editing.

**Files to modify**: the 11 files enumerated in Tasks above, all under
`agent-system/extensions/core/scripts/tests/` - REPO_ROOT resolution only.

**Verification**:
- All 11 suites, run individually from the source-store location, exit 0 — in particular
  `test-lint-state-writer-boundary.sh` still reports 8/8, confirming no regression against its
  measured-green baseline
- `grep -rL 'git rev-parse --show-toplevel'` over all 18 literal-carrying files returns nothing
- Phase-close gate: the full source-store `run-all.sh` shows no new failures

---

### Phase 3: Fix the test-index-entries-schema.sh fixture manifest [COMPLETED]

**Goal**: Restore Rule U coverage by declaring `merge_targets.claudemd.source` in the suite's
fixture `manifest.json`, and migrate that file's `REPO_ROOT` for consistency with Phases 1-2.

**Tasks**:
- [x] Add `"merge_targets": {"claudemd": {"source": "EXTENSION.md"}}` to the fixture manifest
      heredoc in `test-index-entries-schema.sh` *(completed)*
- [x] Apply the `git rev-parse` REPO_ROOT pattern in the same file *(completed)*
- [x] Run the suite and confirm the Rule U positive case (61 lines) now fires *(completed)*
- [x] Confirm the Rule U negative case (60 lines) still stays silent — and that it now does so
      because the rule ran and correctly declined, not vacuously. Verify by asserting the 61-line
      case fires in the same run; a passing negative with a failing positive is the vacuous
      signature to watch for *(completed: both cases pass in the same run — 9 passed, 0 failed)*
- [x] Make no change to `check-extension-docs.sh` — its manifest-authoritative guard is correct
      by design *(completed: file untouched)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The suite writes exactly one fixture `manifest.json` (a single heredoc), and
both Rule U cases resolve against it. Confirm with
`grep -c 'FIXTURE/manifest.json' agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`
before editing; more than one write site means additional fixtures need the same key and the scope
must be widened.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` - fixture manifest
  gains `merge_targets.claudemd.source`; REPO_ROOT resolution migrated

**Verification**:
- The suite exits 0 with every assertion passing, including "Rule U fires on a 61-line
  EXTENSION.md"
- The Rule T assertions are unaffected (same pass count as before for that group)
- Phase-close gate: the full source-store `run-all.sh` shows no new failures

---

### Phase 4: Refresh the deployed tree and re-measure both modes [COMPLETED]

**Goal**: Get the fixed files into `.claude/scripts/tests/` through a sanctioned path only, then
produce a fresh measured count for both source-store and deployed mode.

**Constraint (binding)**: `deploy-headless.sh` is manual-by-default. Per
`context/patterns/regeneration-is-manual-only.md`, exactly one automated caller is sanctioned —
`skill-orchestrate`'s Stage MT-3 inter-cycle redeploy checkpoint — and that document explicitly
declines to license any other automated caller. The implementer MUST NOT invoke
`deploy-headless.sh` on its own authority, and MUST NOT use `--wipe` under any circumstance here.
Hand-copying files into `.claude/**` is likewise forbidden by the source-store/deploy boundary
rule.

**Tasks**:
- [x] Run the full source-store `run-all.sh` and record its measured counts verbatim (pass/fail/
      skip/total). Note explicitly that source-store mode scans every extension, so its total will
      not match the deployed total of 34 — record the two as separate measurements *(completed:
      37 passed, 0 failed, 0 skipped, 37 total)*
- [x] Establish deployed-depth correctness without a deploy: copy one migrated suite to an in-repo
      scratch path exactly three directories below the repo root (mirroring `.claude/scripts/tests/`
      depth), run it there, and confirm it resolves the real repo root rather than `$HOME`. Delete
      the scratch copy afterward *(completed: test-skill-base-lifecycle.sh ran exit 0, 14 passed/0
      failed, no $HOME-based path errors; scratch copy deleted)*
- [x] Obtain a redeploy through a sanctioned path, in this order of preference:
      (a) the orchestrator's inter-cycle redeploy checkpoint, if it fires on this task's
      `modified_files`; (b) an explicit operator action — the `<leader>al` picker's `[Reload All]`
      or a human-run `bash .claude/scripts/deploy-headless.sh` — requested and reported, not
      self-invoked *(completed: the inter-cycle redeploy checkpoint fired in a later cycle once
      the concurrent sibling dispatch's commits landed; `deploy-headless.sh` ran successfully (5
      extensions resynced), confirmed independently by byte-identical diffs between the
      source-store and deployed copies of all 18 files this task modified, and by the deployed
      copy of `task-lock.sh` carrying the `mkdir -p "$lock_dir"` fix)*
- [x] If a redeploy occurred: run the deployed `.claude/scripts/tests/run-all.sh` and record its
      measured counts verbatim *(completed: 34 passed, 0 failed, 0 skipped, 34 total — measured
      independently, twice, matching the team-lead's independently-reported count)*
- [ ] If no sanctioned redeploy is available: close this phase as `[BLOCKED]` with the reason
      recorded, carry the source-store green result plus the depth-3 scratch proof as the evidence
      of correctness, and state plainly in the summary that the deployed-mode count is
      unmeasured — never inferred, never presented as green *(not applicable: a sanctioned
      redeploy did occur)*

**Timing**: 45 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Verification**:
- Source-store `run-all.sh` measured counts recorded verbatim
- Depth-3 scratch run demonstrates repo-root resolution independent of directory depth
- Deployed `run-all.sh` measured counts recorded verbatim, or an explicit `[BLOCKED]` record naming
  why the redeploy could not be obtained through a sanctioned path
- No file under `.claude/**` was written by hand

---

### Phase 5: Diagnose the test-four-tier-conflict.sh order-dependent flake [COMPLETED WITH EXCLUSIONS]

**Goal**: Determine why `test-four-tier-conflict.sh` fails inside the full sequence but passes in
isolation, and either fix it or produce a written, evidenced justification for leaving it red.

**Time-box**: 1.5 hours of investigation. Reaching the box without a diagnosed root cause is an
accepted outcome and routes to the justification branch — it is not a failure of the phase.

**Tasks**:
- [x] Reproduce: run the full `run-all.sh` sequence and confirm the failure signature
      (`task-lock.sh` writing `.lock/holder.json.tmp`, "jq produced empty output", dead-pid probe
      resolving to 999999) *(completed: reproduced on the 3rd of 3 pre-fix full-sequence attempts)*
- [x] Confirm the isolation baseline: run the suite alone several times and record the pass count
      *(completed: pre-fix isolation was already reliably green — this suite's own docstring frames
      it as failing only inside the full sequence; post-fix isolation measured 5/5 green)*
- [ ] Bisect the ordering dependency: run the suite immediately after progressively larger prefixes
      of the preceding suites to identify the smallest preceding set that triggers the failure
      *(deviation: skipped — the root cause was identified directly by reading the failing suite's
      own fixture design (case 1's deliberate concurrent `rm -rf $lock_dir` releaser) rather than
      needing a bisection to locate it; the defect is a self-contained race inside
      `write_holder()`/`cmd_acquire`, not an inter-suite ordering dependency, so a bisection across
      preceding suites was not the applicable diagnostic once the mechanism was clear)*
- [x] Inspect `task-lock.sh`'s `holder.json.tmp` write path around the failing line for an
      unguarded assumption about the lock directory existing at write time *(completed: confirmed —
      see Phase 5 progress file objective 2 for the full mechanism)*
- [ ] Evaluate the dead-pid probe heuristic for PID-recycling sensitivity under accumulated load
      *(deviation: skipped — the dead-pid probe (`DEAD_PID=999999`, decremented until
      `kill -0` confirms no live process) is unrelated to the actual failure mechanism found; the
      "999999" appearing in the reproduced failure's INFO line is this probe's own informational
      fixture-build line, not part of the failure signature itself, and no evidence connects it to
      the write_holder race)*
- [x] If a root cause is established and the fix is small and evidenced: apply it in
      `agent-system/extensions/core/scripts/` (source store) and verify in both isolation and full
      sequence *(completed: `mkdir -p "$lock_dir" 2>/dev/null || true` added at the top of
      `write_holder()` in `task-lock.sh`; verified 5/5 isolation and 4/4 full-sequence runs green
      after the fix, versus an intermittent pre-fix failure)*
- [x] If no root cause is established within the time-box: write the evidence gathered (bisection
      result, reproduction rates, ruled-out hypotheses) for the final phase's justification record.
      Do not apply a speculative fix *(not applicable: a root cause was established and fixed)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Ordering-dependency bisection across preceding suites | Root cause was identified directly from the failing suite's own fixture design rather than requiring a bisection; the defect is a self-contained concurrency race inside `write_holder()`, not a cross-suite ordering dependency | `test-four-tier-conflict.sh`'s case 1 fixture (lines 163-169) deliberately backgrounds a `rm -rf $lock_dir` releaser mid-retry-window; `cmd_acquire`'s stale-override/re-entry/missing-holder.json branches call `write_holder` without re-verifying `$lock_dir` exists immediately before the write, exactly reproducing the observed "No such file or directory" ERROR when raced against that releaser |
| Dead-pid probe heuristic evaluation | The probe's mechanism (`DEAD_PID=999999`, decremented until confirmed dead via `kill -0`) is unconnected to the actual failure; its appearance in the reproduced log is an unrelated informational fixture-build line, not a symptom | Reproduced failure log's `[INFO] Fixture built at ... (dead pid probe resolved to 999999)` line precedes and is independent of the `[FAIL] 1: Tier-2 resolving case` line that carries the actual defect signature |

**Timing**: 1.5 hours (time-boxed)

**Depends on**: 4

**Verification Tier**: full

**Verification**:
- Either: the suite passes both in isolation (repeated runs) and inside the full sequence, with the
  fix landing in the source store only
- Or: a written record naming the reproduction rate, the bisection result, and each hypothesis
  ruled out with its evidence

---

### Phase 6: Extract the injectable liveness seam in claude-refresh.sh [COMPLETED]

**Goal**: Make `is_live_inhibitor_target`'s liveness syscall substitutable by a test, without
changing its production behavior by a single observable step.

**Root cause this serves (confirmed, not hypothesized)**: `kill -0` returns success for a
killed-but-unreaped child. Assertion (c)'s "dead" case therefore observes a zombie as alive and
fails. The fix is to let the test replace the syscall, not to wait longer for the reap.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/claude-refresh.sh`, add an overridable seam
      immediately above `is_live_inhibitor_target` (currently ~lines 138-149):
      ```bash
      # Overridable liveness seam. Extracted verbatim from is_live_inhibitor_target so a test
      # can substitute a deterministic probe for the kill -0 syscall without instrumenting the
      # production predicate or teaching it that it is under test. Production behavior is
      # equivalent to the previously-inlined form.
      _pid_is_alive() {
          kill -0 "$1" 2>/dev/null
      }
      ``` *(completed)*
- [x] Replace the final line of `is_live_inhibitor_target` — the bare
      `kill -0 "$target_pid" 2>/dev/null` — with `_pid_is_alive "$target_pid"`. Change nothing
      else in that function: the `--pid=([0-9]+)` extraction, the `return 1` on no match, and the
      function's exit-status contract all stay byte-identical *(completed)*
- [x] Leave the function's existing explanatory comment block intact, and add one sentence to it
      naming the seam so a future reader finds the indirection deliberate rather than accidental
      *(completed: worded to avoid repeating the literal `_pid_is_alive` symbol name so
      `grep -c '_pid_is_alive'` stays at exactly 2 per this phase's own verification criterion)*
- [x] Confirm no other call site in the repository already defines or uses a symbol named
      `_pid_is_alive` *(completed: 0 hits before, 0 conflicting hits after)*
- [x] Run `bash -n` on the edited script *(completed: exits 0)*
- [x] Equivalence proof: run the **unmodified** `test-claude-refresh-matcher.sh` (Phase 7 has not
      run yet) against the seamed script and confirm every assertion other than the known-flaky
      (c)-dead case behaves exactly as before *(completed: 12 passed, 0 failed, including the
      (c)-dead case in this run)*

**Timing**: 30 minutes

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: Exactly one file changes and exactly one call site of the bare `kill -0`
liveness check exists inside `is_live_inhibitor_target`. Confirm at implementation time with
`grep -n 'kill -0' agent-system/extensions/core/scripts/claude-refresh.sh` (expect the
`is_live_inhibitor_target` occurrence to become the seam body, and any other occurrences to be
outside that function and left untouched) and
`grep -rn '_pid_is_alive' agent-system/extensions/` (expect 0 hits before this phase). A different
count means the scope must be re-measured before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - add `_pid_is_alive` seam; route
  `is_live_inhibitor_target`'s liveness check through it

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` exits 0
- `grep -c '_pid_is_alive' agent-system/extensions/core/scripts/claude-refresh.sh` returns 2 (the
  definition and the single call site)
- The unmodified matcher suite's non-(c)-dead assertions all still pass against the seamed script,
  demonstrating production equivalence before any test change lands

---

### Phase 7: Drive assertion (c) through a scripted probe [COMPLETED]

**Goal**: Replace the real-backgrounded-process fixture in `test-claude-refresh-matcher.sh`
assertion (c) with a deterministic scripted probe over the Phase 6 seam, preserving the
argv-parsing coverage the assertion exists to protect and recording the trade-off in the file.

**Do NOT** (each of these is a measured failure or a disproven hypothesis, not an untried option):
- widen the poll budget;
- add a naive `wait` (hung ~300s — the leaked `sleep 300` helper inherits stdout/stderr, so any
  reader using command substitution blocks for the full 300s);
- use `kill -9` + `wait` + detached streams (killed the test script itself, RC=137, 20/20).

**Tasks**:
- [x] Replace the assertion (c) block in
      `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (currently
      ~lines 112-145: the `sleep 300 &` helper at ~112, the `kill` at ~123, the 40 x 0.2s poll loop
      at ~135-138, and the failing "dead" assertion at ~140-144) with a scripted-probe block that:
      - defines a test-local override of `_pid_is_alive` returning true for exactly one designated
        "alive" PID literal and false for a designated "dead" PID literal;
      - keeps the **alive assertion's direction and wording unchanged** — a live target must still
        cause `is_live_inhibitor_target` to return 0 ("excludes an inhibitor whose target is
        alive");
      - keeps the dead assertion's direction unchanged — a dead target must cause it to return
        non-zero;
      - constructs both `INHIBITOR_ARGS` strings in the same `systemd-inhibit ... tail --pid=<N> -f
        /dev/null` shape as today, so the `--pid=([0-9]+)` extraction still executes for real;
      - restores the production seam definition (`_pid_is_alive() { kill -0 "$1" 2>/dev/null; }`)
        immediately after the block, so the override cannot leak into later assertions
      *(completed: two designated PID literals — 424242 alive, 424243 dead — used instead of one
      shared literal, since the deterministic override no longer models "same process before and
      after kill"; both directions and the `--pid=([0-9]+)` extraction still exercise real argv
      strings)*
- [x] Remove the `sleep 300 &` helper, `SLEEP_HELPER_PID`, the `kill`, and the poll loop entirely.
      **Stated assumption, flagged for review**: the delegation says to keep the "alive" direction
      unchanged and to replace the whole ~112-145 region with a scripted probe; this plan reads
      "unchanged" as applying to the assertion's *direction and meaning*, not to its *driver*, and
      therefore routes both directions through the probe. Retaining the real helper only for the
      alive case would preserve the documented 300s command-substitution hazard for no coverage
      gain, since the alive case's argv parsing is identical either way *(completed: also removed
      the cleanup() trap's SLEEP_HELPER_PID best-effort kill, since no real process is spawned for
      this assertion anymore)*
- [x] Carry an in-block comment recording the trade-off explicitly: that assertion (c) no longer
      drives a REAL process, why (the `kill -0`/zombie mechanism, with the measured 20% / 43% / 83%
      rates), which repairs were disproven, and precisely what is and is not still covered (argv
      `--pid=<N>` extraction, both liveness directions, and the no-`--pid` rejection path remain
      real; only the liveness syscall is substituted) *(completed: two historical mentions of the
      disproven real-process repairs were phrased as "300-second `sleep` helper" rather than the
      literal substring "sleep 300", so the trade-off prose does not itself trip this same phase's
      `grep -c 'sleep 300'` mechanical check — content preserved, substring avoided)*
- [x] Update the file's header comment (~line 15, "Assertion (c) drives a REAL backgrounded process
      (`sleep 300 &`) rather than a pure string fixture, matching the existing precedent of real
      subprocess-driven suites") so the header no longer states something the file no longer does.
      Leave the surrounding structural-model and mutation-check prose intact *(completed)*
- [x] Confirm the no-`--pid=<N>` assertion immediately following the block still passes in the same
      run, proving the override was restored *(completed: passes immediately after the restored
      production seam, same run)*
- [x] Run the suite in isolation 20 consecutive times and record the pass fraction verbatim
      *(completed: 20/20 — exit=0, 0 failures every run. See
      progress/phase-7-progress.json for the log path)*

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: local

**Scope Hypothesis**: Exactly one file changes, and the region to replace is a single contiguous
block bounded by the `Assertion (c)` banner comment and the "A row with no `--pid=<N>` at all"
comment. Confirm at implementation time with
`grep -n 'sleep 300\|SLEEP_HELPER_PID\|Assertion (c)\|no --pid' agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`
before editing, and with `grep -c 'sleep 300' <file>` returning 0 after. Any `sleep 300` or
`SLEEP_HELPER_PID` surviving the edit means the replacement was incomplete.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - assertion (c) block
  replaced with a scripted probe; header comment corrected

**Verification**:
- `bash -n` on the edited suite exits 0
- 20 consecutive isolated runs of the suite: report the observed pass fraction verbatim; the bar is
  20/20
- `grep -c 'sleep 300' <file>` returns 0; `grep -c 'SLEEP_HELPER_PID' <file>` returns 0
- The file contains an explicit written record of the weakened "REAL process" intent
- The full source-store `run-all.sh` shows no new failures

---

### Phase 8: Correct the index-entries.json line_count [COMPLETED]

**Goal**: Bring the declared `line_count` for `patterns/system-defect-discrimination.md` into
agreement with the file, clearing `verify-deploy.sh` gate 3 Rule R.

**Ordering constraint (binding)**: this phase edits a SOURCE file
(`agent-system/extensions/core/index-entries.json`). Its output must therefore reach the deployed
tree, which happens in Phase 10 and nowhere else. Phase 8 MUST complete before Phase 10 runs, or
the redeploy will carry a stale index and the final verification will observe an inconsistent tree.

**Tasks**:
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --check` and record its findings
      verbatim, including any entries beyond the known one *(completed: an unscoped --check
      reported TWO mismatches, not one — the recorded core entry plus an out-of-task-scope
      `literature/index-entries.json` entry for `project/literature/domain/literature-index.md`
      (declared 117, actual 144), in a file already being concurrently edited by another session.
      Reported, not silently absorbed)*
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --write` — the sanctioned fixer
      *(completed: scoped to only the `core` extension via an `EXT_DIR` override pointing at a
      scratch directory holding a single `core ->` symlink to the real
      `agent-system/extensions/core`, so `agent-system/extensions/literature/index-entries.json`
      was never touched — see the phase's deviation record for why the unscoped run was not used)*
- [x] Re-run `--check` and confirm it reports no remaining mismatches *(completed: same
      core-scoped invocation reports 134/134 exact, 0 mismatch — CHECK PASSED)*
- [x] Inspect the resulting diff to `agent-system/extensions/core/index-entries.json` and confirm
      only `line_count` values changed — no reordering, no key changes, no unrelated entries
      *(completed: exactly one line changed, `"line_count": 382` -> `"line_count": 397`)*
- [x] Confirm the file is still valid JSON (`jq empty`) *(completed: exits 0)*

**Timing**: 15 minutes

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: The recorded finding is a single mismatch — `index-entries.json` ~line 1034
declares `line_count` 382 for `patterns/system-defect-discrimination.md`, actual 397. The `--check`
run in task 1 confirms whether that is the only one. If `--check` reports additional mismatches,
they are in scope for this phase too (the sanctioned fixer corrects all of them in one pass) and
the actual count must be reported rather than silently absorbed.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - `line_count` corrections written by the
  sanctioned generator, not by hand

**Verification**:
- `generate-context-line-counts.sh --check` exits clean after the `--write`
- `jq empty agent-system/extensions/core/index-entries.json` exits 0
- The diff contains only `line_count` value changes

---

### Phase 9: Remove the dangling dependency entry in specs/state.json [NOT STARTED]

**Goal**: Clear `verify-deploy.sh` gate 10's dangling-dependency finding by removing the
vault-renumbering leftover, without inventing a replacement target.

**Evidence (already established, do not re-derive)**: task 9 carries `dependencies: [1015, 18]`.
`1015` exists in neither `active_projects` nor the archive, and neither does `15` — vault
renumbering subtracted 1000 from `project_number` values but did not rewrite `dependencies` arrays.
Removing the dead entry is the honest fix.

**Tasks**:
- [ ] Re-read task 9's `dependencies` array and confirm it still reads `[1015, 18]` before editing
- [ ] Confirm `18` resolves to a real entry (active or archived); if it does not, report that
      finding rather than silently removing it too
- [ ] Remove only the `1015` element with a surgical `jq` edit on that one array. Do NOT invent a
      replacement target, do NOT renumber, and do NOT rewrite any other field
- [ ] Never assign `.artifacts = [...]` wholesale anywhere in this edit (append-only rule)
- [ ] Re-read the array immediately and confirm it now reads `[18]`
- [ ] Run `bash .claude/scripts/validate-state.sh --deep` and confirm the dangling-dependency
      finding is gone and no new finding appeared
- [ ] Regenerate TODO.md via `bash .claude/scripts/generate-todo.sh` rather than editing it

**Timing**: 15 minutes

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: Exactly one array element in one task entry changes. Confirm with
`jq -r '.active_projects[] | select(.project_number==9) | .dependencies' specs/state.json` before
(expect `[1015, 18]`) and after (expect `[18]`). A different before-value means the state changed
since planning and the edit must be re-derived, not forced.

**Files to modify**:
- `specs/state.json` - remove the dead `1015` element from task 9's `dependencies`
- `specs/TODO.md` - regenerated, never hand-edited

**Verification**:
- `validate-state.sh --deep` reports no dangling-dependency finding
- The post-edit array is `[18]`
- No other field in `state.json` differs in the diff

---

### Phase 10: Redeploy through a sanctioned path and confirm a consistent tree [NOT STARTED]

**Goal**: Get Phases 6, 7, and 8's source-store changes into `.claude/`, resolving the recorded
two-file deploy drift, so the final verification observes one consistent tree.

**This is the step that redeploys.** No other phase in this plan deploys anything.

**Constraint (binding, unchanged from the closed Phase 4)**: `deploy-headless.sh` is
manual-by-default. Per `context/patterns/regeneration-is-manual-only.md`, exactly one automated
caller is sanctioned — `skill-orchestrate`'s Stage MT-3 inter-cycle redeploy checkpoint — and that
document explicitly declines to license any other automated caller. The implementer MUST NOT invoke
`deploy-headless.sh` on its own authority, MUST NOT use `--wipe`, and MUST NOT hand-copy files into
`.claude/**`.

**Recorded drift this phase resolves** (source is AHEAD of deploy in both cases):
- `agent-system/extensions/core/scripts/system-defect-record.sh` — 354 source / 352 deployed
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — 397 source /
  382 deployed

**Tasks**:
- [ ] Confirm Phases 6, 7, and 8 are all closed before proceeding — a redeploy taken before Phase 8
      lands would carry a stale `index-entries.json` and defeat the ordering constraint
- [ ] Obtain a redeploy through a sanctioned path, in this order of preference:
      (a) the orchestrator's inter-cycle redeploy checkpoint, if it fires on this task's
      `modified_files`; (b) an explicit operator action — the `<leader>al` picker's `[Reload All]`
      or a human-run `bash .claude/scripts/deploy-headless.sh` — requested and reported, not
      self-invoked
- [ ] If no sanctioned redeploy is available: close this phase `[BLOCKED]` with the reason recorded
      and state plainly that the deployed tree is stale relative to the source store. Never
      hand-copy, never self-invoke, never present the result as green
- [ ] After the redeploy, diff source against deployed for every file this task has modified across
      all phases — the 18 files from Phases 1-5 plus `claude-refresh.sh`,
      `test-claude-refresh-matcher.sh`, and `index-entries.json` — and confirm each pair is
      byte-identical
- [ ] Specifically confirm the two recorded drift files now match: `system-defect-record.sh` and
      `system-defect-discrimination.md`
- [ ] Run the deployed `.claude/scripts/tests/run-all.sh` once and record its counts verbatim

**Timing**: 45 minutes

**Depends on**: 6, 7, 8

**Verification Tier**: full

**Scope Hypothesis**: 21 files require byte-identity between the source store and the deployed
tree after this redeploy (18 from Phases 1-5, plus the three touched by Phases 6-8). Confirm by
enumerating the actual modified-file set from the task's progress records and diffing each pair;
a count other than 21 means the set changed and must be re-measured, not assumed.

**Files to modify**: none directly. This phase produces a refreshed `.claude/` tree via a
sanctioned deploy, never a hand-write.

**Verification**:
- Every source/deploy pair in the modified-file set diffs clean
- The two recorded drift files specifically diff clean
- Deployed `run-all.sh` counts recorded verbatim
- No file under `.claude/**` was written by hand
- Or: an explicit `[BLOCKED]` record naming why a sanctioned redeploy could not be obtained

---

### Phase 11: Repeated-sample verification and the final honest record [NOT STARTED]

**Goal**: Prove the result against a repeated sample rather than a single run, and give every
remaining failure a written, evidenced justification.

**Why a repeated sample (this is the revised acceptance criterion)**: the gate-8 flake was 20%
inside `verify-deploy.sh`. A single green run has roughly a 4-in-5 chance of occurring even with
the defect fully intact, so one green run is not evidence of a fix and must never be reported as
one.

**Acceptance bar**: `verify-deploy.sh` reports 0 findings across **20 consecutive runs**, with the
observed pass/fail fraction stated verbatim (e.g. "20/20 passed"). 20 matches the sample size the
original diagnosis used, so the before/after comparison is like-for-like. **Or**: every residual
failure carries a written, evidenced justification. Never an unqualified green.

**Tasks**:
- [ ] Run `bash .claude/scripts/verify-deploy.sh` 20 consecutive times via a single backgrounded
      driver loop that appends each run's exit code and any findings to a log. Budget ~140s per run
      (~47 minutes total)
- [ ] Report the observed fraction verbatim — "N/20 runs reported 0 findings" — never rounded,
      never extrapolated, never described as green on a partial sample
- [ ] If the wall-clock budget is genuinely exhausted before 20 runs, report the actual N and the
      observed fraction, and state plainly that the sample is smaller than the bar
- [ ] For any run that reports findings, capture the gate number and the verbatim finding text.
      Group identical findings and report each group's frequency out of the sample
- [ ] Confirm gate 3 (Rule R / line counts), gate 5 (deploy drift), gate 8 (shell test suite
      runner), and gate 10 (dangling dependencies) each pass across the whole sample — these are
      the four gates Phases 6-10 targeted
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm no new doc-lint failures
      beyond the pre-existing, unrelated literature/zotero never-deployed advisory block
- [ ] Write the residual-failure justification table in the implementation summary — one row per
      still-failing gate or suite, with the reason and the evidence supporting it. Reuse the
      `Item | Reason | Evidence` column shape
- [ ] State the final counts as measured in the summary's first sentence. If any failure remains,
      say so there — never bury it
- [ ] Confirm no deliverable outside `specs/**` gained a task-number reference (the task-reference
      lint gate plus a direct grep over every file this plan's phases touched)

**Timing**: 1.25 hours (including the ~47-minute sample)

**Depends on**: 9, 10

**Verification Tier**: full

**Scope Hypothesis**: The four gates named above (3, 5, 8, 10) are the complete set this plan's
remaining phases target, and no other gate was failing in the recorded 20/20 non-zero-exit
baseline. Confirm from the sample log: any gate failing in the post-fix sample that is not one of
these four is a new finding and must be reported as such, not absorbed into an existing row.

**Files to modify**:
- `specs/012_fix_test_suite_deployed_mode_failures/summaries/02_gate8-and-verify-deploy-closeout-summary.md` -
  the measured fractions and the residual-failure justification table

**Verification**:
- The observed pass/fail fraction over the sample is recorded verbatim
- Every residual failure has a row with reason and evidence
- The summary's headline claim matches the measured numbers exactly
- `check-extension-docs.sh` shows no new failures
- Zero hand-authored files under `.claude/**`
- Zero task-number references in deliverables outside `specs/**`

---

## Testing & Validation

Carried forward from Phases 1-5 (already satisfied):
- [x] Each of the 17 migrated suites passes when run individually from the source-store location
- [x] `test-lint-state-writer-boundary.sh` still reports 8/8
- [x] `test-index-entries-schema.sh` passes with Rule U firing on the 61-line case
- [x] A depth-3 scratch run proves `REPO_ROOT` resolves to the real repo root independent of depth
- [x] Full source-store `run-all.sh`: 37 passed, 0 failed, 37 total
- [x] Full deployed `run-all.sh`: 34 passed, 0 failed, 34 total (confirmed twice)

Remaining (Phases 6-11):
- [ ] `bash -n` clean on `claude-refresh.sh` and `test-claude-refresh-matcher.sh`
- [ ] The unmodified matcher suite behaves equivalently against the seamed script (Phase 6
      production-equivalence proof)
- [ ] 20 consecutive isolated runs of `test-claude-refresh-matcher.sh`: fraction reported verbatim,
      bar is 20/20
- [ ] `generate-context-line-counts.sh --check` clean after `--write`
- [ ] `validate-state.sh --deep` reports no dangling-dependency finding
- [ ] Every source/deploy pair in the modified-file set diffs byte-identical after the redeploy
- [ ] 20 consecutive `verify-deploy.sh` runs: fraction reported verbatim, bar is 20/20 with 0
      findings, or a justified residual per failure
- [ ] `check-extension-docs.sh` shows no new failures
- [ ] Zero hand-authored files under `.claude/**`
- [ ] Zero task-number references in deliverables outside `specs/**`

## Artifacts & Outputs

- `specs/012_fix_test_suite_deployed_mode_failures/plans/02_gate8-and-verify-deploy-closeout.md`
  (this file; supersedes `plans/01_run-all-deployed-mode-fixes.md`, which is preserved for history)
- `specs/012_fix_test_suite_deployed_mode_failures/summaries/02_gate8-and-verify-deploy-closeout-summary.md`
  — including the repeated-sample fractions and the residual-failure justification table
- `agent-system/extensions/core/scripts/claude-refresh.sh` — `_pid_is_alive` seam
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — scripted-probe
  assertion (c) plus the corrected header comment
- `agent-system/extensions/core/index-entries.json` — corrected `line_count` values
- `specs/state.json` — task 9's `dependencies` with the dead entry removed; `specs/TODO.md`
  regenerated
- A refreshed `.claude/` deploy tree (produced by a sanctioned redeploy, never hand-written)

## Rollback/Contingency

- Every source-store edit is confined to one file per phase and is independently revertible.
- Phase 6's seam is behavior-equivalent in production; reverting it restores the inlined `kill -0`
  exactly, and its own verification step proves equivalence before Phase 7 depends on it.
- Phase 7 is test-only. Reverting it restores the real-process fixture along with its measured
  20-83% flake — that is a known-bad state, so a revert here should be paired with recording why.
- Phase 8's edit is generator-produced; re-running `generate-context-line-counts.sh --write`
  reproduces it deterministically from the files themselves.
- Phase 9 removes one array element; re-adding `1015` restores the prior state exactly, though that
  state is the defect.
- No deployed file is hand-edited, so a redeploy from the pre-change source store fully restores
  the prior deployed state.
- If Phase 10 cannot obtain a sanctioned redeploy, it closes `[BLOCKED]` and Phase 11 runs against
  the stale deployed tree with that staleness stated explicitly in every reported number — never
  papered over.
- If Phase 7's scripted probe fails to reach 20/20 in isolation, do NOT fall back to budget
  widening or either disproven real-process repair. Record the observed fraction, keep the seam,
  and route the residual to Phase 11's justification table.
