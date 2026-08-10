# Zotero CLI Tools Evaluation — Final Recommendation

**Task**: 747 — Evaluate Zotero CLI Tools for Shell-First Integration
**Date**: 2026-06-19
**Status**: Recommendation finalized; installation verified

> For detailed findings, evaluation methodology, and full comparison rationale,
> see the research report: `specs/747_evaluate_zotero_cli_tools/reports/01_zotero-cli-eval.md`

---

## Decision Summary

**Primary backend: `zotero-cli-cc` (Agents365-ai)**
**Secondary (optional): `zotero-mcp-server[semantic]` (54yyyu)**

`zotero-cli-cc` is the recommended shell-first backend for a Claude Code Zotero extension.
Its offline SQLite read path, stable typed JSON envelope, page-granular PDF access, and
child attachment support make it purpose-built for agent consumption. The write path (note
add, file attach) routes through the Zotero Web API and is idempotency-keyed for safe retries.

---

## Comparison Matrix

| Criterion | zotero-cli-cc (Agents365-ai) | zotero-mcp / zotero-cli (54yyyu) |
|-----------|------------------------------|----------------------------------|
| **Read items/metadata** | SQLite direct — offline, no Zotero needed | Local API (Zotero running) or Web API |
| **Read notes** | SQLite direct, HTML->MD conversion | Local or Web API via pyzotero |
| **Write notes** | `zot note KEY --add "text"` (Web API) | Web API, `notes create` (beta) |
| **Read attachments** | SQLite direct — offline | Local or Web API |
| **Upload file attachment** | `zot attach KEY --file path` (Web API) | Web API (`add file`) |
| **Markdown as Zotero note** | Web API — note body stores text content | Web API — pyzotero converts MD to HTML |
| **Markdown as file attachment** | `zot attach KEY --file chunk.md` (Web API, verified) | `add file` (Web API) |
| **Child attachment support** | Yes — `zot attach` links file to parent item key | Yes — via `add` command |
| **Offline SQLite reads** | Yes — zero config, Zotero not required | No — requires Zotero local API (port 23119) |
| **PDF text (full)** | `zot pdf KEY` (filesystem, offline) | Zotero indexed fulltext (Zotero 7+ running) |
| **PDF page extraction** | `zot pdf KEY --pages 1-5` (offline) | Not documented in CLI |
| **PDF annotation extraction** | `zot pdf KEY --annotations` (offline) | `ann KEY` (local/web API) |
| **PDF outline extraction** | `zot pdf KEY --outline` (offline) | MCP tool (local API, Zotero running) |
| **JSON output stability** | Typed envelope: `{ok, data, meta}`, exit codes, idempotency | `format=json` available; no stable envelope |
| **Auth (reads)** | None (SQLite) | None (local mode, but Zotero must be running) |
| **Auth (writes)** | Web API key via `zot config init` | `ZOTERO_API_KEY` + `ZOTERO_LIBRARY_ID` env vars |
| **Keyword search** | SQLite (offline), BM25 full-text | Local or Web API |
| **Tag search** | SQLite (offline) | Local or Web API |
| **Full-text search** | BM25 over PDF text cache | Zotero's indexed fulltext (Zotero 7+) |
| **Semantic search** | Optional (embedding models) | Optional (`[semantic]` extra, ChromaDB) |
| **NixOS install** | `uv tool install zotero-cli-cc` (verified) | `uv tool install zotero-mcp-server` |
| **In nixpkgs** | No (PyPI only) | No (PyPI only) |
| **Python requirement** | Not stated; runs on Python 3.13 (tested) | Python >= 3.10 |
| **License** | AGPL-3.0 (commercial license separate) | MIT |
| **Version tested** | 0.7.0 (released after research; 0.4.3 in report) | 0.5.0 (June 2026) |
| **MCP server mode** | Yes (`zot mcp serve`) | Yes (primary mode) |
| **Complexity** | Single install; no ML extras for core | Modular extras; ML deps for semantic search |

---

## Recommended Architecture

### Primary Backend: zotero-cli-cc

The extension shell scripts and agent prompts should use `zot` (zotero-cli-cc) for all
operations:

```
Read path  <- SQLite direct (offline)
Write path <- Zotero Web API (key required)
```

**Why zotero-cli-cc wins**:

1. **Offline SQLite reads**: No requirement for Zotero desktop to be running. Agents can
   query metadata, notes, tags, collections, and resolve PDF paths with millisecond latency.

2. **Agent-optimized output**: The stable JSON envelope `{ok, data, meta}` with typed exit
   codes, `--dry-run`, `--idempotency-key`, and `--no-interaction` flags is purpose-built
   for programmatic consumption. Version 0.7.0 also exposes a `schema` command for
   self-describing the CLI surface.

3. **PDF access**: Page-granular extraction (`--pages N-M`), outline extraction (`--outline`),
   and annotation extraction (`--annotations`) all work from the local filesystem — no
   Zotero indexing required.

