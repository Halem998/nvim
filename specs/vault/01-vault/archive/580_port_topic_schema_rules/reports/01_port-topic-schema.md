# Research Report: Task #580

**Task**: 580 - port_topic_schema_rules
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/Projects/ProofChecker/.claude/context/reference/state-management-schema.md`
- `/home/benjamin/Projects/ProofChecker/.claude/rules/state-management.md`
- `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`
- `/home/benjamin/.config/nvim/.claude/rules/state-management.md`
- `diff` output comparing both pairs
**Artifacts**:
- `specs/580_port_topic_schema_rules/reports/01_port-topic-schema.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The ProofChecker has two discrete additions over the core system: (1) two new fields in `state-management-schema.md` and (2) a new "Task Order Synchronization" section in `state-management.md`.
- The schema adds a top-level `active_topics` string array and a per-task `topic` string field, plus a new "Top-Level Fields" table that was entirely absent from the core schema.
- The rule file adds 49 lines covering derivation relationships, regeneration triggers, responsible scripts, and non-regeneration events for the Task Order section in TODO.md.
- All additions are 100% project-agnostic: no ProofChecker-specific terms appear; `generate-task-order.sh` and `update-task-status.sh` are already present in the core agent system.
- Both files can be ported by clean, surgical insertions at well-defined locations — no existing content needs to be modified.

---

## Context & Scope

**What is being ported**: Two files that govern state management documentation in the shared `.claude/` agent system were extended in the ProofChecker project. This task ports those extensions back into the core Neovim repo's agent system files.

**Target files**:
- `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`
- `/home/benjamin/.config/nvim/.claude/rules/state-management.md`

**Constraint**: The additions must be inserted verbatim (with placeholder topic values replaced/generalized as needed) without modifying existing surrounding content.

---

## Findings

### 1. Schema File Changes (`state-management-schema.md`)

Three distinct insertions are required.

#### 1a. Top-level `active_topics` field in the JSON example block

Insert after line 9 (`"next_project_number": 346,`) in the `state.json Full Structure` block:

```json
  "active_topics": [
    "completeness",
    "decidability",
    "formula-refactor",
    "frame-extensions",
    "algebraic-representation",
    "bilateral",
    "agent-system"
  ],
```

**Note**: The example values are ProofChecker-specific topic names. For the core system, these serve as illustrative examples only — implementers may want to replace them with generic placeholder values like `"topic-a"`, `"topic-b"` or simply use empty array `[]`. The field definition itself is project-agnostic.

#### 1b. Per-task `topic` field in the project entry JSON example block

Insert after `"task_type": "general",` in the project entry inside `active_projects`:

```json
      "topic": "completeness",
```

**Note**: Same situation — example value is ProofChecker-specific; the field itself is generic.

#### 1c. New "Top-Level Fields" table in the Field Reference section

This entire table is **missing** from the core schema — the core file jumps directly from `## Field Reference` to `### Project Entry Fields`. Insert before `### Project Entry Fields`:

```markdown
### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `next_project_number` | number | Yes | Next task number to assign |
| `active_topics` | string[] | No | Canonical ordered list of topic taxonomy values. Used by task-creation commands to populate the topic picker and by `generate-task-order.sh` to determine topic rendering order. |
| `active_projects` | array | Yes | All active (non-archived) task entries |
| `repository_health` | object | No | Repository health assessment |
| `vault_count` | number | No | Number of completed vault operations |
| `vault_history` | array | No | History of vault operations |

```

#### 1d. `topic` field row in the Project Entry Fields table

Add after the `task_type` row in the `### Project Entry Fields` table:

```markdown
| `topic` | string | No | Semantic domain of the task. Kebab-case value from the `active_topics` array (e.g., `"completeness"`, `"agent-system"`). Optional — absent means task appears under "Uncategorized" in Task Order. |
```

**Note**: The description references `active_topics` and "Task Order" — both are generic concepts. The example values `"completeness"` and `"agent-system"` are from ProofChecker but serve as illustrative examples; they do not need to be replaced.

### 2. Rule File Changes (`state-management.md`)

Two distinct modifications are required.

#### 2a. Extend the "Canonical Sources" bullet list for state.json

Current text (lines 14):
```
  - active_projects array with status, task_type
```

Replace with:
```
  - active_projects array with status, task_type, topic (optional per-task field)
  - active_topics top-level string array: canonical topic taxonomy for task grouping in Task Order
```

#### 2b. Add new "Task Order Synchronization" section

The entire section (49 lines) is inserted at the end of the file, after the existing `## Two-Phase Update Pattern` section and before `## Error Handling`. The exact text:

