# Research Report: Fix Loader Symlink Delete Data Loss

**Task**: Fix data loss in the extension loader — `remove_installed_files()` deletes through
symlinks, destroying tracked extension-source files.
**Started**: 2026-07-14
**Completed**: 2026-07-14
**Effort**: Research only (no implementation)
**Dependencies**: None
**Sources/Inputs**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`,
`lua/neotex/plugins/ai/shared/extensions/init.lua`,
`lua/neotex/plugins/ai/shared/extensions/state.lua`,
`.claude/scripts/install-extension.sh`, `.claude/scripts/uninstall-extension.sh`,
`.claude/extensions.json`, live filesystem inspection, headless-nvim scratch tests
**Artifacts**: this report
**Standards**: `.claude/rules/artifact-formats.md`

## Executive Summary

- **Root cause confirmed and precisely characterized, with two distinct failure mechanisms**
  depending on whether the *file itself* is a symlink (agents/commands) or an *ancestor
  directory* is a symlink (skills). Only the ancestor-directory case is destructive.
- `vim.fn.delete(path)` on a path whose **final component is a symlink** (agents/commands
  case) removes only the link — the real source file is completely untouched. This is safe.
- `vim.fn.delete(path)` on a path that is a **plain file reached through a symlinked ancestor
  directory** (skills case: `skill-literature` is a symlinked directory, `SKILL.md` inside it
  is a regular file) **deletes the real target file** — because path resolution follows
  directory-component symlinks transparently; only the final path component's own symlink-ness
  matters for `unlink()` semantics. This is the actual data-loss mechanism.
- `vim.fn.delete(symlink_to_dir_path, "rf")` called **directly on the symlink-to-directory
  path itself** (not on a file inside it) removes only the link — the real directory and all
  its contents are fully preserved. This is the safe primitive the fix should use for the
  skills case.
- A **second, independent, symlink-aware installer already exists**:
  `.claude/scripts/install-extension.sh` / `uninstall-extension.sh`. It creates the symlinks
  that `loader.lua` later destroys. Symlink deploy mode is a **supported, deliberate feature**,
  not an accidental artifact — the fix must make `loader.lua` interoperate with it, not refuse
  it.
- `protected_paths`/`.syncprotect` is honored by `copy_file()` but **never passed to
  `remove_installed_files()`** at either of its two call sites in `init.lua`. This is confirmed
  by direct reading of the function signature (`loader.lua:755`) and both callers
  (`init.lua:517`, `init.lua:669`).
- The currently-observed 10 symlinked skills, 7 symlinked agents, and 3 symlinked commands are
  enumerated below (task description's list is accurate but slightly stale — see Finding 2).

## Context & Scope

The extension system has two independent deploy mechanisms writing into the same target
directories (`.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`):

1. **Symlink installer** (`install-extension.sh` / `uninstall-extension.sh`, bash scripts):
   creates real symlinks from `.claude/{skills,agents,commands}/{name}` to
   `.claude/extensions/{ext}/{skills,agents,commands}/{name}`. Symlink-aware on both install
   and uninstall (checks `-L`, compares `readlink` target, warns and refuses rather than
   clobbering a non-symlink).
2. **Copy engine** (`loader.lua`, driven by `init.lua`'s `manager.load`/`unload`/`reload`,
   triggered from the extension picker UI): copies file *contents* from extension source to
   deployed target on load, and deletes deployed target paths on unload. It has **no symlink
   awareness anywhere** — not in `copy_file()`, not in `remove_installed_files()`.

When an extension that was installed via mechanism 1 (symlinks present) is later reloaded via
mechanism 2 (the picker's reload action, which calls `manager.unload` then `manager.load`),
`remove_installed_files()` deletes through the symlink structure and destroys the real
extension-source files. This is exactly what happened to
`.claude/extensions/literature/skills/skill-literature/SKILL.md`.

## Findings

### Finding 1: Complete install/unload lifecycle map (loader.lua + init.lua)

**`loader.lua`** (`M.remove_installed_files` at `loader.lua:755-785`):
```lua
function M.remove_installed_files(installed_files, installed_dirs)
  local removed_count = 0
  for _, filepath in ipairs(installed_files) do
    if vim.fn.filereadable(filepath) == 1 then
      vim.fn.delete(filepath)              -- loader.lua:761, unconditional, no symlink check
      removed_count = removed_count + 1
    end
  end
  -- directories removed only if empty, deepest-first (loader.lua:766-782)
  ...
