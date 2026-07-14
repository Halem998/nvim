# Implementation Plan: Relocate Extension Source Store Out of .claude/

- **Task**: 863 - Relocate extension source store out of .claude/
- **Status**: [NOT STARTED]
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

### Phase 3: Repoint shell-script store defaults (source + deployed copies) [NOT STARTED]

**Goal**: Update the two shell scripts that independently default to the old store path, in both
their now-relocated source copies and their deployed copies, keeping the pairs byte-identical.

**Tasks**:
- [ ] `check-extension-docs.sh` (source copy now at `agent-system/extensions/core/scripts/`,
      deployed copy at `.claude/scripts/`): change the `EXT_DIR` default (line 39) from
      `"${EXT_DIR:-$REPO_ROOT/.claude/extensions}"` to
      `"${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"`. Keep the `EXT_DIR` env-var override
      mechanism intact. Do NOT change the `$REPO_ROOT/.claude/rules`, `.claude/skills`,
      `.claude/agents`, `.claude/scripts` deployed-comparison paths (those are deploy targets and
      stay put).
- [ ] `validate-extension-index.sh` (source copy now at `agent-system/extensions/core/scripts/`,
      deployed copy at `.claude/scripts/`): change the `.claude` glob (line 143) from
      `"$PROJECT_DIR"/.claude/extensions/*/index-entries.json` to
      `"$PROJECT_DIR"/agent-system/extensions/*/index-entries.json`. Leave the `.opencode`
      counterpart glob (line 153) unchanged (out of scope). Optionally add an `EXT_DIR`-style
      override for parity with `check-extension-docs.sh`.
- [ ] After editing, ensure each source/deployed pair is byte-identical:
      `diff -q agent-system/extensions/core/scripts/check-extension-docs.sh .claude/scripts/check-extension-docs.sh`
      and the same for `validate-extension-index.sh` must report no differences.

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

### Phase 4: Update test fixture [NOT STARTED]

**Goal**: Point the plenary test fixture at the new store location.

**Tasks**:
- [ ] Edit `manifest_spec.lua:192`: change
      `lean_path = global_dir .. "/.claude/extensions/lean"` to
      `global_dir .. "/agent-system/extensions/lean"`.
- [ ] Scan the rest of the spec file for any other `.claude/extensions` fixture literals and
      update them consistently.

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` - line 192 fixture path

**Verification**:
- `grep -n '.claude/extensions' lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua`
  returns no store-source references (deployed-stub references, if any, may legitimately remain).
- Test run deferred to Phase 5.

---

### Phase 5: Scratchpad verification of the three acceptance properties [NOT STARTED]

**Goal**: Prove the picker lists from the new location, arbitrary-CWD deploy still works, and
`~/.config/nvim` self-rebuilds -- all against scratchpad fake project dirs, NEVER the real
`~/.config/nvim/.claude` tree.

**Tasks**:
- [ ] **Picker lists from new location**: in a headless nvim instance, call
      `manifest.list_extensions(config.claude())` and confirm all 19 extensions return with
      `path` fields under `agent-system/extensions/{name}`.
- [ ] **Deploy into an arbitrary fake `$CWD/.claude`**: create `$SCRATCHPAD/fake-project-1/`,
      run `manager.load("nvim", {project_dir = "$SCRATCHPAD/fake-project-1"})` headless, and
      confirm files land under `$SCRATCHPAD/fake-project-1/.claude/` and that
      `$SCRATCHPAD/fake-project-1/.claude/extensions/nvim/manifest.json` (the deployed stub) is
      written at the TARGET path (confirms the deployed-stub concept is unaffected).
- [ ] **Self-rebuild property**: make a FULL COPY of `~/.config/nvim` into
      `$SCRATCHPAD/nvim-selfhost/` (copy, never operate on the real tree), `rm -rf` that copy's
      `.claude/`, then run the picker "Load Core" path (`sync.M.scan_all_artifacts` + execute)
      plus one representative extension load against `project_dir = $SCRATCHPAD/nvim-selfhost`,
      and confirm `.claude/` is regenerated with core + the extension, with source reads coming
      from `agent-system/extensions/` (not the just-deleted `.claude/extensions/`).
- [ ] **Shell scripts pass with non-vacuous output**: run
      `.claude/scripts/check-extension-docs.sh` and `.claude/scripts/validate-extension-index.sh`
      against the real repo (read-only lint, safe) and confirm exit 0 AND that their output
      reflects a non-zero extension count (catch the silent vacuous-pass failure mode).
- [ ] **Test suite**: run the `manifest_spec.lua` plenary/busted harness and confirm it passes
      with the updated fixture.
- [ ] Record all verification commands and results in the implementation summary.

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

### Phase 6: Documentation sweep [NOT STARTED]

**Goal**: Update prose that names the SOURCE store location; leave correct deployed-stub mentions
alone.

**Tasks**:
- [ ] `lua/neotex/plugins/ai/shared/README.md` (~line 104): update
      "Claude: `~/.config/nvim/.claude/extensions/`" to the new store location.
- [ ] Update the core context source for the "Context Architecture" table (the source under
      `agent-system/extensions/core/context/architecture/context-layers.md`) row describing where
      extension context source lives; verify against both source and any deployed copy via grep.
- [ ] `grep -rl '.claude/extensions' --include='*.md'` across the repo; for each hit, determine
      whether it describes the SOURCE store (update to `agent-system/extensions`) or the correct
      deployed per-project stub (leave unchanged). Do NOT introduce any task-number citation in
      any file outside `specs/**`.
- [ ] Note (do not fix) the stray `.claude/extensions/present/...` permission strings in
      `.claude/settings.local.json` as ephemeral, self-regenerating, out of scope.

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

- [ ] `git status` shows Phase 1 move as history-preserving renames.
- [ ] Headless: `config.claude().global_extensions_dir` ends with `/agent-system/extensions`.
- [ ] Headless: `manifest.list_extensions(config.claude())` returns all 19 extensions with
      `agent-system/extensions/{name}` paths.
- [ ] Deploy into `$SCRATCHPAD/fake-project-1/.claude/` succeeds; deployed stub manifest written
      at target.
- [ ] Scratch full-copy of `~/.config/nvim` deletes and regenerates its own `.claude/` from the
      relocated store.
- [ ] `check-extension-docs.sh` and `validate-extension-index.sh` exit 0 with non-vacuous output.
- [ ] `manifest_spec.lua` passes.
- [ ] `diff -q` confirms both shell-script source/deployed pairs are byte-identical.
- [ ] No `.claude/extensions/core` literal remains in `sync.lua`.
- [ ] No task-number citations in any file outside `specs/**`.
- [ ] The real `~/.config/nvim/.claude` tree was never destructively touched.

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
