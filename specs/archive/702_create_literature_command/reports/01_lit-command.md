# Research Report: Task #702

**Task**: 702 - Create a /literature command
**Started**: 2026-06-14T17:00:00Z
**Completed**: 2026-06-14T17:30:00Z
**Effort**: 30 minutes
**Dependencies**: Task 701 (upgrade literature-retrieve.sh — closely related)
**Sources/Inputs**:
- Codebase: `.claude/commands/` (learn.md, research.md, distill.md, fix-it.md)
- Codebase: `.claude/skills/skill-memory/SKILL.md`, `skill-fix-it/SKILL.md`, `skill-project-overview/SKILL.md`, `skill-refresh/SKILL.md`
- Codebase: `.claude/agents/general-research-agent.md`, `meta-builder-agent.md`
- Codebase: `.claude/scripts/literature-retrieve.sh` (current script to understand index.json format)
- Codebase: `.claude/scripts/memory-harvest.sh` (token counting pattern)
- External: `specs/701_upgrade_literature_retrieve_script/reports/01_upgrade-lit-retrieve.md` (prior related task)
- External: `/home/benjamin/Projects/cslib/specs/literature/index.json` (real-world index format)
- System: `pdftotext`, `pandoc` availability check
**Artifacts**: specs/702_create_literature_command/reports/01_lit-command.md
**Standards**: report-format.md

---

## Executive Summary

- The `/literature` command should be a **direct-execution** command (like `/distill`, `/fix-it`, `/refresh`) that manages the `specs/literature/` directory — scanning for unprocessed PDFs/DJVUs, converting them, and maintaining `index.json` validity.
- PDF conversion via `pdftotext` (available at version 25.10.0) is the primary tool; pandoc does NOT support PDF as input format. DJVU conversion requires `djvutxt` from the `djvulibre` package which is available in nixpkgs but NOT currently installed — the command must detect availability and fall back gracefully.
- The `index.json` format is already well-established (from task 701 research): root uses `entries[]` with `path`, `title`, `token_count`, `keywords`, `summary` fields; subdirectory uses `chapters[]` with `file` field. The `/literature` command must read and write this exact schema.
- Token counting: use the `chars / 4 + 20` approximation already established in `memory-harvest.sh` — no external tokenizer needed.
- Architecture: single command file + single skill (direct execution) + NO dedicated agent. The skill does all the work inline using Bash, Read, Write, Edit tools with AskUserQuestion for the interactive conversion workflow.

---

## Context & Scope

The `/literature` command fills a gap in the literature management system: currently there is no tool to convert raw PDFs/DJVUs into the markdown files that `specs/literature/` is designed to hold. Users must manually convert files, compute token counts, and maintain `index.json` entries. The command should automate this pipeline.

The task description specifies five capabilities:
1. Scan for unprocessed PDFs/DJVUs lacking corresponding markdown conversions
2. Convert them to markdown chunked at ~4000 tokens per file
3. Generate/update `index.json` entries with keywords, summary, token_count
4. Validate existing `index.json` entries against the filesystem
5. Report status showing processed vs unprocessed files and index health

---

## Findings

### 1. Existing Command/Skill/Agent Patterns

The system has two patterns for commands:

**Pattern A: Delegation commands** (research.md, plan.md, implement.md) — parse args, call a skill via the `Skill` tool, which then spawns an Agent subagent.

**Pattern B: Direct-execution commands** (distill.md, fix-it.md, refresh.md, learn.md, project-overview.md) — parse args, call a skill via the `Skill` tool, but the skill runs **inline** (no Agent subagent) using `AskUserQuestion` for interactivity.

For `/literature`, Pattern B (direct execution) is correct because:
- The command is interactive (shows findings before converting)
- It needs `AskUserQuestion` for user selections
- It doesn't require deep reasoning — it's file manipulation + CLI tool invocation
- It mirrors the pattern of `/distill` (maintenance command) and `/fix-it` (scan + create workflow)

**Command frontmatter pattern** (from fix-it.md):
```yaml
---
description: Scan files for FIX:, NOTE:, TODO:, QUESTION: tags and create structured tasks interactively
allowed-tools: Skill
argument-hint: "[PATH...]"
model: opus
---
```

