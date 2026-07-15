# Implementation Plan: Make .claude/ Wipe Lossless and One-Keystroke Regenerable

- **Task**: 865 - Make .claude/ wipe lossless and one-keystroke regenerable
- **Status**: [NOT STARTED]
- **Effort**: 9 hours
- **Dependencies**: 863 (store relocation / deploy-target model, already landed)
- **Research Inputs**: reports/01_wipe-lossless-regenerable-research.md
- **Artifacts**: plans/01_wipe-lossless-regenerable.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md, neovim-lua.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Close the remaining wipe-survival gap in the `.claude/ == deploy(store, selection)` model by
lifting stateful and runtime files out of the disposable deploy tree. Three independent items are
addressed with materially different shapes: (1) the extension **selection manifest**
(`extensions.json`) relocates cleanly to a preset-specific project-root dotfile; (2) `settings.json`
/ `settings.local.json` **cannot** literally move (Claude Code hardcodes the `.claude/` read path),
so the fix is reframed to install-once loader semantics plus a wipe-time backup/restore wrapper; and
(3) `logs/` is pure runtime output relocated by a path-constant change. New regenerate-from-surviving-
selection logic is added so a wiped `.claude/` rebuilds without re-picking, and the whole cycle is
proven in a scratchpad fake project dir. Definition of done: after deleting a fake project's
`.claude/`, the surviving root manifest drives an identical rebuild, and `settings.json` survives an
in-place reload unclobbered — verified headlessly, never against the real `~/.config/nvim/.claude`.

### Research Integration

The research report reframed deliverable (2): `.claude/settings.json` and `.claude/settings.local.json`
cannot relocate because Claude Code (the host app) hardcodes those paths. This plan adopts the report's
recommended reframe — install-once semantics in `loader.lua:copy_root_files` (mirroring the already-correct
OpenCode pattern in `sync.lua:1078-1110`) plus an explicit backup/restore step wrapped around the wipe.
The report also identified that regenerate-without-re-picking does **not** exist yet and must be added as
new logic (read the surviving manifest's `status == "active"` extensions via `state.lua:M.list_loaded`,
iterate `manager.load`). All reader/writer sites for `extensions.json` and `.claude/logs` are enumerated
in the report and carried into the phases below.

### Prior Plan Reference

No prior plan for this task. The predecessor task (863, store relocation) is referenced for its proven
scratchpad self-rebuild verification pattern (`manager.load` with `project_dir`/`global_dir` pointed at a
scratch copy, avoiding the `vim.fn.confirm()` dialog that blocks headless runs) and its established
"secondary hardcoding" sweep discipline for shell-script and doc path constants.

### Roadmap Alignment

