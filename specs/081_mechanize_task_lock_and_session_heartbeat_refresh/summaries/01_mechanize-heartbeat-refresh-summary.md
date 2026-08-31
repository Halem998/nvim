# Implementation Summary: Task #81

- **Task**: 81 - Mechanize task-lock and session-registry heartbeat refresh: liveness timestamps never advance during a multi-phase /implement run
- **Status**: [COMPLETED]
- **Started**: 2026-08-31T19:58:00Z
- **Completed**: 2026-08-31T20:35:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None declared. Cross-referenced project 73 (`correlate_subagent_postflight_hook_to_owning_session`) for the events.jsonl amendment; no `file_scope` overlap.
- **Artifacts**: plans/01_mechanize-heartbeat-refresh.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Mechanized the task-lock and session-registry heartbeat refresh so it fires unconditionally at
every phase transition, closing a defect where the prose-authored `task-lock.sh heartbeat` /
`session-heartbeat` calls in `general-implementation-agent.md`'s Stage 4D fired 0 times across 8
real phase transitions in the incident that triggered this task. The refresh now lives INSIDE
`update-phase-status.sh` itself — the one script proven to run 16/16 at every phase transition —
deriving `session_id` from the task's own `.lock/holder.json` rather than accepting it as a
required argument, so every existing 4-argument caller inherits the fix with zero changes of its
own. Alongside the core mechanization, this work added pid liveness to `holder.json` (hardening
`reap` and `acquire`'s stale-override against acting on a live process's lock), a distinct
`never_heartbeated` fingerprint on `check`/`reap` output, a full call-site survey closeout across
both implementation agents and the orchestrate skills, and a deterministic fixture test proving
the mechanism — plus a genuine live reproduction on this task's own real lock and session-registry
records once the change was deployed.

## What Changed

- `agent-system/extensions/core/scripts/update-phase-status.sh` — added
  `heartbeat_after_phase_transition()`, invoked once per call immediately after `plan_dir` is
  resolved (before both the "Phase N not found" exit and the idempotency early-exit). Derives
  `session_id` from `.lock/holder.json`; accepts an optional 5th positional `session_id` argument
  used only as an assertion (mismatch -> traced no-op, never a hard failure); resolves
  `task-lock.sh` via the deploy-tree-first / source-store-fallback pattern; invokes both
  `task-lock.sh heartbeat` and `session-heartbeat`, capturing stderr/exit status instead of
  discarding with `2>/dev/null`; appends one trace line per subcommand to
  `.agent-logs/heartbeat-trace.log`; the entire block is guarded to never affect stdout or exit
  code, and is skippable via `PHASE_HEARTBEAT_DISABLE=1`.
