# Research Report: Task #184

**Task**: 184 - revise_learn_command_input_modes
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T00:30:00Z
**Effort**: 4-6 hours estimated for implementation
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, web research on chunking strategies and MCP tools
**Artifacts**: specs/184_revise_learn_command_input_modes/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The current /learn command supports text, single file, and --task N modes but lacks recursive directory scanning, content mapping, MCP-based memory deduplication, and topic-based memory organization
- The MCP server (`@dsebastien/obsidian-cli-rest-mcp`) uses a two-tool pattern (search + execute) that wraps Obsidian CLI commands including `search`, `read`, `files`, `append`, and `write` operations
- Content mapping for large inputs should use a semantic chunking approach: split content by natural topic boundaries (headings, blank-line-delimited sections), then summarize each chunk before deciding on memory granularity
- Memory deduplication should use `search` (MCP) or grep-based fallback to find existing related memories, then present update/extend/create options
- Memories should follow a "one topic, one memory" principle with explicit topic tags in frontmatter to prevent bloat

## Context and Scope

This research extends research-001.md by addressing the user's specific requirements:

1. **Recursive subdirectory scanning** for directory inputs
2. **ANY text-based file** detection (not just hardcoded extensions)
3. **Content mapping** - create a structured map of input content before memory creation
4. **MCP memory search** integration - use the same tool as --remember to find related existing memories
5. **Memory revision/extension** - revise or extend existing memories instead of always creating new ones
6. **Topic-based organization** - keep memories focused and single-topic to prevent bloat

## Findings

### 1. MCP Server Tool Architecture

The `@dsebastien/obsidian-cli-rest-mcp` server does NOT expose individual tools like `search_notes`, `read_note` etc. as separate MCP tools. Instead it uses a **Code Mode two-tool pattern**:

| MCP Tool | Purpose |
|----------|---------|
| `search` | Discover available Obsidian CLI commands by name, description, or category |
| `execute` | Run any discovered CLI command by name with parameters |

The underlying Obsidian CLI commands accessible via `execute` include:

| CLI Command | Category | Description |
|-------------|----------|-------------|
| `search` | Search | Full-text search across vault |
| `search:context` | Search | Search with surrounding line context |
| `read` | Files | Read file contents |
| `write` / `create` | Files | Create or overwrite a file |
| `append` | Files | Append content to a file |
| `prepend` | Files | Add content after frontmatter |
| `files` | Files | List all vault files |
| `folders` | Files | List all vault folders |
| `links` | Links | Get outgoing links from a note |
| `backlinks` | Links | Get incoming backlinks to a note |

**Implication for /learn**: The existing docs reference `search_notes` which is actually the `search` command executed via the MCP `execute` tool. The revised /learn command should use:
- `execute("search", {query: keywords})` to find related memories
- `execute("read", {path: memory_path})` to read full memory content
- `execute("write", {path: new_path, content: memory_content})` to create memories (alternative to direct file write)

**Graceful degradation**: When MCP is unavailable, fall back to `grep -r` on `.memory/10-Memories/` for search, and direct file I/O for read/write.

### 2. Recursive Directory Scanning Design

The user explicitly wants recursive subdirectory scanning and inclusion of ANY text-based file.

#### Text File Detection Strategy

Rather than a hardcoded extension whitelist, use a two-tier detection approach:

**Tier 1 - Extension whitelist** (fast, covers 95% of cases):
```
*.md *.txt *.lua *.py *.sh *.bash *.zsh *.fish
*.js *.ts *.jsx *.tsx *.json *.yaml *.yml *.toml
*.xml *.html *.css *.scss *.less *.svg
*.rs *.go *.java *.kt *.c *.cpp *.h *.hpp
*.rb *.pl *.php *.r *.jl *.lean *.typ *.tex *.bib
*.vim *.el *.lisp *.clj *.hs *.ml *.ex *.exs
*.nix *.conf *.cfg *.ini *.env *.dockerfile
*.sql *.graphql *.proto *.cmake *.makefile
```

**Tier 2 - Content sniffing** (for extensionless files or unknown extensions):
```bash
# Use file command to check if file is text
file --mime-type "$filepath" | grep -q "text/"
```

**Exclusion patterns** (always skip):
```
.git/ .obsidian/ node_modules/ __pycache__/ .cache/
*.png *.jpg *.jpeg *.gif *.bmp *.ico *.webp
*.pdf *.doc *.docx *.xls *.xlsx *.ppt
*.zip *.tar *.gz *.bz2 *.7z *.rar
*.exe *.dll *.so *.dylib *.o *.a
*.wasm *.pyc *.class *.jar
```

#### Scanning Implementation

