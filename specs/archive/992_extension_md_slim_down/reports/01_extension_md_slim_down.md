# Research Report: Task #992

**Task**: 992 - Bring every EXTENSION.md into conformance with extension-slim-standard.md and Rule U
**Started**: 2026-08-09
**Completed**: 2026-08-09
**Effort**: Medium (2 sub-scopes: 6-file content migration + 2-file dead-file resolution + one lint-script change)
**Dependencies**: index-entries.json schema-conformance work (Rule T) -- confirmed already landed, zero live violations
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`,
  `agent-system/extensions/core/scripts/check-extension-docs.sh`, all 19 extension `EXTENSION.md`/`manifest.json`/`index-entries.json`/`context/` trees,
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`generate_claudemd`), core's `docs/guides/creating-extensions.md`, `docs/guides/adding-domains.md`,
  `context/guides/extension-development.md`, `docs/architecture/extension-system.md`, `docs/architecture/system-overview.md`
- Live lint run: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
**Artifacts**:
- This report: `specs/992_extension_md_slim_down/reports/01_extension_md_slim_down.md`
**Standards**: report-format.md, subagent-return.md, extension-slim-standard.md

## Executive Summary

- **Re-measured counts match the task description exactly, no drift**: literature 169L, email
  106L, lean 73L, cslib 71L, present 64L, nix 62L (sub-scope A, 6 files) plus core 62L
  (sub-scope B, dead file). `slidev` is 12L -- under the 60-line cap, so it currently produces
  no Rule U advisory, but it is still a **dead** file per sub-scope B's own definition and must
  be resolved, not merely left alone because it happens to already be short.
- **Both dead files are provably dead**, confirmed by reading `merge.lua`'s `generate_claudemd()`
  (lines 807-838): it looks up `extension.manifest.merge_targets[merge_key]` and only reads a
  fragment when that key resolves. `core`'s `merge_targets.claudemd.source` is
  `"merge-sources/claudemd.md"` (not `"EXTENSION.md"`), and `slidev`'s manifest has no
  `merge_targets.claudemd` key at all -- both `EXTENSION.md` files are structurally unreachable
  from CLAUDE.md generation, for every one of the 19 extensions.
- **The correct sub-scope B outcome is DELETE, not "teach the checker and leave the file
  in place"**: both files are 100% content-duplicates of their extension's own `README.md`
  (verified line-by-line for core and slidev below), and the project's own documentation
  (`docs/guides/creating-extensions.md`'s "Resource-Only Extensions" section, using **slidev
  itself** as the canonical example) already states the correct pattern is **no** `EXTENSION.md`
  at all for a resource-only extension. Deletion is the fix that matches already-declared
  project intent; it is not a new precedent.
- **`check-extension-docs.sh` line 1278's required-file check
  (`check_file "$ext_path/EXTENSION.md" "EXTENSION.md"`) is unconditional and must change** --
  it currently hard-`fail()`s (not advisory) if `EXTENSION.md` is missing, for every extension,
  with no awareness of `merge_targets.claudemd.source`. This is the one code change needed to
  make deletion possible; Rule U (`check_extension_md_length`, line 737) needs the identical
  authority fix so it does not misapply the 60-line budget to a file that was never meant to
  carry it.
- **Sub-scope A migration targets are already mapped per extension** (see Findings below):
  every one of the 6 over-length files decomposes cleanly into KEEP (header/routing/commands/
  pointers) vs. MOVE (detail sections), using each extension's **already-existing**
  `context/project/{ext}/{domain,patterns,tools}/` taxonomy. Two dedup risks were found and
  should be checked by the implementer before creating new files: `cslib`'s "CI Verification
  Pipeline" section overlaps `tools/lake-commands.md`, and `nix`'s "Build Verification"/"MCP-NixOS
  Integration" sections overlap `tools/nixos-rebuild-guide.md`/`tools/home-manager-guide.md`.
- **One dangling reference discovered outside this task's direct scope**: `email/EXTENSION.md`
  cites `domain/index-architecture.md`, which does not exist on disk in
  `email/context/project/email/domain/`. The migration destination for the "Account isolation,
  folder-scoped only" bullet is a natural place to create this missing file, resolving the
  dangling reference as a side effect.
- **`lean`'s context subdomain is `lean4`, not `lean`** -- new files must land under
  `context/project/lean4/{domain,patterns,tools}/`, matching the extension's existing
  (non-empty) tree, not a new `context/project/lean/` directory.

## Context & Scope

Task 992 has two sub-scopes against `check-extension-docs.sh`'s Rule U
(`check_extension_md_length`), which is currently gated `advisory` via
`SCHEMA_CONFORMANCE_GATE_MODE` (default `advisory`, comment at line 654 explicitly says: promote
to `hard` only once the index-entries.json migration and this EXTENSION.md slim-down land):

- **(A) Trim 6 live, over-length `EXTENSION.md` files** to extension-slim-standard.md's 4-section,
  60-line shape, moving detail content into each extension's `context/project/{ext}/` tree with
  schema-conformant `index-entries.json` entries.
- **(B) Resolve 2 dead `EXTENSION.md` files** (`core`, `slidev`) that are never read by
  `generate_claudemd()` -- decide delete-vs-redefine-authority, and implement the decision, since
  trimming a dead file (the wrong outcome the task explicitly calls out) would still leave 100%
  duplicate, unreachable content sitting in the tree.

Verification bar: `check-extension-docs.sh` reports **zero Rule U advisories** across all 19
extensions, and every new context file has a schema-conformant `index-entries.json` entry
(required keys: `path`, `domain`, `subdomain`, `summary`, `line_count`; forbidden keys:
`description`, `tags`; `load_when` restricted to `agents`/`commands`/`task_types`/`always` --
per `context/index.schema.json`, confirmed already reconciled: a live Rule T run today reports
**0** violations across all 19 extensions' `index-entries.json`, so the schema-migration
prerequisite has already landed and the new entries need only match that existing shape).

This report covers investigation and a migration map only -- no files were modified. Sub-scope A
content extraction (writing new context files, trimming each `EXTENSION.md` to the 4 required
sections, adding index entries) and sub-scope B's manifest/checker/doc edits are implementation
work for `/plan` and `/implement`.

## Findings

### The Standard (extension-slim-standard.md)

- **Hard limit**: 60 lines, enforced (advisory today) by Rule U.
- **Four required sections only**, with per-section budgets: Header 3-5 lines, Routing Table
  5-15 lines, Command List 5-15 lines, Context Pointers 3-5 lines (max 5 `@`-pointers). Budgets
  sum to 40 max, leaving slack under the 60-line ceiling.
- **Move-out categories** (table in the standard): usage examples -> `patterns/`; architecture
  docs, conversion tables, migration guides, troubleshooting, mode descriptions -> `domain/`;
  prerequisites/installation, MCP tool integration -> `tools/`; data schemas -> `patterns/`.
- **Every new context file needs an `index-entries.json` entry** conforming to
  `context/index.schema.json` (the standard's own worked example is stale relative to the schema
  in one respect: it shows a `description` key in one placeholder location which the schema
  actually forbids -- the schema wins per the standard's own disclaimer; do not copy the
  `description` key literally).
- **Migration Template** worked example (`filetypes`, 143L -> ~40L) is the concrete pattern to
  replicate: Header + Skill-Agent Mapping + Commands + `@`-Context pointers only.

### Rule U mechanics (check-extension-docs.sh)

- `check_extension_md_length()` (line 737): `wc -l` on `$ext_path/EXTENSION.md`; if `>60`, calls
  `schema_conformance_report()`, which is `fail()` under `SCHEMA_CONFORMANCE_GATE_MODE=hard` or
  an `info()` advisory line under the current default `advisory`. **This is the gate the follow-on
  flip to `hard` depends on being clean.**
- **Separately**, line 1278's `check_file "$ext_path/EXTENSION.md" "EXTENSION.md"` is an
  unconditional **hard `fail()`** (not routed through `schema_conformance_report()`,
  not gated by any env var) if the file is missing or empty, for every extension with no
  exception. This is the check that blocks simple deletion for sub-scope B and is the one line
  that needs the `merge_targets.claudemd.source`-authority fix.
- Rule E (`check_referenced_scripts_declared`, line 943-944) also scans
  `"$ext_path/EXTENSION.md"` for `*.sh`/`*.sql` filename mentions; trimming content out of
  EXTENSION.md only shrinks the text Rule E scans (all currently-mentioned scripts are already
  declared in `provides.scripts`, confirmed by today's clean lint run), so this is a
  non-issue for sub-scope A, not a new failure surface.

### Live Rule U violator baseline (re-measured, current)

| Extension | Lines | Sub-scope | Status confirmed |
|---|---|---|---|
| literature | 169 | A (trim) | over limit, live merge source |
| email | 106 | A (trim) | over limit, live merge source |
| lean | 73 | A (trim) | over limit, live merge source |
| cslib | 71 | A (trim) | over limit, live merge source |
| present | 64 | A (trim) | over limit, live merge source |
| nix | 62 | A (trim) | over limit, live merge source |
| core | 62 | B (dead) | over limit AND dead -- never read by `generate_claudemd()` |
| slidev | 12 | B (dead) | under limit but dead -- never read by `generate_claudemd()`, and the project's own docs say it should not exist |

All other 11 extensions (`filetypes`, `epidemiology`, `formal`, `founder`, `latex`, `memory`,
`nvim`, `python`, `typst`, `web`, `z3`) are already at or under 60 lines and untouched by this
task.

### Sub-scope B: dead-file evidence and recommended resolution

**Mechanism** (`merge.lua` `generate_claudemd()`, lines 807-838): for each loaded extension, it
reads `extension.manifest.merge_targets[merge_key]` (merge_key = `"claudemd"`); if that key is
absent, or its `.source`/`.target` are absent, the extension contributes **nothing** to CLAUDE.md
-- no error, no fallback to a top-level `EXTENSION.md`, just silent exclusion from the fragment
list. There is no code path anywhere that reads `core/EXTENSION.md` or `slidev/EXTENSION.md`.

- **`core`**: `manifest.json`'s `merge_targets.claudemd.source` = `"merge-sources/claudemd.md"`
  (633 lines -- the actual CLAUDE.md core section, a structurally different document with a
  different purpose than the picker-loaded-fragment pattern the 60-line budget was calibrated
  for). `core/EXTENSION.md` (62L) is a **separate**, hand-written "extension overview" doc whose
  content (category counts table, "Key Capabilities", "Usage Notes", "Dependencies", "Related
  Files") is a near-total subset of `core/README.md` (180L) -- verified by reading both files in
  full. Nothing in `core/EXTENSION.md` is unique. `core/README.md` line 177 has one stale
  cross-reference to `core/EXTENSION.md` as "Detailed capability inventory" that must be removed
  or repointed if the file is deleted.
- **`slidev`**: `manifest.json` has no `merge_targets.claudemd` key at all (only `merge_targets.
  index`). `slidev/EXTENSION.md` (12L) is a strict content subset of `slidev/README.md` (85L,
  same animation/CSS-preset catalog, same dependency-declaration instructions). Critically,
  `docs/guides/creating-extensions.md`'s "Resource-Only Extensions" section (lines ~213-244)
  uses **slidev itself, by name**, as the worked example of the pattern, and its "Key
  characteristics" bullet list states explicitly: *"No `EXTENSION.md` or `claudemd` merge
  target (nothing included in CLAUDE.md)."* Slidev's `EXTENSION.md` existing at all is a
  standing violation of the project's own already-written guidance for this exact extension.

**Recommendation: DELETE both files**, not "redefine authority and leave them in place." Reasons:
1. Zero unique content in either file (fully duplicated in each extension's own `README.md`).
2. The project's documentation already prescribes deletion for the resource-only case (slidev)
   and already treats core's real CLAUDE.md content as living in `merge-sources/claudemd.md`,
   not `EXTENSION.md` -- keeping an unused, drifting duplicate around after already declaring
   this contradicts the intent those docs express.
3. Applying Rule U's 60-line budget to whatever `merge_targets.claudemd.source` names (Option 2
   read literally) does not make sense for `core`: its real claudemd source is 633 lines by
   design (it is the foundational, always-active CLAUDE.md section, not a picker-loaded
   extension fragment) -- redirecting Rule U's length check at it would either force a nonsensical
   60-line cap onto core's real CLAUDE.md content, or require a second exemption carve-out, adding
   complexity for no benefit once the dead file is simply removed.

**Required companion change to `check-extension-docs.sh`** (this is not optional under either
option, since line 1278's required-file check is currently unconditional and would `fail()` the
moment `core/EXTENSION.md` or `slidev/EXTENSION.md` is deleted): make the required-file check
`merge_targets.claudemd.source`-authoritative --
- read `claudemd_source=$(jq -r '.merge_targets.claudemd.source // empty' "$ext_path/manifest.json")`
- require `$ext_path/EXTENSION.md` to exist only when `claudemd_source == "EXTENSION.md"` (the
  default/expected value for all 17 non-core, non-slidev extensions)
- when `claudemd_source` is empty (no claudemd merge target -- resource-only extensions like
  slidev) or points elsewhere (core's `merge-sources/claudemd.md`), do not require
  `EXTENSION.md` to exist at all, and skip Rule U's length check for that extension (it has no
  EXTENSION.md-shaped merge fragment to budget).

This single authority fix serves both extensions uniformly (no extension-name special-casing)
and matches the pattern `docs/guides/creating-extensions.md` and
`context/guides/extension-development.md` already document in prose (the code was simply never
updated to match).

**Documentation cross-references to update alongside the code change** (both describe
`EXTENSION.md` as unconditionally "(REQUIRED)"):
- `docs/architecture/extension-system.md` line 89: `EXTENSION.md ... (REQUIRED)` -- should note
  the `merge_targets.claudemd.source`-conditional requirement.
- `docs/guides/adding-domains.md` line 46: `EXTENSION.md # CLAUDE.md merge content (required)` --
  same.
