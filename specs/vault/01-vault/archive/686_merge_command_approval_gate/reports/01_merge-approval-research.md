# Research Report: Task #686

**Task**: 686 - Add user approval gate to /merge command
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (merge.md, pr.md, tag.md, CLAUDE.md merge-sources)
**Artifacts**: specs/686_merge_command_approval_gate/reports/01_merge-approval-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/merge` command currently has no user confirmation before pushing to origin and creating a PR/MR -- it proceeds directly from branch validation (STEP 3) to push (STEP 4)
- A new STEP 3.5 should be inserted using the AskUserQuestion pattern from the cslib `/pr` command (lines 792-803)
- Both `.claude/commands/merge.md` and `.claude/extensions/core/commands/merge.md` are byte-identical and must both be updated
- The "user-only" prohibition pattern from `/tag` should be adapted for `/merge` to prevent autonomous agent invocation
- The merge-sources `claudemd.md` description for `/merge` should also be updated to note "user-only"

## Context & Scope

The task requires two changes to the `/merge` command:
1. Insert an AskUserQuestion approval gate between STEP 3 (validate branch) and STEP 4 (push to origin)
2. Add a prohibition note in the command header stating agents must never invoke `/merge` autonomously

## Findings

### 1. Current Command Flow

The current `/merge` command has 6 steps:

| Step | Action | Lines |
|------|--------|-------|
| STEP 1 | Parse Arguments | 55-81 |
| STEP 2 | Detect Platform | 85-118 |
| STEP 3 | Validate Branch | 122-145 |
| STEP 4 | Push to Origin | 149-174 |
| STEP 5 | Create PR/MR | 178-265 |
| STEP 6 | Report Results | 269-284 |

The transition from STEP 3 to STEP 4 is on line 145:
```
**If branch is valid**: **IMMEDIATELY CONTINUE** to STEP 4.
```

This is the exact insertion point. A new STEP 3.5 (or renumbered STEP 4 with subsequent steps renumbered) should go between lines 145 and 149.

### 2. AskUserQuestion Approval Pattern (from cslib /pr)

The cslib `/pr` command (lines 792-803) uses this pattern:

```json
{
  "question": "Submit this PR to leanprover/cslib?",
  "header": "Submit PR",
  "multiSelect": false,
  "options": [
    {"label": "Yes, submit the PR", "description": "Push branch and create PR on GitHub"},
    {"label": "Submit as draft", "description": "Create as draft PR (not ready for review)"},
    {"label": "Cancel -- do not submit", "description": "Abort without pushing or creating PR"}
  ]
}
```

Key elements of the pattern:
- A summary block is displayed BEFORE the AskUserQuestion call
- `multiSelect: false` for single-choice confirmation
- Three options: confirm, confirm-with-modification (draft), cancel
- Cancel response triggers a STOP with informational message
- The question is specific about what will happen

### 3. Data to Present Before Approval

At the insertion point (after STEP 3), the following data is already available:
- `current_branch` (from STEP 3's `git branch --show-current`)
- `target` (from STEP 1 argument parsing, default "main")
- `draft` (from STEP 1 argument parsing)
- `platform` (from STEP 2 detection -- "GitHub" or "GitLab")

Additional data that should be gathered at this point:
- **Commit count**: `git rev-list --count {target}..HEAD` -- number of commits to be included
- **Commit log**: `git log --oneline {target}..HEAD` -- one-line summary of each commit (capped at ~20 for readability)
- **PR type label**: "Pull Request" for GitHub, "Merge Request" for GitLab

### 4. Proposed New Step: STEP 4 (User Approval)

The insertion should:
1. Gather commit information via git commands
2. Display a summary block
3. Call AskUserQuestion
4. Handle the three responses (proceed, draft, cancel)

**Proposed summary display**:
```
Merge Summary
=============

Platform: {GitHub|GitLab}
Branch:   {current_branch} -> {target}
Draft:    {yes|no}
Commits:  {N}

