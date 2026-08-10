# Implementation Plan: Task #1010

- **Task**: 1010 - Fix opencode gate-in session-id duplication (test-common-lib.sh deployed-mode failure)
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/1010_fix_opencode_gate_in_session_id_duplication/reports/01_opencode-gate-in-staleness.md
- **Artifacts**: plans/01_opencode-gate-in-catchup-sync.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; source-store-deploy-boundary.md; no-task-references-in-deliverables.md; git-workflow.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`.opencode/scripts/command-gate-in.sh` is a stale deploy snapshot carrying the old inline
`SESSION_ID="sess_$(date +%s)_..."` generator. Its single source-store equivalent,
`agent-system/extensions/core/scripts/command-gate-in.sh`, is **already correct** — it sources
`scripts/lib/common.sh` and calls `common_session_id()`. No source-store edit is required. The
fix is therefore a narrow, one-off catch-up redeploy of that one already-correct source file into
the stale `.opencode/` target, restoring the single-source-of-truth invariant that
`test-common-lib.sh` asserts. Definition of done: `test-common-lib.sh` passes in **both**
source-store and deployed test modes, executed and observed, with no new failures introduced in
either mode relative to a captured pre-change baseline.

### Research Integration

The research report's findings are load-bearing for this plan and are adopted as written:

- `.opencode/` is a **generated deploy target**, deployed by the same base_dir-parameterized Lua
  extension loader as `.claude/` (`config.claude()` vs `config.opencode()` in
  `lua/neotex/plugins/ai/shared/extensions/config.lua`). It shares the exact same source-store
  files. There is no separate opencode-flavored source tree to edit.
- The source-store file is already fixed; the defect is purely target staleness.
- `deploy-headless.sh` hardcodes `ext_config.claude()` and has no `.opencode` option, so a
  headless full resync of `.opencode/` is not currently reachable. This is precisely why a manual
  single-file catch-up is the appropriate remedy here rather than "just redeploy".
- The `test-common-lib.sh` source-store-pass/deployed-fail split is caused by where
  `SCRIPT_DIR/../../..` resolves (`agent-system/extensions/` vs the repo root), not by any
  environment-conditional test logic. **No change to the test is implicated or permitted.**

### Verified Pre-Change Baseline (measured during planning, 2026-08-10)

These are executed measurements, not estimates. The implementer MUST re-capture them (Phase 1)
rather than trusting these numbers, but they define the expected shape of the result:

| Mode | Command | Result | `test-common-lib.sh` |
|------|---------|--------|----------------------|
| Source-store | `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` | 36 passed, 1 failed, 37 total | PASS |
| Deployed | `bash .claude/scripts/tests/run-all.sh --quiet` | 27 passed, 7 failed, 34 total | **FAIL** |

Deployed-mode `[FAIL]` set at baseline (7 suites):

```
test-common-lib.sh              <- THE TARGET DEFECT (this task fixes only this one)
test-index-entries-schema.sh    <- pre-existing, also fails in source-store mode
test-loop-guard-staleness.sh    <- pre-existing, deployed-mode path-resolution defect
test-reconcile-handoff-status.sh<- pre-existing, deployed-mode path-resolution defect
test-resume-scan-nonconformance.sh <- pre-existing, deployed-mode path-resolution defect
test-skill-base-lifecycle.sh    <- pre-existing, deployed-mode path-resolution defect
test-update-task-status.sh      <- pre-existing, deployed-mode path-resolution defect
```

The five path-resolution failures all resolve repo-relative paths to `/home/benjamin/...` instead
of the actual repo root `/home/benjamin/.config/nvim/...`. They are **out of scope** and MUST NOT
be chased. They are recorded here so the implementer can distinguish "pre-existing red" from
"red I just caused".

The direct defect confirmation, from the deployed-mode run:

```
[FAIL] single-source assertion: inline sess_$(date generation found outside lib/common.sh:
[INFO]   /home/benjamin/.config/nvim/.opencode/scripts/command-gate-in.sh
```

