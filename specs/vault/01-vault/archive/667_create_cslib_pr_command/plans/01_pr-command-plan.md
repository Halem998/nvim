# Implementation Plan: Task #667

- **Task**: 667 - Create cslib /pr command
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/667_create_cslib_pr_command/reports/01_pr-command-research.md
- **Artifacts**: plans/01_pr-command-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `/pr` command for the cslib extension that provides a complete PR workflow: accept input (task number, path, or description), create a feature branch, run the full 7-step CI pipeline, submit PR to upstream with user approval gates at each major decision point, and optionally merge back to main. The command is self-contained (no separate skill) because it requires 4+ interactive AskUserQuestion gates throughout execution.

### Research Integration

Key findings from research report:
- Architecture: command-only (no skill needed) due to multiple interactive gates
- Template: `/lean` command structure for multi-mode dispatch and AskUserQuestion pattern
- Fork model: `origin` = benbrastmckie/cslib, `upstream` = leanprover/cslib
- 7 CI steps with `--fix` variants for lint-style and shake
- PR title: conventional commit format (`feat|fix|doc|...[(area)]: description`)
- AI disclosure mandatory in PR body per CSLib and Mathlib policy

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Create `.claude/extensions/cslib/commands/pr.md` with full command logic
- Support three input modes: task number, file/directory path, free-text description
- Implement branch creation from upstream/main with user confirmation
- Run all 7 CI pipeline steps with auto-fix offers on failure
- Compose PR title (conventional commit format) and body (with AI disclosure) interactively
- Push to origin and create PR against upstream/main via `gh pr create`
- Offer optional merge-back of upstream/main to origin/main after PR submission
- Update cslib manifest.json to register the new command

**Non-Goals**:
- Creating a separate skill or agent for this command
- Handling multi-PR batch submissions
- Automating reviewer assignment
- Managing PR review feedback or CI results after submission

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Command file too long for reliable execution | H | L | Well-structured steps with clear EXECUTE/CONTINUE markers; tested template pattern from /lean |
| CI steps may change in future CSLib versions | M | M | Reference ci-pipeline.md context file; document steps so updates are isolated |
| `gh` CLI not authenticated in user environment | H | L | Add auth check at start with clear error message and instructions |
| Merge conflicts during merge-back | M | M | Check for conflicts before merge; abort with guidance if detected |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Create the /pr command file [COMPLETED]

**Goal**: Write the complete command file at `.claude/extensions/cslib/commands/pr.md` with all logic for the PR workflow.

**Tasks**:
- [ ] Create the `commands/` directory in the cslib extension if it does not exist
- [ ] Write frontmatter block (description, allowed-tools, argument-hint, model: opus)
- [ ] Write STEP 1: Parse Arguments -- extract input (task number, path, description) and flags (--draft, --dry-run, --branch)
- [ ] Write STEP 2: Resolve Input Mode -- detect integer (task), path-like, or free text; extract working description
- [ ] Write STEP 3: Environment Check -- verify `gh auth status`, verify git remotes (origin, upstream), verify working directory is cslib project
- [ ] Write STEP 4: Sync with upstream -- `git fetch upstream` and ensure main is up to date
- [ ] Write STEP 5: Branch Creation (AskUserQuestion) -- propose branch name from input, ask user to confirm/rename/cancel, create branch from upstream/main
- [ ] Write STEP 6: Stage Changes -- path mode: copy/stage files; task mode: cherry-pick or already on branch; description mode: verify user has changes staged
- [ ] Write STEP 7: Run CI Pipeline -- execute all 7 steps in order, report each result, offer `--fix` on failure for applicable steps, re-run after fix
- [ ] Write STEP 8: Select PR Title (AskUserQuestion) -- present conventional commit prefixes, prompt for optional area scope, compose title, confirm
- [ ] Write STEP 9: Compose PR Description -- fill template with summary, changes, CI checklist, AI disclosure; show draft; ask user to approve or edit
- [ ] Write STEP 10: Push and Create PR (AskUserQuestion) -- push to origin, `gh pr create --base main --repo leanprover/cslib`, display URL
- [ ] Write STEP 11: Offer Merge-Back (AskUserQuestion) -- ask if user wants to merge upstream/main back to origin/main after PR submission
- [ ] Write error handling section at bottom covering common failure modes

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Create new file (~350-400 lines)

**Verification**:
- File exists at correct path
- Frontmatter has description, allowed-tools, argument-hint, model fields
- All 11 steps are present with EXECUTE NOW and IMMEDIATELY CONTINUE markers
- AskUserQuestion gates at steps 5, 8, 9, 10, 11
- CI pipeline runs all 7 steps in correct order
- PR creation targets `leanprover/cslib` with `--base main`

---

### Phase 2: Update manifest.json [COMPLETED]

**Goal**: Register the new command in the cslib extension manifest so it is discoverable.

**Tasks**:
- [ ] Edit `.claude/extensions/cslib/manifest.json` to change `"commands": []` to `"commands": ["pr.md"]`

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - Update `provides.commands` array

**Verification**:
- `jq '.provides.commands' .claude/extensions/cslib/manifest.json` returns `["pr.md"]`

---

### Phase 3: Verification [COMPLETED]

**Goal**: Confirm the command file is well-formed and the manifest update is valid JSON.

**Tasks**:
- [ ] Validate manifest.json is valid JSON with `jq . .claude/extensions/cslib/manifest.json`
- [ ] Verify command file has correct frontmatter format (YAML delimited by `---`)
- [ ] Verify all AskUserQuestion calls use correct JSON structure with `question`, `header`, `options` fields
- [ ] Check that the 7 CI steps match the documented order in ci-pipeline.md
- [ ] Confirm `gh pr create` command uses `--repo leanprover/cslib --base main`

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- All checks pass without errors
- Command is ready for use

## Testing & Validation

- [ ] `jq . .claude/extensions/cslib/manifest.json` exits 0 (valid JSON)
- [ ] Command frontmatter parses correctly (three `---` delimited sections)
- [ ] Each AskUserQuestion uses the correct multi-option format
- [ ] CI pipeline steps match: build, checkInitImports, lint, lint-style, test, mk_all, shake
- [ ] PR target is `leanprover/cslib` with base `main`
- [ ] Branch naming follows `{type}/{description-slug}` pattern
- [ ] AI disclosure section is included in PR body template

## Artifacts & Outputs

- `.claude/extensions/cslib/commands/pr.md` - The command file
- `.claude/extensions/cslib/manifest.json` - Updated manifest with command registration

## Rollback/Contingency

- Remove `.claude/extensions/cslib/commands/pr.md` if command is not working
- Revert manifest.json `provides.commands` back to `[]`
- Both changes are isolated to the cslib extension and have no system-wide impact
