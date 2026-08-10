# Implementation Plan: Create skill-pr-review-implementation

- **Task**: 724 - Create skill-pr-review-implementation
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: Task 723 (skill-pr-review-research)
- **Research Inputs**: specs/724_create_pr_review_implementation_skill/reports/01_pr-review-impl-skill.md
- **Artifacts**: plans/01_pr-review-impl-skill.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `skill-pr-review-implementation` skill and `pr-review-implementation-agent` that handle `/implement` on pr-type review tasks created by `/pr --review`. The skill follows the thin-wrapper pattern established by `skill-pr-review-research`. When sources are present in the task's state.json entry, the agent reads the research report, implements code changes addressing reviewer feedback, and composes `pr-response.md` and/or `zulip-response.md` in the task directory. When sources are absent (legacy PR prep tasks), the skill delegates to `cslib-implementation-agent` for the existing pr-description workflow. The task transitions to `[PR READY]` using `preflight pr_ready`.

### Research Integration

Key findings from the research report:

1. **Thin-wrapper pattern**: Follow `skill-pr-review-research` exactly -- input validation, preflight, delegation, postflight with artifact linking
2. **PR READY transition**: Use `bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"` to reach `[PR READY]` (not `postflight pr_ready`, which goes to `[COMPLETED]`)
3. **Routing change**: Replace `"pr": "skill-pr-implementation"` with `"pr": "skill-pr-review-implementation"` in manifest.json `routing.implement`; the new skill detects `sources` presence to dispatch between review-response and PR-description workflows
4. **Response files**: `pr-response.md` (GitHub PR comment with reviewer-grouped sections quoting original comments) and `zulip-response.md` (brief Zulip message with `<!-- Send: zulip-send -->` header comment), conditioned on source types
5. **Agent model**: sonnet (worker agent pattern)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly correspond to this task. This is an extension of the CSLib extension's PR review workflow (tasks 722-724).

## Goals & Non-Goals

**Goals**:
- Create `skill-pr-review-implementation/SKILL.md` following the thin-wrapper pattern
- Create `pr-review-implementation-agent.md` with clear stage-based execution flow
- Update `manifest.json` routing, provides.agents, and provides.skills
- Skill correctly dispatches between review-response workflow (sources present) and PR-description workflow (sources absent)
- Agent composes `pr-response.md` and/or `zulip-response.md` conditioned on source types
- Agent implements code changes when the research report contains actionable requested changes
- Task transitions to `[PR READY]` via `preflight pr_ready`

**Non-Goals**:
- Modifying the existing `skill-pr-implementation/SKILL.md` (kept as-is for reference)
- Creating a compound task type `pr:review` (uses `sources` detection instead)
- Automated posting of response files to GitHub or Zulip (user handles this manually)
- Hard-mode variant of this skill (can be added later if needed)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `postflight pr_ready` vs `preflight pr_ready` confusion -- wrong one sets COMPLETED | H | M | Explicitly document in SKILL.md and agent; use `preflight pr_ready` only |
| Routing change breaks non-review PR tasks (no sources) | H | L | Skill checks `sources` array; absent sources delegates to `cslib-implementation-agent` |
| Agent attempts deep code changes beyond its expertise | M | M | Agent MUST NOT section prohibits Lean proof work; code changes limited to what research report requests |
| Research report missing (user skipped /research) | M | L | Skill validates report exists; agent synthesizes from sources directly if no report |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create the Agent Definition [COMPLETED]

**Goal**: Create `pr-review-implementation-agent.md` with complete stage-based execution flow for reading research reports, implementing code changes, and composing response files.

