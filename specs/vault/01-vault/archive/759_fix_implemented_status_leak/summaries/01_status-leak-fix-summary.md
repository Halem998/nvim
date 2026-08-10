# Implementation Summary: Task #759

**Completed**: 2026-06-23
**Duration**: 15 minutes

## Overview

Fixed 6 sites across 4 logical changes where the agent return value `"implemented"` leaked into state.json and TODO.md as a raw status instead of being normalized to `"completed"`. The fixes cover skill documentation, defensive scripting, and command routing.

## What Changed

- `.claude/skills/skill-status-sync/SKILL.md` — Status Mapping table row changed from `implemented | [IMPLEMENTED]` to `completed | [COMPLETED]`
- `.claude/extensions/core/skills/skill-status-sync/SKILL.md` — Same table fix in extension mirror
- `.claude/scripts/generate-todo.sh` — Added `implemented) printf '%s' "COMPLETED" ;;` defensive case in `format_status()` between `expanded` and `pr_ready` cases
- `.claude/skills/skill-orchestrate/SKILL.md` — Split single `--arg status "implemented"` metadata write block (Stage 8) into two blocks: clean exit uses `--arg status "completed"`, partial exit uses `--arg status "partial"`
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` — Same Stage 8 split in extension mirror
- `.claude/scripts/command-gate-out.sh` — Added `[ "$skill_status" = "completed" ]` to the match condition on line 64-65 for backward compatibility after skill-orchestrate now emits "completed" instead of "implemented"

## Decisions

- Kept `[ "$skill_status" = "implemented" ]` in command-gate-out.sh match condition alongside the new `"completed"` check for backward compatibility with any other agents still returning "implemented"
- Did not fix multi-task mode `exit_status="implemented"` at line 1201 of skill-orchestrate/SKILL.md — this was not in the plan's fix sites and the research report did not identify it as a bug site

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: `bash .claude/scripts/generate-todo.sh` — Success
- Files verified: Yes
  - Fix 1a/1b: `grep -n "implemented" *skill-status-sync/SKILL.md | grep "IMPLEMENTED"` returns no matches
  - Fix 2: `grep -c 'implemented.*COMPLETED' generate-todo.sh` returns 1
  - Fix 3a: `grep -c '"implemented"' skill-orchestrate/SKILL.md` returns 2 (both in non-metadata-write sections: dispatch check at line 471 and multi-task exit_status at line 1201)
  - Fix 3b: `grep -c '"implemented"' extensions/core/skills/skill-orchestrate/SKILL.md` returns 1 (multi-task exit_status only)
  - Fix 4: `grep -c '"completed"' command-gate-out.sh` returns 3

## Notes

The two remaining `"implemented"` occurrences in skill-orchestrate (line 471: dispatch status check for commit decisions; line 1201: multi-task mode exit_status) were intentionally not changed. Line 471 reads the agent's raw return value to decide if a commit is needed — this is a valid use. Line 1201 sets exit_status for multi-task mode and was not included in the plan's fix sites. A follow-up task may address the multi-task mode leak if it manifests.
