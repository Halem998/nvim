# Implementation Summary: Task #885

**Completed**: 2026-07-15
**Duration**: ~1 session (Phases 1-4 landed; Phases 5-6 handed off, [BLOCKED])

## Overview

Landed all four regeneration-independent deliverables from the plan (source-store edits under
`agent-system/extensions/core/**`, each verified by actually running the modified script and
observing the result). The task's own research settled that there is no headless/CI path to
trigger the `<leader>al` regeneration required to deploy these changes or to verify live event
flow, so the task finishes honestly `[PARTIAL]` with Phases 5-6 handed off as `[BLOCKED]` — this
is the expected, correct terminus, not a failure.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — Replaced 4 `bash ... || true` silent-fail
  sites with a duplicated `_events_append_observable` wrapper (present/missing/failed distinction,
  always returns 0).
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — Same wrapper pattern at its
  2 event-append call sites; fixed an `if`-guard bug so a present-but-failing helper no longer
  aborts the script under `set -euo pipefail`.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — Same wrapper at its 2 call sites;
  removed an early `[ -x "$EVENTS_APPEND" ] || exit_success` bypass that used to short-circuit
  before the wrapper could ever signal a missing helper. Also threads `--cwd` from hook stdin.
- `agent-system/extensions/core/hooks/events-log-artifact.sh` — Same wrapper at its 2 call sites;
  removed the equivalent early bypass; threads `--cwd` from hook stdin.
- `agent-system/extensions/core/context/schemas/events-schema.json` — Added a nullable `cwd`
  string field (not `cc_session_id`, which belongs to an unfrozen sibling design).
- `agent-system/extensions/core/scripts/events-append.sh` — Added `--cwd PATH`; writes `null` when
  absent (backward compatible).
- `agent-system/extensions/core/scripts/events-query.sh` — Derives `repo` at query time as
  `basename(cwd)` (never stored); added `--repo` filter and `by_repo` summary-counts aggregate;
  tolerant of `cwd: null`.
- `agent-system/extensions/core/context/formats/events-format.md` — Documents the `cwd` field and
  the cross-repo-federation derivation contract.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — New ADVISORY lane (`advisory()`
  helper, `DEPLOY_DRIFT_ADVISORIES` counter, dedicated always-visible summary section) surfacing
  core-extension never-deployed `provides.scripts`/`provides.hooks` entries and
  `root-files/settings.json` hook-registration gaps/duplicates. Opt-in `STRICT_CORE_DEPLOY=1`
  promotes these to real failures.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — New file
  documenting the no-headless-regeneration constraint for future reference.