- `core/README.md` line 177: drop or repoint the dead cross-reference to `core/EXTENSION.md`.

### Sub-scope A: per-extension migration map

For each file: current section list with line ranges, KEEP/MOVE verdict, and destination
(destination directories already exist for all six extensions except `lean`, see the `lean`
namespace note below). Content sourced from the full text of each `EXTENSION.md`, read in full
during this research pass.

**literature (169L -> target ~45-55L)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-6) | KEEP, trim to 3-5L | -- |
| Dependencies (7-13) | MOVE | `domain/` new file (dependency/filetypes-non-transitivity note) |
| Global Repository and Per-Repo Sub-Index (15-25) | MOVE, check dedup first | Likely **merge into existing** `domain/literature-index.md` (its own summary already claims "global Literature/ repo structure, per-repo sub-index" -- read it before creating a second file) |
| Briefing+Tools Agent Pattern (27-40) | MOVE | `patterns/` new file |
| Sparse-Coverage Detection (42-68) | MOVE, compress | `domain/` new file -- note lines 65-68 already point at `merge-sources/claudemd.md`'s "Interactive Sub-Index Setup Detection" section as the fuller authority; the detail here already duplicates that CLAUDE.md content, so the destination file can be short and mostly a pointer |
| Two-Mode /literature Command (70-88) | MOVE | `patterns/` new file |
| Centralized Repository (90-101) | MOVE | `tools/` new file (env var / settings key config) |
| Format Decision (103-113) | MOVE, mostly delete | Already has "See `context/project/literature/domain/format-decision.md`" -- the surrounding paragraph is redundant summary of a file that already exists; keep one line + pointer |
| Zotero Integration prose (115-123) | MOVE | `domain/` new file |
| Zotero script table (124-133) | MOVE | `tools/` new file |
| Skill-Agent Mapping (135-140) | KEEP | -- |
| Commands table (142-151) | KEEP | -- |
| /cite Command table + workflow (153-169) | KEEP table rows (fold into Command List), MOVE workflow prose (164-169) | `patterns/` new file for workflow prose |

