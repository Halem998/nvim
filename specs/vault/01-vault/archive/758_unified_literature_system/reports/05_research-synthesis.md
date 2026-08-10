# Research Synthesis: Unified Literature System

- **Task**: 758 - Unified literature system
- **Status**: [COMPLETED]
- **Sources**: reports/01 through 04

## Executive Summary

Four research dimensions converge on a clear refactoring path. A global Literature/ repo already exists and is well-designed. The two extensions share chunk storage but maintain incompatible indexes. The zotero extension's scripts are fully implemented (not stubs, despite outdated documentation), but `--zot` was never wired into the command pipeline. The recommended architecture replaces static context injection with a lightweight briefing + on-demand tools pattern, consolidates both extensions into one, and introduces a per-repo sub-index as a relevance filter.

## Cross-Report Conflict Resolution

Report 04 (Extension Consolidation) incorrectly states the 9 zotero scripts are "stubs that exit with code 2." Report 01 (Infrastructure Audit) verified all 9 are **fully implemented** (2,375 total lines). The scripts use `exit 2` solely as graceful degradation when the `zot` CLI is unavailable, not as placeholder behavior. This means consolidation must preserve and migrate real working code rather than replacing stubs.

## Current State

### What exists and works

| Component | Location | Status |
|-----------|----------|--------|
| Global Literature repo | `~/Projects/Literature/` | 222 index entries, 47 documents, SQLite FTS5 (180 chunks) |
| `literature-search.sh` | `.claude/scripts/` | 7 subcommands, FTS5 BM25 search, two-tier DB support |
| `literature-ingest.sh` | `.claude/scripts/` | Full pipeline: PDF to markdown to chunk to index to SQLite |
| Literature extension | `.claude/extensions/literature/` | Fully implemented: skill (1,567 lines), 2 scripts, 2 commands |
| Zotero extension scripts | `.claude/extensions/zotero/scripts/` | 9 scripts, 2,375 lines total, all functional |
| `--lit` flag | `parse-command-args.sh` to skill preflights | Wired through researcher, planner, implementer |

### What is broken or incomplete

| Issue | Detail |
|-------|--------|
| `--zot` flag never wired | Not parsed by `parse-command-args.sh`; only exists in docs and orchestrate stubs |
| Dual incompatible indexes | `index.json` (16 fields) vs `zotero-index.json` (20 fields) for the same chunks |
| Four scoring algorithms | `literature-retrieve.sh`, `zotero-retrieve.sh`, `zotero-search.sh`, `zotero-search-index.sh` each use different weights |
| Duplicated code | Stop-word lists (4x), keyword extraction (4x), token estimation (3x), identical `zotero-retrieve.sh` in 2 locations |
| `document_metadata` table empty | `.literature.db` has 180 chunks but 0 document-level metadata rows |
| Passive injection model | Agents receive pre-scored content, cannot explore or search autonomously |
| Outdated zotero README | Claims tasks 750-753 "Not started" despite all scripts being implemented |

## Architectural Decisions

### 1. Global Literature/ repo as single source of truth

The repo at `~/Projects/Literature/` is already operational with a sound structure: `index.json` (source of truth, git-tracked) + `.literature.db` (FTS5 search cache, derived, gitignored) + `sources/` (markdown chunks, git-tracked) + PDFs (gitignored, re-obtainable from Zotero). No structural changes needed. Set `LITERATURE_DIR` explicitly in `.claude/settings.json` to formalize the convention.

### 2. Per-repo sub-index with lightweight references

Replace both `specs/literature/index.json` and `specs/zotero-index.json` with a single `specs/literature-index.json` containing only `doc_id` references, relevance notes, and project-specific tags. The agent resolves full metadata from the global index at runtime, avoiding staleness from duplicated fields. Whole documents are referenced (not individual chunks) — the agent decides which chunks to read.

### 3. Briefing + Tools replaces static injection (Pattern 3C)

Instead of injecting 4,000-8,000 tokens of literature content into agent prompts, inject a ~300-token briefing listing available papers (titles, paths, token counts). Agents use the existing `Read` tool and `literature-search.sh` to pull specific content on demand. This requires no new agent type — just a briefing generator script, updated skill preflights, and literature-access instructions in agent prompts.

### 4. Single merged extension (v2.0.0)

Absorb the zotero extension into the literature extension. Keep `/literature` as the single command with expanded subcommands (absorbing `/zotero --setup`, `--add`, `--remove`, etc.). Delete the `/zotero` command entirely. The merged manifest inherits `keyword_overrides`, context entries, and index merge targets from both extensions.

### 5. Single `--lit` flag

Replace both `--lit` and `--zot` with a single `--lit` flag whose semantics change from "inject literature content" to "generate literature briefing and enable search tools." Since `--zot` was never wired, this is backwards-compatible in flag syntax.

### 6. Unified scoring via FTS5

Replace the four keyword-overlap and weighted-scoring algorithms with `literature-search.sh`'s existing FTS5 BM25 search. The per-repo sub-index provides a relevance boost for project-curated entries. One search interface, one scoring algorithm.

## What needs building vs what exists

### Reuse directly

- `~/Projects/Literature/` repo structure, `index.json`, `.literature.db`
- `literature-search.sh` (7 subcommands, FTS5 search)
- `literature-ingest.sh` (full pipeline with `--zotero` support)
- `skill-literature` conversion/indexing logic
- `skill-cite` and `cite-extract.sh`
- `zotero-search.sh` (CSL-JSON library search)
- All 9 zotero scripts (migrate into unified extension)

### Build new

- `specs/literature-index.json` schema and per-repo management tooling
- `literature-briefing.sh` — generates compact briefing from sub-index + global index
- Modified skill preflights (researcher, planner, implementer) to generate briefing instead of full injection
- Literature-access instructions added to agent prompt templates
- Merged extension manifest, EXTENSION.md, README.md
- `document_metadata` table population in `.literature.db`
- `LITERATURE_DIR` entry in `.claude/settings.json`

### Remove

- `.claude/extensions/zotero/` directory (after migrating scripts)
- `zotero-retrieve.sh` duplicate in `.claude/scripts/`
- `--zot` dead code in `skill-orchestrate`
- `specs/zotero-index.json` concept (replaced by `specs/literature-index.json`)
- `extension_zotero` section from CLAUDE.md auto-generation