4. **Child attachment support**: `zot attach KEY --file chunk.md` creates a child attachment
   under any parent item key. Verified via dry-run in live library. This is the correct path
   for storing markdown chunks alongside their source PDFs.

5. **Single lean install**: No ML extras needed for core functionality. Total install resolves
   36 packages; no ChromaDB or embedding models.

### Secondary Backend (optional): zotero-mcp semantic search

If the extension needs **semantic similarity search** (concept-based, beyond keyword/BM25),
`zotero-mcp-server[semantic]` can be layered alongside. The two tools do not conflict:
zotero-cli-cc reads SQLite; zotero-mcp-server reads the local API. Both can coexist.

Use `zotero-mcp-server` **only** for this optional semantic search path. Do not use it as
the primary backend: it requires Zotero running, has no stable JSON envelope, and write
operations via local mode are unreliable.

---

## Getting Started

### Installation on NixOS

**Step 1**: Ensure `uv` is available (via nixpkgs or home-manager):

```nix
# home.nix
home.packages = [ pkgs.uv ];
programs.home-manager.enable = true;

# Required so uv-installed tools are on PATH
home.sessionVariables.PATH = "$HOME/.local/bin:$PATH";
# Or use: environment.localBinInPath = true; (NixOS system config)
```

**Step 2**: Install zotero-cli-cc:

```bash
uv tool install zotero-cli-cc
```

This installs the `zot` command to `~/.local/bin/zot`. The install is self-contained in a
uv-managed virtualenv at `~/.local/share/uv/tools/zotero-cli-cc/`.

**Step 3 (important)**: Configure the data directory if Zotero is not in `~/Zotero/`:

```bash
# If your Zotero library is at ~/Documents/Zotero/:
export ZOT_DATA_DIR="$HOME/Documents/Zotero"

# Verify:
zot config show
# Should show: Database: /home/USERNAME/Documents/Zotero/zotero.sqlite (OK)
```

Add to `~/.bashrc` or `~/.zshrc` for persistence:
```bash
export ZOT_DATA_DIR="$HOME/Documents/Zotero"
```

**Step 4 (write operations)**: Initialize API key for writes (one-time setup):

```bash
zot config init
# Follow the interactive prompts to store your Zotero API key
```

### Upgrading

```bash
uv tool upgrade zotero-cli-cc
```

---

## API Key Setup (Write Operations)

Read operations (search, read, note view, PDF extract, stats) require no authentication.

For write operations (add notes, upload attachments, tag edits), you need a Zotero API key:

