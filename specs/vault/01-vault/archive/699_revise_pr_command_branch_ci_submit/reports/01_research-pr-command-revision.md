# Research Report: Task #699

**Task**: 699 - Revise /pr command to be single entry point for branch creation, CI, and PR submission
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:00:00Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**: - Codebase: `.claude/extensions/cslib/commands/pr.md`
**Artifacts**: - `specs/699_revise_pr_command_branch_ci_submit/reports/01_research-pr-command-revision.md`
**Standards**: report-format.md

---

## Executive Summary

- The current `/pr` command is a 10-step workflow (STEP 1–11, with STEP 10b) that treats `pr-description.md` as optional and falls back to interactive multi-step title/description composition
- The required changes are surgical: (1) make `pr-description.md` mandatory in task mode and error-out if missing, (2) insert a `lake exe cache get` step immediately after branch creation (between STEP 5 and STEP 6), (3) collapse the dual-path title/description flow in STEP 8 and STEP 9 into a single approval flow when `pr-description.md` exists, and (4) preserve the interactive fallback only for path-mode and description-mode
- The branch creation step (STEP 5) already handles the `upstream/main` base; the cache step simply needs to be appended before staging changes

---

## Context & Scope

The file being modified is `.claude/extensions/cslib/commands/pr.md` (1054 lines). This is a Claude Code command file for the CSLib extension. It is an agent-executed instruction document, not Lua code.

The task requests:
1. `pr-description.md` becomes a **required** input in task mode (error if missing, not a warning)
2. `lake exe cache get` must run immediately after branch creation and before CI
3. The interactive title/description composition flow (the multi-step AskUserQuestion flow in STEP 8 and the template-based composition in STEP 9) must be removed when `pr-description.md` exists
4. Fallback flows for path-mode and description-mode must be preserved

---

## Findings

### Current Command Structure (Step-by-Step)

| Step | Name | Key Action |
|------|------|-----------|
| STEP 1 | Parse Arguments | Extract flags and input_value; detect input_mode |
| STEP 2 | Resolve Input and Working Description | Read task metadata from state.json; load `pr-description.md` (optional); read `base_branch` |
| STEP 3 | Environment Check | Verify `gh auth`, `origin`, `upstream`, `lakefile` |
| STEP 4 | Sync with Upstream | `git fetch upstream` |
| STEP 5 | Branch Creation | Propose/confirm branch name; `git checkout upstream/main -b $branch_name` |
| STEP 6 | Stage Changes | `git status`/`git add`; detect new `.lean` files |
| STEP 7 | Run CI Pipeline | 7-step pipeline: build, checkInitImports, lint, lint-style, test, mk_all, shake |
| STEP 8 | Select PR Title | If `has_pr_description`: confirm loaded title; else: 3-step interactive prefix/area/description flow |
| STEP 9 | Compose PR Description | If `has_pr_description`: present body and ask Approve/Edit/Replace; else: template-based generation with same Approve/Edit/Replace options |
| STEP 10 | Commit, Push, and Create PR | Commit, `git push`, `gh pr create`; PR summary + final approval |
| STEP 10b | Transition Task Status | `update-task-status.sh` postflight; task → `[COMPLETED]` |
| STEP 11 | Offer Merge-Back | Sync `origin/main` with `upstream/main` |

### What the Current Code Does with `pr-description.md`

In **STEP 2** (lines 110–121):
```bash
if [ -f "$pr_desc_path" ]; then
  pr_body=$(cat "$pr_desc_path")
  pr_title=$(head -1 "$pr_desc_path" | sed 's/^# //')
  has_pr_description=true
  echo "Found pr-description.md: $pr_desc_path"
else
  has_pr_description=false
  echo "Warning: pr-description.md not found at $pr_desc_path"
  echo "The description will be composed interactively (STEP 9)."
fi
```

