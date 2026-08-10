# Implementation Summary: Task #1016

- **Task**: 1016 - Fix the register-bare/acquire-suffixed session-id pattern in research.md, plan.md, implement.md
- **Status**: [COMPLETED]
- **Started**: 2026-08-10T00:00:00Z
- **Completed**: 2026-08-10T18:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_register-acquire-parity-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Fixed a live defect in `commands/research.md`, `commands/plan.md`, and `commands/implement.md`:
each registered its multi-task batch session under the bare `$batch_session_id` but
acquired/released each per-task lock under `"${batch_session_id}_${task_num}"`. Because
`session_contention()`'s self-exclusion is an exact string match, every batch read its own
registration as foreign contention and refused every lock acquire. All five plan phases
completed in wave order `[[1,3],[2],[4],[5]]`.

## What Changed

- `agent-system/extensions/core/commands/research.md` — unified the `acquire-retry`/`release`
  call sites to the bare `$batch_session_id` (was `"${batch_session_id}_${task_num}"`); added an
  inline invariant note ported from `skill-orchestrate/SKILL.md` Stage MT-4; rewrote the Step 2
  rationalization sentence that previously defended the suffixed pattern as intentional.
- `agent-system/extensions/core/commands/plan.md` — same three changes.
- `agent-system/extensions/core/commands/implement.md` — same three changes, plus a new
  dispatch-args bullet in Step 3 (`session_id={batch_session_id}`, mirroring the single-task
  path's `session_id={SESSION_ID}` arg shape) and a rationale note explaining this is what makes
  `general-implementation-agent.md`'s Stage 4D dual heartbeat (`task-lock.sh heartbeat` +
  `task-lock.sh session-heartbeat`) resolve against live, matching records instead of degrading
  to silent no-ops; added a caveat clause to the pre-existing "No intra-batch session-registry
  heartbeat" note so it does not read as contradicting the new bullet.
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — added a one-line
  clarification above Stage 4's delegation-context JSON block stating that `session_id` is the
  value received in this skill's args, passed through verbatim, never regenerated at that stage
  (the block's `"sess_{timestamp}_{random}"` template is illustrative of shape only).
- `agent-system/extensions/core/context/patterns/task-lock.md` — rewrote the "Same-session
  bypass" bullet's now-false second half (previously claimed multi-task sessions are
  per-task-suffixed and therefore mutually enforced; now correctly states batches share one bare
  `session_id`, so same-batch siblings ARE bypassed by that check, and explains why that is not a
  hole — in-batch `file_scope` collisions are excluded earlier by
  `orchestrate-batch-admit.sh`'s Step 2.5 pre-check); added two-way cross-references between that
  bullet and the "Register/acquire parity invariant" paragraph; corrected Consumers item 2's
  stale pointer (previously named `skill-implementer/SKILL.md`'s "phase-transition point" as the
  heartbeat site, contradicting item 5's correct attribution to
  `agents/general-implementation-agent.md`'s Stage 4D — item 2 now matches item 5).
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` — added Group 9 cases 9.6,
  9.7, 9.8, siblings of the existing 9.5 static guard, one per command file
  (`research.md`/`plan.md`/`implement.md`), varying only the file path and the bad-pattern
  substring (`${batch_session_id}_${task_num}`); extended the Group 9 header comment; left cases
  9.1-9.5 byte-unchanged (confirmed via `git diff --stat`, additions-only plus the one
  header-comment-line replacement).
- `agent-system/extensions/core/index-entries.json` — corrected the `patterns/task-lock.md`
  entry's `line_count` from 1178 to 1191 (stale after this task's Phase 3 edit added 13 lines;
  confirmed via `git show` against the pre-Phase-3 commit that 1178 was exact before the edit).
- `specs/1016_fix_command_register_acquire_session_id_parity/plans/01_register-acquire-parity-fix.md`
  — all five phases checked off and marked `[COMPLETED]`.

## Decisions

- Ported `skill-orchestrate/SKILL.md` Stage MT-4's invariant-note wording near-verbatim into all
  three command files rather than writing new prose, per the plan's explicit instruction and to
  keep the reference pattern visually recognizable across all four files.
- The naive flat `grep -rnF '${batch_session_id}_${task_num}' agent-system/extensions/core/`
  sweep now returns 3 hits (one per command file) rather than the plan's literally-stated "zero
  hits" — these are the newly-added invariant notes' own descriptive mention of the bad pattern
  as an illustrative example of the failure mode, exactly mirroring
  `skill-orchestrate/SKILL.md`'s own reference invariant note at its line 1966 (which contains
  the identical self-referential mention and has always failed a similarly naive flat-grep
  "zero" expectation for that same reason, given its own downstream deliberately-suffixed
  bookkeeping identifiers). The actual regression guard — Group 9's `grep -nE
  'task-lock\.sh[[:space:]]+(acquire|release|heartbeat)' | grep -F '...'` ERE-scoped shape —
  correctly returns zero for all three files, confirmed directly and via the Phase 4 negative
  control.
- Fixed only the one in-scope `index-entries.json` line_count drift (`patterns/task-lock.md`,
  caused by this task's own Phase 3 edit) rather than running
  `generate-context-line-counts.sh --write` globally, which would also have rewritten an
  unrelated, pre-existing, out-of-scope entry (`schemas/state-schema.json`) that this plan never
  names and that may be mid-edit by concurrent, unrelated work in the same shared session.

## Plan Deviations

- **Task 2.5** (apply the same one-line `session_id` clarification to `skill-team-implement`)
  skipped as a reasoned exclusion: `skill-team-implement/SKILL.md` already declares `session_id`
  as a required input parameter (`| session_id | string | Yes | Session ID for tracking |`) and
  threads it through unchanged (`"$session_id"` / `"{session_id}"`) at every use site, with no
  generation-shaped template comparable to `skill-implementer/SKILL.md`'s old Stage 4 block — no
  clarification was warranted.

## Verification

- Build: N/A (documentation and shell-script changes only)
- Tests: Passed — `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh`: 32
  passed, 0 failed (includes new cases 9.6/9.7/9.8, all PASS; cases 9.1-9.5 unaffected). Phase 4's
  negative control (a mutated scratch copy of `research.md` under the session scratchpad,
  reinserting the bad substring into an `acquire-retry` line) confirmed the new 9.6 grep
  expression triggers correctly, proving the guard is not vacuous; the scratch copy was deleted
  afterward and the repo was never mutated for this control.
- Files verified: Yes — all edited files read back and confirmed via targeted `grep` after each
  edit.
- `bash .claude/scripts/check-task-references.sh`: PASS, 0 unexempted occurrences across all 4
  scanned trees, exit 0.
- `bash .claude/scripts/check-extension-docs.sh`: 3 remaining FAIL items after this task's own
  fix, all traced and none attributable to this task's scope: (1) "deployed script content
  drift: scripts/test-conflict-predicate.sh" is the expected, unavoidable consequence of editing
  the source-store script without deploying — the fix reaches `.claude/**` only via the next
  normal deploy/reload, which this plan deliberately does not perform or simulate; (2) "script
  file on disk NOT in provides.scripts: scripts/assess-repo-health.sh" predates this task,
  introduced by an already-committed, unrelated commit; (3) "index-entries.json entry
  'schemas/state-schema.json' line_count mismatch" also predates this task and touches a file
  this plan never names. A fourth finding that WAS in-scope — the `patterns/task-lock.md`
  line_count drift caused by this task's own Phase 3 edit — was fixed directly.
- `bash .claude/scripts/lint/lint-routing-wiring.sh`: 323 passed, 0 failed, exit 0.
- `bash .claude/scripts/lint/lint-agent-contracts.sh`: 33 passed, 0 warnings, 0 failed, exit 0.
- `git status --short`: confirmed zero `.claude/**` paths present.

## Impacts

- Multi-task `/research`, `/plan`, and `/implement` batches with a declared `file_scope` will no
  longer self-refuse every lock acquire against their own session-registry registration — this
  was a live, universal defect for any multi-task batch declaring `file_scope` on its tasks.
- `implement.md`'s multi-task path now threads a `session_id` value into each per-task dispatch
  that resolves against live records at `general-implementation-agent.md`'s Stage 4D heartbeat
  checkpoints, closing a previously-silent observability gap (heartbeat calls degrading to
  no-ops).
- `context/patterns/task-lock.md` no longer contains two passages instructing opposite things
  about multi-task session-id handling; a reader arriving at either the "Same-session bypass"
  bullet or the "Register/acquire parity invariant" paragraph is now routed to the other.
- `test-conflict-predicate.sh` Group 9 now guards against regression of this exact defect class
  in all three command files, not just `skill-orchestrate/SKILL.md`.

## Follow-ups

- The fix becomes live in the deployed `.claude/**` tree only after the next normal
  deploy/reload (`<leader>al` "Reload All"/"Regenerate", or `bash
  .claude/scripts/deploy-headless.sh`) — this task deliberately does not perform or simulate that
  deploy, per the SOURCE-STORE RULE.
- Two pre-existing, out-of-scope `check-extension-docs.sh` findings remain unresolved by design:
  `scripts/assess-repo-health.sh` not yet listed in `provides.scripts` (from an unrelated,
  already-committed task), and an `index-entries.json` line_count drift on
  `schemas/state-schema.json` (also unrelated to this task and possibly reflecting concurrent
  work elsewhere in the same shared session). Neither blocks this task's own definition of done.

## References

- `specs/1016_fix_command_register_acquire_session_id_parity/plans/01_register-acquire-parity-fix.md`
- `specs/1016_fix_command_register_acquire_session_id_parity/reports/01_register-acquire-session-id-parity.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (reference fix pattern, Stage
  MT-4)
