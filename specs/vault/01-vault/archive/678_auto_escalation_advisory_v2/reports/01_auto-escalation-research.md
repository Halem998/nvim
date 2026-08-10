# Research Report: Task #678

**Task**: 678 - auto_escalation_advisory_v2
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:30:00Z
**Effort**: 1-2 hours implementation
**Dependencies**: Task 669 (hard_mode_agent_system) — completed
**Sources/Inputs**: Codebase (skill-orchestrate/SKILL.md, skill-orchestrate-hard/SKILL.md, state.json schema, handoff schema), Background reports 01 and 02 from task 669
**Artifacts**: specs/678_auto_escalation_advisory_v2/reports/01_auto-escalation-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The standard orchestrator (`skill-orchestrate/SKILL.md`) has no churn detection at all. The hard-mode orchestrator (`skill-orchestrate-hard/SKILL.md`) has full per-target churn detection (H5/H6) that triggers a divergence audit at 3 strikes, but it is only reachable via `/orchestrate --hard`.
- This task adds advisory-only churn detection to the STANDARD orchestrator that emits a `consider --hard` warning when deflection patterns are observed. No auto-escalation. No routing change.
- The three signals are measurable without file reads: plan revision count (count `*.md` files in `plans/`), implement dispatch count with no phase progress (track in loop guard), and analysis-only output (grep `.summary` field in handoff for deflection keywords).
- The cleanest implementation: extend `.orchestrator-loop-guard` with three new counters (`plan_revisions`, `implement_no_progress`, `analysis_only_dispatches`) and check them in Stage 5 (handoff reading) after each dispatch.
- Warning output uses the existing `echo "[orchestrate] WARNING: ..."` pattern to stderr, adding a single `ADVISORY` line that is human-readable and easy to scan in the terminal.

---

## Context & Scope

This is a v2 trajectory item (deferred from task 669). Task 669 implemented `skill-orchestrate-hard` with full H5/H6 churn detection. This task adds lightweight churn detection to the **standard** `skill-orchestrate` as a passive advisory — it watches for the same deflection patterns but emits only a warning, never switching mode or altering the dispatch.

Scope constraints:
1. Advisory only — MUST NOT auto-escalate to `--hard` routing
2. MUST NOT add significant complexity to `skill-orchestrate` (the base skill must remain the simple, fast path)
3. MUST work without reading plan files or implementation summaries (context flatness constraint — see the MUST NOT section in `skill-orchestrate`)
4. Counter state MUST persist across `/orchestrate` invocations (stored in loop guard or separate file)

---

## Findings

### Codebase Patterns

#### 1. The Standard Orchestrator Has No Churn Detection Today

`skill-orchestrate/SKILL.md` Stage 2 creates the loop guard file with these fields:
```json
{
  "session_id": "...",
  "cycle_count": 0,
  "max_cycles": 5,
  "current_state": "reading",
  "started": "...",
  "last_updated": "..."
}
```

There are no revision counters, dispatch counters, or churn state fields. The only existing "guard" mechanism is `cycle_count` vs `MAX_CYCLES=5`.

Existing drift detection (Stage 5a) only activates when `phases_total > 0` AND `dispatch_status = "partial"` AND completion ratio is below 70%. It does not detect analysis-paralysis and it reads the plan file, which is expensive.

The blocker escalation counter (`blocker_escalation_count`) is reset on every `/orchestrate` invocation — it is not persistent.

#### 2. The Hard Orchestrator Already Has Full Churn Detection

`skill-orchestrate-hard/SKILL.md` Stage 2 creates a separate `.orchestrator-churn-state.json` file alongside the loop guard. Stage 4b checks the churn state after every implement dispatch.

The hard orchestrator's churn detection is more sophisticated than needed here:
- Tracks per-target churn (requires `.blockers[0].target` field in handoff)
- Triggers a divergence audit at 3 strikes (requires a research dispatch)
- Stores separate `target_churn`, `adversarial_triggers`, `audit_dispatches`

For the advisory variant, the signals are simpler and broader (task-level, not target-level).

#### 3. Loop Guard is the Right Home for Advisory Counters

The loop guard file (`${TASK_DIR}/.orchestrator-loop-guard`) already persists across invocations. It is read at the top of Stage 2 and written at Stage 7. Adding advisory counters to it requires:
- Reading 3 extra integer fields at Stage 2 initialization (no extra file read needed)
- Incrementing counters in Stage 5 (handoff reading, which already reads the handoff JSON)
- Emitting a warning in Stage 5 when a threshold is crossed

This adds ~15-20 lines to `skill-orchestrate/SKILL.md`. No new files required.

#### 4. Measuring Each Signal

**Signal 1: 2+ plan revisions**

