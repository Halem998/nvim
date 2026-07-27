# Status Markers Convention

**Status**: Active  
**Created**: 2026-01-05  
**Purpose**: Single source of truth for status markers across TODO.md and state.json

---

## Overview

This document defines the complete set of status markers used throughout this agent system for tracking task and phase progress. It serves as the authoritative reference for:

- **Status Marker Definitions**: All valid status markers and their meanings
- **TODO.md Format**: How markers appear in TODO.md task entries
- **state.json Format**: How status values appear in state.json
- **Valid Transitions**: Which status changes are allowed
- **Command Mappings**: Which commands trigger which status changes

---

## Status Marker Definitions

### Standard Status Markers

#### `[NOT STARTED]`
**TODO.md Format**: `- **Status**: [NOT STARTED]`  
**state.json Value**: `"status": "not_started"`  
**Meaning**: Task or phase has not yet begun.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

#### `[RESEARCHING]`
**TODO.md Format**: `- **Status**: [RESEARCHING]`  
**state.json Value**: `"status": "researching"`  
**Meaning**: Research is actively underway.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[RESEARCHED]`.

**Timestamps**: Always include `- **Researched**: YYYY-MM-DD` when started

#### `[RESEARCHED]`
**TODO.md Format**: `- **Status**: [RESEARCHED]`  
**state.json Value**: `"status": "researched"`  
**Meaning**: Research completed, deliverables created.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Artifacts**: Research report linked in TODO.md

#### `[PLANNING]`
**TODO.md Format**: `- **Status**: [PLANNING]`  
**state.json Value**: `"status": "planning"`  
**Meaning**: Implementation plan is being created.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[PLANNED]`.

**Timestamps**: Always include `- **Planned**: YYYY-MM-DD` when started

#### `[PLANNED]`
**TODO.md Format**: `- **Status**: [PLANNED]`  
**state.json Value**: `"status": "planned"`  
**Meaning**: Implementation plan completed, ready for implementation.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Artifacts**: Implementation plan linked in TODO.md

