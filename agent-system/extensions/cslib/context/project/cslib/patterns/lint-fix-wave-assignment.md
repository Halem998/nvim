# Lint-Fix Wave Assignment for Multi-Task Orchestration

Use this guidance when planning parallel lint-fix task orchestration. File conflicts between tasks in the same wave cause race conditions and can corrupt edits.

## File-Overlap Analysis

Before assigning tasks to waves:

1. **Collect file lists**: For each task, extract the set of `.lean` files it will modify. Use the lint output from `lake lint 2>&1 | grep 'Cslib/'` to identify target files per lint category.

2. **Build overlap graph**: For each pair of tasks (A, B), count shared files: `|files(A) ∩ files(B)|`.

3. **Wave assignment rule**: If any task pair shares more than 30% of their files, place those tasks in sequential waves (not parallel).

   Threshold formula: `|A ∩ B| / min(|A|, |B|) > 0.30`

## Conflict Matrix Format

Document file overlap as a matrix before planning waves:

| Task Pair | Task A Files | Task B Files | Shared Files | Overlap % | Same Wave? |
|-----------|-------------|-------------|-------------|-----------|------------|
| 210 vs 211 | 45 | 38 | 22 | 58% | NO |
| 210 vs 212 | 45 | 12 | 3 | 25% | YES |
| 211 vs 212 | 38 | 12 | 2 | 17% | YES |

**Overlap %** = shared / min(A, B). Use the smaller task as the denominator to identify asymmetric overlap (where a small task is entirely subsumed by a larger one).

## Example: Tasks 210 and 211

Tasks 210 (declaration renames) and 211 (keyword-to-typeclass changes) shared approximately 58% of their target files -- primarily declaration files in `Cslib/Logics/Modal/` and `Cslib/Pi/`.

**Why this caused conflicts**: Task 210 renamed declarations that Task 211 then tried to modify using the old names. When both ran in Wave 1 (parallel), Task 211's edits failed with "string not found" errors because Task 210 had already renamed the target strings.

**Correct wave assignment**:
- Wave 1: Task 210 (renames -- establishes new names)
- Wave 2: Task 211 (keyword changes -- uses new names after renames land)

**Note**: The dependency direction matters. Renames must precede keyword changes, not vice versa, because keyword changes reference declaration names by string.

## Lint-Driven Targeting as Mitigation

When tasks use live `lake lint` output as their work queue (see cslib-lint-fix.md), they are partially resilient to rename conflicts: the agent runs `lake lint` at task start and gets the current names, so prior renames are already reflected. However, this does NOT eliminate file-level conflicts -- two agents editing the same file simultaneously still causes corruption.

**Mitigation only works if**: Each task uses live `lake lint` output rather than a pre-computed file list from task creation time.

**Mitigation does NOT help with**: Structural edits where both tasks modify the same declaration (e.g., adding a docstring AND changing the declaration keyword on the same line).

## Worktree Isolation

For high-conflict task pairs (>50% overlap) where sequential ordering is impractical, use git worktrees to run the tasks in isolated copies of the repo:

```bash
# Create worktree for each task
git worktree add ../cslib-task-210 HEAD
git worktree add ../cslib-task-211 HEAD

# Run tasks in separate worktrees
# After both complete, merge results manually
git -C ../cslib-task-210 diff HEAD > task-210.patch
git -C ../cslib-task-211 diff HEAD > task-211.patch
```

**Worktree isolation is appropriate when**:
- Conflict matrix shows >50% overlap
- Tasks cannot be easily sequenced (no clear dependency direction)
- Manual merge review is acceptable

**Worktree isolation is NOT appropriate when**:
- Tasks have >100 edit sites (manual merge becomes impractical)
- Tasks edit identical lines (merge conflicts will still occur)

## Wave Assignment Checklist

Before finalizing the orchestration plan for a set of lint-fix tasks:

- [ ] Run `lake lint 2>&1` and group warnings by file
- [ ] Build conflict matrix for all task pairs
- [ ] Flag pairs with >30% overlap as sequential
- [ ] Determine dependency direction for sequential pairs (which task must run first)
- [ ] For >50% overlap pairs: consider worktree isolation
- [ ] Document wave assignments in the orchestration plan with rationale
