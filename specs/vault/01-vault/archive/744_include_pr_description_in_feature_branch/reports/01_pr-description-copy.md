# Research: Include pr-description.md in Feature Branch

- **Task**: 744
- **Date**: 2026-06-18

## Findings

### Current Flow

The `/pr` command (`pr.md`) has this flow for task-mode:

1. STEP 2: Loads `pr-description.md` from `specs/{NNN}_{SLUG}/pr-description.md` (in the nvim config repo)
2. STEP 9: Displays it and asks user for approval/edits
3. STEP 10: Commits, pushes, and creates PR using the loaded `pr_body`

The `pr-description.md` file is never copied into the cslib repo. It only exists in the nvim config's specs directory.

### Desired Behavior

After STEP 9 (description approved) and before STEP 10 (commit/push), copy `pr-description.md` into the cslib repo root so the user can view it while checking the branch. The file should be:
- Copied to `$CSLIB_DIR/pr-description.md`
- Left **unstaged** (not git-added) so it doesn't become part of the PR commit
- Present only as a convenience for the user to review the full description in the context of the feature branch

### Insertion Point

Between lines 1471 (`**On success**: **IMMEDIATELY CONTINUE** to STEP 10.`) and 1475 (`### STEP 10: Commit, Push, and Create PR`), insert a new `### STEP 9b: Copy PR Description to Feature Branch`.

### Scope

- Only applies in task mode (`input_mode="task"`) when `has_pr_description=true`
- Path mode and description mode don't have a pre-built pr-description.md
- The copy should use the final `pr_body` (which may have been edited by the user in STEP 9)

### File to Modify

- `.claude/extensions/cslib/commands/pr.md` — insert new STEP 9b
