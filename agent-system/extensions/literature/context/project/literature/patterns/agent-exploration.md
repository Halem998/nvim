# Agent Literature Exploration Pattern

## Overview: Briefing + Tools

When the `--lit` flag is active, agents receive a `<literature-briefing>` block instead of
full content injection. The briefing lists available documents with metadata and usage
instructions. Agents then explore literature on demand using existing tools.

This replaces the old content-injection approach (`<literature-context>`) which blindly loaded
all literature files up to a token budget.

## What Agents Receive

When `--lit` is active, the agent prompt includes:

```
<literature-briefing>
## Available Literature

N documents available in the Literature/ repository.
Use Read to access specific files, literature-search.sh to search the corpus.

### Documents

1. **Blackburn, de Rijke & Venema (2002)** — Modal Logic
   - doc_id: blackburn_2002
   - Chunks: 12 sections (45,000 tokens total)
   - Keywords: modal logic, semantics, completeness, frame
   - Path: /home/benjamin/Projects/Literature/sources/blackburn_2002/

2. **Venema (2001)** — A Survey of Modal Logic
   - doc_id: venema_2001
   - Chunks: 3 sections (8,200 tokens total)
   - Keywords: modal logic, survey, correspondence theory
   - Path: /home/benjamin/Projects/Literature/sources/venema_2001/

## Usage Instructions

- **Search the corpus**: `bash .claude/scripts/literature-search.sh "your query"`
- **Read a specific chunk**: Use the Read tool with the absolute path shown above
- **Read selectively**: Only read what you need — prefer search first, then read specific chunks

</literature-briefing>
```

## How to Explore Literature

### Step 1: Search First

Use `literature-search.sh` to find relevant chunks before reading:

```bash
bash .claude/scripts/literature-search.sh "modal logic completeness"
bash .claude/scripts/literature-search.sh "bisimulation" --limit 5
bash .claude/scripts/literature-search.sh "blackburn_2002" --by-doc
```

Returns a JSON array. Each result includes:
- `doc_id`: document identifier
- `section_path`: relative path from `$LITERATURE_DIR/`
- `score`: relevance score (higher is better)
- `snippet`: matching text excerpt

### Step 2: Read Specific Chunks

After searching, Read the most relevant chunks by their absolute path:

```bash
# Construct absolute path: $LITERATURE_DIR + "/" + section_path
/home/benjamin/Projects/Literature/sources/blackburn_2002/section02_syntax.md
```

Or use the path shown in the briefing for the document directory.

### Step 3: Read Selectively

- Read only what you need for the current task
- A single search returns ~3K tokens of context
- Read 1-3 chunks per search query for typical tasks
- Only read entire documents when comprehensive coverage is needed

## Selectivity Principle

The briefing pattern is designed for selectivity:
- **Briefing**: ~300 tokens — always present, zero cost per search
- **Search result**: ~3K tokens — one call, targeted results
- **Chunk read**: 2-8K tokens — only what you need

Compare to old injection: 4,000-8,000 tokens loaded blindly regardless of relevance.

## Example Workflow

Task: "Prove completeness of K modal logic"

```
1. Receive <literature-briefing> with blackburn_2002 (12 chunks, 45K tokens)

2. Search for relevant material:
   bash .claude/scripts/literature-search.sh "K modal logic completeness proof"
   -> Returns section05_completeness.md (score: 8.2) and section07_canonical_model.md (score: 6.1)

3. Read the most relevant chunk:
   Read /home/benjamin/Projects/Literature/sources/blackburn_2002/section05_completeness.md
   -> Contains canonical model construction details

4. Proceed with implementation using the retrieved context
```

## When to NOT Search

- For tasks that don't require literature (most tasks)
- When the task description makes no reference to papers or theorems
- When you already have sufficient context from memory or task artifacts

The `<literature-briefing>` block is a signal that literature is available and relevant — but
agents should only search/read when the task actually requires it.
