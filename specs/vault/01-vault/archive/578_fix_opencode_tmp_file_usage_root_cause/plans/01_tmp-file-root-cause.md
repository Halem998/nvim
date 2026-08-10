# Implementation Plan: Fix OpenCode /tmp/ File Usage Root Cause

- **Task**: 578 - fix_opencode_tmp_file_usage_root_cause
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 574 (prior fix for mktemp calls -- already completed)
- **Research Inputs**: reports/01_tmp-file-root-cause.md
- **Artifacts**: plans/01_tmp-file-root-cause.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The OpenCode agent system continues to generate `/tmp/state.json.tmp` paths because LLM agents compose jq commands based on inconsistent temp file patterns found in skill, command, context, and example documentation files. Task 574 fixed bare `mktemp` calls in shell scripts but missed the documentation layer where agents read patterns and replicate them. This plan standardizes all temp file references across 26 files in two repositories (`~/.config/nvim/.opencode/` and `~/.dotfiles/.opencode/`) to use the canonical `specs/tmp/state.json` pattern, and adds an explicit `/tmp/` prohibition to both AGENTS.md files so agents receive the constraint at session start.

### Research Integration

The research report (reports/01_tmp-file-root-cause.md) identified three root causes:
1. **Bare `state.json.tmp`** in `research-flow-example.md` (3 files) -- the worst pattern, no `specs/` prefix at all
2. **In-place `specs/state.json.tmp`** in commands, skills, and context files (17+ files) -- creates ambiguity vs. canonical `specs/tmp/state.json`
3. **No `/tmp/` prohibition** in AGENTS.md (2 files) -- agents receive no constraint against system `/tmp/`

My audit expanded the research findings:
- Research identified 19 files; audit found **24 files** with temp patterns plus 2 AGENTS.md files (26 total)
- Additional files found: `jq-escaping-workarounds.md` (1), `preflight-postflight.md` (4 copies), `extensions/web/skills/skill-tag/SKILL.md` (1), `extensions/core/skills/skill-tag/SKILL.md` (1)
- `review.md` files also contain `specs/reviews/state.json.tmp` patterns (a different state file but same anti-pattern)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any items in ROADMAP.md. It is a correctness fix for the OpenCode agent system's temp file conventions.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Standardize all temp file write patterns to `specs/tmp/state.json` (or `specs/tmp/{filename}` for non-state.json files like `specs/archive/state.json` and `specs/reviews/state.json`)
- Eliminate bare `state.json.tmp` patterns with no `specs/` prefix
- Eliminate in-place `.tmp` suffix patterns (`specs/state.json.tmp`, `specs/reviews/state.json.tmp`, etc.)
- Fix `${state_file}.tmp` variable expansion in skill-tag to use `specs/tmp/state.json`
- Fix hybrid `specs/tmp/state.json.tmp` patterns (correct directory but wrong filename)
- Add explicit `/tmp/` prohibition to AGENTS.md in both repos
- Ensure `mkdir -p specs/tmp` guards exist before temp file writes

**Non-Goals**:
- Fixing the `.claude/` system (different permission model, out of scope)
- Adding automated lint checks for `/tmp/` usage (optional follow-up, not blocking)
- Modifying shell scripts (already fixed by task 574)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `specs/tmp/` directory not existing at runtime | High | Medium | Add `mkdir -p specs/tmp` before jq writes in all affected files |
| Missing some duplicate/variant files | Medium | Low | Run post-fix grep verification across both repos to confirm zero remaining `.tmp` patterns |
| Breaking jq command syntax during edits | Medium | Low | Each replacement follows a simple pattern; verify with `grep -c` counts before/after |
| LLM still generates `/tmp/` from training data despite prohibition | Medium | Medium | AGENTS.md prohibition significantly reduces probability but cannot fully prevent; the consistent documentation patterns are the primary mitigation |
| `specs/reviews/state.json` needs different temp path than `specs/state.json` | Low | Low | Use `specs/tmp/reviews-state.json` or `specs/tmp/state.json` depending on context; maintain clear naming |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add /tmp/ Prohibition to AGENTS.md [COMPLETED]

**Goal**: Ensure agents receive the temp file convention constraint at session start, before any skill or command files are loaded.

