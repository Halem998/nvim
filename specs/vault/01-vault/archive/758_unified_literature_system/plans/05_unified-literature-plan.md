# Implementation Plan: Unified Literature System

- **Task**: 758 - Unified Literature System
- **Status**: [NOT STARTED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_infrastructure-audit.md, reports/02_agent-design-patterns.md, reports/03_storage-architecture.md, reports/04_extension-consolidation.md
- **Artifacts**: plans/05_unified-literature-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor the literature and zotero extensions into a single unified literature extension that replaces static context injection (`--lit`/`--zot`) with a briefing+tools approach (Pattern 3C). The global Literature/ repo at `~/Projects/Literature/` already exists with 222 index entries and SQLite FTS5 search. The work involves: consolidating two extensions into one, designing a per-repo sub-index (`specs/literature-index.json`), replacing the injection model with a compact briefing block + on-demand `Read`/`literature-search.sh` tools, unifying four scoring algorithms into the existing FTS5 search, and cleaning up dead `--zot` wiring. Done when: a single `--lit` flag produces a briefing block instead of full content injection, agents can search and read literature on demand, the zotero extension directory is removed, and per-repo sub-indexes point to the global Literature/ repo.

### Research Integration

Four research reports integrated:
- **01_infrastructure-audit.md**: Complete inventory of both extensions. Key finding: all 9 zotero scripts are fully implemented (2,375 lines total, NOT stubs). The `--zot` flag was never wired into `parse-command-args.sh`. Four different scoring algorithms exist across retrieval scripts.
- **02_agent-design-patterns.md**: Recommends Pattern 3C (Briefing + Tools) -- inject ~300-token briefing of available papers, let agents use `Read` and `literature-search.sh` on demand. Token savings: 200-500 vs 4,000-8,000.
- **03_storage-architecture.md**: Global Literature/ repo at `~/Projects/Literature/` is operational with 222 entries, FTS5 database, and two newer scripts (`literature-search.sh`, `literature-ingest.sh`) that already support the agent-callable interface.
- **04_extension-consolidation.md**: Strategy for merging extensions. Note: Report 04 incorrectly states zotero scripts are stubs -- they are fully implemented with graceful degradation (exit 2 when `zot` CLI absent). Working code must be preserved/migrated.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances ROADMAP.md Phase 2 item "Literature centralization" (already marked completed for the global repo creation in task 710). This task extends that work with extension consolidation, sub-index design, and the briefing+tools agent interface.

## Goals & Non-Goals

**Goals**:
- Consolidate literature and zotero extensions into a single `literature` extension (v2.0.0)
- Design and implement per-repo sub-index (`specs/literature-index.json`) pointing to global Literature/ repo
- Replace static content injection with briefing+tools pattern (Pattern 3C)
- Unify `--lit` and `--zot` under a single `--lit` flag
- Preserve all working zotero scripts (2,375 lines) by migrating them into the unified extension
- Set `LITERATURE_DIR` explicitly in `.claude/settings.json`

**Non-Goals**:
- Rebuilding the global Literature/ repo structure (already well-designed)
- Rewriting `literature-search.sh` or `literature-ingest.sh` (already operational)
- Implementing a full literature-agent as a separate spawnable subagent (Pattern 3C uses briefing+tools, not a separate agent)
- Changing the FTS5 database schema or `index.json` v2 schema
- Populating the empty `document_metadata` table (separate maintenance task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing `--lit` usage in skills | High | Medium | Keep `--lit` flag syntax unchanged; change behavior behind it from injection to briefing |
| Loss of zotero-specific functionality during migration | Medium | Low | All 9 scripts are preserved; migrate file-by-file with verification |
| Skill-literature SKILL.md becomes too complex with absorbed modes | Medium | Medium | Restructure into 3 capability groups (Conversion, Search/Import, Agent Interface) |
| Briefing block fails to provide enough context for agents | Medium | Low | Include full paths in briefing so agents can Read directly; FTS5 search as fallback |
| Per-repo sub-index creates maintenance burden | Low | Low | Sub-index is minimal (just doc_ids + notes); auto-populated by `/literature --add` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extension Consolidation -- File Migration [NOT STARTED]

**Goal**: Merge zotero extension artifacts into the literature extension and remove the zotero extension directory.

**Tasks**:
- [ ] Copy all 9 implemented zotero scripts from `.claude/extensions/zotero/scripts/` into `.claude/extensions/literature/scripts/`
- [ ] Merge zotero `keyword_overrides` (`zotero`, `bibliography`, `citation`) into literature `manifest.json`
- [ ] Merge zotero `index-entries.json` context entries into literature `index-entries.json`
- [ ] Merge relevant content from zotero `EXTENSION.md` into literature `EXTENSION.md` (add Zotero integration section)
- [ ] Create unified context files: `project/literature/domain/literature-index.md` (merged index schema) and `project/literature/patterns/agent-exploration.md` (exploration guide)
- [ ] Update literature `manifest.json` to v2.0.0 with merged provides, dependencies, and merge_targets
- [ ] Remove the duplicate `zotero-retrieve.sh` from `.claude/scripts/` (keep the extension copy)
- [ ] Remove `.claude/extensions/zotero/` directory entirely
- [ ] Remove `.claude/agents/zotero-agent.md` (replaced by unified literature-agent)
- [ ] Update `.claude/agents/literature-agent.md` to be a real agent definition (not docs-only) describing the briefing+tools pattern

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/manifest.json` -- version bump, merged provides/keywords
- `.claude/extensions/literature/EXTENSION.md` -- add Zotero integration docs
- `.claude/extensions/literature/index-entries.json` -- merge zotero context entries
- `.claude/extensions/literature/scripts/` -- add 9 migrated zotero scripts
- `.claude/extensions/literature/context/project/literature/` -- new context files
- `.claude/agents/literature-agent.md` -- rewrite as real agent definition
- `.claude/scripts/zotero-retrieve.sh` -- remove (duplicate)
- `.claude/extensions/zotero/` -- remove entirely
- `.claude/agents/zotero-agent.md` -- remove

**Verification**:
- `ls .claude/extensions/zotero/` returns "No such file or directory"
- `ls .claude/extensions/literature/scripts/zotero-*.sh` shows all 9 migrated scripts
- `jq '.version' .claude/extensions/literature/manifest.json` returns `"2.0.0"`
- `jq '.keyword_overrides' .claude/extensions/literature/manifest.json` contains `zotero`, `bibliography`, `citation`, `literature`

---

### Phase 2: Per-Repo Sub-Index Design and Tooling [NOT STARTED]

**Goal**: Implement the `specs/literature-index.json` sub-index schema and management commands.

**Tasks**:
- [ ] Define the per-repo sub-index schema in a new script `literature-subindex.sh` with subcommands: `init`, `add <doc_id>`, `remove <doc_id>`, `list`, `validate`
- [ ] Schema: `{ "version": 1, "literature_dir": null, "entries": [{ "doc_id": "string", "relevance_note": "string", "added": "ISO8601", "tags": ["string"] }] }`
- [ ] `init` creates `specs/literature-index.json` with empty entries array
- [ ] `add` looks up doc_id in global `$LITERATURE_DIR/index.json`, validates it exists, appends entry with timestamp
- [ ] `remove` deletes entry by doc_id
- [ ] `list` shows entries with metadata fetched from global index (title, authors, token_count)
- [ ] `validate` checks all doc_ids exist in global index, reports orphans
- [ ] Wire `--add`, `--remove`, `--status` subcommands in `literature.md` command to dispatch to `literature-subindex.sh`
- [ ] Update `skill-literature/SKILL.md` to add sub-index management modes

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-subindex.sh` -- new script
- `.claude/extensions/literature/commands/literature.md` -- add `--add`, `--remove` subcommands
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` -- add sub-index management modes

**Verification**:
- `bash .claude/extensions/literature/scripts/literature-subindex.sh init` creates `specs/literature-index.json`
- `bash .claude/extensions/literature/scripts/literature-subindex.sh add blackburn_2002_book` adds an entry (if doc exists in global index)
- `bash .claude/extensions/literature/scripts/literature-subindex.sh list` shows entries with metadata
- `bash .claude/extensions/literature/scripts/literature-subindex.sh validate` reports no orphans

---

### Phase 3: Briefing Generator Script [NOT STARTED]

**Goal**: Create `literature-briefing.sh` that generates a compact briefing block from the per-repo sub-index, replacing the full content injection approach.

**Tasks**:
- [ ] Create `literature-briefing.sh` that reads `specs/literature-index.json` and generates a `<literature-briefing>` block
- [ ] For each sub-index entry, look up full metadata from global `$LITERATURE_DIR/index.json` (title, authors, year, token_count, chunk paths)
- [ ] For document-level entries (parent_doc == null), list all child chunks with their paths and token counts
- [ ] Output format: numbered list of available papers with title, author, year, token count, and absolute paths
- [ ] Include usage instructions in the briefing: "To read a paper: use Read tool with the path. To search: Bash('literature-search.sh query')"
- [ ] Enforce a compact token budget (~500 tokens max for the briefing itself)
- [ ] Handle edge cases: sub-index not found (return empty), doc_id not in global index (skip with warning to stderr), LITERATURE_DIR not set (use default)

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-briefing.sh` -- new script
- `.claude/extensions/literature/scripts/literature-retrieve.sh` -- mark as deprecated (keep for fallback)

**Verification**:
- Given a `specs/literature-index.json` with 2-3 entries, `literature-briefing.sh` outputs a `<literature-briefing>` block under 500 tokens
- Block contains absolute paths to source files
- Block contains usage instructions for Read and literature-search.sh
- Missing doc_ids produce stderr warnings but do not crash

---

### Phase 4: Rewire --lit Flag and Skill Preflights [NOT STARTED]

**Goal**: Replace static content injection in skill preflights with the briefing+tools approach. Unify `--lit` and `--zot` under a single `--lit` flag.

**Tasks**:
- [ ] Update `parse-command-args.sh`: remove any `--zot`/`ZOT_FLAG` parsing (confirm it does not exist, then ensure it stays absent)
- [ ] Update `skill-researcher/SKILL.md` Stage 4a: replace call to `literature-retrieve.sh` with call to `literature-briefing.sh`; inject `<literature-briefing>` instead of `<literature-context>`
- [ ] Update `skill-planner/SKILL.md` Stage 4a: same briefing replacement
- [ ] Update `skill-implementer/SKILL.md` Stage 4a: same briefing replacement
- [ ] Update `skill-orchestrate/SKILL.md`: remove `zot_flag` threading from delegation context JSON; keep only `lit_flag` which now triggers briefing
- [ ] Add literature-access instructions to agent prompt templates in research, planner, and implementation agents (brief paragraph explaining Read + literature-search.sh)
- [ ] Update `CLAUDE.md` Literature Mode section: document new `--lit` behavior (briefing+tools, not injection)
- [ ] Remove `--zot` references from CLAUDE.md, command docs, and context files
- [ ] Set `LITERATURE_DIR` in `.claude/settings.json` env block

**Timing**: 2 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` -- replace injection with briefing
- `.claude/skills/skill-planner/SKILL.md` -- replace injection with briefing
- `.claude/skills/skill-implementer/SKILL.md` -- replace injection with briefing
- `.claude/skills/skill-orchestrate/SKILL.md` -- remove `zot_flag`, update `lit_flag` semantics
- `.claude/agents/general-research-agent.md` -- add literature-access instructions
- `.claude/agents/planner-agent.md` -- add literature-access instructions
- `.claude/agents/general-implementation-agent.md` -- add literature-access instructions
- `.claude/settings.json` -- add `LITERATURE_DIR` to env
- `.claude/extensions/literature/EXTENSION.md` -- update `--lit` docs

**Verification**:
- `grep -r "zot_flag" .claude/skills/` returns no results
- `grep -r "literature-retrieve.sh" .claude/skills/` returns no results (replaced by briefing.sh)
- `grep "literature-briefing.sh" .claude/skills/skill-researcher/SKILL.md` returns a match
- `grep "LITERATURE_DIR" .claude/settings.json` returns a match
- `grep -r "\-\-zot" .claude/` returns no results outside of archive/deprecated files

---

### Phase 5: Scoring Unification and Script Cleanup [NOT STARTED]

**Goal**: Remove duplicated scoring algorithms and consolidate retrieval into the existing FTS5 search infrastructure.

**Tasks**:
- [ ] Remove `literature-retrieve.sh` from `.claude/extensions/core/scripts/` (replaced by briefing.sh; FTS5 search via literature-search.sh handles all queries)
- [ ] Remove `zotero-retrieve.sh` from `.claude/extensions/literature/scripts/` (migrated in Phase 1, now superseded by briefing approach)
- [ ] Remove `zotero-search-index.sh` from `.claude/extensions/literature/scripts/` (FTS5 search replaces per-repo index search)
- [ ] Verify `literature-search.sh` in `.claude/scripts/` handles the use cases previously served by the removed scripts (keyword search, metadata lookup, cross-reference)
- [ ] Audit remaining zotero scripts for hardcoded paths to `specs/zotero-index.json` -- update to use `specs/literature-index.json` or remove references
- [ ] Create a shared utility `literature-common.sh` extracting: stop-word list, keyword extraction function, token estimation (`words * 1.3`) -- sourced by any remaining scripts that need these

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/core/scripts/literature-retrieve.sh` -- remove
- `.claude/extensions/literature/scripts/zotero-retrieve.sh` -- remove
- `.claude/extensions/literature/scripts/zotero-search-index.sh` -- remove
- `.claude/extensions/literature/scripts/literature-common.sh` -- new shared utilities
- Remaining zotero scripts -- update `specs/zotero-index.json` references

**Verification**:
- `ls .claude/extensions/core/scripts/literature-retrieve.sh` returns "No such file or directory"
- `ls .claude/extensions/literature/scripts/zotero-retrieve.sh` returns "No such file or directory"
- `grep -r "zotero-index.json" .claude/` returns no active references (only in deprecated/archive)
- `literature-search.sh "modal logic"` returns JSON results from FTS5

---

### Phase 6: Documentation and CLAUDE.md Regeneration [NOT STARTED]

**Goal**: Update all documentation to reflect the unified system, regenerate CLAUDE.md from merge sources, and verify end-to-end.

**Tasks**:
- [ ] Update literature extension `README.md` with unified architecture: global repo, sub-index, briefing+tools, single `--lit` flag
- [ ] Update `.claude/extensions/literature/EXTENSION.md` merge source to produce correct CLAUDE.md section (remove zotero section, update literature section)
- [ ] Regenerate CLAUDE.md from merge sources (run the loader/generator)
- [ ] Remove the `extension_zotero` section from CLAUDE.md if the generator does not remove it automatically
- [ ] Update `/literature` command help text in `literature.md` to include new subcommands (`--add`, `--remove`)
- [ ] Verify context index (`index.json`) has correct entries for the unified extension (no orphan zotero entries)
- [ ] Run `.claude/scripts/check-extension-docs.sh` to validate documentation consistency
- [ ] End-to-end test: create a `specs/literature-index.json` with a known doc_id, run `/research` or equivalent with `--lit`, verify briefing block appears instead of full injection

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `.claude/extensions/literature/README.md` -- rewrite for unified system
- `.claude/extensions/literature/EXTENSION.md` -- update merge source
- `.claude/CLAUDE.md` -- regenerated
- `.claude/extensions/literature/commands/literature.md` -- updated help text
- `.claude/context/index.json` -- verify/clean zotero entries

**Verification**:
- `.claude/scripts/check-extension-docs.sh` exits 0
- `grep "zotero" .claude/CLAUDE.md` returns only historical/incidental references, no `extension_zotero` section
- `grep "literature-briefing" .claude/CLAUDE.md` returns a match in the Literature Mode section
- End-to-end test shows `<literature-briefing>` block (not `<literature-context>`)

## Testing & Validation

- [ ] Verify no `--zot` flag references remain in active command/skill files
- [ ] Verify `--lit` flag produces a briefing block under 500 tokens (not full content injection)
- [ ] Verify agents can `Read` literature chunks using paths from the briefing
- [ ] Verify `literature-search.sh` works from agent context (returns JSON metadata)
- [ ] Verify `specs/literature-index.json` sub-index creation, population, and validation
- [ ] Verify all 9 migrated zotero scripts are present and executable in the unified extension
- [ ] Verify extension loader picks up the unified extension correctly (no zotero extension errors)
- [ ] Verify `check-extension-docs.sh` passes

## Artifacts & Outputs

- `specs/758_unified_literature_system/plans/05_unified-literature-plan.md` (this file)
- `.claude/extensions/literature/` -- unified extension (v2.0.0)
- `.claude/extensions/literature/scripts/literature-briefing.sh` -- briefing generator
- `.claude/extensions/literature/scripts/literature-subindex.sh` -- sub-index management
- `.claude/extensions/literature/scripts/literature-common.sh` -- shared utilities
- `.claude/extensions/literature/context/project/literature/` -- unified context files
- `.claude/agents/literature-agent.md` -- updated agent definition

## Rollback/Contingency

The zotero extension directory should be committed to git before deletion (Phase 1). If consolidation fails:
1. Restore `.claude/extensions/zotero/` from git history (`git checkout HEAD -- .claude/extensions/zotero/`)
2. Restore `.claude/agents/zotero-agent.md` from git history
3. Restore `.claude/scripts/zotero-retrieve.sh` from git history
4. Revert `manifest.json` version to pre-2.0.0
5. Revert skill preflight changes (restore `literature-retrieve.sh` calls)

All changes are file-level and git-tracked, making rollback straightforward. The global Literature/ repo at `~/Projects/Literature/` is never modified by this plan.
