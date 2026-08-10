# Implementation Plan: Add model: opus to OpenCode Command Frontmatter

- **Task**: 521 - Add model: opus to OpenCode command frontmatter
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/521_add_model_opus_opencode_commands/reports/01_command-frontmatter-audit.md
- **Artifacts**: plans/01_add-model-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `model: opus` to the YAML frontmatter of all `.opencode/commands/*.md` files. Per the agent frontmatter standard, `model: opus` ensures highest reasoning quality. Currently, zero command files declare this field. This plan covers 17 command files with frontmatter, the command template, the creating-commands guide, the agent frontmatter standard, and all extension mirror commands.

### Research Integration

The research report identified 17 command files with YAML frontmatter missing the `model` field entirely. The command template and creating-commands guide treat `model` as optional. Extension mirrors in `.opencode/extensions/core/commands/` duplicate all command files and must be updated in parallel.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `model: opus` to all 17 command files with YAML frontmatter
- Update command template to include `model: opus` as required
- Update creating-commands guide to mandate `model: opus`
- Add cross-reference in agent frontmatter standard for commands
- Update all extension mirror commands in parallel
- Verify all commands declare `model: opus`

**Non-Goals**:
- Modify `commands/README.md` (no frontmatter, documentation only)
- Change runtime model selection logic in orchestrator
- Remove existing `--fast`, `--haiku`, `--sonnet` flags from argument hints

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Orchestrator uses command frontmatter for model selection | Medium | Low | Verify orchestrator reads agent frontmatter, not command frontmatter |
| Some commands may legitimately need lighter models | Low | Low | Document that runtime flags override frontmatter defaults |
| Extension mirrors get out of sync | Medium | Medium | Update extension mirrors in same commit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Standards and Templates [COMPLETED]

**Goal**: Update documentation that governs how commands are created.

**Tasks**:
- [ ] `.opencode/context/templates/command-template.md`
  - Add `model: opus` to frontmatter example after `description` line
- [ ] `.opencode/docs/guides/creating-commands.md`
  - Update frontmatter table: change `model` from "No" (optional) to "Yes" (required)
  - Update description: `Preferred model: opus (all commands use opus)`
