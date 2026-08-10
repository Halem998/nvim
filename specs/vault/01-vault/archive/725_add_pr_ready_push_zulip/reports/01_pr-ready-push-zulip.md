# Research Report: Task #725

**Task**: 725 - Extend /pr to handle PR READY tasks from the --review workflow
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:30:00Z
**Effort**: 0.5 hours
**Dependencies**: Tasks 722, 723, 724 (completed)
**Sources/Inputs**: Codebase exploration (pr.md, skill-pr-review-implementation/SKILL.md, pr-review-implementation-agent.md, update-task-status.sh), CLI tools (zulip-send --help, gh pr comment --help)
**Artifacts**: specs/725_add_pr_ready_push_zulip/reports/01_pr-ready-push-zulip.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The new PR READY handling for review tasks should be added as **STEP 0.5** in pr.md, inserted between STEP 0 (--review detection) and STEP 1 (normal PR submission flow)
- Detection key: when `$ARGUMENTS` is a pure integer, the task has `sources` array (non-empty), and `status == "pr_ready"` in cslib state.json
- `zulip-send` CLI is installed at `/home/benjamin/.nix-profile/bin/zulip-send` but `~/.zuliprc` has placeholder values (`REPLACE_WITH_*`); the command should check for this and warn the user
- `gh pr comment {pr_number} --body-file {path}` is the correct interface for posting pr-response.md
- `postflight pr_ready` in cslib's `update-task-status.sh` transitions the task to `[COMPLETED]`
- Zulip stream/subject are available in two places: `state.json sources[].parsed.stream_name` and `state.json sources[].parsed.topic`, and also in the `<!-- Send: ... -->` header comment in `zulip-response.md`

---

## Context and Scope

Task 725 adds a new handling path to the existing `/pr` command at `.claude/extensions/cslib/commands/pr.md`. When `/pr N` is invoked on a PR READY task that originated from the `--review` workflow (i.e., has a `sources` array), the command must:

1. Optionally push unpushed commits to the PR branch
2. Post pr-response.md as a GitHub PR comment
3. Optionally send zulip-response.md via zulip-send CLI
4. Transition the task to [COMPLETED]

This is distinct from the existing STEP 1-11 flow, which handles PR submission (branch creation, CI pipeline, PR creation). The new handler is an early-exit path.

---

## Findings

### 1. /pr Command Structure

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` (1,383 lines)

**Current structure**:
- STEP 0: Check for `--review` flag (early exit to STEP 0.1-0.2, then STOP)
- STEP 1: Parse Arguments
- STEP 2: Resolve Input and Working Description (task/path/description modes)
  - Task mode reads `pr-description.md` from cslib task dir and STOPs if not found
- STEP 3: Environment Check
- STEP 4: Sync with Upstream
- STEP 5: Branch Creation
- STEP 5b: Fetch Mathlib Cache
- STEP 6: Stage Changes
- STEP 7: Run CI Pipeline (7 steps)
- STEP 8: Select PR Title
- STEP 9: Compose PR Description
- STEP 10: Commit, Push, and Create PR
- STEP 10b: Transition Task Status to Completed (task mode only)
- STEP 11: Offer Merge-Back

**Key constants defined in STEP 2**:
```bash
CSLIB_DIR="/home/benjamin/Projects/cslib"
CSLIB_STATE="$CSLIB_DIR/specs/state.json"
```

**Detection gap**: STEP 2 task mode looks for `pr-description.md` and STOPs if not found. For review tasks, `pr-response.md` exists instead. Without a new STEP 0.5, the normal flow would fail at STEP 2.

**Insertion point**: New STEP 0.5 should be placed immediately after STEP 0 (after the --review early exit) and before STEP 1. It should early-exit the main flow just like STEP 0 does.

### 2. PR READY Task Detection Logic

A review task in [PR READY] status has these distinguishing characteristics in cslib's `state.json`:

```json
{
  "project_number": N,
  "task_type": "pr",
  "status": "pr_ready",
  "sources": [
    { "type": "github_pr", "url": "...", "parsed": { "owner": "...", "repo": "...", "pr_number": N } },
    { "type": "zulip_thread", "url": "...", "parsed": { "stream_name": "...", "topic": "..." } }
  ]
}
```

Detection bash:
```bash
CSLIB_DIR="/home/benjamin/Projects/cslib"
CSLIB_STATE="$CSLIB_DIR/specs/state.json"

