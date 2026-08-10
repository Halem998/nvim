# Implementation Summary: Task #595

- **Task**: 595 - refactor_research_plan_implement_commands
- **Status**: [COMPLETED]
- **Started**: 2026-05-22T00:00:00Z
- **Completed**: 2026-05-22T01:00:00Z
- **Effort**: 6 hours (estimated), 1 session
- **Dependencies**: Task 593 (completed), Task 594 (completed)
- **Artifacts**:
  - [specs/595_refactor_research_plan_implement_commands/plans/02_command-refactor-plan.md]
  - [specs/595_refactor_research_plan_implement_commands/summaries/02_command-refactor-summary.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

---

## Overview

Refactored the three core workflow commands (`research.md`, `plan.md`, `implement.md`) from 393/420/525 lines down to 191/202/207 lines by extracting the identical extension routing loop to `command-route-skill.sh`, removing redundant inline GATE OUT defensive checks already handled by `command-gate-out.sh`, and condensing verbose multi-task dispatch sections. Added `orchestrator_mode` support to all three core skills by adding `skill_write_orchestrator_handoff()` to `skill-base.sh` and integrating it into skill postflight stages, with `max_continuations=0` protection in `skill-implementer`.

## What Changed

- `.claude/scripts/command-route-skill.sh` — Created new script (~55 lines) that resolves task_type to skill_name via extension manifest lookup, with compound key support and default fallback
- `.claude/scripts/skill-base.sh` — Added `skill_write_orchestrator_handoff()` function (~90 lines with docs) and orchestrator mode header comments; 274 → 363 lines
- `.claude/commands/research.md` — Refactored; 393 → 191 lines (204-line reduction)
- `.claude/commands/plan.md` — Refactored; 420 → 202 lines (218-line reduction)
- `.claude/commands/implement.md` — Refactored; 525 → 207 lines (318-line reduction)
- `.claude/skills/skill-researcher/SKILL.md` — Added orchestrator_mode extraction and handoff call; 231 → 242 lines
- `.claude/skills/skill-planner/SKILL.md` — Added orchestrator_mode extraction and handoff call; 203 → 215 lines
- `.claude/skills/skill-implementer/SKILL.md` — Added orchestrator_mode extraction, max_continuations guard, and handoff call with partial continuation_context; 336 → 363 lines

## Decisions

- **Skill invocations stay inline**: Multi-task dispatch Skill tool calls cannot be extracted to bash scripts; only the validation logic was condensed in place
- **orchestrator_mode defaults to false**: All three command files pass `orchestrator_mode=false` explicitly; skill-orchestrate (task 596) will override this to `true` when dispatching
- **Continuation loop disabled in orchestrator mode**: `skill-implementer` sets `max_continuations=0` when `orchestrator_mode=true` so the orchestrator drives all retries rather than the inner skill loop
- **Handoff with continuation_context**: When implementer returns `partial` with a `handoff_path`, the orchestrator handoff includes a `continuation_context` object with the handoff path and phase counts
- **source semantics for command-route-skill.sh**: Script uses `source` (not execute) to export `SKILL_NAME` to the calling shell environment

## Plan Deviations

- **command-multi-dispatch.sh not created**: The plan explicitly listed this as a Non-Goal (research confirmed Skill tool calls cannot be in bash scripts). Multi-task dispatch was condensed inline instead.
- **Achieve size targets**: research.md at 191 lines (target ~178), plan.md at 202 lines (target ~178), implement.md at 207 lines (target ~202) — all within the acceptable 150-210 range, with slight overshoot due to inherent complexity of each command's required features

## Impacts

- **Net line reduction across commands**: ~740 lines removed (393+420+525 = 1338 → 191+202+207 = 600)
- **New scripts added**: command-route-skill.sh (~55L) + skill-base.sh additions (~90L) = ~145 lines added
- **Net reduction**: ~595 lines eliminated from the command/skill system
- **Extension compatibility**: nvim and nix extensions verified unaffected; routing still resolves correctly via manifest lookup
- **Backward compatible**: All command interfaces unchanged; only internal structure simplified
- **Tier 2 enforcement**: Commands now contain only routing-level controller logic with no agent-level context (Tier 3 content)

## Follow-ups

- **Task 596**: Implement `skill-orchestrate` which will use the `orchestrator_mode=true` flag and read `.orchestrator-handoff.json` files written by the skills
- **Task 598**: Context budget enforcement (next step in the four-tier model)
- **Task 599**: Add orchestrator_mode support to extension skills (skill-neovim-research, etc.)

## References

- `specs/595_refactor_research_plan_implement_commands/plans/02_command-refactor-plan.md`
- `specs/595_refactor_research_plan_implement_commands/reports/02_command-refactor-research.md`
- `specs/595_refactor_research_plan_implement_commands/reports/03_design-guidance.md`
- `.claude/docs/architecture/handoff-schema.md`
- `.claude/docs/architecture/architecture-spec.md`
