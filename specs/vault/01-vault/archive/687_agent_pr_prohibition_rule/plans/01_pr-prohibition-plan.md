# Implementation Plan: Create agent-level PR prohibition rule

- **Task**: 687 - Create agent-level PR prohibition rule
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/687_agent_pr_prohibition_rule/reports/01_pr-prohibition-research.md
- **Artifacts**: plans/01_pr-prohibition-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a universal auto-applied rule file at `.claude/rules/pr-prohibition.md` that explicitly forbids all agents from creating PRs, pushing to remotes, or invoking `/merge`. The rule directs agents to mark tasks as `[PR READY]` and let the user invoke `/merge` or `/pr` manually. A copy is synced to the extension core directory for distribution across projects.

### Research Integration

The research report confirmed that rules in `.claude/rules/` use YAML frontmatter with a `paths:` field for auto-application and require no registration in `index.json`. The path pattern `**/*` achieves universal application. Existing prohibition patterns ("MUST NOT", "FORBIDDEN") in `meta-builder-agent.md` and `skill-tag` provide precedent for the language style. The existing `git-workflow.md` prohibits `git push --force` but not regular `git push` or PR creation, confirming the gap this rule fills.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create a rule file that universally prohibits agents from creating PRs, pushing to remotes, or invoking `/merge`
- Follow established rule format conventions (YAML frontmatter, "MUST NOT" language)
- Sync the rule to the extension core copy for cross-project distribution

**Non-Goals**:
- Adding `user-only: true` to the `/merge` command frontmatter (separate task 686)
- Adding a PreToolUse hook to enforce at the tool-call level (separate task 684)
- Restricting `git push` in settings.json permissions (separate task 685)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rule not applied if `**/*` pattern fails to match | M | L | `**/*` is the broadest glob; Claude Code applies rules when any file matches |
| Agents ignore rule text | M | M | Strong "MUST NOT" language follows established codebase precedent; complemented by tasks 684-686 for enforcement layers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create PR prohibition rule [COMPLETED]

**Goal**: Create the rule file at `.claude/rules/pr-prohibition.md` with YAML frontmatter and three prohibition sections.

**Tasks**:
- [x] Create `.claude/rules/pr-prohibition.md` with YAML frontmatter `paths: "**/*"` *(completed)*
- [x] Add Scope section declaring universal application to all agents, skills, and automated operations *(completed)*
- [x] Add Prohibited Operations section with three subsections: PR/MR creation (`gh pr create`, `glab mr create`, API calls), pushing to remotes (`git push` all forms), and autonomous `/merge` invocation *(completed)*
- [x] Add Required Behavior section directing agents to mark task `[PR READY]` and wait for user *(completed)*
- [x] Add Rationale section explaining why these operations require human judgment *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/rules/pr-prohibition.md` - Create new file

**Verification**:
- File exists at `.claude/rules/pr-prohibition.md`
- YAML frontmatter contains `paths: "**/*"`
- All three prohibition categories are documented (PR creation, pushing, /merge invocation)
- Required behavior section specifies `[PR READY]` status marking

---

### Phase 2: Sync to extension core [COMPLETED]

**Goal**: Copy the rule to the extension core directory so it distributes to other projects via the extension loader.

**Tasks**:
- [x] Copy `.claude/rules/pr-prohibition.md` to `.claude/extensions/core/rules/pr-prohibition.md` *(completed)*
- [x] Verify both files have identical content *(completed)*

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/rules/pr-prohibition.md` - Create new file (copy of Phase 1 output)

**Verification**:
- File exists at `.claude/extensions/core/rules/pr-prohibition.md`
- Content is identical to `.claude/rules/pr-prohibition.md`

## Testing & Validation

- [ ] `.claude/rules/pr-prohibition.md` exists with valid YAML frontmatter
- [ ] `.claude/extensions/core/rules/pr-prohibition.md` is an identical copy
- [ ] Rule contains all three prohibited operations: PR creation, pushing, /merge invocation
- [ ] Rule specifies `[PR READY]` as the required agent behavior on implementation completion
- [ ] No other files were modified (this is a pure addition)

## Artifacts & Outputs

- `.claude/rules/pr-prohibition.md` - The auto-applied rule file
- `.claude/extensions/core/rules/pr-prohibition.md` - Extension core copy for distribution
- `specs/687_agent_pr_prohibition_rule/plans/01_pr-prohibition-plan.md` - This plan

## Rollback/Contingency

Delete both files to revert:
```bash
rm .claude/rules/pr-prohibition.md
rm .claude/extensions/core/rules/pr-prohibition.md
```
No other files are modified, so no further rollback is needed.
