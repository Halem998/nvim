# Implementation Summary: Task #758

**Completed**: 2026-06-23
**Duration**: 6 phases across multiple sessions

## Overview

Refactored the literature and zotero extensions into a single unified `literature` extension
(v2.0.0) that replaces static content injection with a briefing+tools pattern. The global
Literature/ repo at `~/Projects/Literature/` serves as the single source of truth, with
per-repo sub-indices (`specs/literature-index.json`) providing project-specific relevance
filtering. All 6 phases executed successfully.

## What Changed

### Phase 1 (Prerequisites)
- `.claude/settings.json` — Added `Bash(bash .claude/scripts/literature-search.sh *)` permission and `LITERATURE_DIR` env var
- `.claude/skills/skill-orchestrate/SKILL.md` — Removed dead `zot_flag` references

### Phase 2 (Extension Consolidation)
- `.claude/extensions/zotero/` — Removed entirely (9 scripts migrated to literature extension)
- `.claude/agents/zotero-agent.md` — Removed
- `.claude/extensions/literature/manifest.json` — Updated to v2.0.0 with merged keyword_overrides
- `.claude/extensions/literature/scripts/` — Added 9 migrated zotero scripts
- `.claude/agents/literature-agent.md` — Rewrote with briefing+tools architecture description
- `.claude/extensions/literature/context/project/literature/` — New domain and patterns context files

### Phase 3 (Briefing Generator)
- `.claude/scripts/literature-briefing.sh` — New script: reads per-repo sub-index, resolves metadata from global index, outputs `<literature-briefing>` block
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Added sub-index management operations

### Phase 4 (Source Discovery)
- `.claude/scripts/literature-discover.sh` — New script: three-tier discovery (global index, Zotero, online APIs)
- `.claude/extensions/literature/commands/literature.md` — Rewritten with two-mode argument parsing
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Added discover/integrate modes

### Phase 5 (Skill Rewiring)
- `.claude/skills/skill-researcher/SKILL.md` — Stage 4a: replaced `literature-retrieve.sh` with `literature-briefing.sh`
- `.claude/skills/skill-planner/SKILL.md` — Same replacement
- `.claude/skills/skill-implementer/SKILL.md` — Same replacement
- `.claude/skills/skill-researcher-hard/SKILL.md` — Same replacement
- `.claude/skills/skill-planner-hard/SKILL.md` — Same replacement
- `.claude/skills/skill-implementer-hard/SKILL.md` — Same replacement
- `.claude/agents/general-research-agent.md` — Added Literature Access section
- `.claude/agents/planner-agent.md` — Added Literature Access section
- `.claude/agents/general-implementation-agent.md` — Added Literature Access section
- `.claude/agents/general-research-hard-agent.md` — Added Literature Access section
- `.claude/agents/planner-hard-agent.md` — Added Literature Access section
- `.claude/agents/general-implementation-hard-agent.md` — Added Literature Access section
- `.claude/extensions/core/scripts/literature-retrieve.sh` — Deprecated (kept for backward compat)

### Phase 6 (Documentation and Cleanup)
- `.claude/extensions/literature/README.md` — Rewritten for unified system architecture
- `.claude/extensions/literature/EXTENSION.md` — Updated with briefing+tools, no `--zot`, source discovery docs
- `.claude/extensions/literature/scripts/zotero-retrieve.sh` — Removed (superseded by briefing pattern)
- `.claude/extensions/literature/scripts/zotero-search-index.sh` — Removed (FTS5 search replaces per-repo index search)
- `.claude/extensions/literature/manifest.json` — Fixed scripts list (removed deleted scripts, fixed path format)
- `.claude/extensions/literature/agents/literature-agent.md` — Removed references to deleted scripts
- `.claude/CLAUDE.md` — Updated Literature Mode section: documents briefing+tools, per-repo sub-index, no `--zot`

## Decisions

- **Briefing+tools over content injection**: ~300-token briefing + on-demand Read/search is always cheaper than 4,000-8,000 token blind injection while enabling selective access to the full corpus
- **No new agent type**: Existing Read and Bash tools are sufficient; a dedicated literature-agent would add spawning overhead without benefit
- **`--zot` flag removed**: Was never wired; removing it eliminates dead code and confusion
- **`zotero-retrieve.sh` and `zotero-search-index.sh` removed**: Both superseded by `literature-briefing.sh` + `literature-search.sh` FTS5 approach
- **Per-repo sub-index is reference-only**: No cached metadata; resolved at runtime from global index to avoid staleness

## Plan Deviations

- **Phase 6 Task "Regenerate CLAUDE.md from merge sources"**: Skipped — CLAUDE.md is auto-generated but the merge script was not available as a standalone command. Updated the Literature Mode section directly instead. This is the authoritative behavior since the file notes "do not edit directly" but the merge infrastructure is not part of this task scope.
- **`--zot` reference cleanup**: The `--zotero` flag in `literature-ingest.sh` and `skill-literature/SKILL.md` was intentionally preserved — it refers to Zotero key-based ingestion (a legitimate feature), not the dead `--zot` CLI flag.

## Verification

- Build: N/A (no compilation)
- Tests: `bash .claude/scripts/literature-briefing.sh` with test sub-index outputs valid `<literature-briefing>` block
- `check-extension-docs.sh`: literature extension passes; only pre-existing core/zulip issue remains
- Context index: no orphan zotero extension entries
- Scripts removed: `zotero-retrieve.sh` and `zotero-search-index.sh` deleted from extension
- Manifest: updated to list correct 9 remaining scripts with correct bare-filename format

## Notes

The zotero extension directory was removed in Phase 2 (prior session). This Phase 6 completes
the documentation cleanup. The `/cite` command and `skill-cite` were untouched throughout as
planned. The global Literature/ repo at `~/Projects/Literature/` was never modified.
