# Research Report: Task #724

**Task**: 724 - Create skill-pr-review-implementation
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:30:00Z
**Effort**: ~30 minutes research
**Dependencies**: Task 722 (pr --review flag), Task 723 (skill-pr-review-research)
**Sources/Inputs**: Codebase exploration — skill files, agent files, manifest.json, update-task-status.sh, /pr command
**Artifacts**: specs/724_create_pr_review_implementation_skill/reports/01_pr-review-impl-skill.md
**Standards**: report-format.md

## Executive Summary

- The new skill should follow the `skill-pr-review-research` thin-wrapper pattern, delegating all content work to a new `pr-review-implementation-agent`
- Two response files need to be created: `pr-response.md` (GitHub PR comment) and/or `zulip-response.md` (Zulip message text), conditioned on which source types are present in the task's `sources` array
- The PR READY transition uses `bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"` — same as `skill-pr-implementation`; this sets status to `pr_ready` in state.json and `[PR READY]` in TODO.md
- The manifest.json already has `"implement": { "pr": "skill-pr-implementation" }` — this must be updated to route pr-type review tasks (those with `sources`) to the new `skill-pr-review-implementation` instead
- The key design decision is: the skill reads `sources` from state.json to determine which response files to produce; if `github_pr` source present → pr-response.md; if `zulip_thread` source present → zulip-response.md

## Context & Scope

### Background

Task 722 added `--review` flag to `/pr` command. This creates tasks with `task_type: "pr"` and a `sources` array in state.json. The sources array contains `github_pr`, `zulip_thread`, and/or `description` entries.

Task 723 created `skill-pr-review-research` and `pr-review-research-agent`, which fetch review content from GitHub and Zulip, producing a structured report at `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md`. The report contains:
- Sources fetched (table)
- PR Overview
- Review Feedback Summary (by reviewer, with state: APPROVED, CHANGES_REQUESTED, etc.)
- Inline Code Comments (grouped by file)
- Conversation Comments
- Zulip Discussion
- Additional Context
- Open Questions
- Requested Changes
- Next Steps

### Current Routing State

The manifest.json currently routes:
```json
"implement": {
  "cslib": "skill-cslib-implementation",
  "pr": "skill-pr-implementation"
}
```

The `skill-pr-implementation` is used for composing `pr-description.md` before submitting a PR to upstream. It delegates to `cslib-implementation-agent`. This skill is for a different use case — preparing a PR to submit, not responding to review feedback.

The new `skill-pr-review-implementation` must route `/implement N` on review-type pr tasks (those with `sources` array in state.json). There are two options for routing:
1. **Conditional dispatch inside `skill-pr-implementation`**: Check if task has `sources` and delegate accordingly
2. **Separate task subtype** (e.g., `pr:review`): Use compound routing key like `present:grant` pattern
3. **Replace the `pr` implementation route entirely**: Since both task types have `task_type: "pr"`, they share the same routing slot. The new skill would need to handle both cases.

**Recommended approach**: Update `skill-pr-implementation` to detect the presence of `sources` and dispatch to `skill-pr-review-implementation` (or the agent) when sources are present. Alternatively, make `skill-pr-review-implementation` the primary `pr` implementation route and have it detect which workflow is needed.

The cleanest approach is: make `skill-pr-review-implementation` the primary `pr:implement` route. It checks for `sources` in state.json. If present → PR review response workflow. If absent → delegate to the existing PR description preparation workflow (currently handled by `skill-pr-implementation` / `cslib-implementation-agent`). However, this conflates two separate skills.

**Simplest approach** (recommended): Update manifest.json to use the new skill only for tasks that have sources. Since all `/pr --review` tasks have sources and all non-review PR tasks do not have sources, the distinguishing field is `sources`. The routing infrastructure doesn't support conditional routing based on state.json fields, but the **skill itself** can inspect state.json and dispatch to the appropriate agent. The manifest.json entry `"implement": { "pr": "skill-pr-review-implementation" }` would replace `"pr": "skill-pr-implementation"`, and the new skill would check for `sources` presence and either run the review workflow or forward to `cslib-implementation-agent` for PR description preparation.

