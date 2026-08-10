# Research Report: Task #793

**Task**: 793 - Fix literature extension script packaging so `<leader>al` deploys a working extension to all repos.
**Started**: 2026-07-01T15:00:00Z
**Completed**: 2026-07-01T15:34:41Z
**Effort**: Medium (script relocation + manifest update + 2 path-resolution code fixes + 1 doc-lint safeguard)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration only (manifest.json, loader.lua, manifest.lua, sync.lua, init.lua, all literature extension commands/skills/agents/scripts)
**Artifacts**: - `specs/793_literature_extension_script_packaging/reports/01_script-packaging-research.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The prior investigation's root cause is confirmed and correct as far as it goes, but it
  under-describes the actual deployment model. **Extension scripts do not deploy to
  `.claude/extensions/{name}/scripts/` in a consuming repo — they deploy FLAT into
  `.claude/scripts/`** (`loader.lua:317-318`, target_dir is always the repo's `.claude` root,
  never the per-extension directory; `copy_manifest` at `loader.lua:588-617` copies only
  `manifest.json` into `extensions/{name}/`, never the `scripts/` subtree). This is the single
  most important correction to build the fix plan around: the planner must migrate the 7
  missing scripts + 1 SQL file into `.claude/extensions/literature/scripts/` as the **source**,
  but all runtime code should keep referring to them via the **flat** `.claude/scripts/`
  convention that the rest of the extension already uses — not the nested
  `.claude/extensions/literature/scripts/...` convention that appears in two places and is
  effectively dead code post-deployment.
- Definitive script inventory (Goal 1): 7 scripts + 1 SQL file are referenced by the
  extension's commands/skills/agents but are physically absent from both
  `.claude/extensions/literature/scripts/` and `manifest.provides.scripts`:
  `literature-discover.sh`, `literature-ingest.sh`, `literature-search.sh`,
  `literature-build-index.sh`, `literature-convert.sh`, `literature-chunk.sh`, and
  `literature-schema.sql`. `literature-audit.sh` (also only in `.claude/scripts/`) is **not**
  referenced anywhere in the extension's commands/skills/agents/docs — it is an orphaned
  dev-only QA tool and should be explicitly excluded from migration.
- Beyond the discover-script bug already known, a **second, independent** path-resolution bug
  exists in an *already-migrated, already-deployed* script: `zotero-chunk.sh` (in
  `manifest.provides.scripts` today) hardcodes
  `LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"` (`zotero-chunk.sh:38-40`) and uses it
  to invoke `literature-convert.sh`, `literature-chunk.sh`, and `literature-build-index.sh`
  (`zotero-chunk.sh:171,203,274`). This is actually *correct* once the flat-deploy model above
  is understood (all these scripts land together in `.claude/scripts/`), but it must be verified
  to keep working — and a **third** bug, `literature-briefing.sh:192,195`, hardcodes an
  absolute, machine-specific path (`~/.config/nvim/.claude/scripts/literature-search.sh`) into
  text it emits for agents to read, which will be wrong in every other deployed repo regardless
  of the script-migration fix.
- `literature-schema.sql` should be packaged as a plain entry in `manifest.provides.scripts`
  (not the `data` category — `copy_data_dirs` is for whole directories with merge-preserve
  semantics meant for user data like `memory/`, and is the wrong shape and wrong semantics for a
  static, always-in-sync asset file). `copy_scripts`/`copy_file` only special-case `.sh` files
  for chmod preservation (`loader.lua:77`), so a `.sql` entry in `provides.scripts` copies
  correctly with no code changes needed to the loader.
- The picker's "Load Core" sync path (`sync.lua`, invoked by the `on_load_all` callback,
  labeled "Load Core Agent System") is **entirely irrelevant** to this bug: it sources
  exclusively from `.claude/extensions/core/` (`sync.lua:732`, `core_source_base`) and never
  touches non-core extensions. The only mechanism that deploys literature's scripts anywhere is
  the per-extension load/reload path (`extensions/init.lua` `manager.load`/`manager.reload` →
  `loader.copy_scripts`). The fix therefore only needs to be correct for that one path; nothing
  in `sync.lua` needs to change for this task.
