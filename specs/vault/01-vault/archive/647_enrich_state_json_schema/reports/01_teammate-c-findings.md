# Teammate C Findings: Critical Review of Schema Enrichment Audit

- **Task**: 647 - Enrich state.json schema to be the single complete source of truth
- **Started**: 2026-06-10T01:35:00Z
- **Completed**: 2026-06-10T02:00:00Z
- **Effort**: 25 minutes
- **Dependencies**: Teammate A findings
- **Sources/Inputs**:
  - specs/647_enrich_state_json_schema/reports/01_teammate-a-findings.md
  - specs/state.json, specs/TODO.md (nvim project)
  - /home/benjamin/Projects/cslib/specs/state.json, TODO.md
  - .claude/context/reference/state-management-schema.md
  - .claude/scripts/update-task-status.sh
  - .claude/scripts/generate-task-order.sh
  - .claude/scripts/skill-base.sh
- **Artifacts**: This critical review
- **Standards**: report-format.md

## Executive Summary

- Teammate A's core findings are **verified and accurate**: title gaps (confirmed 11/17 nvim, all cslib), status drift (task 87 confirmed: `researched` vs `[PLANNED]`), and artifact gaps (task 638 confirmed: 3 on disk, 0 tracked).
- **Critical gap in Teammate A's analysis**: `description` is not even documented in the official `state-management-schema.md` field reference — it's used in practice but missing from the schema specification. Same for `title` — neither field appears in the Project Entry Fields table.
- **Backwards compatibility risk understated**: 51 references to `project_name` across scripts; `generate-task-order.sh` falls back to `description // project_name` not `title`; adding `title` without updating the fallback chain would produce mixed output.
- **Lazy directory creation recommendation has a conflict**: `skill_create_postflight_marker()` in `skill-base.sh` calls `mkdir -p "$task_dir"` — this is the postflight marker, not artifact creation. You can't defer directory creation past the postflight marker stage.
- **Missing analysis**: Plan status drift root cause is more specific than stated — `update-plan-status.sh` is only called for `implement:preflight`, `implement:postflight`, and `plan:postflight` operations. Research operations never touch plan status, and the `plan:preflight` case also skips it. This means task 638's plan showing `[NOT STARTED]` is expected if the task was completed via `/orchestrate` or manual completion without going through the standard implement pipeline.

## Verified Claims

### 1. Title Field Gap — CONFIRMED

Spot-checked: tasks 87 and 638 in nvim have `"title": "MISSING"` (field absent). Tasks 647-652 do have title (recently added). cslib state.json has zero `title` fields across all 20 tasks. **Verdict: Accurate.**

### 2. Status Drift — CONFIRMED

- nvim task 87: state.json says `researched`, TODO.md says `[PLANNED]`. **Confirmed via direct grep.**
- cslib task 57: state.json says `completed`, Task Order shows `57 [PLANNED]`. Task entry shows `[COMPLETED]`. **Confirmed.** The Task Order wasn't regenerated after completion — exactly the kind of drift the SSOT refactor would fix.
- cslib task 56: plan file shows `[IN PROGRESS]`, state.json says `completed`. **Confirmed via direct grep.**

### 3. Artifact Gaps — CONFIRMED

- nvim task 638: 3 artifacts on disk (report, plan, summary), `artifacts: []` in state.json. **Confirmed.**
- cslib: task 12 (8 on disk, 0 tracked), task 31 (8, 0), task 55 (3, 0), task 56 (3, 0), task 57 (3, 1). **All confirmed.**

## Challenged Assumptions

### 1. `parent_task` and `blocker_reason` Fields — QUESTIONABLE VALUE

Teammate A proposes adding `parent_task` (integer) and `blocker_reason` (string) as optional fields. I challenge these:

- **`parent_task`**: Only 4 tasks across both projects use parent/subtask relationships (tasks 12, 31 in cslib; none in nvim active). The existing `subtasks` array already captures this relationship from the parent side. Adding `parent_task` creates a bidirectional reference that must stay in sync — the exact kind of dual-write problem the refactor is trying to eliminate. **Recommendation: Skip.** If needed, derive parent from `subtasks` arrays.

- **`blocker_reason`**: Only 3 tasks are blocked (cslib 36, 37, 40), and their blocker descriptions are already embedded in the `description` field. A separate field creates two places to store blocker info. **Recommendation: Skip.** Keep blocker text in `description`. If a task is `blocked` status, the description should explain why.

### 2. Filesystem Artifact Scan in generate-todo.sh — RISKY

Teammate A recommends generate-todo.sh scan the filesystem for untracked artifacts as "self-healing." Concerns:

- **Performance**: `find` across all task directories on every TODO.md regeneration adds latency.
- **False positives**: Draft files, temporary artifacts, teammate findings (not the synthesis) would be "discovered" and linked.
- **Responsibility confusion**: Should the rendering script also be a data repair tool? This mixes concerns.
- **Better approach**: Add artifact tracking to the postflight scripts (which already know the artifact path and type). A separate `reconcile-artifacts.sh` audit script could run periodically, similar to the existing `reconcile-task-status.sh`.

### 3. Report Started/Completed Timestamps — KEEP

Teammate A says these "partially duplicate" state.json timestamps. They don't — `created` and `last_updated` in state.json track the *task* lifecycle, not the *report* writing session. A task may be created weeks before research starts. The report's Started/Completed timestamps record when the research *work* happened. These are useful metadata and not redundant. **Recommendation: Keep in report template.**