Plan files live at `${TASK_DIR}/plans/*.md`. Counting them is a cheap filesystem operation:
```bash
plan_count=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | wc -l)
```
This count is stable (files are never deleted) and accurate (each `/revise` creates a new plan file). Threshold: `plan_count >= 2`.

Note: `next_artifact_number` in state.json is NOT the right signal. It tracks research rounds, not plan revisions specifically. `next_artifact_number=2` could mean one research + one plan, or one research (no plan yet). The plan file count is the ground truth.

Alternative: count `artifacts` with `type == "plan"` in state.json. This is also accurate but requires a jq query. The filesystem count is simpler and safe.

**Signal 2: 3+ implement dispatches with no phase completion**

The orchestrator dispatches implement from states `planned`, `implementing`, and `partial` (with continuation or blockers). A "no phase completion" dispatch means `phases_completed_after == phases_completed_before`.

Track in the loop guard: `implement_no_progress_count`. Increment when:
- `dispatch_status == "partial"` AND
- `phases_completed` did not increase since the last implement dispatch

Threshold: `implement_no_progress_count >= 3`.

Reset condition: this counter should reset when a phase IS completed (i.e., `phases_delta > 0`), to avoid false positives when a task legitimately has multiple blocked phases at different times.

**Signal 3: Analysis-only output in implementation phases**

From Report 01, the specific analysis-paralysis signature phrases are:
- "the approach is wrong"
- "a different representation is needed"
- "estimated N lines" as a final answer
- "root cause analysis"
- "settled design"

These appear in the `.summary` field of the handoff JSON, which the orchestrator already reads in Stage 5:
```bash
dispatch_summary=$(echo "$handoff" | jq -r '.summary // ""')
```

Detection: grep the summary for analysis keywords when `phases_completed == 0` and `dispatch_status == "partial"`. This is not a perfect detector (summaries are agent-written and vary), but it catches the most egregious cases.

```bash
# Analysis-only detection: dispatch produced no phase completions AND summary has analysis markers
if [ "$phases_completed" -eq 0 ] && [ "$dispatch_status" = "partial" ]; then
  if echo "$dispatch_summary" | grep -qiE \
    "(approach is wrong|different representation|root.?cause|settled design|cannot proceed|redesign needed|formula.*wrong)"; then
    analysis_only_count=$((analysis_only_count + 1))
  fi
fi
```

Threshold: `analysis_only_count >= 1` (even one analysis-only dispatch is a strong signal).

#### 5. Warning Emission Pattern

Existing WARNING pattern in the orchestrator:
```bash
echo "[orchestrate] WARNING: Task $task_number is currently being researched in another session."
```

The advisory warning should follow the same format but use `ADVISORY` to distinguish it from error warnings:
```bash
echo "[orchestrate] ADVISORY: Churn pattern detected for task $task_number." >&2
echo "[orchestrate] ADVISORY:   - Plan revisions: $plan_count (threshold: 2)" >&2
echo "[orchestrate] ADVISORY:   - Implement dispatches with no phase progress: $implement_no_progress_count (threshold: 3)" >&2
echo "[orchestrate] ADVISORY:   - Analysis-only dispatches: $analysis_only_count (threshold: 1)" >&2
echo "[orchestrate] ADVISORY: Consider running /orchestrate $task_number --hard for structured churn countermeasures." >&2
```

Using `>&2` (stderr) ensures the advisory is visible in the terminal alongside other orchestrator output without interfering with structured output. All existing warnings already use stderr implicitly via echo; explicitly routing to `>&2` makes the advisory distinct.

**One-time emission**: To avoid emitting the same advisory on every cycle, add a `churn_advisory_emitted` boolean to the loop guard and only emit once per task lifecycle.

#### 6. Where in Stage 5 to Insert the Check

Stage 5 already reads the handoff and extracts `phases_completed` and `dispatch_summary`. The churn check should happen after the status update but before the artifact linking, so it does not interfere with postflight:

```
Stage 5 flow (current):
  Read handoff fields
  → Drift detection (arithmetic gate)
  → Postflight status update
  → Artifact linking

Stage 5 flow (with advisory):
  Read handoff fields
  → Drift detection (arithmetic gate)
  → Postflight status update
  → [NEW] Churn advisory check (update counters, emit warning if threshold crossed)
  → Artifact linking
```

The churn check reads fields that are already in memory from earlier in Stage 5.

---

### Loop Guard Schema Extension

New fields to add to the loop guard JSON:

```json
{
  "session_id": "...",
  "cycle_count": 0,
  "max_cycles": 5,
  "current_state": "reading",
  "started": "...",
  "last_updated": "...",

  "churn_advisory": {
    "plan_revision_count": 0,
    "implement_no_progress_count": 0,
    "analysis_only_count": 0,
    "advisory_emitted": false,
    "last_implement_phases_completed": 0
  }
}
```

