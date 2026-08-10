# Implementation Plan: Port generate-task-order.sh and Rewrite task-order-format.md

- **Task**: 579 - Port generate-task-order.sh + task-order-format.md
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/579_port_task_order_script/reports/01_port-task-order.md
- **Artifacts**: plans/01_port-task-order.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Port `generate-task-order.sh` (834 lines) from `/home/benjamin/Projects/ProofChecker/.claude/scripts/` to this repository's `.claude/scripts/`, removing the ProofChecker-specific `assign_topic_heuristic()` function (lines 204-231). Then fully rewrite `.claude/context/formats/task-order-format.md` from the current flat-category format (296 lines) to the wave+tree+topic format documented in the ProofChecker version (395 lines), replacing ProofChecker-specific examples and topic taxonomy with generic equivalents. Verify the ported script runs correctly against this repository's current `specs/state.json` and `specs/TODO.md`.

### Research Integration

Research report `reports/01_port-task-order.md` provides a complete section-by-section portability analysis of the 834-line script. Key findings integrated:
- Only `assign_topic_heuristic()` (lines 208-231) is ProofChecker-specific; all other 11 sections are directly portable
- The function is not called internally by the script (only exported for external callers like `/task`)
- Current core `task-order-format.md` uses an obsolete flat-category format with arrow-chain notation
- Current TODO.md already uses a wave-based format (hand-crafted), so the auto-generated output will be a format upgrade
- The script handles missing `topic`, `description`, and `active_topics` fields gracefully via jq defaults
- `update-task-status.sh` Phase 3 incompatibility is a task 581 concern, not in scope here

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Create `.claude/scripts/generate-task-order.sh` as a portable, project-agnostic script
- Fully replace the flat-category `task-order-format.md` with wave+tree+topic format documentation
- Verify the script produces correct output against the current repository state
- Ensure the script is executable and uses correct relative path resolution