**Tasks**:
- [ ] Create `.claude/extensions/cslib/agents/pr-review-implementation-agent.md` with frontmatter (`name: pr-review-implementation-agent`, `description: ...`, `model: sonnet`)
- [ ] Write Stage 0: Initialize Early Metadata -- create `.return-meta.json` with `status: "in_progress"` before substantive work
- [ ] Write Stage 1: Parse Delegation Context -- extract `session_id`, `task_context`, `sources`, `artifact_number`, `plan_path`, `report_path`, `metadata_file_path`
- [ ] Write Stage 2: Load Research Report -- read report at `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md`, extract `Requested Changes`, `Open Questions`, `Inline Code Comments`, and `Sources Fetched` sections
- [ ] Write Stage 2a: Load Plan (Optional) -- if `plan_path` is provided and file exists, read the plan for implementation guidance; if no plan, proceed with research report only
- [ ] Write Stage 3: Determine Response Files Needed -- inspect `sources` array: `github_pr` type present -> create `pr-response.md`; `zulip_thread` type present -> create `zulip-response.md`
- [ ] Write Stage 4: Implement Code Changes -- if the research report's `Requested Changes` section contains actionable items (formatting, typos, minor adjustments), apply those changes to the codebase; for substantial changes, note them in response files as "will be addressed in follow-up"
- [ ] Write Stage 5: Compose pr-response.md -- write to `specs/{NNN}_{SLUG}/pr-response.md` using the format: heading per reviewer, blockquote of original comment, explanation of changes made; include `## Changes Made`, `## Remaining Questions / Clarifications`, and `## Summary` sections
- [ ] Write Stage 6: Compose zulip-response.md -- write to `specs/{NNN}_{SLUG}/zulip-response.md` with `<!-- Send: zulip-send --stream="{stream_name}" --subject="{topic}" -->` header comment followed by brief Markdown message body summarizing changes and linking to PR
- [ ] Write Stage 7: Write Final Metadata -- update `.return-meta.json` with `status: "implemented"`, artifact entries for each response file created, and `completion_data.completion_summary`
- [ ] Write Stage 8: Return Brief Text Summary -- 3-6 bullet points, NOT JSON
- [ ] Write Error Handling section -- missing sources, missing research report, empty requested changes
- [ ] Write Critical Requirements (MUST DO / MUST NOT) section
- [ ] Include MUST NOT constraints: no PR creation, no git push, no posting to GitHub/Zulip, no `postflight pr_ready` call (skill handles status transition)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/agents/pr-review-implementation-agent.md` - Create new file (~350-400 lines)

**Verification**:
- Agent file exists with correct frontmatter (name, description, model: sonnet)
- All 8 stages documented with clear instructions
- pr-response.md and zulip-response.md format templates included
- MUST NOT section prohibits PR creation, git push, and posting responses

---

### Phase 2: Create the Skill Wrapper [COMPLETED]

**Goal**: Create `skill-pr-review-implementation/SKILL.md` as a thin wrapper that validates inputs, dispatches to the correct agent based on `sources` presence, and handles postflight with `preflight pr_ready` status transition.

**Tasks**:
- [ ] Create directory `.claude/extensions/cslib/skills/skill-pr-review-implementation/`
- [ ] Create `SKILL.md` with frontmatter (`name: skill-pr-review-implementation`, `description: ...`, `allowed-tools: Agent, Bash, Edit, Read, Write`)
- [ ] Write Trigger Conditions -- activates when task_type is "pr" and `/implement` targets it
- [ ] Write Stage 1: Input Validation -- validate task_number exists, task_type is "pr"; check `sources` array presence in state.json
- [ ] Write Stage 1a: Dispatch Decision -- if `sources` array is present and non-empty, proceed with review-response workflow; if `sources` absent, delegate to `cslib-implementation-agent` with PR-description context (same as `skill-pr-implementation`)
- [ ] Write Stage 2: Preflight Status Update -- `bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"`
- [ ] Write Stage 3: Create Postflight Marker -- `touch "specs/{NNN}_{SLUG}/.postflight-pending"`
- [ ] Write Stage 3a: Read Artifact Number -- read `next_artifact_number` from state.json
- [ ] Write Stage 4: Prepare Delegation Context -- build JSON with `sources`, `report_path` (find latest report), `plan_path` (find latest plan if exists), `metadata_file_path`
- [ ] Write Stage 4a: Memory Retrieval (Optional) -- retrieve memories if `--clean` not set
- [ ] Write Stage 5: Invoke Subagent -- use Agent tool with `subagent_type: "pr-review-implementation-agent"`
- [ ] Write Stage 5b: Self-Execution Fallback
- [ ] Write Postflight stages (6-9):
  - Stage 6: Parse Subagent Return (read `.return-meta.json`)
  - Stage 6a: Validate Artifact Content (non-blocking check for response files)
  - Stage 7: Update Task Status -- **CRITICAL**: use `bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"` to set `[PR READY]`
  - Stage 7a: Propagate Memory Candidates
  - Stage 8: Link Artifacts in state.json (pr-response.md and/or zulip-response.md as type `pr_response` / `zulip_response`) + regenerate TODO.md
  - Stage 8a: TTS Lifecycle Notification
  - Stage 9: Cleanup Marker Files
