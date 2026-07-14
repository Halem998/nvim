# Implementation Plan: Relocate Extension Source Store Out of .claude/

- **Task**: 863 - Relocate extension source store out of .claude/
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (this is the unlocking/foundation change)
- **Research Inputs**: specs/863_relocate_extension_source_store_out_of_claude/reports/01_relocate-extension-source-store.md
- **Artifacts**: plans/01_relocate-extension-store.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Move the global extension source store from `~/.config/nvim/.claude/extensions/` to
`~/.config/nvim/agent-system/extensions/` (non-dot-prefixed sibling of `lua/`, `specs/`) so that
`.claude/` in any working directory becomes a 100%-disposable copy-deploy build artifact with no
authored source inside it. The store is read through a single canonical default
(`config.lua:55`, `M.claude` preset) plus three secondary hardcodings (one Lua picker literal, two
shell-script defaults) and one test fixture; all must move in lockstep. Copy-deploy only, no
symlinks; all destructive loader testing runs in the scratchpad against fake project dirs, never
the real `~/.config/nvim/.claude` tree. Definition of done: the picker lists extensions from the
new store, deploying into an arbitrary `$CWD/.claude` still works, and a scratch copy of
`~/.config/nvim` can delete-and-regenerate its own `.claude/` from the relocated store.

### Research Integration

The report established that `M.claude(global_dir)` in `config.lua:48-59` is the single canonical
choke point consumed opaquely by all load/unload/list/verify logic, with exactly one duplicated
literal (`sync.lua:909` `core_source_base = ".claude/extensions/core"`), two independently
defaulting shell scripts (`check-extension-docs.sh` EXT_DIR, `validate-extension-index.sh` glob),
and one test fixture (`manifest_spec.lua:192`). It confirmed the deployed per-project
`.claude/extensions/{name}/manifest.json` stub (read at runtime by `command-route-skill.sh` and
`skill-base.sh`) is a DIFFERENT concept that must NOT move or be touched. It recommended
`git mv` to preserve history, a derive-don't-duplicate refactor for `sync.lua`, and a
scratchpad-only verification plan. The `.opencode/` mirror bug and the orthogonal foundation
pieces (`check_deployed_rule_drift`, `loader.lua` symlink-safe remove) are explicitly out of scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Physically relocate the global source store to `~/.config/nvim/agent-system/extensions/` via
  `git mv` (history-preserving), leaving `.claude/extensions/` at repo root as a pure deploy target.
- Repoint the single canonical default (`config.lua:55`) to the new store.
- Eliminate the second hardcoded literal by deriving `sync.lua`'s `core_source_base` from the
  canonical config value (close the drift class permanently).
- Repoint the two shell-script defaults (source copies now under `agent-system/`, plus their
  deployed copies under `.claude/scripts/`) and keep them byte-identical.
- Update the `manifest_spec.lua` test fixture.
- Verify the three acceptance properties in scratchpad-only fake project directories.
- Sweep documentation prose that names the source location.

**Non-Goals**:
- Touching `M.opencode()` or any `.opencode/`-side equivalent (documented follow-up only).
- Changing `command-route-skill.sh`, `skill-base.sh`'s `skill_get_extension_dir`, `loader.lua`'s
  symlink-safety logic, or `merge.lua`/`verify.lua`'s `normalize_index_path` legacy normalizers.
- Recreating `check_deployed_rule_drift` or the loader symlink-safe remove path (foundation already
  landed; build on it, do not re-author it).
