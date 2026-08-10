# Research Report: Enrich state.json Schema as Single Source of Truth

- **Task**: 647 - Enrich state.json schema to be the single complete source of truth
- **Started**: 2026-06-10T01:00:00Z
- **Completed**: 2026-06-10T02:15:00Z
- **Effort**: 1.25 hours (team research, 2 teammates)
- **Dependencies**: None
- **Sources/Inputs**:
  - `specs/state.json` (nvim project, 17 active tasks)
  - `specs/TODO.md` (nvim project)
  - `/home/benjamin/Projects/cslib/specs/state.json` (20 active tasks)
  - `/home/benjamin/Projects/cslib/specs/TODO.md`
  - `.claude/context/reference/state-management-schema.md`
  - `.claude/context/formats/report-format.md`
  - `.claude/rules/state-management.md`
  - `.claude/scripts/update-task-status.sh`, `generate-task-order.sh`, `skill-base.sh`
  - Web research: SSOT patterns, schema-driven development (2025-2026)
- **Artifacts**: This unified report

## Executive Summary

- `title` is absent from 11 of 17 nvim tasks and ALL 20 cslib tasks; it is a critical gap that prevents TODO.md heading generation and must be added as a required schema field immediately.
- `description` and `title` are both used in practice but neither appears in the official `state-management-schema.md` field reference — they are undocumented conventions that must be formalized.
- Status drift is confirmed across all three layers (state.json, TODO.md entry, plan file); the root cause is a narrow plan-status trigger matrix that only fires on `implement:*` and `plan:postflight` operations, leaving orchestrate/manual paths permanently stale.
- Artifact tracking gaps are severe (5 cslib tasks have zero tracked artifacts despite 3-8 files on disk); the SSOT architecture fully resolves this only if all artifact creation paths write to state.json atomically.
- The Critic confirms Teammate A's findings are accurate and adds three substantive corrections: `parent_task`/`blocker_reason` fields are low-value and should be skipped; filesystem artifact scanning in generate-todo.sh mixes rendering and repair concerns; and script fallback chains need updating before `title` can be consumed.

## Context & Scope

This report synthesizes a cross-project audit of the nvim (17 tasks) and cslib (20 tasks) agent systems to identify all fields present in TODO.md but absent from state.json, catalog status inconsistencies across state layers, assess artifact tracking gaps, and define an enriched schema sufficient for complete TODO.md generation. The focus includes lazy directory creation patterns, plan status drift root causes, report template status handling, and 2025-2026 best practices for SSOT task management systems.

## Findings

### 1. Missing `title` Field (Critical)

state.json stores `project_name` (snake_case slug) but no human-readable title. Titles currently live only in TODO.md headings (`### {N}. {Title}`).

- **nvim**: 11 of 17 tasks missing title (tasks 638-646, 78, 87). The 6 newest tasks (647-652) have title because it was added during creation.
- **cslib**: ALL 20 tasks missing the title field entirely.
- **Impact**: Without `title`, generate-todo.sh cannot produce `### {N}. {Title}` headings. The `project_name` slug loses capitalization, acronyms (SMTP, OAuth), and natural phrasing.
- **Action**: Add `title` as a required field. Backfill from TODO.md headings via migration script. Capture at task creation time going forward.

### 2. `title` and `description` Missing from Official Schema (Critical)

Neither `title` nor `description` appears in the `state-management-schema.md` Project Entry Fields table, despite both being used in practice (16 of 17 nvim tasks have `description`). These are undocumented conventions, not formally specified fields.

- **Impact**: Agents and scripts cannot rely on the schema reference for field existence, type, or required/optional designation.
- **Action**: Add both fields to the official schema reference with explicit required/optional designation and type documentation.

### 3. Status Inconsistencies Across Three Layers (Critical)

Status drift is confirmed across state.json, TODO.md task entries, and plan files:

| Project | Task | state.json | TODO.md Entry | Plan File |
|---------|------|-----------|---------------|-----------|
| nvim | 87 | researched | PLANNED | N/A |
| cslib | 57 | completed | PLANNED (Task Order) | NOT STARTED |
| cslib | 56 | completed | COMPLETED | IN PROGRESS |
| cslib | 31 | expanded | N/A | IN PROGRESS |
| cslib | 12 | expanded | EXPANDED | PARTIAL |
| nvim | 638 | completed | COMPLETED | NOT STARTED |

**Root cause**: The plan status trigger matrix is narrow. `update-plan-status.sh` fires only for `implement:preflight`, `implement:postflight`, and `plan:postflight`. Research operations, `plan:preflight`, manual completions, and orchestrate paths never trigger plan status updates. Any task reaching `completed` outside the standard implement pipeline retains stale plan status permanently.

**Task Order drift** (cslib task 57) occurs when Task Order regeneration ran before the task was completed and was never re-triggered — exactly the type of drift the proposed SSOT architecture would eliminate.

### 4. Artifact Tracking Gaps (High)

Artifact tracking is severely incomplete across both projects:

