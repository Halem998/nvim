# Implementation Plan: Widen validate-handoff-location.sh's task-directory digit-count regex

- **Task**: 1007 - Fix validate-handoff-location.sh's fixed-3-digit task-directory regex
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/1007_fix_handoff_location_regex_4digit_tasks/reports/01_widen-handoff-location-regex.md
- **Artifacts**: plans/01_widen-handoff-location-regex.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/hooks/validate-handoff-location.sh` gates every
`.orchestrator-handoff.json` write against an allow-pattern whose task-directory segment uses the
**exact-count** quantifier `[0-9]{3}`. Now that `specs/state.json`'s `next_project_number` has
crossed 1000, every task directory is 4+ digits, so a correctly-placed handoff can never match:
the hook emits a false `MISPLACED` diagnostic, exits 2, and unconditionally records a spurious
`HANDOFF_MISLOCATED` system defect. The fix is a one-token quantifier widen (`{3}` -> `{3,}`),
paired with a stale-comment update, a new regression suite that pins both the accept and reject
sides of the matcher, and manifest registration so the new suite actually deploys.

Definition of done: a handoff written under a 4-digit task directory exits 0 with no
`MISPLACED` diagnostic and no defect record; genuinely misplaced paths (bare filename, non-numeric
prefix, fewer than 3 digits, non-task location) still exit 2; the new suite is discovered by
`run-all.sh`, registered in the core manifest, and green.

### Research Integration

Findings carried directly into this plan:
- **Exact defect location and mechanism**: `[0-9]{3}` is exact-count, not minimum; `1007_` has
  `100` consumed by the class, leaving `7` where the regex demands a literal `_`.
- **Single-occurrence scope**: a source-store-wide grep for `\[0-9\]{3}_` returns exactly one hit
  (this line). No sibling replication is needed, and no follow-up defect class exists elsewhere.
- **One textual edit covers both branches**: `(OC_)?` is an optional group preceding the shared
  digit class, so the bare and `OC_`-prefixed shapes are fixed by the same single token change.
- **No existing coverage**: `test-validate-handoff.sh` tests a *different* script
  (`scripts/validate-handoff.sh`, a JSON content-schema validator), not this path-matching hook.
  A new suite is required; `test-validate-no-task-references.sh` is the structural model.
- **Accept path never reaches the defect recorder**: the allow branch returns via
  `echo '{}'; exit 0` before the `system-defect-record.sh` call, so the required negative fixture
  needs no stub or mock of that script.
- **Auto-discovery**: `run-all.sh` globs `scripts/tests/test-*.sh`, so no test-runner registration
  step is needed.

**Gap found during planning, not present in the research report**: `run-all.sh` auto-discovery is
necessary but **not sufficient** for the new suite to reach a deployed repo. The core
`manifest.json`'s `provides.scripts` array is an **exhaustive allowlist**, verified during
planning: all 27 test files on disk are listed, with zero entries on either side of the diff. An
unregistered new test file exists in the source store, is picked up by a source-store-rooted
`run-all.sh` run, and is then silently absent from `.claude/scripts/tests/` after deploy — exactly
the deploy-propagation defect class called out in
`specs/decisions/no-task-references-enforcement-history.md`. Phase 3 exists to close this.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Accept task directories with 3 or more digits (legacy 3-digit, current 4-digit, and any future
  digit-count growth) without a further edit at the next order-of-magnitude crossing.
- Keep rejecting genuinely misplaced handoff paths, pinned by explicit reject fixtures rather than
  by assertion.
- Leave the comment block at the top of the allow-branch consistent with the widened regex.
- Land durable regression coverage for a hook that currently has none, and ensure it deploys.

**Non-Goals**:
- Widening the exact-basename guard — it is correct and out of scope.
- Touching the `system-defect-record.sh` invocation, its arguments, or its swallowed-failure
  wrapping.
- Investigating the separately-observed failure of the `system-defect-record.sh` call itself
  (noted in the research report's Live Confirmation section) — unrelated, separately scoped.
- Re-running the capstone LIVE CYCLE acceptance verification; that is explicitly deferred to a
  later capstone re-run once this fix has landed and been redeployed.
- Retrofitting coverage onto any other hook.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widened quantifier over-accepts non-task paths | H | L | `{3,}` widens count only, never the character class — still `[0-9]` anchored. Phase 2's reject fixtures (non-numeric prefix, 2-digit prefix, bare filename, bare `specs/` location) pin this and fail loudly on any future regression |
| New test file never reaches deployed repos | M | H (if unaddressed) | Phase 3 registers it in the core manifest's exhaustive `provides.scripts` allowlist and verifies via the deploy-propagation gate |
| Deployed `.claude/` mirror keeps the old regex after the source edit | M | H | Expected deploy-boundary behavior, not a defect in the fix. Phase 4 verifies the source-store edit and explicitly reports that a redeploy is required to clear the live symptom |
| Test author accidentally hand-edits the deployed `.claude/` mirror | H | L | Phase 4 runs an explicit deploy-boundary check confirming every edited path is under `agent-system/extensions/**` |
| Fixture paths mistaken for real task citations by the deliverable lint | L | L | Use neutral synthetic directory numbers in fixtures, never a live task number; Phase 4 runs `check-task-references.sh` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Widen the quantifier and correct the allow-shape comment [COMPLETED]

**Goal**: The hook accepts 3-or-more-digit task directories, and the comment directly above the
matcher no longer teaches the fixed-3-digit assumption.

**Tasks**:
- [x] In `agent-system/extensions/core/hooks/validate-handoff-location.sh`, change the allow-branch
      matcher's `[0-9]{3}_` to `[0-9]{3,}_`. The full resulting pattern:
      `(^|/)specs/(OC_)?[0-9]{3,}_[^/]+/\.orchestrator-handoff\.json$` *(completed)*
- [x] Update the `# Allowed shapes, absolute or relative:` comment immediately above that matcher
      so the `{NNN}` placeholder is annotated as "3 or more digits" — a reader who trusts the
      comment over re-deriving the regex must not re-learn the exact-3 assumption. *(completed)*
- [x] Confirm by reading the diff that exactly one regex token changed and that the
      `(OC_)?` group, the `[^/]+` slug segment, the `(^|/)` prefix anchor, and the `$` terminator
      are all byte-identical to before. *(completed: git diff confirms 2 lines changed — comment
      wording and the single {3} -> {3,} token; all other regex tokens byte-identical)*

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the change is confined to **one file and one regex
token** (plus adjacent comment lines). Confirm at implementation time by running
`grep -rn '\[0-9\]{3}_' agent-system/` and observing zero remaining hits, and by confirming
`git diff --stat` reports exactly one changed file for this phase.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` - widen the digit-count
  quantifier in the allow-branch matcher; update the allow-shapes comment above it

**Verification**:
- `bash -n agent-system/extensions/core/hooks/validate-handoff-location.sh` parses clean
- Ad hoc matcher check against the widened pattern accepts `specs/042_foo/...`,
  `specs/1234_foo/...`, `specs/OC_1234_foo/...`, `specs/12345_foo/...` and rejects
  `specs/42_foo/...`, `specs/abc_foo/...`, `specs/.orchestrator-handoff.json`, and a bare
  `.orchestrator-handoff.json`
- `grep -rn '\[0-9\]{3}_' agent-system/` returns no hits

---

### Phase 2: Add the regression suite pinning both accept and reject sides [NOT STARTED]

**Goal**: A durable, auto-discovered test suite that fails loudly if the 4-digit accept case
regresses or if the matcher over-widens.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh`,
      modeled structurally on `test-validate-no-task-references.sh`: `mktemp -d` workdir with a
      `trap ... EXIT` cleanup, the hook copied byte-for-byte into the workdir at the relative path
      its `SCRIPT_DIR` resolution expects, synthetic PostToolUse JSON built with `jq -n` and piped
      on stdin, `pass()`/`fail()`/`info()` helpers with `PASSED`/`FAILED` integer counters, and
      exit 0 all-pass / 1 any-fail / 2 environment error (missing hook or missing `jq`).
- [ ] Assert on **exit code** (0 = allowed, 2 = misplaced), matching the hook's real contract; the
      hook must never be instrumented or modified for testability.
- [ ] Implement the accept fixtures: 3-digit legacy; **4-digit — the required negative test, which
      must NOT trip `HANDOFF_MISLOCATED`**; 4-digit with `OC_` prefix; 5-digit future-proofing.
      For the 4-digit case additionally assert that stderr carries no `MISPLACED` text, so the
      fixture pins the diagnostic's absence and not merely the exit code.
- [ ] Implement the reject fixtures: bare `.orchestrator-handoff.json` with no directory;
      `specs/.orchestrator-handoff.json` (outside any task directory); non-numeric prefix
      (`specs/abc_foo/...`); 2-digit prefix (`specs/42_foo/...`, confirming `{3,}` still enforces a
      3-digit minimum rather than "any digits").
- [ ] Implement the non-trigger fixture: a differently-named file such as `handoff-example.json`
      exits 0, confirming the exact-basename guard is untouched by this change.
- [ ] Use neutral synthetic directory numbers in fixture paths — never a live task number — so the
      fixtures read as obviously synthetic and stay clear of the deliverable-citation lint.
- [ ] Make the file executable (`chmod +x`).

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a **9-fixture** minimum set (4 accept, 4 reject, 1
non-trigger) in **one new file**. Confirm at implementation time by counting the emitted
`[PASS]` lines in the suite's own output and reconciling that count against the fixture list
above; if a fixture proves redundant or an additional edge case is discovered, record the
deviation in the implementation summary rather than silently changing the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` - new file

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` exits 0
  with every fixture reporting `[PASS]`
- Temporarily reverting the Phase 1 quantifier in a scratch copy makes the 4-digit, `OC_`-prefixed,
  and 5-digit accept fixtures fail — proving the suite actually pins the fix rather than passing
  vacuously. Restore the fix immediately; do not commit the scratch revert.
- The reject and non-trigger fixtures pass both before and after the Phase 1 change, confirming the
  widen did not alter rejection behavior

---

### Phase 3: Register the new suite in the core manifest [NOT STARTED]

**Goal**: The new test file is declared in the core extension's deploy allowlist, so it actually
lands in a deployed repo instead of existing only in the source store.

**Tasks**:
- [ ] Add `tests/test-validate-handoff-location.sh` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, placed adjacent to the other `tests/` entries
      and matching their exact string form (`tests/`-prefixed, no leading `./`).
- [ ] Confirm the manifest remains valid JSON.
- [ ] Re-run the disk-vs-manifest reconciliation that established this allowlist is exhaustive:
      the set of `tests/*.sh` files on disk and the set declared in `provides.scripts` must be
      equal, with an empty diff in both directions.

**Timing**: 15 minutes

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the manifest allowlist is **exhaustive** (28 test entries
after this addition, up from 27). Confirm at implementation time with a bidirectional `comm` of the
on-disk `tests/*.sh` basenames against the manifest's `tests/`-prefixed entries; both diff
directions must be empty. If the allowlist turns out not to be exhaustive, stop and report rather
than assuming registration is optional.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add the new test file to `provides.scripts`

**Verification**:
- `jq -e '.provides.scripts | index("tests/test-validate-handoff-location.sh")'` succeeds
- `jq empty agent-system/extensions/core/manifest.json` succeeds (valid JSON)
- Bidirectional disk-vs-manifest `comm` over `tests/*.sh` produces no output on either side
- `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` passes

---

### Phase 4: Full gate, deploy-boundary check, and redeploy note [NOT STARTED]

**Goal**: The complete repository gate set is green, every edit landed in the source store rather
than the deploy mirror, and the required redeploy is explicitly recorded.

**Tasks**:
- [ ] Run the full test suite via `agent-system/extensions/core/scripts/tests/run-all.sh` and
      confirm the new suite is auto-discovered and green alongside the existing 27.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and confirm all gates pass, including the
      task-reference lint gate.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm the new test file introduces
      no unexempted task-number citation.
- [ ] **Deploy-boundary check**: confirm via `git status --short` that every path modified across
      Phases 1-3 is under `agent-system/extensions/**` and that **no** file under `.claude/**` was
      hand-edited. A `.claude/**` edit in the diff means the source-store rule was violated and must
      be reverted and redone against the source store.
- [ ] Record in the implementation summary that the deployed `.claude/` mirror still carries the old
      3-digit regex until the next `[Reload All]` / `[Regenerate]` / `deploy-headless.sh` run, so
      the live symptom persists until redeploy. State this as a required follow-up action, not as a
      completed one, unless a redeploy is actually performed.

**Timing**: 15 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- None (verification only)

**Verification**:
- `run-all.sh` exits 0 with `test-validate-handoff-location.sh` listed among the suites run
- `verify-deploy.sh` exits 0
- `check-task-references.sh` exits 0
- `git status --short` shows changes only under `agent-system/extensions/**` and `specs/**`

---

## Testing & Validation

- [ ] A handoff path under a 4-digit task directory exits 0 and produces no `MISPLACED` diagnostic
- [ ] A handoff path under a 4-digit `OC_`-prefixed task directory exits 0
- [ ] A handoff path under a legacy 3-digit task directory still exits 0 (no regression)
- [ ] A 5-digit task directory exits 0 (no repeat of this defect at the next crossing)
- [ ] A bare `.orchestrator-handoff.json` filename still exits 2
- [ ] `specs/.orchestrator-handoff.json` (outside any task directory) still exits 2
- [ ] A non-numeric directory prefix still exits 2
- [ ] A 2-digit directory prefix still exits 2 (the 3-digit minimum is genuinely enforced)
- [ ] A differently-named file is ignored entirely (exact-basename guard intact)
- [ ] `run-all.sh`, `verify-deploy.sh`, and `check-task-references.sh` all exit 0
- [ ] No file under `.claude/**` was hand-edited

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/validate-handoff-location.sh` (modified: widened quantifier,
  corrected comment)
- `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` (new regression
  suite)
- `agent-system/extensions/core/manifest.json` (modified: new test registered in `provides.scripts`)
- `specs/1007_fix_handoff_location_regex_4digit_tasks/summaries/01_widen-handoff-location-regex-summary.md`
  (implementation summary, including the explicit redeploy-required note)

## Rollback/Contingency

All three edits are small, additive-or-single-token, and independently revertable:

- **Regex widen**: revert `{3,}` to `{3}` in the hook. This restores the known-broken behavior, so
  do it only if the widen is shown to over-accept — in which case the correct response is to
  narrow the pattern deliberately (e.g. an explicit upper bound) with a new reject fixture pinning
  the narrowing, not to restore the exact-3 quantifier.
- **New test file**: delete the file and remove its `provides.scripts` entry. Because `run-all.sh`
  discovers purely by glob, deletion fully removes it from the suite with no other cleanup.
- **Manifest entry**: revert the single array-element addition; the manifest is otherwise untouched.

If a phase fails mid-way, the phases are ordered so each leaves the tree green on its own: Phase 1
alone is a correct, shippable fix; Phase 2 adds coverage; Phase 3 makes that coverage deployable.
Stopping after any completed phase is safe.
