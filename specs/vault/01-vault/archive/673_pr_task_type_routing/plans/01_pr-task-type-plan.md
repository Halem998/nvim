# Implementation Plan: PR Task Type Routing

- **Task**: 673 - Add pr task type routing to cslib extension
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 671 (pr_ready status lifecycle), 672 (pr-description-format.md)
- **Research Inputs**: specs/673_pr_task_type_routing/reports/01_pr-task-type-routing.md
- **Artifacts**: plans/01_pr-task-type-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `pr` task type to the cslib extension routing so that `/research`, `/plan`, and `/implement` can operate on PR-preparation tasks. The research and plan phases route to the existing general `skill-researcher` and `skill-planner` (PR work is branch/code analysis and structured writing, not Lean-specific). The implement phase routes to a new `skill-pr-implementation` that reuses `cslib-implementation-agent` but transitions the task to `[PR READY]` instead of `[COMPLETED]`. Context injection is extended so PR-relevant standards (pr-conventions.md, pr-description-format.md, ci-pipeline.md) load for `pr`-type tasks.

### Research Integration

Key findings from the research report (01_pr-task-type-routing.md):

- The routing infrastructure (`command-route-skill.sh`) resolves skills by scanning extension manifests for `routing.$operation.$task_type`; adding `"pr"` keys is sufficient to activate the route.
- `update-task-status.sh` already supports `pr_ready` as a target status (task 671): `preflight:pr_ready` sets `[PR READY]`, `postflight:pr_ready` sets `[COMPLETED]`.
- The new `skill-pr-implementation` should call `update-task-status.sh postflight "$task_number" pr_ready "$session_id"` instead of `postflight implement` -- this is the sole behavioral difference from `skill-cslib-implementation`.
- Context injection uses the `languages` array in `index-entries.json` as the task-type discriminator; adding `"pr"` to the three PR-relevant entries scopes them correctly.
- No new agent is needed; `cslib-implementation-agent` is reused with PR-specific delegation context.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Register `pr` task type routing in the cslib manifest for all three phases (research, plan, implement)
- Create `skill-pr-implementation/SKILL.md` that delegates to `cslib-implementation-agent` with PR-specific context and transitions to `pr_ready`
- Extend `index-entries.json` so PR-relevant context documents load for `pr`-type tasks
- Update `EXTENSION.md` to document the new routing entry and skill

