# Implementation Plan: Task #472

- **Task**: 472 - fix_lean_mcp_script_permissions
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/472_fix_lean_mcp_script_permissions/reports/01_script-permissions-fix.md
- **Artifacts**: plans/01_script-permissions-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Two Lean MCP helper scripts (`setup-lean-mcp.sh` and `verify-lean-mcp.sh`) were committed without execute permissions. Both the source copies in `.claude/extensions/core/scripts/` and the deployed copies in `.claude/scripts/` are affected. The fix requires `chmod +x` on all four files and a git commit that records the permission change.

### Research Integration

Research confirmed that all other `.sh` files in both directories have correct `rwxr-xr-x` permissions. The loader (`loader.lua`) copies permissions verbatim from source to deployed location, so fixing the source files ensures future reloads propagate correct permissions. Both scripts already contain valid `#!/usr/bin/env bash` shebangs.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task falls under "Agent System Quality" in Phase 1 of the roadmap. Fixing script permissions ensures the Lean MCP extension scripts are executable, improving overall agent system reliability.

## Goals & Non-Goals

**Goals**:
- Set execute permissions on both source Lean MCP scripts in `.claude/extensions/core/scripts/`
- Set execute permissions on both deployed copies in `.claude/scripts/`
- Verify git tracks the permission change (mode `100755`)

**Non-Goals**:
- Modifying loader.lua or helpers.lua (permission propagation logic is correct)
- Adding automated permission validation to the extension loader
- Fixing any other files (only these two scripts are affected)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Git does not track execute bit | M | L | Verify with `git ls-files --stage` after commit; check `core.fileMode` config |
| Deployed copies not updated | L | L | Fix both source and deployed in same phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Script Permissions [NOT STARTED]

**Goal**: Set execute permissions on all four script files (2 source + 2 deployed).

**Tasks**:
- [ ] Run `chmod +x` on `.claude/extensions/core/scripts/setup-lean-mcp.sh`
- [ ] Run `chmod +x` on `.claude/extensions/core/scripts/verify-lean-mcp.sh`
- [ ] Run `chmod +x` on `.claude/scripts/setup-lean-mcp.sh`
- [ ] Run `chmod +x` on `.claude/scripts/verify-lean-mcp.sh`

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/scripts/setup-lean-mcp.sh` - add execute permission
- `.claude/extensions/core/scripts/verify-lean-mcp.sh` - add execute permission
- `.claude/scripts/setup-lean-mcp.sh` - add execute permission
- `.claude/scripts/verify-lean-mcp.sh` - add execute permission

**Verification**:
- `ls -la` shows `-rwxr-xr-x` on all four files

---

### Phase 2: Verify and Commit [NOT STARTED]

**Goal**: Confirm git tracks the permission changes and commit.

**Tasks**:
- [ ] Run `git diff` to confirm mode change from `100644` to `100755` on source files
- [ ] Run `git ls-files --stage` on both source files to verify tracked permissions
- [ ] Stage and commit the permission changes

**Timing**: 5 minutes

**Depends on**: 1

**Files to modify**:
- None (git operations only)

**Verification**:
- `git log --oneline -1` shows the permission fix commit
- `git ls-files --stage` shows mode `100755` for both source scripts

## Testing & Validation

- [ ] All four scripts show `-rwxr-xr-x` permissions via `ls -la`
- [ ] `git diff --cached` or `git show` confirms mode change `100644 -> 100755`
- [ ] Both scripts execute without "Permission denied": `bash .claude/scripts/setup-lean-mcp.sh --help` (or similar)

## Artifacts & Outputs

- plans/01_script-permissions-fix.md (this plan)
- summaries/01_script-permissions-summary.md (after implementation)

## Rollback/Contingency

- Revert with `chmod -x` on the four files and `git checkout` the source files to restore original permissions. Risk of rollback is minimal since the change is purely additive (adding execute bit).
