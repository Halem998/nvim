# Research Report: Task #673 — PR Task Type Routing

**Task**: 673 - pr_task_type_routing
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: ~45 minutes research
**Dependencies**: Tasks 671 (pr_ready status), 672 (pr-description-format.md)
**Sources/Inputs**: Codebase — manifest.json, index-entries.json, skill files, agent files, update-task-status.sh, command-route-skill.sh, predecessor summaries
**Artifacts**: specs/673_pr_task_type_routing/reports/01_pr-task-type-routing.md
**Standards**: report-format.md

---

## Executive Summary

- The cslib extension has a single task type (`cslib`) routed through `skill-cslib-research` (research), `skill-planner` (plan), and `skill-cslib-implementation` (implement). Adding a `pr` task type follows the same pattern but requires a new `skill-pr-implementation` skill (and optionally a new agent) dedicated to PR preparation work.
- The recommended approach is: **new `skill-pr-implementation` skill that reuses `cslib-implementation-agent` with PR-specific delegation context** — no new agent needed. The skill provides the PR-preparation behavior (branch, pr-description.md generation, CI verification, `pr_ready` transition) while the agent handles file writes and verification.
- The implement-phase postflight for `pr` tasks must call `update-task-status.sh postflight "$task_number" pr_ready "$session_id"` instead of the standard `postflight implement` call. This sets state to `pr_ready` (not `completed`), directing the user to run `/merge`.
- Context injection for the `pr` task type must load `pr-description-format.md` (already registered in index-entries.json for `cslib-implementation-agent`); adding `task_type: pr` to that entry's `load_when` ensures it loads for `pr`-type tasks.
- Five files require changes: `manifest.json` (routing entries), `index-entries.json` (pr-related entries scoped to `pr` task type), new `skill-pr-implementation/SKILL.md`, and optionally `EXTENSION.md`.

---

## Context & Scope

This research covers the cslib extension's existing routing architecture, the `pr_ready` status lifecycle (task 671), the canonical PR description format (task 672), and how the routing infrastructure (command-route-skill.sh, update-task-status.sh) handles the transition from `implementing` to `pr_ready`.

Scope: read-only analysis; no files were modified.

---

## Findings

### 1. Current cslib Manifest Structure

`.claude/extensions/cslib/manifest.json` defines a single task type `cslib` with:

```json
"routing": {
  "research": { "cslib": "skill-cslib-research" },
  "plan":     { "cslib": "skill-planner" },
  "implement":{ "cslib": "skill-cslib-implementation" }
}
```

The `provides` block lists two agents (`cslib-research-agent.md`, `cslib-implementation-agent.md`), two skills (`skill-cslib-research`, `skill-cslib-implementation`), and one command (`pr.md`). There is no existing `pr` task type.

### 2. Extension Manifest Pattern (from nix/nvim comparison)

All examined extensions follow the same pattern:
- Each task type gets three routing entries: `research`, `plan`, `implement`
- `plan` always routes to `skill-planner` (core planner; no domain-specific planning needed for most extensions)
- `research` and `implement` route to domain-specific skills
- New task types within an extension simply add parallel keys to the `routing` object; each key is independent

### 3. Routing Resolution (command-route-skill.sh)

The script scans all `extensions/*/manifest.json` files and returns the first matching skill for the given `operation` + `task_type` pair. Adding `"pr": "skill-pr-implementation"` under `routing.implement` is sufficient to activate the route. The script supports compound keys (`founder:deck`) but `pr` is simple.

### 4. pr_ready Status Transition

`update-task-status.sh` already supports `pr_ready`:
- `preflight:pr_ready` → sets state to `pr_ready`, TODO to `PR READY`
- `postflight:pr_ready` → sets state to `completed`, TODO to `COMPLETED`

