# Implementation Plan: Task #613

- **Task**: 613 - structured_handoff_subtask_counts
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/613_structured_handoff_subtask_counts/reports/01_handoff-subtask-counts.md
- **Artifacts**: plans/01_handoff-subtask-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `phases_completed` and `phases_total` as top-level fields in `.orchestrator-handoff.json` for all implementation statuses, not just inside `continuation_context` for partial returns. The data already exists in `.return-meta.json` (written by the implementation agent) and is read by `skill-implementer` postflight -- the change threads it through `skill_write_orchestrator_handoff()` via env vars (consistent with the existing `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` pattern) and updates `skill-orchestrate` Stage 5 to read the new fields.

### Research Integration

Key findings from the research report:
- `phases_completed` and `phases_total` exist in `.return-meta.json` metadata (written by implementation agents)
- `skill-implementer` already reads these values during postflight (line 179-180)
- `skill_write_orchestrator_handoff()` in `skill-base.sh` accepts optional data via env vars -- the env var pattern is the established extension mechanism
- The token budget impact is minimal (~10 tokens for two integer fields)
- `skill-orchestrate` Stage 5 currently reads 5 fields; adding 2 more is straightforward

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly advanced by this task. The task improves internal orchestrator observability, which indirectly supports the "Agent System Quality" roadmap phase.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Add `phases_completed` and `phases_total` as top-level fields in the orchestrator handoff JSON for all implementation statuses (implemented, partial, failed)
- Use the env var pattern (consistent with `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON`) to pass values without changing the function signature
- Update `skill-orchestrate` to read the new fields
- Update handoff schema documentation to reflect the new fields

**Non-Goals**:
- Per-phase subtask counts (e.g., `phase_subtask_counts` array) -- deferred to follow-up task
- Reading progress files in skill postflight
- Changing the `.return-meta.json` schema (already has these fields)
- Changing `general-implementation-agent.md` (already writes these fields)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Env var not unset after call, leaking to subsequent invocations | L | L | Explicitly unset vars after each `skill_write_orchestrator_handoff` call (follow existing pattern) |
| Token budget exceeded in handoff JSON | L | L | Two integer fields add ~10 tokens; current usage is ~200 of 400 budget |
| Backward compatibility with skills that do not set the env vars | M | L | Default to 0 via `${VAR:-0}` in skill-base.sh -- zero values signal "not provided" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add env var support to `skill_write_orchestrator_handoff()` [COMPLETED]

**Goal**: Extend the handoff writer in `skill-base.sh` to accept and emit `phases_completed` and `phases_total` as top-level fields in the output JSON.

**Tasks**:
- [x] Add comment documenting `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED` and `ORCHESTRATOR_HANDOFF_PHASES_TOTAL` env vars alongside existing `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` comment (line ~399) *(completed)*
- [x] Read the env vars with defaults inside `skill_write_orchestrator_handoff()`: `local phases_completed="${ORCHESTRATOR_HANDOFF_PHASES_COMPLETED:-0}"` and `local phases_total="${ORCHESTRATOR_HANDOFF_PHASES_TOTAL:-0}"` *(completed)*
- [x] Add `--argjson phases_completed "$phases_completed"` and `--argjson phases_total "$phases_total"` to the `jq -n` command (line ~442) *(completed)*
- [x] Add `"phases_completed": $phases_completed, "phases_total": $phases_total` fields in the JSON template (between `"artifacts"` and `"blockers"`, line ~455) *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` - Add env var reading and JSON output fields (~10 lines)

**Verification**:
- The `jq -n` template compiles without errors (valid jq syntax)
- The two new fields appear in the output JSON structure
- Default values (0) are used when env vars are not set

---

### Phase 2: Export env vars in `skill-implementer` postflight [COMPLETED]

**Goal**: Thread the `phases_completed` and `phases_total` values already available in `skill-implementer` postflight through to the orchestrator handoff writer via the new env vars.

**Tasks**:
- [x] In the success path (status = "implemented", before line 229), add: `export ORCHESTRATOR_HANDOFF_PHASES_COMPLETED="$phases_completed"` and `export ORCHESTRATOR_HANDOFF_PHASES_TOTAL="$phases_total"` *(completed)*
- [x] After the success `skill_write_orchestrator_handoff` call (line 230), add: `unset ORCHESTRATOR_HANDOFF_PHASES_COMPLETED ORCHESTRATOR_HANDOFF_PHASES_TOTAL` *(completed)*
- [x] In the partial path (before line 279), add the same export statements before the existing `skill_write_orchestrator_handoff` call *(completed)*
- [x] After the partial `skill_write_orchestrator_handoff` call (line 280), add the unset alongside the existing `unset ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Add export/unset pairs at success and partial handoff write points (~8 lines)

