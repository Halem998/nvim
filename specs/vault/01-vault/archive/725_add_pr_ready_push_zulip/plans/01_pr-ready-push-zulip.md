# Implementation Plan: Task #725

- **Task**: 725 - Extend /pr to handle PR READY tasks from the --review workflow
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 724 (completed)
- **Research Inputs**: specs/725_add_pr_ready_push_zulip/reports/01_pr-ready-push-zulip.md
- **Artifacts**: plans/01_pr-ready-push-zulip.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task adds a new STEP 0.5 early-exit path to the existing `/pr` command at `.claude/extensions/cslib/commands/pr.md`. When `/pr N` is invoked on a task that has `status: "pr_ready"` and a non-empty `sources` array in cslib's state.json, the command will: (1) commit and push uncommitted changes, (2) post `pr-response.md` as a GitHub PR comment via `gh pr comment`, (3) optionally send `zulip-response.md` via `zulip-send` CLI, and (4) transition the task to [COMPLETED]. Each action has an explicit AskUserQuestion approval gate. This is a single-file change (pr.md) with no new files created.

### Research Integration

The research report (01_pr-ready-push-zulip.md) confirmed:
- STEP 0.5 insertion point between STEP 0 (--review early exit) and STEP 1 (normal PR flow)
- Detection: pure integer argument + `status == "pr_ready"` + `sources_count > 0` in cslib state.json
- `zulip-send` is at `/home/benjamin/.nix-profile/bin/zulip-send` with `-s/--stream` and `-S/--subject` flags; `~/.zuliprc` has placeholder values requiring detection
- Stream/subject from `sources[].parsed.stream_name` and `sources[].parsed.topic` in state.json
- `gh pr comment {pr_number} --repo {owner}/{repo} --body-file {path}` for GitHub comment
- `postflight pr_ready` in cslib's `update-task-status.sh` transitions to [COMPLETED]

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task.

## Goals & Non-Goals

**Goals**:
- Add STEP 0.5 to pr.md that detects and handles PR READY review tasks
- Implement two separate AskUserQuestion approval gates (push+comment, then Zulip)
- Commit and push code changes to the PR branch without squashing
- Post pr-response.md as a GitHub PR comment
- Optionally send zulip-response.md via zulip-send CLI with unconfigured-zuliprc detection
- Transition task to [COMPLETED] via update-task-status.sh postflight

**Non-Goals**:
- Modifying the existing STEP 0 (--review) or STEP 1-11 flow
- Creating new skills, agents, or scripts
- Handling non-review PR READY tasks (those without sources array)
- Auto-configuring ~/.zuliprc

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| STEP 0.5 detection collides with normal task-mode flow | H | L | Detection requires both `pr_ready` status AND non-empty `sources` array; normal PR tasks lack sources |
| zuliprc has placeholder values | M | H | Explicit grep check for `REPLACE_WITH` in ~/.zuliprc before offering Zulip option |
| pr-response.md missing for PR READY task | M | L | File existence check before posting; display error and skip gracefully |
| Large insertion disrupts pr.md readability | L | M | Follow existing STEP structure and formatting conventions exactly |
| jq Issue #1132 escaping | M | L | Use established `select(.project_number == $num)` pattern, avoid `!=` operator |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: STEP 0.5 Detection and Context Resolution [COMPLETED]

**Goal**: Insert the STEP 0.5 header and detection logic (STEP 0.5, 0.5.1, 0.5.2) into pr.md between STEP 0 and STEP 1.

**Tasks**:
- [x] Insert STEP 0.5 header after STEP 0's `**STOP**` line (after line ~337) and before STEP 1 (line ~341) *(completed)*
- [x] Write detection logic: check if `$ARGUMENTS` is a pure integer, then query cslib state.json for `status == "pr_ready"` AND `sources_count > 0` *(completed)*
- [x] If conditions not met, skip to STEP 1 (continue normal flow) *(completed)*
- [x] Write STEP 0.5.1 (Resolve Task Context): define `CSLIB_DIR`, `CSLIB_STATE`, read task metadata, compute `task_dir`, `pr_response_path`, `zulip_response_path` *(completed)*
- [x] Extract PR source data: `pr_number`, `pr_owner`, `pr_repo` from `sources[].parsed` where `type == "github_pr"` *(completed)*
- [x] Extract Zulip source data: `stream_name`, `topic` from `sources[].parsed` where `type == "zulip_thread"` (may not exist) *(completed)*
- [x] Write STEP 0.5.2 (Show Summary): display git status in cslib, pr-response.md preview, PR URL, Zulip availability *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Insert ~80-100 lines for STEP 0.5, 0.5.1, 0.5.2 between the STEP 0 block and STEP 1

**Verification**:
- STEP 0.5 header exists between STEP 0's STOP and STEP 1
- Detection logic correctly gates on pure integer + pr_ready + sources > 0
- Context resolution reads all necessary fields from cslib state.json
- Summary display includes git status, PR info, and Zulip availability

---

### Phase 2: Approval Gates and Push/Comment Execution [COMPLETED]

**Goal**: Add STEP 0.5.3 (push approval) and STEP 0.5.4 (execute push + GitHub comment) to pr.md.

