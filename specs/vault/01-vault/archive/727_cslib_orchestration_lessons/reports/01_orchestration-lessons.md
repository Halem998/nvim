# Task 727: CSLib Multi-Task Orchestration Lessons

## Source Context

Orchestration of tasks 208-213 (lint fixes) in the CSLib project exposed several failure
modes and improvement opportunities for the cslib extension's agents, skills, and planning
system.

## Observed Failures

### F1: Context Exhaustion on Large Mechanical Tasks

**Tasks affected**: 208 (327 docstrings), 209 (298 namespace fixes), 211 (55 def→lemma)

All three agents hit "Prompt is too long" after 67-246 tool uses. The pattern:
- Agent reads the plan, then reads files one by one, making small edits
- Each file read + edit cycle adds ~2-4k tokens to context
- After ~80-150 files, the agent exhausts its context window

**Root cause**: The cslib-implementation-agent reads entire files to find edit targets, but
for mechanical lint fixes, it only needs the specific lines flagged by the linter.

**Recommended fixes**:
1. **Lint-driven implementation mode**: For tasks tagged as `lint-fix`, the agent should run
   `lake lint` first, parse the output for file:line:column references, then use targeted
   `Read` with offset/limit to read only the flagged lines (±5 context lines). This cuts
   per-file context from ~200-500 lines to ~10-15 lines.
2. **Batch-edit pattern**: For mechanical changes (add docstring, change keyword, remove
   attribute), accumulate edits in a list and apply them via `Edit` without re-reading the
   file. The agent currently reads → edits → re-reads to verify, which doubles context cost.
3. **Phase-scoped context**: When a plan has 5+ phases and >50 total edits, the agent should
   complete each phase in a self-contained block: run lint for that phase's files, make edits,
   verify with `lake build`, then move on — never accumulating cross-phase file contents.
4. **Explicit context budget awareness**: Add a rule that for tasks with >100 edit sites, the
   agent should checkpoint progress to a handoff file every 30-40 edits, so that if context
   is exhausted, the next dispatch can resume from the checkpoint.

### F2: Analysis Paralysis (Zero-Output Agent)

**Task affected**: 209 (namespace fixes) — first attempt: 197 tool calls, 0% completion

The agent spent its entire context reading files and analyzing namespace structures without
making a single edit.

**Root cause**: Namespace changes are structurally complex (wrapping code in namespace blocks
affects indentation, imports, and downstream references). The agent's default behavior is to
"understand fully before acting," which for 298 errors means reading hundreds of files before
writing anything.

**Recommended fixes**:
1. **Anti-analysis contract for lint tasks**: Add a rule to cslib-implementation-agent that
   for lint-fix tasks, the first file edit MUST occur within the first 15 tool calls. If the
   agent has used 15 tool calls without an Edit/Write, it should immediately start making
   changes to the lowest-risk files.
2. **Phase-gated risk**: The plan already separated Phase 1 (zero-risk namespace wrapping)
   from Phase 3 (moderate-risk renames). The agent should be instructed to complete all
   zero-risk phases before attempting any analysis of higher-risk phases.
3. **Lint-count progress tracking**: After every 10 edits, the agent should re-run
   `lake lint 2>&1 | grep -c "ERROR_TYPE"` to confirm the count is decreasing. This creates
   a feedback loop that rewards making changes over analyzing.

### F3: Concurrent Agent File Conflicts

**Tasks affected**: 211 (def→lemma) was invalidated by 210 (naming renames)

Task 210 renamed 105 declarations. Task 211 changed `def` to `lemma` on declarations by
name. When 210 finished first and renamed declarations, 211's edits targeted the old names
and silently failed or conflicted.

**Root cause**: All 6 implementation agents ran in parallel on the same worktree. The
orchestrator treated them as independent because they target different lint categories, but
they share file-level write access.

**Recommended fixes**:
1. **Conflict matrix in planner**: When planning multi-task lint fixes, the planner should
   emit a conflict matrix identifying which task pairs touch overlapping files. Tasks 210
   (renames) and 211 (keyword changes) both modify declaration lines in the same files.
2. **Wave assignment by file overlap**: The orchestrator should use file-overlap analysis
   (not just explicit task dependencies) to assign waves. Tasks that modify the same files
   should be in sequential waves, not parallel.
3. **Lint-driven targeting**: If agents use `lake lint` output at execution time (not cached
   from research), they naturally pick up the current declaration names — making them
   resilient to prior renames. This is the most robust fix.
4. **Worktree isolation for conflicting tasks**: Use `isolation: "worktree"` for tasks
   identified in the conflict matrix, then merge worktrees sequentially.

### F4: Stale Metadata Files