**Tasks**:
- [ ] Read current AGENTS.md in nvim `.opencode/` to find the best insertion point (Quick Reference or Standards section)
- [ ] Add temp file convention block to `/home/benjamin/.config/nvim/.opencode/AGENTS.md`:
  ```
  **Temp File Convention**: Always use `specs/tmp/` for temporary files. NEVER use system `/tmp/` or in-place `.tmp` suffixes. Run `mkdir -p specs/tmp` before writing temp files. Canonical pattern: `jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json`
  ```
- [ ] Add identical block to `/home/benjamin/.dotfiles/.opencode/AGENTS.md`
- [ ] Verify both files contain the prohibition with `grep -n 'specs/tmp' AGENTS.md`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/AGENTS.md` - Add temp file convention prohibition
- `/home/benjamin/.dotfiles/.opencode/AGENTS.md` - Add temp file convention prohibition

**Verification**:
- `grep -c 'specs/tmp' ~/.config/nvim/.opencode/AGENTS.md` returns >= 1
- `grep -c 'NEVER.*\/tmp\/' ~/.config/nvim/.opencode/AGENTS.md` returns >= 1
- Same checks pass for `~/.dotfiles/.opencode/AGENTS.md`

---

### Phase 2: Fix Bare and In-Place Patterns in nvim .opencode/ (Primary) [COMPLETED]

**Goal**: Fix all 17 files in the nvim `.opencode/` directory (excluding extensions) that contain incorrect temp file patterns.

**Tasks**:
- [ ] Fix `docs/examples/research-flow-example.md` (line 237): Change `state.json > state.json.tmp && mv state.json.tmp state.json` to `specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json`
- [ ] Fix `commands/review.md`:
  - Line 803: `specs/state.json > specs/state.json.tmp` -> `specs/state.json > specs/tmp/state.json`
  - Lines 844-845, 850-851: `specs/reviews/state.json > specs/reviews/state.json.tmp` -> `specs/reviews/state.json > specs/tmp/reviews-state.json` and update corresponding `mv` targets
- [ ] Fix `commands/todo.md`:
  - Line 402: `specs/state.json > specs/state.json.tmp` -> `specs/state.json > specs/tmp/state.json`
  - Lines 489-490: `specs/archive/state.json > specs/archive/state.json.tmp` -> `specs/archive/state.json > specs/tmp/archive-state.json` and update `mv`
  - Line 640: Same `specs/state.json.tmp` pattern
  - Lines 783-784: Same `specs/state.json.tmp` pattern
- [ ] Fix `skills/skill-project-overview/SKILL.md` (line 373): `specs/state.json.tmp` -> `specs/tmp/state.json`
- [ ] Fix `skills/skill-todo/SKILL.md` (lines 500-501, 519-520, 582-583, 588-589, 612-613): All `specs/state.json.tmp` -> `specs/tmp/state.json`
- [ ] Fix `skills/skill-tag/SKILL.md` (lines 300, 315): `"${state_file}.tmp"` -> `"specs/tmp/state.json"`
- [ ] Fix `context/workflows/preflight-postflight.md` (line 487): `specs/tmp/state.json.tmp` -> `specs/tmp/state.json`
- [ ] Fix `context/core/workflows/preflight-postflight.md` (line 488): Same hybrid pattern
- [ ] Fix `context/core/patterns/jq-escaping-workarounds.md` (line 198): `specs/tmp/test-specs/state.json.tmp` -> `specs/tmp/test-specs/state.json`
- [ ] Add `mkdir -p specs/tmp` guard before first jq write in each file where not already present
- [ ] Run verification: `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/ --include="*.md" | grep -v 'specs/tmp/\|extensions/'` should return zero results (excluding extensions handled in Phase 3)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/docs/examples/research-flow-example.md` - Fix bare pattern
- `/home/benjamin/.config/nvim/.opencode/commands/review.md` - Fix 3 in-place patterns (state.json + reviews/state.json)
- `/home/benjamin/.config/nvim/.opencode/commands/todo.md` - Fix 4 in-place patterns (state.json + archive/state.json)
- `/home/benjamin/.config/nvim/.opencode/skills/skill-project-overview/SKILL.md` - Fix 1 in-place pattern
- `/home/benjamin/.config/nvim/.opencode/skills/skill-todo/SKILL.md` - Fix 5 in-place patterns
- `/home/benjamin/.config/nvim/.opencode/skills/skill-tag/SKILL.md` - Fix 2 variable expansion patterns
- `/home/benjamin/.config/nvim/.opencode/context/workflows/preflight-postflight.md` - Fix 1 hybrid pattern
- `/home/benjamin/.config/nvim/.opencode/context/core/workflows/preflight-postflight.md` - Fix 1 hybrid pattern
- `/home/benjamin/.config/nvim/.opencode/context/core/patterns/jq-escaping-workarounds.md` - Fix 1 test example pattern

