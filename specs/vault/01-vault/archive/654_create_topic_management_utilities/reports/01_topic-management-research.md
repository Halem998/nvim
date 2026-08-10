# Research Report: Task #654

**Task**: 654 - create_topic_management_utilities
**Started**: 2026-06-10T00:00:00Z
**Completed**: 2026-06-10T00:30:00Z
**Effort**: Medium (2-3 hours for research)
**Dependencies**: None
**Sources/Inputs**: Codebase (commands/, skills/, agents/, scripts/, context/patterns/)
**Artifacts**: specs/654_create_topic_management_utilities/reports/01_topic-management-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- Topic picker logic is duplicated across **6 primary files** covering approximately **147 lines** of near-identical bash and pseudo-code patterns.
- Three distinct assignment modes exist: **interactive** (full picker in `/task`, `/meta`), **inherit** (parent topic propagation in `--expand`, `--recover`, `/spawn`), and **suggest** (auto-inferred topic in `/review`, `/fix-it`).
- The `active_topics` maintenance snippet (`jq --arg t "$topic" 'if … index($t) == null then …'`) is copy-pasted verbatim in at least **5 locations**.
- No `flock` is currently used for state.json writes; the existing convention is a **tmp-file atomic write** (`jq … > file.tmp && mv file.tmp file`).
- A suitable home for the new pattern document is `.claude/context/patterns/topic-assignment-pattern.md` (alongside `jq-escaping-workarounds.md`, `skill-lifecycle.md`, etc.).
- The script should live at `.claude/scripts/manage-topics.sh` following the naming and structure conventions of `update-task-status.sh`, `generate-task-order.sh`, etc.

---

## Context & Scope

This research surveyed all `.claude/` content (commands, skills, agents, scripts, context/patterns) to catalog every location where topic assignment logic is inlined, understand the state.json `active_topics` data model, and identify script conventions to follow for `manage-topics.sh`.

---

## Findings

### 1. Codebase Patterns — Locations of Duplicated Topic Logic

#### 1.1 Interactive Picker (full picker — read + ask + handle new + write)

**File**: `.claude/commands/task.md`, lines 133–170 (Step 4.5, Create Mode)

```
existing_topics=$(jq -r '.active_topics // [] | .[]' specs/state.json)
AskUserQuestion: options from active_topics + "New topic..." + "Skip (no topic)"
If "New topic...": follow-up free-text AskUserQuestion
Active Topics Maintenance: jq --arg t "$topic" 'if (.active_topics // [] | index($t)) == null then ...' pattern
```

Approximately **38 lines** of picker prose + bash code.

**File**: `.claude/commands/task.md`, lines 351–402 (Step 6.5, Sync Mode — Topic Backfill)

This is the same interactive picker repeated for each task missing a `topic` field:

```
missing_topics=$(jq -r '.active_projects[] | select(…) | select(.topic == null or .topic == "") | …' specs/state.json)
existing_topics=$(jq -r '.active_topics // [] | .[]' specs/state.json)
AskUserQuestion per task (mirrors Step 4.5 pattern)
Active Topics Maintenance: same jq snippet
```

Approximately **52 lines** for this second copy.

**File**: `.claude/agents/meta-builder-agent.md`, lines 552–605 (Interview Stage 4.5, AssignTopic)

Same interactive picker at the batch level (one picker for all tasks in the batch):

```
active_topics=$(jq -r '.active_topics[]?' specs/state.json)
AskUserQuestion: same picker structure
If "New topic...": follow-up free-text with kebab-case guidance
```

Approximately **54 lines**.

**File**: `.claude/docs/reference/standards/multi-task-creation-standard.md`, lines 554–605 (Stage 4.5)

Specification document version of the same interactive picker (references meta-builder as reference implementation). Does not contain executable code; contains prose + JSON examples. Approximately **52 lines** of specification prose.

#### 1.2 Inherit Mode (parent topic → child tasks, no picker)

**File**: `.claude/commands/task.md`, lines 292–301 (Step 2.5, Expand Mode)

```bash
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)
# Include "topic": parent_topic in each subtask jq entry
```

**File**: `.claude/commands/task.md`, lines 595–632 (Step 7.5 + Step 8, Recover Mode)

```bash
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)
# topic: (if ($topic == "" | not) then $topic else null end)
```

