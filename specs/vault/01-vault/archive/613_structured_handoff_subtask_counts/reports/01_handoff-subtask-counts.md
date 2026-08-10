# Research Report: Task #613 — Structured Subtask Completion Counts

- **Task**: 613 - structured_handoff_subtask_counts
- **Started**: 2026-05-25T00:00:00Z
- **Completed**: 2026-05-25T00:30:00Z
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/agents/general-implementation-agent.md` (Stage 7)
  - `.claude/skills/skill-implementer/SKILL.md` (postflight, handoff writing)
  - `.claude/skills/skill-orchestrate/SKILL.md` (Stage 5 handoff reading)
  - `.claude/docs/architecture/handoff-schema.md` (current schema)
  - `.claude/scripts/skill-base.sh` (`skill_write_orchestrator_handoff` function)
  - `.claude/context/formats/return-metadata-file.md` (metadata schema)
  - `.claude/context/formats/handoff-artifact.md` (continuation handoff schema)
- **Artifacts**: `specs/613_structured_handoff_subtask_counts/reports/01_handoff-subtask-counts.md`
- **Standards**: report-format.md

---

## Executive Summary

- The `.orchestrator-handoff.json` currently carries `phases_completed` and `phases_total` only inside `continuation_context` (when status is `partial`), not at the top level for all statuses.
- The `skill_write_orchestrator_handoff()` function in `skill-base.sh` is the single write point for the handoff; it does not accept `phases_completed`/`phases_total` as parameters.
- `skill-orchestrate` Stage 5 reads only `status`, `summary`, `blockers`, `continuation_context`, and `next_action_hint` from the handoff — it has no awareness of phase counts today.
- The `.return-meta.json` schema already has `metadata.phases_completed` and `metadata.phases_total` (written by the implementation agent); `skill-implementer` reads them during postflight.
- The recommended change adds `phases_completed` and `phases_total` as top-level fields in the orchestrator handoff, sourced from data already available in `skill-implementer`'s postflight stage.

---

## Context & Scope

The `/orchestrate` command drives tasks autonomously through the full lifecycle. After each skill dispatch it reads `.orchestrator-handoff.json` (≤400 tokens) to understand the outcome without loading full artifacts. Currently, the orchestrator only knows broad outcome (`status`, `summary`) and whether there is a continuation (`continuation_context`) — it has no precise accounting of which phases ran and how many subtasks within each phase succeeded.

Task 613 asks: add `phases_completed`/`phases_total` at the top level of the handoff for all statuses, and optionally per-phase subtask counts, so the orchestrator can make finer-grained decisions.

---

## Findings

### 1. Current `.orchestrator-handoff.json` Schema

Full schema per `handoff-schema.md`:

```json
{
  "$schema": "orchestrator-handoff-v1",
  "phase": "research | plan | implement | revise",
  "status": "researched | planned | implemented | partial | failed | blocked",
  "summary": "2-4 sentence description (~100 token budget)",
  "artifacts": [{ "type": "report|plan|summary", "path": "..." }],
  "blockers": [{ "description": "...", "phase": "phase-N", "severity": "hard|soft" }],
  "next_action_hint": "plan | implement | revise | none",
  "files_modified": ["..."],
  "decisions_made": ["..."],
  "dead_ends": ["..."],
  "continuation_context": {
    "handoff_path": "specs/.../handoffs/phase-N-handoff-T.md",
    "phases_completed": 2,
    "phases_total": 4
  }
}
```

**Key observation**: `phases_completed` and `phases_total` exist ONLY inside `continuation_context`, which is present ONLY when `status = "partial"` AND a continuation handoff was written. For `status = "implemented"`, there are no phase counts at all.

### 2. `skill_write_orchestrator_handoff()` — Current Interface

Location: `.claude/scripts/skill-base.sh`, lines 404–465.

Current parameter signature:
```
skill_write_orchestrator_handoff "$orchestrator_mode" "$padded_num" "$project_name" \
  "$phase" "$status" "$summary" "$artifact_path" "$artifact_type" "$next_hint"
