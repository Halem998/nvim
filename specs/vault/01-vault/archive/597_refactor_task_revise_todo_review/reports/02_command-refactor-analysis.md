# Research Report: Task #597 — Command Refactor Analysis

**Task**: 597 — Refactor /task, /revise, /todo, /review for consistency with new architecture
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:45:00Z
**Effort**: Medium (codebase analysis, no web research needed)
**Dependencies**: Task 593 (shared utilities — complete), Task 596 (orchestrator — complete)
**Sources/Inputs**:
- `specs/597_refactor_task_revise_todo_review/reports/01_seed-research.md`
- `specs/597_refactor_task_revise_todo_review/reports/03_design-guidance.md`
- `.claude/commands/task.md` (710L)
- `.claude/commands/revise.md` (160L)
- `.claude/commands/todo.md` (1046L)
- `.claude/commands/review.md` (1039L)
- `.claude/scripts/command-gate-in.sh`, `command-gate-out.sh`, `skill-base.sh`, `parse-command-args.sh`
- `.claude/skills/skill-orchestrate/SKILL.md`
- `.claude/scripts/dispatch-agent.sh`
- `specs/state.json` (memory candidate data)
- `.memory/10-Memories/` (current vault size)
**Artifacts**:
- `specs/597_refactor_task_revise_todo_review/reports/02_command-refactor-analysis.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- All four commands are at or above their design-guidance target sizes, none have been refactored yet
- `/task` (710L) has 5 independent modes; shared gate-in/gate-out applies only to modes 2, 3, 5 (recover, expand, abandon)
- `/revise` (160L) is almost at its 120L target; primary change is `orchestrator_mode` handoff support, already scaffolded in `skill-base.sh`'s `skill_write_orchestrator_handoff()`
- `/todo` (1046L) needs 5 utility modules extracted (4 existing + 1 new); 46 archived tasks in archive/state.json have `memory_candidates`, confirming the harvest gap
- `/review` (1039L) needs 3 utility modules extracted; its issue-grouping algorithm (sections 5.5.2–5.5.5) is the heaviest extraction target at ~180L
- `memory-harvest.sh` is the highest-priority deliverable: currently 0 of 5 planned utility scripts exist

---

## Context & Scope

Task 597 applies the shared infrastructure from task 593 (command-gate-in.sh, command-gate-out.sh, skill-base.sh, parse-command-args.sh) to four secondary commands not covered by task 595. The task also integrates orchestrator handoff support from task 596 into /revise, decomposes /todo and /review into reusable utility modules, and adds automatic memory harvest to /todo's archival pipeline.

**Dependency status**: Task 593 is complete (all 4 shared scripts exist). Task 596 is complete (skill-orchestrate/SKILL.md live, dispatch-agent.sh live, skill_write_orchestrator_handoff() in skill-base.sh).

**No new utility modules exist yet**: `archive-task.sh`, `orphan-detection.sh`, `roadmap-sync.sh`, `vault-operation.sh`, `memory-harvest.sh`, `issue-grouping.sh`, `roadmap-integration.sh`, `tier-selection.sh` — all absent from `.claude/scripts/`.

---

## Findings

### 1. /task (710L) — Shared Utilities Integration

**Current structure**: 5 modes dispatched via `$ARGUMENTS` flag detection. Each mode is a self-contained inline section using direct `jq`, `mv`, and `sed` operations.

**What can use shared gate-in**: Three modes perform task-number-based operations and can use `command-gate-in.sh`:
- `--recover N` (mode 2): Task lookup from archive/state.json (slightly different — reads archive, not active)
- `--expand N` (mode 3): `gate_in $task_number expand`
- `--abandon N` (mode 5): `gate_in $task_number abandon`

**What cannot use shared gate-in**: Two modes don't need it:
- Create (mode 1): No task number exists yet
- `--sync` (mode 4): Bulk operation, no per-task gate

**What can use parse-command-args.sh**: Modes 2, 3, 5 use `--flag N` syntax which `parse-command-args.sh` can parse for the task number extraction. However, mode 1 has free-form text input that would conflict with the script's leading-digit regex. The script should only be sourced for flagged modes.

**Key redundancy identified**: Modes 2 (recover), 3 (expand), and 5 (abandon) all contain the same pattern:
```bash
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)
if [ -z "$task_data" ]; then echo "Error: Task $task_number not found"; exit 1; fi
```
This 4-line block appears 3 times. The gate-in script eliminates all three.

**Line count reduction estimate**: Removing inline gate-in logic from 3 modes saves ~30L (10L each). Additional savings from replacing inline session ID generation (~5L per mode) = ~15L. Total reduction: ~45L. From 710L to ~665L before other simplifications.

**Review mode (--review N)**: This is the most complex mode at ~240L (lines 380-645). It loads artifacts, parses plan phases, generates follow-up suggestions, and creates tasks via AskUserQuestion. The shared gate-in applies for task lookup, but the mode's unique logic is extensive enough that decomposition into a utility function is not the primary focus of task 597. Design guidance targets 300L for the whole file.

### 2. /revise (160L) — Orchestrator Handoff Integration

**Current structure**: 3 checkpoints (GATE IN, DELEGATE, GATE OUT) using inline jq. Already compact. The command correctly delegates to `skill-reviser` and verifies status in GATE OUT.

**What can use shared infrastructure**: 
- CHECKPOINT 1 (GATE IN, lines 22-51) can source `command-gate-in.sh` replacing inline session ID generation and task lookup (~15L reduction)
- CHECKPOINT 3 (GATE OUT, lines 80-116) can call `command-gate-out.sh` replacing the inline defensive correction (~20L reduction)

**Orchestrator handoff requirement**: The design guidance specifies that when `orchestrator_mode=true` is in the delegation context, `/revise` should write `.orchestrator-handoff.json`. However, `/revise` is a command (not a skill) and receives `$ARGUMENTS`, not a `delegation_context` JSON. The `orchestrator_mode` flag needs to be passed differently.

**Implementation approach**: The cleanest approach is to add `--orchestrator` as a recognized argument flag:
```bash
# Parse new flag
orchestrator_mode="false"
if [[ "$ARGUMENTS" =~ --orchestrator ]]; then
  orchestrator_mode="true"
