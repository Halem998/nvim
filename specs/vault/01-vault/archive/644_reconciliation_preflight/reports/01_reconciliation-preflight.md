# Research Report: Task #644

**Task**: 644 - reconciliation_preflight
**Started**: 2026-06-09T04:15:00Z
**Completed**: 2026-06-09T04:30:00Z
**Effort**: 45 minutes
**Dependencies**: 643 (eliminate_dual_postflight — completed)
**Sources/Inputs**: Codebase (skill-orchestrate SKILL.md, update-task-status.sh, skill-base.sh, orchestrate.md, state.json, postflight-workflow.sh, link-artifact-todo.sh)
**Artifacts**: specs/644_reconciliation_preflight/reports/01_reconciliation-preflight.md
**Standards**: report-format.md

---

## Executive Summary

- The orchestrator has a critical gap: when an agent crashes **after writing artifacts but before postflight runs**, the task stays stuck in an in-progress state (`researching`, `planning`, `implementing`) with artifacts orphaned on disk but status not promoted in state.json.
- This exact failure mode exists right now: tasks 644 and 645 are both `status: "researching"` in state.json but have no research reports (they were partially initialized by the multi-task orchestrator in a prior session that was interrupted).
- The recommended fix is a **Stage 2.5 reconciliation pass** inserted into `skill-orchestrate/SKILL.md` immediately after the loop guard initialization, before the state machine loop. It scans the task directory, infers the completed phase from artifact presence, and calls `update-task-status.sh postflight` to promote the status — replaying the missed postflight.
- A standalone bash script (`reconcile-task-status.sh`) is recommended to keep the SKILL.md clean and testable independently.

---

## Context & Scope

The orchestrator (`skill-orchestrate`) is a state machine that drives tasks through `not_started → researching → researched → planning → planned → implementing → completed`. Each phase transition requires:

1. **Preflight**: `update-task-status.sh preflight` sets status to in-progress (e.g., `researching`)
2. **Agent dispatch**: the skill or agent performs work and writes artifacts to disk
3. **Postflight**: `update-task-status.sh postflight` promotes status to completed (e.g., `researched`)

When the session is interrupted after step 2 but before step 3, the task stays in its in-progress state with artifacts already written. On the next `/orchestrate` invocation, Stage 3 reads the in-progress status and exits with a warning ("Task is currently being researched in another session") instead of recognizing that research already completed.

---

## Findings

### Codebase Patterns

#### Current State Machine Entry Point (Stage 2)

```bash
# Stage 2: Preflight — Loop Guard
loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"
handoff_file="${TASK_DIR}/.orchestrator-handoff.json"

mkdir -p "$TASK_DIR"

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
else
  # Fresh start: create guard
  cycle_count=0
  # ... initialize loop guard file
fi
```

There is currently NO reconciliation between "what status does state.json say?" and "what artifacts exist on disk?".

#### In-Flight State Handlers (Stage 3c / Stage 4)

The `researching` and `planning` state handlers simply exit with a warning:

```bash
# State: researching
echo "[orchestrate] WARNING: Task $task_number is currently being researched in another session."
echo "Wait for the research to complete, then run /orchestrate $task_number again."
EXIT (partial)
```

This is the correct behavior for a genuinely concurrent session. But it's wrong when no other session is active — the artifacts are there, the work is done, just the status was never promoted.

#### Artifact-to-Phase Mapping

The system has a clear and consistent mapping of disk artifacts to completed lifecycle phases:

| Artifact Present | Phase Completed | Correct Status |
|------------------|-----------------|----------------|
| `reports/*.md` exists | Research done | `researched` |
| `plans/*.md` exists | Planning done | `planned` |
| `summaries/*.md` exists | Implementation done | `completed` |
| `.orchestrator-handoff.json` | Phase done, status in handoff | Promotes via handoff |