```

The function builds the JSON via `jq -n` with hardcoded `"blockers": []`, `"files_modified": []`, `"decisions_made": []`, `"dead_ends": []`. It accepts `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` as an env var for the `continuation_context` field.

**What's missing**: No `phases_completed`/`phases_total` parameters at the top level.

### 3. Where `phases_completed`/`phases_total` Are Available in `skill-implementer`

In `skill-implementer/SKILL.md`, Stage 6 (postflight), these values are already read:

```bash
phases_completed=$(jq -r '.metadata.phases_completed // 0' "$meta_file")
phases_total=$(jq -r '.metadata.phases_total // 0' "$meta_file")
```

These come from `.return-meta.json` written by `general-implementation-agent` at Stage 7. They are used for:
- The git commit message: `"task ${task_number} phase ${phases_completed}: implementation progress"`
- Populating `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` for partial returns

For the `implemented` (success) status, they are available but NOT currently passed into `skill_write_orchestrator_handoff`.

### 4. How `skill-orchestrate` Reads the Handoff (Stage 5)

```bash
handoff=$(cat "$handoff_file")
dispatch_status=$(echo "$handoff" | jq -r '.status')
dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
```

The orchestrator currently reads 5 fields. It does NOT read any phase count fields. Adding top-level `phases_completed`/`phases_total` would require a new read line in Stage 5, though the orchestrator's state machine does not currently make decisions based on phase counts.

### 5. `.return-meta.json` — Current Schema for Phase Counts

Per `return-metadata-file.md`:

```json
{
  "metadata": {
    "phases_completed": 4,
    "phases_total": 4
  }
}
```

These fields are documented under `metadata` (optional, implementation-agent specific). For `partial` returns, the same fields appear in `partial_progress`:

```json
{
  "partial_progress": {
    "phases_completed": 2,
    "phases_total": 4,
    "handoff_path": "..."
  }
}
```

The schema does NOT currently include per-phase subtask counts anywhere.

### 6. General Implementation Agent Stage 7

`general-implementation-agent.md` Stage 7 writes the metadata file with:
- `phases_completed` and `phases_total` in `metadata` (for `implemented`)
- `phases_completed` and `phases_total` in `partial_progress` (for `partial`)

There is no per-phase subtask tracking in the metadata output. The progress file (`specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json`) does track per-objective completion, but this is not aggregated into `.return-meta.json`.

### 7. Progress File — Per-Phase Subtask Data

The progress file schema (from `progress-file.md`):

```json
{
  "phase": 2,
  "phase_name": "Phase Name",
  "objectives": [
    {"id": 1, "description": "...", "status": "done"},
    {"id": 2, "description": "...", "status": "not_started"}
  ],
  "current_objective": 2
}
```

This file contains per-phase subtask (objective) counts. However, it is only read by successor agents during continuation, not aggregated into `.return-meta.json` or the orchestrator handoff.

---

## Decisions

- The minimal and sufficient change is to add `phases_completed` and `phases_total` as **top-level fields** in `.orchestrator-handoff.json` for all statuses (not just `partial`). This matches the task description and avoids breaking the token budget.
- Per-phase subtask counts (e.g., `{"phase": 1, "subtasks_completed": 3, "subtasks_total": 5}`) are a secondary enhancement. They require reading progress files in `skill-implementer` postflight and would add ~50-100 tokens to the handoff — within budget but only valuable if the orchestrator uses them.
- Per-phase subtask counts are NOT needed for the orchestrator's state machine decisions (it only needs to know if a phase transition happened); they would be informational only.

---

## Recommendations

### Recommended Minimal Change (3 files)

**File 1: `.claude/scripts/skill-base.sh`** (primary change)

Add `phases_completed` and `phases_total` parameters to `skill_write_orchestrator_handoff()`:

```bash
# New optional env vars (alongside ORCHESTRATOR_HANDOFF_CONTINUATION_JSON):
# ORCHESTRATOR_HANDOFF_PHASES_COMPLETED (integer, default 0)
# ORCHESTRATOR_HANDOFF_PHASES_TOTAL (integer, default 0)

