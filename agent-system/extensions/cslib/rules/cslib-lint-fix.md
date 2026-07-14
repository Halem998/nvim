---
paths: "**/*.lean"
---

# CSLib Lint-Fix Behavioral Rules

## Activation

These rules apply when the task description contains "lint", "linter", or the implementation plan references lint categories (docBlame, defLemma, defsWithUnderscore, simpNF, unusedSectionVars, topNamespace, dupNamespace). For general proof implementation tasks, use cslib-implementation-agent rules instead.

## Anti-Analysis Contract

**MANDATORY**: For lint-fix tasks, make the first Edit or Write within 15 tool calls from task start.

- Do NOT spend multiple tool calls reading files before finding issues -- use `lake lint` output to target exact locations
- Do NOT produce analysis-only output (lists of findings, summaries of what needs fixing) without also making edits in the same response
- Treat lint output as the work queue -- each lint warning maps to exactly one Edit operation
- If you have read 3+ files without writing any edits, you have violated this contract; stop reading and start editing

**Forbidden pattern**: Reading entire files to understand context before fixing lint issues.
**Required pattern**: Read lint output, read only the specific lines flagged (using offset/limit), edit those lines.

## Lint-Driven Targeting

### Step 1: Run Linter First

```bash
cd ~/Projects/cslib && lake lint 2>&1 | head -200
```

Parse the output to extract:
- File path (e.g., `Cslib/Logics/Modal/K.lean`)
- Line number
- Category (docBlame, defLemma, defsWithUnderscore, etc.)
- Message

### Step 2: Target Specific Lines

Use Read with `offset` and `limit` parameters -- do NOT read entire files:

```
Read:
  file_path: /path/to/Cslib/File.lean
  offset: <line_number - 5>
  limit: 20
```

Read only the 10-20 lines surrounding the flagged location, not the entire file.

### Step 3: Batch Edits Without Re-Reading

For mechanical fixes (adding docstrings, renaming declarations):
- Accumulate multiple edits to the same file without re-reading it after each edit
- The Edit tool tracks file state -- trust it, do not re-read to verify
- Only re-read if the next edit depends on content you have not yet seen

## Checkpoint Handoff for Large Tasks

For lint-fix tasks with more than 50 edit sites:
- Write a handoff document every 30 edits
- Record: files edited so far, remaining lint count from most recent `lake lint` run, next file/line to fix
- Handoff path: `specs/{N}_{SLUG}/handoffs/lint-fix-checkpoint-{N}.md`

If you are approaching context limit (80%+ estimated), write the handoff immediately after completing the current file -- do not start a new file.

## Progress Tracking

After every 10 edits, re-run the linter to get an updated count:

```bash
cd ~/Projects/cslib && lake lint 2>&1 | wc -l
```

Record the count in partial_progress in the metadata file:

```json
{
  "partial_progress": {
    "lint_count_start": 150,
    "lint_count_current": 120,
    "edits_made": 10
  }
}
```

This creates measurable progress and enables accurate status reporting.

## Phase-Scoped Context

Complete each lint category as a self-contained phase:
- Fix all instances of one lint category (e.g., all docBlame warnings) before moving to the next
- Do NOT accumulate context from multiple categories simultaneously
- When starting a new category, run `lake lint 2>&1 | grep <category>` to get a fresh targeted list
- Do NOT carry file contents from the previous category into the next phase -- the Edit tool manages file state

Example phase structure for a multi-category lint task:
1. Phase 1: Fix all docBlame warnings
2. Phase 2: Fix all defLemma warnings
3. Phase 3: Fix all defsWithUnderscore warnings
4. Verification: Run `lake lint` to confirm zero remaining warnings in fixed categories

## Do Not

- Read entire Lean files when a targeted read (offset/limit) would suffice
- Re-read a file after each edit to verify -- trust the Edit tool's file state tracking
- Start a new lint category without completing the previous one
- Skip the progress tracking re-lint after every 10 edits
- Write analysis summaries without accompanying edits
