# Research Report: Task #746

**Task**: 746 - Enforce Plan Checkbox Tracking During Implementation and Orchestration
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:10:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- `.claude/agents/general-implementation-agent.md`
- `.claude/skills/skill-implementer/SKILL.md`
- `.claude/skills/skill-orchestrate/SKILL.md`
- `.claude/docs/architecture/handoff-schema.md`
- `.claude/rules/plan-format-enforcement.md`
**Artifacts**:
- `specs/746_enforce_plan_checkbox_tracking/reports/01_plan-checkbox-tracking.md`
**Standards**: report-format.md

---

## Executive Summary

- The current self-review gate (Stage 4D-ii in `general-implementation-agent.md`) requires
  reviewing unchecked items and annotating deviations, but does NOT enforce that all `- [ ]`
  items must be checked or annotated before the phase is marked `[COMPLETED]`. It is
  permissive (the agent can choose to skip overlooked items).
- The `skill-implementer` postflight (Stages 6-10) performs summary format validation
  (`validate-artifact.sh`) but performs NO check against plan checkboxes. The postflight
  boundary explicitly forbids source file reads, which currently blocks checkbox validation
  at this layer.
- The orchestrator handoff schema (`handoff-schema.md`) defines `phases_completed` and
  `phases_total` at the top level for drift detection, but has no per-subtask visibility
  (`subtasks_completed`). The orchestrator reads `phases_completed` from the top-level JSON
  (not from `continuation_context`), so adding a top-level field is straightforward.
- Recommended approach: (1) harden Stage 4D-ii to a blocking gate, (2) add a postflight
  plan-checkbox scan in skill-implementer Stage 6/6a as a new Stage 6b-alt (non-blocking
  with auto-fix via Edit), (3) add `subtasks_completed` as an optional top-level field in
  the orchestrator handoff schema and agent writing contract.

---

## Context & Scope

Task 746 requests three enforcement mechanisms to reduce plan checkbox drift:

1. **Harden Stage 4D-ii** — The self-review gate after marking `[COMPLETED]` should block
   progression if any `- [ ]` item has neither been checked nor annotated as a deviation.
2. **Postflight plan-checkbox validation** — After the agent finishes, skill-implementer
   should scan the plan for unchecked items and auto-fix mismatches.
3. **Extend `.orchestrator-handoff.json`** — Add `subtasks_completed: ["1.1", "1.2", ...]`
   for per-subtask visibility when dispatching successors.

Research focused on: exact line locations for all three changes, surrounding context, and
compatibility with the existing postflight boundary restrictions.

---

## Findings

### 1. Current Self-Review Gate (Stage 4D-ii)

**File**: `.claude/agents/general-implementation-agent.md`
**Lines**: 197-226

Current behavior (lines 197-225):
```
After marking a phase [COMPLETED], perform a self-review before proceeding to the next phase:

1. Re-read the phase's task checklist...
2. For each checklist item that remains unchecked:
   - If intentionally skipped or altered, add deviation entry and annotate.
   - If overlooked, evaluate whether it should be completed before proceeding.
3. Record any deviations in the progress file...
4. Annotate the plan checklist inline...
5. Note any skipped items...
Only then proceed to Stage 4D-iii...
```

**Gap**: Step 2 says "evaluate whether it should be completed" for overlooked items — this is
advisory, not blocking. An agent can decide to proceed without checking off items or recording
deviations. The gate needs an explicit HARD REQUIREMENT statement: the phase MUST NOT proceed
unless every `- [ ]` item is either checked off (`- [x]`) or annotated with a deviation marker.

**Exact insertion point**: After the `---` separator at line 227, before Stage 4D-iii starts
at line 229. Alternatively, replace the preamble paragraph and Step 2 to make it a hard gate.

**Proposed change**: Change Step 2 to:
> **HARD REQUIREMENT**: For each unchecked `- [ ]` item, you MUST do one of the following
> before this phase can be marked `[COMPLETED]` and before proceeding to Stage 4D-iii:
> - Complete the overlooked item now (mark `- [x]` with `*(completed)*`)
> - Annotate as a deviation (see deviation format)
> Proceeding with any `- [ ]` item that is neither completed nor annotated as a deviation is
> a protocol violation.

### 2. Current Postflight (skill-implementer)

