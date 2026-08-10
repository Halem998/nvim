# Implementation Plan: Task #723

- **Task**: 723 - Create skill-pr-review-research
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 722 (complete -- added --review flag to /pr command)
- **Research Inputs**: specs/723_create_pr_review_research_skill/reports/01_pr-review-research-skill.md
- **Artifacts**: plans/01_pr-review-research-skill.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `skill-pr-review-research` skill and `pr-review-research-agent` agent within the CSLib extension to handle `/research` on `pr`-type tasks created by `/pr --review`. The skill follows the thin-wrapper pattern established by `skill-cslib-research`, delegating to a new agent that fetches GitHub PR data via `gh api`, optionally fetches Zulip thread content via the Python `zulip` client, and synthesizes all sources into a structured research report. The manifest routing for `pr` research is updated from `skill-researcher` to `skill-pr-review-research`.

### Research Integration

Key findings from research report `01_pr-review-research-skill.md`:
- Thin-wrapper skill pattern from `skill-cslib-research/SKILL.md` is the template for the new skill
- GitHub PR data requires four `gh api` endpoints: `pulls/{num}` (metadata), `pulls/{num}/reviews` (review summaries), `issues/{num}/comments` (conversation), `pulls/{num}/comments` (inline code comments)
- Zulip uses the Python `zulip` client with `~/.zuliprc` credentials; site URL is currently a placeholder requiring graceful degradation
- The `sources` array from `state.json` task entry must be passed in the delegation context
- Routing update in `manifest.json`: change `routing.research.pr` from `"skill-researcher"` to `"skill-pr-review-research"`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `skill-pr-review-research/SKILL.md` following the thin-wrapper pattern
- Create `pr-review-research-agent.md` with GitHub and Zulip fetching logic
- Update `manifest.json` routing and provides arrays
- Update `EXTENSION.md` skill-agent mapping table
- Handle graceful Zulip degradation when `~/.zuliprc` is unconfigured