end
```
No `protected_paths` parameter exists on this function at all (contrast with every `copy_*`
function, all of which accept `protected_paths` — `loader.lua:54, 137, 184, 242, 308, 352,
397, 441, 506, 551`).

`copy_file()` (`loader.lua:54-82`) is the single place `.syncprotect` is honored:
```lua
local function copy_file(source_path, target_path, preserve_perms, protected_paths, rel_path)
  if protected_paths and rel_path and protected_paths[rel_path] then
    return false, true   -- skip: (success=false, skipped=true)
  end
  ...
  local content = helpers.read_file(source_path)
  local success = helpers.write_file(target_path, content)
  ...
end
```
`helpers.write_file` (`lua/neotex/plugins/ai/claude/commands/picker/utils/helpers.lua:70-73`)
is `pcall(vim.fn.writefile, lines, filepath)` — this follows symlinks transparently (verified
empirically, Finding 3): writing to a deployed path that resolves through a symlinked ancestor
writes through to the real extension-source file. On *load*, when the deployed skill directory
is already a symlink to that same extension's own source, this is a harmless self-write
(content read from source, written back to source via the deployed alias) — wasteful but not
destructive, *provided* the symlink actually points at the same extension's source (see Risk
in Finding 5).

`copy_skill_dirs()` (`loader.lua:184-232`) is unconditional about copying individual files
even when the target skill directory already exists (as a symlink or otherwise): the
`isdirectory(target_skill_dir) ~= 1` check (`loader.lua:208`) only guards *directory creation*,
not the subsequent per-file copy loop (`loader.lua:214-227`), which always runs and always
records each `target_path` into `copied_files` regardless of whether the parent was
pre-existing (symlinked or not).

**`init.lua`**:
- `manager.load()` (`init.lua:235`) calls `loader_mod.copy_simple_files` /
  `copy_skill_dirs` / etc. (`init.lua:404-467`), accumulating `all_files`/`all_dirs`, then
  writes them to state via `state_mod.mark_loaded()` (`init.lua:531`) as **relative deployed
  paths** (not source paths) — confirmed by reading `.claude/extensions.json`
  (`.extensions.literature.installed_files`), which lists deployed paths like
  `.claude/agents/literature-agent.md`, `.claude/scripts/literature-briefing.sh`, etc.
- `manager.unload()` (`init.lua:574-699`) reads back `installed_files`/`installed_dirs` from
  state (`init.lua:586-587`), converts to absolute paths (`init.lua:652-663`), and calls
  `loader_mod.remove_installed_files(abs_files, abs_dirs)` (`init.lua:669`) — **no
  `protected_paths` argument passed**, and none is even loaded/available in this function's
  scope.
- Rollback-on-failure inside `manager.load()` (`init.lua:516-519`) calls the same
  `remove_installed_files(all_files, all_dirs)` with the same missing-`protected_paths` gap.
- `manager.reload()` (`init.lua:706+`) is literally `unload()` then `load()` — confirmed by
  reading `init.lua:706-719`.
- UI trigger: `lua/neotex/plugins/ai/shared/extensions/picker.lua:185` (unload) and `:213`
  (reload); also `lua/neotex/plugins/ai/claude/commands/picker/init.lua:206,314,316`. These are
  the picker actions a user invokes (e.g. reload-extension keymap) that produced the observed
  incident.

### Finding 2: Current symlink inventory (verified live, read-only)

Enumerated via `find -type l`, `readlink`, `readlink -f`, `stat`:

**Skills** (`.claude/skills/`, 10 symlinks, all directory-level):
`skill-cslib-research`, `skill-pr-review-implementation`, `skill-zotero`,
`skill-pr-review-research`, `skill-literature`, `skill-cslib-implementation`, `skill-cslib-vet`,
`skill-cslib-implementation-hard`, `skill-pr-implementation`, `skill-cslib-research-hard`.
This matches the task description's "nine other" (all `cslib`/`pr`/`zotero` skills) plus
`skill-literature` itself (already recovered) = 10. **Not stale.**

**Agents** (`.claude/agents/`, 7 symlinks, file-level):
`cslib-vet-agent.md`, `cslib-research-agent.md`, `cslib-implementation-agent.md`,
`cslib-implementation-hard-agent.md`, `pr-review-implementation-agent.md`,
`cslib-research-hard-agent.md`, `pr-review-research-agent.md`.
**`literature-agent.md` is NOT currently a symlink** — it is a regular file
(mode 100644 on disk vs. mode 120000 = symlink in git HEAD, per `git ls-files -s`, and shows as
typechange `T` in git status). This is live, on-disk confirmation of the THIRD SYMPTOM already
having occurred for this file.

**Commands** (`.claude/commands/`, 3 symlinks, file-level): `vet.md`, `zotero.md`, `pr.md`.
**`literature.md` is NOT currently a symlink** (same flattening, same git-status typechange
confirmation).

**Rules** (`.claude/rules/`): zero symlinks currently.

**Stale/dangling symlinks found** (informational, not part of the data-loss mechanism):
`skill-zotero` and `zotero.md` point at `.claude/extensions/zotero/...`, but the `zotero`
extension directory no longer exists on disk (`.claude/extensions/` has no `zotero/` entry —
its functionality was absorbed into the `literature` extension per
`CLAUDE.md`: "Absorbs the former zotero extension"). These are broken symlinks left over from
that merge. Deleting a dangling symlink via `vim.fn.delete()` is inherently safe (there is no
real target to destroy), but they should be cleaned up or re-pointed as a housekeeping item —
out of scope for this fix but worth flagging.

**Origin of the symlinks** (Requirement 4): confirmed via `grep -rn "symlink" lua/... .claude/scripts/*.sh` — the only symlink-*creating* code in the repository is
`install-extension.sh:install_commands/install_skills/install_agents` (`ln -s
"../extensions/$EXT_NAME/..." "$target"`, lines 104/140/169). `loader.lua` and `init.lua`
contain no `ln -s` / `vim.uv.fs_symlink` call anywhere — the copy engine never creates
symlinks, it only (mis)handles ones that already exist. `scan.lua:52-97` even has a
`skip_symlinks` defense-in-depth parameter for a *different* sync path (the picker's
`scan_directory_for_sync`), confirming the project's engineers were aware symlinks could appear
in these trees and defended against them elsewhere — just not in `loader.lua`'s
`remove_installed_files()`.

### Finding 3: `vim.fn.delete()` symlink semantics — verified with real headless-nvim tests

All three cases were constructed and executed in the scratchpad
(`/tmp/.../scratchpad/symlink-test/`), never touching the real `.claude/` tree. Full transcript:

**Case A — file reached via a symlinked *ancestor* directory** (models the skills scenario:
`deployed_skill_dir` is a symlink to `real_skill_dir`; `SKILL.md` inside it is a *plain file*,
not itself a symlink):
```
filereadable before: 1
delete() return code: 0
deployed path exists after: 0
REAL SOURCE FILE exists after: 0        <-- DESTROYED
```
`vim.fn.delete()` unlinks the real target file. This is standard POSIX `unlink()` behavior:
only the final path component's own symlink-ness is consulted; ancestor-directory symlinks are
always transparently followed during path resolution. **This is the actual data-loss
mechanism**, and it is more specific than the task description's phrasing ("deployed path
resolves through the symlink") — it is not that any file is a symlink, it is that the
**directory** is a symlink and the files under it are ordinary files reached through it.

**Case B — the deployed path itself is a symlink to a file** (models the agents/commands
scenario: `deployed_agent.md -> real_agent.md`):
```
getftype before: link
delete() return code: 0
deployed_agent.md exists after: 0
REAL SOURCE FILE real_agent.md exists after: 1     <-- SAFE
real_agent.md content: ORIGINAL AGENT CONTENT - DO NOT LOSE
```
`vim.fn.delete()` on a symlink-to-file removes only the link. The real file is completely
untouched. **This confirms the agents/commands delete step is not the destructive step.**

**Case C — `vim.fn.delete(path, "rf")` called directly on a symlink-to-*directory* path**
(not on a file inside it — the symlink path itself as the delete target):
```
getftype before: link
delete(rf) return code: 0
deployed_dir_c exists after (isdirectory): 0
deployed_dir_c exists after (getftype): <empty, i.e. gone>
REAL SOURCE DIR real_dir_c exists after: 1          <-- SAFE
REAL SOURCE FILE real_dir_c/f.txt exists after: 1   <-- SAFE
```
Critically, `"rf"` recursive-force delete on a symlink-to-directory does **not** follow the
link and recurse into the target — it removes only the link itself, atomically, leaving the
real directory tree fully intact. **This is the safe primitive the fix should use for the
skills case**: instead of deleting individual files under a symlinked skill directory
(Case A, destructive), delete the symlinked directory path itself with `"rf"` (Case C, safe).

**Supplementary check — `vim.fn.resolve()` as a discriminator**:
```
resolve(symlinked_file):        .../real_skill_dir/SKILL.md   (differs from input)
resolve(plain_file):            .../plain_dir/plain.txt        (identical to input)
getftype(deployed_skill_dir):        link   (ancestor dir)
getftype(deployed_skill_dir/SKILL.md): file  (the file itself is NOT a link)
```
`vim.fn.resolve(path) ~= path` reliably detects "a symlink is involved somewhere in this path"
(either the final component or an ancestor), but does **not** by itself distinguish Case A from
Case B — that distinction requires checking `vim.fn.getftype(path)` on the *final component*
first: `"link"` → Case B (safe to delete directly); not `"link"` but `resolve() ~= path` →
Case A (must not delete the file directly; must locate and unlink the symlinked ancestor
instead).

**Supplementary check — `vim.fn.writefile()` through a symlinked ancestor** (LOAD-side
behavior, for completeness): writing to a path reached through a symlinked ancestor directory
writes through to the real file — confirmed (`writefile pcall ok: true`, content identical at
both the deployed and real paths afterward, and the ancestor symlink itself remains a symlink,
unaffected by the write). This confirms the *load* side is non-destructive for the
same-extension case (self-overwrite with identical content) but flags a related risk: if a
deployed symlink ever pointed at a *different* extension's source (stale/mismatched symlink),
`copy_file()` would silently corrupt that other extension's source file with this extension's
content — `loader.lua` has no equivalent of `install-extension.sh`'s target-mismatch guard
(`install-extension.sh:90-98`, which compares `readlink` output against the expected path and
warns rather than overwriting).

### Finding 4: Why the third symptom happens (symlink flattening on agents/commands)

Given Case B (delete only removes the link, source is safe), the flattening of
`literature-agent.md` and `literature.md` from symlinks (mode 120000 in git HEAD) into regular
files (mode 100644 on disk now) is explained fully by the *load* side, not the *remove* side:

1. `remove_installed_files()` deletes `.claude/agents/literature-agent.md`, which is a
   symlink → Case B → only the link is removed, `real_agent.md`-equivalent source content is
   safe.
2. The deployed path `.claude/agents/literature-agent.md` no longer exists at all (link gone).
3. The subsequent `manager.load()` copy step calls `copy_file()`, which does not check whether
   a target *used to be* a symlink — it simply `read_file(source)` + `write_file(target)`. Since
   the target path is now absent, `vim.fn.writefile()` creates a **brand-new regular file**
   there, with correct content but the wrong (non-symlink) structure.

This means content loss did not occur for agents/commands, but the "symlink deploy mode" is
**not currently preserved across an unload+load cycle even once the destructive skills bug is
fixed** — a naive fix that just guards the *delete* step still leaves agents/commands silently
flattened on every reload, because the *copy* step has no symlink-preservation logic either.
The task description's "if supported, both copy and remove must handle it" applies concretely
here.

### Finding 5: Candidate fixes evaluated

**(a) Skip symlinked deployed paths entirely on remove.** Simple, but leaves the deployed
symlink standing after "unload," which is semantically wrong (the extension claims to be
unloaded but its files remain fully present and discoverable) and does nothing for the
copy-side flattening (Finding 4) — a subsequent `load()` still self-overwrites through the
symlink for skills, and for agents/commands the symlink survives unload only, then a normal
reload's load-half would try `copy_file()` against a target that's still a live symlink (which
is actually fine/idempotent in that specific sub-case, since it's a safe self-write, but it
means "unload" didn't actually undo anything for that file).

**(b) Unlink the symlink itself rather than its target.** This is the empirically-correct
primitive (Cases B and C above both prove it's safe), but it must be applied at the *right
granularity*: for agents/commands, apply it to the file path directly (already implicitly what
happens today per Case B — no change needed there beyond not regressing it). For skills, it
must be applied to the **symlinked ancestor directory**, not to individual files within it —
because the individual files are not themselves symlinks (Case A vs Case C distinction). This
requires the removal path to detect, for each tracked file, whether it descends from a
symlinked directory and, if so, delete that directory once (via `"rf"` on the symlink path,
Case C) instead of iterating into its contents.

**(c) Refuse to install over a symlink.** Contradicted by evidence: `install-extension.sh` is
a first-class, actively-used, symlink-*creating* mechanism (10 skills + 7 agents + 3 commands
currently deployed this way), so "refuse" would break the existing supported configuration for
every user who installed extensions that way — including the very `literature`, `cslib`, and
`pr` extensions currently in use. This is not a good option given the evidence.

**Recommendation: (b), applied at the correct granularity, combined with fixing the copy side
to also be symlink-preserving.** Concretely:

- In `remove_installed_files()`, for each `filepath` in `installed_files`: if
  `vim.fn.getftype(filepath) == "link"`, delete it directly (current behavior — already safe,
  Case B, no change in outcome needed). Otherwise, walk up from `filepath` toward the
  configured base (e.g. `.claude/skills/`) checking `vim.fn.getftype()` on each ancestor
  directory component; if an ancestor is found to be a `"link"`, do **not** delete the
  individual file — instead, unlink that ancestor symlink once (`vim.fn.delete(ancestor,
  "rf")`, Case C) and record it so it is not attempted a second time for sibling files under
  the same symlinked directory. If no ancestor is a symlink, fall through to the current plain
  `vim.fn.delete(filepath)`.
- Symmetrically, on the *load*/copy side (`copy_skill_dirs`, and by extension
  `copy_simple_files` for agents/commands), detect a pre-existing symlink at the target
  location **before** copying into it and skip the copy entirely for that target (preserving
  the symlink as-is, avoiding the pointless self-write and, more importantly, avoiding ever
  creating a plain file in that slot on a subsequent load after an unload has correctly
  unlinked it) — this is what prevents Finding 4's flattening from recurring even after the
  remove-side fix. This also naturally suggests introducing a distinct tracked category (e.g.
  `installed_symlinks`, parallel to `installed_files`/`installed_dirs` in
  `state.lua`/`init.lua`) so unload has an explicit, directly-usable list of symlink paths to
  unlink, rather than needing to re-derive "which ancestor is a symlink" from a flat file list
  at unload time. This is a larger, optional refactor beyond the minimal fix; the ancestor-walk
  approach above works correctly without it and is the smaller, more contained change.
