# Implementation Plan: Task #733

- **Task**: 733 - Wire LITERATURE_DIR globally, build FTS5 database, validate unified collection
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 732 (schema unification)
- **Research Inputs**: specs/733_literature_infrastructure_wiring/reports/01_infrastructure-wiring-research.md
- **Artifacts**: plans/01_infrastructure-wiring-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Wire LITERATURE_DIR into the global Claude Code settings (Home Manager-managed), synchronize `literature-retrieve.sh` across all three project roots (nvim, BimodalLogic, cslib) so they share Tier 1 FTS5 support, build the FTS5 database from existing Literature collection content, and validate the `--lit` flag end-to-end. The key constraint is that FTS5 requires `chunks.json` manifests produced by the ingest pipeline -- the existing 183 flat markdown files must be chunked first.

### Research Integration

The research report confirmed: (1) LITERATURE_DIR is present in nvim's project settings.json but absent from the global `~/.dotfiles/config/claude/settings.json`; (2) no `.literature.db` exists anywhere; (3) zero `chunks.json` manifests exist in the Literature directory; (4) nvim has Tier 1 FTS5 code (301 lines) while BimodalLogic (234 lines) and cslib (205 lines) lack it; (5) cslib's version doesn't even handle LITERATURE_DIR. sqlite3 3.51.2 with FTS5 support is confirmed available.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- LITERATURE_DIR available as a Claude Code env var in all three project roots via global settings
- Remove per-project LITERATURE_DIR override from nvim's .claude/settings.json
- Synchronize `literature-retrieve.sh` (nvim's Tier 1+2 version) to BimodalLogic and cslib
- Build `.literature.db` FTS5 database in ~/Projects/Literature/
- Validate `--lit` flag produces output from all three project roots

**Non-Goals**:
- Ingesting all 870 Zotero PDFs (out of scope; only existing Literature markdown files)
- Installing marker_single or upgrading conversion tools
- Modifying the FTS5 schema or literature-build-index.sh internals
- Deploying new literature-search.sh to BL/cslib (follows naturally from retrieve.sh sync)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| literature-build-index.sh requires chunks.json that don't exist | H | H | Run literature-chunk.sh on existing flat .md files to generate chunks.json manifests |
| Updating literature-retrieve.sh in BL/cslib could break Tier 2 fallback | M | L | The nvim version is a superset; test with no DB present to confirm Tier 2 still works |
| home-manager switch may overwrite runtime Claude Code settings | M | L | Standard procedure; the _NOTE in settings.json documents this is expected |
| literature-search.sh not present in BL/cslib for Tier 1 activation | M | M | Copy literature-search.sh alongside literature-retrieve.sh; both are needed for Tier 1 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire LITERATURE_DIR in Global Settings [COMPLETED]

**Goal**: Add LITERATURE_DIR to the global Claude Code settings so all projects inherit it, and remove the per-project override from nvim.

**Tasks**:
- [ ] Edit `~/.dotfiles/config/claude/settings.json`: add `"LITERATURE_DIR": "/home/benjamin/Projects/Literature"` to the `env` block
- [ ] Edit `/home/benjamin/.config/nvim/.claude/settings.json`: remove `"LITERATURE_DIR": "/home/benjamin/Projects/Literature"` from the `env` block (keep `SLASH_COMMAND_TOOL_CHAR_BUDGET`)
- [ ] Run `home-manager switch` to deploy updated global settings to `~/.claude/settings.json`
- [ ] Verify: read `~/.claude/settings.json` and confirm LITERATURE_DIR is present in env block

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `~/.dotfiles/config/claude/settings.json` - Add LITERATURE_DIR to env block
- `/home/benjamin/.config/nvim/.claude/settings.json` - Remove LITERATURE_DIR from env block

**Verification**:
- `jq '.env.LITERATURE_DIR' ~/.claude/settings.json` returns `/home/benjamin/Projects/Literature`
- `jq '.env.LITERATURE_DIR' /home/benjamin/.config/nvim/.claude/settings.json` returns `null`

---

### Phase 2: Synchronize literature-retrieve.sh and literature-search.sh to BL and cslib [COMPLETED]

**Goal**: Deploy nvim's Tier 1+2 `literature-retrieve.sh` and `literature-search.sh` to BimodalLogic and cslib so all three projects support FTS5 on-demand search.

**Tasks**:
- [ ] Copy `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` to `/home/benjamin/Projects/BimodalLogic/.claude/scripts/literature-retrieve.sh`
- [ ] Copy `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` to `/home/benjamin/Projects/cslib/.claude/scripts/literature-retrieve.sh`
- [ ] Check if `literature-search.sh` exists in nvim and copy to BL and cslib if present (required for Tier 1 activation)
- [ ] Check if `literature-schema.sql` and `literature-build-index.sh` need to be present in BL/cslib for the retrieve script to reference them (inspect retrieve.sh for script-relative paths)
- [ ] Test Tier 2 fallback from each project root: `bash .claude/scripts/literature-retrieve.sh "test query" "general" 2>/dev/null | head -20` (should produce `<literature-context>` output without a DB)

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `/home/benjamin/Projects/BimodalLogic/.claude/scripts/literature-retrieve.sh` - Replace with nvim version
- `/home/benjamin/Projects/cslib/.claude/scripts/literature-retrieve.sh` - Replace with nvim version
- `/home/benjamin/Projects/BimodalLogic/.claude/scripts/literature-search.sh` - Copy from nvim (if exists)
- `/home/benjamin/Projects/cslib/.claude/scripts/literature-search.sh` - Copy from nvim (if exists)

**Verification**:
- `wc -l` on all three `literature-retrieve.sh` files shows identical line counts
- Tier 2 output produced from BL and cslib project roots (no DB, falls back to keyword injection)

---

### Phase 3: Build FTS5 Database [COMPLETED]

**Goal**: Generate `chunks.json` manifests from the existing Literature markdown files and build the FTS5 `.literature.db` database.

**Tasks**:
- [ ] Inventory the chunking pipeline: check if `literature-chunk.sh` or `literature-ingest.sh` can process existing `.md` files (not just PDFs)
- [ ] If the chunking scripts only handle PDF/DJVU input, write a minimal adapter that generates `chunks.json` from existing flat `.md` files in `~/Projects/Literature/` using the schema from `literature-schema.sql`
- [ ] Run the chunking process on the Literature directory to produce `chunks.json` manifests
- [ ] Run `bash /home/benjamin/.config/nvim/.claude/scripts/literature-build-index.sh --global` to build `~/Projects/Literature/.literature.db`
- [ ] Verify database was created: `ls -la ~/Projects/Literature/.literature.db`
- [ ] Verify database has content: `sqlite3 ~/Projects/Literature/.literature.db "SELECT COUNT(*) FROM chunks_data;"`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/Projects/Literature/` - chunks.json manifests generated within subdirectories
- `~/Projects/Literature/.literature.db` - FTS5 database created

**Verification**:
- `.literature.db` file exists and has non-zero size
- `chunks_data` table has rows
- `chunks_fts` table is queryable: `sqlite3 ~/Projects/Literature/.literature.db "SELECT chunk_id FROM chunks_fts WHERE chunks_fts MATCH 'modal logic' LIMIT 5;"`

---

### Phase 4: End-to-End Validation [COMPLETED]

**Goal**: Verify the `--lit` flag activates Tier 1 FTS5 search from all three project roots and that the full pipeline works.

**Tasks**:
- [ ] From nvim root: run `bash .claude/scripts/literature-retrieve.sh "completeness theorem" "general"` and confirm Tier 1 output (`<literature-tool>` block, not `<literature-context>`)
- [ ] From BimodalLogic root: run `bash .claude/scripts/literature-retrieve.sh "modal logic" "general"` and confirm Tier 1 output
- [ ] From cslib root: run `bash .claude/scripts/literature-retrieve.sh "forcing" "general"` and confirm Tier 1 output
- [ ] If any project fails Tier 1, diagnose: check LITERATURE_DIR resolution, .literature.db path lookup, literature-search.sh availability
- [ ] Run `bash /home/benjamin/.config/nvim/.claude/scripts/literature-audit.sh` to validate cross-reference extraction quality
- [ ] Verify Tier 2 fallback still works by temporarily renaming the .literature.db and re-running retrieve from one project root

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (validation only)

**Verification**:
- All three projects produce `<literature-tool>` output (Tier 1 active)
- Tier 2 fallback still works when DB is absent
- literature-audit.sh runs without errors

## Testing & Validation

- [ ] LITERATURE_DIR resolves correctly in Claude Code sessions from all three project roots
- [ ] nvim's .claude/settings.json no longer contains LITERATURE_DIR
- [ ] literature-retrieve.sh is identical (or functionally equivalent) across all three projects
- [ ] .literature.db exists at ~/Projects/Literature/.literature.db with queryable FTS5 content
- [ ] Tier 1 search produces results for test queries from all three roots
- [ ] Tier 2 keyword injection still works as fallback when DB is absent

## Artifacts & Outputs

- plans/01_infrastructure-wiring-plan.md (this file)
- summaries/01_infrastructure-wiring-summary.md (after implementation)

## Rollback/Contingency

- **Global settings**: Revert `~/.dotfiles/config/claude/settings.json` to remove LITERATURE_DIR, restore it to nvim's project settings.json, run `home-manager switch`
- **Script sync**: BimodalLogic and cslib versions are in git; `git checkout .claude/scripts/literature-retrieve.sh` in each project
- **FTS5 database**: Delete `~/Projects/Literature/.literature.db` to revert to Tier 2 fallback; remove any generated `chunks.json` manifests