**Verification**:
- `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/ --include="*.md" | grep -v extensions/` returns zero lines
- `grep -rc 'specs/tmp/state\.json' ~/.config/nvim/.opencode/ --include="*.md" | grep -v ':0$' | grep -v extensions/` shows all fixed files

---

### Phase 3: Fix Patterns in nvim .opencode/extensions/ [COMPLETED]

**Goal**: Fix all 7 files in the nvim `.opencode/extensions/` subdirectories (core and web extensions).

**Tasks**:
- [ ] Fix `extensions/core/docs/examples/research-flow-example.md` (line 237): Same bare pattern fix as Phase 2
- [ ] Fix `extensions/core/commands/review.md`: Same patterns as Phase 2 review.md
- [ ] Fix `extensions/core/commands/todo.md`: Same patterns as Phase 2 todo.md
- [ ] Fix `extensions/core/skills/skill-project-overview/SKILL.md` (line 373): Same fix
- [ ] Fix `extensions/core/skills/skill-todo/SKILL.md` (lines 503-504, 522-523, 585-586, 591-592, 615-616): Same fix
- [ ] Fix `extensions/core/skills/skill-tag/SKILL.md` (lines 300, 315): Same variable expansion fix
- [ ] Fix `extensions/core/context/workflows/preflight-postflight.md` (line 487): Same hybrid pattern fix
- [ ] Fix `extensions/web/skills/skill-tag/SKILL.md` (lines 300, 315): Same variable expansion fix
- [ ] Run verification: `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/extensions/ --include="*.md"` should return zero results

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.config/nvim/.opencode/extensions/core/docs/examples/research-flow-example.md` - Fix bare pattern
- `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/review.md` - Fix 3 in-place patterns
- `/home/benjamin/.config/nvim/.opencode/extensions/core/commands/todo.md` - Fix 4 in-place patterns
- `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-project-overview/SKILL.md` - Fix 1 in-place pattern
- `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-todo/SKILL.md` - Fix 5 in-place patterns
- `/home/benjamin/.config/nvim/.opencode/extensions/core/skills/skill-tag/SKILL.md` - Fix 2 variable expansion patterns
- `/home/benjamin/.config/nvim/.opencode/extensions/core/context/workflows/preflight-postflight.md` - Fix 1 hybrid pattern
- `/home/benjamin/.config/nvim/.opencode/extensions/web/skills/skill-tag/SKILL.md` - Fix 2 variable expansion patterns

**Verification**:
- `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/extensions/ --include="*.md"` returns zero lines

---

### Phase 4: Fix Patterns in dotfiles .opencode/ [COMPLETED]

**Goal**: Fix all 7 files in the dotfiles `.opencode/` directory with the same patterns.

**Tasks**:
- [ ] Fix `docs/examples/research-flow-example.md` (line 237): Same bare pattern fix
- [ ] Fix `commands/review.md`: Same in-place and reviews/state.json patterns
- [ ] Fix `commands/todo.md`: Same in-place and archive/state.json patterns
- [ ] Fix `skills/skill-project-overview/SKILL.md` (line 373): Same fix
- [ ] Fix `skills/skill-todo/SKILL.md` (lines 503-504, 522-523, 585-586, 591-592, 615-616): Same fix
- [ ] Fix `skills/skill-tag/SKILL.md` (lines 300, 315): Same variable expansion fix
- [ ] Fix `context/workflows/preflight-postflight.md` (line 487): Same hybrid pattern fix
- [ ] Run verification: `grep -rn 'state\.json\.tmp' ~/.dotfiles/.opencode/ --include="*.md"` should return zero results

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/.dotfiles/.opencode/docs/examples/research-flow-example.md` - Fix bare pattern
- `/home/benjamin/.dotfiles/.opencode/commands/review.md` - Fix 3 in-place patterns
- `/home/benjamin/.dotfiles/.opencode/commands/todo.md` - Fix 4 in-place patterns
- `/home/benjamin/.dotfiles/.opencode/skills/skill-project-overview/SKILL.md` - Fix 1 in-place pattern
- `/home/benjamin/.dotfiles/.opencode/skills/skill-todo/SKILL.md` - Fix 5 in-place patterns
- `/home/benjamin/.dotfiles/.opencode/skills/skill-tag/SKILL.md` - Fix 2 variable expansion patterns
- `/home/benjamin/.dotfiles/.opencode/context/workflows/preflight-postflight.md` - Fix 1 hybrid pattern