- Recommend a new `check_referenced_scripts_declared` rule in
  `.claude/scripts/check-extension-docs.sh` that greps each extension's
  commands/skills/agents/README/EXTENSION.md for `*.sh`/`*.sql` filename tokens, excludes
  core-owned names (cross-referenced against the core manifest) and names already declared in
  the extension's own `provides.scripts`, and `fail`s (exit-1) on any remainder. Running this
  rule today against the *current* (broken) literature manifest reproduces exactly the 7+1
  missing entries, confirming the check is well-targeted — and confirms the extension currently
  reports `PASS` under the existing rule set (no rule catches this class of bug today).

## Context & Scope

Researched: the deployment mechanism for `.claude/extensions/*/manifest.json`
`provides.scripts` (Lua loader in `lua/neotex/plugins/ai/shared/extensions/`), the full set of
literature-extension source files (`commands/literature.md`, `commands/cite.md`,
`skills/skill-literature/SKILL.md`, `skills/skill-cite/SKILL.md`,
`agents/literature-agent.md`, `EXTENSION.md`, `README.md`, `context/project/literature/**`),
the 7 candidate scripts + schema file living only in this repo's deployed `.claude/scripts/`,
and the doc-lint script `.claude/scripts/check-extension-docs.sh`. Did not investigate
`install-extension.sh` in depth (a separate, lighter-weight non-Lua installer that does not
appear to copy `scripts/` at all — out of scope since the task explicitly targets the
`<leader>al` picker/loader path).

## Findings

### Codebase Patterns

#### 1. Definitive script/data-file table (Goal 1)

| Name | In `.claude/extensions/literature/scripts/`? | In `manifest.provides.scripts`? | In `.claude/scripts/` (this repo, deployed)? | Owner | Action needed |
|---|---|---|---|---|---|
| `zotero-search.sh` | Yes | Yes | No (not itself referenced there; only via ext path) | literature | none |
| `cite-extract.sh` | Yes | Yes | No | literature | none |
| `zotero-read.sh` | Yes | Yes | No | literature | none |
| `zotero-write.sh` | Yes | Yes | No | literature | none |
| `zotero-setup.sh` | Yes | Yes | No | literature | none |
| `zotero-chunk.sh` | Yes | Yes | No | literature | **fix internal path bug (see below)** |
| `zotero-attach-chunks.sh` | Yes | Yes | No | literature | none |
| `zotero-index-add.sh` | Yes | Yes | No | literature | none |
| `zotero-index-remove.sh` | Yes | Yes | No | literature | none |
| `literature-briefing.sh` | Yes | Yes | Yes | literature | **fix hardcoded absolute path (see below)** |
| `literature-create-setup-task.sh` | Yes | Yes | Yes | literature | none |
| `test-lit-pipeline.sh` | Yes | Yes | No | literature | none |
| `literature-retrieve.sh` | No (core's) | No (core's) | Yes | **core** | none — do not touch |
| `literature-discover.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-ingest.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-search.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-build-index.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-convert.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-chunk.sh` | **No** | **No** | Yes | literature (unpackaged) | **migrate** |
| `literature-schema.sql` | **No** | **No** | Yes | literature (unpackaged) | **migrate (as `provides.scripts` entry)** |
| `literature-audit.sh` | No | No | Yes | orphaned / dev-only | **leave alone — not referenced anywhere in the extension** |

Verification for `literature-audit.sh`: `grep -rln "literature-audit" .claude/` (excluding the
script itself) returns nothing. It is a standalone pre-implementation QA harness
(`literature-audit.sh:2-11`, "Pre-implementation audit for literature retrieval pipeline") never
invoked from `literature.md`, `skill-literature/SKILL.md`, `skill-cite/SKILL.md`, or
`literature-agent.md`. Genuinely-needed vs. incidental distinction: this is the one clear case
of "exists in `.claude/scripts/` but not actually needed by the extension" — it should not be
migrated as part of this fix (a follow-on task could delete it or fold it into
`test-lit-pipeline.sh` if desired, but that is out of scope here).

Citations for each "migrate" row's reference site:
- `literature-discover.sh`: `commands/literature.md:125-127,295-297`; `EXTENSION.md:37`;
  `README.md:86,211`.
- `literature-ingest.sh`: `skills/skill-literature/SKILL.md:113,119,122,141`; `EXTENSION.md:46`;
  `README.md:97`.