task_status=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  "$CSLIB_STATE" 2>/dev/null)

sources_count=$(jq --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources // [] | length' \
  "$CSLIB_STATE" 2>/dev/null)
```

If `task_status == "pr_ready"` AND `sources_count > 0`: this is a PR READY review task. Run STEP 0.5 and STOP.

**Important**: STEP 0.5 must only activate when `$ARGUMENTS` is a pure integer (task number mode). If `$ARGUMENTS` is a path or description, skip STEP 0.5.

### 3. Artifact Paths for Review Tasks

The pr-review-implementation-agent writes files relative to the cslib task directory:
- `specs/{NNN}_{SLUG}/pr-response.md` - GitHub PR comment body
- `specs/{NNN}_{SLUG}/zulip-response.md` - Zulip message body (may not exist)

For STEP 0.5 in /pr, these paths are:
```bash
task_num_padded=$(printf '%03d' "$input_value")
task_name=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  "$CSLIB_STATE" 2>/dev/null)
task_dir="$CSLIB_DIR/specs/${task_num_padded}_${task_name}"
pr_response_path="$task_dir/pr-response.md"
zulip_response_path="$task_dir/zulip-response.md"
```

### 4. Git Push Strategy for "Single Next Commit"

The task description says "push a single next commit (no squash, preserving the commit as a reference for PR comments)."

The pr-review-implementation-agent applies code changes using the Edit tool without committing them. When /pr handles a PR READY review task, uncommitted code changes may exist in the cslib repository.

**Recommended approach**:
1. Check for uncommitted changes with `git status --porcelain`
2. If changes exist: show them, ask for approval, then `git add -A && git commit -m "task {N}: apply review feedback"`
3. Check for unpushed commits with `git cherry -v origin/HEAD` or `git log --oneline origin/HEAD..HEAD`
4. If unpushed commits exist: ask for push approval, then `git push origin HEAD`

The "single commit" language means: push only the topmost unpushed commit, not all unpushed commits. However, since the review typically adds one commit, this is naturally satisfied.

**No squash**: Use `git push origin HEAD` (not force-push with squash). The `pr-prohibition.md` rule prohibits agents from pushing; this command is user-invoked so pushing is permitted.

**Branch**: The cslib feature branch associated with the PR. Since the PR was previously created via `/pr` (STEP 10), the branch should already exist on origin. The current branch in cslib is the feature branch. Alternatively, derive from the GitHub PR URL:
```bash
pr_number=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "github_pr") | .parsed.pr_number' \
  "$CSLIB_STATE" 2>/dev/null)
# Fetch branch from GitHub
branch=$(gh pr view "$pr_number" --repo leanprover/cslib --json headRefName -q '.headRefName' 2>/dev/null)
```

### 5. AskUserQuestion Interface

The AskUserQuestion tool accepts JSON with:
```json
{
  "question": "Question text shown to user",
  "header": "Section header",
  "multiSelect": false,
  "options": [
    {"label": "Option label", "description": "Explanatory text"},
    ...
  ]
}
```

**Two approvals needed**:

Approval 1 - Push approval:
```json
{
  "question": "Push response commit to origin and post pr-response.md as GitHub PR comment #{pr_number}?",
  "header": "PR READY: Post Review Response",
  "multiSelect": false,
  "options": [
    {"label": "Yes, push and post", "description": "Push the commit and post pr-response.md to GitHub PR #{pr_number}"},
    {"label": "Preview first", "description": "Show the pr-response.md content before posting"},
    {"label": "Cancel", "description": "Do not push or post; leave task in [PR READY]"}
  ]
}
```

Approval 2 - Zulip approval (only if zulip-response.md exists):
```json
{
  "question": "Send zulip-response.md to stream '{stream_name}', topic '{topic}'?",
  "header": "Zulip Message",
  "multiSelect": false,
  "options": [
    {"label": "Yes, send now", "description": "Run: zulip-send --stream '{stream_name}' --subject '{topic}'"},
    {"label": "Show message first", "description": "Display the zulip-response.md content before sending"},
    {"label": "Skip Zulip", "description": "Do not send; task will still be marked [COMPLETED]"}
  ]
}
```

### 6. zulip-send CLI Interface

**Location**: `/home/benjamin/.nix-profile/bin/zulip-send` (confirmed present)

**Configuration**: `~/.zuliprc` with `[api]` section containing `email`, `key`, and `site`. Currently has placeholder values:
```
[api]
email=benjamin@logos-labs.ai
key=REPLACE_WITH_ZULIP_API_KEY
site=REPLACE_WITH_ZULIP_SITE_URL
```

**Status**: Not fully configured. The command will fail until real values are populated.

**Detection of unconfigured state**:
```bash
if grep -q "REPLACE_WITH" ~/.zuliprc 2>/dev/null; then
  echo "Warning: ~/.zuliprc contains placeholder values. Zulip send will fail."
  echo "Configure ~/.zuliprc with your Zulip API credentials before using this feature."