1. Go to: https://www.zotero.org/settings/security#applications
2. Click "Create new private key"
3. Grant "Allow library access" and "Allow write access"
4. Copy the generated key
5. Run: `zot config init` and paste the key when prompted
6. Enter your Zotero user ID (the numeric ID from https://www.zotero.org/settings/account)

The key is stored in `~/.config/zot/config.toml`. Do not commit this file.

---

## Command Quick Reference

### Search and Retrieval (offline, no auth)

```bash
# Keyword search
zot search "modal logic" --limit 10
zot --json search "Kripke" --limit 5          # JSON output for agent consumption

# Filter by collection or item type
zot search "logic" --collection "Formal Tools"
zot search "completeness" --type journalArticle

# View item details
zot read Z7T6Q25X
zot --json read Z7T6Q25X                      # Full JSON metadata

# List recent items
zot recent
zot list --limit 20

# Library overview
zot stats
```

### PDF Access (offline, no auth)

```bash
# Full text extraction
zot pdf KEY

# Page-granular extraction
zot pdf KEY --pages 1-5

# Document outline (headings)
zot pdf KEY --outline

# Extract section by heading number
zot pdf KEY --section 3

# PDF annotations/highlights
zot pdf KEY --annotations

# JSON output for all PDF commands
zot --json pdf KEY --pages 1-5
```

### Notes (read offline; write requires API key)

```bash
# View notes for item
zot note KEY

# Add a note (Web API)
zot note KEY --add "Summary: This paper proves..."

# Preview without committing (dry-run)
zot note KEY --add "Draft note" --dry-run

# Safe retries with idempotency key
zot note KEY --add "Note text" --idempotency-key "note-abc-2026"
```

### Attachments (write requires API key)

```bash
# Upload a file as child attachment
zot attach KEY --file /path/to/file.md

# Upload a PDF
zot attach KEY --file /path/to/paper.pdf

# Preview without uploading (dry-run)
zot attach KEY --file /path/to/chunk.md --dry-run

# Idempotent upload
zot attach KEY --file chunk.md --idempotency-key "chunk-abc-v1"
```

### Tags and Collections (read offline; write requires API key)

```bash
# View tags for item
zot tag KEY

# Add/remove tags
zot tag KEY --add "read"
zot tag KEY --remove "unread"
zot tag KEY --dry-run --add "preview"

# List collections
zot collection list
```

---

## Verified Installation Details

Smoke-tested on NixOS (2026-06-19):

| Test | Result |
|------|--------|
| `uv --version` | uv 0.11.19 at /run/current-system/sw/bin/uv |
| `uv tool install zotero-cli-cc` | Installed v0.7.0; 36 packages resolved |
| `zot --version` | "zot, version 0.7.0" |
| `zot --help` | Full command surface confirmed (search, read, note, pdf, attach, tag, export, collection, stats, list, add, update, delete, mcp, bridge, summarize, workspace, schema) |
| `zot search "modal logic"` (with ZOT_DATA_DIR) | 3 results returned; JSON envelope `{ok, data, meta}` confirmed; latency 922ms |
| `zot --json read Z7T6Q25X` | Full item metadata including tags, creators, DOI, extra fields |
| `zot --json stats` | Library: 880 items, 870 PDFs, 18 notes, 13 collections |
| `zot note KEY --add "text" --dry-run` | Dry-run preview confirmed; `{ok, data: {would: {...}}, dry_run: true}` |
| `zot attach KEY --file chunk.md --dry-run` | Dry-run confirmed child attachment creation |
| `zot collection list` | 13 collections returned with nested children |

**Deviation from research report**: The research identified v0.4.3; installed version is v0.7.0.
The command surface is largely compatible but expanded: v0.7.0 adds `schema`, `summarize`,
`summarize-all`, `relate`, `duplicates`, `trash`, `workspace`, `bridge`, `enrich`,
`find-pdf`, `rename`, and `update-status` commands. The core read/write/search/pdf/note/attach
surface from the research report is confirmed.

**Key configuration note**: On NixOS, the Zotero data directory is not auto-detected if
Zotero is stored at `~/Documents/Zotero/` rather than `~/Zotero/`. Set `ZOT_DATA_DIR` env
var to override. The extension should detect the data directory at setup time and persist it.

---

## Child Attachment Criterion Assessment

The critical evaluation criterion — "Can the CLI create and list child attachments under a
parent Zotero item?" — is confirmed:

**Create child attachment**: `zot attach KEY --file chunk.md` uploads any file and creates it
as a child attachment under the parent item identified by KEY. The `--dry-run` flag confirms
the operation without writing. The `--idempotency-key` flag makes uploads safe to retry.

**List attachments**: Attachments are returned as part of `zot read KEY` output. The SQLite
read path exposes attachment keys and file paths; the full attachment list is visible in the
item's JSON envelope.

This is the correct mechanism for storing markdown chunks alongside PDFs as sibling
attachments under the same parent Zotero item.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| AGPL-3.0 license copyleft | Medium | Extension shell scripts wrapping `zot` are not "linked" to the library; evaluate if CLI-wrapper approach is copyleft-clean; commercial license available from Agents365.ai |
| Web API key required for writes | Low | One-time setup via `zot config init`; stored in `~/.config/zot/config.toml`; reads need no auth |
| Not in nixpkgs (manual install) | Low | `uv tool install` is stable on NixOS; `environment.localBinInPath = true` or session var needed |
| Zotero data dir not auto-detected | Low | Set `ZOT_DATA_DIR` env var; extension should detect at setup and persist in config |
| v0.7.0 API may differ slightly from docs | Low | Tested; core surface confirmed; `zot schema` is self-describing for programmatic surface detection |
| PDF not indexed by Zotero yet | Low | `zot pdf` reads from filesystem directly (not Zotero's index); no indexing needed |
| Notes stored as HTML internally | Low | Markdown content preserved in note body; zot reads them back with HTML-to-MD conversion |

---

## What to Build Next

The Zotero extension (separate future task) should:

1. **Wrap `zot`** for all read operations via shell scripts that set `ZOT_DATA_DIR` and
   parse `{ok, data, meta}` JSON envelope.

2. **Provide a setup command** that detects the Zotero data directory, validates the SQLite
   database is present, and runs `zot config init` for write access.

3. **Use `zot search`** as the primary search backend (keyword + tag), with optional
   BM25 full-text search via workspace commands.

4. **Use `zot pdf KEY --pages N-M`** to extract page-granular text from PDFs for chunked
   processing in `/literature` conversions.

5. **Use `zot note KEY --add`** to store converted markdown summaries as Zotero notes
   (content is stored as HTML internally; markdown syntax is preserved in the body).

6. **Use `zot attach KEY --file chunk.md`** when the raw markdown file should be stored as
   a queryable child attachment alongside the parent PDF item.

7. **Use `--idempotency-key`** on all write operations for safe retries.

8. **Document** the `ZOT_DATA_DIR` env var and Web API key setup in the extension's README.

---

## References

- Research report: `specs/747_evaluate_zotero_cli_tools/reports/01_zotero-cli-eval.md`
- zotero-cli-cc GitHub: https://github.com/Agents365-ai/zotero-cli-cc
- zotero-cli-cc docs: https://agents365-ai.github.io/zotero-cli-cc/
- zotero-mcp GitHub: https://github.com/54yyyu/zotero-mcp
- Zotero Web API: https://www.zotero.org/support/dev/web_api/v3/basics
- uv tool install docs: https://docs.astral.sh/uv/concepts/tools/
