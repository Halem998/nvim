# Implementation Plan: Task #850

- **Task**: 850 - Fix Load Core leaving newly-deployed core scripts untracked downstream
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/850_sync_untracked_core_scripts/reports/01_sync-untracked-core-scripts.md
- **Artifacts**: plans/02_surface-untracked-deployed.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, neovim-lua.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Load Core (`<leader>al`) deploys core `.claude/` assets into downstream repos with a plain filesystem
write and performs no git operation, so newly-created files (`action == "copy"`) land untracked and the
completion notification reports only category counts. This plan adds an advisory-only signal: `sync_files`
will additionally collect the paths of files it newly creates, `execute_sync` will run a single git query
against the target repo to find which of those are untracked, and the completion notice will list them under
a "Newly deployed (untracked) - review and commit" section. The change is confined to
`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, guards non-git targets, and performs no
`git add`/`git commit`.

### Research Integration

The research report root-caused the defect precisely (no manifest gap; `task-lock.sh` is correctly deployed
via the core allow-list; the failure is the missing "commit me" signal). Key file:line anchors from the
report are used directly in this plan:
- `sync_files` writer with no git op: sync.lua:339, 406-413 (write happens at 406; success counted at 413).
- `execute_sync` notification (counts only): sync.lua:430, 480-497.
- Per-file action classification (`"copy"` vs `"replace"`): scan.lua:137.
- Relative-path display precedent (content audit): sync.lua:1146-1148.
- Established git-subprocess pattern in this same file: `vim.fn.system(... vim.fn.shellescape ...)` at sync.lua:128.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap_path / roadmap_flag provided).

## Goals & Non-Goals

**Goals**:
- After a Load Core sync into a git-backed target, list every newly-created core file (`action == "copy"`)
  that is untracked in the target repo, by project-relative path, in the completion notification.
- Perform exactly one git subprocess per sync (not per file); guard non-git targets silently.
- Preserve all existing sync behavior (counts, `.syncprotect`, extension preservation, merge re-injection).

**Non-Goals**:
- No auto-stage and no auto-commit in the target repo (advisory only). Opt-in auto-stage (report Alternative A)
  and a downstream deployed-core manifest (Alternative B) are out of scope.
- No change to `task-lock.sh`, the manifest allow-list, or any downstream repo.
- No fix for the `.claude/scripts/` vs `.claude/extensions/core/scripts/` duplication (report finding 4,
  secondary hardening) - separate concern.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git status` invoked in a non-git target throws/errs | M | M | Guard with `git -C <dir> rev-parse --is-inside-work-tree` (check shell exit via `v:shell_error`); on any failure skip the section and complete normally |
| Path intersection mismatch (absolute `local_path` vs porcelain relative paths) | M | M | Normalize both to project-relative before set-membership; add a headless assertion in verification phase |
| Blocking `vim.fn.system` call slows large syncs | L | L | Single subprocess scoped to `-- <base_dir>`; runs once after all writes, not per file |
| Threading a third return value breaks existing `sync_files` callers | M | L | Only caller is `sync_with_protect` (sync.lua:438); update it and the two-value call sites in the same phase |
| Notification grows unwieldy when many new files deployed | L | L | Reuse content-audit precedent: show a capped list with "... and N more" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is a linear chain.

### Phase 1: Collect newly-copied paths through sync_files -> execute_sync [COMPLETED]

**Goal**: Thread the list of successfully-written new files (`action == "copy"`) from `sync_files` up to
`execute_sync`, without changing any existing sync behavior.

**Tasks**:
- [x] In `sync_files` (sync.lua:339), add a local `copied = {}` accumulator. On a successful write
      (the `if write_success then` block, ~sync.lua:407-413), if `file.action == "copy"`, append
      `file.local_path` to `copied`. *(completed)*
- [x] Return `copied` as a third value: `return success_count, protected_count, copied` (sync.lua:~419).
      Update the function's LuaDoc `@return` block accordingly. *(completed)*
- [x] In `execute_sync`, update the `sync_with_protect` wrapper (sync.lua:438) to pass through the third
      value, and add a `newly_copied = {}` accumulator at `execute_sync` scope. *(completed)*
- [x] For each `sync_with_protect(...)` call (sync.lua:445-458), capture the third return and append its
      entries into `newly_copied` (e.g. a small `local function collect(list) for _,p in ipairs(list) do table.insert(newly_copied, p) end end`).
      Keep the existing `counts.X, protect_counts.X = ...` assignments intact by capturing the third value
      separately. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - add third return value to
  `sync_files`; accumulate `newly_copied` in `execute_sync`.

**Verification**:
- `nvim --headless -c "luafile lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua" -c "q"`
  (module loads without syntax error), or require the module via its package path.
- No behavioral change yet: category counts and protection counts remain identical to before.

---