The current behavior when `pr-description.md` is missing: set `has_pr_description=false`, print a warning, and fall through to interactive composition at STEP 8/9. The new behavior must be: **STOP** with an error message.

Also in STEP 2, the status check warns if the task is not `pr_ready` but allows continuation. This warning could be tightened, but is not in scope for this task.

### Where Cache Management Must Be Inserted

The cache step (`lake exe cache get`) must run **after branch creation (STEP 5)** and **before staging (STEP 6)**. The rationale from the task description: when a new branch is created from `upstream/main`, Lean's build cache is invalidated because the branch now diverges from whatever branch the `.olean` files were originally built on. Running `lake exe cache get` fetches Mathlib's pre-built `.olean` cache so only CSLib's own modules need recompilation during CI.

This becomes a new **STEP 5b** (or it can be numbered STEP 6 and the existing STEP 6 renumbered, but inserting as 5b is lower impact and avoids renumbering all subsequent references in the file).

### Interactive Description Composition Flows to Remove (Task Mode Only)

**STEP 8** has two paths:
- Task mode with `has_pr_description=true` (lines 533–560): confirm loaded title via single AskUserQuestion. **Keep this.**
- Path/description mode or task mode with `has_pr_description=false` (lines 564–644): 3-step interactive prefix/area/description flow. **Remove the task-mode fallback; keep path/description-mode fallback.**

**STEP 9** has two paths:
- Task mode with `has_pr_description=true` (lines 652–683): present body from file, Approve/Edit/Replace. **Keep this.**
- Path/description mode or task mode with `has_pr_description=false` (lines 687–748): template-based description generation with 4-option approval. **Remove the task-mode fallback; keep path/description-mode fallback.**

Since the new behavior errors out in STEP 2 when `pr-description.md` is missing in task mode, the `has_pr_description=false` branch in task mode becomes unreachable. This means the conditional sections in STEP 8 and STEP 9 can be simplified: the `has_pr_description=false` fallback in those steps only applies for path-mode and description-mode.

### Specific Sections to Modify

#### 1. STEP 2 — Change warning to hard error (lines 117–121)

**Current** (lines 117–121):
```bash
  has_pr_description=false
  echo "Warning: pr-description.md not found at $pr_desc_path"
  echo "The description will be composed interactively (STEP 9)."
```

**New behavior**:
```bash
  echo "ERROR: pr-description.md not found at $pr_desc_path"
  echo "Task-mode /pr requires a pre-built pr-description.md."
  echo "Run skill-pr-implementation to generate this file before submitting."
  # STOP — cannot continue without pr-description.md in task mode
```

#### 2. STEP 5 → Insert new STEP 5b after branch creation

After the "On success" line at the end of STEP 5 (line 314) and before STEP 6:

```markdown
### STEP 5b: Fetch Mathlib Cache

**EXECUTE NOW**: Fetch the pre-built Mathlib `.olean` cache so CI does not trigger a near-full rebuild.

When a feature branch is created from `upstream/main`, Lean's build cache may be invalidated
because the new branch diverges from the branch the existing `.olean` files were built on.
Running `lake exe cache get` restores the Mathlib pre-built cache so only CSLib modules need
to be rebuilt during CI.

```bash
cd /home/benjamin/Projects/cslib
lake exe cache get 2>&1
CACHE_STATUS=$?

if [ $CACHE_STATUS -eq 0 ]; then
  echo "[OK] Mathlib cache fetched successfully."
else
  echo "Warning: lake exe cache get exited with status $CACHE_STATUS."
  echo "CI may take significantly longer due to a full Mathlib rebuild."
  echo "Proceeding anyway — this is non-fatal."
fi
```

Cache fetch failure is **non-fatal**: CI will still run correctly, just more slowly. Always
proceed to STEP 6 regardless of cache fetch exit status.

**On success (or non-fatal failure)**: **IMMEDIATELY CONTINUE** to STEP 6.
```

#### 3. STEP 8 — Simplify conditional structure