**File**: `.claude/skills/skill-spawn/SKILL.md`, lines 55–58 and 319–344

```bash
parent_topic=$(echo "$task_data" | jq -r '.topic // ""')  # Inherited by spawned tasks
# topic: (if ($topic == "") then null else $topic end),
```

Stage 14a also has `active_topics` maintenance for the inherited topic (lines 388–400).

#### 1.3 Suggest Mode (auto-infer topic from file path, no picker)

**File**: `.claude/commands/review.md`, lines 519–559

```bash
active_topics=$(jq -r '.active_topics // [] | .[]' specs/state.json)
inferred_topic=""
if echo "$file_path" | grep -qE "^\.claude/|^specs/"; then
  for t in $active_topics; do
    case "$t" in meta|agent-system) inferred_topic="$t"; break;; esac
  done
elif echo "$file_path" | grep -qE "^lua/|^after/"; then
  for t in $active_topics; do
    case "$t" in *neovim*|*nvim*|*lua*) inferred_topic="$t"; break;; esac
  done
fi
```

Approximately **30 lines** for suggest mode.

**File**: `.claude/skills/skill-fix-it/SKILL.md`, lines 451–502 (Steps 9.1 + 9.3)

Same auto-inference heuristic (prose description), followed by the `active_topics` maintenance loop:

```bash
for topic in "${new_topics[@]}"; do
  [[ -z "$topic" ]] && continue
  jq --arg t "$topic" '
    if ((.active_topics // []) | index($t)) == null
    then .active_topics = ((.active_topics // []) + [$t])
    else . end' \
    specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
done
```

Approximately **52 lines** for suggest mode + active_topics maintenance.

#### 1.4 Active Topics Maintenance Snippet (duplicated across all modes)

The following jq pattern appears **5 times** verbatim (task.md ×2, meta-builder-agent.md ×1, skill-spawn/SKILL.md ×1, skill-fix-it/SKILL.md ×1):

```bash
jq --arg t "$topic" '
  if ((.active_topics // []) | index($t)) == null
  then .active_topics = ((.active_topics // []) + [$t])
  else . end' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

The `add TOPIC` subcommand of `manage-topics.sh` will encapsulate this exactly.

---

### 2. state.json Structure — `active_topics` and Task `topic` Fields

From direct inspection of `specs/state.json`:

```json
{
  "version": "1.1.0",
  "next_project_number": 657,
  "active_topics": [
    "wezterm-notifications",
    "workflow-refactor",
    "agent-system"
  ],
  "active_projects": [
    {
      "project_number": 654,
      "project_name": "create_topic_management_utilities",
      "status": "researching",
      "task_type": "meta",
      "topic": "agent-system",
      ...
    }
  ]
}
```

Key observations:
- `active_topics` is a **top-level array** of strings at the root of state.json.
- Each task entry in `active_projects` has an optional `"topic"` field (string or omitted — never `null` in serialized JSON; `null` entries are stripped by `del(.topic)`).
- `generate-task-order.sh` reads `active_topics` for canonical topic ordering in the Task Order section of TODO.md.
- Current topics in the live state: `["wezterm-notifications", "workflow-refactor", "agent-system"]`.
- All 21 active tasks have a `topic` field set.

---

### 3. Script Conventions to Follow

Based on analysis of `update-task-status.sh`, `vault-operation.sh`, `generate-task-order.sh`, and `postflight-research.sh`:

#### 3.1 Header / Shebang

```bash
#!/usr/bin/env bash
# manage-topics.sh - Brief description
#
# Usage: manage-topics.sh <subcommand> [args]
#
# Subcommands:
#   list              Output active_topics as newline-delimited list
#   add TOPIC         Add topic to active_topics (idempotent)
#   set TASK_NUM TOPIC  Set topic field on a task entry
#   validate TOPIC    Check if topic exists (exit 0=yes, 1=no)
```

#### 3.2 Strict Mode

All scripts use `set -euo pipefail`.

#### 3.3 Path Resolution

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TMP_DIR="$PROJECT_ROOT/specs/tmp"
```

#### 3.4 Atomic Write Pattern (no flock — tmp-file rename)

No existing script uses `flock`. The convention is:

