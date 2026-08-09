# Implementation Plan: Task #992

- **Task**: 992 - Trim the 6 over-length live EXTENSION.md files; resolve the 2 dead ones
- **Status**: [IMPLEMENTING]
- **Effort**: 8.75 hours
- **Dependencies**: 987, 990, 991 (index-entries.json schema reconciliation -- research confirms this has landed; a live Rule T run reports 0 violations across all 19 extensions)
- **Research Inputs**: specs/992_extension_md_slim_down/reports/01_extension_md_slim_down.md
- **Artifacts**: plans/01_extension-md-slim-down.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, extension-slim-standard.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Bring every `EXTENSION.md` in `agent-system/extensions/**` into conformance with
`extension-slim-standard.md` (4 required sections, 60-line ceiling, per-section budgets) so the
follow-on gate promotion can flip `SCHEMA_CONFORMANCE_GATE_MODE` to `hard` with no standing Rule U
failures. Two independent sub-scopes run in one wave: (A) six live over-length files are trimmed by
moving detail content into each extension's existing `context/project/{ext}/{domain,patterns,tools}/`
tree with schema-conformant `index-entries.json` entries; (B) two dead files (`core`, `slidev`) are
deleted after making `check-extension-docs.sh`'s required-file check and Rule U both authoritative on
`merge_targets.claudemd.source` rather than on a hardcoded `EXTENSION.md` filename. Done means a live
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` run reports zero
Rule U advisories across all 19 extensions and exits clean, with every new context file carrying a
schema-conformant index entry.

### Research Integration

The research report supplies: re-measured line counts (no drift from the task description), a
per-file KEEP/MOVE migration map with destination directories for all six trim targets, proof via
`merge.lua`'s `generate_claudemd()` that neither dead file is reachable from CLAUDE.md generation,
a recommendation to DELETE both dead files (each is a 100% content subset of its own `README.md`),
the finding that `check-extension-docs.sh`'s unconditional required-file check must become
`merge_targets.claudemd.source`-authoritative under either resolution, four named dedup risks to
check before creating new files, the `lean4` (not `lean`) context-subdomain gotcha, and a dangling
reference in `email/EXTENSION.md` to a `domain/index-architecture.md` that does not exist on disk.
Every phase below is derived from that map; no phase invents a destination the report did not
identify.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; ROADMAP.md was not consulted and the
roadmap flag is not set. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Every live `EXTENSION.md` is at or under 60 lines and carries only the four required sections
  (Header, Routing Table, Command List, Context Pointers), each within its per-section budget.
- All moved content survives in `context/project/{ext}/{domain,patterns,tools}/` files, each with a
  schema-conformant `index-entries.json` entry whose `load_when` targets the agents/task_types that
  previously relied on the content being present in generated CLAUDE.md.
- `core/EXTENSION.md` and `slidev/EXTENSION.md` are deleted, and the checker no longer requires or
  length-checks an `EXTENSION.md` for an extension whose manifest does not name one as its claudemd
  merge source.
- The delete-vs-redefine-authority rationale is recorded in a durable, in-repo location (not only in
  the task artifacts).
- `check-extension-docs.sh` reports zero Rule U advisories across all 19 extensions and exits clean.

**Non-Goals**:
- Flipping `SCHEMA_CONFORMANCE_GATE_MODE` from `advisory` to `hard`. That is the explicitly named
  follow-on; this task only removes the standing failures blocking it.
- Rewriting or reorganizing the 11 extensions already at or under 60 lines.
- Re-migrating `index-entries.json` schema shape (already landed; new entries only need to match the
  existing conformant shape).
- Editing anything under `.claude/**` -- that tree is a disposable deploy artifact regenerated from
  `agent-system/extensions/**` (see `rules/source-store-deploy-boundary.md`).
- Rewriting content semantics. Moves are content-preserving relocations plus pointers, not rewrites.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Over-aggressive trimming drops operational content an agent relied on seeing in CLAUDE.md (notably email's Safety Invariants) | H | M | Every moved block lands in a context file whose `load_when.agents`/`load_when.task_types` name the exact consuming agents (e.g. `email-implementation-agent`), so it remains auto-loaded for those agents; verify the `load_when` targeting before deleting from EXTENSION.md, and add an `@`-pointer in the Context Pointers section |
| A new context file duplicates an existing one (cslib CI pipeline vs. `tools/lake-commands.md`/`standards/ci-pipeline.md`; nix build verification vs. `tools/nixos-rebuild-guide.md`/`tools/home-manager-guide.md`; present talk modes vs. `domain/presentation-types.md`; literature sub-index vs. `domain/literature-index.md`, format-decision vs. `domain/format-decision.md`) | M | H | Each affected phase carries a mandatory Read-the-candidate-first sub-step; prefer merging into the existing file over creating a near-duplicate sibling |
| The generic `merge_targets.claudemd.source` authority fix silently stops requiring `EXTENSION.md` for an extension whose manifest merely omits the key by accident | M | L | The fix emits an advisory (never a silent skip) whenever `merge_targets.claudemd` is absent for an extension that has a non-empty `provides.skills` or `provides.commands` -- i.e. is not genuinely resource-only |
| New files land under `context/project/lean/` instead of the extension's real `context/project/lean4/` subtree | M | M | The lean phase pins the path prefix explicitly and requires matching the `subdomain` field value used by that extension's existing entries (`"lean"`) rather than inventing one from the path segment |
| `line_count` fields in new index entries drift from actual `wc -l` | L | M | Final phase runs `generate-context-line-counts.sh --check` and corrects with `--write` before the gate |
| An implementer edits `.claude/**` (the deploy copy) instead of the source store, and the change is silently wiped on next regeneration | H | M | Every phase's file list is written as an `agent-system/extensions/**` path; the advisory PostToolUse hook plus this line are the reminder |
| Trimming introduces a task-number citation into a deliverable outside `specs/**` | M | L | Final phase runs `check-task-references.sh`; moved prose must cite durable anchors, never task numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4, 5, 6, 7 | -- |
| 2 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Phases 1-7 are territory-disjoint: Phase 1 owns
`agent-system/extensions/core/**` plus `agent-system/extensions/slidev/**`; each of Phases 2-7 owns
exactly one extension directory. No two Wave 1 phases write the same file.

---

### Phase 1: Resolve the two dead EXTENSION.md files [IN PROGRESS]

**Goal**: Make `check-extension-docs.sh` treat `merge_targets.claudemd.source` as the authority for
whether an extension must have (and be length-checked on) an `EXTENSION.md`, then delete both dead
files and repoint every stale cross-reference, recording the rationale durably.

**Tasks**:
- [ ] Read `core/scripts/check-extension-docs.sh` around `check_extension_md_length()` (Rule U) and
      the unconditional `check_file "$ext_path/EXTENSION.md" "EXTENSION.md"` required-file check.
- [ ] Add a shared helper that resolves `claudemd_source=$(jq -r '.merge_targets.claudemd.source // empty' "$ext_path/manifest.json")`.
- [ ] Gate the required-file check: require `$ext_path/EXTENSION.md` to exist only when
      `claudemd_source == "EXTENSION.md"`; when it is empty or names another path, do not require the
      file and skip Rule U's length check for that extension.
- [ ] Add the accidental-omission advisory: when `merge_targets.claudemd` is absent but the
      extension's `provides.skills` or `provides.commands` is non-empty, emit an advisory naming the
      extension (never a silent skip).
- [ ] Record the decision rationale durably in-repo: a comment block above the new helper in
      `check-extension-docs.sh` stating why the manifest's claudemd source is the authority and why
      both dead files were deleted rather than trimmed, plus a short note in
      `core/docs/reference/standards/extension-slim-standard.md` cross-referencing the resource-only
      pattern already documented in `core/docs/guides/creating-extensions.md`. Cite durable anchors
      (file/section names) only -- no task numbers.
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      confirm it still passes with both dead files still present (green sub-step; commit).
- [ ] Delete `agent-system/extensions/core/EXTENSION.md` and
      `agent-system/extensions/slidev/EXTENSION.md`.
- [ ] Update `core/manifest.json` and `slidev/manifest.json` `provides.*` arrays if either declares
      `EXTENSION.md` (verify with `jq` before editing; do not assume).
- [ ] Repoint or remove the stale cross-references: `core/README.md`'s "Detailed capability
      inventory" line pointing at `core/EXTENSION.md`; `core/docs/architecture/extension-system.md`'s
      `EXTENSION.md ... (REQUIRED)` line; `core/docs/guides/adding-domains.md`'s
      `EXTENSION.md # CLAUDE.md merge content (required)` line -- the latter two should state the
      `merge_targets.claudemd.source`-conditional requirement.
- [ ] Re-run the checker; confirm clean and that no new failure appeared for `core` or `slidev`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly 2 files to delete and 3 stale doc cross-references
to repoint. Confirm at implementation time with
`grep -rn "EXTENSION\.md" agent-system/ lua/ --include='*.md' --include='*.sh' --include='*.lua' --include='*.json'`
and with `jq '.provides' agent-system/extensions/{core,slidev}/manifest.json`; if the grep surfaces
additional live references beyond the three named, handle them in this phase rather than deferring.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - manifest-authoritative
  required-file check, Rule U skip, accidental-omission advisory, rationale comment block
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` - note on the
  resource-only / non-EXTENSION.md-claudemd-source case
- `agent-system/extensions/core/docs/architecture/extension-system.md` - conditional-requirement wording
- `agent-system/extensions/core/docs/guides/adding-domains.md` - conditional-requirement wording
- `agent-system/extensions/core/README.md` - drop or repoint the dead cross-reference
- `agent-system/extensions/core/EXTENSION.md` - DELETE
- `agent-system/extensions/slidev/EXTENSION.md` - DELETE
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/slidev/manifest.json` - only
  if they declare the deleted file in `provides.*`

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 with
  no Rule U advisory for `core` or `slidev` and no missing-file failure for either.
- A synthetic check: temporarily confirm the checker still FAILS for an extension whose manifest does
  name `EXTENSION.md` as its claudemd source but whose file is absent (revert immediately) -- proves
  the gate was narrowed, not disabled.
- `grep -rn "core/EXTENSION.md\|slidev/EXTENSION.md" agent-system/ lua/` returns no live references.

---

### Phase 2: Trim literature/EXTENSION.md (169L) [NOT STARTED]

**Goal**: Reduce `literature/EXTENSION.md` to the four required sections under 60 lines, relocating
its nine detail sections into `literature/context/project/literature/{domain,patterns,tools}/`.

**Tasks**:
- [ ] Read `literature/EXTENSION.md` in full and the two dedup candidates
      `context/project/literature/domain/literature-index.md` and
      `context/project/literature/domain/format-decision.md` BEFORE creating any file.
- [ ] Move/merge per the research migration map: Dependencies note -> `domain/`; Global Repository
      and Per-Repo Sub-Index -> merge into existing `domain/literature-index.md` if it already covers
      the material; Briefing+Tools Agent Pattern -> `patterns/`; Sparse-Coverage Detection -> short
      `domain/` file that mostly points at the fuller authority in `core/merge-sources/claudemd.md`'s
      "Interactive Sub-Index Setup Detection" section; Two-Mode `/literature` Command -> `patterns/`;
      Centralized Repository (env var / settings key config) -> `tools/`; Format Decision paragraph ->
      collapse to one line plus the existing `domain/format-decision.md` pointer; Zotero Integration
      prose -> `domain/`; Zotero script table -> `tools/`; `/cite` workflow prose -> `patterns/`.
- [ ] Add a schema-conformant `index-entries.json` entry for every newly created file
      (`path`, `domain`, `subdomain`, `summary`, `line_count`, `load_when`; no `description`/`tags`).
- [ ] Rewrite `EXTENSION.md` to Header + Routing Table (Skill-Agent Mapping) + Command List
      (`/literature` rows folded with the `/cite` rows) + Context Pointers (max 5 `@`-pointers).
- [ ] Confirm `wc -l` <= 60 and each section within budget (Header 3-5, Routing 5-15, Commands 5-15,
      Pointers 3-5).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The map implies roughly 6-8 new or merged context files. The count is a
hypothesis, not a target: confirm by reading the dedup candidates first and merging wherever the
existing file already covers the material. Fewer new files with correct merges is a better outcome
than hitting the estimated count.

**Files to modify**:
- `agent-system/extensions/literature/EXTENSION.md` - trim to 4 sections
- `agent-system/extensions/literature/context/project/literature/{domain,patterns,tools}/*.md` - new/merged
- `agent-system/extensions/literature/index-entries.json` - one entry per new file

**Verification**:
- `wc -l agent-system/extensions/literature/EXTENSION.md` <= 60.
- `jq -e '.entries[] | select(.path == "<new path>")' agent-system/extensions/literature/index-entries.json`
  resolves for every new file, and each entry validates against `core/context/index.schema.json`.
- No `@`-pointer or prose reference in the trimmed `EXTENSION.md` names a file that does not exist.

---

### Phase 3: Trim email/EXTENSION.md (106L) [NOT STARTED]

**Goal**: Reduce `email/EXTENSION.md` to the four required sections under 60 lines by relocating the
68-line Safety Invariants block and Key Technologies, and resolve the dangling
`domain/index-architecture.md` reference by creating that file as the destination for the account-
isolation content.

**Tasks**:
- [ ] Read `email/EXTENSION.md` in full plus the existing `context/project/email/domain/`
      files (`wrapper-contracts.md`, `staleness-detection.md`, `archive-mode-risk.md`) to identify
      which invariant bullets are already covered there and only need a pointer.
- [ ] Create `context/project/email/domain/index-architecture.md` at exactly the path the existing
      dangling reference names, carrying the "Account isolation, folder-scoped only" content
      (the three `folder:` query forms and their live behavior). This is deliberate in-scope work,
      not an out-of-scope typo fix.
- [ ] Consolidate the remaining invariant bullets not already covered by an existing domain file into
      `context/project/email/domain/safety-invariants.md`; fold Key Technologies into that file or a
      sibling `domain/` file.
- [ ] Set `load_when.agents` to include `email-implementation-agent` and `load_when.task_types` to
      include `email` on every new entry, so the operational safety content stays auto-loaded for the
      agents that depend on it.
- [ ] Rewrite `EXTENSION.md` to Header + Task-Type Routing (Routing Table) + Skill-Agent Mapping
      folded into that same table + Command List + Context Pointers.
- [ ] Confirm `wc -l` <= 60 and per-section budgets.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts 2 new domain files (`index-architecture.md`,
`safety-invariants.md`) and that the existing `wrapper-contracts.md`/`staleness-detection.md`/
`archive-mode-risk.md` already cover part of the invariants block. Confirm by reading those three
files first; if they cover more than expected, create fewer new files and use pointers, and if they
cover less, split into a third file rather than exceeding a reasonable single-file size.

**Files to modify**:
- `agent-system/extensions/email/EXTENSION.md` - trim to 4 sections
- `agent-system/extensions/email/context/project/email/domain/index-architecture.md` - new (resolves dangling reference)
- `agent-system/extensions/email/context/project/email/domain/safety-invariants.md` - new
- `agent-system/extensions/email/index-entries.json` - one entry per new file

**Verification**:
- `wc -l agent-system/extensions/email/EXTENSION.md` <= 60.
- `test -f agent-system/extensions/email/context/project/email/domain/index-architecture.md` succeeds
  and every in-repo reference to that path now resolves.
- Every invariant bullet previously in `EXTENSION.md` is findable via `grep` in either a new file or
  an existing `domain/` file -- nothing was dropped.
- New index entries validate against `core/context/index.schema.json`.

---

### Phase 4: Trim lean/EXTENSION.md (73L) [NOT STARTED]

**Goal**: Reduce `lean/EXTENSION.md` to the four required sections under 60 lines by moving MCP
Integration and the 36-line Lean Hard Mode block into `context/project/lean4/`.

**Tasks**:
- [ ] Read `lean/EXTENSION.md` in full plus the dedup candidates
      `context/project/lean4/tools/mcp-tools-guide.md`, `tools/blocked-mcp-tools.md`, and
      `patterns/mcp-fallback-table.md` -- the MCP Integration section very likely merges into one of
      these rather than warranting a new file.
- [ ] Move the MCP Integration section into the best-matching existing `tools/` file (merge) or a new
      `tools/` file only if no existing file fits.
- [ ] Move the Lean Hard Mode block: the "when to use `--hard`" rationale into a new
      `context/project/lean4/domain/` file; keep the hard-mode routing/skill-agent rows only if they
      fit inside the 15-line Routing Table budget, otherwise move them alongside the rationale.
- [ ] Create new files under `context/project/lean4/` -- NOT `context/project/lean/`, which does not
      exist. Set each new entry's `subdomain` to the value the extension's existing entries already
      use (`"lean"`), matching convention rather than the path segment.
- [ ] Rewrite `EXTENSION.md` to Header + Routing Table (Language Routing + Skill-Agent Mapping + Rules
      folded) + Command List + Context Pointers.
- [ ] Confirm `wc -l` <= 60 and per-section budgets.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts 1-2 new files under `context/project/lean4/` and that the
MCP section merges into an existing `tools/` file. Confirm by reading the three named MCP candidates
before creating anything.

**Files to modify**:
- `agent-system/extensions/lean/EXTENSION.md` - trim to 4 sections
- `agent-system/extensions/lean/context/project/lean4/{domain,tools}/*.md` - new/merged
- `agent-system/extensions/lean/index-entries.json` - one entry per new file

**Verification**:
- `wc -l agent-system/extensions/lean/EXTENSION.md` <= 60.
- No new directory `agent-system/extensions/lean/context/project/lean/` was created.
- New entries' `subdomain` values match the existing entries in the same file
  (`jq -r '[.entries[].subdomain] | unique' agent-system/extensions/lean/index-entries.json` yields a
  single value).

---

### Phase 5: Trim cslib/EXTENSION.md (71L) [NOT STARTED]

**Goal**: Reduce `cslib/EXTENSION.md` to the four required sections under 60 lines by moving the
23-line "When to Use --hard" block, MCP Integration, and the CI Verification Pipeline into existing
`context/project/cslib/` files wherever they already cover the material.

**Tasks**:
- [ ] Read `cslib/EXTENSION.md` in full plus the dedup candidates `context/project/cslib/tools/lake-commands.md`
      and `context/project/cslib/standards/ci-pipeline.md` BEFORE creating any file -- the CI
      Verification Pipeline section very likely belongs in one of these, not in a new sibling.
- [ ] Move "When to Use --hard" (23 lines) into a new `context/project/cslib/domain/` file.
- [ ] Merge MCP Integration and the CI Verification Pipeline into the existing `tools/`/`standards/`
      files identified above; create a new file only if neither fits.
- [ ] Add index entries for any newly created file; update the `line_count` of any existing entry
      whose file grew from a merge.
- [ ] Rewrite `EXTENSION.md` to Header + Routing Table (Language Routing + Skill-Agent Mapping) +
      Command List + Context Pointers.
- [ ] Confirm `wc -l` <= 60 and per-section budgets (Skill-Agent Mapping is 12 lines today, already
      inside the 15-line Routing Table budget only if Language Routing folds in -- check the combined
      count).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts at most 1 genuinely new context file (the `--hard` rationale)
with the other two sections merging into existing files. Confirm by reading `tools/lake-commands.md`
and `standards/ci-pipeline.md` first; a second new file is acceptable only with a stated reason why
neither existing file fits.

**Files to modify**:
- `agent-system/extensions/cslib/EXTENSION.md` - trim to 4 sections
- `agent-system/extensions/cslib/context/project/cslib/domain/*.md` - new (`--hard` rationale)
- `agent-system/extensions/cslib/context/project/cslib/{tools/lake-commands.md,standards/ci-pipeline.md}` - merged into if they fit
- `agent-system/extensions/cslib/index-entries.json` - new entries plus `line_count` updates for grown files

**Verification**:
- `wc -l agent-system/extensions/cslib/EXTENSION.md` <= 60.
- No near-duplicate CI-pipeline file exists: `grep -rl "lake build\|CI pipeline" agent-system/extensions/cslib/context/` returns
  the pre-existing files, not a new third one covering the same ground.
- New/updated index entries validate against `core/context/index.schema.json`.

---

### Phase 6: Trim present/EXTENSION.md (64L) [NOT STARTED]

**Goal**: Reduce `present/EXTENSION.md` to the four required sections under 60 lines by moving Talk
Modes and Talk Library into `context/project/present/domain/` and tightening the 17-line Commands
table into the 15-line budget.

**Tasks**:
- [ ] Read `present/EXTENSION.md` in full plus the dedup candidate
      `context/project/present/domain/presentation-types.md` BEFORE creating any file.
- [ ] Move Talk Modes and Talk Library into `domain/presentation-types.md` if it already covers the
      material, otherwise into a single new `domain/` file (both sections together, not two files).
- [ ] Fold Language Routing into the Skill-Agent Mapping table (they are the same axis) or drop the
      redundant one.
- [ ] Compress the Commands table to <= 15 lines; if it cannot compress, move the least-load-bearing
      usage-variant rows into `context/project/present/patterns/` and leave the canonical command rows.
- [ ] Add index entries for any new file; update `line_count` for any existing file that grew.
- [ ] Confirm `wc -l` <= 60 and per-section budgets.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that moving 2 sections plus folding the duplicate routing
axis clears 60 lines, and that at most 1 new context file is needed. Confirm with `wc -l` after the
trim; if still over, move usage-variant command rows to `patterns/` as the named fallback rather than
shaving required sections below their minimum budgets.

**Files to modify**:
- `agent-system/extensions/present/EXTENSION.md` - trim to 4 sections
- `agent-system/extensions/present/context/project/present/domain/*.md` - new or merged
- `agent-system/extensions/present/index-entries.json` - new entries plus `line_count` updates

**Verification**:
- `wc -l agent-system/extensions/present/EXTENSION.md` <= 60, Commands section <= 15 lines.
- Every `/present`-family command previously listed is still listed or reachable via a Context Pointer.
- New/updated index entries validate against `core/context/index.schema.json`.

---

### Phase 7: Trim nix/EXTENSION.md (62L) [NOT STARTED]

**Goal**: Reduce `nix/EXTENSION.md` to the four required sections under 60 lines by moving Key
Technologies, Build Verification, and MCP-NixOS Integration out, and dropping the Context Categories
meta-section that the required Context Pointers section replaces.

**Tasks**:
- [ ] Read `nix/EXTENSION.md` in full plus the dedup candidates
      `context/project/nix/tools/nixos-rebuild-guide.md` and `context/project/nix/tools/home-manager-guide.md`
      BEFORE creating any file -- the Build Verification bash block very likely duplicates them.
- [ ] Move Build Verification into whichever of those two existing guides fits (or split across both);
      create a new file only if neither covers it.
- [ ] Move Key Technologies into an existing `context/project/nix/domain/` file (`flakes.md`,
      `nixos-modules.md`, `home-manager.md`) or a new `domain/` file if none fits.
- [ ] Create `context/project/nix/tools/mcp-nixos-integration.md` for the MCP-NixOS Integration
      section (research found no existing tools file covering it).
- [ ] DROP the Context Categories section entirely -- it is a meta-description of the
      `domain/patterns/standards/tools` taxonomy that the required Context Pointers section replaces.
- [ ] Add index entries for any new file; update `line_count` for any existing file that grew.
- [ ] Confirm `wc -l` <= 60 and per-section budgets.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly 1 genuinely new context file
(`tools/mcp-nixos-integration.md`) with Build Verification and Key Technologies merging into existing
files. Confirm by reading `tools/nixos-rebuild-guide.md`, `tools/home-manager-guide.md`, and the three
`domain/` files first; a second new file is acceptable only with a stated reason.

**Files to modify**:
- `agent-system/extensions/nix/EXTENSION.md` - trim to 4 sections, drop Context Categories
- `agent-system/extensions/nix/context/project/nix/tools/mcp-nixos-integration.md` - new
- `agent-system/extensions/nix/context/project/nix/{tools,domain}/*.md` - merged into
- `agent-system/extensions/nix/index-entries.json` - new entry plus `line_count` updates

**Verification**:
- `wc -l agent-system/extensions/nix/EXTENSION.md` <= 60.
- The `nix flake check` / `nixos-rebuild build` / `home-manager build` command block is findable via
  `grep -rn "nixos-rebuild build --flake" agent-system/extensions/nix/context/` -- nothing was dropped.
- New/updated index entries validate against `core/context/index.schema.json`.

---

### Phase 8: Full gate, line-count sync, and zero-advisory attestation [NOT STARTED]

**Goal**: Prove the verification bar: zero Rule U advisories across all 19 extensions, every new
context file schema-conformant and accurately line-counted, no regressions in any other rule, and no
task-number citations introduced into deliverables.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`; correct
      any drift with `--write`.
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      capture the full output; confirm exit 0 and zero `Rule U` lines.
- [ ] Re-run the checker with `SCHEMA_CONFORMANCE_GATE_MODE=hard` as a dry proof that the follow-on
      flip will pass -- do NOT change the default in the script (that is the follow-on's scope).
- [ ] Validate every new/modified `index-entries.json` against `core/context/index.schema.json`
      (required keys present, forbidden `description`/`tags` absent, `load_when` restricted to
      `agents`/`commands`/`task_types`/`always`).
- [ ] Re-measure `wc -l` for all 19 `EXTENSION.md` files that still exist; record the before/after
      table in the implementation summary.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` and
      `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh`; confirm clean.
- [ ] Confirm no file under `.claude/**` was modified by this task
      (`git status --short -- .claude/` is empty apart from pre-existing unrelated state).
- [ ] Confirm every `@`-pointer in every trimmed `EXTENSION.md` resolves to a file that exists.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts 19 extensions in scope and 6 trimmed + 2 deleted files.
Confirm by enumerating `ls -d agent-system/extensions/*/` and
`find agent-system/extensions -maxdepth 2 -name EXTENSION.md | wc -l` at implementation time rather
than trusting the count; a divergence means an extension was added or removed since research and must
be handled, not ignored.

**Files to modify**:
- None expected beyond `line_count` corrections written by `generate-context-line-counts.sh --write`.

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 with
  zero Rule U advisories.
- The same command with `SCHEMA_CONFORMANCE_GATE_MODE=hard` also exits 0.
- `generate-context-line-counts.sh --check` reports no drift.
- `check-task-references.sh` exits 0.

---

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0,
      zero Rule U advisories across all 19 extensions.
- [ ] The same run with `SCHEMA_CONFORMANCE_GATE_MODE=hard` also exits 0 (proves the follow-on flip is
      unblocked without performing it).
- [ ] Every surviving `EXTENSION.md` is <= 60 lines with exactly the four required sections, each
      within its per-section budget.
- [ ] `core/EXTENSION.md` and `slidev/EXTENSION.md` no longer exist and no in-repo reference to either
      remains.
- [ ] The checker still hard-fails for an extension whose manifest names `EXTENSION.md` as its
      claudemd source but whose file is missing (narrowed, not disabled).
- [ ] Every new context file has an `index-entries.json` entry validating against
      `core/context/index.schema.json`, with accurate `line_count`.
- [ ] `generate-context-line-counts.sh --check` reports no drift.
- [ ] `check-task-references.sh` and `lint/lint-routing-wiring.sh` exit 0.
- [ ] No content that was in an `EXTENSION.md` before this task is unreachable after it: every moved
      block is findable by `grep` in a context file, and every consuming agent still auto-loads it via
      `load_when`.
- [ ] No file under `.claude/**` was edited.

## Artifacts & Outputs

- `specs/992_extension_md_slim_down/plans/01_extension-md-slim-down.md` (this plan)
- `specs/992_extension_md_slim_down/summaries/01_extension-md-slim-down-summary.md` (on completion),
  including the before/after line-count table for all 19 extensions and the sub-scope B decision
  rationale as implemented
- 6 trimmed `agent-system/extensions/{literature,email,lean,cslib,present,nix}/EXTENSION.md`
- New/merged context files under `agent-system/extensions/{literature,email,lean,cslib,present,nix}/context/project/{ext}/{domain,patterns,tools}/`
- Updated `index-entries.json` in those 6 extensions
- Modified `agent-system/extensions/core/scripts/check-extension-docs.sh` (manifest-authoritative
  required-file check, Rule U skip, accidental-omission advisory, rationale comment)
- Updated `core/README.md`, `core/docs/architecture/extension-system.md`,
  `core/docs/guides/adding-domains.md`, `core/docs/reference/standards/extension-slim-standard.md`
- Deleted `agent-system/extensions/core/EXTENSION.md`, `agent-system/extensions/slidev/EXTENSION.md`

## Rollback/Contingency

Every phase is a self-contained, per-substep-committed unit touching one extension directory (or,
for Phase 1, `core` plus `slidev`), so a bad phase reverts with `git revert` of that phase's commits
without disturbing the others. Two specific contingencies:

- **Checker change regresses another rule**: revert the `check-extension-docs.sh` commit first; the
  two dead files can stay deleted only if the required-file check remains manifest-authoritative, so
  reverting the checker requires reverting the deletions in the same operation.
- **A trim drops content an agent needed**: the moved content is preserved in a context file, so the
  fix is to widen that file's `load_when` or add an `@`-pointer -- not to restore the content into
  `EXTENSION.md`, which would reintroduce the Rule U failure.

If uncommitted work must be discarded at any point, run
`bash .claude/scripts/git-snapshot.sh 992` first per `rules/git-workflow.md`.