| Project | Task | On Disk | In state.json | Gap Type |
|---------|------|---------|---------------|----------|
| cslib | 12 | 8 | 0 | Total gap |
| cslib | 31 | 8 | 0 | Total gap |
| cslib | 55 | 3 | 0 | state.json gap |
| cslib | 56 | 3 | 0 | state.json gap |
| nvim | 638 | 3 | 0 | Total gap |
| nvim | 639 | 3 | 1 | Partial gap |

**Root cause**: Artifact linking is a multi-step path (state.json update + TODO.md `link-artifact-todo.sh` call). Code paths that create artifacts outside the standard pipeline (pre-centralization scripts, bootstrapped orchestration, manual creation) never trigger both steps. Under the SSOT architecture, tracking in state.json becomes the single write path — but only if all artifact creation routes through it atomically.

### 5. Plan Status Trigger Matrix Is Incomplete (Medium)

The plan status trigger matrix has specific blind spots beyond the general drift problem:

| Operation | Plan Status Set | Issue |
|-----------|----------------|-------|
| research:preflight/postflight | (none) | Expected — no plan exists yet |
| plan:preflight | (none) | Arguably should set PLANNING |
| plan:postflight | PLANNED | Correct |
| implement:preflight | IMPLEMENTING | Correct |
| implement:postflight | COMPLETED | Correct |
| revise:* | (none) | Revise creates new plan file |
| manual / orchestrate shortcut | (none) | Plan status permanently stale |

The `plan:preflight` case silently skips status update, meaning a plan being actively written shows no in-progress indicator. The orchestrate/manual gap is more impactful in practice.

### 6. Schema Fields Present in TODO.md but Absent from state.json

Complete catalog of fields found in TODO.md entries that have no state.json equivalent:

| TODO.md Field | In state.json? | Frequency | Priority |
|---|---|---|---|
| `### {N}. {Title}` heading | No | Every task | Critical |
| `description` | Informal (not in schema) | Most tasks | Critical |
| `effort` | Informal (not in schema) | Most nvim tasks | Medium |
| `topic` | Informal (not in schema) | All new tasks | Medium |
| `Research Started/Completed` | No | Rare (task 87) | Low (derive from timestamps) |
| `Parent` link | No (`subtasks` exists on parent) | Rare | Low (skip — see Conflicts) |
| `Blocker` text | No | Rare (3 tasks) | Low (embed in `description`) |
| `Changes needed`, `Scope` | No | Rare subsections | Low (embed in `description`) |

### 7. Lazy Directory Creation Is Inconsistently Applied (Medium)

The schema standard documents lazy directory creation (create task directories only when first artifact is written), but current practice is inconsistent:

- `/meta` and `/task` commands call `mkdir -p` eagerly at task creation time
- Research/plan/implement agents create `reports/`, `plans/`, `summaries/` subdirectories on first write
- `skill_create_postflight_marker()` in `skill-base.sh` calls `mkdir -p "$task_dir"` for the postflight marker — this is a hard constraint: directory creation cannot be deferred past the postflight marker stage

**Recommendation**: Task creation commands should NOT create the task directory. The postflight marker write (first event requiring the directory) is the natural earliest creation point. Generate-todo.sh must not depend on directory existence.

### 8. Script Fallback Chains Need Updating Before `title` Is Useful

Adding `title` to state.json is additive and safe — no existing script breaks. However, until scripts are updated, the new field sits unused:

- `generate-task-order.sh` uses `(.description // .project_name) | .[0:65]` — does not see `title`
- The correct fallback chain once `title` is added: `(.title // .description // .project_name)`
- 51 references to `project_name` exist across scripts; most are correct (path construction) and should NOT be changed to `title`; only display-text paths need updating

**Key distinction**: `project_name` remains the directory slug (filesystem paths). `title` is display-only.

### 9. Report Template Status Handling

The current report-format.md correctly states "Status metadata belongs in TODO.md and state.json only, not in reports." The template includes `Started`/`Completed` timestamps, which are report-level (when the research work happened), not task-level status — these are distinct from `created`/`last_updated` in state.json, which track the task lifecycle. No change needed to the template.

### 10. SSOT Best Practices Alignment (2025-2026)

The proposed architecture (state.json as truth, TODO.md as derived output) aligns with established patterns:
- **Infrastructure-as-Code idempotence**: Terraform/Ansible model — state file is truth, infrastructure is derived. Regeneration always produces the same output from the same state.
- **Schema-Driven Development**: Centralizing schema ownership eliminates consistency discrepancies across derived views.
- **DESIGN.md pattern (2026)**: Markdown + JSON as contracts between humans and AI agents, where LLM-generated views are regenerated rather than manually maintained.

## Decisions

- `title` is a required field in the enriched schema. Backfill from TODO.md headings for existing tasks.
- `description` is a required field. Formalize in `state-management-schema.md`. Store full text including subsections (Scope, Changes needed, Blocker) — JSON strings handle multiline via `\n`.
- `parent_task` and `blocker_reason` as separate fields are NOT added. Blocker text belongs in `description`; parent relationship can be derived from `subtasks` arrays on parent entries.
- Filesystem artifact scan is NOT added to generate-todo.sh. A separate `reconcile-artifacts.sh` audit script is the correct approach.
- `Started`/`Completed` timestamps remain in report template — they are report-level metadata, not task status.
- Lazy directory creation should defer to postflight marker stage (first real write event), not task creation time.
- Schema version should be bumped to `"1.1.0"` to signal the schema enrichment to downstream scripts.

