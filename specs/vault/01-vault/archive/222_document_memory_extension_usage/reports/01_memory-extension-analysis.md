# Research Report: Task #222

**Task**: 222 - document_memory_extension_usage
**Started**: 2026-03-17T00:00:00Z
**Completed**: 2026-03-17T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (extensions/memory/*)
**Artifacts**: specs/222_document_memory_extension_usage/reports/01_memory-extension-analysis.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The memory extension provides an Obsidian-compatible vault for storing and retrieving project knowledge
- It integrates with Claude Code via the `/learn` command and optional MCP server for advanced search
- The system uses a three-operation model (UPDATE, EXTEND, CREATE) based on overlap scoring with existing memories
- Key features include content mapping/segmentation, topic-based organization, and graceful degradation when MCP is unavailable

## Context and Scope

This research analyzed the complete memory extension at `.claude/extensions/memory/` to understand:
1. Architecture and component organization
2. Integration points with Claude Code
3. Usage patterns and workflows
4. Configuration requirements
5. User expectations

## Findings

### 1. Extension Architecture

The memory extension follows the standard extension structure:

```
.claude/extensions/memory/
+-- manifest.json           # Extension metadata and MCP config
+-- EXTENSION.md            # Content merged into CLAUDE.md
+-- index-entries.json      # Context discovery entries
+-- README.md               # Navigation overview
+-- commands/
|   +-- learn.md           # /learn command definition
+-- skills/
|   +-- skill-memory/
|       +-- SKILL.md       # Core memory skill implementation
+-- context/
|   +-- project/memory/
|       +-- learn-usage.md              # Usage guide
|       +-- memory-setup.md             # MCP configuration
|       +-- memory-troubleshooting.md   # Troubleshooting
|       +-- knowledge-capture-usage.md  # Example workflows
+-- data/
    +-- .memory/            # Vault skeleton structure
        +-- 00-Inbox/
        +-- 10-Memories/
        +-- 20-Indices/
        +-- 30-Templates/
```

### 2. Core Components

#### 2.1 manifest.json

Defines the extension metadata:
- **name**: "memory"
- **version**: "1.0.0"
- **provides**: Commands (learn.md), Skills (skill-memory), Context (project/memory), Data (.memory)
- **mcp_servers**: Configures `obsidian-memory` MCP server using `@anthropic-ai/obsidian-claude-code-mcp@latest` on WebSocket port 22360

#### 2.2 /learn Command

Four input modes:
1. **Text mode**: `/learn "text content"` - Add quoted text directly
2. **File mode**: `/learn /path/to/file` - Add file content
3. **Directory mode**: `/learn /path/to/dir/` - Scan directory recursively
4. **Task mode**: `/learn --task N` - Review task artifacts

#### 2.3 skill-memory (Direct Execution Skill)

The core skill handles:
- Content mapping (segmentation by file type)
- Memory search (MCP or grep fallback)
- Three memory operations based on overlap scoring:
  - **UPDATE** (>60% overlap): Replace memory content, preserve history
  - **EXTEND** (30-60% overlap): Append dated section
  - **CREATE** (<30% overlap): New memory file
- Index maintenance (category and topic sections)

**Critical**: The skill enforces mandatory user interaction via AskUserQuestion for every segment. It will not write to disk without explicit user confirmation.

### 3. Memory Vault Structure

The vault at `.memory/` (project root) uses Obsidian-compatible format:

```
.memory/
+-- .obsidian/           # Obsidian app configuration
+-- 00-Inbox/            # Quick capture (unused in current implementation)
+-- 10-Memories/         # Stored memory entries (MEM-*.md files)
+-- 20-Indices/          # index.md for navigation
+-- 30-Templates/        # memory-template.md for new entries
```

#### Memory File Format

```yaml
---
title: "Memory Title"
created: YYYY-MM-DD
tags: tag1, tag2, tag3
topic: "hierarchical/topic/path"
source: "user input" or "file: /path"
modified: YYYY-MM-DD
---

# Memory Title

Content here...

## Connections
<!-- Links to related memories using [[filename]] syntax -->
```

#### Naming Convention

Files follow `MEM-{semantic-slug}.md` pattern for grep discoverability.

### 4. MCP Integration

Two MCP server options supported:

| Server | Connection | Requirements |
|--------|------------|--------------|
| obsidian-claude-code-mcp | WebSocket :22360 | Obsidian + plugin |
| @dsebastien/obsidian-cli-rest-mcp | HTTP REST :27124 | Obsidian + Local REST API |

**MCP Tools Available**:
- `search`: Search memories by keywords
- `read`: Retrieve full memory content
- `write`: Create new memory
- `list`: Enumerate all memories

**Graceful Degradation**: When MCP unavailable, falls back to grep-based search:
```bash
grep -l -i "$keyword" .memory/10-Memories/*.md 2>/dev/null
```

### 5. Content Mapping System

Input over 500 tokens is segmented based on file type:
- **Markdown**: Split at heading boundaries
- **Code**: Split at function/class boundaries
- **Text**: Split at paragraph boundaries

Each segment produces:
- Unique ID (seg-NNN)
- Inferred topic path
- Summary (1-2 sentences)
- Key terms (3-5 terms for matching)
- Estimated token count

### 6. Topic Organization

Memories use hierarchical topic paths in frontmatter:
```yaml
topic: "neovim/plugins/telescope"
```

Topic inference priority:
1. Source directory path
2. Keyword analysis
3. Related memory topics
4. User confirmation/override

Index.md maintains both "By Category" and "By Topic" sections.

### 7. Classification Taxonomy (Task Mode)

When reviewing task artifacts, segments are classified:
- **[TECHNIQUE]**: Reusable method or approach
- **[PATTERN]**: Design or implementation pattern
- **[CONFIG]**: Configuration or setup knowledge
- **[WORKFLOW]**: Process or procedure
- **[INSIGHT]**: Key learning or understanding

### 8. Research Integration

The `--remember` flag on `/research N` enables memory-augmented research:
1. Searches memory vault for relevant prior knowledge
2. Includes top matching memories in research context
3. Adds "Prior Knowledge from Memory Vault" section to report

**Note**: This flag requires the memory extension to be loaded. If not loaded, the flag is ignored gracefully.

### 9. Multi-System Architecture

The vault is designed for concurrent use between Claude Code and OpenCode:
- Single `.memory/` vault at project root (shared)
- Different MCP ports per system
- Index regeneration from filesystem (self-healing)
- Last-write-wins for concurrent updates (rare edge case)

### 10. Current State

Analysis of the actual vault:
- `.memory/` exists at project root with full structure
- `10-Memories/` is empty (no memories created yet)
- `.obsidian/` directory present (Obsidian app configured)
- Templates and indices are in place

## Recommendations

### For Documentation (README.md)

The README.md should cover:

1. **Quick Start**
   - Load extension: `<leader>ac` -> select memory
   - Basic usage: `/learn "text"`, `/learn /path/file`

2. **Architecture Overview**
   - Vault structure diagram
   - Component relationships
   - Data flow (input -> mapping -> search -> operation -> index)

3. **Usage Patterns**
   - Four input modes with examples
   - Memory operations (UPDATE/EXTEND/CREATE) explained
   - Interactive workflow description

4. **MCP Setup**
   - Prerequisites (Obsidian, Node.js)
   - WebSocket option (primary)
   - REST API option (fallback)
   - Testing connection

5. **Topic and Classification System**
   - Topic hierarchy guidelines
   - Classification categories
   - Index navigation

6. **Troubleshooting**
   - Common issues (MCP not connecting, no memories found)
   - Debug steps
   - Graceful degradation behavior

7. **Best Practices**
   - Writing good memories
   - Managing vault size
   - Topic consistency

### For User Expectations

Users should expect:
- **Interactive workflow**: Every segment requires explicit confirmation
- **Obsidian dependency**: Full functionality requires Obsidian desktop app
- **Fallback mode**: Basic grep search works without MCP
- **Git-friendly**: Vault content is text-based and versioned
- **Learning curve**: Understanding overlap scoring and topic organization

## Decisions

1. The memory extension uses Obsidian's ecosystem rather than a custom vault format
2. MCP integration is optional with grep fallback
3. User confirmation is mandatory for all write operations
4. Topic paths use slash-separated hierarchy (2-3 levels typical)
5. Memory files use MEM- prefix for discoverability

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Obsidian not installed | Grep fallback provides basic functionality |
| MCP server conflicts | Different ports per system, one active at a time |
| Index corruption | Regeneration from filesystem state |
| Large vault performance | Phase 1 optimized for <1000 memories |
| Duplicate memories | Overlap scoring with UPDATE/EXTEND options |

## Appendix

### Files Analyzed

1. manifest.json - Extension metadata
2. EXTENSION.md - CLAUDE.md merge content
3. index-entries.json - Context discovery
4. commands/learn.md - Command definition
5. skills/skill-memory/SKILL.md - Skill implementation (850 lines)
6. context/project/memory/*.md - Usage documentation (4 files)
7. data/.memory/**/* - Vault skeleton structure

### Search Queries Used

- Glob: `.claude/extensions/memory/**/*`
- Grep: `--remember` in `.claude/`
- Bash: `ls -la .memory/10-Memories/`

### References

- Obsidian documentation: https://obsidian.md
- MCP server: @anthropic-ai/obsidian-claude-code-mcp
- Extension structure: `.claude/extensions/README.md`