# In the jq -n block, add:
--argjson phases_completed "${ORCHESTRATOR_HANDOFF_PHASES_COMPLETED:-0}" \
--argjson phases_total "${ORCHESTRATOR_HANDOFF_PHASES_TOTAL:-0}" \
# In the JSON template, add top-level fields:
"phases_completed": $phases_completed,
"phases_total": $phases_total,
```

Using env vars (consistent with `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON`) avoids changing the function signature and maintains backward compatibility — callers that don't set the env vars get `0` by default.

**File 2: `.claude/skills/skill-implementer/SKILL.md`**

In Stage 7 (success path, after reading `phases_completed`/`phases_total`), export the env vars before calling `skill_write_orchestrator_handoff`:

```bash
export ORCHESTRATOR_HANDOFF_PHASES_COMPLETED="$phases_completed"
export ORCHESTRATOR_HANDOFF_PHASES_TOTAL="$phases_total"
skill_write_orchestrator_handoff "$orchestrator_mode" "$PADDED_NUM" "$PROJECT_NAME" \
  "implement" "$SUBAGENT_STATUS" "$ARTIFACT_SUMMARY" "$ARTIFACT_PATH" "$ARTIFACT_TYPE" "none"
unset ORCHESTRATOR_HANDOFF_PHASES_COMPLETED
unset ORCHESTRATOR_HANDOFF_PHASES_TOTAL
```

The partial path already uses `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON` which embeds `phases_completed`/`phases_total` — those should remain as-is (inside `continuation_context`), but the same env vars should also be set for the top-level fields.

**File 3: `.claude/docs/architecture/handoff-schema.md`**

Update the schema documentation to show `phases_completed` and `phases_total` as top-level optional fields:

```json
{
  "phases_completed": 3,
  "phases_total": 4
}
```

Add to Field Definitions and token budget table (~5 tokens).

### Optional Enhancement: Per-Phase Subtask Counts

If per-phase subtask counts are desired, add to the handoff:

```json
{
  "phase_subtask_counts": [
    {"phase": 1, "subtasks_completed": 5, "subtasks_total": 5},
    {"phase": 2, "subtasks_completed": 3, "subtasks_total": 4}
  ]
}
```

This requires `skill-implementer` postflight to read the progress files (currently only read by agents). The skill currently MUST NOT read source files, but progress files may be in-scope as they are tracking artifacts (not source files). This enhancement is optional and can be scoped to a follow-up task.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Token budget exceeded | Low | New fields add ~10 tokens (two integers + field names); budget is 400 tokens total, current schema uses ~200 |
| Backward compatibility | Low | Using env var pattern (like `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON`) means callers that don't set them get `0` |
| `skill-orchestrate` must read new fields | None | Fields are additive; orchestrator reads only what it needs; new fields won't break existing reads |
| Per-phase subtask reading in skill postflight | Medium | The postflight boundary explicitly prohibits reading source files; progress files are tracking artifacts, not source — but this should be confirmed against `postflight-tool-restrictions.md` |

---

## Implementation Scope Summary

| File | Change | Effort |
|------|--------|--------|
| `.claude/scripts/skill-base.sh` | Add env var params to `skill_write_orchestrator_handoff()` | Small (10 lines) |
| `.claude/skills/skill-implementer/SKILL.md` | Export env vars before calling the function (both success and partial paths) | Small (6 lines) |
| `.claude/docs/architecture/handoff-schema.md` | Update schema docs with new top-level fields | Trivial (15 lines) |
| `.claude/context/formats/return-metadata-file.md` | (No change needed — schema already has these fields in `metadata`) | None |
| `general-implementation-agent.md` | (No change needed — agent already writes `phases_completed`/`phases_total` to `.return-meta.json`) | None |

Total: 3 files, ~30 lines of changes.

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md`
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` (lines 384–465)
- `/home/benjamin/.config/nvim/.claude/context/formats/return-metadata-file.md`
- `/home/benjamin/.config/nvim/.claude/context/formats/handoff-artifact.md`

### Key Grep Results

```
# phases_completed usage in skill-implementer:
phases_completed=$(jq -r '.metadata.phases_completed // 0' "$meta_file")   # line 179
phases_total=$(jq -r '.metadata.phases_total // 0' "$meta_file")           # line 180

# skill-orchestrate reads from handoff (Stage 5):
dispatch_status=$(echo "$handoff" | jq -r '.status')
dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
continuation=$(echo "$handoff" | jq -c '.continuation_context // null')
next_hint=$(echo "$handoff" | jq -r '.next_action_hint // "none"')
```