**Skill frontmatter pattern** (from skill-fix-it/SKILL.md):
```yaml
---
name: skill-literature
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json. Invoke for /literature command.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---
```

Note: Direct-execution skills do NOT include `Agent` in allowed-tools. The skill runs directly without spawning an agent subagent.

### 2. Available CLI Conversion Tools

**pdftotext** (available — `/home/benjamin/.nix-profile/bin/pdftotext`, version 25.10.0):
- Converts PDF to plain text
- Key flags: `-layout` (maintain physical layout), `-raw` (content stream order)
- No native markdown output — the output is plain text that needs post-processing to add headings etc.
- For academic papers, plain text is acceptable as markdown without headers (the `/literature` command can add a title header from metadata)

**pandoc** (available — `/run/current-system/sw/bin/pandoc`, version 3.7.0.2):
- Does NOT support PDF as input (`pdf` is NOT in `--list-input-formats` output)
- Can convert text/html to markdown — potentially useful for post-processing pdftohtml output
- Best use: convert pdftohtml XML output to markdown (richer structure)

**pdftohtml** (available — from poppler package):
- Converts PDF to HTML with structural information
- Combined with pandoc: `pdftohtml -stdout -s file.pdf | pandoc -f html -t gfm` could produce richer markdown

**djvutxt** (NOT installed — requires `djvulibre` from nixpkgs):
- Package exists: `djvulibre-3.5.29` in nixpkgs
- NOT currently in system profile: `which djvutxt` returns nothing
- The command should detect unavailability and suggest: `nix-env -iA nixpkgs.djvulibre`
- DJVU fallback: skip DJVU files with a "tool not available" message

**Recommended conversion pipeline**:
```bash
# For PDFs (primary approach — plain text, minimal)
pdftotext -layout "$pdf_file" "$output_txt"
# Then wrap in minimal markdown with title header

# For PDFs (alternative — richer structure via html intermediate)
pdftohtml -stdout -s -noframes "$pdf_file" 2>/dev/null | \
  pandoc -f html -t gfm --wrap=none 2>/dev/null > "$output_md"

# For DJVUs (when djvutxt available)
djvutxt "$djvu_file" "$output_txt"
```

**Token counting** (from memory-harvest.sh pattern):
```bash
char_count=$(wc -c < "$output_file")
token_count=$(( char_count / 4 + 20 ))
```

### 3. index.json Format (from task 701 research + direct inspection)

The root `specs/literature/index.json` uses this schema (from cslib real-world example):
```json
{
  "token_budget": 4000,
  "entries": [
    {
      "id": "johansson_1937",
      "bib_key": "Johansson1937",
      "title": "Der Minimalkalkül...",
      "authors": "Ingebrigt Johansson",
      "year": 1937,
      "section": null,
      "path": "johansson_1937.md",
      "page_range": "119-136",
      "token_count": 5653,
      "keywords": ["minimal logic", "intuitionistic logic", ...],
      "summary": "Defines minimal logic by removing..."
    }
  ]
}
```

**Required fields** (minimum for `/literature` to generate): `id`, `path`, `token_count`, `keywords`, `summary`. Optional: `title`, `authors`, `year`, `bib_key`, `page_range`.

**Chunking strategy**: When a PDF is too large (~4000 tokens), chunk by page ranges. Each chunk becomes a separate markdown file with its own entry:
- `author_year_p1-10.md` for pages 1-10
- `author_year_p11-20.md` for pages 11-20
- pdftotext supports `-f` (first page) and `-l` (last page) flags for page-range extraction

**Token budget per chunk**: 4000 tokens (~16,000 characters). At ~350 words/page and ~1.3 tokens/word, a 4000-token chunk is roughly 9-10 pages.

### 4. Chunking Architecture

The command needs to decide whether to chunk automatically or present chunk boundaries to the user. Given that academic papers range from 10-100 pages:

- Papers < ~10 pages (single chunk): convert to single file
- Papers >= ~10 pages: chunk by page count, presenting proposed boundaries to user via `AskUserQuestion`

**Page count detection**:
```bash
page_count=$(pdfinfo "$pdf_file" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
```

**Chunk size**: 10 pages per chunk (approximate 4000 tokens). User can override via prompt.

### 5. Keywords and Summary Generation

