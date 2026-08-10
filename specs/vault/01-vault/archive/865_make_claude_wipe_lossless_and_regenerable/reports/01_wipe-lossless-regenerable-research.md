# Research Report: Task #865

**Task**: 865 - Make .claude/ wipe lossless and one-keystroke regenerable
**Started**: 2026-07-14T23:00:00Z
**Completed**: 2026-07-14T23:40:00Z
**Effort**: Medium (3 independent sub-fixes of differing difficulty; one requires a scope
correction against an external hard constraint)
**Dependencies**: Task that relocated the global extension source store to
`agent-system/extensions/` (already landed; this task builds directly on that deploy/target
model)
**Sources/Inputs**: `lua/neotex/plugins/ai/shared/extensions/{state,init,config,loader}.lua`,
`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`,
`agent-system/extensions/core/{manifest.json,root-files/,hooks/,scripts/}`, live
`.claude/settings.json` / `.claude/settings.local.json` diffs, Claude Code settings
documentation (web)
**Artifacts**: this report
**Standards**: report-format.md, no-task-references-in-deliverables.md

## Executive Summary

- **extensions.json** (the selection manifest) can be cleanly relocated to project root. The
  candidate name `.agent-extensions.json` needs one correction: `state.lua`/`config.lua` are
  shared between the Claude and OpenCode presets, so a single shared root filename would let one
  system's manifest clobber the other's if both are ever deployed into the same project.
  Recommend a config-scoped filename per preset (e.g. `.claude-extensions.json` /
  `.opencode-extensions.json`) via one new `config.lua` field, changed at a single choke point
  (`state.lua:71`, `get_state_path`).
- **settings.json / settings.local.json cannot literally move out of `.claude/`.** This is the
  headline finding: Claude Code (the host application) hardcodes `.claude/settings.json` and
  `.claude/settings.local.json` as the only paths it reads for project-level settings — this is
  not a convention our deploy system controls, unlike `extensions.json`. Requirement (2) as
  literally stated is infeasible for these two files without breaking Claude Code's own settings
  resolution. The real, addressable problem underneath the task's framing is different and more
  interesting: `loader.lua`'s `copy_root_files` unconditionally **overwrites** `.claude/settings.json`
  on every core-extension (re)load, and `.claude/settings.local.json` is seeded from a stale,
  checked-in "template" that has drifted far behind the live, Claude-Code-accreted grant list —
  confirmed by diffing the deployed file against its template. **OpenCode's own sync path already
  solved this correctly** (`sync.lua` root-file logic: copy-once, never overwrite an existing
  `settings.json`) — Claude's loader should adopt the same install-once semantics. True
  wipe-survival for these two files then requires an explicit backup/restore step around the wipe
  operation itself, not a path relocation.
- **`.claude/logs/` is pure runtime output with no deploy-time skeleton at all** — no manifest
  entry, no root-file, no data-skeleton. Moving it out of `.claude/` is a straightforward path
  constant change in 3 hook scripts and 2 utility scripts (times their deployed copies).
- Full reader/writer enumeration and a concrete verification plan (extending the sibling task's
  already-proven scratch "self-rebuild" test pattern) are below.

## Context & Scope

Predecessor task relocated the global extension source store from
`~/.config/nvim/.claude/extensions/` to `~/.config/nvim/agent-system/extensions/`, establishing
`.claude/ == deploy(store, selection)`: everything inside a project's `.claude/` should be
reconstructable from (a) the global source store, now safely outside any project's `.claude/`,
and (b) the project's *selection* (which extensions are loaded). This task closes the remaining
gap: the selection state itself, plus two categories of files that are runtime/input rather than
build output, currently live **inside** the disposable `.claude/` tree and are destroyed by a
wipe.

Three independent items were researched: extensions.json (state manifest), settings.json +
settings.local.json (harness config), and logs/ (runtime logs). Each has a materially different
shape and required a different depth of investigation.

## Findings

### 1. extensions.json — selection manifest

