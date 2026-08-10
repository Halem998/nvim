# Implementation Plan: Task #683

- **Task**: 683 - Add keyword_overrides field to cslib extension manifest.json
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 682 (completed)
- **Research Inputs**: specs/683_cslib_manifest_keyword_overrides/reports/01_cslib-keyword-overrides.md
- **Artifacts**: plans/01_cslib-keyword-overrides.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Add a `keyword_overrides` field to the cslib extension manifest at `.claude/extensions/cslib/manifest.json`. This enables deterministic task-type detection for lean-related and PR-related task descriptions when the cslib extension is loaded, replacing agent judgment with explicit keyword matching. The change is a single JSON field insertion -- no other files require modification.

### Research Integration

Research report (01_cslib-keyword-overrides.md) confirmed:
- The cslib manifest has no `keyword_overrides` field yet
- The `keyword_overrides` schema is documented and implemented (task 682)
- Two entries are needed: `cslib` (with lean4 alias + domain keywords) and `pr` (with PR-workflow keywords)
- Insertion point: after `routing_hard`, before `merge_targets`
- Multi-word keyword "pull request" works with jq `\b` regex boundaries

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items directly addressed by this task.

## Goals & Non-Goals

**Goals**:
- Add `keyword_overrides` to cslib manifest with correct schema
- Map lean-related keywords (lean, lean4, mathlib, theorem, proof) to cslib task type with `lean4` alias
- Map PR-related keywords (pr, pull request, submit, upstream, branch, rebase, cherry-pick) to pr task type

**Non-Goals**:
- Modifying the `/task` command (already handled by task 682)
- Adding keyword_overrides to other extensions
- Changing cslib routing or agents

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error from manual insertion | M | L | Validate with `jq .` after edit |
| "pull request" multi-word keyword fails in regex | L | L | "pr" keyword provides fallback coverage |
| Generic keywords (branch, submit) cause false positives | L | M | Accepted tradeoff per task description requirements |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add keyword_overrides to cslib manifest [NOT STARTED]

**Goal**: Insert the `keyword_overrides` field into `.claude/extensions/cslib/manifest.json` with both cslib and pr entries.

**Tasks**:
- [ ] Read current manifest.json to confirm exact insertion point (after `routing_hard` block, before `merge_targets`)
- [ ] Insert `keyword_overrides` JSON block with two entries:
  - `cslib`: keywords `["lean", "lean4", "mathlib", "theorem", "proof"]`, aliases `["lean4"]`
  - `pr`: keywords `["pr", "pull request", "submit", "upstream", "branch", "rebase", "cherry-pick"]`, aliases `[]`
- [ ] Validate JSON syntax with `jq . manifest.json`
- [ ] Verify keyword_overrides structure matches the schema documented in extension-development.md

**Timing**: 15-30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/manifest.json` - Add `keyword_overrides` field between `routing_hard` and `merge_targets`

**Verification**:
- `jq .keyword_overrides .claude/extensions/cslib/manifest.json` returns the expected two-entry object
- `jq .keyword_overrides.cslib.aliases .claude/extensions/cslib/manifest.json` returns `["lean4"]`
- `jq .keyword_overrides.pr.keywords .claude/extensions/cslib/manifest.json` returns the 7-element array
- Full manifest parses without error: `jq . .claude/extensions/cslib/manifest.json`

## Testing & Validation

- [ ] Manifest JSON is valid (no parse errors from `jq .`)
- [ ] `keyword_overrides.cslib.keywords` contains exactly: lean, lean4, mathlib, theorem, proof
- [ ] `keyword_overrides.cslib.aliases` contains exactly: lean4
- [ ] `keyword_overrides.pr.keywords` contains exactly: pr, pull request, submit, upstream, branch, rebase, cherry-pick
- [ ] `keyword_overrides.pr.aliases` is empty array `[]`
- [ ] Field placement is between `routing_hard` and `merge_targets` in the JSON structure

## Artifacts & Outputs

- plans/01_cslib-keyword-overrides.md (this file)
- summaries/01_cslib-keyword-overrides-summary.md (after implementation)
- Modified file: `.claude/extensions/cslib/manifest.json`

## Rollback/Contingency

Revert the single edit to `.claude/extensions/cslib/manifest.json` via `git checkout -- .claude/extensions/cslib/manifest.json`. The keyword_overrides field is purely additive and its removal has no side effects on existing functionality.