The **implement-phase** skill for `pr` tasks must call:
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"
```
instead of the standard `postflight implement` call. This is the critical difference from the `cslib` implement skill, which calls `postflight implement` (-> `completed`).

The `pr_ready` status tells the user the task is ready for PR submission via `/merge`, without auto-completing it. The status lifecycle is:
```
[IMPLEMENTING] -> pr_ready -> [PR READY]  (postflight of /implement for pr type)
[PR READY]     -> completed -> [COMPLETED] (postflight of /merge or explicit /task sync)
```

### 5. Context Injection for pr Task Type

`index-entries.json` has 11 entries. All are scoped to `languages: ["cslib"]` and/or `agents: ["cslib-research-agent", "cslib-implementation-agent"]`. The two PR-relevant entries are:

```json
{ "path": "project/cslib/standards/pr-conventions.md", "load_when": { "languages": ["cslib"], "agents": ["cslib-implementation-agent"] } }
{ "path": "project/cslib/standards/pr-description-format.md", "load_when": { "languages": ["cslib"], "agents": ["cslib-implementation-agent"] } }
```

To ensure these load for `pr`-type tasks, two changes are needed:
1. Add `"pr"` to each entry's `load_when.languages` array, OR
2. Add `"cslib-pr-implementation-agent"` (if a new agent is created) to `load_when.agents`

**Recommended**: Since the recommendation is to reuse `cslib-implementation-agent` for PR tasks, add `"pr"` to `load_when.languages` for the two PR-related entries (pr-conventions.md and pr-description-format.md). This scopes them correctly to PR work without redundantly loading all cslib domain knowledge for PR tasks.

For research and plan phases of `pr` tasks, the `general-research-agent` (skill-researcher) and `skill-planner` are appropriate — these are meta-style tasks analyzing code changes and structuring a PR description outline.

### 6. What the pr Task Type Lifecycle Covers

Based on the task description and predecessor work, the `pr` task type lifecycle is:

**Research phase** (routed to `skill-researcher` / `general-research-agent`):
- Analyze code changes on the PR branch
- Examine stacked PR dependency graph
- Review prior PR descriptions for context
- Identify files changed, summary bullets, literature citations

**Plan phase** (routed to `skill-planner`):
- Outline PR description structure (which optional sections needed)
- Plan branch strategy: create new branch from `upstream/main` vs reuse existing
- Stacked PR base detection: confirm whether `## Context` section needed

**Implement phase** (routed to `skill-pr-implementation`):
- Create or validate the feature branch (using `git checkout upstream/main -b feat/...`)
- Generate `pr-description.md` from the canonical format template
- Run initial CI verification (subset or full 7-step pipeline)
- Transition task to `[PR READY]` instead of `[COMPLETED]`

### 7. New Skill: skill-pr-implementation

A new `skill-pr-implementation` is needed because:

1. The postflight status transition differs: `pr_ready` not `implement`
2. The delegation context differs: PR-specific (branch strategy, pr-description.md path, CI mode)
3. The verification criteria differs: PR description completeness + CI pass, not sorry count + axioms

