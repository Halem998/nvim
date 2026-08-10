# Implementation Summary: Task #1007

- **Task**: 1007 - Fix validate-handoff-location.sh's fixed-3-digit task-directory regex
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T15:36:19Z
- **Completed**: 2026-08-10T16:20:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_widen-handoff-location-regex.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`validate-handoff-location.sh`'s allow-branch matcher used the exact-count quantifier
`[0-9]{3}`, so once `specs/state.json`'s `next_project_number` crossed 1000, every legitimately
placed `.orchestrator-handoff.json` write under a 4+-digit task directory failed to match,
tripping a false `MISPLACED` diagnostic and an unconditional `HANDOFF_MISLOCATED` system-defect
record. The fix widens the quantifier to `{3,}` (a one-token change covering both the bare and
`OC_`-prefixed branches, since they share one alternation group), corrects the adjacent
allow-shapes comment, adds a new 9-fixture regression suite, and registers that suite in the
core manifest's exhaustive `provides.scripts` allowlist so it actually deploys.

## What Changed

- `agent-system/extensions/core/hooks/validate-handoff-location.sh` — widened the allow-branch
  matcher's digit-count quantifier from `[0-9]{3}` to `[0-9]{3,}`, and updated the "Allowed
  shapes" comment to state the `{NNN}` placeholder is "3 or more digits" instead of implying an
  exact 3.
- `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` — new
  regression suite (modeled on `test-validate-no-task-references.sh`): copies the hook
  byte-for-byte into an isolated `mktemp -d` workdir, pipes synthetic PostToolUse JSON on stdin,
  and asserts on exit code (0 = allowed, 2 = misplaced). 9 fixtures: 4 accept (3-digit legacy,
  4-digit required negative fixture with an explicit no-`MISPLACED`-text assertion, 4-digit
  `OC_`-prefixed, 5-digit future-proofing), 4 reject (bare filename, `specs/` root, non-numeric
  prefix, 2-digit prefix), 1 non-trigger (differently-named file, confirming the exact-basename
  guard is untouched).
- `agent-system/extensions/core/manifest.json` — added
  `"tests/test-validate-handoff-location.sh"` to `provides.scripts`, adjacent to the other
  `tests/test-validate-*.sh` entries.

## Decisions

- Used the exact fixture path examples already specified in Phase 1's own verification bullets
  (`specs/042_foo/...`, `specs/1234_foo/...`, etc.) as the model for Phase 2's fixture set, then
  substituted clearly-synthetic directory numbers (`042`, `8842`, `88420`, `42`) rather than any
  live task number, per the deliverable-citation lint's exemption taxonomy.
- Did not copy `system-defect-record.sh` into the test workdir: the hook's reject branch already
  swallows that call's failure (`>/dev/null 2>&1 || echo ... >&2`) before falling through to
  `exit 2` unconditionally, so a missing recorder script does not affect the exit-code contract
  under test and needed no stub or mock.
- Verified the suite actually pins the fix (not merely passing vacuously) by reverting the
  quantifier to `{3}` in a scratch copy and re-running the suite against it: the 4-digit,
  `OC_`-prefixed, and 5-digit accept fixtures failed as expected while the reject and
  non-trigger fixtures stayed stable, confirming the suite exercises the real regression.

## Plan Deviations

- **Phase 4** closed as `[COMPLETED WITH EXCLUSIONS]` rather than plain `[COMPLETED]`. Two of
  the four listed gates could not close green as originally specified, each for a fully
  diagnosed, evidenced, and explicitly plan-anticipated reason (full detail in the plan's Phase 4
  `#### Reasoned Exclusions` table):
  - `run-all.sh`'s aggregate exit code is 1, not 0, due to one pre-existing failure in
    `test-index-entries-schema.sh` (Rule U: "did not fire on a 61-line EXTENSION.md"), unrelated
    to this task's scope. Confirmed pre-existing via `git show 0ed5c9517:...` diffed
    byte-identical against the current file (`0ed5c9517` is the commit immediately preceding this
    task's Phase 1 commit). The new suite itself, `test-validate-handoff-location.sh`, is
    auto-discovered and reports `[PASS]` in the same run.
  - `verify-deploy.sh`'s gate 5 (manifest-driven content-hash/category parity) reports exactly 2
    findings, both the expected staleness of the deployed `.claude/` mirror relative to the
    just-edited source store: `Missing scripts: scripts/tests/test-validate-handoff-location.sh`
    and `Content differs from source: hooks/validate-handoff-location.sh`. This is precisely the
    plan's Risk-table row 3 scenario ("Deployed `.claude/` mirror keeps the old regex after the
    source edit... Expected deploy-boundary behavior, not a defect in the fix"), and clears only
    via a redeploy, which is out of scope for this task per its Non-Goals.

## Verification

- Build: N/A (shell scripts and JSON manifest, no build step)
- Tests: `test-validate-handoff-location.sh` — 9/9 fixtures `[PASS]`, exit 0. Suite verified to
  actually pin the fix via a scratch-copy revert test (3 accept fixtures correctly fail against
  the un-widened `{3}` pattern; reject/non-trigger fixtures unaffected).
- `run-all.sh`: new suite auto-discovered and `[PASS]`; aggregate exit 1 due to one unrelated,
  pre-existing failure (see Plan Deviations).
- `verify-deploy.sh`: gates 1-4, 6-12 pass; gate 5 reports 2 expected deploy-mirror-staleness
  findings (see Plan Deviations).
- `check-task-references.sh`: 0 unexempted occurrences across all 4 scanned trees, exit 0.
- Deploy-boundary check: `git diff --stat` over the Phase 1-3 commit range touches only
  `agent-system/extensions/core/hooks/validate-handoff-location.sh`,
  `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh`, and paths under
  `specs/1007_fix_handoff_location_regex_4digit_tasks/**`. Zero `.claude/**` paths touched.
- Files verified: Yes (hook edit confirmed via `git diff`; new test file confirmed executable and
  passing; manifest entry confirmed present via `jq` and bidirectional disk/manifest `comm`).

## Impacts

- Every task directory created since `next_project_number` crossed 1000 (already true today) can
  now write its `.orchestrator-handoff.json` without tripping a false `MISPLACED` diagnostic or a
  spurious `HANDOFF_MISLOCATED` system-defect record, once the fix is deployed.
- The hook now has durable regression coverage for the first time, pinning both its accept and
  reject behavior against future edits.

## Follow-ups

- **Redeploy required to clear the live symptom**: the deployed `.claude/` mirror still carries
  the pre-fix 3-digit regex and is still missing the new test file until the next
  `[Reload All]` / `[Regenerate]` / `deploy-headless.sh` run. This is a required follow-up
  action, not something performed as part of this implementation task — no redeploy was run.
- The capstone LIVE CYCLE acceptance re-verification (the sibling defect this task was scoped
  out from) is explicitly deferred to a later capstone re-run once this fix has landed and been
  redeployed, per the plan's Non-Goals.
- The separately-observed failure of the `system-defect-record.sh` call itself (noted in the
  research report's Live Confirmation section) remains unrelated and unaddressed, as scoped.

## References

- Plan: `specs/1007_fix_handoff_location_regex_4digit_tasks/plans/01_widen-handoff-location-regex.md`
- Report: `specs/1007_fix_handoff_location_regex_4digit_tasks/reports/01_widen-handoff-location-regex.md`
- Progress files: `specs/1007_fix_handoff_location_regex_4digit_tasks/progress/phase-{1,2,3,4}-progress.json`
