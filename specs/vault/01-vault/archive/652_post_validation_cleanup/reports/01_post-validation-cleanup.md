# Research Report: Task #652

**Task**: 652 - Post-validation cleanup: remove obsolete scripts after logging review
**Started**: 2026-06-15T03:44:36Z
**Completed**: 2026-06-16T04:00:00Z
**Effort**: ~1 hour
**Dependencies**: Task 649 (completed), Task 648 (completed)
**Sources/Inputs**: Codebase audit, git history, deprecation log inspection, pipeline audit report
**Artifacts**: specs/652_post_validation_cleanup/reports/01_post-validation-cleanup.md
**Standards**: report-format.md

---

## Executive Summary

- `link-artifact-todo.sh` is still referenced by `reconcile-task-status.sh` and listed in `extensions.json` — it cannot be deleted until `reconcile-task-status.sh` is updated to call `generate-todo.sh` instead
- `update-task-status.sh` still has old awk/sed TODO.md manipulation code (Phases 2+3) — the PIPELINE_MODE guard added by task 649 was reverted in the "update" commit (714b3a5b6); the cleanup must re-implement this removal
- No `deprecation.log` file exists: the planned deprecation logging was never written because `update-task-status.sh` was reverted; `reconcile-task-status.sh` does attempt to write to it but the file was never created
- The `generate-todo.sh` pipeline is working reliably (1124+ successful log entries, no errors except one deliberate test with `/nonexistent.json`)
- `skill-base.sh`, `skill-reviser/SKILL.md`, and all core skills already use `generate-todo.sh` (the critical skill-side changes survived the revert)
- `postflight-*.sh` scripts are not called by any current skill or command and are candidates for removal

---

## Context & Scope

Task 652 is the post-validation cleanup deferred from the task 649 orchestration batch. The intent was to wait ~1 week after the new `generate-todo.sh` pipeline was deployed, verify it via deprecation logs, and then remove dead code.

The pipeline has been running since 2026-06-10. This report covers:
1. Log review findings
2. Reference audit for each removal candidate
3. Safety verdict for each candidate
4. A complication: `update-task-status.sh` task-649 changes were reverted

---

## Findings

### 1. Log Review

**generate-todo.log**: 1124 lines, 5+ days of successful operation.
- All runs show `OK tasks=N elapsed=Ns WROTE /path/TODO.md`
- One expected error: `ERROR state.json not found at /nonexistent.json` (deliberate test)
- Zero unexpected errors or failures

**deprecation.log**: Does not exist at `.claude/logs/deprecation.log`.
- The `update-task-status.sh` PIPELINE_MODE guard (which would have written this log) was removed in commit 714b3a5b6 ("update")
- `reconcile-task-status.sh` attempts to write to this log but has never been triggered (no tasks were stuck in a recoverable state during the validation window)
- `link-artifact-todo.sh` was supposed to log on invocation (per task 649 summary) but looking at the current file it has no logging code — this means the deprecation logging additions were also reverted

**sessions.log / subagent-postflight.log**: No deprecation entries found.

**Conclusion**: No deprecation hits were recorded because the mechanism was reverted. However, we can audit by reference inspection instead.

### 2. generate-todo.sh Pipeline Verification

The pipeline is working correctly. All active skills call `generate-todo.sh` after updating state.json:
- `skill-base.sh:364` — `skill_link_artifacts()` calls `generate-todo.sh`
- `skill-researcher/SKILL.md:404` — calls `generate-todo.sh`
- `skill-planner/SKILL.md:400` — calls `generate-todo.sh`
- `skill-implementer/SKILL.md:545` — calls `generate-todo.sh`
- `skill-reviser/SKILL.md:382` — calls `generate-todo.sh`
- `skill-team-research/SKILL.md:500`, `skill-team-plan/SKILL.md:474`, `skill-team-implement/SKILL.md:501` — all call `generate-todo.sh`
- `skill-fix-it/SKILL.md:544`, `skill-spawn/SKILL.md:434`, `skill-project-overview/SKILL.md:425` — all call `generate-todo.sh`

State.json/TODO.md are in sync: 3 active tasks in both state.json and TODO.md (652, 87, 78).

### 3. Reference Audit: link-artifact-todo.sh

**All references found:**
1. `.claude/scripts/reconcile-task-status.sh:156` — dry-run call
2. `.claude/scripts/reconcile-task-status.sh:161` — live call (DEPRECATED comment, but still calls it)
3. `.claude/extensions.json:312` — listed as a provides.scripts artifact
4. `.claude/scripts/skill-base.sh:363` — comment only (actual call is now `generate-todo.sh`)
5. `.claude/rules/artifact-formats.md` — mention of deprecated status
6. `.claude/context/patterns/artifact-linking-todo.md` — deprecation notice and reference documentation
7. `.claude/docs/architecture/architecture-spec.md:202` — historical reference
8. `.claude/extensions/core/` — mirror copies of all the above

**Verdict: NEEDS RECONCILE-TASK-STATUS.SH UPDATE FIRST**

