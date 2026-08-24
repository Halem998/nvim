# Implementation Summary: Task #82

- **Task**: 82 - wire_deploy_verification_into_deploy_headless
- **Status**: [COMPLETED]
- **Started**: 2026-08-24T23:07:00Z
- **Completed**: 2026-08-25T00:05:00Z
- **Effort**: ~4 hours (elapsed; host under heavy contention for most of the session)
- **Dependencies**: 32 (completed; not a live blocker)
- **Artifacts**: plans/01_wire-verify-into-deploy-headless.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`deploy-headless.sh` previously echoed the `verify-deploy.sh` invocation command instead of
running it, so its twelve-plus gates were reachable only by a human typing the command by hand.
This implementation added a `--skip-slow` flag to `verify-deploy.sh` (skips gate 8, the 118s
shell test suite, only), wired `deploy-headless.sh` to invoke
`verify-deploy.sh --skip-slow "$TARGET"` inline after every non-dry-run deploy, and introduced a
new, distinct exit code `3` for "deploy landed, but verification failed" — never overloading the
existing `1`/`2` semantics. The `skill-orchestrate` collision and the pre-existing-red-gate
consequence are documented in `regeneration-is-manual-only.md`.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — added `SKIP_SLOW` flag declaration,
  `--skip-slow` arg-parse arm, a gate-8 `[SKIP]` branch (checked first, before the
  source-store-vs-consumer skip), a "Slow-gate selection" header paragraph, and an updated
  `--help` `sed` line range.
- `agent-system/extensions/core/scripts/deploy-headless.sh` — replaced the trailing
  `echo "Verify with: ..."` line with a real, `-e`-safe `if bash ... --skip-slow "$TARGET"; then
  ... else ... exit 3; fi` invocation inside `main()`'s shared trailing block (both the default
  and `--wipe` branches converge there), preceded by an announcement line and followed by a
  named full-gate re-run command on failure. Updated the header `Exit codes:` block to document
  code `3` and updated the `--help` `sed` range.
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` — new fixture-driven
  regression suite (5 cases, 9 assertions) covering `--skip-slow`'s SKIP wording, the absent
  `FINDING gate8` line, the unshadowed unknown-flag arm, `--dry-run`'s non-invocation of
  verification, and a static assertion that `exit 3` and its header documentation remain present.
  The fixture is a throwaway consumer directory with no `agent-system/extensions` subdirectory,
  so gate 8 (which discovers this very suite via `run-all.sh`) structurally cannot recurse.
- `agent-system/extensions/core/manifest.json` — registered
  `tests/test-deploy-verify-wiring.sh` under `provides.scripts` (disclosed deviation: not
  explicitly listed in Phase 3's task text, but required for the new suite to deploy and pass
  gate 5's declared-vs-deployed parity check).
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — new
  subsection under `## Automated Exception: The Inter-Cycle Self-Modification Checkpoint`
  documenting the exit-3 contract, the fast/full gate split, the `skill-orchestrate` Stage MT-3
  step 7 collision (exit 3 sits inside the leading "Non-zero exit" phrase of that step's
  deploy-failure branch but outside its `(1 or 2)` enumeration, so its current behavior on exit 3
  is ambiguous), the recommended (undone) follow-up, and the live doc-lint/gate-8 consequence.
