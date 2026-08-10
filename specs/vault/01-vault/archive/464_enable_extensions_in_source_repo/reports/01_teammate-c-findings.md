# Task 464 - Teammate C: Critic Findings

**Role**: Critic - Identify gaps, shortcomings, and blind spots in the proposed approach.

---

## Key Findings

### 1. The Blocklist Is Filename-Based, Not Path-Aware

The `aggregate_extension_artifacts()` function in `manifest.lua` builds a flat set per category:
```lua
blocklist[category][filename] = true
```

When `scan_directory_for_sync()` applies the blocklist, it passes these filenames as
`exclude_patterns` and matches them against `rel_path` (the relative path from the category
subdirectory root). For single-level files like `agents/neovim-research-agent.md`, the
`rel_path` is just `neovim-research-agent.md` and exact match works. However, skill
directories are blocked at the directory level (e.g., `skill-neovim-research`), and
context entries use prefix matching (`project/neovim`). These are different matching
strategies layered on top of the same exclude_patterns array, so they work -- but only
if the manifest entries are correct and complete.

**Gap**: If a manifest declares `"provides": {"agents": ["neovim-research-agent.md"]}` but
the actual file lives in a subdirectory of `agents/` (e.g., `agents/neovim/neovim-research-agent.md`),
the `rel_path` would be `neovim/neovim-research-agent.md` and the blocklist entry
`neovim-research-agent.md` would NOT match it. The blocklist is path-blind for nested files.

### 2. The Blocklist Only Covers `provides` Categories, Not `merge_targets`

The blocklist is built exclusively from `manifest.provides`. The `merge_targets` section --
which is responsible for injecting content into `CLAUDE.md`, `index.json`, and `settings.json` --
is not represented in the blocklist at all. These merged artifacts are handled separately
by the section preservation + re-injection mechanism in `sync.lua`.

The critical question is: **does the re-injection mechanism correctly strip extension content
from CLAUDE.md before sync, or does it preserve it?** Looking at `sync_files()`:

```lua
if CONFIG_MARKDOWN_FILES[file.name] and file.action == "replace" then
  local local_content = helpers.read_file(file.local_path)
  if local_content then
    local sections = preserve_sections(local_content)
    content = restore_sections(content, sections)
  end
end
```

