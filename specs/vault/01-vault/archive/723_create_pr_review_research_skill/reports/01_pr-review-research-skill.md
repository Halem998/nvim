# Research Report: Task #723

**Task**: 723 - Create skill-pr-review-research
**Started**: 2026-06-15T06:00:00Z
**Completed**: 2026-06-15T06:45:00Z
**Effort**: 2 hours
**Dependencies**: Task 722 (complete — added --review flag to /pr command)
**Sources/Inputs**: Codebase exploration (.claude/skills/, .claude/agents/, .claude/extensions/cslib/), gh api testing, Zulip CLI inspection, command-route-skill.sh analysis
**Artifacts**: specs/723_create_pr_review_research_skill/reports/01_pr-review-research-skill.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The new `skill-pr-review-research` should follow the thin-wrapper pattern established by `skill-cslib-research` and `skill-researcher`, delegating to a new `pr-review-research-agent`.
- GitHub PR data is accessible via three `gh api` endpoints: `/pulls/{num}` (metadata), `/pulls/{num}/reviews` (review summaries), `/issues/{num}/comments` (conversation comments); inline code comments (`/pulls/{num}/comments`) require separate fetch.
- Zulip thread fetching uses the Python `zulip` client available at `/home/benjamin/.nix-profile/bin/`; credentials are stored in `~/.zuliprc` but the `site` field currently has a placeholder (`REPLACE_WITH_ZULIP_SITE_URL`), so the agent must handle the unconfigured case gracefully.
- Routing is already declared in the CSLib manifest: `"pr": "skill-researcher"` for research — this must be changed to `"pr": "skill-pr-review-research"` in `manifest.json`.
- The skill and agent should live inside the CSLib extension alongside `skill-pr-implementation`.

---

## Context & Scope

Task 723 creates the research infrastructure for `pr`-type tasks created by `/pr --review`. These tasks have a `sources` array in `state.json` containing `github_pr`, `zulip_thread`, and/or `description` entries. The research skill must fetch live content from those URLs, synthesize it into a structured report, and support re-research as new comments arrive (multiple rounds).

This is a **meta** task (agent system infrastructure), so the implementation target is `.claude/extensions/cslib/`.

---

## Findings

### 1. Standard Skill/Agent Structure

**Thin-wrapper skill pattern** (from `skill-researcher/SKILL.md` and `skill-cslib-research/SKILL.md`):

```
SKILL.md structure:
  --- YAML frontmatter (name, description, allowed-tools) ---
  Stage 1: Input validation (task in state.json, extract task fields)
  Stage 2: Preflight status update (update-task-status.sh preflight research)
  Stage 3: Create postflight marker (.postflight-pending)
  Stage 3a: Read artifact_number from state.json (with reconciliation)
  Stage 4a: Memory retrieval (optional, skip if clean_flag)
  Stage 4b: Read format specification (report-format.md)
  Stage 4: Prepare delegation context JSON
  Stage 5: Invoke subagent via Agent tool (subagent_type: "agent-name")
  Stage 5b: Self-execution fallback (write .return-meta.json if no Agent used)
  Postflight:
    Stage 6: Parse subagent return (read .return-meta.json)
    Stage 6a: Validate artifact content (non-blocking)
    Stage 7: Update task status (update-task-status.sh postflight research)
    Stage 7a: Propagate memory candidates
    Stage 8: Link artifacts in state.json
    Stage 8a: TTS lifecycle notification
    Stage 9: Cleanup marker files
    Stage 10: Return brief text summary
```

Key skill frontmatter fields:
```yaml
---
name: skill-pr-review-research
description: Fetch GitHub PR and Zulip thread data for pr-type review tasks. Invoke for pr research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---
```

**Agent definition format** (from `general-research-agent.md` and `cslib-research-agent.md`):
```yaml
---
name: pr-review-research-agent
description: Fetch and synthesize GitHub PR and Zulip thread discussion for review tasks
model: sonnet
---
```