**email (106L -> target ~40-50L)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-5) | KEEP | -- |
| Task-Type Routing table (7-11) | KEEP | -- |
| Skill-Agent Mapping (13-19) | KEEP | -- |
| Commands table (21-29) | KEEP | -- |
| Safety Invariants (31-98, 68 lines -- the bulk of the file) | MOVE, split | `domain/` -- several bullets already cite `wrapper-contracts.md §2/§13`, `domain/staleness-detection.md`, `domain/index-architecture.md` (**does not exist on disk today -- dangling reference, see below**); consolidate remaining invariant bullets not already covered by an existing domain file into 1-2 new `domain/` files (e.g. `domain/safety-invariants.md`) |
| Key Technologies (100-106) | MOVE | `domain/` new file, or fold into whichever safety-invariants file is created |

**Dangling reference found**: `email/EXTENSION.md` line 71 says "see ... `domain/index-architecture.md`" but `email/context/project/email/domain/` only contains `archive-mode-risk.md`,
`staleness-detection.md`, `wrapper-contracts.md` -- no `index-architecture.md`. The "Account
isolation, folder-scoped only" bullet's destination file should be created at exactly that path
to resolve the dangling reference as part of this migration (it is outside Rule G's contracts/
*.md-only scope, so the lint would not otherwise catch it).