#### `[REVISING]`
**TODO.md Format**: `- **Status**: [REVISING]`  
**state.json Value**: `"status": "revising"`  
**Meaning**: Plan revision is in progress.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[REVISED]`.

**Timestamps**: Always include `- **Revised**: YYYY-MM-DD` when started

#### `[REVISED]`
**TODO.md Format**: `- **Status**: [REVISED]`  
**state.json Value**: `"status": "revised"`  
**Meaning**: Plan revision completed, new plan version created.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Artifacts**: Revised plan linked in TODO.md (replaces previous plan link)

#### `[IMPLEMENTING]`
**TODO.md Format**: `- **Status**: [IMPLEMENTING]`  
**state.json Value**: `"status": "implementing"`  
**Meaning**: Implementation work is actively underway.

**Valid Transitions**: Non-terminal; any command can run. Normally completes to `[COMPLETED]` or `[PARTIAL]`.

**Timestamps**: Always include `- **Implemented**: YYYY-MM-DD` when started

#### `[COMPLETED]`
**TODO.md Format**: `- **Status**: [COMPLETED]`  
**state.json Value**: `"status": "completed"`  
**Meaning**: Task is finished successfully.

**Valid Transitions**: Terminal state (no further transitions)

**Required Information**:
- `- **Completed**: YYYY-MM-DD` timestamp
- Do not add emojis; rely on status marker and text alone

#### `[PARTIAL]`
**TODO.md Format**: `- **Status**: [PARTIAL]`  
**state.json Value**: `"status": "partial"`  
**Meaning**: Implementation partially completed (can resume).

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

#### `[BLOCKED]`
**TODO.md Format**: `- **Status**: [BLOCKED]`  
**state.json Value**: `"status": "blocked"`  
**Meaning**: Task is blocked by dependencies or issues.

**Valid Transitions**: Any command (research, plan, implement, revise) can run from this status.

**Required Information**:
- `- **Blocked**: YYYY-MM-DD` timestamp
- `- **Blocking Reason**: {reason}` or `- **Blocked by**: {dependency}`

#### `[ABANDONED]`
**TODO.md Format**: `- **Status**: [ABANDONED]`  
**state.json Value**: `"status": "abandoned"`  
**Meaning**: Task was started but abandoned without completion.

**Valid Transitions**: Terminal state. No further transitions (use `/task --recover` to restart).

**Required Information**:
- `- **Abandoned**: YYYY-MM-DD` timestamp
- `- **Abandonment Reason**: {reason}`

---

### Plan-level vs. phase-level markers

The full marker set above is the **task-level** vocabulary (TODO.md / state.json). Plan artifacts
use a related but narrower vocabulary at two further grains, and the differences between all
three are intentional:

- **Plan-level Status field** (the single `- **Status**:` line in a plan artifact's metadata
  block) uses the subset `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`.
- **Phase-heading markers** (`### Phase N: {name} [STATUS]`) are scoped to a single phase within
  a plan and never include `ABANDONED` — see plan-format.md's Implementation Phases format.
  Alongside `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, and `[BLOCKED]`, the
  phase-heading vocabulary also includes `[COMPLETED WITH EXCLUSIONS]` (see below) — a
  phase-heading marker only, absent from both the task-level vocabulary above and the plan-level
  Status subset.

See plan-format.md's "Plan-level vs. phase-level markers" subsection (under Status Marker
Requirements) for the full rationale: `ABANDONED` is deliberately plan/task-level only (no code
path abandons a single phase while leaving siblings active), and plan-level `PARTIAL` is an
aggregate whole-document signal distinct from, and compatible with, an individual phase heading
carrying its own `[PARTIAL]`.

---

#### `[COMPLETED WITH EXCLUSIONS]` (phase-heading marker only)

A third terminal phase-heading outcome, distinct from both plain outcomes on either side of it:

- `[COMPLETED]` — nothing was excluded; every planned item was done.
- `[PARTIAL]` — work remains and is resumable; a future dispatch is expected to continue it.
- `[COMPLETED WITH EXCLUSIONS]` — every remaining item was **decided, justified, and will not be
  revisited**. Nothing is left for a future dispatch to pick up; the phase is closed, not stalled.

This outcome is a **generalization of the existing strategic-sorry mechanism**
(`context/contracts/anti-analysis.md`'s "Strategic sorries" section), not a second, competing
mechanism. Both are members of one documented family — "documented incompleteness that still
counts as success" — differing on exactly one axis: a strategic sorry is *deferred with a
tracked follow-up* (`sorry_inventory.follow_up_task` is non-null), while a reasoned exclusion is
*decided and will not be revisited* (no follow-up field exists at all). See
`context/contracts/anti-analysis.md` for the cross-reference in the other direction.

**Character-class constraint**: the phase-accounting TOTAL regex in
`scripts/update-task-status.sh`'s `count_plan_phases()` is `[A-Z][A-Z ]*` — uppercase letters and
spaces only. Any phase-heading marker text, including this one, must satisfy that class exactly;
a name containing a dash, digit, or parenthesis silently falls out of the denominator. This is
why the chosen marker text is `COMPLETED WITH EXCLUSIONS` rather than a hyphenated or
parenthetical variant.

**Admission test**: A phase may close as `[COMPLETED WITH EXCLUSIONS]` only when ALL five
conditions hold — this is a direct, mode-neutral and task-type-neutral generalization of the
five-condition strategic-sorry test in `context/contracts/anti-analysis.md`:

1. **Decision, not abandonment**: The exclusion is a deliberate decision that the remaining
   item(s) are not applicable — not a stuck or abandoned attempt.
2. **Tightly scoped**: The exclusion is scoped to specific, enumerated items — never "the rest of
   the phase."
3. **Documented reason**: Each excluded item carries a stated reason.
4. **Evidenced**: Each reason carries evidence — command output, a quoted match count, a diff
   excerpt, or an artifact reference confirming it.
5. **No residual work**: Nothing remains that a future dispatch would need to do. This is exactly
   why no follow-up task is recorded — there is nothing to hand off.

Failing any one of these five conditions means the phase is `[PARTIAL]`, not exclusion-closed.
See `context/formats/plan-format.md`'s `#### Reasoned Exclusions` record format for the required
per-item record, and `context/contracts/anti-analysis.md` for the strategic-sorry counterpart.

---

#### `[EXPANDED]`
**TODO.md Format**: `- **Status**: [EXPANDED]`
**state.json Value**: `"status": "expanded"`
**Meaning**: Parent task has been expanded into subtasks; work continues in subtasks.

**Valid Transitions**: Terminal state. No further transitions (work continues in subtasks).

**Note**: Any non-terminal status can transition to `[EXPANDED]` when task is divided.

**Required Information**:
- `- **Subtasks**: {list}` in TODO.md
- `"subtasks": [...]` array in state.json

---

## TODO.md vs state.json Mapping

| TODO.md Marker | state.json Value | Description |
|----------------|------------------|-------------|
| `[NOT STARTED]` | `not_started` | Task not begun |
| `[RESEARCHING]` | `researching` | Research in progress |
| `[RESEARCHED]` | `researched` | Research completed |
| `[PLANNING]` | `planning` | Planning in progress |
| `[PLANNED]` | `planned` | Plan created |
| `[REVISING]` | `revising` | Plan revision in progress |
| `[REVISED]` | `revised` | Plan revision completed |
| `[IMPLEMENTING]` | `implementing` | Implementation in progress |
| `[COMPLETED]` | `completed` | Task fully completed |
| `[PARTIAL]` | `partial` | Implementation partially complete |
| `[BLOCKED]` | `blocked` | Task blocked |
| `[ABANDONED]` | `abandoned` | Task abandoned |
| `[EXPANDED]` | `expanded` | Task expanded into subtasks |

