# Research Report: Task #721 (Round 4) — Lectic Direct Integration vs Custom Implementation

**Task**: 721 - Design targeted literature retrieval
**Started**: 2026-06-15
**Completed**: 2026-06-15
**Focus**: Using Lectic directly for literature search vs reimplementing in bash
**Sources**: Lectic source code (installed at `/home/benjamin/.local/share/nvim/lazy/lectic/`), Neovim plugin files, Round 3 report

---

## Executive Summary

- **Lectic is already installed, functional, and Anthropic-capable**: The installed binary at `/home/benjamin/.nix-profile/bin/lectic` is a compiled v0.0.1 ELF from Nix with `--format` modes, full Anthropic SDK support, and a working Neovim plugin (`extra/lectic.nvim`). The existing Neovim integration needs only minor updates (model string, LSP autocommand).
- **Lectic's SQLite tool is architecturally ideal for literature search but cannot be used by Claude Code agents directly**: The SQLite tool runs inside a Lectic conversation — the LLM uses it as a tool call. Claude Code agents cannot invoke Lectic's SQLite tool without going through a full Lectic conversation, which adds LLM latency and API cost to every search.
- **The optimal architecture is Option C (hybrid)**: Use a shared `.literature.db` file. Claude Code agents query it directly via `sqlite3` CLI (bash scripts from Round 3). Users search interactively via Lectic `.lec` files in Neovim. Both paths benefit from the same FTS5 index built by `literature-build-index.sh`.
- **Lectic's SQLite patterns should inform the bash tool design**: Auto-introspected schema, YAML output, size limits, read-only mode, and atomic transactions are all directly applicable to the `literature-search.sh` bash script design — extract these patterns, do not replicate the Lectic dependency.
- **The `vim.g.lectic_model = "gpt-4"` setting is cosmetic only** in the current Neovim config; the actual model is set in each `.lec` file's YAML frontmatter. Changing it to `claude-opus-4-5` requires no code change, just updating the template in `lectic_extras.lua`.

---

## Current Lectic Setup Assessment

### Installation State

The Lectic ecosystem is in excellent shape:

| Component | Location | Status |
|-----------|----------|--------|
| `lectic` binary | `/home/benjamin/.nix-profile/bin/lectic` | Installed, v0.0.1, compiled ELF |
| Neovim plugin | `/home/benjamin/.local/share/nvim/lazy/lectic/extra/lectic.nvim/` | Installed, has `submit.lua`, `spinner.lua`, `highlight.lua` |
| Plugin spec | `lua/neotex/plugins/ai/lectic.lua` | Loaded, lazy on `ft = {"markdown", "lectic.markdown"}` |
| Utility functions | `lua/neotex/util/lectic_extras.lua` | `submit_selection()` and `create_new_file()` implemented |
| ftplugin | `after/ftplugin/lectic.markdown.lua` | Working: checkbox handling, markdown inheritance, fold state |
| LSP | `extra/lectic.nvim/plugin/lsp.lua` | Available, provides completions and diagnostics in `.lec` files |

### What Needs Updating

**Model configuration** (`lectic_extras.lua` template, line 142-150):
- Template sets `provider: anthropic` (correct) with `# model: claude-3-7-sonnet` commented out
- `vim.g.lectic_model = "gpt-4"` in `lectic.lua` line 52 is used only for the statusline display, not actual model selection
- To use Claude in practice: uncomment `model:` line in any `.lec` file frontmatter, or update the template default to `claude-opus-4-5` or `claude-sonnet-4-5`

**LSP autocommand** (minor): The `extra/lectic.nvim/plugin/lsp.lua` uses `pattern = { "lectic", "lectic.markdown", "markdown.lectic" }`. The ftplugin detection uses `lectic.markdown`. These match — no change needed.

**Plugin spec setup** (`lectic.lua`): The `init` function calls `vim.opt.runtimepath:append(...)` to add `extra/lectic.nvim`. The README recommends `vim.opt.rtp:append(plugin.dir .. "/extra/lectic.nvim")` in a config function. The current approach works but the LSP plugin at `extra/lectic.nvim/plugin/lsp.lua` may not auto-load as a Neovim plugin. Adding `vim.cmd("runtime! plugin/lsp.lua")` after the rtp append would ensure LSP is activated.

**Complete provider support**: The Lectic source (`src/backends/`) includes `anthropic.ts`, `gemini.ts`, `openai.ts`, `codex.ts` — Anthropic is fully supported. The `@anthropic-ai/sdk: ^0.72.1` is in `package.json`.

---

## Architecture Comparison

### Option A: Custom Bash Scripts (Round 3 Proposal)

