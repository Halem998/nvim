# Research Report: Task #747 — Evaluate Zotero CLI Tools

**Task**: 747 - Research and evaluate zotero-cli-cc and 54yyyu/zotero-mcp for shell-first Zotero backend
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:30:00Z
**Effort**: ~1 hour
**Dependencies**: None
**Sources/Inputs**: GitHub repositories, PyPI, official Zotero documentation, project documentation sites
**Artifacts**: specs/747_evaluate_zotero_cli_tools/reports/01_zotero-cli-eval.md
**Standards**: report-format.md

---

## Executive Summary

- **zotero-cli-cc** (Agents365-ai) is the stronger shell-first backend: pure SQLite reads require zero config, offline-capable, agent-optimized JSON envelope, and the write path uses the Zotero Web API rather than the local socket.
- **zotero-mcp** (54yyyu) has a richer feature set (semantic search, PDF outline extraction, Better BibTeX integration) but its "local" mode depends on Zotero's localhost:23119 HTTP API and requires Zotero to be running; write operations through local mode are unreliable (Zotero's own documentation calls the local JS API incomplete for modifications).
- Recommended approach: use **zotero-cli-cc as the primary backend** for item reads, PDF extraction, search, and note writes; layer **zotero-mcp's standalone `zotero-cli`** only if semantic/embedding search is needed. Both install cleanly with `uv` or `pipx` on NixOS.
- Neither tool is packaged in nixpkgs; both require `uv`/`pipx` installation or a custom Nix derivation from PyPI.

---

## Context & Scope

The goal is to select a shell-first backend for a new Claude Code Zotero extension that:
1. Reads and writes attachments and notes on Zotero items
2. Can store converted markdown as Zotero notes or linked attachments
3. Works offline via SQLite where possible
4. Resolves and reads PDFs from Zotero storage
5. Emits stable JSON for agent consumption
6. Has manageable authentication requirements
7. Supports keyword, full-text, and tag-based search
8. Can be installed on NixOS via pip/pipx/uv

Two primary candidates were evaluated:
- `zotero-cli-cc` by Agents365-ai (GitHub: `Agents365-ai/zotero-cli-cc`, PyPI: `zotero-cli-cc`)
- `zotero-mcp` by 54yyyu (GitHub: `54yyyu/zotero-mcp`, PyPI: `zotero-mcp-server`) — which also ships a standalone `zotero-cli` command

---

## Findings

### Codebase Patterns

#### Zotero Storage Architecture (Background)

All Zotero data lives in two places:
- `zotero.sqlite`: item metadata, notes (as HTML), tags, collections, relations
- `[ZoteroDataDir]/storage/[ITEM_KEY]/`: attachment files (PDFs, snapshots, etc.) in per-item subdirectories

The SQLite database must be opened **read-only** when Zotero is running — direct writes bypass data integrity checks and can corrupt the database. Write operations should go through either the local HTTP API (localhost:23119, read-only by design in Zotero 7) or the Web API (requires API key + library ID).

The local HTTP API at `localhost:23119/api/` is GET-only: it covers search, item retrieval, full-text, collections, tags, and saved searches, but **cannot create or modify items**. It also requires Zotero to be running.

---

### Tool A: zotero-cli-cc (Agents365-ai)

**Package**: `zotero-cli-cc` on PyPI | Command: `zot`
**Version**: 0.4.3 (at time of research)
**License**: GNU AGPL-3.0 (commercial licensing available)
**Python requirement**: Not explicitly stated; uv/pipx compatible

#### Architecture: Hybrid SQLite + Web API

The tool distinguishes read and write paths explicitly:
- **Read path**: direct SQLite queries on `zotero.sqlite` — zero config, no API key, no Zotero running required, millisecond responses
- **Write path**: Zotero Web API — requires `zot config init` to store an API key; Zotero is kept in sync

#### Command Surface

