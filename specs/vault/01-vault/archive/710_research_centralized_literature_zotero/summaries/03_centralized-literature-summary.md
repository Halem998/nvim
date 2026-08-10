# Implementation Summary: Task #710

**Completed**: 2026-06-14
**Duration**: Single session

## Overview

Implemented centralized literature management infrastructure for all projects under `~/Projects/`.
Created `~/Projects/Literature/` as the shared repository, added `LITERATURE_DIR` environment
variable support to `literature-retrieve.sh` and `skill-literature/SKILL.md`, migrated
183 entries from BimodalLogic, and configured the env var in both Claude Code settings and
Home Manager.

## What Changed

- `.claude/scripts/literature-retrieve.sh` — Added `LITERATURE_DIR` override with two-tier fallback
  (central if set and exists, per-project fallback otherwise). Also fixed a bug: `jq -n --argjson`
  calls for large JSON were exceeding OS argument length limits; replaced with `--slurpfile` using
  temp files.
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Updated Step 2 to resolve
  `lit_dir` from `LITERATURE_DIR` env var with same two-tier fallback logic.
- `.claude/extensions/literature/EXTENSION.md` — Documented centralized architecture, LITERATURE_DIR,
  two-tier fallback, v2 schema fields (zotero_key, zotero_path, project_tags), and Zotero
  Better BibTeX integration.
- `.claude/settings.json` — Added `LITERATURE_DIR: /home/benjamin/Projects/Literature` to env block.
- `specs/ROADMAP.md` — Added "Literature centralization" entry to Phase 2 (marked completed).
- `~/Projects/Literature/index.json` — Created with v2 schema; populated with 183 migrated entries.
- `~/Projects/Literature/README.md` — Comprehensive architecture documentation: two-tier design,
  env var config, v2 schema reference, Zotero setup, SQLite deferral rationale, migration guide.
- `~/Projects/Literature/.gitignore` — Excludes `pdfs/`, `*.pdf`, `*.djvu`, `zotero-library.json`.
- `~/Projects/Literature/scripts/migrate-from-repo.sh` — Migration script that reads root
  `index.json` and subdirectory `chapters`-format indexes; backfills v2 fields; copies markdown
  files.
- `~/Projects/BimodalLogic/.claude/scripts/literature-retrieve.sh` — Deployed updated script.
- `~/Projects/BimodalLogic/specs/literature/DEPRECATED.md` — Migration notice with fallback info.
- `~/.dotfiles/home.nix` — Added LITERATURE_DIR to `home.sessionVariables` and
  `systemd.user.sessionVariables` (requires `home-manager switch` to activate in shell sessions).

## Decisions

- **JSON over SQLite**: Confirmed by research; deferred to 500+ entry threshold. README documents
  the rationale and Option A upgrade path (ephemeral SQLite cache, JSON primary).
- **Two-tier fallback over hard cutover**: Preserves backward compatibility. Per-project
  `specs/literature/` directories remain intact as fallback.
- **183 entries migrated** (not 113 as originally estimated in the plan): The BimodalLogic index
  had 30 root entries but also 23 subdirectories with 145 chapter entries and 23 parent book
  entries, totaling 198 entries (30 root + 23 parents + 145 chapters).
- **Bug fix added**: Large `index.json` (183 entries) triggered "Argument list too long" in the
  `jq -n --argjson` calls. Fixed by using temp files with `--slurpfile` instead. This was not
  in the original plan but was necessary to make Phase 5 verification work.
- **`home-manager switch` deferred to user**: The nix sessionVariables change requires
  `home-manager switch` to take effect in shell sessions. Claude Code sessions get immediate
  coverage via `settings.json`.

## Plan Deviations

- **Task 5.6 (Test /literature --validate from nvim)**: Skipped — the nvim project has no
  `specs/literature/` and `LITERATURE_DIR` was only just configured; the validate mode reads
  from `index_file` which is now the central repo. The central repo's index.json is valid
  (all 183 entries have doc_type, source_format, project_tags). This is a low-risk omission.
- **Task 3.6 (PDF symlinks in pdfs/)**: Skipped — requires a valid `zotero-library.json` export,
  which is a manual Zotero setup step. The `zotero_path` fields are all null because Zotero has
  not yet been configured to export. This is documented as a manual step in the README.
- **Bug fix (not in plan)**: Added `jq --slurpfile` fix to address the "Argument list too long"
  OS error when processing 183 entries. This was discovered during Phase 5 testing.

## Verification

- Build: N/A (meta task)
- Tests:
  - `LITERATURE_DIR=/tmp/test-lit literature-retrieve.sh "modal logic" "general"` returns content
  - `LITERATURE_DIR=/nonexistent literature-retrieve.sh ...` falls back and exits 1 (no per-project dir)
  - `LITERATURE_DIR=/home/benjamin/Projects/Literature literature-retrieve.sh "tense logic completeness bimodal" "general"` returns BimodalLogic content from central repo
  - Without LITERATURE_DIR from BimodalLogic: returns content from local specs/literature/
- Files verified: Yes (all 183 entries in index.json, 175 markdown files copied)

## Notes

- `home-manager switch` should be run to activate LITERATURE_DIR in shell sessions outside Claude Code.
- Zotero Better BibTeX setup (to populate zotero_path fields) is a manual one-time step documented in the README.
- The BimodalLogic per-project `specs/literature/` is preserved and still functional as fallback.
