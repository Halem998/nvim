# Research Report: Task #745

**Task**: 745 - Modify /orchestrate commit behavior
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:30:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase (SKILL.md, orchestrate.md, skill-base.sh, git-workflow.md)
**Artifacts**: - specs/745_defer_orchestrate_commits/reports/01_defer-commits.md
**Standards**: report-format.md

## Executive Summary

- Currently, NO git commits happen inside `skill-orchestrate`. The only commit point is CHECKPOINT 3 in `orchestrate.md` (the command layer), which runs a single `git add -A && git commit` after the entire orchestration lifecycle completes.
- The proposed change adds a per-implementation-cycle commit inside Stage 5 of `skill-orchestrate/SKILL.md` (after each dispatch that returns `implemented` or `partial` with `phases_completed > 0`), bundling all uncommitted artifacts from prior research/plan cycles.
- CHECKPOINT 3 in `orchestrate.md` must be made conditional so it only fires when there are actually uncommitted changes (to avoid an empty/duplicate commit when per-implementation commits already captured everything).

## Context & Scope

The orchestrate lifecycle consists of:
1. `/orchestrate` command (orchestrate.md) — validates, delegates to skill, then commits at CHECKPOINT 3
2. `skill-orchestrate/SKILL.md` — autonomous state machine; dispatches research/plan/implement agents; no commits today

The task asks to shift commit timing: instead of one final commit after all cycles complete, commit after each implementation dispatch (or partial with progress), and then make the final CHECKPOINT 3 commit conditional.

## Findings

### Current Commit Flow

**Single commit point** — `orchestrate.md` CHECKPOINT 3 (lines 374–387):

```bash
# On completion:
git add -A && git commit -m "task {N}: complete orchestration\n\nSession: {SESSION_ID}"

# On partial:
git add -A && git commit -m "task {N}: orchestration paused (cycles {M}/{MAX})\n\nSession: {SESSION_ID}"
```

This fires unconditionally after CHECKPOINT 2 (GATE OUT). There is no check for uncommitted changes.

**Inside `skill-orchestrate/SKILL.md`** — zero git operations. Stage 5 (Handoff Reading, lines 339–417) reads the handoff JSON and calls `skill_postflight_update` and `skill_link_artifacts`, but never calls git.

**Multi-task mode** — `orchestrate.md` Step 5 (lines 224–299) has its own batch git commit block that also fires unconditionally.

### Where to Add Per-Implementation-Cycle Commits (Stage 5 of SKILL.md)

Stage 5 already has a `case "$dispatch_status"` block (lines 372–385):

```bash
case "$dispatch_status" in
  researched)
    skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
    ;;
  planned)
    skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
    ;;
  implemented)
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
    ;;
  *)
    echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
    ;;
esac
```

The correct insertion point is **after** `skill_postflight_update` in the `implemented` case and after the existing `case` block for `partial` with `phases_completed > 0`.

**Proposed addition to Stage 5** (after the existing `case` block, before artifact linking):

```bash
# Per-implementation-cycle commit: bundle all artifacts from this full research+plan+implement cycle
# Only commit after implementation completes (not after research or plan alone)
should_commit=false
if [ "$dispatch_status" = "implemented" ]; then
  should_commit=true
elif [ "$dispatch_status" = "partial" ] && [ "$phases_completed" -gt 0 ]; then
  should_commit=true
fi

if [ "$should_commit" = "true" ]; then
  # Check for uncommitted changes before committing (avoid empty commits)
  if ! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'; then
    if [ "$dispatch_status" = "implemented" ]; then
      commit_msg="task ${task_number}: complete implementation

Session: ${session_id}"
    else
      commit_msg="task ${task_number}: implementation progress (${phases_completed}/${phases_total} phases)

Session: ${session_id}"
    fi
    git add -A && git commit -m "$commit_msg" || \
      echo "[orchestrate] WARNING: Git commit failed (non-blocking)"
  else
    echo "[orchestrate] No uncommitted changes — skipping per-cycle commit"
  fi
fi
```

### Where to Make CHECKPOINT 3 Conditional (orchestrate.md)

CHECKPOINT 3 (lines 373–387) currently reads:

```
**On completion:**
```bash
git add -A && git commit -m "task {N}: complete orchestration

Session: {SESSION_ID}"
```

**On partial:**
```bash
git add -A && git commit -m "task {N}: orchestration paused (cycles {M}/{MAX})

Session: {SESSION_ID}"
```
```

The fix is to check for uncommitted changes before committing:

```bash
# Conditional final commit: only run if there are uncommitted changes
if ! git diff --quiet HEAD 2>/dev/null || git status --porcelain 2>/dev/null | grep -q '^'; then
  # On completion:
  git add -A && git commit -m "task {N}: complete orchestration

Session: {SESSION_ID}"
  # (or partial variant)
else
  echo "[orchestrate] No uncommitted changes after orchestration — skipping final commit"
fi
```

### Dispatch Status Decision Table

