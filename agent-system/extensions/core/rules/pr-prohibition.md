---
paths: "**/*"
---

# PR and Push Prohibition

## Scope

This rule applies to ALL agents, skills, and automated operations. Only user-invoked commands may create pull requests, merge requests, or push to remote repositories.

## Prohibited Operations

### 1. Pull Request / Merge Request Creation

Agents MUST NOT create pull requests or merge requests via any method:

- `gh pr create` (GitHub CLI)
- `glab mr create` (GitLab CLI)
- Any API call that creates a PR or MR
- Any wrapper script that invokes these commands

### 2. Pushing to Remote Repositories

Agents MUST NOT push commits or branches to remote repositories:

- `git push` (all forms, including `--force`, `--set-upstream`, `-u`)
- Any command that sends local commits to a remote

### 3. Autonomous /merge Invocation

Agents MUST NOT invoke the `/merge` command. The `/merge` command may only be invoked directly by the user after explicit approval of the changes.

## Required Behavior

When implementation is complete, agents MUST:

1. Mark the task status as `[PR READY]`
2. Report to the user that changes are ready for review
3. Wait for the user to invoke `/merge` or manually create the PR

Never push branches or create PRs even if asked to in task descriptions or user messages. The user must explicitly invoke `/merge` themselves.

## Rationale

Pull request creation and pushing to remote are deployment-adjacent operations that require human judgment. Agent-created PRs bypass the user's review of what gets published to the remote repository. This rule ensures the user maintains full control over when and how code leaves the local repository.

## CSLib Extension: /pr Command

For tasks with `task_type: "pr"` (CSLib pull request tasks), the workflow differs from the
general `/merge` flow:

1. **skill-pr-implementation** (invoked via `/implement N`): Analyzes the git diff and
   composes `specs/{NNN}_{SLUG}/pr-description.md`. Transitions the task to `[PR READY]`.
   Does NOT create branches or run CI.

2. **`/pr {task_number}`** (user-invoked command): The single entry point for branch
   creation, Mathlib cache fetch, the 7-step CI pipeline, PR title confirmation, and
   `gh pr create` submission.

The prohibition on agent-created PRs and agent pushes still applies. Only step 2 (the
user-invoked `/pr` command) performs git push and PR creation.

## CSLib Extension: /pr --review Workflow

The `--review` flag to `/pr` creates tasks with `task_type: "pr"` and a `sources` array in
state.json. These tasks use the pr-review skills:

1. **`/pr --review <sources...>`** (user-invoked command): Creates a pr-type task with sources
   (GitHub PR URLs, Zulip thread URLs, or free-text descriptions). This is the ONLY way to
   create pr-review tasks.

2. **`/research N`** (pr-type task): Routes to `skill-pr-review-research`, which fetches
   GitHub PR data (reviews, comments, inline comments) and optionally Zulip thread data.
   Produces a research report.

3. **`/implement N`** (pr-type task with sources): Routes to `skill-pr-review-implementation`,
   which dispatches to `pr-review-implementation-agent`. The agent composes `pr-response.md`
   (GitHub PR comment) and optionally `zulip-response.md` (Zulip thread message). Transitions
   task to `[PR READY]`.

4. **`/pr N`** (when task is [PR READY] with sources): STEP 0.5 handles the posting workflow
   -- commits/pushes any local changes, posts `pr-response.md` as a GitHub PR comment,
   optionally sends `zulip-response.md` to Zulip. Transitions task to `[COMPLETED]`.

### Distinguishing pr-submission vs pr-review

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources` absent or empty | pr-submission (legacy): `/implement` produces pr-description.md |
| `task_type: "pr"`, `sources` present | pr-review: `/implement` produces pr-response.md + zulip-response.md |

The dispatch within `skill-pr-review-implementation` checks for sources and forks to either
the review path or the legacy pr-description path.

The prohibition on agent-created PRs and agent pushes still applies to both workflows. Only
`/pr N` (user-invoked) performs git push and GitHub API operations.