**Conversion Rules**:
- TODO.md uses uppercase with underscores in brackets: `[NOT STARTED]`
- state.json uses lowercase with underscores: `"not_started"`
- Conversion: Remove brackets, convert to lowercase

---

## Command → Status Mapping

| Command | Preflight Status | Postflight Status | Notes |
|---------|------------------|-------------------|-------|
| `/research` | `[RESEARCHING]` | `[RESEARCHED]` | Creates research report |
| `/plan` | `[PLANNING]` | `[PLANNED]` | Creates implementation plan |
| `/revise` | `[REVISING]` | `[REVISED]` | Creates new plan version |
| `/implement` | `[IMPLEMENTING]` | `[COMPLETED]` or `[PARTIAL]` | Executes implementation |
| `/review` | N/A | N/A | Creates new tasks |

**Preflight**: Status updated BEFORE work begins  
**Postflight**: Status updated AFTER work completes

---

## Valid Transition Diagram

```
                    ┌─────────────────────────────────────────┐
                    │         Any Non-Terminal Status          │
                    │                                         │
                    │  NOT STARTED, RESEARCHING, RESEARCHED,  │
                    │  PLANNING, PLANNED, REVISING, REVISED,  │
                    │  IMPLEMENTING, PARTIAL, BLOCKED         │
                    └──────────────┬──────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
              ▼                    ▼                     ▼
        /research             /plan, /revise        /implement
              │                    │                     │
              ▼                    ▼                     ▼
        [RESEARCHING]        [PLANNING]           [IMPLEMENTING]
              │               [REVISING]                │
              ▼                    │              ┌──────┴──────┐
        [RESEARCHED]               ▼              ▼             ▼
                             [PLANNED]       [COMPLETED]   [PARTIAL]
                             [REVISED]

    Terminal states (no further transitions):
    [COMPLETED], [ABANDONED], [EXPANDED]
```

---

## Status Update Protocol

Status updates are performed by `skill-base.sh` functions that all workflow skills source:

- `skill_preflight_update()` -- called BEFORE work begins. Sets the in-progress status variant (e.g., `[RESEARCHING]`, `[IMPLEMENTING]`) in both `state.json` and `TODO.md`.
- `skill_postflight_update()` -- called AFTER work completes. Sets the final status variant (e.g., `[RESEARCHED]`, `[COMPLETED]`) and links artifacts.

Both functions delegate to `update-task-status.sh` for the actual atomic file updates.

For manual corrections and recovery operations outside the normal workflow, use the `skill-status-sync` skill, which provides standalone preflight, postflight, and artifact-link operations.

### Preflight Status Update

**When**: BEFORE work begins  
**Path**: `skill_preflight_update()` in `skill-base.sh` -> `update-task-status.sh`  
**Purpose**: Signal work has started  
**Example**: `/research` calls `skill_preflight_update()` to set `[RESEARCHING]` before beginning research

### Postflight Status Update

**When**: AFTER work completes  
**Path**: `skill_postflight_update()` in `skill-base.sh` -> `update-task-status.sh`  
**Purpose**: Signal work has finished and link artifacts  
**Example**: `/research` calls `skill_postflight_update()` to set `[RESEARCHED]` after creating research report

---

## Atomic Synchronization

`update-task-status.sh` performs updates atomically in this order:
1. `state.json` (status field, timestamps, artifact_paths)
2. `TODO.md` (status marker, timestamps, artifact links)
3. Plan file (phase status markers, if plan exists)

All files are updated via temp-file + atomic rename so no partial state is written on failure.

---

## Validation Rules

### Status Transition Validation

**Permissive Rule**: Any command can run from any non-terminal status.

**Terminal States** (block all transitions):
- `[COMPLETED]` - No further transitions
- `[ABANDONED]` - No further transitions (use `/task --recover` to restart)
- `[EXPANDED]` - No further transitions (work continues in subtasks)

### Required Fields Validation

**For `[BLOCKED]` status**:
- MUST include `blocking_reason` or `blocked_by` parameter
- MUST include `- **Blocked**: YYYY-MM-DD` timestamp in TODO.md

**For `[ABANDONED]` status**:
- MUST include `abandonment_reason` parameter
- MUST include `- **Abandoned**: YYYY-MM-DD` timestamp in TODO.md

**For `[EXPANDED]` status**:
- MUST include `subtasks` array with subtask numbers
- MUST include `- **Subtasks**: {list}` in TODO.md

**For completion statuses** (`[RESEARCHED]`, `[PLANNED]`, `[REVISED]`, `[COMPLETED]`):
- MUST include `validated_artifacts` array with artifact paths
- Artifacts MUST exist on disk and be non-empty

---

## References

- **state-management.md**: Complete state management standard
- **skill-base.sh**: Source for `skill_preflight_update()` and `skill_postflight_update()` functions
- **update-task-status.sh**: Atomic status update script called by skill-base.sh functions
- **skill-status-sync/SKILL.md**: Standalone skill for manual status corrections and recovery

---

**Last Updated**: 2026-01-05
