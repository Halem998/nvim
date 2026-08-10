# Research Report: Task #710 — Teammate D (Horizons)
# Centralized Literature Management — Strategic Alignment & Future Direction

**Task**: 710 - research_centralized_literature_zotero
**Role**: Teammate D — Horizons (long-term alignment, strategic direction)
**Started**: 2026-06-14T22:00:00Z
**Completed**: 2026-06-14T22:40:00Z
**Effort**: ~1.5 hours
**Sources/Inputs**: Codebase (agent system, literature extension, memory vault, context architecture), ROADMAP.md, Zotero.bib, BimodalLogic/cslib specs/literature/, web research (2026 state of the art)

---

## Key Findings

### 1. The ROADMAP Does Not Yet Include Literature Centralization

The project ROADMAP.md (read in full) covers Phase 1 priorities around documentation infrastructure (manifest-driven README generation, marketplace metadata, CI doc-lint) and Phase 2 improvements (extension hot-reload, context discovery caching). Literature centralization is not yet represented. This task is therefore forward-looking infrastructure, not a maintenance fix — it should eventually land on the roadmap as a Phase 2 or Phase 3 item once the design stabilizes.

### 2. The Two Existing Repos Have Minimal Overlap — By Design

BimodalLogic has 113 entries, cslib has 76 entries. Shared `bib_key` values:
- `Burgess1984` (appears in both — different chunking, same source)
- `GHR94` (Gabbay, Hodkinson, Reynolds — temporal logic handbook)
- `Reynolds1994` (both projects reference temporal logic foundations)

The overlap is small (3 out of ~189 total) because the repos serve adjacent but distinct research programs (bimodal temporal logic vs. constructive/classical proof theory). A centralized repo must not assume high overlap or deduplicate aggressively — it should index by `bib_key` and let each project's retrieval select what it needs by keyword.

### 3. Schema Parity Is Already Close — No `doc_type` Field Exists Yet

Both existing `index.json` schemas are identical in fields: `id`, `bib_key`, `title`, `authors`, `year`, `section`, `path`, `page_range`, `token_count`, `keywords`, `summary`. Neither currently uses `doc_type` or `source_format` (mentioned in the EXTENSION.md as planned enriched fields). A centralized schema should introduce these but treat them as nullable for backward compatibility.

### 4. The Zotero.bib `file` Field Is the Bridge to PDFs

The Zotero.bib has 878 entries. The `file` field consistently contains absolute paths into `/home/benjamin/Documents/Zotero/storage/{HASH}/filename.pdf`. Some entries have multiple files (semicolon-separated). This field is the key bridge: a literature ingestion tool can match a `bib_key` in the central index against the BibTeX entry to locate its PDF automatically, without the user having to specify paths manually.

### 5. The Memory Vault Is an Architectural Sibling, Not a Competitor

The memory vault (`.memory/`, 18 entries, `memory-index.json`) stores short-form learned facts (keyword-indexed, 65–400 tokens each). Literature entries store full converted text (3,000–7,000 tokens). These are complementary tiers:
- Memory: agent-learned procedural knowledge, reusable across runs
- Literature: source-of-truth reference material, injected on demand via `--lit`

The clean architectural separation is intentional and should be preserved. However, there is a synergy opportunity: when `/literature --index` creates a new entry, a short memory candidate ("paper X covers topic Y at high depth") could be emitted to the vault. This is a future refinement, not a first-release requirement.

### 6. The `literature-retrieve.sh` Script Has a Hard-Coded `PROJECT_ROOT` Path

