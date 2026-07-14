# Implementation Plan: Fix Loader Symlink Delete Data Loss

- **Task**: 862 - Fix data loss in the extension loader: `remove_installed_files()` destroys
  tracked extension-source files through symlinks
- **Status**: [NOT STARTED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: `specs/862_fix_loader_symlink_delete_data_loss/reports/01_loader-symlink-delete-data-loss.md`
- **Artifacts**: plans/01_loader-symlink-delete-data-loss.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  `.claude/rules/neovim-lua.md`, `.claude/rules/no-task-references-in-deliverables.md`
- **Type**: neovim
- **Lean Intent**: false

## Scope

**This plan modifies `init.lua` in addition to the declared `file_scope`. Read this section
before implementing.**

The task's declared `file_scope` in state.json is
`lua/neotex/plugins/ai/shared/extensions/loader.lua` only. This plan adds a second file:

| File | In declared scope | Why it must change |
|------|-------------------|--------------------|
| `lua/neotex/plugins/ai/shared/extensions/loader.lua` | Yes | Symlink-aware removal and copy |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | **No — added** | Supplies `project_dir` to bound the ancestor walk; performs `.syncprotect` filtering; `manager.unload` never calls `load_syncprotect` today |

**The scope expansion is unavoidable under either candidate approach.** The orchestrator's
framing — that adding a `protected_paths` parameter to `remove_installed_files()` would keep the
change inside `loader.lua` — does not hold, for two independent reasons:

1. **`manager.unload` never loads `.syncprotect` at all.** `loader.lua:16` defines
   `M.load_syncprotect`, and `init.lua:389` calls it on the *load* path only. Whichever function
   ends up performing the protection check, `manager.unload` must first call `load_syncprotect` to
   obtain the set. That call site is in `init.lua`. There is no way to honor `.syncprotect` on
   unload without touching `init.lua`.
2. **The symlink ancestor walk needs a bound, and only the caller knows it** (see the empirical
   finding on bounding below). `project_dir` lives in `init.lua`.

So the choice is not "expand scope or not" — it is *where to put the protection check*. Both
options change both files.

### Decision: filter `.syncprotect` at the `init.lua` call sites (research option (a))

Rejected alternative: add a `protected_paths` parameter to `remove_installed_files()` and
re-derive each `rel_path` inside `loader.lua`. Rejected because:

- **`init.lua` already holds the relative path in the exact stored form.** At `init.lua:653` the
  loop variable `rel_path` is literally `.claude/agents/literature-agent.md`; the next line
  converts it to absolute. Filtering there consumes data already in hand. `loader.lua` would
  receive only the absolute path and have to reverse-engineer the relative form that `init.lua`
  had just discarded — requiring `project_dir` *and* `base_dir` to be threaded in purely to undo a
  transform performed one line earlier.
- **Key-shape derivation is required either way, so it is not a differentiator** (confirmed
  empirically, below). Locating it where the inputs already exist is strictly simpler.
- **It keeps `remove_installed_files()` a pure function over plain path arrays**, which is what
  makes the Phase 2 unit test cheap: research Finding 7 depends on being able to call it directly
  with no global state, no `.claude/extensions.json`, and no `manager.unload`.

**But symlink safety does NOT move to the call sites.** It stays inside `loader.lua`, and
`remove_installed_files()` gains one optional `opts` table carrying `project_dir`. Rationale:
`remove_installed_files()` is the primitive that destroys data. A defense that lives only in its
callers is one forgotten caller away from reintroducing the bug — and there are already two call
sites, one of which (the rollback path at `init.lua:517`) is easy to overlook. The dangerous
primitive defends itself; `.syncprotect` is a policy filter and belongs with the policy data.

### Empirical findings that drove these decisions

Verified during planning; the implementer should not re-derive them:

- **`.syncprotect` key shape mismatch is real.** `.syncprotect` entries are relative to the *base
  dir* (actual file contents: `context/repo/project-overview.md`), while `installed_files` in
  state are relative to the *project root* (`.claude/agents/literature-agent.md`). The filter must
  strip the `base_dir .. "/"` prefix. At `init.lua:653` this is
  `rel_path:sub(#config.base_dir + 2)`, with `config.base_dir` already in scope.
- **`vim.fn.getftype()` returns `"link"` for dangling symlinks**, so the `getftype == "link"`
  check correctly classifies broken links; no separate dangling-link branch is needed.
- **Dangling symlinks are already never removed.** `filereadable()` returns 0 for them, and the
  existing guard at `loader.lua:760` is `filereadable(filepath) == 1`. They are inert with respect
  to this bug.
- **Bounding the walk matters for correctness, not just safety.** This repository is not currently
  reached through a symlink, but `~/.config/nvim` is very commonly a stow/dotfiles symlink on
  other machines. An unbounded upward walk would find that symlink, classify every deployed file
  as symlink-descended, skip all of them, and silently turn unload into a no-op. The walk must
  stop at `project_dir`.

## Overview

`loader.lua`'s copy engine has no symlink awareness, while a parallel installer
(`install-extension.sh`) deliberately deploys 10 skills, 7 agents, and 3 commands as symlinks
into the same target directories. When the picker reloads such an extension,
`remove_installed_files()` iterates into symlinked skill directories and deletes the plain files
inside them, destroying the real extension-source files. This plan makes both the remove path and
the copy path symlink-aware under a single ownership rule, filters `.syncprotect` on the remove
path so protection is symmetric with copy, and restores the two agent/command files that were
already silently flattened from symlinks into regular files.

Definition of done: a scratch-only headless-nvim test proves a symlinked deployed skill's source
file survives `remove_installed_files()`; `.syncprotect` entries are honored on remove as they are
on copy; symlink deploy mode survives a full unload/load cycle without flattening; and the design
decision is recorded durably in code and context so it is not relitigated.

### Research Integration

The research report supersedes the original task description's stated mechanism. Three findings
drive this plan's shape:

1. **The mechanism is ancestor-directory traversal, not final-component symlink following.**
   `vim.fn.delete()` on a symlink-to-file removes only the link (safe). `vim.fn.delete()` on a
   *plain file reached through a symlinked ancestor directory* destroys the real target — standard
   POSIX `unlink()` semantics, where only the final component's own symlink-ness is consulted. The
   skills case (`skill-literature/` is a symlinked directory, `SKILL.md` inside it is an ordinary
   file) is the only destructive path. The fix must key on **ancestor** symlink detection; a
   per-file "is this a symlink" check would miss the bug entirely.
2. **Symlink deploy mode is a supported feature**, proved by `install-extension.sh` /
   `uninstall-extension.sh`, which create and remove these symlinks and are already symlink-aware.
   "Refuse to install over a symlink" is off the table: it would break the currently-deployed
   `literature`, `cslib`, and `pr` extensions.
3. **The copy side flattens symlinks independently of the remove side.** Because delete-on-a-
   symlink-to-file only removes the link, a subsequent `copy_file()` writes a brand-new *regular*
   file into that slot. Fixing only the remove path leaves agents/commands silently degrading from
   symlinks to copies on every reload.

### Design Decision (durable — do not relitigate)

**Rule: the copy engine owns only the paths it created as regular files. Symlinked deployed paths
are owned by `install-extension.sh` and are never written through, and never deleted, by
`loader.lua`.**

This plan **deliberately declines** the research report's remove-side recommendation (unlink the
symlinked ancestor once via `delete(dir, "rf")`) in favour of skipping symlinked and
symlink-descended paths and warning. Justification:

- **`loader.lua` cannot recreate what it unlinks.** It contains no `ln -s` / `vim.uv.fs_symlink`
  anywhere; `install-extension.sh` is the sole symlink-creating mechanism in the repository.
- **The research report's combined recommendation is internally inconsistent on the reload path.**
  It recommends (i) unlinking the symlinked ancestor on remove, and (ii) skipping the copy when
  the target is a *pre-existing* symlink. But `manager.reload` is literally `unload()` then
  `load()` (`init.lua:717-723`). Step (i) unlinks the symlinked skill directory, so by the time
  step (ii) runs there is **no pre-existing symlink left to detect** — the guard cannot fire,
  `helpers.ensure_directory` creates a real directory, and the skill is copied in as plain files.
  Unlinking on remove actively defeats the copy-side guard and reintroduces the flattening symptom
  for skills, this time caused by the fix. Skipping avoids the contradiction: the symlink is still
  there on the load half, so the copy-side guard fires as designed.
- **Accepted cost**: a genuine unload leaves symlinked artifacts in place. Mitigated by warning
  with a count and naming `uninstall-extension.sh` as the correct tool for symlink-installed
  extensions. Non-destructive and honest beats complete and lossy for a data-loss fix.
- **Also considered and rejected**: teaching `loader.lua` to create symlinks (via
  `vim.uv.fs_symlink`) so unload could unlink and load could faithfully restore. This is
  semantically complete and defeats neither guard, but requires tracking deploy mode per extension
  in state — research Finding 5 identifies `installed_symlinks` as "a larger, optional refactor".
  Out of scope here; recorded as a possible follow-up.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:

- Close the data-loss path: `remove_installed_files()` must never delete a file reached through a
  symlinked ancestor directory.
- Make `remove_installed_files()` honor `.syncprotect`, symmetrically with `copy_file()`, via
  filtering at the `init.lua` call sites.
- Make the copy path symlink-preserving so symlink deploy mode survives an unload/load cycle.
- Restore `.claude/agents/literature-agent.md` and `.claude/commands/literature.md` to symlinks,
  after the loader fix lands and only if content is verified identical to the source.
- Record the ownership rule in code and in a context document.

**Non-Goals** (each an explicit decision, not an oversight):

- **Dangling `skill-zotero` / `zotero.md` symlink cleanup — deferred to a follow-up.** These point
  at the removed `zotero` extension directory (absorbed into `literature`). They are provably
  inert with respect to this bug: `filereadable()` is 0 for a dangling link, so the existing guard
  at `loader.lua:760` already skips them, and the fix does not change that. Cleaning them is
  unrelated housekeeping that would expand the diff without reducing risk.
- **Adding an `installed_symlinks` state category** (research Finding 5's optional refactor). The
  detection approach here works without it.
- **Adding `install-extension.sh`-style target-mismatch warnings on the copy path** (research
  Risk 1). The ownership rule makes the loader skip symlinked targets entirely, closing that
  latent risk as a side effect without a mismatch check.
- **Any change to `install-extension.sh` / `uninstall-extension.sh`.**

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementation triggers a real reload/unload while testing, destroying more sources | H | M | Hard constraint restated in every phase that runs loader code: all loader execution uses a scratch `project_dir`. Both `manager.unload` and `manager.load` accept `opts.project_dir` (`init.lua:238,577`), so end-to-end tests run fully in scratch. |
| Ancestor walk escapes its bound (repo under a stow symlink), every file is skipped, unload silently no-ops | M | M | Bound the walk strictly below `project_dir`. Phase 2 asserts plain files under a non-symlinked tree are still deleted and counted — a direct guard on this failure mode. |
| `project_dir` absent, leaving the walk unbounded | H | L | Fail-safe: when `opts.project_dir` is absent, do not walk; use `vim.fn.resolve(path) ~= path` and **skip** any symlink-involved path. Refusing to delete is always the safe direction. Both call sites pass `project_dir` regardless. |
| `.syncprotect` key-shape derivation is wrong, silently protecting nothing | M | L | Key shape confirmed empirically during planning (`.syncprotect` is base-dir-relative; `installed_files` are project-root-relative). Phase 3 asserts the same entry is skipped by both a copy call and a remove call. |
| Restoring the flattened symlinks clobbers content that exists only in the regular file | M | L | Phase 6 diffs the regular file against the symlink target first and restores only on byte-identical content; any difference is surfaced as a blocker, not overwritten. |
| Skipping symlinked paths on unload leaves artifacts behind, confusing users | L | M | Warn with a count and name `uninstall-extension.sh`. Documented as an accepted trade-off above. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every phase
except 6 edits `loader.lua` or its call sites, so phases share file territory and must not run
concurrently. Phase 1 comes first because it closes the data-loss path before any later phase can
plausibly cause loader code to run.

---

### Phase 1: Close the data-loss path in `remove_installed_files()` [COMPLETED]

**Goal**: Make removal symlink-aware so no file reached through a symlinked ancestor is ever
deleted. This is the phase that stops the bleeding; nothing else runs before it.

**SAFETY CONSTRAINT**: This phase edits Lua source only. Do not invoke `manager.load`,
`manager.unload`, `manager.reload`, or the extension picker against the real `.claude/` tree at any
point. No loader execution in this phase at all.

**Tasks**:

- [x] Add a file-local helper `find_symlinked_ancestor(path, root)` to `loader.lua` that walks
      upward from `vim.fn.fnamemodify(path, ":h")` and returns the first ancestor whose
      `vim.fn.getftype()` is `"link"`, or `nil`.
- [x] Bound the walk strictly below `root`: stop when the current directory equals `root`, is no
      longer a prefix-match descendant of `root`, or when `fnamemodify(current, ":h") == current`
      (filesystem-root guard). The walk must never inspect or return `root` itself or anything
      above it. This bound is load-bearing: `~/.config/nvim` is commonly a stow symlink, and an
      unbounded walk would skip every file and turn unload into a silent no-op.
- [x] Change the signature to `M.remove_installed_files(installed_files, installed_dirs, opts)`
      where `opts` is an optional table carrying `project_dir`. Keep `opts` optional so the
      function stays directly unit-testable and existing positional callers remain valid.
      **Do not** add `protected_paths` here — `.syncprotect` is filtered at the call sites in
      Phase 3; see the Scope section for why.
- [x] In the file-removal loop (`loader.lua:759-764`), classify each `filepath` before deleting:
      if `vim.fn.getftype(filepath) == "link"`, skip it (owned by `install-extension.sh`, per the
      ownership rule); else if `opts.project_dir` is set and `find_symlinked_ancestor(filepath,
      opts.project_dir)` returns non-nil, skip it (this is the destructive Case A path); else
      delete as today.
- [x] Implement the fail-safe branch: when `opts.project_dir` is absent, skip any path where
      `vim.fn.resolve(filepath) ~= filepath` rather than walking.
- [x] Return a third value `skipped_count` alongside `removed_count`, counting every path skipped
      for symlink reasons, so callers can report it.
- [x] Add a LuaDoc block on `remove_installed_files` stating the ownership invariant: the copy
      engine owns only paths it created as regular files; symlinked deployed paths belong to
      `install-extension.sh` and are never deleted here. Do not cite a task number in the comment.
- [x] Leave the directory-removal loop (`loader.lua:766-782`) unchanged: `vim.fn.readdir()` on a
      symlinked directory reports the target's contents, so a non-empty result already prevents
      removal. Confirm by reading and record the confirmation in the phase notes.
      **Phase notes**: confirmed by reading the directory-removal loop post-edit
      (`loader.lua:831-850`) — it is byte-identical to the pre-fix version except for
      surrounding comments; no symlink check was added or needed.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — add `find_symlinked_ancestor`; rewrite the
  file-removal loop in `M.remove_installed_files` (currently `loader.lua:751-785`); add the
  ownership-invariant LuaDoc.

**Verification**:

- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.loader')" -c "q"` exits
  clean (module loads, no syntax error).
- Read back the removal loop and confirm every `vim.fn.delete(filepath)` call is guarded by both
  the `getftype == "link"` check and the ancestor check.
- Behavioral proof is deferred to Phase 2; this phase's bar is "the destructive call is now
  unreachable for symlink-involved paths."

---

### Phase 2: Scratch-only verification of the removal fix [NOT STARTED]

**Goal**: Prove empirically, against real code, that the source file survives — reproducing the
research report's three cases plus a regression check, entirely in scratch.

**SAFETY CONSTRAINT**: All fixtures and all deletions occur under the scratchpad directory
`/tmp/claude-1000/-home-benjamin--config-nvim/86fe22e3-6df8-4d8d-bcaa-b7402fdaeefc/scratchpad`.
Do not invoke any loader operation against the real `.claude/` tree. `remove_installed_files` is a
pure function over plain path arrays — it can be called directly without `manager.unload`,
`.claude/extensions.json`, or any global state.

**Tasks**:

- [ ] Create the scratch fixture root at
      `/tmp/claude-1000/-home-benjamin--config-nvim/86fe22e3-6df8-4d8d-bcaa-b7402fdaeefc/scratchpad/loader-symlink-test/`
      and treat it as `project_dir` for all calls.
- [ ] Build the Case A fixture (the data-loss path): a real source file at
      `<scratch>/.claude/extensions/fakeext/skills/skill-fake/SKILL.md` with recognizable content,
      and a deployed symlink `<scratch>/.claude/skills/skill-fake` pointing at
      `<scratch>/.claude/extensions/fakeext/skills/skill-fake`, mirroring `install-extension.sh`'s
      output.
- [ ] Build the Case B fixture: a real source file
      `<scratch>/.claude/extensions/fakeext/agents/fake-agent.md` and a deployed file-level symlink
      `<scratch>/.claude/agents/fake-agent.md` pointing at it.
- [ ] Build the regression fixture: an ordinary deployed regular file
      `<scratch>/.claude/commands/plain.md` with no symlink anywhere in its path.
- [ ] Write a headless Lua test script that calls `M.remove_installed_files` directly with an
      `installed_files` array holding the deployed paths for all three fixtures and
      `opts = { project_dir = <scratch> }`.
- [ ] **Assert Case A**: `vim.fn.filereadable("<scratch>/.claude/extensions/fakeext/skills/skill-fake/SKILL.md") == 1`
      — the source file SURVIVES. This is the assertion the whole task exists for; it must fail
      against the pre-fix code and pass against the post-fix code.
- [ ] **Assert Case A (link intact)**: `vim.fn.getftype("<scratch>/.claude/skills/skill-fake") == "link"`
      — the deployed symlink is left in place per the ownership rule.
- [ ] **Assert Case B**: the deployed symlink `<scratch>/.claude/agents/fake-agent.md` still
      resolves and the source `fake-agent.md` is readable — skipped, not unlinked.
- [ ] **Assert regression**: `<scratch>/.claude/commands/plain.md` IS deleted (`filereadable == 0`)
      and is counted in `removed_count`. This guards the over-skip failure mode where the ancestor
      walk escapes its bound and unload becomes a silent no-op.
- [ ] **Assert counts**: `removed_count == 1` and `skipped_count == 2`.
- [ ] Confirm the test fails on the pre-fix code path by stashing the Phase 1 change or by running
      the equivalent raw `vim.fn.delete()` against a fresh Case A fixture, so the test is proven to
      have discriminating power rather than passing vacuously.
- [ ] Run with `nvim --headless -u NONE -c "luafile <script>" -c "q"` and capture the transcript
      into the phase notes.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:

- Scratch fixtures and test script under the scratchpad directory only. No repository files change
  in this phase.

**Verification**:

- All six assertions above pass against the post-fix code.
- The Case A assertion is demonstrated to fail against pre-fix behavior.
- No file outside the scratchpad directory is created, modified, or deleted; confirm with
  `git status` showing no unexpected changes.

---

### Phase 3: Filter `.syncprotect` at the `init.lua` call sites [NOT STARTED]

**Goal**: Make protection symmetric across copy and remove. `copy_file()` honors
`protected_paths`; the remove path currently never receives it at either call site.

**SCOPE NOTE**: This phase edits `init.lua`, which is outside the declared `file_scope`. See the
Scope section — the expansion is unavoidable because `manager.unload` never calls
`load_syncprotect` today, and that call site is in `init.lua` under any design.

**SAFETY CONSTRAINT**: Lua source edits only. Do not invoke any loader operation against the real
`.claude/` tree.

**Tasks**:

- [ ] In `manager.unload`, call `loader_mod.load_syncprotect(project_dir, config.base_dir)` to
      obtain `protected_paths`. This call does not exist on the unload path today; the load path's
      equivalent is at `init.lua:389`.
- [ ] In the absolute-path conversion loop (`init.lua:652-663`), derive the `.syncprotect` key from
      the loop's `rel_path` with `rel_path:sub(#config.base_dir + 2)` and skip appending the path
      to `abs_files` when `protected_paths[key]` is truthy. The prefix strip is required: keys in
      `.syncprotect` are base-dir-relative (`context/repo/project-overview.md`) while
      `installed_files` are project-root-relative (`.claude/agents/literature-agent.md`) — verified
      during planning.
- [ ] Apply the same filtering to the `data_skeleton_files` loop (`init.lua:657-659`) and to
      `abs_dirs` (`init.lua:660-663`).
- [ ] Count protected skips locally in `init.lua` for reporting.
- [ ] Pass `{ project_dir = project_dir }` as the third argument at the `manager.unload` call site
      (`init.lua:669`) so Phase 1's ancestor walk is bounded.
- [ ] Pass the same `opts` at the rollback call site (`init.lua:517`). This call site is inside
      `manager.load`, which already has `protected_paths` in scope from `init.lua:389`; apply the
      same filtering to `all_files`/`all_dirs` before the rollback call.
- [ ] Extend the unload notification (`init.lua:693-696`) to report the protected-skip and
      symlink-skip counts alongside `removed_count`, naming `uninstall-extension.sh` as the tool
      for symlink-installed extensions when the symlink-skip count is non-zero.

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/init.lua` — `manager.unload` (`load_syncprotect` call,
  filtering at `:652-663`, `opts` at `:669`, notification at `:693-696`); `manager.load` rollback
  path (`:517`). **Outside declared file_scope — see Scope section.**
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — no change in this phase.

**Verification**:

- Extend the Phase 2 scratch script: add a `<scratch>/.syncprotect` containing a protected entry,
  add a matching deployed regular file fixture, and assert that file is NOT deleted while an
  unprotected sibling regular file IS.
- Assert the derived key shape matches what `copy_file` receives, by asserting the same
  `.syncprotect` entry is skipped on both a copy call and a remove call.
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.init')" -c "q"` exits clean.
- All Phase 2 assertions still pass (no regression from the `opts` argument).

---

### Phase 4: Preserve symlinks on the copy path [NOT STARTED]

**Goal**: Stop the silent flattening. Without this, agents/commands symlinks degrade into regular
files on every load, even with the remove path fixed.

**SAFETY CONSTRAINT**: Lua source edits only. Do not invoke any loader operation against the real
`.claude/` tree.

**Tasks**:

- [ ] In `M.copy_simple_files` (`loader.lua:137-174`), before calling `copy_file`, check
      `vim.fn.getftype(target_path) == "link"`. If it is a symlink, skip the copy entirely and do
      NOT append `target_path` to `copied_files` — the copy engine does not own it.
- [ ] In `M.copy_skill_dirs` (`loader.lua:184-232`), check `vim.fn.getftype(target_skill_dir) ==
      "link"` before the per-file copy loop at `loader.lua:214-227`. If the deployed skill
      directory is a symlink, skip the whole skill and record nothing. Note why the existing guard
      is insufficient: `isdirectory(target_skill_dir) ~= 1` at `loader.lua:208` returns 1 for a
      symlink-to-directory, so it only guards directory *creation* — the copy loop always runs.
- [ ] Count symlink-skipped copies separately from `.syncprotect` skips (`skipped_count` currently
      means protected-skips only) so user-facing reporting can distinguish "protected" from
      "symlinked". State the choice in the LuaDoc.
- [ ] Add a LuaDoc note on both functions restating the ownership invariant, mirroring Phase 1's
      wording. No task-number citations.
- [ ] Update the load-side notification in `init.lua` to surface the symlink-skipped count.

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — `M.copy_simple_files`,
  `M.copy_skill_dirs`.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — notification counts only.

**Verification**:

- Extend the scratch script: call `M.copy_simple_files` against a fixture whose target is a
  file-level symlink; assert the symlink is still `getftype == "link"` afterward and that the
  source content is unchanged.
- Call `M.copy_skill_dirs` against a fixture whose deployed skill dir is a symlink; assert the
  symlink survives and that `copied_files` contains no path under it.
- Assert a non-symlinked target still copies normally and IS recorded in `copied_files`.

---

### Phase 5: Scratch integration test of the full unload/load cycle [NOT STARTED]

**Goal**: Prove the end-to-end reload path — the exact operation that caused the incident — is now
non-destructive and non-flattening, against real `manager.unload`/`manager.load` code.

**SAFETY CONSTRAINT**: This is the highest-risk phase because it runs the real
`manager.unload`/`manager.load`/`manager.reload` functions. Every call MUST pass
`opts.project_dir = <scratch>`. Both functions accept it (`init.lua:238,577`). Under no
circumstances call any manager function with a default `project_dir` — the default is
`vim.fn.getcwd()` (`init.lua:708`), which would be the real repository. Confirm the scratch
`project_dir` is threaded before the first call, not after.

**Tasks**:

- [ ] Build a complete scratch project tree: `<scratch>/.claude/extensions/fakeext/` with a
      `manifest.json` declaring one skill, one agent, and one command; matching source files; and
      a `<scratch>/.claude/extensions.json` state file marking `fakeext` loaded with the deployed
      paths recorded as relative paths (matching `state_mod.mark_loaded`'s format).
- [ ] Deploy the skill as a directory symlink and the agent/command as file symlinks, exactly as
      `install-extension.sh` would.
- [ ] Call `manager.reload("fakeext", { confirm = false, project_dir = <scratch> })`.
- [ ] **Assert no data loss**: every file under `<scratch>/.claude/extensions/fakeext/` is readable
      and byte-identical to its pre-reload content.
- [ ] **Assert no flattening**: `<scratch>/.claude/agents/fake-agent.md` and
      `<scratch>/.claude/commands/fake.md` are still `getftype == "link"` after the reload, and
      `<scratch>/.claude/skills/skill-fake` is still a symlinked directory. This assertion closes
      the third symptom and is the one that would fail under the rejected unlink-the-ancestor
      design.
- [ ] **Assert copy-mode still works**: build a second scratch fixture with no symlinks at all,
      reload it, and confirm files are copied and tracked normally — the fix must not break the
      ordinary deploy mode.
- [ ] Capture the full transcript into the phase notes.

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:

- Scratch fixtures only. No repository files change in this phase.

**Verification**:

- All assertions pass.
- `git status` on the real repository shows no unexpected changes — proof the scratch
  `project_dir` was honored and the real tree was never touched.

---

### Phase 6: Restore the flattened symlinks and record the decision [NOT STARTED]

**Goal**: Repair the two files already silently flattened from symlinks into regular files, and
write the ownership rule down where the next reader will find it. Sequenced last: restoring the
symlinks is only safe once the loader can no longer destroy or re-flatten them.

**SAFETY CONSTRAINT**: This phase touches the real `.claude/` tree, but only via `git` and `ln` —
it must NOT invoke any loader operation, picker action, reload, unload, or load against the real
tree. Restoring a symlink with git does not execute loader code; keep it that way.

**Tasks**:

- [ ] Confirm the current on-disk state: `.claude/agents/literature-agent.md` and
      `.claude/commands/literature.md` are regular files (mode 100644) while git HEAD records them
      as symlinks (mode 120000), shown as typechanges (`T`) in `git status`. Verify with
      `git ls-files -s` on both paths.
- [ ] For each of the two files, diff the current regular-file content against the extension source
      it should link to (`.claude/extensions/literature/agents/literature-agent.md` and
      `.claude/extensions/literature/commands/literature.md`). Resolve the intended target from git
      HEAD's recorded symlink content rather than assuming the path.
- [ ] **If byte-identical**: restore the symlink from HEAD with `git checkout HEAD -- <path>` and
      confirm `getftype` reports `link` afterward.
- [ ] **If they differ**: do NOT overwrite. The regular file may hold content the source lacks.
      Surface the diff and stop; report as a blocker for user decision rather than choosing.
- [ ] Verify both restored symlinks resolve to existing files (not dangling) and that `git status`
      no longer reports them as typechanges.
- [ ] Create `.claude/context/project/neovim/domain/extension-deploy-modes.md` documenting: that
      two deploy mechanisms write into the same target directories (the `install-extension.sh`
      symlink installer and the `loader.lua` copy engine driven by the picker); which categories
      use which pattern (skills = directory-level symlinks, agents/commands = file-level symlinks);
      the `vim.fn.delete()` semantics distinction verified empirically (final-component symlink =
      only the link is removed; plain file under a symlinked ancestor directory = the real target
      is destroyed; `delete(path, "rf")` on a symlink-to-directory = only the link is removed); the
      ownership rule with its justification; and the note that the loader cannot create symlinks,
      which is why it must not unlink them. No task-number citations anywhere in this file —
      reference `install-extension.sh` and the loader functions by name.
- [ ] Register the new context file in `.claude/context/index.json` with an appropriate `load_when`
      entry so it is discoverable, following the existing entry format.
- [ ] Re-read `loader.lua` and confirm the ownership-invariant LuaDoc added in Phases 1 and 4 is
      present, consistent between the copy and remove sides, and free of task-number citations.

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:

- `.claude/agents/literature-agent.md` — restore symlink (git checkout from HEAD).
- `.claude/commands/literature.md` — restore symlink (git checkout from HEAD).
- `.claude/context/project/neovim/domain/extension-deploy-modes.md` — new context document.
- `.claude/context/index.json` — register the new context entry.

**Verification**:

- `git ls-files -s` and `getftype` agree that both paths are symlinks again.
- `git status` shows no remaining typechange (`T`) entries for the two files.
- Both symlinks resolve to readable files.
- `grep -ri "task 862\|task N" .claude/context/project/neovim/domain/extension-deploy-modes.md
  lua/neotex/plugins/ai/shared/extensions/loader.lua` returns nothing.

---

## Testing & Validation

- [ ] Case A (the data-loss path): a plain file under a symlinked ancestor directory is NOT
      deleted, and the real extension source survives — the assertion this task exists for.
- [ ] Case A is proven to fail against pre-fix code, establishing the test's discriminating power.
- [ ] Case B: a file-level deployed symlink is skipped and left intact; its source is untouched.
- [ ] Regression: ordinary deployed regular files are still deleted and still counted in
      `removed_count`; unload has not become a silent no-op.
- [ ] `.syncprotect` entries are skipped on remove, using a key shape proven to match what
      `copy_file` receives.
- [ ] Copy path preserves pre-existing symlinks at target locations and does not record them as
      owned files.
- [ ] Full `manager.reload` against a scratch `project_dir` destroys nothing and flattens nothing.
- [ ] Non-symlinked extensions still load, unload, and reload normally.
- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.loader')" -c "q"` and
      the same for `.init` both exit clean.
- [ ] `git status` confirms the real `.claude/` tree was never modified by any test.
- [ ] No task-number citations outside `specs/**`.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/loader.lua` — symlink-aware `remove_installed_files`
  with bounded ancestor walk; symlink-preserving `copy_simple_files` and `copy_skill_dirs`;
  ownership-invariant LuaDoc.
- `lua/neotex/plugins/ai/shared/extensions/init.lua` — **outside declared file_scope**;
  `.syncprotect` filtering and `project_dir` threading at both `remove_installed_files` call sites;
  skip counts surfaced in notifications.
- `.claude/agents/literature-agent.md`, `.claude/commands/literature.md` — restored to symlinks.
- `.claude/context/project/neovim/domain/extension-deploy-modes.md` — new context document.
- `.claude/context/index.json` — new entry registered.
- Scratch test script and fixtures under
  `/tmp/claude-1000/-home-benjamin--config-nvim/86fe22e3-6df8-4d8d-bcaa-b7402fdaeefc/scratchpad/loader-symlink-test/`
  (ephemeral; not committed).
- `specs/862_fix_loader_symlink_delete_data_loss/summaries/01_loader-symlink-delete-data-loss-summary.md`

## Rollback/Contingency

- Each phase is a self-contained commit. Reverting any phase restores the prior behavior of the
  functions it touched; the phases are ordered so that reverting later phases never re-opens the
  data-loss path closed in Phase 1.
- Phase 6's symlink restoration is reversible with `git checkout HEAD -- <path>` in either
  direction; HEAD already holds the correct symlink form.
- If filtering at the `init.lua` call sites proves awkward (for example if a third caller of
  `remove_installed_files` appears), fall back to adding a `protected_paths` field to the existing
  `opts` table and performing the check inside `loader.lua`, deriving the key by stripping
  `project_dir .. "/" .. base_dir .. "/"`. This requires threading `base_dir` through `opts` and
  does not block Phases 4-6.
- If Phase 6's content diff shows the flattened files differ from their sources, stop and report as
  a blocker. Phases 1-5 stand alone and still fix the loader; the symlink restoration can be split
  into a follow-up task without weakening the fix.
- Contingency if a real reload is triggered by accident despite the constraints: the extension
  sources are tracked in git. Recover with `git checkout HEAD -- .claude/extensions/` and report
  the incident before continuing.