Agent stages follow the 8-stage pattern:
- Stage 0: Write early `.return-meta.json` with `status: "in_progress"`
- Stage 1: Parse delegation context (including `sources` array from task metadata)
- Stages 2-4: Execute fetching (GitHub API, Zulip API)
- Stage 5: Synthesize findings
- Stage 6: Create research report
- Stage 7: Write final `.return-meta.json` with `status: "researched"`
- Stage 8: Return brief text summary (NOT JSON)

### 2. Source Data Access

#### 2a. GitHub PR Data (gh api)

Three endpoints together provide complete PR review content:

| Endpoint | Content | Key Fields |
|----------|---------|------------|
| `gh api repos/{owner}/{repo}/pulls/{num}` | PR metadata | `title`, `body`, `state`, `user.login`, `created_at`, `html_url` |
| `gh api repos/{owner}/{repo}/pulls/{num}/reviews` | Review summaries | `state` (APPROVED/CHANGES_REQUESTED/COMMENTED/DISMISSED), `body`, `user.login`, `submitted_at` |
| `gh api repos/{owner}/{repo}/issues/{num}/comments` | Conversation comments | `id`, `user.login`, `body`, `created_at`, `html_url` |
| `gh api repos/{owner}/{repo}/pulls/{num}/comments` | Inline code comments | `id`, `path`, `body`, `diff_hunk`, `position`, `user.login`, `created_at` |

**Confirmed working** via testing against `leanprover/cslib` PRs:
```bash
# PR metadata
gh api repos/leanprover/cslib/pulls/651 --jq '{title, body, state, user: .user.login}'

# Reviews (tested — PR 651 has 1 APPROVED review with body "Thanks!")
gh api repos/leanprover/cslib/pulls/651/reviews \
  --jq '.[] | {state, body, user: .user.login, submitted_at}'

# Issue (conversation) comments
gh api repos/leanprover/cslib/issues/651/comments \
  --jq '.[] | {user: .user.login, body, created_at}'

# Inline code review comments
gh api repos/leanprover/cslib/pulls/651/comments \
  --jq '.[] | {path, body, diff_hunk, user: .user.login}'
```

**Pagination**: Use `--paginate` flag for PRs with many comments. For most CSLib PRs, pagination is unnecessary (small repos), but should be supported.

**Auth**: `gh` is already authenticated (`benbrastmckie` account, `repo` scope). No additional setup needed.

**Note**: `/pulls/{num}/review-comments` (without "pull") does NOT exist and returns a 404-like error. The correct path is `/pulls/{num}/comments` for inline code comments.

#### 2b. Zulip Thread Data

**Available tools**:
- Python `zulip` client: available at `/home/benjamin/.nix-profile/lib/python*/site-packages/zulip/`
- CLI: `zulip-send` (send only, no read), `zulip-api-examples`, `zulip-api`
- Direct REST API via `curl`

**Python approach** (recommended):
```bash
python3 -c "
import zulip, json
client = zulip.Client(config_file='/home/benjamin/.zuliprc')
result = client.get_messages({
    'anchor': 'newest',
    'num_before': 100,
    'num_after': 0,
    'narrow': json.dumps([
        {'operator': 'stream', 'operand': 'STREAM_NAME'},
        {'operator': 'topic', 'operand': 'TOPIC_NAME'}
    ])
})
print(json.dumps(result))
"
```

**Response format**:
```json
{
  "result": "success",
  "messages": [
    {
      "id": 12345,
      "sender_full_name": "John Doe",
      "content": "Message text here",
      "timestamp": 1718437200,
      "subject": "topic name",
      "stream_id": 270676
    }
  ],
  "found_newest": true,
  "found_oldest": false
}
```

**Narrow formats** (from `parsed` fields in `state.json` sources):
```python
# Using stream name (preferred when available)
narrow = [
    {"operator": "stream", "operand": stream_name},
    {"operator": "topic", "operand": topic}
]

# Using stream ID (more robust)
narrow = [
    {"operator": "stream", "operand": stream_id},  # numeric ID
    {"operator": "topic", "operand": topic}
]
```

