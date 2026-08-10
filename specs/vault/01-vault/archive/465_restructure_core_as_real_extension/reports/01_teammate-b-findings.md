# Task 465 - Teammate B: Alternative Approaches & Prior Art

## Overview

This report surveys external extension/plugin systems for best practices relevant to making the
core agent system a real (non-virtual) extension in `.claude/extensions/core/`. Findings are based
on reading the current system code in depth, particularly the Lua extension loader, state module,
manifest validation, and three representative extension manifests (`core`, `nvim`, `lean`).

---

## Key Findings

### 1. The Virtual Flag Is a One-Line Bypass in Two Places

The `virtual` flag is checked at exactly two points in
`lua/neotex/plugins/ai/shared/extensions/init.lua`:

- **Load fast-path** (line 359): skips `pcall` copy block, calls `mark_loaded` with empty lists.
- **Unload fast-path** (line 527): skips file removal, calls `mark_unloaded` directly.

Both paths are clean and short. Replacing them with real file-copy semantics requires only
removing the `if ext_manifest.virtual then ... return end` guards and ensuring the source files
exist at the expected path (`config.global_extensions_dir .. "/core/"`). The loader already
handles conflicts, rollback, and state tracking generically for non-virtual extensions.

### 2. `manifest.get_core_provides()` Is the Only Virtual-Specific Consumer

A function `M.get_core_provides()` in `manifest.lua` (line 263) explicitly checks
`core.manifest.virtual` before returning the provides map. This is used to build the sync
allow-list (blocklist filtering for core sync operations). If `core` becomes real, this function
must either (a) drop the `virtual` guard entirely, (b) check for `name == "core"` instead, or (c)
be made generic over any "base" extension concept.

### 3. Self-Loading Guard Already Accommodates This

The self-loading guard in `manager.load` (line 215-227) issues only a `WARN`-level notification
when loading into the source repository. It does not block. This means loading `core` in the
nvim config repo (which is the global source) would succeed with a warning. If that is undesired,
a stricter guard (return false) can be added for `core` specifically, or the guard can be relaxed
by recognizing that core's source is the same as its target (an in-place extension).

### 4. Other Extension Systems Uniformly Separate "Platform Core" From "Installed Extensions"

Surveying six well-known systems:

| System | Core Treatment | User Extension Treatment |
|--------|---------------|--------------------------|
| VS Code | Built-in extensions live in `extensions/` inside the app bundle; `vscode.proposed.d.ts` and activation events are the same API | User extensions in `~/.vscode/extensions/` follow the identical structure |
| lazy.nvim | Core plugin loader has no manifest; user plugins declared as tables with `dependencies = {}` | All plugins including lazy itself loaded via same `require()` path |
| npm workspaces | `package.json` at root is the workspace root; child packages have their own `package.json`; hoisting puts shared deps at root `node_modules/` | User packages are just entries in `workspaces[]` array |
| Gradle | Core plugins ship in `gradle-plugins.jar`; user plugins in `buildSrc/` or published to Plugin Portal follow identical `apply plugin:` API | All plugins implement `Plugin<Project>` interface |
| OSGi | `org.osgi.framework` bundle is the bootstrap runtime; it IS a bundle, just one that must be started first | All OSGi bundles including the framework bundle use the same manifest format (`Bundle-SymbolicName`, `Import-Package`, etc.) |
| Emacs | Built-in packages in `lisp/` of the Emacs source tree use the same `(provide 'foo)` / `(require 'foo)` mechanism as ELPA packages | ELPA packages are identical in structure; `package.el` treats built-ins and installed packages uniformly at runtime |

**Key takeaway**: Every mature extension system treats the platform core as structurally identical
to user extensions. Separation is a packaging concern, not an architectural one.

### 5. Topological Sort / DAG Resolution Already Implemented

