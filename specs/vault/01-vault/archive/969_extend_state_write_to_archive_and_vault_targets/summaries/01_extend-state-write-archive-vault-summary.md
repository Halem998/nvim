# Implementation Summary: Task #969

- **Task**: 969 - Extend state-write.sh to cover archive and vault state files and convert residual hand-rolled sites
- **Status**: [COMPLETED]
- **Started**: 2026-07-29
- **Completed**: 2026-07-30
- **Effort**: ~5 hours
- **Dependencies**: 967
- **Artifacts**: plans/01_extend-state-write-archive-vault.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Extended `state-write.sh` (the single mutex-guarded `specs/state.json` writer) with an optional
`--state-file <path>` flag and an `--init` fresh-create mode, then converted every hand-rolled
`specs/archive/state.json`/vault-root `state.json` write site in the source store — across
`commands/task.md`, `commands/todo.md`, `skills/skill-todo/SKILL.md`, and the two previously
orphaned scripts `scripts/archive-task.sh` and `scripts/vault-operation.sh` — to route through
these two flags. Corrected the stale "Known residual surface" note in
`context/patterns/task-lock.md`, and closed the verification bar against an explicitly enumerated,
re-measured exclusion list rather than an unsatisfiable "zero hits" grep.

## What Changed

- `agent-system/extensions/core/scripts/state-write.sh` — added `--state-file <path>` (default
  unchanged) and `--init`; added the D3 (`--init` vs. default path) and D4 (`--regen-todo` vs.
  non-default `--state-file`) hard usage refusals with `realpath -m`-normalized path comparison;
  rewrote the header contract to document both flags, the D2 single-mutex rationale, and the
  target-agnostic exit-code table.
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` — extended the fixture
  with a `reset_archive_state_json()` helper and added 5 new cases (5–9): non-default
  `--state-file` transform, cross-target single-mutex serialization (the D2 regression guard),
  `--init` fresh-create plus overwrite note, `--regen-todo` refusal plus two accepted default-path
  spellings, and `--init` default-path refusal. Suite grew from 4 to 9 cases, all passing.
- `agent-system/extensions/core/commands/task.md` — recover mode Step 1 and abandon mode Step 1
  (archive writes) converted to `state-write.sh --state-file specs/archive/state.json`; stale
  "Deliberately left hand-rolled" comments replaced with a note on the single-mutex safety of the
  now-adjacent Step 1/Step 2 pair.
- `agent-system/extensions/core/commands/todo.md` — Step 5A made concrete (with `--init`
  bootstrap-if-missing plus a batch transform), Step 5E.2's orphan-entry write converted, and Step
  5.8.6's vault archive reinit converted to `--init`. Step 5.8.4's `mv` (archive `state.json` ->
  vault-root `state.json`) annotated as a rename, correctly outside `state-write.sh`'s remit.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — Stage 9.2's archive reinit converted
  to `--init` (timestamp bound via `--arg`, not shell-interpolated); Stage 10 steps 1 and 8b made
  concrete, matching `commands/todo.md`'s shapes; Stage 9.2's `mv` annotated as a rename; Stages
  9.3/9.4 re-confirmed as already fully converted.
- `agent-system/extensions/core/scripts/archive-task.sh` — step A (archive insert) and the
  init-if-missing block converted to `state-write.sh --state-file`/`--init`; header corrected.
- `agent-system/extensions/core/scripts/vault-operation.sh` — the two former LIVE
  `specs/state.json` writes (renumber, reset) converted to `state-write.sh --state-file` (these
  previously carried zero mutex protection at all); the archive reinit converted to `--init`;
  added `--session-id` plumbing (mirroring `archive-task.sh`'s pattern) since the script had none.
- `agent-system/extensions/core/context/patterns/task-lock.md` — replaced the stale residual-surface
  note (which claimed 14 skill files / 48 sites plus 8 command sites, all now zero) with a
  re-measured note, and added the `--state-file`/`--init` contract documentation (D2/D3/D4) as the
  durable home for that reasoning.
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` — both archive
  examples (Task Recovery, Task Abandon) updated to the sanctioned `state-write.sh --state-file`
  form, keeping the `del()`/two-step escaping-workaround lesson intact.
- `agent-system/extensions/core/index-entries.json` — corrected 2 stale `line_count` values
  (`patterns/jq-escaping-workarounds.md`, `patterns/task-lock.md`) via
  `generate-context-line-counts.sh --write`, flagged by `check-extension-docs.sh` after this
  task's edits grew both files.

## Decisions

