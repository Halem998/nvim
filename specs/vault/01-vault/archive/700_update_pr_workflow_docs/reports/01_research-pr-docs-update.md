# Research Report: Task #700

**Task**: 700 - Update PR workflow documentation
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: ~45 minutes (file audit and content analysis)
**Dependencies**: Tasks 698 (skill-pr-implementation revision), 699 (/pr command revision) - both complete
**Sources/Inputs**: Codebase (cslib extension files, core rules, project rules)
**Artifacts**: specs/700_update_pr_workflow_docs/reports/01_research-pr-docs-update.md
**Standards**: report-format.md

---

## Executive Summary

- Two files need meaningful text changes: EXTENSION.md (skill table description) and the pr-prohibition.md rule files (new workflow reference)
- The pr-prohibition.md rule has two copies that are in sync: the core extension source and the project-level copy; both need updating
- The manifest.json routing entries for the `pr` task type are correct and do not need changes
- The pr.md command file has two stale references to "branch already exists (created by skill-pr-implementation)" that should be cleaned up since skill-pr-implementation no longer creates branches
- The cslib-implementation-agent.md is already correctly updated: it correctly describes PR Description Mode as "skip CI, only produce pr-description.md"
- No other context files reference the old combined workflow

---

## Context & Scope

Tasks 698 and 699 have already split the PR workflow into two responsibilities:
- **skill-pr-implementation**: produces `pr-description.md` only (reads git diff, composes description, transitions task to `[PR READY]`)
- **/pr command**: the single entry point for branch creation, cache fetch, CI pipeline (7 steps), PR submission

The current documentation in EXTENSION.md still describes skill-pr-implementation as handling "PR branch/description preparation", which is misleading — it no longer creates branches. The pr-prohibition.md rule tells agents to wait for `/merge`, which is for the nvim project, but the cslib project uses `/pr` instead. The prohibition rule should reference the new two-step cslib workflow.

---

## Findings

### Codebase Patterns

#### Files Audited

| File | Status | Action Needed |
|------|--------|---------------|
| `.claude/extensions/cslib/EXTENSION.md` | Stale | Update skill table description for skill-pr-implementation |
| `.claude/extensions/core/rules/pr-prohibition.md` | Stale | Add cslib-specific workflow note |
| `.claude/rules/pr-prohibition.md` | Stale (copy of above) | Sync with core extension copy |
| `.claude/extensions/cslib/manifest.json` | Correct | No changes needed |
| `.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md` | Already updated by task 698 | No changes needed |
| `.claude/extensions/cslib/commands/pr.md` | Two stale references | Clean up references to skill-pr-implementation creating branches |
| `.claude/extensions/cslib/agents/cslib-implementation-agent.md` | Already correct | No changes needed |
| `.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` | No workflow refs | No changes needed |
| `.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md` | No workflow refs | No changes needed |
| `.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md` | No workflow refs | No changes needed |
| `.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md` | No workflow refs | No changes needed |

---

### File-by-File Change Analysis

#### 1. `.claude/extensions/cslib/EXTENSION.md` — Skill Table

**Current content (line 18)**:
```
| skill-pr-implementation | cslib-implementation-agent | sonnet | PR branch/description preparation, transitions task to [PR READY] |
```

**Problem**: "PR branch/description preparation" implies skill-pr-implementation still creates branches. After task 698, it only produces `pr-description.md`.

**Needed content**:
```
| skill-pr-implementation | cslib-implementation-agent | sonnet | PR description preparation only -- produces pr-description.md, transitions task to [PR READY]; branch creation and CI handled by /pr |
```

---

#### 2. `.claude/extensions/core/rules/pr-prohibition.md` — Rule File (Source)

**Current content**: The "Required Behavior" section says agents must wait for the user to invoke `/merge` or manually create the PR. This is accurate for the general nvim project, but does not mention the cslib-specific two-step workflow (skill-pr-implementation -> /pr).

**Problem**: An agent working on a cslib `pr` task type might correctly transition to `[PR READY]` but the rule's "Required Behavior" section does not explain that for cslib tasks, the user should run `/pr {N}` rather than `/merge`. This creates a documentation gap.

**Needed change**: Add a "CSLib Exception: /pr Command" section at the end of the rule that explains the cslib-specific two-step flow. The core prohibition (no agent-created PRs, no agent pushes) stays fully intact; this addition only clarifies which user command to run for cslib tasks vs. general nvim tasks.

**Proposed addition after the "Rationale" section**:
```markdown
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
```

---

#### 3. `.claude/rules/pr-prohibition.md` — Project-Level Copy

This file is an exact copy of `.claude/extensions/core/rules/pr-prohibition.md`. It must be kept in sync. After updating the core extension copy, the same addition must be applied here.

**Note on sync mechanism**: The `manifest.json` for the cslib extension does not list `pr-prohibition.md` as a rule it provides (it provides `cslib.md` only). The pr-prohibition rule comes from the `core` extension. The project-level copy at `.claude/rules/pr-prohibition.md` must be manually updated to match.

---