The current `index.json` entries in real projects have manually written `keywords` and `summary` fields. For automated generation, the `/literature` command should:

1. **Keywords**: Extract frequent noun phrases from converted text using simple word frequency analysis (top 10 content words after stopword removal — same approach as `literature-retrieve.sh` scoring)
2. **Summary**: Extract the abstract if present (look for "Abstract" heading in first ~500 characters of output), or use the first 2-3 sentences as a fallback
3. **Interactive refinement**: Present auto-generated keywords/summary to user via `AskUserQuestion` for confirmation/editing before writing to `index.json`

This matches the interactive pattern of `/learn` which shows proposed memory operations before executing.

### 6. Validation Logic

For index validation (detecting stale entries), the command should:

1. Read all entries from `index.json`
2. For each entry: check if `specs/literature/{entry.path}` exists
3. Report missing files as "stale entries"
4. Check token_count drift: recount file tokens, flag if > 20% different from stored count
5. Detect unindexed markdown files: scan for `.md` files in `specs/literature/` not referenced in any entry

### 7. Command Modes

The `/literature` command should support multiple modes similar to `/distill`:

| Mode | Invocation | Description |
|------|-----------|-------------|
| Status (default) | `/literature` | Show processed/unprocessed files and index health |
| Scan | `/literature --scan` | Scan for PDFs/DJVUs lacking markdown conversions |
| Convert | `/literature --convert [FILE]` | Convert specific or all unprocessed files |
| Validate | `/literature --validate` | Check index.json against filesystem |
| Index | `/literature --index FILE` | Add/update index entry for existing markdown file |

### 8. File Organization Pattern

Following the cslib `specs/literature/` structure:
```
specs/literature/
├── index.json                    # Root index (entries[])
├── author_year.md                # Single-file papers
├── author_year/                  # Multi-file books/large papers
│   ├── index.json               # Subdirectory index (chapters[])
│   ├── ch01_intro.md
│   └── ch02_background.md
└── source_files/                 # Optional: store original PDFs/DJVUs here
    └── author_year.pdf
```

For newly converted PDFs, the command should ask whether to:
1. Place converted .md alongside the source PDF
2. Move the source PDF to a `source_files/` subdirectory

---

## Decisions

- **Architecture**: Direct-execution command (like /distill) — no dedicated agent subagent. Command file + skill only.
- **Skill location**: `.claude/skills/skill-literature/SKILL.md` (as specified in task description)
- **No literature-agent.md needed**: The task description mentions `.claude/agents/literature-agent.md`, but the direct-execution pattern does not use an agent. The agent file would only be needed if the skill delegates to an Agent tool call. Recommendation: do NOT create an agent file — use direct skill execution.
- **PDF conversion tool**: pdftotext primary (available), pandoc+pdftohtml as alternative for richer structure
- **DJVU tool**: Gracefully degrade if djvutxt unavailable — detect and prompt user to install `djvulibre`
- **Token counting**: `chars / 4 + 20` approximation (matches memory-harvest.sh pattern)
- **Chunking threshold**: 4000 tokens (~10 pages) per output file; prompt user for chunk boundaries
- **Keyword extraction**: Automated word-frequency approach, presented for user confirmation
- **Index format**: Exactly match existing `index.json` schema (entries[] for root, chapters[] for subdirs)
- **Agent file**: If task description requires it, create a minimal literature-agent.md that documents the skill delegates inline (no actual routing to agent)

---

## Architecture: The Three Files

### File 1: `.claude/commands/literature.md`

Purpose: Argument parsing and dispatch.

```yaml
---
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, and maintain index.json
allowed-tools: Skill
argument-hint: "[--scan|--convert [FILE]|--validate|--index FILE]"
---
```

Workflow:
1. Parse arguments to determine mode (status/scan/convert/validate/index)
2. Extract optional FILE argument
3. Delegate to `skill-literature` with `mode={mode} file={file}`

### File 2: `.claude/skills/skill-literature/SKILL.md`

Purpose: All implementation logic (direct execution, no agent delegation).

Modes:
- **Status** (default): Read index.json, scan for PDFs/DJVUs, compute and display health report
- **Scan**: Find PDF/DJVU files lacking corresponding markdown, show unprocessed list
- **Convert**: For each unprocessed file: run pdftotext/djvutxt, chunk if needed, generate keywords/summary, present to user via AskUserQuestion, write markdown + update index.json
- **Validate**: Read index.json entries, check filesystem, report stale/missing/unindexed
- **Index**: For existing markdown file, compute token_count, prompt for keywords/summary, add to index.json

