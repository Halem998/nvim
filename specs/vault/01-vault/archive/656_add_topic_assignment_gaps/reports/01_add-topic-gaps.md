# Research Report: Task #656

**Task**: 656 - Add topic assignment to 6 task creation points with missing or incomplete handling
**Started**: 2026-06-10T00:00:00Z
**Completed**: 2026-06-10T00:05:00Z
**Effort**: Medium (4-6 hours implementation)
**Dependencies**: Task 654 (manage-topics.sh and topic-assignment-pattern.md already created)
**Sources/Inputs**:
- `.claude/skills/skill-fix-it/SKILL.md`
- `.claude/commands/review.md`
- `.claude/skills/skill-project-overview/SKILL.md`
- `.claude/skills/skill-spawn/SKILL.md`
- `.claude/commands/task.md`
- `.claude/extensions/core/` (all copies identical to main files)
- `.claude/scripts/manage-topics.sh`
- `.claude/context/patterns/topic-assignment-pattern.md`
**Artifacts**:
- `specs/656_add_topic_assignment_gaps/reports/01_add-topic-gaps.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- All 6 topic assignment gaps confirmed present; exact locations and current code identified
- Extension copies in `.claude/extensions/core/` are byte-for-byte identical — every change to a main file must be mirrored there
- `manage-topics.sh` (list/add/set/validate) and `topic-assignment-pattern.md` (Modes A/B/C) are fully ready from task 654
- The 6 sites split cleanly into 3 change patterns: Mode C suggest-wrap (2 sites), Mode A picker-insert (1 site), and Mode B inherit-with-fallback (3 sites)
- For inherit-with-fallback (spawn, --expand, --review), the pattern document currently says "no fallback picker in current implementation" — the task explicitly asks to add a fallback interactive picker when parent has no topic

---

## Findings

### Site 1: skill-fix-it/SKILL.md — PARTIAL (Mode C suggest-wrap)

**File**: `.claude/skills/skill-fix-it/SKILL.md`

**Current state** (Step 9.1, lines 451-479):
- Inline `if/elif/else` auto-inference heuristic (`.claude/|specs/` -> `agent-system`; `.lua` extension content heuristic)
- Result written directly to `"topic": "{auto-inferred topic}"` in state.json
- Step 9.3 (lines 485-502): inline `active_topics` append jq using old pattern (not `manage-topics.sh`)
- **No user confirmation step** — topic is silently assigned

**What needs to change**:
1. Remove inline `active_topics` jq append in Step 9.3; replace with `manage-topics.sh add "$topic"` (idempotent)
2. After inference, show suggest-confirmation AskUserQuestion (Mode C wraps existing heuristic):
   - Option "Accept: {inferred_topic}" — proceed with inferred value
   - Option "Override..." — free-text for a different topic
   - Option "Skip (no topic)" — assign no topic
3. Use `manage-topics.sh set "$task_num" "$topic"` instead of inline jq to write topic to state.json task entry
4. Update `active_topics` via `manage-topics.sh add` only if topic was accepted or overridden

**Key detail**: The suggest confirmation applies per-task; for batch creation (multiple tasks created in one fix-it run), the confirm prompt fires once per task. If topic inference returns empty (no match), fall straight through to interactive picker (Mode A) rather than confirm.

**Extension copy**: `.claude/extensions/core/skills/skill-fix-it/SKILL.md` — identical, must receive same changes.

---

### Site 2: commands/review.md — PARTIAL (Mode C suggest-wrap)

**File**: `.claude/commands/review.md`

**Current state** (Section 5.6.3, lines 519-559):
- Extension-aware path matching heuristic (`.claude/|specs/` -> agent-system; `lua/|after/` -> neovim)
- `active_topics` array is read but only to match against; never written back
- `"topic": (if ($topic == "" | not) then $topic else null end)` — written to task entry
- **No `active_topics` update** — if a new inferred topic is assigned, `active_topics` is never appended
- **No user confirmation** — topic is silently assigned from heuristic

**What needs to change**:
1. After path heuristic, add suggest-confirmation AskUserQuestion (same 3-option pattern as fix-it)
2. After user confirms/overrides, call `manage-topics.sh add "$topic"` to update `active_topics`
3. Replace inline jq topic write in the `active_projects +=` block with the topic variable already set
4. The `"active_topics"` is currently read but never maintained here — this is the bug. The fix adds `manage-topics.sh add` call after topic is resolved.

**Extension copy**: `.claude/extensions/core/commands/review.md` — identical, must receive same changes.

---

### Site 3: skills/skill-project-overview/SKILL.md — MISSING (Mode A interactive)

**File**: `.claude/skills/skill-project-overview/SKILL.md`

**Current state** (Step 5.3, lines 362-373):
```json
{
  "project_number": $num,
  "project_name": $name,
  "status": "researched",
  "task_type": "meta",
  "next_artifact_number": 2
}
```
No `topic` field at all.

**What needs to change**:
- Insert a new sub-step between "Create Task Directory and Research Artifact" (Step 5.2) and "Update state.json" (Step 5.3): show full Mode A interactive picker
- Use `manage-topics.sh list` to populate options
- After user selects/enters/skips, call `manage-topics.sh add "$topic"` (if not skipping)
- In the Step 5.3 jq block, add `"topic": (if ($topic == "" | not) then $topic else null end)` and `| if .topic == null then del(.topic) else . end`
- The task type is always "meta" (hardcoded); the task is for generating project-overview.md, so `agent-system` is likely the default/auto-suggest

**Proposed insertion point**: After line 293 (mkdir -p command) and before line 362 (state.json jq block). A new "Step 5.2.5: Assign Topic" section.

**Extension copy**: `.claude/extensions/core/skills/skill-project-overview/SKILL.md` — identical, must receive same changes.

---

### Site 4: skills/skill-spawn/SKILL.md — inherit, no fallback (Mode B + fallback)

**File**: `.claude/skills/skill-spawn/SKILL.md`

**Current state** (Stage 11, lines 320-350):
```bash
--arg topic "$parent_topic" \
'...
"topic": (if ($topic == "") then null else $topic end),
...'
```
And Stage 14a (lines 388-400): idiomatic `active_topics` append for inherited topic.

`parent_topic` is read in Stage 1 (line 58):
```bash
parent_topic=$(echo "$task_data" | jq -r '.topic // ""')
```

**What needs to change**:
- The current code already handles the "parent has topic" case correctly (inherits + adds to active_topics)
- The gap is: when `parent_topic` is empty/null, no topic is assigned and no picker is shown
- Add a new stage after Stage 1 (or as Stage 1.5): "If parent_topic is empty, show Mode A interactive picker and set parent_topic from user selection"
- This picker only appears when `parent_topic` is empty; when parent has a topic, the inherit path continues unchanged
- After picker resolves to a new topic, call `manage-topics.sh add "$topic"` (already done in Stage 14a for inherited topics — can unify into same code path)

**Proposed insertion point**: After Stage 1 (line 59), before Stage 2 (line 62 "Preflight Status Update").

**Extension copy**: `.claude/extensions/core/skills/skill-spawn/SKILL.md` — identical, must receive same changes.

---

### Site 5: commands/task.md --expand — inherit, no fallback (Mode B + fallback)

**File**: `.claude/commands/task.md` (Expand Mode section, lines 280-321)

**Current state** (lines 296-303):
```bash
# Step 2.5: Read parent topic for inheritance
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)