**CRITICAL LIMITATION**: `~/.zuliprc` currently has placeholder credentials:
```
site = REPLACE_WITH_ZULIP_SITE_URL
key = REPLACE_WITH_ZULIP_API_KEY
```

The agent must check for placeholder values and gracefully skip Zulip fetching if unconfigured, reporting this as a note in the research report rather than an error.

**Detection pattern**:
```bash
zulip_site=$(python3 -c "
import configparser
c = configparser.ConfigParser()
c.read('/home/benjamin/.zuliprc')
print(c['api'].get('site', ''))
" 2>/dev/null)
if echo "$zulip_site" | grep -q "REPLACE"; then
    echo "ZULIP_UNCONFIGURED"
fi
```

### 3. Routing Configuration

#### Current State (CSLib manifest.json)

The manifest already has a `pr` routing entry for research:
```json
"routing": {
  "research": {
    "cslib": "skill-cslib-research",
    "pr": "skill-researcher"   // <-- currently routes to generic skill-researcher
  },
  ...
}
```

This must be updated to route to the new skill:
```json
"routing": {
  "research": {
    "cslib": "skill-cslib-research",
    "pr": "skill-pr-review-research"   // <-- change to new PR-specific skill
  },
  ...
}
```

For `routing_hard`:
```json
"routing_hard": {
  "research": {
    "cslib": "skill-cslib-research-hard",
    "pr": "skill-researcher-hard"   // <-- can stay as fallback for now
  },
  ...
}
```

#### How command-route-skill.sh Works

The script (`/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh`) is sourced (not executed) by skills. It:
1. Iterates over all extension manifests
2. Looks up `routing[$operation][$task_type]` in each manifest
3. Returns the first match as `SKILL_NAME`
4. Falls back to the default skill if no match found

No changes to `command-route-skill.sh` are needed — changing the manifest entry is sufficient.

### 4. Delegation Context — Sources Array

The agent needs the `sources` array from the task in `state.json`. The skill must:

1. Read the task from `state.json` using `task_number`
2. Extract the `sources` array
3. Pass it in the delegation context to the agent

Example sources array in `state.json`:
```json
"sources": [
  {
    "type": "github_pr",
    "url": "https://github.com/leanprover/cslib/pull/42",
    "parsed": {"owner": "leanprover", "repo": "cslib", "pr_number": 42}
  },
  {
    "type": "zulip_thread",
    "url": "https://leanprover.zulipchat.com/#narrow/stream/270676-lean4/topic/My.20Topic",
    "parsed": {"org": "leanprover", "stream_id": "270676", "stream_name": "lean4", "topic": "My Topic"}
  },
  {
    "type": "description",
    "url": null,
    "parsed": {"text": "Please review the completeness proof"}
  }
]
```

The skill reads sources:
```bash
sources=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .sources // []' \
  specs/state.json)
```

And passes it in the delegation context:
```json
{
  "session_id": "...",
  "task_context": {...},
  "sources": [...],   // <-- new field, pr-type specific
  "artifact_number": "01",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### 5. Multiple Rounds of Research

The task description requires supporting multiple rounds (re-research as new comments arrive). This is handled naturally by the existing skill infrastructure:

- Each `/research N` invocation creates a new artifact with the next `artifact_number`
- The `next_artifact_number` field is incremented after each research round
- The agent fetches current state of GitHub/Zulip each time it runs (no caching)
- Multiple research artifacts coexist: `01_pr-review-initial.md`, `02_pr-review-followup.md`

No special multi-round infrastructure is needed beyond the existing artifact numbering system.

### 6. Proposed File Locations

Following the CSLib extension structure at `.claude/extensions/cslib/`:

```
.claude/extensions/cslib/
├── skills/
│   ├── skill-pr-implementation/SKILL.md   (existing)
│   └── skill-pr-review-research/SKILL.md  (NEW)
├── agents/
│   ├── cslib-research-agent.md            (existing)
│   └── pr-review-research-agent.md        (NEW)
└── manifest.json                          (update routing.research.pr)
```

**manifest.json** also needs:
- Add `"skill-pr-review-research"` to the `provides.skills` array
- Add `"pr-review-research-agent.md"` to the `provides.agents` array

### 7. Report Format for PR Review Tasks

The research report (`01_pr-review-*.md`) should have a structure adapted for PR review synthesis:

```markdown
# PR Review Research: Task #{N}

