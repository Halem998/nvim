# Implementation Plan: Unified Literature System

- **Task**: 758 - Unified Literature System
- **Status**: [COMPLETED]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_infrastructure-audit.md, reports/02_agent-design-patterns.md, reports/03_storage-architecture.md, reports/04_extension-consolidation.md, reports/05_research-synthesis.md, reports/06_team-research.md, reports/07_literature-workflow-design.md
- **Artifacts**: plans/08_unified-literature-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor the literature and zotero extensions into a single unified literature extension that replaces static context injection with a briefing+tools pattern. The global Literature/ repo at `~/Projects/Literature/` is already operational (222 index entries, 47 documents, FTS5 search). The work involves: (1) consolidating two extensions into one, migrating all working zotero scripts; (2) designing the per-repo sub-index (`specs/literature-index.json`); (3) creating a briefing generator that replaces full content injection; (4) building a source discovery pipeline for finding and acquiring papers; (5) rewiring the `--lit` flag in all 6 SKILL.md files; and (6) cleaning up dead code and updating documentation. Done when: `--lit` produces a briefing block instead of content injection, agents can search and read literature on demand via `literature-search.sh`, the zotero extension directory is removed, and `/literature` supports both discovery and integration modes.

### Research Integration

Seven research reports integrated:
- **01 Infrastructure Audit**: Complete inventory. Key correction: all 9 zotero scripts are fully implemented (2,375 lines), not stubs. Report 04 incorrectly claims otherwise. The `--zot` flag was never wired into `parse-command-args.sh`. Four different scoring algorithms exist across retrieval scripts.
- **02 Agent Design Patterns**: Recommends Pattern 3C (Briefing + Tools). Inject a ~300-token briefing of available papers; agents use `Read` and `literature-search.sh` on demand. No new agent type required.
- **03 Storage Architecture**: Global Literature/ repo is operational. Per-repo sub-index design: reference-only (doc_ids), no cached metadata. `literature-search.sh` (FTS5, 7 subcommands) and `literature-ingest.sh` already exist.
- **04 Extension Consolidation**: Merger strategy. Absorb zotero into literature extension v2.0.0. Single `/literature` command surface. NOTE: zotero script status corrected per Report 01.
- **05 Research Synthesis**: Cross-report conflict resolution. Confirms briefing+tools, single `--lit` flag, merged extension, unified FTS5 scoring.
- **06 Team Research (4 teammates)**: Identified critical gaps in prior plan: source discovery pipeline absent, Bash permission for `literature-search.sh` missing, hard-variant skills (6 files not 3) overlooked, literature-agent listed as non-goal contradicting task description. Token economics: briefing is always cheaper; total session cost depends on follow-up searches.
- **07 Workflow Design**: Concrete two-mode `/literature` command (discover + integrate), `literature-briefing.sh` design, `literature-discover.sh` three-tier pipeline, per-repo sub-index schema, SOURCES.md format. Streamlined command surface: 4 entry points down from 7.

### Prior Plan Reference

Prior plan (05_unified-literature-plan.md) was a 6-phase, 9-hour plan covering extension consolidation, sub-index design, briefing generation, flag rewiring, scoring unification, and documentation. Gaps addressed in this revision:
- Source discovery pipeline (Mode A) was entirely absent
- Only 3 SKILL.md files identified for Stage 4a swap (actual count: 6, including hard variants)
- Bash permission for `literature-search.sh` not included as a prerequisite
- Literature-agent listed as a non-goal without explaining the design decision
- Token economics framed as uniform savings (misleading -- briefing is always cheaper, but total cost depends on search volume)

### Roadmap Alignment

Advances ROADMAP.md Phase 2 "Literature centralization" (completed for global repo in task 710). This task extends with extension consolidation, sub-index format, briefing+tools agent interface, and source discovery pipeline.

### Design Decisions

**Briefing+Tools chosen over dedicated literature-agent type**: The task description asks for "a literature-agent that autonomously explores the global Literature/ corpus." The briefing+tools pattern (Report 02, Pattern 3C) achieves this goal without introducing a new agent type. Here is why:

1. Agents already have `Read` and `Bash` tools. A compact briefing tells them what literature is available; `literature-search.sh` lets them search the full corpus; `Read` lets them access specific chunks. This is autonomous exploration using existing tools.
2. A separate agent type would require spawning overhead, context-window management, and a return protocol -- all for a task that existing tools handle directly.
3. The briefing is strictly cheaper than injection (~300 tokens vs 4,000-8,000). Total session cost depends on how many searches/reads the agent performs, but the agent only reads what it needs -- a selectivity improvement over blind injection.
4. This matches the system's existing pattern: memory retrieval uses the same injection approach, and the same briefing+tools upgrade can be applied to memory in a future task.

The `literature-agent.md` file is updated to document this pattern (not as a spawnable agent definition, but as the architectural description of how agents interact with literature).

## Goals & Non-Goals

**Goals**:
- Consolidate literature and zotero extensions into a single `literature` extension (v2.0.0)
- Migrate all 9 working zotero scripts (2,375 lines) into the unified extension
- Design and implement per-repo sub-index (`specs/literature-index.json`) with reference-only entries
- Create `literature-briefing.sh` to replace static content injection
- Create `literature-discover.sh` for three-tier source discovery (global index, Zotero, online APIs)
- Rewire `--lit` flag in all 6 SKILL.md files (3 standard + 3 hard variants)
- Add Bash permission for `literature-search.sh` in `.claude/settings.json`
- Implement two-mode `/literature` command (discover + integrate)
- Set `LITERATURE_DIR` explicitly in `.claude/settings.json`
- Clean up dead `--zot` wiring and duplicate scripts

**Non-Goals**:
- Rebuilding the global Literature/ repo structure (already well-designed)
- Rewriting `literature-search.sh` or `literature-ingest.sh` (already operational)
- Creating a new spawnable agent type (briefing+tools pattern uses existing tools -- see Design Decisions)
- Changing the FTS5 database schema or global `index.json` v2 schema
- Populating the empty `document_metadata` table in `.literature.db` (separate maintenance task)
- Rewriting the `/cite` command or `skill-cite` (unchanged by this refactor)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing `--lit` usage during skill preflight swap | High | Medium | Keep `--lit` flag syntax unchanged; change only the called script and output tag. Test with a real `--lit` invocation before committing. |
| Loss of working zotero script functionality during migration | Medium | Low | All 9 scripts are copied first (Phase 1), then references updated (Phase 4). File-by-file verification. |
| Source discovery API rate limits or downtime | Medium | Medium | Three-tier fallback: global index (offline) -> Zotero (local) -> online APIs. Discovery degrades gracefully to lower tiers. |
| Agents making excessive `literature-search.sh` calls, exceeding token budget | Medium | Low | Briefing includes clear instructions to read selectively. A single search returns ~3K tokens; agents typically make 1-2 searches, well within budget. |
| Skill-literature SKILL.md becomes too complex with absorbed modes | Medium | Medium | Restructure around two clean modes (discover/integrate) plus validate. Down from 7 modes to 3 entry points. |
| Bash permission rule too broad or too narrow | Low | Medium | Use specific pattern `Bash(bash .claude/scripts/literature-search.sh *)` matching only the search script. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 |
| 3 | 5 | 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Prerequisites -- Bash Permission and Environment [COMPLETED]

**Goal**: Establish the critical prerequisites that all subsequent phases depend on: Bash permission for `literature-search.sh` and explicit `LITERATURE_DIR` in settings.