- `agent-system/extensions/core/scripts/task-lock.sh` — `write_holder()` now persists `pid` and
  `pid_source` (fresh-resolved on every `cmd_acquire` write path, preserved-not-re-resolved on
  `cmd_heartbeat`'s write path). `cmd_reap` and `cmd_acquire`'s stale-override both refuse to act
  against a lock whose recorded pid is confirmably alive (`kill -0`), falling back to today's
  timestamp-only behavior for legacy pid-less holders. `cmd_check` and `cmd_reap` output lines
  carry an appended `never_heartbeated=<true|false|unknown>` fingerprint
  (`acquired_at == heartbeat_at`), distinct from staleness itself.
- `agent-system/extensions/core/context/patterns/task-lock.md` — documented the `pid`/`pid_source`
  fields, the pid-liveness floor, the `never_heartbeated` fingerprint, and updated the Consumers
  section (items 2 and 5) to describe the two-layer heartbeat model (cycle-layer vs. the
  mechanized phase-layer) and the new `skill-orchestrate-hard` cycle-layer site.
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` (new) — 19-assertion
  fixture suite proving the mechanism against a real `holder.json` and a real session-registry
  entry with a backdated fixed timestamp (no `sleep`, no wall-clock race).
- `agent-system/extensions/core/scripts/tests/run-all.sh` — auto-discovers the new suite (glob
  match, no explicit registration line needed).
- `agent-system/extensions/core/manifest.json` — added `tests/test-phase-heartbeat.sh` to the
  scripts file list.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — deleted the two
  confirmed-never-firing heartbeat bash blocks from Stage 4D (the brace-placeholder
  `task-lock.sh heartbeat "{task_number}" "{session_id}"` form that carried the confirmed
  `printf "%03d" "{task_number}"` landmine), replaced with a non-executable mechanized-here note.
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — added a
  mechanized-here note at its own `update-phase-status.sh ... COMPLETED` call, closing the
  absent-caller gap via inheritance with zero new call sites.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — added the cycle-layer
  task-lock + session-registry heartbeat pair at Stage 3's loop-guard write, mirroring
  `skill-orchestrate/SKILL.md`'s own Stage 3 site exactly (shell-variable form).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — left its three existing
  call sites' code unchanged; added a note explaining they are the complementary cycle-layer
  heartbeat, still necessary because research/plan cycles have no phase transitions.
- `agent-system/extensions/core/commands/implement.md` — corrected the "no intra-batch
  session-registry heartbeat" deferral reasoning, which previously pointed at the
  never-firing Stage 4D prose; now points at the mechanized phase-layer site and states the
  deferral is sound *because* that refresh is now mechanically guaranteed.
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md` — repointed its heartbeat note
  from the retired Stage 4D prose to the mechanized site.
- `agent-system/extensions/core/index-entries.json` — corrected `patterns/task-lock.md`'s
  declared `line_count` (1191 -> 1247) after this task's own edits grew the file; a pre-existing
  doc-lint drift this task's own edits would otherwise have introduced.
- `specs/state.json` — appended (non-destructively, via a jq-based edit) a recorded amendment to
  project 73's description adding an acceptance criterion that its fix must be shown to correct
  event attribution in `specs/events.jsonl`, not merely marker selection.

## Decisions

- **Session_id is derived from `holder.json`, never threaded as a required argument** — the
  plan's core design decision, taken as given. A threaded argument would still need to be typed
  by the same agent prose already proven not to execute (0/8), and would re-open the confirmed
  `printf "%03d" "{task_number}"` brace-placeholder landmine. Deriving it instead means every
  existing 4-argument caller inherits the fix with zero changes, closing the
  `general-implementation-hard-agent.md` absent-caller gap for free.
- **The optional 5th argument is an assertion, not a requirement.** Supplying it and having it
  disagree with the derived value produces a `noop:session-mismatch` trace and skips the
  heartbeat rather than either failing or silently proceeding — a deliberate, cheap
  defense-in-depth against a caller that does know its own identity.
- **pid resolution differs by call path, not by chance**: `cmd_acquire`'s four write paths always
  freshly resolve a pid for the acquiring process; `cmd_heartbeat`'s single write path preserves
  the pid already on record, because a heartbeat (notably the new mechanized one) may fire from a
  different process than the one that originally acquired the lock — re-resolving there would
  silently rewrite the lock's recorded identity.
- **Pid-liveness is a floor, not a replacement, for the timestamp check.** Both `reap` and
  `acquire`'s stale-override still use the timestamp threshold as the primary staleness signal;
  a live pid only ever *refuses* an action the timestamp alone would have permitted, and a
  legacy pid-less holder falls through to unchanged prior behavior.
- **`never_heartbeated` reports `unknown`, not `false`, when there is no timestamp to compare** —
  `reap`'s missing/unparseable-holder.json fallback branch has no `acquired_at` at all; reporting
  `false` there would falsely claim the lock heartbeated normally.

## Plan Deviations

- None (implementation followed the plan). One test case originally scoped as "unresolvable task
  directory" (Phase 4, assertion group 5c) was implemented as a confirmation that the script's
  pre-existing exit-1 validation-error behavior for an unresolvable task directory is unchanged
  by the heartbeat mechanization (rather than asserting exit 0, since a missing task directory
  was never a "no-op that still succeeds" case even before this change) — this is a
  clarification of the assertion's exact shape, not a deviation from the plan's intent.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh`:
  19/19 assertions pass. `bash agent-system/extensions/core/scripts/tests/run-all.sh`
  (source-store mode): 57/57 suites pass, 0 regressions across every phase's incremental run.
  `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` against the
  real agent tree: 106 passed, 0 warnings, 0 failed.
- Files verified: Yes — every phase's changed files were read back and manually fixture-tested
  before commit (see each phase's progress file `manual_smoke_evidence`/`verification_evidence`).

## Call-Site Survey (Acceptance Criterion 5)

| Site | Status | Note |
|------|--------|------|
| `update-phase-status.sh` | **mechanized** | Derives `session_id` from `holder.json`; fires both heartbeats at every phase transition; traces every outcome. |
| `task-lock.sh` (`write_holder`/`cmd_reap`/`cmd_acquire`) | **fixed** | Pid liveness added; `reap` and `acquire`'s stale-override refuse to act on a live-pid lock. |
| `task-lock.sh` (`cmd_check`/`cmd_reap` output) | **fixed** | `never_heartbeated=<true\|false\|unknown>` fingerprint appended. |
| `general-implementation-agent.md` Stage 4D | **demonstrated non-firing (0/8) -> retired** | The two never-executed prose bash blocks were deleted and replaced with a mechanized-here note. |
| `general-implementation-hard-agent.md` | **absent-caller gap closed via inheritance** | No call site was ever added — the hard agent inherits the mechanized refresh for free. |
| `skill-orchestrate-hard/SKILL.md` Stage 3 | **fixed (absent-caller gap closed)** | Added the cycle-layer heartbeat pair, mirroring `skill-orchestrate/SKILL.md`'s Stage 3 site exactly. |
| `skill-orchestrate/SKILL.md` Stage 3 (3 sites) | **deliberately retained, documented** | Code left unchanged (correct shell-var form); noted as the complementary cycle-layer heartbeat, necessary because research/plan cycles have no phase transitions. |
| `implement.md` Step 3 | **deliberately absent, reasoning corrected** | "No intra-batch heartbeat" omission reasoning corrected to point at the now-mechanized phase-layer site. |
| `skill-implementer/SKILL.md` | **deliberately absent, documentation updated** | Thin wrapper has no phase-transition point of its own; note repointed to the mechanized site. |
| `specs/events.jsonl` cross-session attribution | **deferred to project 73** | Recorded amendment appended (criterion 8); no `hooks/**` file touched. |

## Mechanism Guarantee (Acceptance Criterion 3)

`update-phase-status.sh` is the single command an implementation agent must invoke to move a
phase heading — the transition is not representable any other way. The incident transcript
showed it invoked 16/16 while the adjacent prose heartbeat was invoked 0/8. Putting the refresh
*inside* that script means the only way to skip the heartbeat is to skip the phase transition
itself — stated in the script's own header comment, and mechanically enforced by every existing
4-argument caller inheriting the behavior with no code change of its own.

## Reproduction Evidence (Acceptance Criteria 1-2)

**Deterministic fixture (load-bearing evidence)**: `test-phase-heartbeat.sh` demonstrates, against
a real `holder.json` and a real session-registry entry with a backdated fixed timestamp,
`heartbeat_at` strictly greater than `acquired_at`/`started_at` after one phase transition, and
monotonically non-decreasing (and still `> acquired_at`) after a second consecutive transition —
19/19 assertions pass with no `sleep` and no wall-clock race.

**Live corroboration (obtained, not merely attempted)**: after deploying the source-store changes
to the working `.claude/` tree (Phase 7), this task's own real
`specs/081_mechanize_task_lock_and_session_heartbeat_refresh/.lock/holder.json` and
`specs/.sessions/sess_1788202255_53c3de.json` were sampled before and after a real phase-status
transition on this same task:

| Field | Before | After |
|-------|--------|-------|
| `holder.json` `acquired_at` | `2026-08-31T19:58:56Z` | `2026-08-31T19:58:56Z` (unchanged) |
| `holder.json` `heartbeat_at` | `2026-08-31T19:58:56Z` | `2026-08-31T20:30:26Z` |
| session entry `started_at` | `2026-08-31T18:51:11Z` | `2026-08-31T18:51:11Z` (unchanged) |
| session entry `heartbeat_at` | `2026-08-31T19:58:42Z` | `2026-08-31T20:30:26Z` |

Both `.agent-logs/heartbeat-trace.log` lines for this transition read `ok` with
`sid_source=derived`. This is a full, not partial, live observation — the deploy landed before
this phase's own transitions, so no honesty caveat about partial coverage is needed here.

## Impacts

- Every existing single-task `/implement` run now genuinely refreshes both the task lock and the
  session-registry entry at every phase transition, closing the latent hazard the incident
  surfaced (a multi-hour run's lock going stale under its own hand, or being wrongly reaped).
- The reaper (`reap`) and `acquire`'s stale-override are now defended against acting on a lock
  whose holder process is confirmably still alive, independent of the heartbeat fix.
- Diagnostic tooling (`check`, `reap --dry-run`) can now distinguish "never heartbeated once" from
  "heartbeated normally, then went quiet" at a glance.
- Project 73's eventual fix now carries an explicit, cited acceptance criterion requiring it to
  demonstrate corrected event attribution, not just corrected marker selection.

## Follow-ups

- Optional context-extension recommendation from the research report (not authored under this
  task, per its own explicit scope boundary): a `context/patterns/` or `context/standards/` note
  on when a behavior MUST be mechanized (inside a script proven to run at every relevant
  transition) versus when agent prose remains acceptable, citing this task as a worked example.
- Three pre-existing, unrelated doc-lint findings were observed during Phase 7's deploy/verify
  pass and are explicitly OUT of this task's scope (not touched, not fixed here): `scripts/test-
  state-write-large-payload.sh` and `scripts/tests/test-roadmap-argv-ceiling.sh` missing from
  `provides.scripts`, and a stale `line_count` on the `lean` extension's
  `multi-instance-optimization.md` index entry. None overlap this task's `file_scope`.
- `validate-state.sh --deep` reports two pre-existing, unrelated schema findings (`abandon_reason`
  on project_numbers 64/115, `blocks_note` on project_numbers 106/107/109) — confirmed via `git
  show HEAD:specs/state.json` to predate this task's own commits; out of scope here.
- Project 73's own fix (marker-correlation, event-attribution) remains not_started; this task
  only recorded the amendment, per its own scope boundary against `hooks/**`.

## References

- `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/plans/01_mechanize-heartbeat-refresh.md`
- `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/reports/01_heartbeat-non-execution-root-cause.md`
- `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/progress/phase-{1..7}-progress.json`
- `agent-system/extensions/core/context/patterns/task-lock.md`