**Non-Goals**:
- Creating a hard-mode variant of the skill (can be added later if needed)
- Creating Zulip MCP tools (the Python client via Bash is sufficient)
- Modifying `command-route-skill.sh` (manifest routing is sufficient)
- Adding context files for the agent (instructions are self-contained)
- Creating the implementation counterpart (task 724 scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Zulip credentials not configured | M | H | Agent checks `~/.zuliprc` for placeholder values and skips Zulip with a note in the report |
| GitHub rate limiting on large PRs | L | L | Use `--paginate` flag; `gh` auth handles rate limit retries |
| PR has no reviews/comments | L | M | Report "No comments yet" as valid state |
| Large Zulip threads exceed context | M | L | Cap at `num_before: 200` messages; agent summarizes rather than dumps |
| Sources array missing from state.json | H | L | Skill validates sources exist before delegation; error if missing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create pr-review-research-agent.md [COMPLETED]

**Goal**: Create the agent definition file that performs GitHub and Zulip fetching, synthesizes findings, and writes the research report.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/agents/pr-review-research-agent.md` with YAML frontmatter (`name: pr-review-research-agent`, `description: ...`, `model: sonnet`)
- [ ] Define the agent overview: purpose (fetch and synthesize PR review discussion), invocation source (`skill-pr-review-research`), return format (brief text + metadata file)
- [ ] Define allowed tools section: Read, Write, Edit, Bash (for `gh api` and Python `zulip` client), Glob, Grep
- [ ] Write Stage 0: Early metadata -- write `.return-meta.json` with `status: "in_progress"` before any substantive work
- [ ] Write Stage 1: Parse delegation context -- extract `session_id`, `task_context`, `sources` array, `artifact_number`, `metadata_file_path`
- [ ] Write Stage 2: GitHub PR fetching -- for each source with `type: "github_pr"`:
  - Extract `owner`, `repo`, `pr_number` from `parsed` field
  - Fetch PR metadata: `gh api repos/{owner}/{repo}/pulls/{num} --jq '{title, body, state, user: .user.login, created_at, html_url, merged}'`
  - Fetch reviews: `gh api repos/{owner}/{repo}/pulls/{num}/reviews --jq '.[] | {state, body, user: .user.login, submitted_at}'`
  - Fetch conversation comments: `gh api repos/{owner}/{repo}/issues/{num}/comments --jq '.[] | {user: .user.login, body, created_at}'`
  - Fetch inline code comments: `gh api repos/{owner}/{repo}/pulls/{num}/comments --jq '.[] | {path, body, diff_hunk, user: .user.login, created_at}'` (truncate `diff_hunk` to first 5 lines per comment)
  - Use `--paginate` for endpoints that may have many results
- [ ] Write Stage 3: Zulip thread fetching -- for each source with `type: "zulip_thread"`:
  - Check `~/.zuliprc` for placeholder credentials using configparser pattern from research
  - If unconfigured: log warning, set `zulip_status = "unconfigured"`, skip fetching
  - If configured: use Python `zulip` client to call `get_messages` with narrow by stream name and topic from `parsed` fields
  - Cap at `num_before: 200` messages
  - Extract `sender_full_name`, `content`, `timestamp` from each message
- [ ] Write Stage 4: Description source handling -- for each source with `type: "description"`, extract the `parsed.text` field
- [ ] Write Stage 5: Synthesize findings into research report at `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md` following the PR review report format from research findings:
  - Sources Fetched section listing all sources with status
  - PR Overview (title, author, state, description summary)
  - Review Feedback Summary (reviewer, state, comments)
  - Inline Code Comments (path, comment, truncated diff context)
  - Conversation Comments (user, comment)
  - Zulip Discussion (sender, message) or note if unconfigured/skipped
  - Open Questions (unresolved items)
  - Requested Changes (explicit change requests from reviewers)
  - Next Steps (what the author needs to do)
- [ ] Write Stage 6: Write final `.return-meta.json` with `status: "researched"`, artifact path, and metadata
- [ ] Write Stage 7: Return brief text summary (NOT JSON)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/pr-review-research-agent.md` - CREATE new agent definition

**Verification**:
- File exists at expected path
- YAML frontmatter has `name`, `description`, `model` fields
- All 8 stages are documented
- Zulip graceful degradation is explicitly handled in Stage 3
- GitHub endpoint URLs match research findings (4 endpoints)
- Report format section matches the structure from research findings

---

### Phase 2: Create skill-pr-review-research SKILL.md [COMPLETED]

**Goal**: Create the thin-wrapper skill that validates inputs, extracts the `sources` array from `state.json`, delegates to the agent, and handles postflight.

**Tasks**:
- [ ] Create directory `.claude/extensions/cslib/skills/skill-pr-review-research/`
- [ ] Create `SKILL.md` with YAML frontmatter:
  ```yaml
  ---
  name: skill-pr-review-research
  description: Fetch GitHub PR and Zulip thread data for pr-type review tasks. Invoke for pr research tasks.
  allowed-tools: Agent, Bash, Edit, Read, Write
  ---
  ```
- [ ] Write Stage 1 (Input Validation): Validate `task_number` exists, `task_type` is `"pr"`, and `sources` array is present in state.json task entry
- [ ] Write Stage 2 (Preflight Status Update): Call `update-task-status.sh preflight "$task_number" research "$session_id"`
- [ ] Write Stage 3 (Create Postflight Marker): Write `.postflight-pending` marker file
- [ ] Write Stage 3a (Read Artifact Number): Read `next_artifact_number` from state.json with reconciliation pattern
- [ ] Write Stage 4a (Memory Retrieval): Optional memory retrieval (skip if `clean_flag`)
- [ ] Write Stage 4b (Read Format Spec): Reference `report-format.md` for the agent
- [ ] Write Stage 4 (Prepare Delegation Context): Build delegation JSON including:
  - Standard fields: `session_id`, `delegation_depth`, `delegation_path`, `timeout`, `task_context`, `metadata_file_path`
  - PR-specific field: `sources` array extracted from state.json via jq:
    ```bash
    sources=$(jq -r --argjson num "$task_number" \
      '.active_projects[] | select(.project_number == $num) | .sources // []' \
      specs/state.json)
    ```
  - `artifact_number` for report naming
  - `focus_prompt` if provided
- [ ] Write Stage 5 (Invoke Subagent): Use Agent tool with `subagent_type: "pr-review-research-agent"`
- [ ] Write Stage 5b (Self-Execution Fallback): If work was done inline without Agent tool, write `.return-meta.json` before proceeding to postflight
- [ ] Write Postflight stages (ALWAYS EXECUTE):
  - Stage 6: Parse subagent return from `.return-meta.json`
  - Stage 6a: Validate artifact content (non-blocking)
  - Stage 7: Update task status via `update-task-status.sh postflight "$task_number" research "$session_id"`
  - Stage 7a: Propagate memory candidates from metadata
  - Stage 8: Link artifacts in state.json and regenerate TODO.md
  - Stage 8a: TTS lifecycle notification
  - Stage 9: Cleanup marker files (remove `.postflight-pending`, `.return-meta.json`)
  - Stage 10: Return brief text summary (NOT JSON)

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md` - CREATE new skill definition

**Verification**:
- File exists at expected path
- YAML frontmatter matches the format from `skill-cslib-research`
- Sources extraction uses the safe jq pattern (no `!=` operator)
- Delegation context includes `sources` array
- All postflight stages are present and follow the `skill-cslib-research` pattern
- Self-execution fallback (Stage 5b) is included

---

### Phase 3: Update manifest.json and EXTENSION.md [COMPLETED]

**Goal**: Register the new skill and agent in the CSLib extension manifest and update the extension documentation.

**Tasks**:
- [ ] Update `.claude/extensions/cslib/manifest.json`:
  - Add `"pr-review-research-agent.md"` to `provides.agents` array
  - Add `"skill-pr-review-research"` to `provides.skills` array
  - Change `routing.research.pr` from `"skill-researcher"` to `"skill-pr-review-research"`
- [ ] Update `.claude/extensions/cslib/EXTENSION.md`:
  - Add row to Skill-Agent Mapping table:
    ```
    | skill-pr-review-research | pr-review-research-agent | sonnet | Fetch and synthesize GitHub PR and Zulip discussion for review tasks |
    ```
  - Update the `pr` row in Language Routing table to reflect new research tool set (add `gh api`, `python3 zulip`)
- [ ] Verify `routing_hard.research.pr` entry -- keep as `"skill-researcher-hard"` since no hard variant is being created (graceful fallback per `command-route-skill.sh`)

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - UPDATE provides and routing
- `.claude/extensions/cslib/EXTENSION.md` - UPDATE skill-agent mapping table

**Verification**:
- `manifest.json` is valid JSON after edits
- `provides.agents` contains the new agent filename
- `provides.skills` contains the new skill name
- `routing.research.pr` points to `"skill-pr-review-research"`
- `routing_hard.research.pr` still points to `"skill-researcher-hard"` (no change)
- EXTENSION.md table has the new row with correct columns
- Run `jq . .claude/extensions/cslib/manifest.json` to validate JSON

## Testing & Validation

- [ ] Verify `manifest.json` is valid JSON: `jq . .claude/extensions/cslib/manifest.json`
- [ ] Verify skill SKILL.md has required YAML frontmatter fields: `name`, `description`, `allowed-tools`
- [ ] Verify agent .md has required YAML frontmatter fields: `name`, `description`, `model`
- [ ] Verify routing resolution: `routing.research.pr` resolves to `"skill-pr-review-research"`
- [ ] Verify `provides.agents` and `provides.skills` include the new entries
- [ ] Verify agent handles Zulip unconfigured case with graceful skip (not error)
- [ ] Verify agent uses all 4 GitHub API endpoints documented in research
- [ ] Verify skill extracts `sources` array from state.json task entry
- [ ] Verify postflight stages match `skill-cslib-research` pattern

## Artifacts & Outputs

- `.claude/extensions/cslib/agents/pr-review-research-agent.md` (NEW)
- `.claude/extensions/cslib/skills/skill-pr-review-research/SKILL.md` (NEW)
- `.claude/extensions/cslib/manifest.json` (MODIFIED)
- `.claude/extensions/cslib/EXTENSION.md` (MODIFIED)

## Rollback/Contingency

All changes are additive (new files plus manifest/docs updates). To revert:
1. Delete `.claude/extensions/cslib/skills/skill-pr-review-research/` directory
2. Delete `.claude/extensions/cslib/agents/pr-review-research-agent.md`
3. Revert `manifest.json` routing entry back to `"skill-researcher"` and remove the new provides entries
4. Revert EXTENSION.md table row addition

Since the existing `skill-researcher` fallback still works for `pr` tasks, partial rollback (reverting just the manifest routing) is safe and restores original behavior.
