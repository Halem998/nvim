# Implementation Summary: Task #795

**Completed**: 2026-07-04
**Duration**: ~40 minutes

## Overview

Reserved the `[PR READY]`/`pr_ready` status transition for `task_type == "pr"` tasks only,
closing the lifecycle leak where non-pr (e.g. cslib) implementation tasks could land on
`[PR READY]` instead of `[COMPLETED]`. Implemented as four coordinated edits: a runtime guard
in `update-task-status.sh` with an explicit `--allow-pr-ready` override, a companion edit at
the one legitimate task-type-agnostic caller (`skill-orchestrate-hard`'s skeleton-exhaustion
branch), an explicit `postflight ... implement` call in `skill-cslib-implementation` Stage 6
(the actual root-cause of the leak), and a documentation reconciliation scoping `[PR READY]`
to `type=pr` in both the `claudemd.md` merge-source and the deployed `.claude/CLAUDE.md`.

## What Changed

- `.claude/scripts/update-task-status.sh` — Added `ALLOW_PR_READY` flag parsing
  (`--allow-pr-ready`), a `task_type` jq lookup mirroring the existing `project_name` lookup
  pattern, a guard rejecting `pr_ready` transitions for any task whose `task_type != "pr"`
  unless the override flag is passed (implemented with `==`-only equality checks, no `!=`, per
  the jq Issue #1132 mitigation), and updated usage/comment documentation.
- `.claude/extensions/core/scripts/update-task-status.sh` — Identical mirror edit (separate
  file, not a symlink); verified byte-identical via `diff -q`.
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — Appended `--allow-pr-ready` to the
  skeleton-exhaustion `postflight pr_ready` call site (line ~431) plus an explanatory comment
  noting why the override is required.
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Identical mirror edit
  (separate file, not a symlink); verified byte-identical via `diff -q`.
- `.claude/skills/skill-cslib-implementation/SKILL.md` — Replaced the vague Stage 6 body
  ("Update state.json and TODO.md based on result.") with an explicit, status-gated
  `bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"`
  call plus a partial-resume comment, mirroring the hard sibling's Stage 7. No `pr_ready` call
  introduced. Note: this file is a **symlink** to
  `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`, so the single edit
  updated both locations automatically.
- `.claude/extensions/core/merge-sources/claudemd.md` — Replaced the two-line status-marker
  block with a three-line version: a standard `[IMPLEMENTING] -> [COMPLETED]` terminus for all
  non-pr task types, plus `type=pr`-only `[IMPLEMENTING] -> [PR READY] -> [COMPLETED]` and
  `type=pr`-only re-dispatch lines.
- `.claude/CLAUDE.md` — Applied the identical status-marker edit directly (deployed mirror),
  since no automatable claudemd.md -> CLAUDE.md regeneration script exists (confirmed by
  inspecting `.claude/scripts/install-extension.sh`, which only merges context index.json
  entries, not CLAUDE.md prose). This follows the plan's documented fallback.

## Decisions

- Placed the `task_type` lookup and guard immediately after the existing task-exists check
  (before the idempotency check), since that is the earliest point at which `task_number` is
  confirmed valid and `target_status` has already been validated.
- Implemented the guard as three `==`-only if/elif branches (pr-type allowed; override-flag
  allowed; otherwise reject) rather than a single `!=` condition, per the plan's explicit
  Issue #1132 mitigation requirement.
- Confirmed no automatable `claudemd.md` -> `.claude/CLAUDE.md` regeneration path exists and
  used the plan's sanctioned fallback (direct dual-edit) rather than inventing a new build step.
- Discovered during Phase 3 that `skill-cslib-implementation/SKILL.md` is a symlink to its
  extension-source counterpart, so only one edit was required there (still verified with
  `diff -q` for parity with the other, non-symlinked mirror pairs).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts + markdown skill docs, no build step)
- Tests: Passed — ran all plan-specified verification scenarios in an isolated sandbox
  (`specs/state.json` never touched):
  - Non-pr task + `pr_ready` (no flag) -> rejected, exit 1, clear stderr error.
  - Non-pr task + `pr_ready` + `--allow-pr-ready` -> accepted (dry-run no-op path reached).
  - `type=pr` task + `pr_ready` (no flag) -> accepted.
  - Non-pr task + `implement` (unaffected transition) -> accepted, unchanged behavior.
  - Simulated exact orchestrate-hard skeleton-exhaustion command line (`postflight ... pr_ready
    ... --allow-pr-ready`) against a non-pr task -> accepted.
  - `grep` confirms `skill-cslib-implementation/SKILL.md` Stage 6 calls
    `postflight ... implement` and contains no `pr_ready`.
  - Status-marker lines in `claudemd.md` merge-source and deployed `.claude/CLAUDE.md` compared
    directly -- identical.
- Files verified: Yes — all four mirror pairs confirmed byte-identical via `diff -q`
  (`update-task-status.sh` x2 real files, `skill-orchestrate-hard/SKILL.md` x2 real files,
  `skill-cslib-implementation/SKILL.md` symlink pair).

## Notes

- `bash -n` syntax check passed on the modified `update-task-status.sh`.
- Out of scope per plan: the 5 already-mislabeled deployed cslib tasks (447/404/407/438/453) in
  `~/Projects/cslib` were not touched; the stale `pr-prohibition.md` "Required Behavior" section
  reconciliation was also left as a flagged follow-up, not addressed here.