Exactly one offending file. `Passed: 23, Failed: 1` within that suite.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` and no `roadmap_flag` were provided in the delegation context, so no roadmap
consultation was performed and no roadmap phases are included. (`specs/ROADMAP.md` does exist in
this repository; it was deliberately not read, per the delegation contract.)

## Goals & Non-Goals

**Goals**:
- Make `.opencode/scripts/command-gate-in.sh` byte-identical to
  `agent-system/extensions/core/scripts/command-gate-in.sh`, eliminating the duplicate inline
  session-id generator.
- Restore the single-source-of-truth invariant so `test-common-lib.sh` passes in both
  source-store mode and deployed mode, **verified by executed test runs**.
- Introduce no new test failures in either mode, measured against a captured baseline.
- Document, at the point of the change, that this is a manual redeploy of an unmodified source
  file into a stale target — not new hand-authored divergence to be preserved — so a future real
  `.opencode/` resync is a clean no-op for this file.

**Non-Goals**:
- Fixing the other 38 scripts missing from `.opencode/scripts/`, or the entirely absent
  `.opencode/scripts/lib/` subdirectory. Out of scope; spawn candidate.
- Adding a headless `.opencode` deploy entrypoint to `deploy-headless.sh`. Out of scope; spawn
  candidate.
- Editing `agent-system/extensions/core/scripts/command-gate-in.sh`. It is already correct;
  touching it is a defect, not a fix.
- Editing `test-common-lib.sh` or its `SCRIPT_DIR/../../..` scan-root computation. The split
  behavior is intended design.
- Fixing the six pre-existing unrelated failures listed in the baseline above.
- Correcting the source file's `# Usage: source .claude/scripts/command-gate-in.sh` comment, which
  will land verbatim in the `.opencode/` copy. It is a pre-existing cosmetic inaccuracy in the
  shared source that already renders identically into `.claude/`'s correct copy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The write is mistaken for a prohibited hand-edit of a generated deploy artifact | M | M | Use `cp` from the source-store file so the content is provably a verbatim reproduction of what the deploy engine itself would emit; verify with `diff` returning zero output; state the rationale explicitly in the commit message and summary |
| Transcription drift if content is retyped rather than copied | H | L | Mandate `cp`, never `Write`/`Edit` with retyped content; gate on `diff` byte-identity, not eyeballing |
| Implementer chases the 6 pre-existing unrelated failures and stalls | M | M | Baseline is captured in Phase 1 before any edit; Phase 3 compares FAIL sets, not absolute green |
| `.opencode/` is git-tracked (unlike gitignored `.claude/`), so this change enters version control | L | H (certain) | Expected and correct — `.opencode/**` receives mechanical repo-wide edits in history. Commit it with the rationale in the message |
| Exec bit lost on the target file | M | L | Verify mode is `755` after the copy; `cp` over an existing file preserves the destination mode, but confirm explicitly |
| Copy introduces a task-number citation into a deliverable tree | M | L | `.opencode/**` is a lint-gated deliverable tree; run `check-task-references.sh` after the copy (currently PASS: 0 occurrences across all 4 trees) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential.

---

### Phase 1: Capture Pre-Change Test Baseline in Both Modes [NOT STARTED]

**Goal**: Establish, by execution, the exact set of failing suites in each mode *before* any file
is touched, so Phase 3 can prove that the only change is `test-common-lib.sh` going green.

**Tasks**:
- [ ] Run source-store mode: `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet`,
      capturing full output to a scratch file.
- [ ] Run deployed mode: `bash .claude/scripts/tests/run-all.sh --quiet`, capturing full output to
      a separate scratch file.
- [ ] Extract the `[FAIL] ` line set from each with `grep '^\[FAIL\] '` and record both sets and
      both `[run-all] N passed, M failed, ...` summary lines verbatim.
- [ ] Confirm `test-common-lib.sh` appears in the deployed FAIL set and NOT in the source-store
      FAIL set. If this does not reproduce, STOP and report — the defect premise no longer holds.
- [ ] Run `bash .claude/scripts/tests/test-common-lib.sh` alone and record the offending-file line
      it prints, confirming `.opencode/scripts/command-gate-in.sh` is the sole offender.

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the baseline is source-store `36 passed / 1 failed` and
deployed `27 passed / 7 failed` with the 7-suite FAIL set enumerated in the Overview. Confirm by
executing both `run-all.sh` invocations above and diffing the observed `[FAIL]` sets and summary
lines against those numbers. If the observed baseline differs (e.g. another task landed
concurrently), record the *observed* baseline as authoritative and proceed — the invariant Phase 3
checks is "deployed FAIL set loses exactly `test-common-lib.sh` and gains nothing", not the
absolute counts.

**Files to modify**:
- None. This phase is read-only measurement; it makes no file edits.

**Verification**:
- Two captured output files exist and are non-empty.
- Both `[run-all]` summary lines are recorded verbatim.
- `test-common-lib.sh` confirmed failing in deployed mode and passing in source-store mode.

---

### Phase 2: Catch-Up Sync of the Single Stale File [NOT STARTED]

**Goal**: Make `.opencode/scripts/command-gate-in.sh` byte-identical to its already-correct
source-store original, by verbatim copy.

**Tasks**:
- [ ] Confirm the source file is already correct before copying:
      `grep -n 'common_session_id' agent-system/extensions/core/scripts/command-gate-in.sh`
      must hit, and `grep -c 'sess_\$(date' agent-system/extensions/core/scripts/command-gate-in.sh`
      must be `0`. If either fails, STOP — the plan's premise (source already fixed) is wrong.