**Non-Goals**:
- Implementing a topic heuristic for this project (task 582/583 scope)
- Updating `update-task-status.sh` Phase 3 for DFS tree format compatibility (task 581 scope)
- Adding `topic` or `active_topics` fields to current state.json entries (handled by downstream tasks)
- Modifying `update-recommended-order.sh` or the `## Recommended Order` section (separate section, unrelated)
- Integrating the script into commands like `/task`, `/todo`, `/review` (task 582/583 scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bash version < 4 (no associative arrays) | H | L | Script uses `declare -A`; NixOS/modern Linux always has bash 4+. Add version check if needed. |
| Current tasks lack `description` field in state.json | L | H | Script falls back to `project_name` -- acceptable display quality |
| Current tasks lack `topic` field | L | H | Script renders all tasks under `### Uncategorized` -- expected initial behavior |
| `active_topics` absent from state.json | L | M | Script handles gracefully, renders in encounter order |
| TODO.md Task Order section format mismatch on first run | L | L | Script replaces entire section atomically; clean transition from hand-crafted to generated format |
| Format doc examples do not match actual script output | M | M | Verify examples by running script with `--print` and comparing to documented format |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Port generate-task-order.sh [COMPLETED]

**Goal**: Create the ported script in `.claude/scripts/` with the ProofChecker-specific heuristic removed.

**Tasks**:
- [ ] Copy `/home/benjamin/Projects/ProofChecker/.claude/scripts/generate-task-order.sh` to `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`
- [ ] Remove `assign_topic_heuristic()` function and its section header comment (lines 204-231: the section divider comment block at 204-206, the documentation comment at 208-210, the function body at 211-231)
- [ ] Update the header comment block (lines 1-20) to reference core agent system paths instead of ProofChecker paths
- [ ] Make the script executable (`chmod +x`)
- [ ] Verify `${SCRIPT_DIR}/../..` resolves correctly from `.claude/scripts/` to the repo root

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - NEW file (copy from ProofChecker, remove heuristic function, update header)

**Verification**:
- File exists at `.claude/scripts/generate-task-order.sh` and is executable
- `grep -c 'assign_topic_heuristic' .claude/scripts/generate-task-order.sh` returns 0
- `bash -n .claude/scripts/generate-task-order.sh` passes syntax check
- Line count is approximately 806 lines (834 minus ~28 lines for the removed function and comments)

---

### Phase 2: Rewrite task-order-format.md [COMPLETED]

**Goal**: Replace the flat-category format documentation with the wave+tree+topic format, using generic examples.

**Tasks**:
- [ ] Read the ProofChecker `task-order-format.md` (395 lines) as the structural template
- [ ] Replace the current core `task-order-format.md` (296 lines) entirely with the new format
- [ ] Keep universal sections verbatim from ProofChecker: Placement, Structure Elements, Wave Table format, Grouped Topic Sections format, DFS tree entry format, Status Markers, Parsing Patterns Summary, Generation Algorithm, Script Usage, update-task-status.sh Integration (Mode A/Mode B)
- [ ] Replace ProofChecker Topic Taxonomy table (7 hardcoded topics) with a generic explanation: topics come from `active_topics` in state.json, no hardcoded taxonomy, projects define their own
- [ ] Replace all ProofChecker-specific examples (Lean task names like "Jonsson-Tarski", "Wire the TimelineQuot BFMCS") with generic agent-system style examples (e.g., "Port task order script", "Update command integration", "Configure LSP settings")
- [ ] Remove `assign_topic_heuristic()` cross-reference (lines 122-124 of ProofChecker version)
- [ ] Add notes about: topics being optional (fallback to `### Uncategorized`), `active_topics` controlling render order, how to configure topics
- [ ] Add a "Historical Format" appendix section briefly describing the old flat-category format that was replaced, for reference
- [ ] Ensure format doc examples match actual `generate-task-order.sh` output format

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/context/formats/task-order-format.md` - FULL REWRITE (replace 296-line flat-category format with ~395-line wave+tree+topic format)

**Verification**:
- File has the wave+tree+topic structure elements documented
- No ProofChecker-specific keywords (bilateral, BFMCS, Jonsson, Tarski, algebraic, decidability) appear
- No reference to `assign_topic_heuristic()`
- Generic examples use agent-system style task names
- Parsing patterns summary covers all regex patterns for the new format
- Mode A/Mode B integration section is present

---

### Phase 3: Test and Verify Integration [COMPLETED]

**Goal**: Run the script against the current repository state and verify correct output.

**Tasks**:
- [ ] Run `.claude/scripts/generate-task-order.sh --print` and verify it produces valid wave table and grouped section output
- [ ] Verify the output handles current tasks (which lack `topic` and `description` fields) gracefully
- [ ] Check that all active tasks from state.json appear in the output
- [ ] Compare output format against the documented format in the rewritten `task-order-format.md`
- [ ] Run `.claude/scripts/generate-task-order.sh --update-todo` on a temporary copy of TODO.md to verify atomic section replacement works correctly (do NOT modify the actual TODO.md without user approval)
- [ ] Fix any issues discovered during testing (path resolution, missing fields, format mismatches)

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/scripts/generate-task-order.sh` - Potential fixes from testing
- `.claude/context/formats/task-order-format.md` - Potential fixes if examples do not match actual output

**Verification**:
- `--print` mode produces non-empty, well-formatted output with wave table and grouped sections
- `--update-todo` mode correctly replaces the `## Task Order` section in a test copy of TODO.md
- All active tasks from state.json appear in the output
- No bash errors or warnings during execution
- Script exits with code 0 in all modes

## Testing & Validation

- [ ] `bash -n .claude/scripts/generate-task-order.sh` passes syntax check
- [ ] `generate-task-order.sh --print` produces valid Markdown output
- [ ] Output includes a wave table with correct column headers
- [ ] Output includes grouped sections (at minimum `### Uncategorized`)
- [ ] All active tasks from state.json appear in the output
- [ ] `generate-task-order.sh --update-todo` replaces the correct TODO.md section atomically
- [ ] No ProofChecker-specific content remains in either artifact
- [ ] Format doc examples match actual script output structure

## Artifacts & Outputs

- `.claude/scripts/generate-task-order.sh` - New script (ported from ProofChecker, ~806 lines)
- `.claude/context/formats/task-order-format.md` - Full rewrite (~395 lines)
- `specs/579_port_task_order_script/plans/01_port-task-order.md` - This plan

## Rollback/Contingency

- The script is a new file; rollback is simply `rm .claude/scripts/generate-task-order.sh`
- `task-order-format.md` can be reverted via `git checkout -- .claude/context/formats/task-order-format.md`
- If `--update-todo` causes issues, TODO.md can be reverted via `git checkout -- specs/TODO.md`
- The old flat-category format is preserved in git history for reference