**lean (73L -> target ~45-55L)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-3) | KEEP | -- |
| Language Routing (5-9) | KEEP | -- |
| Skill-Agent Mapping (11-18) | KEEP | -- |
| Rules (20-23) | KEEP (short, arguably part of routing) | -- |
| MCP Integration (25-31) | MOVE | `tools/` new file |
| Commands (33-36) | KEEP | -- |
| Lean Hard Mode (38-73, 36 lines) | MOVE, split | "When to use --hard" + rationale -> `domain/`; hard-mode routing/skill-agent tables -> could stay as a compact addendum to the main routing table, or move to `domain/` alongside the rationale (implementer's call given the 15-line Routing Table budget) |

**Namespace note**: `lean`'s `context/project/` tree uses subdomain **`lean4`**, not `lean` --
confirmed via `find`: `context/project/lean4/{domain,patterns,tools,...}` exists;
`context/project/lean/` does not. New files must land under `context/project/lean4/`, and
`index-entries.json` entries' `subdomain` should follow the extension's existing convention
(check current entries -- e.g. `"subdomain": "lean"` is used in existing `lean/index-entries.json`
entries even though the path segment is `project/lean4/...`; match the existing entries' field
values exactly rather than inventing a new convention).

**cslib (71L -> target ~45-55L)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-3) | KEEP | -- |
| Language Routing (5-10) | KEEP | -- |
| Skill-Agent Mapping (12-23) | KEEP (12 lines, within 5-15 budget) | -- |
| When to Use --hard (25-47, 23 lines) | MOVE | `domain/` new file |
| MCP Integration (49-54) | MOVE, check dedup first | `tools/` -- check for overlap with existing `tools/lake-commands.md` before creating a new file |
| CI Verification Pipeline (56-62) | MOVE, check dedup first | `tools/lake-commands.md` **already exists** and is very likely the right merge target for this section rather than a new file -- read it before migrating |
| Commands (64-71) | KEEP | -- |