**Tasks**:
- [x] Write STEP 0.5.3 (AskUserQuestion - Push and GitHub Comment Approval): present options (Yes/Preview first/Cancel) showing what will happen *(completed)*
- [x] Handle "Preview first" option: display full pr-response.md content, then re-ask *(completed)*
- [x] Handle "Cancel" option: display message and STOP without changing task status *(completed)*
- [x] Write STEP 0.5.4 (Execute Push): check for uncommitted changes with `git status --porcelain` in cslib dir *(completed)*
- [x] If uncommitted changes: `git add -A && git commit -m "task {N}: apply review feedback"` in cslib *(completed)*
- [x] Check for unpushed commits with `git log --oneline origin/HEAD..HEAD` in cslib *(completed)*
- [x] If unpushed commits: `git push origin HEAD` (no force, no squash) *(completed)*
- [x] Post GitHub comment: `gh pr comment "$pr_number" --repo "${pr_owner}/${pr_repo}" --body-file "$pr_response_path"` *(completed)*
- [x] Display success confirmation for push and comment *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Append ~80-100 lines for STEP 0.5.3 and 0.5.4 after Phase 1's insertion

**Verification**:
- AskUserQuestion has three options matching research spec
- "Cancel" path STOPs without modifying any state
- Push logic handles both uncommitted-changes and unpushed-commits cases
- `gh pr comment` uses `--body-file` with correct repo format

---

### Phase 3: Zulip Send and Task Completion [COMPLETED]

**Goal**: Add STEP 0.5.5 (Zulip approval), STEP 0.5.6 (Zulip send), and STEP 0.5.7 (task completion) to pr.md.

**Tasks**:
- [x] Write STEP 0.5.5 (AskUserQuestion - Zulip Approval): only if zulip-response.md exists *(completed)*
- [x] Check ~/.zuliprc for `REPLACE_WITH` placeholder values; if found, warn and offer only "Skip Zulip" option *(completed)*
- [x] If configured: present options (Yes/Show message first/Skip Zulip) *(completed)*
- [x] Handle "Show message first": display zulip-response.md content, then re-ask *(completed)*
- [x] If no zulip-response.md exists: skip STEP 0.5.5 and 0.5.6 entirely *(completed)*
- [x] Write STEP 0.5.6 (Execute Zulip Send): `cat "$zulip_response_path" | zulip-send --stream "$stream_name" --subject "$topic"` *(completed)*
- [x] Display Zulip send success or skip confirmation *(completed)*
- [x] Write STEP 0.5.7 (Transition Task to COMPLETED): *(completed)*
  - [x] Call `bash "$CSLIB_DIR/.claude/scripts/update-task-status.sh" postflight "$input_value" pr_ready "$session_id"` *(completed)*
  - [x] Regenerate TODO.md: `bash "$CSLIB_DIR/.claude/scripts/generate-todo.sh"` *(completed)*
  - [x] Git commit state changes: `cd "$CSLIB_DIR" && git add specs/state.json specs/TODO.md && git commit -m "task ${input_value}: complete pr review response"` *(completed)*
- [x] Display final completion summary with all actions taken *(completed)*
- [x] End with **STOP** to prevent falling through to STEP 1 *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Append ~80-100 lines for STEP 0.5.5, 0.5.6, 0.5.7 after Phase 2's insertion

**Verification**:
- Zulip approval only shown when zulip-response.md exists
- Unconfigured zuliprc detected and warned about
- update-task-status.sh called with correct arguments (postflight, task number, pr_ready, session_id)
- Final STOP prevents fallthrough to STEP 1
- Completion summary shows all actions performed (push, GitHub comment, Zulip send/skip)

## Testing & Validation

- [x] Read the modified pr.md and verify STEP 0.5 is structurally between STEP 0 and STEP 1 *(verified: STEP 0.5 at line 341, STEP 1 at line 735)*
- [x] Verify detection logic: pure integer check, pr_ready status check, sources count check *(verified: grep -qE '^[0-9]+$', jq status/sources checks)*
- [x] Verify jq commands use safe patterns (no `!=` operator) *(verified: all jq uses select(.type == "...") pattern)*
- [x] Verify two separate AskUserQuestion calls exist with correct option structures *(verified: lines 506, 616/635)*
- [x] Verify zuliprc placeholder detection logic uses `grep -q "REPLACE_WITH" ~/.zuliprc` *(verified: line 600)*
- [x] Verify STOP is placed at end of STEP 0.5.7 to prevent fallthrough *(verified: line 731)*
- [x] Verify all bash commands use absolute paths for CSLIB_DIR and tool locations *(verified: CSLIB_DIR, ZULIP_SEND absolute paths)*
- [x] Verify the session_id generation matches the pattern used in STEP 2 *(verified: same pattern sess_$(date +%s)_$(head -c8 /dev/urandom | xxd -p))*

## Artifacts & Outputs

- `.claude/extensions/cslib/commands/pr.md` - Modified with ~250-300 new lines for STEP 0.5 (0.5.1 through 0.5.7)
- specs/725_add_pr_ready_push_zulip/plans/01_pr-ready-push-zulip.md (this plan)
- specs/725_add_pr_ready_push_zulip/summaries/01_pr-ready-push-zulip-summary.md (after implementation)

## Rollback/Contingency

This is a single-file modification to `.claude/extensions/cslib/commands/pr.md`. To revert:
- `git checkout -- .claude/extensions/cslib/commands/pr.md` restores the pre-modification state
- No database migrations, schema changes, or infrastructure modifications are involved
- The existing STEP 0 and STEP 1-11 flows are not modified, only a new STEP 0.5 is inserted between them