{git log --oneline {target}..HEAD output}
```

**Proposed AskUserQuestion**:
```json
{
  "question": "Proceed with pushing branch and creating {PR_type}?",
  "header": "Confirm Merge",
  "multiSelect": false,
  "options": [
    {"label": "Yes, push and create {PR_type}", "description": "Push {current_branch} to origin and create {PR_type} targeting {target}"},
    {"label": "Submit as draft", "description": "Create as draft {PR_type} (not ready for review)"},
    {"label": "Cancel", "description": "Abort without pushing or creating {PR_type}"}
  ]
}
```

**Response handling**:
- "Yes, push and create...": continue to STEP 5 (push)
- "Submit as draft": set `draft=true`, continue to STEP 5
- "Cancel": STOP with message "Merge cancelled. No changes were pushed."

### 5. Step Renumbering

With the new step inserted, the numbering becomes:

| New # | Old # | Action |
|-------|-------|--------|
| STEP 1 | STEP 1 | Parse Arguments |
| STEP 2 | STEP 2 | Detect Platform |
| STEP 3 | STEP 3 | Validate Branch |
| **STEP 4** | **(new)** | **User Approval** |
| STEP 5 | STEP 4 | Push to Origin |
| STEP 6 | STEP 5 | Create PR/MR |
| STEP 7 | STEP 6 | Report Results |

All "IMMEDIATELY CONTINUE to STEP N" references must be updated accordingly:
- STEP 1: "IMMEDIATELY CONTINUE to STEP 2" (unchanged)
- STEP 2: "IMMEDIATELY CONTINUE to STEP 3" (unchanged)
- STEP 3: Change from "IMMEDIATELY CONTINUE to STEP 4" to "IMMEDIATELY CONTINUE to STEP 4"
- New STEP 4: "IMMEDIATELY CONTINUE to STEP 5"
- STEP 5 (old 4): Change "IMMEDIATELY CONTINUE to STEP 5" to "IMMEDIATELY CONTINUE to STEP 6"
- STEP 6 (old 5): Change "IMMEDIATELY CONTINUE to STEP 6" to "IMMEDIATELY CONTINUE to STEP 7"
- STEP 7 (old 6): No continuation (STOP)

### 6. Extension Core Copy

The file at `.claude/extensions/core/commands/merge.md` is **byte-identical** to `.claude/commands/merge.md` (confirmed via `diff` with no output). Both files must be updated with identical changes.

### 7. User-Only Prohibition Pattern

The `/tag` command establishes the user-only pattern with three components:

**Component A: Frontmatter description suffix**
```yaml
description: Create and push semantic version tags for CI/CD deployment (user-only)
```

**Component B: Header block in command body** (between `# Command: /tag` and the first section)
```markdown
**User Only**: YES - Agents MUST NOT invoke this command
```

**Component C: Dedicated "Agent Restrictions" section at bottom**
```markdown
## Agent Restrictions

**Agents MUST NOT invoke /tag**. This is enforced by:
- `user-only: true` in skill frontmatter
- Explicit prohibition in agent rules
- No agent mapping in CLAUDE.md
```

For `/merge`, the adaptation should be lighter since it is not a deployment command. The prohibition reason is different: merge/PR creation is a user-controlled decision about when code goes up for review, and agents should not autonomously create PRs. The suggested approach:

**Component A**: Update frontmatter description:
```yaml
description: Create a pull/merge request for the current branch (GitHub PR or GitLab MR) (user-only)
```

**Component B**: Add after the opening paragraph of the command:
```markdown
**User Only**: YES - Agents MUST NOT invoke this command autonomously. PR/MR creation is a user-controlled decision.
```

**Component C**: Add an "Agent Restrictions" section before "Related Commands":
```markdown
## Agent Restrictions

**Agents MUST NOT invoke /merge autonomously**. PR/MR creation timing and targeting are user-controlled decisions. This command requires explicit user invocation.
```

### 8. Additional Files to Update

Beyond the two merge.md copies, these files reference `/merge` and may need updates:

| File | Current Text | Needed Update |
|------|-------------|---------------|
| `.claude/extensions/core/merge-sources/claudemd.md` line 104 | `\| /merge \| /merge \| Create pull/merge request for current branch \|` | Add "(user-only)" to description |
| `.claude/extensions/core/README.md` (if it lists /merge) | Check for merge listing | Add "(user-only)" if listed |

Note: The generated `.claude/CLAUDE.md` will be auto-regenerated from merge-sources, so updating `claudemd.md` is the canonical fix. The skill-agent-mapping.md "User-Only Skills" table should also add `/merge`.