`link-artifact-todo.sh` cannot be deleted until `reconcile-task-status.sh` is updated to use `generate-todo.sh` for the TODO.md step. The script has a well-marked DEPRECATED comment (added in task 649) but still calls the old script.

After `reconcile-task-status.sh` is updated:
- Remove `.claude/scripts/link-artifact-todo.sh`
- Remove `.claude/extensions/core/scripts/link-artifact-todo.sh`
- Remove from `.claude/extensions.json` provides.scripts list (line 312)
- Update `.claude/extensions/core/manifest.json` similarly
- The doc references (artifact-formats.md, artifact-linking-todo.md, architecture-spec.md) should be updated to remove the deprecated mention entirely

### 4. Reference Audit: Old awk/sed Code in update-task-status.sh

The task 649 implementation added a `PIPELINE_MODE` guard to `update-task-status.sh` that wrapped Phases 2 and 3 (awk/sed TODO.md surgery) in a `PIPELINE_MODE=legacy` block. However, commit 714b3a5b6 ("update") reverted `update-task-status.sh` to the pre-649 version.

**Current state**: `update-task-status.sh` (343 lines) still has:
- `update_todo_task_entry()` — sed-based status update on TODO.md task entry (lines ~187-235)
- `update_todo_task_order()` — sed-based status update on TODO.md Task Order section (lines ~239-273)
- Both are called unconditionally (no PIPELINE_MODE guard)

**Impact**: Every call to `update-task-status.sh` (from `skill_preflight_update` and `skill_postflight_update` in skill-base.sh) does BOTH:
1. Updates state.json (correct)
2. Runs sed on TODO.md task entry and Task Order (legacy, redundant with generate-todo.sh)
3. Calls update-plan-status.sh (correct)

The sed calls are redundant because `skill_postflight_update` is followed by `skill_link_artifacts` which calls `generate-todo.sh` and overwrites everything. But they are NOT harmful — they just do extra work.

**Verdict: NEEDS RE-IMPLEMENTATION OF TASK 649 CHANGES**

The cleanup requires re-adding the PIPELINE_MODE guard (or simply removing Phases 2+3 directly since the pipeline is now validated). Since `generate-todo.sh` is confirmed working, direct removal of Phases 2+3 is now appropriate.

**What to remove from update-task-status.sh:**
- `update_todo_task_entry()` function (lines 187-235)
- `update_todo_task_order()` function (lines 239-273)
- The calls to these functions and `todo_failed` variable (lines 319-337)
- `exit 3` branch for TODO.md failures (line 334)
- `TODO_FILE` variable (no longer needed after removal)
- `TMP_DIR` variable (may still be needed for state.json.tmp — keep if so)

**Important**: The CLAUDE.md claims "The `update-task-status.sh` script calls `generate-todo.sh` internally" — this is currently FALSE. The cleanup must make it TRUE (by having the script call `generate-todo.sh`) or update CLAUDE.md to reflect that skills call it separately.

### 5. Reference Audit: Dead Functions in skill-base.sh

**Examination**: `skill-base.sh` has no dead functions. All public functions are called:
- `skill_validate_input` — called by all skills
- `skill_preflight_update` — called by all skills
- `skill_create_postflight_marker` — called by skills
- `skill_context_injection` — called by skills with extension hooks
- `skill_read_artifact_number` — called by skills
- `skill_read_metadata` — called by skills
- `skill_validate_artifact` — called by skills
- `skill_postflight_update` — called by all skills
- `skill_increment_artifact_number` — called by researcher skills
- `skill_propagate_memory_candidates` — called by skills
- `skill_link_artifacts` — called by skills (now calls generate-todo.sh)
- `skill_cleanup` — called by skills
- `skill_write_orchestrator_handoff` — called by orchestrator-mode skills

**Verdict: NO DEAD FUNCTIONS IN skill-base.sh**

The pipeline audit report (S9) mentioned that `skill-base.sh skill_link_artifacts()` called `link-artifact-todo.sh` — but this was already fixed in task 649 (survied the revert). The current `skill_link_artifacts()` function at line 363-364 correctly calls `generate-todo.sh`.

### 6. Transitional Compatibility Shims

