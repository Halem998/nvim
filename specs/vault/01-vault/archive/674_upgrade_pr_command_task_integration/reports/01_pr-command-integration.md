# Research Report: Task #674

**Task**: 674 - upgrade_pr_command_task_integration
**Started**: 2026-06-12T23:30:00Z
**Completed**: 2026-06-12T23:50:00Z
**Effort**: ~25 minutes
**Dependencies**: Tasks 671, 672, 673 (all completed)
**Sources/Inputs**: Codebase — pr.md, skill-pr-implementation/SKILL.md, manifest.json, update-task-status.sh (both projects), generate-todo.sh, state.json (both projects), pr-description.md examples
**Artifacts**: - specs/674_upgrade_pr_command_task_integration/reports/01_pr-command-integration.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/pr` command has 3 input modes (task, path, description) across 11 STEPs; only the task-mode path requires significant changes
- STEP 2 has a hardcoded `state.json` path bug pointing at the nvim config project instead of the cslib project; fix requires using the cslib project path `/home/benjamin/Projects/cslib/specs/state.json`
- STEP 9 (compose PR description) must be redesigned for task-mode to read `pr-description.md` from task artifacts instead of generating from scratch; path convention is `specs/{NNN}_{SLUG}/pr-description.md` at the cslib project root
- Stacked PR detection should use a `base_branch` field added to state.json task metadata by `skill-pr-implementation` (currently missing from that skill); the `/pr` command reads this field and passes it to `gh pr create --base`
- Task completion requires calling `postflight:pr_ready` on the cslib project's own `update-task-status.sh`; however, that script does not yet support `pr_ready` — it also needs to be updated
- The cslib `generate-todo.sh` also needs `pr_ready` added to its `format_status()` function

## Context & Scope

This task upgrades the existing 885-line `/pr` command (`cslib/commands/pr.md`) to integrate with the task lifecycle established by tasks 671–673. The upgrade affects only the task-mode path; path-mode and description-mode are preserved intact. The scope boundary is:

**In scope**:
- Fix hardcoded state.json path bug (STEP 2)
- Add task status validation in STEP 2 (warn if not pr_ready)
- Redesign STEP 2 task-mode to also read pr-description.md and base_branch
- Redesign STEP 5 task-mode: skip branch creation if branch already exists and is correct
- Redesign STEP 8 task-mode: skip interactive title selection (title comes from pr-description.md first line)
- Redesign STEP 9 task-mode: load pr-description.md content instead of generating
- Update STEP 10: use detected base_branch instead of hardcoded `main`
- Add STEP 10b (after PR creation): call `postflight:pr_ready` to transition task to [COMPLETED]
- Update cslib `update-task-status.sh` to support `pr_ready` target status
- Update cslib `generate-todo.sh` to render `pr_ready` as "PR READY"
- Update `skill-pr-implementation` to write `base_branch` to state.json task metadata

**Out of scope**:
- STEP 3 (Environment Check) — unchanged
- STEP 4 (Sync with Upstream) — unchanged
- STEP 6 task-mode (Stage Changes) — minor warning text adjustment only
- STEP 7 (Run CI Pipeline) — unchanged (all 7 CI steps)
- STEP 11 (Offer Merge-Back) — unchanged

## Findings

### Codebase Patterns

#### pr.md Structure Map (885 lines)

```
/pr Command
├── Input Modes
│   ├── task   — pure integer input (e.g., /pr 159)
│   ├── path   — starts with /, ./, ~/  (e.g., /pr ./Cslib/Logics/)
│   └── description — anything else (e.g., /pr prove K soundness)
│
├── STEP 1:  Parse Arguments         — all modes; extract flags, input_mode
├── STEP 2:  Resolve Input           — mode-specific; BUG in task-mode
├── STEP 3:  Environment Check       — all modes; gh auth, remotes, lakefile
├── STEP 4:  Sync with Upstream      — all modes; git fetch upstream
├── STEP 5:  Branch Creation         — all modes; propose + confirm branch name
├── STEP 6:  Stage Changes           — mode-specific; task has no git add
├── STEP 7:  Run CI Pipeline         — all modes; 7-step pipeline
├── STEP 8:  Select PR Title         — all modes; interactive title selection
├── STEP 9:  Compose PR Description  — all modes; generates description body
├── STEP 10: Commit, Push, Create PR — all modes; gh pr create --base main
└── STEP 11: Offer Merge-Back        — all modes; sync origin/main
```

#### Hardcoded state.json Path Bug (STEP 2, line 79)

Current (wrong):
```bash
task_desc=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  /home/benjamin/.config/nvim/specs/state.json 2>/dev/null)
```

This path points to the **nvim configuration project** state.json, not the cslib project. The correct path is `/home/benjamin/Projects/cslib/specs/state.json`.

Fix — define a constant at the top of STEP 2 task-mode section:
```bash
CSLIB_DIR="/home/benjamin/Projects/cslib"
CSLIB_STATE="$CSLIB_DIR/specs/state.json"

