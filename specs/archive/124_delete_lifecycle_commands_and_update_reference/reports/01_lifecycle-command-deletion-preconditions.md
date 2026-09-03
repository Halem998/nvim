# Research Report: Preconditions for Deleting /research, /plan, /implement

- **Task**: 124 - Delete /research, /plan, /implement commands and update the CLAUDE.md command reference
- **Started**: 2026-08-31T21:00:00Z
- **Completed**: 2026-08-31T21:35:00Z
- **Effort**: ~30 minutes
- **Dependencies**: Task 117, Task 68, Task 81
- **Sources/Inputs**:
  - `specs/TODO.md` (task 68, 81, 117, 118, 124, 125, 126 entries)
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - `agent-system/extensions/core/commands/orchestrate.md`
  - `agent-system/extensions/core/scripts/parse-command-args.sh`
  - `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A1, A2, A7)
- **Artifacts**:
  - This report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task's stated preconditions are only **partially** satisfied. Deletion must NOT proceed yet.
- Precondition (a) — Stage 3.5 Dispatch Prep rehome (memory retrieval + `--lit` resolution into `skill-orchestrate`) — is landed and verified in source, not just marked complete.
- Precondition (b) — the two named blocking defects (multi-task blocked-verdict discrimination; task-lock/session-registry heartbeat) — are both resolved (Task 68, Task 81, both `[COMPLETED]`).
- Precondition (c) — `/orchestrate` supporting `--research`/`--plan`/`--implement` phase-forcing flags as the replacement spelling — is **NOT satisfied**. No such flags exist anywhere in the current source store.
- The phase-forcing-flags work is tracked as Task 126 (`[NOT STARTED]`), which task 124 depends on in substance but does not currently list as a formal dependency.
- Recommendation: block task 124 (or rescope to defer the CLAUDE.md replacement-spelling documentation) until Task 126 lands.

## Context & Scope

Task 124 asks to delete `commands/research.md`, `commands/plan.md`, `commands/implement.md` and update `merge-sources/claudemd.md`'s Command Reference table to document `/orchestrate NNN --research/--plan/--implement` as the replacement spelling. The task's own preflight instructions name three preconditions to verify before any deletion work begins. This report verifies each precondition against the current state of the source store and task-tracking artifacts, and does not perform any deletion or documentation edits.

## Findings

### (a) Stage 3.5 Dispatch Prep rehome — LANDED

- Task 117 ("Build orchestrate dispatch prep stage") is `[COMPLETED]` in `specs/TODO.md` with research/plan/summary artifacts recorded.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` contains a full "Stage 3.5: Dispatch Prep (shared, runs immediately before every Agent dispatch)" section (~line 340) documented as "the SINGLE canonical copy of the memory-retrieval and literature-briefing procedure."
- The stage correctly consumes `clean_flag` (gating memory retrieval) and `lit_flag` (gating literature briefing) as independent flags, and calls `memory-retrieve.sh` with the phase-appropriate argument.
- Verified this stage is actually invoked, not merely defined: grepped for "Stage 3.5: Dispatch Prep" invocation sites in `SKILL.md` and found it referenced at the research dispatch (~lines 454, 501), plan dispatch (~lines 543, 589), and further sites — i.e. wired into both single-task and multi-task dispatch paths.

### (b) Two blocking defects — RESOLVED

- Task 68 ("Make the /orchestrate blocked verdict discriminating…") — `[COMPLETED]`, with research/plan/summary artifacts at `specs/068_discriminate_blocked_on_in_batch_predecessor/`.
- Task 81 ("Mechanize task-lock and session-registry heartbeat refresh…") — `[COMPLETED]`, with research/plan/summary artifacts at `specs/081_mechanize_task_lock_and_session_heartbeat_refresh/`.
- Both are already listed in task 124's own `Dependencies` field in `specs/TODO.md` (Task 117, Task 68, Task 81), and both show a completed resting state.

### (c) `/orchestrate` phase-forcing flags — NOT IMPLEMENTED

- Grepped `agent-system/extensions/core/commands/orchestrate.md`, `agent-system/extensions/core/scripts/parse-command-args.sh`, and `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` for the literal strings `--research`, `--plan`, `--implement`, and `force_phases`: **zero hits** across all three files.
- `orchestrate.md`'s current `## Options` table only documents `--lit`, `--clean`, effort/model flags, `--continue-budget`, `--allow-self-modifying`, and `--allow-scope-collision`. No phase-forcing flag exists today.
- This is exactly the scope of Task 126 ("Implement orchestrate phase forcing flags"), which is `[NOT STARTED]` in `specs/TODO.md` and depends on Task 117 (satisfied) and Task 122.
- Task 126's description matches task 124's stated requirement precisely: it proposes adding `--research`/`--plan`/`--implement` flags to `orchestrate.md`'s Options table and `parse-command-args.sh`, threading them as `force_phases` into `skill-orchestrate`'s Stage 1b/2 phase-resolution logic — none of which exists yet.

### Dependency-graph gap

- Task 124's `Dependencies` field in `specs/TODO.md` currently reads "Task 117, Task 68, Task 81" and does **not** include Task 126, despite task 124's own description stating the phase-forcing-flags task "requires... to have landed, or land in the same window" before the CLAUDE.md replacement-spelling documentation can be written accurately.

## Decisions

- No deletion or documentation edits were made. This report is verification-only, per the task's explicit precondition-check instruction.

## Recommendations

1. **Block task 124** (or move it to `[BLOCKED]`) pending Task 126 landing `--research`/`--plan`/`--implement` phase-forcing flags on `/orchestrate`. Deleting `commands/research.md`, `commands/plan.md`, `commands/implement.md` and publishing a Command Reference table that names a replacement spelling which does not yet exist would leave the documented entry point non-functional the moment it is published.
2. If the team elects to proceed with a partial execution instead of blocking outright, scope task 124 down to something that does not require the replacement-spelling row (e.g., leave the three commands and the reference table untouched, deferring the entire task) — a partial deletion without a working replacement is not a safe middle ground.
3. Add Task 126 as an explicit dependency of task 124 in `specs/TODO.md`, since the task description already treats it as a hard precondition in substance.
4. `commands/revise.md` correctly remains untouched under any of the above — its plan-revision-with-reason and description-update-fallback behaviors have no `/orchestrate` phase-flag equivalent.

## Risks & Mitigations

- **Risk**: Deleting the three commands before Task 126 lands leaves no working entry point for ad hoc phase re-runs (e.g., re-running research on an already-`[PLANNED]` task), a capability the standalone commands currently provide informally via direct invocation.
  - **Mitigation**: Do not delete until Task 126's flags are verified working end-to-end.
- **Risk**: If Task 126 lands with a different flag spelling or semantics than assumed here, the CLAUDE.md table drafted against today's assumption could be wrong.
  - **Mitigation**: Re-verify flag names/semantics against Task 126's actual implementation before writing the Command Reference table update, rather than relying on Task 126's current (not-yet-implemented) description.

## Appendix

- Search queries used: `grep -n -i "Stage 3.5\|Dispatch Prep\|memory.retriev\|memory-retrieve.sh\|lit_flag"` against `skill-orchestrate/SKILL.md`; `grep -n -- "--research\|--plan\|--implement\|force_phases"` against `parse-command-args.sh` and `SKILL.md`; `grep -n -i "research\b\|--plan\|--implement\|Options\|flag"` against `orchestrate.md`.
- Task references consulted: Task 68, Task 81, Task 117, Task 118, Task 122, Task 125, Task 126 (all in `specs/TODO.md`).
- Design reference: `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`, sections A1, A2, A7.