The `last_implement_phases_completed` field tracks the phases_completed value from the previous implement dispatch, enabling delta calculation without re-reading the handoff history.

On resume (loop guard already exists), read these counters from the existing guard file. They accumulate across `/orchestrate` invocations, which is the correct behavior (churn is a per-task-lifecycle signal, not a per-session signal).

---

### Recommendations

#### Recommended Implementation Approach

The implementation is a contained modification to `skill-orchestrate/SKILL.md` in three places:

**Change 1: Stage 2 initialization** — Add churn advisory fields to the loop guard. On fresh start, initialize to zero. On resume, read existing counters.

```bash
# Read or initialize churn advisory counters
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  churn_plan_revisions=$(jq -r '.churn_advisory.plan_revision_count // 0' "$loop_guard_file")
  churn_no_progress=$(jq -r '.churn_advisory.implement_no_progress_count // 0' "$loop_guard_file")
  churn_analysis_only=$(jq -r '.churn_advisory.analysis_only_count // 0' "$loop_guard_file")
  churn_advisory_emitted=$(jq -r '.churn_advisory.advisory_emitted // false' "$loop_guard_file")
  last_impl_phases=$(jq -r '.churn_advisory.last_implement_phases_completed // 0' "$loop_guard_file")
else
  # Fresh start: create guard with churn fields
  churn_plan_revisions=0; churn_no_progress=0; churn_analysis_only=0
  churn_advisory_emitted=false; last_impl_phases=0
  jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "current_state": "reading",
      "started": $started,
      "last_updated": $started,
      "churn_advisory": {
        "plan_revision_count": 0,
        "implement_no_progress_count": 0,
        "analysis_only_count": 0,
        "advisory_emitted": false,
        "last_implement_phases_completed": 0
      }
    }' > "$loop_guard_file"
fi
```

**Change 2: Stage 5 churn check function** — Called after postflight status update, only when an implement dispatch just completed:

```bash
check_churn_advisory() {
  # Only check after implement dispatches
  case "$dispatch_status" in researched|planned) return 0 ;; esac

  # Signal 1: count plan files
  churn_plan_revisions=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | wc -l)

  # Signal 2: implement dispatch with no phase progress
  if [ "$dispatch_status" = "partial" ]; then
    phases_delta=$(( phases_completed - last_impl_phases ))
    if [ "$phases_delta" -le 0 ]; then
      churn_no_progress=$((churn_no_progress + 1))
    else
      churn_no_progress=0  # Reset on progress
    fi
  fi
  last_impl_phases="$phases_completed"

  # Signal 3: analysis-only summary (phases_completed == 0, partial, analysis keywords)
  if [ "$phases_completed" -eq 0 ] && [ "$dispatch_status" = "partial" ]; then
    if echo "$dispatch_summary" | grep -qiE \
      "(approach is wrong|different representation|root.?cause|settled design|cannot proceed|redesign needed|formula.*wrong|analysis.*complete)"; then
      churn_analysis_only=$((churn_analysis_only + 1))
    fi
  fi

  # Check thresholds and emit advisory (once per task lifecycle)
  threshold_crossed=false
  if [ "$churn_plan_revisions" -ge 2 ]; then threshold_crossed=true; fi
  if [ "$churn_no_progress" -ge 3 ]; then threshold_crossed=true; fi
  if [ "$churn_analysis_only" -ge 1 ]; then threshold_crossed=true; fi

  if [ "$threshold_crossed" = "true" ] && [ "$churn_advisory_emitted" = "false" ]; then
    echo "[orchestrate] ADVISORY: Deflection pattern detected for task $task_number." >&2
    echo "[orchestrate] ADVISORY:   Plan revisions: $churn_plan_revisions  (flag: >=2)" >&2
    echo "[orchestrate] ADVISORY:   Implement cycles with no phase progress: $churn_no_progress  (flag: >=3)" >&2
    echo "[orchestrate] ADVISORY:   Analysis-only dispatches: $churn_analysis_only  (flag: >=1)" >&2
    echo "[orchestrate] ADVISORY: This task may benefit from hard-mode orchestration." >&2
    echo "[orchestrate] ADVISORY: Consider: /orchestrate $task_number --hard" >&2
    churn_advisory_emitted=true
  fi

  # Persist updated counters to loop guard
  jq \
    --argjson plan_rev "$churn_plan_revisions" \
    --argjson no_prog "$churn_no_progress" \
    --argjson analysis "$churn_analysis_only" \
    --argjson emitted "$([ "$churn_advisory_emitted" = "true" ] && echo true || echo false)" \
    --argjson last_phases "$last_impl_phases" \
    '.churn_advisory.plan_revision_count = $plan_rev |
     .churn_advisory.implement_no_progress_count = $no_prog |
     .churn_advisory.analysis_only_count = $analysis |
     .churn_advisory.advisory_emitted = $emitted |
     .churn_advisory.last_implement_phases_completed = $last_phases' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
}
```