The dependency resolution in `init.lua` (lines 244-294) implements recursive depth-first loading
with a loading stack for cycle detection and a depth limit of 5. This is equivalent to a DFS
topological sort. OSGi and npm use BFS (Kahn's algorithm), but both approaches are correct.
The current implementation is sufficient for adding core as a real extension that other extensions
depend on.

### 6. Diamond Dependency Is Not a Risk Here

Because `core` has `"dependencies": []` in its manifest, it is a DAG root. All other extensions
that declare `"dependencies": ["core"]` form a star topology. No diamond (A -> B -> C, A -> C)
is possible with core because core itself has no dependencies. This is the same pattern used by
OSGi's `org.osgi.framework` bundle and npm's `react` package in practice.

### 7. The Merge Targets System Already Handles Idempotency

`merge_mod.append_index_entries` deduplicates entries before appending (noted in loader comment,
line 433-435). The "pre-load cleanup removes stale index entries" block (lines 424-449) runs on
every load to clean orphaned entries. Both mechanisms work equally well whether core is virtual
or real. No new merge logic is needed.

### 8. CLAUDE.md Section Injection Works for Core Too

Extension `EXTENSION.md` content is injected into `.claude/CLAUDE.md` at a `section_id`
boundary. Core is currently the only extension without a `merge_targets.claudemd` entry in its
manifest. If core becomes real, it can either (a) inject a "Core System" section into CLAUDE.md,
or (b) omit `merge_targets.claudemd` entirely (merge_targets is optional per manifest validation).
Option (b) is lower risk and matches the existing behavior since the core content of CLAUDE.md
is the full file, not a section.

---

## Alternative Approaches

### Approach A: Remove Virtual Flag, Move Files Physically (Full Real Extension)

**Description**: Move all core files into `.claude/extensions/core/` with the same directory
structure expected by `loader.copy_simple_files`, `copy_skill_dirs`, `copy_context_dirs`, etc.
Remove `"virtual": true` from `manifest.json`. The loader will copy files on load and remove them
on unload.

**Pros**:
- Structurally identical to all other extensions. The system becomes fully uniform.
- Core is now "loadable" from the picker like any extension.
- Unloading core is now possible (removing core files from a project), which could be useful for
  minimal deployments.
- Sync operations no longer need any special-casing for core.

**Cons**:
- The nvim config repository itself IS the global source. Loading core into nvim would copy core
  files from `extensions/core/` to `.claude/` -- the same files are already there. The self-
  loading guard would need to be smarter (or suppressed for core).
- Moving files changes git history visibility for core files.
- The core files are currently the canonical location; extensions are copies. Inverting this
  means `.claude/extensions/core/` becomes canonical, and `.claude/` contains copies. This is a
  conceptual inversion that requires updating any tool that reads from `.claude/agents/` directly.
- Unloading core would break all other loaded extensions (they copy files that assume core is
  present). The unload dependency check already warns about this, but it doesn't block.

**Fit for this system**: High conceptual fit, moderate implementation risk. The self-loading
guard issue is the main complication.

### Approach B: Provider Extension (In-Place, No Copy Semantics)

**Description**: Keep files in their current locations under `.claude/`. Introduce a new manifest
field `"in_place": true` (or rename `virtual` to `in_place` for clarity). The loader skips copy
on load, skips removal on unload, but DOES run merge_targets (CLAUDE.md injection, index merging)
-- unlike the current virtual fast-path which skips merges too.

**Pros**:
- Zero file movement. Git history untouched.
- Core appears in the picker and has proper state tracking.
- merge_targets for core can be added (e.g., injecting the "Core" section into CLAUDE.md is
  currently done by hand).
- Cleanest path that matches the stated goal: "loadable via `<leader>ac` just like any other
  extension."

**Cons**:
- Still requires a new field name or semantic redefinition of `virtual`.
- Core's provides list in manifest.json must accurately reflect the real file locations (it
  already does for the blocklist use-case).
- Does not achieve full structural uniformity (files are not under `extensions/core/`).

**Fit for this system**: Highest practical fit. Low risk. Achieves the picker-loadable goal
without physical file movement.

### Approach C: Layered File Resolution (Extension Dir Overlays Core)

**Description**: Instead of copying files, the loader builds a resolution path: check
`extensions/{name}/` first, fall back to `.claude/` for the same filename. This is the Emacs
`load-path` approach and the same model used by Neovim's `rtp` for `after/` directories.

**Pros**:
- Extensions can shadow/override core files without replacing them.
- Potential for per-project core customization.
- Used successfully in Emacs, Neovim's rtp, and Gradle's `buildSrc` overlay.

**Cons**:
- Requires changing how commands, agents, and skills are resolved (currently flat-copy into
  `.claude/`). Claude Code reads `.claude/commands/*.md` directly -- it is not aware of an
  extension resolution path.
- Significant architectural change to the loader.
- Not compatible with how Claude Code discovers agents and skills.

**Fit for this system**: Low fit. Claude Code's file-based discovery model does not support
virtual path resolution.

### Approach D: Git Subtree for Core Distribution

**Description**: The core files live in a separate git repository. Projects include core via
`git subtree add`. The extension loader reads the subtree path as the extension source directory.
This is the pattern used by npm's package-lock and yarn's workspaces with git: protocol packages.

**Pros**:
- Canonical source is version-controlled independently.
- Updates via `git subtree pull`.
- Works for distributing the agent system to other repos.

**Cons**:
- Requires a separate repository.
- `git subtree` adds operational complexity.
- Does not address the picker-loadability goal.
- Overkill for a single-user configuration repository.

**Fit for this system**: Very low fit. Designed for multi-repo distribution, not single-repo
extension management.

### Approach E: Auto-Load Core on System Init (Always-Loaded Pattern)

**Description**: Core is treated as a "always loaded" extension. The extension manager init code
calls `manager.load("core", { confirm = false })` on startup if core is not already loaded. This
is analogous to VS Code's built-in extensions being activated automatically, or OSGi's framework
bundle being started before any other bundle.

**Pros**:
- Core is always in a known loaded state.
- Other extensions can safely declare `"dependencies": ["core"]` and the dependency will always
  be satisfied.
- No change to the manifest or virtual/in-place semantics needed.