**File**: `.claude/skills/skill-implementer/SKILL.md`

The postflight section (beginning at line 322, "Postflight (ALWAYS EXECUTE)") runs in a
continuation loop with the following stages:
- Stage 6: Parse Subagent Return (Read Metadata File) — lines 337-362
- Stage 6a: Validate Artifact Content — lines 366-379 (validates summary format via
  `validate-artifact.sh`, non-blocking)
- Stage 6b: Commit Phase Progress — lines 384-397
- Stage 7: Update Task Status — lines 402-441
- Stage 8: Link Artifacts — lines 524-548
- Stage 9: Git Commit — lines 570-577
- Stage 10: Cleanup — lines 583-593
- Stage 11: Return Brief Summary — lines 597-608

**POSTFLIGHT BOUNDARY RESTRICTION** (lines 638-660): The postflight phase is explicitly
restricted. The skill MUST NOT:
1. Read source files
2. Edit source files
3. Run build/test commands
4. Use MCP tools
5. Grep or glob the codebase
6. Write summary/reports

This means a full grep-based scan of the plan file is **prohibited** in postflight. However,
the postflight CAN read the `.return-meta.json` metadata and CAN read the plan file path
(already known from `plan_path` in the delegation context). The restriction is on "source
files" — the plan file is a task artifact, not a source file.

**Interpretation**: Reading and editing the plan file (a task artifact) in postflight is
acceptable because:
- The plan path is already known from Stage 4 (`plan_path`)
- The task description calls for "compare completed work against unchecked plan items and
  auto-fix mismatches via Edit"
- The plan is a `.claude/` artifact, not a codebase source file

**Exact insertion point**: A new Stage 6b-checkbox (between Stage 6a and Stage 6b-commit)
that:
1. Reads `plan_path` (known from Stage 4 delegation context)
2. Greps for unchecked `- [ ]` items in completed phases (phases whose heading shows `[COMPLETED]`)
3. For any found: logs a warning and optionally auto-fixes by annotating with `*(postflight: unchecked)*`

**Important caveat**: The postflight runs AFTER the agent has already committed. This means
postflight checkbox validation is a safety net for items the agent missed in Stage 4D-ii, not
a replacement for the agent-level gate. The auto-fix should be non-blocking (warning only, or
annotate without failing the postflight).

**Proposed stage placement**: After Stage 6a (artifact validation) and before Stage 6b (commit):

```
### Stage 6b: Plan Checkbox Postflight Scan (Non-Blocking)

If plan_path is known and the file exists:
- Read plan_path
- Find all [COMPLETED] phase blocks (headings matching `### Phase N: ... [COMPLETED]`)
- For each completed phase: count remaining `- [ ]` items without deviation annotation
- If any unchecked items found:
  - Log warning: "WARNING: {N} unchecked items found in completed phases"
  - For each: auto-annotate via Edit: append `*(postflight: unchecked — review needed)*`
  - Continue (non-blocking — does not fail postflight)
