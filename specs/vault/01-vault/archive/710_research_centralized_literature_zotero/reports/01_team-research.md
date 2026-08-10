# Research Report: Task #710

**Task**: research_centralized_literature_zotero
**Date**: 2026-06-14
**Mode**: Team Research (4 teammates)

---

## Summary

The research confirms that centralized literature management via `~/Projects/Literature/` is architecturally sound and the right long-term design, but requires real code changes — not just configuration. The core mechanism (`LITERATURE_DIR` environment variable in `literature-retrieve.sh`) does not yet exist and must be implemented. The Critic's most important finding is that the task description treated this as an existing feature when it is not: the script's path resolution is entirely hardcoded to `$SCRIPT_DIR/../..` with no override hook of any kind. This is a two-to-four line change, but it must be explicitly planned.

Three design tensions resolve cleanly with the evidence in hand. First, PDF storage should default to symlinks from `~/Projects/Literature/pdfs/{bib_key}.pdf` into Zotero's storage hierarchy for single-machine use, with a `--copy` flag for portability — not copying by default, as that doubles disk usage across 746 PDFs (~4.3GB). Second, the env var approach (`LITERATURE_DIR`) is the right long-term abstraction over symlinks-per-project, though symlinks are a valid zero-code-change bridge during transition. Third, CSL-JSON (via Better BibTeX auto-export) is strictly preferable to BibTeX parsing for Zotero integration: JSON is trivially parsed with `jq`, author arrays are pre-structured, and date fields are already typed. BibTeX parsing requires a custom awk/sed pipeline prone to breakage across Zotero versions.

The most significant complexity is not the path-resolution change but rather the data migration: 141+ existing index entries across two repos use the legacy v1 schema (no `doc_type` or `source_format`), and `bib_key` naming has diverged in incompatible ways between BimodalLogic, cslib, and Zotero itself. The plan phase must sequence this carefully — env var mechanism first, then schema definition, then migration script, then content consolidation — and must preserve per-project `specs/literature/` as a fallback during the transition window to avoid breaking active `--lit` usage.

---

## Key Findings

### 1. Zotero.bib Analysis

The file at `~/texmf/bibtex/bib/Zotero.bib` (878 entries, 693KB) is auto-maintained by Better BibTeX and is the authoritative metadata source for the user's library. Key structural facts:

- **85% PDF coverage**: 746 of 878 entries have `file` fields; 132 do not. Any integration must handle the no-PDF case gracefully.
- **Path format**: The `file` field contains absolute paths — `{/home/benjamin/Documents/Zotero/storage/XXXXXXXX/Human Readable Name.pdf}` — using opaque 8-character hash directories. Paths are hardcoded to `/home/benjamin/` and are not portable across machines.
- **Multi-file entries**: 138 entries have semicolon-separated file lists (e.g., `{path1.pdf;path2.pdf;path3.pdf}`). The first PDF-extension path is usually the primary document.
- **Key format**: Better BibTeX uses `AuthorYYYY` style (`Burgess1982`, `Abasnezhad2020`). Disambiguation suffixes are lowercase letters (`Burgess1982a`, `Burgess1982b`).
- **Entry types**: Mostly `@article` (592) and `@book` (177), with `@incollection` (92) representing book chapters — the type most likely to yield multi-file entries (chapter PDF + full book PDF).

The **strategic insight from Teammate D** is correct: Zotero.bib should be treated as a read-only metadata oracle, not a storage system. The one-way data flow (Zotero → Literature index, never the reverse) is the clean design. When `/literature --index` runs against a new paper, it should parse the `bib_key`, look up the Zotero.bib entry, and auto-populate `authors`, `year`, `title`, and `zotero_path` — dramatically reducing manual metadata burden.