| `dispatch_status` | `phases_completed` | Add commit in Stage 5? | Notes |
|---|---|---|---|
| `researched` | N/A | No | Research artifacts only; defer to implementation cycle |
| `planned` | N/A | No | Plan artifacts only; defer to implementation cycle |
| `implemented` | any | Yes | Bundle all prior artifacts + implementation summary |
| `partial` | 0 | No | No progress made; avoid empty commits |
| `partial` | > 0 | Yes | Partial implementation progress; commit completed phases |
| `failed` | any | No | Nothing to commit |
| `blocked` | any | No | Let blocker escalation handle |

### Bundling Prior Research/Plan Artifacts

When implementation commits, `git add -A` captures all files modified in the prior research and plan cycles (reports, plans, state.json, TODO.md) that were not committed yet. This is correct behavior — the per-implementation-cycle commit naturally bundles everything. No special handling needed.

### Edge Cases

**1. Multi-task mode (Stage MT-4)**

The multi-task postflight in Stage MT-4 (lines 978–1065) calls `skill_postflight_update` per task but also makes no git commits. The multi-task batch commit lives in `orchestrate.md` Step 5 (lines 224–299).

For multi-task mode, the same conditional guard should be applied to the batch commit in `orchestrate.md` Step 5. The per-cycle commit logic in Stage MT-4 is more complex (parallel tasks) and should NOT be added there — the existing batch commit in `orchestrate.md` Step 5 is the right place for multi-task. Only apply the conditional guard there.

**2. Blocker escalation commits**

Stage 6 (Blocker Escalation) dispatches a fork + reviser-agent + re-implement agent. After blocker escalation re-dispatches implement (Step 5 in Stage 6), the resulting handoff goes back through Stage 5 which would then trigger the per-cycle commit. This is correct behavior.

**3. Drift inspection and revision**

Stage 5a (Drift Inspection) and its reviser-agent dispatch do NOT produce implementation outputs; the revised plan is a "planned" artifact. The subsequent re-dispatch of implement goes through Stage 5 again, triggering the per-cycle commit. This is correct.

**4. Partial with `phases_completed == 0`**

If an implementation agent returns `partial` but did no work (phases_completed=0), we should NOT commit — there's nothing meaningful to save yet. The condition `phases_completed > 0` handles this.

**5. `git diff --quiet HEAD` on fresh repo or empty HEAD**

If there is no prior commit (empty repo), `git diff --quiet HEAD` will fail with a non-zero exit. The `2>/dev/null` suppresses the error, and then `git status --porcelain` as a fallback will correctly detect any staged/untracked files. This is a safe combination.

**6. Commit message format for partial cycles**

The git-workflow.md standard for implementation phases is `task {N} phase {P}: {phase_name}`. For the per-cycle partial case, using `task {N}: implementation progress ({phases_completed}/{phases_total} phases)` is a reasonable extension that follows the spirit of the convention.

### Files to Modify

1. `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
   - **Section**: Stage 5: Handoff Reading (lines 339–417)
   - **Location**: After the existing `case "$dispatch_status"` block (after line 385), before the artifact linking block (before line 387: `# Artifact linking`)
   - **Change**: Add the conditional per-cycle commit block

2. `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md`
   - **Section**: CHECKPOINT 3: COMMIT (lines 373–387)
   - **Change**: Wrap both the completion and partial commit commands with an `if ! git diff --quiet HEAD || git status --porcelain | grep -q '^'; then` guard
   - **Multi-task**: Also wrap the batch commit in `orchestrate.md` Step 5 (lines 246–264 and 256–264) with the same guard

## Decisions

- Commit only on `implemented` or `partial` with `phases_completed > 0` — not on `researched` or `planned`
- Use `git add -A` in the per-cycle commit to bundle all accumulated artifacts from prior research/plan cycles
- Use `git diff --quiet HEAD || git status --porcelain | grep -q '^'` as the uncommitted-changes check (handles both tracked modifications and untracked new files)
- Make CHECKPOINT 3 conditional using the same check pattern
- Do NOT add per-cycle commits to Stage MT-4 (multi-task parallel dispatch) — the batch commit in orchestrate.md Step 5 is the correct single commit point for multi-task; only apply the conditional guard there

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `git diff --quiet HEAD` fails on empty HEAD | Use `2>/dev/null` + fallback to `git status --porcelain` |
| Double commit if `implemented` status fires and then CHECKPOINT 3 also fires | CHECKPOINT 3 conditional guard prevents this |
| Losing research/plan artifacts if implementation never completes | Artifacts exist on disk; not committed to git until implementation, but git-untracked is an acceptable trade-off for this workflow |
| Partial commits with no actual file writes (phases_completed=0) | Condition `phases_completed > 0` guards against this |
| Multi-task mode emits duplicate commits | Per-cycle commits NOT added to MT path; only the batch commit in orchestrate.md Step 5 gets the conditional guard |

## Recommended Approach

**Phase 1**: Modify `skill-orchestrate/SKILL.md` Stage 5 — add conditional per-cycle commit block after the `case "$dispatch_status"` block.

**Phase 2**: Modify `orchestrate.md` CHECKPOINT 3 — wrap both commit blocks with uncommitted-changes guard.

**Phase 3**: Modify `orchestrate.md` Step 5 (multi-task batch commit) — wrap batch commit blocks with the same guard.

All three changes are mechanical text edits. No new scripts or functions required. Git commit is already non-blocking (log and continue); the same pattern applies to the new per-cycle commits.