The current implementation derives `LIT_DIR` from `SCRIPT_DIR/../..` (i.e., relative to the script's location inside `.claude/scripts/`). This means it always looks in `specs/literature/` of the current project. To support a centralized repo, this lookup must be extended with a `LITERATURE_DIR` override, checked before the per-project fallback.

---

## Strategic Opportunities

### A. Literature as a "Shared Context Layer" — The `.claude/context/` Analogy

The existing agent system already distinguishes three context layers: agent context (`.claude/context/`), project context (`.context/`), and project memory (`.memory/`). A centralized `~/Projects/Literature/` would be a **fourth layer**: shared domain knowledge that sits above all projects, managed independently of any single repo.

This maps cleanly onto how `.claude/` itself is shared across child projects via `~/.config/nvim/.claude/`. The precedent is already established in the architecture: shared infrastructure lives outside individual repos and is referenced by path or environment variable.

The strategic opportunity: formalize this as the **"domain knowledge layer"** in the architecture docs, distinct from project-scoped literature (`specs/literature/`). Projects could declare a dependency on the central corpus for `--lit` retrieval, just as extensions declare dependencies on each other.

### B. Two-Tier Literature Discovery

Rather than replacing per-project `specs/literature/`, the architecture should support a two-tier lookup:

1. **Central tier** (`$LITERATURE_DIR`, default `~/Projects/Literature/`) — shared across all repos, Zotero-backed, stable
2. **Project tier** (`specs/literature/`) — project-specific chunks, experimental, work-in-progress

The `literature-retrieve.sh` script already does greedy scoring and budget-capped selection. With two tiers, it would score and select from both pools, with project-tier entries taking precedence for the same `bib_key` (allowing a project to override or extend a central entry).

**Why this beats full centralization**: Projects often need custom chunking of shared papers (different section boundaries matter for different research questions). Project-local entries remain useful even when the central entry exists.

### C. Zotero as a Metadata Oracle, Not a Storage System

The critical insight: Zotero's value to this system is **metadata richness** (authors, year, journal, DOI, abstract, citation keys) and **PDF location** (the `file` field), not storage. The centralized `~/Projects/Literature/index.json` should treat `Zotero.bib` as a read-only oracle for populating metadata fields during indexing. This is a one-way data flow: Zotero -> Literature index (not the reverse).

**Practical design**: When `/literature --index FILE` is run in the central repo, the skill should:
1. Parse the `bib_key` from the user or filename convention
2. Look up that key in `Zotero.bib` (via `grep` or BibTeX parser)
3. Auto-populate `authors`, `year`, `title`, `journal/booktitle`, `doi`, `abstract`
4. Set `source_format: "pdf"` and record the Zotero storage path in a new `zotero_path` field
5. The user only needs to confirm/edit the `keywords` and `summary`

This dramatically reduces the manual metadata burden that currently makes indexing slow.

### D. PDF Storage: Symlink Wins for Single-Machine Use, Copy Wins for Portability

For the current single-user setup:
- **Symlinks to Zotero storage** are ideal: zero duplication, always up-to-date if Zotero moves a file, and the Zotero storage paths are stable (hash-named directories don't change).
- **Copies** are better if: (a) syncing to a different machine where Zotero storage isn't available, (b) archiving a snapshot of the corpus independent of Zotero.

**Recommended design**: Default to symlinks for the `~/Projects/Literature/pdfs/` directory (one symlink per canonical bib_key), with a `--copy` flag on `/literature --import` for portability. The `zotero_path` field in index.json provides the source for both operations.

---

## Creative / Unconventional Approaches

### 1. Literature Entries as Memory Seeds (Bidirectional Linking)

When a literature entry is indexed, automatically emit a compact memory to the vault:
```
MEM-lit-{bib_key}: "{Title}" ({Year}) — {one-sentence summary} — Keywords: {top 3}
```

Then `memory-retrieve.sh` could surface "there is a literature entry for this topic" during research, and agents could decide whether to fetch the full text via `--lit`. This creates a lightweight two-pass retrieval system: memory gives the pointer, literature provides the content.

The memory vault already has the right schema for this (category: `INSIGHT`, 50-100 tokens). The implementation cost is low: add an emit step to `/literature --index`.

### 2. Zotero Annotations as First-Class Context

Zotero's Better Notes plugin (2026 state of the art) exports annotations (highlights, comments) to markdown with YAML frontmatter. If annotations were co-located with literature chunks in the central repo:
```
~/Projects/Literature/
  burgess_1984/
    sec01_original.md      (converted full text)
    sec01_annotations.md   (exported Zotero highlights/notes)
```

The scoring function in `literature-retrieve.sh` could weight annotation files higher (they represent focused reading, not raw text), and the `--lit` context block could include both. This would give agents access to what the researcher found important, not just the full text.

**Feasibility**: Zotero's Better Notes exports to markdown with reasonable structure. A one-time export per paper, triggered by `/literature --annotate`, is implementable now.

### 3. A "Literature Review" Agent for Periodic Synthesis

The existing agent system has synthesis agents (used in `--team` mode). A lightweight variant could operate on the central literature corpus periodically:

```
/literature --synthesize [TOPIC]
```

This would:
1. Retrieve all entries matching a topic keyword
2. Ask a synthesis agent to write a 500-word overview connecting the papers
3. Write the synthesis to `~/Projects/Literature/syntheses/{topic}.md`
4. Index the synthesis as a special `doc_type: "synthesis"` entry

Syntheses could then be retrieved via `--lit` just like primary sources. This is analogous to how `/distill --compress` works in the memory vault — generating derived artifacts from raw material.

### 4. RAG/Embedding as a Phase 3 Enhancement

As of June 2026, local embedding generation is practical (nomic-embed-text-v2-moe in GGUF format, runs offline). A vector index over the central literature corpus would enable semantic search that goes beyond keyword overlap. However:

- The keyword scoring system already works well for the current scale (~200 total entries)
- Embedding adds operational complexity (index maintenance, model dependencies)
- The token-budget-based retrieval in `literature-retrieve.sh` already handles the fundamental constraint: context window size

**Recommendation**: Defer RAG/embedding until the corpus exceeds ~500 entries or keyword retrieval precision drops below acceptable quality. The current keyword approach with summary bonuses is well-calibrated for the research domain (formal logic/philosophy) where term specificity is high.

### 5. MCP Server as the Eventual Delivery Mechanism

The 2026 MCP ecosystem (10,000+ public servers, Anthropic donated MCP to Linux Foundation) shows that tool-level integration via MCP is the mature pattern. A future `literature-mcp-server` could expose:
- `search_literature(query, max_results)` — keyword + semantic search
- `get_paper(bib_key)` — full text retrieval
- `cite(bib_key)` — return formatted citation

This would allow any MCP-capable agent (not just Claude Code) to access the corpus. The central `~/Projects/Literature/` repo would become the backing store, and the MCP server would be a thin query layer. This is a 12-18 month horizon item, dependent on the corpus reaching sufficient scale.

---

## Alignment with Agent System Architecture

### Fits the Pattern, Extends the Layered Architecture

The existing five-layer context model is:
1. Agent context (`.claude/context/`)
2. Extensions (`.claude/extensions/*/context/`)
3. Project context (`.context/`)
4. Project memory (`.memory/`)
5. Auto-memory (`~/.claude/projects/`)

A centralized Literature layer fits cleanly as a **Layer 0** — pre-project, shared domain knowledge. The naming convention would be:

| Layer | Location | Scope |
|-------|----------|-------|
| Domain knowledge | `~/Projects/Literature/` | Global (all projects) |
| Agent context | `.claude/context/` | System-wide |
| Extensions | `.claude/extensions/*/context/` | Extension-specific |
| Project context | `.context/` | Per-project |
| Project memory | `.memory/` | Per-project, agent-learned |

This is consistent with how `~/.config/nvim/.claude/` already serves as a cross-project agent infrastructure layer.

### The `LITERATURE_DIR` Convention Is the Right Abstraction

Using an environment variable for the central literature directory location mirrors how the system already handles project-agnostic configuration (e.g., `ANTHROPIC_DEFAULT_OPUS_MODEL` in global settings). The convention should be:

```
LITERATURE_DIR=${LITERATURE_DIR:-$HOME/Projects/Literature}
```

This gives:
- A sensible default that works for the current single-user setup
- An override point for multi-machine or shared-lab scenarios
- No changes to per-project `specs/literature/` behavior when `LITERATURE_DIR` is not set

The variable should live in the global `~/.claude/settings.json` `env` block (already established for `ANTHROPIC_DEFAULT_OPUS_MODEL` and others), making it available to all child projects automatically.

### The Literature Extension Should Become a Core Dependency

Currently the literature extension (`dependency: ["core", "filetypes"]`) is opt-in. Given that research-driven projects (BimodalLogic, cslib, nvim) all benefit from it, it should be considered for promotion to a default dependency of the `core` extension, or at minimum added to the standard extension set recommended in the docs.

---

## Multi-User and Cloud Sync Considerations

### Multi-User (Shared Lab Literature)

The current architecture is single-user. For shared-lab use:
- The central repo (`~/Projects/Literature/`) becomes a shared git repository
- `git pull --rebase` before any `--lit` retrieval ensures freshness
- Conflict resolution is safe because `index.json` entries are append-only (no field is mutated after creation) and file paths are stable
- PDFs would be managed separately (not committed to git) — the `zotero_path` field provides the canonical source

### Cloud Sync (Multiple Machines)

The markdown files in `~/Projects/Literature/` are small enough to sync via git. PDFs are not committed (gitignored). On a second machine:
- The index is available immediately (git pull)
- PDFs are available only if Zotero is synced (Zotero WebDAV or Zotero cloud handles this separately)
- The `zotero_path` field becomes a hint for where to find the PDF, not a guarantee

This is a clean separation of concerns: literature index is in git, PDFs are in Zotero's sync layer.

### Non-PDF Sources

The current system handles PDF and DJVU. Future source types to consider:
- **Web articles** (HTML/URL) — could be fetched and converted to markdown by an extended `--convert` mode
- **Video transcripts** (YouTube/conference talks) — a `transcript` source_format
- **Blog posts** — captured via `LITERATURE_DIR` as plain markdown with manual metadata

The `source_format` field in the planned enriched schema (`pdf`, `djvu`, `manual`) should be extended to include `web`, `transcript`, `epub`. The `--lit` retrieval pipeline is agnostic to source format (it just reads markdown), so this extension requires only schema updates and new conversion handlers.

---

## Confidence Assessment

| Finding | Confidence |
|---------|-----------|
| Two-tier (central + per-project) is better than full migration | High |
| `LITERATURE_DIR` env var is the right abstraction | High |
| Symlinks preferred for single-machine PDF storage | High |
| Zotero.bib as metadata oracle for auto-population | High |
| Memory vault and literature are complementary, not competing | High |
| Annotation extraction as Phase 2 enhancement | Medium |
| RAG/embedding deferred until 500+ entries | Medium |
| Literature entries as memory seeds | Medium |
| MCP server as eventual delivery mechanism | Low-Medium (12-18 months) |
| Synthesis agent for periodic literature review | Low (speculative) |

---

## Summary Recommendations for Architecture Design

1. **Two-tier retrieval**: `LITERATURE_DIR` (global) checked before `specs/literature/` (per-project); project entries take precedence for same `bib_key`.

2. **Zotero.bib auto-population**: When indexing, parse `bib_key` -> look up `Zotero.bib` -> auto-fill `authors`, `year`, `title`, `abstract`, `doi` and record `zotero_path`.

3. **Symlink strategy**: `~/Projects/Literature/pdfs/{bib_key}.pdf` -> Zotero storage path; `--copy` flag for portability.

4. **Enhanced schema**: Add `doc_type` (`paper`/`book`/`chapter`/`section`/`synthesis`), `source_format` (`pdf`/`djvu`/`manual`/`web`/`transcript`), `zotero_path` (nullable), `project_tags` (array of project slugs that have used this entry).

5. **Memory seed emission**: On `/literature --index`, emit a compact memory candidate to `.memory/` (opt-in initially, automatic later).

6. **Global env var in settings**: Add `LITERATURE_DIR` to `~/.claude/settings.json` `env` block with `$HOME/Projects/Literature` default.

7. **Defer RAG**: Keep keyword scoring; revisit when corpus exceeds 500 entries.

8. **Literature extension promotion**: Consider making it a recommended default across all research-oriented projects, not opt-in.