**CSL-JSON is the preferred format for programmatic access** (Teammate B finding, uncontested by other teammates). Better BibTeX can auto-export to `~/Projects/Literature/zotero-library.json` in CSL-JSON on library changes. Authors are pre-structured as `[{family, given}]` arrays, dates are `[[YYYY, MM]]`, and the whole file is trivially parsed with `jq`. BibTeX parsing requires awk pipelines that are fragile across Zotero versions and encoding edge cases (LaTeX-encoded characters in filenames, Unicode).

### 2. Current Per-Repo Systems

**BimodalLogic** (`~/Projects/BimodalLogic/specs/literature/`): 113 index entries, 25 unique source works (by bib_key). Deep section-level chunking (10+ chunks per book, `_sec01`, `_sec02` naming). Schema v1 — no `doc_type` or `source_format`. `token_budget: 40000` in index.json (5x the 8000 default in `literature-retrieve.sh`).

**CSLib** (`~/Projects/cslib/specs/literature/`): 76 index entries, 10 unique source works. Mixed flat files (short papers) and subdirectories (long books). Schema includes `doc_type`, `source_format`, `parent_doc` (v2-compatible). `token_budget: 4000`. Many entries have `bib_key: null` (manually added papers not in Zotero).

**Overlap**: Only 3 `bib_key` values appear in both repos (`Burgess1984`, `GHR94`, `Reynolds1994`). The repos serve adjacent but distinct research programs and were not designed around a shared corpus. The Critic's `comm` analysis confirms this: the overlap is structural, not coincidental.

**Chunking incompatibility** (Critic finding): The 3 overlapping papers are chunked differently. BimodalLogic has `burgess_1984/` with 7 section chunks; cslib has a flat `burgess_1984.md`. These are the same source paper in incompatible granularities. A centralized store must either: (a) adopt one canonical chunking (likely the finer-grained BimodalLogic version, since coarser can be derived from finer), or (b) keep both under different IDs with a `source_project` field. See Conflicts Resolved §2 for the recommended approach.

### 3. Centralized Repo Design

`~/Projects/Literature/` already exists as a git repository (one commit, blank README). The recommended directory layout preserves the current per-repo convention (no `docs/` subdirectory wrapper) for backward compatibility with `literature-retrieve.sh` path expectations:

```
~/Projects/Literature/
├── README.md
├── index.json                    # Unified master index
├── zotero-library.json           # Auto-exported CSL-JSON from Better BibTeX
├── pdfs/
│   ├── Burgess1982.pdf -> /home/benjamin/Documents/Zotero/storage/HASH/...  (symlinks)
│   └── ...
├── burgess_1982/                 # Subdirectory per multi-chunk work
│   ├── sec01_axioms.md
│   └── sec02_28-lemma.md
├── johansson_1937.md             # Flat file for single-chunk papers
└── .gitignore                    # *.pdf, pdfs/
```

The unified `index.json` schema (v2) extends the current enriched schema with two new fields:

```json
{
  "version": 2,
  "token_budget": 8000,
  "max_chunks": 10,
  "description": "Unified literature index. Shared across projects via LITERATURE_DIR.",
  "entries": [{
    "id": "burgess_1982_sec01",
    "bib_key": "Burgess1982",
    "zotero_key": "Burgess1982",
    "title": "...",
    "authors": "John P. Burgess",
    "year": 1982,
    "section": "§1",
    "path": "burgess_1982/sec01_axioms-for-tense-logic.md",
    "page_range": "367-370",
    "token_count": 3541,
    "keywords": [...],
    "summary": "...",
    "doc_type": "section",
    "source_format": "pdf",
    "parent_doc": "burgess_1982",
    "zotero_path": "/home/benjamin/Documents/Zotero/storage/HASH/filename.pdf",
    "project_tags": ["BimodalLogic"]
  }]
}
```

**New fields**:
- `zotero_key`: The exact key in `Zotero.bib` (may differ from `bib_key` for legacy entries). Enables reliable Zotero lookup even when project-local keys diverge.
- `zotero_path`: Absolute path to the PDF in Zotero storage. Nullable for entries not in Zotero or without a PDF attachment.
- `project_tags`: Array of project slugs that have used this entry. Optional metadata for tooling; `literature-retrieve.sh` ignores unknown fields.

