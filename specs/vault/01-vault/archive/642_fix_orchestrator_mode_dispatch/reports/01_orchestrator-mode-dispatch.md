# Research Report: Task #642

**Task**: 642 - Fix orchestrator_mode=false for research/plan dispatch in skill-orchestrate/SKILL.md
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:10:00Z
**Effort**: ~15 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-base.sh, handoff-schema.md, orchestrate-state-machine.md)
**Artifacts**: specs/642_fix_orchestrator_mode_dispatch/reports/01_orchestrator-mode-dispatch.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The orchestrator dispatches research and planning agents with `orchestrator_mode: false`, which means those agents never write `.orchestrator-handoff.json`
- Stage 5 of skill-orchestrate explicitly checks for the handoff file and emits an error if it is missing — yet the dispatch context for `not_started` (line 208) and `researched` (line 240) both hardcode `false`
- The fix is surgical: change `"orchestrator_mode": false` to `"orchestrator_mode": true` in those two dispatch contexts inside `skill-orchestrate/SKILL.md`, plus in the multi-task equivalents at lines 934 and 959
- Both `skill-researcher` (Stage 7, line 157) and `skill-planner` (Stage 7, line 151) already call `skill_write_orchestrator_handoff` and pass through the `orchestrator_mode` value — they just need `true` to be passed in
- No side effects: neither skill does anything differently for `orchestrator_mode=true` that would be harmful (no inner continuation loop, no state changes — just an extra JSON file written at postflight)

---

## Context & Scope

The orchestrator state machine (skill-orchestrate/SKILL.md) drives a task through its lifecycle: research -> plan -> implement -> complete. After each Agent tool invocation, Stage 5 reads `.orchestrator-handoff.json` to learn the dispatch outcome (status, artifacts, blockers). Without the handoff, the orchestrator logs an error but continues based on state.json alone — it cannot read `next_action_hint`, artifact paths, or continuation context from research/plan phases. This causes the postflight chain to degrade: artifact linking (Stage 5 lines 405-425) is skipped for research and plan results.

---

## Findings

### Codebase Patterns

#### File: `.claude/skills/skill-orchestrate/SKILL.md`

**Location 1 — `not_started` state handler (single-task mode)**
- Line 208: `'{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": false}'`
- This is the research dispatch context for state `not_started` or `not started`
- Current value: `"orchestrator_mode": false`
- Required value: `"orchestrator_mode": true`

**Location 2 — `researched` state handler (single-task mode)**
- Line 240: `'{"task_number": N, "task_type": "T", "session_id": "S", "research_artifacts": [...], "orchestrator_mode": false}'`
- This is the planning dispatch context for state `researched`
- Current value: `"orchestrator_mode": false`
- Required value: `"orchestrator_mode": true`

**Location 3 — Multi-task research dispatch (Stage MT-4)**
- Line 934: `'{"task_number": $num, "task_type": $task_type, "session_id": $session_id, "orchestrator_mode": false}'`
- Multi-task mode research dispatch (inside the `for task_num in "${research_tasks[@]}"` loop)
- Current value: `"orchestrator_mode": false`
- Required value: `"orchestrator_mode": true`

**Location 4 — Multi-task plan dispatch (Stage MT-4)**
- Line 959: `'{"task_number": $num, "task_type": $task_type, "session_id": $session_id, "research_artifacts": $research_artifacts, "orchestrator_mode": false}'`
- Multi-task mode plan dispatch (inside the `for task_num in "${plan_tasks[@]}"` loop)
- Current value: `"orchestrator_mode": false`
- Required value: `"orchestrator_mode": true`

**Comparison — implement dispatches (correctly set to `true`)**
- Line 268: `"orchestrator_mode": true` (planned/implementing state)
- Line 300: `"orchestrator_mode": true` (partial state with continuation)
- Line 576: `"orchestrator_mode": true` (blocker escalation Step 5 re-dispatch)
- Line 990: `"orchestrator_mode": true` (multi-task implement dispatch)

#### File: `.claude/skills/skill-researcher/SKILL.md`

- Line 82: `orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"' ...)`
- Line 101: Delegation context template hardcodes `"orchestrator_mode": false` — but this is the context passed to the subagent (general-research-agent), which does not act on it. The skill reads its own `orchestrator_mode` from the incoming delegation context (line 82).
- Line 157: `skill_write_orchestrator_handoff "$orchestrator_mode" ...` — handoff IS written when `$orchestrator_mode = "true"`