# Step 3: Create 2-5 subtasks ... inheriting parent topic
# "Include 'topic': parent_topic in each subtask jq entry (if parent has a topic)"
```

**What needs to change**:
- After reading `parent_topic` (Step 2.5), add a conditional: if `parent_topic` is empty, show Mode A interactive picker to get a topic
- Once topic is resolved (inherited or picked), assign it to all subtasks via `manage-topics.sh set` calls in Step 3
- Also call `manage-topics.sh add` for the resolved topic (currently inline jq does it for inherited; replace with script call)
- The current `"topic": parent_topic` in jq entry format should be preserved; just ensure the variable is populated before use

**Proposed insertion point**: After Step 2.5 (line 303), before Step 3 (line 304 "Create 2-5 subtasks").

**Extension copy**: `.claude/extensions/core/commands/task.md` — identical, must receive same changes.

---

### Site 6: commands/task.md --review — inherit, no fallback (Mode B + fallback)

**File**: `.claude/commands/task.md` (Review Mode section, lines 595-633)

**Current state** (Step 7.5, lines 595-601 and Step 8, lines 607-633):
```bash
# Step 7.5: Read Parent Topic for Inheritance
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)

# Step 8: Create Selected Follow-up Tasks
# ... "topic": (if ($topic == "" | not) then $topic else null end)
```

**What needs to change**:
- After reading `parent_topic` (Step 7.5), add fallback: if `parent_topic` is empty, show Mode A interactive picker
- Once topic is resolved, replace inline `active_topics` maintenance jq in Step 8 with `manage-topics.sh add "$topic"` call
- Replace inline topic write in the jq block with the resolved variable (already the case; just ensure `manage-topics.sh set` is called after task creation)
- The existing Step 8 jq already uses `$topic` variable properly — only the `active_topics` maintenance and the fallback picker are missing

**Proposed insertion point**: New step "Step 7.6: Fallback Topic Picker" between Step 7.5 (line 601) and Step 8 (line 604).

**Extension copy**: `.claude/extensions/core/commands/task.md` — identical, must receive same changes (same file as site 5).

---

## Shared Utility Interface Summary

### manage-topics.sh subcommands

| Subcommand | Use when |
|-----------|---------|
| `manage-topics.sh list` | Building AskUserQuestion options array (Mode A) |
| `manage-topics.sh add TOPIC` | After any topic is resolved, before writing task entry |
| `manage-topics.sh set TASK_NUM TOPIC` | After task entry is written to state.json |
| `manage-topics.sh validate TOPIC` | Optional pre-check before add (add is idempotent, skip usually) |

### topic-assignment-pattern.md modes

| Mode | When to use | Picker shown? |
|------|------------|---------------|
| A: Interactive | project-overview, fallback for B sites | Yes — full list + "New topic..." + "Skip" |
| B: Inherit | spawn/expand/review when parent HAS topic | No — silent inheritance |
| C: Suggest | fix-it, review auto-inference | No full picker — confirm-only (3 options) |

The fallback for B sites (spawn, --expand, --review) is Mode A when parent_topic is empty.

---

## Decisions

1. **Mode C wrapper uses 3-option confirm picker** (not full Mode A): "Accept: {inferred}", "Override...", "Skip". Full Mode A appears only when inference produces no result at all.
2. **Extension copies are mirrors** — all 6 sites have identical copies in `.claude/extensions/core/`; every edit must be applied to both locations.
3. **Batch topic confirmation in fix-it**: confirm fires once per created task, not once per entire scan. This respects per-task ownership.
4. **`manage-topics.sh set` called after task entry exists in state.json**: The `set` subcommand validates task existence (exit code 4 if not found), so it must follow the state.json write.
5. **`manage-topics.sh add` called before `set`**: `set` also calls `add` internally, so a standalone `add` call is redundant; the pattern document shows both for clarity. The implementer may call only `set` (which is atomic: set topic on task + add to active_topics in one jq pass).

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Extension copy drift | Implementation plan must list both paths for every edit |
| Batch tasks prompt fatigue (fix-it) | Confirm prompt only fires when heuristic produces a non-empty topic; empty-inference falls to Mode A once for all tasks in that run |
| `manage-topics.sh set` before task written | Call `set` only in postflight after jq confirms task entry exists |
| task.md has two separate modification sites (--expand and --review) | Plan treats as a single file with two independent sections |

---

## Appendix: File Locations

| Site | Main file | Extension copy |
|------|-----------|----------------|
| 1 fix-it | `.claude/skills/skill-fix-it/SKILL.md` | `.claude/extensions/core/skills/skill-fix-it/SKILL.md` |
| 2 review | `.claude/commands/review.md` | `.claude/extensions/core/commands/review.md` |
| 3 project-overview | `.claude/skills/skill-project-overview/SKILL.md` | `.claude/extensions/core/skills/skill-project-overview/SKILL.md` |
| 4 spawn | `.claude/skills/skill-spawn/SKILL.md` | `.claude/extensions/core/skills/skill-spawn/SKILL.md` |
| 5+6 task (--expand/--review) | `.claude/commands/task.md` | `.claude/extensions/core/commands/task.md` |