| Category | Command | Mode |
|----------|---------|------|
| Search | `zot search "transformer attention"` | SQLite (offline) |
| Item read | `zot read ABC123` | SQLite (offline) |
| Export | `zot export ABC123` | SQLite + formatting |
| Notes read | `zot note ABC123` | SQLite (offline); HTML converted to Markdown |
| Notes write | `zot note ABC123 --add "text"` | Web API (requires key) |
| Tags read | `zot tag ABC123` | SQLite (offline) |
| Tags write | `zot tag ABC123 --add "important"` | Web API |
| PDF text | `zot pdf ABC123` | Local file (offline) |
| PDF pages | `zot pdf ABC123 --pages 1-5` | Local file (offline) |
| PDF annotations | `zot pdf ABC123 --annotations` | Local file (offline) |
| PDF upload | `zot attach KEY --file paper.pdf` | Web API |
| Open file | `zot open ABC123` | Local file |
| MCP server | `zot mcp serve` | Mixed |

#### JSON Output

When stdout is non-TTY (agent/pipe context), `zot` emits a stable JSON envelope:
```json
{
  "ok": true,
  "data": { "..." },
  "meta": {
    "request_id": "...",
    "cli_version": "0.4.3"
  }
}
```

Exit codes are typed (not just 0/1), and `--dry-run` and `--idempotency-key` flags are supported.

#### PDF Resolution

PDF files are resolved from the Zotero storage directory using the item's key (attachment subdirectory naming convention). The data directory is auto-detected. Results are cached for subsequent accesses.

#### Note/Attachment Write-Back

- Notes can be added to items via `zot note KEY --add "text"` (Web API)
- PDF attachments can be uploaded via `zot attach KEY --file paper.pdf` (Web API, marked completed in ROADMAP)
- No explicit support for storing a markdown file as a linked note attachment confirmed in documentation; the note content is HTML-converted at creation time
- Batch operations are supported via MCP tools (tag_add, tag_remove, note_update)

#### Search Capabilities

- Keyword search over SQLite metadata
- BM25 full-text search over per-topic workspaces
- Optional embedding-based semantic search
- PDF annotation text search

#### Authentication

- Read-only: no authentication required
- Write operations: Web API key from `https://www.zotero.org/settings/security#applications`
- Key stored after `zot config init`

#### Known Limitations / Gaps

- Markdown attachment storage is not a documented write-back path (notes go in as HTML, not markdown files attached to items)
- Commercial use requires separate license (AGPL-3.0 copyleft)
- ROADMAP lists saved searches CRUD, additional export formats, and citeproc bibliography generation as pending

---

### Tool B: zotero-mcp / zotero-cli (54yyyu)

**Package**: `zotero-mcp-server` on PyPI | Commands: `zotero-mcp`, `zotero-cli` (and aliases `s`, `g`, `ann`, `coll`)
**Version**: 0.5.0 (released June 8, 2026)
**License**: MIT
**Python requirement**: Python >= 3.10

#### Architecture: Local HTTP API + Web API

This tool does not read SQLite directly. It operates through two modes:

**Local mode** (`ZOTERO_LOCAL=true`):
- Connects to Zotero's localhost:23119 HTTP API
- Requires Zotero to be running
- Read-only by design (Zotero's local API is GET-only)
- Modification operations (tags, library changes) are unreliable / unsupported in local mode
- WSL2 and cross-host environments break due to hardcoded `localhost` in pyzotero

**Web API mode** (default):
- Requires `ZOTERO_API_KEY`, `ZOTERO_LIBRARY_ID`, `ZOTERO_LIBRARY_TYPE` env vars
- Full read + write access
- Internet required

#### Standalone CLI Command Surface

| Category | Command | Mode |
|----------|---------|------|
| Search (keyword) | `zotero-cli search "query"` / `s "query"` | Local API or Web API |
| Search (semantic) | `zotero-cli search --mode semantic` | Local API (with ChromaDB) |
| Search (tag) | `zotero-cli search --mode tag` | Local API or Web API |
| Item metadata | `zotero-cli get metadata KEY` | Local API or Web API |
| Full text | `zotero-cli get fulltext KEY` | Local API (Zotero 7+) |
| Annotations | `zotero-cli ann KEY` | Local API or Web API |
| Notes read | (via MCP tool `zotero_get_notes`) | Local API or Web API |
| Notes write | `zotero-cli notes create --item-key KEY --text "content" --tags "tags"` | Web API (beta) |
| Collections | `zotero-cli coll list` / `coll search` | Local API or Web API |
| Add paper | `zotero-cli add doi/url/file` | Web API |
| Edit item | `zotero-cli edit KEY --title "text" --add-tags "tags"` | Web API |
| PDF outline | (via `zotero_get_pdf_outline` MCP tool) | Local API |

#### Optional Extras (modular install)

| Extra | Purpose |
|-------|---------|
| `[semantic]` | Vector search with ChromaDB + embedding models (OpenAI, Gemini, local) |
| `[pdf]` | PDF outline extraction, EPUB annotation support |
| `[scite]` | Citation intelligence and retraction alerts |
| `[all]` | All of the above |

#### JSON Output

Output format includes `format="json"` for complete raw Zotero metadata, but no stable envelope specification is documented. Markdown and BibTeX formats also available.

#### PDF Resolution

PDF text access works through Zotero's local API when Zotero 7+ is running. The local API serves full-text content that Zotero has already indexed; PDFs not yet indexed by Zotero may not be available.

#### Note/Attachment Write-Back

- `zotero_create_note` is available but marked **beta**
- CLI `zotero-cli notes create` is supported
- Markdown-to-HTML conversion is handled (pyzotero converts markdown to Zotero's HTML note format internally)
- Stored markdown as a file attachment is not a documented operation

#### Search Capabilities

- Keyword search over items
- Tag-based filtering
- Full-text search (requires Zotero 7+ local API)
- Semantic/vector search (requires `[semantic]` extra and embedding model setup)
- Complex multi-criteria search

#### Authentication

- Local mode: no API key; "Allow other applications to communicate with Zotero" must be enabled in Zotero preferences
- Web API: `ZOTERO_API_KEY` + `ZOTERO_LIBRARY_ID` + `ZOTERO_LIBRARY_TYPE`
- Library ID = numeric user ID from zotero.org settings

#### Known Limitations / Gaps

- Local mode requires Zotero running; no true offline/SQLite mode
- Write operations in local mode are unreliable (Zotero's local JS API documented as incomplete for modifications)
- WSL2 / cross-host environments break local mode (pyzotero hardcodes `localhost:23119`)
- `zotero_create_note` is beta
- Switching between installation methods can corrupt the ChromaDB database (requires `--force-rebuild`)
- `[semantic]` extra adds ML dependencies (ChromaDB, embedding models) that may conflict with Nix

---

### Comparison Matrix

| Criterion | zotero-cli-cc (Agents365-ai) | zotero-mcp / zotero-cli (54yyyu) |
|-----------|------------------------------|----------------------------------|
| **Read items/metadata** | SQLite direct, offline | Local API (Zotero running) or Web API |
| **Read notes** | SQLite direct, offline; HTML→MD | Local/Web API; pyzotero |
| **Write notes** | Web API (`zot note --add`) | Web API (beta `notes create`) |
| **Read attachments (list)** | SQLite direct, offline | Local/Web API |
| **Upload file attachment** | Web API (`zot attach --file`) | Web API (`zotero-cli add file`) |
| **Markdown as Zotero note** | Web API: note body = text content | Web API (pyzotero converts MD to HTML) |
| **Markdown as file attachment** | Not documented | Not documented |
| **Offline SQLite reads** | Yes — zero config, Zotero not required | No — requires Zotero local API running |
| **PDF text extraction** | Local file system (auto-detected path) | Zotero's indexed fulltext (Zotero running) |
| **PDF page extraction** | `zot pdf KEY --pages N-M` | Not documented in CLI |
| **PDF annotation extraction** | `zot pdf KEY --annotations` | `zotero-cli ann KEY` |
| **JSON output (stable)** | Yes — typed envelope, exit codes, idempotency | format=json available; no stable envelope |
| **Auth (reads)** | None (SQLite) | None (local API), requires Zotero running |
| **Auth (writes)** | Web API key via `zot config init` | API key + library ID env vars |
| **Keyword search** | SQLite (offline) | Local/Web API |
| **Full-text search** | BM25 over workspaces + PDF text | Zotero's indexed fulltext (Zotero 7+) |
| **Tag search** | SQLite (offline) | Local/Web API |
| **Semantic search** | Optional (local embeddings) | Optional (`[semantic]` extra, ChromaDB) |
| **NixOS pip/pipx install** | `pipx install zotero-cli-cc` or `uv tool install zotero-cli-cc` | `pipx install zotero-mcp-server` or `uv tool install zotero-mcp-server` |
| **In nixpkgs** | No (PyPI only) | No (PyPI only) |
| **uv install (NixOS preferred)** | `uv tool install zotero-cli-cc` | `uv tool install zotero-mcp-server` |
| **Python requirement** | Not stated explicitly | Python >= 3.10 |
| **License** | AGPL-3.0 (commercial = separate license) | MIT |
| **Maintainer** | Agents365.ai (active, v0.4.3) | 54yyyu (active, v0.5.0, June 2026) |
| **MCP server mode** | Yes (`zot mcp serve`, 45 tools) | Yes (primary mode) |
| **Complexity / extras** | Single install, lean | Modular extras; ML deps optional |

---

### NixOS Installation Analysis

Neither tool is packaged in nixpkgs. Two viable approaches on NixOS:

**Option A: uv tool install (recommended by NixOS community)**
```bash
# Install uv via home-manager or nixpkgs
# Then:
uv tool install zotero-cli-cc
uv tool install zotero-mcp-server  # if needed
```
`environment.localBinInPath = true` must be set so `~/.local/bin` is on PATH.

**Option B: pipx**
```bash
# Install pipx via nixpkgs
# Then:
pipx install zotero-cli-cc
pipx install "zotero-mcp-server[all]"
```

**Option C: Custom Nix derivation from PyPI**
Using `pythonPackages.buildPythonPackage` or `pyproject2nix`/`uv2nix` — more reproducible but requires manual maintenance.

The NixOS community has increasingly moved toward `uv` as the preferred Python tool installer, making Option A the lowest-friction choice.

---

### Recommendations

#### Primary Backend: zotero-cli-cc

For a shell-first agent backend, `zotero-cli-cc` is the clear winner:

1. **Offline SQLite reads**: No requirement for Zotero to be running — agents can query metadata, notes, tags, and resolve PDF paths without launching the desktop app.
2. **Agent-optimized output**: The stable JSON envelope with typed exit codes, `--dry-run`, and `--idempotency-key` flags are purpose-built for programmatic consumption.
3. **PDF extraction**: `zot pdf KEY --pages N-M` provides page-granular text access from the local filesystem.
4. **Note writeback**: `zot note KEY --add "text"` sends notes through the Web API, keeping Zotero in sync.
5. **Single install, low complexity**: No ML extras needed for core functionality.

**Write-back for converted markdown**: The note-add path (`zot note KEY --add`) accepts text content and stores it as a Zotero HTML note (Zotero's native note format). This is the correct approach — Zotero does not natively support markdown note files as first-class items; notes are always HTML internally. The display of markdown syntax is handled by rendering plugins (Better Notes, etc.). For file attachments (e.g., the raw markdown file itself), `zot attach KEY --file` can upload any file.

#### Secondary / Optional: zotero-mcp semantic search

If **semantic search** is needed (concept-based similarity over the library), `zotero-mcp-server[semantic]` can be layered alongside `zotero-cli-cc`. The two tools do not conflict — they use different backends (SQLite vs. local API).

#### What to Build

The Zotero extension should:
1. **Wrap `zot`** for all read operations (search, item metadata, notes, PDF text)
2. **Wrap `zot config init`** as a one-time setup step for write operations
3. **Use `zot note KEY --add`** to store converted markdown summaries as Zotero notes
4. **Use `zot attach KEY --file`** if the raw markdown file should be stored as a linked attachment
5. **Parse the JSON envelope** (`ok`, `data`, `meta`) for all agent consumption paths

---

## Decisions

- **Selected primary tool**: `zotero-cli-cc` (Agents365-ai) — shell-first, SQLite-offline reads, stable JSON output
- **Selected secondary tool (optional)**: `zotero-mcp-server[semantic]` (54yyyu) — semantic search only, if needed
- **NixOS install method**: `uv tool install` with `environment.localBinInPath = true`
- **Note writeback strategy**: Use `zot note KEY --add "text"` via Web API; Zotero stores as HTML note (markdown syntax preserved in content)
- **PDF access strategy**: `zot pdf KEY` for text; `zot pdf KEY --pages N-M` for page-granular access; `zot pdf KEY --annotations` for highlights

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| zotero-cli-cc AGPL-3.0 license copyleft | Medium | Extension code must be open-source or commercial license required; evaluate licensing requirements |
| Web API key required for writes | Low | One-time setup; stored by `zot config init`; clearly documented in extension onboarding |
| No nixpkgs package (manual install) | Low | `uv tool install` is straightforward; document in extension README |
| Local API unreliable for writes (zotero-mcp limitation) | Low | We use zotero-cli-cc which routes writes through Web API, not local API |
| Zotero not running for local-mode tools | Low | zotero-cli-cc reads SQLite directly — Zotero does not need to run for reads |
| PDF not indexed by Zotero yet | Low | zotero-cli-cc reads PDFs from filesystem directly, not from Zotero's index |
| Note content stored as HTML, not markdown | Low | Expected behavior; markdown syntax is preserved in note body; render with Better Notes if needed |
| WSL2 networking issues (zotero-mcp local mode) | Medium | Only affects zotero-mcp; mitigated by not using it as primary backend |

---

## Context Extension Recommendations

- **Topic**: Zotero storage layout (SQLite schema, storage/ directory structure, item key naming)
- **Gap**: No documented context on how Zotero stores data locally; agents researching Zotero integrations need to understand the SQLite + filesystem split
- **Recommendation**: Add `.claude/context/project/zotero/domain/zotero-storage-layout.md` once the extension is built

- **Topic**: uv vs pipx for Python CLI tools on NixOS
- **Gap**: NixOS approach to PyPI-only tools (not in nixpkgs) is underdocumented in agent context
- **Recommendation**: Add a note in nix extension context about `uv tool install` with `localBinInPath`

---

## Appendix

### Search Queries Used
- `zotero-cli-cc Agents365-ai GitHub zotero CLI Python shell`
- `54yyyu zotero-cli GitHub Python shell backend Zotero API`
- `Zotero CLI tools Python shell SQLite offline access attachments notes 2025`
- `zotero local API "localhost:23119" offline read notes attachments items without internet`
- `pipx NixOS home-manager install Python CLI tools 2024 2025`
- `zotero SQLite database direct access "zotero.sqlite" attachments PDF path offline read-only`
- `"zotero-mcp" "zotero-cli" 54yyyu notes create write attachment markdown stored offline SQLite`
- `zotero-cli-cc "zot" command reference search notes attach pdf JSON output 2025`

### References

- GitHub: https://github.com/Agents365-ai/zotero-cli-cc
- Docs: https://agents365-ai.github.io/zotero-cli-cc/
- GitHub: https://github.com/54yyyu/zotero-mcp
- PyPI (zotero-mcp): https://pypi.org/project/zotero-mcp-server/ (v0.5.0, June 8 2026)
- Zotero SQLite docs: https://www.zotero.org/support/dev/client_coding/direct_sqlite_database_access
- Zotero Web API docs: https://www.zotero.org/support/dev/web_api/v3/basics
- NixOS Python packaging: https://wiki.nixos.org/wiki/Python
- NixOS pipx discussion: https://discourse.nixos.org/t/installing-python-packages-in-isolated-environments-with-pipx/30680
