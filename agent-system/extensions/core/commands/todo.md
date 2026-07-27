---
description: Archive completed, abandoned, and expanded tasks
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(mv:*), Bash(mkdir:*), Bash(ls:*), Bash(find:*), Bash(jq:*), TaskCreate, TaskUpdate, AskUserQuestion
argument-hint: "[--dry-run]"
model: sonnet
---

# /todo Command

Archive completed, abandoned, and expanded tasks to clean up active task list.

## Arguments

- `--dry-run` - Show what would be archived without making changes

## Execution

### 1. Parse Arguments

```
dry_run = "--dry-run" in $ARGUMENTS
```

### 2. Scan for Archivable Tasks

Read specs/state.json and identify:
- Tasks with status = "completed"
- Tasks with status = "abandoned"
- Tasks with status = "expanded"

Read specs/TODO.md and cross-reference:
- Entries marked [COMPLETED]
- Entries marked [ABANDONED]
- Entries marked [EXPANDED]

### 2.5. Detect Orphaned Directories

Scan for project directories not tracked in any state file.

**CRITICAL**: This step MUST be executed to identify orphaned directories.

```bash
# Get orphaned directories in specs/ (not tracked anywhere)
orphaned_in_specs=()
for dir in specs/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Check if in state.json active_projects
  in_active=$(jq -r --arg n "$project_num" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/state.json 2>/dev/null)

  # Check if in archive/state.json completed_projects
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If not in either, it's an orphan
  if [ -z "$in_active" ] && [ -z "$in_archive" ]; then
    orphaned_in_specs+=("$dir")
  fi
done

# Get orphaned directories in specs/archive/ (not tracked in archive/state.json)
orphaned_in_archive=()
for dir in specs/archive/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Check if in archive/state.json completed_projects
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If not tracked, it's an orphan
  if [ -z "$in_archive" ]; then
    orphaned_in_archive+=("$dir")
  fi
done

# Combined list for archival operations
orphaned_dirs=("${orphaned_in_specs[@]}" "${orphaned_in_archive[@]}")
```

Collect orphaned directories in two categories:
- `orphaned_in_specs[]` - Directories in specs/ not tracked anywhere (will be moved to archive/)
- `orphaned_in_archive[]` - Directories in archive/ not tracked in archive/state.json (already in archive/, need state entries)

Store counts and lists for later use.

### 2.6. Detect Misplaced Directories

