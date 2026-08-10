# Phase 4 Results: Refactor /revise with gate-in/gate-out and orchestrator handoff

**Completed**: 2026-05-22
**Phase**: 4 of 8
**Target**: `.claude/commands/revise.md` (~160L to ~125L)

## What Changed

- `.claude/commands/revise.md` — Refactored from 160L to 125L

## Changes Applied

### 1. `--orchestrator` flag parsing (ARGUMENTS section)
Added argument parsing loop at the start of CHECKPOINT 1 that detects `--orchestrator` and sets `orchestrator_mode="true"`. Remaining args are accumulated into `revision_reason`. The `argument-hint` frontmatter was updated to show `[--orchestrator]`.

### 2. CHECKPOINT 1 (GATE IN) replaced with shared script
Replaced ~30 lines of inline jq (session ID generation, task lookup, padded number calculation, terminal status check) with:
```bash
source .claude/scripts/command-gate-in.sh "$task_number" "revise"
```
The script exports `SESSION_ID`, `PADDED_NUM`, `PROJECT_NAME`, `TASK_STATUS`, `TASK_TYPE`. Plan existence check follows immediately using the exported `PADDED_NUM` and `PROJECT_NAME`.

### 3. CHECKPOINT 3 (GATE OUT) replaced with shared script
Replaced ~37 lines of inline defensive correction logic with:
```bash
bash .claude/scripts/command-gate-out.sh "$task_number" "plan" "$SESSION_ID"
```
Artifact verification (checking plan file exists) remains inline since it's revise-specific. Status mismatch correction is now fully delegated to the shared script.

### 4. Orchestrator handoff block added
After the gate-out call, a conditional block sources `skill-base.sh` and calls `skill_write_orchestrator_handoff` with:
- `phase="revise"`, `status="planned"`, `next_hint="implement"`
- Guarded by `[ "$orchestrator_mode" = "true" ]`

### 5. Artifact Numbering Note updated
Added sentence referencing the shared infrastructure scripts.

### 6. Output section condensed
Combined verbose multi-line output templates into single-line summaries (saves ~15L).

## Verification

- `wc -l .claude/commands/revise.md` → 125L (target: 120-130L)
- GATE IN uses `command-gate-in.sh` (SESSION_ID, PADDED_NUM exported)
- GATE OUT uses `command-gate-out.sh` (defensive correction delegated)
- `--orchestrator` flag triggers `skill_write_orchestrator_handoff` call
- Plan existence check preserved (routes between revision vs description update)
- Without `--orchestrator`, behavior is identical to prior version

## Deviations from Plan

None. All six tasks completed as specified.