**present (64L -> target ~50-58L, smallest trim needed)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-3) | KEEP | -- |
| Skill-Agent Mapping (5-17, 12 lines) | KEEP | -- |
| Commands (19-36, 17 lines -- exceeds the 5-15 budget) | KEEP but tighten | Table is already dense; if it cannot compress under 15 lines, some individual command usage-variant rows could move to `patterns/`, but this is the smallest offender and may only need the two MOVE sections below to clear 60L |
| Language Routing (38-46) | KEEP or fold into Skill-Agent Mapping (duplicate axis) | -- |
| Talk Modes (48-56) | MOVE | `domain/` new file (or check for overlap with existing `domain/presentation-types.md` first) |
| Talk Library (58-64) | MOVE | `domain/` -- likely folds into the same file as Talk Modes, or points at the existing `context/project/present/talk/` tree structure directly |

**nix (62L -> target ~50-58L, smallest trim needed)**

| Section (lines) | Verdict | Destination |
|---|---|---|
| Header (1-3) | KEEP | -- |
| Language Routing (5-9) | KEEP | -- |
| Skill-Agent Mapping (11-16) | KEEP | -- |
| Key Technologies (18-23) | MOVE | `domain/` new file, or fold into an existing `domain/*.md` |
| Build Verification (25-42, with bash code block) | MOVE, check dedup first | Likely overlaps existing `tools/nixos-rebuild-guide.md`/`tools/home-manager-guide.md` -- read both before creating a new file |
| Context Categories (44-49) | DROP or fold into Context Pointers section | This section is itself just a meta-description of the `domain/patterns/standards/tools` taxonomy -- the slimmed EXTENSION.md's required Context Pointers section replaces its purpose |
| MCP-NixOS Integration (51-62) | MOVE, check dedup first | `tools/` -- no existing MCP-NixOS file found in `tools/`; likely genuinely new (`tools/mcp-nixos-integration.md`) |