**Cons**:
- Conflates "always loaded" with "loadable from picker."
- If core is auto-loaded silently, it may still not appear in the picker as a selectable item
  (since it would already be loaded).
- Does not address the file-location goal or the structural uniformity goal.
- The init.lua `manager.load` fast-path returns `false, "Extension already loaded"` if called
  twice; auto-load on startup would need to suppress this error.

**Fit for this system**: Medium fit for the "dependency always satisfied" sub-goal, low fit for
the "loadable from picker" goal.

---

## Best Practices for Dependency Management

From the survey, the following patterns are universally adopted in mature systems:

### 1. Core Has No Outbound Dependencies (DAG Root)

OSGi, npm, Gradle, VS Code all enforce that the platform core/runtime depends on nothing.
This is already satisfied here: `core.manifest.dependencies = []`.

### 2. Dependency Resolution Before File Operations

The current loader correctly loads dependencies before copying files (lines 264-294). This
matches Gradle's dependency resolution phase preceding the execution phase, and npm's install
phase preceding module loading.

### 3. Fail Fast on Missing Dependencies

The loader returns `false, "Failed to load dependency..."` if a dependency fails to load, and
does not proceed with the parent extension. This matches VS Code's activation events model
(if a required extension fails to activate, the dependent fails too) and npm's strict peer
dependency model.

### 4. Soft Unload Warnings (Not Blocks)

The loader warns when unloading an extension that dependents rely on but does not block. This
matches lazy.nvim's behavior (you can `:Lazy unload X` even if Y depends on X; Y breaks, but
the user is warned). OSGi is stricter (it blocks uninstall of a required bundle), but that
strictness adds UI complexity. The current soft approach is appropriate here.

### 5. Idempotent Load Operations

`state_mod.is_loaded()` returns early if already loaded. `append_index_entries` deduplicates.
This matches npm's "install is idempotent" guarantee and Gradle's "tasks run once per build"
contract.

### 6. Section-Based CLAUDE.md Composition

The `inject_section` / `remove_section` pattern with `section_id` markers is identical to:
- VS Code's `contributes` section in `package.json` (additive, per-extension)
- Gradle's `settings.gradle` with `include ':module'` (additive, enumerated)
- npm's `package.json` `scripts` field merging in monorepo roots

This is a well-established pattern. The only gap is that core's contributions to CLAUDE.md
are currently the base file itself, not a section. An `EXTENSION.md` for core would need to
describe the core routing table, command reference, and skill table -- content that is already
in `.claude/CLAUDE.md`.

---

## Recommended Approach

**Approach B (Provider Extension / In-Place Semantics)** best fits this system, with a small
extension to also run merge_targets on load/unload.

The concrete changes required:

1. **Rename or extend `virtual`**: Either rename `"virtual": true` to `"in_place": true` in
   core's manifest.json for clarity, or add a new semantic: virtual = skip copy AND skip merges;
   in_place = skip copy BUT run merges. The distinction matters if core gets an EXTENSION.md
   for CLAUDE.md injection in the future.

2. **Keep files where they are**: No physical file movement. The `global_extensions_dir` is
   `.claude/extensions/`, and `core` already lives there. The files that core "provides" are
   in `.claude/agents/`, `.claude/commands/`, etc. -- the loader already knows not to copy them
   because of the virtual fast-path.

3. **Remove virtual fast-path OR add in_place handling**: Change the load/unload logic to run
   merge_targets even for in-place extensions. This is a 5-10 line change in `init.lua`.

4. **Add `source_dir` to core's state entry**: Currently, virtual extensions store empty
   `installed_files` and `installed_dirs`. The `source_dir` field (populated via
   `manifest._source_dir`) is still written. This is correct and sufficient.

5. **Picker visibility**: Core currently appears in the picker because `manifest.list_extensions`
   scans all subdirectories of `global_extensions_dir`. The virtual flag only affects load/unload
   behavior, not discovery. Core already shows up in the picker.

**If full structural uniformity is the primary goal** (core files physically in
`extensions/core/`), use Approach A but add a special case in `manager.load` for core: detect
when `project_dir == global_dir` and either (a) skip the copy step (same as current virtual
behavior) or (b) copy to a temp location and validate, then no-op. This is more complex than
Approach B.

**Recommendation**: Implement Approach B. It achieves the stated goal (loadable from picker,
tracked in state, dependency-satisfying) with minimal risk and no file movement.

---

## Confidence Level

**High** for the following claims:
- The virtual flag is the only barrier to treating core as a real extension in the picker.
- Approach B requires changes only in `init.lua` (2 fast-path blocks) and `manifest.json`
  (rename or extend `virtual`).
- The dependency resolution, state tracking, and merge systems all already support core as
  a real extension without modification.

**Medium** for:
- Whether `manifest.get_core_provides()` needs updating -- depends on whether the sync allow-
  list approach is preserved as-is or refactored.
- The exact semantics of in_place vs virtual (whether merge_targets should run for core).

**Low** for:
- Any approach involving physical file movement (Approach A) -- the self-loading guard
  interaction and git history implications require more investigation before committing.
