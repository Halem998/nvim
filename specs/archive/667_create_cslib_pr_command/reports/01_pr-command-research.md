# Research Report: Task #667

**Task**: 667 - Create cslib /pr command
**Started**: 2026-06-11T00:00:00Z
**Completed**: 2026-06-11T00:10:00Z
**Effort**: ~60 minutes
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/extensions/lean/commands/lake.md`
- `/home/benjamin/.config/nvim/.claude/extensions/lean/commands/lean.md`
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/merge.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md`
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md`
- Git inspection of `/home/benjamin/Projects/cslib`
**Artifacts**: `specs/667_create_cslib_pr_command/reports/01_pr-command-research.md`
**Standards**: report-format.md

---

## Executive Summary

- The `/pr` command should be **self-contained** within the command file (no separate skill warranted) because it requires multiple interactive `AskUserQuestion` gates throughout execution; the `/lean` command is the best structural template
- The CSLib CI pipeline has **7 ordered steps**; the command must run all of them before allowing PR submission
- CSLib uses a **fork model**: `origin` = `benbrastmckie/cslib` (fork), `upstream` = `leanprover/cslib`; PRs go to `upstream/main` via `gh pr create --base main --repo leanprover/cslib`
- PR titles must begin with `feat|fix|doc|style|refactor|test|chore|perf[(<area>)]:` — AI disclosure in body is mandatory per CSLib and Mathlib policy
- Recommended architecture: **command-only** (no `skill-cslib-pr` needed), three input modes (task number, path, description), with branch creation, CI run, PR submission, and optional merge-back as sequential user-approved stages

---

## Context & Scope

**What was researched**:

1. Existing command structure and format conventions in the lean extension (`/lake`, `/lean`) and the core `/merge` command
2. CSLib CONTRIBUTING.md for PR title format, review process, AI disclosure, and CI requirements
3. CSLib extension existing structure (manifest.json, skills, agents, context files)
4. Git remote configuration of the local CSLib project
5. CI pipeline documentation from the cslib extension context files

**Constraints**:
- Command file must live at `.claude/extensions/cslib/commands/pr.md`
- Must use `AskUserQuestion` for all user approval gates (not proceed blindly)
- Must run all 7 CI steps before allowing PR submission
- Must conform to CSLib PR title format and include AI disclosure
- Must handle three distinct input modes

---

## Findings

### Codebase Patterns

#### Command File Format

Commands in this system use a YAML frontmatter header followed by a Markdown body:

```yaml
---
description: One-line description
allowed-tools: Bash(git:*), Bash(gh:*), AskUserQuestion, Read, Write, Edit
argument-hint: "[mode] [--options]"
---
```

The body uses a step-by-step imperative style with explicit `**EXECUTE NOW**` directives and `**IMMEDIATELY CONTINUE**` signals to prevent the LLM from stopping early. Each STEP is numbered and has clear stop/continue conditions.

**Best template**: `/lean` command — it has:
- Multi-mode dispatch (`check`, `upgrade`, `rollback`)
- `AskUserQuestion` for confirmation before destructive operations
- Backup creation before changes
- Clear step progression with rollback guidance

**Secondary reference**: `/merge` command — it has:
- Git platform detection
- Push and PR creation via `gh pr create`
- Error recovery patterns

#### AskUserQuestion Pattern

```json
{
  "question": "Question text?",
  "header": "Section Header",
  "multiSelect": false,
  "options": [
    {"label": "Yes, proceed", "description": "Detailed explanation"},
    {"label": "No, cancel", "description": "Abort the operation"}
  ]
}
```

For PR title selection, a `multiSelect: false` question with prefix options listed works best.

#### CSLib Extension Structure

The cslib extension already provides:
- Two agents: `cslib-research-agent`, `cslib-implementation-agent`
- Two skills: `skill-cslib-research`, `skill-cslib-implementation`
- Context files for CI pipeline, PR conventions, lake commands, linters
- **No commands currently** (`"commands": []` in manifest.json)

The manifest `provides.commands` field is an empty array — this needs to be updated.

### CSLib Git Workflow

From inspecting `/home/benjamin/Projects/cslib`:

```
origin   -> git@github.com:benbrastmckie/cslib.git  (fork)
upstream -> https://github.com/leanprover/cslib.git  (main repo)
```

**Active branches on fork**:
- `main` (default)
- `pr1/foundations-logic` (example feature branch naming)

**Branch naming convention observed**: `{type}/{scope}` (e.g., `pr1/foundations-logic`)

**PR submission flow**:
1. Create feature branch on fork: `git checkout -b feat/my-feature`
2. Make changes, commit
3. Push to `origin`: `git push -u origin HEAD`
4. Create PR against upstream: `gh pr create --base main --repo leanprover/cslib`

**For merge-back after upstream merges**: `git checkout main && git pull upstream main && git push origin main`

### CI Pipeline (7 Steps)

From `ci-pipeline.md` and `CONTRIBUTING.md`:

| Step | Command | Always Required |
|------|---------|----------------|
| 1 | `lake build` | Yes |
| 2 | `lake exe checkInitImports` | Yes |
| 3 | `lake lint` | Yes |
| 4 | `lake exe lint-style` | Yes |
| 5 | `lake test` | Yes |
| 6 | `lake exe mk_all --module` | Only when adding new files |
| 7 | `lake shake --add-public --keep-implied --keep-prefix` | Yes (before PR) |

Note: Steps 6 and 7 have auto-fix variants (`--fix`) that can be offered as options.

### PR Title Format

```
feat|fix|doc|style|refactor|test|chore|perf[(<area>)]: <description>
```

Examples:
- `feat(Logics): prove completeness for modal logic K`
- `fix: correct alpha-equivalence definition for pi-calculus`
- `doc(Foundations/Syntax): add docstrings to HasAlphaEquiv`

### PR Description Template (from pr-conventions.md)

```markdown
## Summary