- `agent-system/extensions/core/index-entries.json` — Registered the new pattern file.
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` — New durable, user-executable
  handoff: exact `<leader>al` regeneration procedure + success criteria, and the dotfiles
  telemetry/retention snippet (not applied to this repo).

## Decisions

- **Shared wrapper duplicated inline, not sourced from a new file**: the 4 call-site files span
  sourced (`skill-base.sh`) and standalone (`orchestrator-postflight.sh`, 2 hooks) execution
  contexts with no existing shared-sourcing convention, and a new shared script would need a
  `manifest.json` registration outside this task's edit-target scope. Took the plan's own
  documented fallback.
- **`repo` derived as `basename(cwd)` via pure jq, not a per-row `git rev-parse --show-toplevel`
  shell-out**: keeps `events-query.sh` consistent with its existing native-jq streaming-filter
  design; the plan itself flagged the git-toplevel approach as an example ("e.g."), not a
  requirement.
- **Phase 3's "not deployed = FAIL for core" design point was altered to ADVISORY, not FAIL**, per
  a binding orchestrator guardrail issued after the plan was written: the pre-existing core
  deploy drift this check surfaces is real right now and can only be resolved by a user-driven
  regeneration, so a hard FAIL would have bricked the doc-lint gate for every caller — including a
  concurrently running sibling session validating an unrelated memory-extension manifest change
  through this same script — until that regeneration happens. An opt-in `STRICT_CORE_DEPLOY=1`
  lane preserves the original hard-FAIL behavior for callers who want it (e.g. a future
  post-regeneration verification run).

## Plan Deviations

- **Task 1.1** (shared wrapper location) altered: duplicated inline in each of the 4 call-site
  files instead of a single sourced shared script — see Decisions above.
- **Task 2.5** (`repo` derivation) altered: `basename(cwd)` via jq instead of a git-toplevel
  shell-out — see Decisions above.
- **Task 3.1** (core "not deployed" severity) altered: implemented as an ADVISORY lane instead of
  a hard FAIL, per the binding orchestrator concurrency guardrail — see Decisions above and
  `check_core_deploy_advisory`'s in-file rationale comment.
- **Task 4.1** (source-store note) additionally registered the new pattern file in
  `index-entries.json` — not explicitly listed in the plan's file list, but a minimal, low-risk
  companion edit for discoverability, consistent with this repo's existing convention.

Full per-phase deviation entries with reasons: see `progress/phase-{1,2,3,4}-progress.json`.

## Verification

- **Phase 1**: Sandboxed present/absent/failing-helper harness run against all 4 modified files,
  both as direct wrapper calls and full end-to-end stage/hook runs (`skill_context_injection`,
  both `events-log-lifecycle.sh` paths, both `events-log-artifact.sh` branches). Caught and fixed
  a real `set -e` correctness bug where a present-but-failing helper would abort the enclosing
  script before the wrapper could capture its exit code and return 0.
- **Phase 2**: `events-append.sh` run with and without `--cwd`; emitted JSONL lines inspected and
  manually validated against the updated schema (cwd present/nullable, `cc_session_id` absent).
  `events-query.sh` run over a 3-row fixture (populated `cwd` x2, `null` x1): confirmed correct
  `repo` derivation, `--repo` filtering, `by_repo` aggregation, and zero errors on `cwd: null`
  rows. Both hooks confirmed end-to-end to thread `cwd` from stdin into the emitted event line.
- **Phase 3**: Ran the git-committed (pre-edit) `check-extension-docs.sh` via `git show HEAD:...`
  as the literal "before" baseline against the live tree (`REPO_ROOT=$(pwd) ... --quiet`): `exit=1`,
  `FAIL: 5 issue(s) found`, events files silently absent from output. Ran the edited script the
  same way: byte-identical verdict (`exit=1`, `FAIL: 5 issue(s) found`) plus a new, always-visible
  41-item ADVISORY section (including a live-confirmed instance of the duplicate
  `claude-stop-notify.sh` Stop-matcher artifact the research predicted). Full-output `diff`
  confirmed the ADVISORY section was the ONLY delta. `[memory]` extension output confirmed
  byte-identical before/after (additivity with the concurrent sibling task). `STRICT_CORE_DEPLOY=1`
  confirmed to promote the same 41 advisories to real failures (`FAIL: 46`).
- **Phase 4**: `grep -nE 'task [0-9]|tasks [0-9]'` returns no matches on the source-store note.
  `HANDOFF.md` confirmed to contain the keystroke sequence and dotfiles snippet verbatim.
- Build: N/A (bash/JSON/Markdown only)
- Tests: N/A (no test suite for this file set; verification was run-and-observe per the plan's
  own requirement)
- Files verified: Yes — every file listed in "What Changed" was read back or its behavior
  explicitly run and observed, not merely assumed correct after editing.

## Notes

- **Phases 5-6 are `[BLOCKED]`, not skipped** — see
  `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` for the exact user-executable
  procedure. Phase 5 (manual `<leader>al` "Sync all" regeneration in nvim and at least one other
  repo) is a one-time human action; Phase 6 (end-to-end event-flow verification) is additionally
  gated on accumulated real command usage after regeneration and cannot be verified today.
- **No event flow has been verified today.** All Phase 1-4 verification exercised the modified
  scripts directly in sandboxed, deploy-shaped trees (or, for Phase 3, against the live source
  tree with explicit `REPO_ROOT` override) — this proves the CODE is correct, not that live event
  flow works in a regenerated repo. That claim can only be made after the HANDOFF.md procedure is
  followed and real usage accumulates.
- The dotfiles telemetry/retention settings (scope 3/4) were deliberately NOT applied to this
  repo — see HANDOFF.md Part B for the exact snippet and rationale (`cleanupPeriodDays: 365`,
  never `0`, per `anthropics/claude-code` issue #23710).