**Tasks affected**: 208, 211 — `.return-meta.json` showed "in_progress" after implementation

When an agent hits context limits, it never writes the updated `.return-meta.json`. The
orchestrator then reads stale "in_progress" status and can't determine what was actually
accomplished. (The `.orchestrator-handoff.json` files were more reliable because they were
written incrementally.)

**Recommended fixes**:
1. **Write-first metadata pattern**: The agent should write `.return-meta.json` at the
   START of implementation with `phases_completed: 0`, then update it incrementally after
   each phase. This way context exhaustion always leaves accurate metadata.
   (Note: `.orchestrator-handoff.json` already follows this pattern successfully — the
   gap is in `.return-meta.json` which the skill reads for postflight.)
2. **Lint-count-based status detection**: If the metadata is stale, the orchestrator should
   fall back to running `lake lint | grep -c "LINTER"` to detect actual progress by
   comparing the current error count to the task's original count.

### F5: Inaccurate Error Counts in Task Descriptions

**Tasks affected**: 208 (said 327, actual was 543), 213 (said ~17, actual was 28)

Task descriptions from the creation phase had stale or estimated counts. The research phase
updated these, but the plan phase sometimes used the old numbers.

**Recommended fixes**:
1. **Lint-count verification in preflight**: The implementation agent should always run the
   relevant linter at the start and compare the count to the plan's stated count. If they
   differ by >20%, log a warning and use the actual count.

## Recommended Extension Changes

### 1. New Task Type: `lint-fix`

Add a `lint-fix` task type (or sub-type of `cslib`) that activates specialized behavior:
- Lint-driven targeting (parse `lake lint` output for file:line references)
- Anti-analysis contract (first edit within 15 tool calls)
- Checkpoint handoff every 30 edits
- Progress tracking via lint count

### 2. Agent Rule: `cslib-lint-fix-rules.md`

```markdown
## Lint Fix Implementation Rules

1. Run `lake lint` FIRST. Parse output to get exact file:line:linter triples.
2. First file edit MUST occur within 15 tool calls.
3. Read only flagged lines (±5 context), not entire files.
4. After every phase or 30 edits, write checkpoint to .orchestrator-handoff.json.
5. Re-run `lake lint | grep -c "LINTER"` after every 10 edits to track progress.
6. Do NOT analyze the entire codebase before starting edits.
```

### 3. Orchestrator Enhancement: File-Overlap Wave Assignment

Add a pre-dispatch step in multi-task orchestration that:
1. For each task, collects the set of files mentioned in its plan
2. Builds an overlap graph between tasks
3. Tasks with >30% file overlap are placed in sequential waves

### 4. Agent Enhancement: Write-First Metadata

Update cslib-implementation-agent to write `.return-meta.json` incrementally (not just at
initialization). The current Stage 0 early metadata pattern creates the file but never
updates it mid-implementation. Add incremental updates after each phase:
```json
{
  "status": "implementing",
  "phases_completed": 0,
  "phases_total": N,
  "lint_count_start": M,
  "lint_count_current": M
}
```
Update `lint_count_current` after each phase.

### 5. Planner Enhancement: Conflict Matrix

When planning multiple lint-fix tasks, emit a conflict matrix:
```markdown
## Conflict Matrix
| Task | Files | Overlaps With |
|------|-------|---------------|
| 210 | 43 | 211 (22 shared) |
| 211 | 22 | 210 (22 shared) |
| 209 | 17 | 208 (12 shared) |
```

## Summary Statistics

| Task | Target | Final Status | Notes |
|------|--------|-------------|-------|
| 208 | 543 docstrings (docBlame) | Completed (7/7 phases) | `.return-meta.json` stale ("in_progress"), handoff shows success |
| 209 | 298 namespace errors (topNamespace + dupNamespace) | Completed (3/3 phases) | Used `@[nolint dupNamespace]` annotations; task state stuck at "implementing" |
| 210 | 105 naming renames (defsWithUnderscore) | Completed (5/5 phases) | Bulk `sed -i` approach, single dispatch |
| 211 | 55 def→lemma (defLemma) | Completed (5/5 phases) | `.return-meta.json` stale ("in_progress"), handoff shows success |
| 212 | 25 simp removals (simpNF) | Completed | Removed `@[simp]` from abbrev-derived lemmas |
| 213 | 28 unused args (unusedSectionVars) | Completed | Used `omit` pattern and `haveI` with Classical.dec |

All six tasks eventually completed. Tasks 208, 209, 211 had complications (context exhaustion,
metadata staleness, or analysis paralysis on initial attempts). Tasks 210, 212, 213 completed
cleanly. Exact dispatch counts and token costs are not available from preserved artifacts.
