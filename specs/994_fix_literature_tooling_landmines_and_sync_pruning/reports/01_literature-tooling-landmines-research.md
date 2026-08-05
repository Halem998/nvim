# Research Report: Task #994

**Task**: 994 - Fix literature-extension tooling landmines and sync pruning
**Started**: 2026-08-05T20:00:00Z
**Completed**: 2026-08-05T20:38:00Z
**Effort**: ~1.5 hours
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/literature/scripts/zotero-search.sh` (487 lines, full read)
- `agent-system/extensions/literature/scripts/deprecated/zotero-index-add.sh`, `deprecated/README.md`
- `agent-system/extensions/literature/agents/literature-agent.md`, `skills/skill-literature/SKILL.md`
- `agent-system/extensions/literature/context/project/literature/patterns/*.md`, `context/guides/literature-organization.md`
- `~/Philosophy/Papers/PossibleWorlds/.claude/**` (live downstream repo that surfaced the bug reports)
- `~/Philosophy/Papers/PossibleWorlds/specs/054_ingest_presheaf_semantics_literature/reports/01_literature-acquisition-research.md` (the triggering report)
- `lua/neotex/plugins/ai/shared/extensions/{init,state,loader}.lua` (deploy engine source)
- `agent-system/extensions/core/scripts/deploy-headless.sh`
- Two empirical scratch-tree deploy runs (see Findings §2)
**Artifacts**:
- This report: `specs/994_fix_literature_tooling_landmines_and_sync_pruning/reports/01_literature-tooling-landmines-research.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Item 1 (zotero-search.sh quoting)**: Confirmed as a real, undocumented gap. No warning exists
  anywhere today (script header, `literature-agent.md`, `skill-literature/SKILL.md`, or any
  `context/` file) that a multi-word query must be passed as separate shell arguments. Internal
  callers (`literature-discover.sh`'s `tier2_search()`) already do this correctly via an array
  expansion, so the bug is purely a documentation gap for human/agent direct invocation, not a
  script defect.
- **Item 2 (deployment hygiene) — the verification surfaced a bug bigger than the one it was
  checking for.** The "wipe+regenerate prunes by construction" premise holds only for repos
  already state-tracked by the new engine. For a repo bootstrapped under the retired glob engine
  (exactly PossibleWorlds' situation, and likely other older downstream repos), I empirically
  reproduced two distinct, serious failure modes:
  - `deploy-headless.sh` (default, non-destructive resync): silently drops **every
    non-core-extension section from `CLAUDE.md`** (e.g. all of the literature extension's
    "Zotero Integration" content) on its very first run against such a repo, while leaving the
    stale `zotero-index-add.sh` and stale `literature-agent.md` row physically untouched. Root
    cause: `manager.resync_all` only resyncs extensions present in the root
    `.claude-extensions.json`; only `core` has "legacy detection" migration logic
    (`detect_legacy_core`), so pre-existing extensions like `literature` are invisible to the new
    engine and their CLAUDE.md contributions are dropped, not regenerated.
  - `deploy-headless.sh --wipe`: on the same class of repo, deletes `.claude/` entirely and then
    "regenerates 0 extensions" (verified: `.claude/` ends up **completely absent**), because
    `manager.wipe` -> `manager.regenerate` also reloads only extensions found in the (still-empty)
    root state file.
  - This is a deploy-engine (Lua, `lua/neotex/plugins/ai/shared/extensions/`) defect, entirely
    outside this task's `agent-system/extensions/literature/**` file scope and outside "run deploy
    and verify" as originally framed. **Recommendation: do not attempt to fix it here — spin off
    a dedicated task** ("extend `detect_legacy_core`-style migration to all previously-loaded
    extensions, not just core") before relying on `deploy-headless.sh`/`--wipe` as the pruning
    mechanism for any legacy-bootstrapped repo, including PossibleWorlds.
  - The one thing that *is* confirmed true: on a repo that is *already* correctly state-tracked
    (post-migration, `.claude-extensions.json` lists the extension), a resync/regenerate does
    prune retired-script/stale-reference drift correctly — this repo's own `.claude/` tree has no
    trace of `zotero-index-add.sh` anywhere (it isn't even a loaded extension here), consistent
    with clean pruning once state tracking is intact.
- **Item 3 (deprecated/README.md rationale)**: `deprecated/README.md` currently states only that
  `zotero-index-add.sh` was "superseded by inline `jq` logic" — it does **not** yet record the
  specific rationale requested (20-field schema vs. the 4-field `{doc_id, relevance, added,
  source}` shape `literature-briefing.sh` actually reads, the `zot` CLI dependency, and the
  undefined `/zotero --setup` command). This is missing and should be added.

## Context & Scope

The task originates from a downstream research report (PossibleWorlds repo,
`specs/054_ingest_presheaf_semantics_literature/reports/01_literature-acquisition-research.md`)
that hit two real landmines while trying to use the literature tooling: (1) a `zotero-search.sh`
quoting gotcha that silently returns zero results, and (2) `zotero-index-add.sh` being present
and apparently endorsed by `.claude/CLAUDE.md`/`literature-agent.md` as the way to register items
into the per-repo sub-index, when it actually targets a different, unused file
(`specs/zotero-index.json` instead of `specs/literature-index.json`) and depends on an undefined
`/zotero --setup` command. File scope for any fix is `agent-system/extensions/literature/scripts/`
and `agent-system/extensions/literature/context/` — the source store, never `.claude/`.

## Findings

### 1. zotero-search.sh multi-term argument behavior (Item 1)

`agent-system/extensions/literature/scripts/zotero-search.sh` (line ~25) documents scoring
semantics ("Scoring is additive with OR semantics across query terms") but never states, anywhere
in the file, that this requires **separate shell arguments** rather than one quoted phrase. The
`USAGE:` line reads `zotero-search.sh [OPTIONS] QUERY [QUERY...]`, which is technically correct
but easy to misread as "one query string, optionally repeated" rather than "space-split your
query terms yourself before invoking."

Confirmed via the downstream report (line 69 of the triggering report): `zotero-search.sh
"Burgess axioms tense logic"` (one quoted arg) returns **zero results**, while `zotero-search.sh
Burgess axioms tense logic` (four separate args) succeeds — every individual term matches when
passed separately.

Internal callers are already correct:
- `literature-discover.sh` `tier2_search()` (line ~375) calls
  `"$zotero_script" --format=json --limit="$DISCOVER_LIMIT" "${FILTERED_TERMS[@]}"` — a bash
  array expansion, i.e. already multiple args.
- `skill-cite/SKILL.md` and `skill-literature/SKILL.md` reference `{query_terms}` /
  `{terms}` placeholders in their command templates without showing a concrete multi-word
  example, so an implementer copying the pattern by hand could still get it wrong.

No file in `agent-system/extensions/literature/context/` mentions `zotero-search.sh` at all today
(grep across `context/project/literature/patterns/*.md`, `context/project/literature/domain/*.md`,
and `context/guides/literature-organization.md` returns zero hits) — so "the literature extension
context docs" the task description asks to update currently have no natural home for this note.
The closest candidates by topic:
- `context/project/literature/patterns/agent-exploration.md` — the general "how an agent explores
  literature" hub (currently only covers `literature-search.sh`, the *local corpus* search tool,
  a different script from `zotero-search.sh`, the *Zotero library* search tool). Adding a short
  "Zotero vs. corpus search" distinction plus the quoting warning here would consolidate both
  search tools in one place.
- `agents/literature-agent.md` line 110 (`invokes zotero-search.sh --format=json --limit=20
  {terms}`) is not a `context/` file but is the most concrete place an agent would copy a
  hand-written invocation from, and currently shows `{terms}` ambiguously.

**Recommendation**: add an explicit `IMPORTANT:`/warning line near the top of
`zotero-search.sh`'s `USAGE:` block and inline `show_usage()` heredoc (both copies exist in the
file — the header comment block and the `show_usage()` function duplicate the same text and must
be kept in sync), stating plainly: "Pass each search word as a SEPARATE argument — a single
quoted multi-word phrase will not match." Add the same warning to
`context/project/literature/patterns/agent-exploration.md` (new short subsection distinguishing
`literature-search.sh` from `zotero-search.sh`) and fix the `{terms}` example in
`agents/literature-agent.md` line 110 to show a concrete space-separated example.

### 2. Deployment hygiene verification — retired-script pruning (Item 2)

I ran the verification the task specifies against a scratch copy of the actual affected repo
(PossibleWorlds), rather than assuming the deploy-engine-consolidation prerequisite's "wipe path
prunes by construction" claim holds. It does not hold uniformly.

**Setup**: copied `~/Philosophy/Papers/PossibleWorlds/.claude/` into an isolated scratch git repo
(this exactly reproduces the bug repo's state: `.claude/scripts/zotero-index-add.sh` present,
`.claude/CLAUDE.md:848` and `.claude/agents/literature-agent.md:172` both carry the stale
"Add item to per-repo `specs/literature-index.json`" row, and — critically — **no root-level
`.claude-extensions.json`** exists in PossibleWorlds at all, meaning it was deployed exclusively
via the retired glob+allow-list engine and has never been touched by the new manifest-driven
engine).

**Run 1 — `deploy-headless.sh --wipe <scratch>`** (the destructive path the task's item 2
description implies should "prune by construction"):
```
[deploy-headless] Wiped and regenerated 0 extension(s) into <scratch>/.claude
```
Post-run: `<scratch>/.claude` **does not exist**. `manager.wipe` deletes the target directory
unconditionally, then calls `manager.regenerate`, which reloads only extensions found in
`manager.list_loaded(project_dir)` — itself sourced from the root `.claude-extensions.json`. Since
that file never existed for this repo, zero extensions were known to reload, so nothing was
rebuilt. This is not "prune the retired script" — it is "delete the entire deploy tree and
rebuild none of it."

**Run 2 — `deploy-headless.sh <scratch>` (default, non-destructive resync)** on a fresh copy of
the same scratch state:
```
[deploy-headless] Resynced 1 extension(s) into <scratch>/.claude
```
This mode's documented "bootstrap safety" (force-load `core` first, since a legacy repo has no
`core` entry either) worked as designed for `core` specifically — but it force-loaded **only**
`core`. The resulting root `.claude-extensions.json` now lists exactly one extension (`core`).
Consequence: `CLAUDE.md` was rewritten from 962 lines down to 629 lines — every section
contributed by `literature` (the entire "Zotero Integration" table, `--lit` sub-index docs, etc.),
`formal`, and every other previously-active extension's CLAUDE.md content is now **silently
missing**, while `.claude/scripts/zotero-index-add.sh` and `.claude/agents/literature-agent.md`'s
stale row were **left untouched** (default resync's own docstring: "Never destructive; never
removes anything" — accurate for files, but the *regenerated* `CLAUDE.md` is a computed artifact
each extension's `load()` rewrites its own section of, and only `core`'s section got rewritten
here).

**Root cause** (`lua/neotex/plugins/ai/shared/extensions/init.lua`):
- `detect_legacy_core()` (line ~175) exists specifically to handle a legacy-bootstrapped `core`
  and migrate it into the new state system on the next `core` load. There is **no equivalent
  detection for any other extension** — `literature`, `formal`, `nix`, etc. loaded under the old
  engine have no analogous migration path. `manager.resync_all()` (line ~901) and
  `manager.wipe()` -> `manager.regenerate()` both operate exclusively over
  `manager.list_loaded()`, which reads only the root `.claude-extensions.json` — never the
  per-`base_dir` `.claude/extensions.json` file that *does* still correctly list `literature` as
  active in PossibleWorlds (`.claude/extensions.json` was untouched by either run and still shows
  `literature`, `formal`, etc. as `"status": "active"`).
- This means for any repo in PossibleWorlds' situation (old engine, no root state file, multiple
  active extensions beyond core), the very first invocation of either `deploy-headless.sh` mode
  produces incomplete or destructive results, not the "verify pruning and regenerated references"
  outcome the task description's premise assumed.

**Control check — repos that are already state-tracked**: this nvim config repo's own
`.claude-extensions.json` correctly lists `core`, `email`, `memory`, `nix`, `nvim` (it never
loaded `literature` at all, so it isn't a same-extension comparison, but it demonstrates the
happy path: for extensions that *are* in the root state file, resync/regenerate works as
intended). Separately, `agent-system/extensions/literature/manifest.json` no longer declares
`zotero-index-add.sh` under `provides.scripts` (confirmed: `grep -n "zotero-index"
manifest.json` returns nothing), so once a repo's `literature` extension is properly migrated
into the root state file, a resync of `literature` specifically would correctly stop re-copying
the retired script — the manifest-side declaration is already correct. The gap is entirely in
whether `literature` (or any non-core previously-loaded extension) is discoverable to
`resync_all`/`regenerate` at all on a legacy repo.

**Scope call**: fixing `detect_legacy_core`'s single-extension limitation is a Lua deploy-engine
change under `lua/neotex/plugins/ai/shared/extensions/`, entirely outside this task's declared
`agent-system/extensions/literature/scripts/` + `agent-system/extensions/literature/context/`
file scope, and outside the "verification-plus-gap-fill, not mechanism-building" instruction for
item 2. I did **not** attempt a fix. **This should be spun off as its own task** before anyone
relies on `deploy-headless.sh` (either mode) to clean up PossibleWorlds or any other
old-engine-bootstrapped repo — running `--wipe` against PossibleWorlds today, as the task
description's phrasing might suggest doing directly on "an affected downstream repo," would
**delete its entire `.claude/` tree and not rebuild it**. This is a load-bearing finding for
whoever picks up item 2's actual remediation: PossibleWorlds' stale `zotero-index-add.sh` /
CLAUDE.md row cannot safely be cleaned up via `deploy-headless.sh` until the legacy-migration gap
is closed. In the meantime the two literal stale-reference call sites in PossibleWorlds
(`.claude/CLAUDE.md:848`, `.claude/agents/literature-agent.md:172`) are themselves downstream
deploy artifacts, not source-store files — so even a manual one-off edit there would be
overwritten by the next successful sync and isn't a durable fix; the durable fix is closing the
migration gap, then re-running deploy-headless normally.

No stale reference to `zotero-index-add.sh` exists anywhere in the source store itself
(`agent-system/extensions/literature/**` and `agent-system/extensions/core/**`) outside the
`deprecated/` directory and two harmless "Run: zotero-index-add.sh $KEY" hint strings in
`zotero-chunk.sh:145` and `zotero-attach-chunks.sh:125` (both print a next-step suggestion to
stderr; since the script itself still physically exists in `deprecated/` — never hard-deleted —
these are stale suggestions pointing at a script that's no longer wired into `manifest.json`, but
they are not schema-table claims and are lower priority than the CLAUDE.md/agent-doc table rows,
which don't exist in the source store at all — confirmed no `merge-sources/*.md` file in
`agent-system/extensions/core/` or `agent-system/extensions/literature/` contains
`zotero-index-add`). The stale CLAUDE.md/literature-agent.md rows visible in PossibleWorlds today
are themselves **artifacts of the old deploy** (pre-dating the retirement), not evidence of a
current source-store defect — there is nothing to "fix" in the source references beyond what
item 3 covers.

### 3. deprecated/README.md retirement rationale (Item 3)

`agent-system/extensions/literature/scripts/deprecated/README.md` exists and documents
`zotero-index-add.sh` and `zotero-index-remove.sh`, but its stated rationale is generic:

> **zotero-index-add.sh** - Formerly added entries to the Zotero index; superseded by the inline
> `jq` logic in `skills/skill-literature/SKILL.md`. Quarantined during the same removal that
> dropped it from `manifest.json`.

This is missing the specific rationale the task requests, which the downstream research report
independently rediscovered by reading the script (confirmed by direct read of
`deprecated/zotero-index-add.sh`, lines 1-30 and the "Build 20-field entry JSON" section around
line 260):
- The script builds a **20-field** entry (`zotero_key`, `citation_key`, `title`, `authors`,
  `year`, `item_type`, `abstract_snippet`, `keywords`, `tags`, `collections`, `has_pdf`,
  `pdf_path`, `has_chunks`, `chunk_dir`, `chunk_count`, `token_count`, `relevance_keywords`,
  `notes_summary`, `added_at`, `last_retrieved`) written to `specs/zotero-index.json`.
- `literature-briefing.sh` (the actual `--lit` consumer) reads a much simpler 4-field shape
  (`{doc_id, relevance, added, source}`) from a **different file**,
  `specs/literature-index.json` — confirmed by the schema quoted in the downstream report's
  Appendix ("Per-repo sub-index: `specs/literature-index.json` (schema `{project, literature_dir,
  created, entries: [{doc_id, relevance, added, source}]}`)").
- The script also depends on the `zot` CLI (`command -v jq` is checked, but `zotero-read.sh` calls
  are the actual `zot`-dependent step) and prints setup instructions referencing `/zotero --setup`
  — not a command defined anywhere in this project's current command set (confirmed: no
  `commands/zotero.md` exists in `agent-system/extensions/literature/commands/`, only `cite.md`
  and `literature.md`).
- Repairing the script to be useful again would require schema translation (20-field → 4-field,
  different target file, dropping the `zot`/`--setup` dependency) rather than a small fix — this
  is the actual reasoning for retiring it in favor of the documented `jq` append pattern in
  `skill-literature/SKILL.md`'s "Sub-Index Management" section (confirmed present at that file's
  line ~1622 area, "Add: Append a Document Entry").

**Recommendation**: expand the `zotero-index-add.sh` bullet in `deprecated/README.md` with this
concrete schema-mismatch/dependency rationale, so a future reader doesn't have to re-derive it
from the script body (as the downstream report's author had to).

## Decisions

- Item 1 fix location: script header (both the top-comment `USAGE:`/`DESCRIPTION:` block and the
  `show_usage()` heredoc, which duplicate each other and must both be updated) plus
  `context/project/literature/patterns/agent-exploration.md` (best-fit existing context file —
  no file currently mentions `zotero-search.sh` at all) plus a fix to the ambiguous `{terms}`
  example in `agents/literature-agent.md:110`.
- Item 2: verification performed empirically via scratch-tree deploy runs rather than assumed;
  the "wipe+regenerate prunes by construction" premise is **false** for any repo bootstrapped
  under the retired glob engine with more than just `core` active (which includes
  PossibleWorlds). No mechanism-building attempted (per instruction); recommend spinning off a
  dedicated task to extend `detect_legacy_core`-style migration to all extensions, scoped to
  `lua/neotex/plugins/ai/shared/extensions/init.lua`, outside this task's file scope.
- Item 3: rationale gap confirmed real; recommend a straightforward `deprecated/README.md`
  expansion with the schema/dependency specifics above.

## Risks & Mitigations

- **Risk**: an implementer reads item 2's task description ("run the consolidated deploy against
  an affected downstream repo... and verify") and runs `deploy-headless.sh --wipe` directly
  against the live PossibleWorlds repo. **Mitigation**: this report documents that doing so today
  would delete `~/Philosophy/Papers/PossibleWorlds/.claude/` and rebuild nothing — the
  verification MUST be done against a scratch copy (as this report did), and the resulting
  finding routed to a new task rather than "fixed" by force-deploying onto the live repo.
- **Risk**: fixing only the two `zotero-index-add.sh` hint strings in `zotero-chunk.sh` /
  `zotero-attach-chunks.sh` without also expanding `deprecated/README.md` would leave the
  rationale gap (item 3) unresolved even though the hint strings themselves are low-priority.
- **Risk**: editing `.claude/**` directly on any downstream repo (including PossibleWorlds) to
  patch the stale CLAUDE.md/literature-agent.md rows would violate the source-store/deploy
  boundary and be silently overwritten on the next real sync — the only durable fix is at the
  source-store level (item 3's rationale addition doesn't touch these generated-doc rows at all;
  those rows are themselves stale pending the item-2 migration-gap fix, not a content bug in the
  source store).

## Context Extension Recommendations

- **Topic**: legacy multi-extension migration gap in the deploy engine
- **Gap**: `lua/neotex/plugins/ai/shared/extensions/init.lua`'s `detect_legacy_core()` only
  migrates `core`; no equivalent exists for other extensions loaded under the retired glob
  engine, so `manager.resync_all`/`manager.wipe` silently drop or fail to rebuild their CLAUDE.md
  contributions on old-engine-bootstrapped repos.
- **Recommendation**: this is worth a `.claude/context/` note (or a `.memory/` entry) once a
  follow-up task fixes it, documenting the fix and the empirical repro steps in this report so
  the next verification pass doesn't have to rediscover them from scratch.

## Appendix

### Search queries / commands used
- `grep -rn "zotero-index-add"` across `agent-system/` and this repo's own `.claude/`.
- `grep -rln "zotero-search"` across `agent-system/extensions/literature/`.
- Direct reads: `zotero-search.sh` (full), `deprecated/zotero-index-add.sh` (full),
  `deprecated/README.md` (full), `literature-agent.md` (relevant sections), `literature-discover.sh`
  (`tier2_search()`), `init.lua`/`state.lua` (`resync_all`, `wipe`, `list_loaded`,
  `detect_legacy_core`), `deploy-headless.sh` (usage/mode docs).
- Empirical: two scratch-tree copies of `~/Philosophy/Papers/PossibleWorlds/.claude/`, one run
  through `deploy-headless.sh --wipe <scratch>`, one through `deploy-headless.sh <scratch>`
  (default resync); before/after `grep`/`ls`/`wc -l` diffs on `CLAUDE.md`,
  `scripts/zotero-index-add.sh`, `agents/literature-agent.md`, and the resulting root
  `.claude-extensions.json`.

### References
- Triggering report:
  `~/Philosophy/Papers/PossibleWorlds/specs/054_ingest_presheaf_semantics_literature/reports/01_literature-acquisition-research.md`
- `agent-system/extensions/literature/scripts/zotero-search.sh`
- `agent-system/extensions/literature/scripts/deprecated/{README.md,zotero-index-add.sh}`
- `agent-system/extensions/literature/agents/literature-agent.md`
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md`
- `agent-system/extensions/literature/context/project/literature/patterns/agent-exploration.md`
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (`detect_legacy_core`, `manager.resync_all`,
  `manager.wipe`, `manager.regenerate`)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` (`get_state_path`, `M.read`)
- `agent-system/extensions/core/scripts/deploy-headless.sh`
