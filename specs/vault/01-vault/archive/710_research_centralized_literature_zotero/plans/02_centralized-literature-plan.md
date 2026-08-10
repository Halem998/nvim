# Implementation Plan: Task #710

- **Task**: 710 - research_centralized_literature_zotero
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md, reports/02_sqlite-vs-json-research.md
- **Artifacts**: plans/02_centralized-literature-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Centralize literature management from per-repo `specs/literature/` directories into a shared `~/Projects/Literature/` repository with Zotero.bib integration via CSL-JSON export. The implementation adds a `LITERATURE_DIR` environment variable override to `literature-retrieve.sh` and `skill-literature/SKILL.md`, creates the centralized repo structure with a v2 `index.json` schema (adding `zotero_key`, `zotero_path`, `project_tags` fields), migrates ~113 existing entries from BimodalLogic (cslib's `specs/literature/` no longer exists on disk), and deploys updated scripts to all projects. The two-tier fallback (centralized first, per-project second) preserves backward compatibility throughout the transition.

### Research Integration

Two research reports inform this plan:

1. **01_team-research.md** (4-teammate synthesis): Established the architecture -- `LITERATURE_DIR` env var with two-tier fallback, CSL-JSON over BibTeX parsing, symlinks for PDFs, JSON over SQLite for the index, v2 schema with `zotero_key`/`zotero_path`/`project_tags` fields. Identified 6 gaps (concurrency, script deployment, multi-file Zotero entries, null bib_key papers, scan mode adaptation, ROADMAP placement) and resolved 7 cross-teammate conflicts.

2. **02_sqlite-vs-json-research.md**: Confirmed JSON is correct for the current ~200-entry scale. SQLite deferred to ~500+ entries threshold. Recommended Option A (JSON primary, ephemeral SQLite cache on demand) as the future upgrade path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

The ROADMAP.md does not currently include a literature centralization item. The research recommends adding an entry under Phase 2: Medium-Term Improvements. This plan includes a ROADMAP update as its final phase.

## Goals & Non-Goals

**Goals**:
- Add `LITERATURE_DIR` environment variable support to `literature-retrieve.sh` with two-tier fallback
- Update `skill-literature/SKILL.md` to respect `LITERATURE_DIR` for all operations
- Create `~/Projects/Literature/` repo structure with v2 `index.json` schema
- Configure CSL-JSON auto-export from Better BibTeX to `~/Projects/Literature/zotero-library.json`
- Migrate BimodalLogic's 113 entries into the centralized index with v1-to-v2 schema backfill
- Set `LITERATURE_DIR` in `.claude/settings.json` env block and `~/.dotfiles/home.nix` sessionVariables
- Deploy updated scripts to BimodalLogic (and cslib if applicable)
- Update ROADMAP.md with literature centralization entry

**Non-Goals**:
- SQLite index implementation (deferred to 500+ entry threshold)
- Zotero MCP server integration (12-18 month horizon)
- Memory seed emission from `/literature --index` (Phase 2+ enhancement)
- Annotation integration from Better Notes (Phase 2+ enhancement)
- RAG/embedding search (deferred to 500+ entries or keyword precision degradation)
- Concurrency locking for shared `index.json` (low risk at current single-user scale)
- `/literature --import-from-zotero KEY` command (Phase 2 enhancement)
- Migrating cslib content (cslib's `specs/literature/` no longer exists on disk)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--lit` breaks during migration if per-project dirs are removed before central repo is verified | H | M | Two-tier fallback: central checked first, per-project preserved as read-only fallback throughout |
| bib_key divergence between BimodalLogic and Zotero canonical keys | M | H | Introduce `zotero_key` field alongside existing `bib_key`; migration script maps known divergences |
| Better BibTeX CSL-JSON auto-export stops working after Zotero update | M | L | `zotero-library.json` is a convenience, not a hard dependency; manual re-export is the fallback |
| Updated `literature-retrieve.sh` not propagated to BimodalLogic after env var change | H | M | Explicit re-deployment step in Phase 5; verify `--lit` injection from BimodalLogic post-deploy |
| Home Manager sessionVariables change requires `home-manager switch` to take effect | L | H | Document in Phase 4; `settings.json` env block provides immediate coverage for Claude Code sessions |
| Chunking incompatibility for 3 overlapping papers between repos | M | L | Only BimodalLogic has content on disk; adopt its chunking as canonical; no reconciliation needed since cslib's literature dir is gone |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: LITERATURE_DIR Environment Variable in Scripts [COMPLETED]

**Goal**: Add `LITERATURE_DIR` override to `literature-retrieve.sh` and `skill-literature/SKILL.md` with two-tier fallback logic.

**Tasks**:
- [ ] Edit `literature-retrieve.sh` lines 29-32: rename `LIT_DIR` to `DEFAULT_LIT_DIR`, add `LIT_DIR="${LITERATURE_DIR:-$DEFAULT_LIT_DIR}"` with existence check
- [ ] Add directory-existence validation: if `LITERATURE_DIR` is set but does not exist, fall back to per-project `specs/literature`
- [ ] Edit `skill-literature/SKILL.md` Step 2: change `lit_dir="specs/literature"` to `lit_dir="${LITERATURE_DIR:-specs/literature}"` with existence check
- [ ] Ensure both scripts handle the case where neither directory exists (current silent exit behavior preserved)
- [ ] Test locally: set `LITERATURE_DIR=/tmp/test-lit` and verify `literature-retrieve.sh` reads from it; unset and verify fallback to `specs/literature`

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-retrieve.sh` - Add LITERATURE_DIR override (lines 29-32)
- `.claude/skills/skill-literature/SKILL.md` - Add LITERATURE_DIR override (Step 2)

**Verification**:
- `LITERATURE_DIR=/tmp/test-lit literature-retrieve.sh "test" "general"` uses the override directory
- Unsetting `LITERATURE_DIR` falls back to `$PROJECT_ROOT/specs/literature`
- Setting `LITERATURE_DIR` to a nonexistent path falls back to per-project dir

---

### Phase 2: Central Repository Structure and Schema [COMPLETED]

**Goal**: Create `~/Projects/Literature/` directory layout with v2 `index.json` schema and supporting files.

**Tasks**:
- [ ] Create `~/Projects/Literature/index.json` with v2 schema skeleton: `version: 2`, `token_budget: 8000`, `max_chunks: 10`, empty `entries` array, description field
- [ ] Create `~/Projects/Literature/pdfs/` directory
- [ ] Create `~/Projects/Literature/.gitignore` with `*.pdf` and `pdfs/` entries
- [ ] Update `~/Projects/Literature/README.md` with architecture description: two-tier design, schema documentation, usage instructions, SQLite deferral rationale
- [ ] Configure Better BibTeX to auto-export CSL-JSON to `~/Projects/Literature/zotero-library.json` (manual Zotero configuration step -- document the procedure)
- [ ] Commit initial structure to the Literature repo

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `~/Projects/Literature/index.json` - Create with v2 schema
- `~/Projects/Literature/pdfs/` - Create directory
- `~/Projects/Literature/.gitignore` - Create with pdf exclusions
- `~/Projects/Literature/README.md` - Write architecture documentation

**Verification**:
- `jq '.version' ~/Projects/Literature/index.json` returns `2`
- `jq '.entries | length' ~/Projects/Literature/index.json` returns `0`
- `.gitignore` excludes `pdfs/` and `*.pdf`
- README documents the two-tier architecture, env var, and schema

---

### Phase 3: Schema Migration Script and Content Migration [COMPLETED]

**Goal**: Migrate BimodalLogic's 113 literature entries into the centralized repo with v1-to-v2 schema backfill.

**Tasks**:
- [ ] Write migration script (`~/Projects/Literature/scripts/migrate-from-repo.sh`) that:
  - Reads source `index.json` from a specified repo path
  - Backfills `doc_type` for each entry: entries with non-null `parent_doc` get `"section"` or `"chapter"`; flat entries get `"paper"` or `"book"` (heuristic from existing metadata)
  - Backfills `source_format`: default `"pdf"` for all entries (research confirmed ~95% correct)
  - Adds `zotero_key` field: defaults to `bib_key` value; known divergences (e.g., `Burgess1982II` -> `Burgess1982a`) mapped explicitly
  - Adds `zotero_path` field: look up `bib_key` in `zotero-library.json` (if available) to populate; null for entries not in Zotero
  - Adds `project_tags` field: `["BimodalLogic"]` for BimodalLogic entries
  - Preserves all existing fields (`id`, `bib_key`, `title`, `authors`, `year`, `section`, `path`, `page_range`, `token_count`, `keywords`, `summary`, `parent_doc`)
- [ ] Copy markdown content files from `~/Projects/BimodalLogic/specs/literature/` to `~/Projects/Literature/` (preserving subdirectory structure for chunked works)
- [ ] Run migration script against BimodalLogic: `./scripts/migrate-from-repo.sh ~/Projects/BimodalLogic`
- [ ] Validate migrated index: `jq '.entries | length' ~/Projects/Literature/index.json` should return 113
- [ ] Spot-check 3-5 entries for correct `doc_type`, `source_format`, `zotero_key` values
- [ ] Create symlinks in `~/Projects/Literature/pdfs/` for entries with Zotero PDFs (using `zotero_path` values from the CSL-JSON or Zotero.bib `file` field)
- [ ] Commit migrated content to the Literature repo

**Timing**: 1.5 hours

**Depends on**: Phase 1 (script changes must be ready before testing end-to-end)

**Files to modify**:
- `~/Projects/Literature/scripts/migrate-from-repo.sh` - Create migration script
- `~/Projects/Literature/index.json` - Populated with migrated entries
- `~/Projects/Literature/` - Content markdown files copied from BimodalLogic
- `~/Projects/Literature/pdfs/` - Symlinks to Zotero storage

**Verification**:
- `jq '.entries | length' ~/Projects/Literature/index.json` returns 113
- `jq '[.entries[] | select(.doc_type == null)] | length' ~/Projects/Literature/index.json` returns 0 (all entries have doc_type)
- `jq '[.entries[] | select(.zotero_key == null)] | length' ~/Projects/Literature/index.json` shows only entries with `bib_key: null` (papers not in Zotero)
- Content files exist at paths referenced by index entries
- At least 5 PDF symlinks in `pdfs/` resolve to valid Zotero storage paths

---

### Phase 4: Environment Variable Configuration [COMPLETED]

**Goal**: Set `LITERATURE_DIR` in both Claude Code settings and Home Manager so all contexts see it.

**Tasks**:
- [ ] Edit `.claude/settings.json`: add `LITERATURE_DIR` to the `env` block: `"LITERATURE_DIR": "/home/benjamin/Projects/Literature"`
- [ ] Edit `~/.dotfiles/home.nix`: add `LITERATURE_DIR = "/home/benjamin/Projects/Literature";` to `home.sessionVariables` block (line ~1625 area)
- [ ] Add `LITERATURE_DIR` to `systemd.user.sessionVariables` block (line ~890 area) if not automatically propagated
- [ ] Run `home-manager switch` to apply the session variable changes (or document as a manual step)
- [ ] Verify: in a new Claude Code session, `echo $LITERATURE_DIR` returns the expected path

**Timing**: 30 minutes

**Depends on**: Phase 2 (central repo must exist before pointing env var at it), Phase 3 (content must be migrated before enabling the override)

**Files to modify**:
- `.claude/settings.json` - Add LITERATURE_DIR to env block
- `~/.dotfiles/home.nix` - Add LITERATURE_DIR to sessionVariables

**Verification**:
- `jq '.env.LITERATURE_DIR' .claude/settings.json` returns `"/home/benjamin/Projects/Literature"`
- `grep LITERATURE_DIR ~/.dotfiles/home.nix` shows the variable declaration
- After `home-manager switch`: `echo $LITERATURE_DIR` in a new shell returns the path

---

### Phase 5: Script Deployment and End-to-End Verification [COMPLETED]

**Goal**: Deploy updated `literature-retrieve.sh` to BimodalLogic and verify `--lit` injection works from the centralized repo.

**Tasks**:
- [ ] Identify how `literature-retrieve.sh` is distributed to BimodalLogic (check if it is a copy in BimodalLogic's `.claude/scripts/` or loaded from `~/.config/nvim/.claude/scripts/`)
- [ ] If it is a copy: run the extension install mechanism to update BimodalLogic's copy of the script
- [ ] If it is loaded from the shared location: no deployment needed (the Phase 1 edit propagates automatically)
- [ ] Test `--lit` from BimodalLogic: run a test invocation of `literature-retrieve.sh` with `LITERATURE_DIR` set, verify it returns content from `~/Projects/Literature/`
- [ ] Test `--lit` fallback: temporarily unset `LITERATURE_DIR`, verify BimodalLogic falls back to its local `specs/literature/` (which still contains the original files)
- [ ] Test `/literature --validate` from the nvim project with `LITERATURE_DIR` set -- verify it validates the central index
- [ ] Test `/literature --scan` behavior with the centralized directory
- [ ] Mark per-project `specs/literature/` in BimodalLogic as deprecated: add a note to its README or create a `DEPRECATED.md` file

**Timing**: 1 hour

**Depends on**: Phase 4

**Files to modify**:
- BimodalLogic `.claude/scripts/literature-retrieve.sh` - Update if it is a separate copy
- BimodalLogic `specs/literature/DEPRECATED.md` - Create deprecation notice

**Verification**:
- `LITERATURE_DIR=~/Projects/Literature bash .claude/scripts/literature-retrieve.sh "modal logic completeness" "general"` returns content from the central repo
- Without `LITERATURE_DIR`, same command returns content from per-project `specs/literature/`
- `/literature --validate` reports no errors against the central index
- BimodalLogic `specs/literature/DEPRECATED.md` exists with migration notice

---

### Phase 6: Documentation and ROADMAP Update [COMPLETED]

**Goal**: Update documentation to reflect centralized architecture and add ROADMAP entry.

**Tasks**:
- [ ] Update `specs/ROADMAP.md`: add "Literature centralization" entry under Phase 2: Medium-Term Improvements
- [ ] Update `.claude/CLAUDE.md` Literature Mode section: document `LITERATURE_DIR` override behavior, two-tier fallback, and central repo location (this will be auto-regenerated from extension merge sources, so update the literature extension's `EXTENSION.md`)
- [ ] Update literature extension `EXTENSION.md` to document the centralized architecture and `LITERATURE_DIR` usage
- [ ] Document the SQLite deferral decision in `~/Projects/Literature/README.md` (already done in Phase 2, verify it covers the rationale from research report 02)
- [ ] Update `literature-retrieve.sh` header comment to document the `LITERATURE_DIR` override

**Timing**: 45 minutes

**Depends on**: Phase 5

**Files to modify**:
- `specs/ROADMAP.md` - Add literature centralization entry
- `.claude/extensions/literature/EXTENSION.md` - Document LITERATURE_DIR and centralized architecture
- `.claude/scripts/literature-retrieve.sh` - Update header comment
- `~/Projects/Literature/README.md` - Verify SQLite deferral documentation

**Verification**:
- `grep -i "literature" specs/ROADMAP.md` shows the new entry
- Literature extension EXTENSION.md mentions `LITERATURE_DIR` and two-tier fallback
- `literature-retrieve.sh` header comment documents the `LITERATURE_DIR` override

## Testing & Validation

- [ ] `LITERATURE_DIR` override works in `literature-retrieve.sh` (set, unset, nonexistent path)
- [ ] `skill-literature/SKILL.md` respects `LITERATURE_DIR` for all modes (status, scan, validate, index)
- [ ] Central `index.json` passes schema validation (version 2, all entries have required fields)
- [ ] All 113 migrated entries have non-null `doc_type` and `source_format`
- [ ] Content files referenced by `index.json` entries exist at the specified paths
- [ ] PDF symlinks in `pdfs/` resolve to valid Zotero storage paths
- [ ] `--lit` injection from BimodalLogic returns content from central repo when `LITERATURE_DIR` is set
- [ ] `--lit` falls back to per-project `specs/literature/` when `LITERATURE_DIR` is unset
- [ ] `/literature --validate` reports clean against the central index
- [ ] `settings.json` env block includes `LITERATURE_DIR`
- [ ] `home.nix` sessionVariables includes `LITERATURE_DIR`

## Artifacts & Outputs

- `plans/02_centralized-literature-plan.md` (this file)
- `.claude/scripts/literature-retrieve.sh` (modified)
- `.claude/skills/skill-literature/SKILL.md` (modified)
- `.claude/settings.json` (modified)
- `.claude/extensions/literature/EXTENSION.md` (modified)
- `~/Projects/Literature/index.json` (created)
- `~/Projects/Literature/README.md` (updated)
- `~/Projects/Literature/.gitignore` (created)
- `~/Projects/Literature/scripts/migrate-from-repo.sh` (created)
- `specs/ROADMAP.md` (updated)
- `~/.dotfiles/home.nix` (modified)

## Rollback/Contingency

1. **If `LITERATURE_DIR` breaks `--lit` injection**: Unset the env var from `.claude/settings.json` and `home.nix`; all scripts fall back to per-project `specs/literature/` immediately.
2. **If migration corrupts the central index**: The BimodalLogic `specs/literature/` directory remains intact as the authoritative source; re-run the migration script after fixing the issue.
3. **If Better BibTeX CSL-JSON export fails**: The central repo works without `zotero-library.json`; the `zotero_path` and `zotero_key` fields can be populated manually or from direct `Zotero.bib` parsing as a fallback.
4. **Full rollback**: Revert the 2-line changes to `literature-retrieve.sh` and `skill-literature/SKILL.md`; remove `LITERATURE_DIR` from `settings.json` and `home.nix`. The system returns to per-project-only behavior with zero data loss.