The skill can delegate to `cslib-implementation-agent` reusing its existing file-write and CI-run capabilities, with a PR-specific delegation context that instructs it on:
- Target output: `pr-description.md` in the task directory
- Branch: create from `upstream/main`, or validate existing `feat/` branch
- CI: run the 7-step pipeline (same as the agent's Final Verification Stage)
- Compliance check: PR description contains all required sections from `pr-description-format.md`

**No new agent needed.** The `cslib-implementation-agent` already knows how to:
- Write files (Write tool)
- Run `lake build/lint/test/shake` (Bash tool)
- Follow context documents (pr-description-format.md is already in index-entries.json)

The skill wrapper is the correct layer for the `pr_ready` vs `completed` routing difference.

### 8. EXTENSION.md and skill-to-agent mapping

The cslib `EXTENSION.md` (merged into `.claude/CLAUDE.md`) should be updated to document the new routing entry. The CLAUDE.md skill-to-agent mapping table should reflect:

```
skill-pr-implementation | cslib-implementation-agent | sonnet | PR branch/description preparation
```

---

## Recommended Approach

**Option A (Recommended): New skill, reuse existing agent**

Create `skill-pr-implementation/SKILL.md` that:
1. Validates task type is `pr`
2. Preflight: sets status to `implementing`
3. Delegates to `cslib-implementation-agent` with PR-specific context
4. **Postflight**: calls `update-task-status.sh postflight pr_ready` (not `postflight implement`)
5. Links `pr-description.md` artifact in state.json

**Option B (Alternative): Inline skill, no agent**

The PR preparation work (branch creation, pr-description.md generation, CI verification) could be done inline by the skill itself without delegating to an agent. This is simpler but loses the subagent isolation and metadata protocol that the rest of the system uses.

**Recommendation**: Option A for consistency with the rest of the skill/agent architecture.

---

## Exact Changes Needed

### 1. manifest.json — Add `pr` routing entries

```json
"routing": {
  "research": {
    "cslib": "skill-cslib-research",
    "pr":    "skill-researcher"
  },
  "plan": {
    "cslib": "skill-planner",
    "pr":    "skill-planner"
  },
  "implement": {
    "cslib": "skill-cslib-implementation",
    "pr":    "skill-pr-implementation"
  }
}
```

Add `"skill-pr-implementation"` to `provides.skills`:
```json
"skills": [
  "skill-cslib-research",
  "skill-cslib-implementation",
  "skill-pr-implementation"
]
```

### 2. index-entries.json — Extend pr-related entries to `pr` task type

Update the `pr-conventions.md` entry's `load_when`:
```json
"load_when": {
  "languages": ["cslib", "pr"],
  "agents": ["cslib-implementation-agent"]
}
```

Update the `pr-description-format.md` entry's `load_when`:
```json
"load_when": {
  "languages": ["cslib", "pr"],
  "agents": ["cslib-implementation-agent"]
}
```

Also add `"ci-pipeline.md"` to `pr` language (CI verification is part of PR prep):
```json
"load_when": {
  "languages": ["cslib", "pr"],
  "agents": ["cslib-implementation-agent"]
}
```

### 3. New file: skill-pr-implementation/SKILL.md

Path: `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`

Key differences from `skill-cslib-implementation`:
- Trigger: task type is `pr`
- Delegation context includes: `pr_branch_strategy`, `pr_description_path`, `ci_verification_mode`
- Postflight calls: `update-task-status.sh postflight "$task_number" pr_ready "$session_id"`
- Artifact type: `pr_description` (links `pr-description.md` in state.json)
- Summary message directs user to run `/merge` after completion

### 4. EXTENSION.md — Add pr task type to routing table

Update the routing table in EXTENSION.md to include the `pr` row.

---

## Decisions

- **No new agent**: `cslib-implementation-agent` is reused. The skill wrapper handles the `pr_ready` transition difference.
- **skill-researcher for research phase**: PR research is branch/code analysis, not Lean proof research. The general `skill-researcher` + `general-research-agent` is appropriate; no cslib-specific Lean MCP tools needed.
- **skill-planner for plan phase**: Same rationale. PR description planning is a structured writing task, not Lean-specific.
- **Scope PR context loading to `pr` language**: Rather than adding a new agent name to index-entries.json, add `"pr"` to the `languages` array of the two PR standards files. This keeps context loading declarative and uses the existing mechanism.
- **ci-pipeline.md also scoped to `pr`**: The implement phase runs CI verification, so the CI pipeline reference should be available.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| skill-pr-implementation's postflight calls wrong update-task-status target | Explicitly document and test the `pr_ready` argument vs `implement` |
| `cslib-implementation-agent` attempts proof work instead of PR prep | Delegation context must clearly scope the task: "generate pr-description.md, not Lean proofs" |
| Index entries with `languages: ["cslib", "pr"]` load for all cslib tasks | They already load for cslib via the agent filter; the language addition only adds them for `pr`-type tasks run by non-cslib agents. Acceptable overlap. |
| EXTENSION.md drift from manifest.json | Update both atomically in the same implementation phase |

---

## Files to Create / Modify

| Action | File | Summary |
|--------|------|---------|
| Modify | `.claude/extensions/cslib/manifest.json` | Add `pr` routing entries, add skill to provides.skills |
| Modify | `.claude/extensions/cslib/index-entries.json` | Add `"pr"` to languages for pr-conventions.md, pr-description-format.md, ci-pipeline.md entries |
| Create | `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` | New skill for PR preparation; postflight → pr_ready |
| Modify | `.claude/extensions/cslib/EXTENSION.md` | Add `pr` row to routing table |

---

## Context Extension Recommendations

- The `index-entries.json` `load_when` schema currently uses `languages` as the discriminator for task type matching. This is slightly confusing since `pr` is a task type, not a programming language. A future improvement could rename the field to `task_types` in a schema migration — but this is out of scope for task 673.

---

## Appendix

### Files Read

- `.claude/extensions/cslib/manifest.json`
- `.claude/extensions/cslib/index-entries.json`
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `.claude/extensions/cslib/skills/skill-cslib-research/SKILL.md`
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md`
- `.claude/extensions/cslib/agents/cslib-research-agent.md` (partial)
- `.claude/extensions/cslib/commands/pr.md`
- `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`
- `.claude/extensions/nvim/manifest.json`
- `.claude/extensions/nix/manifest.json`
- `.claude/scripts/command-route-skill.sh`
- `.claude/scripts/update-task-status.sh` (first 120 lines)
- `.claude/skills/skill-implementer/SKILL.md` (postflight sections)
- `.claude/skills/skill-orchestrator/SKILL.md`
- `specs/671_pr_ready_status_lifecycle/summaries/01_implementation-summary.md`
- `specs/672_pr_description_format_standard/summaries/01_implementation-summary.md`