The `doc_type` and `source_format` fields (from the v2 enriched schema) must be backfilled for all ~141 migrated entries. Reasonable defaults for the backfill: `doc_type: "section"` for chunked entries (`parent_doc` not null), `doc_type: "paper"` or `"book"` for top-level flat files; `source_format: "pdf"` for all entries (all existing conversions are from PDF or DJVU).

### 4. Cross-Repo Path Resolution

**Current behavior** (confirmed by both Teammate A and the Critic — uncontested): `literature-retrieve.sh` derives `LIT_DIR` entirely from its own filesystem location via `SCRIPT_DIR/../..`. There is no environment variable override. The skill-literature SKILL.md similarly uses a hardcoded relative path `specs/literature`.

**The `LITERATURE_DIR` mechanism does not exist and must be created.** The implementation is minimal but mandatory:

```bash
# Current (lines 29-32 of literature-retrieve.sh):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
INDEX_FILE="$LIT_DIR/index.json"

# Proposed (add 2 lines):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_LIT_DIR="$PROJECT_ROOT/specs/literature"
LIT_DIR="${LITERATURE_DIR:-$DEFAULT_LIT_DIR}"
INDEX_FILE="$LIT_DIR/index.json"
```

The same pattern must be applied to `skill-literature/SKILL.md` which uses `lit_dir="specs/literature"` (a CWD-relative path). The proposed change:

```bash
lit_dir="${LITERATURE_DIR:-specs/literature}"
```

**Environment variable propagation** (Critic risk, confirmed): `LITERATURE_DIR` set in `~/.bashrc` will NOT propagate to Claude Code sessions launched from GUI, cron jobs, or SSH sessions without shell profile sourcing. The correct approach is to set it in TWO locations:
1. `~/.config/nvim/.claude/settings.json` (or `settings.local.json`) `env` block — ensures all Claude Code agent subprocess see it
2. Home Manager `home.sessionVariables` in `home.nix` — ensures interactive shell sessions see it

```json
// ~/.config/nvim/.claude/settings.json
{
  "env": {
    "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
  }
}
```

**Two-tier fallback** (Teammate D recommendation, adopted): The fallback chain should be:
1. `LITERATURE_DIR` if set and the directory exists
2. `$PROJECT_ROOT/specs/literature` if it exists
3. Silent exit (current behavior when neither exists)

This preserves the ability for projects to maintain project-specific literature during migration, and provides a safety net if `LITERATURE_DIR` is temporarily misconfigured.

### 5. Agent System Integration

The `--lit` flag path flows through: `parse-command-args.sh` (sets `LIT_FLAG="true"`) → skill-researcher/planner/implementer (calls `literature-retrieve.sh`) → script injects `<literature-context>` block. The `literature-retrieve.sh` change is the only script-level change needed for `--lit` to use the central repo.

The `/literature` command is a separate code path that also needs updating. Currently `skill-literature/SKILL.md` uses CWD-relative `specs/literature`. After the change, both paths use the same `LITERATURE_DIR` env var, ensuring `/literature --scan`, `/literature --convert`, `/literature --validate`, and `/literature --index` all operate on the central repo when the env var is set.

**Token budget harmonization**: BimodalLogic's index specifies `token_budget: 40000`; cslib uses `4000`; the retrieve script defaults to `8000`. The unified central index should set `token_budget: 8000`. This is a deliberate middle ground — the retrieve script's default is the right calibration for the central corpus. BimodalLogic's 40000 was set to load more context for deep proof work; individual tasks in BimodalLogic can pass a higher budget via a future flag if needed, rather than encoding it in the central index.