### Phase 2: Detect untracked new files and add completion-notice section [NOT STARTED]

**Goal**: After all writes, run one git query against the target repo, intersect its untracked entries with
`newly_copied`, and append an advisory section to the completion notification. Guard non-git targets.

**Tasks**:
- [ ] Add a file-local helper `local function detect_untracked(project_dir, base_dir, copied_paths)` that:
      returns `{}` immediately when `copied_paths` is empty; runs
      `git -C <project_dir> rev-parse --is-inside-work-tree` via `vim.fn.system` with `vim.fn.shellescape`
      (mirror sync.lua:128) and returns `{}` if `vim.v.shell_error ~= 0` (non-git or git absent).
- [ ] In the helper, run a single `git -C <project_dir> status --porcelain --untracked-files=normal -- <base_dir>`;
      parse lines beginning with `?? ` into a set of project-relative untracked paths (strip the `?? ` prefix;
      handle a possible trailing slash for directory entries by prefix-matching).
- [ ] Convert each `copied_paths` absolute `local_path` to project-relative (strip `project_dir .. "/"`,
      reuse the audit precedent at sync.lua:1146-1148) and keep those present in the untracked set. Return the
      resulting relative-path list (sorted for stable output).
- [ ] In `execute_sync`, after `total_synced` is computed and before/within the existing notify block
      (sync.lua:480-497), call `detect_untracked(project_dir, base_dir, newly_copied)`. If the result is
      non-empty, append a section to the notification string:
      `"Newly deployed (untracked in git) - review and commit:"` followed by up to 5 indented relative paths
      and a `"  ... and N more"` line when the list exceeds 5 (reuse the content-audit capping pattern at
      sync.lua:1138-1155).
- [ ] Ensure the section is appended even when the base notify currently only fires under
      `total_synced > 0 or total_protected > 0` - a new untracked file always implies `total_synced > 0`, so
      the existing gate is sufficient; do not widen it.

**Timing**: 1.0 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - add `detect_untracked` helper;
  extend the `execute_sync` notification.

**Verification**:
- Module loads headless without error.
- Static read-through: confirm no `git add`/`git commit`/`git stage` string exists anywhere in the picker
  tree (`grep -rn 'git add\|git commit\|git stage'` returns nothing new).
- Confirm the git call is guarded by `rev-parse --is-inside-work-tree` and short-circuits on empty input.

---

### Phase 3: End-to-end verification and guard validation [NOT STARTED]

**Goal**: Prove the acceptance criteria hold: untracked new files are listed in a git target; non-git targets
complete cleanly; existing behavior unchanged.

**Tasks**:
- [ ] Create a throwaway git repo under the scratchpad, seed it with a `.claude/` that lacks one core script,
      run the Load Core path (or a headless harness that calls `execute_sync` with a synthetic `all_artifacts`
      containing one `action == "copy"` file), and confirm the new file appears in the "newly deployed
      (untracked)" section.
- [ ] Repeat in a non-git directory (no `.git`) and confirm the sync completes with no git error and no
      untracked section.
- [ ] Add/repeat a case where a `copy` file is written then `git add`-ed manually, and confirm it does NOT
      appear (tracked files excluded).
- [ ] Confirm existing category counts, `.syncprotect` protection, and merge re-injection are unchanged
      (diff the notification for an all-tracked sync against pre-change behavior).
- [ ] Run `luacheck`/lint if available on the modified file; ensure 2-space indent and <=100 col per
      neovim-lua.md.

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- None (verification only; scratchpad fixtures under the session scratchpad directory).

**Verification**:
- All six acceptance criteria from the research report are demonstrably satisfied.
- No modification to any downstream repo or to `.claude/` script content.

## Testing & Validation

- [ ] Module `sync.lua` loads headless with no syntax/runtime error after each phase.
- [ ] Git-backed target: a newly-copied core file that is untracked is listed by project-relative path.
- [ ] `task-lock.sh`-style scenario (file previously absent) surfaces in the untracked list.
- [ ] Non-git target completes with no git error and no untracked section.
- [ ] Already-tracked synced files are excluded from the list.
- [ ] No `git add`/`git commit` anywhere in the picker tree; downstream git index unchanged.
- [ ] Category counts, `.syncprotect`, extension section preservation, and merge re-injection unchanged.

## Artifacts & Outputs

- Modified `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  (third return value on `sync_files`; `detect_untracked` helper; extended `execute_sync` notification).
- No new files; no downstream repo changes.

## Rollback/Contingency

The change is confined to one file and is purely additive (a third return value threaded through internal
callers, a new file-local helper, and appended notification text). To roll back, revert the single-file diff
with `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`. Because the feature
performs no `git add`/`git commit` and guards non-git targets, a partial or reverted state cannot corrupt any
downstream repo - at worst the completion notice omits the advisory section, matching current behavior.