## Recommendations

1. **Formalize `title` and `description` in `state-management-schema.md`** — add both to the Project Entry Fields table with required designation, type (string), and examples.
2. **Add `title` to all existing tasks via migration script** (`migrate-todo-to-state.sh`) parsing TODO.md headings; make project-agnostic to handle nvim, cslib, and other projects.
3. **Backfill `description`, `effort`, and `topic`** for tasks missing them, parsing from TODO.md.
4. **Update script fallback chains before relying on `title`** — update `generate-task-order.sh` to use `(.title // .description // .project_name) | .[0:65]`; document the change.
5. **Bump schema version to "1.1.0"** and add version-aware field handling to scripts consuming new fields.
6. **Enforce lazy directory creation** — remove eager `mkdir -p` from `/task` and `/meta` commands; rely on postflight marker as the earliest creation point.
7. **Create `reconcile-artifacts.sh`** as a standalone audit tool to detect and optionally repair artifact tracking gaps — keep this separate from generate-todo.sh.
8. **Drop `Research Started`/`Research Completed`** from TODO.md legacy template — derive from `created`/`last_updated` timestamps or artifact timestamps.
9. **Update plan status trigger matrix** to fire on non-standard completion paths (orchestrate, manual) — add a `complete:*` trigger that always sets plan status to COMPLETED.

## Risks & Mitigations

- **Risk**: Large `description` fields bloat state.json
  - **Mitigation**: JSON handles multi-KB strings; 20 tasks with full descriptions = ~30KB, well within practical limits
- **Risk**: Migration script fails on diverse TODO.md formats across projects
  - **Mitigation**: Use conservative parsing with fallback to manual review; log all unparseable entries; make migration idempotent (skip tasks already having `title`)
- **Risk**: Breaking change for cslib and other downstream projects
  - **Mitigation**: All new fields are additive; generate-todo.sh should use fallback chains gracefully handling missing fields
- **Risk**: `parent_task` reference is needed but embedded in `description` text is hard to parse
  - **Mitigation**: If machine-readable parent references are needed later, add the field then; current frequency (4 tasks across two projects) does not justify the maintenance cost now

## Context Extension Recommendations

- **Topic**: state-management-schema.md completeness
- **Gap**: `title`, `description`, `effort`, and `topic` are used in practice but not documented in the official schema reference, creating a divergence between spec and implementation
- **Recommendation**: Update `state-management-schema.md` as part of task 647 implementation to add all four fields to the Project Entry Fields table

## Appendix

### Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary audit (cross-project field and status gap analysis) | completed | high |
| C | Critic (verification, challenged assumptions, script compatibility) | completed | high |

### Teammate A Key Contributions
- Quantified field gaps across both projects (11/17 nvim, 20/20 cslib missing `title`)
- Identified 6 status inconsistency instances with root-cause analysis
- Catalogued all TODO.md fields absent from state.json schema
- Proposed enriched schema with concrete JSON examples
- Validated SSOT architecture against IaC and schema-driven development patterns

### Teammate C Key Contributions (Critic)
- Verified all Teammate A claims via direct grep — all confirmed accurate
- Identified critical gap: `description` and `title` are not in official `state-management-schema.md`
- Challenged `parent_task`/`blocker_reason` fields as low-value (adopted: skip these fields)
- Challenged filesystem scan in generate-todo.sh as mixing rendering and repair (adopted: separate script)
- Provided detailed plan status trigger matrix showing exact blind spots
- Identified `skill_create_postflight_marker()` constraint on lazy directory creation
- Quantified script update scope: 51 `project_name` references; categorized which need `title` fallback

### Sources

- [Schema-Driven Development: A Modern Approach](https://blog.noclocks.dev/schema-driven-development-and-single-source-of-truth-essential-practices-for-modern-developers)
- [How to Establish a Single Source of Truth (SSOT) in 2026](https://www.thoughtspot.com/data-trends/best-practices/single-source-of-truth)
- [Idempotent Configuration Management](https://www.techtarget.com/searchitoperations/tip/Idempotent-configuration-management-sets-things-right-no-matter-what)
- [DESIGN.md: AI Agent Design Systems (2026)](https://noqta.tn/en/blog/design-md-systeme-design-agents-ia-markdown-2026)
- [All You Need Is Markdown and JSON](https://mfyz.com/all-you-need-is-markdown-and-json/)
- `.claude/scripts/update-task-status.sh` — plan status trigger matrix analysis
- `.claude/scripts/generate-task-order.sh` — fallback chain discovery
- `.claude/scripts/skill-base.sh` — postflight marker directory constraint
- `specs/state.json`, `specs/TODO.md` — nvim project (direct inspection)
- `/home/benjamin/Projects/cslib/specs/state.json`, `TODO.md` — cslib project (direct inspection)