fi
```

**Command syntax** (confirmed from help):
```bash
# Stream message with body from file
cat "$zulip_response_path" | zulip-send --stream "$stream_name" --subject "$topic"

# Or with -m flag (message text inline):
zulip-send --stream "$stream_name" --subject "$topic" -m "$(cat $zulip_response_path)"
```

Note: The pr-review-implementation-agent writes a header comment `<!-- Send: zulip-send --stream="{stream_name}" --subject="{topic}" -->` in zulip-response.md. The /pr command can either parse this comment or read stream/subject from state.json sources[].

**Recommended**: Read from state.json sources since it's authoritative and already parsed:
```bash
zulip_stream=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "zulip_thread") | .parsed.stream_name' \
  "$CSLIB_STATE" 2>/dev/null)
zulip_topic=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "zulip_thread") | .parsed.topic' \
  "$CSLIB_STATE" 2>/dev/null)
```

### 7. gh pr comment Interface

**Command**: `gh pr comment {pr_number} --body-file {path} --repo {owner}/{repo}`

```bash
pr_number=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "github_pr") | .parsed.pr_number' \
  "$CSLIB_STATE" 2>/dev/null)
pr_owner=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "github_pr") | .parsed.owner' \
  "$CSLIB_STATE" 2>/dev/null)
pr_repo=$(jq -r --argjson num "$input_value" \
  '.active_projects[] | select(.project_number == $num) | .sources[] | select(.type == "github_pr") | .parsed.repo' \
  "$CSLIB_STATE" 2>/dev/null)

gh pr comment "$pr_number" \
  --repo "${pr_owner}/${pr_repo}" \
  --body-file "$pr_response_path"
```

### 8. Task Status Transition to [COMPLETED]

The cslib `update-task-status.sh` supports the `pr_ready` postflight transition:
```
postflight:pr_ready -> state="completed", TODO="COMPLETED"
```

Usage:
```bash
bash "$CSLIB_DIR/.claude/scripts/update-task-status.sh" postflight "$input_value" pr_ready "$session_id"
bash "$CSLIB_DIR/.claude/scripts/generate-todo.sh"
```

After completion, commit the state changes:
```bash
cd "$CSLIB_DIR"
git add specs/state.json specs/TODO.md
git commit -m "task ${input_value}: complete pr review response"
```

---

## Decisions

1. **Insert as STEP 0.5**: Place the new handler between STEP 0 and STEP 1 for clean structural separation. STEP 0 handles `--review` flag (task creation), STEP 0.5 handles PR READY review tasks (response posting), STEP 1-11 handles normal PR submission.

2. **Detect via sources + status**: Use `sources_count > 0 AND status == "pr_ready"` as the detection condition. This correctly distinguishes review tasks from PR submission tasks (which also use pr_ready but have no sources).

3. **Two separate AskUserQuestion calls**: One for push + GitHub comment approval, one for Zulip approval. These are different actions with different risk profiles.

4. **Read stream/subject from state.json**: More reliable than parsing the `<!-- Send: ... -->` comment in zulip-response.md since state.json is authoritative.

5. **Warn about unconfigured zuliprc**: Check for `REPLACE_WITH` in `~/.zuliprc` before attempting to send. Offer to skip Zulip gracefully.

6. **Git push strategy**: Check for uncommitted changes first, commit if needed, then check for unpushed commits and push HEAD. Do not squash. Use `git push origin HEAD` (not force-push).

7. **Post pr-response.md as gh pr comment**: Use `--body-file` flag with the path to pr-response.md. The PR number comes from `state.json sources[].parsed.pr_number`.

8. **Use `postflight pr_ready` for status transition**: This transitions the task to [COMPLETED] via cslib's update-task-status.sh.

---

## Proposed STEP 0.5 Structure

```
### STEP 0.5: Check for PR READY Review Task

