# Research Report: Task #695 - Add Artifact Reconciliation to /task --sync

**Task**: 695 - Add artifact reconciliation to /task --sync
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (task.md, postflight scripts, generate-todo.sh, reconcile-task-status.sh)
**Artifacts**: specs/695_artifact_reconciliation_sync/reports/01_artifact-reconciliation-research.md
**Standards**: report-format.md

---

## Executive Summary

- **53 missing artifact registrations** exist across 21 active tasks (all completed). Artifacts are present on disk but not registered in state.json, making them invisible in TODO.md.
- The root cause is that postflight scripts (postflight-research.sh, postflight-plan.sh, postflight-implement.sh) register artifacts at completion time, but many tasks were completed before the unified postflight system (task 593) was introduced or before the system correctly called these scripts.
- **The fix is entirely in `state.json` backfill**: since `generate-todo.sh` reads directly from `state.json.artifacts`, fixing state.json is sufficient to fix TODO.md rendering — no TODO.md edits needed.
- The reconciliation step should be added to `--sync` mode in `task.md` after step 3 (regenerate TODO.md) and before step 6.5 (topic backfill).
- An existing `reconcile-task-status.sh` covers a related but different gap (stuck in-flight status promotion). The new reconciliation is complementary: it handles **completed tasks with missing artifact registrations**, while the existing script handles **in-flight tasks with completed artifacts**.

---

## Context & Scope

### What Was Researched

1. The `--sync` mode in `.claude/commands/task.md` (lines 382-433)
2. The three postflight scripts that register artifacts in state.json
3. `generate-todo.sh` — how it renders artifacts from state.json
4. The artifacts array schema in state.json
5. The existing `reconcile-task-status.sh` script for related patterns
6. Actual gap measurement: 53 missing registrations across 21 tasks on disk

### Constraints

- Must use jq two-step pattern to avoid Claude Code Issue #1132 (`!=` escaping bug)
- Must not create a new script for reconciliation unless truly necessary (could be inline logic or a new script called from --sync)
- Must handle both padded (`695_slug`) and unpadded (`695_slug`) directory formats
- Must handle archived tasks (they have directories under `specs/archive/`, not `specs/`)
- Must not overwrite existing artifact registrations
- Must infer artifact type from directory name (reports/ -> "report", plans/ -> "plan", summaries/ -> "summary")

---

## Findings

### Current Artifact Tracking Flow

**Registration path**:
1. Agent writes artifact file to `specs/{NNN}_{SLUG}/reports|plans|summaries/`
2. Agent calls postflight script (e.g., `postflight-research.sh TASK_NUM PATH SUMMARY`)
3. Postflight script: replaces any existing artifact of the same type, adds new entry
4. `generate-todo.sh` reads `state.json.active_projects[n].artifacts[]` and renders them

**State.json artifact schema**:
```json
{
  "path": "specs/695_slug/reports/01_research.md",
  "type": "research|report|plan|summary|implementation",
  "summary": "Brief description of content"
}
```

**Type conventions** (from postflight scripts + generate-todo.sh):
- `reports/` directory → type `"research"` (postflight-research.sh) or `"report"` (older tasks)
- `plans/` directory → type `"plan"` (postflight-plan.sh)
- `summaries/` directory → type `"summary"` (postflight-implement.sh)
- generate-todo.sh renders `research|report` as "Research", `plan` as "Plan", `summary|implementation` as "Summary"

**Postflight deduplication**: Each postflight script does a "replace" operation — it removes all artifacts of the same type, then adds the new one. This means multiple research reports cannot coexist via the postflight path (though they can exist on disk). The reconciliation should use an "append if not already registered" approach instead.

### Gap Analysis: Actual Data

**53 missing artifact registrations across 21 active tasks** (all completed status):

| Task | Gap Description |
|------|----------------|
| 638 | reports=1, plans=1, summaries=1; state_artifacts=0 |
| 639 | reports=1, plans=1; state_artifacts=1 (only summary) |
| 647 | reports=3 on disk, state_artifacts=1 (team research: 2 teammate files unregistered) |
| 654 | reports=1, summaries=1; state_artifacts=1 (only plan) |
| 655 | reports=1, plans=1, summaries=1; state_artifacts=0 |
| 656 | reports=1, plans=1, summaries=1; state_artifacts=0 |
| 662 | reports=1, plans=1; state_artifacts=0 |
| 663-668 | Each: reports=1, plans=1, summaries=1; state_artifacts=0 |
| 669 | reports=6 on disk (team), state=2; summaries=1 state=0 |
| 670 | summaries=1, state=0 |
| 675-679 | various gaps |
| 682 | summaries=1, state=0 |