**Tasks**:
- [ ] Add `Bash(bash .claude/scripts/literature-search.sh *)` to `.claude/settings.json` permissions.allow array
- [ ] Add `LITERATURE_DIR` to `.claude/settings.json` env block: `"LITERATURE_DIR": "/home/benjamin/Projects/Literature"`
- [ ] Verify `literature-search.sh` is callable: `bash .claude/scripts/literature-search.sh "test query"` returns JSON
- [ ] Remove `zot_flag` references from `skill-orchestrate/SKILL.md` (dead code cleanup -- `--zot` was never wired)

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/settings.json` -- add permission rule and LITERATURE_DIR env var
- `.claude/skills/skill-orchestrate/SKILL.md` -- remove `zot_flag` references

**Verification**:
- `jq '.permissions.allow[]' .claude/settings.json | grep literature-search` returns a match
- `jq '.env.LITERATURE_DIR' .claude/settings.json` returns the path
- `grep -c "zot_flag" .claude/skills/skill-orchestrate/SKILL.md` returns 0

---

### Phase 2: Extension Consolidation -- File Migration [COMPLETED]

**Goal**: Merge zotero extension artifacts into the literature extension and remove the zotero extension directory.

**Tasks**:
- [ ] Copy all 9 implemented zotero scripts from `.claude/extensions/zotero/scripts/` into `.claude/extensions/literature/scripts/`
- [ ] Merge zotero `keyword_overrides` (`zotero`, `bibliography`, `citation`) into literature `manifest.json`
- [ ] Merge zotero `index-entries.json` context entries into literature `index-entries.json`
- [ ] Merge relevant content from zotero `EXTENSION.md` into literature `EXTENSION.md` (Zotero integration section)
- [ ] Create unified context files:
  - `project/literature/domain/literature-index.md` (merged index schema reference)
  - `project/literature/patterns/agent-exploration.md` (briefing+tools exploration guide)
- [ ] Update literature `manifest.json` to v2.0.0 with merged provides, dependencies, keyword_overrides, and merge_targets
- [ ] Remove the duplicate `zotero-retrieve.sh` from `.claude/scripts/` (keep the extension copy temporarily for Phase 4 rollback safety)
- [ ] Remove `.claude/extensions/zotero/` directory entirely
- [ ] Remove `.claude/agents/zotero-agent.md`
- [ ] Update `.claude/agents/literature-agent.md` to document the briefing+tools pattern (how agents interact with literature, not a spawnable agent definition)

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/manifest.json` -- version bump to 2.0.0, merged provides/keywords/merge_targets
- `.claude/extensions/literature/EXTENSION.md` -- add Zotero integration docs
- `.claude/extensions/literature/index-entries.json` -- merge zotero context entries
- `.claude/extensions/literature/scripts/` -- add 9 migrated zotero scripts
- `.claude/extensions/literature/context/project/literature/domain/literature-index.md` -- new
- `.claude/extensions/literature/context/project/literature/patterns/agent-exploration.md` -- new
- `.claude/agents/literature-agent.md` -- rewrite with briefing+tools architecture description
- `.claude/scripts/zotero-retrieve.sh` -- remove (duplicate)
- `.claude/extensions/zotero/` -- remove entirely
- `.claude/agents/zotero-agent.md` -- remove

**Verification**:
- `ls .claude/extensions/zotero/ 2>&1` returns "No such file or directory"
- `ls .claude/extensions/literature/scripts/zotero-*.sh | wc -l` shows 9 migrated scripts
- `jq '.version' .claude/extensions/literature/manifest.json` returns `"2.0.0"`
- `jq '.keyword_overrides | keys' .claude/extensions/literature/manifest.json` contains zotero, bibliography, citation, literature

---

### Phase 3: Per-Repo Sub-Index and Briefing Generator [COMPLETED]

**Goal**: Implement the per-repo sub-index schema and the briefing generator script that replaces static content injection.

**Tasks**:
- [x] Create `literature-briefing.sh` in `.claude/scripts/`: *(completed)*
  - Reads `specs/literature-index.json` (per-repo sub-index)
  - For each entry, resolves metadata from `$LITERATURE_DIR/index.json` (title, authors, year, chunk count, total tokens, chunk paths)
  - Outputs a `<literature-briefing>` block to stdout (~300-500 tokens)
  - Includes usage instructions: Read tool for chunks, `literature-search.sh` for search
  - Edge cases: missing sub-index (exit 0, empty stdout), missing doc_id (skip with stderr warning), unset LITERATURE_DIR (use default)