### 9. Skill Frontmatter Consideration

The `/tag` command references `user-only: true` in skill frontmatter. However, `/merge` does not use a skill -- it is a direct-execution command (no skill-tag equivalent). The command itself IS the execution definition. Therefore, the "user-only" enforcement for `/merge` is purely documentation-based:
- Frontmatter description suffix "(user-only)"
- Prohibition text in command body
- CLAUDE.md table annotation

There is no separate skill file to update.

## Recommendations

### Implementation Approach

1. **Insert new STEP 4 (User Approval)** between current STEP 3 and STEP 4
2. **Renumber** STEPs 4-6 to 5-7, updating all "IMMEDIATELY CONTINUE" references
3. **Add user-only prohibition** using the /tag pattern adapted for merge context
4. **Update both copies** (`.claude/commands/merge.md` and `.claude/extensions/core/commands/merge.md`) identically
5. **Update merge-sources/claudemd.md** to add "(user-only)" to the /merge description
6. **Update skill-agent-mapping.md** to list /merge under User-Only Skills

### Proposed New STEP 4 (Full Text)

```markdown
### STEP 4: User Approval

**EXECUTE NOW**: Gather commit information and present a summary for user approval before pushing.

```bash
commit_count=$(git rev-list --count {target}..HEAD 2>/dev/null || echo "unknown")
commit_log=$(git log --oneline {target}..HEAD 2>/dev/null | head -20)
```

Display the merge summary:
```
Merge Summary
=============

Platform: {GitHub|GitLab}
Branch:   {current_branch} -> {target}
Draft:    {yes|no}
Commits:  {commit_count}

{commit_log}
```

**Ask user** for approval via AskUserQuestion:
```json
{
  "question": "Proceed with pushing branch and creating {PR_type}?",
  "header": "Confirm Merge",
  "multiSelect": false,
  "options": [
    {"label": "Yes, push and create {PR_type}", "description": "Push {current_branch} to origin and create {PR_type} targeting {target}"},
    {"label": "Submit as draft", "description": "Create as draft {PR_type} (not ready for review)"},
    {"label": "Cancel", "description": "Abort without pushing or creating {PR_type}"}
  ]
}
```

**Response handling**:
- **"Yes, push and create..."**: **IMMEDIATELY CONTINUE** to STEP 5.
- **"Submit as draft"**: Set `draft=true`, then **IMMEDIATELY CONTINUE** to STEP 5.
- **"Cancel"**: Display "Merge cancelled. No changes were pushed." and **STOP**.

---
```

## Decisions

- Insert as a new step (STEP 4) with full renumbering rather than "STEP 3.5" -- consistent with existing integer step numbering
- Use the three-option pattern (yes/draft/cancel) from the cslib /pr command -- provides flexibility without complexity
- Cap commit log display at 20 lines to prevent overwhelming output for large branches
- Use `{target}..HEAD` for commit range (not `origin/{target}..HEAD`) since we have not fetched yet at this point
- The "user-only" marking is documentation-only since /merge has no separate skill file
- Both file copies must be updated identically

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Step renumbering introduces off-by-one in continuation references | Careful audit of all "IMMEDIATELY CONTINUE" lines -- there are exactly 5 to check |
| Extension core copy drifts from main copy | Update both files in the same commit |
| Agents ignore the user-only prohibition | Documentation-only enforcement; consider future hook-based enforcement if needed |
| `git rev-list --count` fails on shallow clones | Fallback `\|\| echo "unknown"` handles this gracefully |

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/.claude/commands/merge.md` (435 lines -- full command)
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/merge.md` (435 lines -- identical copy)
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` (lines 750-830 -- approval pattern)
- `/home/benjamin/.config/nvim/.claude/commands/tag.md` (lines 1-76 -- user-only pattern)
- `/home/benjamin/.config/nvim/.claude/context/reference/skill-agent-mapping.md` (lines 35-55 -- user-only skills)
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` (lines 460-490 -- AskUserQuestion format)

### Verification
- Confirmed merge.md copies are byte-identical via `diff` (no output)
- Confirmed tag.md copies are byte-identical via `diff` (no output)
- Confirmed /merge has no separate skill file (direct-execution command)