The handoff JSON (`skill_write_orchestrator_handoff` in skill-base.sh) also tracks the phase outcome but is written by the skill postflight — which means it's written by the same step that also calls `update-task-status.sh`. So if postflight was interrupted, the handoff may also be absent or stale.

#### Status-to-Expected-Artifact Cross-Reference

When state.json says a task is in an in-flight state, the following artifacts indicate the phase actually completed:

| Current Status | Artifact That Proves Completion | Target Status After Reconciliation |
|---------------|--------------------------------|-------------------------------------|
| `researching` | `specs/{NNN}_{SLUG}/reports/*.md` exists | `researched` |
| `planning` | `specs/{NNN}_{SLUG}/plans/*.md` exists | `planned` |
| `implementing` | `specs/{NNN}_{SLUG}/summaries/*.md` exists | `completed` |
| `partial` | `specs/{NNN}_{SLUG}/summaries/*.md` exists | `completed` |

Note: `partial` with a summary is unusual but could happen if the implementer wrote the summary before crashing during the final postflight. The reconciliation should handle it.

#### The postflight Mechanism

`update-task-status.sh postflight` is the authoritative promotion function:

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"
```

Status transitions it produces:
- `postflight research` → sets `researched` in state.json, `[RESEARCHED]` in TODO.md
- `postflight plan` → sets `planned` in state.json, `[PLANNED]` in TODO.md
- `postflight implement` → sets `completed` in state.json, `[COMPLETED]` in TODO.md, triggers full Task Order regeneration

The script is **idempotent**: if status is already at target, it's a no-op (exits 0).

#### Artifact Linking Gap

`update-task-status.sh` does NOT link artifacts — that is done separately via `link-artifact-todo.sh` and the `artifacts` array in state.json. The reconciliation must also check if the artifact is already linked in state.json and link it if not.

In `skill-orchestrate` Stage 5, artifact linking happens via:
```bash
artifact_path=$(echo "$handoff" | jq -r '.artifacts[0].path // ""')
# ... then updates state.json artifacts array and calls link-artifact-todo.sh
```

For reconciliation (no handoff available), the artifact path must be inferred from disk.

#### Existing No-Reconciliation Scripts

None of the existing scripts in `.claude/scripts/` perform artifact-based status inference. The closest is `postflight-workflow.sh` which performs a postflight given explicit artifact path input — but it requires the caller to know which artifact was created.

#### Live Failure Example (Tasks 644 and 645)

Right now in this repository:
- `state.json` shows task 644 as `"status": "researching"` and task 645 as `"status": "researching"`
- `specs/644_reconciliation_preflight/` contains only `reports/` (empty directory)
- `specs/645_parallel_write_safety/` contains only `reports/` (empty directory)
- Neither task has a research report (the agents never actually wrote one)
- The multi-task orchestrator was interrupted after preflight but before research dispatch

**Important**: In this specific case, the tasks don't have artifacts that need reconciling — they need to be re-run from `researching`. This is the "truly in-progress" case that should NOT be auto-promoted. The reconciliation logic must distinguish between:
- "Status says `researching`, no report exists" → genuinely in-progress or incomplete; **do not promote**
- "Status says `researching`, report exists" → agent crashed after writing report; **promote to `researched`**

### Failure Scenarios Covered by Reconciliation

1. **Agent crash after artifact write**: Agent writes `reports/01_*.md` then crashes before `skill_postflight_update` runs. Status stays `researching`, report exists. Fix: promote to `researched`.

2. **Session timeout during postflight**: The Agent tool itself was interrupted (aborted, killed) after the subagent completed but before the skill read the `.return-meta.json` and called postflight. Same result: artifact exists, status stuck in-flight.

3. **Multi-task orchestrator interrupted**: The multi-task orchestrator dispatched research in parallel, agents completed and wrote reports, but the orchestrator session was killed before it could read handoffs and call postflight for each task. Multiple tasks stuck with artifacts but old status.

4. **Planning crash**: Planner wrote `plans/01_*.md` but postflight failed. Status stays `planning`, plan exists.

5. **Implementation partial**: Implementer wrote `summaries/01_*.md` but postflight failed. Status stays `implementing`, summary exists.

### Design Considerations

#### Where to Insert Reconciliation

**Recommended**: As **Stage 2.5** in `skill-orchestrate/SKILL.md`, immediately after the loop guard initialization (Stage 2) and before the state machine loop (Stage 3). This runs once per `/orchestrate` invocation.

**Alternative considered**: At the start of Stage 4's `researching` state handler, to fix the status inline. Rejected: this delays the fix until the state machine loop fires, and doesn't help multi-task mode which dispatches based on pre-read status.

**For multi-task mode**: Stage MT-2 reads statuses before building the dispatch table. Reconciliation should also run at MT-2 time, before dispatching. The cleanest approach is to run reconciliation in the single-task preflight (Stage 2.5) AND add a similar check to MT-2 before building the routing tables.

#### Detection Heuristic

Simple and unambiguous:

```bash
reconcile_task_status() {
  local task_number="$1"
  local task_dir="$2"
  local session_id="$3"

  current_status=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .status' \
    specs/state.json)

  case "$current_status" in
    researching)
      # Check if research report exists
      latest_report=$(ls -1 "${task_dir}/reports/"*.md 2>/dev/null | sort -V | tail -1)
      if [ -n "$latest_report" ]; then
        echo "[reconcile] Task $task_number: report found but status=researching — promoting to researched"
        bash .claude/scripts/update-task-status.sh postflight "$task_number" "research" "$session_id"
        # Link artifact if not already in state.json
        _reconcile_link_artifact "$task_number" "$latest_report" "report"
      fi
      ;;
    planning)
      latest_plan=$(ls -1 "${task_dir}/plans/"*.md 2>/dev/null | sort -V | tail -1)
      if [ -n "$latest_plan" ]; then
        echo "[reconcile] Task $task_number: plan found but status=planning — promoting to planned"
        bash .claude/scripts/update-task-status.sh postflight "$task_number" "plan" "$session_id"
        _reconcile_link_artifact "$task_number" "$latest_plan" "plan"
      fi
      ;;
    implementing|partial)
      latest_summary=$(ls -1 "${task_dir}/summaries/"*.md 2>/dev/null | sort -V | tail -1)
      if [ -n "$latest_summary" ]; then
        echo "[reconcile] Task $task_number: summary found but status=$current_status — promoting to completed"
        bash .claude/scripts/update-task-status.sh postflight "$task_number" "implement" "$session_id"
        _reconcile_link_artifact "$task_number" "$latest_summary" "summary"
      fi
      ;;
  esac
}
```

#### Standalone Script vs Inline

**Recommended**: Standalone script `reconcile-task-status.sh`. Reasons:
- Can be independently tested with `--dry-run`
- Can be called from both single-task Stage 2.5 and multi-task Stage MT-2
- Keeps SKILL.md readable (context flatness constraint)
- Can be invoked manually for ad-hoc recovery

#### Artifact Linking During Reconciliation

The reconciliation must also ensure the artifact is linked in `state.json` (the `artifacts` array). When postflight was missed, the artifacts array is typically empty or missing the artifact. The reconciliation script should:

1. Check if an artifact of the same type already exists in state.json
2. If not, add it using the jq two-step pattern (Issue #1132-safe)
3. Call `link-artifact-todo.sh` to link in TODO.md

This mirrors exactly what Stage 5 of skill-orchestrate does after reading the handoff.

#### Ambiguous Cases

- **Multiple reports**: Use `sort -V | tail -1` (latest version). This is consistent with how the orchestrator picks the latest plan (`ls -1 "${TASK_DIR}/plans/"*.md | sort -V | tail -1`).
- **Partial artifacts** (incomplete .md files): Not detectable from filename alone. The reconciliation does not validate artifact content — if the file exists it's treated as complete. This matches the overall system philosophy (trust artifacts, don't second-guess).
- **Genuinely concurrent sessions**: The current in-flight warning exits immediately; reconciliation does NOT suppress this — it only promotes status when artifacts exist. If no artifact exists, behavior is unchanged.

#### Loop Guard Interaction

The loop guard is created/read in Stage 2. Reconciliation in Stage 2.5 may change the task status BEFORE the state machine loop reads it in Stage 3a. This is correct: Stage 3a always re-reads `state.json` at the top of each iteration, so the promoted status will be picked up on the first cycle.

#### Multi-Task Mode Integration

For multi-task mode, reconciliation should run in Stage MT-2 (before building the routing table and current_statuses map). The simplest approach: call the same `reconcile-task-status.sh` script for each task in the validated list, using the batch session ID.

```bash
# In Stage MT-2, before reading current_statuses:
for task_num in $(echo "$task_numbers_json" | jq -r '.[]'); do
  bash .claude/scripts/reconcile-task-status.sh "$task_num" "$session_id"
