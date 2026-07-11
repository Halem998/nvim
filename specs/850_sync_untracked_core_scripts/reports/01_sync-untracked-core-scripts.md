# Research Report: Task #850 - Load Core Leaves Newly-Deployed Core Scripts Untracked Downstream

**Task**: 850 - sync_untracked_core_scripts
**Started**: 2026-07-11
**Completed**: 2026-07-11T20:44:36Z
**Effort**: ~1 research session (read-only inspection of the Load Core sync path)
**Task Type**: meta (agent-system / `.claude/` infrastructure)
**Dependencies**: None
**Sources/Inputs**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (the Load Core operation)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (per-file action classification)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua` (file writers)
- `.claude/extensions/core/manifest.json` (`provides.scripts` allow-list)
- `.claude/scripts/task-lock.sh`, `.claude/extensions/core/scripts/task-lock.sh` (the affected script twins)
- Downstream evidence: `/home/benjamin/Projects/Logos/Hardware/.claude/scripts/`

**Artifacts**: this report

**Standards**: report-format.md; this repo's CLAUDE.md documentation policy (no emojis, ASCII markers)

---

## Executive Summary

- The `<leader>al` "Load Core" sync deploys core `.claude/` assets into downstream project
  repos by writing files to disk with a plain file write. It performs **no git operation
  whatsoever** in the target repo (verified: zero `git add`/`git commit`/`git status`/`ls-files`
  calls across the entire picker tree). Whether a deployed file ends up git-**tracked** downstream
  is left entirely to the user, out-of-band from the sync.
- `task-lock.sh` is **not** a manifest gap. It IS listed in the core allow-list
  (`.claude/extensions/core/manifest.json` -> `provides.scripts`, near line 137), so Load Core
  correctly deploys it. The defect is not "which files get copied" but "the sync gives the user
  no signal that a newly-created file needs committing."
- **Root cause**: `task-lock.sh` is a *newer* addition to core than the last time the downstream
  project committed its `.claude/scripts/` directory. When Load Core wrote it, `scan.lua`
  classified it as `action = "copy"` (a brand-new local file), it was written to disk, and nothing
  staged/committed it. Every sibling script was committed during some earlier sync, so `task-lock.sh`
  is the single file that postdates that commit and therefore shows up as the lone stray untracked
  file. It is not gitignored; it is simply never tracked.
- The Load Core completion notification (`execute_sync`, sync.lua:480-497) reports only aggregate
  counts per category ("Scripts: N"). It never lists filenames and never distinguishes
  new-vs-existing or tracked-vs-untracked, so the user has no actionable signal.
- **Recommended fix (in nvim, source of truth)**: after a sync, have Load Core collect the files
  it newly created (`action == "copy"`) that are untracked in the target repo's git, and surface
  them as an explicit "Newly deployed (untracked) - review and commit" list in the completion
  notification. Advisory only: do NOT auto-stage or auto-commit (that would silently mutate
  downstream git state). This is a self-contained change to `sync.lua`.

---

## Context and Scope

### The user-facing symptom

In a downstream project (`/home/benjamin/Projects/Logos/Hardware`), a routine `git status`
surfaces `.claude/scripts/task-lock.sh` as a stray untracked file. It is byte-identical to this
repo's copy, it is NOT gitignored, and it is the ONLY untracked script -- every sibling
`.claude/scripts/*.sh` there is tracked.

### Established facts (pre-verified; confirmed during this investigation)

- `.claude/scripts/task-lock.sh` and `.claude/extensions/core/scripts/task-lock.sh` both exist here
  and are git-tracked; the two copies are byte-identical.
- This repo deploys `.claude/` core assets into downstream project repos via the Load Core sync
  bound to `<leader>al`.
- In the Hardware project, the deployed `task-lock.sh` is byte-identical to this repo's copy but is
  UNTRACKED in that project's git (not gitignored; the only untracked script).
- User rule: fixes to `.claude/` scripts must be made HERE in nvim and propagated via `<leader>al`,
  never hand-edited/committed in the downstream project. (Note: this rule concerns *editing content*
  downstream. `git add`/committing an unmodified synced file downstream is the intended end state --
  it makes future syncs diffable -- and does not violate the rule.)

### Scope

- **In scope**: Root-cause why newly-added core scripts land untracked downstream, and specify the
  fix to make HERE in nvim.
- **Out of scope**: Implementing the fix (that is the implementation phase); modifying the sync or
  `task-lock.sh`; any change to the Hardware repo.

---

## Findings (grounded in the sync code)

### 1. Load Core deploys `task-lock.sh` correctly -- the manifest is not the gap

`M.load_all_globally` (sync.lua:950) is the Load Core entry point. It scans artifacts via
`M.scan_all_artifacts` (sync.lua:713). Scripts are collected at:

```
sync.lua:844   artifacts.scripts = sync_scan("scripts", "*.sh", true, nil, "scripts")
```

`sync_scan` post-filters results against an allow-list built from the core manifest's provides:

```
sync.lua:723   local core_provides = manifest.get_core_provides(extension_cfg)
sync.lua:724   local allow_list = core_provides and manifest.build_allow_list(core_provides) or nil
...
sync.lua:773   if allow_list and filter_category and allow_list[filter_category] then
sync.lua:790     if allowed[file_info.name] then table.insert(filtered, file_info) end
```

`task-lock.sh` IS present in that allow-list -- `.claude/extensions/core/manifest.json`
`provides.scripts` contains `"task-lock.sh"` (near line 137; `jq '.provides.scripts | index("task-lock.sh")'`
returns a valid index). So the file passes the allow-list and is deployed. The manifest is NOT
missing an entry; the deployment source of truth for scripts is
`.claude/extensions/core/scripts/` (see finding 4), and that copy exists and is byte-identical.

Conclusion: this is a "no signal to commit" defect, not a "not deployed" or "deployed from the
wrong place" defect.

### 2. "copy" == brand-new local file; that is exactly `task-lock.sh` downstream

Per-file action is assigned in `scan.lua`:

```
scan.lua:137   local action = vim.fn.filereadable(local_file) == 1 and "replace" or "copy"
```

`action = "copy"` means the file did not previously exist in the target repo. When Load Core first
deployed `task-lock.sh` into Hardware (a repo whose last `.claude/scripts/` commit predated the
introduction of `task-lock.sh` to core), it was a `"copy"`: written fresh, and therefore untracked.
Sibling scripts were `"replace"` (already present, already tracked) or were `"copy"` at an earlier
time and then committed by the user.

### 3. The sync performs no git operation in the target repo -- tracking is never automated

The actual write is a plain filesystem write:

```
sync.lua:406   local write_success = helpers.write_file(file.local_path, content)
sync.lua:409     if preserve_perms and file.name:match("%.sh$") then
sync.lua:410       helpers.copy_file_permissions(file.global_path, file.local_path)
```

A tree-wide search confirms there is no staging or committing anywhere in the picker:

```
grep -rln 'git add|git commit|git -C|git status|ls-files|git stage' \
  lua/neotex/plugins/ai/claude/commands/picker/   ->   (no matches)
```

So git-tracking of any deployed file is entirely a manual, out-of-band downstream action. Existing
tracked scripts in Hardware are tracked only because a human ran `git add`/commit at some earlier
point. Any newly-added core script (task-lock.sh today; whatever is added tomorrow) will always
start untracked and stay that way until the user notices and commits it.

### 4. Source-of-truth note: the two script directories

For `.claude`, the sync reads scripts from the core extension directory, not from `.claude/scripts/`:

```
sync.lua:732   local core_source_base = (base_dir == ".claude") and ".claude/extensions/core" or nil
```

with `sync_scan("scripts", ...)` defaulting `use_core_source` to true (sync.lua:762-768). So the
deployment source of truth is `.claude/extensions/core/scripts/task-lock.sh`; `.claude/scripts/` is
the dev-facing/local working copy. Today both copies are byte-identical, so this is not the cause,
but the duplication is a latent hazard: a future edit to only one copy would deploy stale content or
miss the manifest gate. Worth a secondary guard (see Alternatives) but not required to fix this bug.

### 5. The completion notification hides the one fact the user needs

`execute_sync` reports results as category counts only:

```
sync.lua:480-497   helpers.notify("Synced %d artifacts ... Scripts: %d ...", ...)
```

It never lists filenames, and never separates "new/untracked" from "replaced/tracked". The
information needed to act ("a new file `task-lock.sh` was created and is not in git") exists at sync
time (each file carries `action` and `local_path`) but is discarded. This is the concrete surface
to fix.

---

## Root Cause (summary)

```
Load Core deploys task-lock.sh (it is in the core allow-list) ->
  target repo never had it -> scan.lua classifies action = "copy" ->
    helpers.write_file writes it to disk ->
      NO git add / git commit anywhere in the sync path ->
        file sits untracked; completion notice shows only "Scripts: N",
        never the filename or its untracked status ->
          user finds a lone stray untracked file during routine git status.
```

The mechanism *deliberately* leaves committing to the user (it cannot know a downstream project's
commit policy, and auto-committing would be surprising). The defect is the **missing signal**: the
sync knows which files it newly created but never tells the user which of them are untracked.

---

## Proposed Fix (to implement HERE in nvim)

### Recommended: surface newly-deployed untracked files in the Load Core completion notice

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`

**Change**:
1. Have `sync_files` (sync.lua:339) additionally collect the `local_path` of every file it writes
   whose `action == "copy"` (new file), returning that list alongside `success_count` /
   `protected_count`. Thread the collected lists up through `execute_sync` (sync.lua:430).
2. In `execute_sync` (or a post-write step in `load_all_globally`), if the target `project_dir` is a
   git work tree (`git -C <project_dir> rev-parse --is-inside-work-tree`), run a single
   `git -C <project_dir> status --porcelain --untracked-files=normal -- .claude` (one process, not
   per-file) and intersect the `??` entries with the set of newly-copied `local_path`s.
3. Append an explicit section to the completion notification, e.g.:

   ```
   Newly deployed (untracked in git) - review and commit:
     .claude/scripts/task-lock.sh
     .claude/<...any other new core file...>
   ```

   Display relative-to-project paths (the notify block already computes relative paths for the audit
   section at sync.lua:1146-1148; reuse that approach).
4. Guard: if `project_dir` is not a git repo, skip the git query silently and behave exactly as
   today. Never fail the sync on a git error (mirror the non-blocking posture of the content audit).

**Why this is the leading option**:
- It respects the established boundary that downstream git state belongs to the user (no silent
  mutation), while giving the user the one actionable fact they currently lack.
- It generalizes: every future newly-added core script/agent/rule/etc. gets flagged automatically,
  not just `task-lock.sh`.
- It is self-contained to `sync.lua`, reuses existing per-file `action` data and the existing
  notification plumbing, and adds at most one `git` subprocess per sync.

### Alternative A: opt-in auto-stage (not auto-commit)

After collecting the newly-copied untracked files, `git -C <project_dir> add -- <paths>` them so
they appear staged in `git status` and cannot be silently lost. Gate behind a picker/config flag
(default off). Rejected as the default because staging mutates the downstream git index without
explicit user consent; offered as an opt-in for users who want zero-friction tracking.

### Alternative B: emit a machine-readable deployed-core manifest downstream

Write a small `.claude/.core-manifest.json` (list of deployed core relative paths + a version) into
the target during sync, so a downstream `git status` hook or CI check can diff tracked files against
the manifest and flag untracked core files. Heavier, adds a new artifact to maintain, and does not by
itself solve the interactive notification gap -- best considered a complement to the recommended fix,
not a replacement.

### Secondary hardening (optional, separate concern)

Add a dev-time check that `.claude/scripts/*.sh` and `.claude/extensions/core/scripts/*.sh` stay
byte-identical and that every deployment-source script appears in `provides.scripts`. This prevents
a future divergence between the two script directories (finding 4) from silently deploying stale or
unlisted content. Out of scope for this task's core fix.

---

## Acceptance Criteria

- [ ] After a Load Core sync into a git-backed target project, the completion notification lists,
      by project-relative path, every core file it newly created (`action == "copy"`) that is
      untracked in the target repo's git.
- [ ] When Load Core deploys `task-lock.sh` into a repo where it was previously absent, that file
      appears in the "newly deployed (untracked)" list.
- [ ] The sync performs NO `git add` and NO `git commit` in the target repo by default (downstream
      git state unchanged except for files written to disk). Any staging is opt-in only.
- [ ] When the target project is not a git repository, the sync completes normally with no git
      error surfaced (parity with current behavior).
- [ ] Existing sync behavior is preserved: category counts, `.syncprotect` protection, extension
      section preservation, and post-sync merge re-injection all continue to work unchanged.
- [ ] The change is confined to the nvim source of truth
      (`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, plus any helper it needs);
      no `.claude/` script content and no downstream repo is modified as part of this fix.

---

## References (file:line)

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `M.load_all_globally` entry point: line 950
  - `M.scan_all_artifacts`: line 713; allow-list build: lines 723-724; script scan: line 844
  - `sync_files` writer (no git): lines 339, 406-413
  - `execute_sync` notification (counts only): lines 430, 480-497
  - core source base for `.claude`: line 732
  - relative-path display precedent (content audit): lines 1146-1148
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
  - action classification (`"replace"` vs `"copy"`): line 137
- `.claude/extensions/core/manifest.json`
  - `provides.scripts` contains `"task-lock.sh"`: near line 137