task_desc=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  "$CSLIB_STATE" 2>/dev/null)
```

This also eliminates the problem propagating to the task completion step.

#### pr-description.md Artifact Path Convention

From `skill-pr-implementation/SKILL.md` Stage 3:
```
Target output: specs/{NNN}_{SLUG}/pr-description.md
```

This file lives at the **task directory root**, not in a reports/ subdirectory. Confirmed by real examples:
- `/home/benjamin/Projects/cslib/specs/138_subpr_1_1_1_proposition_refactor/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/159_subpr_3_1_temporal_formula/pr-description.md`
- `/home/benjamin/Projects/cslib/specs/145_subpr_2_1_lukasiewicz_primitives/pr-description.md`

The cslib task directory format uses `specs/{NNN}_{project_name}/` (same padded 3-digit convention as the nvim config project). To compute the path:

```bash
task_num_padded=$(printf '%03d' "$input_value")
task_dir="$CSLIB_DIR/specs/${task_num_padded}_${task_name}"
pr_desc_path="$task_dir/pr-description.md"
```

#### pr-description.md Content Format

The canonical format (established by task 672) uses:
1. `# {title}` — H1 heading is the PR title in conventional commit format
2. `## Summary` — 2-4 sentence description
3. `## Context` (optional) — stacked PR info, Zulip links, literature
4. `## File-by-file change summary` — git diff --stat + per-file bullets
5. Optionally: `## Why {X}`, `## Design Rationale`, `## Dependency Graph`
6. `## AI Disclosure` — always last

The title on line 1 (without the `#` prefix) becomes `pr_title` in task-mode, eliminating the need for STEP 8's interactive title selection.

**Important**: The older pr-description.md format (pre-task 672) includes:
```
**Base branch**: `leanprover/cslib:main`
**Head branch**: `benbrastmckie/cslib:refactor/...`
```
These metadata lines are NOT in the new canonical format. The `/pr` command must NOT rely on these lines being present.

#### Stacked PR Base Branch Detection

The task description specifies "detecting base_branch from task metadata" — meaning the approach is to add a `base_branch` field to state.json task entries, written by `skill-pr-implementation` when it creates the PR branch.

Currently `skill-pr-implementation`'s Stage 7 (Link Artifacts) does NOT write `base_branch` to state.json. This field needs to be added.

**Reading base_branch in `/pr` command (STEP 2 task-mode)**:
```bash
base_branch=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .base_branch // "main"' \
  "$CSLIB_STATE" 2>/dev/null)
# Default to "main" if field is missing or null
base_branch="${base_branch:-main}"
```

**Writing base_branch in skill-pr-implementation Stage 7**:
```bash
# Record the base branch in state.json task metadata
jq --argjson num "$task_number" \
   --arg branch "$base_branch_used" \
   '.active_projects |= map(if .project_number == $num then . + {"base_branch": $branch} else . end)' \
   "$CSLIB_STATE" > /tmp/state.tmp && mv /tmp/state.tmp "$CSLIB_STATE"
```

This approach is clean, explicit, and survives between sessions.

#### Task Status Transition on PR Submission

The task lifecycle uses `postflight:pr_ready` to transition a task from `pr_ready` -> `completed`:
- From nvim config `update-task-status.sh` line 97: `postflight:pr_ready) STATE_STATUS="completed"; TODO_STATUS="COMPLETED"`

The cslib project's `update-task-status.sh` currently does NOT support `pr_ready`. Its `map_status()` function only handles `research | plan | implement`. After adding support:

```bash
# In cslib update-task-status.sh map_status():
preflight:pr_ready)   STATE_STATUS="pr_ready";   TODO_STATUS="PR READY" ;;
postflight:pr_ready)  STATE_STATUS="completed";  TODO_STATUS="COMPLETED" ;;
```

The cslib `generate-todo.sh` `format_status()` function also needs:
```bash
pr_ready) printf '%s' "PR READY" ;;
```
(Currently the catch-all `*)` would render "PR_READY" with underscore — wrong.)

**The /pr command task-mode status transition** (new STEP 10b after successful gh pr create):
```bash
# Transition task to [COMPLETED]
cd "$CSLIB_DIR"
bash .claude/scripts/update-task-status.sh postflight "$input_value" pr_ready "$session_id"
```