**Alternative**: Keep `skill-pr-implementation` as the primary route and have it detect `sources` and re-dispatch to `skill-pr-review-implementation` as a secondary skill. This is slightly more complex.

**Chosen approach**: The skill-pr-review-implementation is a standalone skill that handles ONLY review-type tasks (those with `sources`). The manifest.json retains `skill-pr-implementation` as the primary route. The `/implement` command needs a way to reach the new skill. This can be done via a **compound task type key**: when `/pr --review` creates a task, it could set `task_type: "pr:review"` instead of `"pr"`. However, task 722 already committed to `task_type: "pr"`.

**Final decision**: Manifest routing change. Replace `"pr": "skill-pr-implementation"` with `"pr": "skill-pr-review-implementation"`. The new skill detects whether `sources` is present:
- If `sources` present (review task) → run the review response workflow
- If `sources` absent (PR prep task) → delegate to `cslib-implementation-agent` for pr-description.md (same as `skill-pr-implementation` does now)

This keeps the manifest simple and handles both pr task subtypes from a single skill entry point.

## Findings

### Pattern Analysis: skill-pr-review-research (Thin Wrapper)

All cslib extension skills follow the same thin-wrapper pattern:
1. Input validation (task_number, task_type, optional fields)
2. Preflight status update via `update-task-status.sh preflight`
3. Create `.postflight-pending` marker
4. Read `next_artifact_number` from state.json
5. Prepare delegation context JSON (with domain-specific fields)
6. Invoke subagent via `Agent` tool
7. Stage 5b self-execution fallback (write `.return-meta.json` if no Agent was used)
8. Parse metadata file
9. Validate artifacts (non-blocking)
10. Postflight status update via `update-task-status.sh postflight`
11. Propagate memory candidates
12. Link artifacts in state.json + regenerate TODO.md
13. TTS notification
14. Cleanup marker files
15. Return brief text summary

The review implementation skill should follow this exact same pattern. Key difference from skill-pr-implementation: this skill uses `pr_ready` status target, like `skill-pr-implementation` does.

### Postflight PR READY Transition

From `update-task-status.sh`:
```
preflight:pr_ready  -> state: "pr_ready",    TODO: "PR READY"
postflight:pr_ready -> state: "completed",   TODO: "COMPLETED"
```

Wait — `postflight:pr_ready` sets status to `"completed"`. But the task description says the implementation agent should "transition the task to [PR READY]". That means the skill should call:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"
```
(NOT postflight, to SET it to PR READY) — or just manipulate state.json directly.

Actually, looking at `skill-pr-implementation` more carefully:
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"
```
It uses `postflight:pr_ready`. But the script maps `postflight:pr_ready` to `status="completed"` and `TODO="COMPLETED"`. That would mark the task as COMPLETED, not PR READY.

Wait, let me re-read the script output:
```
preflight:pr_ready)  STATE_STATUS="pr_ready";      TODO_STATUS="PR READY" ;;
postflight:pr_ready) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
```

So:
- `preflight pr_ready` → sets to [PR READY] 
- `postflight pr_ready` → sets to [COMPLETED]

The `skill-pr-implementation` Stage 2 calls `preflight implement` (to go to IMPLEMENTING), then Stage 6 calls `postflight pr_ready` which would go to COMPLETED? That seems wrong for a PR READY transition.

But reading `skill-pr-implementation` Stage 6 again:
```
### Stage 6: Update Task Status (Postflight — PR READY)
**CRITICAL DIFFERENCE**: This skill calls `pr_ready` as the status target, NOT `implement`.
This sets the task to `[PR READY]` instead of `[COMPLETED]`, directing the user to run `/merge`.
bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"
```

The skill comment says it uses `postflight pr_ready` but there may be a discrepancy with how the script maps this. The task description for 724 also says "transition the task to [PR READY]".