**Verification**:
- `grep -rn 'state\.json\.tmp' ~/.dotfiles/.opencode/ --include="*.md"` returns zero lines

---

### Phase 5: Cross-Repository Verification [COMPLETED]

**Goal**: Confirm all 26 files are fixed and no remaining incorrect temp file patterns exist in either repository.

**Tasks**:
- [ ] Run comprehensive grep across both repos: `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/ ~/.dotfiles/.opencode/ --include="*.md"` -- must return zero results
- [ ] Verify no bare `> /tmp/` patterns: `grep -rn '> /tmp/' ~/.config/nvim/.opencode/ ~/.dotfiles/.opencode/ --include="*.md"` -- must return zero results
- [ ] Verify AGENTS.md prohibition exists in both: `grep -c 'specs/tmp' ~/.config/nvim/.opencode/AGENTS.md ~/.dotfiles/.opencode/AGENTS.md` -- both must be >= 1
- [ ] Verify `mkdir -p specs/tmp` guards are present where needed by spot-checking 3-4 files
- [ ] Count pattern occurrences of `specs/tmp/state.json` to confirm the new canonical pattern is in place: `grep -rc 'specs/tmp/state\.json' ~/.config/nvim/.opencode/ ~/.dotfiles/.opencode/ --include="*.md" | grep -v ':0$' | wc -l` -- should be >= 24

**Timing**: 15 minutes

**Depends on**: 2, 3, 4

**Files to modify**: None (verification only)

**Verification**:
- All grep checks above pass with expected results
- Zero false positives from legitimate uses

## Testing & Validation

- [ ] `grep -rn 'state\.json\.tmp' ~/.config/nvim/.opencode/ --include="*.md"` returns zero lines
- [ ] `grep -rn 'state\.json\.tmp' ~/.dotfiles/.opencode/ --include="*.md"` returns zero lines
- [ ] `grep -rn '> /tmp/' ~/.config/nvim/.opencode/ --include="*.md"` returns zero lines
- [ ] `grep -rn '> /tmp/' ~/.dotfiles/.opencode/ --include="*.md"` returns zero lines
- [ ] Both AGENTS.md files contain explicit `/tmp/` prohibition text
- [ ] `grep -c 'specs/tmp/state\.json' ~/.config/nvim/.opencode/AGENTS.md` >= 1
- [ ] Spot-check: `research-flow-example.md` shows `specs/state.json > specs/tmp/state.json`
- [ ] Spot-check: `skill-tag/SKILL.md` no longer uses `${state_file}.tmp`

## Artifacts & Outputs

- `specs/578_fix_opencode_tmp_file_usage_root_cause/plans/01_tmp-file-root-cause.md` (this file)
- `specs/578_fix_opencode_tmp_file_usage_root_cause/summaries/01_tmp-file-root-cause-summary.md` (after implementation)
- 26 modified files across two repositories (24 with temp file pattern fixes + 2 AGENTS.md with prohibition)

## Rollback/Contingency

All changes are to documentation/instruction files (`.md`), not executable code. Rollback is straightforward:
- Use `git checkout -- .opencode/` in the nvim repo to revert all changes
- Use `git checkout -- .opencode/` in the dotfiles repo to revert all changes
- No runtime dependencies or build steps are affected
- If a specific file edit breaks jq command syntax in agent-generated code, revert that single file and re-examine the replacement pattern