**All gaps are in completed tasks.** No active (non-completed) tasks have missing artifact registrations. This confirms the gap is a historical issue from before the postflight system was fully integrated.

### Existing reconcile-task-status.sh Analysis

The existing `reconcile-task-status.sh` script handles a **complementary but different problem**:
- It promotes **in-flight tasks** (researching/planning/implementing) to their next status when artifacts exist
- It does NOT handle completed tasks with missing artifact registrations
- It calls `link_artifact()` which does register artifacts in state.json (using the two-step jq pattern)
- However, it only fires when status is one of: researching, planning, implementing, partial

The `link_artifact()` helper in that script is reusable logic for the reconciliation — it checks `artifact_already_linked()` before registering. **This helper pattern should be adapted for the new reconciliation**.

### generate-todo.sh Analysis

The `generate_task_entry()` function (lines 157-303) reads `state.json` and renders artifacts from `.artifacts[]`. Key behavior:
- Groups artifacts by display type (research|report -> "Research", plan -> "Plan", summary|implementation -> "Summary")
- If multiple artifacts of same display type, renders a multi-line list
- Single artifact: inline format `- **Research**: [path]`
- Multiple artifacts: `- **Research**:\n  - [path1]\n  - [path2]`

**Critical insight**: Since generate-todo.sh always regenerates TODO.md fully from state.json, there is **no need to directly edit TODO.md** during reconciliation. Simply updating state.json and then calling generate-todo.sh is sufficient.

### --sync Mode Current Flow (task.md)

```
Step 1: Validate state.json integrity (jq empty check)
Step 2: Identify orphan TODO.md tasks (warn-only)
Step 3: Regenerate TODO.md from state.json (bash generate-todo.sh)
[GAP: No artifact reconciliation]
Step 6.5: Topic backfill for tasks missing topic field
Step 7: Git commit
```

Note: Steps 4 and 5 appear to be numbered 6.5 and 7 in the actual file. The numbering in the file has a jump from step 3 to 6.5.

---

## Proposed Reconciliation Algorithm

### Integration Point

Insert as **Step 3.5** in `--sync` mode, after regenerating TODO.md and before topic backfill.

This ordering is correct because:
1. Step 3 (generate-todo.sh) is fast; running it again after reconciliation is cheap
2. Reconciliation may add new artifacts; a second generate-todo.sh at the end ensures they appear
3. Or alternatively, run reconciliation BEFORE step 3, then step 3 picks up the backfilled artifacts

**Recommended**: Run reconciliation before step 3 (i.e., as step 2.5), then step 3 regenerates TODO.md with the complete artifact set. This is more efficient.

### Algorithm Design

```
For each active task in state.json:
  1. Derive task directory path (padded: specs/{NNN}_{SLUG}/)
  2. Skip if directory does not exist (task has no artifacts)
  3. Skip if task is in archive (directory is under specs/archive/)
     - Note: active_projects should not have archived tasks, but guard anyway
  4. For each subdirectory in [reports/, plans/, summaries/]:
     a. Enumerate all .md files in that subdirectory
     b. Infer artifact type: reports/ -> "report", plans/ -> "plan", summaries/ -> "summary"
     c. For each .md file:
        - Construct relative path: specs/{NNN}_{SLUG}/{subdir}/{filename}
        - Check if path already exists in state.json artifacts array for this task
        - If NOT present: add new artifact entry with inferred type and generated summary
  5. After processing all subdirectories for this task, if any artifacts were added:
     - Log count of backfilled artifacts

After processing all tasks:
  - Call generate-todo.sh to regenerate TODO.md with complete artifact set
  - Report total artifacts backfilled
```

### Deduplication Check Pattern

Use the existing pattern from `reconcile-task-status.sh`'s `artifact_already_linked()`:

```bash
jq -r --argjson num "$task_number" \
  '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | .path] | .[]' \
  specs/state.json | grep -qF "$rel_path"
```

