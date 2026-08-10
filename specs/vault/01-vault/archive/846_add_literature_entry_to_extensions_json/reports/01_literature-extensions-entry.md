# Research Report: Task #846

**Task**: 846 - Add the missing `literature` entry to `.claude/extensions.json`
**Started**: 2026-07-11T00:30:00Z
**Completed**: 2026-07-11T00:57:33Z
**Effort**: research only
**Dependencies**: task #844 (deferred this deliberately), task #841 (drift-guard)
**Sources/Inputs**:
- `.claude/extensions.json` (current state, 4 entries: core/nix/memory/nvim)
- `.claude/extensions/literature/manifest.json`, `EXTENSION.md`, `README.md`
- `lua/neotex/plugins/ai/shared/extensions/{state,loader,init,manifest,config}.lua`
- `.claude/context/index.json`, `.claude/CLAUDE.md`
- Filesystem inspection of deployed `.claude/{agents,commands,skills,scripts,context}` literature artifacts
- `bash .claude/scripts/check-extension-docs.sh` (baseline run)
- `specs/844_finish_or_defer_zotero_cite_install/.orchestrator-handoff.json` and its README addendum
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The `extensions.json` entry is cosmetic bookkeeping for the Neovim-side extension-loader/picker, not load-bearing for the Claude Code commands/skills themselves.** `/literature`, `/cite`, `skill-literature`, `skill-cite`, `literature-agent`, and the deployed scripts all work today purely because Claude Code reads files directly out of `.claude/`; none of that runtime path consults `extensions.json`. The Lua loader (`state.lua`/`init.lua`) is a separate, human-driven subsystem (the extension picker) that happens to use the same file as its own state ledger.
- **However, the missing entry is not harmless to leave alone forever**: because `state_mod.is_loaded(state, "literature")` reads `false`, the Neovim extension picker currently lists literature as `"inactive"` and offers a **"Load"** action. If a human ever clicked it, `manager.load("literature")` would: (a) auto-cascade-load the undeclared `"filetypes"` dependency, (b) copy the 7 currently-**undeployed** zotero scripts into `.claude/scripts/`, and (c) silently collapse 3 existing **symlinks** (`.claude/agents/literature-agent.md`, `.claude/commands/literature.md`, `.claude/skills/skill-literature`) into literal file copies. None of that is destructive, but it is a large, surprising diff nobody asked for. Adding a correct `status: "active"` entry closes off this accidental trigger.
- **The deployed literature footprint is a mixed bag**, not the clean byte-for-byte deploy the task description assumes: 3 artifacts are **symlinks** into `.claude/extensions/literature/...` (not copies), 7 of the 25 scripts declared in `manifest.json.provides.scripts` are **not deployed at all**, and 2 scripts exist in `.claude/scripts/` (`zotero-resolve-pdf.sh`, `.zotero-title-sim.py`) that are **not declared** in the manifest. This was already known and documented by task #844 in `.claude/extensions/literature/README.md` (lines 154-201) as an intentional partial-deploy with a named follow-up: "Proper registration of the literature extension via the extension-loader flow is a named follow-up, not part of this task's scope."
- **Recommendation**: add the entry with the standard 8-field schema, `status: "active"`, correct `version`/`source_dir`, and **empty `installed_files`/`installed_dirs`/`merged_sections`/`data_skeleton_files`**. Do not fabricate a file manifest — the loader never actually performed this deploy, so claiming ownership of specific files risks a future `unload()`/`reload()` deleting real (partially symlinked) files that the loader didn't create. An empty-ownership entry is `is_loaded() == true` (closes the picker's "Load" trap) while making `unload()`'s file-removal step a safe no-op if ever triggered.
- `check-extension-docs.sh` never reads `extensions.json` (confirmed by `grep`) and already exits 0 with `literature: PASS` today, so this edit cannot regress it either way.

## Context & Scope

Task #844 explicitly declined to add this entry ("that file's `merged_sections` metadata is
loader-owned state, and hand-authoring it risks introducing the exact kind of drift this task is
closing") and instead documented the gap in `.claude/extensions/literature/README.md`. Task #846
re-opens this with instructions to research the *exact* schema and loader consumption semantics
before writing anything, rather than guessing. This report is research-only; no files were
modified except the required `.return-meta.json` / handoff bookkeeping.

## Findings

### Codebase Patterns