```bash
jq '...' "$STATE_FILE" > "$TMP_DIR/state.json.tmp"
# validate
jq empty "$TMP_DIR/state.json.tmp" 2>/dev/null || { echo "Error: invalid JSON"; exit 1; }
mv "$TMP_DIR/state.json.tmp" "$STATE_FILE"
```

This is consistent across all scripts. The `TMP_DIR` (`specs/tmp/`) is created with `mkdir -p` before use.

For `manage-topics.sh`, a cleanup trap should remove the temp file on exit:

```bash
cleanup() { rm -f "$TMP_DIR/state.json.tmp" 2>/dev/null || true; }
trap cleanup EXIT
```

#### 3.5 jq Safety

Always use `| not` instead of `!=` (Issue #1132). The existing `index($t) == null` pattern is already safe.

#### 3.6 Exit Codes

- `0` — success / topic exists (for `validate`)
- `1` — topic does not exist (for `validate`) or validation error
- Other non-zero — operational errors

---

### 4. Three Assignment Modes — Detailed Characterization

#### Mode A: Interactive (Full Picker)

Used by: `/task` Create mode, `/task` Sync/Backfill mode, `/meta` Interview Stage 4.5

**Flow**:
1. Read `active_topics` from state.json via `manage-topics.sh list`
2. Build AskUserQuestion options: one per existing topic + "New topic..." + "Skip (no topic)"
3. If active_topics empty: show only "New topic..." and "Skip (no topic)"
4. If user selects existing topic: `batch_topic = selected_label`
5. If user selects "New topic...": follow-up free-text AskUserQuestion, `batch_topic = user_input`
6. If user selects "Skip (no topic)": `batch_topic = null`
7. If `batch_topic` is set: `manage-topics.sh add "$batch_topic"` (idempotent)
8. Per task: `manage-topics.sh set "$task_num" "$batch_topic"`

#### Mode B: Inherit (Parent Topic, No Picker)

Used by: `/task --expand`, `/task --recover` (follow-up tasks), `/spawn`

**Flow**:
1. Read parent topic: `jq -r --arg num "$N" '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' specs/state.json`
2. If parent has a topic: set it on all child/spawned tasks (no picker shown)
3. `manage-topics.sh add "$parent_topic"` (ensures it stays in active_topics)
4. Per task: `manage-topics.sh set "$new_task_num" "$parent_topic"`

Note: In current code the inherit mode falls back to no-topic if parent has none. There is no fallback picker (unlike in the task description's "inherit with fallback picker"). The task description says "inherit (parent topic with fallback picker)" — this is aspirational for task 655/656.

#### Mode C: Suggest (Auto-Infer, No Picker)

Used by: `/review`, `/fix-it`

**Flow**:
1. Read `active_topics` via `manage-topics.sh list`
2. Match file path against heuristics:
   - Path starts with `.claude/` or `specs/` → look for "meta" or "agent-system" in active_topics
   - Path starts with `lua/` or `after/` → look for `*neovim*|*nvim*|*lua*` in active_topics
3. If matched: `inferred_topic = matched_topic`
4. If no match: `inferred_topic = ""`
5. `manage-topics.sh add "$inferred_topic"` (only if non-empty)
6. Per task: `manage-topics.sh set "$task_num" "$inferred_topic"` (if non-empty)

---

### 5. Pattern Document Conventions

Existing pattern documents in `.claude/context/patterns/` follow this structure:

- **Filename**: kebab-case `.md` (e.g., `jq-escaping-workarounds.md`, `skill-lifecycle.md`)
- **Header**: `# Pattern Name` with metadata fields
- **Overview**: Problem statement and solution summary
- **Sections**: Numbered/headed sections with bash code blocks
- **Cross-references**: Links to related documentation at the bottom

The new `topic-assignment-pattern.md` should follow the same structure.

---

### 6. Context Index Entry

The new pattern document should be registered in `.claude/context/index.json`. Based on the index structure, the entry should look like:

```json
{
  "path": ".claude/context/patterns/topic-assignment-pattern.md",
  "description": "Canonical AskUserQuestion flow and three assignment modes (interactive, inherit, suggest) for topic picker logic",
  "line_count": 120,
  "subdomain": "patterns",
  "topics": ["topic-management", "state-json", "active-topics", "picker"],
  "load_when": {
    "always": false,
    "agents": ["meta-builder-agent"],
    "task_types": ["meta"],
    "commands": ["/task", "/meta", "/spawn", "/review", "/fix-it"]
  }
}
```

---

## Decisions

1. **No flock**: The existing convention is tmp-file atomic write. `manage-topics.sh` will follow this pattern exactly for consistency, rather than introducing `flock` as a new dependency.

2. **`validate` subcommand exits 0/1**: Exit 0 = topic exists, exit 1 = topic does not exist (standard Unix convention for boolean check scripts).

3. **`set` subcommand is idempotent**: Setting a task to a topic it already has is a no-op (no error).

4. **`add` is safe on empty/null active_topics**: Uses `(.active_topics // [])` pattern already established in codebase.

5. **Script location**: `.claude/scripts/manage-topics.sh` (consistent with all other scripts in this directory).

6. **Pattern document location**: `.claude/context/patterns/topic-assignment-pattern.md` (alongside peer pattern docs).

7. **Scope of task 654**: Only create the utilities. Tasks 655 and 656 will refactor existing commands to use them.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Commands 655/656 may reference specific line numbers that shift during refactor | task 654 creates utilities only; refactor happens in 655/656 separately |
| `jq index()` performance on large active_topics arrays | active_topics arrays are small (< 20 items in practice); no concern |
| `set` subcommand requires knowing task is in active_projects | Add validation with clear error message, exit code 1 |
| Pattern doc becomes stale as modes evolve | Add `**Last reviewed**` date field and note task 655/656 as implementers |
| generate-task-order.sh reads active_topics directly from state.json | manage-topics.sh writes to the same state.json; no compatibility concerns |

---

## Context Extension Recommendations

- **Topic**: `manage-topics.sh` usage conventions
- **Gap**: No documentation on the new script's API contract (subcommands, exit codes, expected callers)
- **Recommendation**: The `topic-assignment-pattern.md` document itself will serve as this documentation; also consider adding a brief entry in `.claude/scripts/README.md` if one exists

---

## Appendix

### Files Surveyed

| File | Topic Lines | Mode |
|------|-------------|------|
| `.claude/commands/task.md` | 54 lines | Interactive (Create + Backfill), Inherit (Expand + Recover) |
| `.claude/agents/meta-builder-agent.md` | 37 lines | Interactive |
| `.claude/skills/skill-fix-it/SKILL.md` | 26 lines | Suggest |
| `.claude/skills/skill-spawn/SKILL.md` | 12 lines | Inherit |
| `.claude/commands/review.md` | 15 lines | Suggest |
| `.claude/docs/reference/standards/multi-task-creation-standard.md` | 3 lines | Spec (references meta-builder) |
| `.claude/scripts/generate-task-order.sh` | reads active_topics | Consumer (read-only) |

### Duplication Summary

| Duplicated Pattern | Occurrences |
|-------------------|-------------|
| `jq -r '.active_topics // [] | .[]'` read | 5 |
| Full interactive picker (AskUserQuestion JSON) | 3 |
| Active topics maintenance jq snippet | 5 |
| Parent topic read pattern | 3 |
| `topic: (if ($topic == "" | not) then $topic else null end)` | 4 |

**Total duplication estimate**: ~147 lines of near-identical topic logic across 5 files.

### Proposed Script Interface

```
manage-topics.sh list
  -> outputs: line per topic from .active_topics
  -> exit 0 always (empty output if no topics)

manage-topics.sh add TOPIC
  -> adds TOPIC to .active_topics if not present
  -> idempotent (no error if already present)
  -> exit 0 on success

manage-topics.sh set TASK_NUM TOPIC
  -> sets .active_projects[].topic = TOPIC for project_number == TASK_NUM
  -> calls add TOPIC internally to keep active_topics consistent
  -> exit 0 on success, exit 1 if task not found

manage-topics.sh validate TOPIC
  -> exit 0 if TOPIC in .active_topics
  -> exit 1 if not found
  -> no stdout output
```

### References

- `specs/state.json` — live state.json with current active_topics
- `.claude/scripts/update-task-status.sh` — reference for script structure
- `.claude/scripts/vault-operation.sh` — reference for script structure
- `.claude/context/patterns/jq-escaping-workarounds.md` — jq safety guidance
- `.claude/context/patterns/early-metadata-pattern.md` — metadata pattern reference
