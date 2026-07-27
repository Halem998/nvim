# Implementation Summary: Task #912

**Completed**: 2026-07-27
**Duration**: ~1 hour

## Overview

Landed all 5 phases of the plan. Repaired the dead-code `roadmap_items` drop in
`skill-lean-implementation-hard/SKILL.md`, made `skill-implementer-hard/SKILL.md`'s Stage 7a
cross-reference precise and self-contained, declared a justified `file_scope` expansion in
`specs/state.json`, and closed the confirmed root cause — three implementation agents that never
instructed generation of `completion_data` at all — by pointing each at the existing shared
schema doc rather than duplicating it.

## What Changed

- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — added the
  missing guarded `roadmap_items` jq write to Stage 7, mirroring the sibling non-hard lean skill
  (the variable was already extracted but never written).
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — replaced the imprecise
  "Same as `skill-implementer` Stage 7a" cross-reference (a stage that doesn't exist) with an
  inline restatement of the three concrete steps (`completion_summary` write, guarded
  `roadmap_items` write, `memory_candidates` append), citing the accurate `skill-implementer`
  Stage 7 Steps 2-4; also added the missing `roadmap_items` extraction at Stage 6, which the new
  Stage 7a block depends on. Incidentally fixed one pre-existing task-number citation in a nearby
  comment (Stage 5c skeleton-exhaustion routing) since the file was already open and the plan's
  final cross-file grep check covers the whole file.
- `specs/state.json` — declared the `file_scope` expansion for task 912, appending the three
  agent file paths ahead of any edit to them (audit trail records the widening at the moment it
  happened).
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — added a
  `completion_data` pointer to Stage 7's metadata field list. Incidentally fixed two pre-existing
  task-number citations elsewhere in the file (Stage 4.5's skeleton-preference note, and a
  checkpoint sub-section header) for the same reason as above.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — added a `## Context
  References` section (the file had none) pointing at the shared metadata schema, added the
  `completion_data` requirement to the verification-results instructions, and updated the
  "Recording Verification Results" JSON example so the concrete example an agent copies from
  includes the field.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — added a
  `completion_data` pointer to Stage 8's metadata field list (a `## Context References` entry for
  the shared schema already existed here, so only the field-list line was needed).

## Decisions

- Fix shape: a one-line pointer to `@.claude/context/formats/return-metadata-file.md` in each
  broken agent's own field enumeration, not schema duplication and not a new shared contract
  file — matching how the two working pairs (core, web) already avoid the bug.
- Pre-existing task-number citations found incidentally in files this task was already editing
  (2 in `general-implementation-hard-agent.md`, 1 in `skill-implementer-hard/SKILL.md`) were
  fixed with durable anchors rather than left in place, since the plan's own final verification
  step greps the whole of each of the five modified files for the no-task-references rule.
- `specs/state.json`/`specs/TODO.md` commits in this task legitimately carry sibling tasks'
  concurrently-in-progress index rows (per `git-staging-scope.md`'s documented contract for
  shared index files); the Phase 3 commit message notes this honestly ("Also carries current
  index rows for tasks: 910, 911") rather than treating it as a staging violation.

## Plan Deviations

- None (implementation followed plan). The two incidental task-number-citation fixups described
  above are cleanups within files already in scope, not deviations from the plan's task list —
  Phase 2's and Phase 4's own tasks explicitly required verifying no task-number citation
  remained in the touched files.

## Verification

- Build: N/A (documentation/skill-definition changes only)
- Tests: N/A
- Files verified: Yes — all `grep` checks in the plan's per-phase Verification sections and the
  plan-level Testing & Validation section were run and passed (see Cross-Matrix below and the
  constraint checks that follow).

### Cross-Matrix: agent-generates x skill-propagates completion_data / roadmap_items

| Path | Agent generates `completion_data`? | SKILL.md propagates `completion_summary`? | SKILL.md propagates `roadmap_items`? | Contract intact? |
|------|:---:|:---:|:---:|:---:|
| core (`skill-implementer` + `general-implementation-agent`) | Yes | Yes | Yes | Yes |
| core-hard (`skill-implementer-hard` + `general-implementation-hard-agent`) | Yes (fixed) | Yes | Yes (var now extracted, Step precisely referenced) | Yes |
| lean (`skill-lean-implementation` + `lean-implementation-agent`) | Yes (fixed) | Yes | Yes | Yes |
| lean-hard (`skill-lean-implementation-hard` + `lean-implementation-hard-agent`) | Yes (fixed) | Yes | Yes (fixed — was extracted but never written) | Yes |
| web (`skill-web-implementation` + `web-implementation-agent`) | Yes | Yes | Yes | Yes |

All five paths now satisfy both links of the producer/consumer contract.

### Constraint checks (all passed)

- `skill-implementer/SKILL.md`, `skill-lean-implementation/SKILL.md`,
  `skill-web-implementation/SKILL.md`: confirmed untouched by this task (`git diff --stat` empty
  for each across this task's commit range).
- `agent-system/extensions/core/merge-sources/claudemd.md`: confirmed untouched.
- `jq empty specs/state.json` succeeded after Phase 3; `file_scope` for task 912 has length 8.
- No task-number citation remains in any of the five modified non-`specs/**` files.
- `git diff --name-only` for this task's commits contains no path under `.claude/` (source-store
  rule honored throughout).
- `bash .claude/scripts/check-extension-docs.sh` exits 0. Its "core FAIL" summary line reflects
  pre-existing, unrelated deploy-drift advisories (scripts/extensions not yet synced to the
  gitignored `.claude/` deploy tree) — none of the flagged items are files this task touched, and
  none are new as of this task's edits.

## Follow-ups (recorded, not actioned)

1. **Mirror-image gap (out of scope, recommended follow-up)**: `nix`, `neovim`, and
   `epidemiology` implementers correctly generate `completion_data`, but their dispatching
   `SKILL.md` files never read it back into `state.json` — the inverse of the defect this task
   fixed. Different fix shape (SKILL.md-side propagation, not agent-side generation) and
   different files; warrants its own task.
2. **Shared postflight script extraction (lower priority)**: the `completion_data` propagation
   jq block is now duplicated identically across five `SKILL.md` files. Extracting it into a
   shared script under `agent-system/extensions/core/scripts/` would reduce duplication and
   drift risk, but is a refactor of already-working code, not a defect repair — deliberately not
   done here.
3. **Coordination note**: if the producer/consumer contract text in
   `agent-system/extensions/core/merge-sources/claudemd.md` needs updating to reflect the
   now-correct cross-matrix above, that edit is currently inside a concurrently-running sibling
   task's declared `file_scope` and must be sequenced behind that task's completion rather than
   made concurrently.
4. **Redeploy caveat**: these fixes take effect only once the extension source store
   (`agent-system/extensions/`) is redeployed to the gitignored `.claude/` runtime tree. This
   task does not perform that redeploy — it is a separate, user-run operator step.

## Notes

Phase 3's `state.json`/`TODO.md` commit legitimately carries the current index rows of two other
tasks that were mid-flight in the same working tree at commit time; this is documented in that
commit's message body per the shared-index-file staging contract rather than treated as scope
creep.