**Current implementation** (`lua/neotex/plugins/ai/shared/extensions/state.lua:70-72`):
```lua
local function get_state_path(project_dir, config)
  return project_dir .. "/" .. config.base_dir .. "/" .. config.state_file
end
```
`config.base_dir` is `.claude` or `.opencode`; `config.state_file` is `"extensions.json"` for both
presets (`config.lua:54`, `config.lua:70`). `state.lua` exposes exactly two path-touching
functions, `M.read` and `M.write`, both of which call `get_state_path` — this is the single choke
point inside the Lua module (confirmed: `grep -rn "config\.state_file"` across the whole repo
returns only `config.lua`'s schema/preset and `state.lua:71` — no other Lua file reads this field
directly).

**Structure written** (real `.claude/extensions.json`, 5 loaded extensions in this repo):
```json
{ "version": "1.0.0", "extensions": { "<name>": { "source_dir": ..., "loaded_at": ...,
  "version": ..., "status": "active", "installed_files": [...], "installed_dirs": [...],
  "merged_sections": {...}, "data_skeleton_files": [...] } } }
```
`source_dir` was already identified by the predecessor task as write-only, self-healing state
(no read-back consumer) — that finding still holds and is unaffected by relocation.

**Non-Lua readers** (must move in lockstep, same class of "secondary hardcoding" the predecessor
task handled for the store path):
- `agent-system/extensions/core/scripts/skill-base.sh:48` — `skill_get_extension_dir()` hardcodes
  `local extensions_json=".claude/extensions.json"`. Deployed copies at `.claude/scripts/skill-base.sh`
  and `.opencode/scripts/skill-base.sh` are byte-identical siblings that must track it.
  **Side finding (pre-existing, out of scope for this task)**: this function queries
  `.loaded_extensions[] | select(.task_type == $tt)`, a schema that does not match what
  `state.lua` actually writes (`.extensions{name:{...}}`, no `task_type` field anywhere). This
  function silently no-ops today regardless of relocation — worth a separate task, not fixed here.
- `agent-system/extensions/core/scripts/validate-wiring.sh:221` — `local extensions_file="$system_dir/extensions.json"`
  where `$system_dir` is `.claude` or `.opencode`. Deployed copies at `.claude/scripts/validate-wiring.sh`
  and `.opencode/scripts/validate-wiring.sh` must track it.
- Documentation mentioning the path (`agent-system/extensions/core/EXTENSION.md`,
  `agent-system/extensions/core/README.md`, `agent-system/extensions/core/docs/architecture/extension-system.md`,
  `agent-system/extensions/literature/README.md`) — sweep required, same pattern as the
  predecessor task's Phase 6.

**Naming correction**: the task's candidate `.agent-extensions.json` is a good instinct (dotfile,
project-root, optionally committable — directly analogous to the already-established
`specs/literature-index.json` precedent of a project-root, optionally-committed pin file) but
needs system-scoping. `config.lua`'s `M.create()` schema should gain one new required-ish field
(e.g. `root_state_file`), with presets:
- `M.claude()` → `root_state_file = ".claude-extensions.json"`
- `M.opencode()` → `root_state_file = ".opencode-extensions.json"`

`get_state_path` becomes `project_dir .. "/" .. config.root_state_file` — no `base_dir` component
at all, since the whole point is independence from the disposable tree. This is a one-line change
at the single Lua choke point, plus the two shell-script hardcodes, plus doc sweep.

