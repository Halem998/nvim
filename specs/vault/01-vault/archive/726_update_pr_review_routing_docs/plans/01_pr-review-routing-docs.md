# Implementation Plan: Task #726

- **Task**: 726 - Update documentation and routing tables for pr-review workflow
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Tasks 722-725 (all completed)
- **Research Inputs**: specs/726_update_pr_review_routing_docs/reports/01_pr-review-routing-docs.md
- **Artifacts**: plans/01_pr-review-routing-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update two documentation files to register the new pr-review workflow created by tasks 722-725. The CSLib `EXTENSION.md` needs a missing skill-agent mapping row and a new Commands section. The `pr-prohibition.md` rule file needs a new subsection documenting how the `--review` workflow differs from the legacy pr-submission flow. No manifest.json or routing script changes are required -- routing is already operational.

### Research Integration

Research report (01_pr-review-routing-docs.md) confirmed that `manifest.json` routing is already correct, identified exactly two files needing updates, and provided draft content for each change. The core `CLAUDE.md` does not need direct edits (it is auto-generated from merge sources; the EXTENSION.md changes will propagate on next extension reload).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items directly relevant to this documentation task.

## Goals & Non-Goals

**Goals**:
- Add `skill-pr-review-implementation` / `pr-review-implementation-agent` row to EXTENSION.md Skill-Agent Mapping table
- Add a Commands section to EXTENSION.md documenting `/pr` usage modes (submission, --review, PR READY posting)
- Add a "PR Review Workflow" subsection to pr-prohibition.md explaining the end-to-end --review flow and how it coexists with the legacy pr-submission workflow

**Non-Goals**:
- Modifying manifest.json (routing already correct)
- Editing the generated `.claude/CLAUDE.md` directly (EXTENSION.md is the merge source)
- Creating new context files or patterns (recommendation from research deferred to future task)
- Changing any skill or agent definitions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| EXTENSION.md table formatting breaks on merge | L | L | Verify table alignment with pipe characters after edit |
| pr-prohibition.md edits confuse existing workflow documentation | M | L | Add new subsection rather than modifying existing CSLib section |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update EXTENSION.md [COMPLETED]

**Goal**: Add the missing skill-agent mapping row and a new Commands section to the CSLib EXTENSION.md.

**Tasks**:
- [x] Add `skill-pr-review-implementation` row to the Skill-Agent Mapping table (after line 21, the `skill-pr-review-research` row) *(completed)*
- [x] Add a new `### Commands` section after the CI Verification Pipeline section (after line 60) documenting three `/pr` usage modes *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/EXTENSION.md` - Add skill-agent row and Commands section

**Concrete content to add**:

Change A -- Insert after the `skill-pr-review-research` row (line 21):
```
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md and zulip-response.md for pr-type review tasks; falls back to legacy pr-description workflow when sources are absent |
```

Change B -- Append after line 60 (end of CI Verification Pipeline section):
```markdown

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/pr` | `/pr <task_number\|path\|description> [--draft] [--dry-run]` | Submit CSLib PR: create branch, run CI, create PR on leanprover/cslib (user-only) |
| `/pr` | `/pr --review <sources...>` | Create pr-type review task from GitHub PR URLs, Zulip URLs, or descriptions |
| `/pr` | `/pr N` (when task is [PR READY] with sources) | Push changes, post GitHub PR comment, optionally send Zulip message |
```

**Verification**:
- EXTENSION.md table renders correctly (pipe alignment, no broken rows)
- Commands section follows the same table format used in core CLAUDE.md command reference
- `skill-pr-review-implementation` row appears after `skill-pr-review-research` in the table

---

### Phase 2: Update pr-prohibition.md [COMPLETED]

**Goal**: Add a new subsection documenting the pr-review workflow (`/pr --review`) and how it coexists with the legacy pr-submission workflow.

**Tasks**:
- [x] Add a new `## CSLib Extension: /pr --review Workflow` section after the existing `## CSLib Extension: /pr Command` section (after line 61) *(completed)*
- [x] Include the end-to-end flow: `/pr --review` -> `/research N` -> `/implement N` -> `/pr N` (posting) *(completed)*
- [x] Include a coexistence table distinguishing pr-submission (no sources) from pr-review (sources present) *(completed)*
- [x] Reaffirm that the push/PR prohibition still applies to both workflows *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/rules/pr-prohibition.md` - Add pr-review workflow subsection

**Concrete content to add** -- Append after line 61 (end of file):
```markdown

## CSLib Extension: /pr --review Workflow

The `--review` flag to `/pr` creates tasks with `task_type: "pr"` and a `sources` array in state.json. These tasks use the pr-review skills:

1. **`/pr --review <sources...>`** (user-invoked command): Creates a pr-type task with sources (GitHub PR URLs, Zulip thread URLs, or free-text descriptions). This is the ONLY way to create pr-review tasks.

2. **`/research N`** (pr-type task): Routes to `skill-pr-review-research`, which fetches GitHub PR data (reviews, comments, inline comments) and optionally Zulip thread data. Produces a research report.

3. **`/implement N`** (pr-type task with sources): Routes to `skill-pr-review-implementation`, which dispatches to `pr-review-implementation-agent`. The agent composes `pr-response.md` (GitHub PR comment) and optionally `zulip-response.md` (Zulip thread message). Transitions task to `[PR READY]`.

4. **`/pr N`** (when task is [PR READY] with sources): STEP 0.5 handles the posting workflow -- commits/pushes any local changes, posts `pr-response.md` as a GitHub PR comment, optionally sends `zulip-response.md` to Zulip. Transitions task to `[COMPLETED]`.

### Distinguishing pr-submission vs pr-review

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources` absent or empty | pr-submission (legacy): `/implement` produces pr-description.md |
| `task_type: "pr"`, `sources` present | pr-review: `/implement` produces pr-response.md + zulip-response.md |

The dispatch within `skill-pr-review-implementation` checks for sources and forks to either the review path or the legacy pr-description path.

The prohibition on agent-created PRs and agent pushes still applies to both workflows. Only `/pr N` (user-invoked) performs git push and GitHub API operations.
```

**Verification**:
- New section is clearly separated from the existing CSLib section with a `##` heading
- Coexistence table accurately reflects the sources-based dispatch logic
- Prohibition reaffirmation is present at the end

## Testing & Validation

- [x] Verify EXTENSION.md Skill-Agent Mapping table has 7 rows (was 6, now includes `skill-pr-review-implementation`) *(completed)*
- [x] Verify EXTENSION.md Commands section has 3 `/pr` usage rows *(completed)*
- [x] Verify pr-prohibition.md has two CSLib sections: the original `/pr Command` and the new `/pr --review Workflow` *(completed)*
- [x] Verify the coexistence table in pr-prohibition.md matches the research report's analysis *(completed)*
- [x] Grep for "skill-pr-review-implementation" in EXTENSION.md to confirm the row was added *(completed)*

## Artifacts & Outputs

- `specs/726_update_pr_review_routing_docs/plans/01_pr-review-routing-docs.md` (this plan)
- `.claude/extensions/cslib/EXTENSION.md` (modified)
- `.claude/rules/pr-prohibition.md` (modified)

## Rollback/Contingency

Both files are under git version control. If changes are incorrect:
```bash
git checkout -- .claude/extensions/cslib/EXTENSION.md .claude/rules/pr-prohibition.md
```
