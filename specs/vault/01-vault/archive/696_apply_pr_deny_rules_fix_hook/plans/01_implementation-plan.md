# Implementation Plan: Task #696

- **Task**: 696 - Apply PR deny rules to settings.json and fix block-pr-submission.sh hook
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/696_apply_pr_deny_rules_fix_hook/reports/01_pr-deny-rules-research.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply three small edits across two files to enforce PR/MR block rules in the nvim project. The changes add `Bash(gh pr create*)` and `Bash(gh pr merge*)` to `permissions.deny` in `.claude/settings.json`, register `block-pr-submission.sh` in the `PreToolUse` hooks array, and remove the git push block from the hook script. All three changes are contained to `.claude/settings.json` and `.claude/hooks/block-pr-submission.sh`.

### Research Integration

Research report `01_pr-deny-rules-research.md` provides exact diffs for all three changes, confirms the `.claude/extensions/core/hooks/` directory does not exist (no sync needed), and documents the reference state from the cslib project where deny rules were already applied.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `"Bash(gh pr create*)"` and `"Bash(gh pr merge*)"` to `permissions.deny`
- Register `block-pr-submission.sh` as a `PreToolUse` hook with matcher `Bash`
- Remove git push block (lines 25-29) from `block-pr-submission.sh` and update header comment

**Non-Goals**:
- Modifying the cslib project settings (already applied; out of scope)
- Syncing to `.claude/extensions/core/hooks/` (directory does not exist)
- Adding `gh pr merge` to the hook script body (covered by the deny rule; out of scope per research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error in settings.json | H | L | Use Edit with exact string match; verify JSON is valid after edit |
| Hook fires on every Bash call (performance overhead) | L | H | Script exits 0 quickly for non-PR commands; acceptable overhead per research |
| `|| echo '{}'` fallback swallows hook errors silently | L | L | Intentional design; prevents hook from breaking all Bash calls on script failure |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Apply all three changes [COMPLETED]

**Goal**: Edit `.claude/settings.json` (two changes) and `.claude/hooks/block-pr-submission.sh` (one change) to enforce PR deny rules and remove git push block.

**Tasks**:
- [x] Edit `.claude/settings.json`: append `"Bash(gh pr create*)"` and `"Bash(gh pr merge*)"` to `permissions.deny` array after `"Bash(chmod 777 *)"` *(completed)*
- [x] Edit `.claude/settings.json`: insert new PreToolUse entry (matcher `Bash`, command `bash .claude/hooks/block-pr-submission.sh 2>/dev/null || echo '{}'`) as the FIRST entry in `hooks.PreToolUse`, before the existing `Write` matcher entry *(completed)*
- [x] Edit `.claude/hooks/block-pr-submission.sh`: remove the git push block (5 lines starting with `if echo "$COMMAND" | grep -qE '(^|[;&|] *)git push'`) *(completed)*
- [x] Edit `.claude/hooks/block-pr-submission.sh`: update line 3 header comment from `# PreToolUse hook: block git push, gh pr create, and glab mr create operations.` to `# PreToolUse hook: block gh pr create and glab mr create operations.` *(completed)*
- [x] Edit `.claude/hooks/block-pr-submission.sh`: update comment block (lines 5-7) to remove git push reference and add note that git push is allowed *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/settings.json` - Add 2 deny entries and 1 PreToolUse hook entry
- `.claude/hooks/block-pr-submission.sh` - Remove git push block and update header comments

**Verification**:
- Confirm `permissions.deny` now has 6 entries (4 original + 2 new PR entries)
- Confirm `hooks.PreToolUse` has 2 entries (new Bash entry first, existing Write entry second)
- Confirm `block-pr-submission.sh` no longer contains `git push` in any block or check
- Confirm `block-pr-submission.sh` header comment accurately reflects what is blocked

## Testing & Validation

- [ ] `jq '.permissions.deny' /home/benjamin/.config/nvim/.claude/settings.json` — shows 6 entries including `Bash(gh pr create*)` and `Bash(gh pr merge*)`
- [ ] `jq '.hooks.PreToolUse | length' /home/benjamin/.config/nvim/.claude/settings.json` — returns `2`
- [ ] `jq '.hooks.PreToolUse[0].matcher' /home/benjamin/.config/nvim/.claude/settings.json` — returns `"Bash"`
- [ ] `grep -c 'git push' /home/benjamin/.config/nvim/.claude/hooks/block-pr-submission.sh` — returns `0`
- [ ] `bash -n /home/benjamin/.config/nvim/.claude/hooks/block-pr-submission.sh` — no syntax errors

## Artifacts & Outputs

- `specs/696_apply_pr_deny_rules_fix_hook/plans/01_implementation-plan.md` (this file)
- Modified: `.claude/settings.json`
- Modified: `.claude/hooks/block-pr-submission.sh`

## Rollback/Contingency

Both files are tracked in git. If the changes introduce problems, revert with:
```bash
git checkout HEAD -- .claude/settings.json .claude/hooks/block-pr-submission.sh
```