- [ ] Copy verbatim:
      `cp agent-system/extensions/core/scripts/command-gate-in.sh .opencode/scripts/command-gate-in.sh`
      Use `cp`, **not** the `Write` or `Edit` tool with retyped content — byte-identity must be
      guaranteed by the copy mechanism, not by careful transcription.
- [ ] Verify byte-identity:
      `diff .opencode/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh`
      must produce zero output and exit 0.
- [ ] Verify the exec bit survived: `ls -l .opencode/scripts/command-gate-in.sh` must show mode
      `-rwxr-xr-x`. Restore with `chmod 755` if not.
- [ ] Syntax-check the result: `bash -n .opencode/scripts/command-gate-in.sh` must exit 0.
- [ ] Confirm the defect pattern is gone from the target:
      `grep -c 'sess_\$(date' .opencode/scripts/command-gate-in.sh` must be `0`.
- [ ] Confirm the deliverable-tree lint stays clean:
      `bash .claude/scripts/check-task-references.sh` must report `PASS` with `0` occurrences for
      the `.opencode` tree.
- [ ] Confirm no other file was touched: `git status --short` must show exactly one modified path
      outside `specs/**`, namely `.opencode/scripts/command-gate-in.sh`.
- [ ] Commit with the rationale explicit in the body — that this is a manual redeploy of an
      unmodified source file into a stale generated target, performed because no headless
      `.opencode` deploy entrypoint exists, and that a future real resync is expected to be a
      no-op for this file. Stage only `.opencode/scripts/command-gate-in.sh` plus the task-scoped
      `specs/**` paths; never `git add -A` or `git commit -am`.

**Timing**: 0.3 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that **exactly one** file outside `specs/**` changes:
`.opencode/scripts/command-gate-in.sh` (73 lines before, 114 lines after, matching the source).
Confirm with `git status --short` and `git diff --stat` before staging; any second changed
deliverable path means something unintended happened and the phase must stop rather than commit.

**Files to modify**:
- `.opencode/scripts/command-gate-in.sh` — replaced wholesale with a byte-identical copy of
  `agent-system/extensions/core/scripts/command-gate-in.sh`. Gains: `lib/common.sh` sourcing block,
  `SESSION_ID="$(common_session_id)"` in place of the inline generator, the `revise` exemption from
  the terminal-status guard, and the task-lock acquire/register sequence.

**Verification**:
- `diff` against the source produces no output.
- `bash -n` exits 0; file mode is 755.
- `grep -c 'sess_\$(date'` on the target returns 0.
- `check-task-references.sh` reports PASS.
- `git status --short` shows exactly the one expected deliverable path.

---

### Phase 3: Full Verification Gate — Executed Tests in Both Modes [NOT STARTED]

**Goal**: Prove by execution — not by reasoning — that `test-common-lib.sh` now passes in both
source-store and deployed modes, and that nothing else regressed.

**Tasks**:
- [ ] Re-run source-store mode: `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet`,
      capture output.
- [ ] Re-run deployed mode: `bash .claude/scripts/tests/run-all.sh --quiet`, capture output.
- [ ] Run the target suite directly in **both** locations and record its own
      `Passed: N / Failed: M` tail line for each:
      - `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh`
      - `bash .claude/scripts/tests/test-common-lib.sh`
      Both MUST exit 0 with `Failed: 0`.
- [ ] Diff the post-change `[FAIL] ` sets against the Phase 1 baseline sets, per mode. Required
      outcome: the deployed FAIL set loses exactly `test-common-lib.sh` and gains nothing; the
      source-store FAIL set is unchanged.
- [ ] Paste the actual observed summary lines and the target suite's PASS lines into the
      implementation record. A reasoned claim that the tests "should now pass" does not satisfy
      this phase — observed output is required.
- [ ] Run the repo deploy verification gate `bash .claude/scripts/verify-deploy.sh` if it is
      available and runnable in this environment; if it fails for reasons traceable to the six
      pre-existing unrelated failures or to unrelated gates, record that explicitly rather than
      treating it as caused by this change.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the expected post-change results are source-store
`36 passed / 1 failed` (unchanged) and deployed `28 passed / 6 failed` (one suite moved from FAIL
to PASS). Confirm by executing both `run-all.sh` invocations and comparing the observed `[FAIL]`
sets to the Phase 1 baseline. If the deployed count does not move by exactly one in the expected
direction, the phase is NOT complete — investigate rather than reporting success.

**Files to modify**:
- None. This phase is verification only.

**Verification**:
- `test-common-lib.sh` exits 0 with `Failed: 0` when run from BOTH
  `agent-system/extensions/core/scripts/tests/` and `.claude/scripts/tests/`.