## Sources Fetched
- GitHub PR: https://github.com/owner/repo/pull/N (state: OPEN/MERGED)
- Zulip Thread: stream/topic (N messages)
- Description: "Free text..."

## PR Overview
Title, author, state, description summary

## Review Feedback Summary
- Reviewer A [APPROVED]: Comment text
- Reviewer B [CHANGES_REQUESTED]: What changes were requested

## Inline Code Comments (if any)
- path/to/file (line N): Comment text

## Conversation Comments (if any)
- @user: Comment text

## Zulip Discussion (if applicable)
- @sender: Message content

## Open Questions
- Unresolved items requiring author attention

## Requested Changes
- Explicit change requests from reviewers

## Next Steps
- What the author needs to do to get this PR merged
```

---

## Decisions

1. **Place new files inside CSLib extension** rather than in core `.claude/skills/` and `.claude/agents/` — the PR review skill is specific to the CSLib workflow and belongs alongside `skill-pr-implementation`.

2. **Use `skill-researcher` postflight pattern** (identical to `skill-cslib-research`) — the skill is a thin wrapper that delegates to the agent and handles status transitions.

3. **Agent uses Bash + Python for Zulip** rather than a Zulip MCP tool — the Python `zulip` client is available in the Nix profile and works via Bash calls.

4. **Graceful degradation for Zulip** — when `~/.zuliprc` has placeholder credentials, skip Zulip fetching and note in the report. Do not fail the research.

5. **Three GitHub endpoints** for complete PR data: `pulls/{num}` (metadata), `pulls/{num}/reviews` (summaries), `issues/{num}/comments` (conversation). Inline code comments (`pulls/{num}/comments`) are lower priority but should be included if present.

6. **No new context files** needed for the agent — the agent's instructions are self-contained in the agent definition file, following the cslib-research-agent pattern.

7. **Update manifest.json routing** from `"pr": "skill-researcher"` to `"pr": "skill-pr-review-research"` — no changes to `command-route-skill.sh` needed.

8. **EXTENSION.md** needs a new row in the Skill-Agent Mapping table for the new skill.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Zulip credentials not configured | Graceful skip with warning in report; agent proceeds with GitHub-only data |
| GitHub rate limiting | Use `--paginate` only when needed; gh's built-in auth handles rate limits with retries |
| PR has no reviews/comments yet | Report "No comments yet" — valid state for newly created review tasks |
| Large Zulip threads (100+ messages) | Use `num_before: 200` limit; summarize rather than dump all content |
| Zulip URL format edge cases | The `parsed` fields from `/pr --review` parsing are already cleaned; agent uses `parsed.stream_name` and `parsed.topic` |
| inline code comments with long diff_hunk | Truncate diff context to first 5 lines per comment |
| Multiple re-research rounds colliding | Artifact numbering handles this; each round gets its own file |

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` — thin-wrapper pattern
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` — agent definition format
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` — current routing
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md` — domain skill pattern
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` — existing pr-type skill
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-research-agent.md` — domain agent format
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — sources array format
- `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh` — routing resolution logic

### Commands Tested
- `gh api repos/leanprover/cslib/pulls/651` — PR metadata (confirmed)
- `gh api repos/leanprover/cslib/pulls/651/reviews` — review summaries (confirmed, 1 APPROVED)
- `gh api repos/leanprover/cslib/pulls/651/comments` — inline code comments (confirmed, empty)
- `gh api repos/leanprover/cslib/issues/651/comments` — conversation comments (confirmed, empty)
- Zulip Python client inspection (`get_messages`, `narrow` format)
- `~/.zuliprc` credential check (placeholder site URL)
