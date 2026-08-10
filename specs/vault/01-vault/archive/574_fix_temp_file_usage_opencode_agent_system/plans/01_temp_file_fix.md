# Implementation Plan: Task #574

- **Task**: 574 - fix_temp_file_usage_opencode_agent_system
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/574_fix_temp_file_usage_opencode_agent_system/reports/01_temp_file_audit.md
- **Artifacts**: plans/01_temp_file_fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: bash

## Overview

Mechanical fix to replace bare `mktemp` calls (no template) with `mktemp -p specs/tmp tmp.XXXXXXXXXX` in two scripts that create temp files under `/tmp/`, triggering unwanted OpenCode external-directory permission prompts. The fix must be applied across all 4 duplicate directory copies of each script. The `specs/tmp/` directory already exists and is gitignored; scripts need a `mkdir -p` guard added before the first `mktemp` call.

### Research Integration

Key findings from `reports/01_temp_file_audit.md`:
- The migration from `/tmp/` to `specs/tmp/` is 99% complete — only `update-recommended-order.sh` (8 bare `mktemp` calls) and `setup-lean-mcp.sh` (3 bare `mktemp` calls) remain
- Both scripts have 4 identical copies: `.opencode/scripts/`, `.opencode/extensions/core/scripts/`, `.claude/scripts/`, `.claude/extensions/core/scripts/`
- `specs/tmp/` exists and is properly gitignored; no `/tmp/opencode` hardcoded paths remain anywhere
- All bare `mktemp` calls follow pattern: assign to variable → write content → `mv` to target (temp file is ephemeral, destroyed by the `mv`)
- `setup-lean-mcp.sh` also writes to `$HOME/.claude.json` which is inherently external — fixing the temp file path reduces but does not eliminate all permission prompts for that script

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items are directly addressed by this plan. The fix is tactical maintenance.

## Goals & Non-Goals

**Goals**:
- Replace all bare `mktemp` calls in `update-recommended-order.sh` with `mktemp -p specs/tmp tmp.XXXXXXXXXX`
- Replace all bare `mktemp` calls in `setup-lean-mcp.sh` with `mktemp -p specs/tmp tmp.XXXXXXXXXX`
- Add `mkdir -p specs/tmp` guard at the top of each script before the first `mktemp` call
- Apply fixes to all 4 directory copies of each script (8 files total)
- Verify zero bare `mktemp` calls remain after the fix