- `literature-search.sh`: `agents/literature-agent.md:32,52,180`;
  `context/project/literature/domain/literature-index.md:88,91-94`;
  `context/project/literature/patterns/agent-exploration.md:21,39,50,53-55,99`;
  `EXTENSION.md:24-25`; `README.md:61-63`; `scripts/literature-briefing.sh:192,194-195` (as a
  hardcoded absolute path — see bug below).
- `literature-build-index.sh`, `literature-convert.sh`, `literature-chunk.sh`: not referenced
  directly from any command/skill/agent markdown; referenced only from inside
  `literature-ingest.sh:38-40,189,211,296,347` (sibling `$SCRIPT_DIR` calls) and from
  `scripts/zotero-chunk.sh:21,28,171,182,203,206,274,283` (hardcoded
  `PROJECT_ROOT/.claude/scripts` calls — an already-deployed script depending on
  not-yet-deployed siblings).
- `literature-schema.sql`: referenced only from `literature-build-index.sh:24`
  (`SCHEMA_FILE="$SCRIPT_DIR/literature-schema.sql"`).

Cross-check against core: confirmed via
`jq '.provides.scripts' .claude/extensions/core/manifest.json` that `literature-retrieve.sh` is
core-owned (also physically present at `.claude/extensions/core/scripts/literature-retrieve.sh`)
and none of the 7 missing scripts exist in `.claude/extensions/core/scripts/` either — they are
not "core scripts that happen to be literature-flavored"; they simply were never packaged into
any extension source tree at all. They exist today purely because someone hand-placed them
directly into this repo's deployed `.claude/scripts/` without ever adding them to an extension
manifest — this repo is the only place they "work," and only by accident of being the source
repo.

#### 2. Inter-script dependency graph and path-form audit (Goal 2)

```
literature-ingest.sh (SCRIPT_DIR-relative, robust)
  ├─ literature-convert.sh   [$SCRIPT_DIR/literature-convert.sh]      literature-ingest.sh:189
  ├─ literature-chunk.sh     [$SCRIPT_DIR/literature-chunk.sh]        literature-ingest.sh:211
  └─ literature-build-index.sh [$SCRIPT_DIR/literature-build-index.sh] literature-ingest.sh:296,347
       └─ literature-schema.sql [$SCRIPT_DIR/literature-schema.sql]   literature-build-index.sh:24

zotero-chunk.sh (PROJECT_ROOT-relative, currently points at flat .claude/scripts/)
  ├─ literature-convert.sh     [$LITERATURE_SCRIPTS_DIR/literature-convert.sh]  zotero-chunk.sh:171
  ├─ literature-chunk.sh       [$LITERATURE_SCRIPTS_DIR/literature-chunk.sh]    zotero-chunk.sh:203
  └─ literature-build-index.sh [$LITERATURE_SCRIPTS_DIR/literature-build-index.sh] zotero-chunk.sh:274

literature-discover.sh (SCRIPT_DIR-relative, BROKEN candidate ordering)
  └─ zotero-search.sh  [tries "$SCRIPT_DIR/../extensions/literature/scripts/zotero-search.sh"
                         then ".claude/extensions/literature/scripts/zotero-search.sh"]
                        literature-discover.sh:340-342

literature-search.sh, literature-convert.sh, literature-chunk.sh: self-contained, no
sibling-script or sibling-data-file references (grepped, zero hits).
```

Path-form classification:

| Script | Resolution style | Breaks on migration? |
|---|---|---|
| `literature-ingest.sh` (lines 38-41, 189, 211, 296, 347) | `$SCRIPT_DIR`-relative (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `literature-ingest.sh:30`) | **No** — robust as long as all 4 files (`literature-ingest.sh`, `-convert.sh`, `-chunk.sh`, `-build-index.sh`) move together into the same directory. |
| `literature-build-index.sh:24` (`SCHEMA_FILE="$SCRIPT_DIR/literature-schema.sql"`) | `$SCRIPT_DIR`-relative | **No** — robust as long as `literature-schema.sql` moves into the same directory as `literature-build-index.sh`. |
| `zotero-chunk.sh:37-40` (`PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"`; `LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"`) | Hardcoded absolute-from-project-root, always targets **flat** `.claude/scripts/` regardless of where `zotero-chunk.sh` itself lives | **No, but fragile/confusing** — this is only correct because of the flat-deploy model (see below); it is not obviously correct by inspection and should be simplified once the flat-deploy model is documented, ideally to just reference siblings via its own `$SCRIPT_DIR` once everything is confirmed to land in the same flat directory. |
| `literature-discover.sh:339-347` (candidate-search for `zotero-search.sh`) | First candidate `$SCRIPT_DIR/../extensions/literature/scripts/zotero-search.sh` (nested-extension-relative); second candidate `.claude/extensions/literature/scripts/zotero-search.sh` (cwd-relative, same nested path) | **Both candidates target the nested `extensions/literature/scripts/` location, which per the flat-deploy model below never exists as a populated directory in a deployed target repo (only `manifest.json` is copied there).** This candidate list currently "works" only in the source repo. It is dead code for every consumer of the extension. Needs correction (see Decisions). |
| `skills/skill-literature/SKILL.md:1121-1130` (candidate-search for `zotero-search.sh`, Search Step 1) | Same broken-candidate pattern as above, duplicated | Same issue, same fix needed. |
| `skills/skill-literature/SKILL.md:118` (`SCRIPT_DIR="$(dirname "$0")/../../scripts"`) | Skill-relative (`.claude/skills/skill-literature/` → up 2 → `.claude` → `/scripts` = flat `.claude/scripts/`) | **No** — this is the *correct* pattern; it matches the flat-deploy model. |
| `commands/literature.md:127` (`DISCOVER_SCRIPT=".claude/scripts/literature-discover.sh"`) | Flat cwd-relative | **No** — correct, matches flat-deploy model. |

#### 3. The flat-deploy model (why goal 2's "breaks on migration" list is short) — critical correction to prior investigation

`loader.copy_scripts` (`lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342`):
```lua
local source_scripts_dir = source_dir .. "/scripts"
local target_scripts_dir = target_dir .. "/scripts"
...
for _, script_name in ipairs(manifest.provides.scripts) do
  local source_path = source_scripts_dir .. "/" .. script_name
  local target_path = target_scripts_dir .. "/" .. script_name
  ...
```
`target_dir` here is always `project_dir .. "/" .. config.base_dir` (e.g. `{repo}/.claude`),
confirmed at the call site in `lua/neotex/plugins/ai/shared/extensions/init.lua:239` (inside
`manager.load`, which calls `copy_scripts` at `init.lua:434`). **It is never
`{repo}/.claude/extensions/{name}`.** `copy_manifest`
(`loader.lua:588-617`) copies only `manifest.json` into
`{target_dir}/extensions/{extension_name}/manifest.json` — no `scripts/`, `commands/`,
`skills/`, or `agents/` subtree is ever created under `extensions/{name}/` in a consuming repo.

Consequence: **every script listed in `manifest.provides.scripts`, for every extension, lands
flat in `{repo}/.claude/scripts/`, mixed together with core scripts and every other loaded
extension's scripts.** This is verifiable in-repo: `.claude/scripts/generate-todo.sh` (a
core-owned script) is byte-identical to `.claude/extensions/core/scripts/generate-todo.sh` but
has a different mtime (Jun 30 vs Jun 12), confirming it is a separately-maintained deployed
copy, not a symlink — i.e., this repo *is* itself a "consumer" of the core extension via the
same flat-copy mechanism, and already relies on it working correctly.

This means: once `literature-discover.sh`, `-ingest.sh`, `-search.sh`, `-build-index.sh`,
`-convert.sh`, `-chunk.sh`, and `literature-schema.sql` are added to
`manifest.provides.scripts` and physically placed in
`.claude/extensions/literature/scripts/`, loading the extension in *any* repo will deposit all
of them together, flat, in that repo's `.claude/scripts/` — exactly where
`literature.md:127`'s `DISCOVER_SCRIPT=".claude/scripts/literature-discover.sh"` and
`skill-literature/SKILL.md:118`'s `$(dirname "$0")/../../scripts` both already expect to find
them. **No code changes are needed in `literature.md`, `skill-literature/SKILL.md`,
`literature-ingest.sh`, or `literature-build-index.sh` for path resolution** — their existing
`$SCRIPT_DIR`-relative and flat-cwd-relative patterns are already correct for the true
deployment target. The only path-resolution code that needs to change is the two duplicated
"nested extensions/ path" candidate lists (`literature-discover.sh:340-342` and
`skill-literature/SKILL.md:1123-1125`), which reference a location
(`.claude/extensions/literature/scripts/zotero-search.sh`) that will never be populated in a
deployed repo. Recommend simplifying both to prefer the flat sibling path
(`$SCRIPT_DIR/zotero-search.sh` / `.claude/scripts/zotero-search.sh`) as the primary candidate,
keeping the nested path only as a defensive fallback (or dropping it — it is currently
misleading about how deployment actually works and should not be presented as the primary
candidate in either location).