**Conclusion**: skill-researcher is correctly wired. It passes `orchestrator_mode=false` to its own subagent (research agents don't write handoffs), but calls `skill_write_orchestrator_handoff` with the orchestrator_mode it received. The fix must be in the value passed *into* skill-researcher from skill-orchestrate.

#### File: `.claude/skills/skill-planner/SKILL.md`

- Line 71: `orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"' ...)`
- Line 98: Delegation context template hardcodes `"orchestrator_mode": false` — same pattern as skill-researcher (this is for the planner-agent subagent)
- Line 151: `skill_write_orchestrator_handoff "$orchestrator_mode" ...` — handoff IS written when `$orchestrator_mode = "true"`

**Conclusion**: skill-planner is also correctly wired. Same fix applies: pass `orchestrator_mode: true` from skill-orchestrate's dispatch context.

#### File: `.claude/scripts/skill-base.sh`

- Line 459: `if [ "$orchestrator_mode" != "true" ]; then return 0; fi` — guard ensures handoff is only written when explicitly `true`
- This guard is the root cause of the breakage: since `false` is passed, the guard exits early and no handoff file is written

#### File: `.claude/docs/architecture/handoff-schema.md`

- Line 6: "Written by: Skills when `orchestrator_mode: true` in delegation context"
- Lines 182-192: Writing contract confirms skills check `orchestrator_mode` and only write when `true`
- Lines 249-251: Reading contract confirms orchestrator logs an error when handoff file is absent

#### File: `.claude/docs/architecture/orchestrate-state-machine.md`

The state table documents all dispatches — but only `planned` and `implementing` states show `orchestrator_mode=true`. The `not_started` and `researched` state rows do not mention `orchestrator_mode`, which appears to be an omission in the spec that mirrors the bug.

### Summary of All Locations to Fix

| Location | File | Line | Current | Fix |
|----------|------|------|---------|-----|
| 1 | `skill-orchestrate/SKILL.md` | 208 | `"orchestrator_mode": false` | `"orchestrator_mode": true` |
| 2 | `skill-orchestrate/SKILL.md` | 240 | `"orchestrator_mode": false` | `"orchestrator_mode": true` |
| 3 | `skill-orchestrate/SKILL.md` | 934 | `"orchestrator_mode": false` | `"orchestrator_mode": true` |
| 4 | `skill-orchestrate/SKILL.md` | 959 | `"orchestrator_mode": false` | `"orchestrator_mode": true` |

All changes are in the same file: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`

---

## Decisions

- **Only skill-orchestrate/SKILL.md needs to change**: skill-researcher and skill-planner are already correctly wired to write the handoff when `orchestrator_mode=true` is passed in.
- **Four locations total** (2 single-task + 2 multi-task) all need the same change.
- **The "false" values in skill-researcher and skill-planner's internal delegation context templates** (lines 101 and 98 respectively) are intentional and correct — those are passed to the research/planner subagents, which are not expected to write handoffs.

---

## Risks and Mitigations

### Risk 1: Blocker escalation and drift inspection contexts
Lines 459, 494, and 542 in skill-orchestrate/SKILL.md set `orchestrator_mode: false` for blocker research forks and reviser dispatches. These are **correct as-is** — blocker research is a fork (no named subagent), and reviser has its own postflight path. Do not change these.

### Risk 2: orchestrate-state-machine.md spec mismatch
The state machine documentation does not show `orchestrator_mode=true` for `not_started` and `researched` rows. After fixing the skill, the documentation should be updated to match. This is low severity (docs-only).

### Risk 3: Existing partial orchestration runs
Tasks currently in `researching` or `planning` states that were started without the fix may not have a handoff file. The orchestrator already handles this gracefully (Stage 5 logs the error and continues), so existing partial runs will not be broken by the fix.

### Risk 4: Token budget
The handoff for research and plan phases will be minimal (no `continuation_context`, `blockers`, or `phases_completed`). Well within the 400-token budget documented in handoff-schema.md.

---

## Recommendations

**Make exactly four changes in `.claude/skills/skill-orchestrate/SKILL.md`**:

1. Line 208: Change `"orchestrator_mode": false` to `"orchestrator_mode": true` (research dispatch, `not_started` handler)
2. Line 240: Change `"orchestrator_mode": false` to `"orchestrator_mode": true` (plan dispatch, `researched` handler)
3. Line 934: Change `"orchestrator_mode": false` to `"orchestrator_mode": true` (multi-task research dispatch)
4. Line 959: Change `"orchestrator_mode": false` to `"orchestrator_mode": true` (multi-task plan dispatch)

Optionally update `.claude/docs/architecture/orchestrate-state-machine.md` to reflect that all orchestrator dispatches use `orchestrator_mode=true`.

The fix is minimal, safe, and directly addresses the root cause.

---

## Context Extension Recommendations

- **Topic**: orchestrate dispatch contexts
- **Gap**: The state machine spec (`orchestrate-state-machine.md`) does not document `orchestrator_mode=true` for research and plan dispatches, making the spec inconsistent with the correct behavior.
- **Recommendation**: Update the state table in `orchestrate-state-machine.md` to add `orchestrator_mode=true` to the `not_started` and `researched` row dispatch instructions.

---

## Appendix

### Search Queries Used
- `grep -rn "orchestrator_mode" .claude/skills/` — found all orchestrator_mode occurrences in skills
- `grep -rn "orchestrator_mode" .claude/` — found all occurrences across the full system

### References
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — primary bug location
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` — correctly wired downstream
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` — correctly wired downstream
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — guard at line 459
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md` — writing contract
- `/home/benjamin/.config/nvim/.claude/docs/architecture/orchestrate-state-machine.md` — spec