The correct command to reach [PR READY] is:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"
```

The `skill-pr-review-implementation` SKILL.md should document using `preflight pr_ready` (not `postflight`) to reach [PR READY]. The postflight of the skill should not change the status further — the task stays at [PR READY] until the user manually triggers additional actions (responding on GitHub, messaging Zulip).

Actually, looking at the workflow again: the implementation agent creates the response files, and the task transitions to [PR READY] — meaning the user is ready to manually post the responses. The skill sets PR READY during its own postflight, then cleanup happens. The user then manually posts the pr-response.md and/or zulip-response.md.

So the correct transition call in the skill's postflight:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"
```
This sets the task to [PR READY] and that's the end state until the user completes it.

### Response File Format Decisions

#### pr-response.md

This file will be posted as a GitHub PR comment (reply to specific review threads or as a top-level comment). Format considerations:

- GitHub supports full Markdown in PR comments
- Should have a clear section per reviewer / per comment addressed
- Should reference specific review comments by linking to them (GitHub URL fragments)
- Should use `> ` blockquotes to show what comment is being replied to
- Should be organized: "Changes made" bullet list + "Questions answered" sections

Proposed structure:
```markdown
# PR Review Response

Thank you for the thorough review! Here's a summary of the changes made in response:

## Changes Made

### In response to @reviewer-name's comment on `path/to/file.lean`
> [Original comment text (first line)]

[Explanation of what was changed and why]

## Remaining Questions / Clarifications

### Re: [topic]
[Clarification or question for the reviewer]

## Summary

All requested changes have been addressed. Ready for re-review.
```