**Non-Goals**:
- Modifying the `/pr` command (commands/pr.md) -- that is task 674 scope
- Creating a new agent -- `cslib-implementation-agent` is reused
- Changing `update-task-status.sh` -- `pr_ready` support already exists (task 671)
- Renaming `languages` to `task_types` in index-entries.json schema (noted as future improvement in research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| skill-pr-implementation postflight calls wrong status target (`implement` instead of `pr_ready`) | H | L | Explicitly document the `pr_ready` argument in the SKILL.md; verify in testing |
| cslib-implementation-agent attempts Lean proof work instead of PR description generation | M | M | Delegation context must clearly scope the task to "generate pr-description.md, not Lean proofs" |
| Adding `"pr"` to index-entries.json `languages` causes unwanted context loading for cslib tasks | L | L | The entries already load for `cslib` via agent filter; the `"pr"` addition only adds them for `pr`-type tasks run by non-cslib agents |
| EXTENSION.md drifts from manifest.json | M | L | Update both in the same phase (Phase 3) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Manifest Routing and Context Index [COMPLETED]

**Goal**: Register the `pr` task type in manifest.json routing and extend index-entries.json so PR-relevant context loads for `pr`-type tasks.

**Tasks**:
- [x] Add `"pr": "skill-researcher"` to `routing.research` in `.claude/extensions/cslib/manifest.json` *(completed)*
- [x] Add `"pr": "skill-planner"` to `routing.plan` in `.claude/extensions/cslib/manifest.json` *(completed)*
- [x] Add `"pr": "skill-pr-implementation"` to `routing.implement` in `.claude/extensions/cslib/manifest.json` *(completed)*
- [x] Add `"skill-pr-implementation"` to `provides.skills` array in `.claude/extensions/cslib/manifest.json` *(completed)*
- [x] In `.claude/extensions/cslib/index-entries.json`, add `"pr"` to `load_when.languages` for the `pr-conventions.md` entry (index 6) *(completed)*
- [x] In `.claude/extensions/cslib/index-entries.json`, add `"pr"` to `load_when.languages` for the `pr-description-format.md` entry (index 7) *(completed)*
- [x] In `.claude/extensions/cslib/index-entries.json`, add `"pr"` to `load_when.languages` for the `ci-pipeline.md` entry (index 5) *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` -- add routing entries and skill registration
- `.claude/extensions/cslib/index-entries.json` -- extend languages arrays for 3 entries

**Verification**:
- `jq '.routing' .claude/extensions/cslib/manifest.json` shows `pr` keys under all three operations
- `jq '.provides.skills' .claude/extensions/cslib/manifest.json` includes `skill-pr-implementation`
- `jq '[.entries[] | select(any(.load_when.languages[]?; . == "pr")) | .path]' .claude/extensions/cslib/index-entries.json` returns the 3 PR-relevant paths
- `bash .claude/scripts/command-route-skill.sh implement pr` returns `skill-pr-implementation`

---

### Phase 2: Create skill-pr-implementation [COMPLETED]

**Goal**: Create the new skill SKILL.md that delegates PR preparation work to `cslib-implementation-agent` with PR-specific context and transitions to `[PR READY]` via the `pr_ready` status target.

**Tasks**:
- [x] Create directory `.claude/extensions/cslib/skills/skill-pr-implementation/` *(completed)*
- [x] Create `SKILL.md` with frontmatter: `name: skill-pr-implementation`, `description: PR branch and description preparation...`, `allowed-tools: Agent, Bash, Edit, Read, Write` *(completed)*
- [x] Define trigger conditions: task type is `pr` *(completed)*
- [x] Stage 1 (Input Validation): Validate task_number, task_type is `pr`, plan exists *(completed)*
- [x] Stage 2 (Preflight): Call `update-task-status.sh preflight "$task_number" implement "$session_id"` to set status to `[IMPLEMENTING]` *(completed)*
- [x] Stage 3 (Delegation Context): Include PR-specific fields: `pr_branch_strategy` (create from upstream/main or validate existing), `pr_description_path` (specs/{NNN}_{SLUG}/pr-description.md), `ci_verification_mode` (full 7-step pipeline) *(completed)*
- [x] Stage 4 (Invoke Subagent): Delegate to `cslib-implementation-agent` with PR-scoped prompt explaining the task is PR description generation, not Lean proof implementation *(completed)*
- [x] Stage 4b (Self-Execution Fallback): Write `.return-meta.json` if agent tool was not used *(completed)*
- [x] Stage 5 (Parse Return): Read metadata file from `specs/{NNN}_{SLUG}/.return-meta.json` *(completed)*
- [x] Stage 6 (Postflight Status): Call `update-task-status.sh postflight "$task_number" pr_ready "$session_id"` -- this is the critical difference from skill-cslib-implementation which calls `postflight implement` *(completed)*
- [x] Stage 7 (Link Artifacts): Add pr-description.md artifact to state.json *(completed)*
- [x] Stage 8 (Git Commit): Commit with session ID *(completed)*
- [x] Stage 9 (Return Summary): Include message directing user to run `/merge` after completion *(completed)*
- [x] Add MUST NOT / Postflight Boundary section mirroring skill-cslib-implementation constraints *(completed)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` -- new file

**Verification**:
- File exists at `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
- SKILL.md contains `postflight "$task_number" pr_ready "$session_id"` (not `postflight implement`)
- SKILL.md frontmatter has `name: skill-pr-implementation`
- SKILL.md delegation context references `cslib-implementation-agent` as subagent_type
- SKILL.md includes PR-specific delegation fields (pr_branch_strategy, pr_description_path, ci_verification_mode)

---

### Phase 3: EXTENSION.md Documentation Update [COMPLETED]

**Goal**: Update EXTENSION.md to document the new `pr` task type routing and skill-to-agent mapping so the merged CLAUDE.md reflects the addition.

**Tasks**:
- [x] Add `pr` row to the Language Routing table in `.claude/extensions/cslib/EXTENSION.md` with research tools (WebSearch, WebFetch, Read, Bash) and implementation tools (Read, Write, Edit, Bash) *(completed)*
- [x] Add `skill-pr-implementation | cslib-implementation-agent | sonnet | PR branch/description preparation` row to the Skill-Agent Mapping table *(completed)*
- [x] Verify the EXTENSION.md is consistent with the updated manifest.json routing *(completed)*

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` -- add routing row and skill-agent mapping row

**Verification**:
- EXTENSION.md contains a `pr` row in the Language Routing table
- EXTENSION.md contains `skill-pr-implementation` in the Skill-Agent Mapping table
- Routing table matches manifest.json entries

## Testing & Validation

- [ ] `jq '.routing.implement.pr' .claude/extensions/cslib/manifest.json` returns `"skill-pr-implementation"`
- [ ] `jq '.routing.research.pr' .claude/extensions/cslib/manifest.json` returns `"skill-researcher"`
- [ ] `jq '.routing.plan.pr' .claude/extensions/cslib/manifest.json` returns `"skill-planner"`
- [ ] `jq '.provides.skills' .claude/extensions/cslib/manifest.json` includes `"skill-pr-implementation"`
- [ ] `bash .claude/scripts/command-route-skill.sh implement pr` resolves to `skill-pr-implementation`
- [ ] skill-pr-implementation/SKILL.md exists and contains `pr_ready` postflight call
- [ ] index-entries.json has `"pr"` in languages for pr-conventions.md, pr-description-format.md, ci-pipeline.md
- [ ] EXTENSION.md routing table and skill-agent table include `pr` entries
- [ ] No existing `cslib` routing is broken -- `bash .claude/scripts/command-route-skill.sh implement cslib` still returns `skill-cslib-implementation`

## Artifacts & Outputs

- `specs/673_pr_task_type_routing/plans/01_pr-task-type-plan.md` (this plan)
- `.claude/extensions/cslib/manifest.json` (modified)
- `.claude/extensions/cslib/index-entries.json` (modified)
- `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` (new)
- `.claude/extensions/cslib/EXTENSION.md` (modified)

## Rollback/Contingency

All changes are within the `.claude/extensions/cslib/` directory. To revert:
1. `git checkout HEAD -- .claude/extensions/cslib/manifest.json .claude/extensions/cslib/index-entries.json .claude/extensions/cslib/EXTENSION.md`
2. `rm -rf .claude/extensions/cslib/skills/skill-pr-implementation/`

No external dependencies or schema migrations are involved. The `pr_ready` status target and `pr-description-format.md` context file are already in place from tasks 671 and 672.
