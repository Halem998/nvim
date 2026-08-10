# Teammate A Findings: state.json Schema Enrichment Audit

- **Task**: 647 - Enrich state.json schema to be the single complete source of truth
- **Started**: 2026-06-10T01:00:00Z
- **Completed**: 2026-06-10T01:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - specs/state.json (nvim project)
  - specs/TODO.md (nvim project)
  - /home/benjamin/Projects/cslib/specs/state.json
  - /home/benjamin/Projects/cslib/specs/TODO.md
  - .claude/context/reference/state-management-schema.md
  - .claude/context/formats/report-format.md
  - .claude/rules/state-management.md
  - Plan files across both projects
  - Web research on SSOT patterns (2025-2026)
- **Artifacts**: This report
- **Standards**: report-format.md, state-management-schema.md

## Executive Summary

- **11 of 17 nvim tasks** are missing the `title` field in state.json; **ALL 20 cslib tasks** are missing it. The human-readable title lives only in TODO.md headings.
- **4 nvim tasks** and **11 cslib tasks** have no `description` in state.json; descriptions live only in TODO.md.
- **Active status drift detected**: Task 87 (nvim) is `researched` in state.json but `[PLANNED]` in TODO.md. Task 57 (cslib) is `completed` in state.json but `[PLANNED]` in Task Order.
- **Massive artifact linking gaps**: 5 cslib tasks have artifacts on disk but zero tracked in state.json; 2 cslib tasks have partial tracking. Nvim task 638 has 3 artifacts on disk but 0 tracked.
- **Plan file status drift is endemic**: cslib task 56 plan shows `[IN PROGRESS]` despite task being `completed`; task 57 plan shows `[NOT STARTED]` despite being `completed`.
- The report-format.md correctly advises "Status metadata belongs in TODO.md and state.json only, not in reports" but the template still includes Started/Completed fields that redundantly duplicate state.json timestamps.

## Context & Scope

This audit examines every task across the nvim (17 tasks) and cslib (20 tasks) projects to catalog fields that exist in TODO.md but not in state.json, identify status inconsistencies across all three layers (Task Order, task entries, plan files), and identify artifact linking gaps. The goal is to define an enriched state.json schema sufficient for complete TODO.md generation.

## Findings

### 1. Missing `title` Field (Critical)

state.json has `project_name` (snake_case slug, e.g., `fix_himalaya_smtp_authentication_failure`) but no human-readable title. The title ("Fix Himalaya SMTP authentication failure when sending emails") exists only in TODO.md headings (`### 78. Fix Himalaya...`).

**nvim project**: 11 of 17 tasks missing title (tasks 638-646, 78, 87). The 6 new tasks (647-652) have titles because they were just created with the field.

**cslib project**: ALL 20 tasks missing the title field entirely.

**Impact**: Without `title`, generate-todo.sh cannot produce the `### {N}. {Title}` heading. The current `project_name` slug is insufficient — it loses capitalization, abbreviations (SMTP, OAuth, PR), and natural phrasing.