- [x] Define the per-repo sub-index schema (`specs/literature-index.json`): *(completed: documented in Sub-Index Management section of SKILL.md)*
  - Fields: `project` (string), `literature_dir` (string|null, override), `entries` array
  - Entry fields: `doc_id` (required), `relevance` (optional), `added` (ISO date), `source` (optional: discover/manual/import)
  - Reference-only: no cached metadata; resolved at runtime from global index
- [x] Add sub-index jq operations to `skill-literature/SKILL.md`: *(completed)*
  - `init`: create file with empty entries array
  - `add <doc_id>`: validate against global index, append entry
  - `remove <doc_id>`: delete entry by doc_id
  - `list`: show entries with metadata resolved from global index
  - `validate`: check all doc_ids exist in global index, report orphans

**Timing**: 2 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-briefing.sh` -- new script
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` -- add sub-index management operations

**Verification**:
- Given a test `specs/literature-index.json` with 2-3 entries, `bash .claude/scripts/literature-briefing.sh` outputs a `<literature-briefing>` block under 500 tokens
- Block contains absolute paths to source files in `~/Projects/Literature/`
- Block contains usage instructions for Read and literature-search.sh
- Missing doc_ids produce stderr warnings but do not crash (exit 0)

---

### Phase 4: Source Discovery Pipeline [COMPLETED]

**Goal**: Create the source discovery script and wire it into the `/literature` command's Mode A.

**Tasks**:
- [x] Create `literature-discover.sh` in `.claude/scripts/`:
  - Input: search terms (string) and/or `--task N` (extracts description from state.json)
  - Tier 1 (offline): Search global `$LITERATURE_DIR/index.json` by title/keyword match
  - Tier 2 (local): Search Zotero via `zotero-search.sh` if `zotero-library.json` exists; identify PDF availability
  - Tier 3 (online): Semantic Scholar API search; Unpaywall DOI-to-PDF lookup; arXiv direct PDF detection
  - Output: JSON array of discovered sources with status tags (available, in_zotero, in_zotero_no_pdf, open_access, paywall)
  - Deduplication across tiers; graceful degradation when higher tiers fail
  - Exit codes: 0 (sources found), 1 (no sources), 2 (argument error)
- [x] Define SOURCES.md format for `specs/literature/SOURCES.md`:
  - Markdown table with columns: Title, Authors, Year, DOI, Status, Notes
  - Status values: [PENDING], [IN_ZOTERO], [PAYWALL], [FOUND], [RESOLVED]
  - Resolved entries include doc_id in Notes column
- [x] Update `/literature` command (`literature.md`) with two-mode argument parsing:
  - Mode A (discover): `/literature N`, `/literature "prompt"`, `/literature N "prompt"`
  - Mode B (integrate): `/literature`, `/literature ~/path/to/file.pdf`, `/literature ~/dir/`
  - Keep `--validate` flag for index health checks
  - Detection logic: path-like args -> integrate; numeric/text args -> discover; no args -> integrate (scan)
- [x] Update `skill-literature/SKILL.md` to implement the two modes:
  - Mode A: call `literature-discover.sh`, present results via AskUserQuestion, add selected doc_ids to sub-index, append unresolved to SOURCES.md
  - Mode B: resolve source files, run `literature-ingest.sh` for each, update sub-index, mark SOURCES.md entries as [RESOLVED]

**Timing**: 2.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-discover.sh` -- new script
- `.claude/extensions/literature/commands/literature.md` -- rewrite argument parsing for two modes
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` -- replace 7-mode structure with discover/integrate/validate

**Verification**:
- `bash .claude/scripts/literature-discover.sh "modal logic semantics"` returns JSON array (Tier 1 results at minimum)
- `/literature 758` triggers Mode A (discover) using task 758 description as search query
- `/literature ~/path/to/test.pdf` triggers Mode B (integrate)
- Bare `/literature` triggers Mode B (scan for unprocessed PDFs)

---

### Phase 5: Rewire --lit Flag in All Skill Preflights [COMPLETED]