- [ ] `.opencode/docs/reference/standards/agent-frontmatter-standard.md`
  - Add "Commands" subsection after line 175 stating all command files must declare `model: opus`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/context/templates/command-template.md`
- `.opencode/docs/guides/creating-commands.md`
- `.opencode/docs/reference/standards/agent-frontmatter-standard.md`

**Verification**:
- `grep -A 5 "^---$" .opencode/context/templates/command-template.md` shows `model: opus`
- `grep "model" .opencode/docs/guides/creating-commands.md` shows required status

---

### Phase 2: Update Core Command Files [COMPLETED]

**Goal**: Add `model: opus` to all 17 command files in `.opencode/commands/`.

**Tasks**:

Insert `model: opus` after the `description` line in each file's YAML frontmatter:

- [ ] `.opencode/commands/research.md` (add after line 2)
- [ ] `.opencode/commands/plan.md` (add after line 2)
- [ ] `.opencode/commands/implement.md` (add after line 2)
- [ ] `.opencode/commands/review.md` (add after line 2)
- [ ] `.opencode/commands/errors.md` (add after line 2)
- [ ] `.opencode/commands/refresh.md` (add after line 2)
- [ ] `.opencode/commands/todo.md` (add after line 2)
- [ ] `.opencode/commands/meta.md` (add after line 2)
- [ ] `.opencode/commands/revise.md` (add after line 2)
- [ ] `.opencode/commands/merge.md` (add after line 2)
- [ ] `.opencode/commands/project-overview.md` (add after line 2)
- [ ] `.opencode/commands/spawn.md` (add after line 2)
- [ ] `.opencode/commands/tag.md` (add after line 2)
- [ ] `.opencode/commands/task.md` (add after line 2)
- [ ] `.opencode/commands/learn.md` (add after line 2)
- [ ] `.opencode/commands/distill.md` (add after line 2)
- [ ] `.opencode/commands/fix-it.md` (add after line 2)

**Exact insertion pattern**:
```yaml
---
description: {existing description}
model: opus
{remaining frontmatter fields}
---
```

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- All 17 `.opencode/commands/*.md` files listed above

**Verification**:
- Run `grep "model:" .opencode/commands/*.md` - should show 17 matches
- Run `grep -L "model:" .opencode/commands/*.md` - should only show `README.md`

---

### Phase 3: Update Extension Mirror Commands [COMPLETED]

**Goal**: Apply identical `model: opus` additions to all extension mirror command files.

**Tasks**:
- [ ] `.opencode/extensions/core/commands/research.md`
- [ ] `.opencode/extensions/core/commands/plan.md`
- [ ] `.opencode/extensions/core/commands/implement.md`
- [ ] `.opencode/extensions/core/commands/review.md`
- [ ] `.opencode/extensions/core/commands/errors.md`
- [ ] `.opencode/extensions/core/commands/refresh.md`
- [ ] `.opencode/extensions/core/commands/todo.md`
- [ ] `.opencode/extensions/core/commands/meta.md`
- [ ] `.opencode/extensions/core/commands/revise.md`
- [ ] `.opencode/extensions/core/commands/merge.md`
- [ ] `.opencode/extensions/core/commands/project-overview.md`
- [ ] `.opencode/extensions/core/commands/spawn.md`
- [ ] `.opencode/extensions/core/commands/tag.md`
- [ ] `.opencode/extensions/core/commands/task.md`
- [ ] `.opencode/extensions/core/commands/learn.md`
- [ ] `.opencode/extensions/core/commands/distill.md`
- [ ] `.opencode/extensions/core/commands/fix-it.md`

Apply the same `model: opus` insertion pattern as Phase 2.

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- All 17 `.opencode/extensions/core/commands/*.md` files listed above

**Verification**:
- Run `grep "model:" .opencode/extensions/core/commands/*.md` - should show 17 matches
- Run `grep -L "model:" .opencode/extensions/core/commands/*.md` - should only show `README.md` if present

---

### Phase 4: Final Verification and Commit [COMPLETED]

**Goal**: Ensure all commands declare `model: opus` and commit changes.

**Tasks**:
- [ ] Run `grep -L "model:" .opencode/commands/*.md .opencode/extensions/core/commands/*.md` and verify only README files lack it
- [ ] Run `grep "model: opus" .opencode/commands/*.md | wc -l` (expect 17)
- [ ] Run `grep "model: opus" .opencode/extensions/core/commands/*.md | wc -l` (expect 17)
- [ ] Verify template and guide updates are correct
- [ ] Review `git diff --stat` for change scope
- [ ] Commit with message: `task 521: add model: opus to all command frontmatter`

**Timing**: 15 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (verification and commit only)

**Verification**:
- All 34 command files (17 core + 17 extension) declare `model: opus`
- Template and guides updated
- Commit successful

## Testing & Validation

- [ ] All 17 core command files have `model: opus` in frontmatter
- [ ] All 17 extension mirror command files have `model: opus` in frontmatter
- [ ] Command template includes `model: opus`
- [ ] Creating-commands guide lists `model` as required
- [ ] Agent frontmatter standard cross-references command requirement
- [ ] No malformed YAML frontmatter (verify `---` delimiters intact)

## Artifacts & Outputs

- `specs/521_add_model_opus_opencode_commands/plans/01_add-model-plan.md` (this file)
- Git commit with `model: opus` added to all commands
- Updated command template and standards documentation

## Rollback/Contingency

If issues are discovered post-deployment:
1. Revert the commit: `git revert HEAD`
2. If only specific commands cause issues, remove `model: opus` from those files individually