A `session_id` variable needs to be generated at the start of the command (or passed via context). Pattern: `sess_$(date +%s)_$(head -c8 /dev/urandom | xxd -p)`.

### External Resources

- Task 671 summary: `specs/671_pr_ready_status_lifecycle/summaries/01_implementation-summary.md` — 14 files modified to add pr_ready status to the nvim config agent system; the cslib project was not updated
- Task 672 artifact: `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` — canonical format for CSLib PRs; no CI checklist in body
- Task 673 summary: `specs/673_pr_task_type_routing/summaries/01_implementation-summary.md` — skill-pr-implementation created; writes `pr-description.md` to task root; calls `postflight pr_ready`

### Recommendations

#### STEP-by-STEP Change Plan

| STEP | Change Type | Mode Affected | What Changes |
|------|-------------|---------------|-------------|
| STEP 2 | Bug fix | task | Fix hardcoded state.json path to `/home/benjamin/Projects/cslib/specs/state.json` |
| STEP 2 | Enhancement | task | Also read `project_name`, `status`, and `base_branch` from state.json; warn if status is not `pr_ready` |
| STEP 2 | Enhancement | task | Compute `pr_desc_path = CSLIB_DIR/specs/{NNN}_{project_name}/pr-description.md`; read and store content |
| STEP 2 | Enhancement | task | Extract `pr_title` from first line of pr-description.md (strip leading `# `) |
| STEP 2 | Enhancement | task | Detect `base_branch` from state.json `base_branch` field; default to "main" |
| STEP 5 | Enhancement | task | After user confirms branch, check if feat/slug branch already exists (was created by skill-pr-implementation); if yes, offer to reuse it or create a new one |
| STEP 6 | Minor | task | If no staged changes, don't STOP — just warn and continue (CI verification is still useful) |
| STEP 8 | Enhancement | task | When `pr_title` is already set (from pr-description.md), skip interactive selection; show title and ask to approve or override |
| STEP 9 | Enhancement | task | When `pr_desc_path` exists and `pr_body` not yet set, load from file instead of generating; present to user with same approve/edit/replace options |
| STEP 10 | Bug fix | all | Use `$base_branch` (defaulting to "main") instead of hardcoded `--base main` in `gh pr create` |
| NEW STEP 10b | Feature | task | After successful PR creation, call `bash $CSLIB_DIR/.claude/scripts/update-task-status.sh postflight $input_value pr_ready $session_id` |

#### Files Requiring Changes

| File | Change |
|------|--------|
| `.claude/extensions/cslib/commands/pr.md` | STEP 2 bug fix + enhancements; STEP 5/8/9 task-mode redesign; STEP 10 base_branch fix; new STEP 10b |
| `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` | Add `preflight:pr_ready` and `postflight:pr_ready` cases to `map_status()` |
| `/home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` | Add `pr_ready) printf '%s' "PR READY"` to `format_status()` |
| `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` | Stage 7: write `base_branch` field to state.json task metadata |

## Decisions

1. **base_branch stored in state.json**: The task description explicitly says "detecting base_branch from task metadata". This is cleaner than parsing pr-description.md narrative text. The skill-pr-implementation already has a Stage 7 (Link Artifacts) that writes to state.json — extending it with `base_branch` is minimal.

2. **Default to "main"**: When `base_branch` is not found in state.json (legacy tasks, path-mode, description-mode), `--base main` is the correct default (existing behavior preserved).

3. **Skip STEP 8 title selection for task-mode**: The pr-description.md first line is the canonical title. No interactive selection needed — just show it and offer approve/override. This respects the work already done by skill-pr-implementation.

4. **Load pr-description.md in STEP 9, not generate**: This is the core task-mode redesign. The file was created by skill-pr-implementation following the canonical format; the user approved it during implementation. Regenerating from scratch would be wasteful and potentially inconsistent.

5. **session_id in /pr command**: The command needs a session_id for the status update call. Generate it at the top of the command execution using the standard pattern.

6. **Preserve path-mode and description-mode entirely**: Only task-mode is modified. The other two modes retain all existing behavior including STEP 8 interactive title selection and STEP 9 template-based description generation.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| pr-description.md missing when status is pr_ready | Low | Warn user and offer: generate from scratch (fall through to current STEP 9) or abort |
| base_branch not in state.json for older tasks | High (for legacy tasks) | Default to "main"; the user can override with --branch flag |
| cslib update-task-status.sh update breaks existing usage | Low | Only adds new cases to switch; existing cases unchanged |
| PR already exists for branch (duplicate submission) | Low | gh pr create returns error; STEP 10 already handles push rejection; add guidance |
| Task status not pr_ready when /pr N invoked | Medium | Warn user with current status; offer to continue anyway or abort |
| cslib project state.json missing pr_ready rendering | Currently broken | Fix generate-todo.sh format_status() as part of this task |