**postflight-*.sh scripts**: The three thin wrapper scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`) and `postflight-workflow.sh` are not called by any current skill, command, or agent. They only appear in:
- `extensions.json` provides.scripts list
- Their own file headers
- `jq-escaping-workarounds.md` context document (as examples)
- `architecture-spec.md` (historical documentation)

These scripts predate the skill-base.sh unification. Skills now call `update-task-status.sh` via `skill_preflight_update` / `skill_postflight_update`. The postflight scripts are orphaned.

**Verdict: SAFE TO REMOVE (after updating docs)**
- Remove `.claude/scripts/postflight-research.sh`
- Remove `.claude/scripts/postflight-plan.sh`
- Remove `.claude/scripts/postflight-implement.sh`
- Remove `.claude/scripts/postflight-workflow.sh`
- Remove from `.claude/extensions.json` provides.scripts list
- Update `.claude/context/patterns/jq-escaping-workarounds.md` example (line 248-254)
- Update `.claude/docs/architecture/architecture-spec.md` references

---

## Decisions

1. **No deprecation log exists** — the planned monitoring mechanism was reverted; reference inspection is the valid alternative
2. **update-task-status.sh cleanup requires manual re-implementation** — the task 649 changes were reverted and must be re-applied (or simplified further)
3. **link-artifact-todo.sh removal requires reconcile-task-status.sh update first** — one remaining caller prevents safe deletion
4. **skill-base.sh has no dead functions** — no cleanup needed there
5. **postflight-*.sh scripts are orphaned** — safe to remove after documentation updates

---

## Risks & Mitigations

- **Risk**: Removing Phases 2+3 from `update-task-status.sh` could break things if some callers depend on the sed behavior for edge cases
  - **Mitigation**: The `generate-todo.sh` pipeline has been running successfully for 5+ days and regenerates the entire file from state.json; the sed operations are strictly redundant
  
- **Risk**: `reconcile-task-status.sh` is a recovery tool that may be needed in future crashes; if we call `generate-todo.sh` instead of `link-artifact-todo.sh` in it, the behavior changes
  - **Mitigation**: The change is a straightforward substitution — instead of awk/sed surgery on individual lines, we regenerate the full file; the outcome is the same (artifact appears in TODO.md) and the new approach is more robust

- **Risk**: Removing `postflight-*.sh` scripts could break something that calls them
  - **Mitigation**: Grep confirmed zero callers in skills, commands, and agents; only documentation references exist

---

## Categorized Removal Verdicts

### Safe to Remove (after prerequisite changes)

| Item | Prerequisite | Notes |
|------|-------------|-------|
| `.claude/scripts/link-artifact-todo.sh` | Update reconcile-task-status.sh first | Referenced by reconcile-task-status.sh |
| `.claude/extensions/core/scripts/link-artifact-todo.sh` | Same as above | Mirror copy |
| `.claude/scripts/postflight-research.sh` | Update docs | No callers |
| `.claude/scripts/postflight-plan.sh` | Update docs | No callers |
| `.claude/scripts/postflight-implement.sh` | Update docs | No callers |
| `.claude/scripts/postflight-workflow.sh` | Update docs | No callers |
| `.claude/extensions/core/scripts/postflight-*.sh` | Same as above | Mirror copies |

### Needs Code Change (not pure deletion)

| Item | Change Required |
|------|----------------|
| `.claude/scripts/update-task-status.sh` | Remove Phase 2+3 awk/sed functions; add generate-todo.sh call |
| `.claude/extensions/core/scripts/update-task-status.sh` | Same (mirror) |
| `.claude/scripts/reconcile-task-status.sh` | Replace link-artifact-todo.sh call with generate-todo.sh |
| `.claude/extensions/core/scripts/reconcile-task-status.sh` | Same (mirror) |

### Needs Documentation Update

| Item | Change Required |
|------|----------------|
| `.claude/extensions.json` | Remove link-artifact-todo.sh and postflight-*.sh from provides.scripts |
| `.claude/extensions/core/manifest.json` | Same |
| `.claude/context/patterns/artifact-linking-todo.md` | Remove deprecated doc (or note that script is deleted) |
| `.claude/docs/architecture/architecture-spec.md` | Update references |
| `.claude/context/patterns/jq-escaping-workarounds.md` | Update examples |

### Must Keep

| Item | Reason |
|------|--------|
| `.claude/scripts/update-task-status.sh` | Active, called by skill-base.sh — keep but clean up |
| `.claude/scripts/reconcile-task-status.sh` | Active recovery tool — keep but update internals |
| `.claude/scripts/skill-base.sh` | Active, no dead code |
| `.claude/scripts/generate-todo.sh` | The new pipeline — must keep |

---

## Context Extension Recommendations

- **Topic**: update-task-status.sh pipeline mode
- **Gap**: CLAUDE.md claims the script calls `generate-todo.sh` internally, but it does not — the PIPELINE_MODE changes from task 649 were reverted
- **Recommendation**: Either update CLAUDE.md to be accurate, or (preferably) fix the script to actually call `generate-todo.sh` and make CLAUDE.md accurate

---

## Appendix

### Search Queries Used
- `grep -r "link-artifact-todo" .claude/`
- `grep -r "reconcile-task-status" .claude/`
- `grep -n "PIPELINE_MODE\|regenerate_todo\|log_deprecation" .claude/scripts/update-task-status.sh`
- `git show 714b3a5b6 -- .claude/scripts/update-task-status.sh`
- `wc -l .claude/logs/generate-todo.log`
- Pipeline audit report: `specs/audit_pipeline_integrity/pipeline-audit-report.md`

### Key Commits
- `365ab245c` — orchestrate tasks 647-653 (task 649 changes applied)
- `714b3a5b6` — "update" (reverted update-task-status.sh to pre-649 state)

### Validation Window
- generate-todo.sh deployed: 2026-06-10
- First log entry: `2026-06-10T22:57:23Z`
- Report date: 2026-06-16
- Duration: ~5.5 days, 1124 log lines (all successful)