Scan for project directories in specs/ that ARE tracked in archive/state.json (meaning they should be in archive/ but aren't).

**CRITICAL**: This is distinct from orphans - misplaced directories have correct state entries but are in the wrong location.

```bash
# Get misplaced directories (in specs/ but tracked in archive/state.json)
misplaced_in_specs=()
for dir in specs/[0-9]*_*/; do
  [ -d "$dir" ] || continue
  project_num=$(basename "$dir" | cut -d_ -f1)

  # Skip if already identified as orphan (not tracked anywhere)
  in_active=$(jq -r --arg n "$project_num" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/state.json 2>/dev/null)

  # Check if tracked in archive/state.json (should be in archive/)
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)

  # If in archive state but not in active state, it's misplaced
  if [ -z "$in_active" ] && [ -n "$in_archive" ]; then
    misplaced_in_specs+=("$dir")
  fi
done
```

Collect misplaced directories:
- `misplaced_in_specs[]` - Directories in specs/ that are tracked in archive/state.json (need physical move only, no state update)

Store count for later reporting.

### 3. Prepare Archive List

For each archivable task, collect into `candidate_tasks[]`:
- project_number
- project_name (slug)
- status
- completion/abandonment date
- artifact paths

**Subtasks-defer guard**: partition `candidate_tasks[]` into `archivable_tasks[]` (proceeds) and
`deferred_expanded[]` (held back for a later `/todo` run). An expanded parent is deferred while
any task listed in its `subtasks[]` is still present in `active_projects` with a non-terminal
status — this lets a subtask still being worked read its parent's artifacts in place. Use a
`case` statement for status classification, per the jq/shell escaping guidance in the Notes
section (never `!=`):

```bash
archivable_tasks=()
deferred_expanded=()
deferred_expanded_nums=()

for task in "${candidate_tasks[@]}"; do
  status=$(echo "$task" | jq -r '.status')
  project_num=$(echo "$task" | jq -r '.project_number')

  case "$status" in
    expanded)
      # A missing, null, or empty subtasks array means nothing is blocking - archive normally.
      subtasks=$(echo "$task" | jq -c '.subtasks // []')
      subtask_count=$(echo "$subtasks" | jq 'length')
      if [ "$subtask_count" -eq 0 ]; then
        archivable_tasks+=("$task")
        continue
      fi

      blocking_count=0
      for subtask_num in $(echo "$subtasks" | jq -r '.[]'); do
        subtask_status=$(jq -r --argjson n "$subtask_num" \
          '.active_projects[] | select(.project_number == $n) | .status' \
          specs/state.json)

        # An empty result means the subtask is already archived - not blocking.
        if [ -z "$subtask_status" ]; then
          continue
        fi

        case "$subtask_status" in
          completed|abandoned|expanded)
            # Terminal - not blocking.
            ;;
          *)
            # Any other status blocks.
            ((blocking_count++))
            ;;
        esac
      done

      if [ "$blocking_count" -gt 0 ]; then
        deferred_expanded+=("$task")
        deferred_expanded_nums+=("$project_num")
      else
        archivable_tasks+=("$task")
      fi
      ;;
    *)
      # Non-expanded tasks pass through untouched.
      archivable_tasks+=("$task")
      ;;
  esac
done
```

`deferred_expanded_nums[]` (bare project numbers) is consumed by Step 5B's `del()` filter below,
so a deferred parent's archive-list entry is held back WITHOUT the parent being deleted from
`active_projects`. Step 5A (archive/state.json insertion) and Step 5D (directory move) both
iterate `archivable_tasks[]` — the guard-filtered list — never a freshly-recomputed status match.

### 3.5. Scan Roadmap for Task References (Structured Matching)

**Ensure specs/ROADMAP.md exists** before scanning. If the file does not exist, create it with the default template:
```markdown
# Project Roadmap

## Phase 1: Current Priorities (High Priority)

- [ ] (No items yet -- add roadmap items here)

## Success Metrics

- (Define success metrics here)
```

**IMPORTANT**: Meta tasks (task_type: "meta") are excluded from ROADMAP.md matching since they
modify system infrastructure rather than project deliverables. Expanded tasks are excluded for a
structural reason: an expanded task has no `completion_summary` of its own by construction (its
subtasks carry the deliverables), so a future reader must not "fix" this by requiring one.
`roadmap-integration.sh` has no `task_type` filter and no abandoned-status branch of its own (see
its header's "Caller contract" section), so this exclusion partition is entirely `/todo`'s
responsibility -- the script cannot do it for us.

**Step 3.5.1: Separate roadmap-excluded and roadmap-eligible tasks**:
```bash
# Separate archivable tasks: excluded from ROADMAP.md matching vs. eligible for it
roadmap_excluded_tasks=()
roadmap_eligible_tasks=()

for task in "${archivable_tasks[@]}"; do
  task_type=$(echo "$task" | jq -r '.task_type // "general"')
  task_status=$(echo "$task" | jq -r '.status')
  if [ "$task_type" = "meta" ] || [ "$task_status" = "expanded" ]; then
    roadmap_excluded_tasks+=("$task")
  else
    roadmap_eligible_tasks+=("$task")
  fi
done
```

**Step 3.5.2: Parse-only invocation of `roadmap-integration.sh`**:

This step replaces `/todo`'s own checkbox-only, table-blind grep matcher entirely. Calling the
shared script in parse-only mode (no `--annotate`) gives `/todo` full table-row-aware parsing,
the complete `roadmap_matches[]` list (with `confidence`, `match_type`, and for table rows
`line_index`/`raw_line`/`status_index`), and the always-on `roadmap_structure`/`parseable`/
`warnings` diagnostics -- with zero duplicate parsing code. `/todo` never implements matching
itself from this point forward; it only ever constructs an input and reads a payload.

```bash
# Parse-only call: no --annotate. Capture the invocation's own exit status immediately -- do not
# rely solely on the file-existence guard below, mirroring commands/review.md's Step 2.5 pattern.
roadmap_exit=0
roadmap_output=$(bash .claude/scripts/roadmap-integration.sh \
  --roadmap specs/ROADMAP.md \
  --state specs/state.json) || roadmap_exit=$?
```

**Step 3.5.3: Extract structured fields for downstream use**:
```bash
roadmap_state=$(echo "$roadmap_output" | jq '.roadmap_state')
roadmap_matches_raw=$(echo "$roadmap_output" | jq '.roadmap_matches')
roadmap_structure=$(echo "$roadmap_output" | jq '.roadmap_structure')
roadmap_warnings=$(echo "$roadmap_output" | jq '.warnings')
annotation_summary=$(echo "$roadmap_output" | jq '.annotation_summary')
high_confidence_matches=$(echo "$annotation_summary" | jq '.high_confidence_matches')
silent_noop=$(echo "$annotation_summary" | jq '.silent_noop')
```

**Error handling** (identical contract to `commands/review.md`'s Step 2.5): if
`roadmap-integration.sh` is missing, exits non-zero, or produces empty output, log a visible
warning and fall back to the same fully-defined defaults. Both "script missing" and "script
present but failed" must surface the same warning and fallback -- neither is allowed to fail
silently, and no downstream branch is left reading an unbound variable:

```bash
if [ ! -f .claude/scripts/roadmap-integration.sh ]; then
  echo "Warning: roadmap-integration.sh not found -- skipping roadmap integration" >&2
  roadmap_state='{"phases":[],"status_tables":[]}'
  roadmap_matches_raw='[]'
  roadmap_structure='{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}'
  roadmap_warnings='[]'
  high_confidence_matches=0
  silent_noop=false
elif [[ "$roadmap_exit" -ne 0 ]] || [[ -z "$roadmap_output" ]]; then
  echo "Warning: roadmap-integration.sh exited $roadmap_exit or produced empty output -- skipping roadmap integration" >&2
  roadmap_state='{"phases":[],"status_tables":[]}'
  roadmap_matches_raw='[]'
  roadmap_structure='{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}'
  roadmap_warnings='[]'
  high_confidence_matches=0
  silent_noop=false
fi
```

**Step 3.5.4: Eligibility filter -- where meta/expanded exclusion is enforced**:

`roadmap-integration.sh` has no `task_type` filter of its own (see its header's "Caller
contract"), so `/todo` reduces the raw match list to only the tasks Step 3.5.1 classified as
eligible. Everything downstream of this step consumes `roadmap_eligible_matches[]`, never
`roadmap_matches_raw`:

```bash
roadmap_eligible_nums=$(printf '%s\n' "${roadmap_eligible_tasks[@]}" | jq -s '[.[] | .project_number]')
roadmap_eligible_matches=$(echo "$roadmap_matches_raw" | jq --argjson eligible "$roadmap_eligible_nums" \
  '[.[] | select(.matched_task as $t | $eligible | index($t) != null)]')
```

Track:
- `roadmap_excluded_tasks[]` - Array of tasks excluded from ROADMAP.md matching (meta tasks, and
  expanded tasks since they have no `completion_summary` of their own by construction)
- `roadmap_eligible_tasks[]` - Array of tasks eligible for ROADMAP.md matching
- `roadmap_structure` / `roadmap_warnings` - The always-on structure signal and warning codes
  from `roadmap-integration.sh`, present in every mode
- `roadmap_eligible_matches[]` - The script's `roadmap_matches[]`, filtered to eligible tasks --
  the sole input to Step 4's dry-run output and Step 5.5's annotation
- `high_confidence_matches` / `silent_noop` - From `annotation_summary`, always defined even
  though no annotation has run yet (parse-only mode reports 0/false, never an unbound variable)

**Match Types** (the shared script's vocabulary -- both checkbox and table-row matches are live
against this repository's actual `ROADMAP.md`, which is table-based with zero checkboxes: a
parse-only run reports `checkboxes` and `table_rows` in `roadmap_structure`, and either source
can populate `roadmap_eligible_matches[]`):
- `confidence`: `high` (auto-annotate candidate), `medium`, or `low` (report only)
- `match_type`: `explicit_task_ref`, `explicit_roadmap_item`, `exact_title_match`,
  `title_match`, or `keyword_match` -- see the script's `find_match` heuristic
- Checkbox-sourced matches carry no `source` key; table-row-sourced matches carry
  `source: "status_table"` plus `line_index`/`raw_line`/`status_index`, which the annotation
  step (Step 5.5) uses to locate and safely rewrite the matched row in place

### 4. Dry Run Output (if --dry-run)

```
Tasks to archive:

Completed:
- #{N1}: {title} (completed {date})
- #{N2}: {title} (completed {date})

Abandoned:
- #{N3}: {title} (abandoned {date})

Expanded:
- #{N10}: {title} (expanded {date})

Deferred (expanded, subtasks still active): {N}
- #{N11}: {title} ({blocking_count} subtask(s) still active)

Orphaned directories in specs/ (will be moved to archive/): {N}
- {N4}_{SLUG4}/
- {N5}_{SLUG5}/

Orphaned directories in archive/ (need state tracking): {N}
- {N6}_{SLUG6}/
- {N7}_{SLUG7}/

Misplaced directories in specs/ (tracked in archive/, will be moved): {N}
- {N8}_{SLUG8}/
- {N9}_{SLUG9}/

Roadmap updates (from completion summaries):

Task #{N1} ({project_name}):
  Summary: "{completion_summary}"
  Matches:
    - [ ] {item text} (line {N}) [explicit]
    - [ ] {item text 2} (line {N}) [exact]

Task #{N2} ({project_name}):
  Summary: "{completion_summary}"
  Matches:
    - [ ] {item text} (line {N}) [exact]

Task #{N3} ({project_name}) [abandoned]:
  Matches:
    - [ ] {item text} (line {N}) [exact] -> *(Task {N} abandoned)*

Total roadmap items to update: {N}
- Completed: {N}
  - Explicit matches: {N}
  - Exact matches: {N}
- Abandoned: {N}

Total tasks: {N}
Total orphans: {N} (specs: {N}, archive: {N})
Total misplaced: {N}

Run without --dry-run to archive.
```

If no roadmap matches were found (from Step 3.5), omit the "Roadmap updates" section. If no
expanded parents were deferred (`deferred_expanded[]` is empty), omit the "Deferred" section.

Exit here if dry run.

### 4.5. Handle Orphaned Directories (if any found)

If orphaned directories were detected in Step 2.5:

**Use AskUserQuestion**:
```json
{
  "question": "Found {N} orphaned directories not tracked in state files. What would you like to do?",
  "header": "Orphans",
  "multiSelect": false,
  "options": [
    {"label": "Track all orphans", "description": "Move to archive/ and add state entries"},
    {"label": "Skip orphans", "description": "Only archive tracked tasks"},
    {"label": "Review list first", "description": "Show full list before deciding"}
  ]
}
```

**If "Review list first" selected**, display directory list then re-ask:
```json
{
  "question": "Track these {N} orphaned directories?",
  "header": "Confirm",
  "multiSelect": false,
  "options": [
    {"label": "Yes, track all", "description": "Move to archive/ and add state entries"},
    {"label": "No, skip", "description": "Only archive tracked tasks"}
  ]
}
```

**Store the user's decision** (track_orphans = true/false) for use in Step 5.

If no orphaned directories were found, skip this step and proceed.

### 4.6. Handle Misplaced Directories (if any found)

If misplaced directories were detected in Step 2.6:

**Use AskUserQuestion**:
```json
{
  "question": "Found {N} misplaced directories in specs/ (tracked in archive/state.json). Move them?",
  "header": "Misplaced",
  "multiSelect": false,
  "options": [
    {"label": "Move all", "description": "Move to archive/ (state already correct)"},
    {"label": "Skip", "description": "Leave in current location"}
  ]
}
```

**Store the user's decision** (move_misplaced = true/false) for use in Step 5F.

If no misplaced directories were found, skip this step and proceed.

### 5. Archive Tasks

**A. Update archive/state.json**

Ensure archive directory exists:
```bash
mkdir -p specs/archive/
```

Read or create specs/archive/state.json:
```json
{
  "archived_projects": [],
  "completed_projects": []
}
```

Move each task in `archivable_tasks[]` (the guard-filtered list from Step 3 — never a
freshly-recomputed status match, so deferred expanded parents are excluded) from state.json
`active_projects` to archive/state.json `completed_projects` (for completed AND expanded tasks)
or `archived_projects` (for abandoned tasks). Expanded tasks join `completed_projects` — there is
no third array.

**B. Update state.json**

Remove archived tasks from active_projects array using `del()` pattern (avoids Issue #1132 with
`!=` operator). **This filter must also subtract any deferred expanded parents**
(`deferred_expanded_nums[]` from Step 3's subtasks-defer guard) — the blanket status match alone
is wrong here: without the subtraction, a parent the guard deferred is still deleted from
`active_projects` even though its archive-list entry was held back, silently losing the task.
Use `index(...) == null` (never `!=`) to express the subtraction:
```bash
# Use del() instead of map(select(.status != "completed" and .status != "abandoned" and .status != "expanded"))
# This pattern is Issue #1132-safe
# deferred_json must default to [] when nothing was deferred.
deferred_json=$(printf '%s\n' "${deferred_expanded_nums[@]:-}" | jq -R 'select(length > 0) | tonumber' | jq -s '.')
jq --argjson deferred "$deferred_json" '
  del(.active_projects[] | select(
    (.status == "completed" or .status == "abandoned" or .status == "expanded")
    and (. as $item | ($deferred | index($item.project_number)) == null)
  ))' specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```
(`. as $item | ...` is required here: without it, `index(.project_number)` evaluates `.` against
`$deferred` itself after the pipe — not against the array element being tested — and jq errors
with "Cannot index array with string". Verified against a representative state.json.)

**C. Update TODO.md**

Remove archived task entries from main sections.

**D. Move Project Directories to Archive**

**CRITICAL**: This step MUST be executed - do not skip it.

For each task in `archivable_tasks[]` (completed, abandoned, or expanded — deferred expanded
parents excluded by the same guard-filtered list as Step 5A):
```bash
# Variables from task data
project_number={N}
project_name={SLUG}

# Compute padded number for consistent directory naming
padded_num=$(printf "%03d" "$project_number")

# Check padded directory first, then fall back to unpadded for legacy
if [ -d "specs/${padded_num}_${project_name}" ]; then
  src="specs/${padded_num}_${project_name}"
elif [ -d "specs/${project_number}_${project_name}" ]; then
  src="specs/${project_number}_${project_name}"
else
  src=""
fi

# Always archive to padded directory
dst="specs/archive/${padded_num}_${project_name}"

if [ -n "$src" ] && [ -d "$src" ]; then
  mv "$src" "$dst"
  echo "Moved: $(basename "$src") -> archive/${padded_num}_${project_name}/"
  # Track this move for output reporting
else
  echo "Note: No directory for task ${project_number} (skipped)"
  # Track this skip for output reporting
fi
```

Track:
- directories_moved: list of successfully moved directories
- directories_skipped: list of tasks without directories

**E. Track Orphaned Directories (if approved in Step 4.5)**

If user selected "Track all orphans" (track_orphans = true):

**Step E.1: Move orphaned directories from specs/ to archive/**
```bash
for orphan_dir in "${orphaned_in_specs[@]}"; do
  dir_name=$(basename "$orphan_dir")
  mv "$orphan_dir" "specs/archive/${dir_name}"
  echo "Moved orphan: ${dir_name} -> archive/"
done
```

**Step E.2: Add state entries for ALL orphans (both moved and existing in archive/)**
```bash
for orphan_dir in "${orphaned_dirs[@]}"; do
  dir_name=$(basename "$orphan_dir")
  project_num=$(echo "$dir_name" | cut -d_ -f1)
  project_name=$(echo "$dir_name" | cut -d_ -f2-)

  # Determine archive path (after potential move)
  archive_path="specs/archive/${dir_name}"

  # Scan for existing artifacts
  artifacts="[]"
  [ -d "$archive_path/reports" ] && artifacts=$(echo "$artifacts" | jq '. + ["reports/"]')
  [ -d "$archive_path/plans" ] && artifacts=$(echo "$artifacts" | jq '. + ["plans/"]')
  [ -d "$archive_path/summaries" ] && artifacts=$(echo "$artifacts" | jq '. + ["summaries/"]')

  # Add entry to archive/state.json
  jq --arg num "$project_num" \
     --arg name "$project_name" \
     --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --argjson arts "$artifacts" \
     '.completed_projects += [{
       project_number: ($num | tonumber),
       project_name: $name,
       status: "orphan_archived",
       archived: $date,
       source: "orphan_recovery",
       detected_artifacts: $arts
     }]' specs/archive/state.json > specs/archive/state.json.tmp \
  && mv specs/archive/state.json.tmp specs/archive/state.json

  echo "Added state entry for orphan: ${dir_name}"
done
```

Track orphan operations for output reporting:
- orphans_moved: count of directories moved from specs/ to archive/
- orphans_tracked: count of state entries added to archive/state.json

**F. Move Misplaced Directories (if approved in Step 4.6)**

If user selected "Move all" (move_misplaced = true):

```bash
# Move misplaced directories from specs/ to archive/
misplaced_moved=0
for dir in "${misplaced_in_specs[@]}"; do
  dir_name=$(basename "$dir")
  dst="specs/archive/${dir_name}"

  # Check if destination already exists
  if [ -d "$dst" ]; then
    echo "Warning: ${dir_name} already exists in archive/, skipping"
    continue
  fi

  mv "$dir" "$dst"
  echo "Moved misplaced: ${dir_name} -> archive/"
  ((misplaced_moved++))
done
```

**Note**: Unlike orphans, misplaced directories do NOT need state entries added - they are already correctly tracked in archive/state.json. Only the physical move is needed.

Track misplaced operations for output reporting:
- misplaced_moved: count of directories moved from specs/ to archive/

### 5.5. Update Roadmap for Archived Tasks

**Context**: Load @.claude/context/patterns/roadmap-update.md for matching strategy.

For each archived task with roadmap matches (from Step 3.5):

**1. Read current ROADMAP.md content**

**2. Parse match tuple** (from Step 3.5):
```bash
# roadmap_matches[] entries are: project_num:status:match_type:line_num:item_text
# Parse components
project_num=$(echo "$match" | cut -d: -f1)
status=$(echo "$match" | cut -d: -f2)
match_type=$(echo "$match" | cut -d: -f3)  # explicit, exact, or summary
line_num=$(echo "$match" | cut -d: -f4)
item_text=$(echo "$match" | cut -d: -f5-)
```

**3. For each match, determine if already annotated**:
```bash
# Skip if already has completion or abandonment annotation
if echo "$line_content" | grep -qE '\*(Completed:|\*(Abandoned:|\*(Task [0-9]+ abandoned:'; then
  echo "Skipped: Line $line_num already annotated"
  ((roadmap_skipped++))
  continue
fi
```

**4. Apply appropriate annotation based on match type**:

For completed tasks with **explicit** match (via roadmap_items):
```
Edit old_string: "- [ ] {item_text}"
     new_string: "- [x] {item_text} *(Completed: Task {N}, {DATE})*"
```

For completed tasks with **exact** match (via Task N reference):
```
Edit old_string: "- [ ] {item_text} (Task {N})"
     new_string: "- [x] {item_text} (Task {N}) *(Completed: Task {N}, {DATE})*"
```

For abandoned tasks (checkbox stays unchecked):
```
Edit old_string: "- [ ] {item_text} (Task {N})"
     new_string: "- [ ] {item_text} (Task {N}) *(Task {N} abandoned: {short_reason})*"
```

**5. Track changes**:
```json
{
  "roadmap_updates": {
    "completed_annotated": 2,
    "abandoned_annotated": 1,
    "skipped_already_annotated": 1,
    "by_match_type": {
      "explicit": 1,
      "exact": 1,
      "summary": 0
    }
  }
}
```

Track roadmap operations for output reporting:
- roadmap_completed_annotated: count of completed task items marked
- roadmap_abandoned_annotated: count of abandoned task items annotated
- roadmap_skipped: count of items skipped (already annotated)
- roadmap_by_match_type: breakdown by match type (explicit/exact/summary)

**Safety Rules** (from roadmap-update.md):
- Skip items already containing `*(Completed:` or `*(Task` annotations
- Preserve existing formatting and indentation
- One edit per item (no batch edits to same line)
- Never remove existing content

### 5.6. Sync Repository Metrics

Update repository-wide metrics in both state.json and TODO.md header.

**Step 5.7.1: Compute current metrics**:
```bash
# Count TODOs in source files
todo_count=$(grep -r "TODO" . --include="*.lua" --include="*.py" --include="*.js" --include="*.ts" --include="*.tex" | wc -l)

# Count FIXME markers
fixme_count=$(grep -r "FIXME" . --include="*.lua" --include="*.py" --include="*.js" --include="*.ts" --include="*.tex" | wc -l)

# Get current timestamp
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build errors (0 if project-specific lint/check passes)
if make check 2>/dev/null || npm run lint 2>/dev/null || true; then
  build_errors=0
else
  build_errors=1
fi
```

**Step 5.7.2: Update state.json repository_health**:
```bash
jq --arg todo "$todo_count" \
   --arg fixme "$fixme_count" \
   --arg ts "$ts" \
   --arg errors "$build_errors" \
   '.repository_health = {
     "last_assessed": $ts,
     "todo_count": ($todo | tonumber),
     "fixme_count": ($fixme | tonumber),
     "build_errors": ($errors | tonumber),
     "status": (if ($build_errors | tonumber) == 0 then "healthy" else "needs_attention" end)
   }' specs/state.json > specs/state.json.tmp && mv specs/state.json.tmp specs/state.json
```

**Step 5.7.3: Update TODO.md frontmatter**:

Read TODO.md and update the YAML frontmatter `technical_debt` section to match state.json:
```bash
# Using Edit tool to update TODO.md frontmatter
# old_string: current technical_debt block
# new_string: updated technical_debt block with current values
```

The technical_debt block should be updated to:
```yaml
technical_debt:
  todo_count: {todo_count}
  fixme_count: {fixme_count}
  build_errors: {build_errors}
  status: {status}
```

Also update `last_assessed` in repository_health:
```yaml
repository_health:
  overall_score: 90
  production_readiness: improved
  last_assessed: {ts}
```

**Step 5.7.4: Report metrics sync**:
Track for output:
- `metrics_todo_count`: Current TODO count
- `metrics_fixme_count`: Current FIXME count
- `metrics_build_errors`: Current build errors
- `metrics_synced`: true/false indicating if sync was performed

### 5.7. Vault Operation (when next_project_number > 1000)

When `next_project_number` exceeds 1000, initiate vault archival operation to reset task numbering.

**Step 5.8.1: Detect vault threshold**:
```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  vault_needed=true
fi
```

**Step 5.8.2: Identify tasks to renumber**:
```bash
# Find active tasks with project_number > 1000
tasks_to_renumber=$(jq -r '
  .active_projects[] |
  select(.project_number > 1000) |
  {
    old_number: .project_number,
    new_number: (.project_number - 1000),
    project_name: .project_name
  }
' specs/state.json)

renumber_count=$(echo "$tasks_to_renumber" | jq -s 'length')
```

**Step 5.8.3: User confirmation**:

Use AskUserQuestion with vault operation details:
```json
{
  "question": "Task numbering has exceeded 1000. Initiate vault archival?",
  "header": "Vault Operation",
  "description": "Current next_project_number: {next_num}\nActive tasks to renumber: {renumber_count}\n\nThis will:\n1. Move specs/archive/ to specs/vault/{NN-vault}/\n2. Renumber tasks > 1000 by subtracting 1000\n3. Reset next_project_number",
  "options": [
    {"label": "Yes, proceed with vault operation", "value": "proceed"},
    {"label": "No, skip vault this time", "value": "skip"}
  ]
}
```

If user selects "skip", proceed to Step 6 (Git Commit).

**Step 5.8.4: Create vault directory**:
```bash
vault_count=$(jq -r '.vault_count // 0' specs/state.json)
new_vault_num=$((vault_count + 1))
vault_dir_name=$(printf "%02d-vault" "$new_vault_num")
vault_path="specs/vault/${vault_dir_name}"

mkdir -p "$vault_path"
mv "specs/archive" "${vault_path}/archive"
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
```

**Step 5.8.5: Create vault meta.json**:
```bash
current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
archived_count=$(jq -r '.completed_projects | length' "${vault_path}/state.json" 2>/dev/null || echo "0")

jq -n \
  --arg vault_num "$new_vault_num" \
  --arg created_at "$current_timestamp" \
  --argjson archived_count "$archived_count" \
  --argjson final_task_num "$next_num" \
  '{
    vault_number: ($vault_num | tonumber),
    created_at: $created_at,
    archived_count: $archived_count,
    final_task_number: $final_task_num
  }' > "${vault_path}/meta.json"
```

**Step 5.8.6: Reinitialize archive**:
```bash
mkdir -p "specs/archive"
jq -n '{ "completed_projects": [] }' > "specs/archive/state.json"
```

**Step 5.8.7: Renumber tasks > 1000**:

For each task with project_number > 1000:
1. Update state.json project_number (subtract 1000)
2. Update artifact paths (4-digit dir -> 3-digit dir)
3. Update dependencies arrays
4. Rename task directories
5. Update TODO.md entries

**Step 5.8.8: Reset state**:
```bash
# Calculate new next_project_number
max_active=$(jq -r '[.active_projects[].project_number] | max // 0' specs/state.json)
new_next_num=$((max_active + 1))

# Update state.json
jq --argjson new_next "$new_next_num" \
   --argjson vault_num "$new_vault_num" \
   --arg vault_path "$vault_path/" \
   --arg created "$current_timestamp" \
   '.next_project_number = $new_next |
    .vault_count = (.vault_count // 0) + 1 |
    .vault_history = (.vault_history // []) + [{
      vault_number: $vault_num,
      vault_dir: $vault_path,
      created_at: $created
    }]' specs/state.json > specs/state.json.tmp
mv specs/state.json.tmp specs/state.json
```

**Step 5.8.9: Add transition comment to TODO.md**:
```bash
current_date=$(date +"%Y-%m-%d")
comment="<!-- Vault transition: ${current_date} - Archived to ${vault_path}/ -->"
# Insert after frontmatter
```

Track vault operations for output:
- `vault_created`: true/false
- `vault_path`: path to new vault
- `tasks_renumbered`: count of tasks renumbered
- `new_next_project_number`: reset value

### 6. Git Commit

```bash
git add specs/
git commit -m "todo: archive {N} completed tasks"
```

Include roadmap, orphan, and misplaced counts in message as applicable:
```bash
# If roadmap items updated, orphans tracked, and misplaced moved:
git commit -m "todo: archive {N} tasks, update {R} roadmap items, track {M} orphans, move {P} misplaced"

# If roadmap items updated only:
git commit -m "todo: archive {N} tasks, update {R} roadmap items"

# If roadmap items updated and orphans tracked:
git commit -m "todo: archive {N} tasks, update {R} roadmap items, track {M} orphaned directories"

# If orphans tracked and misplaced moved (no roadmap):
git commit -m "todo: archive {N} tasks, track {M} orphans, move {P} misplaced directories"

# If only orphans tracked (no roadmap):
git commit -m "todo: archive {N} tasks and track {M} orphaned directories"

# If only misplaced moved (no roadmap):
git commit -m "todo: archive {N} tasks and move {P} misplaced directories"
```

Where `{R}` = roadmap_completed_annotated + roadmap_abandoned_annotated (total roadmap items updated).

### 7. Output

Use grouped counts instead of listing individual items:

```
Archived {N} tasks

Tasks: {C} completed, {A} abandoned, {E} expanded
Directories: {D} moved

{If any expanded parents were deferred:}
Deferred: {F} expanded parent(s) held back (subtasks still active)

{If orphans or misplaced processed:}
Cleanup: {O} orphans tracked, {P} misplaced moved

{If roadmap updated:}
Roadmap: {R} items updated

{If CLAUDE.md suggestions:}
CLAUDE.md: {applied}/{total} suggestions applied

Active tasks remaining: {N}

Next Steps:
1. Review archive at specs/archive/
2. Run /review for codebase analysis
```

**Section Inclusion Rules:**

| Section | Show When |
|---------|-----------|
| Tasks | Always (with counts) |
| Directories | directories_moved > 0 |
| Deferred | deferred_expanded[] is non-empty |
| Cleanup | orphans_tracked > 0 OR misplaced_moved > 0 |
| Roadmap | roadmap items updated |

If no roadmap items were updated (no matches found in Step 3.5):
- Omit the "Roadmap updated" section

## Notes

### Task Archival
- Archivable statuses are exactly `completed`, `abandoned`, and `expanded` — these are the
  terminal states defined in `context/standards/status-markers.md`'s Validation Rules section.
  `partial` and `blocked` are NOT archivable: they are non-terminal, resumable states, and any
  command may pick a task back up from them.
- `completed` and `expanded` tasks route to archive/state.json's `completed_projects` array;
  `abandoned` tasks route to `archived_projects`. There is no third array for `expanded`.
- **Subtasks-defer guard**: an expanded parent waits to be archived until every task in its
  `subtasks[]` reaches a terminal status, so a subtask still being worked can read its parent's
  artifacts in place. A missing/empty `subtasks[]`, or a subtask no longer in `active_projects`
  (already archived), is never treated as blocking. This guard addresses only the parent/child
  case — general cross-task artifact citations remain a known, pre-existing limitation of
  archival (a plain directory `mv`, plus vault renumbering, can still break a citation from one
  archived task's artifacts into another's).
- Artifacts (plans, reports, summaries) are preserved in archive/{NNN}_{SLUG}/
- Tasks can be recovered with `/task --recover N`
- Archive is append-only (for audit trail)
- Run periodically to keep TODO.md and specs/ manageable
- Completion-time reflections (when present on a task's `reflection` field) are surfaced
  read-only during archival per `skill-todo/SKILL.md`'s memory-harvest stage.

### Orphan Tracking

**Orphan Categories**:
1. **Orphaned in specs/** - Directories in `specs/` not tracked in any state file
   - Action: Move to archive/ AND add entry to archive/state.json
2. **Orphaned in archive/** - Directories in `specs/archive/` not tracked in archive/state.json
   - Action: Add entry to archive/state.json (no move needed)

**orphan_archived Status**:
- Orphaned directories receive status `"orphan_archived"` in archive/state.json
- The `source` field is set to `"orphan_recovery"` to distinguish from normal archival
- The `detected_artifacts` field lists any existing subdirectories (reports/, plans/, summaries/)

**Recovery**:
- Orphaned directories with state entries can be inspected in archive/
- Manual recovery is possible by moving directories and updating state files
- Use `/task --recover N` only for tracked tasks (not orphans)

### Misplaced Directories

**Definition**: Directories in `specs/` that ARE tracked in `archive/state.json`.

This indicates the directory was archived in state but never physically moved.

**Directory Categories Summary**:

| Category | Location | Tracked in state.json? | Tracked in archive/state.json? | Action |
|----------|----------|------------------------|--------------------------------|--------|
| Active | specs/ | Yes | No | Normal (no action) |
| Orphaned in specs/ | specs/ | No | No | Move + add state entry |
| Orphaned in archive/ | archive/ | No | No | Add state entry only |
| Misplaced | specs/ | No | Yes | Move only (state correct) |
| Archived | archive/ | No | Yes | Normal (no action) |

**Misplaced Directories**:
- Already have correct state entries in archive/state.json
- Only need to be physically moved to specs/archive/
- No state updates required

**Causes of Misplaced Directories**:
- Directory move failed silently during previous archival
- Manual state edits without corresponding directory moves
- System interrupted during archival process
- /todo command Step 5D not executing consistently

**Recovery**:
- Use `/task --recover N` to recover misplaced directories (they have valid state entries)
- After moving, the directory will be in the correct location matching its state

### Roadmap Updates

**Matching Strategy** (Structured Synchronization):

Roadmap matching uses structured data from completed tasks, not keyword heuristics:

1. **Explicit roadmap_items** (Priority 1, highest confidence):
   - Tasks can include a `roadmap_items` array in state.json
   - Contains exact item text to match against ROADMAP.md
   - Example: `"roadmap_items": ["Improve /todo command roadmap updates"]`

2. **Exact (Task N) references** (Priority 2):
   - Searches ROADMAP.md for `(Task {N})` patterns
   - Works with existing roadmap items that reference task numbers

3. **Summary-based search** (Future enhancement):
   - Uses `completion_summary` field to find semantically related items
   - Not currently implemented (placeholder for future)

**Producer/Consumer Workflow**:
- `/implement` is the **producer**: populates `completion_summary` and optional `roadmap_items`
- `/todo` is the **consumer**: extracts these fields via jq and matches against ROADMAP.md

**Annotation Formats**:

Completed tasks with explicit match:
```markdown
- [x] {item text} *(Completed: Task {N}, {DATE})*
```

Completed tasks with exact (Task N) match:
```markdown
- [x] {item text} (Task {N}) *(Completed: Task {N}, {DATE})*
```

Abandoned tasks (checkbox stays unchecked):
```markdown
- [ ] {item text} (Task {N}) *(Task {N} abandoned: {short_reason})*
```

**Safety Rules**:
- Skip items already annotated (contain `*(Completed:` or `*(Task` patterns)
- Preserve existing formatting and indentation
- One edit per item
- Never remove existing content

**Date Format**: ISO date (YYYY-MM-DD) from task completion/abandonment timestamp

**Abandoned Reason**: Truncated to first 50 characters of `abandoned_reason` field from state.json

**Well-Formed Completion Summaries**:

Good examples:
- "Implemented structured synchronization between task completion data and roadmap updates. Added completion_summary field to task schema."
- "Fixed modal logic proof for reflexive frames. Added missing transitivity lemma and updated test cases."
- "Created LaTeX documentation for Logos layer architecture with diagrams and examples."

The summary should:
- Be 1-3 sentences describing what was accomplished
- Focus on outcomes, not process
- Be specific enough to enable roadmap matching

### jq Pattern Safety (Issue #1132)

**Problem**: Claude Code Issue #1132 causes jq commands with `!=` operators to fail with `INVALID_CHARACTER` or syntax errors when Claude generates them inline.

**Solution**: This command uses safe jq patterns throughout:

1. **File-based filters** for `!=` operators:
   ```bash
   # Instead of: jq 'select(.task_type != "meta")' file
   cat > specs/tmp/filter_$$.jq << 'EOF'
   select(.task_type != "meta")
   EOF
   jq -f specs/tmp/filter_$$.jq file && rm -f specs/tmp/filter_$$.jq
   ```

2. **`has()` for null checks**:
   ```bash
   # Instead of: jq 'select(.field != null)'
   jq 'select(has("field"))'
   ```

3. **`del()` for exclusion filters**:
   ```bash
   # Instead of: jq '.array |= map(select(.status != "completed"))'
   jq 'del(.array[] | select(.status == "completed"))'
   ```

**Reference**: See `.claude/context/patterns/jq-escaping-workarounds.md` for comprehensive patterns.