fi
```
Then after delegation to skill-reviser, if `orchestrator_mode=true`, read the skill return metadata and write the handoff file using `skill_write_orchestrator_handoff()` from `skill-base.sh`.

**Alternative**: The design guidance shows reading delegation context JSON, but the current revise.md does not receive delegation context — it receives `$ARGUMENTS`. The `--orchestrator` flag approach is simpler and consistent with how other flags work in this command system.

**Current line count**: 160L (vs 161L in design guidance). Target is 120L. With shared gate-in/gate-out, expect ~125L — very close.

### 3. /todo (1046L) — Decomposition into Utility Modules

**Current structure analysis** (by line range):
- Lines 1-26: Arguments, scan for archivable tasks
- Lines 27-88: Orphan detection (Step 2.5) — ~62L, candidate for `orphan-detection.sh`
- Lines 89-123: Misplaced directory detection (Step 2.6) — ~35L, could merge with orphan-detection
- Lines 124-260: Roadmap scan/matching (Step 3.5) — ~137L, candidate for `roadmap-sync.sh`
- Lines 261-378: Dry-run output + interactive orphan handling — ~117L, keeps inline
- Lines 379-522: Archive operations (Steps 5A-5F) — ~143L, partially for `archive-task.sh`
- Lines 523-596: Roadmap update application (Step 5.5) — ~73L, completes `roadmap-sync.sh`
- Lines 597-692: Metrics sync (Step 5.6) — ~95L, candidate for metrics module
- Lines 693-828: Vault operation (Step 5.7) — ~135L, candidate for `vault-operation.sh`
- Lines 829-1047: Git commit, output, notes — ~218L, mostly docs/notes

**Missing module**: `memory-harvest.sh` — NEW, not present. This is called before archiving each task to harvest `memory_candidates` from state.json.

**Memory harvest gap — confirmed**: Archive state.json has 46 completed tasks with `memory_candidates`. Active state.json has 1 completed task (595) with `memory_candidates`. The memory vault at `.memory/10-Memories/` contains only 4 memory files. This confirms the gap identified in seed research: ~50 unharvested task memory candidates.

**Extraction plan for utility modules**:

1. **`orphan-detection.sh`**: Extract Steps 2.5-2.6 (lines 27-123, ~100L). Input: specs/ directory, state.json, archive/state.json. Outputs: prints orphaned dirs and misplaced dirs as newline-separated lists. The `/todo` command sources the output and uses the lists.

2. **`roadmap-sync.sh`**: Extract Steps 3.5 (lines 124-260) and 5.5 (lines 523-596), ~210L combined. This is larger than the 120L estimate in design guidance. The roadmap scan and application share state (roadmap_matches array) so they should be in the same script. Input: task array, ROADMAP.md path. Output: applies roadmap annotations and reports count.

3. **`archive-task.sh`**: Extract core archival logic from Step 5 (archive state update + directory move, ~80L from 5A-5D). Input: task_number, task_slug, dry_run flag. Output: moves directory, returns 0/1.

4. **`vault-operation.sh`**: Extract Step 5.7 (lines 693-828, ~135L). Input: state.json, confirmation flag. Output: creates vault, renumbers, resets state.

5. **`memory-harvest.sh`** (NEW): Algorithm per design guidance. Input: task_number, memory_candidates JSON. Output: writes to .memory/10-Memories/, updates .memory/memory-index.json.

**Post-extraction estimate**: /todo drops from 1046L to ~450L (remaining: argument parsing, orphan/misplaced prompts, dry-run output, main archival loop coordination, metrics sync inline, git commit, output sections, and notes).

### 4. /review (1039L) — Decomposition into Reusable Components

**Current structure analysis** (by line range):
- Lines 1-31: Arguments, scope detection
- Lines 32-48: Review state loading
- Lines 49-116: Gather context (Lua, general, docs patterns)
- Lines 117-296: Roadmap integration (Steps 2.5-2.5.3) — ~180L, candidate for `roadmap-integration.sh`
- Lines 297-374: Parse task order (Step 2.6) — ~77L
- Lines 375-406: Analyze findings (Step 3) — ~32L, stays inline
- Lines 407-424: Create review report (Step 4) — ~17L template ref
- Lines 425-428: Update review state (Step 4.5)
- Lines 429-524: Task proposal mode + issue collection (Step 5-5.5.1)
- Lines 525-569: Issue grouping indicators (Step 5.5.2) — ~45L
- Lines 570-520: Clustering algorithm (Step 5.5.3) — ~50L
- Lines 521-569: Group post-processing (Step 5.5.4) — ~48L
- Lines 570-570: Scoring (Step 5.5.5) — ~12L
- Lines 571-820: Tier selection, task creation (Steps 5.5.6-5.6.4) — ~250L, candidate for `tier-selection.sh`
- Lines 821-987: Task Order management (Steps 6-6.7) — ~165L
- Lines 988-1039: Git commit, standards reference, output

**Three extraction targets confirmed**:

1. **`issue-grouping.sh`**: Steps 5.5.2–5.5.5 (extract grouping indicators, clustering algorithm, post-processing, scoring), approximately lines 525-570 = ~180L. Input: issue list JSON array. Output: grouped issues JSON with scores. This is the most well-bounded extraction since it operates only on the issue list.

2. **`roadmap-integration.sh`**: Steps 2.5-2.5.3 (parse ROADMAP.md, cross-reference with state, annotate) = ~180L. Input: ROADMAP.md path, completed tasks from state.json. Output: annotated roadmap + roadmap_state JSON structure for downstream use.

3. **`tier-selection.sh`**: Steps 5.5.6-5.5.7 (interactive group selection Tier 1 + granularity Tier 2 + manual Tier 3) = ~100L. Input: grouped issues JSON. Output: selected issues list for task creation.

**Post-extraction estimate**: /review drops from 1039L to ~450L (remaining: argument parsing, review state loading, context gathering, report creation, task creation logic from selection, task order management, git commit).

### 5. Shared Infrastructure — Integration Readiness

**command-gate-in.sh** (sourced): 74L. Exports SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM. Works for any operation with a task number. Note: for `/task --recover`, the task is in archive/state.json not active_projects — the gate-in script only reads active_projects. The recover mode needs special handling or a separate lookup.

**command-gate-out.sh** (called as subprocess): 82L. Reads .return-meta.json and applies defensive status correction. Applicable to /revise (it has a skill return). Not applicable to /task or /todo (which manage state directly, no skill delegation). Applicable to /review only if /review is refactored to delegate to a sub-skill (not planned for task 597).

**skill-base.sh**: Provides `skill_write_orchestrator_handoff()` which /revise can call post-delegation to write the handoff file. This function already handles the orchestrator_mode guard.

**parse-command-args.sh**: Primarily for multi-task commands. For /task's flagged modes, the task number is already inline in the flag (`--abandon N`), but the script's leading-digit regex won't match `--abandon 597`. The flagged modes in /task parse the task number differently (after the flag). `parse-command-args.sh` is NOT directly applicable to /task without a wrapper — the modes use custom argument structures.

---

## Decisions

1. **`parse-command-args.sh` not used in /task**: The script expects leading task numbers or ranges (e.g., `597`, `22-24`). The /task command modes use `--flag N` syntax, which the script doesn't handle. Task modes should continue using inline argument parsing.

2. **`command-gate-out.sh` not applicable to /todo or /review**: These commands don't delegate to skills and don't produce .return-meta.json files. Gate-out is only for skill-delegating commands (/research, /plan, /implement, /revise).

3. **`command-gate-in.sh` not applicable to /todo or /review**: These commands don't operate on single task numbers via the standard active_projects lookup. They process lists of tasks or work at the codebase scope.

4. **`--orchestrator` flag for /revise**: Add `--orchestrator` as a recognized flag in /revise's ARGUMENTS parsing. When set, source skill-base.sh and call `skill_write_orchestrator_handoff()` after delegation.

5. **`memory-harvest.sh` is highest priority**: It closes a known information loss gap (50 archived tasks with uncaptured memory_candidates). Should be implemented and integrated before other /todo decomposition.

6. **Roadmap sync as single module**: Design guidance split roadmap into separate scan and application phases. Since they share state (roadmap_matches array), combining into one `roadmap-sync.sh` is cleaner.

---

## Recommendations

**Priority order for implementation**:

### P1: Create `memory-harvest.sh` and integrate into /todo (Critical)
- Write `.claude/scripts/memory-harvest.sh` (~100L)
- Integrate into /todo's archival loop before archive step
- Use existing memory skill's create path (write to `.memory/10-Memories/`, update `.memory/memory-index.json`)
- Filter: only harvest candidates with `confidence >= 0.7`
- Report count in /todo output

### P2: Create the 4 /todo utility modules
- `archive-task.sh` (~80L): core archive operation
- `orphan-detection.sh` (~100L): Steps 2.5-2.6
- `roadmap-sync.sh` (~210L): Steps 3.5 + 5.5 combined
- `vault-operation.sh` (~135L): Step 5.7
- Target: /todo reduced from 1046L to ~450L

### P3: Update /revise with orchestrator handoff
- Add `--orchestrator` flag parsing
- Source `command-gate-in.sh` for CHECKPOINT 1 (~15L reduction)
- Call `command-gate-out.sh` in CHECKPOINT 3 (~20L reduction)
- Add `skill_write_orchestrator_handoff()` call after skill-reviser returns
- Target: /revise reduced from 160L to ~125L

### P4: Create the 3 /review utility modules
- `issue-grouping.sh` (~180L): Steps 5.5.2-5.5.5
- `roadmap-integration.sh` (~180L): Steps 2.5-2.5.3
- `tier-selection.sh` (~100L): Steps 5.5.6-5.5.7
- Target: /review reduced from 1039L to ~450L

### P5: Update /task for gate-in integration
- Apply `command-gate-in.sh` to modes 2 (expand), 5 (abandon)
- Mode 3 (recover) needs archive lookup — adapt gate-in or use inline
- Target: /task reduced from 710L to ~650L (limited reduction; bulk of content is unique mode logic)

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `/todo` decomposition corrupts state.json or archive/state.json | High | Extract one module at a time; test each extraction with a dry-run before connecting |
| `memory-harvest.sh` creates duplicate memories | Medium | Check deduplication logic in memory-index.json; use confidence threshold >= 0.7 |
| `/revise` orchestrator handoff triggers incorrectly | Low | Guard with explicit `--orchestrator` flag; don't auto-detect from context |
| `archive-task.sh` misses legacy unpadded directory handling | Medium | Preserve both padded and unpadded directory format checks from current inline logic |
| `roadmap-sync.sh` produces incorrect annotation matches | Medium | Preserve exact match priority order (explicit > exact > summary) from current inline logic |
| `issue-grouping.sh` clustering algorithm breaks on edge cases | Low | Unit test with single-issue and empty inputs; cap groups at 10 as current logic specifies |

---

## Context Extension Recommendations

- **Topic**: Memory harvest automation pattern
- **Gap**: No documentation exists for the memory harvest integration pattern — how `/todo` calls `memory-harvest.sh` and how confidence thresholds work
- **Recommendation**: After implementing `memory-harvest.sh`, add a context file documenting the harvest pattern to `.claude/context/patterns/memory-harvest-pattern.md`

---

## Appendix

### Actual Line Counts (verified)

| Command | Current Lines | Design Target | Gap |
|---------|--------------|---------------|-----|
| task.md | 710 | ~300L | -410L |
| revise.md | 160 | ~120L | -40L |
| todo.md | 1046 | ~400L | -646L |
| review.md | 1039 | ~400L | -639L |

### Scripts Already Available (task 593)

| Script | Size | Applicable To |
|--------|------|---------------|
| command-gate-in.sh | 74L | /revise (modes 3,5 in /task) |
| command-gate-out.sh | 82L | /revise only |
| skill-base.sh | 364L | /revise (via skill_write_orchestrator_handoff) |
| parse-command-args.sh | 124L | Not directly useful for /task or /todo |

### Scripts to Create (task 597)

| Script | Size Estimate | Extracted From |
|--------|--------------|----------------|
| memory-harvest.sh | ~100L | NEW (not currently in /todo) |
| archive-task.sh | ~80L | /todo Steps 5A-5D |
| orphan-detection.sh | ~100L | /todo Steps 2.5-2.6 |
| roadmap-sync.sh | ~210L | /todo Steps 3.5 + 5.5 |
| vault-operation.sh | ~135L | /todo Step 5.7 |
| issue-grouping.sh | ~180L | /review Steps 5.5.2-5.5.5 |
| roadmap-integration.sh | ~180L | /review Steps 2.5-2.5.3 |
| tier-selection.sh | ~100L | /review Steps 5.5.6-5.5.7 |

### Memory Gap Data

- Archive tasks with `memory_candidates`: 46
- Active completed tasks with `memory_candidates`: 1 (task 595)
- Current vault memories: 4 files in `.memory/10-Memories/`
- Unharvested candidates: ~47 task records