done
```

---

## Decisions

1. **Implement as standalone script**: `reconcile-task-status.sh` in `.claude/scripts/`, called from SKILL.md Stage 2.5 and MT-2.
2. **Single-task insertion point**: Stage 2.5 (after loop guard, before state machine loop).
3. **Multi-task insertion point**: Stage MT-2 (before building current_statuses map).
4. **Detection rule**: artifact file exists + status is in-progress for that phase → promote.
5. **Artifact linking**: reconciliation also links artifacts in state.json and TODO.md (idempotent, safe to re-run).
6. **Session ID for reconciliation**: reuse the current session's session_id (or batch session ID in multi-task mode).
7. **Dry-run support**: the script should support `--dry-run` for safe manual inspection.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| False positive: promoting a task that's genuinely in-progress in another session | Low | Artifact existence is reliable; a genuinely in-progress agent hasn't written its report yet |
| Artifact linking in TODO.md fails silently | Medium | `link-artifact-todo.sh` exits non-zero on failure; reconciliation should log warning (non-blocking) |
| Multi-task race: two orchestrators reconcile the same task simultaneously | Very Low | `update-task-status.sh` is idempotent; worst case is a redundant write |
| Reconciliation promotes a task to `completed` prematurely (e.g., stale summary from prior round) | Low | Use `sort -V | tail -1` to pick the latest artifact; stale artifacts from prior rounds would have been superseded |
| jq Issue #1132 in new script | Medium | Use established safe patterns from existing scripts (two-step jq, `| not` instead of `!=`) |

---

## Context Extension Recommendations

- **Topic**: Orchestrator reconciliation pattern
- **Gap**: No documentation on artifact-based status inference or the "artifact exists but status stuck" failure mode
- **Recommendation**: Add a section to `.claude/docs/architecture/orchestrate-state-machine.md` covering the reconciliation preflight and self-healing behavior

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1170 lines — full state machine)
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (453 lines — postflight mechanism)
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` (526 lines — skill lifecycle + handoff writing)
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-workflow.sh` (138 lines — artifact + status update)
- `/home/benjamin/.config/nvim/.claude/scripts/link-artifact-todo.sh` (251 lines — artifact linking)
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` (330 lines — command entry point)
- `/home/benjamin/.config/nvim/specs/state.json` (live state — confirmed active failure case)

### Key Discoveries

1. Tasks 644 and 645 are currently in the exact failure mode this task addresses: `status=researching` but no research artifacts exist (because the prior orchestrator session was interrupted before dispatching research agents, not after).

2. The `skill_write_orchestrator_handoff` function in `skill-base.sh` is the "oracle" for what phase status should be — but it's written by the same postflight step that's being missed. Reconciliation must infer status from artifacts instead.

3. The `update-task-status.sh` script is already idempotent: calling `postflight research` when status is already `researched` is a safe no-op. This means the reconciliation can be called unconditionally without additional guards.

4. The `link-artifact-todo.sh` script is also idempotent: it checks if the artifact path is already present before inserting (Case 4: already linked).