No ROADMAP.md consulted for this task (not provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Relocate `extensions.json` to a preset-specific project-root dotfile (`.claude-extensions.json` /
  `.opencode-extensions.json`) via one new `config.lua` field (`root_state_file`), changed at the single
  Lua choke point plus all enumerated non-Lua readers.
- Add regenerate-from-surviving-selection logic so a wiped `.claude/` rebuilds without re-picking.
- Stop the live clobber-on-reload bug for `settings.json` / `settings.local.json` via install-once loader
  semantics, and provide a backup/restore wrapper for true zero-loss across a full wipe.
- Relocate `logs/` to a project-root directory via path-constant changes across all source scripts and
  their deployed copies.
- Prove the full wipe-and-regenerate cycle headlessly in a scratchpad fake project dir.

**Non-Goals**:
- Literally moving `.claude/settings.json` / `.claude/settings.local.json` out of `.claude/` (infeasible;
  host-app constraint).
- Re-snapshotting the stale `root-files/settings.local.json` template (separate optional hygiene item).
- Fixing the pre-existing `skill-base.sh` schema mismatch (`.loaded_extensions[]` vs actual
  `.extensions{}`) — the function silently no-ops today; only its path constant is updated here.
- Fixing the pre-existing `.claude/logs/*.log` git-tracking anomaly (flag only).
- Any change to the already-landed `check_deployed_rule_drift` or the symlink-safe remove path in
  `loader.lua` (build on, do not recreate).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Two presets writing manifests to the same root filename if both deploy into one project | M | L | Preset-scoped filenames via new `root_state_file` field (`.claude-extensions.json` / `.opencode-extensions.json`) |
| Treating deliverable (2) literally and breaking Claude Code settings resolution | H | M | Reframed fix documented in plan; no path move for settings files — install-once + backup/restore only |
| Path-constant drift between source scripts and their `.claude`/`.opencode` deployed copies | M | M | Every source + deployed copy enumerated per phase; update in lockstep; verify with grep sweep |
| `settings.json` hooks merge (`process_merge_targets`) breaks after install-once change | M | L | Install-once affects only the base-template copy; the idempotent hooks merge still runs against the preserved/fresh file — verified by reload regression test in Phase 7 |
| Destructive testing against the real `~/.config/nvim/.claude` tree | H | L | All destructive steps confined to scratchpad fake project dirs; `manager.load` with scratch `project_dir`/`global_dir`; never `rm -rf` the real tree |
| No single "wipe" entrypoint exists (wipe = manual `rm -rf`, regenerate = picker "Load Core") | M | M | Phase 5 locates the actual regenerate keystroke and wires restore there; backup/restore also exposed as a callable helper for the wipe step |
| `M.write` still mkdir's `base_dir` before writing the now-root-level manifest | L | M | Phase 1 removes the obsolete `base_dir` mkdir in `M.write`; project_dir always exists |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 6 | -- |
| 2 | 2, 3 | 1 |
| 3 | 5 | 3, 4 |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Relocate extensions.json — Lua choke point [COMPLETED]

**Goal**: Move the selection manifest from `$CWD/.claude/extensions.json` to a preset-specific
project-root dotfile via one new config field and the single Lua path function.

**Tasks**:
- [x] `config.lua` `M.create`: add `root_state_file = { opts.root_state_file, "string" }` to the
  `vim.validate` block and `root_state_file = opts.root_state_file` to the returned table.
- [x] `config.lua` `M.claude()`: add `root_state_file = ".claude-extensions.json"`.
- [x] `config.lua` `M.opencode()`: add `root_state_file = ".opencode-extensions.json"`.
- [x] `state.lua` `get_state_path`: change body to
  `return project_dir .. "/" .. config.root_state_file` (drop the `base_dir`/`state_file` composition).
- [x] `state.lua` `M.write`: remove the now-obsolete `base_dir` mkdir block (lines ~104-108); the root
  manifest lives at `project_dir` which always exists. Keep `M.read`/`M.write` otherwise unchanged.
- [x] Leave the legacy `state_file` field in `config.lua` in place if any other reader still needs it;
  confirm via `grep -rn "config\.state_file"` that only `config.lua` schema references remain after the
  `state.lua` change, and remove `state_file` only if fully unreferenced. *(deviation: altered — grep
  confirmed `state_file` was fully unreferenced after the `state.lua` edit, so the field was removed
  entirely from `config.lua`'s validate block and both presets rather than left in place; `root_state_file`
  replaces it one-for-one.)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - new `root_state_file` field + presets
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - `get_state_path`, `M.write` mkdir removal

**Verification**:
- `grep -rn "config\.state_file\|config\.root_state_file"` shows `state.lua` reads `root_state_file` and
  no stray `state_file` readers remain.
- Headless: `require` both modules without error; `config.claude().root_state_file == ".claude-extensions.json"`.

---

### Phase 2: Update extensions.json non-Lua readers + doc sweep [COMPLETED]

**Goal**: Track the relocated, preset-scoped manifest path across every shell reader, their deployed
copies, and documentation.

**Tasks**:
- [x] `agent-system/extensions/core/scripts/skill-base.sh:48` — replace the hardcoded
  `.claude/extensions.json` with a preset-aware project-root path derived from the system dir
  (e.g. resolve `.claude` -> `.claude-extensions.json`, `.opencode` -> `.opencode-extensions.json`).
  Do NOT fix the pre-existing `.loaded_extensions[]` schema mismatch (out of scope; note in commit).
- [x] `agent-system/extensions/core/scripts/validate-wiring.sh:221` — replace
  `"$system_dir/extensions.json"` with the project-root preset-scoped filename derived from `$system_dir`.
  *(deviation: altered — implemented as `"${system_dir}-extensions.json"` string concatenation rather
  than a case/if branch: `$system_dir` is always passed as an absolute path ending in `/.claude` or
  `/.opencode`, so appending `-extensions.json` yields the correct project-root sibling path for both
  presets with one line, no branching needed.)*
- [x] Update the byte-identical deployed copies in lockstep: `.claude/scripts/skill-base.sh`,
  `.opencode/scripts/skill-base.sh`, `.claude/scripts/validate-wiring.sh`,
  `.opencode/scripts/validate-wiring.sh`. *(deviation: altered — `.opencode/scripts/skill-base.sh` is
  an independently-maintained variant (no `agent-system/extensions/core` source counterpart; diverges
  from the Claude version in task-status vocabulary, artifact-linking helpers, etc.), so its own
  hardcoded `.opencode/extensions.json` -> `.opencode-extensions.json` edit was applied directly rather
  than by copying the `.claude` source; also updated `.opencode/extensions/core/scripts/validate-wiring.sh`,
  a 4th deployed copy discovered on disk beyond the plan's named 4, to keep all validate-wiring.sh
  copies byte-identical.)*
- [x] Documentation sweep (path references only, no logic): `agent-system/extensions/core/EXTENSION.md`,
  `agent-system/extensions/core/README.md`,
  `agent-system/extensions/core/docs/architecture/extension-system.md`,
  `agent-system/extensions/literature/README.md`.
- [x] No task-number citations in any of these files (they are outside `specs/**`).

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` + `.claude/`/`.opencode/` copies
- `agent-system/extensions/core/scripts/validate-wiring.sh` + `.claude/`/`.opencode/` copies
- 4 documentation files listed above

**Verification**:
- `grep -rn "\.claude/extensions\.json\|extensions\.json" agent-system/ .claude/scripts/ .opencode/scripts/`
  returns no stale `.claude/extensions.json` references (only the new root filenames or unrelated matches).
- Deployed shell copies match their sources (`diff` the source against each deployed copy).

---

### Phase 3: Add regenerate-from-surviving-selection logic [COMPLETED]

**Goal**: Add the new capability that reads the surviving root manifest and rebuilds `.claude/` without
re-picking — the crux of "one-keystroke regenerable".

**Tasks**:
- [x] Add a manager function in `init.lua` (e.g. `manager.regenerate(opts)`), that:
  reads state via `state_mod.read(project_dir, config)`, gets active extensions via
  `state_mod.list_loaded(state)`, and iterates `manager.load(name, {confirm=false, project_dir=...,
  global_dir=...})` over that list, accumulating success/error per extension. *(deviation: altered —
  discovered during implementation that `manager.load`'s own "already loaded" guard
  (`state_mod.is_loaded`) would unconditionally reject every formerly-active extension, since the
  surviving manifest still marks them `status == "active"` even though their files are gone after a
  wipe; `manager.load` also has no `global_dir` opt (global source dir is baked into the `config`
  the manager was created with, not passed per-call). Fixed by resetting state to `{extensions={}}`
  before the loop, then calling `manager.load(name, {confirm=false, project_dir=...})` per formerly-
  active name -- `manager.load`'s existing recursive dependency resolution transparently handles
  ordering, and a name already loaded by an earlier iteration's dependency pull-in is detected via a
  fresh state re-read rather than re-invoked. Verified with a scratch smoke test: loading "memory"
  (which depends on "core") into a fake project, wiping only the fake project's `.claude/`, and
  calling `manager.regenerate` successfully reloaded both `core` and `memory` with 0 failures.)*
- [x] Return a structured result (loaded names, failures) so callers and the headless test can assert on it.
- [x] Ensure the function is a no-op-safe when the surviving manifest is empty (returns empty result, no error).
- [x] Add a LuaDoc header per neovim-lua.md conventions; keep it a local-scoped, `pcall`-guarded load loop.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - new `manager.regenerate` function

**Verification**:
- Headless: construct a scratch fake project with a hand-written `.claude-extensions.json` listing one
  active extension; call `manager.regenerate`; assert the extension is loaded and `.claude/` is populated.

---

### Phase 4: Settings install-once semantics in loader [COMPLETED]

**Goal**: Stop `loader.lua:copy_root_files` from unconditionally overwriting `settings.json` /
`settings.local.json` on every core reload, mirroring the OpenCode pattern already in `sync.lua`.

**Tasks**:
- [x] In `loader.lua:copy_root_files` (lines 582-610), add an install-once guard for a defined set of
  filenames (`settings.json`, `settings.local.json`): if `vim.fn.filereadable(target_path) == 1`, skip the
  copy (count as skipped), preserving the existing project file. All other root files
  (e.g. `.gitignore`) keep current always-copy behavior.
- [x] Keep the guard scoped and readable (a small `install_once = { ["settings.json"] = true,
  ["settings.local.json"] = true }` lookup, matching `sync.lua`'s intent and comment style).
  *(deviation: altered — named the module-level table `INSTALL_ONCE_ROOT_FILES` for readability at
  call sites; same shape and intent as the plan's suggested lookup.)*
- [x] Confirm the settings-hooks merge (`process_merge_targets` -> `provides.settings`
  `merge-sources/settings-hooks.json` into `.claude/settings.json`) still runs after the copy step and
  merges idempotently into the preserved/fresh file (no code change; verified behavior). Confirmed by
  inspection: `init.lua`'s `manager.load` calls `copy_root_files` then `process_merge_targets`
  unconditionally in sequence regardless of whether the copy was skipped by install-once, and
  `merge_mod.merge_settings` is idempotent (verified in Phase 7).
- [x] No task-number citations in the loader comment (outside `specs/**`).

**Post-hoc gap found and closed (during Phase 5 smoke testing)**: `copy_root_files`'s install-once
guard alone does not stop "the live clobber-on-reload bug" for the `manager.reload` (unload-then-load)
path, because `manager.unload` unconditionally deletes every tracked `installed_files` entry --
including `settings.json`/`settings.local.json` -- *before* `manager.load` runs, so the install-once
`filereadable` check always finds the target absent and copies fresh regardless. Closed by exporting
`loader_mod.INSTALL_ONCE_ROOT_FILES` and excluding those two filenames from removal in
`manager.unload` (`init.lua`), mirroring the existing `.syncprotect` skip pattern. Verified with a
scratch smoke test: hand-edited `settings.local.json` now survives a full `manager.reload("core", ...)`
cycle (previously did not, confirming this was a live bug, not a hypothetical one).

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - `copy_root_files` install-once guard

**Verification**:
- Headless (Phase 7 regression): deploy core into a scratch fake project, hand-edit
  `.claude/settings.json`, reload core, assert the hand-edit survives (install-once), while a fresh
  project with no existing file still receives the template.

---

### Phase 5: Settings backup/restore wrapper + regenerate entrypoint + architecture docs [COMPLETED]

**Goal**: Provide true zero-loss for the two un-relocatable settings files across a full wipe, and wire
the restore into the actual regenerate path; document the host-app constraint and the install-once pattern.

**Tasks**:
- [x] Add a small backup/restore helper (Lua) that snapshots `.claude/settings.json` and
  `.claude/settings.local.json` to a project-root staging location (e.g. `.claude-settings-backup/` or a
  single dotfile pair) immediately before a wipe, and restores them immediately after regenerate. Use the
  loader's symlink-safe file handling conventions; no destructive git. *(deviation: altered — new file
  `lua/neotex/plugins/ai/shared/extensions/settings_backup.lua`; preset-scoped staging directory name
  via a new `config.settings_backup_dir` field (`.claude-settings-backup` / `.opencode-settings-backup`),
  mirroring `root_state_file`'s collision-avoidance rationale, rather than a single shared dotfile pair.)*
- [x] Locate the actual regenerate keystroke / entrypoint (the picker "Load Core" path in
  `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, or the `manager.regenerate` added in
  Phase 3) and wire the restore step so a regenerate after a wipe re-applies the backed-up settings if the
  staging snapshot exists. If no single "wipe" keystroke exists, expose backup + restore as callable
  helpers and document the intended `backup -> rm -rf .claude/ -> regenerate -> restore` sequence.
  *(deviation: altered — wired restore into `manager.regenerate` itself (confirmed during Phase 2 research
  that the picker's "Load Core" path, `sync.load_all_globally`, does not touch `root_files` for `.claude`
  at all — settings are loader-owned, not sync-owned, for that base_dir), per the plan's own documented
  fallback; `manager.regenerate` calls `settings_backup.restore` unconditionally at the end, no-op-safe
  when no backup was staged.)*
- [x] Add the staging location to the project-root `.gitignore`.
- [x] Documentation (per research Context Extension Recommendations): add a short subsection to
  `agent-system/extensions/core/docs/guides/permission-configuration.md` (or a cross-referenced
  architecture note) explaining that `.claude/settings.json` / `.claude/settings.local.json` file
  *locations* are a Claude Code harness constraint, and document the install-once vs always-overwrite
  asymmetry now unified between `loader.lua` and `sync.lua` in
  `agent-system/extensions/core/docs/architecture/extension-system.md`.
- [x] No task-number citations in any deliverable file (outside `specs/**`).

**Post-hoc gap found and closed (see Phase 4's post-hoc note)**: `manager.unload` was excluding
`settings.json`/`settings.local.json` from removal added here as part of closing the install-once
loop, discovered while smoke-testing this phase's backup/restore cycle alongside the Phase 4 reload
regression.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Files to modify**:
- New/updated Lua helper (co-located with the extensions manager or picker sync operation)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - restore wiring (if that is the regenerate path)
- `.gitignore` (project root) - staging location
- `agent-system/extensions/core/docs/guides/permission-configuration.md` and
  `agent-system/extensions/core/docs/architecture/extension-system.md` - documentation

**Verification**:
- Headless (Phase 7): in a scratch fake project, populate `settings.local.json` with a marker grant, run
  backup, `rm -rf` the fake `.claude/`, regenerate, restore, assert the marker grant is present again.

---

### Phase 6: Relocate logs/ out of .claude/ [COMPLETED]

**Goal**: Move runtime logs to a project-root directory via path-constant changes; add gitignore; flag the
pre-existing tracking anomaly.

**Tasks**:
- [x] Change the `.claude/logs` path constant to a project-root directory (e.g. `.agent-logs`) in the 5
  source files: `agent-system/extensions/core/hooks/post-command.sh:5`,
  `agent-system/extensions/core/hooks/log-session.sh:5`,
  `agent-system/extensions/core/hooks/subagent-postflight.sh:35`,
  `agent-system/extensions/core/scripts/update-phase-status.sh:110`,
  `agent-system/extensions/core/scripts/generate-todo.sh:38`.
- [x] Update the deployed copies in lockstep under `.claude/` and (where present) `.opencode/`
  (`hooks/post-command.sh`, `hooks/log-session.sh`, `hooks/subagent-postflight.sh`,
  `scripts/update-phase-status.sh`, `scripts/generate-todo.sh`). *(deviation: altered — also updated
  `.opencode/extensions/core/hooks/*.sh`, which pre-existing drift had hardcoded to `.claude/logs`
  instead of `.opencode/logs`; both `.opencode` copies now converge on the same `.agent-logs`
  literal, incidentally fixing that divergence as a side effect of the path-constant change rather
  than as a separate logic fix.)*
- [x] Add the new logs directory (e.g. `.agent-logs/`) to the project-root `.gitignore`.
- [x] Documentation sweep (path references only): `docs/guides/context-loading-best-practices.md`,
  `docs/guides/permission-configuration.md`, `context/standards/error-handling.md`,
  `context/troubleshooting/workflow-interruptions.md`, `context/patterns/postflight-control.md`
  (resolve these under `agent-system/extensions/core/` and/or deployed `.claude/` as they exist).
  *(deviation: altered — swept all discovered deployed copies, including `.opencode/context/core/*`
  variants and a stray comment-only reference in `update-phase-status.sh:9`, beyond the plan's named
  file list, since `grep -rl` surfaced them as the same literal path pattern.)*
- [x] Flag (in the phase/commit notes, NOT fix): the pre-existing `.claude/logs/*.log` files currently
  tracked in git despite `.claude/.gitignore`'s `logs/` entry — likely committed before the rule existed.
  Confirmed still present: `.claude/logs/sessions.log`, `.claude/logs/subagent-postflight.log` remain
  git-tracked; left as-is per plan scope (not fixed).

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- 5 source scripts/hooks + their deployed `.claude/`/`.opencode/` copies
- `.gitignore` (project root)
- doc files listed above

**Verification**:
- `grep -rn "\.claude/logs" agent-system/ .claude/` returns no stale references in the changed scripts.
- Deployed copies match sources (`diff`).
- Headless smoke: run a script that writes a log (e.g. trigger `generate-todo.sh` in a scratch dir) and
  confirm the log lands in the new project-root directory, not `.claude/logs`.

---

### Phase 7: Headless scratch verification of full wipe-and-regenerate cycle [NOT STARTED]

**Goal**: Prove wipe-losslessness and identical regeneration end-to-end in a scratchpad fake project, plus
the settings-reload regression — never touching the real tree.

**Tasks**:
- [ ] Build a minimal fake project dir in the scratchpad (not a full repo rsync): a `project_dir` with the
  agent-system store reachable via `global_dir` pointed at the real repo (read-only source), and an empty
  `.claude/`.
- [ ] Deploy 1-2 extensions via `manager.load(name, {project_dir=fake, global_dir=repo, confirm=false})`;
  assert `.claude-extensions.json` lands at the fake project **root**, not inside `.claude/`.
- [ ] Snapshot the deployed `.claude/` tree (excluding volatile fields like `loaded_at`).
- [ ] Run the Phase 5 backup helper (settings), then `rm -rf` ONLY the fake project's `.claude/`.
- [ ] Assert the root `.claude-extensions.json` (and settings backup) survived the deletion.
- [ ] Call `manager.regenerate` (Phase 3) over the surviving manifest; run the Phase 5 restore.
- [ ] Diff the regenerated `.claude/` against the pre-wipe snapshot for byte-identical output (excluding
  volatile timestamp fields); assert restored `settings.local.json` marker survived.
- [ ] Separate regression (same or second fake project): deploy core, hand-edit `.claude/settings.json`,
  reload core, assert the edit survives (install-once, Phase 4).
- [ ] Guardrail assertion in the test harness: refuse to run if `project_dir` resolves to the real
  `~/.config/nvim` tree.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Files to modify**:
- Scratchpad test scripts only (no repo source files); results captured in the implementation summary.

**Verification**:
- All headless assertions pass; regenerated tree is byte-identical (modulo volatile fields); settings
  survive both the wipe/restore cycle and the in-place reload.
- No mutation of the real `~/.config/nvim/.claude` tree (confirm via `git status` showing only intended
  source edits from Phases 1-6).

---

## Testing & Validation

- [ ] `config.claude().root_state_file == ".claude-extensions.json"` and
  `config.opencode().root_state_file == ".opencode-extensions.json"` (Phase 1).
- [ ] `grep` sweeps confirm no stale `.claude/extensions.json` or `.claude/logs` references remain in
  changed source + deployed copies (Phases 2, 6).
- [ ] Deployed shell copies are byte-identical to their sources after edits (Phases 2, 6).
- [ ] Scratch fake-project deploy places `.claude-extensions.json` at project root (Phase 7).
- [ ] Wipe (`rm -rf` fake `.claude/`) + `manager.regenerate` + restore yields a byte-identical `.claude/`
  (modulo `loaded_at`), with settings restored (Phase 7).
- [ ] In-place core reload preserves a hand-edited `.claude/settings.json` (install-once regression, Phase 7).
- [ ] Real `~/.config/nvim/.claude` tree untouched by any test (`git status` review).

## Artifacts & Outputs

- plans/01_wipe-lossless-regenerable.md (this file)
- Modified: `config.lua`, `state.lua`, `init.lua`, `loader.lua`, picker `sync.lua` (restore wiring)
- Modified: `skill-base.sh`, `validate-wiring.sh` (source + deployed copies)
- Modified: 5 log-writing scripts/hooks (source + deployed copies)
- Modified: project-root `.gitignore`; core docs (`permission-configuration.md`, `extension-system.md`,
  and the enumerated path-sweep docs)
- New: `manager.regenerate` logic; settings backup/restore helper
- summaries/01_wipe-lossless-regenerable-summary.md (at implementation time)

## Rollback/Contingency

- All changes are localized path-constant and small-function edits; revert via `git checkout` of the
  touched source files (no destructive git on uncommitted work — snapshot-then-rollback only if needed).
- The `extensions.json` relocation is backward-tolerant: `state.lua:M.read` returns a default empty state
  when the manifest is absent, so a half-migrated project degrades to "no extensions recorded" rather than
  erroring; re-running the picker re-populates the root manifest.
- If the regenerate entrypoint wiring (Phase 5) proves entangled with the picker, fall back to exposing
  backup/restore + `manager.regenerate` as standalone callable helpers and document the manual sequence,
  keeping the acceptance-critical zero-loss property intact without the one-keystroke convenience.
- Settings install-once is purely additive (a skip guard); reverting it restores prior always-overwrite
  behavior with no data migration.
