# Research Report: Task #733

**Task**: 733 - Wire LITERATURE_DIR Globally, Build FTS5 Database, Validate Collection
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T00:30:00Z
**Effort**: ~1 hour
**Dependencies**: Task 728 (Zotero storage), Task 731 (cslib migration), Task 732 (schema unification)
**Sources/Inputs**: Codebase (all three project roots), literature scripts, dotfiles/home.nix
**Artifacts**: specs/733_literature_infrastructure_wiring/reports/01_infrastructure-wiring-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- LITERATURE_DIR is currently defined only in nvim's `.claude/settings.json` — it is missing from the global `~/.dotfiles/config/claude/settings.json`, but IS present as a shell session variable in `home.nix` (both `home.sessionVariables` and `systemd.user.sessionVariables`).
- The FTS5 database (`.literature.db`) does not exist anywhere; building it requires `chunks.json` manifests that do not yet exist — the Literature directory uses flat `.md` files, not the ingested chunk format.
- `literature-retrieve.sh` in nvim has Tier 1 (FTS5) logic; BimodalLogic and cslib use older Tier 2-only versions (234 and 205 lines vs. 301 lines) — so even if a DB were built, only nvim would activate Tier 1.
- Recommended approach: (1) add LITERATURE_DIR to `~/.dotfiles/config/claude/settings.json` env block; (2) run `home-manager switch`; (3) run `literature-ingest.sh` on Zotero PDFs to produce `chunks.json` manifests; (4) then build with `literature-build-index.sh --global`; (5) deploy updated `literature-retrieve.sh` to BL and cslib.

---

## Context & Scope

This research covers the complete state of the `LITERATURE_DIR` configuration, the FTS5 database pipeline, and the `--lit` flag across the three primary project roots: nvim (`~/.config/nvim`), BimodalLogic (`~/Projects/BimodalLogic`), and cslib (`~/Projects/cslib`).

---

## Findings

### 1. Current LITERATURE_DIR Configuration

| Location | LITERATURE_DIR Present | Value |
|----------|----------------------|-------|
| `~/.config/nvim/.claude/settings.json` (env block) | YES | `/home/benjamin/Projects/Literature` |
| `~/.dotfiles/config/claude/settings.json` (env block) | **NO** | (absent) |
| `~/.dotfiles/home.nix` → `home.sessionVariables` | YES | `/home/benjamin/Projects/Literature` |
| `~/.dotfiles/home.nix` → `systemd.user.sessionVariables` | YES | `/home/benjamin/Projects/Literature` |
| `~/Projects/BimodalLogic/.claude/settings.json` (env block) | NO | (has only `SLASH_COMMAND_TOOL_CHAR_BUDGET`) |
| `~/Projects/cslib/.claude/settings.json` (env block) | NO | (has only `SLASH_COMMAND_TOOL_CHAR_BUDGET`) |

**Key finding**: LITERATURE_DIR is exported as a shell session variable via Home Manager (for interactive shells and systemd services), but NOT as a Claude Code environment variable via the global `~/.dotfiles/config/claude/settings.json`. Claude Code's `env` block in settings.json is independent of shell environment variables — Claude Code reads its own settings.json env block at startup. So LITERATURE_DIR is only picked up in Claude Code when running from the nvim project (via its project-level settings.json), NOT from BimodalLogic or cslib sessions.

### 2. ~/.dotfiles/config/claude/ Structure and Home Manager Integration

```
~/.dotfiles/config/claude/
├── settings.json    # Global Claude Code settings (managed by Home Manager)
└── keybindings.json # Global keybindings
```

**Home Manager deployment** (home.nix lines 716-723):
```nix
home.activation.claudeSettings = config.lib.dag.entryAfter ["writeBoundary"] ''
  mkdir -p /home/benjamin/.claude
  rm -f /home/benjamin/.claude/settings.json
  cp ${./config/claude/settings.json} /home/benjamin/.claude/settings.json
  chmod u+w /home/benjamin/.claude/settings.json
  rm -f /home/benjamin/.claude/keybindings.json
  cp ${./config/claude/keybindings.json} /home/benjamin/.claude/keybindings.json
  chmod u+w /home/benjamin/.claude/keybindings.json
'';
```

