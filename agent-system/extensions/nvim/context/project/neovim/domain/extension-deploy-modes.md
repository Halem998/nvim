# Extension Deploy Modes

Two independent mechanisms deploy extension artifacts into the same target directories
(`.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/rules/`, and similar). Any
future change to either mechanism must preserve the ownership rule below, or the flattening and
data-loss symptoms documented here will recur.

## The two mechanisms

1. **Symlink installer** (`install-extension.sh` / `uninstall-extension.sh`). Creates real
   filesystem symlinks from `.claude/{skills,agents,commands}/{name}` to
   `.claude/extensions/{ext}/{skills,agents,commands}/{name}`. Symlink-aware on both install and
   uninstall: it checks whether a target is already a symlink, compares the existing link's
   target against the expected path, and warns rather than clobbering a non-symlink. This is the
   deploy mode used for local development, where edits to the deployed path should be edits to
   the tracked extension source with no copy step in between.

2. **Copy engine** (`loader.lua`, driven by `init.lua`'s `manager.load`/`unload`/`reload`,
   triggered from the extension picker UI). Copies file *contents* from extension source to
   deployed target on load, and removes deployed target paths on unload. This is the deploy mode
   used by the picker for one-shot install/update/removal of an extension without manual symlink
   management.

Both mechanisms write into the same directories, and an extension can move between the two modes
over its lifetime (loaded once via the copy engine, later converted to symlinks by the installer
for local development, or vice versa) without either mechanism being aware the other exists.

## Which categories use which pattern

| Category | Symlink granularity | Example |
|----------|---------------------|---------|
| Skills | Directory-level (`.claude/skills/{name}` is itself a symlink) | `.claude/skills/skill-literature -> ../../agent-system/extensions/literature/skills/skill-literature` |
| Agents | File-level (`.claude/agents/{name}.md` is itself a symlink) | `.claude/agents/literature-agent.md -> ../../agent-system/extensions/literature/agents/literature-agent.md` |
| Commands | File-level, same pattern as agents | `.claude/commands/literature.md -> ../../agent-system/extensions/literature/commands/literature.md` |

This distinction matters for the `vim.fn.delete()` semantics below: skills are destroyed via
*ancestor*-directory symlink resolution, while agents/commands are safe by construction because
the deployed path *itself* is the symlink.

## `vim.fn.delete()` semantics (verified empirically with headless nvim)

Only the final path component's own symlink-ness is consulted by `unlink()`; symlinked ancestor
directories are followed transparently during path resolution. Three distinct cases:

- **Final component is a symlink to a file** (the agents/commands pattern):
  `vim.fn.delete(path)` removes only the link. The real source file is completely untouched.
  Safe.
- **Final component is a symlink to a directory, deleted directly at that path**:
  `vim.fn.delete(path, "rf")` called on the symlink path itself removes only the link. The real
  directory and all its contents are fully preserved. Safe.
- **A plain file reached through a symlinked *ancestor* directory** (the skills pattern: the
  deployed skill directory is a symlink, and a file like `SKILL.md` inside it is an ordinary
  file, not itself a symlink): `vim.fn.delete()` on that file path deletes the real target file
  through the symlinked ancestor. This is the actual data-loss mechanism — the only one of the
  three that destroys data — and it is more specific than "the path is a symlink somewhere": it
  is specifically that an *ancestor directory* is a symlink and the file being iterated is not.

A per-file "is this path itself a symlink" check is therefore insufficient to prevent data loss;
detection must walk ancestor directories, not just the final path component.

## The ownership rule (durable — do not relitigate)

**The copy engine owns only paths it created as regular files. Symlinked deployed paths are
owned by `install-extension.sh` and are never written through, and never deleted, by
`loader.lua`.**

Concretely, in `lua/neotex/plugins/ai/shared/extensions/loader.lua`:

- `M.remove_installed_files` skips (does not delete) any path whose final component is a symlink,
  and any path reached through a symlinked ancestor directory (bounded by the caller-supplied
  `project_dir`), incrementing a `skipped_count` for reporting rather than deleting.
- `M.copy_category`, the single descriptor-driven copier every category flows through, checks for
  a pre-existing symlink at the deployed target *before* copying and skips the copy entirely (not
  recording the path as owned) when the target is already a symlink -- gated by each category
  descriptor's `symlink_guard` field in `CATEGORY_DESCRIPTORS`, `true` for exactly the categories
  the former per-category copier functions (`copy_simple_files` for agents/commands/rules,
  `copy_skill_dirs` for skills) used to guard individually.

### Why skip-and-warn rather than unlink-and-recreate

The loader cannot create symlinks: `loader.lua` and `init.lua` contain no `ln -s` /
`vim.uv.fs_symlink` call anywhere; `install-extension.sh` is the sole symlink-creating mechanism
in this repository. A design that unlinks a symlinked deployed path on unload (recreating
faithfully what `install-extension.sh` set up) is therefore unsound: on the next load, the copy
engine has no way to restore a symlink, so it fills the (now-empty) slot with a freshly copied
regular file, converting symlink deploy mode into copy deploy mode. Since `manager.reload` is
literally `unload()` then `load()`, an unlink-on-remove step actively defeats a
skip-on-copy guard on the very next call: by the time the copy half runs, there is no
pre-existing symlink left for the guard to detect, so it copies a plain file into the slot
regardless.

The accepted cost of skip-and-warn is that a genuine unload leaves symlinked artifacts in place
rather than fully removing them. This is mitigated by warning with a count and naming
`uninstall-extension.sh` as the correct tool for removing symlink-installed extensions.
Non-destructive and honest beats complete and lossy for a data-loss-prone code path.

## Relative-path fragility (regression precedent)

`install-extension.sh`'s symlink-creation sites hardcode the relative target as a literal string
(`rel_path="../../agent-system/extensions/$EXT_NAME/..."`), computed once and never re-derived
from the actual filesystem depth of the source-store root relative to `.claude/{agents,commands,
skills}/`. When the extension source store was relocated (from `.claude/extensions/$EXT_NAME/`
to `agent-system/extensions/$EXT_NAME/`, a different relative depth from `.claude/commands/`
etc.), every existing symlink created under the old hardcoded path silently went dangling —
`install_commands`/`install_skills` only *warn* when an existing symlink's target mismatches
what the (now-corrected) script would create, and `install_agents` does not validate an existing
agent symlink's target at all. Neither warns loudly enough to be noticed without an explicit
audit, and neither self-repairs: a broken symlink-deploy artifact requires an explicit
delete-then-recreate (delete the stale symlink, then re-run `install-extension.sh` for the owning
extension) — simply fixing the hardcoded path and re-running the installer over an
already-broken symlink is not sufficient, because the install functions treat "symlink already
exists" (even a dangling one) as "nothing to do." Any future relocation of the source-store root
must budget for this same repair sequence, or rederive the relative path dynamically (e.g. via
`os.path.relpath`-equivalent logic) instead of hardcoding it, to avoid recurrence.

## Consequence for future loader changes

Any new copy or removal path added to `loader.lua` (a new category descriptor in
`CATEGORY_DESCRIPTORS`, a change to `M.copy_category` itself, or a new caller of
`remove_installed_files`) must preserve the ownership rule: check `vim.fn.getftype()` on the
deployed target before writing or deleting through it, and skip when the target is a symlink not
owned by the copy engine. Treat this as a standing invariant, not a one-time fix.