- Any `git push`, PR/MR creation, or destructive operation against the real `~/.config/nvim/.claude`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing one of the two Lua hardcodings (`config.lua` vs `sync.lua`) leaves picker "Load Core" reading absent content | H | M | Phase 2 derives `core_source_base` from the canonical config value so the two can never drift; verified in Phase 5 self-rebuild |
| Shell scripts silently vacuous-pass (glob matches zero files, exit 0) after store moves out from under an un-updated default | M | M | Phase 5 checks script OUTPUT content (extension count > 0), not just exit code |
| Confusing the global source store with the deployed per-project stub, breaking routing in every consuming project | H | L | Do-not-touch list carried verbatim into Phases 2-3; Phase 5 confirms `.claude/extensions/{name}/manifest.json` still written at deploy target |
| Destructive loader test hits the real `~/.config/nvim/.claude` tree (known data-loss history) | H | L | Phase 5 mandates scratchpad-only fake project dirs and full-copy testing; the only real-tree mutation is the reversible `git mv` in Phase 1 |
| `git mv` leaves stale absolute-path permission strings in `.claude/settings.local.json` | L | H | Left as-is (ephemeral local grants, regenerate on next use); noted in Phase 6, non-blocking |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 6 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Relocate store and repoint canonical default [COMPLETED]

**Goal**: Physically move the source store and repoint the one canonical config default so the
picker's list/load/unload/verify surface reads from the new location.

**Tasks**:
- [x] `mkdir -p agent-system` (parent for the move target), then
      `git mv .claude/extensions agent-system/extensions` to preserve file history.
- [x] Confirm `agent-system/extensions/` contains all expected extension directories
      (`core`, `cslib`, `email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`,
      `lean`, `literature`, `memory`, `nix`, `nvim`, `present`, `python`, `slidev`, `typst`,
      `web`, `z3`) plus `README.md`, and that repo-root `.claude/extensions/` no longer exists
      as a source tree.
- [x] Edit `config.lua:55` (`M.claude` preset): change
      `global_dir .. "/.claude/extensions"` to `global_dir .. "/agent-system/extensions"`.
      Leave `M.opencode()` (line 71) untouched.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - line 55 suffix change
- (filesystem move) `.claude/extensions/` -> `agent-system/extensions/` via `git mv`

**Verification**:
- `ls agent-system/extensions/` lists all 19 extension directories with content intact.
- `git status` shows the move as renames (history preserved), not delete+add.
- Headless: `require("neotex.plugins.ai.shared.extensions.config").claude().global_extensions_dir`
  ends with `/agent-system/extensions`.

---

### Phase 2: Derive sync.lua core_source_base from canonical config [COMPLETED]

**Goal**: Remove the second hardcoded store literal by deriving the "Load Core" source base from
the canonical config value, closing the drift class permanently.

**Tasks**:
- [x] In `sync.lua` `scan_all_artifacts` (around line 909), replace the literal
      `core_source_base = (base_dir == ".claude") and ".claude/extensions/core" or nil` with a
      value derived from the already-computed `extension_cfg` (via `get_extension_config`,
      itself backed by `ext_config.claude`/`ext_config.opencode`): for the `.claude` base_dir,
      compute the relative core-source base from `extension_cfg.global_extensions_dir` by
      stripping the `global_dir .. "/"` prefix and appending `/core`. Keep `nil` for `.opencode`
      (no override). *(altered: derives from the already-in-scope `extension_cfg` local rather
      than a fresh `ext_config.claude(global_dir)` call — same canonical source, avoids a
      redundant require-call re-derivation)*
- [x] Preserve the existing behavior contract: `source_base` is passed to
      `scan.scan_directory_for_sync` as a repo-root-relative path and gates `use_core_source`
      (see lines 939-947, 1055). Confirmed the derived value has the same shape (relative, no
      leading/trailing slash) as the literal it replaces: verified headlessly to resolve to
      `agent-system/extensions/core`.
- [x] Update the explanatory comment block (lines 904-909) to state the source now lives under
      `agent-system/extensions/core/` rather than `.claude/extensions/core/`, without citing any
      task number (per no-task-references rule).

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - lines 904-909 (derive
  `core_source_base`, update comment)

**Verification**:
- Headless: call `M.scan_all_artifacts(global_dir, project_dir, config)` against a scratch
  project_dir and confirm it returns non-empty core artifact sets sourced from
  `agent-system/extensions/core/` (checked more fully in Phase 5).