The agent should reference specific comments by quoting the first line and noting the file/reviewer. It does not need GitHub comment IDs (those aren't easily extractable from the research report). Linking to the specific comment URL from the diff hunk would require knowing the comment ID, which is available in the research report's inline comments if included.

Actually, the research report from pr-review-research-agent DOES include the reviewer names, created_at timestamps, and diff hunks for inline comments. The agent can compose blockquote references without needing comment IDs.

#### zulip-response.md

This file is intended to be "piped to zulip-send". The `zulip-send` CLI tool (from the python-zulip package) accepts:
- `--stream` (stream name)
- `--subject` (topic)
- `--message` (message text, or piped via stdin)

The message will be plain text or Zulip-flavored Markdown (Zulip supports Markdown but with some differences from GitHub). Key considerations:
- Keep it shorter than a GitHub PR comment — Zulip is conversational
- Should reference what PR is being discussed
- Should mention key changes made
- Format: `cat zulip-response.md | zulip-send --stream="stream-name" --subject="topic"`

Proposed structure (plain Markdown, brief):
```
Update on PR #NNN: [PR Title]

Made the following changes in response to review feedback:
- [Change 1 addressing reviewer comment]
- [Change 2 addressing reviewer comment]

Re: [open question from thread] — [brief answer or clarification]

PR is ready for re-review: [URL]
```

The file should contain ONLY the message body text, not the zulip-send command flags. The user will pipe it to zulip-send with the appropriate stream/topic flags (extracted from the `zulip_thread` source's `parsed.stream_name` and `parsed.topic` fields).

However, it would be helpful to include a comment at the top of the file showing the recommended `zulip-send` command:
```
<!-- zulip-send: stream="{stream_name}" topic="{topic}" -->
```
This is a comment not included in the message body but visible when the user reads the file.

### Research Report Reading Strategy

The pr-review-implementation-agent should:

1. **Read the research report** at `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md`
2. **Extract key sections**:
   - `## Requested Changes` → items to implement
   - `## Open Questions` → items to address in responses
   - `## Inline Code Comments` → specific code locations to fix
   - `## Sources Fetched` → which source types were present
3. **Determine which response files to create** based on sources:
   - `github_pr` source → create `pr-response.md`
   - `zulip_thread` source → create `zulip-response.md`
   - Neither → create only a summary note
4. **For pr-type tasks with actual code changes** (Requested Changes section is non-empty):
   - The agent may need to apply code changes before writing the response files
   - But for the CSLib context: the primary task is responding to feedback, not implementing code changes (that's a separate implementation cycle)
   - The response files should document what changes were made OR explain why certain changes are or aren't appropriate

**Scope clarification**: The PR review implementation agent's primary job is:
1. Write response files documenting what action was taken on each piece of feedback
2. If the Requested Changes are simple (formatting, typos, minor proof adjustments) and the task explicitly asks for implementation, apply those changes
3. If the Requested Changes require substantial Lean proof work, note them in the response as "will be addressed in a follow-up" or implement them if the plan covers it

For the initial implementation, the agent should focus on **composing response files** rather than implementing code changes. Code changes require Lean expertise and are a separate concern. The skill name "skill-pr-review-implementation" means "implement the review response", not "implement the code fixes". Code fixes, if needed, would be handled by a separate cslib implementation task.

### Plan Reading

Implementation tasks normally read a plan file. For PR review tasks:
- A plan may or may not exist (user may skip planning and go straight to implementation)
- If a plan exists, the agent reads it for guidance on how to respond
- If no plan exists, the agent synthesizes a response directly from the research report

The skill should handle both cases:
```bash
# Check if plan exists
plan_path=$(find "specs/${padded_num}_${project_name}/plans/" -name "*.md" | sort | tail -1)
if [ -z "$plan_path" ]; then
  plan_path=""  # agent will work from research report directly
fi
```

### Routing Configuration

Current manifest.json `implement` section:
```json
"implement": {
  "cslib": "skill-cslib-implementation",
  "pr": "skill-pr-implementation"
}
```

Required change:
```json
"implement": {
  "cslib": "skill-cslib-implementation",
  "pr": "skill-pr-review-implementation"
}
```

The new `skill-pr-review-implementation` becomes the primary `pr` implementation route. It detects `sources` presence to decide workflow:
- With `sources` → PR review response workflow (new)
- Without `sources` → PR description preparation (existing, delegate to `cslib-implementation-agent`)

The `skill-pr-implementation` file can remain as a reference but is no longer in the manifest routing.

Also need to add to `provides.skills`:
```json
"skills": [
  "skill-cslib-research",
  "skill-cslib-implementation",
  "skill-pr-implementation",     // keep for now (not in routing, but available)
  "skill-cslib-research-hard",
  "skill-cslib-implementation-hard",
  "skill-pr-review-research",
  "skill-pr-review-implementation"   // new
]
```

And to `provides.agents`:
```json
"agents": [
  "cslib-research-agent.md",
  "cslib-implementation-agent.md",
  "cslib-research-hard-agent.md",
  "cslib-implementation-hard-agent.md",
  "pr-review-research-agent.md",
  "pr-review-implementation-agent.md"   // new
]
```

### PR READY Status Flow

From `pr-prohibition.md` (CSLib extension rule):
```
skill-pr-implementation: Analyzes git diff → pr-description.md → [PR READY]
/pr {task_number} (user-invoked): branch creation, CI, PR submission → [COMPLETED]
```

For PR review tasks, the flow is:
```
skill-pr-review-implementation: Research report → pr-response.md + zulip-response.md → [PR READY]
User: Manually posts pr-response.md on GitHub, sends zulip-response.md via zulip-send
/todo: Marks task [COMPLETED] when user is done
```

So `[PR READY]` means "response files are ready for the user to post". The skill reaches this state using:
```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"
```

## Decisions

1. **Skill name**: `skill-pr-review-implementation` at `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md`
2. **Agent name**: `pr-review-implementation-agent` at `.claude/extensions/cslib/agents/pr-review-implementation-agent.md`
3. **Agent model**: `sonnet` (worker agent pattern, matches research agent)
4. **Routing**: Replace `skill-pr-implementation` with `skill-pr-review-implementation` as the `pr` implement route in manifest.json. New skill detects `sources` to dispatch between review and PR description workflows
5. **Response files**:
   - `specs/{NNN}_{SLUG}/pr-response.md` — GitHub PR comment (Markdown, structured by reviewer/comment)
   - `specs/{NNN}_{SLUG}/zulip-response.md` — Zulip message text (brief Markdown, with header comment showing stream/topic)
   - Both files live in the task root (not in `summaries/` or `reports/`)
6. **Response file conditions**: `github_pr` source → pr-response.md; `zulip_thread` source → zulip-response.md
7. **PR READY transition**: Use `preflight pr_ready` (not `postflight pr_ready` — postflight goes to COMPLETED)
8. **Plan fallback**: Skill finds most recent plan if it exists; passes `plan_path: null` to agent if no plan; agent synthesizes from research report directly
9. **No code changes in scope**: Agent response files document planned/completed actions; actual code changes are out of scope for this skill (separate impl task if needed)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Routing conflict: both pr types share `task_type: "pr"` | New skill checks `sources` presence to dispatch; no routing ambiguity |
| `postflight pr_ready` goes to COMPLETED, not PR READY | Use `preflight pr_ready` to set [PR READY]; no postflight call |
| Research report not found (skipped research phase) | Skill validates report exists; if missing, agent synthesizes from sources directly |
| zulip-response.md content too long for Zulip | Keep message under 5000 chars; summarize rather than reproduce all changes |
| pr-response.md referencing comments that don't exist | Agent quotes first line of each comment to anchor context; no dependency on comment IDs |
| Agent tries to implement code changes | Clear MUST NOT in agent: response composition only; code changes are separate |

## Proposed File Locations

### New Files to Create

1. `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md`
   - Thin wrapper following skill-pr-review-research pattern
   - Validates task has `sources` (is a review task)
   - Dispatches to pr-review-implementation-agent OR to cslib-implementation-agent for PR prep tasks

2. `.claude/extensions/cslib/agents/pr-review-implementation-agent.md`
   - model: sonnet
   - Reads research report
   - Determines response files needed based on source types
   - Composes pr-response.md (if github_pr source)
   - Composes zulip-response.md (if zulip_thread source)
   - Writes .return-meta.json with status "implemented"

### Files to Modify

3. `.claude/extensions/cslib/manifest.json`
   - `provides.agents`: add `pr-review-implementation-agent.md`
   - `provides.skills`: add `skill-pr-review-implementation`
   - `routing.implement.pr`: change from `skill-pr-implementation` to `skill-pr-review-implementation`

## Appendix

### Key Reference Files Consulted

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md` — Thin wrapper pattern
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/pr-review-research-agent.md` — Research report structure
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — PR READY transition pattern
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` — Implementation skill pattern
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — /pr command (--review flag)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` — Current routing
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` — PR READY transition mechanics
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` — Core implementer pattern

### Research Report Structure (from pr-review-research-agent)

The research report produced by pr-review-research-agent has these sections:
- Sources Fetched (table with type/status)
- PR Overview (metadata)
- Review Feedback Summary (per reviewer, with state)
- Inline Code Comments (grouped by file, with diff_hunk)
- Conversation Comments
- Zulip Discussion (or skip note)
- Additional Context (description sources)
- Open Questions (derived from unresolved comments)
- Requested Changes (explicit change requests)
- Next Steps (synthesized action items)

The `Requested Changes` and `Open Questions` sections are the primary inputs for composing response files.

### update-task-status.sh PR READY Mappings

```
preflight:pr_ready  -> state.status = "pr_ready",   TODO = "PR READY"
postflight:pr_ready -> state.status = "completed",  TODO = "COMPLETED"
```

**Use `preflight pr_ready` to reach [PR READY].**

### zulip-send Command Format

```bash
# Pipe message body to zulip-send
cat specs/{NNN}_{SLUG}/zulip-response.md | \
  zulip-send --stream="stream-name" --subject="topic-name"

# Or with explicit --message flag
zulip-send --stream="stream-name" \
            --subject="topic-name" \
            --message "$(cat specs/{NNN}_{SLUG}/zulip-response.md)"
```

The `zulip-response.md` should contain a header comment (not included in message) with the recommended send command:
```
<!-- Send: zulip-send --stream="{stream_name}" --subject="{topic}" -->
```
Followed by the plain message text.