### Context Extension Recommendations

- **`domain/index-architecture.md` (email)**: create this file as part of the migration --
  it is already referenced but does not exist, independent of this task's own scope creep risk
  (worth flagging to the implementer explicitly so it isn't mistaken for an out-of-scope typo fix
  and skipped).
- **Duplicate-detection pass before file creation**: for `cslib` (CI pipeline vs.
  `tools/lake-commands.md`), `nix` (build verification vs. `tools/nixos-rebuild-guide.md`/
  `tools/home-manager-guide.md`), `present` (talk modes vs. `domain/presentation-types.md`), and
  `literature` (global-repo/sub-index vs. `domain/literature-index.md`, format-decision vs.
  `domain/format-decision.md`), the implementer should `Read` the candidate existing file first
  and prefer merging over creating a near-duplicate sibling.

## Decisions

- **Sub-scope B: delete `core/EXTENSION.md` and `slidev/EXTENSION.md`**, and make
  `check-extension-docs.sh`'s required-file check (line 1278) and Rule U
  (`check_extension_md_length`, line 737) both read `merge_targets.claudemd.source` from each
  extension's `manifest.json` as the authority for whether an `EXTENSION.md` is required/length-
  checked at all, rather than treating `EXTENSION.md` as an unconditionally required filename.
  This is a combination of the task's two named options, not a pure pick of one: the checker
  change is required regardless of whether the files are deleted or kept (line 1278 would `fail()`
  the moment either file is removed), and once the checker is fixed, deletion is the only outcome
  that also removes the 100%-duplicate, unreachable content each file currently carries.