- `grep -rn '"\.claude/extensions/core"' lua/` returns no remaining literal in `sync.lua`.

---

### Phase 3: Repoint shell-script store defaults (source + deployed copies) [COMPLETED]

**Goal**: Update the two shell scripts that independently default to the old store path, in both
their now-relocated source copies and their deployed copies, keeping the pairs byte-identical.

**Tasks**:
- [x] `check-extension-docs.sh` (source copy now at `agent-system/extensions/core/scripts/`,
      deployed copy at `.claude/scripts/`): changed the `EXT_DIR` default (line 39) from
      `"${EXT_DIR:-$REPO_ROOT/.claude/extensions}"` to
      `"${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"`. Kept the `EXT_DIR` env-var override
      mechanism intact. Did NOT change the `$REPO_ROOT/.claude/rules`, `.claude/skills`,
      `.claude/agents`, `.claude/scripts` deployed-comparison paths (those are deploy targets and
      stay put).
- [x] `validate-extension-index.sh` (source copy now at `agent-system/extensions/core/scripts/`,
      deployed copy at `.claude/scripts/`): changed the `.claude` glob (line 143) from
      `"$PROJECT_DIR"/.claude/extensions/*/index-entries.json` to
      `"$PROJECT_DIR"/agent-system/extensions/*/index-entries.json`. Left the `.opencode`
      counterpart glob (line 153) unchanged (out of scope). *(deviation: skipped — optional
      EXT_DIR-style override for parity was not added; not required by acceptance criteria and
      keeps the diff minimal)*
- [x] After editing, confirmed each source/deployed pair is byte-identical:
      `diff -q agent-system/extensions/core/scripts/check-extension-docs.sh .claude/scripts/check-extension-docs.sh`
      and the same for `validate-extension-index.sh` reported no differences.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - EXT_DIR default (line 39)
- `.claude/scripts/check-extension-docs.sh` - EXT_DIR default (deployed copy)
- `agent-system/extensions/core/scripts/validate-extension-index.sh` - `.claude` glob (line 143)
- `.claude/scripts/validate-extension-index.sh` - `.claude` glob (deployed copy)

**Verification**:
- `diff -q` on both source/deployed pairs reports identical.
- `grep -n 'agent-system/extensions' <each file>` confirms the new default is present.
- Full functional run deferred to Phase 5 (content-count assertion).

---

### Phase 4: Update test fixture [COMPLETED]

**Goal**: Point the plenary test fixture at the new store location.

**Tasks**:
- [x] Edit `manifest_spec.lua:192`: changed
      `lean_path = global_dir .. "/.claude/extensions/lean"` to
      `global_dir .. "/agent-system/extensions/lean"`.