```bash
# Recursive scan with text file detection
find "$directory" -type f \
  ! -path '*/.git/*' \
  ! -path '*/.obsidian/*' \
  ! -path '*/node_modules/*' \
  ! -path '*/__pycache__/*' \
  | while read -r filepath; do
    # Tier 1: check extension
    if is_known_text_extension "$filepath"; then
      echo "$filepath"
    # Tier 2: content sniff for unknown extensions
    elif file --mime-type "$filepath" 2>/dev/null | grep -q "text/"; then
      echo "$filepath"
    fi
  done | sort
```

#### Size Limits

- **Per-file limit**: Skip files larger than 100KB (configurable) - large files are unlikely to be good memory candidates as-is
- **Total file count warning**: If >50 files found, show count and suggest narrowing the path
- **Total content limit**: If combined content exceeds 500KB, warn and suggest processing in batches

### 3. Content Mapping Strategy

For any input (file, directory, or text), the /learn command should create a **content map** before deciding what memories to create. This is the key architectural change from the current design.

#### Content Map Structure

A content map is an intermediate representation that breaks input into **topic segments**:

```
Content Map:
  source: "/path/to/directory" (or file, or "user input")
  segments:
    - id: 1
      topic: "Neovim keymap configuration"
      source_file: "keymaps.lua"
      source_lines: "1-45"
      summary: "Defines leader key bindings for telescope, LSP, and diagnostics"
      estimated_tokens: 350
      key_terms: ["keymap", "telescope", "LSP", "diagnostics", "leader"]
    - id: 2
      topic: "Plugin lazy loading patterns"
      source_file: "plugins/init.lua"
      source_lines: "1-30"
      summary: "Configures lazy.nvim with VeryLazy event for deferred loading"
      estimated_tokens: 200
      key_terms: ["lazy.nvim", "VeryLazy", "event", "plugin"]
```

#### Segmentation Algorithm

