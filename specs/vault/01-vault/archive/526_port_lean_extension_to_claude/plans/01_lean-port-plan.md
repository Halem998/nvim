# Implementation Plan: Task #526

- **Task**: 526 - Port lean extension to `.claude/` for parity
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: `specs/526_port_lean_extension_to_claude/reports/01_lean-port-research.md`
- **Artifacts**: `plans/01_lean-port-plan.md` (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

The `.claude/extensions/lean/` extension already exists and is more complete than `.opencode/extensions/lean/`. This task performs a parity audit and reconciliation: fixing a critical path bug in `opencode-agents.json`, backporting missing index entries to `.opencode/`, verifying skill correctness, and confirming no critical files are missing in either tree.

### Research Integration

The research report found that `.claude/extensions/lean/` has:
- Extra context files: `blocked-mcp-tools.md`, `mcp-fallback-table.md`
- Richer routing with `lean4:lake` and `lean4:version` sub-routes
- Improved skills with Stage 4b self-execution fallback and explicit postflight boundaries
- A critical bug in `opencode-agents.json` referencing non-existent `.opencode/agent/subagents/` paths

Task 525 previously fixed `OC_` prefix and `.language` → `.task_type` issues in `.opencode/` lean skills. This plan verifies those fixes are intact and applies the remaining reconciliation work.

### Prior Plan Reference

No prior plan for this exact task. Task 525 (`specs/525_fix_lean_skill_path_field_refs/`) provides the pattern for skill fixes and verification. Its approach of surgical string replacements with exact old/new pairs, followed by grep regression tests, is the model for verification here.

### Roadmap Alignment

No ROADMAP.md loaded for this task.

## Goals & Non-Goals

**Goals**:
- Fix `.claude/extensions/lean/opencode-agents.json` to reference correct agent paths
- Backport `blocked-mcp-tools.md` and `mcp-fallback-table.md` index entries to `.opencode/extensions/lean/index-entries.json`
- Verify `.claude/` and `.opencode/` lean skills have no `OC_` prefix or `.language` field references
- Verify `.claude/extensions/lean/manifest.json` routing is correct
- Confirm no critical files are missing in either extension tree

**Non-Goals**:
- Porting the broader `.claude/` skill structural improvements (Stage 4b, postflight boundaries) to `.opencode/`
- Backporting the comprehensive `.claude/` README.md to `.opencode/`
- Adding `model: opus` frontmatter to `.opencode/` agents
- Modifying any files outside the lean extension trees

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixing opencode-agents.json breaks agent loading if format is wrong | High | Low | Verify JSON syntax after edit; test with jq |
| Other extensions have same opencode-agents.json bug | Medium | Medium | Note in summary for future audit task |
| Index entry format mismatch between systems | Low | Low | Use `.opencode/` minimal format (no domain/subdomain/summary) |
| Accidentally modifying wrong file | Medium | Low | Use exact Edit oldString/newString; verify with grep |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix opencode-agents.json Path Bug [NOT STARTED]

**Goal**: Fix the critical bug where `.claude/extensions/lean/opencode-agents.json` references non-existent `.opencode/agent/subagents/` paths.

**Tasks**:
- [ ] Read current `.claude/extensions/lean/opencode-agents.json`
- [ ] Update `lean-research` prompt path from `{file:.opencode/agent/subagents/lean-research-agent.md}` to `{file:.claude/extensions/lean/agents/lean-research-agent.md}`
- [ ] Update `lean-implementation` prompt path from `{file:.opencode/agent/subagents/lean-implementation-agent.md}` to `{file:.claude/extensions/lean/agents/lean-implementation-agent.md}`
- [ ] Validate JSON syntax with `jq empty`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/opencode-agents.json` - Update agent prompt file paths

**Verification**:
- `jq empty .claude/extensions/lean/opencode-agents.json` exits 0
- `grep -c ".opencode/agent/subagents" .claude/extensions/lean/opencode-agents.json` returns 0

---

### Phase 2: Backport Missing Index Entries to .opencode/ [NOT STARTED]

**Goal**: Add index entries for `blocked-mcp-tools.md` and `mcp-fallback-table.md` to `.opencode/extensions/lean/index-entries.json` so the `.opencode/` extension can discover these context files.

**Tasks**:
- [ ] Read current `.opencode/extensions/lean/index-entries.json`
- [ ] Add entry for `project/lean4/tools/blocked-mcp-tools.md` (minimal format: path, description, tags, load_when)
- [ ] Add entry for `project/lean4/patterns/mcp-fallback-table.md` (minimal format)
- [ ] Ensure entries use `.opencode/` format (no domain/subdomain/summary fields)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/lean/index-entries.json` - Add 2 missing entries

**Verification**:
- `jq '.entries | length' .opencode/extensions/lean/index-entries.json` returns 25 (was 23)
- `grep -c "blocked-mcp-tools" .opencode/extensions/lean/index-entries.json` returns 1
- `grep -c "mcp-fallback-table" .opencode/extensions/lean/index-entries.json` returns 1
- `jq empty .opencode/extensions/lean/index-entries.json` exits 0

---

### Phase 3: Verify Skills, Manifest, and Cross-Reference [NOT STARTED]

**Goal**: Verify that skills have no legacy references, manifest routing is correct, and both file trees are complete.

**Tasks**:
- [ ] Run `grep -rn "OC_" .opencode/extensions/lean/skills/` - expect 0 matches
- [ ] Run `grep -rn "\.language" .opencode/extensions/lean/skills/` - expect 0 matches
- [ ] Run `grep -rn "OC_" .claude/extensions/lean/skills/` - expect 0 matches
- [ ] Run `grep -rn "\.language" .claude/extensions/lean/skills/` - expect 0 matches
- [ ] Verify `.claude/extensions/lean/manifest.json` routing has `lean4`, `lean4:lake`, `lean4:version` keys
- [ ] Verify `.claude/extensions/lean/manifest.json` merge_targets includes `claudemd`, `settings`, `index`, `opencode_json`
- [ ] Verify `.opencode/extensions/lean/manifest.json` routing has `lean` and `lean4` keys
- [ ] Compare file trees: `find .opencode/extensions/lean -type f | sort` vs `find .claude/extensions/lean -type f | sort`
- [ ] Note any files present in one tree but not the other

**Timing**: 30 minutes

**Depends on**: 1, 2

**Files to modify**: None (verification only)

**Verification**:
- All grep commands return zero matches for legacy patterns
- Manifest routing confirmed correct in both trees
- File tree comparison documented in summary

---

### Phase 4: Final Validation and Summary [NOT STARTED]

**Goal**: Perform final validation, commit changes, and write implementation summary.

**Tasks**:
- [ ] Run any remaining validation checks
- [ ] Stage all modified files with `git add`
- [ ] Commit with message: `task 526: fix lean extension parity`
- [ ] Write summary at `specs/526_port_lean_extension_to_claude/summaries/01_lean-port-summary.md`

**Timing**: 30 minutes

**Depends on**: 3

**Files to modify**:
- `specs/526_port_lean_extension_to_claude/summaries/01_lean-port-summary.md` - Create summary

**Verification**:
- Summary file exists and documents all changes
- Git commit succeeds
- All modified files are accounted for

## Testing & Validation

- [ ] `jq empty .claude/extensions/lean/opencode-agents.json` passes
- [ ] `jq empty .opencode/extensions/lean/index-entries.json` passes
- [ ] No `.language` references in either skill tree
- [ ] No `OC_` prefix references in either skill tree
- [ ] Manifest routing verified in both trees
- [ ] File tree cross-reference complete

## Artifacts & Outputs

- `specs/526_port_lean_extension_to_claude/plans/01_lean-port-plan.md` (this file)
- `specs/526_port_lean_extension_to_claude/summaries/01_lean-port-summary.md`
- Modified: `.claude/extensions/lean/opencode-agents.json`
- Modified: `.opencode/extensions/lean/index-entries.json`

## Rollback/Contingency

If any change causes issues:
1. Revert the specific file using `git checkout -- <file>`
2. Re-run validation to confirm clean state
3. Document the issue in the summary for follow-up

If `opencode-agents.json` format is uncertain, keep a backup copy before editing.