#### 4. `.claude/extensions/cslib/commands/pr.md` — Stale Branch References

The pr.md command file contains two passages that reference skill-pr-implementation as if it created branches (this was the old behavior before task 699 reorganized the workflow):

**Line 271-275 (current)**:
```
**Task mode** (`input_mode="task"`): If a `feat/` branch matching the task slug already exists
locally (as would be created by `skill-pr-implementation`), offer to reuse it:
```bash
if [ -n "$local_exists" ] || [ -n "$remote_exists" ]; then
  echo "Branch '$proposed_branch' already exists (created by skill-pr-implementation)."
```

**Problem**: After task 698, skill-pr-implementation no longer creates branches. These references imply it did. The branch might exist for other reasons (user created it manually, prior /pr run, etc.) but not because skill-pr-implementation made it.

**Lines 286-287 (current)**:
```json
{"label": "Reuse existing '{proposed_branch}'", "description": "Switch to the existing branch (if created by skill-pr-implementation)"},
```

**Needed changes**:
- Line 272: Change "as would be created by `skill-pr-implementation`" to "from a previous /pr run or manual branch creation"
- Line 274: Change "Branch '$proposed_branch' already exists (created by skill-pr-implementation)." to "Branch '$proposed_branch' already exists."
- Line 287: Change "(if created by skill-pr-implementation)" to "(if previously created)"

---

### Manifest.json Routing Verification

**Current routing in manifest.json**:
```json
"routing": {
  "research": { "pr": "skill-researcher" },
  "plan": { "pr": "skill-planner" },
  "implement": { "pr": "skill-pr-implementation" }
},
"routing_hard": {
  "research": { "pr": "skill-researcher-hard" },
  "plan": { "pr": "skill-planner-hard" },
  "implement": { "pr": "skill-implementer-hard" }
}
```

**Assessment**: The routing is correct. `implement` for `pr` task type still routes to `skill-pr-implementation`, which is the right skill to call for composing `pr-description.md`. The `/pr` command is not invoked through the routing table — it is a user command. No changes needed.

---

### Agent File Verification

**`cslib-implementation-agent.md`** already correctly implements the new separation:

The "Final Verification Stage" section includes a "PR Description Mode (Skip Verification)" subsection that correctly says:
- Detection: `task_type == "pr"` in delegation context OR `delegation_path` contains `"skill-pr-implementation"`
- Skip CSLib CI Pipeline entirely (branch creation and CI are handled by the `/pr` command)
- Outputs: `pr-description.md` and `.return-meta.json` only

This agent file was already updated as part of task 698. **No changes needed.**

---

### External Resources

No web research was needed. All findings are from codebase inspection.

---

## Recommendations

### Priority Order for Implementation

1. **EXTENSION.md skill table** (highest priority — directly misleading to agents loading the table)
2. **pr-prohibition.md core extension copy** (adds cslib workflow context)
3. **pr-prohibition.md project-level copy** (keep in sync with core)
4. **pr.md command file** (minor stale references, lower priority but still confusing)

### Implementation Notes

- The pr-prohibition.md update should ADD content, not replace the existing prohibition. The core prohibition (agents cannot push or create PRs) is fully accurate and must remain unchanged. The addition is purely a "CSLib Exception" subsection explaining which user command to use.
- The EXTENSION.md change is a single line in the skill table.
- The pr.md changes are 3 small string replacements.
- All changes are non-breaking (documentation-only).

---

## Decisions

- The manifest.json routing entries are correct and do not need updating.
- The cslib-implementation-agent.md is already accurate and does not need changes.
- The core pr-prohibition.md and project-level copy need to stay in sync — both must receive the same addition.
- The pr.md stale branch references should be cleaned up to avoid future confusion, even though they do not affect behavior.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| pr-prohibition.md core/project copies getting out of sync | Update both files in the same implementation phase |
| EXTENSION.md description becoming too long for the table | Keep it to one line; use "only" keyword to make the boundary clear |
| pr.md changes accidentally altering logic | These are comment/string changes only, not code changes |

---

## Context Extension Recommendations

- **Topic**: CSLib PR workflow two-step separation
- **Gap**: No context file explicitly documents the full two-step flow (skill-pr-implementation -> /pr) as a unit. The pr-prohibition.md update will partially fill this gap.
- **Recommendation**: The pr-prohibition.md "CSLib Extension" addition serves as the canonical documentation for this separation. No additional context file is needed.

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/EXTENSION.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-pr-implementation/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/core/rules/pr-prohibition.md`
- `/home/benjamin/.config/nvim/.claude/rules/pr-prohibition.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-description-format.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/tools/build-cache-strategy.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/domain/contributing-standards.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/rules/cslib.md`

### Search Queries Used

- `grep -r "skill-pr-implementation"` across `.claude/`
- `grep -r "branch creation|create.*branch|CI.*pipeline|PR.*branch"` across cslib context
- `find` for all `pr-prohibition.md` files
- Manual line-by-line audit of EXTENSION.md, manifest.json, pr.md, cslib-implementation-agent.md