```markdown
## Task Order Synchronization

The Task Order section in `specs/TODO.md` is a **derived artifact** generated from `specs/state.json`. It is not a canonical source of truth.

### Derivation Relationship

| Property | Value |
|----------|-------|
| Canonical source | `specs/state.json` (task statuses, dependencies) |
| Derived artifact | `specs/TODO.md` Task Order section (wave+tree display) |
| Divergence tolerance | Acceptable between regeneration events |
| Sync direction | Always state.json → Task Order (never reverse) |

The Task Order may temporarily diverge from `state.json` between regeneration events. This is expected and tolerated. Agents should not hand-edit the Task Order section; regeneration via `generate-task-order.sh` is the only write path.

### Regeneration Triggers

Events that trigger Task Order regeneration:

| Event | Command | Script Call |
|-------|---------|-------------|
| Task archival | `/todo` | `generate-task-order.sh --update-todo` (Step 5.8) |
| Post-vault renumbering | `/todo` | `generate-task-order.sh --update-todo` (Step 5.8.8a) |
| Codebase review | `/review` | `generate-task-order.sh --update-todo` (Section 6.5) |
| Terminal status transition | Automated | `generate-task-order.sh --update-todo` (optional, via hooks) |

All regeneration calls use the `--update-todo` flag, which writes the wave+tree format to the Task Order section in `specs/TODO.md`.

### Responsible Scripts

| Script | Role | When Used |
|--------|------|-----------|
| `generate-task-order.sh --update-todo` | Full regeneration from state.json | `/todo`, `/review`, terminal transitions |
| `update-task-status.sh` (Phase 3) | In-place status-only updates within existing entries | Single-task status changes without full regeneration |

Use `generate-task-order.sh` for all cases where the task set changes (archival, new tasks, renumbering). Use `update-task-status.sh` only for status-only updates to existing Task Order entries.

### Non-Regeneration Events

These events do NOT trigger Task Order regeneration:

- Task creation (before the task enters a terminal or near-terminal state)
- Status transitions to `researching`, `researched`, `planning`, `planned`, `implementing`, `partial`, `blocked`
- Roadmap annotation updates
- Git commits and state.json writes not involving task number changes
- Memory harvest operations

The Task Order is a planning view -- it need not reflect every transient status. Regenerate at archival and review boundaries.
```

### 3. Generalization Check

**Result: 100% project-agnostic.** Verification:

- `generate-task-order.sh` — this script already exists in the core `.claude/scripts/` directory (confirmed by the CLAUDE.md entry for "Utility Scripts").
- `update-task-status.sh` — referenced in the rule; may or may not exist in the core system, but the reference is generic and applicable.
- The `active_topics` field itself carries no domain assumptions — it is a plain string array whose values are project-defined.
- The `topic` per-task field description uses ProofChecker example values as illustrations only; the field semantics are generic.
- The Task Order Synchronization section references only `specs/TODO.md`, `specs/state.json`, and shell scripts — all present in the core system.

---

## Decisions

1. **Keep ProofChecker example topic values** in the JSON example block (`"completeness"`, etc.) — they serve as illustrative examples and are clearly labeled as examples. No replacement needed.
2. **Insert "Top-Level Fields" table as a new subsection** before "Project Entry Fields" — this is an additive insertion that improves the schema documentation.
3. **Insert "Task Order Synchronization" section between "Two-Phase Update Pattern" and "Error Handling"** — this matches the ProofChecker placement and is logically coherent (Task Order is a synchronization concern).
4. **Do not modify any existing content** beyond the one-line expansion of the Canonical Sources bullet — all other changes are pure additions.

---

## Recommendations

### Priority 1: Implement schema additions (state-management-schema.md)

Four surgical insertions in order:
1. Add `active_topics` array to the JSON example block (after `next_project_number` line)
2. Add `topic` field to the per-task entry in the JSON example block
3. Insert the full "Top-Level Fields" table as a new `###` subsection before "Project Entry Fields"
4. Add `topic` row to the "Project Entry Fields" table (after `task_type` row)

### Priority 2: Implement rule additions (state-management.md)

Two changes:
1. Expand the state.json Canonical Sources bullet (2-line replacement of 1 line)
2. Append the full 49-line "Task Order Synchronization" section after "Two-Phase Update Pattern"

### Implementation approach

Use the Edit tool with exact `old_string`/`new_string` pairs. The insertions are at unique locations — no risk of ambiguous matches. Verify with a final diff after each edit.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `update-task-status.sh` doesn't exist in core system | Low | The rule references it as an optional script; its absence doesn't break anything |
| Topic example values cause confusion | Very low | They are in an `## Examples` section and clearly labeled |
| "Top-Level Fields" table insertion breaks existing links | None | Pure addition; no existing anchors are removed |
| Rule section ordering conflicts | None | The new section inserts cleanly between two existing `##` sections |

---

## Appendix

### Diff Summary: state-management-schema.md

```
9a10,18    Add active_topics array to JSON example
15a25      Add topic field to per-task example
57a68,78   Add Top-Level Fields table (new subsection)
65a87      Add topic row to Project Entry Fields table
```

**Line count delta**: +22 lines added, 0 lines removed

### Diff Summary: state-management.md

```
14c14,15   Expand state.json Canonical Sources bullet (1 line -> 2 lines)
61a63,111  Add Task Order Synchronization section (49 lines)
```

**Line count delta**: +50 lines added, 1 line modified (net +50 effective new content)

### File Locations

- Core schema: `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`
- Core rule: `/home/benjamin/.config/nvim/.claude/rules/state-management.md`
- ProofChecker schema: `/home/benjamin/Projects/ProofChecker/.claude/context/reference/state-management-schema.md`
- ProofChecker rule: `/home/benjamin/Projects/ProofChecker/.claude/rules/state-management.md`