**Verification**:
- The env vars are set before each `skill_write_orchestrator_handoff` call
- The env vars are unset after each call (no leakage)
- Both success and partial paths are covered

---

### Phase 3: Update `skill-orchestrate` handoff reading [COMPLETED]

**Goal**: Add `phases_completed` and `phases_total` reads to the orchestrator's handoff parsing in Stage 5, making the data available for logging and future decision-making.

**Tasks**:
- [x] In Stage 5 handoff reading (line ~317-321), after the existing field reads, add: `phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')` and `phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')` *(completed)*
- [x] Update the dispatch result log line (line ~322) to include phase counts when non-zero: `[ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"` *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add field reads and conditional log line (~4 lines)

**Verification**:
- The `jq` reads use `// 0` fallback for backward compatibility
- Log output includes phase counts when available
- No behavioral change to the state machine (fields are informational only at this stage)

---

### Phase 4: Update handoff schema documentation [COMPLETED]

**Goal**: Document the new top-level fields in the handoff schema, including field definitions and token budget impact.

**Tasks**:
- [x] In `handoff-schema.md` "Complete JSON Schema" section (line ~30), add `"phases_completed": 3` and `"phases_total": 4` as top-level fields in the example JSON (after `"artifacts"`, before `"blockers"`) *(completed)*
- [x] In the "Field Definitions" section (after `"artifacts"` definition, line ~102), add definitions for `phases_completed` and `phases_total` -- both optional, integer, default 0, written by implement phase only *(completed)*
- [x] In the "Token Budget Constraints" table (line ~148), add a row: `phases_completed + phases_total | ~5` *(completed)*
- [x] Update the "Successful Implementation" example (line ~275) to include the new fields with sample values *(completed)*

**Timing**: 20 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/docs/architecture/handoff-schema.md` - Add field definitions, schema entries, budget row, example updates (~20 lines)

**Verification**:
- Schema example includes both new fields
- Field definitions are complete (type, default, when written)
- Token budget table sums correctly within 400-token limit
- Example objects are valid JSON

## Testing & Validation

- [ ] Verify `skill-base.sh` jq template compiles: `bash -n .claude/scripts/skill-base.sh` (syntax check)
- [ ] Verify handoff schema examples are valid JSON (paste into `jq .`)
- [ ] Confirm no other callers of `skill_write_orchestrator_handoff` are affected by the new env vars (grep for the function name -- only `skill-implementer`, `skill-planner`, `skill-researcher`, `skill-reviser` call it; non-implement skills simply do not set the env vars, getting default 0)
- [ ] Review that `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED` and `ORCHESTRATOR_HANDOFF_PHASES_TOTAL` are properly unset after every call site in skill-implementer

## Artifacts & Outputs

- `specs/613_structured_handoff_subtask_counts/plans/01_handoff-subtask-plan.md` (this file)
- Modified: `.claude/scripts/skill-base.sh`
- Modified: `.claude/skills/skill-implementer/SKILL.md`
- Modified: `.claude/skills/skill-orchestrate/SKILL.md`
- Modified: `.claude/docs/architecture/handoff-schema.md`

## Rollback/Contingency

All changes are additive (new env var reads with defaults, new JSON fields, new jq reads with fallbacks). Rollback involves reverting the 4 modified files. No data migration or schema versioning is needed -- callers that do not set the env vars get `0` defaults, and readers that do not parse the new fields ignore them via JSON's additive property.
