# Implementation Plan: Task #727

- **Task**: 727 - Implement extension keyword_overrides lookup in /task command step 4
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/727_implement_extension_keyword_overrides_in_task_command/reports/01_keyword-overrides-research.md
- **Artifacts**: plans/01_keyword-overrides-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/task` command step 4 in `.claude/commands/task.md` already contains the full precedence chain (4a-4e) with meta keywords, extension keyword_overrides scanning, default_task_type fallback, hardcoded keyword table, and alias remapping. Research confirms the documentation and implementation match the specified precedence order. However, the jq pattern for keyword matching uses `\b` word boundary anchors which fail for multi-word keywords like "pull request", "market size", or "pitch deck". This plan addresses that bug and validates the existing implementation end-to-end.

### Research Integration

The research report (01_keyword-overrides-research.md) confirmed:
- Step 4 already implements all five precedence levels (4a-4e)
- Only the `cslib` extension currently defines `keyword_overrides`
- Multi-word keywords in the jq `test("\\b" + $kw + "\\b")` pattern will not match correctly because `\b` applies per-character boundary, not per-word
- The `head -1` first-match strategy is acceptable

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly address this task.

## Goals & Non-Goals

**Goals**:
- Fix the multi-word keyword matching bug in step 4b's jq pattern
- Validate that the existing step 4 precedence chain (4a-4e) is complete and correct
- Ensure "neovim", "plugin", "nvim", "lua" keywords in step 4d route to `neovim` (preserve existing behavior)

**Non-Goals**:
- Adding keyword_overrides to extensions that don't have them
- Changing the precedence order itself
- Adding tests (task.md is a command instruction file, not executable code)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq `test()` regex behavior varies across versions | M | L | Use simpler pattern that avoids version-specific regex features |
| Multi-word keyword fix breaks single-word matching | H | L | Pattern must handle both; test with representative keywords |
| Claude Code jq escaping (Issue #1132) corrupts the pattern | M | M | Avoid `!=` and complex pipe constructs in jq; use safe patterns |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix multi-word keyword matching in step 4b [NOT STARTED]

**Goal**: Replace the `\b` word boundary jq pattern with one that correctly matches both single-word and multi-word keywords from extension keyword_overrides.

**Tasks**:
- [ ] Read `.claude/commands/task.md` lines 130-141 (the step 4b jq pattern)
- [ ] Replace the jq `test("\\b" + $kw + "\\b")` pattern in step 4b with a pattern that handles multi-word keywords. Recommended approach: use `test("(^|\\\\W)" + $kw + "(\\\\W|$)")` or switch to `test("(?:^|\\\\s)" + $kw + "(?:\\\\s|$)")` which matches word boundaries via whitespace/start/end anchors
- [ ] Verify the replacement pattern also works for single-word keywords like "lean" or "pr"
- [ ] Verify step 4d's hardcoded keyword table includes "neovim", "plugin", "nvim", "lua" -> neovim (confirm existing)
- [ ] Verify step 4e alias remapping pattern is syntactically correct

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Fix the jq pattern in step 4b (lines ~134-138)

**Verification**:
- The jq pattern in step 4b no longer uses bare `\b` word boundaries
- The replacement pattern correctly handles "pull request", "pitch deck", "market size" as multi-word matches
- Single-word keywords like "lean", "pr", "meta" still match correctly
- Steps 4a through 4e remain complete and structurally sound

---

## Testing & Validation

- [ ] Manually verify the jq pattern handles single-word keyword: `echo '{"keyword_overrides":{"cslib":{"keywords":["lean"]}}}' | jq -r --arg desc "fix lean proof" '<pattern>'` returns "cslib"
- [ ] Manually verify multi-word keyword: `echo '{"keyword_overrides":{"pr":{"keywords":["pull request"]}}}' | jq -r --arg desc "create pull request for upstream" '<pattern>'` returns "pr"
- [ ] Verify no regression: single-word keyword does not match substring (e.g., "lean" should not match "cleaning")

## Artifacts & Outputs

- `plans/01_keyword-overrides-plan.md` (this file)
- `.claude/commands/task.md` (modified step 4b jq pattern)

## Rollback/Contingency

Revert the single edit to `.claude/commands/task.md` via `git checkout -- .claude/commands/task.md`.