- [ ] Write Stage 10: Return Brief Text Summary -- include guidance to manually post response files
- [ ] Write MUST NOT (Postflight Boundary) section -- mirror `skill-pr-implementation` restrictions plus no `postflight implement` call

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` - Create new file (~250-300 lines)

**Verification**:
- Skill file exists with correct frontmatter
- Dispatch decision documented: sources present -> pr-review-implementation-agent; sources absent -> cslib-implementation-agent
- Status transition uses `preflight pr_ready` (NOT `postflight pr_ready`)
- All postflight stages present and match the pattern from `skill-pr-review-research`

---

### Phase 3: Update Manifest and Verify [COMPLETED]

**Goal**: Update `manifest.json` to register the new skill, agent, and routing entry. Verify all files are internally consistent.

**Tasks**:
- [ ] Add `"pr-review-implementation-agent.md"` to `provides.agents` array in manifest.json
- [ ] Add `"skill-pr-review-implementation"` to `provides.skills` array in manifest.json
- [ ] Change `routing.implement.pr` from `"skill-pr-implementation"` to `"skill-pr-review-implementation"` in manifest.json
- [ ] Verify the agent file references match what the skill invokes (`subagent_type: "pr-review-implementation-agent"`)
- [ ] Verify skill frontmatter `name` matches the routing entry
- [ ] Verify `provides.skills` still includes `"skill-pr-implementation"` (kept as reference, no longer in routing)
- [ ] Verify the `routing_hard.implement.pr` entry -- leave as `"skill-implementer-hard"` (no hard variant for review implementation yet)

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - Update provides.agents, provides.skills, routing.implement.pr

**Verification**:
- `jq '.provides.agents' manifest.json` includes `pr-review-implementation-agent.md`
- `jq '.provides.skills' manifest.json` includes `skill-pr-review-implementation`
- `jq '.routing.implement.pr' manifest.json` returns `skill-pr-review-implementation`
- `jq '.provides.skills' manifest.json` still includes `skill-pr-implementation` (not removed)
- No JSON parse errors in manifest.json (`jq '.' manifest.json`)

---

## Testing & Validation

- [ ] `jq '.' .claude/extensions/cslib/manifest.json` parses without error
- [ ] `jq '.routing.implement.pr' .claude/extensions/cslib/manifest.json` returns `"skill-pr-review-implementation"`
- [ ] `.claude/extensions/cslib/agents/pr-review-implementation-agent.md` exists with `model: sonnet` frontmatter
- [ ] `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` exists with correct frontmatter
- [ ] Skill SKILL.md contains `preflight pr_ready` (not `postflight pr_ready`) in Stage 7
- [ ] Agent file contains both `pr-response.md` and `zulip-response.md` format templates
- [ ] Agent MUST NOT section prohibits PR creation, git push, and response posting
- [ ] Skill dispatch logic documented: sources present vs absent leads to different agents

## Artifacts & Outputs

- `.claude/extensions/cslib/agents/pr-review-implementation-agent.md` - New agent definition
- `.claude/extensions/cslib/skills/skill-pr-review-implementation/SKILL.md` - New skill wrapper
- `.claude/extensions/cslib/manifest.json` - Updated routing, provides.agents, provides.skills

## Rollback/Contingency

Revert manifest.json routing change from `"skill-pr-review-implementation"` back to `"skill-pr-implementation"` to restore previous behavior. Delete the new skill directory and agent file. All changes are additive except the routing entry, so rollback is straightforward via `git checkout -- .claude/extensions/cslib/manifest.json` and removing the two new files.