**Recommendation**: Add `title` as a required field. For existing tasks, backfill from TODO.md headings. For new tasks, capture at creation time (the `/task` and `/meta` commands already have the title from the user's description).

### 2. Missing `description` Field (High)

**nvim project**: 4 tasks missing description (638, 639, 78, 87). The descriptions exist only in TODO.md's `**Description**:` block.

**cslib project**: 11 tasks missing description (55-65). Rich descriptions with scope details, code references, and blocker information exist only in TODO.md.

**Impact**: Without full descriptions, generate-todo.sh cannot reproduce the `**Description**: ...` block. Some descriptions are substantial (500+ words for cslib tasks 38-41).

**Recommendation**: Make `description` required. For multi-paragraph descriptions, store the full text in state.json (JSON strings handle newlines with `\n`). For legacy tasks, migrate by parsing TODO.md.

### 3. Missing `effort` Field (Medium)

**nvim project**: Task 87 missing effort (shows "TBD" in TODO.md).

**cslib project**: ALL 20 tasks missing `effort` field. Yet TODO.md shows efforts like "Medium (8-12 hours)", "Small (2 hours)", "Large".

**Impact**: generate-todo.sh needs this to produce the `- **Effort**: {estimate}` line.

**Recommendation**: Keep `effort` optional but ensure task creation commands populate it. Default to `null` rather than omitting.

### 4. Status Inconsistencies (Critical)

**Task Order vs state.json**:
- cslib task 57: `completed` in state.json, `[PLANNED]` in Task Order. The Task Order was regenerated but `completed` tasks should be excluded — yet task 57 shows up with stale `[PLANNED]` status. This indicates the Task Order regeneration ran when task 57 was `planned`, and the status wasn't updated in-place after completion.

**TODO.md task entry vs state.json**:
- nvim task 87: `researched` in state.json, `[PLANNED]` in TODO.md task entry. The update-task-status.sh script either failed silently or was never called for this task's status transition.

**Plan file vs state.json**:
- cslib task 56: plan shows `[IN PROGRESS]`, task is `completed` — plan status was never updated to `[COMPLETED]`
- cslib task 57: plan shows `[NOT STARTED]`, task is `completed` — plan status was never set
- cslib task 12: plan shows `[PARTIAL]`, task is `expanded` — plan wasn't updated to reflect expansion
- cslib task 31: plan shows `[IN PROGRESS]`, task is `expanded` — plan wasn't updated to reflect expansion
- nvim task 638: plan shows `[NOT STARTED]`, task is `completed` — plan status was never updated
- nvim task 78: plan shows `[NOT STARTED]`, task is `planned` — correct (implementation hasn't started)

**Root cause**: Plan file status updates depend on `update-plan-status.sh`, which is only called by `update-task-status.sh` Phase 4 for `implement` and `plan` operations. Tasks that skip the standard pipeline (manual status changes, older commands before the centralized script existed, or orchestrate mode misconfigurations) never get plan status updates.

### 5. Artifact Linking Gaps (Critical)

**nvim project**:
- Task 638 (completed): 3 artifacts on disk (report, plan, summary), 0 tracked in state.json
- Task 639 (completed): 3 artifacts on disk, only 1 tracked (summary only; missing report + plan)
- Task 642 (completed): has artifacts in state.json but missing from TODO.md entries (no Research/Plan/Summary links shown for tasks 642, 646, 643 in the Tasks section)

**cslib project** (worse):
- Task 12: 8 artifacts on disk, 0 tracked in state.json
- Task 31: 8 artifacts on disk, 0 tracked in state.json
- Task 55: 3 artifacts on disk, 0 tracked in state.json
- Task 56: 3 artifacts on disk, 0 tracked in state.json (yet TODO.md links them!)
- Task 65: 4 artifacts on disk, 0 tracked in state.json (research in progress)
- Task 9: 5 on disk, only 1 tracked
- Task 57: 3 on disk, only 1 tracked

**Root cause**: Artifact linking is a multi-step process (update state.json, update TODO.md), and many code paths skip one or both. The `postflight-workflow.sh` updates state.json but the TODO.md linking requires a separate `link-artifact-todo.sh` call. When artifacts are created outside the standard pipeline, they never get linked.

**Key insight for task 648 (generate-todo.sh)**: If TODO.md is generated from state.json, then artifact linking in TODO.md becomes automatic — but only if state.json has all artifacts tracked. The generate-todo.sh script should also do a filesystem scan to detect untracked artifacts as a self-healing measure.

### 6. Report Template Status Assessment

The report-format.md correctly states: "Status metadata belongs in TODO.md and state.json only, not in reports."

However, the template includes **Started** and **Completed** timestamps which partially duplicate `created` and `last_updated` in state.json. These are reasonable to keep in reports since they represent report-level timestamps (when research started/finished), not task-level status.

**Recommendation**: Remove any `- **Status**: [STATUS]` line from the report template if it exists. Keep Started/Completed timestamps as they describe the report's own timeline, not the task's status. The current template is nearly correct — it just needs to ensure no Status field creeps in via agent habits.

### 7. Lazy Directory Creation Assessment

The state-management-schema.md already documents the correct lazy creation pattern:
> Create task directories **lazily** - only when the first artifact is written

Current behavior is inconsistent. The `/meta` and `/task` commands create directories eagerly at task creation time (as seen in the recent task 647-652 creation where `mkdir -p` was called immediately). The research, plan, and implement agents create subdirectories (`reports/`, `plans/`, `summaries/`) when they write artifacts.

**Recommendation**: 
- Task creation commands should NOT create directories — just add the entry to state.json
- The `mkdir -p` should be called by agents when they first write an artifact to the directory
- generate-todo.sh should not depend on directory existence for its operation
- Empty directories should be avoided (they add noise to git)

### 8. Fields in TODO.md Not in state.json Schema

Complete catalog of fields found in TODO.md entries but absent from the state.json schema:

| TODO.md Field | In state.json? | Frequency | Notes |
|---|---|---|---|
| `### {N}. {Title}` heading | No (`project_name` only) | Every task | **Critical gap** |
| `**Research Started**` | No | Rare (task 87) | Legacy field, can derive from artifact timestamps |
| `**Research Completed**` | No | Rare (task 87) | Legacy field, can derive from artifact timestamps |
| `**Parent**` | Partially (`subtasks` exists) | Rare (tasks 36, 37) | References parent task from expansion |
| `**Subtasks**` | Yes (`subtasks` array) | Rare (tasks 12, 31) | Already in schema |
| `**Blocker**` text | No | Rare (tasks 36, 37, 40) | Free-text blocker description |
| `**Changes needed**` | No | Rare (task 641) | Extended description subsection |
| `**Scope**` | No | Rare (tasks 38, 39) | Extended description subsection |

**Recommendation**: 
- `title` → Add as required field (critical)
- `Research Started/Completed` → Drop; derive from artifact timestamps or `created`/`last_updated`
- `Parent` → Add optional `parent_task` integer field for tasks created via `--expand`
- `Blocker` → Add optional `blocker_reason` string field for blocked tasks
- `Changes needed`, `Scope` → These are subsections of the description; keep in `description` field as part of the text
- Existing cslib-only fields: `subtasks` already in schema, `planned` timestamp exists in some tasks

### 9. Proposed Enriched state.json Schema

Based on this audit, the enriched schema adds these fields to the project entry:

```json
{
  "project_number": 647,
  "project_name": "enrich_state_json_schema",
  "title": "Enrich state.json schema to be the single complete source of truth",
  "status": "researching",
  "task_type": "meta",
  "topic": "agent-system",
  "effort": "1-2 hours",
  "created": "2026-06-09T12:00:00Z",
  "last_updated": "2026-06-10T01:00:00Z",
  "dependencies": [],
  "description": "Full description text including any subsections...",
  "parent_task": null,
  "blocker_reason": null,
  "artifacts": [
    {
      "type": "research",
      "path": "specs/647_enrich_state_json_schema/reports/01_team-research.md",
      "summary": "Brief description"
    }
  ],
  "next_artifact_number": 2,
  "session_id": "sess_...",
  "completion_summary": null,
  "roadmap_items": [],
  "memory_candidates": []
}
```

**New required fields**: `title`
**New optional fields**: `parent_task`, `blocker_reason`
**Existing fields to enforce**: `description`, `effort` (always populate, even if estimated)

### 10. Best Practices from 2025-2026 Research

**Schema-Driven Development (SSOT)**:
- A single source of truth means every data element is stored exactly once, with all derived views generated from it
- Benefits: eliminates consistency discrepancies, simplifies maintenance, improves collaboration
- Implementation: centralize schema ownership, avoid multiple components emitting overlapping structures

**Idempotent Regeneration Pattern (from DevOps/IaC)**:
- Define desired state, then regenerate idempotently — no matter how many times you run it, same result
- Configuration drift is eliminated when the derived artifact is always regenerated from source
- Terraform/Ansible model: state file is truth, infrastructure is derived; if drift occurs, regeneration fixes it
- This exactly matches the proposed architecture: state.json is truth, TODO.md is derived

**File-Based AI Agent Systems (2026 trend)**:
- Markdown + JSON is the dominant pattern for AI-assisted task management systems
- DESIGN.md pattern (Google Stitch, 2026): structured Markdown files as contracts between humans and AI agents
- LLMs treat Markdown as a native format — generated views should be regenerated, not manually maintained

**Key insight**: The current dual-write architecture violates SSOT principles. Every field stored in both state.json and TODO.md creates a sync surface. The refactor to state.json-first with TODO.md generation aligns with proven infrastructure-as-code patterns.

## Decisions

- `title` must be a required field in the enriched schema
- `description` must be required and contain the full text (including subsections like Scope, Changes needed)
- `parent_task` and `blocker_reason` should be optional fields for expanded/blocked tasks
- Report template should NOT include a Status field
- Lazy directory creation should be enforced: no `mkdir` at task creation time
- Artifact self-healing: generate-todo.sh should optionally scan filesystem for untracked artifacts

## Recommendations

1. **Add `title` field to all existing tasks** via a migration script that parses TODO.md headings
2. **Backfill `description` and `effort`** for tasks missing them, parsing from TODO.md
3. **Add `parent_task` and `blocker_reason`** optional fields to schema
4. **Remove `Research Started`/`Research Completed`** from TODO.md template — derive from timestamps
5. **Enforce lazy directory creation** in task creation commands (remove eager `mkdir -p`)
6. **Add filesystem artifact scan** to generate-todo.sh as self-healing for untracked artifacts
7. **Update state-management-schema.md** to document `title` as required and the full enriched schema
8. **Create a one-time migration script** (`migrate-todo-to-state.sh`) to backfill all missing fields from existing TODO.md files across projects

## Risks & Mitigations

- **Risk**: Large `description` fields bloat state.json file size
  - **Mitigation**: JSON handles multi-KB strings fine; state.json for 20 tasks with full descriptions would be ~30KB, well within practical limits
- **Risk**: Migration script may fail to parse some TODO.md entries
  - **Mitigation**: Use conservative parsing with fallback to manual review; log unparseable entries
- **Risk**: Breaking change for downstream projects (cslib, BimodalLogic, etc.)
  - **Mitigation**: `title` and new fields are additive; generate-todo.sh should gracefully handle missing fields with fallback to `project_name`

## Appendix

### Status Inconsistency Summary Table

| Project | Task | state.json | Task Order | Task Entry | Plan File |
|---------|------|-----------|------------|------------|-----------|
| nvim | 87 | researched | PLANNED | PLANNED | N/A |
| cslib | 57 | completed | PLANNED | COMPLETED | NOT STARTED |
| cslib | 56 | completed | N/A | COMPLETED | IN PROGRESS |
| cslib | 31 | expanded | N/A | N/A | IN PROGRESS |
| cslib | 12 | expanded | N/A | EXPANDED | PARTIAL |
| nvim | 638 | completed | N/A | COMPLETED | NOT STARTED |

### Artifact Tracking Gap Summary

| Project | Task | On Disk | In state.json | In TODO.md | Gap |
|---------|------|---------|---------------|------------|-----|
| cslib | 12 | 8 | 0 | partial | Total gap |
| cslib | 31 | 8 | 0 | N/A | Total gap |
| cslib | 55 | 3 | 0 | 2 linked | state.json gap |
| cslib | 56 | 3 | 0 | 2 linked | state.json gap |
| cslib | 57 | 3 | 1 | 0 | Partial both |
| cslib | 65 | 4 | 0 | 0 | In progress |
| nvim | 638 | 3 | 0 | 0 | Total gap |
| nvim | 639 | 3 | 1 | 3 linked | state.json gap |

Sources:
- [Schema-Driven Development: A Modern Approach](https://blog.noclocks.dev/schema-driven-development-and-single-source-of-truth-essential-practices-for-modern-developers)
- [How to Establish a Single Source of Truth (SSOT) in 2026](https://www.thoughtspot.com/data-trends/best-practices/single-source-of-truth)
- [Idempotent Configuration Management](https://www.techtarget.com/searchitoperations/tip/Idempotent-configuration-management-sets-things-right-no-matter-what)
- [DESIGN.md: AI Agent Design Systems (2026)](https://noqta.tn/en/blog/design-md-systeme-design-agents-ia-markdown-2026)
- [All You Need Is Markdown and JSON](https://mfyz.com/all-you-need-is-markdown-and-json/)