**Goal**: Replace static content injection with briefing generation in all 6 skill preflight Stage 4a blocks. Add literature-access instructions to agent prompts.

**Tasks**:
- [x] Update `skill-researcher/SKILL.md` Stage 4a: replace `literature-retrieve.sh` call with `literature-briefing.sh`; change `<literature-context>` tag to `<literature-briefing>`
- [x] Update `skill-planner/SKILL.md` Stage 4a: same replacement
- [x] Update `skill-implementer/SKILL.md` Stage 4a: same replacement
- [x] Update `skill-researcher-hard/SKILL.md` Stage 4a: same replacement
- [x] Update `skill-planner-hard/SKILL.md` Stage 4a: same replacement
- [x] Update `skill-implementer-hard/SKILL.md` Stage 4a: same replacement
- [x] Add literature-access instructions to agent prompt sections in:
  - `.claude/agents/general-research-agent.md`
  - `.claude/agents/planner-agent.md`
  - `.claude/agents/general-implementation-agent.md`
  - `.claude/agents/general-research-hard-agent.md`
  - `.claude/agents/planner-hard-agent.md`
  - `.claude/agents/general-implementation-hard-agent.md`
  - Instructions: "When a `<literature-briefing>` block is present, use Read to access specific chunks and `bash .claude/scripts/literature-search.sh "query"` to search the full corpus. Read selectively -- only what you need for the task."