Brief description of what this PR adds or fixes.

## Changes

- List of specific changes made

## CI

- [ ] `lake build` passes
- [ ] `lake exe checkInitImports` passes
- [ ] `lake lint` passes
- [ ] `lake exe lint-style` passes
- [ ] `lake test` passes

## AI Disclosure (if applicable)

Describe any AI tool usage here.
```

### Input Mode Analysis

The task description specifies three input types: task number, path, or description. Analysis:

| Input Mode | Detection | Behavior |
|-----------|-----------|----------|
| Task number (e.g., `667`) | Pure integer argument | Read task from `specs/state.json`, extract description |
| Path (file or dir) | Starts with `/` or `./`, or contains `/` | Stage the path's changes, infer description from diff |
| Description (free text) | Everything else | Use as-is for branch name and PR title prefix |

For **cherry-pick** use case: this refers to taking work from a feature branch and moving it to a clean PR branch, not necessarily `git cherry-pick`. The workflow is:
1. Identify what changed (from input)
2. Create a fresh branch from `main`
3. Stage the relevant changes (copy files or cherry-pick specific commits)
4. Run CI, submit PR

### Architecture Decision: Command vs Command+Skill

**Decision: Command-only (no separate skill)**

Reasoning:
1. The command has heavy interactivity — `AskUserQuestion` calls at 4+ points:
   - Confirm branch creation
   - Select PR title type
   - Approve PR submission
   - Approve merge-back
2. Skills are designed for non-interactive delegation to subagents; this workflow needs the user present at each gate
3. The `/lean` command (which has AskUserQuestion for confirmation) is self-contained and serves as the template
4. Complexity is manageable in a single well-structured command file (~300-400 lines)

**Exception**: If in the future a "run CI only" workflow is needed, a `skill-cslib-ci` skill could be extracted. But for now, the command handles everything.

---

## Decisions

1. **Architecture**: Self-contained command file at `.claude/extensions/cslib/commands/pr.md`; no separate skill needed
2. **Manifest update**: `provides.commands` array must be updated from `[]` to `["pr.md"]`
3. **Input dispatch**: Parse first argument — integer → task mode, path-like → path mode, text → description mode
4. **Branch naming**: `{type}/{description-slug}` derived from the conventional commit prefix and description
5. **CI requirement**: All 7 steps required; `mk_all` step prompted only if new files detected; `--fix` variants offered when issues found
6. **PR target**: Always `upstream/main` (leanprover/cslib) via `gh pr create --base main --repo leanprover/cslib`
7. **AI disclosure**: Always include a standard AI disclosure section in the PR body
8. **Merge-back**: Offer optional merge-back after confirming PR was submitted; merges `upstream/main` back to `origin/main`
9. **Divergence handling**: Before merge-back, always `git fetch upstream` and check for conflicts

---

## Design: Command Steps Outline

### STEP 1: Parse Arguments
- Extract input (task number, path, or free-text description)
- Extract flags: `--draft`, `--dry-run`, `--skip-ci`, `--branch BRANCH`

### STEP 2: Resolve Input Mode
- Integer → read from `specs/state.json`
- Path → describe what was changed
- Text → use as working description

### STEP 3: Confirm Branch Creation (AskUserQuestion)
- Show proposed branch name (e.g., `feat/my-feature`)
- Ask user to confirm or provide custom name
- Options: confirm, rename, cancel

### STEP 4: Create Feature Branch
- `git checkout main && git pull upstream main`
- `git checkout -b {branch-name}`
- Apply changes (path mode: stage files; task mode: already on branch; description mode: user is expected to have made changes)

### STEP 5: Run CI Pipeline
- Run all 7 steps in order
- Report result of each step
- Stop if any step fails (offer to auto-fix where available, then re-run)

### STEP 6: Select PR Title (AskUserQuestion)
- Show conventional commit prefix options (`feat`, `fix`, `doc`, `style`, `refactor`, `test`, `chore`, `perf`)
- Prompt for optional area qualifier (e.g., `Logics`, `Foundations`)
- Prompt for description text
- Display final composed title for confirmation

### STEP 7: Compose PR Description
- Fill in template with summary, changes list, CI checklist, AI disclosure
- AskUserQuestion: approve or edit (show draft, ask confirm)

### STEP 8: Push and Create PR
- `git push -u origin HEAD`
- `gh pr create --base main --repo leanprover/cslib --title "..." --body "..."`
- Display PR URL

### STEP 9: Offer Merge-Back (AskUserQuestion)
- Ask if user wants to merge upstream/main back to origin/main
- If yes: `git fetch upstream && git checkout main && git merge upstream/main && git push origin main`

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| CI step fails during execution | Stop at failed step, show output, offer `--fix` option, re-run |
| Main has diverged during PR process | Always `git fetch upstream main` before merge-back |
| User provides conflicting branch name | Check if branch exists, offer rename |
| `gh` CLI not authenticated | Show `gh auth status` output, provide auth instructions |
| PR already exists for branch | `gh` CLI gracefully shows existing PR URL |
| Step 6 (mk_all) is skipped unnecessarily | Detect new `.lean` files in diff to decide if step 6 is needed |
| Dry-run mode confusion | Make `--dry-run` show exactly what would happen without executing |

---

## Context Extension Recommendations

The cslib extension already has good coverage. One gap identified:

- **Topic**: CSLib git fork workflow
- **Gap**: No documentation of the fork-based contribution model (origin = fork, upstream = canonical repo) and how to submit PRs to upstream
- **Recommendation**: Add `tools/git-workflow.md` to `context/project/cslib/tools/` documenting the fork model and `gh` CLI usage for PR submission

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/extensions/lean/commands/lake.md` - 322 lines, CI repair loop pattern
- `/home/benjamin/.config/nvim/.claude/extensions/lean/commands/lean.md` - 354 lines, AskUserQuestion pattern template
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/merge.md` - 434 lines, gh pr create pattern
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json` - extension structure
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/ci-pipeline.md` - 7-step pipeline
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/context/project/cslib/standards/pr-conventions.md` - PR title format, AI disclosure
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` - cslib skill pattern
- `/home/benjamin/Projects/cslib/CONTRIBUTING.md` - full contribution standards

### Key Bash Commands Used

```bash
find /home/benjamin/.config/nvim/.claude/extensions/lean/commands/ -type f
find /home/benjamin/.config/nvim/.claude/extensions/cslib/ -type f
cd /home/benjamin/Projects/cslib && git remote -v
cd /home/benjamin/Projects/cslib && git branch -a
```