Files are copied (not symlinked) so Claude Code can write runtime changes. The source is `~/.dotfiles/config/claude/settings.json`. After editing this file, `home-manager switch` redeploys it to `~/.claude/settings.json`.

**Current global settings.json env block** (missing LITERATURE_DIR):
```json
{
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-6[1m]",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "1",
    "CLAUDE_CODE_FORK_SUBAGENT": "1"
  }
}
```

**Required addition**:
```json
"LITERATURE_DIR": "/home/benjamin/Projects/Literature"
```

### 3. literature-build-index.sh Analysis

**Location**: `/home/benjamin/.config/nvim/.claude/scripts/literature-build-index.sh` (nvim only; does not exist in BL or cslib)

**What it does**:
1. Requires `sqlite3` (available: version 3.51.2) and FTS5 (confirmed working via test)
2. Accepts `--global`, `--local`, or `--dir <path>` to select target directories
3. Finds all `chunks.json` manifests in target directory
4. Reads schema from `literature-schema.sql` (same directory)
5. Initializes SQLite database with schema (chunks_data, chunks_fts, chunk_relations, document_metadata)
6. Runs Python3 script to insert chunks into `chunks_data`, then rebuilds FTS5 index
7. Resolves cross-references and inserts chunk_relations
8. Performs atomic rename (`.literature.db.tmp` → `.literature.db`)

**FTS5 Schema** (`literature-schema.sql`):
- `chunks_data`: Regular table storing all chunk metadata (chunk_id, doc_id, section_path, title, keywords, summary, token_count, source_path, cross_refs, prev/next_chunk_id)
- `chunks_fts`: FTS5 virtual table (content='chunks_data') with BM25 weights: title=10, keywords=5, summary=3, content=1
- `chunk_relations`: Graph table for cross-ref and parent/child navigation
- `document_metadata`: Per-document metadata

**Critical prerequisite**: The script requires `chunks.json` manifests created by `literature-ingest.sh`. The Literature directory currently has ZERO `chunks.json` files — it contains 183 flat markdown files in the root and chapter subdirectories. Running `literature-build-index.sh --global` today would find no manifests and exit without building anything (not an error, just a no-op with warning).

**Pipeline to enable FTS5**:
1. Run `literature-ingest.sh` on each source PDF/DJVU (or the Zotero storage path)
2. `literature-ingest.sh` → `literature-convert.sh` → `literature-chunk.sh` → creates `chunks.json`
3. `literature-ingest.sh` calls `literature-build-index.sh --global` automatically after each ingest
4. 870 PDFs available in `~/Documents/Zotero/storage/` (no PDFs in Literature directory itself)

### 4. literature-audit.sh Analysis

**Location**: `/home/benjamin/.config/nvim/.claude/scripts/literature-audit.sh`

**What it does** (two audits):

**Audit 1 — Conversion Quality**:
- Tests PDF/DJVU → markdown conversion using available tools
- Tool selection: marker_single (preferred) → PyMuPDF hybrid → pdftotext
- Checks heading count, word count, math block count in output
- Default search paths: BimodalLogic/specs/literature, Literature/pdfs, Zotero/storage
- Audit 1 results from 2026-06-15: pdftotext + PyMuPDF selected; marker not installed

**Audit 2 — Cross-Reference Extraction**:
- Tests regex patterns against existing markdown files
- Patterns: standard theorem labels (Definition/Lemma/Theorem/Proposition/Corollary/Remark/Example + digit), single-letter labels, Axiom labels
- 2026-06-15 results: 90% recall, 90% precision — PASS
- Does NOT audit index integrity; does NOT validate Literature collection

**Important gap**: `literature-audit.sh` is a pre-implementation audit for the conversion pipeline, NOT an index integrity validator. There is no `--validate` equivalent for the Literature collection itself. The task description's "validate collection" likely refers to running `/literature --validate` (the literature skill) or verifying entries match files.

### 5. --lit Flag Pipeline Trace