#### 1. Exact schema of existing `extensions.json` entries

`.claude/extensions.json` top level:
```json
{ "version": "1.0.0", "extensions": { "<name>": { ...entry... } } }
```

Every one of the 4 existing entries (`core`, `nix`, `memory`, `nvim`) has **exactly these 8
fields**, produced by `state.lua`'s `M.mark_loaded()` (lines 122-134):

| Field | Type | Source |
|---|---|---|
| `version` | string | `manifest.version` |
| `loaded_at` | string, `os.date("!%Y-%m-%dT%H:%M:%SZ")` | wall-clock at load time |
| `source_dir` | string, absolute path | `manifest._source_dir` (set in `manifest.lua` `M.read()`), e.g. `/home/benjamin/.config/nvim/.claude/extensions/nix` |
| `installed_files` | array of strings, paths **relative to project root** (e.g. `.claude/agents/nix-research-agent.md`) | files the loader actually wrote |
| `installed_dirs` | array of strings, relative paths | directories the loader had to `mkdir` (pre-existing dirs like `.claude/agents/` itself are NOT listed — only newly created ones, e.g. per-skill leaf dirs) |
| `merged_sections` | object, keyed by `"settings"` and/or `"index"` | only present for categories the extension actually merges: `core`/`nix` have `settings` (hooks/mcpServers/permissions), `nvim`/`memory` have only `index` (list of `context/index.json` paths appended). No entry has both AND no entry has a `"claudemd"` key — CLAUDE.md is a **computed artifact** regenerated wholesale by `merge_mod.generate_claudemd()`, not incrementally tracked. |
| `data_skeleton_files` | array (empty in all 4 current entries — none declare `provides.data`) | |
| `status` | string, always `"active"` in current entries | `"active"` / absent-key = "not loaded" (there is no `"inactive"` status literal ever written by the loader; absence of the key IS the inactive state) |

Field order in the file is alphabetical (jq's `.` pretty-print via `write_json()`'s `jq .`
post-process), so a hand-written entry should be written in any order — `jq` will re-sort it on
next machine write, and matching key **presence/absence**, not ordering, is what matters.

#### 2. Literature manifest cross-reference

`.claude/extensions/literature/manifest.json`:
- `name`: `"literature"`, `version`: `"2.0.0"`
- `dependencies`: `["core", "filetypes"]` — **note**: `"filetypes"` also has no `extensions.json`
  entry (confirmed: only core/nix/memory/nvim are tracked). This is out of scope for #846 but is
  relevant to the risk analysis below (see "cascade" finding).
- `routing_exempt: true`
- `provides.agents`: `["literature-agent.md"]`
- `provides.commands`: `["literature.md", "cite.md"]`
- `provides.skills`: `["skill-literature", "skill-cite"]`
- `provides.context`: `["project/literature"]`
- `provides.scripts`: 25 entries (zotero-* and literature-* `.sh`/`.sql` files)
- `merge_targets.claudemd`: `{source: "EXTENSION.md", target: ".claude/CLAUDE.md", section_id: "extension_literature"}`
- `merge_targets.index`: `{source: "index-entries.json", target: ".claude/context/index.json"}`
- No `provides.data`, no `provides.hooks`(empty `{}`), no `provides.rules`, no `provides.docs`,
  no `provides.templates`, no `provides.systemd`, no `mcp_servers`.

#### 3. Actual deployed state vs. manifest (verified by filesystem inspection)

