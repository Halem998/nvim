# Research Report: Relocate Extension Source Store Out of .claude/

**Task**: 863 - Relocate extension source store out of .claude/
**Started**: 2026-07-14T22:58:04Z
**Completed**: 2026-07-14T23:20:00Z
**Effort**: Medium (single config default + 4 code call sites + 2 shell scripts + 1 test + docs)
**Dependencies**: None (this is the unlocking/foundation change)
**Sources/Inputs**: Codebase read of shared/extensions/*.lua, claude/commands/picker/*.lua,
core scripts, existing architecture docs (extension-deploy-modes.md, handoff-schema.md)
**Artifacts**: this report
**Standards**: report-format.md, no-task-references-in-deliverables.md (honored below)

## Executive Summary

- The global extension source store is read from exactly **one canonical factory function**:
  `M.claude(global_dir)` in `lua/neotex/plugins/ai/shared/extensions/config.lua:48-59`, which
  hardcodes `global_extensions_dir = global_dir .. "/.claude/extensions"` (line 55). All
  load/unload/list/verify logic in `init.lua`, `manifest.lua`, and `verify.lua` consumes this
  single config field — no other code computes the store path independently for the
  load/unload/list surface.
- However, **one additional call site duplicates the literal string** outside this factory:
  `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:909`
  (`core_source_base = ".claude/extensions/core"`), used by the picker's "Load Core Agent
  System" sync operation (`<leader>al`). This must be updated in lockstep or the picker will
  read stale/wrong content for the core rebuild path even after `config.lua` is fixed.
- Two **shell scripts** (deployed copies of scripts whose source lives inside the store itself,
  at `.claude/extensions/core/scripts/`) independently resolve the store location relative to
  repo root rather than through any shared config: `check-extension-docs.sh` (default
  `EXT_DIR="$REPO_ROOT/.claude/extensions"`, overridable via `EXT_DIR` env var) and
  `validate-extension-index.sh` (hardcoded `"$PROJECT_DIR"/.claude/extensions/*/index-entries.json`
  and the `.opencode` counterpart, no override). Both must be repointed or they will silently
  find nothing (vacuous pass) once the store moves.
- One **test file** hardcodes the store path: `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua:192`
  (`global_dir .. "/.claude/extensions/lean"`).
- The **`.opencode/` preset has the identical architectural flaw** (`M.opencode(global_dir)` at
  config.lua:64-75, `global_extensions_dir = global_dir .. "/.opencode/extensions"`), and
  `.opencode/extensions/` is a genuinely independent 11MB source tree (not derived from
  `.claude/extensions/`, content differs per-file). This task's explicit scope is `.claude/` only
  — the `.opencode/` mirror bug should be logged as a documented follow-up, not silently rolled
  into this task's diff.
- Two lines in `merge.lua`/`verify.lua` match the literal `^%.claude/extensions/[^/]+/context/`
  string, but this is a **legacy-format normalizer** for path values *inside* authored
  `index-entries.json` content (guarding against extension authors who mistakenly wrote a
  deploy-shaped prefix into their own JSON), not a filesystem lookup — it is unaffected by the
  physical relocation and requires no change.
- `command-route-skill.sh` and `skill-base.sh`'s `skill_get_extension_dir` both read
  `.claude/extensions/<name>` **relative to the current working directory at runtime** — this is
  the *deployed*, per-project artifact (manifest.json only, written by `loader.lua`'s
  `copy_manifest`), not the global source store. These are unaffected and must NOT be changed.
- Recommended new store location: **`~/.config/nvim/agent-system/extensions/`** (non-dot-prefixed
  top-level directory, sibling to `lua/`, `specs/`, `.claude/`, `.opencode/`). Copy-deploy only;
  no symlinks are introduced anywhere in this change.

## Context & Scope

Task 863 is the "unlocking" change in a sequence whose end state is: `.claude/` in any working
directory is a 100%-disposable build artifact (`.claude/ == deploy(store, selection)`), with one
global source store living entirely outside any deployed `.claude/` tree. Today every *other*
project already satisfies this invariant (source lives at `~/.config/nvim/.claude/extensions/`,
target lives at `$CWD/.claude/`, and those are different trees for any `$CWD != ~/.config/nvim`).
The one exception is `~/.config/nvim` itself, where source and target coincide, which is why the
config-repo's own `.claude/` cannot currently be deleted and rebuilt via the picker.

This research traces every place in the codebase that resolves the global store's filesystem
location, distinguishes those from the *unrelated* deployed-per-project `.claude/extensions/`
artifact (which is not source and must NOT move), and evaluates a target relocation path.

## Findings

### The two distinct ".claude/extensions/" concepts (critical distinction)

1. **Global source store** (what must move): `~/.config/nvim/.claude/extensions/{name}/` — full
   authored content for every available extension (`agents/`, `skills/`, `commands/`, `rules/`,
   `context/`, `scripts/`, `manifest.json`, `EXTENSION.md`/`merge-sources/claudemd.md` for core,
   `index-entries.json`, etc.). Verified present today: `core`, `cslib`, `email`, `epidemiology`,
   `filetypes`, `formal`, `founder`, `latex`, `lean`, `literature`, `memory`, `nix`, `nvim`,
   `present`, `python`, `slidev`, `typst`, `web`, `z3` (14MB total). This is what
   `manifest.lua`'s `M.list_extensions(config)` scans via `config.global_extensions_dir`.

2. **Deployed per-project extension stub** (must NOT move, unrelated to this task): when an
   extension is loaded into *any* project (including `~/.config/nvim` itself), `init.lua`'s
   `manager.load` calls `loader_mod.copy_manifest(...)` which writes only
   `{project_dir}/.claude/extensions/{name}/manifest.json` — a thin per-project record used at
   runtime by `command-route-skill.sh` (routing table lookups, glob
   `.claude/extensions/*/manifest.json` relative to `$PWD`) and `skill-base.sh`'s
   `skill_get_extension_dir` (constructs `.claude/extensions/${ext_name}` relative to `$PWD` for
   lifecycle-hook script resolution). Both of these read the *deployed* artifact in whatever
   project they run in and are completely decoupled from where the global source lives. No
   change needed to either script.

Confusing these two is the main risk in this task: a change that also perturbs the deployed
per-project stub path would break routing (`command-route-skill.sh`) in every consuming project,
which is explicitly out of scope and must be avoided.

### Complete inventory of literal-path references requiring change

| # | File | Line(s) | What it does | Action required |
|---|------|---------|---------------|------------------|
| 1 | `lua/neotex/plugins/ai/shared/extensions/config.lua` | 55 | `M.claude()` preset: canonical `global_extensions_dir` default | **Change the literal suffix** from `/.claude/extensions` to the new store path |
| 2 | `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | 906-909 | `scan_all_artifacts`: hardcodes `core_source_base = ".claude/extensions/core"` for the "Load Core" sync/rebuild path (`<leader>al`), used as `source_base_dir` override in `scan.scan_directory_for_sync` | **Change the literal** to match the new store's `core/` subpath, or (preferred) derive it from `ext_config.claude(global_dir).global_extensions_dir .. "/core"` instead of a second hardcoded string, to eliminate future drift between the two spots |
| 3 | `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua` | 192 | Plenary test: `lean_path = global_dir .. "/.claude/extensions/lean"` | Update test fixture path to match new location |
| 4 | `.claude/extensions/core/scripts/check-extension-docs.sh` (source; deployed copy at `.claude/scripts/check-extension-docs.sh`) | 39 | Doc-lint default: `EXT_DIR="${EXT_DIR:-$REPO_ROOT/.claude/extensions}"`; also drives `check_deployed_rule_drift` (line 185) and `check_deployed_script_drift`-style comparisons, all of which read extension-source files under `$EXT_DIR` | Update the **default** value to the new store path; keep the `EXT_DIR` env-var override mechanism as-is (already a clean escape hatch) |
| 5 | `.claude/extensions/core/scripts/validate-extension-index.sh` (source; deployed copy at `.claude/scripts/validate-extension-index.sh`) | 143, ~152 | Iterates `"$PROJECT_DIR"/.claude/extensions/*/index-entries.json` and the `.opencode` counterpart, where `PROJECT_DIR="${SCRIPT_DIR}/../.."` (repo root when run from a deployed `.claude/scripts/`) | Repoint the `.claude` glob to the new store path (no existing override; consider adding an `EXT_DIR`-style override for parity with script #4) |
| 6 | `lua/neotex/plugins/ai/shared/README.md` | ~104 | Documentation: "Claude: `~/.config/nvim/.claude/extensions/`" | Update prose (non-functional, but stale docs mislead future contributors) |
| 7 | `.claude/extensions/core/context/architecture/context-layers.md` (source of the deployed `.claude/CLAUDE.md` "Context Architecture" table row `Extensions \| .claude/extensions/*/context/ \| ...`) | n/a (not directly opened this pass; located via grep of the *deployed* copy) | Documentation table describing where extension context source lives | Update table row to new location during implementation; verify via grep of both source and deployed copies |
| 8 | `.claude/extensions/README.md` | n/a | Uses only *relative* `extensions/{name}/...` paths (no absolute literal) | No change required — already location-agnostic |

Several other files surfaced by a repo-wide grep for `.claude/extensions` (≈50 hits across
`.claude/docs/`, `.claude/context/`, `.memory/`, `.claude/scripts/*.sh`, `CLAUDE.md`) are
**prose mentions inside documentation, not path-resolution code** (e.g. examples like
`bash .claude/scripts/uninstall-extension.sh .claude/extensions/z3` in that script's own usage
comment refer to the *deployed* per-project extensions dir, which is correct and unchanged).
These should be swept for accuracy during implementation but do not affect functional
correctness of the relocation and can be handled as a documentation-cleanup pass rather than a
blocking dependency.

`.claude/settings.local.json` also contains several stray absolute-path permission-rule strings
referencing `.claude/extensions/present/...` — these are local, ephemeral Claude Code permission
grants (not checked into any deploy contract) and are low-priority; they will simply stop
matching after the move and can be regenerated on next use, no explicit fix required.

### Why `config.lua` is the right single choke point (mostly)

`M.claude(global_dir)` is consumed by exactly one code path for the load/unload/list/verify
surface: `get_extension_config(base_dir, global_dir)` in `sync.lua` and direct
`shared_config.claude(global_dir)` calls in `claude/extensions/config.lua` and
`claude/commands/picker.lua`. Everything downstream (`manifest.lua:list_extensions`,
`manifest.lua:get_extension`, `init.lua`'s entire `manager.load/unload/reload/verify`,
`manifest.lua:aggregate_extension_artifacts`, `manifest.lua:get_core_provides`) reads
`config.global_extensions_dir` as an opaque string — none of them reconstruct the path from
`global_dir` independently. This is good news: fixing the one string in `config.lua:55` fixes
the entire picker "list/load/unload extension" surface (`<leader>ac` presumably, or whichever
keymap opens the extension picker) in one place.

The **one exception** is `sync.lua:909`'s `core_source_base`, which exists because "Load Core
Agent System" (`<leader>al`, full rebuild of core artifacts) reads core's agents/commands/
rules/skills not from `{global_dir}/.claude/{subdir}` (the pre-migration layout) but from
`{global_dir}/.claude/extensions/core/{subdir}` (the post-migration layout, per the comment at
lines 906-908: "core artifact categories ... are now physically located in extensions/core/
after the Phase 2 migration"). This is a second, independent hardcoding of the same underlying
fact and must move in lockstep with `config.lua`.

A separate, unrelated `global_source_dir` concept (`lua/neotex/plugins/ai/claude/config.lua:41`,
`lua/neotex/plugins/ai/shared/picker/config.lua:49/71/90`, and `scan.lua`'s `M.get_global_dir()`)
always resolves to the *repo root* (`~/.config/nvim`), not the extensions subpath — this is
correct today and needs no change; only the extensions-specific suffix appended on top of it
does.

### Candidate relocation targets evaluated

| Candidate | Assessment |
|-----------|------------|
| `~/.config/nvim/agent-system/extensions/` (task's suggestion) | **Recommended.** Non-dot-prefixed, so it reads as hand-authored content (consistent with `lua/`, `after/`, `specs/`) rather than a tool-owned cache (consistent with dot-prefixed `.claude/`, `.opencode/`, `.memory/`, `.context/`). Clearly namespaced against a future `.opencode/extensions/` relocation (`agent-system/opencode-extensions/` would not collide). No existing top-level directory of this name. |
| `~/.config/nvim/extensions/` (bare, no `agent-system/` wrapper) | Rejected: ambiguous in a Neovim config repo, where "extensions" could be misread as referring to Neovim/lazy.nvim plugin extensions rather than the AI agent system's domain extensions. |
| `~/.config/nvim/.agent-system/extensions/` (dot-prefixed) | Rejected: this content is meant to be directly hand-edited by the user/agents when authoring new domain extensions (per `.claude/extensions/README.md`'s "Creating New Extensions" workflow) — dot-prefixing signals "generated/tool-owned," which is the opposite of the intended semantics post-move. |
| `~/.config/nvim/store/extensions/` | Workable but less self-documenting than `agent-system/` about *what* the store belongs to. |

**Recommendation**: `~/.config/nvim/agent-system/extensions/`. The `.claude/` (and, later,
`.opencode/`) presets under it, e.g. `~/.config/nvim/agent-system/extensions/` for Claude,
potentially `~/.config/nvim/agent-system/opencode-extensions/` if/when the `.opencode` mirror
bug is fixed in a follow-up.

### `.opencode/` mirror bug (explicitly out of scope, documented for awareness)

`M.opencode(global_dir)` (config.lua:64-75) has the structurally identical flaw:
`global_extensions_dir = global_dir .. "/.opencode/extensions"`, and
`~/.config/nvim/.opencode/extensions/` is confirmed to be a real, independently-authored 11MB
source tree (e.g. `.opencode/extensions/core/agents/*.md` differ byte-for-byte from
`.claude/extensions/core/agents/*.md` — these are not shared/derived content). The task
description and file_scope name only `.claude/`; this report does not recommend folding the
`.opencode` fix into this task's diff, since doing so doubles the surface area and testing matrix
for what is meant to be a narrowly-scoped unlocking change. Recommend a follow-up task once this
one has landed and proven itself, applying the identical pattern to
`M.opencode()` and any `.opencode`-side equivalent of `sync.lua`'s hardcoded `core_source_base`.

### Foundation already landed (must build on, not recreate)

- `check_deployed_rule_drift` (in `check-extension-docs.sh`, both the deployed copy at
  `.claude/scripts/` and the source copy at `.claude/extensions/core/scripts/`) compares
  `$REPO_ROOT/.claude/rules/$r` (deployed, stays put) against `$ext_path/rules/$r` where
  `ext_path` is derived from `$EXT_DIR/*/` (source store — must move). This function's *logic*
  needs zero changes; only `EXT_DIR`'s default needs to move.
- The symlink-safe remove path in `loader.lua` (`find_symlinked_ancestor`,
  `M.remove_installed_files`'s `getftype()` checks, documented exhaustively in
  `.claude/context/project/neovim/domain/extension-deploy-modes.md`) operates entirely on
  *deployed target* paths (`target_dir`, i.e. `$CWD/.claude/...`) and the ownership rule between
  the copy engine and `install-extension.sh`'s symlink farm. None of this logic references the
  global source store's location at all — it is fully orthogonal to this relocation and requires
  no changes. Verification of this task should include a regression check that
  `extension-deploy-modes.md`'s documented symlink-ownership invariants still hold post-move
  (they should, trivially, since the source-store path never appears in that code path).

## Recommendations

1. **Physical move**: `git mv .claude/extensions agent-system/extensions` (preserves file
   history; a plain filesystem move would not). Verify no other content lives inside
   `.claude/extensions/` that is actually deployed *state* rather than source (spot-checked: only
   `manifest.json` stubs are ever written back into a deployed project's
   `.claude/extensions/{name}/`, and those are always in a *different* tree — `$CWD/.claude/`,
   not `~/.config/nvim/.claude/` — except for the self-hosting case this task fixes).
2. **Single-string fix in `config.lua:55`**: change
   `global_dir .. "/.claude/extensions"` to `global_dir .. "/agent-system/extensions"`. Leave
   `M.opencode()` untouched (out of scope, see above).
3. **De-duplicate `sync.lua`'s `core_source_base`**: rather than hand-editing the second literal
   to match, refactor it to derive from `ext_config.claude(global_dir).global_extensions_dir`
   (already required via `local ext_config = require(...)` at the top of the file) plus
   `"/core"`, so the two spots can never drift again. This is a small, low-risk refactor and
   directly serves the "must not recreate the drift bug" mandate implicit in this sequence's
   design.
4. **Repoint the two shell scripts**: update `EXT_DIR` default in `check-extension-docs.sh` and
   the hardcoded glob in `validate-extension-index.sh` to
   `$REPO_ROOT/agent-system/extensions`. Both scripts already resolve `REPO_ROOT`/`PROJECT_DIR`
   relative to the deployed script's own location, so no further plumbing is needed — only the
   suffix changes. Do this in **both** the source copy (`.claude/extensions/core/scripts/`, now
   `agent-system/extensions/core/scripts/` post-move) and the deployed copy
   (`.claude/scripts/`), matching the existing dual-write pattern used by prior work on this
   same drift-check machinery (evidenced by the sibling completed task's handoff showing both
   copies were edited together, verified byte-identical via `diff -q`).
5. **Update the test fixture**: `manifest_spec.lua:192`'s `lean_path`.
6. **Documentation sweep**: `shared/README.md`, the core context source for the "Context
   Architecture" table, and any other prose mentions surfaced by
   `grep -rl '.claude/extensions' --include='*.md'` that describe the *source* location (as
   opposed to correctly-unchanged mentions of the deployed per-project stub). This can be a
   lower-priority final phase since it does not affect runtime correctness.
7. **Do not touch**: `command-route-skill.sh`, `skill-base.sh`'s `skill_get_extension_dir`,
   `loader.lua`'s symlink-safety logic, `merge.lua`/`verify.lua`'s `normalize_index_path` legacy
   string normalizers — all confirmed orthogonal to the store's physical location.

## Verification Plan

All destructive/mutating verification must run against **fake project directories under the
scratchpad**, never against the real `~/.config/nvim/.claude/` tree (per this task's explicit
constraint and the documented history of a live data-loss bug in this loader).

1. **Store relocation sanity**: after `git mv`, confirm
   `ls ~/.config/nvim/agent-system/extensions/` shows all 19 extension directories with content
   intact (`diff -rq` against a pre-move backup or git stash).
2. **Picker lists from new location**: in a headless nvim instance,
   `require("neotex.plugins.ai.shared.extensions.manifest").list_extensions(require("neotex.plugins.ai.shared.extensions.config").claude())`
   should return all 19 extensions with correct `path` fields pointing at
   `agent-system/extensions/{name}`.
3. **Deploy into an arbitrary fake `$CWD/.claude`**: create
   `$SCRATCHPAD/fake-project-1/`, run `manager.load("nvim", {project_dir = fake_project_1})` via
   a headless nvim `-c "lua ..."` invocation, and confirm files land under
   `$SCRATCHPAD/fake-project-1/.claude/` exactly as before (this exercises the deploy TARGET
   side, which must be completely unaffected by the SOURCE relocation).
4. **`~/.config/nvim` self-rebuild** (the actual unlocking property): in the scratchpad, create a
   **full copy** of `~/.config/nvim` (not the real tree — copy it), `rm -rf` its `.claude/`
   inside that scratch copy, then run the picker's "Load Core Agent System" (`sync.lua`'s
   `scan_all_artifacts`/related) plus a representative extension load against that scratch
   copy's `project_dir`, and confirm `.claude/` is fully regenerated with core + at least one
   extension, with **no orphaned files and no content sourced from inside the regenerated
   `.claude/` itself** (i.e., confirm the source read path was `agent-system/extensions/`, not
   the just-deleted-and-recreated `.claude/extensions/`).
5. **`check-extension-docs.sh` / `validate-extension-index.sh` still pass**: run both against the
   real repo post-move (these are read-only lint scripts, safe to run for real) and confirm exit
   code 0 / no regressions relative to the pre-move baseline output.
6. **`command-route-skill.sh` / `skill-base.sh` unaffected**: spot-check by loading one extension
   into a scratch fake project and confirming `.claude/extensions/{name}/manifest.json` is still
   written at the deployed (target) path, and that `command-route-skill.sh` run from inside that
   fake project still resolves routing correctly.
7. **`manifest_spec.lua` test suite passes** after the fixture path update (run via whatever
   plenary/busted harness this repo uses for `*_spec.lua` files).

## Risks & Mitigations

- **Risk**: missing one of the two hardcoded-string call sites (`config.lua` vs `sync.lua`)
  leaves the picker's "Load Core" path silently reading stale/absent content.
  **Mitigation**: the de-duplication refactor in Recommendation 3 converts this from "two things
  to remember" into "one thing to remember," permanently closing this class of drift.
- **Risk**: shell scripts' hardcoded defaults silently produce a vacuous pass (glob matches zero
  files, loop body never runs, script exits 0) rather than a loud failure when the store moves
  out from under an un-updated default.
  **Mitigation**: verification step 5 above explicitly checks the *content* of the scripts'
  output (extension count > 0), not just exit code, to catch a false-positive vacuous pass.
- **Risk**: confusing the global source store with the deployed per-project stub during
  implementation, causing an edit to `command-route-skill.sh` or `skill-base.sh` that breaks
  routing in every consuming project.
  **Mitigation**: this report's explicit "two distinct concepts" section and the "do not touch"
  list in Recommendations should be carried into the implementation plan verbatim.
- **Risk**: testing against the real `~/.config/nvim/.claude/` tree given this loader's known
  data-loss history.
  **Mitigation**: verification plan mandates scratchpad-only fake project dirs and full-copy
  testing for the self-rebuild scenario; no step in this plan touches the real tree destructively
  except the one-time, git-tracked `git mv` of the source store itself (which is reversible via
  git and does not invoke any loader code).

## Context Extension Recommendations

None — this is infrastructure/meta work internal to the agent system's own extension mechanism,
not a Neovim plugin/keymap/LSP topic that the existing `project/neovim/domain/*` context files
are meant to cover. No context gap identified for the neovim context library.