**Global vs. project-scoped retrieval**: When `--lit` runs in BimodalLogic, it will retrieve from the full central corpus. The keyword scoring mechanism already handles this: entries score 0 if they share no keywords with the task description and are excluded. The `MAX_FILES=10` and `token_budget: 8000` caps prevent oversaturation. Project-scoped filtering via `project_tags` is available as an opt-in future refinement but is not needed for the initial design.

**Literature extension promotion** (Teammate D): The literature extension should be documented as recommended for all research-oriented projects (BimodalLogic, cslib, nvim tasks) even if not promoted to a core dependency. This is a documentation task, not a code change.

### 6. PDF Storage Strategy

**Recommendation: Symlinks for single-machine use, copy on demand for portability.**

The evidence supports symlinks over copying as the default:
- Zotero storage paths are stable (hash directories don't change after import)
- Copying 746 PDFs at ~5MB average ≈ 4.3GB of duplication — substantial
- Symlinks require no disk duplication and auto-reflect Zotero's current state
- The `zotero_path` field in index.json provides the source for both symlink creation and on-demand copying

```
~/Projects/Literature/pdfs/
├── Burgess1982.pdf -> /home/benjamin/Documents/Zotero/storage/QYLBSWIN/Burgess - 1982 -.pdf
├── Gabbay1994.pdf -> /home/benjamin/Documents/Zotero/storage/ABC123/Gabbay et al - 1994 -.pdf
└── ...
```

Gitignore for `pdfs/` in `~/Projects/Literature/.gitignore` handles git tracking cleanly.

For multi-machine or archival use, a `--copy` flag on `/literature --import` (future enhancement) copies the PDF from `zotero_path` to `pdfs/{bib_key}.pdf` with a human-readable name. This is the same pattern Teammate A recommended for the primary strategy, but here it's the on-demand case rather than the default.

---

## Synthesis

### Conflicts Resolved

**1. PDF storage: Copy (Teammate A) vs. symlinks (Teammate B/D)**

Resolution: **Symlinks by default; copy on demand via `--copy` flag.**

Evidence: 746 PDFs at ~5MB average is ~4.3GB — doubling disk usage is the wrong default for a single-machine setup where Zotero storage is always available. Zotero's hash-named directories are stable (they don't change after import, confirmed by Teammate B's analysis of Zotero internals). Symlinks work transparently with `literature-retrieve.sh` since the script reads markdown files from the index, not PDFs directly. The `zotero_path` field gives Teammate A's desired traceability without requiring a copy. Teammate A's concern about Zotero reorganization is addressed by Zotero's stable storage model.

**2. Path resolution: 2-line change (Teammate A) vs. symlinks (Teammate B) vs. env var (Teammate B, long-term)**

Resolution: **Env var (`LITERATURE_DIR`) as the primary mechanism; symlinks as a valid transition-period bridge.**

Evidence: The Critic confirmed that the env var does not exist and must be created — this is a code change regardless of approach. The symlink approach (Teammate B Phase 1) has a real cost: git behavior with symlinks in project repos is non-trivial and projects must explicitly gitignore `specs/literature` to avoid tracking the symlink itself. The env var approach is the architecturally correct abstraction that makes centralization explicit and configurable. Teammate B's own Phase 2 recommendation also lands on the env var as the long-term solution, confirming convergence. Symlinks remain valid as a zero-code-change bridge during the transition window before the updated `literature-retrieve.sh` is distributed to all projects.

**3. BibTeX vs. CSL-JSON (Teammate B finding vs. Teammate A's BibTeX focus)**

Resolution: **CSL-JSON for programmatic Zotero integration; BibTeX for human-readable reference.**

Evidence: Teammate B's CSL-JSON finding is uncontested and technically superior for parsing. The Critic noted complicating factors in BibTeX parsing (multi-file separators, LaTeX encoding, fragility across Zotero versions). CSL-JSON from Better BibTeX auto-export provides pre-structured JSON with typed fields, parseable with `jq`. The `zotero-library.json` file should be auto-exported to `~/Projects/Literature/` and used when scripts need to look up Zotero metadata programmatically. The existing `Zotero.bib` remains the LaTeX/citation source and is not replaced. These serve different consumers.

**4. Chunk reconciliation for overlapping papers (3 shared bib_keys, different granularity)**

Resolution: **Adopt the finer-grained (BimodalLogic) chunking as canonical; index cslib's coarser version as a separate entry with a `source_project: "cslib"` tag.**

Evidence: Finer-grained chunking is a superset of coarser chunking — a caller needing the whole chapter can load all section chunks; a caller needing one section cannot derive it from a flat file. BimodalLogic's 7-chunk `burgess_1984/` is therefore strictly more useful than cslib's flat `burgess_1984.md`. The `project_tags` field (renamed from `projects` for clarity) allows both versions to coexist in the central index, with the retrieval keyword scoring naturally selecting the appropriate granularity. Over time, cslib-specific flat entries can be deprecated as the canonical chunked versions cover the same content.

**5. bib_key normalization (Critic finding: three different keys for same paper)**

Resolution: **Introduce `zotero_key` field as canonical; preserve legacy `bib_key` for backward compatibility.**

Evidence: The Critic enumerated the actual divergence:
- Burgess 1982 "Since and Until": Zotero=`Burgess1982`, BimodalLogic=`Burgess1982`, cslib=`Burgess1982I`
- Burgess 1982 "Time Periods": Zotero=`Burgess1982a`, BimodalLogic=`Burgess1982b`, cslib=`Burgess1982II`

Teammate A's proposed `zotero_key` field (alongside the existing `bib_key`) is the clean resolution. The `bib_key` field preserves project-local conventions for backward compatibility with existing index queries; `zotero_key` holds the canonical Zotero identifier used for Zotero.bib lookups. The schema proposed in Research Area 3 (Teammate A) handles this correctly:
```json
{ "bib_key": "Burgess1982II", "zotero_key": "Burgess1982a" }
```
For new entries created in the central repo, `bib_key` and `zotero_key` should be set to the same value (the Zotero canonical key). Legacy entries from cslib use the cslib convention in `bib_key` and the Zotero key in `zotero_key`.

**6. Migration risk: `--lit` breaks during migration (Critic finding)**

Resolution: **Two-phase migration with per-project fallback preserved throughout.**

Evidence: The Critic's Risk 6 (HIGH) is well-founded — if content is moved to the central repo and per-project `specs/literature/` is emptied before `LITERATURE_DIR` is confirmed working, existing BimodalLogic and cslib tasks get empty `--lit` injection. The migration sequence that avoids this:

1. Create central repo structure and `index.json` (no removal of per-project dirs)
2. Set `LITERATURE_DIR` in `settings.json` — at this point `--lit` fails over to per-project (env var points at central, but `literature-retrieve.sh` hasn't been updated yet)
3. Deploy updated `literature-retrieve.sh` to all projects — at this point central repo is used
4. Verify central repo `--lit` injection works in BimodalLogic and cslib
5. Only then: mark per-project `specs/literature/` as deprecated (leave in place as fallback)

The two-tier fallback in the retrieve script (check `LITERATURE_DIR`, then fall back to `$PROJECT_ROOT/specs/literature`) provides the safety net at step 3-4.

**7. Schema migration: 141 entries needing v1 → v2 backfill (Critic finding)**

Resolution: **Scripted migration with conservative defaults; treat as a dedicated implementation phase.**

Evidence: The Critic confirmed via `jq` that both repos have zero `doc_type` or `source_format` values. 141+ entries need backfilling. Reasonable defaults are deterministic from existing data:
- `doc_type`: entries with non-null `parent_doc` → `"section"` or `"chapter"`; flat entries → `"paper"` (if year + authors suggest article) or `"book"` (heuristic from existing bib_key lookup)
- `source_format`: all existing conversions are from PDF or DJVU; `"pdf"` is correct for ~95%

A migration script can apply these defaults programmatically with a manual review pass for edge cases. This is a real task (30-60 min of scripting) that must be scoped explicitly in the plan phase.

### Gaps Identified

**G1: Concurrency protection for shared `index.json`** (Critic Risk 4, unaddressed by other teammates). Multiple concurrent Claude Code sessions writing to a shared `index.json` via `mv`-based atomic writes can cause last-write-wins data loss. The current per-project isolation avoids this. A file lock (`flock`) or git-rebase workflow should be documented as a future requirement. For the initial single-project-at-a-time workflow, this risk is low but should be acknowledged in the plan.

**G2: Distribution of updated `literature-retrieve.sh`** (Teammate B finding). The script is distributed as copies, not symlinks, during extension install. Updating the shared source at `~/.config/nvim/.claude/scripts/` does not automatically update per-project copies in BimodalLogic and cslib. The plan must include explicit re-deployment via `install-extension.sh` for each affected project.

**G3: Multi-file Zotero entries and primary PDF selection**. 138 Zotero entries have semicolon-separated file lists. No teammate specified the selection heuristic for "which PDF to symlink/copy" when multiple exist. A reasonable heuristic: prefer the path whose filename most closely matches `{Author} - {Year} - {Title}` (the Better BibTeX naming convention) over shorter, less-descriptive filenames (often supplementary material or publisher formats).

**G4: Papers with no Zotero entry** (CSLib has entries with `bib_key: null`). These are manually added papers not tracked in Zotero. The central repo must accommodate these; `zotero_key` and `zotero_path` should both be nullable. The `/literature --index` workflow for such entries is manual — no Zotero lookup step.

**G5: `/literature --scan` behavior with centralized PDFs**. The scan mode currently looks for unprocessed PDFs in `specs/literature/`. With PDFs in Zotero storage (not in `~/Projects/Literature/`), the scan mode may find nothing to process. A Zotero-aware scan mode (scanning `zotero_path` references not yet converted) is a future enhancement.

**G6: ROADMAP placement** (Teammate D finding). Literature centralization is not yet on the project ROADMAP. Once this research phase completes and implementation is planned, an entry should be added to ROADMAP.md as a Phase 2 infrastructure item.

### Strategic Opportunities

**Layer 0 domain knowledge** (Teammate D): Formalizing `~/Projects/Literature/` as a "Layer 0 domain knowledge layer" above the existing five-layer context model is architecturally coherent. The precedent is already established: `~/.config/nvim/.claude/` serves as cross-project agent infrastructure. Literature follows the same pattern. This reframing should inform the architecture documentation update.

**Zotero MCP server** (Teammate B): The `kujenga/zotero-mcp` server (stable as of 2026) is the forward-looking integration pattern — agents could query Zotero directly rather than parsing files. This is a 12-18 month horizon item that depends on MCP server stability and corpus scale, but should be tracked as an architectural option. It would not replace the `index.json` system (which handles offline retrieval and token-budget selection) but could complement it for interactive lookup.

**Memory seeds from literature** (Teammate D): When `/literature --index` creates a new entry, emitting a compact memory candidate (`MEM-lit-{bib_key}: "{Title}" — {summary} — Keywords: {top 3}`) enables two-pass retrieval: memory surfaces the pointer, literature provides the content. This creates a coherent "find → fetch" pattern. Rated medium confidence for the initial implementation (opt-in rather than automatic).

**Annotation integration** (Teammate D): Zotero Better Notes exports annotations to markdown. Co-locating `sec01_annotations.md` alongside `sec01_original.md` and weighting annotation files higher in scoring would give agents access to curated highlights. Feasible now, but a Phase 2+ enhancement.

**RAG/embedding deferral** (Teammate D, confirmed): With ~200 total entries, keyword scoring is well-calibrated. Defer embedding until corpus exceeds ~500 entries or keyword precision degrades. The current `MAX_FILES=10` and `token_budget: 8000` caps are the binding constraints, not search quality.

### Recommendations

1. **Implement `LITERATURE_DIR` env var in `literature-retrieve.sh`** (2-4 lines). This is the critical path change. Add to `skill-literature/SKILL.md` as well (separate code path). Set in `~/.config/nvim/.claude/settings.json` env block AND Home Manager `home.sessionVariables`.

2. **Add CSL-JSON auto-export to `~/Projects/Literature/`**. Configure Better BibTeX to auto-export in CSL-JSON format to `~/Projects/Literature/zotero-library.json` on library changes. This gives scripts a reliable, `jq`-parseable source for Zotero metadata.

3. **Define and create central repo structure**. Create `~/Projects/Literature/index.json` with the v2 schema (including `zotero_key`, `zotero_path`, `project_tags` new fields). Create `pdfs/` directory with `.gitignore`. Write README describing the two-tier architecture.

4. **Write schema migration script** for 141 existing v1 entries. Apply `doc_type`/`source_format` defaults programmatically. Include a `bib_key` → `zotero_key` mapping for the 3 known divergent cases. Scope: ~30-60 min of scripting.

5. **Migrate existing content in order**: BimodalLogic (113 entries) → cslib (76 entries). Copy markdown files to `~/Projects/Literature/`, update index.json entries, verify `--lit` injection works from each project before proceeding to the next.

6. **Deploy updated scripts to all projects** via `install-extension.sh`. Both `literature-retrieve.sh` and `skill-literature/SKILL.md` need re-deployment to BimodalLogic and cslib after the env var changes.

7. **Keep per-project `specs/literature/` as read-only fallback**. Do not delete or empty existing per-project dirs until central repo is verified working for all tasks in each project. Mark them deprecated in a README note.

8. **Implement `--import-from-zotero KEY` mode** (Phase 2). Given a bib_key: look up `zotero-library.json`, find PDF via `zotero_path`, create symlink in `pdfs/`, run `/literature --convert`, and auto-populate index metadata. This streamlines the paper ingestion workflow.

9. **Add ROADMAP entry** for literature centralization as Phase 2 infrastructure.

10. **Defer**: memory seed emission, annotation integration, concurrency locking, RAG/embedding, MCP server. These are Phase 3+ items.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary implementation approaches | completed | high |
| B | Alternative approaches and prior art | completed | high |
| C | Critic/gaps and risks | completed | high |
| D | Strategic horizons | completed | medium |

---

## References

**Codebase (directly examined)**
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — hardcoded path resolution at lines 29-32
- `/home/benjamin/.config/nvim/.claude/skills/skill-literature/SKILL.md` — hardcoded `lit_dir="specs/literature"`
- `/home/benjamin/texmf/bibtex/bib/Zotero.bib` — 878 entries, 693KB, Better BibTeX auto-export
- `/home/benjamin/Projects/BimodalLogic/specs/literature/index.json` — 113 entries, v1 schema, `token_budget: 40000`
- `/home/benjamin/Projects/cslib/specs/literature/index.json` — 76 entries, v2-compatible schema, `token_budget: 4000`
- `/home/benjamin/Projects/Literature/` — bare git repo, blank README, no content

**Web Sources (Teammate B)**
- [Better BibTeX for Zotero — Bundled Translators](https://retorque.re/zotero-better-bibtex/installation/bundled-translators/)
- [Better CSL JSON Translator](https://github.com/retorquere/zotero-better-bibtex/blob/master/translators/Better%20CSL%20JSON.ts)
- [Zotero Local API](https://forums.zotero.org/discussion/116548/how-to-use-pyzotero-to-access-zotero-7-beta-local-api-server)
- [Zotero MCP Server](https://mcpservers.org/servers/kujenga/zotero-mcp)
- [Codified Context: AI Agent Infrastructure](https://arxiv.org/html/2602.20478v1)
- [XDG Configuration in Home Manager](https://deepwiki.com/nix-community/home-manager/4.7.2-xdg-configuration)
