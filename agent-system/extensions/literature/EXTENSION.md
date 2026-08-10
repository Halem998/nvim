## Literature Extension

Version 2.0.0. Unified management of the global Literature/ repository (`~/Projects/Literature/`)
and per-repo sub-indices (`specs/literature-index.json`): source discovery, PDF/DJVU conversion,
FTS5-backed search, agent context briefing, and Zotero integration.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-literature | (direct execution) | Scan, convert, validate, index, discover, and integrate literature |
| skill-cite | (direct execution) | Verify citation claims against Literature/ and Zotero |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/literature` | `/literature` | Show status and index health (Mode B) |
| `/literature` | `/literature N` | Discover sources relevant to task N (Mode A) |
| `/literature` | `/literature "query"` | Discover sources matching a query (Mode A) |
| `/literature` | `/literature ~/path/to/file.pdf` | Ingest a specific PDF/DJVU (Mode B) |
| `/literature` | `/literature ~/dir/` | Ingest all PDFs in a directory (Mode B) |
| `/literature` | `/literature --validate` | Validate the sub-index against the global index |
| `/cite` | `/cite N` | Verify all citations in task N artifacts |
| `/cite` | `/cite N --gaps` | Also flag citations found in Zotero but lacking a PDF |

### Context Pointers

- @context/project/literature/domain/literature-index.md — global/per-repo index schemas, repo layout
- @context/project/literature/patterns/literature-command-modes.md — two-mode `/literature`, discovery tiers
- @context/project/literature/patterns/agent-exploration.md — `--lit` briefing+tools pattern, corpus navigation
- @context/project/literature/tools/zotero-scripts.md — Zotero script inventory, setup, and related pointers
- @context/project/literature/domain/format-decision.md — markdown retained as the sole convert/chunk/index format