## Edge Cases

### Missing pr-description.md

When `/pr N` is called but `pr-description.md` doesn't exist:
1. The task may have been created with type `pr` but `skill-pr-implementation` hasn't run yet → guide user to run `/implement N` first
2. The task may be an old cslib task without `pr` task type → fall through to interactive STEP 9 generation

**Handling**: In STEP 2 task-mode, after computing `pr_desc_path`:
```
if [ -f "$pr_desc_path" ]; then
  pr_body=$(cat "$pr_desc_path")
  pr_title=$(head -1 "$pr_desc_path" | sed 's/^# //')
  has_pr_description=true
else
  has_pr_description=false
  echo "Warning: pr-description.md not found at $pr_desc_path"
  echo "The description will be composed interactively (STEP 9)."
fi
```

### Task Not in pr_ready Status

When `/pr N` is called but the task status is not `pr_ready`:
```
task_status=$(jq -r ... "$CSLIB_STATE")
if [ "$task_status" != "pr_ready" ]; then
  echo "Warning: Task $input_value is in [$task_status] status, not [PR READY]."
  # Ask user to continue anyway or abort
fi
```

### Stacked PR with Unknown base_branch

If `base_branch` is missing from state.json and the pr-description.md contains "stacked on #NNN" text:
1. The command defaults to `--base main`
2. This would create a PR targeting the wrong base
3. Mitigation: Display a warning if "stacked" appears in pr-description.md but base_branch is null:
   ```
   Warning: PR description mentions a stacked PR but base_branch is not set in task metadata.
   Using --base main. If this PR should target a different branch, use --base BRANCH.
   ```

### Skill-pr-implementation Not Yet Updated

Before the `base_branch` field is written to state.json by `skill-pr-implementation`, the `/pr` command defaults to `main`. This is safe — the fix to skill-pr-implementation and the /pr command can be deployed independently, with base_branch defaulting to "main" until skill-pr-implementation writes it.

### STEP 10b: update-task-status.sh Not Yet Updated in cslib

If the cslib `update-task-status.sh` hasn't been updated when STEP 10b runs, it will exit with error. The /pr command should handle this gracefully:
```bash
if ! bash "$CSLIB_DIR/.claude/scripts/update-task-status.sh" postflight "$input_value" pr_ready "$session_id" 2>/dev/null; then
  echo "Note: Could not update task status (pr_ready not supported by update-task-status.sh)."
  echo "Manually update task $input_value to [COMPLETED] in $CSLIB_DIR/specs/"
fi
```

## Context Extension Recommendations

- **Topic**: cslib project lifecycle alignment with nvim config
- **Gap**: The cslib project's `.claude/scripts/` copies of `update-task-status.sh` and `generate-todo.sh` are behind the nvim config's shared scripts — they don't include the `pr_ready` status added by task 671. The extension sync mechanism should propagate these script updates.
- **Recommendation**: After task 674 updates the cslib project scripts directly, note in a context file that the cslib project maintains its own copies of these scripts and they need independent updates when the shared scripts change.

## Appendix

### Search Queries Used

- `grep -n "hardcoded\|/home/benjamin" pr.md` — found line 79 bug
- `find /home/benjamin/Projects/cslib/specs/ -name "pr-description.md"` — found real examples
- `grep -n "pr_ready" update-task-status.sh` (cslib) — confirmed not supported
- `grep -n "format_status" generate-todo.sh` (cslib) — confirmed no pr_ready case

### Key File Paths

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — the command to modify
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — needs base_branch write
- `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh` — needs pr_ready support
- `/home/benjamin/Projects/cslib/.claude/scripts/generate-todo.sh` — needs pr_ready rendering
- `/home/benjamin/Projects/cslib/specs/state.json` — correct state.json path (not nvim config)
- `/home/benjamin/Projects/cslib/specs/{NNN}_{SLUG}/pr-description.md` — artifact read by /pr

### pr-description.md Format Quick Reference

```markdown
# {conventional commit title}

## Summary
{2-4 sentences}

## Context (optional)
{stacked PR / Zulip / literature}

## File-by-file change summary
{### file.lean (+N, -M) with bullets}

## AI Disclosure
{standard text, always last}
```

No CI checklist in the body (per task 672 and PR #635 convention).
