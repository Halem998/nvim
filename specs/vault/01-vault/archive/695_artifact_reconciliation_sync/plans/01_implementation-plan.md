# Implementation Plan: Task #695 - Add Artifact Reconciliation to /task --sync

- **Task**: 695 - Add artifact reconciliation to /task --sync
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/695_artifact_reconciliation_sync/reports/01_artifact-reconciliation-research.md
- **Artifacts**: plans/01_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a `reconcile-artifacts.sh` script that scans task directories for artifact files not registered in state.json and backfills them with append-only semantics. Integrate this as Step 2.5 in the `--sync` mode of `task.md`, running before the `generate-todo.sh` call so that one regeneration captures all backfilled artifacts. The script follows the established pattern from `reconcile-task-status.sh` but uses append-only deduplication (not replace-by-type) to correctly handle team research with multiple report files.

### Research Integration

Key findings from the research report:
- 53 missing artifact registrations across 21 completed tasks (all historical, pre-postflight system)
- `generate-todo.sh` already reads from state.json -- fixing state.json is sufficient
- `reconcile-task-status.sh` has reusable `artifact_already_linked()` pattern
- Type inference: `reports/` -> "report", `plans/` -> "plan", `summaries/` -> "summary"
- Must use `select(.x == $y | not)` instead of `!=` for jq safety (Issue #1132)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Backfill all missing artifact registrations in state.json during `--sync`
- Support `--dry-run` for safe pre-flight inspection
- Handle edge cases: padded/unpadded directories, team research with multiple reports, idempotency
- Integrate cleanly into the existing `--sync` flow with one line of code

**Non-Goals**:
- Reconciling archived tasks (out of scope -- only active_projects)
- Modifying postflight scripts (they work correctly for new tasks)
- Changing how `generate-todo.sh` renders artifacts (it already handles the types we produce)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq Issue #1132 parse errors | H | M | Use "select(... | not)" pattern exclusively, no `!=` |
| Duplicate artifact entries on re-run | M | L | Path-based deduplication check before every append |
| Wrong type for non-standard filenames | L | L | All .md files in reports/ get "report" -- consistent with generate-todo.sh |
| Parent config task.md has different sync mode | M | Certain | Only update nvim project + extension core copies; parent copy has older format |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create reconcile-artifacts.sh [COMPLETED]

**Goal**: Create the standalone reconciliation script with --dry-run support.

**Tasks**:
- [x] Create `.claude/scripts/reconcile-artifacts.sh` with:
  - Argument parsing: `[--dry-run]` flag
  - Read all active tasks from `specs/state.json` via jq
  - For each task: resolve directory (check both padded `{NNN}_{slug}` and unpadded `{N}_{slug}`)
  - For each of `reports/`, `plans/`, `summaries/`: enumerate `.md` files
  - Type inference: `reports/` -> `"report"`, `plans/` -> `"plan"`, `summaries/` -> `"summary"`
  - Deduplication check using `jq ... | grep -qF "$rel_path"` pattern (from `reconcile-task-status.sh` lines 96-103)
  - Append-only registration: single jq step to add `{"path", "type", "summary"}` to `.artifacts` array (no remove-by-type step, unlike postflight)
  - Summary generation: clean filename to human-readable text with " (backfilled by --sync)" suffix
  - Use `specs/tmp/` for jq atomic writes with `mkdir -p specs/tmp`
  - Report totals: "Backfilled N artifacts for M tasks" or "No artifact gaps found" *(completed)*
- [x] Make script executable: `chmod +x .claude/scripts/reconcile-artifacts.sh` *(completed)*
- [x] Test with `--dry-run` against current nvim project state.json *(completed: 54 artifacts found across 22 tasks)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/reconcile-artifacts.sh` - New file (~80-100 lines)

**Verification**:
- `bash .claude/scripts/reconcile-artifacts.sh --dry-run` reports expected gap count (53 missing across 21 tasks)
- Running without `--dry-run` followed by a second run produces "No artifact gaps found" (idempotency)
- `jq '.active_projects[] | select(.project_number == 638) | .artifacts | length' specs/state.json` returns 3 (previously 0)

---

### Phase 2: Integrate into task.md --sync mode [COMPLETED]

**Goal**: Add a reconcile-artifacts.sh call as Step 2.5 in the --sync flow, before generate-todo.sh.

**Tasks**:
- [x] Edit `.claude/commands/task.md` to insert Step 2.5 between the current Step 2 (orphan detection, ending at line 403) and Step 3 (generate-todo.sh, starting at line 405). *(completed)*
- [x] Copy the updated task.md to `.claude/extensions/core/commands/task.md` (keep in sync) *(completed: diff is empty)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/task.md` - Insert Step 2.5 after line 403 (project copy, lines 382-433 = sync section)
- `.claude/extensions/core/commands/task.md` - Mirror same edit (identical to project copy)

**Verification**:
- `diff .claude/commands/task.md .claude/extensions/core/commands/task.md` produces no output
- Running `/task --sync` executes reconciliation then regenerates TODO.md with all artifacts visible

---

### Phase 3: Validate end-to-end and clean up [COMPLETED]

**Goal**: Run full sync, verify TODO.md renders correctly, confirm idempotency.

**Tasks**:
- [x] Run `bash .claude/scripts/reconcile-artifacts.sh` (live mode) to backfill all 53 missing artifacts *(completed: 54 backfilled across 22 tasks)*
- [x] Run `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md *(completed)*
- [x] Spot-check TODO.md for tasks 638, 647, 669 (highest gap counts) to confirm artifacts appear *(completed: 638=3 artifacts, 647=5, 669=8)*
- [x] Run `bash .claude/scripts/reconcile-artifacts.sh` again to confirm "No artifact gaps found" (idempotency) *(completed)*
- [x] Verify no duplicate entries *(completed: returns [])*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- `specs/state.json` - Modified by reconciliation (artifact backfill)
- `specs/TODO.md` - Regenerated by generate-todo.sh

**Verification**:
- TODO.md shows Research/Plan/Summary artifact links for previously-gap tasks
- state.json has no duplicate artifact paths
- Second reconciliation run is a no-op

## Testing & Validation

- [ ] `--dry-run` mode reports correct gap count without modifying state.json
- [ ] Live mode backfills all missing artifacts and reports totals
- [ ] Idempotency: second run produces zero changes
- [ ] No duplicate paths in state.json artifacts arrays
- [ ] TODO.md renders artifacts correctly after regeneration
- [ ] Task 647 (team research, 3 reports) shows all 3 as separate Research entries
- [ ] diff between project and extension core task.md copies is empty

## Artifacts & Outputs

- `.claude/scripts/reconcile-artifacts.sh` - New reconciliation script
- `.claude/commands/task.md` - Updated with Step 2.5
- `.claude/extensions/core/commands/task.md` - Mirror of updated task.md
- `specs/state.json` - Backfilled artifact entries
- `specs/TODO.md` - Regenerated with complete artifact visibility

## Rollback/Contingency

If reconciliation produces incorrect state:
1. `git checkout specs/state.json` to restore pre-reconciliation state
2. `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md
3. If the script itself is faulty, remove `.claude/scripts/reconcile-artifacts.sh` and revert the task.md Step 2.5 insertion