**Regenerate-skips-re-picking**: confirmed nothing in the picker/manager load path currently reads
`extensions.json` to *decide* what to load — `manager.load(name, ...)` (used by the predecessor
task's own verification) takes the extension name explicitly. Regenerate-without-re-picking is a
capability to be *added* (read the surviving root manifest's `extensions` keys with
`status == "active"` — `state.lua`'s own `M.list_loaded` already does this filtering — and iterate
`manager.load` over that list), not something that already exists. Flag this as required new
logic, not just a path change, for the planner.

### 2. settings.json / settings.local.json — hard external constraint

This is the finding that most changes the task's framing.

**Claude Code hardcodes the path.** Per Claude Code's own settings documentation: project
settings are read from exactly `.claude/settings.json` (checked into source control) and
`.claude/settings.local.json` (personal, git-ignored), with precedence
`managed > CLI flags > local settings > project settings > user settings`. This is the host
application's own file-resolution logic — nothing in this repo's Lua/shell tooling controls it,
unlike `extensions.json` which is our own bespoke state file free to live anywhere we choose. A
literal "move settings.json out of `.claude/`" breaks Claude Code's ability to find it. This
constraint does not apply to `extensions.json` (ours) or `logs/` (ours) — only to these two
specific filenames.

**What's actually broken today** (confirmed by direct inspection, not assumption):
- `loader.lua:582` `copy_root_files()` copies `settings.json` from
  `agent-system/extensions/core/root-files/settings.json` to `.claude/settings.json`
  **unconditionally** (via `copy_file(..., false, protected_paths, rel_path)` — the only opt-out
  is an explicit `.syncprotect` entry, which the real repo's `.syncprotect` does not contain for
  `settings.json`). Diffing the current `.claude/settings.json`'s `permissions` block against the
  template confirms they are byte-identical today — the deployed file has not diverged *yet*, but
  the moment a user hand-edits `.claude/settings.json`'s permissions and the core extension is
  reloaded, that edit is silently discarded.
- `.claude/settings.local.json` shows the failure mode already realized: its checked-in template
  (`agent-system/extensions/core/root-files/settings.local.json`) is a **stale snapshot** of
  accumulated Claude-Code-auto-added permission grants (dozens of `Bash(...)` entries from past
  interactive sessions, referencing paths and task numbers that predate the store relocation).
  The live deployed file is currently identical to that stale template purely by chance (no
  further grants have accreted since the last snapshot in this repo) — but the mechanism by which
  new grants Claude Code appends to `.claude/settings.local.json` ever get back into the
  wipe-survivable template is **manual, ad-hoc, and does not currently happen** (confirmed:
  `settings.local.json` is git-ignored via the user's global gitignore, so the live file is never
  captured by any commit; only a hand-authored template re-snapshot would update it).
- **`sync.lua` (the "Load Core" / Ctrl-l picker path) already solved this correctly for
  OpenCode**, but the fix was never extended to Claude: `sync.lua:1082-1110`'s `root_file_names`
  loop uses install-only semantics for `settings.json` — `action = "copy"` only if the local file
  doesn't already exist, `"skip"` otherwise (comment: "these contain project-specific hooks,
  permissions, MCP servers, and package dependencies that must not be clobbered by sync"). For
  `.claude`, this whole `root_file_names` list is **empty** (`sync.lua:1078`, comment: "all root
  files ... are now managed by the extension loader ... not synced") — meaning Claude's path
  bypasses the safe pattern entirely and goes through `loader.lua`'s unconditional-overwrite
  `copy_root_files` instead.

**Recommended fix** (for the planner, not implemented here):
1. Change `loader.lua:copy_root_files` (or add a Claude-specific gate ahead of it) to install-once
   semantics for `settings.json` and `settings.local.json` specifically — copy only if the target
   does not already exist, mirroring `sync.lua`'s already-correct OpenCode logic. This fixes the
   live clobber-on-reload bug independent of the wipe scenario.
2. Accept, as an explicit non-goal, that a raw `rm -rf .claude/` will always destroy whatever is
   currently in `.claude/settings.local.json` (Claude-Code-owned accretive state that cannot be
   reconstructed from any source tree, by construction — it only exists because a human clicked
   "don't ask again"). Zero-loss for *this* file requires the wipe operation itself to snapshot
   `.claude/settings.json` + `.claude/settings.local.json` to a project-root staging file (or
   `specs/`-adjacent location) immediately before deletion and restore them immediately after
   regeneration — analogous to how `specs/` already survives by simply living outside `.claude/`,
   but here the file cannot live outside `.claude/` at all, so the survival mechanism has to be a
   backup/restore step wrapped around the wipe command rather than a path change.
3. Re-snapshot `agent-system/extensions/core/root-files/settings.local.json`'s template is a
   separate, optional hygiene task — not required for this task's acceptance criteria and
   explicitly flagged as such so the planner doesn't scope-creep into auditing every accumulated
   permission string.

### 3. logs/ — pure runtime output, no deploy skeleton

Confirmed via `grep` across `agent-system/extensions/core/manifest.json`: no `"logs"` entry
anywhere in `provides` (no root-file, no data-skeleton, no scripts/hooks category pointing at a
source `logs/` directory). `.claude/logs/` is created purely at runtime via `mkdir -p` inside the
scripts that write to it. This makes it the simplest of the three items: a path-constant change,
no deploy-pipeline logic change.

**Files with the hardcoded `.claude/logs` path constant** (source; each has deployed
`.claude/`/`.opencode/` copies that must track it, same pattern as every other core script/hook):
- `agent-system/extensions/core/hooks/post-command.sh:5` — `LOG_DIR=".claude/logs"`
- `agent-system/extensions/core/hooks/log-session.sh:5` — `LOG_DIR=".claude/logs"`
- `agent-system/extensions/core/hooks/subagent-postflight.sh:35` — `local LOG_DIR=".claude/logs"`
- `agent-system/extensions/core/scripts/update-phase-status.sh:110` — `log_dir="${repo_root}/.claude/logs"`
- `agent-system/extensions/core/scripts/generate-todo.sh:38` — `LOG_FILE="${PROJECT_ROOT}/.claude/logs/generate-todo.log"`

Plus documentation references in `docs/guides/context-loading-best-practices.md`,
`docs/guides/permission-configuration.md`, `context/standards/error-handling.md`,
`context/troubleshooting/workflow-interruptions.md`, `context/patterns/postflight-control.md` —
sweep, not logic changes. Recommend a project-root, non-dot-prefixed or dot-prefixed directory
(e.g. `.agent-logs/`, gitignored) mirroring `specs/`'s "lives at project root" precedent; add the
new directory name to the project root `.gitignore` (git status already shows `.claude/logs/*.log`
under version control today via `.claude/.gitignore`'s `logs/` entry only excluding the deployed
copy — the currently-tracked `sessions.log` / `subagent-postflight.log` files under
`.claude/logs/` in git status are a separate, likely-accidental tracking issue worth flagging to
the planner but not necessarily fixing under this task).

### 4. Verification approach — precedent to extend

The predecessor task already established and proved a scratch "self-rebuild" verification
pattern worth reusing directly rather than re-inventing: full `rsync` copy of the repo (or a
synthetic fake project dir) into the scratchpad, delete `.claude/` from the copy, call
`manager.load(name, {project_dir=..., global_dir=..., confirm=false})` for each previously-active
extension, and diff the regenerated tree against the pre-wipe tree. For task 865 specifically,
the headless verification should additionally:
1. Construct a **fake, minimal project dir** in the scratchpad (not a full repo rsync — the task
   explicitly calls for this, and it is cheaper/faster and avoids any risk of touching the real
   `~/.config/nvim/.claude` regardless of bug class).
2. Deploy 1-2 extensions into it via `manager.load`, confirm `.claude-extensions.json` (or
   whatever final name is chosen) lands at the fake project root, not inside `.claude/`.
3. `rm -rf` only the fake project's `.claude/` directory (never the real tree — this loader had a
   live data-loss bug recently per the task's own testing-safety mandate).
4. Confirm the root manifest file survived the deletion.
5. Regenerate by iterating `manager.load` over the surviving manifest's active-extension list
   (the "regenerate-skips-re-picking" logic identified as new/required above) and diff the
   regenerated `.claude/` tree against a pre-wipe snapshot for byte-identical output (excluding
   inherently-volatile fields like `loaded_at` timestamps).
6. Separately verify (in the same fake project, or a second one) that `settings.json` survives an
   in-place core-extension *reload* (not a wipe) unclobbered once install-once semantics are
   applied — this is the regression test for finding #2's live-clobber bug, distinct from the
   wipe/regenerate test.

## Decisions

- `extensions.json` relocation target: project-root, system-scoped dotfile
  (`.claude-extensions.json` / `.opencode-extensions.json`) via a new `config.lua` field
  (`root_state_file`), not a single shared `.agent-extensions.json` — because `state.lua`/`config.lua`
  are shared infrastructure across two independently-loadable presets that could coexist in one
  project.
- `settings.json` / `settings.local.json`: requirement (2) is **reframed, not dropped**. The
  actionable fix is (a) install-once semantics in the Claude loader (matching OpenCode's existing
  `sync.lua` pattern) to stop the live clobber-on-reload bug, and (b) an explicit backup/restore
  step wrapped around the wipe operation for true zero-loss across a full `.claude/` deletion,
  because the file's canonical read path is hardcoded by Claude Code itself and cannot move.
- `logs/`: straightforward relocation to a project-root directory; no deploy-pipeline logic
  involved since there was never a source skeleton for it.
- Verification: extend the predecessor task's proven scratch self-rebuild pattern rather than
  designing a new verification methodology from scratch.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Two presets (Claude/OpenCode) could write extensions manifests to the same root filename if both are ever active in one project | System-scoped filenames (`.claude-extensions.json` / `.opencode-extensions.json`) via the new `root_state_file` config field |
| Treating requirement (2) literally and attempting to relocate `.claude/settings.json` itself | This report documents the hard external constraint (Claude Code's own settings resolution) with a citation; planner should treat the reframed fix (install-once + backup/restore) as the actual acceptance target, and confirm this reframing with the user/orchestrator before implementing |
| `skill-base.sh`/`validate-wiring.sh` hardcoded path drift (same class of bug the predecessor task fixed for the store path) | Enumerated both files and their deployed copies explicitly above; planner should update all copies in lockstep and consider deriving from a single source the way the predecessor task derived `sync.lua`'s `core_source_base` |
| Destructive testing against the real `~/.config/nvim/.claude` tree (explicit mandate: never) | All verification confined to scratchpad fake project dirs, per Finding 4 and the predecessor task's proven pattern |
| `.claude/logs/*.log` currently appears tracked in git despite `.claude/.gitignore`'s `logs/` entry (git status shows `M .claude/logs/sessions.log`) | Flagged as a separate pre-existing tracking anomaly for the planner to address (likely: files were committed before the gitignore rule existed) — not blocking for this task |

## Context Extension Recommendations

- **Topic**: Claude Code settings-file resolution hierarchy (hardcoded `.claude/settings.json` /
  `.claude/settings.local.json` paths, precedence order).
  **Gap**: not documented anywhere in `agent-system/extensions/core/context/` or `docs/` — the
  existing `docs/guides/permission-configuration.md` discusses permission *content* but not the
  fact that the file *location* itself is a harness-level constraint outside this repo's control.
  **Recommendation**: add a short subsection to `docs/guides/permission-configuration.md` or a new
  architecture note cross-referenced from the extension-system docs, so future
  wipe/regenerate-related tasks don't re-discover this constraint from scratch.
- **Topic**: install-once vs. always-overwrite semantics for deployed root files.
  **Gap**: `sync.lua`'s OpenCode-only install-once pattern for `settings.json` is undocumented as
  a reusable pattern; `loader.lua`'s `copy_root_files` unconditional-overwrite behavior is also
  undocumented as a risk.
  **Recommendation**: document both in `docs/architecture/extension-system.md` once the planner
  unifies them, so the asymmetry doesn't reappear for a future root file.

## Appendix

**Search queries / commands used**:
- `grep -rln "extensions\.json" --include="*.lua" .` / `--include="*.sh" .`
- `grep -rln "settings\.json" --include="*.lua" .` / `--include="*.sh" .`
- `grep -rln "\.claude/logs" agent-system/`
- Direct reads: `state.lua`, `config.lua`, `init.lua` (merge_targets/process_merge_targets/reverse_merge_targets),
  `loader.lua` (`copy_root_files`, `remove_installed_files`), `sync.lua` (lines ~1040-1120)
- `python3 -c "import json; ..."` diffs of `.claude/settings.json` and `.claude/settings.local.json`
  against their `agent-system/extensions/core/root-files/` templates
- `git check-ignore -v .claude/settings.local.json` (confirmed global-gitignore-based exclusion)
- `WebSearch`: "Claude Code settings.json .claude/settings.local.json project settings hierarchy
  documentation" — confirmed hardcoded settings-file resolution and precedence order
- Read of predecessor task's plan/summary (`specs/863_relocate_extension_source_store_out_of_claude/`)
  for the established deploy/target model, self-rebuild verification precedent, and the
  `source_dir`/`settings.local.json` staleness notes it already flagged as out of scope