It PRESERVES sections from the local file (the source repo's CLAUDE.md) into the synced
content. This is the correct behavior for target repos (preserve loaded extension sections
across sync). But in the source repo (~/.config/nvim), if extensions are loaded, their
sections exist in `.claude/CLAUDE.md`. When that file is synced to target repos, it would
carry the extension sections with it -- because the sync reads from `global_path` (the source
repo), not from the target.

**This is the core gap**: The section preservation logic is designed for *target repo* syncs
(preserve local extension content when overwriting from global). It is not designed to strip
extension sections from the *global source* before distribution.

### 3. The `reinject_loaded_extensions()` Flow Creates a Timing Problem

The `reinject_loaded_extensions()` function reads loaded extensions from the *target project's*
`extensions.json`. When the source repo (`~/.config/nvim`) is the target of a sync (which
cannot happen since `load_all_globally()` has `project_dir == global_dir` guard), this is
moot. But when a target repo syncs from the source repo, `reinject_loaded_extensions()` runs
and re-injects merge targets for extensions loaded in the *target repo*. This is correct.

However, if the source repo has extensions loaded in its own `.claude/extensions.json`, and
those extension sections are in `.claude/CLAUDE.md` (the source), those sections will be
distributed to target repos as part of the global file content -- regardless of whether the
target has those extensions loaded.

### 4. The `update_artifact_from_global()` Path Has No Blocklist

The `M.update_artifact_from_global()` function (individual file update via Ctrl-l) does not
apply any blocklist. It directly copies a file from the global path to the local path. If an
extension artifact was installed into `.claude/agents/` in the source repo, a user could
manually sync it to a target repo via the individual file update mechanism, bypassing the
blocklist entirely.

This function does check `.syncprotect`, but not the manifest-based blocklist.

### 5. The `data` Provides Category Has No Blocklist Entry

`VALID_PROVIDES` in manifest.lua includes `"data"`, and the blocklist is initialized with:
```lua
blocklist = { agents={}, skills={}, commands={}, rules={}, context={}, scripts={}, hooks={}, data={} }
```

However, `scan_directory_for_sync()` in `sync.lua` is never called with `blocklist_category = "data"`.
Looking at the scan calls:

- commands: `"commands"`
- agents: `"agents"`
- skills: `"skills"`
- hooks: `"hooks"`
- scripts: `"scripts"`
- rules: `"rules"`
- context: `"context"`
- docs, templates, lib, tests, systemd, settings, root_files: no blocklist category

Data directories are loaded to the project root by `loader_mod.copy_data_dirs()` and are
not scanned by `scan_directory_for_sync()` at all. This is intentional -- data dirs (like
`.memory/`) go to project root, not `.claude/`. So the data blocklist gap exists but may
not matter in practice because data directories are not part of the sync path.

**However**: The `memory` extension's `data: [".memory"]` means that if memory is loaded in
the source repo, a `.memory/` directory exists at the source root. This directory is not
synced (it's not in the `scan_all_artifacts` paths), so this specific case appears safe.

### 6. The Docs, Lib, Tests, Templates, Systemd, Settings Categories Have No Blocklist

The `scan_all_artifacts()` function passes `blocklist_category` only for: commands, agents,
skills, hooks, scripts, rules, context. The following categories receive no blocklist filtering:

- `docs` (*.md files in `docs/`)
- `lib` (*.sh files in `lib/`)
- `tests` (test_*.sh in `tests/`)
- `templates` (*.yaml, *.json in `templates/`)
- `systemd` (*.service, *.timer)
- `settings` (settings.json)
- `root_files` (CLAUDE.md, .gitignore, README.md, settings.local.json)

This is acceptable for the current extensions because no manifest declares `provides` for
docs, lib, tests, templates, or systemd. But this is an unvalidated assumption -- future
extensions could be written that add files to these unprotected categories. The blocklist
infrastructure would not catch them.

### 7. `CLAUDE.md` in `root_files` Is Not Filtered

The `root_files` scan includes `.claude/CLAUDE.md` (the main config file). This file is
synced directly from global to target with section preservation. If extensions are loaded
in the source repo, their sections will be in this file. The section preservation logic
will carry these sections into target repos even if those targets have different extensions
loaded.

More precisely: `restore_sections()` only *adds* sections that don't already exist in the
new content. It does not *remove* sections from the source. So if the global CLAUDE.md
contains extension sections (because the source repo has extensions loaded), and the target
CLAUDE.md does not contain those sections, they will be appended to the target.

**This is the main leak vector if the self-loading guard is removed.**

### 8. The `settings.local.json` Root File Has No Blocklist

`settings.local.json` is included in `root_files` for `.claude` syncs. If any extension
modifies `settings.local.json` in the source repo (e.g., by adding MCP server configurations
via merge_settings targeting `settings.local.json`), those settings would be distributed
to all target repos. No blocklist applies to root_files.

### 9. Race Condition in Re-injection After Sync

The `reinject_loaded_extensions()` call happens after `execute_sync()`. Both operations read
and write the same files (CLAUDE.md, index.json). If a concurrent Neovim session modifies
these files between the two operations, the re-injection could operate on stale state. This
is a theoretical race since Neovim is typically single-session, but worth noting for robustness.

### 10. `.syncprotect` Interaction With Source Repo Extensions

The `.syncprotect` file in the source repo (`~/.config/nvim/.syncprotect`) currently lists:
```
context/repo/project-overview.md
output/implementation-001.md
```

When extensions are loaded in the source repo, their installed files (e.g.,
`.claude/agents/neovim-research-agent.md`) are NOT listed in `.syncprotect`. This means
during a sync FROM the source repo TO a target repo, those extension artifacts will pass
through the blocklist (which should catch them). But `.syncprotect` is a target-side
mechanism -- it protects files in the *target* repo from being overwritten. It does not
filter what is *read* from the source.

The blocklist and `.syncprotect` protect against different failure modes and work in
different directions. This layering is correct but the distinction is worth explicit
documentation.

### 11. The Self-Loading Guard Only Checks One Hardcoded Path

The current guard in `init.lua`:
```lua
local global_dir = vim.fn.expand("~/.config/nvim")
if project_dir == global_dir and not opts.force then
  return false, ...
end
```

This hardcodes `~/.config/nvim` as the source repo. If the `global_source_dir` config
option is set to a different path, the guard would still check `~/.config/nvim`. The guard
does not use `scan.get_global_dir()`. This inconsistency means the guard could be ineffective
if a user has configured a non-standard global source directory.

### 12. No Mechanism to Detect Extension-Contaminated Source Files

There is no validation that runs at sync time to detect if the source `.claude/CLAUDE.md`
contains extension sections before distributing it. The audit mechanism (`audit_synced_content`)
checks the *target* after sync using patterns from `.sync-exclude`. If those audit patterns
don't include extension section markers, the leak would be silent.

The `.sync-exclude` file would need to explicitly add audit patterns for extension section
markers (e.g., `<!-- SECTION: extension_nvim -->`) to catch this scenario.

---

## Gaps Identified

### Critical Gaps

1. **CLAUDE.md section leak**: Extension sections in source repo's CLAUDE.md will be
   distributed to target repos during sync. The section preservation logic preserves local
   sections but does not strip source sections. **No mechanism in the current design addresses
   this gap.**

2. **`update_artifact_from_global()` bypasses blocklist**: Individual file updates (Ctrl-l)
   copy files directly without blocklist filtering, allowing extension artifacts to leak if
   they exist in source repo artifact directories.

### Significant Gaps

3. **Docs/lib/tests/templates/systemd have no blocklist**: These categories are unprotected.
   Future extensions using these categories would leak without any warning.

4. **Guard uses hardcoded path**: The self-loading guard doesn't use the configured
   `global_source_dir`, creating an inconsistency that could silently allow loading if the
   source path is non-standard.

5. **No audit coverage for extension section markers**: The post-sync audit system won't
   detect extension sections in synced files unless audit patterns are explicitly configured.

### Design Assumptions Not Validated

6. **Blocklist assumes flat file structure within categories**: Files nested under
   `agents/subdir/file.md` would not be blocked by a blocklist entry of just `file.md`.

7. **Assumes all extension artifacts are declared in `provides`**: If an extension manually
   creates files (e.g., via a post-load hook) outside of `provides`, the blocklist won't
   cover them.

8. **Assumes `merge_targets` content removal from source CLAUDE.md**: The proposal
   says "sync-time content stripping for merged content" but no such stripping code exists
   in the current implementation. This would be new code -- and it's the most complex part.

---

## Unvalidated Assumptions

| Assumption | Risk | Validated? |
|------------|------|-----------|
| Blocklist covers all sync paths | High | No -- docs, lib, tests, templates have no blocklist |
| Extension sections won't appear in global CLAUDE.md | High | No -- if extensions loaded, they will |
| `update_artifact_from_global` is low-risk | Medium | No -- it bypasses blocklist |
| File nesting within categories is always flat | Medium | No -- nested agents/skills would bypass blocklist |
| All extension-installed files are declared in `provides` | Medium | Assumed but not enforced |
| The self-loading guard uses the configured source path | Low | No -- hardcoded to `~/.config/nvim` |
| Audit patterns will be configured to detect leaks | Low | No -- audit patterns must be manually added |

---

## Questions That Aren't Being Asked

1. **What happens to CLAUDE.md at sync time if extensions are loaded in source?**
   The proposal mentions "sync-time content stripping" but this mechanism does not exist.
   The current section preservation logic does the opposite of what's needed.

2. **How does the re-injection know not to re-inject on the source repo?**
   The `reinject_loaded_extensions()` call in `load_all_globally()` reads the *target*
   project's extensions.json. If the source repo somehow ran "Load Core" on itself (blocked
   by `project_dir == global_dir` guard), re-injection would run against the source's own
   extensions.json. But what happens in the proposed change where the guard is removed?

3. **Is the content stripping meant to be active (at sync time) or passive (before loading)?**
   The proposal is ambiguous. Stripping at sync time requires parsing the source CLAUDE.md
   and removing extension sections before writing to target. Stripping before loading means
   the user must unload extensions before syncing. Neither approach is currently implemented.

4. **What about the `.opencode/CLAUDE.md` equivalent?** The OpenCode system has parallel
   paths. Are extension sections in OpenCode config files also excluded from sync?

5. **What about extensions that register hooks?** The `provides.hooks` category is blocklisted,
   but hooks executed by the Claude Code harness (via `settings.json`) may have been registered
   via `merge_settings`. If settings.json in the source repo has extension-added hooks, those
   would be distributed as part of `settings.json` sync (which has no blocklist).

6. **What is the user experience when sync produces a contaminated CLAUDE.md in a target?**
   There is no warning or detection. The user in the target repo would see unexpected extension
   sections they never loaded, with no explanation.

---

## Confidence Level

- **Blocklist implementation analysis**: High -- code is clear and well-structured
- **CLAUDE.md section leak identification**: High -- traced through the exact code path
- **`update_artifact_from_global()` bypass**: High -- confirmed no blocklist call
- **Docs/lib/tests unprotected categories**: High -- confirmed by reading scan_all_artifacts
- **Content stripping mechanism gap**: High -- no such code exists in reviewed files
- **Race condition**: Low -- theoretical, Neovim is typically single-session
- **Data directory safety**: Medium -- data goes to project root, not sync paths
- **Future extension risks**: Medium -- based on what the manifest schema allows

---

## Summary Assessment

The core protection mechanism (manifest-based blocklist) is sound for discrete file types
(agents, skills, commands, rules, scripts, hooks). The critical gap is in **merged content**:
extension sections injected into CLAUDE.md, entries merged into index.json, and settings
merged into settings.json. These are not filtered by the blocklist. The proposed change
(removing the self-loading guard) would immediately expose the CLAUDE.md leak vector because
the section preservation code was designed to do the opposite -- preserve extension sections
across syncs, not strip them.

The proposal's reference to "sync-time content stripping" describes functionality that would
need to be implemented from scratch. It is not present in the current codebase.