#### 4. `.sql` packaging mechanism (Goal 3)

Valid `provides` categories are enumerated at `lua/neotex/plugins/ai/shared/extensions/manifest.lua:10-12`:
`agents, skills, commands, rules, context, scripts, hooks, data, docs, templates, systemd,
root_files`. Two candidates were considered:

- **`data` category** (`loader.lua:626-679`, `copy_data_dirs`): designed for whole
  *directories* (`source_dir/data/{name}/` → `project_dir/{name}/`, note: goes to project root,
  not into `.claude/`) with **merge-preserve semantics** — "only copy if target file doesn't
  already exist" (`loader.lua:658`), intended for user-owned mutable state like a `memory/`
  skeleton. This is the wrong shape (expects a directory, not a single file) and the wrong
  semantics (a schema file must always match the script that reads it; it should be
  unconditionally overwritten/kept in sync, not preserved-if-present).
- **`scripts` category** (recommended): `copy_scripts` copies whatever filenames are listed
  from `source_dir/scripts/` to `target_dir/scripts/` with no extension filtering; `copy_file`
  (`loader.lua:54-82`) only special-cases permission preservation for names matching `%.sh$`
  (`loader.lua:77`) — a non-`.sh` file such as `literature-schema.sql` simply gets its content
  copied with default (non-executable) permissions, which is exactly correct for a SQL schema
  file. **No loader code changes are required.** Simply add `"literature-schema.sql"` to
  `manifest.provides.scripts` and place the physical file at
  `.claude/extensions/literature/scripts/literature-schema.sql`.

#### 5. "Load Core" sync path vs. per-extension load (Goal 4)