**For structured files** (markdown with headings, code with clear sections):
1. Split at heading boundaries (## or ### for markdown)
2. Split at blank-line-delimited blocks for code files
3. Each segment becomes a candidate topic

**For unstructured text**:
1. Split at paragraph boundaries (double newlines)
2. Group consecutive paragraphs that share keyword overlap (>30% common terms)
3. Each group becomes a candidate topic

**For directories**:
1. Each file is initially one segment
2. Files with shared naming patterns or directory grouping are clustered
3. Very large files are further split at heading/section boundaries

#### Chunk Size Guidance (from 2026 RAG benchmarks)

- Target memory size: 200-500 tokens (roughly 150-400 words)
- Memories under 100 tokens lack context; over 800 tokens become multi-topic
- Semantic chunking aligned to topic boundaries achieves 87% retrieval accuracy vs 13% for fixed-size (per clinical decision support study, 2025)
- Recommended default: split at natural boundaries, merge tiny segments (<100 tokens) with adjacent same-topic segments

### 4. MCP Memory Search Integration

The /learn command should use the SAME search mechanism as /research --remember to find related memories. Currently /research uses:

```
# From research.md Step 5:
# Build search query from task description keywords
# Use MCP tool: search_notes (actually: execute("search", ...))
# Query: extracted keywords, Limit: 5 results
# Read top 3 memories for full content
```

#### Search Strategy for /learn

For EACH content map segment:

1. **Extract key terms**: Take 3-5 most significant terms from the segment (nouns, technical terms, unique identifiers)
2. **Search existing memories**:
   - **MCP path**: `execute("search", {query: "term1 term2 term3"})`
   - **Fallback path**: `grep -l -i "term1\|term2\|term3" .memory/10-Memories/*.md | sort | uniq -c | sort -rn | head -5`
3. **Score relevance**: Count keyword overlap between segment and each found memory
4. **Classify relationship**:
   - **High overlap (>60% terms match)**: This segment covers a topic already in memory -> suggest UPDATE
   - **Medium overlap (30-60%)**: Related but distinct -> suggest EXTEND existing memory with new section
   - **Low overlap (<30%)**: New topic -> suggest CREATE new memory
   - **No matches**: Definitely new -> suggest CREATE

#### Presenting Search Results

For each segment, show:
```
Segment 1: "Neovim keymap configuration" (350 tokens)
  Related memories found:
  - [HIGH] MEM-2026-03-05-042: "Lua keymap patterns" (85% overlap)
    -> Recommended: UPDATE existing memory
  - [LOW] MEM-2026-03-04-015: "Plugin configuration" (20% overlap)
    -> Recommended: CREATE new memory

  Actions:
  [ ] Update MEM-2026-03-05-042 with this content
  [ ] Create new memory
  [ ] Skip this segment
```

### 5. Memory Revision/Extension Logic

The current /learn command offers "Add as new" or "Update existing" but the update is a simple append. The revised system should support three distinct operations:

#### Operation 1: UPDATE (replace/rewrite)

When a segment covers the SAME topic as an existing memory but with newer/better information:
- Read existing memory content
- Present both old and new content side by side (or merged preview)
- Replace the content section while preserving frontmatter (id, date created, tags)
- Add `last_updated: {date}` to frontmatter
- Preserve the `## Connections` section

#### Operation 2: EXTEND (add section)

When a segment adds NEW INFORMATION to an existing topic:
- Read existing memory
- Append a new dated section:
  ```markdown
  ## Extension ({date})

  {new content}
  ```
- Update tags if new topics are introduced
- Update `last_updated` in frontmatter

#### Operation 3: CREATE (new memory)

When a segment covers a genuinely new topic:
- Generate new memory ID
- Use memory template
- Assign topic-based tags
- Add to index under appropriate category

#### Decision Heuristic

```
IF segment_overlap_with_existing > 60%:
  IF segment is more comprehensive than existing:
    -> Suggest UPDATE (replace)
  ELSE:
    -> Suggest EXTEND (append section)
ELIF segment_overlap_with_existing > 30%:
  -> Suggest EXTEND or CREATE (user chooses)
ELSE:
  -> Suggest CREATE
```

### 6. Topic-Based Memory Organization

The current system has 5 classification categories ([TECHNIQUE], [PATTERN], [CONFIG], [WORKFLOW], [INSIGHT]) but no topic-based organization. The user wants memories organized by content topic to prevent bloat.

#### Proposed Topic Tag System

Add a `topic` field to memory frontmatter (distinct from `tags` which holds classification):

```yaml
---
id: MEM-2026-03-11-001
title: "Neovim Keymap Configuration Patterns"
date: 2026-03-11
tags: [PATTERN]
topic: "neovim/keymaps"
source: "directory: nvim/lua/neotex/core/"
last_updated: 2026-03-11
---
```

#### Topic Hierarchy

Topics use a slash-separated hierarchy for natural grouping:

```
neovim/
  neovim/keymaps
  neovim/plugins
  neovim/lsp
  neovim/treesitter
lua/
  lua/error-handling
  lua/module-patterns
  lua/testing
meta/
  meta/agent-patterns
  meta/state-management
  meta/command-design
```

#### Topic Inference

When creating a memory from a content segment, infer topic from:
1. **Directory path** of source file (e.g., `nvim/lua/neotex/plugins/` -> `neovim/plugins`)
2. **Keyword analysis** of content (e.g., mentions of `vim.keymap.set` -> `neovim/keymaps`)
3. **Existing memory topics** that overlap (inherit topic from related memory)
4. **User override**: Present inferred topic but allow user to change it

#### Index Organization by Topic

Update `index.md` to group by topic instead of (or in addition to) classification:

```markdown
## By Topic

### neovim/keymaps
- [Keymap Configuration Patterns](../10-Memories/MEM-2026-03-11-001.md)
- [Leader Key Bindings](../10-Memories/MEM-2026-03-10-005.md)

### neovim/plugins
- [Lazy Loading with lazy.nvim](../10-Memories/MEM-2026-03-09-012.md)

### lua/error-handling
- [pcall Patterns](../10-Memories/MEM-2026-03-08-003.md)
```

### 7. Revised /learn Command Workflow

The complete revised workflow integrating all findings:

```
/learn <input>
  |
  v
[1. Parse Input Mode]
  --task N    -> Task mode (existing, unchanged)
  directory   -> Directory mode (new)
  file        -> File mode (enhanced)
  text        -> Text mode (enhanced)
  |
  v
[2. Content Acquisition]
  Task mode:    Scan specs/{NNN}_*/  for artifacts
  Directory:    Recursive scan with text detection (Tier 1 + Tier 2)
  File:         Read single file
  Text:         Use raw text
  |
  v
[3. Content Mapping]
  Split content into topic segments
  For each segment: extract key terms, estimate size
  Present content map summary to user
  |
  v
[4. Memory Search (MCP or fallback)]
  For each segment:
    Search existing memories using key terms
    Score overlap: HIGH (>60%), MEDIUM (30-60%), LOW (<30%)
    Classify: UPDATE / EXTEND / CREATE
  |
  v
[5. Present Plan with Interactive Selection]
  Show each segment with:
    - Topic summary
    - Related existing memories
    - Recommended action (update/extend/create)
  User selects/modifies actions per segment
  |
  v
[6. Execute Memory Operations]
  For UPDATE: Rewrite memory content, preserve metadata
  For EXTEND: Append dated section to existing memory
  For CREATE: Generate new memory with topic tag
  |
  v
[7. Update Index]
  Add/update entries in index.md
  Group by topic hierarchy
  Update statistics
  |
  v
[8. Git Commit]
  Stage .memory/ changes
  Commit with descriptive message
```

### 8. Files Requiring Modification

| File | Changes | Effort |
|------|---------|--------|
| `.opencode/extensions/memory/commands/learn.md` | Add directory mode detection, restructure argument parsing for 4 modes, add content mapping step | Medium |
| `.opencode/extensions/memory/skills/skill-memory/SKILL.md` | Add directory mode execution, content mapping algorithm, MCP search integration, update/extend/create operations, topic inference | High |
| `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` | Add `topic` and `last_updated` fields to template | Low |
| `.opencode/extensions/memory/data/.memory/20-Indices/index.md` | Add "By Topic" section structure | Low |
| `.opencode/extensions/memory/EXTENSION.md` | Update command table, document new modes | Low |
| `.opencode/extensions/memory/context/project/memory/learn-usage.md` | Full rewrite with new workflow documentation | Medium |
| `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` | Update /learn examples | Low |

## Decisions

1. **Two-tier text detection**: Extension whitelist first, `file --mime-type` fallback for unknown extensions. This balances speed with completeness.
2. **Content mapping as intermediate step**: All input modes produce a content map before memory operations. This is the architectural keystone that enables intelligent deduplication.
3. **MCP search reuse**: Use the same search mechanism as /research --remember (execute("search", ...)) for memory deduplication. Fallback to grep when MCP unavailable.
4. **Three memory operations**: UPDATE (replace), EXTEND (append section), CREATE (new). Current system only has add/append.
5. **Topic tags in frontmatter**: New `topic` field with slash-separated hierarchy. Distinct from classification `tags`.
6. **100KB per-file limit**: Skip files larger than 100KB during directory scanning. Configurable.
7. **Segment size target**: 200-500 tokens per memory. Merge tiny segments, split large ones at topic boundaries.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Content mapping adds complexity and latency | Medium | Make it lightweight - heading/section detection, not full NLP. Skip for small inputs (<500 tokens) |
| MCP server unavailable during search | Low | Grep-based fallback already works for keyword search. Degrade gracefully. |
| Topic inference incorrect | Low | Always show inferred topic and let user override. Learn from corrections over time. |
| Very large directories (1000+ files) | Medium | Hard limit at 200 files with warning. Suggest narrowing path. |
| Memory UPDATE destroys valuable old content | High | Before UPDATE, append old content to a `## History` section or create a backup in 00-Inbox/ |
| Overlap scoring too aggressive (merges unrelated memories) | Medium | Conservative threshold (60% for UPDATE). Always require user confirmation. |

## Appendix

### Search Queries Used

- "dsebastien obsidian-cli-rest-mcp search_notes tool parameters MCP"
- "@dsebastien/obsidian-cli-rest-mcp MCP tools list search read write"
- "content chunking strategies LLM memory systems topic segmentation 2025 2026"
- "text file detection by extension mime type recursive directory scanning"

### References

- [Obsidian CLI REST MCP - Command Reference](https://developassion.gitbook.io/obsidian-cli-rest-mcp/command-reference)
- [dsebastien/obsidian-cli-rest GitHub](https://github.com/dsebastien/obsidian-cli-rest)
- [MarkusPfundstein/mcp-obsidian GitHub](https://github.com/MarkusPfundstein/mcp-obsidian)
- [Weaviate - Chunking Strategies for RAG](https://weaviate.io/blog/chunking-strategies-for-rag)
- [Firecrawl - Best Chunking Strategies for RAG 2026](https://www.firecrawl.dev/blog/best-chunking-strategies-rag)
- [Redis - LLM Chunking](https://redis.io/blog/llm-chunking/)
- [Pinecone - Chunking Strategies for LLM Applications](https://www.pinecone.io/learn/chunking-strategies/)

### Key Codebase Files Examined

- `.opencode/commands/research.md` - --remember flag implementation (Step 5)
- `.opencode/extensions/memory/commands/learn.md` - Current /learn command
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Current skill implementation
- `.opencode/extensions/memory/EXTENSION.md` - Extension manifest with MCP tool list
- `.opencode/extensions/memory/manifest.json` - MCP server configuration
- `.opencode/extensions/memory/settings-fragment.json` - MCP connection settings
- `.opencode/extensions/memory/context/project/memory/memory-setup.md` - MCP setup guide
- `.opencode/extensions/memory/context/project/memory/learn-usage.md` - Current usage guide
- `.opencode/extensions/memory/context/project/memory/memory-troubleshooting.md` - Known limitations
- `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` - Cross-feature examples
- `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Memory template
- `.opencode/extensions/memory/data/.memory/20-Indices/index.md` - Current index structure
- `.opencode/commands/fix.md` - Pattern for directory/path handling

## Next Steps

Run `/plan 184` to create an implementation plan based on these findings.