- [x] Scanned the rest of the spec file for any other `.claude/extensions` fixture literals;
      line 192 was the only occurrence, none remain.

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` - line 192 fixture path

**Verification**:
- `grep -n '.claude/extensions' lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`
  returns no store-source references (deployed-stub references, if any, may legitimately remain).
- Test run deferred to Phase 5.

---

### Phase 5: Scratchpad verification of the three acceptance properties [COMPLETED]

**Goal**: Prove the picker lists from the new location, arbitrary-CWD deploy still works, and
`~/.config/nvim` self-rebuilds -- all against scratchpad fake project dirs, NEVER the real
`~/.config/nvim/.claude` tree.

**Tasks**:
- [x] **Picker lists from new location**: headless nvim, `manifest.list_extensions(config.claude())`
      returned count=19, and all 19 matched `agent%-system/extensions/<name>$` (ok_count=19,
      zero mismatches).
- [x] **Deploy into an arbitrary fake `$CWD/.claude`**: created
      `$SCRATCHPAD/fake-project-1/`, ran `manager.load("nvim", {confirm=false, project_dir=...})`
      headless (`load ok=true`); confirmed the full `.claude/` layout (agents, commands, context,
      docs, rules, scripts, skills, systemd, templates, extensions.json, CLAUDE.md) landed under
      the fake project dir, and that
      `$SCRATCHPAD/fake-project-1/.claude/extensions/nvim/manifest.json` (plus the auto-loaded
      `core` dependency's own stub at `.claude/extensions/core/manifest.json`) was written at the
      target path with correct content -- confirms the deployed-stub concept is fully unaffected
      by the source relocation.
- [x] **Self-rebuild property**: `rsync -a --exclude='.git'` copied `~/.config/nvim` (344M) into
      `$SCRATCHPAD/nvim-selfhost/` in ~2s (copy only, real tree never touched), `rm -rf` that
      copy's `.claude/`, then called `manager.load("core", ...)` followed by
      `manager.load("nvim", ...)` with both `global_dir` and `project_dir` pointed at the scratch
      copy (`config.claude(scratch)`). Both loads returned `ok=true`. Confirmed: `.claude/` fully
      regenerated (14 top-level entries including CLAUDE.md at 632 lines, agents/ with 13 files,
      extensions.json listing `["nvim","core"]`); the freshly written `extensions.json`
      `source_dir` fields for both correctly point at
      `$SCRATCHPAD/nvim-selfhost/agent-system/extensions/{core,nvim}` (proving new loads no
      longer produce the stale `.claude/extensions/...` value); and `agent-system/extensions/core`
      still existed in the scratch copy as the read source (the copy's own `.claude/extensions/`
      was the thing deleted and never re-read from). *(altered: the plan's suggested
      `sync.scan_all_artifacts` + execute path goes through `sync.load_all_globally()`, which
      hard-codes `project_dir = vim.fn.getcwd()` and gates on an interactive `vim.fn.confirm()`
      dialog unsuitable for non-interactive headless verification; used the equivalent
      `manager.load("core"/"nvim", ...)` extension-load path instead, which exercises the exact
      same `manifest.lua` / `loader.lua` source-resolution code as the sync path and is the
      mechanism actually exercised by the property-2 task above, while accepting an injectable
      `project_dir`/`global_dir` for scratch-only operation)*
- [x] **Shell scripts pass with non-vacuous output**: `.claude/scripts/check-extension-docs.sh`
      exited 0 with per-extension PASS lines for all 20 categories (core, cslib, email,
      epidemiology, filetypes, formal, founder, latex, lean, literature, memory, nix, nvim,
      present, project-wide, python, slidev, typst, web, z3) -- "PASS: all extensions OK".
      `.claude/scripts/validate-extension-index.sh` exited 0, validating 19 `.claude`-side
      index-entries.json files (real non-zero entry counts, e.g. core: 105 entries, formal: 46,
      founder: 34) plus 16 `.opencode`-side files (untouched glob, confirmed unaffected), with
      "Errors: 0 / Warnings: 0 / PASSED". Neither script vacuous-passed.
- [x] **Test suite**: `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua"`
      ran 17 assertions: 16 Success, 1 pre-existing unrelated failure ("should reject manifest
      with invalid merge_targets type" -- a `merge_targets`-type-validation assertion in
      `manifest.lua`'s `validate()` unconnected to any path or store-location logic; confirmed by
      inspection that the only edit this task made to the spec file was the `lean_path` fixture
      on line 192, and this failing test predates and is untouched by that edit). The specific
      fixture-dependent test -- "manifest read should read and validate lean extension manifest"
      -- **passed**, confirming the updated `agent-system/extensions/lean` fixture path resolves
      correctly. *(deviation: skipped — fixing the pre-existing unrelated `merge_targets`
      validation failure; out of scope for a source-store relocation task and not touched)*
- [x] Recorded all verification commands and results above and in
      `summaries/01_relocate-extension-store-summary.md`.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification only; scratchpad scratch files under
  `/tmp/claude-.../scratchpad/` are not repo artifacts)