**What it is**: `literature-build-index.sh` creates `.literature.db` from `index.json`. `literature-search.sh` is an agent-callable bash tool that runs FTS5 queries via `sqlite3`.

| Dimension | Assessment |
|-----------|-----------|
| **Performance** | Direct `sqlite3` invocation: ~5-10ms query time + ~200ms `nix-shell` startup (if using nix-shell). With `sqlite3` in PATH directly: ~5ms total. BM25 FTS5 gives excellent ranking. |
| **Agent integration** | Excellent: Claude Code agents call `bash literature-search.sh "query"` directly. No intermediary. Can be used in preflight, agent tools, or mid-conversation. |
| **Neovim integration** | None: Pure bash, no Neovim UI. User would view results in terminal or via `:!` command. |
| **Maintenance burden** | ~150-200 lines of bash for build + search scripts. Schema design done in Round 3. |
| **Portability** | Excellent: Works in any agent system (Claude Code, OpenCode, shell scripts). Only dependency is `sqlite3`. |
| **Elegance** | Good: Clean pipeline. Some bash quoting complexity for SQL injection prevention. |

### Option B: Lectic as the Search Layer

**What it is**: Agent formulates a `.lec` file with a SQLite tool pointing to `.literature.db`, then invokes `lectic` to run the query through an LLM that calls the SQLite tool.

| Dimension | Assessment |
|-----------|-----------|
| **Performance** | Poor for programmatic use: Every search requires an LLM API call (100-500ms minimum). FTS5 quality is identical to Option A (same database). The LLM formulates the SQL, adding latency and potential query errors. |
| **Agent integration** | Indirect: Claude Code cannot use Lectic's SQLite tool directly. It would have to pipe a `.lec` file to `lectic -f file.lec` and parse the output. This is a roundabout approach that adds an LLM-in-the-middle. |
| **Neovim integration** | Excellent: Users can open a literature `.lec` file, type a natural language query, and the Lectic Claude instance writes and executes SQL against the database. Streaming response, folded tool calls, beautiful UX. |
| **Maintenance burden** | Low: Just a `.lec` template file. No bash scripts. But heavily dependent on Lectic being installed, Anthropic API key being available, and Lectic's interface not changing. |
| **Portability** | Poor: Only works where Lectic is installed. Claude Code agents on CI, other machines, or other agent systems cannot use it. |
| **Elegance** | High for human use, low for programmatic use. Two different LLMs (Lectic's Claude and Claude Code's Claude) talking about the same database is architecturally awkward for automation. |

**Critical limitation of Option B**: Lectic's SQLite tool is invoked _by_ the LLM running inside a Lectic conversation. The tool call flow is: `user input -> Lectic -> LLM decides to query -> SQLite tool -> LLM formats result -> user sees output`. Claude Code agents would have to spawn a subprocess running a full Lectic conversation to access this, paying LLM API costs just to run a SQL query. This is fundamentally wrong for automated retrieval.

### Option C: Hybrid — Lectic for Interactive, Bash for Programmatic (Recommended)

**What it is**: The same `.literature.db` file serves two different clients:
1. **Claude Code agents** use `literature-search.sh` (bash + `sqlite3` CLI) — fast, no API cost
2. **Users in Neovim** open `literature-search.lec` with a SQLite tool — natural language queries, beautiful streaming output

Both rebuild from `index.json` via `literature-build-index.sh` if stale.

| Dimension | Assessment |
|-----------|-----------|
| **Performance** | Best of both: Agents get 5-10ms bash queries. Users get LLM-quality natural language parsing with FTS5 precision. |
| **Agent integration** | Excellent (same as Option A for agents). |
| **Neovim integration** | Excellent (same as Option B for humans). |
| **Maintenance burden** | Slightly higher than A or B alone: need both bash scripts AND a `.lec` template. But the shared `.db` eliminates duplication — one build step serves both. |
| **Portability** | Agent path (bash) works everywhere. Lectic path requires Lectic installation. The user already has Lectic installed. |
| **Elegance** | High: Clean separation of concerns. SQL queries go straight to the database when an agent needs speed; go through a helpful LLM when a human needs natural language interaction. |

---

## Performance Analysis

### Query Latency Breakdown

For a 183-entry corpus with a ~1MB `.db` file:

| Operation | Time Estimate | Notes |
|-----------|---------------|-------|
| SQLite FTS5 MATCH query | 1-3ms | In-memory B-tree lookup, trivial for 183 entries |
| `sqlite3` CLI startup | 2-5ms | Minimal shared library load |
| `nix-shell -p sqlite` wrapper | ~200ms | Shell spawn + Nix evaluation overhead |
| Lectic conversation startup | 800-1500ms | Bun runtime + LLM API round trip |
| BM25 ranking computation | <1ms | Built into FTS5 index scan |
| YAML result serialization | <1ms | Lectic's output format, trivially fast |