```

### 3. Current Handoff Schema (orchestrator handoff)

**File**: `.claude/docs/architecture/handoff-schema.md`
**Lines**: 29-75 (Complete JSON Schema section)

Current top-level fields:
- `$schema`, `phase`, `status`, `summary`, `artifacts`, `blockers`, `next_action_hint`,
  `files_modified`, `decisions_made`, `dead_ends`, `continuation_context`

The `continuation_context` object (lines 70-74) contains:
```json
{
  "handoff_path": "...",
  "phases_completed": 2,
  "phases_total": 4
}
```

The orchestrator reads `phases_completed` from the TOP-LEVEL of the handoff (not from
`continuation_context`). See `skill-orchestrate/SKILL.md` lines 355-358:
```bash
phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
```

**Finding**: `phases_completed` and `phases_total` are read as TOP-LEVEL fields by the
orchestrator, but they are NOT defined in the top-level schema — they only appear inside
`continuation_context`. This is a schema inconsistency. The orchestrator reads them from
the top level, but the schema defines them inside `continuation_context`.

**Token budget**: The full handoff must stay under 400 tokens. Adding `subtasks_completed`
as a string array (e.g., `["1.1", "1.2", "2.1"]`) would add ~20-50 tokens, which is within
budget.

**Proposed schema addition**: Add `subtasks_completed` as an optional top-level field:
```json
{
  "subtasks_completed": ["1.1", "1.2", "2.1"]
}
```

This field is written by the agent when in orchestrator_mode, listing the "P.N" identifiers
(phase.step) of completed checklist items. The orchestrator can read this to provide per-subtask
visibility for drift detection and successor dispatch context.

**How the agent knows subtask IDs**: The checklist format from `plan-format-enforcement.md`
uses `- [ ] **Task {P}.{N}**: {description}` — the "P.N" identifier is embedded in the item.
The agent already reads these in Stage 4B-ii. When completing subtasks, it can accumulate
their IDs for inclusion in the orchestrator handoff.

**Exact insertion point** in `handoff-schema.md`: Add between `continuation_context` and
the closing `}` of the top-level schema (after line 74). Also add a Field Definition section
after `continuation_context` (around line 160).

**How skill-implementer writes this**: In the orchestrator handoff writing logic
(within the postflight when `orchestrator_mode = true`), extract `subtasks_completed` from
`.return-meta.json` (agent must populate this field) and write to the handoff JSON.

**How `general-implementation-agent` populates this**: The agent collects completed
subtask IDs during Stage 4B-ii (when it checks off items) and writes them to `.return-meta.json`
under a new `subtasks_completed` field. The skill-implementer then passes this through to the
orchestrator handoff.

### 4. Plan Format

**File**: `.claude/rules/plan-format-enforcement.md`

Phase heading format: `### Phase N: {name} [STATUS]`

Valid status markers: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`

Checklist items (from `general-implementation-agent.md` lines 163-178):
- Completed: `- [x] **Task {P}.{N}**: {description} *(completed)*`
- In-progress: `- [ ] **Task {P}.{N}**: {description} *(in progress)*`
- Deviation-skipped: `- [ ] **Task {P}.{N}**: {description} *(deviation: skipped — {reason})*`
- Deviation-altered: `- [x] **Task {P}.{N}**: {description} *(deviation: altered — {what changed})*`
- Deviation-deferred: `- [ ] **Task {P}.{N}**: {description} *(deviation: deferred to task {N})*`

The deviation annotation format is already well-defined. The self-review gate hardening
needs to enforce that ALL `- [ ]` items in a completed phase carry either the `*(completed)*`
or a `*(deviation: ...)` annotation.

---

## Decisions

- The postflight plan-checkbox scan should be non-blocking (warning + auto-annotate, never fail)
  to avoid blocking implementation for trivial mismatches.
- The agent-level Stage 4D-ii hardening is the primary enforcement point; postflight is a
  safety net only.
- `subtasks_completed` should be a top-level field in the orchestrator handoff (not nested
  inside `continuation_context`) to match how `phases_completed`/`phases_total` are read.
- The agent must accumulate subtask IDs during Stage 4B-ii execution and expose them in
  `.return-meta.json` so skill-implementer can propagate them to the orchestrator handoff.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Hardened Stage 4D-ii causes agents to spend excessive time re-reading plan | Gate only applies within the phase block; no full plan re-read required |
| Postflight checkbox scan reads a large plan file, violating context budget | Non-blocking; limit to completed phases only; use grep not full read |
| `subtasks_completed` array grows very large for multi-phase tasks | Cap at ~20 entries; truncate oldest if over budget (400 token limit for full handoff) |
| Schema inconsistency: `phases_completed` already read at top-level but not in schema | Fix the schema to document `phases_completed`/`phases_total` as top-level fields |

---

## Exact Insertion Points Summary

### Change 1: Harden Stage 4D-ii
**File**: `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
**Location**: Lines 197-225 (Stage 4D-ii section)

Replace the advisory language in Step 2 ("evaluate whether it should be completed") with an
explicit HARD REQUIREMENT block that makes proceeding with unchecked/unannotated items a
protocol violation. The surrounding context (Steps 1, 3, 4, 5) remains unchanged.

Specifically, replace (around line 205-206):
```
   - If the item was overlooked, evaluate whether it should be completed before
     proceeding to the next phase.
```
With:
```
   - If the item was overlooked: **HARD REQUIREMENT** — you MUST either complete the item
     now (execute the work and mark `- [x]`) or record it as a deviation before proceeding.
     Leaving a `- [ ]` item unchecked and unannotated in a phase marked `[COMPLETED]` is
     a protocol violation. Do not mark the phase [COMPLETED] until this is resolved.
```

