# Research Report: Task #874

**Task**: 874 - Fix stale self-sync guard blocking nvim deploy-tree regeneration
**Started**: 2026-07-15T17:20:00Z
**Completed**: 2026-07-15T17:30:00Z
**Effort**: Small (single guarded early-return + one category-population guard)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/init.lua` (keymap wiring)
- Git history: `.gitignore`, commit "chore: gitignore and untrack the .claude/ deploy tree"
- Empirical scratchpad tests against fake project dirs (see Appendix)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- The self-sync guard is exactly where the task description says: `M.load_all_globally()` in
  `sync.lua`, lines 1146-1150 (`if project_dir == global_dir then ... return 0 end`). It is safe
  to remove for every artifact category **except** `lib` and `tests`.
- Empirically confirmed (headless-nvim scratchpad test, real `scan.lua` module, fake dirs only):
  for core-sourced categories (commands, agents, skills, hooks, docs, scripts, rules, context,
  systemd — everything routed through `core_source_base` = `agent-system/extensions/core/`),
  self-load produces genuinely different `global_path`/`local_path` pairs, so removing the guard
  correctly regenerates `.claude/` from the durable core source, exactly as intended.
- Empirically confirmed: for `lib` and `tests` (the two categories flagged in the task's research
  notes, `sync_scan(..., false)` at `sync.lua:1065-1066`), self-load produces a **byte-identical**
  `global_path == local_path` string. This is the "degenerate copy-onto-itself" the task warns
  about. It must be handled/excluded, not left as-is.
- Empirically confirmed the underlying read+write mechanism (`helpers.read_file` /
  `helpers.write_file`, i.e. `vim.fn.readfile` then `vim.fn.writefile`) is a full buffered
  read-to-memory followed by a separate write — content-safe even when source and destination
  path are literally the same file (verified round-trip byte-for-byte in the scratchpad). So the
  self-referential case for `lib`/`tests` is **not a data-loss risk**, but it *is* a correctness
  gap: because these two categories have no durable core-store source, a true "wipe `.claude/`
  and regenerate" cycle would silently produce zero files for them (their "source" is also
  wiped), giving a false impression of full regeneration.
- Confirmed `root_files` stays `{}` for `base_dir == ".claude"` (line 1084) regardless of
  self-load, so root-level `CLAUDE.md` is never touched by this path — third research note is a
  non-issue, already correctly excluded.
- Confirmed the `settings` category is never populated for `.claude` (guarded by
  `if not core_source_base`, and `core_source_base` is always truthy for `.claude` per lines
  913-923) — not a self-load-specific risk either.
- Confirmed `.syncprotect` already exists at the nvim repo root, so the auto-seed write path in
  `load_all_globally` will not fire on the first self-load run.
- A second, structurally similar guard exists at `sync.lua:1392` inside
  `M.update_artifact_from_global()` ("Cannot update artifacts in the global directory"). It is
  **not** named in the task's research notes and is not required to unblock `<leader>al` bulk
  regeneration (a different entry point, single-artifact update rather than load-all). Recommend
  leaving it untouched in this task to keep the fix minimal and time-boxed; flagged as a candidate
  follow-up only.

## Context & Scope

The task asks to remove/rework the early-return guard in `load_all_globally()` that prevents the
nvim repo (where `project_dir == global_dir`, i.e. `~/.config/nvim`) from running its own
`<leader>al` "load all globally" sync. The guard predates the source-store relocation
(`agent-system/extensions/core/` is now the canonical read source for core artifact categories;
`.claude/` is a gitignored, disposable deploy tree per `.gitignore` and confirmed live: `.claude/`
exists on disk but `git ls-files .claude` returns 0 tracked files).

Scope is limited to `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` per the
task's `file_scope`. Research also touched `scan.lua` and `helpers.lua` (read-only) to trace the
actual path-resolution and file I/O mechanics invoked by the guarded code path.

## Findings

### Codebase Patterns

**The guard** (`sync.lua`):
```
1141  function M.load_all_globally(config)
1142    local project_dir = vim.fn.getcwd()
1143    local global_dir = scan.get_global_dir()
1144    local base_dir = (config and config.base_dir) or ".claude"
1145
1146    -- Don't load if we're in the global directory
1147    if project_dir == global_dir then
1148      helpers.notify("Already in the global directory", "INFO")
1149      return 0
1150    end
```
`<leader>al` (visual-mode keymap, wired in `core/visual.lua`, dispatched via
`commands/picker/init.lua:112`) calls `sync.load_all_globally(config)` directly — this is
confirmed to be the entry point named in the task.

**The read/write split** (`scan_all_artifacts`, lines 913-923): for `base_dir == ".claude"`,
`core_source_base` is always derived as a non-nil, non-empty string
(`{relative_extensions_dir}/core`, currently `"agent-system/extensions/core"`) from
`extension_cfg.global_extensions_dir`. This is the *read* side. The *write* side
(`local_path` in every `sync_scan` call) is always `project_dir .. "/" .. base_dir .. "/" ..
subdir`, i.e. `.claude/{subdir}`. For every category that passes `use_core_source` as its
default (`nil`/`true`) — commands, agents, skills, hooks, templates, docs, scripts, rules,
context, systemd — the read path (`agent-system/extensions/core/{subdir}`) and the write path
(`.claude/{subdir}`) are **structurally different directories even when `project_dir ==
global_dir`**. Removing the top-level guard lets these categories regenerate `.claude/` from the
core store exactly as they do for every other (non-self) target repo. This was verified
empirically (see Appendix): a `commands` category scan in a self-load configuration returned
`global_path` under `agent-system/extensions/core/commands/` and `local_path` under
`.claude/commands/` — different strings, correct "replace" semantics.

**The `lib`/`tests` correctness risk** (lines 1063-1066, current):
```
1063  -- .claude-specific artifacts (directories that don't exist in .opencode/)
1064  -- lib and tests are not core extension categories; read from base_dir root
1065  if base_dir == ".claude" then
1066    artifacts.lib = sync_scan("lib", "*.sh", true, nil, nil, false)
1067    artifacts.tests = sync_scan("tests", "test_*.sh", true, nil, nil, false)
```
The trailing `false` argument is `use_core_source = false`, which forces
`source_base = nil` inside `sync_scan`, which in turn makes
`scan_directory_for_sync`'s `effective_source_base` fall back to plain `base_dir` (`.claude`)
instead of `core_source_base`. Concretely: `global_path = global_dir .. "/.claude/lib"` and
`local_path = local_dir .. "/.claude/lib"`. When `project_dir == global_dir` these two paths are
**the same string**, confirmed empirically:
```
lib self-referential? true
tests self-referential? true
commands self-referential? false
```
(full output in Appendix). This is precisely the "degenerate copy-onto-itself" the task's
research notes warn about.

**Why it is not a data-loss risk, but is a correctness gap.** `sync_files` (lines 340-425) does:
```lua
local content = helpers.read_file(file.global_path)   -- vim.fn.readfile: full buffered read
...
local write_success = helpers.write_file(file.local_path, content)  -- vim.fn.writefile
```
Both `helpers.read_file` and `helpers.write_file` (`picker/utils/helpers.lua:51,70`) wrap
`vim.fn.readfile` / `vim.fn.writefile`, which are synchronous, whole-file operations — the read
fully completes and returns an in-memory Lua table of lines before the write ever truncates the
target. There is no streaming or lazy-read involved. A scratchpad round-trip test (read a file
into memory, then `vim.fn.writefile` the same content back to the exact same path) reproduced
this and confirmed the file's content is preserved byte-for-byte. So a `lib`/`tests` self-copy,
*if it had files to copy*, would not corrupt or truncate them.

The actual problem is architectural: `git log --oneline --all -- '.claude/lib' '.claude/tests'`
shows both directories were tracked and populated **before** the deploy-tree
gitignore/untrack commit. Neither `agent-system/extensions/core/` nor any other extension
currently ships an equivalent `lib/`/`tests/` category — these two categories are vestigial
leftovers from the pre-migration layout with **no durable source** anywhere in the new
architecture. Currently, on this exact repo, `.claude/lib` and `.claude/tests` do not exist at
all (`find agent-system/extensions/core -iname lib -o -iname tests` and
`ls .claude/lib .claude/tests` both come back empty), so today the self-load scan for these two
categories returns zero files regardless of the guard. But that emptiness is coincidental, not
enforced: if either directory were ever repopulated inside the disposable `.claude/` tree (e.g.
a stray manual file, or a future workflow that writes there), a full "wipe-`.claude/`-then-
regenerate" cycle would wipe the only copy and then "regenerate" nothing for those two
categories, silently, while the sync summary would still report `Lib: 0 | Tests: 0` as if that
were expected/complete rather than a blind spot in coverage. This matches the task's explicit
instruction to "handle or exclude them if so."

**Root file exclusion (research note 3, confirmed non-issue).** Lines 1080-1085:
```lua
local root_file_names
if base_dir == ".opencode" then
  root_file_names = { "AGENTS.md", "OPENCODE.md", ... }
else
  root_file_names = {}
end
```
For `base_dir == ".claude"`, `root_file_names` is unconditionally `{}` — `artifacts.root_files`
stays empty regardless of self-load status. Root-level `CLAUDE.md` (outside `.claude/`) is
explicitly and separately never synced per the comment at lines 1126-1129 (Neovim-specific
standards would be inappropriate to overwrite in target repos; irrelevant to self-load since it's
already unconditionally excluded). No change needed here.

**Settings category (also confirmed non-issue).** Line 1069:
`if not core_source_base then artifacts.settings = sync_scan(...) end`. Since `core_source_base`
is always truthy for `.claude` (derived unconditionally at lines 913-923 whenever
`extension_cfg.global_extensions_dir` resolves, which it always does for the `.claude` preset),
this branch never executes for `.claude` — `settings.json` sync via this path is already
universally disabled for `.claude`, self-load or not.

**`.syncprotect` auto-seed (checked, no risk).** `~/.config/nvim/.syncprotect` already exists
(277 bytes, includes `context/repo/project-overview.md` and `output/implementation-001.md`), so
the auto-seed branch in `load_all_globally` (lines ~1262-1310, `if
vim.fn.filereadable(syncprotect_path) == 0`) will not fire and will not overwrite anything on a
self-load run.

**`detect_untracked` advisory (pre-existing property, not new).** `.claude/` is blanket-gitignored
(`/.claude/` in `.gitignore`), so `git status --porcelain -- .claude` never reports entries
(ignored paths are excluded by default without `--ignored`). The "Newly deployed (untracked in
git) — review and commit" advisory in `execute_sync` will therefore always report an empty list
for `.claude` regardless of self-load — this was already true before this task and is unaffected
by the guard removal.

**Related but out-of-scope guard.** `sync.lua:1392`, inside `M.update_artifact_from_global()`
(used for single-artifact "update from global" picker actions, a different code path from
`load_all_globally`):
```lua
if project_dir == global_dir then
  if not silent then
    helpers.notify("Cannot update artifacts in the global directory", "WARN")
  end
  return false
end
```
This has the same self-referential character but is not named in the task description, not
required to unblock `<leader>al` bulk regeneration (the task's explicit unblocking target), and
touching it adds surface area to a time-critical fix. Recommend leaving it as a follow-up
candidate rather than modifying it here.

### External Resources

Not applicable — this is a pure codebase-internal fix with no external library/API surface.

### Recommendations

1. **Remove the early-return guard** in `M.load_all_globally()` (current lines 1146-1150) so
   `project_dir == global_dir` no longer short-circuits before scanning. The rest of the function
   already handles the "nothing to sync" (`total_files == 0`) and "already in sync"
   (`total_copy + total_replace == 0`) cases generically, so no separate self-load messaging path
   is required — the existing generic notifications cover it.
2. **Guard the `lib`/`tests` population, not the whole function**, inside `scan_all_artifacts`
   (lines 1063-1072). `scan_all_artifacts(global_dir, project_dir, config)` already receives both
   `global_dir` and `project_dir` as parameters, so the self-load condition
   (`project_dir == global_dir`) is cheaply available at exactly the point these two categories
   are populated. Skip populating `artifacts.lib` / `artifacts.tests` in that case (leave them
   `nil`/absent, which `execute_sync`'s `all_artifacts.lib or {}` pattern already handles safely).
   Suggested comment for the implementer to adapt (keep it durable/anchor-based per the
   no-task-references rule — do not cite this task number in the comment):
   ```lua
   -- lib/tests have no durable core-store source (unlike every other category, which
   -- reads from agent-system/extensions/core/); they still read directly from
   -- {base_dir}/lib and {base_dir}/tests. In a self-load (project_dir == global_dir)
   -- that source path is byte-identical to the destination path, so syncing them here
   -- would be a no-op self-copy at best and a false "fully regenerated" signal at worst
   -- if the directories are ever repopulated. Skip them for self-load; they are not
   -- restorable by this mechanism regardless of the top-level self-sync guard.
   local is_self_load = project_dir == global_dir
   if base_dir == ".claude" and not is_self_load then
     artifacts.lib = sync_scan("lib", "*.sh", true, nil, nil, false)
     artifacts.tests = sync_scan("tests", "test_*.sh", true, nil, nil, false)
     ...
   end
   ```
   (The `settings` sub-branch inside this same `if base_dir == ".claude"` block is already
   unconditionally skipped for `.claude` per the `core_source_base` analysis above, so it does not
   need an additional self-load check — but keep it inside the same `if` guard structure the
   implementer chooses, whichever is cleanest against the surrounding code.)
3. **Do not touch `M.update_artifact_from_global`** (line ~1392) in this task — different entry
   point, not named in the task description, not required to unblock `<leader>al`.
4. **No change needed** to the `root_file_names = {}` exclusion or the `settings` category gate —
   both already correctly prevent self-load issues as static code, confirmed by trace above.
5. After the edit, a live functional check (not a fabricated claim) requires actually invoking
   `<leader>al` (or `sync.load_all_globally()` from a `:lua` command) from within
   `~/.config/nvim` once the fix lands, and confirming: (a) `.claude/` categories sourced from
   `agent-system/extensions/core/` populate/refresh correctly, (b) no `lib`/`tests` entries are
   reported as synced, (c) `CLAUDE.md` under `.claude/` is unaffected (still governed by the
   `root_files`/extension-loader path per the existing comment), (d) no errors are raised. This
   was **not** performed as part of this research pass (per the task's testing constraint, all
   destructive loader testing must happen in the scratchpad against fake dirs, and a full
   `load_all_globally()` invocation also depends on live extension-manifest resolution that was
   not fully replicated in the scratchpad — see Appendix). This should be the implementer's or a
   follow-up manual-verification step, and must be reported as actually-observed, not assumed.

## Decisions

- Recommend a **surgical two-part fix**: (a) delete the top-level self-load early return, (b)
  add a narrow self-load guard scoped only to the `lib`/`tests` category population inside
  `scan_all_artifacts`. This is the minimal change that satisfies both the task's primary goal
  (unblock `<leader>al` self-regeneration) and its explicit correctness constraint (no degenerate
  self-copy for the two non-core-sourced categories).
- Recommend leaving `M.update_artifact_from_global`'s analogous guard (line ~1392) untouched —
  out of the named scope, not blocking, and touching it adds unnecessary risk/surface to a
  time-critical fix.
- Recommend no changes to `root_file_names`, the `settings` gate, `.syncprotect` auto-seed, or
  `detect_untracked` — all traced and confirmed to already behave correctly (or identically
  regardless of self-load) as static code.

## Risks & Mitigations

- **Risk**: full end-to-end `load_all_globally()` behavior (allow-list/blocklist manifest
  resolution, extension config loading, the confirm-dialog UX) was not exercised end-to-end in
  this research pass because faithfully replicating `agent-system/extensions/core/manifest.json`
  and the full extension-config resolution chain in a scratchpad fake repo is substantial setup
  beyond what a research pass should attempt destructively. **Mitigation**: the two path-
  resolution primitives that actually determine self-load correctness
  (`scan_directory_for_sync`'s global/local path derivation, and the `read_file`/`write_file`
  round-trip safety) were verified directly and empirically against the real, unmodified source
  modules — this is the part of the mechanism that actually differs under self-load vs.
  normal-target-repo sync. The implementer should still do one live invocation after the edit
  lands (see Recommendation 5) and report the actually-observed result.
- **Risk**: if a future extension ever adds a legitimate `lib/`/`tests`-equivalent core category
  with a real `agent-system/extensions/core/` source, the exclusion added here would need to be
  revisited (the category would then behave like every other core-sourced category and the
  self-load exclusion would become unnecessary/wrong). **Mitigation**: the recommended code
  comment above explains *why* the exclusion exists, so a future change to add a durable
  lib/tests source will naturally prompt removing the self-load guard alongside it.

## Context Extension Recommendations

- **Topic**: self-load / regeneration semantics of the `<leader>al` sync picker.
- **Gap**: no existing context file documents the read/write split (`core_source_base` vs.
  `base_dir`) or which artifact categories are core-sourced vs. legacy/`base_dir`-sourced. This
  research had to be reconstructed from source each time.
- **Recommendation**: consider adding a short section to
  `.claude/context/project/neovim/domain/extension-deploy-modes.md` (already referenced in prior
  task metadata as covering deploy-mode concepts) documenting which sync categories are
  core-sourced vs. `base_dir`-sourced, and the self-load implications of each — this is exactly
  the kind of fact that would have accelerated this research pass and will likely recur if the
  `lib`/`tests` vestigial categories are ever revisited.

## Appendix

### Search queries / commands used

- `jq -r '.active_projects[] | select(.project_number==874)' specs/state.json`
- `grep -n "Don't load if we're in the global directory\|Already in the global directory\|function M.load_all_globally\|if project_dir == global_dir" sync.lua`
- `git log --oneline --all -- '.claude/lib' '.claude/tests'`
- `grep -n "^\.claude" .gitignore`; `git ls-files .claude | wc -l` (confirms 0 tracked files)
- Scratchpad empirical test (headless nvim, real `scan.lua` module, fake dirs only — never
  touched `~/.config/nvim/.claude`):
  - Fake repo at
    `/tmp/claude-1000/-home-benjamin--config-nvim/<session>/scratchpad/874_test/fake_repo/`
    with `agent-system/extensions/core/commands/foo.md`, `.claude/commands/foo.md`,
    `.claude/lib/bar.sh`, `.claude/tests/test_baz.sh`.
  - `nvim --headless -u NONE -c "set rtp+=." -c "lua dofile('.../test_scan.lua')" -c "qa!"`
    calling `scan.scan_directory_for_sync(FAKE, FAKE, ...)` with `global_dir == local_dir` for
    three categories (`commands` with `source_base_dir = "agent-system/extensions/core"`; `lib`
    and `tests` with `source_base_dir = nil`). Output:
    ```
    commands self-referential? false
    lib self-referential? true
    tests self-referential? true
    ```
  - Direct `vim.fn.readfile` + `vim.fn.writefile` round-trip on the same self-referential fake
    path (`.claude/lib/bar.sh`): content preserved byte-for-byte (`LIB CONTENT V1` before and
    after).

### References

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (primary edit target)
  - `M.scan_all_artifacts` (lines 890-1135, notably 913-923 core_source_base derivation,
    934-990 `sync_scan` helper, 1063-1072 lib/tests/settings block, 1080-1129 root_files)
  - `M.load_all_globally` (lines 1141-1371, guard at 1146-1150)
  - `M.update_artifact_from_global` (lines 1379+, related guard at 1392, out of scope)
  - `sync_files` (lines 340-425, actual read/write mechanics)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
  - `M.get_global_dir` (lines 8-17)
  - `M.scan_directory_for_sync` (lines 55-151, path derivation confirmed by empirical test)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua`
  - `M.read_file` / `M.write_file` (lines 51-73, confirmed full-buffer read-then-write)
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua:112` (confirms `<leader>al` calls
  `sync.load_all_globally(config)`)
- `.gitignore` (blanket `/.claude/` exclusion, confirming the deploy-tree-is-disposable premise)