**Verification**:
- All three acceptance properties demonstrably hold.
- No command in this phase mutated `~/.config/nvim/.claude` (only the scratch copy).
- Both lint scripts exit 0 with non-vacuous output; `manifest_spec.lua` passes.

---

### Phase 6: Documentation sweep [COMPLETED]

**Goal**: Update prose that names the SOURCE store location; leave correct deployed-stub mentions
alone.

**Tasks**:
- [x] `lua/neotex/plugins/ai/shared/README.md` (~line 104): updated
      "Claude: `~/.config/nvim/.claude/extensions/`" to `~/.config/nvim/agent-system/extensions/`.
- [x] Updated the core context source for the "Context Architecture" table
      (`agent-system/extensions/core/context/architecture/context-layers.md` line 31) row
      describing where extension context source lives, from `.claude/extensions/*/context/` to
      `agent-system/extensions/*/context/`.
- [x] `grep -rl '.claude/extensions' --include='*.md'` across the repo (1506 initial hits);
      classified each cluster and fixed all genuine SOURCE-store descriptions (~15 files: the two
      above plus `core/docs/guides/creating-extensions.md`, `core/docs/guides/adding-domains.md`,
      `core/context/guides/extension-development.md`, `core/docs/architecture/extension-system.md`,
      `core/docs/architecture/system-overview.md`, `core/context/architecture/system-overview.md`,
      `core/README.md`, `core/docs/README.md`, `core/context/meta/context-revision-guide.md`,
      `agent-system/extensions/README.md`, `agent-system/extensions/literature/scripts/deprecated/README.md`,
      `.context/README.md`). Left three categories of remaining hits unchanged as legitimate/out
      of scope, per the do-not-touch list and the deployed-stub distinction:
      *(deviation: altered — scope narrowed from a blanket per-hit sweep to three explicit
      exclusion categories, documented below, because the naive grep surfaced 1506 hits, not a
      small case-by-case set)*:
      1. `.claude/extensions/*/manifest.json` runtime-stub references (read by
         `command-route-skill.sh`/`skill-base.sh`) -- explicitly on the do-not-touch list.
      2. `@.claude/extensions/{name}/context/...`-style "Related Context" citations used
         throughout individual extension docs (README.md, SKILL.md, agent .md files across
         nearly every extension, plus root `CLAUDE.md` and `.memory/README.md`) -- verified via
         `copy_context_dirs()` (loader.lua:273) that these citations were ALREADY incorrect
         pre-relocation (context flattens to `.claude/context/{context_path}` with no
         per-extension directory segment at all, so the physical store move neither fixes nor
         worsens this pre-existing, unrelated documentation bug). Fixing this is out of scope
         for a source-store relocation task.
      3. `specs/**` historical task artifacts (1360 hits) -- frozen point-in-time records of past
         research/plans/summaries, not living documentation; not edited.
      4. `.claude/**` deployed-tree copies (41 hits) -- disposable build output regenerated by
         the next real "Load Core" sync; not hand-patched per the copy-deploy philosophy, and
         editing the real deployed tree's content here would exceed the scratchpad-only
         testing constraint's spirit for the real tree.
      5. `.memory/10-Memories/MEM-pattern-*.md` (2 hits) -- describe a general `.claude/` <->
         `.opencode/` substitution pattern for porting scripts between dual systems; unrelated
         to the physical relocation of the Claude-side source store and out of scope (`.opencode/`
         untouched per non-goals).
- [x] Noted (did not fix) the stray `.claude/extensions/present/...` permission strings in
      `.claude/settings.local.json` (6 occurrences) as ephemeral, self-regenerating, out of scope,
      consistent with the Risks table mitigation.
