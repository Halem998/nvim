# Implementation Plan: Task #685

- **Task**: 685 - Restrict Bash(git:*) permissions to exclude git push
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/685_restrict_git_push_permissions/reports/01_git-permissions-research.md
- **Artifacts**: plans/01_git-permissions-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `Bash(git push:*)` to the deny list in `.claude/settings.json` so that `git push` always triggers a permission prompt, while keeping `Bash(git:*)` in the allow list for all other git operations. The deny-override approach is simpler and more maintainable than enumerating 26+ individual git subcommands. Only the project-level nvim config settings.json is modified; the user-level settings are out of scope for this task.

### Research Integration

The research report confirmed that deny rules take absolute precedence over allow rules in Claude Code's permission evaluation order (deny > ask > allow > defaultMode). Adding `Bash(git push:*)` to the deny list will block all `git push` variants even with `Bash(git:*)` in allow. All three `git push` usage sites (/merge, /tag, cslib /pr) are user-initiated commands where a permission prompt is appropriate and desirable. No autonomous agent workflows use `git push`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task.

## Goals & Non-Goals

**Goals**:
- Ensure `git push` (with or without arguments) always triggers a permission prompt
- Keep all other git operations (add, commit, status, diff, log, etc.) auto-allowed via `Bash(git:*)`
- Maintain consistency with existing deny list format in `.claude/settings.json`

**Non-Goals**:
- Modifying user-level `~/.claude/settings.json` (managed by Home Manager, separate concern)
- Modifying the cslib project settings.json (user will reload there separately)
- Blocking `git push` entirely (it should prompt, not be denied outright)
- Enumerating individual git subcommands (research rejected this approach)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deny format does not match bare `git push` (no args) | M | L | Include both `Bash(git push:*)` and `Bash(git push)` in deny list for complete coverage |
| /merge workflow friction from extra prompt | L | L | Users already initiate /merge manually; one approval click is acceptable |
| Format inconsistency (colon vs space) | L | L | Use colon format `Bash(git push:*)` matching existing `Bash(git:*)` style |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add git push deny rules [COMPLETED]

**Goal**: Add `Bash(git push:*)` and `Bash(git push)` entries to the deny list in `.claude/settings.json`.

**Tasks**:
- [ ] Open `.claude/settings.json` and locate the `permissions.deny` array
- [ ] Add `Bash(git push:*)` as the first entry in the deny array (before existing entries)
- [ ] Add `Bash(git push)` as the second entry to catch bare `git push` without arguments
- [ ] Verify JSON syntax is valid after edit
- [ ] Confirm `Bash(git:*)` remains unchanged in the allow list

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/settings.json` - Add 2 entries to `permissions.deny` array

**Verification**:
- `jq '.permissions.deny' .claude/settings.json` shows both new entries
- `jq '.permissions.allow' .claude/settings.json` still contains `Bash(git:*)`
- JSON is valid: `jq . .claude/settings.json > /dev/null` exits 0

---

### Phase 2: Verify no workflow breakage [COMPLETED]

**Goal**: Confirm that no legitimate agent workflows are broken by the new deny rules.

**Tasks**:
- [ ] Grep `.claude/` for all `git push` usage to confirm only user-invoked commands use it
- [ ] Verify `/merge` command documentation notes that git push will prompt (acceptable behavior)
- [ ] Verify `/tag` skill documentation notes that git push will prompt (acceptable behavior)
- [ ] Run `jq . .claude/settings.json` to validate final JSON structure
- [ ] Confirm deny list order: git push rules, then existing safety rules

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (read-only verification)

**Verification**:
- `grep -rn 'git push' .claude/skills/ .claude/scripts/` shows no autonomous push usage
- `jq '.permissions' .claude/settings.json` shows correct allow/deny structure
- No changes to allow list contents

## Testing & Validation

- [ ] `jq '.permissions.deny' .claude/settings.json` includes `Bash(git push:*)` and `Bash(git push)`
- [ ] `jq '.permissions.allow' .claude/settings.json` includes `Bash(git:*)`
- [ ] JSON is well-formed: `jq . .claude/settings.json > /dev/null` succeeds
- [ ] `grep -rn 'git push' .claude/skills/` confirms no autonomous workflows use git push

## Artifacts & Outputs

- plans/01_git-permissions-plan.md (this file)
- summaries/01_git-permissions-summary.md (after implementation)

## Rollback/Contingency

Remove the two added deny entries from `.claude/settings.json` to restore the original behavior where `Bash(git:*)` allows all git operations including push.