| Category | Manifest declares | Actually present in `.claude/` | Notes |
|---|---|---|---|
| agents | `literature-agent.md` | present | **is a symlink**: `.claude/agents/literature-agent.md -> ../extensions/literature/agents/literature-agent.md` |
| commands | `literature.md`, `cite.md` | both present | `literature.md` **is a symlink**; `cite.md` is a **real copy** (deployed by task #844) |
| skills | `skill-literature`, `skill-cite` | both present | `skill-literature` **is a symlink** (`.claude/skills/skill-literature -> ../extensions/literature/skills/skill-literature`); `skill-cite` is a **real copy** (task #844) |
| context | `project/literature` (5 files: domain/literature-index.md + 4 patterns/*.md) | present, real files | real copies, but **not indexed**: `jq '.entries[] | select(.path|startswith("project/literature"))' .claude/context/index.json` returns **zero results**. The `merge_targets.index` step was never run. |
| scripts | 25 files | 18 present, **7 missing** | Missing: `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`. This exact 7-script gap is independently confirmed by task #844's own handoff/README (`.claude/extensions/literature/README.md` lines 154-201) — "quarantine-never-delete", intentionally left undeployed with reasons documented per-script. |
| scripts (extra) | (not declared) | `zotero-resolve-pdf.sh`, `.zotero-title-sim.py` present in `.claude/scripts/` | deployed by a later task (task #836 zotero-pdf-resolution pattern per git log) but never added to `manifest.provides.scripts` |
| CLAUDE.md | `merge_targets.claudemd` -> section `extension_literature` | **absent** | `grep -n "extension_literature\|## Literature Extension" .claude/CLAUDE.md` finds nothing. (The existing "## Literature Mode (`--lit`)" section is unrelated hand-authored runtime documentation, not the manifest's `EXTENSION.md` merge output.) |

This proves conclusively that **no `manager.load("literature")` call has ever completed** —
the loader only ever produces plain-file copies (`copy_file()` in `loader.lua` does
read-source-then-write-target; it never symlinks), and it always runs the merge steps
(`process_merge_targets`) and `state_mod.mark_loaded()` atomically as part of `manager.load()`.
The symlinks and the CLAUDE.md/index.json gap are proof the current deployment was assembled
by hand/ad-hoc scripting (predating task #844, which itself only touched the `/cite` trio and
`zotero-search.sh` — matching the "real copy" status of exactly those 4 files).

### External Resources

None consulted — this is a pure codebase/config question with no external documentation
relevant beyond the files already cited.

### How `loader.lua` and `init.lua` consume `extensions.json` entries

- **`state.lua`** is the sole reader/writer of `extensions.json` (`M.read`/`M.write`, using
  `vim.json.decode`/`encode` + a `jq .` pretty-print pass). `loader.lua` never touches
  `extensions.json` directly — it's a pure file-copy engine (`copy_simple_files`,
  `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`, etc.) that returns lists of
  copied/created paths for `init.lua` to persist via `state.lua`.
- **`init.lua`**'s `manager.load(name, opts)` is the only place a new entry gets written
  (`state_mod.mark_loaded(...)` then `state_mod.write(...)`, `init.lua:531-532`). It:
  1. Refuses immediately if `state_mod.is_loaded(state, name)` is already true.
  2. Resolves and recursively loads `manifest.dependencies` that are not yet loaded (depth-limit
     5, circular-dependency detection) — **for literature this means `"filetypes"` would also
     get auto-loaded** the first time a real load succeeds.
  3. Copies all `provides.*` categories via `loader.lua`, tracking every path it actually wrote.
  4. Runs `process_merge_targets()` (CLAUDE.md/index.json/settings merges) and records only the
     `index`/`settings` results into `merged_sections` (CLAUDE.md itself is a computed artifact,
     regenerated wholesale afterward via `merge_mod.generate_claudemd()`).
  5. Writes the state entry, regenerates CLAUDE.md and `opencode.json`.
- **`manager.unload(name, opts)`** (`init.lua:574`) refuses immediately unless
  `state_mod.is_loaded(state, name)` is true, then deletes exactly the `installed_files` /
  `installed_dirs` recorded in that entry (`loader_mod.remove_installed_files`, which calls
  `vim.fn.delete(filepath)` per file — for a symlink this deletes the symlink itself, not its
  target, but still removes the working artifact) and reverses `merged_sections`.
- **`manager.reload(name, opts)`** (`init.lua:706`) is unload-then-load and **also gates on
  `is_loaded == true` first** — today, since literature has no entry, both `unload()` and
  `reload()` immediately no-op-fail with `"Extension not loaded: literature"`. This is the
  current (accidental) safety net.
- **`manager.list_available()`** (`init.lua:757`) is what the picker UI renders: for every
  extension found on disk in `global_extensions_dir` (`.claude/extensions/*`), it reports
  `status = "inactive"` unless `state_mod.is_loaded` is true, in which case `"active"` or
  `"update-available"` (via `state_mod.needs_update`, a straight string version-mismatch check).
  **This is the concrete, user-facing effect of the missing entry today**: the picker shows
  literature as installable/"inactive" and offers a **Load** action, even though its files are
  already present and working.
- **A missing entry does NOT affect Claude Code's own command/skill/agent dispatch at all** —
  Claude Code reads `.claude/commands/*.md`, `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`
  directly from disk; none of that path consults `extensions.json`. That file is exclusively
  consumed by the Neovim-side Lua extension manager/picker (`lua/neotex/plugins/ai/shared/extensions/`
  and its Telescope UI in `lua/neotex/plugins/ai/claude/commands/picker/`).
- **A malformed entry's realistic failure modes**: (a) missing `status: "active"` key (or any
  falsy/absent value) is read by `is_loaded()` as not-loaded — nothing crashes, the picker just
  still offers "Load"; (b) a `version` field that doesn't match `manifest.json`'s `"2.0.0"` marks
  it `"update-available"` in the picker, prompting a human toward `reload()`, which — as shown
  above — deletes whatever `installed_files`/`installed_dirs` the entry claims; (c) there is
  **no JSON-schema validation of `extensions.json` entries anywhere** in `state.lua`/`init.lua` —
  `vim.json.decode` will happily accept any well-formed JSON with any field set, so a "malformed"
  entry doesn't hard-fail load-time parsing, it just produces wrong bookkeeping (silent, not
  loud) that only manifests the next time a human interacts with the picker.

### Recommendations

**Load-bearing vs. cosmetic — definitive answer**: **Cosmetic bookkeeping for Claude Code's own
runtime** (nothing there reads `extensions.json`), but **load-bearing for the Neovim extension
picker's state machine** (`is_loaded`/`get_status`/`unload`/`reload` all key off this entry, and
its *current absence* is what currently makes the picker mis-report literature as "inactive" and
offer a "Load" action that would mutate the tree in surprising ways if ever clicked).

**Exact entry to add** (insert as `.extensions.extensions.literature`, alongside the existing 4,
keeping the same field set the loader itself writes):

```json
"literature": {
  "version": "2.0.0",
  "loaded_at": "<ISO8601 UTC timestamp at implementation time, e.g. 2026-07-11T00:57:33Z>",
  "source_dir": "/home/benjamin/.config/nvim/.claude/extensions/literature",
  "installed_files": [],
  "installed_dirs": [],
  "merged_sections": {},
  "data_skeleton_files": [],
  "status": "active"
}
```

Rationale for the deliberately empty `installed_files` / `installed_dirs` / `merged_sections`:

1. **Accuracy**: the real loader never performed this deploy (proved above — symlinks, missing
   scripts, absent `index.json`/CLAUDE.md merge sections are impossible outputs of
   `manager.load()`). Any specific file list this task's implementer writes by hand would be a
   *guess* about ownership the loader itself never asserted. `merged_sections: {}` in particular
   must not claim `index.json` paths that don't actually exist in `.claude/context/index.json` —
   doing so would desynchronize the one invariant every other entry currently satisfies
   (`merged_sections.index.paths` exactly mirrors what's really in `index.json`).
2. **Safety under the only two currently-reachable code paths that consume these arrays**:
   `manager.unload()`/`manager.reload()`, both human/picker-triggered only (never called at
   Neovim startup or by any Claude Code skill). With empty arrays, a future accidental
   "Unload literature" click becomes a safe no-op (`remove_installed_files({}, {})` deletes
   nothing) instead of silently deleting the 2 symlinks and the real `skill-cite`/`cite.md`
   files task #844 deployed. This directly satisfies the task's own constraint: *"if adding the
   entry changes what gets loaded/synced, verify no literature script gets clobbered."* An empty
   entry is the only version of this fix with a hard, code-level guarantee of that property.
3. **Closes the actual live risk**: today, `status` is implicitly absent so `is_loaded == false`,
   and the picker offers **Load**, which (unlike Unload) is NOT gated by `is_loaded` and WOULD
   fully execute — cascading into the undeclared `"filetypes"` dependency, copying the 7 missing
   scripts, and collapsing the 3 symlinks into plain copies. Setting `status: "active"` (with any
   valid `version`) is what actually prevents that path, by making `manager.load()`'s first
   check ("Extension already loaded") fire.

If a fuller reconciliation is later wanted (deploying the 7 missing scripts, populating
`index.json`, generating the `## Literature Extension` CLAUDE.md section, and normalizing the
symlinks into real copies), the correct mechanism per `.claude/extensions/literature/README.md`'s
own words is to run the actual extension-loader flow for literature (Neovim picker "Load", or an
equivalent scripted `manager.load("literature", {confirm=false})` call) — not to hand-author
those sections into `extensions.json`. That is explicitly out of task #846's declared
`file_scope` (`.claude/extensions.json`, `lua/.../loader.lua` only) and would also touch
`.claude/context/index.json`, `.claude/CLAUDE.md`, and add new files under `.claude/scripts/`,
plus silently pull in the undeclared `"filetypes"` extension as a dependency — a materially
larger, separately-scoped change best done as its own follow-up task if desired.

## Decisions

- Recommend the 8-field schema exactly matching `state.lua`'s `mark_loaded()` output shape,
  values as specified above.
- Recommend empty `installed_files`/`installed_dirs`/`merged_sections`/`data_skeleton_files`
  rather than a hand-enumerated file list, for the safety/accuracy reasons above.
- Recommend NOT attempting to also fix the 7-missing-script gap, the `index.json` gap, or the
  CLAUDE.md merge gap as part of this task — those require the real loader flow and touch files
  outside task #846's declared scope.
- No change to `loader.lua` is needed or recommended; it was read for consumption semantics only,
  per the task's own instruction ("Do not change loader behavior").

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Hand-written `merged_sections`/`installed_files` could claim ownership of files the loader didn't create, causing a future `unload()` to delete real (possibly symlinked) working artifacts | Use empty arrays/objects, as recommended above |
| `version` mismatch vs. `manifest.json` could flag `"update-available"` and invite a `reload()` | Use `"2.0.0"`, verified to match `manifest.json` exactly at time of writing |
| Setting `status: "active"` closes the picker's current "Load" option for literature, which is the only path that would otherwise deploy the 7 missing scripts | Acceptable / intended: the missing scripts are already deliberately quarantined per task #844's README documentation; this task does not change that decision, and a future dedicated task can still choose to unload+reload deliberately if full reconciliation is wanted |
| `check-extension-docs.sh` regression | Verified: the script never references `extensions.json` (`grep -n "extensions.json"` returns nothing) and currently exits 0 with `literature: PASS` even without the entry; the edit is inert with respect to this check either way |
| task #841 drift-guard / "no clobber of deployed literature scripts" | Confirmed no clobber risk: this is a pure JSON-file addition with no interaction with `loader.lua`'s copy engine; the only mechanism that could ever touch deployed literature files (`unload`/`reload`) is neutralized by the empty-array recommendation above |

## Context Extension Recommendations

- **Topic**: extension-loader vs. Claude-Code-runtime separation of concerns.
- **Gap**: `.claude/context/guides/extension-development.md` and `.claude/context/guides/loader-reference.md`
  do not currently document that `extensions.json` is consumed *exclusively* by the Neovim Lua
  picker/loader and has zero bearing on Claude Code's own command/skill/agent dispatch. This
  distinction was the crux of the "load-bearing or cosmetic" question in this task and would be
  useful to codify so future tasks don't need to re-derive it from source.
- **Recommendation**: add a short "Runtime consumers of `extensions.json`" subsection to
  `.claude/context/guides/loader-reference.md` stating this separation explicitly, with a pointer
  to this report / task #846 as the investigation that established it.

## Appendix

Key commands run:
```bash
jq '.extensions | keys[]' .claude/extensions.json
jq -r '.entries[] | select(.path|startswith("project/literature")) | .path' .claude/context/index.json   # empty
grep -n "extension_literature\|## Literature Extension" .claude/CLAUDE.md   # no match
grep -n "extensions.json" .claude/scripts/check-extension-docs.sh           # no match
bash .claude/scripts/check-extension-docs.sh                                # PASS, literature: PASS
stat .claude/skills/skill-literature                                        # symbolic link
stat .claude/agents/literature-agent.md .claude/commands/literature.md      # symbolic links
for s in <25 manifest scripts>; do [ -f ".claude/scripts/$s" ] || echo MISSING; done  # 7 missing
```

Files read in full or in relevant part:
- `.claude/extensions.json`
- `.claude/extensions/literature/manifest.json`, `EXTENSION.md`, `README.md` (lines 150-201)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` (full)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (full)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 150-330, 480-844)
- `lua/neotex/plugins/ai/shared/extensions/config.lua` (full)
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (lines 140-240)
- `specs/844_finish_or_defer_zotero_cite_install/.orchestrator-handoff.json`