- Document explicitly (in a code comment and/or in extension-development docs) that symlink
  deploy mode (via `install-extension.sh`) is supported and that `loader.lua`'s copy/remove
  paths must remain symlink-safe as a standing invariant — this closes the "decide and
  document" requirement.

### Finding 6: `.syncprotect` symmetry contract

`copy_file()`'s contract (`loader.lua:54-58`): given `protected_paths` (a set keyed by
`rel_path`, loaded once per operation via `M.load_syncprotect` from `.syncprotect` at the
project root) and a `rel_path` for the specific file being copied, if `protected_paths[rel_path]`
is truthy, the copy is skipped and `(false, true)` is returned (`ok=false, skipped=true`) —
callers use the second return to increment a `skipped_count` for user-facing reporting
(`loader.lua:164-169` and all other `copy_*` callers follow this pattern identically).

For symmetry, `remove_installed_files()` needs the same two inputs it currently lacks:
`protected_paths` (the loaded set) and, for each `installed_files`/`installed_dirs` entry, its
`rel_path` relative to the project root (`installed_files`/`installed_dirs` are already stored
as **relative** paths in state — `state_mod.mark_loaded` stores `rel_files`/`rel_dirs`
converted via `paths_to_relative()`, `init.lua:528-531` — but by the time `manager.unload()`
converts them back to absolute paths for the delete call, `init.lua:652-663`, the relative form
is discarded). The fix should either: (i) pass `protected_paths` into
`remove_installed_files()` and have it re-derive each `rel_path` from the project root before
checking protection (mirroring `copy_file`'s check), or (ii) do the protection filtering in
`init.lua` before converting to absolute paths (skip appending a path to `abs_files`/`abs_dirs`
in the first place if it's in `protected_paths`), which is simpler and avoids changing
`remove_installed_files()`'s path-handling logic at all — only its call sites and signature
(adding an optional `protected_paths` parameter, threaded through both call sites at
`init.lua:517` and `init.lua:669`) need to change. Either approach must load `.syncprotect` via
the same `M.load_syncprotect(project_dir, config.base_dir)` call already used at
`init.lua:389` for the load path — `manager.unload()` currently never calls this at all.

### Finding 7: Safe verification procedure

A safe headless-nvim test can validate the fix without touching the real `.claude/` tree,
following the exact pattern used during this research (scratchpad only):

1. Build a scratch fixture mirroring the real structure minimally:
   `scratch/extensions/fakeext/skills/skill-fake/SKILL.md` (real file, extension source) and
   `scratch/skills/skill-fake` → symlink to
   `scratch/extensions/fakeext/skills/skill-fake` (mirrors `install-extension.sh`'s output).
2. Populate a minimal in-memory (or scratch-file) `installed_files` array with the deployed
   path `scratch/skills/skill-fake/SKILL.md` (mirroring what `copy_skill_dirs` would have
   recorded) and call the **patched** `M.remove_installed_files` directly (as a pure function
   — it takes plain path arrays, no global state, so it can be unit-tested in isolation without
   invoking `manager.unload` or touching `.claude/extensions.json` at all).
3. Assert: `vim.fn.filereadable(scratch/extensions/fakeext/skills/skill-fake/SKILL.md) == 1`
   (source survives) and the deployed path no longer resolves
   (`vim.fn.isdirectory(scratch/skills/skill-fake) == 0` or, if a symlink was left dangling
   intentionally as an intermediate state, assert on the fix's specific documented contract).
4. Repeat for the agents/commands (file-level symlink) case and for a plain, non-symlinked
   file case (regression check: ordinary deployed files must still be deleted normally).
5. Never invoke `manager.unload`/`reload`/`load` against `project_dir = <real repo>` during
   this test — always pass a scratch `project_dir` (both `manager.unload` and
   `manager.load` accept `opts.project_dir`, `init.lua:238,577`, so the real functions can be
   exercised end-to-end against a fully scratch project tree if a higher-fidelity integration
   test is desired, without any risk to the real `.claude/` tree).

This procedure needs no destructive operation against real files at any point and directly
exercises the exact code paths (`remove_installed_files`, `copy_skill_dirs`) implicated in the
incident.

## Decisions

- Root cause is the **ancestor-directory-symlink** case specifically (Case A), not a generic
  "symlink" case — the fix logic must distinguish "final component is a symlink" (safe,
  Case B) from "an ancestor directory is a symlink" (destructive today, must be fixed via
  Case C's directory-level unlink).
- Symlink deploy mode is **supported** (an entire parallel installer exists for it) — the
  recommended fix direction is (b) from Finding 5, not (c) (refuse).
- `.syncprotect` threading should reuse the existing `M.load_syncprotect` loader and either
  filter at the `init.lua` call sites before building `abs_files`/`abs_dirs`, or add an
  optional `protected_paths` parameter to `remove_installed_files()` itself — both are viable;
  filtering at the call site is the smaller change.

## Risks & Mitigations

- **Risk**: A deployed symlink could point at a *different* extension's source than the one
  currently being loaded/unloaded (stale or manually mis-created symlink). `copy_file()`'s
  self-write (Finding 3) would silently overwrite that unrelated file. **Mitigation**: the fix
  could optionally add an `install-extension.sh`-style target-mismatch check (compare
  `vim.fn.resolve(target)` against the expected source path for the extension currently being
  processed) before writing through any symlinked target, logging a warning and skipping
  instead of silently writing through, mirroring `install-extension.sh:90-98`'s existing
  pattern. This is not required to fix the reported data-loss bug (which is specifically about
  *delete*, not *write*) but closes a related latent risk surfaced during this research.
- **Risk**: The two dangling `zotero`-related symlinks (`skill-zotero`, `zotero.md`) will error
  or behave oddly if any code path calls `vim.fn.getftype()`/`resolve()` on them expecting a
  live target. Verified these are safe to `vim.fn.delete()` (no target to destroy). Not part of
  this fix's required scope but flagged for cleanup.
- **Risk**: Fixing only `remove_installed_files()` without also fixing the copy side leaves
  Finding 4's flattening bug live — agents/commands symlinks will still degrade to plain files
  on every load that follows a (now-safe) unload. The task description explicitly requires
  deciding whether copy must also handle symlinks; the recommendation above says yes.

## Context Extension Recommendations

- **Topic**: Dual extension-deploy-mechanism architecture (symlink installer vs. copy loader)
  and the symlink-safety invariant it imposes on `loader.lua`.
- **Gap**: `.claude/context/project/neovim/domain/*` has no coverage of the
  `install-extension.sh`/`uninstall-extension.sh` symlink mechanism or its interaction with the
  `lua/neotex/plugins/ai/shared/extensions/` copy engine used by the picker UI.
- **Recommendation**: after the fix lands, add a short domain note (e.g.
  `.claude/context/project/neovim/domain/extension-deploy-modes.md`) documenting that both
  mechanisms exist, which categories (skills = directory-level symlinks, agents/commands =
  file-level symlinks) use which pattern, and the `vim.fn.delete()` semantics distinction
  (final-component symlink = safe; ancestor-directory symlink = must unlink the ancestor, never
  the individual file) verified in this report, so future loader changes don't regress it.

## Appendix

### Search queries / commands used

- `find .claude/{skills,agents,commands,rules} -maxdepth 1 -type l -exec readlink -f {} \;`
- `git ls-files -s .claude/agents/literature-agent.md .claude/commands/literature.md
  .claude/skills/skill-literature` (mode 120000 = symlink in HEAD, confirms typechange)
- `grep -rn "symlink\|fs_symlink\|ln -s" lua/neotex/plugins/ai/` (found no symlink creation in
  Lua code; found `scan.lua`'s unrelated `skip_symlinks` defense-in-depth parameter)
- `grep -rln "symlink" .claude/scripts/*.sh` → `install-extension.sh`, `uninstall-extension.sh`
- `grep -rn "remove_installed_files\|copy_skill_dirs\|copy_simple_files"
  lua/neotex/plugins/ai/` (found both call sites in `init.lua`, confirmed no other callers)
- `jq -r '.extensions.literature.installed_files[]?' .claude/extensions.json` (inspected actual
  tracked deployed paths for the live literature extension)
- Headless nvim scratch tests (`nvim --headless -u NONE -c "luafile ..."`) executed entirely
  under `/tmp/claude-1000/.../scratchpad/symlink-test/` — no real files touched. Full transcript
  reproduced in Finding 3.

### File/line references

- `lua/neotex/plugins/ai/shared/extensions/loader.lua:751-785` — `M.remove_installed_files`
  (the buggy function)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua:54-82` — `copy_file` (the
  `.syncprotect`-honoring pattern to mirror)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua:184-232` — `copy_skill_dirs`
- `lua/neotex/plugins/ai/shared/extensions/init.lua:516-519` — rollback call site (no
  `protected_paths`)
- `lua/neotex/plugins/ai/shared/extensions/init.lua:574-699` — `manager.unload`, primary call
  site (`init.lua:669`, no `protected_paths`)
- `lua/neotex/plugins/ai/shared/extensions/init.lua:706-719` — `manager.reload`
- `.claude/scripts/install-extension.sh:75-174` — symlink creation (`install_commands`,
  `install_skills`, `install_agents`)
- `.claude/scripts/uninstall-extension.sh:74-171` — symlink-safe removal pattern already in use
  by the parallel installer (a useful reference implementation for the ancestor-walk logic)