- `agent-system/extensions/core/index-entries.json` — corrected the `line_count` for
  `patterns/regeneration-is-manual-only.md` (210 -> 307) to keep the entry accurate after the
  Phase 4 edit grew the file; a hygiene fix scoped to the one file this task touched, not the ten
  other pre-existing mismatches found in the same file (out of scope per the plan's Non-Goals).

## Decisions

- Kept the inline call scoped to `--skip-slow` only (not `--findings`), matching Phase 2's
  authorized scope — passing `--findings` on every failing deploy would print all pre-existing
  findings (14, as of this session) on every red run, a design change not authorized here.
- Fixed the `manifest.json` registration and the one `index-entries.json` line_count entry this
  task's own edits drifted, rather than leaving either as newly-introduced drift for a reader to
  discover independently.

## Plan Deviations

- **Phase 3** (manifest.json registration): added `tests/test-deploy-verify-wiring.sh` to
  `provides.scripts` — not explicit in the phase's task list, but required for the new suite to
  deploy and pass gate 5 parity. Disclosed expansion, consistent with the plan's own precedent
  for this file being outside the declared `file_scope`.
- **Phase 5** (acceptance verification, "appears by name"): the injected `line_count` mismatch is
  confirmed to cause exit 3 and a named gate-3 failure, but its specific file/line_count text is
  not printed inline without a follow-up `check-extension-docs.sh` re-run — `check-extension-docs.sh`
  is always invoked with `--quiet` internally by gate 3, and the inline call does not pass
  `--findings`. The task-level ACCEPTANCE criterion (non-zero exit, failure surfaced, no human
  `verify-deploy.sh` invocation) is met; the plan's stricter verification wording is not, without
  scope expansion beyond Phase 2. See `progress/phase-5-progress.json` for full reasoning.
- **Phase 5** (timing measurement): could not cleanly re-measure absolute `--skip-slow` vs. full
  timing — the implementation host was under heavy, externally-caused load (measured up to ~15
  load average) for the whole session, inflating every gate's wall-clock time well past the
  plan's ~50-70s/~2.8min estimates. The structural mechanism (exactly gate 8 skipped, confirmed
  by its own `[SKIP]` line and its absence from `--skip-slow` runs) is verified; absolute-second
  re-measurement is deferred to a future run on an unloaded host.
- **Testing & Validation** (`run-all.sh` failure count): measured 2 pre-existing failing suites
  in this session, not the 3 named in the task description — one of the three suites is passing
  in this session's environment, unrelated to this task. The count did not increase to 4 with the
  new suite added (48 passed + 2 failed = 50 total), which is the property this criterion exists
  to protect.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-deploy-verify-wiring.sh` standalone: 9/9 passed in 0.1s; `run-all.sh
  --quiet`: 48 passed, 2 failed (pre-existing, unrelated), 50 total (discovered the new suite)
- Files verified: Yes — `bash -n` clean on both modified scripts; `--help` renders both updated
  header blocks with no truncation
- End-to-end acceptance: three real `deploy-headless.sh` runs performed —
  (1) clean state: exit 3, 1 of 23 checks failed (pre-existing doc-lint only)
  (2) deliberately injected `line_count` mismatch: exit 3, gate 3 failed, no human
      `verify-deploy.sh` invocation
  (3) reverted: exit 3, 1 of 23 checks failed again (matches clean-state baseline exactly)
  Final full (no `--skip-slow`) `verify-deploy.sh` run: 2 of 24 checks failed (gate 3 + gate 8,
  both pre-existing) — confirms no new failures anywhere in the full 24-gate surface.
- `git status --short` clean of injection residue at every checkpoint.

## Impacts

- Every non-dry-run `deploy-headless.sh` invocation now runs real verification and will exit 3
  until this repo's pre-existing doc-lint issues and the 2 pre-existing failing test suites are
  fixed. This is the intended, disclosed behavior — not a regression.
- `skill-orchestrate` Stage MT-3 step 7's deploy-failure branch text is ambiguous on exit 3
  (documented, not fixed here — see Follow-ups).

## Follow-ups

- Recommended (not started): teach `skill-orchestrate/SKILL.md` Stage MT-3 step 7 to route exit 3
  through its existing baseline-comparison branches (b)/(c) instead of the unconditional-defer
  branch (a), using the exit-3 discriminator this task installed. Touches
  `skills/skill-orchestrate/SKILL.md` and `context/patterns/batch-orchestration-guardrails.md`.
- Optional: pass `--findings` (or a curated subset) from `deploy-headless.sh`'s inline call so a
  freshly-introduced drift's specific finding text appears without a follow-up
  `check-extension-docs.sh` invocation — deferred as a design change beyond this task's scope.
- Fix the 10 pre-existing `index-entries.json` line_count mismatches and the 3 Rule S
  deployed-index-orphan findings recorded in the Phase 5 baseline (`agent-system/extensions/core/`
  and `literature`) — out of scope for this task, but now the exit-3 contract this task installs
  will surface them on every deploy until fixed.

## References

- `specs/082_wire_deploy_verification_into_deploy_headless/plans/01_wire-verify-into-deploy-headless.md`
- `specs/082_wire_deploy_verification_into_deploy_headless/reports/01_wire-verify-into-deploy-headless.md`
- `specs/082_wire_deploy_verification_into_deploy_headless/progress/phase-1-progress.json` through `phase-5-progress.json`
