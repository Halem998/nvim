# Checkpoint: COMMIT (Finalization)

The COMMIT checkpoint creates a git commit and completes the operation.

## Execution Steps

### 1. Determine Targeted Scope

Apply the operation's scope from `.claude/context/standards/git-staging-scope.md` — under-stage,
never over-stage, and never `git add -A` / `git add .`:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json")

# implement only: also stage the plan file and self-reported modified_files
if [ "$operation" = "implement" ]; then
  [ -n "$plan_path" ] && stage_paths+=("$plan_path")
  metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
  while IFS= read -r f; do
    [ -n "$f" ] && stage_paths+=("$f")
  done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
fi
```

Staging itself happens as part of Step 3's scoped-commit call — do not run a separate `git add`.

### 2. Compose Commit Message Body

Format depends on operation. `git-commit-scoped.sh` appends the trailing `Session: {session_id}`
line itself, so the body passed to `--message` omits it:

**Research:**
```
task {N}: complete research
```

**Plan:**
```
task {N}: create implementation plan
```

**Implementation (complete):**
```
task {N}: complete implementation
```

**Implementation (partial):**
```
task {N}: partial implementation (phases 1-{M} of {total})
```

**Implementation (phase):**
```
task {N} phase {P}: {phase_name}
```

### 3. Create Commit

Stage and commit together via the scoped-commit script, the single sanctioned implementation of
path-scoped, mutex-serialized committing:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "{commit_message}" \
  --session "${session_id}" \
  --honest-index-rows "$task_number" \
  -- "${stage_paths[@]}"
```

### 4. Verify Commit

```bash
# Verify commit was created
if [ $? -eq 0 ]; then
  commit_hash=$(git rev-parse HEAD)
  echo "Commit created: $commit_hash"
else
  echo "WARNING: Commit failed (non-blocking)"
fi
```

### 5. Log Session Completion

Record in operation log (optional):
- session_id
- operation
- task_number
- commit_hash
- timestamp

## Error Handling

Git commit failures are **non-blocking**:
- Log the failure
- Do not roll back state updates
- Report to user that commit failed
- Continue with success return

## Output

Return to caller:
```json
{
  "status": "completed|partial|failed",
  "summary": "{operation summary}",
  "artifacts": [{artifact_list}],
  "metadata": {
    "session_id": "{session_id}",
    "commit_hash": "{hash or null}",
    "phases_completed": {N},
    "phases_total": {M}
  },
  "next_steps": "{guidance}"
}
```