- D1–D7 from the plan applied as written: optional `--state-file` (default unchanged); single,
  unparameterized `specs/.scope-lock` mutex across every target (rejecting per-file locks, which
  would create an ABBA deadlock between the recover/abandon interleaved archive+live blocks);
  `--init` mode (rejecting the "wrap the hand-rolled write in scope-acquire/scope-release"
  alternative, which would leave missing staging/validation defects in place); hard `--regen-todo`
  refusal for non-default targets with `realpath -m` normalization; converting
  `archive-task.sh`/`vault-operation.sh` rather than documenting them as dead (the latter had two
  unprotected live-state writes); scoping the verification grep to `agent-system/extensions/core/`
  plus an enumerated exclusion list; making the 3 prose-only archive sites concrete.

## Plan Deviations

- **Testing & Validation item** ("scoped residual grep equals the declared four-item exclusion
  list") altered: the actual post-conversion residual set required a **fifth** declared item —
  `jq-escaping-workarounds.md`'s isolated "Test Script" section (`specs/tmp/test-state.json`), an
  illustrative fixture demonstrating the raw jq escaping-workaround mechanics, never a production
  state-file write site. Recorded as an addition to the exclusion list with a stated reason, per
  the plan's own instruction, not silently passed.
- **Baseline-grep caveat** (found during Phase 8, not pre-declared): the plan's scoped grep
  pattern does not match `archive-task.sh`'s/`vault-operation.sh`'s *original* hand-rolled sites at
  baseline, because those sites redirected through shell variables
  (`"$ARCHIVE_STATE_FILE"`/`"$state_json"`) rather than literal `state.json`/`archive/state.json`
  text adjacent to the redirect. This means the grep alone cannot serve as a regression proof for
  those two scripts; their correctness was instead verified directly via `bash -n`, a `--dry-run`
  smoke test (`archive-task.sh`), and a full no-op-then-confirmed run against a fixtured `>1000`
  state (`vault-operation.sh`). Reported here rather than silently relying on a grep that could
  never have caught a regression in either script.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: `test-state-write-concurrency.sh` 9/9, `test-task-lock-reap.sh` 6/6,
  `test-state-write-regen-timing.sh` 3/3 — all passing
- Adversarial check: temporarily reverting the D4 `--regen-todo` refusal made the new case 8 fail
  as expected, confirming the test actually exercises the guard (not vacuously passing)
- Backward compatibility: 41 `state-write.sh` callers enumerated; `git diff` confirms zero
  unintended argument changes to any pre-existing invocation
- `bash -n`: 4 edited scripts clean; 116 bash fences extracted from 5 edited markdown files (114
  pass; 2 pre-existing, unrelated illustrative "BROKEN" jq-fragment failures in
  `jq-escaping-workarounds.md`, present before this task and never real bash scripts)
- `check-task-references.sh`: exit 0
- `check-extension-docs.sh`: exit 0 (after fixing the 2 stale `index-entries.json` line counts;
  see Follow-ups for the transient deploy-drift note observed mid-task)
- `git status --short`: zero `.claude/**` paths anywhere in the repo; every file this task
  modified is under `agent-system/extensions/core/**` or `specs/**`
- Files verified: Yes

## Impacts

- `specs/archive/state.json` and vault-root `state.json` writes across the core source store now
  get the same mutex-guarded, staged, validated write path as `specs/state.json` — closing a real
  corruption/serialization gap, most notably `vault-operation.sh`'s two former live-state writes
  that carried zero mutex protection.
- Every pre-existing `state-write.sh` caller (41 files) is confirmed unaffected — the new flags are
  purely additive with an unchanged default.

## Follow-ups

- Non-core extension domains (cslib, epidemiology, founder, lean, present, web) still hand-roll
  ~115 `specs/state.json` write sites across 50 files — pre-existing, already-documented,
  out-of-scope surface, re-measured here rather than assumed from the plan's estimate.
- `commands/review.md`'s `specs/reviews/state.json` (3 sites: one fresh-create, two `tmp && mv`
  transforms) is a genuinely different state file, now mechanically convertible via
  `--state-file`/`--init`, left as named follow-up.
- Mid-task, `check-extension-docs.sh` transiently flagged "deployed script content drift" for
  `scripts/vault-operation.sh` (the deployed `.claude/scripts/` copy briefly lagged the
  source-store edit). This is expected for any source-store-only edit before the next redeploy
  cycle; resolving it is `deploy-headless.sh`'s remit (explicitly restricted to
  `skill-orchestrate`'s own inter-cycle redeploy checkpoint), not a general-implementation-agent
  action, and it cleared on its own by the final Phase 8 verification run without this agent
  invoking that script.

## References

- Plan: `specs/969_extend_state_write_to_archive_and_vault_targets/plans/01_extend-state-write-archive-vault.md`
- Research report: `specs/969_extend_state_write_to_archive_and_vault_targets/reports/01_extend-state-write-archive-vault.md`
- `agent-system/extensions/core/context/patterns/task-lock.md` (State-Write Convention section)
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`