### Adding a Missing Artifact to state.json

Use the two-step jq pattern (safe for Issue #1132) from reconcile-task-status.sh:

```bash
# Step 1: Do NOT remove existing artifacts of same type (unlike postflight!)
# Reconciliation uses APPEND-ONLY — we are backfilling gaps, not replacing

# Step 2: Add new artifact entry (append only, no type-based replacement)
jq --arg path "$rel_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
   --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Key distinction from postflight**: Postflight does replace-then-add (one artifact per type). Reconciliation does append-only (preserves existing, adds missing). This handles team research tasks with multiple report files.

### Summary Generation

For backfilled artifacts, generate a human-readable summary from the filename:

```bash
# Strip numeric prefix and extension: "01_research-report.md" -> "research report"
summary=$(basename "$file" .md | sed 's/^[0-9]*_//' | tr '-' ' ')
summary="$(echo "${summary:0:1}" | tr '[:lower:]' '[:upper:]')${summary:1} (backfilled by --sync)"
```

### Implementation as Inline Code or New Script?

**Decision**: Implement as a new script `reconcile-artifacts.sh` (similar to `reconcile-task-status.sh`) called from `--sync` mode.

**Rationale**:
- The logic is complex enough (directory scanning, deduplication, jq operations) to warrant a separate script
- Follows established pattern: reconcile-task-status.sh handles one class of reconciliation, reconcile-artifacts.sh handles another
- Can be tested independently with `--dry-run` flag
- Keeps task.md clean (just adds one bash call)

---

## Integration Point in --sync Mode

The reconciliation step should be inserted as **Step 2.5** in `--sync` mode:

```
Step 1: Validate state.json integrity
Step 2: Identify orphan TODO.md tasks (warn)
Step 2.5: [NEW] Artifact reconciliation
  - bash .claude/scripts/reconcile-artifacts.sh [--dry-run]
  - Reports: "Backfilled N artifacts for M tasks"
  - OR: "No artifact gaps found"
Step 3: Regenerate TODO.md from state.json (now includes backfilled artifacts)
Step 6.5: Topic backfill
Step 7: Git commit
```

Alternatively, if placed as **Step 3.5** (after TODO.md regeneration):
- Must call generate-todo.sh again at end of sync to pick up backfilled artifacts
- Less efficient but logically equivalent

**Recommendation**: Step 2.5 (before generate-todo.sh). One generate-todo.sh call picks up both the existing state AND the backfilled artifacts.

---

## Edge Cases and Concerns

### 1. Archived Tasks

**Issue**: Tasks in `specs/archive/` are in `archive/state.json`, not `active_projects`. The `--sync` mode only operates on `state.json` (active tasks). Archive tasks should NOT be reconciled during `--sync` as they are terminal.

**Resolution**: The loop over `active_projects` naturally excludes archived tasks. But there may be a case where a task is `completed` in active_projects with its directory still under `specs/` (not yet archived by `/todo`). These SHOULD be reconciled — they're active but completed.

### 2. Tasks Without Directories

**Issue**: Newly created tasks have no `specs/{NNN}_{SLUG}/` directory yet.

**Resolution**: Check `[ -d "$task_dir" ]` before scanning. If directory doesn't exist, skip silently.

### 3. Multiple Reports (Team Research)

**Issue**: Team research produces multiple report files (01_team-research.md, 02_teammate-a-findings.md, etc.). Postflight only registers one. The reconciliation should register ALL unregistered files.

**Resolution**: Append-only logic handles this correctly — each file is checked independently and added if missing. Task 647 has 3 report files; state has 1 registered. Reconciliation would add the 2 unregistered ones.

**Type assignment**: All files in `reports/` get type "report" during reconciliation. This is consistent with what generate-todo.sh can display.

### 4. Duplicate Detection Accuracy

**Issue**: Duplicate detection uses path string matching (`grep -qF`). The path must be normalized consistently.

**Resolution**: Always use relative path form `specs/{NNN}_{SLUG}/subdir/file.md`. Both disk path construction and state.json path storage use this format. No normalization issues.

### 5. Padded vs. Unpadded Directory Names

**Issue**: Some older task directories use unpadded numbers (e.g., `78_fix_himalaya`), while newer ones use padded numbers (e.g., `695_artifact_reconciliation_sync`).

**Resolution**: The reconciliation script should check both:
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
if [ -d "specs/${PADDED_NUM}_${slug}" ]; then
  task_dir="specs/${PADDED_NUM}_${slug}"
elif [ -d "specs/${task_number}_${slug}" ]; then
  task_dir="specs/${task_number}_${slug}"
else
  continue  # No directory, skip
fi
```

### 6. Files Outside reports/plans/summaries

**Issue**: Some task directories may contain other `.md` files (e.g., `.return-meta.json` is JSON not MD, but there could be markdown notes).

**Resolution**: Only scan the three canonical subdirectories (`reports/`, `plans/`, `summaries/`). Do not scan task root or other directories.

### 7. Non-Canonical Filenames

**Issue**: What if a file in `reports/` is not a research report (e.g., a README)?

**Resolution**: Include all `.md` files in the subdirectory. A README in `reports/` would get type "report" and a generated summary — acceptable, as it's a legitimate artifact in that directory.

### 8. jq Safety for Issue #1132

The `!=` operator causes escaping issues in Claude Code's Bash tool. All jq operations in the new script must use the safe pattern:

```bash
# SAFE: use "| not" pattern
select(.path == $path | not)
# NOT SAFE: would cause parse errors in Claude Code Bash tool
select(.path != $path)
```

### 9. Idempotency

**Requirement**: Running `--sync` twice should produce the same result (no duplicate artifact entries).

**Guaranteed by**: The deduplication check verifies path presence before adding. Running reconciliation a second time finds all paths already present and skips them.

### 10. tmp Directory

The `specs/tmp/` directory is used by existing jq operations in postflight scripts. The reconciliation script should use the same pattern:

```bash
mkdir -p specs/tmp
```

---

## Decisions

1. **Implement as `reconcile-artifacts.sh`** (new script), called from `--sync` mode — follows established `reconcile-task-status.sh` pattern.
2. **Append-only semantics** (not replace-by-type) — critical distinction from postflight scripts, enables multiple-file-per-type support.
3. **Insert before step 3** (generate-todo.sh call) in `--sync` mode — one TODO.md regeneration picks up backfilled artifacts.
4. **Type inference from directory name**: `reports/` → "report", `plans/` → "plan", `summaries/` → "summary".
5. **Do NOT reconcile archive tasks** — only active_projects, even if status is "completed".
6. **Support `--dry-run` flag** in the new script for safe pre-flight inspection.
7. **Generated summary format**: `"{Cleaned filename} (backfilled by --sync)"` — makes provenance clear.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| jq #1132 parse errors | Medium | Blocks script | Use "| not" pattern, avoid `!=` |
| Overwriting existing artifacts | Low | Data loss | Deduplication check before any write |
| Slow on large task sets (53+ active tasks) | Low | UX delay | jq reads are fast; acceptable |
| Stale tmp directory | Low | Silent failure | mkdir -p before each use |
| Directory format mismatch | Medium | Missed backfill | Check both padded and unpadded |
| Team research: wrong type for teammate files | Low | Minor misclassification | All reports/ files get "report" type, consistent with generate-todo.sh display |

---

## Appendix: Key File Locations

- **`--sync` implementation**: `.claude/commands/task.md` lines 382-433
- **Postflight scripts**:
  - `.claude/scripts/postflight-research.sh` — registers research artifacts
  - `.claude/scripts/postflight-plan.sh` — registers plan artifacts
  - `.claude/scripts/postflight-implement.sh` — registers summary artifacts
- **generate-todo.sh**: `.claude/scripts/generate-todo.sh` — renders artifacts from state.json
- **Existing reconciliation**: `.claude/scripts/reconcile-task-status.sh` — status promotion for in-flight tasks
- **link-artifact-todo.sh**: `.claude/scripts/link-artifact-todo.sh` — direct TODO.md linking (DEPRECATED path; reconciliation should not use this)
- **State file**: `specs/state.json`
- **Archive state**: `specs/archive/state.json`

## Appendix: Measured Gap

As of 2026-06-14, running the gap detection script:
- **21 active tasks** have at least one artifact on disk not registered in state.json
- **53 total missing registrations** across those tasks
- **All gaps are in completed tasks** — no in-flight tasks have unregistered artifacts
- Earliest gap found: Task 638 (created ~2026-06-08, before postflight integration)