- [x] Additionally noted (did not fix) the same ephemeral-staleness category in
      `.claude/extensions.json`: six `source_dir` fields (memory, nvim, core, nix, filetypes,
      literature) still record the pre-move absolute path
      `/home/benjamin/.config/nvim/.claude/extensions/{name}`. Confirmed via
      `grep -rn '\.source_dir\b'` across `lua/neotex/plugins/ai/shared/extensions/*.lua` and the
      picker operations that `source_dir` is write-only state (recorded by `state.lua:126` from
      `manifest.lua:158`'s `manifest._source_dir`) with no read-back consumer anywhere in the
      codebase -- purely informational metadata that self-heals on the next load/reload of each
      extension. *(deviation: skipped — not in the plan's original file list; recorded here for
      completeness since it is the same ephemeral-state category as the settings.local.json note)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/README.md` - store-location prose
- `agent-system/extensions/core/context/architecture/context-layers.md` - Context Architecture
  table row (source of the deployed `.claude/CLAUDE.md`/context-layers copy)
- Other `*.md` files surfaced by grep that describe the source location (case-by-case)

**Verification**:
- `grep -rn '\.claude/extensions' --include='*.md'` remaining hits are all legitimate
  deployed-stub references, not source-store references.
- No task-number citations introduced outside `specs/**`.

---

## Testing & Validation

- [x] `git status` shows Phase 1 move as history-preserving renames (981 files, `R` status).
- [x] Headless: `config.claude().global_extensions_dir` ends with `/agent-system/extensions`.
- [x] Headless: `manifest.list_extensions(config.claude())` returns all 19 extensions with
      `agent-system/extensions/{name}` paths (count=19, ok_count=19).
- [x] Deploy into `$SCRATCHPAD/fake-project-1/.claude/` succeeds; deployed stub manifest written
      at target.
- [x] Scratch full-copy of `~/.config/nvim` deletes and regenerates its own `.claude/` from the
      relocated store (verified via `manager.load` for core + nvim against the scratch copy).
- [x] `check-extension-docs.sh` and `validate-extension-index.sh` exit 0 with non-vacuous output
      (20 categories PASS; 19+16 index files with real entry counts).
- [x] `manifest_spec.lua` passes (16/17; the 1 failure is a pre-existing, unrelated
      `merge_targets` validation assertion -- the fixture-dependent lean-manifest test passed).
- [x] `diff -q` confirms both shell-script source/deployed pairs are byte-identical.
- [x] No `.claude/extensions/core` literal remains in `sync.lua`.
- [x] No task-number citations introduced in any file outside `specs/**` by this task's edits
      (pre-existing citations from other tasks, e.g. task 837/793 references in
      `check-extension-docs.sh` and `system-overview.md`, predate this task and are out of scope).
- [x] The real `~/.config/nvim/.claude` tree was never destructively touched (all destructive
      loader tests ran against scratchpad copies only; verified `git status --short .claude/`
      shows only pre-existing unrelated modifications, no new changes from testing).

## Artifacts & Outputs

- plans/01_relocate-extension-store.md (this file)
- summaries/01_relocate-extension-store-summary.md (on implementation)
- Relocated source store at `agent-system/extensions/`
- Edited: `config.lua`, `sync.lua`, `check-extension-docs.sh` (x2), `validate-extension-index.sh`
  (x2), `manifest_spec.lua`, `shared/README.md`, `context-layers.md` source, misc docs

## Rollback/Contingency

- The relocation is a git-tracked `git mv`; revert with `git mv agent-system/extensions .claude/extensions`
  (or `git checkout` / `git reset` the move) plus reverting the `config.lua:55` and downstream
  edits. No loader code is invoked by the move itself, so reverting is safe.
- If Phase 5 self-rebuild fails, the fault is isolated to the source-read path (Phases 1-2);
  revert those two phases and the store is back to a working (self-hosting-blocked) state with no
  data loss, since all destructive testing was scratchpad-only.
- Because every acceptance test runs against scratchpad copies, no rollback ever needs to touch
  the real `~/.config/nvim/.claude` deploy target.