## Gaps in Teammate A's Analysis

### 1. Official Schema Doesn't Document `description`

The `state-management-schema.md` Project Entry Fields table lists `project_number`, `project_name`, `status`, `task_type`, `topic`, `effort`, `created`, `last_updated`, `dependencies`, `artifacts`, `next_artifact_number` — but NOT `description`. The field is used in practice (16 of 17 nvim tasks have it) but it's an undocumented convention, not a schema-specified field. Teammate A should have flagged this as a schema documentation gap rather than assuming it's a known field.

### 2. `generate-task-order.sh` Fallback Chain

The script uses `(.description // .project_name) | .[0:65]` for display text. It doesn't use `title` at all. When `title` is added, this fallback chain should become `(.title // .description // .project_name) | .[0:65]`. Teammate A didn't analyze the downstream script changes needed to consume the new field.

### 3. Plan Status Update Trigger Matrix

The plan status update (Phase 4 of update-task-status.sh) only fires for:
- `implement:preflight` → IMPLEMENTING
- `implement:postflight` → COMPLETED
- `plan:postflight` → PLANNED

These are the ONLY triggers. Missing cases:
- `research:*` → never touches plan (expected — no plan exists yet)
- `plan:preflight` → PLANNING not set (plan is being written, this is arguably correct)
- Any non-standard completion path (manual, orchestrate shortcut) → plan status stale

This explains WHY plan status drift is endemic: any task that reaches `completed` without going through the standard `implement` pipeline (e.g., task 638 which was completed via bootstrapped orchestration, or cslib tasks completed before the centralized scripts existed) will have stale plan status.

### 4. Multi-Project Deployment Concern

The enriched schema must work across multiple projects (nvim, cslib, BimodalLogic, ModelChecker). Teammate A mentions "breaking change" risk but doesn't address:
- **Migration script must be project-agnostic**: The `migrate-todo-to-state.sh` script needs to handle different TODO.md formats across projects (cslib has different field ordering, some tasks have `**Scope**:` subsections, etc.)
- **Schema version field**: state.json has `"version": "1.0.0"` — should this be bumped to indicate schema changes? Scripts could use this for backwards-compatible field handling.

### 5. `effort` Field Inconsistency

The schema says `effort` is optional (type: string, No required). But the formats are wildly inconsistent:
- nvim: "1-2 hours", "30 minutes", "TBD"
- cslib: "Medium (8-12 hours)", "Large", "Small (2 hours)"

If generate-todo.sh will render this field, should there be a canonical format? This isn't a schema concern per se, but it affects the quality of generated output. **Recommendation: Don't enforce format — it's human-authored and format variety is acceptable.**

## Script Backwards Compatibility Assessment

Adding `title` is **additive and safe** — no existing script will break because:
1. jq queries like `.project_name` still work (title is a new field, not a replacement)
2. `generate-task-order.sh` uses `(.description // .project_name)` which won't see `title` until updated
3. All other scripts reference `project_name` for directory paths, which remains correct

**However**: Until scripts are updated to prefer `title`, the new field sits unused. The migration plan should include a checklist of scripts to update to use `title // description // project_name` fallback chain.

Scripts that need updating (51 references to `project_name` found across scripts):
- `generate-task-order.sh` — display text (critical)
- `update-task-status.sh` — plan directory lookup (uses `project_name` for paths, correct)
- `update-plan-status.sh` — plan directory lookup (uses `project_name` for paths, correct)
- `link-artifact-todo.sh` — task entry lookup (uses task number, not name — no change needed)
- `skill-base.sh` — directory construction (uses `project_name` for paths, correct)

**Key distinction**: `project_name` remains the directory slug. `title` is for display only. Scripts that construct filesystem paths should continue using `project_name`.

## Recommendations

1. **Add both `title` and `description` to the official schema reference** — document in `state-management-schema.md` Project Entry Fields table with proper types and required/optional designation
2. **Skip `parent_task` and `blocker_reason`** — low-frequency fields that create maintenance burden; existing fields suffice
3. **Don't add filesystem scan to generate-todo.sh** — create a separate `reconcile-artifacts.sh` audit script instead
4. **Keep Started/Completed in report template** — they're report-level timestamps, not task-level status
5. **Update script fallback chains** before relying on `title` field
6. **Bump schema version** to "1.1.0" to signal the schema enrichment
7. **Create project-agnostic migration script** that handles diverse TODO.md formats
8. **Add `description` to schema as required** — formalize what's already standard practice

## Appendix

### Plan Status Trigger Matrix

| Operation:Phase | Plan Status Set | Notes |
|----------------|----------------|-------|
| research:preflight | (none) | No plan exists yet |
| research:postflight | (none) | No plan exists yet |
| plan:preflight | (none) | Arguably should set PLANNING |
| plan:postflight | PLANNED | Correct |
| implement:preflight | IMPLEMENTING | Correct |
| implement:postflight | COMPLETED | Correct |
| revise:* | (none) | Revise creates new plan file |
| manual/orchestrate | (none) | Plan status never updated |

### Script project_name Usage Categories

| Category | Scripts | Action Needed |
|----------|---------|--------------|
| Display text | generate-task-order.sh | Update to use title fallback |
| Directory paths | update-task-status.sh, update-plan-status.sh, skill-base.sh, link-artifact-todo.sh | Keep project_name (correct) |
| Commit messages | skill-base.sh | Could optionally use title |
| Task lookup | link-artifact-todo.sh | Uses task number, no change |