Also add a closing enforcement reminder before the "Only then proceed..." line (line 225):
```
> **Checkpoint**: Before calling Stage 4D-iii, verify that every `- [ ]` item in this
> phase's checklist is either checked (`- [x]`) or carries a `*(deviation: ...)` annotation.
> If any remain, go back to Step 2.
```

### Change 2: Postflight Plan-Checkbox Validation
**File**: `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md`
**Location**: After Stage 6a (line 379), before Stage 6b (line 384)

Insert a new stage:
```markdown
### Stage 6b-checkbox: Plan Checkbox Postflight Scan (Non-Blocking)

If `plan_path` is known and the file exists, scan completed phases for unchecked items.

  bash
  if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
    # Extract completed phase blocks only
    unchecked_count=$(grep -c '^\- \[ \]' "$plan_path" 2>/dev/null || echo 0)
    if [ "$unchecked_count" -gt 0 ]; then
      echo "WARNING: $unchecked_count unchecked checklist items found in plan file: $plan_path"
      echo "These items were not completed or annotated as deviations. Review the plan."
      # Non-blocking: log warning but do not fail postflight
    fi
  fi
```

**Note**: Full per-phase filtering (only checking [COMPLETED] phases) requires parsing the
plan file structure. A simpler approach — count ALL unchecked `- [ ]` items and warn if any
exist after all phases are complete — is sufficient for the safety-net purpose and avoids
complex bash parsing.

### Change 3: Extend Orchestrator Handoff Schema
**File**: `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md`
**Location**: Line 74 (after `"phases_total": 4` in the JSON schema example)

Add `subtasks_completed` to the top-level schema:
```json
  "subtasks_completed": [
    "1.1", "1.2", "2.1"
  ]
```

Add Field Definition (after line 160, after `continuation_context` definition):
```markdown
### `subtasks_completed` (optional)
Array of subtask identifiers completed during this dispatch cycle, in `"{phase}.{step}"` format
(e.g., `["1.1", "1.2", "2.1"]`). Written by the agent when accumulating completed checklist
items during Stage 4B-ii. Used by the orchestrator to provide per-subtask visibility for drift
detection and successor dispatch context. Cap at 20 entries to stay within token budget.
```

**Also fix schema inconsistency**: Add `phases_completed` and `phases_total` as documented
top-level fields (they are already read by the orchestrator at the top level but were only
defined in `continuation_context`):
```json
  "phases_completed": 2,
  "phases_total": 4
```

And update `general-implementation-agent.md` to accumulate subtask IDs during Stage 4B-ii
and write them to `.return-meta.json` under `subtasks_completed`.

And update `skill-implementer` Stage 6 to read `subtasks_completed` from `.return-meta.json`
and include it when writing the orchestrator handoff.

---

## Context Extension Recommendations

- **Topic**: Orchestrator handoff top-level vs. nested fields
- **Gap**: The schema documents `phases_completed`/`phases_total` only inside
  `continuation_context`, but the orchestrator reads them from the top level. The schema
  is inconsistent with actual usage.
- **Recommendation**: Update `handoff-schema.md` to document these as top-level optional
  fields, and clarify when skills should populate them vs. when they stay in
  `continuation_context` only.

---

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (477 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (663 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1176 lines)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md` (381 lines)
- `/home/benjamin/.config/nvim/.claude/rules/plan-format-enforcement.md` (14 lines)

### Key Line References
- Stage 4D-ii: `general-implementation-agent.md` lines 197-225
- Postflight start: `skill-implementer/SKILL.md` line 322
- Stage 6a (artifact validation): `skill-implementer/SKILL.md` lines 366-379
- Stage 6b (commit): `skill-implementer/SKILL.md` lines 384-397
- Postflight boundary restriction: `skill-implementer/SKILL.md` lines 638-660
- Orchestrator handoff reading: `skill-orchestrate/SKILL.md` lines 344-358
- Handoff JSON schema: `handoff-schema.md` lines 29-75
- `phases_completed` read by orchestrator: `skill-orchestrate/SKILL.md` lines 355-358