**Non-Goals**:
- Creating a shared temp-file utility function (deferred to follow-up task)
- Adding a lint check for bare `mktemp` calls (deferred to follow-up task)
- Fixing `setup-lean-mcp.sh` external-directory access to `$HOME/.claude.json` (inherent to the script's purpose)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `specs/tmp/` missing at mktemp runtime | Low | Low | Add `mkdir -p specs/tmp` guard before first mktemp call in each script |
| Forgetting to fix all 4 copies | Medium | Low | Grep for bare `mktemp` after fix; zero matches confirms completeness |
| `tmp_file2` variable name clash with fix | Low | Low | `mktemp` call pattern is identical regardless of variable name; simple string replacement |
| Script run from wrong working directory | Low | Low | `mkdir -p specs/tmp` is relative to cwd; scripts are always run from project root per conventions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix update-recommended-order.sh [COMPLETED]

**Goal**: Replace all 8 bare `mktemp` calls with `mktemp -p specs/tmp tmp.XXXXXXXXXX` and add `mkdir -p specs/tmp` guard in all 4 directory copies.

**Tasks**:
- [x] **Task 1.1**: Fix `.opencode/scripts/update-recommended-order.sh` (8 mktemp calls + mkdir guard) *(completed)*
- [x] **Task 1.2**: Fix `.opencode/extensions/core/scripts/update-recommended-order.sh` (identical copy) *(completed)*
- [x] **Task 1.3**: Fix `.claude/scripts/update-recommended-order.sh` (identical copy) *(completed)*
- [x] **Task 1.4**: Fix `.claude/extensions/core/scripts/update-recommended-order.sh` (identical copy) *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.opencode/scripts/update-recommended-order.sh` — 8 bare `mktemp` calls (lines ~154, 388, 403, 497, 553, 613, 640, 649), add `mkdir -p specs/tmp` near top
- `.opencode/extensions/core/scripts/update-recommended-order.sh` — same changes (identical copy)
- `.claude/scripts/update-recommended-order.sh` — same changes (identical copy)
- `.claude/extensions/core/scripts/update-recommended-order.sh` — same changes (identical copy)

**Verification**:
- `rg 'mktemp' --include='*.sh' <directory>` shows only `mktemp -p specs/tmp` patterns (no bare `mktemp`)
- `rg 'mkdir -p specs/tmp' <file>` returns a match in each file

---

### Phase 2: Fix setup-lean-mcp.sh [COMPLETED]

**Goal**: Replace all 3 bare `mktemp` calls with `mktemp -p specs/tmp tmp.XXXXXXXXXX` and add `mkdir -p specs/tmp` guard in all 4 directory copies.

**Tasks**:
- [x] **Task 2.1**: Fix `.opencode/scripts/setup-lean-mcp.sh` (3 mktemp calls + mkdir guard) *(completed)*
- [x] **Task 2.2**: Fix `.opencode/extensions/core/scripts/setup-lean-mcp.sh` (identical copy) *(completed)*
- [x] **Task 2.3**: Fix `.claude/scripts/setup-lean-mcp.sh` (identical copy) *(completed)*
- [x] **Task 2.4**: Fix `.claude/extensions/core/scripts/setup-lean-mcp.sh` (identical copy) *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.opencode/scripts/setup-lean-mcp.sh` — 3 bare `mktemp` calls (lines ~113, 175, 197), add `mkdir -p specs/tmp` near top
- `.opencode/extensions/core/scripts/setup-lean-mcp.sh` — same changes (identical copy)
- `.claude/scripts/setup-lean-mcp.sh` — same changes (identical copy)
- `.claude/extensions/core/scripts/setup-lean-mcp.sh` — same changes (identical copy)

**Verification**:
- `rg 'mktemp' --include='*.sh' <directory>` shows only `mktemp -p specs/tmp` patterns (no bare `mktemp`)
- `rg 'mkdir -p specs/tmp' <file>` returns a match in each file

---

### Phase 3: Verification and Cleanup [COMPLETED]

**Goal**: Confirm zero bare `mktemp` calls remain across the entire codebase and verify scripts are syntactically sound.

**Tasks**:
- [x] **Task 3.1**: Run final audit grep for bare `mktemp` across `.opencode/` and `.claude/` directories *(completed: zero matches)*
- [x] **Task 3.2**: Verify each modified script passes shell syntax check (`bash -n`) *(completed: all 8 OK)*
- [x] **Task 3.3**: Confirm `specs/tmp/` directory exists *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1, 2

**Files to inspect**:
- `.opencode/scripts/update-recommended-order.sh`
- `.opencode/extensions/core/scripts/update-recommended-order.sh`
- `.claude/scripts/update-recommended-order.sh`
- `.claude/extensions/core/scripts/update-recommended-order.sh`
- `.opencode/scripts/setup-lean-mcp.sh`
- `.opencode/extensions/core/scripts/setup-lean-mcp.sh`
- `.claude/scripts/setup-lean-mcp.sh`
- `.claude/extensions/core/scripts/setup-lean-mcp.sh`

**Verification**:
- `rg 'mktemp\)$' .opencode/scripts/ .opencode/extensions/ .claude/scripts/ .claude/extensions/` returns zero matches
- `for f in <all 8 files>; do bash -n "$f" || echo "FAIL: $f"; done` — zero failures

## Testing & Validation

- [ ] Final grep for bare `mktemp` (no template) returns zero matches across all `.opencode/` and `.claude/` scripts
- [ ] All 8 modified scripts pass `bash -n` syntax check
- [ ] `specs/tmp/` directory exists (pre-existing, verified)
- [ ] `git diff --stat` shows only the 8 expected files modified

## Artifacts & Outputs

- 8 modified shell scripts with `mktemp -p specs/tmp tmp.XXXXXXXXXX` replacing all bare `mktemp` calls
- Each script gains `mkdir -p specs/tmp` guard before first temp file use

## Rollback/Contingency

All changes are simple string replacements. Rollback is `git checkout -- <file>` for each modified script. No schema changes, no data migration required.