- **Sub-scope A: use each extension's existing `context/project/{ext}/{domain,patterns,tools}/`
  taxonomy** rather than introducing new top-level categories -- all six extensions already have
  this structure populated (lean under the `lean4` subdomain name, not `lean`), so no new
  directory-structure decisions are needed, only new leaf files plus index entries.
- **No `.orchestrator-handoff.json` was written for this dispatch.** Per
  `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, that artifact is formally
  hard-mode-implementation-agent-only, and `skill-orchestrate`'s own Stage 5 documents "a
  base-mode dispatch never writes `.orchestrator-handoff.json`" as the expected, non-error shape
  for a base-mode (non-`--hard`) research dispatch. Writing one here with research-shaped content
  (no `phases_completed`/`phases_total`/hard-mode fields) would not conform to the schema and
  could be misread by the orchestrator's Stage 4/5 handoff-freshness logic. `.return-meta.json`
  is the correct and sufficient completion signal for this dispatch.

## Risks & Mitigations

- **Risk**: trimming email's Safety Invariants section too aggressively could drop content the
  `email-implementation-agent` or `skill-email-cleanup` relies on being visible without an extra
  context-file read. **Mitigation**: the standard's own Migration Template explicitly keeps this
  kind of "operational safety" content available via `load_when.agents`/`load_when.task_types`
  targeting the exact consuming agents (`email-implementation-agent`), so the content remains
  auto-loaded for the agents that need it, just not always present in CLAUDE.md itself.
- **Risk**: deleting `core/EXTENSION.md` could break some other undiscovered consumer.
  **Mitigation**: exhaustive grep across `agent-system/` and `lua/` for `EXTENSION.md` (and
  specifically `core/EXTENSION.md`/`slidev/EXTENSION.md`) found only doc-prose references (all
  identified above) and the two `check-extension-docs.sh` checks; no `.lua` loader code, install
  script, or symlink-deploy path references `EXTENSION.md` by name outside `merge.lua`'s
  `merge_targets`-driven lookup (which is exactly the mechanism proving the files are dead).
- **Risk**: the required-file check change (line 1278) is generic (reads
  `merge_targets.claudemd.source` for every extension), so a typo'd or missing
  `merge_targets.claudemd` block in some *other* extension's manifest could silently stop
  requiring its `EXTENSION.md` too. **Mitigation**: this is the correct, intended behavior for a
  genuine resource-only extension (matches slidev's already-documented pattern) but should
  `advisory`-log (not silently skip) whenever `merge_targets.claudemd` is absent for an
  extension that HAS a nonempty `provides.skills`/`provides.commands` (i.e., is not
  resource-only) -- catching an accidental omission distinct from an intentional resource-only
  design. Flag this as a planner-level check-design nuance rather than a blocking risk.

## Appendix

- Search/verification commands used: `wc -l` per `EXTENSION.md`, `jq` over each `manifest.json`'s
  `merge_targets`/`provides`, `git ls-files`-independent `grep -rn "EXTENSION.md"` across
  `agent-system/` and `lua/`, a live `REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/check-extension-docs.sh` run (both quiet and Rule-U/Rule-T
  filtered), and a full `Read` of all 6 over-length files plus `core/EXTENSION.md`,
  `slidev/EXTENSION.md`, `core/README.md`, `slidev/README.md`, `merge.lua`'s
  `generate_claudemd()`, and `extension-slim-standard.md` in full.
- Key file references: `agent-system/extensions/core/scripts/check-extension-docs.sh` (lines
  654-663 `SCHEMA_CONFORMANCE_GATE_MODE`, 732-749 Rule U, 1276-1278 required-file checks,
  943-1017 Rule E), `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`
  (full), `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 768-879
  (`generate_claudemd`), `agent-system/extensions/core/docs/guides/creating-extensions.md` lines
  ~213-244 (Resource-Only Extensions / slidev example), `agent-system/extensions/core/context/
  guides/extension-development.md` lines 114-121 (core vs. standard claudemd-source distinction).