EXECUTE NOW: Check whether $ARGUMENTS is a pure integer AND the task has sources and is in pr_ready status.

If conditions met, run STEP 0.5.1 through STEP 0.5.7 and STOP.
If not, skip and CONTINUE to STEP 1.

#### STEP 0.5.1: Resolve Task Context

Define CSLIB_DIR, CSLIB_STATE. Read task_name, task_status, sources_count from state.json.
Compute task_dir, pr_response_path, zulip_response_path.

#### STEP 0.5.2: Show Summary

Display what will happen:
- Changed files (git status in cslib)
- pr-response.md path (and first 20 lines)
- PR number and GitHub URL
- zulip-response.md existence and stream/topic

#### STEP 0.5.3: AskUserQuestion — Push and GitHub Comment Approval

Ask user to approve:
- Commit + push uncommitted changes (if any)
- Post pr-response.md as GitHub PR comment

Options: Yes / Preview first / Cancel

#### STEP 0.5.4: Execute Push

If uncommitted changes: git add -A, git commit
If unpushed commits: git push origin HEAD

Post GitHub comment: gh pr comment {pr_number} --body-file {pr_response_path}

#### STEP 0.5.5: AskUserQuestion — Zulip Approval (if zulip-response.md exists)

Check if ~/.zuliprc is configured (not placeholder).
If not configured: display warning and skip.
If configured: ask user to approve sending Zulip message.

Options: Yes / Show first / Skip

#### STEP 0.5.6: Execute Zulip Send (if approved)

cat {zulip_response_path} | zulip-send --stream "{stream_name}" --subject "{topic}"

#### STEP 0.5.7: Transition Task to [COMPLETED]

Call update-task-status.sh postflight pr_ready
Regenerate TODO.md
Git commit state changes
Display completion summary
STOP
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| zuliprc not configured | Check for REPLACE_WITH before attempting send; offer to skip Zulip |
| No github_pr source in task | Check sources_count > 0 and also check if github_pr type exists before posting comment |
| No zulip_thread source but zulip-response.md exists | Check source type before extracting stream/topic |
| Uncommitted changes in cslib from unrelated work | Show `git status` before committing, require explicit approval |
| pr-response.md not found | Check file existence before posting; fail gracefully with guidance |
| update-task-status.sh may not support pr_ready | Confirmed from cslib .claude/scripts/update-task-status.sh: it does support pr_ready |
| jq `!=` escaping (Issue #1132) | Use `select(.project_number == $num)` pattern (already established in codebase) |

---

## Context Extension Recommendations

- **Topic**: PR review response workflow in /pr command
- **Gap**: No existing context documents the PR READY review task detection pattern or the two-step approval flow
- **Recommendation**: Update .claude/extensions/cslib/context/ with a brief note about the STEP 0.5 pattern once implemented

---

## Appendix

### Search Queries Used

- Read `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` (full file, 1,383 lines)
- Read `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md`
- Read `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/pr-review-implementation-agent.md`
- Read `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md`
- `which zulip-send && zulip-send --help`
- `cat ~/.zuliprc`
- `gh pr comment --help`
- `jq '.active_projects[] | select(.project_number == 197)' /home/benjamin/Projects/cslib/specs/state.json`
- `grep -n "pr_ready" /home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh`
- `git cherry -v origin/HEAD` (in cslib)

### Key File Paths

- Command to modify: `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md`
- zulip-send binary: `/home/benjamin/.nix-profile/bin/zulip-send`
- zulip configuration: `/home/benjamin/.zuliprc`
- cslib state: `/home/benjamin/Projects/cslib/specs/state.json`
- cslib update-task-status: `/home/benjamin/Projects/cslib/.claude/scripts/update-task-status.sh`

### zulip-send Exact Flags

```
-s, --stream STREAM    Stream name (NOT "general" with leading number, just "general")
-S, --subject SUBJECT  Subject (topic) of the message
-m, --message MESSAGE  Message body text (alternative to piping)
```

Stream name note: state.json stores `stream_name` from the URL segment `123-general` as just `general` (numeric prefix stripped during STEP 0.1 parsing in pr.md).