**Change 3: Stage 7 loop guard update** — The existing Stage 7 update only updates `current_state`, `last_updated`, and `cycle_count`. It must now preserve the `churn_advisory` object (achieved by using selective `jq` field updates rather than replacing the whole document, which is what Stage 7 already does).

No change needed here since the Stage 7 update is already a selective merge:
```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```
This already does a selective merge — it only updates three fields, leaving `churn_advisory` untouched.

#### Alternative: Separate .orchestrator-churn-advisory.json File

Following the pattern of `.orchestrator-churn-state.json` in the hard orchestrator, the advisory counters could live in a separate file. This keeps the loop guard schema minimal.

Tradeoff: The separate file approach requires one extra read (to load the advisory file at Stage 2) and one extra write (to persist it). For an advisory-only feature, this overhead is not warranted. Embedding in the loop guard is simpler.

**Verdict**: Embed in the loop guard.

#### What NOT to Do

1. **Do NOT read plan files** to detect analysis-only output — this violates the context flatness constraint. The handoff summary is sufficient.
2. **Do NOT dispatch any agents** as a result of the advisory — it is strictly a warning, never a dispatch trigger.
3. **Do NOT block progression** — the orchestrator loop continues normally regardless of advisory status.
4. **Do NOT emit the advisory more than once** — use the `advisory_emitted` flag to prevent repeated noise.
5. **Do NOT add advisory checks to the multi-task mode** (MT-1 through MT-5) in v1 — the wave-based dispatch makes per-task churn tracking more complex. Leave MT stages unchanged.

---

## Decisions

- **Counter persistence**: Counters live in the loop guard, not a separate file. Reason: no extra file I/O, loop guard already persists across invocations.
- **Signal 1 measurement**: Count plan files in `plans/` directory, not `next_artifact_number` in state.json. Reason: plan file count is the exact signal; `next_artifact_number` tracks research rounds.
- **Signal 3 keywords**: Use a targeted grep regex on the handoff summary. The 6 phrases from Report 01 (F1 forbidden conclusions) are the ground truth. Threshold of 1 (any analysis-only dispatch is a strong signal).
- **Advisory format**: Uses `[orchestrate] ADVISORY:` prefix on stderr, matching the existing `[orchestrate] WARNING:` pattern. Multi-line detail for actionability.
- **Emit once per task**: `advisory_emitted` boolean in loop guard prevents repeated advisory messages across cycles and sessions.
- **No multi-task mode**: Advisory counters only apply to single-task orchestration in v1.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| False positive: analysis-only keyword matches legitimate summary content | Medium | Use a tight regex (exact phrases from Report 01); the threshold is 1 so false positives should be rare in practice |
| Churn counters inflate incorrectly if loop guard is manually deleted | Low | Loop guard deletion resets counters to 0; the advisory is not emitted until thresholds are crossed again — this is the correct behavior |
| jq field-update in Stage 7 accidentally overwrites `churn_advisory` object | Low | The selective merge pattern (`.field = val`) only updates named fields; `churn_advisory` is left untouched |
| Signal 2 counter never resets, leading to stale churn signal | Medium | Counter resets to 0 whenever `phases_delta > 0` (actual progress). This correctly distinguishes "stuck" from "progressing slowly" |
| Stage 5 check fires after research/plan dispatches where phases_completed is meaningless | Low | Gate the check with `case "$dispatch_status"` — skip for `researched` and `planned` statuses |

---

## Integration Points

### File to Modify

**Primary**: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md`

Three locations within this file:
1. Stage 2 (lines ~122-158): Add churn fields to loop guard creation and resume reading
2. Stage 5 (lines ~335-413): Add `check_churn_advisory()` call after postflight status update
3. Add `check_churn_advisory()` function definition (after Stage 5a or as a new sub-stage)

### No Other Files Required

This feature adds ~60-80 lines to `skill-orchestrate/SKILL.md` and no new files. It does not touch:
- `skill-orchestrate-hard/SKILL.md` (already has full churn detection)
- Any agent files
- Any command files
- `state.json` schema (loop guard is a runtime artifact, not tracked in state)
- `handoff-schema.md` (no new handoff fields needed)
- `CLAUDE.md` (advisory is operational behavior, not user-facing architecture documentation)

Optional CLAUDE.md update: the "When to use --hard" section already lists "2+ plan versions" and "analysis-only prior outputs" as signals. The advisory makes these signals explicit at runtime. A brief mention in CLAUDE.md is nice-to-have but not required for the feature to work.

---

## Context Extension Recommendations

None. This is a meta task (agent system modification). Context extension documentation is omitted per CLAUDE.md meta task policy.