`sync.lua`'s `M.scan_all_artifacts` (the "Load Core Agent System" callback, wired via
`picker/config.lua:51-52` `on_load_all`) sources every category **exclusively** from
`.claude/extensions/core/` — confirmed at `sync.lua:732`:
`local core_source_base = (base_dir == ".claude") and ".claude/extensions/core" or nil`, used
for every `sync_scan(...)` call including `artifacts.scripts = sync_scan("scripts", "*.sh",
true, nil, "scripts")` at `sync.lua:844`. This path additionally uses a **blocklist** built from
`manifest.aggregate_extension_artifacts` (`sync.lua:725`) to make sure core-sync doesn't clobber
files owned by other *loaded* extensions — but it never reads from any non-core extension's own
`scripts/` directory. **"Load Core" is therefore completely unrelated to the literature
extension's scripts and requires no changes for this task.** The only relevant path is
`manager.load`/`manager.reload` in `lua/neotex/plugins/ai/shared/extensions/init.lua`, which
calls `loader.copy_scripts` per-extension (as analyzed in Finding #3 above). This also answers
part of the `*.sh`-only-glob concern raised in the task description
(`sync.lua:844`): since `sync.lua` never touches literature's scripts at all, whether its glob
covers `.sql` is moot for this bug — but note for completeness that if `.claude/scripts/` ever
needs to be refreshed via "Load Core" today, a `.sql` file placed there would **not** be
re-synced by that specific glob (only `*.sh`); this is not a blocker for the current task since
the schema file's sync will occur via the per-extension `copy_scripts` path once packaged (see
Finding #4), not via `sync.lua`.

#### 6. Source-of-truth duplication (Goal 5)

Confirmed by diffing `generate-todo.sh` (core) at `.claude/scripts/` vs.
`.claude/extensions/core/scripts/`: this repo already runs a **dual-copy model** for every
already-packaged extension — the extension source under `.claude/extensions/{name}/` is the
canonical, git-tracked original; `.claude/scripts/` (flat) is a *deployed artifact* that this
repo also happens to consume (since this repo's own commands hardcode flat
`.claude/scripts/...` paths, same as any consumer). The 7 scripts + schema file currently break
this model: they exist **only** as flat "deployed" files with no corresponding canonical
source anywhere.

Recommended procedure:
1. `git mv` the 7 scripts + `literature-schema.sql` from `.claude/scripts/` into
   `.claude/extensions/literature/scripts/` (this makes the extension source tree the single
   canonical copy, matching every other already-packaged literature script).
2. Add all 8 filenames to `manifest.provides.scripts`.
3. In **this** repo, invoke `manager.reload("literature")` (exposed via the `<leader>al` picker
   as "reload extension") — `init.lua:706-730`: `reload` = `unload` then `load`, which will
   flat-copy the newly-declared scripts from the extension source back into this repo's
   `.claude/scripts/`, restoring exactly the files that were `git mv`'d away in step 1, but now
   sourced from (and re-derivable from) the canonical extension tree. This closes the loop:
   after this one-time reload, `.claude/scripts/literature-*.sh` in this repo is a regenerable
   deployment artifact, not a hand-maintained original, eliminating future drift risk.
4. Going forward, edits to these scripts must be made in
   `.claude/extensions/literature/scripts/`, followed by a `reload` (or equivalent copy) to
   refresh this repo's own flat copy — same discipline already implicitly required for every
   other literature script and every core script.

Note: `manager.unload` only removes files it tracked as installed (from `all_files`,
`init.lua:393` accumulator) — it does not blanket-delete `.claude/scripts/`, so `reload` is safe
with respect to unrelated files in that directory (core scripts, other extensions' scripts,
etc.).

#### 7. Automated safeguard design (Goal 6)

`.claude/scripts/check-extension-docs.sh` is a per-extension doc-lint script (iterates
`$EXT_DIR/*/`, exit 0 all-pass / exit 1 on any `fail()` call, `FAILURES` counter incremented in
`fail()` at `check-extension-docs.sh:39-43`). It already has
`check_manifest_entries` (`check-extension-docs.sh:59-107`) which validates the *forward*
direction (every `manifest.provides.scripts` entry exists on disk) — but nothing validates the
*reverse* direction (every script referenced in the extension's prose exists in
`manifest.provides.scripts`), which is exactly this bug's class. Confirmed empirically: running
`bash .claude/scripts/check-extension-docs.sh --quiet` today reports `[literature]` with **no
failures** (overall summary: `literature PASS`) despite the packaging bug — proving no existing
rule catches it.

Recommended new function `check_referenced_scripts_declared` (add after
`check_readme_vs_manifest`, called from the same per-extension loop at
`check-extension-docs.sh:335-346`):

1. **Extraction**: For `$ext_path/commands/*.md`, `$ext_path/skills/*/SKILL.md`,
   `$ext_path/agents/*.md`, `$ext_path/README.md`, `$ext_path/EXTENSION.md`, run
   `grep -oE '[A-Za-z0-9_-]+\.(sh|sql)'` to extract every filename-shaped token ending in
   `.sh`/`.sql`, then `sort -u`.
2. **False-positive avoidance — core exclusion**: Build a set from
   `jq -r '.provides.scripts[]?' .claude/extensions/core/manifest.json` and drop any extracted
   name present in that set (e.g. `generate-todo.sh`, `manage-topics.sh`,
   `literature-retrieve.sh`, `memory-harvest.sh` — all legitimately referenced by name in
   literature's own skill/agent docs without needing to be in literature's own manifest).
3. **False-positive avoidance — already-declared exclusion**: Drop any name present in the
   current extension's own `jq -r '.provides.scripts[]?' manifest.json`.
4. **False-positive avoidance — incidental-mention exclusion**: Because a plain filename-token
   grep will over-match prose comparisons (e.g. `skill-literature/SKILL.md:1723`, "matches
   `memory-harvest.sh` pattern" — a description, not an invocation), the core-exclusion in step
   2 already absorbs the one observed instance of this in the literature extension (since
   `memory-harvest.sh` is core-owned). For extensions without this natural absorption, recommend
   scoping the grep to lines containing an invocation-shaped context — e.g. requiring the match
   be preceded on the same line by one of `bash `, `$(`, `` ` ``, `/`, `SCRIPT_DIR`, or be inside
   a fenced code block — to keep the check tight. Given the one real-world case observed
   resolves cleanly via core-exclusion, a simple first version can skip this refinement and add
   it only if false positives appear in practice (start permissive-report/`fail`, iterate).
5. **Verdict**: for each remaining name, `fail "script referenced in docs/skills/agents but NOT
   in provides.scripts: $name"` if it is not already in the (now-filtered) declared set. This
   naturally reproduces exactly the 7+1 currently-missing entries when run against the
   pre-fix manifest, and will pass cleanly once this task's manifest fix lands — giving a
   regression guard against this exact class of bug recurring for literature or any other
   extension.

This satisfies the existing exit-code convention (adds to `$FAILURES`, no changes to the
script's overall exit-code contract needed).

#### 8. `LITERATURE_DIR` documentation (Goal 7)

`EXTENSION.md:53` currently states: "Set `LITERATURE_DIR=/home/benjamin/Projects/Literature` in
`.claude/settings.json` (already configured)." This claim is **false** in this repo today:
`grep -rn "LITERATURE_DIR" .claude/settings.json .claude/settings.local.json
.claude/templates/settings.json` returns zero hits — `LITERATURE_DIR` is not set anywhere.
`literature-discover.sh:36` already defaults it correctly:
`LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"`, so the absence is harmless in
practice, but the doc text is misleading (implies action already taken that was not taken, and
hardcodes a personal absolute path as if canonical). Recommend replacing `EXTENSION.md:51-55`
("Centralized Repository" section) with wording that states the default
(`~/Projects/Literature` via `$HOME`) and describes `LITERATURE_DIR` as an optional override
env var / settings key a user *may* set, rather than asserting it is already configured.
`README.md:19` has similar phrasing ("configured via `LITERATURE_DIR`") but does not assert it
is already set, so only `EXTENSION.md:53` needs the correction.

### Recommendations

1. `git mv .claude/scripts/{literature-discover.sh,literature-ingest.sh,literature-search.sh,literature-build-index.sh,literature-convert.sh,literature-chunk.sh,literature-schema.sql} .claude/extensions/literature/scripts/`
2. Add all 7 `.sh` names + `literature-schema.sql` to `manifest.provides.scripts` in
   `.claude/extensions/literature/manifest.json` (currently 12 entries; will become 20).
3. Fix `literature-discover.sh:340-342` and `skill-literature/SKILL.md:1123-1125`: reorder/replace
   the `zotero-search.sh` candidate list so the flat sibling path (`$SCRIPT_DIR/zotero-search.sh`
   for the script, `.claude/scripts/zotero-search.sh` or `$(dirname "$0")/../../scripts/zotero-search.sh`
   for the skill) is primary; drop or demote the nested `.claude/extensions/literature/scripts/...`
   candidate since it is unreachable in any deployed (non-source) repo.
4. Fix `literature-briefing.sh:192,195`: replace the hardcoded
   `~/.config/nvim/.claude/scripts/literature-search.sh` with a repo-relative
   `.claude/scripts/literature-search.sh` (or a `$SCRIPT_DIR`-derived equivalent) so the emitted
   agent instructions are correct in any deployed repo.
5. Verify (no code change expected, but confirm post-migration) `zotero-chunk.sh:38-40`'s
   `LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"` still resolves correctly under the
   flat-deploy model — it should, since all target scripts land in the same flat directory.
   Consider simplifying to a plain `$SCRIPT_DIR`-sibling reference in a follow-up for clarity,
   but this is not required for correctness.
6. In this repo, run `manager.reload("literature")` (via `<leader>al` picker) after steps 1-2 to
   regenerate this repo's own flat `.claude/scripts/` copies from the new canonical source.
7. Add `check_referenced_scripts_declared` to `.claude/scripts/check-extension-docs.sh` per
   Finding #7, wired into the per-extension loop alongside the other `check_*` calls.
8. Correct `EXTENSION.md:51-55` per Finding #8 (remove the false "(already configured)" claim).
9. Explicitly exclude `literature-audit.sh` from migration (leave in place or handle via a
   separate cleanup task) — it is not referenced by the extension.

## Decisions

- **Do not touch `literature-retrieve.sh`** — confirmed core-owned in both manifest and source
  location; out of scope.
- **Do not modify `sync.lua` / "Load Core"** — confirmed it never sources non-core extension
  scripts; irrelevant to this bug.
- **Package `literature-schema.sql` via `provides.scripts`, not `provides.data`** — `data` is
  directory-shaped with merge-preserve semantics unsuited to a versioned schema asset.
- **Exclude `literature-audit.sh` from migration** — zero references anywhere in the extension's
  commands/skills/agents/docs; treat as orphaned dev tooling, not part of this fix's scope.
- **`git mv`, not `git cp`** — per the dual-copy model already used by every other packaged
  script in this repo (extension source is canonical; flat `.claude/scripts/` is a regenerable
  deployment artifact), followed by a one-time `reload` to repopulate this repo's own flat
  copies from the new source.

## Risks & Mitigations

- **Risk**: `git mv` breaks this repo's own `/literature` and `/cite` commands between the move
  and the `reload` step. **Mitigation**: perform steps 1-2 (move + manifest update) and step 6
  (reload) as a single atomic implementation phase; do not commit/pause between them.
- **Risk**: the new `check_referenced_scripts_declared` doc-lint rule produces false positives
  on other extensions (e.g., prose examples referencing generic script names). **Mitigation**:
  the core-exclusion + already-declared-exclusion filters absorb the one real case observed in
  literature; recommend running the new check against **all** extensions during implementation
  and manually triaging any new failures before merging, rather than assuming zero false
  positives blind.
- **Risk**: `zotero-chunk.sh`'s `LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"` could
  mask a latent bug if any future extension script is placed inside a *nested* subdirectory
  under `scripts/` (the flat model assumes all `provides.scripts` entries are direct siblings
  in one flat directory). **Mitigation**: not a concern for this task (no nesting proposed), but
  worth a one-line comment in `zotero-chunk.sh` documenting the flat-deploy assumption so future
  editors don't reintroduce nested-path bugs.

## Context Extension Recommendations

- **Topic**: Extension script deployment model (flat vs. nested).
- **Gap**: No existing `.claude/context/` file documents that `provides.scripts` always
  flat-deploys to `{base_dir}/scripts/` regardless of extension, which is a non-obvious and
  easily-misunderstood detail (as evidenced by the two nested-path bugs found in this research).
- **Recommendation**: Add a short note to
  `.claude/context/guides/extension-development.md` (or create one if a suitable file doesn't
  exist) stating explicitly: "`provides.scripts` entries are copied flat into
  `{base_dir}/scripts/` in the consuming repo, mixed with core and other extensions' scripts —
  never into `{base_dir}/extensions/{name}/scripts/`. Only `manifest.json` is copied into the
  per-extension `extensions/{name}/` directory (via `copy_manifest`)." This would have prevented
  both nested-path bugs found in this research.

## Appendix

### Search queries / commands used

```bash
jq '.provides.scripts' .claude/extensions/literature/manifest.json
jq '.provides.scripts' .claude/extensions/core/manifest.json
grep -n '\.sh\b' .claude/extensions/literature/commands/{literature,cite}.md
grep -n '\.sh\b' .claude/extensions/literature/skills/skill-{literature,cite}/SKILL.md
grep -n '\.sh\b' .claude/extensions/literature/agents/literature-agent.md
grep -rln "literature-audit\|literature-schema.sql" .claude/
diff .claude/scripts/generate-todo.sh .claude/extensions/core/scripts/generate-todo.sh
bash .claude/scripts/check-extension-docs.sh --quiet
```

### Key files (for the planner)

- `.claude/extensions/literature/manifest.json` — add 8 entries to `provides.scripts`
- `.claude/scripts/{literature-discover,literature-ingest,literature-search,literature-build-index,literature-convert,literature-chunk}.sh`, `.claude/scripts/literature-schema.sql` — `git mv` targets
- `.claude/extensions/literature/scripts/literature-discover.sh:340-342` — candidate-path fix
- `.claude/extensions/literature/skills/skill-literature/SKILL.md:1123-1125` — candidate-path fix
- `.claude/extensions/literature/scripts/literature-briefing.sh:192,195` — hardcoded-path fix
- `.claude/extensions/literature/scripts/zotero-chunk.sh:38-40` — verify only, optional cleanup
- `.claude/extensions/literature/EXTENSION.md:51-55` — doc correction
- `.claude/scripts/check-extension-docs.sh` — new `check_referenced_scripts_declared` function
- `lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342,588-617` — reference for how
  `copy_scripts`/`copy_manifest` actually work (no changes needed here)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua:732,844` — reference showing
  "Load Core" is out of scope (no changes needed here)