- [x] Remove `literature-retrieve.sh` from `.claude/extensions/core/scripts/` (deprecated with comment; retained for backward compat)

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` -- Stage 4a replacement
- `.claude/skills/skill-planner/SKILL.md` -- Stage 4a replacement
- `.claude/skills/skill-implementer/SKILL.md` -- Stage 4a replacement
- `.claude/skills/skill-researcher-hard/SKILL.md` -- Stage 4a replacement
- `.claude/skills/skill-planner-hard/SKILL.md` -- Stage 4a replacement
- `.claude/skills/skill-implementer-hard/SKILL.md` -- Stage 4a replacement
- `.claude/agents/general-research-agent.md` -- add literature-access instructions
- `.claude/agents/planner-agent.md` -- add literature-access instructions
- `.claude/agents/general-implementation-agent.md` -- add literature-access instructions
- `.claude/agents/general-research-hard-agent.md` -- add literature-access instructions
- `.claude/agents/planner-hard-agent.md` -- add literature-access instructions
- `.claude/agents/general-implementation-hard-agent.md` -- add literature-access instructions
- `.claude/extensions/core/scripts/literature-retrieve.sh` -- remove

**Verification**:
- `grep -r "literature-retrieve.sh" .claude/skills/` returns no results
- `grep -r "literature-briefing.sh" .claude/skills/skill-researcher/SKILL.md` returns a match
- `grep -r "literature-briefing.sh" .claude/skills/skill-researcher-hard/SKILL.md` returns a match
- `grep -c "literature-briefing" .claude/skills/skill-*/SKILL.md` shows 6 files with matches
- `grep "literature-search.sh" .claude/agents/general-research-agent.md` returns a match

---

### Phase 6: Documentation, Cleanup, and Verification [COMPLETED]

**Goal**: Update all documentation to reflect the unified system, remove remaining dead code, regenerate CLAUDE.md, and verify end-to-end.

**Tasks**:
- [x] Update literature extension `README.md` with unified architecture: *(completed)*
  - Global repo as source of truth
  - Per-repo sub-index (reference-only)
  - Briefing+tools pattern (with Design Decisions rationale)
  - Two-mode `/literature` command (discover + integrate)
  - Single `--lit` flag semantics
- [x] Update `.claude/extensions/literature/EXTENSION.md` merge source: *(completed)*
  - Replace injection-based `--lit` description with briefing+tools description
  - Remove any `--zot` references
  - Add source discovery documentation
- [x] Remove remaining dead code: *(completed)*
  - `zotero-retrieve.sh` from `.claude/extensions/literature/scripts/` (removed)
  - `zotero-search-index.sh` from `.claude/extensions/literature/scripts/` (removed)
  - `--zot` references: only remain in `literature-ingest.sh --zotero` (Zotero key flag, not the CLI flag; kept)
- [x] Update CLAUDE.md Literature Mode section to document new `--lit` behavior *(completed)*
- [x] Verify the `extension_zotero` section is removed from generated CLAUDE.md *(completed: no such section)*
- [x] Verify context index (`.claude/context/index.json`) has no orphan zotero entries *(completed: none found)*
- [x] Run `.claude/scripts/check-extension-docs.sh` to validate documentation consistency *(completed: literature passes; only pre-existing core/zulip issue)*
- [x] End-to-end test: create `specs/literature-index.json` with a known doc_id, invoke briefing script, verify `<literature-briefing>` block appears *(completed: output verified)*

**Timing**: 1.5 hours

**Depends on**: 5

**Files to modify**:
- `.claude/extensions/literature/README.md` -- rewrite for unified system
- `.claude/extensions/literature/EXTENSION.md` -- update merge source
- `.claude/extensions/literature/scripts/zotero-retrieve.sh` -- remove
- `.claude/extensions/literature/scripts/zotero-search-index.sh` -- remove
- `.claude/CLAUDE.md` -- regenerated from merge sources
- `.claude/context/index.json` -- verify/clean zotero entries

**Verification**:
- `.claude/scripts/check-extension-docs.sh` exits 0
- `grep "extension_zotero" .claude/CLAUDE.md` returns no matches
- `grep "literature-briefing" .claude/CLAUDE.md` returns a match in the Literature Mode section
- `grep -r "\-\-zot" .claude/` returns no matches in active files
- End-to-end: `<literature-briefing>` block appears (not `<literature-context>`)

## Testing & Validation

- [ ] Verify `--lit` flag produces a `<literature-briefing>` block under 500 tokens (not full content injection)
- [ ] Verify agents can `Read` literature chunks using absolute paths from the briefing
- [ ] Verify `literature-search.sh` is callable without permission prompts in orchestrate mode
- [ ] Verify `literature-discover.sh` returns results for a known topic from at least Tier 1
- [ ] Verify `specs/literature-index.json` sub-index creation, add, remove, list, and validate operations work
- [ ] Verify all 9 migrated zotero scripts are present and executable in the unified extension
- [ ] Verify no `--zot` flag references remain in active command/skill files
- [ ] Verify extension loader picks up the unified extension correctly (no zotero extension errors)
- [ ] Verify `check-extension-docs.sh` passes with no errors
- [ ] Verify SOURCES.md can be created and entries can transition through status values

## Artifacts & Outputs

- `specs/758_unified_literature_system/plans/08_unified-literature-plan.md` (this file)
- `.claude/extensions/literature/` -- unified extension (v2.0.0)
- `.claude/scripts/literature-briefing.sh` -- briefing generator (replaces content injection)
- `.claude/scripts/literature-discover.sh` -- three-tier source discovery pipeline
- `.claude/agents/literature-agent.md` -- updated architecture description (briefing+tools pattern)
- `.claude/extensions/literature/context/project/literature/domain/literature-index.md` -- unified index schema reference
- `.claude/extensions/literature/context/project/literature/patterns/agent-exploration.md` -- briefing+tools exploration guide
- `.claude/settings.json` -- updated with LITERATURE_DIR and search permission

## Rollback/Contingency

All changes are file-level and git-tracked. The zotero extension directory should be committed to git before deletion (Phase 2). If the refactor fails at any point:

1. Restore `.claude/extensions/zotero/` from git: `git checkout HEAD -- .claude/extensions/zotero/`
2. Restore `.claude/agents/zotero-agent.md` from git
3. Restore `.claude/scripts/zotero-retrieve.sh` from git
4. Revert `manifest.json` to pre-2.0.0 version
5. Revert skill preflight changes (restore `literature-retrieve.sh` calls in 6 SKILL.md files)
6. Revert `.claude/settings.json` changes

The global Literature/ repo at `~/Projects/Literature/` is never modified by this plan. The `/cite` command and `skill-cite` are untouched throughout.