- Deployed `[FAIL]` set equals the baseline set minus `test-common-lib.sh`, with no additions.
- Source-store `[FAIL]` set is byte-identical to the baseline set.
- Observed command output is recorded, not paraphrased.

---

### Phase 4: Record Rationale and Spawn Candidates [NOT STARTED]

**Goal**: Leave a durable record of why a generated deploy target was written by hand, and surface
the two out-of-scope structural gaps as explicit spawn candidates rather than silent debt.

**Tasks**:
- [ ] In the implementation summary under `specs/1010_.../summaries/`, record: the defect, the
      one-file remedy, the verbatim-copy provenance, and the executed before/after test evidence
      from Phases 1 and 3.
- [ ] Record the rationale that this write is a manual redeploy of an unmodified source file, not
      a divergence to preserve, so a future full `.opencode/` resync should be a no-op for this
      file.
- [ ] Record the two spawn candidates carried forward from research (do not create the tasks here;
      surface them for the orchestrator):
      1. Add a headless (non-interactive) redeploy entrypoint for `.opencode/`, parallel to
         `deploy-headless.sh`'s `.claude/` support — it hardcodes `ext_config.claude()` even
         though `config.opencode()` already exists in
         `lua/neotex/plugins/ai/shared/extensions/config.lua`.
      2. Resync the full `.opencode/scripts/` tree — 38 of 68 top-level scripts are missing,
         including `task-lock.sh`, `verify-deploy.sh`, `state-write.sh`, and the entire
         `scripts/lib/` subdirectory, so other latent deployed-mode failures are likely.
- [ ] Note, as an observation only, that five of the six remaining deployed-mode failures share a
      single root cause (repo-root path resolution landing on `/home/benjamin` instead of the
      repo root) and may warrant their own task. Do not fix them here.
- [ ] Write the orchestrator handoff JSON with the executed verification evidence and the spawn
      candidates.

**Timing**: 0.2 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `specs/1010_fix_opencode_gate_in_session_id_duplication/summaries/01_*-summary.md` — new
- `specs/1010_fix_opencode_gate_in_session_id_duplication/.orchestrator-handoff.json` — updated

**Verification**:
- Summary exists, is non-empty, and contains the observed before/after test output (not a
  paraphrase).
- Both spawn candidates are stated with enough specificity to become tasks without re-research.
- Handoff JSON is valid JSON and names the plan and summary paths.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-common-lib.sh` exits 0, `Failed: 0`
- [ ] `bash .claude/scripts/tests/test-common-lib.sh` exits 0, `Failed: 0`
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` — `[FAIL]` set unchanged
      from baseline
- [ ] `bash .claude/scripts/tests/run-all.sh --quiet` — `[FAIL]` set equals baseline minus
      `test-common-lib.sh`, no additions
- [ ] `diff .opencode/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh`
      produces no output
- [ ] `bash -n .opencode/scripts/command-gate-in.sh` exits 0
- [ ] `bash .claude/scripts/check-task-references.sh` reports PASS with 0 occurrences
- [ ] `git status --short` shows exactly one changed deliverable path outside `specs/**`

## Artifacts & Outputs

- `.opencode/scripts/command-gate-in.sh` — resynced to match its source-store original
- `specs/1010_fix_opencode_gate_in_session_id_duplication/plans/01_opencode-gate-in-catchup-sync.md`
  (this file)
- `specs/1010_fix_opencode_gate_in_session_id_duplication/summaries/01_*-summary.md`
- `specs/1010_fix_opencode_gate_in_session_id_duplication/.orchestrator-handoff.json`
- Two spawn candidates surfaced for the orchestrator (headless `.opencode` deploy entrypoint;
  full `.opencode/scripts/` resync)

## Rollback/Contingency

The change is a single-file content replacement in a git-tracked path, so rollback is trivial and
low-risk:

- Before commit: `git checkout -- .opencode/scripts/command-gate-in.sh` restores the stale
  content. (The working tree must be clean of other uncommitted work, or a
  `bash .claude/scripts/git-snapshot.sh 1010` must be taken first — see the "No Destructive Git on
  Uncommitted Work" rule.)
- After commit: `git revert` the single commit. Nothing else depends on the change; reverting
  simply reinstates the pre-existing deployed-mode `test-common-lib.sh` failure, which is the
  status quo ante and breaks nothing else.
- If the copy somehow breaks `.opencode/` command execution (not expected — the identical content
  already runs as `.claude/scripts/command-gate-in.sh`), revert and re-open the task noting that
  `.opencode/`'s missing `scripts/lib/` subdirectory forced reliance on the repo-root-absolute
  `lib/common.sh` resolution path, which the research confirmed resolves via
  `${repo_root}/.claude/scripts/lib/common.sh`.