**Entry point**: Each skill (skill-researcher, skill-planner, skill-implementer) in all three projects contains:
```bash
lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
```

**literature-retrieve.sh — nvim version** (301 lines, has Tier 1):
```
IF .literature.db EXISTS (local or global) AND literature-search.sh is executable:
  → TIER 1: Emit <literature-tool> block instructing agent to use literature-search.sh
  → Agent does on-demand FTS5 queries via literature-search.sh
  → NO pre-injection of content

ELSE:
  → TIER 2 (keyword injection):
    IF index.json exists AND description non-empty:
      Score entries by keyword overlap, greedy-select within TOKEN_BUDGET=8000
    ELSE:
      Scan all .md/.txt files, inject within budget
    Output: <literature-context> block with file content
```

**Check for Tier 1 activation** (from nvim's literature-retrieve.sh lines 41-86):
```bash
LOCAL_DB="$GIT_ROOT/specs/literature/.literature.db"
GLOBAL_DB="$GLOBAL_LIT_DIR/.literature.db"   # $GLOBAL_LIT_DIR = $LITERATURE_DIR or ~/Projects/Literature

if { [ -f "$LOCAL_DB" ] || [ -f "$GLOBAL_DB" ]; } && [ -x "$SEARCH_SCRIPT" ]; then
  # Tier 1
fi
```

**Current state — ALL projects use Tier 2**:
- `~/Projects/Literature/.literature.db`: DOES NOT EXIST
- `BimodalLogic/specs/literature/.literature.db`: DOES NOT EXIST
- `cslib/specs/literature/.literature.db`: DOES NOT EXIST

**Version mismatch across projects**:
| Project | literature-retrieve.sh lines | Tier 1 support |
|---------|------------------------------|---------------|
| nvim | 301 | YES |
| BimodalLogic | 234 | NO (older version) |
| cslib | 205 | NO (older version, no LITERATURE_DIR support) |

The cslib version doesn't even handle LITERATURE_DIR at all — it uses a hardcoded `$PROJECT_ROOT/specs/literature` path. BimodalLogic does handle LITERATURE_DIR (lines 13-17 show the two-tier fallback), but lacks Tier 1 FTS5 logic.

### 6. FTS5/sqlite3 Availability

- `sqlite3 3.51.2` (2026-01-09) — AVAILABLE
- FTS5 confirmed working via test: `CREATE VIRTUAL TABLE t USING fts5(x)` succeeds
- `python3` — AVAILABLE (required by build-index Python block)
- `pdftotext` — AVAILABLE (poppler)
- `PyMuPDF (fitz)` — AVAILABLE (per audit results from 2026-06-15)

### 7. Three Project Roots Status

| Project | Settings.json LITERATURE_DIR | literature-retrieve.sh LITERATURE_DIR | literature-retrieve.sh Tier 1 | .literature.db |
|---------|------------------------------|---------------------------------------|-------------------------------|----------------|
| nvim | YES | YES (reads from env) | YES (Tier 1 code present) | NOT BUILT |
| BimodalLogic | NO | YES (two-tier fallback) | NO (older script) | NOT BUILT |
| cslib | NO | NO (hardcoded local path) | NO (older script) | NOT BUILT |

---

## Decisions

- LITERATURE_DIR belongs in `~/.dotfiles/config/claude/settings.json` env block (not per-project settings.json) since it is a global resource.
- BimodalLogic and cslib should NOT keep per-project LITERATURE_DIR overrides — the global setting should be the single source.
- FTS5 database build requires running `literature-ingest.sh` on Zotero PDFs first; this is a precondition for task 733's "activate Tier 1" goal.
- The cslib `literature-retrieve.sh` needs updating to match nvim's version (both for LITERATURE_DIR support and Tier 1 logic); same for BimodalLogic.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| literature-ingest.sh on 870 Zotero PDFs is slow | Run selectively on most-referenced PDFs first; can build partial DB |
| FTS5 build requires chunks.json that don't exist yet | Must run ingest pipeline before build-index; task 733 may need to be split or scoped |
| Updating literature-retrieve.sh in BL and cslib could break Tier 2 | The nvim version is a superset — backward compatible; test with no DB present |
| home-manager switch required after dotfiles edit | Standard procedure; no gotchas identified |
| `literature-audit.sh` doesn't validate index integrity | Use `/literature --validate` skill command instead for collection validation |

---

## Implementation Approach

### Phase 1: Wire LITERATURE_DIR globally (low risk, immediate)
1. Edit `~/.dotfiles/config/claude/settings.json` — add `"LITERATURE_DIR": "/home/benjamin/Projects/Literature"` to `env` block
2. Run `home-manager switch` to deploy to `~/.claude/settings.json`
3. Verify: start Claude Code in BimodalLogic and cslib — check `$LITERATURE_DIR` resolves

### Phase 2: Update literature-retrieve.sh in BL and cslib (medium risk)
1. Copy nvim's `literature-retrieve.sh` to BimodalLogic and cslib `.claude/scripts/`
2. The nvim version is backward compatible: when no DB exists, falls through to Tier 2 keyword injection with LITERATURE_DIR support
3. Test: run `bash .claude/scripts/literature-retrieve.sh "modal logic completeness"` from each project root — should get Tier 2 output using global Literature collection

### Phase 3: Build FTS5 database (depends on ingest pipeline)
1. Run `literature-ingest.sh` on key Zotero PDFs (or the existing Literature flat .md files need to be converted to chunks format — this may be what task 732 schema unification covers)
2. Once chunks.json exist, run `bash .claude/scripts/literature-build-index.sh --global`
3. Verify: `ls -la ~/Projects/Literature/.literature.db`

**Note**: If task 732's schema unification produces v2 index entries with chunked structure, Phase 3 may become trivial. Coordinate with task 732 before running ingest on all 870 Zotero PDFs.

### Phase 4: Validate collection with audit
1. Run `bash .claude/scripts/literature-audit.sh --all` for pipeline validation
2. Run `/literature --validate` from each project root to check index integrity
3. Test `--lit` flag end-to-end: `/research <task> --lit` from nvim, BL, and cslib

---

## Context Extension Recommendations

- **Topic**: LITERATURE_DIR env priority in Claude Code vs shell environment
- **Gap**: No documentation exists explaining that `settings.json` env block is independent from shell sessionVariables — developers may assume Home Manager `home.sessionVariables` is sufficient.
- **Recommendation**: Add note to `.claude/context/guides/literature-setup.md` (or similar) documenting that LITERATURE_DIR must be set in both `home.sessionVariables` (for shell tools) and `settings.json` env block (for Claude Code agents).

---

## Appendix

### Key File Paths
- Global Claude Code settings source: `/home/benjamin/.dotfiles/config/claude/settings.json`
- Deployed global settings: `/home/benjamin/.claude/settings.json`
- nvim project settings (has LITERATURE_DIR): `/home/benjamin/.config/nvim/.claude/settings.json`
- Literature directory: `/home/benjamin/Projects/Literature/`
- Literature index: `/home/benjamin/Projects/Literature/index.json` (183 entries)
- Build index script: `/home/benjamin/.config/nvim/.claude/scripts/literature-build-index.sh`
- Audit script: `/home/benjamin/.config/nvim/.claude/scripts/literature-audit.sh`
- Schema: `/home/benjamin/.config/nvim/.claude/scripts/literature-schema.sql`
- nvim literature-retrieve.sh (Tier 1+2): `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh`
- BL literature-retrieve.sh (Tier 2 only): `/home/benjamin/Projects/BimodalLogic/.claude/scripts/literature-retrieve.sh`
- cslib literature-retrieve.sh (Tier 2 only, no LITERATURE_DIR): `/home/benjamin/Projects/cslib/.claude/scripts/literature-retrieve.sh`

### Zotero Storage
- Path: `/home/benjamin/Documents/Zotero/storage/`
- PDF count: 870 PDFs available

### SQLite/FTS5 Status
- sqlite3 version: 3.51.2 (2026-01-09)
- FTS5: confirmed working
- Python3: available
- pdftotext: available (poppler)
- PyMuPDF (fitz): available