Execution flow follows the fix-it skill pattern: scan -> present -> confirm -> execute.

### File 3: `.claude/agents/literature-agent.md` (OPTIONAL — may not be needed)

If required by the architecture (task description names it), create a minimal agent definition that documents the skill's direct-execution pattern. The agent would NOT be invoked during normal `/literature` command execution.

If the implementer decides to use agent delegation instead of direct execution (e.g., for the keyword/summary generation step which benefits from LLM reasoning), the agent can handle the generation sub-task. However, this increases complexity and cost.

**Recommendation**: Skip the agent file unless keyword/summary LLM generation is specifically needed. The skill can generate basic keywords algorithmically.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| djvutxt not installed | Detect with `which djvutxt`, warn user, suggest `nix-env -iA nixpkgs.djvulibre` |
| PDF has no extractable text (scanned image) | pdftotext returns empty/whitespace — detect and warn user: "no text extracted, OCR required" |
| Very large PDFs (100+ pages) | Auto-chunk with 10-page windows; prompt user for confirmation |
| Subdirectory index.json schema differences | Use chapters[] format for subdirectory indexes (matches existing pattern) |
| index.json becomes stale after manual edits | Validate mode detects drift; validate is the first thing status mode reports |
| Token count drift over time | 20% threshold for flagging; recount during validate mode |
| CLAUDE.md update needed | After creating skill, add to skill-to-agent mapping table in .claude/CLAUDE.md |

---

## Context Extension Recommendations

- **Topic**: Literature command documentation
- **Gap**: No documentation for the `/literature` command workflow in `.claude/context/`
- **Recommendation**: After implementation, add `.claude/context/project/literature/` with usage guide and index schema documentation.

---

## Appendix

### Search Queries Used
- `ls .claude/commands/` — enumerate all commands
- `ls .claude/skills/` — enumerate all skills
- `ls .claude/agents/` — enumerate all agents
- `Read` of learn.md, research.md, distill.md — command format patterns
- `Read` of skill-fix-it/SKILL.md, skill-memory/SKILL.md — skill patterns
- `which pdftotext pandoc djvutxt mutool` — tool availability
- `pdftotext -h` — flags for PDF conversion
- `pandoc --list-input-formats` — confirmed PDF not supported
- `pdftotext /path/to/pdf.pdf -` — verified output quality
- `jq` on cslib literature index.json — confirmed real-world schema
- `find /home/benjamin/Projects -name "*.pdf" -o -name "*.djvu"` — real-world files
- `Read` of 701 research report — adjacent task findings

### Key Reference Files
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` — index.json reading pattern
- `/home/benjamin/.config/nvim/.claude/scripts/memory-harvest.sh` — token count pattern (chars/4)
- `/home/benjamin/.config/nvim/.claude/commands/distill.md` — closest command pattern (maintenance command with sub-modes)
- `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` — closest skill pattern (scan + interactive)
- `/home/benjamin/Projects/cslib/specs/literature/index.json` — real-world index schema

### Tool Availability Summary
| Tool | Available | Path | Notes |
|------|-----------|------|-------|
| pdftotext | YES | /home/benjamin/.nix-profile/bin/pdftotext | Version 25.10.0 |
| pdfinfo | YES | /home/benjamin/.nix-profile/bin/pdfinfo | Get page count |
| pandoc | YES | /run/current-system/sw/bin/pandoc | PDF input NOT supported |
| pdftohtml | YES | from poppler | Can bridge to pandoc via html |
| djvutxt | NO | not installed | Needs nixpkgs.djvulibre |
| mutool | NO | not installed | Not available |

### Chunking Math
- Average PDF: 300-400 words/page
- At 1.3 tokens/word: ~400-500 tokens/page
- 4000 token target: ~8-10 pages per chunk
- Recommended: 10 pages per chunk (simple, round number)
- Formula: `pages_per_chunk = max(1, 4000 / (page_count / total_tokens * 4000))`
- Simpler: convert first, measure chars, rechunk by token estimate