The section header currently says "Path mode or Description mode (or task mode when `has_pr_description` is false)" (line 564). After the change, task mode will never reach STEP 8 with `has_pr_description=false` (it will have errored at STEP 2). The header and guard should be updated to:

"Path mode or Description mode:" (removing the task-mode fallback clause).

No structural removal is needed in STEP 8 — the 3-step interactive flow stays for path/description mode. Only the header description changes.

#### 4. STEP 9 — Simplify conditional structure

Same pattern: the guard label "Path mode, Description mode, or Task mode when `has_pr_description` is false" (line 687) becomes "Path mode or Description mode:". The template-based generation stays for path/description mode.

#### 5. Description update in frontmatter/intro

The command description at line 2 says:
> "Accepts a task number, file/directory path, or free-text description as input."

The description could note that in task mode, `pr-description.md` is required. This is lower priority but improves discoverability.

---

## Decisions

1. **Cache step inserted as STEP 5b** rather than renumbering all downstream steps. This minimizes diff size and reduces review surface.
2. **Cache failure is non-fatal**: `lake exe cache get` failing should not block PR submission; CI will still run, just slower. The warning message is sufficient.
3. **Hard error in STEP 2 for missing pr-description.md** in task mode: the task description says "required -- error if missing". This replaces the existing warning+fallback with a STOP.
4. **No removal of the STEP 8/9 interactive composition code**: since task mode now errors at STEP 2 when `pr-description.md` is absent, the `has_pr_description=false` branch in STEP 8/9 becomes dead code for task mode. The simplest fix is updating the section header guards only. Actual removal of dead code within those steps is optional (minor cleanup, not required).
5. **Preserve all path-mode and description-mode flows unchanged**: these are unaffected by the `pr-description.md` mandate (they never set `has_pr_description`).

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `lake exe cache get` requires network access and may be slow | Non-fatal; always proceeds. User sees warning if fetch fails. |
| Existing branch reuse path (STEP 5 "Reuse existing" option) skips branch creation — cache step still needed | Cache step runs unconditionally regardless of reuse vs. create choice |
| Hard error on missing `pr-description.md` breaks existing non-task-mode usage | Error is guarded by `input_mode="task"` — path-mode and description-mode are unaffected |
| Step numbering confusion after inserting 5b | Document explicitly as "STEP 5b"; CI pipeline is still "7-step" (no change to CI count) |

---

## Summary of Changes Required

| Location | Change | Type |
|----------|--------|------|
| STEP 2, lines 117–121 | `pr-description.md` missing → hard error + STOP (not warning + fallback) | Behavior change |
| After STEP 5 "On success" line | Insert new STEP 5b: `lake exe cache get` (non-fatal) | New content |
| STEP 8, fallback section header | Update guard label: remove "task mode when `has_pr_description` is false" clause | Documentation |
| STEP 9, fallback section header | Same: update guard label | Documentation |
| Frontmatter description (line 2) | Optional: note that task mode requires `pr-description.md` | Minor |

---

## Appendix

### File Location
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` — 1054 lines

### Key Line Numbers in Current File
- Line 2: frontmatter `description:` field
- Lines 110–121: `pr-description.md` existence check in STEP 2
- Lines 270–314: STEP 5 (Branch Creation) body and "On success" line
- Lines 319–367: STEP 6 (Stage Changes)
- Lines 372–524: STEP 7 (CI Pipeline, 7 steps)
- Lines 533–560: STEP 8 fast path (task mode with pr-description.md)
- Lines 564–644: STEP 8 interactive fallback (path/description mode + task fallback)
- Lines 652–683: STEP 9 fast path (task mode with pr-description.md)
- Lines 687–748: STEP 9 template-based fallback
- Lines 754–865: STEP 10 (Commit, Push, Create PR)
- Lines 869–896: STEP 10b (Task status transition)
- Lines 900–966: STEP 11 (Offer merge-back)
