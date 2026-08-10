# Implementation Plan: Fix OpenCode Model Not Found Error

- **Task**: 529 - Fix 'Model not found: opus/' error in .opencode/ agent system
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/529_fix_opencode_model_not_found_opus_error/reports/01_model-not-found-research.md
- **Artifacts**: plans/01_fix-model-references.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `.opencode/` agent system was ported from `.claude/` and retains `model: opus` (and one `model: sonnet`) frontmatter in 34 command/agent files. OpenCode CLI's `parseModel()` splits model strings by `/`, so bare aliases like `"opus"` produce `{providerID: "opus", modelID: ""}` and trigger "Model not found: opus/" errors. The fix is to remove the `model:` frontmatter line entirely from all affected files, allowing the user's session model to take precedence. Done when no `.opencode/` files contain bare `model:` frontmatter and commands execute without model resolution errors.

### Research Integration

The research report (01_model-not-found-research.md) identified:
- Root cause: OpenCode's `parseModel()` splits on `/`; bare aliases have no `/` separator
- 34 affected files across `.opencode/commands/`, `.opencode/extensions/core/commands/`, `.opencode/agent/`, and `.opencode/context/templates/`
- Model frontmatter has highest priority in command resolution, always overriding session model
- Recommended fix: remove `model:` field entirely rather than converting to full `provider/model` format

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent frontmatter validation" roadmap item under Phase 1: Agent System Quality (ensuring frontmatter fields are valid and correct across systems).

## Goals & Non-Goals

**Goals**:
- Remove all invalid `model:` frontmatter from `.opencode/` command and agent files
- Update the command template to not include `model:` as a field
- Update documentation to clarify that `model:` is not valid in OpenCode frontmatter
- Verify commands execute without "Model not found" errors

**Non-Goals**:
- Implementing a model alias system in OpenCode (that would be an OpenCode CLI change)
- Converting `model: opus` to full `provider/model` format (hard-coding provider defeats OpenCode's design)
- Fixing synced copies in other projects (ProofChecker etc.) -- those will be fixed by re-sync after this fix
- Modifying the `.claude/` system's model frontmatter (that system is unaffected)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing `model:` from commands means complex tasks run on cheaper models if user selects one | M | L | This matches OpenCode's design; users control model selection via session picker |
| Some files may have the `model:` line at a different position than line 3 | L | L | Use pattern-based sed rather than line-number removal; verify with grep after |
| Documentation files may reference `model:` as valid frontmatter | M | M | Audit docs and update guidance to explain difference from Claude Code |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Audit and Confirm Affected Files [COMPLETED]

**Goal**: Verify the complete list of files with invalid `model:` frontmatter and confirm the exact line content to remove.

**Tasks**:
- [ ] Run `grep -rn "^model:" .opencode/` to produce current list of affected files
- [ ] Confirm all matches are bare aliases (no `/` in value) -- not already valid `provider/model` format
- [ ] Verify line positions match research report expectations (typically line 3 in commands, line 4 in orchestrator)
- [ ] Document any unexpected patterns or edge cases

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- None (audit only)

**Verification**:
- Complete list of files produced and matches research report (34 files)
- No files with valid `provider/model` format are mistakenly identified

---

### Phase 2: Remove model: Frontmatter from All Files [COMPLETED]

**Goal**: Remove the `model:` line from all 34 affected `.opencode/` files.

**Tasks**:
- [ ] Remove `model: opus` line from 17 files in `.opencode/commands/`
- [ ] Remove `model: opus` line from 15 files in `.opencode/extensions/core/commands/`
- [ ] Remove `model: sonnet` line from `.opencode/agent/orchestrator.md`
- [ ] Remove `model: opus` line from `.opencode/context/templates/command-template.md`
- [ ] Run `grep -rn "^model:" .opencode/` to confirm zero matches remain

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/commands/*.md` (17 files) - remove `model: opus` line
- `.opencode/extensions/core/commands/*.md` (15 files) - remove `model: opus` line
- `.opencode/agent/orchestrator.md` - remove `model: sonnet` line
- `.opencode/context/templates/command-template.md` - remove `model: opus` line

**Verification**:
- `grep -rn "^model:" .opencode/` returns no results
- All modified files still have valid frontmatter structure (opening/closing delimiters intact)

---

### Phase 3: Update Documentation and Verify [COMPLETED]

**Goal**: Update documentation to reflect that `model:` is not valid in OpenCode frontmatter, and verify the fix resolves the error.

**Tasks**:
- [ ] Update `.opencode/docs/guides/creating-commands.md` to remove `model:` from valid frontmatter fields or add a note explaining it is not supported
- [ ] Update `.opencode/docs/reference/standards/agent-frontmatter-standard.md` to document that `model:` is Claude Code-only and not used in OpenCode
- [ ] Verify a sample command executes without "Model not found" error (run `opencode` if available, or confirm frontmatter structure is correct)
- [ ] Check if any other documentation references `model:` as a valid OpenCode frontmatter field

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.opencode/docs/guides/creating-commands.md` - remove or annotate `model:` field
- `.opencode/docs/reference/standards/agent-frontmatter-standard.md` - clarify OpenCode differences

**Verification**:
- Documentation no longer lists `model:` as valid OpenCode command frontmatter
- No remaining references to bare model aliases in `.opencode/` documentation
- Command files have correct frontmatter structure without `model:` field

## Testing & Validation

- [ ] `grep -rn "^model:" .opencode/` returns zero results after Phase 2
- [ ] All modified files retain valid frontmatter structure (have `---` delimiters)
- [ ] Documentation accurately reflects that `model:` is not an OpenCode frontmatter field
- [ ] No regression in `.claude/` system (model frontmatter there remains unchanged)

## Artifacts & Outputs

- `specs/529_fix_opencode_model_not_found_opus_error/plans/01_fix-model-references.md` (this file)
- `specs/529_fix_opencode_model_not_found_opus_error/summaries/01_fix-model-references-summary.md` (after implementation)

## Rollback/Contingency

If removing `model:` causes unexpected behavior:
1. `git revert` the implementation commit to restore all `model:` lines
2. Alternative approach: convert to valid `opencode/claude-opus-4-7` format instead of removing (not recommended per research)
3. If specific commands need model pinning, add back with valid `provider/model` format on a per-command basis