**Key insight**: The `nix-shell` overhead identified in Round 3 is the main bottleneck for Option A, not the SQLite query itself. If `sqlite3` can be added to the NixOS system packages (or the user's PATH), the bash search tool drops from ~200ms to ~7ms total. Lectic's LLM overhead makes it 100-200x slower than direct sqlite3 for the query phase.

### Search Quality

For a 183-entry corpus, both paths use the **identical** FTS5 BM25 index. Search quality is determined entirely by the database schema (columns, weights, tokenizer) — not by whether the SQL is written by a bash script or by Lectic's LLM. The BM25 ranking from Round 3 (title×10, keywords×5, abstract×3, summary×2, content×1) applies equally to both.

**Lectic's LLM formulates better queries for ambiguous cases**: When a user types a natural language phrase like "papers about what makes formulas have first-order correspondents", a Lectic-hosted Claude can translate this to `literature_fts MATCH 'Sahlqvist correspondence frame definability'` with appropriate column filters. A bash script would need the user to already know the right search terms. This is the key UX advantage of Option B/C for interactive human use.

### The sqlite3 Path Optimization

Round 3 flagged `nix-shell -p sqlite` overhead (~200ms). The optimization is simple: check if `sqlite3` is in PATH first:

```bash
if command -v sqlite3 > /dev/null 2>&1; then
    sqlite3 "$DB" "$SQL_QUERY"
else
    nix-shell -p sqlite --run "sqlite3 '$DB' '$SQL_QUERY'"
fi
```

On the user's NixOS system, `sqlite3` can be added to `environment.systemPackages` or `home.packages` to eliminate this overhead entirely. This should be part of the implementation plan.

---

## Recommended Architecture

**Option C: Hybrid** — shared `.literature.db`, two access paths.

### Implementation Plan Changes from Round 3

Round 3 proposed bash-only scripts. The hybrid architecture adds:

**New artifact**: `specs/literature/literature-search.lec` — a Lectic conversation template for interactive literature search within Neovim. This file contains:
```yaml
---
interlocutor:
  name: Literature Search
  prompt: |
    You are a literature search assistant with access to an indexed database
    of academic papers and books on logic, modal logic, and formal reasoning.
    
    When the user asks about literature, formulate SQL queries against the
    database using the lit_search tool. Prefer FTS5 MATCH queries with BM25
    ranking for relevance-ordered results. Start with a broad search, then
    narrow using column filters or parent_id hierarchy.
    
    For cross-vocabulary queries (e.g., "papers about frame correspondence"),
    expand to related terms: 'correspondence OR definability OR Sahlqvist'.
    
    After finding relevant documents, present: title, authors, year, doc_type,
    token_count, and a snippet. Ask the user if they want to read the full
    document before providing the path.
  provider: anthropic
  model: claude-sonnet-4-5
  tools:
    - sqlite: ~/Projects/Literature/.literature.db
      name: lit_search
      readonly: true
      limit: 15000
      details: >
        FTS5-indexed literature database. Use literature_fts for ranked search.
        Schema is auto-introspected. Key tables: documents (id, title, authors,
        year, doc_type, depth, parent_id, path, token_count), doc_metadata
        (doc_id, keywords, summary, abstract), literature_fts (virtual, FTS5).
        BM25 weights: title(10), keywords(5), abstract(3), summary(2), content(1).
---
```

**No changes to bash scripts**: The `literature-build-index.sh` and `literature-search.sh` from Round 3 remain as specified. They become the agent automation path.

**New Neovim keybinding**: Add to which-key or lectic-specific mappings:
- `<leader>ml` — Open literature search `.lec` file (mapped to `LecticOpenLitSearch`)
- This requires a new user command in `lectic_extras.lua` that opens the template `.lec` file

**Fixing `vim.g.lectic_model`**: Update to `claude-sonnet-4-5` and update the template in `create_new_file()`. This is a 2-line change with no functional impact.

---

## Implementation Implications

### What Changes from Round 3

Round 3 specified a bash-only implementation. The hybrid adds:

1. **One new file**: `specs/literature/literature-search.lec` (the Lectic template)
2. **One new user command** in `lectic_extras.lua`: `LecticOpenLitSearch` that opens the `.lec` template
3. **One new keymap** for opening the literature search conversation
4. **Minor `lectic.lua` update**: Change `vim.g.lectic_model` display string; update `create_new_file()` template to default to `claude-sonnet-4-5`

### What Does NOT Change from Round 3

- `literature-build-index.sh` — unchanged (builds the shared `.db`)
- `literature-search.sh` — unchanged (agent bash tool)
- `.literature.db` schema — unchanged (FTS5, 3-table design, BM25 weights)
- `index.json` as source of truth — unchanged
- The `--lit` preflight injection — unchanged
- The two-tier global/local architecture — unchanged

### Priority Order

1. **Immediate**: Fix Lectic Neovim config (model string, LSP activation) — 15 minutes
2. **Tier 1**: Implement bash scripts from Round 3 (`literature-build-index.sh`, `literature-search.sh`) — 4-6 hours
3. **Tier 2**: Create `literature-search.lec` template for Neovim interactive use — 30 minutes
4. **Tier 3**: Add `LecticOpenLitSearch` command and keymap — 15 minutes
5. **Optimization**: Add `sqlite3` to NixOS system packages to eliminate `nix-shell` overhead — 5 minutes

The Neovim Lectic integration is nearly free given the existing setup. The bash scripts are the substantive work.

---

## Open Questions

1. **sqlite3 in PATH**: Should `sqlite3` be added to `environment.systemPackages` in the Nix config? This eliminates the `nix-shell` ~200ms overhead and is strongly recommended. This is a separate Nix task but should be noted as a dependency.

2. **`.lec` template location**: Where should `literature-search.lec` live? Options: (a) `specs/literature/` (per-project, user-maintained), (b) `~/.config/lectic/` (user-global, available everywhere), (c) as a Lectic "kit" in the global config. Recommendation: `~/Projects/Literature/literature-search.lec` alongside the database.

3. **LSP activation in current config**: The current `lectic.lua` appends `extra/lectic.nvim` to runtimepath in `init` but does not source the LSP plugin file. The `plugin/lsp.lua` may not auto-execute unless the rtp append happens before Neovim loads plugins. Testing needed.

4. **Abstract coverage**: Still open from Round 3 — how many of the 183 entries have Zotero abstracts via `bib_key`? This affects FTS5 cross-vocabulary recall quality.

5. **Interactive `.lec` conversations vs one-shot queries**: For the Lectic path, should the literature search be a persistent conversation (the user asks follow-up questions) or a fresh query each time? The Lectic UX is naturally conversational — a single `.lec` file can accumulate multiple search sessions. This is actually a feature, not a bug.

---

## Sources

1. `/home/benjamin/.local/share/nvim/lazy/lectic/src/tools/sqlite.ts` — SQLite tool implementation: schema introspection, YAML output, size limits, read-only mode, atomic transactions, CST-based SQL safety checking
2. `/home/benjamin/.local/share/nvim/lazy/lectic/extra/lectic.nvim/README.md` — Lectic Neovim plugin: features, requirements, configuration, keymaps, hook integration
3. `/home/benjamin/.local/share/nvim/lazy/lectic/extra/lectic.nvim/lua/lectic/submit.lua` — Plugin submit function: `vim.system({"lectic", "-s"}, ...)` with streaming stdout, NVIM env var
4. `/home/benjamin/.local/share/nvim/lazy/lectic/CHANGELOG.md` — v0.0.1 (2026-02-03): A2A support, built-in directives, SQLite hardening, MCP streamable HTTP
5. `/home/benjamin/.local/share/nvim/lazy/lectic/src/backends/anthropic.ts` — Anthropic backend with `@anthropic-ai/sdk ^0.72.1`
6. `/home/benjamin/.local/share/nvim/lazy/lectic/src/generateCmd.ts` — CLI flow: stdin reading, `--format` modes, MCP initialization, streaming output
7. `/home/benjamin/.local/share/nvim/lazy/lectic/package.json` — Dependencies: Anthropic SDK, Gemini, OpenAI, MCP SDK v1.25.0
8. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/lectic.lua` — Current Neovim plugin spec (lazy, ft/cmd triggers, `vim.g.lectic_model = "gpt-4"`)
9. `/home/benjamin/.config/nvim/lua/neotex/util/lectic_extras.lua` — `submit_selection()` and `create_new_file()` with `.lec` YAML template
10. `/home/benjamin/.config/nvim/after/ftplugin/lectic.markdown.lua` — ftplugin: markdown inheritance, fold state, checkbox handling
11. `specs/721_design_targeted_literature_retrieval/reports/03_sqlite-lectic-indexing.md` — Round 3: FTS5 schema design, bash script specifications, Lectic pattern analysis
